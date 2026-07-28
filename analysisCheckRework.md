# Analysis Check Rework

This file tracks wrapper-side analysis checks that looked questionable during manual review of the synthetic walkthrough. The checks below were left unchanged in this session on purpose. The goal here is to capture what we saw, why the current behavior is suspect, and how we could revisit it later without losing context.

## C5 Rayleigh Noise-Floor Distribution Check

### What we saw

- The wrapper reported `Rayleigh ratio=2.025 (expected 3.660 +/-20%, Chunk-1 single-look (N_slow=200))`.
- The displayed histogram and the red Rayleigh-fit curve looked inconsistent enough that the warning was hard to interpret by eye.

### Why the current check is suspect

- In [BistaticDataAnalysis/assessDetections.m](BistaticDataAnalysis/assessDetections.m), the reported C5 metric switches to `config.single_look_noise_rdm` when that dataset is available, but the plotted histogram still uses `noise_linear` from the integrated post-mitigation RDM. That means the reported warning and the displayed PDF are not using the same source data.
- The current synthetic confidence preset is intentionally deterministic and low-noise. That makes the pure field-style Rayleigh-noise assumption weaker than it would be on a real noise-dominated capture.
- The current quiet-region selection is fixed in range and Doppler, so any residual synthetic structure or wrap-around behavior in that region can bias the result even if the main detector path is otherwise working.

### How we could consider fixing it later

1. Make the plotted histogram use the same dataset as the reported C5 metric, especially when `single_look_noise_rdm` is present.
2. Split the check behavior by context so synthetic-validation runs can use a different advisory policy from field-capture runs.
3. Revisit the quiet-region selection so it explicitly avoids known wrap-around or deterministic synthetic structure before asserting a Rayleigh-model warning.

## D9 High-SNR "Suspicious Threshold" Check

### What we saw

- The wrapper reported `6/145 detections above 25 dB SNR`.
- Some of the brightest detections were near the synthetic truth targets in the low-noise confidence scene, so the warning currently mixes "easy synthetic truth hit" behavior with "suspiciously bright unmatched detection" behavior.

### Why the current check is suspect

- The fixed `25 dB` threshold in [BistaticDataAnalysis/assessDetections.m](BistaticDataAnalysis/assessDetections.m) is based on a field-style assumption that real aircraft echoes should be weak.
- The walkthrough confidence preset intentionally turns off stochastic noise and uses a clean, inspectable synthetic scene. In that mode, truth-aligned synthetic detections can reasonably exceed the field-oriented threshold without indicating a broken generator.
- The current warning does not distinguish truth-associated detections from unmatched detections before flagging them.

### How we could consider fixing it later

1. Make the threshold mode-aware so synthetic-validation runs and field-capture runs do not share the same fixed brightness rule.
2. Separate truth-associated detections from unmatched detections before raising the warning.
3. Consider replacing the fixed threshold with a percentile-based or truth-relative prominence measure that better matches synthetic-validation goals.

## Current False-Alarm Interpretation For The Walkthrough Confidence Scene

### What we are seeing now

- The current walkthrough run produces a small number of truth-matched hits and a much larger number of unmatched detections.
- The false alarms are not coming from only one place.

### Why this is not purely a detector issue

- The readiness gate still fails `vertical_column_defect`, which means the synthetic data are still producing truth-aligned Doppler-column artifacts that can create extra unmatched detections near the target Dopplers.
- The detector is also intentionally somewhat permissive in the current wrapper configuration, so it is willing to pass more candidate peaks through to the truth-matching stage.

### How to interpret it for future work

1. Detector-tuning changes belong in the separate detector workstream already in progress.
2. Synthetic-data changes should stay focused on reducing the residual vertical-column and sidelobe-driven unmatched detections.
3. Until both sides improve, treat the current false-alarm count as a combined synthetic-artifact plus detector-tuning outcome rather than as a clean detector-only metric.
