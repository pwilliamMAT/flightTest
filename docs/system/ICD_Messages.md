# Interface Control Document — Messages

> **Master copy:** flightTest `main`, `docs/system/`, since 2026-09-26. Change it through git, following the change process in [README.md](README.md).

**System:** Apple Hill passive bistatic radar testbed. Companion to [System_Architecture.md](System_Architecture.md).
**Revision:** Draft B, 2026-09-26: CT messages 2.0.0 (CR-5; changes in §2.7). Draft A was 2026-09-25.
**Focus:** the ADSB Cue Tasker (CT) messages, now at 2.0.0 and heading for Frozen. All other messages are first-draft proposals; they adopt the same conventions (§1), including epoch-millisecond times.

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
| `cue_heartbeat` | CT → RM, AM | **Draft** at 2.0.0 (1.1.0 was Verified 2026-09-26, CR-3) | `cue-heartbeat-2.0.0.json` |
| `cue_snapshot_begin` / `cue_snapshot_end` | CT → RM | **Draft** at 2.0.0 (1.1.0 was Verified 2026-09-26) | `cue-snapshot-begin-2.0.0.json`, `cue-snapshot-end-2.0.0.json` |
| `track_cue` | CT → RM, TR, RD | **Draft** at 2.0.0 (1.1.0 was Verified 2026-09-26, one aircraft) | `track-cue-2.0.0.json` |
| `track_cue_withdrawal` | CT → RM, TR, RD | **Draft** at 2.0.0 (1.1.0 Implemented; never seen live) | `track-cue-withdrawal-2.0.0.json` |
| CT config file (not a message) | file → CT | **Draft** at 2.0.0 | `cue-config-2.0.0.json` |
| CT compression dictionary (not a message) | file → CT and every consumer | **Draft**: id 1 (§1.3) | `dictionaries/cue-dictionary-1.bin` |
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

Schema files and compression dictionaries for CT live in the ADSB-Remoter repository, under `schemas/` and `schemas/dictionaries/`. Superseded versions are in `schemas/archive/`. The rest will live in a shared `schemas/` folder (location **TBD**) using the same naming convention: `<message-name>-<version>.json`.

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
| `generated_utc_ms` | integer ≥ 0 | Milliseconds since 1970-01-01T00:00:00Z (§1.2). |

Proposed shared schema file `envelope-1.0.0.json`, which non-CT schemas `$ref`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/envelope-1.0.0.json",
  "type": "object",
  "required": ["schema_version", "message_type", "message_id", "source",
               "source_instance_id", "sequence_number", "generated_utc_ms"],
  "properties": {
    "schema_version":     { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "message_type":       { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" },
    "message_id":         { "type": "string", "format": "uuid" },
    "source":             { "type": "string", "minLength": 1 },
    "source_instance_id": { "type": "string", "minLength": 1 },
    "sequence_number":    { "type": "integer", "minimum": 1 },
    "generated_utc_ms":   { "type": "integer", "minimum": 0 }
  }
}
```

CT's schemas repeat these fields inline rather than using `$ref`. That is fine. CT does not need to change to adopt the shared file.

### 1.2 Encoding and naming

- UTF-8 JSON. NaN and Infinity are not allowed (CT enforces this with `allow_nan=False`); a missing value is `null`.
- Field names are snake_case, and units go in the name: `_m`, `_mps`, `_hz`, `_hzps`, `_db`, `_dbsm`, `_deg`, `_s`, `_utc_ms`.
- **Times** are integers in fields named `*_utc_ms`: milliseconds since 1970-01-01T00:00:00Z. This applies to every message in this ICD.
  - Reason: MATLAB reads them as numbers, and one vectorised `datetime(t/1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC')` replaces per-field string parsing. A double holds them exactly to the millisecond.
  - Angles are degrees true unless the name says otherwise. Positions use ENU in metres, relative to a named `reference_origin_id`.
- **Resolution.** Producers round measured values to the resolution for their unit, to the nearest value. A producer may send finer values only where this ICD says so.

  | Unit (field suffix) | Resolution |
  |---|---|
  | `latitude_deg`, `longitude_deg` | 1e-6° (about 0.1 m) |
  | other `_deg` | 0.1° |
  | `_m`, `_m_msl` | 1 m (sent as an integer) |
  | `_mps` | 0.1 m/s |
  | `_hz` | 0.1 Hz |
  | `_hzps` | 0.001 Hz/s |
  | `_db`, `_dbsm` | 0.1 dB |
  | `_s` | 0.1 s |
  | `_utc_ms` | 1 ms (integer) |

- **Fixed shapes, for MATLAB `jsondecode` and compiled apps.** These rules make `jsondecode` return the same struct types every time:
  - Within one producer run (one `source_instance_id`), a message type always has the same shape: every property is present in every message. A startup option may add an optional property (for example CT's debug-only `summary`), but then it is present in every message of that run.
  - No field is `null` in some messages and an object or array in others.
  - Arrays of objects always have identical keys, so they decode to struct arrays, not cell arrays.
  - Measured quantities are numbers. Enumerations are strings.
  - Field names are valid MATLAB identifiers of at most 63 characters.
- Every schema sets `additionalProperties: false`. Adding a field therefore requires a schema version bump; this is deliberate.
- Versioning: a patch bump for documentation-only changes, a minor bump for new optional fields or newly-typed sub-objects, a major bump for anything that changes a field's meaning.

### 1.3 Transport

| Stream | Transport | Why |
|---|---|---|
| CT cue stream (all four CT message types) | **UDP**, one message per datagram, plain or compressed (see Framing below) | CT is built for a lossy link. Periodic full snapshots, per-track revisions and sequence numbers let a receiver recover, so a lost datagram is repaired within one snapshot interval (60 s). This is a deliberate exception to "TCP for anything that must arrive". |
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

CT's example and deployed configurations send to `239.192.10.1:31986`. For bench work, CT can also send unicast (for example `127.0.0.1:31001`).

#### Framing of the CT cue stream (since 2.0.0)

Each datagram carries exactly one message, in one of two forms:

| First byte | Contents |
|---|---|
| `{` (0x7B) | **Plain:** the UTF-8 JSON message. |
| `0xDC` | **Compressed:** byte 1 is the dictionary id (1–255). Bytes 2 onward are raw deflate (RFC 1951; no zlib or gzip header) of the UTF-8 JSON message, compressed with that dictionary as the preset dictionary. |

- **The producer chooses the framing once, at startup,** with CT's `udp_output.encoding` (`json` or `deflate_dictionary`) and `udp_output.dictionary_id`, or a command-line override. Every datagram of a run uses the same framing. Deployed CT uses `deflate_dictionary`; plain JSON is for development and troubleshooting.
- **Receivers choose per datagram,** from the first byte, and need no configuration. They count datagrams with an unknown first byte or dictionary id, and drop them. Schema validation always applies to the decoded JSON.
- **One Ethernet frame.** CT's `maximum_datagram_bytes` defaults to 1472, the UDP payload of one 1500-byte Ethernet frame, so no datagram is fragmented. CT fits each `track_cue` to that size (§2.0).
- **Decoding in MATLAB:** use `java.util.zip.Inflater(true)` with `setDictionary` before any input, fed through an `InflaterOutputStream` into a `ByteArrayOutputStream`. This is plain Java 8, and it works in compiled apps (see `analysis/deployability/`).

**Compression dictionaries.** A dictionary is a controlled artifact, like a schema:

- It lives in ADSB-Remoter `schemas/dictionaries/cue-dictionary-<id>.bin`, with a `.sha256` file, and is at most 32 768 bytes.
- It is built reproducibly by `tools/build_cue_dictionary.py` from real 2.0.0 messages.
- It is immutable once released; a change gets a new id through a CR.
- Every consumer ships all released dictionaries, and checks the SHA-256 before use.

| Id | File | SHA-256 | Built from | Status |
|---|---|---|---|---|
| 1 | `cue-dictionary-1.bin` | *recorded at release* | CT 2.0.0 messages, see the file's build record | Draft |

`239.192.0.0/14` is the organization-local multicast scope, the correct choice for a private LAN. Two points to check in CT:

- Multicast TTL defaults to 1, which keeps traffic on the local subnet. That is what we want.
- For consumers on the same machine as CT to receive the stream, `IP_MULTICAST_LOOP` must be on. It is on by default, but CT may need to set it explicitly on some platforms.

Each consumer binds port 31986 with `SO_REUSEADDR` and joins the group, so several apps on one host can listen at once. The switches need either IGMP snooping or tolerance of flooding; on this small network, flooding is harmless.

---

## 2. ADSB Cue Tasker (CT) messages

Producer: `ADSBConsoleApp` (repository ADSB-Remoter), `src/adsb_console/cue.py`. It publishes only when `udp_output.enabled` is true. Every CT message carries `schema_version` `"2.0.0"`; all CT schemas move together because they share one `SCHEMA_VERSION`.

### 2.0 CT timing and receiver rules

| Message | Trigger | Nominal rate |
|---|---|---|
| `cue_heartbeat` | Timer, `heartbeat_interval_s` | Every **10 s** |
| `cue_snapshot_begin`, then `track_cue` × N, then `cue_snapshot_end` | Timer, `snapshot_interval_s`. A full refresh of every track that has a valid prediction | Every **60 s**. N = number of cue-eligible tracks |
| `track_cue` (event) | A new prediction revision. `update_reason` ∈ {initial_track, track_maneuver, prediction_error, periodic_refresh, observer_configuration_change, emitter_configuration_change}. Debounced by `regeneration_debounce_s` | At most 1 per track per **1 s**; refreshed at least every `maximum_prediction_age_s` = **30 s** per track |
| `track_cue` (operator) | `Shift+Q` in the console with `publication_mode: manual` | On demand |
| `track_cue_withdrawal` | A track is purged (`reason: "track_purged"`) | Event |

**Opportunity selection and fit to frame.** A `track_cue` carries only opportunities that the observer can receive, whose emitter is enabled, and that have at least one usable window, strongest peak window SNR first:

1. At most `udp_output.maximum_opportunities_per_cue` of them (default **8**).
2. If the encoded datagram is larger than `maximum_datagram_bytes` (default 1472), CT drops the lowest-ranked opportunity and encodes again, until it fits.
3. A cue that doesn't fit even with no opportunities is not sent. It counts as oversize, and the next heartbeat reports `degraded`.

An empty `opportunities` array is valid, and still delivers the track state.

**Receiver rules:**
- For each `track_id`, keep the `track_cue` with the highest `prediction.revision`, and ignore stale revisions.
- Delete the track on a withdrawal whose `withdrawn_prediction_revision` is at least the revision held.
- A snapshot with a given `snapshot_id` is complete once `cue_snapshot_end` arrives with `published_track_count` equal to the count received. If some are missing, wait for the next snapshot.

### 2.1 `cue_heartbeat`

The liveness signal for the cue stream; it also serves as CT's health heartbeat. `status`:

| Value | When |
|---|---|
| `starting` | The first beat |
| `degraded` | The dump1090 feed is stale (no SBS for more than `maximum_adsb_report_age_s`), or sends failed or were oversize since the previous beat |
| `stopping` | The final beat on a clean shutdown |
| `running` | Otherwise |

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-heartbeat-2.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "message_type",
    "message_id",
    "source",
    "source_instance_id",
    "sequence_number",
    "generated_utc_ms",
    "status",
    "active_tracks",
    "cue_eligible_tracks",
    "active_observers",
    "enabled_emitters",
    "udp_destination",
    "last_full_snapshot_utc_ms"
  ],
  "properties": {
    "schema_version": {
      "const": "2.0.0"
    },
    "message_type": {
      "const": "cue_heartbeat"
    },
    "message_id": {
      "type": "string",
      "format": "uuid"
    },
    "source": {
      "const": "ADSBConsoleApp"
    },
    "source_instance_id": {
      "type": "string",
      "minLength": 1
    },
    "sequence_number": {
      "type": "integer",
      "minimum": 1
    },
    "generated_utc_ms": {
      "type": "integer",
      "minimum": 0
    },
    "status": {
      "enum": [
        "starting",
        "running",
        "degraded",
        "stopping"
      ]
    },
    "active_tracks": {
      "type": "integer",
      "minimum": 0
    },
    "cue_eligible_tracks": {
      "type": "integer",
      "minimum": 0
    },
    "active_observers": {
      "type": "integer",
      "minimum": 0
    },
    "enabled_emitters": {
      "type": "integer",
      "minimum": 0
    },
    "udp_destination": {
      "type": [
        "string",
        "null"
      ]
    },
    "last_full_snapshot_utc_ms": {
      "type": [
        "integer",
        "null"
      ],
      "minimum": 0
    }
  }
}
```

### 2.2 `cue_snapshot_begin` / `cue_snapshot_end`

These bracket each 60 s full refresh. `begin` carries `expected_track_count`; `end` carries `published_track_count` and `failed_track_count`.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-snapshot-begin-2.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "message_type",
    "message_id",
    "source",
    "source_instance_id",
    "sequence_number",
    "generated_utc_ms",
    "snapshot_id",
    "expected_track_count"
  ],
  "properties": {
    "schema_version": {
      "const": "2.0.0"
    },
    "message_type": {
      "const": "cue_snapshot_begin"
    },
    "message_id": {
      "type": "string",
      "format": "uuid"
    },
    "source": {
      "const": "ADSBConsoleApp"
    },
    "source_instance_id": {
      "type": "string",
      "minLength": 1
    },
    "sequence_number": {
      "type": "integer",
      "minimum": 1
    },
    "generated_utc_ms": {
      "type": "integer",
      "minimum": 0
    },
    "snapshot_id": {
      "type": "string",
      "minLength": 1
    },
    "expected_track_count": {
      "type": "integer",
      "minimum": 0
    }
  }
}
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/cue-snapshot-end-2.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "message_type",
    "message_id",
    "source",
    "source_instance_id",
    "sequence_number",
    "generated_utc_ms",
    "snapshot_id",
    "published_track_count",
    "failed_track_count"
  ],
  "properties": {
    "schema_version": {
      "const": "2.0.0"
    },
    "message_type": {
      "const": "cue_snapshot_end"
    },
    "message_id": {
      "type": "string",
      "format": "uuid"
    },
    "source": {
      "const": "ADSBConsoleApp"
    },
    "source_instance_id": {
      "type": "string",
      "minLength": 1
    },
    "sequence_number": {
      "type": "integer",
      "minimum": 1
    },
    "generated_utc_ms": {
      "type": "integer",
      "minimum": 0
    },
    "snapshot_id": {
      "type": "string",
      "minLength": 1
    },
    "published_track_count": {
      "type": "integer",
      "minimum": 0
    },
    "failed_track_count": {
      "type": "integer",
      "minimum": 0
    }
  }
}
```

### 2.3 `track_cue`

The main cue: one aircraft track, with its current state, its prediction, the prediction models (once per cue), and its ranked observation *opportunities*. Each opportunity is one (observer, emitter) pair, with its current predicted geometry and SNR (`current`) and its usable observation windows (`windows`).

- **What is left out, and why:**
  - **Priority:** RM decides it.
  - **Recommended antenna azimuth:** RM derives it from the observer geometry.
  - **Identifiers that can be derived:**
    - an opportunity is identified by `observer_id` + `emitter_id`;
    - a window by `start_utc_ms`;
    - a prediction by `track_id` + `revision`.
- **Emitter id format:** `dtv:<facility_id>:<rf_channel>:<MHz>`. `carrier_frequency_hz` and `rf_channel` are also given as numbers, so consumers need not parse it.
- **`summary`:** optional and **off by default**. It is a debugging aid, enabled only at CT startup (`cue_prediction.include_summary` or `--cue-include-summary`). When enabled, it is present in every opportunity of that run (§1.2).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/track-cue-2.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "message_type",
    "message_id",
    "source",
    "source_instance_id",
    "sequence_number",
    "generated_utc_ms",
    "snapshot_id",
    "track",
    "prediction",
    "models",
    "opportunities"
  ],
  "properties": {
    "schema_version": {
      "const": "2.0.0"
    },
    "message_type": {
      "const": "track_cue"
    },
    "message_id": {
      "type": "string",
      "format": "uuid"
    },
    "source": {
      "const": "ADSBConsoleApp"
    },
    "source_instance_id": {
      "type": "string",
      "minLength": 1
    },
    "sequence_number": {
      "type": "integer",
      "minimum": 1
    },
    "generated_utc_ms": {
      "type": "integer",
      "minimum": 0
    },
    "snapshot_id": {
      "type": [
        "string",
        "null"
      ]
    },
    "track": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "track_id",
        "icao",
        "callsign",
        "status",
        "last_report_utc_ms",
        "report_age_s",
        "state"
      ],
      "properties": {
        "track_id": {
          "type": "string",
          "minLength": 1
        },
        "icao": {
          "type": "string",
          "pattern": "^[0-9A-F]{6}$"
        },
        "callsign": {
          "type": [
            "string",
            "null"
          ]
        },
        "status": {
          "enum": [
            "active",
            "stale",
            "purged",
            "invalid"
          ]
        },
        "last_report_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "report_age_s": {
          "type": "number",
          "minimum": 0
        },
        "state": {
          "$ref": "#/$defs/state"
        }
      }
    },
    "prediction": {
      "$ref": "#/$defs/prediction"
    },
    "models": {
      "$ref": "#/$defs/models"
    },
    "opportunities": {
      "type": "array",
      "items": {
        "$ref": "#/$defs/opportunity"
      }
    }
  },
  "$defs": {
    "vector3": {
      "type": "array",
      "items": {
        "type": "number"
      },
      "minItems": 3,
      "maxItems": 3
    },
    "state": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "epoch_utc_ms",
        "reference_frame",
        "reference_origin_id",
        "position_enu_m",
        "velocity_enu_mps",
        "latitude_deg",
        "longitude_deg",
        "altitude_m_msl",
        "ground_speed_mps",
        "track_angle_deg",
        "vertical_rate_mps",
        "quality"
      ],
      "properties": {
        "epoch_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "reference_frame": {
          "const": "ENU"
        },
        "reference_origin_id": {
          "type": "string",
          "minLength": 1
        },
        "position_enu_m": {
          "$ref": "#/$defs/vector3"
        },
        "velocity_enu_mps": {
          "$ref": "#/$defs/vector3"
        },
        "latitude_deg": {
          "type": "number",
          "minimum": -90,
          "maximum": 90
        },
        "longitude_deg": {
          "type": "number",
          "minimum": -180,
          "maximum": 180
        },
        "altitude_m_msl": {
          "type": "number"
        },
        "ground_speed_mps": {
          "type": [
            "number",
            "null"
          ]
        },
        "track_angle_deg": {
          "type": [
            "number",
            "null"
          ]
        },
        "vertical_rate_mps": {
          "type": [
            "number",
            "null"
          ]
        },
        "quality": {
          "$ref": "#/$defs/quality"
        }
      }
    },
    "quality": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "vertical_rate_assumed",
        "horizontal_velocity_estimated",
        "position_valid",
        "velocity_valid"
      ],
      "properties": {
        "vertical_rate_assumed": {
          "type": "boolean"
        },
        "horizontal_velocity_estimated": {
          "type": "boolean"
        },
        "position_valid": {
          "type": "boolean"
        },
        "velocity_valid": {
          "type": "boolean"
        }
      }
    },
    "prediction": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "revision",
        "created_utc_ms",
        "valid_until_utc_ms",
        "horizon_s",
        "sample_interval_s",
        "motion_model",
        "maturity",
        "update_reason",
        "validation"
      ],
      "properties": {
        "revision": {
          "type": "integer",
          "minimum": 1
        },
        "created_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "valid_until_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "horizon_s": {
          "type": "number",
          "exclusiveMinimum": 0
        },
        "sample_interval_s": {
          "type": "number",
          "exclusiveMinimum": 0
        },
        "motion_model": {
          "const": "constant_velocity_enu"
        },
        "maturity": {
          "enum": [
            "initial",
            "stabilizing",
            "stable",
            "invalid"
          ]
        },
        "update_reason": {
          "enum": [
            "initial_track",
            "track_maneuver",
            "prediction_error",
            "periodic_refresh",
            "observer_configuration_change",
            "emitter_configuration_change",
            "application_snapshot"
          ]
        },
        "validation": {
          "$ref": "#/$defs/validation"
        }
      }
    },
    "validation": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "position_error_m",
        "position_error_threshold_m",
        "velocity_error_mps",
        "velocity_error_threshold_mps",
        "heading_change_deg",
        "heading_change_threshold_deg"
      ],
      "properties": {
        "position_error_m": {
          "type": [
            "number",
            "null"
          ]
        },
        "position_error_threshold_m": {
          "type": [
            "number",
            "null"
          ]
        },
        "velocity_error_mps": {
          "type": [
            "number",
            "null"
          ]
        },
        "velocity_error_threshold_mps": {
          "type": [
            "number",
            "null"
          ]
        },
        "heading_change_deg": {
          "type": [
            "number",
            "null"
          ]
        },
        "heading_change_threshold_deg": {
          "type": [
            "number",
            "null"
          ]
        }
      }
    },
    "models": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "bistatic_range_definition",
        "doppler_source",
        "doppler_sign_convention",
        "snr_model_id",
        "assumed_rcs_dbsm",
        "detection_threshold_db"
      ],
      "properties": {
        "bistatic_range_definition": {
          "const": "tx_target_plus_target_rx_minus_tx_rx"
        },
        "doppler_source": {
          "const": "analytic_derivative_of_bistatic_range"
        },
        "doppler_sign_convention": {
          "const": "positive_for_decreasing_bistatic_path"
        },
        "snr_model_id": {
          "type": "string",
          "minLength": 1
        },
        "assumed_rcs_dbsm": {
          "type": "number"
        },
        "detection_threshold_db": {
          "type": "number"
        }
      }
    },
    "opportunity": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "observer_id",
        "emitter_id",
        "carrier_frequency_hz",
        "rf_channel",
        "current",
        "windows"
      ],
      "properties": {
        "observer_id": {
          "type": "string",
          "minLength": 1
        },
        "emitter_id": {
          "type": "string",
          "minLength": 1
        },
        "carrier_frequency_hz": {
          "type": "number",
          "exclusiveMinimum": 0
        },
        "rf_channel": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 2,
          "maximum": 69
        },
        "current": {
          "$ref": "#/$defs/sample"
        },
        "windows": {
          "type": "array",
          "minItems": 1,
          "items": {
            "$ref": "#/$defs/window"
          }
        },
        "summary": {
          "$ref": "#/$defs/summary"
        }
      }
    },
    "sample": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "time_offset_s",
        "sample_utc_ms",
        "bistatic_range_m",
        "bistatic_range_rate_mps",
        "bistatic_doppler_hz",
        "predicted_bistatic_snr_db",
        "geometrically_visible",
        "rf_available",
        "within_range_limits",
        "within_doppler_limits",
        "above_snr_threshold",
        "usable"
      ],
      "properties": {
        "time_offset_s": {
          "type": "number"
        },
        "sample_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "bistatic_range_m": {
          "type": "number",
          "minimum": 0
        },
        "bistatic_range_rate_mps": {
          "type": "number"
        },
        "bistatic_doppler_hz": {
          "type": "number"
        },
        "predicted_bistatic_snr_db": {
          "type": "number"
        },
        "geometrically_visible": {
          "type": "boolean"
        },
        "rf_available": {
          "type": "boolean"
        },
        "within_range_limits": {
          "type": "boolean"
        },
        "within_doppler_limits": {
          "type": "boolean"
        },
        "above_snr_threshold": {
          "type": "boolean"
        },
        "usable": {
          "type": "boolean"
        }
      }
    },
    "window": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "start_utc_ms",
        "end_utc_ms",
        "duration_s",
        "entry_reason",
        "exit_reason",
        "min_bistatic_range_m",
        "max_bistatic_range_m",
        "min_bistatic_range_rate_mps",
        "max_bistatic_range_rate_mps",
        "min_bistatic_doppler_hz",
        "max_bistatic_doppler_hz",
        "maximum_abs_doppler_rate_hzps",
        "min_snr_db",
        "mean_snr_db",
        "max_snr_db",
        "peak_snr_utc_ms"
      ],
      "properties": {
        "start_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "end_utc_ms": {
          "type": "integer",
          "minimum": 0
        },
        "duration_s": {
          "type": "number",
          "minimum": 0
        },
        "entry_reason": {
          "enum": [
            "prediction_start_inside_usable",
            "prediction_horizon",
            "geometric_visibility",
            "rf_availability",
            "bistatic_range_limit",
            "doppler_limit",
            "snr_threshold",
            "state_transition"
          ]
        },
        "exit_reason": {
          "enum": [
            "prediction_start_inside_usable",
            "prediction_horizon",
            "geometric_visibility",
            "rf_availability",
            "bistatic_range_limit",
            "doppler_limit",
            "snr_threshold",
            "state_transition"
          ]
        },
        "min_bistatic_range_m": {
          "type": "number"
        },
        "max_bistatic_range_m": {
          "type": "number"
        },
        "min_bistatic_range_rate_mps": {
          "type": "number"
        },
        "max_bistatic_range_rate_mps": {
          "type": "number"
        },
        "min_bistatic_doppler_hz": {
          "type": "number"
        },
        "max_bistatic_doppler_hz": {
          "type": "number"
        },
        "maximum_abs_doppler_rate_hzps": {
          "type": [
            "number",
            "null"
          ],
          "minimum": 0
        },
        "min_snr_db": {
          "type": "number"
        },
        "mean_snr_db": {
          "type": "number"
        },
        "max_snr_db": {
          "type": "number"
        },
        "peak_snr_utc_ms": {
          "type": "integer",
          "minimum": 0
        }
      }
    },
    "summary": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "has_usable_window",
        "next_window_start_utc_ms",
        "next_window_end_utc_ms",
        "total_usable_duration_s",
        "maximum_snr_db",
        "maximum_snr_utc_ms",
        "minimum_bistatic_range_m",
        "maximum_bistatic_range_m",
        "minimum_bistatic_doppler_hz",
        "maximum_bistatic_doppler_hz"
      ],
      "properties": {
        "has_usable_window": {
          "type": "boolean"
        },
        "next_window_start_utc_ms": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 0
        },
        "next_window_end_utc_ms": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 0
        },
        "total_usable_duration_s": {
          "type": "number",
          "minimum": 0
        },
        "maximum_snr_db": {
          "type": [
            "number",
            "null"
          ]
        },
        "maximum_snr_utc_ms": {
          "type": [
            "integer",
            "null"
          ],
          "minimum": 0
        },
        "minimum_bistatic_range_m": {
          "type": [
            "number",
            "null"
          ]
        },
        "maximum_bistatic_range_m": {
          "type": [
            "number",
            "null"
          ]
        },
        "minimum_bistatic_doppler_hz": {
          "type": [
            "number",
            "null"
          ]
        },
        "maximum_bistatic_doppler_hz": {
          "type": [
            "number",
            "null"
          ]
        }
      }
    }
  }
}
```

### 2.4 `track_cue_withdrawal`

This tells receivers to drop a track's cue. Only `reason: "track_purged"` is emitted today. Tracks that go stale are not withdrawn until they are purged (see CR-6), so consumers must also judge staleness from `track.report_age_s` and `prediction.valid_until_utc_ms`.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://passive-radar.local/schemas/track-cue-withdrawal-2.0.0.json",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "message_type",
    "message_id",
    "source",
    "source_instance_id",
    "sequence_number",
    "generated_utc_ms",
    "track_id",
    "icao",
    "withdrawn_prediction_revision",
    "reason"
  ],
  "properties": {
    "schema_version": {
      "const": "2.0.0"
    },
    "message_type": {
      "const": "track_cue_withdrawal"
    },
    "message_id": {
      "type": "string",
      "format": "uuid"
    },
    "source": {
      "const": "ADSBConsoleApp"
    },
    "source_instance_id": {
      "type": "string",
      "minLength": 1
    },
    "sequence_number": {
      "type": "integer",
      "minimum": 1
    },
    "generated_utc_ms": {
      "type": "integer",
      "minimum": 0
    },
    "track_id": {
      "type": "string",
      "minLength": 1
    },
    "icao": {
      "type": "string",
      "pattern": "^[0-9A-F]{6}$"
    },
    "withdrawn_prediction_revision": {
      "type": "integer",
      "minimum": 1
    },
    "reason": {
      "type": "string",
      "minLength": 1
    }
  }
}
```

### 2.5 CT configuration file

This is not a wire message. `cue-config-2.0.0.json` validates the JSON config that `ADSBConsoleApp --cue-config` loads, with sections `publication_mode`, `cue_prediction` and `udp_output`. Relative to 1.1.0:

- **Added:** `cue_prediction.include_summary`, and `udp_output.encoding`, `dictionary_id` and `maximum_opportunities_per_cue`.
- **Removed:** `udp_output.oversize_policy`, because fit-to-frame (§2.0) replaces it.

The Activity Manager's `system_config.json` should generate or point to this file.

### 2.6 CT open items

| # | Item | Status |
|---|---|---|
| CT-1 … CT-10 | The 1.1.0 release items (Draft A of this ICD) | Closed: released in 1.1.0, which was Verified live on 2026-09-26 (CR-3). CT-9, the datagram size, is superseded by fit-to-frame (§2.0) and compression (§1.3) |
| CT-11 | 2.0.0 released and Verified: implementation, then a live capture meeting the WI-7 criteria, then the per-opportunity size recorded | Open |
| CT-12 | Stale tracks are withdrawn only when purged | Open, CR-6 |
| CT-13 | Revision comparison across CT restarts | Open, CR-4 |

### 2.7 Version history

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-09-08 | First CT schemas |
| 1.1.0 | 2026-09-25 | Typed every sub-object of `track_cue`; split the snapshot schema into begin and end; dropped `implemented_observers`; `rf_channel` integer or null; heartbeat statuses; only usable opportunities sent. Verified 2026-09-26 |
| **2.0.0** | 2026-09-26 | CR-5, breaking changes: |
| | | – **framing:** plain or deflate-with-dictionary (§1.3); |
| | | – **times:** every `*_utc` string became a `*_utc_ms` integer; |
| | | – **values:** rounded to the §1.2 resolutions; |
| | | – **`models`:** moved to the top of `track_cue` (it was repeated in every opportunity); |
| | | – **removed:** `prediction.prediction_id`, and from opportunities `opportunity_id`, `observer_name`, `transmitter_site_id`, `emitter_enabled`, `observer_can_receive` and `history`, and `windows[].window_id`; |
| | | – **`summary`:** optional and off by default; |
| | | – **`current`:** always an object, and `windows` has at least one entry; |
| | | – **every property required**, apart from the optional `summary`; |
| | | – **fit-to-frame** opportunity selection, up to 8; |
| | | – **config:** `cue-config-2.0.0` |

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
        "observer_id": { "type": "string" }, "emitter_id": { "type": "string" },
        "window_start_utc_ms": { "type": "integer" } } },
    "start_utc_ms": { "type": "integer", "minimum": 0 },
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
  "required": ["message_type", "task_id", "observer_id", "reason", "start_utc_ms", "duration_s",
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
    "deadline_utc_ms": { "type": ["integer", "null"], "minimum": 0 }
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
    "measured_utc_ms": { "type": "integer", "minimum": 0 },
    "az_true_deg": { "type": ["number", "null"] },
    "tilt_deg": { "type": ["number", "null"] },
    "field_strength_ut": { "type": ["number", "null"] },
    "field_strength_ok": { "type": "boolean" },
    "tilt_ok": { "type": "boolean" },
    "moving": { "type": "boolean" },
    "command_state": { "enum": ["idle", "moving", "settled", "fault"] },
    "fault_code": { "type": ["string", "null"] },
    "node_last_heard_utc_ms": { "type": ["integer", "null"], "minimum": 0 }
  },
  "required": ["message_type", "antenna", "measured_utc_ms", "az_true_deg", "moving", "command_state"]
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
    "start_utc_ms": { "type": "integer", "minimum": 0 },
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
  "required": ["message_type", "task_id", "observer_id", "file_path", "start_utc_ms", "status"],
  "$defs": { "antennaSnapshot": { "type": "object", "properties": {
      "az_true_deg": { "type": ["number", "null"] }, "field_strength_ok": { "type": "boolean" },
      "tilt_ok": { "type": "boolean" }, "node_last_heard_utc_ms": { "type": ["integer", "null"], "minimum": 0 } } } }
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
    "earliest_utc_ms": { "type": "integer", "minimum": 0 },
    "latest_utc_ms": { "type": "integer", "minimum": 0 },
    "priority": { "type": "integer", "minimum": 0, "maximum": 9 },
    "estimated_duration_s": { "type": "number" }
  },
  "required": ["message_type", "request_id", "cal_type", "earliest_utc_ms", "latest_utc_ms", "priority"]
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
      "required": ["cpi_utc_ms", "bistatic_range_m", "bistatic_doppler_hz", "snr_db"],
      "properties": {
        "cpi_utc_ms": { "type": "integer", "minimum": 0 },
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
      "required": ["track_id", "observer_id", "emitter_id", "time_utc_ms", "state", "status"],
      "properties": {
        "track_id": { "type": "string" },
        "observer_id": { "type": "string" },
        "emitter_id": { "type": "string" },
        "time_utc_ms": { "type": "integer", "minimum": 0 },
        "state": { "type": "object", "properties": {
            "bistatic_range_m": { "type": "number" }, "bistatic_range_rate_mps": { "type": "number" } } },
        "covariance": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } },
        "status": { "enum": ["tentative", "confirmed", "coasting", "deleted"] },
        "associated_icao": { "type": ["string", "null"], "pattern": "^[0-9A-F]{6}$" },
        "associated_ct_track_id": { "type": ["string", "null"] },
        "next_update_due_utc_ms": { "type": ["integer", "null"], "minimum": 0 } } } }
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
