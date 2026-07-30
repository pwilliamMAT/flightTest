# System Precheck

This repo is organized around a cleaned system-precheck story for a passive-radar startup path.
Newton RF35 is the primary path.
Hudson RF27 is the alternate comparison.
The deterministic coverage package now keeps two explicit geometry branches:

- the `recovered-ROI baseline`
- the additive `WestCorridor` due-west surveillance check

This package is intentionally scoped as a precheck, not end-to-end passive-radar validation.
The supported claims are:

- `illuminator viability`
- `RF front-end capturability`
- `bistatic detectability plausibility`

## Active Working Set

- `generateSystemPrecheckArtifacts.m`
- `helperBuildSystemPrecheckAssumptions.m`
- `helperBuildDeterministicCoverageData.m`
- `helperBuildBistaticTargetPathSummary.m`
- `helperBuildDetectabilitySummary.m`
- `helperBuildSystemPrecheckTextSummaries.m`
- `helperBuildLinkBudgetDecisionMatrix.m`
- `helperBuildRfBudgetCase.m`
- `helperBuildRFRiskTable.m`
- `helperBuildSystemPrecheckSlideSpecs.m`
- `helperExportSystemPrecheckVisuals.m`
- `helperGenerateSystemPrecheckDeck.m`
- `helperOpenSystemPrecheckRfAnalyzer.m`
- `helperDisplayArtifactImage.m`
- `helperGetBandpassInsertionLoss.m`
- `helperReadArtifactTable.m`
- `helperReadTextSummary.m`
- `helperRunScriptIsolated.m`
- `helperWriteTextSummary.m`
- `helperWriteMarkdownTable.m`
- `Docs/SystemPrecheckOverview.m`
- `Docs/SystemPrecheckWriteup.md`
- `RFBudget/RFBudget_Newton.m`
- `RFBudget/RFBudget_Hudson.m`
- `RFBudget/RFBudget_Comparative_Analysis.m`
- `RFBudget/RFBudgetModel_Newton.m`
- `RFBudget/RFBudgetModel_Hudson.m`
- `LinkBudget/FlightTest_Bistatic_RadarAndCommsAnalysis.mlx`
- `LinkBudget/FlightTest_BistaticFlightPath_RadarAndCommsAnalysis.mlx`
- `LinkBudget/PartsList.xlsx`
- `LinkBudget/helperPathlossOverTerrain.m`
- `LinkBudget/helperRadarCoverageTargetGrid.m`
- `LinkBudget/helperGroundAltitude.m`

## Generated Outputs

- `Artifacts/Tables/SystemPrecheckAssumptions.csv`
- `Artifacts/Tables/BistaticTargetPathSummary.csv`
- `Artifacts/Tables/BistaticTargetPathSummary_WestCorridor.csv`
- `Artifacts/Tables/LinkBudgetDecisionMatrix.csv`
- `Artifacts/Tables/SourceViabilitySummary.csv`
- `Artifacts/Tables/RFBudgetSummary.csv`
- `Artifacts/Tables/DetectabilitySummary.csv`
- `Artifacts/Tables/DetectabilitySummary_WestCorridor.csv`
- `Artifacts/Tables/RFRiskTable.csv`
- `Artifacts/Summaries/SystemPrecheckAssumptionsSummary.txt`
- `Artifacts/Summaries/SystemPrecheckDecisionSummary.txt`
- `Artifacts/Summaries/SystemPrecheckRFRiskSummary.txt`
- `Artifacts/Summaries/SystemPrecheckBoundaries.txt`
- `Artifacts/Figures/SystemPrecheck_GeometryOverview.png`
- `Artifacts/Figures/SystemPrecheck_SourceViability.png`
- `Artifacts/Figures/SystemPrecheck_RFChainOverview.png`
- `Artifacts/Figures/SystemPrecheck_RFLevelsAndHeadroom.png`
- `Artifacts/Figures/SystemPrecheck_RoiTargetGridContext.png`
- `Artifacts/Figures/SystemPrecheck_NewtonDeterministicSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_HudsonDeterministicSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_CombinedDeterministicSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_RegionalSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_DetectabilityPlausibility.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridorSetup.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridor_NewtonSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridor_HudsonSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridor_CombinedSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridor_RegionalSNRCoverage.png`
- `Artifacts/Figures/SystemPrecheck_WestCorridor_Detectability.png`
- `Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx`
- `Artifacts/Figures/SystemPrecheck_RFBudgetAnalyzer_Newton.png` (manual optional capture for the deck)
- `Docs/SystemPrecheckOverview.m`
- `Docs/SystemPrecheckWriteup.md`

## Regeneration Order

1. Run `generateSystemPrecheckArtifacts.m`.
2. Review the generated recovered-ROI baseline and `WestCorridor` tables in `Artifacts/Tables`.
3. Review the shared, recovered-ROI baseline, and `WestCorridor` figures in `Artifacts/Figures`.
4. If the RF Budget Analyzer slide is needed, run `helperOpenSystemPrecheckRfAnalyzer("Newton")`, capture the native `show(budget)` view manually, save it to `Artifacts/Figures/SystemPrecheck_RFBudgetAnalyzer_Newton.png`, and rerun the generator.
5. Use `Docs/SystemPrecheckOverview.m` for the Live Editor walkthrough.
6. Use `Docs/SystemPrecheckWriteup.md` as the narrative source.
7. Use `Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx` for the technical deck.

If `SystemPrecheck_TechnicalStory.pptx` is open in PowerPoint, the generator writes a timestamped fallback deck in `Artifacts/Decks` instead of overwriting the locked file.

## Recovery Note (2026-07-22)

- Recovered the prior working session by reviewing `ProjectStatus.md`, `futureSteps.md`, `Docs/SystemPrecheckWriteup.md`, and the active RF-budget scripts.
- Verified `generateSystemPrecheckArtifacts.m` is Code Analyzer clean and runs successfully in MATLAB R2026a with the installed RF, Radar, Phased Array, and Signal Processing toolboxes.
- Regeneration on `2026-07-22` refreshed `Artifacts/Figures/SystemPrecheck_*.png` and `Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx`.
- The main unresolved technical item at recovery time was the Newton-specific bistatic rerun that still inherited the Hudson placeholder.

## Session Update (2026-07-23)

- Replaced the inherited Newton/Hudson target-path placeholder with a deterministic `longley-rice` rerun over the recovered saved-live-script ROI.
- Added `helperBuildBistaticTargetPathSummary.m` and the generated `Artifacts/Tables/BistaticTargetPathSummary.csv` output to the active working set.
- Current mean target-path powers are `-67.56 dBm` for Newton and `-70.62 dBm` for Hudson.

## Session Update (2026-07-29)

- Replaced the text-only PNG summary path with generated `.txt` files under `Artifacts/Summaries`.
- Updated the PPT generator so summary slides use native PowerPoint text placeholders instead of screenshot images.
- Added `Docs/SystemPrecheckOverview.m` as the Live Editor-compatible `.m` walkthrough that runs the generator plus the Newton, Hudson, and comparative RF analyses inline.

## Session Update (2026-07-30)

- Expanded the generated deck from a short text summary into a fixed-order visual review artifact for the pre-hardware data-acquisition basis.
- Added deterministic geometry, ROI, Newton/Hudson coverage, combined coverage, and regional SNR figures built directly from the cleaned Longley-Rice rerun.
- Replaced the overloaded RF summary slide with separate `RFChainOverview` and `RFLevelsAndHeadroom` figures that use MATLAB-default white-background styling.
- Added `helperOpenSystemPrecheckRfAnalyzer.m` and the fixed manual screenshot path for the native RF Budget Analyzer component-view slide.
- Added fallback deck generation to a timestamped `.pptx` when the canonical deck file is locked by an open PowerPoint session.
- Refactored the deterministic coverage helper so it returns named analysis bundles and added the additive `WestCorridor` due-west surveillance branch.
- Added separate `BistaticTargetPathSummary_WestCorridor.csv`, `DetectabilitySummary_WestCorridor.csv`, and `SystemPrecheck_WestCorridor_*.png` artifacts while preserving the recovered-ROI baseline outputs unchanged numerically.
- Updated the deck, walkthrough, write-up, README, and concepts index so the recovered-ROI baseline evidence and the due-west surveillance check are explicitly separated.

## Working-Set Notes

- `RFBudget/RFBudgetModel_Newton.m` and `RFBudget/RFBudgetModel_Hudson.m` are retained as legacy IF quick-look frequency checks only.
- The retained link-budget live scripts are `supporting`, not final evidence.
- The final evidence path is the generated assumptions, shared geometry/RF figures, recovered-ROI baseline coverage outputs, `WestCorridor` outputs, detectability summaries, text summaries, risk table, and deck.
- The native RF Budget Analyzer slide is optional until `Artifacts/Figures/SystemPrecheck_RFBudgetAnalyzer_Newton.png` is populated manually.

## Archive Structure

- `Archive/Autosaves`
- `Archive/OldAnalysis`
- `Archive/ReferenceExamples`
- `Archive/SupersededData`

See `Archive/ArchiveIndex.md` for the exact move list and rationale.
