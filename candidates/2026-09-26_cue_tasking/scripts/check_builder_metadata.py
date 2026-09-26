#!/usr/bin/env python3
"""Compare metadata written by the candidate TechnicalSummaryFamily builder with the candidate metadata.

Usage:
  python3 check_builder_metadata.py <release-or-staging-root>

The builder regenerates family_*.csv, family_known_gaps.md and family_manifest.json. This check
confirms that a release built with the candidate builder would reproduce the hand-edited
candidate metadata, so a future build does not silently overwrite it. Columns that the builder
derives from the build machine (workstation paths, file-existence status, release hashes and
timestamps) are reported but not compared.
"""

from __future__ import annotations

import csv
import io
import json
import sys
from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
OVERLAY_META = CANDIDATE / "overlay" / "metadata"

# Columns derived from the machine the builder runs on.
MACHINE_COLUMNS = {
    "family_evidence_catalog.csv": {"OriginalSource", "CodeEntryPoint"},
    "family_code_navigation.csv": {"TopLevelCodeEntry", "ExecutionStatus"},
    "family_visual_catalog.csv": {"OriginalSource"},
    "family_handoff_catalog.csv": set(),
}
KEYS = {
    "family_evidence_catalog.csv": "CatalogID",
    "family_code_navigation.csv": "EngineeringTopic",
    "family_visual_catalog.csv": "VisualID",
    "family_handoff_catalog.csv": "HandoffID",
}
ACCEPTED_MACHINE_ROWS = 14  # the original code-navigation rows use workstation paths


def read_csv(path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(io.StringIO(path.read_text(encoding="utf-8"))))


def main() -> None:
    built = Path(sys.argv[1]) / "metadata"
    problems = 0
    for name, key in KEYS.items():
        built_rows = {r[key]: r for r in read_csv(built / name)}
        cand_rows = {r[key]: r for r in read_csv(OVERLAY_META / name)}
        if set(built_rows) != set(cand_rows):
            print(f"DIFF {name}: row keys differ: built-only {set(built_rows) - set(cand_rows)}, candidate-only {set(cand_rows) - set(built_rows)}")
            problems += 1
        skipped = 0
        for k, cand in cand_rows.items():
            b = built_rows.get(k)
            if b is None:
                continue
            for col, value in cand.items():
                machine = col in MACHINE_COLUMNS[name]
                if name == "family_code_navigation.csv" and list(cand_rows).index(k) >= ACCEPTED_MACHINE_ROWS:
                    machine = False  # added rows carry fixed URLs and statuses; compare everything
                if machine:
                    skipped += b.get(col) != value
                    continue
                if b.get(col) != value:
                    print(f"DIFF {name} [{k}] {col}:\n  built:     {b.get(col)!r}\n  candidate: {value!r}")
                    problems += 1
        print(f"{'OK  ' if not problems else '    '}{name}: {len(cand_rows)} rows compared; {skipped} machine-derived cells differ (expected)")

    gaps_built = (built / "family_known_gaps.md").read_text(encoding="utf-8").strip()
    gaps_cand = (OVERLAY_META / "family_known_gaps.md").read_text(encoding="utf-8").strip()
    ok = gaps_built == gaps_cand
    problems += not ok
    print(f"{'OK  ' if ok else 'DIFF'} family_known_gaps.md identical (ignoring final newline)")

    mb = json.loads((built / "family_manifest.json").read_text(encoding="utf-8"))
    mc = json.loads((OVERLAY_META / "family_manifest.json").read_text(encoding="utf-8"))
    ok = mb["known_gaps"] == mc["known_gaps"] and mb["canonical_order"] == mc["canonical_order"]
    fields = ["report_id", "latest_version", "accepted_version", "canonical_filename", "content_status", "primary_question",
              "strongest_result", "engineering_decision", "upstream_report", "downstream_report", "claim_boundary"]
    for rb, rc in zip(mb["reports"], mc["reports"], strict=True):
        for f in fields:
            if rb[f] != rc[f]:
                print(f"DIFF manifest report {rc['report_id']} {f}: built {rb[f]!r} candidate {rc[f]!r}")
                ok = False
        if rb["source_hash"] != rc["source_hash"]:
            print(f"DIFF manifest report {rc['report_id']} source_hash")
            ok = False
    problems += not ok
    print(f"{'OK  ' if ok else 'DIFF'} family_manifest.json: known_gaps, canonical order, report fields and source hashes")
    print("RESULT:", "PASS" if not problems else f"FAIL ({problems})")
    raise SystemExit(1 if problems else 0)


if __name__ == "__main__":
    main()
