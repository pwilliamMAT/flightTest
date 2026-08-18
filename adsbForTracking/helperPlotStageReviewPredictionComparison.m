function helperPlotStageReviewPredictionComparison(review, varargin)
%HELPERPLOTSTAGEREVIEWPREDICTIONCOMPARISON Plot one track comparison.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "TrackHex", review.defaultTrackHex);
addParameter(parser, "MaxPairs", 80);
parse(parser, varargin{:});
opts = parser.Results;

trajectoryData = helperBuildStageReviewTrajectories( ...
    review, ...
    "TrackHex", opts.TrackHex, ...
    "MaxPairs", opts.MaxPairs);

timeSeconds = trajectoryData.timeSeconds;
truthState = trajectoryData.truthState;
constvelState = trajectoryData.constvelState;
nnSmokeState = trajectoryData.nnSmokeState;
stage3State = trajectoryData.stage3State;

truthColor = [0.0000, 0.6500, 0.2500];
constvelColor = [0.0000, 0.3000, 1.0000];
nnSmokeColor = [0.5500, 0.5500, 0.5500];
stage3Color = [0.9000, 0.0500, 0.0500];

positionColumns = [1, 3, 5];
velocityColumns = [2, 4, 6];
constvelPositionError = vecnorm( ...
    constvelState(:, positionColumns) - truthState(:, positionColumns), ...
    2, ...
    2);
nnSmokePositionError = vecnorm( ...
    nnSmokeState(:, positionColumns) - truthState(:, positionColumns), ...
    2, ...
    2);
stage3PositionError = vecnorm( ...
    stage3State(:, positionColumns) - truthState(:, positionColumns), ...
    2, ...
    2);
constvelVelocityError = vecnorm( ...
    constvelState(:, velocityColumns) - truthState(:, velocityColumns), ...
    2, ...
    2);
nnSmokeVelocityError = vecnorm( ...
    nnSmokeState(:, velocityColumns) - truthState(:, velocityColumns), ...
    2, ...
    2);
stage3VelocityError = vecnorm( ...
    stage3State(:, velocityColumns) - truthState(:, velocityColumns), ...
    2, ...
    2);

figure("Name", "Stage Review Prediction Comparison");
tiledlayout(3, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
hold on;
plot(truthState(:, 1), truthState(:, 3), "Color", truthColor, "LineWidth", 2.0);
plot(constvelState(:, 1), constvelState(:, 3), "Color", constvelColor, "LineWidth", 1.5);
if review.hasStage3A
    plot(stage3State(:, 1), stage3State(:, 3), "Color", stage3Color, "LineWidth", 1.5);
    legendLabels = ["ADS-B truth", "constvel", "Stage 3A delta MLP"];
else
    legendLabels = ["ADS-B truth", "constvel"];
end
hold off;
grid on;
axis equal;
xlabel("East [m]");
ylabel("North [m]");
title("Easy Track Path: Truth, Constvel, And Stage 3A When Available");
legend(legendLabels, "Location", "best");

nexttile;
hold on;
plot(truthState(:, 1), truthState(:, 3), "Color", truthColor, "LineWidth", 2.0);
plot(nnSmokeState(:, 1), nnSmokeState(:, 3), "Color", nnSmokeColor, "LineWidth", 1.5);
hold off;
grid on;
axis equal;
xlabel("East [m]");
ylabel("North [m]");
title("Stage 2B Smoke NN Path");
legend(["ADS-B truth", "smoke MLP"], "Location", "best");

nexttile;
hold on;
plot(timeSeconds, constvelPositionError, "Color", constvelColor, "LineWidth", 1.5);
if review.hasStage3A
    plot(timeSeconds, stage3PositionError, "Color", stage3Color, "LineWidth", 1.5);
    legend(["constvel", "Stage 3A delta MLP"], "Location", "best");
else
    legend("constvel", "Location", "best");
end
hold off;
grid on;
xlabel("Elapsed time [s]");
ylabel("Position error [m]");
title("One-Step Position Error");

nexttile;
plot(timeSeconds, nnSmokePositionError ./ 1000, "Color", nnSmokeColor, "LineWidth", 1.5);
grid on;
xlabel("Elapsed time [s]");
ylabel("Position error [km]");
title("Stage 2B Smoke NN Position Error");

nexttile;
hold on;
plot(timeSeconds, constvelVelocityError, "Color", constvelColor, "LineWidth", 1.5);
if review.hasStage3A
    plot(timeSeconds, stage3VelocityError, "Color", stage3Color, "LineWidth", 1.5);
    legend(["constvel", "Stage 3A delta MLP"], "Location", "best");
else
    legend("constvel", "Location", "best");
end
hold off;
grid on;
xlabel("Elapsed time [s]");
ylabel("Velocity error [m/s]");
title("One-Step Velocity Error");

nexttile;
plot(timeSeconds, nnSmokeVelocityError, "Color", nnSmokeColor, "LineWidth", 1.5);
grid on;
xlabel("Elapsed time [s]");
ylabel("Velocity error [m/s]");
title("Stage 2B Smoke NN Velocity Error");

end