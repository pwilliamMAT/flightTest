# Receive Site Geometry

Current layout of the passive-radar receive site and the Pluto calibration injector, as described by the operator on 2026-09-24. Update this file whenever antennas or the injector move; the calibration analyses depend on it.

## Receive site

| Item | Value |
| --- | --- |
| Receive system location | 42.29917940712679 N, 71.34964782414613 W |
| Collection PC | Glass-enclosed stairwell at the top of the parking structure |
| Receive antenna height used in predictions | 10 m above ground (assumed; not surveyed) |

## Antenna and injector layout

The three positions form a right triangle with the right angle at the REF antenna:

| From | To | Direction | Distance |
| --- | --- | --- | --- |
| REF antenna | Stairwell (Pluto, collection PC) | Due north | 65 ft (19.8 m) |
| REF antenna | SURV antenna | Due west | 91 ft (27.7 m) |
| SURV antenna | Stairwell | North-east (about 54.5° true) | 112 ft (34.1 m) |

```text
            N
            ^
            |        Stairwell (Pluto, PC)
            |               o
            |             / |
            |    112 ft /   | 65 ft
            |         /     |
   SURV Yagi o---------------o REF Yagi
             <---- 91 ft --->
```

## Antenna pointing (2026-09-24)

| Antenna | Pointing (true) | Notes |
| --- | --- | --- |
| REF Yagi (N320 RF1:RX2) | about 10° | The stairwell (0°) is about 10° off boresight; the eastern DTV towers (76–88°) are about 66–78° off. |
| SURV Yagi (N320 RF0:RX2) | about 270° (west) | The stairwell (54.5°) is about 145° off boresight, on the back side; the eastern DTV towers are about 170° off. |

The operator's description read "the REF antenna is pointed around 10 degrees True whereas the REF antenna is pointed West"; one of the two must be SURV. The assignment above (REF north, SURV west) is the one consistent with the 602.05 MHz loop test, where REF received the stairwell carrier 17 dB stronger than SURV. The DTV absolute-level check (`dtvAbsoluteLevelCheck.m`) fits the pointing from tower levels and is the independent check.

Both Yagis are 12 dBi class UHF TV antennas (Report 01B), horizontally polarised. Neither currently points at the main DTV towers, which are 9–11 km to the east (bearing 82–88° true).

## Local DTV transmitters

The transmitter table is [`siteData/20_DTV_direct_path_input.csv`](siteData/20_DTV_direct_path_input.csv) (call sign, RF channel, centre frequency, transmitter location and height above mean sea level, ERP/EIRP, directional flag). UHF channels the N320 can tune (450 MHz and up), with bearing and distance from the receive site:

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
