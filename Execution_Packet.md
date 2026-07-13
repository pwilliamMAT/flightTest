# Execution Packet: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this artifact when implementation is approved and one execution owner needs a bounded delivery record tied to the approved CODRTIV baseline.

## Metadata
- Session: `2026-07-13 synthetic HDTV simulation implementation increments 1-2`
- Date: `2026-07-13`
- Current phase: `Implementation Loop`
- Execution lead: Codex acting as `ExecutionLead`
- Related Requirements Packet: [Requirements_Packet.md](Requirements_Packet.md)
- Related Requirements Review Packet: [Requirements_Review_Packet.md](Requirements_Review_Packet.md)
- Related Design Packet: [Design_Packet.md](Design_Packet.md)
- Related Verification Spec: [Verification_Spec.md](Verification_Spec.md)
- Status: `In Progress`

## Approved Baseline
- Requirement baseline: [Requirements_Packet.md](Requirements_Packet.md), `REQ-001` through `REQ-012`
- Review baseline: [Requirements_Review_Packet.md](Requirements_Review_Packet.md)
- Design baseline: [Design_Packet.md](Design_Packet.md)
- Verification baseline: [Verification_Spec.md](Verification_Spec.md)
- Human approval reference: user approved the verification contract and implementation scope before entering `Implementation Loop`

## Approved Scope
- Approved change: implement the first two coherent synthetic-session increments: baseline scenario config, DTED-backed scene intake, truth generation, SBS-1-compatible truth emission, native traceability truth emission, packaged-session manifest writing with synthetic provenance, `.bb` artifact writing and readback, wrapper-compatibility smoke coverage, and the approved seed-backed HDTV reference and surveillance synthesis path plus a user-facing generation walkthrough
- Scope boundary: implement only what is required to satisfy `CHK-001` through `CHK-009` and the seed-backed-enablement portion of `CHK-010`; do not widen into detector redesign or higher-fidelity clutter modeling while the downstream truth-match gap remains under investigation
- Out of scope: detector redesign, tracker redesign, building models, diffuse clutter realism, custom ATSC waveform generation, and signal-realism work that depends on an explicit HDTV seed fixture

## Implementation Order
1. Create a deterministic baseline scenario-config and terrain-intake layer tied to the approved Apple Hill and Needham geometry.
2. Implement truth generation, SBS-1 compatibility writing, native traceability truth emission, and packaged-session manifest generation.
3. Implement minimal dual-channel `.bb` artifact writing plus wrapper-compatibility fixes and verification-aligned tests.
4. Implement the seed-backed illuminator path, expose it through the scenario config and generator, and add a live-script walkthrough plus seed-backed verification coverage.

## Ownership
- Integration owner: Codex
- Specialist worker 1 and write boundary: none for increment 1
- Specialist worker 2 and write boundary: none for increment 1

## Touched Subsystems Or Files
- Subsystem or file 1: new synthetic-session generator code under a dedicated simulation folder
- Subsystem or file 2: existing packaged-session replay and truth-alignment path in [BistaticDataAnalysis/analyzeBistaticData.m](BistaticDataAnalysis/analyzeBistaticData.m) and [BistaticDataAnalysis/alignTruthToRadar.m](BistaticDataAnalysis/alignTruthToRadar.m)
- Subsystem or file 3: test coverage aligned to the approved verification spec in [SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m](SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m)
- Subsystem or file 4: user-facing walkthrough in [SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m](SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m)

## Integration Checkpoints
- Checkpoint 1: generated session can be parsed by `helperLoadSessionManifest` and `helperResolveSessionAnalysisSetup`
- Checkpoint 2: generated session can be replayed through `runBistaticAnalysisSession` without core entrypoint edits

## Iteration Log
### Iteration 1
- Change summary: created the execution record, mapped the current packaged-session contract, and probed the real wrapper with a trivial packaged session
- Evidence rerun: manual wrapper probe through `runBistaticAnalysisSession`
- Result: probe exposed a real wrapper integration defect in `analyzeBistaticData.m` when `TRK_ID_COLORS` is referenced after the no-detection branch skips tracker setup
- Blocker or deviation: the wrapper defect is inside the approved compatibility scope and must be fixed to satisfy `CHK-006`

### Iteration 2
- Change summary: implemented seed-backed HDTV session synthesis via `SeedSourcePath`, `helperSyntheticLoadSeedWaveform`, `helperSyntheticSynthesizeSeedBackedChannels`, and manifest/header provenance updates; added `helperSyntheticCreateProbeSeed` for smoke bring-up; added the plain-text live script walkthrough; extended generator tests for seed loading, seed-backed channel content, seed provenance, and wrapper replay
- Evidence rerun: MATLAB static analysis on all touched generator files; targeted `matlab.unittest` runs for the new seed-backed tests; live-script smoke run through [SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m](SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m); seed-backed wrapper replay through `testSeedBackedPackagedSessionReplaysThroughCurrentWrapper`
- Result: seed-backed generation now writes nonzero two-channel `.bb` data, the manifest preserves seed provenance, the walkthrough generates a session successfully, and the unchanged wrapper replays the synthetic session with detections present and aligned truth non-empty. The latest wrapper evidence produced `863` detections and `2/2` overlapping truth tracks for the synthetic session, but `TP` remained `0`, so operational tuning is still open.
- Blocker or deviation: no packaging or compatibility blocker remains for the seed-backed path, but the current probe-seed waveform and/or the simplistic delay and gain model do not yet place the detections close enough to truth for useful scoring. A real field seed is still needed for detector-tuning credibility.

## Rollback Conditions
- Condition 1: if increment 1 requires weakening the packaged-session contract or changing core entrypoint expectations, stop and reopen review
- Condition 2: if increment 1 unexpectedly depends on a custom ATSC waveform generator or building/clutter realism to satisfy the approved baseline, stop and reopen review

## Blocking Questions Or Missing Information
- Blocking question 1: none for increment 1
- Missing approved input or baseline reference: none
- Missing execution dependency or ownership detail: the explicit preferred field HDTV seed fixture path remains undeclared. It no longer blocks smoke generation because the walkthrough can create a probe seed automatically, but it still blocks high-confidence detector-tuning conclusions.
- Missing scope clarification: none
- Missing validation handoff expectation: none

## Reopen Review Conditions
- Requirement changed: if the repeatability boundary expands beyond the approved `generation_time_utc` exclusion
- Design intent changed: if the implementation must replace the approved packaged-session contract or abandon the seed-based assumption for later realism work
- Verification spec weakened or changed: if compatibility proof stops using the unchanged session wrapper or if `CHK-010` is redefined to allow a packaging-only green result

## Validation Handoff
- Checks expected next: `CHK-001` through `CHK-009` now have implementation evidence, and `CHK-010` can continue from the seed-backed baseline using a real field seed plus truth-alignment tuning
- Evidence expected from validation: scenario-config inspection, DTED coverage summary, truth traceability summary, manifest readback, `.bb` readback summary, live-script smoke output, and seed-backed wrapper replay output
- Notes for gatekeeper: the implementation now covers the approved seed-backed illuminator assumption and the walkthrough artifact, but it does not yet claim operational detector utility because the current synthetic detections remain displaced from truth under the existing scoring gates
