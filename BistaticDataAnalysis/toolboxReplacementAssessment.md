# Toolbox Replacement Assessment

Assessment date: June 26, 2026

## Scope

This memo records the current replacement assessment for offline toolbox-backed variants in the passive radar replay flow. The question is not whether `phased.TDOAEstimator` or `phased.CFARDetector2D` can run in isolation. The question is whether they are viable replacements for the current custom measurement and detector path on the captured hardware data and workload shape used by this repository.

This assessment does not change the supported production workflow. It documents why the current custom CAF/RDM detector and custom measurement extraction remain the supported path.

## Evidence Base

- Captured session: `captures/20260622T102123`
- Detector replay snapshot: `detector_replay_20260622T102123.mat`
- Full-session offline benchmark: `bench_20260622T102123.mat` / `bench_20260622T102123.log`
- Replay-snapshot benchmark attempts: `bench_full_20260622T102123_snapshot.mat` / `bench_full_20260622T102123_snapshot.log`
- Toolbox-TDOA-only replay benchmark: `bench_tdoa_20260622T102123.mat` / `bench_tdoa_20260622T102123.log`
- Full replay toolbox TDOA probe: `tdoa_probe_20260622T102123.mat` / `tdoa_probe_20260622T102123.log`
- Targeted MATLAB profiler slices run on June 26, 2026 against the same replay input:
  - sparse slice: part 7, all 8 detections
  - hotspot slice: part 6, block 4, first 20 detections from a 98-detection block

## Key Finding

`phased.TDOAEstimator` is functionally usable on the captured data in the narrow sense that it returns numeric delay measurements across the replay, but it is not a viable full replacement for the current custom range-delay measurement path on this dataset. The blocker is throughput inside toolbox internals, not a lightweight wrapper issue around the toolbox call.

The practical consequence is straightforward: the current passive radar workflow should remain centered on the custom CAF/RDM detector and custom measurement extraction. Toolbox TDOA should not be treated as the leading replacement track for the production front end.

## Measured Evidence

| Case | Workload | Observed behavior |
| :--- | :--- | :--- |
| Full replay toolbox TDOA probe | 434 detections from `detector_replay_20260622T102123.mat` | Completed in `1489.625 s` total, about `3.432 s` per detection. All 434 refined range values were numeric, but the throughput is not acceptable for a per-detection replacement path. |
| Sparse replay slice | Part 7, 8 detections | Completed in `42.415 s`, about `5.302 s` per detection. Profiler showed `TDOAEstimator.stepImpl` at `40.376 s` of `42.415 s` total, about 95% of wall time. |
| Hotspot replay slice | Part 6, block 4, first 20 detections from a 98-detection block | Completed in `73.737 s`, about `3.687 s` per detection. Profiler showed `TDOAEstimator.stepImpl` at `72.414 s` of `73.737 s` total, about 98% of wall time. |
| Sparse and hotspot profiler hotspots | Same slices as above | The dominant functions were `TDOAEstimator.stepImpl`, `AbstractTDOAEstimator.tdoaspectrum`, `tdoagccphat`, and `findpeaks`. The time concentration stayed inside the toolbox estimation stack rather than in file loading, replay bookkeeping, or wrapper logic. |
| Full-session toolbox CFAR replay | `bench_20260622T102123.mat` on the 15-part `20260622T102123` session | `custom_baseline` completed in `32.613 s`. `toolbox_cfar` completed in `882.480 s` with 516 detections versus 434 on the baseline, so it was also materially slower on the captured replay. |
| Full-scope replay-snapshot attempts | `bench_full_20260622T102123_snapshot.mat` | `toolbox_tdoa` hit `Out of memory.` after `682.200 s`. `toolbox_cfar` hit `Out of memory.` after `742.220 s`. This reinforces that the toolbox variants are not currently production-viable on the captured replay workload. |

## Engineering Conclusion

The present issue is algorithm/workload fit inside the toolbox path on this data, not a simple inefficiency in the surrounding MATLAB wrapper code.

The profiling evidence is the key reason for that conclusion:

- In the sparse slice, roughly 95% of total wall time sat inside `TDOAEstimator.stepImpl`.
- In the hotspot slice, roughly 98% of total wall time sat inside `TDOAEstimator.stepImpl`.
- The expensive subwork then concentrated further inside `tdoaspectrum`, `tdoagccphat`, and peak search.

That means wrapper cleanup alone will not make toolbox TDOA a viable drop-in replacement for a per-detection passive-radar measurement path on this captured dataset.

## Supported Positioning

- The supported production workflow remains the custom CAF/RDM detector plus custom measurement extraction.
- `runOfflineToolboxBenchmark` remains useful as an offline assessment harness, not as a production-path switch.
- Toolbox TDOA is currently a replacement-assessment result, not a pending production migration.
- Toolbox CFAR should also be treated as offline parity characterization only under the current evidence base.

## Narrow Future Work

If toolbox TDOA work continues, it should be framed as a `localized_refinement_experiment`, not as the main replacement track.

Priority order:

1. `replacement_assessment`: keep evidence-building tight around the known cost issue.
2. `localized_refinement_experiment`: only revisit toolbox TDOA if the goal is a small local refinement around an already known CAF-derived delay guess.

Any additional runs should stay narrow:

- crop the TDOA input to local support around the CAF-derived delay hypothesis
- use benchmark-only detection caps and scoped replay slices for profiling
- avoid rerunning full-session toolbox TDOA replacement tests unless per-call cost drops materially first
- keep toolbox CFAR work limited to parity characterization, not to a speed-improvement path
