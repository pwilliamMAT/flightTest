function capturePlan = helperBuildStage4ADSBTruthCapturePlan(varargin)
%HELPERBUILDSTAGE4ADSBTRUTHCAPTUREPLAN Build Stage 4A capture plan data.
% Stage 4A is a planning checkpoint. It loads the Stage 3B aggregate
% evaluation and converts the data gaps into plot-ready arrays for a
% question-driven ADS-B-only truth capture review.

projectRoot = fileparts(mfilename("fullpath"));
defaultStage3BArtifactPath = fullfile( ...
    projectRoot, ...
    "artifacts", ...
    "stage3B", ...
    "localADSBAggregateStage3BEvaluation.mat");
defaultStage3CArtifactPath = fullfile( ...
    projectRoot, ...
    "artifacts", ...
    "stage3C", ...
    "stage3CArchiveADSBEvaluation.mat");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ProjectRoot", projectRoot);
addParameter(parser, "Stage3BArtifactPath", defaultStage3BArtifactPath);
addParameter(parser, "Stage3CArtifactPath", defaultStage3CArtifactPath);
addParameter(parser, "RecommendedCaptureTargets", localDefaultRecommendedCaptureTargets());
addParameter(parser, "MotionCoverageTargets", localDefaultMotionCoverageTargets());
parse(parser, varargin{:});

config = struct();
config.ProjectRoot = string(parser.Results.ProjectRoot);
config.Stage3BArtifactPath = string(parser.Results.Stage3BArtifactPath);
config.Stage3CArtifactPath = string(parser.Results.Stage3CArtifactPath);
config.RecommendedCaptureTargets = parser.Results.RecommendedCaptureTargets;
config.MotionCoverageTargets = parser.Results.MotionCoverageTargets;

localValidateTargetStruct(config.RecommendedCaptureTargets, localRecommendedTargetFields());
localValidateTargetStruct(config.MotionCoverageTargets, localMotionTargetFields());

[stage3BSummary, stage3CSummary, hasStage3C] = localLoadStageSummaries(config);

readinessGateTable = localBuildReadinessGatePlotTable( ...
    stage3BSummary.dataReadiness.gateTable, ...
    config.RecommendedCaptureTargets);
motionCoverageTable = localBuildMotionCoverageTable( ...
    stage3BSummary, ...
    config.MotionCoverageTargets);
rmseByManeuverClass = localBuildRmseComparisonTable( ...
    stage3BSummary.metrics.byManeuverClass, ...
    "maneuverClass");
rmseByUpdateRegime = localBuildRmseComparisonTable( ...
    stage3BSummary.metrics.byDtRegime, ...
    "dtRegime");
splitCoverage = localBuildSplitCoverage(stage3BSummary.pairErrorTable);
sourceCoverageTable = localBuildSourceCoverageTable( ...
    stage3BSummary, ...
    stage3CSummary, ...
    hasStage3C);
receiverMetadataTable = localBuildReceiverMetadataTable( ...
    stage3BSummary, ...
    stage3CSummary, ...
    hasStage3C);
collectionPriorityTable = localBuildCollectionPriorityTable( ...
    stage3BSummary, ...
    sourceCoverageTable, ...
    receiverMetadataTable, ...
    config.MotionCoverageTargets, ...
    hasStage3C);
captureProgressTable = localBuildCaptureProgressTable( ...
    stage3BSummary.dataReadiness, ...
    config.RecommendedCaptureTargets, ...
    readinessGateTable);
summary = localBuildSummary( ...
    stage3BSummary, ...
    stage3CSummary, ...
    hasStage3C, ...
    readinessGateTable, ...
    captureProgressTable, ...
    sourceCoverageTable, ...
    receiverMetadataTable, ...
    collectionPriorityTable);

capturePlan = struct();
capturePlan.generatedAt = datetime("now", "TimeZone", "UTC");
capturePlan.projectRoot = config.ProjectRoot;
capturePlan.stage3BArtifactPath = config.Stage3BArtifactPath;
capturePlan.stage3CArtifactPath = config.Stage3CArtifactPath;
capturePlan.hasStage3C = hasStage3C;
capturePlan.stage3BReportPath = string(stage3BSummary.reportPath);
capturePlan.stage3CReportPath = localStage3CReportPath(stage3CSummary, hasStage3C);
capturePlan.captureCommandTemplate = ...
    "sudo ./start_adsb_gps_loggers.sh --adsb-only --adsb-session-id <session_id> --adsb-run-seconds 900";
capturePlan.truthFolderLayout = ...
    "BistaticDataAnalysis/captures/<session_id>/truth/*adsb_<session_id>*.txt.gz";
capturePlan.requiredMetadataLayout = ...
    "BistaticDataAnalysis/captures/<session_id>/session_manifest.json with receiver LLA metadata";
capturePlan.config = config;
capturePlan.summary = summary;
capturePlan.readinessGateTable = readinessGateTable;
capturePlan.motionCoverageTable = motionCoverageTable;
capturePlan.rmseByManeuverClass = rmseByManeuverClass;
capturePlan.rmseByUpdateRegime = rmseByUpdateRegime;
capturePlan.splitCoverage = splitCoverage;
capturePlan.sourceCoverageTable = sourceCoverageTable;
capturePlan.receiverMetadataTable = receiverMetadataTable;
capturePlan.collectionPriorityTable = collectionPriorityTable;
capturePlan.captureProgressTable = captureProgressTable;
capturePlan.stage3BSummary = stage3BSummary;
capturePlan.stage3CSummary = stage3CSummary;

end

function targets = localDefaultRecommendedCaptureTargets()
%LOCALDEFAULTRECOMMENDEDCAPTURETARGETS Return Stage 4A campaign goals.

targets = struct();
targets.sessionCount = 5;
targets.sourceFileCount = 5;
targets.aircraftTrackCount = 30;
targets.turnLikePairCount = 200;
targets.sparseUpdatePairCount = 200;
targets.piOnlyTruthFileCount = 1;
targets.sourceDiversityRoleCount = 2;
targets.passiveRadarGeometryWindowCount = 1;

end

function targets = localDefaultMotionCoverageTargets()
%LOCALDEFAULTMOTIONCOVERAGETARGETS Return motion-regime planning targets.

targets = struct();
targets.constvelLikePairCount = 1000;
targets.constaccLikePairCount = 200;
targets.constturnLikePairCount = 200;
targets.mixedOrSparsePairCount = 200;
targets.climbPairCount = 200;
targets.descentPairCount = 200;
targets.sparseUpdatePairCount = 200;

end

function fieldNames = localRecommendedTargetFields()
%LOCALRECOMMENDEDTARGETFIELDS Required campaign target fields.

fieldNames = [ ...
    "sessionCount", ...
    "sourceFileCount", ...
    "aircraftTrackCount", ...
    "turnLikePairCount", ...
    "sparseUpdatePairCount", ...
    "piOnlyTruthFileCount", ...
    "sourceDiversityRoleCount", ...
    "passiveRadarGeometryWindowCount"];

end

function fieldNames = localMotionTargetFields()
%LOCALMOTIONTARGETFIELDS Required motion coverage target fields.

fieldNames = [ ...
    "constvelLikePairCount", ...
    "constaccLikePairCount", ...
    "constturnLikePairCount", ...
    "mixedOrSparsePairCount", ...
    "climbPairCount", ...
    "descentPairCount", ...
    "sparseUpdatePairCount"];

end

function localValidateTargetStruct(targets, requiredFields)
%LOCALVALIDATETARGETSTRUCT Validate numeric target fields.

if ~isstruct(targets)
    error("Stage4A:InvalidTargets", ...
        "Target configuration must be a scalar struct.");
end

for fieldIdx = 1:numel(requiredFields)
    fieldName = requiredFields(fieldIdx);

    if ~isfield(targets, fieldName)
        error("Stage4A:MissingTargetField", ...
            "Target configuration is missing field: %s", fieldName);
    end

    validateattributes(targets.(fieldName), {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, ...
        mfilename, fieldName);
end

end

function [stage3BSummary, stage3CSummary, hasStage3C] = localLoadStageSummaries(config)
%LOCALLOADSTAGESUMMARIES Prefer Stage 3C and preserve Stage 3B fallback.

[stage3CSummary, hasStage3C] = localLoadStage3CSummaryIfAvailable( ...
    config.Stage3CArtifactPath);

if hasStage3C
    stage3BSummary = stage3CSummary.stage3BSummary;
    localValidateStage3BSummary(stage3BSummary);
    return;
end

stage3BSummary = localLoadStage3BSummary(config.Stage3BArtifactPath);
stage3CSummary = struct();

end

function [stage3CSummary, hasStage3C] = localLoadStage3CSummaryIfAvailable(artifactPath)
%LOCALLOADSTAGE3CSUMMARYIFAVAILABLE Load Stage 3C when available.

stage3CSummary = struct();
hasStage3C = false;

if exist(artifactPath, "file") ~= 2
    return;
end

try
    loaded = load(artifactPath, "stage3CSummary");
catch
    return;
end

if ~isfield(loaded, "stage3CSummary")
    return;
end

candidateSummary = loaded.stage3CSummary;
requiredFields = [ ...
    "archiveSummary", ...
    "archiveInventory", ...
    "stage3BSummary", ...
    "reportPath"];

if ~localHasFields(candidateSummary, requiredFields)
    return;
end

stage3CSummary = candidateSummary;
hasStage3C = true;

end

function localValidateStage3BSummary(stage3BSummary)
%LOCALVALIDATESTAGE3BSUMMARY Verify required Stage 3B fields.

requiredFields = [ ...
    "dataReadiness", ...
    "metrics", ...
    "pairErrorTable", ...
    "reportPath"];

if ~localHasFields(stage3BSummary, requiredFields)
    missingFields = requiredFields(~isfield(stage3BSummary, requiredFields));
    error("Stage4A:InvalidStage3BArtifact", ...
        "Stage 3B summary is missing field: %s", missingFields(1));
end

end

function tf = localHasFields(inputStruct, requiredFields)
%LOCALHASFIELDS Return true when all required fields are present.

tf = isstruct(inputStruct);

if ~tf
    return;
end

for fieldIdx = 1:numel(requiredFields)
    tf = tf && isfield(inputStruct, requiredFields(fieldIdx));
end

end
function stage3BSummary = localLoadStage3BSummary(artifactPath)
%LOCALLOADSTAGE3BSUMMARY Load the saved Stage 3B checkpoint artifact.

if exist(artifactPath, "file") ~= 2
    error("Stage4A:MissingStage3BArtifact", ...
        "Stage 3B artifact was not found: %s", artifactPath);
end

try
    loaded = load(artifactPath, "stage3BSummary");
catch err
    error("Stage4A:Stage3BLoadFailed", ...
        "Failed to load Stage 3B artifact: %s", err.message);
end

if ~isfield(loaded, "stage3BSummary")
    error("Stage4A:MissingStage3BSummary", ...
        "The Stage 3B artifact does not contain stage3BSummary.");
end

stage3BSummary = loaded.stage3BSummary;
localValidateStage3BSummary(stage3BSummary);

end

function readinessGateTable = localBuildReadinessGatePlotTable(gateTable, targets)
%LOCALBUILDREADINESSGATEPLOTTABLE Add recommended targets and shortfalls.

readinessGateTable = gateTable;
gateNames = string(readinessGateTable.gate);
recommendedValue = readinessGateTable.requiredValue;

recommendedValue(gateNames == "distinct ADS-B sessions") = targets.sessionCount;
recommendedValue(gateNames == "local truth files used") = targets.sourceFileCount;
recommendedValue(gateNames == "distinct aircraft tracks") = targets.aircraftTrackCount;
recommendedValue(gateNames == "constturn-like pairs") = targets.turnLikePairCount;
recommendedValue(gateNames == "sparse-update pairs") = targets.sparseUpdatePairCount;

minimumShortfall = max( ...
    readinessGateTable.requiredValue - readinessGateTable.observedValue, ...
    0);
recommendedShortfall = max( ...
    recommendedValue - readinessGateTable.observedValue, ...
    0);
status = strings(height(readinessGateTable), 1);
status(readinessGateTable.passed) = "pass";
status(~readinessGateTable.passed) = "collect_more";

readinessGateTable.recommendedValue = recommendedValue;
readinessGateTable.minimumShortfall = minimumShortfall;
readinessGateTable.recommendedShortfall = recommendedShortfall;
readinessGateTable.status = status;

end

function motionCoverageTable = localBuildMotionCoverageTable(stage3BSummary, targets)
%LOCALBUILDMOTIONCOVERAGETABLE Build regime counts against targets.

countsByManeuver = stage3BSummary.labelSummary.countsByManeuverClass;
dataReadiness = stage3BSummary.dataReadiness;

regimeName = [ ...
    "constvel_like"; ...
    "constacc_like"; ...
    "constturn_like"; ...
    "mixed_or_sparse"; ...
    "climb"; ...
    "descent"; ...
    "sparse_update"];
observedValue = [ ...
    localLookupCount(countsByManeuver, "maneuverClass", "constvel_like"); ...
    localLookupCount(countsByManeuver, "maneuverClass", "constacc_like"); ...
    localLookupCount(countsByManeuver, "maneuverClass", "constturn_like"); ...
    localLookupCount(countsByManeuver, "maneuverClass", "mixed_or_sparse"); ...
    dataReadiness.climbPairCount; ...
    dataReadiness.descentPairCount; ...
    dataReadiness.sparseUpdatePairCount];
targetValue = [ ...
    targets.constvelLikePairCount; ...
    targets.constaccLikePairCount; ...
    targets.constturnLikePairCount; ...
    targets.mixedOrSparsePairCount; ...
    targets.climbPairCount; ...
    targets.descentPairCount; ...
    targets.sparseUpdatePairCount];
shortfallValue = max(targetValue - observedValue, 0);
coverageFraction = observedValue ./ max(targetValue, eps);
coverageFraction = min(coverageFraction, 1);

motionCoverageTable = table( ...
    regimeName, ...
    observedValue, ...
    targetValue, ...
    shortfallValue, ...
    coverageFraction, ...
    'VariableNames', [ ...
        "regime", ...
        "observedValue", ...
        "targetValue", ...
        "shortfallValue", ...
        "coverageFraction"]);

end

function comparisonTable = localBuildRmseComparisonTable(metricTable, groupType)
%LOCALBUILDRMSECOMPARISONTABLE Align constvel and frozen MLP rows by group.

groupNames = unique(string(metricTable.groupName), "stable");
constvelPositionRMSEMeters = NaN(numel(groupNames), 1);
frozenMLPPositionRMSEMeters = NaN(numel(groupNames), 1);
sampleCount = zeros(numel(groupNames), 1);

for groupIdx = 1:numel(groupNames)
    groupName = groupNames(groupIdx);
    constvelRow = localFindMetricRow(metricTable, "constvel baseline", groupName);
    mlpRow = localFindMetricRow(metricTable, "Frozen Stage 3A delta MLP", groupName);

    if ~isempty(constvelRow)
        constvelPositionRMSEMeters(groupIdx) = metricTable.positionRMSEMeters(constvelRow);
        sampleCount(groupIdx) = metricTable.sampleCount(constvelRow);
    end

    if ~isempty(mlpRow)
        frozenMLPPositionRMSEMeters(groupIdx) = metricTable.positionRMSEMeters(mlpRow);
    end
end

comparisonTable = table( ...
    repmat(string(groupType), numel(groupNames), 1), ...
    groupNames, ...
    sampleCount, ...
    constvelPositionRMSEMeters, ...
    frozenMLPPositionRMSEMeters, ...
    'VariableNames', [ ...
        "groupType", ...
        "groupName", ...
        "sampleCount", ...
        "constvelPositionRMSEMeters", ...
        "frozenMLPPositionRMSEMeters"]);

end

function rowIdx = localFindMetricRow(metricTable, methodName, groupName)
%LOCALFINDMETRICROW Find one metric row by method and group.

rowIdx = find( ...
    string(metricTable.method) == methodName & ...
    string(metricTable.groupName) == groupName, ...
    1, ...
    "first");

end

function splitCoverage = localBuildSplitCoverage(pairErrorTable)
%LOCALBUILDSPLITCOVERAGE Build train/validation/test coverage matrix.

splitName = string(pairErrorTable.split);
maneuverClass = string(pairErrorTable.maneuverClass);
dtRegime = string(pairErrorTable.dtRegime);

[groupID, splitGroup, maneuverGroup, dtGroup] = findgroups( ...
    splitName, ...
    maneuverClass, ...
    dtRegime);
pairCount = splitapply(@numel, splitName, groupID);
groupedCoverage = table( ...
    splitGroup, ...
    maneuverGroup, ...
    dtGroup, ...
    pairCount, ...
    'VariableNames', [ ...
        "split", ...
        "maneuverClass", ...
        "dtRegime", ...
        "pairCount"]);

splitOrder = ["train", "validation", "test"];
regimeOrder = ["regular_update", "sparse_update"];
maneuverOrder = [ ...
    "constvel_like", ...
    "constacc_like", ...
    "constturn_like", ...
    "mixed_or_sparse"];
columnLabels = strings(1, numel(splitOrder) * numel(regimeOrder));
coverageMatrix = zeros(numel(maneuverOrder), numel(columnLabels));

columnIdx = 0;

for splitIdx = 1:numel(splitOrder)
    for regimeIdx = 1:numel(regimeOrder)
        columnIdx = columnIdx + 1;
        columnLabels(columnIdx) = splitOrder(splitIdx) + " " + regimeOrder(regimeIdx);

        for maneuverIdx = 1:numel(maneuverOrder)
            rowMask = groupedCoverage.split == splitOrder(splitIdx) & ...
                groupedCoverage.dtRegime == regimeOrder(regimeIdx) & ...
                groupedCoverage.maneuverClass == maneuverOrder(maneuverIdx);

            if any(rowMask)
                coverageMatrix(maneuverIdx, columnIdx) = groupedCoverage.pairCount(find(rowMask, 1, "first"));
            end
        end
    end
end

splitCoverage = struct();
splitCoverage.matrix = coverageMatrix;
splitCoverage.rowLabels = maneuverOrder;
splitCoverage.columnLabels = columnLabels;
splitCoverage.groupedCoverage = groupedCoverage;

end

function sourceCoverageTable = localBuildSourceCoverageTable(stage3BSummary, stage3CSummary, hasStage3C)
%LOCALBUILDSOURCECOVERAGETABLE Summarize testing-machine and Pi-only sources.

if hasStage3C
    archiveSummary = stage3CSummary.archiveSummary;
    testingMachineFileCount = localStructFieldOrDefault( ...
        archiveSummary, ...
        "testingMachineFileCount", ...
        0);
    piOnlyTruthFileCount = localStructFieldOrDefault( ...
        archiveSummary, ...
        "piOnlyTruthFileCount", ...
        0);
    sourceRole = ["testing_machine"; "pi_only"];
    sourceName = ["testing-machine packaged sessions"; "Pi-only independent holdout"];
    truthFileCount = [testingMachineFileCount; piOnlyTruthFileCount];
else
    sourceRole = ["stage3b_local"; "pi_only"];
    sourceName = ["Stage 3B packaged/local truth"; "Pi-only independent holdout"];
    truthFileCount = [stage3BSummary.dataReadiness.sourceFileCount; 0];
end

targetFileCount = [1; 1];
status = strings(numel(sourceRole), 1);
details = strings(numel(sourceRole), 1);

for rowIdx = 1:numel(sourceRole)
    if truthFileCount(rowIdx) >= targetFileCount(rowIdx)
        status(rowIdx) = "present";
        details(rowIdx) = sprintf("%d truth file(s) available.", truthFileCount(rowIdx));
    else
        status(rowIdx) = "collect_holdout";
        details(rowIdx) = "Collect independent Pi-only ADS-B truth and package it as a holdout source.";
    end
end

sourceCoverageTable = table( ...
    sourceRole, ...
    sourceName, ...
    truthFileCount, ...
    targetFileCount, ...
    status, ...
    details, ...
    'VariableNames', [ ...
        "sourceRole", ...
        "sourceName", ...
        "truthFileCount", ...
        "targetFileCount", ...
        "status", ...
        "details"]);

end

function receiverMetadataTable = localBuildReceiverMetadataTable(stage3BSummary, stage3CSummary, hasStage3C)
%LOCALBUILDRECEIVERMETADATATABLE Summarize receiver-origin provenance.

if hasStage3C
    archiveSummary = stage3CSummary.archiveSummary;
    defaultReceiverOriginFileCount = localStructFieldOrDefault( ...
        archiveSummary, ...
        "defaultReceiverOriginFileCount", ...
        0);
    sessionManifestOriginFileCount = localStructFieldOrDefault( ...
        archiveSummary, ...
        "sessionManifestOriginFileCount", ...
        0);
else
    [defaultReceiverOriginFileCount, sessionManifestOriginFileCount] = ...
        localCountReceiverOriginSources(stage3BSummary);
end

totalFileCount = defaultReceiverOriginFileCount + sessionManifestOriginFileCount;
targetManifestFileCount = max(totalFileCount, 1);
originSource = ["session_manifest"; "default_receiver_origin"];
fileCount = [sessionManifestOriginFileCount; defaultReceiverOriginFileCount];
targetFileCount = [targetManifestFileCount; 0];
status = strings(numel(originSource), 1);
details = strings(numel(originSource), 1);

if sessionManifestOriginFileCount >= targetManifestFileCount && defaultReceiverOriginFileCount == 0
    status(1) = "complete";
else
    status(1) = "preserve_metadata";
end

if defaultReceiverOriginFileCount == 0
    status(2) = "none";
else
    status(2) = "replace_default_origin";
end

details(1) = sprintf( ...
    "%d file(s) used receiver LLA from session_manifest.json.", ...
    sessionManifestOriginFileCount);
details(2) = sprintf( ...
    "%d file(s) used the fallback receiver origin.", ...
    defaultReceiverOriginFileCount);

receiverMetadataTable = table( ...
    originSource, ...
    fileCount, ...
    targetFileCount, ...
    status, ...
    details, ...
    'VariableNames', [ ...
        "originSource", ...
        "fileCount", ...
        "targetFileCount", ...
        "status", ...
        "details"]);

end

function [defaultCount, manifestCount] = localCountReceiverOriginSources(stage3BSummary)
%LOCALCOUNTRECEIVERORIGINSOURCES Count receiver-origin source strings.

defaultCount = 0;
manifestCount = 0;

if ~isfield(stage3BSummary, "sourceManifest")
    return;
end

sourceManifest = stage3BSummary.sourceManifest;

if ~istable(sourceManifest) || ~ismember("receiverOriginSource", sourceManifest.Properties.VariableNames)
    return;
end

if ismember("usablePairCount", sourceManifest.Properties.VariableNames)
    usableMask = sourceManifest.usablePairCount > 0;
else
    usableMask = true(height(sourceManifest), 1);
end

originSources = string(sourceManifest.receiverOriginSource);
defaultCount = sum(usableMask & startsWith(originSources, "default"));
manifestCount = sum(usableMask & originSources == "session_manifest");

end
function priorityTable = localBuildCollectionPriorityTable(stage3BSummary, sourceCoverageTable, receiverMetadataTable, motionTargets, hasStage3C)
%LOCALBUILDCOLLECTIONPRIORITYTABLE Convert Stage 3C caveats into gates.

dataReadiness = stage3BSummary.dataReadiness;
piOnlyTruthFileCount = localSourceCount(sourceCoverageTable, "pi_only");
sourceDiversityRoleCount = sum(sourceCoverageTable.truthFileCount > 0);
defaultReceiverOriginFileCount = localMetadataCount(receiverMetadataTable, "default_receiver_origin");
sessionManifestOriginFileCount = localMetadataCount(receiverMetadataTable, "session_manifest");
metadataTargetCount = max(defaultReceiverOriginFileCount + sessionManifestOriginFileCount, 1);
turnSparseObserved = min( ...
    dataReadiness.constturnLikePairCount, ...
    dataReadiness.sparseUpdatePairCount);
turnSparseTarget = min( ...
    motionTargets.constturnLikePairCount, ...
    motionTargets.sparseUpdatePairCount);
verticalObserved = min( ...
    dataReadiness.climbPairCount, ...
    dataReadiness.descentPairCount);
verticalTarget = min( ...
    motionTargets.climbPairCount, ...
    motionTargets.descentPairCount);

priorityName = [ ...
    "independent Pi-only holdout"; ...
    "receiver-origin metadata"; ...
    "source diversity"; ...
    "turn/sparse-update regimes"; ...
    "climb/descent coverage"; ...
    "passive-radar geometry"];
observedValue = [ ...
    piOnlyTruthFileCount; ...
    sessionManifestOriginFileCount; ...
    sourceDiversityRoleCount; ...
    turnSparseObserved; ...
    verticalObserved; ...
    0];
targetValue = [ ...
    1; ...
    metadataTargetCount; ...
    2; ...
    turnSparseTarget; ...
    verticalTarget; ...
    1];
passed = [ ...
    piOnlyTruthFileCount > 0; ...
    sessionManifestOriginFileCount >= metadataTargetCount && defaultReceiverOriginFileCount == 0; ...
    sourceDiversityRoleCount >= 2; ...
    turnSparseObserved >= turnSparseTarget; ...
    verticalObserved >= verticalTarget; ...
    false];
status = strings(numel(priorityName), 1);
details = strings(numel(priorityName), 1);

status(passed) = "pass";
status(~passed) = "collect";
status(1) = localPriorityStatus(passed(1), "collect_holdout");
status(2) = localPriorityStatus(passed(2), "preserve_metadata");
status(3) = localPriorityStatus(passed(3), "collect_source_diversity");
status(4) = localPriorityStatus(passed(4), "target_motion_updates");
status(5) = localPriorityStatus(passed(5), "target_vertical_motion");
status(6) = "target_passive_radar_geometry";

if hasStage3C
    details(1) = "Stage 3C found no Pi-only truth files; collect independent Pi-origin holdout logs.";
else
    details(1) = "Stage 3C was not loaded; keep Pi-only holdout collection as an explicit target.";
end

details(2) = sprintf( ...
    "Preserve or create session_manifest.json receiver LLA metadata; %d file(s) currently use the default origin.", ...
    defaultReceiverOriginFileCount);
details(3) = "Keep testing-machine packaged sessions and Pi-only sessions separable for holdout review.";
details(4) = "Bias future windows toward turns and sparse ADS-B update intervals, not more straight regular updates.";
details(5) = "Keep climb and descent examples in the holdout mix.";
details(6) = "Choose windows with passive-radar-relevant bistatic geometry and record that context during packaging.";

priorityTable = table( ...
    priorityName, ...
    observedValue, ...
    targetValue, ...
    passed, ...
    status, ...
    details, ...
    'VariableNames', [ ...
        "priority", ...
        "observedValue", ...
        "targetValue", ...
        "passed", ...
        "status", ...
        "details"]);

end

function status = localPriorityStatus(passed, collectStatus)
%LOCALPRIORITYSTATUS Return pass or a specific collection status.

if passed
    status = "pass";
else
    status = collectStatus;
end

end
function captureProgressTable = localBuildCaptureProgressTable(dataReadiness, targets, readinessGateTable)
%LOCALBUILDCAPTUREPROGRESSTABLE Build current-to-target capture goals.

goalName = [ ...
    "ADS-B sessions"; ...
    "truth files"; ...
    "aircraft tracks"; ...
    "turn-like pairs"; ...
    "sparse-update pairs"];
observedValue = [ ...
    dataReadiness.sessionCount; ...
    dataReadiness.sourceFileCount; ...
    dataReadiness.aircraftCount; ...
    dataReadiness.constturnLikePairCount; ...
    dataReadiness.sparseUpdatePairCount];
targetValue = [ ...
    targets.sessionCount; ...
    targets.sourceFileCount; ...
    targets.aircraftTrackCount; ...
    targets.turnLikePairCount; ...
    targets.sparseUpdatePairCount];
remainingValue = max(targetValue - observedValue, 0);
progressFraction = observedValue ./ max(targetValue, eps);
progressFraction = min(progressFraction, 1);
minimumGateShortfall = [ ...
    localShortfallForGate(readinessGateTable, "distinct ADS-B sessions"); ...
    localShortfallForGate(readinessGateTable, "local truth files used"); ...
    localShortfallForGate(readinessGateTable, "distinct aircraft tracks"); ...
    localShortfallForGate(readinessGateTable, "constturn-like pairs"); ...
    localShortfallForGate(readinessGateTable, "sparse-update pairs")];

captureProgressTable = table( ...
    goalName, ...
    observedValue, ...
    targetValue, ...
    remainingValue, ...
    progressFraction, ...
    minimumGateShortfall, ...
    'VariableNames', [ ...
        "goal", ...
        "observedValue", ...
        "targetValue", ...
        "remainingValue", ...
        "progressFraction", ...
        "minimumGateShortfall"]);

end

function summary = localBuildSummary(stage3BSummary, stage3CSummary, hasStage3C, readinessGateTable, captureProgressTable, sourceCoverageTable, receiverMetadataTable, collectionPriorityTable)
%LOCALBUILDSUMMARY Build compact scalar answers for tests and reports.

dataReadiness = stage3BSummary.dataReadiness;
piOnlyTruthFileCount = localSourceCount(sourceCoverageTable, "pi_only");
defaultReceiverOriginFileCount = localMetadataCount(receiverMetadataTable, "default_receiver_origin");
sessionManifestOriginFileCount = localMetadataCount(receiverMetadataTable, "session_manifest");

minimumGateShortfall = struct();
minimumGateShortfall.sessions = localShortfallForGate(readinessGateTable, "distinct ADS-B sessions");
minimumGateShortfall.files = localShortfallForGate(readinessGateTable, "local truth files used");
minimumGateShortfall.sourceFiles = minimumGateShortfall.files;
minimumGateShortfall.aircraftTracks = localShortfallForGate(readinessGateTable, "distinct aircraft tracks");
minimumGateShortfall.turnLikePairs = localShortfallForGate(readinessGateTable, "constturn-like pairs");
minimumGateShortfall.sparseUpdatePairs = localShortfallForGate(readinessGateTable, "sparse-update pairs");

recommendedShortfall = localBuildRecommendedShortfall( ...
    captureProgressTable, ...
    hasStage3C);

currentCounts = struct();
currentCounts.pairCount = height(stage3BSummary.pairErrorTable);
currentCounts.sessions = dataReadiness.sessionCount;
currentCounts.files = dataReadiness.sourceFileCount;
currentCounts.sourceFiles = dataReadiness.sourceFileCount;
currentCounts.aircraftTracks = dataReadiness.aircraftCount;
currentCounts.turnLikePairs = dataReadiness.constturnLikePairCount;
currentCounts.sparseUpdatePairs = dataReadiness.sparseUpdatePairCount;
currentCounts.piOnlyTruthFiles = piOnlyTruthFileCount;
currentCounts.defaultReceiverOriginFiles = defaultReceiverOriginFileCount;
currentCounts.sessionManifestOriginFiles = sessionManifestOriginFileCount;

summary = struct();
summary.currentCounts = currentCounts;
summary.minimumGateShortfall = minimumGateShortfall;
summary.recommendedCaptureShortfall = recommendedShortfall;
summary.isReadyForRetraining = dataReadiness.isReadyForRetraining;
summary.hasStage3C = hasStage3C;
summary.piOnlyTruthFileCount = piOnlyTruthFileCount;
summary.defaultReceiverOriginFileCount = defaultReceiverOriginFileCount;
summary.sessionManifestOriginFileCount = sessionManifestOriginFileCount;
summary.independentHoldoutRecommendation = localBuildIndependentHoldoutRecommendation( ...
    piOnlyTruthFileCount, ...
    hasStage3C);
summary.metadataPreservationRecommendation = localBuildMetadataPreservationRecommendation( ...
    defaultReceiverOriginFileCount, ...
    sessionManifestOriginFileCount);
summary.collectionDecision = localBuildCollectionDecision( ...
    stage3CSummary, ...
    collectionPriorityTable, ...
    hasStage3C);
summary.recommendation = summary.collectionDecision;
summary.decision = summary.collectionDecision;

end

function recommendedShortfall = localBuildRecommendedShortfall(captureProgressTable, hasStage3C)
%LOCALBUILDRECOMMENDEDSHORTFALL Build compatible shortfall fields.

recommendedShortfall = struct();

if hasStage3C
    recommendedShortfall.sessions = 0;
    recommendedShortfall.files = 0;
    recommendedShortfall.sourceFiles = 0;
    recommendedShortfall.aircraftTracks = 0;
    recommendedShortfall.turnLikePairs = localRemainingForGoal(captureProgressTable, "turn-like pairs");
    recommendedShortfall.sparseUpdatePairs = localRemainingForGoal(captureProgressTable, "sparse-update pairs");
    recommendedShortfall.piOnlyTruthFiles = 1;
    recommendedShortfall.receiverMetadataFiles = NaN;
    recommendedShortfall.sourceDiversityRoles = 1;
    recommendedShortfall.passiveRadarGeometryWindows = 1;
    return;
end

recommendedShortfall.sessions = localRemainingForGoal(captureProgressTable, "ADS-B sessions");
recommendedShortfall.files = localRemainingForGoal(captureProgressTable, "truth files");
recommendedShortfall.sourceFiles = recommendedShortfall.files;
recommendedShortfall.aircraftTracks = localRemainingForGoal(captureProgressTable, "aircraft tracks");
recommendedShortfall.turnLikePairs = localRemainingForGoal(captureProgressTable, "turn-like pairs");
recommendedShortfall.sparseUpdatePairs = localRemainingForGoal(captureProgressTable, "sparse-update pairs");

end

function recommendation = localBuildIndependentHoldoutRecommendation(piOnlyTruthFileCount, hasStage3C)
%LOCALBUILDINDEPENDENTHOLDOUTRECOMMENDATION State holdout collection need.

if piOnlyTruthFileCount > 0
    recommendation = sprintf( ...
        "Pi-only holdout coverage is present with %d truth file(s); keep it independent from testing-machine packaged sessions.", ...
        piOnlyTruthFileCount);
    return;
end

if hasStage3C
    recommendation = "Collect independent Pi-only ADS-B truth logs as the next Stage 4B priority; Stage 3C found pi_only/truth empty.";
else
    recommendation = "Collect independent Pi-only ADS-B truth logs and use Stage 3C to verify the holdout source separately.";
end

end

function recommendation = localBuildMetadataPreservationRecommendation(defaultReceiverOriginFileCount, sessionManifestOriginFileCount)
%LOCALBUILDMETADATAPRESERVATIONRECOMMENDATION State receiver metadata need.

if defaultReceiverOriginFileCount == 0 && sessionManifestOriginFileCount > 0
    recommendation = "Receiver-origin metadata is preserved through session_manifest.json for all evaluated files.";
    return;
end

recommendation = sprintf( ...
    "Preserve or create session_manifest.json receiver LLA metadata during sync/package; %d evaluated file(s) still use the default receiver origin and %d use session metadata.", ...
    defaultReceiverOriginFileCount, ...
    sessionManifestOriginFileCount);

end

function decision = localBuildCollectionDecision(stage3CSummary, collectionPriorityTable, hasStage3C)
%LOCALBUILDCOLLECTIONDECISION Return the Stage 4A action.

if hasStage3C
    missingPriorities = collectionPriorityTable.priority(~collectionPriorityTable.passed);
    missingText = strjoin(missingPriorities, ", ");

    if isfield(stage3CSummary, "archiveSummary") && ...
            isfield(stage3CSummary.archiveSummary, "stage3BReadinessPassed") && ...
            stage3CSummary.archiveSummary.stage3BReadinessPassed
        gateText = "Basic Stage 3B gates pass on the Stage 3C archive";
    else
        gateText = "Stage 3C was loaded";
    end

    decision = gateText + ...
        ", but Stage 4A should continue targeted collection for " + ...
        missingText + ...
        ". Do not retrain in Stage 4A.";
    return;
end

decision = "Do not retrain in Stage 4A; collect ADS-B-only truth before starting a future retraining stage.";

end

function reportPath = localStage3CReportPath(stage3CSummary, hasStage3C)
%LOCALSTAGE3CREPORTPATH Return Stage 3C report path when available.

if hasStage3C && isfield(stage3CSummary, "reportPath")
    reportPath = string(stage3CSummary.reportPath);
else
    reportPath = "";
end

end

function countValue = localSourceCount(sourceCoverageTable, sourceRole)
%LOCALSOURCECOUNT Return a source role truth-file count.

rowMask = string(sourceCoverageTable.sourceRole) == sourceRole;

if any(rowMask)
    countValue = sourceCoverageTable.truthFileCount(find(rowMask, 1, "first"));
else
    countValue = 0;
end

end

function countValue = localMetadataCount(receiverMetadataTable, originSource)
%LOCALMETADATACOUNT Return receiver-origin provenance count.

rowMask = string(receiverMetadataTable.originSource) == originSource;

if any(rowMask)
    countValue = receiverMetadataTable.fileCount(find(rowMask, 1, "first"));
else
    countValue = 0;
end

end

function remainingValue = localRemainingForGoal(captureProgressTable, goalName)
%LOCALREMAININGFORGOAL Return remaining collection count for one goal.

rowMask = string(captureProgressTable.goal) == goalName;

if any(rowMask)
    remainingValue = captureProgressTable.remainingValue(find(rowMask, 1, "first"));
else
    remainingValue = NaN;
end

end
function shortfallValue = localShortfallForGate(readinessGateTable, gateName)
%LOCALSHORTFALLFORGATE Return the minimum-gate shortfall for one gate.

rowMask = string(readinessGateTable.gate) == gateName;

if any(rowMask)
    shortfallValue = readinessGateTable.minimumShortfall(find(rowMask, 1, "first"));
else
    shortfallValue = NaN;
end

end

function countValue = localLookupCount(countTable, variableName, categoryName)
%LOCALLOOKUPCOUNT Return a category count from a count table.

categoryValues = string(countTable.(variableName));
categoryMask = categoryValues == categoryName;

if any(categoryMask)
    countValue = countTable.pairCount(find(categoryMask, 1, "first"));
else
    countValue = 0;
end

end
function value = localStructFieldOrDefault(inputStruct, fieldName, defaultValue)
%LOCALSTRUCTFIELDORDEFAULT Read a scalar field with a fallback.

if isstruct(inputStruct) && isfield(inputStruct, fieldName)
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end

end

