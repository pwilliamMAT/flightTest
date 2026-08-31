function fig = helperPlutoTonePlotSummary(result, varargin)
%HELPERPLUTOTONEPLOTSUMMARY Create one compact summary figure for the precheck.
%
% Plain-language goal:
%   The operator does not need a large diagnostic report during the gate.
%   This helper puts the useful metrics in one place: channel detect
%   margins, channel frequency errors, either baseline deltas or raw
%   levels, and the tight text summary used for go/no-go decisions.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'result', @isstruct);
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'SummaryTitle', 'Pluto Tone Precheck Summary', @(x) ischar(x) || isstring(x));
parse(p, result, varargin{:});
opts = p.Results;

summary = helperPlutoToneBuildSummary(result);
reference_metrics = result.reference_metrics;
surveillance_metrics = result.surveillance_metrics;
joint_metrics = result.joint_metrics;

fig = figure( ...
    'Name', char(string(opts.SummaryTitle)), ...
    'NumberTitle', 'off', ...
    'Visible', char(string(opts.FigureVisibility)), ...
    'Position', [100, 100, 1200, 840]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo);
margin_values_db = [reference_metrics.detect_margin_db, surveillance_metrics.detect_margin_db];
bar(ax1, categorical({'REF', 'SURV'}), margin_values_db, 'FaceColor', [0.20, 0.45, 0.70]);
grid(ax1, 'on');
xlabel(ax1, 'Channel');
ylabel(ax1, 'Detect Margin [dB]');
title(ax1, 'Tone Detect Margin');

ax2 = nexttile(tlo);
frequency_values_khz = [ ...
    abs(reference_metrics.frequency_error_hz), ...
    abs(surveillance_metrics.frequency_error_hz), ...
    joint_metrics.channel_frequency_delta_hz] ./ 1e3;
bar(ax2, categorical({'REF err', 'SURV err', 'Joint delta'}), frequency_values_khz, 'FaceColor', [0.85, 0.50, 0.15]);
grid(ax2, 'on');
xlabel(ax2, 'Metric');
ylabel(ax2, 'Frequency Error [kHz]');
title(ax2, 'Frequency Checks');

ax3 = nexttile(tlo);
baseline_delta_available = isfinite(reference_metrics.level_delta_vs_baseline_db) && ...
    isfinite(surveillance_metrics.level_delta_vs_baseline_db);
if baseline_delta_available
    level_values = [ ...
        reference_metrics.level_delta_vs_baseline_db, ...
        surveillance_metrics.level_delta_vs_baseline_db];
    y_label = 'Baseline Delta [dB]';
    plot_title = 'Level Drift From Baseline';
else
    level_values = [reference_metrics.level_dbfs, surveillance_metrics.level_dbfs];
    y_label = 'Level [dBFS]';
    plot_title = 'Channel Levels';
end
bar(ax3, categorical({'REF', 'SURV'}), level_values, 'FaceColor', [0.35, 0.65, 0.30]);
grid(ax3, 'on');
xlabel(ax3, 'Channel');
ylabel(ax3, y_label);
title(ax3, plot_title);

ax4 = nexttile(tlo);
text(ax4, 0.01, 0.98, summary.text_block, ...
    'Interpreter', 'none', ...
    'FontName', 'Courier New', ...
    'FontSize', 11, ...
    'VerticalAlignment', 'top');
xlim(ax4, [0, 1]);
ylim(ax4, [0, 1]);
set(ax4, 'XTick', [], 'YTick', []);
xlabel(ax4, 'Normalized X');
ylabel(ax4, 'Normalized Y');
title(ax4, 'Operator Summary');

end
