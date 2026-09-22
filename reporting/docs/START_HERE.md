# Start Here: FlightTest

This page is a short route into the accepted report family. It does not replace
the reports or add a second technical narrative.

## Project purpose

FlightTest develops the collection, packaging, replay, and reporting
infrastructure for a passive bistatic radar effort. The project uses broadcast
signals as illuminators of opportunity and paired radar/truth collection to
develop evidence for aircraft detection, tracking, and localization.

Read the reports as evidence-led engineering: current controlled synthetic
results and installed infrastructure do not by themselves establish live
aircraft or operational performance.

## Read first

| If you are… | Read this first | Then read |
| --- | --- | --- |
| A manager | [FlightTest_EndToEnd_HumanStory_V2](https://pwilliammat.github.io/flightTest/explainers/FlightTest_EndToEnd_HumanStory_V2.html) | [Report 06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html) |
| A new engineer | [FlightTest_EndToEnd_HumanStory_V2](https://pwilliammat.github.io/flightTest/explainers/FlightTest_EndToEnd_HumanStory_V2.html) | [Report 03 — Analysis Pipeline and Gate Rebuild](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html) |
| A contributor finding code or data | [Engineering Index](ENGINEERING_INDEX.md) | [Repository ownership map](../../repository_ownership_map.md) |

For the full ordered family and report-local source links, use
[FlightTest Reporting](../reporting_README.md).

## End-to-end story

[FlightTest_EndToEnd_HumanStory_V2](https://pwilliammat.github.io/flightTest/explainers/FlightTest_EndToEnd_HumanStory_V2.html)
is the fastest human-readable overview. It connects why the work matters,
what was built, how evidence is generated, and what remains blocked.

The accepted report sequence is:

`01 → 01A → 01B → 02 → 02A → 03 → 04 → 05 → 06`.

## Design decisions

- [Report 01A — Illuminator Selection](https://pwilliammat.github.io/flightTest/reports/01A_IlluminatorSelection_V4.html):
  historical transmitter, channel, site, and geometry screening.
- [Report 01B — Receive-Chain Design](https://pwilliammat.github.io/flightTest/reports/01B_ReceiveChainDesign_V2.html):
  modeled receive-chain decisions and the installed-qualification boundary.
- [Report 03 — Analysis Pipeline and Gate Rebuild](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html):
  the G1–G10 gate model and the claims each gate protects.

## Hardware

[Report 02 — Hardware and Collection](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html)
is the primary record of the installed collection infrastructure, capture
packages, and qualification boundary.

Collection operators should then use
[`TestSetupTesting/README.md`](../../TestSetupTesting/README.md), which owns
the supported coordinated-capture and synchronization procedures.

## Analysis

- [Report 03 — Analysis Pipeline and Gate Rebuild](https://pwilliammat.github.io/flightTest/reports/03_AnalysisPipelineAndGateRebuild.html)
  explains the formal gated pipeline.
- [Report 04 — Mitigation and Map-Rate Recovery](https://pwilliammat.github.io/flightTest/reports/04_MitigationAndMapRateRecovery_V2.html)
  records the recovery investigation, including the retained R5A failure.
- The FlightTest session-analysis entry point is
  [`BistaticDataAnalysis/runBistaticAnalysisSession.m`](../../BistaticDataAnalysis/runBistaticAnalysisSession.m).

FlightTest owns operational collection, packaging, replay, and reporting.
`PassiveBistaticRestart` owns the reconstruction and gate-validation work
behind Reports 03–05. See the [repository ownership map](../../repository_ownership_map.md)
before moving code or interpreting an artifact as an integration decision.

## Evidence

- [Report 02A — Synthetic Echo Generation](https://pwilliammat.github.io/flightTest/reports/02A_SyntheticEchoGeneration_V1.html)
  defines the bounded synthetic-truth context.
- [Report 05 — Strongest Evidence: G4-R Recovery Study](https://pwilliammat.github.io/flightTest/reports/05_StrongestEvidence_G4RRecoveryStudy.html)
  is the strongest current controlled diagnostic evidence.
- [Evidence catalog](../metadata/family_evidence_catalog.csv) maps each report
  to its result, decision, source, and claim boundary.

## Current status

[Report 06 — Status and Future Work](https://pwilliammat.github.io/flightTest/reports/06_StatusAndFutureWork_V2.html)
is the accepted report-family status view. It identifies two independent
blockers: map-contract verification and collection/reference-path
qualification.

For the active, detailed reconstruction milestone, consult
`PassiveBistaticRestart/PROJECT_STATE.md`; it is not duplicated here because
the accepted reports remain the FlightTest communication record.

## Find material quickly

- Technical topic, entry-point, data, and ownership: [Engineering Index](ENGINEERING_INDEX.md)
- External or large source artifact: [Source Materials](SOURCE_MATERIALS.md)
- Full accepted report family: [FlightTest Reporting](../reporting_README.md)
