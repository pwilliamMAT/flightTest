# How to Update FlightTest Reports

Use this guide when new engineering work needs to appear in the accepted FlightTest report family and on the public reporting site.

## The operating model

```text
New engineering evidence
        ↓
Candidate report updates outside this repository
        ↓
Technical and claim-boundary review
        ↓
Accepted report versions and metadata in reporting/
        ↓
Commit and push main
        ↓
GitHub Pages republishes the reporting site
```

`reporting/` contains accepted project knowledge only. It is published by GitHub Pages, so do not place drafts, temporary products, private material, generated release directories, or experimental reports here.

`ManagerReport` remains the authoritative source archive and must not be modified by this workflow.

## Refresh process

1. Gather and preserve the new evidence.

   Keep the source data, code, audit outputs, provenance, evidence class, and claim limits together. A new hash, plot, code change, or measurement is a review trigger; it is not automatically a changed engineering claim.

2. Determine which report owns the change.

   Use `metadata/family_manifest.json`, `metadata/family_handoff_catalog.csv`, and `metadata/family_known_gaps.md` to identify the affected report or reports. Keep modeled, installed, measured, synthetic, diagnostic, and operational evidence distinct.

3. Create versioned candidate reports outside `ManagerReport` and outside `reporting/`.

   Create new candidates such as `06_StatusAndFutureWork_V3.html` in a separate writable working area. Do not overwrite an accepted report while developing or reviewing a candidate. Keep candidate-only assets alongside the candidate.

4. Review before acceptance.

   Confirm the report states its question, result, engineering decision, still-unknown items, evidence, method, code navigation, and claim boundary. Check that the new result is supported and does not silently convert synthetic or diagnostic evidence into an operational claim.

5. Promote only accepted material to `reporting/`.

   For each accepted replacement:

   - Copy the accepted HTML and every required local asset into `reports/`.
   - Replace the prior current version in `reports/` only after acceptance. The prior source remains preserved in `ManagerReport` and in Git history.
   - Update `metadata/family_manifest.json` and all affected evidence, handoff, visual, code-navigation, and known-gap records.
   - Update `reporting_README.md` and `index.html` when filenames, report order, current status, strongest evidence, or navigation labels change.
   - Update accepted audits or explainer/storyboard material only when they are separately reviewed and accepted.

6. Validate the accepted repository view.

   Before committing, check:

   - The report family still contains exactly the intended accepted versions in canonical order.
   - Every report-local image, asset, and report link resolves.
   - The reporting index links to the new filenames.
   - The accepted reports have not been reformatted or accidentally changed after acceptance.
   - The public site contains no draft, generated, or restricted material.

7. Publish with Git.

   Stage only the accepted reporting change; do not use `git add .` when unrelated work is present.

   ```powershell
   git status --short
   git add reporting/reports/<accepted-report-and-assets> reporting/metadata/<updated-metadata> reporting/reporting_README.md reporting/index.html
   git diff --cached --check
   git diff --cached --stat
   git commit -m "Refresh accepted FlightTest reporting family"
   git push origin main
   ```

   The `Deploy FlightTest reporting site` GitHub Actions workflow runs automatically after a push to `main` that changes `reporting/`. After it succeeds, the existing site URL updates:

   ```text
   https://pwilliammat.github.io/flightTest/
   ```

## TechnicalSummaryFamily builder

`scripts/buildTechnicalSummaryFamily.m` packages and validates an already accepted nine-report family. It does not generate new report content.

Do not run it against `ManagerReport`: the builder creates staging, immutable-release, and promoted-release folders beside its input root. If a canonical release is needed, run it only in a dedicated writable release workspace that is separate from both the authoritative archive and this public reporting site. Use `scripts/verifyTechnicalSummaryFamily.m` to validate the resulting release.

## Quick rule

Create and review candidates elsewhere. Put only accepted source knowledge in `reporting/`. Push `main` only after the accepted repository view is complete; GitHub Pages then updates the browser site automatically.
