%[text] # Stage 4E: Recursive Filter Evaluation
%[text] Stage 4E asks how complete filters behave when predictions are carried forward, position reports correct the estimate, and missing reports force the filter to coast.
%[text:tableOfContents]{"heading":"Table of Contents"}
%#ok<*NOPTS>
stage4EScriptPath = string(which("stage4ERecursiveFilterEvaluationLiveScript"));
stage4EProjectRoot = string(fileparts(stage4EScriptPath));
addpath(stage4EProjectRoot);
if ~exist("stage4EBenchmarkMode", "var")
    stage4EBenchmarkMode = "full";
end
if ~exist("regenerateStage4EResults", "var")
    regenerateStage4EResults = false;
end
if ~exist("retuneStage4EFilters", "var")
    retuneStage4EFilters = false;
end
if ~exist("stage4ERandomSeed", "var")
    stage4ERandomSeed = 123;
end
if ~exist("generateStage4EPlots", "var")
    generateStage4EPlots = true;
end
if ~exist("enableStage4EInteractiveGlobe", "var")
    enableStage4EInteractiveGlobe = true;
end
if ~exist("stage4EOutputFolder", "var")
    stage4EOutputFolder = fullfile(stage4EProjectRoot, "artifacts", "stage4ERecursiveFilterEvaluation");
end
stage4EResultsPath = fullfile(stage4EOutputFolder, "stage4ERecursiveFilterEvaluationResults.mat");
%%
%[text] ## 1. Load Or Recompute The Benchmark
%[text] Run All loads the frozen full result by default. Set |regenerateStage4EResults = true| to recompute; set |retuneStage4EFilters = true| only when intentionally replacing the validation-only tuning artifact.
if regenerateStage4EResults || exist(stage4EResultsPath, "file") ~= 2
    stage4EResults = runStage4ERecursiveFilterEvaluation( ...
        BenchmarkMode=stage4EBenchmarkMode, ...
        Seed=stage4ERandomSeed, ...
        OutputFolder=stage4EOutputFolder, ...
        ResultsPath=stage4EResultsPath, ...
        RetuneFilters=retuneStage4EFilters, ...
        CreatePlots=false, ...
        Verbose=true);
    stage4ERunStatus = "Recomputed " + stage4EBenchmarkMode + " results";
else
    loadedStage4EResults = load(stage4EResultsPath, "stage4EResults");
    stage4EResults = loadedStage4EResults.stage4EResults;
    stage4ERunStatus = "Loaded saved " + stage4EResults.benchmarkMode + " results";
end
stage4EStatusSentence = stage4ERunStatus + ". " + stage4EResults.interpretation;
disp(stage4EStatusSentence)
%%
%[text] ## 2. What Recursive Filtering Adds
%[text] A transition model predicts the next state and covariance. A position report then corrects that prior estimate. If a report is absent, the posterior equals the prior and uncertainty grows while the filter coasts.
%[text] Every estimator starts from the same first ADS-B position and velocity report. Later updates contain position only, through the native |cvmeas|, |cameas|, and |ctmeas| measurement models.
stage4EConfiguration = stage4EResults.config;
stage4EProtocol = stage4EResults.realProtocol;
stage4EConfigurationSentence = compose( ...
    "%s mode evaluated %d synthetic sequences and %d held-out ADS-B events under %d update profiles.", ...
    stage4EResults.benchmarkMode, ...
    stage4EResults.syntheticSummary.sequenceCount, ...
    stage4EProtocol.eventCount, ...
    numel(stage4EProtocol.profileNames));
disp(stage4EConfigurationSentence)
%%
%[text] ## 3. Five Estimators, One Input Contract
%[text] Three |trackingEKF| estimators use constant-velocity, constant-acceleration, and constant-turn dynamics. A native |trackingIMM| combines those models. A |trackingUKF| uses the frozen warm network only as its state-transition function.
%[text] The network receives its fixed training covariance diagonal as an input feature. The UKF—not the network—propagates recursive covariance from sigma points and process noise.
stage4ENativeFunctionAudit = stage4EResults.nativeFunctionAudit;
stage4EInputAudit = stage4EResults.inputAuditTable;
stage4EInputSentence = compose( ...
    "%d matched filter runs used identical timestamps, measurements, scoring rows, and physical initialization.", ...
    height(stage4EInputAudit));
disp(stage4EInputSentence)
%%
%[text] ## 4. Validation-Only Tuning Is Frozen Before Test Scoring
%[text] |trackingFilterTuner| adjusts process-noise properties and IMM transition behavior on validation events only. The neural network is never retrained.
stage4ETuningSummary = stage4EResults.tuningSummary;
stage4ETuningCosts = stage4ETuningSummary.costTable;
stage4ETuningSentence = compose( ...
    "%d validation events supplied at most %d pairs each; all five tuned costs are finite: %s.", ...
    stage4ETuningSummary.validationSummary.eventCount, ...
    stage4ETuningSummary.validationSummary.maximumPairsPerEvent, ...
    string(all(isfinite(stage4ETuningCosts.validationCost))));
disp(stage4ETuningSentence)
%%
%[text] ## 5. Synthetic Truth Separates Motion And Outage Effects
%[text] Synthetic filters run on the full latent 2 Hz grid. They correct only where each profile supplies an observation, so prior and posterior errors, NEES, coverage, and outage age are evaluated against independent kinematic truth.
stage4EMetrics = stage4EResults.metricTable;
stage4EMotionMetrics = stage4EResults.motionMetricTable;
stage4EOutageMetrics = stage4EResults.outageAgeMetricTable;
stage4ESyntheticRows = stage4EMetrics( ...
    stage4EMetrics.domain == "synthetic_canonical" & ...
    stage4EMetrics.profile == "degraded" & ...
    stage4EMetrics.estimateStage == "posterior", :);
[stage4EBestSyntheticRMSE, stage4EBestSyntheticIndex] = min(stage4ESyntheticRows.positionRMSEMeters);
stage4ESyntheticSentence = compose( ...
    "On degraded canonical truth, %s has the lowest aggregate posterior position RMSE at %.2f m.", ...
    stage4ESyntheticRows.modelID(stage4EBestSyntheticIndex), ...
    stage4EBestSyntheticRMSE);
disp(stage4ESyntheticSentence)
%%
%[text] ## 6. Held-Out ADS-B Is A Scoring Proxy
%[text] For each test event, every fifth report beginning with the third is reserved for scoring before dropout is applied. Those reports never correct any filter. Baseline, 10%, 25%, and burst dropout affect only the remaining update candidates.
stage4ERealRows = stage4EMetrics( ...
    stage4EMetrics.domain == "real_adsb" & ...
    stage4EMetrics.profile == "baseline" & ...
    stage4EMetrics.estimateStage == "posterior", :);
[stage4EBestRealRMSE, stage4EBestRealIndex] = min(stage4ERealRows.positionRMSEMeters);
stage4ERealSentence = compose( ...
    "Against reserved ADS-B reports, %s has the lowest baseline posterior position RMSE at %.2f m; this is proxy performance, not independent truth accuracy.", ...
    stage4ERealRows.modelID(stage4EBestRealIndex), ...
    stage4EBestRealRMSE);
disp(stage4ERealSentence)
%%
%[text] ## 7. Motion, Dropout, Coasting, And Runtime
%[text] The summary keeps four comparisons visible: motion-specific synthetic error, held-out ADS-B dropout response, error versus time since correction, and runtime. Detailed metric, win-rate, consistency, and audit tables remain in the workspace and CSV artifacts.
stage4EEventMetrics = stage4EResults.eventMetricTable;
stage4EEventWinRates = stage4EResults.eventWinRateTable;
stage4EConsistency = stage4EResults.consistencyTable;
stage4ERuntime = stage4EResults.runtimeTable;
if generateStage4EPlots
    stage4ESummaryPlot = helperPlotStage4ERecursiveEvaluation( ...
        stage4EResults, ...
        SavePath=stage4EResults.paths.summaryFigure);
else
    stage4ESummaryPlotStatus = "Summary plotting disabled.";
end
%%
%[text] ## 8. Recursive Integrity And Statistical Consistency
%[text] Finite state, covariance, timing, coasting, correction, NIS, NEES, and coverage checks are evidence about implementation and estimator consistency. They do not turn ADS-B into independent ground truth.
stage4EVerification = stage4EResults.verificationTable;
stage4EArtifactAudit = stage4EResults.artifactAudit;
stage4EIntegritySentence = compose( ...
    "%d of %d recursive integrity checks passed; filter divergences: %d; invalid covariances: %d.", ...
    sum(stage4EVerification.passed), ...
    height(stage4EVerification), ...
    sum(stage4EEventMetrics.divergenceCount), ...
    sum(stage4EEventMetrics.invalidCovarianceCount));
disp(stage4EIntegritySentence)
%%
%[text] ## 9. Representative Globe Paths
%[text] The optional globe views overlay position updates, the reference path, and all five recursively estimated paths for one synthetic motion-transition case and one real burst-outage event.
stage4ESyntheticGlobeReview = helperBuildStage4EGlobeReview( ...
    stage4EResults, ...
    ViewType="synthetic");
stage4ERealGlobeReview = helperBuildStage4EGlobeReview( ...
    stage4EResults, ...
    ViewType="real_adsb");
stage4ESyntheticGlobeSummary = stage4ESyntheticGlobeReview.summaryTable;
stage4ERealGlobeSummary = stage4ERealGlobeReview.summaryTable;
stage4EGlobeLegend = stage4ESyntheticGlobeReview.legendTable;
if enableStage4EInteractiveGlobe
    stage4ESyntheticGlobe = helperOpenStage4EGlobe(stage4ESyntheticGlobeReview);
    stage4ERealGlobe = helperOpenStage4EGlobe(stage4ERealGlobeReview);
else
    stage4ESyntheticGlobeStatus = "Interactive synthetic globe disabled.";
    stage4ERealGlobeStatus = "Interactive real-data globe disabled.";
end
%%
%[text] ## 10. Conclusion And Boundary
%[text] Stage 4E compares recursive estimators under matched position-update schedules. It does not evaluate association, clutter, confirmation, deletion, GNN, JPDA, or passive-radar detections; those require a later benchmark with radar detections and independent ADS-B reference data.
stage4ECompleted = stage4EResults.completed;
stage4EConclusionSentence = compose( ...
    "Stage 4E complete: %s. The learned transition remained frozen, and real-data results remain ADS-B-proxy performance.", ...
    string(stage4ECompleted));
disp(stage4EConclusionSentence)
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
