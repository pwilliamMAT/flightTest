# Design Packet: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this artifact to describe the minimum design needed to satisfy the approved requirement baseline.

## Metadata
- Session: `2026-07-10 synthetic HDTV simulation design`
- Date: `2026-07-10`
- Current phase: `Design`
- Related Requirements Packet: [Requirements_Packet.md](Requirements_Packet.md)
- Related Requirements Review Packet: [Requirements_Review_Packet.md](Requirements_Review_Packet.md)
- Related CONOPS Brief: [CONOPS_Brief.md](CONOPS_Brief.md)
- Related System Context Diagram: [SyntheticHDTVSimulation_CONOPS_Context.slx](SyntheticHDTVSimulation_CONOPS_Context.slx)
- Owner: Human orchestrator with Codex support acting as `SystemDesigner`
- Status: `Approved`

## Native MATLAB Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Site-specific bistatic scene with terrain-backed geometry | `Simulating Site-Specific Bistatic Land Clutter`, `Create Earth-Centered Radar Scenario`, `Create Land Surface from DTED File` | Keep the earth-centered scene and DTED terrain-loading pattern, but use terrain for site context and line-of-sight gating only in v1. Do not require land-clutter reflectivity synthesis in v1. |
| Geodetic aircraft truth generation | `CreateGeoTrajectoryAndLookUpPoseExample` | Use one or more aircraft trajectories from scenario inputs and drive both native truth output and ADS-B-compatible truth emission from the same source timeline. |
| Passive wideband path synthesis for direct path and target echoes | `Free Space Propagation of Wideband Signals`, `Bistatic Transmitter and Receiver with Target` | Replace pulsed-radar scheduling with a passive illuminator seed and generate reference plus surveillance channels that match the existing `.bb` capture contract. |
| Session-compatible baseband artifact creation and replay | `Write Baseband Signal to File`, `Read Baseband Data From File` | Write dual-channel `.bb` files, preserve N320-style header metadata, and package the same folder and manifest contract consumed by the current session-analysis wrapper. |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Earth-centered scenario container | `radarScenario` (Radar Toolbox) | `scene = radarScenario(IsEarthCentered=true, UpdateRate=updateRateHz)` |
| DTED terrain surface in the radar scene | `landSurface` (Radar Toolbox) | `srf = landSurface(scene, Terrain=dtedFile)` |
| Terrain raster intake and coverage inspection | `readgeoraster` (Mapping Toolbox) | `[Z,R] = readgeoraster(dtedFile)` |
| Optional terrain registration for visualization workflows | `addCustomTerrain` (Antenna Toolbox / Site Viewer terrain support) | `addCustomTerrain("AppleHill", dtedFile)` |
| Geodetic target motion | `geoTrajectory` (Radar Toolbox) | `traj = geoTrajectory(waypoints, timeOfArrival, SampleRate=rateHz)` |
| Wideband path delay and Doppler | `phased.WidebandFreeSpace` (Phased Array System Toolbox) | `y = widebandFreeSpace(x, originPos, destPos, originVel, destVel)` |
| Bistatic target scattering | `phased.RadarTarget` (Phased Array System Toolbox) | `tgt = phased.RadarTarget('Mode','Bistatic','MeanRCS',sigmaSqM); y = tgt(x)` |
| Residual frequency-offset injection when needed | `frequencyOffset` (Communications Toolbox) | `y = frequencyOffset(x, fs, offsetHz)` |
| Additive receiver-noise injection | `awgn` (Communications Toolbox) | `y = awgn(x, snrDb, 'measured', seed)` |
| Session radar artifact writing | `comm.BasebandFileWriter` (Communications Toolbox) | `bbw = comm.BasebandFileWriter(fname, fs, fc, md); bbw(samples)` |
| Session radar artifact readback and smoke test | `comm.BasebandFileReader` (Communications Toolbox) | `bbr = comm.BasebandFileReader(fname, SamplesPerFrame=N); x = bbr()` |
| Deferred terrain-clutter extension seam | `clutterGenerator`, `surfaceReflectivityLand` (Radar Toolbox) | `gen = clutterGenerator(scene, radar, Name=Value)` |

Audit note:
- No installed native ATSC or HDTV waveform generator was found in this MATLAB environment. The minimum native-function-compliant design therefore uses a captured HDTV reference-channel seed as the illuminator source for v1 instead of introducing a custom ATSC physical-layer implementation.

## Design Intent
- Design goal: produce the minimum architecture that generates terrain-backed synthetic passive bistatic radar sessions which the existing session-analysis workflow can consume without manual edits to core entrypoints.
- Scope boundary: one approved transmitter site, one approved receiver site, one DTED-backed terrain context, one or more synthetic aircraft trajectories, one HDTV-like illuminator seed, synthetic dual-channel radar session files, session metadata, and truth outputs compatible with the current workflow.
- Out of scope: detector redesign, tracker redesign, building models, full land-clutter reflectivity modeling, multi-emitter or multi-receiver expansion, and a custom ATSC transmitter implementation.

## Architecture Summary
- Design approach: use a hybrid scene-and-signal design. Radar Toolbox and Mapping Toolbox own site geometry, terrain context, and target truth. Phased Array System Toolbox and Communications Toolbox own propagation-level signal synthesis, channel perturbations, and `.bb` session artifact writing. Repo compatibility is preserved by matching the current packaged-session contract consumed by [runBistaticAnalysisSession.m](BistaticDataAnalysis/runBistaticAnalysisSession.m), [helperLoadSessionManifest.m](BistaticDataAnalysis/helperLoadSessionManifest.m), [helperResolveSessionAnalysisSetup.m](BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m), [loadIQData.m](BistaticDataAnalysis/loadIQData.m), and [loadADSBTruth.m](BistaticDataAnalysis/loadADSBTruth.m).
- Major elements:
  - `DE-01 ScenarioConfig`: one MATLAB struct or JSON-backed config that is the sole source of truth for scenario ID, Tx/Rx geodetic coordinates, DTED path, capture timing, sample rate, carrier, LO offset, target trajectories, illuminator-seed source, and optional stochastic controls.
  - `DE-02 SceneTerrainAdapter`: builds an earth-centered `radarScenario`, loads the Apple Hill DTED tile into `landSurface`, and exposes terrain coverage plus line-of-sight or occlusion checks for the approved geometry.
  - `DE-03 TargetTruthEngine`: instantiates target motion from `geoTrajectory`, produces per-target geodetic truth on the scenario timeline, and derives optional bistatic measurement-space truth using the same convention as the current workflow.
  - `DE-04 IlluminatorSeedProvider`: loads a captured HDTV reference-channel seed at the required sample rate and center-frequency context so the synthetic session preserves ATSC-like occupied bandwidth and pilot structure without building a custom transmitter.
  - `DE-05 PassiveChannelSynthesizer`: synthesizes CH1 surveillance and CH2 reference signals for each part. The reference channel carries the direct-path illuminator copy plus optional receiver effects. The surveillance channel carries the direct path seen at the surveillance antenna, target echoes from the approved trajectories, and optional additive noise. Terrain influences v1 through site context and line-of-sight gating, not diffuse clutter-return synthesis.
  - `DE-06 CompatibilityTruthWriter`: emits two truth views from the same scenario source. The compatibility view is SBS-1 or BaseStation ADS-B text compatible with `loadADSBTruth`. The traceability view is a native MATLAB truth artifact containing target IDs, geodetic truth, and optional bistatic measurement truth for review and debugging.
  - `DE-07 SessionPackager`: writes `.bb` radar files with `comm.BasebandFileWriter`, emits `session_manifest.json` with the existing packaged-session fields plus synthetic provenance fields, and lays out `radar/`, `truth/`, and `logs/` under `captures/<session_id>/`.
  - `DE-08 SessionCompatibilitySmokeCheck`: reads back the emitted `.bb` and manifest artifacts and runs the existing session-analysis entrypoint as the design-level compatibility proof.
- Key assumptions:
  - V1 uses a captured HDTV reference-channel seed as the illuminator source because no installed native ATSC generator was found.
  - CH1 remains the surveillance channel and CH2 remains the reference channel by default, matching [loadIQData.m](BistaticDataAnalysis/loadIQData.m).
  - The scenario configuration, not stale comments or fallback constants in legacy scripts, is the source of truth for Tx/Rx coordinates, center frequency, sample rate, and timing.
  - The DTED tile [n42_w072_1arc_v3.dt2](n42_w072_1arc_v3.dt2) covers the current Apple Hill and Needham baseline and is sufficient for v1 terrain context.
  - V1 terrain usage is limited to site context, height awareness, and line-of-sight or occlusion gating. It does not claim high-fidelity clutter-reflectivity realism.

## Interfaces
| Interface ID | Producer | Consumer | Contract | Failure mode if violated |
| :--- | :--- | :--- | :--- | :--- |
| IF-001 | `DE-01 ScenarioConfig` | `DE-02 SceneTerrainAdapter`, `DE-03 TargetTruthEngine`, `DE-04 IlluminatorSeedProvider`, `DE-07 SessionPackager` | A versioned scenario specification containing `scenario_id`, Tx/Rx `lla_deg_m`, DTED path, `center_frequency_hz`, `sample_rate_hz`, `lo_offset_hz`, capture duration and repetition settings, target trajectory definitions, illuminator-seed reference, and optional `random_seed`. | The design cannot reproduce truth or metadata, and later tests cannot tell whether a mismatch comes from geometry, signal synthesis, or packaging. |
| IF-002 | `DE-02 SceneTerrainAdapter` | `DE-05 PassiveChannelSynthesizer`, `DE-03 TargetTruthEngine` | Terrain-backed site context containing scene handles, terrain bounds, fixed Tx/Rx poses, and line-of-sight or occlusion results for the active geometry. | Target visibility and path availability drift from the approved site context, making synthetic returns inconsistent with the declared baseline. |
| IF-003 | `DE-03 TargetTruthEngine` | `DE-05 PassiveChannelSynthesizer`, `DE-06 CompatibilityTruthWriter` | Time-tagged target states with `target_id`, `icao_hex`, `callsign`, geodetic position, velocity, and optional derived `R_excess_m` and `f_D_hz`. | Truth becomes untraceable to the synthetic returns, and downstream evaluation cannot attribute detections to declared targets. |
| IF-004 | `DE-04 IlluminatorSeedProvider` | `DE-05 PassiveChannelSynthesizer` | Complex HDTV-like baseband seed plus sample rate, center-frequency context, and seed provenance. | Synthetic data loses the occupied-band and pilot structure needed for meaningful passive-radar processing checks. |
| IF-005 | `DE-05 PassiveChannelSynthesizer` | `DE-07 SessionPackager` | Per-part `N x 2` complex sample matrices where column 1 is surveillance and column 2 is reference, plus per-part header metadata such as `RecordingUTC`, `SessionID`, `LOOffset`, `Duration_s`, and repetition index. | `loadIQData` or `runBistaticAnalysisSession` misreads channel roles, timing, or frequency context, causing detector and truth comparisons to fail for the wrong reason. |
| IF-006 | `DE-06 CompatibilityTruthWriter` | Existing truth pipeline (`loadADSBTruth` and `runBistaticAnalysisSession`) | One or more SBS-1 or BaseStation text files under `truth/`, named in the `adsb_<session_id>.txt[.gz]` convention and containing `MSG,1`, `MSG,3`, and `MSG,4` records on the scenario UTC timeline. | The current truth pipeline skips, misparses, or misaligns the synthetic truth, violating REQ-007, REQ-008, and REQ-012. |
| IF-007 | `DE-07 SessionPackager` | Existing packaged-session workflow (`helperLoadSessionManifest`, `helperResolveSessionAnalysisSetup`, `runBistaticAnalysisSession`) | `captures/<session_id>/radar/*.bb`, `captures/<session_id>/truth/*`, `captures/<session_id>/logs/*`, and `session_manifest.json` containing the current packaged-session schema plus required synthetic provenance fields. | Session preflight fails, center frequency or timing falls back incorrectly, or truth files are not discovered by the wrapper. |
| IF-008 | `DE-07 SessionPackager` | `DE-08 SessionCompatibilitySmokeCheck` and human reviewer | A native traceability artifact such as `truth/scenario_truth.mat` or equivalent, keyed by `scenario_id`, `target_id`, `icao_hex`, and UTC time. | Human review can only inspect the compatibility truth path and loses the direct mapping from scenario definition to emitted truth. |

## Requirement-To-Design Traceability
| Requirement ID | Design element | Why this satisfies the requirement | Verification impact |
| :--- | :--- | :--- | :--- |
| REQ-001 | `DE-01 ScenarioConfig`, `DE-02 SceneTerrainAdapter` | Tx and Rx geodetic coordinates are explicit scenario inputs and are instantiated in the earth-centered scene instead of being hidden in analysis fallbacks. | Test design must inspect the scenario spec and confirm the generated session uses the declared Tx/Rx baseline. |
| REQ-002 | `DE-03 TargetTruthEngine` | One or more target trajectories are first-class inputs and drive both truth generation and synthetic echo generation. | Tests must inject at least one aircraft trajectory and confirm emitted truth coverage. |
| REQ-003 | `DE-02 SceneTerrainAdapter` | The baseline scene requires a DTED file and loads terrain context near Apple Hill and the Needham transmitter geometry. | Tests must confirm the DTED path is referenced and that the scenario geometry lies within the loaded terrain bounds. |
| REQ-004 | `DE-05 PassiveChannelSynthesizer`, `DE-07 SessionPackager` | Synthetic radar data is generated as dual-channel baseband and written as session radar artifacts for each scenario run. | Tests must confirm `.bb` files are emitted and readable. |
| REQ-005 | `DE-03 TargetTruthEngine`, `DE-06 CompatibilityTruthWriter` | Truth is emitted from the same target-state source that drives the synthetic echoes, preserving direct traceability to declared trajectories. | Tests must cross-check emitted truth against source trajectory IDs and timestamps. |
| REQ-006 | `DE-07 SessionPackager` | The manifest writer preserves the session fields currently used by the analysis wrapper and extends them with synthetic provenance. | Tests must read the manifest through the current helper functions and verify no required metadata is missing. |
| REQ-007 | `DE-06 CompatibilityTruthWriter`, `DE-07 SessionPackager`, `DE-08 SessionCompatibilitySmokeCheck` | The design targets the exact packaged-session contract consumed today, not a parallel simulation-only format. | Tests must run `runBistaticAnalysisSession` on the synthetic session without editing core analysis code. |
| REQ-008 | `DE-03 TargetTruthEngine` | Optional bistatic truth is derived using the same `R_excess` and Doppler conventions already used by the current workflow. | Tests must compare emitted measurement-space truth against the approved convention. |
| REQ-009 | `DE-01 ScenarioConfig`, `DE-03 TargetTruthEngine`, `DE-07 SessionPackager` | Deterministic scenario definitions drive reproducible truth and metadata, while the synthesizer may vary raw radar samples when stochastic effects are enabled. | Tests must rerun one approved scenario and compare truth plus manifest outputs across reruns. |
| REQ-010 | `DE-07 SessionPackager` | Synthetic provenance is carried in the manifest and tied to the scenario ID and generator identity. | Tests must inspect manifest fields for required provenance markers. |
| REQ-011 | `DE-01 ScenarioConfig` | The design reserves one baseline controlled scenario whose stated purpose is detector or truth-projection triage under known geometry. | Tests must run the baseline scenario and confirm its role is documented. |
| REQ-012 | `DE-03 TargetTruthEngine`, `DE-06 CompatibilityTruthWriter`, `DE-08 SessionCompatibilitySmokeCheck` | The output set includes both workflow-compatible truth and a direct traceability artifact, enabling downstream comparison of detections or tracks to known truth. | Tests must confirm the downstream analysis result can be compared to truth for the same synthetic run. |

## Design Risks And Open Questions
- Risk 1: The installed MATLAB toolchain does not include a native ATSC waveform generator. The recommended v1 mitigation is to use a captured reference-channel HDTV seed. If a fully synthetic HDTV waveform becomes mandatory, this design must be reopened.
- Risk 2: Existing repo files contain multiple close but non-identical Tx/Rx coordinate and frequency defaults. The mitigation is to make `DE-01 ScenarioConfig` the single source of truth and to treat current analysis fallbacks as non-authoritative.
- Risk 3: V1 omits diffuse terrain-clutter reflectivity and building scattering. This keeps the design tight for detector and truth-projection triage, but clutter-limited conclusions will remain provisional until a later phase adds `clutterGenerator` and `surfaceReflectivityLand`-based modeling.
- Open question 1: Human review should confirm whether the preferred v1 illuminator seed is a clean captured reference-channel slice from the current site or a curated external seed dataset managed outside the repo.

## Blocking Questions Or Missing Information
- Blocking question 1: none for this draft design packet
- Missing interface expectation: none at the draft baseline; the design fixes v1 compatibility around the existing `.bb` packaged-session and SBS-1 truth contracts
- Missing system constraint: none at the draft baseline beyond the approved requirement to stay tight and avoid high-fidelity clutter modeling in v1
- Missing subsystem-boundary input: none at the draft baseline

## Optional Formal Model References
- `System Composer` model or diagram: none for this draft; markdown remains the control-plane artifact for the first design submission
- Additional reference artifact: [n42_w072_1arc_v3.dt2](n42_w072_1arc_v3.dt2)

## Approval
- Human decision: `Approved`
- Approved by: Human orchestrator
- Approval date: `2026-07-10`
- Conditions: Design is approved with the v1 illuminator-seed assumption, the dual truth-artifact strategy, and the packaged-session compatibility contract accepted as the baseline entering `Test Design`
