# ---------------------------------------------------------------------------
# metrics.R — evaluation metrics written from scratch
#
# Pure base R, no packages. Every estimator here is a few lines you can read
# and change, and each is cross-checked in R/_test_engine.R against either a
# base-R reference (wilcox.test, glm) or the analytic truth.
# ---------------------------------------------------------------------------


# --- Discrimination --------------------------------------------------------

#' AUROC, computed as the Mann-Whitney U statistic
#'
#' The area under the ROC curve is exactly the probability that a randomly
#' chosen event scores higher than a randomly chosen non-event. That identity
#' is the whole computation: rank the scores, sum the ranks of the events,
#' subtract the ranks they would occupy if they were all at the bottom, and
#' divide by the number of possible pairs. Ties contribute one half, which
#' average ranking handles automatically.
auroc <- function(label, score) {
  if (length(unique(label)) < 2L) return(NA_real_)
  n1 <- sum(label == 1L)
  n0 <- sum(label == 0L)
  r  <- rank(score)
  (sum(r[label == 1L]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}


#' Sensitivity (true positive rate) at a threshold
sensitivity <- function(label, score, threshold = 0.5) {
  pos <- label == 1L
  if (!any(pos)) return(NA_real_)
  mean(score[pos] >= threshold)
}


#' Specificity (true negative rate) at a threshold
specificity <- function(label, score, threshold = 0.5) {
  neg <- label == 0L
  if (!any(neg)) return(NA_real_)
  mean(score[neg] < threshold)
}


# --- Calibration -----------------------------------------------------------

#' Calibration slope and intercept
#'
#' Regress the outcome on the logit of the predicted probability. A
#' well-calibrated model gives slope 1 and intercept 0. Slope below 1 means
#' the predictions are too extreme -- the usual signature of overfitting, and
#' the usual finding when a model developed in one population is applied to
#' another.
calibration <- function(label, score, eps = 1e-6) {
  s <- pmin(pmax(score, eps), 1 - eps)
  fit <- glm(label ~ qlogis(s), family = binomial())
  c(intercept = unname(coef(fit)[1]), slope = unname(coef(fit)[2]))
}


#' Expected calibration error, equal-width bins
#'
#' A blunt instrument, and sensitive to the number of bins, but it summarises
#' in one number how far predicted probabilities sit from observed rates.
ece <- function(label, score, n_bins = 10L) {
  bins <- cut(score, breaks = seq(0, 1, length.out = n_bins + 1L),
              include.lowest = TRUE)
  parts <- tapply(seq_along(label), bins, function(ix) {
    if (length(ix) == 0L) return(0)
    (length(ix) / length(label)) * abs(mean(label[ix]) - mean(score[ix]))
  })
  sum(unlist(parts), na.rm = TRUE)
}


#' Brier score
brier <- function(label, score) mean((score - label)^2)


# --- Uncertainty -----------------------------------------------------------

#' Percentile bootstrap interval for any metric
#'
#' Resampling is stratified by outcome, so replicates preserve the observed
#' number of events. Unstratified resampling in a small subgroup regularly
#' produces replicates containing no events at all, at which point the metric
#' is undefined and the interval quietly becomes a statement about which
#' replicates happened to survive.
boot_ci <- function(label, score, fn, n_boot = 2000L, alpha = 0.05,
                    seed = 1L, ...) {
  point <- fn(label, score, ...)
  ix1 <- which(label == 1L)
  ix0 <- which(label == 0L)
  if (length(ix1) < 2L || length(ix0) < 2L) {
    return(c(estimate = point, lower = NA_real_, upper = NA_real_))
  }

  set.seed(seed)
  stats <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    ix <- c(sample(ix1, replace = TRUE), sample(ix0, replace = TRUE))
    stats[b] <- fn(label[ix], score[ix], ...)
  }
  stats <- stats[is.finite(stats)]
  q <- quantile(stats, c(alpha / 2, 1 - alpha / 2), names = FALSE)
  c(estimate = point, lower = q[1], upper = q[2])
}


# --- Stratified reporting --------------------------------------------------

#' Per-subgroup performance table with bootstrap intervals
#'
#' Undersized strata are flagged rather than dropped. A subgroup too small to
#' support inference is a finding about the dataset; removing it converts a
#' data limitation into an apparently clean result.
#'
#' The flag counts events, not rows. Precision in a discrimination metric is
#' governed by the rarer class: a stratum of 5,000 patients containing 12
#' events is a stratum of 12, whatever the denominator suggests.
stratified_report <- function(df, group_col = "group", threshold = 0.5,
                              n_boot = 2000L, min_events = 100L) {
  groups <- c("__overall__", sort(unique(df[[group_col]])))

  rows <- lapply(groups, function(g) {
    sub <- if (identical(g, "__overall__")) df else df[df[[group_col]] == g, ]
    y <- sub$label; s <- sub$score

    a  <- boot_ci(y, s, auroc, n_boot = n_boot)
    se <- boot_ci(y, s, sensitivity, n_boot = n_boot, threshold = threshold)
    cal <- calibration(y, s)

    data.frame(
      group        = g,
      n            = nrow(sub),
      events       = sum(y),
      auroc        = a[["estimate"]],
      auroc_lo     = a[["lower"]],
      auroc_hi     = a[["upper"]],
      ci_width     = a[["upper"]] - a[["lower"]],
      sensitivity  = se[["estimate"]],
      specificity  = specificity(y, s, threshold),
      cal_slope    = cal[["slope"]],
      ece          = ece(y, s),
      brier        = brier(y, s),
      underpowered = sum(y) < min_events && g != "__overall__",
      row.names    = NULL
    )
  })

  do.call(rbind, rows)
}


#' Equalised-odds gaps at a shared threshold
#'
#' Note the assumption under test: that one operating threshold is appropriate
#' for every subgroup. Where it is not, these gaps are the price of pretending
#' otherwise.
equalised_odds <- function(df, group_col = "group", threshold = 0.5) {
  gs <- sort(unique(df[[group_col]]))
  tpr <- sapply(gs, function(g) {
    s <- df[df[[group_col]] == g, ]; sensitivity(s$label, s$score, threshold)
  })
  fpr <- sapply(gs, function(g) {
    s <- df[df[[group_col]] == g, ]; 1 - specificity(s$label, s$score, threshold)
  })
  list(tpr = tpr, fpr = fpr,
       tpr_gap = max(tpr) - min(tpr),
       fpr_gap = max(fpr) - min(fpr),
       worst = names(which.min(tpr)))
}


#' What threshold does each subgroup need to reach a target sensitivity,
#' and what does that cost in specificity?
group_thresholds <- function(df, group_col = "group", target = 0.90) {
  gs <- sort(unique(df[[group_col]]))
  do.call(rbind, lapply(gs, function(g) {
    sub <- df[df[[group_col]] == g, ]
    thr <- unname(quantile(sub$score[sub$label == 1L], 1 - target))
    data.frame(
      group       = g,
      threshold   = thr,
      sensitivity = sensitivity(sub$label, sub$score, thr),
      specificity = specificity(sub$label, sub$score, thr),
      row.names   = NULL
    )
  }))
}


# --- Power -----------------------------------------------------------------

#' Events per arm needed to detect a given AUROC gap
#'
#' Uses the Hanley-McNeil variance approximation for a single AUROC and a
#' normal test for the difference of two independent AUROCs. Approximate, and
#' good enough to make the point that most published subgroup analyses are not
#' powered to find the thing they claim to have looked for.
n_events_for_gap <- function(auc1, auc2, ratio_neg_pos = 3.5,
                             alpha = 0.05, power = 0.80) {
  hm_var <- function(a, n1, n0) {
    q1 <- a / (2 - a); q2 <- 2 * a^2 / (1 + a)
    (a * (1 - a) + (n1 - 1) * (q1 - a^2) + (n0 - 1) * (q2 - a^2)) / (n1 * n0)
  }
  z_a <- qnorm(1 - alpha / 2); z_b <- qnorm(power)
  f <- function(n1) {
    n0 <- n1 * ratio_neg_pos
    v <- hm_var(auc1, n1, n0) + hm_var(auc2, n1, n0)
    abs(auc1 - auc2) / sqrt(v) - (z_a + z_b)
  }
  n <- 5
  while (f(n) < 0 && n < 1e6) n <- n + 5
  n
}
