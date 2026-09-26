"""Where do the bytes of the CT cue stream go, and how small could the messages be?

Usage:
    python3 analyze_cue_traffic.py [capture] [dictionary-training-capture]

Defaults to the two captures in ../evidence. A capture is either raw concatenated
datagrams (socat output) or one JSON message per line; lines wrapped by
ADSB-remoter tools/cue_capture.py ({"payload": ...}) are unwrapped.

Every CT message re-serializes byte-for-byte as compact, key-sorted JSON (checked
below), so each byte on the wire is attributed to exactly one category:

    label             characters of field names
    syntax            quotes, colons, commas, braces and brackets
    schema_constant   values fixed by the schema (schema_version, source, model conventions)
    config_constant   values fixed by CT's configuration for the whole run
    derivable         values computable from other fields, always-true flags, and
                      message_id (redundant with source_instance_id + sequence_number)
    excess_precision  digits beyond an engineering resolution chosen per unit suffix
    value             everything else: the information content

Candidate encodings are then sized per message, including whether each datagram fits
one Ethernet frame (1472-byte UDP payload), which avoids IP fragmentation.
"""

from __future__ import annotations

import gzip
import json
import math
import statistics
import sys
import zlib
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_CAPTURE = HERE.parent / "evidence" / "cue_traffic_20260926T1234Z.jsonl"
DEFAULT_DICTIONARY_SOURCE = HERE.parent / "evidence" / "cue_traffic_20260926T0050Z.jsonl"
MTU_PAYLOAD = 1472

SCHEMA_CONSTANT_KEYS = {
    "schema_version", "source", "reference_frame", "motion_model",
    "bistatic_range_definition", "doppler_source", "doppler_sign_convention",
}
CONFIG_CONSTANT_KEYS = {
    "observer_id", "reference_origin_id", "snr_model_id", "assumed_rcs_dbsm",
    "detection_threshold_db", "horizon_s", "sample_interval_s", "udp_destination",
    "enabled_emitters", "active_observers",
}
DERIVABLE_KEYS = {
    "track_id",                # "adsb:" + icao
    "prediction_id",           # track_id + ":r" + revision
    "opportunity_id",          # observer_id + ":" + emitter_id
    "window_id",               # "w:" + start_utc
    "observer_name",           # configuration lookup from observer_id
    "carrier_frequency_hz",    # encoded in emitter_id "dtv:<facility>:<channel>:<MHz>"
    "rf_channel",              # encoded in emitter_id
    "transmitter_site_id",     # emitter-table lookup
    "position_enu_m",          # lat/lon/alt expressed in the named reference origin
    "duration_s",              # end_utc - start_utc
    "has_usable_window",       # len(windows) > 0
    "next_window_start_utc", "next_window_end_utc", "total_usable_duration_s",  # from windows[]
    "emitter_enabled", "observer_can_receive",  # always true: CT sends only these (ICD CT-9)
    "message_id",              # redundant with source_instance_id + sequence_number
}
CATEGORIES = ["label", "syntax", "schema_constant", "config_constant", "derivable",
              "excess_precision", "value"]


def resolution(key: str) -> float | None:
    """Engineering resolution chosen per unit suffix; None leaves the value unchanged."""
    if key in ("latitude_deg", "longitude_deg"):
        return 1e-6            # about 0.1 m
    for suffix, step in (("_deg", 0.1), ("_hzps", 0.001), ("_hz", 0.1), ("_mps", 0.1),
                         ("_m_msl", 1.0), ("_m", 1.0), ("_dbsm", 0.1), ("_db", 0.1), ("_s", 0.1)):
        if key.endswith(suffix):
            return step
    return None


def rounded(value: float, step: float | None) -> float | int:
    if step is None:
        return value
    decimals = max(0, round(-math.log10(step)))
    r = round(value / step) * step
    return int(round(r)) if decimals == 0 else round(r, decimals)


def dumps(value) -> bytes:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode()


def load(path: Path) -> list[tuple[dict, bytes]]:
    text = path.read_text(encoding="utf-8")
    decoder = json.JSONDecoder()
    out, i = [], 0
    while i < len(text):
        while i < len(text) and text[i] in " \r\n\t":
            i += 1
        if i >= len(text):
            break
        obj, j = decoder.raw_decode(text, i)
        raw = text[i:j]
        if isinstance(obj, dict) and "payload" in obj:
            obj = obj["payload"]
            raw = json.dumps(obj, separators=(",", ":"), sort_keys=True, ensure_ascii=False)
        out.append((obj, raw.encode()))
        i = j
    return out


def attribute(value, key: str, sink: Counter) -> None:
    if isinstance(value, dict):
        sink["syntax"] += 2 + max(len(value) - 1, 0)
        for k in sorted(value):
            sink["label"] += len(k.encode())
            sink["syntax"] += 3
            attribute(value[k], k, sink)
        return
    if isinstance(value, list):
        sink["syntax"] += 2 + max(len(value) - 1, 0)
        for item in value:
            attribute(item, key, sink)
        return
    n = len(json.dumps(value, ensure_ascii=False).encode())
    if isinstance(value, str):
        sink["syntax"] += 2
        n -= 2
    if key in SCHEMA_CONSTANT_KEYS:
        sink["schema_constant"] += n
    elif key in CONFIG_CONSTANT_KEYS:
        sink["config_constant"] += n
    elif key in DERIVABLE_KEYS:
        sink["derivable"] += n
    else:
        if isinstance(value, float):
            excess = n - len(json.dumps(rounded(value, resolution(key))))
            if excess > 0:
                sink["excess_precision"] += excess
                n -= excess
        sink["value"] += n


def utc_ms(text: str) -> int:
    return int(datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp() * 1000)


def trim(value, key: str = ""):
    """The compact 'mirror' content: drop constants and derivable fields (keeping observer_id
    for a second station), round to resolution, and send times as epoch milliseconds."""
    if isinstance(value, dict):
        return {k: trim(v, k) for k, v in value.items()
                if k not in SCHEMA_CONSTANT_KEYS | DERIVABLE_KEYS | {"models"}
                and (k not in CONFIG_CONSTANT_KEYS or k == "observer_id")}
    if isinstance(value, list):
        return [trim(x, key) for x in value]
    if isinstance(value, str) and key.endswith("_utc"):
        return utc_ms(value)
    if isinstance(value, float):
        return rounded(value, resolution(key))
    return value


def key_counts(messages) -> Counter:
    counts: Counter = Counter()

    def walk(v):
        if isinstance(v, dict):
            for k, x in v.items():
                counts[k] += 1
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
    for m in messages:
        walk(m)
    return counts


def short_codes(counts: Counter) -> dict[str, str]:
    """Shortest possible keys: 1-2 letters, most frequent field first (a lower bound;
    readable 2-4 letter mnemonics cost roughly 10-15% more)."""
    letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    codes = list(letters) + [a + b for a in letters for b in letters]
    return {k: codes[i] for i, (k, _) in enumerate(counts.most_common())}


def rename(value, codes):
    if isinstance(value, dict):
        return {codes[k]: rename(v, codes) for k, v in value.items()}
    if isinstance(value, list):
        return [rename(x, codes) for x in value]
    return value


def positional(value):
    """No keys at all: each object becomes an array in schema (sorted-key) order."""
    if isinstance(value, dict):
        return [positional(value[k]) for k in sorted(value)]
    if isinstance(value, list):
        return [positional(x) for x in value]
    return value


def packed_size(value, key: str = "") -> int:
    """Packed-binary estimate: float32 measurements (float64 lat/lon), int64 epoch ms,
    int32 integers, 1-byte bools/null, 16-byte UUIDs, length-prefixed strings, 1-byte counts."""
    if isinstance(value, dict):
        return sum(packed_size(v, k) for k, v in value.items())
    if isinstance(value, list):
        return 1 + sum(packed_size(x, key) for x in value)
    if value is None or isinstance(value, bool):
        return 1
    if isinstance(value, int):
        return 8 if key.endswith("_utc") else 4
    if isinstance(value, float):
        return 8 if key in ("latitude_deg", "longitude_deg") else 4
    if isinstance(value, str):
        return 16 if (len(value) == 36 and value.count("-") == 4) else 1 + len(value.encode())
    return 0


def main(capture: Path, dictionary_source: Path) -> None:
    pairs = load(capture)
    messages = [m for m, _ in pairs]
    for m, raw in pairs:
        assert json.dumps(m, separators=(",", ":"), sort_keys=True, ensure_ascii=False).encode() == raw
    first, last = messages[0]["generated_utc"], messages[-1]["generated_utc"]
    span_s = (utc_ms(last) - utc_ms(first)) / 1000
    total = sum(len(r) for _, r in pairs)
    types = Counter(m["message_type"] for m in messages)
    aircraft = {m["track"]["icao"] for m in messages if m["message_type"] == "track_cue"}
    print(f"Capture {capture.name}: {len(messages)} messages, {total} bytes over {span_s:.0f} s "
          f"({total / span_s:.0f} B/s); {dict(types)}; aircraft {sorted(aircraft)}")

    per_type: dict[str, Counter] = defaultdict(Counter)
    for m, raw in pairs:
        sink: Counter = Counter()
        attribute(m, "", sink)
        assert sum(sink.values()) == len(raw)
        per_type[m["message_type"]] += sink
        per_type["all messages"] += sink
    print("\n| Message | " + " | ".join(CATEGORIES) + " | bytes |")
    print("|---|" + "---:|" * (len(CATEGORIES) + 1))
    for t in ("all messages", "track_cue", "cue_heartbeat", "cue_snapshot_begin", "cue_snapshot_end"):
        sink = per_type[t]
        n = sum(sink.values())
        print(f"| {t} | " + " | ".join(f"{100 * sink[c] / n:.1f}%" for c in CATEGORIES) + f" | {n} |")

    trimmed = [trim(m) for m in messages]
    codes = short_codes(key_counts(messages))
    trimmed_codes = short_codes(key_counts(trimmed))
    dictionary = b"".join(raw for _, raw in load(dictionary_source))[-32768:]

    def deflate_with_dictionary(data: bytes) -> bytes:
        c = zlib.compressobj(9, zlib.DEFLATED, -15, 9, zlib.Z_DEFAULT_STRATEGY, dictionary)
        return c.compress(data) + c.flush()

    encodings = [
        ("JSON as sent (CT 1.1.0)", lambda m, t: dumps(m)),
        ("JSON + gzip per datagram", lambda m, t: gzip.compress(dumps(m), 9, mtime=0)),
        ("JSON + raw deflate, preset dictionary", lambda m, t: deflate_with_dictionary(dumps(m))),
        ("Full names, trimmed values", lambda m, t: dumps(t)),
        ("Short keys, values unchanged", lambda m, t: dumps(rename(m, codes))),
        ("Compact mirror: short keys + trimmed values", lambda m, t: dumps(rename(t, trimmed_codes))),
        ("Compact mirror + gzip", lambda m, t: gzip.compress(dumps(rename(t, trimmed_codes)), 9, mtime=0)),
        ("Positional JSON arrays + trimmed values", lambda m, t: dumps(positional(t))),
        ("Packed binary + trimmed values (estimate)", lambda m, t: b"x" * packed_size(t)),
    ]
    columns = ["track_cue", "cue_heartbeat", "cue_snapshot_begin", "cue_snapshot_end"]
    print("\n| Encoding | " + " | ".join(f"{c} (median B)" for c in columns)
          + " | capture total (B) | vs JSON | datagrams > 1 frame |")
    print("|---|" + "---:|" * (len(columns) + 3))
    baseline = None
    for name, encode in encodings:
        sizes: dict[str, list[int]] = defaultdict(list)
        over = 0
        for m, t in zip(messages, trimmed):
            n = len(encode(m, t))
            sizes[m["message_type"]].append(n)
            over += n > MTU_PAYLOAD
        tot = sum(sum(v) for v in sizes.values())
        baseline = baseline or tot
        print(f"| {name} | " + " | ".join(f"{statistics.median(sizes[c]):.0f}" for c in columns)
              + f" | {tot} | {tot / baseline:.0%} | {over} of {len(messages)} |")
    print(f"\nField names: {len(codes)} distinct, mean {statistics.mean(len(k) for k in codes):.1f} chars.")
    print(f"Preset dictionary: last {len(dictionary)} bytes of {dictionary_source.name} (a different capture).")


if __name__ == "__main__":
    args = [Path(a) for a in sys.argv[1:]]
    main(args[0] if args else DEFAULT_CAPTURE, args[1] if len(args) > 1 else DEFAULT_DICTIONARY_SOURCE)
