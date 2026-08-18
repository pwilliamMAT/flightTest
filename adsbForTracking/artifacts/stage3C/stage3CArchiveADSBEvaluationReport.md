# Stage 3C Archived ADS-B Evaluation Report

Generated: 2026-08-18 13:32:11 UTC

Scope: inventory the archived ADS-B truth package, recover only the gzip files that fail MATLAB `gunzip`, and reuse the frozen Stage 3A versus native `constvel` Stage 3B scoring path. No neural retraining was run.

## Concept In Plain Language

Stage 3C asks whether the archived ADS-B truth package changes the data-readiness answer. The code treats each archived SBS-1 file as truth trajectory data, converts it into the same one-step ENU state-pair format used by Stage 3B, and scores the frozen Stage 3A MLP against MATLAB's native `constvel` predictor on identical rows.

## Native MATLAB Path Used

- Archive gzip handling: MATLAB `gunzip` first; .NET `System.IO.Compression.GZipStream` only for files where `gunzip` fails.
- Truth import: existing `loadADSBTruth` parser for SBS-1 ADS-B files.
- Coordinate conversion: Mapping Toolbox `wgs84Ellipsoid` and `geodetic2enu` through the Stage 3 state-pair builder.
- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel` through Stage 3B scoring.
- Frozen neural inference: Deep Learning Toolbox `minibatchpredict` through the saved Stage 3A artifact.
- Reporting and plots: MATLAB `table`, `groupsummary`, `findgroups`, `splitapply`, `figure`, `tiledlayout`, and `nexttile`.

## Inputs And Outputs

| Artifact | Path |
| :--- | :--- |
| Archive root | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive` |
| Stage 3C MAT artifact | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveADSBEvaluation.mat` |
| Stage 3C report | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveADSBEvaluationReport.md` |
| Archive inventory CSV | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveInventory.csv` |
| Archive inventory MAT | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveInventory.mat` |
| Stage 3B scoring MAT | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CStage3BScoringEvaluation.mat` |
| Stage 3B scoring report | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CStage3BScoringReport.md` |

## Archive Summary

| metric | value |
| :--- | :--- |
| Source files | 16 |
| Selected evaluation files | 16 |
| Usable source files | 16 |
| Usable sessions | 16 |
| Usable one-step pairs | 15013 |
| Aircraft tracks | 222 |
| Native gunzip failures | 2 |
| Fallback recovered files | 2 |
| Pi-only truth files | 0 |
| Default receiver-origin files | 16 |
| Stage 3B readiness passed | true |
| Retraining run | false |

## Headline Aggregate Comparison

| method | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | positionP95ErrorMeters | interpretation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | 15013 | 23.8704 | 5.05349 | 5.98448 | 18.7131 | Native Sensor Fusion constant-velocity prediction on the exact Stage 3B samples. |
| Frozen Stage 3A delta MLP | 15013 | 151.26 | 5.06664 | 26.6968 | 162.566 | Frozen Stage 3A delta-target MLP reconstructed as previousState + predictedDelta. |

## Archive Layout Summary

| layout | folderPath | folderExists | status | sourceFileCount | sessionCount | usablePairCount |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures | 1 | populated | 16 | 16 | 15013 |
| pi_only/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\pi_only\truth | 1 | empty | 0 | 0 | 0 |

## Archive Source Inventory

| originalSourceFile | sourceRole | sessionID | truthLayout | truthFolder | fileExists | fileSizeBytes | modifiedTime | isGzip | nativeGzipStatus | fallbackStatus | fallbackSourceFile | evaluationSourceFile | selectedForEvaluation | parseStatus | aircraftCount | validSampleCount | usablePairCount | receiverOriginSource | gzipErrorMessage | fallbackErrorMessage | parseErrorMessage | zeroUseReason |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth\0_20260611_170632_adsb_20260611T170630.txt.gz | testing_machine | 20260611T170630 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth | 1 | 25832 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth\0_20260611_170632_adsb_20260611T170630.txt.gz | 1 | parsed | 8 | 363 | 357 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth\0_20260615_103439_adsb_20260615T103437.txt.gz | testing_machine | 20260615T103437 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth | 1 | 12011 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth\0_20260615_103439_adsb_20260615T103437.txt.gz | 1 | parsed | 5 | 127 | 121 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth\0_20260616_090718_adsb_20260616T090717.txt.gz | testing_machine | 20260616T090717 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth | 1 | 25232 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth\0_20260616_090718_adsb_20260616T090717.txt.gz | 1 | parsed | 4 | 388 | 384 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth\0_20260616_131956_adsb_20260616T131954.txt.gz | testing_machine | 20260616T131954 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth | 1 | 38904 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth\0_20260616_131956_adsb_20260616T131954.txt.gz | 1 | parsed | 12 | 396 | 381 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth\0_20260616_160703_adsb_20260616T160702.txt.gz | testing_machine | 20260616T160702 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth | 1 | 49736 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth\0_20260616_160703_adsb_20260616T160702.txt.gz | 1 | parsed | 10 | 416 | 406 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth\0_20260618_160533_adsb_20260618T160532.txt.gz | testing_machine | 20260618T160532 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth | 1 | 67984 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth\0_20260618_160533_adsb_20260618T160532.txt.gz | 1 | parsed | 9 | 598 | 589 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | testing_machine | 20260622T102123 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth | 1 | 139744 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1 | parsed | 21 | 1751 | 1729 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth\0_20260622_102533_adsb_20260622T102532.txt.gz | testing_machine | 20260622T102532 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth | 1 | 118734 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth\0_20260622_102533_adsb_20260622T102532.txt.gz | 1 | parsed | 26 | 1292 | 1267 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth\0_20260622_102955_adsb_20260622T102954.txt.gz | testing_machine | 20260622T102954 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth | 1 | 138788 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth\0_20260622_102955_adsb_20260622T102954.txt.gz | 1 | parsed | 25 | 1750 | 1726 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth\0_20260708_092920_adsb_20260708T092917.txt.gz | testing_machine | 20260708T092917 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth | 1 | 24355 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth\0_20260708_092920_adsb_20260708T092917.txt.gz | 1 | parsed | 9 | 292 | 283 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth\0_20260708_135522_adsb_20260708T135521.txt.gz | testing_machine | 20260708T135521 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth | 1 | 45221 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth\0_20260708_135522_adsb_20260708T135521.txt.gz | 1 | parsed | 13 | 419 | 406 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth\0_20260708_155009_adsb_20260708T155008.txt.gz | testing_machine | 20260708T155008 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth | 1 | 81529 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth\0_20260708_155009_adsb_20260708T155008.txt.gz | 1 | parsed | 13 | 824 | 812 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth\0_20260713_150418_adsb_20260713T150404.txt.gz | testing_machine | 20260713T150404 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth | 1 | 104800 | 18-Aug-2026 08:40:40 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth\0_20260713_150418_adsb_20260713T150404.txt.gz | 1 | parsed | 14 | 1117 | 1102 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth\0_20260713_161354_adsb_20260713T161352.txt.gz | testing_machine | 20260713T161352 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth | 1 | 37172 | 18-Aug-2026 08:40:39 | 1 | succeeded | not_needed |  | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth\0_20260713_161354_adsb_20260713T161352.txt.gz | 1 | parsed | 8 | 396 | 387 | default |  |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt.gz | testing_machine | 20260720T140156 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260720T140156\truth | 1 | 162802 | 18-Aug-2026 08:40:39 | 1 | failed | succeeded | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt | 1 | parsed | 31 | 1947 | 1922 | default | An internal error has occurred. |  |  |  |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt.gz | testing_machine | 20260720T143012 | testing_machine/captures/<session_id>/truth | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260720T143012\truth | 1 | 247069 | 18-Aug-2026 08:40:39 | 1 | failed | succeeded | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt | 1 | parsed | 45 | 3187 | 3141 | default | An internal error has occurred. |  |  |  |

## Stage 3C Interpretation

| finding | status | details |
| :--- | :--- | :--- |
| basic Stage 3B readiness gates | pass | The archived evaluation passes the configured Stage 3B retraining-readiness gates. |
| independent Pi-only ADS-B logs | missing | The archive contains testing-machine captures, but pi_only/truth has no ADS-B truth files. |
| receiver-origin metadata | missing | All evaluated files used the default receiver origin because no session_manifest.json receiver LLA was available in the truth-only archive. |
| frozen model policy | held frozen | Stage 3C did not retrain; it reused the frozen Stage 3A MLP and native constvel scoring path. |
| next collection emphasis | collect targeted data | Archive scoring is broad enough for the Stage 3B gates, but independent Pi-only ADS-B truth logs are still missing. Next collection should prioritize independent holdout sessions, source diversity, maneuver/update-regime coverage, and passive-radar-relevant geometry rather than raw sample count alone. |

## Data Readiness Gate

Ready for a future gated retraining experiment. Keep Stage 3A frozen for this report and start retraining as a new stage.

| gate | observedValue | requiredValue | passed | details |
| :--- | :--- | :--- | :--- | :--- |
| distinct ADS-B sessions | 16 | 3 | 1 | Observed 16; requirement met. |
| local truth files used | 16 | 3 | 1 | Observed 16; requirement met. |
| distinct aircraft tracks | 222 | 20 | 1 | Observed 222; requirement met. |
| non-constvel maneuver classes | 3 | 2 | 1 | Observed 3; requirement met. |
| constacc-like pairs | 3129 | 100 | 1 | Observed 3129; requirement met. |
| constturn-like pairs | 350 | 100 | 1 | Observed 350; requirement met. |
| sparse-update pairs | 336 | 100 | 1 | Observed 336; requirement met. |
| climb pairs | 4919 | 100 | 1 | Observed 4919; requirement met. |
| descent pairs | 4374 | 100 | 1 | Observed 4374; requirement met. |

## Verification Checks

| check | passed | details |
| :--- | :--- | :--- |
| archive files selected | 1 | 16 file(s) selected for evaluation |
| nonempty Stage 3B scoring | 1 | 15013 state pairs scored |
| all scoring verification checks passed | 1 | 4 Stage 3B checks passed |
| fallback recovered native gunzip failures | 1 | 2 native gunzip failure(s), 2 fallback recovery file(s) |
| no retraining performed | 1 | Frozen Stage 3A artifact was loaded for inference only |

## Motion And Update Coverage

| maneuverClass | pairCount | percent |
| :--- | :--- | :--- |
| constvel_like | 10699 | 71.2649 |
| constacc_like | 3129 | 20.8419 |
| constturn_like | 350 | 2.33131 |
| mixed_or_sparse | 835 | 5.56185 |

| dtRegime | pairCount | percent |
| :--- | :--- | :--- |
| regular_update | 14677 | 97.7619 |
| sparse_update | 336 | 2.23806 |

| verticalStatus | pairCount | percent |
| :--- | :--- | :--- |
| descent | 4374 | 29.1347 |
| level | 5720 | 38.1003 |
| climb | 4919 | 32.7649 |

## Collection Recommendation

Archive scoring is broad enough for the Stage 3B gates, but independent Pi-only ADS-B truth logs are still missing. Next collection should prioritize independent holdout sessions, source diversity, maneuver/update-regime coverage, and passive-radar-relevant geometry rather than raw sample count alone.

## Figures

- archiveUsability: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3C_archive_usability.png`
- readinessGates: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3C_data_readiness_gates.png`
- motionUpdateCoverage: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3C_motion_update_coverage.png`
