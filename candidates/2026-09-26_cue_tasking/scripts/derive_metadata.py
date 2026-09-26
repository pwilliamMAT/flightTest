#!/usr/bin/env python3
"""Derive candidate copies of the reporting metadata for the 2026-09-26 update.

Reads reporting/metadata/* (never writes them) and writes edited copies to
candidates/2026-09-26_cue_tasking/overlay/metadata/. CSVs are edited as text lines (exact
substring replacements and appended rows) so the diff against the accepted files stays minimal.
The same strings are mirrored in the candidate buildTechnicalSummaryFamily.m, so a future
release build regenerates the same content; scripts/check_builder_metadata.py compares them.
The manifest records the SHA-256 of the candidate HTML, so run this after the HTML is final.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/derive_metadata.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
SRC = REPO / "reporting" / "metadata"
OUT = CANDIDATE / "overlay" / "metadata"
OVERLAY = CANDIDATE / "overlay"

R02_OLD, R02_NEW = "02_HardwareAndCollection_V4.html", "02_HardwareAndCollection_V5.html"
R06_OLD, R06_NEW = "06_StatusAndFutureWork_V2.html", "06_StatusAndFutureWork_V3.html"

# ---- strings shared with buildTechnicalSummaryFamily.m (keep identical) ----
UNKNOWN_02_OLD = "Channel-role proof, lock/drop evidence, and collection suitability."
UNKNOWN_02 = ("Channel-role proof, lock/drop evidence, collection suitability, GPS/PPS lock of the ADS-B time source "
              "(internet NTP accepted with a 0.1 s tolerance), and the Pi clock offset of ADS-B truth before 2026-09-25 21:07 UTC.")
RESULT_06_OLD = "Map-contract verification and collection/reference qualification remain independent blockers."
RESULT_06 = ("Map-contract verification and collection/reference qualification remain independent blockers; "
             "the ADS-B cue interface is verified as infrastructure only.")
UNKNOWN_06_OLD = "Passing map-contract correction and reviewed collection/reference-path qualification."
UNKNOWN_06 = ("Passing map-contract correction, reviewed collection/reference-path qualification, an accepted "
              "truth-separation rule for cued collections, and a first collection scheduled from an ADS-B cue.")
EVIDENCE_02_OLD = "Report 02 V4 package/manifests and qualification criteria."
EVIDENCE_02 = "Report 02 V5 package/manifests, qualification criteria, and as-built cueing/time state."
MANIFEST_GAPS = [
    "The ADS-B Pi time source is NTP-disciplined (accepted); GPS/PPS lock is a hardware to-do, and Pi-timed ADS-B truth before 2026-09-25 21:07 UTC carries an unknown clock offset.",
    "ADS-B cues are verified as a message interface only; no collection has been scheduled from a cue.",
    "The truth-separation rule for cued collections and cue-aided association is proposed (CR-9), not accepted.",
]
KNOWN_GAPS_ADDED = (
    "\n## Added 2026-09-26 (cue-tasking update)\n\n"
    "- The ADS-B Pi keeps time from internet NTP, which is accepted, with a proposed 0.1 s host-to-host tolerance; GPS/PPS lock is a hardware to-do. Before 2026-09-25 21:07 UTC the Pi was measured 14.9 s slow, so Pi-timed ADS-B truth from earlier collections carries an unknown offset until it is re-checked (Report 02 V5 TIME-001; Report 06 V3 STAT-010).\n"
    "- The ADS-B cue interface is verified as a message interface only. The Resource Manager does not schedule collections, and no collection has been made from a cue (Report 06 V3 STAT-009, STAT-012).\n"
    "- Cues choose when and with which tower to collect, and the Tracker may use cues to help association. The truth-separation rule that labels cued collections and cue-aided products is proposed (CR-9, System Engineering section) and not yet accepted; until it is, no cued result counts as independent detection evidence (Report 06 V3 STAT-013).\n"
    "- Predicted SNR in cues is a modeled, pre-integration ranking estimate and has not been reconciled with the Report 01A/01B models.\n"
    "- CueListener and the DTV level-check scripts stay on branch `feature/adsb-cue-listener` pending review; the Cue Tasker code is on an ADSB-remoter feature branch.\n"
    "- The system requirements baseline is a draft (CR-10); no requirement is accepted.\n"
)
RELEASE_POLICY_ADDED = (
    " Reports 02 V5 and 06 V3 replace 02 V4 and 06 V2 as the current versions; the superseded files stay in "
    "`reports/` unchanged because accepted reports link to them."
)
CODE_ROWS = [
    ["ADS-B cue tasking (CT)", "System section (SDR-CT); installed state in 02",
     "Publish per-aircraft cues with modeled illuminator opportunities.",
     "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21/src/adsb_console/cue.py",
     "ADSB-remoter feature/passive-radar-cueing @ 55062fc",
     "prediction.py, bistatic.py, cue_config.py, app.py --headless, deploy/, schemas/ 2.0.0 and dictionaries/",
     "dump1090 SBS, DTV emitter table, observer INI, cue config", "CT 2.0.0 UDP multicast datagrams",
     "SDR-CT Figures 2-4", "Release metadata link", "Strong", "Inspected; 81 tests re-run 2026-09-26", "",
     "Record the commit deployed on the Pi in As_Built.md at each update.", "P1",
     "Deployed on the ADS-B Pi as systemd adsb-cue."],
    ["Cue capture and verification", "System section (SDR-CT)",
     "Decode and validate the cue stream and summarise gaps and sizes.",
     "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21/tools/cue_capture.py",
     "ADSB-remoter feature/passive-radar-cueing @ 55062fc", "tools/cue_decode.py; tools/build_cue_dictionary.py",
     "Live multicast stream", "docs/system/evidence/*_wire.jsonl and *_summary.json", "SDR-CT Figures 2-4",
     "Release metadata link", "Strong", "Inspected only", "", "Keep raw wire bytes for every verification capture.",
     "P1", "Evidence files live on flightTest main under docs/system/evidence/."],
    ["Cue reception (RM first piece)", "System section (SDR-CT)", "Receive and rank cues in MATLAB; no tasking.",
     "https://github.com/pwilliamMAT/flightTest/tree/94bf9247fc9384fd0601e7ef4654f2a1630485c6/CueListener",
     "flightTest feature/adsb-cue-listener @ 94bf924", "runCueListener.m, plotCueWindows.m, dictionaries/",
     "CT multicast stream or JSONL log", "Active cues and opportunity windows", "SDR-CT section 8",
     "Release metadata link", "Strong", "Inspected; 16 tests re-run 2026-09-26",
     "Code stays on its branch pending review.",
     "Pat to review feature/adsb-cue-listener; link the branch or pinned commit 94bf924.",
     "P1", "Java MulticastSocket and java.util.zip; compiled-app probe in docs/system/analysis/deployability/."],
    ["System documents", "System section; 02; 06",
     "Architecture, requirements (draft), ICD, as-built, change requests, verification log.",
     "https://github.com/pwilliamMAT/flightTest/tree/main/docs/system", "flightTest main",
     "analysis/ scripts and deployability probe", "Owner decisions and captures", "Controlled documents",
     "System section pages", "Release metadata link", "Strong", "Inspected only", "",
     "Merge the 2026-09-26 proposals (Requirements.md, CR-9, CR-10) before promoting the section.", "P1",
     "Master copy since 2026-09-26."],
    ["Cue-interface figure generation", "System section (SDR-CT)",
     "Reproduce the CT 2.0.0 acceptance numbers and draw SDR-CT Figures 2-4.",
     "https://github.com/pwilliamMAT/flightTest/blob/main/docs/system/analysis/summarize_cue_capture.py",
     "flightTest main (proposed 2026-09-26)", "Python standard library; optional jsonschema",
     "docs/system/evidence captures and dictionary 1", "SVG figures and cue_capture_summary.json",
     "SDR-CT Figures 2-4", "Release metadata link", "Strong", "Executed 2026-09-26", "",
     "Re-run after any new verification capture.", "P1", "Cross-checks the committed capture summary."],
]
VISUAL_ROWS = [
    ["VIS-20", "System architecture and as-built status", "System section", "Functional architecture with as-built status",
     "system/03_ArchitectureAndAllocation.html (inline SVG)", "docs/system System_Architecture.md, ICD_Messages.md, As_Built.md",
     "System architecture and as-built status", "One verified link", "Separate designed from built", "Strong", "Current",
     "Yes", "Yes", "", "", "Keep inline and update with As_Built", "P1", "Source-backed schematic; no performance content."],
    ["VIS-21", "Message size before and after CR-5", "System section", "Median bytes per message",
     "system/SDR_CT_CueTasking_assets/fig_message_size.svg", "docs/system/evidence captures 20260926T1234Z and T1523Z",
     "Message size before and after CR-5", "7,962 B to 681 B per cue", "Justify the encoding decision", "Strong", "Current",
     "Yes", "Yes", "", "", "Regenerate with summarize_cue_capture.py", "P1", "Measured message sizes."],
    ["VIS-22", "One-frame fit of every cue", "System section", "track_cue bytes against opportunities",
     "system/SDR_CT_CueTasking_assets/fig_cue_size_vs_opportunities.svg", "docs/system/evidence capture 20260926T1523Z",
     "One-frame fit of every cue", "0 of 223 over 1472 B; max 747 B", "Accept the interface", "Strong", "Current",
     "Technical reference", "Yes", "", "", "Regenerate with summarize_cue_capture.py", "P2",
     "Measured message interface; not radar evidence."],
    ["VIS-23", "Live capture timeline", "System section", "What arrived, and when",
     "system/SDR_CT_CueTasking_assets/fig_capture_timeline.svg", "docs/system/evidence capture 20260926T1523Z",
     "Live capture timeline", "15 snapshots consistent", "Accept the interface", "Strong", "Current",
     "Technical reference", "Yes", "", "", "Regenerate with summarize_cue_capture.py", "P2",
     "Measured message interface; not radar evidence."],
]
VISUAL_PATHS = {  # accepted text -> updated text (VIS-07, 08, 09, 18)
    "02_HardwareAndCollection_V4.html and HardwarePhotos": "02_HardwareAndCollection_V5.html and HardwarePhotos",
    "02_HardwareAndCollection_V4.html package/manifests": "02_HardwareAndCollection_V5.html package/manifests",
    ",02_HardwareAndCollection_V4.html,": ",02_HardwareAndCollection_V5.html,",
    ",06_StatusAndFutureWork_V2.html,": ",06_StatusAndFutureWork_V3.html,",
}
# ---------------------------------------------------------------------------


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text: str, old: str, new: str, name: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{name}: expected one match, found {count}: {old[:80]!r}")
    return text.replace(old, new)


def csv_line(values: list[str]) -> str:
    return ",".join('"' + v.replace('"', '""') + '"' if any(c in v for c in ',"\n') else v for v in values)


def manifest() -> None:
    data = json.loads((SRC / "family_manifest.json").read_text(encoding="utf-8"))
    hashes = {R02_NEW: sha256(OVERLAY / "reports" / R02_NEW), R06_NEW: sha256(OVERLAY / "reports" / R06_NEW)}
    for report in data["reports"]:
        if report["report_id"] == "02":
            report.update(latest_version=R02_NEW, accepted_version=R02_NEW, canonical_filename=R02_NEW,
                          source_hash=hashes[R02_NEW], release_hash=None)
        if report["report_id"] == "06":
            report.update(latest_version=R06_NEW, accepted_version=R06_NEW, canonical_filename=R06_NEW,
                          source_hash=hashes[R06_NEW], release_hash=None, strongest_result=RESULT_06)
    for entry in data["source_report_hashes"]:
        new = {"02": R02_NEW, "06": R06_NEW}.get(entry["ReportID"])
        if new:
            entry.update(Filename=new, SourceSHA256=hashes[new],
                         SourcePath=f"flightTest main: reporting/reports/{new} (accepted through candidate review; not in ManagerReport)")
    data["known_gaps"] = data["known_gaps"] + MANIFEST_GAPS
    data["post_release_changes"] = [{
        "date": "2026-09-26",
        "change": "Reports 02 and 06 replaced by V5 and V3 through the 2026-09-26 candidate review; "
                  "no TechnicalSummaryFamily release was built for them. The superseded 02 V4 and 06 V2 stay in reports/.",
        "release_hash": "null for the replaced reports until a release is built",
        "builder": "buildTechnicalSummaryFamily.m and verifyTechnicalSummaryFamily.m updated for the new filenames and metadata",
        "separate_sections": ["system/ (System Engineering section; outside the canonical family)"],
    }]
    (OUT / "family_manifest.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def evidence_catalog() -> None:
    name = "family_evidence_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8")
    text = replace_once(text, f'"{UNKNOWN_02_OLD}"', csv_line([UNKNOWN_02]), name)
    text = replace_once(text, f"ManagerReport\\{R02_OLD},02 deployment/package visuals,../reports/{R02_OLD}",
                        f"ManagerReport\\{R02_OLD},02 deployment/package visuals,../reports/{R02_NEW}", name)
    text = replace_once(text, f'"{RESULT_06_OLD}"', csv_line([RESULT_06]), name)
    text = replace_once(text, f'"{UNKNOWN_06_OLD}"', csv_line([UNKNOWN_06]), name)
    text = replace_once(text, f"ManagerReport\\{R06_OLD},06 blocker/action visuals,../reports/{R06_OLD}",
                        f"ManagerReport\\{R06_OLD},06 blocker/action visuals,../reports/{R06_NEW}", name)
    (OUT / name).write_text(text, encoding="utf-8")


def handoff_catalog() -> None:
    name = "family_handoff_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8")
    text = replace_once(text, f'"{EVIDENCE_02_OLD}"', csv_line([EVIDENCE_02]), name)
    (OUT / name).write_text(text, encoding="utf-8")


def code_navigation() -> None:
    name = "family_code_navigation.csv"
    text = (SRC / name).read_text(encoding="utf-8").rstrip("\n") + "\n"
    (OUT / name).write_text(text + "\n".join(csv_line(r) for r in CODE_ROWS) + "\n", encoding="utf-8")


def visual_catalog() -> None:
    name = "family_visual_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8")
    for old, new in VISUAL_PATHS.items():
        text = replace_once(text, old, new, name)
    text = text.rstrip("\n") + "\n"
    (OUT / name).write_text(text + "\n".join(csv_line(r) for r in VISUAL_ROWS) + "\n", encoding="utf-8")


def known_gaps() -> None:
    name = "family_known_gaps.md"
    text = (SRC / name).read_text(encoding="utf-8")
    anchor = ("- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, "
              "tracking, or localization validation.\n")
    text = replace_once(text, anchor, anchor + KNOWN_GAPS_ADDED, name)
    text = replace_once(text, "canonical version mapping, and validation.",
                        "canonical version mapping, and validation." + RELEASE_POLICY_ADDED, name)
    (OUT / name).write_text(text, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest()
    evidence_catalog()
    handoff_catalog()
    code_navigation()
    visual_catalog()
    known_gaps()
    print(f"wrote {len(list(OUT.iterdir()))} metadata candidates to {OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
