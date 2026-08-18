function plotOutput = helperPlotStage4ADSBTruthCapturePlan(capturePlan, varargin)
%HELPERPLOTSTAGE4ADSBTRUTHCAPTUREPLAN Plot Stage 4A capture questions.
% The plots are the primary review surface for the Stage 4A checkpoint.

defaultOutputFolder = fullfile( ...
    capturePlan.projectRoot, ...
    "artifacts", ...
    "stage4A");

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, "capturePlan", @isstruct);
addParameter(parser, "OutputFolder", defaultOutputFolder);
addParameter(parser, "Visible", "on");
addParameter(parser, "SaveFigures", true);
addParameter(parser, "CloseFigures", false);
addParameter(parser, "PlotName", "all");
parse(parser, capturePlan, varargin{:});

outputFolder = string(parser.Results.OutputFolder);
visibleSetting = char(parser.Results.Visible);
saveFigures = logical(parser.Results.SaveFigures);
closeFigures = logical(parser.Results.CloseFigures);
plotSelection = string(parser.Results.PlotName);

localValidateCapturePlan(capturePlan);

if saveFigures && strlength(outputFolder) > 0 && ~isfolder(outputFolder)
    mkdir(outputFolder);
end

plotSpecs = localPlotSpecs();
plotNames = string(fieldnames(plotSpecs));

if plotSelection ~= "all"
    plotNames = plotNames(plotNames == plotSelection);
end

if isempty(plotNames)
    error("Stage4A:UnknownPlotName", ...
        "PlotName must be all or one of: %s", strjoin(string(fieldnames(plotSpecs)), ", "));
end

plotOutput = struct();
plotOutput.outputFolder = outputFolder;
plotOutput.figureHandles = struct();
plotOutput.figurePaths = struct();
plotOutput.plotNames = plotNames;

for plotIdx = 1:numel(plotNames)
    plotName = plotNames(plotIdx);
    figureHandle = localCreatePlot(plotName, capturePlan, visibleSetting);
    plotOutput.figureHandles.(plotName) = figureHandle;

    if saveFigures
        figurePath = fullfile(outputFolder, plotSpecs.(plotName).fileName);
        exportgraphics(figureHandle, figurePath, "Resolution", 150);
        plotOutput.figurePaths.(plotName) = figurePath;
    else
        plotOutput.figurePaths.(plotName) = "";
    end

    if closeFigures
        close(figureHandle);
    end
end

end

function localValidateCapturePlan(capturePlan)
%LOCALVALIDATECAPTUREPLAN Verify required plot-ready fields.

requiredFields = [ ...
    "readinessGateTable", ...
    "motionCoverageTable", ...
    "rmseByManeuverClass", ...
    "rmseByUpdateRegime", ...
    "splitCoverage", ...
    "sourceCoverageTable", ...
    "receiverMetadataTable", ...
    "collectionPriorityTable", ...
    "captureProgressTable", ...
    "captureCommandTemplate", ...
    "truthFolderLayout", ...
    "requiredMetadataLayout"];

for fieldIdx = 1:numel(requiredFields)
    fieldName = requiredFields(fieldIdx);

    if ~isfield(capturePlan, fieldName)
        error("Stage4A:MissingCapturePlanField", ...
            "Capture plan is missing field: %s", fieldName);
    end
end

end

function plotSpecs = localPlotSpecs()
%LOCALPLOTSPECS Return plot output metadata.

plotSpecs = struct();
plotSpecs.readinessGates = struct( ...
    "fileName", ...
    "stage4A_readiness_gates.png");
plotSpecs.motionCoverage = struct( ...
    "fileName", ...
    "stage4A_motion_coverage_shortfall.png");
plotSpecs.modelDataProblem = struct( ...
    "fileName", ...
    "stage4A_model_vs_data_problem.png");
plotSpecs.splitCoverage = struct( ...
    "fileName", ...
    "stage4A_split_coverage.png");
plotSpecs.captureCampaign = struct( ...
    "fileName", ...
    "stage4A_capture_campaign_progress.png");

end

function figureHandle = localCreatePlot(plotName, capturePlan, visibleSetting)
%LOCALCREATEPLOT Dispatch one Stage 4A plot.

switch plotName
    case "readinessGates"
        figureHandle = localPlotReadinessGates(capturePlan, visibleSetting);
    case "motionCoverage"
        figureHandle = localPlotMotionCoverage(capturePlan, visibleSetting);
    case "modelDataProblem"
        figureHandle = localPlotModelDataProblem(capturePlan, visibleSetting);
    case "splitCoverage"
        figureHandle = localPlotSplitCoverage(capturePlan, visibleSetting);
    case "captureCampaign"
        figureHandle = localPlotCaptureCampaign(capturePlan, visibleSetting);
    otherwise
        error("Stage4A:UnknownPlotName", ...
            "Unknown Stage 4A plot name: %s", plotName);
end

end

function figureHandle = localPlotReadinessGates(capturePlan, visibleSetting)
%LOCALPLOTREADINESSGATES Plot observed, required, and recommended counts.

gateTable = capturePlan.readinessGateTable;
figureHandle = figure( ...
    "Name", ...
    "Stage 4A Readiness Gate Counts", ...
    "Visible", ...
    visibleSetting);
axisHandle = axes(figureHandle);

xValues = 1:height(gateTable);
barData = [ ...
    gateTable.observedValue, ...
    gateTable.requiredValue, ...
    gateTable.recommendedValue];
barSeries = bar(axisHandle, xValues, barData);
barSeries(1).FaceColor = [0.2000, 0.5000, 0.8500];
barSeries(1).DisplayName = "observed";
barSeries(2).FaceColor = [0.4500, 0.4500, 0.4500];
barSeries(2).DisplayName = "required";
barSeries(3).FaceColor = [0.0500, 0.6500, 0.2500];
barSeries(3).DisplayName = "recommended";

hold(axisHandle, "on");
failedIdx = find(~gateTable.passed);

if ~isempty(failedIdx)
    scatter( ...
        axisHandle, ...
        failedIdx, ...
        gateTable.observedValue(failedIdx), ...
        70, ...
        [0.9000, 0.1000, 0.1000], ...
        "v", ...
        "filled", ...
        "DisplayName", ...
        "failed gate");
end

hold(axisHandle, "off");
grid(axisHandle, "on");
xticks(axisHandle, xValues);
xticklabels(axisHandle, localCompactLabels(gateTable.gate));
xtickangle(axisHandle, 35);
xlabel(axisHandle, "Readiness gate");
ylabel(axisHandle, "Count");
title(axisHandle, "Question 1: Are We Ready To Retrain?");
legend(axisHandle, "Location", "best");

end

function figureHandle = localPlotMotionCoverage(capturePlan, visibleSetting)
%LOCALPLOTMOTIONCOVERAGE Plot motion regime gaps against targets.

motionTable = capturePlan.motionCoverageTable;
figureHandle = figure( ...
    "Name", ...
    "Stage 4A Motion Coverage Shortfalls", ...
    "Visible", ...
    visibleSetting);
axisHandle = axes(figureHandle);

xValues = 1:height(motionTable);
barData = [motionTable.observedValue, motionTable.targetValue];
barSeries = bar(axisHandle, xValues, barData);
barSeries(1).FaceColor = [0.2000, 0.5000, 0.8500];
barSeries(2).FaceColor = [0.4500, 0.4500, 0.4500];

hold(axisHandle, "on");
shortfallRows = find(motionTable.shortfallValue > 0);

for rowIdx = shortfallRows.'
    yValue = max(motionTable.observedValue(rowIdx), motionTable.targetValue(rowIdx));
    text( ...
        axisHandle, ...
        rowIdx, ...
        yValue * 1.04 + 1, ...
        sprintf("need %d", motionTable.shortfallValue(rowIdx)), ...
        "Color", ...
        [0.8500, 0.0500, 0.0500], ...
        "HorizontalAlignment", ...
        "center");
end

hold(axisHandle, "off");
grid(axisHandle, "on");
xticks(axisHandle, xValues);
xticklabels(axisHandle, localCompactLabels(motionTable.regime));
xtickangle(axisHandle, 35);
xlabel(axisHandle, "Motion or update regime");
ylabel(axisHandle, "State-pair count");
title(axisHandle, "Question 2: What Motion Regimes Are Missing?");
legend(axisHandle, ["observed", "target"], "Location", "best");

end

function figureHandle = localPlotModelDataProblem(capturePlan, visibleSetting)
%LOCALPLOTMODELDATAPROBLEM Compare constvel and frozen MLP RMSE by regime.

figureHandle = figure( ...
    "Name", ...
    "Stage 4A Model Versus Data Problem", ...
    "Visible", ...
    visibleSetting);
layout = tiledlayout(figureHandle, 2, 1, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

axisHandle = nexttile(layout);
localPlotRmseComparison( ...
    axisHandle, ...
    capturePlan.rmseByManeuverClass, ...
    "Maneuver class", ...
    "Position RMSE By Maneuver Class");

axisHandle = nexttile(layout);
localPlotRmseComparison( ...
    axisHandle, ...
    capturePlan.rmseByUpdateRegime, ...
    "Update regime", ...
    "Position RMSE By ADS-B Update Regime");

end

function localPlotRmseComparison(axisHandle, comparisonTable, xLabelText, titleText)
%LOCALPLOTRMSECOMPARISON Plot grouped constvel and frozen MLP RMSE.

xValues = 1:height(comparisonTable);
barData = [ ...
    comparisonTable.constvelPositionRMSEMeters, ...
    comparisonTable.frozenMLPPositionRMSEMeters];
barSeries = bar(axisHandle, xValues, barData);
barSeries(1).FaceColor = [0.0000, 0.3000, 1.0000];
barSeries(2).FaceColor = [0.9000, 0.0500, 0.0500];
grid(axisHandle, "on");
xticks(axisHandle, xValues);
xticklabels(axisHandle, localCompactLabels(comparisonTable.groupName));
xtickangle(axisHandle, 25);
xlabel(axisHandle, xLabelText);
ylabel(axisHandle, "Position RMSE [m]");
title(axisHandle, titleText);
legend(axisHandle, ["constvel", "Frozen Stage 3A MLP"], "Location", "best");

end

function figureHandle = localPlotSplitCoverage(capturePlan, visibleSetting)
%LOCALPLOTSPLITCOVERAGE Plot split coverage by maneuver and sparse status.

splitCoverage = capturePlan.splitCoverage;
figureHandle = figure( ...
    "Name", ...
    "Stage 4A Split Coverage", ...
    "Visible", ...
    visibleSetting);
axisHandle = axes(figureHandle);

imagesc(axisHandle, splitCoverage.matrix);
colormap(axisHandle, "parula");
colorbar(axisHandle);
xticks(axisHandle, 1:numel(splitCoverage.columnLabels));
xticklabels(axisHandle, localCompactLabels(splitCoverage.columnLabels));
yticks(axisHandle, 1:numel(splitCoverage.rowLabels));
yticklabels(axisHandle, localCompactLabels(splitCoverage.rowLabels));
xtickangle(axisHandle, 35);
xlabel(axisHandle, "Split and update regime");
ylabel(axisHandle, "Maneuver class");
title(axisHandle, "Question 4: Can Splits Evaluate Generalized Motion?");

end

function figureHandle = localPlotCaptureCampaign(capturePlan, visibleSetting)
%LOCALPLOTCAPTURECAMPAIGN Plot targeted Stage 4 collection priorities.

sourceTable = capturePlan.sourceCoverageTable;
metadataTable = capturePlan.receiverMetadataTable;
priorityTable = capturePlan.collectionPriorityTable;
figureHandle = figure( ...
    "Name", ...
    "Stage 4A Targeted ADS-B Collection Priorities", ...
    "Position", ...
    [100, 100, 960, 780], ...
    "Visible", ...
    visibleSetting);
layout = tiledlayout(figureHandle, 3, 1, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

axisHandle = nexttile(layout);
sourceYValues = 1:height(sourceTable);
barh(axisHandle, sourceYValues, sourceTable.truthFileCount);
set(axisHandle, "YDir", "reverse");
grid(axisHandle, "on");
xlabel(axisHandle, "Truth file count");
ylabel(axisHandle, "ADS-B truth source");
yticks(axisHandle, sourceYValues);
yticklabels(axisHandle, localCompactLabels(sourceTable.sourceName));
title(axisHandle, "Pi-Only Versus Testing-Machine Source Coverage");

axisHandle = nexttile(layout);
metadataYValues = 1:height(metadataTable);
barh(axisHandle, metadataYValues, metadataTable.fileCount);
set(axisHandle, "YDir", "reverse");
grid(axisHandle, "on");
xlabel(axisHandle, "File count");
ylabel(axisHandle, "Receiver-origin source");
yticks(axisHandle, metadataYValues);
yticklabels(axisHandle, localCompactLabels(metadataTable.originSource));
title(axisHandle, "Receiver-Origin Metadata Coverage");

axisHandle = nexttile(layout);
yValues = 1:height(priorityTable);
targetForPlot = max(priorityTable.targetValue, eps);
observedForPlot = min(priorityTable.observedValue ./ targetForPlot, 1);
remainingValue = max(1 - observedForPlot, 0);
barData = [observedForPlot, remainingValue];
barSeries = barh(axisHandle, yValues, barData, "stacked");
barSeries(1).FaceColor = [0.0500, 0.6500, 0.2500];
barSeries(2).FaceColor = [0.8000, 0.8000, 0.8000];
set(axisHandle, "YDir", "reverse");
grid(axisHandle, "on");
yticks(axisHandle, yValues);
yticklabels(axisHandle, localCompactLabels(priorityTable.priority));
xlim(axisHandle, [0, 1.8]);
xticks(axisHandle, 0:0.25:1);
xlabel(axisHandle, "Progress toward target fraction");
ylabel(axisHandle, "Collection priority");
title(axisHandle, "Stage 4A Collection Status After Stage 3C");
legend(axisHandle, ["observed", "remaining"], "Location", "best");

hold(axisHandle, "on");
for rowIdx = 1:height(priorityTable)
    labelValue = sprintf( ...
        "%s", ...
        priorityTable.status(rowIdx));
    text( ...
        axisHandle, ...
        1.03, ...
        rowIdx, ...
        labelValue, ...
        "VerticalAlignment", ...
        "middle", ...
        "FontSize", ...
        8, ...
        "Interpreter", ...
        "none");
end
hold(axisHandle, "off");

end
function labels = localCompactLabels(values)
%LOCALCOMPACTLABELS Make labels readable on compact axes.

labels = replace(string(values), "_", " ");
labels = replace(labels, "distinct ADS-B ", "");
labels = replace(labels, "local ", "");
labels = replace(labels, " used", "");

end


