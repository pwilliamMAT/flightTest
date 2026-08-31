function cost = helperStage4ETuningCost(trackHistory, truth)
%HELPERSTAGE4ETUNINGCOST Score physical six-state validation RMSE.
% The custom cost lets trackingFilterTuner compare CV, CA, CT, IMM, and
% warm-UKF states through the same [x,vx,y,vy,z,vz] interface.

if iscell(trackHistory)
    perEventCost = cellfun( ...
        @helperStage4ETuningCost, ...
        trackHistory(:), ...
        truth(:));
    cost = mean(perEventCost);
    return;
end

truthState = double(truth.State);
sampleCount = numel(trackHistory);
estimatedState = zeros(sampleCount, 6);

for sampleIdx = 1:sampleCount
    estimatedState(sampleIdx, :) = localPhysicalState( ...
        trackHistory(sampleIdx).State);
end

stateScale = [100, 10, 100, 10, 150, 5];
normalizedError = ...
    (estimatedState - truthState) ./ stateScale;
cost = sqrt(mean(normalizedError.^2, "all"));

end

function physicalState = localPhysicalState(filterState)
%LOCALPHYSICALSTATE Convert supported native states to the common order.

filterState = double(filterState(:));

switch numel(filterState)
    case 6
        physicalState = filterState.';
    case 9
        physicalState = filterState([1, 2, 4, 5, 7, 8]).';
    case 7
        physicalState = filterState([1, 2, 3, 4, 6, 7]).';
    otherwise
        error("Stage4E:UnsupportedTuningState", ...
            "The tuning cost cannot convert a %d-element state.", ...
            numel(filterState));
end

end
