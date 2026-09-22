# Cross-Report Consistency Audit

Audit date: 2026-09-18  
Scope: `01_NorthStarAndMotivation`, `04_MitigationAndMapRateRecovery`, and
`06_StatusAndFutureWork`, with `02_HardwareAndCollection` and
`03_AnalysisPipelineAndGateRebuild` used as report-family references.

## Result

The three new reports form a consistent standalone evidence-report family.
Each contains the required reporting-contract sections, embedded visual
explanations, local evidence navigation, a glossary, and a source inventory.
The reports preserve the current evidence boundary: no operational detection,
Pd/Pfa, tracking, or localization claim is made.

## Structural and portability checks

| Check | Report 01 | Report 04 | Report 06 | Result |
|---|---:|---:|---:|---|
| Required top-level report sections | 13 | 13 | 13 | Pass |
| Embedded SVG evidence figures | 4 | 5 | 4 | Pass |
| Local `file:///` evidence links | 25 | 47 | 24 | Pass |
| Broken in-report navigation targets | 0 | 0 | 0 | Pass |
| Required external image or web dependency | 0 | 0 | 0 | Pass |
| Markdown companion, outline, figure inventory, source inventory | Present | Present | Present | Pass |

## Terminology and status consistency

The following terms have one meaning across the family:

| Term or state | Shared interpretation |
|---|---|
| `G1`–`G10` | Stable ordered gate sequence, from ingest through tracking/truth validation. |
| `G4-R` | Bounded G4 remediation and revalidation sequence, not an additional pipeline gate. |
| `R1`–`R5A` | Ordered G4-R acceptance/recovery steps; R5A is the bounded 108-condition map-formation matrix. |
| Direct path/reference path | Broadcast copy used as the comparison waveform. |
| Surveillance path | Recording containing broadcast energy plus scene propagation/reflections. |
| Passive cross-ambiguity map | Delay-Doppler map formed from the reference and surveillance paths. |
| ADS-B | Post-hoc truth/geometry context only; it does not steer map formation, thresholding, NMS, or detection generation. |
| `In Progress` | Review and controlled verification of the bounded native-first frozen-NLMS R4 correction candidate. |
| `Blocked` | Map-rate closure, R5B collection suitability, and formal downstream G5/G6/G8/detection/tracking work. |
| `Supported Diagnostic` | A narrow finding supported by bounded evidence, not an operational or formal-gate result. |

The permitted status vocabulary is used for visible report status labels:
`Implemented`, `Investigated`, `Demonstrated`, `Supported Diagnostic`,
`In Progress`, and `Blocked`.

## Evidence and non-claim consistency

All three reports consistently state that:

- The 2026-09-11 R4 result was a passed fixed-pilot checkpoint, not a current
  production-pass conclusion.
- The 2026-09-15 R5A result is an integrity-valid, exact 108-condition
  matrix that failed frozen criteria; it does not invalidate the narrower R4
  checkpoint.
- Native-first, calibration-trained then frozen 16-tap NLMS is a reviewed
  upstream R4 correction candidate only. It is not a G5 product selection,
  hardware/site sufficiency result, or replacement-R5A authorization.
- Collection suitability remains separately blocked pending a reviewed ADS-B
  timing/geometry policy and adequate acquisition/reference-chain evidence.
- Infrastructure, synthetic, and diagnostic evidence are not promoted to
  live-aircraft detection, operational Pd/Pfa, validated tracking, or
  validated localization performance.

## Overlap findings

| Topic | Report owner | Other use | Audit outcome |
|---|---|---|---|
| Why passive HDTV and later localization matter | Report 01 | Report 06 gives only future-path context | No duplication concern. |
| G1–G10 architecture | Report 03 | Report 01 gives a concise value chain; Report 06 gives readiness dependencies | Intentional orientation-only reuse. |
| Physical deployment and collection evidence | Report 02 | Reports 01, 04, and 06 cross-reference it rather than reproduce it | Scope preserved. |
| R1–R5A recovery mechanics and cancellation characterization | Report 04 | Report 06 summarizes current decision implications only | Intentional summary/deep-dive relationship; no duplicated figure. |
| R4/R5A quantitative contrast | Report 04 | Report 06 uses a compact readiness comparison | Necessary manager-level summary in Report 06; detailed metric/causal explanation remains in Report 04. |
| Close-target atlas | Separate G4-R artifact/report | Report 04 mentions it only as a boundary cross-reference | Scope preserved; no atlas reproduction. |

No identical figure titles or file-level duplicate figures occur among the
three new report inventories.

## Edits applied during audit

1. Report 01’s presentation layer was aligned with the approved Report 03 /
   Report 06 white evidence-report layout while retaining its motivation
   content and embedded figures.
2. Report 04 was clarified to state that bounded correction review is
   `In Progress`, while map-contract closure and formal downstream work are
   `Blocked`. Its Markdown companion and outline use the same distinction.

## Remaining evidence gaps, not report gaps

- No field-qualified reference-chain, channel-mapping, lock, or
  overrun/drop-counter evidence supports collection suitability.
- No reviewed numerical ADS-B timing/geometry policy exists for R5B.
- No reviewed adoption and controlled R4 verification has yet established the
  native-first frozen-NLMS correction as production behavior.
- No separately authorized replacement R5A matrix has run.
- Consequently, no formal G5 product selection, G6 freeze, G8 detection,
  `objectDetection`, tracker readiness, tracking validation, or localization
  validation exists to report.

These are correctly reported as project dependencies rather than being
papered over by narrative or visual polish.

## Recommended maintenance

Maintain the current ownership split:

- Report 01: motivation, North Star, and long-term value.
- Report 02: hardware and collection infrastructure.
- Report 03: pipeline and gate architecture.
- Report 04: G4-R recovery evidence and mitigation/map-rate lessons.
- Report 05: strongest evidence / close-target diagnostic work, if maintained
  as a separate report.
- Report 06: current status, management decisions, and future dependencies.

When project state changes, update the status snapshot and source inventories
in Reports 04 and 06 together. Do not revise Report 01’s conceptual
motivation unless the North Star or system boundary changes.
