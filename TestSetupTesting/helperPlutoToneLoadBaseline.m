function baseline = helperPlutoToneLoadBaseline(source)
%HELPERPLUTOTONELOADBASELINE Load one commissioned Pluto tone baseline.
%
% Accepted sources:
%   - in-memory baseline struct
%   - baseline-folder path
%   - baseline.mat path
%   - baseline.json path

if isstruct(source)
    baseline = source;
else
    baseline = localLoadBaselineFromSource(source);
end

baseline = localValidateAndNormalizeBaseline(baseline);
end

function baseline = localLoadBaselineFromSource(source)
source_path = char(string(source));
if isempty(source_path)
    error('helperPlutoToneLoadBaseline:emptySource', ...
        'Baseline source must not be empty.');
end

if isfolder(source_path)
    mat_path = fullfile(source_path, 'baseline.mat');
    json_path = fullfile(source_path, 'baseline.json');
    if exist(mat_path, 'file') == 2
        baseline = localLoadBaselineMAT(mat_path);
        return
    end
    if exist(json_path, 'file') == 2
        baseline = localLoadBaselineJSON(json_path);
        return
    end
    error('helperPlutoToneLoadBaseline:missingBaselineArtifacts', ...
        'Folder %s does not contain baseline.mat or baseline.json.', source_path);
end

[~, ~, extension] = fileparts(source_path);
switch lower(extension)
    case '.mat'
        baseline = localLoadBaselineMAT(source_path);
    case '.json'
        baseline = localLoadBaselineJSON(source_path);
    otherwise
        error('helperPlutoToneLoadBaseline:unsupportedSource', ...
            'Baseline source %s must be a folder, baseline.mat, or baseline.json.', source_path);
end
end

function baseline = localLoadBaselineMAT(mat_path)
try
    loaded = load(mat_path, 'baseline');
catch me_load
    error('helperPlutoToneLoadBaseline:matLoadFailed', ...
        'Could not load %s: %s', mat_path, me_load.message);
end

if ~isfield(loaded, 'baseline') || ~isstruct(loaded.baseline)
    error('helperPlutoToneLoadBaseline:missingBaselineVariable', ...
        'MAT file %s does not contain a struct variable named baseline.', mat_path);
end

baseline = loaded.baseline;
end

function baseline = localLoadBaselineJSON(json_path)
try
    baseline = jsondecode(fileread(json_path));
catch me_json
    error('helperPlutoToneLoadBaseline:jsonLoadFailed', ...
        'Could not parse %s: %s', json_path, me_json.message);
end

if ~isstruct(baseline)
    error('helperPlutoToneLoadBaseline:badJSONStruct', ...
        'JSON file %s did not decode into a struct.', json_path);
end
end

function baseline = localValidateAndNormalizeBaseline(baseline)
required_top_level = { ...
    'schema_version', ...
    'baseline_id', ...
    'settings', ...
    'channel_map', ...
    'statistics', ...
    'thresholds'};

for idx = 1:numel(required_top_level)
    field_name = required_top_level{idx};
    if ~isfield(baseline, field_name)
        error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
            'Baseline is missing the field %s.', field_name);
    end
end

if double(baseline.schema_version) ~= 1
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Baseline schema_version %s is not supported.', string(baseline.schema_version));
end

baseline.baseline_id = char(string(baseline.baseline_id));
baseline.settings = localNormalizeSettings(baseline.settings);
baseline.channel_map = localNormalizeChannelMap(baseline.channel_map);
baseline.statistics = localNormalizeStatistics(baseline.statistics);
baseline.thresholds = helperPlutoToneNormalizeThresholds(baseline.thresholds);
end

function settings = localNormalizeSettings(settings_in)
if ~(isstruct(settings_in) && isscalar(settings_in))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'baseline.settings must be a scalar struct.');
end

settings = struct( ...
    'radio_name', char(string(localRequiredField(settings_in, 'radio_name'))), ...
    'capture_file_base', char(string(localRequiredField(settings_in, 'capture_file_base'))), ...
    'center_frequency_hz', localNumericField(settings_in, 'center_frequency_hz'), ...
    'sample_rate_hz', localNumericField(settings_in, 'sample_rate_hz'), ...
    'lo_offset_hz', localNumericField(settings_in, 'lo_offset_hz'), ...
    'capture_tune_frequency_hz', localNumericField(settings_in, 'capture_tune_frequency_hz'), ...
    'gain', localRowVectorField(settings_in, 'gain'), ...
    'tone_offset_hz', localNumericField(settings_in, 'tone_offset_hz'), ...
    'tone_rf_frequency_hz', localNumericField(settings_in, 'tone_rf_frequency_hz'), ...
    'tone_amplitude', localNumericField(settings_in, 'tone_amplitude'), ...
    'capture_duration_s', localNumericField(settings_in, 'capture_duration_s'));
end

function channel_map = localNormalizeChannelMap(channel_map_in)
if ~(isstruct(channel_map_in) && isscalar(channel_map_in))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'baseline.channel_map must be a scalar struct.');
end

channel_map = struct( ...
    'reference_label', char(string(localRequiredField(channel_map_in, 'reference_label'))), ...
    'reference_channel_index', localNumericField(channel_map_in, 'reference_channel_index'), ...
    'reference_rx_label', char(string(localRequiredField(channel_map_in, 'reference_rx_label'))), ...
    'surveillance_label', char(string(localRequiredField(channel_map_in, 'surveillance_label'))), ...
    'surveillance_channel_index', localNumericField(channel_map_in, 'surveillance_channel_index'), ...
    'surveillance_rx_label', char(string(localRequiredField(channel_map_in, 'surveillance_rx_label'))));

expected_channel_map = localExpectedChannelMap();
if ~isequal(channel_map, expected_channel_map)
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'baseline.channel_map does not match the frozen REF/SURV convention.');
end
end

function statistics = localNormalizeStatistics(statistics_in)
if ~(isstruct(statistics_in) && isscalar(statistics_in) && ...
        isfield(statistics_in, 'reference') && isfield(statistics_in, 'surveillance') && ...
        isfield(statistics_in, 'joint'))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'baseline.statistics must contain reference, surveillance, and joint structs.');
end

statistics = struct( ...
    'reference', localNormalizeChannelStatistics(statistics_in.reference), ...
    'surveillance', localNormalizeChannelStatistics(statistics_in.surveillance), ...
    'joint', localNormalizeJointStatistics(statistics_in.joint));
end

function channel_stats = localNormalizeChannelStatistics(channel_stats_in)
if ~(isstruct(channel_stats_in) && isscalar(channel_stats_in))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Channel statistics must be scalar structs.');
end

channel_stats = struct( ...
    'level_dbfs', localNumericField(channel_stats_in, 'level_dbfs'), ...
    'tone_peak_dbfs', localNumericField(channel_stats_in, 'tone_peak_dbfs'), ...
    'local_floor_dbfs', localNumericField(channel_stats_in, 'local_floor_dbfs'), ...
    'detect_margin_db', localNumericField(channel_stats_in, 'detect_margin_db'), ...
    'measured_frequency_hz', localNumericField(channel_stats_in, 'measured_frequency_hz'));
end

function joint_stats = localNormalizeJointStatistics(joint_stats_in)
if ~(isstruct(joint_stats_in) && isscalar(joint_stats_in))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Joint statistics must be a scalar struct.');
end

joint_stats = struct( ...
    'channel_frequency_delta_hz', localNumericField(joint_stats_in, 'channel_frequency_delta_hz'), ...
    'xcorr_lag_samples', localNumericField(joint_stats_in, 'xcorr_lag_samples'), ...
    'xcorr_lag_seconds', localNumericField(joint_stats_in, 'xcorr_lag_seconds'), ...
    'xcorr_peak_db', localNumericField(joint_stats_in, 'xcorr_peak_db'));
end

function value = localRequiredField(source_struct, field_name)
if ~isfield(source_struct, field_name)
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Required field %s is missing.', field_name);
end
value = source_struct.(field_name);
end

function value = localNumericField(source_struct, field_name)
value = double(localRequiredField(source_struct, field_name));
if ~(isscalar(value) && isfinite(value))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Field %s must be a finite scalar.', field_name);
end
end

function value = localRowVectorField(source_struct, field_name)
value = double(localRequiredField(source_struct, field_name));
if ~(isnumeric(value) && isvector(value) && ~isempty(value) && all(isfinite(value)))
    error('helperPlutoToneLoadBaseline:unsupportedSchema', ...
        'Field %s must be a finite numeric vector.', field_name);
end
value = value(:).';
end

function channel_map = localExpectedChannelMap()
channel_map = struct( ...
    'reference_label', 'REF', ...
    'reference_channel_index', 2, ...
    'reference_rx_label', 'CH2/RX2', ...
    'surveillance_label', 'SURV', ...
    'surveillance_channel_index', 1, ...
    'surveillance_rx_label', 'CH1/RX1');
end
