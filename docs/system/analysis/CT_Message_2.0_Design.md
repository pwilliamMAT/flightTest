# CT Cue Messages: Compressed JSON and Value Clean-up (design for approval)

**Date:** 2026-09-26. **Status:** **approved** 2026-09-26 (Leif), with the answers in §6. Next: edit the ICD (CR-5), then implement.
**Decision it implements:** CR-5, accepted in direction by Leif on 2026-09-26: keep JSON, add a fixed preset deflate dictionary, and clean up the values.
**Drivers:** mainline MATLAB compatibility, deployment as compiled MATLAB apps, and one-frame delivery.
**Evidence:** [Cue_Traffic_Encoding.md](Cue_Traffic_Encoding.md), [check_matlab_decompress.m](check_matlab_decompress.m), [deployability/](deployability/).

## 1. Summary

| | `track_cue` (median) | `cue_heartbeat` | Fits one frame |
|---|---:|---:|---|
| Today: JSON 1.1.0 | 7 962 B | 470 B | no (6 IP fragments) |
| Proposed: JSON 2.0.0, plain | 4 528 B | 450 B | no (development and debugging only) |
| **Proposed: JSON 2.0.0 + 2-byte header + deflate with dictionary** | **536 B** | **115 B** | **yes** |

- **Per opportunity:** each extra opportunity adds about 63 B compressed. One frame (1472 B) would hold about 18 instead of today's fixed cap of 3. That is an estimate from a single-aircraft capture, to be checked on a busier one.
- **Mainline MATLAB and compiled apps:** decoding uses only `jsondecode`, `java.util.zip` and `java.net` (Java 8). This was verified in a MATLAB Compiler standalone app on the MATLAB Runtime, which needed only the base, standard and graphics runtime add-ons (see [deployability/](deployability/)).

## 2. Wire framing (ICD §1.3)

Every datagram is one of:

| First byte | Contents |
|---|---|
| `{` (0x7B) | Plain UTF-8 JSON, exactly as today. Kept for development, debugging and fallback. |
| `0xDC` | Compressed. Byte 1 is the **dictionary id** (1–255). Bytes 2 onward are raw deflate (RFC 1951; no zlib or gzip header) of the UTF-8 JSON message, compressed with the preset dictionary of that id. |

- **Who decides the framing:**
  - **The sender decides once, at startup.** CT reads `udp_output.encoding` and `udp_output.dictionary_id` from its cue config when it starts; a command-line flag can override them for a debug run. Every datagram in that run uses the same framing, and changing it means a restart, which gives receivers a new `source_instance_id`. The deployed service uses `deflate_dictionary`; development and troubleshooting runs use `json`.
  - **Receivers decide per datagram,** from the first byte, and need no configuration. They therefore also handle mixed streams, such as a plain-JSON bench instance alongside the compressed production one, or a dictionary rollout.
- **Unknown first bytes or dictionary ids:** receivers count them and drop the datagram. The schema check runs after decoding, so every tool validates the same JSON either way.
- **CT configuration:**
  - `udp_output.encoding`: `json` or `deflate_dictionary`;
  - `udp_output.dictionary_id`;
  - `udp_output.maximum_datagram_bytes`: the default becomes **1472** (one Ethernet frame).
- **Fit to frame, replacing the fixed top-3 cap (CR-1):**
  - CT encodes the cue with up to `maximum_opportunities_per_cue` opportunities, strongest first (default 8, an upper bound).
  - While the datagram is over `maximum_datagram_bytes`, CT drops the lowest-ranked opportunity and encodes again.
  - A cue that won't fit even with no opportunities counts as oversize, and the heartbeat reports it.

## 3. The dictionary as a controlled artifact

- **Where:** ADSB-remoter `schemas/dictionaries/cue-dictionary-<id>.bin`, alongside the CT schemas as the ICD already places them, with a `.sha256` file. At most 32 768 bytes.
- **How it is built:** reproducibly, by a tool (`tools/build_cue_dictionary.py`) from a named corpus of real 2.0.0 messages. The tool is committed, and the corpus is kept in `docs/system/evidence/`.
- **Immutable once released.** A changed dictionary gets a new id through a CR. The ICD lists every released id with its SHA-256.
- **Consumers ship every released dictionary.** A compiled app adds them as `AdditionalFiles`.

## 4. Value clean-up (message content)

**Version: 2.0.0, not 1.2.0.** ICD §1.2 requires a major bump when a change breaks existing readers, and removing or renaming fields does.

| # | Change | Why |
|---|---|---|
| a | Every `*_utc` string becomes a `*_utc_ms` integer: milliseconds since 1970-01-01 UTC | MATLAB reads a number directly, and one vectorised `datetime(x/1000,'ConvertFrom','posixtime','TimeZone','UTC')` replaces per-field string parsing; half the characters. Exact in a double until the year 287 000 |
| b | CT rounds values to a resolution per unit: lat/lon 1e-6°, other angles 0.1°, metres 1, m/s 0.1, Hz 0.1, Hz/s 0.001, dB 0.1, seconds 0.1 | Removes 17-digit doubles; the resolutions become part of the ICD |
| c | `models` appears once per `track_cue` at the top level, instead of in every opportunity | It is identical for every opportunity today |
| d | `summary` becomes **optional and off by default**. It is enabled only at CT startup, for debugging (`cue_prediction.include_summary`). Removed from each opportunity: `history` (always null on the wire), `emitter_enabled` and `observer_can_receive` (always true, since CT sends only those), `opportunity_id` (= `observer_id:emitter_id`), `observer_name` and `transmitter_site_id` (configuration lookups) | Derivable, constant, or never sent |
| e | Removed: `prediction.prediction_id` (= `track_id:r<revision>`) and `windows[].window_id` (a window is identified by its start time) | Derivable |
| f | **Kept:** the ICD envelope including `message_id`; `track_id`; `icao`; `carrier_frequency_hz` and `rf_channel` (numbers, so MATLAB needn't parse `emitter_id`); ENU position and velocity; `current`; `windows[].duration_s` | Useful to consumers, and cheap after compression |
| g | New ICD §1.2 rules for MATLAB consumers: | `jsondecode` then returns the same struct shapes every time, which compiled apps rely on |
|   | – within one CT run, a message type always has the same shape: every property present in every message. Startup options such as `include_summary` fix the shape for the whole run; | |
|   | – no field is null in some messages and an object or array in others; | |
|   | – arrays of objects always have identical keys; | |
|   | – `current` is always an object; | |
|   | – field names are valid MATLAB identifiers of at most 63 characters. | |
| h | ICD §3.1 `collection_task.cue_ref` becomes `track_id`, `prediction_revision`, `observer_id`, `emitter_id` and `window_start_utc_ms` | Follows (d) and (e); §3 is still Proposed |

## 5. Migration

There is only one consumer today (CueListener), so everything switches at once:

- **CT:**
  - emits 2.0.0, with `encoding` defaulting to `json` in the example config and `deflate_dictionary` in `deploy/pi-cue-config.json`;
  - 2.0.0 schemas; 1.1.0 moves to `schemas/archive/`.
- **Consumers:** `tools/cue_capture.py` and CueListener accept both framings and validate or decode 2.0.0.
- **Verification:** a capture meeting the WI-7 criteria (3 full snapshots, 0 schema failures, no gaps), ideally with several aircraft, moves the 2.0.0 messages to Verified. It also records the real per-opportunity size.

## 6. Decisions (Leif, 2026-09-26)

1. **Version 2.0.0.**
2. **Epoch-millisecond times everywhere:** in all ICD messages (the §1.2 convention), not only the CT ones.
3. **`summary` is off by default**, enabled explicitly at startup for debugging only.
4. **Fit-to-frame with an upper bound of 8 opportunities.** The towers nearest the observer are the strongest, so the distant ones will rarely make the cut anyway.
5. **Dictionary master in ADSB-remoter `schemas/dictionaries/`,** listed in the ICD by id and SHA-256.

Framing: the sender chooses it at startup; receivers detect it per datagram (§2).

### Points as originally proposed

1. Version **2.0.0**, as ICD §1.2 requires for breaking changes, or keep the "1.2" label anyway?
2. Epoch-millisecond times (4a) for **all** ICD messages, or for the CT messages only?
3. Drop `summary` entirely (4d)? Its horizon-wide extents (minimum/maximum bistatic range and Doppler over the whole prediction, not just the windows) would be lost. Nothing consumes them today.
4. Fit-to-frame shedding with an upper bound of 8, replacing the fixed top-3 cap?
5. Dictionary master in ADSB-remoter `schemas/dictionaries/`, listed by id and SHA-256 in the ICD?
