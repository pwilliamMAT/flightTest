# Update memo: 2026-09-26 system architecture and ADS-B cue-tasking candidates

For: Leif (owner). Status: **candidates for review. Nothing is promoted.** `reporting/` is unchanged on this branch, and `main` has not been pushed. The whole candidate set lives in `candidates/2026-09-26_cue_tasking/` on branch `reporting/candidates-cue-tasking`.

## 1. Recommendation

| # | Candidate | Proposed target in `reporting/` | Why |
|---|---|---|---|
| 1 | `overlay/systems/SystemArchitectureAndCueTasking_V1.html` + `_assets/` (3 SVG) | new folder `systems/` (companion, **outside** the canonical family) | New question that no accepted report owns: how the testbed is organised as a system, and whether the CT → RM cue interface works. |
| 2 | `overlay/reports/06_StatusAndFutureWork_V3.html` | `reports/` (replaces V2 as the family's 06) | 06 owns "where the project stands". V2 is dated 2026-09-18 and does not know about the cue interface, the time-source finding, or the 2026-09-25 live-aircraft diagnostic. |
| 3 | `overlay/reports/02_HardwareAndCollection_V5.html` | `reports/` (replaces V4 as the family's 02) | 02 owns installed collection infrastructure. The Pi cue service is installed infrastructure, and the time-source finding changes what 02 can say about ADS-B truth timing in its packages. |
| 4 | `overlay/metadata/*`, `overlay/index.html`, `overlay/reporting_README.md`, `overlay/systems/README.md` | same paths | Records and navigation for 1–3. |

The three reports link to one another, so promote them together or adjust the links (section 6).

## 2. What changed in engineering, and why it belongs in reporting

On 2026-09-25/26 the testbed was given a system-engineering baseline, and its first live interface was verified.

- **System documents** (flightTest `docs/system/` on `main`, commit `ad64bcd`, master copy since 2026-09-26): the architecture (ten software items AR, CT, RM, RC, SP, TR, RD, CM, AM, AC); ICD Draft B (CT messages 2.0.0; all other messages Proposed); As_Built; CR-1 … CR-8; the Verification Log; Engineering Notes; the encoding analysis and CT 2.0 design; the compiled-app probe; the raw wire captures.
- **CT (ADSB Cue Tasker)**, ADSB-remoter `feature/passive-radar-cueing` @ `55062fc`: headless mode; systemd `adsb-cue` on the ADS-B Pi; CT 2.0.0 compressed with dictionary 1 (raw deflate, preset dictionary); multicast `239.192.10.1:31986`; fit to one frame with up to 8 opportunities. Two defects were fixed: a Textual exclusive worker cancelled the SBS reader (`12e91fc`), and oversize cues were dropped (CR-1, then CR-5).
- **RM first piece (CueListener)**, flightTest `feature/adsb-cue-listener` @ `94bf924`, **not on `main`**: a MATLAB receiver built on Java multicast and `java.util.zip`. It applies the ICD receiver rules and does no tasking.
- **Live acceptance**, 2026-09-26 15:23–15:38 UTC. Why it matters: it is the first verified system interface, and it is the interface future collections will be tasked from.
- **Time-source finding.** The Pi ran 14.9 s slow while GPS/PPS was unlocked and it had no internet NTP. Why it matters: it bears directly on ADS-B truth timing, which Reports 02 and 06 (STAT-006, R5B) already treat as a qualification dependency.

The family's reporting rules apply because these results change the current status (06) and the installed-infrastructure record (02). They also carry a claim-boundary risk: "Verified" could be read as a radar result.

## 3. Which reports own the change (from the metadata)

- `family_manifest.json`: 02's question is "What physical hardware and collection infrastructure were built?", with the boundary "Infrastructure is not radar performance". **The installed CT service and the time-source state fit here.** 06's question is "Where does the project stand, and what should happen next?". **The new status, blockers and next actions fit here.**
- No family member owns system architecture or interface control. 03 owns the analysis-pipeline gates (G1–G10), which is a different question. Folding the architecture and ICD into 02 or 03 would break the one-question-per-report rule.
- `family_handoff_catalog.csv`: the eight handoffs form one chain (01 → … → 06). The cue interface produces nothing that a downstream family report consumes yet, because no collection has been tasked from a cue. That is why I recommend a **companion** report for now.
- `family_known_gaps.md`: the time source, the unscheduled collections, the unwritten truth-separation rule for cued collections, and the code that is not on `main` are new gaps. They are added in the candidate.

### Options for the new report (owner decides)

| Option | What it means | Implications |
|---|---|---|
| **B (recommended): companion `systems/` report** | Like `diagnostics/`: its own index section and README, outside the manifest's canonical order. | "Canonical nine-report family" wording stays true. The TechnicalSummaryFamily builder and verifier need no change for this report. Revisit when cues actually task collections, because only then does it hand an artifact into the chain. |
| A: family member `02B_SystemArchitectureAndCueTasking_V1.html` | Canonical order 01, 01A, 01B, 02, **02B**, 02A, 03, 04, 05, 06. | "Nine-report family" wording changes to ten in `index.html`, `reporting_README.md`, `diagnostics/README.md`, the explainer, audits and story spine. `buildTechnicalSummaryFamily.m` (`localReportDefinitions`) and `verifyTechnicalSummaryFamily.m` (the expected list at lines 74–84; checks for "nine" at 149–150, 225, 230 and 496; "Eight canonical handoffs" at 261) all hard-code nine reports and eight handoffs. It needs new handoffs 02→02B and 02B→02A; the latter is artificial. Rename the file and move it to `reports/`. |
| C: no new report | Put the architecture and cue content into 06 V3 only. | 06 would own a second question, and 02/06 would carry ICD detail they are not built for. Not recommended. |

## 4. New claims, their evidence class, and their boundary

| Claim (where) | Evidence class | Status label | Source | Boundary stated in the report |
|---|---|---|---|---|
| Ten software items and CT messages at 2.0.0 are defined; everything else is Proposed (SYS-001) | Design record | Implemented | S02, S03 | Not evidence that any design item works |
| CT runs on the Pi as `adsb-cue`, headless, CT 2.0.0, dictionary 1, multicast `239.192.10.1:31986`, ≤ 8 opportunities, 1472 B (SYS-002, 02 V5 CUE-001) | Installed | Implemented | As_Built, `deploy/` | Not uptime or long-run reliability |
| Live 2.0.0 capture: 223 datagrams, 0 schema failures, 0 gaps/duplicates/out-of-order, 0 over one frame, max 747 B, 15 consistent snapshots (14 with cues), 103 cues from 11 aircraft; median 681 B on the wire vs 9,174 B JSON (SYS-003, 06 V3 STAT-009) | Measured (message interface) | Demonstrated (ICD: Verified) | Wire capture + summary; **reproduced independently** (`generated/cue_capture_summary.json`) | Message interface only; no collection, no detection; withdrawal not observed |
| 1.1.0 cue median 7,962 B, 14/46 over one frame; 58% of bytes were labels and punctuation; 8 encodings compared (SYS-004) | Measured (option 8 is an estimate) | Investigated | Cue_Traffic_Encoding.md, 1234Z capture (median reproduced) | Why size, not bandwidth, drove CR-5 |
| CueListener decodes 2.0.0; 16/16 tests on 20 real datagrams (SYS-005, STAT-012) | Diagnostic | Implemented | CueListener tests (re-run for this review, R2026a) | No tasking; not on `main` |
| A compiled MATLAB app does Java multicast plus dictionary inflate on the Runtime; `udpport` multicast is Windows-only (SYS-006) | Diagnostic | Demonstrated | deployability/README.md | N320, Pluto, `serialport` and `tcpserver` still unchecked |
| Pi measured 14.9 s slow on 2026-09-25; NTP now (0.3 ms); GPS/PPS not locked (SYS-007, STAT-010, TIME-001) | Measured (one reading, raw not kept) + Installed | Blocked | Verification Log, As_Built, CR-8 | Earlier Pi-timed ADS-B truth has an unknown offset. **Not claimed** to explain any earlier result |
| Cue SNR windows are modeled pre-integration estimates (10 dBsm, −10 dB threshold, 8 MHz, NF 3 dB, 10 dBi) (SYS-008) | Modeled | Implemented | `bistatic.py`, `prediction.py`, `pi-cue-config.json` | Ranking only, not a detection prediction; not reconciled with 01A/01B |
| 81 CT tests pass at `55062fc` (SYS-009) | Diagnostic | Implemented | Re-run for this review | The replay-corpus test passes silently without its corpus |
| Cue-driven collection not built; `collection_task` Proposed (SYS-010, STAT-012) | — | In Progress | ICD §3.1, As_Built | — |
| Live-aircraft scan 2026-09-25: 1 of 75 truth opportunities matched; 91% of 34,054 detections at ±60 Hz (STAT-011, quoted only) | Diagnostic (owned by the accepted diagnostic) | Investigated | TrackingScan diagnostic | No gate change |
| No operational evidence (SYS-011) | Operational: none | Blocked | — | — |

No synthetic evidence is used. STAT-001 to STAT-008 in 06 V3 are **carried forward from V2 unchanged**. I did not re-read the PassiveBistaticRestart state (it lives on the Windows workstation), and 06 V3 says so.

## 5. Candidate file list

```
candidates/2026-09-26_cue_tasking/
  UPDATE_MEMO.md                      this memo
  overlay/                            mirrors reporting/; promotion = copy these paths onto reporting/
    index.html                        candidate index (02 V5, 06 V3, new "System engineering" section)
    reporting_README.md               candidate README (links, companion list, systems/ row)
    reports/02_HardwareAndCollection_V5.html
    reports/06_StatusAndFutureWork_V3.html
    systems/README.md
    systems/SystemArchitectureAndCueTasking_V1.html
    systems/SystemArchitectureAndCueTasking_assets/fig_message_size.svg
    systems/SystemArchitectureAndCueTasking_assets/fig_cue_size_vs_opportunities.svg
    systems/SystemArchitectureAndCueTasking_assets/fig_capture_timeline.svg
    metadata/family_manifest.json, family_evidence_catalog.csv, family_handoff_catalog.csv,
             family_code_navigation.csv, family_visual_catalog.csv, family_known_gaps.md
  scripts/
    summarize_cue_capture.py          decodes the committed wire capture, validates, cross-checks, draws the figures
    derive_06_V3.py, derive_02_V5.py  the exact V2→V3 and V4→V5 edits (reviewable deltas)
    derive_metadata.py                the exact metadata edits (manifest hashes of the candidate HTML)
    validate_candidates.py            step-6 validation on merged previews
  generated/cue_capture_summary.json  numbers quoted in the reports
  validation/validation_report.txt    latest validation output
```

Candidate SHA-256: 02 V5 `cd03cf2b…19b1fd`, 06 V3 `a59d1d19…a355`, system report `fe520544…24fd` (the full hashes of 02 and 06 are in the candidate manifest).

**Reproduce** from the worktree root:

```bash
~/Documents/ADSB-remoter/.venv/bin/python candidates/2026-09-26_cue_tasking/scripts/summarize_cue_capture.py --adsb-remoter ~/Documents/ADSB-remoter
python3 candidates/2026-09-26_cue_tasking/scripts/derive_06_V3.py
python3 candidates/2026-09-26_cue_tasking/scripts/derive_02_V5.py
python3 candidates/2026-09-26_cue_tasking/scripts/derive_metadata.py
python3 candidates/2026-09-26_cue_tasking/scripts/validate_candidates.py
```

To view as it would publish: copy `reporting/` to a scratch folder, copy `overlay/` on top, and open `index.html`. In place, the 02 V5 photographs (`../HardwarePhotos/`) and the cross-links resolve only in that merged view.

## 6. Exactly what promotion would change in `reporting/`

1. **Add:** `systems/README.md`, `systems/SystemArchitectureAndCueTasking_V1.html`, `systems/SystemArchitectureAndCueTasking_assets/*.svg` (3 files); `reports/02_HardwareAndCollection_V5.html`; `reports/06_StatusAndFutureWork_V3.html`.
2. **Replace:** `index.html`: Latest-status link → 06 V3; family cards 02 → V5 and 06 → V3; new "System engineering" section before "Diagnostic reports".
3. **Replace:** `reporting_README.md`: Latest status → V3; table links for 02 and 06; companion-list entry for `systems/`; structure-table row for `systems/`.
4. **Replace:** `metadata/`:
   - `family_manifest.json`: reports 02 and 06 get the new filenames, `source_hash` = candidate SHA-256, and `release_hash: null`. `source_report_hashes` is updated. Two `known_gaps` are added, plus a new `post_release_changes` block that says no TechnicalSummaryFamily release was built.
   - `family_evidence_catalog.csv`: CAT-02 and CAT-06 get the new ReleaseAsset and extended StillUnknown.
   - `family_handoff_catalog.csv`: H04 evidence is now "Report 02 V5".
   - `family_code_navigation.csv`: 5 rows added for CT, cue capture, CueListener, docs/system, and the figure script.
   - `family_visual_catalog.csv`: VIS-20 to VIS-23 added.
   - `family_known_gaps.md`: a new "Added 2026-09-26" section and a release-policy sentence.
5. **Superseded files. Decide:**
   - **Retain (recommended).** Keep `reports/02_HardwareAndCollection_V4.html` and `reports/06_StatusAndFutureWork_V2.html` unchanged. Accepted reports 01, 01A, 01B, 04 and 05, the story spine, and the storyboard review link to them by name.
   - **Replace**, as the guide literally says. Deleting them breaks **9** links in accepted pages: `01A`→02 V4 and 06 V2; `01B`→02 V4; `01`→06 V2; `04`→06 V2; `05`→02 V4 and 06 V2; the story spine→02 V4 and 06 V2. Fixing those would mean editing accepted reports.
   - With Retain, `reports/` holds 11 HTML files, not "exactly the intended accepted versions". The manifest and index still name only the nine current ones.
6. **Not changed, but they reference the old versions** (update only if separately reviewed): `audits/report_family_story_spine.html`, `explainers/FlightTest_EndToEnd_HumanStory_V2.html`, `storyboards/*`, `docs/START_HERE.md`, `docs/ENGINEERING_INDEX.md`, `audits/*.md`, `migration_plan.md`.
7. **Scripts** (`reporting/scripts/`): `buildTechnicalSummaryFamily.m` (`localReportDefinitions`, about line 92) and `verifyTechnicalSummaryFamily.m` (lines 74–84) hard-code `02_HardwareAndCollection_V4.html` and `06_StatusAndFutureWork_V2.html`. A verifier run after promotion would therefore fail. The verifier's obsolete-name list (about line 647) would also need `02_…_v4` and `06_…_v2`. The builder also **regenerates** the `family_*` metadata from definitions embedded in the script, so the hand-edited metadata above would be overwritten by the next builder run unless the builder is updated too. I have not changed these scripts.
8. Suggested staging at promotion (not run): `git add reporting/systems reporting/reports/02_HardwareAndCollection_V5.html reporting/reports/06_StatusAndFutureWork_V3.html reporting/metadata reporting/index.html reporting/reporting_README.md`.

## 7. Step-6 validation checklist (candidate view)

Run by `scripts/validate_candidates.py` on merged previews, with results in `validation/validation_report.txt`.

| Check | Result |
|---|---|
| Family contains exactly the intended accepted versions in canonical order | **Pass** for manifest, index and filenames (01, 01A, 01B, 02 V5, 02A, 03, 04, 05, 06 V3). `reports/` equals the family only in "replace" mode; "retain" keeps the two superseded files (section 6.5) |
| Every report-local image, asset and report link resolves | **Pass for every candidate page** (0 broken relative links, fragments checked). Promotion introduces 0 new broken links in "retain" mode and 9 in "replace" mode. `http(s)`/`file:` links are not network-checked (existing known-gap policy) |
| Reporting index links to the new filenames | **Pass** (02 V5, 06 V3, systems report; old versions no longer linked from the index) |
| Accepted reports not reformatted or changed | **Pass.** The overlay replaces only `index.html`, `reporting_README.md` and six metadata files. The derive scripts read V2/V4 and never write them |
| No draft, generated or restricted material | **Pass after review.** No keys, credentials, private host IPs, logins or candidate-branch paths are in the published files. The only multicast address is `239.192.10.1`. The only "Draft" hits are the ICD revision name "Draft B" and the ICD status ladder. The three SVG figures are generated, but their script is included and they are the report's evidence figures, as with other report-local assets |
| HTML/SVG/JSON/CSV well formed | **Pass** (balanced tags; SVG parses as XML; JSON parses; CSV column counts constant) |
| Numbers trace to sources | **Pass.** All 10 cross-checks of the reproduced capture summary against the committed one match exactly; the 1.1.0 median of 7,962 B and 14/46 over one frame reproduce S08 |

**Pre-existing issues, not caused by the candidates.** The accepted site today already has **62 broken relative links**:

- companion CSV/MD/YAML files that were not migrated;
- `../LinkBudget/`, `../RFBudget/` and `.pptx` links;
- the explainer's `TechnicalSummaryFamily/…` links;
- links to the superseded `02_HardwareAndCollection_V3.html` from 01, 04 and 06 V2;
- storyboard links that assume a flat folder.

The candidates fix their own instances: 06 V3 links 02 V5 and 05, and 02 V5 and 06 V3 show the unpublished CSVs as plain text. `diagnostics/README.md` still says the diagnostics are "not listed in `../index.html`", which is no longer true.

## 8. Open questions for Leif

1. **Placement of the new report:** Option B, a companion in `systems/` (recommended); Option A, family member 02B (implies ten reports and builder/verifier changes); or Option C, 06 V3 only?
2. **Superseded files:** retain 02 V4 and 06 V2 in `reports/` so the accepted links keep working (recommended), or replace them and accept or repair the 9 broken links?
3. **Builder and verifier:** update the hard-coded filenames (and the embedded metadata definitions), or record the post-release change in the manifest only, as the candidate does, until the next release build?
4. **Truth separation for cued collections:** the family rule says ADS-B is post-hoc and must not steer detection. Cues will now choose when and on which illuminator to collect, and the architecture lets the Tracker use cues as an association aid. Should this become a CR/decision, for example "cue-selected timing and cue-aided association are recorded and excluded from truth-blind G8/G10 evaluation; Pfa is estimated on uncued or blinded data"? The reports flag it as not yet written down.
5. **Time source:** accept NTP-via-desktop with a stated tolerance, or require GPS/PPS lock before cued collections count? Should any earlier package's ADS-B timing (including the 2026-09-25 tracking scan) be re-checked for the Pi offset? The reports make no claim either way.
6. **Code location:** CueListener and the `dtv*` scripts are not on `main`. The report's code navigation says so. Merge them before promotion, or publish with branch links pinned to commit `94bf924`?
7. **ADSB-remoter visibility:** the reports link `github.com/lhilleMAT2022/ADSB-remoter` at commit `55062fc`. If that repository is private, public readers get 404s. Acceptable?
8. **Figure-script home:** `summarize_cue_capture.py` currently lives only on this branch. Move it to `docs/system/analysis/` (proposed) before promotion, so the code-navigation row can point to `main`?
9. **Manifest provenance:** new versions cannot go into ManagerReport (the workflow must not modify it). Is `source_report_hashes.SourcePath = "flightTest main: reporting/reports/…"` acceptable?

## 9. Git

- Branch `reporting/candidates-cue-tasking` from `origin/main` @ `ad64bcd`. Only `candidates/2026-09-26_cue_tasking/` is added. The checkpoint commit `0d07ddd` was followed by the final commit (see `git log`).
- Nothing under `reporting/` is modified; `main` is not pushed. Pushing this branch does not trigger the Pages workflow, which runs only on pushes to `main` that touch `reporting/**`.
