function figurePaths = helperWriteStage4BPostCampaignFigures(outputFolder, comparison)
%HELPERWRITESTAGE4BPOSTCAMPAIGNFIGURES Visualize dataset growth and diversity.

outputFolder = string(outputFolder);

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

figurePaths = struct();
figurePaths.motionRegimeComparison = localPlotMotionRegimes(outputFolder, comparison);
figurePaths.continuousDistributions = localPlotContinuousDistributions(outputFolder, comparison);
figurePaths.eventAndConcentration = localPlotEvents(outputFolder, comparison);
figurePaths.jointRegimeOccupancy = localPlotJointOccupancy(outputFolder, comparison);
figurePaths.prospectiveSplitCoverage = localPlotSplitCoverage(outputFolder, comparison);
figurePaths.modelComparison = localPlotModelComparison(outputFolder, comparison);

end

function figurePath = localPlotMotionRegimes(outputFolder, comparison)
%LOCALPLOTMOTIONREGIMES Compare legacy maneuver-class counts and percentages.

tableData = comparison.pairRegimeComparison;
tableData = tableData(tableData.dimension == "legacy_maneuver_class", :);
regimes = ["constvel_like", "constacc_like", "constturn_like", "mixed_or_sparse"];
[countMatrix, percentMatrix] = localVariantRegimeMatrices( ...
    tableData, ...
    comparison.variantOrder, ...
    regimes);

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1);
title(layout, "Motion-regime coverage by dataset variant");

nexttile;
bar(categorical(regimes, regimes, regimes), countMatrix.');
ylabel("Pair count");
legend(comparison.variantDisplayNames, "Location", "best");
grid on;

nexttile;
bar(categorical(regimes, regimes, regimes), percentMatrix.');
ylabel("Pairs [%]");
xlabel("Legacy maneuver class");
grid on;

figurePath = fullfile(outputFolder, "stage4BPost_motion_regime_comparison.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function figurePath = localPlotContinuousDistributions(outputFolder, comparison)
%LOCALPLOTCONTINUOUSDISTRIBUTIONS Show empirical motion and timing spread.

variableNames = [ ...
    "horizontalSpeedMetersPerSecond", ...
    "altitudeMeters", ...
    "absTurnRateDegreesPerSecond", ...
    "absHorizontalAccelerationMetersPerSecondSquared", ...
    "verticalRateMetersPerSecond", ...
    "dtSeconds"];
axisLabels = [ ...
    "Horizontal speed [m/s]", ...
    "Altitude [m]", ...
    "|Turn rate| [deg/s]", ...
    "|Horizontal acceleration| [m/s^2]", ...
    "Vertical rate [m/s]", ...
    "Update interval [s]"];

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 3, 2);
title(layout, "Continuous motion and update-interval distributions");

for variableIdx = 1:numel(variableNames)
    nexttile;
    variableRows = comparison.continuousHistogramComparison.variable == ...
        variableNames(variableIdx);
    histogramTable = comparison.continuousHistogramComparison(variableRows, :);
    binLabels = unique(histogramTable.bin, "stable");
    percentMatrix = zeros(numel(binLabels), numel(comparison.variantOrder));

    for variantIdx = 1:numel(comparison.variantOrder)
        variantID = comparison.variantOrder(variantIdx);
        for binIdx = 1:numel(binLabels)
            row = histogramTable.variantID == variantID & ...
                histogramTable.bin == binLabels(binIdx);
            percentMatrix(binIdx, variantIdx) = histogramTable.percent(row);
        end
    end

    bar(categorical(binLabels, binLabels, binLabels), percentMatrix);
    xlabel(axisLabels(variableIdx) + " bin");
    ylabel("Pairs [%]");
    grid on;

    if variableIdx == 1
        legend(comparison.variantDisplayNames, "Location", "best");
    end
end

figurePath = fullfile(outputFolder, "stage4BPost_continuous_distributions.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function figurePath = localPlotEvents(outputFolder, comparison)
%LOCALPLOTEVENTS Compare independent-event counts and concentration.

eventTypes = [ ...
    "sustained_turn", ...
    "sustained_acceleration", ...
    "sustained_climb", ...
    "sustained_descent", ...
    "sparse_gap"];
eventLabels = ["Turn", "Acceleration", "Climb", "Descent", "Sparse gap"];
eventCounts = zeros(numel(comparison.variantOrder), numel(eventTypes));

for variantIdx = 1:numel(comparison.variantOrder)
    variantID = comparison.variantOrder(variantIdx);
    eventSummary = comparison.analyses.(variantID).eventSummary;

    for eventIdx = 1:numel(eventTypes)
        row = eventSummary.eventType == eventTypes(eventIdx);
        eventCounts(variantIdx, eventIdx) = eventSummary.eventCount(row);
    end
end

expanded = comparison.analyses.expanded_post3day_v2.eventSummary;
aircraftShare = zeros(numel(eventTypes), 1);
campaignBlockShare = zeros(numel(eventTypes), 1);

for eventIdx = 1:numel(eventTypes)
    row = expanded.eventType == eventTypes(eventIdx);
    aircraftShare(eventIdx) = expanded.largestAircraftSharePercent(row);
    campaignBlockShare(eventIdx) = ...
        expanded.largestCampaignBlockSharePercent(row);
end

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1);
title(layout, "Independent maneuver events and contributor concentration");

nexttile;
bar(categorical(eventLabels, eventLabels, eventLabels), eventCounts.');
ylabel("Independent event count");
legend(comparison.variantDisplayNames, "Location", "best");
grid on;

nexttile;
bar(categorical(eventLabels, eventLabels, eventLabels), ...
    [aircraftShare, campaignBlockShare]);
ylabel("Largest contribution [%]");
yline(20, "--", "ICAO limit");
yline(60, ":", "Campaign-day limit");
legend(["Largest ICAO", "Largest campaign day"], "Location", "best");
grid on;

figurePath = fullfile(outputFolder, "stage4BPost_events_and_concentration.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function figurePath = localPlotJointOccupancy(outputFolder, comparison)
%LOCALPLOTJOINTOCCUPANCY Show turn/acceleration joint coverage for Expanded-3Day.

occupancy = comparison.analyses.expanded_post3day_v2.jointRegimeOccupancy;
turnLevels = ["<0.5", "0.5-1", "1-3", ">=3"];
accelerationLevels = ["<0.1", "0.1-0.5", "0.5-1", ">=1"];
pairMatrix = zeros(numel(turnLevels), numel(accelerationLevels));
trackMatrix = zeros(numel(turnLevels), numel(accelerationLevels));

for turnIdx = 1:numel(turnLevels)
    for accelerationIdx = 1:numel(accelerationLevels)
        rowMask = occupancy.turnIntensity == turnLevels(turnIdx) & ...
            occupancy.accelerationIntensity == accelerationLevels(accelerationIdx);
        pairMatrix(turnIdx, accelerationIdx) = sum(occupancy.pairCount(rowMask));
        trackMatrix(turnIdx, accelerationIdx) = sum(occupancy.trackCount(rowMask));
    end
end

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2);
title(layout, "Expanded-3Day joint-regime occupancy");

nexttile;
imagesc(log10(pairMatrix + 1));
colorbar;
title("log10(pair count + 1)");
xlabel("|Horizontal acceleration| bin [m/s^2]");
ylabel("|Turn rate| bin [deg/s]");
xticks(1:numel(accelerationLevels));
xticklabels(accelerationLevels);
yticks(1:numel(turnLevels));
yticklabels(turnLevels);

nexttile;
imagesc(log10(trackMatrix + 1));
colorbar;
title("log10(track occupancy + 1)");
xlabel("|Horizontal acceleration| bin [m/s^2]");
ylabel("|Turn rate| bin [deg/s]");
xticks(1:numel(accelerationLevels));
xticklabels(accelerationLevels);
yticks(1:numel(turnLevels));
yticklabels(turnLevels);

figurePath = fullfile(outputFolder, "stage4BPost_joint_regime_occupancy.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function figurePath = localPlotSplitCoverage(outputFolder, comparison)
%LOCALPLOTSPLITCOVERAGE Show event support under both proposed split plans.

coverage = comparison.analyses.expanded_post3day_v2.splitAudit.eventCoverage;
strategies = ["aircraft_disjoint", "chronological_blocked"];
eventTypes = [ ...
    "sustained_turn", ...
    "sustained_acceleration", ...
    "sustained_climb", ...
    "sustained_descent", ...
    "sparse_gap"];
eventLabels = ["Turn", "Acceleration", "Climb", "Descent", "Sparse gap"];
splitNames = ["train", "validation", "test"];

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 1, 2);
title(layout, "Expanded-3Day prospective split event coverage");

for strategyIdx = 1:numel(strategies)
    coverageMatrix = zeros(numel(eventTypes), numel(splitNames));

    for eventIdx = 1:numel(eventTypes)
        for splitIdx = 1:numel(splitNames)
            row = coverage.splitStrategy == strategies(strategyIdx) & ...
                coverage.eventType == eventTypes(eventIdx) & ...
                coverage.split == splitNames(splitIdx);
            coverageMatrix(eventIdx, splitIdx) = coverage.eventCount(row);
        end
    end

    nexttile;
    imagesc(coverageMatrix);
    colorbar;
    title(replace(strategies(strategyIdx), "_", " "));
    xticks(1:numel(splitNames));
    xticklabels(splitNames);
    yticks(1:numel(eventLabels));
    yticklabels(eventLabels);
end

figurePath = fullfile(outputFolder, "stage4BPost_prospective_split_coverage.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function figurePath = localPlotModelComparison(outputFolder, comparison)
%LOCALPLOTMODELCOMPARISON Compare frozen MLP and constvel by variant/regime.

methods = ["constvel baseline", "Frozen Stage 3A delta MLP"];
aggregateMatrix = zeros(numel(comparison.variantOrder), numel(methods));

for variantIdx = 1:numel(comparison.variantOrder)
    variantID = comparison.variantOrder(variantIdx);
    metrics = comparison.variantSummaries.(variantID).metricComparisonTable;

    for methodIdx = 1:numel(methods)
        row = metrics.method == methods(methodIdx);
        aggregateMatrix(variantIdx, methodIdx) = metrics.positionRMSEMeters(row);
    end
end

[regimeLabels, regimeMatrix] = localBuildRegimeModelMatrix(comparison, methods);

fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1);
title(layout, "Frozen Stage 3A MLP versus native constvel");

nexttile;
bar(categorical( ...
    comparison.variantDisplayNames, ...
    comparison.variantDisplayNames, ...
    comparison.variantDisplayNames), aggregateMatrix);
ylabel("Position RMSE [m]");
legend(["constvel", "Frozen Stage 3A MLP"], "Location", "best");
grid on;

nexttile;
bar(categorical(regimeLabels, regimeLabels, regimeLabels), regimeMatrix);
ylabel("Position RMSE [m]");
xlabel("Variant / maneuver regime");
xtickangle(35);
legend(["constvel", "Frozen Stage 3A MLP"], "Location", "best");
grid on;

figurePath = fullfile(outputFolder, "stage4BPost_model_comparison.png");
exportgraphics(fig, figurePath, "Resolution", 150);

end

function [countMatrix, percentMatrix] = localVariantRegimeMatrices( ...
        tableData, variantIDs, regimes)
%LOCALVARIANTREGIMEMATRICES Build plot matrices from long-form summaries.

countMatrix = zeros(numel(variantIDs), numel(regimes));
percentMatrix = zeros(numel(variantIDs), numel(regimes));

for variantIdx = 1:numel(variantIDs)
    for regimeIdx = 1:numel(regimes)
        row = tableData.variantID == variantIDs(variantIdx) & ...
            tableData.regime == regimes(regimeIdx);

        if any(row)
            countMatrix(variantIdx, regimeIdx) = tableData.pairCount(row);
            percentMatrix(variantIdx, regimeIdx) = tableData.percent(row);
        end
    end
end

end

function [labels, metricMatrix] = localBuildRegimeModelMatrix(comparison, methods)
%LOCALBUILDREGIMEMODELMATRIX Stack variant/maneuver grouped RMSE values.

regimes = ["constvel_like", "constacc_like", "constturn_like", "mixed_or_sparse"];
labels = strings(numel(comparison.variantOrder) * numel(regimes), 1);
metricMatrix = NaN(numel(labels), numel(methods));
rowIdx = 0;

for variantIdx = 1:numel(comparison.variantOrder)
    variantID = comparison.variantOrder(variantIdx);
    metrics = comparison.variantSummaries.(variantID).stage3BSummary.metrics.byManeuverClass;

    for regimeIdx = 1:numel(regimes)
        rowIdx = rowIdx + 1;
        labels(rowIdx) = comparison.variantDisplayNames(variantIdx) + ...
            " / " + replace(regimes(regimeIdx), "_", " ");

        for methodIdx = 1:numel(methods)
            row = string(metrics.method) == methods(methodIdx) & ...
                string(metrics.groupName) == regimes(regimeIdx);

            if any(row)
                metricMatrix(rowIdx, methodIdx) = metrics.positionRMSEMeters(row);
            end
        end
    end
end

end
