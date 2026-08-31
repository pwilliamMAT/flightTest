# ADS-B Dataset Variants

Generated: 2026-08-26 21:38:31 UTC

The raw archive is append-only. This manifest freezes source membership so each evaluation remains independently rerunnable.

| Variant ID | Display name | Truth files |
| :--- | :--- | ---: |
| `legacy_pre3day_v1` | Legacy-16 | 16 |
| `campaign_3day_increment_v1` | 3-Day Campaign Increment | 143 |
| `expanded_post3day_v2` | Expanded-3Day | 159 |

Transfer ZIP SHA-256: `BE2457298D38768DB950BF0A2EE15DBE5B5264B8532220F4AD6E44B4DA56AF3C`

No-truth campaign session retained for provenance: `stage4B_3Day_nohup_20260819T132526Z_w133_20260822T072740Z`.

Rerun with:

```matlab
legacy = runADSBDatasetVariantEvaluation("legacy_pre3day_v1");
increment = runADSBDatasetVariantEvaluation("campaign_3day_increment_v1");
expanded = runADSBDatasetVariantEvaluation("expanded_post3day_v2");
comparison = runStage4BPostCampaignMotionDiversityGate;
```
