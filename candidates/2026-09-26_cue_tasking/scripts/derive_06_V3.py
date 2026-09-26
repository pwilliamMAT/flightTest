#!/usr/bin/env python3
"""Derive candidate 06_StatusAndFutureWork_V3.html from the accepted V2 by explicit, reviewable edits.

Every change is an exact (old -> new) replacement or insertion listed below, so the reviewer can see
the whole delta between the accepted V2 and the candidate. The accepted V2 is read, never written.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/derive_06_V3.py
"""

from __future__ import annotations

from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
SOURCE = REPO / "reporting" / "reports" / "06_StatusAndFutureWork_V2.html"
TARGET = CANDIDATE / "overlay" / "reports" / "06_StatusAndFutureWork_V3.html"

SYS = "../system/SDR_CT_CueTasking_V1.html"
SYSIDX = "../system/index.html"
TRUTH = "../system/06_TruthSeparation.html"
TRACK_DIAG = "../diagnostics/TrackingScan_NoDetection_Diagnostic_V1.html"
PLUTO_DIAG = "../diagnostics/PlutoCombPresence_Diagnostic_V1.html"
GH = "https://github.com/pwilliamMAT/flightTest/blob/ad64bcd3ccd9ffbee023c0e1f13544bd6774c2f2/docs/system"

NEW_SECTION = f"""
<section id="changes">
<h2>What changed since V2</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Between 18 and 26 September the program gained a written system design and its first live, checked link between two parts: an ADS-B “bell ringer” that tells the collection side which aircraft to collect on. That is useful plumbing. It does not change the map-contract or collection-suitability blockers below, and a live-aircraft scan on 25 September still found no truth-matched detection.</p>
<div class="table-wrap">
<table class="decision-table">
<thead><tr><th style="width:12%">Evidence ID</th><th style="width:20%">Change</th><th style="width:13%">Status</th><th style="width:28%">Quantitative anchor</th><th>What it does not change</th></tr></thead>
<tbody>
<tr><td><span class="evidence-id">STAT-009</span></td><td>ADS-B cue interface (Cue Tasker → Resource Manager), CT messages 2.0.0</td><td><span class="tag demonstrated">Demonstrated</span></td><td>Live capture 2026-09-26 15:23–15:38 UTC: 223 datagrams, 0 schema failures, 0 sequence gaps, none over one Ethernet frame (largest 747 B); 103 cues from 11 aircraft. ICD status Verified.</td><td>A message-interface result only. No collection was scheduled from a cue, and no detection is implied.</td></tr>
<tr><td><span class="evidence-id">STAT-010</span></td><td>Time source on the ADS-B Pi</td><td><span class="tag implemented">Implemented</span></td><td>Internet NTP accepted by the owner (2026-09-26); accepted tolerance 0.1 s between the Pi and the collection desktop (set from one check at +0.05 to +0.09 s). GPS/PPS not locked: hardware to-do (reseat a suspected loose component), not a blocker for NTP timing. Before 2026-09-25 21:07 UTC the Pi was 14.9 s slow.</td><td>ADS-B truth written by the Pi before 2026-09-25 21:07 UTC carries an unknown clock offset; its re-check, including the 2026-09-25 tracking scan, stays open. This adds to, and does not replace, the ADS-B timing policy that STAT-006 requires.</td></tr>
<tr><td><span class="evidence-id">STAT-011</span></td><td>Live-aircraft tracking scan, 2026-09-25 (diagnostic, outside the family)</td><td><span class="tag investigated">Investigated</span></td><td>One overlapping ADS-B aircraft matched once in 75 opportunities; 91% of 34,054 detections were 60 Hz hum lines; no truth-matched track. See the <a href="{TRACK_DIAG}">tracking-scan diagnostic</a>.</td><td>It is diagnostic evidence with its own claim boundary; it neither opens nor closes a formal gate.</td></tr>
<tr><td><span class="evidence-id">STAT-012</span></td><td>Cue-driven collection (Resource Manager scheduling)</td><td><span class="tag progress">In Progress</span></td><td>First piece built (MATLAB CueListener: receives and ranks cues, 16 of 16 tests); it stays on branch <code>feature/adsb-cue-listener</code> with a review action for Pat. <code>collection_task</code> and all downstream messages are still Proposed.</td><td>Collections are still started by hand. Scheduling is enabling infrastructure, not a detection or suitability result.</td></tr>
<tr><td><span class="evidence-id">STAT-013</span></td><td>Truth separation for cued collections</td><td><span class="tag progress">In Progress</span></td><td>Owner confirmed on 2026-09-26 that cues now choose when and with which tower to collect, and that the Tracker may use cues to help association. Rule accepted as CR-9 (2026-09-26), amended for sites with several emitters and for captures widened to about 12 MHz: the cued/uncued label covers the whole capture, every product records its emitter and its <code>truth_blind</code>/<code>cue_aided</code> label, and products on other emitters of a cued collection are still conditional on the cue. See <a href="{TRUTH}">the rule</a>.</td><td>Labels not yet implemented (the ICD messages that carry them are still Proposed). No cued collection exists yet; when one does, only truth-blind products count as independent detection evidence.</td></tr>
</tbody>
</table>
</div>
<div class="callout warn"><strong>Carried forward unchanged:</strong> STAT-001 to STAT-008 repeat the 2026-09-18 evidence of V2. They were not re-verified for this update. The system architecture, the draft requirements, the interface control document, and the cue-interface evidence are presented in the separate <a href="{SYSIDX}">System Engineering section</a>, which owns those claims; the cue-interface evidence is in its <a href="{SYS}">CT subsystem record</a>.</div>
<p class="source">Primary evidence: <a href="{GH}/README.md">system README and message status register</a>, <a href="{GH}/Verification_Log.md">Verification Log</a>, <a href="{GH}/As_Built.md">As-Built</a>, <a href="{GH}/Change_Requests.md">CR-8</a>, <a href="{TRACK_DIAG}">tracking-scan diagnostic</a>, <a href="{SYSIDX}">System Engineering section</a> (decisions and actions of 2026-09-26).</p>
</section>
"""

EDITS: list[tuple[str, str]] = [
    ("<title>Status and Future Work — V2</title>", "<title>Status and Future Work — V3</title>"),
    (
        "standalone evidence report, V2 executive-readability and traceability enhancement</p>",
        "standalone evidence report, V3 status update</p>",
    ),
    (
        '<p class="small">Status snapshot: 18 September 2026. V2 preserves the underlying evidence and boundaries while adding executive scanning, evidence IDs, and cross-report navigation.',
        '<p class="small">Status snapshot: 26 September 2026 for the system architecture, ADS-B cue tasking, time source, and live-aircraft diagnostic (STAT-009 to STAT-013); 18 September 2026 for STAT-001 to STAT-008, which V3 carries forward from V2 unchanged. V3 also corrects the Report 02 and Report 05 links.',
    ),
    (
        '<a href="#purpose">Purpose</a><a href="#executive-summary">Executive summary</a>',
        '<a href="#purpose">Purpose</a><a href="#executive-summary">Executive summary</a><a href="#changes">Since V2</a>',
    ),
    (
        "verification of one bounded correction candidate and collection-readiness evidence before any downstream advancement.</p>",
        "verification of one bounded correction candidate and collection-readiness evidence before any downstream advancement. <strong>New in V3:</strong> the ADS-B cue interface that will task future collections is verified as infrastructure, internet NTP is accepted as the Pi time source (GPS/PPS lock is a hardware to-do), a truth-separation rule for cued collections is accepted, and a 25 September live-aircraft scan found no truth-matched track; none of these changes the blockers (see What changed since V2). <span class=\"evidence-id\">STAT-009</span> <span class=\"evidence-id\">STAT-010</span> <span class=\"evidence-id\">STAT-011</span> <span class=\"evidence-id\">STAT-013</span></p>",
    ),
    # Insert the new section before the evidence matrix.
    ('<section id="evidence-strength">', NEW_SECTION.strip() + '\n\n<section id="evidence-strength">'),
    # Evidence matrix rows.
    (
        "<td>Reviewed candidate requires bounded adoption decision and controlled R4 verification.</td><td>Defines the next evidence step; does not authorize a replacement matrix.</td></tr>",
        "<td>Reviewed candidate requires bounded adoption decision and controlled R4 verification.</td><td>Defines the next evidence step; does not authorize a replacement matrix.</td></tr>\n"
        '<tr><td><span class="evidence-id">STAT-009</span></td><td>ADS-B cue interface</td><td><span class="status-chip status-demonstrated">Demonstrated</span></td><td>223 datagrams, 0 schema failures, 0 gaps, all within one frame (2026-09-26).</td><td>Message delivery to the collection side; not scheduling, collection, or detection.</td></tr>\n'
        '<tr><td><span class="evidence-id">STAT-010</span></td><td>Pi time source</td><td><span class="status-chip status-implemented">Implemented</span></td><td>Internet NTP accepted; tolerance 0.1 s (accepted); Pi 14.9 s slow before 2026-09-25 21:07 UTC.</td><td>GPS/PPS lock is a hardware to-do; earlier Pi-timed ADS-B truth has an unknown offset until re-checked.</td></tr>\n'
        '<tr><td><span class="evidence-id">STAT-011</span></td><td>Live-aircraft tracking scan</td><td><span class="status-chip status-investigated">Investigated</span></td><td>1 of 75 truth opportunities matched; 91% of detections at ±60 Hz.</td><td>Diagnostic only; no truth-matched track and no gate change.</td></tr>\n'
        '<tr><td><span class="evidence-id">STAT-012</span></td><td>Cue-driven collection</td><td><span class="status-chip status-progress">In Progress</span></td><td>Resource Manager receives and ranks cues; <code>collection_task</code> is Proposed.</td><td>No collection has been scheduled from a cue.</td></tr>\n'
        '<tr><td><span class="evidence-id">STAT-013</span></td><td>Truth separation for cued collections</td><td><span class="status-chip status-progress">In Progress</span></td><td>Rule accepted as CR-9 with the multi-emitter amendment; labels not yet implemented.</td><td>Only truth-blind products of a cued collection will count as independent evidence, and their rates are conditional on the cue.</td></tr>',
    ),
    # Capability matrix.
    (
        '<article><h3>Localization</h3><span class="status-chip status-blocked">Blocked</span><p>Requires validated Measurements and suitable multi-observation geometry. <span class="evidence-id">STAT-007</span></p></article>',
        '<article><h3>Localization</h3><span class="status-chip status-blocked">Blocked</span><p>Requires validated Measurements and suitable multi-observation geometry. <span class="evidence-id">STAT-007</span></p></article>\n'
        '<article><h3>Cue Tasking</h3><span class="status-chip status-demonstrated">Demonstrated</span><p>ADS-B cues reach the collection side intact; message interface only. <span class="evidence-id">STAT-009</span></p></article>\n'
        '<article><h3>Collection Scheduling</h3><span class="status-chip status-progress">In Progress</span><p>Cues are received and ranked; no collection is tasked from them yet. <span class="evidence-id">STAT-012</span></p></article>\n'
        '<article><h3>Time Source</h3><span class="status-chip status-implemented">Implemented</span><p>Internet NTP accepted (0.1 s tolerance); GPS/PPS lock is a hardware to-do. <span class="evidence-id">STAT-010</span></p></article>\n'
        '<article><h3>Live-Aircraft Detection</h3><span class="status-chip status-investigated">Investigated</span><p>2026-09-25 scan: no truth-matched track (diagnostic). <span class="evidence-id">STAT-011</span></p></article>',
    ),
    (
        "<div><h3>Next Required Evidence</h3><p>Controlled R4 correction verification and reviewed collection/reference-chain timing/geometry evidence precede any downstream advancement.",
        "<div><h3>Next Required Evidence</h3><p>Controlled R4 correction verification and reviewed collection/reference-chain timing/geometry evidence precede any downstream advancement. Cue-driven scheduling, the truth-separation rule, and the time-source to-dos are enabling work in parallel, not substitutes. <span class=\"evidence-id\">STAT-010</span> <span class=\"evidence-id\">STAT-012</span> <span class=\"evidence-id\">STAT-013</span>",
    ),
    # Report 02 link corrections (V2 pointed at the superseded V3 file).
    (
        '<p>Report <a href="02_HardwareAndCollection_V3.html">02_HardwareAndCollection_V3.html — Hardware and Collection Infrastructure</a> contains',
        '<p>Report <a href="02_HardwareAndCollection_V5.html">02_HardwareAndCollection_V5.html — Hardware and Collection Infrastructure</a> contains',
    ),
    ('<a href="02_HardwareAndCollection_V3.html">S06-12 Report 02</a>', '<a href="02_HardwareAndCollection_V5.html">S06-12 Report 02</a>'),
    ('<li><a href="02_HardwareAndCollection_V3.html">02 — What did we build?</a></li>', '<li><a href="02_HardwareAndCollection_V5.html">02 — What did we build?</a></li>'),
    (
        "<li>05 — What does the strongest evidence say? (report not linked here because no local Report 05 file is available.)</li>",
        '<li><a href="05_StrongestEvidence_G4RRecoveryStudy.html">05 — What does the strongest evidence say?</a></li>',
    ),
    (
        '<tr><td>What was built and collected?</td><td><a href="02_HardwareAndCollection_V3.html">02_HardwareAndCollection_V3.html — Hardware and Collection Infrastructure</a></td>',
        '<tr><td>What was built and collected?</td><td><a href="02_HardwareAndCollection_V5.html">02_HardwareAndCollection_V5.html — Hardware and Collection Infrastructure</a></td>',
    ),
    # Blocked section: two boundaries added.
    (
        "<li>Truth remains post hoc; it cannot steer Passive Map formation, thresholding, or nonmaximum suppression.</li>",
        "<li>Truth remains post hoc; it cannot steer Passive Map formation, thresholding, or nonmaximum suppression.</li>"
        f"<li>ADS-B cues may choose when and on which illuminator to collect, and the Tracker may use cues to help association. The accepted rule (CR-9, <a href=\"{TRUTH}\">truth separation</a>) labels every capture as a whole, and every product by its emitter and by whether cues entered its processing; only truth-blind products count as independent evidence, and detection probability on cued data is conditional on the cue. <span class=\"evidence-id\">STAT-013</span></li>"
        "<li>“Verified” for the cue messages is an interface-control status, not a radar result. <span class=\"evidence-id\">STAT-009</span></li>",
    ),
    (
        "<div class=\"callout stop\"><strong>This report does not claim <span class=\"evidence-id\">STAT-007</span>:</strong> live-aircraft radar detection;",
        "<div class=\"callout stop\"><strong>This report does not claim <span class=\"evidence-id\">STAT-007</span> <span class=\"evidence-id\">STAT-009</span>:</strong> that a predicted cue opportunity or SNR will yield a detection; accurate Pi-timed ADS-B truth before 2026-09-25; live-aircraft radar detection;",
    ),
    # Management recommendation table: one new row.
    (
        '<tr><td><span class="evidence-id">STAT-007</span> Future Tracking / Localization</td>',
        '<tr><td><span class="evidence-id">STAT-010</span> <span class="evidence-id">STAT-012</span> <span class="evidence-id">STAT-013</span> Cueing and timing infrastructure</td><td>Decided 2026-09-26: internet NTP with the accepted 0.1 s tolerance; CR-9 truth-separation rule accepted with the multi-emitter amendment. Actions — Leif (system, RF, integration): reseat the GPS/PPS component (hardware to-do); design Resource Manager scheduling and <code>collection_task</code> with <code>cue_ref</code>; add the CR-9 labels, emitter list and capture bandwidth to the ICD. Pat: review the CueListener branch; re-check earlier ADS-B timing, including the 25 September tracking scan; add a repeatable clock check.</td><td>Cue interface Verified live (STAT-009); Pi clock was 14.9 s slow before NTP; <code>collection_task</code> is Proposed.</td><td>CR-9 labels in the ICD, a repeatable clock check, and a first collection scheduled from a cue and linked to it.</td><td>Enabling work; it does not relieve the map-contract or R5B collection-suitability blockers.</td></tr>\n'
        '<tr><td><span class="evidence-id">STAT-007</span> Future Tracking / Localization</td>',
    ),
    # Local evidence navigation: companion material.
    (
        "<tr><td>How do the gates fit together?</td>",
        f'<tr><td><span class="evidence-id">STAT-009</span> <span class="evidence-id">STAT-013</span> How is the system designed, and what does the cue interface prove?</td><td><a href="{SYSIDX}">System Engineering section</a> and its <a href="{SYS}">CT subsystem record</a></td><td>Mission goals, draft requirements, architecture, ICD, verification and traceability, truth separation, as-built state, and the live cue verification.</td></tr>\n'
        f'<tr><td><span class="evidence-id">STAT-011</span> What happened on the latest live-aircraft attempts?</td><td><a href="{TRACK_DIAG}">Tracking-scan diagnostic</a> and <a href="{PLUTO_DIAG}">Pluto calibration-signal diagnostic</a></td><td>Hardware and detection troubleshooting evidence outside the family, each with its own boundary.</td></tr>\n'
        "<tr><td>How do the gates fit together?</td>",
    ),
    # Glossary.
    (
        "<dt>ADS-B</dt><dd>Broadcast aircraft-surveillance data used here as post-hoc timing and geometry context, not to steer the detector.</dd>",
        "<dt>ADS-B</dt><dd>Broadcast aircraft-surveillance data used here as post-hoc timing and geometry context, not to steer the detector. Since 2026-09 it also feeds the Cue Tasker, which may select collection opportunities but must not steer map formation, thresholding, or detection.</dd>\n"
        "<dt>Cue Tasker (CT)</dt><dd>The service on the ADS-B Raspberry Pi that publishes one cue per aircraft: predicted path and up to eight ranked (receive site, DTV illuminator) opportunities with modeled, pre-integration SNR windows.</dd>",
    ),
    # Source inventory: remove the unpublished CSV link; add new sources.
    (
        '<p>The companion file <a href="06_StatusAndFutureWork_source_inventory.csv">06_StatusAndFutureWork_source_inventory.csv</a> provides the complete source inventory.',
        "<p>The companion file <code>06_StatusAndFutureWork_source_inventory.csv</code> (retained in the ManagerReport archive, not published on this site) provides the complete V2 source inventory.",
    ),
    (
        "<tr><td>S06-12–S06-14</td><td>Reports 02, 03, and 04</td><td>Scope-controlled cross-references; this report does not duplicate their evidence.</td></tr>",
        "<tr><td>S06-12–S06-14</td><td>Reports 02, 03, and 04</td><td>Scope-controlled cross-references; this report does not duplicate their evidence.</td></tr>\n"
        f'<tr><td>S06-15</td><td><a href="{GH}/README.md">flightTest docs/system</a> at <code>ad64bcd</code>: README, As_Built, Change_Requests (CR-8), Verification_Log, ICD Draft B</td><td>STAT-009, STAT-010, STAT-012.</td></tr>\n'
        f'<tr><td>S06-16</td><td><a href="{SYSIDX}">System Engineering section</a> and <a href="{SYS}">SDR-CT V1</a></td><td>Owner of the architecture, requirements, truth-separation and cue-interface claims summarised here; decisions and actions of 2026-09-26.</td></tr>\n'
        f'<tr><td>S06-17</td><td><a href="{TRACK_DIAG}">Tracking-scan no-detection diagnostic V1</a></td><td>STAT-011.</td></tr>',
    ),
    (
        "All claims are bounded to the cited evidence as of 2026-09-18.</p>",
        "Claims STAT-001 to STAT-008 are bounded to the cited evidence as of 2026-09-18; STAT-009 to STAT-013 as of 2026-09-26.</p>",
    ),
]


def main() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    for old, new in EDITS:
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"expected exactly one match, found {count}: {old[:80]!r}")
        text = text.replace(old, new)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding="utf-8")
    print(f"wrote {TARGET.relative_to(REPO)} ({len(EDITS)} edits)")


if __name__ == "__main__":
    main()
