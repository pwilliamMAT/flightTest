function figurePaths = helperWriteStage3CFigures(outputFolder, stage3CSummary)
%HELPERWRITESTAGE3CFIGURES Save Stage 3C archive diagnostic figures.

outputFolder = string(outputFolder);
figurePaths = struct();

try
    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    figurePaths.archiveUsability = fullfile(outputFolder, "stage3C_archive_usability.png");
    figurePaths.readinessGates = fullfile(outputFolder, "stage3C_data_readiness_gates.png");
    figurePaths.motionUpdateCoverage = fullfile(outputFolder, "stage3C_motion_update_coverage.png");

    localWriteArchiveUsabilityFigure(figurePaths.archiveUsability, stage3CSummary);
    localWriteReadinessFigure(figurePaths.readinessGates, stage3CSummary);
    localWriteMotionCoverageFigure(figurePaths.motionUpdateCoverage, stage3CSummary);
catch err
    error("Stage3C:FigureWriteFailed", ...
        "Failed to write Stage 3C figures: %s", err.message);
end

end

function localWriteArchiveUsabilityFigure(figurePath, stage3CSummary)
%LOCALWRITEARCHIVEUSABILITYFIGURE Plot source usability and gzip handling.

sourceFileTable = stage3CSummary.archiveInventory.sourceFileTable;
figureHandle = figure("Name", "Stage 3C Archive Usability", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle, 2, 1, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

nexttile(layout);
statusName = [ ...
    "native gunzip usable"; ...
    "fallback usable"; ...
    "zero usable pairs"; ...
    "not selected or failed"];
statusCount = [ ...
    sum(sourceFileTable.nativeGzipStatus == "succeeded" & sourceFileTable.usablePairCount > 0); ...
    sum(sourceFileTable.fallbackStatus == "succeeded" & sourceFileTable.usablePairCount > 0); ...
    sum(sourceFileTable.selectedForEvaluation & sourceFileTable.usablePairCount == 0); ...
    sum(~sourceFileTable.selectedForEvaluation | sourceFileTable.parseStatus == "failed")];
bar(categorical(statusName), statusCount);
grid on;
xlabel("Archive file status");
ylabel("Source file count");
title("Stage 3C Archive Usability And Gzip Recovery");

nexttile(layout);
layoutTable = stage3CSummary.archiveInventory.layoutSummary;
bar(categorical(layoutTable.layout), layoutTable.sourceFileCount);
grid on;
xlabel("Archive layout");
ylabel("Truth file count");
title("Stage 3C Truth Files By Archive Layout");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localWriteReadinessFigure(figurePath, stage3CSummary)
%LOCALWRITEREADINESSFIGURE Plot Stage 3B gate counts with Stage 3C labels.

gateTable = stage3CSummary.dataReadiness.gateTable;
figureHandle = figure("Name", "Stage 3C Data Readiness Gates", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));
axisHandle = axes(figureHandle);

gateNames = categorical(string(gateTable.gate));
bar(axisHandle, gateNames, [gateTable.observedValue, gateTable.requiredValue]);
hold(axisHandle, "on");
failedRows = find(~gateTable.passed);

if ~isempty(failedRows)
    scatter( ...
        axisHandle, ...
        failedRows, ...
        gateTable.observedValue(failedRows), ...
        70, ...
        [0.9000, 0.1000, 0.1000], ...
        "v", ...
        "filled", ...
        "DisplayName", ...
        "failed gate");
end

hold(axisHandle, "off");
grid(axisHandle, "on");
xlabel(axisHandle, "Readiness gate");
ylabel(axisHandle, "Count");
title(axisHandle, "Stage 3C Archive Evaluation: Observed Versus Required Gates");
legend(axisHandle, ["observed", "required"], "Location", "best");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localWriteMotionCoverageFigure(figurePath, stage3CSummary)
%LOCALWRITEMOTIONCOVERAGEFIGURE Plot motion, vertical, and update coverage.

labelSummary = stage3CSummary.stage3BSummary.labelSummary;
figureHandle = figure("Name", "Stage 3C Motion And Update Coverage", "Visible", "off");
cleanup = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle, 3, 1, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

nexttile(layout);
localBarCategoryCounts( ...
    labelSummary.countsByManeuverClass.maneuverClass, ...
    labelSummary.countsByManeuverClass.pairCount, ...
    "Maneuver class", ...
    "Pair count", ...
    "Stage 3C Motion-Model Regime Coverage");

nexttile(layout);
localBarCategoryCounts( ...
    labelSummary.countsByDtRegime.dtRegime, ...
    labelSummary.countsByDtRegime.pairCount, ...
    "Update regime", ...
    "Pair count", ...
    "Stage 3C ADS-B Update-Regime Coverage");

nexttile(layout);
localBarCategoryCounts( ...
    labelSummary.countsByVerticalStatus.verticalStatus, ...
    labelSummary.countsByVerticalStatus.pairCount, ...
    "Vertical status", ...
    "Pair count", ...
    "Stage 3C Climb And Descent Coverage");

exportgraphics(figureHandle, figurePath, "Resolution", 150);

end

function localBarCategoryCounts(categoryValues, counts, xLabelText, yLabelText, titleText)
%LOCALBARCATEGORYCOUNTS Plot one categorical count table.

bar(categorical(string(categoryValues)), counts);
grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(titleText);

end
