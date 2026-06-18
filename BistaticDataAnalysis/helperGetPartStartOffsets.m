function [part_start_offsets_s, timing_info] = helperGetPartStartOffsets(data_parts, part_dur_s, fallback_gap_s, varargin)
%HELPERGETPARTSTARTOFFSETS  Derive multi-part start offsets from metadata.
%
%  [part_start_offsets_s, timing_info] = helperGetPartStartOffsets( ...
%      data_parts, part_dur_s, fallback_gap_s)
%
%  Offsets are relative to part 1 start and are expressed in seconds.
%  When metadata is unavailable, the helper falls back to a fixed
%  start-to-start spacing of part_dur_s + fallback_gap_s.
%  Set 'TimingSource' to:
%    'auto'     - use metadata when available, else fallback gap
%    'metadata' - prefer metadata, but still fallback if metadata is absent
%    'fallback' - ignore metadata and use the fixed fallback spacing

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'data_parts');
addRequired(p, 'part_dur_s', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'fallback_gap_s', @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'StartDateTimes', [], @(x) isempty(x) || isdatetime(x) || isnumeric(x) || iscell(x));
addParameter(p, 'TimingSource', 'auto', @(x) any(strcmpi(string(x), ["auto", "metadata", "fallback"])));
parse(p, data_parts, part_dur_s, fallback_gap_s, varargin{:});
opts = p.Results;

data_parts = normalize_paths(data_parts);
N_parts    = numel(data_parts);
timing_source = lower(char(string(opts.TimingSource)));

part_start_offsets_s = (0 : N_parts - 1).' * (part_dur_s + fallback_gap_s);
timing_info = struct();
timing_info.source          = 'fallback_gap';
timing_info.start_datetimes = NaT(N_parts, 1);
timing_info.used_metadata   = false(N_parts, 1);
timing_info.metadata_source = repmat({''}, N_parts, 1);
timing_info.requested_source = timing_source;

if N_parts <= 1
    if N_parts == 1
        timing_info.start_datetimes(1) = NaT;
    end
    return
end

if strcmp(timing_source, 'fallback')
    timing_info.source = 'forced_fallback_gap';
    timing_info.metadata_source(:) = {'forced_fallback_gap'};
    if opts.Verbose
        fprintf('[helperGetPartStartOffsets] Timing source forced to fallback gap %.3f s.\n', ...
            part_dur_s + fallback_gap_s);
    end
    return
end

start_datetimes = resolve_start_datetimes(data_parts, opts.StartDateTimes);
timing_info.start_datetimes = start_datetimes;

if isnat(start_datetimes(1))
    if opts.Verbose
        fprintf('[helperGetPartStartOffsets] Part-1 metadata unavailable; using fallback start spacing %.3f s.\n', ...
            part_dur_s + fallback_gap_s);
    end
    return
end

timing_info.used_metadata(1) = true;
timing_info.metadata_source{1} = 'part1';
part_start_offsets_s(1) = 0;

used_any_metadata = false;

for ip = 2 : N_parts
    if ~isnat(start_datetimes(ip))
        offset_s = seconds(start_datetimes(ip) - start_datetimes(1));
        if isfinite(offset_s) && offset_s > part_start_offsets_s(max(ip - 1, 1)) - 1e-9
            part_start_offsets_s(ip) = offset_s;
            timing_info.used_metadata(ip) = true;
            timing_info.metadata_source{ip} = 'header';
            used_any_metadata = true;
            continue
        end
    end

    part_start_offsets_s(ip) = part_start_offsets_s(ip - 1) + part_dur_s + fallback_gap_s;
    timing_info.metadata_source{ip} = 'fallback_gap';
end

if all(timing_info.used_metadata)
    timing_info.source = 'file_metadata';
elseif used_any_metadata
    timing_info.source = 'mixed';
end

if opts.Verbose
    fprintf('[helperGetPartStartOffsets] Timing source: %s\n', timing_info.source);
    for ip = 1 : N_parts
        fprintf('  Part %d start offset: %.3f s (%s)\n', ...
            ip, part_start_offsets_s(ip), timing_info.metadata_source{ip});
    end
end

end

function data_parts = normalize_paths(data_parts)
if ischar(data_parts) || isstring(data_parts)
    data_parts = {char(data_parts)};
elseif iscell(data_parts)
    data_parts = cellfun(@char, data_parts, 'UniformOutput', false);
else
    error('helperGetPartStartOffsets:badInput', ...
        'data_parts must be a string, char array, or cell array of paths.');
end
end

function start_datetimes = resolve_start_datetimes(data_parts, provided_start_times)
N_parts = numel(data_parts);
start_datetimes = NaT(N_parts, 1);

if ~isempty(provided_start_times)
    if isdatetime(provided_start_times)
        start_datetimes = reshape(local_to_naive_datetime(provided_start_times(:)), [], 1);
    elseif isnumeric(provided_start_times)
        start_datetimes = datetime(provided_start_times(:), 'ConvertFrom', 'posixtime', ...
            'TimeZone', 'UTC');
        start_datetimes = local_to_naive_datetime(start_datetimes);
    elseif iscell(provided_start_times)
        if numel(provided_start_times) ~= N_parts
            error('helperGetPartStartOffsets:badStartDateTimes', ...
                'StartDateTimes cell array must match the number of parts.');
        end
        for ip = 1 : N_parts
            start_datetimes(ip) = parse_metadata_datetime(provided_start_times{ip});
        end
    else
        error('helperGetPartStartOffsets:badStartDateTimes', ...
            'Unsupported StartDateTimes input.');
    end

    if numel(start_datetimes) ~= N_parts
        error('helperGetPartStartOffsets:badStartDateTimes', ...
            'StartDateTimes must contain one entry per part.');
    end
    return
end

for ip = 1 : N_parts
    start_datetimes(ip) = read_part_start_datetime(data_parts{ip});
end
end

function dt = read_part_start_datetime(data_file_path)
dt = NaT;

[info_struct, metadata_struct] = read_baseband_header(data_file_path);
if isempty(fieldnames(info_struct)) && isempty(fieldnames(metadata_struct))
    return
end

candidate_values = {};
candidate_values = append_candidate_fields(candidate_values, info_struct);
if isfield(info_struct, 'Metadata') && isstruct(info_struct.Metadata)
    candidate_values = append_candidate_fields(candidate_values, info_struct.Metadata);
end
candidate_values = append_candidate_fields(candidate_values, metadata_struct);

for k = 1 : numel(candidate_values)
    dt = parse_metadata_datetime(candidate_values{k});
    if ~isnat(dt)
        return
    end
end

function [info_struct, metadata_struct] = read_baseband_header(data_file_path)
info_struct = struct();
metadata_struct = struct();

try
    reader = comm.BasebandFileReader(data_file_path, 'SamplesPerFrame', 1);
    cleanup = onCleanup(@() localReleaseReader(reader)); %#ok<NASGU>
    info_struct = info(reader);
    metadata_struct = localReadMetadataStruct(reader);
    return
catch
end

try
    reader = BasebandFileReader(data_file_path);
    cleanup = onCleanup(@() localReleaseReader(reader)); %#ok<NASGU>
    info_struct = info(reader);
    metadata_struct = localReadMetadataStruct(reader);
catch
    info_struct = struct();
    metadata_struct = struct();
end
end

function metadata_struct = localReadMetadataStruct(reader)
metadata_struct = struct();

if ~isprop(reader, 'Metadata')
    return
end

raw_metadata = reader.Metadata;
if isstruct(raw_metadata)
    metadata_struct = raw_metadata;
end
end

function localReleaseReader(reader)
try
    release(reader);
catch
end
end
end

function candidate_values = append_candidate_fields(candidate_values, source_struct)
candidate_fields = {'RecordingUTC', 'RecordingTime', 'Timestamp', ...
                    'StartTime', 'CaptureTime', 'DateTime'};
for k = 1 : numel(candidate_fields)
    fld = candidate_fields{k};
    if isfield(source_struct, fld) && ~isempty(source_struct.(fld))
        candidate_values{end + 1} = source_struct.(fld); %#ok<AGROW>
    end
end
end

function dt = parse_metadata_datetime(value)
dt = NaT;

if isempty(value)
    return
end

if isdatetime(value) && isscalar(value)
    dt = local_to_naive_datetime(value);
    return
end

if isnumeric(value) && isscalar(value) && isfinite(value)
    dt = datetime(double(value), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    dt = local_to_naive_datetime(dt);
    return
end

if isstring(value) && isscalar(value)
    value = char(value);
end

if ischar(value)
    input_formats = { ...
        'yyyy-MM-dd_HH-mm-ss.SSS', ...
        'yyyy-MM-dd_HH-mm-ss', ...
        'yyyy-MM-dd HH:mm:ss.SSS', ...
        'yyyy-MM-dd HH:mm:ss', ...
        'yyyy/MM/dd HH:mm:ss.SSS', ...
        'yyyy/MM/dd HH:mm:ss', ...
        'yyyy-MM-dd''T''HH:mm:ss.SSS', ...
        'yyyy-MM-dd''T''HH:mm:ss'};

    for k = 1 : numel(input_formats)
        try
            dt = datetime(strtrim(value), 'InputFormat', input_formats{k});
            return
        catch
        end
    end
end
end

function dt = local_to_naive_datetime(dt)
if isempty(dt)
    return
end

if ~isempty(dt.TimeZone)
    dt.TimeZone = 'UTC';
    dt.TimeZone = '';
end
end
