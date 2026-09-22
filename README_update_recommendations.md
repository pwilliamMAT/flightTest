# Root README Update Recommendations

No edit to `README.md` is included in this change.

## Patch plan

1. Add the concise `NEW HERE` section below immediately after the title and
   before `Project Overview`.
2. Keep the existing reporting paragraph temporarily, but replace it with a
   shorter link list after readers have adopted the new navigation path.
3. In a later, separately reviewed edit, move detailed capture syntax to
   `TestSetupTesting/README.md` and detailed session-analysis instructions to
   a dedicated `BistaticDataAnalysis/README.md` or a confirmed existing
   subsystem entry page.
4. Remove duplicated hardware metrics, system configuration values, and
   report findings from the root only after their owning report/subsystem link
   has been verified.
5. Remove the two non-printing control characters before the
   `TestSetupTesting/` and `ADSB_GPS/` headings while making that future edit.

This staged approach improves orientation first and does not disturb active
collection or replay procedures.

## Proposed `NEW HERE` section

```md
## New here

FlightTest provides passive-bistatic radar collection, session packaging,
replay, and reporting infrastructure. Read the accepted reports as
evidence-led engineering: installed infrastructure and controlled synthetic
results do not by themselves establish live-aircraft or operational
performance.

Start with the role-based guide:

- **Manager or new engineer:** [Start Here](reporting/docs/START_HERE.md) —
  begin with `FlightTest_EndToEnd_HumanStory_V2`, then current status.
- **Developer or technical contributor:** [Engineering Index](reporting/docs/ENGINEERING_INDEX.md) —
  find reports, code entry points, data sources, and ownership by topic.
- **Collection operator:** [TestSetupTesting README](TestSetupTesting/README.md) —
  supported capture, package, and synchronization procedures.
- **Session-analysis user:** [BistaticDataAnalysis](BistaticDataAnalysis/) —
  use `runBistaticAnalysisSession.m` for a packaged session.
- **External or large artifact:** [Source Materials](reporting/docs/SOURCE_MATERIALS.md).

### Two connected repositories

- **flightTest** owns collection hardware, capture packaging, operational
  replay, and the accepted reporting family.
- **PassiveBistaticRestart** owns passive-pipeline reconstruction, gate
  validation, synthetic recovery studies, and external evidence artifacts.

See the [repository ownership map](repository_ownership_map.md) before moving
code, changing a capture-package contract, or treating a reconstruction
artifact as an accepted FlightTest update.
```

## Why this is sufficient for the first patch

The section lets a fresh clone answer the five onboarding questions without
making the root README a second report catalog or a replacement operating
manual:

| Question | Answering link |
| --- | --- |
| What is this project? | The opening paragraph and [Start Here](reporting/docs/START_HERE.md) |
| What should I read first? | Role-based Start Here link |
| Where is the code? | Engineering Index and subsystem README links |
| Where is the data? | Engineering Index and Source Materials |
| Which repository owns which work? | Repository ownership map |

The proposed section deliberately points to existing reports and code. It does
not generate, restate, or replace report content.
