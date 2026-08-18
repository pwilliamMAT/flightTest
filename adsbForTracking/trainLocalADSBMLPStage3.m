function stage3Summary = trainLocalADSBMLPStage3(varargin)
%TRAINLOCALADSBMLPSTAGE3 Train the Stage 3A delta-target ADS-B MLP.
% The model learns targetDelta = nextState - previousState and reconstructs
% predictedNextState = previousState + predictedDelta. Absolute horizontal
% x/y are not default neural inputs.

projectRoot = fileparts(mfilename("fullpath"));
defaultDatasetPath = fullfile(projectRoot, "artifacts", "stage2B", "localADSBStatePairDataset.mat");
defaultCharacterizationPath = fullfile(projectRoot, "artifacts", "stage2C", "stage2CManeuverCharacterization.mat");
defaultOutputFolder = fullfile(projectRoot, "artifacts", "stage3");
defaultArtifactPath = fullfile(defaultOutputFolder, "localADSBMLPStage3Training.mat");
defaultReportPath = fullfile(defaultOutputFolder, "stage3LocalADSBMLPTrainingReport.md");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "DatasetPath", defaultDatasetPath);
addParameter(parser, "CharacterizationPath", defaultCharacterizationPath);
addParameter(parser, "OutputFolder", defaultOutputFolder);
addParameter(parser, "ArtifactPath", defaultArtifactPath);
addParameter(parser, "ReportPath", defaultReportPath);
addParameter(parser, "Seed", 123);
addParameter(parser, "HiddenUnits", 64);
addParameter(parser, "TinySampleCount", 64);
addParameter(parser, "TinyEpochs", 50);
addParameter(parser, "ShortEpochs", 15);
addParameter(parser, "LongEpochs", 150);
addParameter(parser, "LongSeeds", [123, 456, 789]);
addParameter(parser, "MiniBatchSize", 128);
addParameter(parser, "LearnRate", 1e-3);
addParameter(parser, "L2Regularization", 1e-4);
addParameter(parser, "VarianceEpsilon", 1e-6);
addParameter(parser, "RunCovariancePhase", "auto");
addParameter(parser, "RunLongTraining", false);
addParameter(parser, "PreflightOnly", false);
addParameter(parser, "CreatePlots", true);
addParameter(parser, "ExecutionEnvironment", "auto");
addParameter(parser, "MeanGateMultiplier", 3);
addParameter(parser, "MeanGateAbsoluteToleranceMeters", 25);
addParameter(parser, "SaneMaxValidationPositionRMSEMeters", 100);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});
opts = parser.Results;

config = localBuildConfig(opts);
localValidateConfig(config);

if config.Verbose
    fprintf("Stage 3A local ADS-B delta-target MLP training\n");
    fprintf("Dataset:\t%s\n", config.DatasetPath);
    fprintf("Maneuver labels:\t%s\n", config.CharacterizationPath);
end

rng(config.Seed, "twister");

stage2BDataset = localLoadStage2BDataset(config.DatasetPath);
stage2CCharacterization = localLoadStage2CCharacterization(config.CharacterizationPath);
localValidateStageArtifacts(stage2BDataset, stage2CCharacterization);

targetDelta = stage2BDataset.nextState - stage2BDataset.previousState;
split = string(stage2BDataset.metadata.split);
trainMask = split == "train";
validationMask = split == "validation";
testMask = split == "test";

constvelBaseline = helperScoreConstVelBaseline( ...
    stage2BDataset.previousState, ...
    stage2BDataset.nextState, ...
    stage2BDataset.dtSeconds);
constvelPredictedState = constvelBaseline.predictedState;

featureSets = helperBuildStage3AFeatures( ...
    stage2BDataset.previousState, ...
    stage2BDataset.previousCovarianceDiag, ...
    stage2BDataset.dtSeconds, ...
    constvelPredictedState, ...
    split);

targetNormalization = localComputeTargetNormalization(targetDelta, trainMask);
targetDeltaNormalized = (targetDelta - targetNormalization.targetMean) ./ targetNormalization.targetStd;

constvelMetrics = helperScoreStage3APredictions( ...
    stage2BDataset.nextState, ...
    constvelPredictedState, ...
    stage2BDataset.metadata, ...
    stage2CCharacterization.maneuverPairTable, ...
    "constvel baseline");

preflightAudit = localBuildPreflightAudit( ...
    stage2BDataset, ...
    stage2CCharacterization, ...
    targetDelta, ...
    featureSets, ...
    constvelMetrics);

if config.PreflightOnly
    baselineResults = localBuildPreflightOnlyBaselines(constvelMetrics);
else
    baselineResults = localBuildBaselineResults( ...
        stage2BDataset, ...
        stage2CCharacterization, ...
        targetDelta, ...
        featureSets.physics.featuresNormalized, ...
        trainMask, ...
        constvelMetrics);
end

normalization = struct();
normalization.target = targetNormalization;
normalization.rawFeatures = featureSets.raw.normalization;
normalization.physicsFeatures = featureSets.physics.normalization;

trainingLadder = localInitializeTrainingLadder(config);
predictions = localInitializePredictions( ...
    stage2BDataset, ...
    constvelPredictedState, ...
    targetDelta, ...
    targetDeltaNormalized);
metrics = table();
figurePaths = struct();
net = [];
trainingInfo = [];

if ~config.PreflightOnly
    if config.Verbose
        fprintf("Training tiny overfit mean-only MLP...\n");
    end

    trainRows = find(trainMask);
    tinyRows = trainRows(1:min(config.TinySampleCount, numel(trainRows)));
    tinyRun = localTrainMeanOnlyNetwork( ...
        featureSets.physics.featuresNormalized(tinyRows, :), ...
        targetDeltaNormalized(tinyRows, :), ...
        [], ...
        [], ...
        size(featureSets.physics.featuresNormalized, 2), ...
        config, ...
        config.TinyEpochs, ...
        "tiny_overfit", ...
        config.Seed);
    tinyPredictedDeltaNormalized = localPredictNetwork(tinyRun.net, featureSets.physics.featuresNormalized(tinyRows, :), 6);
    tinyPredictedState = localReconstructNextState( ...
        stage2BDataset.previousState(tinyRows, :), ...
        tinyPredictedDeltaNormalized, ...
        targetNormalization);
    tinyMetrics = helperScoreStage3APredictions( ...
        stage2BDataset.nextState(tinyRows, :), ...
        tinyPredictedState, ...
        stage2BDataset.metadata(tinyRows, :), ...
        stage2CCharacterization.maneuverPairTable(tinyRows, :), ...
        "tiny overfit delta MLP");

    if config.Verbose
        fprintf("Training short full mean-only MLP with physics-derived features...\n");
    end

    shortPhysicsRun = localTrainMeanOnlyNetwork( ...
        featureSets.physics.featuresNormalized(trainMask, :), ...
        targetDeltaNormalized(trainMask, :), ...
        featureSets.physics.featuresNormalized(validationMask, :), ...
        targetDeltaNormalized(validationMask, :), ...
        size(featureSets.physics.featuresNormalized, 2), ...
        config, ...
        config.ShortEpochs, ...
        "short_physics", ...
        config.Seed);
    physicsPredictedDeltaNormalized = localPredictNetwork( ...
        shortPhysicsRun.net, ...
        featureSets.physics.featuresNormalized, ...
        6);
    physicsPredictedState = localReconstructNextState( ...
        stage2BDataset.previousState, ...
        physicsPredictedDeltaNormalized, ...
        targetNormalization);
    physicsMetrics = helperScoreStage3APredictions( ...
        stage2BDataset.nextState, ...
        physicsPredictedState, ...
        stage2BDataset.metadata, ...
        stage2CCharacterization.maneuverPairTable, ...
        "Stage 3A delta MLP");

    if config.Verbose
        fprintf("Training short ablation MLP with raw motion features...\n");
    end

    shortRawRun = localTrainMeanOnlyNetwork( ...
        featureSets.raw.featuresNormalized(trainMask, :), ...
        targetDeltaNormalized(trainMask, :), ...
        featureSets.raw.featuresNormalized(validationMask, :), ...
        targetDeltaNormalized(validationMask, :), ...
        size(featureSets.raw.featuresNormalized, 2), ...
        config, ...
        config.ShortEpochs, ...
        "short_raw", ...
        config.Seed);
    rawPredictedDeltaNormalized = localPredictNetwork( ...
        shortRawRun.net, ...
        featureSets.raw.featuresNormalized, ...
        6);
    rawPredictedState = localReconstructNextState( ...
        stage2BDataset.previousState, ...
        rawPredictedDeltaNormalized, ...
        targetNormalization);
    rawMetrics = helperScoreStage3APredictions( ...
        stage2BDataset.nextState, ...
        rawPredictedState, ...
        stage2BDataset.metadata, ...
        stage2CCharacterization.maneuverPairTable, ...
        "Stage 3A raw-feature delta MLP");

    trainingLadder = localUpdateMeanTrainingLadder( ...
        trainingLadder, ...
        tinyRun, ...
        tinyMetrics, ...
        shortPhysicsRun, ...
        physicsMetrics, ...
        shortRawRun, ...
        rawMetrics, ...
        baselineResults, ...
        config);

    meanGate = localEvaluateMeanGate(physicsMetrics, constvelMetrics, config);
    trainingLadder.meanGate = meanGate;

    finalFeatureMode = "physics";
    finalPredictedDeltaNormalized = physicsPredictedDeltaNormalized;
    finalPredictedState = physicsPredictedState;
    net = shortPhysicsRun.net;
    trainingInfo = shortPhysicsRun.info;

    covarianceRun = [];

    if localShouldRunCovariancePhase(config.RunCovariancePhase, meanGate.passed)
        if config.Verbose
            fprintf("Mean gate passed; training covariance-head Gaussian NLL model...\n");
        end

        covarianceRun = localTrainCovarianceNetwork( ...
            featureSets.physics.featuresNormalized(trainMask, :), ...
            targetDeltaNormalized(trainMask, :), ...
            featureSets.physics.featuresNormalized(validationMask, :), ...
            targetDeltaNormalized(validationMask, :), ...
            size(featureSets.physics.featuresNormalized, 2), ...
            config, ...
            config.ShortEpochs, ...
            "covariance_head", ...
            config.Seed);
        covarianceOutput = localPredictNetwork(covarianceRun.net, featureSets.physics.featuresNormalized, 12);
        finalPredictedDeltaNormalized = covarianceOutput(:, 1:6);
        finalPredictedState = localReconstructNextState( ...
            stage2BDataset.previousState, ...
            finalPredictedDeltaNormalized, ...
            targetNormalization);
        net = covarianceRun.net;
        trainingInfo = covarianceRun.info;
        trainingLadder.covarianceStatus = "completed";
        trainingLadder.covarianceInfo = covarianceRun.info;
    else
        trainingLadder.covarianceStatus = "skipped";
        trainingLadder.covarianceInfo = [];
    end

    if config.RunLongTraining && meanGate.passed
        if config.Verbose
            fprintf("Mean gate passed and RunLongTraining=true; training long-seed candidates...\n");
        end

        longRun = localRunLongTraining( ...
            featureSets.physics.featuresNormalized, ...
            targetDeltaNormalized, ...
            trainMask, ...
            validationMask, ...
            stage2BDataset, ...
            stage2CCharacterization, ...
            targetNormalization, ...
            config);
        finalFeatureMode = "physics";
        finalPredictedDeltaNormalized = longRun.bestPredictedDeltaNormalized;
        finalPredictedState = longRun.bestPredictedState;
        net = longRun.bestNet;
        trainingInfo = longRun.bestInfo;
        trainingLadder.longRun = longRun;
        trainingLadder.longRunStatus = "completed";
    elseif config.RunLongTraining
        trainingLadder.longRunStatus = "skipped_mean_gate_failed";
    else
        trainingLadder.longRunStatus = "skipped_by_default";
    end

    predictedVarianceNormalized = localBuildVarianceEstimate( ...
        covarianceRun, ...
        featureSets.physics.featuresNormalized, ...
        finalPredictedDeltaNormalized, ...
        targetDeltaNormalized, ...
        trainMask, ...
        config);
    predictedCovarianceDiag = predictedVarianceNormalized .* (targetNormalization.targetStd .^ 2);
    metrics = helperScoreStage3APredictions( ...
        stage2BDataset.nextState, ...
        finalPredictedState, ...
        stage2BDataset.metadata, ...
        stage2CCharacterization.maneuverPairTable, ...
        "Stage 3A delta MLP");

    predictions.predictedDeltaNormalized = finalPredictedDeltaNormalized;
    predictions.predictedDelta = finalPredictedDeltaNormalized .* targetNormalization.targetStd + ...
        targetNormalization.targetMean;
    predictions.predictedNextState = finalPredictedState;
    predictions.predictedVarianceNormalized = predictedVarianceNormalized;
    predictions.predictedCovarianceDiag = predictedCovarianceDiag;
    predictions.featureMode = finalFeatureMode;
    predictions.rawAblationPredictedNextState = rawPredictedState;
    predictions.physicsPredictedNextState = physicsPredictedState;

    trainingLadder.ladderTable = localBuildLadderTable(trainingLadder, config);
end

selectedTrack = localSelectReviewTrack(stage2BDataset.metadata, stage2CCharacterization.trackSummary);

stage3Summary = struct();
stage3Summary.generatedAt = datetime("now", "TimeZone", "UTC");
stage3Summary.datasetPath = config.DatasetPath;
stage3Summary.characterizationPath = config.CharacterizationPath;
stage3Summary.outputFolder = config.OutputFolder;
stage3Summary.artifactPath = config.ArtifactPath;
stage3Summary.reportPath = config.ReportPath;
stage3Summary.config = config;
stage3Summary.configTable = localBuildConfigTable(config);
stage3Summary.stateOrder = stage2BDataset.stateOrder;
stage3Summary.previousState = stage2BDataset.previousState;
stage3Summary.nextState = stage2BDataset.nextState;
stage3Summary.dtSeconds = stage2BDataset.dtSeconds;
stage3Summary.metadata = stage2BDataset.metadata;
stage3Summary.maneuverPairTable = stage2CCharacterization.maneuverPairTable;
stage3Summary.targetDelta = targetDelta;
stage3Summary.targetDeltaNormalized = targetDeltaNormalized;
stage3Summary.normalization = normalization;
stage3Summary.featureSets = featureSets;
stage3Summary.preflightAudit = preflightAudit;
stage3Summary.baselineResults = baselineResults;
stage3Summary.trainingLadder = trainingLadder;
stage3Summary.predictions = predictions;
stage3Summary.metrics = metrics;
stage3Summary.selectedTrack = selectedTrack;
stage3Summary.figurePaths = figurePaths;
stage3Summary.diversityAssessment = stage2CCharacterization.diversityAssessment;
stage3Summary.trainCount = sum(trainMask);
stage3Summary.validationCount = sum(validationMask);
stage3Summary.testCount = sum(testMask);

if config.CreatePlots && ~config.PreflightOnly
    figurePaths = helperWriteStage3AFigures(config.OutputFolder, stage3Summary);
    stage3Summary.figurePaths = figurePaths;
end

helperWriteStage3AReport(config.ReportPath, stage3Summary);

predictedNextState = predictions.predictedNextState;
reconstructedNextState = predictedNextState;
predictedCovarianceDiag = predictions.predictedCovarianceDiag;
trainingLadder = stage3Summary.trainingLadder;
preflightAudit = stage3Summary.preflightAudit;
baselineResults = stage3Summary.baselineResults;
normalization = stage3Summary.normalization;
metrics = stage3Summary.metrics;
config = stage3Summary.config;

try
    if strlength(config.OutputFolder) > 0 && ~isfolder(config.OutputFolder)
        mkdir(config.OutputFolder);
    end

    save(config.ArtifactPath, ...
        "stage3Summary", ...
        "net", ...
        "trainingInfo", ...
        "config", ...
        "normalization", ...
        "predictions", ...
        "predictedNextState", ...
        "reconstructedNextState", ...
        "predictedCovarianceDiag", ...
        "metrics", ...
        "preflightAudit", ...
        "baselineResults", ...
        "trainingLadder", ...
        "targetDelta", ...
        "-v7.3");
catch err
    error("Stage3A:ArtifactSaveFailed", ...
        "Failed to save Stage 3A training artifact: %s", err.message);
end

if stage3Summary.config.Verbose
    fprintf("Stage 3A report written:\t%s\n", stage3Summary.reportPath);
    fprintf("Stage 3A artifact written:\t%s\n", stage3Summary.artifactPath);

    if ~stage3Summary.config.PreflightOnly
        finalMetrics = stage3Summary.metrics.aggregate;
        fprintf("Stage 3A position RMSE [m]:\t%.3f\n", finalMetrics.positionRMSEMeters(1));
        fprintf("Stage 3A velocity RMSE [m/s]:\t%.3f\n", finalMetrics.velocityRMSEMetersPerSecond(1));
    end
end

end

function config = localBuildConfig(opts)
%LOCALBUILDCONFIG Convert parser output to a compact config struct.

config = struct();
config.DatasetPath = string(opts.DatasetPath);
config.CharacterizationPath = string(opts.CharacterizationPath);
config.OutputFolder = string(opts.OutputFolder);
config.ArtifactPath = string(opts.ArtifactPath);
config.ReportPath = string(opts.ReportPath);
config.Seed = double(opts.Seed);
config.HiddenUnits = double(opts.HiddenUnits);
config.TinySampleCount = double(opts.TinySampleCount);
config.TinyEpochs = double(opts.TinyEpochs);
config.ShortEpochs = double(opts.ShortEpochs);
config.LongEpochs = double(opts.LongEpochs);
config.LongSeeds = double(opts.LongSeeds);
config.MiniBatchSize = double(opts.MiniBatchSize);
config.LearnRate = double(opts.LearnRate);
config.L2Regularization = double(opts.L2Regularization);
config.VarianceEpsilon = double(opts.VarianceEpsilon);
config.RunCovariancePhase = lower(string(opts.RunCovariancePhase));
config.RunLongTraining = logical(opts.RunLongTraining);
config.PreflightOnly = logical(opts.PreflightOnly);
config.CreatePlots = logical(opts.CreatePlots);
config.ExecutionEnvironment = string(opts.ExecutionEnvironment);
config.MeanGateMultiplier = double(opts.MeanGateMultiplier);
config.MeanGateAbsoluteToleranceMeters = double(opts.MeanGateAbsoluteToleranceMeters);
config.SaneMaxValidationPositionRMSEMeters = double(opts.SaneMaxValidationPositionRMSEMeters);
config.Verbose = logical(opts.Verbose);

end

function localValidateConfig(config)
%LOCALVALIDATECONFIG Validate scalar training settings.

validateattributes(config.Seed, {'numeric'}, {'scalar', 'integer', 'finite'}, mfilename, "Seed");
validateattributes(config.HiddenUnits, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "HiddenUnits");
validateattributes(config.TinySampleCount, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "TinySampleCount");
validateattributes(config.TinyEpochs, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "TinyEpochs");
validateattributes(config.ShortEpochs, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "ShortEpochs");
validateattributes(config.LongEpochs, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "LongEpochs");
validateattributes(config.MiniBatchSize, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, "MiniBatchSize");
validateattributes(config.LearnRate, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, "LearnRate");
validateattributes(config.L2Regularization, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, "L2Regularization");
validateattributes(config.VarianceEpsilon, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, "VarianceEpsilon");

validCovarianceModes = ["auto", "always", "never"];

if ~any(config.RunCovariancePhase == validCovarianceModes)
    error("Stage3A:BadCovarianceMode", ...
        "RunCovariancePhase must be auto, always, or never.");
end

end

function stage2BDataset = localLoadStage2BDataset(datasetPath)
%LOCALLOADSTAGE2BDATASET Load the Stage 2B artifact.

try
    stage2BDataset = load(datasetPath, ...
        "previousState", ...
        "nextState", ...
        "dtSeconds", ...
        "previousCovarianceDiag", ...
        "metadata", ...
        "stateOrder", ...
        "buildSummary", ...
        "splitManifest", ...
        "baselineConstVelMetrics");
catch err
    error("Stage3A:DatasetLoadFailed", ...
        "Failed to load Stage 2B dataset artifact: %s", err.message);
end

end

function stage2CCharacterization = localLoadStage2CCharacterization(characterizationPath)
%LOCALLOADSTAGE2CCHARACTERIZATION Load Stage 2C maneuver labels.

try
    stage2CCharacterization = load(characterizationPath, ...
        "maneuverPairTable", ...
        "labelSummary", ...
        "trackSummary", ...
        "diversityAssessment");
catch err
    error("Stage3A:CharacterizationLoadFailed", ...
        "Failed to load Stage 2C characterization artifact: %s", err.message);
end

end

function localValidateStageArtifacts(stage2BDataset, stage2CCharacterization)
%LOCALVALIDATESTAGEARTIFACTS Verify saved Stage 2B/2C row alignment.

requiredDatasetFields = [ ...
    "previousState", ...
    "nextState", ...
    "dtSeconds", ...
    "previousCovarianceDiag", ...
    "metadata", ...
    "stateOrder"];

for fieldIdx = 1:numel(requiredDatasetFields)
    fieldName = requiredDatasetFields(fieldIdx);

    if ~isfield(stage2BDataset, fieldName)
        error("Stage3A:MissingDatasetField", ...
            "Stage 2B artifact is missing %s.", fieldName);
    end
end

sampleCount = size(stage2BDataset.previousState, 1);

if size(stage2BDataset.nextState, 1) ~= sampleCount || ...
        numel(stage2BDataset.dtSeconds) ~= sampleCount || ...
        size(stage2BDataset.previousCovarianceDiag, 1) ~= sampleCount || ...
        height(stage2BDataset.metadata) ~= sampleCount
    error("Stage3A:DatasetSizeMismatch", ...
        "Stage 2B arrays must contain one row per state pair.");
end

if height(stage2CCharacterization.maneuverPairTable) ~= sampleCount
    error("Stage3A:CharacterizationSizeMismatch", ...
        "Stage 2C maneuver labels must align with Stage 2B state pairs.");
end

expectedStateOrder = ["x", "vx", "y", "vy", "z", "vz"];

if ~isequal(string(stage2BDataset.stateOrder), expectedStateOrder)
    error("Stage3A:BadStateOrder", ...
        "Stage 3A requires Sensor Fusion state order [x, vx, y, vy, z, vz].");
end

end

function targetNormalization = localComputeTargetNormalization(targetDelta, trainMask)
%LOCALCOMPUTETARGETNORMALIZATION Normalize deltas using train rows only.

targetMean = mean(targetDelta(trainMask, :), 1, "omitnan");
rawTargetStd = std(targetDelta(trainMask, :), 0, 1, "omitnan");
targetStd = rawTargetStd;
badStd = ~isfinite(targetStd) | targetStd <= 0;
targetStd(badStd) = 1;

targetNormalization = struct();
targetNormalization.computedFromSplit = "train";
targetNormalization.trainRowCount = sum(trainMask);
targetNormalization.targetMean = targetMean;
targetNormalization.targetStd = targetStd;
targetNormalization.rawTargetStd = rawTargetStd;
targetNormalization.stateOrder = ["x", "vx", "y", "vy", "z", "vz"];

end

function preflightAudit = localBuildPreflightAudit(stage2BDataset, stage2CCharacterization, targetDelta, featureSets, constvelMetrics)
%LOCALBUILDPREFLIGHTAUDIT Build no-training Stage 3A diagnostics.

finiteCheckTable = table( ...
    [ ...
        "previousState"; ...
        "nextState"; ...
        "dtSeconds"; ...
        "previousCovarianceDiag"; ...
        "targetDelta"; ...
        "maneuverPairTable"], ...
    [ ...
        all(isfinite(stage2BDataset.previousState), "all"); ...
        all(isfinite(stage2BDataset.nextState), "all"); ...
        all(isfinite(stage2BDataset.dtSeconds), "all"); ...
        all(isfinite(stage2BDataset.previousCovarianceDiag), "all"); ...
        all(isfinite(targetDelta), "all"); ...
        height(stage2CCharacterization.maneuverPairTable) == size(targetDelta, 1)], ...
    'VariableNames', ["checkName", "passed"]);

preflightAudit = struct();
preflightAudit.finiteCheckTable = finiteCheckTable;
preflightAudit.splitCountTable = groupsummary(stage2BDataset.metadata, "split");
preflightAudit.splitByManeuverClass = localCrossCountTable( ...
    stage2BDataset.metadata.split, ...
    "split", ...
    stage2CCharacterization.maneuverPairTable.maneuverClass, ...
    "maneuverClass");
preflightAudit.splitByVerticalStatus = localCrossCountTable( ...
    stage2BDataset.metadata.split, ...
    "split", ...
    stage2CCharacterization.maneuverPairTable.verticalStatus, ...
    "verticalStatus");
preflightAudit.splitByDtRegime = localCrossCountTable( ...
    stage2BDataset.metadata.split, ...
    "split", ...
    stage2CCharacterization.maneuverPairTable.dtRegime, ...
    "dtRegime");
preflightAudit.targetDeltaStats = localStateComponentStats(targetDelta);
preflightAudit.featureStdTable = localFeatureStdTable(featureSets);
preflightAudit.previousCovarianceUniqueRowCount = size(unique(stage2BDataset.previousCovarianceDiag, "rows"), 1);
preflightAudit.constvelMetricsBySplit = constvelMetrics.bySplit;

end

function crossTable = localCrossCountTable(firstGroup, firstName, secondGroup, secondName)
%LOCALCROSSCOUNTTABLE Count pairs by two categorical/string labels.

firstGroup = string(firstGroup(:));
secondGroup = string(secondGroup(:));
[groupId, firstOut, secondOut] = findgroups(firstGroup, secondGroup);
pairCount = splitapply(@numel, firstGroup, groupId);

crossTable = table( ...
    firstOut, ...
    secondOut, ...
    pairCount, ...
    'VariableNames', [string(firstName), string(secondName), "pairCount"]);

end

function statsTable = localStateComponentStats(stateMatrix)
%LOCALSTATECOMPONENTSTATS Build component-wise descriptive statistics.

component = ["x"; "vx"; "y"; "vy"; "z"; "vz"];
statsTable = table( ...
    component, ...
    mean(stateMatrix, 1, "omitnan").', ...
    std(stateMatrix, 0, 1, "omitnan").', ...
    min(stateMatrix, [], 1).', ...
    median(stateMatrix, 1, "omitnan").', ...
    max(stateMatrix, [], 1).', ...
    'VariableNames', ["component", "mean", "std", "min", "median", "max"]);

end

function featureStdTable = localFeatureStdTable(featureSets)
%LOCALFEATURESTDTABLE Report raw train standard deviation for features.

rawTable = localOneFeatureStdTable(featureSets.raw);
physicsTable = localOneFeatureStdTable(featureSets.physics);
featureStdTable = [rawTable; physicsTable];

end

function featureStdTable = localOneFeatureStdTable(featureSet)
%LOCALONEFEATURESTDTABLE Build std table for one feature mode.

featureStdTable = table( ...
    repmat(featureSet.featureMode, numel(featureSet.featureNames), 1), ...
    featureSet.featureNames(:), ...
    featureSet.normalization.rawFeatureStd(:), ...
    featureSet.normalization.featureStd(:), ...
    featureSet.normalization.constantFeatureMask(:), ...
    'VariableNames', [ ...
        "featureMode", ...
        "featureName", ...
        "trainStdBeforeGuard", ...
        "trainStdUsed", ...
        "constantFeature"]);

end

function baselineResults = localBuildPreflightOnlyBaselines(constvelMetrics)
%LOCALBUILDPREFLIGHTONLYBASELINES Package constvel metrics without training.

baselineResults = struct();
baselineResults.constvelMetrics = constvelMetrics;
baselineResults.aggregateComparisonTable = constvelMetrics.aggregate;
baselineResults.linearStatus = "skipped_preflight_only";

end

function baselineResults = localBuildBaselineResults(stage2BDataset, stage2CCharacterization, targetDelta, featureMatrix, trainMask, constvelMetrics)
%LOCALBUILDBASELINERESULTS Train/report low-cost non-neural baselines.

zeroDeltaPredictedState = stage2BDataset.previousState;
trainMeanDelta = mean(targetDelta(trainMask, :), 1, "omitnan");
trainMeanPredictedState = stage2BDataset.previousState + trainMeanDelta;

[linearDelta, linearModels, linearStatus] = localFitLinearDeltaBaseline( ...
    featureMatrix(trainMask, :), ...
    targetDelta(trainMask, :), ...
    featureMatrix);
linearPredictedState = stage2BDataset.previousState + linearDelta;

zeroMetrics = helperScoreStage3APredictions( ...
    stage2BDataset.nextState, ...
    zeroDeltaPredictedState, ...
    stage2BDataset.metadata, ...
    stage2CCharacterization.maneuverPairTable, ...
    "zero-delta persistence");
meanMetrics = helperScoreStage3APredictions( ...
    stage2BDataset.nextState, ...
    trainMeanPredictedState, ...
    stage2BDataset.metadata, ...
    stage2CCharacterization.maneuverPairTable, ...
    "train-mean delta");
linearMetrics = helperScoreStage3APredictions( ...
    stage2BDataset.nextState, ...
    linearPredictedState, ...
    stage2BDataset.metadata, ...
    stage2CCharacterization.maneuverPairTable, ...
    "linear delta regression");

baselineResults = struct();
baselineResults.zeroDeltaMetrics = zeroMetrics;
baselineResults.trainMeanDeltaMetrics = meanMetrics;
baselineResults.constvelMetrics = constvelMetrics;
baselineResults.linearMetrics = linearMetrics;
baselineResults.linearModels = linearModels;
baselineResults.linearStatus = linearStatus;
baselineResults.trainMeanDelta = trainMeanDelta;
baselineResults.linearPredictedState = linearPredictedState;
baselineResults.aggregateComparisonTable = [ ...
    zeroMetrics.aggregate; ...
    meanMetrics.aggregate; ...
    constvelMetrics.aggregate; ...
    linearMetrics.aggregate];

end

function [linearDelta, linearModels, linearStatus] = localFitLinearDeltaBaseline(XTrain, YTrain, XAll)
%LOCALFITLINEARDELTABASELINE Fit per-output linear delta regressions.

outputCount = size(YTrain, 2);
sampleCount = size(XAll, 1);
linearDelta = NaN(sampleCount, outputCount);
linearModels = cell(1, outputCount);
linearStatus = strings(1, outputCount);

for outputIdx = 1:outputCount
    try
        model = fitrlinear( ...
            XTrain, ...
            YTrain(:, outputIdx), ...
            "Learner", "leastsquares", ...
            "Regularization", "ridge", ...
            "Lambda", 1e-4);
        linearDelta(:, outputIdx) = predict(model, XAll);
        linearModels{outputIdx} = model;
        linearStatus(outputIdx) = "fitrlinear";
    catch
        model = fitlm(XTrain, YTrain(:, outputIdx));
        linearDelta(:, outputIdx) = predict(model, XAll);
        linearModels{outputIdx} = model;
        linearStatus(outputIdx) = "fitlm_fallback";
    end
end

end

function trainingLadder = localInitializeTrainingLadder(config)
%LOCALINITIALIZETRAININGLADDER Create default ladder state.

trainingLadder = struct();
trainingLadder.tinyOverfitInfo = [];
trainingLadder.shortPhysicsInfo = [];
trainingLadder.shortRawInfo = [];
trainingLadder.covarianceInfo = [];
trainingLadder.covarianceStatus = "not_started";
trainingLadder.longRunStatus = "not_started";
trainingLadder.featureAblationTable = table();
trainingLadder.meanGate = struct("passed", false, "details", "not evaluated");

if config.PreflightOnly
    trainingLadder.ladderTable = table( ...
        [ ...
            "preflight_audit"; ...
            "baselines"; ...
            "tiny_overfit"; ...
            "short_full_mean_only"; ...
            "feature_ablation"; ...
            "covariance_phase"; ...
            "long_run"], ...
        [ ...
            "completed"; ...
            "skipped_preflight_only"; ...
            "skipped_preflight_only"; ...
            "skipped_preflight_only"; ...
            "skipped_preflight_only"; ...
            "skipped_preflight_only"; ...
            "skipped_preflight_only"], ...
        [ ...
            "No-training audit completed."; ...
            "Baseline training skipped by PreflightOnly."; ...
            "Neural training skipped by PreflightOnly."; ...
            "Neural training skipped by PreflightOnly."; ...
            "Neural training skipped by PreflightOnly."; ...
            "Covariance phase skipped by PreflightOnly."; ...
            "Long training skipped by PreflightOnly."], ...
        'VariableNames', ["rung", "status", "details"]);
else
    trainingLadder.ladderTable = table();
end

end

function predictions = localInitializePredictions(stage2BDataset, constvelPredictedState, targetDelta, targetDeltaNormalized)
%LOCALINITIALIZEPREDICTIONS Create prediction struct before training.

sampleCount = size(stage2BDataset.previousState, 1);

predictions = struct();
predictions.targetDelta = targetDelta;
predictions.targetDeltaNormalized = targetDeltaNormalized;
predictions.constvelPredictedState = constvelPredictedState;
predictions.predictedDeltaNormalized = NaN(sampleCount, 6);
predictions.predictedDelta = NaN(sampleCount, 6);
predictions.predictedNextState = NaN(sampleCount, 6);
predictions.predictedVarianceNormalized = NaN(sampleCount, 6);
predictions.predictedCovarianceDiag = NaN(sampleCount, 6);
predictions.featureMode = "";

end

function run = localTrainMeanOnlyNetwork(XTrain, YTrain, XValidation, YValidation, featureCount, config, maxEpochs, runName, seed)
%LOCALTRAINMEANONLYNETWORK Train one mean-only delta MLP with trainnet.

rng(seed, "twister");
layers = localBuildMLPLayers(featureCount, config.HiddenUnits, 6);
options = localBuildTrainingOptions( ...
    config, ...
    maxEpochs, ...
    size(XTrain, 1), ...
    XValidation, ...
    YValidation, ...
    runName);

[net, info] = trainnet(XTrain, YTrain, layers, "mse", options);

run = struct();
run.name = string(runName);
run.net = net;
run.info = info;
run.finalTrainingLoss = localFinalTrainingLoss(info);
run.stopReason = string(info.StopReason);

end

function run = localTrainCovarianceNetwork(XTrain, YTrain, XValidation, YValidation, featureCount, config, maxEpochs, runName, seed)
%LOCALTRAINCOVARIANCENETWORK Train mean-plus-diagonal-variance NLL model.

rng(seed, "twister");
layers = localBuildMLPLayers(featureCount, config.HiddenUnits, 12);
options = localBuildTrainingOptions( ...
    config, ...
    maxEpochs, ...
    size(XTrain, 1), ...
    XValidation, ...
    YValidation, ...
    runName);
lossFcn = @(Yhat, T) localGaussianNLLLoss(Yhat, T, config.VarianceEpsilon);

[net, info] = trainnet(XTrain, YTrain, layers, lossFcn, options);

run = struct();
run.name = string(runName);
run.net = net;
run.info = info;
run.finalTrainingLoss = localFinalTrainingLoss(info);
run.stopReason = string(info.StopReason);

end

function layers = localBuildMLPLayers(featureCount, hiddenUnits, outputCount)
%LOCALBUILDMLPLAYERS Build the shallow Stage 3A MLP.

layers = [
    featureInputLayer(featureCount, "Normalization", "none", "Name", "features")
    fullyConnectedLayer(hiddenUnits, "Name", "fc1")
    reluLayer("Name", "relu1")
    fullyConnectedLayer(hiddenUnits, "Name", "fc2")
    reluLayer("Name", "relu2")
    fullyConnectedLayer(outputCount, "Name", "prediction")];

end

function options = localBuildTrainingOptions(config, maxEpochs, trainSampleCount, XValidation, YValidation, runName)
%LOCALBUILDTRAININGOPTIONS Build common trainnet trainingOptions.

hasValidation = ~isempty(XValidation) && ~isempty(YValidation);
miniBatchSize = min(config.MiniBatchSize, trainSampleCount);

if hasValidation
    options = trainingOptions( ...
        "adam", ...
        "MaxEpochs", maxEpochs, ...
        "MiniBatchSize", miniBatchSize, ...
        "InitialLearnRate", config.LearnRate, ...
        "L2Regularization", config.L2Regularization, ...
        "Shuffle", "every-epoch", ...
        "ValidationData", {XValidation, YValidation}, ...
        "ValidationFrequency", 1, ...
        "ValidationPatience", max(1, maxEpochs), ...
        "ExecutionEnvironment", config.ExecutionEnvironment, ...
        "Verbose", false, ...
        "Plots", "none");
else
    options = trainingOptions( ...
        "adam", ...
        "MaxEpochs", maxEpochs, ...
        "MiniBatchSize", miniBatchSize, ...
        "InitialLearnRate", config.LearnRate, ...
        "L2Regularization", config.L2Regularization, ...
        "Shuffle", "every-epoch", ...
        "ExecutionEnvironment", config.ExecutionEnvironment, ...
        "Verbose", false, ...
        "Plots", "none");
end

if config.Verbose
    fprintf("trainnet rung:\t%s\tepochs:\t%d\n", runName, maxEpochs);
end

end

function loss = localGaussianNLLLoss(Yhat, T, varianceEpsilon)
%LOCALGAUSSIANNLLLOSS Diagonal Gaussian NLL in normalized delta space.

predictedMean = Yhat(1:6, :);
rawVariance = Yhat(7:12, :);
variance = log(1 + exp(rawVariance)) + varianceEpsilon;
residual = predictedMean - T;
loss = mean(0.5 .* (log(variance) + (residual .^ 2) ./ variance), "all");

end

function prediction = localPredictNetwork(net, featuresNormalized, outputCount)
%LOCALPREDICTNETWORK Run minibatchpredict and ensure rows are observations.

prediction = minibatchpredict(net, featuresNormalized);
prediction = gather(prediction);
prediction = double(prediction);

if size(prediction, 2) ~= outputCount && size(prediction, 1) == outputCount
    prediction = prediction.';
end

if size(prediction, 2) ~= outputCount
    error("Stage3A:PredictionWidthMismatch", ...
        "Network prediction width must be %d.", outputCount);
end

end

function predictedNextState = localReconstructNextState(previousState, predictedDeltaNormalized, targetNormalization)
%LOCALRECONSTRUCTNEXTSTATE Apply the Stage 3A delta reconstruction policy.

predictedDelta = predictedDeltaNormalized .* targetNormalization.targetStd + ...
    targetNormalization.targetMean;
predictedNextState = previousState + predictedDelta;

end

function finalLoss = localFinalTrainingLoss(info)
%LOCALFINALTRAININGLOSS Return final trainnet training loss.

if isempty(info) || isempty(info.TrainingHistory)
    finalLoss = NaN;
else
    finalLoss = info.TrainingHistory.Loss(end);
end

end

function trainingLadder = localUpdateMeanTrainingLadder(trainingLadder, tinyRun, tinyMetrics, shortPhysicsRun, physicsMetrics, shortRawRun, rawMetrics, baselineResults, config)
%LOCALUPDATEMEANTRAININGLADDER Store mean-only training results.

trainingLadder.tinyOverfitInfo = tinyRun.info;
trainingLadder.tinyOverfitFinalLoss = tinyRun.finalTrainingLoss;
trainingLadder.tinyOverfitMetrics = tinyMetrics;
trainingLadder.shortPhysicsInfo = shortPhysicsRun.info;
trainingLadder.shortPhysicsFinalLoss = shortPhysicsRun.finalTrainingLoss;
trainingLadder.shortPhysicsMetrics = physicsMetrics;
trainingLadder.shortRawInfo = shortRawRun.info;
trainingLadder.shortRawFinalLoss = shortRawRun.finalTrainingLoss;
trainingLadder.shortRawMetrics = rawMetrics;
trainingLadder.featureAblationTable = localBuildFeatureAblationTable(physicsMetrics, rawMetrics);
trainingLadder.tinyGatePassed = isfinite(tinyRun.finalTrainingLoss) && ...
    tinyMetrics.aggregate.positionRMSEMeters(1) < ...
    baselineResults.trainMeanDeltaMetrics.aggregate.positionRMSEMeters(1);
trainingLadder.shortPhysicsStopReason = string(shortPhysicsRun.info.StopReason);
trainingLadder.shortRawStopReason = string(shortRawRun.info.StopReason);
trainingLadder.configSnapshot = config;

end

function featureAblationTable = localBuildFeatureAblationTable(physicsMetrics, rawMetrics)
%LOCALBUILDFEATUREABLATIONTABLE Compare raw and physics-derived features.

physicsValidation = localLookupSplitPositionRMSE(physicsMetrics, "validation");
rawValidation = localLookupSplitPositionRMSE(rawMetrics, "validation");
physicsTest = localLookupSplitPositionRMSE(physicsMetrics, "test");
rawTest = localLookupSplitPositionRMSE(rawMetrics, "test");

featureAblationTable = table( ...
    ["raw_motion"; "physics_derived_delta"], ...
    [rawMetrics.aggregate.positionRMSEMeters(1); physicsMetrics.aggregate.positionRMSEMeters(1)], ...
    [rawValidation; physicsValidation], ...
    [rawTest; physicsTest], ...
    'VariableNames', [ ...
        "featureMode", ...
        "allPositionRMSEMeters", ...
        "validationPositionRMSEMeters", ...
        "testPositionRMSEMeters"]);

end

function meanGate = localEvaluateMeanGate(physicsMetrics, constvelMetrics, config)
%LOCALEVALUATEMEANGATE Decide whether covariance/long training may proceed.

mlpValidationRMSE = localLookupSplitPositionRMSE(physicsMetrics, "validation");
constvelValidationRMSE = localLookupSplitPositionRMSE(constvelMetrics, "validation");
relativeThreshold = config.MeanGateMultiplier .* constvelValidationRMSE;
absoluteThreshold = constvelValidationRMSE + config.MeanGateAbsoluteToleranceMeters;
gateThreshold = min( ...
    config.SaneMaxValidationPositionRMSEMeters, ...
    max(relativeThreshold, absoluteThreshold));
passed = isfinite(mlpValidationRMSE) && mlpValidationRMSE <= gateThreshold;

meanGate = struct();
meanGate.passed = passed;
meanGate.mlpValidationPositionRMSEMeters = mlpValidationRMSE;
meanGate.constvelValidationPositionRMSEMeters = constvelValidationRMSE;
meanGate.thresholdPositionRMSEMeters = gateThreshold;

if passed
    meanGate.details = "short mean-only model is near enough to constvel for optional covariance/long rungs";
else
    meanGate.details = "short mean-only model did not pass the constvel-nearness gate";
end

end

function value = localLookupSplitPositionRMSE(metrics, splitName)
%LOCALLOOKUPSPLITPOSITIONRMSE Return position RMSE for one split.

splitName = string(splitName);
rows = string(metrics.bySplit.groupName) == splitName;

if any(rows)
    value = metrics.bySplit.positionRMSEMeters(find(rows, 1, "first"));
else
    value = NaN;
end

end

function runCovariance = localShouldRunCovariancePhase(mode, meanGatePassed)
%LOCALSHOULDRUNCOVARIANCEPHASE Apply covariance ladder gate.

switch string(mode)
    case "always"
        runCovariance = true;
    case "auto"
        runCovariance = meanGatePassed;
    otherwise
        runCovariance = false;
end

end

function longRun = localRunLongTraining(featureMatrix, targetDeltaNormalized, trainMask, validationMask, stage2BDataset, stage2CCharacterization, targetNormalization, config)
%LOCALRUNLONGTRAINING Run optional long training over configured seeds.

seedCount = numel(config.LongSeeds);
seedTable = table();
bestValidationRMSE = Inf;
bestNet = [];
bestInfo = [];
bestPredictedDeltaNormalized = [];
bestPredictedState = [];

for seedIdx = 1:seedCount
    seedValue = config.LongSeeds(seedIdx);
    run = localTrainMeanOnlyNetwork( ...
        featureMatrix(trainMask, :), ...
        targetDeltaNormalized(trainMask, :), ...
        featureMatrix(validationMask, :), ...
        targetDeltaNormalized(validationMask, :), ...
        size(featureMatrix, 2), ...
        config, ...
        config.LongEpochs, ...
        "long_physics", ...
        seedValue);
    predictedDeltaNormalized = localPredictNetwork(run.net, featureMatrix, 6);
    predictedState = localReconstructNextState( ...
        stage2BDataset.previousState, ...
        predictedDeltaNormalized, ...
        targetNormalization);
    runMetrics = helperScoreStage3APredictions( ...
        stage2BDataset.nextState, ...
        predictedState, ...
        stage2BDataset.metadata, ...
        stage2CCharacterization.maneuverPairTable, ...
        "Stage 3A long delta MLP");
    validationRMSE = localLookupSplitPositionRMSE(runMetrics, "validation");

    seedTable = [seedTable; table( ...
        seedValue, ...
        validationRMSE, ...
        runMetrics.aggregate.positionRMSEMeters(1), ...
        run.finalTrainingLoss, ...
        string(run.info.StopReason), ...
        'VariableNames', [ ...
            "seed", ...
            "validationPositionRMSEMeters", ...
            "allPositionRMSEMeters", ...
            "finalTrainingLoss", ...
            "stopReason"])]; %#ok<AGROW>

    if validationRMSE < bestValidationRMSE
        bestValidationRMSE = validationRMSE;
        bestNet = run.net;
        bestInfo = run.info;
        bestPredictedDeltaNormalized = predictedDeltaNormalized;
        bestPredictedState = predictedState;
    end
end

longRun = struct();
longRun.seedTable = seedTable;
longRun.bestValidationPositionRMSEMeters = bestValidationRMSE;
longRun.bestNet = bestNet;
longRun.bestInfo = bestInfo;
longRun.bestPredictedDeltaNormalized = bestPredictedDeltaNormalized;
longRun.bestPredictedState = bestPredictedState;

end

function predictedVarianceNormalized = localBuildVarianceEstimate(covarianceRun, featureMatrix, predictedDeltaNormalized, targetDeltaNormalized, trainMask, config)
%LOCALBUILDVARIANCEESTIMATE Return positive diagonal variance estimates.

if ~isempty(covarianceRun)
    covarianceOutput = localPredictNetwork(covarianceRun.net, featureMatrix, 12);
    predictedVarianceNormalized = localSoftplus(covarianceOutput(:, 7:12)) + config.VarianceEpsilon;
else
    residual = predictedDeltaNormalized(trainMask, :) - targetDeltaNormalized(trainMask, :);
    residualVariance = var(residual, 0, 1, "omitnan");
    residualVariance(~isfinite(residualVariance) | residualVariance <= 0) = config.VarianceEpsilon;
    predictedVarianceNormalized = repmat(residualVariance + config.VarianceEpsilon, size(featureMatrix, 1), 1);
end

end

function value = localSoftplus(rawValue)
%LOCALSOFTPLUS Convert raw variance parameters to positive values.

value = log(1 + exp(rawValue));

end

function ladderTable = localBuildLadderTable(trainingLadder, config)
%LOCALBUILDLADDERTABLE Summarize fail-fast rung outcomes.

covarianceDetails = trainingLadder.covarianceStatus;
longDetails = trainingLadder.longRunStatus;

ladderTable = table( ...
    [ ...
        "preflight_audit"; ...
        "baselines"; ...
        "tiny_overfit"; ...
        "short_full_mean_only"; ...
        "feature_ablation"; ...
        "covariance_phase"; ...
        "long_run"], ...
    [ ...
        "completed"; ...
        "completed"; ...
        localPassFailStatus(trainingLadder.tinyGatePassed); ...
        localPassFailStatus(trainingLadder.meanGate.passed); ...
        "completed"; ...
        covarianceDetails; ...
        longDetails], ...
    [ ...
        "Finite checks, target stats, split counts, and constvel split metrics completed."; ...
        "Zero-delta, train-mean delta, constvel, and linear delta baselines completed."; ...
        sprintf("Tiny epochs: %d, final loss: %.6g.", config.TinyEpochs, trainingLadder.tinyOverfitFinalLoss); ...
        sprintf("Short epochs: %d, mean gate: %s.", config.ShortEpochs, trainingLadder.meanGate.details); ...
        "Raw motion features and physics-derived delta features were both trained."; ...
        covarianceDetails; ...
        longDetails], ...
    'VariableNames', ["rung", "status", "details"]);

end

function status = localPassFailStatus(passed)
%LOCALPASSFAILSTATUS Convert a logical gate to text.

if passed
    status = "passed";
else
    status = "did_not_pass";
end

end

function selectedTrack = localSelectReviewTrack(metadata, trackSummary)
%LOCALSELECTREVIEWTRACK Select a readable trajectory for plots/review.

if isempty(trackSummary) || height(trackSummary) == 0
    selectedTrack = struct("hex", "", "rows", (1:min(80, height(metadata))).');
    return;
end

constvelShare = trackSummary.constvelLikePairCount ./ trackSummary.pairCount;
candidateMask = trackSummary.pairCount >= 40 & constvelShare >= 0.70;

if any(candidateMask)
    candidateTable = trackSummary(candidateMask, :);
else
    candidateTable = trackSummary;
end

[~, bestIdx] = max(candidateTable.pairCount);
trackHex = string(candidateTable.hex(bestIdx));
rows = find(string(metadata.hex) == trackHex);

if isempty(rows)
    rows = (1:min(80, height(metadata))).';
else
    [~, sortIdx] = sort(metadata.timeUtcNext(rows));
    rows = rows(sortIdx);
    rows = rows(1:min(80, numel(rows)));
end

selectedTrack = struct();
selectedTrack.hex = trackHex;
selectedTrack.rows = rows(:);

end

function configTable = localBuildConfigTable(config)
%LOCALBUILDCONFIGTABLE Convert config struct to Markdown-friendly table.

fieldNames = string(fieldnames(config));
values = strings(numel(fieldNames), 1);

for fieldIdx = 1:numel(fieldNames)
    fieldName = fieldNames(fieldIdx);
    values(fieldIdx) = localConfigValueToString(config.(fieldName));
end

configTable = table(fieldNames, values, 'VariableNames', ["setting", "value"]);

end

function valueText = localConfigValueToString(value)
%LOCALCONFIGVALUETOSTRING Format config values.

if isstring(value)
    valueText = strjoin(value, ", ");
elseif ischar(value)
    valueText = string(value);
elseif isnumeric(value) || islogical(value)
    valueText = string(mat2str(value));
else
    valueText = string(value);
end

end
