# Demo Skill Insights

| Date | Skill | Worked Well | Unexpected | Do Differently |
|---|---|---|---|---|
| 2026-08-27 | demo-guidelines | The outcome-first dashboard structure kept the frozen Stage 4C evidence central. | MATLAB's dark theme affected exported axes and legends even with a white figure. | Set axes, title, and legend colors explicitly before visual review. |
| 2026-08-27 | demo-review-rubric | Exporting the RMSE figure exposed label overlap that execution-only tests would not catch. | Six compact panels needed shorter model labels and a larger canvas. | Include one early exported-figure review before final regression runs. |
| 2026-08-27 | demo-templates | The existing project plan and state conventions were sufficient for a resumable implementation. | Creating separate demo workflow plan/progress files would have duplicated authoritative project state. | Reuse established project governance artifacts when they already cover the deliverable. |
| 2026-08-28 | demo-guidelines | A standalone Live Script kept the Stage 4D controls, evidence, limitations, and next decision in one review path. | MATLAB's active dark theme reset the bar-chart axes after plotting. | Apply explicit axes and legend colors after plot creation, then inspect the exported figure. |
| 2026-08-28 | demo-review-rubric | Reviewing the exported two-panel figure caught an extra `xline` legend item and low-contrast axes before handoff. | Plot correctness did not guarantee theme-independent readability. | Include a saved-image inspection in the first smoke cycle for every new review figure. |
| 2026-08-28 | demo-templates | The existing `implementationPlan.md` and project documentation remained the authoritative implementation record. | The generic demo `PLAN.md`/`PROGRESS.md` package would have duplicated established state. | Apply the presentation templates selectively without creating parallel sources of truth. |
