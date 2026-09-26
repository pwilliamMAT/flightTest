# As-Built Record

What is actually deployed and running, as of **2026-09-26**. [System_Architecture.md](System_Architecture.md) is the as-designed view; this file records the as-built one. Where they differ, the difference is logged as a change request ([CR-8](Change_Requests.md#cr-8-as-built-corrections-to-system_architecturemd)).

Update this file whenever a host, service, address or deployed version changes.

## Software items

| ID | Item | As-built state | Code (repo, branch) | Runs on |
|---|---|---|---|---|
| AR | ADSB Receiver | Operating: dump1090 in Docker (`jraviles/dump1090`), SBS on TCP 30003 | — | Pi |
| CT | ADSB Cue Tasker (ADSB-Remoter) | Operating as systemd `adsb-cue` (enabled at boot). Publishes **CT 2.0.0, compressed with dictionary 1**, to multicast `239.192.10.1:31986`: at most 8 opportunities per cue, fitted to one frame (1472 B) | [ADSB-remoter](https://github.com/lhilleMAT2022/ADSB-remoter) `feature/passive-radar-cueing` | Pi, `~/flightTest/ADSB-remoter` |
| RM | Resource Manager | Not built. First piece: **CueListener**, which receives and ranks cues (MATLAB, no tasking) | flightTest `feature/adsb-cue-listener`, `CueListener/` | RF Collection Desktop (run by hand) |
| RC | RF Collector | Rev 1 capture scripts (`TestSetupTesting/runLocalHDTVCapture.m`, `log_iq_n320_2antennas.m`); not driven by tasks | flightTest | RF Collection Desktop |
| SP | Signal Processor | Offline pipeline (`BistaticDataAnalysis/`); the detector is not yet producing truth-matched detections | flightTest | desktops |
| CM | Calibration Manager | Pluto calibration scripts, plus a geometry-based DTV level check (`dtvPredictDirectPath`, `dtvAbsoluteLevelCheck`, `dtvFitPointing`). None of these are on `main` yet | flightTest `feature/pluto-azimuth-environment-scan` (the `dtv*` scripts are also on `feature/adsb-cue-listener`) | RF Collection Desktop |
| TR, RD, AM, AC | Tracker, Report & Display, Activity Manager, Antenna Controller | Not built | — | — |
| Time Source | chrony + gpsd | chrony is synced to **internet NTP** through the desktop NAT. GPS/PPS reference clocks are configured but not locked | — | Pi |

## Hosts and network

| Host | Addresses | Notes |
|---|---|---|
| RF Collection Desktop `rf-lenovo-mw` (Ubuntu 26.04) | `eno1` 192.168.10.41/24 (data); `wlp2s0` 172.31.214.40 (internet, MathWorks personal-device Wi-Fi); `enx00e022417f29` 192.168.2.10; ZeroTier 172.25.20.164 | sudo needs a password. ufw installed but **disabled**. Default route via Wi-Fi |
| ADS-B Raspberry Pi 4 `raspberrypi` (Debian 11) | `eth0` 192.168.10.131/24; ZeroTier 172.25.127.167 (network `12ac4a1e71f93ac3`) | User `pi2`, passwordless sudo. SSH from the desktop with `~/.ssh/id_ed25519_flighttest`. uv 0.12 with Python 3.13 for CT |
| USRP N320 | 192.168.10.2 | |

**How the Pi reaches the internet** (added 2026-09-25, survives reboots):

- **Desktop:**
  - `/etc/sysctl.d/90-pi-gateway.conf` sets `net.ipv4.ip_forward=1`.
  - `pi-gateway-nat.service` is a systemd oneshot that adds `iptables -t nat POSTROUTING -s 192.168.10.131 -o wlp2s0 -j MASQUERADE` if it is missing. Change `-o wlp2s0` if the desktop's internet moves off Wi-Fi.
- **Pi:** `/etc/dhcpcd.conf` sets `static routers=192.168.10.41` and `static domain_name_servers=8.8.8.8 144.212.95.8`. The original is at `/etc/dhcpcd.conf.bak-20260926`.
- **Why it matters:** the Pi needs internet for NTP (see Time Source), ZeroTier, and installing software with `uv`.

**Ports in use on the data network:**

| Port | Use |
|---|---|
| TCP 30003 | dump1090 SBS, on the Pi |
| UDP multicast `239.192.10.1:31986` | CT cue stream, TTL 1 |

No other system ports from the ICD are in use yet.

## CT service on the Pi

| | |
|---|---|
| Unit | `/etc/systemd/system/adsb-cue.service`, from ADSB-remoter `deploy/adsb-cue.service` |
| Configuration | `deploy/pi-observers.ini`: only the surveyed receive site, 10 dBi / NF 3 dB / 8 MHz, set explicitly because the INI loader defaults the gain to 0. `deploy/pi-cue-config.json`: multicast, `source_address` 192.168.10.131, `encoding: deflate_dictionary`, `dictionary_id: 1`, 1472 B datagrams, up to 8 opportunities, `summary` off |
| Behaviour | Exits 1 if the SBS source is unreachable or closes, and `Restart=on-failure` retries after 10 s. At boot it normally starts before dump1090 and connects on the second try. SIGTERM sends a final `stopping` heartbeat |
| Logs | `sudo journalctl -u adsb-cue`. The Pi's journald keeps only notice and above, so the unit sets `SyslogLevel=notice` |
| Control from the desktop | `ssh pi2@192.168.10.131 'sudo systemctl status\|restart\|stop adsb-cue'` |
| Update | `cd ~/flightTest/ADSB-remoter && git pull --ff-only && ~/.local/bin/uv sync --no-dev && sudo systemctl restart adsb-cue`. If the unit file changed, copy it to `/etc/systemd/system/` and run `daemon-reload` first |
| Load | About 407 ms of CPU per prediction on the Pi (2 observers × 16 emitters); predictions are limited to about one core |

## Monitoring the cue stream on the desktop

Join the multicast group on `192.168.10.41`, because the default route is Wi-Fi. netcat cannot join multicast groups.

The stream is compressed (CT 2.0.0), so decode it per datagram. From the ADSB-remoter checkout:

```bash
# Watch: socat gives one base64 line per datagram (RECVFROM + fork), cue_decode.py turns it into JSON
socat -u UDP4-RECVFROM:31986,reuseaddr,ip-add-membership=239.192.10.1:192.168.10.41,fork SYSTEM:'base64 -w0; echo' \
  | .venv/bin/python tools/cue_decode.py | jq -c .

# Check: decode, validate against the schemas, and summarise gaps, snapshots, sizes and one-frame fit
uv run python tools/cue_capture.py --bind 0.0.0.0:31986 --multicast-group 239.192.10.1 --multicast-interface 192.168.10.41 --duration-s 240 [--print]
```

In MATLAB, use `runCueListener` (flightTest `CueListener/`). It decodes both framings and ships dictionary 1 in `CueListener/dictionaries/`.
