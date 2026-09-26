#!/usr/bin/env python3
"""Derive candidate index.html and reporting_README.md from the accepted versions by explicit edits.

Adds the System Engineering section (separate from the nine-report exploration family) and points
the family entries for 02 and 06 at V5 and V3. Reads reporting/, writes only into the overlay.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/derive_navigation.py
"""

from __future__ import annotations

from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
SRC = REPO / "reporting"
OUT = CANDIDATE / "overlay"
SITE = "https://pwilliammat.github.io/flightTest"

INDEX_SECTION = """    <section>
      <h2>System engineering</h2>
      <p>The testbed as a formal system design: mission goals, a draft requirements baseline, architecture and allocation, interfaces, verification and traceability, truth separation, and the as-built configuration. This section is separate from the exploration family above, which asks “can we do it, and what does it look like”. Every page states its purpose and claim boundary; its status words are requirement- and interface-level, not radar results.</p>
      <div class="report-grid">
        <a class="report-card" href="system/index.html" target="_blank" rel="noopener noreferrer">
          <p class="report-id">System</p>
          <h3>Design Process and Status</h3>
          <p>Start here: the seven design-process steps and the subsystem records, the decisions of 26 September 2026, the action register, and requirements status at a glance.</p>
        </a>
        <a class="report-card" href="system/02_Requirements.html" target="_blank" rel="noopener noreferrer">
          <p class="report-id">System · 2</p>
          <h3>Requirements (Draft)</h3>
          <p>Two mission goals traced to 15 system and 28 derived requirements, each with allocation, verification method and status. A draft for owner review.</p>
        </a>
        <a class="report-card" href="system/05_VerificationAndTraceability.html" target="_blank" rel="noopener noreferrer">
          <p class="report-id">System · 5</p>
          <h3>Verification and Traceability</h3>
          <p>How each requirement is checked, what has passed so far (the cue message interface), and where the evidence is.</p>
        </a>
        <a class="report-card" href="system/SDR_CT_CueTasking_V1.html" target="_blank" rel="noopener noreferrer">
          <p class="report-id">Subsystem record</p>
          <h3>ADS-B Cue Tasking (CT)</h3>
          <p>The cue tasker on the ADS-B Pi and its live-verified cue stream to the collection side: a message-interface result, not a detection.</p>
        </a>
      </div>
    </section>

"""


def edit(text: str, pairs: list[tuple[str, str]], name: str) -> str:
    for old, new in pairs:
        if text.count(old) < 1:
            raise SystemExit(f"{name}: anchor not found: {old[:80]!r}")
        text = text.replace(old, new)
    return text


def main() -> None:
    index = (SRC / "index.html").read_text(encoding="utf-8")
    index = edit(index, [
        ('href="reports/06_StatusAndFutureWork_V2.html"', 'href="reports/06_StatusAndFutureWork_V3.html"'),
        ('href="reports/02_HardwareAndCollection_V4.html"', 'href="reports/02_HardwareAndCollection_V5.html"'),
        ("    <section>\n      <h2>Diagnostic reports</h2>", INDEX_SECTION + "    <section>\n      <h2>Diagnostic reports</h2>"),
    ], "index.html")
    (OUT / "index.html").write_text(index, encoding="utf-8")

    readme = (SRC / "reporting_README.md").read_text(encoding="utf-8")
    readme = edit(readme, [
        (f"{SITE}/reports/06_StatusAndFutureWork_V2.html", f"{SITE}/reports/06_StatusAndFutureWork_V3.html"),
        (f"{SITE}/reports/02_HardwareAndCollection_V4.html", f"{SITE}/reports/02_HardwareAndCollection_V5.html"),
        ("**Canonical family mapping and claim boundaries:** [family_manifest.json](metadata/family_manifest.json)",
         "**Canonical family mapping and claim boundaries:** [family_manifest.json](metadata/family_manifest.json)<br>\n"
         f"**System engineering (separate from the family):** [design process and status]({SITE}/system/index.html)"),
        ("- [Diagnostic reports](diagnostics/README.md):",
         f"- [System engineering section](system/README.md): the testbed as a formal system design process, separate from the exploration family. It covers mission goals, a [draft requirements baseline]({SITE}/system/02_Requirements.html), architecture and allocation, interfaces, [verification and traceability]({SITE}/system/05_VerificationAndTraceability.html), [truth separation for cued collections]({SITE}/system/06_TruthSeparation.html), the as-built configuration, and the first subsystem design record ([ADS-B cue tasking]({SITE}/system/SDR_CT_CueTasking_V1.html)). The masters stay in `docs/system/`.\n"
         "- [Diagnostic reports](diagnostics/README.md):"),
        ("| `diagnostics/` | Diagnostic reports from hardware and calibration troubleshooting; not part of the accepted family. |",
         "| `system/` | System engineering section: design-process pages and subsystem design records; separate from the accepted family. Masters in `docs/system/`. |\n"
         "| `diagnostics/` | Diagnostic reports from hardware and calibration troubleshooting; not part of the accepted family. |"),
    ], "reporting_README.md")
    (OUT / "reporting_README.md").write_text(readme, encoding="utf-8")
    print("wrote overlay/index.html and overlay/reporting_README.md")


if __name__ == "__main__":
    main()
