# Pluto Waveform Plan
## Phase 2 Standalone Calibration Analysis

## Current Repo Status

This document is a **Phase 2** plan. It does **not** replace the existing Phase 1 Pluto tone precheck that is already implemented under `TestSetupTesting/`.

The current Phase 1 workflow is the authoritative Pluto hardware-readiness gate:

1. Load a commissioned baseline and verify that the requested runtime settings still match it.
2. Build one deterministic Pluto baseband **CW tone** at the requested `ToneOffset_Hz` and `ToneAmplitude`.
3. Start Pluto transmission before the receive capture begins.
4. Run one short dual-channel N320 capture through the existing `runLocalHDTVCapture.m` path.
5. Read the first `.bb` file written by that N320 capture through the existing readback path.
6. Score the received tone on each channel and write a self-contained standalone result folder.

The frozen receive-channel convention for this project remains:

- `SURV = CH1 / RX1 = RF0`
- `REF = CH2 / RX2 = RF1`

The current HDTV collection context for new Pluto analysis work is the **599 MHz** collection band. Phase 2 analysis should therefore expect the modern capture context to be near `599e6`, but it must still check capture-header metadata explicitly instead of silently assuming the expected tuning was used.

## Phase 2 Goal

Phase 2 adds a **secondary standalone analysis layer** on top of captures that already exist from the Phase 1 Pluto workflow or other archived N320 `.bb` files that were collected in the same tone-based context.

Phase 2 is intended to:

- deepen the diagnostic review of Phase 1 Pluto captures
- reuse the baseline/result context that already exists before this plan
- remain **standalone**
- start with **archived `.bb` verification first**

Phase 2 is **not** intended to:

- replace the Phase 1 tone readiness gate
- replace ATSC pilot/direct-path checks for passive bistatic suitability
- introduce a second Pluto transmit/capture workflow in parallel with the existing one
- integrate into `run_coordinated_hdtv_capture.sh`

## Relationship to Phase 1

- **Phase 1** decides whether the Pluto tone path is ready to use.
- **Phase 2** adds deeper follow-on diagnostics to the same run context.
- Phase 2 should reuse the existing Phase 1 result and baseline context rather than inventing a competing top-level workflow.
- Phase 2 outputs should attach to the existing Phase 1 run folder as additional artifacts so review stays tied to the original run.

## Standalone Scope

This Phase 2 plan stays standalone.

Out of scope for the initial Phase 2 implementation:

- integration into `run_coordinated_hdtv_capture.sh`
- edits to the coordinated packaged-session flow
- edits to the existing Phase 1 public API
- new public Pluto runtime controls such as `Gain` or `RadioID`
- live hardware-in-the-loop as the primary verification target
- wideband Pluto waveform generation as the initial implementation target

## Native Function Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Reuse one existing Phase 1 Pluto run and add deeper offline diagnostics | `comm.BasebandFileReader`, `pwelch`, `goertzel`, `xcorr` | Keep the current Pluto transmit/capture workflow unchanged and operate on saved Phase 1 artifacts or archived `.bb` files |
| Re-score channel tone behavior and add richer signal-health checks | Existing repo helpers plus `pwelch`, `goertzel`, `findpeaks` | Reuse the current tone-based scoring context and add secondary metrics without replacing the Phase 1 summary contract |
| Check capture provenance against requested tuning and sample-rate assumptions | `comm.BasebandFileReader` metadata + existing result settings | Add explicit header-vs-request comparisons so old `540 MHz / 6.144 MSPS` captures do not silently look like current `599 MHz` captures |
| Future wideband calibration concepts | `comm.RaisedCosineTransmitFilter` / `rcosdesign`, `mscohere`, `firls` | Defer these ideas to a later sub-phase and do not treat them as the initial implementation target |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Deterministic tone presence / frequency / level checks | `pwelch`, `goertzel`, `findpeaks` | `[pxx, f] = pwelch(x, window, noverlap, nfft, fs, "centered")` |
| Capture readback and metadata checks | `comm.BasebandFileReader` | `reader = comm.BasebandFileReader(path, "SamplesPerFrame", N)` |
| Advisory channel lag / consistency check | `xcorr` | `[c, lags] = xcorr(x1, x2, maxLag, "coeff")` |
| DC / clipping / IQ-health checks | built-in vector operations | `mu = mean(x); clip_ratio = mean(abs(real(x)) > threshold)` |
| Deferred coherence / equalization work | `mscohere`, `firls` | `cxy = mscohere(x, y, window, noverlap, nfft, fs)` |

## Initial Phase 2A Implementation

### Top-Level Entry Point

File name:

- `runPlutoTonePhase2Analysis.m`

Preferred syntax:

```matlab
phase2 = runPlutoTonePhase2Analysis( ...
    'Source', source, ...
    'PlotFigures', true, ...
    'Verbose', true);
```

### Source Contract

`Source` is required and should resolve to **existing Phase 1 context**, not a new Pluto transmit session.

Accepted source types for the initial implementation:

- a Phase 1 Pluto run folder
- a Phase 1 `result.mat`
- a Phase 1 `result.json`
- an in-memory Phase 1 result struct

The preferred path is to load one prior Phase 1 result and use that result's stored settings, baseline reference, and capture-file reference as the authoritative context for Phase 2.

### Required Behavior

1. Load the existing Phase 1 result using the current standalone result schema.
2. Resolve the capture file referenced by that Phase 1 result.
3. Read the stored `.bb` capture through the existing readback path.
4. Verify capture provenance against the stored runtime settings:
   - `center_frequency_hz`
   - `lo_offset_hz`
   - `header_tune_frequency_hz`
   - `sample_rate_hz`
   - minimum valid sample count
5. Reuse the frozen channel map:
   - `SURV = CH1 / RX1 / RF0`
   - `REF = CH2 / RX2 / RF1`
6. Compute deeper tone-based diagnostics without changing the Phase 1 verdict contract.
7. Write a Phase 2 artifact set under the existing run folder.

### Phase 2A Metrics

The initial Phase 2A implementation remains **tone-based**. It should not require a new wideband Pluto waveform.

Per-channel diagnostics:

- clip ratio on `I` and `Q`
- zero / dropout ratio
- DC offset magnitude
- IQ power-balance ratio
- simple circularity / impropriety metric
- rechecked tone frequency
- rechecked tone level
- tone-bin phase estimate

Joint diagnostics:

- channel-to-channel frequency delta
- channel-to-channel phase delta at the detected tone
- advisory-only `xcorr` peak and lag
- capture-header consistency summary

### Initial Phase 2A Status Model

Phase 2A is a **secondary analysis**, not the primary readiness gate. It should therefore attach secondary status information to the existing run rather than overwrite the original Phase 1 outcome.

Recommended status model:

- `PASS` when provenance checks pass and no secondary warnings are raised
- `WARN` when the Phase 1 run is usable but Phase 2 diagnostics detect drift, mild imbalance, or metadata mismatch
- `FAIL` only when the Phase 2 analysis cannot trust or interpret the referenced capture at all

### Phase 2A Artifacts

Write Phase 2 outputs into a subfolder under the existing Phase 1 run folder:

- `phase2_analysis/phase2.mat`
- `phase2_analysis/phase2.json`
- `phase2_analysis/summary.txt`
- `phase2_analysis/summary.png`

Recommended struct content:

- `phase2.phase1_source`
- `phase2.phase1_status`
- `phase2.baseline_id`
- `phase2.capture_info`
- `phase2.header_checks`
- `phase2.signal_health.reference`
- `phase2.signal_health.surveillance`
- `phase2.tone_diagnostics.reference`
- `phase2.tone_diagnostics.surveillance`
- `phase2.joint_diagnostics`
- `phase2.status`
- `phase2.notes`
- `phase2.artifact_paths`

### Phase 2A Visualization

Construct one `figure` with `tiledlayout(2,2)` and include explicit axis labels and titles on every tile.

Recommended tiles:

1. PSD overlay of `REF` and `SURV` around the expected tone region
2. clipping / DC / dropout summary view
3. tone phase / frequency comparison between channels
4. provenance and advisory lag summary

## Verification Approach

The initial verification path for Phase 2 is **archived `.bb` first**.

That means:

- use existing Phase 1 run folders and saved captures as primary test inputs
- verify offline analysis behavior before adding any new live-hardware expectation
- keep hardware-in-the-loop validation as later work

Phase 2 verification should explicitly cover:

- a clean recent `599 MHz` tone capture
- an older capture with mismatched metadata
- a capture with obvious clipping or low-level issues
- a source that is missing the referenced `.bb` file

## Deferred Wideband Calibration Concepts

The earlier draft of this file proposed a wideband Pluto waveform and equalization workflow using Zadoff-Chu / RRC shaping, sub-sample delay extraction, coherence, and FIR equalization.

Those ideas are **not** the initial Phase 2 implementation target.

If revived later, they must be treated as a separate sub-phase, for example **Phase 2B**, with these constraints:

- remain separate from the Phase 1 readiness gate
- use controlled coupling assumptions, not casual near-field OTA injection
- define their own repeatable verification criteria
- avoid presenting a custom Pluto waveform as proof that the passive HDTV reference chain is operationally valid

## Phase 2B Waveform Selection Prototype

The first Phase 2B artifact is [designPlutoPhase2BWaveformPrototype.m](designPlutoPhase2BWaveformPrototype.m). It is an offline design sandbox, not a hardware transmitter.

Plain-language purpose:

- A **CW tone** is still the right Phase 1 readiness signal because it is simple, narrow, deterministic, and easy to detect in both channels.
- A **multitone comb** keeps the same spectral-bin idea but emits several known tones in one CPI, so the receiver can integrate evidence across tones instead of trusting one line.
- An **LFM chirp** spends bandwidth deliberately and then uses matched filtering to compress the received energy into a timing peak, which is useful if the next question is delay, impulse response, or processing gain rather than simple path presence.

The prototype uses toolbox-first primitives:

- `dsp.SineWave` for the CW and multitone components
- `phased.LinearFMWaveform` for the chirp
- `phased.MatchedFilter` for matched-filter response and pulse-compression comparison
- `pwelch`, `spectrogram`, `hann`, and `goertzel` for spectrum and tone-integration diagnostics

The current engineering recommendation is:

1. Keep the Phase 1 CW tone readiness gate unchanged.
2. Use the multitone comb as the lowest-risk Phase 2B extension if the immediate goal is stronger pilot evidence while staying close to the existing tone workflow.
3. Use the LFM chirp when the goal is timing, channel impulse response, or matched-filter processing gain.
4. Do all Phase 2B evaluation offline first, then decide whether a live Pluto transmit experiment is justified.

### Live Multitone Smoke Experiment

The first live-capable Phase 2B experiment is [runPlutoMultitoneStage6Smoke.m](runPlutoMultitoneStage6Smoke.m). It is intentionally shaped like the existing Stage 6 CW runner:

1. Build one deterministic multitone baseband buffer with [helperPlutoMultitoneBuildWaveform.m](helperPlutoMultitoneBuildWaveform.m).
2. Start Pluto TX with the existing `helperPlutoToneStartTx` path.
3. Capture the N320 channels with the existing `helperPlutoToneCaptureN320` path.
4. Read the `.bb` file through the existing `helperPlutoToneReadCapture` path and preserve the frozen channel mapping.
5. Score every expected tone in REF and SURV with [helperPlutoMultitoneScoreCapture.m](helperPlutoMultitoneScoreCapture.m), which reuses `helperPlutoToneScoreChannel` per tone and then aggregates the comb evidence.

Default FTC command:

```matlab
result = runPlutoMultitoneStage6Smoke('Verbose', true);
```

Default waveform:

- `CenterFrequency_Hz = 599e6`
- `SampleRate_Hz = 8e6`
- `LOOffset_Hz = 0`
- `ToneOffsets_Hz = [-350 -250 -150 -50 50 150 250 350] * 1e3`
- `TargetRMSAmplitude = 0.20`
- `PeakLimit = 0.80`

This is still not a commissioned baseline workflow. Treat it as a one-run evidence-gathering experiment that answers whether multiple pilot lines are more robust than the current single CW tone in the same physical setup.

## Coding & Documentation Standards

- Prefer built-in MATLAB functions and current repo reuse points over parallel custom stacks.
- Keep all computations vectorized where practical.
- Use robust input validation with `arguments` blocks or `validateattributes`.
- Use `try-catch` around file I/O and metadata reads.
- All plots must call `figure` explicitly and include `xlabel`, `ylabel`, and descriptive `title`.
- Use `tiledlayout` / `nexttile` rather than `subplot`.
- Use formatted text output and machine-readable saved artifacts for review.

## Summary

This document now defines a **Phase 2 standalone offline analysis plan** that follows the already-implemented Phase 1 Pluto tone precheck. It keeps the repo's current channel mapping, uses the current `599 MHz` collection context, stays standalone, reuses the baseline/result artifacts that already exist, and defers wideband Pluto calibration concepts until later approval.
