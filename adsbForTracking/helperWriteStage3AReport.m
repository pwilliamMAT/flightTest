function helperWriteStage3AReport(reportPath, stage3Summary)
%HELPERWRITESTAGE3AREPORT Write the Stage 3A training report.

reportPath = string(reportPath);

try
    reportFolder = fileparts(reportPath);

    if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
        mkdir(reportFolder);
    end

    fid = fopen(reportPath, "w");

    if fid < 0
        error("Stage3A:ReportOpenFailed", ...
            "Unable to open Stage 3A report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 3A Local ADS-B Delta-Target MLP Training Report\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(datetime("now", "TimeZone", "UTC"), "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: existing Stage 2B and Stage 2C artifacts only. No new ADS-B data was collected.\n\n");

    fprintf(fid, "## Concept In Plain Language\n\n");
    fprintf(fid, "Stage 3A trains the neural network to predict the one-step change in aircraft state, not the absolute next state. The predicted delta is added back to the previous ADS-B-derived state, so even a weak model stays anchored near the current aircraft instead of drifting toward a dataset-average ENU location.\n\n");

    fprintf(fid, "```matlab\n");
    fprintf(fid, "targetDelta = nextState - previousState;\n");
    fprintf(fid, "predictedNextState = previousState + predictedDelta;\n");
    fprintf(fid, "```\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- Neural training: Deep Learning Toolbox `trainnet` with `trainingOptions(""adam"")`.\n");
    fprintf(fid, "- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel`.\n");
    fprintf(fid, "- Linear sanity baseline: Statistics and Machine Learning Toolbox `fitrlinear` with `fitlm` fallback.\n");
    fprintf(fid, "- Metrics and tables: MATLAB `table`, `findgroups`, `splitapply`, `vecnorm`, `mean`, `median`, and `prctile`.\n");
    fprintf(fid, "- Plots: MATLAB `figure`, `tiledlayout`, and `nexttile`.\n\n");

    fprintf(fid, "## Inputs\n\n");
    fprintf(fid, "| Artifact | Path |\n");
    fprintf(fid, "| :--- | :--- |\n");
    fprintf(fid, "| Stage 2B dataset | `%s` |\n", stage3Summary.datasetPath);
    fprintf(fid, "| Stage 2C maneuver labels | `%s` |\n", stage3Summary.characterizationPath);
    fprintf(fid, "| Stage 3A MAT | `%s` |\n", stage3Summary.artifactPath);
    fprintf(fid, "| Stage 3A report | `%s` |\n\n", stage3Summary.reportPath);

    if ~stage3Summary.config.PreflightOnly && ~isempty(stage3Summary.metrics)
        fprintf(fid, "## Headline RMSE Summary\n\n");
        fprintf(fid, "This table repeats the main `constvel` and Stage 3A delta-MLP aggregate metrics so they are not buried in the baseline ladder.\n\n");
        headlineTable = [ ...
            stage3Summary.baselineResults.constvelMetrics.aggregate; ...
            stage3Summary.metrics.aggregate];
        helperWriteTable(fid, headlineTable(:, [ ...
            "method", ...
            "positionRMSEMeters", ...
            "velocityRMSEMetersPerSecond", ...
            "positionMedianErrorMeters", ...
            "positionP95ErrorMeters"]));
        fprintf(fid, "\n");
    end
    fprintf(fid, "## Configuration\n\n");
    helperWriteTable(fid, stage3Summary.configTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Preflight Audit\n\n");
    fprintf(fid, "Preflight completed before neural training. The audit checked finite arrays, split counts, target-delta scale, feature standard deviations, maneuver labels, vertical-status labels, sparse-update labels, and `constvel` split metrics.\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.finiteCheckTable);
    fprintf(fid, "\n");

    fprintf(fid, "### Split Counts\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.splitCountTable);
    fprintf(fid, "\n");

    fprintf(fid, "### Split By Maneuver Class\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.splitByManeuverClass);
    fprintf(fid, "\n");

    fprintf(fid, "### Split By Vertical Status\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.splitByVerticalStatus);
    fprintf(fid, "\n");

    fprintf(fid, "### Sparse Update Counts\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.splitByDtRegime);
    fprintf(fid, "\n");

    fprintf(fid, "### Constvel Metrics By Split\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.constvelMetricsBySplit);
    fprintf(fid, "\n");

    fprintf(fid, "### Target Delta Statistics\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.targetDeltaStats);
    fprintf(fid, "\n");

    fprintf(fid, "### Feature Standard Deviations\n\n");
    helperWriteTable(fid, stage3Summary.preflightAudit.featureStdTable);
    fprintf(fid, "\n");

    fprintf(fid, "### Covariance Interface Note\n\n");
    fprintf(fid, "The Stage 2B artifact has %d unique `previousCovarianceDiag` row. It is retained for interface compatibility, but it has no training variation in this artifact.\n\n", stage3Summary.preflightAudit.previousCovarianceUniqueRowCount);

    fprintf(fid, "## Baseline Ladder\n\n");
    helperWriteTable(fid, stage3Summary.baselineResults.aggregateComparisonTable);
    fprintf(fid, "\n");

    fprintf(fid, "## Training Ladder Status\n\n");
    helperWriteTable(fid, stage3Summary.trainingLadder.ladderTable);
    fprintf(fid, "\n");

    if stage3Summary.config.PreflightOnly
        fprintf(fid, "Preflight-only mode was requested, so no neural training was run.\n\n");
    else
        fprintf(fid, "## Feature Ablation\n\n");
        helperWriteTable(fid, stage3Summary.trainingLadder.featureAblationTable);
        fprintf(fid, "\n");

        fprintf(fid, "## Final Delta MLP Metrics\n\n");
        helperWriteTable(fid, stage3Summary.metrics.aggregate);
        fprintf(fid, "\n");

        fprintf(fid, "### Metrics By Split\n\n");
        helperWriteTable(fid, stage3Summary.metrics.bySplit);
        fprintf(fid, "\n");

        fprintf(fid, "### Metrics By Maneuver Class\n\n");
        helperWriteTable(fid, stage3Summary.metrics.byManeuverClass);
        fprintf(fid, "\n");

        fprintf(fid, "### Metrics By Vertical Status\n\n");
        helperWriteTable(fid, stage3Summary.metrics.byVerticalStatus);
        fprintf(fid, "\n");

        fprintf(fid, "### Metrics By Sparse-Update Status\n\n");
        helperWriteTable(fid, stage3Summary.metrics.byDtRegime);
        fprintf(fid, "\n");
    end

    fprintf(fid, "## Interpretation\n\n");
    fprintf(fid, "- The required comparator remains native `constvel`.\n");
    fprintf(fid, "- If the Stage 3A MLP does not beat `constvel`, that is a training and data diagnostic, not a reason to tune around the result.\n");
    fprintf(fid, "- Current split behavior is not behavior-balanced: `constturn_like` is absent from validation/test in the present artifact, and the validation split is dominated by climb behavior.\n");
    fprintf(fid, "- The current data is not enough for broad maneuver-learning claims. It lacks turn, acceleration, climb/descent, sparse-update, session, and traffic diversity.\n\n");

    fprintf(fid, "## Figures\n\n");
    helperWriteFigureList(fid, stage3Summary.figurePaths);
catch err
    error("Stage3A:ReportWriteFailed", ...
        "Failed to write Stage 3A report: %s", err.message);
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
