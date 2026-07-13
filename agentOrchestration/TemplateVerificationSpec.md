# Template: Verification Spec

Use this after `Requirements Review` and `Design` are complete. This is the authoritative verification contract owned by the `Independent Quality Gatekeeper`.

Implementation does not begin until this artifact is approved.

## Metadata
- Session:
- Date:
- Current phase: `Test Design`
- Related Requirements Packet:
- Related Requirements Review Packet:
- Related Design Packet:
- Gatekeeper:
- Status: `Draft` | `Rejected` | `Approved` | `Superseded`

## Gate Decision
- Gate status: `Reject` | `Revise` | `Approve`
- Decision summary:
- Human waiver required to bypass rejection: `Yes`

## Scope Under Test
- Operational claim:
- Scope boundary:
- Out of scope:
- Failure classes to distinguish:

## Required Evidence Layers
### Software Verification
- Required checks:
- Required environments or fixtures:

### Requirements-Based Verification
- Required requirement coverage:
- Coverage gaps currently accepted:

### Operational Validation
- Required end-outcome proof:
- Scenarios or truth sources required:

## Anti-Flake Rules
- Deterministic inputs by default: `Required`
- Controlled seeds for stochastic behavior: `Required`
- Wall-clock timing dependence allowed only when timing is itself a requirement: `Required`
- Hidden environment dependencies allowed: `No`
- Informative failure messages required: `Yes`

## Requirement-To-Check Traceability
| Requirement ID | Requirement summary | Check IDs | Evidence layer(s) |
| :--- | :--- | :--- | :--- |
| REQ-001 |  | CHK-001 |  |
| REQ-002 |  | CHK-002 |  |

## Check Catalog
### `CHK-001`
- Requirement under test:
- Claim proved:
- Setup and procedure:
- Pass criteria:
- Fail criteria:
- Negative control:
- Regression control:
- Known blind spots:
- Failure artifact required:

### `CHK-002`
- Requirement under test:
- Claim proved:
- Setup and procedure:
- Pass criteria:
- Fail criteria:
- Negative control:
- Regression control:
- Known blind spots:
- Failure artifact required:

## Fixtures And Dependencies
- Fixture 1:
- Fixture 2:
- Controlled seeds:
- External dependencies explicitly declared:

## Blocking Questions Or Missing Information
- Blocking question 1:
- Missing requirement-to-check traceability:
- Missing pass or fail criteria:
- Missing negative or regression control:
- Missing fixture or environment declaration:

## Failure Interpretation
- If `CHK-001` fails:
- If `CHK-002` fails:
- Conditions that require reopening review instead of more coding:

## Anti-False-Confidence Notes
- Misleading green pattern 1:
- Misleading green pattern 2:

## Approval
- Human sign-off required before implementation: `Yes`
- Approved by:
- Approval date:
