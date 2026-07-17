function [joint_metrics, diagnostics] = helperPlutoToneScoreJointMetrics(reference_signal, surveillance_signal, sample_rate_hz, varargin)
%HELPERPLUTOTONESCOREJOINTMETRICS Score joint two-channel consistency metrics.
%
% Plain-language goal:
%   The standalone Pluto precheck should keep the joint decision tight. We
%   only hard-gate on whether both channels report the same tone frequency
%   to within the allowed delta. We still record cross-correlation because
%   it is useful for operator judgment, but it remains advisory-only.
%
% Syntax
%   joint_metrics = helperPlutoToneScoreJointMetrics(ref, surv, fs)
%   [joint_metrics, diagnostics] = helperPlutoToneScoreJointMetrics(...)
%
% Name-value options
%   'ReferenceMetrics'       Channel metrics struct for REF
%   'SurveillanceMetrics'    Channel metrics struct for SURV
%   'Thresholds'             Joint threshold struct
%   'MaxLagSamples'          Max lag for xcorr advisory
%   'MaxSamplesForXCorr'     Maximum samples used for xcorr
%   'Verbose'                Print one-line summary. Default: false
%
% Outputs
%   joint_metrics  Struct matching the frozen result-schema joint fields
%   diagnostics    Extra lag-domain arrays for plots and tests
%
% See also: xcorr.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'reference_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'surveillance_signal', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addRequired(p, 'sample_rate_hz', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ReferenceMetrics', struct(), @isstruct);
addParameter(p, 'SurveillanceMetrics', struct(), @isstruct);
addParameter(p, 'Thresholds', struct(), @isstruct);
addParameter(p, 'MaxLagSamples', 512, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'MaxSamplesForXCorr', 65536, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, reference_signal, surveillance_signal, sample_rate_hz, varargin{:});
opts = p.Results;

reference_signal = double(reference_signal(:));
surveillance_signal = double(surveillance_signal(:));
n_use = min([numel(reference_signal), numel(surveillance_signal), opts.MaxSamplesForXCorr]);
reference_use = reference_signal(1:n_use);
surveillance_use = surveillance_signal(1:n_use);

reference_use = reference_use - mean(reference_use);
surveillance_use = surveillance_use - mean(surveillance_use);

reference_rms = rms(reference_use);
surveillance_rms = rms(surveillance_use);
xcorr_available = reference_rms > eps && surveillance_rms > eps;

lags_samples = NaN;
correlation_abs = NaN;
xcorr_lag_samples = NaN;
xcorr_peak_db = NaN;

if xcorr_available
    reference_use = reference_use ./ (reference_rms + eps);
    surveillance_use = surveillance_use ./ (surveillance_rms + eps);

    max_lag_samples = min(opts.MaxLagSamples, n_use - 1);
    [correlation_values, lag_axis] = xcorr(surveillance_use, reference_use, max_lag_samples, 'coeff');
    [peak_coeff, peak_idx] = max(abs(correlation_values));

    lags_samples = lag_axis(:);
    correlation_abs = abs(correlation_values(:));
    xcorr_lag_samples = lag_axis(peak_idx);
    xcorr_peak_db = 20 * log10(peak_coeff + eps);
else
    max_lag_samples = NaN;
end

reference_frequency_hz = localMeasuredFrequencyHz(opts.ReferenceMetrics);
surveillance_frequency_hz = localMeasuredFrequencyHz(opts.SurveillanceMetrics);
channel_frequency_delta_hz = NaN;
if isfinite(reference_frequency_hz) && isfinite(surveillance_frequency_hz)
    channel_frequency_delta_hz = abs(reference_frequency_hz - surveillance_frequency_hz);
end

[status, fail_codes, warn_codes] = localClassifyJointMetrics( ...
    channel_frequency_delta_hz, ...
    xcorr_lag_samples, ...
    xcorr_peak_db, ...
    opts.Thresholds);

if xcorr_available
    xcorr_note = sprintf( ...
        'xcorr peak %.1f dB at %+d sample(s). Advisory only.', ...
        xcorr_peak_db, ...
        xcorr_lag_samples);
else
    xcorr_note = 'xcorr advisory unavailable because one or both channels are effectively zero after mean removal.';
end

joint_metrics = struct( ...
    'channel_frequency_delta_hz', channel_frequency_delta_hz, ...
    'xcorr_lag_samples', xcorr_lag_samples, ...
    'xcorr_lag_seconds', xcorr_lag_samples / sample_rate_hz, ...
    'xcorr_peak_db', xcorr_peak_db, ...
    'xcorr_note', xcorr_note, ...
    'status', status, ...
    'fail_codes', {fail_codes}, ...
    'warn_codes', {warn_codes});

diagnostics = struct( ...
    'samples_used', n_use, ...
    'max_lag_samples', max_lag_samples, ...
    'lags_samples', lags_samples, ...
    'correlation_abs', correlation_abs, ...
    'xcorr_available', xcorr_available);

if opts.Verbose
    fprintf(['[helperPlutoToneScoreJointMetrics] delta %.1f Hz | ' ...
        'xcorr peak %.1f dB | lag %+d samples | status %s\n'], ...
        channel_frequency_delta_hz, ...
        xcorr_peak_db, ...
        xcorr_lag_samples, ...
        status);
end

end

function measured_frequency_hz = localMeasuredFrequencyHz(metrics)
measured_frequency_hz = NaN;
if isstruct(metrics) && isfield(metrics, 'measured_frequency_hz') && ~isempty(metrics.measured_frequency_hz)
    measured_frequency_hz = double(metrics.measured_frequency_hz);
end
end

function [status, fail_codes, warn_codes] = localClassifyJointMetrics(channel_frequency_delta_hz, xcorr_lag_samples, xcorr_peak_db, thresholds)
fail_codes = cell(0, 1);
warn_codes = cell(0, 1);

channel_frequency_delta_max_hz = localGetThreshold(thresholds, 'channel_frequency_delta_max_hz');
channel_frequency_delta_warn_hz = localGetThreshold(thresholds, 'channel_frequency_delta_warn_hz');
xcorr_peak_advisory_min_db = localGetThreshold(thresholds, 'xcorr_peak_advisory_min_db');
xcorr_lag_advisory_max_samples = localGetThreshold(thresholds, 'xcorr_lag_advisory_max_samples');

if isfinite(channel_frequency_delta_hz)
    if isfinite(channel_frequency_delta_max_hz) && channel_frequency_delta_hz > channel_frequency_delta_max_hz
        fail_codes{end + 1} = 'CHANNEL_FREQUENCY_MISMATCH';
    elseif isfinite(channel_frequency_delta_warn_hz) && channel_frequency_delta_hz > channel_frequency_delta_warn_hz
        warn_codes{end + 1} = 'CHANNEL_FREQUENCY_DELTA_NEAR_LIMIT';
    end
end

lag_advisory = false;
if isfinite(xcorr_peak_advisory_min_db) && isfinite(xcorr_peak_db) && xcorr_peak_db < xcorr_peak_advisory_min_db
    lag_advisory = true;
end
if isfinite(xcorr_lag_advisory_max_samples) && isfinite(xcorr_lag_samples) && ...
        abs(xcorr_lag_samples) > xcorr_lag_advisory_max_samples
    lag_advisory = true;
end
if lag_advisory
    warn_codes{end + 1} = 'JOINT_XCORR_ADVISORY';
end

if ~isempty(fail_codes)
    status = 'FAIL';
elseif ~isempty(warn_codes)
    status = 'WARN';
else
    status = 'PASS';
end
end

function value = localGetThreshold(thresholds, field_name)
value = NaN;
if isstruct(thresholds) && isfield(thresholds, field_name) && ~isempty(thresholds.(field_name))
    value = double(thresholds.(field_name));
end
end
