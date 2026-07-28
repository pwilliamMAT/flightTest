# Next Session Handoff

Updated: July 28, 2026

## July 28, 2026 TestSetupTesting Sync And Pluto Review State

This session intentionally merged the FTC-overlaid TestSetupTesting snapshot with the newer `feature/pluto-tone-precheck-standalone` branch state. The FTC checksum manifest matched all 64 comparable `TestSetupTesting` source files in this checkout, with no differing or FTC-only source files.

Keep these local/source distinctions clear:

- `TestSetupTesting/plutoBaselineCommissioningFieldPlan.md` is a newer tracked branch file and should remain part of the field-test handoff.
- `TestSetupTesting/reviewPlutoToneCaptureSpectra.m` is the new local offline spectrum-review tool and should be added before the next push if we want the FTC to receive it.
- `PlutoHelloWorld.m` is still untracked and should be treated as scratch unless explicitly promoted.
- Generated run/capture outputs and FTC checksum artifacts should remain out of Git.

When pushing this branch back to GitHub, use the user's personal GitHub credentials rather than the MathWorks identity.

The first Phase 2B multitone smoke runner is now `TestSetupTesting/runPlutoMultitoneStage6Smoke.m`. It keeps the existing Pluto TX, N320 capture, and `.bb` readback helpers, but transmits the default 8-tone comb at `599 MHz / 8 MSps` and scores all tones on both channels. FTC command:

```matlab
cd('TestSetupTesting');
result = runPlutoMultitoneStage6Smoke('Verbose', true);
```

Treat the output as an experiment, not as the commissioned Phase 1 readiness gate. The key values are REF/SURV tone counts, median and integrated detect margins, and the median channel-to-channel frequency delta across tones.

The multitone scorer now defaults to `ScoringMode = "expected-bin"`. Plain-language reason: for a known comb, the planned tone offsets are the measurement locations. A single-tone peak search asks "what is the strongest nearby line?", which can be pulled away by a spur or another local spectral feature. Expected-bin scoring asks "how much evidence is present exactly where we emitted tones?", then integrates that evidence across the comb. The old search-peak path remains available with `'ScoringMode','search-peak'` and is still used as a joint channel-frequency diagnostic. In expected-bin mode, a search-peak channel mismatch is a warning; in search-peak mode, it remains a hard fail.

The first FTC multitone run found all 8 tones on both channels, but several near-center tones were weak or frequency-inconsistent. The synced-capture review gave:

- status `WARN`
- REF `8/8`, median margin `-0.9 dB`, integrated margin `+7.8 dB`
- SURV `8/8`, median margin `-2.9 dB`, integrated margin `+7.5 dB`
- joint median channel delta `701.9 Hz`
- problematic tones near `-50`, `+50`, and `+150 kHz`

Next recommended live multitone run:

```matlab
cd('TestSetupTesting');
result = runPlutoMultitoneStage6Smoke( ...
    'SessionID', "pluto_multitone_outer5", ...
    'CaptureFileBase', "pluto_multitone_outer5", ...
    'ToneOffsets_Hz', [-350 -250 -150 250 350] * 1e3, ...
    'Verbose', true);
```

That five-tone subset preserved the best channel-frequency agreement in the synced-capture replay while still retaining about `7 dB` ideal tone-integration gain.

The FTC ran that outer5 command before the expected-bin scorer update was pushed. The original console showed `FAIL` because the legacy CW-style search-peak margins were weak in REF:

- REF `5/5`, median margin `-3.3 dB`, integrated margin `+3.6 dB`
- SURV `5/5`, median margin `-1.4 dB`, integrated margin `+6.6 dB`
- joint median channel delta `61.0 Hz`
- fail code `REFERENCE_MULTITONE_WEAK`

After replaying the synced outer5 capture with expected-bin scoring, the same capture is a `WARN`, not a `FAIL`:

- REF `5/5`, median margin `+0.1 dB`, integrated margin `+7.0 dB`
- SURV `5/5`, median margin `+0.4 dB`, integrated margin `+7.3 dB`
- joint median channel delta `61.0 Hz` from the retained search-peak diagnostic
- warn codes `REFERENCE_MULTITONE_LOW_MARGIN`, `SURVEILLANCE_MULTITONE_LOW_MARGIN`

The FTC also ran an 11-tone comb before this scorer update:

```matlab
cd('TestSetupTesting');
result = runPlutoMultitoneStage6Smoke( ...
    'SessionID', "pluto_multitone_outer11", ...
    'CaptureFileBase', "pluto_multitone_outer11", ...
    'ToneOffsets_Hz', [-550 -450 -350 -250 -150 -50 50 250 350 450 550] * 1e3, ...
    'Verbose', true);
```

The original console showed `FAIL` because search-peak channel agreement had a `13061.5 Hz` median delta. Replaying the synced `outer11` capture with expected-bin scoring gives:

- status `WARN`
- REF `11/11`, median margin `-0.2 dB`, integrated margin `+10.4 dB`
- SURV `11/11`, median margin `-0.2 dB`, integrated margin `+10.4 dB`
- joint search-peak median channel delta `13061.5 Hz`
- warn codes `REFERENCE_MULTITONE_LOW_MARGIN`, `SURVEILLANCE_MULTITONE_LOW_MARGIN`, `MULTITONE_CHANNEL_FREQUENCY_DELTA_NEAR_LIMIT`

Interpretation: `outer11` gives the strongest integrated expected-bin evidence so far, but the broader comb also produces the worst nearby-peak ambiguity. Keep it as evidence that tone integration works; do not promote it over `outer5` until we add a better joint consistency metric than strongest-nearby-peak frequency agreement.

### CPI Integration Result

The next useful processing step is now checked in as `TestSetupTesting/reviewPlutoMultitoneCpiIntegration.m`. It treats each 10 ms CPI as one artificial pulse, extracts the complex FFT coefficient at each planned tone bin, and then evaluates:

- noncoherent tone-bin power integration across CPIs
- slow-time FFT peak integration, which allows residual phase rotation across CPIs
- comb-locked REF/SURV cross-channel coherence at the planned tone bins

Plain-language result: the static per-CPI tone-bin SNR is weak, but the tones are stable enough over slow time to gain useful integration. Across saved runs:

| Run | Tones | REF noncoh margin | SURV noncoh margin | REF slow-time peak | SURV slow-time peak | Median REF/SURV coherence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `outer5 original` | 5 | `+1.5 dB` | `+1.7 dB` | `+9.4 dB` | `+9.8 dB` | `0.815` |
| `outer5 repeat1` | 5 | `+1.3 dB` | `+1.5 dB` | `+8.4 dB` | `+8.7 dB` | `0.871` |
| `outer5 repeat2` | 5 | `+1.4 dB` | `+1.2 dB` | `+8.4 dB` | `+8.5 dB` | `0.763` |
| `outer11` | 11 | `+1.4 dB` | `+1.5 dB` | `+9.3 dB` | `+8.6 dB` | `0.695` |

Interpretation: stop spending field time changing comb definitions for now. The next algorithmic milestone is a comb-locked slow-time detector that integrates the expected tone-bin coefficients across CPIs and searches slow-time frequency, rather than scoring one whole-capture spectrum or using strongest-nearby-peak agreement.

That first detector prototype is now `TestSetupTesting/runPlutoMultitoneSlowTimeDetector.m`. It sums normalized slow-time spectra across the comb and ranks joint REF/SURV slow-time candidates. Results on the saved captures:

| Run | Tones | Peak slow-time bin | Joint peak contrast | REF at peak | SURV at peak |
| --- | ---: | ---: | ---: | ---: | ---: |
| `outer5 original` | 5 | `+0.95 Hz` | `+5.5 dB` | `+6.3 dB` | `+7.5 dB` |
| `outer5 repeat1` | 5 | `-45.71 Hz` | `+4.6 dB` | `+6.3 dB` | `+5.4 dB` |
| `outer5 repeat2` | 5 | `+45.71 Hz` | `+3.7 dB` | `+5.7 dB` | `+3.8 dB` |
| `outer11` | 11 | `-14.29 Hz` | `+2.4 dB` | `+4.2 dB` | `+3.3 dB` |

Interpretation: a common slow-time bin across all tones is not yet stable enough to be the final detector. The per-tone slow-time FFT peaks show integration gain, but the comb does not add coherently at one common slow-time frequency. The next processing step should estimate and compensate per-tone residual slow-time frequency, likely from Pluto/N320 sample-clock or frequency-offset mismatch, before summing tones.

The detector now includes that first compensation step: it finds the joint REF/SURV slow-time peak independently for each tone, then combines those tonewise peaks. This is not a final passive-radar detector, but it is the correct diagnostic for the current multitone injection problem.

`outer9` was run with tone offsets `[-550 -450 -350 -250 -150 150 250 350 450] kHz`. It produced strong expected-bin evidence:

- REF `9/9`, integrated margin `+9.5 dB`
- SURV `9/9`, integrated margin `+9.7 dB`
- search-peak median channel delta `2868.7 Hz`
- status `WARN`

Detector comparison after replay:

| Run | Tones | Common-bin contrast | Tonewise compensated contrast | Tonewise peak-frequency std |
| --- | ---: | ---: | ---: | ---: |
| `outer5 original` | 5 | `+5.5 dB` | `+10.0 dB` | `16.5 Hz` |
| `outer5 repeat1` | 5 | `+4.6 dB` | `+8.3 dB` | `36.4 Hz` |
| `outer5 repeat2` | 5 | `+3.7 dB` | `+8.2 dB` | `24.2 Hz` |
| `outer9` | 9 | `+2.7 dB` | `+7.4 dB` | `24.1 Hz` |
| `outer11` | 11 | `+2.4 dB` | `+7.8 dB` | `25.7 Hz` |

Interpretation: per-tone residual compensation is required. Adding more tones improves whole-capture expected-bin evidence, but it does not improve the current detector unless the per-tone residuals are handled. `outer5` remains the cleanest detector candidate; `outer9` is a useful middle point because it has strong tone evidence and less peak-search ambiguity than `outer11`.

Next FTC pull should pick up the scorer update before any additional multitone run:

```bash
git pull --ff-only origin feature/pluto-tone-precheck-standalone
```

### Repeatability Batch

Use `TestSetupTesting/runPlutoMultitoneRepeatabilityBatch.m` to run repeated captures plus analysis on the FTC without copying the large `.bb` files back. The default comb is 11 tones spaced 100 kHz from `-500 kHz` to `+500 kHz`.

FTC command for the requested 20-run repeatability batch:

```bash
matlab -batch "cd('TestSetupTesting'); batch = runPlutoMultitoneRepeatabilityBatch('RepeatCount',20,'BatchID','pluto_outer11_100khz_repeat20','SessionPrefix','pluto_outer11_100khz','ToneOffsets_Hz',(-500:100:500)*1e3,'PlotFigures',true,'Verbose',true);"
```

Copy back the analysis folder, not the `.bb` capture files:

```text
captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat20_analysis/
```

The most important file is:

```text
batch_summary.csv
```

Each run also has `expected_bin_review/`, `cpi_integration_review/`, and `slow_time_detector/` subfolders with `summary.txt`, `result.mat`, and PNG plots.

### Calibration Baseline And Check

The first calibration-health-check wrappers are now:

- `TestSetupTesting/runPlutoMultitoneCalibrationBaseline.m`
- `TestSetupTesting/runPlutoMultitoneCalibrationCheck.m`

Plain-language workflow:

1. Commission a golden baseline from known-good repeatability runs.
2. Save the golden metrics, waveform settings, hardware settings, thresholds, summary CSV, MAT file, and PNG plot.
3. Run periodic checks with the same waveform/settings.
4. Compare current metrics against baseline medians and report `PASS`, `WARN`, or `FAIL`.

The offline replay path is implemented first. It was verified locally by commissioning a two-run `outer5` baseline from saved captures and checking `outer5_repeat2`; the check passed with all metric drifts inside thresholds.

After the 20-run FTC batch finishes, commission a baseline from its compact summary CSV:

```bash
matlab -batch "cd('TestSetupTesting'); baseline = runPlutoMultitoneCalibrationBaseline('RunSources','../captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat20_analysis/batch_summary.csv','BaselineID','pluto_outer11_100khz_golden','ToneOffsets_Hz',(-500:100:500)*1e3,'PlotFigures',true,'Verbose',true);"
```

To check an already-saved capture against that baseline:

```bash
matlab -batch "cd('TestSetupTesting'); check = runPlutoMultitoneCalibrationCheck('BaselinePath','../captures/plutoMultitoneCalibrationBaselines/pluto_outer11_100khz_golden/baseline.mat','CheckSource','../captures/plutoMultitoneSmoke/SOME_CAPTURE_PART1','PlotFigures',true,'Verbose',true);"
```

To run a live check against that baseline, omit `CheckSource`:

```bash
matlab -batch "cd('TestSetupTesting'); check = runPlutoMultitoneCalibrationCheck('BaselinePath','../captures/plutoMultitoneCalibrationBaselines/pluto_outer11_100khz_golden/baseline.mat','PlotFigures',true,'Verbose',true);"
```

Current threshold policy is intentionally conservative and baseline-relative. It warns/fails on drops in expected-bin integrated margin, slow-time peak margin, tonewise detector contrast, REF/SURV coherence, or increases in tonewise peak-frequency spread.

## July 24, 2026 Pluto Phase 1 Commissioning Sweep Recovery

This is the current Pluto handoff and should be treated as the top starting point before any new hardware work. The July 24 Phase 1 session recovered the commissioning-sweep summary, promoted the Live Editor notebook to the main verification artifact, and narrowed the next hardware step to a geometry-only follow-up.

### What Is Complete

- `TestSetupTesting/reviewPlutoToneCommissioningSweep.m` is checked in and can rebuild the ranked sweep summary from saved `runs/*/result.mat` artifacts without rerunning hardware.
- `TestSetupTesting/PlutoPhase1ValidationLive.m` is now the primary Phase 1 verification entrypoint for both human review and future agentic sessions.
- The notebook records:
  - unit-test and Stage 6 smoke-test execution blocks
  - the accumulated Stage 6 field-trial matrix
  - the recovered fixed-placement commissioning-sweep review for `stairwell_outside_box_nooelec_4p9in`
  - the next recommended fixed-waveform placement and orientation matrix
- `README.md` and `TestSetupTesting/README.md` now point operators to that notebook and to the recovery helper.
- `concepts.md` indexes the Phase 1 validation notebook, the commissioning-sweep workflow, the baseline field plan, and the new capture spectrum review.

### What The Recovered Sweep Established

- The recovered July 24, 2026 fixed-placement sweep ranked every tested configuration as `WEAK`.
- The least-bad diagnostic point was `599 MHz / 250 kHz / ToneAmplitude 0.50`.
- That top-ranked point still had median minimum detect margin `-5.15 dB` and median inter-channel frequency delta `2655 Hz`.
- Both channels found the tone in every recovered configuration, so the Pluto-to-USRP path and the frozen channel mapping still look alive.
- Raising amplitude did not rescue this placement, and higher-amplitude rows often ranked worse.
- Levels stayed near `-10 dBFS`, so clipping does not look like the dominant problem in this sweep.
- No reusable baseline should be commissioned from that recovered sweep.

### Current Engineering Position

- Phase 1 remains the authoritative standalone tone-based readiness gate.
- Phase 2 archived-capture analysis remains separate and should not replace the Phase 1 gate.
- Do not spend the next session on another amplitude-only commissioning sweep.
- Treat installation geometry, nearby metal, local multipath, polarization, or receive-side conditions as the leading causes of the remaining gap.
- Use `TestSetupTesting/PlutoPhase1ValidationLive.m` as the primary notebook for review, reruns, and later handoff narratives.

### Next Recommended Hardware Step

Freeze the waveform at `599 MHz / 8 MSps / LO 0 / gain 30,50 / tone 250 kHz / amp 0.50 / 1 s` and run this small placement matrix before attempting another commissioning sweep:

1. Repeat the current practical permanent setup once as the same-day reference.
2. Move the radiator and feed `10` to `20` inches away from nearby metal while keeping polarization unchanged.
3. Keep the best location from step 2 and rotate the radiator by `90` degrees.
4. Try the same chain at the clearest temporary exposure near or just outside the stairwell opening.

Decision rule:

- If one geometry change materially improves both the minimum detect margin and the inter-channel delta, rerun that winning geometry and only then consider a new commissioning sweep.
- If none of the geometry changes materially help, shift the next investigation toward the receive-side antenna chain or the local RF environment rather than more Pluto waveform sweeps.

### Constraints That Must Carry Forward

- Keep the Pluto on the short USB cable.
- Do not use the long micro-USB extension; it previously made Pluto undiscoverable.
- Move only the antenna and feed when possible, not the Pluto body.
- Keep the frozen Phase 1 mapping `RF0:RX2 -> CH1 / RX1 -> SURV` and `RF1:RX2 -> CH2 / RX2 -> REF`.
- The raw recovered sweep folder `/home/pat/Documents/flightTest-pluto/TestSetupTesting/TestSetupTesting/plutoCommissioningSweeps/pluto_tone_commissioning_20260724T205841` is referenced by the notebook but is not present in this Windows repo checkout.

### Files That Define The Current Pluto State

- `TestSetupTesting/PlutoPhase1ValidationLive.m`
- `TestSetupTesting/README.md`
- `README.md`
- `TestSetupTesting/plutoBaselineCommissioningFieldPlan.md`
- `TestSetupTesting/reviewPlutoToneCommissioningSweep.m`
- `TestSetupTesting/reviewPlutoToneCaptureSpectra.m`
- `TestSetupTesting/runPlutoToneCommissioningSweep.m`
- `concepts.md`

The older sections below are preserved for background, but they are not the current Pluto top-priority handoff.

## July 10, 2026 ATSC Pilot Audit Status Correction

This section corrects the current status of the ATSC pilot-audit upgrade.

### What Is Actually Complete

- The implementation work is present in the current worktree.
- Automated verification completed:
  - `BistaticDataAnalysis/tests/ATSCPilotAuditTest.m`
  - `BistaticDataAnalysis/test_rfQualityAudit.m`
  - `BistaticDataAnalysis/runATSCPilotAuditValidation.m` on session `20260622T102123`
- Manual review update:
  - the top spectrum / pilot-evidence figure has now been reviewed on real capture data
  - the selected PSD peak on the normal side was confirmed by the operator to land on the expected ATSC pilot tone
  - that manual check should be treated as evidence that the new PSD-first selector is behaving correctly on the reference spectrum

### What Is Not Complete

- Full manual review has **not** been completed yet.
- Do **not** treat the ATSC pilot-audit upgrade as fully manually verified.
- The required pending review is:
  - run the revised precheck with figures enabled on at least parts `1` and `5`
  - confirm the bottom stability panel and the figure-level HOLD/CONTINUE summary match the returned structured outputs
  - confirm the same PSD-first pilot-selection behavior remains sensible on more than one part

### Next Action

- The next session should begin with the remaining manual review of the stability panel and multi-part figure summaries before claiming the ATSC pilot-audit work is fully verified.

## June 26, 2026 Toolbox Replacement-Assessment Handoff

This is now the top-priority handoff. The goal for the next session is not to migrate the production workflow to toolbox TDOA or toolbox CFAR. The goal is to tighten the replacement assessment, keep the offline benchmark harness useful, and only continue toolbox TDOA work if a narrow localized refinement path shows materially better cost.

### Current Engineering Position

- The supported production workflow remains the custom CAF/RDM detector plus custom measurement extraction.
- `phased.TDOAEstimator` produced numeric delay estimates on the captured replay, but it was too slow to act as a per-detection replacement for the current custom range-delay path.
- `phased.CFARDetector2D` was also slower on the tested offline replay cases.
- The detailed write-up now lives in `BistaticDataAnalysis/toolboxReplacementAssessment.md`.
- `README.md` now includes a short toolbox-evaluation status section that points to that memo.

### Evidence Already Established

- Evidence base:
  - captured session: `BistaticDataAnalysis/captures/20260622T102123`
  - replay snapshot: `BistaticDataAnalysis/detector_replay_20260622T102123.mat`
  - benchmark artifacts:
    - `BistaticDataAnalysis/bench_20260622T102123.mat`
    - `BistaticDataAnalysis/bench_20260622T102123.log`
    - `BistaticDataAnalysis/bench_full_20260622T102123_snapshot.mat`
    - `BistaticDataAnalysis/bench_full_20260622T102123_snapshot.log`
    - `BistaticDataAnalysis/bench_tdoa_20260622T102123.mat`
    - `BistaticDataAnalysis/bench_tdoa_20260622T102123.log`
    - `BistaticDataAnalysis/tdoa_probe_20260622T102123.mat`
    - `BistaticDataAnalysis/tdoa_probe_20260622T102123.log`
- Measured runtime facts:
  - full replay toolbox TDOA probe: `1489.625 s` for `434` detections, about `3.432 s/detection`
  - sparse profiler slice: part `7`, `8` detections, `42.415 s` total, `TDOAEstimator.stepImpl = 40.376 s`
  - hotspot profiler slice: part `6`, block `4`, first `20` detections from a `98`-detection block, `73.737 s` total, `TDOAEstimator.stepImpl = 72.414 s`
  - full-session custom baseline: `32.613 s`
  - full-session toolbox CFAR: `882.480 s`
  - full-scope replay-snapshot toolbox attempts hit `Out of memory.` after `682.200 s` and `742.220 s`
- Hotspot structure in the replay:
  - part `6` contains `240` detections
  - the densest blocks are part `6` block `4` with `98` detections and part `6` block `3` with `93` detections
- Engineering conclusion already supported by the profiler:
  - the dominant cost sits inside toolbox internals such as `TDOAEstimator.stepImpl`, `tdoaspectrum`, `tdoagccphat`, and peak search
  - this is not primarily a wrapper inefficiency

### What Must Not Change Next Session

- Do not change the supported production wrapper behavior in this cycle.
- Do not present toolbox TDOA as the likely future production front end.
- Keep new controls benchmark-only and offline-only.
- Do not rerun a full-session toolbox TDOA replacement attempt unless narrow slices first show a real reduction in per-call cost.

### Next-Session Goal

1. Add enough benchmark scoping to isolate exact sparse and hotspot slices cleanly.
2. Add explicit run labeling so evidence is clearly separated into:
   - `replacement_assessment`
   - `localized_refinement_experiment`
3. Test whether local-support cropping around the CAF-derived delay guess reduces toolbox TDOA cost materially.
4. Decide whether toolbox TDOA remains closed as a replacement no-go, or whether a narrow localized refinement experiment is justified.

### Concrete Work Plan

#### Stage 1: Tighten Offline Assessment Controls

Files most likely involved:

- `BistaticDataAnalysis/runOfflineToolboxBenchmark.m`
- `BistaticDataAnalysis/helperRestrictDetectorReplayInput.m`
- `BistaticDataAnalysis/tests/OfflineToolboxBenchmarkTest.m`

Implement benchmark-only scoping that is more precise than the current `PartIndices` + `MaxBlocksPerPart` limit:

- add exact block selection support, for example `BlockNumbers` or `BlockNumbersByPart`
- add a benchmark-only detection cap, for example `MaxDetectionsPerBlock` or `MaxDetectionsTotal`
- preserve the existing summary-table shape and carry the applied scope metadata into the output struct

Reason:

- the current helper can limit to the first `N` blocks of a part, but it cannot cleanly isolate hotspot block `4` in part `6`
- the next assessment needs exact sparse and hotspot slices, not broad part-level reruns

#### Stage 2: Add Explicit Assessment Labels

Files most likely involved:

- `BistaticDataAnalysis/runOfflineToolboxBenchmark.m`
- `BistaticDataAnalysis/plotOfflineToolboxBenchmarkSummary.m`
- optionally the saved benchmark output struct fields and figure titles

Add an explicit label or mode field with allowed values:

- `replacement_assessment`
- `localized_refinement_experiment`

Propagate that label into:

- the returned benchmark struct
- figure titles
- console/log output

Reason:

- the repo should stop treating all toolbox runs as generic `benchmarking`
- the next session needs to separate replacement viability evidence from any narrow refinement experiment

#### Stage 3: Test Local-Support TDOA Inputs

Files most likely involved:

- `BistaticDataAnalysis/helperEstimateToolboxTDOARange.m`
- `BistaticDataAnalysis/helperApplyToolboxTDOARefinement.m`
- `BistaticDataAnalysis/tests/OfflineToolboxBenchmarkTest.m`

Implement a benchmark-only path that crops the reference/surveillance support around the existing CAF-derived delay guess before calling `phased.TDOAEstimator`.

Constraints:

- keep the current full-support path available for comparison
- do not change the production detector or supported measurement workflow
- keep the crop controlled by an explicit option so the experiment is easy to turn on and off

Reason:

- the only plausible near-term technical value left for toolbox TDOA is narrow local refinement, not full replacement
- the next session needs hard evidence about whether local support reduces cost enough to matter

#### Stage 4: Run Two Bounded Assessment Slices

Use the captured replay `detector_replay_20260622T102123.mat`.

Run at least these two slices after the new controls exist:

1. Sparse slice:
   - part `7`
   - all detections in that part
   - `RunTruthDiagnostics = false`
   - label as `replacement_assessment`
2. Hotspot slice:
   - part `6`
   - exact block `4`
   - cap at `20` detections initially
   - `RunTruthDiagnostics = false`
   - label as `replacement_assessment`

For each slice, compare:

- current full-support toolbox TDOA path
- local-support cropped toolbox TDOA path
- total runtime
- per-detection runtime
- top profiler hotspots

#### Stage 5: Decide Whether To Stop Or Narrow Further

Decision gate:

- if runtime stays on the order of seconds per detection and profiler time still stays overwhelmingly inside `TDOAEstimator.stepImpl`, stop the replacement path and update the memo with the strengthened evidence
- only if the cropped local-support path shows a material drop in cost should the next session proceed to a `localized_refinement_experiment`

Recommended bar before any wider rerun:

- roughly an order-of-magnitude improvement from the current hotspot cost, or at minimum something near sub-second per-detection behavior on the hotspot slice

If that bar is not met:

- do not rerun full-session toolbox TDOA
- do not broaden toolbox CFAR work beyond offline parity characterization

### Suggested MATLAB Commands After Stage 1 And Stage 2

Sparse slice:

```matlab
cd BistaticDataAnalysis

bench_sparse = runOfflineToolboxBenchmark( ...
    'detector_replay_20260622T102123.mat', ...
    'Variants', {'toolbox_tdoa'}, ...
    'AssessmentMode', 'replacement_assessment', ...
    'PartIndices', 7, ...
    'RunTruthDiagnostics', false, ...
    'PlotSummary', false, ...
    'Verbose', true);
```

Hotspot slice:

```matlab
cd BistaticDataAnalysis

bench_hot = runOfflineToolboxBenchmark( ...
    'detector_replay_20260622T102123.mat', ...
    'Variants', {'toolbox_tdoa'}, ...
    'AssessmentMode', 'replacement_assessment', ...
    'PartIndices', 6, ...
    'BlockNumbers', 4, ...
    'MaxDetectionsPerBlock', 20, ...
    'RunTruthDiagnostics', false, ...
    'PlotSummary', false, ...
    'Verbose', true);
```

These examples assume the next session adds the missing `AssessmentMode`, exact block selection, and detection-cap controls.

### Files Likely To Be Touched Next Session

- `BistaticDataAnalysis/runOfflineToolboxBenchmark.m`
- `BistaticDataAnalysis/helperRestrictDetectorReplayInput.m`
- `BistaticDataAnalysis/helperEstimateToolboxTDOARange.m`
- `BistaticDataAnalysis/helperApplyToolboxTDOARefinement.m`
- `BistaticDataAnalysis/tests/OfflineToolboxBenchmarkTest.m`
- `BistaticDataAnalysis/toolboxReplacementAssessment.md`
- `README.md`
- `NEXT_SESSION_HANDOFF.md`

### Success Criteria For The Next Session

- the benchmark harness can isolate exact sparse and hotspot slices
- assessment outputs are explicitly labeled as `replacement_assessment` or `localized_refinement_experiment`
- local-support cropping is benchmarked against the current full-support toolbox TDOA path
- the repo has a clear decision, backed by measured evidence, on whether any toolbox TDOA work should continue beyond narrow refinement experiments

### Secondary References

- `BistaticDataAnalysis/toolboxReplacementAssessment.md`
- `README.md` toolbox evaluation section
- `BistaticDataAnalysis/tests/OfflineToolboxBenchmarkTest.m`

## June 22, 2026 RF Gain-Sweep Handoff

This section is preserved for background. It is no longer the top-priority handoff.

### Current RF Blocker

- Session `20260618T160532` was audited with `runSessionRFQualityAudit` and did not clear the RF sufficiency bar for `aircraft_detection`.
- Key summary fields from that audit:
  - `overall_pass_fraction = 0`
  - `reference_pass_fraction = 0`
  - `level_pass_fraction = 1`
  - `pilot_pass_fraction = 0`
  - `lag_pass_fraction = 1`
  - `zero_doppler_pass_fraction = 0.6`
  - `pilot_freq_span_hz = 5.676e6`
  - `any_pilot_mirrored = true`
  - `sufficient_for_goal = false`
- Interpretation:
  - the direct path is present and lag-isolated
  - the blocker is weak or inconsistent coherent pilot quality on the reference chain
  - ECA-C suppression is only partially consistent after cancellation
  - raw channel-power asymmetry is not a valid failure signal by itself on this hardware

### Hardware Context That Must Carry Forward

- `RX0 / CH1`: surveillance antenna is an HDTV Yagi with a built-in amplifier
- `RX1 / CH2`: reference antenna is a small telescoping omni with no amplifier
- Because of that hardware split:
  - `CH1` being materially stronger than `CH2` is expected
  - do not use power asymmetry alone to argue for a channel swap
  - raising SDR gain on the reference channel is a valid bounded test
  - a reference-side LNA / amplifier is still an in-scope hardware fix if coherence stays weak

### Gain Sweep Already Performed By The Operator

- The user has already run three coordinated capture sessions with fixed surveillance gain and stepped reference gain:
  - `--gain 28,48`
  - `--gain 28,54`
  - `--gain 28,60`
- The outputs and session IDs from those runs had not yet been shared in-thread at the time this handoff was written.

### What The Next Agent Should Do When Sweep Outputs Arrive

1. Map each gain setting to its packaged session ID.
2. For each session, run the RF audit and capture both summary and per-part metrics:

```matlab
cd BistaticDataAnalysis

rf = runSessionRFQualityAudit('<session_id>', ...
    'Goal', 'aircraft_detection');

rf.summary
rf.assessment
rf.part_table(:, {'part_index','level_dbfs','pilot_snr_db','pilot_pass', ...
    'pilot_freq_hz','pilot_mirrored','lag_pass','suppression_db', ...
    'after_margin_db','after_margin_pass','zero_doppler_pass', ...
    'overall_pass'})
```

3. If the actual HDTV illuminator center frequency is known, pass the same explicit `IlluminatorCenterFrequencyHz` for every compared session so the pilot search uses the same channel geometry across the sweep.
4. Compare the sweep primarily on:
  - `pilot_snr_db`
  - `pilot_pass_fraction`
  - `pilot_freq_span_hz`
  - `any_pilot_mirrored`
  - `zero_doppler_pass_fraction`
  - `after_margin_pass_fraction`
  - `sufficient_for_goal`
5. Treat `level_dbfs` as secondary. A healthier ADC level does not matter if pilot evidence and pilot-frequency consistency stay poor.

### Expected Interpretations

- If higher reference gain materially improves pilot evidence and frequency consistency, SDR gain was part of the problem.
- If `level_dbfs` rises but `pilot_pass_fraction` stays near zero and the pilot remains mirrored or unstable, more SDR gain alone is not enough and the next step is hardware:
  - reference-side LNA / preamplifier
  - better reference antenna
  - better reference antenna placement / aim
- If `60 dB` improves pilot metrics but worsens residual ridge cleanup or stability, do not assume max gain is best. Pick the lowest gain that improves coherence without degrading the post-ECA residual.

### Relevant Files

- `BistaticDataAnalysis/runDirectPathPrecheck.m`
- `BistaticDataAnalysis/runSessionRFQualityAudit.m`
- `BistaticDataAnalysis/summarizeRFQualityAudit.m`
- `TestSetupTesting/run_coordinated_hdtv_capture.sh`
- `TestSetupTesting/runLocalHDTVCapture.m`

## June 18, 2026 Review Handoff

This file is superseded by the new review-oriented test and validation record at `BistaticDataAnalysis/adsbTruthFixTestPlan.md`.

### Current Status

- The ADS-B truth convention patch is now implemented locally.
- Shared conventions are unified around:
  - `R_excess = R_tx + R_rx - L_3D`
  - `f_D = -(fc/c) * dR_excess/dt`
  - `Rdot = -f_D / (fc/c)`
  - `range_cell_m = c/fs`
- Shared helper functions were added so truth conversion, tracker initialization, track-history export, and display code all use the same formulas.
- `createRDM.m` was also corrected to report Doppler at the true FFT-bin centers instead of an endpoint-inclusive `linspace`, because the old axis did not match the actual detector bins.

### Verification Completed On This Machine

- `bistaticTruthConventionTest.m`: `6/6` passed
- `runDetectorReplaySweepTest.m`: `3/3` passed
- `test_bistaticHelpers.m`: passed
- `test_adsbTruthPipeline.m`: passed
- MATLAB Code Analyzer clean on the touched convention/helper files

### Validation Still Blocked Locally

- The packaged session data is not present on this machine:
  - `captures/` does not exist
  - `captures/20260616T160702` does not exist
- Because of that, the required real-data timing A/B rerun remains outstanding and must still be run on the development machine.

### Required Development-Machine Validation

Run both timing modes on session `20260616T160702`:

```matlab
cd BistaticDataAnalysis

clear functions
out_meta = runBistaticAnalysisSession('20260616T160702', ...
    'Verbose', true, ...
    'PartTimingSource', 'metadata');

clear functions
out_fallback = runBistaticAnalysisSession('20260616T160702', ...
    'Verbose', true, ...
    'PartTimingSource', 'fallback');
```

Compare at minimum:

- `n_tp`
- `n_fa`
- `n_miss`
- track-level range and Doppler bias / RMSE
- output against the pre-patch reference log `C:\Users\pwilliam\agenticProjects\bistaticOutput.txt`

### Code Review Focus

- Review `createRDM.m` carefully. The Doppler-axis correction is the only detector-side behavior change discovered during regression.
- Review the new shared helpers and confirm all shared truth/tracker conversions use them.
- Treat `plotBistaticEllipses3D.m` as visualization-only. It now uses the shared 3D baseline scalar, but the fixed-altitude contour drawing still uses horizontal midpoint/bearing as an approximation.

## New Pending Fix Checklist

- A dedicated implementation checklist now lives at `BistaticDataAnalysis/adsbTruthFixChecklist.md`.
- That file is now the current source of truth for the next session:
  - locally completed convention fixes are checked off
  - remaining real-data timing and validation tasks are left open
  - the next agent should start at the pending rerun items, not re-open the local convention patch by default

## Current Status

- Work is split across two machines:
  - this machine: code changes and local MATLAB unit/synthetic validation
  - development machine: real replay runs against the actual packaged session and replay snapshot
- Detector/truth replay fix implemented locally:
  - truth matching now derives range and Doppler bin spacing from saved detector axes when available
  - replay truth bundles are refreshed from detector axes before scoring
  - this fix is in detector/truth replay code only, not tracker behavior
- Development-machine result so far:
  - a looser truth-gate replay run now produces at most `n_tp = 2` out of `216` visible truth samples
  - detector sensitivity sweeps still inflate false alarms much faster than they improve truth hits
  - interpretation: CFAR sensitivity is not the main bottleneck
  - likely causes are:
    - weak surveillance-channel SNR before CFAR
    - a systematic range, Doppler, or timing offset
    - or an `fc` mismatch between the actual capture and the truth projection
- New operator note from June 16:
  - the surveillance antenna in this dataset may have been tuned near `978 MHz`
  - the passive-radar collection band for this workflow is normally HDTV around `540-600 MHz`
  - if true, that antenna mismatch is a credible front-end cause of poor target detectability
  - the replay logs for this run show `adsbToBistatic` using `fc = 540 MHz`, so verify the actual capture center frequency before making more Doppler-based conclusions

## Development-Machine Result So Far

The latest looser truth-gate sweep reported:

- `baseline`: `n_detections = 305`, `n_tp = 0`
- `pfa3e4`: `n_detections = 1273`, `n_tp = 0`
- `pfa1e3`: `n_detections = 5854`, `n_tp = 2`
- `os065`: `n_detections = 3439`, `n_tp = 1`
- `os060`: `n_detections = 8952`, `n_tp = 2`
- `ca_baseline`: `n_detections = 10180`, `n_tp = 2`

Interpretation:

- loosening CFAR can recover an occasional truth hit
- but the best case is still only `2 / 216` visible truth samples
- the dominant effect of looser CFAR is false-alarm growth, not meaningful Pd improvement

This still suggests the next step should be baseline truth/detection inspection plus RF/frequency verification, not more broad CFAR sweeps.

## Validation Already Done On This Machine

- `runDetectorReplaySweepTest` passed: 3/3 tests
- `test_adsbTruthPipeline.m` passed
- MATLAB Code Analyzer passed on:
  - `BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m`
  - `BistaticDataAnalysis/runDetectionTruthDiagnostics.m`
  - `BistaticDataAnalysis/runDetectorReplaySweep.m`
- `README.md` was updated with replay truth-grid notes

## Immediate Next Step Tomorrow

Assuming the latest code is already synced to the development machine, do these checks in order on the development machine.

1. Verify the actual capture center frequency against the truth bundle:

```matlab
r = replay;   % or replay_loose / whatever variable holds the finished run
b = r.case_results(1);   % baseline case

b.truth_diag_output.truth_diag_input.fc
b.truth_diag_output.truth_diag_input.range_cell_m
b.truth_diag_output.truth_metrics.gate_range_m
b.truth_diag_output.truth_metrics.gate_doppler_hz
```

2. Keep using the baseline case for truth/detection inspection and collect:

```matlab
s = b.truth_diag_output.check_summary;
[s.n_aircraft_overlap s.n_truth_visible_samples s.n_truth_samples_in_display ...
 s.n_detections s.n_tp s.n_fa s.n_miss]
s.per_part_truth_points
s.per_part_detection_counts
```

Also capture:

- a screenshot of the baseline detection-vs-truth figure
- the baseline console output around `runDetectionTruthDiagnostics`
- the actual capture metadata that confirms whether this session was centered near `540 MHz` or `600 MHz`
- any notes about which antenna was connected to the surveillance channel during this session

Those outputs should determine whether the next debugging pass is:

- RF front-end mismatch
- alignment / timing / geometry
- or detector localization near the expected truth loci

## Recommended Fast Workflow Tomorrow

Use one baseline case with truth enabled for diagnosis:

```matlab
baseline = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases(1), ...
    'GateRangeCells', 5, ...
    'GateDopplerBins', 5, ...
    'TimeGateS', 0.5, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);
```

Use detector-only screening for broad parameter sweeps:

```matlab
screen = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'RunTruthDiagnostics', false, ...
    'PlotCases', [], ...
    'PlotDetectionTimeSeries', false, ...
    'PlotRDMOverlays', false, ...
    'Verbose', false);
```

Then truth-score only 1-2 selected cases:

```matlab
followup = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases([1 3]), ...
    'GateRangeCells', 5, ...
    'GateDopplerBins', 5, ...
    'TimeGateS', 0.5, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);
```

## Why Replay Sweeps Are Slow

Current replay runtime scales roughly with:

- number of detector cases
- multiplied by number of saved detector blocks

And when truth scoring is enabled, each case also repeats:

- ADS-B load
- bistatic projection
- truth alignment
- detection-vs-truth scoring

That is why:

- one-case truth runs are the right diagnostic tool
- broad sweeps should usually run with `RunTruthDiagnostics = false`

## Likely Next Code Change If Runtime Is Still Too Slow

If replay iteration is still too slow after the workflow above, the next useful code change is:

- add `PartIndices` or time-window support to `runDetectorReplaySweep`

or:

- cache ADS-B load, projection, and alignment once per replay instead of recomputing them for every case

## Touched Files This Session

- `BistaticDataAnalysis/buildDetectionTruthDiagnosticInput.m`
- `BistaticDataAnalysis/runDetectionTruthDiagnostics.m`
- `BistaticDataAnalysis/runDetectorReplaySweep.m`
- `BistaticDataAnalysis/test_adsbTruthPipeline.m`
- `BistaticDataAnalysis/assessTruthVsDetections.m`
- `README.md`
- `NEXT_SESSION_HANDOFF.md`

## Open Questions

- Is the actual capture center frequency for this session `540 MHz`, `600 MHz`, or something else?
- Was the surveillance antenna really tuned near `978 MHz` during this capture, and if so how much surveillance-channel SNR was lost?
- Does the real baseline replay show truth samples inside the displayed measurement space?
- Are detections broadly scattered away from truth, or clustered with a systematic offset?
- Is the next step RF hardware correction or alignment/timing/geometry calibration rather than more CFAR tuning?
