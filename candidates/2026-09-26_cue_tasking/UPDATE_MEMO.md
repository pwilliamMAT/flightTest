# Update memo — 2026-09-26 cue-tasking candidates (INTERIM CHECKPOINT)

Status: work in progress, checkpointed so nothing is lost. Nothing has been promoted; `reporting/` is unchanged and `main` has not been pushed.

## Done so far

- `overlay/systems/SystemArchitectureAndCueTasking_V1.html` + `_assets/` (3 generated SVG figures): new companion report on the system architecture, ICD Draft B, and the verified CT 2.0.0 cue interface.
- `overlay/reports/06_StatusAndFutureWork_V3.html` (from V2 by `scripts/derive_06_V3.py`) and `overlay/reports/02_HardwareAndCollection_V5.html` (from V4 by `scripts/derive_02_V5.py`).
- `overlay/metadata/*` candidate copies (`scripts/derive_metadata.py`), `overlay/index.html`, `overlay/reporting_README.md`, `overlay/systems/README.md`.
- `scripts/summarize_cue_capture.py` reproduces every live-acceptance number from the committed wire capture (all 10 cross-checks match) and writes `generated/cue_capture_summary.json` and the figures.

## Remaining

- Link/asset/well-formedness/restricted-content validation of the merged preview (reporting/ + overlay).
- Final review pass of the three reports.
- Full memo: ownership rationale, evidence class per claim, exact promotion changes, step-6 checklist results, open questions.
