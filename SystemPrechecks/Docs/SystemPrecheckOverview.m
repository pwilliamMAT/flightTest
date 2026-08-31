%[text] # System Precheck Overview
%[text] This Live Editor walkthrough refreshes the current passive-radar system-precheck evidence and answers the pre-build question: what evidence supports attempting a passive-signal-of-opportunity data-acquisition setup for aircraft localization?
%[text] - regenerate the system-level evidence package
%[text] - inspect the shared geometry, recovered-ROI baseline, and due-west corridor figures
%[text] - review the readable RF front-end figures
%[text] - keep the claims anchored to pre-hardware plausibility and explicit boundaries
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
tablesDir = fullfile(projectRoot, "Artifacts", "Tables");
summariesDir = fullfile(projectRoot, "Artifacts", "Summaries");
figuresDir = fullfile(projectRoot, "Artifacts", "Figures");
%%
%[text] ## System-Level Artifact Refresh
%[text] This section answers: what machine-readable evidence package exists before we argue for a hardware build?
%[text] The artifact generator rebuilds the shared assumptions tables, the recovered-ROI baseline coverage branch, the due-west corridor branch, the readable deck figures, and the technical deck.
helperRunScriptIsolated(fullfile(projectRoot, "generateSystemPrecheckArtifacts.m"))
assumptionsTable = helperReadArtifactTable(fullfile(tablesDir, "SystemPrecheckAssumptionsSummary.csv"));
sourceViabilityTable = helperReadArtifactTable(fullfile(tablesDir, "SourceViabilitySummary.csv"));
baselineTargetPathTable = helperReadArtifactTable(fullfile(tablesDir, "BistaticTargetPathSummary.csv"));
westCorridorTargetPathTable = helperReadArtifactTable(fullfile(tablesDir, "BistaticTargetPathSummary_WestCorridor.csv"));
rfSummaryTable = helperReadArtifactTable(fullfile(tablesDir, "RFBudgetSummary.csv"));
disp(assumptionsTable)
disp(sourceViabilityTable(:, ["Path", "Distance_km", "DirectPathPowerAfterAntenna_dBm", "CurrentOperationalStatus"]))
disp(baselineTargetPathTable(:, ["AnalysisName", "Path", "MeanTargetPathPower_dBm", "MeanBistaticSNR_dB", "TargetCount"]))
disp(westCorridorTargetPathTable(:, ["AnalysisName", "Path", "MeanTargetPathPower_dBm", "MeanBistaticSNR_dB", "TargetCount"]))
disp(helperReadTextSummary(fullfile(summariesDir, "SystemPrecheckAssumptionsSummary.txt")))
%%
%[text] ## Illuminator Geometry and Shared Context
%[text] This section answers: where do Newton, Hudson, the recovered-ROI baseline, and the additive due-west corridor sit relative to the receiver?
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_GeometryOverview.png"), "Shared geometry overview")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_SourceViability.png"), "Source viability")
disp(sourceViabilityTable(:, ["Path", "CallSign", "Distance_km", "ERPHorizontal_kW", "DirectPathPowerAfterAntenna_dBm"]))
%%
%[text] ## Recovered-ROI Baseline Coverage
%[text] This section answers: what deterministic evidence supports the original recovered-ROI baseline rerun?
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_RoiTargetGridContext.png"), "Recovered-ROI baseline setup")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_CombinedDeterministicSNRCoverage.png"), "Recovered-ROI combined deterministic SNR coverage")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_RegionalSNRCoverage.png"), "Recovered-ROI regional SNR view")
disp(baselineTargetPathTable(:, ["AnalysisName", "Path", "MeanTargetPathPower_dBm", "MedianTargetPathPower_dBm", "MinTargetPathPower_dBm", "MaxTargetPathPower_dBm"]))
%%
%[text] ## Due-West Surveillance Corridor Check
%[text] This section answers: what changes if the surveillance antenna check is framed as a due-west corridor that starts at the receiver and extends 0.50 deg west?
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_WestCorridorSetup.png"), "West corridor setup")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_WestCorridor_CombinedSNRCoverage.png"), "West corridor combined deterministic SNR coverage")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_WestCorridor_RegionalSNRCoverage.png"), "West corridor regional SNR view")
disp(westCorridorTargetPathTable(:, ["AnalysisName", "Path", "MeanTargetPathPower_dBm", "MedianTargetPathPower_dBm", "MinTargetPathPower_dBm", "MaxTargetPathPower_dBm"]))
%%
%[text] ## RF Front-End Story
%[text] This section answers: does the cleaned direct-sampling chain stay readable and technically plausible for both paths?
%[text] The Newton, Hudson, and comparative scripts remain useful engineering aids, but the deck still uses the generated shared RF figures as the review-room artifact.
helperRunScriptIsolated(fullfile(projectRoot, "RFBudget", "RFBudget_Newton.m"))
helperRunScriptIsolated(fullfile(projectRoot, "RFBudget", "RFBudget_Hudson.m"))
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_RFChainOverview.png"), "RF chain overview")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_RFLevelsAndHeadroom.png"), "RF levels and headroom")
disp(rfSummaryTable(:, ["Path", "FilterLoss_dB", "TargetOutputPower_dBm", "DirectOutputPower_dBm", "SystemNF_dB", "TotalGain_dB", "RecommendedReferenceAttenuation_dB"]))
disp("Optional native analyzer capture helper: helperOpenSystemPrecheckRfAnalyzer(""Newton"")")
%%
%[text] ## Detectability and Risk Review
%[text] This section answers: do both deterministic branches still support a bounded detectability claim, and what remains explicitly out of scope?
helperRunScriptIsolated(fullfile(projectRoot, "RFBudget", "RFBudget_Comparative_Analysis.m"))
baselineDetectabilityTable = helperReadArtifactTable(fullfile(tablesDir, "DetectabilitySummary.csv"));
westCorridorDetectabilityTable = helperReadArtifactTable(fullfile(tablesDir, "DetectabilitySummary_WestCorridor.csv"));
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_DetectabilityPlausibility.png"), "Recovered-ROI baseline detectability")
helperDisplayArtifactImage(fullfile(figuresDir, "SystemPrecheck_WestCorridor_Detectability.png"), "West corridor detectability")
disp(baselineDetectabilityTable(:, ["AnalysisName", "Path", "IntegrationTime_s", "MeanTargetPathPower_dBm", "PostProcessingSNR_dB"]))
disp(westCorridorDetectabilityTable(:, ["AnalysisName", "Path", "IntegrationTime_s", "MeanTargetPathPower_dBm", "PostProcessingSNR_dB"]))
disp(helperReadTextSummary(fullfile(summariesDir, "SystemPrecheckDecisionSummary.txt")))
disp(helperReadTextSummary(fullfile(summariesDir, "SystemPrecheckRFRiskSummary.txt")))
%%
%[text] ## Review Boundaries
%[text] This section answers: what does this overview support, and what does it intentionally avoid claiming?
disp(helperReadTextSummary(fullfile(summariesDir, "SystemPrecheckBoundaries.txt")))
%%
%[text] ## Takeaway
%[text] The current evidence package now supports two aligned claims: the recovered-ROI baseline remains reproducible, and the additive due-west corridor check shows what the same deterministic workflow predicts for a west-looking surveillance geometry.
%[text] The package still does not close field validation, adjacent-channel robustness, calibration, DSI cancellation, or clutter rejection.
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
