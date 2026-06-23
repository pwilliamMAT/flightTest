# Next Session Handoff

Updated: June 22, 2026

## June 22, 2026 RF Gain-Sweep Handoff

This is the current top-priority handoff. Older ADS-B truth notes remain below for background, but the immediate blocker is RF sufficiency on the capture chain.

### Current RF Blocker

- Session `20260618T160532` was audited with `runSessionRFQualityAudit` and did not clear the RF sufficiency bar for `aircraft_detection`.
- Key summary fields from that audit:
  - `overall_pass_fraction = 0`
  - `reference_pass_fraction = 0`
  - `level_pass_fraction = 1`
  - `pilot_pass_fraction = 0`
  - `lag_pass_fraction = 1`
  - `zero_doppler_pass_fraction = 0.6`
  - `pilot_freq_span_hz = 5.676e6`
  - `any_pilot_mirrored = true`
  - `sufficient_for_goal = false`
- Interpretation:
  - the direct path is present and lag-isolated
  - the blocker is weak or inconsistent coherent pilot quality on the reference chain
  - ECA-C suppression is only partially consistent after cancellation
  - raw channel-power asymmetry is not a valid failure signal by itself on this hardware

### Hardware Context That Must Carry Forward

- `RX0 / CH1`: surveillance antenna is an HDTV Yagi with a built-in amplifier
- `RX1 / CH2`: reference antenna is a small telescoping omni with no amplifier
- Because of that hardware split:
  - `CH1` being materially stronger than `CH2` is expected
  - do not use power asymmetry alone to argue for a channel swap
  - raising SDR gain on the reference channel is a valid bounded test
  - a reference-side LNA / amplifier is still an in-scope hardware fix if coherence stays weak

### Gain Sweep Already Performed By The Operator

- The user has already run three coordinated capture sessions with fixed surveillance gain and stepped reference gain:
  - `--gain 28,48`
  - `--gain 28,54`
  - `--gain 28,60`
- The outputs and session IDs from those runs had not yet been shared in-thread at the time this handoff was written.

### What The Next Agent Should Do When Sweep Outputs Arrive

1. Map each gain setting to its packaged session ID.
2. For each session, run the RF audit and capture both summary and per-part metrics:

```matlab
cd BistaticDataAnalysis

rf = runSessionRFQualityAudit('<session_id>', ...
    'Goal', 'aircraft_detection');

rf.summary
rf.assessment
rf.part_table(:, {'part_index','level_dbfs','pilot_snr_db','pilot_pass', ...
    'pilot_freq_hz','pilot_mirrored','lag_pass','suppression_db', ...
    'after_margin_db','after_margin_pass','zero_doppler_pass', ...
    'overall_pass'})
```

3. If the actual HDTV illuminator center frequency is known, pass the same explicit `IlluminatorCenterFrequencyHz` for every compared session so the pilot search uses the same channel geometry across the sweep.
4. Compare the sweep primarily on:
  - `pilot_snr_db`
  - `pilot_pass_fraction`
  - `pilot_freq_span_hz`
  - `any_pilot_mirrored`
  - `zero_doppler_pass_fraction`
  - `after_margin_pass_fraction`
  - `sufficient_for_goal`
5. Treat `level_dbfs` as secondary. A healthier ADC level does not matter if pilot coherence and pilot-frequency consistency stay poor.

### Expected Interpretations

- If higher reference gain materially improves pilot coherence and frequency consistency, SDR gain was part of the problem.
- If `level_dbfs` rises but `pilot_pass_fraction` stays near zero and the pilot remains mirrored or unstable, more SDR gain alone is not enough and the next step is hardware:
  - reference-side LNA / preamplifier
  - better reference antenna
  - better reference antenna placement / aim
- If `60 dB` improves pilot metrics but worsens residual ridge cleanup or stability, do not assume max gain is best. Pick the lowest gain that improves coherence without degrading the post-ECA residual.

### Relevant Files

- `BistaticDataAnalysis/runDirectPathPrecheck.m`
- `BistaticDataAnalysis/runSessionRFQualityAudit.m`
- `BistaticDataAnalysis/summarizeRFQualityAudit.m`
- `TestSetupTesting/run_coordinated_hdtv_capture.sh`
- `TestSetupTesting/runLocalHDTVCapture.m`

## June 18, 2026 Review Handoff

This file is superseded by the new review-oriented test and validation record at `BistaticDataAnalysis/adsbTruthFixTestPlan.md`.

### Current Status

- The ADS-B truth convention patch is now implemented locally.
- Shared conventions are unified around:
  - `R_excess = R_tx + R_rx - L_3D`
  - `f_D = -(fc/c) * dR_excess/dt`
  - `Rdot = -f_D / (fc/c)`
  - `range_cell_m = c/fs`
- Shared helper functions were added so truth conversion, tracker initialization, track-history export, and display code all use the same formulas.
- `createRDM.m` was also corrected to report Doppler at the true FFT-bin centers instead of an endpoint-inclusive `linspace`, because the old axis did not match the actual detector bins.

### Verification Completed On This Machine

- `bistaticTruthConventionTest.m`: `6/6` passed
- `runDetectorReplaySweepTest.m`: `3/3` passed
- `test_bistaticHelpers.m`: passed
- `test_adsbTruthPipeline.m`: passed
- MATLAB Code Analyzer clean on the touched convention/helper files

### Validation Still Blocked Locally

- The packaged session data is not present on this machine:
  - `captures/` does not exist
  - `captures/20260616T160702` does not exist
- Because of that, the required real-data timing A/B rerun remains outstanding and must still be run on the development machine.

### Required Development-Machine Validation

Run both timing modes on session `20260616T160702`:

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

- `n_tp`
- `n_fa`
- `n_miss`
- track-level range and Doppler bias / RMSE
- output against the pre-patch reference log `C:\Users\pwilliam\agenticProjects\bistaticOutput.txt`

### Code Review Focus

- Review `createRDM.m` carefully. The Doppler-axis correction is the only detector-side behavior change discovered during regression.
- Review the new shared helpers and confirm all shared truth/tracker conversions use them.
- Treat `plotBistaticEllipses3D.m` as visualization-only. It now uses the shared 3D baseline scalar, but the fixed-altitude contour drawing still uses horizontal midpoint/bearing as an approximation.

## New Pending Fix Checklist

- A dedicated implementation checklist now lives at `BistaticDataAnalysis/adsbTruthFixChecklist.md`.
- That file is now the current source of truth for the next session:
  - locally completed convention fixes are checked off
  - remaining real-data timing and validation tasks are left open
  - the next agent should start at the pending rerun items, not re-open the local convention patch by default

## Current Status

- Work is split across two machines:
  - this machine: code changes and local MATLAB unit/synthetic validation
  - development machine: real replay runs against the actual packaged session and replay snapshot
- Detector/truth replay fix implemented locally:
  - truth matching now derives range and Doppler bin spacing from saved detector axes when available
  - replay truth bundles are refreshed from detector axes before scoring
  - this fix is in detector/truth replay code only, not tracker behavior
- Development-machine result so far:
  - a looser truth-gate replay run now produces at most `n_tp = 2` out of `216` visible truth samples
  - detector sensitivity sweeps still inflate false alarms much faster than they improve truth hits
  - interpretation: CFAR sensitivity is not the main bottleneck
  - likely causes are:
    - weak surveillance-channel SNR before CFAR
    - a systematic range, Doppler, or timing offset
    - or an `fc` mismatch between the actual capture and the truth projection
- New operator note from June 16:
  - the surveillance antenna in this dataset may have been tuned near `978 MHz`
  - the passive-radar collection band for this workflow is normally HDTV around `540-600 MHz`
  - if true, that antenna mismatch is a credible front-end cause of poor target detectability
  - the replay logs for this run show `adsbToBistatic` using `fc = 540 MHz`, so verify the actual capture center frequency before making more Doppler-based conclusions

## Development-Machine Result So Far

The latest looser truth-gate sweep reported:

- `baseline`: `n_detections = 305`, `n_tp = 0`
- `pfa3e4`: `n_detections = 1273`, `n_tp = 0`
- `pfa1e3`: `n_detections = 5854`, `n_tp = 2`
- `os065`: `n_detections = 3439`, `n_tp = 1`
- `os060`: `n_detections = 8952`, `n_tp = 2`
- `ca_baseline`: `n_detections = 10180`, `n_tp = 2`

Interpretation:

- loosening CFAR can recover an occasional truth hit
- but the best case is still only `2 / 216` visible truth samples
- the dominant effect of looser CFAR is false-alarm growth, not meaningful Pd improvement

This still suggests the next step should be baseline truth/detection inspection plus RF/frequency verification, not more broad CFAR sweeps.

## Validation Already Done On This Machine

- `runDetectorReplaySweepTest` passed: 3/3 tests
- `test_adsbTruthPipeline.m` passed
- MATLAB Code Analyzer passed on:
  - `BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m`
  - `BistaticDataAnalysis/runDetectionTruthDiagnostics.m`
  - `BistaticDataAnalysis/runDetectorReplaySweep.m`
- `README.md` was updated with replay truth-grid notes

## Immediate Next Step Tomorrow

Assuming the latest code is already synced to the development machine, do these checks in order on the development machine.

1. Verify the actual capture center frequency against the truth bundle:

```matlab
r = replay;   % or replay_loose / whatever variable holds the finished run
b = r.case_results(1);   % baseline case

b.truth_diag_output.truth_diag_input.fc
b.truth_diag_output.truth_diag_input.range_cell_m
b.truth_diag_output.truth_metrics.gate_range_m
b.truth_diag_output.truth_metrics.gate_doppler_hz
```

2. Keep using the baseline case for truth/detection inspection and collect:

```matlab
s = b.truth_diag_output.check_summary;
[s.n_aircraft_overlap s.n_truth_visible_samples s.n_truth_samples_in_display ...
 s.n_detections s.n_tp s.n_fa s.n_miss]
s.per_part_truth_points
s.per_part_detection_counts
```

Also capture:

- a screenshot of the baseline detection-vs-truth figure
- the baseline console output around `runDetectionTruthDiagnostics`
- the actual capture metadata that confirms whether this session was centered near `540 MHz` or `600 MHz`
- any notes about which antenna was connected to the surveillance channel during this session

Those outputs should determine whether the next debugging pass is:

- RF front-end mismatch
- alignment / timing / geometry
- or detector localization near the expected truth loci

## Recommended Fast Workflow Tomorrow

Use one baseline case with truth enabled for diagnosis:

```matlab
baseline = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases(1), ...
    'GateRangeCells', 5, ...
    'GateDopplerBins', 5, ...
    'TimeGateS', 0.5, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);
```

Use detector-only screening for broad parameter sweeps:

```matlab
screen = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'RunTruthDiagnostics', false, ...
    'PlotCases', [], ...
    'PlotDetectionTimeSeries', false, ...
    'PlotRDMOverlays', false, ...
    'Verbose', false);
```

Then truth-score only 1-2 selected cases:

```matlab
followup = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases([1 3]), ...
    'GateRangeCells', 5, ...
    'GateDopplerBins', 5, ...
    'TimeGateS', 0.5, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);
```

## Why Replay Sweeps Are Slow

Current replay runtime scales roughly with:

- number of detector cases
- multiplied by number of saved detector blocks

And when truth scoring is enabled, each case also repeats:

- ADS-B load
- bistatic projection
- truth alignment
- detection-vs-truth scoring

That is why:

- one-case truth runs are the right diagnostic tool
- broad sweeps should usually run with `RunTruthDiagnostics = false`

## Likely Next Code Change If Runtime Is Still Too Slow

If replay iteration is still too slow after the workflow above, the next useful code change is:

- add `PartIndices` or time-window support to `runDetectorReplaySweep`

or:

- cache ADS-B load, projection, and alignment once per replay instead of recomputing them for every case

## Touched Files This Session

- `BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m`
- `BistaticDataAnalysis/runDetectionTruthDiagnostics.m`
- `BistaticDataAnalysis/runDetectorReplaySweep.m`
- `BistaticDataAnalysis/test_adsbTruthPipeline.m`
- `BistaticDataAnalysis/assessTruthVsDetections.m`
- `README.md`
- `NEXT_SESSION_HANDOFF.md`

## Open Questions

- Is the actual capture center frequency for this session `540 MHz`, `600 MHz`, or something else?
- Was the surveillance antenna really tuned near `978 MHz` during this capture, and if so how much surveillance-channel SNR was lost?
- Does the real baseline replay show truth samples inside the displayed measurement space?
- Are detections broadly scattered away from truth, or clustered with a systematic offset?
- Is the next step RF hardware correction or alignment/timing/geometry calibration rather than more CFAR tuning?
