function baselineByManeuverClass = helperScoreConstVelByManeuverClass(previousState, nextState, dtSeconds, maneuverClass)
%HELPERSCORECONSTVELBYMANEUVERCLASS Score constvel separately by label.

previousState = double(previousState);
nextState = double(nextState);
dtSeconds = double(dtSeconds(:));

if ~iscategorical(maneuverClass)
    maneuverClass = categorical(string(maneuverClass));
end

maneuverClass = maneuverClass(:);

if size(previousState, 1) ~= numel(maneuverClass)
    error("Stage2C:ClassSizeMismatch", ...
        "maneuverClass must contain one label for each state pair.");
end

classNames = string(categories(maneuverClass));
classCount = numel(classNames);

sampleCount = zeros(classCount, 1);
positionRMSEMeters = NaN(classCount, 1);
velocityRMSEMetersPerSecond = NaN(classCount, 1);
positionMedianErrorMeters = NaN(classCount, 1);
velocityMedianErrorMetersPerSecond = NaN(classCount, 1);
positionP95ErrorMeters = NaN(classCount, 1);
velocityP95ErrorMetersPerSecond = NaN(classCount, 1);

for classIdx = 1:classCount
    className = classNames(classIdx);
    classMask = maneuverClass == className;
    sampleCount(classIdx) = sum(classMask);

    if sampleCount(classIdx) == 0
        continue;
    end

    classMetrics = helperScoreConstVelBaseline( ...
        previousState(classMask, :), ...
        nextState(classMask, :), ...
        dtSeconds(classMask));

    positionRMSEMeters(classIdx) = classMetrics.positionRMSEMeters;
    velocityRMSEMetersPerSecond(classIdx) = classMetrics.velocityRMSEMetersPerSecond;
    positionMedianErrorMeters(classIdx) = classMetrics.positionMedianErrorMeters;
    velocityMedianErrorMetersPerSecond(classIdx) = classMetrics.velocityMedianErrorMetersPerSecond;
    positionP95ErrorMeters(classIdx) = classMetrics.positionP95ErrorMeters;
    velocityP95ErrorMetersPerSecond(classIdx) = classMetrics.velocityP95ErrorMetersPerSecond;
end

baselineByManeuverClass = table( ...
    classNames(:), ...
    sampleCount, ...
    positionRMSEMeters, ...
    velocityRMSEMetersPerSecond, ...
    positionMedianErrorMeters, ...
    velocityMedianErrorMetersPerSecond, ...
    positionP95ErrorMeters, ...
    velocityP95ErrorMetersPerSecond, ...
    'VariableNames', [ ...
        "maneuverClass", ...
        "sampleCount", ...
        "positionRMSEMeters", ...
        "velocityRMSEMetersPerSecond", ...
        "positionMedianErrorMeters", ...
        "velocityMedianErrorMetersPerSecond", ...
        "positionP95ErrorMeters", ...
        "velocityP95ErrorMetersPerSecond"]);

end
