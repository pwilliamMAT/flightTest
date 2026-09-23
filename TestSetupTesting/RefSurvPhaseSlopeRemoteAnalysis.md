# REF/SURV Phase-Slope Analysis on the Field Computer

## Purpose

The large `.bb` baseband captures should stay on the field/collection computer.
This note is a handoff for running the next calibration-channel diagnostic there
with MATLAB and an AI coding assistant.

The question we want to answer is:

> During the Pluto calibration pulse, is the REF/SURV phase difference mostly a
> constant frequency offset, or is it drifting fast enough that we need dynamic
> phase tracking?

This matters because the current 12-tone comb is detectable after integration,
but the expected 1-second coherent gain is not fully recovered.  The existing
summary metrics show REF/SURV tone-frequency deltas on the order of 9-13 kHz.
At that rate the relative phase wraps thousands of times during a 1-second
pulse unless we estimate and remove the phase slope.

## Prerequisites on the field computer

1. The raw capture folders must still contain:

   ```text
   captures/plutoAzimuthEnvironmentScans/<scan_id>/scan_result.mat
   captures/plutoAzimuthEnvironmentScans/<scan_id>/bb_captures_exclude_from_rsync/
   ```

2. MATLAB must have access to `comm.BasebandFileReader`.

3. Pull the current azimuth feature branch:

   ```bash
   cd ~/Documents/flightTest-pluto
   git fetch origin
   git switch feature/pluto-azimuth-environment-scan
   git pull --ff-only
   cd TestSetupTesting
   ```

## First rerun the current reprocessing

For one scan:

```bash
matlab -nodisplay -nosplash -r "try, reprocessPlutoAzimuthEnvironmentalScan('../captures/plutoAzimuthEnvironmentScans/<scan_id>', 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

For all scan folders under the parent that contain `scan_result.mat`:

```bash
matlab -nodisplay -nosplash -r "try, reprocessPlutoAzimuthPulseDebugScans('../captures/plutoAzimuthEnvironmentScans', 'ScanFolderRegex', '.*', 'SummaryFileName', 'azimuth_reprocess_summary.csv', 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

This refreshes the current report products but still does **not** provide the
time-resolved phase-slope fit we need next.

## Diagnostic to add/run locally on the field computer

Add a MATLAB helper, for example:

```text
TestSetupTesting/analyzePlutoAzimuthRefSurvPhaseSlope.m
```

It should read one scan folder, loop over each `.bb` capture, isolate the Pluto
pulse window, and estimate phase slope per tone and per bearing.

### Inputs

Recommended function signature:

```matlab
phaseSlope = analyzePlutoAzimuthRefSurvPhaseSlope(scanRoot, varargin)
```

Suggested options:

```matlab
'ToneOffsets_Hz'          % default from scan.settings.tone_offsets_hz
'BlockDuration_s'         % default 0.010 or 0.020
'MaxSamplesPerPulse'      % default Inf
'PlotFigures'             % default true
'FigureVisibility'        % default 'off'
'Verbose'                 % default true
```

### Processing algorithm

For each bearing/capture:

1. Open the `.bb` file with `comm.BasebandFileReader`.
2. Use reader metadata or `scan.settings` to identify:

   ```matlab
   pulse_start_delay_s
   pulse_duration_s
   sample_rate_hz
   ```

3. Extract only the Pluto pulse samples:

   ```matlab
   surv = data(pulseMask, 1);   % SURV / directional
   ref  = data(pulseMask, 2);   % REF / static reference
   ```

4. For each tone offset `f0`, mix both channels to the planned tone:

   ```matlab
   n = (0:numel(ref)-1).';
   osc = exp(-1j*2*pi*f0/sample_rate_hz*n);
   refTone  = ref  .* osc;
   survTone = surv .* osc;
   ```

5. Form the REF/SURV complex ratio in short time blocks:

   ```matlab
   blockSamples = round(BlockDuration_s * sample_rate_hz);
   for each block
       z(block) = mean(refTone(block) .* conj(survTone(block)), 'omitnan');
       phase(block) = angle(z(block));
       magnitude(block) = abs(z(block));
   end
   phaseUnwrapped = unwrap(phase);
   tBlock = blockCenterSample / sample_rate_hz;
   ```

   Using `ref * conj(surv)` avoids dividing by small SURV samples and directly
   estimates relative phase.

6. Fit phase versus time:

   ```matlab
   p = polyfit(tBlock, phaseUnwrapped, 1);
   delta_frequency_hz = p(1) / (2*pi);
   phase_intercept_rad = p(2);
   residual_phase_rad = phaseUnwrapped - polyval(p, tBlock);
   residual_phase_rms_rad = rms(residual_phase_rad, 'omitnan');
   ```

7. Optionally fit instantaneous frequency drift:

   ```matlab
   instantaneous_frequency_hz = diff(phaseUnwrapped) ./ diff(tBlock) / (2*pi);
   pFreq = polyfit(tBlock(1:end-1), instantaneous_frequency_hz, 1);
   frequency_drift_hz_per_s = pFreq(1);
   ```

### Output metrics

Write a CSV, for example:

```text
ref_surv_phase_slope_summary.csv
```

with one row per bearing per tone:

```text
ScanID
StepIndex
Bearing_deg
ToneOffset_Hz
PulseDuration_s
BlockDuration_s
NumBlocks
RefSurvDeltaFrequency_Hz
RefSurvFrequencyDrift_HzPerS
PhaseFitResidualRMS_rad
PhaseFitResidualRMS_deg
MeanRatioMagnitude
MedianRatioMagnitude
FitRSquared
```

Also write summary plots:

```text
ref_surv_delta_frequency_by_tone.png
ref_surv_frequency_drift_by_tone.png
ref_surv_phase_fit_residual_by_tone.png
```

Useful plot views:

- heatmap: bearing vs tone, colored by `RefSurvDeltaFrequency_Hz`
- heatmap: bearing vs tone, colored by `RefSurvFrequencyDrift_HzPerS`
- line plot: unwrapped phase vs time with fitted line for a few representative tones

## How to interpret the result

### Case A: mostly constant offset

If:

```text
RefSurvDeltaFrequency_Hz ~= 9-13 kHz
RefSurvFrequencyDrift_HzPerS is small
PhaseFitResidualRMS is small
```

then the main issue is a **fixed tonewise residual frequency offset**.  The next
implementation should correct each tone by its fitted `delta_frequency_hz`
before doing the 1-second coherent integration.

### Case B: strong drift during the pulse

If:

```text
RefSurvFrequencyDrift_HzPerS is large
PhaseFitResidualRMS remains large after a linear phase fit
```

then a single NCO correction is not enough.  We need dynamic phase tracking
during the pulse.

### Barker-code design implication

The earlier Barker proposal used:

```text
11-chip Barker code
200 kchip/s
55 us code period
18.2 kHz phase-update rate
```

If the uncorrected REF/SURV offset is 11-13 kHz, phase changes by roughly:

```text
11 kHz * 55 us * 360 deg ~= 218 deg/update
13 kHz * 55 us * 360 deg ~= 257 deg/update
```

That is too fast for simple unwrap.  Therefore, either:

1. perform a coarse tonewise frequency correction first, then use Barker phase
   tracking, or
2. use a faster update rate / shorter training code.

Do not finalize the Barker chip rate until the phase-slope diagnostic reports
`RefSurvFrequencyDrift_HzPerS`.

## Suggested Claude prompt on the field computer

Paste this into Claude while working in the repository root:

```text
Please implement TestSetupTesting/analyzePlutoAzimuthRefSurvPhaseSlope.m.

Use the instructions in TestSetupTesting/RefSurvPhaseSlopeRemoteAnalysis.md.
The function should read a Pluto azimuth scan folder containing scan_result.mat
and raw .bb files under bb_captures_exclude_from_rsync/, isolate the Pluto pulse
window, demodulate each configured tone in REF and SURV, compute block-averaged
REF*conj(SURV) phase over 10-20 ms blocks, unwrap phase, fit phase vs time, and
write ref_surv_phase_slope_summary.csv plus diagnostic PNG plots into the scan
folder. Do not modify or move the raw .bb files. Prefer Signal Processing
Toolbox/MATLAB built-ins. After implementation, run it on one scan first, then
summarize the median and range of RefSurvDeltaFrequency_Hz,
RefSurvFrequencyDrift_HzPerS, and PhaseFitResidualRMS_deg.
```

## Example execution after implementation

```bash
cd ~/Documents/flightTest-pluto/TestSetupTesting
matlab -nodisplay -nosplash -r "try, analyzePlutoAzimuthRefSurvPhaseSlope('../captures/plutoAzimuthEnvironmentScans/<scan_id>', 'BlockDuration_s', 0.010, 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

Start with the latest one-bearing check or a short debug scan before running
the full azimuth set.
