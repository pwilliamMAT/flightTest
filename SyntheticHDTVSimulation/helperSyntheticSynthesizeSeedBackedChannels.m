function [surveillance_channel, reference_channel, synthesis_summary] = helperSyntheticSynthesizeSeedBackedChannels( ...
    seed_waveform, scenario_config, truth_bundle, part_idx, part_start_offset_s)
%HELPERSYNTHETICSYNTHESIZESEEDBACKEDCHANNELS Build one surveillance/reference pair.
%
% Plain language:
% The seed waveform is treated as the illuminator-of-opportunity snapshot.
% CH2 (reference) is a scaled copy of that seed. CH1 (surveillance) starts
% with a direct-path copy of the same seed and then adds one echo per
% synthetic target using the approved bistatic truth. The reference and
% direct-path channels keep the full seed so the illuminator remains
% realistic, while the target echoes use a lightly conditioned copy of the
% seed so a dominant pilot-like line does not replay into full-height
% Doppler columns. The truth still sets the excess delay and the bistatic
% Doppler, so the signal synthesis and the truth artifacts stay tied to the
% same scenario definition.

validateattributes(seed_waveform, {'single', 'double'}, {'column', 'nonempty'}, mfilename, 'seed_waveform');
validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');
validateattributes(truth_bundle, {'struct'}, {'scalar'}, mfilename, 'truth_bundle');
validateattributes(part_idx, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'part_idx');
validateattributes(part_start_offset_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'part_start_offset_s');

fs = double(scenario_config.sample_rate_hz);
n_samples = numel(seed_waveform);
sample_times_s = double(part_start_offset_s) + (0 : n_samples - 1).' ./ fs;
[echo_conditioning_config, seed_echo_source_mode] = localResolveSeedEchoConditioning( ...
    scenario_config, fs);
[echo_source_seed, echo_seed_conditioning] = helperSyntheticBuildConditionedEchoSeed( ...
    seed_waveform, fs, echo_conditioning_config);

reference_channel = localApplyGain(seed_waveform, double(scenario_config.reference_gain_db));
surveillance_channel = localApplyGain( ...
    localApplyDelay(seed_waveform, double(scenario_config.direct_path_delay_samples)), ...
    double(scenario_config.direct_path_gain_db));

bistatic_tracks = truth_bundle.bistatic_tracks;
scenario_targets = scenario_config.targets;
n_tracks = numel(bistatic_tracks);
track_summaries = repmat(struct( ...
    'hex', '', ...
    'callsign', '', ...
    'echo_gain_db', NaN, ...
    'valid_samples', 0, ...
    'delay_samples_range', [NaN, NaN], ...
    'doppler_hz_range', [NaN, NaN]), 1, n_tracks);

for idx = 1 : n_tracks
    track = bistatic_tracks(idx);
    [delay_samples, doppler_hz, valid_mask] = localInterpolateTrackState( ...
        track, double(scenario_config.radar_epoch_utc), sample_times_s, fs, ...
        double(scenario_config.direct_path_delay_samples));
    echo_gain_db = localResolveEchoGainDB(track.hex, scenario_targets);

    if any(valid_mask)
        delayed_seed = localApplyDelay(echo_source_seed, delay_samples);
        doppler_rotation = localBuildDopplerRotation(doppler_hz, valid_mask, fs);
        echo_waveform = localApplyGain(delayed_seed .* doppler_rotation, echo_gain_db);
        echo_waveform(~valid_mask) = 0;
        surveillance_channel = surveillance_channel + echo_waveform;

        track_summaries(idx).delay_samples_range = [ ...
            min(double(delay_samples(valid_mask))), ...
            max(double(delay_samples(valid_mask)))];
        track_summaries(idx).doppler_hz_range = [ ...
            min(double(doppler_hz(valid_mask))), ...
            max(double(doppler_hz(valid_mask)))];
        track_summaries(idx).valid_samples = sum(valid_mask);
    end

    track_summaries(idx).hex = char(string(track.hex));
    track_summaries(idx).callsign = char(string(track.callsign));
    track_summaries(idx).echo_gain_db = echo_gain_db;
end

if scenario_config.use_stochastic_noise
    if isempty(scenario_config.random_seed)
        error('helperSyntheticSynthesizeSeedBackedChannels:missingRandomSeed', ...
            'random_seed is required when use_stochastic_noise is true.');
    end

    surveillance_channel = awgn( ...
        surveillance_channel, ...
        double(scenario_config.noise_snr_db), ...
        'measured', ...
        double(scenario_config.random_seed) + part_idx - 1);
    reference_channel = awgn( ...
        reference_channel, ...
        double(scenario_config.noise_snr_db) + 12, ...
        'measured', ...
        double(scenario_config.random_seed) + 1000 + part_idx - 1);
end

surveillance_channel = complex(single(real(surveillance_channel)), single(imag(surveillance_channel)));
reference_channel = complex(single(real(reference_channel)), single(imag(reference_channel)));

synthesis_summary = struct( ...
    'part_idx', double(part_idx), ...
    'part_start_offset_s', double(part_start_offset_s), ...
    'signal_mode', char(string(scenario_config.signal_mode)), ...
    'seed_echo_source_mode', char(string(seed_echo_source_mode)), ...
    'echo_seed_conditioning', echo_seed_conditioning, ...
    'track_summaries', {track_summaries});
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

function [delay_samples, doppler_hz, valid_mask] = localInterpolateTrackState( ...
    bistatic_track, radar_epoch_utc, sample_times_s, fs, direct_path_delay_samples)
c_light = physconst('LightSpeed');
t_track_s = double(bistatic_track.t_utc(:)) - radar_epoch_utc;
R_excess_m = interp1(t_track_s, double(bistatic_track.R_excess_m(:)), sample_times_s, 'linear', NaN);
doppler_hz = interp1(t_track_s, double(bistatic_track.f_D_hz(:)), sample_times_s, 'linear', NaN);

valid_mask = isfinite(R_excess_m) & isfinite(doppler_hz) & R_excess_m >= 0;
delay_samples = direct_path_delay_samples + (R_excess_m ./ c_light) .* fs;
delay_samples(~valid_mask) = 0;
doppler_hz(~valid_mask) = 0;
delay_samples = single(delay_samples);
end

function phase_rotation = localBuildDopplerRotation(doppler_hz, valid_mask, fs)
doppler_hz = double(doppler_hz(:));
valid_mask = logical(valid_mask(:));
doppler_hz(~valid_mask) = 0;

phase_rad = 2 * pi * [0; cumsum(doppler_hz(1:end - 1), 1)] ./ fs;
phase_rotation = exp(1j * phase_rad);
phase_rotation(~valid_mask) = 0;
phase_rotation = complex(single(real(phase_rotation)), single(imag(phase_rotation)));
end

function echo_gain_db = localResolveEchoGainDB(track_hex, scenario_targets)
echo_gain_db = -25;
for idx = 1 : numel(scenario_targets)
    if strcmpi(char(string(scenario_targets(idx).icao_hex)), char(string(track_hex)))
        echo_gain_db = double(scenario_targets(idx).echo_gain_db);
        return
    end
end
end

function [echo_conditioning_config, seed_echo_source_mode] = localResolveSeedEchoConditioning( ...
    scenario_config, sample_rate_hz)
echo_conditioning_config = struct( ...
    'enabled', true, ...
    'reference_source', 'full_seed', ...
    'direct_path_source', 'full_seed', ...
    'target_echo_source', 'conditioned_seed', ...
    'method', 'dominant_line_notch_then_rms_match_v1', ...
    'minimum_prominence_db', 10, ...
    'notch_half_width_hz', min(50e3, 0.01 * double(sample_rate_hz)), ...
    'dc_highpass_cutoff_hz', min(50e3, 0.01 * double(sample_rate_hz)), ...
    'max_analysis_samples', 65536, ...
    'baseline_span_bins', 129, ...
    'note', ['Reference and direct-path channels keep the full seed. ' ...
        'Synthetic target echoes use a lightly conditioned seed copy so a dominant ' ...
        'pilot-like line does not create full-height Doppler columns.']);

if isfield(scenario_config, 'seed_echo_conditioning') && ...
        isstruct(scenario_config.seed_echo_conditioning) && ...
        isscalar(scenario_config.seed_echo_conditioning)
    field_names = fieldnames(scenario_config.seed_echo_conditioning);
    for idx = 1 : numel(field_names)
        echo_conditioning_config.(field_names{idx}) = scenario_config.seed_echo_conditioning.(field_names{idx});
    end
end

echo_conditioning_config.enabled = logical(echo_conditioning_config.enabled);
if isfield(scenario_config, 'seed_echo_source_mode') && ...
        strlength(string(scenario_config.seed_echo_source_mode)) > 0
    seed_echo_source_mode = char(string(scenario_config.seed_echo_source_mode));
elseif echo_conditioning_config.enabled
    seed_echo_source_mode = 'conditioned_target_echoes_v1';
else
    seed_echo_source_mode = 'full_seed_target_echoes_v1';
end
end
