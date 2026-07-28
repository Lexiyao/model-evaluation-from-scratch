# ---------------------------------------------------------------------------
# make_results.R — reproduce every number quoted in the README
#
# Run from the project root:
#
#     Rscript R/make_results.R
#
# It is also the Quarto pre-render step, so a fresh clone renders the same
# figures a reader would get by running the line above. It writes the one
# generated artefact, data/predictions.csv, which is deliberately git-ignored:
# it is output, not source, and anyone can recreate it from the seed.
# ---------------------------------------------------------------------------

source("R/simulate.R")
source("R/metrics.R")

df <- simulate_predictions()

if (!dir.exists("data")) dir.create("data")
write.csv(df, "data/predictions.csv", row.names = FALSE)

tt  <- truth_table()
rep <- stratified_report(df, n_boot = 2000L)

cat("\n=== 1. Discrimination: the subgroup you cannot see is the moderate one ===\n")
show <- rep[, c("group", "n", "events", "auroc", "auroc_lo", "auroc_hi", "ci_width")]
show$true_auroc <- c(NA, tt$true_auroc[match(rep$group[-1], tt$group)])
print(show[, c("group", "n", "events", "true_auroc",
               "auroc", "auroc_lo", "auroc_hi", "ci_width")],
      digits = 3, row.names = FALSE)

base <- tt$true_auroc[tt$group == "I-II"]
power <- data.frame(
  group       = c("III-IV", "V-VI"),
  true_gap    = round(base - tt$true_auroc[match(c("III-IV", "V-VI"), tt$group)], 3),
  events_need = sapply(c("III-IV", "V-VI"),
                       function(g) n_events_for_gap(base, tt$true_auroc[tt$group == g])),
  events_have = rep$events[match(c("III-IV", "V-VI"), rep$group)]
)
cat("\nEvents needed vs held, to detect each subgroup gap:\n")
print(power, row.names = FALSE)

cat("\n=== 2. Calibration: ECE misses what the slope catches ===\n")
print(rep[, c("group", "cal_slope", "ece", "brier", "auroc")],
      digits = 3, row.names = FALSE)

cat("\n=== 3. Thresholds: one clinical rule, three different prices ===\n")
print(group_thresholds(df, target = 0.90), digits = 3, row.names = FALSE)

eo <- equalised_odds(df)
cat(sprintf("\nEqualised-odds TPR gap at a shared 0.5 threshold: %.3f (worst: %s)\n",
            eo$tpr_gap, eo$worst))

cat("\n=== An honest limitation, measured: bootstrap coverage in V-VI ===\n")
covered <- 0L; n_rep <- 200L
truth_vvi <- true_auroc(GROUPS[["V-VI"]]$d)
for (r in seq_len(n_rep)) {
  set.seed(10000 + r)
  y <- rbinom(160, 1, PREVALENCE)
  s <- plogis(rnorm(160, mean = y * GROUPS[["V-VI"]]$d, sd = 1))
  ci <- boot_ci(y, s, auroc, n_boot = 400L, seed = r)
  if (!is.na(ci[["lower"]]) && truth_vvi >= ci[["lower"]] &&
      truth_vvi <= ci[["upper"]]) covered <- covered + 1L
}
cat(sprintf("Nominal 95%% interval covered the truth %.1f%% of the time (target 95%%).\n",
            100 * covered / n_rep))

cat("\nWrote data/predictions.csv (", nrow(df), " rows).\n", sep = "")
