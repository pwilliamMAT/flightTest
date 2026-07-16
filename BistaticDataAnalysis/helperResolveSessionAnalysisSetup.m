function analysis_setup = helperResolveSessionAnalysisSetup(session_id, varargin)
%HELPERRESOLVESESSIONANALYSISSETUP Resolve one packaged session into inputs for analysis.

p = inputParser;
p.FunctionName = mfilename;
addOptional(p, 'session_id', session_id, @(x) isempty(x) || ischar(x) || isstring(x));
addParameter(p, 'DatasetRoot', helperResolvePackagedCaptureRoot(), @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', false, @islogical);
parse(p, session_id, varargin{:});
opts = p.Results;

requested_session = char(string(opts.session_id));
dataset_root = char(string(opts.DatasetRoot));
session_folder = char(string(opts.SessionFolder));
manifest_path = char(string(opts.ManifestPath));

if strlength(string(manifest_path)) > 0
    manifest_path = char(string(manifest_path));
    session_folder = fileparts(manifest_path);
elseif strlength(string(session_folder)) > 0
    session_folder = char(string(session_folder));
    manifest_path = fullfile(session_folder, 'session_manifest.json');
elseif strlength(string(requested_session)) > 0
    session_folder = fullfile(dataset_root, requested_session);
    manifest_path = fullfile(session_folder, 'session_manifest.json');
else
    candidate_dirs = dir(dataset_root);
    candidate_dirs = candidate_dirs([candidate_dirs.isdir]);
    candidate_dirs = candidate_dirs(~ismember({candidate_dirs.name}, {'.', '..'}));
    keep = false(size(candidate_dirs));
    for k = 1:numel(candidate_dirs)
        keep(k) = exist(fullfile(dataset_root, candidate_dirs(k).name, 'session_manifest.json'), 'file') == 2;
    end
    candidate_dirs = candidate_dirs(keep);
    if isempty(candidate_dirs)
        error('helperResolveSessionAnalysisSetup:noSessions', ...
            'No packaged sessions were found in %s.', dataset_root);
    elseif numel(candidate_dirs) > 1
        names = strjoin(sort({candidate_dirs.name}), ', ');
        error('helperResolveSessionAnalysisSetup:ambiguousSession', ...
            ['Multiple packaged sessions were found in %s.\n' ...
             'Pass a session_id explicitly. Available sessions: %s'], ...
            dataset_root, names);
    end
    session_folder = fullfile(dataset_root, candidate_dirs(1).name);
    manifest_path = fullfile(session_folder, 'session_manifest.json');
end

manifest = helperLoadSessionManifest(manifest_path);

if strlength(string(requested_session)) > 0 && ~strcmp(manifest.session_id, requested_session)
    error('helperResolveSessionAnalysisSetup:sessionMismatch', ...
        'Requested session %s but manifest %s describes session %s.', ...
        requested_session, manifest_path, manifest.session_id);
end

radar_files = helperResolveManifestPaths(session_folder, manifest.radar_files);
adsb_files = helperResolveManifestPaths(session_folder, manifest.adsb_files);
log_files = helperResolveManifestPaths(session_folder, manifest.log_files);

if isempty(radar_files)
    error('helperResolveSessionAnalysisSetup:emptyRadarFiles', ...
        'Session manifest %s does not list any radar files.', manifest_path);
end

missing_radar = radar_files(cellfun(@(p) exist(p, 'file') ~= 2, radar_files));
if ~isempty(missing_radar)
    error('helperResolveSessionAnalysisSetup:missingRadarFiles', ...
        'The packaged session is missing radar file(s):\n  %s', ...
        strjoin(missing_radar, '\n  '));
end

valid_adsb = {};
for k = 1:numel(adsb_files)
    if exist(adsb_files{k}, 'file') ~= 2
        warning('helperResolveSessionAnalysisSetup:missingADSBFile', ...
            'Ignoring missing ADS-B file listed in manifest: %s', adsb_files{k});
        continue
    end

    [~, base_name, ext] = fileparts(adsb_files{k});
    if strcmpi(ext, '.gz')
        [~, base_name] = fileparts(base_name);
    end
    if startsWith(base_name, 'nmea_', 'IgnoreCase', true)
        warning('helperResolveSessionAnalysisSetup:ignoringNMEA', ...
            'Ignoring GPS/NMEA file in ADS-B truth slot: %s', adsb_files{k});
        continue
    end
    valid_adsb{end + 1} = adsb_files{k}; %#ok<AGROW>
end

existing_logs = {};
for k = 1:numel(log_files)
    if exist(log_files{k}, 'file') ~= 2
        warning('helperResolveSessionAnalysisSetup:missingLogFile', ...
            'Ignoring missing log file listed in manifest: %s', log_files{k});
        continue
    end
    existing_logs{end + 1} = log_files{k}; %#ok<AGROW>
end

analysis_setup = struct( ...
    'session_id', manifest.session_id, ...
    'session_folder', string(session_folder), ...
    'manifest_path', string(manifest_path), ...
    'data_folder', string(fileparts(radar_files{1})), ...
    'data_parts', {radar_files(:).'}, ...
    'adsb_files', {valid_adsb(:).'}, ...
    'log_files', {existing_logs(:).'}, ...
    'verbose', logical(opts.Verbose));

[manifest_center_hz, manifest_lo_offset_hz] = localResolveManifestFrequencyMetadata(manifest);
if isfinite(manifest_center_hz)
    analysis_setup.session_manifest_center_frequency_hz = manifest_center_hz;
end
if isfinite(manifest_lo_offset_hz)
    analysis_setup.session_manifest_lo_offset_hz = manifest_lo_offset_hz;
end

if ~isempty(manifest.radar_epoch_utc)
    analysis_setup.radar_epoch_utc = manifest.radar_epoch_utc;
end

if isfield(manifest, 'capture_duration_s')
    analysis_setup.capture_duration_s = manifest.capture_duration_s;
end

if isfield(manifest, 'capture_repetition_spacing_s')
    capture_gap_s = manifest.capture_repetition_spacing_s;
    if ~isnumeric(capture_gap_s)
        capture_gap_s = str2double(string(capture_gap_s));
    end
    if isnumeric(capture_gap_s) && isscalar(capture_gap_s) && isfinite(capture_gap_s) && capture_gap_s >= 0
        analysis_setup.capture_repetition_spacing_s = double(capture_gap_s);
    end
end

end

function [center_hz, lo_offset_hz] = localResolveManifestFrequencyMetadata(manifest)
center_hz = localNestedScalarOrNaN(manifest, {'sdr_defaults', 'center_frequency_hz'});
lo_offset_hz = localNestedScalarOrNaN(manifest, {'sdr_defaults', 'lo_offset_hz'});

if ~isfinite(center_hz)
    center_hz = localNestedScalarOrNaN(manifest, {'header_readback', 'center_frequency_hz'});
end

if ~isfinite(lo_offset_hz)
    lo_offset_hz = localNestedScalarOrNaN(manifest, {'header_readback', 'lo_offset_hz'});
end
end

function value = localNestedScalarOrNaN(data, field_path)
value = NaN;
cursor = data;

for k = 1:numel(field_path)
    field_name = field_path{k};
    if ~isstruct(cursor) || ~isfield(cursor, field_name)
        return
    end
    cursor = cursor.(field_name);
end

if isempty(cursor)
    return
end

if isnumeric(cursor)
    cursor = double(cursor);
    cursor = cursor(1);
else
    cursor = str2double(string(cursor));
end
if isfinite(cursor)
    value = cursor;
end
end

function resolved = helperResolveManifestPaths(session_folder, rel_paths)
% Convert manifest-relative paths into absolute local paths.

resolved = cell(size(rel_paths));
for k = 1:numel(rel_paths)
    candidate = char(string(rel_paths{k}));
    if ispc
        is_absolute = ~isempty(regexp(candidate, '^[A-Za-z]:[\\/]', 'once')) || startsWith(candidate, '\\');
    else
        is_absolute = startsWith(candidate, filesep);
    end

    if is_absolute
        resolved{k} = candidate;
    else
        resolved{k} = fullfile(session_folder, candidate);
    end
end
end
