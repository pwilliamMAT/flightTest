# FlightTest Engineering Index

Navigation only. Accepted reports own evidence and claim boundaries; code does
not by itself prove successful execution.

## Illuminator Selection

| Route | Location |
| --- | --- |
| Reports | [Report 01A](https://pwilliammat.github.io/flightTest/reports/01A_IlluminatorSelection_V4.html); [Report 01](https://pwilliammat.github.io/flightTest/reports/01_NorthStarAndMotivation_V2.html) |
| Primary Code Entry Points | No repository-local executable entry point; use the verified historical source material. |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — FlightTest reporting/planning inputs. |
| Data Sources | [`Radio_Tower_List.txt`](../../SystemPrechecks/LinkBudget/Radio_Tower_List.txt); [`PlanningRadarNetworkCoverageOverTerrainRadarData.mat`](../../SystemPrechecks/LinkBudget/PlanningRadarNetworkCoverageOverTerrainRadarData.mat) |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-01`. |

## Receive Chain Design

| Route | Location |
| --- | --- |
| Reports | [Report 01B](https://pwilliammat.github.io/flightTest/reports/01B_ReceiveChainDesign_V2.html); [Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) |
| Primary Code Entry Points | [`assess_bb_quality.m`](../../TestSetupTesting/assess_bb_quality.m); [`check_dual_channel_coherence.m`](../../TestSetupTesting/check_dual_channel_coherence.m); [`runDirectPathPrecheck.m`](../../BistaticDataAnalysis/runDirectPathPrecheck.m) |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — FlightTest collection checks and reporting. |
| Data Sources | [`DTV_RFBudgetAnalysis.mat`](../../SystemPrechecks/RFBudget/DTV_RFBudgetAnalysis.mat); reference/surveillance IQ in packaged sessions. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-02`, `SM-03`. |

## Hardware and Collection

| Route | Location |
| --- | --- |
| Reports | [Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) |
| Primary Code Entry Points | [`run_coordinated_hdtv_capture.sh`](../../TestSetupTesting/run_coordinated_hdtv_capture.sh); [`runLocalHDTVCapture.m`](../../TestSetupTesting/runLocalHDTVCapture.m); [`sync_capture_session.sh`](../../TestSetupTesting/sync_capture_session.sh); [`start_adsb_gps_loggers.sh`](../../ADSB_GPS/start_adsb_gps_loggers.sh) |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — FlightTest owns the capture-package contract. |
| Data Sources | `captures/<session_id>/radar/`, `truth/`, `logs/`, and `session_manifest.json`. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-06`, `SM-07`. |

## Synthetic Validation

| Route | Location |
| --- | --- |
| Reports | [Report 02A](https://pwilliammat.github.io/flightTest/reports/02A_SyntheticEchoGeneration_V1.html); [Report 05](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) |
| Primary Code Entry Points | [`signalProcessingTests.m`](../../SignalProcessingAnalysis/signalProcessingTests.m); [`injectSyntheticTarget.m`](../../SignalProcessingAnalysis/helpers/injectSyntheticTarget.m) |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — FlightTest hosts local experiments; PassiveBistaticRestart owns the formal gated study. |
| Data Sources | Declared synthetic truth, real-background recordings, and accepted atlas condition records. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-04`. |

## Pipeline

| Route | Location |
| --- | --- |
| Reports | [Report 03](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html); [Report 06](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| Primary Code Entry Points | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4PassiveBaselineMap.m`; `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateValidity.m` |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — PassiveBistaticRestart owns pipeline reconstruction and gate decisions. |
| Data Sources | FlightTest-compatible dual-channel packages, frozen gate configuration, and compact gate bundles. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-05`. |

## Recovery

| Route | Location |
| --- | --- |
| Reports | [Report 04](https://pwilliammat.github.io/flightTest/reports/04_MitigationAndMapRateRecovery_V2.html); [Report 05](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) |
| Primary Code Entry Points | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateMatrix.m`; `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RCloseTargetAtlasRecoveryStudy.m` |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — PassiveBistaticRestart owns formal recovery studies. |
| Data Sources | Frozen R4 contract, real-background sessions, synthetic conditions, and matrix/atlas artifacts. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-04`, `SM-05`. |

## Strongest Evidence

| Route | Location |
| --- | --- |
| Reports | [Report 05](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) |
| Primary Code Entry Points | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RCloseTargetAtlasRecoveryStudy.m` |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — PassiveBistaticRestart supplies evidence; FlightTest owns the accepted report. |
| Data Sources | Controlled synthetic-recovery conditions and the close-target atlas bundle. |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-04`. |

## Current Status

| Route | Location |
| --- | --- |
| Reports | [Report 06](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| Primary Code Entry Points | [`buildTechnicalSummaryFamily.m`](../scripts/buildTechnicalSummaryFamily.m); [`verifyTechnicalSummaryFamily.m`](../scripts/verifyTechnicalSummaryFamily.m) |
| Repository Ownership | [Repository Ownership](REPOSITORY_OWNERSHIP.md) — FlightTest owns accepted status communication. |
| Data Sources | [`family_evidence_catalog.csv`](../metadata/family_evidence_catalog.csv); [`family_code_navigation.csv`](../metadata/family_code_navigation.csv); [`family_manifest.json`](../metadata/family_manifest.json) |
| Source Materials | [Source Materials](SOURCE_MATERIALS.md) — `SM-04`, `SM-05`, `SM-08`. |
