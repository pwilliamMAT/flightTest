function figurePaths = helperWriteStage3AFigures(outputFolder, stage3Summary)
%HELPERWRITESTAGE3AFIGURES Save Stage 3A diagnostic figures.

outputFolder = string(outputFolder);
figurePaths = struct();

if stage3Summary.config.PreflightOnly
    return;
end

try
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    figurePaths.trainingLoss = fullfile(outputFolder, "stage3A_training_loss.png");
    figurePaths.errorComparison = fullfile(outputFolder, "stage3A_constvel_vs_mlp_error.png");
    figurePaths.maneuverMetrics = fullfile(outputFolder, "stage3A_maneuver_class_metrics.png");
    figurePaths.trajectoryComparison = fullfile(outputFolder, "stage3A_trajectory_comparison.png");

    localWriteTrainingLossFigure(figurePaths.trainingLoss, stage3Summary);
    localWriteErrorComparisonFigure(figurePaths.errorComparison, stage3Summary);
    localWriteManeuverMetricsFigure(figurePaths.maneuverMetrics, stage3Summary);
    localWriteTrajectoryFigure(figurePaths.trajectoryComparison, stage3Summary);
catch err
    error("Stage3A:FigureWriteFailed", ...
        "Failed to write Stage 3A figures: %s", err.message);
end

end

function localWriteTrainingLossFigure(figurePath, stage3Summary)
%LOCALWRITETRAININGLOSSFIGURE Save trainnet loss traces.

lossFigure = figure("Name", "Stage 3A Training Loss", "Visible", "off");
cleanup = onCleanup(@() close(lossFigure));

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
hold on;
localPlotTrainingHistory(stage3Summary.trainingLadder.tinyOverfitInfo, "Tiny overfit");
localPlotTrainingHistory(stage3Summary.trainingLadder.shortPhysicsInfo, "Short physics MLP");
localPlotTrainingHistory(stage3Summary.trainingLadder.shortRawInfo, "Short raw MLP");
hold off;
grid on;
xlabel("Iteration");
ylabel("Training loss");
title("Stage 3A Mean-Only MLP Training Loss");
legend("Location", "best");

nexttile;
hold on;
localPlotValidationHistory(stage3Summary.trainingLadder.shortPhysicsInfo, "Short physics validation");
localPlotValidationHistory(stage3Summary.trainingLadder.shortRawInfo, "Short raw validation");
hold off;
grid on;
xlabel("Iteration");
ylabel("Validation loss");
title("Stage 3A Validation Loss");
legend("Location", "best");

exportgraphics(lossFigure, figurePath, "Resolution", 150);

end

function localWriteErrorComparisonFigure(figurePath, stage3Summary)
%LOCALWRITEERRORCOMPARISONFIGURE Compare constvel and MLP error distributions.

errorFigure = figure("Name", "Stage 3A Constvel Versus MLP Error", "Visible", "off");
cleanup = onCleanup(@() close(errorFigure));

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
hold on;
histogram(stage3Summary.baselineResults.constvelMetrics.positionErrorMeters, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
histogram(stage3Summary.metrics.positionErrorMeters, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
hold off;
grid on;
xlabel("Position error [m]");
ylabel("Pair count");
title("One-Step Position Error");
legend(["constvel", "Stage 3A delta MLP"], "Location", "best");

nexttile;
hold on;
histogram(stage3Summary.baselineResults.constvelMetrics.velocityErrorMetersPerSecond, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
histogram(stage3Summary.metrics.velocityErrorMetersPerSecond, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
hold off;
grid on;
xlabel("Velocity error [m/s]");
ylabel("Pair count");
title("One-Step Velocity Error");
legend(["constvel", "Stage 3A delta MLP"], "Location", "best");

exportgraphics(errorFigure, figurePath, "Resolution", 150);

end

function localWriteManeuverMetricsFigure(figurePath, stage3Summary)
%LOCALWRITEMANEUVERMETRICSFIGURE Save maneuver-class RMSE bars.

figureHandle = figure("Name", "Stage 3A Maneuver-Class Metrics", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));

constvelTable = stage3Summary.baselineResults.constvelMetrics.byManeuverClass;
mlpTable = stage3Summary.metrics.byManeuverClass;
classNames = string(mlpTable.groupName);
constvelRmse = localLookupGroupMetric(constvelTable, classNames, "positionRMSEMeters");
mlpRmse = mlpTable.positionRMSEMeters;

bar(categorical(classNames), [constvelRmse, mlpRmse]);
grid on;
xlabel("Maneuver class");
ylabel("Position RMSE [m]");
title("Stage 3A Position RMSE By Maneuver Class");
legend(["constvel", "Stage 3A delta MLP"], "Location", "best");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localWriteTrajectoryFigure(figurePath, stage3Summary)
%LOCALWRITETRAJECTORYFIGURE Save one selected track comparison.

figureHandle = figure("Name", "Stage 3A Trajectory Comparison", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));

trackRows = stage3Summary.selectedTrack.rows;
truthState = stage3Summary.nextState(trackRows, :);
constvelState = stage3Summary.predictions.constvelPredictedState(trackRows, :);
mlpState = stage3Summary.predictions.predictedNextState(trackRows, :);

hold on;
plot(truthState(:, 1), truthState(:, 3), "Color", [0.0000, 0.6500, 0.2500], "LineWidth", 2.0);
plot(constvelState(:, 1), constvelState(:, 3), "Color", [0.0000, 0.3000, 1.0000], "LineWidth", 1.5);
plot(mlpState(:, 1), mlpState(:, 3), "Color", [0.9000, 0.0500, 0.0500], "LineWidth", 1.5);
hold off;
axis equal;
grid on;
xlabel("East [m]");
ylabel("North [m]");
title("Selected Track: ADS-B Truth, Constvel, And Stage 3A MLP");
legend(["ADS-B truth", "constvel", "Stage 3A delta MLP"], "Location", "best");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localPlotTrainingHistory(trainingInfo, displayName)
%LOCALPLOTTRAININGHISTORY Plot trainnet training loss if available.

if isempty(trainingInfo) || isempty(trainingInfo.TrainingHistory)
    return;
end

history = trainingInfo.TrainingHistory;
plot(history.Iteration, history.Loss, "LineWidth", 1.3, "DisplayName", displayName);

end

function localPlotValidationHistory(trainingInfo, displayName)
%LOCALPLOTVALIDATIONHISTORY Plot trainnet validation loss if available.

if isempty(trainingInfo) || isempty(trainingInfo.ValidationHistory)
    return;
end

history = trainingInfo.ValidationHistory;
plot(history.Iteration, history.Loss, "LineWidth", 1.3, "DisplayName", displayName);

end

function values = localLookupGroupMetric(metricTable, groupNames, metricName)
%LOCALLOOKUPGROUPMETRIC Align metric rows to a requested group order.

values = NaN(numel(groupNames), 1);
tableGroupNames = string(metricTable.groupName);

for groupIdx = 1:numel(groupNames)
    rowIdx = find(tableGroupNames == groupNames(groupIdx), 1, "first");

    if ~isempty(rowIdx)
        values(groupIdx) = metricTable.(metricName)(rowIdx);
    end
end

end
