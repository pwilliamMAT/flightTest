function helperWriteStage4BPostCampaignReport(reportPath, comparison)
%HELPERWRITESTAGE4BPOSTCAMPAIGNREPORT Write the robustness-readiness decision.

reportPath = string(reportPath);
reportFolder = fileparts(reportPath);

if strlength(reportFolder) > 0 && ~isfolder(reportFolder)
    mkdir(reportFolder);
end

fid = fopen(reportPath, "w");

if fid < 0
    error("Stage4BPost:ReportOpenFailed", ...
        "Unable to open comparison report: %s", reportPath);
end

cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# Stage 4B-Post ADS-B Motion-Diversity Gate\n\n");
fprintf(fid, "Generated: %s UTC\n\n", ...
    string(comparison.generatedAt, "yyyy-MM-dd HH:mm:ss"));
fprintf(fid, "## Decision\n\n");
fprintf(fid, "- Local gated retraining readiness: **%s**\n", ...
    localPassFail(comparison.localRetrainingReady));
fprintf(fid, "- Broad generalization readiness: **%s**\n", ...
    localPassFail(comparison.broadGeneralizationReady));
fprintf(fid, "- Neural retraining performed in this gate: **no**\n\n");

if comparison.localRetrainingReady
    fprintf(fid, "Expanded-3Day meets the approved evidence thresholds for a separately authorized local-receiver retraining experiment. This does not establish that a learned predictor will outperform `constvel`.\n\n");
else
    failedGates = comparison.readinessGateTable.gate( ...
        ~comparison.readinessGateTable.passed);
    fprintf(fid, "Expanded-3Day does not yet meet every threshold for a local-receiver retraining experiment. Failed gates: %s.\n\n", ...
        strjoin(failedGates, ", "));
end

fprintf(fid, "%s\n\n", comparison.broadGeneralizationReason);
fprintf(fid, "## Named Dataset Difference\n\n");
fprintf(fid, "`Expanded-3Day = Legacy-16 + 3-Day Campaign Increment`\n\n");
fprintf(fid, "The named difference **Expanded-3Day minus Legacy-16** adds %d pairs, %d aircraft, %d session/aircraft tracks, %d independent events, and %d occupied joint-regime cells.\n\n", ...
    comparison.differenceSummary.pairCount, ...
    comparison.differenceSummary.aircraftCount, ...
    comparison.differenceSummary.aircraftTrackCount, ...
    comparison.differenceSummary.eventCount, ...
    comparison.differenceSummary.occupiedJointRegimeCellCount);

fprintf(fid, "## Variant Summary\n\n");
fprintf(fid, "| Variant | Truth files | Usable files | Sessions | ICAO | Tracks | Pairs | Events | Occupied joint cells | constvel RMSE [m] | Frozen MLP RMSE [m] |\n");
fprintf(fid, "| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n");

for rowIdx = 1:height(comparison.variantSummaryTable)
    row = comparison.variantSummaryTable(rowIdx, :);
    fprintf(fid, "| %s | %d | %d | %d | %d | %d | %d | %d | %d | %.3f | %.3f |\n", ...
        row.displayName, ...
        row.sourceFileCount, ...
        row.usableSourceFileCount, ...
        row.sessionCount, ...
        row.aircraftCount, ...
        row.aircraftTrackCount, ...
        row.pairCount, ...
        row.eventCount, ...
        row.occupiedJointRegimeCellCount, ...
        row.constvelPositionRMSEMeters, ...
        row.frozenMLPPositionRMSEMeters);
end

fprintf(fid, "\n## Local Retraining Gates\n\n");
fprintf(fid, "| Gate | Observed | Required | Result |\n");
fprintf(fid, "| :--- | :--- | :--- | :---: |\n");

for rowIdx = 1:height(comparison.readinessGateTable)
    row = comparison.readinessGateTable(rowIdx, :);
    fprintf(fid, "| %s | %s | %s | %s |\n", ...
        row.gate, ...
        row.observed, ...
        row.required, ...
        localPassFail(row.passed));
end

fprintf(fid, "\n## Independent Event Coverage\n\n");
fprintf(fid, "| Variant | Event | Count | ICAO | Tracks | Sessions | Campaign days | Largest ICAO [%%] | Largest campaign day [%%] |\n");
fprintf(fid, "| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n");

for rowIdx = 1:height(comparison.eventComparison)
    row = comparison.eventComparison(rowIdx, :);
    fprintf(fid, "| %s | %s | %d | %d | %d | %d | %d | %.1f | %.1f |\n", ...
        row.displayName, ...
        replace(row.eventType, "_", " "), ...
        row.eventCount, ...
        row.aircraftCount, ...
        row.trackCount, ...
        row.sessionCount, ...
        row.campaignBlockCount, ...
        row.largestAircraftSharePercent, ...
        row.largestCampaignBlockSharePercent);
end

fprintf(fid, "\n### Expanded-3Day minus Legacy-16\n\n");
fprintf(fid, "| Event | Added events | Added duration [s] |\n");
fprintf(fid, "| :--- | ---: | ---: |\n");

for rowIdx = 1:height(comparison.eventDifferenceTable)
    row = comparison.eventDifferenceTable(rowIdx, :);
    fprintf(fid, "| %s | %d | %.1f |\n", ...
        replace(row.eventType, "_", " "), ...
        row.eventCount, ...
        row.totalDurationSeconds);
end

fprintf(fid, "\n## Reproducibility\n\n");
fprintf(fid, "Dataset membership is frozen in `adsb_archive/datasetVersions/adsbDatasetVariants.csv`; each source path is verified against its SHA-256 digest before evaluation. Variant artifacts remain separate from historical `artifacts/stage3C/`.\n\n");
fprintf(fid, "```matlab\n");
fprintf(fid, 'legacy = runADSBDatasetVariantEvaluation("legacy_pre3day_v1");\n');
fprintf(fid, 'increment = runADSBDatasetVariantEvaluation("campaign_3day_increment_v1");\n');
fprintf(fid, 'expanded = runADSBDatasetVariantEvaluation("expanded_post3day_v2");\n');
fprintf(fid, "comparison = runStage4BPostCampaignMotionDiversityGate;\n");
fprintf(fid, "```\n\n");
fprintf(fid, "Detailed CSV tables and six figures are stored beside this report. The refreshed Stage 4A outputs explicitly load the Expanded-3Day artifact.\n");

end

function text = localPassFail(passed)
%LOCALPASSFAIL Return a compact report label.

if passed
    text = "PASS";
else
    text = "FAIL";
end

end
