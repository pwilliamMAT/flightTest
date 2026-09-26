# Engineering Notes

Lessons verified on this testbed. Each item is something that cost time, or would have, once. They are grouped by area, with the practice each one suggests. The dated evidence is in [Verification_Log.md](Verification_Log.md).

## Systems engineering practice

- **Keep as-designed and as-built apart.**
  - [System_Architecture.md](System_Architecture.md) says what should exist; [As_Built.md](As_Built.md) says what runs, where and how it is started.
  - Several facts (NAT for the Pi, NTP source, service names, interfaces) were true only in operators' heads until they were written into the as-built record.
- **Status claims need evidence.**
  - The ICD §0 levels (Proposed → Frozen) work because each step has a check.
  - Record every check in the verification log. Commit the raw capture under [evidence/](evidence/) when it is small; otherwise say where it is, or that it wasn't kept.
- **Implementation will get ahead of the documents; log it.**
  - Use a change request: a deviation, correction, clarification or proposal ([Change_Requests.md](Change_Requests.md)).
  - Example: CR-1. The top-3 opportunity cap was needed to make cues arrive at all, but it contradicts ICD §2.3 until the owner decides.
- **Keep one controlled copy of shared configuration data.**
  - Today the DTV emitter table exists in four places (see the [README](README.md)), and the receive-site position in three inconsistent versions (CR-7).
  - Each copy is a place for drift.
- **Measure before redesigning a format.** The cue-traffic analysis showed that the constraint is datagram size, not bandwidth. That changes which options matter.
- **Build test fixtures from real wire captures.** The CueListener fixture is 16 real datagrams from the Pi. It caught details (null handling, struct-array decoding, revision ordering) that synthetic messages would not.
- **Watch for tests that pass when their data is missing.** ADSB-remoter `tests/test_replay_cueing.py` returns early, and so passes, when its external replay corpus is absent. A missing dependency should produce a skip, never a pass.

## Network and multicast

- **Join multicast on the data-network interface explicitly.**
  - The desktop is multi-homed and its default route is Wi-Fi, so an unspecified join goes out the wrong interface and hears nothing.
  - socat: `ip-add-membership=239.192.10.1:192.168.10.41`. Java: `joinGroup(group, NetworkInterface)`.
- **netcat cannot join multicast.** Use socat or a small script.
- **socat reads 8192-byte blocks by default**, so it truncates 8 kB cues. Always pass `-b 65535`.
- **Size receive buffers for snapshot bursts.** A snapshot sends every cued aircraft at once (about 8 kB each). The kernel default buffer (212 kB) overflowed during tests and showed up as sequence gaps. Use 8 MiB (`rmem_max` on the desktop is 50 MB).
- **Datagrams larger than one frame are fragmented.** Anything over 1472 B of UDP payload is sent in fragments, and losing one fragment loses the whole datagram. Every 8 kB `track_cue` is sent as 6 fragments. See [analysis/Cue_Traffic_Encoding.md](analysis/Cue_Traffic_Encoding.md).
- **A host without a default route cannot send multicast** (`ENETUNREACH`) unless the socket is bound to a source address or a multicast route exists. CT pins `source_address` to 192.168.10.131 for this reason.

## MATLAB

- **`udpport` multicast is Windows-only.**
  - `configureMulticast` raises `PlatformNotSupported` on Linux, and there is no way to choose the join interface.
  - Use `java.net.MulticastSocket` (CR-2). Verify it in the compiler deployability check.
- **MATLAB passes arrays to Java by copy.**
  - `stream.read(buf)` and `inflater.inflate(buf)` fill a Java-side copy, and the MATLAB `buf` stays empty.
  - Let Java own the bytes:
    - for datagrams, read back through `DatagramPacket.getData()`;
    - for decompression, write the compressed bytes *into* a `java.util.zip.InflaterOutputStream` and take the result from `ByteArrayOutputStream.toByteArray()`.
  - Avoid `org.apache.commons.io`: it's bundled with MATLAB, but it isn't part of standard Java.
- **`DatagramPacket.receive` shrinks the packet length** to the last datagram's size. Reset it with `setLength(bufferSize)` before every receive, or later datagrams are silently truncated.
- **`udpport` datagram writes split at `OutputDatagramSize`**, which defaults to 512 bytes. Set it to 65507 when one message must be one datagram.
- **`jsondecode` handles the cue schema well.** `null` becomes `[]`; arrays of objects with identical keys become struct arrays (otherwise cell arrays); nested objects become structs. Consumers should accept both struct and cell arrays.
- **Class redefinition needs `clear`.** While an instance of a handle class exists in the session, MATLAB keeps using the old definition. `clear` the objects and the class name before re-running tests.
- **In-memory decompression works through `java.util.zip`.** gzip and raw deflate with a preset dictionary take 0.1–0.4 ms per cue ([analysis/check_matlab_decompress.m](analysis/check_matlab_decompress.m)).
- **Java-based I/O deploys cleanly.**
  - A MATLAB Compiler standalone app using `java.net.MulticastSocket` and `java.util.zip` ran on the Runtime.
  - It needed only the base, standard and graphics runtime add-ons; avoiding `udpport` also avoids the Instrument Control Toolbox runtime.
  - Compiling a small probe takes seconds, so do it before designing around a toolbox feature ([analysis/deployability/](analysis/deployability/)).

## Hosts, time and services

- **Check clock offsets before trusting any timing.**
  - Without internet NTP, the Pi's GPS/PPS reference clocks were not locked and the Pi ran about 15 s slow. That shifts every cue timestamp and all ADS-B truth, and can masquerade as a truth-alignment problem in the analysis.
  - Quick check from the desktop: compare `ssh pi2@192.168.10.131 date +%s.%N` with local time, and look at `chronyc tracking` on the Pi.
- **Units must survive a service starting before its data source.** CT exits non-zero when dump1090 isn't up yet, and systemd `Restart=on-failure` retries. After a reboot it connects on the second attempt.
- **Journald on the Pi keeps only notice and above** (`MaxLevelStore=notice`). A service that logs at INFO needs `SyslogLevel=notice` in its unit. Reading the journal as `pi2` needs sudo.
- **Configuration loaders with silent defaults bite.** CT's observer INI loader defaults `receiverGainDbi` to 0 dBi, while the built-in observer uses 10 dBi. Always set RF parameters explicitly in deployed configuration.
- **Default observer lists leak into production.** CT's built-in observers include the CBS tower as a "remote observer", which produced opportunities for a receiver that doesn't exist. Deployed CT uses `deploy/pi-observers.ini` with the real site only.

## Software (CT specifics worth knowing)

- **Textual's `run_worker(..., exclusive=True)` cancels every worker in the same group.** In CT, the first 60 s snapshot silently cancelled the ADS-B reader. Give each exclusive worker its own `group=`. Found only by a headless end-to-end run with a short snapshot interval.
- **Timestamp rebasing during replay.** Replaying recorded SBS without rebasing timestamps makes every track look stale against the wall clock, which is how the 2026-09-08 capture ended up with no track cues (ICD CT-1).
