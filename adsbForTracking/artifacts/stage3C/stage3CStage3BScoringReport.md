# Stage 3B Aggregate ADS-B Evaluation Report

Generated: 2026-08-18 13:31:53 UTC

Scope: aggregate all currently discoverable local ADS-B truth data, evaluate the frozen Stage 3A MLP against native `constvel`, and decide whether the data is ready for a future retraining stage. No neural retraining was run.

## Concept In Plain Language

Stage 3B freezes the Stage 3A neural network and treats it like a saved prediction component. Every eligible ADS-B state pair is scored twice: once with the native constant-velocity model and once with the frozen delta-target MLP. The comparison uses the exact same rows, so any difference comes from the predictor rather than from a data split mismatch.

```matlab
constvelPredictedNextState = constvel(previousState, dtSeconds);
predictedDeltaNormalized = minibatchpredict(net, frozenFeatures);
predictedDelta = predictedDeltaNormalized .* targetStd + targetMean;
frozenStage3APredictedNextState = previousState + predictedDelta;
```

## Native MATLAB Path Used

- ADS-B state-pair aggregation: existing local `loadADSBTruth` and Stage 2B dataset builder.
- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel`.
- Frozen neural inference: Deep Learning Toolbox `minibatchpredict`.
- Metrics and grouped reporting: MATLAB `table`, `findgroups`, `splitapply`, `vecnorm`, `mean`, `median`, and `prctile`.
- Plots: MATLAB `figure`, `tiledlayout`, `nexttile`, and optional `trackingGlobeViewer` review.

## Inputs And Outputs

| Artifact | Path |
| :--- | :--- |
| Stage 3B aggregate dataset | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveStatePairDataset.mat` |
| Stage 3B dataset summary | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveStatePairDatasetSummary.md` |
| Frozen Stage 3A artifact | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\localADSBMLPStage3Training.mat` |
| Stage 3B MAT artifact | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CStage3BScoringEvaluation.mat` |
| Stage 3B report | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CStage3BScoringReport.md` |

## Headline Aggregate Comparison

| method | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | positionP95ErrorMeters | interpretation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | 15013 | 23.8704 | 5.05349 | 5.98448 | 18.7131 | Native Sensor Fusion constant-velocity prediction on the exact Stage 3B samples. |
| Frozen Stage 3A delta MLP | 15013 | 151.26 | 5.06664 | 26.6968 | 162.566 | Frozen Stage 3A delta-target MLP reconstructed as previousState + predictedDelta. |

## Data Inventory

| sourceFile | fileExists | fileSizeBytes | modifiedTime | parseStatus | usedInDataset | usablePairCount | sessionID |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth\0_20260611_170632_adsb_20260611T170630.txt.gz | 1 | 25832 | 18-Aug-2026 08:40:39 | parsed | 1 | 357 | 20260611T170630 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth\0_20260615_103439_adsb_20260615T103437.txt.gz | 1 | 12011 | 18-Aug-2026 08:40:40 | parsed | 1 | 121 | 20260615T103437 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth\0_20260616_090718_adsb_20260616T090717.txt.gz | 1 | 25232 | 18-Aug-2026 08:40:40 | parsed | 1 | 384 | 20260616T090717 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth\0_20260616_131956_adsb_20260616T131954.txt.gz | 1 | 38904 | 18-Aug-2026 08:40:39 | parsed | 1 | 381 | 20260616T131954 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth\0_20260616_160703_adsb_20260616T160702.txt.gz | 1 | 49736 | 18-Aug-2026 08:40:39 | parsed | 1 | 406 | 20260616T160702 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth\0_20260618_160533_adsb_20260618T160532.txt.gz | 1 | 67984 | 18-Aug-2026 08:40:40 | parsed | 1 | 589 | 20260618T160532 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1 | 139744 | 18-Aug-2026 08:40:40 | parsed | 1 | 1729 | 20260622T102123 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth\0_20260622_102533_adsb_20260622T102532.txt.gz | 1 | 118734 | 18-Aug-2026 08:40:39 | parsed | 1 | 1267 | 20260622T102532 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth\0_20260622_102955_adsb_20260622T102954.txt.gz | 1 | 138788 | 18-Aug-2026 08:40:39 | parsed | 1 | 1726 | 20260622T102954 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth\0_20260708_092920_adsb_20260708T092917.txt.gz | 1 | 24355 | 18-Aug-2026 08:40:39 | parsed | 1 | 283 | 20260708T092917 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth\0_20260708_135522_adsb_20260708T135521.txt.gz | 1 | 45221 | 18-Aug-2026 08:40:40 | parsed | 1 | 406 | 20260708T135521 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth\0_20260708_155009_adsb_20260708T155008.txt.gz | 1 | 81529 | 18-Aug-2026 08:40:40 | parsed | 1 | 812 | 20260708T155008 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth\0_20260713_150418_adsb_20260713T150404.txt.gz | 1 | 104800 | 18-Aug-2026 08:40:40 | parsed | 1 | 1102 | 20260713T150404 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth\0_20260713_161354_adsb_20260713T161352.txt.gz | 1 | 37172 | 18-Aug-2026 08:40:39 | parsed | 1 | 387 | 20260713T161352 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt | 1 | 1.38742e+06 | 18-Aug-2026 09:31:19 | parsed | 1 | 1922 | 20260720T140156 |
| C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt | 1 | 2.06645e+06 | 18-Aug-2026 09:31:22 | parsed | 1 | 3141 | 20260720T143012 |

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
| frozen delta reconstruction | 1 | max abs reconstruction error = 0 |
| same sample count for constvel and MLP | 1 | constvel rows = 15013, MLP rows = 15013 |
| finite frozen MLP predictions | 1 | finite prediction rows = 15013 |
| all aggregate metrics use dataset row count | 1 | dataset rows = 15013 |

## Metrics By Session

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | sessionID | 20260611T170630 | 357 | 94.2406 | 4.56035 | 4.96422 | 0.19427 | 15.8137 | 1.3148 |
| Frozen Stage 3A delta MLP | sessionID | 20260611T170630 | 357 | 191.417 | 4.62124 | 8.88869 | 0.252395 | 201.935 | 1.53769 |
| constvel baseline | sessionID | 20260615T103437 | 121 | 7.68679 | 1.09368 | 4.95336 | 0.366304 | 14.4131 | 2.41192 |
| Frozen Stage 3A delta MLP | sessionID | 20260615T103437 | 121 | 81.1808 | 1.21306 | 14.9602 | 0.449934 | 171.907 | 2.67273 |
| constvel baseline | sessionID | 20260616T090717 | 384 | 8.94211 | 0.753562 | 5.34618 | 0.286329 | 13.5686 | 1.43071 |
| Frozen Stage 3A delta MLP | sessionID | 20260616T090717 | 384 | 114.141 | 0.833468 | 22.537 | 0.317501 | 123.401 | 1.53236 |
| constvel baseline | sessionID | 20260616T131954 | 381 | 8.80486 | 0.953193 | 5.32624 | 0.120092 | 17.2883 | 2.15509 |
| Frozen Stage 3A delta MLP | sessionID | 20260616T131954 | 381 | 140.333 | 1.14049 | 35.3452 | 0.199937 | 180.176 | 2.23783 |
| constvel baseline | sessionID | 20260616T160702 | 406 | 20.5563 | 1.38027 | 6.73047 | 0.284694 | 23.5597 | 2.30691 |
| Frozen Stage 3A delta MLP | sessionID | 20260616T160702 | 406 | 215.353 | 1.5875 | 76.8735 | 0.464702 | 251.471 | 2.32778 |
| constvel baseline | sessionID | 20260618T160532 | 589 | 66.3188 | 4.89877 | 5.388 | 0.0369007 | 12.5594 | 1.0161 |
| Frozen Stage 3A delta MLP | sessionID | 20260618T160532 | 589 | 231.452 | 4.92924 | 28.2599 | 0.207682 | 221.169 | 1.54966 |
| constvel baseline | sessionID | 20260622T102123 | 1729 | 9.58791 | 1.01989 | 5.93985 | 0.0653882 | 17.9101 | 1.57284 |
| Frozen Stage 3A delta MLP | sessionID | 20260622T102123 | 1729 | 131.927 | 0.920472 | 22.5427 | 0.15023 | 88.3493 | 1.52765 |
| constvel baseline | sessionID | 20260622T102532 | 1267 | 10.6506 | 1.13185 | 6.85258 | 0.152203 | 20.0658 | 1.68002 |
| Frozen Stage 3A delta MLP | sessionID | 20260622T102532 | 1267 | 171.576 | 1.22968 | 31.9069 | 0.22622 | 231.47 | 1.97819 |
| constvel baseline | sessionID | 20260622T102954 | 1726 | 9.61917 | 1.32359 | 5.96647 | 0.195349 | 18.1291 | 2.31019 |
| Frozen Stage 3A delta MLP | sessionID | 20260622T102954 | 1726 | 139.542 | 1.37677 | 23.1925 | 0.27914 | 141.493 | 2.37477 |
| constvel baseline | sessionID | 20260708T092917 | 283 | 7.65017 | 0.7963 | 5.05545 | 0.13495 | 14.9293 | 1.67518 |
| Frozen Stage 3A delta MLP | sessionID | 20260708T092917 | 283 | 174.939 | 1.00892 | 23.4866 | 0.222406 | 290.366 | 2.26684 |
| constvel baseline | sessionID | 20260708T135521 | 406 | 12.5815 | 1.92549 | 8.49392 | 0.260559 | 24.0692 | 3.83279 |
| Frozen Stage 3A delta MLP | sessionID | 20260708T135521 | 406 | 154.154 | 2.03231 | 65.8758 | 0.440137 | 266.669 | 3.82027 |
| constvel baseline | sessionID | 20260708T155008 | 812 | 9.48763 | 0.911242 | 5.99139 | 0.245488 | 16.6574 | 1.90955 |
| Frozen Stage 3A delta MLP | sessionID | 20260708T155008 | 812 | 95.8113 | 0.949133 | 27.7299 | 0.320521 | 131.331 | 1.98573 |
| constvel baseline | sessionID | 20260713T150404 | 1102 | 25.8725 | 2.80755 | 6.418 | 0.164713 | 23.8611 | 2.64291 |
| Frozen Stage 3A delta MLP | sessionID | 20260713T150404 | 1102 | 210.547 | 2.70189 | 34.4431 | 0.281051 | 267.746 | 2.90356 |
| constvel baseline | sessionID | 20260713T161352 | 387 | 28.8826 | 20.1361 | 5.7575 | 0.248111 | 12.1401 | 1.92585 |
| Frozen Stage 3A delta MLP | sessionID | 20260713T161352 | 387 | 156.212 | 20.1348 | 52.0934 | 0.253165 | 230.984 | 2.00394 |
| constvel baseline | sessionID | 20260720T140156 | 1922 | 9.38852 | 0.571731 | 6.14254 | 0.0858456 | 17.8449 | 1.30282 |
| Frozen Stage 3A delta MLP | sessionID | 20260720T140156 | 1922 | 121.278 | 0.619256 | 24.2642 | 0.234313 | 121.109 | 1.32677 |
| constvel baseline | sessionID | 20260720T143012 | 3141 | 15.0142 | 7.68124 | 5.60158 | 0.216747 | 18.8158 | 2.29382 |
| Frozen Stage 3A delta MLP | sessionID | 20260720T143012 | 3141 | 130.388 | 7.70502 | 23.4884 | 0.300407 | 138.276 | 2.36942 |

## Metrics By Source File

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth\0_20260611_170632_adsb_20260611T170630.txt.gz | 357 | 94.2406 | 4.56035 | 4.96422 | 0.19427 | 15.8137 | 1.3148 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260611T170630\truth\0_20260611_170632_adsb_20260611T170630.txt.gz | 357 | 191.417 | 4.62124 | 8.88869 | 0.252395 | 201.935 | 1.53769 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth\0_20260615_103439_adsb_20260615T103437.txt.gz | 121 | 7.68679 | 1.09368 | 4.95336 | 0.366304 | 14.4131 | 2.41192 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260615T103437\truth\0_20260615_103439_adsb_20260615T103437.txt.gz | 121 | 81.1808 | 1.21306 | 14.9602 | 0.449934 | 171.907 | 2.67273 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth\0_20260616_090718_adsb_20260616T090717.txt.gz | 384 | 8.94211 | 0.753562 | 5.34618 | 0.286329 | 13.5686 | 1.43071 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T090717\truth\0_20260616_090718_adsb_20260616T090717.txt.gz | 384 | 114.141 | 0.833468 | 22.537 | 0.317501 | 123.401 | 1.53236 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth\0_20260616_131956_adsb_20260616T131954.txt.gz | 381 | 8.80486 | 0.953193 | 5.32624 | 0.120092 | 17.2883 | 2.15509 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T131954\truth\0_20260616_131956_adsb_20260616T131954.txt.gz | 381 | 140.333 | 1.14049 | 35.3452 | 0.199937 | 180.176 | 2.23783 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth\0_20260616_160703_adsb_20260616T160702.txt.gz | 406 | 20.5563 | 1.38027 | 6.73047 | 0.284694 | 23.5597 | 2.30691 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260616T160702\truth\0_20260616_160703_adsb_20260616T160702.txt.gz | 406 | 215.353 | 1.5875 | 76.8735 | 0.464702 | 251.471 | 2.32778 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth\0_20260618_160533_adsb_20260618T160532.txt.gz | 589 | 66.3188 | 4.89877 | 5.388 | 0.0369007 | 12.5594 | 1.0161 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260618T160532\truth\0_20260618_160533_adsb_20260618T160532.txt.gz | 589 | 231.452 | 4.92924 | 28.2599 | 0.207682 | 221.169 | 1.54966 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1729 | 9.58791 | 1.01989 | 5.93985 | 0.0653882 | 17.9101 | 1.57284 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1729 | 131.927 | 0.920472 | 22.5427 | 0.15023 | 88.3493 | 1.52765 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth\0_20260622_102533_adsb_20260622T102532.txt.gz | 1267 | 10.6506 | 1.13185 | 6.85258 | 0.152203 | 20.0658 | 1.68002 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102532\truth\0_20260622_102533_adsb_20260622T102532.txt.gz | 1267 | 171.576 | 1.22968 | 31.9069 | 0.22622 | 231.47 | 1.97819 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth\0_20260622_102955_adsb_20260622T102954.txt.gz | 1726 | 9.61917 | 1.32359 | 5.96647 | 0.195349 | 18.1291 | 2.31019 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260622T102954\truth\0_20260622_102955_adsb_20260622T102954.txt.gz | 1726 | 139.542 | 1.37677 | 23.1925 | 0.27914 | 141.493 | 2.37477 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth\0_20260708_092920_adsb_20260708T092917.txt.gz | 283 | 7.65017 | 0.7963 | 5.05545 | 0.13495 | 14.9293 | 1.67518 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T092917\truth\0_20260708_092920_adsb_20260708T092917.txt.gz | 283 | 174.939 | 1.00892 | 23.4866 | 0.222406 | 290.366 | 2.26684 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth\0_20260708_135522_adsb_20260708T135521.txt.gz | 406 | 12.5815 | 1.92549 | 8.49392 | 0.260559 | 24.0692 | 3.83279 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T135521\truth\0_20260708_135522_adsb_20260708T135521.txt.gz | 406 | 154.154 | 2.03231 | 65.8758 | 0.440137 | 266.669 | 3.82027 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth\0_20260708_155009_adsb_20260708T155008.txt.gz | 812 | 9.48763 | 0.911242 | 5.99139 | 0.245488 | 16.6574 | 1.90955 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260708T155008\truth\0_20260708_155009_adsb_20260708T155008.txt.gz | 812 | 95.8113 | 0.949133 | 27.7299 | 0.320521 | 131.331 | 1.98573 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth\0_20260713_150418_adsb_20260713T150404.txt.gz | 1102 | 25.8725 | 2.80755 | 6.418 | 0.164713 | 23.8611 | 2.64291 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T150404\truth\0_20260713_150418_adsb_20260713T150404.txt.gz | 1102 | 210.547 | 2.70189 | 34.4431 | 0.281051 | 267.746 | 2.90356 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth\0_20260713_161354_adsb_20260713T161352.txt.gz | 387 | 28.8826 | 20.1361 | 5.7575 | 0.248111 | 12.1401 | 1.92585 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\adsb_archive\testing_machine\captures\20260713T161352\truth\0_20260713_161354_adsb_20260713T161352.txt.gz | 387 | 156.212 | 20.1348 | 52.0934 | 0.253165 | 230.984 | 2.00394 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt | 1922 | 9.38852 | 0.571731 | 6.14254 | 0.0858456 | 17.8449 | 1.30282 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T140156\truth\0_20260720_140157_adsb_20260720T140156.txt | 1922 | 121.278 | 0.619256 | 24.2642 | 0.234313 | 121.109 | 1.32677 |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt | 3141 | 15.0142 | 7.68124 | 5.60158 | 0.216747 | 18.8158 | 2.29382 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\fallback_truth\testing_machine\captures\20260720T143012\truth\0_20260720_143014_adsb_20260720T143012.txt | 3141 | 130.388 | 7.70502 | 23.4884 | 0.300407 | 138.276 | 2.36942 |

## Metrics By Aircraft Track

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | aircraftTrack | 20260611T170630/A34C64 | 202 | 5.54789 | 0.338925 | 4.32803 | 0.168197 | 9.9698 | 0.795649 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/A34C64 | 202 | 8.82906 | 0.353236 | 6.44902 | 0.187275 | 14.4404 | 0.787496 |
| constvel baseline | aircraftTrack | 20260611T170630/A80A7C | 7 | 283.045 | 22.3739 | 123.132 | 15.5458 | 698.805 | 36.7081 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/A80A7C | 7 | 325.77 | 22.2026 | 121.077 | 15.0388 | 644.883 | 36.6245 |
| constvel baseline | aircraftTrack | 20260611T170630/AB31D7 | 70 | 5.76388 | 0.459683 | 3.58041 | 0.270783 | 11.4429 | 0.649069 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/AB31D7 | 70 | 18.9929 | 0.477929 | 13.1305 | 0.293941 | 34.8113 | 0.676064 |
| constvel baseline | aircraftTrack | 20260611T170630/ABC2C8 | 29 | 8.2213 | 0.234837 | 7.11488 | 0.125057 | 13.9232 | 0.530444 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/ABC2C8 | 29 | 441.906 | 0.570085 | 72.5148 | 0.327889 | 1327.11 | 1.44361 |
| constvel baseline | aircraftTrack | 20260611T170630/C06167 | 34 | 12.2077 | 0.573861 | 7.43654 | 0.215027 | 24.922 | 1.14492 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/C06167 | 34 | 63.2886 | 0.590365 | 17.4351 | 0.267092 | 142.734 | 1.07751 |
| constvel baseline | aircraftTrack | 20260611T170630/C084A3 | 15 | 415.873 | 16.0614 | 15.2445 | 1.36719 | 1222.45 | 46.2799 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260611T170630/C084A3 | 15 | 658.151 | 16.5547 | 85.2187 | 1.40109 | 1908.68 | 47.7202 |
| constvel baseline | aircraftTrack | 20260615T103437/A2CF40 | 8 | 12.896 | 2.75173 | 8.78535 | 1.76017 | 25.8396 | 5.90232 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260615T103437/A2CF40 | 8 | 162.021 | 3.206 | 121.89 | 2.21809 | 258.097 | 6.88525 |
| constvel baseline | aircraftTrack | 20260615T103437/A4F8EB | 86 | 4.95101 | 0.795198 | 3.98213 | 0.414908 | 8.7902 | 1.56434 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260615T103437/A4F8EB | 86 | 28.4609 | 0.837874 | 11.4197 | 0.421181 | 61.5388 | 1.62775 |
| constvel baseline | aircraftTrack | 20260615T103437/AA6B9D | 4 | 23.8477 | 0.173221 | 22.6282 | 0.140515 | 33.3855 | 0.282148 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260615T103437/AA6B9D | 4 | 315.145 | 0.362694 | 218.954 | 0.290458 | 537.466 | 0.588759 |
| constvel baseline | aircraftTrack | 20260615T103437/AB5A01 | 16 | 7.52394 | 0.768985 | 6.06969 | 0.17205 | 14.1973 | 2.008 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260615T103437/AB5A01 | 16 | 62.5953 | 0.894708 | 13.4223 | 0.196531 | 174.99 | 2.33578 |
| constvel baseline | aircraftTrack | 20260615T103437/ADCDCC | 7 | 8.70447 | 1.69846 | 7.55553 | 0.536576 | 13.1098 | 4.35494 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260615T103437/ADCDCC | 7 | 90.872 | 1.77748 | 69.7784 | 0.775116 | 170.598 | 4.37441 |
| constvel baseline | aircraftTrack | 20260616T090717/A20347 | 97 | 9.63488 | 0.367451 | 6.98227 | 0.295586 | 18.7624 | 0.719281 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T090717/A20347 | 97 | 104.883 | 0.640446 | 46.9489 | 0.378792 | 196.592 | 1.23369 |
| constvel baseline | aircraftTrack | 20260616T090717/A5702C | 251 | 5.55182 | 0.55775 | 4.75288 | 0.324399 | 8.83591 | 1.5129 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T090717/A5702C | 251 | 36.5888 | 0.559469 | 20.1366 | 0.314943 | 52.5208 | 1.47746 |
| constvel baseline | aircraftTrack | 20260616T090717/A6C781 | 11 | 31.1877 | 3.36674 | 5.2636 | 0.215396 | 95.4475 | 10.4164 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T090717/A6C781 | 11 | 556.313 | 3.6431 | 83.8102 | 1.57822 | 1624.34 | 10.366 |
| constvel baseline | aircraftTrack | 20260616T090717/C00DEA | 25 | 11.4274 | 0.296148 | 8.72842 | 0.0868485 | 24.8675 | 0.7609 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T090717/C00DEA | 25 | 88.4087 | 0.310343 | 15.5519 | 0.158104 | 216.871 | 0.654854 |
| constvel baseline | aircraftTrack | 20260616T131954/408121 | 74 | 5.9564 | 0.140841 | 4.88464 | 0 | 9.29652 | 0.416336 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T131954/408121 | 74 | 54.3145 | 0.168581 | 32.1912 | 0.0603677 | 80.5763 | 0.412906 |
| constvel baseline | aircraftTrack | 20260616T131954/71C208 | 22 | 8.27481 | 1.5728 | 6.23444 | 0.683921 | 15.8548 | 3.19518 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T131954/71C208 | 22 | 192.22 | 1.12931 | 68.8826 | 0.747906 | 431.367 | 2.44357 |
| constvel baseline | aircraftTrack | 20260616T131954/A19A48 | 26 | 12.7977 | 2.64363 | 8.05552 | 1.62655 | 24.8695 | 4.46109 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T131954/A19A48 | 26 | 141.512 | 3.15648 | 58.5617 | 1.78926 | 397.543 | 5.34112 |
| constvel baseline | aircraftTrack | 20260616T131954/A21839 | 89 | 13.0721 | 0.339523 | 9.75563 | 0.139757 | 29.3293 | 0.403532 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T131954/A21839 | 89 | 246.609 | 1.12877 | 67.8169 | 0.219841 | 340.656 | 1.73006 |
| constvel baseline | aircraftTrack | 20260616T131954/A68CD7 | 2 | 8.06151 | 1.06535 | 7.52619 | 0.753315 | 10.4149 | 1.50663 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260616T131954/A68CD7 | 2 | 86.1086 | 0.903604 | 81.5324 | 0.731044 | 109.23 | 1.26215 |

## Metrics By Maneuver Class

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | maneuverClass | constacc_like | 3129 | 8.98969 | 0.941915 | 5.79522 | 0.513964 | 16.4694 | 1.68657 |
| constvel baseline | maneuverClass | constvel_like | 10699 | 9.23008 | 0.458335 | 5.97854 | 0.00498193 | 17.8081 | 0.560023 |
| constvel baseline | maneuverClass | constturn_like | 350 | 34.6967 | 30.8496 | 5.31274 | 1.8126 | 17.295 | 5.56672 |
| constvel baseline | maneuverClass | mixed_or_sparse | 835 | 91.3548 | 7.36406 | 7.98942 | 1.67142 | 57.2392 | 9.38519 |
| Frozen Stage 3A delta MLP | maneuverClass | constacc_like | 3129 | 86.9808 | 0.977307 | 28.0368 | 0.513387 | 184.621 | 1.83909 |
| Frozen Stage 3A delta MLP | maneuverClass | constvel_like | 10699 | 62.3027 | 0.51066 | 25.9494 | 0.168963 | 113.647 | 0.83227 |
| Frozen Stage 3A delta MLP | maneuverClass | constturn_like | 350 | 52.4421 | 30.8305 | 22.6299 | 1.76504 | 78.1956 | 5.54148 |
| Frozen Stage 3A delta MLP | maneuverClass | mixed_or_sparse | 835 | 576.307 | 7.49731 | 53.6556 | 1.88259 | 1334.61 | 10.2662 |

## Metrics By Vertical Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | verticalStatus | level | 5720 | 12.2393 | 5.67094 | 5.27475 | 0.0171721 | 18.4617 | 1.70889 |
| constvel baseline | verticalStatus | climb | 4919 | 18.3945 | 1.87855 | 6.49315 | 0.238067 | 19.4367 | 2.28842 |
| constvel baseline | verticalStatus | descent | 4374 | 37.1392 | 6.45208 | 6.16373 | 0.233137 | 18.0041 | 1.92331 |
| Frozen Stage 3A delta MLP | verticalStatus | level | 5720 | 145.295 | 5.68826 | 18.7068 | 0.178076 | 130.505 | 1.79745 |
| Frozen Stage 3A delta MLP | verticalStatus | climb | 4919 | 173.723 | 1.91002 | 43.151 | 0.340381 | 229.986 | 2.40188 |
| Frozen Stage 3A delta MLP | verticalStatus | descent | 4374 | 130.322 | 6.45715 | 21.223 | 0.282202 | 129.396 | 2.01518 |

## Metrics By Sparse-Update Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | dtRegime | regular_update | 14677 | 10.5226 | 4.84359 | 5.89189 | 0.161214 | 17.5656 | 1.79444 |
| constvel baseline | dtRegime | sparse_update | 336 | 143.607 | 10.7835 | 16.3752 | 1.06591 | 121.662 | 20.6015 |
| Frozen Stage 3A delta MLP | dtRegime | regular_update | 14677 | 67.8144 | 4.84522 | 25.9744 | 0.260465 | 126.537 | 1.81752 |
| Frozen Stage 3A delta MLP | dtRegime | sparse_update | 336 | 906.322 | 11.0244 | 504.337 | 2.00501 | 1905.27 | 20.8654 |

## Representative Track

Selected session: `20260616T131954`

Selected aircraft hex: `ACFE9A`

| sessionID | hex | callsign | pairCount | medianDtSeconds | constvelLikePairCount | constaccLikePairCount | constturnLikePairCount | mixedOrSparsePairCount | climbPairCount | descentPairCount | sparseUpdatePairCount | constvelPositionRMSEMeters | frozenStage3APositionRMSEMeters |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 20260616T131954 | ACFE9A | N9362J | 85 | 0.533 | 63 | 16 | 1 | 5 | 0 | 0 | 1 | 4.3921 | 42.6344 |

## Interpretation

- Stage 3B is an evaluation and data-readiness gate, not a retraining run.
- The frozen Stage 3A MLP is scored on the same samples as `constvel`.
- The current aggregate should not be used for a broad retraining claim unless the readiness gate passes.
- A later retraining or residual-learning experiment should be tracked as a new stage.

## Figures

_No figures were generated._
