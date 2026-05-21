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
| **Bistatic Iso-Range Ellipse** | The locus of all target positions with a given bistatic range-excess `R_exc` is an ellipse with Tx and Rx at the foci: `a = (R_exc+L)/2`, `b = sqrt(a²-c²)`, `c = L/2`. Computed in local ENU frame (Rx as origin) and back-projected to geodetic via `enu2geodetic`. Used to map CFAR detections onto a geographic display. | `plotBistaticEllipses3D.m` |

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
2. Baseline length `L = hypot(txE, txN)`; rotation angle `theta = atan2(txN, txE)`
3. Rotation matrix `R2 = [cosθ, −sinθ; sinθ, cosθ]` aligns the Tx–Rx axis with the ellipse x-axis
4. Parametric ellipse (midpoint as origin):
   ```matlab
   x_loc = a * cos(phi);  % phi = linspace(0, 2*pi, N)
   y_loc = b * sin(phi);
   ```
5. Rotate to ENU, shift to geographic midpoint, add target altitude as ENU-up
6. Back-project to geodetic: `[lat, lon, alt] = enu2geodetic(e, n, u, rxLLA, spheroid)` (Mapping Toolbox R2021a+)

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

