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

- **[PENDING] 7. Implement Target Tracker**
  - **Task**: Create a function (`trackTargets.m`) to associate CFAR detections across frames using a Kalman filter or GNN tracker.
  - **Prerequisite**: ✅ 27 detections confirmed across Newton_part1/part2/part3. Manual E10/E11 cross-frame consistency cross-match still required (see `radarChecksCheckList.md` §E).
  - **Next action**: Run E10 cross-match using `part_res(i).detections` from `analyzeBistaticData.m` to identify persistent detections across parts before initialising tracker.

---

## Human Verification Checklist

- **[COMPLETED] A. Verify `loadIQData.m` Functionality**
  - ✅ Output cubes are [2500 × 2000], complex double. ADC power diagnostic confirms CH2 stronger (reference on RX2, correct).

- **[COMPLETED] B. Verify `verifySync.m` Script**
  - ✅ DPI lag detected, cross-correlation peak present at expected bin.

- **[COMPLETED] C. Verify CFAR detections on Newton_part1/part2/part3**
  - **Result**: ✅ 27 total detections across all three Newton data parts. B3 PASS, D9 PASS. Pipeline fully validated with range whitening active (Pfa=1e-4, cfar_guard_cells=[6,2]).

- **[PENDING] D. Cross-frame consistency check (E10/E11)**
  - **Status**: All three Newton parts have been processed (27 total detections in `part_res`). The manual E10 cross-match has not yet been run.
  - **Action**: Use the cross-match code block in `radarChecksCheckList.md` §E10 with `detections_p1 = part_res(1).detections`, etc.
  - **Check**: ≥ 1 persistent detection across all 3 parts with monotonic Doppler trend.

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
