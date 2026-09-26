# Change Requests

Proposed changes to the controlled documents ([System_Architecture.md](System_Architecture.md) and [ICD_Messages.md](ICD_Messages.md)), and places where implementation got ahead of them.

The owner (Leif) decides each one. Accepted changes are made in the controlled document in this folder, which is the master copy, in the same commit that marks the CR **Done**. Evidence lives in [Verification_Log.md](Verification_Log.md) and [evidence/](evidence/).

| Field | Meaning |
|---|---|
| Status | **Open** (awaiting decision), **Accepted** (document to be updated), **Rejected**, **Done** (document updated) |
| Kind | **Deviation** (implementation already differs from the document), **Correction** (the document is wrong about the as-built system), **Clarification** (the document is ambiguous), **Proposal** (a new change) |

| CR | Title | Kind | Affects | Status |
|---|---|---|---|---|
| CR-1 | Cap `track_cue` opportunities to the top N by peak SNR | Deviation | ICD §2.3, §2.5; `cue-config` schema | Open |
| CR-2 | MATLAB consumers need a Java multicast socket | Proposal | ICD §1.3; Architecture Deployment Policy rule 5, open item 4 | Open |
| CR-3 | Mark CT messages Verified from the 2026-09-26 capture | Proposal | ICD §0 status table | Open |
| CR-4 | Revision comparison across CT restarts | Clarification | ICD §2.0 receiver rule | Open |
| CR-5 | Encoding of the CT cue stream | Proposal | ICD §1.2, §1.3, §2.3 | Open (analysis done) |
| CR-6 | Stale tracks are not withdrawn until purged | Clarification | ICD §2.0, §2.4 | Open |
| CR-7 | Single controlled source for observer site geometry | Proposal | Architecture (CT inputs); SiteGeometry.md | Open |
| CR-8 | As-built corrections to System_Architecture.md | Correction | Architecture: RF Collection Desktop, Raspberry Pi, Time Source, CT, open item 9 | Open |

---

### CR-1: Cap `track_cue` opportunities to the top N by peak SNR

- **What changed:** CT (ADSB-remoter commit `65e2fbe`, branch `feature/passive-radar-cueing`) publishes only the N usable opportunities with the highest peak window SNR, strongest first. N is `udp_output.maximum_opportunities_per_cue`, default 3, in the new `cue-config-1.1.0.json` (1.0.0 archived). The wire schema is unchanged; the list is just shorter.
- **Why:** decision CT-9(c) alone did not fit the datagram limit. With usable windows, a cue with 11 opportunities was about 25 kB even without history, over `maximum_datagram_bytes` = 16 384. CT counted it as failed and did not send it. In practice **every cue that carried an opportunity was dropped**, and only empty cues reached receivers. Capped at 3, a cue is about 8 kB.
- **Conflicts with:** ICD §2.3 ("one *opportunity* per (observer, emitter) pair") and §2.5 ("No schema changes are proposed").
- **Decide:** accept the cap and its default, or choose another limit. CR-5 could remove the need for a cap.

### CR-2: MATLAB consumers of the multicast cue stream

- **Finding (2026-09-26, R2026a on Ubuntu):** `udpport` cannot join a multicast group on Linux; `configureMulticast` raises `instrument:interface:udpport:PlatformNotSupported`. It also cannot choose the interface that joins. The RF Collection Desktop's default route is its Wi-Fi, so a join on the default interface receives nothing from the data network.
- **Working method:** `java.net.MulticastSocket`, joined on the data-network interface (`192.168.10.41`). This is implemented and tested in `CueListener` (flightTest branch `feature/adsb-cue-listener`).
- **Proposed changes:**
  - ICD §1.3: state that consumers join on the data-network interface.
  - Architecture Deployment Policy rule 5 and open item 4: add "Java `MulticastSocket` and `java.util.zip` inside a compiled app" to the compiler deployability checks.

### CR-3: CT messages meet the Verified criteria

The [2026-09-26 12:34 capture](evidence/cue_traffic_20260926T1234Z.jsonl) meets the WI-7 acceptance criteria:

- 46 messages, all validated against the CT 1.1.0 schemas with 0 failures;
- no sequence gaps and no duplicate `message_id` values;
- 4 snapshots, 3 of them carrying `track_cue`, each with `published_track_count` equal to the cues received.

**Proposal:** mark `cue_heartbeat`, `cue_snapshot_begin`, `cue_snapshot_end` and `track_cue` as **Verified**. `track_cue_withdrawal` has not been seen live and stays **Implemented**.

Limit: the capture contains one aircraft, with one window per opportunity. A capture with several aircraft and multi-window opportunities would strengthen the evidence.

### CR-4: Revision comparison across CT restarts

ICD §2.0 says to keep the highest `prediction.revision` per `track_id`. Revisions restart at 1 when CT restarts (new `source_instance_id`), so a literal reading would ignore every cue from a restarted CT until its revisions caught up.

**Proposed text:** "Compare revisions only within one `source_instance_id`. A cue from a new `source_instance_id` replaces the held cue for that track." This is what `CueListener` does.

### CR-5: Encoding of the CT cue stream

See [analysis/Cue_Traffic_Encoding.md](analysis/Cue_Traffic_Encoding.md).

- **Findings:**
  - 58% of the bytes are field names and JSON punctuation; about 17% is information.
  - Bandwidth is not a constraint (under 0.1% of 1 GbE even at 100 aircraft).
  - Datagram size is: every `track_cue` is fragmented into 6 IP fragments, and the size limit forced CR-1.
- **Options that fit one frame:** deflate with a preset dictionary (no schema change), compact mirror + gzip, or packed binary. Leaving JSON buys little.
- **Decision pending:** the four questions at the end of the analysis.

### CR-6: Stale tracks are not withdrawn until purged

CT sends `track_cue_withdrawal` only when a track is purged, which happens after `--track-retention-minutes` (default 20 min). A track that stops reporting is not withdrawn when it ages out (about 20 s).

Periodic snapshots also re-send the last cue of a track that has gone quiet. For example, a cue with `report_age_s` = 82 s was observed on 2026-09-26.

**Proposal:** either state in the ICD that consumers must judge staleness from `track.report_age_s` and `prediction.valid_until_utc`, or have CT withdraw on age-out with a new `reason` value.

### CR-7: Single controlled source for observer site geometry

The receive site is described in three inconsistent ways:

| Source | Position | Altitude |
|---|---|---|
| [SiteGeometry.md](SiteGeometry.md) | 42.29917940712679, −71.34964782414613 (surveyed) | 10 m above ground |
| BistaticDataAnalysis `rxLLA` | 42.2999333, −71.349333 | 15.0 m, labelled MSL (ground is about 60 m, so probably height above ground) |
| CT `deploy/pi-observers.ini` | surveyed position | 75 m |

The emitter table also exists in several copies (see the [README](README.md)).

**Proposal:** one controlled site-configuration file (observer positions in a stated datum, antenna pointing, RF chain parameters) that CT, the analysis pipeline and the RF Collector all read.

### CR-8: As-built corrections to System_Architecture.md

- **RF Collection Desktop:** the data interface is `eno1`, not `en0`. Internet access is over Wi-Fi `wlp2s0`. The desktop now NATs the Pi to the internet (`pi-gateway-nat.service`).
- **Raspberry Pi:** its default route is via the RF Collection Desktop (`/etc/dhcpcd.conf`, `routers=192.168.10.41`). The old gateway, 192.168.10.1, does not exist.
- **Time Source:** chrony on the Pi keeps time from **internet NTP through that NAT**. The GPS/PPS reference clocks are configured but not locked (as of 2026-09-25). Before NTP was reachable, the Pi ran about 15 s slow, which shifts every cue timestamp and all ADS-B truth. The Time Source is therefore not yet "Operating" as described.
- **ADSB Cue Tasker:** it runs as the systemd service `adsb-cue`, executing `adsb-console --headless --source 127.0.0.1:30003 --observerfile deploy/pi-observers.ini --cue-config deploy/pi-cue-config.json`, not `python3 -m adsb_remoter`. The Activity Manager does not launch it yet.
- **Open item 9:** `dtvPredictDirectPath.m` exists: on flightTest `feature/pluto-azimuth-environment-scan` and `feature/adsb-cue-listener`, in `TestSetupTesting/`.
