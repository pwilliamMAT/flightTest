# Receive Site Geometry

Current layout of the passive-radar receive site and the Pluto calibration injector, as described by the operator on 2026-09-24. Update this file whenever antennas or the injector move; the calibration analyses depend on it.

## Receive site

| Item | Value |
| --- | --- |
| Receive system location (used in predictions) | 42.29917940712679 N, 71.34964782414613 W (about 77 ft south-east of REF; close enough for the 9–100 km tower paths) |
| REF antenna | 42.299325729126025 N, 71.34985194911563 W (Google Maps, 2026-09-24) |
| SURV antenna | 42.29932832679127 N, 71.34955294673453 W (Google Maps, 2026-09-24) |
| Stairwell (Pluto, collection PC) | 42.299491169102254 N, 71.3498772818933 W (Google Maps, 2026-09-24) |
| Collection PC | Glass-enclosed stairwell at the top of the parking structure |
| Receive antenna height used in predictions | 10 m above ground (assumed; not surveyed) |

## Antenna and injector layout

The three positions form a near-right triangle (96° at the REF antenna). Distances and bearings below are computed from the Google Maps positions in the table above; they replace the paced estimates (65 ft, 91 ft, 112 ft) recorded earlier on 2026-09-24. Corrected on 2026-09-24: SURV is **east** of REF (an earlier version of this file, and of the published diagnostic, had it west).

| From | To | Direction | Distance |
| --- | --- | --- | --- |
| REF antenna | Stairwell (Pluto, collection PC) | 353.5° true (just west of north) | 61 ft (18.5 m) |
| REF antenna | SURV antenna | 89.3° true (east) | 81 ft (24.7 m) |
| SURV antenna | Stairwell | 304.1° true (north-west) | 106 ft (32.3 m) |

```text
            N
            ^
            |   Stairwell (Pluto, PC)
            |   o
            |   | \
            |   |   \ 106 ft
            |   |     \
            | 61 ft     \
            |   |         \
            |   o-----------o
            |   REF Yagi    SURV Yagi
            |   <-- 81 ft -->
```

Each rotator's controller is in a weather enclosure about 6–8 ft from its antenna, powered from a 15 VAC wall supply; the rotator and the antenna's built-in LNA are powered up the coax. The rotator turns only while the controller's button is held, and each press alternates direction; there is no position feedback.

## Antenna pointing (2026-09-24)

| Antenna | Pointing (true) | Notes |
| --- | --- | --- |
| REF Yagi (N320 RF1:RX2) | about 10° | The stairwell (353.5°) is about 16.5° off boresight; the eastern DTV towers (76–88°) are about 66–78° off. |
| SURV Yagi (N320 RF0:RX2) | about 270° (west) | Looks along the REF–SURV leg toward the REF mast. The stairwell (304.1°) is about 34° off boresight; the eastern DTV towers are about 170° off, behind it. |

The operator's description read "the REF antenna is pointed around 10 degrees True whereas the REF antenna is pointed West"; one of the two must be SURV. The assignment above (REF north, SURV west) is the one consistent with the loop tests, where REF receives the stairwell carrier more strongly than SURV (REF also has a second LNA). The DTV absolute-level check (`dtvAbsoluteLevelCheck.m`, `dtvFitPointing.m`) was meant as the independent check, but on 2026-09-24 it could not fit the pointing: nine of the ten towers with a clear pilot sit at 76–88°, and REF levels are distorted by overload.

Channel 22 from Hudson (309°, 15 km) is strong on REF but weak on SURV, although it is only 39° off SURV's boresight. From SURV the stairwell bears 304.1°, within about 5° of Hudson, so the stairwell structure most likely shadows Hudson for SURV. From REF the stairwell is at 353.5°, about 44° from Hudson, and does not block it.

## Injector placement options

A 100 ft SMA cable lets the Pluto stay in the stairwell with its transmit antenna out on the deck. Positions in the table are relative to REF; "off" is the angle from each antenna's boresight. Free-space changes are relative to the stairwell position at 540 MHz; the pattern column uses the simple Yagi model in `dtvFitPointing.m` (12 dBi, 45° beamwidth, 20 dB front-to-back), which is only a rough guide.

| Position | Cable run from stairwell | REF: distance, off | SURV: distance, off | Change vs. stairwell, before cable loss and glass |
| --- | --- | --- | --- | --- |
| Stairwell (now) | – | 61 ft, 16.5° | 106 ft, 34° (through glass) | – |
| Midpoint of the REF–SURV leg | 76 ft | 40.5 ft, 79° | 40.5 ft, 1° | SURV about +15 dB; REF about −15 dB |
| 15 ft north of the midpoint | 65 ft | 43 ft, 59° | 43 ft, 20° | SURV about +12 dB; REF about −15.5 dB |

100 ft of cable costs roughly 3 dB (LMR-400), 6 dB (LMR-240), 10–11 dB (RG-58) or 20 dB or more (RG-174) at 540 MHz. Taking the injector out of the glass stairwell also removes an unknown glass loss. REF has plenty of margin to give up (+21 to +49 dB at gain 0 on 2026-09-24). Keep the injector antenna horizontally polarised like the Yagis.

Both Yagis are 12 dBi class UHF TV antennas (Report 01B), horizontally polarised. Neither currently points at the main DTV towers, which are 9–11 km to the east (bearing 82–88° true).

## Receive chain (2026-09-24)

| Channel | Chain |
| --- | --- |
| REF (RF1:RX2) | Consumer HDTV Yagi with built-in LNA and rotator → antenna controller → **Nooelec Lana wideband LNA (20 MHz–4 GHz)** → about 100 ft coax → N320 |
| SURV (RF0:RX2) | Consumer HDTV Yagi with built-in LNA and rotator → antenna controller → coax → N320 (no second LNA; run length not recorded) |

The Lana's gain and compression point at 600 MHz are not published on the vendor pages and have not been measured here.

### Overload at the N320 input

The local DTV cluster is predicted at about −14 dBm per channel at an isotropic antenna (`dtvPredictDirectPath`), before any antenna or LNA gain. Gain sweeps on 2026-09-24 show the receive chain is not linear at the `[30 50]` ([SURV REF]) RadioGain that `runLocalHDTVCapture.m`, the Pluto loop tests and `dtvAbsoluteLevelCheck.m` have used:

- ATSC pilot at 599 MHz: SURV follows the gain only from 0 to about 10 dB. REF does not follow it even from 0 to 5 dB, and above 35 dB the REF pilot falls. Total output stays near −10 to −12 dBFS whatever the gain.
- Pluto carrier at 602.05 MHz (`plutoCwGainSweep`): the REF tone stays at about −52 dBFS from gain 0 to 40, while the carrier-off floor rises 13 dB between gain 0 and 5. REF has its best margin at gain 0 (35 dB), SURV at gain 10 (15 dB). From SURV gain 15 up, the margin collapses.

With the second LNA fitted, REF is overloaded at every N320 gain. Removing the Lana or adding a pad, ideally with a channel bandpass filter on both inputs, should restore a linear range. Until then, use RadioGain `[10 0]` for Pluto loop tests, and treat absolute levels and coupling figures from REF as lower bounds rather than linear measurements.

## Local DTV transmitters

The transmitter table is [`20_DTV_direct_path_input.csv`](20_DTV_direct_path_input.csv) (call sign, RF channel, centre frequency, transmitter location and height above mean sea level, ERP/EIRP, directional flag). UHF channels the N320 can tune (450 MHz and up), with bearing and distance from the receive site:

| RF ch | Centre (MHz) | Stations | Site | Bearing (true) | Distance |
| --- | --- | --- | --- | --- | --- |
| 19 | 503 | WUTF-TV | CBS Tower (MA) | 82° | 9.4 km |
| 20 | 509 | WBZ-TV | CBS Tower (MA) | 82° | 9.4 km |
| 21 | 515 | WSBK-TV | CBS Tower (MA) | 82° | 9.4 km |
| 22 | 521 | WDPX-TV / WBPX-TV | Hudson (MA) | 309° | 15.1 km |
| 23 | 527 | WPXG-TV / WYDN | Fort Mountain (NH) | 1° | 98.4 km |
| 26 | 545 | W26EU-D | FM128 Tower (MA) | 85° | 10.4 km |
| 29 | 563 | WNEU | CBS Tower (MA) | 82° | 9.4 km |
| 32 | 581 | WBTS-CD / WGBX-TV | CBS Tower (MA) | 82° | 9.4 km |
| 33 | 587 | WCVB-TV | CBS Tower (MA) | 82° | 9.4 km |
| 34 | 593 | WFXT | Cabot Street (MA) | 88° | 10.9 km |
| 35 | 599 | WHDH / WLVI | Newton (MA) | 83° | 11.1 km |
| 36 | 605 | WCEA-LD | John Hancock Tower (MA) | 76° | 23.3 km |

Bearings and distances are computed by `dtvPredictDirectPath.m`. Channel boundaries between adjacent on-air channels (candidate gaps for a calibration carrier): 506, 512, 518, 524, 584, 590, 596 and 602 MHz.
