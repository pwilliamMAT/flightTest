# Stage 2B Local ADS-B Smoke Pipeline Summary

Generated: 2026-08-26 20:41:19 UTC

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
| Raw source files | 143 |
| Parsed files | 143 |
| Parsed aircraft tracks | 3158 |
| Valid ADS-B state samples | 447575 |
| Usable one-step pairs | 442890 |
| Duplicate timestamps removed | 0 |
| Adjacent candidate pairs | 448199 |
| Rejected nonfinite endpoint pairs | 3638 |
| Rejected nonpositive dt pairs | 0 |
| Rejected dt > max pairs | 1671 |

## dt Statistics

| Statistic | dt [s] |
| :--- | ---: |
| Count | 442890 |
| Min | 0.385 |
| P25 | 0.506 |
| Median | 0.879 |
| P75 | 1.062 |
| Max | 29.998 |

## Split Summary

| split | GroupCount |
| :--- | :--- |
| test | 66746 |
| train | 306289 |
| validation | 69855 |

- Split policy: `aircraft_level_70_15_15_smoke`.
- Split seed: 42.
- Leakage check passed: 1.
- Aircraft split check passed: 1.

## Baseline Constvel Metrics

| Metric | Value |
| :--- | ---: |
| Samples | 442890 |
| Position RMSE [m] | 24.542 |
| Velocity RMSE [m/s] | 3.873 |
| Position median error [m] | 5.876 |
| Velocity median error [m/s] | 0.170 |
| Position P95 error [m] | 19.816 |
| Velocity P95 error [m/s] | 2.233 |

## Smoke Training Status

MLP smoke training has not been run for this report yet.
## Artifacts

- Dataset MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4BPostCampaign\campaign_3day_increment_v1\stage3CArchiveStatePairDataset.mat`
