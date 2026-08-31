function splitAudit = helperAuditADSBProspectiveSplits(pairTable, eventTable)
%HELPERAUDITADSBPROSPECTIVESPLITS Audit two leakage-resistant split plans.
% The aircraft-disjoint plan assigns each ICAO to exactly one split. The
% chronological plan assigns complete sessions to contiguous time blocks.

localValidateInputs(pairTable, eventTable);

splitNames = ["train"; "validation"; "test"];
aircraftAssignment = localBuildAircraftAssignment(pairTable, splitNames);
chronologicalAssignment = localBuildChronologicalAssignment(pairTable, splitNames);

aircraftPairSplit = localMapValues( ...
    pairTable.hex, ...
    aircraftAssignment.hex, ...
    aircraftAssignment.split);
chronologicalPairSplit = localMapValues( ...
    pairTable.sessionID, ...
    chronologicalAssignment.sessionID, ...
    chronologicalAssignment.split);
aircraftEventSplit = localMapValues( ...
    eventTable.hex, ...
    aircraftAssignment.hex, ...
    aircraftAssignment.split);
chronologicalEventSplit = localMapValues( ...
    eventTable.sessionID, ...
    chronologicalAssignment.sessionID, ...
    chronologicalAssignment.split);

eventTypes = [ ...
    "sustained_turn"; ...
    "sustained_acceleration"; ...
    "sustained_climb"; ...
    "sustained_descent"; ...
    "sparse_gap"];
eventCoverage = [ ...
    localBuildEventCoverage( ...
        eventTable.eventType, ...
        aircraftEventSplit, ...
        eventTypes, ...
        splitNames, ...
        "aircraft_disjoint"); ...
    localBuildEventCoverage( ...
        eventTable.eventType, ...
        chronologicalEventSplit, ...
        eventTypes, ...
        splitNames, ...
        "chronological_blocked")];

pairCoverage = [ ...
    localBuildPairCoverage( ...
        pairTable, ...
        aircraftPairSplit, ...
        splitNames, ...
        "aircraft_disjoint"); ...
    localBuildPairCoverage( ...
        pairTable, ...
        chronologicalPairSplit, ...
        splitNames, ...
        "chronological_blocked")];

normalizationAudit = [ ...
    localBuildNormalizationAudit( ...
        pairTable, ...
        aircraftPairSplit, ...
        "aircraft_disjoint"); ...
    localBuildNormalizationAudit( ...
        pairTable, ...
        chronologicalPairSplit, ...
        "chronological_blocked")];

splitAudit = struct();
splitAudit.aircraftAssignment = aircraftAssignment;
splitAudit.chronologicalSessionAssignment = chronologicalAssignment;
splitAudit.aircraftPairSplit = aircraftPairSplit;
splitAudit.chronologicalPairSplit = chronologicalPairSplit;
splitAudit.aircraftEventSplit = aircraftEventSplit;
splitAudit.chronologicalEventSplit = chronologicalEventSplit;
splitAudit.eventCoverage = eventCoverage;
splitAudit.pairCoverage = pairCoverage;
splitAudit.normalizationAudit = normalizationAudit;
splitAudit.aircraftLeakage = localHasAssignmentLeakage( ...
    aircraftAssignment.hex, ...
    aircraftAssignment.split);
splitAudit.chronologicalSessionLeakage = localHasAssignmentLeakage( ...
    chronologicalAssignment.sessionID, ...
    chronologicalAssignment.split);
splitAudit.rareRegimeSupportPassed = localRareRegimeSupportPassed( ...
    eventCoverage, ...
    eventTypes);

end

function localValidateInputs(pairTable, eventTable)
%LOCALVALIDATEINPUTS Validate public split-audit inputs.

pairVariables = [ ...
    "sessionID", ...
    "hex", ...
    "timeUtcK", ...
    "maneuverClass", ...
    "verticalStatus", ...
    "dtRegime", ...
    "previousState"];
eventVariables = ["eventType", "sessionID", "hex"];
missingPairVariables = setdiff( ...
    pairVariables, ...
    string(pairTable.Properties.VariableNames));
missingEventVariables = setdiff( ...
    eventVariables, ...
    string(eventTable.Properties.VariableNames));

if ~isempty(missingPairVariables)
    error("Stage4BPost:MissingSplitPairVariable", ...
        "Split pair table is missing variable %s.", missingPairVariables(1));
end

if ~isempty(missingEventVariables)
    error("Stage4BPost:MissingSplitEventVariable", ...
        "Event table is missing variable %s.", missingEventVariables(1));
end

end

function assignment = localBuildAircraftAssignment(pairTable, splitNames)
%LOCALBUILDAIRCRAFTASSIGNMENT Deterministically assign complete ICAO groups.

hex = sort(unique(string(pairTable.hex)));
split = localBalancedLabels(numel(hex), splitNames);
assignment = table(hex, split);

end

function assignment = localBuildChronologicalAssignment(pairTable, splitNames)
%LOCALBUILDCHRONOLOGICALASSIGNMENT Assign complete sessions by start time.

[sessionGroup, sessionID] = findgroups(string(pairTable.sessionID));
startTimeUtc = splitapply(@min, pairTable.timeUtcK, sessionGroup);
[startTimeUtc, order] = sort(startTimeUtc);
sessionID = sessionID(order);
split = localContiguousLabels(numel(sessionID), splitNames);
assignment = table(sessionID, startTimeUtc, split);

end

function labels = localBalancedLabels(itemCount, splitNames)
%LOCALBALANCEDLABELS Assign a deterministic 60/20/20 repeating pattern.

labels = strings(itemCount, 1);
pattern = [1; 1; 1; 2; 3];

for itemIdx = 1:itemCount
    labels(itemIdx) = splitNames(pattern(mod(itemIdx - 1, numel(pattern)) + 1));
end

end

function labels = localContiguousLabels(itemCount, splitNames)
%LOCALCONTIGUOUSLABELS Split ordered sessions into contiguous 60/20/20 sets.

labels = strings(itemCount, 1);

if itemCount == 0
    return;
end

trainEnd = min(max(floor(0.60 * itemCount), 1), itemCount);
validationEnd = min(max(floor(0.80 * itemCount), trainEnd), itemCount);
labels(1:trainEnd) = splitNames(1);

if validationEnd > trainEnd
    labels(trainEnd + 1:validationEnd) = splitNames(2);
end

if itemCount > validationEnd
    labels(validationEnd + 1:end) = splitNames(3);
end

end

function mapped = localMapValues(values, keys, assignedLabels)
%LOCALMAPVALUES Map group values to their deterministic split labels.

values = string(values);
keys = string(keys);
assignedLabels = string(assignedLabels);
mapped = strings(numel(values), 1);
[isFound, keyIndex] = ismember(values, keys);
mapped(isFound) = assignedLabels(keyIndex(isFound));
mapped(~isFound) = "unassigned";

end

function coverage = localBuildEventCoverage(eventValues, splitValues, ...
        eventTypes, splitNames, strategy)
%LOCALBUILDEVENTCOVERAGE Count every event/split combination, including zero.

rowCount = numel(eventTypes) * numel(splitNames);
splitStrategy = repmat(string(strategy), rowCount, 1);
eventType = strings(rowCount, 1);
split = strings(rowCount, 1);
eventCount = zeros(rowCount, 1);
rowIdx = 0;

for eventIdx = 1:numel(eventTypes)
    for splitIdx = 1:numel(splitNames)
        rowIdx = rowIdx + 1;
        eventType(rowIdx) = eventTypes(eventIdx);
        split(rowIdx) = splitNames(splitIdx);
        eventCount(rowIdx) = sum( ...
            string(eventValues) == eventTypes(eventIdx) & ...
            string(splitValues) == splitNames(splitIdx));
    end
end

coverage = table(splitStrategy, eventType, split, eventCount);

end

function coverage = localBuildPairCoverage(pairTable, splitValues, ...
        splitNames, strategy)
%LOCALBUILDPAIRCOVERAGE Summarize pair support by split and legacy labels.

maneuverClasses = string(categories(pairTable.maneuverClass));
rowCount = numel(maneuverClasses) * numel(splitNames);
splitStrategy = repmat(string(strategy), rowCount, 1);
maneuverClass = strings(rowCount, 1);
split = strings(rowCount, 1);
pairCount = zeros(rowCount, 1);
aircraftCount = zeros(rowCount, 1);
sessionCount = zeros(rowCount, 1);
rowIdx = 0;

for maneuverIdx = 1:numel(maneuverClasses)
    for splitIdx = 1:numel(splitNames)
        rowIdx = rowIdx + 1;
        rowMask = string(pairTable.maneuverClass) == maneuverClasses(maneuverIdx) & ...
            string(splitValues) == splitNames(splitIdx);
        maneuverClass(rowIdx) = maneuverClasses(maneuverIdx);
        split(rowIdx) = splitNames(splitIdx);
        pairCount(rowIdx) = sum(rowMask);
        aircraftCount(rowIdx) = numel(unique(pairTable.hex(rowMask)));
        sessionCount(rowIdx) = numel(unique(pairTable.sessionID(rowMask)));
    end
end

coverage = table( ...
    splitStrategy, ...
    maneuverClass, ...
    split, ...
    pairCount, ...
    aircraftCount, ...
    sessionCount);

end

function audit = localBuildNormalizationAudit(pairTable, splitValues, strategy)
%LOCALBUILDNORMALIZATIONAUDIT Record training-only state normalization.

trainMask = string(splitValues) == "train";
trainingState = pairTable.previousState(trainMask, :);

if isempty(trainingState)
    stateMean = NaN(1, 6);
    stateStd = NaN(1, 6);
else
    stateMean = mean(trainingState, 1, "omitnan");
    stateStd = std(trainingState, 0, 1, "omitnan");
end

splitStrategy = string(strategy);
normalizationSource = "train_only";
trainingPairCount = sum(trainMask);
audit = table( ...
    splitStrategy, ...
    normalizationSource, ...
    trainingPairCount, ...
    {stateMean}, ...
    {stateStd}, ...
    'VariableNames', [ ...
        "splitStrategy", ...
        "normalizationSource", ...
        "trainingPairCount", ...
        "stateMean", ...
        "stateStd"]);

end

function hasLeakage = localHasAssignmentLeakage(keys, splitValues)
%LOCALHASASSIGNMENTLEAKAGE Detect a group assigned to multiple splits.

[group, ~] = findgroups(string(keys));
splitCount = splitapply(@(x) numel(unique(string(x))), splitValues, group);
hasLeakage = any(splitCount > 1);

end

function passed = localRareRegimeSupportPassed(eventCoverage, eventTypes)
%LOCALRAREREGIMESUPPORTPASSED Require every event type in all splits.

passed = true;
strategies = ["aircraft_disjoint", "chronological_blocked"];
splitNames = ["train", "validation", "test"];

for strategyIdx = 1:numel(strategies)
    for eventIdx = 1:numel(eventTypes)
        for splitIdx = 1:numel(splitNames)
            rowMask = eventCoverage.splitStrategy == strategies(strategyIdx) & ...
                eventCoverage.eventType == eventTypes(eventIdx) & ...
                eventCoverage.split == splitNames(splitIdx);
            requiredCount = 1;

            if splitNames(splitIdx) ~= "train"
                requiredCount = 5;
            end

            passed = passed && any(rowMask) && ...
                eventCoverage.eventCount(rowMask) >= requiredCount;
        end
    end
end

end
