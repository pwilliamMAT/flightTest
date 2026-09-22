# FlightTest Engineering Index

Navigation only. Reports remain the authority for evidence and claim
boundaries; code is not evidence of successful execution by itself.

## Illuminator selection

| Navigation item | Location |
| --- | --- |
| Reports | [01A — Illuminator Selection](https://pwilliammat.github.io/flightTest/reports/01A_IlluminatorSelection_V4.html); [01 — North Star](https://pwilliammat.github.io/flightTest/reports/01_NorthStarAndMotivation_V2.html) |
| Code entry points | External provenance: `LinkBudget/FlightTest_Bistatic_RadarAndCommsAnalysis.mlx`; `LinkBudget/AppleHill_CustomizeBuildingsForRayTracingAnalysisExample.mlx` |
| Data sources | [`SystemPrechecks/LinkBudget/Radio_Tower_List.txt`](../../SystemPrechecks/LinkBudget/Radio_Tower_List.txt); [`PlanningRadarNetworkCoverageOverTerrainRadarData.mat`](../../SystemPrechecks/LinkBudget/PlanningRadarNetworkCoverageOverTerrainRadarData.mat); `applehill.osm` in the external LinkBudget source |
| Source material | `LinkBudgetProgress.pptx`; see [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest reporting and planning inputs; original Live Scripts remain external OneDrive source material. |

## Receive-chain design

| Navigation item | Location |
| --- | --- |
| Reports | [01B — Receive-Chain Design](https://pwilliammat.github.io/flightTest/reports/01B_ReceiveChainDesign_V2.html); [02 — Hardware and Collection](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) |
| Code entry points | [`assess_bb_quality.m`](../../TestSetupTesting/assess_bb_quality.m); [`check_dual_channel_coherence.m`](../../TestSetupTesting/check_dual_channel_coherence.m); [`runDirectPathPrecheck.m`](../../BistaticDataAnalysis/runDirectPathPrecheck.m) |
| Data sources | [`DTV_RFBudgetAnalysis.mat`](../../SystemPrechecks/RFBudget/DTV_RFBudgetAnalysis.mat); captured reference/surveillance IQ in packaged sessions |
| Source material | `FlightTest_RFBudgetAnalysis.pptx`; `MountingDiagramParkingLot.pptx`; see [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest owns collection-side checks and reporting; historical RF-model sources are external. |

## Hardware and collection

| Navigation item | Location |
| --- | --- |
| Reports | [02 — Hardware and Collection](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) |
| Code entry points | [`run_coordinated_hdtv_capture.sh`](../../TestSetupTesting/run_coordinated_hdtv_capture.sh); [`runLocalHDTVCapture.m`](../../TestSetupTesting/runLocalHDTVCapture.m); [`sync_capture_session.sh`](../../TestSetupTesting/sync_capture_session.sh); [`start_adsb_gps_loggers.sh`](../../ADSB_GPS/start_adsb_gps_loggers.sh) |
| Data sources | `captures/<session_id>/session_manifest.json`, `radar/`, `truth/`, and `logs/`; Raspberry Pi ADS-B/GPS output |
| Source material | Capture archives and retained hardware photos; see [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest. This is the source of the collection-package contract. |

## Replay, truth, and diagnostic iteration

| Navigation item | Location |
| --- | --- |
| Reports | [02 — Hardware and Collection](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html); [06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| Code entry points | [`runBistaticAnalysisSession.m`](../../BistaticDataAnalysis/runBistaticAnalysisSession.m); [`runDetectionTruthDiagnostics.m`](../../BistaticDataAnalysis/runDetectionTruthDiagnostics.m); [`runDetectorReplaySweep.m`](../../BistaticDataAnalysis/runDetectorReplaySweep.m); [`runSessionRFQualityAudit.m`](../../BistaticDataAnalysis/runSessionRFQualityAudit.m) |
| Data sources | Packaged radar/truth files plus `session_manifest.json`; saved `truth_diag_input.mat` and `detector_replay_input.mat` snapshots when available |
| Source material | Capture archive record; [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest operational replay. This is distinct from the formal gate-reconstruction ownership in PassiveBistaticRestart. |

## Synthetic validation

| Navigation item | Location |
| --- | --- |
| Reports | [02A — Synthetic Echo Generation](https://pwilliammat.github.io/flightTest/reports/02A_SyntheticEchoGeneration_V1.html); [05 — G4-R Recovery Study](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) |
| Code entry points | [`signalProcessingTests.m`](../../SignalProcessingAnalysis/signalProcessingTests.m); [`injectSyntheticTarget.m`](../../SignalProcessingAnalysis/helpers/injectSyntheticTarget.m); external provenance: `flightTest_SynthDataBranch/SyntheticHDTVSimulation/generateRealBackgroundSyntheticSuite.m` |
| Data sources | Declared synthetic truth, real-background recordings, session manifests, and accepted atlas condition records |
| Source material | G4-R close-target atlas bundle; [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest contains local signal-processing experiments and reporting; the accepted gated recovery study is owned by PassiveBistaticRestart. |

## Pipeline and gate validation

| Navigation item | Location |
| --- | --- |
| Reports | [03 — Analysis Pipeline and Gate Rebuild](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html); [06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| Code entry points | `PassiveBistaticRestart/runG4PassiveBaselineMap.m`; `PassiveBistaticRestart/runG4RMapRateValidity.m`; `PassiveBistaticRestart/PROJECT_STATE.md` |
| Data sources | FlightTest-style dual-channel session packages; gate configuration; saved compact gate bundles |
| Source material | PassiveBistaticRestart G4-R artifacts; [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | PassiveBistaticRestart owns pipeline reconstruction and formal gate decisions. FlightTest owns collection/package compatibility and receives selectively integrated mature work. |

## Recovery and mitigation

| Navigation item | Location |
| --- | --- |
| Reports | [04 — Mitigation and Map-Rate Recovery](https://pwilliammat.github.io/flightTest/reports/04_MitigationAndMapRateRecovery_V2.html); [05 — G4-R Recovery Study](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html) |
| Code entry points | `PassiveBistaticRestart/runG4RMapRateMatrix.m`; `PassiveBistaticRestart/runG4RCloseTargetAtlasRecoveryStudy.m`; `PassiveBistaticRestart/helperApplyG4RNativeFirstCancellation.m` |
| Data sources | Frozen R4 contract, real-background sessions, synthetic injection conditions, compact matrix and atlas artifacts |
| Source material | G4-R map-rate and close-target atlas bundles; [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | PassiveBistaticRestart. Formal G5/G6/G8 promotion is intentionally separate from this diagnostic work. |

## Evidence, status, and report maintenance

| Navigation item | Location |
| --- | --- |
| Reports | [05 — Strongest Evidence](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html); [06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| Code entry points | [`buildTechnicalSummaryFamily.m`](../scripts/buildTechnicalSummaryFamily.m); [`verifyTechnicalSummaryFamily.m`](../scripts/verifyTechnicalSummaryFamily.m) |
| Data sources | [`family_evidence_catalog.csv`](../metadata/family_evidence_catalog.csv); [`family_code_navigation.csv`](../metadata/family_code_navigation.csv); [`family_manifest.json`](../metadata/family_manifest.json) |
| Source material | Accepted reports, audits, external atlas/artifact bundles, and presentation references; [Source Materials](SOURCE_MATERIALS.md) |
| Repository ownership | FlightTest `reporting/` owns the accepted communication family. PassiveBistaticRestart remains the source for its external technical evidence artifacts. |

## Cross-repository rule

Use [`repository_ownership_map.md`](../../repository_ownership_map.md) before
changing a capture-package contract, importing a gate result, or treating an
external artifact as an accepted FlightTest update.
