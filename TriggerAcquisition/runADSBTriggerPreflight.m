function preflight_result = runADSBTriggerPreflight(varargin)
%RUNADSBTRIGGERPREFLIGHT Run local MATLAB pre-hardware checks for Phase 1.
%
% Example:
%   result = runADSBTriggerPreflight('Verbose', true);
%
% Public name-value groups:
%   Asset settings:
%       'MissionReportPath', 'RFBudgetPath'
%   Local wrapper settings:
%       'RadioName'
%   Output settings:
%       'PreviewOutputPath', 'SummaryOutputPath', 'ShowPreviewFigure', 'Verbose'
%
% Plain-language goal:
%   Before the testing machine starts any hardware-triggered session, this
%   helper checks that the MATLAB trigger path is intact: the existing
%   capture wrapper resolves, the saved corridor assets load, and the
%   preview map runs without warnings and writes a reviewable PNG.

repo_info = helperTriggerAddProjectPaths();
default_mission_report = fullfile(repo_info.repo_root, 'TestSetupTesting', ...
    'MissionReport_LoganCorridor.mat');
default_rf_budget = fullfile(repo_info.repo_root, 'SystemPrechecks', ...
    'RFBudget', 'DTV_RFBudgetAnalysis.mat');
default_preview_output = fullfile(tempdir, 'adsb_trigger_preflight', 'trigger_candidate_map.png');

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'MissionReportPath', default_mission_report, @(x) ischar(x) || isstring(x));
addParameter(p, 'RFBudgetPath', default_rf_budget, @(x) ischar(x) || isstring(x));
addParameter(p, 'PreviewOutputPath', default_preview_output, @(x) ischar(x) || isstring(x));
addParameter(p, 'SummaryOutputPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ShowPreviewFigure', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, varargin{:});
opts = p.Results;

preview_output_path = string(opts.PreviewOutputPath);
summary_output_path = localResolveSummaryOutputPath(opts.SummaryOutputPath, preview_output_path);

check_table = localEmptyCheckTable();
check_table = localAppendCheck(check_table, ...
    "matlab_session_started", ...
    true, ...
    "MATLAB preflight helper started successfully.");

capture_wrapper_path = which('runLocalHDTVCapture');
check_table = localAppendCheck(check_table, ...
    "capture_wrapper_on_path", ...
    ~isempty(capture_wrapper_path), ...
    localDetailOrMissing(capture_wrapper_path, 'runLocalHDTVCapture was not found on path.'));

capture_backend_path = which('log_iq_n320_2antennas');
check_table = localAppendCheck(check_table, ...
    "capture_backend_on_path", ...
    ~isempty(capture_backend_path), ...
    localDetailOrMissing(capture_backend_path, 'log_iq_n320_2antennas was not found on path.'));

[support_passed, support_detail] = localCheckSupportFunctions();
check_table = localAppendCheck(check_table, ...
    "usrp_support_functions", ...
    support_passed, ...
    support_detail);

[radio_passed, radio_detail] = localCheckRadioConfiguration(string(opts.RadioName));
check_table = localAppendCheck(check_table, ...
    "saved_radio_configuration", ...
    radio_passed, ...
    radio_detail);

[asset_passed, asset_detail, assets] = localCheckAssets( ...
    string(opts.MissionReportPath), ...
    string(opts.RFBudgetPath));
check_table = localAppendCheck(check_table, ...
    "frozen_assets_loaded", ...
    asset_passed, ...
    asset_detail);

[preview_passed, preview_detail, preview_result] = localCheckPreview( ...
    preview_output_path, ...
    logical(opts.ShowPreviewFigure));
check_table = localAppendCheck(check_table, ...
    "preview_generation_warning_free", ...
    preview_passed, ...
    preview_detail);

overall_passed = all(check_table.passed);
blocking_checks = string(check_table.check_name(~check_table.passed));
readiness_status = localResolveReadinessStatus(overall_passed);
artifacts = localWritePreflightArtifacts( ...
    summary_output_path, ...
    check_table, ...
    preview_output_path, ...
    overall_passed, ...
    readiness_status, ...
    blocking_checks);

preflight_result = struct( ...
    'overall_passed', overall_passed, ...
    'readiness_status', readiness_status, ...
    'blocking_checks', blocking_checks, ...
    'radio_name', string(opts.RadioName), ...
    'mission_report_path', string(opts.MissionReportPath), ...
    'rf_budget_path', string(opts.RFBudgetPath), ...
    'check_table', check_table, ...
    'assets', assets, ...
    'preview_result', preview_result, ...
    'artifacts', artifacts);

if opts.Verbose
    fprintf('[runADSBTriggerPreflight] Readiness ....... %s\n', char(readiness_status));
    fprintf('[runADSBTriggerPreflight] Overall pass .... %s\n', char(string(overall_passed)));
    for idx = 1:height(check_table)
        fprintf('[runADSBTriggerPreflight] %s\t%s\t%s\n', ...
            char(check_table.check_name(idx)), ...
            char(string(check_table.passed(idx))), ...
            char(check_table.detail(idx)));
    end
    fprintf('[runADSBTriggerPreflight] Summary ......... %s\n', char(artifacts.summary_txt));
end

end

function summary_output_path = localResolveSummaryOutputPath(summary_output_path, preview_output_path)
summary_output_path = string(summary_output_path);
if strlength(summary_output_path) > 0
    return
end

preview_dir = fileparts(char(preview_output_path));
summary_output_path = fullfile(preview_dir, 'trigger_preflight_summary.txt');
end

function [passed, detail] = localCheckSupportFunctions()
required_functions = [ ...
    "basebandReceiver"; ...
    "radioConfigurations"];
required_classes = [ ...
    "comm.BasebandFileReader"; ...
    "comm.BasebandFileWriter"];

missing_entries = strings(0, 1);

for idx = 1:numel(required_functions)
    function_name = required_functions(idx);
    if isempty(which(char(function_name)))
        missing_entries(end + 1, 1) = function_name; %#ok<AGROW>
    end
end

for idx = 1:numel(required_classes)
    class_name = required_classes(idx);
    if exist(char(class_name), 'class') ~= 8
        missing_entries(end + 1, 1) = class_name; %#ok<AGROW>
    end
end

passed = isempty(missing_entries);
if passed
    detail = "Support-package entrypoints for the existing wrapper were found.";
else
    detail = "Missing support-package entrypoints: " + strjoin(missing_entries, ", ");
end
end

function [passed, detail] = localCheckRadioConfiguration(radio_name)
passed = false;
detail = "";

if isempty(which('radioConfigurations'))
    detail = "radioConfigurations is not available, so saved radio names could not be checked.";
    return
end

try
    configurations = radioConfigurations;
catch me_radio
    detail = "radioConfigurations failed: " + string(me_radio.message);
    return
end

if isempty(configurations)
    detail = "No saved radio configurations were returned.";
    return
end

config_names = string({configurations.Name}).';
passed = any(config_names == radio_name);
if passed
    detail = "Saved radio configuration found: " + radio_name;
else
    detail = "Saved radio configuration not found. Available names: " + strjoin(config_names, ", ");
end
end

function [passed, detail, assets] = localCheckAssets(mission_report_path, rf_budget_path)
assets = struct();
try
    assets = helperTriggerResolveAssets( ...
        'MissionReportPath', mission_report_path, ...
        'RFBudgetPath', rf_budget_path);
catch me_assets
    passed = false;
    detail = "Asset load failed: " + string(me_assets.message);
    return
end

mission_loaded = assets.mission_report.loaded;
rf_loaded = assets.rf_budget.loaded;
passed = mission_loaded && rf_loaded;
detail = sprintf('mission=%s rfBudget=%s', ...
    char(string(mission_loaded)), ...
    char(string(rf_loaded)));
end

function [passed, detail, preview_result] = localCheckPreview(preview_output_path, show_preview_figure)
preview_result = struct();
preview_dir = fileparts(char(preview_output_path));
if strlength(string(preview_dir)) > 0 && exist(preview_dir, 'dir') ~= 7
    mkdir(preview_dir);
end

lastwarn('');
warning_message = "";
warning_id = "";

try
    preview_result = plotADSBTriggerCandidateMap( ...
        'ShowFigure', show_preview_figure, ...
        'SavePNG', true, ...
        'OutputPath', preview_output_path, ...
        'PreviewGridStep_m', 2000, ...
        'Verbose', false);
    [warning_message, warning_id] = lastwarn;
catch me_preview
    passed = false;
    detail = "Preview generation failed: " + string(me_preview.message);
    return
end

passed = preview_result.saved_png && ...
    isfile(char(preview_output_path)) && ...
    strlength(string(warning_message)) == 0 && ...
    strlength(string(warning_id)) == 0 && ...
    strlength(string(preview_result.warning_message)) == 0;

if passed
    detail = "Preview generated without warnings and saved " + preview_output_path;
else
    detail = sprintf('saved=%s warning=%s warningId=%s', ...
        char(string(preview_result.saved_png)), ...
        char(string(warning_message)), ...
        char(string(warning_id)));
end
end

function check_table = localEmptyCheckTable()
check_table = table( ...
    strings(0, 1), ...
    false(0, 1), ...
    strings(0, 1), ...
    'VariableNames', {'check_name', 'passed', 'detail'});
end

function check_table = localAppendCheck(check_table, check_name, passed, detail)
row = table( ...
    string(check_name), ...
    logical(passed), ...
    string(detail), ...
    'VariableNames', check_table.Properties.VariableNames);
check_table = [check_table; row];
end

function detail = localDetailOrMissing(path_text, missing_text)
if isempty(path_text)
    detail = string(missing_text);
else
    detail = string(path_text);
end
end

function artifacts = localWritePreflightArtifacts(summary_output_path, check_table, preview_output_path, overall_passed, readiness_status, blocking_checks)
summary_dir = fileparts(char(summary_output_path));
if strlength(string(summary_dir)) > 0 && exist(summary_dir, 'dir') ~= 7
    mkdir(summary_dir);
end

summary_lines = strings(0, 1);
summary_lines(end + 1) = "ADS-B Trigger Phase 1 Preflight";
summary_lines(end + 1) = "==============================";
summary_lines(end + 1) = "Readiness:\t" + string(readiness_status);
summary_lines(end + 1) = "Overall Pass:\t" + string(overall_passed);
summary_lines(end + 1) = "Preview PNG:\t" + string(preview_output_path);
if ~isempty(blocking_checks)
    summary_lines(end + 1) = "Blocking Checks:\t" + strjoin(blocking_checks, ", ");
end
summary_lines(end + 1) = "";

for idx = 1:height(check_table)
    summary_lines(end + 1) = sprintf('%s\t%s', ...
        char(check_table.check_name(idx)), ...
        char(string(check_table.passed(idx))));
    summary_lines(end + 1) = "  detail:\t" + check_table.detail(idx);
end

localWriteTextFile(summary_output_path, strjoin(summary_lines, newline));

artifacts = struct( ...
    'summary_txt', string(summary_output_path), ...
    'preview_png', string(preview_output_path));
end

function readiness_status = localResolveReadinessStatus(overall_passed)
if overall_passed
    readiness_status = "READY_FOR_TRIGGER_SHADOW_DRY_RUN";
else
    readiness_status = "NOT_READY_FOR_TRIGGER_HARDWARE";
end
end

function localWriteTextFile(output_path, content)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('runADSBTriggerPreflight:fileOpenFailed', ...
            'Could not open %s for writing.', output_path);
    end
    fprintf(file_id, '%s', content);
    fclose(file_id);
catch me_write
    if file_id ~= -1
        fclose(file_id);
    end
    error('runADSBTriggerPreflight:writeFailed', ...
        'Could not write %s: %s', output_path, me_write.message);
end
end
