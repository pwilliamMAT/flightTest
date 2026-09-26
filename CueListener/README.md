# ADS-B Cue Listener

The MATLAB receiving end of the ADS-B cue tasker. It is the first piece of the resource manager: it shows which aircraft can be collected on, with which DTV tower, and when.

## Concept

The cue tasker is `adsb-console --headless` from the [ADSB-remoter](https://github.com/lhilleMAT2022/ADSB-remoter) repo. It runs as the `adsb-cue` service on the ADS-B Raspberry Pi (`pi2@192.168.10.131`) and watches the local dump1090 feed. For every aircraft it:

- predicts the flight path over the next 10 minutes;
- works out the bistatic geometry to our receive site for every UHF DTV tower;
- keeps the time windows in which the predicted bistatic SNR stays above the detection threshold.

It then "rings the bell": it sends one JSON message per aircraft carrying up to three opportunities, ranked by peak SNR. The messages go out as UDP multicast to `239.192.10.1:31986`.

Deciding what to actually collect, when, and with which illuminator is the collection system's job. `CueListener` only listens. It keeps the latest cue for each aircraft and answers "what are the best opportunities right now?".

| Message | Meaning |
| :--- | :--- |
| `track_cue` | Latest prediction for one aircraft (`prediction.revision` increases). It holds up to 3 opportunities; each names an illuminator (`emitter_id` = `dtv:<facility>:<rf channel>:<MHz>`) and lists its predicted windows with start/end, peak and mean SNR, and bistatic range and Doppler limits. |
| `track_cue_withdrawal` | The aircraft was dropped. Forget that prediction. |
| `cue_heartbeat` | Sender health, every 10 s: `starting`, `running`, `degraded` (no ADS-B for more than 20 s, or a send failure) or `stopping`. |
| `cue_snapshot_begin` / `_end` | Brackets a full resend of every active cue, every 60 s. |

The JSON schemas are in the ADSB-remoter repo (`schemas/*-1.1.0.json`). They use the same bistatic convention as `BistaticDataAnalysis`: `R_excess = R_tx + R_rx − L`, and `f_D = −(fc/c)·dR_excess/dt`.

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

- **Call signs:** pass `'DtvTableFile'` pointing to the FCC DTV CSV (`TestSetupTesting/siteData/20_DTV_direct_path_input.csv` on the branches that carry it) to show call signs such as "WUTF-TV ch19" instead of raw emitter ids.
- **Log format:** `LogFile` output matches the ADSB-remoter `tools/cue_capture.py` JSONL format, so either tool's logs can be replayed here.

## Network notes

- **Java multicast socket:** MATLAB's `udpport` can join a multicast group only on Windows (`configureMulticast` raises `PlatformNotSupported` on Linux), and it cannot choose the interface that joins. The listener therefore uses a `java.net.MulticastSocket`.
- **Join interface:** the socket joins on `InterfaceAddress`, which defaults to `192.168.10.41`, the collection desktop's `eno1`. The desktop's default route is its Wi-Fi, so a join without an explicit interface would go out on the wrong network. On another machine on the data network, pass its own 192.168.10.x address.
- **Same network only:** the sender uses TTL 1, so listeners must be on 192.168.10.0/24.
- **Buffer size:** every 60 s the sender resends all active cues in one burst of about 8 kB per aircraft, which can overflow a default kernel socket buffer. The listener asks for 8 MiB. `Stats.SequenceGaps` counts any datagrams lost anyway.
- **Monitoring alongside MATLAB:** the socket shares its port, so `socat` or `cue_capture.py` can listen at the same time. With socat, keep `-b 65535`:
  ```bash
  socat -b 65535 -u UDP4-RECV:31986,reuseaddr,ip-add-membership=239.192.10.1:192.168.10.41,rcvbuf=8388608 STDOUT | jq -c .
  ```

## Tests

```matlab
runtests('CueListener/tests/CueListenerTest.m')
```

The fixture holds 16 real datagrams from the Pi, captured on 2026-09-26. The tests cover replay, ranking, expiry, revision ordering, withdrawals, sequence gaps and sender restarts, the timeline plot, and a real UDP socket receiving on loopback, with a log round trip.
