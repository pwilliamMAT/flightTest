# testCodexOrchestration

## Project End State
Deliver a reusable CODRTIV v2 orchestration framework that keeps work phase-correct and now requires a context-only `System Composer` `System Context Diagram` during `CONOPS`.

## Current Approved CONOPS Status
- Status: `Draft`
- Current rule baseline: `CONOPS` is not complete until the `CONOPS Brief`, the `System Context Diagram`, and the `README.md` screenshot or export are all present.
- Approval note: This repository now enforces the diagram requirement in the v2 operating manual, implementation plan, personas, and `TemplateCONOPSBrief.md`.
- System context model: `CODRTIV_v2_SystemContext.slx`
- Current export: `docs/CONOPS-SystemContextDiagram.png`

## Operational Objective And Scope Boundary
The operational objective is to help a human orchestrator keep Codex sessions inside the intended CODRTIV phase while preserving the required artifacts and gates.

The system-of-interest boundary is the v2 orchestration framework itself: it accepts a project end state, current phase, and approved inputs, and it produces phase-correct artifacts, blocked notes, and gate guidance. Out of scope are product implementation decisions, design decomposition during `CONOPS`, and phase skipping without explicit human approval.

## CONOPS Diagram Screenshot
Caption: The diagram treats `CODRTIVv2Framework` as the system-of-interest and keeps the view at the context level. It shows the human orchestrator and project workspace as primary input sources, the working Codex session and MathWorks tooling as adjacent external systems, and the project artifact set as the main output boundary.

![CODRTIV v2 CONOPS System Context Diagram](docs/CONOPS-SystemContextDiagram.png)
