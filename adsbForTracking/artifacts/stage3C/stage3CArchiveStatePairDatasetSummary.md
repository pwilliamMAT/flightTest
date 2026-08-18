# Stage 2B Local ADS-B Smoke Pipeline Summary

Generated: 2026-08-18 13:31:46 UTC

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
| Raw source files | 16 |
| Parsed files | 16 |
| Parsed aircraft tracks | 253 |
| Valid ADS-B state samples | 15263 |
| Usable one-step pairs | 15013 |
| Duplicate timestamps removed | 0 |
| Adjacent candidate pairs | 15311 |
| Rejected nonfinite endpoint pairs | 280 |
| Rejected nonpositive dt pairs | 0 |
| Rejected dt > max pairs | 18 |

## dt Statistics

| Statistic | dt [s] |
| :--- | ---: |
| Count | 15013 |
| Min | 0.399 |
| P25 | 0.495 |
| Median | 0.585 |
| P75 | 1.030 |
| Max | 29.651 |

## Split Summary

| split | GroupCount |
| :--- | :--- |
| test | 2082 |
| train | 10272 |
| validation | 2659 |

- Split policy: `aircraft_level_70_15_15_smoke`.
- Split seed: 42.
- Leakage check passed: 1.
- Aircraft split check passed: 1.

## Baseline Constvel Metrics

| Metric | Value |
| :--- | ---: |
| Samples | 15013 |
| Position RMSE [m] | 23.870 |
| Velocity RMSE [m/s] | 5.053 |
| Position median error [m] | 5.984 |
| Velocity median error [m/s] | 0.167 |
| Position P95 error [m] | 18.713 |
| Velocity P95 error [m/s] | 1.958 |

## Smoke Training Status

MLP smoke training has not been run for this report yet.
## Artifacts

- Dataset MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3C\stage3CArchiveStatePairDataset.mat`
