#!/usr/bin/env python3
"""Reproduce the CT 2.0.0 live-acceptance numbers and draw the candidate report's figures.

Candidate-review tool for candidates/2026-09-26_cue_tasking (not part of reporting/).

Inputs (all already committed evidence):
  * docs/system/evidence/cue_traffic_20260926T1523Z_wire.jsonl  - CT 2.0.0 live capture, wire bytes
  * docs/system/evidence/cue_traffic_20260926T1523Z_summary.json - cue_capture.py summary of it
  * docs/system/evidence/cue_traffic_20260926T1234Z.jsonl        - CT 1.1.0 live capture, plain JSON
  * ADSB-remoter schemas/dictionaries/cue-dictionary-1.bin       - released preset dictionary 1
  * ADSB-remoter schemas/*-2.0.0.json (optional)                 - schema validation, if jsonschema is installed

Outputs:
  * generated/cue_capture_summary.json (numbers quoted in the candidate reports)
  * overlay/systems/SystemArchitectureAndCueTasking_assets/fig_*.svg (figures)

Usage, from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/summarize_cue_capture.py \
      --adsb-remoter ~/Documents/ADSB-remoter

Standard library only, except jsonschema (optional). Decoding follows ICD_Messages.md 1.3:
first byte 0xDC, byte 1 = dictionary id, then raw deflate (RFC 1951) with the preset dictionary.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import statistics
import zlib
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

DICTIONARY_1_SHA256 = "ca649af0a49ceb14b8610aeec89e55c3e83801e8d7e50d449aeeedac4e5b4cd4"
ONE_FRAME_BYTES = 1472
COMPRESSED_TAG = 0xDC

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parent
# The flightTest root is the nearest parent that holds docs/system (so the script can be moved).
REPO = next(p for p in HERE.parents if (p / "docs" / "system" / "evidence").is_dir())
EVIDENCE = REPO / "docs" / "system" / "evidence"
ASSETS = CANDIDATE / "overlay" / "systems" / "SystemArchitectureAndCueTasking_assets"
SUMMARY = CANDIDATE / "generated" / "cue_capture_summary.json"

# Chart colours: validated pair (dataviz validator, light surface): plain JSON vs on the wire.
C_JSON = "#eb6834"
C_WIRE = "#2a78d6"
INK = "#172033"
MUTED = "#526176"
GRID = "#e2e8f0"
FONT = "Segoe UI,Arial,sans-serif"


def decode(datagram: bytes, dictionary: bytes) -> bytes:
    if datagram[:1] == b"{":
        return datagram
    if datagram[0] != COMPRESSED_TAG or datagram[1] != 1:
        raise ValueError(f"unexpected frame tag/dictionary {datagram[:2].hex()}")
    inflater = zlib.decompressobj(-15, zdict=dictionary)
    message = inflater.decompress(datagram[2:]) + inflater.flush()
    if not inflater.eof:
        raise ValueError("truncated deflate stream")
    return message


def load_validators(schema_dir: Path | None) -> dict[str, object]:
    if schema_dir is None:
        return {}
    try:
        import jsonschema  # type: ignore[import-not-found]
    except ImportError:
        return {}
    names = {
        "cue_heartbeat": "cue-heartbeat-2.0.0.json",
        "cue_snapshot_begin": "cue-snapshot-begin-2.0.0.json",
        "cue_snapshot_end": "cue-snapshot-end-2.0.0.json",
        "track_cue": "track-cue-2.0.0.json",
        "track_cue_withdrawal": "track-cue-withdrawal-2.0.0.json",
    }
    validators = {}
    for message_type, filename in names.items():
        schema = json.loads((schema_dir / filename).read_text())
        validators[message_type] = jsonschema.Draft202012Validator(
            schema, format_checker=jsonschema.FormatChecker()
        )
    return validators


def stats(values: list[float]) -> dict[str, float]:
    return {
        "count": len(values),
        "minimum": min(values),
        "median": statistics.median(values),
        "maximum": max(values),
    }


def summarize(wire_path: Path, plain_1_1_path: Path, dictionary: bytes, validators: dict) -> dict:
    records = [json.loads(line) for line in wire_path.read_text().splitlines() if line.strip()]
    rows = []
    schema_failures = 0
    for record in records:
        raw = base64.b64decode(record["datagram_b64"])
        message_bytes = decode(raw, dictionary)
        message = json.loads(message_bytes)
        validator = validators.get(message["message_type"])
        if validator is not None and any(True for _ in validator.iter_errors(message)):
            schema_failures += 1
        rows.append(
            {
                "t": record["received_unix_s"],
                "wire": len(raw),
                "json": len(message_bytes),
                "msg": message,
            }
        )

    by_type: dict[str, list[dict]] = {}
    for row in rows:
        by_type.setdefault(row["msg"]["message_type"], []).append(row)

    sequences = [row["msg"]["sequence_number"] for row in rows]
    instances = {row["msg"]["source_instance_id"] for row in rows}
    ordered = sorted(sequences)
    gaps = sum(b - a - 1 for a, b in zip(ordered, ordered[1:], strict=False) if b - a > 1)
    out_of_order = sum(1 for a, b in zip(sequences, sequences[1:], strict=False) if b < a)
    message_ids = [row["msg"]["message_id"] for row in rows]

    cues = by_type.get("track_cue", [])
    snapshot_cues = Counter(c["msg"]["snapshot_id"] for c in cues if c["msg"]["snapshot_id"])
    snapshots = []
    for end in by_type.get("cue_snapshot_end", []):
        sid = end["msg"]["snapshot_id"]
        snapshots.append(
            {
                "snapshot_id": sid,
                "published_track_count": end["msg"]["published_track_count"],
                "received_track_cue_count": snapshot_cues.get(sid, 0),
                "consistent": end["msg"]["published_track_count"] == snapshot_cues.get(sid, 0),
            }
        )

    opportunities = [len(c["msg"]["opportunities"]) for c in cues]
    by_opps: dict[int, list[int]] = {}
    for c, n in zip(cues, opportunities, strict=True):
        by_opps.setdefault(n, []).append(c["wire"])
    # Least-squares slope of wire size against opportunity count (bytes per extra opportunity).
    mean_n = statistics.fmean(opportunities)
    mean_b = statistics.fmean(c["wire"] for c in cues)
    slope = sum((n - mean_n) * (c["wire"] - mean_b) for c, n in zip(cues, opportunities, strict=True)) / sum(
        (n - mean_n) ** 2 for n in opportunities
    )

    plain_lines = [line for line in plain_1_1_path.read_bytes().splitlines() if line.strip()]
    plain_1_1 = {}
    for line in plain_lines:
        message = json.loads(line)
        plain_1_1.setdefault(message["message_type"], []).append(len(line))

    t0 = min(row["t"] for row in rows)
    t1 = max(row["t"] for row in rows)
    return {
        "source_file": str(wire_path.relative_to(REPO)),
        "dictionary_sha256": hashlib.sha256(dictionary).hexdigest(),
        "schema_validation": "jsonschema 2.0.0" if validators else "not run (no schema dir or jsonschema)",
        "first_received_utc": datetime.fromtimestamp(t0, UTC).isoformat(timespec="seconds"),
        "last_received_utc": datetime.fromtimestamp(t1, UTC).isoformat(timespec="seconds"),
        "duration_s": round(t1 - t0, 1),
        "datagrams": len(rows),
        "compressed_datagrams": sum(1 for r in records if base64.b64decode(r["datagram_b64"])[0] == COMPRESSED_TAG),
        "schema_failures": schema_failures,
        "source_instances": len(instances),
        "sequence_gaps": gaps,
        "out_of_order": out_of_order,
        "duplicate_message_ids": len(message_ids) - len(set(message_ids)),
        "over_one_frame": sum(1 for row in rows if row["wire"] > ONE_FRAME_BYTES),
        "max_datagram_bytes": max(row["wire"] for row in rows),
        "message_counts": {k: len(v) for k, v in sorted(by_type.items())},
        "wire_bytes_by_type": {k: stats([r["wire"] for r in v]) for k, v in sorted(by_type.items())},
        "json_bytes_by_type": {k: stats([r["json"] for r in v]) for k, v in sorted(by_type.items())},
        "track_cue_compression_ratio_median": round(
            statistics.median(c["json"] for c in cues) / statistics.median(c["wire"] for c in cues), 2
        ),
        "unique_aircraft": len({c["msg"]["track"]["icao"] for c in cues}),
        "opportunities_per_cue": stats(opportunities),
        "opportunity_count_histogram": dict(sorted(Counter(opportunities).items())),
        "wire_bytes_per_extra_opportunity_lsq": round(slope, 1),
        "update_reasons": dict(Counter(c["msg"]["prediction"]["update_reason"] for c in cues)),
        "heartbeat_status": dict(Counter(h["msg"]["status"] for h in by_type.get("cue_heartbeat", []))),
        "snapshots": len(snapshots),
        "snapshots_consistent": sum(s["consistent"] for s in snapshots),
        "snapshots_carrying_cues": sum(1 for s in snapshots if s["published_track_count"] > 0),
        "withdrawals": len(by_type.get("track_cue_withdrawal", [])),
        "distinct_emitters_in_cues": len(
            {o["emitter_id"] for c in cues for o in c["msg"]["opportunities"]}
        ),
        "plain_json_1_1_0_capture": {
            "source_file": str(plain_1_1_path.relative_to(REPO)),
            "messages": len(plain_lines),
            "bytes_by_type": {k: stats(v) for k, v in sorted(plain_1_1.items())},
            "over_one_frame": sum(1 for line in plain_lines if len(line) > ONE_FRAME_BYTES),
        },
        "_rows": [
            {"t": r["t"] - t0, "type": r["msg"]["message_type"], "wire": r["wire"],
             "opps": len(r["msg"].get("opportunities", [])),
             "reason": r["msg"].get("prediction", {}).get("update_reason")}
            for r in rows
        ],
    }


# ------------------------------------------------------------------ SVG helpers


def svg_open(width: int, height: int, title: str, desc: str) -> list[str]:
    return [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" '
        f'aria-labelledby="t d" font-family="{FONT}">',
        f'<title id="t">{title}</title><desc id="d">{desc}</desc>',
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
    ]


def text(x: float, y: float, s: str, size: int = 13, fill: str = INK, anchor: str = "start", weight: str = "400") -> str:
    # White halo keeps labels legible where they cross grid or limit lines.
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" '
        f'text-anchor="{anchor}" font-weight="{weight}" paint-order="stroke" stroke="#ffffff" '
        f'stroke-width="3" stroke-linejoin="round">{s}</text>'
    )


def bar(x: float, y: float, w: float, h: float, fill: str, tip: str) -> str:
    # Rounded data-end, square baseline end (4 px radius only at the far end).
    r = min(4.0, w / 2, h / 2)
    if w <= 2 * r:
        return f'<rect x="{x:.1f}" y="{y:.1f}" width="{max(w,1):.1f}" height="{h:.1f}" fill="{fill}"><title>{tip}</title></rect>'
    path = (
        f"M{x:.1f},{y:.1f} H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} "
        f"V{y + h - r:.1f} Q{x + w:.1f},{y + h:.1f} {x + w - r:.1f},{y + h:.1f} H{x:.1f} Z"
    )
    return f'<path d="{path}" fill="{fill}"><title>{tip}</title></path>'


def fig_message_size(summary: dict) -> str:
    """Median bytes per message: CT 1.1.0 plain (12:34 capture) vs CT 2.0.0 JSON vs on the wire."""
    json_b = summary["json_bytes_by_type"]
    wire_b = summary["wire_bytes_by_type"]
    old = summary["plain_json_1_1_0_capture"]["bytes_by_type"]
    rows = [
        ("track_cue", "track_cue"),
        ("cue_heartbeat", "cue_heartbeat"),
        ("cue_snapshot_begin", "cue_snapshot_begin"),
        ("cue_snapshot_end", "cue_snapshot_end"),
    ]
    width, left, right = 1100, 210, 70
    top, group_h, bar_h = 92, 96, 22
    height = top + group_h * len(rows) + 60
    xmax = 12000.0
    scale = (width - left - right) / xmax
    out = svg_open(
        width, height,
        "Median message size: plain JSON against the compressed datagram on the wire",
        "Grouped horizontal bars per CT message type. For each type: CT 1.1.0 plain JSON (12:34 UTC capture), "
        "CT 2.0.0 decoded JSON, and the CT 2.0.0 compressed datagram (15:23 UTC capture). A dashed line marks "
        "the 1472-byte one-frame limit.",
    )
    out.append(text(24, 32, "Median bytes per message, by message type", 18, weight="700"))
    out.append(text(24, 54, "Orange = plain JSON (as sent by 1.1.0, or as decoded from 2.0.0). Blue = CT 2.0.0 compressed datagram as received. "
                    "Dashed = one Ethernet frame (1472 B UDP payload).", 12, MUTED))
    for i in range(0, 11):
        x = left + i * 1000 * scale
        out.append(f'<line x1="{x:.1f}" y1="{top - 10}" x2="{x:.1f}" y2="{height - 50}" stroke="{GRID}" stroke-width="1"/>')
        out.append(text(x, height - 32, f"{i * 1000:,}", 11, MUTED, "middle"))
    out.append(text(left + (width - left - right) / 2, height - 12, "bytes (median)", 12, MUTED, "middle"))
    frame_x = left + ONE_FRAME_BYTES * scale
    for g, (label, key) in enumerate(rows):
        y0 = top + g * group_h
        out.append(text(left - 12, y0 + 44, label, 13, INK, "end", "600"))
        series = [
            ("1.1.0 plain JSON", old.get(key, {}).get("median"), C_JSON, 0.45),
            ("2.0.0 JSON (decoded)", json_b[key]["median"], C_JSON, 1.0),
            ("2.0.0 on the wire", wire_b[key]["median"], C_WIRE, 1.0),
        ]
        for j, (name, value, colour, opacity) in enumerate(series):
            y = y0 + j * (bar_h + 4)
            if value is None:
                continue
            w = value * scale
            b = bar(left, y, w, bar_h, colour, f"{label}, {name}: median {value:,.0f} B")
            if opacity < 1:
                b = b.replace(f'fill="{colour}"', f'fill="{colour}" fill-opacity="{opacity}"', 1)
            out.append(b)
            out.append(text(left + w + 6, y + 16, f"{value:,.0f} B · {name}", 12, INK))
    out.append(f'<line x1="{frame_x:.1f}" y1="{top - 18}" x2="{frame_x:.1f}" y2="{height - 50}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="6 4"/>')
    out.append(text(frame_x + 6, top - 20, "1472 B: one frame", 12, INK, "start", "600"))
    out.append("</svg>")
    return "\n".join(out)


def fig_size_vs_opportunities(summary: dict) -> str:
    rows = [r for r in summary["_rows"] if r["type"] == "track_cue"]
    width, height = 1100, 470
    left, right, top, bottom = 90, 40, 100, 70
    xmax, ymax = 8.5, 1600
    sx = (width - left - right) / (xmax + 0.5)
    sy = (height - top - bottom) / ymax

    def px(n: float) -> float:
        return left + (n + 0.5) * sx

    def py(b: float) -> float:
        return height - bottom - b * sy

    out = svg_open(
        width, height,
        "Compressed track_cue size against the number of opportunities it carries",
        "Dot plot of all 103 track_cue datagrams in the 15:23 UTC capture: x = opportunities in the cue (0 to 8), "
        "y = bytes on the wire. A dashed line marks the 1472-byte one-frame limit; every dot is below it.",
    )
    out.append(text(24, 32, "Every track_cue fitted one frame: bytes on the wire against opportunities per cue", 18, weight="700"))
    out.append(text(24, 54, f"All {len(rows)} track_cue datagrams, 2026-09-26 15:23–15:38 UTC. Dots are jittered horizontally so repeats stay visible.", 12, MUTED))
    for b in range(0, 1601, 200):
        y = py(b)
        out.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width - right}" y2="{y:.1f}" stroke="{GRID}" stroke-width="1"/>')
        out.append(text(left - 10, y + 4, f"{b:,}", 11, MUTED, "end"))
    for n in range(0, 9):
        out.append(text(px(n), height - bottom + 20, str(n), 12, MUTED, "middle"))
    out.append(text((left + width - right) / 2, height - 22, "opportunities in the cue", 12, MUTED, "middle"))
    out.append(text(22, top - 22, "bytes on the wire", 12, MUTED))
    fy = py(ONE_FRAME_BYTES)
    out.append(f'<line x1="{left}" y1="{fy:.1f}" x2="{width - right}" y2="{fy:.1f}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="6 4"/>')
    out.append(text(left + 8, fy - 8, "1472 B: one Ethernet frame (UDP payload)", 12, INK, "start", "600"))
    counts: Counter = Counter()
    for r in rows:
        k = counts[r["opps"]]
        counts[r["opps"]] += 1
        jitter = ((k * 37) % 21 - 10) / 10 * 0.28
        out.append(
            f'<circle cx="{px(r["opps"] + jitter):.1f}" cy="{py(r["wire"]):.1f}" r="4.5" fill="{C_WIRE}" '
            f'fill-opacity="0.75" stroke="#ffffff" stroke-width="1.5"><title>{r["opps"]} opportunities: {r["wire"]} B '
            f'({r["reason"]})</title></circle>'
        )
    med8 = summary["wire_bytes_by_type"]["track_cue"]["median"]
    out.append(text(px(8) - 12, py(med8) - 16, f"median of all cues {med8:,.0f} B", 12, INK, "end"))
    out.append("</svg>")
    return "\n".join(out)


def fig_timeline(summary: dict) -> str:
    rows = summary["_rows"]
    width, height = 1100, 300
    left, right, top = 170, 40, 70
    duration = summary["duration_s"]
    sx = (width - left - right) / duration
    lanes = [("cue_heartbeat", "heartbeat (10 s)"), ("cue_snapshot_end", "snapshot end (60 s)"), ("track_cue", "track_cue")]
    lane_y = {k: top + 40 + i * 55 for i, (k, _) in enumerate(lanes)}
    out = svg_open(
        width, height,
        "Timeline of the CT 2.0.0 live acceptance capture",
        "Three lanes over the 15-minute capture: heartbeats every 10 s, snapshot ends every 60 s labelled with the "
        "number of cues they published, and track_cue datagrams sized by opportunity count.",
    )
    out.append(text(24, 32, "What arrived, and when: CT 2.0.0 live capture, 2026-09-26 from 15:23 UTC", 18, weight="700"))
    out.append(text(24, 54, "Numbers above snapshot marks = published_track_count, each equal to the track_cue messages received for that snapshot.", 12, MUTED))
    for m in range(0, int(duration // 60) + 1):
        x = left + m * 60 * sx
        out.append(f'<line x1="{x:.1f}" y1="{top + 10}" x2="{x:.1f}" y2="{height - 50}" stroke="{GRID}" stroke-width="1"/>')
        if m % 2 == 0:
            out.append(text(x, height - 32, f"+{m} min", 11, MUTED, "middle"))
    for key, label in lanes:
        out.append(text(left - 12, lane_y[key] + 4, label, 12, INK, "end", "600"))
    for r in rows:
        x = left + r["t"] * sx
        if r["type"] == "cue_heartbeat":
            out.append(f'<circle cx="{x:.1f}" cy="{lane_y["cue_heartbeat"]}" r="4" fill="{MUTED}"><title>heartbeat +{r["t"]:.1f} s</title></circle>')
        elif r["type"] == "track_cue":
            radius = 3 + r["opps"] * 0.6
            out.append(f'<circle cx="{x:.1f}" cy="{lane_y["track_cue"]}" r="{radius:.1f}" fill="{C_WIRE}" fill-opacity="0.55" stroke="#ffffff" stroke-width="1"><title>track_cue +{r["t"]:.1f} s, {r["opps"]} opportunities, {r["wire"]} B</title></circle>')
    ends = [r for r in rows if r["type"] == "cue_snapshot_end"]
    pubs = [s for s in summary["_snapshot_counts"]]
    for r, count in zip(ends, pubs, strict=True):
        x = left + r["t"] * sx
        y = lane_y["cue_snapshot_end"]
        out.append(f'<rect x="{x - 2:.1f}" y="{y - 10}" width="4" height="20" rx="2" fill="{INK}"><title>snapshot end +{r["t"]:.1f} s: {count} cues</title></rect>')
        out.append(text(x, y - 14, str(count), 11, INK, "middle"))
    out.append(text(left, height - 10, "Dot size in the track_cue lane grows with the number of opportunities (0 to 8).", 11, MUTED))
    out.append("</svg>")
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--adsb-remoter", type=Path, required=True, help="ADSB-remoter checkout (dictionary 1, schemas)")
    parser.add_argument("--wire", type=Path, default=EVIDENCE / "cue_traffic_20260926T1523Z_wire.jsonl")
    parser.add_argument("--plain-1-1", type=Path, default=EVIDENCE / "cue_traffic_20260926T1234Z.jsonl")
    parser.add_argument("--assets-dir", type=Path, default=ASSETS, help="where the SVG figures are written")
    parser.add_argument("--summary-out", type=Path, default=SUMMARY, help="where the JSON summary is written")
    args = parser.parse_args()
    assets = args.assets_dir

    dictionary = (args.adsb_remoter / "schemas" / "dictionaries" / "cue-dictionary-1.bin").read_bytes()
    if hashlib.sha256(dictionary).hexdigest() != DICTIONARY_1_SHA256:
        raise SystemExit("dictionary 1 SHA-256 mismatch")
    validators = load_validators(args.adsb_remoter / "schemas")
    summary = summarize(args.wire.resolve(), args.plain_1_1.resolve(), dictionary, validators)

    # Snapshot counts in arrival order, for the timeline labels.
    ends = []
    for record in json.loads("[" + ",".join(args.wire.read_text().splitlines()) + "]"):
        message = json.loads(decode(base64.b64decode(record["datagram_b64"]), dictionary))
        if message["message_type"] == "cue_snapshot_end":
            ends.append(message["published_track_count"])
    summary["_snapshot_counts"] = ends

    assets.mkdir(parents=True, exist_ok=True)
    (assets / "fig_message_size.svg").write_text(fig_message_size(summary) + "\n")
    (assets / "fig_cue_size_vs_opportunities.svg").write_text(fig_size_vs_opportunities(summary) + "\n")
    (assets / "fig_capture_timeline.svg").write_text(fig_timeline(summary) + "\n")

    public = {k: v for k, v in summary.items() if not k.startswith("_")}
    out = args.summary_out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(public, indent=2, sort_keys=True) + "\n")

    # Cross-check against the committed cue_capture.py summary.
    committed = json.loads((EVIDENCE / "cue_traffic_20260926T1523Z_summary.json").read_text())
    checks = {
        "datagrams": (public["datagrams"], committed["datagrams_received"]),
        "schema_failures": (public["schema_failures"], committed["schema_failure_count"]),
        "sequence_gaps": (public["sequence_gaps"], committed["sequence_gaps"]),
        "over_one_frame": (public["over_one_frame"], committed["datagrams_over_one_frame"]),
        "max_datagram_bytes": (public["max_datagram_bytes"], committed["maximum_datagram_bytes"]),
        "unique_aircraft": (public["unique_aircraft"], committed["unique_tracks"]),
        "track_cue_median_wire": (public["wire_bytes_by_type"]["track_cue"]["median"], committed["track_cue_size_bytes"]["median"]),
        "track_cue_median_json": (public["json_bytes_by_type"]["track_cue"]["median"], committed["track_cue_json_size_bytes"]["median"]),
        "message_counts": (public["message_counts"], committed["message_counts"]),
        "update_reasons": (public["update_reasons"], committed["revisions_by_reason"]),
    }
    failed = False
    for name, (mine, theirs) in checks.items():
        ok = mine == theirs
        failed |= not ok
        print(f"{'OK  ' if ok else 'DIFF'} {name}: reproduced={mine} committed={theirs}")
    print(f"wrote {out} and 3 figures in {assets}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
