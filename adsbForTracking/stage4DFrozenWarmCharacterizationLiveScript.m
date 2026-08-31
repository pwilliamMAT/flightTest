%[text] # Stage 4D: One-Step Predictor Characterization
%[text] Stage 4D isolates transition-model behavior. Every prediction starts from an observed state; no estimate is fed recursively into the next prediction.
%[text:tableOfContents]{"heading":"Table of Contents"}
%#ok<*NOPTS>
stage4DScriptPath = string(which("stage4DFrozenWarmCharacterizationLiveScript"));
stage4DProjectRoot = string(fileparts(stage4DScriptPath));
addpath(stage4DProjectRoot);
if ~exist("stage4DBenchmarkMode", "var")
    stage4DBenchmarkMode = "full";
end
if ~exist("regenerateStage4DResults", "var")
    regenerateStage4DResults = false;
end
if ~exist("stage4DRandomSeed", "var")
    stage4DRandomSeed = 123;
end
if ~exist("generateStage4DPlots", "var")
    generateStage4DPlots = true;
end
if ~exist("enableStage4DInteractiveGlobe", "var")
    enableStage4DInteractiveGlobe = true;
end
if ~exist("stage4DCanonicalGlobeProfile", "var")
    stage4DCanonicalGlobeProfile = "degraded";
end
if ~exist("stage4DRealGlobeProfile", "var")
    stage4DRealGlobeProfile = "burst_outage";
end
if ~exist("stage4DRealGlobeEventRank", "var")
    stage4DRealGlobeEventRank = 1;
end
if ~exist("stage4DOutputFolder", "var")
    stage4DOutputFolder = fullfile(stage4DProjectRoot, "artifacts", "stage4DFrozenWarmCharacterization");
end
stage4DResultsPath = fullfile(stage4DOutputFolder, "stage4DFrozenWarmCharacterizationResults.mat");
%%
%[text] ## 1. Purpose And Result Source
%[text] The frozen Stage 4C warm network is compared with native motion models under controlled motion, timing, noise, and dropout. The script loads a saved full result by default so review does not silently rerun the benchmark.
if regenerateStage4DResults || exist(stage4DResultsPath, "file") ~= 2
    stage4DResults = runStage4DFrozenWarmCharacterization( ...
        BenchmarkMode=stage4DBenchmarkMode, ...
        Seed=stage4DRandomSeed, ...
        OutputFolder=stage4DOutputFolder, ...
        ResultsPath=stage4DResultsPath, ...
        CreatePlots=false, ...
        Verbose=true);
    stage4DRunStatus = "Regenerated " + stage4DBenchmarkMode + " results";
else
    loadedStage4DResults = load(stage4DResultsPath, "stage4DResults");
    stage4DResults = loadedStage4DResults.stage4DResults;
    stage4DRunStatus = "Loaded saved " + stage4DResults.benchmarkMode + " results";
end
stage4DStatusSentence = stage4DRunStatus + ". " + stage4DResults.interpretation;
disp(stage4DStatusSentence)
%%
%[text] ## 2. What The Degraded Input Looks Like
%[text] This deterministic preview shows only one retained, noisy in-distribution observation sequence. Larger interval stems reveal reports lost to irregular sampling and the 25% dropout profile; no latent truth or model prediction is plotted.
stage4DInputPreview = stage4DResults.inputPreview;
stage4DInputSentence = compose( ...
    "%s contains %d retained observations over %.1f seconds.", ...
    stage4DInputPreview.caseID, ...
    size(stage4DInputPreview.observationState, 1), ...
    stage4DInputPreview.observationTimeSeconds(end));
disp(stage4DInputSentence)
if generateStage4DPlots
    stage4DInputPlot = helperPlotStage4DInputPreview( ...
        stage4DInputPreview, ...
        SavePath=stage4DResults.paths.inputPreviewFigure);
else
    stage4DInputPlotStatus = "Input-preview plotting disabled.";
end
%%
%[text] ## 3. Frozen Model And Integrity Checks
%[text] The only learned artifact is |expanded_warm_mean_v1|. Stage 4D checks its architecture, provenance, and SHA-256 before and after inference; no neural training occurs.
stage4DArtifactAudit = stage4DResults.artifactAudit;
stage4DVerification = stage4DResults.verificationTable;
stage4DNativeFunctionAudit = stage4DResults.nativeFunctionAudit;
stage4DIntegritySentence = compose( ...
    "%d of %d executable integrity checks passed; training performed: %s.", ...
    sum(stage4DVerification.passed), ...
    height(stage4DVerification), ...
    string(stage4DResults.trainingPerformed));
disp(stage4DIntegritySentence)
%%
%[text] ## 4. Synthetic Conditions
%[text] Independent latent truth comes from |kinematicTrajectory|. Ideal observations use every 2 Hz truth sample, empirical timing uses intervals from frozen training rows, and degraded observations add position/velocity noise plus random report loss.
stage4DConfiguration = stage4DResults.config;
stage4DSyntheticObservationProfiles = stage4DResults.syntheticObservationProfiles;
stage4DConfigurationSentence = compose( ...
    "Mode %s uses seed %d, %d canonical cases, %d in-distribution trajectories, and %d out-of-distribution trajectories.", ...
    stage4DResults.benchmarkMode, ...
    stage4DResults.randomSeed, ...
    height(stage4DResults.canonicalCaseTable), ...
    stage4DResults.syntheticEvidence.inDistribution.truthTrajectoryCount, ...
    stage4DResults.syntheticEvidence.outOfDistribution.truthTrajectoryCount);
disp(stage4DConfigurationSentence)
%%
%[text] ## 5. Motion Type Changes The One-Step Error
%[text] Seven canonical motions separate level flight, climb, acceleration, turns, and transitions. The chart keeps the fair same-information comparison visible; detailed per-case results remain in |stage4DCanonicalMetrics|.
stage4DCanonicalCases = stage4DResults.canonicalCaseTable;
stage4DCanonicalMetrics = stage4DResults.canonicalMetricTable( ...
    stage4DResults.canonicalMetricTable.weighting == "pair_weighted", :);
if generateStage4DPlots
    stage4DMotionPlot = helperPlotStage4DMotionComparison( ...
        stage4DResults, ...
        SavePath=stage4DResults.paths.motionComparisonFigure);
else
    stage4DMotionPlotStatus = "Motion-comparison plotting disabled.";
end
%%
%[text] ## 6. Mixed Motion And Held-Out ADS-B
%[text] Mixed-motion synthetic results distinguish in-distribution from deliberately stronger out-of-distribution maneuvers. Held-out ADS-B uses baseline, 10%, 25%, and contiguous burst dropout, but its target is still a retained ADS-B report rather than independent truth.
stage4DMixedMotionMetrics = stage4DResults.mixedMotionTable;
stage4DRealObservationProfiles = stage4DResults.realObservationProfiles;
stage4DRealDropoutMetrics = stage4DResults.realDropoutTable;
stage4DRealSentence = compose( ...
    "%d held-out ADS-B events were evaluated as an observation-reference proxy under %d dropout profiles.", ...
    stage4DResults.realEvidence.truthTrajectoryCount, ...
    height(stage4DRealObservationProfiles));
disp(stage4DRealSentence)
%%
%[text] ## 7. Headline Metrics And Robustness
%[text] Frozen warm and |constvel| receive exactly the same current observed state and elapsed time. Causal |constacc| and |constturn| are diagnostic context because they also receive one predecessor.
stage4DHeadlineMetrics = stage4DResults.headlineMetricTable;
stage4DEventWinRates = stage4DResults.eventWinRateTable;
stage4DPairedConfidenceIntervals = stage4DResults.pairedConfidenceIntervalTable;
stage4DRuntime = stage4DResults.runtimeTable;
if generateStage4DPlots
    stage4DRobustnessPlot = helperPlotStage4DCharacterization( ...
        stage4DResults, ...
        SavePath=stage4DResults.paths.characterizationFigure);
else
    stage4DRobustnessPlotStatus = "Robustness plotting disabled.";
end
%%
%[text] ## 8. Canonical Globe Review
%[text] The optional globe overlays observed inputs, latent truth, and one-step predictions for all canonical motions. Detailed legend and validation tables stay available in the workspace without being printed inline.
stage4DCanonicalGlobeReview = helperBuildStage4DGlobeReview( ...
    stage4DResults, ...
    ViewType="canonical", ...
    ObservationProfile=stage4DCanonicalGlobeProfile);
stage4DCanonicalGlobeSummary = stage4DCanonicalGlobeReview.summaryTable;
stage4DCanonicalGlobeLegend = stage4DCanonicalGlobeReview.legendTable;
stage4DCanonicalGlobeValidation = stage4DCanonicalGlobeReview.validationTable;
if enableStage4DInteractiveGlobe
    stage4DCanonicalGlobe = helperOpenStage4DGlobe(stage4DCanonicalGlobeReview);
else
    stage4DCanonicalGlobeStatus = "Interactive globe disabled.";
end
%%
%[text] ## 9. Held-Out ADS-B Globe Review
%[text] The second optional globe shows one ranked held-out event under the selected dropout profile. Its scoring path is the next retained ADS-B report, not latent aircraft truth.
stage4DRealGlobeReview = helperBuildStage4DGlobeReview( ...
    stage4DResults, ...
    ViewType="real_adsb", ...
    ObservationProfile=stage4DRealGlobeProfile, ...
    RealEventRank=stage4DRealGlobeEventRank);
stage4DRealGlobeSummary = stage4DRealGlobeReview.summaryTable;
stage4DRealGlobeLegend = stage4DRealGlobeReview.legendTable;
stage4DRealGlobeValidation = stage4DRealGlobeReview.validationTable;
if enableStage4DInteractiveGlobe
    stage4DRealGlobe = helperOpenStage4DGlobe(stage4DRealGlobeReview);
else
    stage4DRealGlobeStatus = "Interactive globe disabled.";
end
%%
%[text] ## 10. Conclusion
%[text] Stage 4D answers only how each transition model predicts one step from a report. Recursive correction, covariance consistency, and coasting behavior are evaluated separately in Stage 4E.
stage4DLimitations = stage4DResults.limitationsTable;
stage4DNextDecision = stage4DResults.nextDecision;
stage4DCompleted = stage4DResults.completed;
stage4DConclusionSentence = "Stage 4D complete: " + string(stage4DCompleted) + ". " + stage4DNextDecision;
disp(stage4DConclusionSentence)
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
