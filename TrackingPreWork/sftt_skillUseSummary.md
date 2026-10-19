# SFTT skill-use summary

## 2026-10-13 — localization-likelihood POC

- **Skills consulted:** pinned `matlab-multi-object-tracking` and `matlab-import-tracking-data` under `C:/Users/pwilliam/agenticProjects/toolkits/sensor-fusion-and-tracking-toolbox/.claude/skills`.
- **Files read:** both `SKILL.md` files; multi-object-tracking `references/toolbox-functions.md`; import-tracking-data `references/coordinate-transforms.md`.
- **Task:** implement the approved static range-only localization/geometry/RF study, using existing excess-range and ENU conventions without running the processing pipeline.
- **Effect:** retained explicit measurement units and receiver-centered coordinates; kept the study outside tracking/data-association scope as the skill exclusions advise. No `objectDetection`, filter initialization, tracker, truth import, or fuser was introduced. Native `crlb` and `tsoaposest` belong to Phased Array System Toolbox and provide focused localization verification.
- **Results:** full MATLAB R2026a runner completed; 34/34 tests passed, including native verification, height conversion, covariance/availability invariants, explicit RF, and cache/fallback checks. Numerical results are linked from [report.md](docs/localizationLikelihood/report.md).
- **Other skills applied:** `matlab-analyze-rf-propagation/SKILL.md` and `matlab-testing/SKILL.md` from `C:/Users/pwilliam/.agents/skills`. The user's approved plan already authorized the tests, so no additional approval step was needed.
