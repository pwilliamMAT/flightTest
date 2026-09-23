## RF Calibration Comb: Barker-Coded Phase Lock-In Specification

---

## 1. Overview & Objectives

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