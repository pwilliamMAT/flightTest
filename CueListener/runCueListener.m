function listener = runCueListener(varargin)
%RUNCUELISTENER Listen to the ADS-B cue tasker and show the current opportunities.
%
%   Concept
%   -------
%   The ADS-B cue tasker on the Raspberry Pi multicasts one JSON cue per aircraft
%   with its predicted passive-radar observation windows (see CueListener). This
%   entrypoint joins that multicast stream on the RF collection desktop, keeps the
%   latest cue for every aircraft, and every SummaryPeriod_s prints the sender's
%   health plus the best opportunities and redraws the window timeline. It is the
%   first piece of the resource manager: it shows what could be collected. It does
%   not schedule or start collections.
%
%   Workflow
%   --------
%     L = runCueListener('Duration_s', 120);   % listen for two minutes
%     activeCues(L)                            % state is kept after it stops
%     L = runCueListener('Duration_s', Inf, 'LogFile', "cues.jsonl");   % until Ctrl-C
%
%   Name-value options
%   ------------------
%     Duration_s        how long to listen; Inf runs until Ctrl-C       (default 60)
%     SummaryPeriod_s   seconds between console summaries and redraws   (default 10)
%     ShowPlot          redraw plotCueWindows at each summary            (default true)
%     TopN              aircraft listed in each console summary          (default 10)
%   Any other name-value pair is passed to CueListener (MulticastGroup, Port,
%   InterfaceAddress, LogFile, DtvTableFile, ...).
%
%   Network notes: the cue tasker sends to 239.192.10.1:31986 with TTL 1, so the
%   listener must be on the 192.168.10.0/24 data network. The default
%   InterfaceAddress (192.168.10.41) is the collection desktop's eno1 address;
%   pass your own address on another machine.
%
%   See also CueListener, plotCueWindows.

p = inputParser;
p.FunctionName = 'runCueListener';
p.KeepUnmatched = true;
addParameter(p, 'Duration_s', 60, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SummaryPeriod_s', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ShowPlot', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'TopN', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});
o = p.Results;
listenerArgs = localUnmatchedToArgs(p.Unmatched);

listener = CueListener(listenerArgs{:});
start(listener);
cleanup = onCleanup(@() stop(listener));
fprintf('Listening for cues on %s:%d (interface %s)\n', ...
    listener.MulticastGroup, listener.LocalPort, listener.InterfaceAddress);

ax = [];
t0 = tic;
nextSummary = 0;
while toc(t0) < o.Duration_s
    poll(listener);
    if toc(t0) >= nextSummary
        nextSummary = toc(t0) + o.SummaryPeriod_s;
        localPrintSummary(listener, o.TopN);
        if o.ShowPlot
            ax = localEnsureAxes(ax);
            plotCueWindows(listener, 'Axes', ax);
            drawnow limitrate;
        end
    end
    pause(0.2);
end
localPrintSummary(listener, o.TopN);
end

function localPrintSummary(listener, topN)
s = status(listener);
stats = s.Stats;
fprintf('\n[%s UTC] sender %s | cued %d (sender active %g, eligible %g) | msgs %d, gaps %d, restarts %d, decode errors %d\n', ...
    string(datetime('now', 'TimeZone', 'UTC'), 'HH:mm:ss'), localOrDash(s.HeartbeatStatus), ...
    s.CuedTracks, s.SenderActiveTracks, s.SenderEligibleTracks, stats.Received, ...
    stats.SequenceGaps, stats.SourceRestarts, stats.DecodeErrors);
cues = activeCues(listener);
if isempty(cues)
    fprintf('  no active cues\n');
    return
end
shown = cues(1:min(height(cues), topN), {'ICAO', 'Callsign', 'ReportAge_s', ...
    'BestEmitter', 'BestPeakSNR_dB', 'BestWindowStart', 'BestWindowEnd', 'Altitude_m'});
disp(shown);
end

function ax = localEnsureAxes(ax)
% Reopen the timeline if the user closed its figure while listening.
if isempty(ax) || ~isvalid(ax)
    ax = axes(figure('Name', 'ADS-B cue windows'));
end
end

function args = localUnmatchedToArgs(unmatched)
names = fieldnames(unmatched);
args = cell(1, 2 * numel(names));
for k = 1:numel(names)
    args{2 * k - 1} = names{k};
    args{2 * k} = unmatched.(names{k});
end
end

function text = localOrDash(value)
if strlength(value) == 0
    text = "-";
else
    text = value;
end
end
