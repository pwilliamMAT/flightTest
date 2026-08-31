function validation_result = runADSBTriggerOfflineValidation(varargin)
%RUNADSBTRIGGEROFFLINEVALIDATION Run the frozen Phase 1 offline validation set.
%
% Example:
%   result = runADSBTriggerOfflineValidation('Verbose', true);
%
% Public name-value groups:
%   Output settings:
%       'OutputRoot', 'Verbose'
%
% Plain-language goal:
%   This is the authoritative offline review path for the Phase 1 trigger
%   wrapper. It stages the frozen ADS-B replay cases, runs the existing
%   session and preview entrypoints, compares them against the checked-in
%   baseline, and writes reviewable artifacts before anyone uses hardware.

repo_info = helperTriggerAddProjectPaths();
default_output_root = fullfile(tempdir, ...
    "adsb_trigger_phase1_validation_" + string(datetime('now', ...
    'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss')));

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'OutputRoot', default_output_root, @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, varargin{:});
opts = p.Results;

baseline = helperTriggerPhase1FrozenBaseline();
output_root = string(opts.OutputRoot);
reference_time_utc = datetime('now', 'TimeZone', 'UTC');

if exist(output_root, 'dir') ~= 7
    mkdir(output_root);
end

summary_table = localEmptySummaryTable();

positive_case = localRunShadowReplayCase( ...
    output_root, ...
    baseline.shadow_positive, ...
    reference_time_utc, ...
    opts.Verbose);
[positive_passed, positive_delta] = localCompareShadowReplay( ...
    positive_case.session_result, ...
    baseline.shadow_positive, ...
    baseline.score_tolerance);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "west_shadow_replay", ...
    positive_passed, ...
    localShadowObservedText(positive_case.session_result), ...
    localShadowExpectedText(baseline.shadow_positive), ...
    positive_delta, ...
    positive_case.session_result.artifacts.trigger_summary_txt);

negative_case = localRunShadowReplayCase( ...
    output_root, ...
    baseline.shadow_negative, ...
    reference_time_utc, ...
    opts.Verbose);
[negative_passed, negative_delta] = localCompareShadowReplay( ...
    negative_case.session_result, ...
    baseline.shadow_negative, ...
    baseline.score_tolerance);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "east_decoy_replay", ...
    negative_passed, ...
    localShadowObservedText(negative_case.session_result), ...
    localShadowExpectedText(baseline.shadow_negative), ...
    negative_delta, ...
    negative_case.session_result.artifacts.trigger_summary_txt);

default_preview_case = localRunDefaultPreviewCase(output_root, opts.Verbose);
[default_preview_passed, default_preview_delta] = localCompareDefaultPreview( ...
    default_preview_case.preview, ...
    baseline.default_preview, ...
    baseline.preview_tolerance);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "default_preview", ...
    default_preview_passed, ...
    localDefaultPreviewObservedText(default_preview_case.preview), ...
    localDefaultPreviewExpectedText(baseline.default_preview), ...
    default_preview_delta, ...
    default_preview_case.preview.image_path);

empty_preview_case = localRunEmptyPreviewCase(output_root, opts.Verbose);
[empty_preview_passed, empty_preview_delta] = localCompareEmptyPreview( ...
    empty_preview_case.preview, ...
    baseline.empty_preview, ...
    baseline.preview_tolerance);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "empty_preview", ...
    empty_preview_passed, ...
    localEmptyPreviewObservedText(empty_preview_case.preview), ...
    localEmptyPreviewExpectedText(baseline.empty_preview), ...
    empty_preview_delta, ...
    empty_preview_case.preview.image_path);

override_preview_case = localRunExplicitOverridePreviewCase(output_root, opts.Verbose);
[override_passed, override_delta] = localCompareExplicitOverridePreview( ...
    override_preview_case.preview, ...
    baseline.explicit_azimuth_override, ...
    baseline.preview_tolerance);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "explicit_override_preview", ...
    override_passed, ...
    localExplicitOverrideObservedText(override_preview_case.preview), ...
    localExplicitOverrideExpectedText(baseline.explicit_azimuth_override), ...
    override_delta, ...
    override_preview_case.preview.image_path);

shell_case = localRunShellWrapperCheck(repo_info.trigger_root);
[shell_passed, shell_delta] = localCompareShellWrapper( ...
    shell_case.script_text, ...
    baseline.shell_wrapper);
summary_table = localAppendSummaryRow( ...
    summary_table, ...
    "shell_wrapper_contract", ...
    shell_passed, ...
    "Shell wrapper snippets present", ...
    "Preflight and explicit azimuth snippets are checked in", ...
    shell_delta, ...
    shell_case.script_path);

overall_passed = all(summary_table.passed);

artifacts = localWriteValidationArtifacts( ...
    output_root, ...
    summary_table, ...
    baseline, ...
    overall_passed, ...
    reference_time_utc);

validation_result = struct( ...
    'baseline_id', baseline.baseline_id, ...
    'approval_rule', baseline.approval_rule, ...
    'reference_time_utc', reference_time_utc, ...
    'output_root', output_root, ...
    'overall_passed', overall_passed, ...
    'summary_table', summary_table, ...
    'artifacts', artifacts, ...
    'cases', struct( ...
        'west_shadow_replay', positive_case, ...
        'east_decoy_replay', negative_case, ...
        'default_preview', default_preview_case, ...
        'empty_preview', empty_preview_case, ...
        'explicit_override_preview', override_preview_case, ...
        'shell_wrapper', shell_case));

save(char(artifacts.validation_result_mat), 'validation_result', '-v7.3');

if opts.Verbose
    fprintf('[runADSBTriggerOfflineValidation] Baseline ........ %s\n', char(baseline.baseline_id));
    fprintf('[runADSBTriggerOfflineValidation] Output root ..... %s\n', char(output_root));
    fprintf('[runADSBTriggerOfflineValidation] Overall pass .... %s\n', char(string(overall_passed)));
    fprintf('[runADSBTriggerOfflineValidation] Summary text .... %s\n', char(artifacts.validation_summary_txt));
end

end

function case_result = localRunShadowReplayCase(output_root, replay_baseline, reference_time_utc, verbose)
case_name = string(replay_baseline.scenario_name);
case_root = fullfile(output_root, case_name);
session_root = fullfile(case_root, 'captures');
stage_dir = fullfile(case_root, 'adsb_stage');
session_id = "phase1_" + case_name;

if exist(session_root, 'dir') ~= 7
    mkdir(session_root);
end
if exist(stage_dir, 'dir') ~= 7
    mkdir(stage_dir);
end

scenario_info = helperTriggerWriteValidationScenario( ...
    stage_dir, ...
    session_id, ...
    'Scenario', case_name, ...
    'ReferenceTimeUTC', reference_time_utc, ...
    'Verbose', false);

session_result = runADSBTriggeredCaptureSession( ...
    'SessionID', session_id, ...
    'SessionRoot', session_root, ...
    'ADSBStageDir', stage_dir, ...
    'Mode', 'shadow', ...
    'ShowTriggerPreviewMap', false, ...
    'SaveTriggerPreviewMap', false, ...
    'MinConsecutiveQualifiedPolls', 1, ...
    'WatchTimeout_s', 0.05, ...
    'PollPeriod_s', 0.01, ...
    'TailSeconds_s', 0, ...
    'Verbose', false);

case_result = struct( ...
    'scenario_info', scenario_info, ...
    'session_root', string(session_root), ...
    'stage_dir', string(stage_dir), ...
    'session_result', session_result);

if verbose
    fprintf('[runADSBTriggerOfflineValidation] Replay case ..... %s\t%s\n', ...
        char(case_name), ...
        char(session_result.final_status));
end
end

function case_result = localRunDefaultPreviewCase(output_root, verbose)
preview_path = fullfile(output_root, 'default_preview', 'trigger_candidate_map.png');
preview_dir = fileparts(preview_path);
if exist(preview_dir, 'dir') ~= 7
    mkdir(preview_dir);
end

preview = plotADSBTriggerCandidateMap( ...
    'ShowFigure', false, ...
    'SavePNG', true, ...
    'OutputPath', preview_path, ...
    'PreviewGridStep_m', 2000, ...
    'Verbose', false);

case_result = struct( ...
    'preview', preview);

if verbose
    fprintf('[runADSBTriggerOfflineValidation] Default preview . %s\n', char(preview.image_path));
end
end

function case_result = localRunEmptyPreviewCase(output_root, verbose)
preview_path = fullfile(output_root, 'empty_preview', 'trigger_candidate_map.png');
preview_dir = fileparts(preview_path);
if exist(preview_dir, 'dir') ~= 7
    mkdir(preview_dir);
end

preview = plotADSBTriggerCandidateMap( ...
    'ShowFigure', false, ...
    'SavePNG', true, ...
    'OutputPath', preview_path, ...
    'AltitudeBand_m', [1000, 2000], ...
    'PreviewAltitude_m', 5000, ...
    'PreviewGridStep_m', 2000, ...
    'Verbose', false);

case_result = struct( ...
    'preview', preview);

if verbose
    fprintf('[runADSBTriggerOfflineValidation] Empty preview ... %s\n', char(preview.image_path));
end
end

function case_result = localRunExplicitOverridePreviewCase(output_root, verbose)
preview_path = fullfile(output_root, 'explicit_override_preview', 'trigger_candidate_map.png');
preview_dir = fileparts(preview_path);
if exist(preview_dir, 'dir') ~= 7
    mkdir(preview_dir);
end

preview = plotADSBTriggerCandidateMap( ...
    'ShowFigure', false, ...
    'SavePNG', true, ...
    'OutputPath', preview_path, ...
    'CorridorAzimuthCenter_deg', 270.0, ...
    'SurveillanceBoresightAzimuth_deg', 255.0, ...
    'CorridorReferenceLLA', [42.3656, -71.0096, 10.0], ...
    'PreviewGridStep_m', 2000, ...
    'Verbose', false);

case_result = struct( ...
    'preview', preview);

if verbose
    fprintf('[runADSBTriggerOfflineValidation] Override preview  %s\n', char(preview.image_path));
end
end

function shell_case = localRunShellWrapperCheck(trigger_root)
script_path = fullfile(trigger_root, 'run_adsb_triggered_hdtv_capture.sh');
shell_case = struct( ...
    'script_path', string(script_path), ...
    'script_text', string(fileread(script_path)));
end

function [passed, delta_summary] = localCompareShadowReplay(session_result, replay_baseline, tolerance)
passed = true;
delta_lines = strings(0, 1);

actual_hex = string(session_result.candidate_table.hex);
actual_qualified = logical(session_result.candidate_table.qualified);
actual_hard_gate = logical(session_result.candidate_table.hard_gate_pass);
actual_corridor_gate = logical(session_result.candidate_table.corridor_gate_pass);
actual_boresight_gate = logical(session_result.candidate_table.boresight_gate_pass);
actual_trigger_score = double(session_result.candidate_table.trigger_score);
actual_geometry_score = double(session_result.candidate_table.geometry_score);
actual_rf_proxy_score = double(session_result.candidate_table.rf_proxy_score);
actual_predicted_offset = double(session_result.candidate_table.predicted_start_offset_s);

if string(session_result.final_status) ~= string(replay_baseline.expected_final_status)
    passed = false;
    delta_lines(end + 1) = "Final status changed.";
end
if logical(session_result.trigger_fired) ~= logical(replay_baseline.expected_trigger_fired)
    passed = false;
    delta_lines(end + 1) = "Trigger/no-trigger decision changed.";
end
if ~isequal(actual_hex(:), string(replay_baseline.expected_candidate_hex(:)))
    passed = false;
    delta_lines(end + 1) = "Candidate ranking changed.";
end
if ~isequal(actual_qualified(:), logical(replay_baseline.expected_qualified(:)))
    passed = false;
    delta_lines(end + 1) = "Qualification flags changed.";
end
if ~isequal(actual_hard_gate(:), logical(replay_baseline.expected_hard_gate_pass(:)))
    passed = false;
    delta_lines(end + 1) = "Hard-gate results changed.";
end
if ~isequal(actual_corridor_gate(:), logical(replay_baseline.expected_corridor_gate_pass(:)))
    passed = false;
    delta_lines(end + 1) = "Corridor-gate results changed.";
end
if ~isequal(actual_boresight_gate(:), logical(replay_baseline.expected_boresight_gate_pass(:)))
    passed = false;
    delta_lines(end + 1) = "Boresight-gate results changed.";
end
if any(abs(actual_trigger_score(:) - double(replay_baseline.expected_trigger_score(:))) > tolerance)
    passed = false;
    delta_lines(end + 1) = "Trigger scores changed.";
end
if any(abs(actual_geometry_score(:) - double(replay_baseline.expected_geometry_score(:))) > tolerance)
    passed = false;
    delta_lines(end + 1) = "Geometry scores changed.";
end
if any(abs(actual_rf_proxy_score(:) - double(replay_baseline.expected_rf_proxy_score(:))) > tolerance)
    passed = false;
    delta_lines(end + 1) = "RF proxy scores changed.";
end
if any(abs(actual_predicted_offset(:) - double(replay_baseline.expected_predicted_start_offset_s(:))) > tolerance)
    passed = false;
    delta_lines(end + 1) = "Predicted start offsets changed.";
end

if isempty(delta_lines)
    delta_lines(end + 1) = "Matches frozen Phase 1 replay baseline.";
end
delta_summary = strjoin(delta_lines, " ");
end

function [passed, delta_summary] = localCompareDefaultPreview(preview, preview_baseline, tolerance)
passed = true;
delta_lines = strings(0, 1);

actual_linear_idx = find(preview.qualified_grid(:));
expected_linear_idx = localExpandLinearRuns(preview_baseline.expected_qualified_linear_runs);
qualified_east_axis = preview.east_axis_m(any(preview.qualified_grid, 1));

if logical(preview.qualified_region_exists) ~= logical(preview_baseline.expected_qualified_region_exists)
    passed = false;
    delta_lines(end + 1) = "Qualified-region existence changed.";
end
if abs(double(preview.qualified_area_km2) - double(preview_baseline.expected_qualified_area_km2)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Qualified-area footprint changed.";
end
if abs(double(preview.max_trigger_score) - double(preview_baseline.expected_max_trigger_score)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Preview max trigger score changed.";
end
if nnz(preview.qualified_grid) ~= double(preview_baseline.expected_qualified_count)
    passed = false;
    delta_lines(end + 1) = "Qualified-cell count changed.";
end
if isempty(qualified_east_axis)
    actual_max_qualified_east_m = NaN;
else
    actual_max_qualified_east_m = max(qualified_east_axis);
end
if abs(actual_max_qualified_east_m - double(preview_baseline.expected_max_qualified_east_m)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Qualified east-support changed.";
end
if ~isequal(actual_linear_idx(:), expected_linear_idx(:))
    passed = false;
    delta_lines(end + 1) = "Qualified-grid footprint changed.";
end
if abs(double(preview.config_summary.corridor_azimuth_center_deg) - ...
        double(preview_baseline.expected_corridor_azimuth_center_deg)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Preview corridor azimuth changed.";
end
if abs(double(preview.config_summary.boresight_azimuth_deg) - ...
        double(preview_baseline.expected_boresight_azimuth_deg)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Preview boresight azimuth changed.";
end

if isempty(delta_lines)
    delta_lines(end + 1) = "Matches frozen Phase 1 preview footprint.";
end
delta_summary = strjoin(delta_lines, " ");
end

function [passed, delta_summary] = localCompareEmptyPreview(preview, preview_baseline, tolerance)
passed = true;
delta_lines = strings(0, 1);

if logical(preview.qualified_region_exists) ~= logical(preview_baseline.expected_qualified_region_exists)
    passed = false;
    delta_lines(end + 1) = "Empty-region existence changed.";
end
if abs(double(preview.qualified_area_km2) - double(preview_baseline.expected_qualified_area_km2)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Empty-region area changed.";
end
if string(preview.qualified_region_message) ~= string(preview_baseline.expected_qualified_region_message)
    passed = false;
    delta_lines(end + 1) = "Empty-region message changed.";
end
if any(preview.qualified_grid(:))
    passed = false;
    delta_lines(end + 1) = "Empty-region footprint is no longer empty.";
end

if isempty(delta_lines)
    delta_lines(end + 1) = "Matches frozen empty preview behavior.";
end
delta_summary = strjoin(delta_lines, " ");
end

function [passed, delta_summary] = localCompareExplicitOverridePreview(preview, override_baseline, tolerance)
passed = true;
delta_lines = strings(0, 1);

if abs(double(preview.config_summary.corridor_azimuth_center_deg) - ...
        double(override_baseline.expected_corridor_azimuth_center_deg)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Explicit corridor override changed.";
end
if abs(double(preview.config_summary.boresight_azimuth_deg) - ...
        double(override_baseline.expected_boresight_azimuth_deg)) > tolerance
    passed = false;
    delta_lines(end + 1) = "Explicit boresight override changed.";
end

if isempty(delta_lines)
    delta_lines(end + 1) = "Matches explicit override precedence baseline.";
end
delta_summary = strjoin(delta_lines, " ");
end

function [passed, delta_summary] = localCompareShellWrapper(script_text, shell_baseline)
passed = true;
delta_lines = strings(0, 1);

for idx = 1:numel(shell_baseline.required_snippets)
    snippet = string(shell_baseline.required_snippets(idx));
    if ~contains(script_text, snippet)
        passed = false;
        delta_lines(end + 1) = "Missing snippet: " + snippet;
    end
end

if isempty(delta_lines)
    delta_lines(end + 1) = "Shell wrapper still exposes the frozen Phase 1 contract.";
end
delta_summary = strjoin(delta_lines, " ");
end

function summary_table = localEmptySummaryTable()
summary_table = table( ...
    strings(0, 1), ...
    false(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    'VariableNames', { ...
        'check_name', ...
        'passed', ...
        'observed', ...
        'expected', ...
        'delta_summary', ...
        'artifact_path'});
end

function summary_table = localAppendSummaryRow(summary_table, check_name, passed, observed, expected, delta_summary, artifact_path)
row = table( ...
    string(check_name), ...
    logical(passed), ...
    string(observed), ...
    string(expected), ...
    string(delta_summary), ...
    string(artifact_path), ...
    'VariableNames', summary_table.Properties.VariableNames);
summary_table = [summary_table; row];
end

function text_out = localShadowObservedText(session_result)
text_out = sprintf('status=%s hex=%s qualified=%s', ...
    char(string(session_result.final_status)), ...
    char(strjoin(string(session_result.candidate_table.hex), ",")), ...
    char(mat2str(logical(session_result.candidate_table.qualified.'))));
end

function text_out = localShadowExpectedText(replay_baseline)
text_out = sprintf('status=%s hex=%s qualified=%s', ...
    char(string(replay_baseline.expected_final_status)), ...
    char(strjoin(string(replay_baseline.expected_candidate_hex), ",")), ...
    char(mat2str(logical(replay_baseline.expected_qualified.'))));
end

function text_out = localDefaultPreviewObservedText(preview)
qualified_east_axis = preview.east_axis_m(any(preview.qualified_grid, 1));
if isempty(qualified_east_axis)
    max_qualified_east_m = NaN;
else
    max_qualified_east_m = max(qualified_east_axis);
end

text_out = sprintf('area=%.3f km^2 max=%.6f east=%.3f m', ...
    preview.qualified_area_km2, ...
    preview.max_trigger_score, ...
    max_qualified_east_m);
end

function text_out = localDefaultPreviewExpectedText(preview_baseline)
text_out = sprintf('area=%.3f km^2 max=%.6f east=%.3f m', ...
    preview_baseline.expected_qualified_area_km2, ...
    preview_baseline.expected_max_trigger_score, ...
    preview_baseline.expected_max_qualified_east_m);
end

function text_out = localEmptyPreviewObservedText(preview)
text_out = sprintf('exists=%s area=%.3f km^2', ...
    char(string(preview.qualified_region_exists)), ...
    preview.qualified_area_km2);
end

function text_out = localEmptyPreviewExpectedText(preview_baseline)
text_out = sprintf('exists=%s area=%.3f km^2', ...
    char(string(preview_baseline.expected_qualified_region_exists)), ...
    preview_baseline.expected_qualified_area_km2);
end

function text_out = localExplicitOverrideObservedText(preview)
text_out = sprintf('corridor=%.1f deg boresight=%.1f deg', ...
    preview.config_summary.corridor_azimuth_center_deg, ...
    preview.config_summary.boresight_azimuth_deg);
end

function text_out = localExplicitOverrideExpectedText(override_baseline)
text_out = sprintf('corridor=%.1f deg boresight=%.1f deg', ...
    override_baseline.expected_corridor_azimuth_center_deg, ...
    override_baseline.expected_boresight_azimuth_deg);
end

function expanded_idx = localExpandLinearRuns(run_pairs)
expanded_idx = zeros(0, 1);
for idx = 1:size(run_pairs, 1)
    expanded_idx = [expanded_idx; (run_pairs(idx, 1):run_pairs(idx, 2)).']; %#ok<AGROW>
end
end

function artifacts = localWriteValidationArtifacts(output_root, summary_table, baseline, overall_passed, reference_time_utc)
summary_txt = fullfile(output_root, 'validation_summary.txt');
summary_csv = fullfile(output_root, 'validation_summary.csv');
result_mat = fullfile(output_root, 'validation_result.mat');

summary_lines = strings(0, 1);
summary_lines(end + 1) = "ADS-B Trigger Phase 1 Offline Validation";
summary_lines(end + 1) = "=====================================";
summary_lines(end + 1) = "Baseline ID:\t" + string(baseline.baseline_id);
summary_lines(end + 1) = "Reference Time UTC:\t" + string(reference_time_utc);
summary_lines(end + 1) = "Overall Pass:\t" + string(overall_passed);
summary_lines(end + 1) = "Approval Rule:\t" + string(baseline.approval_rule);
summary_lines(end + 1) = "";

for idx = 1:height(summary_table)
    summary_lines(end + 1) = sprintf('%s\t%s', ...
        char(summary_table.check_name(idx)), ...
        char(string(summary_table.passed(idx))));
    summary_lines(end + 1) = "  observed:\t" + summary_table.observed(idx);
    summary_lines(end + 1) = "  expected:\t" + summary_table.expected(idx);
    summary_lines(end + 1) = "  delta:\t" + summary_table.delta_summary(idx);
    if strlength(summary_table.artifact_path(idx)) > 0
        summary_lines(end + 1) = "  artifact:\t" + summary_table.artifact_path(idx);
    end
    summary_lines(end + 1) = "";
end

localWriteTextFile(summary_txt, strjoin(summary_lines, newline));
writetable(summary_table, summary_csv);

artifacts = struct( ...
    'validation_summary_txt', string(summary_txt), ...
    'validation_summary_csv', string(summary_csv), ...
    'validation_result_mat', string(result_mat));
end

function localWriteTextFile(output_path, content)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('runADSBTriggerOfflineValidation:fileOpenFailed', ...
            'Could not open %s for writing.', output_path);
    end
    fprintf(file_id, '%s', content);
    fclose(file_id);
catch me_write
    if file_id ~= -1
        fclose(file_id);
    end
    error('runADSBTriggerOfflineValidation:writeFailed', ...
        'Could not write %s: %s', output_path, me_write.message);
end
end
