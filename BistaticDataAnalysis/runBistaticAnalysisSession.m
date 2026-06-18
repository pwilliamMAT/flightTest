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
%    'SaveDetectorReplaySnapshot'    Save a detector-replay snapshot under
%                                    <session>/analysis. Default: true
%    'DetectorReplaySnapshotFolder'  Override the detector snapshot folder.
%    'DetectorReplaySnapshotBaseName'
%                                    Override the detector snapshot filename stem.

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
addParameter(p, 'PartTimingSource', 'auto', @localIsPartTimingSource);
addParameter(p, 'SaveTruthDiagnosticSnapshot', true, @islogical);
addParameter(p, 'TruthDiagnosticSnapshotMode', 'compact', @localIsSnapshotMode);
addParameter(p, 'TruthDiagnosticSnapshotFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'TruthDiagnosticSnapshotBaseName', 'truth_diag_input', @(x) ischar(x) || isstring(x));
addParameter(p, 'SaveDetectorReplaySnapshot', true, @islogical);
addParameter(p, 'DetectorReplaySnapshotFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'DetectorReplaySnapshotBaseName', 'detector_replay_input', @(x) ischar(x) || isstring(x));
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
analysisSetup.session_wrapper_options = localBuildWrapperOptions(opts);
analysisSetup.part_timing_source = char(string(opts.PartTimingSource));

fprintf('Session analysis preflight:\n');
fprintf('  session_id   : %s\n', analysisSetup.session_id);
fprintf('  session_dir  : %s\n', analysisSetup.session_folder);
fprintf('  manifest     : %s\n', analysisSetup.manifest_path);
fprintf('  radar files  : %d\n', numel(analysisSetup.data_parts));
fprintf('  ADS-B files  : %d\n', numel(analysisSetup.adsb_files));
fprintf('  part timing  : %s\n', analysisSetup.part_timing_source);
if isfield(analysisSetup, 'radar_epoch_utc') && ~isempty(analysisSetup.radar_epoch_utc)
    fprintf('  radar epoch  : %.6f UTC Unix seconds\n', analysisSetup.radar_epoch_utc);
else
fprintf('  radar epoch  : auto-read from the first radar file when available\n');
end
fprintf('\n');

part_start_offsets_s = [];
part_end_offsets_s = [];
part_dur_s = [];
part_timing_info = struct();

run(fullfile(fileparts(mfilename('fullpath')), 'analyzeBistaticData.m'));
session_opts = localResolveWrapperOptions(analysisSetup);

analysis_output = struct( ...
    'session_id', string(analysisSetup.session_id), ...
    'session_folder', string(analysisSetup.session_folder), ...
    'manifest_path', string(analysisSetup.manifest_path), ...
    'radar_files', {analysisSetup.data_parts}, ...
    'adsb_files', {analysisSetup.adsb_files});

if isfield(analysisSetup, 'radar_epoch_utc')
    analysis_output.radar_epoch_utc = analysisSetup.radar_epoch_utc;
end

analysis_output.truth_diag_snapshot = localDefaultTruthSnapshotStatus( ...
    analysisSetup.session_folder, session_opts);
analysis_output.detector_replay_snapshot = localDefaultDetectorReplaySnapshotStatus( ...
    analysisSetup.session_folder, session_opts);

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
if exist('part_start_offsets_s', 'var')
    analysis_output.part_start_offsets_s = part_start_offsets_s(:);
end
if exist('part_end_offsets_s', 'var')
    analysis_output.part_end_offsets_s = part_end_offsets_s(:);
end
if exist('part_dur_s', 'var') && ~isempty(part_dur_s)
    analysis_output.part_duration_s = part_dur_s;
end
if exist('part_timing_info', 'var') && isstruct(part_timing_info)
    analysis_output.part_timing_info = part_timing_info;
end
if exist('part_start_offsets_s', 'var') && exist('part_dur_s', 'var')
    part_timing_info_local = struct();
    if exist('part_timing_info', 'var') && isstruct(part_timing_info)
        part_timing_info_local = part_timing_info;
    end
    analysis_output.part_timing_summary = localBuildPartTimingSummary( ...
        part_start_offsets_s, part_dur_s, part_timing_info_local);
end
if exist('truth_diag_input', 'var')
    analysis_output.truth_diag_input = truth_diag_input;
    if session_opts.save_truth_snapshot && ~strcmpi(session_opts.truth_snapshot_mode, "off")
        try
            saved_snapshot = helperSaveTruthDiagnosticSnapshots( ...
                truth_diag_input, analysisSetup.session_folder, ...
                'SnapshotMode', session_opts.truth_snapshot_mode, ...
                'OutputFolder', session_opts.truth_snapshot_folder, ...
                'BaseName', session_opts.truth_snapshot_base_name, ...
                'Verbose', false);
            analysis_output.truth_diag_snapshot = localMergeStruct( ...
                analysis_output.truth_diag_snapshot, saved_snapshot);
            analysis_output.truth_diag_snapshot.saved = localTruthSnapshotSaved(saved_snapshot);
            if analysis_output.truth_diag_snapshot.saved
                analysis_output.truth_diag_snapshot.status = "saved";
                analysis_output.truth_diag_snapshot.message = "";
            else
                analysis_output.truth_diag_snapshot.status = "unavailable";
                analysis_output.truth_diag_snapshot.message = ...
                    "Truth snapshot save completed without producing a snapshot path.";
            end
            localPrintSnapshotInfo(analysis_output.truth_diag_snapshot);
        catch ME
            analysis_output.truth_diag_snapshot.status = "error";
            analysis_output.truth_diag_snapshot.message = string(ME.message);
            warning('runBistaticAnalysisSession:truthSnapshotSaveFailed', ...
                'Truth diagnostic snapshot was not saved: %s', ME.message);
        end
    elseif session_opts.save_truth_snapshot
        analysis_output.truth_diag_snapshot.message = ...
            "Truth snapshot saving is disabled because TruthDiagnosticSnapshotMode is 'off'.";
    else
        analysis_output.truth_diag_snapshot.message = ...
            "Truth snapshot saving is disabled by SaveTruthDiagnosticSnapshot=false.";
    end
elseif session_opts.save_truth_snapshot && session_opts.verbose
    fprintf('Truth diagnostic snapshot not saved: no truth_diag_input was produced.\n');
    if strlength(analysis_output.truth_diag_snapshot.message) == 0
        analysis_output.truth_diag_snapshot.message = ...
            "Truth diagnostic input was not produced by analyzeBistaticData.";
    end
end
if exist('truth_diag_output', 'var') && isstruct(truth_diag_output) && ...
        isfield(truth_diag_output, 'check_summary')
    analysis_output.truth_diag_summary = truth_diag_output.check_summary;
end

if exist('config', 'var') && exist('data_parts', 'var') && ...
        exist('part_start_offsets_s', 'var') && exist('part_end_offsets_s', 'var') && ...
        exist('part_res', 'var')
    detector_truth_template = struct([]);
    if exist('truth_diag_input', 'var') && isstruct(truth_diag_input) && ~isempty(truth_diag_input)
        detector_truth_template = localCompactTruthTemplate(truth_diag_input);
    end

    tracks_log_for_replay = [];
    if exist('tracks_log', 'var') && ~isempty(tracks_log)
        tracks_log_for_replay = tracks_log;
    end

    part_duration_s = NaN;
    if exist('part_dur_s', 'var') && ~isempty(part_dur_s)
        part_duration_s = part_dur_s;
    end

    detector_replay_input = buildDetectorReplayInput( ...
        config, data_parts, part_start_offsets_s, part_end_offsets_s, part_res, ...
        'SessionID', analysisSetup.session_id, ...
        'AnalysisLabel', localResolveDetectorReplayLabel(analysisSetup, detector_truth_template), ...
        'PartDurationS', part_duration_s, ...
        'TruthDiagnosticInput', detector_truth_template, ...
        'TracksLog', tracks_log_for_replay, ...
        'Verbose', false);
    analysis_output.detector_replay_input = detector_replay_input;

    if session_opts.save_detector_snapshot
        try
            saved_snapshot = helperSaveDetectorReplaySnapshot( ...
                detector_replay_input, analysisSetup.session_folder, ...
                'OutputFolder', session_opts.detector_snapshot_folder, ...
                'BaseName', session_opts.detector_snapshot_base_name, ...
                'Verbose', false);
            analysis_output.detector_replay_snapshot = localMergeStruct( ...
                analysis_output.detector_replay_snapshot, saved_snapshot);
            analysis_output.detector_replay_snapshot.saved = ...
                isfield(saved_snapshot, 'path') && strlength(saved_snapshot.path) > 0;
            if analysis_output.detector_replay_snapshot.saved
                analysis_output.detector_replay_snapshot.status = "saved";
                analysis_output.detector_replay_snapshot.message = "";
            else
                analysis_output.detector_replay_snapshot.status = "unavailable";
                analysis_output.detector_replay_snapshot.message = ...
                    "Detector replay snapshot save completed without producing a snapshot path.";
            end
            localPrintDetectorReplaySnapshotInfo(analysis_output.detector_replay_snapshot);
        catch ME
            analysis_output.detector_replay_snapshot.status = "error";
            analysis_output.detector_replay_snapshot.message = string(ME.message);
            warning('runBistaticAnalysisSession:detectorReplaySnapshotSaveFailed', ...
                'Detector replay snapshot was not saved: %s', ME.message);
        end
    else
        analysis_output.detector_replay_snapshot.message = ...
            "Detector replay snapshot saving is disabled by SaveDetectorReplaySnapshot=false.";
    end
elseif session_opts.save_detector_snapshot && session_opts.verbose
    fprintf('Detector replay snapshot not saved: no detector replay input was produced.\n');
    if strlength(analysis_output.detector_replay_snapshot.message) == 0
        analysis_output.detector_replay_snapshot.message = ...
            "Detector replay input was not produced by analyzeBistaticData.";
    end
end

end

function tf = localIsSnapshotMode(value)
mode = char(string(value));
tf = any(strcmpi(mode, {'compact', 'full', 'both', 'off'}));
end

function tf = localIsPartTimingSource(value)
mode = char(string(value));
tf = any(strcmpi(mode, {'auto', 'metadata', 'fallback'}));
end

function wrapper_opts = localBuildWrapperOptions(opts)
wrapper_opts = struct( ...
    'verbose', logical(opts.Verbose), ...
    'save_truth_snapshot', logical(opts.SaveTruthDiagnosticSnapshot), ...
    'truth_snapshot_mode', string(opts.TruthDiagnosticSnapshotMode), ...
    'truth_snapshot_folder', string(opts.TruthDiagnosticSnapshotFolder), ...
    'truth_snapshot_base_name', string(opts.TruthDiagnosticSnapshotBaseName), ...
    'save_detector_snapshot', logical(opts.SaveDetectorReplaySnapshot), ...
    'detector_snapshot_folder', string(opts.DetectorReplaySnapshotFolder), ...
    'detector_snapshot_base_name', string(opts.DetectorReplaySnapshotBaseName));
end

function wrapper_opts = localResolveWrapperOptions(analysisSetup)
wrapper_opts = localBuildWrapperOptions(struct( ...
    'Verbose', false, ...
    'SaveTruthDiagnosticSnapshot', true, ...
    'TruthDiagnosticSnapshotMode', 'compact', ...
    'TruthDiagnosticSnapshotFolder', "", ...
    'TruthDiagnosticSnapshotBaseName', 'truth_diag_input', ...
    'SaveDetectorReplaySnapshot', true, ...
    'DetectorReplaySnapshotFolder', "", ...
    'DetectorReplaySnapshotBaseName', 'detector_replay_input'));

if isstruct(analysisSetup) && isfield(analysisSetup, 'session_wrapper_options') && ...
        isstruct(analysisSetup.session_wrapper_options)
    wrapper_opts = localMergeStruct(wrapper_opts, analysisSetup.session_wrapper_options);
end
end

function snapshot_status = localDefaultTruthSnapshotStatus(session_folder, wrapper_opts)
snapshot_status = struct( ...
    'saved', false, ...
    'status', "unavailable", ...
    'mode', string(wrapper_opts.truth_snapshot_mode), ...
    'output_folder', localResolveSnapshotOutputFolder( ...
        session_folder, wrapper_opts.truth_snapshot_folder), ...
    'compact_path', "", ...
    'full_path', "", ...
    'message', localDefaultTruthSnapshotMessage(wrapper_opts));
end

function snapshot_status = localDefaultDetectorReplaySnapshotStatus(session_folder, wrapper_opts)
snapshot_status = struct( ...
    'saved', false, ...
    'status', "unavailable", ...
    'output_folder', localResolveSnapshotOutputFolder( ...
        session_folder, wrapper_opts.detector_snapshot_folder), ...
    'path', "", ...
    'message', localDefaultDetectorReplaySnapshotMessage(wrapper_opts));
end

function output_folder = localResolveSnapshotOutputFolder(session_folder, override_folder)
output_folder = string(override_folder);
if strlength(output_folder) == 0
    output_folder = string(fullfile(char(string(session_folder)), 'analysis'));
end
end

function tf = localTruthSnapshotSaved(snapshot_info)
tf = false;
if ~isstruct(snapshot_info)
    return
end

if isfield(snapshot_info, 'compact_path') && strlength(snapshot_info.compact_path) > 0
    tf = true;
    return
end

if isfield(snapshot_info, 'full_path') && strlength(snapshot_info.full_path) > 0
    tf = true;
end
end

function message = localDefaultTruthSnapshotMessage(wrapper_opts)
if ~wrapper_opts.save_truth_snapshot
    message = "Truth snapshot saving is disabled by SaveTruthDiagnosticSnapshot=false.";
elseif strcmpi(wrapper_opts.truth_snapshot_mode, "off")
    message = "Truth snapshot saving is disabled because TruthDiagnosticSnapshotMode is 'off'.";
else
    message = "";
end
end

function message = localDefaultDetectorReplaySnapshotMessage(wrapper_opts)
if ~wrapper_opts.save_detector_snapshot
    message = "Detector replay snapshot saving is disabled by SaveDetectorReplaySnapshot=false.";
else
    message = "";
end
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

function localPrintDetectorReplaySnapshotInfo(snapshot_info)
if ~isstruct(snapshot_info)
    return
end

if isfield(snapshot_info, 'path') && strlength(snapshot_info.path) > 0
    fprintf('Saved detector replay snapshot: %s\n', char(snapshot_info.path));
end
end

function truth_template = localCompactTruthTemplate(truth_diag_input)
truth_template = truth_diag_input;
if isfield(truth_template, 'rdm_parts')
    truth_template = rmfield(truth_template, 'rdm_parts');
end
end

function analysis_label = localResolveDetectorReplayLabel(analysisSetup, truth_template)
if isstruct(truth_template) && isfield(truth_template, 'analysis_label') && ...
        ~isempty(truth_template.analysis_label)
    analysis_label = char(string(truth_template.analysis_label));
elseif isfield(analysisSetup, 'session_id') && strlength(string(analysisSetup.session_id)) > 0
    analysis_label = sprintf('Session %s', char(string(analysisSetup.session_id)));
else
    analysis_label = 'Detector Replay';
end
end

function merged = localMergeStruct(base_struct, override_struct)
merged = base_struct;
if ~isstruct(override_struct)
    return
end

override_fields = fieldnames(override_struct);
for k = 1 : numel(override_fields)
    field_name = override_fields{k};
    merged.(field_name) = override_struct.(field_name);
end
end

function timing_summary = localBuildPartTimingSummary(part_start_offsets_s, part_dur_s, part_timing_info)
part_start_offsets_s = part_start_offsets_s(:);
start_spacing_s = diff(part_start_offsets_s);
inter_part_gap_s = start_spacing_s - part_dur_s;

requested_source = "";
resolved_source = "";
used_metadata = false(numel(part_start_offsets_s), 1);

if isstruct(part_timing_info)
    if isfield(part_timing_info, 'requested_source')
        requested_source = string(part_timing_info.requested_source);
    end
    if isfield(part_timing_info, 'source')
        resolved_source = string(part_timing_info.source);
    end
    if isfield(part_timing_info, 'used_metadata') && ...
            numel(part_timing_info.used_metadata) == numel(part_start_offsets_s)
        used_metadata = logical(part_timing_info.used_metadata(:));
    end
end

timing_summary = struct( ...
    'requested_source', requested_source, ...
    'resolved_source', resolved_source, ...
    'n_parts', numel(part_start_offsets_s), ...
    'part_duration_s', part_dur_s, ...
    'part_start_offsets_s', part_start_offsets_s, ...
    'start_spacing_s', start_spacing_s, ...
    'inter_part_gap_s', inter_part_gap_s, ...
    'median_start_spacing_s', localMedianOrNaN(start_spacing_s), ...
    'median_gap_s', localMedianOrNaN(inter_part_gap_s), ...
    'used_metadata', used_metadata, ...
    'n_metadata_parts', nnz(used_metadata));
end

function value = localMedianOrNaN(x)
if isempty(x)
    value = NaN;
else
    value = median(x, 'omitnan');
end
end
