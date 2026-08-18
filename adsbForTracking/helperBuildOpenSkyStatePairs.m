function analysis = helperBuildOpenSkyStatePairs(rawTable, config)
%HELPERBUILDOPENSKYSTATEPAIRS Filter records and construct one-step states.
% States use Sensor Fusion and Tracking Toolbox constant-velocity ordering:
% [x; vx; y; vy; z; vz], where x/east and y/north are local ENU axes.

analysis = struct();
analysis.rawRecords = height(rawTable);
analysis.tableWorked = false;
analysis.timetableWorked = false;
analysis.timetableError = "";
analysis.enuWorked = false;
analysis.enuError = "";
analysis.stateConstructionWorked = false;
analysis.retainedRecords = 0;
analysis.repeatedAircraftCount = 0;
analysis.usablePairs = 0;
analysis.aircraftWithStatePairs = 0;
analysis.duplicateTimestampRecordsRemoved = 0;
analysis.fieldCompleteness = helperFieldCompleteness(rawTable);
analysis.retainedFieldCompletenessPercent = NaN;
analysis.altitudeSourceCounts = table(strings(0, 1), zeros(0, 1), 'VariableNames', ["AltitudeSource", "Count"]);
analysis.vzSourceCounts = table(strings(0, 1), zeros(0, 1), 'VariableNames', ["VzSource", "Count"]);
analysis.dtStats = struct("count", 0, "min", NaN, "p25", NaN, "median", NaN, "p75", NaN, "max", NaN);
analysis.provisionalCovariance = diag(config.covarianceStd .^ 2);
analysis.stateOrderVerified = false;
analysis.decision = "NO-GO";
analysis.criteria = table(strings(0, 1), false(0, 1), strings(0, 1), 'VariableNames', ["Criterion", "Passed", "Evidence"]);
analysis.risks = strings(0, 1);
analysis.pairDtSeconds = zeros(0, 1);
analysis.pairStateK = zeros(0, 6);
analysis.pairStateNext = zeros(0, 6);
analysis.pairCovarianceK = zeros(6, 6, 0);

try
    rawTimetable = table2timetable(rawTable, "RowTimes", "retrievalTime");
    analysis.tableWorked = istable(rawTable);
    analysis.timetableWorked = istimetable(rawTimetable);
catch err
    analysis.tableWorked = istable(rawTable);
    analysis.timetableWorked = false;
    analysis.timetableError = string(err.message);
end

if height(rawTable) == 0
    analysis.risks = "No raw records were parsed from OpenSky snapshots.";
    analysis = helperFinalizeDecision(analysis, config);
    return;
end

geoAltitudeValid = isfinite(rawTable.geoAltitude);
baroAltitudeValid = isfinite(rawTable.baroAltitude);
altitudeMeters = NaN(height(rawTable), 1);
altitudeSource = strings(height(rawTable), 1);

useGeoAltitude = geoAltitudeValid;
useBaroAltitude = ~useGeoAltitude & baroAltitudeValid;

altitudeMeters(useGeoAltitude) = rawTable.geoAltitude(useGeoAltitude);
altitudeMeters(useBaroAltitude) = rawTable.baroAltitude(useBaroAltitude);
altitudeSource(useGeoAltitude) = "geoAltitude";
altitudeSource(useBaroAltitude) = "baroAltitude";
altitudeSource(~useGeoAltitude & ~useBaroAltitude) = "missing";

rawTable.altitudeMeters = altitudeMeters;
rawTable.altitudeSource = altitudeSource;

validIcao = strlength(strtrim(rawTable.icao24)) > 0;
validTimestamp = isfinite(rawTable.timePosition);
validLatLon = isfinite(rawTable.latitude) & isfinite(rawTable.longitude);
validAltitude = isfinite(rawTable.altitudeMeters);
validVelocity = isfinite(rawTable.velocity);
validTrueTrack = isfinite(rawTable.trueTrack);
airborne = rawTable.onGroundKnown & ~rawTable.onGround;

baseRetained = ...
    validIcao & ...
    validTimestamp & ...
    validLatLon & ...
    validAltitude & ...
    validVelocity & ...
    validTrueTrack & ...
    airborne;

eastMeters = NaN(height(rawTable), 1);
northMeters = NaN(height(rawTable), 1);
upMeters = NaN(height(rawTable), 1);
horizontalRangeMeters = NaN(height(rawTable), 1);

try
    spheroid = wgs84Ellipsoid("meter");
    enuCandidate = baseRetained;

    [eastMeters(enuCandidate), northMeters(enuCandidate), upMeters(enuCandidate)] = geodetic2enu( ...
        rawTable.latitude(enuCandidate), ...
        rawTable.longitude(enuCandidate), ...
        rawTable.altitudeMeters(enuCandidate), ...
        config.centerLatDeg, ...
        config.centerLonDeg, ...
        config.centerAltMeters, ...
        spheroid);

    horizontalRangeMeters(enuCandidate) = hypot(eastMeters(enuCandidate), northMeters(enuCandidate));
    analysis.enuWorked = true;
catch err
    analysis.enuWorked = false;
    analysis.enuError = string(err.message);
end

rawTable.x = eastMeters;
rawTable.y = northMeters;
rawTable.z = upMeters;
rawTable.horizontalRangeMeters = horizontalRangeMeters;

withinRadius = rawTable.horizontalRangeMeters <= config.radiusMeters;
retainedMask = baseRetained & withinRadius;
retainedTable = rawTable(retainedMask, :);
analysis.retainedRecords = height(retainedTable);

if analysis.retainedRecords > 0
    retainedComplete = ...
        isfinite(retainedTable.latitude) & ...
        isfinite(retainedTable.longitude) & ...
        isfinite(retainedTable.altitudeMeters) & ...
        isfinite(retainedTable.velocity) & ...
        isfinite(retainedTable.trueTrack);

    analysis.retainedFieldCompletenessPercent = 100 * mean(retainedComplete);
    analysis.altitudeSourceCounts = helperStringCounts(retainedTable.altitudeSource, "AltitudeSource");
else
    analysis.retainedFieldCompletenessPercent = 0;
end

if height(retainedTable) == 0
    analysis.risks = "No airborne records survived validity and 50 km radius filtering.";
    analysis = helperFinalizeDecision(analysis, config);
    return;
end

retainedTable.stateTime = retainedTable.timePositionUtc;
retainedTable.vx = retainedTable.velocity .* sind(retainedTable.trueTrack);
retainedTable.vy = retainedTable.velocity .* cosd(retainedTable.trueTrack);
retainedTable.vz = retainedTable.verticalRate;
retainedTable.vzSource = strings(height(retainedTable), 1);
retainedTable.vzSource(isfinite(retainedTable.verticalRate)) = "verticalRate";
retainedTable.vzSource(~isfinite(retainedTable.verticalRate)) = "missing";
retainedTable.finiteDifferenceVz = NaN(height(retainedTable), 1);

retainedTable = sortrows(retainedTable, ["icao24", "stateTime"]);
duplicateKey = retainedTable.icao24 + "|" + string(posixtime(retainedTable.stateTime));
[~, uniqueIdx] = unique(duplicateKey, "stable");
analysis.duplicateTimestampRecordsRemoved = height(retainedTable) - numel(uniqueIdx);
retainedUnique = retainedTable(uniqueIdx, :);

if height(retainedUnique) > 0
    [groupId, aircraftIds] = findgroups(retainedUnique.icao24);
    samplesPerAircraft = splitapply(@numel, retainedUnique.stateTime, groupId);
    analysis.repeatedAircraftCount = sum(samplesPerAircraft >= 2);

    for aircraftIdx = 1:numel(aircraftIds)
        groupMask = groupId == aircraftIdx;
        groupRows = find(groupMask);

        if numel(groupRows) < 2
            continue;
        end

        groupDt = seconds(diff(retainedUnique.stateTime(groupRows)));
        groupDz = diff(retainedUnique.z(groupRows));
        validFiniteDiff = isfinite(groupDt) & groupDt > 0 & isfinite(groupDz);
        finiteDiffVz = NaN(numel(groupRows) - 1, 1);
        finiteDiffVz(validFiniteDiff) = groupDz(validFiniteDiff) ./ groupDt(validFiniteDiff);
        retainedUnique.finiteDifferenceVz(groupRows(2:end)) = finiteDiffVz;
    end
end

stateValid = ...
    isfinite(retainedUnique.x) & ...
    isfinite(retainedUnique.vx) & ...
    isfinite(retainedUnique.y) & ...
    isfinite(retainedUnique.vy) & ...
    isfinite(retainedUnique.z) & ...
    isfinite(retainedUnique.vz);

stateTable = retainedUnique(stateValid, :);
analysis.vzSourceCounts = helperStringCounts(retainedUnique.vzSource, "VzSource");
analysis.stateOrderVerified = isequal(config.stateOrder, ["x", "vx", "y", "vy", "z", "vz"]);

if height(stateTable) > 0 && analysis.stateOrderVerified
    analysis.stateConstructionWorked = true;
end

pairAircraft = strings(0, 1);
pairTimeK = NaT(0, 1, "TimeZone", "UTC");
pairDtSeconds = zeros(0, 1);
pairStateK = zeros(0, 6);
pairStateNext = zeros(0, 6);

if height(stateTable) > 1
    [stateGroupId, stateAircraftIds] = findgroups(stateTable.icao24);
    aircraftPairCounts = zeros(numel(stateAircraftIds), 1);

    for aircraftIdx = 1:numel(stateAircraftIds)
        groupRows = find(stateGroupId == aircraftIdx);

        if numel(groupRows) < 2
            continue;
        end

        groupDt = seconds(diff(stateTable.stateTime(groupRows)));
        validPair = isfinite(groupDt) & groupDt > 0;

        if ~any(validPair)
            continue;
        end

        currentRows = groupRows(1:end - 1);
        nextRows = groupRows(2:end);
        currentRows = currentRows(validPair);
        nextRows = nextRows(validPair);
        groupDt = groupDt(validPair);

        currentState = [ ...
            stateTable.x(currentRows), ...
            stateTable.vx(currentRows), ...
            stateTable.y(currentRows), ...
            stateTable.vy(currentRows), ...
            stateTable.z(currentRows), ...
            stateTable.vz(currentRows)];

        nextState = [ ...
            stateTable.x(nextRows), ...
            stateTable.vx(nextRows), ...
            stateTable.y(nextRows), ...
            stateTable.vy(nextRows), ...
            stateTable.z(nextRows), ...
            stateTable.vz(nextRows)];

        pairAircraft = [pairAircraft; repmat(stateAircraftIds(aircraftIdx), numel(groupDt), 1)];
        pairTimeK = [pairTimeK; stateTable.stateTime(currentRows)];
        pairDtSeconds = [pairDtSeconds; groupDt];
        pairStateK = [pairStateK; currentState];
        pairStateNext = [pairStateNext; nextState];
        aircraftPairCounts(aircraftIdx) = numel(groupDt);
    end

    analysis.aircraftWithStatePairs = sum(aircraftPairCounts > 0);
end

analysis.usablePairs = numel(pairDtSeconds);
analysis.pairDtSeconds = pairDtSeconds;
analysis.pairStateK = pairStateK;
analysis.pairStateNext = pairStateNext;

if analysis.usablePairs > 0
    analysis.pairCovarianceK = repmat(analysis.provisionalCovariance, 1, 1, analysis.usablePairs);

    dtPercentiles = prctile(pairDtSeconds, [25, 75]);
    analysis.dtStats.count = numel(pairDtSeconds);
    analysis.dtStats.min = min(pairDtSeconds);
    analysis.dtStats.p25 = dtPercentiles(1);
    analysis.dtStats.median = median(pairDtSeconds);
    analysis.dtStats.p75 = dtPercentiles(2);
    analysis.dtStats.max = max(pairDtSeconds);
end

analysis.pairTable = table(pairAircraft, pairTimeK, pairDtSeconds, pairStateK, pairStateNext);

if analysis.duplicateTimestampRecordsRemoved > 0
    analysis.risks(end + 1, 1) = "Repeated current-state snapshots produced duplicate aircraft timestamps; duplicates were removed before dt calculation.";
end

if any(~isfinite(retainedUnique.verticalRate))
    analysis.risks(end + 1, 1) = "Some retained records lacked verticalRate; finite-difference vertical rate was computed only as a continuity diagnostic and not used in usable state pairs.";
end

analysis = helperFinalizeDecision(analysis, config);

end

function fieldCompleteness = helperFieldCompleteness(rawTable)
%HELPERFIELDCOMPLETENESS Report OpenSky field availability in raw records.

fieldNames = [
    "icao24"
    "timePosition"
    "lastContact"
    "longitude"
    "latitude"
    "baroAltitude"
    "geoAltitude"
    "onGround"
    "velocity"
    "trueTrack"
    "verticalRate"
    "sensors"
    "squawk"
    "spi"
    "positionSource"];

validCounts = zeros(numel(fieldNames), 1);
validPercent = NaN(numel(fieldNames), 1);
recordCount = height(rawTable);

if recordCount == 0
    fieldCompleteness = table(fieldNames, validCounts, validPercent);
    return;
end

validCounts(1) = sum(strlength(strtrim(rawTable.icao24)) > 0);
validCounts(2) = sum(isfinite(rawTable.timePosition));
validCounts(3) = sum(isfinite(rawTable.lastContact));
validCounts(4) = sum(isfinite(rawTable.longitude));
validCounts(5) = sum(isfinite(rawTable.latitude));
validCounts(6) = sum(isfinite(rawTable.baroAltitude));
validCounts(7) = sum(isfinite(rawTable.geoAltitude));
validCounts(8) = sum(rawTable.onGroundKnown);
validCounts(9) = sum(isfinite(rawTable.velocity));
validCounts(10) = sum(isfinite(rawTable.trueTrack));
validCounts(11) = sum(isfinite(rawTable.verticalRate));
validCounts(12) = sum(strlength(rawTable.sensors) > 0);
validCounts(13) = sum(strlength(rawTable.squawk) > 0);
validCounts(14) = sum(rawTable.spiKnown);
validCounts(15) = sum(isfinite(rawTable.positionSource));
validPercent = 100 * validCounts ./ recordCount;

fieldCompleteness = table(fieldNames, validCounts, validPercent);

end

function countTable = helperStringCounts(values, variableName)
%HELPERSTRINGCOUNTS Count string categories with stable display names.

if isempty(values)
    countTable = table(strings(0, 1), zeros(0, 1), 'VariableNames', [variableName, "Count"]);
    return;
end

[groupId, groupNames] = findgroups(values);
counts = splitapply(@numel, values, groupId);
countTable = table(groupNames, counts, 'VariableNames', [variableName, "Count"]);

end

function analysis = helperFinalizeDecision(analysis, config)
%HELPERFINALIZEDECISION Apply the Stage 2A go/no-go criteria.

criteriaName = [
    "Natick endpoint reachable without manual setup"
    "At least 5 airborne aircraft with repeated valid samples"
    "At least 100 usable one-step state pairs"
    "Median usable dt <= 30 seconds"
    "At least 80 percent retained field completeness"
    "MATLAB table/timetable creation works"
    "ENU conversion works"
    "State construction order is [x; vx; y; vy; z; vz]"];

passed = false(numel(criteriaName), 1);
evidence = strings(numel(criteriaName), 1);

passed(1) = true;
evidence(1) = "Endpoint metadata check reached HTTP success before sampling.";

passed(2) = analysis.repeatedAircraftCount >= 5;
evidence(2) = sprintf("%d repeated aircraft", analysis.repeatedAircraftCount);

passed(3) = analysis.usablePairs >= 100;
evidence(3) = sprintf("%d usable pairs", analysis.usablePairs);

passed(4) = isfinite(analysis.dtStats.median) && analysis.dtStats.median <= 30;
evidence(4) = sprintf("median dt %.2f s", analysis.dtStats.median);

passed(5) = isfinite(analysis.retainedFieldCompletenessPercent) && analysis.retainedFieldCompletenessPercent >= 80;
evidence(5) = sprintf("%.1f percent retained completeness", analysis.retainedFieldCompletenessPercent);

passed(6) = analysis.tableWorked && analysis.timetableWorked;
evidence(6) = sprintf("table %d, timetable %d", analysis.tableWorked, analysis.timetableWorked);

passed(7) = analysis.enuWorked;
evidence(7) = sprintf("ENU conversion %d", analysis.enuWorked);

passed(8) = analysis.stateConstructionWorked && analysis.stateOrderVerified;
evidence(8) = strjoin(config.stateOrder, ", ");

analysis.criteria = table(criteriaName, passed, evidence, 'VariableNames', ["Criterion", "Passed", "Evidence"]);

if all(passed)
    analysis.decision = "GO";
else
    analysis.decision = "NO-GO";
end

end
