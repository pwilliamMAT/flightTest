function [rebasedNet, audit] = helperRebaseStage3ANetworkNormalization( ...
        oldNet, ...
        oldFeatureNormalization, ...
        oldTargetNormalization, ...
        newFeatureNormalization, ...
        newTargetNormalization, ...
        physicalFeatures, ...
        previousState)
%HELPERREBASESTAGE3ANETWORKNORMALIZATION Re-express Stage 3A weights.
% Rebasing changes only the first and output affine layers. The transformed
% network therefore makes the same physical state-delta prediction when its
% inputs and outputs use the new Expanded-3Day normalization.

localValidateInputs( ...
    oldNet, ...
    oldFeatureNormalization, ...
    oldTargetNormalization, ...
    newFeatureNormalization, ...
    newTargetNormalization, ...
    physicalFeatures, ...
    previousState);

oldFeatureMean = double(oldFeatureNormalization.featureMean(:).');
oldFeatureStd = double(oldFeatureNormalization.featureStd(:).');
newFeatureMean = double(newFeatureNormalization.featureMean(:).');
newFeatureStd = double(newFeatureNormalization.featureStd(:).');
oldTargetMean = double(oldTargetNormalization.targetMean(:).');
oldTargetStd = double(oldTargetNormalization.targetStd(:).');
newTargetMean = double(newTargetNormalization.targetMean(:).');
newTargetStd = double(newTargetNormalization.targetStd(:).');

% If z_new = (x - mu_new)/sigma_new, then the equivalent old normalized
% input is z_old = inputScale*z_new + inputOffset.
inputScale = newFeatureStd ./ oldFeatureStd;
inputOffset = (newFeatureMean - oldFeatureMean) ./ oldFeatureStd;

% A physical output represented in the new target coordinates is an affine
% transform of the old normalized output.
outputScale = oldTargetStd ./ newTargetStd;
outputOffset = (oldTargetMean - newTargetMean) ./ newTargetStd;

rebasedNet = oldNet;
learnables = rebasedNet.Learnables;

fc1WeightRow = localFindLearnable(learnables, "fc1", "Weights");
fc1BiasRow = localFindLearnable(learnables, "fc1", "Bias");
outputWeightRow = localFindLearnable(learnables, "prediction", "Weights");
outputBiasRow = localFindLearnable(learnables, "prediction", "Bias");

oldFirstWeights = extractdata(learnables.Value{fc1WeightRow});
oldFirstBias = extractdata(learnables.Value{fc1BiasRow});
oldOutputWeights = extractdata(learnables.Value{outputWeightRow});
oldOutputBias = extractdata(learnables.Value{outputBiasRow});

inputScaleLike = cast(inputScale, "like", oldFirstWeights);
inputOffsetLike = cast(inputOffset(:), "like", oldFirstWeights);
outputScaleLike = cast(outputScale(:), "like", oldOutputWeights);
outputOffsetLike = cast(outputOffset(:), "like", oldOutputWeights);

newFirstWeights = oldFirstWeights .* inputScaleLike;
newFirstBias = oldFirstBias + oldFirstWeights * inputOffsetLike;
newOutputWeights = oldOutputWeights .* outputScaleLike;
newOutputBias = oldOutputBias .* outputScaleLike + outputOffsetLike;

learnables.Value{fc1WeightRow} = dlarray(newFirstWeights);
learnables.Value{fc1BiasRow} = dlarray(newFirstBias);
learnables.Value{outputWeightRow} = dlarray(newOutputWeights);
learnables.Value{outputBiasRow} = dlarray(newOutputBias);
rebasedNet.Learnables = learnables;

oldFeaturesNormalized = ...
    (double(physicalFeatures) - oldFeatureMean) ./ oldFeatureStd;
newFeaturesNormalized = ...
    (double(physicalFeatures) - newFeatureMean) ./ newFeatureStd;
oldOutputNormalized = localPredict(oldNet, oldFeaturesNormalized);
newOutputNormalized = localPredict(rebasedNet, newFeaturesNormalized);
oldPhysicalDelta = oldOutputNormalized .* oldTargetStd + oldTargetMean;
newPhysicalDelta = newOutputNormalized .* newTargetStd + newTargetMean;
oldPhysicalState = double(previousState) + oldPhysicalDelta;
newPhysicalState = double(previousState) + newPhysicalDelta;

maxAbsDeltaDifference = max( ...
    abs(oldPhysicalDelta - newPhysicalDelta), [], "all");
maxAbsStateDifference = max( ...
    abs(oldPhysicalState - newPhysicalState), [], "all");
% Scale the tolerance from the predicted delta, not absolute ENU position.
% Otherwise a large local coordinate could hide a meaningful rebase error.
referenceScale = max(1, max(abs(oldPhysicalDelta), [], "all"));
tolerance = max(1e-5, 1e-5 * referenceScale);
passed = isfinite(maxAbsStateDifference) && ...
    maxAbsStateDifference <= tolerance;

audit = struct();
audit.checkedSampleCount = size(physicalFeatures, 1);
audit.firstLayerName = "fc1";
audit.outputLayerName = "prediction";
audit.inputScale = inputScale;
audit.inputOffset = inputOffset;
audit.outputScale = outputScale;
audit.outputOffset = outputOffset;
audit.maxAbsPhysicalDeltaDifference = maxAbsDeltaDifference;
audit.maxAbsPhysicalStateDifference = maxAbsStateDifference;
audit.tolerance = tolerance;
audit.passed = passed;

if ~passed
    error("Stage4C:WarmStartRebaseMismatch", ...
        "Warm-start rebasing changed physical predictions by %.9g; tolerance is %.9g.", ...
        maxAbsStateDifference, ...
        tolerance);
end

end

function localValidateInputs( ...
        oldNet, ...
        oldFeatureNormalization, ...
        oldTargetNormalization, ...
        newFeatureNormalization, ...
        newTargetNormalization, ...
        physicalFeatures, ...
        previousState)
%LOCALVALIDATEINPUTS Validate dimensions and normalization contracts.

if ~isa(oldNet, "dlnetwork") || ~oldNet.Initialized
    error("Stage4C:InvalidWarmStartNetwork", ...
        "The warm-start source must be an initialized dlnetwork.");
end

localValidateNormalization( ...
    oldFeatureNormalization, "featureMean", "featureStd", 20);
localValidateNormalization( ...
    newFeatureNormalization, "featureMean", "featureStd", 20);
localValidateNormalization( ...
    oldTargetNormalization, "targetMean", "targetStd", 6);
localValidateNormalization( ...
    newTargetNormalization, "targetMean", "targetStd", 6);

validateattributes(physicalFeatures, ...
    {'numeric'}, {'2d', 'real', 'finite', 'ncols', 20}, ...
    mfilename, "physicalFeatures");
validateattributes(previousState, ...
    {'numeric'}, {'2d', 'real', 'finite', 'ncols', 6}, ...
    mfilename, "previousState");

if size(physicalFeatures, 1) ~= size(previousState, 1)
    error("Stage4C:RebaseSampleSizeMismatch", ...
        "physicalFeatures and previousState must have the same row count.");
end

if isfield(oldFeatureNormalization, "featureNames") && ...
        isfield(newFeatureNormalization, "featureNames")
    oldNames = string(oldFeatureNormalization.featureNames(:));
    newNames = string(newFeatureNormalization.featureNames(:));

    if numel(oldNames) ~= numel(newNames) || any(oldNames ~= newNames)
        error("Stage4C:RebaseFeatureNameMismatch", ...
            "Old and new feature normalization must use the same feature order.");
    end
end

end

function localValidateNormalization(value, meanField, stdField, expectedWidth)
%LOCALVALIDATENORMALIZATION Check one affine normalization definition.

if ~isstruct(value) || ...
        ~isfield(value, meanField) || ...
        ~isfield(value, stdField)
    error("Stage4C:InvalidNormalization", ...
        "Normalization is missing %s or %s.", meanField, stdField);
end

meanValue = double(value.(meanField));
stdValue = double(value.(stdField));

if numel(meanValue) ~= expectedWidth || ...
        numel(stdValue) ~= expectedWidth || ...
        any(~isfinite(meanValue), "all") || ...
        any(~isfinite(stdValue), "all") || ...
        any(stdValue <= 0, "all")
    error("Stage4C:InvalidNormalization", ...
        "Normalization fields must be finite and have %d positive scales.", ...
        expectedWidth);
end

end

function row = localFindLearnable(learnables, layerName, parameterName)
%LOCALFINDLEARNABLE Find one named affine parameter.

mask = string(learnables.Layer) == layerName & ...
    string(learnables.Parameter) == parameterName;

if sum(mask) ~= 1
    error("Stage4C:WarmStartArchitectureMismatch", ...
        "Expected one %s/%s learnable parameter.", ...
        layerName, ...
        parameterName);
end

row = find(mask);

end

function output = localPredict(net, input)
%LOCALPREDICT Return observations by output variables as a double matrix.

output = minibatchpredict( ...
    net, ...
    single(input), ...
    "MiniBatchSize", ...
    min(8192, size(input, 1)));
output = double(gather(extractdata(output)));

if size(output, 1) ~= size(input, 1) && ...
        size(output, 2) == size(input, 1)
    output = output.';
end

if size(output, 1) ~= size(input, 1) || size(output, 2) ~= 6
    error("Stage4C:RebasePredictionShapeMismatch", ...
        "Warm-start equivalence predictions must be N-by-6.");
end

end
