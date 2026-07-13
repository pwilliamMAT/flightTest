function [seed_file_path, seed_info] = helperSyntheticCreateProbeSeed(varargin)
%HELPERSYNTHETICCREATEPROBESEED Create a deterministic smoke-test seed `.bb`.
%
% Plain language:
% This helper is only for workflow bring-up when a real HDTV field capture
% is not available yet. It writes a short dual-channel baseband file whose
% second channel behaves as the illuminator seed and whose first channel is
% a delayed, frequency-shifted variant. That lets the seed-loading,
% packaging, and wrapper-replay paths run end to end without inventing a
% custom ATSC waveform generator.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'FileName', "synthetic_probe_seed.bb", @(x) ischar(x) || isstring(x));
addParameter(p, 'DurationS', 0.05, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(p, 'SampleRateHz', 8e6, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(p, 'CenterFrequencyHz', 599e6, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(p, 'PilotOffsetHz', -2.69056e6, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'SurveillanceFrequencyOffsetHz', 180, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'SurveillanceDelaySamples', 0.75, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
addParameter(p, 'TargetRMS', 0.25, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(p, 'RandomSeed', 731, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
parse(p, varargin{:});
opts = p.Results;

output_folder = localResolveOutputFolder(opts.OutputFolder);
file_name = char(string(opts.FileName));
seed_file_path = fullfile(output_folder, file_name);
localCreateFolderIfNeeded(output_folder);

sample_rate_hz = double(opts.SampleRateHz);
center_frequency_hz = double(opts.CenterFrequencyHz);
duration_s = double(opts.DurationS);
n_samples = round(sample_rate_hz * duration_s);
t_s = (0 : n_samples - 1).' ./ sample_rate_hz;

rng(double(opts.RandomSeed), 'twister');

wideband_noise = complex(randn(n_samples, 1), randn(n_samples, 1)) ./ sqrt(2);
occupied_band_hz = min(2.75e6, 0.45 * sample_rate_hz);
wideband_noise = lowpass(wideband_noise, occupied_band_hz, sample_rate_hz);

pilot = exp(1j * 2 * pi * double(opts.PilotOffsetHz) .* t_s);
reference_channel = wideband_noise + 0.35 .* pilot;
reference_channel = localNormalizeRMS(reference_channel, double(opts.TargetRMS));

surveillance_channel = frequencyOffset( ...
    reference_channel, sample_rate_hz, double(opts.SurveillanceFrequencyOffsetHz));
surveillance_channel = localApplyDelay( ...
    surveillance_channel, double(opts.SurveillanceDelaySamples));
surveillance_channel = surveillance_channel + 0.05 .* complex( ...
    randn(n_samples, 1), randn(n_samples, 1)) ./ sqrt(2);
surveillance_channel = localNormalizeRMS( ...
    surveillance_channel, 0.8 * double(opts.TargetRMS));

samples = [surveillance_channel, reference_channel];
samples = complex(single(real(samples)), single(imag(samples)));

recording_dt = datetime(2026, 7, 10, 16, 0, 0, 'TimeZone', 'UTC');
metadata = struct( ...
    'Label', 'SyntheticProbeSeed', ...
    'SessionID', 'synthetic_probe_seed', ...
    'ScenarioID', 'probe_seed_smoke_v1', ...
    'LOOffset', 0, ...
    'DateTime', char(string(recording_dt, 'yyyy-MM-dd_HH-mm-ss.SSS')), ...
    'RecordingUTC', posixtime(recording_dt), ...
    'Duration_s', duration_s, ...
    'Repetition', 1, ...
    'DataOrigin', 'synthetic', ...
    'SignalMode', 'probe_seed_v1', ...
    'PilotOffsetHz', double(opts.PilotOffsetHz), ...
    'RandomSeed', double(opts.RandomSeed));

try
    bbw = comm.BasebandFileWriter(seed_file_path, ...
        'SampleRate', sample_rate_hz, ...
        'CenterFrequency', center_frequency_hz, ...
        'Metadata', metadata);
    cleanup_writer = onCleanup(@() release(bbw));
    bbw(samples);
catch ME
    error('helperSyntheticCreateProbeSeed:writeFailed', ...
        'Could not write probe seed file %s: %s', seed_file_path, ME.message);
end

seed_info = struct( ...
    'seed_file_path', seed_file_path, ...
    'duration_s', duration_s, ...
    'sample_rate_hz', sample_rate_hz, ...
    'center_frequency_hz', center_frequency_hz, ...
    'pilot_offset_hz', double(opts.PilotOffsetHz), ...
    'surveillance_frequency_offset_hz', double(opts.SurveillanceFrequencyOffsetHz), ...
    'surveillance_delay_samples', double(opts.SurveillanceDelaySamples), ...
    'target_rms', double(opts.TargetRMS), ...
    'random_seed', double(opts.RandomSeed), ...
    'num_samples', n_samples);
end

function output_folder = localResolveOutputFolder(output_folder_in)
if strlength(string(output_folder_in)) == 0
    output_folder = fullfile(tempdir, 'synthetic_hdtv_probe_seed');
else
    output_folder = char(string(output_folder_in));
end
end

function localCreateFolderIfNeeded(folder_path)
if exist(folder_path, 'dir') == 7
    return
end

[status, message] = mkdir(folder_path);
if ~status
    error('helperSyntheticCreateProbeSeed:mkdirFailed', ...
        'Could not create folder %s: %s', folder_path, message);
end
end

function waveform = localNormalizeRMS(waveform_in, target_rms)
measured_rms = rms(waveform_in);
if measured_rms <= 0 || ~isfinite(measured_rms)
    error('helperSyntheticCreateProbeSeed:degenerateWaveform', ...
        'The generated probe waveform has zero or non-finite RMS.');
end

waveform = waveform_in .* (target_rms ./ measured_rms);
end

function shifted_signal = localApplyDelay(signal_in, delay_samples)
vfd = dsp.VariableFractionalDelay;
cleanup_vfd = onCleanup(@() release(vfd));
delay_value = cast(delay_samples, 'like', real(signal_in(1)));
shifted_signal = vfd(signal_in, delay_value);
end
