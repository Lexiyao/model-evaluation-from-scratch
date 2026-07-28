# Model Evaluation from Scratch

**A worked example in R — why one AUROC tells you almost nothing, built up one estimator at a time.**

📖 **Read it here → [lexiyao.github.io/model-evaluation-from-scratch](https://lexiyao.github.io/model-evaluation-from-scratch/)**

---

A clinical prediction model is usually reported as a single number. That number is an average over a population, and averages are exactly the wrong summary when the question is whether the model works for the people least represented in the data that built it.

This is a readable, end-to-end walkthrough that codes the standard evaluation toolkit **from scratch** — AUROC as a rank statistic, calibration slope, expected calibration error, the stratified bootstrap, equalised-odds gaps, and a power calculation for subgroup differences. No metric is hidden inside a package. Each is cross-checked against an independent reference (`wilcox.test`, `glm`) or against an analytic truth.

> **All data are simulated.** No patient records, cohort or image dataset is used or shared anywhere in this repository. Simulation is deliberate: because the true AUROC in each subgroup is chosen up front and has a closed form — Φ(d/√2) for binormal scores with separation *d* — every estimate can be judged against the right answer rather than against another estimate.

---

## What's inside

| Chapter | Builds | Shows |
|---|---|---|
| 1 · The headline number | A single pooled AUROC | What an average conceals |
| 2 · The idea | — | Discrimination, calibration, and utility as three separate questions |
| 3 · The data | A seeded simulator | Subgroup performance with a *known* answer |
| 4 · Discrimination from scratch | AUROC as Mann-Whitney U | Cross-checked against `wilcox.test` |
| 5 · Uncertainty | Stratified bootstrap | Why the interval, not the estimate, is the finding |
| 6 · Calibration | Slope, intercept, ECE | Two calibration metrics disagreeing — and which one is wrong |
| 7 · Thresholds and fairness | Equalised odds, group thresholds | What a fixed clinical requirement actually costs |
| 8 · Takeaways | — | A checklist for reading any model-evaluation paper |

---

## Three headline results

### 1. The subgroup you can't see is the moderate one

| Group | n | events | **true** AUROC | estimate | 95% CI | CI width |
|---|---|---|---|---|---|---|
| Overall | 2860 | 597 | — | 0.867 | 0.852–0.883 | 0.031 |
| I–II | 1800 | 377 | 0.892 | 0.897 | 0.878–0.913 | 0.035 |
| III–IV | 900 | 181 | 0.847 | 0.855 | 0.824–0.883 | **0.058** |
| V–VI | 160 | 39 | 0.714 | **0.655** | 0.554–0.750 | **0.196** |

The obvious reading is that the small group is the problem. The more useful reading is the middle row. Detecting the true 0.045 gap in III–IV needs roughly **445 events per group**; the data contain 181. The dramatic gap in V–VI is, just barely, detectable — 39 events against the ~40 required. **The moderate, plausible, easy-to-miss gap is the one the study is not powered to find**, and it is the one that will be reported as "no significant difference between subgroups."

### 2. ECE misses what the calibration slope catches

| Group | calibration slope | ECE |
|---|---|---|
| Overall | 1.595 | 0.351 |
| I–II | 1.849 | 0.355 |
| III–IV | 1.501 | 0.356 |
| V–VI | **0.502** | 0.293 |

A slope of 0.50 in V–VI means predictions there are far too extreme; a slope of 1.85 in I–II means they are too conservative. These are opposite failures, and pooling them produces 1.60 — a number describing no one. Meanwhile ECE is essentially flat across all three groups and would have reported the model as equally calibrated everywhere. Chapter 6 works through why: ECE takes absolute values within bins, so systematic over- and under-prediction cancel in aggregate and its bin structure is insensitive to the direction of the error.

### 3. A fixed clinical requirement has a very different price in each group

Threshold needed to detect 90% of events:

| Group | threshold | resulting specificity |
|---|---|---|
| I–II | 0.617 | 0.699 |
| III–IV | 0.564 | 0.574 |
| V–VI | 0.256 | **0.132** |

Same clinical standard, same model. In the best-served group it means referring 30% of negatives; in the worst-served group, 87%. That is a service-design problem, not a rounding error, and it is invisible in every number reported above it.

---

## An honest limitation, measured

The percentile bootstrap used throughout **undercovers** at these sample sizes. Across 200 replicate datasets of the V–VI stratum, nominal 95% intervals contained the true AUROC **89.5%** of the time. The intervals in the table above are therefore, if anything, too narrow — which strengthens rather than weakens the argument. `R/_test_engine.R` measures this rather than assuming it; BCa or analytic (Hanley–McNeil) intervals would be the next step.

---

## Run it yourself

Requires [R](https://www.r-project.org/) and [Quarto](https://quarto.org/). The estimators are **pure base R with no package dependencies**; `ggplot2` is needed only for the figures.

```bash
# validate every estimator against its reference
Rscript R/_test_engine.R

# regenerate every number quoted above
Rscript R/make_results.R

# render the book to docs/
quarto render
```

The fastest way to understand any of this is to break the simulation on purpose. Open `R/simulate.R`, change the separation `d` in one stratum, or shrink `n` until the interval swallows the effect, and re-render.

---

## Repository layout

```
├── index.qmd                 # landing page
├── chapters/                 # the eight-chapter walkthrough (.qmd)
├── R/
│   ├── simulate.R            # seeded generator with analytic ground truth
│   ├── metrics.R             # AUROC, calibration, bootstrap, power — from scratch
│   ├── make_results.R        # reproduces every number in this README
│   ├── _test_engine.R        # validation against wilcox.test, glm, and truth
│   └── theme_eval.R          # ggplot2 theme
├── data/                     # generated synthetic predictions (CSV)
├── docs/                     # rendered site (GitHub Pages)
└── references.bib
```

---

## Further reading

The methods here come from:

- Hanley & McNeil (1982), *Radiology* — the ROC area and its standard error. [doi:10.1148/radiology.143.1.7063747](https://doi.org/10.1148/radiology.143.1.7063747)
- Steyerberg et al. (2010), *Epidemiology* — assessing the performance of prediction models. [doi:10.1097/EDE.0b013e3181c30fb2](https://doi.org/10.1097/EDE.0b013e3181c30fb2)
- Van Calster et al. (2019), *BMC Medicine* — calibration, the Achilles heel of predictive analytics. [doi:10.1186/s12916-019-1466-7](https://doi.org/10.1186/s12916-019-1466-7)
- Collins et al. (2024), *BMJ* — TRIPOD+AI reporting guideline. [doi:10.1136/bmj-2023-078378](https://doi.org/10.1136/bmj-2023-078378)
- Vickers & Elkin (2006), *Med Decis Making* — decision curve analysis. [doi:10.1177/0272989X06295361](https://doi.org/10.1177/0272989X06295361)

## Licence

[MIT](LICENSE) © 2026 Zixi Yao
