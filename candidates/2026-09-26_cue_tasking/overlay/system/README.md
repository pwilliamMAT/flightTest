# System engineering section

The System Engineering section of the FlightTest reporting site. It is **separate from the exploration report family** in `../reports/` (which stays at nine reports and asks "can we do it, and what does it look like"). It presents the testbed as a formal system design process. The pages are not listed in `../metadata/family_manifest.json` as family reports.

The masters stay in flightTest `docs/system/` on `main` (architecture, requirements, ICD, as-built record, change requests, verification log, raw captures). These pages summarise and link to them. The requirements tables are generated from `docs/system/Requirements.md`.

| Page | Step | Purpose |
| --- | --- | --- |
| [index.html](index.html) | 0 | Process overview, decisions, action register, status at a glance |
| [01_MissionAndNeeds.html](01_MissionAndNeeds.html) | 1 | Mission goals, stakeholders, mission needs |
| [02_Requirements.html](02_Requirements.html) | 2 | DRAFT requirements baseline: tree, status counts, full tables |
| [03_ArchitectureAndAllocation.html](03_ArchitectureAndAllocation.html) | 3 | Architecture figure, items, allocation, requirements per item, design rules |
| [04_Interfaces.html](04_Interfaces.html) | 4 | ICD summary: status ladder, message register, conventions, transport |
| [05_VerificationAndTraceability.html](05_VerificationAndTraceability.html) | 5 | Verification activities and the traceability matrix |
| [06_TruthSeparation.html](06_TruthSeparation.html) | 6 | Proposed rule for cued collections and cue-aided association (CR-9) |
| [07_AsBuiltAndConfiguration.html](07_AsBuiltAndConfiguration.html) | 7 | As-built items, deployed configuration, time source, actions |
| [SDR_CT_CueTasking_V1.html](SDR_CT_CueTasking_V1.html) | SDR | Subsystem design record 1: ADS-B Cue Tasker and the verified cue interface |

Every page states its purpose and claim boundary. Status words for requirements and interfaces (Verified, Partial, Proposed) are requirement- or interface-level; none of them is a radar-performance result.
