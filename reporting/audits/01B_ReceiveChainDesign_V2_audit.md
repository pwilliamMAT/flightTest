# 01B Receive-Chain Design V2 audit

## File protection

- Baseline preserved: `01B_ReceiveChainDesign_V1.html` was not edited, renamed, or overwritten.
- V1 SHA-256 at V2 final validation: `732BB46E48C00EC879DA7D792E0071D6350E1380B1932CAFE192D6666F7A3877`.
- New report: `01B_ReceiveChainDesign_V2.html`.
- Existing V1 inventories remain unchanged.
- V2 adds two report-relative assets only:
  - `01B_ReceiveChainDesign_assets/rf_budget_analyzer_system_model.png`
  - `01B_ReceiveChainDesign_assets/parking_lot_designed_architecture.png`
- No MATLAB code, source PowerPoint, source image, accepted report, or presentation was modified.

## RF Budget Model Recovery

- **Was a source-faithful model figure found?** Yes.
- **Source:** `LinkBudget/LinkBudgetProgress.pptx`, slide 30, “Overview of Sim Config – MAT file of sim data.”
- **What it shows:** An authentic RF Budget Analyzer stage view: RF Filter → RF Amplifier → Demodulator → IF Filter → IF Amplifier, with stage gain, NF, OIP3, and a selected-stage power-characteristics chart.
- **Recovery method:** Source PowerPoint was opened read-only through PowerPoint automation and slide 30 was exported to a stable PNG. The source deck was closed without saving.
- **Important configuration boundary:** This is an earlier IF/demodulator model. A separate original RF Budget Analyzer diagram covering the later full Yagi → cable → 75-to-50-ohm transition → filter → LANA → N320 direct-sampling chain was not recovered. V2 does not fabricate one. It places the original Analyzer view beside the later source-code/cascade evidence and labels the evolution explicitly.

## MountingDiagram Recovery

- **Was the architectural diagram found?** Yes.
- **Source:** `MountingDiagramParkingLot.pptx`, slide 4.
- **Recovery method:** Source PowerPoint was opened read-only through PowerPoint automation and slide 4 was exported to a stable PNG. The source deck was closed without saving.
- **What question it answers:** What designed hardware architecture did the RF analysis lead to?
- **What it shows:** Flat-panel and rotating Yagi antennas, RF cable, RF filter, wideband amplifier, placeholder IF amplifier, N320, data-collection PC, data storage, WiFi extender, and small/large electronics enclosure locations.
- **Boundary:** It is a planned layout. It does not show transmitter, ADS-B, GPS, final signal roles, as-built connectors, measured gain, lock, reference adequacy, or collection qualification.

## V2 changes

| Addition | Purpose | Source |
|---|---|---|
| Figure 0: RF Budget System Model | Shows the original stage-level model before the output plots. | `SRC-01B-11` |
| Model → Architecture → Hardware → Qualification rail | Makes the evidence progression visible without claiming a single unchanged configuration. | `SRC-01B-02/03/04/07/09/11/12` |
| Figure 3: designed parking-lot architecture | Inserts the missing designed-system layer between model outputs and installed-hardware context. | `SRC-01B-12` |
| “What changed because of this analysis?” table | Converts historical evidence into four traceable engineering decisions. | `SRC-01B-01/02/03/04/05` |
| Stronger result language | Replaces vague causal language with model result → decision → unresolved measurement statements. | Existing V1 sources preserved |

## Decision Summary Verification

| Decision-table row | Traceable evidence | Verification |
|---|---|---|
| Weak signal preservation | Direct-sampling scripts and Figures 1–2 show cable/mismatch/filter loss before the 20 dB LANA. | Supported; still scoped to historical model. |
| Impedance strategy | Comparative script models 0.4 dB transition; Tim Reeves review calls for deliberate 50-ohm design or a transformer. | Supported; no installed-match claim added. |
| Filter behavior | Newton script assumes 1.5 dB; vendor +25°C S2P file reports −0.7335926 dB S21 at 599 MHz. | Supported; discrepancy retained. |
| Radio headroom | Historical cascades approach plotted radio line; Newton/comparative code recommends separate 20–30 dB reference attenuation. | Supported; no actual receive-power claim added. |

No unsupported component choice, field result, or current qualification decision was introduced.

## Quantitative and source consistency

- Preserved V1 visible numeric values and source IDs.
- Preserved the Newton target-input conflict: earlier model `−79.50 dBm`; later Newton/comparative code reuses `−67.37 dBm` as a Hudson placeholder.
- Preserved the frequency representation discrepancy: Report 01A Live Script uses 596.3/548 MHz labels; later RF-budget scripts use 599/551 MHz.
- Preserved the filter-loss discrepancy rather than reconciling it silently.
- Preserved the distinction between historical output, vendor component data, planned architecture, physical context, and current qualification evidence.

## Report-family placement

- **01A → 01B:** 01A historical geometry, candidate frequency/bandwidth, and predicted direct-path values become 01B RF-budget inputs.
- **01B → 02:** 01B turns those inputs into specific physical questions: component order, cable/connector/impedance behavior, filter response, radio headroom, path roles, lock/drop state, and Reference Path adequacy. Report 02 owns the measurement and collection evidence.
- The resulting flow is explicit in V2: **Historical Signal Assumptions → RF Budget Model → Designed Architecture → Installed Hardware → Qualification Questions**.

## Visual review

- V2 retains all V1 figures: Hudson cascade, Newton cascade, comparative figure, receiver enclosure, bench return-loss screenshot, and native engineering decision chain.
- V2 adds the recovered original Analyzer model and original mounting diagram.
- Source figures were copied unchanged; no technical plot or architecture diagram was recreated.
- Figure captions state the question, material result, decision influence, and boundary.
- Full report render was inspected after generation.
- All seven V2 image paths resolve from `01B_ReceiveChainDesign_assets/`; no temporary extraction path or base64 image remains.

## Final status

READY WITH KNOWN GAPS

The report is ready for manual review. The known gap is that no source-faithful RF Budget Analyzer diagram of the later full direct-sampling N320 chain was recovered. V2 addresses this transparently by showing the recovered early Analyzer system model, the later direct-sampling cascade outputs, and the planned N320 architecture as separate evidence layers.
