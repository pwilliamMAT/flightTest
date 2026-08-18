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
- (deferred) Stage 4C: Testing and verification. Do not start until refreshed Stage 4A plots show enough representative coverage for a real model-quality evaluation.

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

Stage 4B now implements a testing-machine ADS-B interval capture coordinator. New project code stays under `adsbForTracking/piCaptureCampaign/`; the operator runs it from the Ubuntu testing machine, it SSHes to the Raspberry Pi, starts bounded ADS-B-only windows through the existing Pi logger wrapper, fetches gzip truth logs with `scp`, and packages each window as `captures/<session_id>/` with `session_manifest.json` receiver-origin metadata.

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
| Manifest encoding concept | `jsonencode` | `jsonText = jsonencode(manifest)` |
| Post-campaign archive evaluation | Existing MATLAB Stage 3C scripts | `runStage3CArchiveADSBEvaluation` then `stage4ADSBTruthCapturePlanningLiveScript` |

Implemented artifacts:

- Script: `piCaptureCampaign/run_stage4_adsb_interval_campaign.sh`.
- Operator README: `piCaptureCampaign/README.md`.
- Test: `tests/Stage4BADSBIntervalCampaignScriptTest.m`.

Default campaign behavior:

- Runs 300 second ADS-B-only captures every 1800 seconds for 259200 seconds.
- Runs from the testing machine and defaults to Pi target `pi2@192.168.10.131` with workdir `/home/pi2/flightTest/ADSB_GPS`.
- Uses remote command `sudo -n bash start_adsb_gps_loggers.sh --adsb-only --adsb-session-id <session_id> --adsb-run-seconds <seconds>`.
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
- `--preflight-only` checks SSH, remote logger wrapper, remote `sudo -n`, `dump1090`, `python3`, local `scp`, and local write access before capture startup.
- A shell-level fake `ssh`/`scp` test verifies the expected remote command and the ADS-B-only packaged-session layout without contacting hardware.
- The operator README describes running from the testing machine and no longer instructs copying/running the coordinator on the Pi.

Manual testing-machine smoke test:

```bash
cd /path/to/flightTest
bash adsbForTracking/piCaptureCampaign/run_stage4_adsb_interval_campaign.sh --campaign-seconds 700 --capture-seconds 30 --interval-seconds 300 --max-windows 2
```

Post-campaign validation remains to sync packaged ADS-B-only sessions as needed, preserve `captures/<session_id>/session_manifest.json` with receiver LLA metadata, rerun Stage 3C, rerun Stage 4A, and check movement toward Pi-only holdout, metadata completeness, source diversity, targeted motion/update coverage, and passive-radar-relevant geometry.
## Stage 4C: Testing And Verification Skeleton

Do not begin until refreshed Stage 4A capture-readiness plots show enough representative coverage for a real model-quality evaluation.

Questions Stage 4C must answer:

- Does the learned prediction-step model beat or match `constvel` and `trackingEKF` prediction-only baselines on held-out aircraft and held-out days?
- Does it remain stable during multi-step rollout?
- Are covariance outputs positive semidefinite and calibrated?
- Does performance degrade gracefully across sparse ADS-B updates, irregular `dt`, turns, climbs/descents, and low-density traffic?
- What acceptance thresholds define success: RMSE reduction, consistency improvement, maneuver robustness, or runtime?
- What plots and reports are required for review?

Expected Stage 4C output:

- Test suite plan.
- Verification report template.
- Acceptance criteria tied to Stage 2 goals and Stage 3 model design.
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






