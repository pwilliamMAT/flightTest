# SFTT Skill Use Summary

## 2026-09-08 - Dual-Channel Capture Scheduler Interface Spec

- Skill used: `matlab-import-tracking-data`.
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: document the scheduler-facing contract for the dual-channel N320 capture invoked by the ADS-B-triggered acquisition workflow.
- How the skill affected the work: kept the specification at the acquisition and truth-handoff boundary, preserved ADS-B as separately collected truth data, and avoided introducing detection formatting, tracker behavior, or downstream analysis into the capture API.
- Result:
  - Added `TestSetupTesting/dualCaptureSchedulerInterfaceSpec.md`.
  - Documented `runLocalHDTVCapture.m` as the supported scheduler boundary and `log_iq_n320_2antennas.m` as its internal hardware backend.
  - Specified inputs, channel order, deterministic filenames, return fields, stdout markers, trigger packaging behavior, scheduler acceptance checks, resource constraints, failure handling, and current timing limitations.
  - Verified the contract statically against the capture wrapper, hardware logger, trigger supervisor, package helper, manifest writer, regression stub, and representative field logs. No hardware capture was run.

## 2026-09-08 - Stage 4H-A5 Verification Repair

- Skills used: `matlab-import-tracking-data` and `matlab-multi-object-tracking`.
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: repair eight verification defects in Stage 4H-A5, regenerate its canonical evidence once, and decide whether the bounded clean-data neural residual experiment remains authorized.
- How the skills affected the work: preserved ADS-B as truth trajectories in the existing ENU `[x, vx, y, vy, z, vz]` contract, kept native `constvel` and the frozen A2 `trackingEKF` configuration unchanged, treated ICAO only as the split and continuity key, and prevented the audit repair from becoming tracker redesign, neural training, dataset rebuilding, or Q/R selection.
- Resulting files, decisions, and verification:
  - Archived and hash-verified the 11 pre-repair outputs under `adsbForTracking/artifacts/stage4HTurnDiversityAudit/archive/20260903_preRepair/`.
  - Added native transitive dependency hashing, direct immutable-v1 comparison, canonical output/archive enforcement, all-pair event attribution, combined A5/A3 final gates, corrected test-use metadata, and transitive training/Q/R API scanning.
  - Reproduced 24,266 turn-like pairs and 1,259 sustained-turn events; v2 preserves 204 validation and 230 test baseline events and recovers 91.530% of legacy-rejected turn pairs as motion-confounded.
  - All 31 combined gates and 102 required tests pass; Code Analyzer reports zero findings across 42 files, and exact-configuration resume succeeds. The repaired decision remains `authorize_one_clean_data_neural_residual_experiment`; no training or Q/R selection occurred.

## 2026-09-03 - Stage 4H-A4 ADS-B Cartesian-Velocity Ingestion Repair

- Skill used: `matlab-import-tracking-data`.
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: repair the canonical ADS-B truth parser's course-wrap synchronization defect, rebuild Expanded-3Day in isolation, and rerun A3 before any neural training.
- How the skill affected the work: retained ADS-B as timestamp-sorted truth trajectories rather than detections, preserved the existing ENU state contract and explicit knot/degree/feet-per-minute conversions, and kept parser compatibility, source provenance, and downstream tracking usability as required invariants.
- Result: Cartesian east/north interpolation changed 408,767 rows while preserving all non-horizontal values and matching A3's independent oracle to `1.91e-13 m/s`. All 81 required tests, 15 A4 checks, 13 corrected-A3 implementation checks, and 37-file Code Analyzer checks passed. Ingestion integrity now passes, but clean-core maneuver diversity does not; the decision is `collect_or_revise_audit`, with no training or Q/R selection performed.

## 2026-09-02 - Stage 4H-A3 ADS-B Supervision Integrity Gate

- Skills used: `matlab-import-tracking-data` and `matlab-multi-object-tracking`.
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\references\time-and-units.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\references\coordinate-transforms.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: audit all 457,903 frozen ADS-B state pairs for raw-report provenance and supervision integrity, then rerun frozen predictor, `trackingEKF`, and information-gate sensitivity without neural training.
- How the skills affected the work: preserved source timestamps and units, converted speed/course/vertical rate to Cartesian ENU before interpolation, kept truth data separate from tracker measurements, retained native `constvel` and the frozen A2 `trackingEKF` configuration, and evaluated validation before descriptive development test.
- Result: every row has fixed strict/default/permissive quality annotations and raw lineage. The audit found 424 horizontal-velocity synchronization discrepancies over 5 m/s, with a 330.248 m/s maximum at a course-wrap crossing, while the default clean core retained no sustained-turn events. The decision is `repair_ingestion_and_rebuild_derived_artifacts`; no neural training is authorized. All 50 Stage 4H tests and 14 relevant dataset/parser regressions passed, Code Analyzer was clean across 30 Stage 4H files, and complete evidence is under `adsbForTracking/artifacts/stage4HADSBIntegrityGate/`.

## 2026-09-01 - Stage 4H-A2 Training-Only EKF Noise Calibration

- Skill used: `matlab-multi-object-tracking`
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: continue Stage 4H without repeating earlier work, standardize the causal replay on `trackingEKF`, tune only Q/R on training aircraft, and rerun the frozen information gate.
- How the skill affected the work: retained native `constvel`/`constveljac` and `cvmeas`/`cvmeasjac`, kept the small Cartesian-velocity adapter required by asynchronous ADS-B reports, treated filter initialization and Q/R as explicit physical assumptions, and kept validation/test data out of executable candidate selection.
- Resulting files, decisions, and verification:
  - Added `helperStage4HEKFConfiguration.m`, `helperBuildStage4HEventCache.m`, `runStage4HEKFNoiseCalibration.m`, `helperPlotStage4HEKFNoiseCalibration.m`, `runStage4HEKFCalibratedInformationGate.m`, and `tests/Stage4HEKFNoiseCalibrationTest.m`; updated the existing Stage 4H replay, dataset, gate, and tests for `trackingEKF`.
  - The frozen training-only winner is `vertical_rate_x2`: process acceleration standard deviation `[2, 2, 0.8] m/s^2`, position standard deviation `[30, 30, 45] m`, and speed/course/vertical-rate standard deviation `[1 m/s, 1 degree, 1 m/s]`.
  - On 120 training aircraft and 29,477 pairs, aircraft-mean position RMSE improved 5.647%, pair-weighted position RMSE improved 9.198%, P95 improved 25.975%, and velocity RMSE improved 0.017%.
  - On the unchanged full gate, historical-to-calibrated posterior-CV RMSE improved 8.841% on validation and 26.915% on development test. The full feature set improved calibrated validation CV by 4.520%, below the 5% gate, and complete context added no stable information beyond state plus interval.
  - Decision: `stop_before_neural_training`. This is an ADS-B point-estimation win, not a statistical covariance-calibration claim. Contradictory report handling and stale-gap/reset behavior remain a separate causal policy to freeze from training data or confirm on new ADS-B.
  - All 21 full-run integrity checks and all 37 Stage 4H tests passed. Code Analyzer reported zero findings across 23 Stage 4H files. Evidence is under `adsbForTracking/artifacts/stage4HEKFNoiseCalibration/` and `adsbForTracking/artifacts/stage4HEKFCalibratedInformationGate/`.

## 2026-09-01 - Stage 4H Session Reorientation

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\references\setup-checklist.md`
- Project task: reconcile the just-completed ADS-B tracking session and identify the next bounded investigation.
- How the skill affected the work: confirmed that the existing linear `trackingKF` uses a consistent six-state constant-velocity model and highlighted process-noise, measurement-noise, initialization, and report handling as one coupled filter configuration rather than treating a single Q or R value as the proven cause.
- Result: Stage 4H-A remains complete with neural training paused. The next recommended investigation is a training-aircraft-only filter calibration and report-quality/reset policy, followed by a frozen rerun of the same information gate.

## 2026-09-01 - Plain-Language Stage 4H Interpretation

- Skill used: `matlab-multi-object-tracking`
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: create a durable "tell me like I am five" explanation of what Stage 4H actually compared and why the current filter configuration limits the neural-model conclusion.
- How the skill affected the work: kept the distinction between measurement uncertainty, process uncertainty, prediction, and correction explicit; avoided claiming that the experiment identified one physically incorrect Q or R value; and separated direct `constvel` from `constvel` applied after recursive filtering.
- Result:
  - Added `adsbForTracking/stage4HTellMeLikeIm5Report.md`.
  - The report preserves the measured validation/test results for direct report-aligned CV, posterior CV, and the complete diagnostic correction.
  - It states that Stage 4H is valid evidence against training on the current posterior, but is not yet a clean test of learned aircraft dynamics or calibrated posterior covariance.
  - It records the next sequence: training-only Q/R and report-policy work, freeze the configuration, repeat the information gate, and train only after a stable incremental-information result.

## 2026-08-31 - Stage 4H-A Causal Posterior Information Gate

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\references\setup-checklist.md`
- Project task: complete and verify the Stage 4H-A no-training gate that reconstructs causal Kalman posterior state/covariance from asynchronous raw ADS-B events and tests whether covariance plus short history justify a new residual model.
- How the skill affected the work: replaced the interim nonlinear `trackingUKF` measurement path with native `trackingKF(MotionModel="3D Constant Velocity")`, preserved `[x,vx,y,vy,z,vz]` state order, converted reported speed/course/vertical rate to Cartesian ENU with `aer2enu`, used switched linear position/velocity measurement matrices, verified process- and measurement-noise dimensions, and retained `constvel` as the residual baseline.
- Resulting files, decisions, and verification:
  - Added the Stage 4H causal replay, frozen split application, 62-feature builder, training-aircraft ridge information ladder, posterior-fidelity audit, plot, question-driven Live Script, six test classes, and compact CSV/figure evidence plus the complete MAT result.
  - The full run matched all 457,903 pairs from 1,978 aircraft at exact anchor times. The full model improved posterior-CV validation RMSE by 7.498%, but complete context was not significantly better than state plus interval and development-test RMSE degraded by 7.603%.
  - The fixed-Q/R posterior was substantially worse than report-aligned CV, identifying classical covariance calibration and a frozen outlier/gap policy as prerequisites rather than authorizing neural training.
  - Decision: `stop_before_neural_training`. All 15 full-run checks and all 29 Stage 4H tests passed; Code Analyzer was clean, the Live Script ran headlessly, the summary figure was inspected, and frozen dataset/split hashes were unchanged.

## 2026-08-31 - Stage 4G Residual-Learnability Audit

- Skills used: `matlab-import-tracking-data`, `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: implement the approved Stage 4G no-training audit of the frozen neural correction and causal short-history learnability.
- How the skills affected the work: preserved ADS-B as truth trajectories in the existing `[x, vx, y, vy, z, vz]` state-pair contract, retained native `constvel` as the direct baseline, kept ICAO as a split/bootstrap/history-continuity key rather than a model feature, and avoided `objectDetection`, tracker construction, IMM/UKF evaluation, filter tuning, and neural training.
- Resulting files, decisions, and verification:
  - Added the Stage 4G runner, residual-signal evaluator, target-free causal-history builder, plotting helper, question-driven plain-text Live Script, test class, and compact saved evidence.
  - The full audit evaluated 86,420 validation pairs and 93,524 test pairs from 395 aircraft in each disjoint split and used 2,000 complete-aircraft bootstrap replicates.
  - Validation selected alpha `0.1014` `[0.0503, 0.1551]`; the frozen test blend improved `constvel` position RMSE by only `0.342%`, with a paired RMSE-difference interval `[-0.134, -0.024] m`, so it failed the existing 5% gate.
  - Causal velocity-change and wrapped-heading magnitudes consistently predicted CV residual magnitude, while signed/vector continuation was not reliable. The decision is `reject_frozen_correction_authorize_history_residual`.
  - All 17 full-run checks and 10 Stage 4G tests passed. MATLAB Code Analyzer was clean, and frozen dataset, split, and warm-model hashes were unchanged.

## 2026-08-31 - Stage 4F Frozen Warm-Model Adequacy Audit

- Skill used: `matlab-multi-object-tracking`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\references\setup-checklist.md`
- Project task: test the already-frozen warm neural state transition against native `constvel` without further training or tuning, first in direct rollout and then inside otherwise identical UKFs.
- How the skill affected the work: preserved the six-state `[x, vx, y, vy, z, vz]` contract, used native `constvel`, `trackingUKF`, and `cvmeas`, matched filter initialization/noise/correction settings, audited actual sigma-point inputs, and kept the IMM out of the Stage 4F decision baseline.
- Resulting files, decisions, and verification:
  - Added `Stage4FPlan.md`, `stage4FFrozenWarmAdequacyAuditLiveScript.m`, `runStage4FFrozenWarmAdequacyAudit.m`, three focused helpers, and `tests/Stage4FFrozenWarmAdequacyAuditTest.m`.
  - The full audit covered all 93,524 test pairs, 887 direct events, 16 degraded synthetic sequences, 40 held-out ADS-B events under four profiles, and shared process-noise scales `[0.25, 1, 4]`.
  - The warm transition lost every direct horizon and every matched-UKF headline comparison at every noise scale. The decision is `reject_frozen_model`; no training, tuning, or frozen-artifact modification occurred.
  - All 17 full-run checks, 10 Stage 4F tests, 13 Stage 4D regressions, and 11 Stage 4E regressions passed. Code Analyzer was clean, and the saved summary figure was inspected after making its colors theme-independent.

## 2026-08-31 - Stage 4E IMM Configuration And Tuning Documentation

- Skill used: `matlab-multi-object-tracking`
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: make the Stage 4E review self-explanatory for a new user by documenting how the recursive benchmark arose, how the native IMM was initialized and tuned, and what the frozen tuning achieved.
- How the skill affected the work: preserved the native `trackingEKF` and `trackingIMM` model semantics, distinguished process-noise tuning from motion-model or neural-network training, and retained the boundary between recursive state estimation and multi-object data association.
- Resulting files and decisions:
  - Updated `adsbForTracking/stage4ERecursiveFilterEvaluationLiveScript.m` to reconstruct the initial IMM from its authoritative initializer, load the frozen tuning artifact, and display initial-versus-tuned process noise, transition probabilities, validation costs, and headline IMM results.
  - Expanded the root `README.md` with the Stage 3-to-4E progression, current verification status, IMM setup, tuning protocol, numeric results, run controls, saved evidence, and scope boundary.
  - Updated `adsbForTracking/concepts.md` so the Stage 4E concept entry identifies the new configuration-and-tuning review content.
  - Verified the Live Script by loading the saved full artifact with plots and globes disabled, confirmed MATLAB Code Analyzer reports no findings, and passed all 11 `Stage4ERecursiveFilterEvaluationTest` tests.

## 2026-08-31 - Stage 4E Recursive Filter Evaluation Completion

- Skills used: `matlab-import-tracking-data`, `matlab-multi-object-tracking`, `matlab-testing`, `matlab-debugging`, and `matlab-optimize-performance`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-multi-object-tracking\SKILL.md`
- Project task: resume and complete the interrupted Stage 4E recursive comparison of native CV/CA/CT EKF, native IMM, and frozen-warm UKF estimators.
- How the skills affected the work: preserved `[x, vx, y, vy, z, vz]` physical-state semantics; kept real ADS-B results labeled as a scoring proxy rather than independent truth; used native `trackingEKF`, `trackingIMM`, `trackingUKF`, `trackingFilterTuner`, `objectDetection`, and motion/measurement functions; kept tuning validation-only; and verified the class-based acceptance suite in MATLAB.
- Resulting files, decisions, and verification:
  - Produced the frozen validation-only tuning artifact and completed the full 48-synthetic-sequence/40-ADS-B-event benchmark under four update profiles.
  - Corrected an exact-byte initialization audit that rejected only `trackingIMM` roundoff, while leaving estimator states and covariances unchanged.
  - Bounded smoke-mode real events to 240 pairs without truncating full-mode events.
  - Replaced tiny-batch `minibatchpredict` calls with numerically equivalent direct `predict`, reducing the Stage 4E test runtime from 247 seconds to 75 seconds.
  - All 17 full-run integrity checks and all 11 Stage 4E tests passed. The native IMM was strongest on the degraded synthetic and real baseline proxy headlines; the frozen-warm UKF was not promoted.

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

## 2026-09-03 - Stage 4H-A5 Turn-Diversity Audit (Pre-Repair, Superseded)

- Skill used: `matlab-import-tracking-data`
- SFTT files read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: separate ADS-B integrity from aircraft motion, trace turn exclusions, and rerun the frozen A3 gate once without training, rebuilding data, or retuning Q/R.
- How the skill affected the work: kept ADS-B in the truth-trajectory pathway and preserved the existing ENU table/state-pair contract; no `objectDetection` conversion or tracker-input redesign was introduced.
- Historical pre-repair files, decisions, and verification:
  - Added the selectable `integrity_motion_separation_v2` policy, turn-diversity audit helper and runner, dashboard, plain-text Live Script, and focused tests.
  - Reproduced 24,266 turn-like pairs and 1,259 sustained-turn events, with 204 validation and 230 test baseline events surviving the v2 default policy.
  - Verified 91.530% of legacy-rejected turn-like pairs were motion-confounded, all 18 A5 checks and all nine A3 decision gates passed, 91/91 required tests passed, and Code Analyzer reported zero findings across 36 files.
  - Authorized one bounded clean-data neural residual experiment but did not perform training, data rebuilding, or Q/R selection.

## 2026-09-18 - Hardware and Collection Evidence Report

- Skill used: `matlab-import-tracking-data`.
- SFTT file read:
  - `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`
- Project task: create the standalone manager-facing `02_HardwareAndCollection.html` evidence report covering physical deployment, coordinated IQ capture, ADS-B/GPS context, session manifests, packaging, replay, and collection limitations.
- How the skill affected the work: kept ADS-B/GPS logs in the independent truth/geometry/time-context role; explicitly prohibited presenting them as passive-radar detections, tracker outputs, or radar-performance evidence. The report separately labels implemented collection support, demonstrated historical packaging, and unproven field-readiness claims.
- Result:
  - Created `ManagerReport/02_HardwareAndCollection.html` with embedded actual-deployment photographs, standalone architecture/workflow/provenance visuals, scorecard, evidence links, glossary, and explicit non-claims.
  - Added scoped figure and source inventories in `ManagerReport/`.
  - No ADS-B import, tracker construction, data conversion, MATLAB execution, or radar-performance result was produced.

## 2026-09-18 — Hardware and Collection V2 evidence report
- Skill: matlab-import-tracking-data
- Files read: SKILL.md; flightTest ADS-B/GPS collection and manifest evidence summarized in ManagerReport/02_HardwareAndCollection_V2.html
- Task: Kept ADS-B and GPS/NMEA content framed as independent truth, time, and geometry context during the V2 hardware/collection evidence-report enrichment.
- Effect and result: Added hardware-first figures, package evidence, and explicit boundaries; no ADS-B/GPS artifact was represented as a passive-radar detection, tracker output, or performance proof.

## 2026-09-18 — Hardware and Collection V3 enhancement
- Skill: matlab-import-tracking-data
- Files read: SKILL.md; flightTest ADS-B/GPS logger, collection, manifest, provenance, and readiness evidence summarized in ManagerReport/02_HardwareAndCollection_V3.html.
- Task: Preserved ADS-B/GPS as independent truth, timing, and geometry context while adding V3 executive evidence status, traceability, configuration control, and management recommendations.
- Effect and result: The V3 evidence matrix and trace example explicitly distinguish packaged ADS-B context from passive-radar aircraft measurements, detections, tracking, and performance claims.

## 2026-09-18 — Hardware and Collection V4 stabilization

- Skill: `matlab-import-tracking-data`
- Files read: `C:\Users\pwilliam\agenticProjects\toolkits\sensor-fusion-and-tracking-toolbox\.claude\skills\matlab-import-tracking-data\SKILL.md`; `C:\Users\pwilliam\agenticProjects\flightTest\hardwareCheck.md`; `C:\Users\pwilliam\agenticProjects\flightTest\projectProvenanceUpdate.md`; V3 report and evidence register.
- Task: Stabilize `ManagerReport/02_HardwareAndCollection_V4.html` by defining reference-path qualification acceptance criteria and clarifying the RF0/RF1 evidence boundary while retaining ADS-B/GPS evidence scope.
- Effect and result: Kept ADS-B and GPS/NMEA artifacts framed as independent truth, timing, and geometry context. The new acceptance table requires session-bound GPS/NMEA evidence before any claim and treats absent or unknown metadata as HOLD; it does not create detections, tracking inputs, or radar-performance claims.
