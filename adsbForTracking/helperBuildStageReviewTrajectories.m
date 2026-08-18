function trajectoryData = helperBuildStageReviewTrajectories(review, varargin)
%HELPERBUILDSTAGEREVIEWTRAJECTORIES Build LLA trajectories for one track.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "TrackHex", review.defaultTrackHex);
addParameter(parser, "MaxPairs", 80);
parse(parser, varargin{:});
opts = parser.Results;

trackHex = string(opts.TrackHex);
maxPairs = double(opts.MaxPairs);

rows = find(string(review.pairReviewTable.hex) == trackHex);

if isempty(rows)
    error("StageReview:TrackNotFound", ...
        "Track hex %s was not found in the review artifact.", trackHex);
end

[~, sortIdx] = sort(review.pairReviewTable.timeUtcNext(rows));
rows = rows(sortIdx);

if isfinite(maxPairs) && numel(rows) > maxPairs
    rows = rows(1:maxPairs);
end

firstRow = rows(1);
timeUtc = [ ...
    review.pairReviewTable.timeUtcK(firstRow); ...
    review.pairReviewTable.timeUtcNext(rows)];
timeSeconds = seconds(timeUtc - timeUtc(1));

truthState = [ ...
    review.dataset.previousState(firstRow, :); ...
    review.dataset.nextState(rows, :)];
constvelState = [ ...
    review.dataset.previousState(firstRow, :); ...
    review.constvelPredictedState(rows, :)];
nnSmokeState = [ ...
    review.dataset.previousState(firstRow, :); ...
    review.nnPredictedNextState(rows, :)];

if review.hasStage3A
    stage3State = [ ...
        review.dataset.previousState(firstRow, :); ...
        review.stage3PredictedNextState(rows, :)];
else
    stage3State = NaN(size(truthState));
end

[timeSeconds, uniqueIdx] = unique(timeSeconds, "stable");
timeUtc = timeUtc(uniqueIdx);
truthState = truthState(uniqueIdx, :);
constvelState = constvelState(uniqueIdx, :);
nnSmokeState = nnSmokeState(uniqueIdx, :);
stage3State = stage3State(uniqueIdx, :);

receiverOriginLLA = review.dataset.metadata.receiverOriginLLA(firstRow, :);
truthLLA = localStateToLLA(truthState, receiverOriginLLA);
constvelLLA = localStateToLLA(constvelState, receiverOriginLLA);
nnSmokeLLA = localStateToLLA(nnSmokeState, receiverOriginLLA);

if review.hasStage3A
    stage3LLA = localStateToLLA(stage3State, receiverOriginLLA);
    stage3Trajectory = geoTrajectory(stage3LLA, timeSeconds, "ReferenceFrame", "ENU");
else
    stage3LLA = NaN(size(truthLLA));
    stage3Trajectory = [];
end

trajectoryData = struct();
trajectoryData.trackHex = trackHex;
trajectoryData.callsign = string(review.pairReviewTable.callsign(firstRow));
trajectoryData.receiverOriginLLA = receiverOriginLLA;
trajectoryData.rows = rows;
trajectoryData.timeUtc = timeUtc;
trajectoryData.timeSeconds = timeSeconds;
trajectoryData.truthState = truthState;
trajectoryData.constvelState = constvelState;
trajectoryData.nnSmokeState = nnSmokeState;
trajectoryData.stage3State = stage3State;
trajectoryData.truthLLA = truthLLA;
trajectoryData.constvelLLA = constvelLLA;
trajectoryData.nnSmokeLLA = nnSmokeLLA;
trajectoryData.stage3LLA = stage3LLA;
trajectoryData.truthTrajectory = geoTrajectory(truthLLA, timeSeconds, "ReferenceFrame", "ENU");
trajectoryData.constvelTrajectory = geoTrajectory(constvelLLA, timeSeconds, "ReferenceFrame", "ENU");
trajectoryData.nnSmokeTrajectory = geoTrajectory(nnSmokeLLA, timeSeconds, "ReferenceFrame", "ENU");
trajectoryData.stage3Trajectory = stage3Trajectory;

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