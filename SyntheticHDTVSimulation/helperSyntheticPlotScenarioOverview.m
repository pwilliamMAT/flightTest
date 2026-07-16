function plot_handles = helperSyntheticPlotScenarioOverview(scenario_config, truth_bundle)
%HELPERSYNTHETICPLOTSCENARIOOVERVIEW Plot static geometry and truth previews.
%
% Plain language:
% This helper gives the walkthrough a fast static preview of the exact
% target definitions that will drive generation. The figure shows the site
% geometry, the waypoint-defined trajectories, and the resulting bistatic
% truth so changes to timing, path shape, or echo-strength assignments can
% be inspected before writing files.

validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');
validateattributes(truth_bundle, {'struct'}, {'scalar'}, mfilename, 'truth_bundle');

truth_targets = truth_bundle.targets;
bistatic_tracks = truth_bundle.bistatic_tracks;
n_targets = numel(truth_targets);
target_colors = lines(max(n_targets, 1));
active_window_s = scenario_config.part_duration_s * scenario_config.capture_repetitions + ...
    max(scenario_config.capture_repetitions - 1, 0) * scenario_config.capture_repetition_spacing_s;
truth_sample_period_s = double(scenario_config.truth_sample_period_s);

fig = figure('Name', 'Synthetic Scenario Overview', 'Color', 'w');
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax_geometry = nexttile(layout, 1);
hold(ax_geometry, 'on')
scatter(ax_geometry, scenario_config.tx_lla_deg_m(2), scenario_config.tx_lla_deg_m(1), ...
    90, [0.10, 0.10, 0.10], '^', 'filled', 'DisplayName', 'Transmitter')
scatter(ax_geometry, scenario_config.rx_lla_deg_m(2), scenario_config.rx_lla_deg_m(1), ...
    90, [0.35, 0.35, 0.35], 'v', 'filled', 'DisplayName', 'Receiver')

for idx = 1 : n_targets
    target_label = localTargetLabel(truth_targets(idx));
    waypoints_lla_deg_m = double(scenario_config.targets(idx).waypoints_lla_deg_m);

    plot(ax_geometry, waypoints_lla_deg_m(:, 2), waypoints_lla_deg_m(:, 1), '--o', ...
        'Color', target_colors(idx, :), ...
        'LineWidth', 1.0, ...
        'HandleVisibility', 'off')
    plot(ax_geometry, truth_targets(idx).lon_deg, truth_targets(idx).lat_deg, '-', ...
        'Color', target_colors(idx, :), ...
        'LineWidth', 1.8, ...
        'DisplayName', target_label)
    scatter(ax_geometry, waypoints_lla_deg_m(1, 2), waypoints_lla_deg_m(1, 1), ...
        50, target_colors(idx, :), 'filled', 'HandleVisibility', 'off')
    scatter(ax_geometry, waypoints_lla_deg_m(end, 2), waypoints_lla_deg_m(end, 1), ...
        50, target_colors(idx, :), 'd', 'filled', 'HandleVisibility', 'off')
    scatter(ax_geometry, truth_targets(idx).lon_deg(1), truth_targets(idx).lat_deg(1), ...
        65, target_colors(idx, :), 'o', 'LineWidth', 1.2, 'HandleVisibility', 'off')
    scatter(ax_geometry, truth_targets(idx).lon_deg(end), truth_targets(idx).lat_deg(end), ...
        70, target_colors(idx, :), 's', 'LineWidth', 1.2, 'HandleVisibility', 'off')
end

grid(ax_geometry, 'on')
axis(ax_geometry, 'equal')
xlabel(ax_geometry, 'Longitude [deg]')
ylabel(ax_geometry, 'Latitude [deg]')
title(ax_geometry, { ...
    sprintf('Sampled Target Motion Over %.2f s Active Window', active_window_s), ...
    sprintf('Synthetic Truth Sampling %.3f s | Start = circle | End = square', truth_sample_period_s)})
text(ax_geometry, 0.02, 0.02, ...
    'Short captures can appear nearly static relative to fixed Tx/Rx geometry.', ...
    'Units', 'normalized', ...
    'BackgroundColor', [1, 1, 1], ...
    'EdgeColor', [0.85, 0.85, 0.85], ...
    'Margin', 4, ...
    'FontSize', 8)
legend(ax_geometry, 'Location', 'bestoutside')
hold(ax_geometry, 'off')

ax_altitude = nexttile(layout, 2);
hold(ax_altitude, 'on')
for idx = 1 : n_targets
    plot(ax_altitude, truth_targets(idx).t_rel_s, truth_targets(idx).alt_m, ...
        'Color', target_colors(idx, :), ...
        'LineWidth', 1.8, ...
        'DisplayName', localTargetLabel(truth_targets(idx)))
end
grid(ax_altitude, 'on')
xlabel(ax_altitude, 'Relative Time [s]')
ylabel(ax_altitude, 'Altitude [m]')
title(ax_altitude, 'Synthetic Truth Altitude Profile')
legend(ax_altitude, 'Location', 'best')
hold(ax_altitude, 'off')

ax_range = nexttile(layout, 3);
hold(ax_range, 'on')
for idx = 1 : numel(bistatic_tracks)
    relative_time_s = double(bistatic_tracks(idx).t_utc(:)) - double(scenario_config.radar_epoch_utc);
    plot(ax_range, relative_time_s, double(bistatic_tracks(idx).R_excess_m(:)) ./ 1e3, ...
        'Color', target_colors(idx, :), ...
        'LineWidth', 1.8, ...
        'DisplayName', localTargetLabel(truth_targets(idx)))
end
grid(ax_range, 'on')
xlabel(ax_range, 'Relative Time [s]')
ylabel(ax_range, 'Bistatic Range Excess [km]')
title(ax_range, 'Synthetic Truth Range Preview')
legend(ax_range, 'Location', 'best')
hold(ax_range, 'off')

ax_doppler = nexttile(layout, 4);
hold(ax_doppler, 'on')
for idx = 1 : numel(bistatic_tracks)
    relative_time_s = double(bistatic_tracks(idx).t_utc(:)) - double(scenario_config.radar_epoch_utc);
    plot(ax_doppler, relative_time_s, double(bistatic_tracks(idx).f_D_hz(:)), ...
        'Color', target_colors(idx, :), ...
        'LineWidth', 1.8, ...
        'DisplayName', localTargetLabel(truth_targets(idx)))
end
grid(ax_doppler, 'on')
xlabel(ax_doppler, 'Relative Time [s]')
ylabel(ax_doppler, 'Bistatic Doppler [Hz]')
title(ax_doppler, 'Synthetic Truth Doppler Preview')
legend(ax_doppler, 'Location', 'best')
hold(ax_doppler, 'off')

title(layout, 'Synthetic Scenario Preview')

plot_handles = struct( ...
    'figure', fig, ...
    'layout', layout, ...
    'geometry_axes', ax_geometry, ...
    'altitude_axes', ax_altitude, ...
    'range_axes', ax_range, ...
    'doppler_axes', ax_doppler);
end

function target_label = localTargetLabel(target_struct)
target_label = char("Synthetic Truth: " + string(target_struct.target_id) + ...
    " (" + string(target_struct.callsign) + ")");
end
