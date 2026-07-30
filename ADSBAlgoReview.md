# ADS-B Algorithm Review: ADS-B To Range-Doppler Projection

## Scope

This document reviews the current defense of the ADS-B-to-range-Doppler conversion used in the passive bistatic radar workflow. The review is intentionally bounded to the current branch implementation and the synthetic data generation pipeline.

The question being answered is not whether the project has achieved field-validated truth registration on hardware. The question being answered here is narrower: is the current ADS-B projection math correct by convention, reusable across the workflow, and robust enough to trust as the Stage 2 synthetic truth-placement layer?

## Executive Conclusion

For the synthetic data generation and validation pipeline, the ADS-B-to-range-Doppler math is now well-defended.

- It is **correct** in the sense that the helper reuses the authoritative bistatic geometry, Doppler-sign, and radar-time alignment functions already used by the repo, and those conventions are checked directly against the RD-map axis behavior.
- It is **reusable** because the shared helper is a composition layer rather than a second implementation of the same math, and it exposes one flat projection-table contract that multiple consumers can share.
- It is **robust** because the implementation fails safe on sparse, invalid, duplicate-timestamp, and outside-window truth cases instead of fabricating plausible-looking output.

The remaining open question is on the hardware side: capture-backed timing and measurement registration still need explicit evaluation before this should be described as physically confirmed on real data.

## Review Basis

This review is grounded in the current branch state of:

- [BistaticDataAnalysis/adsbToBistatic.m](BistaticDataAnalysis/adsbToBistatic.m)
- [BistaticDataAnalysis/alignTruthToRadar.m](BistaticDataAnalysis/alignTruthToRadar.m)
- [BistaticDataAnalysis/helperProjectADSBTruthToRangeDoppler.m](BistaticDataAnalysis/helperProjectADSBTruthToRangeDoppler.m)
- [BistaticDataAnalysis/bistaticTruthConventionTest.m](BistaticDataAnalysis/bistaticTruthConventionTest.m)
- [SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m](SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m)
- [SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m](SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m)

Current verification evidence used for this review:

- `bistaticTruthConventionTest` passed `11/11` on this branch.
- Targeted raw-spot-check coverage in `SyntheticHDTVSessionGeneratorTest` passed `3/3` on this branch:
  - `testValidationHelperReturnsRawSpotCheckOutputs`
  - `testValidationHelperSelectsFirstFiveEligibleSpotCheckTargets`
  - `testValidationHelperRawSpotCheckFindsFinitePeaksInConfidenceFixture`

## How The Math Was Tested

The math was tested at three levels: convention tests, helper edge-case tests, and end-to-end synthetic validation tests.

### 1. Convention Tests

The convention tests in [BistaticDataAnalysis/bistaticTruthConventionTest.m](BistaticDataAnalysis/bistaticTruthConventionTest.m) establish that the truth projection uses the same measurement conventions as the passive range-Doppler map itself.

- `testSharedConstantsMatchCAFAxes` verifies that the shared bistatic conversion constants match the range-cell and Doppler-bin spacing used by `createRDM`.
- `testCreateRDMMatchesPassiveCAFDopplerConvention` verifies that the passive CAF Doppler sign used by the RD map agrees with the sign convention used by the truth-conversion helpers.
- `testTruthProjectionUsesThreeDimensionalBaseline` verifies that excess range is referenced to the full 3-D Tx-Rx baseline, not only the horizontal ground separation.

These tests are the core correctness anchor because they tie the truth math to the map that the operator actually inspects.

### 2. Projection-Helper Edge Cases

The helper-specific tests in [BistaticDataAnalysis/bistaticTruthConventionTest.m](BistaticDataAnalysis/bistaticTruthConventionTest.m) then validate the composition helper directly.

- `testProjectionHelperUsesBaselineConsistentRangeExcess` checks that the projected bistatic output, the aligned output, and the flat table all agree on the same baseline-consistent excess range.
- `testProjectionHelperKeepsApproachingAndRecedingDopplerSigns` checks that the sign flips correctly when the target motion reverses.
- `testProjectionHelperMarksOutsideWindowQueriesInvalid` checks that queries outside the radar window remain invalid and NaN after alignment.
- `testProjectionHelperLeavesSingleFixTrackNonInterpolable` checks that a single-fix track does not produce fabricated aligned truth.
- `testProjectionHelperHandlesDuplicateTimestampsWithoutFailure` checks that duplicate or near-duplicate timestamps do not break the projection path.

These are the main robustness tests because they target the failure classes most likely to create false confidence in truth overlays.

### 3. End-To-End Synthetic Validation

The synthetic validation path in [SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m](SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m) uses the shared helper output directly to drive the Stage 2 raw pre-ECA-C spot check.

The tests in [SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m](SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m) then verify that:

- `spot_check_table` is present and has the expected fields,
- the first-five target selection policy is deterministic,
- the deterministic confidence fixture produces finite truth coordinates and finite observed local peaks,
- the residual and gate-pass fields are populated in a machine-readable way.

This matters because it shows the conversion math is not only unit-tested in isolation. It is also exercised by the actual synthetic validation workflow that consumes the projected truth.

## Why The Math Is Correct

The core geometry lives in [BistaticDataAnalysis/adsbToBistatic.m](BistaticDataAnalysis/adsbToBistatic.m). The excess range is computed as:

```text
R_excess = R_tx + R_rx - L
```

where `L` is the Tx-Rx baseline. The bistatic Doppler is derived from the time rate of change of excess range:

```text
f_D = -(fc/c) * dR_excess/dt
```

The sign convention is explicit: **positive Doppler means approaching**, which corresponds to decreasing excess range.

That sign is not defended only by comments. It is checked against the actual passive CAF / RD-map behavior in `testCreateRDMMatchesPassiveCAFDopplerConvention`. That is the key reason the defense is strong: the truth overlay and the range-Doppler map are tied to the same sign convention by test.

The time alignment lives separately in [BistaticDataAnalysis/alignTruthToRadar.m](BistaticDataAnalysis/alignTruthToRadar.m). It converts ADS-B UTC timestamps into radar-relative time using `radar_epoch_utc`, then resamples the projected truth onto the requested CPI or query-time grid. That is the correct separation of concerns:

- `adsbToBistatic` owns geometry and range-rate-to-Doppler conversion,
- `alignTruthToRadar` owns radar-time alignment and interpolation.

The shared helper [BistaticDataAnalysis/helperProjectADSBTruthToRangeDoppler.m](BistaticDataAnalysis/helperProjectADSBTruthToRangeDoppler.m) does not duplicate either responsibility. It composes those two layers and emits the result in a reusable form.

## Why The Helper Is Reusable

The reusability argument is strong because `helperProjectADSBTruthToRangeDoppler` is intentionally narrow.

- It calls `adsbToBistatic` for geometry and Doppler.
- It calls `alignTruthToRadar` for radar-relative resampling.
- It returns both structured outputs and a flat `projection_table` with one row per target per query time.

The flat table carries:

- `hex`
- `callsign`
- `query_time_s`
- `R_excess_m`
- `f_D_hz`
- `valid`

That output contract is already useful in multiple places:

- truth normalization and downstream ADS-B-based workflow steps,
- synthetic validation summaries,
- the midpoint-CPI raw-RDM spot check,
- targeted unit and integration tests.

This is exactly what reusable infrastructure should look like. The authoritative math remains in one place, and downstream tools consume a shared projection contract instead of each one rebuilding geometry, interpolation, and validity logic independently.

## Why The Implementation Is Robust

The implementation is robust because it is conservative about what counts as valid truth.

In [BistaticDataAnalysis/adsbToBistatic.m](BistaticDataAnalysis/adsbToBistatic.m):

- NaN-altitude or otherwise unusable fixes are removed before projection.
- non-physical `R_excess <= 0` samples are removed,
- duplicate or zero-gap time steps are guarded before differentiation,
- Doppler is derived from range-rate using the same shared conversion used elsewhere in the repo.

In [BistaticDataAnalysis/alignTruthToRadar.m](BistaticDataAnalysis/alignTruthToRadar.m):

- duplicate timestamps are collapsed before interpolation,
- tracks with fewer than two unique fixes remain non-interpolable,
- outside-window query times remain NaN rather than being extrapolated into false truth,
- tracks with no useful overlap remain present structurally but invalid numerically.

In [SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m](SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQPart.m):

- the raw spot-check query time is deterministic,
- the selection policy is deterministic,
- only finite projected truth rows are eligible,
- the local-peak check records residuals and whether the result stayed inside the intended gate.

This is the right robustness posture for a truth-projection layer. When the truth is insufficient or ambiguous, the code returns invalid/NaN output instead of inventing a clean-looking answer.

## Expert Review

A bistatic-radar expert should read the current defense as strong for **internal correctness**, **software reuse**, and **synthetic-workflow robustness**.

The strongest part of the defense is that the projection helper does not invent a second geometry model. It reuses the authoritative bistatic conversion and alignment layers, and those conventions are tied back to the actual RD-map behavior by test.

The expert caveat is that this is still not the same as hardware-side physical confirmation.

The main remaining expert questions are therefore on the capture-backed side, not on the synthetic side:

1. How is `radar_epoch_utc` established and trusted against ADS-B UTC for real measurements?
2. Is there an independent capture-backed gold case where projected truth lands near an observed hardware echo without tuning the gate around it?
3. How sensitive is the hardware-side result to sparse or irregular ADS-B sampling and any residual clock offset?
4. Are the search gates narrow enough, on real data, that a nearby peak is meaningful rather than inevitable?

For the synthetic pipeline, most of those uncertainties are controlled by construction. The timing basis, Tx/Rx geometry, and target motion are defined by the fixture, which is why the current evidence is already persuasive there.

So the expert reading should be:

- **Correctness:** well-defended for internal mathematical and convention correctness.
- **Reusability:** well-defended because the helper is a shared composition layer with a stable flat-table output.
- **Robustness:** well-defended because edge cases fail safe and are tested directly.
- **Open caveat:** hardware-side timing and registration still need explicit evaluation before claiming physical confirmation on measured data.

## Takeaways

The current project should make the following claim, and no stronger one:

> The ADS-B-to-range-Doppler conversion math is internally validated, reusable, and robust for the synthetic data generation and Stage 2 truth-placement workflow.

The project should also keep the following caveat explicit:

> Hardware-side confirmation remains a separate capture-backed timing and registration problem. The current defense does not by itself prove field-validated truth placement on measured radar data.

In practical terms:

- For the synthetic pipeline, the math is well-defended now.
- For hardware, the next review step is not to rewrite the projection math. The next step is to evaluate clocking, epoch registration, and capture-backed corroboration.
- The raw pre-ECA-C spot check is a strong Stage 2 confidence aid for synthetic truth placement and analysis-step utility, but it does not by itself promote the workflow to Stage 3 field realism.
