function normalization = helperComputeADSBNormalization(previousState, previousCovarianceDiag, dtSeconds, nextState, split)
%HELPERCOMPUTEADSBNORMALIZATION Compute train-split normalization constants.
% The train-only policy avoids teaching later validation/test rows to the
% preprocessing stage, even for this smoke dataset.

split = string(split);
trainMask = split == "train";

if ~any(trainMask)
    error("Stage2B:NoTrainingRows", ...
        "At least one training row is required to compute normalization.");
end

previousStateMean = mean(previousState(trainMask, :), 1, "omitnan");
previousStateStd = std(previousState(trainMask, :), 0, 1, "omitnan");
previousCovarianceDiagMean = mean(previousCovarianceDiag(trainMask, :), 1, "omitnan");
previousCovarianceDiagStd = std(previousCovarianceDiag(trainMask, :), 0, 1, "omitnan");
dtMean = mean(dtSeconds(trainMask), "omitnan");
dtStd = std(dtSeconds(trainMask), 0, "omitnan");
nextStateMean = mean(nextState(trainMask, :), 1, "omitnan");
nextStateStd = std(nextState(trainMask, :), 0, 1, "omitnan");

previousStateStd = localGuardStandardDeviation(previousStateStd);
previousCovarianceDiagStd = localGuardStandardDeviation(previousCovarianceDiagStd);
dtStd = localGuardStandardDeviation(dtStd);
nextStateStd = localGuardStandardDeviation(nextStateStd);

normalization = struct();
normalization.computedFromSplit = "train";
normalization.trainRowCount = sum(trainMask);
normalization.previousStateMean = previousStateMean;
normalization.previousStateStd = previousStateStd;
normalization.previousCovarianceDiagMean = previousCovarianceDiagMean;
normalization.previousCovarianceDiagStd = previousCovarianceDiagStd;
normalization.dtMean = dtMean;
normalization.dtStd = dtStd;
normalization.nextStateMean = nextStateMean;
normalization.nextStateStd = nextStateStd;
normalization.inputMean = [previousStateMean, previousCovarianceDiagMean, dtMean];
normalization.inputStd = [previousStateStd, previousCovarianceDiagStd, dtStd];
normalization.targetMean = nextStateMean;
normalization.targetStd = nextStateStd;

end

function guardedStd = localGuardStandardDeviation(inputStd)
%LOCALGUARDSTANDARDDEVIATION Prevent divide-by-zero in constant channels.

guardedStd = inputStd;
badStd = ~isfinite(guardedStd) | guardedStd <= 0;
guardedStd(badStd) = 1;

end
