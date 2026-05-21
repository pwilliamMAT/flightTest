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
%       fallback), colour-coded Part1=blue, Part2=green, Part3=magenta.
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
%   PartColors      [Nparts×3] RGB colour array, one row per unique part.
%                   Default: [blue; green; magenta].
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

% Default colour table: Part1=blue, Part2=green, Part3=magenta
defaultColors = [0.20, 0.45, 0.90; ...  % Part 1 - blue
                 0.10, 0.75, 0.30; ...  % Part 2 - green
                 0.85, 0.10, 0.85];    % Part 3 - magenta

addParameter(p, 'TargetAlt_m',    3000,         @(x) isnumeric(x) && all(x(:) >= 0));
addParameter(p, 'NEllipsePoints',  360,          @(x) isnumeric(x) && isscalar(x) && x >= 10);
addParameter(p, 'Basemap',        'satellite',   @ischar);
addParameter(p, 'PartColors',      defaultColors, @(x) isnumeric(x) && size(x,2) == 3);
addParameter(p, 'LineWidth',       2,             @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Use2DFallback',   false,         @islogical);

parse(p, txLLA, rxLLA, detectionTable, varargin{:});
opts = p.Results;

% Convert table -> matrix if needed
if istable(detectionTable)
    dtMat = detectionTable{:, 1:6};
else
    dtMat = double(detectionTable(:, 1:6));
end

range_m  = dtMat(:, 1);
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

fprintf('\n[%s] Bistatic geometry:\n', mfilename);
fprintf('  Tx ENU from Rx  :  E=%.1f m,  N=%.1f m,  U=%.1f m\n', txE, txN, txU);
fprintf('  Baseline L      :  %.3f km   bearing  %.1f° (CCW from East)\n', ...
    L/1e3, rad2deg(theta));

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
parts   = unique(part_idx, 'sorted');
N_parts = numel(parts);

% Pad the colour table if there are more parts than pre-defined colours
clr_map = opts.PartColors;
while size(clr_map, 1) < N_parts
    extra_hue = (size(clr_map, 1)) / (N_parts + 1);
    clr_map(end+1, :) = hsv2rgb([extra_hue, 0.85, 0.90]); %#ok<AGROW>
end

% ── Decide 3-D globe or 2-D map fallback ────────────────────────────────
%   geoglobe (Mapping Toolbox, R2020b+) is used for 3-D globe rendering of
%   geographic line contours (geoplot3).  trackingGlobeViewer is reserved
%   for Step 7, where objectTrack outputs from trackerGNN will be passed to
%   plotTrack/plotDetection.  Fall back to geoaxes 2-D if geoglobe is
%   absent or the user explicitly requests 2-D.
use_globe = ~opts.Use2DFallback && ...
    (exist('geoglobe', 'file') == 2 || exist('geoglobe', 'builtin') == 3);

if use_globe
    % ── 3-D geoglobe ──────────────────────────────────────────────────
    uif  = uifigure( ...
        'Name',     'Passive Bistatic Radar — Ellipse Trajectory (3D Globe)', ...
        'Position', [50, 50, 1280, 720]);
    gObj = geoglobe(uif, 'Basemap', opts.Basemap, 'Terrain', 'gmted2010');
    hold(gObj, 'on');
    fprintf('[%s] Rendering on geoglobe 3-D globe.\n', mfilename);
else
    % ── 2-D geoaxes fallback ──────────────────────────────────────────
    figH = figure( ...
        'Name',     'Passive Bistatic Radar — Ellipse Trajectory (2D Map)', ...
        'Position', [50, 50, 1280, 720]);
    gObj = geoaxes(figH, 'Basemap', opts.Basemap);
    hold(gObj, 'on');
    fprintf('[%s] geoglobe unavailable or disabled; rendering on geoaxes 2-D map.\n', ...
        mfilename);
end

% ── Station markers ──────────────────────────────────────────────────────
%   Tx = red upward triangle  (▲)   Rx = blue square (■)
%   The small altitude offset (+200 m) keeps markers above the terrain tile.
if use_globe
    % geoglobe only supports marker 'none' or 'o' — circles used for both
    % stations; Tx is larger to distinguish from Rx.
    geoplot3(gObj, txLLA(1), txLLA(2), txLLA(3)+200, ...
        'ro', 'MarkerSize', 16, 'LineWidth', 2);
    geoplot3(gObj, rxLLA(1), rxLLA(2), rxLLA(3)+200, ...
        'bo', 'MarkerSize', 12, 'LineWidth', 2);
    % Baseline connecting Tx and Rx (geoglobe only supports '-' or 'none')
    geoplot3(gObj, [txLLA(1), rxLLA(1)], [txLLA(2), rxLLA(2)], ...
        [txLLA(3)+50, rxLLA(3)+50], 'w-', 'LineWidth', 1);
else
    % Store handles so they can be reused directly in the legend
    h_tx_marker = geoplot(gObj, txLLA(1), txLLA(2), ...
        'r^', 'MarkerSize', 14, 'MarkerFaceColor', 'red', 'LineWidth', 2, ...
        'DisplayName', 'Tx -- HDTV Tower');
    h_rx_marker = geoplot(gObj, rxLLA(1), rxLLA(2), ...
        'bs', 'MarkerSize', 12, 'MarkerFaceColor', [0.20 0.45 0.90], 'LineWidth', 2, ...
        'DisplayName', 'Rx -- Surveillance Site');
    geoplot(gObj, [txLLA(1), rxLLA(1)], [txLLA(2), rxLLA(2)], ...
        'w--', 'LineWidth', 1, 'HandleVisibility', 'off');
end

% ── Ellipse contours per file part ──────────────────────────────────────
legend_h      = gobjects(0);   % collects one representative handle per part
legend_labels = {};

for p_i = 1 : N_parts
    ip   = parts(p_i);
    clr  = clr_map(p_i, :);
    mask = (part_idx == ip);
    kidx = find(mask);
    t_lo = min(t_abs_s(mask));
    t_hi = max(t_abs_s(mask));

    part_label = sprintf('Part %d  |  t = %.2f – %.2f s  |  %d det.', ...
        ip, t_lo, t_hi, numel(kidx));

    first_drawn = false;   % used to tag exactly one handle for the legend

    for j = 1 : numel(kidx)
        k = kidx(j);

        % Skip non-physical detections flagged during computation
        if isscalar(ellipse_lat{k}) && isnan(ellipse_lat{k})
            continue
        end

        % Only the first contour of each part appears in the legend;
        % the rest set HandleVisibility='off' to keep the legend clean.
        if ~first_drawn
            hv = 'on';
            first_drawn = true;
        else
            hv = 'off';
        end

        if use_globe
            % Render iso-range contour as a 500-m vertical ribbon by
            % stacking geoplot3 rings every 50 m from tgt_alt-250 to
            % tgt_alt+250.  geoplot3 on geoglobe requires row-vector
            % inputs, so transpose the column-vector geodetic arrays.
            lat_row = ellipse_lat{k}';          % [1 × NEllipsePoints]
            lon_row = ellipse_lon{k}';
            N_pts   = numel(lat_row);
            ribbon_bot = tgt_alt(k) - 250;
            ribbon_top = tgt_alt(k) + 250;
            for alt_step = ribbon_bot : 50 : ribbon_top
                geoplot3(gObj, lat_row, lon_row, ...
                    alt_step * ones(1, N_pts), ...
                    'Color', clr, 'LineWidth', 1.5);
            end
        else
            h = geoplot(gObj, ellipse_lat{k}, ellipse_lon{k}, ...
                'Color', clr, 'LineWidth', opts.LineWidth, ...
                'DisplayName', part_label, 'HandleVisibility', hv);
        end

        if strcmp(hv, 'on') && ~use_globe && isvalid(h)
            legend_h(end+1)      = h;         %#ok<AGROW>
            legend_labels{end+1} = part_label; %#ok<AGROW>
        end
    end
end

% ── Legend, title, grid ──────────────────────────────────────────────────
if use_globe
    % geoglobe does not expose a legend object; print a labelled console summary.
    % Attempt to centre the camera above the scene midpoint.
    scene_lat = mean([txLLA(1), rxLLA(1)]);
    scene_lon = mean([txLLA(2), rxLLA(2)]);
    try
        campos(gObj, scene_lat, scene_lon, 250e3);
    catch
        % campos unavailable in this MATLAB version — keep default view
    end

    fprintf('\n─── FIGURE LEGEND ───────────────────────────────────────\n');
    fprintf('  Red  ▲  : Tx — HDTV Tower      [%.4f°, %.4f°, %.0f m]\n', ...
        txLLA(1), txLLA(2), txLLA(3));
    fprintf('  Blue ■  : Rx — Surveillance     [%.4f°, %.4f°, %.0f m]\n', ...
        rxLLA(1), rxLLA(2), rxLLA(3));
    fprintf('  Baseline L = %.3f km\n', L/1e3);
    for p_i = 1 : N_parts
        ip   = parts(p_i);
        clr  = clr_map(p_i, :);
        mask = (part_idx == ip);
        fprintf('  RGB [%.2f %.2f %.2f]  :  Part %d  (t=%.2f–%.2f s, %d dets)\n', ...
            clr(1), clr(2), clr(3), ip, ...
            min(t_abs_s(mask)), max(t_abs_s(mask)), sum(mask));
    end
    fprintf('─────────────────────────────────────────────────────────\n');

else
    % Traditional geoaxes: full legend, title, grid
    hold(gObj, 'off');

    % Reuse the Tx/Rx handles created earlier (stored as h_tx_marker /
    % h_rx_marker) so we do not add extra invisible glyphs to the axes.
    all_h = [h_tx_marker; h_rx_marker; legend_h(:)];
    all_labels = [{'Tx -- HDTV Tower'; 'Rx -- Surveillance Site'}; legend_labels(:)];
    valid_mask = isvalid(all_h);
    all_h      = all_h(valid_mask);
    all_labels = all_labels(valid_mask);

    legend(gObj, all_h, all_labels, ...
        'Location',  'northwest', ...
        'FontSize',   9, ...
        'Color',      [0.10 0.10 0.10], ...
        'TextColor',  'white');

    title(gObj, sprintf( ...
        'Bistatic Range Ellipses — %d detections  |  %d file parts  |  L=%.1f km', ...
        N_dets, N_parts, L/1e3));

    grid(gObj, 'on');
end

fprintf('[%s] Complete — rendered %d ellipses across %d parts.\n\n', ...
    mfilename, N_dets, N_parts);

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
