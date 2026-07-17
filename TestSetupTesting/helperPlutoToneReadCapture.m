function [reference_signal, surveillance_signal, capture_info_out] = helperPlutoToneReadCapture(capture_info_in, varargin)
%HELPERPLUTOTONEREADCAPTURE Read one captured .bb file through the proven loadIQData path.
%
% Plain-language goal:
%   The precheck needs the same channel interpretation used by the rest of
%   the project, so this helper reads the first N320 capture file with the
%   proven BistaticDataAnalysis/loadIQData.m path and then packages the
%   readback metadata into the frozen result schema.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'capture_info_in', @isstruct);
addParameter(p, 'ExpectedSampleRateHz', NaN, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CaptureDurationSeconds', NaN, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, capture_info_in, varargin{:});
opts = p.Results;

capture_file_path = localResolveCaptureFilePath(capture_info_in);
if strlength(capture_file_path) == 0 || exist(char(capture_file_path), 'file') ~= 2
    error('helperPlutoToneReadCapture:captureFileMissing', ...
        'The capture file is missing or unreadable: %s', char(capture_file_path));
end

sample_rate_hz = localResolveSampleRate(capture_info_in, opts.ExpectedSampleRateHz);
capture_duration_s = localResolveDuration(capture_info_in, opts.CaptureDurationSeconds);
num_samples_requested = max(1, ceil(sample_rate_hz * capture_duration_s * 1.05));
cpi_duration_s = min(capture_duration_s, max(1024 / sample_rate_hz, 0.01));

try
    reader = comm.BasebandFileReader(char(capture_file_path), 'SamplesPerFrame', 1);
    metadata = reader.Metadata;
    release(reader);
catch me_meta
    error('helperPlutoToneReadCapture:metadataReadFailed', ...
        'Could not read .bb metadata from %s: %s', char(capture_file_path), me_meta.message);
end

analysis_root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'BistaticDataAnalysis');
path_added = false;
if isempty(which('loadIQData'))
    addpath(analysis_root);
    path_added = true;
end

if isempty(which('loadIQData'))
    if path_added
        rmpath(analysis_root);
    end
    error('helperPlutoToneReadCapture:loadIQDataUnavailable', ...
        'BistaticDataAnalysis/loadIQData.m is not available on the MATLAB path.');
end

read_options = struct('swap_channels', false, 'verbose', opts.Verbose);
try
    [reference_signal, surveillance_signal] = loadIQData( ...
        char(capture_file_path), ...
        num_samples_requested, ...
        cpi_duration_s, ...
        sample_rate_hz, ...
        read_options);
catch me_read
    if path_added
        rmpath(analysis_root);
    end
    error('helperPlutoToneReadCapture:readFailed', ...
        'Could not read the captured .bb file %s: %s', char(capture_file_path), me_read.message);
end
if path_added
    rmpath(analysis_root);
end

reference_signal = double(reference_signal(:));
surveillance_signal = double(surveillance_signal(:));
samples_per_channel = min(numel(reference_signal), numel(surveillance_signal));
if samples_per_channel < 1024
    error('helperPlutoToneReadCapture:tooFewSamples', ...
        'Only %d complex samples were available per channel.', samples_per_channel);
end

reference_signal = reference_signal(1:samples_per_channel);
surveillance_signal = surveillance_signal(1:samples_per_channel);

capture_info_out = struct( ...
    'capture_session_id', char(string(localFieldOrDefault(capture_info_in, 'session_id', ""))), ...
    'capture_file_path', char(capture_file_path), ...
    'local_capture_files', string(localFieldOrDefault(capture_info_in, 'local_capture_files', strings(0, 1))), ...
    'recording_utc', localFiniteOrNaN(localFieldOrDefault(capture_info_in, 'recording_utc', NaN)), ...
    'header_center_frequency_hz', localFiniteOrNaN(localFieldOrDefault(capture_info_in, 'header_center_frequency_hz', NaN)), ...
    'header_lo_offset_hz', localFiniteOrNaN(localFieldOrDefault(capture_info_in, 'header_lo_offset_hz', NaN)), ...
    'header_tune_frequency_hz', localFiniteOrNaN(localFieldOrDefault(capture_info_in, 'header_tune_frequency_hz', NaN)), ...
    'header_sample_rate_hz', localFiniteOrNaN(localFieldOrDefault(capture_info_in, 'header_sample_rate_hz', sample_rate_hz)), ...
    'samples_per_channel', double(samples_per_channel), ...
    'samples_scored', double(samples_per_channel), ...
    'slice_duration_s', double(samples_per_channel / sample_rate_hz), ...
    'reader_metadata', metadata);

if opts.Verbose
    fprintf('[helperPlutoToneReadCapture] File .......... %s\n', char(capture_file_path));
    fprintf('[helperPlutoToneReadCapture] Samples/ch ..... %d\n', samples_per_channel);
    fprintf('[helperPlutoToneReadCapture] Slice .......... %.6f s\n', ...
        samples_per_channel / sample_rate_hz);
end
end

function capture_file_path = localResolveCaptureFilePath(capture_info_in)
capture_file_path = "";
if isfield(capture_info_in, 'local_capture_files') && ~isempty(capture_info_in.local_capture_files)
    capture_file_path = string(capture_info_in.local_capture_files(1));
elseif isfield(capture_info_in, 'capture_file_path') && ...
        strlength(string(capture_info_in.capture_file_path)) > 0
    capture_file_path = string(capture_info_in.capture_file_path);
end
end

function sample_rate_hz = localResolveSampleRate(capture_info_in, expected_sample_rate_hz)
sample_rate_hz = expected_sample_rate_hz;
if ~isfinite(sample_rate_hz) && isfield(capture_info_in, 'header_sample_rate_hz')
    sample_rate_hz = double(capture_info_in.header_sample_rate_hz);
end
if ~isfinite(sample_rate_hz) && isfield(capture_info_in, 'sample_rate_hz')
    sample_rate_hz = double(capture_info_in.sample_rate_hz);
end
if ~(isscalar(sample_rate_hz) && isfinite(sample_rate_hz) && sample_rate_hz > 0)
    error('helperPlutoToneReadCapture:sampleRateUnavailable', ...
        'A valid sample rate is required to read the capture file.');
end
end

function capture_duration_s = localResolveDuration(capture_info_in, requested_duration_s)
capture_duration_s = requested_duration_s;
if ~isfinite(capture_duration_s) && isfield(capture_info_in, 'capture_duration_s')
    capture_duration_s = double(capture_info_in.capture_duration_s);
end
if ~(isscalar(capture_duration_s) && isfinite(capture_duration_s) && capture_duration_s > 0)
    error('helperPlutoToneReadCapture:captureDurationUnavailable', ...
        'A valid capture duration is required to estimate the sample count.');
end
end

function value = localFieldOrDefault(source_struct, field_name, default_value)
value = default_value;
if isstruct(source_struct) && isfield(source_struct, field_name)
    value = source_struct.(field_name);
end
end

function value = localFiniteOrNaN(value_in)
value = NaN;
numeric_value = double(value_in);
if isscalar(numeric_value) && isfinite(numeric_value)
    value = numeric_value;
end
end
