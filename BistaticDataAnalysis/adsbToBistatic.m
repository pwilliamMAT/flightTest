function adsb_bistatic = adsbToBistatic(adsb_tracks, txLLA, rxLLA, fc)
%ADSBTOBISTATIC  Project ADS-B aircraft tracks into passive bistatic radar
%  measurement space: bistatic range excess R_excess and Doppler f_D.
%
% ── BACKGROUND ──────────────────────────────────────────────────────────
%  The passive bistatic radar measures two scalars per detection:
%
%    R_excess  =  R_tx + R_rx  −  L       [m]   (from CAF range axis)
%    f_D       =  (2·fc/c) · dR_excess/dt [Hz]  (from CAF Doppler axis)
%
%  where R_tx is the slant range from the HDTV transmitter (Tx) to the
%  target, R_rx is the slant range from the surveillance receiver (Rx) to
%  the target, L is the Tx-Rx baseline, fc is the carrier frequency, and c
%  is the speed of light.
%
%  Given an ADS-B position fix (lat, lon, alt), this function computes
%  R_excess directly from geometry.  The bistatic Doppler is then derived
%  by numerically differentiating the R_excess time series:
%
%    f_D ≈ (2·fc/c) · ΔR_excess / Δt
%
%  This avoids any ambiguity in the bistatic Doppler formula (monostatic
%  factor of 2 vs. bistatic (cos β_tx + cos β_rx)) and is exactly
%  consistent with the radar code's Doppler axis convention:
%    α = 2·fc/c   [Hz/(m/s)] used throughout analyzeBistaticData.m
%
% ── ENU GEOMETRY ────────────────────────────────────────────────────────
%  All computations use the same WGS-84 ENU frame as plotBistaticEllipses3D:
%    Origin     = Rx (surveillance receiver)
%    +East, +North, +Up axes aligned with the local geodetic frame
%  This flat-Earth approximation introduces < 0.05% error for baselines
%  under 200 km — negligible vs. the ~30 m radar range-cell resolution.
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   adsb_bistatic = adsbToBistatic(adsb_tracks, txLLA, rxLLA, fc)
%
% ── INPUTS ──────────────────────────────────────────────────────────────
%   adsb_tracks   Struct array from loadADSBTruth.  Each element has
%                 fields: .hex, .callsign, .t_utc, .lat_deg, .lon_deg,
%                 .alt_m (required); .speed_mps, .track_deg, .vrate_mps
%                 (optional; only used for diagnostic cross-check).
%
%   txLLA         [1×3] Transmitter position [lat_deg, lon_deg, alt_m_MSL].
%
%   rxLLA         [1×3] Receiver position    [lat_deg, lon_deg, alt_m_MSL].
%
%   fc            Carrier frequency [Hz].  Needed for the α = 2fc/c
%                 Doppler coupling factor.
%
% ── OUTPUTS ─────────────────────────────────────────────────────────────
%   adsb_bistatic   Struct array [1 × N_aircraft] — same indexing as
%                   adsb_tracks but projected into bistatic measurement
%                   space.  Fields:
%
%     .hex           char   — ICAO hex address (carried through)
%     .callsign      char   — callsign         (carried through)
%     .t_utc         [M×1]  — UTC epoch seconds at each valid fix
%     .R_excess_m    [M×1]  — bistatic range excess [m]
%     .f_D_hz        [M×1]  — bistatic Doppler [Hz]  (positive = receding)
%     .lat_deg       [M×1]  — WGS-84 latitude  (carried through)
%     .lon_deg       [M×1]  — WGS-84 longitude (carried through)
%     .alt_m         [M×1]  — altitude MSL [m]  (carried through)
%     .L_m           scalar — Tx-Rx baseline length [m] (diagnostic)
%
%   Fixes where R_excess < 0 (physically impossible: total path < baseline)
%   are removed.  Fixes where altitude is NaN are removed.
%
% ── TOOLBOX REQUIREMENTS ────────────────────────────────────────────────
%   Mapping Toolbox  (geodetic2enu, wgs84Ellipsoid)
%
% ── EXAMPLE ─────────────────────────────────────────────────────────────
%   txLLA = [42.310278, -71.236667, 431.9];
%   rxLLA = [42.2999333, -71.349333, 15.0];
%   fc    = 600e6;   % 600 MHz ATSC channel
%   bist  = adsbToBistatic(adsb_tracks, txLLA, rxLLA, fc);
%   fprintf('Aircraft %s: %.0f–%.0f km bistatic range\n', ...
%       bist(1).hex, min(bist(1).R_excess_m)/1e3, max(bist(1).R_excess_m)/1e3);
%
% See also: loadADSBTruth, alignTruthToRadar, plotBistaticEllipses3D.

% =========================================================================
%  0.  Validate inputs
% =========================================================================
if nargin < 4
    error('adsbToBistatic:missingArg', ...
        'Usage: adsbToBistatic(adsb_tracks, txLLA, rxLLA, fc)');
end
if ~(isnumeric(txLLA) && numel(txLLA) == 3)
    error('adsbToBistatic:badTxLLA', 'txLLA must be a [1×3] numeric vector.');
end
if ~(isnumeric(rxLLA) && numel(rxLLA) == 3)
    error('adsbToBistatic:badRxLLA', 'rxLLA must be a [1×3] numeric vector.');
end
if ~(isnumeric(fc) && isscalar(fc) && fc > 0)
    error('adsbToBistatic:badFc', 'fc must be a positive scalar (Hz).');
end
if isempty(adsb_tracks)
    adsb_bistatic = struct( ...
        'hex', {}, 'callsign', {}, 't_utc', {}, 'R_excess_m', {}, ...
        'f_D_hz', {}, 'lat_deg', {}, 'lon_deg', {}, 'alt_m', {}, 'L_m', {});
    return
end

% =========================================================================
%  1.  One-time bistatic geometry setup (same as plotBistaticEllipses3D §1)
% =========================================================================
spheroid = wgs84Ellipsoid('meter');
c_light  = physconst('LightSpeed');   % 299 792 458 m/s
alpha    = 2 * fc / c_light;          % Doppler coupling [Hz/(m/s)], α = 2fc/c

% Locate Tx in the Rx-centred ENU frame.
[txE, txN, txU] = geodetic2enu( ...
    txLLA(1), txLLA(2), txLLA(3), ...
    rxLLA(1), rxLLA(2), rxLLA(3), spheroid);

% Horizontal baseline (same approximation as plotBistaticEllipses3D)
L = hypot(txE, txN);   % [m]

fprintf('[adsbToBistatic] Baseline L = %.3f km  |  α = %.4f Hz/(m/s)  |  fc = %.0f MHz\n', ...
    L/1e3, alpha, fc/1e6);

% =========================================================================
%  2.  Per-aircraft bistatic projection
% =========================================================================
N_aircraft    = numel(adsb_tracks);
adsb_bistatic = struct( ...
    'hex',        {adsb_tracks.hex}, ...
    'callsign',   {adsb_tracks.callsign}, ...
    't_utc',      cell(1, N_aircraft), ...
    'R_excess_m', cell(1, N_aircraft), ...
    'f_D_hz',     cell(1, N_aircraft), ...
    'lat_deg',    cell(1, N_aircraft), ...
    'lon_deg',    cell(1, N_aircraft), ...
    'alt_m',      cell(1, N_aircraft), ...
    'L_m',        num2cell(repmat(L, 1, N_aircraft)));

for k = 1 : N_aircraft
    trk = adsb_tracks(k);

    t_pos   = trk.t_utc;
    lat_pos = trk.lat_deg;
    lon_pos = trk.lon_deg;
    alt_pos = trk.alt_m;

    if isempty(t_pos)
        continue
    end

    % ── Remove fixes with NaN altitude ───────────────────────────────────
    valid = ~isnan(lat_pos) & ~isnan(lon_pos) & ~isnan(alt_pos);
    if ~any(valid)
        warning('adsbToBistatic:noValidAlt', ...
            'Aircraft %s: all position fixes have NaN altitude — skipped.', ...
            trk.hex);
        continue
    end
    t_pos   = t_pos(valid);
    lat_pos = lat_pos(valid);
    lon_pos = lon_pos(valid);
    alt_pos = alt_pos(valid);

    N_pos = numel(t_pos);

    % ── R_rx: range from Rx (origin) to aircraft ─────────────────────────
    %  In the Rx-centred ENU frame, Rx is at [0, 0, 0].  The aircraft's ENU
    %  displacement from Rx is therefore its ENU position directly.
    [ac_e_rx, ac_n_rx, ac_u_rx] = geodetic2enu( ...
        lat_pos, lon_pos, alt_pos, ...
        rxLLA(1), rxLLA(2), rxLLA(3), spheroid);

    R_rx_m = sqrt(ac_e_rx.^2 + ac_n_rx.^2 + ac_u_rx.^2);   % [N_pos×1]

    % ── R_tx: range from Tx to aircraft ──────────────────────────────────
    %  Compute ENU displacement of the aircraft relative to the Tx position.
    [ac_e_tx, ac_n_tx, ac_u_tx] = geodetic2enu( ...
        lat_pos, lon_pos, alt_pos, ...
        txLLA(1), txLLA(2), txLLA(3), spheroid);

    R_tx_m = sqrt(ac_e_tx.^2 + ac_n_tx.^2 + ac_u_tx.^2);   % [N_pos×1]

    % ── Bistatic range excess ─────────────────────────────────────────────
    %  R_excess = R_tx + R_rx − L
    %  A negative R_excess is non-physical (would require the total path to
    %  be shorter than the direct baseline — impossible in free space).
    %  This can occur for aircraft very close to the baseline or below the
    %  horizon from one station; these fixes are discarded.
    R_excess_m = R_tx_m + R_rx_m - L;   % [N_pos×1]

    physical = R_excess_m > 0;
    if ~any(physical)
        warning('adsbToBistatic:allInsideBaseline', ...
            'Aircraft %s: all fixes yield R_excess ≤ 0 — inside baseline.  Skipped.', ...
            trk.hex);
        continue
    end
    if any(~physical)
        n_skip = sum(~physical);
        warning('adsbToBistatic:someInsideBaseline', ...
            'Aircraft %s: %d/%d fixes have R_excess ≤ 0 and will be removed.', ...
            trk.hex, n_skip, N_pos);
        t_pos      = t_pos(physical);
        lat_pos    = lat_pos(physical);
        lon_pos    = lon_pos(physical);
        alt_pos    = alt_pos(physical);
        R_excess_m = R_excess_m(physical);
    end

    N_valid = numel(t_pos);

    % ── Bistatic Doppler via numerical differentiation of R_excess ────────
    %  f_D = α · dR_excess/dt   where  α = 2·fc/c
    %
    %  Numerical scheme: central differences at interior points, forward/
    %  backward differences at the endpoints.  This is equivalent to
    %  convolution with the [-1/2, 0, +1/2] / dt stencil.
    %
    %  ADS-B position update rate is typically 0.5–2 Hz (1–2 s between fixes).
    %  At this rate, a 300 m/s aircraft changes R_excess by up to 600 m/s,
    %  producing Doppler rates well within the stencil's accuracy envelope.
    %
    %  Sign convention: positive Doppler → R_excess increasing → target receding.
    %  This matches the Doppler axis in the RDM and the tracker's α·Ṙ convention.
    dRdt = zeros(N_valid, 1);
    if N_valid >= 2
        dt_vec = diff(t_pos);   % [N_valid-1 × 1]  seconds between fixes

        % Guard against duplicate or zero-gap timestamps (should have been
        % removed by loadADSBTruth, but defend again here)
        dt_vec = max(dt_vec, 0.001);   % floor at 1 ms

        dR_vec  = diff(R_excess_m);    % [N_valid-1 × 1]  metres

        % Forward difference at first point
        dRdt(1) = dR_vec(1) / dt_vec(1);

        % Backward difference at last point
        dRdt(N_valid) = dR_vec(end) / dt_vec(end);

        % Central difference at interior points
        if N_valid > 2
            dRdt(2:N_valid-1) = ...
                (R_excess_m(3:end) - R_excess_m(1:end-2)) ./ ...
                (t_pos(3:end)      - t_pos(1:end-2));
        end
    end
    f_D_hz = alpha * dRdt;   % [N_valid×1]  Hz

    % ── Store results ─────────────────────────────────────────────────────
    adsb_bistatic(k).t_utc      = t_pos;
    adsb_bistatic(k).R_excess_m = R_excess_m;
    adsb_bistatic(k).f_D_hz     = f_D_hz;
    adsb_bistatic(k).lat_deg    = lat_pos;
    adsb_bistatic(k).lon_deg    = lon_pos;
    adsb_bistatic(k).alt_m      = alt_pos;

    fprintf('[adsbToBistatic]   %s (%s): %d fixes  R=%.1f–%.1f km  f_D=%.1f–%.1f Hz\n', ...
        trk.hex, trk.callsign, N_valid, ...
        min(R_excess_m)/1e3, max(R_excess_m)/1e3, ...
        min(f_D_hz), max(f_D_hz));
end

% Remove aircraft with no valid bistatic data
has_data = ~cellfun(@isempty, {adsb_bistatic.t_utc});
adsb_bistatic = adsb_bistatic(has_data);

fprintf('[adsbToBistatic] Complete: %d aircraft projected into bistatic space.\n\n', ...
    numel(adsb_bistatic));

end  % ════════════════════ end adsbToBistatic ════════════════════
