# Verification-First Codex Orchestration Method v1

## Summary
This document defines a human-led, verification-first workflow for using Codex agents on complex engineering problems. It is designed around the passive bistatic radar analysis-suite effort, but the structure is intended to be reusable for other projects after it proves itself in this sandbox.

The method exists to prevent a common failure mode: specialists making locally strong edits without shared system truth, strong integration ownership, or tests that are capable of disproving a bad path.

## Core Principles
- The human orchestrator owns scope, priorities, approval, and waivers.
- Many agents may advise, but only one agent may integrate.
- Verification is independent from implementation and has hard blocking authority.
- Tests are designed before implementation, not after.
- A valid outcome is "this is not a code problem."
- Planning diversity is useful; overlapping implementation ownership is not.

## Roles And Authority
### Human Orchestrator
- Defines the session goal, scope boundary, and success metric.
- Approves advancement between gates.
- Is the only authority allowed to waive a failed verification gate.

### Expert Panel
- Default panel: `Systems`, `RF`, `Radar`, `Tracking`.
- Used during discovery and planning to broaden the solution space.
- Produces recommendations, risks, and evidence requests.
- Does not own integrated implementation.

### Synthesis Agent
- Produces one coherent recommendation from the expert panel.
- Names assumptions, alternatives rejected, dependencies, and required evidence.
- Does not widen scope or implement code.

### Teacher Agent
- Explains the proposed path, tradeoffs, and test logic to the human operator.
- Ensures the human understands why the plan is being chosen.
- Does not redefine scope or silently introduce new requirements.

### Verifier
- Owns test adequacy, red-team review, and interpretation of test strength.
- Must be independent from the execution lead.
- Can block progress if evidence is weak, circular, or misleading.

### Execution Lead
- Owns integrated implementation after approval.
- May delegate tightly bounded, non-overlapping subtasks.
- Cannot widen scope without a new `Decision Packet`.

### Specialist Workers
- Optional support for bounded implementation slices.
- Must have disjoint write ownership.
- Must report back into the execution lead rather than merging strategy independently.

## Anti-Chaos Rules
- Many agents may advise; one agent integrates.
- Specialists recommend; they do not co-own the full workflow.
- The synthesis agent decides nothing alone; it packages a recommendation for human review.
- The verifier can block progress but cannot silently redefine scope.
- Only the human may approve a waiver.
- If an agent needs to change the plan, stop and re-enter a planning flow.

## Operating Modes
### `Plan`
Use for discovery, architecture choices, competing hypotheses, verification design, and cases where the blocker may not be purely software.

Outputs:
- `Session Brief`
- `Decision Packet`
- `Teaching Brief`
- `Verification Spec`
- `Red-Team Report`

### `Execute`
Use only when scope has already been approved.

Outputs:
- `Execution Packet`
- code or configuration changes within approved scope

### `Validate`
Use to run the agreed checks, interpret outcomes, and classify failures.

Outputs:
- `Validation Report`
- optional escalation recommendation

## Phase Scaling Rules
### Full Workflow
Use when the problem is ambiguous, high-risk, cross-subsystem, or likely to involve hardware, synchronization, geometry, or architecture decisions.

Required gates:
1. Session Brief
2. Discovery
3. Expert Deliberation
4. Synthesis
5. Teaching
6. Verification Design
7. Red-Team
8. Human Sign-Off
9. Execution
10. Validation
11. Waiver or Escalation
12. Hardware or Data Escalation if indicated

### Medium Workflow
Use when the scope is narrower but the current failure is still unclear or the existing tests are suspect.

Required gates:
1. Session Brief
2. Discovery
3. Synthesis
4. Verification Design
5. Human Sign-Off
6. Execution
7. Validation

Optional gates:
- Expert Deliberation
- Teaching
- Red-Team, if the change is still high consequence

### Lightweight Workflow
Use for already-approved local work with strong existing test coverage and low architectural risk.

Required gates:
1. Session Brief
2. Execution
3. Validation

Do not use this workflow when the root cause is uncertain.

## Full Workflow Gates
### 1. Session Brief Gate
Define the objective, success metric, current blocker, scope limit, known risks, and the decision needed this session.

Advance when:
- the problem statement is concrete
- the stop condition is explicit

### 2. Discovery Gate
Inspect code, data products, interfaces, current test quality, known failures, and existing evidence in read-only mode.

Advance when:
- the current system shape is understood well enough to state the likely failure classes

### 3. Expert Deliberation Gate
Each panel member responds independently against the same evidence packet.

Advance when:
- each memo includes a recommendation, assumptions, risks, and required evidence

### 4. Synthesis Gate
Collapse the expert panel into one recommended path.

Advance when:
- one `Decision Packet` exists
- rejected alternatives are named
- dependencies and unknowns are explicit

### 5. Teaching Gate
Explain the plan and test logic to the human operator.

Advance when:
- the human can understand the mental model, why this path is chosen, and what would falsify it

### 6. Verification Design Gate
Define the tests before implementation begins.

Advance when:
- a `Verification Spec` exists with exact pass or fail criteria
- each test states what claim it proves and how it could still mislead

### 7. Red-Team Gate
The verifier attacks the plan and the tests.

Advance when:
- blind spots, false positives, missing controls, and integration gaps are either fixed or explicitly accepted

### 8. Human Sign-Off Gate
The human approves the `Decision Packet` and `Verification Spec` together.

Advance when:
- the human explicitly authorizes the approved scope

### 9. Execution Gate
The execution lead implements only the approved scope.

Advance when:
- the intended change is complete
- no unapproved scope widening occurred

### 10. Validation Gate
Run the agreed checks and compare them against the predeclared evidence standard.

Advance when:
- a `Validation Report` exists with pass or fail, interpretation, and next action

### 11. Waiver Or Escalation Gate
If verification fails, either stop or issue an explicit human waiver.

Advance when:
- the failure is resolved, or
- the human records a `Waiver Record`

### 12. Hardware Or Data Escalation Gate
Use when the evidence points to non-code failure.

Advance when:
- the problem is explicitly classified as `data`, `sync`, `geometry`, or `hardware`

## Required Artifacts
### `Session Brief`
- objective
- success metric
- scope boundary
- current blocker
- known evidence
- known risks
- stop condition

### `Expert Memo`
- diagnosis
- assumptions
- recommended action
- risks
- dependencies
- evidence needed
- confidence

### `Decision Packet`
- chosen path
- alternatives considered
- alternatives rejected
- assumptions
- dependencies
- interface contracts
- expected benefits
- known risks

### `Teaching Brief`
- mental model
- why this path
- what can fail
- what evidence would change the decision

### `Verification Spec`
- claim under test
- test inventory
- pass or fail criteria
- before or after metrics
- negative controls
- failure interpretation
- anti-false-confidence notes

### `Red-Team Report`
- weak assumptions
- missing cases
- misleading metrics
- integration risks
- conditions where green tests would still be untrustworthy

### `Execution Packet`
- approved scope
- task order
- ownership
- touched subsystems
- integration checkpoints
- rollback conditions

### `Validation Report`
- expected result
- observed result
- pass or fail
- interpretation
- defect classification
- next action

### `Waiver Record`
- failed gate
- accepted risk
- reason for waiver
- follow-up verification required

## Verification System
### Hard Rules
- No major implementation starts without a `Verification Spec`.
- No major change counts as successful without multi-layer evidence.
- The verifier must be independent from the execution lead.
- A test is not adequate just because it passes.
- A failed hard gate stops progress unless the human explicitly waives it.

### Evidence Standard
Every major change must produce:
- `Subsystem evidence`: the changed module behaves as intended under controlled conditions.
- `Physics or truth evidence`: behavior matches geometry, timing, signal model, or known truth data.
- `End-to-end evidence`: the full workflow improves the actual objective without regressing agreed controls.

### Verifier Responsibilities
The verifier must challenge:
- tests that only prove the code matches its own assumptions
- metrics that can improve while the real objective degrades
- overfitting to a small set of files, captures, or scenarios
- missing negative controls
- weak regression controls
- integration gaps that local tests ignore
- hardware or data defects disguised as software problems

## Radar-Specific Verification Stack
### Synthetic Pipeline Tests
- inject targets at known range, Doppler, and SNR
- verify CAF peak recovery
- verify detector response near the injected bin

### Geometry And Timing Tests
- validate transmitter and receiver geometry
- validate ADS-B interpolation at CPI midpoint
- validate unit conversions and bin mapping
- validate expected range and Doppler resolution

### Signal-Path Tests
- reference channel quality
- synchronization assumptions
- clutter or DPI mitigation effect
- CAF output stability
- thresholding behavior

### Truth-Gated Detection Tests
- compare detections to ADS-B projected expectations
- use declared spatial and Doppler tolerances
- classify misses rather than hiding them inside aggregate metrics

### Regression Controls
- fixed baseline data
- known negative cases
- do-not-worsen controls for clutter and false alarms

### Hardware Or Data Stop Conditions
Stop optimization and classify as non-code failure when:
- synthetic injection cannot be recovered at controlled SNR
- timing or synchronization checks fail
- geometry or bin mapping is inconsistent with physics
- metrics move but truth consistency stays broken
- equivalent captures behave inconsistently without software explanation

## Failure Taxonomy
- `code defect`: local logic or implementation bug
- `integration defect`: module boundaries or sequencing break the workflow
- `test defect`: the tests are weak, circular, or misleading
- `data defect`: recordings, labels, or metadata are wrong or incomplete
- `sync defect`: timing alignment or common-clock assumptions are broken
- `geometry defect`: coordinate transforms, baselines, or bin mapping are wrong
- `hardware defect`: receiver chain, clocks, antennas, or RF setup are limiting the result

## Session Management Rules
- Use a fresh session when switching from planning to execution on major work.
- Use a fresh session when switching from implementation to substantial validation or review.
- Keep the planning session separate from the implementation session when the upstream debate is large.
- Reuse a session only for lightweight work with approved scope and clear context.
- Always restate the current phase, approved inputs, required output, and stop condition.

## Git Policy
- Create a branch before any major investigation or algorithmic path.
- Commit a known-good baseline before risky execution work begins.
- Commit after validated increments, not after arbitrary partial edits.
- Keep branch names aligned with the work, for example `investigation/sync-sanity` or `feature/caf-rework`.
- Do not let multiple execution agents work in a dirty tree without explicit ownership.
- If the approved path changes materially, capture that change in a new commit boundary and a new `Decision Packet`.

## Default Prompt Control Fields
Prompts should explicitly declare:
- `Current phase`
- `Goal`
- `Approved inputs`
- `Output required`
- `Do not`
- `Stop when`

There are no magic trigger words, but consistent control fields are required if the workflow is expected to remain structured.

## Assumptions And Defaults
- This sandbox is Codex-first.
- The default planning panel is `Systems`, `RF`, `Radar`, and `Tracking`.
- The default operator is the human user, not an autonomous PM agent.
- The full workflow is reserved for ambiguous, high-risk, or cross-subsystem work.
- The lightweight workflow is reserved for already-approved local work.
- A companion file, `OperatingManual_v1.md`, provides day-to-day usage guidance and prompt skeletons.
- A formal skill should not be created until this method has been exercised and stabilized.
