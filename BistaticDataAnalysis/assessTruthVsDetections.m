function metrics = assessTruthVsDetections(detections, tracks_log, adsb_aligned, varargin)
%ASSESSTRUTHVSDETECTIONS  Evaluate radar pipeline accuracy against ADS-B truth.
%
%  Computes two complementary levels of performance metrics:
%
%  DETECTION-LEVEL  (§1)
%    For every CFAR detection, search for ADS-B aircraft within a
%    spatio-temporal gate and label each detection as:
%      TP  — True Positive: detection falls within (ΔR, Δf) gate of an
%             ADS-B aircraft at the same CPI time.
%      FA  — False Alarm:   detection has no matching ADS-B aircraft.
%    For each ADS-B aircraft, count missed detections (CPIs where the
%    aircraft is in the surveillance volume but produced no matched detection).
%
%  TRACK-LEVEL  (§2)
%    For each Kalman Filter track in tracks_log, associate it with the
%    nearest ADS-B aircraft by minimum mean |ΔR_excess| over the track's
%    confirmed lifetime.  Then compute:
%      range_bias_m   — mean(R_track − R_adsb)         [m]
%      range_rmse_m   — sqrt(mean((R_track − R_adsb)²)) [m]
%      doppler_bias_hz  — mean(f_track − f_adsb)       [Hz]
%      doppler_rmse_hz  — sqrt(mean((f_track − f_adsb)²))
%
% ── ASSOCIATION GATES ──────────────────────────────────────────────────
%  Gate parameters (override via 'GateRangeCells' and 'GateDopplerBins'):
%    ΔR gate:  |R_det − R_adsb| < gate_range_cells × range_cell_m
%    Δf gate:  |f_det − f_adsb| < gate_doppler_bins × doppler_bin_hz
%  Defaults: 3 range cells (~180 m @ 60 m/cell for 5 Msps),
%            3 Doppler bins (30 Hz @ 10 Hz/bin)
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   metrics = assessTruthVsDetections(detections, tracks_log, adsb_aligned)
%   metrics = assessTruthVsDetections(..., 'RangeCellM', 30, 'DopplerBinHz', 10)
%   metrics = assessTruthVsDetections(..., 'GateRangeCells', 3, 'GateDopplerBins', 3)
%
% ── INPUTS ──────────────────────────────────────────────────────────────
%   detections     Struct array or table of CFAR detections.  Required
%                  fields: .t_abs_s [scalar], .R_excess_m [scalar],
%                  .f_D_hz [scalar].  Each element is one detection from
%                  one CPI.  Pass [] to skip detection-level analysis.
%
%   tracks_log     Struct array of KF track histories.
%                  Preferred fields: .t_abs_s [P×1], .R_excess_m [P×1],
%                  .f_D_hz [P×1], .TrackID, .StateCovDiag (optional).
%                  Legacy fallback fields: .t_abs_s with .State.
%                  Pass [] to skip track-level analysis.
%
%   adsb_aligned   Struct array from alignTruthToRadar.  Required fields:
%                  .hex, .callsign, .t_abs_s, .R_excess_m, .f_D_hz.
%
% ── OPTIONAL NAME-VALUE PARAMETERS ─────────────────────────────────────
%   'RangeCellM'       Range cell size [m].   Default: 30.
%   'DopplerBinHz'     Doppler bin  [Hz].     Default: 10.
%   'GateRangeCells'   Range gate width in cells.   Default: 3.
%   'GateDopplerBins'  Doppler gate width in bins.  Default: 3.
%   'TimeGateS'        Detection-to-truth time gate [s]. Default: derived
%                      from the aligned truth grid spacing.
%   'StateIsVelocity'  Logical.  If true, tracks_log.State(:,3) is
%                      range-rate [m/s]; convert using f_D = -α·Rdot.
%                      Default: false (State(:,3) already in Hz).
%   'Alpha'            Doppler coupling factor α = 2fc/c [Hz/(m/s)].
%                      Only used when StateIsVelocity=true.  Default: 4.0.
%   'Verbose'          Logical.  Print per-aircraft table.  Default: true.
%
% ── OUTPUT ──────────────────────────────────────────────────────────────
%   metrics   Struct with fields:
%
%     DETECTION-LEVEL:
%     .det_table      table  — one row per detection: columns
%                              t_abs_s, R_excess_m, f_D_hz,
%                              matched_hex, matched_callsign,
%                              matched_truth_t_abs_s,
%                              matched_truth_R_excess_m,
%                              matched_truth_f_D_hz,
%                              matched_dt_s,
%                              det_range_err_m, det_doppler_err_hz,
%                              is_tp, is_fa
%     .n_tp           scalar — total true positives
%     .n_fa           scalar — total false alarms
%     .n_miss         scalar — total missed detections (all aircraft combined)
%     .Pd_per_ac      table  — per-aircraft: hex, callsign, n_tp,
%                              n_hit_cpis, n_miss, n_visible_cpis, Pd
%     .det_range_err_m  [n_tp×1] — ΔR at each TP (for histogram)
%     .det_doppler_err_hz [n_tp×1] — Δf at each TP
%
%     TRACK-LEVEL:
%     .trk_table      table  — one row per KF track: track_id, assoc_hex,
%                              assoc_callsign, range_bias_m, range_rmse_m,
%                              doppler_bias_hz, doppler_rmse_hz, n_pts
%     .gate_range_m   scalar — range gate half-width [m] used
%     .gate_doppler_hz scalar — Doppler gate half-width [Hz] used
%
% See also: loadADSBTruth, adsbToBistatic, alignTruthToRadar, plotTruthComparison.

% =========================================================================
%  0.  Parse inputs
% =========================================================================
p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'detections');
addRequired(p, 'tracks_log');
addRequired(p, 'adsb_aligned');
addParameter(p, 'RangeCellM',      30,    @(x) isnumeric(x) && x > 0);
addParameter(p, 'DopplerBinHz',    10,    @(x) isnumeric(x) && x > 0);
addParameter(p, 'GateRangeCells',  3,     @(x) isnumeric(x) && x > 0);
addParameter(p, 'GateDopplerBins', 3,     @(x) isnumeric(x) && x > 0);
addParameter(p, 'TimeGateS',       [],    @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'StateIsVelocity', false, @islogical);
addParameter(p, 'Alpha',           4.0,   @(x) isnumeric(x) && x > 0);
addParameter(p, 'Verbose',         true,  @islogical);
parse(p, detections, tracks_log, adsb_aligned, varargin{:});
opts = p.Results;

gate_R = opts.GateRangeCells  * opts.RangeCellM;    % half-width [m]
gate_f = opts.GateDopplerBins * opts.DopplerBinHz;  % half-width [Hz]

metrics = struct();
metrics.gate_range_m    = gate_R;
metrics.gate_doppler_hz = gate_f;

N_ac = numel(adsb_aligned);
if N_ac == 0
    warning('assessTruthVsDetections:noTruth', 'adsb_aligned is empty — nothing to compare.');
    return
end

if isempty(opts.TimeGateS)
    time_gate_s = estimateTruthTimeGate(adsb_aligned);
else
    time_gate_s = opts.TimeGateS;
end
metrics.time_gate_s = time_gate_s;

fprintf('[assessTruthVsDetections] Gate: |ΔR| < %.0f m,  |Δf| < %.1f Hz\n', gate_R, gate_f);
fprintf('[assessTruthVsDetections] Time gate: |Δt| < %.3f s\n', time_gate_s);
fprintf('[assessTruthVsDetections] %d ADS-B aircraft available as truth.\n', N_ac);

% =========================================================================
%  §1  DETECTION-LEVEL ASSESSMENT
% =========================================================================
metrics.n_tp             = 0;
metrics.n_fa             = 0;
metrics.n_miss           = 0;
metrics.det_range_err_m  = [];
metrics.det_doppler_err_hz = [];
metrics.det_table        = table();
metrics.Pd_per_ac        = table();

if ~isempty(detections)
    N_det = numel(detections);

    % ── Unpack detection arrays ───────────────────────────────────────────
    if isstruct(detections)
        det_t = [detections.t_abs_s].';
        det_R = [detections.R_excess_m].';
        det_f = [detections.f_D_hz].';
    else
        % Assume table with those column names
        det_t = detections.t_abs_s;
        det_R = detections.R_excess_m;
        det_f = detections.f_D_hz;
        N_det = height(detections);
    end

    % Per-detection output columns
    is_tp        = false(N_det, 1);
    is_fa        = true(N_det, 1);
    matched_hex  = repmat({''}, N_det, 1);
    matched_callsign = repmat({''}, N_det, 1);
    matched_truth_t = NaN(N_det, 1);
    matched_truth_R = NaN(N_det, 1);
    matched_truth_f = NaN(N_det, 1);
    matched_dt_s = NaN(N_det, 1);
    matched_dR   = NaN(N_det, 1);
    matched_df   = NaN(N_det, 1);

    % ── Per-aircraft TP counter and miss counter ──────────────────────────
    ac_tp    = zeros(N_ac, 1);
    ac_miss  = zeros(N_ac, 1);

    % Build a time grid per aircraft (for miss counting: only CPIs where the
    % aircraft is inside the surveillance volume are eligible)
    for d = 1 : N_det
        t_d = det_t(d);
        R_d = det_R(d);
        f_d = det_f(d);

        best_dR  = Inf;
        best_k   = 0;
        best_t_k = NaN;
        best_R_k = NaN;
        best_f_k = NaN;

        for k = 1 : N_ac
            ac = adsb_aligned(k);
            if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
                continue
            end
            valid_truth = ~isnan(ac.R_excess_m) & ~isnan(ac.f_D_hz);
            if ~any(valid_truth)
                continue
            end

            t_truth = ac.t_abs_s(valid_truth);
            R_truth = ac.R_excess_m(valid_truth);
            f_truth = ac.f_D_hz(valid_truth);

            % Nearest truth sample to this detection's time
            [dt_min, idx] = min(abs(t_truth - t_d));
            if dt_min > time_gate_s
                continue
            end
            R_k = R_truth(idx);
            f_k = f_truth(idx);
            dR = abs(R_d - R_k);
            df = abs(f_d - f_k);
            if dR < gate_R && df < gate_f
                if dR < best_dR
                    best_dR  = dR;
                    best_k   = k;
                    best_t_k = t_truth(idx);
                    best_R_k = R_k;
                    best_f_k = f_k;
                end
            end
        end

        if best_k > 0
            is_tp(d)       = true;
            is_fa(d)       = false;
            matched_hex{d} = adsb_aligned(best_k).hex;
            matched_callsign{d} = adsb_aligned(best_k).callsign;
            matched_truth_t(d) = best_t_k;
            matched_truth_R(d) = best_R_k;
            matched_truth_f(d) = best_f_k;
            matched_dt_s(d) = det_t(d) - best_t_k;
            matched_dR(d)  = det_R(d) - best_R_k;
            matched_df(d)  = det_f(d) - best_f_k;
            ac_tp(best_k)  = ac_tp(best_k) + 1;
        end
    end

    % ── Miss count: CPIs where aircraft is visible but no TP was registered
    for k = 1 : N_ac
        ac = adsb_aligned(k);
        if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
            continue
        end
        % Unique CPI times where this aircraft has non-NaN truth
        valid_truth = ~isnan(ac.R_excess_m) & ~isnan(ac.f_D_hz);
        cpi_visible = ac.t_abs_s(valid_truth);
        if isempty(cpi_visible)
            continue
        end
        % Unique CPI times that had a TP match for this aircraft
        tp_times = det_t(strcmp(matched_hex, ac.hex));
        % Miss = visible CPIs with no associated TP (within 1 CPI time step)
        min_dt_cpi = estimateTruthTimeGate(ac);   % typical CPI interval
        if isnan(min_dt_cpi) || min_dt_cpi == 0
            min_dt_cpi = 0.5;   % fallback 0.5 s
        end
        n_visible = numel(cpi_visible);
        n_covered = 0;
        for ci = 1 : n_visible
            if any(abs(tp_times - cpi_visible(ci)) <= min_dt_cpi / 2)
                n_covered = n_covered + 1;
            end
        end
        ac_miss(k) = n_visible - n_covered;
    end
    ac_n_visible_all = countVisibleTruthSamples(adsb_aligned);
    ac_hit_cpi = max(ac_n_visible_all - ac_miss, 0);

    % ── Assemble output ───────────────────────────────────────────────────
    metrics.n_tp               = sum(is_tp);
    metrics.n_fa               = sum(is_fa);
    metrics.n_miss             = sum(ac_miss);
    metrics.det_range_err_m    = matched_dR(is_tp);
    metrics.det_doppler_err_hz = matched_df(is_tp);

    metrics.det_table = table( ...
        det_t, det_R, det_f, matched_hex, matched_callsign, ...
        matched_truth_t, matched_truth_R, matched_truth_f, ...
        matched_dt_s, matched_dR, matched_df, ...
        is_tp, is_fa, ...
        'VariableNames', ...
        {'t_abs_s', 'R_excess_m', 'f_D_hz', 'matched_hex', 'matched_callsign', ...
         'matched_truth_t_abs_s', 'matched_truth_R_excess_m', 'matched_truth_f_D_hz', ...
         'matched_dt_s', 'det_range_err_m', 'det_doppler_err_hz', ...
         'is_tp', 'is_fa'});

    % Per-aircraft detection probability table
    ac_hex_list      = {adsb_aligned.hex}.';
    ac_cs_list       = {adsb_aligned.callsign}.';
    ac_Pd = ac_hit_cpi ./ max(ac_n_visible_all, 1);

    metrics.Pd_per_ac = table( ...
        ac_hex_list, ac_cs_list, ac_tp, ac_hit_cpi, ac_miss, ac_n_visible_all, ac_Pd, ...
        'VariableNames', ...
        {'hex', 'callsign', 'n_tp', 'n_hit_cpis', 'n_miss', 'n_visible_cpis', 'Pd'});

    if opts.Verbose
        fprintf('\n── Detection-Level Metrics ──────────────────────────────────────\n');
        fprintf('  Total detections: %d  |  TP: %d  |  FA: %d  |  Missed: %d\n', ...
            N_det, metrics.n_tp, metrics.n_fa, metrics.n_miss);
        if metrics.n_tp > 0
            fprintf('  Range error:   mean=%.1f m  rms=%.1f m\n', ...
                mean(metrics.det_range_err_m, 'omitnan'), ...
                sqrt(mean(metrics.det_range_err_m.^2, 'omitnan')));
            fprintf('  Doppler error: mean=%.2f Hz  rms=%.2f Hz\n', ...
                mean(metrics.det_doppler_err_hz, 'omitnan'), ...
                sqrt(mean(metrics.det_doppler_err_hz.^2, 'omitnan')));
        end
        fprintf('\n  Per-aircraft detection probability:\n');
        disp(metrics.Pd_per_ac(:, {'hex','callsign','n_tp','n_hit_cpis','n_miss','Pd'}));
    end
end

% =========================================================================
%  §2  TRACK-LEVEL ASSESSMENT
% =========================================================================
metrics.trk_table = table();

if ~isempty(tracks_log) && N_ac > 0
    N_trk = numel(tracks_log);

    trk_ids         = zeros(N_trk, 1);
    assoc_hex       = repmat({''}, N_trk, 1);
    assoc_cs        = repmat({''}, N_trk, 1);
    range_bias      = NaN(N_trk, 1);
    range_rmse      = NaN(N_trk, 1);
    doppler_bias    = NaN(N_trk, 1);
    doppler_rmse    = NaN(N_trk, 1);
    n_pts_vec       = zeros(N_trk, 1);

    for ti = 1 : N_trk
        trk = tracks_log(ti);
        trk_series = extractTrackSeries(trk, ti, opts);
        trk_ids(ti) = trk_series.TrackID;
        t_trk = trk_series.t_abs_s;
        R_trk = trk_series.R_excess_m;
        f_trk = trk_series.f_D_hz;

        if isempty(t_trk) || isempty(R_trk) || isempty(f_trk)
            continue
        end

        % ── Find best-matching ADS-B aircraft (min mean |ΔR| during track) –
        best_mean_dR = Inf;
        best_k       = 0;

        for k = 1 : N_ac
            ac = adsb_aligned(k);
            if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
                continue
            end
            % Interpolate ADS-B truth onto the track's time grid
            R_ac_at_trk = interp1(ac.t_abs_s, ac.R_excess_m, t_trk, 'linear', NaN);
            valid_both   = ~isnan(R_ac_at_trk) & ~isnan(R_trk);
            if sum(valid_both) < 2
                continue
            end
            mean_dR = mean(abs(R_trk(valid_both) - R_ac_at_trk(valid_both)));
            if mean_dR < best_mean_dR
                best_mean_dR = mean_dR;
                best_k       = k;
            end
        end

        if best_k == 0
            continue
        end

        % ── Compute metrics for the associated aircraft ────────────────────
        ac = adsb_aligned(best_k);
        R_ac_at_trk = interp1(ac.t_abs_s, ac.R_excess_m, t_trk, 'linear', NaN);
        f_ac_at_trk = interp1(ac.t_abs_s, ac.f_D_hz,     t_trk, 'linear', NaN);
        valid_R     = ~isnan(R_ac_at_trk) & ~isnan(R_trk);
        valid_f     = ~isnan(f_ac_at_trk) & ~isnan(f_trk);

        if any(valid_R)
            dR             = R_trk(valid_R) - R_ac_at_trk(valid_R);
            range_bias(ti) = mean(dR);
            range_rmse(ti) = sqrt(mean(dR.^2));
        end
        if any(valid_f)
            df               = f_trk(valid_f) - f_ac_at_trk(valid_f);
            doppler_bias(ti) = mean(df);
            doppler_rmse(ti) = sqrt(mean(df.^2));
        end
        assoc_hex(ti) = {ac.hex};
        assoc_cs(ti)  = {ac.callsign};
        n_pts_vec(ti) = sum(valid_R);
    end

    metrics.trk_table = table( ...
        trk_ids, assoc_hex, assoc_cs, range_bias, range_rmse, ...
        doppler_bias, doppler_rmse, n_pts_vec, ...
        'VariableNames', {'track_id', 'assoc_hex', 'assoc_callsign', ...
                          'range_bias_m', 'range_rmse_m', ...
                          'doppler_bias_hz', 'doppler_rmse_hz', 'n_pts'});

    if opts.Verbose
        fprintf('\n── Track-Level Metrics ──────────────────────────────────────────\n');
        disp(metrics.trk_table);
    end
end

fprintf('[assessTruthVsDetections] Done.\n\n');

end  % ════════════════════ end assessTruthVsDetections ════════════════════

% ── Local helper ─────────────────────────────────────────────────────────
function time_gate_s = estimateTruthTimeGate(adsb_aligned)
dt_all = zeros(0, 1);

for k = 1 : numel(adsb_aligned)
    ac = adsb_aligned(k);
    if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
        continue
    end

    valid_truth = ~isnan(ac.R_excess_m);
    if isfield(ac, 'f_D_hz')
        valid_truth = valid_truth & ~isnan(ac.f_D_hz);
    end

    t_visible = ac.t_abs_s(valid_truth);
    if numel(t_visible) < 2
        continue
    end

    dt_vec = diff(t_visible(:));
    dt_vec = dt_vec(dt_vec > 0);
    dt_all = [dt_all; dt_vec(:)]; %#ok<AGROW>
end

if isempty(dt_all)
    time_gate_s = 0.5;
else
    time_gate_s = median(dt_all);
end
end

function ac_n_visible_all = countVisibleTruthSamples(adsb_aligned)
N_ac = numel(adsb_aligned);
ac_n_visible_all = zeros(N_ac, 1);

for k = 1 : N_ac
    ac = adsb_aligned(k);
    if isempty(ac.R_excess_m)
        continue
    end

    valid_truth = ~isnan(ac.R_excess_m);
    if isfield(ac, 'f_D_hz')
        valid_truth = valid_truth & ~isnan(ac.f_D_hz);
    end
    ac_n_visible_all(k) = sum(valid_truth);
end
end

function trk_series = extractTrackSeries(trk, fallback_track_id, opts)
trk_series = struct( ...
    'TrackID',     fallback_track_id, ...
    't_abs_s',     zeros(0, 1), ...
    'R_excess_m',  zeros(0, 1), ...
    'f_D_hz',      zeros(0, 1));

if isfield(trk, 'TrackID') && ~isempty(trk.TrackID)
    trk_series.TrackID = trk.TrackID;
end

if ~isfield(trk, 't_abs_s') || isempty(trk.t_abs_s)
    return
end
trk_series.t_abs_s = trk.t_abs_s(:);

if isfield(trk, 'R_excess_m') && ~isempty(trk.R_excess_m)
    trk_series.R_excess_m = trk.R_excess_m(:);
elseif isfield(trk, 'State') && ~isempty(trk.State) && size(trk.State, 2) >= 1
    trk_series.R_excess_m = trk.State(:, 1);
else
    trk_series.t_abs_s = zeros(0, 1);
    return
end

if isfield(trk, 'f_D_hz') && ~isempty(trk.f_D_hz)
    trk_series.f_D_hz = trk.f_D_hz(:);
    return
end

if isfield(trk, 'Rdot_mps') && ~isempty(trk.Rdot_mps)
    trk_series.f_D_hz = -opts.Alpha * trk.Rdot_mps(:);
    return
end

if isfield(trk, 'State') && ~isempty(trk.State)
    if size(trk.State, 2) >= 3 && ~opts.StateIsVelocity
        trk_series.f_D_hz = trk.State(:, 3);
    elseif size(trk.State, 2) >= 3 && opts.StateIsVelocity
        trk_series.f_D_hz = -opts.Alpha * trk.State(:, 3);
    elseif size(trk.State, 2) >= 2
        trk_series.f_D_hz = -opts.Alpha * trk.State(:, 2);
    end
end
end
