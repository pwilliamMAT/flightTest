# Expert Review: Seed-Backed Synthetic HDTV Pipeline

## Scope

This document is a sequential council review of the current synthetic generation pipeline, with emphasis on [SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m](SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m) as the operator-facing manual verification entry point.

The review is grounded in the current branch state of:

- [SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m](SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m)
- [SyntheticHDTVSimulation/helperSyntheticGenerateTruth.m](SyntheticHDTVSimulation/helperSyntheticGenerateTruth.m)
- [SyntheticHDTVSimulation/helperSyntheticBuildCaptureTruthBundle.m](SyntheticHDTVSimulation/helperSyntheticBuildCaptureTruthBundle.m)
- [SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQ.m](SyntheticHDTVSimulation/helperSyntheticValidateGeneratedIQ.m)
- [BistaticDataAnalysis/runBistaticAnalysisSession.m](BistaticDataAnalysis/runBistaticAnalysisSession.m)
- [README.md](README.md)
- [SyntheticHDTVSimulation/tests/SyntheticHDTVCaptureTruthTest.m](SyntheticHDTVSimulation/tests/SyntheticHDTVCaptureTruthTest.m)
- [SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m](SyntheticHDTVSimulation/tests/SyntheticHDTVSessionGeneratorTest.m)

Current verification evidence used for this review:

- MATLAB Code Analyzer on the walkthrough reported non-blocking live-script warnings, not a parser or interface failure.
- MATLAB Code Analyzer on `helperSyntheticGenerateTruth.m` reported one readability note and no blocking issues.
- MATLAB Code Analyzer on `helperSyntheticBuildCaptureTruthBundle.m` was clean.
- `SyntheticHDTVCaptureTruthTest` passed `9/9`.
- `SyntheticHDTVSessionGeneratorTest` passed `38/39`, with one wrapper-replay test interrupted by an `iolib:badbit` output-stream write error while `analyzeBistaticData` was printing verbose console text. That failure does not look like a truth-generation or geometry failure, but it is still a current regression caveat for automated verification environments.

## Native Function Audit

| Proposed Workflow | Native MATLAB Documentation Example Analogue | Updates needed to fit current goal |
| :--- | :--- | :--- |
| Capture-backed truth preview on a tracking globe | `trackingGlobeViewer` with `plotTrajectory` and `plotPlatform` | Keep using the normalized sampled truth bundle so the walkthrough previews the same trajectories that drive synthesis |
| Sample truth on the exact generator timeline | `geoTrajectory` with `lookupPose` | Keep the current contract where both synthetic and capture-backed modes land on one sampled `truth_bundle` |
| Convert aircraft kinematics into bistatic range and Doppler | `adsbToBistatic` | Keep using it as the native bridge from sampled aircraft motion into measurement-space truth |
| Generate wideband target echoes from truth kinematics | `phased.WidebandFreeSpace` | Keep the current delay/Doppler propagation role, but continue to label the amplitude model as heuristic rather than physical |

| Proposed Feature / Algorithm | Native MATLAB Function/Toolbox Equivalent | Documentation Syntax Template Used |
| :--- | :--- | :--- |
| 3-D truth preview | `trackingGlobeViewer` | `viewer = trackingGlobeViewer(ReferenceLocation=refloc)` |
| Plot aircraft trajectories | `plotTrajectory` | `plotTrajectory(viewer,trajectories,...)` |
| Plot Tx/Rx context markers | `plotPlatform` | `plotPlatform(viewer,platStructs,"ENU",...)` |
| Sample waypoint or ADS-B trajectories | `geoTrajectory` | `traj = geoTrajectory(waypoints,timeOfArrival,ReferenceFrame="NED")` |
| Query sampled pose and velocity | `lookupPose` | `[position,orientation,velocity] = lookupPose(traj,sampleTimes)` |
| Bistatic projection | `adsbToBistatic` | `tracks = adsbToBistatic(adsbTracks,txLla,rxLla,fc)` |
| Wideband free-space propagation | `phased.WidebandFreeSpace` | `chan = phased.WidebandFreeSpace('SampleRate',fs,'OperatingFrequency',fc,...)` |

## Council Review

### Reviewer 1: Systems And CONOPS

1. Have we indicated the right level of fidelity?

- Mostly yes.
- The repo now consistently describes the product as an intermediate seed-backed model and explicitly says it is not a field-surrogate scene model. That is the right baseline.
- The one statement that should remain explicit in every audience-facing summary is: capture-backed truth does not mean capture-backed RF fidelity. The truth is capture-backed. The RF remains synthetic.

2. Are we ready to run this through our analysis pipeline?

- Yes, for packaged-session compatibility, pipeline plumbing, truth traceability, operator rehearsal, and controlled detector/tracker debug.
- Yes, the walkthrough is now the right manual verification script because it asks explicit validation questions, previews the exact sampled truth, runs the readiness gate, and can replay the packaged session through the existing wrapper.
- No, if the expectation is that a successful synthetic run proves field readiness.

3. What caveats affect decisions about the analysis pipeline?

- The workflow is intentionally a bridge artifact, not an operational benchmark.
- Track inclusion in capture-backed mode is curated by the overlap-and-geometry filter. That is useful for controlled testing, but it is not the same thing as showing every aircraft that existed in the captured airspace.
- The selected truth window and the retained-aircraft count are scenario-design decisions and should be treated as part of the test fixture.

4. What should we not use this dataset to inform?

- Do not use it to justify mission-level detection coverage claims.
- Do not use it to estimate field false-alarm behavior.
- Do not use it as evidence that the current site, clutter, or multipath environment is represented faithfully enough for final detector or tracker tuning.

Expected audience questions:

- If truth is capture-backed, how much of the full scene is still synthetic?
- Are we validating the analysis pipeline or validating a scene model?
- Does the retained-aircraft set represent operational traffic or only a clean subset?

Mitigations:

- Put `truth_source_mode`, selected truth window, retained-aircraft count, and echo-gain policy in every review package.
- Keep saying "intermediate workflow-validation dataset" instead of "realistic synthetic field dataset."
- Show the selection table whenever capture-backed truth is used.

### Reviewer 2: RF And Propagation Fidelity

1. Have we indicated the right level of fidelity?

- Only if we keep the current caveats prominent.
- The current RF path is still seed replay plus delayed, Doppler-shifted, gain-scaled seed copies.
- The conditioned target-echo mode is a pragmatic usability improvement, not a physical propagation effect.
- The capture-backed amplitude model is explicitly `range_only_heuristic_v1`, which is the right honesty level. It must not be presented as RCS, aspect, glint, or scattering fidelity.

2. Are we ready to run this through our analysis pipeline?

- Yes, for delay/Doppler placement checks, direct-path mitigation debugging, seed-preservation checks, and controlled A/B comparisons between conditioned and full-seed modes.
- No, for final threshold tuning intended to transfer to field-collected clutter conditions.

3. What caveats affect decisions about the analysis pipeline?

- The same seed structure is reused across the reference, direct path, and target echoes.
- Strong seed features can create synthetic behaviors that are more coherent and more repeatable than field echoes.
- The readiness gate can still flag `vertical_column_defect`, which means the synthetic target region can still carry truth-aligned vertical Doppler artifacts.
- The environment is not benchmark-grade for clutter, terrain multipath, buildings, or rich scattering.

4. What should we not use this dataset to inform?

- Do not set final CFAR thresholds from it.
- Do not tune sidelobe or clutter-suppression logic solely from it.
- Do not tune amplitude-based target classification, bright-target handling, or RCS-dependent ranking from it.

Expected audience questions:

- How much of detector success is due to seeded coherence rather than physically realistic echoes?
- Does the conditioned mode make the scene unrealistically easy?
- How different are conditioned and full-seed outputs for the same truth?

Mitigations:

- Require conditioned-vs-full-seed comparison runs before accepting any mitigation change.
- Tag all synthetic results with dataset mode so nobody mixes conditioned-mode conclusions into field-performance claims.
- Keep field-threshold tuning on a separate path from synthetic-debug tuning.

### Reviewer 3: Truth, Geometry, And Tracking

1. Have we indicated the right level of fidelity?

- Yes for aircraft kinematics and truth traceability.
- The strongest design choice in the current update is that the same normalized `truth_bundle` contract now feeds the 2-D preview, the 3-D globe preview, the written truth artifact, and RF synthesis.
- That gives the walkthrough much better internal consistency than earlier split-path designs.

2. Are we ready to run this through our analysis pipeline?

- Yes, for truth alignment, geometry inspection, retained-track auditing, and downstream detection-vs-truth checks.
- The walkthrough is now strong as a manual truth-verification script because it previews the same sampled `truth_bundle.targets` that later drive synthesis.

3. What caveats affect decisions about the analysis pipeline?

- ADS-B is still an irregular, transponder-derived truth source rather than a perfect kinematic sensor.
- The filter requires at least two in-window fixes, a finite bistatic projection, and at least one aligned sample beyond the `5 km` guard.
- Only retained tracks appear in the main preview. Excluded tracks appear in the diagnostic selection table, which is good for clarity but means the plot is intentionally curated.
- Truth sampling period and time cropping can smooth or hide very short-duration behavior.

4. What should we not use this dataset to inform?

- Do not use it to evaluate performance on non-cooperative or ADS-B-denied targets.
- Do not use it to infer sensitivity to truth dropouts, transponder latency, or truth corruption.
- Do not use it to infer performance on aircraft trajectories that were filtered out by the overlap-and-geometry rules.

Expected audience questions:

- Why were some aircraft excluded from the preview and synthesis?
- How much does `tMaxS` change the retained set?
- Are the target trajectories shown on the globe exactly the same ones used for RF generation?

Mitigations:

- Save and circulate the capture selection table with include/exclude reasons.
- Report `loaded_aircraft_count` and `retained_aircraft_count` beside every figure set.
- Keep the statement "the preview consumes the same sampled truth bundle used for synthesis" in the walkthrough narrative.

### Reviewer 4: Verification, Validation, And Live-Script Usability

1. Have we indicated the right level of fidelity?

- The walkthrough now indicates the level of claim more responsibly than before.
- It explicitly frames the run around four reader-facing validation questions and classifies the result as configuration-only, exploratory, intermediate workflow validation, debugging-only, or not ready.
- That is the right structure for manual verification at this phase.

2. Are we ready to run this through our analysis pipeline?

- Yes, with one important qualifier.
- The capture-truth regression is clean, and the walkthrough now covers scenario definition, truth preview, 3-D preview, IQ generation, readiness, and wrapper replay in one place.
- The remaining qualifier is that automated wrapper replay still has at least one environment-sensitive regression in the broader generator suite: a verbose console output write failure during a wrapper test. That looks more like an execution-environment issue than a truth-model failure, but it still weakens the "fully clean automation" story.

3. What caveats affect decisions about the analysis pipeline?

- A readiness pass supports intermediate workflow validation, not field-performance certification.
- A readiness fail due only to `vertical_column_defect` is different from a fail on target placement or direct-path consistency. Those failure classes should not be treated as equivalent.
- Some analysis checks are still advisory for this phase, especially where synthetic and field statistics differ.

4. What should we not use this dataset to inform?

- Do not collapse synthetic readiness and field readiness into one release gate.
- Do not call the pipeline fully validated for field use just because the walkthrough is now coherent.
- Do not ignore the residual `vertical_column_defect` caveat when reporting success.

Expected audience questions:

- If the walkthrough says "useful for intermediate workflow validation," what exactly is included in that claim?
- What does a `vertical_column_defect` fail mean operationally?
- If wrapper replay succeeds manually but a test fails in automation, which signal should we trust?

Mitigations:

- Publish a short decision legend with every walkthrough package: what each readiness class permits and forbids.
- Separate algorithmic failures from harness or output-stream failures in the test dashboard.
- Keep wrapper replay in the manual verification flow, but do not let it be the only evidence.

### Reviewer 5: Downstream Analysis Pipeline And Overfitting Risk

1. Have we indicated the right level of fidelity?

- Not completely unless we emphasize the overfitting risk.
- The dataset is good enough to shape development decisions about interfaces, timing, truth joins, measurement-space reasoning, and some mitigation behaviors.
- It is not good enough to safely tune the full analysis pipeline as if synthetic statistics were field statistics.

2. Are we ready to run this through our analysis pipeline?

- Yes, as a synthetic lane with explicit guardrails.
- The pipeline should ingest it, analyze it, and compare detections against truth.
- That work is valuable for debugging regressions, validating manifest contracts, and checking whether algorithm changes preserve expected measurement behavior.

3. What caveats affect decisions about the analysis pipeline?

- Synthetic success may be inflated by seed coherence and reduced environmental richness.
- Synthetic failure may also be misleading if it is driven by known generator artifacts rather than by realistic field difficulty.
- If we tune detector thresholds, mitigation aggressiveness, or tracker confirmation logic too tightly against this dataset, we risk training the analysis chain around synthetic artifacts rather than field behavior.

4. What should we not use this dataset to inform?

- Do not retune global detector thresholds intended for field deployment.
- Do not use it to set final tracker confirmation or deletion logic.
- Do not use it to estimate operational Pd/Pfa, clutter stationarity, or false-track behavior.
- Do not use it to justify rejection of field-data anomalies that synthetic data simply does not reproduce.

Expected audience questions:

- Which parameter changes are safe to learn from synthetic runs?
- How do we prevent synthetic data from biasing the field-data pipeline?
- Should synthetic and field runs share one configuration?

Mitigations:

- Keep separate synthetic-informed and field-qualified configuration lanes.
- Require field revalidation before merging any threshold or gating change justified by synthetic evidence.
- Treat synthetic data as a regression and debugging asset first, and a performance-scoring asset only in narrowly defined, explicitly synthetic contexts.

## Council Consensus

The council consensus is that [SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m](SyntheticHDTVSimulation/seedBackedSyntheticHDTVSessionWalkthrough.m) is now ready as the manual verification walkthrough for the current synthetic pipeline.

That statement is narrow and intentional:

- It is ready to verify scenario setup, truth consistency, capture-backed truth selection behavior, 2-D and 3-D truth previews, session packaging, signal-physics readiness, and packaged-session replay through the current analysis wrapper.
- It is ready to support analysis-pipeline plumbing, truth-aligned detector debugging, compatibility checks, controlled regression testing, and conditioned-vs-full-seed comparisons.
- It is not ready to support field-equivalent performance claims.
- It is not ready to serve as the main basis for final detector, tracker, clutter, or CFAR tuning.

### Direct Answers To The Requested Questions

1. Have we indicated the right level of fidelity?

- Mostly yes.
- The repo language is now close to right: intermediate, not field-surrogate, with explicit capture-backed truth and explicit range-only amplitude heuristic.
- The remaining discipline required is to keep repeating that capture-backed truth improves kinematic realism and traceability, not overall RF realism.

2. Are we ready to run this through our analysis pipeline?

- Yes, for the current intended purpose.
- No, if the purpose is final field-performance assessment.

3. What caveats affect how we make decisions about the analysis pipeline?

- `vertical_column_defect` remains a live caveat.
- Target amplitudes are heuristic, not RCS-based.
- Clutter, multipath, and site richness are not field-equivalent.
- Capture-backed truth is filtered and windowed before synthesis.
- Wrapper automation still has at least one environment-sensitive output-stream issue in the broader test suite.

4. Are there things we cannot use this dataset to inform?

- Yes.
- Final threshold setting, field false-alarm expectations, final tracker tuning, clutter-model assumptions, amplitude-model assumptions, and claims about real-world operational coverage should not be learned from this dataset alone.

### Allowed And Not Allowed

| Use this dataset for | Do not use this dataset for |
| :--- | :--- |
| Pipeline compatibility and packaging checks | Final field-performance claims |
| Truth alignment and geometry sanity checks | Field CFAR threshold tuning |
| Signal-mitigation debugging | Final tracker confirmation/deletion tuning |
| Controlled regression testing | Clutter or multipath realism claims |
| Conditioned-vs-full-seed comparison | RCS or aspect-model conclusions |

## Likely Technical Audience Questions And Suggested Mitigations

| Likely question | Why it will be asked | Suggested mitigation |
| :--- | :--- | :--- |
| How field-like is this dataset really? | Capture-backed truth can sound more realistic than the RF actually is | Lead with a two-part statement: capture-backed kinematics, synthetic RF |
| Are the globe trajectories the same paths used for synthesis? | Audiences will suspect preview-only truth | Keep stating that the preview consumes the same sampled `truth_bundle.targets` used downstream |
| Why were some aircraft excluded? | Curated truth can hide difficulty | Always attach the selection table with include/exclude reasons |
| Does conditioned mode make the data too easy? | It is a synthetic usability intervention | Present conditioned and full-seed modes as a paired comparison, not as one hidden default |
| Can we tune detector thresholds on this now? | People will want to use available data aggressively | Require a field revalidation gate before accepting threshold changes |
| If readiness passes, are we done? | Pass/fail labels invite overclaiming | Add a standing note that readiness pass supports intermediate workflow validation only |
| If readiness fails only on `vertical_column_defect`, should we ignore it? | The failure is known and tempting to dismiss | Report it separately from placement and direct-path failures, but do not hide it |
| Why did one wrapper test fail if manual replay is still considered usable? | Audiences will ask about confidence in automation | Classify the current failure as an execution-harness/output-stream issue until reproduced as an algorithmic failure |

## Recommended Guardrails Before Using Synthetic Results To Change The Analysis Pipeline

- Tag every result set with `truth_source_mode`, target-echo dataset mode, selected truth window, and retained-aircraft count.
- Keep synthetic-informed parameter changes in a separate review lane from field-qualified changes.
- Re-check any threshold, gating, or tracker-logic change on field captures before accepting it.
- Use conditioned and full-seed comparison runs when judging mitigation changes.
- Preserve the selection table and readiness summary with every shared synthetic session.
