# Repository Cleanup Recommendations

These are recommendations only. No source material was moved, renamed, archived, or deleted during this migration.

## Future folder improvements

- Keep `reporting/` as the project-knowledge boundary. Keep generic report-generation logic, reusable prompts, templates, and skill tests in a separate `evidence-to-manager-skill` repository or package.
- On the next approved report refresh, introduce a deliberate source-asset strategy. The current raw HTML has archival relative paths, so any path normalization must be part of a reviewed content revision, not a migration-side rewrite.
- Maintain one accepted version per report/explainer in the active source folders. Put only reviewed superseded sources into a clearly dated external archive after the team approves that action.
- Keep TechnicalSummaryFamily releases externally generated and immutable. Store only the small canonical metadata interface needed for source navigation in this repository.
- Recover prompt provenance before adding prompt files. New prompts should state their accepted-output target, evidence inputs, review expectations, and version.

## Duplicates and superseded versions to review later

- Root-level older report versions are candidates for archival classification: pre-V2 `01`, pre-V4 `02`, pre-V4 `01A`, V1 `01B`, pre-V2 `04`, pre-V2 `06`, and the pre-V2 end-to-end human story.
- `IlluminatorSelection_Explainer.html`, `ReceiveChainDesign_Explainer.html`, and `SyntheticEchoGeneration_Explainer.html` are older explainer names/versions relative to the accepted numbered explainers.
- `PassiveHDTVAircraftLocalization_ManagerReviewV2.pptx` and `PassiveHDTVAircraftLocalization_ManagerReviewV2(2).pptx` should receive a content and hash comparison before either is called a duplicate. Both remain external until then.
- `_full_deck_work`, `_human_story_work`, `_pilot_work`, and `_pilot_v2_work` should be classified as reproducible work areas, archive-only history, or still-active work before any future cleanup.
- `TechnicalSummaryFamily_Releases` contains failed staging directories and superseded promoted releases. Preserve them as release-process evidence; do not add them to Git.

## Potential future archival candidates

- Superseded source-report and explainer versions once their replacement and review decision are confirmed.
- Pilot PowerPoint decks and montage files after their inventory entry identifies the accepted reference deck.
- Experimental audit drafts and working inventories that are neither referenced by canonical metadata nor needed to reproduce an accepted decision.

Before any archival action, record the decision, destination, replacement artifact, and reason. Do not delete historical evidence as routine cleanup.
