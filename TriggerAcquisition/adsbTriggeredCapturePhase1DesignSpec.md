# ADS-B Triggered Capture Phase 1 Design Spec

This note freezes the current Phase 1 trigger contract before any new gating redesign. Treat it as the baseline description for offline validation, preflight review, and future approval conversations.

## Scope

Phase 1 is a wrapper-only acquisition layer. It does **not** replace the existing local N320 capture path, and it does **not** claim calibrated passive-radar detection performance.

Current entrypoints:

- Shell coordinator: `TriggerAcquisition/run_adsb_triggered_hdtv_capture.sh`
- MATLAB session supervisor: `TriggerAcquisition/runADSBTriggeredCaptureSession.m`
- Standalone preview: `TriggerAcquisition/plotADSBTriggerCandidateMap.m`
- Local preflight: `TriggerAcquisition/runADSBTriggerPreflight.m`
- Offline baseline validation: `TriggerAcquisition/runADSBTriggerOfflineValidation.m`
- Frozen comparison target: `TriggerAcquisition/helperTriggerPhase1FrozenBaseline.m`

## Phase 1 Defaults

Current defaults are:

- `Mode = shadow`
- `OpportunityPolicy = single`
- `WatchTimeout_s = 600`
- `PollPeriod_s = 5`
- `ADSBRotation_s = 5`
- `TailSeconds_s = 5`
- `CaptureDuration_s = 30`
- `CorridorAzimuthCenter_deg = 270`
- `SurveillanceBoresightAzimuth_deg = 270`
- `QualifiedTriggerScore = 0.45`
- `MinConsecutiveQualifiedPolls = 2`
- `ReceiverRangeBand_m = [15000 60000]`
- `AltitudeBand_m = [1000 5000]`

The default trigger direction is west-facing. Logan or other east-facing geometry is no longer implied by default.

## Geometry Precedence

The geometry resolver is frozen as:

1. `CorridorAzimuthCenter_deg` override wins for the corridor center.
2. If the corridor override is absent and `CorridorReferenceLLA` is finite, the corridor center is derived from that reference point.
3. Otherwise the corridor center defaults to `270 deg`.
4. `SurveillanceBoresightAzimuth_deg` is resolved independently.
5. If the boresight override is absent, the boresight defaults to `270 deg`.

This means a legacy corridor reference does **not** implicitly rotate the boresight. Any future change to that precedence is a contract change and must be approved explicitly.

## Qualification Rule

The current qualification definition is frozen as:

```text
qualified = hard_gate_pass & trigger_score >= QualifiedTriggerScore
```

with:

```text
hard_gate_pass = geometry_gate_pass & freshness_gate_pass
geometry_gate_pass = altitude_gate_pass & range_gate_pass & corridor_gate_pass & boresight_gate_pass
```

`trigger_score` remains a proxy ranking score based on the current geometry sequence and coarse RF prior. It is not calibrated `Pd` unless `ReferenceChainPenalty_dB` is supplied, and even then it remains a proxy transformation rather than a field-calibrated model.

## State Machine

The MATLAB supervisor owns this fixed Phase 1 state machine:

```text
watch -> score -> arm -> capture_once -> tail -> exit
```

Behavior notes:

- `shadow` mode records the recommendation but does not authorize capture.
- `live` mode calls the existing `runLocalHDTVCapture.m` path once.
- The Phase 1 wrapper is still single-opportunity only, even if a caller asks for `continuous`.

## Phase 1 Non-Goals

These remain out of scope for this frozen baseline:

- no calibrated `Pd` or field-fit trigger probability model
- no multi-opportunity policy
- no new RF propagation model or new mission-report generation flow
- no new N320 capture backend
- no mixing of gating redesign with shell/hardware/integration refactors in the same pass

## Offline Validation Rule

Use `runADSBTriggerOfflineValidation.m` before any pre-hardware or hardware review. That validation freezes:

- west-side positive ranking and qualification
- east-side decoy rejection
- explicit azimuth-override precedence
- empty qualified-region rendering
- preview qualified-region footprint
- shell-wrapper command contract

Any intentional delta requires explicit approval and a deliberate baseline update in `helperTriggerPhase1FrozenBaseline.m`.

## Pre-Hardware Rule

Before any future testing-machine run, require:

1. MATLAB regression tests passing
2. `runADSBTriggerOfflineValidation` passing
3. one standalone preview review
4. `run_adsb_triggered_hdtv_capture.sh --preflight-only` passing on the testing machine
5. one shadow-mode dry run on the testing machine
