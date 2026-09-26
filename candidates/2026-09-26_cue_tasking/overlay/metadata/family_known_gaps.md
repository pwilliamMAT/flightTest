# Family Known Gaps

## Accepted P1 through P3 gaps

- Field channel-role, lock/drop, reference-path, and collection-suitability qualification remains unavailable.
- Historical 01A/01B frequency, ERP, filter-loss, and target-level differences remain visible and unreconciled.
- The original Apple Hill 3-D ray-path capture and raw paired before/after injection visual were not recovered.
- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation.

## Added 2026-09-26 (cue-tasking update)

- The ADS-B Pi keeps time from internet NTP, which is accepted, with an accepted 0.1 s host-to-host tolerance; GPS/PPS lock is a hardware to-do. Before 2026-09-25 21:07 UTC the Pi was measured 14.9 s slow, so Pi-timed ADS-B truth from earlier collections carries an unknown offset until it is re-checked (Report 02 V5 TIME-001; Report 06 V3 STAT-010).
- The ADS-B cue interface is verified as a message interface only. The Resource Manager does not schedule collections, and no collection has been made from a cue (Report 06 V3 STAT-009, STAT-012).
- Cues choose when and with which emitter to collect, and the Tracker may use cues to help association. The truth-separation rule (CR-9, System Engineering section) is accepted: the cued/uncued label covers the whole capture, including every channel of a capture widened to take in adjacent channels; every product records its emitter and whether it is truth-blind or cue-aided; products on other emitters of a cued collection are still conditional on the cue. The labels are not yet implemented in the ICD or the code, and no cued collection exists yet (Report 06 V3 STAT-013).
- Predicted SNR in cues is a modeled, pre-integration ranking estimate and has not been reconciled with the Report 01A/01B models.
- CueListener and the DTV level-check scripts stay on branch `feature/adsb-cue-listener` pending review by Pat; the Cue Tasker code is on an ADSB-remoter feature branch.
- The system requirements baseline is published as a DRAFT (CR-10 open); only the individual owner decisions of 2026-09-26 recorded in it are accepted.
- No full TechnicalSummaryFamily release build was run for 02 V5 and 06 V3. A full build validates local workstation evidence links and ManagerReport companion files, which exist only on the Windows workstation; the builder and verifier were tested in a scratch workspace instead.

## Workstation dependencies

- Local file evidence links were existence-checked at build time and are nonportable by design.
- External web links are preserved but not network-validated.

## Release policy

No unresolved P0 item is hidden. The former P0 family-navigation gap is resolved by release-local navigation, explicit handoffs, canonical version mapping, and validation. Reports 02 V5 and 06 V3 replace 02 V4 and 06 V2 as the current versions; the superseded files stay in `reports/` unchanged because accepted reports link to them.