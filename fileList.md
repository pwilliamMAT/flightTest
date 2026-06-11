# TestSetupTesting File Inventory

This file documents the current contents of `TestSetupTesting` at a high level so archive decisions can be made before capture workflow changes are merged.

Classification tags:
- `active`: appears to be part of the current workflow or a likely reusable helper
- `candidate-archive`: appears superseded, scratch/demo-only, auto-save, or data artifact
- `unknown-review`: purpose is clear, but current usage in the active workflow is uncertain

## Inventory

| File | Classification | High-Level Purpose | Archive Rationale |
| --- | --- | --- | --- |
| `README.md` | `active` | Folder-level documentation for the passive radar evaluation workflow. | Keep as active documentation. |
| `PassiveRadarCollection_wPreFlightChecks.m` | `active` | Local mission-control script that runs preflight checks and then starts SDR capture. | Keep; it is a top-level collection entrypoint. |
| `log_iq_n320_2antennas.m` | `active` | Main dual-channel N320 capture function used for passive radar data collection. | Keep; this is the core SDR logger. |
| `log_iq_n320.m` | `unknown-review` | Single-channel capture variant using Wireless Testbench saved radio configurations. | Review whether single-channel capture is still needed alongside the dual-channel workflow. |
| `runLocalHDTVCapture.m` | `active` | Local-only HDTV capture wrapper that centralizes the stable SDR defaults for terminal-driven runs. | Keep; this is now the recommended MATLAB entrypoint for the SDR step. |
| `run_coordinated_hdtv_capture.sh` | `active` | External Ubuntu coordinator that starts ADS-B on the Pi and then launches the local SDR capture with `matlab -batch`. | Keep; this is now the recommended coordinated-capture entrypoint. |
| `runCoordinatedHDTVCapture.m` | `active` | Legacy MATLAB-owned coordinator that starts Pi ADS-B logging and local SDR capture together. | Keep for backward compatibility, even if it becomes legacy. |
| `helperQuotePosixArg.m` | `active` | Small helper for safely quoting arguments passed to a remote POSIX shell. | Keep; still useful for any SSH-based workflow. |
| `assess_bb_quality.m` | `active` | Quick-look quality assessment for a captured baseband file, including PSD and diagnostic plots. | Keep; useful for validating new captures. |
| `check_dual_channel_coherence.m` | `active` | Verifies coherence and relative timing between the two recorded channels. | Keep; important for validating dual-channel capture health. |
| `script_QualityEtc.m` | `active` | Top-level characterization and detection script that chains together quality and detection analyses. | Keep; appears to be the main downstream analysis driver in this folder. |
| `IQDataProcessing.m` | `active` | Batch-processing script for longer recordings using the production detection/localization path. | Keep; likely needed for longer post-processing runs. |
| `BenchmarkEngine.m` | `unknown-review` | Compares standard and Nitro CAF implementations for speed and numerical agreement. | Review whether benchmarking is still part of the maintained workflow or just development support. |
| `compute_radar_caf.m` | `active` | Baseline cross-ambiguity function engine for range-Doppler processing. | Keep; foundational processing function. |
| `compute_radar_caf_nitro.m` | `active` | Faster FFT-based CAF implementation for production-style processing. | Keep; paired with the standard engine. |
| `compute_radar_caf_thresholded.m` | `active` | Applies thresholding and peak extraction on top of the CAF map. | Keep; direct extension of the detection flow. |
| `compute_radar_caf_interpolated.m` | `unknown-review` | Adds sub-sample peak refinement to CAF detections. | Review if this path is still used versus the toolbox-based localization path. |
| `compute_radar_caf_localized.m` | `candidate-archive` | Older localization variant that appears superseded by the toolbox-oriented localization function. | Likely superseded by `compute_radar_caf_localized_TbxFns.m`. |
| `compute_radar_caf_localized_TbxFns.m` | `active` | More robust localization and plotting path using toolbox functions and either CAF engine. | Keep; appears to be the maintained localization implementation. |
| `calc_system_resolution.m` | `active` | Computes theoretical range and Doppler resolution from waveform and CPI settings. | Keep; supports characterization. |
| `calc_detection_threshold.m` | `active` | Estimates a simple threshold and peak-to-noise ratio for the ambiguity map. | Keep; supports characterization. |
| `calc_coverage_map.m` | `active` | Estimates bistatic coverage / maximum range from geometry and noise assumptions. | Keep; supports mission analysis. |
| `calc_theoretical_accuracy.m` | `active` | Estimates expected range and velocity accuracy from SNR and waveform settings. | Keep; supports characterization. |
| `calc_suppression_depth.m` | `active` | Quantifies clutter/direct-path suppression depth and dynamic range. | Keep; supports system characterization. |
| `calculate_saf.m` | `active` | Computes the self-ambiguity function used to inspect clutter structure. | Keep; useful characterization tool. |
| `calculate_bistatic_ellipse.m` | `active` | Geometry helper for plotting bistatic ellipses from transmitter/receiver locations. | Keep; shared localization helper. |
| `VisualizeCoverage_Estimate.m` | `unknown-review` | Produces a mission-report style coverage visualization based on fixed scenario assumptions. | Review whether this is still used or if the second visualization supersedes it. |
| `VisualizeCoverage_Estimate2.m` | `unknown-review` | Alternate higher-fidelity coverage visualization with map imagery and 3D display elements. | Review overlap with `VisualizeCoverage_Estimate.m`; likely only one should stay active long term. |
| `dualChannelQuickCheck.m` | `candidate-archive` | Ad hoc quick-look script with a hard-coded local file path for channel visualization. | Hard-coded path and scratch-script style suggest it should move out of the active workflow. |
| `compute_radar_caf_interpolated.asv` | `candidate-archive` | MATLAB auto-save copy of the interpolated CAF script. | Auto-save artifact; not a maintained source file. |
| `log_iq_n320_2antennas.asv` | `candidate-archive` | MATLAB auto-save copy of the dual-channel logger. | Auto-save artifact; not a maintained source file. |
| `script_QualityEtc.asv` | `candidate-archive` | MATLAB auto-save copy of the characterization script. | Auto-save artifact; not a maintained source file. |
| `MissionReport_LoganCorridor.mat` | `candidate-archive` | Saved result artifact rather than executable source. | Generated data artifact; should not live beside active source unless intentionally curated. |

## Summary

Likely needed for the coordinated capture workflow:
- `log_iq_n320_2antennas.m`
- `runLocalHDTVCapture.m`
- `run_coordinated_hdtv_capture.sh`
- `PassiveRadarCollection_wPreFlightChecks.m`
- `runCoordinatedHDTVCapture.m`
- `helperQuotePosixArg.m`
- `README.md`

Likely needed for downstream analysis:
- `assess_bb_quality.m`
- `check_dual_channel_coherence.m`
- `script_QualityEtc.m`
- `IQDataProcessing.m`
- `compute_radar_caf*.m`
- `compute_radar_caf_localized_TbxFns.m`
- `calc_*.m`
- `calculate_saf.m`
- `calculate_bistatic_ellipse.m`

Most likely archive candidates on first pass:
- `compute_radar_caf_localized.m`
- `dualChannelQuickCheck.m`
- `compute_radar_caf_interpolated.asv`
- `log_iq_n320_2antennas.asv`
- `script_QualityEtc.asv`
- `MissionReport_LoganCorridor.mat`

Files that need a brief keep/archive decision before any move:
- `log_iq_n320.m`
- `BenchmarkEngine.m`
- `compute_radar_caf_interpolated.m`
- `VisualizeCoverage_Estimate.m`
- `VisualizeCoverage_Estimate2.m`
