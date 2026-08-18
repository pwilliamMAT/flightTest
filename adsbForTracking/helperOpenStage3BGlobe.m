function globeOutput = helperOpenStage3BGlobe(stage3BSummary, varargin)
%HELPEROPENSTAGE3BGLOBE Plot Stage 3B truth, constvel, and frozen MLP tracks.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "SessionID", stage3BSummary.selectedTrack.sessionID);
addParameter(parser, "TrackHex", stage3BSummary.selectedTrack.hex);
addParameter(parser, "MaxPairs", 80);
parse(parser, varargin{:});
opts = parser.Results;

trajectoryData = localBuildStage3BTrajectories( ...
    stage3BSummary, ...
    "SessionID", opts.SessionID, ...
    "TrackHex", opts.TrackHex, ...
    "MaxPairs", opts.MaxPairs);

truthColor = [0.0000, 0.6500, 0.2500];
constvelColor = [0.0000, 0.3000, 1.0000];
frozenMlpColor = [0.9000, 0.0500, 0.0500];

viewer = trackingGlobeViewer( ...
    "ReferenceLocation", trajectoryData.receiverOriginLLA, ...
    "PlatformHistoryDepth", 1000, ...
    "TrackHistoryDepth", 1000);

plotTrajectory( ...
    viewer, ...
    trajectoryData.frozenStage3ATrajectory, ...
    "Color", frozenMlpColor, ...
    "LineWidth", int32(3));
plotTrajectory( ...
    viewer, ...
    trajectoryData.constvelTrajectory, ...
    "Color", constvelColor, ...
    "LineWidth", int32(3));
plotTrajectory( ...
    viewer, ...
    trajectoryData.truthTrajectory, ...
    "Color", truthColor, ...
    "LineWidth", int32(4));

trajectory = [ ...
    "ADS-B next-state truth"; ...
    "constvel prediction"; ...
    "Frozen Stage 3A delta MLP prediction"];
color = ["green"; "blue"; "red"];
rgb = [ ...
    string(mat2str(truthColor)); ...
    string(mat2str(constvelColor)); ...
    string(mat2str(frozenMlpColor))];
meaning = [ ...
    "Observed ADS-B-derived next state, drawn last so it stays visible."; ...
    "Native Sensor Fusion constant-velocity one-step prediction."; ...
    "Frozen Stage 3A prediction reconstructed as previousState + predictedDelta."];

legendTable = table(trajectory, color, rgb, meaning, ...
    'VariableNames', ["trajectory", "color", "rgb", "meaning"]);

colors = struct();
colors.truth = truthColor;
colors.constvel = constvelColor;
colors.frozenStage3A = frozenMlpColor;

globeOutput = struct();
globeOutput.viewer = viewer;
globeOutput.trajectoryData = trajectoryData;
globeOutput.legendTable = legendTable;
globeOutput.colors = colors;

end

function trajectoryData = localBuildStage3BTrajectories(stage3BSummary, varargin)
%LOCALBUILDSTAGE3BTRAJECTORIES Build LLA trajectories for one Stage 3B track.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "SessionID", stage3BSummary.selectedTrack.sessionID);
addParameter(parser, "TrackHex", stage3BSummary.selectedTrack.hex);
addParameter(parser, "MaxPairs", 80);
parse(parser, varargin{:});
opts = parser.Results;

sessionID = string(opts.SessionID);
trackHex = string(opts.TrackHex);
maxPairs = double(opts.MaxPairs);

rows = find(string(stage3BSummary.pairErrorTable.sessionID) == sessionID & ...
    string(stage3BSummary.pairErrorTable.hex) == trackHex);

if isempty(rows)
    error("Stage3B:TrackNotFound", ...
        "Track %s in session %s was not found in the Stage 3B artifact.", trackHex, sessionID);
end

[~, sortIdx] = sort(stage3BSummary.pairErrorTable.timeUtcNext(rows));
rows = rows(sortIdx);

if isfinite(maxPairs) && numel(rows) > maxPairs
    rows = rows(1:maxPairs);
end

firstRow = rows(1);
timeUtc = [ ...
    stage3BSummary.pairErrorTable.timeUtcK(firstRow); ...
    stage3BSummary.pairErrorTable.timeUtcNext(rows)];
timeSeconds = seconds(timeUtc - timeUtc(1));

truthState = [ ...
    stage3BSummary.previousState(firstRow, :); ...
    stage3BSummary.nextState(rows, :)];
constvelState = [ ...
    stage3BSummary.previousState(firstRow, :); ...
    stage3BSummary.predictions.constvelPredictedNextState(rows, :)];
frozenStage3AState = [ ...
    stage3BSummary.previousState(firstRow, :); ...
    stage3BSummary.predictions.frozenStage3APredictedNextState(rows, :)];

[timeSeconds, uniqueIdx] = unique(timeSeconds, "stable");
timeUtc = timeUtc(uniqueIdx);
truthState = truthState(uniqueIdx, :);
constvelState = constvelState(uniqueIdx, :);
frozenStage3AState = frozenStage3AState(uniqueIdx, :);

receiverOriginLLA = stage3BSummary.metadata.receiverOriginLLA(firstRow, :);
truthLLA = localStateToLLA(truthState, receiverOriginLLA);
constvelLLA = localStateToLLA(constvelState, receiverOriginLLA);
frozenStage3ALLA = localStateToLLA(frozenStage3AState, receiverOriginLLA);

trajectoryData = struct();
trajectoryData.sessionID = sessionID;
trajectoryData.trackHex = trackHex;
trajectoryData.callsign = string(stage3BSummary.pairErrorTable.callsign(firstRow));
trajectoryData.receiverOriginLLA = receiverOriginLLA;
trajectoryData.rows = rows;
trajectoryData.timeUtc = timeUtc;
trajectoryData.timeSeconds = timeSeconds;
trajectoryData.truthState = truthState;
trajectoryData.constvelState = constvelState;
trajectoryData.frozenStage3AState = frozenStage3AState;
trajectoryData.truthLLA = truthLLA;
trajectoryData.constvelLLA = constvelLLA;
trajectoryData.frozenStage3ALLA = frozenStage3ALLA;
trajectoryData.truthTrajectory = geoTrajectory(truthLLA, timeSeconds, "ReferenceFrame", "ENU");
trajectoryData.constvelTrajectory = geoTrajectory(constvelLLA, timeSeconds, "ReferenceFrame", "ENU");
trajectoryData.frozenStage3ATrajectory = geoTrajectory(frozenStage3ALLA, timeSeconds, "ReferenceFrame", "ENU");

end

function lla = localStateToLLA(state, receiverOriginLLA)
%LOCALSTATETOLLA Convert ENU state positions to geodetic coordinates.

spheroid = wgs84Ellipsoid("meter");

[latDeg, lonDeg, altitudeMeters] = enu2geodetic( ...
    state(:, 1), ...
    state(:, 3), ...
    state(:, 5), ...
    receiverOriginLLA(1), ...
    receiverOriginLLA(2), ...
    receiverOriginLLA(3), ...
    spheroid);

lla = [latDeg, lonDeg, altitudeMeters];

end
