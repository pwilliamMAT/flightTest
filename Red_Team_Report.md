# Red-Team Report: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this when the `Independent Quality Gatekeeper` attacks the verification contract before implementation starts.

## Metadata
- Session: `2026-07-10 synthetic HDTV simulation red-team review`
- Date: `2026-07-10`
- Current phase: `Test Design`
- Related Requirements Packet: [Requirements_Packet.md](Requirements_Packet.md)
- Related Requirements Review Packet: [Requirements_Review_Packet.md](Requirements_Review_Packet.md)
- Related Design Packet: [Design_Packet.md](Design_Packet.md)
- Related Verification Spec: [Verification_Spec.md](Verification_Spec.md)
- Gatekeeper: `Independent Quality Gatekeeper` (Codex)
- Status: `Final`

## Executive Outcome
- Recommendation: `Proceed`
- Blocking issues: none at the verification-contract level after tightening the repeatability rule and requiring real wrapper replay plus declared external fixtures
- Summary judgment: the verification contract is strong enough to block the most likely false greens for this project. It requires the simulation to prove compatibility at the actual packaged-session boundary, to prove truth compatibility through the current truth loader, to preserve the approved repeatability boundary, and to produce at least one scorable downstream comparison path in the baseline triage scenario.

## Attacks On Requirements And Design
- Ambiguity that still weakens verification: `REQ-009` originally conflicted with `REQ-010` because `generation_time_utc` is naturally run-unique. The verification spec resolves this by excluding only `generation_time_utc` from rerun equality, not replay-critical metadata.
- Hidden assumption that can mislead green results: the v1 design depends on an HDTV illuminator-seed fixture because no native ATSC generator is installed. If that fixture were left implicit, implementation could pass local tests on one machine and fail elsewhere. The verification spec now declares the seed fixture as an explicit dependency.
- Design gap that breaks traceability: the design emits both SBS-1-compatible truth and a native traceability truth artifact. Without forcing the SBS-1 path through the existing loader, a green result could prove only the native truth artifact. The verification spec closes this gap by requiring the current truth pipeline to consume the emitted compatibility truth.

## Attacks On The Verification Spec
- Missing requirement coverage: none after traceability was expanded so that `REQ-001` through `REQ-012` each map to at least one named check
- Missing negative control: the initial weak spot was packaging and truth-format validation. The final spec adds explicit negative controls for missing manifest fields, broken truth format, out-of-coverage terrain, and scenario overlap failure.
- Missing regression control: the final spec requires canonical summaries for geometry, truth, manifest structure, and wrapper replay so that later implementation changes can be checked against stable baselines.
- Flake risk: stochastic radar synthesis could create unstable rerun evidence. The final spec requires deterministic mode by default and controlled seeds whenever stochastic effects are enabled.
- Undeclared environment dependency: the DTED asset and HDTV seed asset are the two material external fixtures. Both are now declared explicitly in the spec.
- Overspecified mock or coupled test: a pure helper-level mock of packaging or truth emission would be too weak. The final spec rejects helper-only green results and requires replay through `runBistaticAnalysisSession`.

## Misleading Green Scenarios
- Scenario 1: the implementation writes syntactically valid `.bb` files and a manifest, and the manifest passes a schema check, but the current session wrapper still cannot resolve or replay the session without manual edits. `CHK-006` exists to prevent this false green.
- Scenario 2: the implementation emits a native truth artifact with perfect traceability, but the SBS-1-compatible truth is malformed or not aligned to the scenario timeline, so the existing `loadADSBTruth` path cannot consume it. `CHK-002` and `CHK-010` exist to prevent this false green.

## Minimum Fixes Before Approval
- Fix 1: limit rerun-metadata exclusions to approved run-unique provenance only, specifically `generation_time_utc`, unless the human explicitly reopens requirements review
- Fix 2: require the HDTV seed asset and DTED asset to be declared as explicit fixtures before implementation starts; no hidden current-directory or machine-local assumptions are allowed

## Residual Risks If Approved
- Residual risk 1: the chosen HDTV seed may be workflow-compatible yet still fail to represent the most stressful real-world reference quality or pilot structure seen in field captures. This is a realism risk, not a verification-contract gap.
- Residual risk 2: the approved v1 baseline omits diffuse terrain-clutter reflectivity and buildings. The verification contract can prove compatibility and scoring utility, but not full clutter realism.

## Gatekeeper Sign-Off
- Final gate status: `Approve`
- Signed by: `Independent Quality Gatekeeper` (Codex)
- Date: `2026-07-10`
