# FlightTest and PassiveBistaticRestart: Repository Ownership Map

## In one minute

The repositories are one engineering effort with different responsibilities:

- **flightTest** is the operational system repository: collection hardware,
  acquisition coordination, packaged-session handoff, replay utilities, and
  the accepted reporting family.
- **PassiveBistaticRestart** is the controlled reconstruction repository:
  passive-pipeline gates, map-rate validation, mitigation/recovery studies,
  and the compact evidence bundles that support those studies.

They should exchange explicit package contracts, code changes, and evidence
references. They should not rely on hidden shared working-state or duplicate
ownership of a gate decision.

## Ownership at a glance

| Area | flightTest | PassiveBistaticRestart |
| --- | --- | --- |
| Collection hardware and Pi/SDR coordination | Owns | Consumes compatible captures |
| Packaged session contract | Owns | Depends on it |
| Operational session replay and truth diagnostics | Owns | May use equivalent data for gate work |
| Synthetic signal-processing experiments | Hosts local experiments and reporting context | Owns formal gated recovery studies |
| Passive pipeline reconstruction and gate decisions | Receives selected mature integrations | Owns G1–G10 reconstruction, current G4-R closure, and gate records |
| Recovery and atlas artifacts | References them in accepted reports | Owns authoritative generated artifact bundles |
| Accepted technical reports and onboarding | Owns `reporting/` | Supplies referenced technical evidence only |

## FlightTest

| Aspect | Responsibility |
| --- | --- |
| Purpose | Operate and evolve the collection, packaging, replay, and communication infrastructure for FlightTest. |
| Inputs | N320 dual-channel IQ; ADS-B/GPS truth; Pi and SDR configuration; antenna/RF hardware; source-material references; MATLAB/toolbox environment. |
| Outputs | `captures/<session_id>/` package containing `radar/`, `truth/`, `logs/`, and `session_manifest.json`; operational analysis/replay snapshots; accepted reports, explainers, audits, and navigation. |
| Primary code | `TestSetupTesting/run_coordinated_hdtv_capture.sh`, `TestSetupTesting/runLocalHDTVCapture.m`, `TestSetupTesting/sync_capture_session.sh`, `ADSB_GPS/`, and `BistaticDataAnalysis/runBistaticAnalysisSession.m`. |
| Dependencies | SDR/Pi collection environment; MATLAB and required toolboxes; capture-package storage; PassiveBistaticRestart artifacts when reports cite gate/recovery evidence. |
| Does not own | The authoritative G4-R reconstruction decision, formal map-rate matrix, or G4-R atlas generation. |

## PassiveBistaticRestart

| Aspect | Responsibility |
| --- | --- |
| Purpose | Rebuild and validate the passive-bistatic pipeline gate by gate, with explicit contracts, evidence, and decision boundaries. |
| Inputs | FlightTest-compatible dual-channel session packages or copied baseline data; `session_manifest.json`; frozen gate configurations; declared synthetic conditions; existing evidence artifacts. |
| Outputs | Gate results, compact evidence bundles under `artifacts/`, map-rate/recovery studies, G4-R atlas material, project state, and decision records. |
| Primary code | `runG4PassiveBaselineMap.m`, `runG4RMapRateValidity.m`, `runG4RMapRateMatrix.m`, `runG4RCloseTargetAtlasRecoveryStudy.m`, and associated helpers. |
| Dependencies | Compatible capture/package semantics from FlightTest; MATLAB/toolboxes; retained local baseline data; explicit gate plans and decision records. |
| Does not own | Field collection hardware, the production capture coordinator, the canonical FlightTest reporting site, or automatic promotion of diagnostic evidence into an operational claim. |

## How the repositories interact

```text
FlightTest hardware + ADS-B/GPS
            |
            v
FlightTest packaged session
captures/<session_id>/
            |
            +--> FlightTest operational replay and diagnostics
            |
            v
PassiveBistaticRestart gate reconstruction,
map-rate validation, recovery, and compact evidence
            |
            v
Reviewed evidence references and selectively mature changes
            |
            v
FlightTest accepted reporting family / chosen integrations
```

## Integration rules

1. **Package changes start in FlightTest.** Changes to file layout,
   `session_manifest.json`, channel labels, or collection metadata need an
   explicit compatibility check before PassiveBistaticRestart consumes them.
2. **Gate decisions stay in PassiveBistaticRestart until reviewed.** A
   generated artifact or a passing diagnostic does not automatically change
   FlightTest operational behavior or report claims.
3. **Reports cite evidence; they do not absorb the artifact system.**
   FlightTest `reporting/` links to accepted external summaries and preserves
   claim boundaries without copying large atlas, raw-IQ, or presentation
   outputs.
4. **Mature code returns by selective integration.** Import a bounded,
   reviewed function or contract with its tests and evidence reference; do not
   copy an entire reconstruction working tree into FlightTest.
5. **Status has two views.** Report 06 is the accepted FlightTest status
   communication. `PassiveBistaticRestart/PROJECT_STATE.md` is the detailed
   active reconstruction authority.

## Where to start

- Manager or new engineer: [`reporting/docs/START_HERE.md`](reporting/docs/START_HERE.md)
- Developer finding an entry point: [`reporting/docs/ENGINEERING_INDEX.md`](reporting/docs/ENGINEERING_INDEX.md)
- Operator packaging or replaying a session: [`TestSetupTesting/README.md`](TestSetupTesting/README.md)
- Researcher working a formal passive-pipeline gate: the
  `PassiveBistaticRestart` `PROJECT_STATE.md` and its active plan
