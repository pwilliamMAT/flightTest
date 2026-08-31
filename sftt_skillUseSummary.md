# SFTT Skill Use Summary

## 2026-08-31 - ADS-B Branch Preservation And Validation

- Skills used: `matlab-multi-object-tracking`, `matlab-testing`
- Skill files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
  - `C:\Users\pwilliam\.agents\skills\matlab-testing\SKILL.md`
- Project task: preserve the completed ADS-B Stage 4B-Post through Stage 4D work in coherent Git commits, isolate Stage 4E as work in progress, and verify each boundary before publishing it remotely.
- How the skills affected the work: retained the native `constvel`, `constacc`, `constturn`, `trackingEKF`, `trackingUKF`, and `trackingIMM` semantics; used the existing class-based tests as the acceptance evidence; and kept Stage 4E isolated as unapproved recursive-filter research.
- Result: Stage 4B-Post passed 33 focused and regression tests, Stage 4C passed 39 tests, Stage 4D passed 52 focused and regression tests, and Stage 4E passed 11 tests after regenerating its previously stale verification artifact. All current Stage 4E invariants, including identical projected six-state initialization, pass. The changed MATLAB files passed Code Analyzer, and Stage 4E remains on a dedicated WIP branch pending an explicit milestone decision.

## 2026-08-28 - Stage 4D Condition Interpretation

- Skill used: `matlab-multi-object-tracking`
- SFTT file read:
  - `C:\Users\pwilliam\.agents\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: explain the observation regimes, transition-relative metric, and native motion-model information boundaries shown in the Stage 4D characterization figure.
- How the skill affected the work: distinguished the same-information warm-versus-`constvel` comparison from predecessor-assisted `constacc`/`constturn` diagnostics and preserved the one-step-prediction interpretation.
- Result: confirmed that the figure reports one-step position RMSE rather than recursive tracker performance and documented the exact synthetic timing/noise/dropout and real ADS-B dropout conditions for the user.

## 2026-08-28 - Stage 4D Frozen Warm-Model Characterization

- Skill used: `matlab-multi-object-tracking`
- SFTT file read:
  - `C:\Users\pwilliam\.agents\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement the standalone Stage 4D benchmark for the frozen Stage 4C warm one-step predictor and add interactive canonical and held-out ADS-B trajectory review.
- How the skill affected the work: preserved Sensor Fusion state ordering, used native `constvel`, `constacc`, and `constturn`, kept the warm-versus-`constvel` same-information comparison distinct from predecessor-assisted CA/CT results, and used `enu2geodetic`, `geoTrajectory`, `trackingGlobeViewer`, and `plotTrajectory` without introducing tracker association or claiming a deployed tracker.
- Resulting files, decisions, and verification:
  - Added the Stage 4D computation entry point, synthetic and real-dropout helpers, metrics, visualization, plain-text Live Script, and class-based tests.
  - Added configurable Stage 4D globe reviews for all seven canonical motion scenarios and one ranked held-out ADS-B dropout event. Each view overlays observed input, the domain-correct scoring reference, frozen warm, `constvel`, causal `constacc`, and causal `constturn`.
  - Generated synthetic latent truth with `kinematicTrajectory` and scored real dropout perturbations against the next retained ADS-B observation.
  - Verified 21 canonical cases, 100 ten-minute in-distribution trajectories, 50 ten-minute out-of-distribution trajectories, and all 887 frozen held-out real events.
  - Confirmed that no scratch or Stage 3A model was loaded and that the warm SHA-256 remained `1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE`.
  - The full same-information results retain `constvel` as the deployed prediction reference; recursive warm-model and `trackingIMM` integration remain deferred.
  - Passed 51 focused and regression tests: 12 Stage 4D, 8 Stage 4C retraining, 8 Stage 4C native-baseline, and 23 Stage Review tests. MATLAB Code Analyzer was clean for all nine Stage 4D MATLAB files.

## 2026-08-28 - Configurable Stage 4C Globe Trajectory Count

- Skills used: `matlab-import-tracking-data`, `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\references\visualization.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: make the Stage 4C class-specific globe views configurable so `N` selects the longest `N` continuous eligible truth events and each viewer draws truth plus four aligned model paths per event.
- How the skills affected the work: retained ADS-B as geodetic truth trajectories, preserved native `constvel`, `constacc`, and `constturn` semantics and frozen causal eligibility, used `geoTrajectory` cell arrays with native `trackingGlobeViewer.plotTrajectory`, and kept ICAO/session values as continuity and summary keys rather than model inputs.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/helperBuildStage4CTrajectoryCollection.m` for deterministic longest-first selection, capped counts, three batched neural inference calls, event reconstruction, and continuity/eligibility/time/LLA validation.
  - Extended `helperOpenStage4CReviewGlobe` with dashboard, motion-class, and `TrajectoryCount` inputs while preserving its original single-representative call.
  - Added `stage4CGlobeTrajectoryCount = 50` to the Live Script and replaced hard-coded representative headings with collection summaries. Headless Run All does not construct or open multi-event viewers.
  - Verified 1, 50, 100, 500, and 1,000 requests produce exactly `N` events and `5N` paths; a 2,000-event turn request caps at all 1,242 eligible events and 6,210 paths.
  - Passed 39 focused tests: 23 Stage Review, 8 Stage 4C native-baseline, and 8 Stage 4C retraining tests. MATLAB Code Analyzer reported no issues in the five changed MATLAB files.
  - Inspected 50-, 100-, 500-, and 1,000-event viewer snapshots and confirmed the original one-representative viewer call still works.
  - Confirmed the frozen Stage 3A, scratch, and warm SHA-256 digests remained `2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906`, `941AFD716E75BC6D75AA4799BDCF38BC8294F8850A3876EEB2D83B0B8883F81F`, and `1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE`.

## 2026-08-28 - Stage 4C RMSE Split Semantics

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: revise the Stage 4C review so deterministic native motion models are not presented as if they undergo machine-learning validation.
- How the skill affected the work: retained `constvel`, `constacc`, and `constturn` as deterministic class-aligned comparators, used “test” only to identify the held-out rows scored by those algorithms, and kept neural validation-versus-test behavior in a separate figure.
- Resulting files, decisions, and verification:
  - Updated `adsbForTracking/helperPlotStage4CRMSEDashboard.m` to show the class-aligned native model and three frozen neural networks on 12 matched test rows only.
  - Added `adsbForTracking/helperPlotStage4CNNValidationTest.m` for the 18-row neural-only validation-versus-test comparison.
  - Updated the Live Script, regression contract, concept index, implementation plan, and README wording; no predictions or frozen artifacts were changed.
  - Visually inspected both 3-by-2 figures and passed 24 focused tests: 8 Stage Review, 8 Stage 4C native-baseline, and 8 Stage 4C retraining tests. The Stage Review test executed Run All with the interactive globes disabled.
  - MATLAB Code Analyzer reported no issues in the two plotting helpers, Live Script, or updated test.
  - Confirmed the frozen Stage 3A, scratch, and warm SHA-256 digests remained `2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906`, `941AFD716E75BC6D75AA4799BDCF38BC8294F8850A3876EEB2D83B0B8883F81F`, and `1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE`.

## 2026-08-27 - Unified Stage 4C Review Dashboard

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\.agents\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: extend `stageReviewLiveScript.m` into the Run All dashboard for frozen Expanded-3Day partitions, matched Stage 4C RMSE comparisons, and three class-specific `trackingGlobeViewer` views.
- How the skill affected the work: preserved the native `constvel`, `constacc`, and `constturn` state conventions; reused Stage 4C's causal predecessor eligibility; kept ICAO as a split and continuity key only; and treated all displayed paths as truth or one-step prediction trajectories rather than tracker outputs.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/helperBuildStage4CReviewDashboard.m`, `adsbForTracking/helperPlotStage4CRMSEDashboard.m`, and `adsbForTracking/helperOpenStage4CReviewGlobe.m`.
  - Updated `adsbForTracking/stageReviewLiveScript.m` with the 457,903-row split/motion dashboard, matched 3-by-2 RMSE figure, and deterministic `constvel_like`, `constacc_like`, and `constturn_like` representative sections.
  - Converted local ENU paths with `enu2geodetic`, created `geoTrajectory` objects, and routed all five trajectories to each independent globe viewer through `plotTrajectory`.
  - Kept all three neural artifacts frozen; no training, clipping, smoothing, recursive forecasting, or model promotion was introduced.
  - Passed 22 focused tests: 6 Stage Review, 8 Stage 4C native-baseline, and 8 Stage 4C retraining regressions. MATLAB Code Analyzer was clean for the changed dashboard implementation and test files.
  - Confirmed the frozen Stage 3A, scratch, and warm SHA-256 digests remained `2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906`, `941AFD716E75BC6D75AA4799BDCF38BC8294F8850A3876EEB2D83B0B8883F81F`, and `1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE`.

## 2026-08-27 - Stage 4C Native Maneuver-Baseline Extension

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\references\setup-checklist.md`
- Project task: add evaluation-only native `constacc` and `constturn` baselines to the frozen Stage 4C ADS-B comparison.
- How the skill affected the work: preserved the documented native state orders, used `constacc` and `constturn` directly for propagation, treated ICAO only as a split/predecessor grouping key, and kept truth-derived maneuver labels out of initialization and prediction.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/runStage4CNativeManeuverBaselineEvaluation.m` plus focused helpers for causal initialization, matched scoring, and visualization.
  - Applied `raw_causal_finite_difference_v1`: raw 3-D acceleration and wrapped heading rate from the immediately preceding adjacent observation, with no clipping or smoothing.
  - Matched the required validation/test coverage exactly: 16,896/17,030 and 17,890/18,028 `constacc_like` rows; 2,075/2,084 and 2,164/2,186 `constturn_like` rows.
  - Preserved Stage 3A, scratch, and warm model artifacts byte-for-byte. No training or model promotion occurred.
  - Retained and reported large raw turn-rate spikes; bounded or smoothed causal initialization remains deferred.
  - Passed 37 focused and regression tests across the native extension, Stage Review, Stage 4C, Stage 3A, Stage 3B, and Stage 4B-Post. MATLAB Code Analyzer reported zero issues in the eight changed non-notebook MATLAB files.

## 2026-08-27 - Stage 4C-Retrain Expanded-3Day Mean MLP

- Skills used: `matlab-import-tracking-data`, `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement and run the approved Stage 4C exploratory retraining experiment on the frozen Expanded-3Day ADS-B state-pair dataset.
- How the skills affected the work: retained ADS-B as truth trajectories in ENU `[x, vx, y, vy, z, vz]` order, kept ICAO only as a global split key, preserved native `constvel` as the primary motion comparator, and did not create detections, change association logic, or claim a deployed tracker.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/runStage4CRetrainExpandedADSBMLP.m` and focused helpers for the 20-feature contract, normalization rebasing, held-out scoring, figures, and reporting.
  - Froze `adsbForTracking/adsb_archive/datasetVersions/expandedPost3DayICAODisjointSplit_v1.csv` with 277,959/86,420/93,524 train/validation/test pairs and no ICAO overlap.
  - Verified all 159 source-file hashes, train-only normalization, the unchanged Stage 3A artifact hash, and warm-start physical equivalence to `2.98e-4` maximum absolute difference.
  - Trained scratch and warm-start 20-64-64-6 mean MLPs with MATLAB `trainnet`; both used fresh Adam state and identical options.
  - On the untouched test split, `constvel` achieved 23.303 m position RMSE versus 208.972 m for frozen Stage 3A, 28.149 m for scratch, and 27.469 m for warm start. Neither new model was promoted.
  - Passed all 25 requested Stage 3A, Stage 3B, Stage 4B-Post, and Stage 4C tests. MATLAB Code Analyzer reported zero issues in the seven new Stage 4C MATLAB files.

## 2026-08-26 - Stage 4B-Post Dataset Integration And Motion-Diversity Gate

- Skills used: `matlab-import-tracking-data`, `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement the approved Stage 4B-Post integration and determine whether the completed three-day ADS-B campaign contains enough heterogeneous motion for a separately authorized local NN retraining experiment.
- How the skill affected the work: retained ADS-B as truth trajectories, reused `loadADSBTruth` and the existing ENU `[x, vx, y, vy, z, vz]` state-pair path, preserved native `constvel` as the comparator, and did not create `objectDetection` values or retrain a tracker/network.
- Resulting files, decisions, and verification:
  - Added safe, hash-validated, append-only integration through `adsbForTracking/integrateStage4BThreeDayArchive.m`.
  - Froze 16 Legacy-16, 143 3-Day Campaign Increment, and 159 Expanded-3Day source files in `adsbForTracking/adsb_archive/datasetVersions/adsbDatasetVariants.csv`.
  - Added manifest-driven variant evaluation and event-, contributor-, joint-regime-, and split-level motion analysis.
  - Legacy-16 reproduced 15,013 pairs and 23.870 m `constvel` position RMSE; Expanded-3Day produced 457,903 pairs and 24.520 m `constvel` position RMSE.
  - Expanded-3Day passed the local gated-retraining criteria; broad-generalization readiness remains false because the data represent one receiver geometry and collection domain.
  - No neural retraining was performed.
  - Final verification passed 33 Stage 3B through Stage 4B-Post tests, and MATLAB Code Analyzer reported no issues in the 14 changed MATLAB files. The Stage 3C regression now resolves the frozen Legacy-16 source list instead of rediscovering the expanded append-only archive.

## 2026-08-26 - Versioned Three-Day ADS-B Dataset Integration Plan

- Skill used: `matlab-import-tracking-data`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: plan safe integration of the completed three-day Stage 4B ADS-B campaign while preserving the previous smaller evaluation and defining a stronger motion-heterogeneity gate for future NN retraining.
- How the skill affected the work: kept ADS-B in the truth-trajectory pathway, retained the existing `loadADSBTruth` and `[x, vx, y, vy, z, vz]` ENU state-pair contract, and avoided introducing `objectDetection`, a new parser, or tracker changes.
- Resulting files, decisions, and verification:
  - Updated `adsbForTracking/implementationPlan.md` with the planned Stage 4B-Post versioned integration and motion-diversity gate.
  - Named the reproducible variants `legacy_pre3day_v1` (**Legacy-16**), `campaign_3day_increment_v1` (**3-Day Campaign Increment**), and `expanded_post3day_v2` (**Expanded-3Day**).
  - Required explicit hash-backed source membership and separate output folders so each variant remains independently rerunnable.
  - Required event-, aircraft-, session-, campaign-block-, joint-regime-, and split-level diversity evidence instead of relying on adjacent pair totals.
  - Verified the transferred ZIP contains 144 valid session manifests, 143 truth gzip files, one permitted no-gzip window, and no unrelated files; all 575 file entries were readable.
  - No MATLAB ingestion, scoring, or retraining was run during this planning task.

## 2026-08-17 - ADS-B Archive Sync Command

- Skill used: `matlab-import-tracking-data`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: derive an ADS-B-only sync command from the acquisition code so collected ADS-B truth logs can be archived on the development computer without copying HDTV IQ files.
- How the skill affected the work: treated ADS-B logs as truth/trajectory source data, not as detections, and preserved the repository's `truth` folder convention so later ADS-B import/discovery tools can find the files.
- Resulting files, decisions, and verification:
  - Inspected `ADSB_GPS/gatherTCPcompress.py`, `ADSB_GPS/start_adsb_gps_loggers.sh`, `TestSetupTesting/run_coordinated_hdtv_capture.sh`, `TriggerAcquisition/run_adsb_triggered_hdtv_capture.sh`, `TriggerAcquisition/helperTriggerPackageSession.m`, and `adsbForTracking/helperDiscoverLocalADSBTruthFiles.m`.
  - Confirmed Pi logger artifacts are named `*adsb*.txt` or `*adsb*.txt.gz`.
  - Confirmed packaged synchronized and triggered sessions place ADS-B truth under `captures/<session_id>/truth/`.
  - Added the ADS-B-only archive sync note to `README.md`.
  - No MATLAB execution was needed for this command-generation task.
## 2026-08-17 - Stage 4A ADS-B Truth Capture Planning

- Skill used: `matlab-import-tracking-data`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement the Stage 4A question-driven ADS-B truth capture Live Script, helpers, tests, and documentation.
- How the skill affected the work: treated ADS-B files as truth trajectory inputs, preserved the existing `loadADSBTruth` and packaged `truth/` discovery path, and kept this checkpoint out of tracker/filter retraining.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/stage4ADSBTruthCapturePlanningLiveScript.m`.
  - Added `adsbForTracking/helperBuildStage4ADSBTruthCapturePlan.m` and `adsbForTracking/helperPlotStage4ADSBTruthCapturePlan.m`.
  - Added `adsbForTracking/tests/Stage4ADSBTruthCapturePlanningLiveScriptTest.m`.
  - Confirmed the minimum gate shortfalls from the saved Stage 3B artifact: 2 sessions, 2 truth files, 3 aircraft tracks, 69 turn-like pairs, and 64 sparse-update pairs.
  - Verified Code Analyzer is clean for the new Stage 4A Live Script, helpers, and test.
  - Verified `Stage4ADSBTruthCapturePlanningLiveScriptTest` passes and the full `adsbForTracking/tests` suite passes.

## 2026-08-17 - Stage 4B ADS-B Interval Capture Campaign

- Skill used: `matlab-import-tracking-data`; `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement the Stage 4B Pi-local ADS-B interval capture campaign wrapper and tests while preserving the existing ADS-B truth ingestion path.
- How the skill affected the work: treated ADS-B files as truth trajectory inputs, preserved the `*adsb_<session_id>*.txt.gz` naming convention for later `loadADSBTruth` discovery, and kept the campaign focused on data collection rather than tracker/filter changes or retraining.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh`.
  - Added `adsbForTracking/piCaptureCampaign/README.md`.
  - Added `adsbForTracking/tests/Stage4BADSBIntervalCampaignScriptTest.m`.
  - Updated `adsbForTracking/implementationPlan.md`, `adsbForTracking/concepts.md`, and `README.md` with the Stage 4B interval campaign workflow.
  - Verified `checkcode('tests/Stage4BADSBIntervalCampaignScriptTest.m','-id')` is clean.
  - Verified `Stage4BADSBIntervalCampaignScriptTest` passes: 6 passed, 0 failed, using Git Bash discovered under `C:\Program Files\Git\bin\bash.exe`.

## 2026-08-18 - Stage 3C Archived ADS-B Evaluation Extension

- Skill used: `matlab-import-tracking-data`; `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement Stage 3C to inventory and evaluate `adsbForTracking/adsb_archive/adsb_archive` without retraining.
- How the skill affected the work: treated archived ADS-B logs as truth trajectory sources, preserved the existing `loadADSBTruth` and Stage 3 state-pair format, reused native `constvel` as the prediction comparator, and kept the work out of objectDetection/tracker formatting.
- Resulting files, decisions, and verification:
  - Added `adsbForTracking/runStage3CArchiveADSBEvaluation.m`.
  - Added `adsbForTracking/helperBuildStage3CArchiveInventory.m`, `adsbForTracking/helperWriteStage3CReport.m`, and `adsbForTracking/helperWriteStage3CFigures.m`.
  - Added `BistaticDataAnalysis/helperInflateGzipWithDotNet.m` as a fallback used only after MATLAB `gunzip` fails.
  - Added `adsbForTracking/tests/Stage3CArchiveEvaluationTest.m`.
  - Verified the archive pass reports 16 source files, 2 fallback-recovered gzip files, 16 usable sessions, 15,013 usable pairs, and 222 aircraft tracks.
  - Verified Code Analyzer is clean for the new Stage 3C files.
  - Verified `Stage3CArchiveEvaluationTest`, `Stage3BAggregateEvaluationTest`, and `Stage4ADSBTruthCapturePlanningLiveScriptTest` pass.

## 2026-08-18 - Stage 4 Alignment After Stage 3C

- Skill used: `matlab-import-tracking-data`; `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: update Stage 4A and Stage 4B after the Stage 3C archive finding so future ADS-B collection is targeted around independent Pi-only holdout data, receiver-origin metadata, source diversity, motion/update coverage, and passive-radar geometry rather than raw count shortfalls.
- How the skill affected the work: kept ADS-B files in the truth trajectory path instead of converting them to detections, preserved native `constvel` as the prediction comparator, and kept Stage 4 as planning/collection guidance with no retraining.
- Resulting files, decisions, and verification:
  - Updated `adsbForTracking/helperBuildStage4ADSBTruthCapturePlan.m` to prefer the Stage 3C artifact and fall back to Stage 3B when Stage 3C is absent.
  - Updated `adsbForTracking/helperPlotStage4ADSBTruthCapturePlan.m`, `adsbForTracking/stage4ADSBTruthCapturePlanningLiveScript.m`, and Stage 4 tests for Pi-only coverage, receiver-origin metadata coverage, and Stage 3C collection priorities.
  - Updated `adsbForTracking/piCaptureCampaign/README.md` and `Stage4BADSBIntervalCampaignScriptTest.m` to require `session_manifest.json` receiver LLA metadata during sync/package.
  - Updated `adsbForTracking/implementationPlan.md`, `adsbForTracking/concepts.md`, root `README.md`, and root `concepts.md`.
  - Verified Code Analyzer is clean for changed MATLAB files.
  - Verified `Stage4ADSBTruthCapturePlanningLiveScriptTest`, `Stage4BADSBIntervalCampaignScriptTest`, `Stage3BAggregateEvaluationTest`, and `Stage3CArchiveEvaluationTest` pass.

## 2026-08-18 - Stage 4 Alignment Final Verification

- Skill used: `matlab-import-tracking-data`; `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: finalize the Stage 4 alignment update after Stage 3C by correcting the Stage 4A collection-priority plot readability and rerunning the required analyzer and regression checks.
- How the skill affected the work: kept ADS-B archive and Pi-only files in the truth trajectory workflow, preserved `constvel` as the native comparator context, and avoided any retraining or objectDetection conversion.
- Resulting files, decisions, and verification:
  - Updated `adsbForTracking/helperPlotStage4ADSBTruthCapturePlan.m` so source and receiver-origin metadata coverage use horizontal bars and the collection-priority plot uses normalized progress with explicit status labels.
  - Regenerated the Stage 4A figure artifacts through `stage4ADSBTruthCapturePlanningLiveScript.m`.
  - Verified Code Analyzer is clean for `helperBuildStage4ADSBTruthCapturePlan.m`, `helperPlotStage4ADSBTruthCapturePlan.m`, `stage4ADSBTruthCapturePlanningLiveScript.m`, `Stage4ADSBTruthCapturePlanningLiveScriptTest.m`, and `Stage4BADSBIntervalCampaignScriptTest.m`.
  - Verified `Stage4ADSBTruthCapturePlanningLiveScriptTest`, `Stage4BADSBIntervalCampaignScriptTest`, `Stage3BAggregateEvaluationTest`, and `Stage3CArchiveEvaluationTest` pass.

## 2026-08-18 - Stage 4B Testing-Machine ADS-B Capture Coordinator

- Skill used: `matlab-import-tracking-data`; `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: convert Stage 4B from a Pi-local ADS-B interval wrapper into a testing-machine coordinator that SSHes to the Pi, fetches ADS-B gzip truth logs, and packages ADS-B-only holdout sessions locally.
- How the skill affected the work: kept ADS-B logs in the truth trajectory pathway, preserved the existing `*adsb_<session_id>*.txt.gz` and `captures/<session_id>/truth/` discovery contract, and added manifest receiver-origin metadata instead of converting truth to detections or changing tracker logic.
- Resulting files, decisions, and verification:
  - Updated `adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh` to add Pi SSH/SCP options, dry-run/preflight coordinator output, remote logger polling, local package creation, and `receiver_origin_lla` manifest metadata.
  - Updated `adsbForTracking/tests/Stage4BADSBIntervalCampaignScriptTest.m` with new help/dry-run/validation/preflight checks and a fake `ssh`/`scp` packaging test.
  - Updated `adsbForTracking/piCaptureCampaign/README.md`, root `README.md`, `adsbForTracking/implementationPlan.md`, root `concepts.md`, and `adsbForTracking/concepts.md` to describe the testing-machine workflow.
  - Adjusted Stage 4B to match the full capture coordinator ADS-B path: preflight checks the remote Python `gatherTCPcompress.py` logger and `python3`, and capture starts that logger with `setsid`/`nohup` plus `--session-id` and `--run-seconds` rather than adding a separate `dump1090` preflight.
  - Verified `bash -n adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh` passes under Git Bash.
  - Verified Code Analyzer is clean for `Stage4BADSBIntervalCampaignScriptTest.m`.
  - Verified `Stage4BADSBIntervalCampaignScriptTest`, `Stage4ADSBTruthCapturePlanningLiveScriptTest`, and `Stage3CArchiveEvaluationTest` pass.
