# Stage 2B Local ADS-B Smoke Pipeline Summary

Generated: 2026-08-14 02:35:22 UTC

Scope: local ADS-B dataset construction, `constvel` baseline scoring, and minimal MLP smoke training only. This is not a final model-quality claim.

## Concept In Plain Language

Each ADS-B aircraft track is converted from latitude, longitude, and altitude into local east-north-up meters around the receiver. Adjacent samples from the same aircraft become one-step training examples: the model receives the previous state, assumed covariance diagonal, and elapsed time, then predicts the next state and diagonal uncertainty.

## Native MATLAB Path Used

- Parser: existing `loadADSBTruth` from `BistaticDataAnalysis`.
- Coordinate conversion: Mapping Toolbox `wgs84Ellipsoid` and `geodetic2enu`.
- State convention: Sensor Fusion `[x; vx; y; vy; z; vz]`.
- Baseline: Sensor Fusion and Tracking Toolbox `constvel`.
- Smoke model: Deep Learning Toolbox `dlnetwork` with diagonal Gaussian NLL.

## Dataset Summary

| Metric | Value |
| :--- | ---: |
| Raw source files | 1 |
| Parsed files | 1 |
| Parsed aircraft tracks | 21 |
| Valid ADS-B state samples | 1751 |
| Usable one-step pairs | 1729 |
| Duplicate timestamps removed | 0 |
| Adjacent candidate pairs | 1759 |
| Rejected nonfinite endpoint pairs | 26 |
| Rejected nonpositive dt pairs | 0 |
| Rejected dt > max pairs | 4 |

## dt Statistics

| Statistic | dt [s] |
| :--- | ---: |
| Count | 1729 |
| Min | 0.399 |
| P25 | 0.490 |
| Median | 0.580 |
| P75 | 1.006 |
| Max | 27.721 |

## Split Summary

| split | GroupCount |
| :--- | :--- |
| test | 461 |
| train | 1144 |
| validation | 124 |

- Split policy: `aircraft_level_70_15_15_smoke`.
- Split seed: 42.
- Leakage check passed: 1.
- Aircraft split check passed: 1.

## Baseline Constvel Metrics

| Metric | Value |
| :--- | ---: |
| Samples | 1729 |
| Position RMSE [m] | 9.588 |
| Velocity RMSE [m/s] | 1.020 |
| Position median error [m] | 5.940 |
| Velocity median error [m/s] | 0.065 |
| Position P95 error [m] | 17.910 |
| Velocity P95 error [m/s] | 1.573 |

## Smoke Training Status

| Metric | Value |
| :--- | ---: |
| Epochs | 3 |
| Final loss | 0.365376 |
| Finite loss | 1 |
| Output rows | 1729 |
| Output columns | 12 |
| Strictly positive predicted variances | 1 |
| Minimum predicted variance | 0.111578 |
| Model position RMSE [m] | 37183.211 |
| Model velocity RMSE [m/s] | 108.078 |
| Empirical 1-sigma coverage | 0.666 |
| Empirical 2-sigma coverage | 0.939 |

## Artifacts

- Dataset MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2B\localADSBStatePairDataset.mat`
- Training MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2B\localADSBMLPSmokeTraining.mat`
