# CT Cue Traffic: Labels vs Values, and Encoding Options

**Date:** 2026-09-26. **Status:** analysis for decision (owner: Leif). **Relates to:** [ICD_Messages.md](../ICD_Messages.md) §1.2 (encoding), §1.3 (transport) and §2.3 (`track_cue`); [CR-1 and CR-5](../Change_Requests.md).

**Question:** the multicast cue traffic looks like it is mostly JSON field names. Should the ADSB Cue Tasker (CT) compress it, move to a compact "mirror" schema with very short labels, or leave JSON altogether?

**Short answer:**
- Most of the bytes are field names and punctuation. What matters on this network is fitting each datagram into one Ethernet frame, not bandwidth.
- Several options get there. Leaving JSON buys almost nothing over compressed, compact JSON.
- The choice is yours; the questions to settle are at the end.

## Data

- **Capture:** [`evidence/cue_traffic_20260926T1234Z.jsonl`](../evidence/cue_traffic_20260926T1234Z.jsonl).
  - 46 datagrams recorded with socat on the RF Collection Desktop from `239.192.10.1:31986`, 12:34:33–12:38:23 UTC (230 s).
  - CT 1.1.0 with the top-3 opportunity cap: 24 heartbeats, 14 `track_cue` for one aircraft (A7946A), and 4 snapshot pairs.
- **Exact accounting:** every message re-serializes byte-for-byte as compact, key-sorted JSON, so each byte is attributed exactly once.
- **Dictionary source:** the preset-dictionary option uses a dictionary taken from a *different* capture ([`cue_traffic_20260926T0050Z.jsonl`](../evidence/cue_traffic_20260926T0050Z.jsonl): other aircraft, 12 hours earlier), so its result is out of sample.
- **Reproduce:** `python3 analysis/analyze_cue_traffic.py` for the tables, and `check_matlab_decompress.m` in MATLAB for the decode check.

## Where the bytes go

| Message | Field names | JSON syntax | Schema constants | Config constants | Derivable | Excess digits | **Information** | Bytes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| all messages | **44.2%** | 14.0% | 4.6% | 2.4% | 8.5% | 8.9% | **17.3%** | 125 875 |
| `track_cue` | 44.8% | 13.8% | 4.7% | 2.2% | 8.6% | 10.1% | 15.9% | 111 579 |
| `cue_heartbeat` | 41.5% | 16.0% | 4.0% | 4.5% | 7.7% | 0.0% | 26.4% | 11 280 |

- **58% of the bytes are field names and punctuation.** There are 118 distinct field names averaging 15.3 characters; the longest is `maximum_abs_doppler_rate_hzps`. No single label dominates (the largest is 1.1% of the traffic). The cost comes from many long names repeated many times.
- **The opportunities are the bulk.** They make up 81% of a `track_cue`: 3 × about 2.15 kB, each repeating about 40 field names. Within one opportunity:
  - `windows` 675 B
  - `summary` 429 B
  - `current` 378 B
  - ids and flags 328 B
  - `models` 280 B, which is **identical in every opportunity**
- **A quarter of the value bytes carry no information:**
  - **Schema or configuration constants:** `source`, the model conventions, `observer_id`, `horizon_s`, and so on.
  - **Derivable fields:**
    - `track_id` = `"adsb:"` + `icao`
    - `prediction_id`
    - `opportunity_id`
    - `window_id`
    - `carrier_frequency_hz` and `rf_channel`, which are both inside `emitter_id`
    - `summary.next_window_*`, which is `windows[0]`
    - `duration_s`
    - `message_id`, because `source_instance_id` + `sequence_number` are already unique
  - **Excess float digits:** full 17-digit doubles such as `-258.95142778748794` for a Doppler whose useful resolution is 0.1 Hz.
- **Information content is about 17%**, and it is roughly the same for every option below.

## Does the size matter here?

- **Bandwidth: no.**
  - This capture averaged 547 B/s.
  - A busy sky of 100 cued aircraft needs about 13 kB/s for the 60 s snapshots plus about 27 kB/s for per-track refreshes (at least one every 30 s).
  - That totals about 40 kB/s, or 0.3 Mbit/s: under 0.1% of the 1 GbE data network.
- **Datagram size: yes.**
  - **Fragmentation:** an 8 kB `track_cue` goes out as 6 IP fragments. Losing any one fragment loses the whole cue.
  - **Burst size:** a 100-aircraft snapshot is about 800 kB arriving within milliseconds, which already needed an 8 MiB receive buffer.
  - **The cap:** the 16 KiB `maximum_datagram_bytes` limit is what forced the top-3 opportunity cap (CR-1).
  - A cue that fits one frame (1472 B of UDP payload) avoids fragmentation entirely and would allow more opportunities per cue.
- **Decode cost: no.** MATLAB `jsondecode` takes about 0.3 ms per cue. Decompression adds 0.1–0.4 ms.
- **Precedent:** the ICD already uses short keys where size is a hard limit (ESP-NOW, 250 B, ICD §3.4).

## Options measured

Sizes are in bytes. The cue and heartbeat columns are medians; the total is for the whole capture. "> 1 frame" counts datagrams over 1472 B.

| # | Encoding | `track_cue` | heartbeat | Capture total | vs JSON | > 1 frame |
|---|---|---:|---:|---:|---:|---:|
| 0 | JSON as sent (CT 1.1.0) | 7 962 | 470 | 125 875 | 100% | 14 of 46 |
| 1 | JSON + gzip per datagram | 1 984 | 321 | 37 767 | 30% | 14 of 46 |
| 2 | JSON + raw deflate with a preset dictionary | **987** | 116 | 17 695 | 14% | **0** |
| 3 | Full field names, trimmed values | 4 247 | 259 | 67 868 | 54% | 14 of 46 |
| 4 | Short keys (1–2 letters), values unchanged | 4 705 | 296 | 75 169 | 60% | 14 of 46 |
| 5 | Compact mirror: short keys + trimmed values | 1 984 | 149 | 32 822 | 26% | 14 of 46 |
| 6 | Compact mirror + gzip | **726** | 139 | 14 800 | 12% | **0** |
| 7 | Positional JSON arrays (no keys) + trimmed values | 1 331 | 117 | 22 692 | 18% | 0 |
| 8 | Packed binary + trimmed values (estimate) | 893 | 100 | 16 067 | 13% | 0 |

- **"Trimmed values"** means: drop schema and configuration constants and derivable fields (keeping `observer_id` for a future second station); round to engineering resolution (lat/lon 1e-6°, other angles 0.1°, metres to 1 m, m/s 0.1, Hz 0.1, dB 0.1); and send times as integer epoch milliseconds.
- **Short keys:** the 1–2 letter keys are a lower bound. Readable 2–4 letter mnemonics cost roughly 10–15% more.

| # | MATLAB decode | Human-readable on the wire | JSON Schema validation | Schema change | Notes |
|---|---|---|---|---|---|
| 0 | `jsondecode` | yes (`socat … \| jq`) | yes | none | Every cue is fragmented. |
| 1 | Java `GZIPInputStream`, verified | after one decode step | yes, after decode | none (transport only) | Doesn't fit a frame; gzip's header and lack of shared context waste most of the gain on small messages. |
| 2 | Java `Inflater.setDictionary`, verified | after one decode step | yes, after decode | none; the dictionary becomes a versioned artifact | Sender and receivers must hold the same dictionary; a 1-byte encoding/dictionary id per datagram handles versioning. |
| 3 | `jsondecode` | yes | yes | yes (new versions: drops fields, rounds) | The value cleanup alone saves more than short keys alone. |
| 4 | `jsondecode` + rename via codebook | with the codebook | yes (mirror schema) | new mirror schema + codebook | Label shortening alone only reaches 60%. |
| 5 | as 4 | with the codebook | yes (mirror schema) | new message versions (content and labels) | |
| 6 | as 4, plus Java gzip | after decode | yes | as 5 | Smallest measured. |
| 7 | `jsondecode` + index map | poor | awkward (`prefixItems`) | field **order** becomes the contract | Fragile to schema evolution; only a small margin under 1 frame. |
| 8 | `typecast`, custom parser | no | no | custom codec on both sides | About the same size as 6, while losing JSON tooling, schema validation and readability. |

## Observations for the decision

1. **Labels alone are not the whole story.** Shortening keys (option 4) reaches 60%, and cleaning up values (option 3) reaches 54%. You need both (option 5, 26%) or compression to get far.
2. **Only compression or a binary layout fits a cue in one frame.**
   - Options 2 and 6 both get there.
   - **Option 2 needs no schema change at all.** The JSON 1.1.0 schema stays the logical contract, and logs and validation work unchanged after a decode step.
   - **Option 6 is the smallest**, but it needs a mirror schema, a codebook, and content decisions.
3. **Leaving JSON is not supported by the numbers.** Packed binary (option 8) is about the same size as compressed compact JSON (option 6). It gives up `jsondecode`, JSON Schema validation, `socat | jq` debugging and easy schema evolution, and needs a hand-written codec on both sides.
4. **Value cleanup is worth doing whatever the encoding.** It is also a matter of ICD content. Candidates for the next CT schema revision:
   - move `models` into a static per-emitter configuration message;
   - drop derivable ids and `summary.next_window_*`;
   - send `message_id` only if de-duplication beyond `source_instance_id` + `sequence_number` is needed;
   - round floats to the resolutions above.
5. **A hybrid is possible.** Keep JSON as the logical format and add a 1-byte encoding tag on the wire (`0` = plain JSON, `1` = deflate with dictionary v1). CueListener and `cue_capture.py` decode, then validate against the unchanged schema. Keeping `0` available preserves plain-text debugging.

**Questions for the owner:**
- **(a)** Is one-frame delivery a requirement? If so, compression or binary is required.
- **(b)** Is plain-text readability on the wire a requirement? If so, options 0, 3 and 5, or the hybrid tag above.
- **(c)** Are the value clean-ups in item 4 acceptable as ICD changes?
- **(d)** Would you accept a versioned preset dictionary as a controlled artifact alongside the schemas?
