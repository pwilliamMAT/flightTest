# Implementation Plan: Improve Synthetic Quality Checks

## Summary

This plan strengthens the synthetic HDTV session workflow so it builds real confidence in the generated bistatic IQ before time is spent tuning the downstream passive radar analysis chain. The key idea is to move beyond "the files look reasonable" and prove that the generated `.bb` artifacts preserve the same truth that drove synthesis.

The existing generator architecture is already sound at a modeling level:

- `helperSyntheticGenerateTruth` produces `bistatic_tracks`
- `helperSyntheticSynthesizeSeedBackedChannels` uses those same `R_excess_m` and `f_D_hz` values to synthesize target echo delay and Doppler

The remaining work is to make that consistency visible, measurable, and easy for a user to trust from the walkthrough.

## Native MATLAB Audit

### Workflow analogues

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Static synthetic-scenario preview with target motion and measurement-space truth | `tiledlayout`, `plot`, `scatter`, `text`, `geoTrajectory`, `lookupPose` workflows in MATLAB / Navigation Toolbox | Keep the existing preview, but make the first tile explicitly "sampled active-window trajectory" and add start/end markers plus motion-scale annotation |
| Cheap pre-pipeline IQ validation for passive bistatic data | Signal-inspection and diagnostic workflows using `periodogram`, `xcorr`-style lag estimation, `fft`, `imagesc`, and current repo helpers `runDirectPathPrecheck` and `createRDM` | Turn the validation into a mode-aware helper that distinguishes broadcast-specific checks from generic synthetic-signal checks |
| Truth-to-measurement consistency validation | Radar Toolbox / passive-radar-style measurement validation using truth-to-range/Doppler comparison | Add required overlay and numeric residual checks between predicted synthetic truth and measured RDM / cross-correlation peaks |
| Processor-readiness validation | Existing `processOnePart` chunking logic and CAF / clutter-mitigation path | Match the cheap validation dwell to the same CPI and chunking conventions the real processor uses, so the preview is actually predictive of downstream behavior |

### Function analogues

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Waypoint-driven truth sampling | `geoTrajectory`, `lookupPose` | `traj = geoTrajectory(waypoints,timeOfArrival); pose = lookupPose(traj,t);` |
| Spectrum sanity check | `periodogram` | `periodogram(x,[],nfft,fs,"centered","power")` |
| Delay / channel-alignment sanity | FFT-based cross-correlation or `xcorr`-style lag estimation | `xc = ifft(fft(x).*conj(fft(y)));` |
| Range-Doppler sanity map | `fft`, `fftshift`, `imagesc` using existing CAF path | `imagesc(dopplerAxis,rangeAxis,rdm)` |
| Target overlay / residual check | Built from existing truth arrays plus nearest-bin comparison | `interp1(...)` for truth-at-dwell and bin-index comparison |

## Implementation Changes

### 1. Clarify the synthetic preview

- Keep the first preview tile in LLA coordinates because the current plotting logic is already correct.
- Update `SyntheticHDTVSimulation/helperSyntheticPlotScenarioOverview.m` so the first tile is explicitly labeled as sampled target motion over the active scenario window, not a single snapshot.
- Retain both geometry layers already present:
  - editable waypoint path
  - sampled truth path
- Strengthen motion cues:
  - add explicit start markers
  - add explicit end markers
  - include active-window duration and truth sample period in the title or subtitle
  - add short explanatory text that short captures can make motion appear nearly static relative to the Tx/Rx geometry
- Keep the overall preview lightweight and static. Do not add a second geometry view in this pass.

### 2. Make truth provenance explicit in user-facing labels

- Update the range and Doppler preview legends so they do not use bare labels such as `SYNTH01`.
- Use explicit provenance wording such as:
  - `Synthetic Truth: TGT001 (SYNTH01)`
  - `Synthetic ADS-B-Compatible Truth: TGT001 (SYNTH01)`
- Make the legend wording consistent with the actual implementation:
  - target motion is user-defined synthetic truth
  - ADS-B-like structs are a compatibility format, not real recorded ADS-B data

### 3. Add a reusable synthetic IQ validation helper

- Add a reusable helper in `SyntheticHDTVSimulation`:

```matlab
validationSummary = helperSyntheticValidateGeneratedIQ(sessionArtifacts, opts)
```

- Call the helper from `SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m` after generation.
- Keep the helper reusable so later tests and real-data checks can call it directly.
- Return a structured summary rather than only producing figures.

### 4. Validate file and format integrity

- The helper should first perform basic `.bb` and manifest integrity checks:
  - header readback matches scenario config and manifest
  - sample rate is correct
  - center frequency is correct
  - part duration is correct
  - channel count is correct
  - IQ arrays are finite
  - IQ arrays are nonzero
  - surveillance and reference are not identical
- Report RMS and peak levels for both channels so clipping or degenerate scaling is visible.

### 5. Validate truth-to-IQ consistency

- This is the core confidence step and should be treated as required.
- Read the first generated radar part and analyze it using dwell sizing consistent with the downstream processor.
- Compute measured direct-path lag and compare it against `scenario_config.direct_path_delay_samples`.
- Build a first-chunk Range-Doppler map using the same `createRDM` path already used later in analysis.
- Use `truth_bundle.bistatic_tracks` to predict where each target should appear in the validation dwell.
- Overlay predicted target locations onto the validation RDM.
- Report residuals between:
  - predicted bistatic range excess and observed peak range
  - predicted bistatic Doppler and observed peak Doppler
- Do not make the truth overlay optional in this implementation phase. Without it, the RDM is illustrative but not evidentiary.

### 6. Keep the direct-path precheck, but make it mode-aware

- Reuse `BistaticDataAnalysis/runDirectPathPrecheck.m` because it already provides useful low-cost diagnostics.
- Treat its checks differently depending on seed type:
  - if the seed is real ATSC-like data or the probe seed with a planted pilot, pilot/coherence checks are authoritative
  - if the seed is a more generic seed waveform, pilot-specific checks should become advisory or be skipped
- Keep the generic checks active regardless of seed type:
  - lag dominance
  - channel consistency
  - zero-Doppler ridge behavior

### 7. Make the validation predictive of the real downstream pipeline

- Use the same CPI and chunking conventions the current processor uses in `BistaticDataAnalysis/processOnePart.m`.
- Ensure the cheap validation is not based on arbitrary dwell parameters that the real processor never sees.
- Add an analysis-readiness summary that reports:
  - range-bin spacing from sample rate
  - Doppler-bin spacing from the validation dwell
  - whether each target is sufficiently separated from the direct path and from other targets in range-Doppler space
- Surface the synthesis-side expected delay and Doppler ranges using `synthesis_summary.track_summaries` so the user can compare:
  - expected measurement-space location
  - measured measurement-space location

### 8. Add one deterministic confidence scenario

- Add a validation-oriented preset or walkthrough example that is intentionally easy to inspect:
  - one or two targets
  - longer part duration than the current `0.10 s` default
  - stochastic noise disabled by default
  - near-constant target Doppler over the validation dwell
- Keep the existing short default walkthrough available as a smoke test, but document that it is not the best case for visual trajectory interpretation or robust downstream validation.

### 9. Improve the walkthrough summary text

- Add a concise user-facing validation report to the walkthrough that answers:
  - Is the file formatted and readable correctly?
  - Does the measured direct path match the configured direct path?
  - Do synthetic targets appear near their predicted range-Doppler locations?
  - Is this session likely suitable for downstream pipeline evaluation?
- Keep the output concise and decision-oriented so a user can quickly decide whether to proceed to full analysis.

## Test Plan

### Preview semantics

- Run the walkthrough with the default short capture.
- Confirm the first preview tile clearly states that it shows sampled motion over the active window.
- Confirm the preview explains why motion may look nearly static for short captures.
- Confirm start and end markers are visible.

### Provenance labeling

- Confirm every user-facing preview label explicitly identifies the curves as synthetic truth or synthetic ADS-B-compatible truth.
- Confirm no preview legend relies on raw `SYNTH<>` text alone.

### Closed-loop IQ validation

- Generate a default session and verify the helper returns:
  - file/header integrity pass
  - measured direct-path lag versus configured lag
  - one first-chunk RDM with predicted truth overlay
  - per-target residuals in range and Doppler
- Confirm the helper returns a summary struct that can support later smoke tests.

### Mode-aware seed handling

- Run the validation on the synthetic probe seed and confirm pilot checks are treated as authoritative.
- Run the validation on a non-ATSC seed-backed case, if available, and confirm pilot-specific messaging becomes advisory rather than causing a false fail.

### Deterministic confidence case

- Run a low-noise deterministic scenario and confirm the target residuals are tight enough to show that the synthesis chain preserves truth through file writing and readback.

### Downstream relevance

- Confirm the validation dwell and chunking match `processOnePart` assumptions so the cheap validation is predictive of later analysis behavior.

## Assumptions and Defaults

- The current generator architecture is sound because the same truth bundle drives both preview products and echo synthesis.
- The main remaining risk is not scenario definition but preserving and recovering that truth through the written IQ artifacts and downstream read path.
- Preview-only changes improve usability but are insufficient on their own to justify downstream analysis work.
- `runDirectPathPrecheck` remains valuable, but pilot-specific checks must be conditioned on seed type.
- A truth-overlay RDM and numeric residual check are required to claim meaningful confidence in the synthetic dataset for downstream passive radar processing.
