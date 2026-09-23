# Root README Information-Architecture Review

## Classification

The root [`README.md`](README.md) remains the project entry point. This review
classifies only the navigation change proposed in
[`README_update_recommendations.md`](README_update_recommendations.md); it does
not edit the README.

| Current README content | Classification in this pass | Treatment |
| --- | --- | --- |
| Title, purpose, system goals, and minimal prerequisites | Keep | Retain as the root orientation. |
| Reporting and current-status route | Condense | Replace the duplicate paragraph with the proposed `NEW HERE` route and links to the accepted reporting family. |
| Coordinated capture, session sync, and replay instructions | Keep | Preserve all existing instructions. |
| Collection and replay subsystem routes | Link | Retain the root workflow and link to [`TestSetupTesting/README.md`](TestSetupTesting/README.md) and [`BistaticDataAnalysis/`](BistaticDataAnalysis/) as their detailed owners. |
| Hardware/configuration values, performance claims, and engineering narrative | Link | Direct readers to the owning accepted reports rather than expand a second evidence narrative. |
| Detailed subsystem inventories | Condense | Leave them unchanged now; future edits may reduce them only after each supported entry point is confirmed. |
| Procedural material | Move | Deferred. No collection or replay material is moved in this pass. |
| README material | Remove | None. No README material is removed in this pass. |

## Recorded duplication

- **Collection and packaging:** the root README and
  [`TestSetupTesting/README.md`](TestSetupTesting/README.md) both describe
  coordinated capture and synchronization.
- **Replay and diagnostics:** the root README and
  [`BistaticDataAnalysis/`](BistaticDataAnalysis/) both route users into
  packaged-session replay and diagnostic tools.

These duplications are recorded for later ownership decisions. The proposed
README patch explicitly preserves the existing collection and replay
instructions.

## Canonical routes

- Role-based onboarding: [`reporting/docs/START_HERE.md`](reporting/docs/START_HERE.md)
- Engineering entry points: [`reporting/docs/ENGINEERING_INDEX.md`](reporting/docs/ENGINEERING_INDEX.md)
- Repository boundary: [`reporting/docs/REPOSITORY_OWNERSHIP.md`](reporting/docs/REPOSITORY_OWNERSHIP.md)
- Large and external artifacts: [`reporting/docs/SOURCE_MATERIALS.md`](reporting/docs/SOURCE_MATERIALS.md)

## Out of scope

This review does not alter accepted reports, explainers, audits, storyboards,
presentations, MATLAB files, collection workflows, or replay workflows.
