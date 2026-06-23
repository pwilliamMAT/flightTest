function capture_info = runLocalHDTVCapture(varargin)
%RUNLOCALHDTVCAPTURE Recommended local-only HDTV capture entrypoint.
%  This wrapper keeps the standard N320 HDTV settings in one place so the
%  terminal command stays short and only the commonly tuned parameters need
%  to be overridden from the coordinator script.
%
%  Example:
%    info = runLocalHDTVCapture('Gain', [30 50], ...
%        'CaptureDuration_s', 30, ...
%        'CaptureFile', 'n320_hdtv_capture');

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureDuration_s', 30, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CaptureFile', "n320_hdtv_capture", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 540e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 6.144e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 200e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'Repetitions', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'RepetitionSpacing_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, varargin{:});
opts = p.Results;

capture_args = { ...
    'radio', string(opts.RadioName), ...
    'cf', opts.CenterFrequency_Hz, ...
    'sr', opts.SampleRate_Hz, ...
    'lo', opts.LOOffset_Hz, ...
    'gain', opts.Gain, ...
    'dur', opts.CaptureDuration_s, ...
    'reps', opts.Repetitions, ...
    'repspace', opts.RepetitionSpacing_s, ...
    'file', string(opts.CaptureFile)};

requested_session = string(opts.SessionID);
if strlength(requested_session) > 0
    capture_args = [capture_args, {'session_id', requested_session}];
end

[session_id, written_files] = log_iq_n320_2antennas(capture_args{:});
if strlength(requested_session) > 0 && ~strcmp(char(session_id), char(requested_session))
    error('runLocalHDTVCapture:sessionMismatch', ...
        'Local capture returned session ID %s but %s was requested.', ...
        session_id, requested_session);
end

absolute_files = strings(size(written_files));
for k = 1:numel(written_files)
    absolute_files(k) = string(helperMakeAbsolutePath(written_files(k)));
end

recording_utc = NaN;
header_center_frequency_hz = NaN;
header_lo_offset_hz = NaN;
header_tune_frequency_hz = NaN;
header_sample_rate_hz = NaN;
if ~isempty(absolute_files)
    try
        meta_reader = comm.BasebandFileReader(char(absolute_files(1)), 'SamplesPerFrame', 1);
        header_center_frequency_hz = double(meta_reader.CenterFrequency);
        header_sample_rate_hz = double(meta_reader.SampleRate);
        file_meta = meta_reader.Metadata;
        release(meta_reader);
        if isstruct(file_meta) && isfield(file_meta, 'RecordingUTC') && ~isempty(file_meta.RecordingUTC)
            recording_utc = double(file_meta.RecordingUTC);
        end
        if isstruct(file_meta) && isfield(file_meta, 'LOOffset') && ~isempty(file_meta.LOOffset)
            header_lo_offset_hz = double(file_meta.LOOffset);
        end
        if isfinite(header_center_frequency_hz)
            header_tune_frequency_hz = header_center_frequency_hz + ...
                localFiniteOrZero(header_lo_offset_hz);
        end
    catch me_meta
        warning('runLocalHDTVCapture:recordingTimeUnavailable', ...
            'Could not read RecordingUTC from the first capture file: %s', me_meta.message);
    end
end

capture_info = struct( ...
    'session_id', session_id, ...
    'capture_duration_s', opts.CaptureDuration_s, ...
    'capture_repetitions', opts.Repetitions, ...
    'capture_repetition_spacing_s', opts.RepetitionSpacing_s, ...
    'radar_active_window_s', opts.Repetitions * opts.CaptureDuration_s + ...
        max(opts.Repetitions - 1, 0) * opts.RepetitionSpacing_s, ...
    'radar_recorded_iq_seconds_s', opts.Repetitions * opts.CaptureDuration_s, ...
    'capture_file_base', string(opts.CaptureFile), ...
    'radio_name', string(opts.RadioName), ...
    'center_frequency_hz', opts.CenterFrequency_Hz, ...
    'sample_rate_hz', opts.SampleRate_Hz, ...
    'lo_offset_hz', opts.LOOffset_Hz, ...
    'header_center_frequency_hz', header_center_frequency_hz, ...
    'header_lo_offset_hz', header_lo_offset_hz, ...
    'header_tune_frequency_hz', header_tune_frequency_hz, ...
    'header_sample_rate_hz', header_sample_rate_hz, ...
    'gain', opts.Gain, ...
    'recording_utc', recording_utc, ...
    'local_capture_files', absolute_files);

fprintf('CAPTURE_SESSION_ID=%s\n', session_id);
if isfinite(recording_utc)
    fprintf('CAPTURE_RECORDING_UTC=%.6f\n', recording_utc);
end
if isfinite(header_center_frequency_hz)
    fprintf('CAPTURE_HEADER_CENTER_FREQUENCY_HZ=%.12g\n', header_center_frequency_hz);
end
if isfinite(header_lo_offset_hz)
    fprintf('CAPTURE_HEADER_LO_OFFSET_HZ=%.12g\n', header_lo_offset_hz);
end
if isfinite(header_tune_frequency_hz)
    fprintf('CAPTURE_HEADER_TUNE_FREQUENCY_HZ=%.12g\n', header_tune_frequency_hz);
end
if isfinite(header_sample_rate_hz)
    fprintf('CAPTURE_HEADER_SAMPLE_RATE_HZ=%.12g\n', header_sample_rate_hz);
end
for k = 1:numel(absolute_files)
    fprintf('CAPTURE_FILE_%d=%s\n', k, absolute_files(k));
end

if isfinite(header_center_frequency_hz)
    fprintf(['Header readback: center=%.3f MHz, lo=%.3f MHz, tune=%.3f MHz, ' ...
        'sampleRate=%.3f MSps\n'], ...
        header_center_frequency_hz / 1e6, ...
        localFiniteOrZero(header_lo_offset_hz) / 1e6, ...
        header_tune_frequency_hz / 1e6, ...
        header_sample_rate_hz / 1e6);
end
end

function abs_path = helperMakeAbsolutePath(file_path)
%HELPERMAKEABSOLUTEPATH Convert one capture output path into an absolute path.

file_path = char(string(file_path));
if ispc
    is_absolute = ~isempty(regexp(file_path, '^[A-Za-z]:[\\/]', 'once')) || startsWith(file_path, '\\');
else
    is_absolute = startsWith(file_path, filesep);
end

if is_absolute
    abs_path = file_path;
else
    abs_path = fullfile(pwd, file_path);
end
end

function value = localFiniteOrZero(value_in)
value = 0;
if isfinite(value_in)
    value = value_in;
end
end
