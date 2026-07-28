function fig = plotDetectionTruthDiagnostics(adsb_aligned, detections, metrics, varargin)
%PLOTDETECTIONTRUTHDIAGNOSTICS Plot detections and truth in measurement space.
%
% Plain-language goal:
%   Before tuning a tracker, verify that the detector is producing hits near
%   the expected truth trajectory. This figure overlays ADS-B truth and CFAR
%   detections directly in the radar's own measurement coordinates:
%   bistatic range excess versus time and Doppler versus time.
%
% Syntax
%   fig = plotDetectionTruthDiagnostics(adsb_aligned, detections, metrics)
%
% Inputs
%   adsb_aligned   Struct array from alignTruthToRadar.
%   detections     Detection struct array or table. Used when metrics does
%                  not already contain det_table.
%   metrics        Struct from assessTruthVsDetections.
%
% Name-value options
%   'FigureTitle'  Text appended to the figure title.
%   'MaxAircraft'  Maximum number of aircraft truth trajectories to plot.
%   'ShowLabels'   Label the aircraft callsigns/hex codes at the end.
%   'SavePDF'      Optional output PDF path.
%
% Output
%   fig            Figure handle.
%
% See also: assessTruthVsDetections, alignTruthToRadar.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'adsb_aligned', @(x) isempty(x) || isstruct(x));
addRequired(p, 'detections');
addRequired(p, 'metrics', @(x) isempty(x) || isstruct(x));
addParameter(p, 'FigureTitle', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'MaxAircraft', 12, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ShowLabels', true, @islogical);
addParameter(p, 'SavePDF', "", @(x) ischar(x) || isstring(x));
parse(p, adsb_aligned, detections, metrics, varargin{:});
opts = p.Results;

if isempty(adsb_aligned)
    warning('plotDetectionTruthDiagnostics:noTruth', ...
        'adsb_aligned is empty. Nothing to plot.');
    fig = gobjects(1);
    return
end

det_table = localBuildDetectionTable(detections, metrics);

valid_counts = zeros(1, numel(adsb_aligned));
for k = 1 : numel(adsb_aligned)
    valid_counts(k) = sum(isfinite(adsb_aligned(k).R_excess_m) & isfinite(adsb_aligned(k).f_D_hz));
end

keep_idx = find(valid_counts > 0);
if isempty(keep_idx)
    warning('plotDetectionTruthDiagnostics:noVisibleTruth', ...
        'adsb_aligned contains no finite truth samples to plot.');
    fig = gobjects(1);
    return
end

[~, order_idx] = sort(valid_counts(keep_idx), 'descend');
keep_idx = keep_idx(order_idx);
keep_idx = keep_idx(1:min(numel(keep_idx), opts.MaxAircraft));

truth_colors = lines(numel(keep_idx));
truth_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1 : numel(keep_idx)
    truth_map(char(string(adsb_aligned(keep_idx(k)).hex))) = truth_colors(k, :);
end

unmatched_color = [0.72, 0.72, 0.72];
other_match_color = [0.55, 0.55, 0.55];

fig = figure('Position', [80, 80, 1400, 860]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax_range = nexttile(tlo, 1);
ax_dopp = nexttile(tlo, 2);

localStyleAxes(ax_range);
localStyleAxes(ax_dopp);

xlabel(ax_range, 't_{abs} [s]');
ylabel(ax_range, 'R_{excess} [km]');
xlabel(ax_dopp, 't_{abs} [s]');
ylabel(ax_dopp, 'f_D [Hz]');

hold(ax_range, 'on');
hold(ax_dopp, 'on');

legend_handles = gobjects(0);
legend_labels = {};

for k = 1 : numel(keep_idx)
    ac = adsb_aligned(keep_idx(k));
    valid = isfinite(ac.R_excess_m) & isfinite(ac.f_D_hz);
    if ~any(valid)
        continue
    end

    t_plot = ac.t_abs_s(valid);
    R_plot = ac.R_excess_m(valid) / 1e3;
    f_plot = ac.f_D_hz(valid);
    [t_range, R_range] = localBreakLargeGaps(t_plot, R_plot);
    [t_dopp, f_dopp] = localBreakLargeGaps(t_plot, f_plot);

    h = plot(ax_range, t_range, R_range, '-', 'Color', truth_colors(k, :), 'LineWidth', 1.7);
    plot(ax_dopp, t_dopp, f_dopp, '-', 'Color', truth_colors(k, :), 'LineWidth', 1.7, ...
        'HandleVisibility', 'off');

    legend_handles(end + 1) = h; %#ok<AGROW>
    legend_labels{end + 1} = ['Truth: ', localAircraftLabel(ac)]; %#ok<AGROW>

    if opts.ShowLabels
        text(ax_range, t_plot(end), R_plot(end), [' ', localAircraftLabel(ac)], ...
            'Color', truth_colors(k, :), 'FontSize', 8, 'FontWeight', 'bold', ...
            'HandleVisibility', 'off');
        text(ax_dopp, t_plot(end), f_plot(end), [' ', localAircraftLabel(ac)], ...
            'Color', truth_colors(k, :), 'FontSize', 8, 'FontWeight', 'bold', ...
            'HandleVisibility', 'off');
    end
end

if ~isempty(det_table)
    unmatched_mask = true(height(det_table), 1);
    if ismember('is_tp', det_table.Properties.VariableNames)
        unmatched_mask = ~det_table.is_tp;
    end

    if any(unmatched_mask)
        scatter(ax_range, det_table.t_abs_s(unmatched_mask), det_table.R_excess_m(unmatched_mask) / 1e3, ...
            48, unmatched_color, 'x', 'LineWidth', 1.5);
        scatter(ax_dopp, det_table.t_abs_s(unmatched_mask), det_table.f_D_hz(unmatched_mask), ...
            48, unmatched_color, 'x', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        legend_handles(end + 1) = scatter(ax_range, NaN, NaN, 48, unmatched_color, 'x', 'LineWidth', 1.5);
        legend_labels{end + 1} = 'Unmatched detections';
    end

    matched_mask = ismember('is_tp', det_table.Properties.VariableNames) & det_table.is_tp;
    if any(matched_mask)
        matched_colors = repmat(other_match_color, height(det_table), 1);
        if ismember('matched_hex', det_table.Properties.VariableNames)
            for i = find(matched_mask).'
                key = char(string(det_table.matched_hex{i}));
                if truth_map.isKey(key)
                    matched_colors(i, :) = truth_map(key);
                end
            end
        end

        scatter(ax_range, det_table.t_abs_s(matched_mask), det_table.R_excess_m(matched_mask) / 1e3, ...
            56, matched_colors(matched_mask, :), 'o', 'filled', ...
            'MarkerEdgeColor', [0.12, 0.12, 0.12], 'LineWidth', 0.8);
        scatter(ax_dopp, det_table.t_abs_s(matched_mask), det_table.f_D_hz(matched_mask), ...
            56, matched_colors(matched_mask, :), 'o', 'filled', ...
            'MarkerEdgeColor', [0.12, 0.12, 0.12], 'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
        legend_handles(end + 1) = scatter(ax_range, NaN, NaN, 56, [0.85, 0.85, 0.85], 'o', 'filled', ...
            'MarkerEdgeColor', [0.12, 0.12, 0.12], 'LineWidth', 0.8);
        legend_labels{end + 1} = 'Matched detections';
    end
end

if ~isempty(legend_handles)
    legend(ax_range, legend_handles, legend_labels, 'Location', 'eastoutside', 'FontSize', 8);
end

det_count = height(det_table);
n_tp = 0;
n_fa = 0;
n_miss = 0;
if ~isempty(metrics)
    if isfield(metrics, 'n_tp'), n_tp = metrics.n_tp; end
    if isfield(metrics, 'n_fa'), n_fa = metrics.n_fa; end
    if isfield(metrics, 'n_miss'), n_miss = metrics.n_miss; end
end

title(ax_range, 'Bistatic Range Excess vs Time', 'FontSize', 11);
title(ax_dopp, 'Bistatic Doppler vs Time', 'FontSize', 11);

main_title = 'Detection-vs-Truth Diagnostics';
if strlength(string(opts.FigureTitle)) > 0
    main_title = sprintf('%s  |  %s', main_title, char(string(opts.FigureTitle)));
end
subtitle_text = sprintf('Detections: %d   TP: %d   FA: %d   Missed truth CPIs: %d', ...
    det_count, n_tp, n_fa, n_miss);
sgtitle(tlo, {main_title, subtitle_text}, 'FontSize', 12);

if strlength(string(opts.SavePDF)) > 0
    exportgraphics(fig, char(string(opts.SavePDF)), 'ContentType', 'vector');
    fprintf('[plotDetectionTruthDiagnostics] Saved: %s\n', char(string(opts.SavePDF)));
end

end

function det_table = localBuildDetectionTable(detections, metrics)
det_table = table();

if ~isempty(metrics) && isfield(metrics, 'det_table') && ~isempty(metrics.det_table)
    det_table = metrics.det_table;
    return
end

if isempty(detections)
    return
end

if istable(detections)
    det_table = detections;
    return
end

det_t = [detections.t_abs_s].';
det_R = [detections.R_excess_m].';
det_f = [detections.f_D_hz].';
det_table = table(det_t, det_R, det_f, ...
    'VariableNames', {'t_abs_s', 'R_excess_m', 'f_D_hz'});
end

function [t_out, y_out] = localBreakLargeGaps(t_in, y_in)
t_out = t_in(:);
y_out = y_in(:);

if numel(t_out) < 3
    return
end

dt = diff(t_out);
dt = dt(dt > 0);
if isempty(dt)
    return
end

gap_threshold = 2.5 * median(dt);
break_idx = find(diff(t_out) > gap_threshold);
if isempty(break_idx)
    return
end

t_parts = cell(numel(break_idx) + 1, 1);
y_parts = cell(numel(break_idx) + 1, 1);
start_idx = 1;
for k = 1 : numel(break_idx)
    stop_idx = break_idx(k);
    t_parts{k} = [t_out(start_idx:stop_idx); NaN];
    y_parts{k} = [y_out(start_idx:stop_idx); NaN];
    start_idx = stop_idx + 1;
end
t_parts{end} = t_out(start_idx:end);
y_parts{end} = y_out(start_idx:end);

t_out = vertcat(t_parts{:});
y_out = vertcat(y_parts{:});
end

function label = localAircraftLabel(ac)
if isfield(ac, 'callsign') && ~isempty(strtrim(char(string(ac.callsign))))
    label = strtrim(char(string(ac.callsign)));
elseif isfield(ac, 'hex') && ~isempty(ac.hex)
    label = strtrim(char(string(ac.hex)));
else
    label = 'Aircraft';
end
end

function localStyleAxes(ax)
grid(ax, 'on');
box(ax, 'on');
end
