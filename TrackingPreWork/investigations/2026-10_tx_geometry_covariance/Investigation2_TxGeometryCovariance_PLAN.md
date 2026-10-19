# Investigation 2: Tx-Site Geometry, TDOA Hyperbolas and Covariance-Orientation Robustness — Plan

TrackingPreWork Investigation 2. Written 2026-10-19. The method and predictions are fixed before any code runs. This file is self-contained for the implementing agent: start with **Implementer notes** at the end.

## Context

The first TrackingPreWork study answered one narrow question: does WLEK-LD add RF-supported useful area?
- Code: `TrackingPreWork/analysis/localizationLikelihood/`.
- Report: `TrackingPreWork/docs/localizationLikelihood/report.md`.
- Commit: 5e13ff6.

It reduced geometry to scalar RMS and area, so it does not show:
- **The geometry itself.** Where constant-measurement surfaces cross at shallow angles.
- **Each detection's covariance ellipsoid.** Its shape and orientation.
- **The project owner's main concern.** When a detection covariance ellipsoid is long and thin, a slight error in its assumed orientation produces a large error in the gated or fused 3D position. We want a Tx set that limits this error.

This is a **Tx-site selection investigation**, not a teaching exercise. It uses:
- the real Apple Hill Rx;
- the real Newton and Hudson Tx;
- the candidate UHF sites.

Question: which candidate Tx, or Tx pair, added to the baseline gives detection covariances that are small, near-spherical, and robust to orientation error?

It applies the tools of the MathWorks [Object Tracking Using TDOA](https://www.mathworks.com/help/fusion/ug/object-tracking-using-time-difference-of-arrival.html) example to our sites:
- TDOA hyperbola plots;
- a GDOP heatmap;
- Jacobian covariance, as in its `helperCalcPositionCovariance`.

The folder layout follows the `../PassiveBistaticAnalysis/investigations/` convention (see that folder's `README.md`).

## Folder Layout

```
TrackingPreWork/investigations/
  README.md      index table: Investigation 1 (pointer to analysis/localizationLikelihood, left in place) + this one
  2026-10_tx_geometry_covariance/
    README.md        question, status, results index, how to rerun, what it leaves open
    Investigation2_TxGeometryCovariance_PLAN.md   this file
    config.json      every parameter (sites, candidates, grid, altitudes, sigma, δθ ladder, MC counts, quick/full modes)
    run_tx_geometry_covariance.m      plain-text Live Script entry point (sections = report chapters)
    publish_tx_geometry_covariance.m  export(...,Run=true) → results/<ts>/TxGeometryCovariance.html
    code/            helpers only this investigation uses (prefix helperTGC*)
    tests/           txGeometryCovarianceTest.m (+ Regression-tagged quick-mode baseline comparison)
    results/<timestamp>[_label]/   CSVs, run_manifest.json, HTML committed; .mat and figures/ ignored
    .gitignore
```

## Configurations Evaluated

- **Rx:** Apple Hill, the maintained coordinates 42.299293, −71.349500, 25 m AGL.
- **Baseline Tx:** Newton and Hudson, as in `localizationLikelihoodConfig.m`.
- **Candidates:**
  - the eligible sites from Study 1's screen: WLEK, WCRN site, WWOO site, John Hancock, Cabot Street and FM128;
  - Cochesett, as a geometry-only reference.
- **Sets:**
  - baseline plus each single candidate;
  - baseline plus each candidate pair (21 pairs).
- **Newton coordinate sensitivity:** catalog Newton (42.311389, −71.216111) as an alternative baseline site.

## Measurement Models (Both Reported)

1. **Bistatic range-sum (absolute timing).**
   - ρ_i = ‖p−Tx_i‖ + ‖p−Rx‖ − L_i.
   - Surface normal: n_i = u_Ti + u_R, with |n_i| = 2cos(β_i/2).
   - Reuse `helperLLGeometry` unchanged.
2. **TDOA (reference timing unknown).**
   - Differencing two range-sums at the shared Rx cancels the Rx leg: ρ_i − ρ_j = ‖p−Tx_i‖ − ‖p−Tx_j‖ + const.
   - Each Tx pair therefore defines a true hyperboloid with foci Tx_i and Tx_j.
   - Jacobian rows are u_Ti − u_Tj. The difference noise covariance is D·R·Dᵀ, which is correlated.
   - This mode tolerates an unknown common sync bias. TDOA-only 3D needs ≥4 Tx, i.e. baseline plus 2 candidates. Report which sets reach it.

## Method

**A. Geometry pictures (the example's figures, using our sites).** For each set, at 6000 ft AGL (also 3000 and 9000 ft), produce:
- a map of TDOA hyperbola families, one colour per Tx pair (contours of ρ_i − ρ_j on the ROI grid, on a geographic basemap);
- the bistatic ellipses, side by side for comparison;
- the Rx–Tx and Tx–Tx baseline lines, which are the GDOP-blind directions.

Grid and terrain: reuse `helperLLGrid` and `helperLLTerrain`, with the site list extended by the candidates.

**B. GDOP and covariance heatmaps.**
- Per cell: P = (Hᵀ R⁻¹ H)⁻¹ through the existing whitened-SVD path. Native check against `crlb`.
- Derived quantities:
  - GDOP, HDOP and VDOP;
  - the eigendecomposition P = VΛVᵀ, with principal σ1 ≥ σ2 ≥ σ3;
  - the **aspect ratio** σ1/σ3;
  - long-axis azimuth and elevation.
- Heatmaps per set and per mode.
- A covariance-ellipsoid glyph overlay (3D, `ellipsoid` + `surf`) at sampled cells, to show orientation directly.

**C. Covariance-orientation robustness (the core question).**

*C1. Mis-specified orientation.*
- Rotate the assumed covariance: P̂ = R(δθ)·P·R(δθ)ᵀ, with δθ ∈ {0.5, 1, 2, 5}°, about each principal axis. Report the worst axis.
- **Inconsistency factor** κ = tr(P̂⁻¹P)/3, the expected NEES ratio.
- **Gate-miss probability** P(eᵀP̂⁻¹e > χ²₃(0.99)), by Monte Carlo with e ~ N(0,P).
- **Fused-position error inflation:**
  - Fuse the detection with an independent prior Q, such as a track prediction.
  - Weight it once with P̂ and once with P, and compare the analytic MSE.
  - This turns a slight orientation error into metres of 3D position error.
  - Use `objectDetection` / `trackingKF` conventions so the metric maps onto a later tracker.
- Analytic small-angle check: κ − 1 ≈ (δθ²/3)·Σ_{i<j}(λi/λj + λj/λi − 2).
  - The cost grows with the aspect ratio squared.
  - So **aspect ratio, not GDOP alone, is the site-selection metric**.

*C2. Physical sources of orientation error.*
- Measure the finite-difference rotation of P's principal axes under realistic perturbations:
  - Tx/Rx coordinate error (the NAD83/WGS84 approximation; the Newton catalog-vs-maintained difference);
  - target-altitude error;
  - linearization at an estimate displaced 1σ along the long axis;
  - per-Tx range bias.
- Report δθ in degrees and the resulting κ and position error from C1. Report the eigenvector sensitivity ∝ 1/(λi − λj) alongside.

*C3. Nonlinear truth check.*
- At about 12 representative cells (best, median and worst aspect ratio per leading set), run Monte Carlo with native `tsoaposest` (range-sum) and `tdoaposest` (TDOA).
- Compare the sample covariance with the linearized P:
  - principal-axis angle;
  - size ratio;
  - bias.
- Flag cells where the Gaussian ellipsoid is itself the wrong shape (banana or ghost solutions).

**D. Site ranking.** For each set, ROI (recovered north, west corridor) and altitude, compute:
- the area with GDOP·σ ≤ the limit;
- the median and P95 aspect ratio;
- the area where κ(1°) ≤ 1.5, the "orientation-robust area";
- the median fused-error inflation at δθ = 1°;
- whether TDOA-mode 3D is available.

Report each metric twice:
- geometry-only;
- RF-gated, with Study 1's `helperLLRF` SNR gate, where the candidate ERP is sourced.

Then produce a Pareto plot (robust area against supported area) and a decision table that names the recommended Tx set or sets.

## Predictions (Fixed Before Running)

| ID | Prediction | Pass |
|---|---|---|
| T1 | Range-sum P from `helperLLGeometry` matches native `crlb` | Relative error ≤ 1e-6 at the test cells |
| T2 | TDOA-mode P equals range-sum P with the common bias marginalized | ≤ 1e-6 relative |
| T3 | The small-angle κ formula matches the exact tr(P̂⁻¹P)/3 | ≤ 2% at δθ ≤ 2° |
| T4 | Linearized P agrees with MC (`tsoaposest`) where the aspect ratio is < 10 | Axis angle ≤ 5°, size ratio within ±15% |
| T5 | Newton+Hudson alone is 3D rank-deficient everywhere (reproduces Study 1) | 0 full-rank cells |
| E1 (expectation) | Candidates bearing far from both baselines (WLEK, Cochesett) minimize the aspect ratio in the north ROI | Recorded, not pass/fail |
| E2 (expectation) | The orientation-robust area is much smaller than the GDOP-useful area for every 3-Tx set | Recorded |

A failed check means "investigate the instrument first". No parameter is tuned to make a check pass.

## Outputs (`results/<ts>/`)

**Tables:**
- `site_table.csv`: the frozen candidates, with provenance;
- `set_metrics.csv`;
- `cell_covariance_summary.csv`;
- `orientation_robustness.csv`;
- `physical_perturbations.csv`;
- `mc_check.csv`;
- `predictions_verdict.csv`;
- `site_ranking.csv`.

**Manifest:** `run_manifest.json` holds:
- the git commit and a dirty-tree flag;
- the MATLAB release and toolboxes;
- the config;
- SHA-256 hashes of the inputs.

**Report:** `TxGeometryCovariance.html`, a self-contained report exported from the Live Script. Its figures are:
- hyperbola and ellipse maps;
- GDOP and aspect-ratio heatmaps;
- ellipsoid glyphs;
- κ-against-δθ curves;
- physical-perturbation bars;
- MC scatter against the linearized ellipse;
- the Pareto chart and the ranking table.

## Reuse (Called, Not Copied or Edited)

- **Study 1 helpers** in `TrackingPreWork/analysis/localizationLikelihood/`:
  - `helperLLGeometry`: H, whitened SVD, covariance;
  - `helperLLGrid`;
  - `helperLLTerrain`: datum-correct ENU; called with an extended `cfg.sites`;
  - `helperLLRF` and `helperLLRadarSNR`: the RF gate;
  - `helperLLCache`, `helperLLCacheFile` and `helperLLSourceStamp`;
  - `helperLLNativeVerification`: its `crlb` / `tsoaposest` patterns.
- **Native tools:**
  - Phased Array System Toolbox: `tdoaposest`, `tsoaposest`, `crlb`, all in R2026a under `toolbox/phased/phased/`;
  - Sensor Fusion and Tracking Toolbox: `objectDetection` and `trackingKF`. It is installed.
- **Patterns from `../PassiveBistaticAnalysis/`:**
  - `investigations/2026-10_real_aircraft_budget/publish_real_aircraft_budget.m`: the export plus `.last_run` pattern;
  - `config.json` with quick/full modes;
  - `helperWriteRunManifest.m`, at that repo's root. Port an equivalent into `code/`; do not reference it across repos.

## Boundaries

- Study 1's code, results and report are not modified. It gets an index row in `investigations/README.md` only.
- No IQ processing, detection import or tracker run on real data. The `trackingKF` fusion is an analytic, per-cell metric.
- RF-gated conclusions stay conditional on Study 1's RF assumptions.

## Verification

1. Run `runtests("TrackingPreWork/investigations/2026-10_tx_geometry_covariance/tests")`. It covers:
   - unit checks T1–T3;
   - the hyperboloid focus property;
   - κ = 1 at δθ = 0;
   - rotation symmetry;
   - quick-mode regression against the baseline.
2. Run `publish_tx_geometry_covariance(Quick=true)`, then the full run. Confirm the HTML renders every figure and that `predictions_verdict.csv` lists T1–T5.
3. Inspect the hyperbola maps visually against the example's figures. Check that GDOP is worst along the Rx–Tx baselines.
4. Code Analyzer must be clean on all new files. Update `TrackingPreWork/concepts.md` and the investigations README index.

## Implementer Notes

**Repository and branch.**
- Repository: `flightTest`, on branch `feature/wlek-localization-study`.
- Use MATLAB R2026a (`C:\Program Files\MATLAB\R2026a`).

**Project rules** (from `AGENTS.md`; mandatory). For each processing step:
1. Explain the concept in plain language: a Live Script text section.
2. Prefer Phased Array System Toolbox, Radar Toolbox and Signal Processing Toolbox functions (plus Sensor Fusion and Tracking Toolbox here) over custom code.
3. Comment the code heavily: what each step does, and why.
4. Add a visualization of each step.
5. Add a row to `TrackingPreWork/concepts.md` that maps the concept to its file.
6. Verify that each step runs before moving to the next.

**Step 0 is a blocker. Resolve it before writing analysis code.**
- Study 1's candidate source, `SystemPrechecks/LinkBudget/Radio_Tower_List.txt`, is **not present in this checkout**. Without it, `helperLLScreen` cannot run.
- Look for it in `../DataCollect`, `../PassiveBistaticAnalysis` and git history. Otherwise rebuild the entries from the FCC/RabbitEars facility IDs frozen in `localizationLikelihoodConfig.m` (`cfg.screen.facility`).
- Freeze lat/lon, AGL height, RF channel and ERP for every candidate in `config.json`, with provenance.
- A candidate without a sourced height or ERP is marked geometry-only. Never guess the values.
- If the coordinates cannot be sourced, stop and ask the project owner.

**Known coupling.** `helperLLTerrain` and `helperLLAnalyze` assume `cfg.sites` holds 4 entries, with RF on the first 3.
- Build an extended cfg copy inside `code/` (e.g. `helperTGCBuildCfg`) rather than editing Study 1.
- If a Study 1 helper truly needs a change, stop and ask.

**MATLAB MCP.** The server was disconnected during planning. Reconnect it, or have the owner run the steps manually.

**Suggested build order:**
1. Step 0.
2. Folder skeleton, `config.json`, `.gitignore`, investigations `README.md`.
3. Covariance and eigen metrics, with the T1/T2 tests.
4. Hyperbola and GDOP maps (A, B).
5. C1, with the T3 test.
6. C2.
7. C3, with the T4 test.
8. Ranking (D), with the T5 check.
9. Live Script assembly and the publish script.
10. Quick-mode baseline and the regression test.
11. Full run, README results index, `concepts.md` update.

**Git.** Commit only when asked. End commit messages with the attribution line the session requires.
