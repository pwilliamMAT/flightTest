# Diagnostic reports

Single-file HTML diagnostic reports from hardware and calibration troubleshooting. They are **not** members of the accepted nine-report family in `../reports/`, and they are not listed in `../index.html` or `../metadata/family_manifest.json`.

Each report states its question, result, engineering decision, still-unknown items, evidence class, method, code navigation and claim boundary, following `../howToUpdateReports.md`. Charts and data are embedded in the file; Tailwind CSS and Chart.js load from public CDNs.

To promote a diagnostic into the published site, review it as a candidate per `../howToUpdateReports.md`, then add it to `../index.html` and the metadata records before merging to `main`.

| Report | Question | Evidence dates |
| --- | --- | --- |
| [PlutoCombPresence_Diagnostic_V1.html](PlutoCombPresence_Diagnostic_V1.html) | Is the Pluto calibration comb reaching the N320, and where is it lost? | 2026-07-28 to 2026-09-23 |
