# Radar Expert Detector Tuning

## Current priority

The current symptom is that detections are not consistently landing on the ADS-B truth loci in bistatic `(R_excess, f_D)` space.

The right order is:

1. Get detections to appear near truth.
2. Then clean up false alarms.
3. Only after that, spend time on tracker tuning.

If the detector is not producing hits near truth, tracker changes will mostly hide the root cause instead of fixing it.

## Main tuning suggestions

### 1. Sweep detector sensitivity first

Start with the parameters that most directly control whether weak truth-aligned peaks can pass CFAR:

- `Pfa`
- `CfarType`
- `OSRankFraction`

Recommended first values:

- `Pfa`: `1e-4`, `3e-4`, `1e-3`
- `CfarType`: compare `OS` and `CA`
- `OSRankFraction`: `0.75`, `0.65`, `0.60`

Reason:

- If the current detector is simply too conservative, these sweeps are the fastest way to recover missed truth-aligned detections.
- `OS` is robust, but it can be too conservative in some local regions. A lower OS rank or a CA comparison run tells us whether that conservatism is the issue.

### 2. Reduce CFAR window size if truth peaks look masked

If truth exists in the right place but detections are sparse or missing, test smaller guard and training windows.

Recommended values to compare:

- `GuardCells`: `[6 2]`, `[4 2]`, `[4 1]`
- `TrainCells`: `[20 4]`, `[12 4]`, `[10 3]`

Reason:

- Large windows can inflate the threshold around clutter gradients, sidelobes, or structured interference.
- Smaller windows often recover weak aircraft echoes, especially when the local environment is not homogeneous.

### 3. Check whether suppression logic is blocking real targets

The detector has several mechanisms that are useful in clutter, but any of them can also remove a real aircraft if the truth lies near the suppressed region.

Recommended parameters to test:

- `LocalMaxima`: `true` and `false`
- `LMRangeBins`: `4`, `2`
- `LMDoppBins`: `2`, `1`
- `ATSCGuardPenaltyDB`: `10`, `6`, `0`
- `ATSCGuardWidthBins`: `3`, `2`, `1`
- `NotchGuardDoppBins`: `1`, `0`

Reason:

- `LocalMaxima` can suppress broad or nearby peaks during diagnostics.
- The ATSC ghost-range guard can block real echoes if truth falls near one of the guarded ranges.
- The zero-Doppler notch guard can matter if truth Doppler is close to DC.

### 4. Revisit the near-range exclusion only if truth is close in

If truth is near the lower edge of the displayed range axis, check `MinRangeM`.

Recommended values:

- `MinRangeM`: current baseline, `2000`, `0`

Reason:

- A real aircraft can be suppressed before CFAR reporting if it falls inside the minimum-range exclusion.

### 5. Use truth gates only for diagnosis, not as a detector fix

These parameters do not change the detector itself. They only change how strictly detections are matched to truth:

- `GateRangeCells`
- `GateDopplerBins`
- `TimeGateS`

Recommended diagnostic values:

- `GateRangeCells`: `3`, `5`
- `GateDopplerBins`: `3`, `5`
- `TimeGateS`: default, then a slightly looser test such as `0.25` or `0.5` if needed

Reason:

- If a looser truth gate suddenly turns many false alarms into true positives, the issue may be small systematic offset rather than CFAR sensitivity.
- That would push the next investigation toward timing, Doppler calibration, or bistatic geometry rather than detector thresholds.

### 6. Do not sweep everything at once

Use one family of changes at a time:

1. Sensitivity family
2. Window-size family
3. Suppression family
4. Close-range exclusion

Reason:

- If too many parameters move together, it becomes impossible to tell which change actually helped.

## How to interpret outcomes

### Good outcome

- `n_tp` increases
- truth-vs-detection plots show detections landing closer to truth
- false alarms rise only moderately

### Bad outcome

- `n_fa` increases a lot
- `n_tp` does not improve
- detections still do not move toward truth

That usually means either:

- the wrong detector family is being tuned, or
- the dominant problem is not CFAR at all, but timing/alignment/measurement bias

### Strong sign of timing or geometry bias

If detections repeatedly sit near truth but with a nearly fixed offset in range or Doppler, stop broad CFAR tuning and investigate:

- truth epoch
- bistatic projection
- Doppler sign or scaling
- part/block timing alignment

## Recommended first campaigns

### Campaign A: sensitivity

- baseline
- higher `Pfa`
- much higher `Pfa`
- CA comparison
- lower OS rank

### Campaign B: CFAR window size

- baseline
- smaller guard
- smaller guard and smaller train

### Campaign C: suppression logic

- baseline
- local-max off
- smaller local-max neighborhood
- relaxed ATSC guard
- notch guard off

### Campaign D: close-range gate

- baseline
- reduced `MinRangeM`
- zero `MinRangeM`

## Workflow

### Short answer

Yes: the detector-only iteration workflow is `runDetectorReplaySweep`.

No: it does not automatically sweep every parameter.

It runs exactly the cases you give it.

## What `runDetectorReplaySweep` does

It reruns only the detector stage from the saved block-level replay snapshot:

- reuses the saved whitened per-block RDMs
- reruns `detectTargets`
- rebuilds the detection list
- optionally rescored the new detections against ADS-B truth

It does not rerun:

- IQ loading
- clutter mitigation
- CAF generation

## Supported per-case overrides

Each case can override any of these directly:

- `Name`
- `Pfa`
- `GuardCells`
- `TrainCells`
- `MinRangeM`
- `CfarType`
- `OSRankFraction`
- `LocalMaxima`
- `LMRangeBins`
- `LMDoppBins`
- `MinSNRDB`
- `ATSCGuardPenaltyDB`
- `ATSCGuardWidthBins`
- `NotchGuardDoppBins`

You can also use `CfarOptions` for advanced fields not exposed as top-level arguments.

## Syntax options

### Option 1: one baseline replay

If you already have the replay snapshot path:

```matlab
cd BistaticDataAnalysis

replay = runDetectorReplaySweep( ...
    'C:\Users\pwilliam\agenticProjects\flightTest\captures\<session_id>\analysis\detector_replay_input.mat', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

### Option 2: one modified detector run, no sweep

This is still `runDetectorReplaySweep`, but with one set of overrides:

```matlab
cd BistaticDataAnalysis

replay = runDetectorReplaySweep( ...
    replay_path, ...
    'Pfa', 3e-4, ...
    'GuardCells', [4 2], ...
    'TrainCells', [12 4], ...
    'CfarType', 'OS', ...
    'OSRankFraction', 0.65, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

### Option 3: actual sweep across named cases

This is the normal way to compare several detector configurations:

```matlab
cd BistaticDataAnalysis

cases = struct( ...
    'Name', {'baseline', 'pfa3e4', 'pfa1e3', 'ca_pfa3e4'}, ...
    'Pfa', {1e-4, 3e-4, 1e-3, 3e-4}, ...
    'CfarType', {'OS', 'OS', 'OS', 'CA'});

replay = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

## Suggested first commands

### Sensitivity campaign

```matlab
cases = struct( ...
    'Name', {'baseline', 'pfa3e4', 'pfa1e3', 'os065', 'ca_pfa3e4'}, ...
    'Pfa', {1e-4, 3e-4, 1e-3, 3e-4, 3e-4}, ...
    'OSRankFraction', {0.75, 0.75, 0.75, 0.65, 0.75}, ...
    'CfarType', {'OS', 'OS', 'OS', 'OS', 'CA'});

replay = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

### CFAR window campaign

```matlab
cases = struct( ...
    'Name', {'baseline', 'guard4_2_train12_4', 'guard4_1_train10_3'}, ...
    'GuardCells', {[6 2], [4 2], [4 1]}, ...
    'TrainCells', {[20 4], [12 4], [10 3]});

replay = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

### Suppression campaign

```matlab
cases = struct( ...
    'Name', {'baseline', 'no_localmax', 'smaller_localmax', 'relaxed_atsc', 'no_notch_guard'}, ...
    'LocalMaxima', {true, false, true, true, true}, ...
    'LMRangeBins', {4, 4, 2, 4, 4}, ...
    'LMDoppBins', {2, 2, 1, 2, 2}, ...
    'ATSCGuardPenaltyDB', {10, 10, 10, 6, 10}, ...
    'ATSCGuardWidthBins', {3, 3, 3, 2, 3}, ...
    'NotchGuardDoppBins', {1, 1, 1, 1, 0});

replay = runDetectorReplaySweep( ...
    replay_path, ...
    'Cases', cases, ...
    'PlotCases', 'all', ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', false, ...
    'Verbose', true);

replay.summary_table
```

## If `out` already exists

If your full run was started with `runBistaticAnalysisSession`, the shortest syntax is:

```matlab
replay_path = out.detector_replay_snapshot.path;
```

Then use `replay_path` in any of the examples above.

## If you ran `analyzeBistaticData.m` directly

Build the replay bundle once from the current workspace:

```matlab
compact_truth_template = truth_diag_input;
if isfield(compact_truth_template, 'rdm_parts')
    compact_truth_template = rmfield(compact_truth_template, 'rdm_parts');
end

detector_replay_input = buildDetectorReplayInput( ...
    config, data_parts, part_start_offsets_s, part_end_offsets_s, part_res, ...
    'SessionID', session_id, ...
    'AnalysisLabel', 'Detector Replay', ...
    'TruthDiagnosticInput', compact_truth_template, ...
    'PartDurationS', part_dur_s, ...
    'TracksLog', tracks_log, ...
    'Verbose', false);

saveDetectorReplayInput(detector_replay_input, 'detector_replay_input.mat');
replay_path = 'detector_replay_input.mat';
```

After that, use `runDetectorReplaySweep(replay_path, ...)`.

## Recommended working style

1. Run one campaign at a time.
2. Look at `replay.summary_table` first.
3. Then inspect the time-series plot for the most promising cases.
4. Keep the tracker out of the loop until detector-vs-truth looks physically reasonable.
