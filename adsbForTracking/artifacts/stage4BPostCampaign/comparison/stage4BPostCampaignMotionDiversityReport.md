# Stage 4B-Post ADS-B Motion-Diversity Gate

Generated: 2026-08-27 12:37:00 UTC

## Decision

- Local gated retraining readiness: **PASS**
- Broad generalization readiness: **FAIL**
- Neural retraining performed in this gate: **no**

Expanded-3Day meets the approved evidence thresholds for a separately authorized local-receiver retraining experiment. This does not establish that a learned predictor will outperform `constvel`.

The evaluated data use one receiver location and one local ADS-B collection domain; three campaign days cannot establish cross-location or cross-source generalization.

## Named Dataset Difference

`Expanded-3Day = Legacy-16 + 3-Day Campaign Increment`

The named difference **Expanded-3Day minus Legacy-16** adds 442890 pairs, 1790 aircraft, 2933 session/aircraft tracks, 26416 independent events, and 84 occupied joint-regime cells.

## Variant Summary

| Variant | Truth files | Usable files | Sessions | ICAO | Tracks | Pairs | Events | Occupied joint cells | constvel RMSE [m] | Frozen MLP RMSE [m] |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Legacy-16 | 16 | 16 | 16 | 188 | 222 | 15013 | 803 | 129 | 23.870 | 151.260 |
| 3-Day Campaign Increment | 143 | 138 | 138 | 1844 | 2933 | 442890 | 26416 | 213 | 24.542 | 213.460 |
| Expanded-3Day | 159 | 154 | 154 | 1978 | 3155 | 457903 | 27219 | 213 | 24.520 | 211.710 |
| Expanded-3Day minus Legacy-16 | 143 | 138 | 138 | 1790 | 2933 | 442890 | 26416 | 84 | NaN | NaN |

## Local Retraining Gates

| Gate | Observed | Required | Result |
| :--- | :--- | :--- | :---: |
| all source files classified | 143/143 classified; 0 parse failures | all classified; zero failures | PASS |
| campaign files with usable pairs | 138/143 (96.5%) | >=95% | PASS |
| sustained turn diversity | 1276 events, 483 ICAO, 3 campaign days | >=30 events, >=10 ICAO, 3 campaign days | PASS |
| sustained acceleration diversity | 7588 events, 1191 ICAO, 3 campaign days | >=30 events, >=10 ICAO, 3 campaign days | PASS |
| sustained climb diversity | 1841 events, 989 ICAO, 3 campaign days | >=50 events, >=15 ICAO, 3 campaign days | PASS |
| sustained descent diversity | 1478 events, 859 ICAO, 3 campaign days | >=50 events, >=15 ICAO, 3 campaign days | PASS |
| sparse-update diversity | 15036 events, 2715 tracks, 3 campaign days | >=100 events, >=20 tracks, 3 campaign days | PASS |
| contributor concentration | max ICAO 1.6%; max campaign day 46.6% | each critical regime: ICAO <=20%, campaign day <=60% | PASS |
| aircraft-disjoint split support | minimum train/validation/test = 756/253/267 events | all regimes in train; >=5 each in validation/test | PASS |
| chronological split support | minimum train/validation/test = 996/151/97 events | all regimes in train; >=5 each in validation/test | PASS |
| expanded independent coverage | +26416 events; +84 occupied cells | positive events and occupied cells | PASS |
| no neural retraining | 0 retraining run(s) | 0 | PASS |

## Independent Event Coverage

| Variant | Event | Count | ICAO | Tracks | Sessions | Campaign days | Largest ICAO [%] | Largest campaign day [%] |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Legacy-16 | sustained turn | 39 | 20 | 21 | 11 | 0 | 23.1 | NaN |
| Legacy-16 | sustained acceleration | 275 | 83 | 91 | 16 | 0 | 4.4 | NaN |
| Legacy-16 | sustained climb | 76 | 62 | 74 | 15 | 0 | 3.9 | NaN |
| Legacy-16 | sustained descent | 77 | 62 | 66 | 15 | 0 | 5.2 | NaN |
| Legacy-16 | sparse gap | 336 | 122 | 137 | 16 | 0 | 3.6 | NaN |
| 3-Day Campaign Increment | sustained turn | 1237 | 467 | 610 | 109 | 3 | 1.7 | 46.6 |
| 3-Day Campaign Increment | sustained acceleration | 7313 | 1126 | 1657 | 129 | 3 | 1.7 | 41.8 |
| 3-Day Campaign Increment | sustained climb | 1765 | 942 | 1197 | 125 | 3 | 0.6 | 36.6 |
| 3-Day Campaign Increment | sustained descent | 1401 | 804 | 974 | 128 | 3 | 0.9 | 36.5 |
| 3-Day Campaign Increment | sparse gap | 14700 | 1703 | 2578 | 137 | 3 | 0.5 | 35.4 |
| Expanded-3Day | sustained turn | 1276 | 483 | 631 | 120 | 3 | 1.6 | 46.6 |
| Expanded-3Day | sustained acceleration | 7588 | 1191 | 1748 | 145 | 3 | 1.6 | 41.8 |
| Expanded-3Day | sustained climb | 1841 | 989 | 1271 | 140 | 3 | 0.5 | 36.6 |
| Expanded-3Day | sustained descent | 1478 | 859 | 1040 | 143 | 3 | 0.8 | 36.5 |
| Expanded-3Day | sparse gap | 15036 | 1790 | 2715 | 153 | 3 | 0.5 | 35.4 |

### Expanded-3Day minus Legacy-16

| Event | Added events | Added duration [s] |
| :--- | ---: | ---: |
| sustained turn | 1237 | 17061.8 |
| sustained acceleration | 7313 | 75260.5 |
| sustained climb | 1765 | 205824.8 |
| sustained descent | 1401 | 148651.6 |
| sparse gap | 14700 | 148595.0 |

## Reproducibility

Dataset membership is frozen in `adsb_archive/datasetVersions/adsbDatasetVariants.csv`; each source path is verified against its SHA-256 digest before evaluation. Variant artifacts remain separate from historical `artifacts/stage3C/`.

```matlab
legacy = runADSBDatasetVariantEvaluation("legacy_pre3day_v1");
increment = runADSBDatasetVariantEvaluation("campaign_3day_increment_v1");
expanded = runADSBDatasetVariantEvaluation("expanded_post3day_v2");
comparison = runStage4BPostCampaignMotionDiversityGate;
```

Detailed CSV tables and six figures are stored beside this report. The refreshed Stage 4A outputs explicitly load the Expanded-3Day artifact.
