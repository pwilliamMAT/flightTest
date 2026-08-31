%[text] # ADS-B Trigger Phase 1 Validation Notebook
%[text] This plain-text Live Editor notebook is the lightweight Phase 1 validation entrypoint for the ADS-B-triggered capture wrapper.
%[text] - Run the MATLAB regression suite for the wrapper
%[text] - Run one standalone preview using the frozen west-facing defaults
%[text] - Run one offline replay validation against the frozen Phase 1 baseline
%[text] - Run one local pre-hardware readiness check
%[text] - Review the resulting artifact paths before any testing-machine hardware run
scriptRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptRoot);
cd(scriptRoot);
helperTriggerAddProjectPaths();
%%
%[text] ## Current Agreed Context
agreedContext = table( ...
    ["Phase 1 role"; "Capture backend"; "Default corridor"; "Default boresight"; "Single-opportunity stance"; "Baseline approval rule"], ...
    ["Wrapper-only ADS-B trigger gate"; "Reuse runLocalHDTVCapture unchanged"; "270 deg west-facing"; "270 deg west-facing"; "Remain single-opportunity"; "Any intentional delta requires explicit frozen-baseline update"], ...
    'VariableNames', ["Topic", "CurrentDecision"]);
disp(agreedContext);
%%
%[text] ## Native Function Audit For Workflow
%[text:table]
%[text] | Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
%[text] | --- | --- | --- |
%[text] | Run the trigger-wrapper regression suite | |runtests| and |matlab.unittest.TestResult| | Keep the suite read-only and treat it as the minimum gate |
%[text] | Render one standalone trigger preview | Existing repo entrypoint |plotADSBTriggerCandidateMap| | Save the PNG so the review is attached to the run |
%[text] | Compare one offline replay set against the frozen Phase 1 baseline | Existing repo entrypoint |runADSBTriggerOfflineValidation| | Use the checked-in baseline instead of manual visual comparison |
%[text] | Review generated artifacts for handoff | built-in |table|, strings, and Live Editor sections | Keep the review compact and point directly to the generated files |
%[text:table]
workflowAudit = table( ...
    ["Run the trigger-wrapper regression suite"; "Render one standalone trigger preview"; "Compare one offline replay set against the frozen Phase 1 baseline"; "Review generated artifacts for handoff"], ...
    ["runtests and matlab.unittest.TestResult"; "plotADSBTriggerCandidateMap"; "runADSBTriggerOfflineValidation"; "table, strings, and Live Editor sections"], ...
    ["Keep the suite read-only and treat it as the minimum gate"; "Save the PNG so the review is attached to the run"; "Use the checked-in baseline instead of manual visual comparison"; "Keep the review compact and point directly to the generated files"], ...
    'VariableNames', ["ProposedWorkflow", "NativeMATLABDocumentationExampleAnalogue", "UpdatesNeededToFitCurrentGoal"]);
disp(workflowAudit);
%%
%[text] ## Native Function Audit For Functions
%[text:table]
%[text] | Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
%[text] | --- | --- | --- |
%[text] | MATLAB regression execution | |runtests| | |results = runtests(""ADSBTriggeredCaptureSessionTest.m"")| |
%[text] | Preview rendering | Existing repo function |plotADSBTriggerCandidateMap| | |preview = plotADSBTriggerCandidateMap(...);| |
%[text] | Frozen baseline comparison | Existing repo function |runADSBTriggerOfflineValidation| | |validation = runADSBTriggerOfflineValidation(...);| |
%[text] | Summary tables | |table| and string arrays | |T = table(var1,var2,...);| |
%[text:table]
functionAudit = table( ...
    ["MATLAB regression execution"; "Preview rendering"; "Frozen baseline comparison"; "Summary tables"], ...
    ["runtests"; "plotADSBTriggerCandidateMap"; "runADSBTriggerOfflineValidation"; "table and string arrays"], ...
    ["results = runtests(""ADSBTriggeredCaptureSessionTest.m"")"; "preview = plotADSBTriggerCandidateMap(...);"; "validation = runADSBTriggerOfflineValidation(...);"; "T = table(var1,var2,...);"], ...
    'VariableNames', ["ProposedFeatureOrAlgorithm", "NativeMATLABFunctionOrToolboxEquivalent", "DocumentationSyntaxTemplateUsed"]);
disp(functionAudit);
%%
%[text] ## Run Controls
if ~exist('runUnitTests', 'var')
    runUnitTests = true;
end
if ~exist('runStandalonePreview', 'var')
    runStandalonePreview = true;
end
if ~exist('runOfflineValidation', 'var')
    runOfflineValidation = true;
end
if ~exist('runHardwarePreflight', 'var')
    runHardwarePreflight = true;
end
if ~exist('previewOutputPath', 'var')
    previewOutputPath = "";
end
if ~exist('validationOutputRoot', 'var')
    validationOutputRoot = "";
end
if ~exist('preflightPreviewOutputPath', 'var')
    preflightPreviewOutputPath = "";
end
controls = table( ...
    runUnitTests, ...
    runStandalonePreview, ...
    runOfflineValidation, ...
    runHardwarePreflight, ...
    string(previewOutputPath), ...
    string(validationOutputRoot), ...
    string(preflightPreviewOutputPath), ...
    'VariableNames', ["RunUnitTests", "RunStandalonePreview", "RunOfflineValidation", "RunHardwarePreflight", "PreviewOutputPath", "ValidationOutputRoot", "PreflightPreviewOutputPath"]);
disp(controls);
%%
%[text] ## MATLAB Regression Suite
unitBlock = localRunUnitBlock(runUnitTests);
localDisplayBlock(unitBlock);
%%
%[text] ## Standalone Preview
previewBlock = localRunPreviewBlock(runStandalonePreview, previewOutputPath);
localDisplayBlock(previewBlock);
%%
%[text] ## Offline Baseline Validation
offlineBlock = localRunOfflineValidationBlock(runOfflineValidation, validationOutputRoot);
localDisplayBlock(offlineBlock);
%%
%[text] ## Hardware Readiness Preflight
preflightBlock = localRunPreflightBlock(runHardwarePreflight, preflightPreviewOutputPath);
localDisplayBlock(preflightBlock);
%%
%[text] ## Review Artifacts
artifactTable = localBuildArtifactTable(unitBlock, previewBlock, offlineBlock, preflightBlock);
if height(artifactTable) > 0
    disp(artifactTable);
else
    disp("No artifact rows were produced.");
end
%%
%[text] ## Notebook Summary
summaryLines = strings(0, 1);
summaryLines(end + 1) = "ADS-B Trigger Phase 1 validation notebook completed.";
summaryLines(end + 1) = "The frozen design note lives in TriggerAcquisition/adsbTriggeredCapturePhase1DesignSpec.md.";
summaryLines(end + 1) = "Use the offline validation result as the authority for ranking, qualification, trigger, and preview-footprint deltas.";
if unitBlock.ran
    summaryLines(end + 1) = "Regression suite pass: " + string(unitBlock.passed);
end
if previewBlock.ran
    summaryLines(end + 1) = "Standalone preview PNG: " + previewBlock.artifact_path;
end
if offlineBlock.ran
    summaryLines(end + 1) = "Offline validation pass: " + string(offlineBlock.passed);
    summaryLines(end + 1) = "Offline validation summary: " + offlineBlock.artifact_path;
end
if preflightBlock.ran
    summaryLines(end + 1) = "Hardware readiness status: " + preflightBlock.readiness_status;
    if strlength(preflightBlock.blocking_checks_text) > 0
        summaryLines(end + 1) = "Hardware blockers: " + preflightBlock.blocking_checks_text;
    end
    summaryLines(end + 1) = "Preflight summary: " + preflightBlock.artifact_path;
end
localDisplaySummaryLines(summaryLines);

function block = localRunUnitBlock(run_flag)
block = struct( ...
    'label', "MATLAB Regression Suite", ...
    'ran', false, ...
    'passed', false, ...
    'summary', "", ...
    'detail', "", ...
    'artifact_path', "", ...
    'table', table());

if ~run_flag
    block.summary = "Skipped by run controls.";
    return
end

block.ran = true;
test_output = evalc('results = runtests(''ADSBTriggeredCaptureSessionTest.m'');');
passed = all([results.Passed]);
failed_count = sum([results.Failed]);
incomplete_count = sum([results.Incomplete]);
block.passed = passed;
block.summary = sprintf('passed=%s failed=%d incomplete=%d', ...
    char(string(passed)), ...
    failed_count, ...
    incomplete_count);
block.detail = "Regression suite remains the minimum gate before preflight or hardware review.";
block.artifact_path = "ADSBTriggeredCaptureSessionTest.m";
block.table = struct2table(struct( ...
    'Passed', passed, ...
    'FailedCount', failed_count, ...
    'IncompleteCount', incomplete_count, ...
    'CapturedOutputLines', numel(splitlines(string(test_output)))));
end

function block = localRunPreviewBlock(run_flag, preview_output_path)
block = struct( ...
    'label', "Standalone Preview", ...
    'ran', false, ...
    'passed', false, ...
    'summary', "", ...
    'detail', "", ...
    'artifact_path', "", ...
    'table', table());

if ~run_flag
    block.summary = "Skipped by run controls.";
    return
end

block.ran = true;
if strlength(string(preview_output_path)) == 0
    preview_output_path = fullfile(tempdir, 'adsb_trigger_phase1_validation_notebook', 'trigger_candidate_map.png');
end

preview = plotADSBTriggerCandidateMap( ...
    'ShowFigure', true, ...
    'SavePNG', true, ...
    'OutputPath', preview_output_path, ...
    'PreviewGridStep_m', 2000, ...
    'Verbose', false);

block.passed = preview.saved_png && preview.qualified_region_exists;
block.summary = sprintf('saved=%s qualifiedRegion=%s area=%.3f km^2', ...
    char(string(preview.saved_png)), ...
    char(string(preview.qualified_region_exists)), ...
    preview.qualified_area_km2);
block.detail = "Review the PNG and confirm the qualified footprint stays west-facing and excludes east-side support.";
block.artifact_path = string(preview.image_path);
block.table = struct2table(struct( ...
    'SavedPNG', preview.saved_png, ...
    'QualifiedRegionExists', preview.qualified_region_exists, ...
    'QualifiedArea_km2', preview.qualified_area_km2, ...
    'MaxTriggerScore', preview.max_trigger_score));
end

function block = localRunOfflineValidationBlock(run_flag, output_root)
block = struct( ...
    'label', "Offline Baseline Validation", ...
    'ran', false, ...
    'passed', false, ...
    'summary', "", ...
    'detail', "", ...
    'artifact_path', "", ...
    'table', table());

if ~run_flag
    block.summary = "Skipped by run controls.";
    return
end

block.ran = true;
if strlength(string(output_root)) == 0
    validation = runADSBTriggerOfflineValidation('Verbose', false);
else
    validation = runADSBTriggerOfflineValidation('OutputRoot', output_root, 'Verbose', false);
end

block.passed = validation.overall_passed;
block.summary = sprintf('overallPass=%s checks=%d', ...
    char(string(validation.overall_passed)), ...
    height(validation.summary_table));
block.detail = "Review the summary text and the generated replay/preview artifacts before changing the trigger logic or using hardware.";
block.artifact_path = validation.artifacts.validation_summary_txt;
block.table = validation.summary_table;
end

function block = localRunPreflightBlock(run_flag, preflight_preview_output_path)
block = struct( ...
    'label', "Hardware Readiness Preflight", ...
    'ran', false, ...
    'passed', false, ...
    'summary', "", ...
    'detail', "", ...
    'artifact_path', "", ...
    'table', table(), ...
    'readiness_status', "", ...
    'blocking_checks_text', "");

if ~run_flag
    block.summary = "Skipped by run controls.";
    return
end

block.ran = true;
if strlength(string(preflight_preview_output_path)) == 0
    preflight_preview_output_path = fullfile(tempdir, 'adsb_trigger_phase1_preflight_notebook', 'trigger_candidate_map.png');
end

preflight = runADSBTriggerPreflight( ...
    'PreviewOutputPath', preflight_preview_output_path, ...
    'ShowPreviewFigure', false, ...
    'Verbose', false);

block.passed = preflight.overall_passed;
block.readiness_status = string(preflight.readiness_status);
block.blocking_checks_text = strjoin(string(preflight.blocking_checks), ", ");
block.summary = sprintf('status=%s passed=%s', ...
    char(string(preflight.readiness_status)), ...
    char(string(preflight.overall_passed)));

if preflight.overall_passed
    block.detail = "Local MATLAB-side checks are ready for a trigger shadow-mode dry run on a configured machine.";
else
    if strlength(block.blocking_checks_text) > 0
        block.detail = "Blocking checks: " + block.blocking_checks_text;
    else
        block.detail = "One or more blocking preflight checks failed.";
    end
end

block.artifact_path = preflight.artifacts.summary_txt;
block.table = preflight.check_table;
end

function localDisplayBlock(block)
disp(" ");
disp(block.label + ": " + block.summary);
if strlength(string(block.detail)) > 0
    disp(block.detail);
end
if ~isempty(block.table)
    disp(block.table);
end
end

function localDisplaySummaryLines(summary_lines)
disp(" ");
disp("Notebook Summary");
disp("----------------");
for idx = 1:numel(summary_lines)
    fprintf('- %s\n', char(summary_lines(idx)));
end
end

function artifactTable = localBuildArtifactTable(unitBlock, previewBlock, offlineBlock, preflightBlock)
artifactTable = table( ...
    strings(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    'VariableNames', ["Block", "Artifact", "Purpose"]);

if unitBlock.ran
    artifactTable(end + 1, :) = { ...
        unitBlock.label, ...
        unitBlock.artifact_path, ...
        "Minimum regression gate"};
end
if previewBlock.ran
    artifactTable(end + 1, :) = { ...
        previewBlock.label, ...
        previewBlock.artifact_path, ...
        "Manual qualified-region review"};
end
if offlineBlock.ran
    artifactTable(end + 1, :) = { ...
        offlineBlock.label, ...
        offlineBlock.artifact_path, ...
        "Frozen Phase 1 replay and preview comparison"};
end
if preflightBlock.ran
    artifactTable(end + 1, :) = { ...
        preflightBlock.label, ...
        preflightBlock.artifact_path, ...
        "Local hardware-readiness gate"};
end
end
