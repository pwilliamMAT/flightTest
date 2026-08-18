function baselineConstVelMetrics = helperScoreConstVelBaseline(previousState, nextState, dtSeconds)
%HELPERSCORECONSTVELBASELINE Score Sensor Fusion constvel predictions.
% ADS-B samples arrive at irregular intervals, so each row dispatches one
% native constvel call with that row's dt. The motion math stays inside the
% Sensor Fusion and Tracking Toolbox implementation.

sampleCount = size(previousState, 1);
predictedState = NaN(sampleCount, 6);

for sampleIdx = 1:sampleCount
    predictedColumn = constvel(previousState(sampleIdx, :).', dtSeconds(sampleIdx));
    predictedState(sampleIdx, :) = predictedColumn(:).';
end

positionColumns = [1, 3, 5];
velocityColumns = [2, 4, 6];

positionError = predictedState(:, positionColumns) - nextState(:, positionColumns);
velocityError = predictedState(:, velocityColumns) - nextState(:, velocityColumns);
positionErrorNorm = vecnorm(positionError, 2, 2);
velocityErrorNorm = vecnorm(velocityError, 2, 2);

baselineConstVelMetrics = struct();
baselineConstVelMetrics.sampleCount = sampleCount;
baselineConstVelMetrics.positionRMSEMeters = sqrt(mean(positionErrorNorm .^ 2, "omitnan"));
baselineConstVelMetrics.velocityRMSEMetersPerSecond = sqrt(mean(velocityErrorNorm .^ 2, "omitnan"));
baselineConstVelMetrics.positionComponentRMSEMeters = sqrt(mean(positionError .^ 2, 1, "omitnan"));
baselineConstVelMetrics.velocityComponentRMSEMetersPerSecond = sqrt(mean(velocityError .^ 2, 1, "omitnan"));
baselineConstVelMetrics.positionMedianErrorMeters = median(positionErrorNorm, "omitnan");
baselineConstVelMetrics.velocityMedianErrorMetersPerSecond = median(velocityErrorNorm, "omitnan");
baselineConstVelMetrics.positionP95ErrorMeters = prctile(positionErrorNorm, 95);
baselineConstVelMetrics.velocityP95ErrorMetersPerSecond = prctile(velocityErrorNorm, 95);
baselineConstVelMetrics.positionMeanErrorMeters = mean(positionErrorNorm, "omitnan");
baselineConstVelMetrics.velocityMeanErrorMetersPerSecond = mean(velocityErrorNorm, "omitnan");
baselineConstVelMetrics.stateOrder = ["x", "vx", "y", "vy", "z", "vz"];
baselineConstVelMetrics.predictedState = predictedState;

end
