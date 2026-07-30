function adsb_aligned = alignTruthToRadar(adsb_bistatic, t_epoch_utc, t_abs_query)
%ALIGNTRUTHTORADAR  Resample ADS-B bistatic tracks onto the radar pipeline's
%  relative time axis t_abs_s.
%
% ── BACKGROUND ──────────────────────────────────────────────────────────
%  The radar pipeline operates in a recording-relative time coordinate:
%
%    t_abs_s  =  (sample index) / fs   [seconds since start of Part 1]
%
%  ADS-B truth timestamps are UTC Unix seconds (posixtime).  This function:
%    (1) Converts the ADS-B timestamps to recording-relative time by
%        subtracting the epoch returned by getRadarEpoch:
%            t_rel_adsb = adsb_bistatic(k).t_utc  −  t_epoch_utc
%    (2) Uses interp1 (linear, NaN outside the ADS-B data span) to
%        resample R_excess_m and f_D_hz onto t_abs_query.
%
%  The output struct is what assessTruthVsDetections and plotTruthComparison
%  consume — both expect values indexed identically to the radar's CPI grid.
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   adsb_aligned = alignTruthToRadar(adsb_bistatic, t_epoch_utc, t_abs_query)
%
% ── INPUTS ──────────────────────────────────────────────────────────────
%   adsb_bistatic     Struct array from adsbToBistatic.  Required fields:
%                     .hex, .callsign, .t_utc, .R_excess_m, .f_D_hz.
%
%   t_epoch_utc       Scalar double — Unix timestamp of the first sample of
%                     Part 1, from getRadarEpoch.  If NaN, this function
%                     returns an empty struct array and prints a warning.
%
%   t_abs_query       [P×1] or [1×P] double — radar pipeline time axis
%                     [seconds since start of Part 1] at which truth values
%                     are needed.  Typically the t_abs_s vector from
%                     analyzeBistaticData §5–§7 (one entry per CPI).
%
% ── OUTPUTS ─────────────────────────────────────────────────────────────
%   adsb_aligned   Struct array [1 × N_aircraft].  Fields:
%
%     .hex           char    — ICAO hex (carried through)
%     .callsign      char    — callsign (carried through)
%     .t_abs_s       [P×1]   — query time axis (same as t_abs_query)
%     .R_excess_m    [P×1]   — bistatic range excess at each query time [m]
%                              NaN where query is outside the ADS-B span.
%     .f_D_hz        [P×1]   — bistatic Doppler at each query time [Hz]
%                              NaN where query is outside the ADS-B span.
%     .t_rel_adsb    [M×1]   — recording-relative timestamps of the raw
%                              ADS-B fixes (diagnostic: plot to check overlap)
%     .overlap_s     scalar  — overlap duration [s] between ADS-B track and
%                              radar window (0 if no overlap)
%
%   Aircraft with no overlap with t_abs_query are retained in the output
%   struct but will have all-NaN R_excess_m and f_D_hz arrays — callers
%   should check overlap_s before including them in analyses.
%
% ── NOTES ───────────────────────────────────────────────────────────────
%  • interp1 with 'linear' and 'extrap' = NaN is equivalent to
%    method 'linear' with a bounds check.
%  • ADS-B fixes typically arrive every 1–3 s; the radar CPI grid is
%    typically every 0.1–0.5 s.  Linear interpolation is sufficient for
%    smooth aircraft trajectories.
%  • The overlap_s diagnostic is useful for quick sanity checks when
%    debugging time-sync issues between the radar and ADS-B loggers.
%
% See also: loadADSBTruth, adsbToBistatic, getRadarEpoch, assessTruthVsDetections.

% =========================================================================
%  0.  Validate inputs
% =========================================================================
if nargin < 3
    error('alignTruthToRadar:missingArg', ...
        'Usage: alignTruthToRadar(adsb_bistatic, t_epoch_utc, t_abs_query)');
end
if isempty(adsb_bistatic)
    adsb_aligned = struct( ...
        'hex', {}, 'callsign', {}, 't_abs_s', {}, ...
        'R_excess_m', {}, 'f_D_hz', {}, 't_rel_adsb', {}, 'overlap_s', {});
    warning('alignTruthToRadar:emptyInput', ...
        'adsb_bistatic is empty — no aircraft to align.');
    return
end
if isnan(t_epoch_utc) || isempty(t_epoch_utc)
    warning('alignTruthToRadar:noEpoch', ...
        ['t_epoch_utc is NaN — cannot convert ADS-B UTC times to radar-relative.\n', ...
         'Run getRadarEpoch first and provide the ManualEpoch if the filename has no time.']);
    adsb_aligned = struct( ...
        'hex', {}, 'callsign', {}, 't_abs_s', {}, ...
        'R_excess_m', {}, 'f_D_hz', {}, 't_rel_adsb', {}, 'overlap_s', {});
    return
end

% Ensure t_abs_query is a column vector
t_abs_query = t_abs_query(:);
P           = numel(t_abs_query);
t_radar_min = min(t_abs_query);
t_radar_max = max(t_abs_query);
radar_span  = t_radar_max - t_radar_min;

fprintf('[alignTruthToRadar] Radar window: t_abs = %.2f – %.2f s (%.1f s total)\n', ...
    t_radar_min, t_radar_max, radar_span);
fprintf('[alignTruthToRadar] Epoch: UTC %.0f  (%s)\n', ...
    t_epoch_utc, ...
    datestr(datetime(t_epoch_utc, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC'), ...
            'yyyy-mm-dd HH:MM:SS UTC'));

% =========================================================================
%  1.  Initialise output struct array
% =========================================================================
N_aircraft    = numel(adsb_bistatic);
adsb_aligned  = struct( ...
    'hex',        {adsb_bistatic.hex}, ...
    'callsign',   {adsb_bistatic.callsign}, ...
    't_abs_s',    cell(1, N_aircraft), ...
    'R_excess_m', cell(1, N_aircraft), ...
    'f_D_hz',     cell(1, N_aircraft), ...
    't_rel_adsb', cell(1, N_aircraft), ...
    'overlap_s',  num2cell(zeros(1, N_aircraft)));

% =========================================================================
%  2.  Per-aircraft alignment
% =========================================================================
for k = 1 : N_aircraft
    bist = adsb_bistatic(k);

    % Pre-populate output regardless of alignment success
    adsb_aligned(k).t_abs_s    = t_abs_query;
    adsb_aligned(k).R_excess_m = NaN(P, 1);
    adsb_aligned(k).f_D_hz     = NaN(P, 1);
    adsb_aligned(k).t_rel_adsb = [];
    adsb_aligned(k).overlap_s  = 0;

    if isempty(bist.t_utc) || isempty(bist.R_excess_m)
        continue
    end

    % ── Convert ADS-B UTC → radar-relative seconds ────────────────────────
    t_rel = bist.t_utc(:) - t_epoch_utc;   % [M×1]  seconds since Part 1 start

    adsb_aligned(k).t_rel_adsb = t_rel;

    % ── Overlap diagnostic ────────────────────────────────────────────────
    adsb_min = min(t_rel);
    adsb_max = max(t_rel);
    overlap_lo = max(adsb_min, t_radar_min);
    overlap_hi = min(adsb_max, t_radar_max);
    overlap_s  = max(0, overlap_hi - overlap_lo);
    has_query_overlap = any(t_abs_query >= adsb_min & t_abs_query <= adsb_max);
    adsb_aligned(k).overlap_s = overlap_s;

    if ~has_query_overlap
        fprintf('[alignTruthToRadar]   %s (%s): NO overlap  (ADS-B span %.1f–%.1f s)\n', ...
            bist.hex, bist.callsign, adsb_min, adsb_max);
        continue
    end

    % ── Interpolate R_excess and f_D onto t_abs_query ─────────────────────
    %  Require at least 2 ADS-B fixes for interp1 to work.
    M = numel(t_rel);
    if M < 2
        fprintf('[alignTruthToRadar]   %s (%s): only 1 fix — cannot interpolate.\n', ...
            bist.hex, bist.callsign);
        continue
    end

    % Collapse duplicate timestamps before interpolation so repeated ADS-B
    % fixes do not break the alignment step. Keeping the first occurrence is
    % sufficient here because the shared bistatic projection already
    % computed the range and Doppler series on the raw track.
    [t_rel_unique, unique_idx] = unique(t_rel, 'stable');
    R_unique = bist.R_excess_m(unique_idx);
    f_unique = bist.f_D_hz(unique_idx);
    if numel(t_rel_unique) < 2
        fprintf('[alignTruthToRadar]   %s (%s): fewer than 2 unique fixes after de-duplication.\n', ...
            bist.hex, bist.callsign);
        continue
    end

    % interp1 will produce NaN outside [min(t_rel), max(t_rel)] automatically
    % when no extrapolation method is requested (default extrap = NaN).
    R_interp = interp1(t_rel_unique, R_unique(:), t_abs_query, 'linear', NaN);
    f_interp = interp1(t_rel_unique, f_unique(:), t_abs_query, 'linear', NaN);

    adsb_aligned(k).R_excess_m = R_interp;
    adsb_aligned(k).f_D_hz     = f_interp;

    n_valid = sum(~isnan(R_interp));
    if overlap_s == 0 && n_valid > 0
        adsb_aligned(k).overlap_s = eps(max(abs([adsb_min, adsb_max, t_radar_min, t_radar_max, 1])));
    end
    fprintf('[alignTruthToRadar]   %s (%s): %.1f s overlap  →  %d/%d valid query points\n', ...
        bist.hex, bist.callsign, adsb_aligned(k).overlap_s, n_valid, P);
end

% ── Summary ───────────────────────────────────────────────────────────────
overlapping = sum([adsb_aligned.overlap_s] > 0);
fprintf('[alignTruthToRadar] Complete: %d/%d aircraft overlap the radar window.\n\n', ...
    overlapping, N_aircraft);

end  % ════════════════════ end alignTruthToRadar ════════════════════
