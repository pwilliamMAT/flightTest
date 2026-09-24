# Diagnostic reports

Single-file HTML diagnostic reports from hardware and calibration troubleshooting. They are **not** members of the accepted nine-report family in `../reports/`, and they are not listed in `../index.html` or `../metadata/family_manifest.json`.

Each report states its question, result, engineering decision, still-unknown items, evidence class, method, code navigation and claim boundary, following `../howToUpdateReports.md`. Charts and data are embedded in the file; Tailwind CSS and Chart.js load from public CDNs.

To promote a diagnostic into the published site, review it as a candidate per `../howToUpdateReports.md`, then add it to `../index.html` and the metadata records before merging to `main`.

| Report | Question | Evidence dates |
| --- | --- | --- |
| [PlutoCombPresence_Diagnostic_V1.html](PlutoCombPresence_Diagnostic_V1.html) | Is the Pluto calibration signal reaching the N320, and is the receive chain fit to measure it? Includes the single-carrier loop closure, the receive-chain overload at N320 gain [30 50], channel-boundary loop tests at [10 0] from 476 to 602 MHz, the range-Doppler dynamic range the overload costs (about 13.5 dB), and a map and level table of every DTV emitter in the site's transmitter table. | 2026-07-28 to 2026-09-24 |
