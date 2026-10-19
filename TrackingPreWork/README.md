# FlightTest localization-likelihood POC

This MATLAB study separates transmitter geometry, modeled echo support, and useful local position uncertainty. WLEK-LD RF31 is compared with the maintained Newton/Hudson baseline in two ROIs, with Cochesett as a geometry-only reference.

Start with the [customer walkthrough Live Script](analysis/localizationLikelihood/localizationWalkthrough.m). It guides technical customer engineers through the scenario, assumptions, worked range/Jacobian/SVD and RF calculations, measurement availability, and conditional conclusions in about 25 minutes. Eight executable figures accompany the explanation, with the northern ROI at 6,000 ft AGL as the main example.

From the parent `flightTest` repository root in MATLAB R2026a, open it in the Live Editor and choose **Run All**:

```matlab
open("TrackingPreWork/analysis/localizationLikelihood/localizationWalkthrough.m")
```

The walkthrough also supports starting from `TrackingPreWork` or `analysis/localizationLikelihood`. It recomputes the full study using compatible terrain/RF caches and writes only relevant caches by default. A cached clean-workspace run took about 33 seconds here (13 seconds for study computation); service/cache misses can take longer. It leaves inline figures open and preserves unrelated figures.

Run setup and scenario computation after changing configuration. Then run the sections in order. Map/table sections can be rerun without rebuilding the study; worked calculations depend on the preceding range/Jacobian sections. The optional final switch delegates verification and full export to the existing runner in a separate function workspace. That runner rereads the configuration file, so temporary walkthrough overrides are not exported.

The [executed report](docs/localizationLikelihood/report.md), [source survey](docs/localizationLikelihood/repositorySurvey.md), [assumptions](docs/localizationLikelihood/assumptions.md), and [current state](PROJECT_STATE.md) remain supporting references. The [concept index](concepts.md) maps the educational steps to code.

The original full-study command remains unchanged:

```matlab
run("TrackingPreWork/analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m")
```

The runner uses MATLAB, Phased Array System Toolbox, Radar Toolbox, Mapping Toolbox, Aerospace Toolbox, Antenna Toolbox and RF Toolbox. Terrain calculations require access to MATLAB's default elevation service, or compatible cached results. Service failure is reported and restarts the physical scenario as explicitly labeled flat terrain/free space. Programming/configuration errors remain errors.

Edit [localizationLikelihoodConfig.m](analysis/localizationLikelihood/localizationLikelihoodConfig.m) for modeling inputs. Configuration and source digests invalidate relevant terrain/RF caches. The default effective NF includes the modeled system reference plane; component filter loss is used for candidate screening and is not added again by default.

For a single inline plot, use the same drawing code as the report:

```matlab
helperLLPlots(result, Plots=4, AltitudesFtAGL=6000, ...
    ROI="Recovered north", Display="inline");
```

`help helperLLPlots` lists the 12 plot numbers. Its original one-argument call still exports all 12 figures. The walkthrough uses `helperLLWalkthroughStudy` for full computation, `helperLLWalkthroughView` for compact tables and current-result interpretation, and `helperLLWalkthroughExport` for isolated optional verification/export.

The runner writes 12 PNGs, 10 CSV tables, and a MAT study in [results](analysis/localizationLikelihood/results), then regenerates the ten-section report. The MAT file contains `study`, including configuration/provenance, baseline and catalog-Newton arrays, masks, uncertainty metrics and sensitivities. Cache data is reproducible and ignored by the scoped `.gitignore`. Existing FlightTest reports, pipeline code and captures are preserved.

Focused tests alone:

```matlab
runtests("TrackingPreWork/analysis/localizationLikelihood/tests")
```

The result is conditional on assumed measurement quality and RF support. It does not establish global position uniqueness, detected aircraft, tracking performance or qualified acquisition hardware.

A source/documentation Git checkpoint is now coherent. These commands are suggestions to review and run manually from the parent repository; the generated MAT (about 25 MB), PNG/CSV results and caches are excluded from this proposed staging list.

```powershell
git status --short TrackingPreWork
git add TrackingPreWork/README.md TrackingPreWork/PROJECT_STATE.md TrackingPreWork/concepts.md TrackingPreWork/sftt_skillUseSummary.md TrackingPreWork/docs/localizationLikelihood 'TrackingPreWork/analysis/localizationLikelihood/*.m' TrackingPreWork/analysis/localizationLikelihood/tests TrackingPreWork/analysis/localizationLikelihood/.gitignore
git diff --cached --stat
git diff --cached
git commit -m "Explain and verify Tx3 localization value in an executable customer walkthrough"
```
