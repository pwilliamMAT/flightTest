# Sensor Fusion and Tracking Toolbox Skill Use

## 2026-08-31 — `matlab-import-tracking-data`

- Files read: `SKILL.md`, `references/output-formats.md`,
  `references/code-patterns.md`, `references/time-and-units.md`, and
  `references/visualization.md`.
- Task: adapt archived ADSB-remoter SBS/BaseStation files for passive-radar
  opportunity planning.
- Effect: ADS-B is retained as UTC, geodetic trajectory truth in the existing
  `loadADSBTruth` schema. The adapter does not create `objectDetection`
  objects, and bistatic geometry is computed only after import.
- Result: `loadADSBRemoterArchive`,
  `buildManualADSBOpportunityTable`, and the associated trajectory
  import, CPA opportunity visualization, and regression tests implement this
  boundary. The live-console observer and emitter files now match the MATLAB
  599 MHz geometry and RF assumptions.
- Verification: Code Analyzer reported no findings across the five integration
  files. Four of six MATLAB tests passed, including CSV/gzip archive mapping
  and configuration parity; the two geometry/BiSNR tests were blocked by a
  Mapping Toolbox license checkout error (`-15.3`), not by a failed assertion.

## 2026-09-01 — `matlab-import-tracking-data`

- Files read: pinned `SKILL.md`.
- Task: resume the interrupted offline verification of the ADSB-remoter
  archive adapter and manual passive-radar opportunity workflow.
- Effect: retained the existing UTC geodetic trajectory-truth boundary and
  verified it without changing the import schema or creating detections.
- Result: all 6 `ADSBRemoterIntegrationTest` tests pass in MATLAB R2026a,
  including CSV/gzip import, configuration parity, project geometry and
  Doppler parity, and assumption-based BiSNR ranking. Code Analyzer reports
  no findings in the five ADS-B integration files.

## 2026-09-01 — `matlab-import-tracking-data`

- Files read: pinned `SKILL.md`; existing `loadADSBTruth.m`,
  `loadADSBRemoterArchive.m`, and session-manifest helpers.
- Task: diagnose the damaged August archive and add an ADS-B-only acceptance
  gate before any N320 test.
- Effect: retained ADS-B as UTC geodetic trajectory truth and kept acquisition
  outside the adapter. Readiness now checks archive integrity, time-window
  overlap, position-fix density, update cadence, velocity availability, and
  endpoint-censored observed CPA before presenting bounded manual candidates.
- Result: `runADSBReadinessTest` and `plotADSBReadiness` return PASS/HOLD
  evidence without creating `objectDetection` data or triggering acquisition.
  Six focused tests pass. Of the four intact August Yagi archives, sessions
  `20260827T141524` and `20260827T141921` pass; the two earlier sessions hold
  because no candidate has an interior observed CPA. The truncated
  `20260827T135456` archive is rejected with a dedicated diagnostic.
