function thresholds = helperPlutoToneNormalizeThresholds(thresholds_in)
%HELPERPLUTOTONENORMALIZETHRESHOLDS Validate the frozen baseline threshold schema.

if ~(isstruct(thresholds_in) && isscalar(thresholds_in))
    error('helperPlutoToneNormalizeThresholds:badInput', ...
        'Thresholds must be a scalar struct with reference, surveillance, and joint fields.');
end

thresholds = struct();
thresholds.reference = localNormalizeChannelThresholds(thresholds_in, 'reference');
thresholds.surveillance = localNormalizeChannelThresholds(thresholds_in, 'surveillance');
thresholds.joint = localNormalizeJointThresholds(thresholds_in);
end

function channel_thresholds = localNormalizeChannelThresholds(thresholds_in, field_name)
if ~isfield(thresholds_in, field_name) || ~isstruct(thresholds_in.(field_name))
    error('helperPlutoToneNormalizeThresholds:missingChannelThresholds', ...
        'Thresholds must contain the struct field %s.', field_name);
end

source_struct = thresholds_in.(field_name);
channel_thresholds = struct( ...
    'detect_margin_warn_db', localScalarField(source_struct, 'detect_margin_warn_db'), ...
    'detect_margin_min_db', localScalarField(source_struct, 'detect_margin_min_db'), ...
    'frequency_error_warn_hz', localScalarField(source_struct, 'frequency_error_warn_hz'), ...
    'frequency_error_max_hz', localScalarField(source_struct, 'frequency_error_max_hz'), ...
    'level_max_dbfs', localScalarField(source_struct, 'level_max_dbfs'), ...
    'baseline_level_drift_warn_db', localScalarField(source_struct, 'baseline_level_drift_warn_db'), ...
    'baseline_level_drift_max_db', localScalarField(source_struct, 'baseline_level_drift_max_db'));

if channel_thresholds.detect_margin_warn_db < channel_thresholds.detect_margin_min_db
    error('helperPlutoToneNormalizeThresholds:badDetectMarginOrder', ...
        'detect_margin_warn_db must be greater than or equal to detect_margin_min_db for %s.', field_name);
end
if channel_thresholds.frequency_error_warn_hz > channel_thresholds.frequency_error_max_hz
    error('helperPlutoToneNormalizeThresholds:badFrequencyOrder', ...
        'frequency_error_warn_hz must be less than or equal to frequency_error_max_hz for %s.', field_name);
end
if channel_thresholds.baseline_level_drift_warn_db > channel_thresholds.baseline_level_drift_max_db
    error('helperPlutoToneNormalizeThresholds:badDriftOrder', ...
        'baseline_level_drift_warn_db must be less than or equal to baseline_level_drift_max_db for %s.', field_name);
end
end

function joint_thresholds = localNormalizeJointThresholds(thresholds_in)
if ~isfield(thresholds_in, 'joint') || ~isstruct(thresholds_in.joint)
    error('helperPlutoToneNormalizeThresholds:missingJointThresholds', ...
        'Thresholds must contain the struct field joint.');
end

source_struct = thresholds_in.joint;
joint_thresholds = struct( ...
    'channel_frequency_delta_warn_hz', localScalarField(source_struct, 'channel_frequency_delta_warn_hz'), ...
    'channel_frequency_delta_max_hz', localScalarField(source_struct, 'channel_frequency_delta_max_hz'), ...
    'xcorr_peak_advisory_min_db', localScalarField(source_struct, 'xcorr_peak_advisory_min_db'), ...
    'xcorr_lag_advisory_max_samples', localScalarField(source_struct, 'xcorr_lag_advisory_max_samples'));

if joint_thresholds.channel_frequency_delta_warn_hz > joint_thresholds.channel_frequency_delta_max_hz
    error('helperPlutoToneNormalizeThresholds:badJointFrequencyOrder', ...
        'channel_frequency_delta_warn_hz must be less than or equal to channel_frequency_delta_max_hz.');
end
end

function value = localScalarField(source_struct, field_name)
if ~isfield(source_struct, field_name) || isempty(source_struct.(field_name))
    error('helperPlutoToneNormalizeThresholds:missingField', ...
        'Threshold field %s is missing.', field_name);
end

value = double(source_struct.(field_name));
if ~(isscalar(value) && isfinite(value))
    error('helperPlutoToneNormalizeThresholds:badScalarField', ...
        'Threshold field %s must be a finite scalar.', field_name);
end
end
