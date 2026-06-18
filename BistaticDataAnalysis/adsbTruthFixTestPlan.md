# ADS-B Truth Fix Test Plan and Review Handoff

Updated: June 18, 2026

## Scope

This change set standardizes the shared ADS-B truth, detector, and tracker conventions around the measurement state

`R_excess = R_tx + R_rx - L_3D`

with these required conversions:

- Doppler coupling: `f_D = -(fc/c) * dR_excess/dt`
- Inverse Doppler coupling: `Rdot = -f_D / (fc/c)`
- Shared range-cell spacing: `range_cell_m = c / fs`
- Shared numeric baseline for truth projection: `L = baseline_3d_m`
- Tracker and display sign consistency: displayed Doppler must use `-alpha * Rdot`

During regression, one additional detector-side bug was found and fixed:

- `createRDM.m` had been reporting Doppler with an endpoint-inclusive `linspace(-prf/2, prf/2, N_slow)`, which does not match the actual `fftshift(fft(...))` bin centers. The function now reports the true FFT bin-center axis with spacing `prf / N_slow`.

## Files To Review First

- `BistaticDataAnalysis/createRDM.m`
- `BistaticDataAnalysis/helperBistaticDopplerCoupling.m`
- `BistaticDataAnalysis/helperBistaticDopplerFromRangeRate.m`
- `BistaticDataAnalysis/helperBistaticRangeRateFromDoppler.m`
- `BistaticDataAnalysis/helperDeriveTxRxGeometry.m`
- `BistaticDataAnalysis/adsbToBistatic.m`
- `BistaticDataAnalysis/initMeasurementSpaceKF.m`
- `BistaticDataAnalysis/helperDeriveBistaticConstants.m`
- `BistaticDataAnalysis/helperTracksLogToHistories.m`
- `BistaticDataAnalysis/analyzeBistaticData.m`
- `BistaticDataAnalysis/render_rdm_step.m`
- `BistaticDataAnalysis/bistaticTruthConventionTest.m`

## Automated Verification Executed

### 1. Focused convention regression

Command:

```matlab
run(bistaticTruthConventionTest)
```

Result:

- `6/6` passed

Coverage:

- Shared constants match the CAF axes:
  - `alpha = fc/c`
  - `range_cell_m = c/fs`
  - `doppler_bin_hz = prf/N_slow`
- `createRDM` Doppler sign and bin-center placement match the passive CAF convention
- ADS-B truth projection uses the 3D Tx-Rx baseline
- Doppler/range-rate round trip matches track-history export
- KF initialization uses the shared conversions and measurement noise conventions

### 2. Detector replay regression

Command:

```matlab
runtests('runDetectorReplaySweepTest.m')
```

Result:

- `3/3` passed

Purpose:

- Confirms the detector replay path still parses case options and preserves existing replay behavior after the truth-convention changes

### 3. Helper and timing smoke test

Command:

```matlab
test_bistaticHelpers
```

Result:

- passed

Coverage:

- Shared bistatic constants
- 3D Tx/Rx geometry helper
- Doppler/range-rate round trip helper
- Part-timing helper fallback and metadata modes

### 4. Synthetic truth-pipeline integration

Command:

```matlab
test_adsbTruthPipeline
```

Result:

- passed

Coverage:

- `loadADSBTruth -> adsbToBistatic -> alignTruthToRadar -> assessTruthVsDetections`
- Standalone truth-diagnostic bundle creation and replay
- Detector replay snapshot creation and replay
- Truth scoring using detector-derived range and Doppler grid spacing

Observed synthetic metrics from the executed run:

- `11` fake detections generated
- detection-level truth scoring: `TP=10`, `FA=1`, `missed=2`
- standalone diagnostic unit: `TP=12`, `FA=0`, `missed=0`

## Static Analysis

Code Analyzer was run on the touched MATLAB surface.

Clean:

- `createRDM.m`
- `adsbToBistatic.m`
- `helperDeriveBistaticConstants.m`
- `initMeasurementSpaceKF.m`
- `helperTracksLogToHistories.m`
- `trackTargets.m`
- `render_rdm_step.m`
- `assessTruthVsDetections.m`
- `plotBistaticEllipses3D.m`
- `helperDeriveTxRxGeometry.m`
- `bistaticTruthConventionTest.m`
- `test_bistaticHelpers.m`

Info-only notes remain in:

- `analyzeBistaticData.m`
- `test_adsbTruthPipeline.m`

These are existing script-style growth warnings, not functional correctness warnings.

## Required Real-Data Validation

This machine does not have the packaged session data.

Blocked locally:

- `captures/` directory is absent
- `captures/20260616T160702` is absent

The following real-data validation still must be run on the development machine before declaring the change fully closed:

### 1. Timing A/B rerun on the saved session

```matlab
cd BistaticDataAnalysis

clear functions
out_meta = runBistaticAnalysisSession('20260616T160702', ...
    'Verbose', true, ...
    'PartTimingSource', 'metadata');

clear functions
out_fallback = runBistaticAnalysisSession('20260616T160702', ...
    'Verbose', true, ...
    'PartTimingSource', 'fallback');
```

Compare at minimum:

- `out_meta.truth_metrics.n_tp`
- `out_fallback.truth_metrics.n_tp`
- `out_meta.truth_metrics.n_fa`
- `out_fallback.truth_metrics.n_fa`
- `out_meta.truth_metrics.trk_table`
- `out_fallback.truth_metrics.trk_table`

### 2. Pre-patch versus post-patch comparison

Use `C:\Users\pwilliam\agenticProjects\bistaticOutput.txt` as the pre-patch reference log.

Check:

- TP, FA, and miss counts
- track-level range and Doppler bias
- whether only one timing mode improves materially

### 3. Tracker-display consistency spot check

Verify that a confirmed track's printed Doppler in the console and legend matches:

- `track_histories.f_D_hz`
- the sign convention used in `render_rdm_step.m`

## Review Focus

Reviewers should specifically verify these points:

- Every shared conversion uses the new helpers instead of re-deriving `alpha` or the Doppler sign ad hoc.
- No shared tracker or truth code still assumes `c/(2*fs)` for the detector grid.
- `createRDM` now reports true FFT-bin Doppler centers, and downstream code uses that axis consistently.
- `adsbToBistatic.m` uses the 3D baseline for the numeric truth model.
- `analyzeBistaticData.m` and `render_rdm_step.m` display Doppler with `-alpha * Rdot`.

## Known Residual Risk

`plotBistaticEllipses3D.m` now uses the shared 3D baseline scalar for consistency with the numeric truth model, but it still uses the horizontal ENU midpoint and bearing to draw fixed-altitude contours. That is acceptable as a visualization approximation for now, but it is not the same thing as recomputing the exact fixed-altitude 3D iso-range locus. Reviewers should treat that as a visualization caveat, not as a truth-scoring bug.
