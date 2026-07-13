function [seed_waveform, seed_info] = helperSyntheticLoadSeedWaveform(scenario_config, n_output_samples, part_start_offset_s)
%HELPERSYNTHETICLOADSEEDWAVEFORM Load one HDTV seed slice for synthesis.
%
% Plain language:
% The generator does not synthesize an ATSC waveform from scratch. Instead,
% it reuses a captured illuminator slice from a trusted baseband file. This
% helper reads the requested channel, skips to the requested time offset,
% wraps if approved, adapts the sample rate when needed, and normalizes the
% slice to a stable RMS level before the channel synthesizer uses it.

validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');
validateattributes(n_output_samples, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'n_output_samples');
validateattributes(part_start_offset_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'part_start_offset_s');

seed_path = char(string(scenario_config.seed_source_path));
if strlength(string(seed_path)) == 0
    error('helperSyntheticLoadSeedWaveform:missingSeedPath', ...
        'seed_source_path is required for seed-backed synthesis.');
end
if exist(seed_path, 'file') ~= 2
    error('helperSyntheticLoadSeedWaveform:missingSeedFile', ...
        'Seed baseband file not found: %s', seed_path);
end

loop_mode = char(string(scenario_config.seed_loop_mode));
if ~ismember(loop_mode, {'wrap', 'error'})
    error('helperSyntheticLoadSeedWaveform:unsupportedLoopMode', ...
        'seed_loop_mode must be ''wrap'' or ''error''.');
end

frame_samples = localFrameSamples(n_output_samples);
reader = comm.BasebandFileReader( ...
    seed_path, ...
    'SamplesPerFrame', frame_samples, ...
    'CyclicRepetition', strcmp(loop_mode, 'wrap'));
cleanup_reader = onCleanup(@() release(reader)); %#ok<NASGU>

source_summary = info(reader);
source_sample_rate_hz = double(reader.SampleRate);
source_center_frequency_hz = double(reader.CenterFrequency);
source_num_channels = double(reader.NumChannels);
source_num_samples = double(source_summary.NumSamplesInData);
source_metadata = reader.Metadata;

seed_channel_index = double(scenario_config.seed_channel_index);
if seed_channel_index > source_num_channels
    error('helperSyntheticLoadSeedWaveform:channelIndexOutOfRange', ...
        ['seed_channel_index=%d exceeds the channel count (%d) in %s. ' ...
         'Use channel 2 for a dual-channel field capture or channel 1 for a one-channel seed clip.'], ...
        seed_channel_index, source_num_channels, seed_path);
end

source_offset_s = double(scenario_config.seed_start_offset_s) + double(part_start_offset_s);
source_offset_samples = round(source_offset_s * source_sample_rate_hz);
source_needed_samples = max(8, ceil(double(n_output_samples) * source_sample_rate_hz / ...
    double(scenario_config.sample_rate_hz)) + 8);

if ~strcmp(loop_mode, 'wrap') && source_offset_samples + source_needed_samples > source_num_samples
    error('helperSyntheticLoadSeedWaveform:seedTooShort', ...
        ['The requested seed interval exceeds the source file length. ' ...
         'Need %d samples after offset %d from %s, but the file only contains %d samples.'], ...
        source_needed_samples, source_offset_samples, seed_path, source_num_samples);
end

source_waveform = localReadChannelSamples( ...
    reader, seed_channel_index, source_offset_samples, source_needed_samples);
source_waveform = double(source_waveform(:));

if abs(source_sample_rate_hz - double(scenario_config.sample_rate_hz)) > 1e-9
    [p_factor, q_factor] = rat( ...
        double(scenario_config.sample_rate_hz) / source_sample_rate_hz, 1e-12);
    source_waveform = resample(source_waveform, p_factor, q_factor);
end

if numel(source_waveform) < n_output_samples
    if strcmp(loop_mode, 'wrap')
        source_waveform = localWrapSamples(source_waveform, n_output_samples);
    else
        error('helperSyntheticLoadSeedWaveform:resampleShortfall', ...
            'Seed readback produced %d samples after resampling, but %d are required.', ...
            numel(source_waveform), n_output_samples);
    end
end

seed_waveform = source_waveform(1:n_output_samples);
seed_waveform = localNormalizeRMS(seed_waveform, double(scenario_config.seed_target_rms));
seed_waveform = complex(single(real(seed_waveform)), single(imag(seed_waveform)));

seed_info = struct( ...
    'seed_path', seed_path, ...
    'seed_channel_index', seed_channel_index, ...
    'loop_mode', loop_mode, ...
    'source_sample_rate_hz', source_sample_rate_hz, ...
    'source_center_frequency_hz', source_center_frequency_hz, ...
    'source_num_channels', source_num_channels, ...
    'source_num_samples', source_num_samples, ...
    'source_offset_s', source_offset_s, ...
    'source_offset_samples', source_offset_samples, ...
    'output_num_samples', double(n_output_samples), ...
    'output_sample_rate_hz', double(scenario_config.sample_rate_hz), ...
    'target_rms', double(scenario_config.seed_target_rms), ...
    'source_metadata', source_metadata);
end

function frame_samples = localFrameSamples(n_output_samples)
frame_samples = min(max(double(n_output_samples), 4096), 262144);
frame_samples = round(frame_samples);
end

function channel_samples = localReadChannelSamples(reader, channel_index, offset_samples, needed_samples)
channel_samples = complex(zeros(needed_samples, 1));
remaining_offset = double(offset_samples);
write_index = 1;

while remaining_offset > 0
    frame = reader();
    frame_length = size(frame, 1);
    if remaining_offset >= frame_length
        remaining_offset = remaining_offset - frame_length;
        continue
    end

    frame = frame(remaining_offset + 1 : end, channel_index);
    remaining_offset = 0;
    n_copy = min(numel(frame), needed_samples - write_index + 1);
    channel_samples(write_index : write_index + n_copy - 1) = frame(1:n_copy);
    write_index = write_index + n_copy;
end

while write_index <= needed_samples
    frame = reader();
    frame = frame(:, channel_index);
    n_copy = min(numel(frame), needed_samples - write_index + 1);
    channel_samples(write_index : write_index + n_copy - 1) = frame(1:n_copy);
    write_index = write_index + n_copy;
end
end

function waveform = localWrapSamples(waveform_in, target_length)
repetitions = ceil(target_length / max(numel(waveform_in), 1));
waveform = repmat(waveform_in(:), repetitions, 1);
waveform = waveform(1:target_length);
end

function waveform = localNormalizeRMS(waveform_in, target_rms)
measured_rms = rms(waveform_in);
if measured_rms <= 0 || ~isfinite(measured_rms)
    error('helperSyntheticLoadSeedWaveform:degenerateSeed', ...
        'The selected seed slice has zero or non-finite RMS and cannot drive synthesis.');
end

waveform = waveform_in .* (target_rms / measured_rms);
end
