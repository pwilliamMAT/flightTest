# 02A Synthetic Echo Generation V1 audit

## File protection

- Created: `02A_SyntheticEchoGeneration_V1.html`
- Created report-relative assets only in `02A_SyntheticEchoGeneration_assets/`.
- No accepted report, source MATLAB file, source artifact, source figure, or presentation was modified.
- `02A_outline.yaml` was created first and structurally validated before the report was generated.

## Engineering-story completeness

The report uses the required outcome-first structure:

| Test | Question | Result | Why it matters | Decision | Evidence | Method | Remaining uncertainty |
|---|---|---|---|---|---|---|---|
| 1 | Can we create a known target? | One declared truth bundle carries target geometry and metadata into synthesis. | Prevents post hoc “bright pixel” interpretation. | Declare truth before replay and retain it for post-hoc association only. | Truth code, walkthrough, visual, manifests. | Waypoint/ADS-B normalization. | Not a measured aircraft echo or calibrated RCS. |
| 2 | Can we place it where expected? | Geometry is converted to delay and Doppler, then into a fractional-delay, Doppler-shifted echo. | Placement becomes inspectable. | Check geometry/support before interpreting outcomes. | Synthesis helper, atlas maps, validation image. | Excess path/rate, wideband propagation, fractional delay. | Placement does not guarantee support or recovery. |
| 3 | What uncertainty does synthetic truth remove? | The paired package holds real background constant while adding only a declared CH1 echo. | Isolates an injection/replay question from scene variation. | Use real-background pairs and reviewable manifests. | Generator, design note, manifests, accepted boundaries. | Copy channels, inject CH1 only, preserve CH2/control. | Not field qualification or operational performance. |

## Source coverage

- Inspected the design packet, seed-backed walkthrough, truth helper, seed-backed channel helper, real-background target-echo helper, native toolbox target-echo helper, echo-conditioning helper, seed-backed session generator/README, real-background suite generator/design note, accepted placement artifacts, and accepted pipeline/G4-R/status boundaries.
- No recoverable Teams-export artifact matching IDs `4-2958ca` or `5-75ea14` was found. The design packet, code, source README/design note, manifests, and figures provide the recoverable explanatory record.
- Source code was inspected but not run. The report makes no claim that it regenerated any synthetic session.

## Quantitative verification

| Visible numeric claim | Source | Treatment |
|---|---|---|
| Historical real-background suite: 6.144 MHz sample rate; 599 MHz center frequency | `SRC-02A-07` | Historical package configuration only. |
| Historical support: [−1200, −150] µs × ±750 Hz | `SRC-02A-08` | Accepted support context, not a physical target limit. |
| 15 km anchor: expected −76.456 µs / 540.5 Hz; selected CUT −65.104 µs / 540 Hz | `SRC-02A-08` | Current accepted placement/evaluation context. |
| 15 km context: 3 km altitude and 150 m/s northbound | `SRC-02A-08` | Current accepted synthetic scenario input. |
| Exact 8/8 / 0/8 / target-specific-control statement | `SRC-02A-09`, Report 05 | Included solely as a cross-reference to the owner report; not reinterpreted. |

## Evidence and figure coverage

- Included original historical declared-truth, historical generator-validation, current geographic-placement, and current delay-Doppler placement figures.
- Included a source-derived before/after channel-contract visual because no recoverable source-faithful raw “before injection” / matching “after injection” figure was found.
- The explanatory before/after and package visuals are visibly labelled as native HTML representations of source-defined contracts, not technical plots or recreated source data.
- No mitigation thumbnails were relabelled as before/after injection images.

## Boundaries and product separation

- Seed-backed synthetic IQ and real-background surveillance-only injection are kept distinct.
- The August historical package and September accepted G4-R atlas are not combined into one configuration.
- The report does not claim live-aircraft detection, operational Pd/Pfa, map-wide false alarms, hardware qualification, collection suitability, tracking, or localization.
- The support-exclusion interpretation and exact recovery outcome remain owned by Report 05.

## Report-family placement

- Report ID: `02A`
- Previous: `02_HardwareAndCollection_V4.html`
- Next: `03_AnalysisPipelineAndGateRebuild.html`
- Scope retained: synthetic-truth construction and its value/limits. Hardware qualification remains in Report 02; truth-blind pipeline mechanics in Report 03; G4-R interpretation in Report 05.

## Final status

READY WITH KNOWN GAPS

The report is ready for manual review. The known visual gap is a missing recoverable raw before/after injection plot; it is disclosed and handled with a clearly labelled channel-contract schematic rather than a fabricated technical figure.
