# Decisions

## 2026-09-16 — Capture packages record physical provenance

Both supported capture paths require an `OperatorSetupNotes` value for a live
capture. Interactive MATLAB prompts once when it is empty; headless and shell
execution refuse to begin ADS-B logging or RF capture without it. The value is
written verbatim as `operator_setup_notes` in manifest version 3.

The note is deliberately free-form. It must identify both channel antenna and
inline chains, polarization, approximate pointing and height, channel-mapping
proof, and any anomaly, weather, or setup deviation. Structured equipment
inventory remains deferred.

## 2026-09-16 — Channel identity is declared, never inferred

Every package stores ordered `channel_mapping` entries containing stored
channel index, N320 port, semantic role, and named gain. Ports and roles flow
from the trigger/local request through baseband metadata and package writers;
relative RF power never determines or swaps channel roles.

## 2026-09-16 — This milestone remains commissioning-only

The collection sequence provides hardware evidence only. It does not create
formal aircraft opportunities, retune the detector, change detector support,
or establish aircraft detections.

## 2026-09-16 — ADSB-remoter remains pinned external test data

The integration dependency is declared at
`external/ADSB-remoter`, commit
`63ff6688628c2813e4287c5ecdc0df67883c3f93`, matching the preparation
worktree. The integration worktree contains the corresponding gitlink and
checkout; its fixture-adapter regression suite passes 6/6.
