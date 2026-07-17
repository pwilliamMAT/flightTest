# System Precheck Write-Up

This package is a `system precheck`, not end-to-end passive-radar validation.
Its job is to answer three narrow questions before deeper field work:

1. Is there a credible illuminator at the intended receiver location?
2. Can a plausible RF front end capture the signal environment without immediately collapsing on direct-path power?
3. Is bistatic detectability still plausible under the current inherited target-path assumptions?

## Current Operational Context

- Newton is the primary source path.
- Hudson is the alternate comparison path.
- The cleaned assumptions table identifies the Newton RF35 source as `WHDH-TV / WLVI-TV`, not `CBS`.
- The Hudson RF27 alternate source remains `WUNI`.
- Both sources are treated as `Licensed` as of `2026-07-17`.
- The common analysis receiver remains the `MathWorks Apple Hill Garage`.

Primary assumption references:

- `../Artifacts/Tables/SystemPrecheckAssumptions.csv`
- `../Artifacts/Tables/SystemPrecheckAssumptionsSummary.csv`

## Evidence Classes

| Category | Examples | Role in this write-up |
| :--- | :--- | :--- |
| `Sourced` | call sign, RF channel, RF range, ERP, station status | Used directly in the argument |
| `Assumed` | receiver antenna gain, TwinRX gain setting, current Newton target-path power | Used only with explicit caution |
| `Inferred` | center frequency from RF allocation midpoint, mixed H/V polarization from separate ERP values | Used where the repo needs a stable modeling value |
| `Supporting` | retained `.mlx` link-budget studies | Useful background, not final evidence |

## Illuminator Viability

The sourced geometry and ERP summary supports the first claim.
The cleaned direct-path precheck estimates:

- Newton RF35: `9.38 km` to the receiver and about `-3.29 dBm` after a `12 dBi` receive antenna assumption.
- Hudson RF27: `15.13 km` to the receiver and about `-10.70 dBm` after the same receive antenna assumption.

Those are strong direct-path levels for a pre-hardware sanity check.
Even before any deeper passive-radar processing discussion, both emitters are viable illuminators at the chosen receiver location.

Supporting outputs:

- `../Artifacts/Tables/SourceViabilitySummary.csv`
- `../Artifacts/Figures/SystemPrecheck_SourceViability.png`

## Final Link Budget Evidence

The link-budget folder still contains useful technical work, but the final argument should not rely on the historical live scripts as if they were frozen evidence.

The retained `.mlx` files stay in the repo as `supporting` because:

- they still depend on interactive geometry selection,
- they still carry placeholder-heavy HDTV assumptions,
- they are not yet locked to the cleaned assumptions table, and
- they mix analysis iterations that are useful to understand maturity, but not ideal for a final review room argument.

That is why the cleaned working set uses:

- the sourced assumptions table,
- the generated source-viability summary,
- the link-budget decision matrix, and
- the retained supporting live scripts only as background.

Supporting outputs:

- `../Artifacts/Tables/LinkBudgetDecisionMatrix.csv`
- `../Artifacts/Figures/SystemPrecheck_DecisionMatrixSummary.png`

## RF Front-End Capture-Chain Evidence

The cleaned RF story is stronger than the historical naming suggested.
The active RF path now uses:

- corrected Newton and Hudson frequencies,
- corrected Newton source identity,
- measured `ZABP-587-S+` insertion loss interpolated from the included `25 C` S-parameter file, and
- a common direct-sampling TwinRX chain instead of relying on the legacy IF scripts as final evidence.

Current modeled RF summary:

- Newton: filter loss `0.73 dB`, total gain `47.92 dB`, system NF `3.57 dB`.
- Hudson: filter loss `0.79 dB`, total gain `47.85 dB`, system NF `3.44 dB`.

The useful conclusion is not that the current gain setting is perfect.
The useful conclusion is that the chain is plausible, low-noise, and easy to retune, while the direct path is so strong that an attenuated reference path is mandatory.

Supporting outputs:

- `../Artifacts/Tables/RFBudgetSummary.csv`
- `../Artifacts/Figures/SystemPrecheck_RFCaptureChain.png`

## Bistatic Detectability Plausibility

Under the inherited target-path assumption of `-67.37 dBm`, the modeled RF chain does not struggle with SNR.
The generated detectability table shows that the current limitation is not modeled SNR margin.
The current limitation is the provenance of the Newton target-path power itself.

That distinction matters:

- Hudson detectability plausibility is still only as strong as the supporting live-script assumptions that produced the inherited target-path power.
- Newton detectability plausibility is weaker, because it still reuses the Hudson-derived placeholder until the Newton-specific path is rerun.

So the defended claim here is only:

`Given the inherited target-path assumption, detectability remains plausible.`

It is not:

`The Newton path has already been fully validated.`

Supporting outputs:

- `../Artifacts/Tables/DetectabilitySummary.csv`
- `../Artifacts/Figures/SystemPrecheck_DetectabilityPlausibility.png`

## RF Risk Table

The dominant review-room risks are now explicit instead of being buried in narrative comments:

- direct-path overload and required attenuation,
- target-path provenance,
- adjacent-channel uncertainty,
- unmeasured assembled-chain headroom,
- and the boundary between precheck plausibility and field validation.

Primary risk reference:

- `../Artifacts/Tables/RFRiskTable.csv`
- `../Artifacts/Figures/SystemPrecheck_RFRiskSummary.png`

## Model Boundaries and Excluded Effects

This cleaned package intentionally excludes:

- DSI cancellation performance,
- clutter rejection,
- synchronization and calibration behavior,
- measured field interference,
- and measured detection performance.

Those are important, but they belong to later validation work rather than this precheck cleanup session.

Boundary slide asset:

- `../Artifacts/Figures/SystemPrecheck_Boundaries.png`

## Confidence Statement

The confidence split is now clear:

- `High` confidence that both Newton and Hudson are viable illuminators at the chosen receiver location.
- `Moderate` confidence that the cleaned RF front-end chain is a plausible capture path, provided the reference path is attenuated and the gain plan is bench-checked.
- `Low-to-moderate` confidence in Newton-specific bistatic detectability because the Newton target-path number is still inherited rather than independently rerun.

That is a more defensible story than the pre-cleanup repo state because it separates what is sourced, what is assumed, and what is still open.

## What This Analysis Does Not Claim

- It does not claim deployed passive-radar performance.
- It does not claim Newton-specific target-path validation.
- It does not claim adjacent-channel robustness without a field survey.
- It does not claim measured synchronization, calibration, DSI cancellation, or clutter rejection performance.
- It does not claim that the current TwinRX gain setting is final.

## Final Output Set

- `../Artifacts/Tables/*.csv`
- `../Artifacts/Figures/SystemPrecheck_*.png`
- `../Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx`
