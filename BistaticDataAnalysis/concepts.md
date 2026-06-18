# Key Radar Signal Processing Concepts

This document captures both **what** each algorithm does and **why** each design choice was made. The goal is to record the reasoning behind implementation decisions so future readers understand the tradeoffs, not just the mechanics.

---

## Core Signal Processing

| Concept | Description | Implemented In |
| :--- | :--- | :--- |
| **Data Cube** | A 2D matrix structuring raw 1D signal data into `fast-time` (range) and `slow-time` (Doppler) dimensions for radar processing. | `loadIQData.m` |
| **Coherent Processing Interval (CPI) in Passive Radar** | In passive radar, there are no transmitted pulses. The CPI is an **artificial construct** created by segmenting the continuous incoming data stream into fixed-length chunks. Each chunk is treated as a "virtual pulse," allowing for Doppler processing. The length of this artificial CPI is a critical tuning parameter: a longer CPI improves Doppler resolution but can cause smearing for fast targets, while a shorter CPI has worse Doppler resolution but provides a clearer snapshot. | `analyzeBistaticData.m` (see `config.cpi_duration_s`) |
| **Cross-Ambiguity Function (CAF)** | The 2D generalization of cross-correlation. The CAF between the surveillance channel s(t) and reference channel r(t) is computed as a range (fast-time) cross-correlation stack for each CPI, then a Doppler (slow-time) FFT across CPIs. The output is the Range-Doppler Map (RDM): each cell (r, d) represents the energy scattered by a target with bistatic range-excess r and Doppler shift d. Output stored as amplitude-dB: `rdm = 20×log10(|CAF| + eps)`. | `createRDM.m` |
| **Range Whitening (Per-Row Median Normalisation)** | Pre-CFAR stage that subtracts each range bin’s own median power across Doppler (in dB), making the CFAR threshold range-independent. Absolute detection power is restored post-CFAR by adding the stored per-row noise floor back to each detection’s power column. Median is used over mean for robustness to the presence of a bright target in the Doppler dimension. | `processOnePart.m` |
| **Bistatic Iso-Range Ellipse** | The locus of all target positions with a given bistatic range-excess `R_exc` is an ellipse with Tx and Rx at the foci: `a = (R_exc+L)/2`, `b = sqrt(a²-c²)`, `c = L/2`. Computed in local ENU frame (Rx as origin) and back-projected to geodetic via `enu2geodetic`. CFAR detections are rendered as ellipses colour-coded by Doppler frequency (cold = approaching, warm = receding) so the globe gives an instantaneous speed map of every hit. | `plotBistaticEllipses3D.m` |
| **Tracking in Measurement Space** | Because a passive radar with a single receiver can only measure bistatic range excess (one scalar per detection), it is mathematically impossible to estimate a 2D/3D target position from a single snapshot. The only valid state to track is the 1D measurement itself: `[R_excess; Ṙ]`. A 1D Kalman filter with `MotionModel = '1D Constant Velocity'` propagates this directly. The tracker produces a time series of `[R, Ṙ]` estimates; the geographic position is constrained only to the corresponding bistatic ellipse, not a point. | `trackTargets.m`, `initMeasurementSpaceKF.m` |
| **Doppler–Velocity Coupling (α) and Sign Convention** | For the measurement state `R_excess = R_tx + R_rx - L`, the passive CAF convention is `f_D = -(fc/c) * Rdot = -alpha * Rdot`, where `Rdot = dR_excess/dt`. The **negative sign** is mandated by the passive-radar CAF implementation in `createRDM.m`: `xc = ifft(fft(surv) .* conj(fft(ref)))` followed by `fftshift(fft(xc .* win_slow, 2))`. Under this convention, an **approaching** target (`Rdot < 0`) produces a **positive** `f_D` bin. The KF measurement matrix must use **H(2,2) = -alpha**, and the initial velocity seed must be **Rdot0 = -f_D/alpha**. Coupling factor value: `alpha = fc/c ~= 2.00 Hz/(m/s)` at `fc = 599 MHz`. Shared helpers now centralize this conversion so truth projection, tracking, diagnostics, and displays all use the same sign and scale. | `helperBistaticDopplerCoupling.m`, `helperBistaticDopplerFromRangeRate.m`, `helperBistaticRangeRateFromDoppler.m`, `initMeasurementSpaceKF.m`, `createRDM.m` |
| **Interactive RD Map Viewer** | After tracking, each tracker time step can be inspected interactively: the step_data struct is precomputed once (holds the whitened RDM image, axis vectors, per-step CFAR detections, and confirmed track array), then a slider/button UI renders any step on demand. Precomputation moves the expensive work (RDM computation) out of the callback path so each step transition takes <100 ms instead of 10–20 s. | `analyzeBistaticData.m` §7.4a, §7.6; `render_rdm_step.m` |
| **ADS-B Truth Ingestion** | SBS-1/BaseStation format messages from dump1090 are parsed into per-aircraft structs. MSG type 1 gives callsign; type 3 gives position (lat/lon/alt); type 4 gives velocity (ground speed, track, vertical rate). Records are grouped by ICAO hex address and velocity fields are merged onto the position time grid via `interp1`. Unit conversions: ft→m, kts→m/s, ft/min→m/s. Files may be raw `.txt` or `.gz` compressed. | `loadADSBTruth.m` |
| **Bistatic Truth Projection** | An ADS-B position fix (lat, lon, alt) is converted to bistatic measurement space by computing the full 3D slant ranges `R_rx = ||ENU_ac - ENU_rx||`, `R_tx = ||ENU_ac - ENU_tx||`, then `R_excess = R_tx + R_rx - L_3D` where `L_3D` is the full Tx-Rx separation including altitude difference. Bistatic Doppler is derived by numerical differentiation of the `R_excess` time series with the shared passive-radar coupling `f_D = -(fc/c) * dR_excess/dt`. This keeps ADS-B truth numerically aligned with the detector and tracker without relying on closed-form bistatic-angle approximations. | `adsbToBistatic.m`, `helperDeriveTxRxGeometry.m` |
| **Truth-Radar Alignment** | The radar pipeline operates in recording-relative time `t_abs_s` (seconds since start of Part 1). ADS-B uses UTC Unix timestamps. `getRadarEpoch` extracts the recording start epoch from the filename (14-digit `YYYYMMDDHHMMSS` for May-2026 data; `M_D_YYYY` date-only with midnight-UTC fallback for Newton July-2026 data; or a manual `ManualEpoch` override). `alignTruthToRadar` subtracts the epoch and resamples ADS-B R_excess and f_D onto the radar's CPI query grid via `interp1` (linear, NaN outside data span). | `getRadarEpoch.m`, `alignTruthToRadar.m` |
| **Range-Doppler Truth Overlay** | The cleanest validation view is to compare radar and truth in the sensor's native measurement space: bistatic range excess and Doppler. The analysis now samples ADS-B truth on the full CFAR block-centre cadence, overlays the truth segment that falls inside each part on the static whitened RDM, and overlays the nearest truth sample on the interactive tracker step view. This makes missed detections, range bias, Doppler-sign errors, and ambiguous captures visible immediately without first back-projecting to geography. | `helperBuildTruthQueryTimes.m`, `helperPlotRDMTruthOverlay.m`, `analyzeBistaticData.m`, `render_rdm_step.m` |
| **Truth Comparison Metrics** | Two-level evaluation: (1) Detection-level — each CFAR detection is labelled TP or FA by testing `|ΔR| < 3×range_cell` AND `|Δf| < 3×Doppler_bin` against every ADS-B aircraft at that CPI time; per-aircraft probability of detection `Pd = n_tp / (n_tp + n_miss)` is tabulated. (2) Track-level — each KF track is associated with the nearest ADS-B aircraft by minimum mean `|ΔR|` over the track's confirmed lifetime; range bias/RMSE and Doppler bias/RMSE are computed. | `assessTruthVsDetections.m`, `plotTruthComparison.m` |
| **Timing-Source A/B Validation** | Multi-part burst sessions can be aligned either by per-file header timestamps or by a simple fallback spacing from the session manifest. Because the truth-fix regression now hinges on whether that timing choice changes TP/FA counts and track bias, the session wrapper preserves the resolved part-start timeline and `runTruthFixTimingComparison` reruns both timing modes back to back, then summarizes the differences against the saved pre-patch log. | `helperGetPartStartOffsets.m`, `analyzeBistaticData.m`, `runBistaticAnalysisSession.m`, `compareBistaticTimingModes.m`, `runTruthFixTimingComparison.m` |
| **Measurement-Space Residual Offset Map** | If timing changes the truth window but does not change TP or FA, the next question is whether detections are consistently displaced from truth by a constant offset in bistatic range and Doppler. `estimateTruthMeasurementOffset` forms all time-near detection/truth candidate pairs, bins their residuals `(ΔR, Δf) = (R_det - R_truth, f_det - f_truth)` into a 2-D histogram, identifies the strongest residual cluster, and then re-scores the detections after compensating by that offset. A strong TP increase after compensation points to a systematic localization or projection bias rather than random false alarms. | `estimateTruthMeasurementOffset.m`, `assessTruthVsDetections.m`, `test_truthMeasurementOffset.m` |

| **Standalone Truth-Diagnostic Bundle** | Re-running the full IQ pipeline to tune truth overlays is too slow, so the analysis now captures a compact post-detection bundle containing the timing grid, CFAR detections, optional tracker histories, and optional cached RDM display data. That bundle is the contract between the full pipeline and the standalone diagnostic unit, letting new truth checks plug back into the main workflow later without reprocessing raw data. | `buildDetectionTruthDiagnosticInput.m`, `saveDetectionTruthDiagnosticInput.m`, `runBistaticAnalysisSession.m`, `analyzeBistaticData.m` |
| **Detection-vs-Truth Time-Series Diagnostics** | Before trusting tracker-to-truth comparisons, first check whether the detector is producing hits near the truth at all. The new diagnostic plots `R_excess(t)` and `f_D(t)` for each ADS-B aircraft and overlays matched versus unmatched detections, so missed CPIs, range bias, Doppler bias, and gating mistakes are visible directly in measurement space. | `plotDetectionTruthDiagnostics.m`, `runDetectionTruthDiagnostics.m`, `assessTruthVsDetections.m` |
| **Snapshot-Based Fast Iteration** | Once one full session has produced `truth_diag_input`, the truth diagnostics can be rerun directly from the in-memory struct or a saved MAT snapshot. `runBistaticAnalysisSession` now auto-saves a compact snapshot under the packaged session, and can optionally save a larger full snapshot that also preserves cached RDM images for standalone RDM overlay replay. This shortens the edit-test loop from minutes to seconds because only ADS-B loading, bistatic projection, alignment, matching, and plotting are repeated; the expensive IQ, ECA-C, CAF, and CFAR stages are skipped. | `runBistaticAnalysisSession.m`, `helperSaveTruthDiagnosticSnapshots.m`, `saveDetectionTruthDiagnosticInput.m`, `runDetectionTruthDiagnostics.m`, `test_adsbTruthPipeline.m` |
| **Detector Replay Checkpoint** | Truth-only snapshots are too late in the chain for CFAR retuning, so the pipeline now saves an earlier checkpoint at the exact detector boundary: each block's whitened RDM, per-row noise-floor vector, absolute noise reference, look count, and block time. `runDetectorReplaySweep` can then rerun only `detectTargets`, rebuild the detection list, and optionally rescore the result against ADS-B truth. This makes CFAR and post-CFAR parameter sweeps fast because IQ loading, ECA-C, and CAF generation are not repeated. | `processOnePart.m`, `buildDetectorReplayInput.m`, `saveDetectorReplayInput.m`, `helperSaveDetectorReplaySnapshot.m`, `runDetectorReplaySweep.m`, `runBistaticAnalysisSession.m`, `test_adsbTruthPipeline.m` |

---

## Clutter Mitigation: ECA-C

### Why ECA-C (and not simple bandstop filtering)?

A simple Doppler notch filter removes all energy at zero Doppler, including target returns at zero bistatic velocity. ECA-C (Extended Cancellation Algorithm — Coherent, Colone 2009) is an **adaptive filter** trained on the reference channel. It estimates the coupling coefficients between the reference and the direct-path interference and clutter seen in the surveillance channel, then subtracts a reconstructed model. The key benefits over a static notch are:

1. **Generalises beyond zero-Doppler**: ECA-C cancels clutter at any Doppler that is correlated with the reference — including specular multipath and moving ground clutter.
2. **Preserves target energy**: The filter only removes what is predictable from the reference signal. Targets with returns not coherent with the reference are untouched.
3. **No range smearing**: A time-domain subtraction, not a Doppler-domain multiplication, so the range sidelobes of the reference waveform are also removed.

### ECA-C Stage 1: Frequency-Domain Least-Squares (LS)

For each Doppler bin (each column of the slow-time DFT), a complex scalar α is estimated by LS regression:

```
α_k = (R_k* · S_k) / (R_k* · R_k)       [R = reference DFT column, S = surveillance DFT column]
```

The cancellation is: `S_cancelled = S - α_k · R_k`. This is a per-bin frequency-domain approach — equivalent to estimating a time-domain FIR filter of order N_cancel bins, but computed efficiently in the DFT domain by processing each range cell independently. `N_cancel = max(1, round(3 × N_slow / 2000))` — dynamically scaled to the CPI length so the same code works for both 2000-CPI full records and 200-CPI sub-chunks.

### Why Dynamic N_cancel?

The LS estimator needs enough degrees of freedom to separate clutter from targets. For a 2000-CPI full record, the original design used N_cancel = 3. For 200-CPI sub-chunks, forcing N_cancel = 3 would over-constrain the estimator (3/200 = 1.5% of the data consumed by cancellation). The dynamic formula `max(1, round(3 × N_slow / 2000))` ensures N_cancel = 1 for N_slow = 200, which is a single complex scalar per bin — the minimum meaningful cancellation that still removes the dominant direct-path term.

**Trade-off**: N_cancel = 1 limits suppression depth. With 200 CPIs and a non-stationary ATSC signal, the LS estimate has a condition number that limits suppression to roughly 13–20 dB (measured: ~13.8 dB). This is a physics constraint, not a code bug.

### ECA-C Stage 2: Zero-Doppler Subspace Notch

After Stage 1, a residual zero-Doppler spur often remains due to stationary clutter that is not perfectly correlated with the reference in a short CPI. Stage 2 applies an SVD-based subspace projection that nulls the dominant components of the zero-Doppler Doppler bin. The projection matrix is `P⊥ = I − U_s · U_s†` where `U_s` are the top N_cancel singular vectors of the zero-Doppler column. This removes the strongest stationary clutter signatures without affecting off-zero-Doppler content.

---

## Sub-Chunk Non-Coherent Integration (NCI)

### Why sub-chunk instead of processing the full 2000-CPI record at once?

ECA-C LS convergence depends on **signal stationarity within the CPI**. For ATSC 1.0, the baseband waveform changes on a timescale of milliseconds (MPEG-2 video content). A 2000-CPI record (1 second) spans many statistical realisations of the signal, which degrades the LS estimate. Shorter CPIs (200 samples = 100 ms) are more stationary.

The penalty for short CPIs is Doppler resolution: `Δf_D = 1 / (N_slow × T_CPI) = 1 / (200 × 0.5 ms) = 10 Hz`. Aircraft at 300 m/s have bistatic Doppler up to 1200 Hz at 600 MHz, so 10 Hz resolution is adequate.

The sub-chunk NCI scheme:
1. Process each 200-CPI block independently through ECA-C and CAF → `rdm_chunk_k` (amplitude-dB)
2. Convert to linear power: `P_k = 10.^(rdm_chunk_k / 10)`
3. Sum and normalise: `rdm_after = 10 × log10(sum(P_k) / N_chunks)`

This is equivalent to **incoherent integration over N_chunks = 10 looks**. The SNR gain is less than the coherent integration gain (√10 vs 10) but the integration gain is real because each chunk independently measures the target's (nearly constant) bistatic range and Doppler.

---

## CFAR Detection: Why OS-CFAR with Gamma Statistics?

### The fundamental CFAR problem

CFAR (Constant False Alarm Rate) sets a detection threshold such that the probability of a false alarm equals a specified `Pfa` regardless of the local noise power. The classical CA-CFAR computes the threshold as `T = α × mean(training cells)`. The scale factor α is chosen from the distribution of the noise statistic.

### Why OS-CFAR over CA-CFAR?

CA-CFAR assumes all N training cells contain only noise (i.e., no interferers, no targets, no sidelobes). When a clutter edge, a strong sidelobe, or an ATSC ghost range falls inside the training window, CA-CFAR inflates the threshold and masks nearby weaker targets. OS-CFAR uses the k-th ranked order statistic (here: 75th percentile, k = 0.75 N), which is robust to up to (N − k) contaminated cells. With N ≈ 592 training cells and k = 0.75, up to 148 contaminated cells have no effect on the threshold.

### Why multi-look Gamma CFAR (betaincinv)?

After NCI over L = 10 looks, the noise statistic is no longer a simple chi-squared with 2 degrees of freedom (the single-look case). The sum of L independent power samples follows a Gamma(L, θ) distribution. The correct α for OS-CFAR with L looks and Pfa is derived from the incomplete beta function inverse:

```
Pfa = betainc(1/(1+α), k, N-k+1) — solved for α via betaincinv
```

where the incomplete beta CDF appears because the order statistic of a Gamma variate has a beta-distributed CDF. For L=10, N=592, Pfa=1e-4: α ≈ 1.04 (OS) vs α ≈ 2.27 (CA). The OS threshold is only 0.17 dB above the 75th-percentile noise estimate when training cells are clean — this is the correct and intentional behaviour.

---

## Slow-Time Window Selection: Why Kaiser(β=6) Over Hann

### The sidelobe contamination threshold wall

The slow-time FFT (Doppler processing) transforms the slow-time dimension of the range profiles into Doppler bins. Any finite-length DFT has sidelobes: energy from a strong signal at Doppler bin 0 (zero-Doppler / DC) "leaks" into adjacent Doppler bins at an amplitude determined by the window's **sidelobe level**.

After ECA-C, the zero-Doppler residual is typically 13–20 dB above the noise floor (limited by LS convergence in a 200-CPI block). This residual DC power leaks into the CFAR training cells at all Doppler bins through the window sidelobes.

**Hann window** (−32 dB first sidelobe):
- Residual DC is ~30 dB above noise
- Hann sidelobes at −32 dB → DC leakage into training cells at 30 − 32 = −2 dB relative to noise floor
- Training cells contain noise + DC leakage, biasing the 75th-percentile upward
- OS-CFAR threshold rises by a few dB everywhere → no target can exceed the threshold → **threshold wall → zero detections**

**Kaiser(β=6) window** (−44 dB first sidelobe):
- Same residual DC at ~30 dB above noise
- Kaiser sidelobes at −44 dB → DC leakage at 30 − 44 = −14 dB relative to noise floor
- Leakage is 14 dB below the noise floor → negligible contribution to training cell estimates
- OS-CFAR threshold remains ≈ noise floor + 0.17 dB → clean detection

**The fix**: `createRDM.m` uses `kaiser(N_slow, 6)` applied to `range_profiles` before the slow-time FFT. Comments in the code explain the sidelobe arithmetic.

### Kaiser vs Hann tradeoffs in general

| Property | Hann | Kaiser(β=6) |
|----------|------|-------------|
| First sidelobe level | −32 dB | −44 dB |
| Coherent processing loss (CL) | 1.76 dB | ~1.8 dB |
| ENBW (noise bandwidth) | 1.50 bins | ~1.57 bins |
| Main lobe width (3-dB) | 1.44 bins | ~1.60 bins |

For passive radar with moderate clutter suppression (13–20 dB ECA-C), the lower sidelobe level of Kaiser is critical for detector stability. The slight main-lobe broadening (0.16 bins) is acceptable given that Doppler resolution (10 Hz at N_slow=200) is already much finer than the target's Doppler spread.

---

## B3 Metric: Windowed vs Unwindowed Clutter Measurement

### The problem

The B3 quality check measures zero-Doppler suppression depth: `suppression_dB = before_val − after_val`. Both `before_val` (pre-ECA-C RDM near zero-Doppler) and `after_val` (post-ECA-C RDM) are extracted from the windowed RDM.

For **coherent clutter** (a strong deterministic signal at zero Doppler):
- The Kaiser window attenuates the coherent signal's DFT amplitude by `mean(kaiser(N, β))` ≈ 0.40 → 20×log10(0.40) ≈ −8 dB
- `before_val` (windowed) is ~8 dB lower than the true unwindowed clutter power

For **noise** (post-cancellation floor):
- Kaiser window raises the equivalent noise bandwidth (ENBW) by `sum(w²)/sum(w)² × N` ≈ 1.57 bins vs 1.0 for boxcar
- `after_val` is elevated by `10×log10(1.57)` ≈ +2 dB

**Net effect**: B3 = (before − 8 dB) − (after + 2 dB) → understates true suppression by ~10 dB.

### The fix

The corrected formula (in `assessDetections.m`):
```matlab
window_coherent_loss_db = -20 * log10(mean(kaiser(N_slow, 6)));  % ≈ +8 dB
before_val = before_val_windowed + window_coherent_loss_db;       % recovers true level
```

This converts `before_val` back to what it would be in an unwindowed DFT, restoring the true clutter amplitude for the B3 comparison. The `after_val` term is not corrected (it is noise, not coherent signal) — only the coherent `before_val` has the window amplitude attenuation.

`window_coherent_loss_db` is dynamically computed in `analyzeBistaticData.m` and passed to `assessDetections.m` via `config.window_coherent_loss_db`. The default is 0 (no correction) to remain backward-compatible with boxcar/no-window workflows.

---

## Detector Calibration: Pfa and the Expected False-Alarm Count (C6)

Check C6 compares the actual detection count to the expected count = `N_cells × Pfa`. This is a sanity check on the CFAR calibration — if the detector is working correctly, the false-alarm rate in noise-only regions should match Pfa.

Ratio >> 10×: noise model is wrong (e.g., training cells contaminated → threshold too low, or Pfa math wrong)  
Ratio << 0.01×: threshold is too high (e.g., contamination in the other direction, or the Gamma/betaincinv formula is computing a much larger α than intended)

With the Hann-window threshold wall, C6 → 0 (threshold so high that no cell passes, even noise-only cells below the expected rate). The expected count with Pfa=1e-4 and N_cells ≈ 2500 × 2000 = 5,000,000 (before guard zone exclusion) is ~500 false alarms. Seeing 0 confirmed the threshold wall was total.

---

## Range Whitening: Per-Row Median Normalisation

### The problem: range-dependent noise floor

After NCI, the RDM has a noise floor that varies with bistatic range (RDM row). Near-range bins (<10 km) retain elevated residual clutter power after ECA-C. If a single global noise estimate is used for CFAR, either:
- Near-range threshold is too low → false-alarm flood
- Far-range threshold is too high → missed targets

### The fix: per-row median as a local noise estimate

In `processOnePart.m`, immediately before CFAR:

```matlab
row_nf_block = median(rdm_block, 2);       % [N_range × 1] median power per range bin (dB)
rdm_block_w  = rdm_block - row_nf_block;   % whitened: each row's median across Doppler → 0 dB
```

Each range bin’s power is shifted so that its median across Doppler becomes 0 dB. OS-CFAR then trains on this whitened map, estimating a consistent threshold (~0.17 dB above the local row median) regardless of the absolute range-dependent noise level.

### Restoring absolute power to detections

CFAR detections from the whitened map report power relative to the row median (whitened dB scale). To produce physically meaningful absolute dB values for `assessDetections.m` (checks B3, D9):

```matlab
abs_nf_block = median(row_nf_block);                                     % representative absolute NF scalar
r_idx = max(1, min(N_range, round(blk_dets(:,1) / range_bin_m) + 1));   % range bin index per detection
blk_dets(:,3) = blk_dets(:,3) + row_nf_block(r_idx);                    % restore to absolute dB
```

The scalar `abs_nf_block` (~224–228 dB for the Newton deployment) is stored in `block_nf_dbs` and returned as `cfar_nf_db` to `analyzeBistaticData.m`.

### Why median and not mean?

The median is robust to the presence of a bright target return in the Doppler dimension. A single strong target does not bias the median of a row with 2000 Doppler cells (it would need to dominate more than half the cells, which is never the case for a single aircraft echo). The mean would be pulled upward by even one bright target, inflating the threshold for that entire range bin and masking nearby weaker targets.

---

## Target Tracking in Measurement Space

### The fundamental observability constraint

A conventional tracking radar sends a pulse and receives it back from a target; from the round-trip delay it measures slant range, and from multiple returns it infers range-rate and, with a phased array, angle. A passive bistatic radar with a **single surveillance receiver** has only one observable per snapshot: the bistatic range excess `R = R_Tx + R_Rx − L`. From a single ellipse you cannot uniquely determine the target's (latitude, longitude) position — every point on that ellipse is an equally valid hypothesis.

**The only well-posed choice is to track in the 1D measurement space `[R; Ṙ]`.** This:
1. Directly tracks what the sensor actually measures — no inversion required.
2. Avoids unobservable states (x, y) that would require two simultaneous measurements (e.g., range + angle, or two receivers) to estimate.
3. Produces a time series of bistatic range and range-rate that is a meaningful trajectory product: each state maps to a bistatic ellipse, and a sequence of ellipses shows the target moving inward or outward.

The geographic footprint is the *envelope* of those ellipses — the operator sees an arc sweep on the globe that constrains target position without resolving it to a point.

### Why `trackTargets.m` uses `trackerGNN` instead of a manual KF loop

A manual loop (compute predicted range, find nearest detection, update KF) requires implementing the full track lifecycle: tentative → confirmed → coasted → deleted. `trackerGNN` from the Sensor Fusion and Tracking Toolbox provides:
- **Hungarian-algorithm GNN assignment** — globally optimal assignment at each time step (not greedy nearest-neighbor per track)
- **Automatic lifecycle management** — tracks are confirmed at `ConfirmationThreshold`, deleted at `DeletionThreshold`, and coasted (predict-only) when unmatched
- **Standard `objectTrack` output** — consistent interface with `objectDetection` inputs, directly compatible with MATLAB's track evaluation and display tooling

The custom `initMeasurementSpaceKF.m` is needed because `trackerGNN`'s default KF initializer expects a full 2D/3D position measurement. A custom init function specifies:
- `H = [1, 0]` — measure `R` only, not `Ṙ`
- `P0 = diag([range_bin_m², (50·range_bin_m/α)²])` — initial range uncertainty = one range cell (~30 m); initial velocity uncertainty = 50 range cells' worth of range-rate (very broad, intentionally uninformative so the first measurement can pull the estimate quickly)
- `Q = q_psd · [dt³/3, dt²/2; dt²/2, dt] × q_psd` (Singer-model process noise at `q_psd = 400 m²/s³`)

### Why `MotionModel = '1D Constant Velocity'`

The state `[R; Ṙ]` evolves as:
```
R(k+1)  = R(k) + Ṙ·dt
Ṙ(k+1) = Ṙ(k) + w_k   (process noise)
```
An aircraft at cruise altitude maintains nearly constant airspeed and heading within a 1–3 second observation window, so the range-rate is approximately constant. A 1D constant-acceleration model would add an unobservable acceleration state — unobservable because range-rate is already the derivative of range, and estimating a second derivative requires more signal than our sparse (3-part, 10 s gap) timeline provides.

### Why `ConfirmationThreshold = [1, 1]`

This means *confirm a track after seeing 1 detection in 1 scan*. The Newton dataset has only three 1-second file parts separated by ~10-second gaps, giving at most 3 tracker time steps per track lifetime. With a stricter threshold such as `[2, 3]` (confirm after 2 detections in 3 scans), a track that appears only in Part 1 and Part 3 would never be confirmed. `[1, 1]` ensures every single-detection hit gets confirmed immediately.

**The cost**: with `[1, 1]`, every single CFAR detection — including random false alarms — spawns a confirmed track. The 26 detections in the Newton run produced up to 10 simultaneously confirmed tracks. Most have `StateCovariance(2,2)` → `σ_v ≈ 370 m/s` (uninformative; the initial prior has not been updated by a second detection). Raising to `[2, 3]` or `[3, 5]` would dramatically reduce spurious tracks at the cost of missing tracks with fewer than 2 detections. The right threshold depends on the expected target density and part-count for future datasets.

### Why `AssignmentThreshold = 50` (range bins)

The assignment gate is the maximum Mahalanobis distance (in measurement space, normalized by the predicted covariance) between a detection and a track prediction. A threshold of 50 means a detection more than 50 standard deviations from the predicted range is not considered a match. With σ_R ≈ 30 m and a 10-second coast gap, the predicted position uncertainty after coasting grows to √(q_psd·Δt³/3) ≈ √(400·333) ≈ 365 m ≈ 12 range bins. A gate of 50 bins ≈ 1500 m comfortably encompasses even an aggressively maneuvering target across the inter-part gap.

### The inter-part gap and tracker coasting

The three Newton data parts were recorded with ~10-second intervals between them (`inter_part_gap_s = 10`). During each gap, the tracker predicts forward without receiving any measurements — this is the KF **coasting** state (`IsCoasted = true`). Tracks are not deleted during coasting unless they fail to receive a detection for `DeletionThreshold(2) = 3` consecutive scan intervals. With only 3 parts, a track that appears in Part 1 and Part 3 but not Part 2 survives the two consecutive coasting steps and is updated in Part 3.

**Why this matters for trajectory continuity**: the 10-second gap means the KF extrapolates `R` forward by `Ṙ × 10 s`. For an aircraft at 500 m/s closing speed, the predicted range changes by 5 km. If the Part-3 detection is within the assignment gate of the coasted prediction, the same TrackID is maintained — producing a continuous trajectory arc across all three parts rather than three unrelated detections.

### How `alpha = fc/c` bridges the state and the RDM display

The KF state is `[R (m); Rdot (m/s)]`. The RDM display axis is Doppler frequency (Hz). The relationship is:
```
f_D = -(fc/c) * Rdot = -alpha * Rdot
```
At `fc = 600 MHz`, `alpha ~= 2.001 Hz/(m/s)`. This factor appears in:
- `initMeasurementSpaceKF.m`: the measurement matrix encodes `f_D = -alpha * Rdot`
- `analyzeBistaticData.m`: console tables and legends convert tracker `Rdot` back to Doppler with `-alpha_trk * state(2)`
- `render_rdm_step.m`: `D_est = -p.alpha_trk * st(2)` and `sigma_D = abs(p.alpha_trk) * sqrt(P(2,2))`

---

## Visualization Architecture

### Why precompute `step_data` instead of computing on-the-fly in the slider callback

The interactive RD map viewer must display one of 11 tracker time steps on each slider drag. The RDM data for each step requires knowing which file part to use (each part is a separate `processOnePart.m` call) and whitening the RDM by subtracting the per-row median. Both steps involve large matrices (2500 × 2000 per part).

If these computations happened inside the slider callback, each step transition would take 10–20 seconds — making the UI unusable. `step_data` (in `analyzeBistaticData.m` §7.4a) precomputes this once after all parts are processed:

```
for each tracker time step s:
    find which part i_p the time t_s belongs to
    rdm_image = part_res(i_p).rdm_after - median(part_res(i_p).rdm_after, 2)
    store: t_abs_s, i_part, rdm_image, range_axis, doppler_axis, dets (this step only), conf_trks
```

Each callback then calls `render_rdm_step.m` with the precomputed `step_data(n)` struct — the callback is a pure visualization operation with no signal processing, completing in < 100 ms.

**Why only the detections for this exact time step?** All 26 detections from the full three-part run are stored in `all_track_dets`. Rendering all 26 on every step would be confusing — a detection from Part 1 appearing on Part 3's background. The `mask_t = abs(all_track_dets(:,5) - t_s) < 1e-9` filter selects only the 1–4 CFAR hits that actually fell in this tracker scan, so the viewer shows "what the CFAR saw at this moment" alongside "what the tracker believed."

### Why `uicontrol` (classic) instead of `uifigure`/`uislider` (App Designer)

`uifigure` and its companion `uislider` component are part of MATLAB's web-based App Designer engine, introduced in R2016a but substantially improved through R2020b. They require the WebView2 runtime and behave differently across desktop/Online/Codespaces environments.

`uicontrol` is the classic UI widget system, unchanged since early MATLAB versions. It runs in the same process as the figure and has deterministic callback timing. Using `uicontrol` for the slider, label, Prev, and Next buttons guarantees the viewer works in any environment where the script runs.

The `SliderStep` parameter is set to `[1/(N_steps-1), 1/(N_steps-1)]` so each unit drag moves the slider by exactly one step — no rounding artifacts.

### Why a static one-pass globe render instead of per-step animation

The original approach updated the globe on every tracker step: for each step, deleted all previous ellipse handles, and drew a new set of altitude-ribbon ellipses for all confirmed tracks. This was the bottleneck:

- **Per-ellipse cost**: 11 `geoplot3` calls (altitude ribbon from −250 m to +250 m in 50 m steps) per main ellipse, plus 2 `geoplot3` calls for the ±1σ side contours = 13 calls per track
- **Per-step cost**: ~5 confirmed tracks × 13 calls = 65 `geoplot3` calls per step
- **Handle deletion loop**: 13 handles × 5 tracks × 11 previous steps accumulated → up to 715 `delete()` calls per step
- **WebGL cost**: each `geoplot3` triggers a full scene redraw in the geoglobe WebView

Result: ~2 seconds per step, ~22 seconds total for the globe portion.

**The fix**: a single post-loop pass rendering the *last-known state* for each unique TrackID — one `geoplot3` call per track at a fixed altitude of `TGT_ALT_M = 3000 m`, no altitude ribbon. For 10 unique tracks: 10 `geoplot3` calls total (down from ~715). Render time: < 1 second.

**Why last-known-state and not final-step?** A track deleted partway through (e.g., T7, lost after Part 2) would be invisible if only the final step's confirmed tracks were rendered. "Last known" means the globe shows *every* track the system ever confirmed, at the last ellipse the KF was confident about — a complete picture of the engagement.

### Why per-TrackID colours (not per-part colours)

`plotBistaticEllipses3D.m` uses per-detection Doppler colour coding: the colour of each ellipse encodes the target's closing/opening speed at the moment of detection. This is useful for the raw CFAR ellipse view (no association) because it turns the globe into a speed map.

The tracker's RD map and globe use per-TrackID colours from `TRK_ID_COLORS` (12-entry qualitative palette). The same colour appears on the track's filled circle in `render_rdm_step.m` and on its globe ellipse in the §7.5 loop. **The cross-reference is the key benefit**: an operator looking at both figures simultaneously can identify which range-Doppler blob corresponds to which geographic ellipse purely by colour, without needing to read the `T#` label.

Multiple tracks can be simultaneously confirmed within the same file part (up to 10 in the Newton run). If part-colour were used, all contemporaneous tracks would be the same colour and be indistinguishable on either the RD map or the globe.

---

## Bistatic Iso-Range Ellipse Geometry

### Concept

For a bistatic radar with transmitter Tx and receiver Rx separated by baseline L, a target producing a range-excess of `R_exc` metres (the y-axis value from the RDM) lies on an **ellipse** with:
- Foci at Tx and Rx
- Semi-major axis `a = (R_exc + L) / 2`
- Focal half-distance `c = L / 2`
- Semi-minor axis `b = sqrt(a² − c²)`

This is the bistatic iso-range contour: every point on the ellipse has the same total Tx→target→Rx path length.

### Coordinate frame

`plotBistaticEllipses3D.m` computes ellipses in a **local ENU frame** with Rx as origin:

1. Convert Tx to ENU: `[txE, txN, txU] = geodetic2enu(txLLA, rxLLA, spheroid)`
2. Shared numeric baseline length `L_3D = norm([txE, txN, txU])`; horizontal bearing `theta = atan2(txN, txE)`
3. Rotation matrix `R2 = [cosθ, −sinθ; sinθ, cosθ]` aligns the horizontal Tx-Rx bearing with the ellipse x-axis
4. Parametric ellipse (midpoint as origin):
   ```matlab
   x_loc = a * cos(phi);  % phi = linspace(0, 2*pi, N)
   y_loc = b * sin(phi);
   ```
5. Rotate to ENU, shift to geographic midpoint, add target altitude as ENU-up
6. Back-project to geodetic: `[lat, lon, alt] = enu2geodetic(e, n, u, rxLLA, spheroid)` (Mapping Toolbox R2021a+)

The numeric truth model uses `L_3D`. The plotting path still uses the horizontal midpoint and bearing as a visualization approximation for fixed-altitude contours.

### Validity bounds

The flat-Earth ENU approximation error is approximately `(L/2)² / (2 R_E²)` where `R_E ≈ 6371 km`. For a 100 km baseline, error < 0.001% — negligible for aircraft positioning. Approximation valid for baselines up to ~200 km.

### Why `enu2geodetic` over ECEF conversion?

`enu2geodetic` (R2021a+) directly inverts the ENU-to-geodetic transform in one call, avoiding the two-step ENU→ECEF→geodetic chain. Code is shorter and the intent is immediately clear. For compatibility with MATLAB versions prior to R2021a, the two-step approach using `enu2ecef` + `ecef2geodetic` is equivalent.

---

## ATSC 1.0 Waveform Artifacts and Why They Matter

ATSC 1.0 transmits at 10.762 Msps with a segment-sync pattern every 832 symbols. The repetition period is:

```
T_rep = 832 / 10.762e6 = 77.3 µs → bistatic range excess = c × T_rep / 2 = 11.6 km
```

Wait — for bistatic radar, the range-excess lags appear at multiples of `c × T_rep = 23.2 km` (not halved, because the target-to-receiver range is the correlation lag, not a round-trip). The cross-correlation of ATSC with itself has peaks at every 23.2 km × n (n = 1, 2, 3...). These are **waveform range sidelobes**, not targets, and appear at the same Doppler as the DPI (zero Doppler). Check A1 counts detections that fall on these exact ranges.

The ATSC pilot carrier (at approximately 310 kHz offset from the channel centre, or a fixed fraction thereof) can appear as a bright Doppler ridge in the CAF output if the pilot tone is not fully removed. Check A2 flags Doppler columns with anomalous integrated power across all ranges.

Both artifact types are eliminated or mitigated by ECA-C (which subtracts the reference signal structure) but residual artifacts can survive if cancellation is limited by short CPI stationarity.

