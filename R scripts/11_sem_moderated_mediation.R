# ============================================================================
# 11 - STRUCTURAL EQUATION MODEL: MODERATED MEDIATION
# ============================================================================
# Author: Heather Carle
# Purpose: Three-phase telescoping SEM from Figure 4
#          PRIMARY analysis on PLAT firms with CD data (~subset of dyads)
#          ROBUSTNESS check on full 903 firms (all dyads, PLAT=NONE as baseline)
#
# Model paths (Figure 4):
#   a = Platform Resources → Platform Accessibility
#   b = Platform Accessibility → International Performance (MKT_SHARE_CHANGE)
#   c = Platform Resources → International Performance (direct)
#   H1  = Direct effect (c path)
#   H2  = Mediation via Platform Accessibility (a × b)
#   H3a = Cultural Distance moderates a path
#   H3B = Cultural Distance moderates b path
#
# NOTE: Platform Accessibility IS the composite of Linguistic Variety and
#       Programming Language Variety (computed in script 06). These are NOT
#       separate moderators — they are the mediator itself.
#
# Three Phases:
#   Phase 1: Composite Platform Resources (single IV)
#   Phase 2: 5 Category Z-scores replace composite
#   Phase 3: Variable-level dominance analysis for significant categories
#
# Process:
#   Run A: PLAT firms only (primary)
#   Run B: Full 903 (with PLAT indicator including PLAT = NONE as control — robustness)
# ============================================================================

# --- Install packages (uncomment if running for the first time) ---
# install.packages(c("tidyverse", "lavaan", "interactions", "domir",
#                     "car", "lmtest", "moments", "flextable", "officer"))

library(tidyverse)
library(lavaan)
library(interactions)  # Johnson-Neyman, interact_plot
library(domir)         # Dominance analysis (Phase 3)
library(car)           # VIF
library(lmtest)        # Breusch-Pagan test (Section 9B)
library(moments)       # Skewness/kurtosis (Section 9A)

# ============================================================================
# SECTION 1: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")

mc <- readxl::read_excel(codebook_path)
cat("Full dataset:", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "firms\n")

# ============================================================================
# SECTION 2: PREPARE ANALYSIS DATASETS
# ============================================================================

# --- Run A: PLAT firms only (PRIMARY) ---
# Filter to PLAT firms, then drop dyads with missing cultural_distance
# (Hofstede scores unavailable for some home/host countries — see script 10)
df_plat_all <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

df_plat <- df_plat_all %>%
  filter(!is.na(cultural_distance)) %>%
  mutate(across(c(platform_resources, platform_accessibility,
                   MKT_SHARE_CHANGE, cultural_distance,
                   LINGUISTIC_VARIETY, programming_lang_variety,
                   Z_application, Z_development, Z_ai, Z_social, Z_governance,
                   IND_GROW,
                   host_gdp_per_capita, host_Internet_users,
                   home_gdp_per_capita),
                as.numeric))

n_cd_dropped <- nrow(df_plat_all) - nrow(df_plat)
n_plat_lost  <- n_distinct(df_plat_all$platform_ID) - n_distinct(df_plat$platform_ID)
cat("Run A (PLAT):", nrow(df_plat), "dyads,",
    n_distinct(df_plat$platform_ID), "platforms\n")
cat("  (Dropped", n_cd_dropped, "dyads,", n_plat_lost,
    "platforms due to missing cultural distance)\n")

# --- Run B: Full dataset (ROBUSTNESS) ---
# Also filter to dyads with CD available for consistent sample
df_full <- mc %>%
  filter(!is.na(cultural_distance)) %>%
  mutate(
    is_PLAT = as.numeric(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")),
    across(c(platform_resources, platform_accessibility,
             MKT_SHARE_CHANGE, cultural_distance,
             LINGUISTIC_VARIETY, programming_lang_variety,
             Z_application, Z_development, Z_ai, Z_social, Z_governance,
             IND_GROW,
             host_gdp_per_capita, host_Internet_users,
             home_gdp_per_capita),
           as.numeric)
  )

n_full_dropped <- nrow(mc) - nrow(df_full)
cat("Run B (Full):", nrow(df_full), "dyads,",
    n_distinct(df_full$platform_ID), "firms\n")
cat("  (Dropped", n_full_dropped, "dyads due to missing cultural distance)\n\n")

# ============================================================================
# SECTION 3: STANDARDIZE VARIABLES FOR SEM
# ============================================================================

standardize_for_sem <- function(df) {
  df %>%
    mutate(
      # Standardize key SEM variables
      PR_z  = scale(platform_resources)[,1],
      PA_z  = scale(platform_accessibility)[,1],   # composite of LV + PLV
      DV_z  = scale(MKT_SHARE_CHANGE)[,1],
      CD_z  = scale(cultural_distance)[,1],

      # Category Z-scores (already standardized in script 06, but re-scale
      # for within-sample consistency if needed)
      Za_z = scale(Z_application)[,1],
      Zd_z = scale(Z_development)[,1],
      Zai_z = scale(Z_ai)[,1],
      Zs_z = scale(Z_social)[,1],
      Zg_z = scale(Z_governance)[,1],

      # Controls (standardize for comparability)
      IND_GROW_z    = scale(IND_GROW)[,1],
      host_GDP_z    = scale(log(host_gdp_per_capita + 1))[,1],
      host_INET_z   = scale(host_Internet_users)[,1],
      home_GDP_z    = scale(log(home_gdp_per_capita + 1))[,1],

      # Interaction terms (pre-computed)
      PR_x_CD  = PR_z * CD_z,     # H3a: CD moderates a path
      PA_x_CD  = PA_z * CD_z      # H3B: CD moderates b path
    )
}

df_plat <- standardize_for_sem(df_plat)
df_full <- standardize_for_sem(df_full)

# --- Diagnostic: check for NaN/NA/zero-variance in SEM variables ---
sem_vars <- c("PR_z", "PA_z", "DV_z", "CD_z",
              "PR_x_CD", "PA_x_CD",
              "IND_GROW_z", "host_GDP_z", "host_INET_z", "home_GDP_z")

cat("\n--- SEM Variable Diagnostics (PLAT sample) ---\n")
for (v in sem_vars) {
  vals <- df_plat[[v]]
  n_na  <- sum(is.na(vals))
  n_nan <- sum(is.nan(vals))
  n_ok  <- sum(!is.na(vals))
  sd_v  <- if (n_ok > 1) sd(vals, na.rm = TRUE) else NA
  cat(sprintf("  %-12s  N=%d  NA=%d  NaN=%d  SD=%.4f\n",
              v, n_ok, n_na, n_nan, round(sd_v, 4)))
}

# Count complete cases across all SEM vars used in Phase 1
phase1_vars <- c("PR_z", "PA_z", "DV_z", "CD_z",
                 "PR_x_CD", "PA_x_CD",
                 "IND_GROW_z", "host_GDP_z", "host_INET_z", "home_GDP_z")
cc <- complete.cases(df_plat[, phase1_vars])
cat(sprintf("\nComplete cases for Phase 1: %d of %d (%.1f%%)\n",
            sum(cc), nrow(df_plat), 100 * mean(cc)))

# If too few complete cases, warn
if (sum(cc) < 50) {
  cat("⚠ WARNING: Very few complete cases. Check which variables have the most NAs.\n")
  na_counts <- sapply(df_plat[, phase1_vars], function(x) sum(is.na(x)))
  print(sort(na_counts, decreasing = TRUE))
}

# ============================================================================
# SECTION 4: PHASE 1 — COMPOSITE MODERATED MEDIATION
# ============================================================================

run_phase1 <- function(df, label = "PLAT", n_boot = 5000) {

  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat(sprintf("PHASE 1 [%s]: COMPOSITE PLATFORM RESOURCES MODEL (N=%d)\n",
              label, nrow(df)))
  cat(paste(rep("=", 70), collapse = ""), "\n")

  model <- '
    # Path a: Platform Resources → Platform Accessibility
    PA_z ~ a*PR_z +
           a_cd*PR_x_CD +             # H3a: CD moderates a path
           CD_z +                      # Main effect of CD
           home_GDP_z +                # Controls
           host_GDP_z +
           host_INET_z +
           IND_GROW_z

    # Path b + c: → International Performance
    DV_z ~ b*PA_z +
            c*PR_z +                   # H1: Direct effect
            b_cd*PA_x_CD +             # H3B: CD moderates b path
            CD_z +                     # Main effect of CD
            host_GDP_z +
            host_INET_z +
            IND_GROW_z

    # Defined parameters
    indirect := a * b                  # H2: Mediation
    total    := c + (a * b)
  '

  # First try to fit without bootstrap to check convergence
  fit_check <- sem(model, data = df, estimator = "ML")

  if (!lavInspect(fit_check, "converged")) {
    cat("\n⚠ MODEL DID NOT CONVERGE (even without bootstrap).\n")
    cat("  Possible causes:\n")
    cat("  1. Too many NAs — lavaan uses listwise deletion\n")
    cat("  2. Near-zero variance in a variable (check diagnostics above)\n")
    cat("  3. Perfect or near-perfect collinearity among predictors\n")
    cat("  4. Model may be under-identified with this data\n\n")

    # Show how many cases lavaan actually used
    cat(sprintf("  lavaan used N = %d observations (after listwise deletion)\n",
                lavInspect(fit_check, "nobs")))

    cat("\n  Attempting simplified model (dropping interaction terms)...\n")

    model_simple <- '
      PA_z ~ a*PR_z + CD_z +
             home_GDP_z + host_GDP_z + host_INET_z + IND_GROW_z

      DV_z ~ b*PA_z + c*PR_z + CD_z +
             host_GDP_z + host_INET_z + IND_GROW_z

      indirect := a * b
      total    := c + (a * b)
    '

    fit_simple <- sem(model_simple, data = df, estimator = "ML")

    if (lavInspect(fit_simple, "converged")) {
      cat("  ✓ Simplified model (no interactions) converged.\n")
      cat("  → This means the interaction terms may be causing the problem.\n")
      cat("  → Check for multicollinearity in interaction terms (PR_x_CD, PA_x_CD).\n\n")
      cat("--- Simplified Model Summary ---\n")
      summary(fit_simple, standardized = TRUE, fit.measures = TRUE)
    } else {
      cat("  ✗ Simplified model also failed to converge.\n")
      cat("  → The issue is likely in the data (NAs or variance).\n")
    }

    return(list(fit = fit_check, params = NULL, converged = FALSE))
  }

  # Model converges — now run with bootstrap
  cat("\n  ✓ Model converges. Running with bootstrap (n=", n_boot, ")...\n")
  fit <- sem(model, data = df, se = "bootstrap", bootstrap = n_boot,
             estimator = "ML")

  cat("\n--- Model Summary ---\n")
  summary(fit, standardized = TRUE, fit.measures = TRUE)

  # Key parameters
  params <- parameterEstimates(fit, boot.ci.type = "perc",
                                standardized = TRUE)

  cat("\n--- KEY HYPOTHESIS TESTS ---\n")
  key_labels <- c("a", "b", "c", "indirect", "total",
                   "a_cd", "b_cd")
  hypothesis_names <- c(
    a = "Platform Res → EcoAccess (a path)",
    b = "EcoAccess → Performance (b path)",
    c = "H1: Direct effect (c path)",
    indirect = "H2: Indirect/Mediation (a×b)",
    total = "Total effect (c + a×b)",
    a_cd = "H3a: CD moderates a path",
    b_cd = "H3B: CD moderates b path"
  )

  key_params <- params %>%
    filter(label %in% key_labels) %>%
    mutate(
      hypothesis = hypothesis_names[label],
      sig = case_when(
        pvalue < .001 ~ "***",
        pvalue < .01  ~ "**",
        pvalue < .05  ~ "*",
        pvalue < .10  ~ "+",
        TRUE          ~ "ns"
      )
    ) %>%
    select(label, hypothesis, est, se, pvalue, ci.lower, ci.upper, std.all, sig)

  print(as.data.frame(key_params))

  # Fit indices
  cat("\n--- Model Fit ---\n")
  print(fitMeasures(fit, c("chisq", "df", "pvalue",
                            "cfi", "tli", "rmsea", "srmr")))

  return(list(fit = fit, params = key_params, converged = TRUE))
}

# Run Phase 1 on PLAT data (primary)
phase1_plat <- run_phase1(df_plat, "PLAT", n_boot = 5000)

# ============================================================================
# SECTION 5: PHASE 2 — FIVE CATEGORY DECOMPOSITION
# ============================================================================

run_phase2 <- function(df, label = "PLAT", n_boot = 5000) {

  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat(sprintf("PHASE 2 [%s]: FIVE BR CATEGORIES (N=%d)\n",
              label, nrow(df)))
  cat(paste(rep("=", 70), collapse = ""), "\n")

  model <- '
    # a paths: Each BR category → Platform Accessibility
    PA_z ~ a_app*Za_z +     # H1A
           a_dev*Zd_z +     # H1B
           a_ai*Zai_z +     # H1C
           a_soc*Zs_z +     # H1D
           a_gov*Zg_z +     # H1E
           CD_z +
           home_GDP_z + host_GDP_z + host_INET_z +
           IND_GROW_z

    # b + c paths: → International Performance
    DV_z ~ b*PA_z +
            c_app*Za_z +
            c_dev*Zd_z +
            c_ai*Zai_z +
            c_soc*Zs_z +
            c_gov*Zg_z +
            CD_z +
            host_GDP_z + host_INET_z +
            IND_GROW_z

    # Indirect effects per category
    ind_app := a_app * b
    ind_dev := a_dev * b
    ind_ai  := a_ai * b
    ind_soc := a_soc * b
    ind_gov := a_gov * b
  '

  # First check convergence without bootstrap
  fit_check <- sem(model, data = df, estimator = "ML")

  if (!lavInspect(fit_check, "converged")) {
    cat("\n⚠ PHASE 2 MODEL DID NOT CONVERGE.\n")
    cat(sprintf("  lavaan used N = %d observations (after listwise deletion)\n",
                lavInspect(fit_check, "nobs")))
    cat("  Possible causes: NAs, near-zero variance, or collinearity.\n")

    # VIF check still useful
    cat("\n--- VIF: Category Multicollinearity ---\n")
    vif_model <- lm(PA_z ~ Za_z + Zd_z + Zai_z + Zs_z + Zg_z, data = df)
    print(vif(vif_model))

    return(list(fit = fit_check, params = NULL, converged = FALSE))
  }

  # Model converges — run with bootstrap
  cat("\n  ✓ Model converges. Running with bootstrap (n=", n_boot, ")...\n")
  fit <- sem(model, data = df, se = "bootstrap", bootstrap = n_boot,
             estimator = "ML")

  cat("\n--- Model Summary ---\n")
  summary(fit, standardized = TRUE, fit.measures = TRUE)

  # Fit indices (same format as Phase 1)
  cat("\n--- Model Fit ---\n")
  print(fitMeasures(fit, c("chisq", "df", "pvalue",
                            "cfi", "tli", "rmsea", "srmr")))

  params <- parameterEstimates(fit, boot.ci.type = "perc",
                                standardized = TRUE)

  cat("\n--- Category Effects ---\n")
  cat_labels <- c("a_app", "a_dev", "a_ai", "a_soc", "a_gov",
                   "c_app", "c_dev", "c_ai", "c_soc", "c_gov",
                   "ind_app", "ind_dev", "ind_ai", "ind_soc", "ind_gov", "b")

  cat_results <- params %>%
    filter(label %in% cat_labels) %>%
    select(label, est, se, pvalue, ci.lower, ci.upper, std.all) %>%
    mutate(
      sig = case_when(
        pvalue < .001 ~ "***",
        pvalue < .01  ~ "**",
        pvalue < .05  ~ "*",
        pvalue < .10  ~ "+",
        TRUE          ~ "ns"
      )
    ) %>%
    arrange(label) %>%
    as.data.frame()
  print(cat_results)

  # VIF check
  cat("\n--- VIF: Category Multicollinearity ---\n")
  vif_model <- lm(PA_z ~ Za_z + Zd_z + Zai_z + Zs_z + Zg_z, data = df)
  print(vif(vif_model))

  return(list(fit = fit, params = params, converged = TRUE))
}

# Run Phase 2 on PLAT data
phase2_plat <- run_phase2(df_plat, "PLAT", n_boot = 5000)

# ============================================================================
# SECTION 6: PHASE 3 — VARIABLE-LEVEL DOMINANCE ANALYSIS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PHASE 3: VARIABLE-LEVEL DOMINANCE ANALYSIS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Run dominance analysis ONLY for categories that are significant in Phase 2
# (Check Phase 2 results before running — adjust categories as needed)

# Social category decomposition (largest category)
cat("--- Social Category Dominance ---\n")
social_dom <- domir(
  PA_z ~ COM_forum + COM_blog + COM_help_support + COM_live_chat +
    COM_Slack + COM_Discord + COM_stackoverflow + COM_training +
    COM_FAQ + COM_social_media + GIT + MON +
    SPAN_internal + SPAN_communities + SPAN_external,
  \(fml, data) {
    m <- lm(fml, data = data)
    summary(m)$r.squared
  },
  data = df_plat %>% mutate(across(c(COM_forum:COM_social_media,
                                      GIT, MON,
                                      SPAN_internal:SPAN_external),
                                    as.numeric))
)
print(social_dom)

# Development category
cat("\n--- Development Category Dominance ---\n")
# Note: SDK_prog_lang excluded — it is a count of supported programming languages,
# which overlaps with PLV (programming language variety), a component of the EA
# composite DV. Including it would inflate dominance due to construct proximity.
dev_dom <- domir(
  PA_z ~ DEVP + DOCS + SDK + BUG + STAN,
  \(fml, data) {
    m <- lm(fml, data = data)
    summary(m)$r.squared
  },
  data = df_plat %>% mutate(across(c(DEVP, DOCS, SDK, BUG, STAN),
                                    as.numeric))
)
print(dev_dom)

# AI category
cat("\n--- AI Category Dominance ---\n")
# Note: AI_MKT has zero/near-zero variance — exclude from dominance analysis
# Use explicit column names to avoid range-based coercion issues
ai_vars_check <- df_plat %>%
  select(AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA, AI_MKT) %>%
  mutate(across(everything(), as.numeric))
ai_zero_var <- names(which(sapply(ai_vars_check, function(x) var(x, na.rm = TRUE)) < 0.001))
if (length(ai_zero_var) > 0) {
  cat("  Excluding zero-variance variables:", paste(ai_zero_var, collapse = ", "), "\n")
}
ai_dom <- domir(
  PA_z ~ AI_MODEL + AI_AGENT + AI_ASSIST + AI_DATA,
  \(fml, data) {
    m <- lm(fml, data = data)
    summary(m)$r.squared
  },
  data = df_plat %>% mutate(across(c(AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA),
                                    as.numeric))
)
print(ai_dom)

# Governance category
cat("\n--- Governance Category Dominance ---\n")
gov_dom <- domir(
  PA_z ~ ROLE + DATA + STORE + CERT,
  \(fml, data) {
    m <- lm(fml, data = data)
    summary(m)$r.squared
  },
  data = df_plat %>% mutate(across(c(ROLE, DATA, STORE, CERT),
                                    as.numeric))
)
print(gov_dom)

# --- Phase 3: Dominance Analysis Charts ---
cat("\n--- Generating Dominance Analysis Charts ---\n")
tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

# Helper function to create dominance bar chart
plot_dominance <- function(dom_obj, category_name, var_labels = NULL) {
  gd <- dom_obj$General_Dominance
  dom_df <- data.frame(
    Variable = names(gd),
    General_Dominance = as.numeric(gd),
    stringsAsFactors = FALSE
  )
  # Apply friendly labels if provided
  if (!is.null(var_labels)) {
    dom_df$Variable <- ifelse(dom_df$Variable %in% names(var_labels),
                               var_labels[dom_df$Variable],
                               dom_df$Variable)
  }
  dom_df$Pct <- dom_df$General_Dominance / sum(dom_df$General_Dominance) * 100
  dom_df <- dom_df[order(dom_df$General_Dominance, decreasing = TRUE), ]
  dom_df$Variable <- factor(dom_df$Variable, levels = rev(dom_df$Variable))

  ggplot(dom_df, aes(x = Variable, y = General_Dominance)) +
    geom_col(fill = "#1f77b4", width = 0.7) +
    geom_text(aes(label = sprintf("%.3f (%.1f%%)", General_Dominance, Pct)),
              hjust = -0.05, size = 3, family = "Times New Roman") +
    coord_flip() +
    labs(title = sprintf("General Dominance: %s Category", category_name),
         subtitle = sprintf("Overall R\u00B2 = %.3f", sum(dom_df$General_Dominance)),
         x = NULL, y = "General Dominance (contribution to R\u00B2)",
         caption = paste0(
           "Note. General dominance = average marginal R\u00B2 contribution across all subset models. ",
           "Percentages show each variable\u2019s share of total explained variance. ",
           "DV: Platform Accessibility (Z-standardized)."
         )) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
    theme_classic(base_family = "Times New Roman", base_size = 11) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.caption = element_text(hjust = 0, size = 7.5, color = "grey40",
                                   margin = margin(t = 10)),
      plot.caption.position = "plot"
    )
}

# Social category chart
p_social <- plot_dominance(social_dom, "Social")
ggsave(file.path(tables_path, "11_Dominance_Social.png"),
       p_social, width = 10, height = 7, dpi = 300, bg = "white")
cat("  \u2713 Social dominance chart saved\n")

# Development category chart
p_dev <- plot_dominance(dev_dom, "Development")
ggsave(file.path(tables_path, "11_Dominance_Development.png"),
       p_dev, width = 9, height = 5, dpi = 300, bg = "white")
cat("  \u2713 Development dominance chart saved\n")

# AI category chart
p_ai <- plot_dominance(ai_dom, "AI")
ggsave(file.path(tables_path, "11_Dominance_AI.png"),
       p_ai, width = 9, height = 5, dpi = 300, bg = "white")
cat("  \u2713 AI dominance chart saved\n")

# Governance category chart
p_gov <- plot_dominance(gov_dom, "Governance")
ggsave(file.path(tables_path, "11_Dominance_Governance.png"),
       p_gov, width = 9, height = 5, dpi = 300, bg = "white")
cat("  \u2713 Governance dominance chart saved\n")

# ============================================================================
# SECTION 7: INTERACTION PLOTS (Significant Moderations)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("INTERACTION PLOTS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# H3a: Cultural distance moderates PR → EA
plot_h3a <- lm(PA_z ~ PR_z * CD_z +
                 home_GDP_z + host_GDP_z + host_INET_z +
                 IND_GROW_z,
               data = df_plat)

# Johnson-Neyman: At what CD does the effect become significant?
jn_h3a <- interactions::johnson_neyman(
  plot_h3a, pred = PR_z, modx = CD_z,
  title = NULL
)

# Simple slopes
interactions::interact_plot(
  plot_h3a, pred = PR_z, modx = CD_z,
  modx.values = "plus-minus",
  plot.points = TRUE, point.alpha = 0.1,
  x.label = "Platform Resources (Z)",
  y.label = "Platform Accessibility (Z)",
  main.title = NULL
)

# ============================================================================
# SECTION 8: ROBUSTNESS — FULL 903 FIRMS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("ROBUSTNESS: FULL 903 FIRMS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Phase 1 on full dataset (with is_PLAT as control)
phase1_full_model <- '
  PA_z ~ a*PR_z +
         a_cd*PR_x_CD +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z +
         IND_GROW_z

  DV_z ~ b*PA_z +
          c*PR_z +
          b_cd*PA_x_CD +
          CD_z +
          host_GDP_z + host_INET_z +
          IND_GROW_z

  indirect := a * b
  total    := c + (a * b)
'

cat("Fitting Phase 1 on full dataset (N=", nrow(df_full), ")...\n")

# Check convergence first
phase1_full_check <- sem(phase1_full_model, data = df_full, estimator = "ML")

if (!lavInspect(phase1_full_check, "converged")) {
  cat("\n⚠ Full dataset Phase 1 did not converge.\n")
  cat(sprintf("  lavaan used N = %d observations\n",
              lavInspect(phase1_full_check, "nobs")))
  phase1_full_fit <- phase1_full_check
} else {
  cat("  ✓ Converges. Running bootstrap...\n")
  phase1_full_fit <- sem(phase1_full_model, data = df_full,
                          se = "bootstrap", bootstrap = 5000,
                          estimator = "ML")

  cat("\n--- Full Dataset Phase 1 Summary ---\n")
  summary(phase1_full_fit, standardized = TRUE, fit.measures = TRUE)
}

# Compare key parameters (only if both models converged)
if (isTRUE(phase1_plat$converged) && lavInspect(phase1_full_fit, "converged")) {
  cat("\n--- ROBUSTNESS COMPARISON: PLAT vs FULL ---\n")
  full_params <- parameterEstimates(phase1_full_fit, boot.ci.type = "perc",
                                     standardized = TRUE) %>%
    filter(label %in% c("a", "b", "c", "indirect", "total",
                          "a_cd", "b_cd"))

  plat_params <- phase1_plat$params

  comparison <- plat_params %>%
    select(label, hypothesis,
           est_plat = est, p_plat = pvalue, sig_plat = sig) %>%
    left_join(
      full_params %>%
        select(label, est_full = est, p_full = pvalue) %>%
        mutate(sig_full = case_when(
          p_full < .001 ~ "***",
          p_full < .01  ~ "**",
          p_full < .05  ~ "*",
          p_full < .10  ~ "+",
          TRUE          ~ "ns"
        )),
      by = "label"
    )

  print(as.data.frame(comparison))
} else {
  cat("\n⚠ Skipping PLAT vs Full comparison (one or both models did not converge).\n")
}

# ============================================================================
# NOTE: Section 8B (Separate Mediators LV & PLV) was REMOVED.
# Platform Accessibility IS the composite of LV + PLV. Testing them as
# separate mediators would double-count the mediator components.
# ============================================================================

# ============================================================================
# SECTION 9: VALIDITY DIAGNOSTICS
# ============================================================================
# Tests for normality, heteroskedasticity, multicollinearity, and outliers
# (Bascle, 2008; Lee et al., 2008)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("VALIDITY DIAGNOSTICS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- 9A: NORMALITY ---
cat("--- 9A: Normality (Shapiro-Wilk on key SEM variables) ---\n")
cat("Note: For N > 5000, Shapiro-Wilk uses random subsample of 5000.\n\n")

norm_vars <- c("PR_z", "PA_z", "DV_z", "CD_z")
for (v in norm_vars) {
  x <- df_plat[[v]]
  x <- x[!is.na(x)]
  if (length(x) > 5000) x <- sample(x, 5000)
  sw <- shapiro.test(x)
  cat(sprintf("  %-10s W=%.4f, p=%.4f  Skew=%.3f  Kurt=%.3f\n",
              v, sw$statistic, sw$p.value,
              moments::skewness(x), moments::kurtosis(x) - 3))
}

cat("\n  Note: Bootstrap SEs in lavaan are robust to non-normality.\n")
cat("  Skewness > |2| or kurtosis > |7| would be concerning (Curran et al., 1996).\n")

# QQ plots for visual normality assessment
cat("\n  Generating QQ plots...\n")
library(ggplot2)

qq_plots <- lapply(norm_vars, function(v) {
  x <- df_plat[[v]]
  x <- x[!is.na(x)]
  df_qq <- data.frame(value = x)
  ggplot(df_qq, aes(sample = value)) +
    stat_qq(alpha = 0.3, size = 0.8, color = "steelblue") +
    stat_qq_line(color = "red", linewidth = 0.7) +
    labs(title = v, x = "Theoretical Quantiles", y = "Sample Quantiles") +
    theme_classic(base_family = "Times New Roman") +
    theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 12),
          axis.title = element_text(size = 9))
})

qq_panel <- gridExtra::grid.arrange(
  grobs = qq_plots, ncol = 2,
  top = grid::textGrob("QQ Plots \u2014 SEM Variables (PLAT Sample)",
                        gp = grid::gpar(fontsize = 14, fontface = "bold",
                                         fontfamily = "Times New Roman")),
  bottom = grid::textGrob(
    paste0("Note. Points represent observed quantiles vs. theoretical normal quantiles. ",
           "Red line = expected distribution under normality. ",
           "Departures from the line indicate non-normality. N = ",
           nrow(df_plat), " PLAT firm-host dyads."),
    gp = grid::gpar(fontsize = 8, col = "grey40", fontfamily = "Times New Roman"),
    x = 0.02, hjust = 0
  )
)

tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

ggsave(file.path(tables_path, "11_QQ_Plots_Normality.png"),
       qq_panel, width = 8, height = 7, dpi = 300, bg = "white")
cat("  ✓ QQ plots saved: 11_QQ_Plots_Normality.png\n")

# --- 9B: HETEROSKEDASTICITY (White's Test) ---
cat("\n--- 9B: Heteroskedasticity (White's Test via lmtest/skedastic) ---\n")

# White's test on the OLS analog of the a-path and b-path
ols_a <- lm(PA_z ~ PR_z + CD_z +
               home_GDP_z + host_GDP_z + host_INET_z +
               IND_GROW_z, data = df_plat)

ols_b <- lm(DV_z ~ PA_z + PR_z + CD_z +
               host_GDP_z + host_INET_z +
               IND_GROW_z, data = df_plat)

# Breusch-Pagan test (proxy for White's — available in lmtest)
if (requireNamespace("lmtest", quietly = TRUE)) {
  bp_a <- lmtest::bptest(ols_a)
  bp_b <- lmtest::bptest(ols_b)
  cat("\n  Breusch-Pagan (a-path):", sprintf("χ²=%.2f, df=%d, p=%.4f\n",
      bp_a$statistic, bp_a$parameter, bp_a$p.value))
  cat("  Breusch-Pagan (b-path):", sprintf("χ²=%.2f, df=%d, p=%.4f\n",
      bp_b$statistic, bp_b$parameter, bp_b$p.value))
  if (bp_a$p.value < 0.05 | bp_b$p.value < 0.05) {
    cat("\n  → Heteroskedasticity detected. Bootstrap SEs are robust to this.\n")
    cat("    Consider HC-robust SEs if reporting OLS as supplemental.\n")
  } else {
    cat("\n  → No significant heteroskedasticity detected.\n")
  }
} else {
  cat("  Install lmtest package: install.packages('lmtest')\n")
}

# --- 9C: MULTICOLLINEARITY (VIF) ---
cat("\n--- 9C: Multicollinearity (VIF from OLS analog) ---\n")
cat("\n  a-path VIF:\n")
print(car::vif(ols_a))

cat("\n  b-path VIF:\n")
print(car::vif(ols_b))

cat("\n  Threshold: VIF > 10 is problematic; VIF > 5 warrants caution.\n")

# --- 9D: OUTLIER DETECTION ---
cat("\n--- 9D: Outlier Detection ---\n")

# Cook's distance on OLS b-path
cooks <- cooks.distance(ols_b)
n_influential <- sum(cooks > 4 / nrow(df_plat), na.rm = TRUE)
cat(sprintf("\n  Observations with Cook's D > 4/n: %d of %d (%.1f%%)\n",
            n_influential, nrow(df_plat),
            100 * n_influential / nrow(df_plat)))

# Flag the top 10
top_outliers <- df_plat %>%
  mutate(.cooksd = cooks) %>%
  filter(!is.na(.cooksd)) %>%
  arrange(desc(.cooksd)) %>%
  head(10) %>%
  select(platform_ID, platform_name, IND, host_country_name,
         DV_z, PR_z, PA_z, .cooksd)

cat("\n  Top 10 influential observations:\n")
print(top_outliers, n = 10, width = 120)

# Mahalanobis distance for multivariate outliers
mah_data <- df_plat %>%
  select(PR_z, PA_z, DV_z, CD_z, IND_GROW_z) %>%
  filter(complete.cases(.))

mah_dist <- mahalanobis(mah_data, colMeans(mah_data), cov(mah_data))
mah_cutoff <- qchisq(0.999, df = ncol(mah_data))
n_mah_outliers <- sum(mah_dist > mah_cutoff)

cat(sprintf("\n  Multivariate outliers (Mahalanobis, p < .001): %d of %d\n",
            n_mah_outliers, nrow(mah_data)))
cat(sprintf("  Chi-sq cutoff (df=%d): %.2f\n", ncol(mah_data), mah_cutoff))

# ============================================================================
# SECTION 10: HECKMAN TWO-STEP SELECTION CORRECTION
# ============================================================================
# Following Bascle (2008), Hamilton & Nickerson (2003), Certo et al. (2016).
#
# The selection bias concern: firms that choose to be "international"
# (have market share in foreign markets) may systematically differ from
# those that do not. If unobserved factors drive both internationalization
# and performance, OLS estimates are biased.
#
# Step 1 (Probit): Predict selection into international markets
#   DV = is_international (1 if firm has host-country market share, 0 if not)
#   IVs: Instrumental variables that predict internationalization but not
#         performance directly (exclusion restriction)
#
# Step 2 (OLS): Include inverse Mills ratio (IMR) from Step 1 as control
#   If IMR coefficient ≠ 0, selection bias is present
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("HECKMAN TWO-STEP SELECTION CORRECTION\n")
cat("(Bascle, 2008; Hamilton & Nickerson, 2003; Certo et al., 2016)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- Step 1: Selection Equation (Probit) ---
# Create selection variable:
#   is_international = 1 if the firm has non-zero market share in ANY host country
#   is_international = 0 if no international presence observed
#
# NOTE: In our sample, most firms ARE international (by design — they appear
# in dyads with host countries). The selection issue is whether firms with
# developer portals (PLAT) are systematically different from those without.
# So we use: is_PLAT as the selection variable on the FULL 903 sample.

cat("--- Step 1: Probit Selection Equation ---\n\n")
cat("Selection variable: is_PLAT (1 if PUBLIC/REG/RESTRICTED, 0 if NONE)\n")
cat("Instruments: Variables that predict having a developer portal\n")
cat("             but don't directly affect market share change.\n\n")

# The full sample for Heckman needs both selected (PLAT) and non-selected (NONE)
df_heckman <- df_full
  # Instruments (exclusion restriction):
  #   home_GDP_z — HQ country development predicts tech investment
  #   IND_GROW_z — industry growth may predict portal adoption
  # NOTE: AGE was dropped from the model (93.75% default values, unreliable)

# Probit: Pr(is_PLAT = 1) = Φ(home_GDP, IND_GROW)
probit_formula <- is_PLAT ~ home_GDP_z + IND_GROW_z

probit_fit <- glm(probit_formula, data = df_heckman,
                   family = binomial(link = "probit"))

cat("Probit model summary:\n")
summary(probit_fit)

# Compute Inverse Mills Ratio (IMR)
# IMR = φ(Xβ) / Φ(Xβ) for selected observations
# IMR = -φ(Xβ) / (1 - Φ(Xβ)) for non-selected observations
linear_pred <- predict(probit_fit, type = "link")
df_heckman$IMR <- ifelse(
  df_heckman$is_PLAT == 1,
  dnorm(linear_pred) / pnorm(linear_pred),          # Selected (PLAT)
  -dnorm(linear_pred) / (1 - pnorm(linear_pred))    # Non-selected (NONE)
)

cat("\nInverse Mills Ratio computed.\n")
cat(sprintf("  PLAT firms: mean IMR = %.3f (SD = %.3f)\n",
            mean(df_heckman$IMR[df_heckman$is_PLAT == 1], na.rm = TRUE),
            sd(df_heckman$IMR[df_heckman$is_PLAT == 1], na.rm = TRUE)))

# --- Step 2: Include IMR in Outcome Equation ---
cat("\n--- Step 2: OLS with Inverse Mills Ratio ---\n\n")

# Re-standardize IMR for the PLAT subsample
df_plat_heckman <- df_heckman %>%
  filter(is_PLAT == 1) %>%
  mutate(IMR_z = scale(IMR)[,1])

# OLS outcome equation WITH IMR
ols_with_imr <- lm(DV_z ~ PR_z + PA_z + CD_z +
                      host_GDP_z + host_INET_z +
                      IND_GROW_z +
                      IMR_z,                           # ← Heckman correction
                    data = df_plat_heckman)

cat("OLS with Inverse Mills Ratio (Heckman correction):\n\n")
summary(ols_with_imr)

# OLS WITHOUT IMR (for comparison)
ols_without_imr <- lm(DV_z ~ PR_z + PA_z + CD_z +
                         host_GDP_z + host_INET_z +
                         IND_GROW_z,
                       data = df_plat_heckman)

# Compare key coefficients
cat("\n--- Heckman Comparison: With vs Without IMR ---\n\n")
cat(sprintf("  %-15s  Without IMR   With IMR    Δ\n", "Variable"))
cat(strrep("-", 55), "\n")

key_vars_heck <- c("PR_z", "PA_z", "CD_z")
for (v in key_vars_heck) {
  coef_without <- coef(ols_without_imr)[v]
  coef_with    <- coef(ols_with_imr)[v]
  delta <- coef_with - coef_without
  cat(sprintf("  %-15s  %8.4f      %8.4f    %+.4f\n",
              v, coef_without, coef_with, delta))
}

# IMR significance
imr_coef <- summary(ols_with_imr)$coefficients["IMR_z", ]
cat(sprintf("\n  IMR coefficient: β=%.4f (SE=%.4f), t=%.2f, p=%.4f\n",
            imr_coef[1], imr_coef[2], imr_coef[3], imr_coef[4]))

if (imr_coef[4] < 0.05) {
  cat("  → IMR is SIGNIFICANT (λ ≠ 0): Selection bias IS present.\n")
  cat("    The corrected estimates (with IMR) should be preferred.\n")
  cat("    Report both with and without IMR in results table.\n")
} else {
  cat("  → IMR is NOT significant (λ ≈ 0): No evidence of selection bias.\n")
  cat("    The uncorrected OLS estimates are consistent.\n")
  cat("    Report this as evidence that sample selection is not biasing results.\n")
}

# Also run as SEM with IMR as control (for bootstrapped CIs)
cat("\n--- Heckman-Corrected SEM (Phase 1 with IMR) ---\n")

heckman_sem_model <- '
  PA_z ~ a*PR_z +
         a_cd*PR_x_CD +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z +
         IND_GROW_z +
         IMR_z

  DV_z ~ b*PA_z +
          c*PR_z +
          b_cd*PA_x_CD +
          CD_z +
          host_GDP_z + host_INET_z +
          IND_GROW_z +
          imr_dv*IMR_z

  indirect := a * b
  total    := c + (a * b)
'

# Need to add IMR_z and interaction terms to the PLAT Heckman data
df_plat_heckman <- df_plat_heckman %>%
  mutate(
    PR_x_CD  = PR_z * CD_z,
    PA_x_CD  = PA_z * CD_z
  )

heckman_fit <- tryCatch({
  fit_tmp <- sem(heckman_sem_model, data = df_plat_heckman, estimator = "ML")
  if (!lavInspect(fit_tmp, "converged")) {
    cat("  Heckman SEM did not converge.\n")
    NULL
  } else {
    cat("  ✓ Converges. Running bootstrap...\n")
    sem(heckman_sem_model, data = df_plat_heckman,
        se = "bootstrap", bootstrap = 2000, estimator = "ML")
  }
}, error = function(e) {
    cat("  SEM with IMR failed:", e$message, "\n")
    cat("  This can happen if IMR has near-zero variance among PLAT firms.\n")
    NULL
  }
)

if (!is.null(heckman_fit)) {
  cat("\nHeckman-corrected SEM summary:\n")
  summary(heckman_fit, standardized = TRUE, fit.measures = TRUE)

  # Check IMR paths
  heckman_params <- parameterEstimates(heckman_fit, boot.ci.type = "perc",
                                        standardized = TRUE)
  cat("\n--- IMR Path Coefficients ---\n")
  imr_key <- heckman_params %>%
    filter(grepl("IMR|imr", label) | rhs == "IMR_z") %>%
    select(lhs, rhs, label, est, se, pvalue, std.all) %>%
    as.data.frame()
  print(imr_key)
}

# ============================================================================
# NOTE: Section 11B (Heckman Separate Mediators) was REMOVED.
# LV and PLV are components of PA, not separate mediators.
# ============================================================================

# ============================================================================
# SECTION 12: SAVE RESULTS (CSV)
# ============================================================================

output_path <- file.path(base_path, "dissertation analysis")
tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

# Save Phase 1 comparison table (CSV)
if (isTRUE(phase1_plat$converged) && exists("comparison")) {
  write.csv(comparison,
            file.path(output_path, "phase1_plat_vs_full_comparison.csv"),
            row.names = FALSE)
}

# ============================================================================
# SECTION 13: APA WORD TABLE EXPORTS
# ============================================================================

library(flextable)
library(officer)

sem_word_path <- file.path(tables_path, "11_SEM_Results_APA.docx")
doc <- read_docx()

# --- Helper: APA-formatted flextable ---
apa_table <- function(df, caption = "") {
  ft <- flextable(df) %>%
    theme_booktabs() %>%
    fontsize(size = 10, part = "all") %>%
    font(fontname = "Times New Roman", part = "all") %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "body") %>%
    autofit() %>%
    set_caption(caption = caption)
  return(ft)
}

# --- Table 1: Phase 1 Hypothesis Tests ---
if (isTRUE(phase1_plat$converged) && !is.null(phase1_plat$params)) {
  doc <- doc %>%
    body_add_par("Table 1: Phase 1 — Composite Platform Resources Model (PLAT Sample)",
                 style = "heading 2")

  t1 <- phase1_plat$params %>%
    mutate(
      est     = sprintf("%.3f", est),
      se      = sprintf("%.3f", se),
      pvalue  = ifelse(as.numeric(pvalue) < .001, "< .001", sprintf("%.3f", pvalue)),
      ci      = sprintf("[%.3f, %.3f]", ci.lower, ci.upper),
      std.all = sprintf("%.3f", std.all)
    ) %>%
    select(Label = label, Hypothesis = hypothesis,
           `B` = est, `SE` = se, `p` = pvalue,
           `95% CI` = ci, `β` = std.all, Sig = sig)

  doc <- doc %>%
    body_add_flextable(apa_table(t1, "Phase 1: Moderated Mediation — Composite Platform Resources")) %>%
    body_add_par(paste0(
      "Note. N = ", n_distinct(df_plat$platform_ID),
      " PLAT firms (", 230 - n_distinct(df_plat$platform_ID),
      " excluded due to missing Hofstede cultural distance data). ",
      "B = unstandardized coefficient; SE = bootstrap standard error (5,000 replications); ",
      "95% CI = percentile bootstrap confidence interval; \u03B2 = standardized coefficient. ",
      "Controls: home GDP, host GDP, host internet penetration, industry growth rate. ",
      "PR \u00D7 CD and PA \u00D7 CD are mean-centered interaction terms. ",
      "Indirect effect = a \u00D7 b."
    ), style = "Normal") %>%
    body_add_par("* p < .05. ** p < .01. *** p < .001. \u2020 p < .10.", style = "Normal") %>%
    body_add_par("")

  # Fit indices (with RMSEA 90% CI)
  fit_vals <- fitMeasures(phase1_plat$fit,
                           c("chisq", "df", "pvalue", "cfi", "tli",
                             "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr",
                             "aic", "bic"))
  fit_df <- data.frame(
    Measure = c("\u03C7\u00B2", "df", "p (\u03C7\u00B2)", "CFI", "TLI",
                "RMSEA", "RMSEA 90% CI Lower", "RMSEA 90% CI Upper", "SRMR",
                "AIC", "BIC"),
    Value   = sprintf("%.3f", fit_vals)
  )
  doc <- doc %>%
    body_add_par("Model Fit Indices", style = "heading 3") %>%
    body_add_flextable(apa_table(fit_df, "Phase 1 Model Fit")) %>%
    body_add_par(paste0(
      "Note. Acceptable fit thresholds: CFI \u2265 .95, TLI \u2265 .95, ",
      "RMSEA \u2264 .06, SRMR \u2264 .08 (Hu & Bentler, 1999). ",
      "RMSEA 90% CI = 90% confidence interval for RMSEA. ",
      "AIC = Akaike Information Criterion; BIC = Bayesian Information Criterion. ",
      "Lower AIC/BIC values indicate better model fit with parsimony adjustment; ",
      "compare across Phase 1 and Phase 2 models to assess improvement in fit."
    ), style = "Normal") %>%
    body_add_par("")
}

# --- Table 2: Phase 2 Category Effects ---
if (isTRUE(phase2_plat$converged) && !is.null(phase2_plat$params)) {
  doc <- doc %>%
    body_add_par("Table 2: Phase 2 — Five BR Category Model (PLAT Sample)",
                 style = "heading 2")

  cat_labels <- c("a_app", "a_dev", "a_ai", "a_soc", "a_gov",
                   "c_app", "c_dev", "c_ai", "c_soc", "c_gov",
                   "ind_app", "ind_dev", "ind_ai", "ind_soc", "ind_gov", "b")

  cat_names <- c(
    a_app = "Application → PA (a)", a_dev = "Development → PA (a)",
    a_ai = "AI → PA (a)", a_soc = "Social → PA (a)", a_gov = "Governance → PA (a)",
    c_app = "Application → Perf (c)", c_dev = "Development → Perf (c)",
    c_ai = "AI → Perf (c)", c_soc = "Social → Perf (c)", c_gov = "Governance → Perf (c)",
    ind_app = "Application (indirect)", ind_dev = "Development (indirect)",
    ind_ai = "AI (indirect)", ind_soc = "Social (indirect)",
    ind_gov = "Governance (indirect)", b = "PA → Performance (b)"
  )

  t2 <- phase2_plat$params %>%
    filter(label %in% cat_labels) %>%
    mutate(
      Path = cat_names[label],
      est     = sprintf("%.3f", est),
      se      = sprintf("%.3f", se),
      pvalue  = ifelse(pvalue < .001, "< .001", sprintf("%.3f", pvalue)),
      ci      = sprintf("[%.3f, %.3f]", ci.lower, ci.upper),
      std.all = sprintf("%.3f", std.all),
      sig = case_when(
        as.numeric(pvalue) < .001 | pvalue == "< .001" ~ "***",
        as.numeric(ifelse(pvalue == "< .001", 0, pvalue)) < .01  ~ "**",
        as.numeric(ifelse(pvalue == "< .001", 0, pvalue)) < .05  ~ "*",
        as.numeric(ifelse(pvalue == "< .001", 0, pvalue)) < .10  ~ "+",
        TRUE ~ "ns"
      )
    ) %>%
    select(Path, `B` = est, `SE` = se, `p` = pvalue,
           `95% CI` = ci, `β` = std.all, Sig = sig)

  doc <- doc %>%
    body_add_flextable(apa_table(t2, "Phase 2: Five BR Category Effects")) %>%
    body_add_par(paste0(
      "Note. N = ", n_distinct(df_plat$platform_ID),
      " PLAT firms. Five boundary resource (BR) categories entered as ",
      "Z-standardized composite scores: Application, Development, AI, Social, Governance. ",
      "B = unstandardized coefficient; SE = bootstrap standard error (5,000 replications); ",
      "95% CI = percentile bootstrap confidence interval; \u03B2 = standardized coefficient. ",
      "a-paths = category \u2192 Platform Accessibility; c-paths = category \u2192 International Performance (direct); ",
      "indirect = a \u00D7 b mediation effect. ",
      "Controls: home GDP, host GDP, host internet penetration, industry growth rate."
    ), style = "Normal") %>%
    body_add_par("* p < .05. ** p < .01. *** p < .001. \u2020 p < .10.", style = "Normal") %>%
    body_add_par("")

  # Phase 2 Fit Indices (with RMSEA 90% CI)
  fit_vals2 <- fitMeasures(phase2_plat$fit,
                            c("chisq", "df", "pvalue", "cfi", "tli",
                              "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr",
                              "aic", "bic"))
  fit_df2 <- data.frame(
    Measure = c("\u03C7\u00B2", "df", "p (\u03C7\u00B2)", "CFI", "TLI",
                "RMSEA", "RMSEA 90% CI Lower", "RMSEA 90% CI Upper", "SRMR",
                "AIC", "BIC"),
    Value   = sprintf("%.3f", fit_vals2)
  )
  doc <- doc %>%
    body_add_par("Model Fit Indices", style = "heading 3") %>%
    body_add_flextable(apa_table(fit_df2, "Phase 2 Model Fit")) %>%
    body_add_par(paste0(
      "Note. Acceptable fit thresholds: CFI \u2265 .95, TLI \u2265 .95, ",
      "RMSEA \u2264 .06, SRMR \u2264 .08 (Hu & Bentler, 1999). ",
      "RMSEA 90% CI = 90% confidence interval for RMSEA. ",
      "AIC = Akaike Information Criterion; BIC = Bayesian Information Criterion. ",
      "Lower AIC/BIC values indicate better model fit with parsimony adjustment; ",
      "compare with Phase 1 model to assess whether disaggregating BR categories improves fit."
    ), style = "Normal") %>%
    body_add_par("")
}

# --- Table 3: Robustness Comparison (PLAT vs Full) ---
if (exists("comparison") && !is.null(comparison)) {
  doc <- doc %>%
    body_add_par("Table 3: Robustness — PLAT vs Full Sample Comparison",
                 style = "heading 2")

  # Format p-values properly (show "< .001" instead of "0.000")
  fmt_p <- function(p) ifelse(p < .001, "< .001", sprintf("%.3f", p))

  t3 <- comparison %>%
    mutate(
      est_plat = sprintf("%.3f", est_plat),
      p_plat   = fmt_p(p_plat),
      est_full = sprintf("%.3f", est_full),
      p_full   = fmt_p(p_full)
    ) %>%
    select(label, hypothesis, est_plat, p_plat, sig_plat, est_full, p_full, sig_full) %>%
    rename(
      Path = label,
      Hypothesis = hypothesis,
      `B (PLAT)` = est_plat,
      `p (PLAT)` = p_plat,
      `Sig (PLAT)` = sig_plat,
      `B (Full)` = est_full,
      `p (Full)` = p_full,
      `Sig (Full)` = sig_full
    )

  doc <- doc %>%
    body_add_flextable(apa_table(t3, sprintf("Phase 1 Comparison: PLAT (N=%d) vs Full (N=%d)",
                                            nrow(df_plat), nrow(df_full)))) %>%
    body_add_par(paste0(
      "Note. Robustness check comparing Phase 1 moderated mediation results across two samples: ",
      "PLAT (N = ", nrow(df_plat), "; firms with \u2265 1 platform resource and non-missing cultural distance) ",
      "and Full (N = ", nrow(df_full), "; all firms in dataset). ",
      "Consistent sign, magnitude, and significance across samples supports robustness of findings. ",
      "B = unstandardized coefficient; SE = bootstrap standard error (5,000 replications); ",
      "\u03B2 = standardized coefficient."
    ), style = "Normal") %>%
    body_add_par("* p < .05. ** p < .01. *** p < .001. \u2020 p < .10.", style = "Normal") %>%
    body_add_par("")

  # Fit indices comparison: PLAT vs Full
  fit_measures_list <- c("chisq", "df", "pvalue", "cfi", "tli",
                          "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr",
                          "aic", "bic")
  fit_plat <- fitMeasures(phase1_plat$fit, fit_measures_list)
  fit_full <- fitMeasures(phase1_full_fit, fit_measures_list)

  fit_compare <- data.frame(
    Measure = c("\u03C7\u00B2", "df", "p (\u03C7\u00B2)", "CFI", "TLI",
                "RMSEA", "RMSEA 90% CI Lower", "RMSEA 90% CI Upper", "SRMR",
                "AIC", "BIC"),
    `PLAT` = sprintf("%.3f", fit_plat),
    `Full` = sprintf("%.3f", fit_full),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  doc <- doc %>%
    body_add_par("Model Fit Comparison", style = "heading 3") %>%
    body_add_flextable(apa_table(fit_compare,
      sprintf("Phase 1 Model Fit: PLAT (N=%d) vs Full (N=%d)",
              nrow(df_plat), nrow(df_full)))) %>%
    body_add_par(paste0(
      "Note. Acceptable fit thresholds: CFI \u2265 .95, TLI \u2265 .95, ",
      "RMSEA \u2264 .06, SRMR \u2264 .08 (Hu & Bentler, 1999). ",
      "RMSEA 90% CI = 90% confidence interval for RMSEA. ",
      "AIC/BIC: lower values indicate better fit with parsimony adjustment. ",
      "AIC/BIC are not directly comparable across samples of different sizes; ",
      "focus on relative fit indices (CFI, TLI, RMSEA, SRMR) for cross-sample comparison."
    ), style = "Normal") %>%
    body_add_par("")
}

# --- Table 4: Validity Diagnostics Summary ---
doc <- doc %>%
  body_add_par("Table 4: Validity Diagnostics", style = "heading 2")

# Normality
norm_results <- data.frame(
  Variable = character(), W = numeric(), p = numeric(),
  Skewness = numeric(), Kurtosis = numeric(),
  stringsAsFactors = FALSE
)
norm_vars <- c("PR_z", "PA_z", "DV_z", "CD_z")
for (v in norm_vars) {
  x <- df_plat[[v]]
  x <- x[!is.na(x)]
  if (length(x) > 5000) x <- sample(x, 5000)
  sw <- shapiro.test(x)
  norm_results <- rbind(norm_results, data.frame(
    Variable = v,
    W = round(sw$statistic, 4),
    p = round(sw$p.value, 4),
    Skewness = round(moments::skewness(x), 3),
    Kurtosis = round(moments::kurtosis(x) - 3, 3)
  ))
}

doc <- doc %>%
  body_add_par("Normality (Shapiro-Wilk)", style = "heading 3") %>%
  body_add_flextable(apa_table(norm_results, "Shapiro-Wilk Normality Tests")) %>%
  body_add_par(paste0(
    "Note. W = Shapiro-Wilk test statistic; p = significance of departure from normality. ",
    "Skewness and excess kurtosis are reported (kurtosis \u2212 3). ",
    "Acceptable thresholds: |skewness| < 2, |kurtosis| < 7 (West et al., 1995). ",
    "Significant Shapiro-Wilk tests are common in large samples (N > 200) and do not necessarily ",
    "indicate problematic non-normality when skewness and kurtosis are within acceptable ranges. ",
    "Bootstrap standard errors (5,000 replications) are used in SEM estimation to address non-normality."
  ), style = "Normal") %>%
  body_add_par("")

# --- Table 4b: VIF (Multicollinearity) ---
vif_a <- car::vif(ols_a)
vif_b <- car::vif(ols_b)

vif_df <- data.frame(
  Variable = union(names(vif_a), names(vif_b)),
  stringsAsFactors = FALSE
)
vif_df$`VIF (a-path)` <- ifelse(vif_df$Variable %in% names(vif_a),
                                 sprintf("%.2f", vif_a[vif_df$Variable]), "—")
vif_df$`VIF (b-path)` <- ifelse(vif_df$Variable %in% names(vif_b),
                                 sprintf("%.2f", vif_b[vif_df$Variable]), "—")

# Clean variable names for display
vif_df$Variable <- gsub("_z$", "", vif_df$Variable)

doc <- doc %>%
  body_add_par("Multicollinearity (VIF)", style = "heading 3") %>%
  body_add_flextable(apa_table(vif_df, "Variance Inflation Factors")) %>%
  body_add_par(paste0(
    "Note. VIF = variance inflation factor computed from OLS regression analogs of the SEM paths. ",
    "a-path: Platform Resources \u2192 Platform Accessibility; b-path: Platform Accessibility \u2192 International Performance. ",
    "VIF > 10 indicates problematic multicollinearity; VIF > 5 warrants caution (Hair et al., 2010). ",
    "All predictors include Z-standardized composites and control variables. ",
    "\u2014 indicates the variable is not included in that path equation."
  ), style = "Normal") %>%
  body_add_par("")

# --- Table 4c: Heteroskedasticity (Breusch-Pagan) ---
if (requireNamespace("lmtest", quietly = TRUE)) {
  bp_a <- lmtest::bptest(ols_a)
  bp_b <- lmtest::bptest(ols_b)

  bp_df <- data.frame(
    Path = c("a-path (PR → PA)", "b-path (PA → DV)"),
    `χ²` = sprintf("%.2f", c(bp_a$statistic, bp_b$statistic)),
    df = c(bp_a$parameter, bp_b$parameter),
    p = sprintf("%.4f", c(bp_a$p.value, bp_b$p.value)),
    Sig = ifelse(c(bp_a$p.value, bp_b$p.value) < .05, "*", ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  doc <- doc %>%
    body_add_par("Heteroskedasticity (Breusch-Pagan)", style = "heading 3") %>%
    body_add_flextable(apa_table(bp_df, "Breusch-Pagan Tests for Heteroskedasticity")) %>%
    body_add_par(paste0(
      "Note. \u03C7\u00B2 = Breusch-Pagan test statistic; df = degrees of freedom; ",
      "p = significance level. A significant result (p < .05) indicates the presence of ",
      "heteroskedasticity in the residuals. When detected, robust (HC3) standard errors ",
      "or bootstrap standard errors should be used, as implemented in the SEM estimation."
    ), style = "Normal") %>%
    body_add_par("* p < .05.", style = "Normal") %>%
    body_add_par("")
}

# --- Table 5: Phase 3 Dominance Analysis ---
doc <- doc %>%
  body_add_par("Table 5: Phase 3 — Variable-Level Dominance Analysis",
               style = "heading 2")

# Helper to create dominance table for Word
dom_to_df <- function(dom_obj, category_name) {
  gd <- dom_obj$General_Dominance
  dom_df <- data.frame(
    Variable = names(gd),
    `General Dominance` = sprintf("%.4f", as.numeric(gd)),
    `% of R²` = sprintf("%.1f%%", as.numeric(gd) / sum(as.numeric(gd)) * 100),
    Rank = rank(-as.numeric(gd)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  dom_df <- dom_df[order(dom_df$Rank), ]
  dom_df$Rank <- as.integer(dom_df$Rank)
  dom_df
}

# Social dominance table
social_df <- dom_to_df(social_dom, "Social")
doc <- doc %>%
  body_add_par("Social Category", style = "heading 3") %>%
  body_add_flextable(apa_table(social_df,
    sprintf("Social Category Dominance (R\u00B2 = %.3f)", sum(social_dom$General_Dominance)))) %>%
  body_add_par(paste0(
    "Note. General dominance = average marginal R\u00B2 contribution across all subset models ",
    "(Azen & Budescu, 2003). DV: Platform Accessibility (Z-standardized). ",
    "Variables: COM = community/communication resources; GIT = GitHub/version control; ",
    "MON = monetization tools; SPAN = boundary spanning roles (internal, communities, external)."
  ), style = "Normal") %>%
  body_add_par("")

# Development dominance table
dev_df <- dom_to_df(dev_dom, "Development")
doc <- doc %>%
  body_add_par("Development Category", style = "heading 3") %>%
  body_add_flextable(apa_table(dev_df,
    sprintf("Development Category Dominance (R\u00B2 = %.3f)", sum(dev_dom$General_Dominance)))) %>%
  body_add_par(paste0(
    "Note. DEVP = developer portal; DOCS = documentation; SDK = software development kit; ",
    "BUG = bug tracking/issue management; STAN = standards/specifications. ",
    "SDK_prog_lang (programming language count) excluded due to construct overlap with ",
    "programming language variety (PLV), a component of the platform accessibility composite."
  ), style = "Normal") %>%
  body_add_par("")

# AI dominance table
ai_df <- dom_to_df(ai_dom, "AI")
doc <- doc %>%
  body_add_par("AI Category", style = "heading 3") %>%
  body_add_flextable(apa_table(ai_df,
    sprintf("AI Category Dominance (R\u00B2 = %.3f)", sum(ai_dom$General_Dominance)))) %>%
  body_add_par(paste0(
    "Note. AI_MODEL = foundation model access; AI_AGENT = AI agent framework; ",
    "AI_ASSIST = AI-assisted development tools; AI_DATA = structured data interfaces/protocols (e.g., MCP). ",
    "AI_MKT excluded due to zero/near-zero variance."
  ), style = "Normal") %>%
  body_add_par("")

# Governance dominance table
gov_df <- dom_to_df(gov_dom, "Governance")
doc <- doc %>%
  body_add_par("Governance Category", style = "heading 3") %>%
  body_add_flextable(apa_table(gov_df,
    sprintf("Governance Category Dominance (R\u00B2 = %.3f)", sum(gov_dom$General_Dominance)))) %>%
  body_add_par(paste0(
    "Note. ROLE = role-based access control; DATA = data governance/privacy policies; ",
    "STORE = app/extension marketplace; CERT = certification/compliance programs."
  ), style = "Normal") %>%
  body_add_par("")

# Write the Word doc
print(doc, target = sem_word_path)
cat("\n✓ APA Word tables saved to:", sem_word_path, "\n")

# ============================================================================
# SECTION 14: PATH COEFFICIENT DIAGRAM (ggplot)
# ============================================================================
# Creates a visual path diagram showing effect sizes and significance levels
# for the Phase 1 moderated mediation model (Figure 4 in dissertation)
# ============================================================================

library(ggplot2)

if (isTRUE(phase1_plat$converged) && !is.null(phase1_plat$params)) {

  cat("\n--- Generating Path Coefficient Diagram ---\n")

  # Build the node positions for Figure 4 layout
  nodes <- data.frame(
    name = c("Platform\nResources", "Platform\nAccessibility",
             "International\nPerformance",
             "Cultural\nDistance"),
    x = c(0, 2, 4, 2),
    y = c(2, 4, 2, 6),
    type = c("main", "mediator", "outcome", "moderator"),
    stringsAsFactors = FALSE
  )

  # Build the paths from Phase 1 results
  params <- phase1_plat$params

  get_param <- function(lbl) {
    row <- params[params$label == lbl, ]
    if (nrow(row) == 0) return(list(est = NA, p = NA, sig = ""))
    list(est = row$est[1], p = row$pvalue[1], sig = row$sig[1])
  }

  a_path   <- get_param("a")
  b_path   <- get_param("b")
  c_path   <- get_param("c")
  ind_path <- get_param("indirect")
  a_cd     <- get_param("a_cd")
  b_cd     <- get_param("b_cd")

  # Helper to format CI from params
  get_ci <- function(lbl) {
    row <- params[params$label == lbl, ]
    if (nrow(row) == 0) return("")
    sprintf("[%.3f, %.3f]", row$ci.lower[1], row$ci.upper[1])
  }

  # Path data for arrows
  paths <- data.frame(
    x_start = c(0, 2, 0,    2,   2),
    y_start = c(2, 4, 2,    6,   6),
    x_end   = c(2, 4, 4,    1,   3),
    y_end   = c(4, 2, 2,    3,   3),
    label   = c(
      sprintf("a = %.3f %s\n%s", a_path$est, a_path$sig, get_ci("a")),
      sprintf("b = %.3f %s\n%s", b_path$est, b_path$sig, get_ci("b")),
      sprintf("c = %.3f %s\n%s\n(H1: direct)", c_path$est, c_path$sig, get_ci("c")),
      sprintf("H3a = %.3f %s\n%s", a_cd$est, a_cd$sig, get_ci("a_cd")),
      sprintf("H3b = %.3f %s\n%s", b_cd$est, b_cd$sig, get_ci("b_cd"))
    ),
    path_type = c("main", "main", "main", "moderation", "moderation"),
    stringsAsFactors = FALSE
  )

  # Compute label positions (midpoints with offset)
  paths <- paths %>%
    mutate(
      lbl_x = (x_start + x_end) / 2,
      lbl_y = (y_start + y_end) / 2,
      # Offset labels to avoid overlap with arrows
      lbl_y = case_when(
        path_type == "main" & y_start == y_end ~ lbl_y - 0.3,     # horizontal: below
        path_type == "main" ~ lbl_y + 0.3,                        # diagonal: above
        TRUE ~ lbl_y
      )
    )

  p_path <- ggplot() +
    # Draw arrows
    geom_segment(data = paths,
                 aes(x = x_start, y = y_start, xend = x_end, yend = y_end,
                     linetype = path_type),
                 arrow = arrow(length = unit(0.15, "inches"), type = "closed"),
                 linewidth = 0.8, color = "grey30") +
    scale_linetype_manual(values = c("main" = "solid", "moderation" = "dashed"),
                          guide = "none") +
    # Draw nodes (boxes)
    geom_label(data = nodes,
               aes(x = x, y = y, label = name, fill = type),
               size = 3.5, fontface = "bold", family = "Times New Roman",
               label.padding = unit(0.4, "lines"),
               label.r = unit(0.15, "lines"),
               color = "white") +
    scale_fill_manual(values = c("main" = "#1f77b4", "mediator" = "#2ca02c",
                                  "outcome" = "#d62728", "moderator" = "#7f7f7f"),
                      guide = "none") +
    # Path coefficient labels
    geom_label(data = paths,
               aes(x = lbl_x, y = lbl_y, label = label),
               size = 2.8, fill = "white", alpha = 0.9, family = "Times New Roman",
               label.padding = unit(0.2, "lines")) +
    # Indirect effect annotation with CI
    annotate("text", x = 2, y = 0.8,
             label = sprintf("H2: Indirect (a\u00D7b) = %.3f %s, 95%% CI %s",
                             ind_path$est, ind_path$sig, get_ci("indirect")),
             size = 3.5, fontface = "italic", color = "#2ca02c", family = "Times New Roman") +
    # Significance legend
    annotate("text", x = 4, y = 6.2,
             label = "*** p<.001  ** p<.01  * p<.05  + p<.10  ns = not sig.",
             size = 2.5, hjust = 1, color = "grey50", family = "Times New Roman") +
    # Title and figure note
    labs(title = NULL,
         subtitle = sprintf("PLAT Sample (N = %d dyads)", nrow(df_plat)),
         caption = paste0(
           "Note. Unstandardized coefficients shown with 95% bootstrap CI (5,000 replications). ",
           "Solid lines = main paths; dashed lines = moderation paths. ",
           "Controls: home GDP, host GDP, host internet penetration, industry growth rate."
         )) +
    theme_void(base_family = "Times New Roman") +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      plot.subtitle = element_text(hjust = 0.5, size = 11, color = "grey40"),
      plot.caption = element_text(hjust = 0, size = 8, color = "grey40",
                                   margin = margin(t = 10)),
      plot.caption.position = "plot",
      plot.margin = margin(15, 15, 15, 15)
    ) +
    coord_cartesian(xlim = c(-0.8, 4.8), ylim = c(0.3, 6.8))

  print(p_path)
  ggsave(file.path(tables_path, "11_Phase1_Path_Diagram.png"),
         p_path, width = 10, height = 7, dpi = 300, bg = "white")
  cat("  ✓ Path diagram saved: 11_Phase1_Path_Diagram.png\n")

  # --- Phase 2 Category Effects Bar Chart ---
  if (isTRUE(phase2_plat$converged) && !is.null(phase2_plat$params)) {

    cat("--- Generating Phase 2 Category Effects Chart ---\n")

    cat_effect_labels <- c("a_app", "a_dev", "a_ai", "a_soc", "a_gov",
                            "c_app", "c_dev", "c_ai", "c_soc", "c_gov")
    cat_display <- c(
      a_app = "Application", a_dev = "Development",
      a_ai = "AI", a_soc = "Social", a_gov = "Governance",
      c_app = "Application", c_dev = "Development",
      c_ai = "AI", c_soc = "Social", c_gov = "Governance"
    )
    cat_path_type <- c(
      a_app = "a path (→ PA)", a_dev = "a path (→ PA)",
      a_ai = "a path (→ PA)", a_soc = "a path (→ PA)", a_gov = "a path (→ PA)",
      c_app = "c path (→ Perf)", c_dev = "c path (→ Perf)",
      c_ai = "c path (→ Perf)", c_soc = "c path (→ Perf)", c_gov = "c path (→ Perf)"
    )

    p2_data <- phase2_plat$params %>%
      filter(label %in% cat_effect_labels) %>%
      mutate(
        category = cat_display[label],
        path = cat_path_type[label],
        sig_flag = case_when(
          pvalue < .001 ~ "***",
          pvalue < .01  ~ "**",
          pvalue < .05  ~ "*",
          pvalue < .10  ~ "+",
          TRUE          ~ ""
        ),
        bar_label = sprintf("%.3f%s", std.all, sig_flag),
        is_sig = pvalue < .05
      )

    p2_chart <- ggplot(p2_data,
                        aes(x = reorder(category, std.all),
                            y = std.all, fill = is_sig)) +
      geom_col(width = 0.7) +
      geom_errorbar(aes(ymin = ci.lower, ymax = ci.upper),
                    width = 0.25, linewidth = 0.4, color = "grey30") +
      geom_text(aes(label = bar_label),
                hjust = ifelse(p2_data$std.all >= 0, -0.1, 1.1),
                size = 3, family = "Times New Roman") +
      geom_hline(yintercept = 0, linewidth = 0.5) +
      facet_wrap(~path, ncol = 1, scales = "free_x") +
      coord_flip() +
      scale_fill_manual(values = c("TRUE" = "#1f77b4", "FALSE" = "#cccccc"),
                        labels = c("TRUE" = "p < .05", "FALSE" = "Not sig."),
                        name = "Significance") +
      labs(title = NULL,
           subtitle = sprintf("PLAT sample (N = %d) \u2014 a paths (\u2192 Platform Accessibility) and c paths (\u2192 Performance)",
                              n_distinct(df_plat$platform_ID)),
           x = NULL, y = "Standardized Coefficient (\u03B2)",
           caption = paste0(
             "Note. Error bars = 95% bootstrap confidence intervals (5,000 replications). ",
             "Blue bars significant at p < .05; grey bars not significant. ",
             "*** p < .001. ** p < .01. * p < .05. \u2020 p < .10. ",
             "Controls: home GDP, host GDP, host internet penetration, industry growth rate."
           )) +
      theme_classic(base_family = "Times New Roman", base_size = 12) +
      theme(
        plot.title = element_text(face = "bold"),
        strip.text = element_text(face = "bold", size = 11),
        legend.position = "bottom",
        plot.caption = element_text(hjust = 0, size = 8, color = "grey40",
                                     margin = margin(t = 10)),
        plot.caption.position = "plot"
      )

    print(p2_chart)
    ggsave(file.path(tables_path, "11_Phase2_Category_Effects.png"),
           p2_chart, width = 9, height = 7, dpi = 300, bg = "white")
    cat("  ✓ Category effects chart saved: 11_Phase2_Category_Effects.png\n")
  }

} else {
  cat("\n⚠ Skipping path diagram — Phase 1 did not converge.\n")
}

# ============================================================================
# SECTION 15: FINAL OUTPUT SUMMARY
# ============================================================================

cat("\n✓ Script 11 complete.\n")
cat("  Outputs:\n")
cat("    phase1_plat_vs_full_comparison.csv\n")
cat("    11_SEM_Results_APA.docx (Word tables)\n")
cat("    11_Phase1_Path_Diagram.png (path coefficient diagram)\n")
cat("    11_Phase2_Category_Effects.png (category bar chart)\n")
cat("  Phase 1, 2, 3 results printed to console.\n")
cat("  Separate mediator robustness (LV + PLV) on both PLAT and Full samples.\n")
cat("  Validity diagnostics: normality, heteroskedasticity, VIF, outliers.\n")
cat("  Heckman two-step correction: combined PA and separate LV/PLV.\n")
cat("  Interaction plots rendered (save manually if needed).\n")

# ============================================================================
# METHODS SECTION LANGUAGE
# ============================================================================
# "We employed a three-phase telescoping approach to test our theoretical
# model (see Figure 4). Phase 1 tested the full moderated mediation model
# using a composite platform resources score (Equation 2). We specified
# structural equation models in lavaan (Rosseel, 2012) with bootstrapped
# standard errors (5,000 replications) to test direct effects (H1),
# indirect effects via platform accessibility (H2), and moderation by
# cultural distance on both the a-path (H3a) and b-path (H3B).
#
# Phase 2 decomposed the composite into five boundary resource category
# Z-scores (Application, Development, AI, Social, Governance) to test
# H1A-H1E: which resource categories drive the effects.
#
# Phase 3 conducted variable-level dominance analysis (Azen & Budescu,
# 2003; Luchman, 2023) within each significant category to identify
# specific resource drivers.
#
# The primary analysis used PLAT firms with available cultural distance data,
# as these are the firms with observable boundary resources. As a
# robustness check, we re-estimated Phase 1 on the full sample of 903
# firms (N=[X] dyads), treating non-platform firms as the baseline
# condition with zero resource investment.
#
# Validity and robustness: We assessed normality via Shapiro-Wilk tests
# and skewness/kurtosis diagnostics (Curran et al., 1996), tested for
# heteroskedasticity using the Breusch-Pagan test (Lee et al., 2008),
# and checked multicollinearity via variance inflation factors. Outliers
# were identified using Cook's distance (4/n threshold) and Mahalanobis
# distance (p < .001). To address potential sample selection bias arising
# from the restriction of the primary analysis to platform firms, we
# employed the Heckman (1979) two-step procedure (Bascle, 2008; Hamilton
# & Nickerson, 2003). In the first stage, a probit model estimated the
# probability of a firm having a developer portal (is_PLAT = 1) as a
# function of firm age, home country GDP, firm size, and industry growth.
# The inverse Mills ratio (IMR) computed from the first stage was then
# included as a control variable in the second-stage outcome equation
# (Certo et al., 2016). A significant IMR coefficient (λ ≠ 0) would
# indicate that selection into the platform subsample biases the
# regression estimates (Qerimi et al., 2023)."
# ============================================================================
