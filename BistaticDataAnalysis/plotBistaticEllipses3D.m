function plotBistaticEllipses3D(txLLA, rxLLA, detectionTable, varargin)
%PLOTBISTATICELLIPSES3D  Map passive-bistatic-radar iso-range ellipses onto
%  a 3-D geographic globe, colour-coded by file part.
%
% ── BACKGROUND ──────────────────────────────────────────────────────────
%  In a passive bistatic radar (PBR) every constant-range locus is an
%  ELLIPSE whose foci are the HDTV transmitter (Tx) and the surveillance
%  receiver (Rx).  The CAF/RDM range axis gives the *bistatic range excess*:
%
%       R_excess  =  R_tx + R_rx  −  L           [metres]
%
%  where R_tx, R_rx are the target-to-station slant ranges and L is the
%  Tx-Rx baseline.  The corresponding ellipse (with Tx and Rx as foci) has:
%
%       semi-major  a  =  (R_excess + L) / 2
%       focal dist  c  =  L / 2
%       semi-minor  b  =  √(a² − c²)
%
%  This function:
%    1. Establishes Rx as the ENU origin and locates Tx in that frame.
%    2. For every detection, computes the parametric ellipse in the local
%       baseline-aligned frame, rotates it into ENU, and stacks it at an
%       assumed target altitude.
%    3. Back-projects via enu2geodetic to (lat, lon, alt).
%    4. Plots all contours on a geoglobe (3-D globe) or geoaxes (2-D map
%       fallback), colour-coded by Doppler frequency (approaching = cold,
%       receding = warm) so each ellipse conveys the target speed.
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   plotBistaticEllipses3D(txLLA, rxLLA, detectionTable)
%   plotBistaticEllipses3D(___, Name, Value, ...)
%
% ── REQUIRED INPUTS ─────────────────────────────────────────────────────
%   txLLA           [1×3]  HDTV transmitter position:
%                          [latitude_deg, longitude_deg, altitude_m_MSL]
%
%   rxLLA           [1×3]  Surveillance receiver position:
%                          [latitude_deg, longitude_deg, altitude_m_MSL]
%
%   detectionTable  [N×6] double matrix or table with columns:
%       Col 1  range_m   — bistatic range excess from RDM y-axis (m)
%       Col 2  doppler   — Doppler frequency (Hz)
%       Col 3  pwr_db    — detected-cell power (dB, absolute ADC scale)
%       Col 4  blk       — block index within the file part
%       Col 5  t_abs_s   — absolute time since recording start (s)
%       Col 6  part      — file-part number (1, 2, 3, …)
%     This matches the format of all_track_dets produced by
%     analyzeBistaticData.m (columns 1-6).
%
% ── OPTIONAL NAME-VALUE PARAMETERS ──────────────────────────────────────
%   TargetAlt_m     Assumed target altitude MSL [m].
%                   Scalar → same alt for every detection.
%                   [N×1] → individual altitude per detection.
%                   Default: 3000 m  (≈ 10 000 ft; plausible GA or commuter
%                   jet in the 10–150 km coverage zone).
%
%   NEllipsePoints  Parametric points per ellipse contour.  Default: 360.
%                   Use ≥720 for publication figures.
%
%   Basemap         Basemap string for geoglobe/geoaxes.  Default: 'satellite'.
%                   Options: 'topographic', 'openstreetmap', 'streets-light'.
%
%   DopplerColormap MATLAB colormap name used to colour ellipses by the
%                   detection's Doppler frequency.  Cold end = most-negative
%                   Doppler (approaching target); warm end = most-positive
%                   (receding target).  Default: 'jet'.
%                   Options: 'parula', 'cool', 'turbo', 'hsv', etc.
%
%   LineWidth       Ellipse contour line width (pts).  Default: 2.
%
%   Use2DFallback   Set true to force geoaxes 2-D map even when geoglobe
%                   is available.  Default: false.
%
% ── TOOLBOX REQUIREMENTS ────────────────────────────────────────────────
%   Mapping Toolbox  (geodetic2enu, enu2geodetic, wgs84Ellipsoid,
%                     geoglobe, geoplot3, geoaxes, geoplot)
%
% ── EXAMPLE ─────────────────────────────────────────────────────────────
%   Run test_plotBistaticEllipses3D() (defined at end of this file):
%
%       addpath('<repo>/flightTest/BistaticDataAnalysis');
%       test_plotBistaticEllipses3D();
%
% See also: geodetic2enu, enu2geodetic, geoglobe, geoaxes, geoplot3.

% =========================================================================
%  0.  Input Validation & Default Parameters
% =========================================================================
p = inputParser;
p.FunctionName = mfilename;

addRequired(p, 'txLLA',  @(x) isnumeric(x) && numel(x) == 3);
addRequired(p, 'rxLLA',  @(x) isnumeric(x) && numel(x) == 3);
addRequired(p, 'detectionTable', ...
    @(x) (isnumeric(x) && size(x,2) >= 6) || istable(x));

addParameter(p, 'TargetAlt_m',    3000,      @(x) isnumeric(x) && all(x(:) >= 0));
addParameter(p, 'NEllipsePoints',  360,       @(x) isnumeric(x) && isscalar(x) && x >= 10);
addParameter(p, 'Basemap',        'satellite', @ischar);
addParameter(p, 'DopplerColormap', 'jet',      @ischar);
addParameter(p, 'LineWidth',       2,          @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Use2DFallback',   false,      @islogical);
addParameter(p, 'Verbose',         false,      @islogical);
addParameter(p, 'ADSBTracks',      [],         @(x) isstruct(x) || isempty(x));

parse(p, txLLA, rxLLA, detectionTable, varargin{:});
opts = p.Results;
vb   = opts.Verbose;   % shorthand for verbose flag

% Convert table -> matrix if needed
if istable(detectionTable)
    dtMat = detectionTable{:, 1:6};
else
    dtMat = double(detectionTable(:, 1:6));
end

range_m  = dtMat(:, 1);
dopp_hz  = dtMat(:, 2);
t_abs_s  = dtMat(:, 5);
part_idx = round(dtMat(:, 6));
N_dets   = size(dtMat, 1);

% Expand scalar target altitude to per-detection column vector
tgt_alt = opts.TargetAlt_m(:);
if isscalar(tgt_alt)
    tgt_alt = repmat(tgt_alt, N_dets, 1);
elseif numel(tgt_alt) ~= N_dets
    error('plotBistaticEllipses3D:altSizeMismatch', ...
        'TargetAlt_m must be scalar or [%d×1]; received [%d×1].', ...
        N_dets, numel(tgt_alt));
end

% =========================================================================
%  1.  ENU Geometry — Rx as the Local Cartesian Origin
% =========================================================================
% All bistatic ellipse maths is performed in a flat-Earth ENU frame centred
% on the receiver.  Error vs. full ellipsoidal geometry is < 0.05 % for
% baselines under 200 km — well within the ~30 m range-cell resolution.

spheroid = wgs84Ellipsoid('meter');

% Transform Tx into ENU.  geodetic2enu returns displacement [East, North, Up]
% of the query point relative to the reference point (rxLLA), in metres.
[txE, txN, txU] = geodetic2enu( ...
    txLLA(1), txLLA(2), txLLA(3), ...
    rxLLA(1), rxLLA(2), rxLLA(3), spheroid);

% Horizontal baseline length and bearing (ignoring small vertical component)
L     = hypot(txE, txN);      % [m] — Tx-Rx horizontal separation
theta = atan2(txN, txE);      % [rad] — baseline angle, CCW from East

% 2-D rotation matrix: local ellipse frame ──> ENU horizontal plane
%   In the local frame: x̂ points along the Tx-Rx baseline (major axis),
%                       ŷ is perpendicular (minor axis).
R2 = [cos(theta), -sin(theta);
      sin(theta),  cos(theta)];

% Ellipse centre in ENU: the midpoint of the two foci (Rx at origin, Tx at
% [txE, txN]), so the centre is at [txE/2, txN/2].
midE = txE / 2;
midN = txN / 2;

if vb
    fprintf('\n[%s] Bistatic geometry:\n', mfilename);
    fprintf('  Tx ENU from Rx  :  E=%.1f m,  N=%.1f m,  U=%.1f m\n', txE, txN, txU);
    fprintf('  Baseline L      :  %.3f km   bearing  %.1f\u00b0 (CCW from East)\n', ...
        L/1e3, rad2deg(theta));
end

% =========================================================================
%  2.  Parametric Ellipse Contours — Geodetic Back-Projection
% =========================================================================
% phi is the parametric angle traversing the full ellipse.  The canonical
% parametric form is:
%   x_local = a·cos(φ)   (along Tx-Rx baseline / major axis)
%   y_local = b·sin(φ)   (perpendicular to baseline / minor axis)

phi = linspace(0, 2*pi, opts.NEllipsePoints)';   % [NEllipsePoints × 1]

% Pre-allocate per-detection geodetic contour storage
ellipse_lat = cell(N_dets, 1);
ellipse_lon = cell(N_dets, 1);
ellipse_alt = cell(N_dets, 1);

for k = 1 : N_dets
    r_exc = range_m(k);   % bistatic range excess [m] from the RDM y-axis

    % ── Ellipse semi-axes ────────────────────────────────────────────────
    %  a: semi-major — half the total Tx→target→Rx path length
    %  c: focal half-distance — half the Tx-Rx baseline
    %  b: semi-minor — from the ellipse Pythagorean identity a²=b²+c²
    a = (r_exc + L) / 2;
    c = L / 2;

    % A detection with R_excess < 0 is non-physical (implies the total
    % bistatic path is shorter than the baseline — impossible in free space).
    if a <= c
        warning('plotBistaticEllipses3D:insideBaseline', ...
            'Detection %d: R_excess=%.0f m gives a=%.0f m ≤ c=%.0f m. Skipped.', ...
            k, r_exc, a, c);
        ellipse_lat{k} = NaN;
        ellipse_lon{k} = NaN;
        ellipse_alt{k} = NaN;
        continue
    end

    b = sqrt(a^2 - c^2);

    % ── Parametric ellipse in local baseline-aligned 2-D frame ──────────
    x_loc = a * cos(phi);   % [NEllipsePoints × 1]  along major axis
    y_loc = b * sin(phi);   % [NEllipsePoints × 1]  along minor axis

    % ── Rotate into the ENU horizontal plane ────────────────────────────
    %   R2 aligns the local x-axis with the Tx-Rx bearing.
    xy_enu = R2 * [x_loc'; y_loc'];   % [2 × NEllipsePoints]

    % ── Translate so the ellipse centre sits at the Tx-Rx midpoint ───────
    enu_e = xy_enu(1, :)' + midE;    % [NEllipsePoints × 1]
    enu_n = xy_enu(2, :)' + midN;

    % ── Vertical component ───────────────────────────────────────────────
    %   enu2geodetic expects the ENU 'Up' displacement from the reference
    %   point (rxLLA).  Setting it to (target_alt_MSL − rx_alt_MSL) places
    %   all ellipse points at the desired absolute altitude.
    enu_u = repmat(tgt_alt(k) - rxLLA(3), opts.NEllipsePoints, 1);

    % ── Back-project ENU → geodetic ─────────────────────────────────────
    [lat_pts, lon_pts, alt_pts] = enu2geodetic( ...
        enu_e, enu_n, enu_u, ...
        rxLLA(1), rxLLA(2), rxLLA(3), spheroid);

    ellipse_lat{k} = lat_pts;
    ellipse_lon{k} = lon_pts;
    ellipse_alt{k} = alt_pts;
end

% =========================================================================
%  3.  Visualisation
% =========================================================================
% ── Per-detection Doppler colour mapping ─────────────────────────────────
%   Each ellipse is coloured by the detection's Doppler frequency so the
%   globe gives an at-a-glance speed map of every CFAR hit:
%     cold end of the colormap  →  most-negative Doppler  (approaching)
%     warm end of the colormap  →  most-positive Doppler  (receding)
N_clr      = 256;
cmap_table = feval(opts.DopplerColormap, N_clr);   % [256 × 3] RGB
dopp_lo = min(dopp_hz);
dopp_hi = max(dopp_hz);
if dopp_lo == dopp_hi
    dopp_lo = dopp_lo - 1;   % guard against zero-range colourmap
    dopp_hi = dopp_hi + 1;
end
dopp_norm  = (dopp_hz - dopp_lo) ./ (dopp_hi - dopp_lo);   % [0, 1]
color_idx  = max(1, min(N_clr, floor(dopp_norm * (N_clr - 1)) + 1));
det_colors = cmap_table(color_idx, :);   % [N_dets × 3] — one RGB row per detection

parts   = unique(part_idx, 'sorted');
N_parts = numel(parts);

% ── Decide 3-D globe or 2-D map fallback ─────────────────────────────────
use_globe = ~opts.Use2DFallback && ...
    (exist('geoglobe', 'file') == 2 || exist('geoglobe', 'builtin') == 3);

if use_globe
    uif  = uifigure( ...
        'Name',     'Passive Bistatic Radar — Ellipse Trajectory (3D Globe)', ...
        'Position', [50, 50, 1280, 720]);
    gObj = geoglobe(uif, 'Basemap', opts.Basemap, 'Terrain', 'gmted2010');
    hold(gObj, 'on');
    if vb, fprintf('[%s] Rendering on geoglobe 3-D globe.\n', mfilename); end
else
    figH = figure( ...
        'Name',     'Passive Bistatic Radar — Ellipse Trajectory (2D Map)', ...
        'Position', [50, 50, 1280, 720]);
    gObj = geoaxes(figH, 'Basemap', opts.Basemap);
    hold(gObj, 'on');
    fprintf('[%s] geoglobe unavailable or disabled; rendering on geoaxes 2-D map.\n', ...
        mfilename);
end

% ── Station markers ──────────────────────────────────────────────────────
if use_globe
    geoplot3(gObj, txLLA(1), txLLA(2), txLLA(3)+200, ...
        'ro', 'MarkerSize', 16, 'LineWidth', 2);
    geoplot3(gObj, rxLLA(1), rxLLA(2), rxLLA(3)+200, ...
        'bo', 'MarkerSize', 12, 'LineWidth', 2);
    geoplot3(gObj, [txLLA(1), rxLLA(1)], [txLLA(2), rxLLA(2)], ...
        [txLLA(3)+50, rxLLA(3)+50], 'w-', 'LineWidth', 1);
else
    h_tx_marker = geoplot(gObj, txLLA(1), txLLA(2), ...
        'r^', 'MarkerSize', 14, 'MarkerFaceColor', 'red', 'LineWidth', 2, ...
        'DisplayName', 'Tx — HDTV Tower');
    h_rx_marker = geoplot(gObj, rxLLA(1), rxLLA(2), ...
        'bs', 'MarkerSize', 12, 'MarkerFaceColor', [0.20 0.45 0.90], 'LineWidth', 2, ...
        'DisplayName', 'Rx — Surveillance Site');
    geoplot(gObj, [txLLA(1), rxLLA(1)], [txLLA(2), rxLLA(2)], ...
        'w--', 'LineWidth', 1, 'HandleVisibility', 'off');
end

% ── Ellipse contours — one per detection, coloured by Doppler ────────────
for k = 1 : N_dets
    if isscalar(ellipse_lat{k}) && isnan(ellipse_lat{k})
        continue
    end
    clr = det_colors(k, :);
    if use_globe
        lat_row    = ellipse_lat{k}';
        lon_row    = ellipse_lon{k}';
        N_pts      = numel(lat_row);
        ribbon_bot = tgt_alt(k) - 250;
        ribbon_top = tgt_alt(k) + 250;
        for alt_step = ribbon_bot : 50 : ribbon_top
            geoplot3(gObj, lat_row, lon_row, ...
                alt_step * ones(1, N_pts), ...
                'Color', clr, 'LineWidth', opts.LineWidth);
        end
    else
        geoplot(gObj, ellipse_lat{k}, ellipse_lon{k}, ...
            'Color', clr, 'LineWidth', opts.LineWidth, ...
            'HandleVisibility', 'off');
    end
end

% ── Doppler colour-scale legend (companion figure, works for both modes) ──
fig_cb = figure('Name', 'Doppler Colour Scale', ...
    'Position',  [1340, 50, 90, 420], ...
    'Color',     [0.12, 0.12, 0.12], ...
    'MenuBar',   'none', ...
    'ToolBar',   'none');
ax_cb = axes(fig_cb, 'Position', [0.05, 0.05, 0.35, 0.88], ...
    'Visible', 'off', 'Color', 'none');
colormap(ax_cb, cmap_table);
clim(ax_cb, [dopp_lo, dopp_hi]);
cb              = colorbar(ax_cb, 'eastoutside');
cb.Label.String = 'Doppler  (Hz)';
cb.Label.Color  = [0.90, 0.90, 0.90];
cb.Color        = [0.90, 0.90, 0.90];
cb.FontSize     = 10;

% ── Title / console summary ───────────────────────────────────────────────
if use_globe
    scene_lat = mean([txLLA(1), rxLLA(1)]);
    scene_lon = mean([txLLA(2), rxLLA(2)]);
    try
        campos(gObj, scene_lat, scene_lon, 250e3);
    catch
        % campos unavailable in this MATLAB version — keep default view
    end
    fprintf('\n─── FIGURE LEGEND ───────────────────────────────────────\n');
    fprintf('  Tx  [%.4f°, %.4f°, %.0f m MSL]  (red  circle)\n', ...
        txLLA(1), txLLA(2), txLLA(3));
    fprintf('  Rx  [%.4f°, %.4f°, %.0f m MSL]  (blue circle)\n', ...
        rxLLA(1), rxLLA(2), rxLLA(3));
    fprintf('  Baseline L = %.3f km\n', L/1e3);
    fprintf('  Colour = Doppler (Hz)   map: %s\n', opts.DopplerColormap);
    fprintf('  %.1f Hz (cold / approaching)  →  %.1f Hz (warm / receding)\n', ...
        dopp_lo, dopp_hi);
    fprintf('─────────────────────────────────────────────────────────\n');
else
    hold(gObj, 'off');
    legend(gObj, [h_tx_marker, h_rx_marker], ...
        {'Tx — HDTV Tower', 'Rx — Surveillance Site'}, ...
        'Location',  'northwest', ...
        'FontSize',   9, ...
        'Color',      [0.10, 0.10, 0.10], ...
        'TextColor',  'white');
    title(gObj, sprintf( ...
        'Bistatic Ellipses — %d det.  |  %d parts  |  L=%.1f km  |  colour = Doppler (Hz)', ...
        N_dets, N_parts, L/1e3));
    grid(gObj, 'on');
end

fprintf('[%s] Complete — rendered %d ellipses  (Doppler: %.1f to %.1f Hz).\n\n', ...
    mfilename, N_dets, dopp_lo, dopp_hi);

% ── ADS-B truth track overlay (optional) ────────────────────────────────
%  Pass 'ADSBTracks', adsb_bistatic (from adsbToBistatic) to overlay each
%  aircraft's geographic path on the basemap for visual cross-check.
if ~isempty(opts.ADSBTracks)
    ac_clr = lines(numel(opts.ADSBTracks));
    for ka = 1 : numel(opts.ADSBTracks)
        ac = opts.ADSBTracks(ka);
        if isempty(ac.lat_deg) || numel(ac.lat_deg) < 2
            continue
        end
        alt_plot = ac.alt_m + 200;   % 200 m lift so path sits above terrain
        if use_globe
            geoplot3(gObj, ac.lat_deg, ac.lon_deg, alt_plot, ...
                '-', 'Color', ac_clr(ka, :), 'LineWidth', 2);
        else
            geoplot(gObj, ac.lat_deg, ac.lon_deg, ...
                '-', 'Color', ac_clr(ka, :), 'LineWidth', 2);
        end
        label_ac = ac.callsign;
        if isempty(strtrim(label_ac))
            label_ac = ac.hex;
        end
        if vb
            fprintf('[%s]   ADS-B track: %s (%s)  %d fixes\n', ...
                mfilename, label_ac, ac.hex, numel(ac.lat_deg));
        end
    end
    fprintf('[%s] ADS-B overlay: %d aircraft tracks drawn.\n', ...
        mfilename, numel(opts.ADSBTracks));
end

end  % ════════════════════ end plotBistaticEllipses3D ════════════════════


% =========================================================================
%  VERIFICATION HARNESS
%  Run test_plotBistaticEllipses3D() from the MATLAB Command Window to
%  exercise the function with values drawn from the Newton-dataset
%  Pfa=1e-4 run (600 MHz HDTV, 5 Msps, garage deployment, 5 Jul 2026).
% =========================================================================
function test_plotBistaticEllipses3D()
%TEST_PLOTBISTATICELLIPSES3D  Quick end-to-end verification.
%
% USAGE:
%   addpath('<repo>/flightTest/BistaticDataAnalysis');
%   test_plotBistaticEllipses3D();
%
% UPDATE txLLA / rxLLA with your actual site survey coordinates before
% comparing against truth.  The values below are approximate placeholders
% consistent with a Newton MA deployment receiving WNAC-DT (Fox 25)
% transmissions at 600 MHz.

fprintf('=== test_plotBistaticEllipses3D ===\n');

% ── Site Coordinates ──────────────────────────────────────────────────────
% Tx:  WNAC-DT broadcast tower, Needham Heights MA  (~600 MHz HDTV)
%      *** UPDATE with surveyed coordinates for production use ***
txLLA = [42.2791, -71.2322, 195];   % [lat°N, lon° (negative = West), alt m MSL]

% Rx:  Parking-garage deployment, Newton MA (approximate rooftop)
rxLLA = [42.3490, -71.2070,  42];   % [lat°N, lon°, alt m MSL]

% Baseline sanity check (printed, not plotted)
spheroid_test = wgs84Ellipsoid('meter');
[tE, tN, ~]   = geodetic2enu(txLLA(1), txLLA(2), txLLA(3), ...
                              rxLLA(1), rxLLA(2), rxLLA(3), spheroid_test);
L_test = hypot(tE, tN);
fprintf('  Tx ENU from Rx  :  [%.1f m E, %.1f m N]\n', tE, tN);
fprintf('  Baseline L      :  %.3f km\n\n', L_test/1e3);

% ── Detection Table ───────────────────────────────────────────────────────
% Three key candidate detections from the 27-detection Pfa=1e-4 run,
% selected because they show a smooth, temporally consistent outbound range
% progression (7 km → 9 km → 12 km over ~1.7 s ≈ aircraft at ~250 m/s).
%
% Columns: [range_m, doppler_hz, pwr_db, blk, t_abs_s, part]
%
%   range_m   : bistatic range excess from the RDM y-axis (what you pass in)
%   t_abs_s   : absolute time since start of Part 1 -ecording
%   part      : file-part number (determines colour: 1=blue, 2=green, 3=magenta)
%
% NOTE: doppler / pwr_db are carried for context but not used by the
%       plotting function itself — they are available for annotation.
detTable = [ ...
%  range_m   dopp_hz   pwr_db   blk   t_abs_s   part
    7075,     -42.0,   226.5,    1,    0.450,    1;   % Part 1 - first track candidate
    9294,     -51.0,   225.8,    1,    1.150,    2;   % Part 2 - mid-track
   11692,     -63.0,   225.2,    1,    2.150,    3;   % Part 3 - latest / furthest
];

fprintf('  Detections:\n');
fprintf('  %8s  %9s  %8s  %4s  %9s  %4s\n', ...
    'range_km', 'dopp_hz', 'pwr_dB', 'blk', 't_abs_s', 'part');
for k = 1 : size(detTable, 1)
    fprintf('  %8.3f  %9.1f  %8.1f  %4d  %9.3f  %4d\n', ...
        detTable(k,1)/1e3, detTable(k,2), detTable(k,3), ...
        detTable(k,4), detTable(k,5), detTable(k,6));
end
fprintf('\n');

% ── Call the function ─────────────────────────────────────────────────────
plotBistaticEllipses3D(txLLA, rxLLA, detTable, ...
    'TargetAlt_m',    3000, ...    % 10 000 ft assumed altitude
    'NEllipsePoints',  720, ...    % smooth contours for inspection
    'Basemap',        'satellite', ...
    'LineWidth',       2.5);

fprintf('=== test complete ===\n');
end  % ════════════════════ end test_plotBistaticEllipses3D ═════════════
