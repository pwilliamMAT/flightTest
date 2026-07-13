# Requirements Packet: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this artifact to convert the approved [CONOPS_Brief.md](CONOPS_Brief.md) and approved System Context Diagram into an atomic, testable requirement baseline.

## Metadata
- Session: `2026-07-10 synthetic HDTV simulation requirements`
- Date: `2026-07-10`
- Current phase: `Requirements`
- Related CONOPS Brief: [CONOPS_Brief.md](CONOPS_Brief.md)
- Related System Context Diagram: [SyntheticHDTVSimulation_CONOPS_Context.slx](SyntheticHDTVSimulation_CONOPS_Context.slx)
- Owner: Human orchestrator with Codex support
- Status: `Approved`

## Requirement Quality Rules
- No hidden design decisions unless the constraint is itself a requirement.
- Each requirement has a source and a proposed verification method.
- If a requirement cannot be tested, it must be revised before approval.

## Requirement Table
| ID | Requirement statement | Type | Source scenario or driver | Rationale | Proposed verification method | Priority | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| REQ-001 | The baseline simulation capability shall define one transmitter site and one receiver site using geodetic coordinates that represent the approved bistatic deployment context. | Interface | CONOPS Mission Outcome; Scope; System Context Diagram | The simulation must stay anchored to the real field geometry it is intended to de-risk. | Inspection of scenario inputs and demonstration of one baseline scenario using explicit Tx/Rx geodetic definitions. | High | Approved |
| REQ-002 | The simulation shall accept one or more time-varying target trajectories as truth inputs for each scenario run. | Functional | CONOPS Mission Outcome; Operational Scenario 1; Operational Scenario 2 | Controlled target truth is required to separate detector behavior from field ambiguity. | Inspection of scenario interface and demonstration with at least one synthetic aircraft trajectory. | High | Approved |
| REQ-003 | For the Apple Hill Natick baseline, the simulation shall accept terrain-surface context derived from DTED data covering the area near the approved transmitter and receiver locations. Building models are not required in v1. | Interface | Requirements Review resolution; CONOPS Scope; Available Assets; Native Function Audit | The baseline must remain site-consistent while keeping v1 tight and avoiding unnecessary building-model scope. | Inspection of scenario inputs and demonstration that the baseline scenario references DTED-derived terrain near the approved Tx/Rx locations. | Medium | Approved |
| REQ-004 | The simulation shall emit synthetic radar session data for each approved scenario run. | Functional | CONOPS Project end state; Operational Scenario 1 | Synthetic radar session data is the core artifact required to exercise the downstream workflow on controlled inputs. | Demonstration that an approved scenario run produces synthetic radar session artifacts. | High | Approved |
| REQ-005 | The simulation shall emit truth outputs that remain traceable to the synthetic target trajectories for the same scenario run. | Data | CONOPS Project end state; Operational Scenario 1 | Evaluation is not credible unless every synthetic run can be mapped back to known target truth. | Inspection of output truth artifacts and test that each truth record traces to a declared synthetic trajectory. | High | Approved |
| REQ-006 | The simulation shall emit metadata that preserves the frequency, sampling, timing, and manifest fields required by the current passive radar session-analysis workflow. | Interface | CONOPS Available Assets; Scope; Evidence Needed To Enter Requirements | Current analysis behavior depends on capture metadata and timing context, so the synthetic contract must preserve those fields. | Inspection of emitted metadata against the approved current workflow contract and demonstration through session preflight. | High | Approved |
| REQ-007 | The emitted synthetic artifact set shall be packaged so that the existing passive radar analysis workflow can consume it without manual edits to core analysis entrypoints. | Interface | CONOPS Scope; System Context Diagram; Available Assets | The simulation must connect to the existing workflow rather than requiring a separate one-off analysis path. | Demonstration by running the standard session-analysis entrypoint on the emitted artifact set without changing core analysis code. | High | Approved |
| REQ-008 | When truth is expressed in bistatic measurement space, it shall use the same bistatic conventions as the current analysis workflow. | Compatibility | CONOPS Assumption accepted temporarily; Available Assets | Comparison against the current detector and truth-projection path requires convention compatibility rather than a parallel truth definition. | Test against a controlled reference case and inspection of truth-convention documentation for the emitted artifacts. | High | Approved |
| REQ-009 | Given the same approved scenario inputs, the simulation shall reproduce the same truth and metadata outputs across reruns. Reproducibility of emitted synthetic radar session data across reruns is not required. | Quality | Requirements Review resolution; CONOPS Operational Scenario 2; Hazards And Risks | The workflow needs stable truth and metadata for controlled evaluation, while allowing simulation reruns to produce different synthetic radar session data when that is acceptable to the operator. | Repeatability test using the same approved inputs across multiple reruns for truth and metadata outputs, plus inspection that saved emitted artifact sets remain usable without rerunning the scenario. | High | Approved |
| REQ-010 | The emitted artifact set shall include manifest-level provenance fields that explicitly identify the outputs as synthetic rather than field-captured. At minimum, the manifest shall record `data_origin`, `scenario_id`, `generator_name`, `generation_time_utc`, and `truth_source`, and it shall record `random_seed` whenever stochastic generation is used. | Data | CONOPS Hazards And Risks; Failure condition that matters | Synthetic provenance must stay explicit so later evidence is not confused with field data. | Inspection of artifact metadata and manifest contents for the required provenance markers. | Medium | Approved |
| REQ-011 | The baseline simulation capability shall include at least one controlled scenario intended to isolate detector and truth-projection behavior from field-capture ambiguity. | Functional | CONOPS Operational Scenario 1; Mission Outcome | The first baseline must prove the simulation can answer the current operational question before broader expansion. | Demonstration of one controlled baseline scenario and inspection that the scenario is documented as detector or truth-projection triage. | High | Approved |
| REQ-012 | The emitted synthetic artifact set shall contain enough information to support downstream comparison of detections or tracks against known truth for the same synthetic run using the existing passive radar analysis workflow. | Functional | CONOPS Project end state; Operational Scenario 1; Operational Scenario 2 | The downstream purpose of the simulation is evaluation against known truth through the existing workflow, not synthetic generation in isolation. | Demonstration that a downstream analysis result from the existing workflow can be compared against the emitted truth for the same run. | High | Approved |

## Cross-Cutting Constraints
- Constraint 1: The baseline requirement intent remains tied to the approved Apple Hill and CBS deployment context, packaged-session conventions, and approved `CONOPS` assumptions unless a later phase explicitly changes that baseline.
- Constraint 2: The baseline requirement intent remains tightly scoped to synthetic scenario generation and supporting outputs; detector redesign, full digital-twin expansion, and substituting synthetic evidence for later real-data validation remain out of scope.
- Constraint 3: The first-pass requirement intent favors compatibility with the existing passive radar workflow over broad feature expansion.
- Constraint 4: The first-pass baseline requires physical site or terrain-surface context, but it does not require a high-fidelity land-clutter reflectivity model.
- Constraint 5: The existing downstream passive radar analysis workflow remains the detector and tracker of record for baseline evaluation.

## Blocking Questions Or Missing Information
- Blocking question 1: none at the current draft baseline
- Missing source or operational intent: none at the current draft baseline
- Missing acceptance intent or proposed verification method: none at the current draft baseline
- Scope ambiguity that changes requirement wording: none at the current draft baseline
- Cross-cutting constraint still unresolved: none at the current draft baseline

## Open Ambiguities
- None at the current draft baseline.

## Approval
- Review required before use in design: `Yes`
- Approved by: Human orchestrator
- Approval date: `2026-07-10`
- Notes: Approved as the submitted requirement baseline entering `Requirements Review`.
