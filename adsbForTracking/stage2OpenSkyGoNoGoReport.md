# Stage 2A OpenSky Go/No-Go Report

Generated: 2026-08-14 01:09:57 UTC

Scope: OpenSky current-state go/no-go probe only. No full Stage 2 dataset was built and no neural network was trained.

## Native MATLAB Path Used

- Retrieval: `webread`, `weboptions`, and `jsondecode` for current-state snapshots.
- HTTP metadata: MATLAB `matlab.net.http.RequestMessage` to capture status, content type, and available rate-limit headers.
- Organization: `table` and `timetable`.
- ENU conversion: `wgs84Ellipsoid` and `geodetic2enu`.
- State order: Sensor Fusion convention `[x; vx; y; vy; z; vz]`.

## Access Result

| Target | HTTP status | Content type | Rate-limit headers | Error |
| :--- | ---: | :--- | :--- | :--- |
| OpenSky datasets page | 200 | text/html | None observed |  |
| Natick current-state endpoint | 200 | application/json | X-Rate-Limit-Remaining: 386 |  |

Current-state endpoint:

```text
https://opensky-network.org/api/states/all?lamin=41.83&lomin=-71.96&lamax=42.73&lomax=-70.74
```

## Sampling Summary

| Metric | Value |
| :--- | ---: |
| Requested duration [s] | 600 |
| Actual elapsed duration [s] | 600.2 |
| Requested cadence [s] | 15 |
| Median observed successful cadence [s] | 15.00 |
| Snapshots attempted | 41 |
| Snapshots successful | 41 |
| Raw records parsed | 2243 |
| Retained airborne records | 996 |
| Aircraft with repeated valid samples | 46 |
| Aircraft with usable state pairs | 46 |
| Usable one-step state pairs | 881 |
| Duplicate timestamps removed | 64 |

## Field Completeness

Raw OpenSky state-vector field completeness:

| fieldNames | validCounts | validPercent |
| :--- | :--- | :--- |
| icao24 | 2243.00 | 100.00 |
| timePosition | 2243.00 | 100.00 |
| lastContact | 2243.00 | 100.00 |
| longitude | 2243.00 | 100.00 |
| latitude | 2243.00 | 100.00 |
| baroAltitude | 1139.00 | 50.78 |
| geoAltitude | 1138.00 | 50.74 |
| onGround | 2243.00 | 100.00 |
| velocity | 2243.00 | 100.00 |
| trueTrack | 2243.00 | 100.00 |
| verticalRate | 1139.00 | 50.78 |
| sensors | 0.00 | 0.00 |
| squawk | 1022.00 | 45.56 |
| spi | 2243.00 | 100.00 |
| positionSource | 2243.00 | 100.00 |

Retained-record completeness for latitude, longitude, altitude, velocity, and true track: 100.0%.

## Altitude And Vertical Rate

Altitude preference was `geoAltitude` first, then `baroAltitude` as fallback.

| AltitudeSource | Count |
| :--- | :--- |
| baroAltitude | 1.00 |
| geoAltitude | 995.00 |

Vertical velocity used `verticalRate` when available. Finite-difference altitude rate was computed only as a continuity diagnostic and was not used in usable state pairs.

| VzSource | Count |
| :--- | :--- |
| missing | 1.00 |
| verticalRate | 931.00 |

## ENU And State Construction

- Natick ENU origin: latitude 42.2833 deg, longitude -71.3495 deg, altitude 0.0 m.
- Radius filter: 50000 m horizontal range after ENU conversion.
- Velocity convention: `vx = speed * sind(trueTrack)`, `vy = speed * cosd(trueTrack)` because OpenSky true track is clockwise from north.
- State column order verified: `x, vx, y, vy, z, vz`.
- MATLAB table creation worked: 1.
- MATLAB timetable creation worked: 1.
- ENU conversion worked: 1.
- State construction worked: 1.

## Provisional Covariance

This covariance is a probe-only placeholder and is not a final training policy.

| State element | Assumed standard deviation | Unit |
| :--- | ---: | :--- |
| x | 100.0 | m |
| vx | 10.0 | m/s |
| y | 100.0 | m |
| vy | 10.0 | m/s |
| z | 150.0 | m |
| vz | 5.0 | m/s |

## dt Distribution

| Statistic | dt [s] |
| :--- | ---: |
| Count | 881 |
| Min | 1.00 |
| P25 | 10.00 |
| Median | 16.00 |
| P75 | 21.00 |
| Max | 167.00 |

## Go/No-Go Criteria

| Criterion | Passed | Evidence |
| :--- | :--- | :--- |
| Natick endpoint reachable without manual setup | true | Endpoint metadata check reached HTTP success before sampling. |
| At least 5 airborne aircraft with repeated valid samples | true | 46 repeated aircraft |
| At least 100 usable one-step state pairs | true | 881 usable pairs |
| Median usable dt <= 30 seconds | true | median dt 16.00 s |
| At least 80 percent retained field completeness | true | 100.0 percent retained completeness |
| MATLAB table/timetable creation works | true | table 1, timetable 1 |
| ENU conversion works | true | ENU conversion 1 |
| State construction order is [x; vx; y; vy; z; vz] | true | x, vx, y, vy, z, vz |

## Risks And Failures

- Repeated current-state snapshots produced duplicate aircraft timestamps; duplicates were removed before dt calculation.
- Some retained records lacked verticalRate; finite-difference vertical rate was computed only as a continuity diagnostic and not used in usable state pairs.
- OpenSky redistribution and historical-access terms still need full review before any shared or long-running Stage 2 dataset work.

## Decision

**GO.** Continue Stage 2 with OpenSky as the initial data source while keeping local ADS-B collection as the fallback and validation path.
