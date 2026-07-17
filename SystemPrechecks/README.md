# System Precheck

This repo is now organized around a cleaned system-precheck story for a passive-radar startup path.
Newton RF35 is the primary path.
Hudson RF27 is the alternate comparison.

This package is intentionally scoped as a precheck, not end-to-end passive-radar validation.
The supported claims are:

- `illuminator viability`
- `RF front-end capturability`
- `bistatic detectability plausibility`

## Active Working Set

- `generateSystemPrecheckArtifacts.m`
- `helperBuildSystemPrecheckAssumptions.m`
- `helperBuildLinkBudgetDecisionMatrix.m`
- `helperBuildRfBudgetCase.m`
- `helperBuildRFRiskTable.m`
- `helperGetBandpassInsertionLoss.m`
- `helperGenerateSystemPrecheckDeck.m`
- `helperExportTextFigure.m`
- `helperWriteMarkdownTable.m`
- `RFBudget/RFBudget_Newton.m`
- `RFBudget/RFBudget_Hudson.m`
- `RFBudget/RFBudget_Comparative_Analysis.m`
- `RFBudget/RFBudgetModel_Newton.m`
- `RFBudget/RFBudgetModel_Hudson.m`
- `LinkBudget/FlightTest_Bistatic_RadarAndCommsAnalysis.mlx`
- `LinkBudget/FlightTest_BistaticFlightPath_RadarAndCommsAnalysis.mlx`
- `LinkBudget/FM_stationList.mat`
- `LinkBudget/Radio_Tower_List.txt`
- `LinkBudget/PartsList.xlsx`
- `LinkBudget/helperPathlossOverTerrain.m`
- `LinkBudget/helperRadarCoverageTargetGrid.m`
- `LinkBudget/helperGroundAltitude.m`

## Generated Outputs

- `Artifacts/Tables/SystemPrecheckAssumptions.csv`
- `Artifacts/Tables/LinkBudgetDecisionMatrix.csv`
- `Artifacts/Tables/SourceViabilitySummary.csv`
- `Artifacts/Tables/RFBudgetSummary.csv`
- `Artifacts/Tables/DetectabilitySummary.csv`
- `Artifacts/Tables/RFRiskTable.csv`
- `Artifacts/Figures/SystemPrecheck_*.png`
- `Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx`
- `Docs/SystemPrecheckWriteup.md`

## Regeneration Order

1. Run `generateSystemPrecheckArtifacts.m`.
2. Review the generated tables in `Artifacts/Tables`.
3. Use `Docs/SystemPrecheckWriteup.md` as the narrative source.
4. Use `Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx` for the technical deck.

## Working-Set Notes

- `RFBudget/RFBudgetModel_Newton.m` and `RFBudget/RFBudgetModel_Hudson.m` are retained as legacy IF quick-look frequency checks only.
- The retained link-budget live scripts are `supporting`, not final evidence.
- The final evidence path is the generated assumptions, source-viability, RF-summary, detectability, and risk outputs.

## Archive Structure

- `Archive/Autosaves`
- `Archive/OldAnalysis`
- `Archive/ReferenceExamples`
- `Archive/SupersededData`

See `Archive/ArchiveIndex.md` for the exact move list and rationale.
