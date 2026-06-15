# Flight Test Data Collection & Passive Bistatic Radar System

## Project Overview

This repository contains a complete passive bistatic radar system and multi-sensor data collection platform for aircraft detection, localization, and tracking validation. The system is designed to generate shareable datasets for verifying MATLAB Radar and Sensor Fusion and Tracking Toolbox functions.

### System Goals

1. **Passive Bistatic Radar:** Detect and localize aircraft using TV broadcast signals (ATSC) as illuminators of opportunity
2. **Ground Truth Collection:** Capture ADS-B and GPS data for validation and performance assessment
3. **Multi-Sensor Fusion:** Integrate passive radar with RF beacon tracking for enhanced situational awareness
4. **Toolbox Validation:** Generate real-world datasets for testing MathWorks radar and tracking algorithms

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

This script verifies SSH access to the Pi, starts `gatherTCPcompress.py` remotely, waits 15 s, runs the local HDTV capture for 30 s through `matlab -batch`, keeps ADS-B running until the local SDR step actually finishes, leaves ADS-B running for 5 s after that capture, and then stops the Pi logger gracefully before packaging the session locally as:

```text
captures/<session_id>/radar/
captures/<session_id>/truth/
captures/<session_id>/logs/
captures/<session_id>/session_manifest.json
```

At the end of a successful run, the coordinator also prints the exact `sync_capture_session.sh` command to run on the development machine for that packaged session.
For Pi truth capture recovery, the coordinator now reads the Pi session log's `final artifact` record first, then falls back to searching the Pi capture folder and the Pi user's home tree for `adsb_<session_id>` gzip files.

Important syntax notes:
- The default Pi host is `192.168.10.131` and the default Pi user is `pi2`.
- The default local SDR settings are hidden behind `runLocalHDTVCapture.m`:
  - `radio = 'My USRP N320'`
  - `cf = 540e6`
  - `sr = 6.144e6`
  - `lo = 200e3`
  - `gain = [30 50]`
  - `capture-duration = 30`
  - `lead = 15`
  - `tail = 5`
- `--capture-file` sets the base name for the local `.bb` files; the shared session ID is appended automatically.
- `--gain` accepts either a scalar such as `30` or a dual-channel pair such as `30,50`.
- `--announce-host` overrides the hostname/IP that the coordinator prints into the development-machine sync command.
- `adsb_capture/` is only a temporary staging area for fetched truth files.
- The packaged session is written under `captures/` unless `--session-root` is provided.
- `--adsb-stage-dir` overrides the temporary ADS-B staging folder.
- The Pi-side logger writes its session log to `/home/pi2/flightTest/ADSB_GPS/adsb_capture_<session>.log`.
- The testing machine must be able to SSH to the Pi without an interactive password prompt. Verify this first with `ssh -o BatchMode=yes -o ConnectTimeout=10 pi2@192.168.10.131 "echo READY"`.

Typical capture overrides:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --gain 28,48 --capture-duration 30 --capture-file n320_hdtv_capture
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
On macOS, the sync script will try `/Applications/MATLAB*.app/bin/matlab` automatically if `matlab` is not already on `PATH`.
Pass `--matlab-bin` if the development machine needs a non-default MATLAB executable path or if you want to override the auto-detected MATLAB binary.

### 3. Analyze on the Development Machine

To run the analysis without editing `analyzeBistaticData.m`, use the MATLAB session wrapper:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');
```

The wrapper loads `session_manifest.json`, resolves radar and `adsb_*` files automatically, ignores any `nmea_*` files that appear in the truth list, and preserves direct use of `analyzeBistaticData.m` for manual debugging.
When ADS-B truth is present, the analysis now overlays the projected truth directly on both the static per-part Range-Doppler maps and the interactive RD viewer in bistatic `(R_excess, f_D)` space.

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

If you want to save that post-detection snapshot and replay it later:

```matlab
cd BistaticDataAnalysis
saveDetectionTruthDiagnosticInput(out.truth_diag_input, 'truth_diag_snapshot.mat');

diag = runDetectionTruthDiagnostics('truth_diag_snapshot.mat', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true);
```

This replay path skips the expensive raw IQ, ECA-C, CAF, and CFAR stages. It reruns only ADS-B loading, bistatic truth projection, truth alignment, detection matching, and the comparison plots.

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
- [`runBistaticAnalysisSession.m`](BistaticDataAnalysis/runBistaticAnalysisSession.m) - Supported analysis entrypoint for packaged sessions; returns `truth_diag_input` for fast diagnostic replay
- [`buildDetectionTruthDiagnosticInput.m`](BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m) - Builds the standalone post-detection bundle used to replay truth diagnostics without reprocessing IQ
- [`saveDetectionTruthDiagnosticInput.m`](BistaticDataAnalysis/saveDetectionTruthDiagnosticInput.m) - Saves a `truth_diag_input` snapshot to MAT for later replay
- [`runDetectionTruthDiagnostics.m`](BistaticDataAnalysis/runDetectionTruthDiagnostics.m) - Re-runs truth alignment, detection matching, and diagnostic plots from a bundle, struct, or MAT snapshot
- [`plotDetectionTruthDiagnostics.m`](BistaticDataAnalysis/plotDetectionTruthDiagnostics.m) - Plots `R_excess` vs time and `f_D` vs time with matched and unmatched detections overlaid on truth
- [`helperBuildTruthQueryTimes.m`](BistaticDataAnalysis/helperBuildTruthQueryTimes.m) - Builds the block-center time grid used to align ADS-B truth to the radar processing cadence
- [`helperPlotRDMTruthOverlay.m`](BistaticDataAnalysis/helperPlotRDMTruthOverlay.m) - Overlays ADS-B truth directly on Range-Doppler figures in bistatic measurement space
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
This starts ADS-B on the Pi, waits 15 s, runs the local SDR capture for 30 s, keeps ADS-B running until that local capture completes, lets ADS-B run a few seconds longer, then stops the Pi logger gracefully and writes a packaged session to `captures/<session_id>/`.
When packaging completes, the script prints the exact sync command to copy that session onto the development machine.

To tune gains or timing without rewriting a long MATLAB command:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh --gain 28,48 --lead-seconds 15 --tail-seconds 5
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

### 2b. Re-run Only the Detection-vs-Truth Diagnostics
```matlab
cd BistaticDataAnalysis
diag = runDetectionTruthDiagnostics(out.truth_diag_input, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true, ...
    'PlotTrackComparison', false);
```
Use this after one full session run when you only want to iterate on truth alignment, truth overlays, or detection-vs-truth checks.

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

*Last Updated: June 15, 2026*
