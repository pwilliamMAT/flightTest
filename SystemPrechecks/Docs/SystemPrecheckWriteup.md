# System Precheck Write-Up

This package is a `system precheck`, not end-to-end passive-radar validation.
Its job is still to answer three narrow questions before deeper field work:

1. Is there a credible illuminator at the intended receiver location?
2. Can a plausible RF front end capture the signal environment without immediately collapsing on direct-path power?
3. Does deterministic bistatic detectability remain plausible under the current geometry assumptions?

## Current Operational Context

- Newton remains the primary source path.
- Hudson remains the alternate comparison path.
- The cleaned assumptions table identifies the Newton RF35 source as `WHDH-TV / WLVI-TV`, not `CBS`.
- The Hudson RF27 alternate source remains `WUNI`.
- Both sources are treated as `Licensed` as of `2026-07-17`.
- The common analysis receiver remains the `MathWorks Apple Hill Garage`.
- The deterministic coverage story now has two explicit branches:
  - the existing `recovered-ROI baseline`
  - the additive `due-west surveillance corridor` check

Primary assumption references:

- `../Artifacts/Tables/SystemPrecheckAssumptions.csv`
- `../Artifacts/Tables/SystemPrecheckAssumptionsSummary.csv`
- `../Artifacts/Summaries/SystemPrecheckAssumptionsSummary.txt`
- `../Artifacts/Figures/SystemPrecheck_GeometryOverview.png`

## Evidence Classes

| Category | Examples | Role in this write-up |
| :--- | :--- | :--- |
| `Sourced` | call sign, RF channel, RF range, ERP, station status | Used directly in the argument |
| `Assumed` | receiver antenna gain, TwinRX gain setting, assembled-chain headroom, due-west corridor geometry | Used only with explicit caution |
| `Inferred` | center frequency from RF allocation midpoint, mixed H/V polarization, recovered ROI coordinates from the saved live-script figure | Used where the repo needs a stable modeling value |
| `Generated visual` | shared geometry, recovered-ROI baseline coverage, west-corridor coverage, RF-chain, and detectability figures | Primary visual evidence in the deck |
| `Manual visual` | native RF Budget Analyzer screenshot | Optional native component-view evidence for review-room use |
| `Supporting` | retained `.mlx` link-budget studies | Useful background, not final evidence |

## Direct-Path Source Viability

The sourced geometry and ERP summary still support the first claim.
The cleaned direct-path precheck estimates:

- Newton RF35: `9.38 km` to the receiver and about `-3.29 dBm` after a `12 dBi` receive antenna assumption.
- Hudson RF27: `15.13 km` to the receiver and about `-10.70 dBm` after the same receive antenna assumption.

Those remain strong direct-path levels for a pre-hardware sanity check.
Even before any deeper passive-radar processing discussion, both emitters are viable illuminators at the chosen receiver location.

Supporting outputs:

- `../Artifacts/Tables/SourceViabilitySummary.csv`
- `../Artifacts/Figures/SystemPrecheck_SourceViability.png`
- `../Artifacts/Figures/SystemPrecheck_GeometryOverview.png`

## Shared Geometry Context

The shared geometry figure now shows three distinct items that should not be conflated:

- the receiver and the Newton/Hudson transmitter locations
- the historical `recovered-ROI baseline`
- the additive `due-west surveillance corridor` plus a visible due-west boresight marker

That due-west marker is `visual only`.
It does not apply a directional receive-antenna pattern or alter the RF math.
Its job is to make the west-looking surveillance check obvious in the figures and deck.

Supporting outputs:

- `../Artifacts/Figures/SystemPrecheck_GeometryOverview.png`
- `../Artifacts/Tables/SystemPrecheckAssumptions.csv`

## Recovered-ROI Baseline Coverage Story

The original deterministic rerun remains intact and still serves as the baseline reference.
This branch:

- keeps the recovered rectangular ROI from the saved live-script figure,
- rebuilds the target grid deterministically,
- reruns the path with `longley-rice`, and
- exports readable Newton, Hudson, combined, regional, and detectability artifacts.

Current mean target-path estimates from the recovered-ROI baseline are:

- Newton RF35: `-67.56 dBm`
- Hudson RF27: `-70.62 dBm`

That baseline remains the defended reference branch because it is the same deterministic geometry used before this west-corridor extension, now with explicit tables and map-level outputs.

Supporting outputs:

- `../Artifacts/Tables/BistaticTargetPathSummary.csv`
- `../Artifacts/Tables/DetectabilitySummary.csv`
- `../Artifacts/Figures/SystemPrecheck_RoiTargetGridContext.png`
- `../Artifacts/Figures/SystemPrecheck_NewtonDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_HudsonDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_CombinedDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_RegionalSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_DetectabilityPlausibility.png`

## Due-West Surveillance Corridor Check

The additive west-looking check uses the same deterministic RF and propagation workflow, but swaps in a second ROI:

- latitude limits `42.182143` to `42.416443 deg`
- longitude limits `-71.849500` to `-71.349500 deg`
- vertical center fixed at the receiver latitude `42.299293 deg`
- east edge fixed at the receiver longitude `-71.349500 deg`
- west edge extended `0.50 deg` west

This branch is not a replacement for the recovered baseline.
It is a separate surveillance-oriented geometry check intended to answer the practical question: what does the same deterministic workflow predict if the antenna look direction is framed as a due-west corridor from the receiver?

Current mean target-path estimates from the due-west corridor branch are:

- Newton RF35: `-72.99 dBm`
- Hudson RF27: `-70.74 dBm`

Compared with the recovered-ROI baseline, the west-corridor branch weakens Newton by about `5.43 dB` and Hudson by about `0.12 dB`.
That difference is exactly why the second branch is useful: it tests a materially different surveillance geometry without pretending it is the same evidence package as the recovered baseline.

Supporting outputs:

- `../Artifacts/Tables/BistaticTargetPathSummary_WestCorridor.csv`
- `../Artifacts/Tables/DetectabilitySummary_WestCorridor.csv`
- `../Artifacts/Figures/SystemPrecheck_WestCorridorSetup.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_NewtonSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_HudsonSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_CombinedSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_RegionalSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_Detectability.png`

## RF Front-End Capture Story

The RF capture story remains shared.
The active RF path still uses:

- corrected Newton and Hudson frequencies,
- corrected Newton source identity,
- measured `ZABP-587-S+` insertion loss interpolated from the included `25 C` S-parameter file, and
- a common direct-sampling TwinRX chain instead of relying on the legacy IF scripts as final evidence.

Current modeled RF summary:

- Newton: filter loss `0.73 dB`, total gain `47.92 dB`, system NF `3.57 dB`.
- Hudson: filter loss `0.79 dB`, total gain `47.85 dB`, system NF `3.44 dB`.

The useful conclusion is still not that the current gain setting is final.
The useful conclusion is that the chain is plausible, low-noise, and easy to retune, while the direct path is so strong that an attenuated reference path is mandatory.

Supporting outputs:

- `../Artifacts/Tables/RFBudgetSummary.csv`
- `../Artifacts/Figures/SystemPrecheck_RFChainOverview.png`
- `../Artifacts/Figures/SystemPrecheck_RFLevelsAndHeadroom.png`
- `../Artifacts/Figures/SystemPrecheck_RFBudgetAnalyzer_Newton.png` (optional manual screenshot)

## Bistatic Detectability Plausibility

The detectability claim is now explicitly paired with the geometry branch that produced it.

That matters because:

- the recovered-ROI baseline detectability summary is derived from `BistaticTargetPathSummary.csv`
- the due-west corridor detectability summary is derived from `BistaticTargetPathSummary_WestCorridor.csv`
- the west-corridor detectability numbers are not copied from the baseline branch

Under both deterministic branches, the modeled RF chain still lands far above the illustrative `13 dB` threshold in the generated detectability plots.
So the defended claim remains:

`Given the stated deterministic geometry branch, detectability remains plausible.`

It is still not:

`The target path has already been field-validated.`

Supporting outputs:

- `../Artifacts/Tables/DetectabilitySummary.csv`
- `../Artifacts/Tables/DetectabilitySummary_WestCorridor.csv`
- `../Artifacts/Figures/SystemPrecheck_DetectabilityPlausibility.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_Detectability.png`

## Final Link-Budget Evidence and Background Artifacts

The link-budget folder still contains useful technical work, but the final argument should not rely on the historical live scripts as if they were frozen evidence.

The retained `.mlx` files stay in the repo as `supporting` because:

- they still depend on interactive geometry selection,
- they still carry placeholder-heavy HDTV assumptions,
- they are not locked to the cleaned assumptions table, and
- they mix analysis iterations that are useful for traceability, but not ideal for a final review-room argument.

That is why the cleaned working set now uses:

- the sourced assumptions table,
- the generated source-viability summary,
- the shared geometry and RF figures,
- the recovered-ROI baseline coverage figures,
- the due-west corridor coverage figures,
- the paired detectability outputs, and
- the retained supporting live scripts only as background.

Supporting outputs:

- `../Artifacts/Tables/LinkBudgetDecisionMatrix.csv`
- `../Artifacts/Summaries/SystemPrecheckDecisionSummary.txt`

## RF Risk Table

The dominant review-room risks remain explicit instead of buried in narrative comments:

- direct-path overload and required attenuation,
- target-path provenance,
- adjacent-channel uncertainty,
- unmeasured assembled-chain headroom,
- and the boundary between precheck plausibility and field validation.

Primary risk reference:

- `../Artifacts/Tables/RFRiskTable.csv`
- `../Artifacts/Summaries/SystemPrecheckRFRiskSummary.txt`

## Model Boundaries and Excluded Effects

This cleaned package intentionally excludes:

- DSI cancellation performance,
- clutter rejection,
- synchronization and calibration behavior,
- measured field interference,
- and measured detection performance.

Those are important, but they still belong to later validation work rather than this precheck session.

Boundary references:

- `../Artifacts/Summaries/SystemPrecheckBoundaries.txt`
- slide `Risks and Scope Boundaries` in the generated deck

## Confidence Statement

The confidence split is now:

- `High` confidence that both Newton and Hudson are viable illuminators at the chosen receiver location.
- `Moderate` confidence that the cleaned RF front-end chain is a plausible capture path, provided the reference path is attenuated and the gain plan is bench-checked.
- `Moderate` confidence in the recovered-ROI baseline detectability story because it is deterministic and reproducible, but still model-based.
- `Moderate` confidence in the due-west corridor check because it uses the same deterministic workflow, but intentionally changes the surveillance geometry and remains model-based.

That is a more defensible story than the pre-cleanup repo state because it separates what is sourced, what is assumed, what is deterministic model output, and what is still open.

## What This Analysis Does Not Claim

- It does not claim deployed passive-radar performance.
- It does not claim measured target-path validation.
- It does not claim adjacent-channel robustness without a field survey.
- It does not claim measured synchronization, calibration, DSI cancellation, or clutter rejection performance.
- It does not claim that the current TwinRX gain setting is final.

## Final Output Set

- `../Artifacts/Tables/*.csv`
- `../Artifacts/Summaries/*.txt`
- `../Artifacts/Figures/SystemPrecheck_GeometryOverview.png`
- `../Artifacts/Figures/SystemPrecheck_SourceViability.png`
- `../Artifacts/Figures/SystemPrecheck_RFChainOverview.png`
- `../Artifacts/Figures/SystemPrecheck_RFLevelsAndHeadroom.png`
- `../Artifacts/Figures/SystemPrecheck_RoiTargetGridContext.png`
- `../Artifacts/Figures/SystemPrecheck_NewtonDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_HudsonDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_CombinedDeterministicSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_RegionalSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_DetectabilityPlausibility.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridorSetup.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_NewtonSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_HudsonSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_CombinedSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_RegionalSNRCoverage.png`
- `../Artifacts/Figures/SystemPrecheck_WestCorridor_Detectability.png`
- `../Artifacts/Figures/SystemPrecheck_RFBudgetAnalyzer_Newton.png` (optional manual capture)
- `../Artifacts/Decks/SystemPrecheck_TechnicalStory.pptx`
- `SystemPrecheckOverview.m` in `Docs`
