# ---------------------------------------------------------------------------
# _test_engine.R — sanity checks
#
# Every hand-written estimator is checked against either an independent
# reference implementation or the analytic truth. Run this before trusting
# anything in the chapters:
#
#     Rscript R/_test_engine.R
# ---------------------------------------------------------------------------

source("R/simulate.R")
source("R/metrics.R")

ok <- TRUE
check <- function(label, got, want, tol) {
  pass <- isTRUE(abs(got - want) < tol)
  ok <<- ok && pass
  cat(sprintf("%-52s %10.5f vs %10.5f  %s\n",
              label, got, want, if (pass) "PASS" else "FAIL"))
}

cat("\n--- Validating from-scratch estimators ---\n\n")

df <- simulate_predictions()

## 1. AUROC against the Mann-Whitney U statistic from wilcox.test ------------
##    Same identity, entirely different code path.
w <- wilcox.test(score ~ factor(label), data = df, exact = FALSE)
auc_ref <- unname(w$statistic) / (sum(df$label == 0) * sum(df$label == 1))
check("AUROC (hand-written) vs wilcox.test U",
      auroc(df$label, df$score), 1 - auc_ref, 1e-9)

## 2. AUROC against the analytic truth ---------------------------------------
##    Phi(d / sqrt(2)) is the population value the sample should approach.
tt <- truth_table()
for (i in seq_len(nrow(tt))) {
  g   <- tt$group[i]
  sub <- df[df$group == g, ]
  check(sprintf("AUROC in %-7s vs analytic Phi(d/sqrt2)", g),
        auroc(sub$label, sub$score), tt$true_auroc[i],
        if (nrow(sub) > 500) 0.05 else 0.15)
}

## 3. AUROC is invariant to monotone transformation --------------------------
##    Ranks do not care whether we are on the logit or probability scale.
check("AUROC invariant to logit transform",
      auroc(df$label, df$latent), auroc(df$label, df$score), 1e-12)

## 4. Degenerate cases -------------------------------------------------------
check("AUROC of a random score is about 0.5",
      auroc(df$label, runif(nrow(df))), 0.5, 0.03)
check("AUROC of the outcome itself is 1",
      auroc(df$label, df$label + 0.0), 1.0, 1e-12)

## 5. Sensitivity / specificity against a hand-built confusion table ---------
thr  <- 0.5
pred <- as.integer(df$score >= thr)
tab  <- table(factor(pred, 0:1), factor(df$label, 0:1))
check("Sensitivity vs confusion table",
      sensitivity(df$label, df$score, thr), tab["1", "1"] / sum(tab[, "1"]), 1e-12)
check("Specificity vs confusion table",
      specificity(df$label, df$score, thr), tab["0", "0"] / sum(tab[, "0"]), 1e-12)

## 6. Calibration slope against a direct glm --------------------------------
fit <- glm(label ~ qlogis(pmin(pmax(score, 1e-6), 1 - 1e-6)),
           family = binomial(), data = df)
check("Calibration slope vs direct glm",
      calibration(df$label, df$score)[["slope"]], unname(coef(fit)[2]), 1e-9)

## 7. A perfectly calibrated score has ECE near zero ------------------------
set.seed(99)
p  <- runif(20000)
y  <- rbinom(20000, 1, p)
check("ECE of a perfectly calibrated score", ece(y, p), 0, 0.02)
check("Calibration slope of a calibrated score", calibration(y, p)[["slope"]],
      1.0, 0.08)

## 8. Bootstrap coverage -----------------------------------------------------
##    The interval should contain the truth about 95% of the time. Anything
##    much below that means the interval is decorative.
cat("\n--- Bootstrap coverage (200 replicate datasets, group V-VI) ---\n")
covered <- 0L; n_rep <- 200L
truth_vvi <- true_auroc(GROUPS[["V-VI"]]$d)
for (r in seq_len(n_rep)) {
  set.seed(10000 + r)
  yy <- rbinom(160, 1, PREVALENCE)
  ss <- plogis(rnorm(160, mean = yy * GROUPS[["V-VI"]]$d, sd = 1))
  ci <- boot_ci(yy, ss, auroc, n_boot = 400L, seed = r)
  if (!is.na(ci[["lower"]]) && truth_vvi >= ci[["lower"]] &&
      truth_vvi <= ci[["upper"]]) covered <- covered + 1L
}
cov_rate <- covered / n_rep
check("Empirical coverage of nominal 95% interval", cov_rate, 0.95, 0.06)

cat("\n", if (ok) "All checks passed.\n" else "SOME CHECKS FAILED.\n", sep = "")
quit(status = if (ok) 0 else 1)
