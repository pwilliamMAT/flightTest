# Codex Orchestration Operating Manual v1

## What This Manual Is For
Use this manual when you are operating Codex as a coordinated engineering team rather than as a single code generator. It is optimized for you as the human orchestrator and is meant to be used alongside `ImplementationPlan_v1.md`.

This manual is intentionally compact. Its job is to help you run a session cleanly, choose the right workflow size, and keep roles from bleeding together.

## How To Use This Manual With Agents
The right model is:
- the operating manual is primarily for you
- the agent can use it as an intake checklist to help classify the session
- the final choice of path should still be yours, especially for `Plan` vs `Execute` and whether to invoke the full ceremony

Why:
- this manual is an operator control document
- if you hand it to the agent as full authority, the agent may overcomplicate simple work or justify the wrong workflow too confidently
- if you use it yourself first, then ask the agent to audit your choice, you keep control where it belongs

Recommended pattern:
1. You make a quick initial call: `Plan`, `Execute`, or `Validate`.
2. If you are uncertain, ask the agent to read `OperatingManual_v1.md` and recommend the mode, workflow size, needed roles, and missing artifacts.
3. You approve or adjust that recommendation.
4. Then start the real session in the chosen mode.

Session-classification prompt:

```text
Read OperatingManual_v1.md and help me classify this session.
Given my current goal and context, tell me:
1. whether this should be Plan, Execute, or Validate
2. whether the workflow should be Full, Medium, or Lightweight
3. which roles are actually needed
4. which required artifacts are missing
Do not implement anything yet. Keep the recommendation concise and decision-oriented.
```

Use that prompt when:
- you are starting a new major session
- the failure mode is unclear
- you are unsure whether the issue is code vs integration vs hardware or data
- you are deciding whether to split into separate sessions

Do not bother with it when:
- you already have an approved `Decision Packet` and `Verification Spec`
- the task is a small local fix
- you are clearly in `Validate` already

## The 3 Operating Modes
### `Plan`
Use when:
- the root cause is unclear
- architecture or workflow changes are on the table
- the tests are not yet trustworthy
- hardware, synchronization, geometry, or data may be involved

Do in this mode:
- discovery
- expert-panel input
- synthesis
- teaching
- verification design
- red-team review

Do not use this mode for broad implementation.

### `Execute`
Use when:
- scope is approved
- the `Decision Packet` and `Verification Spec` already exist
- the goal is to implement within a known boundary

Do in this mode:
- make the approved changes
- keep one execution owner
- stop if scope pressure appears

### `Validate`
Use when:
- the implementation is ready to be checked
- you need to interpret pass or fail
- you need to decide between iteration, escalation, or waiver

Do in this mode:
- run the agreed checks
- classify failures
- decide whether the problem is code, integration, test, data, sync, geometry, or hardware

## Choosing The Workflow Size
### Full Workflow
Use for:
- ambiguous or high-risk problems
- cross-subsystem changes
- cases where the blocker may not be purely software
- early-stage architecture and rescue work

### Medium Workflow
Use for:
- narrower issues with unclear failure cause
- situations where tests need redesign
- work that may stay local but still carries real risk

### Lightweight Workflow
Use for:
- already-approved local changes
- well-understood bug fixes
- tasks with strong existing tests and low architecture risk

If you are uncertain which workflow to choose, do not choose `Lightweight`.

## How To Keep Structure Without Magic Words
You do not need magic phrases, but you do need consistent control language. Start prompts with explicit fields such as:

```text
Current phase:
Goal:
Approved inputs:
Output required:
Do not:
Stop when:
```

Those six fields matter more than persona prose.

## Artifact Templates
Use the companion templates in this folder when you want stable handoff artifacts:
- `TemplateDecisionPacket.md`
- `TemplateVerificationSpec.md`
- `TemplateExecutionPacket.md`
- `TemplateValidationReport.md`
- `TemplateWaiverRecord.md`

Keep the core headings stable unless there is a strong reason to change them. Add project-specific detail inside the sections rather than inventing a new structure every session.

## Session-Start Checklist
- State the current phase: `Plan`, `Execute`, or `Validate`.
- State the session goal in one sentence.
- Name the approved inputs, if any.
- Name the exact output required for this session.
- Name the stop condition.
- Decide whether this is `Full`, `Medium`, or `Lightweight`.
- Decide which roles are needed and which are not.
- Check whether you need a fresh git branch or checkpoint.

## Pre-Implementation Checklist
- A `Decision Packet` exists.
- A `Verification Spec` exists.
- The verifier has challenged the plan.
- The human understands why this path is being chosen.
- The human has explicitly signed off.
- The execution lead is named.
- Parallel workers, if any, have disjoint ownership.
- Git has a safe checkpoint before risky work starts.

## Pre-Merge Or Post-Validation Checklist
- The agreed checks actually ran.
- The result is measured against the declared pass or fail criteria.
- The `Validation Report` explains the result rather than just listing output.
- No silent scope widening occurred.
- Any failure is classified.
- Any waiver is explicit and recorded.
- If the evidence points to non-code failure, do not loop blindly into more coding.

## Persona Usage Rules
- Ask the expert panel for recommendations, not code.
- Ask the synthesis agent for one recommended path, not another brainstorm.
- Ask the teacher to explain why this plan and why these tests.
- Ask the verifier how the plan could still fail even if the tests pass.
- Ask the execution lead to implement only the approved scope.
- Do not let multiple specialists patch overlapping workflow logic.

## When To Use Separate Sessions
Use a new session:
- after human sign-off and before major implementation
- before substantial validation or review
- when switching from debate to building
- when the previous context is noisy, bloated, or contradictory

Stay in the same session only when:
- the task is lightweight
- scope is already approved
- context is still small and coherent

## When To Use Git
Use git:
- before any major execution phase
- before risky refactors
- before trying a competing algorithmic path
- after a validated increment

Avoid:
- parallel coding in a dirty tree without ownership
- treating arbitrary partial edits as meaningful checkpoints
- mixing planning artifacts and broad implementation changes in one ambiguous commit

## Prompt Skeletons
### Planning Session Prompt
```text
Current phase: Plan
Workflow size: Full
Goal: [state the decision to make]
Known context: [brief current state]
Roles to use: [Systems, RF, Radar, Tracking, or narrower set]
Output required: Decision Packet, Teaching Brief, Verification Spec
Do not: write code or widen scope beyond the goal
Stop when: the proposed path and tests are ready for human sign-off
```

### Expert-Panel Prompt
```text
Current phase: Plan
You are the [role name].
Goal: critique the problem from your domain perspective.
Approved inputs: [Session Brief and discovery evidence]
Output required: Expert Memo with diagnosis, assumptions, risks, evidence needed, and recommendation
Do not: write code or assume your role owns the whole system
Stop when: you have produced one concise memo
```

### Synthesis Prompt
```text
Current phase: Plan
You are the synthesis agent.
Approved inputs: [expert memos]
Goal: produce one coherent recommendation.
Output required: Decision Packet
Do not: create new requirements or hidden scope
Stop when: one path, its risks, and its required evidence are explicit
```

### Teacher Prompt
```text
Current phase: Plan
You are the teacher agent.
Approved inputs: [Decision Packet]
Goal: explain the mental model, tradeoffs, and why this path is chosen.
Output required: Teaching Brief for the human operator
Do not: invent new architecture or implementation scope
Stop when: the plan is understandable to the human
```

### Verifier Prompt
```text
Current phase: Plan
You are the verifier.
Approved inputs: [Decision Packet and draft Verification Spec]
Goal: challenge test adequacy and plan robustness.
Output required: Verification Spec and Red-Team Report
Do not: implement the feature or soften weak evidence
Stop when: you have identified blind spots, false positives, and hard pass or fail criteria
```

### Execution-Lead Prompt
```text
Current phase: Execute
You are the execution lead.
Approved inputs: [Decision Packet and Verification Spec]
Goal: implement the approved scope only.
Output required: Execution Packet plus completed code changes
Do not: widen scope, redesign tests casually, or absorb unrelated cleanup
Stop when: the approved change is implemented or blocked by a material issue
```

### Validation Prompt
```text
Current phase: Validate
Approved inputs: [Verification Spec and implementation state]
Goal: run the agreed checks and classify the outcome.
Output required: Validation Report
Do not: propose new features before interpreting the evidence
Stop when: the result is classified as pass, fail, waiver candidate, or hardware/data escalation
```

## Practical Patterns
### Full Workflow Pattern
Use this sequence:
1. Discovery and panel input
2. Synthesis
3. Teaching
4. Verification design
5. Red-team review
6. Human sign-off
7. New execution session
8. Validation

### Medium Workflow Pattern
Use this sequence:
1. Discovery
2. Synthesis
3. Verification design
4. Human sign-off
5. Execution
6. Validation

### Lightweight Pattern
Use this sequence:
1. Brief the task
2. Execute
3. Validate

## Common Failure Patterns
### Too Many Cooks
Symptom:
- multiple agents are editing or redesigning the workflow at once

Response:
- stop parallel implementation
- appoint one execution lead
- push all further advice back into planning artifacts

### Green Tests, Broken System
Symptom:
- tests pass, but the real objective is still failing

Response:
- treat this as a `test defect` or `integration defect`
- send the verifier back to redesign the evidence standard

### Endless Local Tweaks
Symptom:
- each change is justified locally, but the whole system does not improve

Response:
- stop lightweight execution
- return to `Plan`
- require synthesis and verification redesign

### Code Is Not The Problem
Symptom:
- synthetic checks, timing checks, or geometry checks fail before the end-to-end logic is trustworthy

Response:
- classify as `data`, `sync`, `geometry`, or `hardware`
- stop algorithm tuning until that class of defect is addressed

### Context Rot
Symptom:
- the session is full of stale debate, conflicting assumptions, or long irrelevant history

Response:
- start a fresh session
- restate the current phase and approved inputs

## Operator Defaults
- Default to `Plan` mode when the root cause is uncertain.
- Default to separate sessions for major `Plan`, `Execute`, and `Validate` boundaries.
- Default to one execution owner.
- Default to an independent verifier.
- Default to stronger tests rather than faster iteration when the system objective is still not trustworthy.
