# Flight Test Data Collection & Passive Bistatic Radar System

## Project Overview

This repository contains a complete passive bistatic radar system and multi-sensor data collection platform for aircraft detection, localization, and tracking validation. The system is designed to generate shareable datasets for verifying MATLAB Radar and Sensor Fusion and Tracking Toolbox functions.

### System Goals

1. **Passive Bistatic Radar:** Detect and localize aircraft using TV broadcast signals (ATSC) as illuminators of opportunity
2. **Ground Truth Collection:** Capture ADS-B and GPS data for validation and performance assessment
3. **Multi-Sensor Fusion:** Integrate passive radar with RF beacon tracking for enhanced situational awareness
4. **Toolbox Validation:** Generate real-world datasets for testing MathWorks radar and tracking algorithms

## Integration Checkpoint and Architecture Reference

The branch `checkpoint/working-integration-nonfunctional-detector-2026-07-08` is the preservation milestone for the current integrated replay, truth-diagnostic, visualization-profile, and offline-toolbox-evaluation work. Treat it as a durable handoff point for a **working integration with a still non-functional detector**, not as a release or detector-tuned baseline.

The System Composer quick-reference model lives under `BistaticDataAnalysis/architecture/`:

- `bistaticAnalysisQuickReference.slx` - logical pipeline reference model
- `bistaticAnalysisQuickReference.png` - exported static snapshot of that diagram
- `buildBistaticAnalysisArchitecture.m` - reproducible create/open helper

The coordinated capture presentation flowchart also lives there:

- `coordinatedCaptureAnalysisFlowchart.pptx` - single-slide 16:9 PowerPoint flowchart for the testing-machine to MATLAB handoff
- `coordinatedCaptureAnalysisFlowchart.png` - exported slide preview for quick review
- `buildCoordinatedCaptureAnalysisFlowchart.ps1` - reproducible PowerPoint generator

The active analysis presentation flowchart also lives there:

- `bistaticDataAnalysisPipelineFlowchart.pptx` - single-slide 16:9 PowerPoint flowchart for the current `BistaticDataAnalysis` mainline plus ADS-B truth evaluation branch
- `bistaticDataAnalysisPipelineFlowchart.png` - exported slide preview for quick review
- `buildBistaticDataAnalysisPipelineFlowchart.ps1` - reproducible PowerPoint generator

Open the current model without rebuilding it:

```matlab
cd BistaticDataAnalysis/architecture
buildBistaticAnalysisArchitecture('OpenModel', true, 'ExportDiagram', true);
```

Force a full rebuild of the model and refresh the PNG snapshot:

```matlab
cd BistaticDataAnalysis/architecture
info = buildBistaticAnalysisArchitecture('ForceRebuild', true, 'OpenModel', true, 'ExportDiagram', true);
```

Rebuild the coordinated-capture PowerPoint slide and refresh its PNG preview:

```powershell
powershell -ExecutionPolicy Bypass -File BistaticDataAnalysis\architecture\buildCoordinatedCaptureAnalysisFlowchart.ps1
```

Rebuild the active-analysis PowerPoint slide and refresh its PNG preview:

```powershell
powershell -ExecutionPolicy Bypass -File BistaticDataAnalysis\architecture\buildBistaticDataAnalysisPipelineFlowchart.ps1
```

This architecture artifact is a **pipeline reference only**. It is not an executable processing model, and it does not replace the MATLAB analysis entrypoints under `BistaticDataAnalysis/`.

The standalone Pluto tone precheck is being developed separately from the working acquisition path. The frozen phase-1 contract for that work lives in [TestSetupTesting/plutoTonePrecheckDesignSpec.md](TestSetupTesting/plutoTonePrecheckDesignSpec.md).
The current standalone slice now includes the live wrapper `runPlutoTonePrecheck.m`, baseline loading and settings validation, deterministic Pluto waveform/TX startup, reuse of the existing N320 capture path, `.bb` readback through `BistaticDataAnalysis/loadIQData.m`, result scoring, artifact writing, saved-result review, and baseline commissioning from prior standalone run artifacts.
The wrapper still remains standalone and is not yet integrated into `run_coordinated_hdtv_capture.sh` or the broader acquisition flow, and `commissionPlutoToneBaseline` still uses the temporary offline `RunSources` path rather than starting hardware itself.
If the Pluto support package runtime is unavailable on a given machine, the wrapper now fails early with `PLUTO_CONNECT_FAILED` and still writes a reviewable result folder instead of proceeding into the capture path.
A separate companion plan, [TestSetupTesting/PlutoWaveformPlan.md](TestSetupTesting/PlutoWaveformPlan.md), now documents a **Phase 2** standalone follow-on analysis over archived Phase 1 Pluto captures. It does not replace the active Phase 1 tone precheck.
For an SSH-friendly checked-in Stage 6 smoke-test entrypoint on the Phase 1 branch, use [TestSetupTesting/runPlutoToneStage6Smoke.m](TestSetupTesting/runPlutoToneStage6Smoke.m) from the `TestSetupTesting/` folder.
For a fixed-placement commissioning sweep that compares tone offsets and amplitudes before you choose a reusable Phase 1 baseline candidate, use [TestSetupTesting/runPlutoToneCommissioningSweep.m](TestSetupTesting/runPlutoToneCommissioningSweep.m).
If a sweep already finished its per-run captures but failed while assembling the top-level summary, recover the saved artifacts with [TestSetupTesting/reviewPlutoToneCommissioningSweep.m](TestSetupTesting/reviewPlutoToneCommissioningSweep.m) instead of rerunning the hardware immediately.
For a shareable plain-text Live Editor notebook that runs the current Phase 1 unit tests and smoke tests in order, use [TestSetupTesting/PlutoPhase1ValidationLive.m](TestSetupTesting/PlutoPhase1ValidationLive.m).
Treat that notebook as the primary Phase 1 verification entrypoint for both human review and future agentic sessions.
Open that notebook in the MATLAB Live Editor on the testing machine and use **Run All**. The run controls near the top let you skip individual smoke stages or enable the full wrapper once `baselinePath` is set.
That notebook now also records the accumulated Stage 6 field-trial matrix through the `599 MHz / 1.5 MHz` placement and amplitude experiments, the recovered fixed-placement commissioning sweep review for `stairwell_outside_box_nooelec_4p9in`, and the next recommended geometry-only follow-up test at `599 MHz / 250 kHz / ToneAmplitude 0.50`.
For an operator-facing testing-machine prescription that turns those follow-up recommendations into a concrete field procedure, use [TestSetupTesting/plutoBaselineCommissioningFieldPlan.md](TestSetupTesting/plutoBaselineCommissioningFieldPlan.md).
For the step-by-step Pluto calibration sequence, see the `Pluto Calibration Sequence` section in [TestSetupTesting/README.md](TestSetupTesting/README.md).
For a staged hardware bring-up checklist on the testing machine before running the calibration wrapper, see [TestSetupTesting/plutoCalibrationHardwareBringup.md](TestSetupTesting/plutoCalibrationHardwareBringup.md).
The bring-up checklist now includes the same observed field-trial matrix plus short operator notes about which physical setups and tone-level changes helped and which ones did not.

### Hardware Platform

- **USRP N320:** Phase-coherent dual-channel software-defined radio for HDTV passive radar (540 MHz, 6 MHz bandwidth)
- **Raspberry Pi 4B (Bullseye):** Data collection coordinator and ADS-B/GPS logger
- **RTL-SDR (×2):** Low-cost SDRs for ADS-B (1090 MHz) and FM signal reception
- **GPS-Hat:** Precision GPS with PPS (Pulse-Per-Second) for time synchronization
- **Dual-Antenna Configuration:** 
  - High-gain Yagi (surveillance channel) - monitors airspace
  - Omnidirectional (reference channel) - receives direct transmitter signal

### System Configuration

- **Receiver Location:** Apple Hill Campus, MathWorks, Natick, MA (42.3007°N, -71.3490°W)
- **Transmitter:** ATSC TV Tower, Eastern Massachusetts (42.311389°N, -71.216111°W)
- **Baseline:** ~12 km bistatic separation
- **Primary Coverage:** Aircraft approaching Logan International Airport
- **Detection Range:** ~62 km for 1.0 m² RCS targets

---

## Coordinated Capture Syntax

TLDR:
1. Capture and package a session on the testing machine. See **1. Capture on the Testing Machine**.
2. Sync that packaged session onto the development machine. See **2. Sync on the Development Machine**.
3. Run the packaged-session analysis on the development machine. See **3. Analyze on the Development Machine**.

### 1. Capture on the Testing Machine

Use the Ubuntu SDR capture machine as the coordinator. From the repo root, run:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh
```

This script verifies SSH access to the Pi, starts `gatherTCPcompress.py` remotely, waits 15 s, runs the local HDTV capture through `matlab -batch`, keeps ADS-B running until the local SDR step actually finishes, leaves ADS-B running for 5 s after that capture, and then stops the Pi logger gracefully before packaging the session locally as:

```text
captures/<session_id>/radar/
captures/<session_id>/truth/
captures/<session_id>/logs/
captures/<session_id>/session_manifest.json
```

At the end of a successful run, the coordinator also prints the exact `sync_capture_session.sh` command to run on the development machine for that packaged session.
For Pi truth capture recovery, the coordinator now reads the Pi session log's `final artifact` record first, then falls back to searching the Pi capture folder and the Pi user's home tree for `adsb_<session_id>` gzip files.
The packaged `session_manifest.json` now records both the requested SDR settings under `sdr_defaults` and a `header_readback` block from the first captured `.bb` file so later analysis can compare the intended capture settings against the actual file header metadata.
By default the coordinator uses `--repetitions 1`, so `--capture-duration 30` records one continuous 30 s radar file. The lower-level logger still streams that capture in 1 s chunks internally for write safety, but those chunks are appended into the same `.bb` file and do not reduce the analysis size.

Important syntax notes:
- The default Pi host is `192.168.10.131` and the default Pi user is `pi2`.
- The default local SDR settings are hidden behind `runLocalHDTVCapture.m`:
  - `radio = 'My USRP N320'`
  - `cf = 540e6`
  - `sr = 6.144e6`
  - `lo = 200e3`
  - `gain = [30 50]`
  - `capture-duration = 30`
  - `repetitions = 1`
  - `repetition-spacing = 1.0`
  - `lead = 15`
  - `tail = 5`
- `--capture-duration <seconds>` is the duration of each radar file, not the total wall-clock session span.
- `--repetitions <count>` controls how many radar files are recorded in one coordinated session.
- `--repetition-spacing <seconds>` inserts a gap only between repetitions, not after the final one.
- `--center-frequency <hz>` overrides the local radar capture center frequency and is written into the packaged session manifest.
- `--lo-offset <hz>` overrides the local SDR LO offset and is passed through to `runLocalHDTVCapture`.
- `--capture-file` sets the base name for the local `.bb` files; the shared session ID is appended automatically.
- `--gain` accepts either a scalar such as `30` or a dual-channel pair such as `30,50`.
- `--announce-host` overrides the hostname/IP that the coordinator prints into the development-machine sync command.
- `adsb_capture/` is only a temporary staging area for fetched truth files.
- The packaged session is written under `captures/` unless `--session-root` is provided.
- `--adsb-stage-dir` overrides the temporary ADS-B staging folder.
- The Pi-side logger writes its session log to `/home/pi2/flightTest/ADSB_GPS/adsb_capture_<session>.log`.
- The testing machine must be able to SSH to the Pi without an interactive password prompt. Verify this first with `ssh -o BatchMode=yes -o ConnectTimeout=10 pi2@192.168.10.131 "echo READY"`.

Continuous 30 s capture:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --center-frequency 600000000 --lo-offset 200000 --gain 28,48 --capture-duration 30 --capture-file n320_hdtv_capture
```

Burst-style capture to reduce analysis time:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --center-frequency 600000000 --lo-offset 200000 --gain 28,48 --capture-duration 1 --repetitions 15 --repetition-spacing 1 --capture-file n320_hdtv_capture
```

That burst example spans about 29 s wall-clock, but it records only 15 s of radar IQ and packages 15 separate radar files instead of one long continuous file.

Recommended clean 600 MHz recapture workflow:

Testing machine:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --center-frequency 599000000 --lo-offset 0 --gain 28,48 --capture-duration 1 --repetitions 15 --repetition-spacing 1 --capture-file n320_hdtv_capture
```

Development machine after the sync command is printed:

```bash
cd /path/to/flightTest
bash TestSetupTesting/sync_capture_session.sh --host <testing-machine> --user <testing-user> --session-id <new-session-id>
```

First MATLAB verification on the development machine:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('<new-session-id>');
replay_path = out.detector_replay_snapshot.path
```

Then confirm the baseline replay is using the saved header frequency:

```matlab
baseline = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', struct('Name', 'baseline'), ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

b = baseline.case_results(1);
b.truth_diag_output.truth_diag_input.fc
```

### 2. Sync on the Development Machine

To pull one packaged session onto a development machine, use:

```bash
cd /path/to/flightTest
bash TestSetupTesting/sync_capture_session.sh --host <testing-machine> --user <testing-user> --session-id <id>
```

This pulls `captures/<session_id>/` with `rsync -av -C`, preserves the packaged layout locally, and fails if the remote session folder or `session_manifest.json` is missing.
Large radar captures can take several minutes to transfer, and `rsync` may appear quiet while it copies the radar file.
In an interactive terminal, it then asks whether to run `runBistaticAnalysisSession('<session_id>')` immediately on the development machine. If you answer no, or pass `--no-ask-analysis`, it prints the exact MATLAB command instead.
Pass `--user` whenever your username on the testing machine differs from your username on the development machine.
Pass `--remote-root` whenever the testing machine stores packaged sessions somewhere other than `~/agenticProjects/flightTest/captures`.
If the sync preflight fails and the script suggests that `--user` may be wrong, also check `--remote-root`; the preflight currently uses one generic SSH error message for both username/access failures and missing remote session paths.
On macOS, the sync script will try `/Applications/MATLAB*.app/bin/matlab` automatically if `matlab` is not already on `PATH`.
Pass `--matlab-bin` if the development machine needs a non-default MATLAB executable path or if you want to override the auto-detected MATLAB binary.

### 3. Analyze on the Development Machine

To run the analysis without editing `analyzeBistaticData.m`, use the MATLAB session wrapper:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');
```

The wrapper loads `session_manifest.json`, resolves radar and `adsb_*` files automatically, ignores any `nmea_*` files that appear in the truth list, and preserves direct use of `analyzeBistaticData.m` for manual debugging.
The wrapper now defaults to the safer `core` visualization profile. That profile keeps the interactive RD viewer and truth-comparison figures, disables the `geoglobe` / `uifigure` paths and other lower-value companion windows, and avoids the old one-window-per-part RDM fan-out. Use `runBistaticAnalysisSession(..., 'VisualizationProfile', 'full')` to re-enable every figure path, or `... 'VisualizationProfile', 'headless'` to run a snapshot-first session with no interactive figures.
Direct runs of `analyzeBistaticData.m` now resolve the same visualization-profile logic, so manual debugging and the packaged-session wrapper use the same graphics defaults unless you override the per-plot switches in the config block.
The returned struct now also includes `out.visualization`, `out.figure_inventory`, and `out.ranked_crash_causes` so a post-sync audit can confirm which figure paths were active and which graphics risks were suppressed by the chosen profile.
When packaged session frequency metadata is available, the wrapper now carries the manifest center frequency and LO offset into the analysis config so the reference-quality and pilot-selection logic can use session metadata instead of falling back immediately to a hard-coded carrier.
For multi-part burst sessions, the analysis now derives part start offsets from each `.bb` file's `RecordingUTC` metadata when available. If that metadata cannot be read, the session wrapper falls back to the packaged manifest's `capture_repetition_spacing_s` instead of reusing the legacy fixed 3 s gap assumption.
If you need to compare timing assumptions on the same packaged session, run `runBistaticAnalysisSession(..., 'PartTimingSource', 'metadata')` or `runBistaticAnalysisSession(..., 'PartTimingSource', 'fallback')`.
For the ADS-B truth-fix rerun, use the dedicated helper instead of running those two passes by hand:

```matlab
cd BistaticDataAnalysis
cmp = runTruthFixTimingComparison('20260616T160702');
cmp.comparison.summary_table
cmp.comparison.delta_table
```

That helper runs both timing modes, preserves each run's part-start summary in the returned output struct, and optionally compares both results against the saved pre-patch console log `C:\Users\pwilliam\agenticProjects\bistaticOutput.txt`.
If both timing modes still produce `TP=0`, the next check is whether detections are simply displaced from truth by a nearly constant measurement-space offset:

```matlab
off = estimateTruthMeasurementOffset(cmp.metadata_output);
off.summary
```

That diagnostic builds a residual heatmap of `detection - truth` in `(ΔR, Δf)` space for time-near candidate pairs, estimates the strongest constant offset cluster, and re-scores the detections after compensating by that offset. If compensated TP jumps sharply, the remaining problem is detector localization or projection bias rather than timing alone.
When ADS-B truth is present, the analysis now overlays the projected truth directly on both the single-window per-part Range-Doppler viewer and the interactive RD viewer in bistatic `(R_excess, f_D)` space.
The shared convention for that truth/tracker path is now:
- `R_excess = R_tx + R_rx - L_3D`
- `f_D = -(fc/c) * dR_excess/dt`
- `range_cell_m = c/fs`
- `createRDM` Doppler axes are reported at the true FFT bin centers
By default it also saves:
- a compact post-detection truth snapshot at `captures/<session_id>/analysis/truth_diag_input.mat`
- a detector replay snapshot at `captures/<session_id>/analysis/detector_replay_input.mat`

The first artifact is for truth-only iteration; the second is for rerunning only the detector stage.
The wrapper now always returns `out.truth_diag_snapshot` and `out.detector_replay_snapshot` status structs, even when an optional artifact could not be written. Check `.saved` and `.status` (`saved`, `unavailable`, or `error`) before assuming the on-disk snapshot exists.
After the first full run, the wrapper also prints and returns `out.restart_commands.truth_only` and `out.restart_commands.detector_only`, which point directly at those saved snapshot paths so post-sync iteration can restart from the compact truth bundle or the detector replay bundle instead of repeating IQ, ECA-C, CAF, and CFAR.

### 3a. Pre-Analysis Direct-Path Check

Before running the full bistatic analysis, you can read only a short slice from one radar file and verify that the direct path looks usable:

```matlab
cd BistaticDataAnalysis
pre = runDirectPathPrecheck('20260616T090717');
```

By default this reads the first radar file in the packaged session and only the first 1 second of IQ, so it is much faster than the full analysis path.
In this repository, session IDs now resolve directly against `BistaticDataAnalysis/captures`, so `runDirectPathPrecheck('20260622T102123')` works without a manual `DatasetRoot` override.
The diagnostic produces three figures and pass/warn summaries for:
- reference spectrum and PSD-based pilot evidence
- lag-domain direct-path peak dominance between surveillance and reference
- zero-Doppler ridge strength before and after ECA-C

Why this matters for passive bistatic HDTV signals:
- ATSC 8-VSB payload data is intentionally broad and noise-like in the spectrum, so "one coherent FFT bin stayed strong across CPIs" is not the right primary test for whether the direct-path reference is healthy.
- The ATSC pilot is the one narrow, always-transmitted spectral feature tied to the broadcast waveform itself. If the reference channel shows that pilot at the expected transmitted location, the capture is much more likely to be correctly tuned, correctly oriented in frequency, and strong enough to support direct-path-based processing.
- In this passive-radar workflow the reference channel anchors ECA-C clutter cancellation, direct-path lag calibration, and the interpretation of later range-Doppler products. A cleaner pilot audit is therefore relevant even when the final WARN is caused by residual clutter rather than by pilot selection.

The reference-spectrum figure and returned pilot-audit struct now distinguish between:
- the expected normal-orientation ATSC pilot location
- the expected mirrored-orientation ATSC pilot location
- the final selected candidate
- the mirrored diagnostic-only candidate
- the residual-frequency stability trace after centering the selected pilot
- the legacy FFT-bin coherence metric as secondary text only

That matters when the header center is off the ATSC raster. For example, a header `Fc = 600 MHz` with `LOOffset = 200 kHz` can still contain a valid channel centered at `599 MHz`; in that case the ATSC pilot can wrap onto the positive-frequency side of baseband instead of appearing on the usual negative side.
The returned `pre.reference_profile` struct and `pre.pilot_diagnostic_table` now report the selected pilot frequency, PSD prominence, peak power, frequency error, advisory residual-frequency statistics, and the mirrored diagnostic candidate. That makes the selection explainable without reverse-engineering ambiguous plot labels.
The figure-level summary and `pre.precheck_summary` now use passive-radar language such as `Passive-radar recommendation: HOLD - pilot evidence not yet trustworthy`, rather than only saying that a plot looks good or bad.
The frequency-resolution path is metadata-first but not metadata-blind: it uses an explicit `IlluminatorCenterFrequencyHz` override when you provide one, otherwise it locks to a file-header center only when that center is plausibly on the ATSC raster, otherwise it falls back to the nearest raster as a diagnostic search center. Under the current `Normal only` policy, mirrored candidates remain diagnostic-only even if they look stronger than the normal-side line.

To run the capture-backed engineering validation that samples parts `[1 5 10 15]` from the packaged session and summarizes pilot stability:

```matlab
cd BistaticDataAnalysis
val = runATSCPilotAuditValidation('20260622T102123');
val.part_table
val.summary
```

Status note as of July 10, 2026:
- automated verification for this upgrade is complete
- manual review of the top spectrum/pilot-evidence figure on real capture data now confirms that the selected PSD peak lands on the expected pilot tone
- full manual review is still not complete until an operator also checks the stability panel plus the HOLD/CONTINUE summary text against the returned structured outputs, ideally on more than one part

If you want to probe a specific file directly:

```matlab
cd BistaticDataAnalysis
pre = runDirectPathPrecheck('C:\path\to\capture_part1.bb', ...
    'SliceDurationS', 1.0, ...
    'PlotFigures', true);
```

If the channel-power diagnostic, pilot-evidence plot, and ECA-C behaviour together suggest the better ATSC reference is actually on `RX1`, rerun the precheck with:

```matlab
pre = runDirectPathPrecheck('20260616T090717', 'SwapChannels', true);
```

Power asymmetry alone is not enough to infer a swap. In this project's default hardware, the surveillance channel may be stronger because it uses a higher-gain / amplified Yagi while the reference channel may be a small unamplified omni.

If you know the actual ATSC illuminator center, pass it explicitly so the pilot search uses the exact channel geometry instead of the nearest raster guess:

```matlab
pre = runDirectPathPrecheck('20260616T131954', ...
    'IlluminatorCenterFrequencyHz', 599e6);
```

To audit an entire packaged session instead of one representative slice:

```matlab
cd BistaticDataAnalysis
rf = runSessionRFQualityAudit('20260616T160702');
rf.part_table
rf.summary
rf.assessment
```

This session-level audit keeps the RF-only questions separate from later detector/truth diagnostics. It checks whether the capture is consistently usable for passive radar by measuring, per part:
- reference-channel level, PSD-based ATSC pilot evidence, and spectral flatness
- direct-path lag dominance between surveillance and reference
- zero-Doppler ridge strength before ECA-C, suppression after ECA-C, and whether the residual ridge still sits too far above the post-ECA noise floor

Then it rolls those into one sufficiency decision for either `aircraft_detection` or `tracking_validation`. Use this before spending time on CFAR sweeps or truth debugging.
Per-part warnings are preserved in `rf.part_table` and rolled into the session summary; one weak part should not stop the audit from evaluating the rest of the session.
The audit intentionally does not use raw inter-channel power asymmetry as a sufficiency metric, because in this hardware the surveillance Yagi may legitimately be much stronger than the small reference omni.
If the reference ADC level looks acceptable but pilot evidence stays weak or badly misplaced, a reference-side LNA / amplifier is a valid hardware adjustment and should be treated as in scope.
For the current hardware baseline, `RX0/CH1` is typically the surveillance HDTV Yagi with a built-in amplifier and `RX1/CH2` is the small unamplified telescoping reference antenna. That means a reference-gain sweep such as `28,48 -> 28,54 -> 28,60` is a valid experiment, but it should be judged primarily by pilot prominence, pilot-frequency consistency, mirrored-pilot incidence, and the post-ECA residual ridge rather than by channel-power ratio alone.
When comparing multiple gain-sweep sessions, use the same explicit `IlluminatorCenterFrequencyHz` for every run if the actual HDTV channel center is known. If a higher SDR gain improves ADC level but does not materially improve PSD-based pilot evidence, the next in-scope fix is a better reference front end such as a reference-side LNA / amplifier, better antenna, or better placement.
For passive bistatic HDTV in particular, this is the right order of operations: first confirm that the broadcast pilot looks like a valid direct-path reference, then worry about how much residual zero-Doppler clutter remains after ECA-C. A session can legitimately "win" on pilot identification while still warning on clutter suppression, which is exactly the distinction this audit is trying to preserve.

Use the stricter goal when the intended outcome is track-quality validation or quantitative truth comparison, not just "can the session support aircraft detection at all?":

```matlab
rf_track = runSessionRFQualityAudit('20260616T160702', ...
    'Goal', 'tracking_validation');
rf_track.assessment
```

By default, `tracking_validation` requires every audited part to clear the RF bars, while `aircraft_detection` allows a high pass fraction across the session.

### 3b. Re-run Only the Truth Diagnostics

After one full session run, you can iterate on the detection-vs-truth plots without re-running the raw IQ pipeline:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');

diag = runDetectionTruthDiagnostics(out.truth_diag_input, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true, ...
    'PlotTrackComparison', false);
```

The automatic snapshot is also returned in `out.truth_diag_snapshot.compact_path`, so you can replay it directly:

```matlab
cd BistaticDataAnalysis
diag = runDetectionTruthDiagnostics(out.truth_diag_snapshot.compact_path, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true);
```

If the compact snapshot was unavailable, replay from the in-memory bundle instead:

```matlab
diag_source = out.truth_diag_input;
if out.truth_diag_snapshot.saved
    diag_source = out.truth_diag_snapshot.compact_path;
end

diag = runDetectionTruthDiagnostics(diag_source, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true);
```

If you want a larger replay snapshot that also preserves cached per-part RDM images for standalone RDM overlay recreation:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530', ...
    'TruthDiagnosticSnapshotMode', 'both');

diag = runDetectionTruthDiagnostics(out.truth_diag_snapshot.full_path, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true);
```

This replay path skips the expensive raw IQ, ECA-C, CAF, and CFAR stages. It reruns only ADS-B loading, bistatic truth projection, truth alignment, detection matching, and the comparison plots. The compact snapshot is the default because it is smaller; the full snapshot is optional when you want standalone RDM overlay figures as well.
When cached detector axes are available, truth matching now derives the range and Doppler bin spacing from those saved products instead of relying only on nominal config constants. This keeps the TP gates aligned with the replayed detector geometry.
When the original radar file paths are still accessible, `runDetectionTruthDiagnostics` also refreshes `fs` and `fc` from the first `.bb` header before ADS-B projection. New session snapshots now preserve that header-refreshed metadata so truth replays do not silently keep a stale carrier frequency.

### 3c. Re-run Only the Detector Stage

When you want to retune CFAR or post-CFAR thresholds without rerunning IQ loading, ECA-C, or CAF generation:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');

cases = struct( ...
    'Name', {'baseline', 'tight_snr'}, ...
    'MinSNRDB', {0, 10});

replay = runDetectorReplaySweep(out.detector_replay_snapshot.path, ...
    'Cases', cases, ...
    'PlotDetectionTimeSeries', false, ...
    'PlotRDMOverlays', false);
```

If the detector replay snapshot was unavailable, pass the in-memory replay bundle instead:

```matlab
replay_source = out.detector_replay_input;
if out.detector_replay_snapshot.saved
    replay_source = out.detector_replay_snapshot.path;
end

replay = runDetectorReplaySweep(replay_source, ...
    'Cases', cases, ...
    'PlotDetectionTimeSeries', false, ...
    'PlotRDMOverlays', false);
```

This replay path starts from the saved per-block whitened detector inputs, reruns `detectTargets`, rebuilds the detection table, and can still score the new detections against ADS-B truth. Use it when you are iterating on `Pfa`, guard/train cells, local-max suppression, minimum SNR, or related detector parameters.
During truth scoring, `runDetectorReplaySweep` now refreshes the truth-bundle range and Doppler cell spacing from the saved detector axes before calling `runDetectionTruthDiagnostics`, so replay TP/FA counts use the actual replay grid.
When the saved radar file paths are available, the truth diagnostics invoked by detector replay also refresh `fs` and `fc` from the first `.bb` header before ADS-B projection. This prevents a stale replay snapshot from continuing to score truth at the wrong carrier frequency.

`Cases` is a struct array of per-case detector overrides. Each case starts from the detector defaults saved in the replay snapshot and only overrides the fields you specify.

Supported per-case fields:
- `Name`
- `Pfa`
- `GuardCells`
- `TrainCells`
- `MinRangeM`
- `CfarType`
- `OSRankFraction`
- `LocalMaxima`
- `LMRangeBins`
- `LMDoppBins`
- `MinSNRDB`
- `ATSCGuardPenaltyDB`
- `ATSCGuardWidthBins`
- `NotchGuardDoppBins`
- `CfarOptions`

Important syntax notes:
- `Cases` fields are per-case detector settings.
- Plotting and scoring controls such as `PlotCases`, `PlotDetectionTimeSeries`, `PlotRDMOverlays`, `GateRangeCells`, `GateDopplerBins`, `TimeGateS`, `RunTruthDiagnostics`, and `Verbose` are outer `runDetectorReplaySweep` name-value pairs, not `Cases` fields.
- Vector-valued fields such as `GuardCells` and `TrainCells` must use cell-array entries, because each case needs its own 1x2 vector.
- In most sweeps, prefer the flat case fields such as `CfarType`, `OSRankFraction`, and `MinSNRDB`; use `CfarOptions` only when you want to pass a nested options struct directly.
- Common lower-camel case aliases such as `minSNRDB` are accepted inside `Cases` for compatibility, but the canonical field names shown here are still preferred.
- Typos in outer name-value options still error; the parser now suggests the closest supported option name when it can.
- Malformed MATLAB struct syntax is still a MATLAB error, so keep the `cases = struct(...)` field/value pattern exactly as shown in the examples.

Troubleshooting note: when sweeps increase false alarms but not truth hits

If a replay sweep drives `n_detections` up by 10x-30x while `n_tp` stays near zero, do not assume the next fix is an even looser detector. That pattern usually means the limiting problem is upstream of CFAR:

- The replay truth model may be using the wrong carrier frequency. Check the saved session metadata and the `adsbToBistatic` console line. If the capture was actually centered at 600 MHz but truth projection is using 540 MHz, the expected Doppler will be scaled low by about 11%.
- The surveillance antenna may be badly mismatched to the broadcast band. A 978 MHz surveillance antenna used on a roughly 540-600 MHz HDTV illuminator can still receive energy, but with reduced gain and pattern quality, which lowers aircraft echo SNR before CFAR ever runs.
- A fixed range or timing alignment error may still be present. Large false-alarm growth with almost no Pd improvement is more consistent with a localization bias than with an overly strict threshold.
- The channel assignment may still be wrong even if the nominal reference-quality check passes, but do not use channel power alone to infer that. In this project, an amplified surveillance Yagi can make `CH1` much stronger than `CH2` even when the default mapping is correct. Treat a swap as plausible only if the pilot-evidence / direct-path prechecks improve materially when `config.swap_channels = true`.

In that situation, prioritize:

1. Verify capture `fc` from the `.bb` header or packaged session metadata.
2. Check both reference-channel health and surveillance-channel signal level on the raw capture.
3. Run one-case truth overlays to look for a consistent range or Doppler offset.
4. Only then spend more time on targeted detector changes such as `LocalMaxima`, ATSC guard, notch guard, or `MinRangeM`.

Example: sweep detector sensitivity first

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');

cases = struct( ...
    'Name', {'baseline', 'pfa3e4', 'pfa1e3', 'os065', 'os060', 'ca_baseline'}, ...
    'Pfa', {1e-4, 3e-4, 1e-3, 1e-4, 1e-4, 1e-4}, ...
    'CfarType', {'OS', 'OS', 'OS', 'OS', 'OS', 'CA'}, ...
    'OSRankFraction', {0.75, 0.75, 0.75, 0.65, 0.60, 0.75});

replay = runDetectorReplaySweep(out.detector_replay_snapshot.path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false);

replay.summary_table
```

Example: sweep CFAR window sizes

```matlab
cases = struct( ...
    'Name', {'baseline', 'smaller_window', 'larger_window'}, ...
    'GuardCells', {[6 2], [4 2], [8 3]}, ...
    'TrainCells', {[20 4], [12 4], [28 6]});

replay = runDetectorReplaySweep(out.detector_replay_snapshot.path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false);
```

Example: sweep suppression and post-CFAR thresholds

```matlab
cases = struct( ...
    'Name', {'baseline', 'snr6', 'snr10', 'no_localmax'}, ...
    'MinSNRDB', {0, 6, 10, 0}, ...
    'LocalMaxima', {true, true, true, false});

replay = runDetectorReplaySweep(out.detector_replay_snapshot.path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'GateRangeCells', 3, ...
    'GateDopplerBins', 3, ...
    'TimeGateS', 2.0);
```

For a detector-tuning playbook and ready-to-paste sweep examples, see [radarExpertDetectorTuning.md](radarExpertDetectorTuning.md). The segmented rerun workflow is also captured in [BistaticDataAnalysis/checklist.md](BistaticDataAnalysis/checklist.md).

### 3d. Run the Offline Toolbox Benchmark

When you want to compare the current custom measurement path against toolbox-backed timing and CFAR alternatives without changing the supported production wrapper:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260615T103437', ...
    'SaveTruthDiagnosticSnapshot', false, ...
    'SaveDetectorReplaySnapshot', false);

bench = runOfflineToolboxBenchmark(out.detector_replay_input, ...
    'PlotSummary', true, ...
    'Verbose', true);

bench.summary_table
```

You can also point the benchmark directly at a saved replay snapshot or a packaged session:

```matlab
bench = runOfflineToolboxBenchmark(out.detector_replay_snapshot.path);

bench = runOfflineToolboxBenchmark('20260615T103437');
```

Supported source types:
- a detector replay bundle struct
- an analysis-output struct that contains `.detector_replay_input`
- a MAT-file containing `detector_replay_input`
- a packaged session ID, session folder, or manifest path

The harness always includes `custom_baseline` and then benchmarks up to three toolbox variants on the same input:
- `custom_baseline`
- `toolbox_tdoa`
- `toolbox_cfar`
- `toolbox_tdoa_cfar`

The summary table has fixed fields for:
- detector, TDOA, truth-scoring, and total runtime
- detection count
- `n_tp`, `n_fa`, `n_miss`
- mean `Pd`
- deltas versus `custom_baseline`

For fast development iterations, point the harness at a saved replay snapshot and limit the replay scope instead of rerunning the full session:

```matlab
bench = runOfflineToolboxBenchmark( ...
    'detector_replay_20260622T102123.mat', ...
    'Variants', {'toolbox_tdoa'}, ...
    'PartIndices', 1:2, ...
    'MaxBlocksPerPart', 1, ...
    'RunTruthDiagnostics', false, ...
    'PlotSummary', false, ...
    'Verbose', true);
```

Scoped replay slices keep the same summary-table schema, but they are intended for code iteration rather than final metrics:
- `PartIndices` selects which replay parts to exercise.
- `MaxBlocksPerPart` keeps only the first N cached detector blocks from each selected part.
- Truth diagnostics are automatically disabled for scoped replay slices, because partial part/block runs are not acceptance-quality accuracy measurements.
- To minimize startup cost, use a saved detector replay snapshot or `out.detector_replay_input`; a packaged session folder still has to rebuild the replay input before these limits can apply.

Important behavior notes:
- `toolbox_tdoa` and `toolbox_tdoa_cfar` reload the original radar `.bb` files from the replay bundle so they can re-measure delay with `phased.TDOAEstimator`. If those file paths are no longer reachable, the harness reports an error row for the affected variant instead of silently skipping it.
- `toolbox_cfar` and `toolbox_tdoa_cfar` use `phased.CFARDetector2D` on the saved replay blocks, but they keep the project-specific wrapper logic outside the toolbox object: zero-Doppler notch fill, ATSC ghost-range penalties, minimum-SNR gating, and local-max suppression.
- If the replay bundle has no usable ADS-B truth template, the harness still runs and reports runtime plus detection counts, but the truth metrics stay `NaN`.

### 3e. Toolbox Evaluation Status

The toolbox benchmark is currently an offline assessment path only. It does not change the supported production wrapper.

- Toolbox TDOA was assessed on the captured `20260622T102123` replay and returned numeric delay measurements, but it is currently too slow to replace the custom measurement path on this workload.
- Toolbox CFAR was also slower in the tested offline replay cases, so it should be treated as parity characterization rather than a speed-improvement path.
- The supported workflow remains the custom CAF/RDM detector plus custom measurement extraction.
- If toolbox TDOA is revisited, treat it as a localized refinement experiment rather than the main production front-end replacement track.

Detailed rationale and measured evidence are documented in [BistaticDataAnalysis/toolboxReplacementAssessment.md](BistaticDataAnalysis/toolboxReplacementAssessment.md).
The current execution plan for the next session is tracked in [NEXT_SESSION_HANDOFF.md](NEXT_SESSION_HANDOFF.md).

### 4. Other Entry Points

If you want to run only the local SDR step from a terminal, use:

```bash
cd /path/to/flightTest
matlab -batch "cd('TestSetupTesting'); runLocalHDTVCapture();"
```

Legacy MATLAB-owned coordination is still available, but it is now the secondary path:

```bash
cd /path/to/flightTest
matlab -batch "cd('TestSetupTesting'); info = runCoordinatedHDTVCapture('PiHost','192.168.10.131'); disp(info.session_id);"
```

Use the shell coordinator, `sync_capture_session.sh`, and `runBistaticAnalysisSession` as the supported end-to-end workflow.

---

## Repository Structure

### 📁 [`TestSetupTesting/`](TestSetupTesting/)
**Passive Bistatic Radar System - Main Processing Pipeline**

Complete MATLAB implementation for passive radar data collection, quality assessment, system characterization, and aircraft detection/localization.

**Key Components:**

#### Data Collection
- [`PassiveRadarCollection_wPreFlightChecks.m`](TestSetupTesting/PassiveRadarCollection_wPreFlightChecks.m) - Mission control with Linux optimization and hardware validation
- [`log_iq_n320_2antennas.m`](TestSetupTesting/log_iq_n320_2antennas.m) - Dual-channel IQ data recording
- [`runLocalHDTVCapture.m`](TestSetupTesting/runLocalHDTVCapture.m) - Local-only HDTV capture wrapper that keeps the standard SDR defaults in one place
- [`run_coordinated_hdtv_capture.sh`](TestSetupTesting/run_coordinated_hdtv_capture.sh) - Recommended Ubuntu coordinator that starts Pi ADS-B logging over SSH, runs the local SDR capture through `matlab -batch`, and packages the session under `captures/<session_id>/`
- [`sync_capture_session.sh`](TestSetupTesting/sync_capture_session.sh) - Pull one packaged session from the testing machine to a development machine with `rsync -av -C`, then optionally launch session-based analysis
- [`runCoordinatedHDTVCapture.m`](TestSetupTesting/runCoordinatedHDTVCapture.m) - Legacy MATLAB-owned Pi + SDR coordinator kept for backward compatibility
- [`log_iq_n320.m`](TestSetupTesting/log_iq_n320.m) - Single-channel variant

#### Quality Assessment
- [`assess_bb_quality.m`](TestSetupTesting/assess_bb_quality.m) - Signal quality analysis (PSD, SNR, DC offset, pilot detection)
- [`check_dual_channel_coherence.m`](TestSetupTesting/check_dual_channel_coherence.m) - Phase synchronization verification
- [`script_QualityEtc.m`](TestSetupTesting/script_QualityEtc.m) - **Master characterization script** (runs complete workflow)

#### System Characterization
- [`calc_system_resolution.m`](TestSetupTesting/calc_system_resolution.m) - Range/velocity resolution calculation
- [`calc_detection_threshold.m`](TestSetupTesting/calc_detection_threshold.m) - Statistical threshold (CFAR)
- [`calc_coverage_map.m`](TestSetupTesting/calc_coverage_map.m) - Link budget and maximum range
- [`calc_theoretical_accuracy.m`](TestSetupTesting/calc_theoretical_accuracy.m) - Localization uncertainty analysis
- [`calc_suppression_depth.m`](TestSetupTesting/calc_suppression_depth.m) - Dynamic range measurement
- [`calculate_saf.m`](TestSetupTesting/calculate_saf.m) - Self-Ambiguity Function (clutter characterization)

#### Detection Engines
- [`compute_radar_caf.m`](TestSetupTesting/compute_radar_caf.m) - **Standard** Cross-Ambiguity Function (time-domain xcorr)
- [`compute_radar_caf_nitro.m`](TestSetupTesting/compute_radar_caf_nitro.m) - **Nitro** FFT-accelerated engine (5-10× faster)
- [`compute_radar_caf_thresholded.m`](TestSetupTesting/compute_radar_caf_thresholded.m) - CFAR detection with thresholding
- [`compute_radar_caf_interpolated.m`](TestSetupTesting/compute_radar_caf_interpolated.m) - Spline interpolation for sub-sample accuracy
- [`compute_radar_caf_localized_TbxFns.m`](TestSetupTesting/compute_radar_caf_localized_TbxFns.m) - **Production localization** (geographic coordinates + bistatic ellipses)

**Engine Comparison:**
- **Standard Engine:** Uses time-domain `xcorr()` for cross-correlation. More memory efficient, easier to understand, but slower.
- **Nitro Engine:** Uses frequency-domain correlation via FFT/IFFT. Exploits FFT speed advantages for large datasets. Produces numerically equivalent results but 5-10× faster. Recommended for production batch processing.
- [`BenchmarkEngine.m`](TestSetupTesting/BenchmarkEngine.m) validates both engines produce identical detections and measures speedup.

#### Batch Processing & Utilities
- [`IQDataProcessing.m`](TestSetupTesting/IQDataProcessing.m) - Production batch processor (uses Nitro engine for speed)
- [`BenchmarkEngine.m`](TestSetupTesting/BenchmarkEngine.m) - Performance comparison tool (validates standard vs Nitro equivalence)
- [`calculate_bistatic_ellipse.m`](TestSetupTesting/calculate_bistatic_ellipse.m) - Bistatic geometry calculations
- [`VisualizeCoverage_Estimate.m`](TestSetupTesting/VisualizeCoverage_Estimate.m) - Geographic coverage visualization
- [`dualChannelQuickCheck.m`](TestSetupTesting/dualChannelQuickCheck.m) - Quick coherence verification

#### Data Files
- `*.bb` - Baseband IQ recordings from USRP N320
- `MissionReport_LoganCorridor.mat` - Saved performance metrics and system characterization

**See [`TestSetupTesting/README.md`](TestSetupTesting/README.md) for detailed documentation of the evaluation workflow.**

---

### [`BistaticDataAnalysis/`](BistaticDataAnalysis/)
**Session-based bistatic analysis and truth alignment**

- [`analyzeBistaticData.m`](BistaticDataAnalysis/analyzeBistaticData.m) - Main processing engine; still supports direct manual runs for debugging
- [`runBistaticAnalysisSession.m`](BistaticDataAnalysis/runBistaticAnalysisSession.m) - Supported analysis entrypoint for packaged sessions; returns `truth_diag_input`, returns `detector_replay_input`, and auto-saves truth plus detector replay snapshots under the packaged session
- [`buildDetectionTruthDiagnosticInput.m`](BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m) - Builds the standalone post-detection bundle used to replay truth diagnostics without reprocessing IQ
- [`saveDetectionTruthDiagnosticInput.m`](BistaticDataAnalysis/saveDetectionTruthDiagnosticInput.m) - Saves a compact or full `truth_diag_input` snapshot to MAT for later replay
- [`helperSaveTruthDiagnosticSnapshots.m`](BistaticDataAnalysis/helperSaveTruthDiagnosticSnapshots.m) - Writes session-style compact/full truth-diagnostic snapshots into an analysis folder
- [`buildDetectorReplayInput.m`](BistaticDataAnalysis/buildDetectorReplayInput.m) - Builds the block-level detector replay bundle from the saved whitened CFAR inputs
- [`saveDetectorReplayInput.m`](BistaticDataAnalysis/saveDetectorReplayInput.m) - Saves `detector_replay_input` to MAT for later detector-only reruns
- [`helperSaveDetectorReplaySnapshot.m`](BistaticDataAnalysis/helperSaveDetectorReplaySnapshot.m) - Writes the session-style detector replay snapshot into the analysis folder
- [`runDetectorReplaySweep.m`](BistaticDataAnalysis/runDetectorReplaySweep.m) - Re-runs `detectTargets` from the saved detector checkpoint and optionally rescores the results against ADS-B truth
- [`runDetectionTruthDiagnostics.m`](BistaticDataAnalysis/runDetectionTruthDiagnostics.m) - Re-runs truth alignment, detection matching, and diagnostic plots from a bundle, struct, or MAT snapshot
- [`plotDetectionTruthDiagnostics.m`](BistaticDataAnalysis/plotDetectionTruthDiagnostics.m) - Plots `R_excess` vs time and `f_D` vs time with matched and unmatched detections overlaid on truth
- [`helperBuildTruthQueryTimes.m`](BistaticDataAnalysis/helperBuildTruthQueryTimes.m) - Builds the block-center time grid used to align ADS-B truth to the radar processing cadence
- [`helperPlotRDMTruthOverlay.m`](BistaticDataAnalysis/helperPlotRDMTruthOverlay.m) - Overlays ADS-B truth directly on Range-Doppler figures in bistatic measurement space
- [`helperBistaticDopplerCoupling.m`](BistaticDataAnalysis/helperBistaticDopplerCoupling.m), [`helperBistaticDopplerFromRangeRate.m`](BistaticDataAnalysis/helperBistaticDopplerFromRangeRate.m), [`helperBistaticRangeRateFromDoppler.m`](BistaticDataAnalysis/helperBistaticRangeRateFromDoppler.m) - Shared Doppler conversion helpers for the passive CAF convention
- [`helperDeriveTxRxGeometry.m`](BistaticDataAnalysis/helperDeriveTxRxGeometry.m) - Shared Tx/Rx ENU geometry helper used by truth projection and ellipse rendering
- [`adsbTruthFixChecklist.md`](BistaticDataAnalysis/adsbTruthFixChecklist.md) - Current session-start checklist for the ADS-B `LLA -> bistatic range/Doppler` work, with completed local convention fixes checked off and the remaining development-machine timing/validation steps left open
- [`bistaticTruthConventionTest.m`](BistaticDataAnalysis/bistaticTruthConventionTest.m) - Focused regression suite for Doppler coupling, range-cell spacing, 3D baseline usage, and `createRDM` Doppler-axis bin centers
- [`adsbTruthFixTestPlan.md`](BistaticDataAnalysis/adsbTruthFixTestPlan.md) - Review-oriented test plan, executed verification record, and remaining real-data validation steps
- [`helperLoadSessionManifest.m`](BistaticDataAnalysis/helperLoadSessionManifest.m) - Loads and validates `session_manifest.json`
- [`helperResolveSessionAnalysisSetup.m`](BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m) - Resolves one packaged session into radar files, truth files, and analysis preflight settings
- [`test_adsbTruthPipeline.m`](BistaticDataAnalysis/test_adsbTruthPipeline.m) - Synthetic end-to-end regression test for the ADS-B truth and standalone diagnostic workflow

---

### 📁 [`ADSB_GPS/`](ADSB_GPS/)
**Ground Truth Collection System - ADS-B & GPS Logging**

Raspberry Pi-based data collection system for capturing aircraft transponder messages and GPS ground truth synchronized with passive radar observations.

**Key Components:**

#### Python Data Loggers
- [`gatherTCPcompress.py`](ADSB_GPS/gatherTCPcompress.py) - ADS-B message capture from dump1090 (TCP port 30003)
  - Graceful shutdown on timeout or `Ctrl+C` with synchronous final-file flush/compress
  - `--run-seconds` and `--session-id` options for bounded capture windows that align with SDR sessions
  - Timestamped data files with automatic rollover, chunk-safe TCP line reassembly, and optional rsync/rclone sync

- [`gatherNMEAcompress.py`](ADSB_GPS/gatherNMEAcompress.py) - GPS/NMEA sentence logging from gpsd
  - Captures position, velocity, and timing data
  - Synchronized with PPS for precision timestamping
  - Compressed storage with configurable sample rates

- [`getSomeNMEAStuff.py`](ADSB_GPS/getSomeNMEAStuff.py) - Quick NMEA data extraction utility
- [`test_gatherTCPcompress.py`](ADSB_GPS/test_gatherTCPcompress.py) - Local integration test for chunked TCP input and final gzip file creation

#### System Control
- [`start_adsb_gps_loggers.sh`](ADSB_GPS/start_adsb_gps_loggers.sh) - **Master control script**
  - Starts/stops gpsd, dump1090, and data loggers
  - Supports bounded ADS-B runs via `--adsb-run-seconds` and shared session IDs via `--adsb-session-id`
  - Handles service conflicts and targeted logger restarts without killing unrelated Python processes
  - Automatically runs on Raspberry Pi boot

#### Data Files
- `nmea_*.txt.gz` - Compressed GPS/NMEA logs with timestamps
- Historical data from June 2025 collection campaigns

**Purpose:** Provides independent ground truth for validating passive radar detections. ADS-B messages contain aircraft position, velocity, and identification which can be correlated with radar detections for performance assessment.

---

## Quick Start Guide

### 1. Collect Passive Radar Data
```matlab
cd TestSetupTesting
PassiveRadarCollection_wPreFlightChecks  % Runs pre-flight checks and captures data
```

### 1b. Coordinate a 30 s HDTV Capture with Raspberry Pi ADS-B Logging
```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh
```
This starts ADS-B on the Pi, waits 15 s, runs the local SDR capture, keeps ADS-B running until that local capture completes, lets ADS-B run a few seconds longer, then stops the Pi logger gracefully and writes a packaged session to `captures/<session_id>/`.
With the defaults, that local SDR step is one continuous 30 s radar file. For shorter burst-style sessions, set `--capture-duration`, `--repetitions`, and `--repetition-spacing` explicitly.
When packaging completes, the script prints the exact sync command to copy that session onto the development machine.

To tune gains or timing without rewriting a long MATLAB command:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --gain 28,48 --lead-seconds 15 --tail-seconds 5
```

To collect 15 one-second radar files across about 29 seconds of wall-clock time:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --center-frequency 600000000 --gain 28,48 --capture-duration 1 --repetitions 15 --repetition-spacing 1
```

### 1c. Sync One Packaged Session to a Development Machine
```bash
cd /path/to/flightTest
bash TestSetupTesting/sync_capture_session.sh --host <testing-machine> --user <testing-user> --session-id <id>
```
In an interactive terminal, this script prompts to launch the session analysis immediately after the transfer succeeds.

### 2. Run Session-Based Analysis by Session ID
```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');
```
This also writes a compact truth snapshot to `captures/<session_id>/analysis/truth_diag_input.mat` and a detector replay snapshot to `captures/<session_id>/analysis/detector_replay_input.mat` by default.

### 2a. Run the Fast Direct-Path Precheck
```matlab
cd BistaticDataAnalysis
pre = runDirectPathPrecheck('20260611T101530');
```
Use this when you want a quick yes/no answer on reference quality, lag peak dominance, and zero-Doppler suppression before paying for the full analysis.

### 2b. Re-run Only the Detection-vs-Truth Diagnostics
```matlab
cd BistaticDataAnalysis
diag = runDetectionTruthDiagnostics(out.truth_diag_snapshot.compact_path, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true, ...
    'PlotTrackComparison', false);
```
Use this after one full session run when you only want to iterate on truth alignment, truth overlays, or detection-vs-truth checks.

### 2c. Re-run Only the Detector Stage
```matlab
cd BistaticDataAnalysis
replay = runDetectorReplaySweep(out.detector_replay_snapshot.path, ...
    'Pfa', 1e-4, ...
    'MinSNRDB', 10, ...
    'PlotDetectionTimeSeries', false, ...
    'PlotRDMOverlays', false);
```
Use this after one full session run when you want to iterate on CFAR and detector parameters only.
For multi-case sweeps with the `Cases` struct, see the earlier **3c. Re-run Only the Detector Stage** section in this README.

### 3. Run System Characterization
```matlab
script_QualityEtc  % Complete workflow: quality → characterization → detection
```

### 4. Batch Process Long Recordings
```matlab
IQDataProcessing  % Processes entire file, outputs Results_*.csv
```

### 5. Start Ground Truth Collection (Raspberry Pi)
```bash
cd ADSB_GPS
sudo ./start_adsb_gps_loggers.sh
```

For a single bounded ADS-B-only run from the Pi:
```bash
cd ADSB_GPS
sudo ./start_adsb_gps_loggers.sh --adsb-only --adsb-session-id 20260610T094500 --adsb-run-seconds 50
```

---

## System Performance

**Typical Metrics from Logan Corridor Testing:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Range Resolution** | ~50 m | Limited by 6 MHz bandwidth |
| **Velocity Resolution** | ~0.5 m/s | 100 ms integration time |
| **Detection Threshold** | +13 dB | Pfa = 1×10⁻⁶ |
| **Maximum Range** | ~62 km | For 1 m² RCS targets |
| **Range Accuracy** | ±5-10 m | At 20 dB SNR |
| **Velocity Accuracy** | ±0.3-0.5 m/s | At 20 dB SNR |
| **Processing Speed** | 5-10× | Nitro vs standard engine |

---

## Software Requirements

### MATLAB
- **Version:** R2023a or later
- **Required Toolboxes:**
  - Communications Toolbox (USRP interface, baseband file I/O)
  - Phased Array System Toolbox (CFAR detection, radar functions)
  - Signal Processing Toolbox (filtering, spectral analysis)
  - Mapping Toolbox (geographic transformations, visualization)

### Raspberry Pi
- **OS:** Raspberry Pi OS (Bullseye)
- **Software:**
  - `gpsd` - GPS daemon
  - `dump1090` - ADS-B decoder
  - Python 3.x with standard libraries
  - RTL-SDR drivers

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PASSIVE RADAR WORKFLOW                        │
└─────────────────────────────────────────────────────────────────┘

1. DATA COLLECTION (PassiveRadarCollection_wPreFlightChecks.m)
   ├─ Linux kernel optimization
   ├─ 10-second dry run with validation
   ├─ Dual-channel coherence check
   └─ Production capture (hours)

2. QUALITY ASSESSMENT (assess_bb_quality.m)
   ├─ Signal quality metrics (SNR, DC offset)
   ├─ Power spectral density analysis
   ├─ ATSC pilot tone detection
   └─ Spectrogram visualization

3. SYSTEM CHARACTERIZATION (script_QualityEtc.m)
   ├─ Resolution calculation
   ├─ Self-Ambiguity Function (clutter)
   ├─ Cross-Ambiguity Function (targets)
   ├─ Detection threshold calculation
   └─ Coverage and accuracy analysis

4. DETECTION & LOCALIZATION (compute_radar_caf_localized_TbxFns.m)
   ├─ CFAR detection in delay-Doppler space
   ├─ Spline interpolation refinement
   ├─ Guard zone filtering
   └─ Geographic coordinate conversion

5. VALIDATION (ADSB_GPS data)
   ├─ Compare radar detections with ADS-B positions
   ├─ Calculate localization errors
   └─ Generate performance statistics
```

---

## Key Techniques Implemented

- **Bistatic Geometry:** Cross-Ambiguity Function with dual-channel correlation
- **Clutter Suppression:** Reference channel projection subtraction
- **Decimation:** 10× sample rate reduction for processing speed (6.144 MHz → 614.4 kHz)
- **CFAR Detection:** Cell-Averaging Constant False Alarm Rate (2D) with guard bands
- **Spline Interpolation:** Sub-sample peak refinement for improved localization accuracy
- **FFT Acceleration (Nitro):** Frequency-domain correlation using FFT/IFFT instead of time-domain xcorr
  - Leverages FFT computational efficiency: O(N log N) vs O(N²)
  - Equivalent to time-domain results but 5-10× faster
  - Essential for real-time or large dataset processing
- **Guard Zones:** Site-specific clutter rejection based on delay/Doppler thresholds
- **Geographic Mapping:** Bistatic ellipse plotting with Mapping Toolbox

---

## Example Review Notes

Review date: June 26, 2026

- The MathWorks passive bistatic OFDM example adds a true localization stage after measurement extraction: bistatic range plus angle-of-arrival are fused into a 3-D position estimate. The current project stops at bistatic ellipse visualization and range-Doppler tracking, so it does not yet produce a solved target position.
- The example's most relevant toolbox updates for this repository are not a direct swap to `phased.RangeDopplerResponse`. The better fit is to benchmark the existing direct/reflected delay measurement against `phased.TDOAEstimator`, and to compare the custom 2-D CFAR logic against `phased.CFARDetector2D`.
- A direct port of the example's AOA localization stage is blocked by hardware. The current capture path is dual-channel (`RX1` surveillance and `RX2` reference), not a 2-D surveillance array, so azimuth/elevation estimation would require a new coherent multi-element surveillance front end.

---

## References

- **Bistatic Radar Theory:** Willis, N. J., & Griffiths, H. D. (2007). *Advances in Bistatic Radar*
- **Passive Radar:** Griffiths, H. D., & Baker, C. J. (2005). *Passive coherent location radar systems*
- **ATSC Standard:** ATSC A/53 (Digital Television Standard)
- **CFAR Detection:** Finn, H. M., & Johnson, R. S. (1968). *Adaptive detection mode with threshold control*

---

## Contributing

This is a research and development project. For questions or collaboration opportunities, please reach out through MathWorks channels.

---

## License

Proprietary - MathWorks Internal Research

---

*Last Updated: July 10, 2026*
