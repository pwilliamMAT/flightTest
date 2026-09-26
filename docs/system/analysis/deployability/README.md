# Deployability probe: cue reception in a compiled MATLAB app

The Architecture's Application Deployment Policy requires every MATLAB item to run as a MATLAB Compiler standalone app on the MATLAB Runtime (rule 5 and open item 4).

This probe checks the two things the cue stream needs from such an app, on Linux, without `udpport` (whose multicast support is Windows-only, CR-2):

1. Joining the CT multicast group on the data-network interface, receiving live datagrams, and running `jsondecode` on them, using `java.net.MulticastSocket`.
2. Decoding a cue that Python compressed with raw deflate and a preset dictionary (the CR-5 encoding), using `java.util.zip.Inflater` through `InflaterOutputStream` only, with no MATLAB-bundled Java libraries.

## Run

```bash
python3 make_probe_payload.py        # writes cue.json, cue.dict, cue.deflate here (not committed)
```

```matlab
opts = compiler.build.StandaloneApplicationOptions('cueProbe.m', 'OutputDir', 'build', ...
    'AdditionalFiles', {'cue.deflate', 'cue.dict', 'cue.json'});
compiler.build.standaloneApplication(opts);
```

```bash
build/run_cueProbe.sh <MATLAB or MATLAB Runtime root> 25 192.168.10.41   # seconds, join interface
```

## Result, 2026-09-26 (R2026a, Ubuntu 26.04, RF Collection Desktop)

- **Build:** took 6 s. No unresolved symbols and no excluded files.
- **Runtime dependencies:** only MATLAB Base Runtime, Standard Runtime Addon and Graphics Runtime Addon. The Instrument Control Toolbox is **not** needed.
- **Output:**

```
deployed=1  java=1.8.0_202
inflate+dictionary: 1005 -> 7958 bytes, byte-exact=1, jsondecode icao=A7946A
multicast on 192.168.10.41 for 25s via eno1: cue_heartbeat=3, cue_snapshot_begin=1, cue_snapshot_end=1, track_cue=1
PROBE OK
```

**Conclusion:** Java multicast and in-memory inflate with a preset dictionary both work in a compiled standalone app, so CR-2 and CR-5 are deployable. The N320, Pluto, `serialport` and `tcpserver` parts of open item 4 are still to be checked.
