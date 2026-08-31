function review = helperBuildStageReviewArtifacts(varargin)
%HELPERBUILDSTAGEREVIEWARTIFACTS Load saved stage artifacts for review.
% This helper does not train, collect, or mutate source data. It aligns the
% ADS-B next-state target, native constvel prediction, Stage 2B smoke NN
% output, optional Stage 3A/3B results, and the compact Stage 4C native
% maneuver-baseline extension.

projectRoot = fileparts(mfilename("fullpath"));
defaultDatasetPath = fullfile(projectRoot, "artifacts", "stage2B", "localADSBStatePairDataset.mat");
defaultTrainingPath = fullfile(projectRoot, "artifacts", "stage2B", "localADSBMLPSmokeTraining.mat");
defaultCharacterizationPath = fullfile(projectRoot, "artifacts", "stage2C", "stage2CManeuverCharacterization.mat");
defaultStage3TrainingPath = fullfile(projectRoot, "artifacts", "stage3", "localADSBMLPStage3Training.mat");
defaultStage3BEvaluationPath = fullfile(projectRoot, "artifacts", "stage3B", "localADSBAggregateStage3BEvaluation.mat");
defaultStage4CComparisonPath = fullfile(projectRoot, "artifacts", "stage4CRetrain", "expandedPost3DayMeanMLPComparison_v1.mat");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ProjectRoot", projectRoot);
addParameter(parser, "DatasetPath", defaultDatasetPath);
addParameter(parser, "TrainingPath", defaultTrainingPath);
addParameter(parser, "CharacterizationPath", defaultCharacterizationPath);
addParameter(parser, "Stage3TrainingPath", defaultStage3TrainingPath);
addParameter(parser, "Stage3BEvaluationPath", defaultStage3BEvaluationPath);
addParameter(parser, "Stage4CComparisonPath", defaultStage4CComparisonPath);
parse(parser, varargin{:});
opts = parser.Results;

projectRoot = string(opts.ProjectRoot);
datasetPath = string(opts.DatasetPath);
trainingPath = string(opts.TrainingPath);
characterizationPath = string(opts.CharacterizationPath);
stage3TrainingPath = string(opts.Stage3TrainingPath);
stage3BEvaluationPath = string(opts.Stage3BEvaluationPath);
stage4CComparisonPath = string(opts.Stage4CComparisonPath);

dataset = localLoadDataset(datasetPath);
training = localLoadTraining(trainingPath);
characterization = localLoadCharacterization(characterizationPath);
stage3Training = localLoadStage3Training(stage3TrainingPath);
stage3BEvaluation = localLoadStage3BEvaluation(stage3BEvaluationPath);
stage4CComparison = localLoadStage4CComparison(stage4CComparisonPath);
localValidateArtifactAlignment(dataset, training, characterization, stage3Training);

constvelPredictedState = localPredictConstvel( ...
    dataset.previousState, ...
    dataset.dtSeconds);
nnPredictedNextState = double(training.predictedNextState);

if stage3Training.hasStage3A
    stage3PredictedNextState = double(stage3Training.predictedNextState);
    stage3PredictedCovarianceDiag = double(stage3Training.predictedCovarianceDiag);
else
    stage3PredictedNextState = NaN(size(dataset.nextState));
    stage3PredictedCovarianceDiag = NaN(size(dataset.nextState));
end

pairReviewTable = localBuildPairReviewTable( ...
    dataset, ...
    characterization, ...
    constvelPredictedState, ...
    nnPredictedNextState, ...
    stage3PredictedNextState);

review = struct();
review.projectRoot = projectRoot;
review.datasetPath = datasetPath;
review.trainingPath = trainingPath;
review.characterizationPath = characterizationPath;
review.stage3TrainingPath = stage3TrainingPath;
review.stage3BEvaluationPath = stage3BEvaluationPath;
review.stage4CComparisonPath = stage4CComparisonPath;
review.hasStage3A = stage3Training.hasStage3A;
review.hasStage3B = stage3BEvaluation.hasStage3B;
review.hasStage4C = stage4CComparison.hasStage4C;
review.hasStage4CNativeManeuverBaseline = ...
    stage4CComparison.hasNativeManeuverBaseline;
review.dataset = dataset;
review.trainingSummary = training.trainingSummary;
review.characterization = characterization;
review.stage3Summary = stage3Training.stage3Summary;
review.stage3BSummary = stage3BEvaluation.stage3BSummary;
review.stage3BMetricComparisonTable = stage3BEvaluation.metricComparisonTable;
review.stage3BDataReadiness = stage3BEvaluation.dataReadiness;
review.stage3BTrackSummary = stage3BEvaluation.trackSummary;
review.stage3BPairErrorTable = stage3BEvaluation.pairErrorTable;
review.stage4CSummary = stage4CComparison.stage4CSummary;
review.stage4CNativeManeuverBaseline = ...
    stage4CComparison.nativeManeuverBaseline;
review.stage4CNativeMetricTable = stage4CComparison.nativeMetricTable;
review.constvelPredictedState = constvelPredictedState;
review.nnPredictedNextState = nnPredictedNextState;
review.stage3PredictedNextState = stage3PredictedNextState;
review.stage3PredictedCovarianceDiag = stage3PredictedCovarianceDiag;
review.nnPredictedNextStateNormalized = double(training.predictedNextStateNormalized);
review.nnPredictedVarianceNormalized = double(training.predictedVarianceNormalized);
review.pairReviewTable = pairReviewTable;
review.defaultTrackHex = localChooseDefaultTrack(characterization.trackSummary);
review.phaseSummaryTable = localBuildPhaseSummaryTable( ...
    stage3Training.hasStage3A, ...
    stage3BEvaluation.hasStage3B, ...
    stage4CComparison.hasNativeManeuverBaseline);
review.metricComparisonTable = localBuildMetricComparisonTable( ...
    dataset.baselineConstVelMetrics, ...
    training.trainingSummary, ...
    stage3Training);
review.labelRuleSummaryTable = localBuildLabelRuleSummaryTable( ...
    characterization.labelSummary.thresholds);
review.maneuverCountsTable = characterization.labelSummary.countsByManeuverClass;
review.baselineByManeuverClass = characterization.baselineByManeuverClass;
review.trackSummary = characterization.trackSummary;

end

function dataset = localLoadDataset(datasetPath)
%LOCALLOADDATASET Load the Stage 2B state-pair artifact.

try
    loaded = load(datasetPath, ...
        "previousState", ...
        "nextState", ...
        "dtSeconds", ...
        "metadata", ...
        "baselineConstVelMetrics", ...
        "buildSummary", ...
        "stateOrder", ...
        "normalization");
catch err
    error("StageReview:DatasetLoadFailed", ...
        "Failed to load Stage 2B dataset artifact: %s", err.message);
end

dataset = loaded;

end

function training = localLoadTraining(trainingPath)
%LOCALLOADTRAINING Load the saved Stage 2B smoke NN output.

try
    loaded = load(trainingPath, ...
        "trainingSummary", ...
        "predictedNextState", ...
        "predictedNextStateNormalized", ...
        "predictedVarianceNormalized");
catch err
    error("StageReview:TrainingLoadFailed", ...
        "Failed to load Stage 2B smoke training artifact: %s", err.message);
end

training = loaded;

end

function characterization = localLoadCharacterization(characterizationPath)
%LOCALLOADCHARACTERIZATION Load the Stage 2C characterization artifact.

try
    loaded = load(characterizationPath, ...
        "maneuverPairTable", ...
        "labelSummary", ...
        "baselineByManeuverClass", ...
        "trackSummary", ...
        "diversityAssessment");
catch err
    error("StageReview:CharacterizationLoadFailed", ...
        "Failed to load Stage 2C characterization artifact: %s", err.message);
end

characterization = loaded;

end

function stage3Training = localLoadStage3Training(stage3TrainingPath)
%LOCALLOADSTAGE3TRAINING Load Stage 3A only when the artifact exists.

stage3Training = struct();
stage3Training.hasStage3A = false;
stage3Training.stage3Summary = [];
stage3Training.predictedNextState = [];
stage3Training.predictedCovarianceDiag = [];

if exist(stage3TrainingPath, "file") ~= 2
    return;
end

try
    loaded = load(stage3TrainingPath, ...
        "stage3Summary", ...
        "predictedNextState", ...
        "predictedCovarianceDiag");
catch err
    error("StageReview:Stage3LoadFailed", ...
        "Failed to load Stage 3A training artifact: %s", err.message);
end

stage3Training.hasStage3A = true;
stage3Training.stage3Summary = loaded.stage3Summary;
stage3Training.predictedNextState = loaded.predictedNextState;
stage3Training.predictedCovarianceDiag = loaded.predictedCovarianceDiag;

end

function stage3BEvaluation = localLoadStage3BEvaluation(stage3BEvaluationPath)
%LOCALLOADSTAGE3BEVALUATION Load Stage 3B only when the artifact exists.

stage3BEvaluation = struct();
stage3BEvaluation.hasStage3B = false;
stage3BEvaluation.stage3BSummary = [];
stage3BEvaluation.metricComparisonTable = table();
stage3BEvaluation.dataReadiness = [];
stage3BEvaluation.trackSummary = table();
stage3BEvaluation.pairErrorTable = table();

if exist(stage3BEvaluationPath, "file") ~= 2
    return;
end

try
    loaded = load(stage3BEvaluationPath, "stage3BSummary");
catch err
    error("StageReview:Stage3BLoadFailed", ...
        "Failed to load Stage 3B evaluation artifact: %s", err.message);
end

if ~isfield(loaded, "stage3BSummary")
    error("StageReview:Stage3BMissingSummary", ...
        "The Stage 3B artifact does not contain stage3BSummary.");
end

summary = loaded.stage3BSummary;
stage3BEvaluation.hasStage3B = true;
stage3BEvaluation.stage3BSummary = summary;
stage3BEvaluation.metricComparisonTable = summary.metricComparisonTable;
stage3BEvaluation.dataReadiness = summary.dataReadiness;
stage3BEvaluation.trackSummary = summary.trackSummary;
stage3BEvaluation.pairErrorTable = summary.pairErrorTable;

end

function stage4CComparison = localLoadStage4CComparison(stage4CComparisonPath)
%LOCALLOADSTAGE4CCOMPARISON Load compact Stage 4C evaluation evidence.

stage4CComparison = struct();
stage4CComparison.hasStage4C = false;
stage4CComparison.hasNativeManeuverBaseline = false;
stage4CComparison.stage4CSummary = [];
stage4CComparison.nativeManeuverBaseline = [];
stage4CComparison.nativeMetricTable = table();

if exist(stage4CComparisonPath, "file") ~= 2
    return;
end

try
    loaded = load(stage4CComparisonPath, "stage4CSummary");
catch err
    error("StageReview:Stage4CLoadFailed", ...
        "Failed to load the Stage 4C comparison artifact: %s", ...
        err.message);
end

if ~isfield(loaded, "stage4CSummary")
    error("StageReview:Stage4CMissingSummary", ...
        "The Stage 4C artifact does not contain stage4CSummary.");
end

stage4CComparison.hasStage4C = true;
stage4CComparison.stage4CSummary = loaded.stage4CSummary;

if isfield(loaded.stage4CSummary, "nativeManeuverBaseline") && ...
        isfield( ...
        loaded.stage4CSummary.nativeManeuverBaseline, ...
        "completed") && ...
        loaded.stage4CSummary.nativeManeuverBaseline.completed
    stage4CComparison.hasNativeManeuverBaseline = true;
    stage4CComparison.nativeManeuverBaseline = ...
        loaded.stage4CSummary.nativeManeuverBaseline;
    stage4CComparison.nativeMetricTable = ...
        loaded.stage4CSummary.nativeManeuverBaseline.metrics.table;
end

end

function localValidateArtifactAlignment(dataset, training, characterization, stage3Training)
%LOCALVALIDATEARTIFACTALIGNMENT Verify saved artifact rows line up.

pairCount = size(dataset.nextState, 1);

if size(dataset.previousState, 1) ~= pairCount || numel(dataset.dtSeconds) ~= pairCount
    error("StageReview:DatasetSizeMismatch", ...
        "Stage 2B previousState, nextState, and dtSeconds row counts must match.");
end

if height(dataset.metadata) ~= pairCount
    error("StageReview:MetadataSizeMismatch", ...
        "Stage 2B metadata must contain one row per state pair.");
end

if size(training.predictedNextState, 1) ~= pairCount
    error("StageReview:TrainingSizeMismatch", ...
        "Saved NN predictions must contain one row per Stage 2B state pair.");
end

if height(characterization.maneuverPairTable) ~= pairCount
    error("StageReview:CharacterizationSizeMismatch", ...
        "Stage 2C maneuver labels must contain one row per Stage 2B state pair.");
end

if stage3Training.hasStage3A && size(stage3Training.predictedNextState, 1) ~= pairCount
    error("StageReview:Stage3SizeMismatch", ...
        "Saved Stage 3A predictions must contain one row per Stage 2B state pair.");
end

end

function predictedState = localPredictConstvel(previousState, dtSeconds)
%LOCALPREDICTCONSTVEL Apply the native constvel model to every pair.

sampleCount = size(previousState, 1);
predictedState = NaN(sampleCount, 6);

for sampleIdx = 1:sampleCount
    predictedColumn = constvel(previousState(sampleIdx, :).', dtSeconds(sampleIdx));
    predictedState(sampleIdx, :) = predictedColumn(:).';
end

end

function pairReviewTable = localBuildPairReviewTable(dataset, characterization, constvelPredictedState, nnPredictedNextState, stage3PredictedNextState)
%LOCALBUILDPAIRREVIEWTABLE Build scalar diagnostics for plotting.

positionColumns = [1, 3, 5];
velocityColumns = [2, 4, 6];
pairCount = size(dataset.nextState, 1);

constvelPositionError = constvelPredictedState(:, positionColumns) - dataset.nextState(:, positionColumns);
constvelVelocityError = constvelPredictedState(:, velocityColumns) - dataset.nextState(:, velocityColumns);
nnPositionError = nnPredictedNextState(:, positionColumns) - dataset.nextState(:, positionColumns);
nnVelocityError = nnPredictedNextState(:, velocityColumns) - dataset.nextState(:, velocityColumns);
stage3PositionError = stage3PredictedNextState(:, positionColumns) - dataset.nextState(:, positionColumns);
stage3VelocityError = stage3PredictedNextState(:, velocityColumns) - dataset.nextState(:, velocityColumns);

pairReviewTable = table( ...
    (1:pairCount).', ...
    dataset.metadata.sessionID, ...
    dataset.metadata.hex, ...
    dataset.metadata.callsign, ...
    dataset.metadata.timeUtcK, ...
    dataset.metadata.timeUtcNext, ...
    dataset.dtSeconds, ...
    characterization.maneuverPairTable.maneuverClass, ...
    characterization.maneuverPairTable.verticalStatus, ...
    characterization.maneuverPairTable.absTurnRateDegreesPerSecond, ...
    abs(characterization.maneuverPairTable.horizontalAccelerationMetersPerSecondSquared), ...
    abs(characterization.maneuverPairTable.verticalAccelerationMetersPerSecondSquared), ...
    vecnorm(constvelPositionError, 2, 2), ...
    vecnorm(constvelVelocityError, 2, 2), ...
    vecnorm(nnPositionError, 2, 2), ...
    vecnorm(nnVelocityError, 2, 2), ...
    vecnorm(stage3PositionError, 2, 2), ...
    vecnorm(stage3VelocityError, 2, 2), ...
    'VariableNames', [ ...
        "pairIndex", ...
        "sessionID", ...
        "hex", ...
        "callsign", ...
        "timeUtcK", ...
        "timeUtcNext", ...
        "dtSeconds", ...
        "maneuverClass", ...
        "verticalStatus", ...
        "absTurnRateDegreesPerSecond", ...
        "absHorizontalAccelerationMetersPerSecondSquared", ...
        "absVerticalAccelerationMetersPerSecondSquared", ...
        "constvelPositionErrorMeters", ...
        "constvelVelocityErrorMetersPerSecond", ...
        "nnSmokePositionErrorMeters", ...
        "nnSmokeVelocityErrorMetersPerSecond", ...
        "stage3PositionErrorMeters", ...
        "stage3VelocityErrorMetersPerSecond"]);

end

function defaultTrackHex = localChooseDefaultTrack(trackSummary)
%LOCALCHOOSEDEFAULTTRACK Pick a clean, high-count review track.

if isempty(trackSummary) || height(trackSummary) == 0
    defaultTrackHex = "";
    return;
end

constvelShare = trackSummary.constvelLikePairCount ./ trackSummary.pairCount;
candidateMask = trackSummary.pairCount >= 40 & constvelShare >= 0.70;

if any(candidateMask)
    candidateTable = trackSummary(candidateMask, :);
else
    candidateTable = trackSummary;
end

score = candidateTable.pairCount + candidateTable.constvelLikePairCount;
[~, bestIdx] = max(score);
defaultTrackHex = string(candidateTable.hex(bestIdx));

end

function phaseSummaryTable = localBuildPhaseSummaryTable( ...
        hasStage3A, hasStage3B, hasStage4CNative)
%LOCALBUILDPHASESUMMARYTABLE Summarize project progress for the Live Script.

phase = ["Stage 1"; "Stage 2A"; "Stage 2B"; "Stage 2C"];
latestOutcome = [ ...
    "Literature and toolbox review selected MATLAB-native constvel and a simple MLP prediction-step smoke path."; ...
    "OpenSky access was validated, then local ADS-B was kept as the primary data path."; ...
    "Local ADS-B was converted into one-step ENU state pairs and a minimal MLP was trained only as a plumbing check."; ...
    "Existing state pairs were labeled by observed motion regime and scored by constvel baseline class."];
status = [ ...
    "Complete"; ...
    "Complete"; ...
    "Complete, but the MLP is not a quality result"; ...
    "Complete, and current data lacks maneuver diversity"];

if hasStage3A
    phase = [phase; "Stage 3A"];
    latestOutcome = [latestOutcome; "Delta-target MLP training artifact exists; compare it against constvel and the Stage 2B smoke MLP without making broad maneuver claims."];
    status = [status; "Complete enough for review artifact comparison"];
else
    phase = [phase; "Stage 3A"];
    latestOutcome = [latestOutcome; "No Stage 3A artifact found yet; review remains Stage 2B/2C focused."];
    status = [status; "Pending"];
end

if hasStage3B
    phase = [phase; "Stage 3B"];
    latestOutcome = [latestOutcome; "Aggregate ADS-B evaluation artifact exists; frozen Stage 3A MLP and constvel are compared on identical local ADS-B samples."];
    status = [status; "Complete as an evaluation and data-readiness gate"];
else
    phase = [phase; "Stage 3B"];
    latestOutcome = [latestOutcome; "No Stage 3B aggregate evaluation artifact found yet."];
    status = [status; "Pending"];
end

if hasStage4CNative
    phase = [phase; "Stage 4C"];
    latestOutcome = [ ...
        latestOutcome; ...
        "Frozen Stage 4C models are compared with causal native constacc and constturn baselines on matched maneuver rows."];
    status = [ ...
        status; ...
        "Complete as an evaluation-only maneuver-baseline extension"];
else
    phase = [phase; "Stage 4C"];
    latestOutcome = [ ...
        latestOutcome; ...
        "No completed native constacc/constturn maneuver-baseline extension was found."];
    status = [status; "Pending"];
end

phaseSummaryTable = table(phase, latestOutcome, status, ...
    'VariableNames', ["phase", "latestOutcome", "status"]);

end

function metricComparisonTable = localBuildMetricComparisonTable(baselineConstVelMetrics, trainingSummary, stage3Training)
%LOCALBUILDMETRICCOMPARISONTABLE Compare native baseline and NN artifacts.

method = ["constvel baseline"; "smoke MLP"];
positionRMSEMeters = [ ...
    baselineConstVelMetrics.positionRMSEMeters; ...
    trainingSummary.modelPositionRMSEMeters];
velocityRMSEMetersPerSecond = [ ...
    baselineConstVelMetrics.velocityRMSEMetersPerSecond; ...
    trainingSummary.modelVelocityRMSEMetersPerSecond];
interpretation = [ ...
    "Native Sensor Fusion motion model"; ...
    "Three-epoch neural network smoke test, not a usable predictor"];

if stage3Training.hasStage3A && ~isempty(stage3Training.stage3Summary.metrics)
    stage3Aggregate = stage3Training.stage3Summary.metrics.aggregate;
    method = [method; "Stage 3A delta MLP"];
    positionRMSEMeters = [positionRMSEMeters; stage3Aggregate.positionRMSEMeters(1)];
    velocityRMSEMetersPerSecond = [velocityRMSEMetersPerSecond; stage3Aggregate.velocityRMSEMetersPerSecond(1)];
    interpretation = [interpretation; "Delta-target MLP reconstructed as previousState + predictedDelta"];
end

metricComparisonTable = table( ...
    method, ...
    positionRMSEMeters, ...
    velocityRMSEMetersPerSecond, ...
    interpretation, ...
    'VariableNames', [ ...
        "method", ...
        "positionRMSEMeters", ...
        "velocityRMSEMetersPerSecond", ...
        "interpretation"]);

end

function labelRuleSummaryTable = localBuildLabelRuleSummaryTable(thresholds)
%LOCALBUILDLABELRULESUMMARYTABLE Explain the Stage 2C diagnostic labels.

labelRuleSummaryTable = table( ...
    ["constvel_like"; "constacc_like"; "constturn_like"; "mixed_or_sparse"], ...
    [ ...
        "Low heading-rate, low speed change, low vertical-rate change, and regular dt."; ...
        "Speed or vertical-rate change crosses threshold without turn dominance."; ...
        "Heading change and turn-rate cross thresholds without acceleration dominance."; ...
        "Sparse update, or both turn-like and acceleration-like behavior in the same pair."], ...
    [ ...
        sprintf("Turn rate < %.1f deg/s, speed change < %.1f m/s, vertical-rate change < %.1f m/s.", thresholds.turnRateDegreesPerSecond, thresholds.speedChangeMetersPerSecond, thresholds.verticalRateChangeMetersPerSecond); ...
        sprintf("Speed change >= %.1f m/s or acceleration >= %.1f m/s^2, or vertical-rate change crosses %.1f m/s.", thresholds.speedChangeMetersPerSecond, thresholds.horizontalAccelerationMetersPerSecondSquared, thresholds.verticalRateChangeMetersPerSecond); ...
        sprintf("Heading change >= %.1f deg and turn rate >= %.1f deg/s.", thresholds.headingChangeDegrees, thresholds.turnRateDegreesPerSecond); ...
        sprintf("dt >= %.1f s, or mixed turn and acceleration indicators.", thresholds.sparseUpdateSeconds)], ...
    'VariableNames', ["label", "meaning", "thresholdRule"]);

end
