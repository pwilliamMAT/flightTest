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
%   This helper reuses helperPlutoToneScoreChannel for each tone, so every
%   per-tone check still uses the existing pwelch, findpeaks, and goertzel
%   path. The new code only aggregates those per-tone MATLAB-toolbox
%   measurements into comb-level REF, SURV, and joint summaries.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'reference_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'surveillance_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'sample_rate_hz', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'tone_offsets_hz', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'SearchHalfWidthHz', 20e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PeakExclusionHalfWidthHz', 2e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
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

reference_tone_metrics_cell = cell(n_tones, 1);
surveillance_tone_metrics_cell = cell(n_tones, 1);
reference_tone_diagnostics_cell = cell(n_tones, 1);
surveillance_tone_diagnostics_cell = cell(n_tones, 1);

for idx = 1:n_tones
    [reference_tone_metrics_cell{idx}, reference_tone_diagnostics_cell{idx}] = helperPlutoToneScoreChannel( ...
        reference_signal, ...
        sample_rate_hz, ...
        'ChannelLabel', 'REF', ...
        'ExpectedFrequencyHz', tone_offsets_hz(idx), ...
        'SearchHalfWidthHz', opts.SearchHalfWidthHz, ...
        'PeakExclusionHalfWidthHz', opts.PeakExclusionHalfWidthHz, ...
        'Verbose', false);

    [surveillance_tone_metrics_cell{idx}, surveillance_tone_diagnostics_cell{idx}] = helperPlutoToneScoreChannel( ...
        surveillance_signal, ...
        sample_rate_hz, ...
        'ChannelLabel', 'SURV', ...
        'ExpectedFrequencyHz', tone_offsets_hz(idx), ...
        'SearchHalfWidthHz', opts.SearchHalfWidthHz, ...
        'PeakExclusionHalfWidthHz', opts.PeakExclusionHalfWidthHz, ...
        'Verbose', false);
end

reference_tone_metrics = vertcat(reference_tone_metrics_cell{:});
surveillance_tone_metrics = vertcat(surveillance_tone_metrics_cell{:});
reference_tone_diagnostics = vertcat(reference_tone_diagnostics_cell{:});
surveillance_tone_diagnostics = vertcat(surveillance_tone_diagnostics_cell{:});

reference_summary = localSummarizeChannel("REF", reference_tone_metrics, opts);
surveillance_summary = localSummarizeChannel("SURV", surveillance_tone_metrics, opts);
joint_summary = localSummarizeJoint(reference_tone_metrics, surveillance_tone_metrics, opts);
[xcorr_metrics, xcorr_diagnostics] = localComputeXcorr(reference_signal, surveillance_signal, opts);

[status, fail_codes, warn_codes] = localClassifyMultitone( ...
    reference_summary, surveillance_summary, joint_summary, opts);

multitone_metrics = struct( ...
    'status', status, ...
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

integrated_margin_db = 10 * log10(sum(10 .^ (detect_margin_db(tone_found) / 10)) + eps);
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
    'min_detect_margin_db', min(detect_margin_db, [], 'omitnan'), ...
    'median_detect_margin_db', median(detect_margin_db, 'omitnan'), ...
    'integrated_detect_margin_db', integrated_margin_db, ...
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

function [status, fail_codes, warn_codes] = localClassifyMultitone(reference_summary, surveillance_summary, joint_summary, opts)
fail_codes = cell(0, 1);
warn_codes = cell(0, 1);

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
if joint_summary.median_channel_frequency_delta_hz > opts.FailMaxMedianChannelDelta_Hz
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
