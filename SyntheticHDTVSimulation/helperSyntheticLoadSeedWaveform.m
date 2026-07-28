function [seed_waveform, seed_info] = helperSyntheticLoadSeedWaveform( ...
    scenario_config, n_output_samples, part_start_offset_s)
%HELPERSYNTHETICLOADSEEDWAVEFORM Load one HDTV seed slice for synthesis.
%
% Plain language:
% The generator does not synthesize an ATSC waveform from scratch. Instead,
% it reuses one or more captured illuminator parts from a trusted baseband
% session. This helper resolves the session context, reads the requested
% channel across part boundaries when needed, wraps if approved, adapts the
% sample rate when required, and normalizes the slice to a stable RMS level
% before the channel synthesizer uses it.

validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');
validateattributes(n_output_samples, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'n_output_samples');
validateattributes(part_start_offset_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'part_start_offset_s');

repo_root = fileparts(fileparts(mfilename('fullpath')));
seed_context = localResolveSeedContext(scenario_config, repo_root);
if isempty(seed_context.radar_files)
    error('helperSyntheticLoadSeedWaveform:missingSeedPath', ...
        'seed_source_path is required for seed-backed synthesis.');
end

loop_mode = char(string(scenario_config.seed_loop_mode));
if ~ismember(loop_mode, {'wrap', 'error'})
    error('helperSyntheticLoadSeedWaveform:unsupportedLoopMode', ...
        'seed_loop_mode must be ''wrap'' or ''error''.');
end

[source_num_channels, source_metadata] = localReadSourceMetadata( ...
    seed_context.radar_files{1});
source_sample_rate_hz = double(seed_context.sample_rate_hz);
source_center_frequency_hz = double(seed_context.center_frequency_hz);
source_num_samples_per_file = double(seed_context.radar_file_sample_counts(:));
source_num_samples_total = sum(source_num_samples_per_file, 'omitnan');

if ~(isfinite(source_sample_rate_hz) && source_sample_rate_hz > 0)
    error('helperSyntheticLoadSeedWaveform:missingSeedSampleRate', ...
        'The resolved seed session does not expose a finite sample rate.');
end
if ~(isfinite(source_num_samples_total) && source_num_samples_total > 0)
    error('helperSyntheticLoadSeedWaveform:missingSeedSampleCount', ...
        'The resolved seed session does not expose readable radar sample counts.');
end

seed_channel_index = double(scenario_config.seed_channel_index);
if seed_channel_index > source_num_channels
    error('helperSyntheticLoadSeedWaveform:channelIndexOutOfRange', ...
        ['seed_channel_index=%d exceeds the channel count (%d) in %s. ' ...
         'Use channel 2 for a dual-channel field capture or channel 1 for a one-channel seed clip.'], ...
        seed_channel_index, source_num_channels, seed_context.radar_files{1});
end

source_offset_s = double(scenario_config.seed_start_offset_s) + double(part_start_offset_s);
source_offset_samples = round(source_offset_s * source_sample_rate_hz);
source_needed_samples = max(8, ceil(double(n_output_samples) * source_sample_rate_hz / ...
    double(scenario_config.sample_rate_hz)) + 8);

if ~strcmp(loop_mode, 'wrap') && source_offset_samples + source_needed_samples > source_num_samples_total
    error('helperSyntheticLoadSeedWaveform:seedTooShort', ...
        ['The requested seed interval exceeds the source session length. ' ...
         'Need %d samples after offset %d from %s, but the session only ' ...
         'contains %d samples across %d radar file(s).'], ...
        source_needed_samples, source_offset_samples, ...
        char(string(seed_context.source_spec_path)), ...
        source_num_samples_total, numel(seed_context.radar_files));
end

[source_waveform, read_segments, initial_seed_path] = localReadChannelSamplesFromSession( ...
    seed_context.radar_files, ...
    source_num_samples_per_file, ...
    seed_channel_index, ...
    source_offset_samples, ...
    source_needed_samples, ...
    loop_mode);
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
    'seed_path', initial_seed_path, ...
    'seed_source_path', char(string(seed_context.source_spec_path)), ...
    'seed_session_manifest_path', char(string(seed_context.manifest_path)), ...
    'seed_radar_files', {seed_context.radar_files(:).'}, ...
    'seed_channel_index', seed_channel_index, ...
    'loop_mode', loop_mode, ...
    'source_sample_rate_hz', source_sample_rate_hz, ...
    'source_center_frequency_hz', source_center_frequency_hz, ...
    'source_num_channels', source_num_channels, ...
    'source_num_samples', source_num_samples_total, ...
    'source_num_samples_per_file', source_num_samples_per_file, ...
    'source_offset_s', source_offset_s, ...
    'source_offset_samples', source_offset_samples, ...
    'output_num_samples', double(n_output_samples), ...
    'output_sample_rate_hz', double(scenario_config.sample_rate_hz), ...
    'target_rms', double(scenario_config.seed_target_rms), ...
    'source_metadata', source_metadata, ...
    'read_segments', {read_segments});
end

function seed_context = localResolveSeedContext(scenario_config, repo_root)
if isfield(scenario_config, 'seed_session_context') && ...
        isstruct(scenario_config.seed_session_context) && ...
        isscalar(scenario_config.seed_session_context) && ...
        isfield(scenario_config.seed_session_context, 'radar_files')
    seed_context = scenario_config.seed_session_context;
else
    seed_context = helperSyntheticResolveSessionContext( ...
        scenario_config.seed_source_path, ...
        'RepoRoot', repo_root);
end
end

function [source_num_channels, source_metadata] = localReadSourceMetadata(seed_path)
reader = comm.BasebandFileReader(seed_path, 'SamplesPerFrame', 1);
cleanup_reader = onCleanup(@() release(reader));
source_num_channels = double(reader.NumChannels);
source_metadata = reader.Metadata;
clear cleanup_reader
end

function [channel_samples, read_segments, initial_seed_path] = localReadChannelSamplesFromSession( ...
    radar_files, source_num_samples_per_file, channel_index, offset_samples, ...
    needed_samples, loop_mode)
channel_samples = complex(zeros(needed_samples, 1));
read_segments = repmat(struct( ...
    'file_path', '', ...
    'file_index', 0, ...
    'file_offset_samples', 0, ...
    'samples_read', 0), 0, 1);

total_source_samples = sum(source_num_samples_per_file, 'omitnan');
source_num_samples_per_file = source_num_samples_per_file(:);
radar_files = radar_files(:);

if strcmp(loop_mode, 'wrap')
    current_global_offset = mod(offset_samples, total_source_samples);
else
    current_global_offset = offset_samples;
end

write_index = 1;
initial_seed_path = "";

while write_index <= needed_samples
    [file_index, file_offset_samples] = localLocateFileOffset( ...
        source_num_samples_per_file, ...
        current_global_offset);
    samples_remaining_in_file = source_num_samples_per_file(file_index) - file_offset_samples;
    samples_to_read = min(samples_remaining_in_file, needed_samples - write_index + 1);
    frame_samples = localFrameSamples(samples_to_read);

    file_samples = localReadChannelSamplesFromFile( ...
        radar_files{file_index}, ...
        channel_index, ...
        file_offset_samples, ...
        samples_to_read, ...
        frame_samples);

    if strlength(initial_seed_path) == 0
        initial_seed_path = string(radar_files{file_index});
    end

    channel_samples(write_index : write_index + samples_to_read - 1) = file_samples;
    read_segments(end + 1, 1) = struct( ... %#ok<AGROW>
        'file_path', char(string(radar_files{file_index})), ...
        'file_index', double(file_index), ...
        'file_offset_samples', double(file_offset_samples), ...
        'samples_read', double(samples_to_read));

    write_index = write_index + samples_to_read;
    current_global_offset = current_global_offset + samples_to_read;

    if current_global_offset >= total_source_samples
        if strcmp(loop_mode, 'wrap')
            current_global_offset = mod(current_global_offset, total_source_samples);
        else
            break
        end
    end
end
end

function [file_index, file_offset_samples] = localLocateFileOffset( ...
    source_num_samples_per_file, global_offset_samples)
cumulative_end_samples = cumsum(source_num_samples_per_file);
file_index = find(global_offset_samples < cumulative_end_samples, 1, 'first');
if isempty(file_index)
    file_index = numel(source_num_samples_per_file);
end

if file_index == 1
    file_offset_samples = global_offset_samples;
else
    file_offset_samples = global_offset_samples - cumulative_end_samples(file_index - 1);
end
end

function channel_samples = localReadChannelSamplesFromFile( ...
    seed_path, channel_index, offset_samples, needed_samples, frame_samples)
reader = comm.BasebandFileReader( ...
    seed_path, ...
    'SamplesPerFrame', frame_samples, ...
    'CyclicRepetition', false);
cleanup_reader = onCleanup(@() release(reader));
channel_samples = localReadChannelSamples( ...
    reader, ...
    channel_index, ...
    offset_samples, ...
    needed_samples);
clear cleanup_reader
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
