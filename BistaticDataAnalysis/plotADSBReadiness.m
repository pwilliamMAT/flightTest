function figure_handle = plotADSBReadiness(result, varargin)
%PLOTADSBREADINESS Visualize ADS-B freshness and manual candidate quality.
%
%   figure_handle = plotADSBReadiness(result)
%
%   The upper panel shows position-fix timing for every aircraft in the
%   tested window. The lower panel shows the bounded 599 MHz opportunity
%   table. Circles are eligible manual candidates; crosses are HOLD rows.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'result', @isstruct);
addParameter(p, 'Visible', 'on', ...
    @(x) any(strcmpi(string(x), ["on", "off"])));
parse(p, result, varargin{:});
opts = p.Results;

required_fields = {'Status', 'Summary', 'Candidates', 'Fixes'};
if ~all(isfield(result, required_fields))
    error('plotADSBReadiness:badResult', ...
        'result must come from runADSBReadinessTest.');
end

figure_handle = figure( ...
    'Name', 'ADS-B Readiness', ...
    'Color', 'white', ...
    'Visible', char(opts.Visible));
layout = tiledlayout(figure_handle, 2, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

timeline_axes = nexttile(layout);
localPlotTimeline(timeline_axes, result);

candidate_axes = nexttile(layout);
localPlotCandidates(candidate_axes, result);

title(layout, compose('ADS-B-only readiness: %s', upper(result.Status)));
end

function localPlotTimeline(axes_handle, result)
fixes = result.Fixes;
if isempty(fixes)
    axis(axes_handle, 'off');
    text(axes_handle, 0.5, 0.5, 'No readable ADS-B fixes in the window', ...
        'HorizontalAlignment', 'center');
    title(axes_handle, 'Truth freshness');
    return
end

window_start = result.Summary.WindowStartUTC(1);
elapsed_s = seconds(fixes.FixTimeUTC - window_start);
[aircraft_ids, ~, aircraft_index] = unique( ...
    fixes.AircraftID, 'stable');
scatter(axes_handle, elapsed_s, aircraft_index, 18, ...
    double(fixes.HasVelocity), 'filled');
hold(axes_handle, 'on');
xline(axes_handle, 0, '--k', 'window start');
window_duration_s = seconds( ...
    result.Summary.WindowEndUTC(1) - window_start);
xline(axes_handle, window_duration_s, '--k', 'window end');
hold(axes_handle, 'off');
grid(axes_handle, 'on');
xlabel(axes_handle, 'Seconds from analysis-window start');
ylabel(axes_handle, 'Aircraft');
yticks(axes_handle, 1:numel(aircraft_ids));
yticklabels(axes_handle, aircraft_ids);
title(axes_handle, 'Position-fix timing (color indicates velocity availability)');
colorbar_handle = colorbar(axes_handle);
colorbar_handle.Ticks = [0, 1];
colorbar_handle.TickLabels = {'missing', 'available'};
end

function localPlotCandidates(axes_handle, result)
candidates = result.Candidates;
if isempty(candidates)
    axis(axes_handle, 'off');
    text(axes_handle, 0.5, 0.5, 'No manual candidates available', ...
        'HorizontalAlignment', 'center');
    title(axes_handle, '599 MHz opportunity quality');
    return
end

eligible = candidates.CandidateEligible;
hold(axes_handle, 'on');
if any(~eligible)
    scatter(axes_handle, ...
        candidates.Doppler_Hz(~eligible), ...
        candidates.ExcessRange_m(~eligible) ./ 1e3, ...
        55, candidates.BiSNR_dB(~eligible), 'x', 'LineWidth', 1.5);
end
if any(eligible)
    scatter(axes_handle, ...
        candidates.Doppler_Hz(eligible), ...
        candidates.ExcessRange_m(eligible) ./ 1e3, ...
        80, candidates.BiSNR_dB(eligible), 'o', 'filled');
end
hold(axes_handle, 'off');
grid(axes_handle, 'on');
xlabel(axes_handle, 'Bistatic Doppler (Hz)');
ylabel(axes_handle, 'Bistatic excess range (km)');
title(axes_handle, ...
    'Manual candidates (circle = eligible, cross = HOLD)');
colorbar_handle = colorbar(axes_handle);
colorbar_handle.Label.String = 'Assumption-based BiSNR (dB)';

labels = "  " + candidates.AircraftID;
text(axes_handle, ...
    candidates.Doppler_Hz, ...
    candidates.ExcessRange_m ./ 1e3, ...
    labels, ...
    'Interpreter', 'none', ...
    'VerticalAlignment', 'middle');
end
