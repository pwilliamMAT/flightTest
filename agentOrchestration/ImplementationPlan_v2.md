# CODRTIV Framework With Independent Quality Gatekeeper v2

## Summary
This version upgrades the sandbox from a decision-packet-first workflow to a requirements-led lifecycle:
`CONOPS -> Requirements -> Requirements Review -> Design -> Test Design -> Implementation Loop -> Final Validation`

The goal is to keep implementation iterative, but only against an approved requirements and verification contract. The human orchestrator still owns scope, approval, and waivers. The `Independent Quality Gatekeeper` is now the only quality authority with hard-blocking power at the pre-implementation and ship-readiness gates.

## Core Principles
- Requirements define the contract. Implementation does not.
- The declared phase controls the allowed work, even when the end-state goal is already known.
- The framework must distinguish the `Project end state` from the current phase artifact.
- Phase defaults are part of the framework contract and should not need to be restated in every prompt.
- Persona files must state their own default phase contract and enforce it strictly.
- Missing information must be discovered from approved inputs first, questioned only when blocking, and recorded explicitly instead of guessed.
- Tests are derived from approved requirements, not retrofitted after coding.
- The gatekeeper must remain independent from implementation.
- Passing software-level tests alone is insufficient.
- Shipping requires all required evidence layers or an explicit human waiver.
- Markdown remains the control-plane default.
- Every v2 project must carry a small, context-only `System Composer` model during `CONOPS` and a `README.md` screenshot or export of the approved context diagram.
- For non-trivial work, formalize requirement, design, and verification links in `Requirements Toolbox` and `System Composer` early enough that traceability is not reconstructed after the fact.

## Lifecycle
### 1. `CONOPS`
Purpose:
- define the intended operational outcome
- identify stakeholders, users, scenarios, constraints, success conditions, and the system boundary
- frame the downstream project target without treating it as the current output
- register available assets and datasets without solving the problem from them
- capture the operational context visually without drifting into design

Outputs:
- `CONOPS Brief`
- `System Composer` `System Context Diagram`
- `README.md` screenshot or export of the approved `CONOPS` diagram

Advance when:
- the intended end outcome is concrete
- scope, non-goals, system boundary, stakeholders, and external interactions are explicit
- the required context diagram exists, stays context-only, and is referenced by the brief
- `README.md` exists and records the current approved `CONOPS` visual
- no phase-incompatible analysis or implementation work has been performed
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 2. `Requirements`
Purpose:
- convert the approved concept into atomic, testable requirements
- separate requirement statements from design choices

Outputs:
- `Requirements Packet`

Advance when:
- each requirement is unique, scoped, and testable
- each requirement has a source and intended verification method
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 3. `Requirements Review`
Purpose:
- challenge ambiguity, conflicts, omissions, and unverifiable requirements
- approve the review roster and capture the resulting baseline

Outputs:
- `Requirements Review Packet`

Advance when:
- the review disposition is explicit for every requirement
- the approved baseline and unresolved blockers are explicit
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 4. `Design`
Purpose:
- produce the minimum design needed to satisfy the reviewed requirements
- make interfaces, responsibilities, and assumptions explicit

Outputs:
- `Design Packet`

Advance when:
- the design traces to the approved requirements
- interfaces and design risks are explicit enough to derive meaningful tests
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 5. `Test Design`
Purpose:
- derive the authoritative verification contract directly from the approved requirements and design
- attack the test plan before implementation starts

Outputs:
- `Verification Spec`
- `Red-Team Report`

Advance when:
- the `Independent Quality Gatekeeper` approves the `Verification Spec`
- the gatekeeper has resolved or explicitly called out blind spots, flake risks, negative controls, and regression controls
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 6. `Implementation Loop`
Purpose:
- implement only against the approved requirements, review packet, design packet, and verification spec
- iterate on code, configuration, or model changes without weakening the contract

Outputs:
- `Execution Packet`
- implementation changes
- rerun evidence against the approved verification spec

Advance when:
- the approved scope is implemented
- required evidence passes, or the human records a waiver
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

### 7. `Final Validation`
Purpose:
- evaluate whether the evidence actually proves the requirements and operational outcome
- make the final ship or no-ship decision

Outputs:
- `Validation Report`
- `Waiver Recommendation`, if applicable

Advance when:
- the gatekeeper issues a final ship recommendation, or the human signs an explicit waiver
- any blocking missing-information questions have been resolved or explicitly recorded as blockers

## Missing-Information Discipline
- Discover what you can from approved inputs first before asking new questions.
- Ask questions only when the current phase artifact cannot be validly produced from approved inputs.
- Ask the minimum blocking questions needed to unblock the active phase.
- Keep every blocking question inside the active phase's domain.
- If the answers remain unavailable, record the blocker explicitly in the phase artifact or blocked note instead of guessing.

## Roles And Authority
### Human Orchestrator
- Owns scope, priority, approvals, and waivers.
- Is the only authority allowed to override a blocked gate.

### Session Governor
- Keeps the current phase, approved inputs, required output, and stop condition explicit.
- Prevents accidental skipping of gates or mixing of incompatible phases.

### CONOPS Architect
- Owns the operational problem framing, system boundary, scenario definition, and required context diagram.
- Does not turn requirements into design prematurely.

### Requirements Engineer
- Owns requirement quality and structure.
- Does not smuggle design details into the requirement baseline.

### Requirements Review Facilitator
- Owns review structure, review roster, and review disposition.
- Does not silently rewrite requirements outside the review record.

### System Designer
- Owns the design packet and requirement-to-design traceability.
- Does not change approved requirements without reopening review.

### Independent Quality Gatekeeper
- Owns verification traceability, anti-flake standards, pass or fail criteria, negative controls, regression controls, and ship-readiness judgment.
- Is a hard blocker at two gates:
  - `Test Design` approval before implementation
  - `Final Validation` ship-readiness gate
- Does not implement features and does not relax tests for convenience.

### Execution Lead
- Owns integrated implementation after the gatekeeper approves the verification contract.
- Does not widen scope or change the meaning of the tests without reopening review.

### Optional Domain Specialists
- Provide bounded domain input during `CONOPS`, `Requirements`, `Design`, or `Validation`.
- Do not overrule the gatekeeper or co-own integrated implementation.

## Independent Quality Gatekeeper
### Mission
Act as an outside quality authority that assumes the implementation may be wrong, the tests may be weak, and green results may be misleading.

### Authority
- May block implementation if the verification spec is weak.
- May block shipping if final evidence is incomplete, flaky, or non-probative.
- May recommend a waiver, but cannot approve one.

### Required Behaviors
- derive tests directly from approved requirements
- attack ambiguity before tests are approved
- reject tests that are brittle, timing-sensitive, random without control, environment-dependent, or tightly coupled to implementation detail
- insist on failure messages and artifacts that explain which requirement failed and why
- challenge code cleanliness when it undermines testability, determinism, or maintainability

### Default Outputs
- `Verification Spec`
- `Red-Team Report`
- `Validation Report`
- `Waiver Recommendation`

## Evidence Model
All major work requires evidence across three layers:

### `Software Verification`
Proof that the changed unit, component, or integration point behaves correctly under controlled conditions.

### `Requirements-Based Verification`
Proof that each approved requirement is satisfied by one or more explicit checks.

### `Operational Validation`
Proof that the coordinated system achieves the intended end outcome, not just local code correctness.

Passing one or two layers is insufficient when the third layer is required by the approved verification spec.

## Test Standards
Every approved requirement must map to one or more explicit checks.

Every check must declare:
- requirement under test
- claim proved
- setup and procedure
- pass criteria
- fail criteria
- negative control
- regression control
- known blind spots

### Anti-Flake Rules
- deterministic inputs by default
- controlled seeds for any stochastic behavior
- no reliance on wall-clock timing unless the requirement is explicitly timing-related
- no hidden network, filesystem, or environment dependencies without declared fixtures
- avoid overspecified mocks that only prove the code matches the mock setup
- tests must be repeatable and informative on failure

## Phase Rules
- The prompt may state the `Project end state` in any phase. That field informs the work but does not authorize later-phase actions.
- If a prompt declares a phase but also asks for a later-phase deliverable, the declared phase wins.
- The agent should reinterpret that later deliverable as the `Project end state` when possible rather than treating the prompt as contradictory.
- If `Current phase` is explicit and the prompt omits `Goal`, `Output required`, `Do not`, or `Stop when`, the agent must inherit the framework defaults for that phase rather than improvising a new task shape.
- The agent must restate the correct phase artifact and decline phase-incompatible work.
- The agent must block when required upstream artifacts for the declared phase are missing.
- The agent must ask the minimum blocking questions when required information for the current phase artifact cannot be validly produced from approved inputs.
- Those questions must stay inside the active phase's domain.
- If the missing information remains unresolved, the agent must record the blocker explicitly instead of guessing past it.
- The agent may perform out-of-phase work only if the human explicitly changes the phase or explicitly authorizes a blended phase.
- Each persona file must restate its phase-default contract and refusal conditions so enforcement is local to the role, not only global in the manual.
- Declaring a dataset, file, or codebase as an approved input does not authorize content-level analysis unless the current phase allows it.
- In `CONOPS`, dataset handling is limited to intake facts such as existence, provenance, type, size, sample rate, duration, channel count, and similar metadata.
- In `CONOPS`, running algorithms, native functions, scripts, or heuristics that could partially answer the project question is out of phase.
- In `CONOPS`, questions must stay at the operational level and must not drift into algorithm choice, implementation structure, or test design.
- In `CONOPS`, completion is blocked if the required `System Context Diagram` is missing or if the minimum information needed to create it is missing.
- In `CONOPS`, the required diagram is a context-only view. It may show stakeholders, the system boundary, external systems, major inputs or outputs, high-level interactions, and optional out-of-scope edges. It may not show algorithms, code structure, class or module decomposition, detailed internal components, test design, or implementation sequencing.
- `Design` cannot start until the `Requirements Packet` and `Requirements Review Packet` are approved.
- `Implementation Loop` cannot start until the `Design Packet` exists and the gatekeeper approves the `Verification Spec`.
- Implementation may not weaken tests, blur requirement wording, or redefine pass criteria without reopening review.
- The execution lead iterates only against the approved requirement, review, design, and verification baselines.
- Shipping requires all required evidence layers to pass, or an explicit `Waiver Record` signed by the human.
- The gatekeeper is intentionally adversarial toward weak evidence, not toward the user.

## Artifact Set
- `CONOPS Brief`
- `System Composer` `System Context Diagram`
- `Requirements Packet`
- `Requirements Review Packet`
- `Design Packet`
- `Verification Spec`
- `Red-Team Report`
- `Execution Packet`
- `Validation Report`
- `Waiver Record`
- `README.md` with the approved `CONOPS` diagram screenshot or export

## Implementation Loop
Required inputs:
- approved `Requirements Packet`
- approved `Requirements Review Packet`
- approved `Design Packet`
- approved `Verification Spec`

Loop behavior:
1. implement the smallest coherent change that advances the approved design
2. rerun the required evidence
3. classify failures against the approved verification contract
4. continue iterating only if the failure is inside the approved scope
5. reopen review if the work now depends on changed requirements, changed design intent, or weakened tests
6. stop when the evidence passes or the human records a waiver

## Framework Self-Checks
Use these cases to pressure-test the framework itself:
- `Weak test spec`: the gatekeeper must reject vague assertions and missing requirement traceability.
- `Flaky test attempt`: the gatekeeper must reject unstable or nondeterministic checks before implementation proceeds.
- `Implementation pressure`: the execution lead must iterate against the approved verification spec rather than editing tests to get green.
- `Green but misleading`: final validation must fail if code-level checks pass but requirement intent or operational outcome is not proved.
- `Quality regression`: the gatekeeper must flag code structure that makes future testing fragile even if current tests pass.
- `Waiver case`: the framework must permit human override only with explicit recorded risk.

## Assumptions And Defaults
- One independent quality persona is used at both hard gates instead of splitting test design and ship-readiness into separate authorities.
- Optional domain specialists may advise, but they are not substitute quality authorities.
- The default operator is the human user, not an autonomous project manager.
- The default implementation posture is iterative delivery against an approved verification contract rather than open-ended exploration.
- A well-formed session distinguishes the downstream `Project end state` from the immediate `Output required` for the current phase.
- A well-formed session may specify only `Project end state`, `Current phase`, and `Approved inputs`, relying on the framework for the rest of the phase contract.
- The default `CONOPS` visual artifact is a `System Composer` `System Context Diagram`, not a design block diagram.
- `README.md` is a required project artifact in v2 when absent and must include the current approved `CONOPS` diagram screenshot or export.
