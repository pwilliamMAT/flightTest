function trainingSummary = trainLocalADSBMLPSmoke(datasetPath, varargin)
%TRAINLOCALADSBMLPSMOKE Run a minimal MLP smoke-training pass.
% This is only an interface and numerical-health check. It trains for a few
% epochs and verifies finite loss, output dimensions, and positive diagonal
% variance outputs.

projectRoot = fileparts(mfilename("fullpath"));
defaultOutputFolder = fullfile(projectRoot, "artifacts", "stage2B");
defaultDatasetPath = fullfile(defaultOutputFolder, "localADSBStatePairDataset.mat");
defaultOutputPath = fullfile(defaultOutputFolder, "localADSBMLPSmokeTraining.mat");
defaultReportPath = fullfile(defaultOutputFolder, "stage2BLocalADSBSmokeSummary.md");

if nargin < 1 || isempty(datasetPath)
    datasetPath = defaultDatasetPath;
end

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "OutputPath", defaultOutputPath);
addParameter(parser, "ReportPath", defaultReportPath);
addParameter(parser, "NumEpochs", 3);
addParameter(parser, "MiniBatchSize", 128);
addParameter(parser, "LearnRate", 1e-3);
addParameter(parser, "VarianceEpsilon", 1e-6);
addParameter(parser, "HiddenUnits", 32);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});
opts = parser.Results;

datasetPath = string(datasetPath);
outputPath = string(opts.OutputPath);
reportPath = string(opts.ReportPath);
numEpochs = double(opts.NumEpochs);
miniBatchSize = double(opts.MiniBatchSize);
learnRate = double(opts.LearnRate);
varianceEpsilon = double(opts.VarianceEpsilon);
hiddenUnits = double(opts.HiddenUnits);
verbose = logical(opts.Verbose);

validateattributes(numEpochs, {'numeric'}, {'scalar', 'integer', 'positive'}, ...
    mfilename, "NumEpochs");
validateattributes(miniBatchSize, {'numeric'}, {'scalar', 'integer', 'positive'}, ...
    mfilename, "MiniBatchSize");
validateattributes(learnRate, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, "LearnRate");
validateattributes(varianceEpsilon, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, "VarianceEpsilon");

try
    loaded = load(datasetPath, ...
        "previousState", ...
        "nextState", ...
        "dtSeconds", ...
        "previousCovarianceDiag", ...
        "metadata", ...
        "normalization", ...
        "baselineConstVelMetrics", ...
        "buildSummary", ...
        "sourceManifest", ...
        "splitManifest", ...
        "stateOrder", ...
        "covarianceStdAssumed");
catch err
    error("Stage2B:DatasetLoadFailed", ...
        "Failed to load dataset artifact: %s", err.message);
end

normalization = loaded.normalization;
features = [loaded.previousState, loaded.previousCovarianceDiag, loaded.dtSeconds];
featuresNormalized = (features - normalization.inputMean) ./ normalization.inputStd;
targetsNormalized = (loaded.nextState - normalization.targetMean) ./ normalization.targetStd;

if any(~isfinite(featuresNormalized), "all") || any(~isfinite(targetsNormalized), "all")
    error("Stage2B:NonfiniteTrainingData", ...
        "Normalized smoke-training inputs and targets must be finite.");
end

trainMask = loaded.metadata.split == "train";

if ~any(trainMask)
    error("Stage2B:NoTrainingRows", ...
        "Dataset does not contain training rows.");
end

featureCount = size(featuresNormalized, 2);
outputCount = 12;

layers = [
    featureInputLayer(featureCount, "Normalization", "none", "Name", "features")
    fullyConnectedLayer(hiddenUnits, "Name", "fc1")
    reluLayer("Name", "relu1")
    fullyConnectedLayer(hiddenUnits, "Name", "fc2")
    reluLayer("Name", "relu2")
    fullyConnectedLayer(outputCount, "Name", "prediction")];

net = dlnetwork(layerGraph(layers));

XTrain = featuresNormalized(trainMask, :);
YTrain = targetsNormalized(trainMask, :);
trainCount = size(XTrain, 1);
lossHistory = NaN(numEpochs, 1);
iteration = 0;
trailingAverage = [];
trailingAverageSquared = [];
rng(123, "twister");

for epochIdx = 1:numEpochs
    rowOrder = randperm(trainCount);
    batchLosses = zeros(ceil(trainCount / miniBatchSize), 1);
    batchIdx = 0;

    for startIdx = 1:miniBatchSize:trainCount
        batchIdx = batchIdx + 1;
        stopIdx = min(startIdx + miniBatchSize - 1, trainCount);
        rows = rowOrder(startIdx:stopIdx);

        dlX = dlarray(XTrain(rows, :).', "CB");
        dlY = dlarray(YTrain(rows, :).', "CB");

        [loss, gradients] = dlfeval( ...
            @localModelLoss, ...
            net, ...
            dlX, ...
            dlY, ...
            varianceEpsilon);

        iteration = iteration + 1;
        [net, trailingAverage, trailingAverageSquared] = adamupdate( ...
            net, ...
            gradients, ...
            trailingAverage, ...
            trailingAverageSquared, ...
            iteration, ...
            learnRate);

        batchLosses(batchIdx) = double(extractdata(loss));
    end

    lossHistory(epochIdx) = mean(batchLosses, "omitnan");

    if verbose
        fprintf("MLP smoke epoch\t%d/%d\tloss\t%.6f\n", ...
            epochIdx, ...
            numEpochs, ...
            lossHistory(epochIdx));
    end
end

dlAllFeatures = dlarray(featuresNormalized.', "CB");
dlPredictions = predict(net, dlAllFeatures);
predictionMatrix = extractdata(dlPredictions).';
predictedNextStateNormalized = predictionMatrix(:, 1:6);
rawVariance = predictionMatrix(:, 7:12);
predictedVarianceNormalized = localSoftplus(rawVariance) + varianceEpsilon;
predictedNextState = predictedNextStateNormalized .* normalization.targetStd + normalization.targetMean;

positionColumns = [1, 3, 5];
velocityColumns = [2, 4, 6];
modelPositionError = predictedNextState(:, positionColumns) - loaded.nextState(:, positionColumns);
modelVelocityError = predictedNextState(:, velocityColumns) - loaded.nextState(:, velocityColumns);
modelPositionErrorNorm = vecnorm(modelPositionError, 2, 2);
modelVelocityErrorNorm = vecnorm(modelVelocityError, 2, 2);

normalizedResidual = predictedNextStateNormalized - targetsNormalized;
normalizedSigma = sqrt(predictedVarianceNormalized);
empiricalOneSigmaCoverage = mean(abs(normalizedResidual) <= normalizedSigma, "all");
empiricalTwoSigmaCoverage = mean(abs(normalizedResidual) <= 2 * normalizedSigma, "all");

trainingSummary = struct();
trainingSummary.generatedAt = datetime("now", "TimeZone", "UTC");
trainingSummary.datasetPath = datasetPath;
trainingSummary.outputPath = outputPath;
trainingSummary.numEpochs = numEpochs;
trainingSummary.miniBatchSize = miniBatchSize;
trainingSummary.learnRate = learnRate;
trainingSummary.varianceEpsilon = varianceEpsilon;
trainingSummary.hiddenUnits = hiddenUnits;
trainingSummary.trainCount = trainCount;
trainingSummary.validationCount = sum(loaded.metadata.split == "validation");
trainingSummary.testCount = sum(loaded.metadata.split == "test");
trainingSummary.lossHistory = lossHistory;
trainingSummary.finalLoss = lossHistory(end);
trainingSummary.finiteLoss = all(isfinite(lossHistory));
trainingSummary.outputSize = size(predictionMatrix);
trainingSummary.correctOutputDimensions = isequal(size(predictionMatrix), [size(featuresNormalized, 1), outputCount]);
trainingSummary.positivePredictedVariances = all(predictedVarianceNormalized > 0, "all");
trainingSummary.minimumPredictedVariance = min(predictedVarianceNormalized, [], "all");
trainingSummary.modelPositionRMSEMeters = sqrt(mean(modelPositionErrorNorm .^ 2, "omitnan"));
trainingSummary.modelVelocityRMSEMetersPerSecond = sqrt(mean(modelVelocityErrorNorm .^ 2, "omitnan"));
trainingSummary.empiricalOneSigmaCoverage = empiricalOneSigmaCoverage;
trainingSummary.empiricalTwoSigmaCoverage = empiricalTwoSigmaCoverage;
trainingSummary.baselineConstVelMetrics = loaded.baselineConstVelMetrics;
trainingSummary.stateOrder = loaded.stateOrder;

if ~trainingSummary.finiteLoss
    error("Stage2B:NonfiniteLoss", ...
        "MLP smoke training produced a nonfinite loss.");
end

if ~trainingSummary.correctOutputDimensions
    error("Stage2B:BadOutputDimensions", ...
        "MLP smoke output dimensions did not match N x 12.");
end

if ~trainingSummary.positivePredictedVariances
    error("Stage2B:NonpositiveVariance", ...
        "MLP smoke training produced nonpositive variance outputs.");
end

try
    outputFolder = fileparts(outputPath);

    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    save(outputPath, ...
        "trainingSummary", ...
        "net", ...
        "predictionMatrix", ...
        "predictedNextStateNormalized", ...
        "predictedVarianceNormalized", ...
        "predictedNextState", ...
        "-v7.3");
catch err
    error("Stage2B:TrainingSaveFailed", ...
        "Failed to save MLP smoke-training artifact: %s", err.message);
end

dataset = struct();
dataset.previousState = loaded.previousState;
dataset.nextState = loaded.nextState;
dataset.dtSeconds = loaded.dtSeconds;
dataset.previousCovarianceDiag = loaded.previousCovarianceDiag;
dataset.metadata = loaded.metadata;
dataset.stateOrder = loaded.stateOrder;
dataset.covarianceStdAssumed = loaded.covarianceStdAssumed;
dataset.normalization = loaded.normalization;
dataset.sourceManifest = loaded.sourceManifest;
dataset.splitManifest = loaded.splitManifest;
dataset.buildSummary = loaded.buildSummary;
dataset.baselineConstVelMetrics = loaded.baselineConstVelMetrics;

helperWriteStage2BReport(reportPath, dataset, trainingSummary);

if verbose
    fprintf("MLP smoke final loss:\t%.6f\n", trainingSummary.finalLoss);
    fprintf("Output dimensions:\t%d x %d\n", trainingSummary.outputSize(1), trainingSummary.outputSize(2));
    fprintf("Minimum predicted variance:\t%.6g\n", trainingSummary.minimumPredictedVariance);
    fprintf("Training artifact written:\t%s\n", outputPath);
    fprintf("Summary report written:\t%s\n", reportPath);
end

end

function [loss, gradients] = localModelLoss(net, dlX, dlY, varianceEpsilon)
%LOCALMODELLOSS Diagonal Gaussian NLL in normalized state space.

dlPrediction = forward(net, dlX);
predictedMean = dlPrediction(1:6, :);
rawVariance = dlPrediction(7:12, :);
variance = log(1 + exp(rawVariance)) + varianceEpsilon;
residual = predictedMean - dlY;
negativeLogLikelihood = 0.5 * (log(variance) + (residual .^ 2) ./ variance);
loss = mean(negativeLogLikelihood, "all");
gradients = dlgradient(loss, net.Learnables);

end

function value = localSoftplus(rawValue)
%LOCALSOFTPLUS Convert raw variance parameters to positive variances.

value = log(1 + exp(rawValue));

end
