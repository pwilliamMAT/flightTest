function stage3CSummary = runStage3CArchiveADSBEvaluation(varargin)
%RUNSTAGE3CARCHIVEADSBEVALUATION Evaluate archived ADS-B truth without retraining.
% Stage 3C is an archive-extension checkpoint. It inventories the archived
% ADS-B truth package, stages narrow gzip fallbacks only when MATLAB gunzip
% fails, and reuses the frozen Stage 3A versus constvel Stage 3B scoring path.

projectRoot = fileparts(mfilename("fullpath"));
flightTestRoot = fileparts(projectRoot);
defaultArchiveRoot = fullfile(projectRoot, "adsb_archive", "adsb_archive");
defaultOutputFolder = fullfile(projectRoot, "artifacts", "stage3C");
defaultParserFolder = fullfile(flightTestRoot, "BistaticDataAnalysis");
defaultStage3AArtifactPath = fullfile( ...
    projectRoot, ...
    "artifacts", ...
    "stage3", ...
    "localADSBMLPStage3Training.mat");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ProjectRoot", projectRoot);
addParameter(parser, "ArchiveRoot", defaultArchiveRoot);
addParameter(parser, "OutputFolder", defaultOutputFolder);
addParameter(parser, "ParserFolder", defaultParserFolder);
addParameter(parser, "SourceFiles", strings(0, 1));
addParameter(parser, "DatasetVariantID", "");
addParameter(parser, "Stage3AArtifactPath", defaultStage3AArtifactPath);
addParameter(parser, "UseGzipFallback", true);
addParameter(parser, "CreatePlots", true);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});

config = localBuildConfig(parser.Results);
localValidateConfig(config);

if isfolder(config.ParserFolder)
    addpath(config.ParserFolder);
end

if config.Verbose
    fprintf("Stage 3C archived ADS-B evaluation\n");
    fprintf("Archive root:\t%s\n", config.ArchiveRoot);
    fprintf("Output folder:\t%s\n", config.OutputFolder);
    fprintf("Gzip fallback enabled:\t%d\n", config.UseGzipFallback);
end

archiveInventory = helperBuildStage3CArchiveInventory( ...
    "ArchiveRoot", ...
    config.ArchiveRoot, ...
    "OutputFolder", ...
    config.OutputFolder, ...
    "ParserFolder", ...
    config.ParserFolder, ...
    "SourceFiles", ...
    config.SourceFiles, ...
    "UseGzipFallback", ...
    config.UseGzipFallback, ...
    "Verbose", ...
    config.Verbose);

localWriteInventoryArtifacts(config, archiveInventory);

sourceFiles = archiveInventory.sourceFilesForEvaluation;

if isempty(sourceFiles)
    error("Stage3C:NoEvaluationSources", ...
        "No archived ADS-B truth files could be selected for Stage 3C evaluation.");
end

stage3BSummary = runStage3BAggregateADSBEvaluation( ...
    "ProjectRoot", ...
    config.ProjectRoot, ...
    "SourceFiles", ...
    sourceFiles, ...
    "SearchRoot", ...
    config.ArchiveRoot, ...
    "ParserFolder", ...
    config.ParserFolder, ...
    "OutputFolder", ...
    config.OutputFolder, ...
    "AggregateDatasetPath", ...
    config.AggregateDatasetPath, ...
    "AggregateDatasetReportPath", ...
    config.AggregateDatasetReportPath, ...
    "Stage3AArtifactPath", ...
    config.Stage3AArtifactPath, ...
    "ArtifactPath", ...
    config.Stage3BScoringArtifactPath, ...
    "ReportPath", ...
    config.Stage3BScoringReportPath, ...
    "RebuildAggregateDataset", ...
    true, ...
    "CreatePlots", ...
    false, ...
    "CreateGlobeSnapshot", ...
    false, ...
    "Verbose", ...
    config.Verbose);

archiveSummary = localBuildArchiveSummary(archiveInventory, stage3BSummary);
interpretationTable = localBuildInterpretationTable(archiveSummary, stage3BSummary);
verificationTable = localBuildVerificationTable(archiveSummary, stage3BSummary);

stage3CSummary = struct();
stage3CSummary.generatedAt = datetime("now", "TimeZone", "UTC");
stage3CSummary.projectRoot = config.ProjectRoot;
stage3CSummary.archiveRoot = config.ArchiveRoot;
stage3CSummary.datasetVariantID = config.DatasetVariantID;
stage3CSummary.outputFolder = config.OutputFolder;
stage3CSummary.artifactPath = config.ArtifactPath;
stage3CSummary.reportPath = config.ReportPath;
stage3CSummary.inventoryTablePath = config.InventoryTablePath;
stage3CSummary.inventoryArtifactPath = config.InventoryArtifactPath;
stage3CSummary.stage3BScoringArtifactPath = config.Stage3BScoringArtifactPath;
stage3CSummary.stage3BScoringReportPath = config.Stage3BScoringReportPath;
stage3CSummary.aggregateDatasetPath = config.AggregateDatasetPath;
stage3CSummary.aggregateDatasetReportPath = config.AggregateDatasetReportPath;
stage3CSummary.config = config;
stage3CSummary.archiveInventory = archiveInventory;
stage3CSummary.archiveSummary = archiveSummary;
stage3CSummary.stage3BSummary = stage3BSummary;
stage3CSummary.metricComparisonTable = stage3BSummary.metricComparisonTable;
stage3CSummary.dataReadiness = stage3BSummary.dataReadiness;
stage3CSummary.interpretationTable = interpretationTable;
stage3CSummary.verificationTable = verificationTable;
stage3CSummary.figurePaths = struct();

if config.CreatePlots
    stage3CSummary.figurePaths = helperWriteStage3CFigures( ...
        config.OutputFolder, ...
        stage3CSummary);
end

helperWriteStage3CReport(config.ReportPath, stage3CSummary);
localSaveArtifact(stage3CSummary);

if config.Verbose
    localPrintSummary(stage3CSummary);
end

end

function config = localBuildConfig(opts)
%LOCALBUILDCONFIG Normalize parser output and default Stage 3C paths.

outputFolder = string(opts.OutputFolder);

config = struct();
config.ProjectRoot = string(opts.ProjectRoot);
config.ArchiveRoot = string(opts.ArchiveRoot);
config.OutputFolder = outputFolder;
config.ParserFolder = string(opts.ParserFolder);
config.SourceFiles = string(opts.SourceFiles);
config.SourceFiles = config.SourceFiles(strlength(strtrim(config.SourceFiles)) > 0);
config.DatasetVariantID = string(opts.DatasetVariantID);
config.Stage3AArtifactPath = string(opts.Stage3AArtifactPath);
config.UseGzipFallback = logical(opts.UseGzipFallback);
config.CreatePlots = logical(opts.CreatePlots);
config.Verbose = logical(opts.Verbose);
config.AggregateDatasetPath = fullfile(outputFolder, "stage3CArchiveStatePairDataset.mat");
config.AggregateDatasetReportPath = fullfile(outputFolder, "stage3CArchiveStatePairDatasetSummary.md");
config.Stage3BScoringArtifactPath = fullfile(outputFolder, "stage3CStage3BScoringEvaluation.mat");
config.Stage3BScoringReportPath = fullfile(outputFolder, "stage3CStage3BScoringReport.md");
config.InventoryTablePath = fullfile(outputFolder, "stage3CArchiveInventory.csv");
config.InventoryArtifactPath = fullfile(outputFolder, "stage3CArchiveInventory.mat");
config.ArtifactPath = fullfile(outputFolder, "stage3CArchiveADSBEvaluation.mat");
config.ReportPath = fullfile(outputFolder, "stage3CArchiveADSBEvaluationReport.md");

end

function localValidateConfig(config)
%LOCALVALIDATECONFIG Validate paths before running file-heavy work.

if strlength(config.OutputFolder) == 0
    error("Stage3C:MissingOutputFolder", ...
        "OutputFolder must not be empty.");
end

if exist(config.ArchiveRoot, "dir") ~= 7
    error("Stage3C:MissingArchiveRoot", ...
        "ArchiveRoot was not found: %s", config.ArchiveRoot);
end

if exist(config.ParserFolder, "dir") ~= 7
    error("Stage3C:MissingParserFolder", ...
        "ParserFolder was not found: %s", config.ParserFolder);
end

if exist(config.Stage3AArtifactPath, "file") ~= 2
    error("Stage3C:MissingStage3AArtifact", ...
        "Stage 3A artifact was not found: %s", config.Stage3AArtifactPath);
end

end

function localWriteInventoryArtifacts(config, archiveInventory)
%LOCALWRITEINVENTORYARTIFACTS Save inventory as both table and MAT artifact.

try
    if strlength(config.OutputFolder) > 0 && ~isfolder(config.OutputFolder)
        mkdir(config.OutputFolder);
    end

    writetable(archiveInventory.sourceFileTable, config.InventoryTablePath);
    save(config.InventoryArtifactPath, "archiveInventory");
catch err
    error("Stage3C:InventoryWriteFailed", ...
        "Failed to write Stage 3C archive inventory artifacts: %s", err.message);
end

end

function archiveSummary = localBuildArchiveSummary(archiveInventory, stage3BSummary)
%LOCALBUILDARCHIVESUMMARY Build scalar counts used by reports and tests.

sourceFileTable = archiveInventory.sourceFileTable;
usableSourceMask = sourceFileTable.usablePairCount > 0;
usableSessions = unique(string(sourceFileTable.sessionID(usableSourceMask)));
sourceRoles = string(sourceFileTable.sourceRole);
sourceManifest = stage3BSummary.sourceManifest;
receiverOriginSources = string(sourceManifest.receiverOriginSource);
stage3BUsableMask = sourceManifest.usablePairCount > 0;

archiveSummary = struct();
archiveSummary.sourceFileCount = height(sourceFileTable);
archiveSummary.selectedEvaluationFileCount = numel(archiveInventory.sourceFilesForEvaluation);
archiveSummary.usableSourceFileCount = sum(usableSourceMask);
archiveSummary.usableSessionCount = numel(usableSessions);
archiveSummary.usablePairCount = size(stage3BSummary.nextState, 1);
archiveSummary.aircraftTrackCount = height(stage3BSummary.trackSummary);
archiveSummary.testingMachineFileCount = sum(sourceRoles == "testing_machine");
archiveSummary.piOnlyTruthFileCount = sum(sourceRoles == "pi_only");
archiveSummary.nativeGunzipFailureCount = sum(sourceFileTable.nativeGzipStatus == "failed");
archiveSummary.fallbackRecoveredFileCount = sum(sourceFileTable.fallbackStatus == "succeeded");
archiveSummary.zeroUseFileCount = sum(sourceFileTable.usablePairCount == 0);
archiveSummary.defaultReceiverOriginFileCount = sum( ...
    stage3BUsableMask & receiverOriginSources == "default");
archiveSummary.sessionManifestOriginFileCount = sum( ...
    stage3BUsableMask & receiverOriginSources == "session_manifest");
archiveSummary.stage3BReadinessPassed = stage3BSummary.dataReadiness.isReadyForRetraining;
archiveSummary.retrainingRun = false;
archiveSummary.collectionRecommendation = localCollectionRecommendation(archiveSummary);

end

function recommendation = localCollectionRecommendation(archiveSummary)
%LOCALCOLLECTIONRECOMMENDATION State what collection is still missing.

if archiveSummary.piOnlyTruthFileCount == 0
    recommendation = "Archive scoring is broad enough for the Stage 3B gates, but independent Pi-only ADS-B truth logs are still missing. Next collection should prioritize independent holdout sessions, source diversity, maneuver/update-regime coverage, and passive-radar-relevant geometry rather than raw sample count alone.";
    return;
end

recommendation = "Archive scoring passed the basic gates. Future collection should still emphasize independent holdout sessions, source diversity, turn/sparse-update regimes, and passive-radar-relevant geometry.";

end

function interpretationTable = localBuildInterpretationTable(archiveSummary, stage3BSummary)
%LOCALBUILDINTERPRETATIONTABLE Convert counts into Stage 3C decisions.

finding = [ ...
    "basic Stage 3B readiness gates"; ...
    "independent Pi-only ADS-B logs"; ...
    "receiver-origin metadata"; ...
    "frozen model policy"; ...
    "next collection emphasis"];
status = strings(numel(finding), 1);
details = strings(numel(finding), 1);

if archiveSummary.stage3BReadinessPassed
    status(1) = "pass";
    details(1) = "The archived evaluation passes the configured Stage 3B retraining-readiness gates.";
else
    status(1) = "fail";
    details(1) = stage3BSummary.dataReadiness.recommendation;
end

if archiveSummary.piOnlyTruthFileCount == 0
    status(2) = "missing";
    details(2) = "The archive contains testing-machine captures, but pi_only/truth has no ADS-B truth files.";
else
    status(2) = "present";
    details(2) = sprintf("pi_only/truth contains %d file(s).", archiveSummary.piOnlyTruthFileCount);
end

if archiveSummary.sessionManifestOriginFileCount == 0
    status(3) = "missing";
    details(3) = "All evaluated files used the default receiver origin because no session_manifest.json receiver LLA was available in the truth-only archive.";
else
    status(3) = "partial";
    details(3) = sprintf( ...
        "%d file(s) used session metadata and %d file(s) used the default receiver origin.", ...
        archiveSummary.sessionManifestOriginFileCount, ...
        archiveSummary.defaultReceiverOriginFileCount);
end

status(4) = "held frozen";
details(4) = "Stage 3C did not retrain; it reused the frozen Stage 3A MLP and native constvel scoring path.";
status(5) = "collect targeted data";
details(5) = archiveSummary.collectionRecommendation;

interpretationTable = table( ...
    finding, ...
    status, ...
    details, ...
    'VariableNames', ["finding", "status", "details"]);

end

function verificationTable = localBuildVerificationTable(archiveSummary, stage3BSummary)
%LOCALBUILDVERIFICATIONTABLE Record Stage 3C-specific invariants.

check = [ ...
    "archive files selected"; ...
    "nonempty Stage 3B scoring"; ...
    "all scoring verification checks passed"; ...
    "fallback recovered native gunzip failures"; ...
    "no retraining performed"];
passed = [ ...
    archiveSummary.selectedEvaluationFileCount > 0; ...
    height(stage3BSummary.pairErrorTable) > 0; ...
    all(stage3BSummary.verificationTable.passed); ...
    archiveSummary.fallbackRecoveredFileCount == archiveSummary.nativeGunzipFailureCount; ...
    ~archiveSummary.retrainingRun];
details = [ ...
    sprintf("%d file(s) selected for evaluation", archiveSummary.selectedEvaluationFileCount); ...
    sprintf("%d state pairs scored", height(stage3BSummary.pairErrorTable)); ...
    sprintf("%d Stage 3B checks passed", sum(stage3BSummary.verificationTable.passed)); ...
    sprintf("%d native gunzip failure(s), %d fallback recovery file(s)", archiveSummary.nativeGunzipFailureCount, archiveSummary.fallbackRecoveredFileCount); ...
    "Frozen Stage 3A artifact was loaded for inference only"];

verificationTable = table( ...
    check, ...
    passed, ...
    details, ...
    'VariableNames', ["check", "passed", "details"]);

end

function localSaveArtifact(stage3CSummary)
%LOCALSAVEARTIFACT Save Stage 3C artifact and compact top-level variables.

archiveInventory = stage3CSummary.archiveInventory;
archiveSummary = stage3CSummary.archiveSummary;
stage3BSummary = stage3CSummary.stage3BSummary;
metricComparisonTable = stage3CSummary.metricComparisonTable;
dataReadiness = stage3CSummary.dataReadiness;
interpretationTable = stage3CSummary.interpretationTable;
verificationTable = stage3CSummary.verificationTable;

try
    artifactFolder = fileparts(stage3CSummary.artifactPath);

    if strlength(artifactFolder) > 0 && ~isfolder(artifactFolder)
        mkdir(artifactFolder);
    end

    save(stage3CSummary.artifactPath, ...
        "stage3CSummary", ...
        "archiveInventory", ...
        "archiveSummary", ...
        "stage3BSummary", ...
        "metricComparisonTable", ...
        "dataReadiness", ...
        "interpretationTable", ...
        "verificationTable", ...
        "-v7.3");
catch err
    error("Stage3C:ArtifactSaveFailed", ...
        "Failed to save Stage 3C artifact: %s", err.message);
end

end

function localPrintSummary(stage3CSummary)
%LOCALPRINTSUMMARY Print concise Stage 3C results.

archiveSummary = stage3CSummary.archiveSummary;
aggregate = stage3CSummary.metricComparisonTable;
constvelRow = aggregate.method == "constvel baseline";
mlpRow = aggregate.method == "Frozen Stage 3A delta MLP";

fprintf("Stage 3C archived ADS-B evaluation complete\n");
fprintf("Archive source files:\t%d\n", archiveSummary.sourceFileCount);
fprintf("Usable sessions:\t%d\n", archiveSummary.usableSessionCount);
fprintf("Pairs evaluated:\t%d\n", archiveSummary.usablePairCount);
fprintf("Aircraft tracks:\t%d\n", archiveSummary.aircraftTrackCount);
fprintf("Fallback recovered files:\t%d\n", archiveSummary.fallbackRecoveredFileCount);
fprintf("Constvel position RMSE [m]:\t%.3f\n", aggregate.positionRMSEMeters(constvelRow));
fprintf("Frozen Stage 3A position RMSE [m]:\t%.3f\n", aggregate.positionRMSEMeters(mlpRow));
fprintf("Basic Stage 3B readiness passed:\t%d\n", archiveSummary.stage3BReadinessPassed);
fprintf("Report written:\t%s\n", stage3CSummary.reportPath);
fprintf("Artifact written:\t%s\n", stage3CSummary.artifactPath);

end
