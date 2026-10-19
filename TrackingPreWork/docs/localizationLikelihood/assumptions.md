# Localization-likelihood assumptions and interpretation

Date: 2026-10-13. The configuration function is the executable source of changeable values. This document explains why the defaults are used and what the study can establish. Source status and conflicts are recorded in [repositorySurvey.md](repositorySurvey.md).

## Geometry and vertical datum

The maintained Apple Hill receiver is 42.299293°, -71.349500°, 25 m AGL. Maintained Newton is 42.310280°, -71.236670°, 315.468 m AGL; Hudson is 42.384083°, -71.493139°, 373.6848 m AGL. WLEK-LD is 42.531583°, -70.986222°, 137.16 m AGL. Cochesett is 42.010556°, -71.044444°, 149.0472 m AGL and is geometry only. The catalog Newton sensitivity changes only its horizontal location to 42.311389°, -71.216111°. It does not silently replace the maintained baseline.

The catalog labels coordinates NAD83. Their use as WGS84 horizontal coordinates is a POC approximation, not a surveyed datum transformation. Terrain elevation is MSL. The ENU conversion uses ellipsoidal height h = terrain MSL + antenna/aircraft AGL + geoid separation N, with the receiver antenna as origin. In the separately labeled fallback, terrain MSL is set to zero before the same vertical conversion; free-space propagation replaces Longley–Rice. Never combine cached terrain-aware and fallback arrays under one result label.

Each transmitter supplies one independent excess-range measurement: rho = rTx + rRx - baseline. The modeled errors are unbiased Gaussian with standard deviation 50 m, independent across transmitters. Sensitivities use 25 and 100 m. This assumed error is not derived from SNR, bandwidth, an ambiguity function, synchronization measurements, or observed aircraft data. Correlated timing/reference errors and model bias could materially reduce benefit.

The unconstrained model estimates East, North, and Up. The known-altitude comparison assumes receiver-centered local Up is exactly known at each test point. It retains true 3D slant ranges and removes only the Up Jacobian column. It is a local conditional uncertainty calculation, not a promise that an operational altitude source supplies exact Up or that constant terrain-relative altitude is a flat ENU surface. SVD rank deficiency means unobservable full position; no finite pseudoinverse covariance is displayed as full-position confidence. The condition limit applies to the whitened measurement Jacobian and is 10^4. Full rank is local and cannot rule out separate global ellipsoid-intersection solutions.

## Regions, thresholds, and summary statistics

The recovered northern ROI is the headline comparison: latitude 42.3082–42.5425°, longitude -71.5908–-71.0049°. The west corridor is reported separately: latitude 42.182143–42.416443°, longitude -71.849500–-71.349500°. Both use the same 0.02° geographic grid and the same altitude slices: 3000, 6000, 9000 ft AGL. The 6000 ft slice is the maintained baseline; the other slices are sensitivity cases. Geographic cell areas account for latitude and ROI intersection; percentages are area weighted. No volume is inferred from three slices.

An available range requires modeled SNR at least 13 dB. The threshold is motivated by the repository's detectability precedent, but applying it to range availability is a POC assumption. A useful cell additionally needs full rank, acceptable conditioning, and RMS error below 500 m horizontal for known Up or 1000 m total for 3D. These engineering cutoffs are study choices. Median and 95th-percentile uncertainty summarize valid positions and must be shown with valid-point counts, unobservable/failed counts, and coverage; statistics conditional on surviving positions alone cannot demonstrate broad usefulness.

At each point, recompute information using precisely the transmitters that pass the SNR gate. Report any-link coverage and measurement count separately from useful localization. Tx3 gains may reflect improved geometry, an extra usable constraint, or both. Newly useful cells with both baseline links supported are distinguished from those missing a baseline link without claiming mutually exclusive physical causes. With two scalar ranges, unconstrained 3D remains deficient even if both signals are strong.

## RF conventions

| Quantity | Default and rationale |
|---|---|
| Newton channel / horizontal ERP | RF35, 599 MHz, 1000 kW; maintained precheck baseline with documented site conflict |
| Hudson channel / horizontal ERP | RF27, 551 MHz, 400 kW; maintained precheck baseline |
| WLEK-LD channel / horizontal ERP | RF31, 575 MHz, 15 kW; repository catalog parameters and RabbitEars channel corroboration |
| Cochesett | RF10, 195 MHz reference only; no RF contribution to the recommended configuration |
| ERP to EIRP | EIRP = ERP × 10^(2.15/10); do not treat ERP as conducted power and then add an unrelated transmit gain |
| Radar-equation gains | Explicit [0, 12] dB transmit/receive gains with EIRP passed as power; 12 dBi receive gain is an assumed effective gain |
| RCS | Fixed 0.5 m² bistatic RCS; no aspect, frequency, or aircraft variation |
| Effective NF | 2.5 dB; total system noise temperature 290 × 10^(NF/10) K, including reference thermal noise |
| Bandwidth | 6 MHz; defines full-channel filter screening and input thermal-noise context |
| Equivalent observation interval | 5 microseconds, inherited from 1/200 kHz; no additional coherent-integration gain |
| Propagation | Longley–Rice minus free-space loss on each leg, evaluated at each link's carrier; native radar equation supplies spreading loss |
| Ranges | WGS84-derived receiver-centered ENU 3D slant distances |
| Antenna patterns | Constant effective gains and horizontal ERP; catalog directionality/tilt/polarization are not modeled patterns |

The `radareqsnr` energy-based output is an equivalent-observation SNR under the stated interval. Bandwidth must not be multiplied into an extra integration gain. A hand reference is EIRP × Gr × lambda² × RCS × tau / ((4*pi)^3 × rTx² × rRx² × k × Ts × loss), where gains/loss are linear. The included bandpass data screens candidate frequency compatibility; the full installed receive-chain response remains unresolved and must not be inferred from that component alone. Treat the effective NF as a configurable system approximation, rather than subtracting unverified front-end losses again without defining a new reference plane.

Historical maintained summaries and Report 01A use different frequencies, ERP assumptions, implicit radar-equation gains/noise, and power conversions. Preserve them as historical evidence; do not calibrate this POC to their numerical outputs. No modeled SNR is a measured echo or an operational probability of detection.

## Candidate screen and acquisition boundary

Deduplicate the repository's 29 catalog rows by exact recorded latitude/longitude, keep sites within 60 km, require less than 3 dB insertion loss throughout a full 6 MHz channel in the included +25°C S2P response, then maximize minimum bearing separation from maintained Newton/Hudson. The 60 km radius and 3 dB cutoff are preliminary study rules. WLEK has about 33.40° minimum separation and 39.50 km receiver distance. Its filter loss is 0.76995 dB at 575 MHz and approximately 0.77537 dB worst over RF31. Cochesett has stronger bearing separation (59.24°), but RF10 sees 56.82 dB loss at channel center. It is therefore retained solely to explain geometry, not as an RF-supported option. Channel/facility lookup was corroborated on RabbitEars on 2026-10-13; the repository's catalog site/height/ERP values remain the frozen geometric baseline.

**Hardware-acquisition caveat:** Realizing the modeled benefit requires simultaneous coherent acquisition and a suitable reference for each separate RF channel, with synchronized/calibrated measurements. The installed receive-chain response, optional high-pass filter, available channel count/bandwidth, reference quality, and timing integrity are unresolved. This POC does not qualify hardware or approve acquisition changes; its conclusions are conditional on the modeled RF support and measurement quality.

## Grid sampling and signed propagation sensitivity

Geographic weights are exact cell/ROI intersection areas, but each field value is sampled at the common cell center. A partial boundary cell can therefore contribute even when its center lies outside the ROI. The report discloses added center-inside counts and outside-center area. Additional 0.01° and 0.005° checks at 6000 ft bound this issue; their west-corridor estimates are not claimed converged.

The maintained Longley–Rice-minus-free-space convention is signed. Negative differences predict enhancement relative to the native slant-range radar equation. They are preserved explicitly, and a same-geometry zero-excess-loss SNR reference is reported. In the executed baseline, the few WLEK-supported cells depend on this enhancement near the receiver. They do not establish reliable physical localization opportunity without validating that propagation behavior.

## Provenance, repeatability, and exclusions

Cache keys must include all relevant geometry, terrain/datum mode, propagation, frequency, power/gain/noise/interval/RCS, and source/configuration metadata. Changing a relevant value must invalidate the corresponding cache. Cache-hit and fresh calculations require a focused equality check. Terrain access failure must be visible in the result metadata, figures, and report.

The study is a deterministic static opportunity map with focused synthetic/noise checks. It does not run the signal-processing pipeline, acquire IQ, produce detections, incorporate angle/Doppler measurements, associate measurements, fuse tracks, implement a tracker, or establish global position uniqueness. The schematic Logan approach is illustrative context only, not a recovered/approved flight route. Native MATLAB function checks verify implementation conventions; they do not independently validate uncertain physical inputs.
