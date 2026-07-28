function [target_echo_waveform, track_summaries, model_summary] = ...
    helperSyntheticSynthesizeToolboxTargetEchoes( ...
    echo_source_seed, scenario_config, truth_bundle, part_start_offset_s)
%HELPERSYNTHETICSYNTHESIZETOOLBOXTARGETECHOES Build target echoes with native propagation.
%
% Plain language:
% The readiness path now uses a toolbox-native wideband propagation
% analogue instead of hand-rolling the full target-echo delay model. The
% synthetic truth already tells us the bistatic excess range and Doppler,
% so this helper maps that measurement-space truth into a
% `phased.WidebandFreeSpace` channel. The full seed waveform remains the
% source of the target echoes unless the caller explicitly supplied a
% conditioned diagnostic seed.

validateattributes(echo_source_seed, {'single', 'double'}, {'column', 'nonempty'}, mfilename, 'echo_source_seed');
validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');
validateattributes(truth_bundle, {'struct'}, {'scalar'}, mfilename, 'truth_bundle');
validateattributes(part_start_offset_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'part_start_offset_s');

fs = double(scenario_config.sample_rate_hz);
fc = double(scenario_config.center_frequency_hz);
n_samples = numel(echo_source_seed);
sample_times_s = double(part_start_offset_s) + (0 : n_samples - 1).' ./ fs;

block_duration_s = localResolveBlockDuration(scenario_config, n_samples, fs);
block_sample_count = min(n_samples, max(1, round(block_duration_s * fs)));
maximum_distance_m = localResolveMaximumExcessRange(truth_bundle);

propagator = phased.WidebandFreeSpace( ...
    'SampleRate', fs, ...
    'OperatingFrequency', fc, ...
    'MaximumDistanceSource', 'Property', ...
    'MaximumDistance', maximum_distance_m, ...
    'MaximumNumInputSamplesSource', 'Property', ...
    'MaximumNumInputSamples', block_sample_count, ...
    'FractionalDelayMethod', 'FIR');
cleanup_propagator = onCleanup(@() release(propagator));
propagation_latency_samples = double(propagator.OutputSignalLatency);

bistatic_tracks = truth_bundle.bistatic_tracks;
scenario_targets = scenario_config.targets;
n_tracks = numel(bistatic_tracks);
target_echo_waveform = complex(zeros(n_samples, 1, 'single'));
track_summaries = repmat(struct( ...
    'hex', '', ...
    'callsign', '', ...
    'echo_gain_db', NaN, ...
    'echo_gain_policy', '', ...
    'valid_samples', 0, ...
    'delay_samples_range', [NaN, NaN], ...
    'doppler_hz_range', [NaN, NaN], ...
    'range_rate_mps_range', [NaN, NaN], ...
    'propagation_block_count', 0), 1, n_tracks);

for idx = 1 : n_tracks
    track = bistatic_tracks(idx);
    [range_excess_m, range_rate_mps, doppler_hz, valid_mask] = localInterpolateMeasurementTruth( ...
        track, ...
        double(scenario_config.radar_epoch_utc), ...
        sample_times_s, ...
        fc);
    [echo_gain_db, echo_gain_policy] = localResolveEchoGainMetadata( ...
        truth_bundle, ...
        track.hex, ...
        idx, ...
        scenario_targets);

    track_echo = localPropagateTrackEcho( ...
        propagator, ...
        echo_source_seed, ...
        range_excess_m, ...
        range_rate_mps, ...
        valid_mask, ...
        block_sample_count, ...
        propagation_latency_samples);

    if any(valid_mask)
        track_echo = localApplyDelay(track_echo, double(scenario_config.direct_path_delay_samples));
        track_echo = localApplyGain(track_echo, echo_gain_db);
        target_echo_waveform = target_echo_waveform + track_echo;

        track_summaries(idx).delay_samples_range = [ ...
            min(double(scenario_config.direct_path_delay_samples) + ...
                (double(range_excess_m(valid_mask)) ./ physconst('LightSpeed')) .* fs), ...
            max(double(scenario_config.direct_path_delay_samples) + ...
                (double(range_excess_m(valid_mask)) ./ physconst('LightSpeed')) .* fs)];
        track_summaries(idx).doppler_hz_range = [ ...
            min(double(doppler_hz(valid_mask))), ...
            max(double(doppler_hz(valid_mask)))];
        track_summaries(idx).range_rate_mps_range = [ ...
            min(double(range_rate_mps(valid_mask))), ...
            max(double(range_rate_mps(valid_mask)))];
        track_summaries(idx).valid_samples = sum(valid_mask);
        track_summaries(idx).propagation_block_count = ceil(sum(valid_mask) / block_sample_count);
    end

    track_summaries(idx).hex = char(string(track.hex));
    track_summaries(idx).callsign = char(string(track.callsign));
    track_summaries(idx).echo_gain_db = echo_gain_db;
    track_summaries(idx).echo_gain_policy = echo_gain_policy;

    reset(propagator);
end

model_summary = struct( ...
    'echo_generation_model', 'toolbox_wideband_free_space_v1', ...
    'propagation_domain', 'measurement_space_excess_path', ...
    'propagation_block_duration_s', block_duration_s, ...
    'propagation_block_sample_count', double(block_sample_count), ...
    'propagation_latency_samples', propagation_latency_samples, ...
    'fractional_delay_method', 'FIR');
end

function [range_excess_m, range_rate_mps, doppler_hz, valid_mask] = localInterpolateMeasurementTruth( ...
    bistatic_track, radar_epoch_utc, sample_times_s, center_frequency_hz)
t_track_s = double(bistatic_track.t_utc(:)) - radar_epoch_utc;
range_excess_m = interp1(t_track_s, double(bistatic_track.R_excess_m(:)), sample_times_s, 'linear', NaN);
doppler_hz = interp1(t_track_s, double(bistatic_track.f_D_hz(:)), sample_times_s, 'linear', NaN);
range_rate_mps = -(physconst('LightSpeed') ./ center_frequency_hz) .* doppler_hz;

valid_mask = isfinite(range_excess_m) & isfinite(range_rate_mps) & isfinite(doppler_hz) & ...
    (range_excess_m >= 0);
range_excess_m(~valid_mask) = 0;
range_rate_mps(~valid_mask) = 0;
doppler_hz(~valid_mask) = 0;
end

function track_echo = localPropagateTrackEcho( ...
    propagator, echo_source_seed, range_excess_m, range_rate_mps, valid_mask, ...
    block_sample_count, propagation_latency_samples)
n_samples = numel(echo_source_seed);
seed_double = double(echo_source_seed(:));
track_echo_double = complex(zeros(n_samples, 1));
origin_pos = [0; 0; 0];
origin_vel = [0; 0; 0];

for block_start_idx = 1 : block_sample_count : n_samples
    block_end_idx = min(n_samples, block_start_idx + block_sample_count - 1);
    block_indices = block_start_idx : block_end_idx;
    block_seed = seed_double(block_indices);
    block_valid_mask = valid_mask(block_indices);
    if ~any(block_valid_mask)
        continue
    end

    block_range_m = median(range_excess_m(block_indices(block_valid_mask)), 'omitnan');
    block_range_rate_mps = median(range_rate_mps(block_indices(block_valid_mask)), 'omitnan');

    if ~(isfinite(block_range_m) && isfinite(block_range_rate_mps))
        continue
    end

    dest_pos = [block_range_m; 0; 0];
    dest_vel = [block_range_rate_mps; 0; 0];
    propagated_block = propagator(block_seed, origin_pos, dest_pos, origin_vel, dest_vel);
    track_echo_double(block_indices) = propagated_block;
end

track_echo_double(~valid_mask) = 0;
track_echo_double = localNormalizePropagatedEcho(track_echo_double, seed_double, valid_mask);
track_echo_double = localShiftSignalEarlier(track_echo_double, propagation_latency_samples);
track_echo = complex(single(real(track_echo_double)), single(imag(track_echo_double)));
end

function normalized_echo = localNormalizePropagatedEcho(track_echo_double, seed_double, valid_mask)
normalized_echo = track_echo_double;
if ~any(valid_mask)
    return
end

echo_rms = rms(track_echo_double(valid_mask));
seed_rms = rms(seed_double(valid_mask));
if ~(isfinite(echo_rms) && echo_rms > 0 && isfinite(seed_rms) && seed_rms > 0)
    return
end

normalized_echo = track_echo_double .* (seed_rms / echo_rms);
end

function shifted_signal = localShiftSignalEarlier(signal_in, shift_samples)
shift_samples = round(double(shift_samples));
if shift_samples <= 0
    shifted_signal = signal_in;
    return
end

shifted_signal = complex(zeros(size(signal_in)));
if numel(signal_in) > shift_samples
    shifted_signal(1 : end - shift_samples) = signal_in(shift_samples + 1 : end);
end
end

function block_duration_s = localResolveBlockDuration(scenario_config, n_samples, sample_rate_hz)
block_duration_s = double(scenario_config.propagation_block_duration_s);
block_duration_s = max(block_duration_s, 1 / sample_rate_hz);
block_duration_s = min(block_duration_s, n_samples / sample_rate_hz);
end

function maximum_distance_m = localResolveMaximumExcessRange(truth_bundle)
all_ranges_m = zeros(0, 1);
for idx = 1 : numel(truth_bundle.bistatic_tracks)
    all_ranges_m = [all_ranges_m; double(truth_bundle.bistatic_tracks(idx).R_excess_m(:))]; %#ok<AGROW>
end

all_ranges_m = all_ranges_m(isfinite(all_ranges_m) & all_ranges_m >= 0);
if isempty(all_ranges_m)
    maximum_distance_m = 1e3;
else
    maximum_distance_m = max(all_ranges_m) + 1e3;
end
end

function shifted_signal = localApplyDelay(signal_in, delay_samples)
vfd = dsp.VariableFractionalDelay;
cleanup_vfd = onCleanup(@() release(vfd));
delay_value = cast(delay_samples, 'like', real(signal_in(1)));
shifted_signal = vfd(signal_in, delay_value);
end

function signal_out = localApplyGain(signal_in, gain_db)
signal_out = signal_in .* single(10 .^ (gain_db / 20));
end

function [echo_gain_db, echo_gain_policy] = localResolveEchoGainMetadata( ...
    truth_bundle, track_hex, track_index, scenario_targets)
echo_gain_db = NaN;
echo_gain_policy = 'truth_bundle_track_metadata_v1';

if isfield(truth_bundle, 'track_metadata') && ...
        numel(truth_bundle.track_metadata) >= track_index
    track_metadata = truth_bundle.track_metadata(track_index);
    if isfield(track_metadata, 'echo_gain_db') && ...
            ~isempty(track_metadata.echo_gain_db)
        echo_gain_db = double(track_metadata.echo_gain_db);
    end
    if isfield(track_metadata, 'echo_gain_policy') && ...
            strlength(string(track_metadata.echo_gain_policy)) > 0
        echo_gain_policy = char(string(track_metadata.echo_gain_policy));
    end
end

if isfinite(echo_gain_db)
    return
end

echo_gain_policy = 'scenario_target_gain_v1';
echo_gain_db = -25;
for idx = 1 : numel(scenario_targets)
    if strcmpi(char(string(scenario_targets(idx).icao_hex)), char(string(track_hex)))
        echo_gain_db = double(scenario_targets(idx).echo_gain_db);
        return
    end
end

echo_gain_policy = 'default_gain_v1';
end
