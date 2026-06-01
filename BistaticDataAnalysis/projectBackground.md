# Project Background: Passive Bistatic Target Localization and Tracking

## 1. Project Overview

This document outlines the plan and key considerations for a project focused on processing In-phase and Quadrature (IQ) data for passive bistatic target localization. The system uses High-Definition Television (HDTV) signals as the signal of opportunity and a USRP N320 for data collection.

The primary technical goal is to estimate a target's 2D trajectory. This will be achieved by first calculating the target's bistatic range using Time Difference of Arrival (TDOA) and then processing a sequence of these range measurements over time with a tracking filter. All processing and analysis will be conducted using MATLAB.

## 2. High-Level Plan

The project will be executed in the following phases:

1.  **Data Loading and Preparation:**
    *   Develop a MATLAB script to read the raw IQ data files (`.bin`), separating the surveillance and reference channels.
    *   Reshape the data into a `fast-time` (samples) by `slow-time` (pulses) matrix to form the data cube for processing.

2.  **Synchronization Check:**
    *   Perform a cross-correlation between the reference and surveillance channels to verify system time synchronization. A strong peak at the expected direct path delay will validate the timing.

3.  **Direct-Path Interference (DPI) and Clutter Mitigation:**
    *   Implement a Doppler-based filtering technique, such as the Enhanced Cancellation Algorithm by Carrier (ECA-C), to remove the strong, stationary direct signal and static clutter from the surveillance channel data.

4.  **Bistatic Range Estimation via TDOA:**
    *   Perform a cross-correlation between the cleaned surveillance signal and the reference signal to find the TDOA of any target echoes.
    *   Convert the TDOA measurement to bistatic range (`range = tdoa * c`).

5.  **Target Detection:**
    *   Apply a Constant False Alarm Rate (CFAR) detector to the range profile (the cross-correlation output) to automatically detect target peaks above the noise floor.

6.  **Trajectory Estimation with a Tracker:**
    *   Initialize and configure a Kalman filter (likely an Extended or Unscented Kalman Filter) to handle the non-linear measurement model.
    *   The filter's state will represent the target's 2D position and velocity.
    *   The bistatic range detections will be used as measurements to update the tracker over time, producing an estimated target trajectory.

## 3. Critical Consideration: ITAR Compliance

**This project must not implement capabilities that are restricted by the International Traffic in Arms Regulations (ITAR).** All development and analysis must be conducted with the explicit goal of remaining within the scope of fundamental research and avoiding the creation of a "defense article."

### ITAR Analysis Summary

Our review of the United States Munitions List (USML) indicates that passive radar systems can fall under ITAR control. The most relevant section is **USML Category XI(a)(3)(xxvii)**, which controls:

> "Bi-static/multi-static radar that exploits greater than 125 kHz bandwidth and is lower than 2 GHz center frequency to passively detect or track using radio frequency (RF) transmissions (e.g., commercial radio, television stations);"

### Guiding Principles for Compliance:

To ensure this project remains outside the scope of ITAR:

1.  **Fundamental Research:** The work should be treated as fundamental research, intended for public dissemination.
2.  **No Military Design:** The software and system must not be "specially designed" for a military end-user or for a military application.
3.  **Public Domain Methods:** The processing techniques used (e.g., cross-correlation, FFT, CFAR, Kalman filtering) are standard, publicly documented algorithms and do not in themselves constitute "technical data" in this context.
4.  **Focus on "How," not "What":** The project's focus is on the scientific process of signal processing, not on creating a deployable, operational system for surveillance.
5.  **Performance Limitations:** While we aim for the best possible results, we will not artificially limit the accuracy of the processing. The key is that the system as a whole is not designed or intended for a controlled military purpose.

All personnel and automated agents working on this project must adhere to these principles to ensure that the resulting software and data are not subject to ITAR export controls.

## 4. Known Algorithm Limitations and Design Notes

### 4.1 Why LMS/NLMS Adaptive Filters Cannot Be Used for DPI Cancellation

A time-domain adaptive filter (LMS or NLMS) cancels interference by learning a finite impulse response (FIR) that maps the reference channel to the surveillance channel. The filter can only model delays **within its tap length**. For a filter of length L taps at sample rate fs, the maximum delay it can cancel is:

> τ_max = L / fs

For the USRP N320 dual-channel recordings in this project, the two ADC pipelines exhibit a hardware timing offset of approximately **6387 samples (~1.28 ms)** due to asynchronous channel start-up. The DPI therefore arrives in the surveillance channel at this lag. To cancel it with NLMS would require a filter of at least 6400 taps — computationally impractical and numerically fragile.

**The correct solution is the Extensive Cancellation Algorithm (ECA)**, which operates in the frequency domain. A delay in time is a linear phase in frequency, so ECA estimates and removes the DPI transfer function per frequency bin without any knowledge of, or constraint on, the lag value. See `mitigateClutter.m` for the implementation.

### 4.2 Hardware vs. Digital Synchronisation of Dual-Channel Recordings

The ~6387-sample timing offset between channels is a **recording artifact**, not a physical path difference. It arises because the USRP N320's two ADC channels start sampling at different buffer boundaries when not explicitly synchronised.

**Hardware fix (preferred for production):** The USRP N320 supports timed starts via its GPSDO / 10 MHz + PPS reference. Both channels can be commanded to begin sampling at the same clock edge by setting a future start time in the Wireless Testbench recording script:
```matlab
bbrx.StartTime = getCurrentTime(bbrx) + seconds(0.1);  % synchronous start
```
This reduces the inter-channel offset to < 1 sample.

**Digital compensation (standard in development/test):** The ECA algorithm is inherently immune to timing offsets. The `dpi_lag` detection in `createRDM.m` is used only to correctly set the range axis origin for display. Both approaches are valid; ideally both are used together.

---

## 5. Implementation Architecture and Visualisation

### 5.1 Modular Per-File Pipeline: `processOnePart.m`

The per-file signal processing chain is encapsulated in `processOnePart.m`. It accepts a file path and a `config` struct and executes the complete pipeline for one 1-second IQ recording:

```
loadIQData → verifySync → ECA-C (mitigateClutter) → CAF (createRDM)
           → NCI → range whitening → CFAR (detectTargets)
```

Returns: `[all_detections, cfar_nf_db, rdm_before, rdm_after, range_axis, doppler_axis, config]`

The orchestration script `analyzeBistaticData.m` calls `processOnePart.m` once per Newton data part (part1/part2/part3) and collects results into a `part_res` struct array, then:
- Runs `assessDetections.m` on the aggregate detection list
- Generates per-part RDM figures with CFAR detection overlays
- Prints a trajectory-summary table

### 5.2 Target Tracking and Post-Detection Visualization

After all parts are processed, `analyzeBistaticData.m` §7 runs the full tracker and visualization pipeline:

```
trackTargets(all_track_dets, config)
    → tracks_log (11 steps × objectTrack arrays)
    → pre-compute step_data (§7.4a)
    → one-pass static globe render (§7.5)
    → track colour legend figure (§7.5)
    → interactive RD map viewer (§7.6, render_rdm_step.m)
```

**Key architectural decisions and their rationale:**

**Measurement-space tracking**: A passive bistatic radar with a single receiver is fundamentally limited to measuring bistatic range excess. Attempting to track in 2D position space (`[x, y, ẋ, ẏ]`) would be physically invalid — the problem is unobservable from one range measurement per snapshot. The 1D state `[R (m); Ṙ (m/s)]` is the correct and minimal observable state for this sensor geometry. See `concepts.md` §"Target Tracking in Measurement Space" for the full mathematical argument.

**`trackerGNN` + custom `initMeasurementSpaceKF.m`**: MATLAB's `trackerGNN` handles data association (Hungarian algorithm), track lifecycle (tentative → confirmed → coasted → deleted), and covariance propagation automatically. The custom initializer overrides the default 2D/3D position-space KF with a 1D range-space KF (`H = [1,0]`, Singer process noise at 400 m²/s³).

**Static globe, not animated**: Animating the globe per tracker time step required ~700 `geoplot3` calls due to the altitude-ribbon technique (11 calls per ellipse at 50 m altitude steps). Each call triggers a WebGL scene redraw in geoglobe. The static one-pass render uses a single `geoplot3` per unique TrackID at last-known state, reducing total calls to ~10 and render time from ~22 s to < 1 s.

**Precomputed `step_data`**: The interactive RD map slider must respond in < 200 ms. If RDM computation (ECA-C + CAF + NCI + whitening) were re-run inside the slider callback, each drag event would take 10–20 s. Pre-computing the whitened RDM image, range/Doppler axes, per-step detection subset, and confirmed track array for all 11 steps at script start (§7.4a) moves all heavy computation out of the callback path.

**Classic `uicontrol`**: MATLAB's App Designer `uifigure`/`uislider` requires the WebView2 runtime and is not universally available across MATLAB Online, desktop, and Codespaces environments. Classic `uicontrol` components work in all MATLAB versions from R2006 onward and behave predictably in all environments.

---

## 6. Current State of the Pipeline (as of 2026-05-27)

The full passive bistatic radar signal processing chain is implemented and validated end-to-end on the Newton MA dataset (3 × 1 s parts, fc = 600 MHz, fs = 5 Msps).

### What works

| Stage | Files | Status |
|-------|-------|--------|
| IQ data loading | `loadIQData.m` | ✅ Complete |
| Synchronisation check | `verifySync.m` | ✅ Complete |
| Clutter mitigation (ECA-C) | `mitigateClutter.m` | ✅ Complete |
| CAF / RDM | `createRDM.m` | ✅ Complete |
| Sub-chunk NCI | `processOnePart.m` | ✅ Complete |
| Range whitening + CFAR (OS-CFAR) | `processOnePart.m`, `detectTargets.m` | ✅ Complete |
| Quality checks A1–D9 | `assessDetections.m` | ✅ Complete |
| CFAR ellipse globe | `plotBistaticEllipses3D.m` | ✅ Complete |
| Measurement-space tracker | `trackTargets.m`, `initMeasurementSpaceKF.m` | ✅ Complete |
| Interactive RD map viewer | `analyzeBistaticData.m` §7.6, `render_rdm_step.m` | ✅ Complete |
| Static globe + track legend | `analyzeBistaticData.m` §7.5 | ✅ Complete |
| Truth-data comparison | — | ❌ No truth data available |

### Validated results (Newton dataset)

- **26 CFAR detections** across 3 file parts (Pfa = 1e-4, OS-CFAR, L = 10 looks)
- **11 tracker time steps**, peak 10 simultaneously confirmed tracks
- **10 unique TrackIDs** over full run
- B3 (clutter suppression), D9 (anomalous SNR): both PASS
- Trajectory physically consistent: primary target shows increasing range (~7 km → ~12 km) with negative Doppler (outbound), consistent with departing aircraft in I-90 corridor

### Natural stopping point and what comes next

The pipeline has reached a natural stopping point: it produces a complete set of outputs (RDM figures, CFAR ellipses, tracker trajectories, interactive viewer, globe visualization) but lacks truth data to numerically validate accuracy. Future work requires:

1. **ADS-B truth integration**: capture simultaneous 1090 MHz ADS-B using a local receiver (e.g., `gatherTCPcompress.py` / `start_adsb_gps_loggers.sh` in `ADSB_GPS/`) time-synchronized to the IQ recording. Convert ADS-B (lat, lon, alt) → bistatic range excess using the same Tx/Rx geometry and compare to tracker `State(1)`.
2. **Multi-receiver extension**: adding a second geographically separated receiver would make the target position observable (two ellipses → intersection point), resolving the fundamental ambiguity of the single-receiver system.
3. **Tighter ConfirmationThreshold**: with longer datasets (more than 3 parts per collection), raising `ConfirmationThreshold` to `[2, 3]` or `[3, 5]` would significantly reduce the false-track rate at the cost of requiring at least 2 consistent detections before confirming a track.
4. **Doppler-color CFAR ellipse globe integration**: `plotBistaticEllipses3D.m` (Doppler-color raw CFAR ellipses) and the tracker globe (`analyzeBistaticData.m` §7.5, per-TrackID-color tracked ellipses) are currently separate figures. A merged view showing both raw and tracked ellipses would aid expert interpretation.

**Design principle**: orchestration (config, loops, figures, quality checks) stays in `analyzeBistaticData.m`; signal processing (per-file IQ pipeline) stays in `processOnePart.m`. This mirrors the step-by-step structure recommended by `agents.md` and makes each module independently testable.

**Range whitening** is the final pre-CFAR stage inside `processOnePart.m`: each RDM row’s median across Doppler is subtracted (in dB) so that the CFAR threshold is set relative to local row noise rather than a global estimate. This compensates the USRP N320’s range-dependent noise floor without requiring a hardware calibration. Absolute detection powers are restored by adding the stored per-row noise floor back before returning detections. See `concepts.md § Range Whitening` for the full rationale.

### 5.2 Geographic Bistatic Ellipse Visualization: `plotBistaticEllipses3D.m`

CFAR detections are visualised as bistatic iso-range ellipses on a geographic map. Each ellipse is the locus of all possible target positions for a given detection’s bistatic range-excess, given the known Tx/Rx geodetic coordinates. Ellipses are colour-coded by data part.

**Output modes:**
- **`geoglobe` (3D)**: `geoplot3` curves at target altitude on a 3D interactive globe with satellite basemap. Requires Mapping Toolbox R2021a+.
- **`geoaxes` (2D fallback)**: `geoplot` curves on a 2D geoaxes with full legend and title. Activated via `'Use2DFallback', true`.

**Usage:**
```matlab
plotBistaticEllipses3D(txLLA, rxLLA, detectionTable);
% or with options:
plotBistaticEllipses3D(txLLA, rxLLA, detectionTable, ...
    'TargetAlt_m', 3000, 'Use2DFallback', true);
```

**Test script**: `test_ellipses.m` (standalone script in `BistaticDataAnalysis/`) exercises the function with placeholder Newton deployment coordinates.

The ellipse geometry and coordinate-frame details are documented in `concepts.md § Bistatic Iso-Range Ellipse Geometry`.