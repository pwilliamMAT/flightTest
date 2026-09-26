#!/usr/bin/env python3
"""Derive candidate 02_HardwareAndCollection_V5.html from the accepted V4 by explicit, reviewable edits.

V5 adds the installed ADS-B cueing service and the as-built time-source state, and turns the four
links to unpublished CSV companions into plain text. Everything else, including the embedded
photographs and the ../HardwarePhotos links, is carried over byte for byte. The accepted V4 is read,
never written.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/derive_02_V5.py
"""

from __future__ import annotations

import re
from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
SOURCE = REPO / "reporting" / "reports" / "02_HardwareAndCollection_V4.html"
TARGET = CANDIDATE / "overlay" / "reports" / "02_HardwareAndCollection_V5.html"

SYS = "../system/SDR_CT_CueTasking_V1.html"
SYSIDX = "../system/index.html"
ASBUILT = "../system/07_AsBuiltAndConfiguration.html"
GH = "https://github.com/pwilliamMAT/flightTest/blob/ad64bcd3ccd9ffbee023c0e1f13544bd6774c2f2/docs/system"
CT = "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21"

NEW_SECTION = f"""
<section id="cueing">
<h2>5A. Installed cueing and time infrastructure (added in V5)</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> The ADS-B Raspberry Pi now also runs a service that tells the collection desktop, over the data network, which aircraft could be worth collecting on. Collections are still started by hand. Setting it up also showed that the Pi’s clock, which timestamps the ADS-B truth, had been about 15 seconds slow; it now keeps time from internet NTP, which the owner has accepted.</p>
<div class="technical">
<p>The ADS-B Cue Tasker runs on the same Raspberry Pi as dump1090 and the ADS-B/GPS loggers, as the systemd service <code>adsb-cue</code> (headless <code>adsb-console</code>, enabled at boot, restarted by systemd if dump1090 is not yet up). It publishes one compressed JSON message per UDP datagram to the multicast group <code>239.192.10.1:31986</code> with TTL 1, so only hosts on the rooftop data network receive it. Its observer configuration holds only the real receive site. On the collection desktop the MATLAB <code>CueListener</code> receives and ranks the cues; it does not start captures, and the coordinated capture workflow in section 5 is unchanged. <span class="evidence-key">CUE-001</span></p>
<p>The architecture designs the Pi as a stratum-0 time source with GPS and 1-PPS. As built on 2026-09-26, chrony on the Pi keeps time from internet NTP through a NAT on the collection desktop; the GPS/PPS reference clocks are configured but not locked. The owner accepted internet NTP as the time source on 2026-09-26, with an accepted tolerance of 0.1 s between the Pi and the collection desktop (set from the one check, +0.05 to +0.09 s). GPS/PPS lock is a hardware to-do (a loose component is suspected), not a blocker for NTP-based timing. On 2026-09-25, before the NTP route existed, the Pi was measured 14.9 s slow with chrony unsynchronised. The N320 capture timestamps come from the desktop’s NTP clock, while the ADS-B records are timestamped on the Pi, so an error in the Pi clock is an error in the IQ-to-ADS-B alignment. <span class="evidence-key">TIME-001</span></p>
</div>
<div class="table-wrap">
<table class="decision-table">
<thead><tr><th style="width:20%">Element</th><th style="width:15%">Status</th><th style="width:33%">Evidence (class)</th><th>Boundary</th></tr></thead>
<tbody>
<tr><td><span class="evidence-key">CUE-001</span> ADS-B cue service on the Pi</td><td><span class="status-chip implemented">Implemented</span></td><td>As-built record and deployed unit and configuration files (installed). Live cue stream checked on 2026-09-26: 223 datagrams, 0 schema failures, 0 gaps (measured, message interface).</td><td>Infrastructure only. No capture has been started from a cue; the cue content is a modeled ranking, not a detection prediction.</td></tr>
<tr><td><span class="evidence-key">TIME-001</span> Time source on the Pi</td><td><span class="status-chip implemented">Implemented</span></td><td>Internet NTP via the desktop, synchronised 2026-09-25 21:07 UTC and accepted 2026-09-26 with a 0.1 s tolerance (installed); GPS/PPS configured, not locked: hardware to-do. Pi 14.9 s slow before that, one reading, raw data not kept (measured).</td><td>ADS-B truth written by the Pi before 2026-09-25 21:07 UTC, including the ADS-B artifacts in the historical packages of section 6, carries an unknown clock offset. Whether any package was affected has not been assessed; the re-check stays open.</td></tr>
</tbody>
</table>
</div>
<div class="callout warn"><strong>Qualification consequence:</strong> the CTRL-001 acceptance criteria in section 9 do not yet include a check of the ADS-B host clock against the capture host clock. The draft requirements baseline proposes one: a repeatable host-clock check against the 0.1 s tolerance (DR-TIME-1) and the time-sync state of every timestamping host recorded with each collection (DR-TIME-2); see the <a href="{SYSIDX}">System Engineering section</a>. <span class="evidence-key">TIME-001</span></div>
<p class="source">Primary evidence: <a href="{GH}/As_Built.md">As-Built record</a>, <a href="{GH}/Change_Requests.md">CR-8</a>, <a href="{GH}/Verification_Log.md">Verification Log</a>, <a href="{CT}/deploy/adsb-cue.service">service unit</a>, <a href="{CT}/deploy/pi-cue-config.json">deployed cue configuration</a>. Architecture, requirements, message contract, and cue verification are presented in the <a href="{SYSIDX}">System Engineering section</a>; see its <a href="{ASBUILT}">as-built page</a> and <a href="{SYS}">CT subsystem record</a>.</p>
</section>
"""

EDITS: list[tuple[str, str]] = [
    (
        "<title>Hardware and Collection Infrastructure — V4</title>",
        "<title>Hardware and Collection Infrastructure — V5</title>",
    ),
    (
        "standalone evidence report, V4 audit-stabilization enhancement</p>",
        "standalone evidence report, V5 cueing and time-source update</p>",
    ),
    (
        '<p class="small">Status snapshot: 18 September 2026. V4 retains',
        '<p class="small">Status snapshot: 18 September 2026, except section 5A and the CUE-001 and TIME-001 rows, which are as of 26 September 2026. V5 adds the installed ADS-B cueing service and the as-built time-source state to V4 without changing its other content. V4 retains',
    ),
    ('<a href="#provenance">Provenance</a>', '<a href="#cueing">Cueing &amp; time</a>\n<a href="#provenance">Provenance</a>'),
    (
        '<tr><td>GPS/NMEA support</td><td><span class="status-chip implemented">Implemented</span></td><td>S06 separate GPS/NMEA logger implementation.</td><td>Not present in the sampled historical package.</td></tr>',
        '<tr><td>GPS/NMEA support</td><td><span class="status-chip implemented">Implemented</span></td><td>S06 separate GPS/NMEA logger implementation.</td><td>Not present in the sampled historical package.</td></tr>\n'
        '<tr><td>ADS-B cue service (V5)</td><td><span class="status-chip implemented">Implemented</span></td><td><span class="evidence-key">CUE-001</span>: <code>adsb-cue</code> on the Pi publishes cues to the data network; see section 5A.</td><td>Captures are not started from cues; no detection claim.</td></tr>\n'
        '<tr><td>Time source (V5)</td><td><span class="status-chip implemented">Implemented</span></td><td><span class="evidence-key">TIME-001</span>: internet NTP accepted (0.1 s tolerance); GPS/PPS lock is a hardware to-do; Pi 14.9 s slow before 2026-09-25 21:07 UTC.</td><td>Pi-timed ADS-B truth before that time carries an unknown offset until re-checked.</td></tr>',
    ),
    ('<section id="provenance">', NEW_SECTION.strip() + '\n\n<section id="provenance">'),
    (
        "<div class=\"pendingstep\"><strong>GPS and ADS-B readiness are separate questions.</strong> ADS-B files are packaged historically, while the GPS/NMEA logger is not shown in the sampled manifests.",
        "<div class=\"pendingstep\"><strong>GPS and ADS-B readiness are separate questions.</strong> ADS-B files are packaged historically, while the GPS/NMEA logger is not shown in the sampled manifests. V5: the Pi that timestamps ADS-B was 14.9 s slow before 2026-09-25 21:07 UTC; it now keeps time from internet NTP (accepted, 0.1 s tolerance), and its GPS/PPS reference is still not locked (section 5A).",
    ),
    (
        "<tr><td>V4</td><td>18 Sep 2026</td><td>Qualification acceptance criteria, channel-role assignment boundary, and audit-stabilization improvements.</td></tr>",
        "<tr><td>V4</td><td>18 Sep 2026</td><td>Qualification acceptance criteria, channel-role assignment boundary, and audit-stabilization improvements.</td></tr>\n"
        "<tr><td>V5</td><td>26 Sep 2026</td><td>Section 5A: installed ADS-B cue service and as-built time source (CUE-001, TIME-001; internet NTP accepted, GPS/PPS a hardware to-do); links to unpublished CSV companions shown as plain text.</td></tr>",
    ),
    (
        '<article class="card"><h3>Readiness and control</h3><ul class="plain-list">',
        f'<article class="card"><h3>Cueing and time (V5)</h3><ul class="plain-list"><li><a href="{GH}/As_Built.md">As-Built record</a></li><li><a href="{GH}/Verification_Log.md">Verification Log</a></li><li><a href="{SYSIDX}">System Engineering section</a></li></ul></article>\n'
        '<article class="card"><h3>Readiness and control</h3><ul class="plain-list">',
    ),
]

# Companion CSVs referenced by V4 are not published under reporting/reports; show them as text.
UNPUBLISHED = [
    "02_HardwareAndCollection_V4_evidence_register.csv",
    "hardware_photo_inventory.csv",
    "updated_figure_inventory.csv",
    "updated_source_inventory.csv",
]


def main() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    for old, new in EDITS:
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"expected exactly one match, found {count}: {old[:80]!r}")
        text = text.replace(old, new)
    unlinked = 0
    for name in UNPUBLISHED:
        pattern = re.compile(r'<a href="' + re.escape(name) + r'">(.*?)</a>', re.S)
        text, n = pattern.subn(
            r'<span title="Companion file retained in the ManagerReport archive; not published on this site">\1</span>',
            text,
        )
        unlinked += n
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding="utf-8")
    print(f"wrote {TARGET.relative_to(REPO)} ({len(EDITS)} edits, {unlinked} unpublished-CSV links shown as text)")


if __name__ == "__main__":
    main()
