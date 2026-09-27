# Diagnostic reports

Single-file HTML diagnostic reports from hardware, calibration and tracking troubleshooting. They are **not** members of the accepted nine-report family in `../reports/` and are not listed in `../metadata/family_manifest.json`. `../index.html` links them under "Diagnostic reports", in two groups: calibration scan reports and tracking scan reports.

Each report states its question, result, engineering decision, still-unknown items, evidence class, method, code navigation and claim boundary, following `../howToUpdateReports.md`. Charts and data are embedded in the file; Tailwind CSS and Chart.js load from public CDNs.

To add a diagnostic, put the file here, add a row to the right group below, and add a card to the matching group in `../index.html`.

## Calibration scan reports

Is the receive chain linear, and does a known signal get through it?

| Report | Question | Evidence dates |
| --- | --- | --- |
| [PlutoCombPresence_Diagnostic_V1.html](PlutoCombPresence_Diagnostic_V1.html) | Is the Pluto calibration signal reaching the N320, and is the receive chain fit to measure it? Includes the single-carrier loop closure, the receive-chain overload at N320 gain [30 50], channel-boundary loop tests at [10 0] from 476 to 602 MHz, the range-Doppler dynamic range the overload costs (about 13.5 dB), and a map and level table of every DTV emitter in the site's transmitter table. | 2026-07-28 to 2026-09-24 |

## Tracking scan reports

Does an aircraft pass produce a truth-matched detection? Newest first.

| Report | Question | Evidence dates |
| --- | --- | --- |
| [TimedCuedPasses_Diagnostic_V1.html](TimedCuedPasses_Diagnostic_V1.html) | With the capture timestamps fixed, do cued passes produce truth-matched detections, and what did the timing error do to the earlier results? The old captures were fifteen 1 s slices over about 87 s with the stamp 3.3 s early; captures are now contiguous and radio-timed to ±1–3 ms. Re-scored, no earlier session has a real detection. Two new passes (UAL659, RKJ948; six captures on 503, 521, 593 and 599 MHz) did not detect the cued aircraft; the two matches that occurred are other aircraft at chance level. Also covers pass timelines (about 135 s per channel), the PC's 100 Mb/s link and the relaxed direction rule, and a follow-up column test showing that DAL2779's 7 matches in a relaxed-rule 599 MHz capture (20260927T170344_599) are low-Doppler clutter-line detections, not the aircraft. | 2026-09-27 |
| [CuedPass_ThreeTower_Diagnostic_V1.html](CuedPass_ThreeTower_Diagnostic_V1.html) | Did the first cue-triggered, three-tower capture of an aircraft pass produce a truth-matched detection, and why did the overnight run take only one pass? No match at the standard gate; one two-detection candidate at 521 MHz (the only capture with the aircraft in the surveillance beam) after a 2.0–2.5 s timing correction. **Its 521 MHz candidate is withdrawn** (see the timed-passes report). Also documents the early capture start stamp, the fifteen 1 s segments per capture file, the analysis memory fix (13.45 → 5.3 GB), beam-aware cueing, and the case for more memory on the collection PC. | 2026-09-27 |
| [TrackingScan_NoDetection_Diagnostic_V1.html](TrackingScan_NoDetection_Diagnostic_V1.html) | Does an aircraft-tracking scan at 599 MHz with the lowered receive gain produce a truth-matched track? No: the detections are dominated by 60 Hz hum and other low-Doppler lines, and the one overlapping aircraft is absent even after stacking its predicted track. Also documents the hard-coded transmitter and the analysis memory limit. | 2026-09-24 to 2026-09-25 |
