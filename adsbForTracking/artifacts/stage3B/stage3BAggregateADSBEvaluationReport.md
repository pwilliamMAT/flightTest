# Stage 3B Aggregate ADS-B Evaluation Report

Generated: 2026-08-17 20:28:16 UTC

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
| Stage 3B aggregate dataset | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\localADSBAggregateStatePairDataset.mat` |
| Stage 3B dataset summary | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3BAggregateStatePairDatasetSummary.md` |
| Frozen Stage 3A artifact | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\localADSBMLPStage3Training.mat` |
| Stage 3B MAT artifact | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\localADSBAggregateStage3BEvaluation.mat` |
| Stage 3B report | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3BAggregateADSBEvaluationReport.md` |

## Headline Aggregate Comparison

| method | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | positionP95ErrorMeters | interpretation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | 1729 | 9.58791 | 1.01989 | 5.93985 | 17.9101 | Native Sensor Fusion constant-velocity prediction on the exact Stage 3B samples. |
| Frozen Stage 3A delta MLP | 1729 | 131.927 | 0.920472 | 22.5427 | 88.3493 | Frozen Stage 3A delta-target MLP reconstructed as previousState + predictedDelta. |

## Data Inventory

| sourceFile | fileExists | fileSizeBytes | modifiedTime | parseStatus | usedInDataset | usablePairCount | sessionID |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C:\Users\pwilliam\agenticProjects\flightTest\BistaticDataAnalysis\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1 | 139744 | 26-Jun-2026 12:22:11 | parsed | 1 | 1729 | 20260622T102123 |

## Data Readiness Gate

Not ready for retraining. Stage 3B found 1 ADS-B session(s) and 1 usable truth file(s); collect more local SBS-1 ADS-B sessions first.

| gate | observedValue | requiredValue | passed | details |
| :--- | :--- | :--- | :--- | :--- |
| distinct ADS-B sessions | 1 | 3 | 0 | Observed 1; need at least 3 before retraining. |
| local truth files used | 1 | 3 | 0 | Observed 1; need at least 3 before retraining. |
| distinct aircraft tracks | 17 | 20 | 0 | Observed 17; need at least 20 before retraining. |
| non-constvel maneuver classes | 3 | 2 | 1 | Observed 3; requirement met. |
| constacc-like pairs | 345 | 100 | 1 | Observed 345; requirement met. |
| constturn-like pairs | 31 | 100 | 0 | Observed 31; need at least 100 before retraining. |
| sparse-update pairs | 36 | 100 | 0 | Observed 36; need at least 100 before retraining. |
| climb pairs | 662 | 100 | 1 | Observed 662; requirement met. |
| descent pairs | 365 | 100 | 1 | Observed 365; requirement met. |

## Verification Checks

| check | passed | details |
| :--- | :--- | :--- |
| frozen delta reconstruction | 1 | max abs reconstruction error = 0 |
| same sample count for constvel and MLP | 1 | constvel rows = 1729, MLP rows = 1729 |
| finite frozen MLP predictions | 1 | finite prediction rows = 1729 |
| all aggregate metrics use dataset row count | 1 | dataset rows = 1729 |

## Metrics By Session

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | sessionID | 20260622T102123 | 1729 | 9.58791 | 1.01989 | 5.93985 | 0.0653882 | 17.9101 | 1.57284 |
| Frozen Stage 3A delta MLP | sessionID | 20260622T102123 | 1729 | 131.927 | 0.920472 | 22.5427 | 0.15023 | 88.3493 | 1.52765 |

## Metrics By Source File

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\BistaticDataAnalysis\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1729 | 9.58791 | 1.01989 | 5.93985 | 0.0653882 | 17.9101 | 1.57284 |
| Frozen Stage 3A delta MLP | sourceFile | C:\Users\pwilliam\agenticProjects\flightTest\BistaticDataAnalysis\captures\20260622T102123\truth\0_20260622_102124_adsb_20260622T102123.txt.gz | 1729 | 131.927 | 0.920472 | 22.5427 | 0.15023 | 88.3493 | 1.52765 |

## Metrics By Aircraft Track

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | aircraftTrack | 20260622T102123/44046E | 125 | 15.3255 | 0.938992 | 10.5483 | 0.0556693 | 29.3892 | 3.18609 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/44046E | 125 | 25.9485 | 0.927435 | 23.6758 | 0.147276 | 36.7645 | 3.09322 |
| constvel baseline | aircraftTrack | 20260622T102123/71C217 | 9 | 16.8977 | 0.656403 | 6.84409 | 0.0493109 | 47.3792 | 1.8238 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/71C217 | 9 | 304.537 | 1.01575 | 68.6023 | 0.406861 | 723.531 | 2.77645 |
| constvel baseline | aircraftTrack | 20260622T102123/A00D5B | 82 | 12.6383 | 1.38687 | 6.62421 | 0.2671 | 25.2053 | 3.50485 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A00D5B | 82 | 435.746 | 1.77462 | 49.5057 | 0.227838 | 1095.35 | 4.2889 |
| constvel baseline | aircraftTrack | 20260622T102123/A075DF | 216 | 9.84354 | 0.657458 | 7.09162 | 0.251749 | 18.394 | 1.32934 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A075DF | 216 | 23.3443 | 0.645513 | 11.3324 | 0.238936 | 29.5024 | 1.34189 |
| constvel baseline | aircraftTrack | 20260622T102123/A14104 | 2 | 42.187 | 0.205363 | 36.2699 | 0.16256 | 57.816 | 0.288052 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A14104 | 2 | 685.857 | 0.670924 | 540.278 | 0.586982 | 962.771 | 0.911929 |
| constvel baseline | aircraftTrack | 20260622T102123/A1CFDC | 33 | 12.1988 | 3.08713 | 8.67245 | 1.1586 | 25.6557 | 5.8763 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A1CFDC | 33 | 91.2716 | 2.70183 | 48.6767 | 1.13836 | 218.532 | 5.37676 |
| constvel baseline | aircraftTrack | 20260622T102123/A26DFB | 28 | 11.5123 | 0.568918 | 6.18002 | 0.125741 | 28.4189 | 1.51067 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A26DFB | 28 | 42.8535 | 0.568151 | 16.5894 | 0.280232 | 112.138 | 1.2337 |
| constvel baseline | aircraftTrack | 20260622T102123/A38439 | 112 | 10.285 | 0.858969 | 7.02125 | 0.279004 | 15.8239 | 1.72367 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A38439 | 112 | 65.3166 | 0.738351 | 12.5855 | 0.227186 | 71.6419 | 1.47421 |
| constvel baseline | aircraftTrack | 20260622T102123/A3EBD8 | 311 | 4.75732 | 0.363018 | 4.13276 | 0 | 8.47443 | 0.603863 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A3EBD8 | 311 | 14.2397 | 0.368371 | 13.1899 | 0.0574205 | 18.2565 | 0.609146 |
| constvel baseline | aircraftTrack | 20260622T102123/A4F26B | 42 | 10.1526 | 0.342601 | 8.0259 | 0.0813782 | 18.5774 | 0.732917 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A4F26B | 42 | 327.27 | 0.79863 | 43.4916 | 0.188136 | 719.872 | 1.73287 |
| constvel baseline | aircraftTrack | 20260622T102123/A60E95 | 59 | 5.9467 | 0.485368 | 4.78048 | 0 | 10.234 | 1.23663 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A60E95 | 59 | 12.7386 | 0.499817 | 9.12725 | 0.0974789 | 25.7215 | 1.26696 |
| constvel baseline | aircraftTrack | 20260622T102123/A6CB01 | 36 | 10.8447 | 0.831176 | 8.39113 | 0.294112 | 22.1384 | 1.5241 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A6CB01 | 36 | 386.568 | 1.10614 | 77.6896 | 0.420366 | 961.315 | 2.9298 |
| constvel baseline | aircraftTrack | 20260622T102123/A862F2 | 304 | 5.77984 | 0.198561 | 5.21524 | 0 | 9.39949 | 0.514444 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A862F2 | 304 | 39.6538 | 0.22125 | 39.1227 | 0.113143 | 49.743 | 0.469765 |
| constvel baseline | aircraftTrack | 20260622T102123/A9C380 | 158 | 11.7794 | 0.143194 | 7.55909 | 0 | 24.3828 | 0.331587 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/A9C380 | 158 | 28.641 | 0.150501 | 16.2642 | 0.0238181 | 67.9095 | 0.32987 |
| constvel baseline | aircraftTrack | 20260622T102123/AC11EA | 29 | 7.71753 | 0.707067 | 3.30453 | 0.176599 | 9.0486 | 1.01897 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/AC11EA | 29 | 153.467 | 0.561008 | 34.0008 | 0.342763 | 250.063 | 1.35635 |
| constvel baseline | aircraftTrack | 20260622T102123/AD7B4D | 145 | 8.81815 | 0.413896 | 7.72778 | 0.221799 | 14.1537 | 0.657705 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/AD7B4D | 145 | 46.9508 | 0.41362 | 38.236 | 0.225072 | 76.1185 | 0.707633 |
| constvel baseline | aircraftTrack | 20260622T102123/ADCD6D | 38 | 12.7633 | 4.83338 | 5.3842 | 1.53228 | 31.7236 | 11.7469 |
| Frozen Stage 3A delta MLP | aircraftTrack | 20260622T102123/ADCD6D | 38 | 68.9437 | 3.65561 | 53.1278 | 1.34884 | 111.555 | 8.8709 |

## Metrics By Maneuver Class

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | maneuverClass | constvel_like | 1300 | 8.90865 | 0.379784 | 5.86911 | 0 | 16.4515 | 0.461605 |
| constvel baseline | maneuverClass | mixed_or_sparse | 53 | 23.174 | 2.93388 | 13.5988 | 1.67468 | 56.8963 | 5.84375 |
| constvel baseline | maneuverClass | constacc_like | 345 | 7.57523 | 0.751458 | 5.78638 | 0.460292 | 13.712 | 1.4181 |
| constvel baseline | maneuverClass | constturn_like | 31 | 15.5645 | 5.56464 | 7.69582 | 2.88799 | 40.4214 | 14.918 |
| Frozen Stage 3A delta MLP | maneuverClass | constvel_like | 1300 | 36.4331 | 0.391967 | 21.9692 | 0.107011 | 57.0206 | 0.46868 |
| Frozen Stage 3A delta MLP | maneuverClass | mixed_or_sparse | 53 | 699.341 | 3.08625 | 203.276 | 1.77215 | 1693.86 | 7.76616 |
| Frozen Stage 3A delta MLP | maneuverClass | constacc_like | 345 | 82.8618 | 0.761825 | 21.0142 | 0.41223 | 170.89 | 1.48706 |
| Frozen Stage 3A delta MLP | maneuverClass | constturn_like | 31 | 49.9508 | 4.25079 | 42.9681 | 1.77615 | 96.1223 | 11.611 |

## Metrics By Vertical Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | verticalStatus | level | 702 | 9.78351 | 0.533361 | 5.21309 | 0 | 20.923 | 0.905372 |
| constvel baseline | verticalStatus | descent | 365 | 10.3444 | 0.719481 | 6.98401 | 0.248406 | 18.9675 | 1.51306 |
| constvel baseline | verticalStatus | climb | 662 | 8.92165 | 1.45932 | 5.8491 | 0.132074 | 14.035 | 2.39296 |
| Frozen Stage 3A delta MLP | verticalStatus | level | 702 | 64.7665 | 0.526859 | 14.7129 | 0.0911563 | 44.7893 | 0.907973 |
| Frozen Stage 3A delta MLP | verticalStatus | descent | 365 | 63.7125 | 0.681229 | 12.5801 | 0.23927 | 66.7664 | 1.40289 |
| Frozen Stage 3A delta MLP | verticalStatus | climb | 662 | 196.904 | 1.28944 | 40.9746 | 0.165488 | 159.681 | 2.29143 |

## Metrics By Sparse-Update Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | dtRegime | regular_update | 1693 | 8.82128 | 0.93438 | 5.85202 | 0.0493016 | 16.158 | 1.29326 |
| constvel baseline | dtRegime | sparse_update | 36 | 27.4888 | 2.98305 | 19.3458 | 1.23782 | 57.5944 | 6.14126 |
| Frozen Stage 3A delta MLP | dtRegime | regular_update | 1693 | 49.8425 | 0.795436 | 21.9494 | 0.145087 | 66.4748 | 1.32256 |
| Frozen Stage 3A delta MLP | dtRegime | sparse_update | 36 | 847.987 | 3.30712 | 482.385 | 1.48965 | 1751.67 | 8.23612 |

## Representative Track

Selected session: `20260622T102123`

Selected aircraft hex: `A3EBD8`

| sessionID | hex | callsign | pairCount | medianDtSeconds | constvelLikePairCount | constaccLikePairCount | constturnLikePairCount | mixedOrSparsePairCount | climbPairCount | descentPairCount | sparseUpdatePairCount | constvelPositionRMSEMeters | frozenStage3APositionRMSEMeters |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 20260622T102123 | A3EBD8 | N3517G | 311 | 0.497 | 235 | 63 | 9 | 4 | 3 | 0 | 0 | 4.75732 | 14.2397 |

## Interpretation

- Stage 3B is an evaluation and data-readiness gate, not a retraining run.
- The frozen Stage 3A MLP is scored on the same samples as `constvel`.
- The current aggregate should not be used for a broad retraining claim unless the readiness gate passes.
- A later retraining or residual-learning experiment should be tracked as a new stage.

## Figures

- aggregateError: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3B_constvel_vs_frozen_mlp_error.png`
- positionAbsError: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3B_position_abs_error.png`
- groupMetrics: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3B_grouped_position_rmse.png`
- readinessGates: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3B_data_readiness_gates.png`
- trajectoryComparison: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3B\stage3B_trajectory_comparison.png`
