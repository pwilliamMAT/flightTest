# Pluto Baseline Commissioning Field Plan

This document is the operator-facing prescription for the next Pluto hardware session on the testing machine.

Current situation in plain language:

- The Pluto-to-USRP path is alive.
- The recovered July 24, 2026 fixed-placement commissioning sweep did **not** produce a baseline-worthy candidate.
- The least-bad diagnostic point was `599 MHz / 250 kHz / ToneAmplitude 0.50`.
- The next session should not begin with another broad amplitude sweep.
- The next session should isolate geometry and receive-chain effects first, then gather a clean repeated-run dataset for baseline commissioning.

This plan is meant to be used at the testing machine when you can physically move hardware and run MATLAB.

## Frozen Run Settings For This Session

Unless a later decision step in this document explicitly says otherwise, keep these settings fixed for every exploratory run:

- `CenterFrequency_Hz = 599e6`
- `SampleRate_Hz = 8e6`
- `LOOffset_Hz = 0`
- `Gain = [30 50]`
- `ToneOffset_Hz = 250e3`
- `ToneAmplitude = 0.50`
- `CaptureDuration_s = 1`

Carry forward these physical constraints:

- Keep the Pluto on the short USB cable.
- Do **not** use the long micro-USB extension.
- Move only the antenna and feed when possible, not the Pluto body.
- Keep the frozen Phase 1 mapping:
  - `RF0:RX2 -> CH1 / RX1 -> SURV`
  - `RF1:RX2 -> CH2 / RX2 -> REF`

## MATLAB Session Setup

Open MATLAB from the repo root and run this once before starting the field procedure:

```matlab
repoRoot = pwd;
testRoot = fullfile(repoRoot, "TestSetupTesting");
addpath(testRoot);
```

## Native Function Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Run a frozen-waveform Pluto-to-USRP geometry matrix | Existing repo Stage 6 runner `runPlutoToneStage6Smoke` | Keep all waveform and gain settings fixed and change only the physical geometry between runs |
| Capture Pluto-off receive background at the same settings | Existing repo capture wrapper `runLocalHDTVCapture` plus `comm.BasebandFileReader` readback | Leave Pluto TX off so the local floor and any narrow interferers near the expected tone can be checked without changing the receive chain |
| Localize a persistent weak channel to geometry or receive hardware | Existing repo capture flow `runLocalHDTVCapture` and direct score helpers `helperPlutoToneReadCapture`, `helperPlutoToneScoreChannel` | Change one physical chain element at a time so the weak behavior can be tied to one path instead of a mixed set of edits |
| Gather a repeated commissioning-quality dataset once one geometry wins | Existing repo commissioning runner `runPlutoToneCommissioningSweep` | Use one fixed configuration only, with multiple repeats, instead of another broad offset or amplitude sweep |
| Build and validate a reusable baseline | Existing repo baseline functions `commissionPlutoToneBaseline` and `runPlutoTonePrecheck` | Feed only the repeated winning configuration into commissioning, then validate with one fresh hold-out run |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Combined Pluto-to-USRP smoke execution | `runPlutoToneStage6Smoke` | `result = runPlutoToneStage6Smoke(...);` |
| Receive-only capture writing | `runLocalHDTVCapture` | `captureInfo = runLocalHDTVCapture(...);` |
| Tone-local spectral scoring | `pwelch`, `findpeaks`, `goertzel` through `helperPlutoToneScoreChannel` | `[metrics, diagnostics] = helperPlutoToneScoreChannel(x, fs, ...);` |
| Repeatability aggregation | `median`, `std` | `m = median(values, "omitnan");` |
| Narrow commissioning run artifact generation | `runPlutoToneCommissioningSweep` | `sweep = runPlutoToneCommissioningSweep(...);` |
| Baseline-backed hold-out validation | `runPlutoTonePrecheck` | `result = runPlutoTonePrecheck("BaselinePath", baselinePath, ...);` |

## Session Objective

The goal is **not** to prove that Pluto can transmit a tone.
That is already established.

The goal is to leave the session with one of these two outcomes:

1. A clean repeated-run dataset from one fixed geometry that is good enough to feed into `commissionPlutoToneBaseline`.
2. Clear evidence that the remaining problem is in the receive chain or local RF environment, not in Pluto tone settings.

## What Not To Do First

- Do not begin with another broad offset or amplitude sweep.
- Do not mix exploratory geometry runs into the commissioning dataset.
- Do not change tone offset, tone amplitude, gain, and geometry in the same run.
- Do not attempt Stage 7 baseline-backed wrapper validation until a baseline has actually been commissioned.

## Success Targets For A Commissioning Candidate

The repo currently treats a configuration as truly strong only when the repeated-run summary is roughly in this range:

- median minimum detect margin at least `+6 dB`
- median channel frequency delta at most `2000 Hz`
- max observed level no higher than `-6 dBFS`

That is the `STRONG` tier in the commissioning review logic.
Anything weaker than that may still be diagnostically useful, but it should not be treated as a durable baseline without human judgment.

## Step 1: Run The Frozen Geometry Matrix

Use the fixed waveform above and change only the physical installation.

Recommended matrix:

| Run Label | Geometry change | Why this run exists |
| :--- | :--- | :--- |
| `PlacementRef` | Repeat the current practical permanent setup once with no physical changes | Creates the same-day reference point |
| `MoveAwayFromMetal` | Keep the same coax and antenna chain, but move the radiator and feed `10` to `20` inches away from nearby metal while keeping polarization unchanged | Tests whether nearby box, stairwell, or window metal is suppressing one channel |
| `RotatePolarization` | Keep the best location so far and rotate the radiator by `90` degrees | Tests local orientation and polarization sensitivity |
| `BestExposureTemporary` | Keep the same short USB, same coax, and same antenna chain, but temporarily place the radiator at the clearest exposure near or just outside the stairwell opening | Tests whether the stairwell environment itself is the dominant limiter |

Run template:

```matlab
runLabel = "PlacementRef";
sessionId = "pluto_field_placement_ref";
captureRoot = fullfile(repoRoot, "captures", "plutoFieldPlan");

try
    result = runPlutoToneStage6Smoke( ...
        "SessionID", sessionId, ...
        "CaptureRoot", captureRoot, ...
        "CaptureFileBase", sessionId, ...
        "CenterFrequency_Hz", 599e6, ...
        "SampleRate_Hz", 8e6, ...
        "LOOffset_Hz", 0, ...
        "Gain", [30 50], ...
        "ToneOffset_Hz", 250e3, ...
        "ToneAmplitude", 0.50, ...
        "CaptureDuration_s", 1, ...
        "Verbose", true);

    fprintf("Run label ............... %s\n", runLabel);
    fprintf("REF detect margin [dB] .. %.3f\n", result.reference_metrics.detect_margin_db);
    fprintf("SURV detect margin [dB] . %.3f\n", result.surveillance_metrics.detect_margin_db);
    fprintf("REF freq err [Hz] ....... %.3f\n", result.reference_metrics.frequency_error_hz);
    fprintf("SURV freq err [Hz] ...... %.3f\n", result.surveillance_metrics.frequency_error_hz);
    fprintf("Channel delta [Hz] ...... %.3f\n", result.joint_metrics.channel_frequency_delta_hz);
    fprintf("Max level [dBFS] ........ %.3f\n", max([ ...
        result.reference_metrics.level_dbfs ...
        result.surveillance_metrics.level_dbfs]));
catch me
    fprintf("Geometry run failed: %s\n", me.message);
    rethrow(me)
end
```

Record every run in a simple operator table:

| Run Label | Physical notes | REF detect [dB] | SURV detect [dB] | Channel delta [Hz] | Max level [dBFS] | Keep for follow-up? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PlacementRef` | Fill in during the session |  |  |  |  |  |
| `MoveAwayFromMetal` | Fill in during the session |  |  |  |  |  |
| `RotatePolarization` | Fill in during the session |  |  |  |  |  |
| `BestExposureTemporary` | Fill in during the session |  |  |  |  |  |

Decision after Step 1:

- If one geometry clearly improves both minimum detect margin and channel delta, carry that geometry forward.
- If none of the four runs materially improve the result, continue to Steps 2 and 3 before attempting any commissioning run.

## Step 2: Capture Pluto-Off Background At The Same Receive Settings

This checks whether a local spur or elevated floor near `250 kHz` is already present before Pluto transmits.

Important rule:

- Do **not** change the receive settings from Step 1.
- Leave Pluto TX off for this step.

Capture template:

```matlab
sessionId = "pluto_field_background_off";

try
    captureInfo = runLocalHDTVCapture( ...
        "SessionID", sessionId, ...
        "CaptureDuration_s", 1, ...
        "CaptureFile", sessionId, ...
        "RadioName", "My USRP N320", ...
        "CenterFrequency_Hz", 599e6, ...
        "SampleRate_Hz", 8e6, ...
        "LOOffset_Hz", 0, ...
        "Gain", [30 50]);

    [referenceSignal, surveillanceSignal, captureInfoOut] = helperPlutoToneReadCapture( ...
        captureInfo, ...
        "ExpectedSampleRateHz", 8e6, ...
        "CaptureDurationSeconds", 1, ...
        "Verbose", true);

    referenceMetrics = helperPlutoToneScoreChannel( ...
        referenceSignal, ...
        8e6, ...
        "ChannelLabel", "REF", ...
        "ExpectedFrequencyHz", 250e3, ...
        "Verbose", true);

    surveillanceMetrics = helperPlutoToneScoreChannel( ...
        surveillanceSignal, ...
        8e6, ...
        "ChannelLabel", "SURV", ...
        "ExpectedFrequencyHz", 250e3, ...
        "Verbose", true);

    fprintf("Background file ......... %s\n", captureInfoOut.capture_file_path);
catch me
    fprintf("Background capture failed: %s\n", me.message);
    rethrow(me)
end
```

What to look for:

- A persistent narrow feature near `250 kHz` even with Pluto off
- One channel having a meaningfully higher local floor than the other
- Any sign that one channel is already degraded before the injected tone is present

Important interpretation note:

- The Pluto-off step is diagnostic only.
- A tone-detect or channel-status failure is expected here because the injected tone is intentionally absent.
- Use this step to compare local floor, narrow spurs, and channel asymmetry, not to score pass/fail readiness.

If the background capture already looks asymmetric, do not blame the Pluto waveform first.

## Step 3: Run Receive-Chain Isolation If One Channel Is Still Weak

Only do this step if one channel remains materially worse after the geometry matrix.

Allowed changes in this step:

- swap one receive antenna or coax path at a time
- keep the same frozen waveform and gain settings
- keep written notes about exactly what was swapped and what stayed fixed

The purpose is to answer one question:

- Does the weakness follow the **channel path** or the **physical geometry**?

Decision logic:

- If the weakness follows the cable or antenna path, troubleshoot the receive chain before commissioning a baseline.
- If the weakness stays tied to the environment or placement, return to the best geometry from Step 1 and continue.

## Step 4: Choose One Winning Geometry

Choose exactly one geometry to carry into commissioning.

Selection rule:

- Favor the setup that gives the best combined minimum detect margin and channel delta.
- Prefer a setup that is physically repeatable and can be reconstructed later.
- Do not choose a setup that is only possible as a hand-held temporary stunt unless it can later be installed repeatably.

Write down:

- `PlacementID`
- antenna used
- coax used
- exact antenna location
- antenna orientation
- approximate distance to nearby metal
- whether the door, window, or lid state matters
- any operator body-position constraints that seemed to change the result

## Step 5: Gather A Narrow Repeated Commissioning Dataset

Once one geometry wins, do **not** go back to a broad sweep.
Instead, run a narrow commissioning sweep with only the one frozen configuration.

Suggested settings:

- `ToneOffsets_Hz = 250e3`
- `ToneAmplitudes = 0.50`
- `RunsPerConfiguration = 5`

Example:

```matlab
try
    sweep = runPlutoToneCommissioningSweep( ...
        "SweepRoot", fullfile(repoRoot, "TestSetupTesting", "plutoCommissioningSweeps"), ...
        "SiteID", "", ...
        "PlacementID", "fill_in_best_geometry", ...
        "PlacementNotes", "fill in exact geometry and operator notes", ...
        "CenterFrequency_Hz", 599e6, ...
        "SampleRate_Hz", 8e6, ...
        "LOOffset_Hz", 0, ...
        "Gain", [30 50], ...
        "ToneOffsets_Hz", 250e3, ...
        "ToneAmplitudes", 0.50, ...
        "RunsPerConfiguration", 5, ...
        "CaptureDuration_s", 1, ...
        "Verbose", true);
catch me
    fprintf("Narrow commissioning sweep failed: %s\n", me.message);
    rethrow(me)
end
```

If the hardware runs complete but the top-level summary fails to assemble, rebuild it with:

```matlab
review = reviewPlutoToneCommissioningSweep("path_to_sweep_folder", "Verbose", true);
```

Decision after Step 5:

- If the repeated-run review reaches a clearly improved result, continue to baseline commissioning.
- If the repeated-run review is still weak or inconsistent, stop and treat the session as diagnostic only.

## Step 6: Commission The Baseline From The Repeated Winning Runs

Only use the repeated winning runs from Step 5.
Do **not** mix exploratory geometry runs into the baseline.

Example:

```matlab
runSources = [ ...
    "path_to_run_01_result.mat"
    "path_to_run_02_result.mat"
    "path_to_run_03_result.mat"
    "path_to_run_04_result.mat"
    "path_to_run_05_result.mat"];

try
    baseline = commissionPlutoToneBaseline( ...
        "BaselineRoot", fullfile(repoRoot, "TestSetupTesting", "plutoToneBaselines"), ...
        "BaselineID", "fill_in_baseline_id", ...
        "SiteID", "", ...
        "PlacementID", "fill_in_best_geometry", ...
        "PlacementNotes", "copy the exact winning geometry notes", ...
        "Thresholds", helperPlutoToneDefaultThresholds(), ...
        "RadioName", "My USRP N320", ...
        "CaptureFileBase", "pluto_tone_baseline", ...
        "CenterFrequency_Hz", 599e6, ...
        "SampleRate_Hz", 8e6, ...
        "LOOffset_Hz", 0, ...
        "Gain", [30 50], ...
        "ToneOffset_Hz", 250e3, ...
        "ToneAmplitude", 0.50, ...
        "CaptureDuration_s", 1, ...
        "NumRuns", numel(runSources), ...
        "RunSources", runSources, ...
        "PlotFigures", true, ...
        "Verbose", true);
catch me
    fprintf("Baseline commissioning failed: %s\n", me.message);
    rethrow(me)
end
```

Expected output:

- `baseline.mat`
- `baseline.json`
- `summary.txt`
- `summary.png`

## Step 7: Validate The New Baseline With One Hold-Out Run

Do one fresh run that was **not** used to build the baseline.

Example:

```matlab
baselinePath = fullfile( ...
    repoRoot, ...
    "TestSetupTesting", ...
    "plutoToneBaselines", ...
    "fill_in_baseline_id", ...
    "baseline.mat");

try
    result = runPlutoTonePrecheck( ...
        "BaselinePath", baselinePath, ...
        "CaptureRoot", fullfile(repoRoot, "captures", "plutoPrecheck"), ...
        "RadioName", "My USRP N320", ...
        "CaptureFileBase", "pluto_tone_precheck_holdout", ...
        "CenterFrequency_Hz", 599e6, ...
        "SampleRate_Hz", 8e6, ...
        "LOOffset_Hz", 0, ...
        "Gain", [30 50], ...
        "ToneOffset_Hz", 250e3, ...
        "ToneAmplitude", 0.50, ...
        "CaptureDuration_s", 1, ...
        "PlotFigures", true, ...
        "Verbose", true);
catch me
    fprintf("Hold-out precheck failed: %s\n", me.message);
    rethrow(me)
end
```

If the hold-out run matches the commissioned settings and lands within reasonable level drift and joint-metric bounds, the baseline is usable for later Phase 1 prechecks.

## Stop Conditions

Stop the session and do not force commissioning if any of these hold:

- one receive channel cannot reliably see the tone
- the best geometry is not physically repeatable
- the weak behavior clearly follows a receive cable or antenna path
- repeated runs from the winning geometry still drift too much to be trustworthy
- levels approach clipping or the receive chain looks obviously saturated

## Suggested Session Artifacts To Save

Save enough information so the next session can start from evidence instead of memory:

- the final filled-in operator table from Step 1
- the Pluto-off background capture path
- exact notes on any receive-chain swap or isolation step
- the winning `PlacementID` and `PlacementNotes`
- the repeated-run sweep folder from Step 5
- the commissioned baseline folder from Step 6
- the hold-out precheck result folder from Step 7

## Short Session Summary Template

Fill this in at the end of the testing-machine session:

- Winning geometry:
- Best repeated configuration:
- Median minimum detect margin:
- Median channel delta:
- Baseline commissioned:
- Hold-out precheck status:
- Main remaining blocker, if any:

## 2026-07-29 Multitone Calibration Session

This session moved the Pluto health check from exploratory multitone smoke tests into a baseline-backed calibration workflow.
The calibration waveform used an 11-tone comb with 100 kHz spacing:

```matlab
(-500:100:500) * 1e3
```

The first requested 20-run repeatability batch stopped during run 11 because the field-test computer overheated and shut down.
The first 10 runs were successfully captured and analyzed in:

```text
captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat20_analysis
```

After adding ventilation to the field-test computer, a second 10-run batch completed successfully in:

```text
captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat10_analysis
```

The combined 20 successful runs were used to commission the golden baseline:

```text
Baseline ID: pluto_outer11_100khz_golden
Runs: 20
REF expected integrated median: 10.58 dB
SURV expected integrated median: 10.51 dB
REF slow-time peak median: 8.28 dB
SURV slow-time peak median: 8.17 dB
Median cross-channel coherence: 0.786
Tonewise detector contrast median: 8.60 dB
```

To regenerate that baseline from the two analysis folders on the field-test computer:

```bash
matlab -batch "cd('TestSetupTesting'); baseline = runPlutoMultitoneCalibrationBaseline('RunSources',[\"../captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat20_analysis\"; \"../captures/plutoMultitoneSmoke/pluto_outer11_100khz_repeat10_analysis\"],'BaselineID','pluto_outer11_100khz_golden','ToneOffsets_Hz',(-500:100:500)*1e3,'PlotFigures',true,'Verbose',true);"
```

The first live calibration check against that baseline passed:

```text
PLUTO MULTITONE CALIBRATION CHECK: PASS
Fail codes: none
Warn codes: none
REF expected integrated drift: -0.04 dB
SURV expected integrated drift: -0.23 dB
REF slow-time peak drift: -0.65 dB
SURV slow-time peak drift: -0.20 dB
Median cross-channel coherence drift: -0.069
Tonewise detector contrast drift: -0.56 dB
```

The check artifacts copied back to the development workspace were in:

```text
captures/plutoMultitoneSmoke/pluto_multitone_cal_check_20260729T122918_check
```

To rerun a live calibration check on the field-test computer:

```bash
matlab -batch "cd('TestSetupTesting'); check = runPlutoMultitoneCalibrationCheck('BaselinePath','../captures/plutoMultitoneCalibrationBaselines/pluto_outer11_100khz_golden/baseline.mat','PlotFigures',true,'Verbose',true);"
```

Interpretation:

- The baseline-relative calibration check is the health gate; it passed cleanly.
- The lower-level expected-bin review may still report `WARN` because per-tone median margins are close to 0 dB, but the integrated comb evidence is strong and stable.
- `SearchPeakMedianDelta_Hz` remains diagnostic only because nearby-peak search is noisy across repeatability runs.
- The 0 kHz tone in the current 11-tone comb is suppressed by the CPI integration DC-removal step, so a future production waveform should avoid DC. Candidate replacements are `[-500:-100 100:500] * 1e3` or `[-600:-100 100:600] * 1e3`.
