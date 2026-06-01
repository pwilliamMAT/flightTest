Your primary goal is to assist in developing a passive radar signal processing chain in MATLAB. A critical secondary goal is to make this process educational. For each new signal processing step, you must:

1.  First, explain the concept in plain language.
2.  **Prioritize using functions from the Phased Array System Toolbox, Radar Toolbox, and Signal Processing Toolbox** over custom implementations. The goal is to demonstrate a workflow that leverages these powerful, pre-built tools.
3.  Implement the concept with heavily commented MATLAB code that explains both the "what" and the "why" of the chosen toolbox functions.
4.  Add visualization steps (plots, graphs) to show the effect of the processing.
5.  Update the `concepts.md` file. This file serves as a running index. For each new concept, you must add an entry that maps the concept name to the file where it is implemented, providing a clear concept-to-file index.
6.  Always verify the successful execution of each step before proceeding to the next.

---

## Next Session: ADS-B Truth Incorporation

### Objective
Obtain ADS-B truth data for the Natick May 21 2026 radar collection window and use it to quantitatively validate the tracker output against known aircraft trajectories.

### Context for the Incoming Agent

**Dataset**: `/Users/pwillie822/MCPServer/FlightTest_RadSigProc/04_Natick_Ah_Pkg_May_21_26/`  
**Radar collection window**: 2026-05-21 **19:26:50–19:27:29 UTC** (file header timestamps are local EDT = UTC−4; i.e., 15:26–15:27 local = 19:26–19:27 UTC).  
**Tx**: CBS Tower Newton MA, 599 MHz ATSC. **Rx**: Parking garage, 4 Apple Hill Dr Newton MA.

**What has been done (all functions implemented and tested):**

| Function | File | Status |
|---|---|---|
| Parse SBS-1/BaseStation ADS-B | `loadADSBTruth.m` | ✅ Fixed (`CollapseDelimiters,false`) |
| Extract radar epoch from filename | `getRadarEpoch.m` | ✅ Handles `YYYYMMDDHHMMSS` format |
| Project ADS-B to bistatic R/f_D | `adsbToBistatic.m` | ✅ Central-difference Doppler |
| Align truth to radar time axis | `alignTruthToRadar.m` | ✅ UTC→radar-relative + interp1 |
| Compute TP/FA/miss + RMSE | `assessTruthVsDetections.m` | ✅ Tested (Pd=0.833 on synthetic data) |
| Plot truth vs radar tracks | `plotTruthComparison.m` | ✅ |
| §8 hook in main script | `analyzeBistaticData.m` §8 | ✅ Skips gracefully if no `adsb_files` |
| Unit test | `test_adsbTruthPipeline.m` | ✅ Passes 49/49 records |

**What is blocking truth incorporation:**  
No ADS-B file in the Natick dataset covers the 19:26 UTC window. The files inspected covered May 24–25 2026 (wrong days) or 18:20 and 20:03 UTC on May 21 (wrong time). Only 4 of 51 gz files were sampled — the remaining 47 were not opened.

### Step-by-Step Tasks for Next Session

**Step 1 — Scan ALL gz files for the target time window:**
```bash
for f in /Users/pwillie822/MCPServer/FlightTest_RadSigProc/04_Natick_Ah_Pkg_May_21_26/*.gz; do
    first=$(gunzip -c "$f" 2>/dev/null | head -1 | grep -o '[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\},[0-9:\.]*' | head -1)
    echo "$f  →  $first"
done
```
Target: any file showing `2026/05/21,1[5-9]:2[5-9]` (local) or compute based on UTC offset.

**Step 2 — If no local file found, query OpenSky Network:**  
Historical state vectors API:
```
GET https://opensky-network.org/api/states/all?lamin=42.0&lamax=42.6&lomin=-71.6&lomax=-71.0&time=<unix_timestamp>
```
Unix timestamp for 2026-05-21 19:26:50 UTC = `1748111210`. Query several 10-second windows. **Note**: OpenSky free tier provides historical data up to 1 hour for anonymous access; registered accounts get 30 days. May need registration.

Alternatively, use FlightAware AeroAPI v4 (paid, but MIT has institutional access): `GET /flights/search?query=-latlong "42.0 -71.6 42.6 -71.0" -start 2026-05-21T19:26:00Z -end 2026-05-21T19:28:00Z`.

**Step 3 — Once truth file is obtained, wire it into the script:**  
In `analyzeBistaticData.m` §1, add:
```matlab
config.adsb_files = { ...
    '/path/to/adsb_20260521_192600.txt'  ...  % or .gz — loadADSBTruth handles both
};
```
Run `analyzeBistaticData`. Section §8 will automatically call `loadADSBTruth → getRadarEpoch → adsbToBistatic → alignTruthToRadar → assessTruthVsDetections → plotTruthComparison`.

**Step 4 — Verify `getRadarEpoch` handles the Natick filename:**  
The filename `n320_599_8Msps_100ms_1` contains no date. `getRadarEpoch` needs either:
  - A `ManualEpoch` override: `getRadarEpoch(filename, 'ManualEpoch', datetime(2026,5,21,19,26,50,'TimeZone','UTC'))`, OR
  - The epoch baked into `config`: `config.radar_epoch_utc = datetime(2026,5,21,19,26,50,'TimeZone','UTC')` and §8 passes it to `getRadarEpoch`.
  
  Check `getRadarEpoch.m` to see which interface it currently expects. The `analyzeBistaticData.m §8` call is:  
  ```matlab
  t_epoch_utc = getRadarEpoch(data_parts{1});
  ```
  If the filename pattern doesn't match, it will return a fallback or error. Add `'ManualEpoch'` if needed.

**Step 5 — Validate Doppler sign against truth:**  
After running with truth, check the `assessTruthVsDetections` output:
- A track with **negative Doppler** in the RDM should correspond to an **approaching** aircraft (ADS-B range decreasing). If the signs are reversed, the −α fix in `initMeasurementSpaceKF` may need to be re-examined vs the sign in `adsbToBistatic`.
- `adsbToBistatic` computes Doppler as `f_D = (2fc/c) · ΔR_excess/Δt`. If ADS-B range is decreasing (approaching), this gives **negative** f_D — which is the **opposite** of what `createRDM.m` produces for the same aircraft. In that case, negate f_D in `adsbToBistatic` or negate the raw detections before passing to `objectDetection` in `trackTargets`.
- The ground truth is: check the aircraft's ADS-B velocity vs the sign of its RDM Doppler bin. Pick one aircraft, note whether it's heading toward or away from the Rx, and verify the RDM Doppler bin sign matches.

**Step 6 — Tune tracker parameters using truth feedback:**  
After truth is available:
- If `|ΔR_rms| > 2 × range_bin` (37.5 m) for confirmed tracks, the gate or process noise needs adjustment.
- If association rate < 70%, consider widening `AssignmentThreshold` from 50 → 100 or relaxing `R_meas`.
- If false tracks dominate, tighten `ConfirmationThreshold` from `[2,3]` → `[3,5]`.

### Key Constants for This Dataset

```matlab
config.fc  = 599e6;                    % CBS Tower, Newton MA
config.fs  = 8e6;                      % 8 Msps
config.txLLA = [42.310278, -71.236667, 431.9];
config.rxLLA = [42.2999333, -71.349333, 15.0];
config.inter_part_gap_s = 3.0;         % measured ~2.85 s avg (5.96 s for file 1→2)
% range_bin = c/(2*fs) = 18.75 m
% alpha = 2*599e6/3e8 = 3.993 Hz/(m/s)
% Doppler bin = 10 Hz (N_slow=200, T_cpi=0.5 ms)
% H(2,2) = -alpha  (passive CAF convention: positive f_D = approaching = Rdot < 0)
```

### Critical Bug Fixed This Session (Do Not Revert)

`initMeasurementSpaceKF.m` line `H(2,2) = -alpha` and `Rdot0 = -z0(2)/alpha` — the **negative sign** is correct for this passive-radar CAF implementation. If you see 100+ single-step tracks with σ_v ≈ 374 m/s unchanged from P₀, the sign has been reverted. See `checklist.md` session 2026-05-28 for the derivation proof.
