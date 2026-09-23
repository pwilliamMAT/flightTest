# FlightTest Reporting

Start here for the accepted technical report family, the latest project status, and the materials needed to get up to speed.

**Open rendered reports:** [FlightTest reporting site](https://pwilliammat.github.io/flightTest/) — browser view; report links there open in a new tab.<br>
**Latest status:** [Report 06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html)<br>
**Current strongest controlled evidence:** [Report 05 — G4-R Recovery Study](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html)
**Canonical family mapping and claim boundaries:** [family_manifest.json](metadata/family_manifest.json)

GitHub's repository file view intentionally displays HTML source rather than rendering it. Use the hosted reporting site for readable reports; this repository index remains the version-controlled source guide.

## Canonical nine-report family

Read the accepted family in order. Each report owns one question, result, decision, and claim boundary.

| ID | Accepted report | What it covers |
| --- | --- | --- |
| 01 | [North Star and Motivation](https://pwilliammat.github.io/flightTest/reports/01_NorthStarAndMotivation_V2.html) | Why the project is worth pursuing and why claims must be measurement-led. |
| 01A | [Illuminator Selection](https://pwilliammat.github.io/flightTest/reports/01A_IlluminatorSelection_V4.html) | Historical illuminator, channel, site, and observation-geometry screening. |
| 01B | [Receive-Chain Design](https://pwilliammat.github.io/flightTest/reports/01B_ReceiveChainDesign_V2.html) | How predicted signal conditions shaped the receive-chain design. |
| 02 | [Hardware and Collection](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) | Installed collection infrastructure and its qualification boundary. |
| 02A | [Synthetic Echo Generation](https://pwilliammat.github.io/flightTest/reports/02A_SyntheticEchoGeneration_V1.html) | Declared synthetic truth and bounded paired replay. |
| 03 | [Analysis Pipeline and Gate Rebuild](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html) | The G1–G10 pipeline gates and what they protect. |
| 04 | [Mitigation and Map-Rate Recovery](https://pwilliammat.github.io/flightTest/reports/04_MitigationAndMapRateRecovery_V2.html) | Recovery work, including the retained R5A failure. |
| 05 | [Strongest Evidence: G4-R Recovery Study](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) | The strongest current controlled synthetic diagnostic evidence. |
| 06 | [Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) | Current blockers, decisions, and next evidence actions. |

## Useful companion material

- [End-to-end human story](https://pwilliammat.github.io/flightTest/explainers/FlightTest_EndToEnd_HumanStory_V2.html) — an onboarding narrative that connects the nine reports.
- [Engineering story spine](https://pwilliammat.github.io/flightTest/audits/report_family_story_spine.html) — the short family-level story map.
- [Canonical gap review](audits/report_family_gap_review.md) and [known gaps](metadata/family_known_gaps.md) — current limitations and unresolved evidence.
- [Manager-slide storyboard](https://pwilliammat.github.io/flightTest/storyboards/manager_slide_storyboard_review.html) — accepted presentation planning; no presentation binary is stored here.
- [Accepted audit inventory](audits/audits_inventory.csv), [workflow summary](docs/workflow_summary.md), and [presentation inventory](docs/presentation_inventory.csv).
- [How to update accepted reports](howToUpdateReports.md) — maintainer guidance for candidate review, acceptance, validation, and GitHub Pages publication.

## Repository structure and scope

| Folder | Contents |
| --- | --- |
| `reports/` | All nine accepted members of the canonical technical report family. |
| `explainers/` | The accepted end-to-end human story. |
| `audits/` | Accepted report-family, explainer, and story audits. |
| `storyboards/` | Accepted manager-slide storyboard artifacts. |
| `metadata/` | Canonical family map, evidence, handoff, visual, code-navigation, and known-gap records. |
| `prompts/` | Prompt-provenance inventory; no approved historical prompt files were recovered. |
| `scripts/` | Unmodified TechnicalSummaryFamily build and verification sources. |
| `docs/` | Workflow and presentation-reference documentation. |

Accepted report-local visual evidence remains with the reports, and `HardwarePhotos/` is retained because the unchanged hardware report links to it. These are source evidence, not regenerated outputs.

The authoritative migration source remains the `ManagerReport` archive, which was not modified. This repository intentionally excludes immutable release histories, staging directories, rendered PowerPoint output, montages, temporary extraction products, and historical presentation binaries; see `.gitignore` and [migration_plan.md](migration_plan.md).

Some accepted HTML retains original external provenance links. Report 05 refers to excluded external generated analysis artifacts, and the end-to-end story refers to the external canonical release. Those links have not been rewritten because accepted report content is preserved unchanged.

## Relationship to TechnicalSummaryFamily and the reusable skill

The current promoted TechnicalSummaryFamily release is `20260921_181348`, identified in [family_manifest.json](metadata/family_manifest.json). This repository contains accepted project knowledge and the small canonical metadata interface; it is not the immutable release system.

For future reuse, keep the FlightTest-specific corpus here and keep generic prompts, templates, orchestration, and tests in the separate `evidence-to-manager-skill` framework. Do not treat generated releases or presentation renders as source material.
