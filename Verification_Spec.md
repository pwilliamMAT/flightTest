# Verification Spec: Synthetic HDTV Scenario Generator for Passive Bistatic Radar

Use this after `Requirements Review` and `Design` are complete. This is the authoritative verification contract owned by the `Independent Quality Gatekeeper`.

Implementation does not begin until this artifact is approved.

## Metadata
- Session: `2026-07-10 synthetic HDTV simulation test design`
- Date: `2026-07-10`
- Current phase: `Test Design`
- Related Requirements Packet: [Requirements_Packet.md](Requirements_Packet.md)
- Related Requirements Review Packet: [Requirements_Review_Packet.md](Requirements_Review_Packet.md)
- Related Design Packet: [Design_Packet.md](Design_Packet.md)
- Gatekeeper: `Independent Quality Gatekeeper` (Codex)
- Status: `Approved`

## Native MATLAB Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Unit and regression verification of geometry, truth, timing, and convention helpers | MATLAB Test `runtests` workflow plus existing repo regression patterns such as `bistaticTruthConventionTest.m` and `runDetectorReplaySweepTest.m` | Extend the existing MATLAB Test style to cover the new simulation-specific helpers without introducing hardware or network dependencies. |
| Temporary packaged-session generation and artifact inspection | Baseband file read or write examples and temporary-folder fixture workflows | Generate synthetic sessions under a temporary output root, then inspect `.bb`, truth, and manifest artifacts without relying on the permanent repo state. |
| End-to-end replay through the current analysis wrapper | Existing repo workflow centered on `runBistaticAnalysisSession` and `runDetectionTruthDiagnostics` | Treat the unchanged packaged-session wrapper as the operational validation seam. Do not replace it with helper-only smoke tests or mocks. |
| Repeatability verification for truth and metadata | Base MATLAB struct and JSON comparison workflows | Canonicalize metadata before comparison and exclude only approved run-unique provenance fields such as `generation_time_utc`. |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| Unit-test execution | `runtests` (MATLAB Test) | `results = runtests("bistaticTruthConventionTest")` |
| Class-based verification | `matlab.unittest.TestCase` (MATLAB Test) | `classdef myTest < matlab.unittest.TestCase` |
| Temporary output isolation | `matlab.unittest.fixtures.TemporaryFolderFixture` (MATLAB Test) | `fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture)` |
| Baseband artifact readback | `comm.BasebandFileReader` (Communications Toolbox) | `bbr = comm.BasebandFileReader(fname, SamplesPerFrame=N); x = bbr()` |
| Manifest parse and schema inspection | `jsondecode` (Base MATLAB) | `manifest = jsondecode(fileread(manifestPath))` |
| Terrain coverage verification | `readgeoraster` (Mapping Toolbox) | `[Z,R] = readgeoraster(dtedFile)` |
| Truth compression compatibility | `gzip`, `gunzip` (Base MATLAB) | `gzip(truthFile)` |

## Gate Decision
- Gate status: `Approve`
- Decision summary: The verification contract is approved because it requires real packaged-session replay through the existing analysis wrapper, explicit negative controls for packaging and truth compatibility, controlled stochastic behavior, and an operational baseline that must produce a scorable truth-comparison path rather than a packaging-only green result.
- Human waiver required to bypass rejection: `Yes`

## Scope Under Test
- Operational claim: The approved v1 simulation design can generate terrain-backed synthetic passive bistatic radar sessions that the existing passive-radar workflow can consume and compare against known truth without manual edits to core analysis entrypoints.
- Scope boundary: approved Apple Hill and Needham geometry, DTED terrain intake, one or more synthetic target trajectories, a declared HDTV illuminator-seed fixture, dual-channel `.bb` session output, SBS-1-compatible truth output, native traceability truth output, and packaged-session replay through the current workflow.
- Out of scope: building models, diffuse terrain-clutter realism, full custom ATSC waveform generation, detector retuning as part of verification, and hardware-in-the-loop SDR capture.
- Failure classes to distinguish: geometry mismatch, terrain-ingest failure, truth-traceability failure, manifest schema failure, packaged-session discovery failure, measurement-convention mismatch, repeatability-boundary violation, hidden fixture dependency, and operational-utility failure.

## Required Evidence Layers
### Software Verification
- Required checks: `CHK-001` through `CHK-009`
- Required environments or fixtures: MATLAB R2026a with Communications Toolbox, Radar Toolbox, Phased Array System Toolbox, Mapping Toolbox, and MATLAB Test; one temporary output root; one approved DTED tile; one declared HDTV seed fixture

### Requirements-Based Verification
- Required requirement coverage: `REQ-001` through `REQ-012` must each map to at least one explicit check in this artifact
- Coverage gaps currently accepted: building-model realism and diffuse terrain-clutter reflectivity are intentionally excluded because they are out of scope in the approved v1 requirement and design baseline

### Operational Validation
- Required end-outcome proof: one approved baseline synthetic session must replay through `runBistaticAnalysisSession` without core code edits and must yield a non-empty truth-comparison path for the existing workflow
- Scenarios or truth sources required: one controlled detector or truth-projection triage scenario, one DTED-backed Apple Hill baseline, one SBS-1-compatible truth emission path, and one native traceability truth artifact

## Anti-Flake Rules
- Deterministic inputs by default: `Required`
- Controlled seeds for stochastic behavior: `Required`
- Wall-clock timing dependence allowed only when timing is itself a requirement: `Required`
- Hidden environment dependencies allowed: `No`
- Informative failure messages required: `Yes`

## Requirement-To-Check Traceability
| Requirement ID | Requirement summary | Check IDs | Evidence layer(s) |
| :--- | :--- | :--- | :--- |
| REQ-001 | Baseline Tx and Rx geodetic definitions | `CHK-001` | Software Verification, Requirements-Based Verification |
| REQ-002 | Time-varying target trajectories accepted as truth inputs | `CHK-002`, `CHK-010` | Software Verification, Operational Validation |
| REQ-003 | DTED-derived terrain context near approved Tx and Rx | `CHK-003` | Software Verification, Requirements-Based Verification |
| REQ-004 | Synthetic radar session data emitted | `CHK-004`, `CHK-006` | Software Verification, Operational Validation |
| REQ-005 | Truth outputs traceable to synthetic trajectories | `CHK-002` | Software Verification, Requirements-Based Verification |
| REQ-006 | Metadata preserves current workflow contract | `CHK-005`, `CHK-006` | Software Verification, Requirements-Based Verification |
| REQ-007 | Artifact set packaged for current workflow without core edits | `CHK-006` | Operational Validation, Requirements-Based Verification |
| REQ-008 | Bistatic truth conventions match current workflow | `CHK-007` | Software Verification, Requirements-Based Verification |
| REQ-009 | Truth and metadata repeat across reruns | `CHK-008` | Software Verification, Requirements-Based Verification |
| REQ-010 | Synthetic provenance fields present in manifest | `CHK-005` | Software Verification, Requirements-Based Verification |
| REQ-011 | One controlled baseline scenario for detector or truth-projection triage | `CHK-009`, `CHK-010` | Requirements-Based Verification, Operational Validation |
| REQ-012 | Output set supports downstream comparison against known truth | `CHK-010` | Operational Validation, Requirements-Based Verification |

## Check Catalog
### `CHK-001`
- Requirement under test: `REQ-001`
- Claim proved: the baseline scenario defines exactly one approved transmitter site and one approved receiver site using explicit geodetic coordinates that are not inherited from analysis fallbacks
- Setup and procedure: load the baseline scenario configuration, instantiate the scenario geometry path, and inspect the declared Tx and Rx geodetic coordinates plus the derived baseline distance
- Pass criteria: exactly one Tx and one Rx are present; both coordinates are explicit in the scenario configuration; the instantiated values match the approved baseline within a documented tolerance; the scene uses the approved earth-centered or geodetic interpretation
- Fail criteria: any site is missing, duplicated, implicit, or mismatched against the approved baseline
- Negative control: perturb one Tx or Rx coordinate outside tolerance and confirm the check fails with a geometry mismatch
- Regression control: re-run the same baseline fixture and compare the derived site summary against a saved approved summary
- Known blind spots: this check proves geometry declaration, not signal realism
- Failure artifact required: serialized scenario-site summary including Tx and Rx coordinates, baseline distance, and mismatch diagnostics

### `CHK-002`
- Requirement under test: `REQ-002`, `REQ-005`
- Claim proved: one or more target trajectories are accepted as truth inputs and emitted truth stays traceable to the declared synthetic targets
- Setup and procedure: run the target-truth path using at least two declared synthetic aircraft trajectories with explicit `target_id`, `icao_hex`, and `callsign`; inspect the emitted compatibility truth and native traceability truth
- Pass criteria: each declared target appears in the emitted truth outputs; timestamps are ordered; native truth preserves target identity and source-trajectory traceability; compatibility truth contains the required `MSG,1`, `MSG,3`, and `MSG,4` records for the declared targets
- Fail criteria: any declared target is missing, ambiguous, duplicated without explanation, or detached from the source trajectory definition
- Negative control: remove one target identifier or corrupt one target timeline and confirm the traceability check fails
- Regression control: compare the emitted truth summary against an approved baseline scenario summary
- Known blind spots: this check does not prove the downstream workflow can consume the truth, only that the truth is emitted and traceable
- Failure artifact required: truth summary table, emitted truth file preview, and missing or mismatched target list

### `CHK-003`
- Requirement under test: `REQ-003`
- Claim proved: the baseline simulation accepts DTED-derived terrain context covering the approved Apple Hill and Needham geometry
- Setup and procedure: load the approved DTED tile, verify its raster bounds, instantiate the terrain-backed scene, and confirm the approved Tx and Rx locations lie within coverage
- Pass criteria: the DTED file loads successfully; raster bounds cover the approved Tx and Rx; the terrain adapter accepts the file without requiring building models
- Fail criteria: the DTED file cannot be loaded, the approved geometry falls outside coverage, or terrain intake silently degrades to no-terrain mode
- Negative control: point the terrain path to a missing or out-of-area file and confirm the check fails before session generation
- Regression control: re-run the bounds and coverage check against the approved `n42_w072_1arc_v3.dt2` tile
- Known blind spots: this check proves terrain context intake, not high-fidelity clutter realism
- Failure artifact required: raster-bounds summary, terrain-path record, and Tx or Rx coverage result

### `CHK-004`
- Requirement under test: `REQ-004`
- Claim proved: the simulator emits dual-channel radar session data as valid `.bb` artifacts readable by the current MATLAB toolchain
- Setup and procedure: generate one minimal synthetic session, write the radar artifacts with `comm.BasebandFileWriter`, and read the first file back with `comm.BasebandFileReader`
- Pass criteria: at least one radar file is written; the first radar file reads successfully; two channels are present; header metadata contains the required timing and session fields; header sample rate and center frequency match the scenario configuration
- Fail criteria: no radar file is produced, the file is unreadable, only one channel is present, or header metadata is missing or inconsistent
- Negative control: generate an intentionally malformed one-channel or metadata-incomplete file and confirm readback or header validation fails
- Regression control: re-run the same deterministic baseline scenario and confirm header structure and channel count match the approved readback summary
- Known blind spots: readback alone does not prove packaged-session compatibility through the current wrapper
- Failure artifact required: radar-file inventory, readback header dump, and channel-count summary

### `CHK-005`
- Requirement under test: `REQ-006`, `REQ-010`
- Claim proved: `session_manifest.json` preserves the current workflow contract and includes the required synthetic provenance fields
- Setup and procedure: parse the emitted manifest through both `jsondecode` and the existing `helperLoadSessionManifest`; inspect timing, frequency, radar file, truth file, log file, and provenance fields
- Pass criteria: the helper accepts the manifest; all required packaged-session fields are present; required synthetic provenance fields are present; `data_origin` explicitly marks the session as synthetic; the manifest contains the declared `scenario_id`, `generator_name`, `generation_time_utc`, `truth_source`, and `random_seed` when stochastic generation is used
- Fail criteria: helper parse fails, required packaged-session fields are missing, or synthetic provenance is absent or ambiguous
- Negative control: omit one required manifest or provenance field and confirm helper or schema validation fails with a clear message
- Regression control: compare the emitted manifest key set and field types against an approved canonical manifest summary
- Known blind spots: manifest correctness does not guarantee downstream replay success unless `CHK-006` also passes
- Failure artifact required: manifest snapshot, canonical field diff, and helper-parse result

### `CHK-006`
- Requirement under test: `REQ-004`, `REQ-006`, `REQ-007`
- Claim proved: the emitted artifact set is packaged so that the existing passive-radar session-analysis workflow can consume it without manual edits to core analysis entrypoints
- Setup and procedure: run `runBistaticAnalysisSession` on the emitted synthetic session using the normal packaged-session entrypoint and inspect the returned preflight and snapshot status fields
- Pass criteria: the wrapper resolves the session folder and manifest without manual code edits; the wrapper discovers the radar and truth files; session preflight completes; snapshot status fields are not `error`; no core entrypoint patching is required
- Fail criteria: replay requires manual edits to core entrypoints, manifest discovery fails, file discovery fails, or wrapper execution aborts before producing analysis output
- Negative control: misplace the manifest or truth files and confirm wrapper preflight fails with a packaging error rather than silently falling through
- Regression control: replay the approved baseline scenario from a temporary folder and compare the wrapper output structure against the approved replay summary
- Known blind spots: wrapper success alone does not prove the truth path is useful for scoring unless `CHK-010` passes
- Failure artifact required: wrapper console log, returned output summary, and snapshot status summary

### `CHK-007`
- Requirement under test: `REQ-008`
- Claim proved: any emitted bistatic measurement-space truth follows the same range and Doppler conventions used by the current workflow
- Setup and procedure: derive measurement-space truth for a controlled scenario and compare it against the approved convention path used by the current workflow and its existing helper tests
- Pass criteria: emitted truth uses `R_excess = R_tx + R_rx - L_3D`; Doppler sign matches the passive-radar convention already enforced in existing repo tests; timing and range-cell interpretation match the current truth-projection path
- Fail criteria: the emitted truth uses a horizontal baseline, the wrong Doppler sign, or a timing convention that disagrees with the current workflow
- Negative control: intentionally invert the Doppler sign or substitute the horizontal baseline and confirm the comparison fails
- Regression control: re-run the existing convention-style regression fixture against the simulation-emitted truth
- Known blind spots: this check proves convention compatibility, not that the current detector will detect the target
- Failure artifact required: truth-convention comparison report with range and Doppler mismatch values

### `CHK-008`
- Requirement under test: `REQ-009`
- Claim proved: the same approved scenario inputs reproduce the same truth and metadata outputs across reruns, excluding only approved run-unique provenance
- Setup and procedure: run the same approved scenario twice in controlled mode, canonicalize the emitted truth and manifest metadata, and compare them field by field
- Pass criteria: canonicalized truth matches exactly; canonicalized metadata matches exactly after excluding only `generation_time_utc`; fields that drive replay behavior such as `radar_epoch_utc`, `center_frequency_hz`, `sample_rate_hz`, and file lists remain deterministic
- Fail criteria: truth differs, replay-critical metadata differs, or more manifest fields need to be excluded than the approved run-unique provenance list
- Negative control: change one scenario input such as target trajectory or center frequency and confirm the canonical comparison fails
- Regression control: compare both reruns against a saved canonical baseline generated from the same approved scenario
- Known blind spots: this check does not require raw radar samples to match across reruns, by approved requirement
- Failure artifact required: canonical truth diff, canonical metadata diff, and explicit excluded-field list

### `CHK-009`
- Requirement under test: `REQ-011`
- Claim proved: the approved baseline includes a controlled scenario explicitly intended to isolate detector or truth-projection behavior from field ambiguity
- Setup and procedure: inspect the baseline scenario definition, its stated purpose, and its target visibility summary against the approved design packet
- Pass criteria: one baseline scenario is explicitly marked as detector or truth-projection triage; it declares target trajectories, intended evaluation purpose, and an expected overlap with the analysis window
- Fail criteria: the baseline scenario is undocumented, ambiguous in purpose, or places all targets outside the usable analysis window
- Negative control: define a scenario with no overlap or no declared triage purpose and confirm the check fails
- Regression control: compare the baseline scenario summary against the approved detector-triage scenario record
- Known blind spots: this check proves scenario intent and overlap, not end-to-end usability on its own
- Failure artifact required: baseline scenario summary including declared purpose, target count, and expected overlap window

### `CHK-010`
- Requirement under test: `REQ-002`, `REQ-011`, `REQ-012`
- Claim proved: the emitted artifact set supports downstream comparison of detections or tracks against known truth for the same synthetic run using the existing workflow
- Setup and procedure: run the approved baseline synthetic session through `runBistaticAnalysisSession`, then run the existing downstream truth-comparison path on the emitted session or its saved snapshot
- Pass criteria: emitted truth loads through the current truth pipeline; aligned truth is non-empty; the baseline scenario yields at least one downstream detection or track candidate that can be scored against truth; a comparison summary is produced without manual core-code edits
- Fail criteria: emitted truth is not consumable by the current truth pipeline, aligned truth is empty, or the baseline scenario yields no scorable downstream candidates for comparison
- Negative control: misformat the truth file or move all targets outside the overlap window and confirm the comparison path fails or produces an empty aligned-truth result
- Regression control: rerun the saved snapshot or detector replay generated from the same synthetic session and confirm the comparison summary remains available
- Known blind spots: this check proves comparison usability, not final detector quality or field realism
- Failure artifact required: truth-diagnostic summary, aligned-truth summary, and detection-or-track candidate count

## Fixtures And Dependencies
- Fixture 1: approved DTED tile [n42_w072_1arc_v3.dt2](n42_w072_1arc_v3.dt2)
- Fixture 2: one approved HDTV reference-channel seed asset, declared by explicit path or packaged fixture identifier before implementation begins
- Fixture 3: temporary output root for generated synthetic sessions
- Fixture 4: one approved baseline scenario configuration containing Tx and Rx geometry, timing, carrier, sample rate, and target trajectories
- Fixture 5: unchanged current analysis entrypoints, especially `runBistaticAnalysisSession`, `helperLoadSessionManifest`, `helperResolveSessionAnalysisSetup`, `loadIQData`, and `loadADSBTruth`
- Controlled seeds: fixed integer seeds are required whenever stochastic noise or other random effects are enabled; deterministic mode is required for repeatability checks when stochasticity is not under test
- External dependencies explicitly declared: MATLAB R2026a; Communications Toolbox; Radar Toolbox; Phased Array System Toolbox; Mapping Toolbox; MATLAB Test; declared HDTV seed fixture path; declared DTED path

## Blocking Questions Or Missing Information
- Blocking question 1: none after resolution of the repeatability ambiguity for `generation_time_utc`
- Missing requirement-to-check traceability: none at the approved test-design baseline
- Missing pass or fail criteria: none at the approved test-design baseline
- Missing negative or regression control: none at the approved test-design baseline
- Missing fixture or environment declaration: none at the verification-contract level; the exact HDTV seed fixture must be declared in the execution context before implementation starts

## Failure Interpretation
- If `CHK-001` fails: treat the failure as a baseline-geometry defect; do not proceed to signal tuning until the scenario source of truth is corrected
- If `CHK-002` fails: treat the failure as a truth-traceability defect; downstream scoring evidence is not credible
- If `CHK-003` fails: treat the failure as a terrain-context defect; do not claim Apple Hill fidelity
- If `CHK-004` fails: treat the failure as a radar-artifact generation defect; no downstream replay evidence is meaningful
- If `CHK-005` fails: treat the failure as a metadata or provenance defect; do not accept the session as workflow-compatible
- If `CHK-006` fails: treat the failure as a packaged-session contract failure; reopen design if the only fix is to change core analysis entrypoints or session layout
- If `CHK-007` fails: treat the failure as a convention mismatch; do not compare detections or tracks against emitted truth until corrected
- If `CHK-008` fails: treat the failure as a repeatability-boundary violation; reopen requirements review if the proposed fix expands the list of allowed run-unique fields beyond `generation_time_utc`
- If `CHK-009` fails: treat the failure as a baseline-scenario design defect; operational validation cannot proceed
- If `CHK-010` fails: treat the failure as an operational-utility defect; the simulation may package data but does not yet support the intended downstream tuning workflow
- Conditions that require reopening review instead of more coding: any need to replace the packaged-session contract, any need to require a custom ATSC waveform generator instead of the approved seed-based assumption, any need to add building models or high-fidelity clutter to satisfy the v1 baseline, any need to relax the requirement that the current workflow consume the artifacts without core-code edits, or any expansion of allowed metadata-drift fields beyond the approved run-unique provenance list

## Anti-False-Confidence Notes
- Misleading green pattern 1: a `.bb` file and manifest can be syntactically valid yet still fail the real wrapper or force metadata fallbacks; helper-only smoke tests are insufficient without `CHK-006`
- Misleading green pattern 2: a session can replay and load truth yet still be useless for tuning if aligned truth is empty or no downstream candidate is scorable against truth; replay alone is insufficient without `CHK-010`

## Approval
- Human sign-off required before implementation: `Yes`
- Approved by: `Independent Quality Gatekeeper` (Codex)
- Approval date: `2026-07-10`
