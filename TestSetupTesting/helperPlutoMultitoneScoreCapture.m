function [multitone_metrics, diagnostics] = helperPlutoMultitoneScoreCapture(reference_signal, surveillance_signal, sample_rate_hz, tone_offsets_hz, varargin)
%HELPERPLUTOMULTITONESCORECAPTURE Score a two-channel multitone pilot capture.
%
% Plain-language concept:
%   The existing Phase 1 scorer asks, "Did each channel see one expected
%   tone?"  A multitone scorer asks the same question several times, once
%   per emitted tone, and then integrates the answers. If most tones are
%   visible on both channels and their measured frequencies agree, the
%   multitone pilot gives stronger evidence than a single line without
%   requiring matched filtering.
%
% Toolbox-first implementation:
%   This helper uses pwelch to score the planned tone bins directly and also
%   performs a coherent matched-tone integration over the available pulse
%   samples. The Welch view is a familiar spectrum diagnostic; the coherent
%   view answers the calibration question more directly: "How much known tone
%   energy accumulates when we integrate for the whole calibration pulse?"

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'reference_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'surveillance_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'sample_rate_hz', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'tone_offsets_hz', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'SearchHalfWidthHz', 20e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PeakExclusionHalfWidthHz', 2e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'ScoringMode', "expected-bin", @(x) any(strcmpi(string(x), ["expected-bin", "search-peak"])));
addParameter(p, 'NumSamplesForSpectrum', Inf, @localMustBeSpectrumSampleLimit);
addParameter(p, 'WelchWindowLength', 8192, @(x) isnumeric(x) && isscalar(x) && x >= 32);
addParameter(p, 'WelchOverlapLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'NFFT', 131072, @(x) isnumeric(x) && isscalar(x) && x >= 256);
addParameter(p, 'MinToneFoundFraction', 0.75, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'WarnMinMedianDetectMargin_dB', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FailMinMedianDetectMargin_dB', -3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'WarnMaxMedianChannelDelta_Hz', 2500, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'FailMaxMedianChannelDelta_Hz', 10000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxLagSamples', 2048, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'MaxSamplesForXCorr', 65536, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, reference_signal, surveillance_signal, sample_rate_hz, tone_offsets_hz, varargin{:});
opts = p.Results;

tone_offsets_hz = double(tone_offsets_hz(:));
localValidateToneOffsets(tone_offsets_hz, sample_rate_hz);

reference_signal = double(reference_signal(:));
surveillance_signal = double(surveillance_signal(:));
n_tones = numel(tone_offsets_hz);

[reference_search_metrics, reference_search_diagnostics] = localScorePeakSearch( ...
    reference_signal, sample_rate_hz, tone_offsets_hz, "REF", opts);
[surveillance_search_metrics, surveillance_search_diagnostics] = localScorePeakSearch( ...
    surveillance_signal, sample_rate_hz, tone_offsets_hz, "SURV", opts);

scoring_mode = lower(string(opts.ScoringMode));
switch scoring_mode
    case "expected-bin"
        [reference_tone_metrics, reference_tone_diagnostics] = localScoreExpectedBins( ...
            reference_signal, sample_rate_hz, tone_offsets_hz, "REF", opts);
        [surveillance_tone_metrics, surveillance_tone_diagnostics] = localScoreExpectedBins( ...
            surveillance_signal, sample_rate_hz, tone_offsets_hz, "SURV", opts);
    case "search-peak"
        reference_tone_metrics = reference_search_metrics;
        surveillance_tone_metrics = surveillance_search_metrics;
        reference_tone_diagnostics = reference_search_diagnostics;
        surveillance_tone_diagnostics = surveillance_search_diagnostics;
end

reference_tone_metrics = localAttachCoherentMetrics( ...
    reference_tone_metrics, reference_signal, sample_rate_hz, tone_offsets_hz, "REF");
surveillance_tone_metrics = localAttachCoherentMetrics( ...
    surveillance_tone_metrics, surveillance_signal, sample_rate_hz, tone_offsets_hz, "SURV");

reference_summary = localSummarizeChannel("REF", reference_tone_metrics, opts);
surveillance_summary = localSummarizeChannel("SURV", surveillance_tone_metrics, opts);
joint_summary = localSummarizeJoint(reference_search_metrics, surveillance_search_metrics, opts);
[xcorr_metrics, xcorr_diagnostics] = localComputeXcorr(reference_signal, surveillance_signal, opts);

[status, fail_codes, warn_codes] = localClassifyMultitone( ...
    reference_summary, surveillance_summary, joint_summary, scoring_mode, opts);

multitone_metrics = struct( ...
    'status', status, ...
    'scoring_mode', char(scoring_mode), ...
    'fail_codes', {fail_codes}, ...
    'warn_codes', {warn_codes}, ...
    'tone_offsets_hz', tone_offsets_hz, ...
    'num_tones', n_tones, ...
    'ideal_noncoherent_integration_gain_db', 10 * log10(n_tones), ...
    'reference', reference_summary, ...
    'surveillance', surveillance_summary, ...
    'joint', joint_summary, ...
    'xcorr_advisory', xcorr_metrics);

diagnostics = struct( ...
    'reference_tone_metrics', reference_tone_metrics, ...
    'surveillance_tone_metrics', surveillance_tone_metrics, ...
    'reference_tone_diagnostics', reference_tone_diagnostics, ...
    'surveillance_tone_diagnostics', surveillance_tone_diagnostics, ...
    'reference_peak_search_tone_metrics', reference_search_metrics, ...
    'surveillance_peak_search_tone_metrics', surveillance_search_metrics, ...
    'reference_peak_search_tone_diagnostics', reference_search_diagnostics, ...
    'surveillance_peak_search_tone_diagnostics', surveillance_search_diagnostics, ...
    'xcorr_diagnostics', xcorr_diagnostics);

if opts.Verbose
    fprintf('[helperPlutoMultitoneScoreCapture] REF tones %d/%d | median margin %.1f dB\n', ...
        reference_summary.num_tones_found, n_tones, reference_summary.median_detect_margin_db);
    fprintf('[helperPlutoMultitoneScoreCapture] SURV tones %d/%d | median margin %.1f dB\n', ...
        surveillance_summary.num_tones_found, n_tones, surveillance_summary.median_detect_margin_db);
    fprintf('[helperPlutoMultitoneScoreCapture] Median channel delta %.1f Hz | status %s\n', ...
        joint_summary.median_channel_frequency_delta_hz, status);
end
end

function [tone_metrics, tone_diagnostics] = localScorePeakSearch(channel_signal, sample_rate_hz, tone_offsets_hz, channel_label, opts)
n_tones = numel(tone_offsets_hz);
tone_metrics_cell = cell(n_tones, 1);
tone_diagnostics_cell = cell(n_tones, 1);

for idx = 1:n_tones
    [tone_metrics_cell{idx}, tone_diagnostics_cell{idx}] = helperPlutoToneScoreChannel( ...
        channel_signal, ...
        sample_rate_hz, ...
        'ChannelLabel', channel_label, ...
        'ExpectedFrequencyHz', tone_offsets_hz(idx), ...
        'SearchHalfWidthHz', opts.SearchHalfWidthHz, ...
        'PeakExclusionHalfWidthHz', opts.PeakExclusionHalfWidthHz, ...
        'Verbose', false);
end

tone_metrics = vertcat(tone_metrics_cell{:});
tone_diagnostics = vertcat(tone_diagnostics_cell{:});
end

function [tone_metrics, diagnostics] = localScoreExpectedBins(channel_signal, sample_rate_hz, tone_offsets_hz, channel_label, opts)
channel_signal = double(channel_signal(:));
full_scale = localResolveFullScale(channel_signal);
level_dbfs = 20 * log10(rms(channel_signal) / full_scale + eps);

n_use = localResolveSpectrumSampleCount(numel(channel_signal), opts.NumSamplesForSpectrum);
analysis_signal = channel_signal(1:n_use);
analysis_signal = analysis_signal - mean(analysis_signal);

window_length = min(opts.WelchWindowLength, n_use);
overlap_length = localResolveOverlapLength(opts.WelchOverlapLength, window_length);
nfft = localResolveNFFT(opts.NFFT, n_use, window_length);

% Welch averaging reduces variance before we evaluate the known comb bins.
% That is the right primary measurement for a planned multitone waveform:
% every emitted tone is known ahead of time, so nearby accidental peaks
% should not steal the measurement from the planned frequency.
window = hann(window_length, 'periodic');
[psd_linear, frequency_hz] = pwelch( ...
    analysis_signal, ...
    window, ...
    overlap_length, ...
    nfft, ...
    sample_rate_hz, ...
    'centered');

rbw_hz = sample_rate_hz / nfft;
bin_power_linear = psd_linear .* rbw_hz;
spectrum_dbfs = 10 * log10(bin_power_linear / (full_scale ^ 2) + eps);

n_tones = numel(tone_offsets_hz);
tone_metrics = repmat(localEmptyToneMetric(channel_label), n_tones, 1);
expected_bin_frequency_hz = nan(n_tones, 1);
expected_bin_index = nan(n_tones, 1);

for idx = 1:n_tones
    expected_frequency_hz = tone_offsets_hz(idx);
    [~, nearest_idx] = min(abs(frequency_hz - expected_frequency_hz));
    expected_bin_index(idx) = nearest_idx;
    expected_bin_frequency_hz(idx) = frequency_hz(nearest_idx);

    search_mask = abs(frequency_hz - expected_frequency_hz) <= opts.SearchHalfWidthHz;
    floor_mask = search_mask & abs(frequency_hz - expected_frequency_hz) >= opts.PeakExclusionHalfWidthHz;
    if nnz(floor_mask) < 8
        floor_mask = search_mask;
    end

    local_floor_dbfs = median(spectrum_dbfs(floor_mask), 'omitnan');
    if ~isfinite(local_floor_dbfs)
        local_floor_dbfs = median(spectrum_dbfs(search_mask), 'omitnan');
    end

    tone_peak_dbfs = spectrum_dbfs(nearest_idx);
    detect_margin_db = tone_peak_dbfs - local_floor_dbfs;
    frequency_error_hz = expected_bin_frequency_hz(idx) - expected_frequency_hz;
    [status, fail_codes, warn_codes] = localClassifyExpectedBinTone(detect_margin_db, opts);

    tone_metrics(idx) = struct( ...
        'channel_label', char(channel_label), ...
        'channel_index', localChannelIndex(channel_label), ...
        'rx_label', char(localRxLabel(channel_label)), ...
        'tone_found', isfinite(detect_margin_db), ...
        'expected_frequency_hz', expected_frequency_hz, ...
        'measured_frequency_hz', expected_bin_frequency_hz(idx), ...
        'frequency_error_hz', frequency_error_hz, ...
        'level_dbfs', level_dbfs, ...
        'tone_peak_dbfs', tone_peak_dbfs, ...
        'local_floor_dbfs', local_floor_dbfs, ...
        'detect_margin_db', detect_margin_db, ...
        'coherent_tone_dbfs', NaN, ...
        'coherent_residual_floor_dbfs', NaN, ...
        'coherent_margin_db', NaN, ...
        'coherent_samples', 0, ...
        'coherent_duration_s', NaN, ...
        'coherent_note', '', ...
        'level_delta_vs_baseline_db', NaN, ...
        'status', status, ...
        'fail_codes', {fail_codes}, ...
        'warn_codes', {warn_codes});
end

diagnostics = struct( ...
    'samples_used', n_use, ...
    'welch_window_length', window_length, ...
    'welch_overlap_length', overlap_length, ...
    'nfft', nfft, ...
    'rbw_hz', rbw_hz, ...
    'full_scale', full_scale, ...
    'frequency_hz', frequency_hz(:), ...
    'spectrum_dbfs', spectrum_dbfs(:), ...
    'expected_bin_index', expected_bin_index, ...
    'expected_bin_frequency_hz', expected_bin_frequency_hz, ...
    'scoring_note', 'Expected-bin multitone scoring uses the planned comb frequencies as the primary measurement.');
end

function tone_metrics = localAttachCoherentMetrics(tone_metrics, channel_signal, sample_rate_hz, tone_offsets_hz, channel_label)
%LOCALATTACHCOHERENTMETRICS Coherently integrate each planned tone.
%
% Plain-language concept:
%   A known tone is like a metronome. If we multiply the receive samples by
%   the opposite metronome and average, the planned tone becomes a DC value
%   that adds coherently while uncorrelated noise averages down. Therefore a
%   longer calibration pulse should increase this coherent margin when the
%   expected tone frequency is accurate and the hardware is stable.
channel_signal = double(channel_signal(:));
num_samples = numel(channel_signal);
full_scale = localResolveFullScale(channel_signal);
signal_power = mean(abs(channel_signal) .^ 2, 'omitnan');
sample_index = (0:num_samples - 1).';

for idx = 1:numel(tone_offsets_hz)
    expected_frequency_hz = double(tone_offsets_hz(idx));
    oscillator = exp(-1j * 2 * pi * expected_frequency_hz / sample_rate_hz * sample_index);
    coherent_value = mean(channel_signal .* oscillator, 'omitnan');
    coherent_tone_power = abs(coherent_value) ^ 2;

    % The variance of the coherent average falls with the number of pulse
    % samples.  This is the processing gain the pulse-duration sweep was
    % intended to expose.
    residual_power = max(signal_power - coherent_tone_power, 0);
    coherent_noise_power = residual_power / max(1, num_samples);
    coherent_margin_db = 10 * log10(coherent_tone_power / (coherent_noise_power + eps) + eps);

    tone_metrics(idx).coherent_tone_dbfs = 20 * log10(abs(coherent_value) / full_scale + eps);
    tone_metrics(idx).coherent_residual_floor_dbfs = 10 * log10(coherent_noise_power / (full_scale ^ 2) + eps);
    tone_metrics(idx).coherent_margin_db = coherent_margin_db;
    tone_metrics(idx).coherent_samples = double(num_samples);
    tone_metrics(idx).coherent_duration_s = double(num_samples) / double(sample_rate_hz);
    tone_metrics(idx).coherent_note = char("Expected-frequency coherent integration over the full provided pulse.");
    tone_metrics(idx).channel_label = char(channel_label);
end
end

function metric = localEmptyToneMetric(channel_label)
metric = struct( ...
    'channel_label', char(channel_label), ...
    'channel_index', localChannelIndex(channel_label), ...
    'rx_label', char(localRxLabel(channel_label)), ...
    'tone_found', false, ...
    'expected_frequency_hz', NaN, ...
    'measured_frequency_hz', NaN, ...
    'frequency_error_hz', NaN, ...
    'level_dbfs', NaN, ...
    'tone_peak_dbfs', NaN, ...
    'local_floor_dbfs', NaN, ...
    'detect_margin_db', NaN, ...
    'coherent_tone_dbfs', NaN, ...
    'coherent_residual_floor_dbfs', NaN, ...
    'coherent_margin_db', NaN, ...
    'coherent_samples', 0, ...
    'coherent_duration_s', NaN, ...
    'coherent_note', '', ...
    'level_delta_vs_baseline_db', NaN, ...
    'status', 'FAIL', ...
    'fail_codes', {{'MULTITONE_EXPECTED_BIN_UNEVALUATED'}}, ...
    'warn_codes', {cell(0, 1)});
end

function [status, fail_codes, warn_codes] = localClassifyExpectedBinTone(detect_margin_db, opts)
fail_codes = cell(0, 1);
warn_codes = cell(0, 1);

if ~isfinite(detect_margin_db)
    status = 'FAIL';
    fail_codes{end + 1} = 'MULTITONE_EXPECTED_BIN_INVALID';
elseif detect_margin_db < opts.FailMinMedianDetectMargin_dB
    status = 'FAIL';
    fail_codes{end + 1} = 'MULTITONE_EXPECTED_BIN_WEAK';
elseif detect_margin_db < opts.WarnMinMedianDetectMargin_dB
    status = 'WARN';
    warn_codes{end + 1} = 'MULTITONE_EXPECTED_BIN_LOW_MARGIN';
else
    status = 'PASS';
end
end

function channel_index = localChannelIndex(channel_label)
if strcmpi(string(channel_label), "REF")
    channel_index = 2;
else
    channel_index = 1;
end
end

function rx_label = localRxLabel(channel_label)
if strcmpi(string(channel_label), "REF")
    rx_label = "CH2/RX2";
else
    rx_label = "CH1/RX1";
end
end

function full_scale = localResolveFullScale(channel_signal)
max_abs_value = max(abs(channel_signal), [], 'omitnan');
if max_abs_value > 2.0
    full_scale = 32768;
else
    full_scale = 1.0;
end
end

function overlap_length = localResolveOverlapLength(overlap_length_in, window_length)
if isempty(overlap_length_in)
    overlap_length = floor(window_length / 2);
else
    overlap_length = min(overlap_length_in, window_length - 1);
end
end

function nfft = localResolveNFFT(requested_nfft, n_use, window_length)
max_supported_nfft = 2 ^ nextpow2(n_use);
nfft = min(requested_nfft, max_supported_nfft);
nfft = max(nfft, 2 ^ nextpow2(window_length));
end

function localMustBeSpectrumSampleLimit(value)
if ~(isnumeric(value) && isscalar(value) && (isinf(value) || (isfinite(value) && value >= 1024)))
    error('helperPlutoMultitoneScoreCapture:invalidSampleLimit', ...
        'NumSamplesForSpectrum must be Inf or a scalar value >= 1024.');
end
end

function n_use = localResolveSpectrumSampleCount(num_samples, requested_limit)
if isinf(requested_limit)
    n_use = num_samples;
else
    n_use = min(num_samples, requested_limit);
end
end

function localValidateToneOffsets(tone_offsets_hz, sample_rate_hz)
nyquist_hz = sample_rate_hz / 2;
if any(abs(tone_offsets_hz) >= nyquist_hz)
    error('helperPlutoMultitoneScoreCapture:toneOutOfRange', ...
        'Every tone offset must remain inside the baseband Nyquist span %.3f MHz.', ...
        nyquist_hz / 1e6);
end
end

function summary = localSummarizeChannel(label, tone_metrics, opts)
tone_found = arrayfun(@(s) logical(s.tone_found), tone_metrics(:));
detect_margin_db = arrayfun(@(s) double(s.detect_margin_db), tone_metrics(:));
frequency_error_hz = arrayfun(@(s) double(s.frequency_error_hz), tone_metrics(:));
measured_frequency_hz = arrayfun(@(s) double(s.measured_frequency_hz), tone_metrics(:));
tone_peak_dbfs = arrayfun(@(s) double(s.tone_peak_dbfs), tone_metrics(:));
local_floor_dbfs = arrayfun(@(s) double(s.local_floor_dbfs), tone_metrics(:));
coherent_tone_dbfs = arrayfun(@(s) double(s.coherent_tone_dbfs), tone_metrics(:));
coherent_residual_floor_dbfs = arrayfun(@(s) double(s.coherent_residual_floor_dbfs), tone_metrics(:));
coherent_margin_db = arrayfun(@(s) double(s.coherent_margin_db), tone_metrics(:));
coherent_duration_s = arrayfun(@(s) double(s.coherent_duration_s), tone_metrics(:));

integrated_margin_db = 10 * log10(sum(10 .^ (detect_margin_db(tone_found) / 10)) + eps);
integrated_coherent_margin_db = 10 * log10(sum(10 .^ (coherent_margin_db(tone_found) / 10)) + eps);
num_tones_found = nnz(tone_found);
found_fraction = num_tones_found / numel(tone_found);

if found_fraction < opts.MinToneFoundFraction
    channel_status = "FAIL";
elseif median(detect_margin_db(tone_found), 'omitnan') < opts.WarnMinMedianDetectMargin_dB
    channel_status = "WARN";
else
    channel_status = "PASS";
end

summary = struct( ...
    'channel_label', char(label), ...
    'num_tones_expected', numel(tone_found), ...
    'num_tones_found', num_tones_found, ...
    'tone_found_fraction', found_fraction, ...
    'tone_found', tone_found, ...
    'measured_frequency_hz', measured_frequency_hz, ...
    'frequency_error_hz', frequency_error_hz, ...
    'tone_peak_dbfs', tone_peak_dbfs, ...
    'local_floor_dbfs', local_floor_dbfs, ...
    'detect_margin_db', detect_margin_db, ...
    'coherent_tone_dbfs', coherent_tone_dbfs, ...
    'coherent_residual_floor_dbfs', coherent_residual_floor_dbfs, ...
    'coherent_margin_db', coherent_margin_db, ...
    'coherent_duration_s', coherent_duration_s, ...
    'min_detect_margin_db', min(detect_margin_db, [], 'omitnan'), ...
    'median_detect_margin_db', median(detect_margin_db, 'omitnan'), ...
    'integrated_detect_margin_db', integrated_margin_db, ...
    'min_coherent_margin_db', min(coherent_margin_db, [], 'omitnan'), ...
    'median_coherent_margin_db', median(coherent_margin_db, 'omitnan'), ...
    'integrated_coherent_margin_db', integrated_coherent_margin_db, ...
    'median_coherent_duration_s', median(coherent_duration_s, 'omitnan'), ...
    'status', char(channel_status));
end

function joint_summary = localSummarizeJoint(reference_tone_metrics, surveillance_tone_metrics, opts)
ref_found = arrayfun(@(s) logical(s.tone_found), reference_tone_metrics(:));
surv_found = arrayfun(@(s) logical(s.tone_found), surveillance_tone_metrics(:));
both_found = ref_found & surv_found;

ref_frequency_hz = arrayfun(@(s) double(s.measured_frequency_hz), reference_tone_metrics(:));
surv_frequency_hz = arrayfun(@(s) double(s.measured_frequency_hz), surveillance_tone_metrics(:));
channel_frequency_delta_hz = abs(ref_frequency_hz - surv_frequency_hz);

median_delta_hz = median(channel_frequency_delta_hz(both_found), 'omitnan');
max_delta_hz = max(channel_frequency_delta_hz(both_found), [], 'omitnan');
if isempty(max_delta_hz)
    max_delta_hz = NaN;
end

if nnz(both_found) < ceil(opts.MinToneFoundFraction * numel(both_found))
    joint_status = "FAIL";
elseif median_delta_hz > opts.FailMaxMedianChannelDelta_Hz
    joint_status = "FAIL";
elseif median_delta_hz > opts.WarnMaxMedianChannelDelta_Hz
    joint_status = "WARN";
else
    joint_status = "PASS";
end

joint_summary = struct( ...
    'frequency_agreement_source', 'search-peak', ...
    'num_tones_found_both_channels', nnz(both_found), ...
    'both_channels_found_fraction', nnz(both_found) / numel(both_found), ...
    'channel_frequency_delta_hz', channel_frequency_delta_hz, ...
    'median_channel_frequency_delta_hz', median_delta_hz, ...
    'max_channel_frequency_delta_hz', max_delta_hz, ...
    'status', char(joint_status));
end

function [xcorr_metrics, xcorr_diagnostics] = localComputeXcorr(reference_signal, surveillance_signal, opts)
n_use = min([numel(reference_signal), numel(surveillance_signal), opts.MaxSamplesForXCorr]);
ref_use = reference_signal(1:n_use);
surv_use = surveillance_signal(1:n_use);
ref_use = ref_use - mean(ref_use);
surv_use = surv_use - mean(surv_use);

ref_rms = rms(ref_use);
surv_rms = rms(surv_use);
if ref_rms <= eps || surv_rms <= eps
    xcorr_metrics = struct( ...
        'available', false, ...
        'lag_samples', NaN, ...
        'peak_db', NaN, ...
        'note', 'xcorr unavailable because one channel is effectively zero.');
    xcorr_diagnostics = struct('lags_samples', NaN, 'correlation_abs', NaN);
    return
end

max_lag_samples = min(round(opts.MaxLagSamples), n_use - 1);
[corr_values, lags] = xcorr(surv_use ./ ref_rms, ref_use ./ surv_rms, max_lag_samples, 'coeff');
[peak_value, peak_idx] = max(abs(corr_values));

xcorr_metrics = struct( ...
    'available', true, ...
    'lag_samples', double(lags(peak_idx)), ...
    'peak_db', 20 * log10(peak_value + eps), ...
    'note', 'Advisory only. Multitone spacing can create periodic lag ambiguities.');
xcorr_diagnostics = struct( ...
    'lags_samples', lags(:), ...
    'correlation_abs', abs(corr_values(:)));
end

function [status, fail_codes, warn_codes] = localClassifyMultitone(reference_summary, surveillance_summary, joint_summary, scoring_mode, opts)
fail_codes = cell(0, 1);
warn_codes = cell(0, 1);
peak_search_is_primary = strcmpi(string(scoring_mode), "search-peak");

min_tones_required = ceil(opts.MinToneFoundFraction * reference_summary.num_tones_expected);

if reference_summary.num_tones_found < min_tones_required
    fail_codes{end + 1} = 'REFERENCE_MULTITONE_INSUFFICIENT_TONES';
end
if surveillance_summary.num_tones_found < min_tones_required
    fail_codes{end + 1} = 'SURVEILLANCE_MULTITONE_INSUFFICIENT_TONES';
end
if reference_summary.median_detect_margin_db < opts.FailMinMedianDetectMargin_dB
    fail_codes{end + 1} = 'REFERENCE_MULTITONE_WEAK';
elseif reference_summary.median_detect_margin_db < opts.WarnMinMedianDetectMargin_dB
    warn_codes{end + 1} = 'REFERENCE_MULTITONE_LOW_MARGIN';
end
if surveillance_summary.median_detect_margin_db < opts.FailMinMedianDetectMargin_dB
    fail_codes{end + 1} = 'SURVEILLANCE_MULTITONE_WEAK';
elseif surveillance_summary.median_detect_margin_db < opts.WarnMinMedianDetectMargin_dB
    warn_codes{end + 1} = 'SURVEILLANCE_MULTITONE_LOW_MARGIN';
end
if joint_summary.median_channel_frequency_delta_hz > opts.FailMaxMedianChannelDelta_Hz && peak_search_is_primary
    fail_codes{end + 1} = 'MULTITONE_CHANNEL_FREQUENCY_MISMATCH';
elseif joint_summary.median_channel_frequency_delta_hz > opts.WarnMaxMedianChannelDelta_Hz
    warn_codes{end + 1} = 'MULTITONE_CHANNEL_FREQUENCY_DELTA_NEAR_LIMIT';
end

if ~isempty(fail_codes)
    status = 'FAIL';
elseif ~isempty(warn_codes)
    status = 'WARN';
else
    status = 'PASS';
end
end
