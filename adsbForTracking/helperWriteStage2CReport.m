function helperWriteStage2CReport(reportPath, characterization)
%HELPERWRITESTAGE2CREPORT Write the Stage 2C maneuver-characterization report.

reportPath = string(reportPath);

try
    reportFolder = fileparts(reportPath);

    if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
        mkdir(reportFolder);
    end

    fid = fopen(reportPath, "w");

    if fid < 0
        error("Stage2C:ReportOpenFailed", "Unable to open report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 2C Maneuver-Aware Characterization Report\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(datetime("now", "TimeZone", "UTC"), "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: existing Stage 2B state-pair artifact only. No new ADS-B data was collected, and no neural model was trained for this stage.\n\n");

    fprintf(fid, "## Direct Answer\n\n");
    fprintf(fid, "%s\n\n", characterization.diversityAssessment.directAnswer);

    fprintf(fid, "## Concept In Plain Language\n\n");
    fprintf(fid, "A constant-velocity predictor should work well when an aircraft keeps the same speed, heading, and vertical rate between two ADS-B updates. Stage 2C checks whether the existing pairs contain enough departures from that behavior to teach or evaluate anything more interesting. It derives heading change from the velocity-vector direction, speed change from horizontal speed magnitude, vertical-rate change from `vz`, climb/descent status from `vz`, and sparse-update status from `dtSeconds`.\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- Heading wrap: Mapping Toolbox `wrapTo180`.\n");
    fprintf(fid, "- Magnitudes: MATLAB `vecnorm`.\n");
    fprintf(fid, "- Grouping and counts: MATLAB `categorical`, `countcats`, `findgroups`, and `splitapply`.\n");
    fprintf(fid, "- Baseline: Sensor Fusion and Tracking Toolbox `constvel` through `helperScoreConstVelBaseline`.\n\n");

    fprintf(fid, "## Input Artifact\n\n");
    fprintf(fid, "| Metric | Value |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Dataset path | `%s` |\n", characterization.stage2BContext.datasetPath);
    fprintf(fid, "| State pairs | %d |\n", characterization.stage2BContext.pairCount);
    fprintf(fid, "| Aircraft tracks | %d |\n", characterization.stage2BContext.aircraftCount);
    fprintf(fid, "| Median dt [s] | %.3f |\n", characterization.stage2BContext.medianDtSeconds);
    fprintf(fid, "| Aggregate constvel position RMSE [m] | %.3f |\n", characterization.stage2BContext.aggregateConstVelPositionRMSEMeters);
    fprintf(fid, "| Aggregate constvel velocity RMSE [m/s] | %.3f |\n\n", characterization.stage2BContext.aggregateConstVelVelocityRMSEMetersPerSecond);

    fprintf(fid, "## Threshold Labels\n\n");
    helperWriteTable(fid, localThresholdTable(characterization.labelSummary.thresholds));
    fprintf(fid, "\n");

    fprintf(fid, "## Maneuver-Class Counts\n\n");
    helperWriteTable(fid, characterization.labelSummary.countsByManeuverClass);
    fprintf(fid, "\n");

    fprintf(fid, "## Climb And Descent Counts\n\n");
    helperWriteTable(fid, characterization.labelSummary.countsByVerticalStatus);
    fprintf(fid, "\n");

    fprintf(fid, "## Sparse-Update Counts\n\n");
    helperWriteTable(fid, characterization.labelSummary.countsByDtRegime);
    fprintf(fid, "\n");

    fprintf(fid, "## Constvel Baseline By Maneuver Class\n\n");
    helperWriteTable(fid, characterization.baselineByManeuverClass);
    fprintf(fid, "\n");

    fprintf(fid, "## Per-Track Summary\n\n");
    fprintf(fid, "The table is sorted by pair count. Counts are pair counts, not raw ADS-B message counts.\n\n");
    helperWriteTable(fid, characterization.trackSummary);
    fprintf(fid, "\n");

    fprintf(fid, "## Diversity Gap\n\n");
    fprintf(fid, "- Constvel-like share: %.1f%%.\n", characterization.diversityAssessment.constvelPercent);
    fprintf(fid, "- Constacc-like share: %.1f%%.\n", characterization.diversityAssessment.constaccPercent);
    fprintf(fid, "- Constturn-like share: %.1f%%.\n", characterization.diversityAssessment.constturnPercent);
    fprintf(fid, "- Mixed or sparse share: %.1f%%.\n", characterization.diversityAssessment.mixedOrSparsePercent);
    fprintf(fid, "- Pairs at or above standard-rate turn threshold, 3 deg/s: %d.\n", characterization.diversityAssessment.standardRateTurnPairCount);
    fprintf(fid, "- Maximum observed absolute turn rate [deg/s]: %.3f.\n", characterization.diversityAssessment.maxAbsTurnRateDegreesPerSecond);
    fprintf(fid, "- This is still a single-session local smoke dataset. It lacks diversity in maneuver regimes, update spacing, traffic mix, route geometry, and collection conditions.\n\n");

    fprintf(fid, "## Artifacts\n\n");
    fprintf(fid, "- Stage 2C MAT: `%s`\n", characterization.artifactPath);
    fprintf(fid, "- Stage 2C figure: `%s`\n", characterization.figurePath);
catch err
    error("Stage2C:ReportWriteFailed", ...
        "Failed to write Stage 2C report: %s", err.message);
end

end

function thresholdTable = localThresholdTable(thresholds)
%LOCALTHRESHOLDTABLE Convert threshold struct to a Markdown-ready table.

thresholdTable = table( ...
    [ ...
        "headingChangeDegrees"; ...
        "turnRateDegreesPerSecond"; ...
        "speedChangeMetersPerSecond"; ...
        "horizontalAccelerationMetersPerSecondSquared"; ...
        "verticalRateChangeMetersPerSecond"; ...
        "verticalAccelerationMetersPerSecondSquared"; ...
        "climbRateMetersPerSecond"; ...
        "sparseUpdateSeconds"; ...
        "minimumHorizontalSpeedMetersPerSecond"], ...
    [ ...
        thresholds.headingChangeDegrees; ...
        thresholds.turnRateDegreesPerSecond; ...
        thresholds.speedChangeMetersPerSecond; ...
        thresholds.horizontalAccelerationMetersPerSecondSquared; ...
        thresholds.verticalRateChangeMetersPerSecond; ...
        thresholds.verticalAccelerationMetersPerSecondSquared; ...
        thresholds.climbRateMetersPerSecond; ...
        thresholds.sparseUpdateSeconds; ...
        thresholds.minimumHorizontalSpeedMetersPerSecond], ...
    'VariableNames', ["threshold", "value"]);

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
