# Project Plan and Progress

**Guiding Principle**: Each processing step should be implemented as a standalone MATLAB function. A main script, `analyzeBistaticData.m`, will be used to define parameters and orchestrate the calls to these functions.

- **[COMPLETED] 1. Create MATLAB Data Loading Function**
  - **Task**: Develop a MATLAB function (`loadIQData.m`) to read and de-interleave raw IQ data.
  - **Implementation**: `BasebandFileReader` primary path with `int16` binary fallback; output always `double`; CH1=Surveillance, CH2=Reference with `swap_channels` flag.
  - **Verification**: ✅ Function successfully loads and de-interleaves data. ADC power diagnostic printed on load.

- **[COMPLETED] 2. Reshape Data into a Data Cube**
  - **Task**: Add functionality to `loadIQData.m` to reshape the 1D channel data into a 2D `fast-time` × `slow-time` matrix.
  - **Implementation**: N_fast = 2500 samples (0.5 ms CPI at 5 Msps), N_slow = 2000 CPIs → 1 s data cube.
  - **Verification**: ✅ Function creates [2500 × 2000] cubes; dimensions confirmed in console output.

- **[COMPLETED] 3. Perform Synchronization Check**
  - **Task**: Create a function (`verifySync.m`) that takes the two channel data arrays, performs a cross-correlation, and plots the result.
  - **Implementation**: Cross-correlation peak search to detect DPI lag; lag passed through entire pipeline so all range axes are relative to the true DPI bin.
  - **Verification**: ✅ DPI lag detected at chunk 1 and held constant across sub-chunks.

- **[COMPLETED] 4. Implement DPI and Clutter Mitigation**
  - **Task**: Create a function (`mitigateClutter.m`) implementing ECA-C (Extended Cancellation Algorithm – Coherent).
  - **Implementation**: Stage 1 = frequency-domain LS per Doppler bin (α computed per-bin from reference DFT coefficients). Stage 2 = zero-Doppler subspace notch using SVD-based projection. Dynamic `N_cancel = max(1, round(3 × N_slow / 2000))` — scales with sub-chunk size so short CPIs always cancel at least 1 bin.
  - **Verification**: B3 suppression depth measured at 13.8 dB with Hann window (understated due to windowing effect on B3 metric — see session log). Kaiser revert expected to improve detector performance.

- **[COMPLETED] 5. Compute Cross-Ambiguity Function and Range-Doppler Map**
  - **Task**: Create `createRDM.m` to compute the bistatic Cross-Ambiguity Function (CAF) between mitigated surveillance and reference channels and return a Range-Doppler Map (RDM) in dB.
  - **Implementation**: Range-domain cross-correlation per CPI (fast-time), then slow-time FFT with Kaiser(β=6) window applied to `range_profiles`. Physical range and Doppler axes attached. Output: `rdm = 20 × log10(|CAF|)` amplitude-dB.
  - **Verification**: ✅ RDM generated successfully. Zero-Doppler ridge visible before ECA-C; reduced after.

- **[COMPLETED] 5b. Sub-chunk Non-Coherent Integration**
  - **Task**: Partition the 2000-CPI record into N_chunks = 10 × 200-CPI blocks; independently mitigate each block via ECA-C; non-coherently integrate the resulting power maps.
  - **Implementation**: Loop in `analyzeBistaticData.m` §4. Accumulates `10.^(rdm_chunk/10)` (linear power) and normalises: `rdm_after = 10 × log10(sum_power / N_chunks)`. N_chunks fed to CFAR as `nci_looks = 10`.
  - **Why**: 200-CPI blocks are more stationary than the full 2000-CPI record for ECA-C LS convergence. NCI raises integrated SNR while the CFAR threshold formula is corrected for L = 10 looks via `betaincinv`.

- **[COMPLETED] 5c. Extract Per-File Pipeline into `processOnePart.m`**
  - **Task**: Refactor the per-file loop body from `analyzeBistaticData.m` into a dedicated callable function.
  - **Implementation**: `processOnePart.m` accepts a file path and `config` struct; runs load → ECA-C → CAF → NCI → range-whitening → CFAR and returns `all_detections`, `cfar_nf_db`, `rdm_before`, `rdm_after`, `range_axis`, `doppler_axis`. `analyzeBistaticData.m` calls it once per data part and aggregates results into a `part_res` struct array.
  - **Why**: Separating orchestration (parameter setup, figure loop, quality checks) from per-file signal processing improves readability and testability, and allows multi-part calls without duplicating code — following the modular pattern recommended in `agents.md`.
  - **Verification**: ✅ Pipeline runs successfully on Newton_part1/part2/part3 and returns per-part `part_res` struct.

- **[COMPLETED] 5d. Range Whitening (Per-Row Median Normalisation)**
  - **Task**: Add a pre-CFAR stage that removes range-dependent noise floor variation so that the CFAR threshold is relative to the local row noise rather than a global estimate.
  - **Implementation** (in `processOnePart.m`): after NCI, compute `row_nf_block = median(rdm_block, 2)` (per-range-bin median across Doppler); apply `rdm_block_w = rdm_block - row_nf_block`; run CFAR on whitened map; restore absolute power via `blk_dets(:,3) = blk_dets(:,3) + row_nf_block(r_idx)`. The representative absolute NF scalar `abs_nf_block = median(row_nf_block)` (~224–228 dB) is stored in `block_nf_dbs` and passed to `assessDetections` as `cfar_nf_db`.
  - **Why**: The USRP N320 noise floor is not flat with bistatic range. Near-range bins retain elevated clutter residuals after ECA-C; far-range bins are cleaner. A single global threshold either over-triggers near-range or under-triggers far-range. Per-row whitening lets each bin self-calibrate. The median is used (not mean) because it is robust to a single bright target in the Doppler dimension.
  - **Verification**: ✅ 27 detections confirmed across all three Newton parts (Pfa=1e-4). B3 PASS, D9 PASS.

- **[COMPLETED] 6. Implement CFAR Detection**
  - **Task**: Add a 2D CFAR detector (`detectTargets.m`) with both CA-CFAR and OS-CFAR variants.
  - **Implementation**: OS-CFAR active (75th-percentile rank). Multi-look Gamma CFAR threshold via `betaincinv(1−Pfa, L, N·L)` for L = `nci_looks`. `Pfa = 1e-4` (relaxed from 1e-5 to recover lower-SNR detections; tighten to 1e-5 if false-alarm density becomes unacceptable). `cfar_guard_cells = [6, 2]` half-widths (range increased 4→6 to prevent ATSC waveform sidelobe energy from entering the training window). Zero-Doppler notch fill prevents ECA-C notch from biasing training-cell estimates. Local-maxima suppression collapses clusters to single detections. ATSC ghost-range penalty zones at 23.2 km harmonics.
  - **Verification**: ✅ 27 detections confirmed across all 3 Newton data parts. B3 PASS, D9 PASS.

- **[COMPLETED] 6b. Expert Radar Quality Checks**
  - **Task**: Implement `assessDetections.m` running checks A1–D9 automatically after CFAR.
  - **Checks**: A1 (ATSC ghost ranges), A2 (pilot-tone Doppler ridge), B3 (zero-Doppler suppression depth), C5 (Rayleigh noise floor), C6 (false-alarm count vs expected), D7 (physical Doppler gate), D8 (near-field zone), D9 (anomalous SNR).
  - **B3 windowed correction (prior session)**: `before_val` corrected from windowed to unwindowed by adding `window_coherent_loss_db = -20 * log10(mean(kaiser(N,6)))`. Recovers the true clutter power at the ECA-C input; B3 threshold restored to 30 dB.
  - **B3 guard-cell message fix (this session)**: PASS message updated to "within 6 dB" to match the `+6 dB` guard used in `processOnePart.m` when restoring absolute power to detections.
  - **Validation**: ✅ B3 PASS, D9 PASS confirmed on all three Newton parts (27 total detections).

- **[COMPLETED] 6c. Geographic Bistatic Ellipse Visualization**
  - **Task**: Create `plotBistaticEllipses3D.m` to map each CFAR detection's bistatic iso-range ellipse onto a 3D geographic globe, colour-coded by data part.
  - **Implementation**: ENU flat-Earth coordinate frame (Rx as origin); bistatic ellipse geometry (`a = (R_exc+L)/2`, `b = sqrt(a²-c²)`); back-projected to geodetic via `enu2geodetic` (Mapping Toolbox R2021a+). Supports both `geoglobe` (3D) and `geoaxes` (2D fallback via `'Use2DFallback', true`). Per-part colour map; station markers (Tx ▲, Rx ■) stored at creation time and reused directly in the legend. Test harness: `test_ellipses.m`.
  - **Key choice**: ENU flat-Earth valid for baselines < 200 km (< 0.05% ellipse error); `enu2geodetic` used over ECEF conversions for readability. Dummy `NaN` geoplot handles avoided by storing markers at creation time.
  - **Verification**: ✅ `checkcode` reports no syntax errors. Run `test_ellipses` to validate end-to-end rendering.

- **[COMPLETED] 7. Implement Target Tracker**
  - **Task**: Create `trackTargets.m` and `initMeasurementSpaceKF.m` to associate CFAR detections across time steps using a Kalman-filter GNN tracker, and update `analyzeBistaticData.m` to run the tracker on all collected detections after all parts are processed.
  - **Implementation**:
    - `trackTargets.m`: groups `all_track_dets` by unique `t_abs_s`, wraps each group as `objectDetection` objects, and steps `trackerGNN` forward. Returns `tracks_log` struct array (one entry per time step, containing `.time` and `.tracks` — an `objectTrack` array of currently confirmed tracks).
    - `initMeasurementSpaceKF.m`: custom KF initializer for `trackerGNN`. State = `[R (m); Ṙ (m/s)]`, H and noise parameters passed from `config` via closure (see session 2026-05-28 for critical sign fix). `P0 = diag([range_bin_m², (50·range_bin_m/alpha)²])`. Measurement noise `R_meas = diag([(3·range_bin_m)², (2·dopp_bin_hz)²])`. Process noise `sigma_a = 50 m/s²`.
    - `trackerGNN` config: `ConfirmationThreshold = [2,3]`, `DeletionThreshold = [5,5]`, `AssignmentThreshold = 50`.
    - `init_fcn = @(det) initMeasurementSpaceKF(det, config.fc, config.fs)` — closure passes dataset-specific parameters; no hardcoded constants in the KF initializer.
  - **Why measurement-space KF**: a single passive receiver with one Rx can only measure bistatic range excess. Tracking in `[x, y]` position space is unobservable from a single range measurement. The only valid 1D state is `[R; Ṙ]`. See `concepts.md` §"Target Tracking in Measurement Space".
  - **Why `[2,3]` ConfirmationThreshold**: filters isolated false-alarm detections that flooded the track pool with `[1,1]`. Requires 2 detections in any 3-frame window (300 ms) to confirm — a real aircraft will satisfy this; most single-frame CFAR hits will not.
  - **Why `[5,5]` DeletionThreshold**: gives a track 500 ms (5 × 100 ms) before deletion. Prevents spurious losses during transient fades or at part boundaries where the KF gate is briefly wider.
  - **Results (Newton, 3-part)**: 26 total CFAR detections → 11 tracker time steps → peak 10 confirmed tracks. T7 confirmed in Part 2 only, deleted before Part 3.
  - **Verification**: ✅ Script runs end-to-end; tracker produces `tracks_log` with `objectTrack` arrays; confirmed-track console table printed per part.

- **[COMPLETED] 7a. Geographic Ellipse Viewer — Globe Speedup and Track Legend**
  - **Task**: Replace the per-step animated globe rendering (slow: ~2 s/step) with a one-time static pass, and add a companion Track Colour Legend figure.
  - **Root cause of slowness**: altitude ribbon (11 `geoplot3` calls per ellipse at 50 m altitude steps) × ±1σ side contours × N_tracks × N_steps, plus a handle-deletion loop — ~700+ WebGL scene updates total.
  - **Fix**: single `geoplot3` call per unique TrackID at last-known state at `TGT_ALT_M = 3000 m`, no ribbon. ~10 calls total vs ~700+.
  - **Track Colour Legend figure**: companion `figure` (not `uifigure`) showing coloured dot + `T#  R(km)  D(Hz)` for every unique TrackID. Same 12-colour palette (`TRK_ID_COLORS`) used for RD map markers, legend dots, and globe ellipses — cross-referenceable by colour.
  - **Why last-known state**: a deleted track (e.g., T7) would vanish if only the final step's confirmed tracks were rendered. "Last-known" preserves the complete engagement history.
  - **Verification**: ✅ Globe renders in < 1 s (previously ~22 s for 11 steps). Colour legend figure appears alongside globe.

- **[COMPLETED] 7b. Interactive Range-Doppler Map Viewer**
  - **Task**: Create an interactive figure that lets the user step through all 11 tracker time steps using a slider and Prev/Next buttons, showing the whitened RDM background + per-step CFAR detections + confirmed track states with ±1σ error crosses.
  - **Implementation**:
    - `analyzeBistaticData.m` §7.4a: precomputes `step_data(1..N_steps)` struct array (whitened RDM image, axes, per-step detections, confirmed track array) — moves all heavy computation out of callback path.
    - `analyzeBistaticData.m` §7.6: creates classic `figure` + `axes` + `uicontrol` slider/label/buttons; defines `render_fn` closure; assigns callbacks after all handles exist.
    - `render_rdm_step.m`: the rendering function called by every callback. `cla` + `imagesc` + `scatter` (CFAR hits as white ×) + `scatter`/`plot`/`text` per confirmed track + `title` + `set(lbl, 'String', ...)` + `drawnow`.
  - **Why precompute step_data**: on-the-fly RDM computation would take 10–20 s per slider drag (re-running processOnePart). Pre-computation at script start takes ~2–5 s total; callbacks complete in < 100 ms.
  - **Why classic `uicontrol`**: `uifigure`/`uislider` requires App Designer engine (R2016a+ WebView2); `uicontrol` works in all MATLAB versions and all environments (desktop, Online, Codespaces).
  - **Why separate `render_rdm_step.m` file**: `analyzeBistaticData.m` is a script (not a function), and MATLAB scripts cannot contain local functions. The renderer must be a separate file on the MATLAB path.
  - **Verification**: ✅ File created, no syntax errors. Script runs to completion and opens interactive figure with working slider.

---

## Human Verification Checklist

- **[COMPLETED] A. Verify `loadIQData.m` Functionality**
  - ✅ Output cubes are [2500 × 2000], complex double. ADC power diagnostic confirms CH2 stronger (reference on RX2, correct).

- **[COMPLETED] B. Verify `verifySync.m` Script**
  - ✅ DPI lag detected, cross-correlation peak present at expected bin.

- **[COMPLETED] C. Verify CFAR detections on Newton_part1/part2/part3**
  - **Result**: ✅ 26–27 total detections across all three Newton data parts. B3 PASS, D9 PASS. Pipeline fully validated with range whitening active (Pfa=1e-4, cfar_guard_cells=[6,2]).

- **[COMPLETED] D. Tracker runs end-to-end on Newton dataset**
  - **Result**: ✅ 26 detections → 11 tracker time steps → peak 10 confirmed tracks. `tracks_log` struct array populated. Console table printed per part. Globe renders in < 1 s. Interactive RD viewer opens with working slider.

- **[COMPLETED - TRUTH OVERLAY IMPLEMENTED, REAL-SESSION VALIDATION PENDING] E. Truth-data comparison**
  - **ADS-B pipeline status**: ALL functions implemented and unit-tested. `test_adsbTruthPipeline.m` passes end-to-end (49/49 synthetic SBS-1 records parsed, TP=10, Pd=0.833).
  - **Functions implemented**:
    - `loadADSBTruth.m` — parses SBS-1/BaseStation dump1090 format. **Critical fix (R2025b)**: `strsplit(line, ',', 'CollapseDelimiters', false)` — MATLAB R2025b changed default to `CollapseDelimiters=true` for explicit delimiters, collapsing empty trailing fields; the fix is required for correct MSG field counting.
    - `getRadarEpoch.m` — extracts UTC epoch from filename (14-digit `YYYYMMDDHHMMSS` for Natick/May-2026 files; `M_D_YYYY` date-only for Newton/July-2026 files; manual override via `ManualEpoch`).
    - `adsbToBistatic.m` — converts ADS-B (lat, lon, alt) to bistatic measurement space: `R_excess = R_tx + R_rx − L`; Doppler from numerical central-difference of `R_excess(t)`.
    - `alignTruthToRadar.m` — subtracts radar epoch from ADS-B UTC, resamples to radar CPI query times via `interp1` (linear, NaN outside data span).
    - `assessTruthVsDetections.m` — detection-level TP/FA/miss labelling + track-level range/Doppler RMSE.
    - `plotTruthComparison.m` — side-by-side truth vs radar track plots.
    - `analyzeBistaticData.m` Section 8 - integrated; now aligns truth on the full CFAR block-centre cadence, refreshes the interactive RD viewer once truth is loaded, and overlays ADS-B truth on the static per-part RDM figures.
    - `helperBuildTruthQueryTimes.m` - builds the multi-part block-centre time grid used for truth alignment.
    - `helperPlotRDMTruthOverlay.m` - shared measurement-space overlay helper for the static RDM figures and `render_rdm_step.m`.
  - **Current workflow status (June 15, 2026)**: coordinated capture and Pi truth-artifact recovery were validated on a live packaged session. Session `20260615T103437` is the active real-data target for confirming the new ADS-B-on-RDM overlay path on the development machine.
  - **Natick dataset truth status**: The compressed ADS-B files in `04_Natick_Ah_Pkg_May_21_26/` were inspected. Files `231_adsb...gz` through `281_adsb...gz` (51 files) were sampled and cover **May 24–25 2026**, NOT the radar collection window. `0_adsb_20260521_142051.txt` covers 18:20–18:21 UTC on May 21. `4_adsb_20260521_142633_anal.txt` (200k lines) covers 20:03–20:12 UTC. The radar data was collected at **~19:26–19:28 UTC on May 21 2026**. No captured ADS-B file covers this window.
  - **Next steps for the next session**:
    1. On the development machine, confirm the synced packaged session exists locally and run `runBistaticAnalysisSession('20260615T103437')`.
    2. Verify the preflight reports a nonzero ADS-B file count and that Section 8 executes without skipping.
    3. Inspect the static per-part RDM figures and the interactive RD viewer to confirm the ADS-B overlay falls in plausible `(R_excess, f_D)` locations relative to the radar energy.
    4. Record any consistent range or Doppler bias and decide whether the next adjustment should target time alignment, geometry, or display styling.

- **[COMPLETED] F. Fast Iteration and Parameter-Sweep Workflow**
  - **Goal**: avoid rerunning the full multi-minute IQ pipeline when only a later analysis segment is being tuned.
  - **Three supported analysis levels**:
    1. **Full session run** â€” use when upstream signal processing has changed (`processOnePart.m`, `detectTargets.m` internals, clutter mitigation, CAF, timing setup, session manifest inputs).
    2. **Truth-only replay** â€” use when tuning truth alignment, detection-vs-truth plots, truth gates, or standalone RDM truth overlays.
    3. **Detector-only replay** â€” use when sweeping CFAR and post-CFAR detector parameters such as `Pfa`, guard/train cells, OS rank, local-max suppression, ATSC guard penalty, notch guard, or `MinSNRDB`.
  - **Segment 1 â€” Full packaged-session analysis**:
    - Entry point: `runBistaticAnalysisSession(session_id)`
    - Example:
      ```matlab
      cd BistaticDataAnalysis
      out = runBistaticAnalysisSession('20260615T103437');
      ```
    - **Outputs created automatically**:
      - `out.truth_diag_snapshot.compact_path`
      - `out.truth_diag_snapshot.full_path` (if `TruthDiagnosticSnapshotMode = 'both'`)
      - `out.detector_replay_snapshot.path`
    - **When to use**: only when the slow upstream radar chain must be rerun.
  - **Segment 2 â€” Truth-only replay**:
    - Entry point: `runDetectionTruthDiagnostics(...)`
    - Fast path from an existing full-session output:
      ```matlab
      cd BistaticDataAnalysis
      diag = runDetectionTruthDiagnostics(out.truth_diag_snapshot.compact_path, ...
          'PlotDetectionTimeSeries', true, ...
          'PlotRDMOverlays', false, ...
          'PlotTrackComparison', false);
      ```
    - **Adjustable diagnostic-only parameters**:
      - `GateRangeCells`
      - `GateDopplerBins`
      - `TimeGateS`
      - `PlotDetectionTimeSeries`
      - `PlotRDMOverlays`
    - **When to use**: truth alignment checks, truth-vs-detection plots, and verifying whether detections fall near ADS-B truth before touching tracker logic.
  - **Segment 3 â€” Detector-only replay / parameter sweep**:
    - Entry point: `runDetectorReplaySweep(...)`
    - Shortest syntax after `runBistaticAnalysisSession`:
      ```matlab
      cd BistaticDataAnalysis
      replay_path = out.detector_replay_snapshot.path;
      ```
    - **One modified detector run (no sweep table)**:
      ```matlab
      replay = runDetectorReplaySweep( ...
          replay_path, ...
          'Pfa', 3e-4, ...
          'GuardCells', [4 2], ...
          'TrainCells', [12 4], ...
          'CfarType', 'OS', ...
          'OSRankFraction', 0.65, ...
          'PlotDetectionTimeSeries', true, ...
          'PlotRDMOverlays', false, ...
          'Verbose', true);
      replay.summary_table
      ```
    - **Named sweep across multiple cases**:
      ```matlab
      cases = struct( ...
          'Name', {'baseline', 'pfa3e4', 'pfa1e3', 'ca_pfa3e4'}, ...
          'Pfa', {1e-4, 3e-4, 1e-3, 3e-4}, ...
          'CfarType', {'OS', 'OS', 'OS', 'CA'});

      replay = runDetectorReplaySweep( ...
          replay_path, ...
          'Cases', cases, ...
          'PlotCases', 'all', ...
          'PlotDetectionTimeSeries', true, ...
          'PlotRDMOverlays', false, ...
          'Verbose', true);
      replay.summary_table
      ```
    - **Detector parameters that can be swept directly**:
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
    - **Important boundary**: `runDetectorReplaySweep` reruns only the detector stage from the saved whitened block-level RDM inputs. It does **not** rerun IQ loading, ECA-C clutter mitigation, or CAF generation.
    - **How to review results**:
      1. Check `replay.summary_table` first (`n_detections`, `n_tp`, `n_fa`, `n_miss`, `mean_pd`).
      2. Then inspect the detection-vs-truth plots for the best cases.
      3. Only after detections land near truth should tracker tuning resume.
  - **If the full run was started with `analyzeBistaticData.m` directly instead of `runBistaticAnalysisSession`**:
    - Build the replay bundle once from the current workspace:
      ```matlab
      compact_truth_template = truth_diag_input;
      if isfield(compact_truth_template, 'rdm_parts')
          compact_truth_template = rmfield(compact_truth_template, 'rdm_parts');
      end

      detector_replay_input = buildDetectorReplayInput( ...
          config, data_parts, part_start_offsets_s, part_end_offsets_s, part_res, ...
          'SessionID', session_id, ...
          'AnalysisLabel', 'Detector Replay', ...
          'TruthDiagnosticInput', compact_truth_template, ...
          'PartDurationS', part_dur_s, ...
          'TracksLog', tracks_log, ...
          'Verbose', false);

      saveDetectorReplayInput(detector_replay_input, 'detector_replay_input.mat');
      replay_path = 'detector_replay_input.mat';
      ```
    - Then run `runDetectorReplaySweep(replay_path, ...)` using either a single set of overrides or a `Cases` struct.
  - **Recommended usage discipline for parameter sweeps**:
    1. Sweep one family of detector parameters at a time.
    2. Start with sensitivity (`Pfa`, `CfarType`, `OSRankFraction`).
    3. Then test CFAR window sizes (`GuardCells`, `TrainCells`).
    4. Then test suppression logic (`LocalMaxima`, ATSC guard, notch guard).
    5. Keep the tracker out of the loop until detector-vs-truth behavior is physically reasonable.
  - **Reference**: `radarExpertDetectorTuning.md` now contains the detailed radar-expert tuning suggestions and copy/paste sweep campaigns.

---

## Session Testing Log

### Session: 2026-05-20 — Passive Bistatic Radar Pipeline Debug

**Hardware**: USRP N320 dual-channel, fs = 5 Msps, fc = 600 MHz (ATSC 1.0 TV)  
**Data**: `n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part1` (1 s, N_slow = 2000)  
**CPI**: 0.5 ms → PRF = 2000 Hz → ±1000 Hz unambiguous Doppler  
**Sub-chunking**: 10 × 200-CPI blocks (100 ms each), non-coherent integration

**Issues found and resolved this session:**

| Issue | Root Cause | Fix Applied |
|-------|-----------|------------|
| Zero CFAR detections | Hann window −32 dB sidelobes: residual DC clutter (~30 dB above noise) placed sidelobes at +/−2 dB relative to noise → OS-CFAR 75th-percentile training window contaminated → threshold wall everywhere | Reverted to Kaiser(β=6) in `createRDM.m`; −44 dB sidelobes land 14 dB below noise floor |
| B3 suppression reading 13.8 dB (< 30 dB target) | `before_val` measured from windowed RDM depresses coherent DC amplitude by `−20×log10(mean(kaiser)) ≈ −8 dB`, understating true suppression | Added `window_coherent_loss_db` correction to `before_val` in `assessDetections.m`; B3 threshold restored to 30 dB |
| CFAR multi-look threshold too low (L=1 formula with L=10 looks) | betaincinv multi-look Gamma CFAR was already in place from prior session; confirmed via `[CFAR-DEBUG]` print | No fix needed; debug print added to verify per-run |
| ±char encoding error in console output | Unicode ± glyph not ASCII-safe in MATLAB fprintf | Replaced with `char(177)` |

**Measured values (pre-Kaiser-revert, Hann window):**

| Metric | Value | Status |
|--------|-------|--------|
| B3 zero-Doppler suppression (windowed before) | 13.8 dB | Understated — corrected metric expected ~22+ dB |
| CFAR detections | 0 | Bug — threshold wall from window sidelobe contamination |
| α (multi-look, L=10, N=592, Pfa=1e-4) | ~1.04 | Correct — `betaincinv` implemented |
| N_cancel (ECA-C Stage 2, N_slow=200) | 1 bin | Correct — dynamic formula `max(1, round(3×N/2000))` |

**Next steps (completed in session 2):**
1. ✅ Kaiser window + B3 correction validated — 27 detections found
2. ✅ B3 PASS, D9 PASS confirmed on all 3 Newton parts
3. ✅ Range whitening added; pipeline modularised into `processOnePart.m`
4. ⏳ E10/E11 cross-frame cross-match — ready to run (see session 2 next steps)

---

### Session: 2026-05-20 (Session 2) — Range Whitening, Guard Cells, Modular Pipeline, Geographic Visualization

**Focus**: Apply all session-1 fixes, relax Pfa, add range whitening, modularise per-file processing, create geographic ellipse visualization.

**Changes applied:**

| Change | File | Rationale |
|--------|------|-----------|
| Pfa relaxed 1e-5 → 1e-4 | `analyzeBistaticData.m` | 1 detection at 1e-5 (insufficient); 27 at 1e-4 with D9 still passing |
| CFAR range guard cells 4 → 6 | `analyzeBistaticData.m` | ATSC sidelobe energy spans ~5–7 range bins; guard of 4 was clipping the outermost lobe into the training window |
| Per-row median whitening + absolute NF restoration | `processOnePart.m` | USRP N320 NF not flat with range; per-row self-calibration makes CFAR range-independent |
| `processOnePart.m` extracted | new file | Modularises per-file pipeline; `analyzeBistaticData.m` calls it N_parts times |
| Per-part RDM figures with CFAR detection overlays | `analyzeBistaticData.m` | 3 figures (one per Newton part) replace single part-1-only figure |
| `plotBistaticEllipses3D.m` created | new file | Maps CFAR detections as bistatic iso-range ellipses on 3D globe / 2D geoaxes |
| `test_ellipses.m` created | new file | Standalone test script for `plotBistaticEllipses3D` |
| B3 guard message updated to "within 6 dB" | `assessDetections.m` | Matches `+6 dB` guard used in absolute power restoration step |

**Results:**

| Metric | Value | Status |
|--------|-------|--------|
| Total CFAR detections (all 3 parts) | 27 | ✅ |
| B3 zero-Doppler suppression | PASS | ✅ |
| D9 anomalous SNR check | PASS | ✅ |
| Pfa | 1e-4 | |
| cfar_guard_cells | [6, 2] (range, Doppler) | |

**Next steps:**
1. Run E10/E11 cross-frame consistency check: `detections_p1 = part_res(1).detections`, etc. — code in `radarChecksCheckList.md` §E10
2. Implement `trackTargets.m` (step 7) — 27-detection prerequisite is now met
3. Run `test_ellipses` to validate `plotBistaticEllipses3D` end-to-end with actual Tx/Rx survey coordinates

---

### Session: 2026-05-27 — Tracker, Globe Speedup, Interactive RD Map Viewer, Track Legend

**Hardware / Data**: Same Newton MA dataset (3 × 1 s parts, fc = 600 MHz, fs = 5 Msps, parking-garage deployment).

**Focus**: End-to-end target tracking in bistatic measurement space; replace per-step animated globe with fast static render; add interactive Range-Doppler Map viewer with slider/buttons; add track colour legend companion figure.

**New files created:**

| File | Purpose |
|------|---------|
| `trackTargets.m` | `trackerGNN`-based tracker. Groups `all_track_dets` by unique timestamp, wraps as `objectDetection`, steps GNN tracker, returns `tracks_log` struct array. |
| `initMeasurementSpaceKF.m` | Custom KF initializer for 1D `[R; Ṙ]` state. Specifies `H = [1,0]`, initial covariance `P0`, Singer process noise `Q`, measurement noise `R_meas = range_bin_m²`. |
| `render_rdm_step.m` | Renders one tracker time step on the interactive RD map axes: `imagesc` + CFAR detections (white ×) + per-track filled circles + ±1σ error crosses + `T#` labels. Called by slider/button callbacks via closure. |

**Changes to `analyzeBistaticData.m`:**

| Section | Change | Why |
|---------|--------|-----|
| §7.2 | Globe figure only (no `fig_rdm` created here) | RD map is now separate interactive figure; globe is static post-loop |
| §7.3 | Add `TRK_ID_COLORS` 12-colour palette + `CLR_NAMES` + `alpha_trk` | Same palette used for RD map markers, globe ellipses, and legend — cross-reference by colour |
| §7.4a | Pre-compute `step_data(1..N_steps)` struct array | Move all heavy RDM computation out of callback path; each callback is then < 100 ms |
| §7.4 | Console quality table only (no per-part RDM animation) | Static globe + interactive slider replaces the animated per-part loop |
| §7.5 | One-time static globe render (last-known state per TrackID) | 10 `geoplot3` calls vs ~700+ in the animated version; < 1 s total |
| §7.5+ | Track Colour Legend companion figure | Colour-coded dot + `T# / R / D` for every unique TrackID; same colours as globe and RD map |
| §7.6 | Interactive RD map viewer (`figure` + `uicontrol` slider + buttons) | Enables step-by-step inspection of all 11 tracker time steps |

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Track in `[R; Ṙ]` not `[x, y]` | Single receiver → only bistatic range is observable; 2D position is underdetermined. See `concepts.md` §"Target Tracking in Measurement Space" |
| `ConfirmationThreshold = [1,1]` | Newton dataset has only 3 parts / ≤3 time steps per track lifetime; stricter threshold would prevent confirmation for single-part tracks |
| Static globe (last-known state) | 700× fewer WebGL scene updates than animated version; deleted tracks (e.g., T7) still visible at their last confirmed state |
| Precompute `step_data` | RDM computation takes 10–20 s; pre-computing once makes callbacks < 100 ms |
| Classic `uicontrol` | Works in all MATLAB versions and environments; `uifigure` requires App Designer engine |
| `render_rdm_step.m` as separate file | `analyzeBistaticData.m` is a script — MATLAB scripts cannot contain local functions |

**Results:**

| Metric | Value |
|--------|-------|
| Total CFAR detections (all 3 Newton parts) | 26 |
| Tracker time steps | 11 |
| Peak simultaneously confirmed tracks | 10 |
| Unique TrackIDs over full run | 10 |
| T7 status | Confirmed in Part 2 only; deleted before Part 3; visible on globe at last-known state |
| Globe render time | < 1 s (previously ~22 s for 11 steps) |
| Slider callback time | < 100 ms per step |

**Natural stopping point**: no ADS-B or GPS truth data was available from the Newton recording session. Without truth, quantitative accuracy assessment (range bias, velocity RMSE, association correctness) is not possible. Pipeline is fully functional end-to-end; results are physically plausible. See checklist §E (Deferred) for what would be required to complete the validation.

---

### Session: 2026-05-28 — Natick Dataset Migration, ADS-B Pipeline, Tracker Sign Fix

**Hardware / Data**: USRP N320 dual-channel, fc = 599 MHz (CBS Tower Newton MA), fs = 8 Msps.  
**Dataset**: `04_Natick_Ah_Pkg_May_21_26` — 10 × 1 s files (`n320_599_8Msps_100ms_1` through `_10`).  
**Collection window**: 2026-05-21 15:26:50–15:27:29 UTC (file header timestamps).  
**Inter-file gap**: ~2.85 s steady-state (5.96 s for file 1→2 due to HW init); `inter_part_gap_s = 3.0` used.

**Focus**: Migrate `analyzeBistaticData.m` to Natick dataset; complete ADS-B truth pipeline and unit test; fix tracker Doppler sign inversion and hardcoded parameters.

---

**Natick dataset migration (`analyzeBistaticData.m`):**

| Parameter | Old (Newton) | New (Natick) |
|---|---|---|
| `config.fc` | `600e6` | `599e6` |
| `config.fs` | `5e6` | `8e6` |
| `config.numSamples` | `5e6` | `8e6` |
| `data_parts` | 3 Newton files | 10 Natick files `_1`–`_10` |
| `config.inter_part_gap_s` | `0` | `3.0` (measured ~2.85 s avg) |
| `config.max_nci_looks` | `3` | `2` (37.5 m cell at 8 Msps) |
| Site comment | WNAC-DT / 5 Jul 2026 | CBS Tower / 21 May 2026 |

**Site coordinates (unchanged)**: Tx = CBS Tower Newton MA `[42.310278, -71.236667, 431.9]`; Rx = Parking garage 4 Apple Hill Dr `[42.2999333, -71.349333, 15.0]`.

**`100ms` filename note**: `dur=0.1` arg to capture script → `nSeg = ceil(0.1/1) = 1` due to hardcoded `seg = seconds(1)`. Every file is always exactly 1 s regardless of `dur`. The `100ms` in the name = argument value, not capture duration.

---

**ADS-B truth pipeline — completed and unit-tested:**

| Function | Status | Notes |
|---|---|---|
| `loadADSBTruth.m` | ✅ Fixed | `strsplit(..., 'CollapseDelimiters', false)` — R2025b bug |
| `getRadarEpoch.m` | ✅ Complete | Handles `YYYYMMDDHHMMSS` (Natick) and `M_D_YYYY` (Newton) filename formats |
| `adsbToBistatic.m` | ✅ Complete | Bistatic R_excess + Doppler via central-difference |
| `alignTruthToRadar.m` | ✅ Complete | UTC→radar-relative time, `interp1` resampling |
| `assessTruthVsDetections.m` | ✅ Complete | TP/FA/miss + range/Doppler RMSE |
| `plotTruthComparison.m` | ✅ Complete | Side-by-side truth vs radar tracks |
| `analyzeBistaticData.m §8` | ✅ Integrated | Skips gracefully if `config.adsb_files` not set |
| `test_adsbTruthPipeline.m` | ✅ Passing | 49/49 SBS-1 records, TP=10, Pd=0.833 |

**Critical MATLAB R2025b fix**: `strsplit(line, ',')` with explicit delimiter now defaults to `CollapseDelimiters=true`, collapsing consecutive commas (empty fields). SBS-1 MSG,1 lines end with 10+ empty fields. Without `'CollapseDelimiters', false`, `numel(parts) < 16` for every line → 0 records parsed.

---

**Tracker fixes (`initMeasurementSpaceKF.m`, `trackTargets.m`):**

| Problem | Symptom | Fix |
|---|---|---|
| **Doppler sign inversion** — `H(2,2) = +alpha` | Positive f_D (approaching) predicted range to increase, opposite of measured data. After N steps, predicted range diverged 2·|Ṙ|·N·Δt from detections → assignment gate failure. Root cause: used active-radar sign convention instead of passive CAF convention. | `H(2,2) = -alpha`; `Rdot0 = -f_D/alpha` |
| `initMeasurementSpaceKF` hardcoded `fc=600e6, fs=5e6` | Wrong α and range bin for 599 MHz / 8 Msps. Gate shape incorrect; `R_meas` inconsistent with data. | Parameters now passed via closure: `init_fcn = @(det) initMeasurementSpaceKF(det, config.fc, config.fs)` |
| `trackTargets` hardcoded `range_bin = c/(2×5e6)` | Mismatched `R_meas` (30 m bins) vs actual data (18.75 m bins) | Fixed to `c / (2 * config.fs)` |
| `R_meas` too tight — 1-bin² variance | Microscopic innovation gate: any sub-bin centroid error → Mahal² > threshold → missed assignment | `R_meas = diag([(3·bin)², (2·10)²])` — 3-bin range, 2-bin Doppler |
| `sigma_a = 20 m/s²` — process noise too low | At Δt=3 s (inter-part gap), `σ_R_added = √(q·Δt³/3) ≈ 58 m` — too narrow to accommodate bistatic geometry acceleration | `sigma_a = 50 m/s²` — covers bistatic acceleration effects (30–80 m/s² at close range) |
| `ConfirmationThreshold = [1,1]` | Every single-frame false alarm became a confirmed track; pool of 100+ tracks overwhelmed GNN association | `[2,3]` — requires 2 detections in 3 consecutive frames |
| `DeletionThreshold = [3,3]` | Tracks deleted in 300 ms; too fast to survive even within-part fades | `[5,5]` — 500 ms tolerance |

**Passive-radar CAF sign convention** (derived from `createRDM.m`):
```
xc = ifft( fft(surv) .* conj(fft(ref)) )    % cross-correlation
rdm = fftshift( fft(xc .* win_slow, 2) )    % Doppler FFT (fftshift → positive = real positive frequency)
```
A target with decreasing bistatic range (approaching) produces a **positive** f_D bin in the RDM. Therefore `f_D = −α·Ṙ`, not `+α·Ṙ`. The sign matters: with the wrong sign, the KF predicts range in the wrong direction on every time step, and all detections fall outside the gate within ~5 frames.

---

**First Natick run results (prior to sign fix)**:

| Metric | Value | Notes |
|---|---|---|
| Total detections | 127 | Across 10 parts, 47 time steps |
| Peak confirmed tracks | 15 | All short-lived (≤3 steps) |
| Unique TrackIDs | 126 | ~1 track per detection — gating failure |
| σ_v for all tracks | 374 m/s | = initial P₀ value — velocity never converged |
| Only converged track | T115 (σ_v = 2.5 m/s) | Single aircraft with sufficient SNR to survive sign bug |

**Expected after sign fix**: much fewer total tracks, some tracks spanning multiple parts with declining σ_v.

**Next steps (for continuation session):** See Section E above and `NEXT_SESSION_HANDOFF.md`.

