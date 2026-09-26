#!/usr/bin/env python3
"""Derive candidate buildTechnicalSummaryFamily.m and verifyTechnicalSummaryFamily.m.

Edits (every one an exact, counted replacement on the accepted scripts in reporting/scripts/):
  * canonical filenames 02 V5 and 06 V3 in both scripts;
  * the superseded 02 V4 and 06 V2 names become legacy names that the builder rewrites to the
    current versions in release copies, and obsolete names that the verifier refuses in links;
  * the builder's embedded metadata definitions carry the same strings as the hand-edited
    candidate metadata (derive_metadata.py): 02/06 still-unknown text, 06 strongest result,
    H04 evidence, VIS-07/08/09/18 paths, VIS-20..23, five code-navigation rows, known gaps,
    and manifest known_gaps.
Writes candidates/2026-09-26_cue_tasking/overlay/scripts/*.m. Reads, never writes, reporting/.

Run from the flightTest worktree root:
  python3 candidates/2026-09-26_cue_tasking/scripts/derive_family_scripts.py
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

CANDIDATE = Path(__file__).resolve().parents[1]
REPO = CANDIDATE.parents[1]
SRC = REPO / "reporting" / "scripts"
OUT = CANDIDATE / "overlay" / "scripts"

spec = importlib.util.spec_from_file_location("derive_metadata", CANDIDATE / "scripts" / "derive_metadata.py")
meta = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(meta)


def mstr(text: str) -> str:
    """MATLAB double-quoted string literal."""
    return '"' + text.replace('"', '""') + '"'


def string_matrix(rows: list[list[str]], indent: str = "    ") -> str:
    lines = [indent + ", ".join(mstr(v) for v in row) for row in rows]
    return "[ ...\n" + "; ...\n".join(lines) + "]"


def replace(text: str, old: str, new: str, count: int, name: str) -> str:
    found = text.count(old)
    if found != count:
        raise SystemExit(f"{name}: expected {count} match(es), found {found}: {old[:90]!r}")
    return text.replace(old, new)


def build_script() -> str:
    name = "buildTechnicalSummaryFamily.m"
    s = (SRC / name).read_text(encoding="utf-8")
    s = replace(s, '        "02_HardwareAndCollection_V4.html", ...\n', '        "02_HardwareAndCollection_V5.html", ...\n', 1, name)
    s = replace(s, '        "06_StatusAndFutureWork_V2.html"}, ...\n', '        "06_StatusAndFutureWork_V3.html"}, ...\n', 1, name)
    s = replace(s, f'        {mstr(meta.RESULT_06_OLD)}}}, ...', f'        {mstr(meta.RESULT_06)}}}, ...', 1, name)
    s = replace(s, f'        {mstr(meta.UNKNOWN_02_OLD)}, ...', f'        {mstr(meta.UNKNOWN_02)}, ...', 1, name)
    s = replace(s, f'        {mstr(meta.UNKNOWN_06_OLD)}}}, ...', f'        {mstr(meta.UNKNOWN_06)}}}, ...', 1, name)
    s = replace(s, f'    {mstr(meta.EVIDENCE_02_OLD)}; ...', f'    {mstr(meta.EVIDENCE_02)}; ...', 1, name)
    # Legacy names rewritten to the current canonical versions in release copies.
    s = replace(s, '    "02_HardwareAndCollection_V3.html", ...\n    "04_MitigationAndMapRateRecovery.html", ...\n    "06_StatusAndFutureWork.html"];',
                '    "02_HardwareAndCollection_V3.html", ...\n    "02_HardwareAndCollection_V4.html", ...\n    "04_MitigationAndMapRateRecovery.html", ...\n    "06_StatusAndFutureWork.html", ...\n    "06_StatusAndFutureWork_V2.html"];', 2, name)
    s = replace(s, "    reports(4).Filename, ...\n    reports(4).Filename, ...\n    reports(4).Filename, ...\n    reports(7).Filename, ...\n    reports(9).Filename];",
                "    reports(4).Filename, ...\n    reports(4).Filename, ...\n    reports(4).Filename, ...\n    reports(4).Filename, ...\n    reports(7).Filename, ...\n    reports(9).Filename, ...\n    reports(9).Filename];", 1, name)
    # Visual catalog paths and new rows.
    for old, new in [('"02_HardwareAndCollection_V4.html and HardwarePhotos"', '"02_HardwareAndCollection_V5.html and HardwarePhotos"'),
                     ('"02_HardwareAndCollection_V4.html package/manifests"', '"02_HardwareAndCollection_V5.html package/manifests"'),
                     ('    "02_HardwareAndCollection_V4.html"; ...\n', '    "02_HardwareAndCollection_V5.html"; ...\n'),
                     ('    "06_StatusAndFutureWork_V2.html"; ...\n', '    "06_StatusAndFutureWork_V3.html"; ...\n')]:
        s = replace(s, old, new, 1, name)
    visual_tail = "    'RecommendedAction','Priority','Notes'});\nend\n\nfunction codeNavigation"
    s = replace(s, visual_tail,
                "    'RecommendedAction','Priority','Notes'});\n"
                "% 2026-09-26: System Engineering section visuals (outside the family, recorded for navigation).\n"
                f"extraVisuals = array2table({string_matrix(meta.VISUAL_ROWS)}, ...\n"
                "    'VariableNames',visuals.Properties.VariableNames);\n"
                "visuals = [visuals;extraVisuals];\nend\n\nfunction codeNavigation", 1, name)
    code_tail = "    'MissingNavigation','RecommendedChange','Priority','Notes'});\nend\n\nfunction localWriteStorySpine"
    s = replace(s, code_tail,
                "    'MissingNavigation','RecommendedChange','Priority','Notes'});\n"
                "% 2026-09-26: cue tasking and system documents (code outside this repository or on branches).\n"
                f"extraCode = array2table({string_matrix(meta.CODE_ROWS)}, ...\n"
                "    'VariableNames',codeNavigation.Properties.VariableNames);\n"
                "codeNavigation = [codeNavigation;extraCode];\nend\n\nfunction localWriteStorySpine", 1, name)
    # Known gaps text (same content as the candidate family_known_gaps.md).
    added = [line for line in meta.KNOWN_GAPS_ADDED.strip("\n").split("\n")]
    matlab_added = " + newline + ...\n    ".join(mstr(line) if line else '""' for line in added)
    s = replace(s,
                '    "- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation." + newline + newline + ...\n',
                '    "- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation." + newline + newline + ...\n'
                f"    {matlab_added} + newline + newline + ...\n", 1, name)
    s = replace(s,
                '"No unresolved P0 item is hidden. The former P0 family-navigation gap is resolved by release-local navigation, explicit handoffs, canonical version mapping, and validation.";',
                '"No unresolved P0 item is hidden. The former P0 family-navigation gap is resolved by release-local navigation, explicit handoffs, canonical version mapping, and validation.' + meta.RELEASE_POLICY_ADDED.replace('"', '""') + '";', 1, name)
    # Links from family reports to site sections outside the family (system/, diagnostics/, ...)
    # do not exist inside a release package; point them at the public site instead.
    s = replace(s, "    content = localRewriteCanonicalReportLinks(content,reports);\n",
                "    content = localRewriteCanonicalReportLinks(content,reports);\n"
                "    content = localRewriteSiteSectionLinks(content);\n", 1, name)
    s = replace(s, "function content = localInjectReleaseBlock(content,report,reports,sourcePath)\n",
                "function content = localRewriteSiteSectionLinks(content)\n"
                "% Family reports may link to site sections outside the family. Those pages are not part\n"
                "% of a release package, so release copies link to them on the public reporting site.\n"
                "siteRoot = \"https://pwilliammat.github.io/flightTest/\";\n"
                "sections = [\"system\",\"diagnostics\",\"explainers\",\"audits\",\"storyboards\"];\n"
                "for index = 1:numel(sections)\n"
                "    content = replace(content,\"href=\"\"../\" + sections(index) + \"/\", ...\n"
                "        \"href=\"\"\" + siteRoot + sections(index) + \"/\");\n"
                "end\n"
                "end\n\n"
                "function content = localInjectReleaseBlock(content,report,reports,sourcePath)\n", 1, name)
    gaps = ", ...\n    ".join(mstr(g) for g in meta.MANIFEST_GAPS)
    s = replace(s, '    "No operational detection, tracking, or localization claim is established."};',
                f'    "No operational detection, tracking, or localization claim is established.", ...\n    {gaps}}};', 1, name)
    return s


def verify_script() -> str:
    name = "verifyTechnicalSummaryFamily.m"
    s = (SRC / name).read_text(encoding="utf-8")
    s = replace(s, '        "02_HardwareAndCollection_V4.html", ...\n', '        "02_HardwareAndCollection_V5.html", ...\n', 1, name)
    s = replace(s, '        "06_StatusAndFutureWork_V2.html"});', '        "06_StatusAndFutureWork_V3.html"});', 1, name)
    s = replace(s, '    "02_hardwareandcollection_v2.html","02_hardwareandcollection_v3.html", ...\n',
                '    "02_hardwareandcollection_v2.html","02_hardwareandcollection_v3.html", ...\n'
                '    "02_hardwareandcollection_v4.html","06_statusandfuturework_v2.html", ...\n', 1, name)
    # Fix: "[^\\s]" in a MATLAB string excludes backslash and the letter s, so any URL containing
    # an "s" after the scheme failed; "\\S" is the intended non-whitespace class.
    s = replace(s, 'tf = ~isempty(regexp(uri,"^https?://[^\\\\s]+$","once"));',
                'tf = ~isempty(regexp(uri,"^https?://\\S+$","once"));', 1, name)
    return s


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "buildTechnicalSummaryFamily.m").write_text(build_script(), encoding="utf-8")
    (OUT / "verifyTechnicalSummaryFamily.m").write_text(verify_script(), encoding="utf-8")
    print(f"wrote {OUT.relative_to(REPO)}/buildTechnicalSummaryFamily.m and verifyTechnicalSummaryFamily.m")


if __name__ == "__main__":
    main()
