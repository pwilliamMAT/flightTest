# FlightTest Source Materials

This index records large or external artifacts that support the accepted
reports. It is a locator, not a request to copy materials into Git.

“Owner” below means repository or evidence-system ownership, not an assigned
individual. The listed OneDrive paths were recovered from report metadata; no
SharePoint web URL is currently recorded. Replace a local path with the
approved SharePoint/OneDrive link when one becomes available.

| Name | Purpose | Where it lives | Owner | Used by reports | Used by code |
| --- | --- | --- | --- | --- | --- |
| `LinkBudgetProgress.pptx` | Historical link-budget, illuminator-comparison, and RF Budget Analyzer source slides. | External OneDrive source: `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\LinkBudget\LinkBudgetProgress.pptx` | FlightTest reporting/planning source | 01A, 01B | Original link-budget Live Script and RF-design workflow; report metadata points to the external source. |
| `FlightTest_RFBudgetAnalysis.pptx` | Historical RF-budget analysis and receive-chain context. | External OneDrive source: `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\RFBudget\FlightTest_RFBudgetAnalysis.pptx` | FlightTest reporting/planning source | 01B | External RF-budget analysis sources; local supporting data includes `SystemPrechecks/RFBudget/DTV_RFBudgetAnalysis.mat`. |
| `MountingDiagramParkingLot.pptx` | Installed/desired receiver architecture and parking-lot mounting design. | External OneDrive source: `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\MountingDiagramParkingLot.pptx` | FlightTest collection/reporting source | 01B, 02 | Collection and hardware-planning context; no runtime code dependency. |
| G4-R close-target atlas bundle | Authoritative controlled synthetic recovery study, condition manifest, summary, maps, and thumbnails. | External sibling repo: `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\artifacts\20260622T102123\G4_R_Close_Target_Atlas_Recovery\20260918T134014380Z\` | PassiveBistaticRestart | 02A, 05, 06 | `runG4RCloseTargetAtlasRecoveryStudy.m` and atlas helpers in PassiveBistaticRestart. |
| G4-R map-rate / R5A bundles | Compact formal gate and recovery records, including retained R5A failure evidence. | External sibling repo under `PassiveBistaticRestart\artifacts\20260622T102123\G4_R_*` | PassiveBistaticRestart | 03, 04, 06 | `runG4RMapRateValidity.m`, `runG4RMapRateMatrix.m`, and recovery helpers. |
| Capture archives and packaged sessions | Raw dual-channel IQ, ADS-B truth, logs, and manifests used for collection/replay. | Working collection paths include `captures\yagi-august-data\SurvYagiCaptures\`; an untracked local archive is `TestSetupTesting\SurvYagiCaptures.zip`. Long-term copies should be SharePoint/OneDrive artifacts, not Git blobs. | FlightTest collection | 02; referenced context for 03–06 | Capture scripts in `TestSetupTesting/`; operational replay in `BistaticDataAnalysis/`; gate studies consume compatible session packages in PassiveBistaticRestart. |
| Hardware photos | Photographic evidence retained for the accepted hardware report. | Versioned report-local files: `reporting/HardwarePhotos/` | FlightTest reporting | 02 | No runtime code dependency. |
| Manager-review presentation decks | Historical and accepted communication references; not routine report sources. | External `ManagerReport` archive; inventory in [`presentation_inventory.csv`](presentation_inventory.csv) | FlightTest reporting archive | Family-level communication reference | No runtime code dependency. |

## Handling rules

- Prefer the approved SharePoint or OneDrive URL when sharing one of these
  items. Do not commit a second binary copy to improve a Markdown link.
- Keep raw IQ, complete map collections, generated decks, and other large
  outputs out of ordinary source-control changes.
- Link reports to a stable summary, manifest, or stored external artifact
  rather than regenerating a report-local replacement.
- If an artifact moves, update this table and the relevant metadata catalog;
  do not silently rewrite accepted report content.

## Related navigation

- Accepted reports and current status: [`../reporting_README.md`](../reporting_README.md)
- Code and data entry points: [Engineering Index](ENGINEERING_INDEX.md)
- Two-repository boundary: [Repository ownership map](../../repository_ownership_map.md)
