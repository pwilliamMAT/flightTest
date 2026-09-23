# FlightTest Source Materials

This is the authoritative registry for large or external artifacts that
support accepted reports. It is a locator, not a request to copy binaries into
Git.

**Storage rule:** Git holds code, reports, explainers, and metadata.
SharePoint/OneDrive or approved artifact storage holds large binaries and
collection data.

## Canonical project storage

[FlightTest Datasets and Presentations](https://mathworks.sharepoint.com/:f:/r/sites/spc/signal/RadarToolbox/Shared%20Documents/Data/FlightTest%20Datasets%20and%20Presentations?d=wfe2816fad8cd4aa88a4cea5271af71bb&csf=1&web=1&e=HKMaVG)
is the project landing destination for approved dataset and presentation
uploads. This link does not confirm that any listed artifact has been
uploaded; retain each artifact's individual Storage Location and Status below.

| Artifact ID | Artifact Name | Purpose | Owner | Storage Location | Used By Reports | Used By Code | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SM-01 | `LinkBudgetProgress.pptx` | Historical link-budget, illuminator-comparison, and RF-budget source slides. | FlightTest | `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\LinkBudget\LinkBudgetProgress.pptx` | 01A, 01B | No runtime dependency. | Verified local OneDrive source. |
| SM-02 | `FlightTest_RFBudgetAnalysis.pptx` | Historical RF-budget analysis and receive-chain context. | FlightTest | `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\RFBudget\FlightTest_RFBudgetAnalysis.pptx` | 01B | Supports `SystemPrechecks/RFBudget/DTV_RFBudgetAnalysis.mat`. | Verified local OneDrive source. |
| SM-03 | `MountingDiagramParkingLot.pptx` | Receiver architecture and parking-lot mounting design. | FlightTest | `C:\Users\pwilliam\OneDrive - MathWorks\Documents\SFTT\Customers\FlightTest\MountingDiagramParkingLot.pptx` | 01B, 02 | No runtime dependency. | Verified local OneDrive source. |
| SM-04 | G4-R close-target atlas bundle | Authoritative G4-R close-target atlas, condition manifest, maps, and thumbnails. | PassiveBistaticRestart | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\artifacts\20260622T102123\G4_R_Close_Target_Atlas_Recovery\20260918T134014380Z` | 02A, 05, 06 | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RCloseTargetAtlasRecoveryStudy.m` | Verified external artifact location. |
| SM-05 | G4-R map-rate and R5A recovery bundles | Compact G4-R map-rate and retained R5A recovery records. | PassiveBistaticRestart | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\artifacts\20260622T102123` | 03, 04, 06 | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateValidity.m`; `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateMatrix.m` | Verified external artifact location. |
| SM-06 | Capture archives and packaged sessions | Raw dual-channel IQ, ADS-B truth, logs, and session manifests. | FlightTest | `PENDING_PROJECT_STORAGE` | 02; context for 03–06 | Collection scripts in `TestSetupTesting/`; operational replay in `BistaticDataAnalysis/`. | Pending project-storage location. |
| SM-07 | Hardware photos | Photographic evidence for the accepted hardware report. | FlightTest | `reporting/HardwarePhotos/` | 02 | No runtime dependency. | Verified Git report-source location. |
| SM-08 | Manager-review presentation decks | Historical and accepted manager-review presentation decks. | FlightTest | `PENDING_PROJECT_STORAGE` | Family-level communication reference | No runtime dependency. | Pending project-storage location. |

If an artifact moves, update this registry and the relevant metadata catalog;
do not silently rewrite accepted report content. See
[Repository Ownership](REPOSITORY_OWNERSHIP.md) for the two-repository
boundary and [Engineering Index](ENGINEERING_INDEX.md) for implementation
entry points.
