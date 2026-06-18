function comparison_run = runTruthFixTimingComparison(session_id, varargin)
%RUNTRUTHFIXTIMINGCOMPARISON Run the truth-fix timing A/B rerun on one session.
%
% Plain-language goal:
%   The remaining ADS-B truth question is whether the per-part timing taken
%   from radar-file metadata is helping or hurting truth alignment. This
%   helper reruns the same packaged session twice, once with metadata
%   timing and once with the simple fallback spacing, and then compares the
%   two outputs side by side.
%
% Syntax
%   comparison_run = runTruthFixTimingComparison('20260616T160702')
%
% Name-value options
%   'DatasetRoot'                Override the packaged-session root.
%   'SessionFolder'              Override the packaged session folder.
%   'ManifestPath'               Override the session manifest path.
%   'ReferenceLogPath'           Optional pre-patch console log.
%   'ClearFunctionsBetweenRuns'  Call clear functions before each run.
%                                Default: true
%   'SaveTruthDiagnosticSnapshot'
%   'TruthDiagnosticSnapshotMode'
%   'SaveDetectorReplaySnapshot' Forwarded to runBistaticAnalysisSession.
%   'Verbose'                    Print progress and comparison output.
%
% Output
%   comparison_run               Struct containing:
%     .metadata_output
%     .fallback_output
%     .comparison
%
% See also: runBistaticAnalysisSession, compareBistaticTimingModes.

if nargin < 1
    session_id = "";
end

repo_root = fileparts(fileparts(mfilename('fullpath')));
default_reference_log = string(fullfile(fileparts(repo_root), 'bistaticOutput.txt'));
if exist(char(default_reference_log), 'file') ~= 2
    default_reference_log = "";
end

p = inputParser;
p.FunctionName = mfilename;
addOptional(p, 'session_id', session_id, @(x) isempty(x) || ischar(x) || isstring(x));
addParameter(p, 'DatasetRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ReferenceLogPath', default_reference_log, @(x) ischar(x) || isstring(x));
addParameter(p, 'ClearFunctionsBetweenRuns', true, @islogical);
addParameter(p, 'SaveTruthDiagnosticSnapshot', false, @islogical);
addParameter(p, 'TruthDiagnosticSnapshotMode', 'off', @(x) ischar(x) || isstring(x));
addParameter(p, 'SaveDetectorReplaySnapshot', false, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, session_id, varargin{:});
opts = p.Results;

metadata_kwargs = localBuildSessionArgs(opts, 'metadata');
fallback_kwargs = localBuildSessionArgs(opts, 'fallback');

if opts.Verbose
    fprintf('\n[runTruthFixTimingComparison] Session %s\n', char(string(opts.session_id)));
    fprintf('[runTruthFixTimingComparison] Pass 1/2: metadata timing\n');
end
localMaybeClearFunctions(opts.ClearFunctionsBetweenRuns);
metadata_output = runBistaticAnalysisSession(opts.session_id, metadata_kwargs{:});

if opts.Verbose
    fprintf('\n[runTruthFixTimingComparison] Pass 2/2: fallback timing\n');
end
localMaybeClearFunctions(opts.ClearFunctionsBetweenRuns);
fallback_output = runBistaticAnalysisSession(opts.session_id, fallback_kwargs{:});

comparison = compareBistaticTimingModes(metadata_output, fallback_output, ...
    'ReferenceLogPath', opts.ReferenceLogPath, ...
    'Verbose', opts.Verbose);

comparison_run = struct( ...
    'metadata_output', metadata_output, ...
    'fallback_output', fallback_output, ...
    'comparison', comparison);

end

function args = localBuildSessionArgs(opts, timing_source)
args = { ...
    'DatasetRoot', opts.DatasetRoot, ...
    'SessionFolder', opts.SessionFolder, ...
    'ManifestPath', opts.ManifestPath, ...
    'Verbose', opts.Verbose, ...
    'PartTimingSource', timing_source, ...
    'SaveTruthDiagnosticSnapshot', logical(opts.SaveTruthDiagnosticSnapshot), ...
    'TruthDiagnosticSnapshotMode', opts.TruthDiagnosticSnapshotMode, ...
    'SaveDetectorReplaySnapshot', logical(opts.SaveDetectorReplaySnapshot)};
end

function localMaybeClearFunctions(do_clear)
if ~do_clear
    return
end

clear functions
end
