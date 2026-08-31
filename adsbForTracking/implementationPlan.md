# Gated ADS-B Neural Kalman Research Plan

## Progress Navigator

- (completed) Stage 1: Literature and resource review. Read `stage1LiteratureReviewResults.md` and the Stage 1 outcome section for the owner-approved direction.
- (completed) Stage 2A: OpenSky go/no-go probe. Read `stage2OpenSkyGoNoGoReport.md` and the Stage 2A outcome section for why local ADS-B became the primary data path.
- (completed) Stage 2B: Local ADS-B smoke pipeline. Read the Stage 2B outcome section and `artifacts/stage2B/stage2BLocalADSBSmokeSummary.md` for completed dataset, baseline, and MLP smoke-training status.
- (completed) Stage 2C: Maneuver-aware characterization with existing data. Read the Stage 2C outcome section and `artifacts/stage2C/stage2CManeuverCharacterizationReport.md` before Stage 3 work.
- (completed) Stage 3A: Delta-target MLP training implementation. The saved artifact trains state deltas with MATLAB `trainnet`, keeps `constvel` as the comparator, and reports split and maneuver diagnostics without broad maneuver-learning claims.
- (completed) Stage 3B: Aggregate ADS-B evaluation gate. Aggregate currently discoverable local ADS-B truth, compare frozen Stage 3A MLP against `constvel` on identical samples, and gate whether future retraining is justified.
- (completed) Stage 3C: Archived ADS-B evaluation extension. Inventory and score `adsb_archive/adsb_archive` without retraining, using MATLAB `gunzip` first and a narrow .NET fallback for native gzip failures.
- (completed) Stage 4A: ADS-B truth capture-planning checkpoint. Now prefers the saved Stage 3C artifact, keeps Stage 3B fallback compatibility, and turns archive caveats into targeted ADS-B collection priorities before any retraining.
- (completed) Stage 4B: Testing-machine ADS-B interval capture coordinator. Run from the Ubuntu testing machine; it SSHes to the Pi for bounded ADS-B-only windows, fetches gzip truth logs, and packages local `captures/<session_id>/` sessions with receiver-origin manifests.
- (completed) Stage 4B-Post: Versioned dataset integration and motion-diversity gate. The prior 16-session evaluation is preserved as `Legacy-16`, the new campaign is independently rerunnable as the `3-Day Campaign Increment`, and their union is `Expanded-3Day`. The expanded data pass the local gated-retraining criteria but do not support broad-generalization claims.
- (completed) Stage 4C-Retrain: Expanded-3Day exploratory mean-MLP training. The scratch and normalization-rebased warm-start controls were trained on the frozen global ICAO-disjoint split, evaluated on untouched holdouts, and retained as exploratory artifacts without model promotion.
- (completed) Stage 4C-Native: Evaluation-only native maneuver-baseline extension. Raw causal finite differences initialize native `constacc` and `constturn` on matched eligible maneuver slices without retraining or model promotion.
- (completed) Stage 4C-Review: Unified review dashboard. `stageReviewLiveScript.m` is the Run All entry point for frozen split/motion counts, a test-only native-versus-neural RMSE dashboard, a separate neural validation-versus-test dashboard, and three configurable class-specific `trackingGlobeViewer` trajectory collections.
- (completed) Stage 4D: Standalone frozen-warm characterization. `stage4DFrozenWarmCharacterizationLiveScript.m` audits the unchanged warm artifact, runs deterministic synthetic and held-out ADS-B dropout benchmarks, and keeps same-information warm-versus-`constvel` conclusions separate from predecessor-assisted `constacc`/`constturn` results.
- (completed) Stage 4E: Recursive filter evaluation. Validation-only `trackingFilterTuner` parameters are frozen before matched recursive CV/CA/CT EKF, native IMM, and frozen-warm UKF testing on synthetic truth and held-out ADS-B scoring proxies.

## Summary

- Treat this as a four-stage gated effort.
- Stage 1 is the completed literature, web, GitHub, and dataset review used to identify prior neural/Kalman/state-update approaches worth reusing.
- Stage 2 began with a 2-hour OpenSky go/no-go probe. That probe passed technically, but owner review changed the primary data path to local ADS-B collection from the Raspberry Pi/RTL-SDR/dump1090 pipeline because anonymous OpenSky current-state sampling would duplicate the local acquisition pipeline.
- Stage 2B completed the local ADS-B smoke pipeline: dataset artifact, source and split manifests, `constvel` baseline metrics, and a minimal finite-loss MLP training interface on the verified local truth file.
- Stage 2C characterized maneuver content from the existing Stage 2B artifact and found insufficient maneuver diversity for broad model-quality claims. `constvel` remains the baseline floor, not the learned-model target.
- Stage 3A completed the delta-target MLP training artifact and confirmed that `constvel` remains the meaningful floor on the current data.
- Stage 3B completed the aggregate evaluation gate: freeze Stage 3A, aggregate all currently discoverable local ADS-B truth, compare against `constvel` on identical rows, and report whether there is enough data diversity for later retraining.
- Stage 3C completed the archive evaluation extension: the frozen Stage 3A model and `constvel` were scored on 16 archived truth files, 16 usable sessions, 15,013 one-step pairs, and 222 aircraft tracks; no retraining was run.
- Stage 4A completed the ADS-B truth capture-planning checkpoint and has been updated after Stage 3C: no retraining, only plots that show basic gates now pass while Pi-only holdout data, receiver-origin metadata, source diversity, targeted motion/update coverage, and passive-radar-relevant geometry remain collection priorities.
- Stage 4B adds the testing-machine ADS-B interval capture coordinator under `adsbForTracking/piCaptureCampaign/`; it schedules ADS-B-only truth captures by SSHing to the Pi, then fetches and packages ADS-B-only holdout sessions with `session_manifest.json` receiver-origin metadata for Stage 3C/4A review.
- Stage 4B-Post integrated the completed three-day campaign without erasing the smaller Stage 3C baseline. The named legacy, incremental, and expanded variants use the same parser, state-pair rules, maneuver thresholds, frozen Stage 3A MLP, and native `constvel` baseline. Expanded-3Day passes the event-, contributor-, campaign-day-, joint-regime-, and split-level local retraining gate, while broad generalization remains unsupported.
- Stage 4E completed the recursive diagnostic that Stage 4D deferred. It does not promote the learned model: the native CV/CA/CT IMM is the strongest tested recursive estimator, while the frozen-warm UKF is less accurate and substantially slower on both independent synthetic truth and held-out ADS-B scoring proxies.

## (completed) Stage 1: Literature And Resource Review

Deliverable: a concise resource matrix, preferably as a Markdown memo, listing relevant papers, GitHub repos, datasets, and toolbox examples. The memo must end with a downselect recommendation that is specific enough to gate Stage 2.

For each resource, capture:

- Resource name, link, source type, relevance rating, and evidence grade: direct ADS-B evidence, aircraft trajectory but not ADS-B, generic tracking transferable, or background only.
- Training data type, approximate size, real vs simulated status, prediction horizon, train/test split strategy, and data diversity notes.
- NN or ML approach used.
- State/filter role: full state transition, Kalman gain, residual dynamics, process noise, measurement update, covariance calibration, trajectory prediction, tracking association, or uncertainty calibration.
- Approach category: neural predictor, neural filter component, or uncertainty-calibrated learned estimator.
- Major results in 2-3 lines, including reported metrics where available.
- Uncertainty support: covariance output, NLL/calibration metric, ensemble/quantile output, or no uncertainty.
- Code and dataset reproducibility status: license/access, runnability, dependency burden, provided splits/seeds/weights, and MATLAB integration burden.
- Reuse assessment: directly reusable, repairable, concept only, not usable, or background.

Search scope:

- Neural Kalman filtering and learned state estimation: `KalmanNet`, `KalmanNetNN`, `RTSNet`, `DANSE`, `Deep Kalman Filter`, `Deep Variational Bayes Filter`, `Recurrent Kalman Network`, `Differentiable Kalman Filter`, `Neural State Space Model`, `Deep Markov Model`, learned Kalman gain, learned process noise, learned measurement noise, covariance calibration, innovation-based adaptive estimation, neural IMM, and maneuver-aware filtering.
- Aircraft/ADS-B trajectory prediction: LSTM, GRU, TCN, Transformer, graph models, maneuver prediction, intent-aware models, 4D trajectory prediction, ETA prediction, climb/cruise/descent prediction, terminal-area and en-route trajectory prediction, trajectory uncertainty prediction, flight phase recognition, Mode S, OpenSky Network, ASTERIX, Eurocontrol DDR, FAA SWIM, and NAS trajectory prediction.
- Open implementations and datasets on GitHub, Papers with Code, arXiv, IEEE/MDPI/Sensors/Aerospace venues, OpenSky resources, Mode S datasets, terminal-area ADS-B datasets, weather-joined trajectory datasets, BADA/OpenAP resources, and route/waypoint/navigation datasets.
- MATLAB-native baselines and examples: `trackingKF`, `trackingEKF`, `trackingUKF`, `trackingIMM`, `trackerGNN`, `trackerJPDA`, `trackerTOMHT`, `trackOSPAMetric`, `trackCLEARMetric`, `trackErrorMetrics`, `lstmLayer`, `gruLayer`, `transformerEncoderLayer`, and `trainnet`.
- Sensor Fusion and Tracking Toolbox motion/measurement model functions: `constvel`, `constveljac`, `cvmeas`, `cvmeasjac`, plus `constacc`, `constaccjac`, `cameas`, `cameasjac`, `constturn`, `constturnjac`, `ctmeas`, and `ctmeasjac` as future maneuver-model references.

Gate to complete Stage 1:

- Review at least 15 relevant resources with a balanced minimum, where available: 5 neural/Kalman resources, 5 aviation trajectory prediction resources, 3 aviation datasets or data sources, 3 code implementations, and 3 MATLAB/toolbox resources.
- Assess at least 3 candidate repos for actual runnability, not just relevance, and confirm license/access status for at least 2 candidate datasets.
- Include a short exclusion log for tempting but unsuitable resources, with reasons such as no uncertainty output, no code, proprietary data, unrealistic sampling, toy-only evaluation, or no aircraft maneuver relevance.
- Provide a final downselect table with candidate, why it matters, blocking assumptions, MATLAB implementation path, expected data needs, and recommended Stage 2 experiment.
- Recommend one MATLAB-native baseline path, one first NN model family, one candidate public dataset path, and one fallback if no existing repo is reusable.
- Provide a clear recommendation on whether to piggyback on an existing approach.
- Provide a clear recommendation on data volume/diversity needed for a pilot ADS-B collection.
- Carry explicit risks and unknowns into Stage 2.

## (completed) Stage 1 Outcome And Owner Review Course Correction

The Stage 1 memo is `stage1LiteratureReviewResults.md`. It satisfies the original Stage 1 resource-review gate, but owner review supersedes its initial hybrid downselect in the following ways:

- The first NN should not augment a Kalman filter with residuals, learned process noise, or learned covariance inflation.
- The first NN should replace the Sensor Fusion and Tracking Toolbox prediction/time-update role only.
- The target interface is `previousState, previousCovariance, dt -> predictedState, predictedCovariance`.
- The state vector must match Sensor Fusion and Tracking Toolbox constant-velocity convention: `[x; vx; y; vy; z; vz]` in local ENU meters and meters/second.
- The strict native prediction analogue is `constvel(state,dt)` with `constveljac(state,dt)` for baseline covariance propagation.
- `cvmeas` and `cvmeasjac` are measurement-model functions, not prediction functions; defer them until a later full measurement-update replacement.
- Use `trackingEKF` as the preferred classical comparator. Do not use `trackingKF` as the first baseline.
- Keep the first network simple, preferably an MLP, before testing GRU/LSTM/TCN, DANSE, KalmanNet, or Transformer-style approaches.

## (completed) Stage 2A Outcome And Local ADS-B Direction

The Stage 2A OpenSky go/no-go report is `stage2OpenSkyGoNoGoReport.md`. It found that anonymous OpenSky current-state access around Natick is technically viable:

- OpenSky datasets page and Natick current-state endpoint were reachable without manual credentials.
- The 10-minute probe collected 41 successful snapshots at a 15 second cadence.
- The probe parsed 2,243 raw records, retained 996 airborne records, found 46 aircraft with repeated valid samples, and built 881 usable one-step state pairs.
- Median usable `dt` was 16 seconds.
- MATLAB `table`, `timetable`, `wgs84Ellipsoid`, `geodetic2enu`, and `[x; vx; y; vy; z; vz]` state construction all worked.

Owner review after the successful probe changes the Stage 2 data-source priority:

- Do not use repeated anonymous OpenSky current-state polling as the primary training data path. It is a live sampling workflow and would duplicate the local ADS-B acquisition system already built for this project.
- Keep OpenSky as a validated fallback/reference source and as evidence that the state-pair construction approach is feasible.
- Make the primary Stage 2 data path the local Raspberry Pi/RTL-SDR/dump1090 ADS-B pipeline, including triggered capture sessions and any existing local SBS-1/BaseStation ADS-B truth logs.
- Reuse existing repo ADS-B parsing and capture infrastructure wherever possible.

## Stage 2: Data Acquisition And Prediction-Step Model Approach

Do not begin until Stage 1 is complete.

Questions Stage 2 must answer:

- What local ADS-B collection plan is needed to produce enough Raspberry Pi/RTL-SDR/dump1090 SBS-1 data for a prediction-step training dataset?
- What existing local ADS-B files are sufficient for parser, state-pair, and training smoke tests before collecting more data?
- How should ADS-B latitude, longitude, altitude, velocity, heading, and vertical rate be converted into local ENU state pairs in `[x; vx; y; vy; z; vz]` order?
- What covariance initialization is defensible for each training example when ADS-B gives position/velocity truth proxies but not true uncertainty?
- What initial NN input encoding should be used for `previousState`, `previousCovariance`, and `dt`?
- What covariance output parameterization guarantees a symmetric positive semidefinite `predictedCovariance`?
- What train/validation/test split prevents leakage by aircraft, route, day, region, and overlapping windows?
- What QA metrics decide whether the pilot data is usable for a prediction-step replacement?

Selected Stage 2 defaults:

- Model target: prediction/time-update replacement only.
- Runtime NN interface: `previousState, previousCovariance, dt -> predictedState, predictedCovariance`.
- State representation: local ENU, ordered as `[x; vx; y; vy; z; vz]`.
- Native comparator: `constvel(state,dt)` and covariance propagation with `constveljac(state,dt)`.
- Filter comparator: `trackingEKF` configured consistently with `constvel`, `constveljac`, `cvmeas`, and `cvmeasjac`; use it for benchmarking only.
- First model family: simple MLP predicting next state and covariance. Recurrent models are deferred until the one-step prediction formulation is validated.
- Dataset path: use local SBS-1/BaseStation ADS-B logs from the Raspberry Pi/RTL-SDR/dump1090 pipeline as the primary source. Keep OpenSky as fallback/reference only.
- Training target: one-step next state from ADS-B-derived state pairs, with covariance trained through likelihood/calibration rather than true covariance labels.
- First covariance output policy: predict six diagonal covariance variance values only. Map raw network outputs through a strictly positive transform such as `softplus(rawVariance) + epsilon`, then form `diag(variance)` so the predicted covariance is positive semidefinite by construction.

Expected Stage 2 output:

- A completed Stage 2A OpenSky go/no-go report.
- A data acquisition plan.
- A local ADS-B pilot dataset specification with minimum usable flight/window counts and criteria for whether more local collection is required.
- A candidate NN prediction-step architecture choice.
- A precise state/covariance encoding for model inputs and outputs.
- A baseline/comparator definition using `constvel`, `constveljac`, and `trackingEKF`.
- A decision on raw/derived artifact formats.

## (completed) Stage 2A: OpenSky Go/No-Go Probe

Complete this gate before committing to the full Stage 2 data-acquisition scope. The probe is intentionally limited to 2 hours of hands-on effort. Its purpose is not to build the final dataset; it is to decide whether OpenSky can supply usable prediction-step training pairs with low enough retrieval and processing effort.

Probe area:

- Center the probe on Natick, MA.
- Use approximate center latitude/longitude `42.2833, -71.3495`.
- Use a 50 km radius for final filtering.
- Use this initial OpenSky bounding box: `lamin=41.83`, `lomin=-71.96`, `lamax=42.73`, `lomax=-70.74`.
- After retrieval, filter records to the true 50 km radius using `geodetic2enu` and Euclidean horizontal range.

Allowed data sources, in priority order:

1. Anonymous OpenSky current-state API for the Natick bounding box: `https://opensky-network.org/api/states/all?lamin=41.83&lomin=-71.96&lamax=42.73&lomax=-70.74`
2. A public OpenSky sample or historical file only if it can be identified and loaded within 30 minutes.
3. Existing OpenSky credentials only if already available in the local environment; do not block the probe waiting for account creation or manual credential setup.

Minimum probe workflow:

1. Connectivity check: request the datasets page and the Natick current-state endpoint. Record HTTP status, content type, and any rate-limit headers.
2. Sampling check: collect repeated current-state snapshots for 10-15 minutes at a 15-30 second cadence, unless an immediately usable historical/sample file is available.
3. Parse the OpenSky state vector fields into a table with explicit names: `icao24`, `callsign`, `originCountry`, `timePosition`, `lastContact`, `longitude`, `latitude`, `baroAltitude`, `onGround`, `velocity`, `trueTrack`, `verticalRate`, `sensors`, `geoAltitude`, `squawk`, `spi`, and `positionSource`.
4. Keep airborne records with valid `icao24`, timestamp, latitude, longitude, altitude, velocity, and true track. Prefer `geoAltitude` for geometric altitude when available; otherwise use `baroAltitude` and record that fallback.
5. Convert valid records to local ENU relative to the Natick center using `wgs84Ellipsoid` and `geodetic2enu`.
6. Build state vectors in Sensor Fusion ordering `[x; vx; y; vy; z; vz]`. Compute `vx` and `vy` from speed and true track. Use `verticalRate` for `vz` when available; otherwise use finite-difference altitude only for continuity checks and mark the source.
7. Group by `icao24`, sort by timestamp, remove duplicate timestamps, compute `dt`, and build one-step pairs `state_k, covariance_k, dt_k -> state_k+1`.
8. Assign a provisional diagonal covariance for this probe only, in `[x; vx; y; vy; z; vz]` order, with documented assumed standard deviations. Do not treat this covariance as final training policy.
9. Write a short `stage2OpenSkyGoNoGoReport.md` summarizing access, parsing, field completeness, state-pair counts, `dt` distribution, altitude-source split, failures, and the final go/no-go decision.

Go criteria:

- The Natick endpoint is reachable without manual setup.
- The probe produces at least 5 airborne aircraft with repeated valid samples.
- The probe produces at least 100 usable one-step state pairs after filtering.
- Median usable `dt` is no greater than 30 seconds.
- At least 80% of retained records have valid latitude, longitude, altitude, velocity, and true track.
- A MATLAB table/timetable can be created without custom external dependencies.
- ENU conversion and `[x; vx; y; vy; z; vz]` state construction work for retained records.
- No immediate access, rate-limit, or licensing issue blocks local experimental use.

No-go criteria:

- Any required access path needs account creation, manual credential exchange, paid access, or more than 30 minutes of discovery.
- Repeated snapshots do not produce enough continuity for one-step pairs.
- Field completeness is too poor to build position and velocity states reliably.
- Sampling cadence or duplicates make `dt` unusable for the prediction-step experiment.
- Processing requires substantial custom scraping or non-MATLAB dependencies.
- Terms, rate limits, or redistribution constraints prevent practical local experimentation.

Required decision:

- If the go criteria pass, continue Stage 2 with OpenSky as the initial data source and still keep local ADS-B collection as a validation/fallback path.
- If any no-go criterion is decisive, stop OpenSky work and make local ADS-B collection the primary Stage 2 data acquisition path.
- If results are mixed, default to local ADS-B unless one additional hour would clearly resolve the issue without new account setup.

Risks and mitigations:

- API reachability risk: record status and rate-limit headers; if blocked or unstable, no-go OpenSky and pivot to local ADS-B.
- Continuity risk: current-state snapshots may be too sparse for trajectories; mitigate by sampling for 10-15 minutes, then no-go if pair counts remain low.
- Field-completeness risk: ground aircraft and null altitudes are common; mitigate by airborne filtering and altitude-source reporting.
- Altitude ambiguity risk: `baroAltitude` and `geoAltitude` may differ; mitigate by recording altitude source and not mixing silently.
- Coordinate/state-ordering risk: state order must remain `[x; vx; y; vy; z; vz]`; verify with a table column-order check in the report.
- Covariance-label risk: OpenSky does not provide true state covariance; use only provisional diagonal covariance for the probe and defer final covariance policy to full Stage 2.
- Leakage risk: repeated snapshots can produce overlapping windows; the probe may count windows for feasibility, but full Stage 2 must split by aircraft/day/region before training.
- Scope-creep risk: the probe is capped at 2 hours; do not add complex historical scraping, weather joins, route joins, or neural training during Stage 2A.


## (completed) Stage 2B: Local ADS-B Dataset Construction And First Training Interface

Stage 2B replaces the original "OpenSky first" data path with local ADS-B. Its purpose is to build a MATLAB-native state-pair dataset and first training interface for the prediction/time-update replacement. It must not replace the measurement update and must not use `cvmeas` or `cvmeasjac` except later in full filter benchmarking.

Primary local data sources, in priority order:

1. Existing packaged ADS-B truth files under `BistaticDataAnalysis/captures`, especially `BistaticDataAnalysis/captures/20260622T102123/truth/0_20260622_102124_adsb_20260622T102123.txt.gz`.
2. New triggered-capture sessions from `TriggerAcquisition/run_adsb_triggered_hdtv_capture.sh`, which stages Pi ADS-B files into packaged session `truth/` folders.
3. Raw files produced by `ADSB_GPS/gatherTCPcompress.py` when they are SBS-1/BaseStation ADS-B logs.
4. OpenSky only as fallback/reference data if local ADS-B collection is blocked or needs cross-checking.

Existing local data audit:

- `BistaticDataAnalysis/captures/20260622T102123/truth/0_20260622_102124_adsb_20260622T102123.txt.gz` was verified with `loadADSBTruth`.
- Verified parse result: 21 aircraft tracks, 1,780 total position fixes, 1,751 valid state samples, 20 aircraft with repeated samples, and 1,729 usable one-step pairs with `0 < dt <= 30` seconds.
- Verified `dt` range for usable pairs: minimum 0.40 seconds, median 0.58 seconds, maximum 27.72 seconds.
- The current `ADSB_GPS` folder contains logger scripts and NMEA `.txt.gz` files. Those NMEA files do not contain valid SBS-1 ADS-B records and should not be used as ADS-B training data.

Stage 2B concrete deliverables:

- `buildLocalADSBStatePairDataset.m`: MATLAB entrypoint that discovers local SBS-1 ADS-B files, calls `loadADSBTruth`, builds state pairs, saves the derived `.mat` dataset, and writes a short build summary.
- Focused helper functions for file discovery, receiver-origin resolution, ADS-B-track-to-ENU state construction, split assignment, normalization-statistic calculation, and `constvel` baseline scoring.
- A dataset-builder smoke test using the verified `20260622T102123` truth file.
- A minimal MATLAB MLP smoke-training script or function that loads the derived dataset, runs a few epochs, verifies finite loss, verifies positive diagonal covariance outputs, and reports baseline comparison metrics.
- A concise Stage 2B dataset/training summary report with counts, field completeness, `dt` statistics, split counts, baseline metrics, and smoke-training status.

Stage 2B non-goals:

- Do not write a new ADS-B parser.
- Do not run hardware collection or change the Raspberry Pi/RTL-SDR acquisition scripts.
- Do not expand OpenSky use beyond fallback/reference checks.
- Do not claim final model quality from the existing single local truth file.
- Do not implement recurrent models, full covariance output, learned Kalman gain, residual filters, measurement-update replacement, or hyperparameter sweeps.
- Do not add weather joins, route joins, aircraft-performance databases, smoothing, resampling, or multi-step rollout windows in this stage.

Native parser and input contract:

- Reuse `BistaticDataAnalysis/loadADSBTruth.m`; do not write a new SBS-1 parser.
- `loadADSBTruth` reads raw `.txt` or `.txt.gz` SBS-1/BaseStation logs, groups by ICAO hex, removes duplicate position timestamps, converts altitude from feet to meters, speed from knots to meters/second, and vertical rate from feet/minute to meters/second.
- `loadADSBTruth` returns per-aircraft fields `hex`, `callsign`, `t_utc`, `lat_deg`, `lon_deg`, `alt_m`, `speed_mps`, `track_deg`, and `vrate_mps`.
- Treat `MSG,3` position fixes as the state timeline. Treat `MSG,4` velocity interpolation onto the `MSG,3` timeline as the local ADS-B truth proxy already established by the repo.

State-pair construction workflow:

1. Find candidate local ADS-B truth files under packaged session `truth/` folders and accepted raw SBS-1 log locations.
2. Parse with `loadADSBTruth`.
3. For each session, resolve receiver ENU origin from session metadata when available. Default to the existing triggered-capture `RxLLA = [42.2999333, -71.349333, 15.0]` only when no session-specific receiver position is available.
4. Convert `lat_deg`, `lon_deg`, and `alt_m` to local ENU with `wgs84Ellipsoid` and `geodetic2enu`.
5. Compute velocity components with `vx = speed_mps * sind(track_deg)`, `vy = speed_mps * cosd(track_deg)`, and `vz = vrate_mps`.
6. Build states in exactly this order: `[x; vx; y; vy; z; vz]`.
7. Sort each aircraft by `t_utc`, remove duplicate timestamps, compute `dt`, and keep one-step pairs with `0 < dt <= 30` seconds.
8. Keep only pairs where both endpoints have finite latitude, longitude, altitude, speed, track, vertical rate, ENU position, and velocity components.
9. Do not smooth, resample, weather-join, route-join, or build multi-step windows in the first dataset pass.

Derived artifact contract:

- Save raw source files unchanged. Do not rewrite or normalize the raw SBS-1 logs.
- Save derived MATLAB artifacts as `.mat` files using `-v7.3` when large.
- The first derived dataset struct must contain:
  - `previousState`: `N x 6` double, ordered `[x, vx, y, vy, z, vz]`.
  - `nextState`: `N x 6` double, ordered `[x, vx, y, vy, z, vz]`.
  - `dtSeconds`: `N x 1` double.
  - `previousCovarianceDiag`: `N x 6` double.
  - `metadata`: table with at least `sessionID`, `sourceFile`, `hex`, `callsign`, `timeUtcK`, `timeUtcNext`, `receiverOriginLLA`, and `split`.
  - `stateOrder`: string array equal to `["x","vx","y","vy","z","vz"]`.
  - `covarianceStdAssumed`: row vector `[100, 10, 100, 10, 150, 5]`.
  - `normalization`: struct with input and target means/standard deviations computed from the training split only.
  - `sourceManifest`: table with source file path, source role, file size, modified time, parse status, aircraft count, and usable-pair count.
  - `splitManifest`: table or struct recording split policy, split seed, train/validation/test aircraft/session assignment, and leakage-check result.
  - `buildSummary`: struct with raw file counts, parsed aircraft counts, valid sample counts, usable pair counts, rejected-pair counts by reason, `dt` summary, and smoke-test flag.
  - `baselineConstVelMetrics`: struct with `constvel` one-step position and velocity error metrics in physical units.
- The first covariance input remains provisional. Use diagonal variances from the assumed standard deviations above in `[x; vx; y; vy; z; vz]` order. Do not treat these values as true ADS-B covariance labels.

Split and leakage policy:

- For smoke tests with only the existing `20260622T102123` file, allow a deterministic aircraft-level split and label the result "smoke test only".
- For any model-quality claim, require session-level holdout when multiple sessions exist.
- Do not allow the same `(sessionID, hex, timeUtcK)` pair to appear in multiple splits.
- If a single aircraft has overlapping one-step windows, keep all of that aircraft's windows in only one split for the first implementation.

First NN training interface:

- First model family: MLP.
- Inputs: normalized `previousState`, normalized `previousCovarianceDiag`, and normalized/scaled `dtSeconds`.
- Outputs: normalized predicted next-state mean and six raw diagonal covariance variance parameters.
- Convert raw covariance outputs with `softplus(rawVariance) + epsilon` and form a diagonal covariance. This guarantees a positive diagonal and therefore a positive semidefinite covariance matrix.
- First loss: diagonal Gaussian negative log likelihood on normalized next state, plus reporting metrics in physical units.
- Required reports: position RMSE, velocity RMSE, Gaussian NLL, empirical 1-sigma/2-sigma coverage, median/percentile `dt`, and comparison to `constvel(state,dt)`.

Stage 2B test and acceptance gates:

- Existing `loadADSBTruth` parser tests must pass before new dataset-builder work is accepted.
- A synthetic unit test must verify state ordering and velocity component conversion: `vx = speed_mps * sind(track_deg)`, `vy = speed_mps * cosd(track_deg)`, and `vz = vrate_mps`.
- A dataset-builder smoke test must run on the verified `20260622T102123` truth file and produce at least 1,000 usable one-step pairs with finite `dt`, finite states, and `0 < dt <= 30` seconds.
- State-order tests must verify that the exported state order is exactly `[x; vx; y; vy; z; vz]`.
- Split tests must verify that no `(sessionID, hex, timeUtcK)` pair appears in more than one split and that all overlapping one-step windows for one aircraft remain in one split for the first implementation.
- Covariance tests must verify that all input diagonal variances are positive and that all predicted diagonal covariance matrices from the smoke model are positive semidefinite.
- Baseline tests must run `constvel(state,dt)` on the smoke dataset and save one-step physical-unit position and velocity error metrics before NN training is accepted.
- Training smoke test must run a few epochs on the local smoke dataset and verify finite loss, correct output dimensions, strictly positive predicted variances, saved normalization constants, and saved smoke-training metrics.
- Stage 2B is complete only when the dataset artifact, source manifest, split manifest, build summary, `constvel` baseline metrics, and smoke-training status are written and reviewable.
- The existing single local truth file is enough for parser, state-pair, artifact, baseline, and training-code smoke tests. It is not enough for final model-quality claims; collect additional local ADS-B sessions before making performance claims.

## (completed) Stage 2B Outcome

Stage 2B smoke implementation is complete. It produced a MATLAB-native local ADS-B state-pair dataset and first training interface, but it does not establish that the NN improves aircraft prediction in a scientifically meaningful way.

Completed artifacts:

- Dataset builder entrypoint: `buildLocalADSBStatePairDataset.m`.
- MLP smoke-training entrypoint: `trainLocalADSBMLPSmoke.m`.
- One-command smoke runner: `runStage2BLocalADSBSmoke.m`.
- Focused tests: `tests/Stage2BLocalADSBSmokeTest.m`.
- Dataset artifact: `artifacts/stage2B/localADSBStatePairDataset.mat`.
- Training artifact: `artifacts/stage2B/localADSBMLPSmokeTraining.mat`.
- Summary report: `artifacts/stage2B/stage2BLocalADSBSmokeSummary.md`.

Verified smoke results:

- Parsed the verified `20260622T102123` local truth file through the existing `loadADSBTruth` parser.
- Built 1,729 usable one-step state pairs with finite states and `0 < dt <= 30` seconds.
- Preserved the required Sensor Fusion state order `["x","vx","y","vy","z","vz"]`.
- Saved positive provisional covariance diagonals using `[100, 10, 100, 10, 150, 5]` standard deviations.
- Computed normalization constants from the training split only.
- Passed aircraft-level split and `(sessionID, hex, timeUtcK)` leakage checks.
- Saved `constvel` one-step baseline metrics: position RMSE about 9.588 m and velocity RMSE about 1.020 m/s on the smoke artifact.
- Ran minimal MLP smoke training for three epochs with finite final loss, `N x 12` outputs, and strictly positive predicted variance values.
- Existing ADS-B truth/parser regression passed, and the new Stage 2B test class passed 3/3 tests.

Interpretation:

- Stage 2B proves the data contract, state order, artifact structure, native baseline path, covariance positivity transform, and MATLAB training-loop plumbing.
- Stage 2B does not prove model quality. The current single-session smoke file is too small and too narrow for claims about learned prediction performance.
- The NN should train against observed ADS-B next state, not against `constvel` output. `constvel` remains the floor comparator used to detect whether a learned model adds value.

## Stage 2C: Maneuver-Aware Characterization With Existing Data

Stage 2C should happen before full Stage 3 training. Its purpose is to ensure the project can evaluate interesting aircraft motion, not merely rediscover a constant-velocity predictor on mostly straight tracks.

Stage 2C must use only data already available locally. Do not collect new ADS-B sessions yet. If the existing data lacks maneuver diversity, document the gap explicitly so a later collection plan can target the missing regimes.

Core premise:

- `constvel` is useful because it is simple, native, and physically interpretable.
- `constvel` is not the final target behavior. The learned prediction-step model should learn from ADS-B next-state outcomes and should be judged by whether it improves or calibrates prediction across motion regimes.
- The project needs explicit maneuver coverage analysis before any broad claim that the NN is useful.

Native MATLAB comparators to keep in view after Stage 2B:

- Keep `constvel` and `constveljac` as the baseline floor.
- Use `constacc` and `constaccjac` to define acceleration-like behavior and as a likely future baseline where state compatibility is clearly documented.
- Use `constturn` and `constturnjac` to define turn-like behavior and as a likely future baseline where state compatibility is clearly documented.
- Keep `trackingIMM` in view as the serious classical comparator for diverse regime-switching behavior, but do not make IMM a prerequisite for computing pilot quality-style metrics.
- Keep `cvmeas`, `cvmeasjac`, and measurement-update replacement out of this stage.

Maneuver characterization outputs:

- Per-pair and per-track summaries of horizontal turn rate, heading change, speed change, vertical-rate change, climb/descent status, and `dt` regime.
- Counts of straight, turning, climbing, descending, accelerating/decelerating, and sparse-update pairs.
- A simple threshold-based maneuver taxonomy aligned with native toolbox model assumptions:
  - constvel-like: low turn rate, low speed change, low vertical-rate change.
  - constacc-like: measurable speed or vertical-rate change without sustained turn dominance.
  - constturn-like: sustained heading-rate or curvature behavior.
- Baseline metrics split by maneuver class, not just aggregate RMSE.
- A diversity-gap note describing which maneuver classes are underrepresented in the existing data and should be targeted by later collection.

Stage 2C acceptance checks:

- Generate a maneuver-characterization report from the Stage 2B dataset artifact.
- Verify that maneuver labels are derived only from existing ADS-B state fields and do not require smoothing, weather joins, route joins, or external aircraft-performance data.
- Report `constvel` baseline metrics by maneuver class.
- Do not set a hard Stage 3 maneuver-coverage gate yet. Run training, report what happens, and let the observed results guide whether stronger gates are justified.
- Keep one NN/MLP path for now. Maneuver labels are for evaluation and diagnosis, not for routing examples to separate models.

Resolved owner decisions before Stage 2C/3:

1. Do not collect new ADS-B data yet. Build what is possible from existing local data and document diversity gaps for a later collection plan.
2. Use simple, physically meaningful maneuver thresholds based on native toolbox motion-model assumptions before trying residual-based model classification.
3. Keep a single NN/MLP for now. The phrase "next NN" means the current single learned prediction-step experiment, not a new architecture family.
4. Compute quality-style scores whenever useful. `trackingIMM` is important context for diverse motion, but it is not required before reporting pilot metrics.
5. Do not create a Stage 3 maneuver-coverage gate yet. Run training and use observed results to decide whether a future gate is warranted.

## (completed) Stage 2C Outcome And Diversity Decision

Stage 2C used only `artifacts/stage2B/localADSBStatePairDataset.mat`. It did not collect new ADS-B data and did not train another neural model.

Primary outputs:

- Report: `artifacts/stage2C/stage2CManeuverCharacterizationReport.md`.
- Derived characterization artifact: `artifacts/stage2C/stage2CManeuverCharacterization.mat`.
- Figure: `artifacts/stage2C/stage2CManeuverCharacterization.png`.
- Implementation: `runStage2CManeuverCharacterization.m`, `helperAssignADSBManeuverLabels.m`, `helperScoreConstVelByManeuverClass.m`, and `helperWriteStage2CReport.m`.
- Tests: `tests/Stage2CManeuverCharacterizationTest.m`.
- Review Live Script: `stageReviewLiveScript.m`, with static plots and a `trackingGlobeViewer` section comparing ADS-B next-state truth, native `constvel`, and the saved smoke MLP output.

Threshold labels were derived from existing state pairs only:

- Heading and turn rate from velocity-vector direction change.
- Speed change from horizontal speed magnitude.
- Vertical-rate change from `vz`.
- Climb/descent from `vz`.
- Sparse update from `dtSeconds`.

Observed maneuver-class split on the current artifact:

| Maneuver class | Pairs | Share | Constvel position RMSE [m] | Constvel velocity RMSE [m/s] |
| :--- | ---: | ---: | ---: | ---: |
| constvel_like | 1,300 | 75.2% | 8.909 | 0.380 |
| constacc_like | 345 | 20.0% | 7.575 | 0.751 |
| constturn_like | 31 | 1.8% | 15.565 | 5.565 |
| mixed_or_sparse | 53 | 3.1% | 23.174 | 2.934 |

Additional diversity notes:

- No pair reached the 3 deg/s standard-rate turn threshold; the maximum observed absolute turn rate was 2.421 deg/s.
- The dataset contains climb/descent status examples from existing `vz` values: 662 climbing pairs, 365 descending pairs, and 702 level pairs.
- Only 36 pairs were sparse updates at `dtSeconds >= 5` seconds.
- The artifact is still a single-session local smoke dataset, so it lacks diversity in maneuver regimes, update spacing, traffic mix, route geometry, and collection conditions.

Decision for the Stage 2C question:

- No, the current dataset is not diverse enough to support a defensible claim that a learned predictor can learn behavior beyond `constvel`.
- The labels are still useful for Stage 3 stratified diagnostics and regression tests.
- Future data collection should intentionally target turns, acceleration/deceleration, climbs, descents, and sparse-update regimes before making broad model-quality claims.

## Stage 3: Training Implementation Skeleton

Stages 1, 2B, and 2C are complete. Stage 3A is now the next implementation push. It should use the existing Stage 2B dataset and Stage 2C maneuver labels only; do not collect new ADS-B data during Stage 3A.

Stage 3A purpose:

- Replace the three-epoch smoke trainer with a reproducible MATLAB training run that can be inspected and repeated.
- Keep one small MLP as the first serious learned prediction-step model.
- Train the MLP to predict state deltas, not absolute next states, so the model learns local motion instead of memorizing global ENU position scale.
- Use the Stage 2C maneuver labels for stratified diagnostics, not as a classifier output and not as a routing layer.
- Make the result honest: the current artifact can prove whether the training setup is sane, but it cannot prove broad maneuver learning.

Stage 3A Native Function Discovery:

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Train a simple MLP with validation and checkpointing | Deep Learning Toolbox `trainnet` with `trainingOptions("adam")` | Use a custom function-handle loss for diagonal Gaussian NLL because the network outputs both state-delta means and variance parameters. |
| Fail-fast mean-only training ladder | Deep Learning Toolbox `trainnet` with `trainingOptions("adam")` | Start with mean-only MSE delta prediction before enabling the covariance head and Gaussian NLL. |
| Baseline sanity models | Statistics and Machine Learning Toolbox `fitrlinear` or `fitlm` | Train simple per-output delta baselines before neural runs so the MLP has a low-cost sanity target. |
| Avoid a hand-written optimizer loop | `trainnet` plus `ValidationData`, `ValidationPatience`, `CheckpointPath`, and returned training info | Keep custom math limited to the loss and prediction postprocessing; do not reimplement Adam or mini-batch iteration unless `trainnet` cannot support the required loss. |
| Compare with native motion baseline | Sensor Fusion and Tracking Toolbox `constvel` and `constveljac` | Use `constvel` for one-step state prediction and keep covariance propagation as a reported comparator where the assumed covariance policy is explicit. |
| Report split and maneuver diagnostics | MATLAB `table`, `groupsummary`, `findgroups`, and `splitapply` | Report train, validation, test, maneuver-class, vertical-status, sparse-update, and per-track metrics. |
| Review trajectories visually | `trackingGlobeViewer`, `plotTrajectory`, and `snapshot` | Use fixed colors: truth green, `constvel` blue, Stage 3 MLP red; save or show a snapshot for the Live Script. |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| MLP layer stack | `featureInputLayer`, `fullyConnectedLayer`, `reluLayer` | `layers = [featureInputLayer(featureCount); fullyConnectedLayer(hiddenUnits); reluLayer; fullyConnectedLayer(outputCount)]` |
| Network training | `trainnet` | `[net, info] = trainnet(XTrain, YTrain, layers, lossFcn, options)` |
| Training options | `trainingOptions` | `options = trainingOptions("adam", "MaxEpochs", maxEpochs, "ValidationData", validationData, "ValidationPatience", patience)` |
| Linear delta baseline | `fitrlinear` or `fitlm` | `model = fitrlinear(XTrain, yTrain)` |
| Prediction | `minibatchpredict` or `predict` | `prediction = minibatchpredict(net, XAll)` |
| Positive diagonal variance | MATLAB elementwise `log` and `exp` | `variance = log(1 + exp(rawVariance)) + varianceEpsilon` |
| Native baseline | `constvel` | `predictedState = constvel(previousState, dtSeconds)` |
| Error metrics | `vecnorm`, `mean`, `median`, `prctile` | `positionRMSE = sqrt(mean(positionErrorNorm .^ 2, "omitnan"))` |

Resolved Stage 3A design decisions:

- Do not add Stage 2D for this adjustment. Stage 2C completed the data-characterization gate; delta-target MLP training belongs in Stage 3.
- Do not use generic transfer learning for the first serious run. A pretrained image, text, audio, or unrelated sequence model does not match the low-dimensional ADS-B prediction-step interface. Revisit transfer learning only if a compatible ADS-B trajectory model with matching state semantics is found.
- Keep a shallow MATLAB MLP because the input and output are small tabular dynamics quantities, and the goal is to validate the prediction-step interface before introducing GRU, LSTM, TCN, Transformer, KalmanNet, or IMM-style neural routing.
- Use `trainnet` as the default Stage 3A training engine. The Stage 2B custom training loop was a smoke-test convenience, not the preferred serious-training path.
- Keep the custom Gaussian NLL loss for the covariance phase because the final model predicts both a mean and diagonal covariance. Do not start the serious run there; first prove mean-only delta prediction with MSE.
- Train one-step prediction first. Multi-step rollout is deferred until the one-step model is stable and interpretable.

Stage 3A ML expert pre-run review conclusions:

- The delta-target plan is correct, but Stage 3A must be a fail-fast ladder rather than a single long covariance run.
- The current aircraft-level split is leakage-aware but not behavior-balanced: all 31 `constturn_like` pairs are in training, none are in validation or test, and the validation split is entirely climb status.
- Treat the current validation and test splits as smoke holdouts only. They can catch gross training failures, but they cannot prove maneuver generalization.
- Add physics-derived delta features such as `vx * dt`, `vy * dt`, `vz * dt`, or the equivalent native `constvel` state delta so the MLP does not waste its first capacity learning multiplication.
- The current `previousCovarianceDiag` has one unique row in the Stage 2B artifact. Keep it in the interface, but report it as non-informative for this dataset and do not expect covariance-conditioned behavior yet.
- Gate any Gaussian NLL or covariance-head work on a sane mean-only model that stays near the aircraft and approaches the native `constvel` baseline.

Stage 3A target and reconstruction policy:

```matlab
targetDelta = nextState - previousState;
predictedNextState = previousState + predictedDelta;
```

Rationale:

- Absolute `nextState` includes local ENU position that can be thousands of meters from the receiver origin. A weak absolute-state model can collapse toward a dataset-average location and draw a trajectory in the wrong direction.
- `targetDelta` is the observed one-step motion. For constant-velocity behavior, position deltas are approximately velocity times `dt`, and velocity deltas are approximately zero.
- Reconstructing with `previousState + predictedDelta` anchors even a mediocre model near the current aircraft instead of letting it predict an unrelated absolute position.
- This is still a prediction-step replacement, not a residual correction model. Do not train against `constvel` residuals in Stage 3A.

Stage 3A default feature encoding:

- The public runtime interface remains `previousState, previousCovariance, dt -> predictedState, predictedCovariance`.
- The first serious MLP should use motion-focused features derived from that interface: previous velocity components, previous altitude/local `z`, previous covariance diagonal, `dtSeconds`, and physics-derived delta features such as `vx * dt`, `vy * dt`, `vz * dt`, or `constvel(previousState, dtSeconds) - previousState`.
- Do not include absolute horizontal `x` and `y` as default neural features in Stage 3A. They are used only to reconstruct the final absolute prediction. This avoids teaching the first model local-map position bias before motion learning is proven.
- Because `previousCovarianceDiag` is constant in the current artifact, include it only to preserve the interface and explicitly report that it has no training variation yet.
- Compute all feature and target normalization statistics from the training split only.

Stage 3A fail-fast training ladder:

1. Preflight audit, no training: finite checks, target-delta statistics, feature standard deviations, split-by-maneuver counts, split-by-vertical-status counts, sparse-update counts, and `constvel` metrics by split.
2. Baseline pass: report persistence or zero-delta, train-mean-delta, native `constvel`, and a simple per-output linear delta regression with `fitrlinear` or `fitlm`.
3. Tiny overfit test: train a mean-only delta MLP on 32 to 128 training examples. It should drive training error sharply down; if it cannot, stop and debug target reconstruction, normalization, or `trainnet` data formats.
4. Short full run: train a mean-only delta MLP for 10 to 20 epochs with one seed. Stop if validation position RMSE is still tens to hundreds of meters worse than `constvel`, or if trajectory plots move in the wrong direction.
5. Feature ablation: compare raw motion features against engineered `vx * dt`, `vy * dt`, `vz * dt`, and `constvel` delta features. Keep sparse-update behavior reported separately and consider a sparse-update flag.
6. Covariance phase: add the 12-output mean-plus-variance head and Gaussian NLL only after mean prediction is sane. Gate this phase on physical RMSE and calibration coverage, not NLL alone.
7. Longer run: run 100 to 300 epochs, validation patience 20 to 30, and 3 to 5 seeds only after the quick rungs approach `constvel`. Select the best checkpoint by validation physical metric and report all seeds.

Stage 3A training defaults:

- Entry point: `trainLocalADSBMLPStage3.m`.
- Dataset: `artifacts/stage2B/localADSBStatePairDataset.mat`.
- Maneuver labels: `artifacts/stage2C/stage2CManeuverCharacterization.mat`.
- Output folder: `artifacts/stage3/`.
- Random seed: `rng(123, "twister")`.
- Hidden units: two fully connected hidden layers with 64 units each and ReLU activations.
- Mean-only output size for first rungs: 6 normalized state-delta means.
- Covariance-phase output size after mean prediction is sane: 12 values, with 6 normalized state-delta means and 6 raw diagonal variance parameters.
- Tiny overfit maximum epochs: 50.
- Short full-run maximum epochs: 10 to 20.
- Long-run maximum epochs: 100 to 300, only after the quick rungs pass.
- Mini-batch size: 128.
- Initial learning rate: `1e-3`.
- Validation patience: 20 to 30 epochs for the long run; keep early rungs short and explicit.
- L2 regularization: `1e-4`.
- Execution environment: `auto` unless a later hardware check requires CPU-only reproducibility.

Stage 3A required artifacts:

- `artifacts/stage3/localADSBMLPStage3Training.mat` with the trained network, training info, config, normalization, predictions, reconstructed next states, covariance diagonals, and metrics.
- `artifacts/stage3/stage3LocalADSBMLPTrainingReport.md` with training details, preflight audit tables, split counts, loss curves, aggregate metrics, split metrics, maneuver-class metrics, baseline ladder results, and an explicit diversity warning.
- Stage 3 figures for training progress, error comparison against `constvel`, maneuver-class metrics, and at least one trajectory comparison.
- Updated `stageReviewLiveScript.m` section that compares ADS-B truth, native `constvel`, Stage 2B smoke MLP, and Stage 3A delta-target MLP where the Stage 3 artifact exists.
- Updated `concepts.md` entry for the delta-target MLP training workflow.

Stage 3A acceptance checks:

- Training uses MATLAB `trainnet` and does not include a hand-written mini-batch Adam loop.
- The preflight audit reports split-by-maneuver and split-by-vertical-status counts before any training.
- The short test mode can run on the real Stage 2B artifact with a small epoch count and produce finite loss.
- Mean-only MLP training passes the tiny-overfit and short-full-run gates before covariance/NLL training starts.
- All predicted diagonal variances are strictly positive after the softplus transform in the covariance phase.
- Metrics are reported for train, validation, test, maneuver class, vertical status, sparse-update status, and at least the selected review track.
- `constvel` remains the required comparator. If the Stage 3A MLP does not beat `constvel`, report that directly instead of tuning until it appears favorable.
- The report explicitly states that the current data lacks turn, acceleration, climb/descent, sparse-update, session, and traffic diversity for broad learned-model claims.

Deferred follow-up questions after Stage 3B:

- Should a later model learn `constvel` residuals instead of full state deltas?
- Is there enough evidence to add absolute `x` and `y` back as an ablation feature?
- Does a simple `trackingEKF` prediction-only comparator add clarity beyond the direct `constvel` one-step baseline?
- How much more local ADS-B collection is required before testing GRU, LSTM, TCN, Transformer, KalmanNet, `trackingIMM`, or multi-step rollout?

## Stage 3B: Aggregate ADS-B Evaluation Gate

Stage 3B is implemented as an evaluation and data-readiness gate, not a retraining run.

Native MATLAB path:

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Local ADS-B aggregation | MATLAB `dir`, `table`, and existing parser workflows | Reuse `helperDiscoverLocalADSBTruthFiles` and `buildLocalADSBStatePairDataset`; do not create another parser. |
| Frozen prediction comparison | Sensor Fusion and Tracking Toolbox `constvel` workflow | Compare frozen Stage 3A MLP and native `constvel` on identical state-pair rows. |
| Grouped metrics | MATLAB `findgroups`, `splitapply`, `vecnorm`, `mean`, `median`, `prctile` | Report aggregate, session, source, aircraft, maneuver, vertical, and sparse-update metrics. |
| Review visualization | MATLAB `figure`, `plot`, `tiledlayout`, `nexttile`, and `trackingGlobeViewer` | Save static Stage 3B plots, including the blue/red row-wise position absolute error separation view, and provide an optional globe helper. |

Function audit:

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Constant-velocity baseline | `constvel` | `predictedState = constvel(previousState, dtSeconds)` |
| Frozen MLP inference | `minibatchpredict` | `predictedDeltaNormalized = minibatchpredict(net, featuresNormalized)` |
| Error norms | `vecnorm`, `mean`, `median`, `prctile` | `rmse = sqrt(mean(vecnorm(error, 2, 2).^2, "omitnan"))` |
| Grouped reporting | `findgroups`, `splitapply` | `metric = splitapply(@mean, values, groupID)` |

Implemented artifacts:

- Entrypoint: `runStage3BAggregateADSBEvaluation.m`.
- Output MAT: `artifacts/stage3B/localADSBAggregateStage3BEvaluation.mat`.
- Aggregate dataset: `artifacts/stage3B/localADSBAggregateStatePairDataset.mat`.
- Report: `artifacts/stage3B/stage3BAggregateADSBEvaluationReport.md`.
- Figures: Stage 3B aggregate error, all-row position absolute error separation, grouped RMSE, readiness gates, and selected-track comparison.
- Review integration: `stageReviewLiveScript.m` and `helperBuildStageReviewArtifacts.m` load Stage 3B optionally.
- Concept index: `concepts.md` includes the Stage 3B aggregate evaluation gate.

Current Stage 3B result from available local data:

- Evaluated pairs: 1,729.
- Distinct sessions: 1.
- Usable local truth files: 1.
- Aircraft tracks: 17.
- Native `constvel` position RMSE: about 9.588 m.
- Frozen Stage 3A MLP position RMSE: about 131.927 m.
- Retraining readiness: not ready, because session/source diversity and some maneuver/update-regime gates are below the configured thresholds.

Stage 3B acceptance checks:

- `constvel` and frozen Stage 3A MLP metrics are computed on the same samples.
- Frozen MLP reconstruction remains `previousState + predictedDelta`.
- The Stage 3B Live Script section plots every row-wise position absolute error with `constvel` in blue and the frozen Stage 3A MLP in red.
- The aggregate report and MAT artifact are produced even when only one eligible session exists.
- The Live Script runs with and without a Stage 3B artifact.
- Retraining remains deferred until a later stage with more diverse local ADS-B data.

## (completed) Stage 3C: Archived ADS-B Evaluation Extension

Stage 3C is implemented as an archive evaluation extension after the Stage 3B gate. It does not replace the original Stage 3B artifact and does not retrain the Stage 3A MLP.

Native workflow audit:

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Import archived ADS-B truth trajectories | `trackingScenarioRecording` / truth trajectory import analogue: https://www.mathworks.com/help/fusion/ref/trackingscenariorecording.html | Keep ADS-B as truth trajectory data, not `objectDetection`; reuse `loadADSBTruth` and Stage 3 state-pair format. |
| Convert ADS-B geodetic fixes into local training states | `geodetic2enu`: https://www.mathworks.com/help/map/ref/geodetic2enu.html | Preserve existing ENU state order `[x, vx, y, vy, z, vz]` and receiver-origin fallback reporting. |
| Score native prediction baseline | `constvel`: https://www.mathworks.com/help/fusion/ref/constvel.html | Continue using `constvel(state, dt)` through Stage 3B scoring; do not hand-code constant-velocity propagation. |
| Visualize archive coverage and gaps | `figure`, `tiledlayout`, `nexttile`, `trackingGlobeViewer`: https://www.mathworks.com/help/fusion/ref/trackingglobeviewer.html | Add labeled Stage 3C plots for archive usability, readiness gates, and motion/update-regime coverage. |

Function audit:

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Gzip decompression | Primary: `gunzip`; fallback only after MATLAB `gunzip` fails: .NET `System.IO.Compression.GZipStream` | `out = gunzip(filename, tempFolder)` |
| Time parsing and units | `datetime`, `posixtime`, built-in scalar conversions | `dt = datetime(text, "InputFormat", ..., "TimeZone", "UTC")` |
| Geodetic to ENU conversion | `wgs84Ellipsoid`, `geodetic2enu` | `[xEast, yNorth, zUp] = geodetic2enu(lat, lon, alt, lat0, lon0, h0, spheroid)` |
| Baseline prediction | Sensor Fusion and Tracking Toolbox `constvel` | `predictedState = constvel(previousState, dtSeconds)` |
| Frozen MLP inference | Deep Learning Toolbox `minibatchpredict` | `y = minibatchpredict(net, featuresNormalized)` |
| Grouped metrics | `table`, `findgroups`, `splitapply`, `groupsummary`, `vecnorm`, `mean`, `median`, `prctile` | `G = findgroups(groupValues); metric = splitapply(@mean, values, G)` |

Implemented artifacts:

- Entrypoint: `runStage3CArchiveADSBEvaluation.m`.
- Archive inventory helper: `helperBuildStage3CArchiveInventory.m`.
- Report and figures: `helperWriteStage3CReport.m` and `helperWriteStage3CFigures.m`.
- Gzip fallback: `../BistaticDataAnalysis/helperInflateGzipWithDotNet.m`.
- Test: `tests/Stage3CArchiveEvaluationTest.m`.
- Output folder: `artifacts/stage3C/`.

Current Stage 3C result from the archived ADS-B package:

- Archive source files: 16.
- Fallback recovered files: 2.
- Usable sessions: 16.
- Usable one-step pairs: 15,013.
- Aircraft tracks: 222.
- Native `constvel` position RMSE: about 23.870 m.
- Frozen Stage 3A MLP position RMSE: about 151.260 m.
- Basic Stage 3B readiness gates: pass.
- Remaining collection gaps: `pi_only/truth` is empty, and all truth-only archive sessions use the default receiver origin because no `session_manifest.json` receiver LLA metadata was packaged.

Stage 3C acceptance checks:

- Code Analyzer is clean for the new Stage 3C entrypoint, helpers, fallback helper, and test.
- `Stage3CArchiveEvaluationTest` passes and verifies archive discovery, empty `pi_only/truth` handling, fallback gzip inflation, artifacts, figures, scoring tables, and the exact archive counts.
- Existing `Stage3BAggregateEvaluationTest` passes, preserving the original one-session Stage 3B baseline.
- Existing `Stage4ADSBTruthCapturePlanningLiveScriptTest` passes.

## (completed) Stage 4A: Question-Driven ADS-B Truth Capture Planning Checkpoint

Stage 4A is implemented as a capture-planning checkpoint, not a retraining run. It now prefers the saved Stage 3C archive artifact when present and falls back to the saved Stage 3B aggregate artifact only for compatibility.

Native MATLAB path:

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Recompute collection priorities from Stage 3C | MATLAB `load`, `table`, `groupsummary`, `findgroups`, `splitapply` | Load the saved Stage 3C artifact when available and convert archive caveats into explicit Stage 4 collection gates. |
| Visualize revised collection gaps | MATLAB `figure`, `tiledlayout`, `nexttile`, `bar`, `barh`, `imagesc` | Show Pi-only versus testing-machine source coverage, receiver-origin metadata coverage, motion/update coverage, and targeted collection status. |
| Compare predictors by regime | Sensor Fusion and Tracking Toolbox `constvel` comparator plus saved Stage 3B MLP outputs | Continue plotting native `constvel` and frozen Stage 3A MLP results by maneuver and update regime without retraining. |
| Preserve ADS-B truth ingestion path | Existing `loadADSBTruth` SBS-1 parser and capture discovery layout | Keep ADS-B as truth trajectory data under `BistaticDataAnalysis/captures/<session_id>/truth/*adsb_<session_id>*.txt.gz`; require `session_manifest.json` receiver LLA metadata during packaging. |

Implemented artifacts:

- Live Script: `stage4ADSBTruthCapturePlanningLiveScript.m`.
- Builder: `helperBuildStage4ADSBTruthCapturePlan.m`.
- Plot helper: `helperPlotStage4ADSBTruthCapturePlan.m`.
- Test: `tests/Stage4ADSBTruthCapturePlanningLiveScriptTest.m`.
- Figures: `artifacts/stage4A/stage4A_readiness_gates.png`, `stage4A_motion_coverage_shortfall.png`, `stage4A_model_vs_data_problem.png`, `stage4A_split_coverage.png`, and `stage4A_capture_campaign_progress.png`.

Current Stage 4A result from the saved Stage 3C artifact:

- Basic Stage 3B readiness gates pass on the archive: 16 sessions, 16 truth files, 222 aircraft tracks, 350 constturn-like pairs, 336 sparse-update pairs, 4,919 climb pairs, and 4,374 descent pairs.
- The remaining issue is not raw archive count. `pi_only/truth` is empty, all 16 evaluated files use the default receiver origin, and new collection still needs independent holdout sessions, source diversity, and passive-radar-relevant geometry.
- The Stage 4A summary now exposes `hasStage3C`, `piOnlyTruthFileCount`, `defaultReceiverOriginFileCount`, `sessionManifestOriginFileCount`, `independentHoldoutRecommendation`, `metadataPreservationRecommendation`, and `collectionDecision`.
- Capture command template: `sudo ./start_adsb_gps_loggers.sh --adsb-only --adsb-session-id <session_id> --adsb-run-seconds 900`.
- Truth folder layout: `BistaticDataAnalysis/captures/<session_id>/truth/*adsb_<session_id>*.txt.gz`.
- Required metadata layout: `BistaticDataAnalysis/captures/<session_id>/session_manifest.json` with receiver LLA metadata.
- Retraining remains deferred.

Stage 4A acceptance checks:

- The helper loads Stage 3C when present and falls back to Stage 3B when Stage 3C is absent.
- The current Stage 4A result no longer reports the primary issue as missing 2 sessions or 2 files.
- Empty Pi-only archive coverage is an explicit collection priority.
- Default receiver-origin usage is an explicit metadata preservation priority.
- Every Stage 4A plot has `xlabel`, `ylabel`, and `title`.
- Code Analyzer is clean for the changed Stage 4A Live Script, helpers, and test.
- `Stage4ADSBTruthCapturePlanningLiveScriptTest`, `Stage4BADSBIntervalCampaignScriptTest`, `Stage3CArchiveEvaluationTest`, and `Stage3BAggregateEvaluationTest` pass.
## (completed) Stage 4B: ADS-B Interval Capture Campaign

Stage 4B now implements a testing-machine ADS-B interval capture coordinator. New project code stays under `adsbForTracking/piCaptureCampaign/`; the operator runs it from the Ubuntu testing machine, it SSHes to the Raspberry Pi, starts bounded ADS-B-only windows through the existing Pi Python ADS-B logger used by the full capture pipeline, fetches gzip truth logs with `scp`, and packages each window as `captures/<session_id>/` with `session_manifest.json` receiver-origin metadata.

Native workflow audit:

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Run ADS-B capture from the testing machine while SSHing into the Pi | MATLAB `system` external-command analogue, existing repo Bash coordinator pattern in `TestSetupTesting/run_coordinated_hdtv_capture.sh` | Keep orchestration in Bash to match the capture pipeline operator model; do not move this into MATLAB. |
| Preserve ADS-B truth as packaged session data | MATLAB `jsonencode`, `load`, table-based Stage 3C archive ingestion analogue | Write ADS-B-only `captures/<session_id>/session_manifest.json` with receiver LLA metadata so Stage 3C reads session metadata instead of default receiver origin. |
| Validate post-campaign collection readiness | Existing Stage 3C and Stage 4A MATLAB workflows | Rerun Stage 3C/Stage 4A after syncing packaged sessions; no retraining. |

Function audit:

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Shell preflight/test execution | `system` | `[status, output] = system(command)` |
| ADS-B-only capture | Existing Pi Python logger used by the full capture coordinator | `python3 gatherTCPcompress.py --session-id <session_id> --run-seconds 300` |
| Manifest encoding concept | `jsonencode` | `jsonText = jsonencode(manifest)` |
| Post-campaign archive evaluation | Existing MATLAB Stage 3C scripts | `runStage3CArchiveADSBEvaluation` then `stage4ADSBTruthCapturePlanningLiveScript` |

Implemented artifacts:

- Script: `piCaptureCampaign/run_stage4_adsb_interval_campaign.sh`.
- Operator README: `piCaptureCampaign/README.md`.
- Test: `tests/Stage4BADSBIntervalCampaignScriptTest.m`.

Default campaign behavior:

- Runs 300 second ADS-B-only captures every 1800 seconds for 259200 seconds.
- Runs from the testing machine and defaults to Pi target `pi2@192.168.10.131` with workdir `/home/pi2/flightTest/ADSB_GPS`.
- Uses the full-pipeline ADS-B command pattern: `python3 gatherTCPcompress.py --session-id <session_id> --run-seconds <seconds>`, launched remotely with `setsid` or `nohup`.
- Uses campaign IDs of the form `stage4B_<UTC timestamp>` unless overridden.
- Uses per-window session IDs of the form `<campaign_id>_wNNN_<UTC timestamp>`.
- Writes campaign metadata under `piCaptureCampaign/campaigns/<campaign_id>/`.
- Packages each window under `captures/<session_id>/truth/`, `captures/<session_id>/logs/`, and `captures/<session_id>/session_manifest.json`.
- Writes manifest field `receiver_origin_lla` as a numeric three-element `[lat, lon, alt_m]`, defaulting to `[42.2999333, -71.349333, 15.0]`, with `--receiver-origin-lla` override support.
- Continues through no-aircraft/no-file windows and aborts after three consecutive remote logger start failures.

Stage 4B acceptance checks:

- `run_stage4_adsb_interval_campaign.sh` exists and is designed for `bash -n` syntax validation where bash is available.
- `--help` lists SSH/SCP options, local packaging roots, receiver-origin override, and campaign controls.
- `--dry-run --campaign-seconds 3700 --capture-seconds 300 --interval-seconds 1800` plans three unique windows and prints Pi target, session root, receiver LLA, and remote command template without SSH or package writes.
- Invalid numeric options and invalid `--receiver-origin-lla` values fail nonzero.
- `--preflight-only` matches the full capture coordinator preflight: SSH, remote Python ADS-B logger presence, `python3`, local `scp`, and local write access before capture startup. It does not add a separate `dump1090` check.
- A shell-level fake `ssh`/`scp` test verifies the expected remote command and the ADS-B-only packaged-session layout without contacting hardware.
- The operator README describes running from the testing machine and no longer instructs copying/running the coordinator on the Pi.

Manual testing-machine smoke test:

```bash
cd /path/to/flightTest
bash adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh --campaign-seconds 700 --capture-seconds 30 --interval-seconds 300 --max-windows 2
```

Post-campaign validation remains to sync packaged ADS-B-only sessions as needed, preserve `captures/<session_id>/session_manifest.json` with receiver LLA metadata, rerun Stage 3C, rerun Stage 4A, and check movement toward Pi-only holdout, metadata completeness, source diversity, targeted motion/update coverage, and passive-radar-relevant geometry.

## (completed) Stage 4B-Post: Versioned Dataset Integration And Motion-Diversity Gate

Stage 4B-Post integrates the completed three-day ADS-B campaign, preserves the earlier evaluation as an independently rerunnable baseline, and answers:

> Have we collected enough heterogeneous motion data to justify training a more robust neural prediction model?

This is an integration and data-readiness stage. Keep the Stage 3A MLP frozen and do not retrain while measuring how the dataset changed.

### Named Dataset Variants

Use these names consistently in code, reports, plots, and artifact folders:

| Variant ID | Display name | Contents | Known pre-integration evidence |
| :--- | :--- | :--- | :--- |
| `legacy_pre3day_v1` | **Legacy-16** | The exact 16 archived truth files used by the 2026-08-18 Stage 3C run. | 16 usable sessions, 15,013 pairs, 222 session/aircraft tracks, 350 constturn-like pairs, and 336 sparse-update pairs. |
| `campaign_3day_increment_v1` | **3-Day Campaign Increment** | Only the completed Stage 4B campaign `stage4B_3Day_nohup_20260819T132526Z`. | 144 packaged windows, 144 valid manifests, 143 gzip truth files, and one permitted no-gzip window (`w133`). |
| `expanded_post3day_v2` | **Expanded-3Day** | The union of `Legacy-16` and the `3-Day Campaign Increment`. | Expected inventory before parsing: 159 truth files; final usable session, track, and pair counts must come from MATLAB ingestion. |

The named difference between the old and new evaluation is the **3-Day Campaign Increment**:

```text
Expanded-3Day = Legacy-16 + 3-Day Campaign Increment
```

Do not describe the new result merely as a rerun of Stage 3C. It is an expanded-data evaluation, and every comparison must identify which named variant produced it.

### Verified Transfer Input

- Transfer package: `stage4B_adsb_3day.zip`.
- Windows SHA-256: `BE2457298D38768DB950BF0A2EE15DBE5B5264B8532220F4AD6E44B4DA56AF3C`.
- Archive contents: 575 readable file entries, 144 session folders, 144 valid `session_manifest.json` files, 143 `*.txt.gz` truth files, and 288 log files.
- Every manifest has numeric `receiver_origin_lla = [42.2999333, -71.349333, 15.0]`.
- All entries belong to campaign `stage4B_3Day_nohup_20260819T132526Z`; no unrelated Pluto capture files are present.
- Keep the ZIP until integration, parsing, and variant-manifest verification all pass. Do not automatically delete or move it.

### Native MATLAB Workflow Audit

| Proposed workflow | Native or existing MATLAB analogue | Update needed for this stage |
| :--- | :--- | :--- |
| Extract the transport package to a temporary staging area | `unzip`, `tempname`, `onCleanup` | Validate the staged layout and collisions before copying any session into the append-only archive. |
| Import ADS-B truth trajectories | Existing `loadADSBTruth` | Reuse it unchanged; ADS-B remains truth trajectory data and must not be converted to `objectDetection`. |
| Build local motion states | Existing `helperBuildLocalADSBStatePairs`, `wgs84Ellipsoid`, `geodetic2enu` | Preserve `[x, vx, y, vy, z, vz]`, units, receiver-origin metadata, and `0 < dt <= 30` seconds. |
| Evaluate the frozen predictor | Existing Stage 3B/3C path, `minibatchpredict`, native `constvel` | Run identical scoring separately for all three named variants; do not retrain. |
| Summarize motion coverage | `table`, `findgroups`, `splitapply`, `groupsummary`, `discretize`, `prctile` | Add independent maneuver-event, contributor-concentration, time-block, and prospective split summaries. |
| Visualize the old/new difference | `figure`, `tiledlayout`, `nexttile`, `bar`, `barh`, `heatmap` or `imagesc` | Plot percentages and independent contributors as well as raw pair counts. |

Custom code is justified only for dataset-variant membership, safe collision handling, contiguous maneuver-event segmentation, and the final readiness decision. Do not write another ADS-B parser, coordinate converter, motion propagator, or optimizer.

### Integration And Versioning Workflow

1. **Stage and validate without changing the archive.**
   - Extract the ZIP under a temporary folder.
   - Require the sole top-level data folder to be `captures/`.
   - Verify all 144 manifests parse, all session IDs match their folder names, all 143 named truth files exist, and the one no-gzip window is explicitly represented.
   - Test every gzip through the existing MATLAB truth-import path.
   - Reject path traversal, unexpected file types, duplicate session IDs, unexplained missing truth, or nonfinite receiver origins.

2. **Integrate into an append-only source store.**
   - Copy validated session folders into `adsb_archive/adsb_archive/testing_machine/captures/`.
   - Before each copy, check for an existing session folder.
   - If an existing session has identical file hashes, record it as already present.
   - If any same-named session differs, abort the integration; never overwrite it.
   - Retain the complete session package so `truth/`, `logs/`, and `session_manifest.json` stay together.

3. **Freeze logical dataset membership.**
   - Add one durable dataset-version manifest containing relative source path, source-file hash, session ID, campaign ID, capture date/time, receiver-origin source, and membership flags for all three variants.
   - `legacy_pre3day_v1` must explicitly list the original 16 files, not rediscover whatever happens to be under the archive root later.
   - `campaign_3day_increment_v1` must explicitly list the 143 campaign truth files.
   - `expanded_post3day_v2` must be the verified, duplicate-free union of the other two sets.
   - Assert that the legacy and increment file sets are disjoint and that `Expanded-3Day = Legacy-16 union 3-Day Campaign Increment`.

4. **Provide one-command reruns.**
   - Add a variant-aware entry point with this intended calling convention:

```matlab
legacy = runADSBDatasetVariantEvaluation("legacy_pre3day_v1");
increment = runADSBDatasetVariantEvaluation("campaign_3day_increment_v1");
expanded = runADSBDatasetVariantEvaluation("expanded_post3day_v2");
comparison = runStage4BPostCampaignMotionDiversityGate;
```

   - Resolve source files from the version manifest, never from unconstrained directory discovery.
   - Write each run to a separate immutable output folder:

```text
artifacts/stage4BPostCampaign/legacy_pre3day_v1/
artifacts/stage4BPostCampaign/campaign_3day_increment_v1/
artifacts/stage4BPostCampaign/expanded_post3day_v2/
artifacts/stage4BPostCampaign/comparison/
```

   - Preserve the existing `artifacts/stage3C/` result as historical evidence; do not overwrite it.
   - Allow Stage 4A to receive the explicit `Expanded-3Day` Stage 3C artifact path and write refreshed outputs to the versioned folder.

### Reproducibility Check Against The Previous Run

Before interpreting new data, rerun `Legacy-16` through the variant-aware path and require:

- 16 usable sessions and 16 source files;
- 15,013 one-step pairs and 222 session/aircraft tracks;
- 350 constturn-like and 336 sparse-update pairs;
- 4,919 climb and 4,374 descent pairs;
- native `constvel` position RMSE approximately 23.870 m; and
- frozen Stage 3A MLP position RMSE approximately 151.260 m.

Material disagreement means the import, thresholds, source membership, or frozen model changed. Stop and resolve that before comparing `3-Day Campaign Increment` or `Expanded-3Day`.

### Motion-Heterogeneity Evaluation

Keep the existing pair-level labels for backward compatibility, but do not treat adjacent pair count as independent evidence. Evaluate all three variants at five levels:

1. **Continuous motion distributions**
   - Horizontal speed and altitude.
   - Absolute turn rate, with bins `<0.5`, `0.5-1`, `1-3`, and `>=3` deg/s.
   - Absolute horizontal acceleration, with bins `<0.1`, `0.1-0.5`, `0.5-1`, and `>=1` m/s^2.
   - Vertical rate, climb/descent status, and vertical acceleration.
   - Update interval, with bins `<0.75`, `0.75-2`, `2-5`, `5-15`, and `15-30` seconds.

2. **Independent maneuver events**
   - Segment contiguous rows within each `(sessionID, hex)` track.
   - Define sustained turn and acceleration events as at least three consecutive qualifying pairs spanning at least two seconds.
   - Define sustained climb and descent events as contiguous qualifying segments spanning at least ten seconds.
   - Treat sparse updates as separate gap events rather than multiplying their evidence by neighboring regular samples.
   - Report event count, duration, peak magnitude, unique ICAO count, session count, and 24-hour campaign-block count.

3. **Joint-regime coverage**
   - Cross turn intensity, acceleration intensity, vertical status, and update regime.
   - Show both raw pair occupancy and independent event/track occupancy.
   - Identify empty or nearly empty combinations rather than collapsing everything into `mixed_or_sparse`.

4. **Contributor diversity and concentration**
   - Report unique ICAO addresses, session/aircraft tracks, sessions, UTC dates, and three 24-hour campaign blocks.
   - For every critical regime, report the contribution share from the largest aircraft, session, and time block.
   - Report how many aircraft and sessions contribute at least one sustained event; a single prolific aircraft must not make a regime appear well covered.

5. **Prospective train/validation/test support**
   - Audit both an aircraft-disjoint grouping and a chronological blocked grouping.
   - Keep every ICAO wholly within one aircraft-disjoint split.
   - Keep complete sessions and contiguous time blocks together.
   - Require motion-regime support in train, validation, and test before freezing a final split.
   - Compute normalization only from the future training partition.

The comparison report must show `Legacy-16`, `3-Day Campaign Increment`, `Expanded-3Day`, and the named increment `Expanded-3Day minus Legacy-16` side by side.

### Robust-NN Readiness Decision

Produce two separate verdicts:

1. **Local gated retraining readiness** asks whether `Expanded-3Day` can support a better local-receiver NN experiment.
2. **Broad generalization readiness** asks whether the data support claims across receiver locations, collection geometries, traffic mixes, or data sources.

Provisional minimum gate for **local gated retraining readiness**:

- All source files are classified; no unexplained parse failures or conflicting duplicate sessions remain.
- At least 95% of truth-bearing campaign files produce usable state pairs.
- Sustained turn and acceleration each have at least 30 events from at least 10 unique ICAO addresses across all three 24-hour campaign blocks.
- Sustained climb and descent each have at least 50 events from at least 15 unique ICAO addresses across all three campaign blocks.
- Sparse-update coverage has at least 100 gap events from at least 20 session/aircraft tracks across all three campaign blocks.
- No single ICAO contributes more than 20% of any critical maneuver regime, and no one campaign block contributes more than 60%.
- Both proposed split strategies retain every critical motion regime in train, validation, and test, with at least five independent rare-regime events in validation and test.
- The expanded dataset adds independent motion events and occupied joint-regime cells, not merely more constvel-like pairs.

If these pass, the result is **ready for a local gated retraining experiment**, not proof that the new NN will beat `constvel`.

The **broad generalization** verdict must remain false unless the evaluated data also include independent receiver geometry or a genuinely separate source/collection domain. Three days from one Pi/receiver location can improve local motion diversity but cannot alone justify broad deployment claims.

### Required Outputs

- Dataset-version manifest and a human-readable variant summary.
- Version-aware evaluation entry point and focused helpers.
- Separate Stage 3C-style artifacts and reports for all three variants.
- One comparison report answering the robustness question directly.
- Minimum figures:
  - old/increment/expanded counts and percentages by motion regime;
  - continuous motion and `dt` distributions;
  - independent maneuver events and contributor concentration;
  - joint-regime occupancy;
  - prospective split coverage; and
  - frozen Stage 3A MLP versus native `constvel` by variant and regime.
- Updated Stage 4A outputs driven explicitly by `Expanded-3Day`.
- Focused integration, variant-membership, event-segmentation, split-leakage, and regression tests.
- Updated `concepts.md` entry when the workflow is implemented.

### Acceptance Checks

- Integration never overwrites a nonidentical session and leaves the transfer ZIP untouched.
- All new manifests preserve the receiver origin and campaign identity.
- The one no-gzip window is retained in campaign provenance but excluded from truth scoring.
- Variant membership is explicit, hash-validated, and stable across reruns.
- `Legacy-16` reproduces the prior Stage 3C counts and metrics within documented tolerance.
- `Expanded-3Day` equals the duplicate-free union of the legacy and increment variants.
- The same maneuver thresholds and frozen Stage 3A model are used for all three comparisons.
- Readiness uses independent events and contributor/split diversity, not pair totals alone.
- No neural training occurs during this gate.
- Code Analyzer is clean for changed MATLAB files.
- Existing Stage 3B, Stage 3C, Stage 4A, and Stage 4B tests remain passing alongside the new focused tests.

### Stage 4B-Post Outcome

Implementation completed on 2026-08-26:

- The transferred ZIP hash matched `BE2457298D38768DB950BF0A2EE15DBE5B5264B8532220F4AD6E44B4DA56AF3C`.
- All 144 packaged sessions were integrated into the append-only archive. The 143 truth files and 288 log files matched their manifests; `w133` was retained as the one expected no-truth session.
- Dataset membership is frozen by relative path and SHA-256 in `adsb_archive/datasetVersions/adsbDatasetVariants.csv`: 16 Legacy-16 files, 143 3-Day Campaign Increment files, and 159 Expanded-3Day files.
- Legacy-16 reproduced 16 usable sessions, 15,013 pairs, 222 session/aircraft tracks, 23.870 m native `constvel` position RMSE, and 151.260 m frozen-MLP position RMSE.
- The 3-Day Campaign Increment produced 138 usable sessions from 143 truth files, 442,890 pairs, and 2,933 session/aircraft tracks. Five truth files parsed without error but produced no usable state pairs.
- Expanded-3Day produced 154 usable sessions, 457,903 pairs, and 3,155 session/aircraft tracks. Its native `constvel` position RMSE was 24.520 m, while the unchanged frozen Stage 3A MLP was 211.710 m.
- Expanded-3Day contains 1,276 sustained-turn, 7,588 sustained-acceleration, 1,841 sustained-climb, 1,478 sustained-descent, and 15,036 sparse-gap events. Every critical event type spans all three 24-hour campaign blocks.
- The largest single-aircraft contribution to any critical event regime is 1.6%, and the largest campaign-block contribution is 46.6%.
- Aircraft-disjoint and chronological blocked split audits retain every critical event type in train, validation, and test with at least five validation and test events.
- All approved local gated-retraining checks pass. This authorizes proposing a separate local-receiver retraining milestone; it does not demonstrate that the frozen MLP beats `constvel`.
- Broad-generalization readiness remains false because the added data come from one receiver location and one local collection domain.
- No neural training was performed during Stage 4B-Post.
- Final verification passed 33 focused and regression tests across Stage 3B, frozen Legacy-16 Stage 3C, Stage 4A, Stage 4B, and Stage 4B-Post. The Stage 3C regression now selects the frozen Legacy-16 manifest explicitly so later append-only archive growth cannot change its historical test dataset. MATLAB Code Analyzer reported no issues in the 14 changed MATLAB implementation and test files.

Primary outputs:

- `adsb_archive/datasetVersions/adsbDatasetVariants.csv`
- `artifacts/stage4BPostCampaign/comparison/stage4BPostCampaignMotionDiversityReport.md`
- `artifacts/stage4BPostCampaign/comparison/stage4BPostCampaignMotionDiversity.mat`
- `artifacts/stage4BPostCampaign/<variant>/`
- `artifacts/stage4BPostCampaign/expanded_post3day_v2/stage4A/`

### Stage Boundary

If local gated retraining readiness passes, propose a new, separately approved training milestone with a frozen dataset manifest and split manifest. Stage 4C-Retrain was subsequently approved as that separate milestone.

If it fails, report the exact missing motion regimes, contributors, or split cells and recommend the smallest targeted collection needed.

## (completed) Stage 4C-Retrain: Expanded-3Day Exploratory Mean-MLP Training

Stage 4B-Post authorized one local exploratory retraining experiment. This
stage does not promote a model or support broad-generalization claims.

Implementation:

- Use `runStage4CRetrainExpandedADSBMLP` as the entry point.
- Preserve the memoryless 20–64–64–6 ReLU MLP and normalized six-state
  delta-MSE objective through MATLAB `trainnet`.
- Keep ICAO out of the 20 network features. Use it only to apply the frozen
  `adsb_archive/datasetVersions/expandedPost3DayICAODisjointSplit_v1.csv`
  assignment.
- Use all 457,903 Expanded-3Day pairs:
  - Train: 277,959 pairs and 1,188 ICAOs.
  - Validation: 86,420 pairs and 395 ICAOs.
  - Test: 93,524 pairs and 395 ICAOs.
- Ignore the inherited smoke split because 394 ICAOs occur in more than one
  inherited partition.
- Compute feature and target normalization from the new training partition
  only.
- Train one scratch candidate and one warm-start control. Rebase the warm
  control's first and output affine layers so its physical predictions are
  unchanged under the new input/target normalization, then start Adam with
  fresh optimizer state.
- Use seed 123, CPU execution, Adam learning rate `1e-3`, L2 `1e-4`, batch
  size 1024, at most 50 epochs, validation once per epoch, patience 8, and
  the best-validation output network.
- Run a 128-row tiny-overfit check before either full-data training run.

Model identities and outputs:

- `legacy_stage3a_v1`: frozen
  `artifacts/stage3/localADSBMLPStage3Training.mat`, never overwritten.
- `expanded_scratch_mean_v1`:
  `artifacts/stage4CRetrain/expandedPost3DayScratchMeanMLP_v1.mat`.
- `expanded_warm_mean_v1`:
  `artifacts/stage4CRetrain/expandedPost3DayWarmStartMeanMLP_v1.mat`.
- Compact comparison evidence:
  `artifacts/stage4CRetrain/expandedPost3DayMeanMLPComparison_v1.mat`,
  `stage4CRetrainMetricComparison.csv`, and
  `stage4CRetrainExpandedADSBMLPReport.md`.

Evaluation:

- Compare native `constvel`, frozen Stage 3A, scratch, and warm predictions
  on identical untouched validation and test rows.
- Report position and velocity RMSE, median, and P95 for constvel-like,
  acceleration, turn, mixed/sparse, climb, descent, level, regular-update,
  and sparse-update regimes.
- Report both pair-weighted metrics and independent-event-weighted metrics.
  An independent event is a contiguous run within one session/ICAO track
  and one reported regime.
- Plot training curves and representative held-out trajectories.
- Report success or failure directly without promoting either candidate.

Verification:

- Require exact dataset membership, all 159 source hashes, dataset/split
  hashes, one split per ICAO, train-only normalization, and no identity
  feature.
- Require physical-prediction equivalence after warm-start rebasing.
- Require finite tiny-overfit and one-epoch scratch/warm smoke results.
- Require distinct output paths and an unchanged Stage 3A SHA-256 digest.
- Run Stage 3A, Stage 3B, and Stage 4B-Post regressions plus MATLAB Code
  Analyzer.

Deferred:

- Twelve-output mean-plus-variance training, recurrent/history models,
  hyperparameter sweeps, deployment, multi-step rollout, covariance
  calibration, and broad-generalization claims.

### Stage 4C-Retrain Outcome

- The frozen split contains 277,959 training, 86,420 validation, and 93,524
  test pairs across 1,188/395/395 globally disjoint ICAOs.
- All 159 Expanded-3Day source files matched the frozen source manifest and
  SHA-256 digests. The dataset, split manifest, and original Stage 3A
  artifact hashes are recorded in both model artifacts.
- The warm-start affine rebase preserved physical predictions to
  `2.98e-4` maximum absolute state difference on 512 checked rows.
- The 128-row tiny-overfit loss decreased from `0.693553` to `0.091436`.
- Scratch stopped after 47 epochs on validation patience; its best
  normalized validation delta MSE was `0.624472`.
- Warm start stopped after 27 epochs on validation patience; its best
  normalized validation delta MSE was `0.626225`.
- On the untouched test partition, pair-weighted position RMSE was:
  - `constvel`: 23.303 m.
  - frozen `legacy_stage3a_v1`: 208.972 m.
  - `expanded_scratch_mean_v1`: 28.149 m.
  - `expanded_warm_mean_v1`: 27.469 m.
- Test velocity RMSE was 3.467 m/s for `constvel`, 3.547 m/s for frozen
  Stage 3A, 3.453 m/s for scratch, and 3.453 m/s for warm start.
- Both retrained models greatly improved on frozen Stage 3A and were
  essentially tied with `constvel` in velocity, but neither beat
  `constvel` in position. Neither model is promoted.
- The complete metric table includes pair-weighted and
  independent-event-weighted RMSE, median, and P95 for validation/test,
  maneuver class, vertical status, and update regime.
- Verification passed 25 focused tests: 3 Stage 3A, 4 Stage 3B, 10 Stage
  4B-Post, and 8 Stage 4C. MATLAB Code Analyzer reported zero issues in the
  seven new Stage 4C implementation/test files.

## (completed) Stage 4C-Native: Causal Maneuver-Baseline Extension

This evaluation-only extension tests whether native maneuver models improve
the Stage 4C comparison when they receive causal motion initialization from
the immediately preceding observation. It does not retrain or modify the
Stage 3A, scratch, or warm networks.

Implementation:

- Use `runStage4CNativeManeuverBaselineEvaluation` after the completed
  Stage 4C retraining run.
- Apply policy `raw_causal_finite_difference_v1`.
- Estimate raw 3-D acceleration as the velocity difference from the
  immediately preceding observation divided by its positive `dt`.
- Estimate native turn rate as the wrapped change in mathematical ENU
  heading divided by prior `dt`. MATLAB `constturn` receives this value in
  degrees per second.
- Require the predecessor to be temporally adjacent and in the same
  session, ICAO, and frozen split. Exclude first rows, temporal gaps,
  nonpositive prior intervals, split mismatches, and nonfinite inputs.
- Apply no clipping or smoothing.
- Build predictions before assigning retrospective truth-derived maneuver
  labels. Labels select evaluation slices only; ICAO remains a grouping and
  partition key.

Evaluation:

- Compare native `constacc`, `constvel`, frozen Stage 3A, scratch, and warm
  models on identical eligible `constacc_like` rows.
- Compare native `constturn` and the same four comparators on identical
  eligible `constturn_like` rows.
- Report pair-weighted and independent-event-weighted position/velocity
  RMSE, median, and P95.
- Extend the existing Stage 4C comparison MAT artifact, metric CSV, and
  report. Add one compact maneuver-baseline comparison figure.

Outcome:

- Frozen coverage exactly matched the approved counts:
  - Validation `constacc_like`: 16,896 / 17,030.
  - Validation `constturn_like`: 2,075 / 2,084.
  - Test `constacc_like`: 17,890 / 18,028.
  - Test `constturn_like`: 2,164 / 2,186.
- On test `constacc_like` rows, pair-weighted position RMSE was 8.524 m for
  `constacc` and 8.551 m for `constvel`; velocity RMSE was 1.104 m/s and
  1.013 m/s, respectively.
- On test `constturn_like` rows, pair-weighted position RMSE was 16.023 m
  for `constturn` and 14.388 m for `constvel`; velocity RMSE was 17.220 m/s
  and 15.370 m/s, respectively.
- The corresponding `constturn` median errors were lower than `constvel`
  (5.586 versus 6.090 m position; 0.783 versus 2.343 m/s velocity), but raw
  turn-rate spikes dominated RMSE.
- Test absolute turn-rate initialization had P99 8.278 deg/s, P99.9
  325.285 deg/s, and maximum 385.017 deg/s. These values remain unmodified
  in the primary comparison.
- No model is promoted. Bounded or smoothed causal initialization remains a
  future sensitivity study.

Primary files:

- `runStage4CNativeManeuverBaselineEvaluation.m`
- `helperBuildStage4CNativeManeuverBaselines.m`
- `helperScoreStage4CNativeManeuverModels.m`
- `helperWriteStage4CNativeManeuverFigure.m`
- `tests/Stage4CNativeManeuverBaselineEvaluationTest.m`
- `artifacts/stage4CRetrain/expandedPost3DayMeanMLPComparison_v1.mat`
- `artifacts/stage4CRetrain/stage4CRetrainMetricComparison.csv`
- `artifacts/stage4CRetrain/stage4CRetrainExpandedADSBMLPReport.md`
- `artifacts/stage4CRetrain/stage4C_native_maneuver_baseline_comparison.png`

## (completed) Stage 4C-Review: Unified Review Dashboard

The Stage Review Live Script now presents the completed Stage 4C evidence
without training or modifying frozen artifacts.

Native MATLAB audit for the configurable trajectory collections:

| Proposed workflow | Native MATLAB path | Update for this review |
| :--- | :--- | :--- |
| Deterministic event selection | `sortrows`, table indexing, `unique` | Reuse the existing longest-first event table and select its first `N` rows. |
| Frozen neural inference | `minibatchpredict` | Concatenate selected event rows for one call per network, then split predictions by event. |
| Geodetic trajectory display | `enu2geodetic`, `geoTrajectory`, `trackingGlobeViewer`, `plotTrajectory` | Pass one cell array per model so five calls draw `5N` paths, with truth last. |

Implementation:

- Load the frozen 457,903-row Expanded-3Day dataset and global
  ICAO-disjoint split.
- Cross-tabulate all four motion classes by train, validation, and test.
- Plot a primary 3-by-2 dashboard with motion class by row and
  position/velocity RMSE by column.
- On the primary dashboard, compare each class-aligned native model with
  the frozen Stage 3A legacy, Expanded scratch, and Expanded warm networks
  on matched held-out test rows only. “Test” identifies the evaluated
  partition; deterministic native algorithms are not trained or validated.
- Plot a separate 3-by-2 neural-only dashboard comparing validation and
  test RMSE for the three frozen networks.
- Preserve the original longest continuous test event for compatibility,
  and add `stage4CGlobeTrajectoryCount`, defaulting to 50, so each viewer
  can select the longest `N` eligible events for its motion class using the
  same deterministic session, ICAO, time, and dataset-row tie-breakers.
- Build each requested collection on demand, cap `N` at class availability,
  and report requested/plotted event, path, pair, session, and ICAO counts.
- Batch all selected rows through each frozen neural network, split the
  outputs back into continuous events, and validate test membership, motion
  class, native eligibility, strictly increasing time, and finite LLA.
- Convert local ENU positions with `enu2geodetic`, construct
  `geoTrajectory` objects, and open three independent
  `trackingGlobeViewer` windows through five model-batched
  `plotTrajectory` calls per viewer, with truth drawn last.
- Keep `enableInteractiveGlobe=false` as the automated/headless path.

Outcome:

- Split allocation is 277,959 train, 86,420 validation, and 93,524 test
  pairs; the motion-class cross-tabulation covers all 457,903 rows.
- Each class-specific request plots `min(N, eligible event count)` events
  and therefore five times that many paths: truth, its respective native
  model, `legacy_stage3a_v1`, `expanded_scratch_mean_v1`, and
  `expanded_warm_mean_v1`.
- The default is 50 events (250 paths) per viewer. Counts such as 100, 500,
  and 1,000 can be requested by changing the Live Script variable and
  rerunning only the desired viewer section.
- The original representatives remain available for compatibility and
  documentation: 176 `constvel_like`, 40 `constacc_like`, and 25
  `constturn_like` pairs, selected from 12,537, 10,340, and 1,242 eligible
  events, respectively.
- The primary RMSE figure contains 12 test rows: one class-aligned native
  model and three frozen neural models for each motion class. The
  neural-only figure contains 18 rows spanning both held-out splits.
- Paths are sequences of one-step predictions from observed states, not
  recursive forecasts or tracker outputs.
- No training, clipping, smoothing, or frozen-artifact mutation occurs.
- Verification passed 39 focused tests: 23 Stage Review, 8 Stage 4C native,
  and 8 Stage 4C retraining regressions. The Stage Review suite covers
  counts of 1, 50, 100, 500, and 1,000; deterministic ranking; class and
  eligibility checks; continuity, monotonic-time, and finite-LLA checks;
  capping above availability; invalid inputs; and headless Run All.
  Interactive 50-, 100-, 500-, and 1,000-event viewers were inspected.
  MATLAB Code Analyzer reported no issues in the five changed MATLAB files.
- The frozen model SHA-256 digests remained
  `2459D134...B906`, `941AFD71...F81F`, and `1999F972...FFE`
  for Stage 3A legacy, Expanded scratch, and Expanded warm, respectively.

Primary files:

- `stageReviewLiveScript.m`
- `helperBuildStage4CReviewDashboard.m`
- `helperBuildStage4CTrajectoryCollection.m`
- `helperPlotStage4CRMSEDashboard.m`
- `helperPlotStage4CNNValidationTest.m`
- `helperOpenStage4CReviewGlobe.m`
- `tests/StageReviewLiveScriptTest.m`

## (completed) Stage 4D: Frozen Warm-Model Characterization

Stage 4D treats `expanded_warm_mean_v1` as a frozen learned reference. It is
a standalone one-step predictor study, not a recursive tracker evaluation or
a promotion decision.

Implementation:

- Use `stage4DFrozenWarmCharacterizationLiveScript.m` as the standalone
  review entry point and `runStage4DFrozenWarmCharacterization.m` as the
  reusable computation entry point.
- Generate independent latent ENU truth with `kinematicTrajectory`.
- Run 21 canonical motion/profile cases, 100 ten-minute in-distribution
  mixed-motion trajectories, and 50 ten-minute out-of-distribution
  trajectories in full mode.
- Apply ideal, empirical-training-timing, and degraded noise/dropout
  observation profiles.
- Reconstruct all 887 contiguous frozen real test events under baseline,
  10 percent random dropout, 25 percent random dropout, and burst-outage
  profiles.
- Compare only the frozen warm model with native `constvel`, `constacc`, and
  `constturn`. Warm versus `constvel` is the same-information headline;
  causal acceleration and turn models are reported separately because they
  receive one predecessor.
- Score synthetic predictions against latent truth and real perturbations
  against the next retained ADS-B observation.
- Build one interactive `trackingGlobeViewer` collection for all seven
  canonical motions and a second for one selectable held-out ADS-B dropout
  event. Convert ENU positions with `enu2geodetic`, represent each path with
  `geoTrajectory`, and overlay input, scoring reference, warm, `constvel`,
  `constacc`, and `constturn` using six model-batched `plotTrajectory` calls.
- Keep globe generation optional for headless execution, but always expose
  the selected-view summary, legend, and trajectory validation tables in the
  Live Script.
- Write results only under
  `artifacts/stage4DFrozenWarmCharacterization/`.

Outcome:

- All 20 executable verification checks passed: deterministic generation,
  continuous and finite synthetic trajectories, monotonic times, exact
  frozen-test baseline reconstruction, matched comparison rows, leakage
  exclusions, separate outputs, and unchanged model integrity.
- The warm artifact remained
  `1999F972DBDABE67F45953C52CD4CDB1620F1FECF1716C075F391064D3B32FFE`
  before and after execution. No scratch or Stage 3A model was loaded.
- Full mode scored 638,010 same-information pairs across synthetic and real
  profiles in 51.1 seconds.
- On in-distribution synthetic trajectories with empirical timing, position
  RMSE was 58.598 m for warm and 43.598 m for `constvel`.
- On the frozen real baseline, position RMSE was 27.469 m for warm and
  23.303 m for `constvel`. The paired event-RMSE difference was
  10.668 m with a 95 percent interval of [9.689, 11.647] m.
- Causal native results remain contextual rather than headline comparisons.
  For example, real baseline `constturn` position RMSE was 16.039 m on its
  92,637 eligible predecessor-assisted rows.
- The Stage 4D decision is to retain `constvel` as the deployed prediction
  reference and not begin recursive warm-model or `trackingIMM` integration
  from this evidence.
- Both smoke and full benchmarks completed, and the new Live Script loaded
  the saved full result successfully in a headless run.
- The canonical degraded globe review produced seven motion trajectories and
  42 displayed paths; the held-out burst-outage review produced one event
  and six paths. Both passed finite-LLA, monotonic-time, and matched-count
  validation, and both native viewers opened successfully.
- All 51 focused and regression tests passed: 12 Stage 4D, 8 Stage 4C
  retraining, 8 Stage 4C native-baseline, and 23 Stage Review tests.
- MATLAB Code Analyzer reported no issues in the nine Stage 4D MATLAB files.
- `stageReviewLiveScript.m` and all Stage 4C artifacts were left unchanged.

Primary files:

- `stage4DFrozenWarmCharacterizationLiveScript.m`
- `runStage4DFrozenWarmCharacterization.m`
- `helperGenerateStage4DSyntheticBenchmark.m`
- `helperBuildStage4DRealDropoutBenchmark.m`
- `helperEvaluateStage4DPredictors.m`
- `helperPlotStage4DCharacterization.m`
- `helperBuildStage4DGlobeReview.m`
- `helperOpenStage4DGlobe.m`
- `tests/Stage4DFrozenWarmCharacterizationTest.m`
- `artifacts/stage4DFrozenWarmCharacterization/stage4DFrozenWarmCharacterizationResults.mat`

## (completed) Stage 4E: Recursive Filter Evaluation

Stage 4E asks what changes when one-step predictors become complete recursive
estimators. In plain language, each filter carries its last estimate forward,
uses an available position report to correct that prediction, and coasts on
growing uncertainty when a report is missing.

Implementation:

- Use `stage4ERecursiveFilterEvaluationLiveScript.m` as the review entry point
  and `runStage4ERecursiveFilterEvaluation.m` as the reusable computation
  entry point.
- Compare position-updated native CV, CA, and CT `trackingEKF` estimators, a
  native three-model `trackingIMM`, and a `trackingUKF` whose state transition
  is the unchanged `expanded_warm_mean_v1` network.
- Tune process-noise and IMM transition properties with
  `trackingFilterTuner` on three validation events of at most 120 pairs each.
  Freeze the resulting artifact before any test scoring; do not retrain the
  network.
- Evaluate matched timestamps, position measurements, update masks, scoring
  rows, and physical six-state initialization for every filter.
- Score 48 full-mode synthetic sequences against latent `kinematicTrajectory`
  truth and 40 held-out ADS-B events under baseline, 10 percent random
  dropout, 25 percent random dropout, and burst-outage profiles.
- Reserve every fifth real ADS-B report beginning with the third for scoring
  before dropout is applied. These reports never correct a filter, so the
  real result remains an ADS-B scoring proxy rather than independent truth.
- Report prior/posterior position and velocity error, synthetic NEES and
  coverage, NIS, event win rate, error versus correction age, recursive
  runtime, input integrity, and optional `trackingGlobeViewer` paths.
- Keep smoke-mode real events bounded to 240 pairs for practical regression
  testing; full mode retains the complete selected events.

Outcome:

- All 17 executable integrity checks passed, including identical inputs and
  tolerance-equivalent initialization, scheduled corrections, reserved score
  rows, deterministic dropout, finite states, positive-definite covariance,
  validation-only frozen tuning, no neural training, and unchanged warm-model
  SHA-256.
- On degraded canonical synthetic truth, native IMM achieved 81.436 m
  posterior position RMSE, followed by CA EKF at 94.160 m, CT EKF at
  116.120 m, CV EKF at 122.190 m, and frozen-warm UKF at 399.620 m.
- On the held-out ADS-B baseline scoring proxy, native IMM achieved 11.616 m
  posterior position RMSE, followed by CT EKF at 20.118 m, CV EKF at
  20.990 m, CA EKF at 27.389 m, and frozen-warm UKF at 239.390 m.
- Each model executed 117,010 recursive predictions. Measured time per
  prediction was 112.1 microseconds for CV EKF, 124.9 for CA EKF, 165.4 for
  CT EKF, 1,428 for native IMM, and 8,505 for frozen-warm UKF.
- Replacing repeated tiny-batch `minibatchpredict` calls with direct
  `predict` preserved output within `2.27e-13`, made the transition call
  4.09 times faster, and reduced the Stage 4E test runtime from 247 seconds
  to 75 seconds.
- The verified full run completed in 1,226.9 seconds. The native IMM is the
  strongest tested recursive estimator; the frozen-warm UKF is not promoted.
- The result does not evaluate association, clutter, confirmation, deletion,
  GNN, JPDA, or passive-radar detection performance.

Primary files:

- `stage4ERecursiveFilterEvaluationLiveScript.m`
- `runStage4ERecursiveFilterEvaluation.m`
- `helperTuneStage4EFilters.m`
- `helperInitializeStage4EFilter.m`
- `helperEvaluateStage4ESequences.m`
- `helperStage4EWarmTransition.m`
- `helperPlotStage4ERecursiveEvaluation.m`
- `helperBuildStage4EGlobeReview.m`
- `helperOpenStage4EGlobe.m`
- `tests/Stage4ERecursiveFilterEvaluationTest.m`
- `artifacts/stage4ERecursiveFilterEvaluation/stage4ERecursiveFilterEvaluationResults.mat`

## Assumptions

- No code or data collection starts during Stage 1.
- Stage 1 may use web search and GitHub review.
- MATLAB-native Sensor Fusion and Tracking Toolbox motion/measurement functions remain the preferred comparator path unless a later gate identifies a clearly better reusable implementation.
- The first learned model is a prediction-step replacement, not a full Kalman filter update replacement.
- Full measurement-update replacement is deferred until the prediction-step experiment is successful.
- The first checked-in planning artifact can be a Markdown memo unless a different artifact format is requested.

## Council Review Of Stage 1

This section preserves the original council-review rationale. The specific first-experiment choice is superseded by the Stage 1 outcome and owner review correction above: start with a simple neural prediction-step replacement using Sensor Fusion state ordering and `constvel`/`constveljac` comparators.

### Consensus Strengths

- The Stage 1 structure is sound: it separates papers, code, datasets, and MATLAB/toolbox resources, and it requires an engineering recommendation rather than a bibliography.
- The "state/filter role" field is important and should be preserved. It prevents mixing trajectory-only prediction, learned filter components, uncertainty calibration, and association methods into one vague "neural Kalman" category.
- The staged gate is appropriate: no data acquisition, NN design, or implementation should begin until the literature/resource review has produced a justified reuse recommendation and a Stage 2 direction.
- MATLAB-native baselines are correctly included early, which keeps the project grounded in reproducible classical filtering before introducing learned components.

### Neural Filtering Expert Feedback

- Make the Stage 1 search more systematic around learned uncertainty and hybrid filters. Add search terms such as `KalmanNet`, `KalmanNetNN`, `RTSNet`, `DANSE`, `Deep Variational Bayes Filter`, `Recurrent Kalman Network`, `Differentiable Kalman Filter`, `Neural State Space Model`, `Deep Markov Model`, `learned process noise`, `learned measurement noise`, `covariance calibration`, `innovation-based adaptive estimation`, `neural IMM`, and `maneuver-aware filtering`.
- Require the review to distinguish three categories: neural predictor, neural filter component, and uncertainty-calibrated learned estimator.
- Require at least 5 resources that directly modify or augment a Kalman-style estimator, not only standalone trajectory predictors.
- Classify every candidate by training target: next state, innovation, gain, covariance/noise, residual correction, association, or uncertainty calibration.
- Watch for papers trained only on toy or synthetic systems. They may not transfer to irregular ADS-B sampling, sparse updates, dropped messages, and maneuver changes.

### Aviation And ADS-B Trajectory ML Expert Feedback

- Add aviation-specific search terms: `ADS-B trajectory prediction`, `aircraft trajectory prediction`, `4D trajectory prediction`, `flight trajectory forecasting`, `ETA prediction`, `intent prediction`, `aircraft maneuver prediction`, `climb cruise descent prediction`, `terminal area trajectory prediction`, `TMA trajectory prediction`, `en-route trajectory prediction`, `trajectory uncertainty prediction`, `flight phase recognition`, `Mode S`, `OpenSky Network`, `ASTERIX`, `Eurocontrol DDR`, `FAA SWIM`, and `NAS trajectory prediction`.
- Include aviation dataset/resource classes: OpenSky Network historical state vectors, OpenSky challenge datasets, Mode S decoded datasets, terminal-area ADS-B collections, weather-joined trajectory datasets, aircraft performance databases such as BADA/OpenAP, and route/waypoint/navigation databases.
- Review aviation model classes beyond generic sequence models: intent-aware prediction, physics-informed trajectory prediction, hybrid aircraft-performance plus ML models, uncertainty-aware forecasting, multi-agent air traffic graph models, trajectory clustering before prediction, flight-phase-conditioned models, irregular-sample handling, and domain adaptation across airports/airspaces.
- Make data diversity part of the Stage 1 gate. Raw message count is not enough; the review should consider flight phase, aircraft type, sampling interval, turns, climbs/descents, time of day, weather if available, and missing-message patterns.
- Keep association-heavy methods separate unless a later stage explicitly decides to study degraded identity, spoofing, or fused-sensor ambiguity.

### Open-Source And Dataset Reproducibility Expert Feedback

- Add explicit code-resource review fields: license compatibility, citation requirements, last commit date, maintainer activity, issue health, framework/version support, dependency lockfile or environment file, Docker/Conda availability, training/evaluation scripts, pretrained weights, seeds, splits, published metrics, hardware/runtime requirements, and MATLAB portability.
- Add explicit dataset review fields: data license, redistribution rights, access friction, included fields, geographic coverage, time span, aircraft diversity, traffic density, sampling consistency, missing-message behavior, sensor/source provenance, filtering/censoring/outlier issues, duplicate handling, and train/test leakage risks.
- Add a reproducibility score for top candidates: `directly runnable`, `repairable`, `concept only`, or `not usable`.
- Require at least 3 candidate repos to be assessed for actual runnability, not just relevance, and at least 2 datasets to have license/access confirmed.
- Require a short exclusion log for tempting but unsuitable resources, with reasons such as no uncertainty output, no code, proprietary data, unrealistic sampling, toy-only evaluation, or no aircraft maneuver relevance.
- Do not overvalue GitHub stars. Popularity does not imply a usable or reproducible implementation.

### MATLAB And Sensor Fusion Expert Feedback

- Treat MathWorks resources as first-class review items, not a catch-all category. Include `constvel`, `constveljac`, `cvmeas`, `cvmeasjac`, `trackingEKF`, `trackingUKF`, `trackingIMM`, `trackerGNN`, `trackerJPDA`, `trackerTOMHT`, `trackOSPAMetric`, `trackCLEARMetric`, `trackErrorMetrics`, `lstmLayer`, `gruLayer`, `transformerEncoderLayer`, and `trainnet`.
- Review baseline suitability using engineering criteria: state vector, coordinate frame, sample interval assumptions, missing-update handling, covariance availability, online operation, multi-aircraft scalability, uncertainty output, and MATLAB implementation path.
- Add at least three directly comparable baseline candidates to the Stage 1 gate: one classical MATLAB-native filter, one simple sequence model, and one neural-Kalman-style candidate.
- Do not compare cleaned-track trajectory prediction results directly against online filtering results unless measurement timing, update cadence, and uncertainty handling are aligned.
- Avoid choosing a complex Transformer first unless Stage 1 shows that the available pilot dataset will be large and diverse enough. Owner review narrows the first experiment further: use a simple MLP prediction-step replacement before considering GRU/LSTM/TCN residual learners or full neural-filter architectures.

### Recommended Stage 1 Gate Revisions

- Replace the simple count gate with a balanced evidence gate: at least 5 neural/Kalman resources, 5 aviation trajectory prediction resources, 3 aviation datasets or data sources, 3 code implementations, and 3 MATLAB/toolbox resources.
- Keep the existing "15 relevant resources" target as a minimum, but require the balance above where possible.
- Add an evidence grade per resource: direct ADS-B evidence, aircraft trajectory but not ADS-B, generic tracking transferable, or background only.
- Add review-matrix fields for prediction horizon, split strategy, real vs simulated data, metrics, uncertainty support, reproducibility score, license/access status, and MATLAB integration burden.
- Require a final downselect table with: candidate, why it matters, blocking assumptions, MATLAB implementation path, expected data needs, and recommended Stage 2 experiment.
- Require the Stage 1 memo to end with a defensible short list: one MATLAB-native baseline path, one first NN model family, one candidate public dataset path, and one fallback if no existing repo is reusable.

### Council Pitfalls To Carry Forward

- Many aircraft trajectory papers predict future cleaned positions but do not implement an online filter update or calibrated covariance.
- Learned Kalman gain methods may look attractive but can fail under distribution shift, irregular sampling, missing messages, and maneuver-heavy segments.
- ADS-B data can contain latency, quantization, bad altitude fields, duplicates, ground/airborne transitions, and uneven sampling.
- Public datasets may not match the local receiver geometry, local traffic mix, or planned collection schedule.
- A learned model that improves position RMSE can still be worse for tracking if uncertainty is poorly calibrated.
- The Stage 1 review should not reintroduce the excluded ADS-B-as-truth workflow category. The focus remains learned state estimation, aircraft trajectory modeling, reusable code/datasets, and MATLAB-native baselines.

## Council Review Of Stage 2B

This review evaluates the Stage 2B local ADS-B plan after the successful OpenSky probe and owner decision to make local ADS-B the primary data path. The council consensus is that Stage 2B is feasible for a single implementation agent if it remains tightly scoped to dataset construction, baseline comparison, and smoke training.

### MATLAB And Sensor Fusion Reviewer

- Keep the implementation MATLAB-native because the expected final deliverable is MATLAB-based and may become a MATLAB example.
- Reuse `loadADSBTruth`, `table`, `timetable`, `wgs84Ellipsoid`, `geodetic2enu`, `constvel`, and `constveljac` before adding any custom machinery.
- Keep Stage 2B prediction-only. `cvmeas` and `cvmeasjac` remain measurement functions and must not enter this stage's training target.
- The state-order invariant `[x; vx; y; vy; z; vz]` should be tested explicitly because a silent ordering error would invalidate all training and baseline results.

### ADS-B Data Reviewer

- The verified `20260622T102123` truth file is sufficient for parser, artifact, baseline, and training-code smoke tests.
- The same file is not sufficient for final model-quality claims because it is one local session with limited traffic diversity.
- `ADSB_GPS` currently contains logger scripts and NMEA logs, not parseable SBS-1 ADS-B training logs. The next agent should not spend time trying to train from those NMEA files.
- Additional local ADS-B sessions should be collected before any claim that the NN improves over `constvel` in a general way.

### Neural Filtering Reviewer

- A simple MLP with diagonal covariance output is the right first neural model because it tests the prediction-step interface without introducing sequence-model or full-covariance complexity.
- Use diagonal Gaussian negative log likelihood for smoke training, but treat calibration metrics from the single smoke file as software checks rather than scientific evidence.
- Defer recurrent models, learned Kalman gains, residual filters, full covariance Cholesky output, and multi-step rollout until the one-step dataset and baseline path are stable.
- Positive diagonal covariance via `softplus(rawVariance) + epsilon` is a sufficient PSD-safe parameterization for this stage.

### Dataset And Reproducibility Reviewer

- The dataset artifact needs more than state arrays. It must also save normalization constants, source manifest, split manifest, build summary, and `constvel` baseline metrics so results are repeatable.
- Normalization constants must be computed from the training split only, even in smoke tests, to avoid baking leakage into the implementation pattern.
- Split metadata is required even for the single-session smoke test because the same code path should scale to later multi-session training.
- Raw SBS-1 logs should remain unchanged; all derived data should be written to new MATLAB artifacts.

### Single-Agent Scope Reviewer

- Stage 2B is achievable by one agent if limited to local file discovery, state-pair dataset building, `constvel` baseline metrics, and a few-epoch MLP smoke test.
- Hardware collection, OpenSky expansion, hyperparameter sweeps, final model-quality evaluation, full covariance output, and measurement-update work should be treated as explicit non-goals.
- Acceptance should be binary and software-oriented: build at least 1,000 usable pairs from the verified local file, write the required artifacts, run the baseline, and complete finite-loss smoke training.

### Council Recommendation

Proceed with Stage 2B as a MATLAB-native smoke implementation. The next agent should not optimize the neural model or collect new data until the dataset artifact, manifests, `constvel` baseline metrics, and MLP smoke-training path all work end to end on the existing local truth file.






