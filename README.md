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

Use the PC as the coordinator. From a terminal on the SDR capture machine, run `matlab -batch` from the repo root:

```bash
cd /path/to/flightTest
matlab -batch "cd('TestSetupTesting'); info = runCoordinatedHDTVCapture('PiHost','192.168.10.131','PiUser','pi2','CaptureFile','n320_hdtv_capture','LocalCaptureArgs',{'radio','My USRP N320','gain',[30 50]}); disp(info.session_id);"
```

This call starts `gatherTCPcompress.py` on the Raspberry Pi over SSH, waits 15 s, runs the local HDTV capture for 30 s, leaves ADS-B running for 5 s after the SDR capture, and then copies the matching `adsb_<session>.txt.gz` file back to the PC.

Important syntax notes:
- `'PiHost'` is required and should be `192.168.10.131` for the current Raspberry Pi setup.
- `'PiUser'` defaults to `'pi2'`.
- `'LocalCaptureArgs'` must be a cell array of name-value pairs passed directly into `log_iq_n320_2antennas`.
- `'CaptureFile'` sets the base name for the local `.bb` files; the shared session ID is appended automatically.
- The example above assumes your shell is in the repo root before `matlab -batch` starts. If not, change `cd('TestSetupTesting')` to the full path to that folder.

To set the timing explicitly instead of using the defaults:

```bash
cd /path/to/flightTest
matlab -batch "cd('TestSetupTesting'); info = runCoordinatedHDTVCapture('PiHost','192.168.10.131','CaptureDuration_s',30,'LeadSeconds_s',15,'TailSeconds_s',5,'LocalCaptureArgs',{'radio','My USRP N320','gain',[30 50]}); disp(info.session_id);"
```

The returned `info` struct contains the shared `session_id`, the local capture file paths, and any ADS-B files copied back from the Pi. Use that `session_id` later in `analyzeBistaticData.m` to select the matching radar capture.

---

## Repository Structure

### 📁 [`TestSetupTesting/`](TestSetupTesting/)
**Passive Bistatic Radar System - Main Processing Pipeline**

Complete MATLAB implementation for passive radar data collection, quality assessment, system characterization, and aircraft detection/localization.

**Key Components:**

#### Data Collection
- [`PassiveRadarCollection_wPreFlightChecks.m`](TestSetupTesting/PassiveRadarCollection_wPreFlightChecks.m) - Mission control with Linux optimization and hardware validation
- [`log_iq_n320_2antennas.m`](TestSetupTesting/log_iq_n320_2antennas.m) - Dual-channel IQ data recording
- [`runCoordinatedHDTVCapture.m`](TestSetupTesting/runCoordinatedHDTVCapture.m) - Starts Raspberry Pi ADS-B logging over SSH, waits for lead time, runs the local 30 s HDTV capture, and optionally copies the matching ADS-B file back to the PC
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
matlab -batch "cd('TestSetupTesting'); info = runCoordinatedHDTVCapture('PiHost','192.168.10.131','CaptureFile','n320_hdtv_capture','LocalCaptureArgs',{'radio','My USRP N320','gain',[30 50]}); disp(info.session_id);"
```
This starts ADS-B on the Pi, waits 15 s, runs the local SDR capture for 30 s, lets ADS-B run a few seconds longer, and copies the matching `adsb_<session>.txt.gz` file back to the PC.

### 2. Run System Characterization
```matlab
script_QualityEtc  % Complete workflow: quality → characterization → detection
```

### 3. Batch Process Long Recordings
```matlab
IQDataProcessing  % Processes entire file, outputs Results_*.csv
```

### 4. Start Ground Truth Collection (Raspberry Pi)
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

*Last Updated: June 10, 2026*
