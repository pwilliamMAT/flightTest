# Cross-explainer review — 01A, 01B, 02, 02A, 03

## Reviewed chain

| Report | Owns | Handoff |
|---|---|---|
| `01_NorthStarAndMotivation_V2.html` | Why passive HDTV aircraft-localization work matters and what it is not yet. | Establishes the problem that needs an illuminator, receiver, collection, controlled target, and analysis chain. |
| `01A_IlluminatorSelection_V4.html` | Historical transmitter, receiver-site, and observation-geometry selection. | Supplies candidate frequency, bandwidth, historical predicted level, and geometry inputs to 01B. |
| `01B_ReceiveChainDesign_V1.html` | Translation of historical RF inputs into antenna, cable, impedance, filter, LNA, N320, and headroom design reasoning. | Identifies the physical questions that Report 02 must measure and qualify. |
| `02_HardwareAndCollection_V4.html` | Physical hardware, channel roles, capture configuration, and collection qualification boundaries. | Supplies the real collection context that 02A preserves as background in a controlled synthetic experiment. |
| `02A_SyntheticEchoGeneration_V1.html` | Declared synthetic truth, delay/Doppler construction, surveillance-only injection, package traceability, and limits. | Supplies a reviewable package to the truth-blind pipeline in 03. |
| `03_AnalysisPipelineAndGateRebuild.html` | Gate sequence, truth separation, map/CFAR/NMS processing, and evidence-control rules. | Receives the synthetic package without using truth to steer detector generation. |

## Ownership and duplication review

- **01A vs 01B:** No duplicated illuminator/site decision. 01B repeats only the specific historical signal/frequency inputs needed to explain why the RF cascade exists, and labels 01A as the source and owner.
- **01B vs 02:** The receiver-enclosure photograph in 01B is used only to show the handoff from a model to physical hardware. Installation, channel-role proof, lock/drop evidence, and Reference Path qualification remain explicitly in 02.
- **02 vs 02A:** 02A uses a recorded dual-channel pair as controlled background but does not claim that injection qualifies the hardware, capture, or reference path.
- **02A vs 03:** 02A describes declared truth and package generation. It directs all truth-blind processing, support, map, CFAR, and NMS policy to 03.
- **02A vs 05:** 02A links to the exact G4-R result but does not reinterpret it, select a mitigation product, or turn it into live-aircraft performance.

## Figure review

- 01A visuals are geography, terrain/building visibility, and target-region modeling.
- 01B visuals are cascade and component-model evidence, plus clearly bounded physical context.
- 02A visuals are declared trajectories, synthetic placement, delay/Doppler placement, and generator checks.
- The 02A atlas figures overlap visually with Report 05 only where needed to explain the generator-to-pipeline handoff. Their captions limit the use to placement/support context.
- No mitigation thumbnail was reused as a fabricated before/after injection image.

## Language review

- Both new explainers use the consistent outcome-first order: **Question → Result → Why it matters → Engineering decision → Evidence → Method → Remaining uncertainty**.
- Both avoid the rejected abstract phrasing: capability pathways, evidence promotion, bounded opportunity, operationalization, framework, and strategic initiative.
- Both use direct decision language: “The model showed…,” “Therefore…,” and “Still unknown…”.

## Continuity findings

1. The engineering story now reads naturally as: choose a plausible illuminator/geometry → convert predicted levels into a receive-chain design → build and qualify physical collection → inject declared truth into preserved recorded background → process truth-blind.
2. 01B resolves a missing bridge between historical link budget and hardware: it explains why long cable, impedance, filtering, low-noise gain, and N320 headroom are a single engineering decision.
3. 02A resolves a missing bridge between collection and pipeline: it explains why a known synthetic target is useful without claiming it is a live-aircraft result.
4. The main remaining evidence gaps are intentionally visible, not hidden:
   - 01B lacks an end-to-end installed RF measurement/qualification record.
   - 02A lacks a recoverable raw source-faithful before/after injection figure; it uses a labelled source-derived channel-contract schematic instead.

## Result

The reports have distinct ownership, compatible visual style, direct transitions, and no material narrative or evidence overlap that should be removed before manual review.
