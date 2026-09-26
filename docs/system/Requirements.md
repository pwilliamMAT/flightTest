# Requirements Baseline — DRAFT

> **Status: DRAFT baseline for owner review (proposed by CR-10, 2026-09-26). Nothing in this file is accepted yet.**
> Master copy once accepted: flightTest `main`, `docs/system/`. Change it through git and the CR process in [README.md](README.md).

**System:** Apple Hill passive bistatic radar testbed. Companion to [System_Architecture.md](System_Architecture.md) (what is designed) and [ICD_Messages.md](ICD_Messages.md) (how items talk).

**How this baseline was built:**

- It starts from the project's two mission goals, which were the only top-level goals when it was written.
- Mission needs follow from the goals. System requirements follow from the needs.
- Derived requirements are written only where existing design decisions, change requests, or verification work already imply them: the cue interface, timing, dataset packaging and provenance, data release, MATLAB deployment, and truth separation.
- No number is invented. Where a value is not known it is **TBD**. Where a value is proposed from a measurement, the measurement is cited and the value is marked *proposed*.

## Conventions

| Field | Meaning |
|---|---|
| ID | `MG` mission goal, `MN` mission need, `SR` system requirement, `DR-<area>` derived requirement |
| Parent | The ID or IDs this requirement serves |
| Allocation | Architecture items from [System_Architecture.md](System_Architecture.md): AR, CT, RM, RC, SP, TR, RD, CM, AM, AC, Time Source; or *process* for rules on how evidence is handled |
| Method | **I** inspection, **A** analysis, **D** demonstration, **T** test |
| Status | **Verified**: evidence shows the requirement met. **Partial**: part is met, or it is met under narrower conditions than stated. **Not met**: the item exists and the requirement is not met. **Not started**: the allocated item is not built yet. **Proposed**: depends on a rule or message that is itself only proposed |

Status reflects the evidence on 2026-09-26. Evidence links point to [Verification_Log.md](Verification_Log.md), [evidence/](evidence/), the change requests, or the public reporting site.

## 1. Mission goals

| ID | Goal |
|---|---|
| MG-1 | Collect passive radar data to show that a complete passive radar system can be built with MATLAB and MathWorks tools. |
| MG-2 | Collect data that proves MATLAB functions, for example radar, tracking and signal processing, work as designed on real data that can be shared with customers. |

## 2. Stakeholders

| Stakeholder | Interest |
|---|---|
| Project owner | Goals, priorities, acceptance of requirements and evidence |
| Testbed engineers | Operate, maintain and extend the hardware and software items |
| Users of MATLAB radar, tracking and signal-processing functions | Real data with truth on which to exercise and judge those functions |
| Customers receiving shared datasets | Documented, traceable data that they are allowed to use |
| Site and network owners | Hosting, network, and physical-installation constraints at Apple Hill |

## 3. Mission needs

| ID | Need | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|
| MN-1 | Operate a complete passive bistatic radar chain (cue, schedule, collect, process, track, report), with every processing and control function built with MATLAB and MathWorks tools and any exception named and justified. | MG-1 | System | I, D | Partial | Architecture item status in [README.md](README.md). CT is Python, an exception that the owner must confirm is compatible with MG-1 (DR-DEP-4) |
| MN-2 | Collect real passive radar data on aircraft of opportunity, using broadcast DTV transmitters as illuminators. | MG-1, MG-2 | System | D | Partial | Historical packages ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html)); no collection yet driven by cues |
| MN-3 | Give every dataset independent truth good enough to judge MATLAB function outputs (detections, tracks) against it. | MG-2 | System | I, A | Partial | ADS-B is packaged with collections; timing tolerance DR-TIME-1; truth separation CR-9 is proposed |
| MN-4 | Make datasets shareable with customers: packaged, documented, traceable to their provenance, and cleared for release. | MG-2 | System | I | Not met | Packaging is partial (DR-DATA-1 to 3); release clearance not assessed (SR-11) |
| MN-5 | Keep every claim that a function or the system works traceable to evidence, with its evidence class and claim boundary, and never overstated. | MG-1, MG-2 | Process | I | Partial | Reporting rules ([howToUpdateReports.md](../../reporting/howToUpdateReports.md)); cued-evidence labelling proposed (CR-9) |
| MN-6 | Run the MATLAB items as deployed applications, so the system runs as a system and not only inside interactive MATLAB sessions. | MG-1 | System | D | Partial | Compiled-app probe ([analysis/deployability/](analysis/deployability/)); no production item compiled yet |

## 4. System requirements

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| SR-01 | The system shall identify aircraft of opportunity from ADS-B and publish, for each, the receivable DTV illuminators and the predicted time windows to the Resource Manager. | Collections must be aimed at aircraft that are present and favourably placed. | MN-2 | AR, CT | T | Verified (interface) | CT 2.0.0 live acceptance, [Verification_Log.md](Verification_Log.md) 2026-09-26 15:23; [evidence](evidence/cue_traffic_20260926T1523Z_wire.jsonl) |
| SR-02 | The Resource Manager shall turn cues, track reports and calibration requests into collection tasks and antenna commands, within the limits of one N320 and two rotators. | One receiver and two slow rotators must be shared among competing requests. | MN-1, MN-2 | RM | D | Not started | First piece only (CueListener: receives and ranks cues, no tasking), [As_Built.md](As_Built.md) |
| SR-03 | The RF Collector shall record dual-channel (SURV, REF) IQ on a commanded DTV channel, start time and duration, and record the requested and read-back settings. | Passive bistatic processing needs synchronised reference and surveillance channels with known settings. | MN-2 | RC | D | Partial | Manual captures with manifests and readback ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html)); not task-driven |
| SR-04 | The Antenna Controller shall point SURV and REF to commanded azimuths within a pointing tolerance of **TBD**, report the achieved azimuth, and keep both stationary during a capture. | Surveillance coverage and reference quality depend on pointing; motion corrupts a capture. | MN-2 | AC | T | Not started | Design proposed in [System_Architecture.md](System_Architecture.md) (Antenna Orientation Module) |
| SR-05 | Every host that timestamps IQ, ADS-B truth or cues shall keep UTC within the timing tolerance of DR-TIME-1. | Truth is only useful if its timestamps line up with the IQ. | MN-3 | Time Source, RC, AR, CT | T, A | Partial | NTP accepted by the owner (2026-09-26); one check at +0.05 to +0.09 s ([Verification_Log.md](Verification_Log.md) 2026-09-25 21:07); GPS/PPS not locked (DR-TIME-3) |
| SR-06 | Every collection shall be packaged with the ADS-B truth record that covers its collection window. | Independent truth for every dataset (MN-3). | MN-3 | AR, RC | I | Partial | Historical packages include an ADS-B gzip ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html)); cue-driven packaging not built |
| SR-07 | The Signal Processor shall form range-Doppler maps and detections from captures with MATLAB functions, without using truth or cues to form them (DR-TS-3). | Detections must be evidence about the functions, not about the truth fed into them. | MN-1, MN-3 | SP | D, T | Not met | Offline pipeline exists; detector not yet producing truth-matched detections ([tracking-scan diagnostic](https://pwilliammat.github.io/flightTest/diagnostics/TrackingScan_NoDetection_Diagnostic_V1.html)) |
| SR-08 | The Tracker shall form bistatic range-Doppler tracks per illuminator from detections. | Tracking functions are part of MG-2. | MN-1, MN-2 | TR | D | Not started | — |
| SR-09 | The Calibration Manager shall check receive-chain health before collection and report PASS, WARN or FAIL. | A collection on an unhealthy chain wastes the opportunity and misleads analysis. | MN-2, MN-3 | CM | D | Partial | Pluto and DTV-level scripts in development ([Pluto diagnostic](https://pwilliammat.github.io/flightTest/diagnostics/PlutoCombPresence_Diagnostic_V1.html)); not on `main` |
| SR-10 | Every shareable dataset shall be a self-describing package: IQ, truth, logs, configuration and read-back, channel roles, and file hashes under one manifest. | Customers and later analysts must be able to check what was recorded and how. | MN-4 | RC, RD | I | Partial | Historical manifests lack role, lock, drop and hash fields ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) §6, §9) |
| SR-11 | Every shareable dataset shall carry a data-rights and release statement, approved before it is shared. The content of the statement is **TBD**. | Sharing with customers requires known rights to every part of the data. | MN-4 | Process | I | Not started | Rights of ADS-B truth, site location data and emitter table sources not yet assessed |
| SR-12 | Every software item except the named exceptions (DR-DEP-4) shall be implemented in MATLAB and be deployable as a compiled standalone app on the MATLAB Runtime, Linux first. | Demonstrates MG-1 as a running system. | MN-1, MN-6 | RM, RC, SP, TR, RD, CM, AM, AC | D | Partial | Cue-reception path proven in a compiled app ([analysis/deployability/](analysis/deployability/)); no production item compiled |
| SR-13 | Every reported claim shall state its evidence class and claim boundary, and evidence from cued or cue-aided processing shall be labelled as such (DR-TS). | Prevents modeled, diagnostic or cue-aided evidence from being read as independent or operational evidence. | MN-5 | Process | I | Partial | Reporting family rules; truth-separation rule proposed (CR-9) |
| SR-14 | Every message between items shall be defined in the ICD with a schema, a version and a development status, and a status shall change only on recorded evidence. | Interfaces are how independent items become one system. | MN-1 | All items | I | Partial | CT messages Verified at 2.0.0; all other messages Proposed ([ICD_Messages.md](ICD_Messages.md) §0) |
| SR-15 | The Activity Manager shall launch the software items on their configured hosts and report the health of each. | A system of ten items needs one place that starts and watches them. | MN-1, MN-6 | AM | D | Not started | CT heartbeat exists ([ICD_Messages.md](ICD_Messages.md) §2.1); AM not built |

## 5. Derived requirements

### 5.1 Cue interface (parents SR-01, SR-14)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-CUE-1 | CT messages shall validate against the CT schemas 2.0.0 (ICD §2). | Receivers rely on a fixed contract. | SR-01, SR-14 | CT | T | Verified | 223 of 223 datagrams valid, 0 schema failures ([summary](evidence/cue_traffic_20260926T1523Z_summary.json)) |
| DR-CUE-2 | Each cue datagram shall fit one Ethernet frame (at most 1472 B of UDP payload). | A fragmented datagram is lost if any fragment is lost (CR-5). | SR-01 | CT | T | Verified | 0 of 223 over one frame, largest 747 B |
| DR-CUE-3 | The cue stream shall let a receiver recover from loss: heartbeat every 10 s, full snapshot every 60 s, and sequence numbers per sender instance. | UDP multicast is a deliberate exception to reliable transport (ICD §1.3). | SR-01 | CT | T | Verified | 15 of 15 snapshots consistent, 0 sequence gaps |
| DR-CUE-4 | Each cue shall identify its SNR model and threshold (`models`), and consumers shall treat predicted SNR as a ranking, not a detection prediction. | Predicted SNR is a modeled, pre-integration estimate. | SR-01, SR-13 | CT, RM | I | Verified | `models` block in `track-cue-2.0.0.json`; CueListener README |
| DR-CUE-5 | A consumer shall be able to tell that a cue is stale or withdrawn. | A scheduler must not act on a dead track. | SR-01 | CT, RM | T | Partial | Withdrawal never seen live; stale tracks withdrawn only at purge (CR-6, open) |
| DR-CUE-6 | MATLAB consumers shall receive the stream on the data-network interface and decode both framings, in a MATLAB session and in a compiled app. | `udpport` multicast is Windows-only (CR-2). | SR-01, SR-12 | RM | D | Verified | CueListener 16 tests; compiled probe ([Verification_Log.md](Verification_Log.md) 2026-09-26 14:30, 15:30) |
| DR-CUE-7 | Consumers shall compare prediction revisions only within one `source_instance_id`. | Revisions restart when CT restarts. | SR-01 | RM | I | Proposed | CR-4 (open); CueListener already does this |

### 5.2 Tasking (parent SR-02)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-TASK-1 | Every cue-driven collection task shall carry `cue_ref` (track, prediction revision, observer, emitter, window start). | Links each capture to the prediction that caused it, for truth scoring and truth separation. | SR-02, SR-13 | RM, RC | I | Proposed | ICD §3.1 `collection_task` (Proposed) |
| DR-TASK-2 | The Resource Manager shall run a 1-minute short planning loop and a 5-minute long planning loop. | Architecture decision 1 (2026-09-25). | SR-02 | RM | D | Not started | [System_Architecture.md](System_Architecture.md), Decisions |

### 5.3 Timing (parent SR-05)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-TIME-1 | The ADS-B Pi and the RF Collection Desktop shall agree on UTC within **0.1 s** (*proposed tolerance*). Internet NTP is an accepted time source. | The only measurement bounds the agreement at +0.05 to +0.09 s, limited by SSH jitter. At up to about 290 m/s (fastest aircraft in the acceptance capture), 0.1 s moves the bistatic range by at most about 58 m (twice the speed), about one range cell for a ~5.4 MHz ATSC signal. | SR-05 | Time Source, RC | T, A | Partial | One check ([Verification_Log.md](Verification_Log.md) 2026-09-25 21:07); a repeatable check is still needed |
| DR-TIME-2 | Each collection shall record the time-sync state (source, offset, sync status) of every host that timestamps its IQ or truth. | Makes the timing of every package checkable after the fact. | SR-05, SR-10 | RC, AR, Time Source | I | Not met | No package records chrony state yet |
| DR-TIME-3 | The GPS/PPS reference clocks on the Pi shall lock. | Restores the designed stratum-0 source. Not needed to meet DR-TIME-1 with NTP. | SR-05 | Time Source | T | Not met | Configured but not locked; a loose component is suspected. Hardware to-do: reseat and re-check ([As_Built.md](As_Built.md)) |
| DR-TIME-4 | ADS-B truth recorded on the Pi before 2026-09-25 21:07 UTC shall not be used as timing truth until its clock offset is bounded. | The Pi was measured 14.9 s slow before NTP was reachable (CR-8). | SR-05, SR-06 | Process | A | Not met | Re-check of earlier packages (including the 2026-09-25 tracking scan) is open |

### 5.4 Datasets, provenance and release (parents SR-06, SR-10, SR-11)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-DATA-1 | The manifest shall record requested and read-back settings, ordered ports, channel roles, and antenna and cable identity. | Channel roles must be recorded, not inferred from signal power (Report 02). | SR-10 | RC | I | Partial | Settings and readback recorded; roles and identity missing ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) §9) |
| DR-DATA-2 | The manifest shall record receiver lock state and dropped or overflow sample counts. | A capture with drops or no lock is not trustworthy. | SR-10 | RC | I | Not met | Missing from historical manifests |
| DR-DATA-3 | The manifest shall record the SHA-256 of every packaged file. | Integrity and provenance for shared data. | SR-10 | RC | I | Not met | Missing from historical manifests |
| DR-DATA-4 | The ADS-B truth in a package shall cover the collection window with a lead and tail of **TBD** seconds. | Tracks must be known before and after the capture to align truth. | SR-06 | AR, RC | I | Partial | Historical example: 49 s ADS-B window around a 29 s radar window ([Report 02](https://pwilliammat.github.io/flightTest/reports/02_HardwareAndCollection_V4.html) §6) |
| DR-DATA-5 | Each shareable dataset shall carry a release statement covering its data sources (IQ, ADS-B truth, site location, emitter table). | Customers must know what they may do with the data. | SR-11 | Process | I | Not started | — |
| DR-DATA-6 | Each package shall record `collection_basis` and, for cued collections, the `cue_ref` (CR-9, rule TS-1). | Cued data must never be mistaken for independent detection evidence. | SR-10, SR-13 | RC, RM | I | Proposed | CR-9 |

### 5.5 MATLAB implementation and deployment (parent SR-12)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-DEP-1 | Each MATLAB item shall have one entry point that runs unchanged compiled or in a MATLAB session. | Architecture deployment rule 1. | SR-12 | MATLAB items | I | Not met | No production item has an entry point of this form yet |
| DR-DEP-2 | Host-specific values (hosts, ports, paths, device names) shall come from configuration, not code. | Architecture deployment rule 2; lets items move between hosts. | SR-12, SR-15 | MATLAB items, AM | I | Not met | `system_config.json` is proposed; some defaults are still in code |
| DR-DEP-3 | Each toolbox or hardware dependency shall be proven in a compiled app before an item is designed around it. | Architecture deployment rule 5 and open item 4. | SR-12 | MATLAB items | D | Partial | Java multicast and `java.util.zip` proven; N320, Pluto, `serialport`, `tcpserver` still TBD |
| DR-DEP-4 | The exceptions to MATLAB implementation shall be named: CT (Python), system services (chrony, gpsd, dump1090) and ESP32 firmware. | Keeps MG-1 honest about what is not MATLAB. | SR-12, MN-1 | CT, AR, Time Source, AC | I | Partial | Named in [System_Architecture.md](System_Architecture.md); owner to confirm that a Python CT is consistent with MG-1 |

### 5.6 Truth separation (parents SR-07, SR-13; rule proposed in CR-9)

| ID | Requirement | Rationale | Parent | Allocation | Method | Status | Evidence |
|---|---|---|---|---|---|---|---|
| DR-TS-1 | Every capture shall be labelled with its `collection_basis`: `cued`, `uncued`, `calibration` or `survey`. | Cues choose when, and with which tower, to collect. | SR-13, SR-10 | RM, RC | I | Proposed | CR-9 rule TS-1 |
| DR-TS-2 | Every detection and track product shall be labelled with its `truth_use`: `truth_blind` or `cue_aided`. | The Tracker may use cues to help association. | SR-13 | SP, TR | I | Proposed | CR-9 rule TS-2 |
| DR-TS-3 | Only `truth_blind` products shall count as independent detection or tracking evidence. | Evidence must not contain the truth it is scored against. | SR-07, SR-13 | SP, TR, process | I | Proposed | CR-9 rule TS-3 |
| DR-TS-4 | Detection probability from cued collections shall be reported as conditional on the cue. False-alarm rates shall state the collections and cells they were measured on. | Cued collections are not a random sample of the sky. | SR-13 | Process | I, A | Proposed | CR-9 rule TS-4 |
| DR-TS-5 | Cue-aided association and tracking shall be scored separately from truth-blind results, and never reported as independent tracking performance. | Cues and ADS-B truth come from the same receiver. | SR-13 | TR, RD, process | I | Proposed | CR-9 rule TS-5 |

## 6. Counts (2026-09-26 draft)

| Level | Count | Verified | Partial | Not met | Not started | Proposed |
|---|---:|---:|---:|---:|---:|---:|
| Mission goals | 2 | — | — | — | — | — |
| Mission needs | 6 | 0 | 5 | 1 | 0 | 0 |
| System requirements | 15 | 1 | 8 | 1 | 5 | 0 |
| Derived requirements | 28 | 5 | 6 | 7 | 2 | 8 |

## 7. Open points for the owner

1. Accept, change or reject each requirement. Values marked **TBD** or *proposed* need a decision.
2. Is a Python cue tasker consistent with MG-1, or should CT eventually move to MATLAB (DR-DEP-4)?
3. What must a data-release statement contain, and who approves it (SR-11, DR-DATA-5)?
4. Should the Report 02 CTRL-001 acceptance criteria (A-B-A reference test, 30 s drop test) become derived requirements under SR-03 and SR-10?
