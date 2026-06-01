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
%  Defaults: 3 range cells (90 m @ 30 m/cell), 3 Doppler bins (30 Hz @ 10 Hz/bin)
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
%   tracks_log     Struct array of KF tracks from trackTargets.  Required
%                  fields: .t_abs_s [P×1], .State [P×4] where
%                  State(p,1) = R_excess_m, State(p,3) = f_D_hz (or
%                  dR/dt in m/s — see 'StateIsVelocity' parameter).
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
%   'StateIsVelocity'  Logical.  If true, tracks_log.State(:,3) is
%                      range-rate [m/s]; multiply by α=2fc/c to get f_D.
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
%                              matched_hex ('' = FA), is_tp, is_fa
%     .n_tp           scalar — total true positives
%     .n_fa           scalar — total false alarms
%     .n_miss         scalar — total missed detections (all aircraft combined)
%     .Pd_per_ac      table  — per-aircraft: hex, callsign, n_tp, n_miss, Pd
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

fprintf('[assessTruthVsDetections] Gate: |ΔR| < %.0f m,  |Δf| < %.1f Hz\n', gate_R, gate_f);
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
        best_f_k = NaN;

        for k = 1 : N_ac
            ac = adsb_aligned(k);
            if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
                continue
            end
            % Nearest truth sample to this detection's time
            [dt_min, idx] = min(abs(ac.t_abs_s - t_d));
            if dt_min > opts.DopplerBinHz   % looser time gate: 1 Doppler bin's worth of CPI time
                continue
            end
            R_k = ac.R_excess_m(idx);
            f_k = ac.f_D_hz(idx);
            if isnan(R_k) || isnan(f_k)
                continue
            end
            dR = abs(R_d - R_k);
            df = abs(f_d - f_k);
            if dR < gate_R && df < gate_f
                if dR < best_dR
                    best_dR  = dR;
                    best_k   = k;
                    best_f_k = f_k;
                end
            end
        end

        if best_k > 0
            is_tp(d)       = true;
            is_fa(d)       = false;
            matched_hex{d} = adsb_aligned(best_k).hex;
            matched_dR(d)  = det_R(d) - adsb_aligned(best_k).R_excess_m( ...
                                  findNearest(adsb_aligned(best_k).t_abs_s, t_d));
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
        cpi_visible = ac.t_abs_s(~isnan(ac.R_excess_m));
        if isempty(cpi_visible)
            continue
        end
        % Unique CPI times that had a TP match for this aircraft
        tp_times = det_t(strcmp(matched_hex, ac.hex));
        % Miss = visible CPIs with no associated TP (within 1 CPI time step)
        min_dt_cpi = median(diff(ac.t_abs_s));   % typical CPI interval
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

    % ── Assemble output ───────────────────────────────────────────────────
    metrics.n_tp               = sum(is_tp);
    metrics.n_fa               = sum(is_fa);
    metrics.n_miss             = sum(ac_miss);
    metrics.det_range_err_m    = matched_dR(is_tp);
    metrics.det_doppler_err_hz = matched_df(is_tp);

    metrics.det_table = table( ...
        det_t, det_R, det_f, matched_hex, is_tp, is_fa, ...
        'VariableNames', ...
        {'t_abs_s', 'R_excess_m', 'f_D_hz', 'matched_hex', 'is_tp', 'is_fa'});

    % Per-aircraft detection probability table
    ac_hex_list      = {adsb_aligned.hex}.';
    ac_cs_list       = {adsb_aligned.callsign}.';
    ac_n_visible_all = zeros(N_ac, 1);
    for k = 1 : N_ac
        ac = adsb_aligned(k);
        if ~isempty(ac.R_excess_m)
            ac_n_visible_all(k) = sum(~isnan(ac.R_excess_m));
        end
    end
    ac_Pd = ac_tp ./ max(ac_tp + ac_miss, 1);

    metrics.Pd_per_ac = table( ...
        ac_hex_list, ac_cs_list, ac_tp, ac_miss, ac_n_visible_all, ac_Pd, ...
        'VariableNames', ...
        {'hex', 'callsign', 'n_tp', 'n_miss', 'n_visible_cpis', 'Pd'});

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
        disp(metrics.Pd_per_ac(:, {'hex','callsign','n_tp','n_miss','Pd'}));
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

        % Support both track struct layouts used by trackTargets
        if isfield(trk, 'TrackID')
            trk_ids(ti) = trk.TrackID;
        else
            trk_ids(ti) = ti;
        end

        if isfield(trk, 'State')
            t_trk = trk.t_abs_s(:);
            R_trk = trk.State(:, 1);
            if opts.StateIsVelocity
                f_trk = opts.Alpha * trk.State(:, 3);   % vel [m/s] → Hz
            else
                f_trk = trk.State(:, 3);                % already Hz
            end
        else
            continue   % Unexpected format — skip
        end

        if isempty(t_trk)
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
function idx = findNearest(t_vec, t_query)
    [~, idx] = min(abs(t_vec - t_query));
end
