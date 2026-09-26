#!/usr/bin/env python3
"""Build the System Engineering section pages (candidate) for the reporting site.

The section presents the system design process: mission and needs, requirements, architecture
and allocation, interfaces, verification and traceability, truth separation, as-built and
configuration, and subsystem design records. The masters stay in flightTest docs/system; the
pages summarise and link to them. The requirements tables are parsed from
docs/system/Requirements.md, so the page cannot drift from the master.

Writes candidates/2026-09-26_cue_tasking/overlay/system/*.html and README.md, and refreshes the
section navigation inside the subsystem design record(s). Reads, never writes, reporting/.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/build_system_section.py
"""

from __future__ import annotations

import html
import re
from collections import Counter
from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
OUT = CANDIDATE / "overlay" / "system"
FRAGMENTS = CANDIDATE / "scripts" / "fragments"
REQUIREMENTS = REPO / "docs" / "system" / "Requirements.md"
SDR_PAGES = ["SDR_CT_CueTasking_V1.html"]

MAIN = "https://github.com/pwilliamMAT/flightTest/blob/main/docs/system"
MAIN_TREE = "https://github.com/pwilliamMAT/flightTest/tree/main/docs/system"
PIN = "https://github.com/pwilliamMAT/flightTest/blob/ad64bcd3ccd9ffbee023c0e1f13544bd6774c2f2/docs/system"
SITE = "https://pwilliammat.github.io/flightTest"
CUE_BRANCH = "https://github.com/pwilliamMAT/flightTest/tree/feature/adsb-cue-listener"
CUE_PIN = "https://github.com/pwilliamMAT/flightTest/tree/94bf9247fc9384fd0601e7ef4654f2a1630485c6/CueListener"
CT_REPO = "https://github.com/lhilleMAT2022/ADSB-remoter"
CT_PIN = "https://github.com/lhilleMAT2022/ADSB-remoter/blob/55062fc8a4ccacbcb7cedb5dfe8cdbe7a23c8f21"
SNAPSHOT = "26 September 2026"

PAGES = [
    ("index.html", "0", "Process and status"),
    ("01_MissionAndNeeds.html", "1", "Mission and needs"),
    ("02_Requirements.html", "2", "Requirements (DRAFT)"),
    ("03_ArchitectureAndAllocation.html", "3", "Architecture and allocation"),
    ("04_Interfaces.html", "4", "Interfaces"),
    ("05_VerificationAndTraceability.html", "5", "Verification and traceability"),
    ("06_TruthSeparation.html", "6", "Truth separation"),
    ("07_AsBuiltAndConfiguration.html", "7", "As-built and configuration"),
    ("SDR_CT_CueTasking_V1.html", "SDR", "Subsystem record: CT"),
]

# --------------------------------------------------------------------------- styling

BASE_CSS = """:root{--ink:#172033;--muted:#526176;--line:#cbd5e1;--panel:#f8fafc;--blue:#0f4c81;--blue2:#eaf3fb;--green:#166534;--green2:#ecfdf3;--amber:#9a5b00;--amber2:#fff7e6;--red:#a61b1b;--red2:#fff1f1;--purple:#6d28d9;--purple2:#f5f3ff}
*{box-sizing:border-box}body{max-width:1240px;margin:2rem auto;padding:0 1rem 3rem;color:var(--ink);background:#fff;font:16px/1.52 "Segoe UI",Arial,sans-serif}h1,h2,h3{line-height:1.22;color:#102a43}h1{font-size:2.15rem;margin:.2rem 0 .25rem}h2{margin-top:2.8rem;padding-top:.35rem;border-top:2px solid #e2e8f0;font-size:1.55rem}h3{margin-top:1.5rem;font-size:1.15rem}p{max-width:1080px}a{color:#075caa;text-decoration-thickness:1px;text-underline-offset:2px}a:hover{color:#003f73}code{font:.92em Consolas,"Courier New",monospace;background:#f1f5f9;padding:.08rem .25rem;border-radius:3px}.subtitle,.small{color:var(--muted)}.subtitle{font-size:1.05rem;margin:.15rem 0 .7rem}.small{font-size:.92rem}.kicker{margin:0;color:var(--blue);font-size:.82rem;font-weight:750;letter-spacing:.08em;text-transform:uppercase}.eli5{padding:.85rem 1rem;border-left:5px solid var(--blue);background:var(--blue2);font-size:1.03rem}.technical{padding-left:1rem;border-left:2px solid #cbd5e1}.callout{border:1px solid var(--line);border-left:5px solid var(--blue);padding:.85rem 1rem;margin:1rem 0;background:var(--blue2)}.callout.warn{border-left-color:var(--amber);background:var(--amber2)}.callout.stop{border-left-color:var(--red);background:var(--red2)}.source{font-size:.92rem;color:var(--muted);margin-top:.65rem}.source a{font-weight:600}.tag{display:inline-block;border-radius:99px;padding:.16rem .55rem;font-size:.83rem;font-weight:700;white-space:nowrap}.t-verified{color:#166534;background:#ecfdf3}.t-partial,.t-proposed{color:#9a5b00;background:#fff7e6}.t-notmet{color:#a61b1b;background:#fff1f1}.t-notstarted{color:#475569;background:#f1f5f9}.t-info{color:#075caa;background:#eaf3fb}.figure{margin:1.25rem 0 1.6rem;padding:1rem;border:1px solid var(--line);background:#fff}.figure svg{display:block;width:100%;height:auto}.figure figcaption{margin:.7rem .2rem 0;color:var(--muted);font-size:.94rem}.table-wrap{overflow-x:auto;margin:1rem 0 1.4rem}.decision-table{width:100%;min-width:900px;border-collapse:collapse;table-layout:fixed}.decision-table th,.decision-table td{border:1px solid var(--line);padding:.6rem;vertical-align:top;text-align:left;overflow-wrap:anywhere}.decision-table th{background:#edf3f8;color:#102a43}.decision-table tbody tr:nth-child(even){background:#fbfdff}.decision-table.compact td,.decision-table.compact th{font-size:.9rem;padding:.45rem .55rem}.decision-table .tag{white-space:normal}.decision-table.wide{min-width:1120px}.plain-list li{margin:.45rem 0}.metric{font-variant-numeric:tabular-nums;font-weight:700}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:.8rem;margin:1rem 0 1.3rem}.card{border:1px solid var(--line);border-top:4px solid var(--blue);padding:.8rem 1rem;background:var(--panel)}.card h3{margin:.1rem 0 .4rem;font-size:1.02rem}.card p{margin:.3rem 0 0;font-size:.92rem}.step-no{font:700 .8rem Consolas,"Courier New",monospace;color:var(--blue)}.two-col{display:grid;grid-template-columns:1fr 1fr;gap:1rem}.draft-banner{margin:1rem 0;padding:.8rem 1rem;border:2px dashed var(--amber);background:var(--amber2);font-weight:600}.req-tree ul{list-style:none;margin:.2rem 0 .2rem 1.1rem;padding-left:.8rem;border-left:2px solid #e2e8f0}.req-tree>ul{margin-left:0;border-left:0;padding-left:0}.req-tree li{margin:.28rem 0}.evidence-id{display:inline-block;font:700 .82rem Consolas,"Courier New",monospace;color:#075caa;background:var(--blue2);border:1px solid #c7ddec;border-radius:4px;padding:.08rem .33rem;white-space:nowrap}.rid{display:inline-block;min-width:6.2rem;font:700 .85rem Consolas,"Courier New",monospace;color:#075caa}dl dt{font-weight:700;margin-top:1rem}dl dd{margin:.25rem 0 0 1rem}footer{margin-top:3rem;padding-top:1rem;border-top:2px solid #e2e8f0;color:var(--muted);font-size:.9rem}@media(max-width:760px){body{margin:1rem auto}.two-col{grid-template-columns:1fr}h1{font-size:1.7rem}.decision-table{min-width:760px}.figure{padding:.55rem}}"""

NAV_CSS = """.sys-nav{margin:0 0 1.2rem;padding:.6rem .8rem;border:1px solid var(--line,#cbd5e1);border-top:4px solid #0f4c81;background:#f8fafc;font:14px/1.45 "Segoe UI",Arial,sans-serif}.sys-nav strong{color:#102a43;margin-right:.6rem}.sys-nav a{display:inline-block;margin:.1rem .7rem .1rem 0;color:#075caa;white-space:nowrap}.sys-nav a[aria-current=page]{color:#102a43;font-weight:700;text-decoration:none;border-bottom:2px solid #0f4c81}.sys-nav .sys-nav-home{float:right;margin-right:0}@media(max-width:760px){.sys-nav .sys-nav-home{float:none}}"""


def nav(current: str) -> str:
    links = []
    for filename, number, label in PAGES:
        text = f"{number} · {label}" if number not in {"0", "SDR"} else label
        attr = ' aria-current="page"' if filename == current else ""
        links.append(f'<a href="{filename}"{attr}>{html.escape(text)}</a>')
    return (
        f"<style>{NAV_CSS}</style>"
        '<nav class="sys-nav" aria-label="System engineering section">'
        '<a class="sys-nav-home" href="../index.html">Reporting home</a>'
        "<strong>System engineering</strong>" + "".join(links) + "</nav>"
    )


def page(filename: str, title: str, kicker: str, subtitle: str, body: str, description: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="{html.escape(description)}">
<title>{html.escape(title)}</title>
<style>
{BASE_CSS}
</style>
</head>
<body>
{nav(filename)}
<header>
<p class="kicker">{html.escape(kicker)}</p>
<h1>{html.escape(title)}</h1>
<p class="subtitle">{subtitle}</p>
<p class="small">Status snapshot: {SNAPSHOT}. The masters of everything summarised here are in flightTest <a href="{MAIN_TREE}"><code>docs/system/</code></a>; where a page and a master disagree, the master wins.</p>
</header>
{body}
<footer>
<p>System Engineering section of the FlightTest reporting site. It is separate from the exploration report family and follows the same evidence rules: every claim states its evidence and claim boundary. Requirement and interface status words (Verified, Partial, Proposed) are defined on the <a href="02_Requirements.html">requirements page</a> and in the ICD; none of them is a radar-performance result.</p>
</footer>
</body>
</html>
"""


# --------------------------------------------------------------------------- requirements master


def md_inline(text: str) -> str:
    """Tiny Markdown-to-HTML for table cells: code, bold, italic, links (relative ones to main)."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<![*\w])\*([^*]+)\*(?![*\w])", r"<em>\1</em>", out)

    def link(m: re.Match[str]) -> str:
        label, url = m.group(1), m.group(2)
        if url.startswith("../../reporting/"):
            url = "../" + url[len("../../reporting/"):]
        elif not re.match(r"https?://", url):
            base = MAIN_TREE if url.endswith("/") else MAIN
            url = f"{base}/{url}"
        return f'<a href="{url}">{label}</a>'

    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, out)


def parse_requirements() -> tuple[list[dict[str, str]], list[str]]:
    rows: list[dict[str, str]] = []
    header: list[str] | None = None
    section = ""
    for line in REQUIREMENTS.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            section = line.lstrip("#").strip()
            header = None
            continue
        if not line.startswith("|"):
            header = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = cells
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        row = dict(zip(header, cells, strict=False))
        if re.match(r"^(MG|MN|SR|DR)-", row.get("ID", "")):
            row["_section"] = section
            rows.append(row)
    status_words = ["Verified", "Partial", "Not met", "Not started", "Proposed"]
    return rows, status_words


def status_class(status: str) -> str:
    s = status.lower()
    if s.startswith("verified"):
        return "t-verified"
    if s.startswith("partial"):
        return "t-partial"
    if s.startswith("not met"):
        return "t-notmet"
    if s.startswith("not started"):
        return "t-notstarted"
    if s.startswith("proposed"):
        return "t-proposed"
    return "t-info"


def status_key(status: str) -> str:
    for word in ["Verified", "Partial", "Not met", "Not started", "Proposed"]:
        if status.startswith(word):
            return word
    return status


def tag(status: str) -> str:
    return f'<span class="tag {status_class(status)}">{md_inline(status)}</span>'


REQS, STATUS_WORDS = parse_requirements()
BY_ID = {r["ID"]: r for r in REQS}


def level(prefix: str) -> list[dict[str, str]]:
    return [r for r in REQS if r["ID"].startswith(prefix)]


def counts_table() -> str:
    body = []
    for label, prefix in [("Mission needs", "MN-"), ("System requirements", "SR-"), ("Derived requirements", "DR-")]:
        rows = level(prefix)
        c = Counter(status_key(r["Status"]) for r in rows)
        body.append(
            f"<tr><td>{label}</td><td class='metric'>{len(rows)}</td>"
            + "".join(f"<td>{c.get(w, 0)}</td>" for w in STATUS_WORDS)
            + "</tr>"
        )
    head = "".join(f"<th>{tag(w)}</th>" for w in STATUS_WORDS)
    return (
        '<div class="table-wrap"><table class="decision-table compact" style="min-width:700px">'
        f"<thead><tr><th>Level</th><th>Count</th>{head}</tr></thead><tbody>{''.join(body)}</tbody></table></div>"
    )


def short(text: str, n: int = 110) -> str:
    plain = re.sub(r"\*\*|`|\*", "", text)
    return plain if len(plain) <= n else plain[: n - 1].rsplit(" ", 1)[0] + "…"


def tree() -> str:
    children: dict[str, list[str]] = {}
    for r in REQS:
        parent = r.get("Parent", "")
        first = parent.split(",")[0].strip() if parent else ""
        children.setdefault(first, []).append(r["ID"])

    def render(rid: str) -> str:
        r = BY_ID[rid]
        text = r.get("Goal") or r.get("Need") or r.get("Requirement") or ""
        status = r.get("Status")
        kids = children.get(rid, [])
        inner = "".join(render(k) for k in kids)
        return (
            f"<li><span class='rid'>{rid}</span> {html.escape(short(text))}"
            + (f" {tag(status)}" if status else "")
            + (f"<ul>{inner}</ul>" if inner else "")
            + "</li>"
        )

    roots = [r["ID"] for r in REQS if r["ID"].startswith("MG-")]
    return "<div class='req-tree'><ul>" + "".join(render(g) for g in roots) + "</ul></div>"


def req_table(rows: list[dict[str, str]], with_rationale: bool = True) -> str:
    head = "<th style='width:8%'>ID</th><th style='width:26%'>Requirement</th>"
    if with_rationale:
        head += "<th style='width:16%'>Rationale</th>"
    head += "<th style='width:7%'>Parent</th><th style='width:9%'>Allocation</th><th style='width:6%'>Method</th><th style='width:9%'>Status</th><th>Evidence</th>"
    body = []
    for r in rows:
        text = r.get("Requirement") or r.get("Need") or ""
        cells = f"<td><span class='rid'>{r['ID']}</span></td><td>{md_inline(text)}</td>"
        if with_rationale:
            cells += f"<td>{md_inline(r.get('Rationale', '—'))}</td>"
        cells += (
            f"<td>{md_inline(r.get('Parent', ''))}</td><td>{md_inline(r.get('Allocation', ''))}</td>"
            f"<td>{md_inline(r.get('Method', ''))}</td><td>{tag(r.get('Status', ''))}</td><td>{md_inline(r.get('Evidence', ''))}</td>"
        )
        body.append(f"<tr>{cells}</tr>")
    return f"<div class='table-wrap'><table class='decision-table compact wide'><thead><tr>{head}</tr></thead><tbody>{''.join(body)}</tbody></table></div>"


# --------------------------------------------------------------------------- shared content

ACTIONS = f"""<div class="table-wrap"><table class="decision-table">
<thead><tr><th style="width:7%">ID</th><th style="width:38%">Action</th><th style="width:14%">Who</th><th style="width:16%">Traces to</th><th>Why</th></tr></thead>
<tbody>
<tr><td>A-1</td><td>Review the CueListener branch <a href="{CUE_BRANCH}"><code>feature/adsb-cue-listener</code></a> (pinned review point <a href="{CUE_PIN}"><code>94bf924</code></a>), including the <code>dtv*</code> level-check scripts. CueListener stays on that branch until the review is done.</td><td>Pat</td><td>SR-02, DR-CUE-6, SR-09</td><td>The first piece of the Resource Manager is not on <code>main</code>; a review is the step before any merge.</td></tr>
<tr><td>A-2</td><td>Reseat the suspected loose component in the Pi's GPS/PPS path and re-check the reference-clock lock.</td><td>Leif (hardware and integration)</td><td>DR-TIME-3</td><td>Hardware troubleshooting to-do. It does not block NTP-based timing, which is accepted.</td></tr>
<tr><td>A-3</td><td>Bound the Pi clock offset for ADS-B truth recorded before 2026-09-25 21:07 UTC, starting with the 2026-09-25 tracking scan.</td><td>Pat</td><td>DR-TIME-4</td><td>The Pi was measured 14.9 s slow before NTP was reachable; earlier truth is not timing truth until bounded.</td></tr>
<tr><td>A-4</td><td>Review the DRAFT requirements baseline; it stays DRAFT while CR-10 is open.</td><td>Leif (system)</td><td>CR-10</td><td>The baseline as a whole is not accepted; individual decisions of 2026-09-26 are recorded in it.</td></tr>
<tr><td>A-5</td><td>Add a repeatable host-clock check (Pi against collection desktop) and record chrony state with every collection.</td><td>Pat</td><td>DR-TIME-1, DR-TIME-2</td><td>The accepted 0.1 s tolerance rests on one SSH-jitter-limited check.</td></tr>
<tr><td>A-6</td><td>Design Resource Manager scheduling and the <code>collection_task</code> message with <code>cue_ref</code> and <code>collection_basis</code>.</td><td>Leif (system)</td><td>SR-02, DR-TASK-1, DR-TS-1</td><td>Next design step: no collection is yet scheduled from a cue.</td></tr>
<tr><td>A-7</td><td>Add the CR-9 follow-up to the Proposed ICD §3 messages: an emitter list and a capture bandwidth in <code>collection_task</code> and <code>capture_record</code>, and <code>truth_use</code> in <code>detection_list</code> and <code>track_report</code>; add the truth-separation design rule to the architecture.</td><td>Leif (system)</td><td>CR-9, DR-DATA-7, DR-TS-1, DR-TS-2, DR-TS-6</td><td>CR-9 is accepted; the controlled documents are not updated yet.</td></tr>
</tbody></table></div>"""

DECISIONS = """<ul class="plain-list">
<li><strong>Two report tracks.</strong> The exploration report family ("can we do it, and what does it look like") stays at nine reports. System engineering is presented in this separate section as a formal design process.</li>
<li><strong>Requirements.</strong> The baseline is published labelled DRAFT; CR-10 stays open. Values still marked TBD stay TBD for now.</li>
<li><strong>Time source.</strong> Internet NTP is an accepted time source, with an accepted host-to-host tolerance of 0.1 s (DR-TIME-1). GPS/PPS lock is a hardware troubleshooting to-do, not a blocker for NTP-based timing. The re-check of earlier ADS-B timing stays open.</li>
<li><strong>MATLAB exception.</strong> The Python Cue Tasker is an accepted named exception under MG-1 (DR-DEP-4).</li>
<li><strong>Truth separation.</strong> CR-9 is accepted, amended for sites that host several emitters and for captures widened (for example to 12 MHz) to take in adjacent channels: the cued/uncued label covers the whole capture, every product records its emitter, and products on other emitters of a cued collection are still conditional on the cue (<a href="06_TruthSeparation.html">page 6</a>). The ICD and architecture follow-up is action A-7.</li>
<li><strong>Report 02 criteria.</strong> The Report 02 acceptance tests stay in Report 02 and do not become derived requirements.</li>
<li><strong>Owners.</strong> System, RF and integration actions go to Leif; everything else to Pat.</li>
<li><strong>Code location.</strong> CueListener and the <code>dtv*</code> scripts stay on <code>feature/adsb-cue-listener</code>, with a review action for Pat (A-1).</li>
<li><strong>Release build.</strong> No full TechnicalSummaryFamily release build is run: it needs files that exist only on the Windows workstation. This is recorded as a known limitation.</li>
</ul>"""


def boundary(text: str) -> str:
    return f'<div class="callout stop"><strong>Claim boundary:</strong> {text}</div>'


# --------------------------------------------------------------------------- pages


def page_index() -> str:
    steps = [
        ("01_MissionAndNeeds.html", "1", "Mission and needs", "Two mission goals, five stakeholder groups, six mission needs.", "Draft", "t-partial", "Requirements.md §1–3"),
        ("02_Requirements.html", "2", "Requirements (DRAFT)", f"DRAFT baseline: {len(level('SR-'))} system and {len(level('DR-'))} derived requirements with allocation, method and status.", "DRAFT baseline (CR-10)", "t-partial", "Requirements.md"),
        ("03_ArchitectureAndAllocation.html", "3", "Architecture and allocation", "Ten software items allocated to three hosts; deployment policy; design rules.", "Controlled (rev. 2026-09-25)", "t-info", "System_Architecture.md"),
        ("04_Interfaces.html", "4", "Interfaces", "Message contract: envelope, transport, framing, per-message status.", "ICD Draft B; CT messages Verified", "t-partial", "ICD_Messages.md"),
        ("05_VerificationAndTraceability.html", "5", "Verification and traceability", "Every requirement traced to its method, status and evidence.", f"{sum(1 for r in REQS if status_key(r.get('Status','')) == 'Verified')} requirements verified", "t-partial", "Verification_Log.md"),
        ("06_TruthSeparation.html", "6", "Truth separation", "How cued collections and cue-aided association are labelled and scored.", "Accepted (CR-9); not yet implemented", "t-partial", "Change_Requests.md CR-9"),
        ("07_AsBuiltAndConfiguration.html", "7", "As-built and configuration", "What runs where, deployed configuration, time source, actions.", "Recorded 2026-09-26", "t-info", "As_Built.md"),
        ("SDR_CT_CueTasking_V1.html", "SDR", "Subsystem record: CT", "ADS-B Cue Tasker design, deployment and live cue-interface verification.", "1 of 10 items recorded", "t-partial", "ADSB-remoter; evidence/"),
    ]
    cards = "".join(
        f'<article class="card"><p class="step-no">Step {n}</p><h3><a href="{f}">{html.escape(t)}</a></h3><p>{html.escape(d)}</p>'
        f'<p><span class="tag {c}">{html.escape(s)}</span></p><p class="small">Master: {html.escape(m)}</p></article>'
        for f, n, t, d, s, c, m in steps
    )
    body = f"""
<section id="purpose">
<h2>Purpose of this section</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> The exploration reports ask “can we do it, and what does it look like?”. This section asks a different question: what exactly is the system we are building, what must it do, how is it put together, and how do we know each part works? It follows a formal design process, from the mission down to the individual parts, and records what has been checked so far.</p>
<div class="technical">
<p>The project has two mission goals: to collect passive radar data showing that a complete system can be built with MATLAB and MathWorks tools (MG-1), and to collect data that proves MATLAB functions such as radar, tracking and signal processing work as designed on real data that can be shared with customers (MG-2). The pages below trace those goals through needs and requirements to the architecture, the interfaces, verification evidence, and the system as built. The exploration family in <a href="../index.html">the reporting home</a> keeps its own nine reports and claim boundaries; this section links to them where their evidence is used.</p>
</div>
{boundary("this section describes the designed system and the verification status of its requirements and interfaces. A requirement or interface marked Verified means that stated check passed on stated evidence; it is not a radar detection, tracking, or localization result. The requirements baseline is a DRAFT for owner review.")}
</section>

<section id="process">
<h2>The design process, step by step</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Read left to right and top to bottom: each step builds on the one before. The chip on each card says how far that step has got.</p>
<div class="grid">{cards}</div>
<p class="source">Masters: <a href="{MAIN}/README.md">docs/system README</a> (index, software items, message status register, open decisions).</p>
</section>

<section id="decisions">
<h2>Decisions recorded on 26 September 2026</h2>
{DECISIONS}
</section>

<section id="actions">
<h2>Action register</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> These are the open actions that follow from the decisions and the verification status. Each traces to a requirement or change request.</p>
{ACTIONS}
</section>

<section id="status">
<h2>Requirements status at a glance</h2>
{counts_table()}
<p class="small">From the DRAFT baseline; see <a href="02_Requirements.html">Requirements</a> for the definitions and <a href="05_VerificationAndTraceability.html">Verification</a> for the evidence.</p>
</section>
"""
    return page("index.html", "System Engineering: Design Process and Status", "System engineering · overview",
                "Passive bistatic radar testbed — formal system design process, separate from the exploration report family",
                body, "System engineering section: design process, decisions, actions and status.")


def page_mission() -> str:
    goals = "".join(f"<tr><td><span class='rid'>{r['ID']}</span></td><td>{md_inline(r['Goal'])}</td></tr>" for r in level("MG-"))
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Before designing anything, write down what the testbed is for and who needs what from it. Everything else in this section traces back to these two goals.</p>
{boundary("goals and needs state intent. They are not evidence that the system meets them; that is recorded against each need's status and on the verification page.")}
</section>
<section id="goals">
<h2>Mission goals</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:600px"><thead><tr><th style="width:12%">ID</th><th>Goal</th></tr></thead><tbody>{goals}</tbody></table></div>
<p>MG-1 is about the system: a complete passive radar chain built and run with MATLAB and MathWorks tools. MG-2 is about the data: real recordings, with truth, good enough to show that MATLAB functions behave as designed, and packaged so they can be shared with customers. The exploration reports (<a href="../reports/01_NorthStarAndMotivation_V2.html">Report 01</a> onward) explore whether the physics and processing make that possible; this section defines the system that has to deliver it.</p>
</section>
<section id="stakeholders">
<h2>Stakeholders</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:600px"><thead><tr><th style="width:30%">Stakeholder</th><th>Interest</th></tr></thead><tbody>
<tr><td>Project owner</td><td>Goals, priorities, acceptance of requirements and evidence</td></tr>
<tr><td>Testbed engineers</td><td>Operate, maintain and extend the hardware and software items</td></tr>
<tr><td>Users of MATLAB radar, tracking and signal-processing functions</td><td>Real data with truth on which to exercise and judge those functions</td></tr>
<tr><td>Customers receiving shared datasets</td><td>Documented, traceable data that they are allowed to use</td></tr>
<tr><td>Site and network owners</td><td>Hosting, network, and physical-installation constraints at Apple Hill</td></tr>
</tbody></table></div>
</section>
<section id="needs">
<h2>Mission needs</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Six needs connect the goals to requirements. Only one of them (datasets that can be shared) has no part met yet.</p>
{req_table(level("MN-"), with_rationale=False)}
<div class="callout"><strong>Named exception, accepted:</strong> the Cue Tasker is written in Python. The owner accepted it on 26 September 2026 as a named exception under MG-1, alongside the system services and the antenna-node firmware (DR-DEP-4).</div>
<p class="source">Master: <a href="{MAIN}/Requirements.md">docs/system/Requirements.md</a> §1–3 (DRAFT, CR-10).</p>
</section>
"""
    return page("01_MissionAndNeeds.html", "Mission and Stakeholder Needs", "System engineering · step 1",
                "What the testbed is for, who needs what from it, and the needs that requirements must serve", body,
                "Mission goals, stakeholders and mission needs of the passive radar testbed.")


def page_requirements() -> str:
    sections = []
    groups = [
        ("System requirements", [r for r in REQS if r["ID"].startswith("SR-")]),
        ("Derived: cue interface", level("DR-CUE-")),
        ("Derived: tasking", level("DR-TASK-")),
        ("Derived: timing", level("DR-TIME-")),
        ("Derived: datasets, provenance and release", level("DR-DATA-")),
        ("Derived: MATLAB implementation and deployment", level("DR-DEP-")),
        ("Derived: truth separation", level("DR-TS-")),
    ]
    for title, rows in groups:
        sections.append(f"<h3>{title} ({len(rows)})</h3>{req_table(rows)}")
    body = f"""
<div class="draft-banner">DRAFT — requirements baseline for owner review (CR-10, open). The baseline as a whole is not accepted. Owner decisions of 26 September 2026 on individual items are recorded below; values marked TBD are still unknown.</div>
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Until now the testbed had a design but no written list of what it must do. This baseline starts from the two mission goals and works down, writing requirements only where the goals or existing design decisions already call for them, and marks every unknown value as TBD rather than guessing.</p>
<div class="technical">
<p>Levels: mission goals (MG) → mission needs (MN) → system requirements (SR) → derived requirements (DR). Each requirement has a rationale, a parent, an allocation to architecture items, a verification method (<strong>I</strong> inspection, <strong>A</strong> analysis, <strong>D</strong> demonstration, <strong>T</strong> test), and a status on current evidence: <span class="tag t-verified">Verified</span> evidence shows it met; <span class="tag t-partial">Partial</span> part met, or met under narrower conditions; <span class="tag t-notmet">Not met</span> the item exists and does not meet it; <span class="tag t-notstarted">Not started</span> the allocated item is not built; <span class="tag t-proposed">Proposed</span> depends on a rule or message that is itself only proposed.</p>
</div>
{boundary("a requirement's status reflects the evidence cited in its row on 26 September 2026. Verified requirements so far concern the cue message interface; no requirement about detection, tracking, or dataset release is met.")}
</section>
<section id="tree">
<h2>Requirements tree</h2>
<p class="small">Each requirement is shown under its first parent; the tables give every parent.</p>
{tree()}
</section>
<section id="counts">
<h2>Status counts</h2>
{counts_table()}
</section>
<section id="tables">
<h2>Requirements, rationale, allocation and status</h2>
{''.join(sections)}
</section>
<section id="open">
<h2>Owner decisions and open points</h2>
<p><strong>Decided 26 September 2026:</strong> the 0.1 s host-clock tolerance (DR-TIME-1); the Python Cue Tasker as an accepted named exception (DR-DEP-4); the truth-separation rule CR-9 with its emitter and wide-capture amendment (DR-TS-1 to DR-TS-6, DR-DATA-7); the Report 02 acceptance tests stay in Report 02 and are not derived requirements.</p>
<ol class="plain-list">
<li>Accept, change or reject each requirement; the baseline stays DRAFT while CR-10 is open.</li>
<li>Values still TBD: pointing tolerance (SR-04), ADS-B lead and tail (DR-DATA-4), content and approver of the data-release statement (SR-11, DR-DATA-5).</li>
</ol>
<p class="source">Master: <a href="{MAIN}/Requirements.md">docs/system/Requirements.md</a>; change request CR-10 in <a href="{MAIN}/Change_Requests.md">Change_Requests.md</a>.</p>
</section>
"""
    return page("02_Requirements.html", "System Requirements — DRAFT Baseline", "System engineering · step 2",
                "From mission goals to derived requirements, with allocation, verification method and status", body,
                "Draft requirements baseline of the passive radar testbed.")


def allocation_counts() -> str:
    items = ["AR", "CT", "RM", "RC", "SP", "TR", "RD", "CM", "AM", "AC", "Time Source"]
    rows = []
    for item in items:
        ids = [r["ID"] for r in REQS if r["ID"][:2] in {"SR", "DR"} and re.search(rf"(^|[ ,]){re.escape(item)}([ ,]|$)", r.get("Allocation", ""))]
        if item in {"RM", "RC", "SP", "TR", "RD", "CM", "AM", "AC"}:
            ids += [r["ID"] for r in REQS if "MATLAB items" in r.get("Allocation", "") or "All items" in r.get("Allocation", "")]
        elif item in {"AR", "CT", "Time Source"}:
            ids += [r["ID"] for r in REQS if "All items" in r.get("Allocation", "")]
        ids = sorted(set(ids), key=lambda x: REQS.index(BY_ID[x]))
        c = Counter(status_key(BY_ID[i]["Status"]) for i in ids)
        summary = ", ".join(f"{c[w]} {w.lower()}" for w in STATUS_WORDS if c.get(w))
        rows.append(f"<tr><td><strong>{item}</strong></td><td>{len(ids)}</td><td>{summary or '—'}</td><td class='small'>{', '.join(ids) or '—'}</td></tr>")
    return (
        "<div class='table-wrap'><table class='decision-table compact'><thead><tr><th style='width:11%'>Item</th><th style='width:12%'>Requirements</th>"
        f"<th style='width:28%'>Status</th><th>IDs</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>"
    )


def page_architecture() -> str:
    figure = (FRAGMENTS / "architecture_figure.html").read_text(encoding="utf-8")
    figure = figure.replace(
        "Sources: S02, S03, S04. [Implemented]",
        f'Evidence IDs (SYS-…) refer to the <a href="SDR_CT_CueTasking_V1.html">CT subsystem record</a>. Sources: <a href="{MAIN}/System_Architecture.md">System_Architecture.md</a>, <a href="{MAIN}/ICD_Messages.md">ICD_Messages.md</a>, <a href="{MAIN}/As_Built.md">As_Built.md</a>. [Implemented]',
    )
    items = (FRAGMENTS / "item_status_table.html").read_text(encoding="utf-8")
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> The testbed is split into ten programs, each with one job and a two-letter ID, placed on three computers. This page shows how they connect, which exist today, and which requirements each one carries.</p>
<div class="technical">
<p>The architecture is written as the source of a MATLAB System Composer model: functional items, hardware items, networks, an allocation of items to hosts, and a profile of stereotypes. Every MATLAB item is to become a compiled standalone app on the MATLAB Runtime, Linux first; the named exceptions are the Cue Tasker (Python), system services (chrony, gpsd, dump1090) and the ESP32 antenna-node firmware.</p>
</div>
{boundary("the architecture is a design record. Items shown as planned or proposed do not exist; a link drawn in the design is not evidence that it works. Only the cue stream has been verified on the wire.")}
</section>
<section id="figure">
<h2>Functional architecture with as-built status</h2>
{figure}
</section>
<section id="items">
<h2>Software items</h2>
{items}
</section>
<section id="allocation">
<h2>Allocation to hosts</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:640px"><thead><tr><th style="width:40%">Software item</th><th>Allocated to</th></tr></thead><tbody>
<tr><td>AR ADS-B Receiver; Time Source; CT ADS-B Cue Tasker</td><td>ADS-B Raspberry Pi (+ RTL-SDR, GPS receiver)</td></tr>
<tr><td>RM Resource Manager; RC RF Collector; CM Calibration Manager; AC Antenna Controller; TR Tracker; AM Activity Manager</td><td>RF Collection Desktop (+ USRP N320, Pluto SDR, ESP32 gateway to the antenna nodes)</td></tr>
<tr><td>SP Signal Processor; RD Report and Display</td><td>RF Collection Desktop (near-real-time, primary display); RF Data Reduction Desktop (offline processing, auxiliary display)</td></tr>
</tbody></table></div>
</section>
<section id="requirements">
<h2>Requirements allocated to each item</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> Counting requirements per item shows where the work is: the cue path is largely verified, while the scheduling, processing, tracking and packaging items carry most of the unmet requirements.</p>
{allocation_counts()}
<p class="small">Requirements allocated to “MATLAB items” or “All items” are counted for every item they cover. Process-only requirements are not listed.</p>
</section>
<section id="rules">
<h2>Design rules</h2>
<ul class="plain-list">
<li><strong>Deployment:</strong> one entry point per MATLAB item; host-specific values from configuration; privileged host setup outside the apps; deployability of every toolbox or hardware dependency proven in a compiled app first (SR-12, DR-DEP-1 to DR-DEP-4).</li>
<li><strong>Transport:</strong> TCP for tasks, captures, detections, tracks and calibration; UDP for heartbeats and antenna state; the cue stream is UDP multicast by design, recovered by snapshots and sequence numbers (<a href="04_Interfaces.html">Interfaces</a>).</li>
<li><strong>Timing:</strong> hosts keep UTC through the Time Source; internet NTP is accepted, with an accepted 0.1 s host-to-host tolerance; the N320 takes no PPS or 10 MHz reference (<a href="07_AsBuiltAndConfiguration.html">As-built</a>).</li>
<li><strong>Truth separation (accepted, CR-9):</strong> every capture is labelled by how it was chosen, every product by how cues and truth were used and by its emitter, and only truth-blind products count as independent evidence (<a href="06_TruthSeparation.html">Truth separation</a>). The design rule is still to be added to the architecture (A-7).</li>
</ul>
<p class="source">Masters: <a href="{MAIN}/System_Architecture.md">System_Architecture.md</a> (as designed, rev. 2026-09-25), <a href="{MAIN}/As_Built.md">As_Built.md</a> (as built), <a href="{MAIN}/Change_Requests.md">CR-8</a> (as-built corrections).</p>
</section>
"""
    return page("03_ArchitectureAndAllocation.html", "Architecture and Allocation", "System engineering · step 3",
                "Ten software items, their hosts, their status, and the requirements each carries", body,
                "Architecture, allocation and design rules of the passive radar testbed.")


def page_interfaces() -> str:
    msgs = [
        ("cue_heartbeat", "CT → RM, AM", "Verified at 2.0.0"),
        ("cue_snapshot_begin / cue_snapshot_end", "CT → RM", "Verified at 2.0.0"),
        ("track_cue", "CT → RM, TR, RD", "Verified at 2.0.0"),
        ("track_cue_withdrawal", "CT → RM, TR, RD", "Implemented (not seen live)"),
        ("CT configuration file (not a message)", "file → CT", "Implemented"),
        ("CT compression dictionary 1 (not a message)", "file → CT and consumers", "Released; in use and Verified live"),
        ("collection_task", "RM → RC", "Proposed"),
        ("antenna_command", "RM → AC", "Proposed"),
        ("antenna_state", "AC → RC, RM, RD", "Proposed"),
        ("rotator_command / rotator_packet", "AC ↔ antenna nodes", "Proposed"),
        ("capture_record", "RC → SP, CM", "Proposed"),
        ("calibration_request", "CM → RM", "Proposed"),
        ("calibration_result", "CM → SP, AM, RD", "Proposed"),
        ("detection_list", "SP → TR, RD", "Proposed"),
        ("track_report", "TR → RM, RD", "Proposed"),
        ("health_status", "all MATLAB items → AM", "Proposed"),
    ]

    def t(status: str) -> str:
        return tag("Verified" if status.startswith("Verified") or status.startswith("Released") else "Partial" if status.startswith("Implemented") else "Proposed").replace(
            ">Verified<", f">{html.escape(status)}<").replace(">Partial<", f">{html.escape(status)}<").replace(">Proposed<", f">{html.escape(status)}<")

    rows = "".join(f"<tr><td><code>{html.escape(m)}</code></td><td>{html.escape(pc)}</td><td>{t(s)}</td></tr>" for m, pc, s in msgs)
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> The items talk to each other only through written message contracts. One family of messages, the cue stream, is live and checked. Every other message is still a proposal on paper.</p>
{boundary("an interface status is about the message contract: whether a schema exists, whether the producer emits it, whether it was validated live. It says nothing about the quality of what the message carries; for example, a Verified cue still carries modeled, pre-integration SNR predictions.")}
</section>
<section id="ladder">
<h2>Development status ladder (ICD §0)</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:700px"><thead><tr><th style="width:15%">Status</th><th style="width:35%">Meaning</th><th>Exit criterion to the next status</th></tr></thead><tbody>
<tr><td>Proposed</td><td>Exists only in the ICD.</td><td>A schema file is committed.</td></tr>
<tr><td>Draft</td><td>A schema exists; no producer code yet.</td><td>The producer emits it and a unit test validates it.</td></tr>
<tr><td>Implemented</td><td>The producer emits it; a unit test validates it.</td><td>Seen live on the wire and validated with zero errors by a capture tool.</td></tr>
<tr><td>Verified</td><td>Validated live on the wire.</td><td>Reviewed, with every open item for the message closed.</td></tr>
<tr><td>Frozen</td><td>Version locked.</td><td>—</td></tr>
</tbody></table></div>
</section>
<section id="register">
<h2>Message register</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:700px"><thead><tr><th style="width:38%">Message</th><th style="width:25%">Producer → consumers</th><th>ICD Draft B status</th></tr></thead><tbody>{rows}</tbody></table></div>
<p class="small">The proposed <code>truth_track</code> message was dropped: the Tracker and Report &amp; Display consume <code>track_cue</code> directly. That is why truth separation (<a href="06_TruthSeparation.html">page 6</a>) matters for the Tracker.</p>
<div class="callout warn"><strong>Follow-up from CR-9 (not yet in the ICD):</strong> <code>collection_task</code> and <code>capture_record</code> will need an emitter list and a capture bandwidth, because one capture can cover several emitters (a site may host several, and a capture may be widened to about 12 MHz). <code>detection_list</code> and <code>track_report</code> already carry <code>emitter_id</code> and will need <code>truth_use</code>. Action A-7.</div>
</section>
<section id="conventions">
<h2>Conventions every message follows</h2>
<ul class="plain-list">
<li><strong>Envelope:</strong> <code>schema_version</code>, <code>message_type</code>, <code>message_id</code>, <code>source</code>, <code>source_instance_id</code>, <code>sequence_number</code>, <code>generated_utc_ms</code>, flat rather than nested.</li>
<li><strong>Encoding:</strong> UTF-8 JSON; snake_case names with units in the name; times as integer epoch milliseconds; values rounded to a stated resolution per unit.</li>
<li><strong>Fixed shapes for MATLAB:</strong> every property present in every message of a run, no field that is sometimes null and sometimes an object, identical keys across array elements, so <code>jsondecode</code> returns the same structs every time (SR-14).</li>
<li><strong>Versioning:</strong> <code>additionalProperties: false</code>; semantic versions per schema; breaking changes need a major version and a CR.</li>
</ul>
</section>
<section id="transport">
<h2>Transport and ports</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:700px"><thead><tr><th style="width:18%">Port</th><th style="width:22%">Protocol</th><th style="width:20%">Listener</th><th>Receives</th></tr></thead><tbody>
<tr><td>31985</td><td>UDP</td><td>AM</td><td><code>health_status</code></td></tr>
<tr><td>31986</td><td>UDP multicast <code>239.192.10.1</code>, TTL 1</td><td>RM, TR, RD, AM</td><td>The CT cue stream (all CT messages). In use.</td></tr>
<tr><td>31986</td><td>TCP</td><td>RM</td><td><code>track_report</code>, <code>calibration_request</code></td></tr>
<tr><td>31987</td><td>TCP</td><td>RC</td><td><code>collection_task</code></td></tr>
<tr><td>31988</td><td>TCP</td><td>AC</td><td><code>antenna_command</code></td></tr>
<tr><td>31989</td><td>UDP broadcast</td><td>RC, RM, RD</td><td><code>antenna_state</code></td></tr>
<tr><td>31990–31993</td><td>TCP</td><td>SP, TR, RD, CM</td><td>Captures, detections, tracks, calibration results</td></tr>
</tbody></table></div>
<p><strong>Cue-stream framing (since 2.0.0):</strong> one message per datagram, either plain JSON (first byte <code>{{</code>) or compressed (first byte <code>0xDC</code>, then a dictionary id, then raw deflate with that preset dictionary). The sender chooses once at startup; receivers detect it per datagram. Every datagram fits one Ethernet frame (1472 B). Design, evidence and the decision history are in the <a href="SDR_CT_CueTasking_V1.html">CT subsystem record</a>.</p>
<p class="source">Master: <a href="{MAIN}/ICD_Messages.md">docs/system/ICD_Messages.md</a> (Draft B, 2026-09-26). Schemas and dictionaries: <a href="{CT_REPO}/tree/feature/passive-radar-cueing/schemas">ADSB-remoter <code>schemas/</code></a>.</p>
</section>
"""
    return page("04_Interfaces.html", "Interfaces", "System engineering · step 4",
                "The message contract between items: conventions, transport, and the status of every message", body,
                "Interface control summary for the passive radar testbed.")


ACTIVITIES = [
    ("2026-09-25", "CT headless end-to-end on a replayed SBS file (CT 1.1.0)", "733 of 733 messages valid, 0 gaps, 5 snapshots", "SR-01, DR-CUE-1, DR-CUE-3", "Diagnostic (replay; raw data not kept)"),
    ("2026-09-25", "Headless run with a 5 s snapshot interval", "Found the worker defect that cancelled the SBS reader; fixed with a regression test", "SR-01", "Diagnostic"),
    ("2026-09-25", "Pi clock against the NTP-synced desktop", "Pi 14.9 s slow; chrony unsynchronised", "SR-05, DR-TIME-4", "Measured (one reading, not kept)"),
    ("2026-09-25 21:07", "Pi clock after routing to internet NTP", "chrony synced (0.3 ms); desktop − Pi +0.05 to +0.09 s", "DR-TIME-1", "Measured (not kept)"),
    ("2026-09-26 00:50", "First live multicast capture, Pi → desktop", "34 messages, 0 schema failures, 0 gaps", "SR-01", "Measured (partial file kept)"),
    ("2026-09-26 02:10", "CueListener live in MATLAB", "7 messages decoded, 0 gaps, 0 decode errors", "DR-CUE-6", "Diagnostic"),
    ("2026-09-26 12:34", "CT 1.1.0 live acceptance (WI-7)", "46 messages, 0 failures; 4 consistent snapshots", "DR-CUE-1, DR-CUE-3", "Measured"),
    ("2026-09-26 14:30", "Compiled MATLAB app on the MATLAB Runtime", "Joined the live group and decoded cues; dictionary inflate byte-exact", "DR-CUE-6, DR-DEP-3", "Diagnostic"),
    ("2026-09-26 15:08", "Dictionary 1 rebuilt with --check", "Byte-for-byte identical; 1,707 corpus cues schema-valid", "DR-CUE-2", "Diagnostic"),
    ("2026-09-26 15:23", "CT 2.0.0 live acceptance", "223 datagrams, 0 failures, 0 gaps, none over one frame (max 747 B), 15 consistent snapshots", "SR-01, DR-CUE-1, DR-CUE-2, DR-CUE-3", "Measured (raw wire bytes kept)"),
    ("2026-09-26 15:30", "CueListener with 2.0.0 compressed datagrams", "16 of 16 tests on 20 real datagrams", "DR-CUE-6", "Diagnostic"),
    ("2026-09-26", "Report-time re-runs: CT suite at 55062fc; CueListener at 94bf924; capture summary reproduced", "81 passed; 16 of 16 passed; 10 of 10 numbers match", "SR-01, DR-CUE-1 to DR-CUE-3, DR-CUE-6", "Diagnostic"),
]


def page_verification() -> str:
    acts = "".join(
        f"<tr><td>{d}</td><td>{html.escape(w)}</td><td>{html.escape(r)}</td><td>{html.escape(ids)}</td><td>{html.escape(c)}</td></tr>" for d, w, r, ids, c in ACTIVITIES
    )
    trace_rows = [r for r in REQS if r["ID"][:2] in {"SR", "DR"}]
    trace = "".join(
        f"<tr><td><span class='rid'>{r['ID']}</span></td><td>{html.escape(short(r['Requirement'], 90))}</td><td>{md_inline(r['Method'])}</td><td>{tag(r['Status'])}</td><td>{md_inline(r['Evidence'])}</td></tr>"
        for r in trace_rows
    )
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> For each requirement: how will we check it, has it been checked, and where is the proof? So far the checks that passed are all about the cue messages; the radar parts are still to be verified.</p>
{boundary("verification here is requirement-level. A Verified cue-interface requirement shows messages arrive intact and valid; it does not show that a cued collection yields a detection. Evidence classes follow the reporting rules (modeled, installed, measured, synthetic, diagnostic, operational); no operational evidence exists.")}
</section>
<section id="coverage">
<h2>Coverage</h2>
{counts_table()}
</section>
<section id="activities">
<h2>Verification activities and the requirements they cover</h2>
<div class="table-wrap"><table class="decision-table compact"><thead><tr><th style="width:11%">Date (UTC)</th><th style="width:25%">Check</th><th style="width:27%">Result</th><th style="width:19%">Requirements</th><th>Evidence class</th></tr></thead><tbody>{acts}</tbody></table></div>
<p class="source">Master: <a href="{MAIN}/Verification_Log.md">Verification_Log.md</a>; raw captures in <a href="{MAIN_TREE}/evidence">evidence/</a>; reproduction script <a href="{MAIN}/analysis/summarize_cue_capture.py">analysis/summarize_cue_capture.py</a>.</p>
</section>
<section id="trace">
<h2>Traceability matrix</h2>
<p class="small">Every system and derived requirement with its method, status and evidence, generated from the requirements master.</p>
<div class="table-wrap"><table class="decision-table compact"><thead><tr><th style="width:10%">ID</th><th style="width:34%">Requirement (short)</th><th style="width:7%">Method</th><th style="width:11%">Status</th><th>Evidence</th></tr></thead><tbody>{trace}</tbody></table></div>
</section>
<section id="next">
<h2>Next verification</h2>
<ul class="plain-list">
<li>A repeatable Pi-to-desktop clock check against the 0.1 s tolerance (DR-TIME-1, action A-5).</li>
<li>A live capture that contains a <code>track_cue_withdrawal</code> (DR-CUE-5).</li>
<li>A first collection scheduled from a cue, carrying <code>cue_ref</code> and <code>collection_basis</code> (SR-02, DR-TASK-1, DR-TS-1).</li>
<li>A truth-blind detection evaluation on that collection, reported under the truth-separation rule (SR-07, DR-TS-3, DR-TS-4).</li>
</ul>
</section>
"""
    return page("05_VerificationAndTraceability.html", "Verification and Traceability", "System engineering · step 5",
                "How each requirement is checked, what has been checked, and where the evidence is", body,
                "Verification plan, status and requirements traceability for the passive radar testbed.")


def page_truth() -> str:
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> ADS-B now plays two roles: it tells us when and where to listen, and it is the answer key we mark the radar against. If the same information also helped the radar find the aircraft, marking it against the answer key would prove nothing. This rule keeps the two roles apart and makes every result say which role ADS-B played, and which transmitter lit the aircraft.</p>
<div class="callout"><strong>Status:</strong> accepted as CR-9 on 26 September 2026, with an amendment for sites that host several emitters and for captures widened to take in adjacent channels. The labels are not yet implemented: the ICD messages that will carry them are still Proposed, and the design rule is still to be added to the architecture (action A-7). No cued collection has been made yet.</div>
{boundary("this page defines how evidence is labelled and counted. It creates no evidence, and it does not change any existing claim of the exploration family, whose rule that ADS-B truth is post hoc and must not steer map formation, thresholding, non-maximum suppression or detection still applies.")}
</section>
<section id="definitions">
<h2>Terms and definitions</h2>
<div class="callout"><strong>Site, emitter, capture.</strong> A <strong>site</strong> (“tower”) is a transmitter site. One site may host several <strong>emitters</strong>: DTV transmitters on different RF channels and frequencies. An emitter is identified by <code>emitter_id</code> (<code>dtv:&lt;facility&gt;:&lt;channel&gt;:&lt;MHz&gt;</code>), and <strong>a cue names an emitter</strong>, not a site. A <strong>capture</strong> may be centred on the cued emitter or widened, for example to 12 MHz, to take in adjacent channels of interest, so one capture can hold several emitters.</div>
<div class="two-col">
<div class="callout"><strong>Collection basis</strong> (how a capture was chosen; applies to the whole capture)<ul class="plain-list"><li><code>cued</code>: time, emitter or pointing came from a CT cue.</li><li><code>uncued</code>: chosen without ADS-B, for example on a timetable.</li><li><code>calibration</code>, <code>survey</code>.</li></ul></div>
<div class="callout"><strong>Truth use</strong> (did cues or ADS-B enter the processing? judged per product)<ul class="plain-list"><li><code>truth_blind</code>: no cue or ADS-B input to map formation, thresholding, non-maximum suppression, detection, association or track initiation.</li><li><code>cue_aided</code>: any such input, for example gating, association aid, track initiation, or the choice of cells to search.</li></ul></div>
</div>
</section>
<section id="rules">
<h2>Accepted rule</h2>
<div class="table-wrap"><table class="decision-table"><thead><tr><th style="width:8%">Rule</th><th style="width:52%">Text</th><th>Where it lands</th></tr></thead><tbody>
<tr><td>TS-1</td><td><strong>Label collections.</strong> Every capture carries <code>collection_basis</code>. The label applies to the <strong>whole capture, including every channel and emitter in it</strong>. A cued capture also carries the <code>cue_ref</code> of the prediction that caused it (track, prediction revision, observer, cued emitter, window start).</td><td>ICD <code>collection_task</code>, <code>capture_record</code>, dataset manifest; DR-TS-1, DR-DATA-6</td></tr>
<tr><td>TS-2</td><td><strong>Label products.</strong> Every detection list and track report carries <code>truth_use</code>, judged <strong>per product</strong>, and records the <strong>emitter</strong> (<code>emitter_id</code>, RF channel) it came from.</td><td>ICD <code>detection_list</code>, <code>track_report</code>; DR-TS-2, DR-TS-6</td></tr>
<tr><td>TS-3</td><td><strong>Independent evidence.</strong> Only <code>truth_blind</code> products count as independent detection or tracking evidence. A cued collection can still give independent detection evidence, because choosing when and where to listen happens before the IQ exists, provided that nothing after capture uses the cue or ADS-B. Truth is attached only after candidates are generated.</td><td>DR-TS-3; SR-07</td></tr>
<tr><td>TS-4</td><td><strong>Rates.</strong> Detection probability from cued collections is reported as conditional on a cued opportunity. This holds for <strong>every product of a cued collection, including products on emitters other than the cued one</strong>, because the whole collection was cued. False-alarm rates state the collections, emitters and cells they were measured on. A rate from cued data is not presented as the rate of uncued operation.</td><td>DR-TS-4</td></tr>
<tr><td>TS-5</td><td><strong>Cue-aided association.</strong> Results that used cues for association or initiation are scored and reported separately, labelled <code>cue_aided</code>, and never presented as independent tracking performance. Because cues and scoring truth share one ADS-B source, agreement between a cue-aided track and ADS-B is a consistency check, not a measurement.</td><td>DR-TS-5; SR-08</td></tr>
<tr><td>TS-6</td><td><strong>Scoring source.</strong> Scoring uses the logged ADS-B reports for the collection window, not CT predictions.</td><td>SR-06</td></tr>
<tr><td>TS-7</td><td><strong>Reports.</strong> Every reported result based on cued data states its <code>collection_basis</code>, <code>truth_use</code> and emitter; <code>cue_aided</code> evidence is never classed as operational evidence.</td><td>SR-13; reporting rules</td></tr>
</tbody></table></div>
</section>
<section id="examples">
<h2>How the rule sorts typical cases</h2>
<div class="table-wrap"><table class="decision-table"><thead><tr><th style="width:40%">Case</th><th style="width:14%">Collection basis</th><th style="width:13%">Truth use</th><th>Independent detection evidence?</th></tr></thead><tbody>
<tr><td>Timetabled capture; truth-blind detector; ADS-B attached after detection.</td><td>uncued</td><td>truth_blind</td><td>Yes.</td></tr>
<tr><td>Capture time and emitter chosen from a cue; truth-blind detector; ADS-B attached after detection.</td><td>cued</td><td>truth_blind</td><td>Yes, reported as conditional on a cued opportunity (TS-4), with the cued emitter recorded.</td></tr>
<tr><td>Cued capture widened to about 12 MHz; a truth-blind detection on an adjacent channel, from another emitter at the same or another site.</td><td>cued (whole capture)</td><td>truth_blind</td><td>Yes, still conditional on the cue (TS-4); the product records its own emitter, not the cued one (TS-2).</td></tr>
<tr><td>Cued capture; detector searches only the range-Doppler cells around the cue's prediction.</td><td>cued</td><td>cue_aided</td><td>No. Consistency check only.</td></tr>
<tr><td>Tracker uses cues to start or associate tracks.</td><td>any</td><td>cue_aided</td><td>No. Scored and reported separately as cue-aided tracking (TS-5).</td></tr>
<tr><td>Pluto calibration capture.</td><td>calibration</td><td>—</td><td>Not detection evidence; calibration evidence only.</td></tr>
</tbody></table></div>
</section>
<section id="followup">
<h2>Follow-up in the controlled documents</h2>
<ul class="plain-list">
<li>The Proposed ICD §3 messages will need an <strong>emitter list</strong> and a <strong>capture bandwidth</strong>: <code>collection_task</code> today names one <code>emitter_id</code>, and <code>capture_record</code> has a centre frequency and sample rate but no emitter list (DR-DATA-7).</li>
<li><code>detection_list</code> and <code>track_report</code> already carry <code>emitter_id</code>; they will need <code>truth_use</code> (DR-TS-2, DR-TS-6).</li>
<li>A “Truth separation” design rule is to be added to the architecture. All of this is action A-7 (Leif); the ICD is not edited yet.</li>
</ul>
<p class="source">Master: <a href="{MAIN}/Change_Requests.md">Change_Requests.md, CR-9</a> (accepted 2026-09-26). Requirements DR-TS-1 to DR-TS-6 and DR-DATA-6, DR-DATA-7 in the <a href="02_Requirements.html">DRAFT baseline</a>. Family rule: <a href="../reports/03_AnalysisPipelineAndGateRebuild.html">Report 03</a> (truth separation in the G1–G10 gates).</p>
</section>
"""
    return page("06_TruthSeparation.html", "Truth Separation for Cued Collections", "System engineering · step 6",
                "How cued collections and cue-aided association are labelled, counted and scored", body,
                "Accepted truth-separation rule (CR-9) for cued collections and cue-aided association.")


def page_asbuilt() -> str:
    body = f"""
<section id="purpose">
<h2>Purpose</h2>
<p class="eli5"><strong>Bottom line (ELI5):</strong> The design says what should exist; this page says what actually runs, where, with which settings, and what is still to fix.</p>
{boundary("as-built entries are installed-state records. They show that something is deployed and how it is configured, not that it performs to any requirement; performance status is on the verification page.")}
</section>
<section id="items">
<h2>Software items as built</h2>
<div class="table-wrap"><table class="decision-table"><thead><tr><th style="width:8%">ID</th><th style="width:40%">As built, 2026-09-26</th><th style="width:30%">Code (repository, branch)</th><th>Runs on</th></tr></thead><tbody>
<tr><td>AR</td><td>Operating: dump1090 in Docker, SBS on TCP 30003.</td><td>—</td><td>ADS-B Pi</td></tr>
<tr><td>CT</td><td>Operating as the systemd service <code>adsb-cue</code>, enabled at boot; publishes CT 2.0.0 compressed with dictionary 1.</td><td><a href="{CT_REPO}/tree/feature/passive-radar-cueing">ADSB-remoter <code>feature/passive-radar-cueing</code></a> (deployed at <a href="{CT_PIN}"><code>55062fc</code></a>)</td><td>ADS-B Pi</td></tr>
<tr><td>RM</td><td>First piece only: CueListener receives and ranks cues; no tasking. Run by hand.</td><td><a href="{CUE_BRANCH}">flightTest <code>feature/adsb-cue-listener</code></a> (review point <a href="{CUE_PIN}"><code>94bf924</code></a>); stays on the branch pending review (A-1)</td><td>Collection desktop</td></tr>
<tr><td>RC</td><td>Rev 1 capture scripts; not driven by tasks.</td><td>flightTest <code>TestSetupTesting/</code></td><td>Collection desktop</td></tr>
<tr><td>SP</td><td>Offline pipeline; detector not yet producing truth-matched detections.</td><td>flightTest <code>BistaticDataAnalysis/</code></td><td>Desktops</td></tr>
<tr><td>CM</td><td>Pluto calibration scripts and a geometry-based DTV level check.</td><td>flightTest <code>feature/pluto-azimuth-environment-scan</code>; the <code>dtv*</code> scripts also on <code>feature/adsb-cue-listener</code></td><td>Collection desktop</td></tr>
<tr><td>TR, RD, AM, AC</td><td>Not built.</td><td>—</td><td>—</td></tr>
</tbody></table></div>
</section>
<section id="config">
<h2>Deployed cue-tasker configuration</h2>
<div class="table-wrap"><table class="decision-table" style="min-width:640px"><thead><tr><th style="width:45%">Setting</th><th>Value</th></tr></thead><tbody>
<tr><td>Observers</td><td>The real receive site only; receiver 10 dBi, NF 3 dB, 8 MHz (set explicitly)</td></tr>
<tr><td>Prediction horizon / sample interval</td><td>600 s / 10 s</td></tr>
<tr><td>Detection threshold for predicted windows</td><td>−10 dB, pre-integration (modeled)</td></tr>
<tr><td>Maximum prediction age; ADS-B report age for “degraded”</td><td>30 s; 20 s</td></tr>
<tr><td>Destination</td><td>UDP multicast <code>239.192.10.1:31986</code>, TTL 1</td></tr>
<tr><td>Encoding; datagram limit; opportunities per cue</td><td><code>deflate_dictionary</code> with dictionary 1; 1472 B; up to 8</td></tr>
<tr><td>Heartbeat; snapshot</td><td>10 s; 60 s</td></tr>
</tbody></table></div>
<p class="source">Source: <a href="{CT_PIN}/deploy/pi-cue-config.json"><code>deploy/pi-cue-config.json</code></a>, <a href="{CT_PIN}/deploy/pi-observers.ini"><code>deploy/pi-observers.ini</code></a>, <a href="{CT_PIN}/deploy/adsb-cue.service"><code>deploy/adsb-cue.service</code></a>.</p>
</section>
<section id="time">
<h2>Time source</h2>
<div class="two-col">
<div class="callout"><strong>Accepted: internet NTP</strong><ul class="plain-list"><li>chrony on the Pi keeps time from internet NTP, routed through the collection desktop.</li><li>Stated tolerance: <strong>0.1 s</strong> between the Pi and the collection desktop (accepted by the owner on 26 September 2026, DR-TIME-1). Basis: the one check after NTP was reachable found +0.05 to +0.09 s, limited by SSH jitter; chrony reported 0.3 ms to its source.</li><li>Why 0.1 s is enough for now: at up to about 290 m/s, 0.1 s changes the bistatic range by at most about 58 m, about one range cell for a ~5.4 MHz ATSC signal.</li></ul></div>
<div class="callout warn"><strong>To do and open</strong><ul class="plain-list"><li>Hardware to-do: GPS/PPS reference clocks are configured but not locked; a loose component is suspected. Reseat and re-check (A-2, Leif; DR-TIME-3). Not a blocker for NTP-based timing.</li><li>Open: the Pi was measured 14.9 s slow before 2026-09-25 21:07 UTC. ADS-B truth recorded before then, including the 2026-09-25 tracking scan, is not timing truth until its offset is bounded (A-3, Pat; DR-TIME-4).</li><li>Open: no package yet records the hosts' time-sync state (DR-TIME-2).</li></ul></div>
</div>
</section>
<section id="actions">
<h2>Action register</h2>
{ACTIONS}
<p class="source">Masters: <a href="{MAIN}/As_Built.md">As_Built.md</a>, <a href="{MAIN}/Change_Requests.md">CR-8</a>, <a href="{MAIN}/Verification_Log.md">Verification_Log.md</a>. Host addresses and access details are kept in the master record, not on this site.</p>
</section>
"""
    return page("07_AsBuiltAndConfiguration.html", "As-Built and Configuration", "System engineering · step 7",
                "What runs where, with which settings, and the open actions", body,
                "As-built state, deployed configuration, time source and actions for the passive radar testbed.")


README = """# System engineering section

The System Engineering section of the FlightTest reporting site. It is **separate from the exploration report family** in `../reports/` (which stays at nine reports and asks "can we do it, and what does it look like"). It presents the testbed as a formal system design process. The pages are not listed in `../metadata/family_manifest.json` as family reports.

The masters stay in flightTest `docs/system/` on `main` (architecture, requirements, ICD, as-built record, change requests, verification log, raw captures). These pages summarise and link to them. The requirements tables are generated from `docs/system/Requirements.md`.

| Page | Step | Purpose |
| --- | --- | --- |
| [index.html](index.html) | 0 | Process overview, decisions, action register, status at a glance |
| [01_MissionAndNeeds.html](01_MissionAndNeeds.html) | 1 | Mission goals, stakeholders, mission needs |
| [02_Requirements.html](02_Requirements.html) | 2 | **DRAFT** requirements baseline (CR-10 open): tree, status counts, full tables |
| [03_ArchitectureAndAllocation.html](03_ArchitectureAndAllocation.html) | 3 | Architecture figure, items, allocation, requirements per item, design rules |
| [04_Interfaces.html](04_Interfaces.html) | 4 | ICD summary: status ladder, message register, conventions, transport |
| [05_VerificationAndTraceability.html](05_VerificationAndTraceability.html) | 5 | Verification activities and the traceability matrix |
| [06_TruthSeparation.html](06_TruthSeparation.html) | 6 | Accepted rule for cued collections and cue-aided association (CR-9), with the multi-emitter and wide-capture amendment |
| [07_AsBuiltAndConfiguration.html](07_AsBuiltAndConfiguration.html) | 7 | As-built items, deployed configuration, time source, actions |
| [SDR_CT_CueTasking_V1.html](SDR_CT_CueTasking_V1.html) | SDR | Subsystem design record 1: ADS-B Cue Tasker and the verified cue interface |

Every page states its purpose and claim boundary. Status words for requirements and interfaces (Verified, Partial, Proposed) are requirement- or interface-level; none of them is a radar-performance result.
"""


def refresh_sdr_nav() -> None:
    for name in SDR_PAGES:
        path = OUT / name
        text = path.read_text(encoding="utf-8")
        new, n = re.subn(r"<!-- system-nav -->.*?<!-- /system-nav -->",
                         lambda _m: "<!-- system-nav -->" + nav(name) + "<!-- /system-nav -->", text, flags=re.S)
        if n != 1:
            raise SystemExit(f"{name}: expected one system-nav marker pair, found {n}")
        if ".kicker{" not in new:
            new = new.replace("</style>\n</head>", ".kicker{margin:0;color:var(--blue);font-size:.82rem;font-weight:750;letter-spacing:.08em;text-transform:uppercase}\n</style>\n</head>", 1)
        path.write_text(new, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    builders = {
        "index.html": page_index,
        "01_MissionAndNeeds.html": page_mission,
        "02_Requirements.html": page_requirements,
        "03_ArchitectureAndAllocation.html": page_architecture,
        "04_Interfaces.html": page_interfaces,
        "05_VerificationAndTraceability.html": page_verification,
        "06_TruthSeparation.html": page_truth,
        "07_AsBuiltAndConfiguration.html": page_asbuilt,
    }
    for name, build in builders.items():
        (OUT / name).write_text(build(), encoding="utf-8")
    (OUT / "README.md").write_text(README, encoding="utf-8")
    refresh_sdr_nav()
    c = Counter(r["ID"].split("-")[0] for r in REQS)
    print(f"wrote {len(builders)} pages + README; requirements parsed: {dict(c)}")


if __name__ == "__main__":
    main()
