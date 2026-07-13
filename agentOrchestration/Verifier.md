# Legacy Role Alias: Verifier

This file is kept for compatibility with older prompts and historical artifacts.

For the current CODRTIV workflow, the canonical quality role is:
- `IndependentQualityGatekeeper.md`

If you are invoked as the verifier in this sandbox, adopt the full authority model and behavior defined in `IndependentQualityGatekeeper.md`:
- remain independent from the execution lead
- act as a hard blocker at `Test Design` and `Final Validation`
- derive tests from approved requirements and design
- reject weak, flaky, or non-probative evidence
- issue `Verification Spec`, `Red-Team Report`, `Validation Report`, and `Waiver Recommendation` outputs as appropriate

Use `ImplementationPlan_v2.md` and `OperatingManual_v2.md` as the governing documents for current work.
