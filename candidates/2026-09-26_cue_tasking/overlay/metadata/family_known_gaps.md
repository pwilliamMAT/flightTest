# Family Known Gaps

## Accepted P1 through P3 gaps

- Field channel-role, lock/drop, reference-path, and collection-suitability qualification remains unavailable.
- Historical 01A/01B frequency, ERP, filter-loss, and target-level differences remain visible and unreconciled.
- The original Apple Hill 3-D ray-path capture and raw paired before/after injection visual were not recovered.
- The family contains controlled synthetic evidence, not live-aircraft detection, operational Pd/Pfa, tracking, or localization validation.

## Added 2026-09-26 (cue-tasking update)

- The ADS-B Pi time source is not GPS/PPS-locked. It keeps time from internet NTP through the collection desktop; before 2026-09-25 21:07 UTC the Pi was measured 14.9 s slow, so Pi-timed ADS-B truth from earlier collections carries an unknown offset (Report 02 V5 TIME-001; Report 06 V3 STAT-010).
- The ADS-B cue interface is verified as a message interface only. The Resource Manager does not schedule collections, and no collection has been made from a cue (Report 06 V3 STAT-009, STAT-012).
- The truth-separation rule for cue-selected collections and cue-aided association is not yet written down.
- Predicted SNR in cues is a modeled, pre-integration ranking estimate and has not been reconciled with the Report 01A/01B models.
- CueListener and the DTV level-check scripts are not on `main`; the Cue Tasker code is on an ADSB-remoter feature branch.

## Workstation dependencies

- Local file evidence links were existence-checked at build time and are nonportable by design.
- External web links are preserved but not network-validated.

## Release policy

No unresolved P0 item is hidden. Reports 02 V5 and 06 V3 were accepted after release 20260921_181348 without a new TechnicalSummaryFamily release; the builder and verifier still name 02 V4 and 06 V2. The former P0 family-navigation gap is resolved by release-local navigation, explicit handoffs, canonical version mapping, and validation.