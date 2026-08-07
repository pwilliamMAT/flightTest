# Pluto Azimuth Environmental Calibration

This note explains the operator-guided azimuth scan implemented by
`runPlutoAzimuthEnvironmentalScan.m` and launched from Linux by
`run_pluto_azimuth_environment_scan.sh`.

## Plain-language goal

The azimuth scan is a hand-rotated RF survey.  At each bearing, the N320
records both receive channels:

- **Directional channel**: the antenna that will be rotated through azimuth.
- **Reference channel**: the antenna that should stay fixed and provide a
  stable comparison.

During each capture, Pluto briefly transmits the standard 12-tone no-DC comb.  The
longer capture tells us what the **ambient RF environment** looks like at that
bearing.  The short Pluto burst gives a **calibration marker** that can reveal
how the directional antenna response changes with pointing angle.

## Why the Pluto pulse is bounded

The scan has two different measurements inside each bearing capture:

1. **Ambient RF measurement**: everything except the Pluto pulse window.
2. **Calibration-comb measurement**: only the Pluto pulse window.

Keeping the Pluto burst bounded means the ambient spectrum is not dominated by
our own calibration transmitter. The current default is intentionally longer
than the original 0.2 s smoke-test pulse so each individual tone has more
samples for calibration scoring. The analysis still removes the pulse window
before estimating the ambient PSD with `pwelch`. For the pulse itself, the
analysis now uses the full pulse window for the Welch spectrum diagnostic and
adds a coherent matched-tone integration that should improve as pulse duration
increases when the tone frequency is stable.

## Current default timing

The default launcher settings are:

```text
Azimuth steps: 8
Capture duration: 4 s per bearing
Pluto pulse start: 0.5 s after capture begins
Pluto pulse duration: 1.0 s
Writer frame duration: 0.1 s
Tone comb: 12 tones, -650 kHz to +650 kHz, skipping exact DC
Default folder name: az_scan_XXsteps_YYsecs_JJJJHHMM
```

The fixed 0.1 s frame size is intentional.  `comm.BasebandFileWriter` requires
the same input matrix size on every write call, so the capture is written as a
sequence of equal-duration frames.

## Remote-debug run

When nobody is physically at the antenna, use `auto` mode.  MATLAB will step
through the requested bearings without waiting for the operator to press Enter.
The antenna will not actually rotate, so the expected result is a mostly flat
azimuth pattern.

From the field computer:

```bash
cd ~/Documents/flightTest-pluto
git fetch origin
git switch feature/pluto-azimuth-environment-scan
git pull --ff-only
cd TestSetupTesting
bash run_pluto_azimuth_environment_scan.sh -n 4 -c 5 -p 1.0 -i az_remote_debug -a auto
```

## Real field run

For an actual azimuth scan, omit `auto`.  MATLAB will prompt at each bearing.
Rotate the directional antenna clockwise, wait for it to settle, then press
Enter.

Example 8-point scan:

```bash
cd ~/Documents/flightTest-pluto/TestSetupTesting
bash run_pluto_azimuth_environment_scan.sh -n 8 -c 4 -p 1.0 -i roof_azimuth_scan8
```

Example denser 24-point scan:

```bash
cd ~/Documents/flightTest-pluto/TestSetupTesting
bash run_pluto_azimuth_environment_scan.sh --num-steps 24 --capture-seconds 6 --pulse-seconds 1.5 --scan-id roof_azimuth_scan24
```

Launcher help:

```bash
bash run_pluto_azimuth_environment_scan.sh --help
```

## Output folder

Each scan writes a self-contained report folder:

```text
captures/plutoAzimuthEnvironmentScans/<scan_id>/
```

If `--scan-id` is omitted, the launcher creates a name like:

```text
az_scan_08steps_04secs_62181430
```

Here `6218` means year digit `6` plus Julian day `218`, and `1430` is
local 24-hour time.

The main review file is:

```text
index.html
```

Open that file locally in a browser on the field computer.

## Key artifacts

```text
index.html
summary.txt
azimuth_summary.csv
calibration_tone_summary.csv
scan_result.mat
environment_power_polar.png
calibration_pattern_polar.png
calibration_tone_margin_heatmap.png
calibration_tone_margin_by_frequency.png
calibration_coherent_tone_margin_by_frequency.png
directional_psd_heatmap.png
reference_psd_heatmap.png
channel_ratio_and_metrics.png
rsync_exclude_large_captures.txt
```

## Reprocessing existing field-computer captures

If the raw `bb_captures_exclude_from_rsync/` files are still present on the
field computer, you can re-run the improved full-pulse and coherent scoring
without repeating RF data collection:

```bash
cd ~/Documents/flightTest-pluto/TestSetupTesting
matlab -nodisplay -nosplash -r "try, reprocessPlutoAzimuthEnvironmentalScan('../captures/plutoAzimuthEnvironmentScans/az_pulse_1.0_debug', 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

For the pulse-duration sweep, repeat the same call for each
`az_pulse_<pulse_length>_debug` folder. The reprocess step overwrites the CSV,
MAT, PNG, text, and HTML report products in that scan folder, but it does not
modify the raw baseband captures.

To reprocess every `az_pulse_*_debug` folder and write one comparison table:

```bash
matlab -nodisplay -nosplash -r "try, reprocessPlutoAzimuthPulseDebugScans('../captures/plutoAzimuthEnvironmentScans', 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

By default, that batch helper only scans folders whose names match:

```text
^az_pulse_([0-9.]+)_debug$
```

To point it at a different set of scan folders, pass `ScanFolderRegex`.
For example, to reprocess every child folder under the parent that contains a
`scan_result.mat` file:

```bash
matlab -nodisplay -nosplash -r "try, reprocessPlutoAzimuthPulseDebugScans('../captures/plutoAzimuthEnvironmentScans', 'ScanFolderRegex', '.*', 'SummaryFileName', 'azimuth_reprocess_summary.csv', 'PlotFigures', true, 'FigureVisibility', 'off', 'Verbose', true); catch me, disp(getReport(me,'extended','hyperlinks','off')); exit(1); end; exit(0);"
```

To target one naming family, use any MATLAB regular expression, for example:

```matlab
reprocessPlutoAzimuthPulseDebugScans('../captures/plutoAzimuthEnvironmentScans', ...
    'ScanFolderRegex', '^roof_azimuth_.*', ...
    'SummaryFileName', 'roof_azimuth_reprocess_summary.csv');
```

The batch summary is written as:

```text
captures/plutoAzimuthEnvironmentScans/az_pulse_reprocess_summary.csv
```

## Copying reports without the large capture files

The raw N320 baseband captures are intentionally tagged so they are easy to
exclude when syncing back to a development laptop:

```text
bb_captures_exclude_from_rsync/
*__BB_CAPTURE_DO_NOT_RSYNC*
```

Each report folder includes:

```text
rsync_exclude_large_captures.txt
```

Example from the parent of the scan folder on the field computer:

```bash
rsync -av --exclude-from=az_remote_debug/rsync_exclude_large_captures.txt az_remote_debug/ user@devbox:/path/to/az_remote_debug/
```

That copies the HTML, CSV, text, MAT summary, and PNG report artifacts while
skipping the large raw capture files.

## How to interpret the top-level azimuth metrics

### Ambient power polar plot

`environment_power_polar.png` compares total ambient RF power versus bearing.

Expected behavior during a real scan:

- The directional channel may rise and fall as the antenna points toward or
  away from strong emitters, reflectors, or coupling sources.
- The reference channel should be more stable because it is not being rotated.

During remote debugging, both traces may be nearly flat because the antenna is
not actually moving.

### Calibration pattern polar plot

`calibration_pattern_polar.png` compares the integrated 12-tone no-DC Pluto response
versus bearing.

Expected behavior during a real scan:

- The directional channel should vary with antenna pointing.
- The reference channel should be comparatively stable.

If both channels change together, suspect a transmitter, receiver, gain, or
environmental change that is not caused by antenna pointing alone.

## How to interpret the 12-tone no-DC calibration data

The integrated comb score is useful, but it hides frequency-dependent behavior.
The per-tone artifacts show whether the band shape changes across the 12-tone no-DC comb
frequencies.

### `calibration_tone_summary.csv`

This CSV has one row per bearing per tone.  Important columns:

- `Bearing_deg`
- `ToneOffset_kHz`
- `DirectionalDetectMargin_dB`
- `ReferenceDetectMargin_dB`
- `DirectionalMinusReferenceMargin_dB`
- `DirectionalTonePeak_dBFS`
- `ReferenceTonePeak_dBFS`
- `DirectionalCoherentMargin_dB`
- `ReferenceCoherentMargin_dB`
- `DirectionalMinusReferenceCoherentMargin_dB`
- `ChannelFrequencyDelta_Hz`

Useful checks:

- Are all 12 tones present at every bearing?
- Does one tone consistently have lower margin?
- Does the directional-minus-reference shape change with bearing?
- Does one edge of the comb behave differently from the other edge?

### Per-tone heatmap

`calibration_tone_margin_heatmap.png` shows:

1. directional detect margin by bearing and tone,
2. reference detect margin by bearing and tone,
3. directional-minus-reference margin by bearing and tone.

This is the best quick-look plot for frequency-dependent antenna or coupling
behavior.

### Per-tone by-frequency plot

`calibration_tone_margin_by_frequency.png` overlays the 12-tone no-DC comb shape for
each bearing.

In a good stable calibration:

- the reference-channel curves should lie close together,
- the directional-channel curves may separate by bearing,
- broad slope or ripple changes may indicate frequency-dependent coupling,
  antenna response, or nearby-object effects.

### Coherent per-tone by-frequency plot

`calibration_coherent_tone_margin_by_frequency.png` overlays the coherent
matched-tone margin for each bearing. This plot is the best place to check
whether a longer calibration pulse is buying processing gain. The coherent
margin mixes each planned tone to DC and averages over the full pulse duration,
so it should rise with pulse length if the tone is stable and should expose
frequency-dependent or bearing-dependent calibration changes more clearly than
the short capped spectrum view did.

## Practical interpretation for parking-lot/roof use

The primary field question is:

> Did the directional antenna see a different RF environment or calibration
> response at some bearing, while the reference antenna stayed stable?

If yes, the scan can help identify problematic azimuths or near-field coupling
conditions, such as a vehicle parked near the antennas.

If no, the remote-debug run may still be useful as an end-to-end system test,
but it is not a real antenna-pattern measurement unless the directional antenna
was physically rotated.
