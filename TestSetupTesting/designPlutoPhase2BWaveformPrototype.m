function result = designPlutoPhase2BWaveformPrototype(varargin)
%DESIGNPLUTOPHASE2BWAVEFORMPROTOTYPE Compare CW, multitone, and LFM pilot waveforms.
%
% Plain-language concept:
%   A single CW tone is easy to find in a spectrum, but it carries almost no
%   timing information because every cycle looks like every other cycle. A
%   multitone comb keeps the "look in known frequency bins" simplicity while
%   letting us add evidence from several tones in one coherent processing
%   interval. A linear FM chirp spreads the same calibration energy over a
%   wider bandwidth; when the receiver correlates the capture with a matched
%   copy of the chirp, the energy compresses back into one narrow timing
%   peak. That pulse compression is the receive processing gain we are trying
%   to evaluate before changing any live Pluto hardware workflow.
%
% This function is deliberately offline-only. It does not call sdrtx,
% transmitRepeat, runLocalHDTVCapture, or any other hardware path. It is a
% design sandbox for Phase 2B waveform selection.
%
% Example:
%   result = designPlutoPhase2BWaveformPrototype( ...
%       'PlotFigures', true, ...
%       'OutputFolder', fullfile(pwd, 'phase2bWaveformPrototype'));
%
% Toolboxes used intentionally:
%   - phased.LinearFMWaveform builds the LFM chirp using the same radar
%     waveform object family we would use in production.
%   - phased.MatchedFilter applies the matched filters used to show pulse
%     compression and relative timing ambiguity.
%   - dsp.SineWave builds deterministic tone components consistent with the
%     existing Phase 1 CW helper.
%   - pwelch, spectrogram, hann, and goertzel provide standard Signal
%     Processing Toolbox diagnostics rather than custom FFT plumbing.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CpiDuration_s', 1e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'TargetRms', 0.20, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'PeakLimit', 0.80, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'CwToneOffset_Hz', 250e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ToneCombOffsets_Hz', [-350 -250 -150 -50 50 150 250 350] * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'ChirpBandwidth_Hz', 1.0e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'InputSnr_dB', -12, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ReferenceDelaySamples', 16, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'SurveillanceDelaySamples', 29, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

fs = double(opts.SampleRate_Hz);
cpi_duration_s = double(opts.CpiDuration_s);
n_cpi = round(fs * cpi_duration_s);
if n_cpi < 128
    error('designPlutoPhase2BWaveformPrototype:shortCPI', ...
        'CpiDuration_s must produce at least 128 samples.');
end

nyquist_hz = fs / 2;
all_offsets_hz = [double(opts.CwToneOffset_Hz), double(opts.ToneCombOffsets_Hz(:).')];
if any(abs(all_offsets_hz) >= nyquist_hz)
    error('designPlutoPhase2BWaveformPrototype:toneOutOfRange', ...
        'All tone offsets must remain inside the baseband Nyquist span.');
end
if double(opts.ChirpBandwidth_Hz) >= fs
    error('designPlutoPhase2BWaveformPrototype:chirpOutOfRange', ...
        'ChirpBandwidth_Hz must be smaller than SampleRate_Hz.');
end

rng(42, 'twister');

% Build three candidates with comparable CPI duration and amplitude limits.
% The CW waveform is the current Phase 1 concept. The comb and chirp are
% candidate Phase 2B concepts that should be evaluated offline before any
% transmit workflow is changed.
waveforms(1) = localBuildCwCandidate(opts, n_cpi);
waveforms(2) = localBuildToneCombCandidate(opts, n_cpi);
waveforms(3) = localBuildLfmCandidate(opts, n_cpi);

for idx = 1:numel(waveforms)
    waveforms(idx) = localAddWaveformDiagnostics(waveforms(idx), opts);
    waveforms(idx) = localAddReceiveSimulation(waveforms(idx), opts);
end

summary = localBuildSummaryTable(waveforms, opts);

result = struct( ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'concept', "Phase 2B waveform selection prototype", ...
    'plain_language_summary', localPlainLanguageSummary(), ...
    'settings', localSettingsStruct(opts, n_cpi), ...
    'waveforms', waveforms, ...
    'summary', summary, ...
    'recommendation', localRecommendation());

if opts.Verbose
    disp(result.plain_language_summary);
    disp(summary);
    disp(result.recommendation);
end

if opts.PlotFigures
    result.figure_handle = localPlotPrototype(result);
    output_folder = string(opts.OutputFolder);
    if strlength(output_folder) > 0
        if ~isfolder(output_folder)
            mkdir(output_folder);
        end
        figure_path = fullfile(output_folder, 'phase2b_waveform_prototype.png');
        exportgraphics(result.figure_handle, figure_path, 'Resolution', 150);
        result.artifact_paths = struct('summary_png', string(figure_path));
    end
end
end

function candidate = localBuildCwCandidate(opts, n_cpi)
fs = double(opts.SampleRate_Hz);
tone_offset_hz = double(opts.CwToneOffset_Hz);

% dsp.SineWave is used here for continuity with the existing Phase 1 helper.
% It produces a deterministic complex tone with explicit sample rate,
% frequency, and frame length.
sine_wave = dsp.SineWave( ...
    'Amplitude', 1, ...
    'ComplexOutput', true, ...
    'Frequency', tone_offset_hz, ...
    'SampleRate', fs, ...
    'SamplesPerFrame', n_cpi);
waveform = double(sine_wave());
release(sine_wave);

[waveform, scale_info] = localNormalizeWaveform(waveform, opts);

candidate = localBaseCandidate( ...
    "CW tone", ...
    "Single spectral line; easy spectral detection but poor delay information.", ...
    waveform, ...
    tone_offset_hz, ...
    0, ...
    scale_info);
candidate.matched_filter_coefficients = conj(flipud(candidate.samples));
candidate.integration_offsets_hz = tone_offset_hz;
end

function candidate = localBuildToneCombCandidate(opts, n_cpi)
fs = double(opts.SampleRate_Hz);
tone_offsets_hz = double(opts.ToneCombOffsets_Hz(:));
waveform = complex(zeros(n_cpi, 1));

% Each tone is generated by dsp.SineWave, then summed. The final waveform is
% normalized after summation because multiple tones can create high peaks
% when their phases line up.
for idx = 1:numel(tone_offsets_hz)
    sine_wave = dsp.SineWave( ...
        'Amplitude', 1, ...
        'ComplexOutput', true, ...
        'Frequency', tone_offsets_hz(idx), ...
        'SampleRate', fs, ...
        'SamplesPerFrame', n_cpi);
    waveform = waveform + double(sine_wave());
    release(sine_wave);
end
waveform = waveform ./ numel(tone_offsets_hz);

[waveform, scale_info] = localNormalizeWaveform(waveform, opts);
occupied_bandwidth_hz = max(tone_offsets_hz) - min(tone_offsets_hz);

candidate = localBaseCandidate( ...
    "Multitone comb", ...
    "Several known tones in one CPI; each tone is weak alone, but their evidence can be integrated.", ...
    waveform, ...
    median(tone_offsets_hz), ...
    occupied_bandwidth_hz, ...
    scale_info);
candidate.matched_filter_coefficients = conj(flipud(candidate.samples));
candidate.integration_offsets_hz = tone_offsets_hz;
candidate.tone_spacing_hz = median(diff(sort(tone_offsets_hz)));
end

function candidate = localBuildLfmCandidate(opts, n_cpi)
fs = double(opts.SampleRate_Hz);
cpi_duration_s = double(opts.CpiDuration_s);
chirp_bandwidth_hz = double(opts.ChirpBandwidth_Hz);

% phased.LinearFMWaveform creates the radar-style chirp. SweepInterval
% "Symmetric" centers the sweep around complex baseband so the emitted
% energy occupies roughly +/- B/2 rather than starting at DC.
lfm = phased.LinearFMWaveform( ...
    'SampleRate', fs, ...
    'PulseWidth', cpi_duration_s, ...
    'PRF', 1 / (2 * cpi_duration_s), ...
    'SweepBandwidth', chirp_bandwidth_hz, ...
    'SweepInterval', 'Symmetric', ...
    'OutputFormat', 'Samples', ...
    'NumSamples', n_cpi);
waveform = double(lfm());
raw_matched_filter = double(getMatchedFilter(lfm));
release(lfm);

[waveform, scale_info] = localNormalizeWaveform(waveform, opts);

% getMatchedFilter gives the toolbox-generated matched-filter coefficients.
% Scale the coefficients by the same factor as the waveform so the filter is
% matched to the normalized transmit candidate.
matched_filter_coefficients = raw_matched_filter(:) .* scale_info.scale_factor;

candidate = localBaseCandidate( ...
    "LFM chirp", ...
    "Wideband sweep; matched filtering compresses CPI energy into a narrow delay peak.", ...
    waveform, ...
    0, ...
    chirp_bandwidth_hz, ...
    scale_info);
candidate.matched_filter_coefficients = matched_filter_coefficients;
candidate.integration_offsets_hz = [];
candidate.sweep_slope_hz_per_s = chirp_bandwidth_hz / cpi_duration_s;
end

function candidate = localBaseCandidate(name, description, waveform, center_offset_hz, bandwidth_hz, scale_info)
candidate = struct( ...
    'name', string(name), ...
    'description', string(description), ...
    'samples', waveform(:), ...
    'center_offset_hz', double(center_offset_hz), ...
    'occupied_bandwidth_hz', double(bandwidth_hz), ...
    'rms', localRms(waveform), ...
    'peak', max(abs(waveform)), ...
    'scale_info', scale_info, ...
    'matched_filter_coefficients', [], ...
    'integration_offsets_hz', [], ...
    'tone_spacing_hz', NaN, ...
    'sweep_slope_hz_per_s', NaN, ...
    'energy', NaN, ...
    'duration_s', NaN, ...
    'time_bandwidth_product', NaN, ...
    'energy_gain_db', NaN, ...
    'psd_frequency_hz', [], ...
    'psd_db', [], ...
    'spectrogram_time_s', [], ...
    'spectrogram_frequency_hz', [], ...
    'spectrogram_db', [], ...
    'tone_integration', struct(), ...
    'receive_simulation', struct());
end

function [waveform, scale_info] = localNormalizeWaveform(waveform, opts)
target_rms = double(opts.TargetRms);
peak_limit = double(opts.PeakLimit);
waveform = waveform(:);

raw_rms = localRms(waveform);
if raw_rms == 0
    error('designPlutoPhase2BWaveformPrototype:zeroWaveform', ...
        'Cannot normalize a zero-valued waveform.');
end

scale_factor = target_rms / raw_rms;
scaled_peak = max(abs(waveform * scale_factor));
peak_limited = scaled_peak > peak_limit;
if peak_limited
    scale_factor = peak_limit / max(abs(waveform));
end

waveform = waveform * scale_factor;
scale_info = struct( ...
    'raw_rms', raw_rms, ...
    'target_rms', target_rms, ...
    'peak_limit', peak_limit, ...
    'scale_factor', scale_factor, ...
    'peak_limited', peak_limited);
end

function candidate = localAddWaveformDiagnostics(candidate, opts)
fs = double(opts.SampleRate_Hz);
n_samples = numel(candidate.samples);
window_length = min(2048, max(128, 2 ^ floor(log2(n_samples / 4))));
window = hann(window_length, 'periodic');
noverlap = floor(0.75 * window_length);
nfft = max(4096, 2 ^ nextpow2(n_samples));

% Welch spectra show how much instantaneous spectral occupancy each
% candidate would put into the Pluto baseband before any channel effects.
[pxx, f_hz] = pwelch(candidate.samples, window, noverlap, nfft, fs, 'centered');
candidate.psd_frequency_hz = f_hz(:);
candidate.psd_db = 10 * log10(pxx(:) + eps);

% Spectrogram is most useful for the chirp, but plotting it for every
% waveform makes the CW/comb/chirp contrast obvious.
[stft, f_spec_hz, t_spec_s] = spectrogram(candidate.samples, window, noverlap, nfft, fs, 'centered');
candidate.spectrogram_time_s = t_spec_s(:);
candidate.spectrogram_frequency_hz = f_spec_hz(:);
candidate.spectrogram_db = 20 * log10(abs(stft) + eps);

candidate.energy = sum(abs(candidate.samples).^2);
candidate.duration_s = n_samples / fs;
if candidate.occupied_bandwidth_hz > 0
    candidate.time_bandwidth_product = candidate.duration_s * candidate.occupied_bandwidth_hz;
else
    candidate.time_bandwidth_product = 0;
end
candidate.energy_gain_db = 10 * log10(candidate.energy + eps);

if ~isempty(candidate.integration_offsets_hz)
    candidate.tone_integration = localToneIntegrationMetric( ...
        candidate.samples, candidate.integration_offsets_hz, fs);
else
    candidate.tone_integration = struct( ...
        'num_tones', 0, ...
        'ideal_noncoherent_gain_db', NaN, ...
        'measured_integrated_to_best_tone_db', NaN, ...
        'tone_powers', []);
end
end

function candidate = localAddReceiveSimulation(candidate, opts)
fs = double(opts.SampleRate_Hz);
ref_delay = round(double(opts.ReferenceDelaySamples));
surv_delay = round(double(opts.SurveillanceDelaySamples));
max_delay = max(ref_delay, surv_delay);
n_waveform = numel(candidate.samples);
n_frame = n_waveform + max_delay + n_waveform;

ref_clean = localDelayedCopy(candidate.samples, n_frame, ref_delay, 1.0);
surv_clean = localDelayedCopy(candidate.samples, n_frame, surv_delay, 0.55 * exp(1j * 0.7));

signal_power = mean(abs(candidate.samples).^2);
noise_power = signal_power / (10 ^ (double(opts.InputSnr_dB) / 10));
ref_rx = ref_clean + localComplexNoise(n_frame, noise_power);
surv_rx = surv_clean + localComplexNoise(n_frame, noise_power);

% phased.MatchedFilter keeps this prototype aligned with the radar toolbox
% path. For CW and tone-comb waveforms the "matched" response intentionally
% exposes their delay ambiguity; for the chirp it shows pulse compression.
mf = phased.MatchedFilter('Coefficients', candidate.matched_filter_coefficients(:));
ref_response = mf(ref_rx);
release(mf);
mf = phased.MatchedFilter('Coefficients', candidate.matched_filter_coefficients(:));
surv_response = mf(surv_rx);
release(mf);

ref_metrics = localMatchedFilterMetrics(ref_response, n_waveform, fs);
surv_metrics = localMatchedFilterMetrics(surv_response, n_waveform, fs);

candidate.receive_simulation = struct( ...
    'input_snr_db', double(opts.InputSnr_dB), ...
    'reference_delay_samples', ref_delay, ...
    'surveillance_delay_samples', surv_delay, ...
    'reference_rx', ref_rx, ...
    'surveillance_rx', surv_rx, ...
    'reference_response', ref_response, ...
    'surveillance_response', surv_response, ...
    'reference_metrics', ref_metrics, ...
    'surveillance_metrics', surv_metrics, ...
    'estimated_channel_delay_delta_samples', surv_metrics.estimated_delay_samples - ref_metrics.estimated_delay_samples, ...
    'true_channel_delay_delta_samples', surv_delay - ref_delay);
end

function delayed = localDelayedCopy(waveform, n_frame, delay_samples, gain)
delayed = complex(zeros(n_frame, 1));
idx = delay_samples + (1:numel(waveform));
delayed(idx) = gain .* waveform(:);
end

function noise = localComplexNoise(n_samples, noise_power)
sigma = sqrt(noise_power / 2);
noise = sigma * (randn(n_samples, 1) + 1j * randn(n_samples, 1));
end

function metrics = localMatchedFilterMetrics(response, n_waveform, fs)
response_mag = abs(response(:));
[peak_value, peak_idx] = max(response_mag);
estimated_delay_samples = peak_idx - n_waveform;

guard = max(4, round(0.000002 * fs));
mask = true(size(response_mag));
mask(max(1, peak_idx - guard):min(numel(mask), peak_idx + guard)) = false;
sidelobe_peak = max(response_mag(mask));

half_power_width_samples = localHalfPowerWidth(response_mag, peak_idx);

metrics = struct( ...
    'peak_index', peak_idx, ...
    'estimated_delay_samples', estimated_delay_samples, ...
    'estimated_delay_s', estimated_delay_samples / fs, ...
    'peak_magnitude', peak_value, ...
    'sidelobe_peak', sidelobe_peak, ...
    'pslr_db', 20 * log10((sidelobe_peak + eps) / (peak_value + eps)), ...
    'half_power_width_samples', half_power_width_samples, ...
    'half_power_width_s', half_power_width_samples / fs);
end

function width_samples = localHalfPowerWidth(response_mag, peak_idx)
peak_value = response_mag(peak_idx);
threshold = peak_value / sqrt(2);
left_idx = peak_idx;
while left_idx > 1 && response_mag(left_idx) >= threshold
    left_idx = left_idx - 1;
end
right_idx = peak_idx;
while right_idx < numel(response_mag) && response_mag(right_idx) >= threshold
    right_idx = right_idx + 1;
end
width_samples = max(1, right_idx - left_idx - 1);
end

function integration = localToneIntegrationMetric(waveform, tone_offsets_hz, fs)
n_samples = numel(waveform);
tone_offsets_hz = double(tone_offsets_hz(:));
tone_powers = zeros(numel(tone_offsets_hz), 1);

% goertzel evaluates only the DFT bins we care about. For a candidate comb,
% that models a receiver that checks known bins and then integrates evidence
% across the comb instead of making a decision from one tone alone.
for idx = 1:numel(tone_offsets_hz)
    bin_index = mod(round(tone_offsets_hz(idx) / fs * n_samples), n_samples) + 1;
    tone_value = goertzel(waveform, bin_index);
    tone_powers(idx) = abs(tone_value).^2;
end

best_tone_power = max(tone_powers);
integrated_power = sum(tone_powers);

integration = struct( ...
    'num_tones', numel(tone_offsets_hz), ...
    'ideal_noncoherent_gain_db', 10 * log10(numel(tone_offsets_hz)), ...
    'measured_integrated_to_best_tone_db', 10 * log10((integrated_power + eps) / (best_tone_power + eps)), ...
    'tone_offsets_hz', tone_offsets_hz, ...
    'tone_powers', tone_powers);
end

function summary = localBuildSummaryTable(waveforms, opts)
names = strings(numel(waveforms), 1);
num_tones = zeros(numel(waveforms), 1);
bandwidth_hz = zeros(numel(waveforms), 1);
tb_product = zeros(numel(waveforms), 1);
ideal_tone_gain_db = NaN(numel(waveforms), 1);
ref_delay_est = zeros(numel(waveforms), 1);
surv_delay_est = zeros(numel(waveforms), 1);
delta_est = zeros(numel(waveforms), 1);
pslr_ref_db = zeros(numel(waveforms), 1);
width_ref_samples = zeros(numel(waveforms), 1);
peak = zeros(numel(waveforms), 1);
rms_value = zeros(numel(waveforms), 1);

for idx = 1:numel(waveforms)
    wf = waveforms(idx);
    names(idx) = wf.name;
    num_tones(idx) = wf.tone_integration.num_tones;
    bandwidth_hz(idx) = wf.occupied_bandwidth_hz;
    tb_product(idx) = wf.time_bandwidth_product;
    ideal_tone_gain_db(idx) = wf.tone_integration.ideal_noncoherent_gain_db;
    ref_delay_est(idx) = wf.receive_simulation.reference_metrics.estimated_delay_samples;
    surv_delay_est(idx) = wf.receive_simulation.surveillance_metrics.estimated_delay_samples;
    delta_est(idx) = wf.receive_simulation.estimated_channel_delay_delta_samples;
    pslr_ref_db(idx) = wf.receive_simulation.reference_metrics.pslr_db;
    width_ref_samples(idx) = wf.receive_simulation.reference_metrics.half_power_width_samples;
    peak(idx) = wf.peak;
    rms_value(idx) = wf.rms;
end

summary = table( ...
    names, ...
    peak, ...
    rms_value, ...
    bandwidth_hz, ...
    tb_product, ...
    num_tones, ...
    ideal_tone_gain_db, ...
    ref_delay_est, ...
    surv_delay_est, ...
    delta_est, ...
    repmat(double(opts.SurveillanceDelaySamples) - double(opts.ReferenceDelaySamples), numel(waveforms), 1), ...
    pslr_ref_db, ...
    width_ref_samples, ...
    'VariableNames', ["Waveform", "Peak", "RMS", "OccupiedBandwidth_Hz", "TimeBandwidthProduct", ...
    "IntegratedToneCount", "IdealToneIntegrationGain_dB", "EstimatedRefDelay_samples", ...
    "EstimatedSurvDelay_samples", "EstimatedDelta_samples", "TrueDelta_samples", ...
    "ReferencePSLR_dB", "ReferenceHalfPowerWidth_samples"]);
end

function fig = localPlotPrototype(result)
waveforms = result.waveforms;
fs = result.settings.sample_rate_hz;

fig = figure('Name', 'Pluto Phase 2B waveform prototype', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Phase 2B waveform prototype: spectra, time-frequency content, and matched-filter response');

nexttile(tl, 1);
hold on;
for idx = 1:numel(waveforms)
    plot(waveforms(idx).psd_frequency_hz / 1e6, waveforms(idx).psd_db, 'LineWidth', 1.1);
end
grid on;
xlabel('Baseband frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('Transmit candidate spectra');
legend({waveforms.name}, 'Location', 'best');

nexttile(tl, 2);
lfm_idx = find([waveforms.name] == "LFM chirp", 1);
imagesc( ...
    waveforms(lfm_idx).spectrogram_time_s * 1e3, ...
    waveforms(lfm_idx).spectrogram_frequency_hz / 1e6, ...
    waveforms(lfm_idx).spectrogram_db);
axis xy;
grid on;
xlabel('Time in CPI (ms)');
ylabel('Baseband frequency (MHz)');
title('LFM chirp spectrogram');
cb = colorbar;
cb.Label.String = 'Magnitude (dB)';

nexttile(tl, 3);
hold on;
for idx = 1:numel(waveforms)
    metrics = waveforms(idx).receive_simulation.reference_metrics;
    response = abs(waveforms(idx).receive_simulation.reference_response);
    response_db = 20 * log10(response / (metrics.peak_magnitude + eps) + eps);
    delay_axis_samples = (1:numel(response_db)) - numel(waveforms(idx).samples);
    plot(delay_axis_samples, response_db, 'LineWidth', 1.1);
end
grid on;
xlabel('Estimated delay (samples)');
ylabel('Matched-filter response (dB rel. peak)');
title('Reference-channel matched-filter response');
legend({waveforms.name}, 'Location', 'best');
ylim([-60 3]);

nexttile(tl, 4);
summary = result.summary;
bar(categorical(summary.Waveform), summary.ReferenceHalfPowerWidth_samples);
grid on;
ylabel('Half-power width (samples)');
title(sprintf('Delay sharpness at %.1f MSps', fs / 1e6));
end

function settings = localSettingsStruct(opts, n_cpi)
settings = struct( ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'cpi_duration_s', double(opts.CpiDuration_s), ...
    'samples_per_cpi', double(n_cpi), ...
    'target_rms', double(opts.TargetRms), ...
    'peak_limit', double(opts.PeakLimit), ...
    'cw_tone_offset_hz', double(opts.CwToneOffset_Hz), ...
    'tone_comb_offsets_hz', double(opts.ToneCombOffsets_Hz(:)), ...
    'chirp_bandwidth_hz', double(opts.ChirpBandwidth_Hz), ...
    'input_snr_db', double(opts.InputSnr_dB), ...
    'reference_delay_samples', double(opts.ReferenceDelaySamples), ...
    'surveillance_delay_samples', double(opts.SurveillanceDelaySamples));
end

function txt = localPlainLanguageSummary()
txt = [ ...
    "CW tone: easiest to transmit and score, but delay is ambiguous because it has almost no useful bandwidth."; ...
    "Multitone comb: keeps spectral-bin scoring and gains robustness by adding evidence from several tones in one CPI, but its spacing creates periodic delay ambiguities."; ...
    "LFM chirp: uses bandwidth intentionally, then matched filtering compresses the received energy into a narrower delay peak, which is the strongest candidate when timing or channel impulse response matters."; ...
    "This prototype is offline-only and should be treated as Phase 2B design evidence, not as a replacement for the Phase 1 readiness gate."];
end

function txt = localRecommendation()
txt = [ ...
    "Recommendation: keep the Phase 1 CW tone gate unchanged for hardware readiness."; ...
    "For Phase 2B, prototype the multitone comb first if the goal is robust tone evidence with minimal Pluto workflow change."; ...
    "Prototype the LFM chirp when the goal shifts to delay, impulse-response, or matched-filter processing gain, because it gives the cleanest timing observable."];
end

function value = localRms(x)
value = sqrt(mean(abs(x(:)).^2));
end
