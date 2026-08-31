# Stage 2B Local ADS-B Smoke Pipeline Summary

Generated: 2026-08-26 21:08:31 UTC

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
| Raw source files | 159 |
| Parsed files | 159 |
| Parsed aircraft tracks | 3411 |
| Valid ADS-B state samples | 462838 |
| Usable one-step pairs | 457903 |
| Duplicate timestamps removed | 0 |
| Adjacent candidate pairs | 463510 |
| Rejected nonfinite endpoint pairs | 3918 |
| Rejected nonpositive dt pairs | 0 |
| Rejected dt > max pairs | 1689 |

## dt Statistics

| Statistic | dt [s] |
| :--- | ---: |
| Count | 457903 |
| Min | 0.385 |
| P25 | 0.505 |
| Median | 0.873 |
| P75 | 1.060 |
| Max | 29.998 |

## Split Summary

| split | GroupCount |
| :--- | :--- |
| test | 70738 |
| train | 321448 |
| validation | 65717 |

- Split policy: `aircraft_level_70_15_15_smoke`.
- Split seed: 42.
- Leakage check passed: 1.
- Aircraft split check passed: 1.

## Baseline Constvel Metrics

| Metric | Value |
| :--- | ---: |
| Samples | 457903 |
| Position RMSE [m] | 24.520 |
| Velocity RMSE [m/s] | 3.918 |
| Position median error [m] | 5.879 |
| Velocity median error [m/s] | 0.170 |
| Position P95 error [m] | 19.772 |
| Velocity P95 error [m/s] | 2.224 |

## Smoke Training Status

MLP smoke training has not been run for this report yet.
## Artifacts

- Dataset MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4BPostCampaign\expanded_post3day_v2\stage3CArchiveStatePairDataset.mat`
