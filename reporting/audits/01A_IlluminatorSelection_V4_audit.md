# 01A Illuminator Selection V4 audit

## File protection

- Baseline retained: `ManagerReport/01A_IlluminatorSelection_V3.html` was copied before V4-only edits.
- V3 SHA-256 before V4 build: `DE2BBA3EFB71C3E2C8A616FF4FFFB5C57F2A23CFB78C98E9761EC0E919618E58`.
- V3 source-inventory SHA-256: `ED4C28BB0C6E1F82342990806131233D41510B3E9029563A46A915D14E4DEEC8`.
- V3 figure-inventory SHA-256: `EC6266959EDBFDC63F7899769278A30A234FC7E7A75E31D9D8E59C872C2E4849`.
- V3 audit SHA-256: `8BA547431212179DAB1EB8569496A5C5719E0FE97FF93199DF61ECDD92C0BD2F`.
- New report: `ManagerReport/01A_IlluminatorSelection_V4.html`.
- V3 HTML, V3 inventories, V3 audit, accepted Reports 01–06, source PowerPoints, Live Scripts, source figures, and presentations were not edited.
- V4 reuses the existing stable `01A_IlluminatorSelection_assets/` folder. No original asset was altered and no PowerPoint was generated.

## V4 outcome-first communication changes

Each major test now starts with an outcome panel directly under its title:

| Test | Result and metric | Why it matters | Engineering decision | Still unknown |
|---|---|---|---|---|
| Test 1 — rooftop/direct path | East Garage was historically recorded as clear toward Newton/Needham and obstructed toward Hudson/Marlborough; West Garage showed the opposite broad pattern. | Roof choice changes which broadcast direction can plausibly provide a direct-path reference. | Prototype at Apple Hill East Garage for office proximity and adjustment flexibility; retain LS Garage as a possible later collection site. | Installed role, lock, integrity, signal quality, and qualified Reference Path. |
| Test 2 — target region | Hudson 69.91 dB versus Newton 57.78 dB mean modeled FOV SNR; target power −67.3723 dBm versus −79.5023 dBm. | The historical model predicted stronger modeled illumination over the same region under Hudson assumptions. | Carry both cases into receiver-design analysis; label Hudson preferred only in the historical target-region comparison. | Verified transmitter parameters, current geometry, and field measurements. |
| Test 3 — RF-design inputs | Newton 596.3 MHz and Hudson 548 MHz; 6 MHz bandwidth; modeled direct paths −28.8871 dBm and −39.8370 dBm. | The values define candidate RF-budget operating cases. | Use the candidate cases and their historical predictions as inputs to `01B_ReceiveChainDesign`. | Current broadcast configuration, ERP, installed-chain headroom, impedance behavior, and Reference Path adequacy. |

Evidence and method remain below each outcome panel. The detailed Question, Why, Method, Evidence, Result, Decision, and Remaining uncertainty content was retained.

## Executive-answer verification

V4 separates three different statements that must not be conflated:

1. **Historical comparison preference:** the slide-42 target-region model favors Hudson, 69.91 dB over Newton, 57.78 dB.
2. **Prototype implementation decision:** Apple Hill East Garage was the documented practical prototype site because it was close to the office and could be adjusted easily; the site comparison favored the Newton/Needham direction there.
3. **Current uncertainty:** neither historical result verifies a current broadcast configuration, a measured direct path, a qualified Reference Path, collection suitability, or aircraft detection.

The report does not claim that the Hudson historical model preference became the first installed transmitter configuration.

## Site Viewer recovery

### Sources rechecked

- `LinkBudget/AppleHill_CustomizeBuildingsForRayTracingAnalysisExample.mlx`
- Its embedded package content and autosave package
- `LinkBudget/applehill.osm`
- `LinkBudget/LinkBudgetProgress.pptx`
- Existing V3 recovery record and stable Figure 1B asset

### What Figure 1B establishes

- It is the original 548 × 330 px Apple Hill building-footprint output embedded in the Live Script.
- The source reads `applehill.osm`, selects an Apple Hill area of interest, imports the buildings into Site Viewer, uses the candidate transmitter/Apple Hill receiver setup, and configures SBR ray tracing with up to three reflections and two diffractions.
- It supports the local-geometry question: which nearby buildings could influence the path close to the receiver?

### Exact limitation

No original Apple Hill 3D Site Viewer, line-of-sight, reflected-ray, or `plot(rays)` image was recoverable from the Live Script package, autosave package, LinkBudget PowerPoint media, or associated source folders. The autosave images are generic Chicago example screenshots and were not used. A source-faithful MATLAB recovery attempt recorded in V3 exceeded the Site Viewer tool limit; V4 did not reuse any incomplete output or generate a substitute.

V4 therefore retains the authentic geometry evidence and states that it is **not** measured received power, verified multipath, a rendered ray-path result, installed-antenna performance, Reference Path qualification, or collection acceptance.

## Candidate-tower source provenance

### Recovered chain

1. `Radio_Stations/Radio_Stations/data_from_web/BostonStationList.html` is a saved RabbitEars Boston `marketdetail` survey page.
2. `scraper.ipynb` contains `extract_boston_tv_towers.py`, which explicitly parses the saved page into station-level location, height, ERP, channel, and RF-program fields.
3. `LinkBudget/Radio_Tower_List.txt` is the direct machine-readable tower input used by the LinkBudget MATLAB workflow.
4. `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` parses that list, creates transmitter sites, and focuses the later HDTV comparison on Newton and Hudson.

### Limitation

No workspace artifact identifies Leif Hille, FlightTestAE, or another named person as the provider of the candidate list. No complete transformation record connecting every notebook output to the checked-in LinkBudget list was recovered. V4 reports the saved survey/parser provenance and the direct analysis input, but does not invent a handoff or data lineage.

## Figure-caption verification

Every retained figure caption now explicitly says:

- what the image shows;
- which engineering question it addresses;
- the result that matters;
- the decision it influenced; and
- what the figure does not prove.

The retained evidence set remains FIG-01 through FIG-05 and FIG-08. FIG-06 and FIG-07 remain omitted because their manager decision value is redundant with the stronger retained comparison figures. No figure was created, redrawn, recompressed, or changed.

## Quantitative verification

| Visible V4 claim | Primary source | Verification treatment |
|---|---|---|
| Hudson mean modeled FOV SNR: 69.91 dB | `LinkBudgetProgress.pptx`, slide 42 | Historical modeled comparison only. |
| Newton mean modeled FOV SNR: 57.78 dB | `LinkBudgetProgress.pptx`, slide 42 | Historical modeled comparison only. |
| Hudson modeled target power: −67.3723 dBm | `LinkBudgetProgress.pptx`, slide 42 | Historical model output only. |
| Newton modeled target power: −79.5023 dBm | `LinkBudgetProgress.pptx`, slide 42 | Historical model output only. |
| Hudson modeled direct path: −39.8370 dBm | `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` saved output | Model output, not received-power measurement. |
| Newton modeled direct path: −28.8871 dBm | `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` saved output | Model output, not received-power measurement. |
| Hudson case: 548 MHz; Newton case: 596.3 MHz | `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` | Historical modeled cases. |
| HDTV bandwidth: 6 MHz | `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` | Historical model input. |
| Target model: 6,000 ft and 0.5 m² bistatic RCS | `FlightTest_Bistatic_RadarAndCommsAnalysis.mlx` | Historical assumptions; earlier deck ROI label remains documented separately as 3,000 ft. |
| ERP discrepancy | Live Script placeholders versus `Radio_Tower_List.txt` station records | Preserved and not reconciled. |

## Source and asset packaging

- All V4-used images resolve relative to `01A_IlluminatorSelection_assets/`.
- No V4 HTML path contains `_human_story_work`.
- No V4 image is embedded as base64.
- The report now links to V4 source and figure inventories and this audit.
- Original source links remain local, descriptive, and unchanged in intent.

## Report-family placement and boundaries

- Report ID: `01A`
- Previous report: `01_NorthStarAndMotivation_V2.html`
- Next report: `01B_ReceiveChainDesign`
- Scope remains historical illuminator, receiver-site, and observation-geometry screening.
- RF components, installed hardware qualification, collection suitability, synthetic echo generation, signal-processing recovery, aircraft detection, tracking, and localization remain out of scope.

## Language review

V4 replaces buried or generic conclusions with direct statements:

- “Hudson became the preferred geometry in the historical target-region comparison.”
- “Rooftop geometry and practical access both mattered before receiver design.”
- “The analysis produced concrete candidate inputs for receive-chain reasoning.”
- “The historical model preference did not become a verified installed-transmitter selection.”

Terms retained for traceability—ERP, SBR, dBm, FOV SNR, and Reference Path—remain defined in nearby plain language or the glossary.

## Final status

READY WITH KNOWN GAPS

The V4 decisions, metrics, source provenance, and asset links are traceable. The known gap remains the unavailable original Apple Hill 3D Site Viewer or ray-path capture; V4 uses only the authentic embedded Apple Hill geometry output and makes that limitation explicit.
