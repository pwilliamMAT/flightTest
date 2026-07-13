# Session Recovery - 2026-06-22

## Recovered From
- Codex session log: `C:\Users\pwilliam\.codex\sessions\2026\06\22\rollout-2026-06-22T08-46-08-019eef5d-e33c-79c2-890f-0b86daab3cfc.jsonl`
- Current sandbox files in `testCodexOrchestration`

## Session Goal
Build a reusable Codex orchestration method for complex engineering work, using the passive bistatic radar effort as the motivating case.

Primary concern:
- specialists were making locally strong edits without enough integration ownership
- weak testing allowed bad paths to look successful
- the workflow needed to distinguish code problems from sync, geometry, data, or hardware problems

## What Was Produced
- [ImplementationPlan_v1.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\ImplementationPlan_v1.md)
- [OperatingManual_v1.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\OperatingManual_v1.md)
- [SystemsEngineer.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\SystemsEngineer.md)
- [BistaticRadarExpert.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\BistaticRadarExpert.md)
- [Verifier.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\Verifier.md)
- [ExecutionLead.md](C:\Users\pwilliam\agenticProjects\learningSandbox\testCodexOrchestration\ExecutionLead.md)

## Key Decisions Recovered
### Workflow model
- Use three operating modes: `Plan`, `Execute`, `Validate`
- Use three workflow sizes: `Full`, `Medium`, `Lightweight`
- Treat verification as a hard gate, independent from implementation
- Accept that a valid outcome can be "this is not a code problem"

### Control model
- The human operator owns scope, sign-off, and waivers
- The operating manual is primarily for the human, not the agent
- The agent may help classify the session, but should not be the sole authority for choosing the workflow
- Many agents may advise, but only one agent should integrate implementation

### Persona hardening
- `SystemsEngineer.md` was rewritten to be a bounded architecture and integration specialist
- `BistaticRadarExpert.md` was rewritten to stop autonomous looping and obey phase control
- `Verifier.md` was added as an explicit independent hard-gate verifier
- `ExecutionLead.md` was added as an explicit integrated implementation owner
- `Teacher` and `Synthesis` were intentionally left as inline prompt patterns for now

## Most Important Guidance Added To The Manual
The recommended usage pattern recovered from the session:
1. The human makes an initial call: `Plan`, `Execute`, or `Validate`
2. If uncertain, ask the agent to read `OperatingManual_v1.md` and classify the session
3. The human approves or adjusts that recommendation
4. Only then start the real working session

## Last Recorded Recommendation
The last substantive recommendation from the session was:
- use this orchestration method on the real passive bistatic radar codebase
- but start with a `Plan`-only pilot
- do not start with autonomous implementation

Recommended first pilot shape:
- create a fresh git branch in the radar repo
- start a new Codex session in `Plan` mode
- classify the session with `OperatingManual_v1.md`
- focus on one narrow stalled problem
- request only planning artifacts, not code changes

Suggested first pilot question:
- is the current blocker primarily `algorithmic`, `integration`, `test`, `sync`, `geometry`, `data`, or `hardware`?

## Suggested First Pilot Prompt
```text
Read OperatingManual_v1.md and help me classify this session.
Current problem: the passive bistatic radar detector is not reliably recovering aircraft near ADS-B-projected range-Doppler locations.
I want a Plan-mode session only.
Use SystemsEngineer.md, BistaticRadarExpert.md, and Verifier.md as role guidance.
Output required: Session Brief, expert recommendations, Decision Packet, and Verification Spec.
Do not implement code yet.
Stop when the recommended path and tests are ready for human review.
```

## Known Follow-Up Work
Completed after recovery:
- added `TemplateDecisionPacket.md`
- added `TemplateVerificationSpec.md`
- added `TemplateExecutionPacket.md`
- added `TemplateValidationReport.md`
- added `TemplateWaiverRecord.md`

Still remaining:
- run the first real `Plan`-mode pilot in the actual radar codebase

## Notes
- No `README.md` existed in `testCodexOrchestration` during the recovered session
- The sandbox is documentation-oriented; no git repository was present in this folder
