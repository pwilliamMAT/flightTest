# FlightTest Reporting Workflow

1. **Evidence** — A traceable observation, measurement, source artifact, or bounded result. Evidence supports a claim but does not automatically establish field performance.
2. **Technical Reports** — The numbered evidence-family reports that explain a question, evidence, decision, claim boundary, and handoff.
3. **Engineering Explainers** — Focused reports that make a technical decision or method understandable, such as illuminator selection, receive-chain design, and synthetic echo generation.
4. **Report Family** — The ordered set `01 → 01A → 01B → 02 → 02A → 03 → 04 → 05 → 06`, with explicit ownership and handoffs recorded in canonical metadata.
5. **Canonical Release** — The validated external TechnicalSummaryFamily package that fixes one navigable report-family version. It remains outside this repository.
6. **End-to-End Story** — The accepted human-readable narrative that connects the report family for new engineers and management.
7. **Storyboard** — The accepted manager-slide sequence derived from the evidence family and end-to-end story before presentation production.
8. **Presentation** — A generated communication artifact. It is an external reference or archive item, not the routine source of truth for report refreshes.

The operating rule is evidence first, then technical reports and explainers, then the canonical family and human story, then storyboard and presentation. Each stage preserves the claim boundaries established by the preceding evidence.
