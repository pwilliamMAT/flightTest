function [metrics, diagnostics] = helperPlutoToneScoreChannel(channel_signal, sample_rate_hz, varargin)
%HELPERPLUTOTONESCORECHANNEL Score one captured channel against the expected CW tone.
%
% Plain-language goal:
%   For the standalone Pluto precheck we want a very small set of channel
%   metrics that answer four questions quickly:
%     1. Is a narrow tone present near the expected offset?
%     2. How far above the local spectral floor is that tone?
%     3. Is the tone at the expected frequency?
%     4. Has the overall channel level drifted away from its baseline?
%
% Syntax
%   metrics = helperPlutoToneScoreChannel(channel_signal, sample_rate_hz)
%   [metrics, diagnostics] = helperPlutoToneScoreChannel(..., 'Name', value)
%
% Name-value options
%   'ChannelLabel'             'REF' or 'SURV'. Default: 'REF'
%   'ChannelIndex'             Numeric channel index. Default follows label
%   'RXLabel'                  Display label. Default follows label
%   'ExpectedFrequencyHz'      Expected baseband tone frequency [Hz]
%   'SearchHalfWidthHz'        Search half-width around expected tone [Hz]
%   'PeakExclusionHalfWidthHz' Exclusion width for local-floor estimate [Hz]
%   'NumSamplesForSpectrum'    Maximum samples used for spectral scoring
%   'WelchWindowLength'        Welch window length
%   'WelchOverlapLength'       Welch overlap length
%   'NFFT'                     Welch FFT length
%   'BaselineMetrics'          Struct with baseline channel metrics
%   'Thresholds'               Struct with warn/fail thresholds
%   'Verbose'                  Print one-line summary. Default: false
%
% Outputs
%   metrics      Struct matching the frozen result-schema channel fields
%   diagnostics  Extra spectral data for plots and tests
%
% See also: pwelch, findpeaks, goertzel.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'channel_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'sample_rate_hz', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ChannelLabel', "REF", @(x) ischar(x) || isstring(x));
addParameter(p, 'ChannelIndex', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(p, 'RXLabel', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ExpectedFrequencyHz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SearchHalfWidthHz', 25e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PeakExclusionHalfWidthHz', 2e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'NumSamplesForSpectrum', 262144, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'WelchWindowLength', 8192, @(x) isnumeric(x) && isscalar(x) && x >= 32);
addParameter(p, 'WelchOverlapLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'NFFT', 131072, @(x) isnumeric(x) && isscalar(x) && x >= 256);
addParameter(p, 'BaselineMetrics', struct(), @isstruct);
addParameter(p, 'Thresholds', struct(), @isstruct);
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, channel_signal, sample_rate_hz, varargin{:});
opts = p.Results;

[channel_label, channel_index, rx_label, code_prefix] = localResolveChannelMetadata( ...
    opts.ChannelLabel, opts.ChannelIndex, opts.RXLabel);

channel_signal = double(channel_signal(:));
full_scale = localResolveFullScale(channel_signal);
level_dbfs = 20 * log10(rms(channel_signal) / full_scale + eps);

n_use = min(numel(channel_signal), opts.NumSamplesForSpectrum);
analysis_signal = channel_signal(1:n_use);
analysis_signal = analysis_signal - mean(analysis_signal);

window_length = min(opts.WelchWindowLength, n_use);
overlap_length = localResolveOverlapLength(opts.WelchOverlapLength, window_length);
nfft = localResolveNFFT(opts.NFFT, n_use, window_length);

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

localValidateExpectedFrequency(opts.ExpectedFrequencyHz, sample_rate_hz);
search_mask = abs(frequency_hz - opts.ExpectedFrequencyHz) <= opts.SearchHalfWidthHz;

if ~any(search_mask)
    error('helperPlutoToneScoreChannel:emptySearchWindow', ...
        'No Welch frequency bins fell inside the requested search window.');
end

search_frequency_hz = frequency_hz(search_mask);
search_spectrum_dbfs = spectrum_dbfs(search_mask);
[peak_values_dbfs, peak_locations_hz] = findpeaks( ...
    search_spectrum_dbfs, ...
    search_frequency_hz, ...
    'SortStr', 'descend');

peak_found = ~isempty(peak_values_dbfs);
if peak_found
    measured_frequency_hz = peak_locations_hz(1);
    peak_from_spectrum_dbfs = peak_values_dbfs(1);
else
    [peak_from_spectrum_dbfs, peak_idx] = max(search_spectrum_dbfs);
    measured_frequency_hz = search_frequency_hz(peak_idx);
end

peak_exclusion_half_width_hz = max(opts.PeakExclusionHalfWidthHz, 2 * rbw_hz);
floor_mask = search_mask & abs(frequency_hz - measured_frequency_hz) >= peak_exclusion_half_width_hz;
if nnz(floor_mask) < 8
    floor_mask = search_mask;
end

local_floor_dbfs = median(spectrum_dbfs(floor_mask), 'omitnan');
if ~isfinite(local_floor_dbfs)
    local_floor_dbfs = median(search_spectrum_dbfs, 'omitnan');
end

[tone_peak_dbfs, goertzel_bin_index] = localEstimateTonePeakDBFS( ...
    analysis_signal, sample_rate_hz, measured_frequency_hz, full_scale);

if ~isfinite(tone_peak_dbfs)
    tone_peak_dbfs = peak_from_spectrum_dbfs;
end

frequency_error_hz = measured_frequency_hz - opts.ExpectedFrequencyHz;
detect_margin_db = tone_peak_dbfs - local_floor_dbfs;
level_delta_vs_baseline_db = localBaselineLevelDelta(level_dbfs, opts.BaselineMetrics);

[status, fail_codes, warn_codes] = localClassifyChannel( ...
    peak_found, ...
    detect_margin_db, ...
    frequency_error_hz, ...
    level_dbfs, ...
    level_delta_vs_baseline_db, ...
    opts.Thresholds, ...
    code_prefix);

metrics = struct( ...
    'channel_label', char(channel_label), ...
    'channel_index', channel_index, ...
    'rx_label', char(rx_label), ...
    'tone_found', peak_found, ...
    'expected_frequency_hz', opts.ExpectedFrequencyHz, ...
    'measured_frequency_hz', measured_frequency_hz, ...
    'frequency_error_hz', frequency_error_hz, ...
    'level_dbfs', level_dbfs, ...
    'tone_peak_dbfs', tone_peak_dbfs, ...
    'local_floor_dbfs', local_floor_dbfs, ...
    'detect_margin_db', detect_margin_db, ...
    'level_delta_vs_baseline_db', level_delta_vs_baseline_db, ...
    'status', status, ...
    'fail_codes', {fail_codes}, ...
    'warn_codes', {warn_codes});

diagnostics = struct( ...
    'samples_used', n_use, ...
    'welch_window_length', window_length, ...
    'welch_overlap_length', overlap_length, ...
    'nfft', nfft, ...
    'rbw_hz', rbw_hz, ...
    'full_scale', full_scale, ...
    'frequency_hz', frequency_hz(:), ...
    'spectrum_dbfs', spectrum_dbfs(:), ...
    'search_frequency_hz', search_frequency_hz(:), ...
    'search_spectrum_dbfs', search_spectrum_dbfs(:), ...
    'search_mask', search_mask(:), ...
    'peak_found', peak_found, ...
    'peak_from_spectrum_dbfs', peak_from_spectrum_dbfs, ...
    'goertzel_bin_index', goertzel_bin_index);

if opts.Verbose
    fprintf(['[helperPlutoToneScoreChannel] %s: tone=%s | detect %.1f dB | ' ...
        'freq err %.1f Hz | level %.1f dBFS | status %s\n'], ...
        char(rx_label), ...
        localPassString(peak_found), ...
        detect_margin_db, ...
        frequency_error_hz, ...
        level_dbfs, ...
        status);
end

end

function [channel_label, channel_index, rx_label, code_prefix] = localResolveChannelMetadata(channel_label_in, channel_index_in, rx_label_in)
channel_label = upper(string(channel_label_in));
channel_index = channel_index_in;
rx_label = string(rx_label_in);

switch channel_label
    case "REF"
        code_prefix = 'REFERENCE';
        if isempty(channel_index)
            channel_index = 2;
        end
        if strlength(rx_label) == 0
            rx_label = "CH2/RX2";
        end
    case "SURV"
        code_prefix = 'SURVEILLANCE';
        if isempty(channel_index)
            channel_index = 1;
        end
        if strlength(rx_label) == 0
            rx_label = "CH1/RX1";
        end
    otherwise
        code_prefix = char(upper(channel_label));
        if isempty(channel_index)
            channel_index = NaN;
        end
        if strlength(rx_label) == 0
            rx_label = channel_label;
        end
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

function localValidateExpectedFrequency(expected_frequency_hz, sample_rate_hz)
nyquist_hz = sample_rate_hz / 2;
if abs(expected_frequency_hz) > nyquist_hz
    error('helperPlutoToneScoreChannel:expectedFrequencyOutOfRange', ...
        'ExpectedFrequencyHz %.3f MHz is outside the capture Nyquist span %.3f MHz.', ...
        expected_frequency_hz / 1e6, nyquist_hz / 1e6);
end
end

function [tone_peak_dbfs, goertzel_bin_index] = localEstimateTonePeakDBFS(signal, sample_rate_hz, measured_frequency_hz, full_scale)
n_samples = numel(signal);
normalized_frequency = mod(measured_frequency_hz, sample_rate_hz) / sample_rate_hz;
goertzel_bin_index = round(normalized_frequency * n_samples) + 1;
goertzel_bin_index = max(1, min(n_samples, goertzel_bin_index));

tone_dft = goertzel(signal, goertzel_bin_index);
tone_amplitude = abs(tone_dft) / n_samples;
tone_peak_dbfs = 20 * log10(tone_amplitude / full_scale + eps);
end

function level_delta_vs_baseline_db = localBaselineLevelDelta(level_dbfs, baseline_metrics)
level_delta_vs_baseline_db = NaN;
if isstruct(baseline_metrics) && isfield(baseline_metrics, 'level_dbfs') && ...
        isfinite(baseline_metrics.level_dbfs)
    level_delta_vs_baseline_db = level_dbfs - double(baseline_metrics.level_dbfs);
end
end

function [status, fail_codes, warn_codes] = localClassifyChannel(peak_found, detect_margin_db, frequency_error_hz, level_dbfs, level_delta_vs_baseline_db, thresholds, code_prefix)
fail_codes = cell(0, 1);
warn_codes = cell(0, 1);

if ~peak_found
    fail_codes{end + 1} = sprintf('%s_TONE_NOT_FOUND', code_prefix);
end

detect_margin_min_db = localGetThreshold(thresholds, 'detect_margin_min_db');
detect_margin_warn_db = localGetThreshold(thresholds, 'detect_margin_warn_db');
frequency_error_max_hz = localGetThreshold(thresholds, 'frequency_error_max_hz');
level_max_dbfs = localGetThreshold(thresholds, 'level_max_dbfs');
baseline_level_drift_max_db = localGetThreshold(thresholds, 'baseline_level_drift_max_db');
baseline_level_drift_warn_db = localGetThreshold(thresholds, 'baseline_level_drift_warn_db');

if peak_found
    if isfinite(detect_margin_min_db) && detect_margin_db < detect_margin_min_db
        fail_codes{end + 1} = sprintf('%s_DETECT_MARGIN_LOW', code_prefix);
    elseif isfinite(detect_margin_warn_db) && detect_margin_db < detect_margin_warn_db
        warn_codes{end + 1} = sprintf('%s_DETECT_MARGIN_NEAR_LIMIT', code_prefix);
    end

    if isfinite(frequency_error_max_hz) && abs(frequency_error_hz) > frequency_error_max_hz
        fail_codes{end + 1} = sprintf('%s_FREQUENCY_ERROR_HIGH', code_prefix);
    end
end

if isfinite(level_max_dbfs) && level_dbfs > level_max_dbfs
    fail_codes{end + 1} = sprintf('%s_LEVEL_TOO_HIGH', code_prefix);
end

if isfinite(level_delta_vs_baseline_db)
    if isfinite(baseline_level_drift_max_db) && abs(level_delta_vs_baseline_db) > baseline_level_drift_max_db
        fail_codes{end + 1} = sprintf('%s_BASELINE_LEVEL_DRIFT', code_prefix);
    elseif isfinite(baseline_level_drift_warn_db) && abs(level_delta_vs_baseline_db) > baseline_level_drift_warn_db
        warn_codes{end + 1} = sprintf('%s_BASELINE_LEVEL_DRIFT_NEAR_LIMIT', code_prefix);
    end
end

status = localResolveStatus(fail_codes, warn_codes);
end

function value = localGetThreshold(thresholds, field_name)
value = NaN;
if isstruct(thresholds) && isfield(thresholds, field_name) && ~isempty(thresholds.(field_name))
    value = double(thresholds.(field_name));
end
end

function status = localResolveStatus(fail_codes, warn_codes)
if ~isempty(fail_codes)
    status = 'FAIL';
elseif ~isempty(warn_codes)
    status = 'WARN';
else
    status = 'PASS';
end
end

function txt = localPassString(tf)
if tf
    txt = 'FOUND';
else
    txt = 'MISSING';
end
end
