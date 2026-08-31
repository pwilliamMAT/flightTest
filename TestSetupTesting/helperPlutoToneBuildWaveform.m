function [waveform, waveform_info] = helperPlutoToneBuildWaveform(sample_rate_hz, tone_offset_hz, tone_amplitude, varargin)
%HELPERPLUTOTONEBUILDWAVEFORM Build a deterministic complex CW waveform for Pluto TX.
%
% Plain-language goal:
%   The Pluto transmitter should emit one stable tone whose frequency and
%   digital level are completely determined by the precheck settings. This
%   helper uses dsp.SineWave so the generated waveform matches the native
%   MATLAB support-package workflow instead of hand-rolled sample loops.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'sample_rate_hz', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'tone_offset_hz', @(x) isnumeric(x) && isscalar(x));
addRequired(p, 'tone_amplitude', @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'MinSamples', 65536, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'MaxExactPeriodSamples', 65536, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, sample_rate_hz, tone_offset_hz, tone_amplitude, varargin{:});
opts = p.Results;

nyquist_hz = sample_rate_hz / 2;
if abs(tone_offset_hz) >= nyquist_hz
    error('helperPlutoToneBuildWaveform:toneOutOfRange', ...
        'ToneOffset_Hz %.3f MHz must remain inside the baseband Nyquist span %.3f MHz.', ...
        tone_offset_hz / 1e6, nyquist_hz / 1e6);
end

[period_samples, exact_periodic_wrap] = localResolvePeriodSamples( ...
    sample_rate_hz, tone_offset_hz, opts.MaxExactPeriodSamples);

if exact_periodic_wrap
    n_samples = ceil(opts.MinSamples / period_samples) * period_samples;
else
    n_samples = opts.MinSamples;
end

sine_wave = dsp.SineWave( ...
    'Amplitude', tone_amplitude, ...
    'ComplexOutput', true, ...
    'Frequency', tone_offset_hz, ...
    'SampleRate', sample_rate_hz, ...
    'SamplesPerFrame', n_samples);
waveform = single(sine_wave());
release(sine_wave);
waveform = waveform(:);

waveform_info = struct( ...
    'sample_rate_hz', double(sample_rate_hz), ...
    'tone_offset_hz', double(tone_offset_hz), ...
    'tone_amplitude', double(tone_amplitude), ...
    'n_samples', double(n_samples), ...
    'period_samples', double(period_samples), ...
    'exact_periodic_wrap', exact_periodic_wrap);

if opts.Verbose
    fprintf(['[helperPlutoToneBuildWaveform] fs %.3f MSps | tone %.3f kHz | ' ...
        'N %d | exact wrap %s\n'], ...
        sample_rate_hz / 1e6, ...
        tone_offset_hz / 1e3, ...
        n_samples, ...
        localLogicalString(exact_periodic_wrap));
end
end

function [period_samples, exact_periodic_wrap] = localResolvePeriodSamples(sample_rate_hz, tone_offset_hz, max_exact_period_samples)
if tone_offset_hz == 0
    period_samples = 1;
    exact_periodic_wrap = true;
    return
end

[~, period_candidate] = rat(abs(tone_offset_hz) / sample_rate_hz, 1e-12);
period_samples = max(1, double(period_candidate));
exact_periodic_wrap = period_samples <= max_exact_period_samples;

if ~exact_periodic_wrap
    period_samples = max_exact_period_samples;
end
end

function txt = localLogicalString(tf)
if tf
    txt = 'true';
else
    txt = 'false';
end
end
