# System Engineering: Apple Hill Passive Bistatic Radar Testbed

This folder is the home of the system engineering material for the testbed: the architecture, the interface control document, and the records that keep them honest (as-built state, change requests, verification evidence).

- **What the system is:** an ADS-B cue tasker on the Raspberry Pi tells a MATLAB resource manager which aircraft to collect on, with which DTV illuminator and when. An N320-based RF collector, signal processor and tracker then do the passive radar work. The top-level flow is in [System_Architecture.md](System_Architecture.md).
- **Where the masters live:**
  - The documents marked *received* below arrived on 2026-09-26 as copies of masters kept in the "043" project folder, and are stored here unchanged.
  - **Open decision:** make this folder, on `main`, the master, so that changes go through git. Until then, changes are made in the 043 masters and re-copied here. Everything proposed against them is logged in [Change_Requests.md](Change_Requests.md) rather than edited in place.

## Documents

| Document | What it is | Origin | Revision |
|---|---|---|---|
| [System_Architecture.md](System_Architecture.md) | Functional items, hardware, networks, allocation, System Composer mapping, decisions and open items | received | 2026-09-25 |
| [ICD_Messages.md](ICD_Messages.md) | Message contract: envelope, transport and ports, CT messages (§2, being frozen), proposed messages for other items (§3), status levels (§0) | received | Draft A, 2026-09-25 |
| [SiteGeometry.md](SiteGeometry.md) | Receive-site location, antenna layout and pointing, local DTV transmitter table and bearings | received | 2026-09-24 |
| [20_DTV_direct_path_input.csv](20_DTV_direct_path_input.csv) | FCC-derived DTV emitter table (call sign, channel, frequency, location, EIRP) | received | — |
| [CT_1.1.0_handoff.md](CT_1.1.0_handoff.md) | Work brief that took the CT messages to schema 1.1.0 | received | 2026-09-25 |
| [CT_1.1.0_report.md](CT_1.1.0_report.md) | The CT agent's report back on that brief | received | 2026-09-25 |
| [As_Built.md](As_Built.md) | What actually runs, where, and how it is started, updated and monitored | authored here | 2026-09-26 |
| [Change_Requests.md](Change_Requests.md) | Register of deviations, corrections and proposals against the architecture and ICD (CR-1 … CR-8) | authored here | 2026-09-26 |
| [Verification_Log.md](Verification_Log.md) | Dated checks and their evidence | authored here | 2026-09-26 |
| [Engineering_Notes.md](Engineering_Notes.md) | Lessons learned: network, MATLAB, hosts, SE practice | authored here | 2026-09-26 |
| [analysis/Cue_Traffic_Encoding.md](analysis/Cue_Traffic_Encoding.md) | Label-versus-value analysis of the cue traffic and encoding options (for CR-5) | authored here | 2026-09-26 |
| [analysis/analyze_cue_traffic.py](analysis/analyze_cue_traffic.py), [analysis/check_matlab_decompress.m](analysis/check_matlab_decompress.m) | Scripts that reproduce the analysis | authored here | 2026-09-26 |
| [evidence/](evidence/) | Raw wire captures behind the verification log (one JSON message per line) | captured | 2026-09-26 |

## Software items and where their code is

| ID | Item | Code | As-built |
|---|---|---|---|
| AR | ADSB Receiver | dump1090 (Docker) on the Pi | Operating |
| CT | ADSB Cue Tasker (ADSB-Remoter) | [ADSB-remoter](https://github.com/lhilleMAT2022/ADSB-remoter), branch `feature/passive-radar-cueing`: `src/adsb_console/cue.py` (messages), `prediction.py`, `schemas/`, `tools/cue_capture.py`, `deploy/` | Operating as `adsb-cue` on the Pi |
| RM | Resource Manager | flightTest `feature/adsb-cue-listener`: `CueListener/` (receives, applies the ICD §2.0 rules, ranks cues; no tasking yet) | First piece built |
| RC | RF Collector | flightTest `TestSetupTesting/runLocalHDTVCapture.m`, `log_iq_n320_2antennas.m` | Rev 1, not task-driven |
| SP | Signal Processor | flightTest `BistaticDataAnalysis/` | Offline; detector in development |
| CM | Calibration Manager | flightTest `feature/pluto-azimuth-environment-scan`: `TestSetupTesting/` Pluto scripts and `dtv*` level checks | In development |
| TR, RD, AM, AC | Tracker, Report & Display, Activity Manager, Antenna Controller | — | Planned or proposed |

Details, including hosts, addresses, services and ports, are in [As_Built.md](As_Built.md).

## Message status register

The levels are defined in ICD §0. "Evidence" is the status the evidence supports; the ICD column changes only when the owner updates the ICD.

| Message | Schema (ADSB-remoter `schemas/`) | ICD status (Draft A) | Supported by evidence | Evidence |
|---|---|---|---|---|
| `cue_heartbeat` | `cue-heartbeat-1.1.0.json` | Verified (at 1.0.0) | **Verified** at 1.1.0 | [2026-09-26 12:34 capture](evidence/cue_traffic_20260926T1234Z.jsonl), CR-3 |
| `cue_snapshot_begin` / `_end` | `cue-snapshot-begin-1.1.0.json`, `cue-snapshot-end-1.1.0.json` | Verified (at 1.0.0) | **Verified** at 1.1.0 | same |
| `track_cue` | `track-cue-1.1.0.json` | Implemented | **Verified** (one aircraft, with the top-3 cap; see CR-1, CR-3) | same |
| `track_cue_withdrawal` | `track-cue-withdrawal-1.1.0.json` | Implemented | Implemented (not yet seen live) | — |
| CT configuration | `cue-config-1.1.0.json` (adds `maximum_opportunities_per_cue`) | Implemented at 1.0.0 | Implemented at 1.1.0 (CR-1) | — |
| All ICD §3 messages | — | Proposed | Proposed | — |

## Conventions

- **Messages and schemas:** follow ICD §1 (snake_case, units in names, flat envelope, `additionalProperties: false`, semver per schema) and the ICD §0 status levels.
- **Changes to controlled documents:** add a CR with its evidence first. Edit the document only after the owner accepts it, then mark the CR **Done**.
- **Evidence files:** `evidence/<stream>_<UTC timestamp>.jsonl`, one message per line, exactly as received. Log each capture in [Verification_Log.md](Verification_Log.md).
- **As-built:** update [As_Built.md](As_Built.md) in the same change as any deployment change.

## Shared data with more than one copy (see CR-7)

| Data | Copies |
|---|---|
| DTV emitter table | 043 master folder; this folder; flightTest `TestSetupTesting/siteData/` (on `feature/pluto-azimuth-environment-scan` and `feature/adsb-cue-listener`); ADSB-remoter repo root. The contents match; only the line endings differ |
| Receive-site geometry | [SiteGeometry.md](SiteGeometry.md) (surveyed, 10 m above ground); `BistaticDataAnalysis` `rxLLA` (older position, 15 m); ADSB-remoter `deploy/pi-observers.ini` (surveyed position, 75 m) |

## Open decisions

| Item | Where |
|---|---|
| Make this folder the master for the system documents | above |
| Top-N opportunity cap | CR-1 |
| Encoding of the cue stream (compression, compact mirror schema, or none) | CR-5, [analysis](analysis/Cue_Traffic_Encoding.md) |
| Single source for site geometry | CR-7 |
| Remaining architecture open items | System_Architecture.md, "Remaining Open Items" |
