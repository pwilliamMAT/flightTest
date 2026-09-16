function [adsb_tracks, import_info] = loadADSBRemoterArchive(source, varargin)
%LOADADSBREMOTERARCHIVE Load archived ADSB-remoter SBS trajectory truth.
%
%   tracks = loadADSBRemoterArchive(source)
%   [tracks, info] = loadADSBRemoterArchive(source, 'Verbose', false)
%
%   SOURCE may be a CSV/TXT file, a gzip-compressed CSV/TXT file, a folder,
%   or a collection of those paths. Folder discovery is recursive and only
%   selects filenames containing "adsb".
%
%   ADSB-remoter stores standard SBS/BaseStation records. Some archived
%   files repeat the generated time in both field 7 and field 8, leaving a
%   complete date-time in field 7. This adapter normalizes that layout in a
%   temporary file. It then delegates SBS parsing, unit conversion, record
%   grouping, and velocity interpolation to loadADSBTruth.
%
%   The result is the existing canonical trajectory struct with fields:
%   hex, callsign, t_utc, lat_deg, lon_deg, alt_m, speed_mps, track_deg,
%   and vrate_mps. No objectDetection objects are created.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source');
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, source, varargin{:});
opts = p.Results;

source_files = localResolveSourceFiles(source);
temporary_root = string(tempname) + "_adsb_remoter";
mkdir(temporary_root);
temporary_cleanup = onCleanup(@() localRemoveTemporaryFolder(temporary_root));

normalized_files = strings(numel(source_files), 1);
normalized_timestamp_lines = zeros(numel(source_files), 1);

for file_idx = 1:numel(source_files)
    source_folder = fullfile(temporary_root, sprintf('source_%04d', file_idx));
    mkdir(source_folder);
    expanded_file = localExpandSourceFile(source_files(file_idx), source_folder);
    normalized_files(file_idx) = fullfile( ...
        temporary_root, sprintf('normalized_%04d.txt', file_idx));
    normalized_timestamp_lines(file_idx) = localNormalizeTimestampLayout( ...
        expanded_file, normalized_files(file_idx));
end

% loadADSBTruth remains the single parser and unit-conversion authority.
adsb_tracks = loadADSBTruth(cellstr(normalized_files), ...
    'Verbose', opts.Verbose);

import_info = struct( ...
    'source_id', ...
        "ADSB-remoter@63ff6688628c2813e4287c5ecdc0df67883c3f93", ...
    'parser', "loadADSBTruth", ...
    'source_files', source_files, ...
    'source_file_count', numel(source_files), ...
    'normalized_timestamp_line_count', sum(normalized_timestamp_lines), ...
    'track_count', numel(adsb_tracks), ...
    'position_fix_count', sum(arrayfun( ...
        @(track) numel(track.t_utc), adsb_tracks)));

clear temporary_cleanup

end

function source_files = localResolveSourceFiles(source)
if ischar(source)
    source_paths = string({source});
elseif isstring(source)
    source_paths = source(:);
elseif iscell(source)
    source_paths = string(source(:));
else
    error('loadADSBRemoterArchive:badSource', ...
        'source must be text or a cell array of text paths.');
end

if isempty(source_paths) || any(ismissing(source_paths)) || ...
        any(strlength(strtrim(source_paths)) == 0)
    error('loadADSBRemoterArchive:badSource', ...
        'At least one nonempty source path is required.');
end

source_files = strings(0, 1);
for path_idx = 1:numel(source_paths)
    current_path = source_paths(path_idx);
    if isfile(current_path)
        if ~localIsSupportedFile(current_path)
            error('loadADSBRemoterArchive:unsupportedFile', ...
                'Unsupported archive file: %s', current_path);
        end
        source_files(end + 1, 1) = current_path; %#ok<AGROW>
    elseif isfolder(current_path)
        listing = dir(fullfile(current_path, '**', '*'));
        listing = listing(~[listing.isdir]);
        if isempty(listing)
            continue
        end
        discovered = string(fullfile({listing.folder}, {listing.name})).';
        is_adsb = contains(lower(discovered), "adsb");
        is_supported = localIsSupportedFile(discovered);
        source_files = [source_files; discovered(is_adsb & is_supported)]; %#ok<AGROW>
    else
        error('loadADSBRemoterArchive:sourceNotFound', ...
            'Archive source does not exist: %s', current_path);
    end
end

source_files = unique(sort(source_files), 'stable');
if isempty(source_files)
    error('loadADSBRemoterArchive:noArchiveFiles', ...
        'No ADS-B CSV/TXT archive files were found.');
end
end

function tf = localIsSupportedFile(file_path)
path_lower = lower(string(file_path));
tf = endsWith(path_lower, ".csv") | ...
    endsWith(path_lower, ".txt") | ...
    endsWith(path_lower, ".csv.gz") | ...
    endsWith(path_lower, ".txt.gz");
end

function expanded_file = localExpandSourceFile(source_file, output_folder)
if endsWith(lower(source_file), ".gz")
    try
        expanded = gunzip(source_file, output_folder);
    catch cause
        failure = MException( ...
            'loadADSBRemoterArchive:invalidGzipArchive', ...
            ['Could not decompress ADS-B archive %s. The file may be ' ...
             'truncated or corrupt; preserve the original and reacquire or ' ...
             'restore a complete copy before using it as truth.'], ...
            source_file);
        failure = addCause(failure, cause);
        throwAsCaller(failure);
    end
    if numel(expanded) ~= 1
        error('loadADSBRemoterArchive:unexpectedGzipContents', ...
            'Expected one file in archive %s.', source_file);
    end
    expanded_file = string(expanded{1});
else
    expanded_file = source_file;
end
end

function normalized_count = localNormalizeTimestampLayout(input_file, output_file)
input_id = fopen(input_file, 'r');
if input_id < 0
    error('loadADSBRemoterArchive:openFailed', ...
        'Could not open archive input %s.', input_file);
end
input_cleanup = onCleanup(@() fclose(input_id));

output_id = fopen(output_file, 'w');
if output_id < 0
    error('loadADSBRemoterArchive:openFailed', ...
        'Could not create temporary normalized input %s.', output_file);
end
output_cleanup = onCleanup(@() fclose(output_id));

normalized_count = 0;
while true
    line_text = fgetl(input_id);
    if ~ischar(line_text)
        break
    end

    fields = strsplit(line_text, ',', 'CollapseDelimiters', false);
    line_changed = false;
    if numel(fields) >= 10
        [fields, generated_changed] = localNormalizeDatePair(fields, 7, 8);
        [fields, logged_changed] = localNormalizeDatePair(fields, 9, 10);
        line_changed = generated_changed || logged_changed;
    end

    if line_changed
        normalized_count = normalized_count + 1;
        line_text = strjoin(fields, ',');
    end
    fprintf(output_id, '%s\n', line_text);
end

clear output_cleanup
clear input_cleanup
end

function [fields, changed] = localNormalizeDatePair( ...
        fields, date_field_idx, time_field_idx)
changed = false;
date_text = strtrim(fields{date_field_idx});
tokens = regexp(date_text, ...
    '^(\d{4})[-/](\d{2})[-/](\d{2})(?:[ T](\d{2}:\d{2}:\d{2}(?:\.\d+)?))?$', ...
    'tokens', 'once');
if isempty(tokens)
    return
end

normalized_date = sprintf('%s/%s/%s', tokens{1}, tokens{2}, tokens{3});
if ~strcmp(fields{date_field_idx}, normalized_date)
    fields{date_field_idx} = normalized_date;
    changed = true;
end

if isempty(strtrim(fields{time_field_idx})) && numel(tokens) >= 4 && ...
        ~isempty(tokens{4})
    fields{time_field_idx} = tokens{4};
    changed = true;
end
end

function localRemoveTemporaryFolder(folder_path)
if isfolder(folder_path)
    rmdir(folder_path, 's');
end
end
