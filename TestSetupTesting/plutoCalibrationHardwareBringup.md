# Pluto Calibration Hardware Bring-Up

This document is the staged bring-up sequence for the testing machine before running the standalone Pluto calibration workflow.

Goal:

1. Prove the NI USRP N320 receive path works by itself.
2. Prove the project capture path works by itself.
3. Prove the Pluto transmit path works by itself.
4. Prove the Pluto-to-USRP RF path works before baseline gating.
5. Only then run the full standalone calibration wrapper.

This document assumes:

- The testing machine is already physically connected to the USRP N320.
- The receive antennas are already connected to the expected USRP channels.
- The Pluto radio is available to the testing machine over USB.
- The repository is present on the testing machine.

Channel convention used throughout this repo:

- `RF0:RX2 -> CH1 / RX1 -> SURV`
- `RF1:RX2 -> CH2 / RX2 -> REF`

Project default precheck settings:

- `CenterFrequency_Hz = 540e6`
- `LOOffset_Hz = 200e3`
- `CaptureTuneFrequency_Hz = 540.2e6`
- `ToneOffset_Hz = 250e3`
- `ToneRFFrequency_Hz = 540.45e6`
- `SampleRate_Hz = 6.144e6`
- `Gain = [30 50]`

## Stage Summary

| Stage | Purpose | Stop if this fails |
| :--- | :--- | :--- |
| 0 | Verify Linux host and network assumptions | Yes |
| 1 | Verify MATLAB toolboxes and support packages | Yes |
| 2 | Verify the saved USRP radio configuration exists | Yes |
| 3 | Verify direct dual-channel USRP receive capture works | Yes |
| 4 | Verify the repo capture wrapper writes a usable `.bb` file | Yes |
| 5 | Verify Pluto transmit can start and stop cleanly | Yes |
| 6 | Verify the Pluto tone is actually seen in both USRP channels | Yes |
| 7 | Run the full standalone calibration wrapper with baseline gating | Yes |

## Stage 0: Linux Host and Network Checks

The repo capture stack expects the USRP host tuning path to run on Linux.
`TestSetupTesting/log_iq_n320_2antennas.m` currently assumes the USRP network interface is named `eno1`.

Before any capture, verify that assumption on the testing machine:

```bash
ip link show eno1
```

If the USRP-facing NIC is not `eno1`, update `TestSetupTesting/log_iq_n320_2antennas.m` before relying on the repo hardening logic.

The capture script attempts to enforce:

- MTU `9000`
- CPU governor `performance`
- socket buffers `50 MB`

Useful checks:

```bash
ip link show eno1
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
sysctl net.core.rmem_max
sysctl net.core.wmem_max
```

Expected direction:

- The USRP NIC should show `mtu 9000`.
- CPU governor should report `performance`.
- `rmem_max` and `wmem_max` should be at least `50000000`.

If these do not hold, fix them before attempting long captures.

## Stage 1: MATLAB Toolboxes and Support Packages

For this repo and this calibration workflow you need:

- Communications Toolbox
- DSP System Toolbox
- Wireless Testbench Support Package for NI USRP Radios
- Communications Toolbox Support Package for Analog Devices ADALM-PLUTO Radio

Important note for USRP N3xx radios:

- In modern MATLAB releases, N3xx support is expected through the Wireless Testbench support path, not the older USRP N-series path.

Run this in MATLAB first:

```matlab
fprintf('exist findsdru ........ %d\n', exist('findsdru', 'file'));
fprintf('exist radioSetupWizard  %d\n', exist('radioSetupWizard', 'file'));
fprintf('exist radioConfigurations %d\n', exist('radioConfigurations', 'file'));
fprintf('exist basebandReceiver  %d\n', exist('basebandReceiver', 'file'));
fprintf('exist sdrtx ........... %d\n', exist('sdrtx', 'file'));
fprintf('exist comm.BasebandFileReader class .. %d\n', exist('comm.BasebandFileReader', 'class'));
fprintf('exist dsp.SineWave class ............. %d\n', exist('dsp.SineWave', 'class'));
```

Pass condition:

- `findsdru` exists
- `radioSetupWizard` exists
- `radioConfigurations` exists
- `basebandReceiver` exists
- `sdrtx` exists
- `comm.BasebandFileReader` exists
- `dsp.SineWave` exists

If `findsdru` is missing, install the NI USRP support package before continuing.
If `sdrtx` is missing, install the Pluto support package before continuing.

## Stage 2: Verify Saved USRP Radio Configuration

The repo capture wrapper defaults to the radio configuration name:

- `"My USRP N320"`

List the saved radio configurations:

```matlab
configs = radioConfigurations
```

If the expected configuration does not exist, run the Radio Setup wizard:

```matlab
radioSetupWizard
```

Save a configuration named exactly:

```text
My USRP N320
```

Then verify the radio is discoverable:

```matlab
radios = findsdru
```

Pass condition:

- `radioConfigurations` includes `"My USRP N320"`
- `findsdru` returns the connected N320 with a healthy status

## Stage 3: Minimal USRP Receive Smoke Test

This stage checks the radio and two-channel receive path directly, before using the repo wrappers.

Important label bridge for the N320:

- The hardware capture log prints the physical USRP ports: `RF0:RX2` and `RF1:RX2`.
- The later `.bb` reader and scoring helpers report the stored file channels as `CH1/RX1` and `CH2/RX2`.
- In this repo those names refer to the same fixed paths:
  - `RF0:RX2 -> CH1/RX1 -> SURV`
  - `RF1:RX2 -> CH2/RX2 -> REF`

Run this in MATLAB:

```matlab
clear bbrx

try
    bbrx = basebandReceiver("My USRP N320");
    bbrx.CenterFrequency = 540.2e6;
    bbrx.SampleRate = 6.144e6;
    bbrx.RadioGain = [30 50];
    bbrx.Antennas = ["RF0:RX2" "RF1:RX2"];

    iq = capture(bbrx, seconds(1));
    release(bbrx);

    fprintf('Samples captured ........ %d\n', size(iq, 1));
    fprintf('Channels captured ....... %d\n', size(iq, 2));
    fprintf('CH1 mean power .......... %.3e\n', mean(abs(iq(:, 1)).^2));
    fprintf('CH2 mean power .......... %.3e\n', mean(abs(iq(:, 2)).^2));
catch me
    if exist('bbrx', 'var')
        release(bbrx);
    end
    rethrow(me)
end
```

Pass condition:

- Capture completes without error.
- `size(iq, 2) == 2`
- Both channel powers are finite and clearly above zero.

Stop here if:

- only one channel appears
- capture throws a host/radio error
- one or both channels are effectively zero

## Stage 4: Repo Capture Path Smoke Test

This stage verifies the exact N320 capture path used by the repo before involving Pluto.

Run this from the repo root in MATLAB:

```matlab
try
    captureInfo = runLocalHDTVCapture( ...
        'SessionID', "usrp_smoke_test", ...
        'CaptureDuration_s', 1, ...
        'CaptureFile', "usrp_smoke_test", ...
        'RadioName', "My USRP N320", ...
        'CenterFrequency_Hz', 540e6, ...
        'SampleRate_Hz', 6.144e6, ...
        'LOOffset_Hz', 200e3, ...
        'Gain', [30 50]);

    disp(captureInfo)
catch me
    rethrow(me)
end
```

Then verify the first `.bb` file is readable:

```matlab
clear reader

try
    reader = comm.BasebandFileReader(char(captureInfo.local_capture_files(1)), ...
        'SamplesPerFrame', 4096);
    iq = reader();
    release(reader);

    fprintf('BB samples/frame ....... %d\n', size(iq, 1));
    fprintf('BB channels ............ %d\n', size(iq, 2));
    fprintf('Header center [MHz] .... %.6f\n', captureInfo.header_center_frequency_hz / 1e6);
    fprintf('Header LO [MHz] ........ %.6f\n', captureInfo.header_lo_offset_hz / 1e6);
    fprintf('Header tune [MHz] ...... %.6f\n', captureInfo.header_tune_frequency_hz / 1e6);
    fprintf('Header sample rate [MSps] %.6f\n', captureInfo.header_sample_rate_hz / 1e6);
catch me
    if exist('reader', 'var')
        release(reader);
    end
    rethrow(me)
end
```

If you want a checked-in convenience runner instead of retyping the full block:

```matlab
cd('/path/to/flightTest/TestSetupTesting')
result = runPlutoToneStage6Smoke('Verbose', true);
```

From an SSH terminal, the short form is:

```bash
cd /path/to/flightTest/TestSetupTesting
matlab -batch "result = runPlutoToneStage6Smoke('Verbose', true); disp(result.joint_metrics)"
```

Pass condition:

- The capture wrapper completes.
- A `.bb` file is written.
- The file reopens with `comm.BasebandFileReader`.
- The header values match the requested settings.

## Stage 5: Pluto TX-Only Smoke Test

This stage verifies the Pluto transmit path by itself.
Start with a modest amplitude so you do not overdrive the receive chain when you later move to the combined test.

Run this from the repo root in MATLAB:

```matlab
clear txContext

try
    waveform = helperPlutoToneBuildWaveform(6.144e6, 250e3, 0.25, ...
        'Verbose', true);

    txContext = helperPlutoToneStartTx( ...
        'CenterFrequencyHz', 540.2e6, ...
        'SampleRateHz', 6.144e6, ...
        'Waveform', waveform, ...
        'Verbose', true);

    pause(2)

    release(txContext.transmitter);
catch me
    if exist('txContext', 'var')
        release(txContext.transmitter);
    end
    rethrow(me)
end
```

Pass condition:

- Pluto connects.
- Transmission starts cleanly.
- Release stops transmission cleanly.

Stop here if:

- `helperPlutoToneStartTx` throws a missing dependency error
- USB connection to Pluto is unstable
- the radio cannot be opened

## Stage 6: Combined Pluto-to-USRP Smoke Test Without Baseline

This is the most useful intermediate step before the full wrapper.
It proves that the Pluto tone is actually being received by the USRP and seen in both channels.

Run this from the repo root in MATLAB:

```matlab
clear txContext

try
    waveform = helperPlutoToneBuildWaveform(6.144e6, 250e3, 0.25, ...
        'Verbose', true);

    txContext = helperPlutoToneStartTx( ...
        'CenterFrequencyHz', 540.2e6, ...
        'SampleRateHz', 6.144e6, ...
        'Waveform', waveform, ...
        'Verbose', true);

    captureInfo = helperPlutoToneCaptureN320( ...
        'SessionID', "pluto_usrp_smoke", ...
        'CaptureRoot', fullfile(pwd, 'captures', 'plutoSmoke'), ...
        'CaptureFileBase', "pluto_usrp_smoke", ...
        'RadioName', "My USRP N320", ...
        'CenterFrequencyHz', 540e6, ...
        'SampleRateHz', 6.144e6, ...
        'LOOffsetHz', 200e3, ...
        'Gain', [30 50], ...
        'CaptureDurationSeconds', 1, ...
        'Verbose', true);

    [referenceSignal, surveillanceSignal, captureInfoOut] = helperPlutoToneReadCapture( ...
        captureInfo, ...
        'ExpectedSampleRateHz', 6.144e6, ...
        'CaptureDurationSeconds', 1, ...
        'Verbose', true);

    release(txContext.transmitter);

    referenceMetrics = helperPlutoToneScoreChannel( ...
        referenceSignal, ...
        6.144e6, ...
        'ChannelLabel', 'REF', ...
        'ExpectedFrequencyHz', 250e3, ...
        'Verbose', true);

    surveillanceMetrics = helperPlutoToneScoreChannel( ...
        surveillanceSignal, ...
        6.144e6, ...
        'ChannelLabel', 'SURV', ...
        'ExpectedFrequencyHz', 250e3, ...
        'Verbose', true);

    jointMetrics = helperPlutoToneScoreJointMetrics( ...
        referenceSignal, ...
        surveillanceSignal, ...
        6.144e6, ...
        'ReferenceMetrics', referenceMetrics, ...
        'SurveillanceMetrics', surveillanceMetrics, ...
        'Verbose', true);

    disp(captureInfoOut)
    disp(referenceMetrics)
    disp(surveillanceMetrics)
    disp(jointMetrics)
catch me
    if exist('txContext', 'var')
        release(txContext.transmitter);
    end
    rethrow(me)
end
```

Pass condition:

- Both `referenceMetrics.tone_found` and `surveillanceMetrics.tone_found` are true.
- Both measured frequencies are close to `250e3 Hz`.
- `jointMetrics.channel_frequency_delta_hz` is small.
- Neither channel is clipped or obviously too close to `0 dBFS`.

Operator suggestion:

- If the received levels are too high, reduce Pluto output level, add attenuation, or increase physical separation before continuing.
- If one channel sees the tone clearly and the other does not, check the antenna chain, channel mapping, and gain settings before continuing.

## Observed Field-Trial Matrix

The table below records the Stage 6 runs already performed during bring-up so later hardware changes can be compared against them without reconstructing chat history.
All rows use the fixed repo mapping:

- `RF0:RX2 -> CH1/RX1 -> SURV`
- `RF1:RX2 -> CH2/RX2 -> REF`

| Run | Config | Physical setup | REF detect [dB] | SURV detect [dB] | REF freq err [Hz] | SURV freq err [Hz] | Joint delta [Hz] | XCorr [dB] | Interpretation |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| Stage 6A | `540 MHz / 250 kHz / amp 0.25` | Branch-default smoke run | `+0.8189` | `-2.4643` | `-16843.8` | `-22609.4` | `5765.6` | `-36.7368` | End-to-end worked, but tone prominence and inter-channel agreement were weak. |
| Stage 6B | `599 MHz / 250 kHz / amp 0.5` | HDTV-band comparison run | `+3.8760` | `-2.0907` | `-10376.0` | `-8483.9` | `1892.1` | `-5.8812` | Best overall combined result so far. |
| Stage 6C | `599 MHz / 3.2 MHz / amp 0.5` | Higher-offset comparison run | `+1.5789` | `-1.1572` | `+22900.4` | `+18383.8` | `4516.6` | `-5.4117` | Stayed passable, but did not improve over Stage 6B. |
| Stage 6D1 | `599 MHz / 1.5 MHz / amp 0.5` | First 1.5 MHz comparison run before placement study | `-0.6732` | `-2.8809` | `-18920.9` | `-17211.9` | `1709.0` | `-5.9941` | Joint delta improved relative to Stage 6C, but both detect margins stayed weak. |
| Stage 6D2 | `599 MHz / 1.5 MHz / amp 0.5` | Pluto on top of computer box, inside stairwell, 6.75 in telescoping antenna | `-1.2627` | `-9.3541` | `-13000.5` | `-12268.1` | `732.4219` | `-6.0588` | Best 1.5 MHz delta so far, but surveillance detect collapsed. |
| Stage 6D3 | `599 MHz / 1.5 MHz / amp 0.5` | Short USB plus 10 ft Nooelec mount and 4.9 in antenna held just outside stairwell | `+0.3467` | `+1.5753` | `+7080.1` | `+20874.0` | `13793.9` | `-5.9300` | Outside placement improved tone visibility, but joint agreement collapsed. |
| Stage 6D4 | `599 MHz / 1.5 MHz / amp 0.5` | Same 10 ft Nooelec mount and 4.9 in antenna taped outside stairwell ledge | `+1.1428` | `-0.3017` | `+6958.0` | `+21301.3` | `14343.3` | `-4.0574` | Mounted outside stayed better for visibility than inside, but joint stability remained poor. |
| Stage 6D5 | `599 MHz / 1.5 MHz / amp 0.8` | Same outside-mounted 10 ft Nooelec mount and 4.9 in antenna as Stage 6D4, but stronger Pluto tone | `+1.7067` | `+3.7273` | `-4455.6` | `-12390.1` | `7934.6` | `-4.2754` | Stronger tone materially improved detect margin and reduced delta versus Stage 6D4, but the combined result still trails Stage 6B. |

Observed operator notes:

- No observed Stage 6 run is baseline-worthy yet.
- `599 MHz / 250 kHz / amp 0.5` remains the best overall combined run and is still the main comparison point for future tuning changes.
- The `1.5 MHz` placement and amplitude study showed that physical placement and tone level affect single-channel visibility, but neither change alone has solved the inter-channel agreement problem.
- On the outside-mounted setup, raising `ToneAmplitude` from `0.5` to `0.8` improved both detect margins and reduced the joint delta from `14343.3 Hz` to `7934.6 Hz`, which suggests tone visibility was part of the problem.
- Even after that amplitude increase, the outside-mounted `1.5 MHz` run still trails Stage 6B materially on joint agreement, so the remaining issue is not just insufficient Pluto power.
- The 10 ft micro-USB extension made Pluto undiscoverable. Keep the Pluto on the short USB cable and move only the antenna/feed when possible.
- The practical permanent setup tried so far is Pluto on top of the computer box, but that setup still needs better combined metrics before it should be treated as a calibration baseline.

## Stage 7: Full Standalone Calibration Wrapper

Only run this stage after Stages 1 through 6 pass.
This stage requires a commissioned baseline file.

If you already have a baseline, run:

```matlab
baselinePath = fullfile(pwd, 'TestSetupTesting', 'plutoToneBaselines', ...
    '<baseline_id>', 'baseline.mat');

result = runPlutoTonePrecheck( ...
    'BaselinePath', baselinePath, ...
    'CaptureRoot', fullfile(pwd, 'captures', 'plutoPrecheck'), ...
    'RadioName', "My USRP N320", ...
    'CaptureFileBase', "pluto_tone_precheck", ...
    'CenterFrequency_Hz', 540e6, ...
    'SampleRate_Hz', 6.144e6, ...
    'LOOffset_Hz', 200e3, ...
    'Gain', [30 50], ...
    'ToneOffset_Hz', 250e3, ...
    'ToneAmplitude', 0.25, ...
    'CaptureDuration_s', 1, ...
    'PlotFigures', true, ...
    'Verbose', true);

disp(result.precheck_summary.text_block)
```

Pass condition:

- `result.status` is `PASS` or an explainable `WARN`
- the summary metrics look physically reasonable
- a run folder is written under `TestSetupTesting/plutoPrecheckRuns/`

If you do not yet have a baseline:

- stop after Stage 6
- if the physical Pluto placement is now fixed, run `runPlutoToneCommissioningSweep.m` to compare the candidate tone offsets and amplitudes on that one permanent setup
- do not treat Stage 7 as available yet

## Stage 8: Ready for the Larger Acquisition Workflow

Once Stage 7 is stable:

1. Keep the Pluto calibration wrapper separate from the coordinated capture path until you are satisfied with repeatability.
2. Use the standalone result folders to compare runs and verify hardware stability.
3. Only after that should you wire the precheck in front of the larger acquisition workflow.

## Quick Troubleshooting

### `findsdru` does not exist

The NI USRP support package is not installed or not available in this MATLAB environment.

### `sdrtx` does not exist

The Pluto support package is not installed or not available in this MATLAB environment.

### `radioConfigurations` is empty

The saved radio setup configuration does not exist yet.
Run `radioSetupWizard` and save `"My USRP N320"`.

### Direct capture returns one channel

The radio configuration, channel mapping, or antenna selection is wrong.
Do not continue until dual-channel capture works.

### `.bb` file writes but readback fails

The repo capture path is not healthy yet.
Fix the readback issue before involving Pluto.

### Pluto TX starts but no tone is visible in the USRP capture

Check:

- Pluto is transmitting at the intended RF frequency
- the USRP tune frequency is `CenterFrequency_Hz + LOOffset_Hz`
- the expected tone offset is still `250e3 Hz`
- RF path, attenuation, and physical placement are sane

### Tone is visible but levels are too high

Back off the Pluto output or add attenuation before continuing.
Do not continue into baseline-backed calibration with an obviously saturated receive chain.

## Suggested Operator Habit

Use short `1 s` captures until every stage is stable.
Do not jump directly to the full wrapper or the larger acquisition flow.
The fastest path to a reliable setup is:

1. direct USRP receive
2. repo capture path
3. Pluto transmit only
4. combined Pluto-to-USRP smoke test
5. full standalone calibration
