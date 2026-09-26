# CT 1.1.0 implementation report

## Message status

| Message | Status | Evidence |
|---|---|---|
| `cue_heartbeat` | Implemented | `tests/test_cue.py`; health-state coverage in `tests/test_app.py` |
| `cue_snapshot_begin` | Implemented | `tests/test_cue.py` validates `cue-snapshot-begin-1.1.0.json` |
| `cue_snapshot_end` | Implemented | `tests/test_cue.py` validates `cue-snapshot-end-1.1.0.json` |
| `track_cue` | Implemented | `tests/test_cue.py` and `tests/test_replay_cueing.py` validate 1.1.0 output; replay coverage uses two observers and three emitters |
| `track_cue_withdrawal` | Implemented | `tests/test_cue.py` validates `track-cue-withdrawal-1.1.0.json` |

Current automated verification: `ruff check . --no-cache` passed and `pytest -q -p no:cacheprovider` passed (60 tests).

## WI-1

The 2026-09-08 capture replayed 2022 SBS timestamps while prediction eligibility compares
reports with the current event clock. Predictions therefore correctly became invalid. The
heartbeat bug was that it counted all stored predictions, including invalid predictions with
no state, while snapshots excluded them. `cue_eligible_predictions()` now supplies the same
stateful prediction set to both paths.

## WI-2

`track_cue` now serializes only receiver-compatible, enabled opportunities with at least one
usable window. Empty opportunity arrays are still emitted so Resource Manager receives valid
track state. The datagram default and example are 16,384 bytes. `cue_capture.py` records
minimum/median/maximum track-cue sizes and opportunities per cue for the pending wire capture.

## CT 1.1.0 changes

The 1.0.0 message schemas are archived. CT now emits 1.1.0 schemas, removes
`implemented_observers`, splits snapshot schemas, normalizes valid RF channels to integers,
and emits null for invalid channels. Heartbeats report startup, running, degraded, and clean
shutdown state. The example and publisher use `239.192.10.1:31986`; the capture tool can join
that multicast group.

## Open items

WI-7 remains open: a multicast capture containing three full snapshots has not yet been
recorded. Therefore no CT message is yet **Verified** or **Frozen**. The capture tool now
checks the required schema failures, duplicate IDs, sequence gaps, snapshot cue counts, and
size statistics when that run is performed.
