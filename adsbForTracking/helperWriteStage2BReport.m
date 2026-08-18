function helperWriteStage2BReport(reportPath, dataset, trainingSummary)
%HELPERWRITESTAGE2BREPORT Write a concise Stage 2B smoke summary report.

reportPath = string(reportPath);

try
    reportFolder = fileparts(reportPath);

    if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
        mkdir(reportFolder);
    end

    fid = fopen(reportPath, "w");

    if fid < 0
        error("Stage2B:ReportOpenFailed", "Unable to open report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 2B Local ADS-B Smoke Pipeline Summary\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(datetime("now", "TimeZone", "UTC"), "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: local ADS-B dataset construction, `constvel` baseline scoring, and minimal MLP smoke training only. This is not a final model-quality claim.\n\n");

    fprintf(fid, "## Concept In Plain Language\n\n");
    fprintf(fid, "Each ADS-B aircraft track is converted from latitude, longitude, and altitude into local east-north-up meters around the receiver. Adjacent samples from the same aircraft become one-step training examples: the model receives the previous state, assumed covariance diagonal, and elapsed time, then predicts the next state and diagonal uncertainty.\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- Parser: existing `loadADSBTruth` from `BistaticDataAnalysis`.\n");
    fprintf(fid, "- Coordinate conversion: Mapping Toolbox `wgs84Ellipsoid` and `geodetic2enu`.\n");
    fprintf(fid, "- State convention: Sensor Fusion `[x; vx; y; vy; z; vz]`.\n");
    fprintf(fid, "- Baseline: Sensor Fusion and Tracking Toolbox `constvel`.\n");
    fprintf(fid, "- Smoke model: Deep Learning Toolbox `dlnetwork` with diagonal Gaussian NLL.\n\n");

    fprintf(fid, "## Dataset Summary\n\n");
    buildSummary = dataset.buildSummary;
    fprintf(fid, "| Metric | Value |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Raw source files | %d |\n", buildSummary.rawFileCount);
    fprintf(fid, "| Parsed files | %d |\n", buildSummary.parsedFileCount);
    fprintf(fid, "| Parsed aircraft tracks | %d |\n", buildSummary.parsedAircraftCount);
    fprintf(fid, "| Valid ADS-B state samples | %d |\n", buildSummary.validSampleCount);
    fprintf(fid, "| Usable one-step pairs | %d |\n", buildSummary.usablePairCount);
    fprintf(fid, "| Duplicate timestamps removed | %d |\n", buildSummary.duplicateTimestampRecordsRemoved);
    fprintf(fid, "| Adjacent candidate pairs | %d |\n", buildSummary.totalAdjacentPairCount);
    fprintf(fid, "| Rejected nonfinite endpoint pairs | %d |\n", buildSummary.rejectedPairCounts.nonfiniteEndpoint);
    fprintf(fid, "| Rejected nonpositive dt pairs | %d |\n", buildSummary.rejectedPairCounts.nonPositiveDt);
    fprintf(fid, "| Rejected dt > max pairs | %d |\n\n", buildSummary.rejectedPairCounts.aboveMaxDt);

    fprintf(fid, "## dt Statistics\n\n");
    fprintf(fid, "| Statistic | dt [s] |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Count | %d |\n", buildSummary.dtSummary.count);
    fprintf(fid, "| Min | %.3f |\n", buildSummary.dtSummary.min);
    fprintf(fid, "| P25 | %.3f |\n", buildSummary.dtSummary.p25);
    fprintf(fid, "| Median | %.3f |\n", buildSummary.dtSummary.median);
    fprintf(fid, "| P75 | %.3f |\n", buildSummary.dtSummary.p75);
    fprintf(fid, "| Max | %.3f |\n\n", buildSummary.dtSummary.max);

    fprintf(fid, "## Split Summary\n\n");
    helperWriteTable(fid, dataset.splitManifest.countsBySplit);
    fprintf(fid, "\n");
    fprintf(fid, "- Split policy: `%s`.\n", dataset.splitManifest.policy);
    fprintf(fid, "- Split seed: %.0f.\n", dataset.splitManifest.splitSeed);
    fprintf(fid, "- Leakage check passed: %d.\n", dataset.splitManifest.leakageCheckPassed);
    fprintf(fid, "- Aircraft split check passed: %d.\n\n", dataset.splitManifest.aircraftSplitCheckPassed);

    fprintf(fid, "## Baseline Constvel Metrics\n\n");
    baseline = dataset.baselineConstVelMetrics;
    fprintf(fid, "| Metric | Value |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Samples | %d |\n", baseline.sampleCount);
    fprintf(fid, "| Position RMSE [m] | %.3f |\n", baseline.positionRMSEMeters);
    fprintf(fid, "| Velocity RMSE [m/s] | %.3f |\n", baseline.velocityRMSEMetersPerSecond);
    fprintf(fid, "| Position median error [m] | %.3f |\n", baseline.positionMedianErrorMeters);
    fprintf(fid, "| Velocity median error [m/s] | %.3f |\n", baseline.velocityMedianErrorMetersPerSecond);
    fprintf(fid, "| Position P95 error [m] | %.3f |\n", baseline.positionP95ErrorMeters);
    fprintf(fid, "| Velocity P95 error [m/s] | %.3f |\n\n", baseline.velocityP95ErrorMetersPerSecond);

    fprintf(fid, "## Smoke Training Status\n\n");

    if isempty(trainingSummary)
        fprintf(fid, "MLP smoke training has not been run for this report yet.\n");
    else
        fprintf(fid, "| Metric | Value |\n");
        fprintf(fid, "| :--- | ---: |\n");
        fprintf(fid, "| Epochs | %d |\n", trainingSummary.numEpochs);
        fprintf(fid, "| Final loss | %.6f |\n", trainingSummary.finalLoss);
        fprintf(fid, "| Finite loss | %d |\n", trainingSummary.finiteLoss);
        fprintf(fid, "| Output rows | %d |\n", trainingSummary.outputSize(1));
        fprintf(fid, "| Output columns | %d |\n", trainingSummary.outputSize(2));
        fprintf(fid, "| Strictly positive predicted variances | %d |\n", trainingSummary.positivePredictedVariances);
        fprintf(fid, "| Minimum predicted variance | %.6g |\n", trainingSummary.minimumPredictedVariance);
        fprintf(fid, "| Model position RMSE [m] | %.3f |\n", trainingSummary.modelPositionRMSEMeters);
        fprintf(fid, "| Model velocity RMSE [m/s] | %.3f |\n", trainingSummary.modelVelocityRMSEMetersPerSecond);
        fprintf(fid, "| Empirical 1-sigma coverage | %.3f |\n", trainingSummary.empiricalOneSigmaCoverage);
        fprintf(fid, "| Empirical 2-sigma coverage | %.3f |\n\n", trainingSummary.empiricalTwoSigmaCoverage);
    end

    fprintf(fid, "## Artifacts\n\n");
    fprintf(fid, "- Dataset MAT: `%s`\n", buildSummary.outputPath);

    if ~isempty(trainingSummary)
        fprintf(fid, "- Training MAT: `%s`\n", trainingSummary.outputPath);
    end
catch err
    error("Stage2B:ReportWriteFailed", ...
        "Failed to write Stage 2B report: %s", err.message);
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
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        valueText = string(value);
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
