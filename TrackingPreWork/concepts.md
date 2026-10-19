# Localization-likelihood concepts

Scoped index for the study in `analysis/localizationLikelihood`. The parent FlightTest signal-processing index is preserved.

Start with [localizationWalkthrough.m](analysis/localizationLikelihood/localizationWalkthrough.m), the customer Live Script. Sections 1–3 establish the question and assumptions; 4–5 expose range and information calculations; 6–8 connect ideal geometry to modeled signal support; 9–10 test stability and explain how to adapt the study. Each concept below appears beside runnable code and its interpretation.

| Concept | Implementation and explanation |
|---|---|
| Guided calculation-to-conclusion workflow with inline figures | [localizationWalkthrough.m](analysis/localizationLikelihood/localizationWalkthrough.m), [full-scope computation](analysis/localizationLikelihood/helperLLWalkthroughStudy.m), [current-result tables](analysis/localizationLikelihood/helperLLWalkthroughView.m) |
| Selective inline plotting and isolated optional verification/export | [helperLLPlots.m](analysis/localizationLikelihood/helperLLPlots.m), [helperLLWalkthroughExport.m](analysis/localizationLikelihood/helperLLWalkthroughExport.m) |
| Reproducible candidate screening, ERP and full-channel filter compatibility | [helperLLScreen.m](analysis/localizationLikelihood/helperLLScreen.m), [repository survey](docs/localizationLikelihood/repositorySurvey.md) |
| Terrain MSL, AGL and geoid separation before receiver-centered ENU | [helperLLTerrain.m](analysis/localizationLikelihood/helperLLTerrain.m) |
| Excess bistatic range and local range-only information | [helperLLGeometry.m](analysis/localizationLikelihood/helperLLGeometry.m) |
| Cholesky whitening, SVD rank, covariance and unit-variance geometry metric | [helperLLGeometry.m](analysis/localizationLikelihood/helperLLGeometry.m) |
| Known local Up with full 3D slant ranges | [helperLLGeometry.m](analysis/localizationLikelihood/helperLLGeometry.m) |
| Explicit ERP/EIRP, gains, total noise temperature and equivalent-observation SNR | [helperLLRadarSNR.m](analysis/localizationLikelihood/helperLLRadarSNR.m) |
| Per-channel two-leg terrain propagation and signed excess-loss sensitivity | [helperLLRF.m](analysis/localizationLikelihood/helperLLRF.m), [helperLLRFDiagnostics.m](analysis/localizationLikelihood/helperLLRFDiagnostics.m) |
| Available-measurement subsets versus any-link coverage | [helperLLAnalyze.m](analysis/localizationLikelihood/helperLLAnalyze.m) |
| Geographic cell areas, conditional uncertainty quantiles and Tx3 attribution | [helperLLGrid.m](analysis/localizationLikelihood/helperLLGrid.m), [helperLLSummaries.m](analysis/localizationLikelihood/helperLLSummaries.m) |
| Range contours, uncertainty bands and categorical observability transitions | [helperLLPlots.m](analysis/localizationLikelihood/helperLLPlots.m) |
| Native CRLB and range-sum-to-TSOA verification | [helperLLNativeVerification.m](analysis/localizationLikelihood/helperLLNativeVerification.m), [tests](analysis/localizationLikelihood/tests/localizationLikelihoodTest.m) |

Executed evidence and limitations: [study report](docs/localizationLikelihood/report.md). No new IQ-processing stage, detection import, fuser or tracker was introduced.
