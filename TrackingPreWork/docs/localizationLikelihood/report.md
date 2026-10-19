# FlightTest localization-likelihood POC

Generated 2026-10-14 14:07:16 UTC with 26.1.0.3203278 (R2026a). Mode: **terrain**.

## 1. Objective and result

Measure the incremental value of WLEK-LD RF31 while separating ideal range geometry, modeled signal support, and useful localization. The recovered northern ROI is the headline comparison; the west corridor is independent supporting evidence.

**Headline: 0.0000 km² maximum added useful area in the northern ROI across the executed refined-grid cases at 6000 ft AGL.** WLEK improves ideal geometry but does not demonstrate a robust northern localization-coverage benefit under these RF assumptions. The coarse-grid results, including partial boundary cells, remain visible in the tables. This is a local Gaussian information/uncertainty study, not a measured likelihood of detection or a global position-uniqueness proof.

## 2. Sources and configuration

See [repository survey](repositorySurvey.md) and [assumptions](assumptions.md). The original verbatim ten-section narrative was unavailable; this report reconstructs the technical coverage transparently. Maintained Newton/Hudson precheck inputs govern; historical live scripts and reports are preserved. All authored changes are under TrackingPreWork. SHA-256 source stamps, configuration, MATLAB products, arrays, masks, and metrics are saved in the MAT result.

Grid 0.020°; heights 3000, 6000, 9000 ft AGL; range sigma 50 m; gate 13.0 dB; useful limits 500 m known-Up horizontal RMS and 1000 m 3D total RMS; condition of whitened H <= 10000.

Candidate screen: 29 catalog records, 13 distinct coordinate pairs, 10 within 60 km. Complex S21 is linearly interpolated; full-channel maxima include interior segment minima of |S21|.

| Location | RFChannel | DistanceKm | MinimumSeparationDeg | FullChannelMaxLossDB | Eligible | Selected |
| --- | --- | --- | --- | --- | --- | --- |
| Cochesett | 10 | 40.796 | 59.237 | 57.396 | false | false |
| WLEK site | 31 | 39.495 | 33.403 | 0.77537 | true | true |
| WCRN site | 30 | 25.527 | 20.57 | 0.78385 | true | false |
| WWOO site | 28 | 24.688 | 8.0649 | 0.79317 | true | false |
| John Hancock | 36 | 23.317 | 6.3254 | 0.73419 | true | false |
| Cabot Street | 34 | 10.849 | 5.3085 | 0.7462 | true | false |
| FM128 | 26 | 10.425 | 2.3162 | 0.79485 | true | false |
| Catalog Newton | 35 | 11.08 | 0.50158 | 0.73688 | false | false |
| CBS Tower | 20 | 9.3832 | 0.0015406 | 0.8849 | false | false |
| Hudson | 27 | 15.127 | 3.1457e-10 | 0.79398 | false | false |

## 3. Measurement and height conventions

rho_i = ||p-Tx_i|| + ||p-Rx|| - ||Tx_i-Rx||, in meters, without a factor of one half. H_i is the sum of the two target-directed unit vectors. Terrain MSL plus antenna/aircraft AGL plus EGM96 geoid separation gives WGS84 ellipsoidal height before receiver-centered ENU conversion. Supplied NAD83 horizontal coordinates are treated as WGS84-compatible, an explicit approximation.

Whiten H using chol(R,'lower'), then use SVD for rank, singular values, conditioning, and covariance. No information-matrix inverse or deficient pseudoinverse confidence is used. Known Up retains 3D slant distances and fixes only the receiver-frame Up coordinate locally. GeometryRMS is sqrt(sum(1/svd(H)^2)) with unit range variance. Full rank is local: separate ellipsoidal intersections can remain.

Native examples read and adapted: [Tracking Using Bistatic Range Detections](https://www.mathworks.com/help/fusion/ug/track-using-bistatic-range-detections.html) supplies the excess-range/ellipsoid convention; [Object Tracking Using TDOA](https://www.mathworks.com/help/fusion/ug/object-tracking-using-time-difference-of-arrival.html) motivates constant-measurement contours (ellipsoids here, rather than TDOA hyperboloids); [CRLB for Bistatic Position Estimation](https://www.mathworks.com/help/phased/ug/crlb-for-bistatic-position-estimation.html) supplies sqrt(trace(C)) presentation and fixed color limits. Its angle measurement is deliberately removed. Verification uses crlb, tsoaposest and radareqsnr; no Doppler, detections, fuser, or tracker is added. Public example pages were read on 2026-10-13; installed R2026a syntax and execution provide version verification.

## 4. Ideal geometry and uncertainty

A single transmitter is deficient in both modes. Newton+Hudson is always deficient for unconstrained 3D. Three independent usable ranges can produce full local 3D rank, while two can support known-Up horizontal localization. The following 6000 ft results include all configurations, including the geometry-only Cochesett reference. Medians and P95 are area-weighted over full-rank, accepted-condition cells; counts disclose their limited domain.

| ROI | Configuration | Mode | ROICells | IdealValidCells | IdealUsefulAreaKm2 | IdealMedianRMSM | IdealP95RMSM | IdealMedianGeometryRMS | IdealP95GeometryRMS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Recovered north | Newton | Known Up | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | Newton | Unconstrained 3D | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | Hudson | Known Up | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | Hudson | Unconstrained 3D | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | WLEK | Known Up | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | WLEK | Unconstrained 3D | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | Newton+Hudson | Known Up | 403 | 403 | 1232 | 84.991 | 231.12 | 1.6998 | 4.6223 |
| Recovered north | Newton+Hudson | Unconstrained 3D | 403 | 0 | 0 | NaN | NaN | NaN | NaN |
| Recovered north | Newton+Hudson+WLEK | Known Up | 403 | 403 | 1254.9 | 59.818 | 104.89 | 1.1964 | 2.0978 |
| Recovered north | Newton+Hudson+WLEK | Unconstrained 3D | 403 | 403 | 1103.3 | 433.54 | 1287.5 | 8.6708 | 25.751 |
| Recovered north | Newton+Hudson+Cochesett | Known Up | 403 | 403 | 1254.9 | 56.185 | 142.03 | 1.1237 | 2.8406 |
| Recovered north | Newton+Hudson+Cochesett | Unconstrained 3D | 403 | 403 | 527.77 | 1278.7 | 4516.8 | 25.574 | 90.337 |
| West corridor | Newton | Known Up | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | Newton | Unconstrained 3D | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | Hudson | Known Up | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | Hudson | Unconstrained 3D | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | WLEK | Known Up | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | WLEK | Unconstrained 3D | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | Newton+Hudson | Known Up | 338 | 338 | 1020.1 | 119.72 | 498.53 | 2.3945 | 9.9706 |
| West corridor | Newton+Hudson | Unconstrained 3D | 338 | 0 | 0 | NaN | NaN | NaN | NaN |
| West corridor | Newton+Hudson+WLEK | Known Up | 338 | 338 | 1073.1 | 106.48 | 185.66 | 2.1297 | 3.7133 |
| West corridor | Newton+Hudson+WLEK | Unconstrained 3D | 338 | 338 | 428.76 | 1250 | 3202.5 | 24.999 | 64.051 |
| West corridor | Newton+Hudson+Cochesett | Known Up | 338 | 338 | 1073.1 | 66.199 | 126.97 | 1.324 | 2.5394 |
| West corridor | Newton+Hudson+Cochesett | Unconstrained 3D | 338 | 338 | 402.83 | 1595.2 | 5231.2 | 31.904 | 104.62 |

## 5. Modeled signal support

ERP-to-EIRP correction 2.15 dB; explicit gains [0,12] dB; Ts=515.7 K; RCS=0.5 m²; bandwidth=6 MHz; equivalent interval=5 microseconds. Both propagation legs use the respective transmitter frequency. The interval is counted once. ApplyBandpassLoss=false; the default uses the component response for screening without subtracting it again from the effective system-NF model.

The inherited signed Longley–Rice-minus-free-space difference is preserved. Negative values predict enhancement, and are not silently clipped. The same-geometry zero-excess-loss reference below exposes support that depends on that enhancement. This is a model sensitivity, not a second measured RF dataset.

| ROI | Transmitter | MaxSNRDB | MaxFreeSpaceSNRDB | SupportedAreaKm2 | SupportedOnlyWithEnhancementKm2 |
| --- | --- | --- | --- | --- | --- |
| Recovered north | Newton | 44.048 | 35.951 | 361.64 | 3.6616 |
| West corridor | Newton | 44.048 | 35.951 | 235.69 | 3.6616 |
| Recovered north | Hudson | 36.486 | 29.271 | 352.61 | 10.972 |
| West corridor | Hudson | 36.486 | 29.271 | 336.04 | 7.3254 |
| Recovered north | WLEK-LD | 13.066 | 5.0924 | 0.3297 | 0.3297 |
| West corridor | WLEK-LD | 13.066 | 5.0924 | 0.091596 | 0.091596 |

## 6. Combined opportunity and Tx3 attribution

Each point uses only ranges with SNR >= gate, then recomputes information. Any-link coverage and number of supported ranges are saved separately. Useful coverage requires full rank, accepted condition, and the selected RMS limit. Areas use WGS84 cell/ROI intersections; the field is sampled at cell centers. Three altitude slices are not a volume.

| ROI | AltitudeFtAGL | Mode | BaselineUsefulAreaKm2 | WithWLEKUsefulAreaKm2 | AddedUsefulCells | AddedUsefulAreaKm2 | IdealAddedUsefulAreaKm2 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Recovered north | 3000 | Known Up | 176 | 176 | 0 | 0 | 22.908 |
| Recovered north | 3000 | Unconstrained 3D | 0 | 0.3297 | 1 | 0.3297 | 667.26 |
| West corridor | 3000 | Known Up | 193.65 | 193.65 | 0 | 0 | 52.963 |
| West corridor | 3000 | Unconstrained 3D | 0 | 0.091596 | 1 | 0.091596 | 216.4 |
| Recovered north | 6000 | Known Up | 176 | 176 | 0 | 0 | 22.908 |
| Recovered north | 6000 | Unconstrained 3D | 0 | 0.3297 | 1 | 0.3297 | 1103.3 |
| West corridor | 6000 | Known Up | 193.65 | 193.65 | 0 | 0 | 52.963 |
| West corridor | 6000 | Unconstrained 3D | 0 | 0.091596 | 1 | 0.091596 | 428.76 |
| Recovered north | 9000 | Known Up | 172.34 | 172.34 | 0 | 0 | 26.898 |
| Recovered north | 9000 | Unconstrained 3D | 0 | 0.3297 | 1 | 0.3297 | 1227.6 |
| West corridor | 9000 | Known Up | 189.99 | 189.99 | 0 | 0 | 63.94 |
| West corridor | 9000 | Unconstrained 3D | 0 | 0.091596 | 1 | 0.091596 | 689.62 |

Attribution at the baseline altitude distinguishes already-supported baseline links from a missing usable constraint. These logical categories do not exclude overlapping physical causes such as geometry and RF support. LostUsefulCells is zero in the executed baseline and error/gate sensitivities.

| ROI | Mode | AddedWhereBothBaselineSupportedKm2 | AddedWhereBaselineMissingConstraintKm2 | NewAnyLinkAreaKm2 | AddedUsefulCenterInsideCells | AddedUsefulOutsideCenterAreaKm2 |
| --- | --- | --- | --- | --- | --- | --- |
| Recovered north | Known Up | 0 | 0 | 0 | 0 | 0 |
| Recovered north | Unconstrained 3D | 0.3297 | 0 | 0 | 0 | 0.3297 |
| West corridor | Known Up | 0 | 0 | 0 | 0 | 0 |
| West corridor | Unconstrained 3D | 0.091596 | 0 | 0 | 0 | 0.091596 |

Actual uncertainty statistics at 6000 ft (NaN means no valid sample; it is not zero uncertainty):

| ROI | Configuration | Mode | ROICells | ValidCells | RankDeficientCells | IllConditionedCells | MedianHorizontalM | P95HorizontalM | MedianVerticalM | P95VerticalM | MedianTotalM | P95TotalM |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Recovered north | Newton+Hudson | Known Up | 403 | 61 | 342 | 0 | 64.312 | 429.99 | 0 | 0 | 64.312 | 429.99 |
| Recovered north | Newton+Hudson | Unconstrained 3D | 403 | 0 | 403 | 0 | NaN | NaN | NaN | NaN | NaN | NaN |
| Recovered north | Newton+Hudson+WLEK | Known Up | 403 | 61 | 342 | 0 | 64.312 | 429.99 | 0 | 0 | 64.312 | 429.99 |
| Recovered north | Newton+Hudson+WLEK | Unconstrained 3D | 403 | 1 | 402 | 0 | 135 | 135 | 57.363 | 57.363 | 146.68 | 146.68 |
| West corridor | Newton+Hudson | Known Up | 338 | 65 | 273 | 0 | 62.939 | 429.99 | 0 | 0 | 62.939 | 429.99 |
| West corridor | Newton+Hudson | Unconstrained 3D | 338 | 0 | 338 | 0 | NaN | NaN | NaN | NaN | NaN | NaN |
| West corridor | Newton+Hudson+WLEK | Known Up | 338 | 65 | 273 | 0 | 62.939 | 429.99 | 0 | 0 | 62.939 | 429.99 |
| West corridor | Newton+Hudson+WLEK | Unconstrained 3D | 338 | 1 | 337 | 0 | 135 | 135 | 57.363 | 57.363 | 146.68 | 146.68 |

## 7. Sensitivities and recommendation stability

Range sigma 25, 50, 100 m and SNR gates 10, 13, 16 dB were crossed on the same physical arrays. Full results are in sensitivitySummary.csv and sensitivityAttribution.csv. The following 6000 ft table retains every error/gate case.

| ROI | Mode | SigmaM | GateDB | AddedUsefulAreaKm2 | AddedUsefulCenterInsideCells |
| --- | --- | --- | --- | --- | --- |
| Recovered north | Known Up | 25 | 10 | 0 | 0 |
| Recovered north | Unconstrained 3D | 25 | 10 | 0.6594 | 0 |
| West corridor | Known Up | 25 | 10 | 0 | 0 |
| West corridor | Unconstrained 3D | 25 | 10 | 3.7555 | 1 |
| Recovered north | Known Up | 25 | 13 | 0 | 0 |
| Recovered north | Unconstrained 3D | 25 | 13 | 0.3297 | 0 |
| West corridor | Known Up | 25 | 13 | 0 | 0 |
| West corridor | Unconstrained 3D | 25 | 13 | 0.091596 | 0 |
| Recovered north | Known Up | 25 | 16 | 0 | 0 |
| Recovered north | Unconstrained 3D | 25 | 16 | 0 | 0 |
| West corridor | Known Up | 25 | 16 | 0 | 0 |
| West corridor | Unconstrained 3D | 25 | 16 | 0 | 0 |
| Recovered north | Known Up | 50 | 10 | 0 | 0 |
| Recovered north | Unconstrained 3D | 50 | 10 | 0.6594 | 0 |
| West corridor | Known Up | 50 | 10 | 0 | 0 |
| West corridor | Unconstrained 3D | 50 | 10 | 3.7555 | 1 |
| Recovered north | Known Up | 50 | 13 | 0 | 0 |
| Recovered north | Unconstrained 3D | 50 | 13 | 0.3297 | 0 |
| West corridor | Known Up | 50 | 13 | 0 | 0 |
| West corridor | Unconstrained 3D | 50 | 13 | 0.091596 | 0 |
| Recovered north | Known Up | 50 | 16 | 0 | 0 |
| Recovered north | Unconstrained 3D | 50 | 16 | 0 | 0 |
| West corridor | Known Up | 50 | 16 | 0 | 0 |
| West corridor | Unconstrained 3D | 50 | 16 | 0 | 0 |
| Recovered north | Known Up | 100 | 10 | 0 | 0 |
| Recovered north | Unconstrained 3D | 100 | 10 | 0.6594 | 0 |
| West corridor | Known Up | 100 | 10 | 0 | 0 |
| West corridor | Unconstrained 3D | 100 | 10 | 3.7555 | 1 |
| Recovered north | Known Up | 100 | 13 | 0 | 0 |
| Recovered north | Unconstrained 3D | 100 | 13 | 0.3297 | 0 |
| West corridor | Known Up | 100 | 13 | 0 | 0 |
| West corridor | Unconstrained 3D | 100 | 13 | 0.091596 | 0 |
| Recovered north | Known Up | 100 | 16 | 0 | 0 |
| Recovered north | Unconstrained 3D | 100 | 16 | 0 | 0 |
| West corridor | Known Up | 100 | 16 | 0 | 0 |
| West corridor | Unconstrained 3D | 100 | 16 | 0 | 0 |

Refining the grid checks whether a small coarse-grid gain is caused by boundary sampling. Maximum refined northern added area is 0 km². West-corridor areas vary with refinement and are not claimed converged.

| ROI | Mode | GridSpacingDegrees | BaselineUsefulAreaKm2 | AddedUsefulAreaKm2 | AddedUsefulCenterInsideCells |
| --- | --- | --- | --- | --- | --- |
| Recovered north | Known Up | 0.01 | 172.02 | 0 | 0 |
| Recovered north | Unconstrained 3D | 0.01 | 0 | 0 | 0 |
| West corridor | Known Up | 0.01 | 194.02 | 0 | 0 |
| West corridor | Unconstrained 3D | 0.01 | 0 | 0.50378 | 1 |
| Recovered north | Known Up | 0.005 | 170.41 | 0 | 0 |
| Recovered north | Unconstrained 3D | 0.005 | 0 | 0 | 0 |
| West corridor | Known Up | 0.005 | 192.29 | 0.13738 | 1 |
| West corridor | Unconstrained 3D | 0.005 | 0 | 1.0992 | 6 |

Newton catalog sensitivity uses 42.311389°, -71.216111° while retaining its RF parameters and height. Compare with section 6; this changes baseline horizontal coverage but does not rescue broad WLEK signal support.

| ROI | Mode | BaselineUsefulAreaKm2 | AddedUsefulAreaKm2 | IdealAddedUsefulAreaKm2 |
| --- | --- | --- | --- | --- |
| Recovered north | Known Up | 165.03 | 0 | 23.567 |
| Recovered north | Unconstrained 3D | 0 | 0.3297 | 1113.2 |
| West corridor | Known Up | 181.49 | 0 | 82.228 |
| West corridor | Unconstrained 3D | 0 | 0.091596 | 428.75 |

## 8. Verification and reproducibility

**34/34 tests passed; 0 failed; 0 incomplete.** Native crlb covariance relative error at a well-conditioned study point: 1.47e-10; information-matrix error: 4.56e-10. Native tsoaposest noiseless synthetic position error: 2.36e-13 m.

The original ten sanity-check labels were unavailable. Executed coverage maps to ten engineering categories: (1) excess range/baseline, (2) analytic Jacobian/finite differences, (3) rank and degeneracy, (4) fixed-Up 3D slants, (5) covariance scaling/independent information, (6) availability and weak-Tx3 preservation, (7) native crlb/tsoaposest units, (8) explicit RF hand reference and parameter effects, (9) height datum/geographic area, (10) cache invalidation, fresh equality, explicit fallback labels, and summary/attribution partitions. See testResults.csv for individual checks.

Fresh-versus-cached native checks: maximum terrain-position difference 0 m and WLEK SNR difference 0 dB.

Cache keys contain relevant configuration, source digests, release, coordinates/heights and propagation mode. Changing unrelated measurement sigma/gate reuses RF; changing a relevant physical input invalidates it. Native elevation/propagation service failures restart the scenario as flat-free-space; programming/configuration failures are rethrown. Explicit fallback execution is tested; no network outage was induced.

Rerun from the repository root:

```matlab
run("TrackingPreWork/analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m")
```

## 9. Limitations

This study assumes unbiased independent 50 m range errors, constant RCS/gains and effective NF, synchronized valid ranges, and no false association or clutter. SNR is an equivalent-observation model and is not a calibrated range-error law. At the baseline altitude the maximum coarse-grid WLEK SNR margin over the gate is 0.066 dB. Consult section 5 for support that requires negative signed excess loss; that behavior needs physical validation. Coarse boundary-cell sampling can assign a cell-center result to a small ROI intersection even when its center is outside. Refined west results are not claimed converged.

The catalog/Newton conflict, NAD83/WGS84 approximation, antenna patterns, optional high-pass response, terrain dataset revisions, and global multi-solution ambiguity remain. Known Up is an exact local condition; operational altitude errors would weaken it. No detection, tracking, or field-acquisition capability was demonstrated.

**Hardware-acquisition caveat:** Realizing modeled benefit requires simultaneous coherent acquisition and suitable references for separate RF channels, with synchronized/calibrated measurements. Installed receive-chain response, optional high-pass filter, available channel count/bandwidth, reference quality, and timing integrity are unresolved. This POC does not qualify hardware or approve acquisition changes; conclusions remain conditional on modeled RF support and measurement quality.

## 10. Deliverables and next decision

The screen selects WLEK among the frozen UHF candidates. Its ideal geometric value does not translate into a demonstrated material northern localization-coverage gain. The catalog Newton alternative does not change the lack of broad WLEK signal support in this execution. Retain Cochesett as geometry-only because of the filter result. The most useful next engineering step is to validate the per-channel echo SNR/reference quality and signed excess-loss behavior before expanding localization implementation.

Authored code: one runner, one configuration function, focused helpers for screen/grid/datum/range information/RF/cache/attribution/plots/report/native checks, and one class-based test suite. Documentation: survey, assumptions, this generated report, scoped concepts index, skill-use summary, and concise PROJECT_STATE. Generated products: PNG figures, configuration/attribution/RF/sensitivity/grid/candidate/test CSVs, and localizationLikelihoodResults.mat. Existing reports and link budgets were preserved.

Created source files (paths relative to TrackingPreWork):

- [analysis/localizationLikelihood/helperLLAnalyze.m](../../analysis/localizationLikelihood/helperLLAnalyze.m)
- [analysis/localizationLikelihood/helperLLCache.m](../../analysis/localizationLikelihood/helperLLCache.m)
- [analysis/localizationLikelihood/helperLLCacheFile.m](../../analysis/localizationLikelihood/helperLLCacheFile.m)
- [analysis/localizationLikelihood/helperLLGeometry.m](../../analysis/localizationLikelihood/helperLLGeometry.m)
- [analysis/localizationLikelihood/helperLLGrid.m](../../analysis/localizationLikelihood/helperLLGrid.m)
- [analysis/localizationLikelihood/helperLLNativeVerification.m](../../analysis/localizationLikelihood/helperLLNativeVerification.m)
- [analysis/localizationLikelihood/helperLLPlots.m](../../analysis/localizationLikelihood/helperLLPlots.m)
- [analysis/localizationLikelihood/helperLLRF.m](../../analysis/localizationLikelihood/helperLLRF.m)
- [analysis/localizationLikelihood/helperLLRFDiagnostics.m](../../analysis/localizationLikelihood/helperLLRFDiagnostics.m)
- [analysis/localizationLikelihood/helperLLRadarSNR.m](../../analysis/localizationLikelihood/helperLLRadarSNR.m)
- [analysis/localizationLikelihood/helperLLRunScenario.m](../../analysis/localizationLikelihood/helperLLRunScenario.m)
- [analysis/localizationLikelihood/helperLLScreen.m](../../analysis/localizationLikelihood/helperLLScreen.m)
- [analysis/localizationLikelihood/helperLLSensitivities.m](../../analysis/localizationLikelihood/helperLLSensitivities.m)
- [analysis/localizationLikelihood/helperLLSourceStamp.m](../../analysis/localizationLikelihood/helperLLSourceStamp.m)
- [analysis/localizationLikelihood/helperLLSummaries.m](../../analysis/localizationLikelihood/helperLLSummaries.m)
- [analysis/localizationLikelihood/helperLLTerrain.m](../../analysis/localizationLikelihood/helperLLTerrain.m)
- [analysis/localizationLikelihood/helperLLWalkthroughExport.m](../../analysis/localizationLikelihood/helperLLWalkthroughExport.m)
- [analysis/localizationLikelihood/helperLLWalkthroughStudy.m](../../analysis/localizationLikelihood/helperLLWalkthroughStudy.m)
- [analysis/localizationLikelihood/helperLLWalkthroughView.m](../../analysis/localizationLikelihood/helperLLWalkthroughView.m)
- [analysis/localizationLikelihood/helperLLWriteReport.m](../../analysis/localizationLikelihood/helperLLWriteReport.m)
- [analysis/localizationLikelihood/localizationLikelihoodConfig.m](../../analysis/localizationLikelihood/localizationLikelihoodConfig.m)
- [analysis/localizationLikelihood/localizationWalkthrough.m](../../analysis/localizationLikelihood/localizationWalkthrough.m)
- [analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m](../../analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m)
- [analysis/localizationLikelihood/tests/localizationLikelihoodTest.m](../../analysis/localizationLikelihood/tests/localizationLikelihoodTest.m)

Additional created files: `README.md`, `PROJECT_STATE.md`, `concepts.md`, `sftt_skillUseSummary.md`, `analysis/localizationLikelihood/.gitignore`, and `docs/localizationLikelihood/{repositorySurvey,assumptions,report}.md`. No pre-existing tracked source file was modified.

Figure index (all generated under analysis/localizationLikelihood/results):

- [01_site_roi_overview](../../analysis/localizationLikelihood/results/01_site_roi_overview.png)
- [02_excess_range_contours](../../analysis/localizationLikelihood/results/02_excess_range_contours.png)
- [03_ideal_geometry_2D](../../analysis/localizationLikelihood/results/03_ideal_geometry_2D.png)
- [04_ideal_geometry_3D](../../analysis/localizationLikelihood/results/04_ideal_geometry_3D.png)
- [05_geometry_improvement_transitions](../../analysis/localizationLikelihood/results/05_geometry_improvement_transitions.png)
- [06_per_transmitter_snr](../../analysis/localizationLikelihood/results/06_per_transmitter_snr.png)
- [07_configuration_snr](../../analysis/localizationLikelihood/results/07_configuration_snr.png)
- [08_useful_localization_2D](../../analysis/localizationLikelihood/results/08_useful_localization_2D.png)
- [09_useful_localization_3D](../../analysis/localizationLikelihood/results/09_useful_localization_3D.png)
- [10_signal_geometry_diagnostics](../../analysis/localizationLikelihood/results/10_signal_geometry_diagnostics.png)
- [11_area_versus_altitude](../../analysis/localizationLikelihood/results/11_area_versus_altitude.png)
- [12_cochesett_geometry_reference](../../analysis/localizationLikelihood/results/12_cochesett_geometry_reference.png)

[CSV/MAT result folder](../../analysis/localizationLikelihood/results/) contains the detailed evidence. Generated MAT/cache products are reproducible and should be reviewed for size before a manual Git checkpoint. No Git writes were performed.
