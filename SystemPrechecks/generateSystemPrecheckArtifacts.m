clear
clc
close all

projectRoot = fileparts(mfilename("fullpath"));
tablesDir = fullfile(projectRoot, "Artifacts", "Tables");
figuresDir = fullfile(projectRoot, "Artifacts", "Figures");
decksDir = fullfile(projectRoot, "Artifacts", "Decks");

ensureFolder(tablesDir);
ensureFolder(figuresDir);
ensureFolder(decksDir);

[assumptionTable, stationSummary] = helperBuildSystemPrecheckAssumptions();
decisionMatrix = helperBuildLinkBudgetDecisionMatrix();

writetable(assumptionTable, fullfile(tablesDir, "SystemPrecheckAssumptions.csv"));
writetable(stationSummary, fullfile(tablesDir, "SystemPrecheckAssumptionsSummary.csv"));
writetable(decisionMatrix, fullfile(tablesDir, "LinkBudgetDecisionMatrix.csv"));

helperWriteMarkdownTable(assumptionTable, ...
    fullfile(tablesDir, "SystemPrecheckAssumptions.md"), ...
    "# System Precheck Assumptions Table");
helperWriteMarkdownTable(decisionMatrix, ...
    fullfile(tablesDir, "LinkBudgetDecisionMatrix.md"), ...
    "# Link Budget Decision Matrix");

wgs84 = wgs84Ellipsoid("meter");
lightSpeed = physconst("LightSpeed");
stationCount = height(stationSummary);

distance_km = zeros(stationCount, 1);
freeSpacePathLoss_dB = zeros(stationCount, 1);
eirp_dBm = zeros(stationCount, 1);
directPathPowerAfterAntenna_dBm = zeros(stationCount, 1);

for stationIndex = 1:stationCount
    centerFrequencyHz = stationSummary.CenterFrequency_MHz(stationIndex) * 1e6;
    wavelength = lightSpeed / centerFrequencyHz;
    distance_m = distance( ...
        stationSummary.TowerLatitude_deg(stationIndex), ...
        stationSummary.TowerLongitude_deg(stationIndex), ...
        stationSummary.ReceiverLatitude_deg(stationIndex), ...
        stationSummary.ReceiverLongitude_deg(stationIndex), ...
        wgs84);

    distance_km(stationIndex) = distance_m / 1e3;
    freeSpacePathLoss_dB(stationIndex) = fspl(distance_m, wavelength);
    eirp_dBm(stationIndex) = 10 * log10(stationSummary.ERPHorizontal_kW(stationIndex) * 1e6) + 2.15;
    directPathPowerAfterAntenna_dBm(stationIndex) = ...
        eirp_dBm(stationIndex) + stationSummary.ReceiverAntennaGain_dBi(stationIndex) - freeSpacePathLoss_dB(stationIndex);
end

sourceLinkTable = table;
sourceLinkTable.Path = stationSummary.Path;
sourceLinkTable.CallSign = stationSummary.CallSign;
sourceLinkTable.CurrentOperationalStatus = stationSummary.CurrentOperationalStatus;
sourceLinkTable.Distance_km = distance_km;
sourceLinkTable.ERPHorizontal_kW = stationSummary.ERPHorizontal_kW;
sourceLinkTable.EIRP_dBm = eirp_dBm;
sourceLinkTable.FreeSpacePathLoss_dB = freeSpacePathLoss_dB;
sourceLinkTable.DirectPathPowerAfterAntenna_dBm = directPathPowerAfterAntenna_dBm;

writetable(sourceLinkTable, fullfile(tablesDir, "SourceViabilitySummary.csv"));
helperWriteMarkdownTable(sourceLinkTable, ...
    fullfile(tablesDir, "SourceViabilitySummary.md"), ...
    "# Source Viability Summary");

rfResults = cell(stationCount, 1);

for stationIndex = 1:stationCount
    stationStruct = table2struct(stationSummary(stationIndex, :));
    rfResults{stationIndex} = helperBuildRfBudgetCase( ...
        stationStruct, ...
        directPathPowerAfterAntenna_dBm(stationIndex));
end

rfResults = vertcat(rfResults{:});

rfSummaryTable = table;
rfSummaryTable.Path = string({rfResults.Path}).';
rfSummaryTable.CenterFrequency_MHz = [rfResults.CenterFrequency_MHz].';
rfSummaryTable.FilterLoss_dB = [rfResults.FilterLoss_dB].';
rfSummaryTable.CableLoss_dB = [rfResults.CableLoss_dB].';
rfSummaryTable.TargetInputAfterAntenna_dBm = [rfResults.TargetInputAfterAntenna_dBm].';
rfSummaryTable.DirectInputAfterAntenna_dBm = [rfResults.DirectInputAfterAntenna_dBm].';
rfSummaryTable.TargetOutputPower_dBm = [rfResults.TargetOutputPower_dBm].';
rfSummaryTable.DirectOutputPower_dBm = [rfResults.DirectOutputPower_dBm].';
rfSummaryTable.TargetPreProcessingSNR_dB = [rfResults.TargetPreProcessingSNR_dB].';
rfSummaryTable.TargetPostProcessing1sSNR_dB = [rfResults.TargetPostProcessing1sSNR_dB].';
rfSummaryTable.SystemNF_dB = [rfResults.SystemNF_dB].';
rfSummaryTable.TotalGain_dB = [rfResults.TotalGain_dB].';
rfSummaryTable.HeadroomToRecommendedInput_dB = [rfResults.HeadroomToRecommendedInput_dB].';
rfSummaryTable.RecommendedReferenceAttenuation_dB = [rfResults.RecommendedReferenceAttenuation_dB].';

writetable(rfSummaryTable, fullfile(tablesDir, "RFBudgetSummary.csv"));
helperWriteMarkdownTable(rfSummaryTable, ...
    fullfile(tablesDir, "RFBudgetSummary.md"), ...
    "# RF Budget Summary");

integrationTimes_s = [0.1; 0.5; 1.0; 2.0];
detectabilityRows = strings(stationCount * numel(integrationTimes_s), 4);
detectabilityRowIndex = 1;

for stationIndex = 1:stationCount
    signalBandwidthHz = stationSummary.SignalBandwidth_MHz(stationIndex) * 1e6;
    for timeIndex = 1:numel(integrationTimes_s)
        integrationGain_dB = 10 * log10(integrationTimes_s(timeIndex) * signalBandwidthHz);
        postProcessingSNR_dB = rfResults(stationIndex).TargetPreProcessingSNR_dB + integrationGain_dB;
        detectabilityRows(detectabilityRowIndex, :) = string({ ...
            stationSummary.Path(stationIndex), ...
            num2str(integrationTimes_s(timeIndex), "%.1f"), ...
            num2str(postProcessingSNR_dB, "%.2f"), ...
            string(postProcessingSNR_dB > 13)});
        detectabilityRowIndex = detectabilityRowIndex + 1;
    end
end

detectabilityTable = array2table(detectabilityRows, ...
    "VariableNames", ...
    ["Path", "IntegrationTime_s", "PostProcessingSNR_dB", "Above13dBThreshold"]);
writetable(detectabilityTable, fullfile(tablesDir, "DetectabilitySummary.csv"));
helperWriteMarkdownTable(detectabilityTable, ...
    fullfile(tablesDir, "DetectabilitySummary.md"), ...
    "# Detectability Summary");

riskTable = helperBuildRFRiskTable(stationSummary, sourceLinkTable, rfSummaryTable);
writetable(riskTable, fullfile(tablesDir, "RFRiskTable.csv"));
helperWriteMarkdownTable(riskTable, ...
    fullfile(tablesDir, "RFRiskTable.md"), ...
    "# RF Risk Table");

sourceFigurePath = fullfile(figuresDir, "SystemPrecheck_SourceViability.png");
captureFigurePath = fullfile(figuresDir, "SystemPrecheck_RFCaptureChain.png");
detectabilityFigurePath = fullfile(figuresDir, "SystemPrecheck_DetectabilityPlausibility.png");
assumptionsFigurePath = fullfile(figuresDir, "SystemPrecheck_AssumptionsSummary.png");
decisionFigurePath = fullfile(figuresDir, "SystemPrecheck_DecisionMatrixSummary.png");
riskFigurePath = fullfile(figuresDir, "SystemPrecheck_RFRiskSummary.png");
boundariesFigurePath = fullfile(figuresDir, "SystemPrecheck_Boundaries.png");

createSourceFigure(sourceLinkTable, sourceFigurePath);
createCaptureFigure(rfSummaryTable, captureFigurePath);
createDetectabilityFigure(stationSummary, rfResults, integrationTimes_s, detectabilityFigurePath);

assumptionLines = [ ...
    "Path     | Source                          | RF [MHz] | ERP H/V [kW] | Status"; ...
    "---------+---------------------------------+----------+---------------+----------"; ...
    "Newton   | WHDH/WLVI shared RF35 source   | 596-602  | 1000 / 316    | Licensed"; ...
    "Hudson   | WUNI alternate RF27 source     | 548-554  | 400 / 100     | Licensed"; ...
    "Receiver | MathWorks Apple Hill Garage    | Assumed common receiver location"; ...
    "Note     | Newton target-path power reuses the Hudson-derived placeholder until the link budget is rerun."];
helperExportTextFigure("System Precheck Assumptions Summary", assumptionLines, assumptionsFigurePath);

decisionLines = [ ...
    "Active output path: generated tables, figures, write-up, and PPTX from generateSystemPrecheckArtifacts.m"; ...
    "Supporting: FlightTest_Bistatic_RadarAndCommsAnalysis.mlx"; ...
    "  Reason not final evidence: placeholder ERP values, interactive ROI, and no assumptions-table freeze inside the live script."; ...
    "Supporting: FlightTest_BistaticFlightPath_RadarAndCommsAnalysis.mlx"; ...
    "  Reason not final evidence: interactive polyline plus inherited live-script assumptions."; ...
    "Supporting inputs retained in-place: FM_stationList.mat, Radio_Tower_List.txt, PartsList.xlsx."; ...
    "Archived: RadarAndCommsAnalysis.mlx, OldCode/*.mlx, LinkBudgetProgress.pptx, *.asv."; ...
    "Reference moved to Archive/ReferenceExamples: AppleHill example, applehill.osm, FinalRDGScript.m, helperOptimizeRadarSites.m, terrain example MAT-file."; ...
    "Reference helpers retained in-place: helperPathlossOverTerrain.m, helperRadarCoverageTargetGrid.m, helperGroundAltitude.m."];
helperExportTextFigure("Link Budget Decision Summary", decisionLines, decisionFigurePath);

riskLines = [
    "Topic                       | Summary";
    "---------------------------+--------------------------------------------------------------";
    "Direct path                | Reference-channel attenuation is required for both paths.";
    "Target path                | Hudson value is reused; Newton still needs its own rerun.";
    "Noise figure               | Current model closes near 4 dB system NF.";
    "Gain allocation            | Capture-chain gain is adequate but should be retuned in bench testing.";
    "Headroom                   | Direct path exceeds the recommended TwinRX input window without attenuation.";
    "Selectivity                | S2P loss is acceptable, but adjacent-channel rejection is unverified.";
    "IF rationale               | Active path is direct sampling; legacy IF scripts are not final evidence.";
    "Interference               | No field spectrum survey is present in the repo."];
helperExportTextFigure("RF Risk Summary", riskLines, riskFigurePath);

boundaryLines = [ ...
    "This package is a system precheck, not end-to-end passive-radar validation."; ...
    "It does not claim measured field detectability."; ...
    "It does not claim closed-loop synchronization, calibration, or DSI cancellation performance."; ...
    "It does not claim Newton-specific target-path propagation has been independently rerun."; ...
    "It does not claim adjacent-channel robustness without a field spectrum survey."; ...
    "It does claim illuminator viability, RF front-end capturability, and detectability plausibility within these stated bounds."];
helperExportTextFigure("What This Analysis Does Not Claim", boundaryLines, boundariesFigurePath);

slideSpecs = struct( ...
    "Title", { ...
        "Operational Context and Assumptions", ...
        "Illuminator Viability", ...
        "RF Front-End Capturability", ...
        "Bistatic Detectability Plausibility", ...
        "Link Budget Triage Summary", ...
        "RF Risk Summary", ...
        "Boundaries and Excluded Effects"}, ...
    "ImagePath", { ...
        assumptionsFigurePath, ...
        sourceFigurePath, ...
        captureFigurePath, ...
        detectabilityFigurePath, ...
        decisionFigurePath, ...
        riskFigurePath, ...
        boundariesFigurePath});

helperGenerateSystemPrecheckDeck( ...
    fullfile(decksDir, "SystemPrecheck_TechnicalStory.pptx"), ...
    slideSpecs);

fprintf("Generated tables in %s\n", tablesDir);
fprintf("Generated figures in %s\n", figuresDir);
fprintf("Generated deck in %s\n", decksDir);

function ensureFolder(folderPath)
if ~isfolder(folderPath)
    mkdir(folderPath);
end
end

function createSourceFigure(sourceLinkTable, outputPath)
figureHandle = figure( ...
    "Visible", "off", ...
    "Color", "w", ...
    "Position", [100 100 1400 700]);
tiledlayout(1, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile
bar(categorical(sourceLinkTable.Path), sourceLinkTable.DirectPathPowerAfterAntenna_dBm);
hold on
yline(-25, "--", "Preferred low edge", "LineWidth", 1.25);
yline(-15, "--", "Recommended max input", "LineWidth", 1.25);
hold off
grid on
xlabel("Source path");
ylabel("Estimated direct-path power after antenna [dBm]");
title("Direct-path illuminator viability");

nexttile
yyaxis left
bar(categorical(sourceLinkTable.Path), sourceLinkTable.Distance_km);
ylabel("Range to receiver [km]");
yyaxis right
plot(categorical(sourceLinkTable.Path), sourceLinkTable.ERPHorizontal_kW, "o-", "LineWidth", 2);
ylabel("Horizontal ERP [kW]");
grid on
xlabel("Source path");
title("Geometry and transmitter context");

sgtitle("System Precheck Source Viability");
exportgraphics(figureHandle, outputPath, "Resolution", 300);
close(figureHandle);
end

function createCaptureFigure(rfSummaryTable, outputPath)
figureHandle = figure( ...
    "Visible", "off", ...
    "Color", "w", ...
    "Position", [100 100 1400 900]);
tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile
bar(categorical(rfSummaryTable.Path), rfSummaryTable.TargetOutputPower_dBm);
hold on
yline(-25, "--", "Preferred low edge", "LineWidth", 1.25);
yline(-15, "--", "Recommended max input", "LineWidth", 1.25);
hold off
grid on
xlabel("Source path");
ylabel("Target-path output at TwinRX input [dBm]");
title("Target-path capturability");

nexttile
bar(categorical(rfSummaryTable.Path), rfSummaryTable.DirectOutputPower_dBm);
hold on
yline(-15, "--", "Recommended max input", "LineWidth", 1.25);
hold off
grid on
xlabel("Source path");
ylabel("Direct-path output at TwinRX input [dBm]");
title("Reference-path overload risk");

nexttile
bar(categorical(rfSummaryTable.Path), [rfSummaryTable.SystemNF_dB rfSummaryTable.TotalGain_dB], "grouped");
grid on
xlabel("Source path");
ylabel("Cascade metric [dB]");
title("Noise figure and total gain");
legend("System NF", "Total gain", "Location", "northwest");

nexttile
bar(categorical(rfSummaryTable.Path), rfSummaryTable.RecommendedReferenceAttenuation_dB);
grid on
xlabel("Source path");
ylabel("Recommended reference attenuation [dB]");
title("Suggested reference-path attenuation");

sgtitle("RF Front-End Capturability");
exportgraphics(figureHandle, outputPath, "Resolution", 300);
close(figureHandle);
end

function createDetectabilityFigure(stationSummary, rfResults, integrationTimes_s, outputPath)
figureHandle = figure( ...
    "Visible", "off", ...
    "Color", "w", ...
    "Position", [100 100 1400 700]);
tiledlayout(1, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile
hold on

for stationIndex = 1:numel(rfResults)
    signalBandwidthHz = stationSummary.SignalBandwidth_MHz(stationIndex) * 1e6;
    integrationGain_dB = 10 * log10(integrationTimes_s * signalBandwidthHz);
    postProcessingSNR_dB = rfResults(stationIndex).TargetPreProcessingSNR_dB + integrationGain_dB;
    plot( ...
        integrationTimes_s, ...
        postProcessingSNR_dB, ...
        "LineWidth", 2, ...
        "DisplayName", stationSummary.Path(stationIndex));
end

yline(13, "--", "Illustrative detection threshold", "LineWidth", 1.25);
hold off
grid on
xlabel("Integration time [s]");
ylabel("Post-processing SNR [dB]");
title("Detectability plausibility versus integration time");
legend("Location", "southeast");

nexttile
pathNames = categorical(string({rfResults.Path}));
bar(pathNames, [[rfResults.TargetPreProcessingSNR_dB].' [rfResults.TargetPostProcessing1sSNR_dB].'], "grouped");
hold on
yline(13, "--", "Illustrative detection threshold", "LineWidth", 1.25);
hold off
grid on
xlabel("Source path");
ylabel("SNR [dB]");
title("Pre-processing and 1 s post-processing SNR");
legend("Pre-processing", "1 s post-processing", "Location", "northwest");

sgtitle("Bistatic Detectability Plausibility (Newton target path still uses a carried placeholder)");
exportgraphics(figureHandle, outputPath, "Resolution", 300);
close(figureHandle);
end
