function helperWriteStage3CReport(reportPath, stage3CSummary)
%HELPERWRITESTAGE3CREPORT Write the Stage 3C archive evaluation report.

reportPath = string(reportPath);

try
    reportFolder = fileparts(reportPath);

    if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
        mkdir(reportFolder);
    end

    fid = fopen(reportPath, "w");

    if fid < 0
        error("Stage3C:ReportOpenFailed", ...
            "Unable to open Stage 3C report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 3C Archived ADS-B Evaluation Report\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(datetime("now", "TimeZone", "UTC"), "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: inventory the archived ADS-B truth package, recover only the gzip files that fail MATLAB `gunzip`, and reuse the frozen Stage 3A versus native `constvel` Stage 3B scoring path. No neural retraining was run.\n\n");

    fprintf(fid, "## Concept In Plain Language\n\n");
    fprintf(fid, "Stage 3C asks whether the archived ADS-B truth package changes the data-readiness answer. The code treats each archived SBS-1 file as truth trajectory data, converts it into the same one-step ENU state-pair format used by Stage 3B, and scores the frozen Stage 3A MLP against MATLAB's native `constvel` predictor on identical rows.\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- Archive gzip handling: MATLAB `gunzip` first; .NET `System.IO.Compression.GZipStream` only for files where `gunzip` fails.\n");
    fprintf(fid, "- Truth import: existing `loadADSBTruth` parser for SBS-1 ADS-B files.\n");
    fprintf(fid, "- Coordinate conversion: Mapping Toolbox `wgs84Ellipsoid` and `geodetic2enu` through the Stage 3 state-pair builder.\n");
    fprintf(fid, "- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel` through Stage 3B scoring.\n");
    fprintf(fid, "- Frozen neural inference: Deep Learning Toolbox `minibatchpredict` through the saved Stage 3A artifact.\n");
    fprintf(fid, "- Reporting and plots: MATLAB `table`, `groupsummary`, `findgroups`, `splitapply`, `figure`, `tiledlayout`, and `nexttile`.\n\n");

    fprintf(fid, "## Inputs And Outputs\n\n");
    fprintf(fid, "| Artifact | Path |\n");
    fprintf(fid, "| :--- | :--- |\n");
    fprintf(fid, "| Archive root | `%s` |\n", stage3CSummary.archiveRoot);
    fprintf(fid, "| Stage 3C MAT artifact | `%s` |\n", stage3CSummary.artifactPath);
    fprintf(fid, "| Stage 3C report | `%s` |\n", stage3CSummary.reportPath);
    fprintf(fid, "| Archive inventory CSV | `%s` |\n", stage3CSummary.inventoryTablePath);
    fprintf(fid, "| Archive inventory MAT | `%s` |\n", stage3CSummary.inventoryArtifactPath);
    fprintf(fid, "| Stage 3B scoring MAT | `%s` |\n", stage3CSummary.stage3BScoringArtifactPath);
    fprintf(fid, "| Stage 3B scoring report | `%s` |\n\n", stage3CSummary.stage3BScoringReportPath);

    fprintf(fid, "## Archive Summary\n\n");
    helperWriteSummaryTable(fid, stage3CSummary.archiveSummary);
    fprintf(fid, "\n");

    fprintf(fid, "## Headline Aggregate Comparison\n\n");
    helperWriteTable(fid, stage3CSummary.metricComparisonTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Archive Layout Summary\n\n");
    helperWriteTable(fid, stage3CSummary.archiveInventory.layoutSummary);
    fprintf(fid, "\n");

    fprintf(fid, "## Archive Source Inventory\n\n");
    helperWriteTable(fid, stage3CSummary.archiveInventory.sourceFileTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Stage 3C Interpretation\n\n");
    helperWriteTable(fid, stage3CSummary.interpretationTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Data Readiness Gate\n\n");
    fprintf(fid, "%s\n\n", stage3CSummary.dataReadiness.recommendation);
    helperWriteTable(fid, stage3CSummary.dataReadiness.gateTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Verification Checks\n\n");
    helperWriteTable(fid, stage3CSummary.verificationTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Motion And Update Coverage\n\n");
    helperWriteTable(fid, stage3CSummary.stage3BSummary.labelSummary.countsByManeuverClass);
    fprintf(fid, "\n");
    helperWriteTable(fid, stage3CSummary.stage3BSummary.labelSummary.countsByDtRegime);
    fprintf(fid, "\n");
    helperWriteTable(fid, stage3CSummary.stage3BSummary.labelSummary.countsByVerticalStatus);
    fprintf(fid, "\n");

    fprintf(fid, "## Collection Recommendation\n\n");
    fprintf(fid, "%s\n\n", stage3CSummary.archiveSummary.collectionRecommendation);

    fprintf(fid, "## Figures\n\n");
    helperWriteFigureList(fid, stage3CSummary.figurePaths);
catch err
    error("Stage3C:ReportWriteFailed", ...
        "Failed to write Stage 3C report: %s", err.message);
end

end

function helperWriteSummaryTable(fid, archiveSummary)
%HELPERWRITESUMMARYTABLE Write selected scalar archive counts.

metric = [ ...
    "Source files"; ...
    "Selected evaluation files"; ...
    "Usable source files"; ...
    "Usable sessions"; ...
    "Usable one-step pairs"; ...
    "Aircraft tracks"; ...
    "Native gunzip failures"; ...
    "Fallback recovered files"; ...
    "Pi-only truth files"; ...
    "Default receiver-origin files"; ...
    "Stage 3B readiness passed"; ...
    "Retraining run"];
value = [ ...
    string(archiveSummary.sourceFileCount); ...
    string(archiveSummary.selectedEvaluationFileCount); ...
    string(archiveSummary.usableSourceFileCount); ...
    string(archiveSummary.usableSessionCount); ...
    string(archiveSummary.usablePairCount); ...
    string(archiveSummary.aircraftTrackCount); ...
    string(archiveSummary.nativeGunzipFailureCount); ...
    string(archiveSummary.fallbackRecoveredFileCount); ...
    string(archiveSummary.piOnlyTruthFileCount); ...
    string(archiveSummary.defaultReceiverOriginFileCount); ...
    string(archiveSummary.stage3BReadinessPassed); ...
    string(archiveSummary.retrainingRun)];
summaryTable = table(metric, value, ...
    'VariableNames', ["metric", "value"]);
helperWriteTable(fid, summaryTable);

end

function helperWriteFigureList(fid, figurePaths)
%HELPERWRITEFIGURELIST Write saved figure paths.

if isempty(figurePaths)
    fprintf(fid, "_No figures were generated._\n");
    return;
end

figureNames = string(fieldnames(figurePaths));

if isempty(figureNames)
    fprintf(fid, "_No figures were generated._\n");
    return;
end

for figureIdx = 1:numel(figureNames)
    figureName = figureNames(figureIdx);
    fprintf(fid, "- %s: `%s`\n", figureName, figurePaths.(figureName));
end

end

function helperWriteTable(fid, inputTable)
%HELPERWRITETABLE Write a basic Markdown table.

if isempty(inputTable) || height(inputTable) == 0
    fprintf(fid, "_No rows._\n");
    return;
end

variableNames = string(inputTable.Properties.VariableNames);
fprintf(fid, "| %s |\n", strjoin(variableNames, " | "));
fprintf(fid, "| %s |\n", strjoin(repmat(":---", 1, numel(variableNames)), " | "));

for rowIdx = 1:height(inputTable)
    rowValues = strings(1, numel(variableNames));

    for variableIdx = 1:numel(variableNames)
        value = inputTable{rowIdx, variableIdx};
        rowValues(variableIdx) = localFormatMarkdownValue(value);
    end

    fprintf(fid, "| %s |\n", strjoin(rowValues, " | "));
end

end

function valueText = localFormatMarkdownValue(value)
%LOCALFORMATMARKDOWNVALUE Format one table cell for Markdown.

if isstring(value)
    valueText = strjoin(value, ", ");
elseif ischar(value)
    valueText = string(value);
elseif iscategorical(value)
    valueText = strjoin(string(value), ", ");
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        if isfinite(double(value))
            valueText = string(sprintf("%.6g", value));
        else
            valueText = string(value);
        end
    else
        valueText = string(mat2str(value));
    end
elseif isdatetime(value)
    valueText = string(value);
else
    valueText = string(value);
end

valueText = replace(valueText, "|", "\|");

end
