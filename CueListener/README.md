# ADS-B Cue Listener

The MATLAB receiving end of the ADS-B cue tasker. It is the first piece of the resource manager: it shows which aircraft can be collected on, with which DTV tower, and when.

## Concept

The cue tasker is `adsb-console --headless` from the [ADSB-remoter](https://github.com/lhilleMAT2022/ADSB-remoter) repo. It runs as the `adsb-cue` service on the ADS-B Raspberry Pi (`pi2@192.168.10.131`) and watches the local dump1090 feed. For every aircraft it:

- predicts the flight path over the next 10 minutes;
- works out the bistatic geometry to our receive site for every UHF DTV tower;
- keeps the time windows in which the predicted bistatic SNR stays above the detection threshold.

It then "rings the bell": it sends one JSON message per aircraft carrying up to 8 opportunities, ranked by peak SNR and fitted into one Ethernet frame. The messages go out as UDP multicast to `239.192.10.1:31986`. On the deployed Pi each message is compressed (see Framing); a compressed 8-opportunity cue is about 700 B on the wire.

Deciding what to actually collect, when, and with which illuminator is the collection system's job. `CueListener` only listens. It keeps the latest cue for each aircraft and answers "what are the best opportunities right now?".

| Message | Meaning |
| :--- | :--- |
| `track_cue` | Latest prediction for one aircraft (`prediction.revision` increases). It holds up to 8 opportunities. Each names an illuminator (`emitter_id` = `dtv:<facility>:<rf channel>:<MHz>`, plus numeric `carrier_frequency_hz` and `rf_channel`) and lists its predicted windows: start/end, peak and mean SNR, and bistatic range and Doppler limits. The model settings (`models`) appear once per cue. |
| `track_cue_withdrawal` | The aircraft was dropped. Forget that prediction. |
| `cue_heartbeat` | Sender health, every 10 s: `starting`, `running`, `degraded` (no ADS-B for more than 20 s, or a send failure) or `stopping`. |
| `cue_snapshot_begin` / `_end` | Brackets a full resend of every active cue, every 60 s. |

The message contract is [`docs/system/ICD_Messages.md`](../docs/system/ICD_Messages.md): §1.3 for transport and ports, and §2 for the CT messages. Where each software item fits is in [`docs/system/System_Architecture.md`](../docs/system/System_Architecture.md). The listener applies the receiver rules in ICD §2.0:

- keep the `track_cue` with the highest `prediction.revision` per `track_id`;
- delete a track on a withdrawal whose `withdrawn_prediction_revision` is at least the revision held;
- drop any `message_id` it has already seen;
- count a snapshot as complete when the number of cues received with its `snapshot_id` equals the `published_track_count` in `cue_snapshot_end` (`Stats.SnapshotsComplete`/`SnapshotsIncomplete`, `LastCompleteSnapshotUtc`). An incomplete snapshot is repaired by the next one, 60 s later.

**Schema 2.0.0 (ICD Draft B).** Times are integer epoch milliseconds in `*_utc_ms` fields; `helperCueParseUtc` turns them into UTC datetimes. The listener drops messages whose `schema_version` isn't 2.x (`Stats.UnsupportedVersion`).

**Framing (ICD §1.3).** A datagram is either plain JSON (first byte `{`) or compressed: `0xDC`, a dictionary id, then raw deflate of the JSON with that preset dictionary. The listener detects which, per datagram.
- **Dictionaries:** the released ones ship in `CueListener/dictionaries/`, copied from their master in ADSB-remoter `schemas/dictionaries/`, and are checked against their SHA-256 when the listener is constructed.
- **Decoding:** uses `java.util.zip` only, which also works in compiled apps (`docs/system/analysis/deployability/`).
- **Counters:** `Stats.PlainDatagrams`, `CompressedDatagrams` and `FrameErrors`.

The JSON schemas are in the ADSB-remoter repo (`schemas/*-2.0.0.json`, also embedded in the ICD). They use the same bistatic convention as `BistaticDataAnalysis`: `R_excess = R_tx + R_rx − L`, and `f_D = −(fc/c)·dR_excess/dt`.

SNR values are **pre-integration** estimates from the bistatic radar equation. Use them to rank opportunities, not as a detection prediction.

## Usage

```matlab
addpath CueListener
L = runCueListener('Duration_s', 120);        % console summary + window timeline
activeCues(L)                                 % one row per aircraft, best first
opportunities(L, "adsb:A8D5A0")               % every predicted window for one aircraft
plotCueWindows(L)

L = runCueListener('Duration_s', Inf, 'LogFile', "cues.jsonl");   % keep a log; Ctrl-C to stop
L = CueListener.replay("cues.jsonl");                             % work offline from a log
```

For your own loop, a resource manager can use `CueListener` directly:

```matlab
L = CueListener('MessageFcn', @(msg, L) disp(msg.message_type));
start(L);
poll(L);          % or CueListener('Background', true) to poll from a timer
stop(L);
```

- **Call signs:** emitter ids show as call signs, such as "WUTF-TV ch19", using the FCC DTV table in `TestSetupTesting/siteData/20_DTV_direct_path_input.csv`. It is the same table the cue tasker uses and the one `dtvPredictDirectPath` reads. Pass `'DtvTableFile'` to use another copy.
- **Site geometry:** the receive-site positions and antenna pointing are in `TestSetupTesting/SiteGeometry.md`. `dtvPredictDirectPath`, `dtvAbsoluteLevelCheck` and `dtvFitPointing` compare measured DTV levels with levels predicted from that geometry.
- **Log format:** `LogFile` output matches the ADSB-remoter `tools/cue_capture.py` JSONL format, so either tool's logs can be replayed here.

## Network notes

- **Java multicast socket:** MATLAB's `udpport` can join a multicast group only on Windows (`configureMulticast` raises `PlatformNotSupported` on Linux), and it cannot choose the interface that joins. The listener therefore uses a `java.net.MulticastSocket`.
- **Join interface:** the socket joins on `InterfaceAddress`, which defaults to `192.168.10.41`, the collection desktop's `eno1`. The desktop's default route is its Wi-Fi, so a join without an explicit interface would go out on the wrong network. On another machine on the data network, pass its own 192.168.10.x address.
- **Same network only:** the sender uses TTL 1, so listeners must be on 192.168.10.0/24.
- **Buffer size:** every 60 s the sender resends all active cues in one burst, which can overflow a default kernel socket buffer. The listener asks for 8 MiB. `Stats.SequenceGaps` counts any datagrams lost anyway.
- **Monitoring alongside MATLAB:** the socket shares its port, so socat or `cue_capture.py` can listen at the same time. The stream is compressed, so give each datagram its own socat child process (`UDP4-RECVFROM` + `fork`) and decode the base64 lines with ADSB-remoter's `tools/cue_decode.py`:
  ```bash
  socat -u UDP4-RECVFROM:31986,reuseaddr,ip-add-membership=239.192.10.1:192.168.10.41,fork SYSTEM:'base64 -w0; echo' \
    | ~/Documents/ADSB-remoter/.venv/bin/python ~/Documents/ADSB-remoter/tools/cue_decode.py | jq -c .
  ```

## Tests

```matlab
runtests('CueListener/tests/CueListenerTest.m')
```

The fixture holds 20 consecutive real CT 2.0.0 datagrams from the Pi (2026-09-26 15:32 UTC), stored as their exact compressed wire bytes. The tests cover:
- decoding the compressed stream;
- plain and compressed framing, unknown frames and dictionaries, and the dictionary checksum;
- replay, ranking, expiry and revision ordering;
- withdrawals, duplicates, sequence gaps, sender restarts and snapshot completeness;
- dropping older schema versions;
- the timeline plot;
- a real UDP socket receiving compressed datagrams on loopback, with a log round trip.
