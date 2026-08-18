function helperWriteStage3BReport(reportPath, stage3BSummary)
%HELPERWRITESTAGE3BREPORT Write the Stage 3B aggregate evaluation report.

reportPath = string(reportPath);

try
    reportFolder = fileparts(reportPath);

    if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
        mkdir(reportFolder);
    end

    fid = fopen(reportPath, "w");

    if fid < 0
        error("Stage3B:ReportOpenFailed", ...
            "Unable to open Stage 3B report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 3B Aggregate ADS-B Evaluation Report\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(datetime("now", "TimeZone", "UTC"), "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: aggregate all currently discoverable local ADS-B truth data, evaluate the frozen Stage 3A MLP against native `constvel`, and decide whether the data is ready for a future retraining stage. No neural retraining was run.\n\n");

    fprintf(fid, "## Concept In Plain Language\n\n");
    fprintf(fid, "Stage 3B freezes the Stage 3A neural network and treats it like a saved prediction component. Every eligible ADS-B state pair is scored twice: once with the native constant-velocity model and once with the frozen delta-target MLP. The comparison uses the exact same rows, so any difference comes from the predictor rather than from a data split mismatch.\n\n");

    fprintf(fid, "```matlab\n");
    fprintf(fid, "constvelPredictedNextState = constvel(previousState, dtSeconds);\n");
    fprintf(fid, "predictedDeltaNormalized = minibatchpredict(net, frozenFeatures);\n");
    fprintf(fid, "predictedDelta = predictedDeltaNormalized .* targetStd + targetMean;\n");
    fprintf(fid, "frozenStage3APredictedNextState = previousState + predictedDelta;\n");
    fprintf(fid, "```\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- ADS-B state-pair aggregation: existing local `loadADSBTruth` and Stage 2B dataset builder.\n");
    fprintf(fid, "- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel`.\n");
    fprintf(fid, "- Frozen neural inference: Deep Learning Toolbox `minibatchpredict`.\n");
    fprintf(fid, "- Metrics and grouped reporting: MATLAB `table`, `findgroups`, `splitapply`, `vecnorm`, `mean`, `median`, and `prctile`.\n");
    fprintf(fid, "- Plots: MATLAB `figure`, `tiledlayout`, `nexttile`, and optional `trackingGlobeViewer` review.\n\n");

    fprintf(fid, "## Inputs And Outputs\n\n");
    fprintf(fid, "| Artifact | Path |\n");
    fprintf(fid, "| :--- | :--- |\n");
    fprintf(fid, "| Stage 3B aggregate dataset | `%s` |\n", stage3BSummary.aggregateDatasetPath);
    fprintf(fid, "| Stage 3B dataset summary | `%s` |\n", stage3BSummary.aggregateDatasetReportPath);
    fprintf(fid, "| Frozen Stage 3A artifact | `%s` |\n", stage3BSummary.stage3AArtifactPath);
    fprintf(fid, "| Stage 3B MAT artifact | `%s` |\n", stage3BSummary.artifactPath);
    fprintf(fid, "| Stage 3B report | `%s` |\n\n", stage3BSummary.reportPath);

    fprintf(fid, "## Headline Aggregate Comparison\n\n");
    helperWriteTable(fid, stage3BSummary.metricComparisonTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Data Inventory\n\n");
    helperWriteTable(fid, stage3BSummary.inventoryTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Data Readiness Gate\n\n");
    fprintf(fid, "%s\n\n", stage3BSummary.dataReadiness.recommendation);
    helperWriteTable(fid, stage3BSummary.dataReadiness.gateTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Verification Checks\n\n");
    helperWriteTable(fid, stage3BSummary.verificationTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Session\n\n");
    helperWriteTable(fid, stage3BSummary.metrics.bySession);
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Source File\n\n");
    helperWriteTable(fid, stage3BSummary.metrics.bySourceFile);
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Aircraft Track\n\n");
    helperWriteTable(fid, localTopRows(stage3BSummary.metrics.byAircraftTrack, 40));
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Maneuver Class\n\n");
    helperWriteTable(fid, stage3BSummary.metrics.byManeuverClass);
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Vertical Status\n\n");
    helperWriteTable(fid, stage3BSummary.metrics.byVerticalStatus);
    fprintf(fid, "\n");

    fprintf(fid, "## Metrics By Sparse-Update Status\n\n");
    helperWriteTable(fid, stage3BSummary.metrics.byDtRegime);
    fprintf(fid, "\n");

    fprintf(fid, "## Representative Track\n\n");
    fprintf(fid, "Selected session: `%s`\n\n", stage3BSummary.selectedTrack.sessionID);
    fprintf(fid, "Selected aircraft hex: `%s`\n\n", stage3BSummary.selectedTrack.hex);
    helperWriteTable(fid, localSelectedTrackSummary(stage3BSummary.trackSummary, stage3BSummary.selectedTrack));
    fprintf(fid, "\n");

    fprintf(fid, "## Interpretation\n\n");
    fprintf(fid, "- Stage 3B is an evaluation and data-readiness gate, not a retraining run.\n");
    fprintf(fid, "- The frozen Stage 3A MLP is scored on the same samples as `constvel`.\n");
    fprintf(fid, "- The current aggregate should not be used for a broad retraining claim unless the readiness gate passes.\n");
    fprintf(fid, "- A later retraining or residual-learning experiment should be tracked as a new stage.\n\n");

    fprintf(fid, "## Figures\n\n");
    helperWriteFigureList(fid, stage3BSummary.figurePaths);
catch err
    error("Stage3B:ReportWriteFailed", ...
        "Failed to write Stage 3B report: %s", err.message);
end

end

function outputTable = localTopRows(inputTable, maxRows)
%LOCALTOPROWS Limit a long report table.

if isempty(inputTable) || height(inputTable) <= maxRows
    outputTable = inputTable;
    return;
end

outputTable = inputTable(1:maxRows, :);

end

function selectedSummary = localSelectedTrackSummary(trackSummary, selectedTrack)
%LOCALSELECTEDTRACKSUMMARY Return the selected track row.

if isempty(trackSummary) || height(trackSummary) == 0
    selectedSummary = table();
    return;
end

rowMask = string(trackSummary.sessionID) == string(selectedTrack.sessionID) & ...
    string(trackSummary.hex) == string(selectedTrack.hex);

if any(rowMask)
    selectedSummary = trackSummary(find(rowMask, 1, "first"), :);
else
    selectedSummary = table();
end

end

function helperWriteFigureList(fid, figurePaths)
%HELPERWRITEFIGURELIST Write saved figures if present.

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
%HELPERWRITETABLE Write a simple Markdown table.

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
