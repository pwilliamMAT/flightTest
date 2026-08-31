function assets = helperTriggerResolveAssets(varargin)
%HELPERTRIGGERRESOLVEASSETS Load the saved corridor and RF-budget priors.
%
% Plain-language goal:
%   Phase 1 uses a coarse likelihood proxy, not a calibrated Pd model. This
%   helper loads the saved Logan-corridor mission summary and the checked-in
%   RF budget object so the scorer can reuse that prior information without
%   inventing a new link-budget workflow.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'MissionReportPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'RFBudgetPath', "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

mission_report_path = string(opts.MissionReportPath);
rf_budget_path = string(opts.RFBudgetPath);

assets = struct( ...
    'mission_report', localLoadMissionReport(mission_report_path), ...
    'rf_budget', localLoadRFBudget(rf_budget_path));

coverage_range_m = assets.mission_report.max_coverage_km * 1e3;
if ~isfinite(coverage_range_m) || coverage_range_m <= 0
    coverage_range_m = 60e3;
end

rf_chain_scale = assets.rf_budget.chain_scale;
if ~isfinite(rf_chain_scale) || rf_chain_scale <= 0
    rf_chain_scale = 0.25;
end

assets.proxy_prior = struct( ...
    'coverage_range_m', coverage_range_m, ...
    'detection_threshold_db', assets.mission_report.detection_threshold_db, ...
    'rf_chain_scale', rf_chain_scale, ...
    'proxy_label', "proxy_only", ...
    'is_calibrated', false, ...
    'notes', "Mission summary and saved RF budget seed a coarse ranking prior only.");

end

function mission_report = localLoadMissionReport(mission_report_path)
mission_report = struct( ...
    'path', mission_report_path, ...
    'loaded', false, ...
    'range_resolution_m', NaN, ...
    'velocity_resolution_mps', NaN, ...
    'detection_threshold_db', NaN, ...
    'max_coverage_km', NaN, ...
    'range_accuracy_m', NaN, ...
    'velocity_accuracy_mps', NaN, ...
    'suppression_depth_db', NaN);

if strlength(mission_report_path) == 0 || exist(mission_report_path, 'file') ~= 2
    return
end

try
    loaded = load(mission_report_path);
catch me_load
    mission_report.notes = "Mission report load failed: " + string(me_load.message);
    return
end

if ~isfield(loaded, 'RadarReport') || ~istable(loaded.RadarReport)
    mission_report.notes = "Mission report MAT file does not contain RadarReport.";
    return
end

report_table = loaded.RadarReport;
mission_report.loaded = true;
mission_report.range_resolution_m = localMetricValue(report_table, "Range Resolution");
mission_report.velocity_resolution_mps = localMetricValue(report_table, "Velocity Resolution");
mission_report.detection_threshold_db = localMetricValue(report_table, "Detection Threshold");
mission_report.max_coverage_km = localMetricValue(report_table, "Max Coverage");
mission_report.range_accuracy_m = localMetricValue(report_table, "Range Accuracy");
mission_report.velocity_accuracy_mps = localMetricValue(report_table, "Velocity Accuracy");
mission_report.suppression_depth_db = localMetricValue(report_table, "Suppression Depth");
end

function rf_budget = localLoadRFBudget(rf_budget_path)
rf_budget = struct( ...
    'path', rf_budget_path, ...
    'loaded', false, ...
    'object_class', "", ...
    'input_frequency_hz', NaN, ...
    'final_output_power_dbm', NaN, ...
    'max_output_power_dbm', NaN, ...
    'final_nf_db', NaN, ...
    'chain_scale', NaN);

if strlength(rf_budget_path) == 0 || exist(rf_budget_path, 'file') ~= 2
    return
end

try
    loaded = load(rf_budget_path);
catch me_load
    rf_budget.notes = "RF budget load failed: " + string(me_load.message);
    return
end

if ~isfield(loaded, 'rfb')
    rf_budget.notes = "RF budget MAT file does not contain rfb.";
    return
end

rfb = loaded.rfb;
rf_budget.loaded = true;
rf_budget.object_class = string(class(rfb));

try
    rf_budget.input_frequency_hz = double(rfb.InputFrequency(1));
catch
end

try
    output_power_dbm = double(rfb.OutputPower(:));
    rf_budget.final_output_power_dbm = output_power_dbm(end);
    rf_budget.max_output_power_dbm = max(output_power_dbm);
catch
end

try
    nf_db = double(rfb.NF(:));
    rf_budget.final_nf_db = nf_db(end);
catch
end

stage_loss_db = rf_budget.max_output_power_dbm - rf_budget.final_output_power_dbm;
if isfinite(stage_loss_db)
    power_scale = max(0.15, min(1.0, 1.0 - stage_loss_db ./ 140.0));
else
    power_scale = 0.25;
end

if isfinite(rf_budget.final_nf_db)
    nf_scale = max(0.15, min(1.0, 1.0 - max(rf_budget.final_nf_db - 20.0, 0.0) ./ 140.0));
else
    nf_scale = 0.25;
end

rf_budget.chain_scale = min(power_scale, nf_scale);
end

function metric_value = localMetricValue(report_table, metric_name_fragment)
metric_value = NaN;
if ~all(ismember({'MetricNames', 'Values'}, report_table.Properties.VariableNames))
    return
end

row_mask = contains(string(report_table.MetricNames), string(metric_name_fragment), ...
    'IgnoreCase', true);
if ~any(row_mask)
    return
end

metric_value = double(report_table.Values(find(row_mask, 1, 'first')));
end
