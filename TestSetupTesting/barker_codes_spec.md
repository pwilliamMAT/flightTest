## RF Calibration Comb: Barker-Coded Phase Lock-In Specification

> **Status (2026-09-23): on hold. The premise below is not supported by the data.**
> Evidence: [`reporting/diagnostics/PlutoCombPresence_Diagnostic_V1.html`](../reporting/diagnostics/PlutoCombPresence_Diagnostic_V1.html).
> The original specification is kept unchanged from section 1 on. Inline notes mark the affected sections.

## 0. Review of observations (2026-09-23)

### 0.1 What the data show

1. **The Pluto comb has not been detected in any N320 capture.** That covers 82 archived captures (Jul–Aug 2026) and 4 new ones (2026-09-23, Pluto TX gain −10 and 0 dB, tones in-band at ±150–650 kHz and out-of-band at ±3.0–3.5 MHz). Checks used: pulse-window vs. Pluto-off spectrum; tone bin vs. its ±10 kHz neighbours with the ATSC pilot as a positive control; and a 1 Hz coherent search over ±60 kHz of offset against a Pluto-off baseline. At the N320 the comb is below about −78 dBFS per tone. The method finds a synthetic comb at −75 dBFS (out-of-band) and −65 dBFS (in-band).
2. **The Pluto itself transmits the comb correctly.** A self-loopback (TX dipole → Pluto RX) shows all 12 tones at their planned frequencies, +35 dB above the floor at TX −10 dB, falling by 20 dB when TX gain drops by 20 dB. The loss is in the stairwell-to-Yagi path: glass enclosure, 61 ft to REF and 106 ft to SURV, and very likely off the Yagis' main lobes.
3. **The "9–13 kHz REF/SURV frequency offset" in §1 isn't physical.** `ChannelFrequencyDelta_Hz` is the difference between the strongest bins found near each planned tone in each channel. With no tone present, each channel picks a different noise peak, giving random values from 1 to 28 kHz that average about 12 kHz. Two channels of one N320 share a reference clock, and any Pluto frequency error is common to both, so a kHz-level REF/SURV difference isn't expected in the first place.
4. **The "observed ~12–14 dB" coherent gain in §1 is also a noise artifact.** `helperPlutoMultitoneScoreCapture.m` sums the linear per-tone peak/floor ratios, so N noise-only tones score 10·log₁₀(N) dB (10.8 dB for 12, 10.4 dB for 11). Every logged multitone "integrated margin" sits within about 0.3 dB of that line, or below it.
5. **The frequency drift rate df/dt (§5.1, §9) therefore can't be measured yet.** There is no tone to track.

### 0.2 Technical issues in the current specification

Independent of the premise, these need fixing before any implementation:

- **Spectral overlap (§2.1).** Modulating each tone with an 11-chip code at 200 kchip/s spreads it to a ±200 kHz main lobe. The tones are 100 kHz apart, so neighbouring coded tones overlap almost completely and can't be separated by frequency.
- **Correlation window (§4.1).** One code period is 11 chips × 40 samples/chip = 440 samples. Correlating a single 40-sample (one-chip) block against the 11-chip code doesn't measure the code. The correlation has to run over at least one full 440-sample period.
- **Mixer frequency (§3.2).** The N320 samples are already at complex baseband around the tuned 599 MHz. Mix with the tone *offset* only: `x .* exp(-1j*2*pi*f_offset/fs*n)`, not 599 MHz + offset. Also low-pass filter or block-average each channel on its own *before* forming any REF/SURV product; otherwise the other 11 tones and the ATSC signal leak into every tone's estimate.
- **Code orthogonality (§2.2).** There is no set of 12 mutually orthogonal 11-chip Barker variants. Cyclic shifts of a Barker code have off-peak correlation of magnitude 1/11, not zero. If per-tone codes are really needed, use a code family designed for that (e.g. Gold or Walsh-Hadamard) at a chip rate compatible with the tone spacing.
- The checklist (§10) says "12-bit"; the specification uses 11-chip codes.

### 0.3 Recommended direction: N320 as the calibration source

The operator proposes using the N320's own transmitter as the pilot/calibration source, since it is already near the antennas, and keeping the Pluto only for environmental monitoring. That changes the problem this specification set out to solve:

- **No transmitter-receiver frequency offset.** The N320 TX and both RX channels share one reference clock and LO chain, so the injected tones land exactly on their planned bins, with no Pluto crystal offset (±25 ppm is up to ±15 kHz at 599 MHz) and no slow-time residual between transmitter and receiver.
- **REF/SURV relative phase becomes nearly static.** What remains is the fixed difference in cable, antenna and propagation path, plus slow thermal drift. A per-tone complex average over the pulse (after per-channel mixing and block-averaging) should then give the full coherent gain without adaptive phase tracking. Barker-based phase lock-in is probably unnecessary for the *phase* problem.
- **Where a code still helps is delay.** For bistatic processing the useful calibration is the REF–SURV **delay** and phase difference (and direct-path multipath), not just the phase at a few tones. A wideband pseudo-noise or Barker sequence transmitted from the N320, at a chip rate chosen for delay resolution (e.g. 1–4 Mchip/s at 8 MS/s) and cross-correlated separately in REF and SURV, measures the inter-channel delay directly. This would replace the comb, not modulate each comb tone.
- **Hardware notes.** The captures use the RX2 ports (`RF0:RX2`, `RF1:RX2`), so the TX/RX ports are free for an injection antenna or a coupled/attenuated feed. Simultaneous transmit and receive needs `basebandTransceiver` rather than `basebandReceiver`. Transmitting on the same board makes internal TX→RX leakage a possibility, so keep an on/off pulse structure and verify presence against a TX-off baseline (the `plutoCombFineCheck` / `plutoBurstPresence` pattern) before trusting any calibration number. Occupied-channel emissions still apply, as with the Pluto.
- **The Pluto becomes an environmental monitor.** It is useful as an independent receiver of the local RF environment, but it is no longer part of the calibration chain.

### 0.4 Before resuming this specification

1. Get a calibration signal into both channels that passes a noise-baselined presence check: the N320 TX source, or a relocated or cabled Pluto.
2. Measure the actual REF/SURV phase and frequency behaviour at the measured tone frequencies (per-channel mixing and block-averaging).
3. Only if that shows phase variation faster than a per-pulse average can handle, revisit coded phase tracking. If so, fix the issues in §0.2 first.

---

## 1. Overview & Objectives

> *Review note (2026-09-23): the problem statement and expected outcome below rest on noise-only metrics; see §0.1 items 3–4.*

**Goal:** Recover missing ~7 dB of coherent integration gain by implementing per-tone phase lock-in using a dual-channel (SURV/REF) Barker-coded reference system.

**Problem Being Solved:** 9–13 kHz frequency offset between SURV and REF channels causes phase winding that destroys coherent integration across the 1-second pulse. Barker codes provide high-SNR phase measurement and enable adaptive phase correction.

**Expected Outcome:** Close the gap between expected coherent gain (~17.8 dB) and observed (~12–14 dB), recovering ~3–5 dB additional margin.

---

## 2. Signal Specification

### 2.1 Transmitter (Pluto SDR)

**12-Tone Comb with Barker-Code Modulation**

| **Parameter** | **Value** |
|---|---|
| **Center frequency** | 599 MHz |
| **Tone offsets** | ±150, ±250, ±350, ±450, ±550, ±650 kHz |
| **Number of tones** | 12 |
| **Tone duration** | 1.0 second |
| **Barker code (per tone)** | 11-bit, unique orthogonal code assigned to each tone |
| **Barker chip rate** | 200 kHz [chip/sec] |
| **Barker code period (Tc)** | 11 / 200 kHz = 55 µs |
| **Barker code repetitions in 1 sec** | ~18,181 repetitions |

> *Review note (2026-09-23): at 200 kchip/s each coded tone spreads to ±200 kHz, overlapping its 100 kHz-spaced neighbours; see §0.2.*

### 2.2 Barker Code Assignment

**Use 12 orthogonal or near-orthogonal 11-bit codes.** Recommended approach:
- Start with the canonical 11-bit Barker code: `[+1, +1, +1, −1, −1, −1, +1, −1, −1, +1, −1]`
- Generate 12 orthogonal variants via:
  - **Cyclic shifts** (if 12 orthogonal shifts exist in 11-bit space), OR
  - **Complementary pairs with frequency offsets** (e.g., apply small +/− phase rotations to base code), OR
  - **Hadamard/Walsh codes** of length 16, select 12 rows

**Recommendation:** Use small tone-specific phase increments on a single base code if true orthogonal sets are unavailable. Separation by **frequency + phase shift** is clearer than cyclic shifts.

### 2.3 Slow-Time Phase Evolution

**Optional (future refinement):** Barker codes can also be modulated with slow-time phase ramp to further resolve oscillator drift. For Phase 1, keep phase constant; phase ramp can be added if needed.

---

## 3. Receiver Processing (USRP N320: SURV + REF Channels)

### 3.1 Signal Capture

| **Parameter** | **Value** |
|---|---|
| **RX sample rate** | 8 MS/s |
| **RF bandwidth** | ~1.3 MHz (covers all 12 tones) |
| **Capture duration** | 1.0 second = 8,000,000 samples |
| **Quantization** | 16-bit I/Q (complex) |
| **Channels** | SURV (surveillance), REF (reference) |

### 3.2 Per-Tone Demodulation

For each tone **k** ∈ {1, 2, …, 12}:

**Step 1: Baseband Demodulation**
```
f_k_offset = tone_offset[k]  % ±150, ±250, … ±650 kHz
f_k_center = 599 MHz + f_k_offset

SURV_IQ_k = demod(SURV_raw, f_k_center, 8 MHz sample rate)
  → complex-valued baseband, 8 MS/s rate, length 8M samples

REF_IQ_k = demod(REF_raw, f_k_center, 8 MHz sample rate)
  → complex-valued baseband, 8 MS/s rate, length 8M samples
```

Use a standard complex mixer:
```
demod(x, f_c, fs) = x * exp(-j * 2π * f_c / fs * [0:N-1])
```

---

## 4. Barker Correlation & Phase Measurement

### 4.1 Barker Code Correlation (Per Tone)

> *Review note (2026-09-23): one code period is 440 samples, not 40; see §0.2. The mixer in §3.2 should use the tone offset only.*

For each tone **k**:

**Input:** 
- `SURV_IQ_k`, `REF_IQ_k` (length 8 M complex samples)
- `barker_k` (11-bit code assigned to tone k, e.g., `[+1, +1, +1, −1, −1, −1, +1, −1, −1, +1, −1]`)

**Processing:**
```
barker_chip_rate = 200 kHz = 200,000 chips/sec
sample_rate = 8 MS/s
samples_per_chip = 8,000,000 / 200,000 = 40 samples/chip

% Reshape to blocks of 40 samples (one chip per block)
SURV_blocks_k = reshape(SURV_IQ_k, 40, 8,000,000/40)
  → 40 × 200,000 matrix

% Correlate each block with Barker code
For i = 1 : 200,000 :
  block_i = SURV_blocks_k(:, i)  % 40 complex samples
  
  % Correlate block against each of the 11 Barker chips
  corr_i = correlate(block_i, barker_k, 'full')
    → complex output, length 50
  
  % Find peak correlation
  [mag_i, idx_i] = max(abs(corr_i))
  phase_SURV_k(i) = angle(corr_i(idx_i))  % phase at peak
```

Repeat for `REF_IQ_k` → `phase_REF_k` (200,000 phase estimates per tone).

### 4.2 Phase Error Extraction

For each tone **k**:
```
phase_error_raw_k = phase_SURV_k - phase_REF_k
  → 200,000 estimates (one per Barker code period)

% Unwrap phase to handle ±π wrapping
phase_error_k = unwrap(phase_error_raw_k)
```

---

## 5. Phase Tracking & Correction

### 5.1 Phase Error Smoothing (Low-Pass Filter)

**Goal:** Remove measurement noise from Barker correlation while tracking slow oscillator drift.

> *Review note (2026-09-23): df/dt can't be measured until a calibration tone is actually present at the N320; see §0.1 item 5.*

**Frequency Drift Rate (TO BE FILLED IN):**
```
df/dt = [AWAITING USER CALCULATION] Hz/sec
```

**Recommended Filter Bandwidth:**
- Measurement update rate from Barker: **~18 kHz** (one correlation every 55 µs)
- Required tracking bandwidth: **5–10 × df/dt** Hz
- **Phase error filter cutoff: 200 Hz** (conservative; adjust based on actual df/dt)

**Implementation:** First-order IIR low-pass filter on unwrapped phase error:
```
alpha = 2 * π * f_cutoff / (2 * π * f_cutoff + f_meas_rate)
  where f_cutoff = 200 Hz, f_meas_rate = 18 kHz

phase_error_filtered_k(1) = phase_error_k(1)

For i = 2 : 200,000 :
  phase_error_filtered_k(i) = alpha * phase_error_k(i) 
                            + (1 - alpha) * phase_error_filtered_k(i-1)
```

Result: `phase_error_filtered_k` (200,000 smoothed phase estimates).

### 5.2 Phase Correction Interpolation

Upsample phase correction from 18 kHz (Barker rate) back to 8 MS/s:

```
% Expand phase corrections to match original sample rate
phase_correction_k = interp(phase_error_filtered_k, 40)
  → 8,000,000 complex phase corrections

% Alternative: linear interpolation between Barker measurements
phase_correction_k = interp1(barker_timestamps, phase_error_filtered_k, ...
                             sample_timestamps, 'linear')
```

---

## 6. Baseband Demodulation with Phase Correction

For each tone **k**:

```
SURV_corrected_k = SURV_IQ_k .* exp(-j * phase_correction_k)
  → 8 M complex samples, phase-locked to REF

REF_corrected_k = REF_IQ_k  % reference is already "correct" by definition
```

---

## 7. Coherent Integration & Power Calculation

For each tone **k**:

```
% Coherent sum (complex, full 1-second window)
coherent_sum_k = sum(SURV_corrected_k)

% Coherent power (dB)
power_k_coherent = 20 * log10(abs(coherent_sum_k) / 8e6)  % normalized by sample count

% Non-coherent power (Welch PSD reference, for comparison)
[Pxx_k, ~] = pwelch(SURV_IQ_k, [], [], [], 8e6);
power_k_welch = 10 * log10(Pxx_k(closest_bin_to_f_k))
```

---

## 8. Output Metrics

For each of the 12 tones, compute and log:

| **Metric** | **Definition** | **Unit** |
|---|---|---|
| **Coherent power** | `20*log10(abs(sum(corrected)) / N_samples)` | dB |
| **Welch power** | Welch PSD at tone bin | dB |
| **SNR margin (coherent)** | Coherent power − noise floor | dB |
| **Barker peak mag (SURV)** | Max magnitude of Barker correlation | linear |
| **Barker peak mag (REF)** | Max magnitude of Barker correlation | linear |
| **Phase tracking residual RMS** | `sqrt(mean(phase_error_filtered_k^2))` | radians |
| **Frequency delta (median, RMS)** | From initial frequency search | Hz, Hz |

---

## 9. Parameters Summary Table

| **Item** | **Value** | **Status** |
|---|---|---|
| **Barker code length** | 11 bits | Fixed |
| **Barker chip rate** | 200 kHz | Initial estimate; adjust if df/dt > 10 kHz/sec |
| **Barker update interval** | 55 µs (~18 kHz rate) | Derived |
| **Phase filter cutoff** | 200 Hz | Initial; refine based on actual df/dt |
| **Phase filter alpha** | ~0.037 | Derived from 200 Hz & 18 kHz rates |
| **Frequency drift rate (df/dt)** | **[AWAITING INPUT]** | **User to fill in from calculation** |
| **Recommended Barker rate adjustment** | If df/dt > 10 kHz/s, increase to 500 kHz | Decision threshold |

---

## 10. Phase 1 Implementation Checklist

- [ ] Implement 12-bit Barker code transmit waveform (Pluto)
- [ ] Verify on-the-air Barker structure (inspect SURV/REF captures)
- [ ] Demodulate each of 12 tones to baseband (SURV & REF)
- [ ] Implement Barker correlation per tone (can use FFT-based convolution)
- [ ] Extract phase from correlation peak (all 200k estimates per tone)
- [ ] Unwrap phase error (SURV − REF)
- [ ] Apply low-pass filter (200 Hz cutoff, first-order IIR)
- [ ] Interpolate phase correction to 8 MS/s
- [ ] Apply phase correction to SURV baseband
- [ ] Coherently integrate corrected SURV (1-second window)
- [ ] Compare coherent power before/after correction → measure gain recovery
- [ ] Log all metrics; analyze phase tracking residuals

---

## 11. Known Unknowns & Next Steps

1. **Frequency drift rate (df/dt):** User to measure from peak-search over time windows
2. **Barker code orthogonality:** Verify 12 codes have low cross-correlation (<0.1) or consider Hadamard approach
3. **Phase filter tuning:** May need to increase bandwidth if drift is faster than expected
4. **Noise floor stability:** Confirm SURV/REF noise floors are stable across 1-second window

---

**Once you have the frequency drift rate, I can refine the Barker chip rate and filter bandwidth to match your actual conditions.**