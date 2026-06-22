# ADS-B Truth Fix Checklist

Updated: June 18, 2026

## Session Snapshot

- Local implementation is complete for the shared convention work.
- Remaining work for the next session is real packaged-session validation, not another local formula patch.
- The detailed verification record and code-review notes live in `adsbTruthFixTestPlan.md`.
- The real-data blocker is unchanged on this machine: `captures/20260616T160702` is not present locally.

## Purpose

This checklist is now the session-start document for finishing the ADS-B truth fix on real packaged data.

Treat items 1 through 5 as implemented locally unless new evidence from the development-machine rerun disproves them. The next session should start at items 6 and 7.

## Current Context

- Session `20260616T160702` looks materially better at the front end:
  - ATSC-consistent pilot candidate found near `-2.800 MHz`
  - direct-path lag/coherence checks pass
  - ECA-C suppression passes
- The saved development-machine run still reported `TP=0`, `FA=83`, so detector tuning should not be the first next step.
- The existing review concluded that the numeric truth conversion does **not** depend on the Tx-Rx midpoint/centroid used for plotting. `adsbToBistatic.m` computes truth directly from Tx and Rx geometry.
- The metadata-derived part timing in the saved log is still suspicious for a `1 s` burst with `2 s` spacing, so timing must remain part of the validation plan even after the geometry fixes.
- One detector-side correction landed during local regression:
  - `createRDM.m` now reports Doppler at the true FFT-bin centers instead of using an endpoint-inclusive `linspace`

## Do Not Reopen Without New Evidence

- Do not revert `alpha = fc/c`, `f_D = -(fc/c) * dR_excess/dt`, or `range_cell_m = c/fs` unless the development-machine rerun produces a concrete contradiction.
- Do not treat the midpoint in `plotBistaticEllipses3D.m` as the cause of `TP=0`.
- Do not start with broader CFAR sweeps until the timing A/B rerun is complete.
- Do not spend time re-patching console Doppler signs unless the printed values disagree with `track_histories.f_D_hz` on the real rerun.

## Checklist

### 1. Shared Doppler coupling convention  `[complete locally]`

- [x] Re-derive the bistatic Doppler model against the actual CAF convention used in `createRDM.m`.
- [x] Patch every shared `alpha` user to the same convention.
- [x] Update comments and help text so they no longer describe the old convention.

Final convention:
`alpha = fc/c`
`f_D = -alpha * dR_excess/dt`
`Rdot = -f_D / alpha`

Primary files touched:
`BistaticDataAnalysis/adsbToBistatic.m`
`BistaticDataAnalysis/helperDeriveBistaticConstants.m`
`BistaticDataAnalysis/initMeasurementSpaceKF.m`
`BistaticDataAnalysis/helperTracksLogToHistories.m`
`BistaticDataAnalysis/analyzeBistaticData.m`
`BistaticDataAnalysis/render_rdm_step.m`
`BistaticDataAnalysis/helperBistaticDopplerCoupling.m`
`BistaticDataAnalysis/helperBistaticDopplerFromRangeRate.m`
`BistaticDataAnalysis/helperBistaticRangeRateFromDoppler.m`
`BistaticDataAnalysis/test_adsbTruthPipeline.m`
`BistaticDataAnalysis/test_bistaticHelpers.m`

Local evidence:
- `bistaticTruthConventionTest.m` passed (`6/6`)
- `test_adsbTruthPipeline.m` passed
- `test_bistaticHelpers.m` passed

Next-session re-check:
- Confirm the real rerun uses the same sign in ADS-B truth, tracker display, and `track_histories.f_D_hz`.

### 2. Full 3D Tx-Rx baseline  `[complete locally]`

- [x] Change the baseline `L` in truth conversion to full 3D Tx-Rx separation.
- [x] Change the plotting geometry to use the same 3D baseline where appropriate.
- [x] Search for remaining horizontal-only baseline assumptions in active bistatic geometry code.

Status:
- Numeric truth conversion now uses `geom.baseline_3d_m`.
- Shared geometry now comes from `helperDeriveTxRxGeometry.m`.
- Plotting uses the same 3D baseline scalar but still uses the horizontal midpoint and bearing as a visualization approximation.

Primary files touched:
`BistaticDataAnalysis/adsbToBistatic.m`
`BistaticDataAnalysis/plotBistaticEllipses3D.m`
`BistaticDataAnalysis/analyzeBistaticData.m`
`BistaticDataAnalysis/helperDeriveTxRxGeometry.m`

Local evidence:
- `bistaticTruthConventionTest.m` asserts the 3D baseline and expected constant range shift.

Residual caveat:
- Treat the fixed-altitude ellipse drawing as visualization-only unless the next session specifically chooses to derive the exact 3D fixed-altitude locus.

### 3. Shared detector-grid conventions  `[complete locally]`

- [x] Make the shared range-cell constant match the detector axis used by `createRDM.m`.
- [x] Remove the remaining shared `c/(2*fs)` assumption from tracker/truth helper code.
- [x] Update tests and comments to match the final convention.
- [x] Fix `createRDM.m` Doppler reporting so the axis matches the actual FFT bin centers.

Final convention:
`range_cell_m = c/fs`
`doppler_bin_hz = prf/N_slow`

Primary files touched:
`BistaticDataAnalysis/createRDM.m`
`BistaticDataAnalysis/helperDeriveBistaticConstants.m`
`BistaticDataAnalysis/initMeasurementSpaceKF.m`
`BistaticDataAnalysis/trackTargets.m`
`BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m`
`BistaticDataAnalysis/runDetectionTruthDiagnostics.m`
`BistaticDataAnalysis/test_bistaticHelpers.m`
`BistaticDataAnalysis/test_adsbTruthPipeline.m`

Important note:
`runDetectionTruthDiagnostics.m` already contains logic to recover the detector spacing from saved `range_axis` data and correct stale `c/(2*fs)` snapshots where possible.
That replay-side correction should be kept, but the underlying shared constants still need to be fixed so new outputs are consistent by construction.

Local evidence:
- `bistaticTruthConventionTest.m` checks shared constants against the `createRDM` axes.
- `test_adsbTruthPipeline.m` verifies truth scoring uses detector-derived range and Doppler spacing during replay.

### 4. Tracker display Doppler sign  `[complete locally]`

- [x] Make the console and legend displays use the same Doppler convention as `helperTracksLogToHistories.m`.
- [x] Search for remaining active `alpha * Rdot` displays that should be `-alpha * Rdot`.

Status:
- `helperTracksLogToHistories.m`, `analyzeBistaticData.m`, and `render_rdm_step.m` now all use the same sign convention.

Primary files touched:
`BistaticDataAnalysis/helperTracksLogToHistories.m`
`BistaticDataAnalysis/analyzeBistaticData.m`
`BistaticDataAnalysis/render_rdm_step.m`

Next-session re-check:
- Verify on the real rerun that a confirmed track's printed Doppler matches the corresponding `track_histories.f_D_hz`.

### 5. Midpoint is not the numeric truth model  `[complete locally]`

- [x] Do not rewrite `adsbToBistatic.m` around a midpoint/centroid model.
- [x] Keep the numeric truth conversion based on Tx and Rx positions directly.
- [x] If plotting helpers use the midpoint, treat that as visualization geometry only.

Context:
The review already established that the Tx-Rx midpoint is only used in the ellipse-plotting path.
The numeric truth conversion is driven by `R_tx + R_rx - L`, not by centroid placement.

Primary files involved:
`BistaticDataAnalysis/adsbToBistatic.m`
`BistaticDataAnalysis/plotBistaticEllipses3D.m`

Reason to keep this note:
This is still true and should remain a guardrail for the next session.

### 6. Real packaged-session timing A/B rerun  `[pending]`

- [ ] Ensure `captures/20260616T160702` is available on the development machine.
- [ ] Re-run the same packaged session with metadata timing.
- [ ] Re-run it again with fallback timing.
- [ ] Compare TP/FA/miss counts and track bias after the geometry fixes land.
- [ ] Check whether tracker console Doppler, legend Doppler, and `track_histories.f_D_hz` agree on the rerun.

Context:
The saved run in `bistaticOutput.txt` used metadata timing and produced part starts `0.000, 7.750, 12.026, 16.271, ...`, which does not match the expected cadence for a `1 s` burst with `2 s` spacing.
That means timing can still mask or distort the effect of the geometry fixes.

Recommended rerun sequence on the development machine:

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

Or run the same A/B sequence through the dedicated helper:

```matlab
cd BistaticDataAnalysis
cmp = runTruthFixTimingComparison('20260616T160702');
cmp.comparison.summary_table
cmp.comparison.delta_table
```

Compare at minimum:
`out_meta.truth_metrics.n_tp`
`out_fallback.truth_metrics.n_tp`
`out_meta.truth_metrics.n_fa`
`out_fallback.truth_metrics.n_fa`
`out_meta.truth_metrics.trk_table`
`out_fallback.truth_metrics.trk_table`

Decision rule:
If geometry fixes materially improve only one timing mode, timing remains an active bug.
If neither timing mode improves, revisit detector localization and truth gates only after confirming the Doppler convention patch was applied everywhere.

If both timing modes still produce the same `TP` and `FA`, timing is probably not the dominant blocker anymore. In that case, check for a systematic measurement-space offset before doing more CFAR sweeps:

```matlab
off = estimateTruthMeasurementOffset(cmp.metadata_output);
off.summary
```

Interpretation:
- if compensated `TP` rises sharply, detector localization or truth projection is biased by an approximately constant `(ΔR, Δf)`
- if compensated `TP` stays near zero, the remaining problem is more likely weak target energy / RF front-end quality than a simple global offset

At that point, run the RF session audit before spending more time on CFAR or truth-gate tuning:

```matlab
rf = runSessionRFQualityAudit('20260616T160702');
rf.part_table
rf.summary
rf.assessment
```

Use the stricter goal when the intent is tracking-quality validation rather than only aircraft-presence detection:

```matlab
rf_track = runSessionRFQualityAudit('20260616T160702', ...
    'Goal', 'tracking_validation');
rf_track.assessment
```

Decision rule:
- if `rf.assessment.sufficient_for_goal` is false, fix RF/reference/cancellation quality before more detector tuning
- if the RF audit passes and compensated `TP` is still near zero, the next suspect is detector localization or thresholding rather than front-end sufficiency

### 7. Pre-patch versus post-patch comparison  `[pending]`

- [ ] Keep `C:\Users\pwilliam\agenticProjects\bistaticOutput.txt` as the pre-patch reference log.
- [ ] Compare new results against the saved file, not the earlier pasted terminal excerpt.
- [ ] Record whether any improvement is timing-sensitive, global, or absent.

Useful pre-patch references:
`bistaticOutput.txt` line 26: metadata timing source
`bistaticOutput.txt` lines 27-36: suspicious part start offsets
`bistaticOutput.txt` line 3335: truth gate widths
`bistaticOutput.txt` line 3369: `TP=0`, `FA=83`

## Next Session First Actions

1. Get `captures/20260616T160702` onto the development machine before making more code changes.
2. Run the metadata and fallback timing reruns from item 6.
3. Compare those outputs against `bistaticOutput.txt`.
4. Only after that decide whether the remaining problem is timing, localization, RF front-end quality, or detector tuning.
