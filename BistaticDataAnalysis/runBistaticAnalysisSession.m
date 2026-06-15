function analysis_output = runBistaticAnalysisSession(session_id, varargin)
%RUNBISTATICANALYSISSESSION Run analyzeBistaticData on one packaged session.
%  Example:
%    out = runBistaticAnalysisSession('20260611T101530');
%
%  Key name-value options:
%    'SaveTruthDiagnosticSnapshot'   Save a post-detection truth snapshot
%                                    under <session>/analysis. Default: true
%    'TruthDiagnosticSnapshotMode'   'compact', 'full', 'both', or 'off'.
%                                    Default: 'compact'
%    'TruthDiagnosticSnapshotFolder' Override the snapshot output folder.
%    'TruthDiagnosticSnapshotBaseName'
%                                    Override the snapshot filename stem.

if nargin < 1
    session_id = "";
end

p = inputParser;
p.FunctionName = mfilename;
addOptional(p, 'session_id', session_id, @(x) isempty(x) || ischar(x) || isstring(x));
addParameter(p, 'DatasetRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', false, @islogical);
addParameter(p, 'SaveTruthDiagnosticSnapshot', true, @islogical);
addParameter(p, 'TruthDiagnosticSnapshotMode', 'compact', @localIsSnapshotMode);
addParameter(p, 'TruthDiagnosticSnapshotFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'TruthDiagnosticSnapshotBaseName', 'truth_diag_input', @(x) ischar(x) || isstring(x));
parse(p, session_id, varargin{:});
opts = p.Results;

repo_root = fileparts(fileparts(mfilename('fullpath')));
if strlength(string(opts.DatasetRoot)) == 0
    dataset_root = fullfile(repo_root, 'captures');
else
    dataset_root = char(string(opts.DatasetRoot));
end

analysisSetup = helperResolveSessionAnalysisSetup(opts.session_id, ...
    'DatasetRoot', dataset_root, ...
    'SessionFolder', opts.SessionFolder, ...
    'ManifestPath', opts.ManifestPath, ...
    'Verbose', opts.Verbose);

fprintf('Session analysis preflight:\n');
fprintf('  session_id   : %s\n', analysisSetup.session_id);
fprintf('  session_dir  : %s\n', analysisSetup.session_folder);
fprintf('  manifest     : %s\n', analysisSetup.manifest_path);
fprintf('  radar files  : %d\n', numel(analysisSetup.data_parts));
fprintf('  ADS-B files  : %d\n', numel(analysisSetup.adsb_files));
if isfield(analysisSetup, 'radar_epoch_utc') && ~isempty(analysisSetup.radar_epoch_utc)
    fprintf('  radar epoch  : %.6f UTC Unix seconds\n', analysisSetup.radar_epoch_utc);
else
    fprintf('  radar epoch  : auto-read from the first radar file when available\n');
end
fprintf('\n');

run(fullfile(fileparts(mfilename('fullpath')), 'analyzeBistaticData.m'));

analysis_output = struct( ...
    'session_id', string(analysisSetup.session_id), ...
    'session_folder', string(analysisSetup.session_folder), ...
    'manifest_path', string(analysisSetup.manifest_path), ...
    'radar_files', {analysisSetup.data_parts}, ...
    'adsb_files', {analysisSetup.adsb_files});

if isfield(analysisSetup, 'radar_epoch_utc')
    analysis_output.radar_epoch_utc = analysisSetup.radar_epoch_utc;
end

if exist('data_parts', 'var')
    analysis_output.data_parts = data_parts;
end
if exist('all_track_dets', 'var')
    analysis_output.all_track_dets = all_track_dets;
end
if exist('adsb_tracks', 'var')
    analysis_output.adsb_tracks = adsb_tracks;
end
if exist('adsb_aligned', 'var')
    analysis_output.adsb_aligned = adsb_aligned;
end
if exist('truth_metrics', 'var')
    analysis_output.truth_metrics = truth_metrics;
end
if exist('truth_diag_input', 'var')
    analysis_output.truth_diag_input = truth_diag_input;
    if opts.SaveTruthDiagnosticSnapshot
        analysis_output.truth_diag_snapshot = helperSaveTruthDiagnosticSnapshots( ...
            truth_diag_input, analysisSetup.session_folder, ...
            'SnapshotMode', opts.TruthDiagnosticSnapshotMode, ...
            'OutputFolder', opts.TruthDiagnosticSnapshotFolder, ...
            'BaseName', opts.TruthDiagnosticSnapshotBaseName, ...
            'Verbose', false);
        localPrintSnapshotInfo(analysis_output.truth_diag_snapshot);
    end
elseif opts.SaveTruthDiagnosticSnapshot && opts.Verbose
    fprintf('Truth diagnostic snapshot not saved: no truth_diag_input was produced.\n');
end
if exist('truth_diag_output', 'var') && isstruct(truth_diag_output) && ...
        isfield(truth_diag_output, 'check_summary')
    analysis_output.truth_diag_summary = truth_diag_output.check_summary;
end

end

function tf = localIsSnapshotMode(value)
mode = char(string(value));
tf = any(strcmpi(mode, {'compact', 'full', 'both', 'off'}));
end

function localPrintSnapshotInfo(snapshot_info)
if ~isstruct(snapshot_info)
    return
end

if isfield(snapshot_info, 'compact_path') && strlength(snapshot_info.compact_path) > 0
    fprintf('Saved compact truth snapshot: %s\n', char(snapshot_info.compact_path));
end
if isfield(snapshot_info, 'full_path') && strlength(snapshot_info.full_path) > 0
    fprintf('Saved full truth snapshot: %s\n', char(snapshot_info.full_path));
end
end
