# FlightTest and PassiveBistaticRestart Ownership

This is the canonical repository-boundary reference. It assigns responsibility;
it does not replace the accepted reports or either repository's active project
state.

## FlightTest

| Aspect | Responsibility |
| --- | --- |
| Purpose | Operate the passive-radar collection, session-packaging, operational replay, and accepted reporting infrastructure. |
| Primary Inputs | Dual-channel IQ, ADS-B/GPS truth, SDR/Pi configuration, antenna/RF hardware, and MATLAB/toolbox environment. |
| Primary Outputs | Packaged sessions, operational replay/diagnostic outputs, and the accepted `reporting/` evidence family. |
| Major Deliverables | `captures/<session_id>/` package contract, collection/replay utilities, Reports 01–06, and the end-to-end story. |
| Key Reports | [Reports 01–06](../reporting_README.md) and the [end-to-end story](../explainers/FlightTest_EndToEnd_HumanStory_V2.html). |
| Key Entry Points | [`run_coordinated_hdtv_capture.sh`](../../TestSetupTesting/run_coordinated_hdtv_capture.sh), [`sync_capture_session.sh`](../../TestSetupTesting/sync_capture_session.sh), and [`runBistaticAnalysisSession.m`](../../BistaticDataAnalysis/runBistaticAnalysisSession.m). |

## PassiveBistaticRestart

| Aspect | Responsibility |
| --- | --- |
| Purpose | Reconstruct and validate the passive-bistatic pipeline through explicit gates and controlled recovery studies. |
| Primary Inputs | FlightTest-compatible session packages, frozen gate configurations, declared synthetic conditions, and retained evidence artifacts. |
| Primary Outputs | Gate records, compact artifact bundles, map-rate/recovery studies, project state, and decision records. |
| Major Deliverables | G1–G10 reconstruction, G4-R validation/recovery work, and authoritative generated artifact bundles. |
| Key Reports | [Report 03](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html), [Report 04](https://pwilliammat.github.io/flightTest/reports/04_MitigationAndMapRateRecovery_V2.html), and [Report 05](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html). |
| Key Entry Points | `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4PassiveBaselineMap.m`, `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateValidity.m`, `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RMapRateMatrix.m`, and `C:\Users\pwilliam\agenticProjects\PassiveBistaticRestart\runG4RCloseTargetAtlasRecoveryStudy.m`. |

## Ownership flow

```text
FlightTest:               Collection → Packaging → Replay
                                              |
                                              v
PassiveBistaticRestart:   Pipeline → Recovery → controlled evidence generation
                                              |
                                              v
FlightTest:               accepted evidence/reporting
```

FlightTest owns the capture-package contract and accepted communication.
PassiveBistaticRestart owns formal reconstruction and gate decisions until a
bounded, reviewed integration is accepted by FlightTest.
