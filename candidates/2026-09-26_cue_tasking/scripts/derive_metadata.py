#!/usr/bin/env python3
"""Derive candidate copies of the reporting metadata for the 2026-09-26 cue-tasking update.

Reads reporting/metadata/* (never writes them) and writes edited copies to
candidates/2026-09-26_cue_tasking/overlay/metadata/. CSVs are edited as text lines (exact
substring replacements and appended rows) so the diff against the accepted files stays minimal.
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
BRANCH = "reporting/candidates-cue-tasking"

R02_OLD, R02_NEW = "02_HardwareAndCollection_V4.html", "02_HardwareAndCollection_V5.html"
R06_OLD, R06_NEW = "06_StatusAndFutureWork_V2.html", "06_StatusAndFutureWork_V3.html"
SYS = "SystemArchitectureAndCueTasking_V1.html"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text: str, old: str, new: str, name: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{name}: expected one match, found {count}: {old[:80]!r}")
    return text.replace(old, new)


def manifest() -> None:
    data = json.loads((SRC / "family_manifest.json").read_text(encoding="utf-8"))
    hashes = {
        R02_NEW: sha256(OVERLAY / "reports" / R02_NEW),
        R06_NEW: sha256(OVERLAY / "reports" / R06_NEW),
    }
    for report in data["reports"]:
        if report["report_id"] == "02":
            report.update(
                latest_version=R02_NEW, accepted_version=R02_NEW, canonical_filename=R02_NEW,
                source_hash=hashes[R02_NEW], release_hash=None,
            )
        if report["report_id"] == "06":
            report.update(
                latest_version=R06_NEW, accepted_version=R06_NEW, canonical_filename=R06_NEW,
                source_hash=hashes[R06_NEW], release_hash=None,
                strongest_result=(
                    "Map-contract verification and collection/reference qualification remain independent "
                    "blockers; the ADS-B cue interface is verified as infrastructure only."
                ),
            )
    for entry in data["source_report_hashes"]:
        new = {"02": R02_NEW, "06": R06_NEW}.get(entry["ReportID"])
        if new:
            entry.update(
                Filename=new,
                SourcePath=f"flightTest branch {BRANCH}: candidates/2026-09-26_cue_tasking/overlay/reports/{new}",
                SourceSHA256=hashes[new],
            )
    data["known_gaps"] = data["known_gaps"] + [
        "The ADS-B Pi time source is not GPS/PPS-locked; Pi-timed ADS-B truth before 2026-09-25 21:07 UTC carries an unknown clock offset.",
        "ADS-B cues are verified as a message interface only; no collection has been scheduled from a cue.",
    ]
    data["post_release_changes"] = [
        {
            "date": "2026-09-26",
            "change": "Reports 02 and 06 replaced by V5 and V3 through the candidate review in "
            f"flightTest branch {BRANCH}; no TechnicalSummaryFamily release was built for them.",
            "release_hash": "null for the replaced reports until a release is built",
            "companion_reports": [f"systems/{SYS} (outside the canonical family)"],
        }
    ]
    text = json.dumps(data, indent=2, ensure_ascii=False)
    (OUT / "family_manifest.json").write_text(text, encoding="utf-8")  # accepted file has no final newline


def evidence_catalog() -> None:
    name = "family_evidence_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8")
    text = replace_once(
        text,
        '"Channel-role proof, lock/drop evidence, and collection suitability."',
        '"Channel-role proof, lock/drop evidence, collection suitability, and a locked ADS-B time source (V5: Pi clock 14.9 s slow before 2026-09-25 21:07 UTC)."',
        name,
    )
    text = replace_once(text, f"ManagerReport\\{R02_OLD},02 deployment/package visuals,../reports/{R02_OLD}",
                        f"ManagerReport\\{R02_OLD} (V5 candidate: flightTest branch {BRANCH}),02 deployment/package visuals,../reports/{R02_NEW}", name)
    text = replace_once(
        text,
        '"Passing map-contract correction and reviewed collection/reference-path qualification."',
        '"Passing map-contract correction, reviewed collection/reference-path qualification, and a first collection scheduled from an ADS-B cue."',
        name,
    )
    text = replace_once(text, f"ManagerReport\\{R06_OLD},06 blocker/action visuals,../reports/{R06_OLD}",
                        f"ManagerReport\\{R06_OLD} (V3 candidate: flightTest branch {BRANCH}),06 blocker/action visuals,../reports/{R06_NEW}", name)
    (OUT / name).write_text(text, encoding="utf-8")


def handoff_catalog() -> None:
    name = "family_handoff_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8")
    text = replace_once(text, '"Report 02 V4 package/manifests and qualification criteria."',
                        '"Report 02 V5 package/manifests, qualification criteria, and as-built cueing/time state."', name)
    (OUT / name).write_text(text, encoding="utf-8")


def code_navigation() -> None:
    name = "family_code_navigation.csv"
    text = (SRC / name).read_text(encoding="utf-8").rstrip("\n") + "\n"
    rows = [
        'ADS-B cue tasking (CT),"SYS companion; installed state in 02","Publish per-aircraft cues with modeled illuminator opportunities.",'
        "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21/src/adsb_console/cue.py,"
        '"ADSB-remoter feature/passive-radar-cueing @ 55062fc (not on the ADSB-remoter default branch)",'
        '"prediction.py, bistatic.py, cue_config.py, app.py --headless, deploy/, schemas/ 2.0.0 and dictionaries/","dump1090 SBS, DTV emitter table, observer INI, cue config",'
        '"CT 2.0.0 UDP multicast datagrams","SYS Figures 2-4 (from captures)",Release metadata link,Strong,"Inspected; 81 tests re-run 2026-09-26",,'
        '"Record the commit deployed on the Pi in As_Built.md at each update.",P1,"Deployed on the ADS-B Pi as systemd adsb-cue."',
        'Cue capture and verification,"SYS companion",Decode and validate the cue stream and summarise gaps and sizes.,'
        "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21/tools/cue_capture.py,"
        '"ADSB-remoter feature/passive-radar-cueing @ 55062fc","tools/cue_decode.py; tools/build_cue_dictionary.py","Live multicast stream",'
        '"docs/system/evidence/*_wire.jsonl and *_summary.json","SYS Figures 2-4",Release metadata link,Strong,Inspected only,,'
        '"Keep raw wire bytes for every verification capture.",P1,"Evidence files live on flightTest main under docs/system/evidence/."',
        'Cue reception (RM first piece),"SYS companion",Receive and rank cues in MATLAB; no tasking.,'
        "https://github.com/pwilliamMAT/flightTest/tree/94bf9247fc9384fd0601e7ef4654f2a1630485c6/CueListener,"
        '"flightTest feature/adsb-cue-listener @ 94bf924 (not on main)","runCueListener.m, plotCueWindows.m, dictionaries/","CT multicast stream or JSONL log",'
        '"Active cues and opportunity windows","SYS section 8",Release metadata link,Strong,"Inspected; 16 tests re-run 2026-09-26",'
        '"Code is not on main.","Merge CueListener to main or keep the branch link current.",P1,"Java MulticastSocket and java.util.zip; compiled-app probe in docs/system/analysis/deployability/."',
        'System documents,"SYS companion; 02; 06","Architecture, ICD, as-built, change requests, verification log.",'
        "https://github.com/pwilliamMAT/flightTest/tree/ad64bcd3ccd9ffbee023c0e1f13544bd6774c2f2/docs/system,"
        '"flightTest main @ ad64bcd","analysis/ scripts and deployability probe","Owner decisions and captures","Controlled documents","SYS Figure 1",'
        'Release metadata link,Strong,Inspected only,,"None.",P1,"Master copy since 2026-09-26."',
        'Cue-report figure generation,"SYS companion","Reproduce the CT 2.0.0 acceptance numbers and draw SYS Figures 2-4.",'
        f'"summarize_cue_capture.py (candidate branch {BRANCH}; final location to be set by the owner)",'
        f'"flightTest {BRANCH}","derive_*.py candidate scripts","docs/system/evidence captures and dictionary 1","SVG figures and cue_capture_summary.json","SYS Figures 2-4",'
        'Release metadata link,Moderate,"Executed 2026-09-26",'
        '"Final code location not yet decided.","Move the script to docs/system/analysis/ or another controlled location before promotion.",P1,"Cross-checks the committed capture summary."',
    ]
    (OUT / name).write_text(text + "\n".join(rows) + "\n", encoding="utf-8")


def visual_catalog() -> None:
    name = "family_visual_catalog.csv"
    text = (SRC / name).read_text(encoding="utf-8").rstrip("\n") + "\n"
    base = "systems/SystemArchitectureAndCueTasking_assets"
    rows = [
        f'VIS-20,System architecture and as-built status,"SYS companion","Functional architecture with as-built status",systems/{SYS} (inline SVG),'
        '"docs/system System_Architecture.md, ICD_Messages.md, As_Built.md",Which items exist and which link is verified,"One verified link",'
        'Separate designed from built,Strong,Current,Yes,Yes,,,Keep inline and update with As_Built,P1,Source-backed schematic; no performance content.',
        f'VIS-21,Message size before and after CR-5,"SYS companion","Median bytes per message",{base}/fig_message_size.svg,'
        '"docs/system/evidence captures 20260926T1234Z and T1523Z",Why compression was needed,"7,962 B to 681 B per cue",'
        'Justify the encoding decision,Strong,Current,Yes,Yes,,,Regenerate with summarize_cue_capture.py,P1,Measured message sizes.',
        f'VIS-22,One-frame fit of every cue,"SYS companion","track_cue bytes against opportunities",{base}/fig_cue_size_vs_opportunities.svg,'
        '"docs/system/evidence capture 20260926T1523Z",Whether every cue fits one frame,"0 of 223 over 1472 B; max 747 B",'
        'Accept the interface,Strong,Current,Technical reference,Yes,,,Regenerate with summarize_cue_capture.py,P2,Measured message interface; not radar evidence.',
        f'VIS-23,Live capture timeline,"SYS companion","What arrived, and when",{base}/fig_capture_timeline.svg,'
        '"docs/system/evidence capture 20260926T1523Z",Snapshot and heartbeat regularity,"15 snapshots consistent",'
        'Accept the interface,Strong,Current,Technical reference,Yes,,,Regenerate with summarize_cue_capture.py,P2,Measured message interface; not radar evidence.',
    ]
    (OUT / name).write_text(text + "\n".join(rows) + "\n", encoding="utf-8")


def known_gaps() -> None:
    name = "family_known_gaps.md"
    text = (SRC / name).read_text(encoding="utf-8")
    text = replace_once(
        text,
        "- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation.\n",
        "- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation.\n"
        "\n## Added 2026-09-26 (cue-tasking update)\n\n"
        "- The ADS-B Pi time source is not GPS/PPS-locked. It keeps time from internet NTP through the collection desktop; before 2026-09-25 21:07 UTC the Pi was measured 14.9 s slow, so Pi-timed ADS-B truth from earlier collections carries an unknown offset (Report 02 V5 TIME-001; Report 06 V3 STAT-010).\n"
        "- The ADS-B cue interface is verified as a message interface only. The Resource Manager does not schedule collections, and no collection has been made from a cue (Report 06 V3 STAT-009, STAT-012).\n"
        "- The truth-separation rule for cue-selected collections and cue-aided association is not yet written down.\n"
        "- Predicted SNR in cues is a modeled, pre-integration ranking estimate and has not been reconciled with the Report 01A/01B models.\n"
        "- CueListener and the DTV level-check scripts are not on `main`; the Cue Tasker code is on an ADSB-remoter feature branch.\n",
        name,
    )
    text = replace_once(
        text,
        "No unresolved P0 item is hidden.",
        "No unresolved P0 item is hidden. Reports 02 V5 and 06 V3 were accepted after release 20260921_181348 without a new TechnicalSummaryFamily release; the builder and verifier still name 02 V4 and 06 V2.",
        name,
    )
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
