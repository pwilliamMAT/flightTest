# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A MATLAB passive bistatic radar (PBR) project. It uses ATSC HDTV broadcasts (~599 MHz) as the illuminator, a dual-channel USRP N320 as the receiver (SURV + REF), and ADS-B logged on a Raspberry Pi as ground truth. A second strand of work uses an ADALM-Pluto as a known calibration transmitter to check the N320 receive chain and antennas. There is no build step. Code is MATLAB (toolbox-heavy) plus bash/Python glue.

## Working conventions (from `agents.md`)

- **Prefer toolbox functions** (Phased Array System, Radar, Signal Processing, Communications) over custom implementations, e.g. `pwelch`, `phased.CFARDetector2D`, `phased.MatchedFilter`, `comm.BasebandFileReader/Writer`.
- New signal-processing steps get plain-language explanation, heavily commented code (what + why), and a visualization.
- **Update `concepts.md`** (the root one) when adding or substantially changing a concept. It is a table mapping each concept to its implementing files. Recent commits also update `TestSetupTesting/README.md` and the relevant feature `.md` (e.g. `TestSetupTesting/Azimuth-Calibration.md`) in the same change. Follow that pattern.
- Verify each step runs before moving on. The MATLAB MCP tools (`evaluate_matlab_code`, `run_matlab_test_file`) run code in the user's live MATLAB session.
- Public entrypoints use `inputParser` name/value parameters with a documented header block (concept, workflow, example, `See also`). Private helpers are `helper*.m` files, and file-local functions are prefixed `local*`.

## Running tests

Tests are a mix of `matlab.unittest` class-based tests (`*Test.m`) and older script-style `assert` tests (`test_*.m`). Run them from their own folder:

```matlab
cd TestSetupTesting
runtests('PlutoTonePrecheckHelperTest')                       % one class
runtests('PlutoTonePrecheckHelperTest/testChannelScorerFindsToneAndPassesThresholds')  % one method

cd BistaticDataAnalysis
runtests('bistaticTruthConventionTest.m')
runtests('tests')                                             % tests/ subfolder (ATSC pilot, toolbox benchmark, visualization)
test_bistaticHelpers                                          % script-style: just run it
```

Some tests (e.g. `tests/ATSCPilotAuditTest.m`) depend on a captured session under `captures/` and skip or degrade gracefully if it is absent. `TestSetupTesting/PlutoPhase1ValidationLive.m` is the plain-text Live Script that runs the Pluto Phase 1 unit and smoke tests in order.

Python: `python3 ADSB_GPS/test_gatherTCPcompress.py`.

## Architecture

### Three-machine data flow

1. **Testing machine** (Ubuntu, N320 attached): `TestSetupTesting/run_coordinated_hdtv_capture.sh` SSHes to the Pi (`pi2@192.168.10.131`) to start `ADSB_GPS/gatherTCPcompress.py`, runs `matlab -batch "runLocalHDTVCapture"` (defaults live in that file), stops the Pi logger, and packages `captures/<session_id>/{radar,truth,logs}/` + `session_manifest.json`.
2. **Development machine**: `TestSetupTesting/sync_capture_session.sh --host … --user … --session-id …` rsyncs one session.
3. **Analysis**: `cd BistaticDataAnalysis; out = runBistaticAnalysisSession('<session_id>')`.

`captures/`, `adsb_capture/`, `*.bb`, `*.mat`, and `*.txt` are gitignored. Data never goes in commits.

### `BistaticDataAnalysis/`: session analysis pipeline

- `runBistaticAnalysisSession.m` is the supported entrypoint. It resolves the manifest (`helperLoadSessionManifest`, `helperResolveSessionAnalysisSetup`), carries header/manifest frequency into config, then drives `analyzeBistaticData.m`. That file is the monolithic processing engine and can also be run directly for debugging.
- Chain: `loadIQData` → `checkRefQuality` / ATSC pilot audit → `mitigateClutter` (ECA-C) → `createRDM` (CAF/range-Doppler) → `detectTargets` (custom CFAR) → `trackTargets` → ADS-B truth (`loadADSBTruth` → `adsbToBistatic` → `alignTruthToRadar` → `assessTruthVsDetections`).
- **Checkpoint/replay design**: a full run saves `captures/<id>/analysis/truth_diag_input.mat` and `detector_replay_input.mat`. `runDetectionTruthDiagnostics` and `runDetectorReplaySweep` restart from those files so you can iterate without redoing IQ/ECA/CAF. `out.restart_commands` prints the exact calls.
- **Measurement convention** (shared by truth projection, RDM axes, and tracker; do not diverge): `R_excess = R_tx + R_rx − L_3D`, `f_D = −(fc/c)·dR_excess/dt`, `range_cell_m = c/fs`, RDM Doppler axis at FFT bin centers. Use the `helperBistaticDoppler*` and `helperDeriveTxRxGeometry` helpers, not ad-hoc formulas. `bistaticTruthConventionTest.m` guards this.
- `VisualizationProfile` (`core` default / `full` / `headless`) via `helperResolveVisualizationProfile` gates risky `uifigure`/`geoglobe` figures.
- `runDirectPathPrecheck` / `runSessionRFQualityAudit` are fast pre-analysis gates. Toolbox TDOA/CFAR (`runOfflineToolboxBenchmark`) are offline comparisons only. The custom CAF/CFAR path remains production (see `toolboxReplacementAssessment.md`).
- Known state: the integrated pipeline works end to end, but the detector is not yet producing truth-matched detections. See `NEXT_SESSION_HANDOFF.md`.

### `TestSetupTesting/`: capture stack and Pluto calibration work

- N320 capture: `runLocalHDTVCapture.m` → `log_iq_n320_2antennas.m` writes `.bb` via `comm.BasebandFileWriter` (every write must use the same frame size). Channel mapping is frozen: **CH1/RX1 = SURV, CH2/RX2 = REF**.
- Pluto work is standalone and not integrated into the coordinated capture. The pieces build on each other:
  - Phase 1 CW tone precheck: `runPlutoTonePrecheck`, `helperPlutoTone*`. The contract is in `plutoTonePrecheckDesignSpec.md`.
  - Phase 2B multitone comb: `helperPlutoMultitoneBuildWaveform`, `helperPlutoMultitoneScoreCapture`, `runPlutoMultitone*`, `reviewPlutoMultitone*`. The plan is in `PlutoWaveformPlan.md`.
  - Azimuth environmental scan (current branch): `runPlutoAzimuthEnvironmentalScan.m`. Launch it with `run_pluto_azimuth_environment_scan.sh` (`-n/-c/-p/-i/-a auto`). The launcher uses `matlab -nodisplay -r`, not `-batch`, so operator `input()` prompts work. Existing scans are rescored with `reprocessPlutoAzimuth*.m`. See `Azimuth-Calibration.md`.
- Before trusting any Pluto calibration metric, verify the comb is actually present against a Pluto-off baseline with `plutoBurstPresence` / `plutoCombFineCheck` (and `plutoLoopbackCheck` for the Pluto alone). The summed "integrated margin" in `helperPlutoMultitoneScoreCapture.m` reads 10·log10(N) dB on pure noise. See `reporting/diagnostics/PlutoCombPresence_Diagnostic_V1.html`.
- Pluto runs write self-contained result folders (`result.mat`/`.json`, `summary.txt`/`.png`, CSVs, `index.html`) so results can be reviewed or reprocessed offline without hardware. Raw `.bb` captures go under `bb_captures_exclude_from_rsync/`.
- `TestSetupTesting` code reads `.bb` files through `BistaticDataAnalysis/loadIQData.m` (added to the path). A legacy copy of `loadIQData.m` also sits at the repo root.
- Older characterization scripts (`compute_radar_caf*.m`, `calc_*.m`, `script_QualityEtc.m`, `IQDataProcessing.m`) predate the session pipeline and are secondary.

### `ADSB_GPS/`: Raspberry Pi truth loggers

`start_adsb_gps_loggers.sh` manages gpsd/dump1090/loggers. `gatherTCPcompress.py` reads dump1090 SBS-1 on TCP 30003 and supports `--run-seconds` and `--session-id` for bounded coordinated runs.

### `reporting/`: published report site

`reporting/` on `main` is published to GitHub Pages (https://pwilliammat.github.io/flightTest/). Follow `reporting/howToUpdateReports.md`: `reporting/reports/` holds exactly the accepted nine-report family; diagnostic HTML reports go in `reporting/diagnostics/` and are linked from `reporting/index.html`. Pushing `main` republishes the site.

## Reference docs worth reading first

- `README.md`: full capture → sync → analyze command reference and options.
- `TestSetupTesting/README.md`: Pluto calibration sequence and entrypoint map.
- `NEXT_SESSION_HANDOFF.md`: current open problems and planned next steps.
- `concepts.md`: concept → file index.
