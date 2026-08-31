function comparison = helperPlutoToneCompareBaseline(baseline, runtime_settings, varargin)
%HELPERPLUTOTONECOMPAREBASELINE Compare runtime settings and metrics to a commissioned baseline.
%
% Plain-language goal:
%   The baseline is authoritative for both threshold ownership and the
%   fixed set of settings that must match before a live precheck is
%   meaningful. This helper keeps that comparison logic in one place so the
%   wrapper can fail fast before touching hardware.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'baseline', @(x) isempty(x) || isstruct(x));
addRequired(p, 'runtime_settings', @isstruct);
addParameter(p, 'ReferenceMetrics', struct(), @isstruct);
addParameter(p, 'SurveillanceMetrics', struct(), @isstruct);
parse(p, baseline, runtime_settings, varargin{:});
opts = p.Results;

baseline_id = "(none)";
settings_match = false;
settings_mismatch_fields = cell(0, 1);

if isstruct(opts.baseline) && isfield(opts.baseline, 'baseline_id')
    baseline_id = char(string(opts.baseline.baseline_id));
end

if isstruct(opts.baseline) && isfield(opts.baseline, 'settings') && isstruct(opts.baseline.settings)
    mismatch_fields = localSettingsMismatch(opts.baseline.settings, opts.runtime_settings);
    settings_match = isempty(mismatch_fields);
    settings_mismatch_fields = cellstr(mismatch_fields(:));
end

reference_level_delta_db = localMetricField(opts.ReferenceMetrics, 'level_delta_vs_baseline_db');
surveillance_level_delta_db = localMetricField(opts.SurveillanceMetrics, 'level_delta_vs_baseline_db');
comparison_applied = settings_match && ...
    (isfinite(reference_level_delta_db) || isfinite(surveillance_level_delta_db));

comparison = struct( ...
    'baseline_id', baseline_id, ...
    'settings_match', settings_match, ...
    'settings_mismatch_fields', {settings_mismatch_fields}, ...
    'reference_level_delta_db', reference_level_delta_db, ...
    'surveillance_level_delta_db', surveillance_level_delta_db, ...
    'comparison_applied', comparison_applied);
end

function mismatch_fields = localSettingsMismatch(baseline_settings, runtime_settings)
fields_to_compare = { ...
    'center_frequency_hz', ...
    'sample_rate_hz', ...
    'lo_offset_hz', ...
    'gain', ...
    'tone_offset_hz', ...
    'tone_amplitude'};

mismatch_fields = strings(0, 1);
for idx = 1:numel(fields_to_compare)
    field_name = fields_to_compare{idx};
    if ~isfield(baseline_settings, field_name) || ~isfield(runtime_settings, field_name)
        mismatch_fields(end + 1) = string(field_name); %#ok<AGROW>
        continue
    end

    baseline_value = double(baseline_settings.(field_name));
    runtime_value = double(runtime_settings.(field_name));
    if ~isequaln(size(baseline_value), size(runtime_value)) || ...
            any(abs(baseline_value(:) - runtime_value(:)) > 1e-9)
        mismatch_fields(end + 1) = string(field_name); %#ok<AGROW>
    end
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
