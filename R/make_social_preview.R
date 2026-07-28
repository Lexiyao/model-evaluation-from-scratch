# ---------------------------------------------------------------------------
# make_social_preview.R — the repo's social-preview card (1280x640)
#
# Redraws the Chapter 5 figure — subgroup AUROC with bootstrap intervals and
# the planted truth — sized for GitHub's social preview / OpenGraph card, so
# the link renders as an image on LinkedIn, Twitter, Slack, etc.
#
#     Rscript R/make_social_preview.R
#
# Writes assets/social-preview.png.
# ---------------------------------------------------------------------------

source("R/simulate.R")
source("R/metrics.R")
source("R/theme_eval.R")

df  <- simulate_predictions()
rep <- stratified_report(df, n_boot = 2000L)
tt  <- truth_table()

d <- rep[rep$group != "__overall__", ]
d$true_auroc <- tt$true_auroc[match(d$group, tt$group)]
pooled <- rep$auroc[rep$group == "__overall__"]

p <- ggplot(d, aes(y = factor(group, levels = c("V-VI", "III-IV", "I-II")))) +
  geom_vline(xintercept = pooled, linetype = "dashed", colour = EVAL_GREY) +
  geom_errorbarh(aes(xmin = auroc_lo, xmax = auroc_hi), height = 0.18,
                 colour = EVAL_INK, linewidth = 0.9) +
  geom_point(aes(x = auroc, colour = underpowered), size = 6) +
  geom_point(aes(x = true_auroc), shape = 4, size = 6, stroke = 1.6,
             colour = EVAL_WARN) +
  scale_colour_manual(values = c("FALSE" = EVAL_ACCENT, "TRUE" = EVAL_WARN),
                      guide = "none") +
  annotate("text", x = pooled, y = 3.55, label = "pooled AUROC 0.87",
           colour = EVAL_GREY, size = 4.2, hjust = 0.5, vjust = 0) +
  labs(
    title    = "Model Evaluation from Scratch",
    subtitle = "The estimate is not the finding — the interval is. Crosses mark the known truth.",
    x = "Subgroup AUROC (95% bootstrap CI)", y = NULL
  ) +
  coord_cartesian(xlim = c(0.5, 1.0), clip = "off") +
  theme_eval(base_size = 20) +
  theme(
    plot.title    = element_text(size = 34, face = "bold", colour = EVAL_INK),
    plot.subtitle = element_text(size = 17, colour = EVAL_GREY,
                                 margin = margin(b = 18)),
    axis.text.y   = element_text(size = 22, face = "bold", colour = EVAL_INK),
    plot.margin   = margin(34, 40, 30, 30)
  )

if (!dir.exists("assets")) dir.create("assets")
ggsave("assets/social-preview.png", p, width = 12.8, height = 6.4,
       dpi = 100, bg = "white")

cat("Wrote assets/social-preview.png (1280x640)\n")
