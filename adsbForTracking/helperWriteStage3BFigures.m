function figurePaths = helperWriteStage3BFigures(outputFolder, stage3BSummary)
%HELPERWRITESTAGE3BFIGURES Save Stage 3B diagnostic figures.

outputFolder = string(outputFolder);
figurePaths = struct();

try
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    figurePaths.aggregateError = fullfile(outputFolder, "stage3B_constvel_vs_frozen_mlp_error.png");
    figurePaths.positionAbsError = fullfile(outputFolder, "stage3B_position_abs_error.png");
    figurePaths.groupMetrics = fullfile(outputFolder, "stage3B_grouped_position_rmse.png");
    figurePaths.readinessGates = fullfile(outputFolder, "stage3B_data_readiness_gates.png");
    figurePaths.trajectoryComparison = fullfile(outputFolder, "stage3B_trajectory_comparison.png");

    localWriteAggregateErrorFigure(figurePaths.aggregateError, stage3BSummary);
    helperPlotStage3BPositionAbsError( ...
        stage3BSummary, ...
        "Visible", ...
        "off", ...
        "FigurePath", ...
        figurePaths.positionAbsError);
    localWriteGroupMetricsFigure(figurePaths.groupMetrics, stage3BSummary);
    localWriteReadinessFigure(figurePaths.readinessGates, stage3BSummary);
    localWriteTrajectoryFigure(figurePaths.trajectoryComparison, stage3BSummary);
catch err
    error("Stage3B:FigureWriteFailed", ...
        "Failed to write Stage 3B figures: %s", err.message);
end

end

function localWriteAggregateErrorFigure(figurePath, stage3BSummary)
%LOCALWRITEAGGREGATEERRORFIGURE Compare row-wise error distributions.

pairErrorTable = stage3BSummary.pairErrorTable;
errorFigure = figure("Name", "Stage 3B Aggregate Error", "Visible", "off");
cleanup = onCleanup(@() close(errorFigure));

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
hold on;
histogram(pairErrorTable.constvelPositionErrorMeters, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
histogram(pairErrorTable.frozenStage3APositionErrorMeters, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
hold off;
grid on;
xlabel("Position error [m]");
ylabel("Pair count");
title("Stage 3B One-Step Position Error");
legend(["constvel", "Frozen Stage 3A MLP"], "Location", "best");

nexttile;
hold on;
histogram(pairErrorTable.constvelVelocityErrorMetersPerSecond, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
histogram(pairErrorTable.frozenStage3AVelocityErrorMetersPerSecond, 40, ...
    "DisplayStyle", "stairs", ...
    "LineWidth", 1.5);
hold off;
grid on;
xlabel("Velocity error [m/s]");
ylabel("Pair count");
title("Stage 3B One-Step Velocity Error");
legend(["constvel", "Frozen Stage 3A MLP"], "Location", "best");

exportgraphics(errorFigure, figurePath, "Resolution", 150);

end

function localWriteGroupMetricsFigure(figurePath, stage3BSummary)
%LOCALWRITEGROUPMETRICSFIGURE Save grouped position RMSE comparisons.

metrics = stage3BSummary.metrics;
figureHandle = figure("Name", "Stage 3B Grouped Position RMSE", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
localPlotGroupedRMSE( ...
    metrics.byManeuverClass, ...
    "Maneuver class", ...
    "Stage 3B Position RMSE By Maneuver Class");

nexttile;
localPlotGroupedRMSE( ...
    metrics.byDtRegime, ...
    "dt regime", ...
    "Stage 3B Position RMSE By Update Regime");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localPlotGroupedRMSE(metricTable, xLabelText, titleText)
%LOCALPLOTGROUPEDRMSE Plot constvel and frozen MLP RMSE by group.

mlpRows = string(metricTable.method) == "Frozen Stage 3A delta MLP";
mlpTable = metricTable(mlpRows, :);
groupNames = string(mlpTable.groupName);
constvelRmse = localLookupGroupMetric(metricTable, "constvel baseline", groupNames, "positionRMSEMeters");
mlpRmse = mlpTable.positionRMSEMeters;

bar(categorical(groupNames), [constvelRmse, mlpRmse]);
grid on;
xlabel(xLabelText);
ylabel("Position RMSE [m]");
title(titleText);
legend(["constvel", "Frozen Stage 3A MLP"], "Location", "best");

end

function localWriteReadinessFigure(figurePath, stage3BSummary)
%LOCALWRITEREADINESSFIGURE Plot observed values against readiness gates.

gateTable = stage3BSummary.dataReadiness.gateTable;
figureHandle = figure("Name", "Stage 3B Data Readiness Gates", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));

gateNames = categorical(string(gateTable.gate));
bar(gateNames, [gateTable.observedValue, gateTable.requiredValue]);
grid on;
xlabel("Readiness gate");
ylabel("Count");
title("Stage 3B Data Readiness: Observed Versus Required");
legend(["observed", "required"], "Location", "best");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localWriteTrajectoryFigure(figurePath, stage3BSummary)
%LOCALWRITETRAJECTORYFIGURE Save one selected-track ENU comparison.

figureHandle = figure("Name", "Stage 3B Trajectory Comparison", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));

trackRows = stage3BSummary.selectedTrack.rows;
truthState = stage3BSummary.nextState(trackRows, :);
constvelState = stage3BSummary.predictions.constvelPredictedNextState(trackRows, :);
mlpState = stage3BSummary.predictions.frozenStage3APredictedNextState(trackRows, :);

hold on;
plot(truthState(:, 1), truthState(:, 3), "Color", [0.0000, 0.6500, 0.2500], "LineWidth", 2.0);
plot(constvelState(:, 1), constvelState(:, 3), "Color", [0.0000, 0.3000, 1.0000], "LineWidth", 1.5);
plot(mlpState(:, 1), mlpState(:, 3), "Color", [0.9000, 0.0500, 0.0500], "LineWidth", 1.5);
hold off;
axis equal;
grid on;
xlabel("East [m]");
ylabel("North [m]");
title("Selected Track: ADS-B Truth, Constvel, And Frozen Stage 3A MLP");
legend(["ADS-B truth", "constvel", "Frozen Stage 3A MLP"], "Location", "best");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function values = localLookupGroupMetric(metricTable, methodName, groupNames, metricName)
%LOCALLOOKUPGROUPMETRIC Align metric rows to a requested group order.

values = NaN(numel(groupNames), 1);
tableMethod = string(metricTable.method);
tableGroupNames = string(metricTable.groupName);

for groupIdx = 1:numel(groupNames)
    rowIdx = find(tableMethod == methodName & tableGroupNames == groupNames(groupIdx), 1, "first");

    if ~isempty(rowIdx)
        values(groupIdx) = metricTable.(metricName)(rowIdx);
    end
end

end
