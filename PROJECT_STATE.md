# Project State

## Objective

Develop a passive-radar collection workflow that produces reproducible
hardware-commissioning evidence without making aircraft-detection claims.

## Active Milestone

Hardware commissioning and capture provenance: require operator-recorded
physical setup details and explicit channel mapping for local and
ADS-B-triggered N320 capture packages.

## Definition of Done

- Local and live-triggered capture paths fail closed without setup notes.
- Manifest version 3 records the notes verbatim and preserves each stored
  channel's N320 port, semantic role, and gain.
- Offline provenance, precheck, ADS-B-readiness, trigger, and shell checks
  pass, subject only to documented external dependencies and frozen-baseline
  discrepancies.
- No hardware collection, detector tuning, or detection interpretation is
  performed in this software milestone.

## Verified Progress

- This worktree is based on `feature/next-collection-prep` at `a1a67ae`.
  The ADS-B-triggered workflow from `d4d2e04` was reconciled here as
  `08ea2a8`, retaining both README documentation changes.
- `OperatorSetupNotes`, explicit ordered `channel_mapping`, and manifest
  version 3 are implemented in the local, shell, and live-triggered paths.
- The commissioning runbook and concept index describe the required physical
  provenance template and evidence-only collection boundary.
- Passed in this worktree on 2026-09-16:
  `CaptureProvenanceTest` (6/6),
  `runPassiveRadarHardwarePrecheckTest` (21/21),
  `ADSBReadinessTest` (6/6),
  `ADSBRemoterIntegrationTest` (6/6), and focused live-trigger provenance
  tests (2/2).
- The complete `ADSBTriggeredCaptureSessionTest` result is 12/16 passed; its
  four failures are the frozen-baseline cases recorded below.
- `git diff --check` passes. Shell syntax and option-parser checks passed in
  this integration session.

## Current Blocker

- The complete trigger test class retains four frozen score/preview
  mismatches (for example score `0.616359956856437` versus frozen
  `0.607586160470972`). Focused provenance behavior passes; do not update
  the frozen baseline without a separate investigation.

## Next Action

Pull this integration branch on the testing machine and run the commissioning
sequence without detector tuning or aircraft-detection interpretation. Review
the frozen trigger-baseline discrepancy separately before treating the full
trigger regression suite as green.
