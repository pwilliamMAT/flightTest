function result = helperPlutoToneBuildStandaloneResultFromSmoke(smoke_result, varargin)
%HELPERPLUTOTONEBUILDSTANDALONERESULTFROMSMOKE Promote a Stage 6 smoke result into the frozen standalone result schema.
%
% Plain-language goal:
%   The commissioning sweep reuses the Stage 6 smoke runner because that is
%   the proven Pluto-to-USRP path today. This helper wraps the smoke output
%   into the same saved-result schema used by the standalone precheck so
%   the artifact writer and baseline commissioning code can consume it
%   later without a second format.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'smoke_result', @isstruct);
addParameter(p, 'RunID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotFigures', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, smoke_result, varargin{:});
opts = p.Results;

settings_in = localRequiredStructField(smoke_result, 'settings');
capture_info = localRequiredStructField(smoke_result, 'capture_info');
reference_metrics = localRequiredStructField(smoke_result, 'reference_metrics');
surveillance_metrics = localRequiredStructField(smoke_result, 'surveillance_metrics');
joint_metrics = localRequiredStructField(smoke_result, 'joint_metrics');

run_id = string(opts.RunID);
if strlength(run_id) == 0
    if isfield(settings_in, 'session_id') && strlength(string(settings_in.session_id)) > 0
        run_id = string(settings_in.session_id);
    else
        run_id = "pluto_smoke_" + string(datetime( ...
            'now', ...
            'TimeZone', 'UTC', ...
            'Format', 'yyyyMMdd''T''HHmmssSSS'));
    end
end

[fail_codes, warn_codes] = localCollectCodes(reference_metrics, surveillance_metrics, joint_metrics);
status = localResolveStatus(fail_codes, warn_codes);

result = struct( ...
    'schema_version', 1, ...
    'run_id', char(run_id), ...
    'created_utc', localCreatedUTC(capture_info), ...
    'overall_pass', strcmp(status, 'PASS'), ...
    'status', status, ...
    'fail_codes', {fail_codes}, ...
    'warn_codes', {warn_codes}, ...
    'settings', localBuildSettings(settings_in, opts), ...
    'capture_info', capture_info, ...
    'channel_map', localChannelMap(), ...
    'reference_metrics', reference_metrics, ...
    'surveillance_metrics', surveillance_metrics, ...
    'joint_metrics', joint_metrics, ...
    'baseline_comparison', struct( ...
        'baseline_id', '(none)', ...
        'settings_match', false, ...
        'settings_mismatch_fields', {cell(0, 1)}, ...
        'reference_level_delta_db', localMetricField(reference_metrics, 'level_delta_vs_baseline_db'), ...
        'surveillance_level_delta_db', localMetricField(surveillance_metrics, 'level_delta_vs_baseline_db'), ...
        'comparison_applied', false), ...
    'precheck_summary', struct(), ...
    'artifact_paths', struct());

result.precheck_summary = helperPlutoToneBuildSummary(result);

if opts.Verbose
    fprintf('[helperPlutoToneBuildStandaloneResultFromSmoke] Run ID ...... %s\n', char(run_id));
    fprintf('[helperPlutoToneBuildStandaloneResultFromSmoke] Status ...... %s\n', status);
end
end

function settings = localBuildSettings(settings_in, opts)
settings = struct( ...
    'baseline_path', "", ...
    'capture_root', localTextField(settings_in, 'capture_root', ""), ...
    'radio_name', localTextField(settings_in, 'radio_name', "My USRP N320"), ...
    'capture_file_base', localTextField(settings_in, 'capture_file_base', "pluto_smoke"), ...
    'center_frequency_hz', localNumericField(settings_in, 'center_frequency_hz', NaN), ...
    'sample_rate_hz', localNumericField(settings_in, 'sample_rate_hz', NaN), ...
    'lo_offset_hz', localNumericField(settings_in, 'lo_offset_hz', NaN), ...
    'capture_tune_frequency_hz', localNumericField(settings_in, 'capture_tune_frequency_hz', NaN), ...
    'gain', localNumericRow(settings_in, 'gain'), ...
    'tone_offset_hz', localNumericField(settings_in, 'tone_offset_hz', NaN), ...
    'tone_rf_frequency_hz', localNumericField(settings_in, 'tone_rf_frequency_hz', NaN), ...
    'tone_amplitude', localNumericField(settings_in, 'tone_amplitude', NaN), ...
    'capture_duration_s', localNumericField(settings_in, 'capture_duration_s', NaN), ...
    'plot_figures', logical(opts.PlotFigures), ...
    'verbose', logical(opts.Verbose));
end

function channel_map = localChannelMap()
channel_map = struct( ...
    'reference_label', 'REF', ...
    'reference_channel_index', 2, ...
    'reference_rx_label', 'CH2/RX2', ...
    'surveillance_label', 'SURV', ...
    'surveillance_channel_index', 1, ...
    'surveillance_rx_label', 'CH1/RX1');
end

function created_utc = localCreatedUTC(capture_info)
created_utc = char(string(datetime( ...
    'now', ...
    'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));

if isstruct(capture_info) && isfield(capture_info, 'recording_utc') && isfinite(double(capture_info.recording_utc))
    created_utc = char(string(datetime( ...
        double(capture_info.recording_utc), ...
        'ConvertFrom', 'posixtime', ...
        'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
end
end

function value = localRequiredStructField(source_struct, field_name)
if ~isstruct(source_struct) || ~isfield(source_struct, field_name) || ~isstruct(source_struct.(field_name))
    error('helperPlutoToneBuildStandaloneResultFromSmoke:missingStructField', ...
        'Smoke result must contain the struct field %s.', field_name);
end

value = source_struct.(field_name);
end

function [fail_codes, warn_codes] = localCollectCodes(reference_metrics, surveillance_metrics, joint_metrics)
fail_codes = localUniqueCodes([ ...
    localCodes(reference_metrics, 'fail_codes'); ...
    localCodes(surveillance_metrics, 'fail_codes'); ...
    localCodes(joint_metrics, 'fail_codes')]);

warn_codes = localUniqueCodes([ ...
    localCodes(reference_metrics, 'warn_codes'); ...
    localCodes(surveillance_metrics, 'warn_codes'); ...
    localCodes(joint_metrics, 'warn_codes')]);
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

function value = localMetricField(metrics, field_name)
value = NaN;
if isstruct(metrics) && isfield(metrics, field_name) && ~isempty(metrics.(field_name))
    metric_value = double(metrics.(field_name));
    if isscalar(metric_value)
        value = metric_value;
    end
end
end

function value = localTextField(source_struct, field_name, default_value)
value = char(string(default_value));
if isstruct(source_struct) && isfield(source_struct, field_name) && strlength(string(source_struct.(field_name))) > 0
    value = char(string(source_struct.(field_name)));
end
end

function value = localNumericField(source_struct, field_name, default_value)
value = double(default_value);
if isstruct(source_struct) && isfield(source_struct, field_name) && ~isempty(source_struct.(field_name))
    numeric_value = double(source_struct.(field_name));
    if isscalar(numeric_value)
        value = numeric_value;
    end
end
end

function value = localNumericRow(source_struct, field_name)
value = NaN(1, 0);
if isstruct(source_struct) && isfield(source_struct, field_name) && ~isempty(source_struct.(field_name))
    value = double(source_struct.(field_name));
    value = value(:).';
end
end

function codes = localCodes(source_struct, field_name)
codes = strings(0, 1);
if isstruct(source_struct) && isfield(source_struct, field_name) && ~isempty(source_struct.(field_name))
    codes = localNormalizeCodes(source_struct.(field_name));
end
end

function codes = localNormalizeCodes(raw_codes)
if isempty(raw_codes)
    codes = strings(0, 1);
    return
end

if isstring(raw_codes)
    codes = raw_codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

if ischar(raw_codes)
    if isempty(raw_codes)
        codes = strings(0, 1);
    else
        codes = string(cellstr(raw_codes));
    end
    codes = codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

if iscell(raw_codes)
    nested_codes = cell(numel(raw_codes), 1);
    for idx = 1:numel(raw_codes)
        nested_codes{idx} = localNormalizeCodes(raw_codes{idx});
    end
    if isempty(nested_codes)
        codes = strings(0, 1);
    else
        codes = vertcat(nested_codes{:});
    end
    codes = codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

try
    codes = string(raw_codes(:));
catch
    codes = strings(0, 1);
end

codes = codes(:);
codes = codes(strlength(codes) > 0);
end

function unique_codes = localUniqueCodes(codes)
if isempty(codes)
    unique_codes = cell(0, 1);
    return
end

codes = string(codes(:));
codes = codes(strlength(codes) > 0);
codes = unique(codes, 'stable');
unique_codes = cellstr(codes);
end
