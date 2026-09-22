# Reporting Repository Migration Plan

## Scope and provenance

- **Authoritative source archive:** `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\ManagerReport`
- **Repository destination:** `C:\Users\pwilliam\agenticProjects\flightTest\reporting`
- **Migration action:** copy only. No ManagerReport files were moved, deleted, regenerated, or edited.

## Files copied

| Destination | Accepted files copied |
| --- | --- |
| `reports/` | `01_NorthStarAndMotivation_V2.html`, `01A_IlluminatorSelection_V4.html`, `01B_ReceiveChainDesign_V2.html`, `02_HardwareAndCollection_V4.html`, `02A_SyntheticEchoGeneration_V1.html`, `03_AnalysisPipelineAndGateRebuild.html`, `04_MitigationAndMapRateRecovery_V2.html`, `05_StrongestEvidence_G4RRecoveryStudy.html`, `06_StatusAndFutureWork_V2.html` |
| `explainers/` | `FlightTest_EndToEnd_HumanStory_V2.html` |
| `audits/` | `01A_IlluminatorSelection_V4_audit.md`, `01B_ReceiveChainDesign_V2_audit.md`, `02A_audit.md`, `FlightTest_EndToEnd_HumanStory_V2_Audit.md`, `cross_explainer_review.md`, `cross_report_audit.md`, `final_polish_audit.md`, `report_family_upgrade_audit.md`, `report_family_gap_review.md`, `report_family_gap_review_audit.md`, `report_family_story_spine.html` |
| `storyboards/` | `manager_slide_storyboard.csv`, `manager_slide_storyboard_review.html`, `storyboard_audit.md` |
| `metadata/` | `family_manifest.json`, `family_evidence_catalog.csv`, `family_handoff_catalog.csv`, `family_visual_catalog.csv`, `family_code_navigation.csv`, `family_known_gaps.md` |
| `scripts/` | `buildTechnicalSummaryFamily.m`, `verifyTechnicalSummaryFamily.m` |
| Supporting accepted visual evidence | `reports/01A_IlluminatorSelection_assets/`, `reports/01B_ReceiveChainDesign_assets/`, `reports/02A_SyntheticEchoGeneration_assets/`, and `HardwarePhotos/` |

The asset directories are retained so that copied HTML continues to use its original relative evidence paths where possible. They were copied without changing the HTML.

## Files intentionally excluded from Git

| Excluded material | Reason |
| --- | --- |
| `_full_deck_work/`, `_human_story_work/`, `_pilot_work/`, `_pilot_v2_work/` | Temporary or exploratory working areas, not accepted source knowledge. |
| `*_rendered/`, PowerPoint render directories, and montage files | Regenerable presentation output. |
| `TechnicalSummaryFamily_Releases/` and staging directories | Immutable release history and generated packaging output remain in the external release system. |
| Temporary extraction directories and extraction assets | Regenerable intermediates. The ignore rules intentionally do not exclude accepted report-local asset folders. |
| Historical `.pptx` files | Presentation history is documented in `docs/presentation_inventory.csv`; none was automatically copied. |

## Material left in ManagerReport

All original files remain in the authoritative archive, including every copied source file. The following categories intentionally remain there:

- Superseded report and explainer versions, including older `01`, `01A`, `01B`, `02`, `04`, `06`, and end-to-end-story variants.
- The full generated `TechnicalSummaryFamily` release interface and all immutable `TechnicalSummaryFamily_Releases` history.
- Additional companion inventories, validation records, raw evidence ledgers, experimental audits, and intermediate working products not needed for the accepted repository view.
- PowerPoint history, rendered decks, montage images, and presentation-build work areas.
- External generated analysis artifacts referenced by Report 05.
- Unrecovered historical workflow prompts. No prompt files were found in the source archive, so none was copied or represented as accepted.

## Reasoning

The destination holds project knowledge that is stable enough to review, refresh, and use as a skill example. Generated release packages and presentation outputs stay external so Git history remains focused on accepted source material and future report changes.
