# CODRTIV Operating Manual v2

## What This Manual Is For
Use this manual when you want Codex sessions to follow the requirements-led CODRTIV lifecycle instead of falling into ad hoc implementation. Pair it with `ImplementationPlan_v2.md`.

This manual is for the human orchestrator first. Agents can use it to classify the session, but they should not silently choose a phase or skip a gate for you.

## Fast Start
Minimal prompt contract:
- `Project end state`
- `Current phase`
- `Approved inputs`

Optional override fields:
- `Project end state`
- `Goal`
- `Output required`
- `Do not`
- `Stop when`

If `Current phase` is explicit and the optional override fields are omitted, the framework defaults for that phase apply automatically.

Then answer four operator questions:
1. Which of the seven phases is actually in scope right now?
2. Which artifacts already exist and are approved?
3. Which roles are needed for this phase and which are not?
4. What exact gate must be cleared before the next phase can begin?

Use these fields with different meanings:
- `Project end state`: the real downstream outcome or deliverable the project is trying to reach
- `Goal`: the objective of the current phase
- `Output required`: the artifact or decision that must be produced in the current phase

## Conflict Resolution Rules
- Stating the `Project end state` in an early-phase prompt is allowed and encouraged.
- The declared `Current phase` and its artifact control the allowed work, even when the `Project end state` is already known.
- If the prompt names an early phase and also names a later deliverable such as a function, implementation, decoded answer, or validation result, treat that later deliverable as the `Project end state`, not as current scope.
- If `Goal`, `Output required`, `Do not`, or `Stop when` are omitted, inherit the framework defaults for the declared phase.
- `Output required` must resolve to the artifact for the declared phase. If the prompt conflicts with that rule, restate the correct artifact and stay in phase.
- `Approved inputs` are not blanket permission to analyze everything deeply. Use them only in ways that are allowed by the current phase.

## Phase Map
Use exactly one of these as `Current phase`:
- `CONOPS`
- `Requirements`
- `Requirements Review`
- `Design`
- `Test Design`
- `Implementation Loop`
- `Final Validation`

Do not blend `Design`, `Implementation Loop`, and `Final Validation` into one prompt unless the work is trivial and the human explicitly accepts the reduced ceremony.

## Dataset Intake Rules
### `CONOPS`
Allowed use of a named dataset or file:
- existence and path confirmation
- provenance, ownership, and intended role in the project
- file type, size, sample rate, duration, channel count, and similar intake metadata

Not allowed in `CONOPS`:
- content-level inspection that answers part of the project question
- decoding, classification, transcription, measurement, or benchmarking
- running native functions, scripts, or heuristics that could partially solve the task
- generating requirements, design choices, or implementation detail from solved data

If deeper dataset inspection would answer the project question, stop and defer it to a later phase or require an explicit human override.

## Required Outputs By Phase
- `CONOPS`: `CONOPS Brief`, `System Composer` `System Context Diagram`, and `README.md` with a current screenshot or export of the approved `CONOPS` diagram
- `Requirements`: `Requirements Packet`
- `Requirements Review`: `Requirements Review Packet`
- `Design`: `Design Packet`
- `Test Design`: `Verification Spec` and `Red-Team Report`
- `Implementation Loop`: `Execution Packet` plus implementation changes
- `Final Validation`: `Validation Report`, or `Waiver Recommendation` if the evidence is incomplete

## Phase-Default Contract
When `Current phase` is declared, these defaults apply unless the prompt explicitly overrides them.

### `CONOPS`
- Default goal: define the operational objective, scope, constraints, stakeholders, scenarios, success conditions, and system context boundary
- Default output: `CONOPS Brief`, `System Composer` `System Context Diagram`, and `README.md` screenshot or export update
- Default do not: do not inspect dataset contents beyond intake metadata, do not decode or classify, do not write requirements, design, or code, and do not substitute a design-level block diagram for the required context view
- Default stop when: the operational problem, non-goals, system boundary, stakeholders, external interactions, and success conditions are explicit, and the approved context diagram is recorded in `README.md`

### `Requirements`
- Default goal: convert the approved `CONOPS Brief` and `System Context Diagram` into atomic, testable requirements
- Default output: `Requirements Packet`
- Default do not: do not smuggle design decisions into the requirement baseline
- Default stop when: each requirement has an ID, statement, rationale, and verification method

### `Requirements Review`
- Default goal: challenge ambiguity, conflicts, omissions, and unverifiable requirements
- Default output: `Requirements Review Packet`
- Default do not: do not silently rewrite the baseline outside the review record
- Default stop when: the approved baseline and unresolved blockers are explicit

### `Design`
- Default goal: produce the minimum design that satisfies the approved requirements
- Default output: `Design Packet`
- Default do not: do not reopen requirement scope without saying so
- Default stop when: requirement-to-design traceability and interface assumptions are explicit

### `Test Design`
- Default goal: derive and approve the verification contract directly from the approved requirements and design
- Default output: `Verification Spec` and `Red-Team Report`
- Default do not: do not implement features or weaken tests for convenience
- Default stop when: every approved requirement has explicit checks, controls, and pass or fail criteria

### `Implementation Loop`
- Default goal: implement the approved scope only and rerun the approved evidence
- Default output: `Execution Packet` plus implementation changes
- Default do not: do not widen scope or edit the meaning of the tests
- Default stop when: the approved scope is implemented or a material blocker requires reopening review

### `Final Validation`
- Default goal: judge whether the evidence proves the requirements and operational outcome
- Default output: `Validation Report`
- Default do not: do not declare success from code-level green checks alone
- Default stop when: ship, no-ship, escalation, or waiver recommendation is explicit

## Missing-Information Rules
These rules apply in every phase:
- discover what you can from approved inputs first
- ask questions only when the missing information is necessary to produce the current phase artifact validly
- ask the minimum number of blocking questions needed to unblock the phase
- keep questions inside the active phase's allowed domain
- if the missing information cannot be derived or answered, stop and report a short phase-specific blocked note instead of guessing

### `CONOPS`
- Questions in this phase should clarify operational intent, users, success conditions, scope, and constraints.
- Blocking missing information usually means one or more of:
  - no clear `Project end state`
  - no intended operator, user, or stakeholder
  - no operational success condition
  - no system-of-interest boundary
  - no external interaction context or major input or output
  - no scope boundary or non-goals
  - no key operational constraint that materially changes the concept
- A `CONOPS` phase is also blocked if the brief lacks the required `System Context Diagram` and the minimum information needed to create it cannot be derived.
- Prioritize questions in this order when multiple blockers exist:
  - operational success condition
  - intended operator, user, or stakeholder
  - system-of-interest boundary
  - external interaction context or major input or output
  - scope boundary or non-goals
  - key operational constraint
- Do not ask implementation, algorithm, test-design, or code-structure questions in `CONOPS`.
- If the blocking information cannot be derived and is still missing, stop and report a short `CONOPS blocked by missing information` note instead of guessing.

### `Requirements`
- Questions in this phase should clarify requirement intent, source, scope, and verification intent.
- Blocking missing information usually means one or more of:
  - no approved `CONOPS Brief`
  - no approved `System Context Diagram`
  - no source for a requirement or requirement cluster
  - no operational intent needed to phrase a requirement
  - no acceptance intent or proposed verification method
  - no scope boundary that changes requirement wording
- Prioritize questions in this order when multiple blockers exist:
  - source intent
  - acceptance intent
  - scope ambiguity
  - cross-cutting constraints
- Do not ask about algorithm choice, design structure, implementation form, or test execution details beyond a proposed verification method.
- If the blocking information cannot be derived and is still missing, stop and report a short `Requirements blocked by missing information` note instead of guessing.

### `Requirements Review`
- Questions in this phase should clarify review governance, disposition authority, and unresolved ambiguity or conflict.
- Blocking missing information usually means one or more of:
  - no approved `Requirements Packet`
  - no review roster or review authority
  - no acceptance or disposition criteria
  - no context for a conflict or omission that prevents disposition
- Prioritize questions in this order when multiple blockers exist:
  - review authority
  - disposition criteria
  - unresolved conflict context
- Do not ask about design choices, implementation plans, or code or test execution details.
- If the blocking information cannot be derived and is still missing, stop and report a short `Requirements Review blocked by missing information` note instead of guessing.

### `Design`
- Questions in this phase should clarify interfaces, constraints, architecture boundaries, and assumptions needed for traceability.
- Blocking missing information usually means one or more of:
  - no approved `Requirements Packet`
  - no approved `Requirements Review Packet`
  - no interface expectations
  - no system constraints that affect architecture
  - no scope boundaries between subsystems
- Prioritize questions in this order when multiple blockers exist:
  - interface boundary
  - key constraints
  - subsystem ownership or scope
- Do not ask about implementation details, code structure, or final verification judgment.
- If the blocking information cannot be derived and is still missing, stop and report a short `Design blocked by missing information` note instead of guessing.

### `Test Design`
- Questions in this phase should clarify evidence, pass or fail criteria, controls, fixtures, and traceability completeness.
- Blocking missing information usually means one or more of:
  - no approved requirements or design artifacts needed to derive checks
  - no pass or fail criteria for a required check
  - no requirement-to-check traceability
  - no negative or regression controls
  - no fixture or environment declarations
- Prioritize questions in this order when multiple blockers exist:
  - approved upstream artifacts
  - requirement-to-check traceability
  - pass or fail criteria
  - negative and regression controls
  - fixture and environment declarations
- Do not ask how the implementation will be written, which code structure will be used, or which design alternative should be chosen.
- If the blocking information cannot be derived and is still missing, stop and report a short `Test Design blocked by missing information` note instead of guessing.

### `Implementation Loop`
- Questions in this phase should clarify approved scope, dependencies, ownership, and evidence handoff only.
- Blocking missing information usually means one or more of:
  - no approved baseline artifacts for the work in scope
  - no approved scope boundary for the current increment
  - no execution dependencies or ownership boundaries
  - no required validation handoff or evidence expectations
- Prioritize questions in this order when multiple blockers exist:
  - approved scope and baseline
  - execution dependencies
  - ownership boundaries
  - validation handoff expectations
- Do not reopen requirements, redesign the solution, or soften the verification contract unless the phase is explicitly changed.
- If the blocking information cannot be derived and is still missing, stop and report a short `Implementation Loop blocked by missing information` note instead of guessing.

### `Final Validation`
- Questions in this phase should clarify missing evidence, missing required checks, interpretation context, and waiver or escalation authority.
- Blocking missing information usually means one or more of:
  - no evidence for one or more required evidence layers
  - no required check result or outcome record
  - no approved verification or execution context needed to interpret failures
  - no waiver or escalation authority context when evidence is incomplete
- Prioritize questions in this order when multiple blockers exist:
  - required evidence layers
  - required checks or result records
  - interpretation context for failures
  - waiver or escalation authority context
- Do not redesign evidence by question, reopen implementation details as a substitute for evidence, or rewrite failed checks into passes.
- If the blocking information cannot be derived and is still missing, stop and report a short `Final Validation blocked by missing information` note instead of guessing.

## Strict Enforcement Rules
- Phase defaults are binding when `Current phase` is explicit and the corresponding fields are not overridden.
- A persona must refuse later-phase work in an earlier phase unless the human explicitly changes the phase or explicitly authorizes a blended phase.
- A persona must refuse earlier-phase authority it does not own, even if asked. Example: the execution lead does not approve requirements or ship readiness.
- If a later-phase deliverable appears in an earlier-phase prompt, reinterpret it as `Project end state` or future work and stay in phase.
- If required upstream artifacts are missing for the declared phase, stop and report the missing artifacts rather than improvising around them.
- If information required to produce the phase artifact is missing and cannot be derived from approved inputs, the persona must ask the minimum blocking questions before proceeding.
- Those questions must stay inside the declared phase's allowed domain.
- If the missing information remains unresolved, stop with the phase-specific blocked note instead of guessing.
- Approved inputs may only be inspected to the depth allowed by the declared phase.
- In `CONOPS`, a design-level block diagram, algorithm flow, class or module decomposition, detailed internal component view, test design, or implementation sequence does not satisfy the required `System Context Diagram`.
- In `CONOPS`, the required visual artifact is a small `System Composer` context model that shows the system boundary, stakeholders, external systems, major inputs or outputs, and optional out-of-scope edges without becoming a design artifact.
- Persona files are required to restate their own default phase contract and refusal behavior explicitly. The framework is not relying on operator memory.
- If the user wants to override a phase default, the override must be explicit in the prompt. Otherwise the default stands.

## Hard Gates
### Before Requirements
- `CONOPS Brief` exists.
- `System Composer` `System Context Diagram` exists and stays context-only.
- `README.md` exists and contains a current screenshot or export of the approved `CONOPS` diagram.

### Before Design
- `CONOPS Brief` exists.
- `Requirements Packet` exists.
- `Requirements Review Packet` exists.
- The approved requirement baseline is explicit.

### Before Implementation
- `Design Packet` exists.
- `Verification Spec` exists.
- The `Independent Quality Gatekeeper` has approved the verification contract.
- The human has explicitly approved the scope.

### Before Shipping
- Required software-verification evidence exists.
- Required requirements-based evidence exists.
- Required operational-validation evidence exists.
- The `Independent Quality Gatekeeper` has issued a ship or no-ship recommendation.
- Any waiver is explicit and recorded.

## Role Usage
- Use `SessionGovernor.md` when the phase boundary, approved inputs, or next artifact is unclear.
- Use `CONOPSArchitect.md` to frame the operational problem and success conditions.
- Use `RequirementsEngineer.md` to turn the concept into testable requirement statements.
- Use `RequirementsReviewFacilitator.md` to run the review and freeze the approved baseline.
- Use `SystemDesigner.md` to produce the minimum design that satisfies the approved requirements.
- Use `IndependentQualityGatekeeper.md` for the hard quality gates and evidence judgment.
- Use `ExecutionLead.md` only after the verification contract is approved.
- Use domain specialists as advisers, not as replacements for the gatekeeper or execution lead.

## Artifact Checklist
Use the companion templates in this folder:
- `TemplateCONOPSBrief.md`
- `TemplateRequirementsPacket.md`
- `TemplateRequirementsReviewPacket.md`
- `TemplateDesignPacket.md`
- `TemplateVerificationSpec.md`
- `TemplateRedTeamReport.md`
- `TemplateExecutionPacket.md`
- `TemplateValidationReport.md`
- `TemplateWaiverRecommendation.md`
- `TemplateWaiverRecord.md`

Project-level companion artifact:
- `README.md`, created if absent, with the current approved `CONOPS` diagram screenshot or export plus a short summary of the operational objective and scope boundary

Legacy note:
- `TemplateDecisionPacket.md` remains for the older v1 workflow and should not be the primary planning artifact for CODRTIV v2.

## Prompt Skeletons
### Session Governor Prompt
```text
Project end state: [real downstream outcome]
Current phase: [one CODRTIV phase]
Approved inputs: [list artifacts or say none]
```

### CONOPS Prompt
Use this when you want the session to produce the required concept brief and its visual companion. If an approved context diagram already exists, include it in `Approved inputs`; otherwise let `CONOPS` produce it.

```text
Project end state: [real downstream outcome]
Current phase: CONOPS
Approved inputs: [user goal, known operational context, approved System Context Diagram if one exists]
```

### Hard-Stop CONOPS Prompt
Use this when you want the session to stay strictly in `CONOPS` even if the project end goal is obvious.

```text
Project end state: [real downstream outcome]
Current phase: CONOPS
Approved inputs: [goal statement, asset names, file paths]
Phase authority: if any requested deliverable conflicts with CONOPS, CONOPS wins
Dataset rule: named files may be used only for intake metadata such as existence, type, size, sample rate, duration, and channels
Diagram rule: either provide the approved `System Composer` `System Context Diagram` as an input, or require `CONOPS` to produce it before the phase can complete
Diagram scope: context only; no algorithms, internal design structure, test design, or implementation sequencing
```

### Requirements Prompt
```text
Project end state: [real downstream outcome]
Current phase: Requirements
Approved inputs: [CONOPS Brief and approved System Context Diagram]
```

### Requirements Review Prompt
```text
Project end state: [real downstream outcome]
Current phase: Requirements Review
Approved inputs: [Requirements Packet]
```

### Design Prompt
```text
Project end state: [real downstream outcome]
Current phase: Design
Approved inputs: [Requirements Packet and Requirements Review Packet]
```

### Gatekeeper Prompt
```text
Project end state: [real downstream outcome]
Current phase: Test Design
Approved inputs: [Requirements Packet, Requirements Review Packet, Design Packet]
```

### Execution Lead Prompt
```text
Project end state: [real downstream outcome]
Current phase: Implementation Loop
Approved inputs: [Requirements Packet, Requirements Review Packet, Design Packet, Verification Spec]
```

### Final Validation Prompt
```text
Project end state: [real downstream outcome]
Current phase: Final Validation
Approved inputs: [Verification Spec, Execution Packet, evidence results]
```

## Quality Gatekeeper Rules
The `Independent Quality Gatekeeper` is mandatory at two points:
- after `Design`, to approve or reject the `Verification Spec`
- after implementation, to approve or reject ship readiness

The gatekeeper may block progress for:
- missing requirement traceability
- vague or non-probative tests
- flake risk
- undeclared environment dependencies
- missing negative controls
- missing regression controls
- evidence that is green but not meaningful

## Implementation Loop Rules
- Implement only against the approved requirement, review, design, and verification baselines.
- Rerun the agreed evidence after each meaningful increment.
- If a requirement changes, a design assumption changes, or the tests need to be softened, stop and reopen review.
- Do not convert schedule pressure into weaker verification.

## When To Formalize In MathWorks Tooling
Keep markdown as the control plane by default. Formalize into native tools when the work is non-trivial:
- use `Requirements Toolbox` when requirement IDs, reviews, traceability, or verification status need to persist beyond a single session
- use `System Composer` in `CONOPS` for the required context-only `System Context Diagram`, and again in `Design` when design elements and interfaces need durable ownership and requirement links
- use `Simulink Test` or equivalent managed test assets when the verification contract is large enough that ad hoc scripts will lose traceability

## Common Failure Patterns
### Requirements Drift
Symptom:
- implementation or design introduces behavior that is not in the approved requirement baseline

Response:
- stop the implementation loop
- reopen `Requirements Review`

### Green But Misleading
Symptom:
- local checks pass but the operational outcome is still not proved

Response:
- treat this as a gatekeeper failure
- strengthen the evidence model before more coding

### Test Contract Erosion
Symptom:
- pass criteria, mocks, fixtures, or timing assumptions are quietly changed to preserve momentum

Response:
- treat this as a blocked gate
- require a revised `Verification Spec`

### Code Is Not The Problem
Symptom:
- evidence points to environment, data, sync, geometry, or hardware issues

Response:
- classify it explicitly
- stop blind implementation iterations

## Operator Defaults
- Default to the earliest unresolved phase.
- Default to one execution owner.
- Default to stronger evidence rather than faster iteration.
- Default to a fresh session when moving from `Test Design` to `Implementation Loop` or from `Implementation Loop` to `Final Validation`.
