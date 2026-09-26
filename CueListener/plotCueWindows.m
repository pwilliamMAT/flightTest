function ax = plotCueWindows(listener, varargin)
%PLOTCUEWINDOWS Timeline of predicted passive-radar observation windows per aircraft.
%
%   Concept
%   -------
%   Every track cue carries, for its best DTV illuminators, the time windows in
%   which the predicted bistatic SNR stays above the detection threshold. Drawn
%   on one time axis, they show the resource manager at a glance which aircraft
%   can be collected on, with which tower, starting when and for how long. That is
%   the scheduling question the collection system has to answer.
%
%   Each row is one aircraft (strongest first). Each bar is one window, coloured by
%   its peak predicted SNR and labelled with the illuminator. The vertical line
%   marks "now", and a dot marks the time of peak SNR inside each window.
%
%   Workflow
%   --------
%     L = CueListener.replay("capture.jsonl");
%     plotCueWindows(L, 'Now', datetime(2026,9,26,0,52,0,'TimeZone','UTC'));
%
%   Name-value options
%   ------------------
%     Now        reference time (UTC) for "active" and the now-line (default: current time)
%     Axes       axes to draw into (default: new figure)
%     MaxTracks  most aircraft to show, strongest first (default 15)
%
%   See also CueListener, runCueListener.

p = inputParser;
p.FunctionName = 'plotCueWindows';
addRequired(p, 'listener', @(x) isa(x, 'CueListener'));
addParameter(p, 'Now', datetime('now', 'TimeZone', 'UTC'), @isdatetime);
addParameter(p, 'Axes', [], @(x) isempty(x) || isa(x, 'matlab.graphics.axis.Axes'));
addParameter(p, 'MaxTracks', 15, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, listener, varargin{:});
o = p.Results;

ax = o.Axes;
if isempty(ax)
    ax = axes(figure('Name', 'ADS-B cue windows'));
end
cla(ax);
hold(ax, 'on');

cues = activeCues(listener, 'Now', o.Now);
cues = cues(1:min(height(cues), o.MaxTracks), :);
nTracks = height(cues);

% One colour scale for every bar: from the weakest to the strongest window shown.
windowTables = cell(nTracks, 1);
allSnr = [];
for k = 1:nTracks
    windowTables{k} = opportunities(listener, cues.TrackId(k));
    if ~isempty(windowTables{k})
        allSnr = [allSnr; windowTables{k}.PeakSNR_dB]; %#ok<AGROW>
    end
end
cmap = parula(256);
if isempty(allSnr)
    snrLimits = [0 1];
else
    snrLimits = [min(allSnr) max(allSnr)];
    if diff(snrLimits) < 1
        snrLimits = snrLimits + [-0.5 0.5];
    end
end

for k = 1:nTracks
    y = nTracks - k + 1;   % strongest aircraft at the top
    windows = windowTables{k};
    nWindows = height(windows);
    for j = 1:nWindows
        % Spread an aircraft's windows vertically so overlapping bars stay visible.
        yj = y + 0.3 * ((j - 1) / max(nWindows - 1, 1) - 0.5) * (nWindows > 1);
        colour = cmap(localColourIndex(windows.PeakSNR_dB(j), snrLimits, size(cmap, 1)), :);
        plot(ax, [windows.WindowStart(j) windows.WindowEnd(j)], [yj yj], '-', ...
            'LineWidth', 7, 'Color', colour, 'Tag', 'CueWindow');
        plot(ax, windows.PeakSNRTime(j), yj, 'k.', 'MarkerSize', 10);
        text(ax, windows.WindowStart(j), yj, " " + windows.Emitter(j), ...
            'FontSize', 7, 'VerticalAlignment', 'middle', 'Clipping', 'on');
    end
end

xline(ax, o.Now, '--', 'now', 'Color', [0.8 0.1 0.1]);
colormap(ax, cmap);
clim(ax, snrLimits);
cb = colorbar(ax);
cb.Label.String = 'Peak predicted bistatic SNR (dB, pre-integration)';
labels = strings(nTracks, 1);
for k = 1:nTracks
    labels(nTracks - k + 1) = strtrim(cues.ICAO(k) + " " + cues.Callsign(k));
end
set(ax, 'YTick', 1:nTracks, 'YTickLabel', labels, 'YLim', [0.4 max(nTracks, 1) + 0.6]);
grid(ax, 'on');
xlabel(ax, 'Time (UTC)');
status = listener.status();
title(ax, sprintf('Cued aircraft: %d shown of %d active | sender: %s', ...
    nTracks, height(activeCues(listener, 'Now', o.Now)), localOrDash(status.HeartbeatStatus)));
hold(ax, 'off');
end

function index = localColourIndex(value, limits, n)
fraction = (value - limits(1)) / diff(limits);
index = min(max(round(1 + fraction * (n - 1)), 1), n);
end

function text = localOrDash(value)
if strlength(value) == 0
    text = "-";
else
    text = value;
end
end
