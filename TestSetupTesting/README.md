# Passive Bistatic Radar for Aircraft Localization
## Apple Hill Campus, MathWorks - Natick, MA

This repository contains MATLAB code for evaluating, characterizing, and processing data from a passive bistatic radar system designed to detect and localize aircraft using ATSC television signals as an illuminator of opportunity.

---

## System Overview

**Configuration:**
- **Receiver (RX):** Apple Hill Campus, Natick, MA (42.3007°N, -71.3490°W)
- **Transmitter (TX):** ATSC TV Tower (42.311389°N, -71.216111°W)
- **Hardware:** USRP N320 (Dual-channel, phase-coherent)
- **Signal:** ATSC TV broadcast at 540 MHz, 6 MHz bandwidth
- **Sample Rate:** 6.144 MHz (configurable down to 614.4 kHz via decimation)
- **Target Application:** Detection of aircraft on approach to Logan International Airport

---

## Standalone Pluto Tone Precheck

The Pluto-driven standalone precheck is being developed separately from the working coordinated acquisition path so the hardware-readiness gate can be proven before any integration work.
The frozen pre-implementation contract lives in [plutoTonePrecheckDesignSpec.md](plutoTonePrecheckDesignSpec.md) and defines the exact MATLAB entrypoints, result and baseline schemas, summary metrics, artifact layout, and fail/warn codes for this phase.
The current implemented slice covers the live standalone wrapper `runPlutoTonePrecheck.m`, baseline loading and mismatch checks, deterministic Pluto waveform/TX startup, reuse of `runLocalHDTVCapture.m`, capture readback through `BistaticDataAnalysis/loadIQData.m`, channel and joint scoring, compact result/artifact writing, saved-result review, and baseline commissioning from prior standalone run artifacts or in-memory results.
The wrapper is still intentionally separate from the working coordinated capture path, and `commissionPlutoToneBaseline` still uses the temporary offline `RunSources` path rather than starting hardware itself.
When the Pluto support package runtime is missing, the wrapper now fails cleanly with `PLUTO_CONNECT_FAILED` and writes a reviewable run folder without attempting the N320 capture.
A separate companion plan, [PlutoWaveformPlan.md](PlutoWaveformPlan.md), now documents a **Phase 2** standalone follow-on analysis over archived Phase 1 captures. It does not replace the current Phase 1 tone precheck or its public runtime contract.
For an SSH-friendly checked-in Stage 6 smoke-test entrypoint, use [runPlutoToneStage6Smoke.m](runPlutoToneStage6Smoke.m) from the `TestSetupTesting/` folder.
For a fixed-placement commissioning sweep that compares tone offsets and amplitudes before you choose a reusable baseline candidate, use [runPlutoToneCommissioningSweep.m](runPlutoToneCommissioningSweep.m).
If that sweep writes the per-run folders but then errors while building the top-level summary, recover the saved artifacts with [reviewPlutoToneCommissioningSweep.m](reviewPlutoToneCommissioningSweep.m) before deciding to rerun the hardware.
For a shareable plain-text Live Editor notebook that runs the current Phase 1 unit tests and smoke tests in order, use [PlutoPhase1ValidationLive.m](PlutoPhase1ValidationLive.m).
Treat that notebook as the primary Phase 1 verification entrypoint for both human review and future agentic sessions.
Open that notebook in the MATLAB Live Editor on the testing machine and use **Run All**. The run controls near the top let you skip individual smoke stages or enable the full wrapper once `baselinePath` is set.
That notebook now also records the accumulated Stage 6 field-trial matrix, the recovered fixed-placement commissioning sweep review for `stairwell_outside_box_nooelec_4p9in`, and the next recommended geometry-only follow-up test at `599 MHz / 250 kHz / ToneAmplitude 0.50`.
For staged testing-machine bring-up before running the calibration wrapper, see [plutoCalibrationHardwareBringup.md](plutoCalibrationHardwareBringup.md).
The bring-up checklist now includes the same observed field-trial matrix plus short operator notes about which physical setups and tone-level changes helped and which ones did not.

### Pluto Calibration Sequence

The current standalone calibration/precheck flow is:

1. Load the commissioned Pluto baseline and validate that the frozen runtime settings still match it.
2. Build one deterministic Pluto baseband CW waveform at the requested `ToneOffset_Hz` and `ToneAmplitude`.
3. Start Pluto transmission first so the RF tone is present in the air before the receive capture begins.
4. Run one short dual-channel N320 capture through `runLocalHDTVCapture.m` while the Pluto is transmitting.
5. Read the first `.bb` file written by that N320 capture, not a Pluto-side file, through `BistaticDataAnalysis/loadIQData.m`.
6. Interpret the received N320 channels with the frozen mapping `RF0:RX2 -> CH1 / RX1 -> SURV` and `RF1:RX2 -> CH2 / RX2 -> REF`.
7. Score the received tone on each USRP channel for detect margin, frequency error, absolute level, and baseline-relative level drift, then add the joint channel-frequency consistency check plus advisory-only `xcorr`.
8. Write a self-contained result folder with `result.mat`, `result.json`, `summary.txt`, `summary.png`, and the capture-file reference so the run can be reviewed later without rerunning hardware.

### Phase 1 Commissioning Sweep

Once the Pluto placement is physically fixed, the preferred path to a reusable baseline is:

1. Run [runPlutoToneCommissioningSweep.m](runPlutoToneCommissioningSweep.m) on that fixed setup.
2. Review the ranked configuration summary to choose the best tone offset and amplitude candidate.
3. Rerun the winning configuration for a longer repeated series.
4. Feed those saved run folders into `commissionPlutoToneBaseline` to create the reusable baseline file.

The default commissioning sweep compares:

- `ToneOffset_Hz = [250e3, 1.5e6]`
- `ToneAmplitude = [0.50, 0.65, 0.80, 0.90]`

The current code allows amplitudes up to `1.0`, but the first recommended sweep stops at `0.9` to avoid jumping straight to the digital ceiling before the fixed placement is understood.
The recovered July 24, 2026 sweep review still ranked every configuration as `WEAK`, so the next recommended test is not another amplitude sweep. Freeze the waveform at `599 MHz / 250 kHz / ToneAmplitude 0.50` and run a small placement and orientation matrix first.

Important interpretation note:
- The `.bb` file used for scoring is the USRP receive capture collected while the Pluto tone is on. It should therefore contain the Pluto-injected tone as received by the USRP antennas, plus any ambient RF and noise present at the time of capture.

## Evaluation Workflow

The system evaluation follows a multi-stage process to ensure data quality, characterize system performance, and generate aircraft detections:

### Coordinated HDTV + ADS-B Capture

For the recommended coordinated collection workflow, start from the repo root on the Ubuntu testing machine and use the external coordinator:

```bash
cd /path/to/flightTest
bash TestSetupTesting/run_coordinated_hdtv_capture.sh
```

This keeps the Raspberry Pi ADS-B launch outside MATLAB. The shell script starts `gatherTCPcompress.py` on `pi2@192.168.10.131`, then runs the local SDR capture through `matlab -batch` by calling `runLocalHDTVCapture.m`, which hides the stable defaults such as `radio='My USRP N320'` and `lo=200e3`. The Pi logger now runs until the coordinator observes the local capture finish, then the coordinator waits the configured tail interval and sends a graceful stop signal so MATLAB startup latency does not truncate the ADS-B window.

Each successful run is packaged locally under the repo-root `captures/` folder as:

```text
captures/<session_id>/radar/
captures/<session_id>/truth/
captures/<session_id>/logs/
captures/<session_id>/session_manifest.json
```

`adsb_capture/` is only a temporary staging directory for fetched ADS-B files. The packaged session folder is the supported handoff artifact for post-capture analysis.
At the end of a successful run, the coordinator prints the exact development-machine sync command for that session. Use `--announce-host` if the testing machine needs to advertise a specific hostname or IP in that printed command.
For Pi truth capture recovery, the coordinator first reads the Pi session log's `final artifact` path, then falls back to searching the Pi capture directory and the Pi user's home tree for `adsb_<session_id>` gzip files.

To pull one packaged session to a development machine, run:

```bash
cd /path/to/flightTest
bash TestSetupTesting/sync_capture_session.sh --host <testing-machine> --user <testing-user> --session-id <id>
```

If the testing machine writes packaged sessions somewhere other than `~/agenticProjects/flightTest/captures`, also pass `--remote-root <path>`.
Large radar captures can take several minutes to transfer, and `rsync` may appear quiet while it copies the radar file.
In an interactive terminal on the development machine, the sync script then asks whether to launch `runBistaticAnalysisSession('<session_id>')` immediately. If you answer no, or pass `--no-ask-analysis`, it prints the exact MATLAB command instead.
On macOS, the script will try `/Applications/MATLAB*.app/bin/matlab` automatically if `matlab` is not already on `PATH`. Pass `--matlab-bin <path>` if you want to override that path or if MATLAB lives somewhere else.

To analyze that synced session without editing the engine script, run:

```matlab
cd BistaticDataAnalysis
out = runBistaticAnalysisSession('20260611T101530');
```

The older `runCoordinatedHDTVCapture.m` MATLAB workflow is still present for backward compatibility, but it is now the secondary path.

### 1. **Data Collection with Pre-Flight Checks**

**Script:** [PassiveRadarCollection_wPreFlightChecks.m](PassiveRadarCollection_wPreFlightChecks.m)

This mission control wrapper validates system health before production data collection:

- **Linux Kernel Optimization:** Sets network buffer sizes (50MB) and CPU performance mode
- **Dry-Run Test:** Captures 10 seconds of data for validation
- **Data Integrity Checks:**
  - Zero detection (dropped packets/disk bottleneck)
  - Dual-channel verification
  - Signal power analysis
  - Time-synchronization between channels via cross-correlation
- **Disk Space Verification**
- **Production Capture:** Records multi-hour datasets (default: 2 hours)

**Key Function:** [log_iq_n320_2antennas.m](log_iq_n320_2antennas.m)

---

### 2. **Baseband Quality Assessment**

**Script:** [assess_bb_quality.m](assess_bb_quality.m)

Comprehensive analysis of recorded IQ data to validate signal quality:

- **DC Offset Analysis:** Measures and reports DC bias relative to RMS
- **Power Spectral Density (PSD):** Welch method with configurable FFT length
- **Occupied Bandwidth (OBW):** Calculates 99% power bandwidth
- **In-Band vs. Out-of-Band Power:** Validates signal centering
- **SNR Estimation:** Ratio of in-band to out-of-band power
- **ATSC Pilot Tone Detection:** Verifies presence of expected -2.69 MHz pilot
- **Spectrogram Visualization:** Time-frequency analysis for transient events

**Example Usage:**
```matlab
[x, Fs] = assess_bb_quality('n320_540_5Msps_10s.bb', 'cf', 540e6, 'bw', 6e6);
```

**Outputs:**
- Cleaned, centered IQ data
- Quality metrics (DC offset, SNR, bandwidth)
- Diagnostic plots (PSD, spectrogram)

---

### 3. **Dual-Channel Coherence Verification**

**Script:** [check_dual_channel_coherence.m](check_dual_channel_coherence.m)

Validates phase-alignment between surveillance and reference channels:

- **Cross-Correlation Analysis:** Computes correlation between Channel 1 (Surveillance) and Channel 2 (Reference)
- **Direct Path Detection:** Identifies the peak corresponding to the direct signal path
- **Peak-to-Sidelobe Ratio (PSLR):** Quantifies coherence quality (>15 dB indicates success)
- **Timing Offset Measurement:** Reports relative delay in microseconds

**Success Criteria:** PSLR > 15 dB confirms channels are phase-coherent

---

### 4. **System Characterization**

**Script:** [script_QualityEtc.m](script_QualityEtc.m)

Comprehensive performance analysis integrating multiple characterization functions:

#### 4.1 Resolution Calculation
**Function:** [calc_system_resolution.m](calc_system_resolution.m)
- **Range Resolution:** Determined by signal bandwidth (6 MHz) → ~50 meters
- **Velocity Resolution:** Determined by coherent integration time (Tint) and wavelength
  - Doppler resolution: 1/Tint
  - Velocity resolution: (Doppler_res × λ) / 2

#### 4.2 Self-Ambiguity Function (SAF)
**Function:** [calculate_saf.m](calculate_saf.m)
- Characterizes surveillance channel clutter profile
- 2D correlation across delay and Doppler axes
- Identifies static objects (0 Doppler, significant delay)
- Guides clutter suppression strategy

#### 4.3 Detection Threshold Calculation
**Function:** [calc_detection_threshold.m](calc_detection_threshold.m)
- Statistical threshold based on desired probability of false alarm (Pfa = 1e-6)
- Calculates Peak-to-Noise Ratio (PNR) of current data
- Uses median-based noise floor estimation
- Provides threshold in dB above noise floor

#### 4.4 Coverage Map Generation
**Function:** [calc_coverage_map.m](calc_coverage_map.m)
- Bistatic radar link budget analysis
- Estimates maximum detection range for specified target RCS
- Uses measured direct path power and noise floor
- Accounts for baseline geometry and bistatic loss
- **Default Target:** 1.0 m² RCS (small aircraft/Cessna)
- **Typical Range:** ~62 km from receiver

#### 4.5 Theoretical Accuracy Analysis
**Function:** [calc_theoretical_accuracy.m](calc_theoretical_accuracy.m)
- Predicts localization uncertainty based on SNR
- Range uncertainty (meters)
- Velocity uncertainty (m/s)
- Referenced to strong target SNR (typically 20 dB)

#### 4.6 Suppression Depth Measurement
**Function:** [calc_suppression_depth.m](calc_suppression_depth.m)
- Quantifies dynamic range of clutter suppression
- Measures isolation between surveillance and reference channels
- Reports system dynamic range in dB

#### Output: Mission Report
All metrics compiled into a structured table:
- Range/Velocity Resolution
- Detection Threshold
- Maximum Coverage
- Localization Accuracy
- Suppression Depth
- Saved as: `MissionReport_LoganCorridor.mat`

---

### 5. **Cross-Ambiguity Function (CAF) Processing**

The core detection engine computes the bistatic range-Doppler map through multiple variants:

#### 5.1 Standard CAF Engine
**Script:** [compute_radar_caf.m](compute_radar_caf.m)

Optimized processing pipeline:
- **Digital Re-Centering:** Shifts signal to baseband before decimation (-4.8 MHz offset)
- **Decimation:** Reduces sample rate by 10× (6.144 MHz → 614.4 kHz) for speed
- **Clutter Suppression:** Optional subtraction of reference channel projection
- **Cross-Correlation:** Searches delay-Doppler space
  - Delay range: 0-300 µs
  - Doppler range: ±1000 Hz (5 Hz steps)
- **Output:** 2D CAF map (Doppler × Delay)

#### 5.2 Nitro CAF Engine
**Script:** [compute_radar_caf_nitro.m](compute_radar_caf_nitro.m)

FFT-based acceleration for production processing:
- Uses frequency-domain correlation via FFT/IFFT
- Significantly faster than time-domain xcorr
- Numerically equivalent results
- **Benchmark:** Typically 5-10× speedup over standard engine

**Comparison Tool:** [BenchmarkEngine.m](BenchmarkEngine.m)

#### 5.3 Thresholded Detection
**Script:** [compute_radar_caf_thresholded.m](compute_radar_caf_thresholded.m)

Applies CFAR (Constant False Alarm Rate) detection to CAF map:
- 2D CA-CFAR detector (Cell-Averaging)
- Guard band: 3×3 cells
- Training band: 5×5 cells
- Probability of false alarm: 1e-6

#### 5.4 Interpolated CAF
**Script:** [compute_radar_caf_interpolated.m](compute_radar_caf_interpolated.m)

Enhances sensitivity through sub-sample refinement:
- Spline interpolation around detected peaks
- Improves range/Doppler accuracy
- Increases effective resolution

---

### 6. **Aircraft Localization**

**Script:** [compute_radar_caf_localized_TbxFns.m](compute_radar_caf_localized_TbxFns.m)

Converts range-Doppler detections to geographic coordinates:

#### Processing Pipeline:
1. **Data Intake:** Accepts filename or raw data matrix (for batch processing)
2. **Engine Selection:** Switches between standard or Nitro CAF engine
3. **CFAR Detection:** 2D detection with guard zones
4. **Guard Zone Filtering:** Site-specific clutter rejection
   - Delay > 2.0 µs
   - |Doppler| > 5.0 Hz
5. **Spline Refinement:** Sub-sample peak localization
6. **Bistatic Geometry:** Converts delay to total path length
7. **Ellipse Plotting:** Visualizes detection on geographic map using Mapping Toolbox

**Key Function:** [calculate_bistatic_ellipse.m](calculate_bistatic_ellipse.m)

**Outputs:**
- Detection table: Delay (µs), Doppler (Hz), Total Path (km)
- Geographic map with bistatic ellipses
- TX/RX positions and baseline

---

### 7. **Batch Processing**

**Script:** [IQDataProcessing.m](IQDataProcessing.m)

Production pipeline for processing long-duration datasets:

- **Coherent Processing Interval (CPI):** 0.1 seconds (100 ms)
- **Sequential Processing:** Iterates through entire baseband file
- **Progress Tracking:** Real-time ETA and completion percentage
- **Detection Consolidation:** Aggregates all detections with timestamps
- **Output:** CSV file with all detections and metadata

**Configuration:**
- Toggle Nitro engine: `useNitro = true`
- Control plotting: `showPlots = false` (for speed)
- Auto-save results: `saveConsolidated = true`

**Example Output:** `Results_n320_dual_capture_Dec29_230pm.csv`

---

### 8. **Coverage Visualization**

**Script:** [VisualizeCoverage_Estimate.m](VisualizeCoverage_Estimate.m) / [VisualizeCoverage_Estimate2.m](VisualizeCoverage_Estimate2.m)

Geographic visualization of system coverage:

- **2D Map:** Coverage circle overlaid on Massachusetts coastline
- **Ground Track:** Logan International Airport approach path
- **Hardware Positions:** TX and RX locations
- **3D Situation Display:** Range rings and elevation profile
- **Coverage Estimate:** Typically 62 km radius for 1.0 m² RCS target

---

## File Organization

### Data Collection
- `PassiveRadarCollection_wPreFlightChecks.m` - Mission control with validation
- `log_iq_n320_2antennas.m` - Dual-channel IQ logging
- `log_iq_n320.m` - Single-channel variant

### Quality Assessment
- `assess_bb_quality.m` - Comprehensive signal quality analysis
- `check_dual_channel_coherence.m` - Phase synchronization validation
- `script_QualityEtc.m` - Master characterization script

### System Characterization
- `calc_system_resolution.m` - Range/velocity resolution
- `calc_detection_threshold.m` - Statistical threshold calculation
- `calc_coverage_map.m` - Link budget and max range
- `calc_theoretical_accuracy.m` - Localization uncertainty
- `calc_suppression_depth.m` - Dynamic range measurement
- `calculate_saf.m` - Self-ambiguity function (clutter map)

### CAF Processing Engines
- `compute_radar_caf.m` - Standard time-domain engine
- `compute_radar_caf_nitro.m` - FFT-accelerated engine
- `compute_radar_caf_thresholded.m` - CFAR detection
- `compute_radar_caf_interpolated.m` - Sub-sample refinement
- `compute_radar_caf_localized.m` - Geographic localization
- `compute_radar_caf_localized_TbxFns.m` - Production localization (with Mapping Toolbox)

### Batch Processing
- `IQDataProcessing.m` - Production batch processor
- `BenchmarkEngine.m` - Performance comparison tool

### Utilities
- `calculate_bistatic_ellipse.m` - Bistatic geometry calculations
- `VisualizeCoverage_Estimate.m` - Geographic coverage maps
- `VisualizeCoverage_Estimate2.m` - Alternative visualization
- `dualChannelQuickCheck.m` - Quick coherence check

### Data Files
- `*.bb` - Baseband IQ recordings from USRP N320
- `MissionReport_LoganCorridor.mat` - Saved performance metrics

---

## Quick Start Guide

### 1. Collect Data
```matlab
% Run pre-flight checks and collect 2 hours of data
PassiveRadarCollection_wPreFlightChecks
```

### 2. Assess Quality
```matlab
% Evaluate signal quality
[x, Fs] = assess_bb_quality('n320_dual_capture.bb', 'cf', 540e6, 'bw', 6e6);

% Check channel coherence
check_dual_channel_coherence('n320_dual_capture.bb', 6.144e6);
```

### 3. Characterize System
```matlab
% Run comprehensive characterization
script_QualityEtc
% Generates: MissionReport_LoganCorridor.mat
```

### 4. Process for Detections
```matlab
% Batch process entire file
IQDataProcessing
% Generates: Results_*.csv with all detections
```

### 5. Visualize Coverage
```matlab
% Plot coverage map
VisualizeCoverage_Estimate
```

---

## System Requirements

- **MATLAB Version:** R2023a or later (recommended)
- **Required Toolboxes:**
  - Communications Toolbox (USRP hardware interface, baseband file I/O)
  - Phased Array System Toolbox (CFAR detection, radar functions)
  - Signal Processing Toolbox (filtering, correlation, spectral analysis)
  - Mapping Toolbox (geographic coordinate transformations, visualization)
- **Hardware:** USRP N320 with dual-channel configuration
- **OS:** Linux recommended (for kernel optimizations in data collection)
- **Disk Space:** ~4 GB per hour of recording at 6.144 MHz sample rate

---

## Key Performance Metrics

**Typical System Performance:**

| Metric | Value | Units |
|--------|-------|-------|
| Range Resolution | ~50 | meters |
| Velocity Resolution | ~0.5 | m/s |
| Detection Threshold | +13 | dB above noise |
| Maximum Range (1 m² RCS) | ~62 | km |
| Range Accuracy (20 dB SNR) | ±5-10 | meters |
| Velocity Accuracy (20 dB SNR) | ±0.3-0.5 | m/s |
| Processing Speed (Nitro) | 5-10× | vs. standard |

---

## Troubleshooting

### Common Issues:

**1. Weak Coherence (PSLR < 15 dB)**
- Check antenna alignment
- Verify reference channel gain (should be ~20 dB higher than surveillance)
- Ensure cables are not swapped

**2. Zeros in Recorded Data**
- Increase network buffer size (`rmem_max`)
- Switch to faster disk (SSD recommended)
- Reduce sample rate or duration

**3. No Detections**
- Verify direct path signal is present (check PSD for strong peak)
- Lower detection threshold
- Increase coherent integration time (Tint)
- Check that aircraft are actually present in coverage area

**4. Processing Too Slow**
- Use Nitro engine (`useNitro = true`)
- Increase decimation factor
- Reduce Doppler search range
- Disable plotting in batch mode

---

## References

- **Bistatic Radar Principles:** Willis, N. J., & Griffiths, H. D. (2007). *Advances in Bistatic Radar*
- **ATSC Signal Specification:** ATSC Standard A/53 (Digital Television Standard)
- **CFAR Detection:** Finn, H. M., & Johnson, R. S. (1968). Adaptive detection mode with threshold control
- **USRP N320:** Ettus Research, [N320 Product Documentation](https://www.ettus.com/all-products/usrp-n320/)

---

## Author & Location

**System Location:** Apple Hill Campus, MathWorks, Natick, MA  
**Transmitter:** ATSC TV Tower, Eastern Massachusetts  
**Target Scenario:** Aircraft approaching Logan International Airport

---

## License

This code is provided for evaluation and research purposes.

---

## Notes

- All GPS coordinates are in WGS84 datum
- Range values assume bistatic geometry (sum of TX→Target and Target→RX distances)
- Doppler sign convention: positive = approaching receiver
- Delay values are relative to the direct path signal
- Processing assumes ATSC 8-VSB modulation with pilot tone at -2.69 MHz offset

---

*Last Updated: June 15, 2026*
