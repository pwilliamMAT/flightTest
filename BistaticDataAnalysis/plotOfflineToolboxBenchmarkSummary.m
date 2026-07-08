function fig = plotOfflineToolboxBenchmarkSummary(summary_table, varargin)
%PLOTOFFLINETOOLBOXBENCHMARKSUMMARY Visualize offline benchmark tradeoffs.
%
% Plain-language goal:
%   Tables are precise, but a quick comparison figure makes it easier to
%   see which variant trades runtime for measurement-space accuracy. The
%   left subplot breaks total runtime into detector, TDOA, and truth-score
%   stages. The right subplot compares detection count, true positives, and
%   false alarms on the same benchmark set.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'summary_table', @istable);
addParameter(p, 'FigureTitle', 'Offline Toolbox Benchmark', @(x) ischar(x) || isstring(x));
parse(p, summary_table, varargin{:});
opts = p.Results;

if isempty(summary_table)
    fig = gobjects(1);
    return
end

variant_names = string(summary_table.variant_name);
fig = figure('Name', char(string(opts.FigureTitle)), ...
    'NumberTitle', 'off', ...
    'Color', [0.96, 0.96, 0.96], ...
    'Position', [120, 120, 1100, 520]);

tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

ax1 = nexttile(fig, 1);
runtime_matrix = [ ...
    summary_table.detector_runtime_s, ...
    summary_table.tdoa_runtime_s, ...
    summary_table.truth_runtime_s];
bar(ax1, categorical(cellstr(variant_names)), runtime_matrix, 'stacked');
grid(ax1, 'on');
ylabel(ax1, 'Runtime (s)');
title(ax1, 'Per-Stage Runtime');
legend(ax1, {'Detector', 'TDOA', 'Truth scoring'}, 'Location', 'northwest');

ax2 = nexttile(fig, 2);
metric_matrix = [ ...
    summary_table.detection_count, ...
    summary_table.n_tp, ...
    summary_table.n_fa];
bar(ax2, categorical(cellstr(variant_names)), metric_matrix, 'grouped');
grid(ax2, 'on');
ylabel(ax2, 'Count');
title(ax2, 'Detection and Truth Metrics');
legend(ax2, {'Detections', 'True positives', 'False alarms'}, 'Location', 'northwest');
end
