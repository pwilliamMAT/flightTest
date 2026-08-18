# SFTT Skill Use Summary

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
