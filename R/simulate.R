# ---------------------------------------------------------------------------
# simulate.R — a seeded generator with a KNOWN answer
#
# The design mirrors the situation this book is about: a prediction model that
# works well in the group that dominates the data and less well in the group
# that does not.
#
# Crucially, the truth is not merely planted, it is *computable*. If scores in
# the non-event group are N(0, 1) and in the event group N(d, 1), the true
# AUROC has a closed form:
#
#       AUROC = P(X_event > X_non-event) = Phi(d / sqrt(2))
#
# So every estimate in the chapters that follow can be judged against the
# right answer, not merely against another estimate.
# ---------------------------------------------------------------------------

# Separation d in each stratum, and the resulting true AUROC.
# The imbalance across strata is chosen to resemble published dermatology
# image datasets, in which Fitzpatrick V-VI is routinely under 5% of images.
GROUPS <- list(
  "I-II"   = list(n = 1800, d = 1.75),
  "III-IV" = list(n =  900, d = 1.45),
  "V-VI"   = list(n =  160, d = 0.80)
)

PREVALENCE <- 0.22
SEED <- 2026


#' True AUROC implied by a separation d (binormal, equal variance)
#'
#' @param d Mean difference between event and non-event score distributions
#' @return The population AUROC
true_auroc <- function(d) {
  pnorm(d / sqrt(2))
}


#' Generate one dataset of predicted probabilities
#'
#' @param groups Named list of list(n=, d=)
#' @param prevalence Event probability, held constant across strata so that
#'   any performance gap cannot be attributed to differing base rates
#' @param seed RNG seed
#' @return data.frame with columns: id, group, label, score, and the latent
#'   score on the logit scale
simulate_predictions <- function(groups = GROUPS,
                                 prevalence = PREVALENCE,
                                 seed = SEED) {
  set.seed(seed)
  out <- vector("list", length(groups))

  for (i in seq_along(groups)) {
    g <- names(groups)[i]
    n <- groups[[i]]$n
    d <- groups[[i]]$d

    y <- rbinom(n, 1, prevalence)
    latent <- rnorm(n, mean = y * d, sd = 1)

    out[[i]] <- data.frame(
      id     = sprintf("%s_%05d", g, seq_len(n)),
      group  = g,
      label  = y,
      latent = latent,
      score  = plogis(latent),
      stringsAsFactors = FALSE
    )
  }

  df <- do.call(rbind, out)
  df[sample(nrow(df)), ]
}


#' The table of planted truths, for comparison against estimates
truth_table <- function(groups = GROUPS) {
  data.frame(
    group      = names(groups),
    n          = vapply(groups, function(g) g$n, numeric(1)),
    separation = vapply(groups, function(g) g$d, numeric(1)),
    true_auroc = vapply(groups, function(g) true_auroc(g$d), numeric(1)),
    row.names  = NULL
  )
}
