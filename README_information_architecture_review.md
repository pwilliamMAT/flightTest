# Root README Information-Architecture Review

## Scope and finding

The root [`README.md`](README.md) currently serves three different audiences at
once:

1. a person deciding what the project is and whether the evidence supports it;
2. an operator collecting or replaying a session; and
3. a developer debugging a specific MATLAB stage.

It contains valuable material, but the detailed operating manual dominates the
onboarding path. The root should become a concise orientation and routing page.
Accepted reports should remain the primary explanation of engineering evidence
and status; subsystem READMEs should own procedures.

## Recommended ownership of current README content

| Current root content | Best home | Root README treatment |
| --- | --- | --- |
| Project title, passive-bistatic purpose, and research/claim boundary | Root README | Keep as a short opening statement. |
| Link to accepted reports, end-to-end story, and current status | Root README plus `reporting/` | Keep only a short “read first” route; `reporting/reporting_README.md` and `reporting/docs/START_HERE.md` own the detailed report navigation. |
| System goals | Root README | Retain a compact list if it is still current; do not repeat implementation details. |
| Hardware inventory, locations, transmitter, baseline, coverage, and performance numbers | Report 02 and its source evidence | Replace the detailed list with a link to Hardware and Collection. Configuration-dependent values should not be maintained as root-README facts. |
| Coordinated-capture instructions, option-by-option shell syntax, Pi recovery behavior, and sync troubleshooting | `TestSetupTesting/README.md` | Move the procedural detail here. Keep one supported collection-command link at the root. |
| Session analysis, direct-path checks, truth diagnostics, and detector-replay examples | A `BistaticDataAnalysis/README.md` or existing session checklists | Move the procedural detail here. The root should link to the supported session entry point. |
| Data-collection, quality, CAF, localization, and batch-processing inventories | Subsystem READMEs | Keep only a short subsystem map at the root; detailed file lists belong beside the code. |
| Quick-start commands | Root README and subsystem READMEs | Root: one onboarding path. Subsystems: executable, environment-specific commands. |
| System-performance table | Report 02, Report 05, and evidence catalog | Do not present configuration- or evidence-dependent metrics as timeless root facts. Link to the owning report. |
| Software and Raspberry Pi requirements | Root README for minimal prerequisites; subsystem READMEs for operational setup | Keep a concise prerequisites pointer; put versioning, services, and platform setup with the relevant subsystem. |
| Workflow diagram and key-technique explanations | Report 03 and `reporting/docs/ENGINEERING_INDEX.md` | Link to the gate/pipeline report and topic index instead of maintaining a second engineering narrative. |
| Literature references | Report-local references and source-material index | Keep only a pointer when references are needed for onboarding. |

## What belongs in `reporting/`

`reporting/` already contains the accepted, versioned technical family and
should remain the primary location for:

- claim boundaries, current status, decisions, and evidence interpretation;
- the accepted end-to-end onboarding narrative;
- report-family navigation and audit records;
- report-local visual evidence and the canonical metadata catalogs; and
- pointers to external source artifacts used to build or support a report.

The root README should not restate report findings. It should direct readers to:

- [`reporting/docs/START_HERE.md`](reporting/docs/START_HERE.md) for managers
  and new engineers;
- [`reporting/docs/ENGINEERING_INDEX.md`](reporting/docs/ENGINEERING_INDEX.md)
  for technical contributors; and
- [`reporting/reporting_README.md`](reporting/reporting_README.md) for the
  canonical nine-report family.

## What belongs in source-material references

Large, external, or provenance-sensitive artifacts should be listed rather
than copied into Git. Examples already referenced by the accepted material
include:

- `LinkBudgetProgress.pptx`;
- `FlightTest_RFBudgetAnalysis.pptx`;
- `MountingDiagramParkingLot.pptx`;
- the G4-R close-target atlas bundle in `PassiveBistaticRestart`;
- capture archives and raw baseband packages; and
- historical manager-review presentation decks.

[`reporting/docs/SOURCE_MATERIALS.md`](reporting/docs/SOURCE_MATERIALS.md)
records their purpose, known location, repository owner, and consumers. Use a
SharePoint or OneDrive URL when one is available; do not add a binary copy to
this repository merely to make a report link convenient.

## Duplicated or competing navigation

| Topic | Current duplication | Recommended resolution |
| --- | --- | --- |
| Coordinated capture and session packaging | Root README and `TestSetupTesting/README.md` both describe the workflow in depth. | Let `TestSetupTesting/README.md` own the operating procedure; retain one root link and one supported command. |
| Session analysis and replay | Root README gives a full procedure while `BistaticDataAnalysis/` contains several checklists and function-level guides. | Establish one subsystem entry README or link page; retain only the route from the root. |
| Hardware and performance statements | Root README, `TestSetupTesting/README.md`, and accepted reporting material all describe system characteristics. | Report 02 owns evidence and configuration qualification; subsystem docs own how to run checks. |
| Project status | Root README’s reporting paragraph, `reporting/reporting_README.md`, Report 06, and external project state can be read as competing status sources. | Report 06 is the report-family status view. The active state of the reconstruction work remains in `PassiveBistaticRestart/PROJECT_STATE.md`. Link explicitly to each purpose. |
| Pipeline explanation | Root workflow diagram, `TestSetupTesting` CAF descriptions, and Report 03 describe overlapping pipelines. | Report 03 owns the gate narrative; `ENGINEERING_INDEX.md` distinguishes FlightTest operational replay from the PassiveBistaticRestart gate pipeline. |

## Navigation defects to address during a later README edit

- The root README has non-printing control characters immediately before the
  `TestSetupTesting/` and `ADSB_GPS/` headings. Remove them when the README is
  next edited.
- `BistaticDataAnalysis/` is a primary session-analysis subsystem but has no
  dedicated README. Its operational route is currently spread across the root
  README and checklist files.
- The root reports a mixture of current and historical configuration values.
  Link to the accepted evidence rather than treating those values as stable
  onboarding facts.

## Recommended transition

Do not remove procedural material until its destination is confirmed and
linked. The first safe change is the small `NEW HERE` section proposed in
[`README_update_recommendations.md`](README_update_recommendations.md). It
creates an immediate orientation path without changing any report, explainer,
or existing operating procedure.
