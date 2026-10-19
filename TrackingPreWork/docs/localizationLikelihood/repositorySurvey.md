# Localization-likelihood repository survey

Survey date: 2026-10-13. Scope: the maintained FlightTest repository and the approved localization-likelihood POC. Existing processing, reports, and link-budget artifacts were inspected read-only; the processing pipeline was not run.

This survey is established before implementation. The accepted plan refers to ten earlier survey questions and a prescribed narrative, but their verbatim wording was not supplied and was not found in the inspected repository text. The ten questions below reconstruct the requested technical coverage transparently; they do not claim to quote the missing prompt.

Status vocabulary: **sourced** = recorded external/catalog fact, not independently field verified; **local-analysis** = repository model or generated result; **inferred** = recovered or calculated from evidence; **assumed** = configurable POC choice; **conflicted** = inconsistent sources retained explicitly; **unresolved** = evidence insufficient; **verified** = actually executed focused check, with scope stated.

## 1. What already exists, and which sources govern?

The maintained `SystemPrechecks` functions and generated tables govern the RF baseline. Retained `.mlx` files and `reporting/reports/01A_IlluminatorSelection_V4.html` explain historical assumptions and design decisions. They are not current field measurements. `BistaticDataAnalysis/adsbToBistatic.m` supplies the excess-range convention, and `helperDeriveTxRxGeometry.m` supplies the receiver-centered WGS84 ENU convention. Neither pipeline needs to run for this study.

## 2. Which receiver and transmitter geometry is established?

| Input | Value carried into POC | Source location | Status / conflict |
|---|---|---|---|
| Apple Hill receiver | 42.299293, -71.349500 degrees; 25 m AGL | `SystemPrechecks/Artifacts/Tables/SystemPrecheckAssumptions.csv`; `helperBuildDeterministicCoverageData.m` | local-analysis; differs from collection coordinates |
| Newton baseline | 42.310280, -71.236670 degrees; 315.468 m AGL | Same table; helper converts 1035 ft | conflicted: coordinate agrees with catalog CBS Tower, while RF35 Newton catalog location differs |
| Newton catalog sensitivity | 42.311389, -71.216111 degrees; 315.468 m AGL | `SystemPrechecks/LinkBudget/Radio_Tower_List.txt`, `station_8_73238` | sourced; historical 01A report also uses this site |
| Hudson | 42.384083, -71.493139 degrees; 373.6848 m AGL | Maintained table; catalog Hudson blocks; helper converts 1226 ft | sourced/local-analysis |
| WLEK-LD primary Tx3 | 42.531583, -70.986222 degrees; 137.16 m AGL; horizontal ERP 15 kW | Catalog `station_8_182343`, 450 ft AGL | sourced catalog parameters; RF31/575 MHz corroborated on RabbitEars 2026-10-13 |
| Cochesett reference | 42.010556, -71.044444 degrees; 149.0472 m AGL | Catalog `station_8_23671` and `station_8_41436`, 489 ft AGL | sourced; geometry only |

The catalog labels positions NAD83. This small POC treats supplied horizontal coordinates as WGS84-compatible without a surveyed datum transformation; this approximation is subordinate to the explicit Newton location sensitivity. The historical ENU helper documents MSL inputs but passes them directly to `geodetic2enu`; this POC must correct heights locally using ellipsoidal height = terrain MSL + AGL + geoid separation.

Alternative receiver coordinates are real repository conflicts: `BistaticDataAnalysis/analyzeBistaticData.m` uses 42.2999333, -71.349333, 15 m labeled MSL; `TestSetupTesting/IQDataProcessing.m` and `BenchmarkEngine.m` use 42.3007, -71.3490. Those processing/collection-context coordinates are not substituted for the maintained Apple Hill precheck input. The analysis script also uses the CBS coordinate and 431.9 m labeled MSL for its transmitter.

## 3. Which airspace regions and altitudes are supported?

The recovered northern ROI is latitude 42.3082–42.5425 degrees and longitude -71.5908–-71.0049 degrees. Its bounds were recovered from saved live-script output. The west corridor is latitude 42.182143–42.416443 degrees and longitude -71.849500–-71.349500 degrees, with a visual-only westward boresight. Both appear in maintained assumptions and `helperBuildDeterministicCoverageData.m`. The maintained aircraft altitude is 6000 ft AGL; 3000/9000 ft AGL and a common 0.02-degree grid are POC sensitivities/assumptions. Three slices do not establish a volume.

## 4. What measurement is being localized?

For each transmitter, rho = norm(p - Tx) + norm(p - Rx) - norm(Tx - Rx), in meters. Its position Jacobian is the sum of the two unit vectors from the stations toward the aircraft. No factor of one half is used. Full 3D ranges remain in the known-altitude analysis; only the Jacobian's Up column is excluded. One scalar range cannot localize a point; two ranges cannot provide unconstrained 3D observability. Local full rank also does not prove global uniqueness of ellipsoid intersections.

## 5. What RF baseline exists and what needs correction?

The maintained model uses `txsite`, `rxsite`, `propagationModel("longley-rice")`, `pathloss`, and `radareqsnr`. For each leg it subtracts free-space path loss from Longley–Rice loss and adds the two excess losses. Maintained Newton/Hudson centers are 599/551 MHz, horizontal ERP 1000/400 kW, RCS 0.5 m², receiver height 25 m AGL, effective NF 2.5 dB, 6 MHz bandwidth, and equivalent interval 1/200 kHz = 5 microseconds. Receive gain 12 dBi is an assumed RF-budget value.

Local corrections: convert ERP to EIRP (+2.15 dB); set transmit/receive gains explicitly; set system noise temperature explicitly; use ENU slant distances; set the reverse target transmitter frequency to the corresponding broadcast; do not add another integration gain. The historical helper omits `Gain` and `Ts`, thereby inheriting `radareqsnr` defaults, and leaves reverse target `txsite` frequency at its default. Its power conversion uses k*(F-1)*290*B, which represents receiver-added noise rather than total input-referred thermal noise. Historical dBm summaries therefore remain labeled model references.

## 6. How is the third transmitter screened?

The approved screen deduplicates catalog locations, retains sites within 60 km of Apple Hill, requires less than 3 dB included bandpass insertion loss across a full channel, and maximizes minimum bearing separation from maintained Newton and Hudson. The radius and cutoff are assumptions. The supplied plan selects WLEK-LD RF31; Cochesett RF10 is geometry only. The native source is `SystemPrechecks/RFBudget/ZABP-587-S+_Plus25degC.s2p`; `helperGetBandpassInsertionLoss.m` reads it with `sparameters` and linearly interpolates complex S21. Included filter loss is approximately 0.77 dB at 575 MHz and 56.8 dB at 195 MHz. This says nothing conclusive about the optional high-pass filter or installed chain.

Executed screen on 2026-10-13: parsed 29 catalog records, deduplicated to 13 exact coordinate pairs, and retained 10 locations within 60 km using native WGS84 `distance` and `azimuth`. South Mountain (78.54 km), Saddleback Mountain (98.07 km), and Fort Mountain (98.36 km) fail the radius rule. The [RabbitEars facility/market listing](https://www.rabbitears.info/market.php?request=station_search&callsign=182343) and [printable market listing](https://www.rabbitears.info/market.php?request=print_market&mktid=8), retrieved 2026-10-13, provide channel-to-facility mapping absent from the catalog text itself. The frozen catalog supplies positions, not an assertion that every current channel still uses that position.

| Deduplicated catalog location | Example facility/channel at that location | Distance km | Bearing degrees | Minimum separation degrees | Screen interpretation |
|---|---|---:|---:|---:|---|
| WLEK site | 182343 / RF31 | 39.495 | 49.085 | 33.403 | Selected among UHF-compatible sites |
| WCRN site | 9154 / RF30 | 25.527 | 103.06 | 20.570 | Compatible, smaller angular separation |
| WWOO site | 186685 / RF28 listing | 24.688 | 74.424 | 8.065 | Smaller separation; listing also flags move to RF8 and 5G, unresolved suitability |
| John Hancock Tower | 168497 / WCEA RF36; co-sited WHDT RF4 | 23.317 | 76.163 | 6.325 | UHF path compatible; listing flags RF36-to-18 transition |
| Cabot Street | 6463 / WFXT RF34; co-sited VHF services | 10.849 | 87.797 | 5.309 | UHF path compatible |
| FM128 Tower | 55114 / W26EU RF26 | 10.425 | 84.805 | 2.316 | Compatible, smaller angular separation |
| Catalog Newton | 72145 and 73238 / shared RF35 | 11.080 | 82.990 | 0.502 | Same broadcast as baseline; sensitivity, not an independent Tx3 |
| CBS Tower | 25456 / RF20 and other UHF channels | 9.383 | 82.490 | 0.002 | Maintained Newton location; little bearing diversity |
| Hudson | 60551 / RF27 and other UHF channels | 15.127 | 308.557 | 0.000 | Existing baseline location |
| Cochesett | 23671 / WWDP RF10 | 40.796 | 141.726 | 59.237 | Rejected by filter screen; geometry-only reference |

Full-channel interpolation over included S2P frequencies and channel endpoints gives all RF14–36 channels less than 1.598 dB worst loss. RF31 is 0.76995 dB at center and approximately 0.77537 dB worst across 572–578 MHz. RF10 center 195 MHz is 56.822 dB. Retaining a location when it has at least one compatible UHF service leaves nine geographically distinct compatible locations including baseline/sensitivity locations. Removing those existing/redundant choices does not change WLEK's winning separation. Future channel moves and waveform/receiver suitability are not resolved by a component-frequency screen.

## 7. What do historical reports establish?

Report 01A preserves Newton/Hudson historical centers of 596.3/548 MHz and explicitly identifies equal 500 kW ERP as placeholders. Its historical regional comparison favors Hudson: mean modeled FOV SNR 69.91 dB versus 57.78 dB; target power -67.3723 versus -79.5023 dBm. Those figures are not the maintained RF baseline. It separately records Apple Hill East Garage as a practical prototype decision and the Newton/Needham direction as clearer there. It does not establish field-qualified transmitter selection, direct-path adequacy, aircraft detection, or localization.

Read-only extraction of `matlab/document.xml` from retained `SystemPrechecks/LinkBudget/FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` independently confirms the 500 kW entries, 596.3/548 MHz, 0.5 m² RCS, 5 microseconds, 2.5 dB NF, interactive ROI drawing, and TIREM-if-available/Longley–Rice-otherwise selection. No live script was executed. The current deterministic helper removes interactive ROI selection and uses explicit maintained ROIs. Its generated `BistaticTargetPathSummary.csv` reports 84 northern points on the older 0.04° grid, with mean modeled SNR 39.7199/36.6659 dB for Newton/Hudson. The west table reports 78 points and 34.2915/36.5433 dB. These are reproducibility references with inherited RF conventions, not calibration targets for the corrected POC.

## 8. Which native MATLAB functions fit?

| Proposed workflow | Native documentation analogue | Adaptation |
|---|---|---|
| Explain range ellipsoids | Bistatic-range and TDOA positioning examples | Use excess bistatic range, not conventional one-way TDOA |
| Present position uncertainty | Bistatic CRLB example | Range-only Jacobian; no angle measurements |
| Verify information | `crlb` | `crlb(sigFcn,R,p,DataComplexity="Real")` against analytic Jacobian |
| Verify synthetic localization | `tsoaposest` | Add Tx–Rx baseline to excess range, divide by c, convert variance by c² |
| Terrain and RF | `elevation`, `geoidheight`, `geodetic2enu`, `pathloss`, `radareqsnr` | Explicit vertical datum, per-channel legs, ERP/gain/noise conventions |
| Stable covariance | `chol`, `svd` | Whiten covariance; reject deficient rank; never label pseudoinverse as finite full-position confidence |

A compact custom analytic Jacobian and subset/area summaries are justified to expose the approved range-only model and attribution; existing tracker/fuser workflows would add unrequested measurements or state estimation.

Native examples read on 2026-10-13: [Tracking Using Bistatic Range Detections](https://www.mathworks.com/help/fusion/ug/track-using-bistatic-range-detections.html), [Object Tracking Using TDOA](https://www.mathworks.com/help/fusion/ug/object-tracking-using-time-difference-of-arrival.html), and [CRLB for Bistatic Position Estimation](https://www.mathworks.com/help/phased/ug/crlb-for-bistatic-position-estimation.html). The POC takes the first example's excess-range ellipsoids, the second's constant-measurement visualization idea, and the third's sqrt(trace(C)) maps and fixed color limits. It removes the CRLB example's angle row and does not execute example tracking workflows. Native syntax was verified against installed R2026a help and focused execution.

## 9. What uncertainty and combined coverage claims are permitted?

Independent 50 m range standard deviation (25/100 m sensitivities), 13 dB SNR gate, condition-number ceiling 10000, 500 m horizontal RMS with known Up, and 1000 m 3D total RMS are POC assumptions. The 13 dB gate has a repository detectability precedent, not a measured range-error calibration. Signal support selects rows, then information must be recomputed for that subset. Report any-link coverage, supported link count, ideal geometry, and useful localization separately; report valid counts beside median/95th-percentile uncertainty and area-weighted summaries separately for each ROI.

The threshold precedent is `SystemPrechecks/helperBuildDetectabilitySummary.m`, which evaluates `postProcessingSNR_dB > 13`. This POC deliberately labels its at-least-13-dB equivalent-observation availability gate as a new assumption, rather than claiming the old post-processing threshold validates range measurement availability.

## 10. What is verified, unresolved, and excluded?

The approved pre-implementation feasibility record states MATLAB R2026a availability, native `crlb` agreement around 9.3e-11 relative error, a noiseless `tsoaposest` recovery, and successful terrain/sample Longley–Rice access. These are method checks, not evidence that Tx3 helps. The implementation must rerun focused tests and full studies before claiming benefit. Unresolved items include installed antenna patterns, synchronization and independent error assumptions, RCS, reference-channel adequacy, effective receiver NF, installed filter response, and global position ambiguity. No detections, tracker, fuser, live acquisition, processing-pipeline run, or hardware qualification is in scope. Terrain failure must produce a distinctly labeled flat-terrain/free-space run.
