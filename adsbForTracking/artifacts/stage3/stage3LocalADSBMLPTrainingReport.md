# Stage 3A Local ADS-B Delta-Target MLP Training Report

Generated: 2026-08-14 20:21:09 UTC

Scope: existing Stage 2B and Stage 2C artifacts only. No new ADS-B data was collected.

## Concept In Plain Language

Stage 3A trains the neural network to predict the one-step change in aircraft state, not the absolute next state. The predicted delta is added back to the previous ADS-B-derived state, so even a weak model stays anchored near the current aircraft instead of drifting toward a dataset-average ENU location.

```matlab
targetDelta = nextState - previousState;
predictedNextState = previousState + predictedDelta;
```

## Native MATLAB Path Used

- Neural training: Deep Learning Toolbox `trainnet` with `trainingOptions("adam")`.
- Native motion baseline: Sensor Fusion and Tracking Toolbox `constvel`.
- Linear sanity baseline: Statistics and Machine Learning Toolbox `fitrlinear` with `fitlm` fallback.
- Metrics and tables: MATLAB `table`, `findgroups`, `splitapply`, `vecnorm`, `mean`, `median`, and `prctile`.
- Plots: MATLAB `figure`, `tiledlayout`, and `nexttile`.

## Inputs

| Artifact | Path |
| :--- | :--- |
| Stage 2B dataset | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2B\localADSBStatePairDataset.mat` |
| Stage 2C maneuver labels | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2C\stage2CManeuverCharacterization.mat` |
| Stage 3A MAT | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\localADSBMLPStage3Training.mat` |
| Stage 3A report | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3LocalADSBMLPTrainingReport.md` |

## Headline RMSE Summary

This table repeats the main `constvel` and Stage 3A delta-MLP aggregate metrics so they are not buried in the baseline ladder.

| method | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | positionP95ErrorMeters |
| :--- | :--- | :--- | :--- | :--- |
| constvel baseline | 9.58791 | 1.01989 | 5.93985 | 17.9101 |
| Stage 3A delta MLP | 131.927 | 0.920472 | 22.5427 | 88.3493 |

## Configuration

| setting | value |
| :--- | :--- |
| DatasetPath | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2B\localADSBStatePairDataset.mat |
| CharacterizationPath | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2C\stage2CManeuverCharacterization.mat |
| OutputFolder | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3 |
| ArtifactPath | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\localADSBMLPStage3Training.mat |
| ReportPath | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3LocalADSBMLPTrainingReport.md |
| Seed | 123 |
| HiddenUnits | 64 |
| TinySampleCount | 64 |
| TinyEpochs | 50 |
| ShortEpochs | 15 |
| LongEpochs | 150 |
| LongSeeds | [123 456 789] |
| MiniBatchSize | 128 |
| LearnRate | 0.001 |
| L2Regularization | 0.0001 |
| VarianceEpsilon | 1e-06 |
| RunCovariancePhase | auto |
| RunLongTraining | false |
| PreflightOnly | false |
| CreatePlots | true |
| ExecutionEnvironment | cpu |
| MeanGateMultiplier | 3 |
| MeanGateAbsoluteToleranceMeters | 25 |
| SaneMaxValidationPositionRMSEMeters | 100 |
| Verbose | true |

## Preflight Audit

Preflight completed before neural training. The audit checked finite arrays, split counts, target-delta scale, feature standard deviations, maneuver labels, vertical-status labels, sparse-update labels, and `constvel` split metrics.

| checkName | passed |
| :--- | :--- |
| previousState | 1 |
| nextState | 1 |
| dtSeconds | 1 |
| previousCovarianceDiag | 1 |
| targetDelta | 1 |
| maneuverPairTable | 1 |

### Split Counts

| split | GroupCount |
| :--- | :--- |
| test | 461 |
| train | 1144 |
| validation | 124 |

### Split By Maneuver Class

| split | maneuverClass | pairCount |
| :--- | :--- | :--- |
| test | constacc_like | 122 |
| test | constvel_like | 324 |
| test | mixed_or_sparse | 15 |
| train | constacc_like | 197 |
| train | constturn_like | 31 |
| train | constvel_like | 887 |
| train | mixed_or_sparse | 29 |
| validation | constacc_like | 26 |
| validation | constvel_like | 89 |
| validation | mixed_or_sparse | 9 |

### Split By Vertical Status

| split | verticalStatus | pairCount |
| :--- | :--- | :--- |
| test | climb | 319 |
| test | descent | 121 |
| test | level | 21 |
| train | climb | 219 |
| train | descent | 244 |
| train | level | 681 |
| validation | climb | 124 |

### Sparse Update Counts

| split | dtRegime | pairCount |
| :--- | :--- | :--- |
| test | regular_update | 448 |
| test | sparse_update | 13 |
| train | regular_update | 1130 |
| train | sparse_update | 14 |
| validation | regular_update | 115 |
| validation | sparse_update | 9 |

### Constvel Metrics By Split

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel baseline | split | train | 1144 | 9.92586 | 1.14981 | 6.05612 | 0.0761877 | 19.4256 | 1.6689 |
| constvel baseline | split | test | 461 | 7.90492 | 0.517316 | 5.58731 | 0.000641904 | 12.6159 | 0.775978 |
| constvel baseline | split | validation | 124 | 11.8548 | 1.14529 | 6.97358 | 0.164659 | 20.1964 | 2.14549 |

### Target Delta Statistics

| component | mean | std | min | median | max |
| :--- | :--- | :--- | :--- | :--- | :--- |
| x | -63.5135 | 252.01 | -4255.18 | -36.5027 | 2355.53 |
| vx | -0.0731205 | 0.619254 | -12.8916 | 0 | 4.74227 |
| y | -27.0488 | 178.106 | -3453.63 | -20.0872 | 1941.21 |
| vy | 0.0288875 | 0.768713 | -8.93408 | 0 | 13.6698 |
| z | 0.976857 | 8.52038 | -90.3311 | -0.0922931 | 109.11 |
| vz | -0.00024504 | 0.245337 | -2.25169 | 0 | 3.13298 |

### Feature Standard Deviations

| featureMode | featureName | trainStdBeforeGuard | trainStdUsed | constantFeature |
| :--- | :--- | :--- | :--- | :--- |
| raw_motion | vx | 125.849 | 125.849 | 0 |
| raw_motion | vy | 82.6233 | 82.6233 | 0 |
| raw_motion | z | 4033.76 | 4033.76 | 0 |
| raw_motion | vz | 5.01307 | 5.01307 | 0 |
| raw_motion | dtSeconds | 1.4168 | 1.4168 | 0 |
| raw_motion | previousCovarianceDiag_x | 0 | 1 | 1 |
| raw_motion | previousCovarianceDiag_vx | 0 | 1 | 1 |
| raw_motion | previousCovarianceDiag_y | 0 | 1 | 1 |
| raw_motion | previousCovarianceDiag_vy | 0 | 1 | 1 |
| raw_motion | previousCovarianceDiag_z | 0 | 1 | 1 |
| raw_motion | previousCovarianceDiag_vz | 0 | 1 | 1 |
| physics_derived_delta | vx | 125.849 | 125.849 | 0 |
| physics_derived_delta | vy | 82.6233 | 82.6233 | 0 |
| physics_derived_delta | z | 4033.76 | 4033.76 | 0 |
| physics_derived_delta | vz | 5.01307 | 5.01307 | 0 |
| physics_derived_delta | dtSeconds | 1.4168 | 1.4168 | 0 |
| physics_derived_delta | previousCovarianceDiag_x | 0 | 1 | 1 |
| physics_derived_delta | previousCovarianceDiag_vx | 0 | 1 | 1 |
| physics_derived_delta | previousCovarianceDiag_y | 0 | 1 | 1 |
| physics_derived_delta | previousCovarianceDiag_vy | 0 | 1 | 1 |
| physics_derived_delta | previousCovarianceDiag_z | 0 | 1 | 1 |
| physics_derived_delta | previousCovarianceDiag_vz | 0 | 1 | 1 |
| physics_derived_delta | vxTimesDt | 189.618 | 189.618 | 0 |
| physics_derived_delta | vyTimesDt | 165.414 | 165.414 | 0 |
| physics_derived_delta | vzTimesDt | 6.22978 | 6.22978 | 0 |
| physics_derived_delta | constvelDelta_x | 189.618 | 189.618 | 0 |
| physics_derived_delta | constvelDelta_vx | 0 | 1 | 1 |
| physics_derived_delta | constvelDelta_y | 165.414 | 165.414 | 0 |
| physics_derived_delta | constvelDelta_vy | 0 | 1 | 1 |
| physics_derived_delta | constvelDelta_z | 6.22978 | 6.22978 | 0 |
| physics_derived_delta | constvelDelta_vz | 0 | 1 | 1 |

### Covariance Interface Note

The Stage 2B artifact has 1 unique `previousCovarianceDiag` row. It is retained for interface compatibility, but it has no training variation in this artifact.

## Baseline Ladder

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| zero-delta persistence | all | all | 1729 | 316.251 | 1.01989 | 93.3354 | 0.0653882 | 415.912 | 1.57284 |
| train-mean delta | all | all | 1729 | 308.954 | 1.01773 | 118.673 | 0.0712194 | 394.123 | 1.54776 |
| constvel baseline | all | all | 1729 | 9.58791 | 1.01989 | 5.93985 | 0.0653882 | 17.9101 | 1.57284 |
| linear delta regression | all | all | 1729 | 9.92168 | 0.982554 | 6.08981 | 0.28947 | 18.1475 | 1.63421 |

## Training Ladder Status

| rung | status | details |
| :--- | :--- | :--- |
| preflight_audit | completed | Finite checks, target stats, split counts, and constvel split metrics completed. |
| baselines | completed | Zero-delta, train-mean delta, constvel, and linear delta baselines completed. |
| tiny_overfit | passed | Tiny epochs: 50, final loss: 0.159951. |
| short_full_mean_only | did_not_pass | Short epochs: 15, mean gate: short mean-only model did not pass the constvel-nearness gate. |
| feature_ablation | completed | Raw motion features and physics-derived delta features were both trained. |
| covariance_phase | skipped | skipped |
| long_run | skipped_by_default | skipped_by_default |

## Feature Ablation

| featureMode | allPositionRMSEMeters | validationPositionRMSEMeters | testPositionRMSEMeters |
| :--- | :--- | :--- | :--- |
| raw_motion | 226.789 | 597.924 | 255.649 |
| physics_derived_delta | 131.927 | 402.293 | 124.714 |

## Final Delta MLP Metrics

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stage 3A delta MLP | all | all | 1729 | 131.927 | 0.920472 | 22.5427 | 0.15023 | 88.3493 | 1.52765 |

### Metrics By Split

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stage 3A delta MLP | split | train | 1144 | 49.952 | 0.95832 | 15.9567 | 0.140107 | 67.7818 | 1.5641 |
| Stage 3A delta MLP | split | test | 461 | 124.714 | 0.529545 | 36.5751 | 0.140971 | 129.887 | 0.846525 |
| Stage 3A delta MLP | split | validation | 124 | 402.293 | 1.51612 | 48.2783 | 0.212357 | 890.612 | 3.7591 |

### Metrics By Maneuver Class

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stage 3A delta MLP | maneuverClass | constvel_like | 1300 | 36.4331 | 0.391967 | 21.9692 | 0.107011 | 57.0206 | 0.46868 |
| Stage 3A delta MLP | maneuverClass | mixed_or_sparse | 53 | 699.341 | 3.08625 | 203.276 | 1.77215 | 1693.86 | 7.76616 |
| Stage 3A delta MLP | maneuverClass | constacc_like | 345 | 82.8618 | 0.761825 | 21.0142 | 0.41223 | 170.89 | 1.48706 |
| Stage 3A delta MLP | maneuverClass | constturn_like | 31 | 49.9508 | 4.25079 | 42.9681 | 1.77615 | 96.1223 | 11.611 |

### Metrics By Vertical Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stage 3A delta MLP | verticalStatus | level | 702 | 64.7665 | 0.526859 | 14.7129 | 0.0911563 | 44.7893 | 0.907973 |
| Stage 3A delta MLP | verticalStatus | descent | 365 | 63.7125 | 0.681229 | 12.5801 | 0.23927 | 66.7664 | 1.40289 |
| Stage 3A delta MLP | verticalStatus | climb | 662 | 196.904 | 1.28944 | 40.9746 | 0.165488 | 159.681 | 2.29143 |

### Metrics By Sparse-Update Status

| method | groupVariable | groupName | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stage 3A delta MLP | dtRegime | regular_update | 1693 | 49.8425 | 0.795436 | 21.9494 | 0.145087 | 66.4748 | 1.32256 |
| Stage 3A delta MLP | dtRegime | sparse_update | 36 | 847.987 | 3.30712 | 482.385 | 1.48965 | 1751.67 | 8.23612 |

## Interpretation

- The required comparator remains native `constvel`.
- If the Stage 3A MLP does not beat `constvel`, that is a training and data diagnostic, not a reason to tune around the result.
- Current split behavior is not behavior-balanced: `constturn_like` is absent from validation/test in the present artifact, and the validation split is dominated by climb behavior.
- The current data is not enough for broad maneuver-learning claims. It lacks turn, acceleration, climb/descent, sparse-update, session, and traffic diversity.

## Figures

- trainingLoss: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3A_training_loss.png`
- errorComparison: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3A_constvel_vs_mlp_error.png`
- maneuverMetrics: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3A_maneuver_class_metrics.png`
- trajectoryComparison: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\stage3A_trajectory_comparison.png`
