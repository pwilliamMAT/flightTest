function preview_result = helperTriggerRenderCandidateMap(config, assets, varargin)
%HELPERTRIGGERRENDERCANDIDATEMAP Render the trigger candidate preview plot.
%
% Plain-language goal:
%   This preview converts the trigger wrapper's ENU scoring region into a
%   geographic operator view and a numeric ENU cross-check so the user can
%   see which aircraft locations are considered favorable before the watch
%   loop starts.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'config', @isstruct);
addRequired(p, 'assets', @isstruct);
addParameter(p, 'OutputPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ShowFigure', true, @islogical);
addParameter(p, 'SavePNG', true, @islogical);
addParameter(p, 'Altitude_m', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'GridStep_m', 500, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'RangeMargin_m', 5000, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'Basemap', "streets-light", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', false, @islogical);
parse(p, config, assets, varargin{:});
opts = p.Results;
output_path = string(opts.OutputPath);
if opts.SavePNG && strlength(output_path) == 0
    output_path = string(tempname) + ".png";
end

altitude_slice_m = double(opts.Altitude_m);
if ~isfinite(altitude_slice_m)
    altitude_slice_m = mean(config.AltitudeBand_m);
end

preview_extent_m = max(config.ReceiverRangeBand_m(2), assets.proxy_prior.coverage_range_m) + opts.RangeMargin_m;
east_axis_m = -preview_extent_m : opts.GridStep_m : preview_extent_m;
north_axis_m = -preview_extent_m : opts.GridStep_m : preview_extent_m;
[east_grid_m, north_grid_m] = meshgrid(east_axis_m, north_axis_m);
horizontal_range_m = hypot(east_grid_m, north_grid_m);
inside_extent_mask = horizontal_range_m <= preview_extent_m;

up_slice_m = altitude_slice_m - config.RxLLA(3);
point_mask = inside_extent_mask(:);
point_positions_enu_m = [ ...
    east_grid_m(point_mask).'; ...
    north_grid_m(point_mask).'; ...
    repmat(up_slice_m, 1, nnz(point_mask))];
point_velocities_enu_mps = zeros(size(point_positions_enu_m));

evaluation = helperTriggerEvaluateGeometryField( ...
    point_positions_enu_m, point_velocities_enu_mps, config, assets, ...
    'ApplyFreshnessGate', false);

[lat_vec_deg, lon_vec_deg] = enu2geodetic( ...
    point_positions_enu_m(1, :).', point_positions_enu_m(2, :).', point_positions_enu_m(3, :).', ...
    config.RxLLA(1), config.RxLLA(2), config.RxLLA(3), evaluation.geometry.spheroid);

trigger_score_grid = nan(size(east_grid_m));
geometry_gate_grid = false(size(east_grid_m));
qualified_grid = false(size(east_grid_m));

trigger_score_grid(point_mask) = evaluation.trigger_score;
geometry_gate_grid(point_mask) = evaluation.geometry_gate_pass;
qualified_grid(point_mask) = evaluation.qualified;

qualified_area_km2 = nnz(qualified_grid) .* (opts.GridStep_m .^ 2) ./ 1e6;
max_trigger_score = max(evaluation.trigger_score, [], 'omitnan');
qualified_region_exists = any(qualified_grid(:));
qualified_region_message = "";
if ~qualified_region_exists
    qualified_region_message = "No qualified trigger region exists for the current settings.";
end

preview_result = struct( ...
    'figure_handle', [], ...
    'geoaxes_handle', [], ...
    'enu_axes_handle', [], ...
    'image_path', output_path, ...
    'saved_png', false, ...
    'show_figure', logical(opts.ShowFigure), ...
    'save_png', logical(opts.SavePNG), ...
    'altitude_slice_m', altitude_slice_m, ...
    'grid_step_m', double(opts.GridStep_m), ...
    'range_margin_m', double(opts.RangeMargin_m), ...
    'preview_extent_m', preview_extent_m, ...
    'preview_extent_km', preview_extent_m ./ 1e3, ...
    'qualified_area_km2', qualified_area_km2, ...
    'qualified_region_exists', qualified_region_exists, ...
    'qualified_region_message', qualified_region_message, ...
    'max_trigger_score', max_trigger_score, ...
    'east_axis_m', east_axis_m, ...
    'north_axis_m', north_axis_m, ...
    'trigger_score_grid', trigger_score_grid, ...
    'geometry_gate_grid', geometry_gate_grid, ...
    'qualified_grid', qualified_grid, ...
    'config_summary', localBuildConfigSummary(config), ...
    'warning_message', "");
preview_result.config_summary.qualified_region_exists = qualified_region_exists;
preview_result.config_summary.qualified_region_message = qualified_region_message;

default_color_order = get(groot, 'defaultAxesColorOrder');
rx_color = default_color_order(1, :);
tx_color = default_color_order(2, :);
geometry_gate_color = default_color_order(1, :);
qualified_region_color = default_color_order(2, :);
corridor_color = default_color_order(5, :);
boresight_color = [0.85 0.10 0.10];
range_band_color = 0.35 .* [1.0 1.0 1.0];
light_background_color = [1.0 1.0 1.0];
light_foreground_color = [0.0 0.0 0.0];
light_grid_color = 0.85 .* [1.0 1.0 1.0];
legend_entries = [ ...
    "Qualified trigger region"; ...
    "Geometry gate"; ...
    "Corridor center"; ...
    "Corridor gates"; ...
    "Boresight gates"; ...
    "Range band"];
overlay_styles = struct( ...
    'qualified_region_color_rgb', qualified_region_color, ...
    'qualified_region_line_style', "-", ...
    'geometry_gate_color_rgb', geometry_gate_color, ...
    'geometry_gate_line_style', "--", ...
    'corridor_color_rgb', corridor_color, ...
    'corridor_center_line_style', "-", ...
    'corridor_gate_line_style', "--", ...
    'boresight_color_rgb', boresight_color, ...
    'boresight_line_style', ":", ...
    'range_band_color_rgb', range_band_color, ...
    'range_band_line_style', "--");
preview_result.legend_entries = legend_entries;
preview_result.overlay_styles = overlay_styles;
preview_result.config_summary.overlay_styles = overlay_styles;

fig = figure( ...
    'Name', 'ADS-B Trigger Candidate Map', ...
    'Color', light_background_color, ...
    'Visible', localResolveVisibility(opts.ShowFigure));
colormap(fig, parula(256));
t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
t.OuterPosition = [0.02 0.17 0.96 0.80];

gx = geoaxes(t);
gx.Layout.Tile = 1;
gx.Color = light_background_color;
gx.LatitudeAxis.Color = light_foreground_color;
gx.LongitudeAxis.Color = light_foreground_color;
gx.LatitudeLabel.Color = light_foreground_color;
gx.LongitudeLabel.Color = light_foreground_color;
geobasemap(gx, char(string(opts.Basemap)));
hold(gx, 'on');

score_size = 14;
scatter_handle = geoscatter(gx, lat_vec_deg, lon_vec_deg, score_size, evaluation.trigger_score, 'filled');
scatter_handle.DisplayName = 'Trigger score background';
clim(gx, [0 1]);

geoplot(gx, config.RxLLA(1), config.RxLLA(2), 's', ...
    'Color', rx_color, 'MarkerSize', 8, 'LineWidth', 1.2, 'DisplayName', 'RX');
geoplot(gx, config.TxLLA(1), config.TxLLA(2), '^', ...
    'Color', tx_color, 'MarkerSize', 8, 'LineWidth', 1.2, 'DisplayName', 'TX');

localPlotBoundaryRays(gx, config.CorridorAzimuthCenter_deg, preview_extent_m, up_slice_m, config, ...
    'Color', corridor_color, 'LineStyle', '-', 'DisplayName', 'Corridor center');
localPlotBoundaryRays(gx, config.CorridorAzimuthCenter_deg + [-1 1] .* config.CorridorAzimuthHalfWidth_deg, ...
    preview_extent_m, up_slice_m, config, ...
    'Color', corridor_color, 'LineStyle', '--', 'DisplayName', 'Corridor gates');
localPlotBoundaryRays(gx, config.SurveillanceBoresightAzimuth_deg + [-1 1] .* config.BoresightAzimuthHalfWidth_deg, ...
    preview_extent_m, up_slice_m, config, ...
    'Color', boresight_color, 'LineStyle', ':', 'DisplayName', 'Boresight gates');

localPlotRangeCircle(gx, config.ReceiverRangeBand_m(1), up_slice_m, config, evaluation.geometry.spheroid, ...
    'Color', range_band_color, 'LineStyle', '--', 'DisplayName', 'Range band');
localPlotRangeCircle(gx, config.ReceiverRangeBand_m(2), up_slice_m, config, evaluation.geometry.spheroid, ...
    'Color', range_band_color, 'LineStyle', '--', 'DisplayName', '');

localPlotMaskContourGeo(gx, east_axis_m, north_axis_m, geometry_gate_grid, up_slice_m, config, evaluation.geometry.spheroid, ...
    'Color', geometry_gate_color, 'LineWidth', 1.2, 'LineStyle', '--', 'DisplayName', 'Geometry gate');
localPlotMaskContourGeo(gx, east_axis_m, north_axis_m, qualified_grid, up_slice_m, config, evaluation.geometry.spheroid, ...
    'Color', qualified_region_color, 'LineWidth', 1.8, 'LineStyle', '-', 'DisplayName', 'Qualified trigger region');

geolimits(gx, [min(lat_vec_deg) max(lat_vec_deg)], [min(lon_vec_deg) max(lon_vec_deg)]);
geo_title = title(gx, sprintf('Geographic Qualified Trigger Region at %.0f m MSL', altitude_slice_m));
geo_title.Color = light_foreground_color;
hold(gx, 'off');

ax = nexttile(t, 2);
score_image = imagesc(ax, east_axis_m ./ 1e3, north_axis_m ./ 1e3, trigger_score_grid);
score_image.AlphaData = double(~isnan(trigger_score_grid));
ax.Color = light_background_color;
ax.XColor = light_foreground_color;
ax.YColor = light_foreground_color;
ax.GridColor = light_grid_color;
ax.MinorGridColor = light_grid_color;
set(ax, 'YDir', 'normal');
axis(ax, 'equal');
hold(ax, 'on');
clim(ax, [0 1]);
enu_colorbar = colorbar(ax);
enu_colorbar.Label.String = 'Trigger score [proxy background]';
enu_colorbar.Color = light_foreground_color;

localPlotMaskContourENU(ax, east_axis_m, north_axis_m, geometry_gate_grid, ...
    'LineColor', geometry_gate_color, 'LineStyle', '--', 'LineWidth', 1.2);
localPlotMaskContourENU(ax, east_axis_m, north_axis_m, qualified_grid, ...
    'LineColor', qualified_region_color, 'LineStyle', '-', 'LineWidth', 1.8);

localPlotRangeCircleENU(ax, config.ReceiverRangeBand_m(1), up_slice_m, range_band_color, '--');
localPlotRangeCircleENU(ax, config.ReceiverRangeBand_m(2), up_slice_m, range_band_color, '--');
localPlotRayENU(ax, config.CorridorAzimuthCenter_deg, preview_extent_m, corridor_color, '-');
localPlotRayENU(ax, config.CorridorAzimuthCenter_deg + [-1 1] .* config.CorridorAzimuthHalfWidth_deg, ...
    preview_extent_m, corridor_color, '--');
localPlotRayENU(ax, config.SurveillanceBoresightAzimuth_deg + [-1 1] .* config.BoresightAzimuthHalfWidth_deg, ...
    preview_extent_m, boresight_color, ':');

plot(ax, 0, 0, 's', 'Color', rx_color, 'MarkerSize', 8, 'LineWidth', 1.2);
plot(ax, evaluation.geometry.tx_enu_m(1) ./ 1e3, evaluation.geometry.tx_enu_m(2) ./ 1e3, ...
    '^', 'Color', tx_color, 'MarkerSize', 8, 'LineWidth', 1.2);

legend_handle = localAddOverlayLegend(fig, legend_entries, overlay_styles, light_background_color, light_foreground_color);
preview_result.legend_handle = legend_handle;

if ~qualified_region_exists
    text(ax, 0.02, 0.98, char(qualified_region_message), ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'Color', light_foreground_color, ...
        'BackgroundColor', light_background_color, ...
        'Margin', 4);
end

grid(ax, 'on');
xlabel(ax, 'East [km]');
ylabel(ax, 'North [km]');
ax.XLabel.Color = light_foreground_color;
ax.YLabel.Color = light_foreground_color;
enu_title = title(ax, 'ENU Trigger Score Background and Qualified Region');
enu_title.Color = light_foreground_color;
hold(ax, 'off');

main_title = title(t, 'ADS-B Trigger Candidate Preview  |  Qualified Trigger Region');
main_title.Color = light_foreground_color;
sub_title = subtitle(t, sprintf(['Altitude band %.0f to %.0f m MSL  |  Preview slice %.0f m MSL  |  ' ...
    'Qualified = hard gate pass & trigger score >= %.2f%s'], ...
    config.AltitudeBand_m(1), config.AltitudeBand_m(2), altitude_slice_m, ...
    config.QualifiedTriggerScore, char(localQualifiedRegionSuffix(qualified_region_message))));
sub_title.Color = light_foreground_color;

drawnow;

if opts.SavePNG && strlength(output_path) > 0
    output_dir = fileparts(char(output_path));
    if strlength(string(output_dir)) > 0 && exist(output_dir, 'dir') ~= 7
        mkdir(output_dir);
    end

    exportgraphics(fig, char(output_path), 'Resolution', 150);
    preview_result.saved_png = true;
end

preview_result.figure_handle = fig;
preview_result.geoaxes_handle = gx;
preview_result.enu_axes_handle = ax;

if ~opts.ShowFigure
    close(fig);
    preview_result.figure_handle = [];
    preview_result.geoaxes_handle = [];
    preview_result.enu_axes_handle = [];
    preview_result.legend_handle = [];
end

if opts.Verbose
    fprintf('[helperTriggerRenderCandidateMap] Max trigger score .. %.3f\n', max_trigger_score);
    fprintf('[helperTriggerRenderCandidateMap] Qualified area .... %.2f km^2\n', qualified_area_km2);
    if ~qualified_region_exists
        fprintf('[helperTriggerRenderCandidateMap] Qualified region .. %s\n', char(qualified_region_message));
    end
    if preview_result.saved_png
        fprintf('[helperTriggerRenderCandidateMap] Saved PNG ....... %s\n', char(preview_result.image_path));
    end
end

end

function config_summary = localBuildConfigSummary(config)
config_summary = struct( ...
    'qualified_trigger_score', double(config.QualifiedTriggerScore), ...
    'corridor_azimuth_center_deg', double(config.CorridorAzimuthCenter_deg), ...
    'corridor_half_width_deg', double(config.CorridorAzimuthHalfWidth_deg), ...
    'boresight_azimuth_deg', double(config.SurveillanceBoresightAzimuth_deg), ...
    'boresight_az_half_width_deg', double(config.BoresightAzimuthHalfWidth_deg), ...
    'boresight_el_half_width_deg', double(config.BoresightElevationHalfWidth_deg), ...
    'altitude_band_m', double(config.AltitudeBand_m(:).'), ...
    'receiver_range_band_m', double(config.ReceiverRangeBand_m(:).'));
end

function visibility = localResolveVisibility(show_figure)
if show_figure
    visibility = 'on';
else
    visibility = 'off';
end
end

function localPlotBoundaryRays(ax, azimuth_deg, max_range_m, up_slice_m, config, varargin)
if numel(azimuth_deg) > 1
    base_args = localStripDisplayName(varargin);
    for idx = 1:numel(azimuth_deg)
        localPlotBoundaryRays(ax, azimuth_deg(idx), max_range_m, up_slice_m, config, base_args{:}, ...
            'DisplayName', localDisplayName(varargin, idx));
    end
    return
end

ray_ranges_m = linspace(0, max_range_m, 200);
east_m = ray_ranges_m .* sind(azimuth_deg);
north_m = ray_ranges_m .* cosd(azimuth_deg);
[lat_deg, lon_deg] = enu2geodetic( ...
    east_m, north_m, repmat(up_slice_m, size(east_m)), ...
    config.RxLLA(1), config.RxLLA(2), config.RxLLA(3), wgs84Ellipsoid('meter'));
geoplot(ax, lat_deg, lon_deg, varargin{:});
end

function args_out = localStripDisplayName(args_in)
args_out = args_in;
name_idx = find(strcmpi(args_out(1:2:end), 'DisplayName'), 1, 'first');
if isempty(name_idx)
    return
end

remove_idx = (2 .* name_idx - 1) : (2 .* name_idx);
args_out(remove_idx) = [];
end

function display_name = localDisplayName(args_in, idx)
display_name = '';
name_idx = find(strcmpi(args_in(1:2:end), 'DisplayName'), 1, 'first');
if isempty(name_idx)
    return
end
if idx == 1
    display_name = args_in{2 .* name_idx};
end
end

function localPlotRangeCircle(ax, slant_range_m, up_slice_m, config, spheroid, varargin)
horizontal_radius_m = sqrt(max(slant_range_m .^ 2 - up_slice_m .^ 2, 0.0));
if horizontal_radius_m <= 0
    return
end

theta = linspace(0, 2.0 .* pi, 361);
east_m = horizontal_radius_m .* sin(theta);
north_m = horizontal_radius_m .* cos(theta);
[lat_deg, lon_deg] = enu2geodetic( ...
    east_m, north_m, repmat(up_slice_m, size(east_m)), ...
    config.RxLLA(1), config.RxLLA(2), config.RxLLA(3), spheroid);
geoplot(ax, lat_deg, lon_deg, varargin{:});
end

function localPlotMaskContourGeo(ax, east_axis_m, north_axis_m, mask_grid, up_slice_m, config, spheroid, varargin)
if ~localMaskHasBoundary(mask_grid)
    return
end

contours = contourc(east_axis_m ./ 1e3, north_axis_m ./ 1e3, double(mask_grid), [0.5 0.5]);
segments = localParseContourSegments(contours);
for idx = 1:numel(segments)
    [lat_deg, lon_deg] = enu2geodetic( ...
        segments(idx).east_m, segments(idx).north_m, repmat(up_slice_m, size(segments(idx).east_m)), ...
        config.RxLLA(1), config.RxLLA(2), config.RxLLA(3), spheroid);
    if idx == 1
        geoplot(ax, lat_deg, lon_deg, varargin{:});
    else
        geoplot(ax, lat_deg, lon_deg, varargin{:}, 'HandleVisibility', 'off');
    end
end
end

function segments = localParseContourSegments(contours)
segments = struct('east_m', {}, 'north_m', {});
if isempty(contours)
    return
end

segment_idx = 0;
column_idx = 1;
while column_idx < size(contours, 2)
    point_count = double(contours(2, column_idx));
    data_idx = (column_idx + 1) : (column_idx + point_count);
    segment_idx = segment_idx + 1;
    segments(segment_idx).east_m = contours(1, data_idx).' .* 1e3;
    segments(segment_idx).north_m = contours(2, data_idx).' .* 1e3;
    column_idx = data_idx(end) + 1;
end
end

function localPlotRangeCircleENU(ax, slant_range_m, up_slice_m, color_value, line_style)
horizontal_radius_km = sqrt(max(slant_range_m .^ 2 - up_slice_m .^ 2, 0.0)) ./ 1e3;
if all(horizontal_radius_km <= 0)
    return
end

theta = linspace(0, 2.0 .* pi, 361);
plot(ax, horizontal_radius_km .* sin(theta), horizontal_radius_km .* cos(theta), ...
    'Color', color_value, 'LineStyle', line_style, 'LineWidth', 1.2);
end

function localPlotRayENU(ax, azimuth_deg, max_range_m, color_value, line_style)
azimuth_deg = double(azimuth_deg(:).');
for idx = 1:numel(azimuth_deg)
    ray_range_km = [0, max_range_m] ./ 1e3;
    plot(ax, ray_range_km .* sind(azimuth_deg(idx)), ray_range_km .* cosd(azimuth_deg(idx)), ...
        'Color', color_value, 'LineStyle', line_style, 'LineWidth', 1.2);
end
end

function localPlotMaskContourENU(ax, east_axis_m, north_axis_m, mask_grid, varargin)
if ~localMaskHasBoundary(mask_grid)
    return
end

contour(ax, east_axis_m ./ 1e3, north_axis_m ./ 1e3, double(mask_grid), [0.5 0.5], varargin{:});
end

function tf = localMaskHasBoundary(mask_grid)
mask_grid = logical(mask_grid);
tf = any(mask_grid(:)) && any(~mask_grid(:));
end

function suffix = localQualifiedRegionSuffix(message_text)
suffix = "";
if strlength(string(message_text)) > 0
    suffix = "  |  " + string(message_text);
end
end

function legend_handle = localAddOverlayLegend(fig, legend_entries, overlay_styles, background_color, foreground_color)
legend_ax = axes(fig, ...
    'Position', [0.08 0.01 0.84 0.12], ...
    'Color', 'none', ...
    'XColor', 'none', ...
    'YColor', 'none', ...
    'XTick', [], ...
    'YTick', [], ...
    'Box', 'off');
hold(legend_ax, 'on');

legend_handles = [ ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.qualified_region_color_rgb, 'LineStyle', char(overlay_styles.qualified_region_line_style), 'LineWidth', 1.8); ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.geometry_gate_color_rgb, 'LineStyle', char(overlay_styles.geometry_gate_line_style), 'LineWidth', 1.2); ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.corridor_color_rgb, 'LineStyle', char(overlay_styles.corridor_center_line_style), 'LineWidth', 1.2); ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.corridor_color_rgb, 'LineStyle', char(overlay_styles.corridor_gate_line_style), 'LineWidth', 1.2); ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.boresight_color_rgb, 'LineStyle', char(overlay_styles.boresight_line_style), 'LineWidth', 1.2); ...
    plot(legend_ax, NaN, NaN, 'Color', overlay_styles.range_band_color_rgb, 'LineStyle', char(overlay_styles.range_band_line_style), 'LineWidth', 1.2)];

legend_handle = legend(legend_ax, legend_handles, cellstr(legend_entries), ...
    'Location', 'northwest', ...
    'NumColumns', 3, ...
    'Orientation', 'horizontal');
legend_handle.Title.String = 'Overlay Legend';
legend_handle.Color = background_color;
legend_handle.TextColor = foreground_color;
legend_handle.Box = 'on';
hold(legend_ax, 'off');
end
