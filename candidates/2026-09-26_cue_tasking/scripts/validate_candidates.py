#!/usr/bin/env python3
"""Validate the 2026-09-26 cue-tasking candidates as they would look after promotion.

Builds preview trees in a temporary directory (reporting/ copied, overlay/ applied on top; the
accepted reporting/ is never written) and checks, per howToUpdateReports.md step 6:

  * HTML well-formedness of every candidate page (balanced non-void tags) and SVG/XML parse of assets;
  * every relative href/src in every HTML page of the preview resolves, including #fragments;
  * the index links the new filenames; the manifest's canonical order and filenames exist;
  * the reports/ folder holds the intended family versions;
  * metadata JSON parses and CSV rows have a constant column count;
  * no restricted or draft material in the files that promotion would publish;
  * no confidential wording anywhere on the branch (terms supplied from a file outside the repository);
  * relative links in the proposed docs/system changes resolve.

Two previews are checked: "retain" (superseded 02 V4 and 06 V2 stay in reports/ unchanged) and
"replace" (they are removed). The baseline (accepted reporting/ as it is today) is also checked so
pre-existing problems are not attributed to the candidates.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/validate_candidates.py
Writes candidates/2026-09-26_cue_tasking/validation/validation_report.txt; exit 1 if a candidate check fails.
"""

from __future__ import annotations

import csv
import io
import json
import re
import shutil
import tempfile
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
REPORTING = REPO / "reporting"
OVERLAY = CANDIDATE / "overlay"
SUPERSEDED = ["reports/02_HardwareAndCollection_V4.html", "reports/06_StatusAndFutureWork_V2.html"]
FAMILY = [
    "01_NorthStarAndMotivation_V2.html", "01A_IlluminatorSelection_V4.html", "01B_ReceiveChainDesign_V2.html",
    "02_HardwareAndCollection_V5.html", "02A_SyntheticEchoGeneration_V1.html",
    "03_AnalysisPipelineAndGateRebuild.html", "04_MitigationAndMapRateRecovery_V2.html",
    "05_StrongestEvidence_G4RRecoveryStudy.html", "06_StatusAndFutureWork_V3.html",
]
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
        "path", "rect", "line", "circle", "stop", "use", "polyline", "polygon", "ellipse"}
# Confidential-wording scan: the owner's list of terms is NOT stored in the repository. Pass a file
# (one regular expression per line, "label<TAB>regex") outside the repo with --confidential-terms or
# the CONFIDENTIAL_TERMS_FILE environment variable. Allowed phrases (accepted wording copied unchanged)
# are listed one per line after a line "ALLOW".
def load_confidential(path_text: str | None) -> tuple[list[tuple[str, str]], list[str]]:
    import os
    path_text = path_text or os.environ.get("CONFIDENTIAL_TERMS_FILE")
    if not path_text:
        return [], []
    terms, allowed, allow_mode = [], [], False
    for line in Path(path_text).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        if line.strip() == "ALLOW":
            allow_mode = True
            continue
        if allow_mode:
            allowed.append(line.strip())
        else:
            label, _, regex = line.partition("\t")
            terms.append((regex, label))
    return terms, allowed


RESTRICTED = [
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key"),
    (r"(?i)\b(password|passwd|secret|api[_-]?key|access[_-]?token)\b\s*[:=]", "credential assignment"),
    (r"id_ed25519|id_rsa", "SSH key file name"),
    (r"\b(?:10|127)\.\d{1,3}\.\d{1,3}\.\d{1,3}\b|\b192\.168\.\d{1,3}\.\d{1,3}\b|\b172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}\b", "private IP address"),
    (r"\bpi2@|\bsudo\b|12ac4a1e71f93ac3", "host login, sudo, or ZeroTier network id"),
    (r"(?i)\bTODO\b|\bFIXME\b|\bTBC\b|lorem ipsum", "unfinished-work marker"),
    (r"candidates/2026-09-26|reporting/candidates-cue-tasking", "candidate-branch path"),
]


class Balance(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[tuple[str, int]] = []
        self.errors: list[str] = []
        self.ids: set[str] = set()
        self.links: list[str] = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if "name" in a and tag == "a":
            self.ids.add(a["name"])
        for key in ("href", "src"):
            if a.get(key):
                self.links.append(a[key])
        if tag not in VOID:
            self.stack.append((tag, self.getpos()[0]))

    def handle_startendtag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        for key in ("href", "src"):
            if a.get(key):
                self.links.append(a[key])

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if not self.stack:
            self.errors.append(f"line {self.getpos()[0]}: stray </{tag}>")
            return
        if self.stack[-1][0] == tag:
            self.stack.pop()
            return
        names = [t for t, _ in self.stack]
        if tag in names:
            while self.stack and self.stack[-1][0] != tag:
                t, line = self.stack.pop()
                if t not in {"p", "li", "td", "th", "tr", "dt", "dd", "option"}:
                    self.errors.append(f"unclosed <{t}> from line {line}")
            self.stack.pop()
        else:
            self.errors.append(f"line {self.getpos()[0]}: unmatched </{tag}>")


def parse(path: Path) -> Balance:
    parser = Balance()
    parser.feed(path.read_text(encoding="utf-8"))
    parser.close()
    for t, line in parser.stack:
        if t not in {"p", "li", "td", "th", "tr", "dt", "dd", "html", "body", "head"}:
            parser.errors.append(f"unclosed <{t}> from line {line}")
    return parser


def broken_links(root: Path, pages: list[Path]) -> dict[str, list[str]]:
    cache: dict[Path, set[str]] = {}
    result: dict[str, list[str]] = {}
    for page in pages:
        parser = parse(page)
        cache[page.resolve()] = parser.ids
        bad = []
        for link in parser.links:
            parts = urlsplit(link)
            if parts.scheme in {"http", "https", "file", "mailto", "data", "javascript"} or link.startswith("//"):
                continue
            target = page if not parts.path else (page.parent / unquote(parts.path))
            if not target.exists():
                bad.append(link)
                continue
            if parts.fragment and target.suffix == ".html":
                ids = cache.get(target.resolve())
                if ids is None:
                    ids = parse(target).ids
                    cache[target.resolve()] = ids
                if parts.fragment not in ids:
                    bad.append(link + " (missing fragment)")
        if bad:
            result[str(page.relative_to(root))] = sorted(set(bad))
    return result


def build_preview(tmp: Path, mode: str) -> Path:
    root = tmp / mode
    shutil.copytree(REPORTING, root)
    if mode != "baseline":
        shutil.copytree(OVERLAY, root, dirs_exist_ok=True)
    if mode == "replace":
        for rel in SUPERSEDED:
            (root / rel).unlink()
    return root


def main() -> None:
    lines: list[str] = []
    failures: list[str] = []

    def out(s: str = "") -> None:
        lines.append(s)

    published = sorted(p for p in OVERLAY.rglob("*") if p.is_file())
    out("Candidate files that promotion would publish under reporting/:")
    for p in published:
        out(f"  {p.relative_to(OVERLAY)}  ({p.stat().st_size:,} B)")

    out("\n[1] Well-formedness")
    for p in published:
        if p.suffix == ".html":
            errs = parse(p).errors
            out(f"  {'PASS' if not errs else 'FAIL'} {p.relative_to(OVERLAY)}" + (f": {errs[:5]}" if errs else ""))
            if errs:
                failures.append(f"HTML not well formed: {p.name}")
        elif p.suffix == ".svg":
            try:
                ET.parse(p)
                out(f"  PASS {p.relative_to(OVERLAY)} (XML)")
            except ET.ParseError as exc:
                out(f"  FAIL {p.relative_to(OVERLAY)}: {exc}")
                failures.append(f"SVG not well formed: {p.name}")
        elif p.suffix == ".json":
            json.loads(p.read_text(encoding="utf-8"))
            out(f"  PASS {p.relative_to(OVERLAY)} (JSON)")
        elif p.suffix == ".csv":
            widths = {len(r) for r in csv.reader(io.StringIO(p.read_text(encoding="utf-8")))}
            ok = len(widths) == 1
            out(f"  {'PASS' if ok else 'FAIL'} {p.relative_to(OVERLAY)} (CSV, columns {sorted(widths)})")
            if not ok:
                failures.append(f"CSV ragged: {p.name}")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        previews = {m: build_preview(tmp, m) for m in ("baseline", "retain", "replace")}
        out("\n[2] Relative links and local assets (http/https/file links are not network-checked)")
        results = {}
        for mode, root in previews.items():
            pages = sorted(root.rglob("*.html"))
            results[mode] = broken_links(root, pages)
            total = sum(len(v) for v in results[mode].values())
            out(f"  preview '{mode}': {len(pages)} HTML pages, {total} broken relative links")
            for page, bad in results[mode].items():
                out(f"    {page}: {bad}")
        baseline = {(k, b) for k, v in results["baseline"].items() for b in v}
        for mode in ("retain", "replace"):
            new = sorted({(k, b) for k, v in results[mode].items() for b in v} - baseline)
            out(f"  introduced by promotion in '{mode}' mode: {len(new)}")
            for k, b in new:
                out(f"    {k}: {b}")
        candidate_pages = {str(p.relative_to(OVERLAY)) for p in published if p.suffix == ".html"}
        cand_broken = {k: v for k, v in results["retain"].items() if k in candidate_pages}
        out(f"  candidate pages with any broken relative link (retain mode): {len(cand_broken)}")
        if cand_broken:
            failures.append("candidate page has broken links")

        root = previews["retain"]
        out("\n[3] Index, manifest, canonical order")
        index = (root / "index.html").read_text(encoding="utf-8")
        for name in ("reports/02_HardwareAndCollection_V5.html", "reports/06_StatusAndFutureWork_V3.html",
                     "system/index.html", "system/02_Requirements.html", "system/05_VerificationAndTraceability.html",
                     "system/SDR_CT_CueTasking_V1.html"):
            ok = f'href="{name}"' in index
            out(f"  {'PASS' if ok else 'FAIL'} index links {name}")
            if not ok:
                failures.append(f"index missing {name}")
        for old in SUPERSEDED:
            ok = f'href="{old}"' not in index
            out(f"  {'PASS' if ok else 'FAIL'} index no longer links {old}")
        order = re.findall(r'<p class="report-id">([0-9A-Z]+)</p>', index)
        out(f"  index family order: {order[:9]}")
        manifest = json.loads((root / "metadata" / "family_manifest.json").read_text(encoding="utf-8"))
        ids = [r["report_id"] for r in manifest["reports"]]
        files = [r["canonical_filename"] for r in manifest["reports"]]
        ok = ids == manifest["canonical_order"] and files == FAMILY and order[:9] == ids
        out(f"  {'PASS' if ok else 'FAIL'} manifest order {ids} matches canonical_order, index, and intended filenames")
        if not ok:
            failures.append("canonical order mismatch")
        for f in files:
            if not (root / "reports" / f).exists():
                failures.append(f"missing family file {f}")
        present = sorted(p.name for p in (root / "reports").glob("*.html"))
        extra = sorted(set(present) - set(FAMILY))
        out(f"  reports/ HTML in 'retain' mode: {len(present)}; beyond the family: {extra}")
        present_r = sorted(p.name for p in (previews["replace"] / "reports").glob("*.html"))
        out(f"  reports/ HTML in 'replace' mode: {len(present_r)}; equals intended family: {present_r == sorted(FAMILY)}")

        out("\n[4] Accepted files unchanged by the overlay (byte-identical in the preview)")
        changed = []
        for p in REPORTING.rglob("*"):
            if p.is_file():
                q = root / p.relative_to(REPORTING)
                if q.read_bytes() != p.read_bytes():
                    changed.append(str(p.relative_to(REPORTING)))
        out(f"  accepted files replaced by candidates: {sorted(changed)}")
        allowed = ({"index.html", "reporting_README.md"} | {f"metadata/{p.name}" for p in (OVERLAY / 'metadata').iterdir()}
                   | {f"scripts/{p.name}" for p in (OVERLAY / 'scripts').iterdir()})
        if set(changed) - allowed:
            failures.append(f"unexpected accepted file changed: {set(changed) - allowed}")

    out("\n[5] Restricted and draft material in files promotion would publish")
    for p in published:
        text = p.read_text(encoding="utf-8", errors="replace")
        for pattern, label in RESTRICTED:
            hits = sorted(set(m.group(0) for m in re.finditer(pattern, text)))
            if hits:
                out(f"  FLAG {p.relative_to(OVERLAY)}: {label}: {hits[:6]}")
    out("  (any FLAG above is reviewed in UPDATE_MEMO.md; 239.192.10.1 is the organization-local multicast group and is not flagged)")
    labelled = sorted(str(p.relative_to(OVERLAY)) for p in published if re.search(r"\bDRAFT\b", p.read_text(encoding="utf-8", errors="replace")))
    out(f"  Intentionally labelled DRAFT content (the requirements baseline and pages that cite it): {labelled}")

    import sys
    arg = sys.argv[sys.argv.index("--confidential-terms") + 1] if "--confidential-terms" in sys.argv else None
    CONFIDENTIAL, CONFIDENTIAL_ALLOWED = load_confidential(arg)
    out("\n[6] Confidential wording on the whole branch (files added or lines added relative to origin/main)")
    if not CONFIDENTIAL:
        out("  SKIPPED: no terms file given (the terms are kept outside the repository)")
    import subprocess
    names = subprocess.run(["git", "diff", "--name-only", "origin/main", "--"], cwd=REPO, capture_output=True, text=True, check=True).stdout.split()
    names += subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=REPO, capture_output=True, text=True, check=True).stdout.split()
    hits_total = 0
    for rel in sorted(set(names)):
        path = REPO / rel
        if not path.is_file() or path.suffix in {".png", ".jpg", ".bin"}:
            continue
        if subprocess.run(["git", "cat-file", "-e", f"origin/main:{rel}"], cwd=REPO, capture_output=True).returncode == 0:
            diff = subprocess.run(["git", "diff", "origin/main", "--", rel], cwd=REPO, capture_output=True, text=True).stdout
            text = "\n".join(l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++"))
        else:
            text = path.read_text(encoding="utf-8", errors="replace")
        for pattern, label in CONFIDENTIAL:
            if rel.endswith("validation_report.txt"):
                continue  # the checker's own output
            hits = [m.group(0) for m in re.finditer(pattern, text)
                    if not any(a in text[max(0, m.start() - 60):m.end() + 60] for a in CONFIDENTIAL_ALLOWED)]
            if hits:
                hits_total += len(hits)
                out(f"  FAIL {rel}: {label}: {len(hits)}")
    if CONFIDENTIAL:
        out(f"  {'PASS' if not hits_total else 'FAIL'}: {hits_total} confidential-wording hits ({len(CONFIDENTIAL)} terms from the external list)")
    if hits_total:
        failures.append("confidential wording")

    out("\n[7] Relative links in the proposed docs/system documents")
    bad = []
    for rel in ["docs/system/Requirements.md", "docs/system/Change_Requests.md", "docs/system/README.md", "docs/system/As_Built.md"]:
        path = REPO / rel
        for m in re.finditer(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            url = m.group(1)
            if re.match(r"https?://|#|mailto:", url):
                continue
            if not (path.parent / url.split("#")[0]).exists():
                bad.append(f"{rel}: {url}")
    out(f"  {'PASS' if not bad else 'FAIL'}: {len(bad)} unresolved" + ("".join(f"\n    {b}" for b in bad)))
    if bad:
        failures.append("docs/system links")

    out("\nRESULT: " + ("PASS" if not failures else "FAIL: " + "; ".join(failures)))
    report = CANDIDATE / "validation" / "validation_report.txt"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
