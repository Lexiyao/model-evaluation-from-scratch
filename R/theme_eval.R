# ---------------------------------------------------------------------------
# theme_eval.R — a single, quiet ggplot2 theme and a small palette
#
# The only job of this file is to make every figure in the book look like it
# came from the same place. Nothing here changes a number; it changes ink.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

# A four-colour palette. INK for foreground marks, GREY for reference lines
# and de-emphasised elements, ACCENT for the thing you are meant to look at,
# WARN for the thing that should worry you (undersized strata, the truth).
EVAL_INK    <- "#1d2433"
EVAL_GREY   <- "#9aa3b2"
EVAL_ACCENT <- "#2f6f9f"
EVAL_WARN   <- "#c8553d"

# Colours for the three strata, ordered so that the worst-served group reads
# as the warmest. The gradient is the argument of the book in three swatches.
group_cols <- c(
  "I-II"   = EVAL_ACCENT,
  "III-IV" = "#d9a15a",
  "V-VI"   = EVAL_WARN
)


#' A minimal theme with room to breathe
#'
#' @param base_size Base font size in points
theme_eval <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold", size = base_size * 1.15,
                                   colour = EVAL_INK,
                                   margin = margin(b = 2)),
      plot.subtitle = element_text(colour = EVAL_GREY, size = base_size * 0.9,
                                   margin = margin(b = 10)),
      plot.caption  = element_text(colour = EVAL_GREY, size = base_size * 0.75,
                                   hjust = 0),
      axis.title    = element_text(colour = EVAL_INK, size = base_size * 0.9),
      axis.text     = element_text(colour = EVAL_INK),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#eceef2", linewidth = 0.4),
      plot.margin   = margin(12, 14, 10, 10),
      legend.position = "bottom",
      legend.title  = element_text(colour = EVAL_INK, size = base_size * 0.85),
      legend.text   = element_text(colour = EVAL_INK, size = base_size * 0.8)
    )
}
