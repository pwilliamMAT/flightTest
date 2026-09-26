# Interface Control Document — Messages

> **Master copy:** flightTest `main`, `docs/system/`, since 2026-09-26. Change it through git, following the change process in [README.md](README.md).

**System:** Apple Hill passive bistatic radar testbed. Companion to [System_Architecture.md](System_Architecture.md).
**Revision:** Draft A, 2026-09-25. For review.
**Focus of this revision:** the ADSB Cue Tasker (CT) messages, with the goal of freezing them as soon as possible. All other messages are first-draft proposals.

This ICD **replaces** the Interface Catalog and the proposed message envelope in System_Architecture.md. CT already has a working, schema-validated envelope, so the whole system adopts it instead of the camelCase envelope proposed there (see §1).

---

## 0. Development status

Every message carries one development status:

| Status | Meaning | Exit criteria to the next status |
|---|---|---|
| **Proposed** | Exists only in this ICD. | A schema file is committed. |
| **Draft** | A schema file exists; no producer code yet. | The producer emits it and a unit test validates it against the schema. |
| **Implemented** | The producer emits it, and a unit test validates the output against the schema. | Seen live on the wire, and validated with zero errors by a capture tool (`tools/cue_capture.py` or equivalent). |
| **Verified** | Validated live on the wire. | Reviewed, and every open item for the message is closed. |
| **Frozen** | Version locked. Any change needs a new `schema_version` and a compatibility note. | — |

### Status summary

| Message | Producer → Consumers | Status | Schema |
|---|---|---|---|
| `cue_heartbeat` | CT → RM, AM | **Verified** (28 live, 0 errors, capture 2026-09-08) | `cue-heartbeat-1.0.0.json` |
| `cue_snapshot_begin` / `cue_snapshot_end` | CT → RM | **Verified** (5 pairs live, 0 errors) | `cue-snapshot-boundary-1.0.0.json` (current); in 1.1.0, `cue-snapshot-begin-1.1.0.json` and `cue-snapshot-end-1.1.0.json` |
| `track_cue` | CT → RM, TR, RD | **Implemented**. Unit-tested against the schema (`test_cue.py`). A replay test (`test_replay_cueing.py`) also runs recorded ADS-B data through the prediction code and validates the resulting cue, but with **one observer** only. **Not yet seen live** (see CT-1). | `track-cue-1.0.0.json` |
| `track_cue_withdrawal` | CT → RM, TR, RD | **Implemented**, but no schema unit test and not seen live. | `track-cue-withdrawal-1.0.0.json` |
| CT config file (not a message) | file → CT | **Implemented**. Validated at load time. | `cue-config-1.0.0.json` |
| `collection_task` | RM → RC | Proposed | §3.1 |
| `antenna_command` | RM → AC | Proposed | §3.2 |
| `antenna_state` | AC → RC, RM, RD | Proposed | §3.3 |
| `rotator_command` / `rotator_packet` | AC ↔ antenna nodes (ESP-NOW) | Proposed | §3.4 |
| `capture_record` | RC → SP, CM | Proposed | §3.5 |
| `calibration_request` | CM → RM | Proposed | §3.6 |
| `calibration_result` | CM → SP, AM, RD | Proposed | §3.7 |
| `detection_list` | SP → TR, RD | Proposed | §3.8 |
| `track_report` | TR → RM, RD | Proposed | §3.9 |
| `health_status` | all (except CT) → AM | Proposed | §3.10 |
| ~~`truth_track`~~ | — | **Dropped** (proposed). TR and RD consume `track_cue` directly. | — |

Schema files for CT live in the ADSB-Remoter repository under `schemas/`. The rest will live in a shared `schemas/` folder (location **TBD**) using the same naming convention: `<message-name>-<version>.json`.

---

## 1. Common conventions (adopted from CT)

### 1.1 Envelope

Every message is one JSON object whose top level starts with these fields. The envelope is flattened, not nested under a `payload` key.

| Field | Type | Notes |
|---|---|---|
| `schema_version` | string (semver) | The version of that message's schema file. |
| `message_type` | string (const) | snake_case message name. Receivers dispatch on this field. |
| `message_id` | string (UUID) | Unique per message. Used for de-duplication. |
| `source` | string (const per producer) | Application name, e.g. `ADSBConsoleApp`. |
| `source_instance_id` | string | Unique per process start. A new value tells receivers the producer restarted and its sequence numbering has reset. |
| `sequence_number` | integer ≥ 1 | Increases by one per message from each `source_instance_id`, across all message types. Receivers use it to detect gaps and reordering. |
| `generated_utc` | string, ISO-8601 UTC | Millisecond precision with a `Z` suffix, e.g. `2026-09-08T19:36:09.079Z`. |

Proposed shared schema file `envelope-1.0.0.json`, which non-CT schemas `$ref`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/envelope-1.0.0.json",
  "type": "object",
  "required": ["schema_version", "message_type", "message_id", "source",
               "source_instance_id", "sequence_number", "generated_utc"],
  "properties": {
    "schema_version":     { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "message_type":       { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" },
    "message_id":         { "type": "string", "format": "uuid" },
    "source":             { "type": "string", "minLength": 1 },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number":    { "type": "integer", "minimum": 1 },
    "generated_utc":      { "type": "string", "format": "date-time" }
  }
}
```

CT's schemas repeat these fields inline rather than using `$ref`. That is fine. CT does not need to change to adopt the shared file.

### 1.2 Encoding and naming

- UTF-8 JSON. NaN and Infinity are not allowed (CT enforces this with `allow_nan=False`); a missing value is `null`.
- Field names are snake_case, and units go in the name: `_m`, `_mps`, `_hz`, `_db`, `_dbsm`, `_deg`, `_s`, `_utc`.
- All times are UTC. Angles are degrees true unless the name says otherwise. Positions use ENU in metres, relative to a named `reference_origin_id`.
- Every schema sets `additionalProperties: false`. Adding a field therefore requires a schema version bump; this is deliberate.
- Versioning: a patch bump for documentation-only changes, a minor bump for new optional fields or newly-typed sub-objects, a major bump for anything that changes a field's meaning.

### 1.3 Transport

| Stream | Transport | Why |
|---|---|---|
| CT cue stream (all four CT message types) | **UDP**, one message per datagram | CT is built for a lossy link. Periodic full snapshots, per-track revisions and sequence numbers let a receiver recover, so a lost datagram is repaired within one snapshot interval (60 s). This is a deliberate exception to "TCP for anything that must arrive". |
| Tasking, captures, detections, tracks, calibration | TCP, newline-delimited JSON | Must arrive, and has no periodic refresh. |
| `antenna_state`, `health_status` | UDP | Periodic and loss-tolerant. |
| Antenna nodes | ESP-NOW (then USB serial to AC) | See §3.4. |

**Ports** (from the architecture, 31984–31999). This changes CT's configuration only:

| Port | Proto | Listener | Receives |
|---|---|---|---|
| 31984 | TCP | AM | control |
| 31985 | UDP | AM | `health_status` |
| 31986 | UDP multicast `239.192.10.1` | RM, TR, RD, AM (group members) | CT cue stream: all four CT message types (CT-4, Option A) |
| 31986 | TCP | RM | `track_report`, `calibration_request` |
| 31987 | TCP | RC | `collection_task` |
| 31988 | TCP | AC | `antenna_command` |
| 31989 | UDP | broadcast | `antenna_state` |
| 31990 | TCP | SP | `capture_record`, `calibration_result` |
| 31991 | TCP | TR | `detection_list` |
| 31992 | TCP | RD | `track_report`, `detection_list`, `calibration_result` |
| 31993 | TCP | CM | `capture_record` (calibration captures) |
| 31994 | TCP | host agents | launch / stop |

CT currently defaults to `127.0.0.1:31001`. Moving it to the multicast group means setting `udp_output.destination_address` to `239.192.10.1` and `destination_port` to `31986` in the config file.

`239.192.0.0/14` is the organization-local multicast scope, the correct choice for a private LAN. Two points to check in CT:

- Multicast TTL defaults to 1, which keeps traffic on the local subnet. That is what we want.
- For consumers on the same machine as CT to receive the stream, `IP_MULTICAST_LOOP` must be on. It is on by default, but CT may need to set it explicitly on some platforms.

Each consumer binds port 31986 with `SO_REUSEADDR` and joins the group, so several apps on one host can listen at once. The switches need either IGMP snooping or tolerance of flooding; on this small network, flooding is harmless.

---

## 2. ADSB Cue Tasker (CT) messages

Producer: `ADSBConsoleApp` (repository ADSB-Remoter), `src/adsb_console/cue.py`. It publishes only when `udp_output.enabled` is true.

### 2.0 CT timing (from `examples/passive-radar-cueing.json`)

| Message | Trigger | Nominal rate |
|---|---|---|
| `cue_heartbeat` | Timer, `heartbeat_interval_s` | Every **10 s** |
| `cue_snapshot_begin`, then `track_cue` × N, then `cue_snapshot_end` | Timer, `snapshot_interval_s`. A full refresh of every track that has a valid prediction. | Every **60 s**. N = number of predicted tracks (116 cue-eligible in the 2026-09-08 capture). |
| `track_cue` (event) | A new prediction revision. `update_reason` ∈ {initial_track, track_maneuver, prediction_error, periodic_refresh, observer_configuration_change, emitter_configuration_change}. Debounced by `regeneration_debounce_s`. | At most 1 per track per **1 s** (debounce). Refreshed at least every `maximum_prediction_age_s` = **30 s** per track. |
| `track_cue` (operator) | `Shift+Q` in the console with `publication_mode: manual` | On demand |
| `track_cue_withdrawal` | A track is purged (`reason: "track_purged"`) | Event |

Receiver rule: for each `track_id`, keep the `track_cue` with the highest `prediction.revision`. Ignore stale revisions, and delete the track on a withdrawal whose `withdrawn_prediction_revision` ≥ the revision held. A snapshot with a given `snapshot_id` is complete once `cue_snapshot_end` arrives with `published_track_count` equal to the count received. If some are missing, wait for the next snapshot.

### 2.1 `cue_heartbeat` — status: Verified

The liveness signal for the cue stream. It also serves as CT's health heartbeat (see CT-4).

Schema `cue-heartbeat-1.0.0.json` (current, unchanged):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-heartbeat-1.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version", "message_type", "message_id", "source", "source_instance_id",
    "sequence_number", "generated_utc", "status", "active_tracks",
    "cue_eligible_tracks", "active_observers", "implemented_observers", "enabled_emitters"
  ],
  "properties": {
    "schema_version": { "const": "1.0.0" },
    "message_type": { "const": "cue_heartbeat" },
    "message_id": { "type": "string", "format": "uuid" },
    "source": { "const": "ADSBConsoleApp" },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number": { "type": "integer", "minimum": 1 },
    "generated_utc": { "type": "string", "format": "date-time" },
    "status": { "enum": ["starting", "running", "degraded", "stopping"] },
    "active_tracks": { "type": "integer", "minimum": 0 },
    "cue_eligible_tracks": { "type": "integer", "minimum": 0 },
    "active_observers": { "type": "integer", "minimum": 0 },
    "implemented_observers": { "type": "integer", "minimum": 0 },
    "enabled_emitters": { "type": "integer", "minimum": 0 },
    "udp_destination": { "type": ["string", "null"] },
    "last_full_snapshot_utc": { "type": ["string", "null"], "format": "date-time" }
  }
}
```

Review items: CT-5 (`status` is always `"running"`), CT-6 (`implemented_observers` always equals `active_observers`).

**Decided for `cue-heartbeat-1.1.0` (CT-6):**

- Remove `implemented_observers` from `required` and from `properties`.
- Set `schema_version` to `"1.1.0"`.

Nothing else changes. CT-5 changes which `status` values CT sends, but not the schema.

### 2.2 `cue_snapshot_begin` / `cue_snapshot_end` — status: Verified

These bracket each 60 s full refresh. `begin` carries `expected_track_count`. `end` carries `published_track_count` and `failed_track_count`.

Schema `cue-snapshot-boundary-1.0.0.json` (current, unchanged):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-snapshot-boundary-1.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version", "message_type", "message_id", "source", "source_instance_id",
    "sequence_number", "generated_utc", "snapshot_id"
  ],
  "properties": {
    "schema_version": { "const": "1.0.0" },
    "message_type": { "enum": ["cue_snapshot_begin", "cue_snapshot_end"] },
    "message_id": { "type": "string", "format": "uuid" },
    "source": { "const": "ADSBConsoleApp" },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number": { "type": "integer", "minimum": 1 },
    "generated_utc": { "type": "string", "format": "date-time" },
    "snapshot_id": { "type": "string", "minLength": 1 },
    "expected_track_count": { "type": "integer", "minimum": 0 },
    "published_track_count": { "type": "integer", "minimum": 0 },
    "failed_track_count": { "type": "integer", "minimum": 0 }
  }
}
```

Review item CT-7: the count fields are optional in the schema but required in practice (on `begin` and on `end` respectively).

**Decided for 1.1.0 (CT-7):** split `cue-snapshot-boundary` into one schema per message type, matching the rest of CT. Each file allows only one `message_type` value and requires its own counts. CT's output doesn't change. `cue_capture.py` needs no change, because it already picks the schema by `message_type`. Only the file mapping in `test_cue.py` changes. `cue-snapshot-boundary-1.0.0.json` is retired.

`cue-snapshot-begin-1.1.0.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-snapshot-begin-1.1.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version", "message_type", "message_id", "source", "source_instance_id",
    "sequence_number", "generated_utc", "snapshot_id", "expected_track_count"
  ],
  "properties": {
    "schema_version": { "const": "1.1.0" },
    "message_type": { "const": "cue_snapshot_begin" },
    "message_id": { "type": "string", "format": "uuid" },
    "source": { "const": "ADSBConsoleApp" },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number": { "type": "integer", "minimum": 1 },
    "generated_utc": { "type": "string", "format": "date-time" },
    "snapshot_id": { "type": "string", "minLength": 1 },
    "expected_track_count": { "type": "integer", "minimum": 0 }
  }
}
```

`cue-snapshot-end-1.1.0.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-snapshot-end-1.1.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version", "message_type", "message_id", "source", "source_instance_id",
    "sequence_number", "generated_utc", "snapshot_id",
    "published_track_count", "failed_track_count"
  ],
  "properties": {
    "schema_version": { "const": "1.1.0" },
    "message_type": { "const": "cue_snapshot_end" },
    "message_id": { "type": "string", "format": "uuid" },
    "source": { "const": "ADSBConsoleApp" },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number": { "type": "integer", "minimum": 1 },
    "generated_utc": { "type": "string", "format": "date-time" },
    "snapshot_id": { "type": "string", "minLength": 1 },
    "published_track_count": { "type": "integer", "minimum": 0 },
    "failed_track_count": { "type": "integer", "minimum": 0 }
  }
}
```

Because `additionalProperties` is false, a begin message carrying end counts (or an end message carrying `expected_track_count`) is now rejected, whereas before it passed silently.

### 2.3 `track_cue` — status: Implemented

The main cue. It carries one aircraft track: its current state, its prediction metadata, and one *opportunity* per (observer, emitter) pair. Each opportunity holds the predicted bistatic geometry, SNR, and usable observation windows.

This message corresponds to `ADSBCue` in the architecture. Beam-entry times come from `windows[]`. The architecture's `priority` and `recommended_surv_az_deg` are **not** added to CT: priority is RM's job, and the azimuth can be derived by RM from the observer geometry. Keeping them out of CT helps it freeze sooner.

**Current schema `track-cue-1.0.0.json`:** the top level, `track`, `track.state` and `prediction` are fully typed. These sub-objects are declared only as `"type": "object"`, so they are **not locked down**:

- `state.quality`
- `prediction.validation`
- `opportunity.models`
- `opportunity.current`
- `opportunity.summary`
- `opportunity.windows[]`
- `opportunity.history[]`

That gap is the main thing keeping `track_cue` from being freezable (CT-2).

**Proposed `track-cue-1.1.0.json`** is below, for review. It changes no fields and no meanings. It types the loose sub-objects exactly as `cue.py` already emits them and turns the free-text fields into fixed value lists. Current CT output should therefore validate against it unchanged, apart from the `schema_version` constant. Changes from 1.0.0 are marked `// NEW` (JSON does not allow comments; remove them when creating the file).

```jsonc
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/track-cue-1.1.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version", "message_type", "message_id", "source",
    "source_instance_id", "sequence_number", "generated_utc",
    "snapshot_id", "track", "prediction", "opportunities"
  ],
  "properties": {
    "schema_version": { "const": "1.1.0" },                       // NEW version
    "message_type": { "const": "track_cue" },
    "message_id": { "type": "string", "format": "uuid" },
    "source": { "const": "ADSBConsoleApp" },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number": { "type": "integer", "minimum": 1 },
    "generated_utc": { "type": "string", "format": "date-time" },
    "snapshot_id": { "type": ["string", "null"] },
    "track": {
      "type": "object",
      "additionalProperties": false,
      "required": ["track_id", "icao", "status", "last_report_utc", "report_age_s", "state"],
      "properties": {
        "track_id": { "type": "string", "minLength": 1 },
        "icao": { "type": "string", "pattern": "^[0-9A-F]{6}$" },
        "callsign": { "type": ["string", "null"] },
        "status": { "enum": ["active", "stale", "purged", "invalid"] },
        "last_report_utc": { "type": "string", "format": "date-time" },
        "report_age_s": { "type": "number", "minimum": 0 },
        "state": { "$ref": "#/$defs/state" }
      }
    },
    "prediction": { "$ref": "#/$defs/prediction" },
    "opportunities": { "type": "array", "items": { "$ref": "#/$defs/opportunity" } }
  },
  "$defs": {
    "numberOrNull": { "type": ["number", "null"] },
    "utcOrNull": { "type": ["string", "null"], "format": "date-time" },     // NEW
    "vector3": { "type": "array", "items": { "type": "number" }, "minItems": 3, "maxItems": 3 },
    "state": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "epoch_utc", "reference_frame", "reference_origin_id", "position_enu_m",
        "velocity_enu_mps", "latitude_deg", "longitude_deg", "altitude_m_msl"
      ],
      "properties": {
        "epoch_utc": { "type": "string", "format": "date-time" },
        "reference_frame": { "const": "ENU" },
        "reference_origin_id": { "type": "string", "minLength": 1 },
        "position_enu_m": { "$ref": "#/$defs/vector3" },
        "velocity_enu_mps": { "$ref": "#/$defs/vector3" },
        "latitude_deg": { "type": "number", "minimum": -90, "maximum": 90 },
        "longitude_deg": { "type": "number", "minimum": -180, "maximum": 180 },
        "altitude_m_msl": { "type": "number" },
        "ground_speed_mps": { "$ref": "#/$defs/numberOrNull" },
        "track_angle_deg": { "$ref": "#/$defs/numberOrNull" },
        "vertical_rate_mps": { "$ref": "#/$defs/numberOrNull" },
        "quality": { "$ref": "#/$defs/quality" }                             // NEW (was untyped object|null)
      }
    },
    "quality": {                                                             // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["vertical_rate_assumed", "horizontal_velocity_estimated",
                   "position_valid", "velocity_valid"],
      "properties": {
        "vertical_rate_assumed": { "type": "boolean" },
        "horizontal_velocity_estimated": { "type": "boolean" },
        "position_valid": { "type": "boolean" },
        "velocity_valid": { "type": "boolean" }
      }
    },
    "prediction": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "prediction_id", "revision", "created_utc", "valid_until_utc", "horizon_s",
        "sample_interval_s", "motion_model", "maturity", "update_reason", "validation"
      ],
      "properties": {
        "prediction_id": { "type": "string", "minLength": 1 },
        "revision": { "type": "integer", "minimum": 1 },
        "created_utc": { "type": "string", "format": "date-time" },
        "valid_until_utc": { "type": "string", "format": "date-time" },
        "horizon_s": { "type": "number", "exclusiveMinimum": 0 },
        "sample_interval_s": { "type": "number", "exclusiveMinimum": 0 },
        "motion_model": { "const": "constant_velocity_enu" },
        "maturity": { "enum": ["initial", "stabilizing", "stable", "invalid"] },
        "update_reason": {
          "enum": [
            "initial_track", "track_maneuver", "prediction_error", "periodic_refresh",
            "observer_configuration_change", "emitter_configuration_change",
            "application_snapshot"
          ]
        },
        "validation": { "$ref": "#/$defs/validation" }                       // NEW (was untyped)
      }
    },
    "validation": {                                                          // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["position_error_m", "position_error_threshold_m",
                   "velocity_error_mps", "velocity_error_threshold_mps",
                   "heading_change_deg", "heading_change_threshold_deg"],
      "properties": {
        "position_error_m": { "$ref": "#/$defs/numberOrNull" },
        "position_error_threshold_m": { "$ref": "#/$defs/numberOrNull" },
        "velocity_error_mps": { "$ref": "#/$defs/numberOrNull" },
        "velocity_error_threshold_mps": { "$ref": "#/$defs/numberOrNull" },
        "heading_change_deg": { "$ref": "#/$defs/numberOrNull" },
        "heading_change_threshold_deg": { "$ref": "#/$defs/numberOrNull" }
      }
    },
    "opportunity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "opportunity_id", "observer_id", "observer_name", "emitter_id",
        "transmitter_site_id", "carrier_frequency_hz", "emitter_enabled",
        "observer_can_receive", "models", "current", "summary", "windows", "history"
      ],
      "properties": {
        "opportunity_id": { "type": "string", "minLength": 1 },
        "observer_id": { "type": "string", "minLength": 1 },
        "observer_name": { "type": "string", "minLength": 1 },
        "emitter_id": { "type": "string", "minLength": 1 },
        "transmitter_site_id": { "type": "string", "minLength": 1 },
        "carrier_frequency_hz": { "type": "number", "exclusiveMinimum": 0 },
        "rf_channel": { "type": ["integer", "null"], "minimum": 2, "maximum": 69 },  // NEW: CT-8 decided (int)
        "emitter_enabled": { "type": "boolean" },
        "observer_can_receive": { "type": "boolean" },
        "models": { "$ref": "#/$defs/models" },                              // NEW (was untyped)
        "current": { "oneOf": [ { "$ref": "#/$defs/sample" }, { "type": "null" } ] },  // NEW
        "summary": { "$ref": "#/$defs/summary" },                            // NEW (was untyped)
        "windows": { "type": "array", "items": { "$ref": "#/$defs/window" } },          // NEW
        "history": { "type": ["array", "null"], "items": { "$ref": "#/$defs/sample" } } // NEW
      }
    },
    "models": {                                                              // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["bistatic_range_definition", "doppler_source", "doppler_sign_convention",
                   "snr_model_id", "assumed_rcs_dbsm", "detection_threshold_db"],
      "properties": {
        "bistatic_range_definition": { "const": "tx_target_plus_target_rx_minus_tx_rx" },
        "doppler_source": { "const": "analytic_derivative_of_bistatic_range" },
        "doppler_sign_convention": { "const": "positive_for_decreasing_bistatic_path" },
        "snr_model_id": { "type": "string", "minLength": 1 },
        "assumed_rcs_dbsm": { "type": "number" },
        "detection_threshold_db": { "type": "number" }
      }
    },
    "sample": {                                                              // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["time_offset_s", "sample_utc", "bistatic_range_m", "bistatic_range_rate_mps",
                   "bistatic_doppler_hz", "predicted_bistatic_snr_db", "geometrically_visible",
                   "rf_available", "within_range_limits", "within_doppler_limits",
                   "above_snr_threshold", "usable"],
      "properties": {
        "time_offset_s": { "type": "number" },
        "sample_utc": { "type": "string", "format": "date-time" },
        "bistatic_range_m": { "type": "number", "minimum": 0 },
        "bistatic_range_rate_mps": { "type": "number" },
        "bistatic_doppler_hz": { "type": "number" },
        "predicted_bistatic_snr_db": { "type": "number" },
        "geometrically_visible": { "type": "boolean" },
        "rf_available": { "type": "boolean" },
        "within_range_limits": { "type": "boolean" },
        "within_doppler_limits": { "type": "boolean" },
        "above_snr_threshold": { "type": "boolean" },
        "usable": { "type": "boolean" }
      }
    },
    "summary": {                                                             // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["has_usable_window", "next_window_start_utc", "next_window_end_utc",
                   "total_usable_duration_s", "maximum_snr_db", "maximum_snr_utc",
                   "minimum_bistatic_range_m", "maximum_bistatic_range_m",
                   "minimum_bistatic_doppler_hz", "maximum_bistatic_doppler_hz"],
      "properties": {
        "has_usable_window": { "type": "boolean" },
        "next_window_start_utc": { "$ref": "#/$defs/utcOrNull" },
        "next_window_end_utc": { "$ref": "#/$defs/utcOrNull" },
        "total_usable_duration_s": { "type": "number", "minimum": 0 },
        "maximum_snr_db": { "$ref": "#/$defs/numberOrNull" },
        "maximum_snr_utc": { "$ref": "#/$defs/utcOrNull" },
        "minimum_bistatic_range_m": { "$ref": "#/$defs/numberOrNull" },
        "maximum_bistatic_range_m": { "$ref": "#/$defs/numberOrNull" },
        "minimum_bistatic_doppler_hz": { "$ref": "#/$defs/numberOrNull" },
        "maximum_bistatic_doppler_hz": { "$ref": "#/$defs/numberOrNull" }
      }
    },
    "windowReason": {                                                        // NEW (values from prediction.py)
      "enum": ["prediction_start_inside_usable", "prediction_horizon", "geometric_visibility",
               "rf_availability", "bistatic_range_limit", "doppler_limit", "snr_threshold",
               "state_transition"]
    },
    "window": {                                                              // NEW
      "type": "object",
      "additionalProperties": false,
      "required": ["window_id", "start_utc", "end_utc", "duration_s", "entry_reason", "exit_reason",
                   "min_bistatic_range_m", "max_bistatic_range_m",
                   "min_bistatic_range_rate_mps", "max_bistatic_range_rate_mps",
                   "min_bistatic_doppler_hz", "max_bistatic_doppler_hz",
                   "maximum_abs_doppler_rate_hzps", "min_snr_db", "mean_snr_db", "max_snr_db",
                   "peak_snr_utc"],
      "properties": {
        "window_id": { "type": "string", "minLength": 1 },
        "start_utc": { "type": "string", "format": "date-time" },
        "end_utc": { "type": "string", "format": "date-time" },
        "duration_s": { "type": "number", "minimum": 0 },
        "entry_reason": { "$ref": "#/$defs/windowReason" },
        "exit_reason": { "$ref": "#/$defs/windowReason" },
        "min_bistatic_range_m": { "type": "number" },
        "max_bistatic_range_m": { "type": "number" },
        "min_bistatic_range_rate_mps": { "type": "number" },
        "max_bistatic_range_rate_mps": { "type": "number" },
        "min_bistatic_doppler_hz": { "type": "number" },
        "max_bistatic_doppler_hz": { "type": "number" },
        "maximum_abs_doppler_rate_hzps": { "type": "number", "minimum": 0 },
        "min_snr_db": { "type": "number" },
        "mean_snr_db": { "type": "number" },
        "max_snr_db": { "type": "number" },
        "peak_snr_utc": { "type": "string", "format": "date-time" }
      }
    }
  }
}
```

Uncertain points in this draft: whether the `validation` fields can really be `null` (for an initial prediction), and whether any window field can be `null`. I set these from reading `cue.py`, not from live output. A live `track_cue` capture validated against 1.1.0 settles both (CT-1).

### 2.4 `track_cue_withdrawal` — status: Implemented

This tells receivers to drop a track's cue.

Current schema `track-cue-withdrawal-1.0.0.json`: envelope + `track_id`, `icao` (6 hex), `withdrawn_prediction_revision` (int ≥ 1), `reason` (free string).

**Decided for 1.1.0:** identical to 1.0.0 except `schema_version` = `"1.1.0"`. This is required because `cue.py` uses one `SCHEMA_VERSION` constant for every CT message, so all CT message schemas move to the next version together. Also add a schema unit test (CT-3).

Possible later change (not decided): make `reason` a fixed set of values:

```json
"reason": { "enum": ["track_purged", "track_invalid", "prediction_invalid", "operator_withdrawn"] }
```

Only `track_purged` is emitted today (`app.py`). The other three are placeholders.

### 2.5 CT configuration file — status: Implemented

This is not a wire message. `cue-config-1.0.0.json` validates the JSON config that `ADSBConsoleApp --cue-config` loads, with sections `publication_mode`, `cue_prediction` and `udp_output`. It belongs in the ICD because its values set the message rates in §2.0 and the destination in §1.3. No schema changes are proposed. The Activity Manager's `system_config.json` should generate or point to this file, so that CT's destination follows the configuration map.

### 2.6 CT open items (the path to Frozen)

| # | Item | Blocks | Proposed action |
|---|---|---|---|
| **CT-1** | **No `track_cue` has been seen live.** In the 2026-09-08 capture, heartbeats reported 116 cue-eligible tracks, but every snapshot had `expected_track_count: 0`. So `self.predictions` was empty and no predictions were produced. | Verified | Find out why predictions were empty (observer/emitter configuration? prediction disabled?). Then capture and validate a live snapshot. |
| **CT-2** | Loose sub-objects in `track_cue` 1.0.0 | Frozen | Review and adopt 1.1.0 (§2.3). Bump `SCHEMA_VERSION` in `cue.py`. |
| **CT-3** | No schema unit test for `track_cue_withdrawal` | Implemented → Verified | Add it to `test_udp_publisher_serializes_sequences_and_snapshot_messages`. |
| **CT-4** | **Fan-out.** The cue stream has several consumers (RM, TR, RD, and AM for the heartbeat), but CT sends to one address. | Deployment | Option A (recommended): UDP multicast, e.g. `239.192.10.1:31986`. Consumers join the group; CT needs a config change only (plus possibly setting the TTL/loopback socket options). Option B: RM relays to the others. Option C: CT supports a list of destinations (a code change, but no schema change). |
| **CT-5** | `cue_heartbeat.status` is hard-coded to `"running"` | Frozen | Emit `starting` on the first beat, `degraded` when the dump1090 feed is stale or sends are failing, and `stopping` on shutdown. |
| **CT-6** | `implemented_observers` is always set equal to `active_observers` | Frozen | Define the difference between the two, or drop one in 1.1.0. |
| **CT-7** | Snapshot count fields are optional in the schema | Frozen | Add an `if`/`then` on `message_type` in 1.1.0. |
| **CT-8** | `rf_channel` is typed int, string or null | Frozen | Pick one; integer or null is proposed. |
| **CT-9** | **Datagram size.** `maximum_datagram_bytes` = 1200. A `track_cue` with 2 observers × 16 emitters = 32 opportunities is roughly 25–40 KB even without history, so today it would be counted as `failed`. Test fixtures use few opportunities. | Verified | Measure a real payload once CT-1 is fixed. Options: (a) include only opportunities with `observer_can_receive && emitter_enabled && has_usable_window`, which is a behaviour change with no schema change; (b) raise the limit to ≤ 65507 and rely on IP fragmentation on the quiet wired LAN; (c) both. Recommendation: (c), with a limit of 16 KB. |
| CT-10 | The `$id` domain `passive-radar.local` | — | Keep it and use it for all schemas in the system. |

**Decisions (2026-09-25):**

| # | Decision |
|---|---|
| CT-1 | To do: find out why predictions were empty, then capture a live snapshot. |
| CT-2 | **Adopt `track-cue-1.1.0`** (§2.3). |
| CT-3 | To do: add the withdrawal schema test. |
| CT-4 | **Option A, UDP multicast.** CT sends to group `239.192.10.1:31986`; RM, TR, RD and AM join the group (§1.3). |
| CT-5 | **Emit `starting`** on the first beat, **`degraded`** when the dump1090 feed is stale or sends are failing, and **`stopping`** on shutdown. Code change in `cue.py`/`app.py`; no schema change, since the enum already allows these values. |
| CT-6 | **Keep `active_observers` and drop `implemented_observers`.** This needs `cue-heartbeat-1.1.0` (§2.1). |
| CT-7 | **Split into two schemas:** `cue-snapshot-begin-1.1.0` and `cue-snapshot-end-1.1.0`, each requiring its own counts (§2.2). There is no change to CT's output; only the file mapping in `test_cue.py` changes. |
| CT-8 | **`rf_channel` is an integer or null** (applied in §2.3). |
| CT-9 | **Recommendation (c):** send only receivable, enabled opportunities that have a usable window, and raise `maximum_datagram_bytes` to 16384. Measure real payload sizes after CT-1. |
| CT-10 | **Agreed:** keep `passive-radar.local` as the `$id` domain for all schemas. |

**Suggested order:** CT-1 and CT-9 first, since they are the only things preventing live verification. Then CT-2, CT-3, CT-5, CT-6, CT-7 and CT-8 as a single 1.1.0 schema release. Every CT message schema moves to 1.1.0 together, because they share one `SCHEMA_VERSION`:

- `track-cue`
- `cue-heartbeat`
- `cue-snapshot-begin`
- `cue-snapshot-end`
- `track-cue-withdrawal`

After a validated live capture, declare all of them **Frozen at 1.1.0**.

Work is handed off in [CT_1.1.0_handoff.md](CT_1.1.0_handoff.md).

---

## 3. Other messages (Proposed)

These use the envelope in §1.1. The schemas below list only the message-specific fields. Each real schema file combines `{"allOf": [{"$ref": "envelope-1.0.0.json"}, {...below...}]}` with `unevaluatedProperties: false`. `source` is the software item's app name.

### 3.1 `collection_task` — RM → RC (TCP 31987) — Proposed

**Rate:** event-driven. Up to a few per minute, issued from the 1 min short loop and the 5 min long loop. Most collections last 15 s or less.

```json
{
  "properties": {
    "message_type": { "const": "collection_task" },
    "task_id": { "type": "string", "minLength": 1 },
    "observer_id": { "type": "string" },
    "reason": { "enum": ["cue", "track_update", "calibration", "survey"] },
    "cue_ref": { "type": ["object", "null"], "properties": {
        "track_id": { "type": "string" }, "prediction_revision": { "type": "integer" },
        "opportunity_id": { "type": "string" }, "window_id": { "type": "string" } } },
    "start_utc": { "type": "string", "format": "date-time" },
    "duration_s": { "type": "number", "exclusiveMinimum": 0, "maximum": 60 },
    "emitter_id": { "type": ["string", "null"] },
    "center_frequency_hz": { "type": "number" },
    "sample_rate_sps": { "type": "number" },
    "lo_offset_hz": { "type": "number" },
    "gain_db": { "type": "object", "properties": { "surv": { "type": "number" }, "ref": { "type": "number" } },
                 "required": ["surv", "ref"] },
    "surv_az_deg": { "type": ["number", "null"] },
    "ref_az_deg": { "type": ["number", "null"] },
    "output_path": { "type": "string" }
  },
  "required": ["message_type", "task_id", "observer_id", "reason", "start_utc", "duration_s",
               "center_frequency_hz", "sample_rate_sps", "lo_offset_hz", "gain_db", "output_path"]
}
```

`cue_ref` links a capture back to the exact CT prediction that caused it, which the truth scoring needs.

### 3.2 `antenna_command` — RM → AC (TCP 31988) — Proposed

**Rate:** event-driven. One per re-point before a task, at most one per antenna per short loop.

```json
{
  "properties": {
    "message_type": { "const": "antenna_command" },
    "task_id": { "type": ["string", "null"] },
    "antenna": { "enum": ["SURV", "REF"] },
    "command": { "enum": ["go_to", "stop", "cal_sweep"] },
    "target_az_deg": { "type": ["number", "null"], "minimum": 0, "exclusiveMaximum": 360 },
    "tolerance_deg": { "type": "number", "minimum": 0 },
    "deadline_utc": { "type": ["string", "null"], "format": "date-time" }
  },
  "required": ["message_type", "antenna", "command"]
}
```

### 3.3 `antenna_state` — AC → RC, RM, RD (UDP 31989 broadcast) — Proposed

**Rate:** 1 Hz per antenna while moving. While stopped, sent on any change > 0.5° and otherwise every 10 s. Nothing is sent during captures except the 10 s heartbeat.

```json
{
  "properties": {
    "message_type": { "const": "antenna_state" },
    "antenna": { "enum": ["SURV", "REF"] },
    "measured_utc": { "type": "string", "format": "date-time" },
    "az_true_deg": { "type": ["number", "null"] },
    "tilt_deg": { "type": ["number", "null"] },
    "field_strength_ut": { "type": ["number", "null"] },
    "field_strength_ok": { "type": "boolean" },
    "tilt_ok": { "type": "boolean" },
    "moving": { "type": "boolean" },
    "command_state": { "enum": ["idle", "moving", "settled", "fault"] },
    "fault_code": { "type": ["string", "null"] },
    "node_last_heard_utc": { "type": ["string", "null"], "format": "date-time" }
  },
  "required": ["message_type", "antenna", "measured_utc", "az_true_deg", "moving", "command_state"]
}
```

### 3.4 `rotator_command` / `rotator_packet` — AC ↔ antenna nodes (ESP-NOW via the USB gateway) — Proposed

**Rate:** see antenna_controller.md. Packets arrive at up to ~10 Hz while moving (on each > 0.5° change) and as a 10 s heartbeat when idle. Commands are sent on demand.

**Constraint:** an ESP-NOW frame carries at most 250 bytes, so this pair does **not** use the full envelope. It uses short keys, and the gateway expands them into the full field names before handing them to AC:

```json
{ "t": "rp", "n": 1, "q": 1234, "h": 271.4, "m": [12.1, -3.2, -40.0],
  "a": [0.01, -0.02, 0.99], "f": 49.8, "mv": 0, "e": 0 }
```

Keys: `t` = type (`rc` command / `rp` packet), `n` = node ID, `q` = sequence, `h` = true heading (deg), `m` = magnetometer µT ×3, `a` = accelerometer g ×3, `f` = total field (µT), `mv` = moving flag, `e` = ack/fault code. A command is `{"t":"rc","n":1,"q":57,"c":"goto","az":270.0}`.

Schema: **TBD** once the firmware exists.

### 3.5 `capture_record` — RC → SP, CM (TCP 31990 / 31993) — Proposed

**Rate:** one per completed capture. At most about 1 per 15 s; typically a few per minute.

```json
{
  "properties": {
    "message_type": { "const": "capture_record" },
    "task_id": { "type": "string" },
    "observer_id": { "type": "string" },
    "file_path": { "type": "string" },
    "start_utc": { "type": "string", "format": "date-time" },
    "duration_s": { "type": "number" },
    "center_frequency_hz": { "type": "number" },
    "sample_rate_sps": { "type": "number" },
    "lo_offset_hz": { "type": "number" },
    "gain_db": { "type": "object" },
    "radio": { "type": "string" },
    "antenna_ports": { "type": "array", "items": { "type": "string" } },
    "channel_map": { "const": { "1": "SURV", "2": "REF" } },
    "surv_antenna": { "$ref": "#/$defs/antennaSnapshot" },
    "ref_antenna": { "$ref": "#/$defs/antennaSnapshot" },
    "matlab_release": { "type": "string" },
    "status": { "enum": ["ok", "drops", "fail"] },
    "dropped_samples": { "type": "integer", "minimum": 0 }
  },
  "required": ["message_type", "task_id", "observer_id", "file_path", "start_utc", "status"],
  "$defs": { "antennaSnapshot": { "type": "object", "properties": {
      "az_true_deg": { "type": ["number", "null"] }, "field_strength_ok": { "type": "boolean" },
      "tilt_ok": { "type": "boolean" }, "node_last_heard_utc": { "type": ["string", "null"] } } } }
}
```

### 3.6 `calibration_request` — CM → RM (TCP 31986) — Proposed

**Rate:** event-driven, following the calibration schedule. Typically a few per hour, plus one after any FAIL.

```json
{
  "properties": {
    "message_type": { "const": "calibration_request" },
    "request_id": { "type": "string" },
    "cal_type": { "enum": ["pluto_tone", "pluto_multitone", "noise_floor", "azimuth_scan", "rotator_mag_sweep"] },
    "earliest_utc": { "type": "string", "format": "date-time" },
    "latest_utc": { "type": "string", "format": "date-time" },
    "priority": { "type": "integer", "minimum": 0, "maximum": 9 },
    "estimated_duration_s": { "type": "number" }
  },
  "required": ["message_type", "request_id", "cal_type", "earliest_utc", "latest_utc", "priority"]
}
```

### 3.7 `calibration_result` — CM → SP, AM, RD (TCP) — Proposed

**Rate:** one per calibration capture evaluated.

```json
{
  "properties": {
    "message_type": { "const": "calibration_result" },
    "request_id": { "type": ["string", "null"] },
    "task_id": { "type": "string" },
    "cal_type": { "type": "string" },
    "verdict": { "enum": ["PASS", "WARN", "FAIL"] },
    "baseline_ref": { "type": "string" },
    "per_channel": { "type": "object", "properties": {
        "surv": { "$ref": "#/$defs/chan" }, "ref": { "$ref": "#/$defs/chan" } } },
    "coherence": { "type": ["number", "null"] },
    "artifact_path": { "type": "string" }
  },
  "required": ["message_type", "task_id", "cal_type", "verdict"],
  "$defs": { "chan": { "type": "object", "properties": {
      "gain_offset_db": { "type": ["number", "null"] }, "phase_offset_deg": { "type": ["number", "null"] },
      "freq_offset_hz": { "type": ["number", "null"] }, "margin_db": { "type": ["number", "null"] } } } }
}
```

### 3.8 `detection_list` — SP → TR, RD (TCP 31991 / 31992) — Proposed

**Rate:** one per processed capture (usually one per `capture_record`), within the near-real-time budget.

```json
{
  "properties": {
    "message_type": { "const": "detection_list" },
    "task_id": { "type": "string" },
    "observer_id": { "type": "string" },
    "emitter_id": { "type": "string" },
    "processing": { "type": "object", "properties": {
        "cpi_s": { "type": "number" }, "n_cpi": { "type": "integer" },
        "detector": { "type": "string" }, "pfa": { "type": "number" } } },
    "detections": { "type": "array", "items": { "type": "object",
      "required": ["cpi_utc", "bistatic_range_m", "bistatic_doppler_hz", "snr_db"],
      "properties": {
        "cpi_utc": { "type": "string", "format": "date-time" },
        "bistatic_range_m": { "type": "number" },
        "bistatic_doppler_hz": { "type": "number" },
        "snr_db": { "type": "number" },
        "range_sigma_m": { "type": ["number", "null"] },
        "doppler_sigma_hz": { "type": ["number", "null"] },
        "quality": { "type": ["string", "null"] } } } },
    "rd_map_path": { "type": ["string", "null"] }
  },
  "required": ["message_type", "task_id", "observer_id", "emitter_id", "detections"]
}
```

`bistatic_range_m` and `bistatic_doppler_hz` use the **same definitions and sign convention as CT** (`opportunity.models`). The Tracker compares them directly with CT's predictions.

### 3.9 `track_report` — TR → RM, RD (TCP 31986 / 31992) — Proposed

**Rate:** after each tracker update (per `detection_list`), plus a full list every 30 s.

```json
{
  "properties": {
    "message_type": { "const": "track_report" },
    "report_kind": { "enum": ["update", "full"] },
    "tracks": { "type": "array", "items": { "type": "object",
      "required": ["track_id", "observer_id", "emitter_id", "time_utc", "state", "status"],
      "properties": {
        "track_id": { "type": "string" },
        "observer_id": { "type": "string" },
        "emitter_id": { "type": "string" },
        "time_utc": { "type": "string", "format": "date-time" },
        "state": { "type": "object", "properties": {
            "bistatic_range_m": { "type": "number" }, "bistatic_range_rate_mps": { "type": "number" } } },
        "covariance": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } },
        "status": { "enum": ["tentative", "confirmed", "coasting", "deleted"] },
        "associated_icao": { "type": ["string", "null"], "pattern": "^[0-9A-F]{6}$" },
        "associated_ct_track_id": { "type": ["string", "null"] },
        "next_update_due_utc": { "type": ["string", "null"], "format": "date-time" } } } }
  },
  "required": ["message_type", "report_kind", "tracks"]
}
```

### 3.10 `health_status` — all MATLAB items → AM (UDP 31985) — Proposed

**Rate:** every **5 s** per software item, plus immediately on any state change. CT is exempt: its `cue_heartbeat` serves the same purpose (CT-4).

```json
{
  "properties": {
    "message_type": { "const": "health_status" },
    "item_id": { "enum": ["AR", "CT", "RM", "RC", "SP", "TR", "RD", "CM", "AM", "AC"] },
    "host": { "type": "string" },
    "state": { "enum": ["starting", "up", "degraded", "stopping", "down"] },
    "detail": { "type": ["string", "null"] },
    "metrics": { "type": "object" }
  },
  "required": ["message_type", "item_id", "host", "state"]
}
```

### 3.11 Not messages

- **Time sync:** NTP (chrony) from the Pi. It is not in this ICD.
- **SBS-1 from dump1090 (TCP 30003):** an external format owned by dump1090, consumed only by CT. It is not in this ICD.
- **IQ data:** `.bb` files referenced by path in `capture_record`. They never go over a socket.
