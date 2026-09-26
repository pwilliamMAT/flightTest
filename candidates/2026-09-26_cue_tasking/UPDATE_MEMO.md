# Update memo: System Engineering section, requirements baseline, and cue-tasking updates (2026-09-26)

For: Leif (owner). Status: **candidates and proposals, ready for promotion, not yet promoted.** Branch `reporting/candidates-cue-tasking`. `reporting/` is unchanged on this branch, and `main` has not been pushed.

## 0. Owner decisions applied

**First round (2026-09-26):**
- System engineering gets its own section, built as a formal design process. The exploration family stays at nine reports.
- The superseded 02 V4 and 06 V2 stay in `reports/`.
- The builder and verifier are updated and tested in a scratch workspace.
- The truth-separation rule is written down.
- Internet NTP is accepted as the time source; GPS/PPS lock is a hardware to-do.
- CueListener stays on its branch, with a review action for Pat.
- ADSB-remoter is public, so links to it are fine.
- The figure script moves to `docs/system/analysis/`.
- The manifest SourcePath reads "flightTest main: reporting/reports/…".

**Second round (2026-09-26):**
1. **Requirements publish as DRAFT.** The requirements page, its section-index card, the reporting-index card and the section navigation all say DRAFT. CR-10 stays open.
2. **The 0.1 s NTP tolerance is accepted** (DR-TIME-1). The other TBD values stay TBD.
3. **The Python Cue Tasker is an accepted named exception under MG-1.** DR-DEP-4 is now Verified.
4. **CR-9 is accepted, with an amendment.** One site may host several emitters, and a capture may be widened to about 12 MHz. The amended rule:
   - the cued/uncued label covers the whole capture, including every channel in it;
   - every product records its emitter;
   - products on other emitters of a cued collection are still conditional on the cue;
   - truth-blind versus cue-aided is judged per product;
   - "tower" means the transmitter site, and a cue names an emitter.

   This touches CR-9, DR-TS-1..6 (new DR-TS-6), new DR-DATA-7, the truth-separation page and the known gaps. The CR-9 follow-up records that the Proposed ICD §3 `collection_task` and `capture_record` need an emitter list and a capture bandwidth. The ICD itself is not edited.
5. **The Report 02 acceptance tests stay out of the requirements.** Recorded in Requirements.md §7 and on the requirements page.
6. **Owners.** System, RF and integration actions go to Leif; everything else to Pat. A-1 Pat, A-2 Leif, A-3 Pat, A-4 Leif, A-5 Pat, A-6 Leif, and new A-7 Leif (the ICD and architecture follow-up from CR-9). This is applied to the section index, the as-built page, and the 06 V3 management row.
7. **No full release build.** The manifest keeps its `post_release_changes` note and adds `"full_build": "not run …"`. The known gaps (markdown and manifest) record that a full build needs files from the Windows workstation.

## 1. Structure

```
reporting/
  index.html                  + "System engineering" section, separate from the family (requirements card says DRAFT)
  reporting_README.md         + section link and structure row
  reports/                    exploration family, still nine reports:
    02_HardwareAndCollection_V5.html   (current; V4 retained unchanged)
    06_StatusAndFutureWork_V3.html     (current; V2 retained unchanged)
  system/                     System Engineering section
    index.html                 0 · process, decisions, action register (owners), status counts
    01_MissionAndNeeds.html    1 · mission goals, stakeholders, needs
    02_Requirements.html       2 · DRAFT baseline, generated from docs/system/Requirements.md
    03_ArchitectureAndAllocation.html  4 · 04_Interfaces.html  5 · 05_VerificationAndTraceability.html
    06_TruthSeparation.html    6 · accepted rule CR-9 (multi-emitter amendment) and worked cases
    07_AsBuiltAndConfiguration.html    7 · as-built, CT configuration, time source, action register
    SDR_CT_CueTasking_V1.html + SDR_CT_CueTasking_assets/ (3 SVG)   subsystem design record 1
    README.md
  metadata/ (6 files), scripts/ (builder and verifier)
docs/system/ (proposals, to merge to main first):
  Requirements.md (new, DRAFT); Change_Requests.md (CR-9 accepted and amended, CR-10 open, CR-8 time decision);
  README.md; As_Built.md; analysis/summarize_cue_capture.py
```

## 2. Draft requirements baseline (counts after the second round)

| Level | Count | Verified | Partial | Not met | Not started | Proposed |
|---|---:|---:|---:|---:|---:|---:|
| Mission goals | 2 | — | — | — | — | — |
| Mission needs | 6 | 0 | 5 | 1 | 0 | 0 |
| System requirements | 15 | 1 | 8 | 1 | 5 | 0 |
| Derived requirements | 30 | 6 | 5 | 7 | 5 | 7 |

Top-level tree:

```
MG-1  complete system built with MATLAB and MathWorks tools
  MN-1  complete chain, MATLAB except named exceptions ... SR-02, SR-07, SR-08, SR-12, SR-14, SR-15
  MN-2  real data on aircraft of opportunity ............. SR-01, SR-03, SR-04, SR-09
  MN-5  claims traceable to evidence ..................... SR-13
  MN-6  MATLAB items run as deployed apps
MG-2  data proving MATLAB functions on shareable real data
  MN-3  independent truth for every dataset .............. SR-05, SR-06
  MN-4  shareable datasets ............................... SR-10, SR-11
Derived: DR-CUE-1..7, DR-TASK-1..2, DR-TIME-1..4, DR-DATA-1..7, DR-DEP-1..4, DR-TS-1..6
```

Status changes in the second round:

- **DR-DEP-4** is now Verified (the exception is accepted).
- **DR-TS-3, 4 and 5** are Not started. The rule is accepted, but no cued products exist yet.
- **DR-TS-1, DR-TS-2, new DR-TS-6 and new DR-DATA-7** are Proposed, because the ICD messages that will carry them are still Proposed.

## 3. Validation, re-run after the second round

**Candidate view** (`scripts/validate_candidates.py`):

- All 12 candidate pages are well formed and have 0 broken relative links.
- Keeping V4/V2 in `reports/` introduces 0 new broken links.
- The index links the new files, and the canonical order holds.
- There is no restricted material.
- The `docs/system` links resolve.
- **Confidential wording: 0 hits** in every file and line the branch adds. The term list is kept outside the repository and passed with `--confidential-terms`.
- The only DRAFT-labelled content is intentional: the requirements baseline, which the section navigation shows on every section page.

**Changes under `reporting/`: 0.** `git diff origin/main -- reporting` is empty.

**Builder test** (scratch workspace, R2026a; `validation/builder_test_report.txt`):

- Failed checks: 306, all "Dependency resolution" (273 Windows-workstation `file:///` links and 33 companion files that exist only in ManagerReport). This is a strict subset of the unmodified control's 319.
- The builder-generated metadata matches the candidate metadata in every value that doesn't depend on the build machine.
- A full release build needs the Windows workstation, which is not available. This is recorded as a known limitation.

## 4. Exactly how promotion would run (not run here)

From a clean clone or worktree of flightTest, with the push identity already configured:

```bash
# 0. Start from the reviewed branch
git fetch origin
git switch main && git pull --ff-only origin main
B=origin/reporting/candidates-cue-tasking     # or the local branch if it was not pushed

# 1. Merge the docs/system proposals to main (only docs/system; no candidates/ folder on main)
git checkout $B -- docs/system/Requirements.md docs/system/Change_Requests.md docs/system/README.md \
    docs/system/As_Built.md docs/system/analysis/summarize_cue_capture.py
git status --short                                   # expect exactly these 5 paths
git diff --cached --check
git commit -m "Add the DRAFT requirements baseline, accept CR-9 (truth separation), record time-source decisions"

# 2. Bring the candidate folder in temporarily and copy the overlay into reporting/
#    (adds system/, 02 V5, 06 V3; replaces index.html, reporting_README.md, metadata/, scripts/;
#     02 V4 and 06 V2 stay in place)
git checkout $B -- candidates/2026-09-26_cue_tasking
cp -r candidates/2026-09-26_cue_tasking/overlay/. reporting/

# 3. Validate the accepted repository view, then drop the candidate folder before committing
python3 candidates/2026-09-26_cue_tasking/scripts/validate_candidates.py --confidential-terms <external terms file>
#   expect RESULT: PASS (0 broken relative links, canonical order, index links, 0 confidential hits)
python3 -c "import json;json.load(open('reporting/metadata/family_manifest.json'))"
git rm -r -q --cached candidates && rm -rf candidates   # candidate tooling never goes to main
git add reporting/system reporting/reports/02_HardwareAndCollection_V5.html \
    reporting/reports/06_StatusAndFutureWork_V3.html reporting/metadata reporting/scripts \
    reporting/index.html reporting/reporting_README.md
git status --short                                   # expect only the reporting/ paths above
git diff --cached --check && git diff --cached --stat
git commit -m "Promote 02 V5, 06 V3 and the System Engineering section"

# 4. Push main (triggers the GitHub Pages deploy for reporting/**), then check the Actions run and the site
git push origin main
```

Notes on these steps:

- Step 1 lands before step 2 because the section pages link to the `docs/system` masters on `main`.
- Step 3 runs the validator on the promoted tree; its overlay comparison then becomes trivially equal. The branch-only check reports the same results.

## 5. Remaining open points

- **TBD values:** pointing tolerance (SR-04), ADS-B lead and tail (DR-DATA-4), and the content and approver of the data-release statement (SR-11, DR-DATA-5).
- **CR-10** (requirements baseline) stays open; the baseline publishes as DRAFT.
- **Action A-7 (Leif):** add the CR-9 labels, emitter list and capture bandwidth to the ICD, and the truth-separation rule to the architecture.
- **Not changed and still naming V4/V2** (update only if separately reviewed):
  - the story spine;
  - the explainer;
  - the storyboard;
  - `docs/START_HERE.md` and `docs/ENGINEERING_INDEX.md`.

  `diagnostics/README.md` still says the diagnostics are not listed in `index.html`, which is no longer true.

## 6. Reproduce the candidate

```bash
C=candidates/2026-09-26_cue_tasking
python3 docs/system/analysis/summarize_cue_capture.py --adsb-remoter ../ADSB-remoter --out-dir $C/generated --assets-dir $C/overlay/system/SDR_CT_CueTasking_assets
python3 $C/scripts/build_system_section.py
python3 $C/scripts/derive_06_V3.py && python3 $C/scripts/derive_02_V5.py && python3 $C/scripts/derive_navigation.py
python3 $C/scripts/derive_metadata.py && python3 $C/scripts/derive_family_scripts.py
python3 $C/scripts/validate_candidates.py --confidential-terms <terms file kept outside the repo>
python3 $C/scripts/check_builder_metadata.py <scratch>/TechnicalSummaryFamily_Releases/<id>_staging
```
