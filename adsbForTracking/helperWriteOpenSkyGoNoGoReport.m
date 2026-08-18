function helperWriteOpenSkyGoNoGoReport(reportPath, summary)
%HELPERWRITEOPENSKYGONOGOREPORT Write the Stage 2A Markdown report.

analysis = summary.analysis;
config = summary.config;

try
    fid = fopen(reportPath, "w");

    if fid < 0
        error("OpenSkyProbe:ReportOpenFailed", "Unable to open report for writing.");
    end

    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, "# Stage 2A OpenSky Go/No-Go Report\n\n");
    fprintf(fid, "Generated: %s UTC\n\n", string(summary.generatedAt, "yyyy-MM-dd HH:mm:ss"));
    fprintf(fid, "Scope: OpenSky current-state go/no-go probe only. No full Stage 2 dataset was built and no neural network was trained.\n\n");

    fprintf(fid, "## Native MATLAB Path Used\n\n");
    fprintf(fid, "- Retrieval: `webread`, `weboptions`, and `jsondecode` for current-state snapshots.\n");
    fprintf(fid, "- HTTP metadata: MATLAB `matlab.net.http.RequestMessage` to capture status, content type, and available rate-limit headers.\n");
    fprintf(fid, "- Organization: `table` and `timetable`.\n");
    fprintf(fid, "- ENU conversion: `wgs84Ellipsoid` and `geodetic2enu`.\n");
    fprintf(fid, "- State order: Sensor Fusion convention `[x; vx; y; vy; z; vz]`.\n\n");

    fprintf(fid, "## Access Result\n\n");
    helperWriteAccessTable(fid, summary.datasetsAccess, summary.stateAccess);
    fprintf(fid, "\n");

    fprintf(fid, "Current-state endpoint:\n\n");
    fprintf(fid, "```text\n%s\n```\n\n", config.stateUrl);

    fprintf(fid, "## Sampling Summary\n\n");
    successfulSnapshots = sum(summary.snapshotSuccess);
    attemptedSnapshots = numel(summary.snapshotSuccess);
    actualDurationSeconds = seconds(summary.probeEndTime - summary.probeStartTime);

    if successfulSnapshots > 1
        successfulTimes = summary.retrievalTimes(summary.snapshotSuccess);
        observedCadenceSeconds = seconds(diff(successfulTimes));
        medianObservedCadenceSeconds = median(observedCadenceSeconds);
    else
        medianObservedCadenceSeconds = NaN;
    end

    fprintf(fid, "| Metric | Value |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Requested duration [s] | %.0f |\n", config.sampleDurationSeconds);
    fprintf(fid, "| Actual elapsed duration [s] | %.1f |\n", actualDurationSeconds);
    fprintf(fid, "| Requested cadence [s] | %.0f |\n", config.sampleCadenceSeconds);
    fprintf(fid, "| Median observed successful cadence [s] | %.2f |\n", medianObservedCadenceSeconds);
    fprintf(fid, "| Snapshots attempted | %d |\n", attemptedSnapshots);
    fprintf(fid, "| Snapshots successful | %d |\n", successfulSnapshots);
    fprintf(fid, "| Raw records parsed | %d |\n", analysis.rawRecords);
    fprintf(fid, "| Retained airborne records | %d |\n", analysis.retainedRecords);
    fprintf(fid, "| Aircraft with repeated valid samples | %d |\n", analysis.repeatedAircraftCount);
    fprintf(fid, "| Aircraft with usable state pairs | %d |\n", analysis.aircraftWithStatePairs);
    fprintf(fid, "| Usable one-step state pairs | %d |\n", analysis.usablePairs);
    fprintf(fid, "| Duplicate timestamps removed | %d |\n\n", analysis.duplicateTimestampRecordsRemoved);

    fprintf(fid, "## Field Completeness\n\n");
    fprintf(fid, "Raw OpenSky state-vector field completeness:\n\n");
    helperWriteTable(fid, analysis.fieldCompleteness);
    fprintf(fid, "\n");
    fprintf(fid, "Retained-record completeness for latitude, longitude, altitude, velocity, and true track: %.1f%%.\n\n", analysis.retainedFieldCompletenessPercent);

    fprintf(fid, "## Altitude And Vertical Rate\n\n");
    fprintf(fid, "Altitude preference was `geoAltitude` first, then `baroAltitude` as fallback.\n\n");
    helperWriteTable(fid, analysis.altitudeSourceCounts);
    fprintf(fid, "\n");
    fprintf(fid, "Vertical velocity used `verticalRate` when available. Finite-difference altitude rate was computed only as a continuity diagnostic and was not used in usable state pairs.\n\n");
    helperWriteTable(fid, analysis.vzSourceCounts);
    fprintf(fid, "\n");

    fprintf(fid, "## ENU And State Construction\n\n");
    fprintf(fid, "- Natick ENU origin: latitude %.4f deg, longitude %.4f deg, altitude %.1f m.\n", config.centerLatDeg, config.centerLonDeg, config.centerAltMeters);
    fprintf(fid, "- Radius filter: %.0f m horizontal range after ENU conversion.\n", config.radiusMeters);
    fprintf(fid, "- Velocity convention: `vx = speed * sind(trueTrack)`, `vy = speed * cosd(trueTrack)` because OpenSky true track is clockwise from north.\n");
    fprintf(fid, "- State column order verified: `%s`.\n", strjoin(config.stateOrder, ", "));
    fprintf(fid, "- MATLAB table creation worked: %d.\n", analysis.tableWorked);
    fprintf(fid, "- MATLAB timetable creation worked: %d.\n", analysis.timetableWorked);
    fprintf(fid, "- ENU conversion worked: %d.\n", analysis.enuWorked);
    fprintf(fid, "- State construction worked: %d.\n\n", analysis.stateConstructionWorked);

    fprintf(fid, "## Provisional Covariance\n\n");
    fprintf(fid, "This covariance is a probe-only placeholder and is not a final training policy.\n\n");
    fprintf(fid, "| State element | Assumed standard deviation | Unit |\n");
    fprintf(fid, "| :--- | ---: | :--- |\n");
    fprintf(fid, "| x | %.1f | m |\n", config.covarianceStd(1));
    fprintf(fid, "| vx | %.1f | m/s |\n", config.covarianceStd(2));
    fprintf(fid, "| y | %.1f | m |\n", config.covarianceStd(3));
    fprintf(fid, "| vy | %.1f | m/s |\n", config.covarianceStd(4));
    fprintf(fid, "| z | %.1f | m |\n", config.covarianceStd(5));
    fprintf(fid, "| vz | %.1f | m/s |\n\n", config.covarianceStd(6));

    fprintf(fid, "## dt Distribution\n\n");
    fprintf(fid, "| Statistic | dt [s] |\n");
    fprintf(fid, "| :--- | ---: |\n");
    fprintf(fid, "| Count | %d |\n", analysis.dtStats.count);
    fprintf(fid, "| Min | %.2f |\n", analysis.dtStats.min);
    fprintf(fid, "| P25 | %.2f |\n", analysis.dtStats.p25);
    fprintf(fid, "| Median | %.2f |\n", analysis.dtStats.median);
    fprintf(fid, "| P75 | %.2f |\n", analysis.dtStats.p75);
    fprintf(fid, "| Max | %.2f |\n\n", analysis.dtStats.max);

    fprintf(fid, "## Go/No-Go Criteria\n\n");
    helperWriteTable(fid, analysis.criteria);
    fprintf(fid, "\n");

    fprintf(fid, "## Risks And Failures\n\n");

    if isempty(analysis.risks)
        fprintf(fid, "- No decisive immediate access, rate-limit, licensing, MATLAB dependency, or ENU/state-construction blocker was observed during this probe.\n");
    else
        for riskIdx = 1:numel(analysis.risks)
            fprintf(fid, "- %s\n", analysis.risks(riskIdx));
        end
    end

    fprintf(fid, "- OpenSky redistribution and historical-access terms still need full review before any shared or long-running Stage 2 dataset work.\n\n");

    fprintf(fid, "## Decision\n\n");

    if analysis.decision == "GO"
        fprintf(fid, "**GO.** Continue Stage 2 with OpenSky as the initial data source while keeping local ADS-B collection as the fallback and validation path.\n");
    else
        fprintf(fid, "**NO-GO.** Make local ADS-B collection the primary Stage 2 data path unless one additional hour can clearly resolve the failed criterion without account setup.\n");
    end
catch err
    error("OpenSkyProbe:ReportWriteFailed", "Failed to write report: %s", err.message);
end

end

function helperWriteAccessTable(fid, datasetsAccess, stateAccess)
%HELPERWRITEACCESSTABLE Write connectivity rows for the two required URLs.

fprintf(fid, "| Target | HTTP status | Content type | Rate-limit headers | Error |\n");
fprintf(fid, "| :--- | ---: | :--- | :--- | :--- |\n");
helperWriteAccessRow(fid, datasetsAccess);
helperWriteAccessRow(fid, stateAccess);

end

function helperWriteAccessRow(fid, access)
%HELPERWRITEACCESSROW Write one connectivity row.

if isempty(access.rateLimitHeaders)
    rateText = "None observed";
else
    rateText = strjoin(access.rateLimitHeaders, "; ");
end

if strlength(access.errorMessage) == 0
    errorText = "";
else
    errorText = access.errorMessage;
end

fprintf(fid, "| %s | %.0f | %s | %s | %s |\n", ...
    access.label, ...
    access.statusCode, ...
    access.contentType, ...
    rateText, ...
    errorText);

end

function helperWriteTable(fid, inputTable)
%HELPERWRITETABLE Write a simple Markdown table for scalar/string/numeric tables.

if height(inputTable) == 0
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
        rowValues(variableIdx) = helperFormatMarkdownValue(value);
    end

    fprintf(fid, "| %s |\n", strjoin(rowValues, " | "));
end

end

function valueText = helperFormatMarkdownValue(value)
%HELPERFORMATMARKDOWNVALUE Format a scalar table cell for Markdown output.

if isstring(value)
    valueText = strjoin(value, ", ");
elseif ischar(value)
    valueText = string(value);
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        if isnumeric(value) && isfinite(value)
            valueText = sprintf("%.2f", value);
        elseif islogical(value)
            valueText = string(value);
        else
            valueText = string(value);
        end
    else
        valueText = string(mat2str(value));
    end
else
    valueText = string(value);
end

valueText = replace(valueText, "|", "\\|");

end
