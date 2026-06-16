# Next Session Handoff

Updated: June 16, 2026

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
