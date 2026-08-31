# Stage 4C-Retrain: Expanded-3Day Exploratory Mean-MLP Training

Generated: 27-Aug-2026 14:35:45

## Concept

Each network receives only one previous `[x, vx, y, vy, z, vz]` state, its six covariance-diagonal values, and `dt`. It predicts the six-state change to the next ADS-B observation. No trajectory history or ICAO identifier enters the model.

The scratch candidate learns from a new random initialization. The warm control begins with the frozen Stage 3A weights after an affine weight rebase that preserves physical predictions under Expanded-3Day normalization. Both use fresh Adam state and identical rows/options.

## Exploratory Verdict

expanded_scratch_mean_v1 does not beat constvel on test position RMSE (28.149 m; delta +4.847 m) and beats constvel on velocity RMSE (3.453 m/s; delta -0.014 m/s). expanded_warm_mean_v1 does not beat constvel on test position RMSE (27.469 m; delta +4.166 m) and beats constvel on velocity RMSE (3.453 m/s; delta -0.014 m/s).

No candidate is promoted by this experiment. Broad-generalization, learned covariance, recurrent history, and deployment remain deferred.

## Native Function Audit

| workflow | nativeMATLABFunction | stage4CUse | verified |
| --- | --- | --- | --- |
| Irregular one-step motion baseline | constvel | Reuse saved native predictions and spot-check 32 rows | true |
| Mean-MLP training | trainnet with trainingOptions('adam') | Normalized delta-MSE, patience, and best-validation output | true |
| MLP architecture | featureInputLayer, fullyConnectedLayer, reluLayer | Unchanged 20-64-64-6 architecture | true |
| Held-out error summaries | vecnorm, mean, median, weighted quantile | Position/velocity RMSE, median, and P95 | true |

## Frozen Dataset And Split

- Dataset: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4BPostCampaign\expanded_post3day_v2\stage3CArchiveStatePairDataset.mat`
- Dataset SHA-256: `9B757A85A58DA6663F79524E6B287B06420DB0BF3480A7AA661E96792212EBDD`
- Dataset-variant manifest SHA-256: `87B6D5C73046BC3EEC63CE17531EBC7B6E1D7E824D7254CD1C0D753BEB6221E4`
- Split manifest: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\adsb_archive\datasetVersions\expandedPost3DayICAODisjointSplit_v1.csv`
- Split manifest SHA-256: `74CA2A3BC5E583C6C03E06395CA5D50C772F13C67B73148CA9FEB459322900DB`
- Source files hash-verified: true
- Inherited smoke-split ICAOs spanning multiple partitions: 394 (ignored)

| split | pairCount | aircraftCount |
| --- | --- | --- |
| train | 277959 | 1188 |
| validation | 86420 | 395 |
| test | 93524 | 395 |

## Model And Optimization

- Architecture: `20-64-64-6` with ReLU hidden layers.
- Objective: normalized six-state delta MSE through MATLAB `trainnet`.
- Optimizer: Adam, learning rate 0.001, L2 0.0001.
- Batch size: 1024; maximum epochs: 50.
- Validation: once per epoch, patience 8, output network `best-validation`.
- Seed and execution: 123, `cpu`.

## Pre-Training Checks

- Tiny-overfit rows: 128; first/final loss: 0.693553 / 0.0914357; passed: true.
- Warm-start rebase maximum physical-state difference: 0.000297544164 m or m/s (tolerance 0.024466016); passed: true.
- Frozen Stage 3A artifact unchanged: true (`2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906`).

## Held-Out Headline Metrics

These are pair-weighted overall metrics. The complete CSV also contains independent-event-weighted results and all maneuver, vertical, and update-rate slices.

| modelID | split | sampleCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | positionP95ErrorMeters |
| --- | --- | --- | --- | --- | --- | --- |
| constvel | validation | 86420 | 27.2469 | 4.47721 | 5.77329 | 20.2622 |
| legacy_stage3a_v1 | validation | 86420 | 213.136 | 4.53418 | 29.6355 | 258.163 |
| expanded_scratch_mean_v1 | validation | 86420 | 30.9305 | 4.44321 | 9.59813 | 31.3481 |
| expanded_warm_mean_v1 | validation | 86420 | 30.6954 | 4.45011 | 9.55622 | 30.0412 |
| constvel | test | 93524 | 23.3028 | 3.46728 | 6.0039 | 19.8957 |
| legacy_stage3a_v1 | test | 93524 | 208.972 | 3.54669 | 30.5698 | 247.871 |
| expanded_scratch_mean_v1 | test | 93524 | 28.1494 | 3.45292 | 9.97796 | 30.7353 |
| expanded_warm_mean_v1 | test | 93524 | 27.4691 | 3.45316 | 9.95098 | 29.257 |

## Weighting Interpretation

- Pair-weighted: Every held-out state pair has weight one.
- Independent-event-weighted: Each row has reciprocal event-length weight, so every event has total weight one.
- Event boundary: A contiguous run within one session/ICAO track and one reported regime.

## Native Maneuver-Baseline Extension

This evaluation-only extension compares native `constacc` on matched `constacc_like` rows and native `constturn` on matched `constturn_like` rows. The Stage 3A, scratch, and warm networks remain frozen.

- Initialization policy: `raw_causal_finite_difference_v1`.
- Acceleration is the raw three-dimensional velocity finite difference from the immediately preceding adjacent observation.
- Turn rate is the raw wrapped heading finite difference in degrees per second, matching the native `constturn` omega convention.
- Clipping applied: false; smoothing applied: false.
- Maneuver labels are retrospective truth-derived evaluation slices. They never initialize or enter a prediction.
- ICAO is used only for frozen split assignment and same-track predecessor grouping.

### Eligibility Coverage

| split | maneuverSlice | sourceSliceRowCount | eligibleRowCount | excludedRowCount | coverageFraction |
| --- | --- | --- | --- | --- | --- |
| validation | constacc_like | 17030 | 16896 | 134 | 0.992132 |
| validation | constturn_like | 2084 | 2075 | 9 | 0.995681 |
| test | constacc_like | 18028 | 17890 | 138 | 0.992345 |
| test | constturn_like | 2186 | 2164 | 22 | 0.989936 |

Only temporally adjacent rows with positive prior `dt`, the same split, finite causal values, and finite native outputs are scored.

### Nonzero Exclusion Reasons

| split | maneuverSlice | reason | rowCount |
| --- | --- | --- | --- |
| validation | constacc_like | first_row_in_track | 114 |
| validation | constacc_like | nonadjacent_predecessor | 20 |
| validation | constturn_like | first_row_in_track | 8 |
| validation | constturn_like | nonadjacent_predecessor | 1 |
| test | constacc_like | first_row_in_track | 109 |
| test | constacc_like | nonadjacent_predecessor | 29 |
| test | constturn_like | first_row_in_track | 18 |
| test | constturn_like | nonadjacent_predecessor | 4 |

### Raw Initialization Diagnostics

Acceleration quantiles use the 3-D magnitude; turn-rate quantiles use absolute degrees per second. The outlier upper fence is Q3 + 1.5 IQR and is descriptive only: outliers remain in the native predictions.

| split | maneuverSlice | quantity | units | sampleCount | p50 | p90 | p95 | p99 | p999 | maximum | signedMinimum | signedMaximum | outlierUpperFence | outlierCount | outlierFraction |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| validation | constacc_like | acceleration_magnitude | m/s^2 | 16896 | 0.511884 | 1.50375 | 2.21561 | 3.97893 | 8.0881 | 70.4258 | NaN | NaN | 1.93812 | 1122 | 0.0664062 |
| validation | constturn_like | absolute_turn_rate | deg/s | 2075 | 1.25057 | 2.76551 | 3.5328 | 13.9427 | 187.365 | 346.525 | -259.083 | 346.525 | 4.5723 | 36 | 0.0173494 |
| test | constacc_like | acceleration_magnitude | m/s^2 | 17890 | 0.483095 | 1.36973 | 2.15508 | 4.00048 | 5.95646 | 81.2158 | NaN | NaN | 1.71995 | 1290 | 0.0721073 |
| test | constturn_like | absolute_turn_rate | deg/s | 2164 | 1.41641 | 2.75876 | 3.52032 | 8.27776 | 325.285 | 385.017 | -324.724 | 385.017 | 4.33191 | 45 | 0.0207948 |

Raw finite differences amplify ADS-B quantization, timing jitter, and short-interval velocity changes. Turn-rate spikes are therefore an expected sensitivity of this baseline, not evidence that the aircraft physically sustained the reported peak rate. Bounded or smoothed causal initialization is deferred as a separate sensitivity study.

### Matched Held-Out Metrics

Every model in a split/slice section uses exactly the same eligible rows. Both pair-weighted and independent-event-weighted position and velocity RMSE, median, and P95 are shown.

| modelID | split | groupName | weighting | sampleCount | eventCount | positionRMSEMeters | velocityRMSEMetersPerSecond | positionMedianErrorMeters | velocityMedianErrorMetersPerSecond | positionP95ErrorMeters | velocityP95ErrorMetersPerSecond |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| constacc | validation | constacc_like | pair_weighted | 16896 | 9525 | 8.2646 | 1.23264 | 5.48227 | 0.413691 | 15.6811 | 2.02036 |
| constacc | validation | constacc_like | independent_event_weighted | 16896 | 9525 | 8.67049 | 1.37917 | 5.59555 | 0.448678 | 16.4973 | 2.0877 |
| constvel | validation | constacc_like | pair_weighted | 16896 | 9525 | 8.25806 | 1.0341 | 5.50687 | 0.514444 | 15.8234 | 1.89283 |
| constvel | validation | constacc_like | independent_event_weighted | 16896 | 9525 | 8.62524 | 1.04341 | 5.61262 | 0.514444 | 16.6972 | 1.84297 |
| legacy_stage3a_v1 | validation | constacc_like | pair_weighted | 16896 | 9525 | 101.38 | 1.1206 | 27.8633 | 0.56517 | 228.081 | 2.16471 |
| legacy_stage3a_v1 | validation | constacc_like | independent_event_weighted | 16896 | 9525 | 111.008 | 1.14619 | 27.1689 | 0.52316 | 270.061 | 2.20629 |
| expanded_scratch_mean_v1 | validation | constacc_like | pair_weighted | 16896 | 9525 | 14.4667 | 1.05451 | 9.39795 | 0.517614 | 29.0427 | 1.99847 |
| expanded_scratch_mean_v1 | validation | constacc_like | independent_event_weighted | 16896 | 9525 | 15.0899 | 1.06478 | 9.55889 | 0.486917 | 30.3507 | 2.00301 |
| expanded_warm_mean_v1 | validation | constacc_like | pair_weighted | 16896 | 9525 | 13.6708 | 1.03272 | 9.45009 | 0.495742 | 26.2566 | 1.94757 |
| expanded_warm_mean_v1 | validation | constacc_like | independent_event_weighted | 16896 | 9525 | 14.1274 | 1.03979 | 9.51702 | 0.461944 | 27.2329 | 1.92003 |
| constturn | validation | constturn_like | pair_weighted | 2075 | 1338 | 19.7592 | 13.357 | 5.12863 | 0.850991 | 14.1329 | 3.47223 |
| constturn | validation | constturn_like | independent_event_weighted | 2075 | 1338 | 18.5801 | 12.4469 | 5.03453 | 0.948642 | 14.1607 | 3.40653 |
| constvel | validation | constturn_like | pair_weighted | 2075 | 1338 | 17.6824 | 14.2159 | 5.48058 | 2.17206 | 15.3322 | 7.23628 |
| constvel | validation | constturn_like | independent_event_weighted | 2075 | 1338 | 15.3101 | 12.558 | 5.3091 | 1.87363 | 15.0126 | 6.282 |
| legacy_stage3a_v1 | validation | constturn_like | pair_weighted | 2075 | 1338 | 57.8015 | 14.2029 | 25.7056 | 2.12967 | 116.625 | 7.29525 |
| legacy_stage3a_v1 | validation | constturn_like | independent_event_weighted | 2075 | 1338 | 56.3725 | 12.5506 | 23.0312 | 1.87119 | 116.45 | 6.15788 |
| expanded_scratch_mean_v1 | validation | constturn_like | pair_weighted | 2075 | 1338 | 19.9935 | 14.1657 | 9.04517 | 2.07566 | 24.1603 | 7.05584 |
| expanded_scratch_mean_v1 | validation | constturn_like | independent_event_weighted | 2075 | 1338 | 17.5058 | 12.5159 | 8.46551 | 1.8073 | 23.0363 | 5.95425 |
| expanded_warm_mean_v1 | validation | constturn_like | pair_weighted | 2075 | 1338 | 19.756 | 14.189 | 9.01108 | 2.12921 | 25.6862 | 7.24428 |
| expanded_warm_mean_v1 | validation | constturn_like | independent_event_weighted | 2075 | 1338 | 17.7607 | 12.5346 | 8.80511 | 1.85125 | 24.2344 | 6.02595 |
| constacc | test | constacc_like | pair_weighted | 17890 | 10340 | 8.52405 | 1.10439 | 5.67801 | 0.397253 | 16.3884 | 2.08364 |
| constacc | test | constacc_like | independent_event_weighted | 17890 | 10340 | 8.76875 | 1.14205 | 5.82292 | 0.422376 | 16.8988 | 2.09644 |
| constvel | test | constacc_like | pair_weighted | 17890 | 10340 | 8.55142 | 1.01298 | 5.6774 | 0.514444 | 16.3884 | 1.9538 |
| constvel | test | constacc_like | independent_event_weighted | 17890 | 10340 | 8.80317 | 1.00918 | 5.82907 | 0.514218 | 16.9238 | 1.82001 |
| legacy_stage3a_v1 | test | constacc_like | pair_weighted | 17890 | 10340 | 102.924 | 1.10863 | 28.2548 | 0.533356 | 225.275 | 2.21911 |
| legacy_stage3a_v1 | test | constacc_like | independent_event_weighted | 17890 | 10340 | 112.902 | 1.11226 | 27.8999 | 0.509995 | 268.273 | 2.18676 |
| expanded_scratch_mean_v1 | test | constacc_like | pair_weighted | 17890 | 10340 | 14.7761 | 1.03892 | 9.765 | 0.493621 | 28.8456 | 2.03457 |
| expanded_scratch_mean_v1 | test | constacc_like | independent_event_weighted | 17890 | 10340 | 15.271 | 1.02857 | 9.97168 | 0.465884 | 29.9429 | 1.94992 |
| expanded_warm_mean_v1 | test | constacc_like | pair_weighted | 17890 | 10340 | 14.1253 | 1.01381 | 9.99853 | 0.472017 | 26.1124 | 2.01016 |
| expanded_warm_mean_v1 | test | constacc_like | independent_event_weighted | 17890 | 10340 | 14.4394 | 1.00479 | 10.0373 | 0.441105 | 26.9934 | 1.94779 |
| constturn | test | constturn_like | pair_weighted | 2164 | 1242 | 16.0232 | 17.2197 | 5.58596 | 0.783318 | 16.4828 | 3.70283 |
| constturn | test | constturn_like | independent_event_weighted | 2164 | 1242 | 11.7034 | 11.5248 | 5.44648 | 0.922758 | 15.6053 | 3.40433 |
| constvel | test | constturn_like | pair_weighted | 2164 | 1242 | 14.3884 | 15.37 | 6.09046 | 2.34334 | 20.4481 | 8.17715 |
| constvel | test | constturn_like | independent_event_weighted | 2164 | 1242 | 11.2936 | 10.6522 | 5.73988 | 1.99571 | 17.518 | 6.1713 |
| legacy_stage3a_v1 | test | constturn_like | pair_weighted | 2164 | 1242 | 62.114 | 15.3764 | 28.2695 | 2.30965 | 135.306 | 8.21167 |
| legacy_stage3a_v1 | test | constturn_like | independent_event_weighted | 2164 | 1242 | 55.3609 | 10.6531 | 25.2224 | 1.98175 | 114.223 | 6.28699 |
| expanded_scratch_mean_v1 | test | constturn_like | pair_weighted | 2164 | 1242 | 17.5225 | 15.3328 | 9.36787 | 2.24064 | 28.0962 | 7.93259 |
| expanded_scratch_mean_v1 | test | constturn_like | independent_event_weighted | 2164 | 1242 | 14.6186 | 10.6259 | 8.68949 | 1.92037 | 25.6304 | 6.06128 |
| expanded_warm_mean_v1 | test | constturn_like | pair_weighted | 2164 | 1242 | 17.4605 | 15.348 | 9.49061 | 2.28907 | 26.7068 | 8.03323 |
| expanded_warm_mean_v1 | test | constturn_like | independent_event_weighted | 2164 | 1242 | 14.5194 | 10.6338 | 8.90738 | 1.97766 | 24.1005 | 6.24063 |

### Frozen-Artifact Integrity

| artifactID | path | beforeSHA256 | afterSHA256 | unchanged |
| --- | --- | --- | --- | --- |
| legacy_stage3a_v1 | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage3\localADSBMLPStage3Training.mat | 2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906 | 2459D134B9352E10EBC803419AD110784411515FE28ACCB4A1D88606A319B906 | true |
| expanded_scratch_mean_v1 | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\expandedPost3DayScratchMeanMLP_v1.mat | 941AFD716E75BC6D75AA4799BDCF38BC8294F8850A3876EEB2D83B0B8883F81F | 941AFD716E75BC6D75AA4799BDCF38BC8294F8850A3876EEB2D83B0B8883F81F | true |
| expanded_warm_mean_v1 | C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\expandedPost3DayWarmStartMeanMLP_v1.mat | 1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE | 1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE | true |

No training occurred, and this exploratory comparison promotes no model.

## Outputs

- Scratch artifact: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\expandedPost3DayScratchMeanMLP_v1.mat`
- Warm artifact: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\expandedPost3DayWarmStartMeanMLP_v1.mat`
- Compact comparison artifact: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\expandedPost3DayMeanMLPComparison_v1.mat`
- Complete metric table: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\stage4CRetrainMetricComparison.csv`
- Training curves: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\stage4C_training_curves.png`
- Representative trajectories: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\stage4C_representative_trajectories.png`
- Native maneuver-baseline comparison: `C:\Users\pwilliam\agenticProjects\flightTest\adsbForTracking\artifacts\stage4CRetrain\stage4C_native_maneuver_baseline_comparison.png`
