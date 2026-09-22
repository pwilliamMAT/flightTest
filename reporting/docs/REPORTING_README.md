# FlightTest Reporting Repository

This directory is the source-controlled home for accepted FlightTest reporting knowledge. Its authoritative migration source is the `ManagerReport` archive; the archive remains intact and is not modified by this repository.

## What is here

| Folder | Contents |
| --- | --- |
| `reports/` | The six accepted evidence-family report sources requested for routine report-family work. |
| `explainers/` | The three accepted engineering explainers and the accepted end-to-end human story. |
| `audits/` | Accepted report-family, explainer, and story audits, indexed by `audits_inventory.csv`. |
| `storyboards/` | The accepted manager-slide storyboard and its review artifacts. |
| `metadata/` | Six canonical family metadata files from the promoted TechnicalSummaryFamily release. |
| `prompts/` | Prompt-provenance inventory. No historical approved prompts were recovered from the archive. |
| `scripts/` | Unmodified TechnicalSummaryFamily build and verification sources, indexed by `script_inventory.csv`. |
| `docs/` | Project-specific workflow, presentation, migration, and maintenance guidance. |
| `HardwarePhotos/` | Accepted visual evidence retained solely because the unchanged Hardware and Collection report refers to it by a relative path. |

The `01A`, `01B`, and `02A` explainer asset directories sit beside their unchanged HTML sources in `explainers/` for the same reason.

## Accepted versus source material

The copied HTML, audit, storyboard, and metadata files are accepted artifacts, copied byte-for-byte from the authoritative archive. Report-local images are accepted source evidence necessary to render those unchanged artifacts. They are not regenerated outputs.

This repository intentionally does not contain immutable TechnicalSummaryFamily release histories, staging directories, rendered PowerPoint output, montage images, temporary extraction products, or the historical PowerPoint collection. See `.gitignore`, `migration_plan.md`, and `presentation_inventory.csv`.

Some unchanged HTML links still point to evidence outside this repository:

- Report 05 retains original `file:///` links to external generated analysis artifacts, which are deliberately excluded.
- The end-to-end human story retains original links to the external canonical TechnicalSummaryFamily release.

Those links document original provenance. They were not rewritten because doing so would modify accepted report content.

## Relationship to TechnicalSummaryFamily

`TechnicalSummaryFamily` is an external generated canonical release system. The current promoted release is identified in `metadata/family_manifest.json` as release `20260921_181348`. This repository contains the accepted source knowledge and the six canonical metadata records needed to understand that family; it is not a replacement for the release system and does not contain `TechnicalSummaryFamily_Releases/`.

The scripts in `scripts/` are intentionally unmodified reference sources. They expect the fuller ManagerReport-style workspace and write release and validation artifacts that this repository excludes. Use them to understand the existing packaging contract, not as an instruction to recreate release history here.

## Relationship to the future reusable skill

`flightTest/reporting` is the project-specific example and evidence source. A future `evidence-to-manager-skill` should live separately and own reusable prompts, templates, generic orchestration, and tests. It should consume this layout as an example project without embedding FlightTest-specific claims, paths, or artifacts into the reusable framework.

For a future refresh, update an approved source artifact in this repository, record the review decision, and use a separately governed release workflow. Do not treat generated releases or presentation renders as source material.
