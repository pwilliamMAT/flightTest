# Stage 1 Literature Review Results

Date: 2026-08-13

This memo consolidates the Stage 1 neural filtering, aviation trajectory, repo/dataset, and MATLAB baseline reviews for the gated ADS-B neural Kalman research plan. Stage 1 remains a research gate only: no data collection, training, or implementation is started here.

## Executive Recommendation

Do not piggyback wholesale on an existing repository for Stage 2. No reviewed repo combines direct ADS-B data, online Kalman-style filtering, calibrated covariance, clean licensing, and a MATLAB-ready implementation path.

Recommended Stage 2 direction:

1. Build the MATLAB-native baseline first: per-aircraft local ENU filtering with `trackingKF` and `trackingIMM`, preserving state covariance at every prediction and correction step.
2. Use OpenSky historical/API data and local ADS-B data as the primary real-data path, subject to access and redistribution term review.
3. Train the first neural model as a compact GRU/LSTM residual or adaptive process-noise/covariance-inflation learner, not a full replacement trajectory predictor.
4. Use DANSE and KalmanNet as architectural references only. DANSE is the strongest licensed neural-state-estimation reference; KalmanNet is the strongest learned-gain reference but lacks a clear covariance-calibration path and has no GitHub-detected license.
5. Carry covariance calibration, irregular sampling, train/test leakage, altitude semantics, and maneuver-heavy distribution shift as explicit Stage 2 risks.

## Verification Status

- GitHub metadata for key repos was live-checked on 2026-08-13 where noted: public status, license detected by GitHub API, last push date, root files, and dependency files.
- MATLAB local availability was reported by the MATLAB baseline reviewer for R2026a: Sensor Fusion and Tracking Toolbox, Radar Toolbox, Phased Array System Toolbox, Deep Learning Toolbox, Mapping Toolbox, and Aerospace Toolbox were available. `transformerEncoderLayer` did not resolve locally; `selfAttentionLayer`, `positionEmbeddingLayer`, `trainnet`, and `dlnetwork` did.
- Paper links, MathWorks documentation links, and several dataset terms were not all live-verified. The memo marks access or license assumptions where they still require confirmation.

## Scoring Scheme

| Field | Values |
| :--- | :--- |
| Relevance | Very high, High, Medium, Low |
| Evidence grade | Direct ADS-B evidence, Aircraft trajectory but not ADS-B, Generic tracking transferable, Background only |
| Reproducibility | Directly runnable, Repairable, Concept only, Not usable |
| MATLAB burden | Low, Medium, High |
| Reuse assessment | Directly reusable, Repairable, Concept only, Not usable, Background |

## Native MATLAB Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Single-aircraft ADS-B online filtering baseline | `trackingKF`, `trackingEKF`, `trackingUKF`, `trackingCKF` examples | Convert ADS-B geodetic measurements to local ENU; support irregular timestamps; keep per-aircraft covariance |
| Maneuver-aware aircraft baseline | `trackingIMM` with multiple motion models | Configure CV, CA, and CT-style modes for climb, cruise, turn, and descent segments |
| Multi-aircraft tracking and association baseline | `trackerGNN`, `trackerJPDA`, `trackerTOMHT` | Defer unless ADS-B identity is degraded or passive-radar fusion introduces association ambiguity |
| Track metric reporting | `trackErrorMetrics`, `trackOSPAMetric`, `trackCLEARMetrics`, `trackAssignmentMetrics` | Add ADS-B-specific horizon errors and covariance calibration metrics such as NIS or Gaussian NLL |
| Geographic and local visualization | `trackingGlobeViewer`, `theaterPlot`, `geoplot`, `geoscatter` | Plot geodetic tracks plus ENU residuals, covariance bounds, gap duration, and maneuver diagnostics |
| Sequence learning baseline | `gruLayer`, `lstmLayer`, `trainnet` | Start with residual or process-noise targets; avoid full trajectory replacement as the first neural model |
| Differentiable learned filter training | `dlnetwork`, `dlarray`, `dlfeval`, `dlgradient` | Use only when Stage 3 requires training through Kalman recursion, Cholesky covariance output, NLL, or NIS losses |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Constant-velocity Kalman baseline | `trackingKF` | `filter = trackingKF("MotionModel","3D Constant Velocity")` |
| Nonlinear coordinate-aware filtering | `trackingEKF`, `trackingUKF`, `trackingCKF` | `predict(filter,dt)` and `correct(filter,measurement)` |
| Maneuver model switching | `trackingIMM` | `filter = trackingIMM(filters,modelProbabilities,transitionProbabilities)` |
| Multi-target association | `trackerGNN`, `trackerJPDA`, `trackerTOMHT` | `tracks = tracker(detections,time)` |
| Tracking metrics | `trackErrorMetrics`, `trackOSPAMetric`, `trackCLEARMetrics`, `trackAssignmentMetrics` | `metric = trackErrorMetrics` |
| Time alignment | `timetable`, `retime`, `synchronize` | `TT = retime(TT,"regular",method,"TimeStep",dt)` |
| Geodetic-to-local conversion | `wgs84Ellipsoid`, `geodetic2enu`, `lla2enu`, `geodetic2ecef` | `[xEast,yNorth,zUp] = geodetic2enu(lat,lon,h,lat0,lon0,h0,spheroid)` |
| Sequence model | `gruLayer`, `lstmLayer`, `trainnet` | `net = trainnet(X,T,layers,loss,options)` |
| Custom learned covariance/filter recursion | `dlnetwork`, `dlarray`, custom training loop | `gradients = dlgradient(loss,net.Learnables)` |

## Consolidated Resource Matrix

### Neural Filtering And State Estimation

| Resource | Type, relevance, evidence | Data, horizon, split | Approach, state/filter role, category | Results and uncertainty | Reproducibility, MATLAB burden, reuse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [KalmanNet](https://arxiv.org/abs/2107.10043), [KalmanNet_TSP](https://github.com/KalmanNet/KalmanNet_TSP) | Paper and code; High; Generic tracking transferable | Synthetic linear CA/canonical and Lorenz systems; recursive filtering; configurable synthetic train/test splits | RNN learns Kalman gain from innovations and state evolution; neural filter component | Reports MSE gains over KF/EKF under model mismatch; covariance calibration is weak or absent | GitHub metadata live-verified: public Python, last push 2024-02-12, `requirements.txt`, no detected license. Repairable as concept; MATLAB burden Medium-High |
| [RTSNet](https://github.com/KalmanNet/RTSNet_TSP) | Paper/code family; Medium; Generic tracking transferable | Synthetic linear and Lorenz systems; full-sequence smoothing; synthetic splits | Neural Rauch-Tung-Striebel smoother gain; offline smoothing; neural filter component | Reports smoothing MSE improvements under model mismatch; not centered on online covariance | GitHub metadata live-verified: public Python, last push 2023-12-21 for RTSNet_TSP, no detected license. Concept only for this online ADS-B gate; MATLAB burden High |
| [DANSE](https://github.com/saikatchatt/danse-jrnl) | Paper/code; High; Generic tracking transferable | Synthetic nonlinear SSMs including linear, Lorenz, Chen, Lorenz-96; generation scripts and splits | RNN learns predictive prior mean/covariance, then performs Kalman-style update; uncertainty-calibrated learned estimator | Reports state-estimation MSE improvements over EKF/UKF/KalmanNet/DMM-style baselines; explicit covariance/prior distribution | GitHub metadata live-verified: MIT, public Python, last push 2024-03-26. Best licensed neural-state-estimation reference; MATLAB burden Medium |
| [Backprop Kalman Filter](https://arxiv.org/abs/1605.07148) | Paper; Medium; Generic tracking transferable | Generic tracking/control examples; sequence filtering; non-ADS-B | Differentiable Kalman filter layer with learned observation model; neural filter component | Optimizes state error and likelihood through KF equations; covariance-aware by design | Concept only; useful if Stage 3 trains through filter equations with `dlnetwork`; MATLAB burden Medium-High |
| [Recurrent Kalman Network](https://arxiv.org/abs/1905.07357), [rkn_share](https://github.com/ALRhub/rkn_share) | Paper/code; Medium; Generic tracking transferable | Robotics and simulated sequences; sequence prediction/filtering; split details not live-verified | Deep latent recurrent Kalman model with factorized covariance; uncertainty-calibrated learned estimator | Reports RMSE/NLL-style sequence improvements; latent covariance support | License and current runnability not live-verified. Repairable concept; physical ADS-B state adaptation is high burden |
| [Deep Kalman Filter](https://arxiv.org/abs/1511.05121) | Paper; Low-Medium; Background only | General sequence datasets; variational latent trajectories; not online aircraft tracking | Deep latent state-space model; neural predictor/probabilistic estimator | Probabilistic sequence likelihood/ELBO; uncertainty is latent and not a tracker covariance | Background only for Stage 2. Too indirect and high burden for first experiment |
| [Deep Markov Model / Structured Inference Network](https://arxiv.org/abs/1609.09869) | Paper; Low-Medium; Background only | General time series; not ADS-B | Variational nonlinear Markov model; neural predictor/probabilistic estimator | ELBO/likelihood metrics; latent uncertainty but not directly usable track covariance | Background only; high MATLAB burden |
| [Deep Variational Bayes Filter](https://arxiv.org/abs/1605.06432) | Paper; Low-Medium; Background only | Vision/control-style sequences; not ADS-B | Variational Bayes state-space learner; neural predictor/probabilistic estimator | Probabilistic latent uncertainty; not an online aircraft tracker | Background only; not first-stage reusable |
| Innovation-Based Adaptive Estimation | Classical literature; High; Generic tracking transferable | No training data; online innovation statistics | Adaptive Q/R/covariance tuning from innovation sequence; uncertainty calibration | Strong conceptual link to NIS, covariance consistency, and adaptive process noise | Direct concept for MATLAB `trackingKF`/`trackingIMM`; low MATLAB burden |

### Aviation Trajectory, Intent, And Performance

| Resource | Type, relevance, evidence | Data, horizon, split | Approach, state/filter role, category | Results and uncertainty | Reproducibility, MATLAB burden, reuse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [DeepTP: End-to-End Neural Flight Trajectory Prediction](https://scholar.google.com/scholar?q=DeepTP+flight+trajectory+prediction) | Paper; High; Aircraft trajectory but not necessarily ADS-B | Real operational tracks with weather/flight-context features; longer en-route horizons; split details require verification | LSTM/RNN trajectory predictor; neural predictor | Reports lower trajectory error than baseline predictors; uncertainty generally absent | Code/data/license not live-verified. Concept only; risk of proprietary/cleaned data and offline prediction mismatch |
| [Aircraft Trajectory Prediction With Predictive Analytics, Ayhan and Samet](https://scholar.google.com/scholar?q=Aircraft+trajectory+prediction+made+easy+with+predictive+analytics+Ayhan+Samet) | Paper; Medium-High; Aircraft trajectory but not ADS-B | Historical trajectories; medium/long horizons; split details require verification | Similarity/regression trajectory forecasting; neural or ML predictor depending variant | Useful evidence for history and route conditioning; uncertainty unclear | Concept only; data access and route leakage risks |
| [ADS-B LSTM/GRU/Attention trajectory prediction literature](https://scholar.google.com/scholar?q=ADS-B+aircraft+trajectory+prediction+LSTM+GRU+attention) | Paper family; High; Direct ADS-B evidence where individual studies use OpenSky/local ADS-B | Usually OpenSky or local ADS-B with thousands of flights/windows; horizons often seconds to 30 minutes; splits often random/window-based | LSTM, GRU, seq2seq, attention; cleaned future state prediction; neural predictor | Typically reports RMSE/MAE gains over kinematic baselines; uncertainty often absent | Useful feature/horizon context, but direct reuse is weak. Major risk: overlapping-window leakage and cleaned-track-only evaluation |
| [Flight Extraction and Phase Identification for Large ADS-B Datasets](https://scholar.google.com/scholar?q=Flight+Extraction+and+Phase+Identification+for+Large+ADS-B+Datasets) | Paper/tooling concept; High; Direct ADS-B evidence | Large real ADS-B trajectories; horizon N/A; split N/A | Flight segmentation and phase labeling; preprocessing and feature support | Supports climb/cruise/descent/ground segmentation; no prediction uncertainty | Concept reusable in MATLAB; ensure phase labels do not use future validation/test samples |
| [WTFTP model](https://github.com/MusDev7/wtftp-model) | Paper/code; High; Aircraft trajectory but not ADS-B-verified | Full data withheld; 500 example samples; 9 input steps plus 1 target; 6 features | Wavelet plus LSTM trajectory predictor; neural predictor | Aviation sequence-modeling reference; no Kalman update or covariance | GitHub metadata live-verified by reviewer: Apache-2.0, last push 2023-08-30, old Python/Torch stack. Repairable for examples only; not a Stage 2 base |
| Graph/multi-agent air traffic trajectory prediction literature | Paper family; Medium; Aircraft trajectory and sometimes ADS-B | Multi-aircraft traffic snapshots; horizons seconds-minutes; splits often weakly documented | GNN, Transformer, LSTM hybrids; interaction-aware predictor | Captures traffic-context effects; uncertainty usually absent | High MATLAB burden and higher data requirement. Defer unless local pilot data has dense interaction scenarios |
| [OpenAP aircraft performance model](https://github.com/junzis/openap) | Code/data; High; Background/performance-informed aviation evidence | Aircraft type/performance models; not trajectory truth | Performance prior for climb/descent/speed envelope features; background/tooling | Useful for plausibility checks and phase-conditioned features; no covariance | GitHub metadata live-verified: LGPL-3.0, active. Useful as reference or external helper; embedding code requires license care |
| [EUROCONTROL BADA](https://www.eurocontrol.int/model/bada) | Proprietary/controlled resource; Medium; Background/performance-informed | Curated aircraft performance model; not open training data | Physics/performance prior | High-authority constraints, but access likely restrictive | Exclude from public reproducibility unless the project already has access and redistribution rights |
| [BlueSky ATC simulator](https://github.com/TUDelft-CNS-ATM/bluesky) | Simulator/code; Medium; Simulated background | Synthetic air traffic scenarios; arbitrary horizons | Scenario generation and maneuver stress testing; background/tooling | Useful for stress tests, not real ADS-B validation | License not live-verified in this memo. Concept/supporting tool only due sim-to-real gap |

### Repos, Datasets, And Reproducibility

| Resource | Type, relevance, evidence | Data, horizon, split | Approach, state/filter role, category | Results and uncertainty | Reproducibility, MATLAB burden, reuse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [OpenSky Network](https://opensky-network.org), [OpenSky datasets](https://opensky-network.org/datasets/) | Dataset/API; Very high; Direct ADS-B/Mode S evidence | Real global ADS-B/Mode S state vectors; user-defined horizons; no official ML split | Data source for ADS-B training/evaluation | Enables real irregular sampling, gaps, traffic diversity; no native uncertainty labels | Sample bucket live-verified by reviewer; historical access/redistribution terms still need review. Best public data path; MATLAB burden Medium |
| OpenSky COVID-19 and published OpenSky flight datasets | Dataset family; High; Direct ADS-B evidence | Processed real trajectories/flight lists; may be coarser than raw state vectors | Data source and route/diversity study support | Useful for broad coverage; often not high-rate enough for update-level Kalman learning | Terms and exact versions not live-verified. Repairable for context; confirm Zenodo/license before use |
| WTFTP example dataset | Dataset/code sample; Medium; Aircraft trajectory but not ADS-B-verified | 500 public example windows; full dataset withheld | Smoke-test sequence format; trajectory prediction | Too small for model training; no uncertainty | Useful only as data-shape reference; not enough for Stage 2 training |
| [traffic](https://github.com/xoolive/traffic) | Code/tooling; High; Direct ADS-B/OpenSky support | Works with OpenSky and air-traffic trajectory workflows; no model data | Data wrangling, filtering, visualization, export; not a Kalman filter | Strong tooling, no prediction covariance | GitHub metadata live-verified: MIT, active, tests/lockfiles/devcontainer. Directly runnable as external helper; MATLAB should ingest exported tables |
| [pyModeS](https://github.com/junzis/pyModeS) | Code/tooling; Medium; Direct Mode S/ADS-B evidence | Raw Mode S/ADS-B decoder; no prediction data | Decoding/preprocessing | Not a predictor; no uncertainty | GitHub metadata live-verified: GPL-3.0, active. Use as external reference only because GPL embedding is high risk |
| [OurAirports](https://ourairports.com/data/) | Dataset; Medium; Background/context | Airports, runways, navaids; no trajectories | Airport/runway context features | Supports phase/terminal-context features; no uncertainty | Current terms not live-verified here; generally open CSVs. Useful after license confirmation |
| OpenFlights / route metadata | Dataset; Low-Medium; Background/context | Airports, airlines, routes; no ADS-B tracks | Route context only | Useful for route-level covariates; no uncertainty | Terms not live-verified; likely share-alike constraints. Optional context only |

### MATLAB Baseline And Metric Resources

| Resource | Type, relevance, evidence | Data, horizon, split | Approach, state/filter role, category | Results and uncertainty | Reproducibility, MATLAB burden, reuse |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `trackingKF` | Toolbox function; Very high; Generic tracking transferable | No training data; event-driven online filtering | CV/CA-style baseline state estimator; MATLAB-native baseline | Full state covariance; supports RMSE, NIS, Gaussian NLL add-ons | Directly reusable; low burden |
| `trackingEKF`, `trackingUKF`, `trackingCKF` | Toolbox functions; High; Generic tracking transferable | No training data; online nonlinear/custom measurement filtering | Nonlinear/custom state and measurement models; MATLAB-native baseline | Full state covariance; useful when geodetic or turn-rate nonlinearities are retained | Directly reusable; medium burden |
| `trackingIMM` | Toolbox function; Very high; Generic tracking transferable | No training data; online maneuver filtering | Multiple motion models with mode probabilities; MATLAB-native baseline | Mixture covariance and mode probabilities; strong maneuver baseline | Directly reusable; medium burden. Recommended first maneuver baseline |
| `trackerGNN`, `trackerJPDA`, `trackerTOMHT` | Toolbox functions; Medium; Generic tracking transferable | No training data; multi-target association | Track management and association | Track covariance and assignment metrics | Defer for ADS-B-only identity-preserving Stage 2; use later for passive-radar fusion |
| `trackErrorMetrics`, `trackOSPAMetric`, `trackCLEARMetrics`, `trackAssignmentMetrics` | Toolbox metrics; Very high; Generic tracking transferable | No training data; evaluation harness | Position, velocity, assignment, OSPA/CLEAR metrics | Metrics do not solve covariance calibration; add NIS/NLL explicitly | Directly reusable; low burden |
| `trackingGlobeViewer`, `theaterPlot`, `geoplot`, `geoscatter` | Toolbox/visualization; High; Background/tooling | No training data | Track and residual visualization | Visual confidence/covariance inspection possible | Directly reusable; low burden |
| `timetable`, `retime`, `synchronize` | MATLAB data handling; Very high; Background/tooling | ADS-B irregular timestamps and gaps | Time alignment and gap characterization | Supports missing masks and data QA metrics | Directly reusable; low burden |
| `wgs84Ellipsoid`, `geodetic2enu`, `lla2enu`, `geodetic2ecef` | Mapping/Aerospace tools; Very high; Background/tooling | ADS-B latitude, longitude, altitude | Convert geodetic observations to ENU/ECEF state units | Preserves meter units for covariance and residuals | Directly reusable; low burden |
| `gruLayer`, `lstmLayer`, `trainnet` | Deep Learning Toolbox; High; Generic sequence transferable | Stage 2/3 sequence windows; one-step and short rollout targets | First residual or adaptive-noise learner | MSE/Huber baseline; no covariance unless target includes it | Directly reusable; low-medium burden |
| `dlnetwork` custom loops | Deep Learning Toolbox; High later; Generic neural filtering transferable | Stage 3 custom loss and recursive filter training | Learned gain/noise/covariance or differentiable filter recursion | Supports NLL, NIS, rollout, Cholesky covariance losses | Use after baseline metric harness is stable; high burden |

## Candidate Repo Runnability Assessment

| Repo | License/access | Dependency and runnability status | Score | Decision |
| :--- | :--- | :--- | :--- | :--- |
| `KalmanNet/KalmanNet_TSP` | No GitHub-detected license; public | `requirements.txt` present; old Torch 1.10.1 stack; synthetic demos; last push 2024-02-12 | Repairable | Cite and inspect architecture, but do not reuse code unless license is clarified |
| `saikatchatt/danse-jrnl` | MIT; public | Scripts, configs, tests, synthetic data generation; old PyTorch-era dependencies; last push 2024-03-26 | Repairable | Best external neural-filter reference and safest licensed concept source |
| `KalmanNet/RTSNet_TSP` or `RTSNet_ICASSP22` | No GitHub-detected license; public | Python scripts for smoothing; synthetic systems; online ADS-B mismatch | Concept only | Do not use for Stage 2 online filtering; possible later offline smoother comparison |
| `MusDev7/wtftp-model` | Apache-2.0; public examples | Old Python 3.7/Torch 1.4/CUDA 10; full dataset withheld; example set only | Repairable for examples | Cite for aviation sequence modeling; not an implementation base |
| `xoolive/traffic` | MIT; public | Active, modern packaging, tests, lockfiles/devcontainer; data tooling only | Directly runnable | Optional external preprocessing reference/helper, with MATLAB as the primary analysis environment |
| `junzis/openap` | LGPL-3.0; public | Active, modern packaging; performance model, not trajectories | Directly runnable | Use as reference/external feature support; avoid embedding code without license review |
| `junzis/pyModeS` | GPL-3.0; public | Active decoder library; not prediction | Directly runnable | Reference only; GPL makes direct embedding risky |

## Dataset Access And License Notes

| Dataset/source | License/access status | Included fields and size notes | Stage 2 suitability |
| :--- | :--- | :--- | :--- |
| OpenSky Network historical database/API | Access and redistribution terms require explicit review; account/API limits likely apply | Real ADS-B/Mode S state vectors: time, ICAO24, lat/lon, altitude, velocity, heading, vertical rate, on-ground/source depending endpoint | Best candidate public ADS-B path if terms permit |
| OpenSky dataset samples | Sample bucket live-verified by reviewer; exact per-file terms need review | Public sample files; useful for format validation and quick prototype data ingest | Good for smoke tests, not sufficient alone |
| OpenSky published COVID-19 / research datasets | Not fully live-verified here; confirm Zenodo/version/license | Processed flights and trajectories; may not preserve update-level cadence | Useful for broad route/aircraft diversity, but may be too coarse for Kalman update learning |
| WTFTP example data | Public sample data in repo; full dataset withheld | 500 windows, 10 time steps, 6 attributes | Format reference only |
| OpenAP data | LGPL-3.0 code/data package; citation expected | Aircraft performance models and metadata | Useful for optional aircraft-type/performance features; not trajectory truth |
| OurAirports | Current terms not live-verified here; generally open CSVs | Airports, runways, navaids | Useful context feature source after license check |
| OpenFlights route data | Terms not live-verified; likely share-alike constraints | Airports, airlines, routes | Optional route context; not needed for first baseline |

## Exclusion Log

| Resource | Reason for exclusion or down-rank |
| :--- | :--- |
| Pure KalmanNet learned-gain implementation as the first model | Attractive neural-filter framing, but published form does not naturally output calibrated covariance and may be fragile under irregular ADS-B sampling and distribution shift |
| Deep Kalman Filter, Deep Markov Model, Deep Variational Bayes Filter | Probabilistic but too latent/general, evaluated mostly as sequence models rather than interpretable online aircraft state filters |
| RTSNet as Stage 2 primary model | Smoother is offline and does not match the first online filtering gate |
| Cleaned-track-only trajectory predictors | Often report good RMSE but do not evaluate online update timing, missing messages, or covariance |
| Large Transformer trajectory predictors | Higher data requirements; local MATLAB did not resolve `transformerEncoderLayer`; not justified before baseline and GRU/LSTM residual tests |
| Graph/multi-aircraft models | Need dense interaction data and stable neighbor context; not first priority for single-aircraft ADS-B filtering |
| WTFTP full training workflow | Full dataset is withheld; not reproducible enough for Stage 2 base |
| `HappyGithub-dev/Aircraft-Trajectory-Prediction` | Reviewer live-verified zero-byte or unusable project files and no license |
| `ericperret/DroneRX` | ADS-B/drone firmware, not aircraft trajectory ML; no detected license |
| `open-aviation/atmdata` GitHub repo as code | Useful portal pointer only; repo is website source, not runnable model/data |
| FlightAware, FlightRadar24, ADS-B Exchange bulk history, EUROCONTROL DDR/BADA | Potentially useful but unsuitable for public reproducibility unless access and redistribution rights are secured |

## Final Downselect

| Candidate | Why it matters | Blocking assumptions | MATLAB implementation path | Expected data needs | Recommended Stage 2 experiment |
| :--- | :--- | :--- | :--- | :--- | :--- |
| MATLAB `trackingKF` ENU baseline | Establishes a low-burden online filter with interpretable covariance | ADS-B positions can be treated as measurements with defensible measurement noise; altitude source is consistent | Convert LLA to local ENU; state `[x; vx; y; vy; z; vz]`; event-driven `predict(filter,dt)` and `correct(filter,z)` | At least several days of ADS-B tracks with gaps and maneuvers | Build metric harness and baseline error/covariance reports |
| MATLAB `trackingIMM` ENU maneuver baseline | Handles turns, acceleration, climb/descent better than a single CV filter | Motion models and transition probabilities can be tuned without overfitting | Combine CV, CA, and CT-style models; retain mode probabilities and mixture covariance | Same as KF, with enough turns/climbs/descents to compare phase-conditioned errors | Compare KF vs IMM by phase, maneuver class, gap duration, and horizon |
| GRU/LSTM residual or adaptive process-noise learner | Adds neural capacity while preserving MATLAB filter semantics | Enough leakage-safe windows exist; residuals are learnable beyond IMM; validation data covers maneuvers | Use `trainnet` for standard residual model; inputs include innovation history, `dt`, speed, vertical rate, turn-rate proxy, missing mask, optional phase | Pilot: tens of thousands of windows from hundreds of flights across multiple days; more for robust generalization | Train one-step residual or process-noise inflation model after baseline harness is stable |
| DANSE-style covariance/prior learner | Best match for learned uncertainty while retaining filtering structure | Synthetic-code concept transfers to ADS-B; MATLAB custom loop burden is acceptable | Use `dlnetwork` only after Stage 2 selects state representation and covariance target | Larger and more diverse than residual learner; needs calibration validation | Stage 3 candidate if GRU residual improves RMSE but covariance remains weak |
| KalmanNet learned-gain comparator | Strong known learned-Kalman reference | License must be clarified; covariance limitation must be acceptable for comparison only | Reimplement a minimal learned-gain network in MATLAB rather than importing unlicensed code | Same sequence windows as residual learner | Optional comparator, not first recommended implementation |
| OpenSky plus local ADS-B data path | Only practical public real ADS-B source found for reproducible pilot work | Access, terms, and redistribution are approved; enough local diversity exists | Ingest via exported CSV/tables; use `timetable`, `retime`, `synchronize`, ENU conversion | Multiple days, hundreds of flights, diverse aircraft, climbs, descents, turns, sparse updates | Stage 2 data acquisition and split manifest design |
| `traffic` and OpenAP as supporting references | Strong aviation preprocessing and performance context | Python helper use and licenses are acceptable; MATLAB remains primary | Use externally only if helpful, export tables to MATLAB; avoid embedding license-sensitive code | Optional metadata and preprocessing support | Reference for data QA, phase/context features, and plausibility checks |

## Recommended Stage 2 Pilot Data Requirements

Minimum pilot target before training any NN beyond a simple GRU/LSTM residual:

- Tens of thousands of valid training windows.
- Hundreds of flights across multiple days.
- Multiple aircraft classes or at least a documented aircraft-type distribution.
- Climb, cruise, descent, level-off, and terminal-turn segments.
- Explicit gap, duplicate, and irregular-`dt` distributions.
- Separate held-out aircraft, held-out days, and held-out geographic/route regions where feasible.

Split policy:

- Do not split random overlapping windows.
- Split by flight first, then stress-test by aircraft/ICAO, date block, route/airport/airspace, and weather/time period if weather is joined.
- Fit normalization, interpolation rules, clustering, and phase labels only on training data or with strictly causal logic.
- Track the source of altitude: barometric vs geometric altitude must not be mixed silently.

Recommended horizons:

- One-step filter update.
- Rolling 10 s, 30 s, 60 s, and 120 s prediction horizons.
- Defer full-flight ETA or route-intent prediction until the online filtering task is stable.

## Risks And Unknowns To Carry Into Stage 2

| Risk | Stage 2 handling |
| :--- | :--- |
| ADS-B is measurement-derived, not ground truth | Treat ADS-B as a truth proxy only; document measurement covariance assumptions and avoid overclaiming covariance calibration |
| Irregular cadence, gaps, duplicates, and latency | Preserve event-driven `dt`; log gap statistics; include missing-update masks in NN features |
| Altitude ambiguity | Separate barometric and geometric altitude fields where available; do not silently combine them |
| Train/test leakage | Use flight/aircraft/day/region split manifests; prohibit random overlapping-window splits |
| Maneuver distribution shift | Report metrics by phase, turn rate, vertical rate, and gap duration |
| Covariance can worsen even if RMSE improves | Report NIS or Gaussian NLL alongside RMSE and horizon errors |
| Existing neural-filter repos are mostly synthetic | Reuse concepts, not code, unless license and adaptation burden are resolved |
| Public datasets may not match local receiver geometry | Compare OpenSky-derived pilot results against local ADS-B collection once available |

## Gate Decision

Stage 1 meets the review gate: it covers more than 15 resources, including at least 5 neural/Kalman resources, 5 aviation trajectory resources, 3 aviation datasets/data sources, 3 code implementations, and 3 MATLAB/toolbox resources. It also assesses more than 3 repos for runnability and records dataset access/license risks.

The recommended gate output for Stage 2 is:

- MATLAB-native baseline path: local ENU `trackingKF` followed by `trackingIMM`.
- First NN model family: compact GRU/LSTM residual or adaptive process-noise/covariance-inflation learner.
- Candidate public dataset path: OpenSky historical/API data plus local ADS-B collection, with access terms reviewed.
- Fallback if no repo is reusable: implement the Stage 2 baseline and first NN in MATLAB from scratch, using DANSE/KalmanNet only as design references.
- Piggyback recommendation: do not piggyback wholesale on an existing repo.
