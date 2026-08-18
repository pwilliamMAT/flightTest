function rawTable = helperParseOpenSkyStates(snapshots, retrievalTimes, snapshotSuccess)
%HELPERPARSEOPENSKYSTATES Convert OpenSky state vectors into explicit columns.
% OpenSky returns each state vector as a positional mixed-type cell array.
% The helper maps those positions into named MATLAB table variables.

totalRecords = 0;

for snapshotIdx = 1:numel(snapshots)
    if ~snapshotSuccess(snapshotIdx)
        continue;
    end

    if isempty(snapshots{snapshotIdx})
        continue;
    end

    if ~isfield(snapshots{snapshotIdx}, "states")
        continue;
    end

    if isempty(snapshots{snapshotIdx}.states)
        continue;
    end

    totalRecords = totalRecords + numel(snapshots{snapshotIdx}.states);
end

snapshotIndex = zeros(totalRecords, 1);
retrievalTime = NaT(totalRecords, 1, "TimeZone", "UTC");
responseTimeUnix = NaN(totalRecords, 1);
icao24 = strings(totalRecords, 1);
callsign = strings(totalRecords, 1);
originCountry = strings(totalRecords, 1);
timePosition = NaN(totalRecords, 1);
lastContact = NaN(totalRecords, 1);
longitude = NaN(totalRecords, 1);
latitude = NaN(totalRecords, 1);
baroAltitude = NaN(totalRecords, 1);
onGround = false(totalRecords, 1);
onGroundKnown = false(totalRecords, 1);
velocity = NaN(totalRecords, 1);
trueTrack = NaN(totalRecords, 1);
verticalRate = NaN(totalRecords, 1);
sensors = strings(totalRecords, 1);
geoAltitude = NaN(totalRecords, 1);
squawk = strings(totalRecords, 1);
spi = false(totalRecords, 1);
spiKnown = false(totalRecords, 1);
positionSource = NaN(totalRecords, 1);

rowIdx = 0;

for snapshotIdx = 1:numel(snapshots)
    if ~snapshotSuccess(snapshotIdx)
        continue;
    end

    if isempty(snapshots{snapshotIdx})
        continue;
    end

    snapshot = snapshots{snapshotIdx};

    if ~isfield(snapshot, "states")
        continue;
    end

    if isempty(snapshot.states)
        continue;
    end

    states = snapshot.states;
    currentResponseTimeUnix = NaN;

    if isfield(snapshot, "time")
        currentResponseTimeUnix = double(snapshot.time);
    end

    for stateIdx = 1:numel(states)
        rowIdx = rowIdx + 1;
        stateVector = states{stateIdx};

        snapshotIndex(rowIdx) = snapshotIdx;
        retrievalTime(rowIdx) = retrievalTimes(snapshotIdx);
        responseTimeUnix(rowIdx) = currentResponseTimeUnix;

        icao24(rowIdx) = helperReadOpenSkyString(stateVector, 1);
        callsign(rowIdx) = helperReadOpenSkyString(stateVector, 2);
        originCountry(rowIdx) = helperReadOpenSkyString(stateVector, 3);
        timePosition(rowIdx) = helperReadOpenSkyDouble(stateVector, 4);
        lastContact(rowIdx) = helperReadOpenSkyDouble(stateVector, 5);
        longitude(rowIdx) = helperReadOpenSkyDouble(stateVector, 6);
        latitude(rowIdx) = helperReadOpenSkyDouble(stateVector, 7);
        baroAltitude(rowIdx) = helperReadOpenSkyDouble(stateVector, 8);

        [onGround(rowIdx), onGroundKnown(rowIdx)] = helperReadOpenSkyLogical(stateVector, 9);

        velocity(rowIdx) = helperReadOpenSkyDouble(stateVector, 10);
        trueTrack(rowIdx) = helperReadOpenSkyDouble(stateVector, 11);
        verticalRate(rowIdx) = helperReadOpenSkyDouble(stateVector, 12);
        sensors(rowIdx) = helperReadOpenSkyValueText(stateVector, 13);
        geoAltitude(rowIdx) = helperReadOpenSkyDouble(stateVector, 14);
        squawk(rowIdx) = helperReadOpenSkyString(stateVector, 15);

        [spi(rowIdx), spiKnown(rowIdx)] = helperReadOpenSkyLogical(stateVector, 16);

        positionSource(rowIdx) = helperReadOpenSkyDouble(stateVector, 17);
    end
end

responseTime = datetime(responseTimeUnix, "ConvertFrom", "posixtime", "TimeZone", "UTC");
timePositionUtc = datetime(timePosition, "ConvertFrom", "posixtime", "TimeZone", "UTC");
lastContactUtc = datetime(lastContact, "ConvertFrom", "posixtime", "TimeZone", "UTC");

rawTable = table( ...
    snapshotIndex, ...
    retrievalTime, ...
    responseTimeUnix, ...
    responseTime, ...
    icao24, ...
    callsign, ...
    originCountry, ...
    timePosition, ...
    timePositionUtc, ...
    lastContact, ...
    lastContactUtc, ...
    longitude, ...
    latitude, ...
    baroAltitude, ...
    onGround, ...
    onGroundKnown, ...
    velocity, ...
    trueTrack, ...
    verticalRate, ...
    sensors, ...
    geoAltitude, ...
    squawk, ...
    spi, ...
    spiKnown, ...
    positionSource);

end

function value = helperReadOpenSkyString(stateVector, index)
%HELPERREADOPENSKYSTRING Read string-like OpenSky state vector entries.

value = "";

if ~iscell(stateVector)
    return;
end

if numel(stateVector) < index
    return;
end

rawValue = stateVector{index};

if isempty(rawValue)
    return;
end

if ischar(rawValue) || isstring(rawValue)
    value = strtrim(string(rawValue));
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = string(rawValue);
end

end

function value = helperReadOpenSkyDouble(stateVector, index)
%HELPERREADOPENSKYDOUBLE Read numeric OpenSky state vector entries.

value = NaN;

if ~iscell(stateVector)
    return;
end

if numel(stateVector) < index
    return;
end

rawValue = stateVector{index};

if isempty(rawValue)
    return;
end

if isnumeric(rawValue) && isscalar(rawValue)
    value = double(rawValue);
elseif islogical(rawValue) && isscalar(rawValue)
    value = double(rawValue);
end

end

function [value, known] = helperReadOpenSkyLogical(stateVector, index)
%HELPERREADOPENSKYLOGICAL Read logical OpenSky state vector entries.

value = false;
known = false;

if ~iscell(stateVector)
    return;
end

if numel(stateVector) < index
    return;
end

rawValue = stateVector{index};

if isempty(rawValue)
    return;
end

if islogical(rawValue) && isscalar(rawValue)
    value = rawValue;
    known = true;
elseif isnumeric(rawValue) && isscalar(rawValue) && isfinite(rawValue)
    value = rawValue ~= 0;
    known = true;
end

end

function value = helperReadOpenSkyValueText(stateVector, index)
%HELPERREADOPENSKYVALUETEXT Preserve mixed OpenSky entries as readable text.

value = "";

if ~iscell(stateVector)
    return;
end

if numel(stateVector) < index
    return;
end

rawValue = stateVector{index};

if isempty(rawValue)
    return;
end

if ischar(rawValue) || isstring(rawValue)
    value = strtrim(string(rawValue));
elseif isnumeric(rawValue) || islogical(rawValue)
    value = string(mat2str(rawValue));
elseif iscell(rawValue)
    value = "<cell>";
else
    value = string(class(rawValue));
end

end
