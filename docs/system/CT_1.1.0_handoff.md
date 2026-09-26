# Task Brief: CT cue messages to 1.1.0 (Frozen)

**For:** the coding agent working in the ADSB-Remoter repository (`100_ADSB_Console_Respin`).
**From:** system architecture / ICD owner (Leif). **Date:** 2026-09-25.

## 1. Goal

Bring the ADSB Cue Tasker (CT) messages to **Frozen at schema version 1.1.0**, as defined in `docs/system/ICD_Messages.md` §0.

In this system, CT is `ADSBConsoleApp`. Its cue stream is the only way the rest of the passive radar system (Resource Manager, Tracker, Display, Activity Manager) learns about aircraft. The goal is a cue interface that is stable enough for those consumers to be built against it.

## 2. Reference documents and which parts bind you

| Document | Status for this task |
|---|---|
| `docs/system/ICD_Messages.md` **§1** (conventions, transport) and **§2** (CT messages) | **Binding.** Implement exactly this. |
| `docs/system/ICD_Messages.md` §0 (status definitions) | Binding: this is how you report progress. |
| `docs/system/ICD_Messages.md` §3 (other messages) | **Background only.** Do not implement. |
| `docs/system/System_Architecture.md`, `SiteGeometry.md` | Background only. |

These documents are copies. The master versions live in the 043 project folder, so **do not edit them here**. Report any needed changes instead (§6).

## 3. Current state (as found on 2026-09-25)

- `src/adsb_console/cue.py`:
  - builds all CT messages in `CueSerializer`;
  - sends them over UDP in `UdpCuePublisher`;
  - uses one constant, `SCHEMA_VERSION = "1.0.0"`, for every message type.
- `src/adsb_console/app.py`:
  - schedules heartbeats (`heartbeat_interval_s`) and snapshots (`_publish_snapshot`, `snapshot_interval_s`);
  - publishes prediction revisions and withdrawals (`reason="track_purged"`).
- `schemas/` has five 1.0.0 files. The unit tests validate against them:
  - `tests/test_cue.py`
  - `tests/test_replay_cueing.py`, which hard-codes `track-cue-1.0.0.json`
- `tools/cue_capture.py` validates UDP traffic against `schemas/`, choosing the schema by `message_type`.
- Evidence (`cue_capture.jsonl`, 2026-09-08):
  - 38 of 38 messages were valid, with no sequence gaps.
  - The capture contained heartbeats and snapshot begin/end only. **There were no `track_cue` messages.**
  - Heartbeats reported 116 cue-eligible tracks while every snapshot had `expected_track_count: 0`.

## 4. Work items, in order

### WI-1: No live `track_cue` (CT-1)

Find out why `self.predictions` was empty in the 2026-09-08 run (see `_publish_snapshot` in `app.py`), even though heartbeats counted 116 cue-eligible tracks. Possible causes include observer/emitter configuration, prediction being disabled, and history thresholds. Check whether the `cue_eligible_tracks` count and the conditions for creating a prediction disagree.

Fix the cause if it is a bug. **If it is intended behaviour, stop and report it.**

### WI-2: Datagram size (CT-9, decided: option c)

1. In `CueSerializer.track_cue`, include only opportunities with `observer_can_receive and emitter_enabled` **and** at least one usable window.
   - A cue may then have `opportunities: []`, which is allowed. Report how often this happens.
   - Decide whether such cues should still be sent. The default is to send them, because RM still needs track state. Report what you did.
2. Raise `maximum_datagram_bytes` to **16384** in `examples/passive-radar-cueing.json`, and make the `UdpOutputConfig` default match.
3. **Measure and report** real `track_cue` sizes from a live or replay run: minimum, median and maximum bytes, and opportunities per cue, with and without history.

### WI-3: Schema 1.1.0 release (CT-2, CT-6, CT-7, CT-8)

Create these files in `schemas/` from ICD §2:

| New file | Source |
|---|---|
| `track-cue-1.1.0.json` | ICD §2.3. **Remove the `// NEW` comments.** JSON does not allow them. |
| `cue-heartbeat-1.1.0.json` | ICD §2.1: the 1.0.0 schema with `implemented_observers` removed. |
| `cue-snapshot-begin-1.1.0.json` | ICD §2.2 |
| `cue-snapshot-end-1.1.0.json` | ICD §2.2. It replaces `cue-snapshot-boundary`. |
| `track-cue-withdrawal-1.1.0.json` | The 1.0.0 schema with only `schema_version` changed to `"1.1.0"`. This is needed because `SCHEMA_VERSION` is shared by all messages. Keep `reason` as free text; a fixed list is not decided. |

Then update the code and tests:

- Set `SCHEMA_VERSION = "1.1.0"` in `cue.py`.
- Remove `implemented_observers` from `CueSerializer.heartbeat`.
- `rf_channel` must be an **integer or null** (range 2–69). If the emitter data provides a string, convert it to an integer in the serializer. If the conversion fails, emit null and report the value.
- Point `tests/test_cue.py` and `tests/test_replay_cueing.py` at the 1.1.0 files. `cue_snapshot_begin` and `cue_snapshot_end` now map to separate files.
- Move the 1.0.0 schema files to `schemas/archive/`. Keep `cue-config-1.0.0.json` in place, because it is not a message schema and is unchanged.
- In the ICD 1.1.0 schemas, these fields are **nullable because of how `cue.py` reads, not because of observed output**:
  - the `prediction.validation` fields;
  - everything under `summary`;
  - `current`.

  Also, no `window` field is nullable. If real output violates the 1.1.0 schema, **do not loosen the schema on your own.** Report the field, a real example value, and your proposed change.

### WI-4: Heartbeat status (CT-5)

`cue_heartbeat.status` is currently hard-coded to `"running"`. It should be:

| Value | When |
|---|---|
| `starting` | The first heartbeat after start-up. |
| `degraded` | The dump1090 feed is stale (no SBS input for longer than `maximum_adsb_report_age_s`), or the last publish attempts failed or were oversize. |
| `stopping` | A final heartbeat sent on clean shutdown. |
| `running` | Otherwise. |

Keep the rules simple and document them in the code.

### WI-5: Tests (CT-3)

- Add a schema-validation test for `track_cue_withdrawal`.
- Add a replay test with **two observers and several emitters**, so that WI-2 is exercised. The current replay test uses one observer.
- The tests must pass the repository's standard checks: `ruff`, `pyright` (strict), and `pytest`.

### WI-6: Multicast (CT-4, decided: option A)

- **Example config:** set `udp_output.destination_address` to `239.192.10.1` and `destination_port` to `31986`.
- **Publisher:** when the destination is a multicast address, `UdpCuePublisher` sets `IP_MULTICAST_TTL = 1` and `IP_MULTICAST_LOOP = 1`.
- **Capture tool:** `tools/cue_capture.py` must be able to join the multicast group. Add an option if it currently only binds unicast.
- **Unicast:** it must keep working (e.g. `127.0.0.1:31001`) for development.

### WI-7: Live verification

Run CT with live or replayed SBS data and capture at least **3 full snapshots** with `tools/cue_capture.py` on the multicast group. Acceptance:

- `schema_failure_count: 0` and `invalid_messages: 0`
- `track_cue` present, with each snapshot's `published_track_count` equal to the number of `track_cue` messages received for that `snapshot_id`
- no sequence gaps and no duplicate `message_id` values
- message sizes recorded (see WI-2)

## 5. Rules

- **Do not change the meaning of any existing field, and do not add fields** beyond ICD §2. Any schema change beyond this brief needs the ICD owner's approval.
- If the ICD is wrong or cannot be implemented as written, **stop and report it** rather than working around it.
- Keep the console app's interactive behaviour unchanged, apart from what this brief asks for.
- Commit in small steps: one commit per work item, each with passing tests.

## 6. Report back

When done, or when blocked, write `docs/system/CT_1.1.0_report.md` with:

1. **Status for each message**, using the ICD §0 levels (Implemented / Verified), with evidence (test names, capture file, summary JSON):
   - `cue_heartbeat`
   - `cue_snapshot_begin`
   - `cue_snapshot_end`
   - `track_cue`
   - `track_cue_withdrawal`
2. **WI-1:** the root cause and the fix.
3. **WI-2:** the size measurements, and what you decided about cues with no opportunities.
4. **ICD change requests:** each with the field, the problem, a real example, and your proposed change.
5. Anything left open.

The ICD owner will update the master ICD from this report and declare the messages Frozen.
