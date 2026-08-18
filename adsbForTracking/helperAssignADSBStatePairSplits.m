function [metadata, splitManifest] = helperAssignADSBStatePairSplits(metadata, splitSeed)
%HELPERASSIGNADSBSTATEPAIRSPLITS Deterministically split by session/aircraft.
% Keeping all windows for one aircraft in one split prevents overlapping
% adjacent pairs from leaking across train, validation, and test partitions.

splitSeed = double(splitSeed);

if height(metadata) == 0
    splitManifest = struct();
    splitManifest.policy = "aircraft_level_70_15_15_smoke";
    splitManifest.splitSeed = splitSeed;
    splitManifest.groupAssignments = table();
    splitManifest.leakageCheckPassed = true;
    splitManifest.aircraftSplitCheckPassed = true;
    splitManifest.countsBySplit = table();
    return;
end

groupKey = metadata.sessionID + "|" + metadata.hex;
[groupId, groupNames] = findgroups(groupKey);
groupCount = numel(groupNames);

rng(splitSeed, "twister");
randomOrder = randperm(groupCount);

splitByGroup = strings(groupCount, 1);

if groupCount == 1
    splitByGroup(:) = "train";
else
    trainCount = max(1, floor(0.70 * groupCount));
    validationCount = max(1, floor(0.15 * groupCount));

    if groupCount >= 3 && trainCount + validationCount >= groupCount
        trainCount = groupCount - 2;
        validationCount = 1;
    end

    if groupCount == 2
        trainCount = 1;
        validationCount = 0;
    end

    trainGroups = randomOrder(1:trainCount);
    splitByGroup(trainGroups) = "train";

    if validationCount > 0
        validationGroups = randomOrder(trainCount + 1:trainCount + validationCount);
        splitByGroup(validationGroups) = "validation";
    end

    testGroups = randomOrder(trainCount + validationCount + 1:end);
    splitByGroup(testGroups) = "test";
end

metadata.split = splitByGroup(groupId);

sessionID = strings(groupCount, 1);
hex = strings(groupCount, 1);

for groupIdx = 1:groupCount
    firstRow = find(groupId == groupIdx, 1, "first");
    sessionID(groupIdx) = metadata.sessionID(firstRow);
    hex(groupIdx) = metadata.hex(firstRow);
end

groupAssignments = table( ...
    sessionID, ...
    hex, ...
    splitByGroup, ...
    'VariableNames', ["sessionID", "hex", "split"]);

countsBySplit = groupsummary(metadata, "split");
leakageCheckPassed = localNoKeyAppearsInMultipleSplits(metadata);
aircraftSplitCheckPassed = localNoAircraftAppearsInMultipleSplits(metadata);

splitManifest = struct();
splitManifest.policy = "aircraft_level_70_15_15_smoke";
splitManifest.splitSeed = splitSeed;
splitManifest.groupAssignments = groupAssignments;
splitManifest.leakageCheckPassed = leakageCheckPassed;
splitManifest.aircraftSplitCheckPassed = aircraftSplitCheckPassed;
splitManifest.countsBySplit = countsBySplit;
splitManifest.note = "Smoke split only for single-session data; use session-level holdout before model-quality claims.";

end

function passed = localNoKeyAppearsInMultipleSplits(metadata)
%LOCALNOKEYAPPEARSINMULTIPLESPLITS Check (sessionID, hex, timeUtcK) leakage.

timeKey = compose("%.9f", posixtime(metadata.timeUtcK));
pairKey = metadata.sessionID + "|" + metadata.hex + "|" + timeKey;
[keyGroupId, keyNames] = findgroups(pairKey);
splitCounts = zeros(numel(keyNames), 1);

for keyIdx = 1:numel(keyNames)
    splitCounts(keyIdx) = numel(unique(metadata.split(keyGroupId == keyIdx)));
end

passed = all(splitCounts == 1);

end

function passed = localNoAircraftAppearsInMultipleSplits(metadata)
%LOCALNOAIRCRAFTAPPEARSINMULTIPLESPLITS Check aircraft-level split integrity.

aircraftKey = metadata.sessionID + "|" + metadata.hex;
[aircraftGroupId, aircraftNames] = findgroups(aircraftKey);
splitCounts = zeros(numel(aircraftNames), 1);

for aircraftIdx = 1:numel(aircraftNames)
    splitCounts(aircraftIdx) = numel(unique(metadata.split(aircraftGroupId == aircraftIdx)));
end

passed = all(splitCounts == 1);

end
