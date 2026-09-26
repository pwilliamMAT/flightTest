# System-engineering reports

Single-file HTML reports on how the testbed is organised as a system and what has been verified about its interfaces. They are **not** members of the accepted report family in `../reports/`, and they are not listed in `../metadata/family_manifest.json` as family reports.

Each report states its question, result, engineering decision, still-unknown items, evidence class, method, code navigation and claim boundary, following `../howToUpdateReports.md`. The controlled system documents themselves (architecture, interface control document, as-built record, change requests, verification log, raw captures) live in flightTest `docs/system/` on `main`; these reports summarise them and do not replace them.

| Report | Question | Evidence dates |
| --- | --- | --- |
| [SystemArchitectureAndCueTasking_V1.html](SystemArchitectureAndCueTasking_V1.html) | How is the passive-radar testbed organised as a system, and does the ADS-B Cue Tasker deliver usable cues to the collection side? Covers the ten software items, ICD Draft B (CT messages 2.0.0), the compressed one-frame encoding decision, the 2026-09-26 live acceptance capture, the MATLAB CueListener and compiled-app probe, and the Pi time-source finding. A message-interface result, not a detection. | 2026-09-25 to 2026-09-26 |
