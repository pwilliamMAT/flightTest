function session_context = helperSyntheticResolveSessionContext(seed_source_input, varargin)
%HELPERSYNTHETICRESOLVESESSIONCONTEXT Resolve seed/session input to one session context.
%
% Plain language:
% Synthetic generation needs more than "the first radar file" when the
% user points at a packaged capture session. This helper accepts a direct
% baseband file, a packaged-session folder, a `session_manifest.json` path,
% or a session ID under the captures root, then returns the normalized
% session context needed by both truth generation and seed playback.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'seed_source_input', @(x) ischar(x) || isstring(x));
addParameter(p, 'RepoRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CapturesRoot', "", @(x) ischar(x) || isstring(x));
parse(p, seed_source_input, varargin{:});
opts = p.Results;

seed_token = strtrim(char(string(opts.seed_source_input)));
if isempty(seed_token)
    session_context = localDefaultSessionContext();
    return
end

repo_root = char(string(opts.RepoRoot));
if strlength(string(repo_root)) == 0
    repo_root = fileparts(fileparts(mfilename('fullpath')));
end

captures_root = char(string(opts.CapturesRoot));
if strlength(string(captures_root)) == 0
    captures_root = fullfile(repo_root, 'captures');
end

candidate_specs = localBuildCandidates(seed_token, repo_root, captures_root);
resolution_errors = strings(0, 1);

for idx = 1 : numel(candidate_specs)
    try
        session_context = localResolveCandidate(candidate_specs{idx});
        return
    catch ME
        resolution_errors(end + 1, 1) = string(ME.message); %#ok<AGROW>
    end
end

error('helperSyntheticResolveSessionContext:unresolvableSeedSource', ...
    ['Could not resolve seed source "%s" to a session context. Provide a ' ...
     'radar baseband file, a packaged-session folder, a ' ...
     '`session_manifest.json` path, or a session ID under %s.\n\nTried:\n- %s'], ...
    seed_token, captures_root, strjoin(unique(resolution_errors), '\n- '));
end

function candidate_specs = localBuildCandidates(seed_token, repo_root, captures_root)
seed_token = localNormalizeWindowsDrivePath(seed_token);
candidate_specs = {seed_token};

if ~localIsAbsolutePath(seed_token)
    candidate_specs{end + 1} = fullfile(repo_root, seed_token);
    candidate_specs{end + 1} = fullfile(captures_root, seed_token);
end

candidate_specs = unique(candidate_specs, 'stable');
end

function session_context = localResolveCandidate(candidate_spec)
candidate_spec = localNormalizeWindowsDrivePath(char(string(candidate_spec)));

if exist(candidate_spec, 'file') == 2
    [~, file_name, extension] = fileparts(candidate_spec);

    if strcmpi([file_name extension], 'session_manifest.json')
        session_context = localResolveFromManifest(candidate_spec, "session_manifest", candidate_spec);
        return
    end

    if localIsSupportedDirectBasebandFile(candidate_spec)
        session_context = localResolveFromBasebandFile(candidate_spec);
        return
    end

    error('helperSyntheticResolveSessionContext:unsupportedSeedFile', ...
        ['Seed source file is not a supported baseband file or ' ...
         '`session_manifest.json`: %s'], ...
        candidate_spec);
end

if exist(candidate_spec, 'dir') == 7
    manifest_path = fullfile(candidate_spec, 'session_manifest.json');
    if exist(manifest_path, 'file') == 2
        session_context = localResolveFromManifest(manifest_path, "session_manifest", candidate_spec);
        return
    end

    radar_folder = fullfile(candidate_spec, 'radar');
    radar_candidates = dir(fullfile(radar_folder, '*.bb'));
    if isempty(radar_candidates)
        radar_candidates = localListExtensionlessRadarFiles(radar_folder);
    end
    if ~isempty(radar_candidates)
        radar_candidates = sort({radar_candidates.name});
        radar_files = cellfun( ...
            @(name) fullfile(radar_folder, name), ...
            radar_candidates(:), ...
            'UniformOutput', false);
        session_context = localBuildContextFromRadarFiles( ...
            radar_files, ...
            {}, ...
            {}, ...
            {}, ...
            "", ...
            candidate_spec, ...
            "session_folder_without_manifest", ...
            candidate_spec, ...
            struct());
        return
    end

    error('helperSyntheticResolveSessionContext:missingSessionManifest', ...
        ['Seed source folder does not contain `session_manifest.json`, ' ...
         '`radar/*.bb`, or extensionless `radar/*` baseband files: %s'], ...
        candidate_spec);
end

error('helperSyntheticResolveSessionContext:missingSeedSource', ...
    'Seed source does not exist: %s', candidate_spec);
end

function session_context = localResolveFromBasebandFile(baseband_file_path)
baseband_file_path = char(string(baseband_file_path));
session_context = localBuildContextFromRadarFiles( ...
    {baseband_file_path}, ...
    {}, ...
    {}, ...
    {}, ...
    "", ...
    fileparts(baseband_file_path), ...
    "baseband_file", ...
    baseband_file_path, ...
    struct());

    % A direct file path should stay classified as a baseband-file input,
    % but if it sits inside a packaged capture session we still load the
    % manifest-backed context so explicit capture-truth mode can use the
    % adjacent ADS-B logs.
[manifest_path, session_folder] = localDiscoverAdjacentManifest(baseband_file_path);
if strlength(manifest_path) == 0
    return
end

manifest_context = localResolveFromManifest( ...
    char(manifest_path), ...
    "baseband_file", ...
    baseband_file_path);

source_matches_manifest = any(strcmpi( ...
    char(string(baseband_file_path)), ...
    manifest_context.radar_files));
if ~source_matches_manifest
    return
end

session_context = manifest_context;
session_context.input_kind = "baseband_file";
session_context.source_spec_path = string(baseband_file_path);
session_context.resolved_from = string(baseband_file_path);
session_context.session_folder = string(session_folder);
end

function [manifest_path, session_folder] = localDiscoverAdjacentManifest(baseband_file_path)
manifest_path = "";
session_folder = "";

parent_folder = fileparts(baseband_file_path);
grandparent_folder = fileparts(parent_folder);
if isempty(parent_folder) || isempty(grandparent_folder)
    return
end

manifest_candidate = fullfile(grandparent_folder, 'session_manifest.json');
if exist(manifest_candidate, 'file') ~= 2
    return
end

manifest_path = string(manifest_candidate);
session_folder = string(grandparent_folder);
end

function session_context = localResolveFromManifest(manifest_path, input_kind, resolved_from)
manifest_path = char(string(manifest_path));
manifest = localLoadSessionManifest(manifest_path);
session_folder = fileparts(manifest_path);
radar_files = cellfun( ...
    @(entry) localResolveManifestPath(session_folder, entry), ...
    manifest.radar_files(:), ...
    'UniformOutput', false);
adsb_files = cellfun( ...
    @(entry) localResolveManifestPath(session_folder, entry), ...
    manifest.adsb_files(:), ...
    'UniformOutput', false);

for idx = 1 : numel(radar_files)
    if exist(radar_files{idx}, 'file') ~= 2
        error('helperSyntheticResolveSessionContext:missingRadarFile', ...
            'Seed manifest %s points to a missing radar file: %s', ...
            manifest_path, radar_files{idx});
    end
end

for idx = 1 : numel(adsb_files)
    if exist(adsb_files{idx}, 'file') ~= 2
        error('helperSyntheticResolveSessionContext:missingADSBFile', ...
            'Seed manifest %s points to a missing ADS-B file: %s', ...
            manifest_path, adsb_files{idx});
    end
end

session_context = localBuildContextFromRadarFiles( ...
    radar_files, ...
    manifest.radar_files(:).', ...
    adsb_files, ...
    manifest.adsb_files(:).', ...
    manifest_path, ...
    session_folder, ...
    input_kind, ...
    resolved_from, ...
    manifest);
end

function session_context = localBuildContextFromRadarFiles( ...
    radar_files, radar_files_rel, adsb_files, adsb_files_rel, manifest_path, ...
    session_folder, input_kind, resolved_from, manifest)
header_info = localReadRadarFileHeaders(radar_files);

capture_duration_s = localManifestNumeric(manifest, 'capture_duration_s', NaN);
capture_repetitions = localManifestNumeric(manifest, 'capture_repetitions', numel(radar_files));
capture_repetition_spacing_s = localManifestNumeric( ...
    manifest, ...
    'capture_repetition_spacing_s', ...
    0);
radar_active_window_s = localManifestNumeric(manifest, 'radar_active_window_s', NaN);
radar_epoch_utc = localManifestNumeric(manifest, 'radar_epoch_utc', NaN);
sample_rate_hz = localManifestNestedNumeric(manifest, {'sdr_defaults', 'sample_rate_hz'}, NaN);
center_frequency_hz = localManifestNestedNumeric(manifest, {'sdr_defaults', 'center_frequency_hz'}, NaN);
lo_offset_hz = localManifestNestedNumeric(manifest, {'sdr_defaults', 'lo_offset_hz'}, NaN);
recorded_iq_seconds_s = localManifestNumeric(manifest, 'radar_recorded_iq_seconds_s', NaN);

if ~isfinite(sample_rate_hz)
    sample_rate_hz = header_info.sample_rate_hz(1);
end
if ~isfinite(center_frequency_hz)
    center_frequency_hz = header_info.center_frequency_hz(1);
end
if ~isfinite(lo_offset_hz)
    lo_offset_hz = header_info.lo_offset_hz(1);
end
if ~isfinite(capture_duration_s)
    capture_duration_s = header_info.duration_s(1);
end
if ~isfinite(radar_epoch_utc)
    radar_epoch_utc = header_info.recording_utc(1);
end
if ~isfinite(recorded_iq_seconds_s)
    recorded_iq_seconds_s = sum(header_info.duration_s, 'omitnan');
end
if ~isfinite(radar_active_window_s)
    radar_active_window_s = localComputeActiveWindow( ...
        capture_duration_s, ...
        capture_repetitions, ...
        capture_repetition_spacing_s, ...
        recorded_iq_seconds_s);
end

recorded_start_offsets_s = zeros(numel(radar_files), 1);
if numel(radar_files) > 1
    recorded_start_offsets_s(2:end) = cumsum(header_info.duration_s(1:end - 1), 'omitnan');
end

active_part_start_offsets_s = zeros(numel(radar_files), 1);
if numel(radar_files) > 1
    active_part_start_offsets_s = (0 : numel(radar_files) - 1).' .* ...
        (capture_duration_s + capture_repetition_spacing_s);
end

session_context = localDefaultSessionContext();
session_context.input_kind = string(input_kind);
session_context.resolved_from = string(resolved_from);
session_context.source_spec_path = localResolveSourceSpecPath( ...
    manifest_path, ...
    session_folder, ...
    input_kind, ...
    resolved_from);
session_context.manifest_path = string(manifest_path);
session_context.session_folder = string(session_folder);
session_context.radar_files = radar_files(:).';
session_context.radar_files_rel = radar_files_rel(:).';
session_context.adsb_files = adsb_files(:).';
session_context.adsb_files_rel = adsb_files_rel(:).';
session_context.first_radar_file = localFirstOrEmpty(radar_files);
session_context.radar_epoch_utc = radar_epoch_utc;
session_context.radar_active_window_s = radar_active_window_s;
session_context.capture_duration_s = capture_duration_s;
session_context.capture_repetitions = capture_repetitions;
session_context.capture_repetition_spacing_s = capture_repetition_spacing_s;
session_context.radar_recorded_iq_seconds_s = recorded_iq_seconds_s;
session_context.sample_rate_hz = sample_rate_hz;
session_context.center_frequency_hz = center_frequency_hz;
session_context.lo_offset_hz = lo_offset_hz;
session_context.radar_file_sample_counts = header_info.num_samples(:);
session_context.radar_file_durations_s = header_info.duration_s(:);
session_context.radar_file_recording_utc = header_info.recording_utc(:);
session_context.recorded_part_start_offsets_s = recorded_start_offsets_s;
session_context.active_part_start_offsets_s = active_part_start_offsets_s;
session_context.is_manifest_backed = strlength(session_context.manifest_path) > 0;
session_context.has_adsb = ~isempty(session_context.adsb_files);
end

function value = localResolveSourceSpecPath(manifest_path, session_folder, input_kind, resolved_from)
if input_kind == "baseband_file"
    value = string(resolved_from);
elseif strlength(string(manifest_path)) > 0
    value = string(manifest_path);
elseif strlength(string(session_folder)) > 0
    value = string(session_folder);
else
    value = string(resolved_from);
end
end

function header_info = localReadRadarFileHeaders(radar_files)
n_files = numel(radar_files);
header_info = struct( ...
    'sample_rate_hz', NaN(n_files, 1), ...
    'center_frequency_hz', NaN(n_files, 1), ...
    'lo_offset_hz', NaN(n_files, 1), ...
    'num_samples', NaN(n_files, 1), ...
    'duration_s', NaN(n_files, 1), ...
    'recording_utc', NaN(n_files, 1));

for idx = 1 : n_files
    try
        reader = comm.BasebandFileReader(radar_files{idx}, 'SamplesPerFrame', 1);
        cleanup_reader = onCleanup(@() release(reader));
        reader_info = info(reader);
        metadata = reader.Metadata;

        header_info.sample_rate_hz(idx) = double(reader.SampleRate);
        header_info.center_frequency_hz(idx) = double(reader.CenterFrequency);
        header_info.lo_offset_hz(idx) = localMetadataNumeric(metadata, 'LOOffset', 0);
        header_info.num_samples(idx) = double(reader_info.NumSamplesInData);
        header_info.duration_s(idx) = localResolveDurationS( ...
            metadata, ...
            header_info.num_samples(idx), ...
            header_info.sample_rate_hz(idx));
        header_info.recording_utc(idx) = localMetadataNumeric(metadata, 'RecordingUTC', NaN);
        clear cleanup_reader
    catch
        % Keep NaN header fields so callers can still surface a useful
        % resolution error if the radar file exists but cannot be read.
    end
end
end

function duration_s = localResolveDurationS(metadata, num_samples, sample_rate_hz)
duration_s = localMetadataNumeric(metadata, 'Duration_s', NaN);
if isfinite(duration_s)
    return
end

if isfinite(num_samples) && isfinite(sample_rate_hz) && sample_rate_hz > 0
    duration_s = num_samples ./ sample_rate_hz;
else
    duration_s = NaN;
end
end

function value = localMetadataNumeric(metadata, field_name, default_value)
value = double(default_value);
if ~isstruct(metadata) || ~isfield(metadata, field_name) || isempty(metadata.(field_name))
    return
end

candidate = double(metadata.(field_name));
if isscalar(candidate) && isfinite(candidate)
    value = candidate;
end
end

function value = localManifestNumeric(manifest, field_name, default_value)
value = double(default_value);
if ~isstruct(manifest) || ~isfield(manifest, field_name) || isempty(manifest.(field_name))
    return
end

candidate = double(manifest.(field_name));
if isscalar(candidate) && isfinite(candidate)
    value = candidate;
end
end

function value = localManifestNestedNumeric(manifest, field_path, default_value)
value = double(default_value);
if ~isstruct(manifest)
    return
end

source = manifest;
for idx = 1 : numel(field_path)
    field_name = field_path{idx};
    if ~isfield(source, field_name) || isempty(source.(field_name))
        return
    end
    source = source.(field_name);
end

candidate = double(source);
if isscalar(candidate) && isfinite(candidate)
    value = candidate;
end
end

function radar_active_window_s = localComputeActiveWindow( ...
    capture_duration_s, capture_repetitions, capture_repetition_spacing_s, ...
    recorded_iq_seconds_s)
if isfinite(capture_duration_s) && isfinite(capture_repetitions) && ...
        isfinite(capture_repetition_spacing_s) && capture_repetitions >= 1
    radar_active_window_s = capture_duration_s * capture_repetitions + ...
        max(capture_repetitions - 1, 0) * capture_repetition_spacing_s;
elseif isfinite(recorded_iq_seconds_s)
    radar_active_window_s = recorded_iq_seconds_s;
else
    radar_active_window_s = NaN;
end
end

function manifest = localLoadSessionManifest(manifest_path)
manifest_path = char(string(manifest_path));
if exist(manifest_path, 'file') ~= 2
    error('helperSyntheticResolveSessionContext:missingManifest', ...
        'Session manifest not found: %s', manifest_path);
end

try
    manifest = jsondecode(fileread(manifest_path));
catch ME
    error('helperSyntheticResolveSessionContext:badManifestJson', ...
        'Could not parse session manifest %s: %s', manifest_path, ME.message);
end

if ~isfield(manifest, 'radar_files')
    error('helperSyntheticResolveSessionContext:missingRadarFiles', ...
        'Session manifest %s is missing radar_files.', manifest_path);
end

manifest.radar_files = localNormalizeManifestStrings(manifest.radar_files);
if isempty(manifest.radar_files)
    error('helperSyntheticResolveSessionContext:emptyRadarFiles', ...
        'Session manifest %s must list at least one radar file.', manifest_path);
end

if isfield(manifest, 'adsb_files')
    manifest.adsb_files = localNormalizeManifestStrings(manifest.adsb_files);
else
    manifest.adsb_files = {};
end
end

function radar_file_path = localResolveManifestPath(session_folder, radar_entry)
radar_entry = localNormalizeWindowsDrivePath(char(string(radar_entry)));
if localIsAbsolutePath(radar_entry)
    radar_file_path = radar_entry;
else
    radar_file_path = fullfile(session_folder, strrep(radar_entry, '/', filesep));
end
end

function values = localNormalizeManifestStrings(raw_value)
if isempty(raw_value)
    values = {};
elseif ischar(raw_value) || (isstring(raw_value) && isscalar(raw_value))
    values = {char(string(raw_value))};
elseif isstring(raw_value)
    values = cellstr(raw_value(:));
elseif iscell(raw_value)
    values = cellfun(@(x) char(string(x)), raw_value(:), 'UniformOutput', false);
else
    error('helperSyntheticResolveSessionContext:badManifestField', ...
        'Manifest string fields must decode to char, string, or cell arrays of strings.');
end
end

function normalized_path = localNormalizeWindowsDrivePath(path_value)
normalized_path = char(string(path_value));
if ispc && ~isempty(regexp(normalized_path, '^/[A-Za-z]:[\\/]', 'once'))
    normalized_path = normalized_path(2:end);
end
end

function tf = localIsAbsolutePath(path_value)
if ispc
    tf = ~isempty(regexp(path_value, '^[A-Za-z]:[\\/]', 'once')) || startsWith(path_value, '\\');
else
    tf = startsWith(path_value, filesep);
end
end

function tf = localIsSupportedDirectBasebandFile(candidate_spec)
[~, file_name, extension] = fileparts(candidate_spec);
if strcmpi([file_name extension], 'session_manifest.json')
    tf = false;
    return
end

tf = strcmpi(extension, '.bb') || strlength(string(extension)) == 0;
end

function radar_candidates = localListExtensionlessRadarFiles(radar_folder)
if exist(radar_folder, 'dir') ~= 7
    radar_candidates = struct('name', {}, 'folder', {}, 'date', {}, 'bytes', {}, ...
        'isdir', {}, 'datenum', {});
    return
end

all_entries = dir(radar_folder);
is_regular_file = ~[all_entries.isdir];
has_no_extension = arrayfun(@(entry) strlength(string(localGetExtension(entry.name))) == 0, all_entries);
radar_candidates = all_entries(is_regular_file & has_no_extension);
end

function extension = localGetExtension(file_name)
[~, ~, extension] = fileparts(file_name);
end

function first_value = localFirstOrEmpty(values)
if isempty(values)
    first_value = "";
else
    first_value = string(values{1});
end
end

function session_context = localDefaultSessionContext()
session_context = struct( ...
    'input_kind', "not_applicable", ...
    'resolved_from', "", ...
    'source_spec_path', "", ...
    'manifest_path', "", ...
    'session_folder', "", ...
    'radar_files', {{}}, ...
    'radar_files_rel', {{}}, ...
    'adsb_files', {{}}, ...
    'adsb_files_rel', {{}}, ...
    'first_radar_file', "", ...
    'radar_epoch_utc', NaN, ...
    'radar_active_window_s', NaN, ...
    'capture_duration_s', NaN, ...
    'capture_repetitions', 0, ...
    'capture_repetition_spacing_s', NaN, ...
    'radar_recorded_iq_seconds_s', NaN, ...
    'sample_rate_hz', NaN, ...
    'center_frequency_hz', NaN, ...
    'lo_offset_hz', NaN, ...
    'radar_file_sample_counts', zeros(0, 1), ...
    'radar_file_durations_s', zeros(0, 1), ...
    'radar_file_recording_utc', zeros(0, 1), ...
    'recorded_part_start_offsets_s', zeros(0, 1), ...
    'active_part_start_offsets_s', zeros(0, 1), ...
    'is_manifest_backed', false, ...
    'has_adsb', false);
end
