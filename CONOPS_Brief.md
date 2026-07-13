# CONOPS Brief: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this artifact to define the operational concept for the synthetic HDTV simulation effort before requirements are written.

## Metadata
- Session: `2026-07-10 synthetic HDTV simulation CONOPS`
- Date: `2026-07-10`
- Current phase: `CONOPS`
- Owner: Human orchestrator with Codex support
- Approved inputs:
  - User session brief naming `agentOrchestration/OperatingManual_v2.md` and `agentOrchestration/ImplementationPlan_v2.md`
  - [README.md](README.md)
  - [NEXT_SESSION_HANDOFF.md](NEXT_SESSION_HANDOFF.md)
  - [radarExpertDetectorTuning.md](radarExpertDetectorTuning.md)
  - [BistaticDataAnalysis/analyzeBistaticData.m](BistaticDataAnalysis/analyzeBistaticData.m)
  - [BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m](BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m)
  - [TestSetupTesting/runLocalHDTVCapture.m](TestSetupTesting/runLocalHDTVCapture.m)
  - [TestSetupTesting/run_coordinated_hdtv_capture.sh](TestSetupTesting/run_coordinated_hdtv_capture.sh)
- Status: `Approved`

## Native Function Audit
| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Tight site-specific passive bistatic HDTV simulation for the current Apple Hill receiver and CBS/ATSC transmitter geometry | MathWorks example `Simulating Site-Specific Bistatic Land Clutter` | Constrain the example to the repo's geometry, packaged-session conventions, and aircraft-evaluation use case instead of a broad environment study |
| Aircraft truth and scenario playback for detector triage | Radar Toolbox scenario workflows built around `radarScenario` and `geoTrajectory` | Preserve the current pipeline's time axis, geodetic geometry, and bistatic truth conventions so synthetic outputs can be compared to existing analysis products |
| Context-only operational modeling for CODRTIV v2 `CONOPS` | System Composer context-model workflow | Keep the artifact at the system boundary level with inputs, outputs, stakeholders, and adjacent systems only |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Scenario container for time-aligned synthetic runs | `radarScenario` (Radar Toolbox) | `scene = radarScenario` |
| Time-varying aircraft truth trajectories | `geoTrajectory` (Radar Toolbox) | `traj = geoTrajectory(...)` |
| Site surface and terrain context | `landSurface` (Radar Toolbox) | `surface = landSurface(...)` |
| Land-clutter reflectivity modeling | `surfaceReflectivityLand` (Radar Toolbox) | `reflectivity = surfaceReflectivityLand(...)` |
| Context-diagram artifact creation | `systemcomposer.createModel` (System Composer) | `model = systemcomposer.createModel(modelName)` |

## Mission Outcome
- Project end state: a tight MATLAB simulation that generates synthetic HDTV-like passive bistatic data, truth, and evaluation-ready outputs consistent with the current field setup so the team can judge detector and truth-projection behavior against controlled ground truth
- Operational objective: separate algorithmic limits from RF, timing, geometry, and hardware ambiguity by replaying controlled scenarios through the existing passive radar workflow
- Intended user or stakeholder: radar algorithm developer, passive-radar integration engineer, and project owner deciding whether the detector family is fit for this dataset
- Success condition: the future simulation effort can emit reusable scenario artifacts that stay tied to the current test geometry and metadata conventions, and those artifacts can be used to evaluate processing behavior against known truth without field-capture ambiguity
- Failure condition that matters: the simulation cannot be mapped cleanly back to truth or current session metadata, so synthetic results do not discriminate detector problems from non-algorithmic issues

## Scope
- In scope:
  - define the operational role of a synthetic HDTV scenario generator tied to the current passive radar workflow
  - identify which geometry, timing, RF metadata, and truth interfaces must be extracted from the current pipeline and hardware setup
  - define the system boundary and adjacent systems for the future simulation effort
- Out of scope:
  - detector redesign, CFAR tuning, clutter-model implementation details, waveform code generation, and verification thresholds
  - using synthetic results as a substitute for later real-data validation
  - building a full digital twin of the capture site or hardware stack
- Assumptions:
  - the current repo geometry, packaged-session metadata, and bistatic truth conventions are the baseline until a later phase freezes any refined transmitter naming or coordinates
  - the minimum useful simulation output includes synthetic HDTV-like session data plus truth and evaluation-side artifacts that remain compatible with the current pipeline
- Constraints:
  - remain in `CONOPS` and avoid algorithm, design, test, or implementation commitments
  - prioritize native MathWorks workflows over custom infrastructure
  - keep the simulation effort deliberately tight and aligned to the relevant portions of the cited MathWorks bistatic land-clutter example

## System Context Diagram
- Diagram artifact path or model name: `SyntheticHDTVSimulation_CONOPS_Context.slx`
- Diagram status: `Approved`
- README screenshot or export path: `docs/CONOPS-SystemContextDiagram.png`
- Caption: The diagram treats `Synthetic HDTV Scenario Generator` as the system of interest. It accepts operator-defined CONOPS inputs plus physical geometry, session metadata, truth/scenario inputs, and site/environment context, and it outputs synthetic session artifacts to the existing passive radar analysis and evaluation workflows.
- System-of-interest boundary shown: one central simulation component only
- Stakeholders or operators shown: `Radar Analyst`
- External systems or services shown: `Physical Test Geometry`, `Capture Session Metadata`, `Site and Environment Data`, `Truth and Scenario Inputs`, `Passive Radar Analysis Pipeline`, and `Detector and Tracker Evaluation`
- Primary inputs and outputs shown: `conops`, `geometry`, `captureMeta`, `siteData`, `truthDef`, `syntheticSession`, and `evalBundle`
- Out-of-scope or adjacent systems called out: downstream detector redesign and field-hardware retuning remain outside this `CONOPS` boundary

## Blocking Questions Or Missing Information
- Blocking question 1: none at the `CONOPS` level; the exact synthetic artifact contract is deferred to `Requirements`
- Blocking question 2: none at the `CONOPS` level; the exact land-clutter fidelity and site-data source are deferred to `Requirements`
- Assumption accepted temporarily: packaged-session compatibility is the default consumer contract, and truth should remain usable in both geodetic and bistatic measurement space

## Available Assets
- Dataset or file 1: [TestSetupTesting/runLocalHDTVCapture.m](TestSetupTesting/runLocalHDTVCapture.m) and [TestSetupTesting/run_coordinated_hdtv_capture.sh](TestSetupTesting/run_coordinated_hdtv_capture.sh)
  - Provenance or owner: current local and coordinated capture entrypoints in this repo
  - Intended role in the project: define current hardware defaults and packaged-session metadata that future synthetic outputs should mirror
  - Intake facts allowed in CONOPS: center frequency, sample rate, LO offset, gain defaults, capture repetition spacing, radar epoch capture, and manifest schema
- Dataset or file 2: [BistaticDataAnalysis/analyzeBistaticData.m](BistaticDataAnalysis/analyzeBistaticData.m), [BistaticDataAnalysis/runBistaticAnalysisSession.m](BistaticDataAnalysis/runBistaticAnalysisSession.m), and [BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m](BistaticDataAnalysis/helperResolveSessionAnalysisSetup.m)
  - Provenance or owner: current analysis pipeline and session-wrapper logic
  - Intended role in the project: define the consumer-side contract for synthetic sessions and the current Tx/Rx geometry defaults
  - Intake facts allowed in CONOPS: expected manifest fields, ADS-B truth slot usage, timing metadata usage, and fallback Tx/Rx coordinates
- Dataset or file 3: [NEXT_SESSION_HANDOFF.md](NEXT_SESSION_HANDOFF.md), [radarExpertDetectorTuning.md](radarExpertDetectorTuning.md), and [README.md](README.md)
  - Provenance or owner: prior project notes and current repo documentation
  - Intended role in the project: capture why the simulation is needed now
  - Intake facts allowed in CONOPS: unresolved ambiguity between RF sufficiency, geometry or timing bias, and detector-family limits
- Dataset or file 4: `captures/`
  - Provenance or owner: packaged-session root expected by the current workflow
  - Intended role in the project: future source of field-session metadata and replay comparisons
  - Intake facts allowed in CONOPS: not available in this local workspace at the time of this brief

## Deferred Technical Questions
- What is the minimum required synthetic artifact set: full IQ only, truth plus expected detections only, or a combined bundle?
- Which site/environment datasets from the MathWorks example are required for credibility and which are intentionally excluded to keep the effort tight?
- Should expected detections be generated by the existing downstream pipeline only, by a synthetic reference generator, or by both?
- What synthetic-provenance fields must be added to the packaged-session schema without breaking current analysis wrappers?

## Operational Scenarios
### Scenario 1
- Trigger: detector misses on real data remain ambiguous between algorithmic and non-algorithmic causes
- Expected behavior: the synthetic scenario generator accepts approved geometry, timing, and aircraft-truth definitions and emits a controlled session bundle plus aligned truth products
- Observable outcome: downstream analysis can compare detections to known truth without field-capture ambiguity

### Scenario 2
- Trigger: a future detector or truth-projection change needs a repeatable benchmark before returning to real data
- Expected behavior: the same synthetic scenario can be regenerated with stable metadata and replayed through the current workflow
- Observable outcome: changes in behavior can be attributed to code or parameter changes instead of changing field conditions

## Hazards And Risks
- Hazard or risk 1: overfitting the synthetic scenario to current detector assumptions could hide geometry, timing, or hardware problems instead of exposing them
- Hazard or risk 2: breaking packaged-session compatibility would make the simulation operationally disconnected from the current analysis workflow
- Hazard or risk 3: solving real datasets during `CONOPS` would bias the next-phase requirements baseline

## Evidence Needed To Enter Requirements
- Evidence item 1: approved system boundary, stakeholders, non-goals, and success conditions for the synthetic simulation effort
- Evidence item 2: approved context diagram recorded in [README.md](README.md)
- Evidence item 3: inventory of current pipeline and hardware metadata that the future simulation must preserve

## Approval
- Human decision:
- Approved by: Human orchestrator
- Approval date: `2026-07-10`
- Conditions: Proceed to `Requirements` using this brief and its companion System Context Diagram as the approved baseline.
