# Pluto Tone Precheck Design Spec

## Status

This document freezes the first-pass standalone design for the Pluto-driven tone precheck.

Phase 1 scope:

- Build the Pluto tone precheck as a standalone MATLAB module under `TestSetupTesting/`.
- Keep it separate from the working coordinated capture path until the standalone behavior is proven.
- Use it later as one pre-pipeline function call from the acquisition flow.

Phase 1 non-goals:

- No edits yet to `run_coordinated_hdtv_capture.sh`.
- No edits yet to `runLocalHDTVCapture.m`.
- No edits yet to packaged-session manifest handling.
- No edits yet to `BistaticDataAnalysis/`.
- No attempt to replace the ATSC direct-path precheck in `BistaticDataAnalysis/runDirectPathPrecheck.m`.

## Frozen Operating Assumptions

- The testing machine drives the Pluto transmitter directly.
- The N320 capture path remains the same one already used by `runLocalHDTVCapture.m`.
- Channel convention remains:
  - `RF0:RX2 -> CH1 / RX1 -> SURV`
  - `RF1:RX2 -> CH2 / RX2 -> REF`
- The precheck is a hardware-readiness gate only.
- A CW tone is acceptable for power, frequency, and path-health checks.
- A CW tone is not a hard inter-channel lag-calibration source.
- Raw `xcorr` remains advisory-only.
- There is no hard gate on reference-versus-surveillance power ratio.

## Native Function Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Pluto transmit one deterministic CW tone and leave it running during a short N320 capture | Communications Toolbox Support Package workflow using `sdrtx("Pluto")` with `transmitRepeat` | Add one wrapper that maps project capture settings to Pluto RF center, baseband tone offset, and deterministic start/stop handling |
| Reuse the existing dual-channel N320 capture path for the standalone precheck | `runLocalHDTVCapture.m` wrapper over `log_iq_n320_2antennas.m` | Keep the same `CenterFrequency_Hz`, `SampleRate_Hz`, `LOOffset_Hz`, and `Gain` conventions so later integration is one call-site addition, not a second capture stack |
| Read one short `.bb` capture and score each channel for tone presence, level, and frequency | `comm.BasebandFileReader` with Welch PSD style analysis | Add a dedicated scoring helper that computes CW-specific metrics instead of ATSC pilot metrics |
| Compare a new run against a commissioned baseline and emit a tight operator summary | Existing project pattern in `runDirectPathPrecheck.m` and `summarizeRFQualityAudit.m` | Keep the summary compact to the agreed metrics and carry fail/warn codes explicitly in the result struct |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Pluto transmitter connection and repeat transmit | `sdrtx("Pluto")`, `transmitRepeat` | `tx = sdrtx("Pluto"); transmitRepeat(tx, waveform);` |
| Deterministic CW waveform generation | `dsp.SineWave` | `tone = dsp.SineWave("Frequency", f0, "SampleRate", fs);` |
| Baseband file readback | `comm.BasebandFileReader` | `reader = comm.BasebandFileReader(path, "SamplesPerFrame", N);` |
| Tone detect margin from spectrum | `pwelch` | `[pxx, f] = pwelch(x, window, noverlap, nfft, fs, "centered");` |
| Exact tone-bin power check | `goertzel` | `y = goertzel(x, k);` |
| Local spectral peak extraction | `findpeaks` | `[pks, locs] = findpeaks(psd_db, f_hz);` |
| Advisory inter-channel lag check | `xcorr` | `[c, lags] = xcorr(x1, x2, maxLag, "coeff");` |

## Frequency and Naming Conventions

- `CenterFrequency_Hz` is the value written into the `.bb` header by the existing N320 capture writer.
- `LOOffset_Hz` is the existing N320 analog tuning offset.
- `CaptureTuneFrequency_Hz = CenterFrequency_Hz + LOOffset_Hz`.
- `ToneOffset_Hz` is the expected tone location in the captured complex baseband, relative to `CaptureTuneFrequency_Hz`.
- `ToneRFFrequency_Hz = CaptureTuneFrequency_Hz + ToneOffset_Hz`.
- Pluto transmit setup shall be defined so the received tone appears at `ToneOffset_Hz` in the captured baseband.
- All summary frequency errors are reported relative to `ToneOffset_Hz`.

## Summary Contract

The operator summary must remain tight. It reports only:

- Overall verdict: `PASS`, `WARN`, or `FAIL`
- Baseline ID
- Reference line:
  - detect margin above local floor `[dB]`
  - frequency error from expected offset `[Hz]`
  - level `[dBFS]`
  - baseline delta `[dB]`
- Surveillance line:
  - the same four metrics
- Joint line:
  - channel-to-channel frequency delta `[Hz]`
- Fail reason codes only when status is `WARN` or `FAIL`

Canonical text shape:

```text
PLUTO PRECHECK: PASS | baseline garage_v1
REF  (CH2/RX2): detect +14.2 dB | freq err 0.8 kHz | level -18.6 dBFS (dBase +0.7 dB)
SURV (CH1/RX1): detect +8.9 dB  | freq err 1.1 kHz | level -29.4 dBFS (dBase -0.5 dB)
JOINT: channel freq delta 0.3 kHz
```

## Public API

### 1. `runPlutoTonePrecheck`

```matlab
result = runPlutoTonePrecheck( ...
    'BaselinePath', baselinePath, ...
    'CaptureRoot', captureRoot, ...
    'RadioName', "My USRP N320", ...
    'CaptureFileBase', "pluto_tone_precheck", ...
    'CenterFrequency_Hz', 540e6, ...
    'SampleRate_Hz', 6.144e6, ...
    'LOOffset_Hz', 200e3, ...
    'Gain', [30 50], ...
    'ToneOffset_Hz', 250e3, ...
    'ToneAmplitude', 0.5, ...
    'CaptureDuration_s', 0.25, ...
    'PlotFigures', true, ...
    'Verbose', true);
```

Frozen behavior:

- `BaselinePath` is required.
- Baseline settings are loaded and checked before any hardware action.
- Settings mismatch is based on:
  - `CenterFrequency_Hz`
  - `SampleRate_Hz`
  - `LOOffset_Hz`
  - `Gain`
  - `ToneOffset_Hz`
  - `ToneAmplitude`
- The function starts Pluto TX, performs one short dual-channel N320 capture, scores both channels, compares to baseline, writes artifacts, and returns one result struct.
- `status` is derived as:
  - `FAIL` if `fail_codes` is non-empty
  - `WARN` if `fail_codes` is empty and `warn_codes` is non-empty
  - `PASS` otherwise
- `overall_pass` is `true` only when `status == "PASS"`.

### 2. `commissionPlutoToneBaseline`

```matlab
baseline = commissionPlutoToneBaseline( ...
    'BaselineRoot', baselineRoot, ...
    'BaselineID', baselineID, ...
    'SiteID', siteID, ...
    'PlacementID', placementID, ...
    'PlacementNotes', placementNotes, ...
    'Thresholds', thresholds, ...
    'RadioName', "My USRP N320", ...
    'CaptureFileBase', "pluto_tone_baseline", ...
    'CenterFrequency_Hz', 540e6, ...
    'SampleRate_Hz', 6.144e6, ...
    'LOOffset_Hz', 200e3, ...
    'Gain', [30 50], ...
    'ToneOffset_Hz', 250e3, ...
    'ToneAmplitude', 0.5, ...
    'CaptureDuration_s', 0.25, ...
    'NumRuns', 3, ...
    'PlotFigures', true, ...
    'Verbose', true);
```

Frozen behavior:

- `Thresholds` is stored verbatim in the baseline file and becomes the authoritative gate source for later runs.
- `NumRuns` commissioning captures are allowed so the baseline statistics can be aggregated by median.
- The baseline function writes both a MATLAB `.mat` baseline file and a JSON mirror.
- The returned `baseline` struct uses the exact baseline schema below.

### 3. `reviewPlutoTonePrecheckResult`

```matlab
result = reviewPlutoTonePrecheckResult( ...
    source, ...
    'PlotFigures', true, ...
    'Verbose', true);
```

Accepted `source` values:

- run-folder path
- `result.mat` path
- `result.json` path
- in-memory result struct

Frozen behavior:

- The function reloads a prior result, validates the schema, reprints the tight summary, and optionally regenerates plots from the saved capture or saved metrics.
- It does not perform new hardware actions.

## Result Struct Schema

Top-level fields are frozen as:

```matlab
result.schema_version
result.run_id
result.created_utc
result.overall_pass
result.status
result.fail_codes
result.warn_codes
result.settings
result.capture_info
result.channel_map
result.reference_metrics
result.surveillance_metrics
result.joint_metrics
result.baseline_comparison
result.precheck_summary
result.artifact_paths
```

### `result.settings`

```matlab
settings.baseline_path
settings.capture_root
settings.radio_name
settings.capture_file_base
settings.center_frequency_hz
settings.sample_rate_hz
settings.lo_offset_hz
settings.capture_tune_frequency_hz
settings.gain
settings.tone_offset_hz
settings.tone_rf_frequency_hz
settings.tone_amplitude
settings.capture_duration_s
settings.plot_figures
settings.verbose
```

### `result.capture_info`

```matlab
capture_info.capture_session_id
capture_info.capture_file_path
capture_info.local_capture_files
capture_info.recording_utc
capture_info.header_center_frequency_hz
capture_info.header_lo_offset_hz
capture_info.header_tune_frequency_hz
capture_info.header_sample_rate_hz
capture_info.samples_per_channel
capture_info.samples_scored
capture_info.slice_duration_s
capture_info.reader_metadata
```

### `result.channel_map`

```matlab
channel_map.reference_label
channel_map.reference_channel_index
channel_map.reference_rx_label
channel_map.surveillance_label
channel_map.surveillance_channel_index
channel_map.surveillance_rx_label
```

Frozen values:

- `reference_label = "REF"`
- `reference_channel_index = 2`
- `reference_rx_label = "CH2/RX2"`
- `surveillance_label = "SURV"`
- `surveillance_channel_index = 1`
- `surveillance_rx_label = "CH1/RX1"`

### `result.reference_metrics` and `result.surveillance_metrics`

Both channel metric structs use the same exact field list:

```matlab
metrics.channel_label
metrics.channel_index
metrics.rx_label
metrics.tone_found
metrics.expected_frequency_hz
metrics.measured_frequency_hz
metrics.frequency_error_hz
metrics.level_dbfs
metrics.tone_peak_dbfs
metrics.local_floor_dbfs
metrics.detect_margin_db
metrics.level_delta_vs_baseline_db
metrics.status
metrics.fail_codes
metrics.warn_codes
```

Definitions:

- `level_dbfs` is whole-channel RMS level.
- `tone_peak_dbfs` is the detected tone-line level from the spectral scorer.
- `local_floor_dbfs` is the local spectral floor near the expected tone.
- `detect_margin_db = tone_peak_dbfs - local_floor_dbfs`.
- `level_delta_vs_baseline_db` is signed and uses the same channel in the commissioned baseline.

### `result.joint_metrics`

```matlab
joint_metrics.channel_frequency_delta_hz
joint_metrics.xcorr_lag_samples
joint_metrics.xcorr_lag_seconds
joint_metrics.xcorr_peak_db
joint_metrics.xcorr_note
joint_metrics.status
joint_metrics.fail_codes
joint_metrics.warn_codes
```

Frozen behavior:

- `channel_frequency_delta_hz = abs(reference_metrics.measured_frequency_hz - surveillance_metrics.measured_frequency_hz)`.
- `channel_frequency_delta_hz` is a hard gate.
- `xcorr_*` fields are advisory only.
- `JOINT_XCORR_ADVISORY` may produce a warning but never a fail.

### `result.baseline_comparison`

```matlab
baseline_comparison.baseline_id
baseline_comparison.settings_match
baseline_comparison.settings_mismatch_fields
baseline_comparison.reference_level_delta_db
baseline_comparison.surveillance_level_delta_db
baseline_comparison.comparison_applied
```

### `result.precheck_summary`

```matlab
precheck_summary.headline
precheck_summary.reference_line
precheck_summary.surveillance_line
precheck_summary.joint_line
precheck_summary.reason_line
precheck_summary.text_block
```

`text_block` is the newline-joined operator summary text.

### `result.artifact_paths`

```matlab
artifact_paths.run_folder
artifact_paths.result_mat
artifact_paths.result_json
artifact_paths.summary_txt
artifact_paths.summary_png
artifact_paths.capture_file
```

## Baseline File Schema

Top-level baseline fields are frozen as:

```matlab
baseline.schema_version
baseline.baseline_id
baseline.created_utc
baseline.site_id
baseline.placement_id
baseline.placement_notes
baseline.settings
baseline.channel_map
baseline.statistics
baseline.thresholds
baseline.commissioning
baseline.provenance
```

### `baseline.settings`

```matlab
settings.radio_name
settings.capture_file_base
settings.center_frequency_hz
settings.sample_rate_hz
settings.lo_offset_hz
settings.capture_tune_frequency_hz
settings.gain
settings.tone_offset_hz
settings.tone_rf_frequency_hz
settings.tone_amplitude
settings.capture_duration_s
```

### `baseline.channel_map`

Use the exact same `channel_map` schema and values as the runtime result.

### `baseline.statistics`

```matlab
statistics.reference
statistics.surveillance
statistics.joint
```

`statistics.reference` and `statistics.surveillance` both use:

```matlab
stats.level_dbfs
stats.tone_peak_dbfs
stats.local_floor_dbfs
stats.detect_margin_db
stats.measured_frequency_hz
```

`statistics.joint` uses:

```matlab
joint.channel_frequency_delta_hz
joint.xcorr_lag_samples
joint.xcorr_lag_seconds
joint.xcorr_peak_db
```

All baseline statistics are median-aggregated across `NumRuns`.

### `baseline.thresholds`

```matlab
thresholds.reference
thresholds.surveillance
thresholds.joint
```

`thresholds.reference` and `thresholds.surveillance` both use:

```matlab
threshold.detect_margin_warn_db
threshold.detect_margin_min_db
threshold.frequency_error_warn_hz
threshold.frequency_error_max_hz
threshold.level_max_dbfs
threshold.baseline_level_drift_warn_db
threshold.baseline_level_drift_max_db
```

`thresholds.joint` uses:

```matlab
joint.channel_frequency_delta_warn_hz
joint.channel_frequency_delta_max_hz
joint.xcorr_peak_advisory_min_db
joint.xcorr_lag_advisory_max_samples
```

Frozen policy:

- Threshold numeric values are baseline-owned, not hard-coded in the runtime result.
- There is no threshold field for reference-versus-surveillance power ratio.
- `xcorr` threshold fields remain advisory only.

### `baseline.commissioning`

```matlab
commissioning.num_runs
commissioning.aggregation_method
commissioning.run_ids
commissioning.result_paths
```

Frozen values:

- `aggregation_method = "median"`

### `baseline.provenance`

```matlab
provenance.baseline_mat_path
provenance.baseline_json_path
provenance.matlab_release
provenance.git_branch
provenance.git_commit
```

## Fail and Warn Codes

### Fail Codes

- `BASELINE_LOAD_FAILED`
- `BASELINE_SCHEMA_UNSUPPORTED`
- `BASELINE_SETTINGS_MISMATCH`
- `PLUTO_CONNECT_FAILED`
- `PLUTO_TX_START_FAILED`
- `N320_CAPTURE_FAILED`
- `CAPTURE_FILE_MISSING`
- `CAPTURE_READ_FAILED`
- `REFERENCE_TONE_NOT_FOUND`
- `REFERENCE_DETECT_MARGIN_LOW`
- `REFERENCE_FREQUENCY_ERROR_HIGH`
- `REFERENCE_LEVEL_TOO_HIGH`
- `REFERENCE_BASELINE_LEVEL_DRIFT`
- `SURVEILLANCE_TONE_NOT_FOUND`
- `SURVEILLANCE_DETECT_MARGIN_LOW`
- `SURVEILLANCE_FREQUENCY_ERROR_HIGH`
- `SURVEILLANCE_LEVEL_TOO_HIGH`
- `SURVEILLANCE_BASELINE_LEVEL_DRIFT`
- `CHANNEL_FREQUENCY_MISMATCH`

### Warn Codes

- `REFERENCE_DETECT_MARGIN_NEAR_LIMIT`
- `SURVEILLANCE_DETECT_MARGIN_NEAR_LIMIT`
- `REFERENCE_BASELINE_LEVEL_DRIFT_NEAR_LIMIT`
- `SURVEILLANCE_BASELINE_LEVEL_DRIFT_NEAR_LIMIT`
- `CHANNEL_FREQUENCY_DELTA_NEAR_LIMIT`
- `JOINT_XCORR_ADVISORY`

## Code-to-Metric Mapping

- `REFERENCE_TONE_NOT_FOUND`
  - no tone candidate accepted on `REF`
- `REFERENCE_DETECT_MARGIN_LOW`
  - `REF.detect_margin_db < baseline.thresholds.reference.detect_margin_min_db`
- `REFERENCE_FREQUENCY_ERROR_HIGH`
  - `abs(REF.frequency_error_hz) > baseline.thresholds.reference.frequency_error_max_hz`
- `REFERENCE_LEVEL_TOO_HIGH`
  - `REF.level_dbfs > baseline.thresholds.reference.level_max_dbfs`
- `REFERENCE_BASELINE_LEVEL_DRIFT`
  - `abs(REF.level_delta_vs_baseline_db) > baseline.thresholds.reference.baseline_level_drift_max_db`
- `SURVEILLANCE_TONE_NOT_FOUND`
  - no tone candidate accepted on `SURV`
- `SURVEILLANCE_DETECT_MARGIN_LOW`
  - `SURV.detect_margin_db < baseline.thresholds.surveillance.detect_margin_min_db`
- `SURVEILLANCE_FREQUENCY_ERROR_HIGH`
  - `abs(SURV.frequency_error_hz) > baseline.thresholds.surveillance.frequency_error_max_hz`
- `SURVEILLANCE_LEVEL_TOO_HIGH`
  - `SURV.level_dbfs > baseline.thresholds.surveillance.level_max_dbfs`
- `SURVEILLANCE_BASELINE_LEVEL_DRIFT`
  - `abs(SURV.level_delta_vs_baseline_db) > baseline.thresholds.surveillance.baseline_level_drift_max_db`
- `CHANNEL_FREQUENCY_MISMATCH`
  - `joint.channel_frequency_delta_hz > baseline.thresholds.joint.channel_frequency_delta_max_hz`
- `REFERENCE_DETECT_MARGIN_NEAR_LIMIT`
  - `REF.detect_margin_db` is above the fail threshold but below `detect_margin_warn_db`
- `SURVEILLANCE_DETECT_MARGIN_NEAR_LIMIT`
  - `SURV.detect_margin_db` is above the fail threshold but below `detect_margin_warn_db`
- `REFERENCE_BASELINE_LEVEL_DRIFT_NEAR_LIMIT`
  - `abs(REF.level_delta_vs_baseline_db)` is above the warn threshold but not above the fail threshold
- `SURVEILLANCE_BASELINE_LEVEL_DRIFT_NEAR_LIMIT`
  - `abs(SURV.level_delta_vs_baseline_db)` is above the warn threshold but not above the fail threshold
- `CHANNEL_FREQUENCY_DELTA_NEAR_LIMIT`
  - `joint.channel_frequency_delta_hz` is above the warn threshold but not above the fail threshold
- `JOINT_XCORR_ADVISORY`
  - `abs(joint.xcorr_lag_samples)` or `joint.xcorr_peak_db` indicates reduced coherence, but this does not block the run

## Artifact Layout

Standalone run artifact root:

```text
TestSetupTesting/plutoPrecheckRuns/<run_id>/
```

Required files:

```text
result.mat
result.json
summary.txt
summary.png
capture/<capture_file>
```

Baseline artifact root:

```text
TestSetupTesting/plutoToneBaselines/<baseline_id>/
```

Required files:

```text
baseline.mat
baseline.json
summary.txt
summary.png
commissioning_runs/
```

## Planned Helper Split

The standalone implementation should be decomposed into:

- `helperPlutoToneBuildWaveform.m`
- `helperPlutoToneStartTx.m`
- `helperPlutoToneCaptureN320.m`
- `helperPlutoToneReadCapture.m`
- `helperPlutoToneScoreChannel.m`
- `helperPlutoToneScoreJointMetrics.m`
- `helperPlutoToneCompareBaseline.m`
- `helperPlutoTonePlotSummary.m`
- `helperPlutoToneWriteArtifacts.m`

## Immediate Implementation Order

1. Implement the schema and artifact-writing helpers first.
2. Implement the channel scorer and joint scorer next.
3. Implement baseline commissioning on top of the scorers.
4. Implement the full runtime precheck wrapper last.
5. Leave acquisition-pipeline integration out of scope until the standalone flow is proven.
