function restart_commands = helperBuildSessionRestartCommands(session_id, truth_snapshot, detector_snapshot, varargin)
%HELPERBUILDSESSIONRESTARTCOMMANDS Build MATLAB commands for fast reruns.
%
% Plain-language goal:
%   Once one full session analysis has saved the truth and detector replay
%   snapshots, most follow-on debugging should restart from those smaller
%   artifacts instead of re-running the raw-IQ pipeline.
%
% Syntax
%   cmds = helperBuildSessionRestartCommands(session_id, truth_snapshot, detector_snapshot)
%   cmds = helperBuildSessionRestartCommands(..., 'VisualizationProfile', 'core')
%
% Inputs
%   session_id        Packaged session identifier.
%   truth_snapshot    Struct returned by runBistaticAnalysisSession.
%   detector_snapshot Struct returned by runBistaticAnalysisSession.
%
% Name-value options
%   'VisualizationProfile'  Profile to show in the full-session command.
%
% Output
%   restart_commands  Struct with string commands:
%     .full_session
%     .truth_only
%     .detector_only
%
% See also: runBistaticAnalysisSession, runDetectionTruthDiagnostics,
%           runDetectorReplaySweep.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'session_id', @(x) ischar(x) || isstring(x));
addRequired(p, 'truth_snapshot');
addRequired(p, 'detector_snapshot');
addParameter(p, 'VisualizationProfile', "core", @(x) ischar(x) || isstring(x));
parse(p, session_id, truth_snapshot, detector_snapshot, varargin{:});
opts = p.Results;

restart_commands = struct( ...
    'working_folder', "BistaticDataAnalysis", ...
    'full_session', "", ...
    'truth_only', "", ...
    'detector_only', "");

session_id = string(session_id);
if strlength(session_id) > 0
    restart_commands.full_session = "out = runBistaticAnalysisSession(" + ...
        localQuoteLiteral(session_id) + ...
        ", 'VisualizationProfile', " + localQuoteLiteral(string(opts.VisualizationProfile)) + ");";
end

truth_snapshot_path = localSelectTruthSnapshotPath(truth_snapshot);
if strlength(truth_snapshot_path) > 0
    restart_commands.truth_only = "diag = runDetectionTruthDiagnostics(" + ...
        localQuoteLiteral(truth_snapshot_path) + ...
        ", 'PlotDetectionTimeSeries', true, 'PlotRDMOverlays', false, " + ...
        "'PlotTrackComparison', true);";
end

detector_snapshot_path = localSelectDetectorSnapshotPath(detector_snapshot);
if strlength(detector_snapshot_path) > 0
    restart_commands.detector_only = "replay = runDetectorReplaySweep(" + ...
        localQuoteLiteral(detector_snapshot_path) + ...
        ", 'Cases', struct('Name', 'baseline'), 'PlotDetectionTimeSeries', false, " + ...
        "'PlotRDMOverlays', false, 'Verbose', true);";
end

end

function path_value = localSelectTruthSnapshotPath(truth_snapshot)
path_value = "";
if ~isstruct(truth_snapshot)
    return
end

if isfield(truth_snapshot, 'compact_path') && ...
        strlength(string(truth_snapshot.compact_path)) > 0
    path_value = string(truth_snapshot.compact_path);
    return
end

if isfield(truth_snapshot, 'full_path') && ...
        strlength(string(truth_snapshot.full_path)) > 0
    path_value = string(truth_snapshot.full_path);
end
end

function path_value = localSelectDetectorSnapshotPath(detector_snapshot)
path_value = "";
if ~isstruct(detector_snapshot)
    return
end

if isfield(detector_snapshot, 'path') && ...
        strlength(string(detector_snapshot.path)) > 0
    path_value = string(detector_snapshot.path);
end
end

function quoted = localQuoteLiteral(value)
value = string(value);
value = replace(value, "'", "''");
quoted = "'" + value + "'";
end
