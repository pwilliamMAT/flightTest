# Stage 2C Maneuver-Aware Characterization Report

Generated: 2026-08-14 14:43:08 UTC

Scope: existing Stage 2B state-pair artifact only. No new ADS-B data was collected, and no neural model was trained for this stage.

## Direct Answer

No. The existing artifact is useful for software checks and stratified baseline reporting, but it does not contain enough maneuver diversity for a defensible claim beyond `constvel`. It is 75.2% constvel-like, 20.0% constacc-like, 1.8% constturn-like, and 3.1% mixed or sparse; only 31 pairs reach the constturn-like label and 0 pairs reach the 3 deg/s standard-rate turn threshold.

## Concept In Plain Language

A constant-velocity predictor should work well when an aircraft keeps the same speed, heading, and vertical rate between two ADS-B updates. Stage 2C checks whether the existing pairs contain enough departures from that behavior to teach or evaluate anything more interesting. It derives heading change from the velocity-vector direction, speed change from horizontal speed magnitude, vertical-rate change from `vz`, climb/descent status from `vz`, and sparse-update status from `dtSeconds`.

## Native MATLAB Path Used

- Heading wrap: Mapping Toolbox `wrapTo180`.
- Magnitudes: MATLAB `vecnorm`.
- Grouping and counts: MATLAB `categorical`, `countcats`, `findgroups`, and `splitapply`.
- Baseline: Sensor Fusion and Tracking Toolbox `constvel` through `helperScoreConstVelBaseline`.

## Input Artifact

| Metric | Value |
| :--- | ---: |
| Dataset path | `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2B\localADSBStatePairDataset.mat` |
| State pairs | 1729 |
| Aircraft tracks | 17 |
| Median dt [s] | 0.580 |
| Aggregate constvel position RMSE [m] | 9.588 |
| Aggregate constvel velocity RMSE [m/s] | 1.020 |

## Threshold Labels

| threshold | value |
| :--- | :--- |
| headingChangeDegrees | 0.5 |
| turnRateDegreesPerSecond | 1 |
| speedChangeMetersPerSecond | 0.5 |
| horizontalAccelerationMetersPerSecondSquared | 0.5 |
| verticalRateChangeMetersPerSecond | 0.5 |
| verticalAccelerationMetersPerSecondSquared | 0.5 |
| climbRateMetersPerSecond | 1 |
| sparseUpdateSeconds | 5 |
| minimumHorizontalSpeedMetersPerSecond | 1 |

## Maneuver-Class Counts

| maneuverClass | pairCount | percent |
| :--- | :--- | :--- |
| constvel_like | 1300 | 75.188 |
| constacc_like | 345 | 19.9537 |
| constturn_like | 31 | 1.7929 |
| mixed_or_sparse | 53 | 3.0654 |

## Climb And Descent Counts

| verticalStatus | pairCount | percent |
| :--- | :--- | :--- |
| descent | 365 | 21.1105 |
| level | 702 | 40.6015 |
| climb | 662 | 38.288 |

## Sparse-Update Counts

| dtRegime | pairCount | percent |
| :--- | :--- | :--- |
| regular_update | 1693 | 97.9179 |
| sparse_update | 36 | 2.0821 |

## Constvel Baseline By Maneuver Class

| maneuverClass | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| constvel_like | 1300 | 8.9087 | 0.37978 | 5.8691 | 0 | 16.4515 | 0.46161 |
| constacc_like | 345 | 7.5752 | 0.75146 | 5.7864 | 0.46029 | 13.712 | 1.4181 |
| constturn_like | 31 | 15.5645 | 5.5646 | 7.6958 | 2.888 | 40.4214 | 14.918 |
| mixed_or_sparse | 53 | 23.174 | 2.9339 | 13.5988 | 1.6747 | 56.8963 | 5.8437 |

## Per-Track Summary

The table is sorted by pair count. Counts are pair counts, not raw ADS-B message counts.

| sessionID | hex | callsign | pairCount | medianDtSeconds | maxAbsTurnRateDegreesPerSecond | maxAbsHorizontalAccelerationMetersPerSecondSquared | maxAbsVerticalAccelerationMetersPerSecondSquared | constvelLikePairCount | constaccLikePairCount | constturnLikePairCount | mixedOrSparsePairCount | climbPairCount | descentPairCount |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 20260622T102123 | A3EBD8 | N3517G | 311 | 0.497 | 2.4213 | 1.2765 | 0.80675 | 235 | 63 | 9 | 4 | 3 | 0 |
| 20260622T102123 | A862F2 | OPN64 | 304 | 0.5035 | 0 | 1.2578 | 0.81077 | 232 | 72 | 0 | 0 | 304 | 0 |
| 20260622T102123 | A075DF | RPA4687 | 216 | 0.539 | 1.9 | 1.1356 | 1.9278 | 129 | 79 | 2 | 6 | 0 | 216 |
| 20260622T102123 | A9C380 | RPA3465 | 158 | 0.9755 | 1.5248e-14 | 0.4664 | 0.35632 | 157 | 1 | 0 | 0 | 0 | 0 |
| 20260622T102123 | AD7B4D | EJA968 | 145 | 1.004 | 0.87417 | 0.51755 | 0.5849 | 133 | 12 | 0 | 0 | 145 | 0 |
| 20260622T102123 | 44046E | GCK17 | 125 | 1.011 | 0.92536 | 0.53564 | 0.28271 | 120 | 4 | 0 | 1 | 0 | 0 |
| 20260622T102123 | A38439 | JBU1286 | 112 | 0.56 | 1.5457 | 1.1483 | 2.2101 | 65 | 41 | 0 | 6 | 0 | 112 |
| 20260622T102123 | A00D5B | AAL1277 | 82 | 0.8605 | 0.5685 | 0.9042 | 0.69313 | 51 | 25 | 0 | 6 | 82 | 0 |
| 20260622T102123 | A60E95 | N49JP | 59 | 0.544 | 1.0309 | 0.53036 | 0.68159 | 53 | 4 | 0 | 2 | 0 | 0 |
| 20260622T102123 | A4F26B | LXJ418 | 42 | 1.0525 | 0 | 0.42259 | 0.29174 | 38 | 1 | 0 | 3 | 42 | 0 |
| 20260622T102123 | ADCD6D | JBU1833 | 38 | 1.0205 | 2.1772 | 0.93632 | 0.94115 | 4 | 18 | 15 | 1 | 38 | 0 |
| 20260622T102123 | A6CB01 | LXJ537 | 36 | 1.465 | 0.25773 | 0.49946 | 0.31565 | 23 | 8 | 0 | 5 | 15 | 0 |
| 20260622T102123 | A1CFDC | N216AR | 33 | 1.1 | 1.6762 | 1.1165 | 1.1822 | 10 | 12 | 5 | 6 | 33 | 0 |
| 20260622T102123 | AC11EA | N877SC | 29 | 1.053 | 0.97276 | 0.2732 | 0.68159 | 24 | 2 | 0 | 3 | 0 | 0 |
| 20260622T102123 | A26DFB | KAP98 | 28 | 0.7335 | 0.19608 | 0.79429 | 0.47571 | 22 | 2 | 0 | 4 | 0 | 28 |
| 20260622T102123 | 71C217 | KAL091 | 9 | 1.56 | 0.042311 | 0.46911 | 0.50785 | 4 | 1 | 0 | 4 | 0 | 9 |
| 20260622T102123 | A14104 |  | 2 | 16.8355 | 0 | 0 | 0.010391 | 0 | 0 | 0 | 2 | 0 | 0 |

## Diversity Gap

- Constvel-like share: 75.2%.
- Constacc-like share: 20.0%.
- Constturn-like share: 1.8%.
- Mixed or sparse share: 3.1%.
- Pairs at or above standard-rate turn threshold, 3 deg/s: 0.
- Maximum observed absolute turn rate [deg/s]: 2.421.
- This is still a single-session local smoke dataset. It lacks diversity in maneuver regimes, update spacing, traffic mix, route geometry, and collection conditions.

## Artifacts

- Stage 2C MAT: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2C\stage2CManeuverCharacterization.mat`
- Stage 2C figure: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage2C\stage2CManeuverCharacterization.png`
