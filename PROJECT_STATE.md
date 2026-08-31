# Project State

## Objective

Develop and validate the MATLAB passive-radar data-collection and processing
workflow while preserving experimental work on bounded branches.

## Active Milestone

Preserve all unique local work remotely, then prepare clean candidates based on
`origin/main` for an explicit integration decision.

## Verified State

- `origin/main` is `f551338`; local `main` matches it.
- `feature/adsb-stage4b-d` is preserved at `a82c737`.
- `wip/adsb-stage4e-recursive-filter` is preserved at `5327bec`.
- `feature/yagi-investigation` is preserved at `1739055`.
- The checkpoint, Pluto tone-precheck, System Prechecks, azimuth, and synthetic
  branches remain unchanged and synchronized with their remote refs.
- The two azimuth remote refs intentionally point to the same commit.
- `offline-toolbox-eval` has no unique commits and remains local only.

## Validation Evidence

- ADS-B Stage 4B-Post: 33 MATLAB tests passed; Code Analyzer clean.
- ADS-B Stage 4C: 39 MATLAB tests passed; Code Analyzer clean.
- ADS-B Stage 4D: 52 MATLAB tests passed; Code Analyzer clean.
- ADS-B Stage 4E: 11 MATLAB tests and all 17 saved integrity checks passed;
  Code Analyzer clean. It remains research-only pending milestone approval.
- Raw acquisition archives and generated MAT artifacts remain local. Their
  provenance is recorded on the applicable preservation branches.

## Integration Status

No preservation branch has been merged into `main`. The clean integration
candidates are:

| Candidate | Tip | Validation | Readiness |
| --- | --- | --- | --- |
| `integration/repository-stewardship` | this branch | Local settings retained but untracked; raw archives and autosaves ignored | Ready for review |
| `integration/pluto-calibration-prechecks` | `313a8ed` | 10 tests passed; 40 MATLAB files Code Analyzer clean | Software-ready; live hardware gate remains |
| `integration/system-prechecks` | `1a09af1` | Generator plus Newton, Hudson, and comparative analyses ran; 30 MATLAB files Code Analyzer clean | Ready for technical review |
| `integration/adsb-interval-collection` | `10abcd9` | 8 tests passed; Code Analyzer clean | Software-ready; deployment environment should be confirmed |
| `integration/adsb-triggered-capture` | `d4d2e04` | 15 tests passed; 16 non-error Code Analyzer findings remain | Needs cleanup and live preflight before merge |
| `integration/pluto-azimuth-scan` | `0fe6f4d` | Four-bearing dry run and 10 Pluto regressions passed; changed MATLAB files Code Analyzer clean | Depends on Pluto candidate; live scan remains |

The checkpoint, synthetic-data, Yagi, and ADS-B research branches are
preservation-only for the current milestone.

## Next Action

Review the clean candidate diffs and validation matrix, approve the candidates
that should enter `main`, and then merge only those approved candidates.
