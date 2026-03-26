# ============================================================================
# 14 - CLUSTER ANALYSIS: RESOURCE PROFILES × PERFORMANCE OUTCOMES
# ============================================================================
# Author: Heather Carle
# Purpose: Exploratory analysis linking boundary resource cluster profiles
#          (from 08_descriptive_statistics.R Part G) to performance outcomes.
#          Tests whether natural groupings of platforms based on their resource
#          configurations differ in platform accessibility and international
#          performance.
#
# Chapter IV section: "Additional Exploratory Analysis"
#   (alongside 10_pca_aligned_sem.R and 11_ai_time_investigation.R)
#
# Input:   MASTER_CODEBOOK_analytic.xlsx
#          platform_cluster_assignments.csv (from script 08, Part G)
# Output:  Cluster–performance tables, ANOVA results, multi-group SEM,
#          cluster profile visualizations
# Last Updated: February 2026
#
# ANALYSIS STRUCTURE:
#   Part A: Merge clusters with outcome data
#   Part B: Descriptive profiles — cluster × outcomes
#   Part C: ANOVA / Kruskal-Wallis across clusters
#   Part D: Effect sizes and pairwise comparisons
#   Part E: Multi-group SEM (Phase 1 model by cluster)
#   Part F: Visualization
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lavaan)
library(writexl)

# For effect sizes and post-hoc tests
if (!requireNamespace("effectsize", quietly = TRUE)) {
  cat("Installing effectsize package...\n")
  install.packages("effectsize", repos = "https://cloud.r-project.org",
                   quiet = TRUE)
}
if (!requireNamespace("rstatix", quietly = TRUE)) {
  cat("Installing rstatix package...\n")
  install.packages("rstatix", repos = "https://cloud.r-project.org",
                   quiet = TRUE)
}

library(effectsize)
library(rstatix)

# ============================================================================
# SECTION 2: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis")
tables_path <- file.path(base_path, "FINAL DISSERTATION",
                          "tables and charts REVISED")

mc <- read_excel(codebook_path)
cat("Loaded:", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "platforms\n")

# PLAT dyads — filter to dyads with cultural_distance available (see script 10)
plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(cultural_distance))
cat("PLAT dyads (with CD):", nrow(plat_dyads), "\n")

# Load cluster assignments from script 08
cluster_file <- file.path(output_path, "platform_cluster_assignments.csv")

if (!file.exists(cluster_file)) {
  stop("Cluster assignments not found at: ", cluster_file,
       "\n  Run 08_descriptive_statistics.R (Part G) first.")
}

clusters <- read.csv(cluster_file, stringsAsFactors = FALSE)
cat("Cluster assignments loaded:", nrow(clusters), "platforms\n\n")

# ============================================================================
# SECTION 3: SELECT OPTIMAL K
# ============================================================================

# Script 08 saves k=3, k=4, k=5. We'll use k=4 as default (common in
# typology research) but test all three for robustness.
# You can change this after reviewing the elbow plot from script 08.

preferred_k <- 4
cluster_col <- paste0("cluster_k", preferred_k)

if (!cluster_col %in% colnames(clusters)) {
  # Fallback: use whatever k is available
  avail_k <- grep("^cluster_k", colnames(clusters), value = TRUE)
  if (length(avail_k) == 0) {
    stop("No cluster_k columns found in cluster assignments file.")
  }
  cluster_col <- avail_k[1]
  preferred_k <- as.numeric(gsub("cluster_k", "", cluster_col))
  cat("NOTE: k=4 not found. Using", cluster_col, "\n\n")
}

cat("Using cluster solution: k =", preferred_k, "\n\n")

# ============================================================================
# PART A: MERGE CLUSTERS WITH OUTCOME DATA
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART A: MERGE CLUSTER ASSIGNMENTS WITH DYAD-LEVEL OUTCOMES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Merge cluster assignments (platform-level) into dyad-level data
# Use cluster_label from script 08 if available (automatic profile-based names)
if ("cluster_label" %in% colnames(clusters)) {
  cluster_lookup <- clusters %>%
    select(platform_ID, cluster = cluster_label)
  cat("Using automatic cluster labels from script 08.\n")
} else {
  cluster_lookup <- clusters %>%
    select(platform_ID, cluster = all_of(cluster_col))
  cat("NOTE: cluster_label not found — using raw cluster numbers.\n")
  cat("  Re-run script 08 to generate automatic labels.\n")
}

plat_analysis <- plat_dyads %>%
  left_join(cluster_lookup, by = "platform_ID") %>%
  filter(!is.na(cluster))

cat("Dyads with cluster assignment:", nrow(plat_analysis), "\n")
cat("Platforms per cluster:\n")
plat_analysis %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  count(cluster) %>%
  print()

# Label clusters as factor
plat_analysis <- plat_analysis %>%
  mutate(cluster = factor(cluster))

# ============================================================================
# PART B: DESCRIPTIVE PROFILES — CLUSTER × OUTCOMES
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART B: CLUSTER PROFILES WITH OUTCOME VARIABLES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Outcome variables
outcome_vars <- c("MKT_SHARE_CHANGE", "platform_accessibility")
# Resource composites for profile context
resource_vars <- c("platform_resources",
                    "Z_application", "Z_development", "Z_ai",
                    "Z_social", "Z_governance")

# Check which vars exist
profile_vars <- intersect(c(outcome_vars, resource_vars), colnames(plat_analysis))

# --- B1: Dyad-level profiles ---
cat("--- B1: Dyad-Level Means by Cluster ---\n\n")

dyad_profile <- plat_analysis %>%
  group_by(cluster) %>%
  summarize(
    n_dyads = n(),
    n_platforms = n_distinct(platform_ID),
    across(all_of(profile_vars),
           list(mean = ~mean(., na.rm = TRUE),
                sd   = ~sd(., na.rm = TRUE)),
           .names = "{.col}_{.fn}"),
    .groups = "drop"
  )

# Print key columns
cat("Cluster sizes:\n")
dyad_profile %>%
  select(cluster, n_dyads, n_platforms) %>%
  print()

cat("\nOutcome means:\n")
for (v in intersect(outcome_vars, colnames(plat_analysis))) {
  cat(sprintf("\n  %s:\n", v))
  dyad_profile %>%
    select(cluster,
           mean = !!sym(paste0(v, "_mean")),
           sd   = !!sym(paste0(v, "_sd"))) %>%
    mutate(across(where(is.numeric), ~round(., 4))) %>%
    print()
}

cat("\nResource profile means:\n")
for (v in intersect(resource_vars, colnames(plat_analysis))) {
  cat(sprintf("\n  %s:\n", v))
  dyad_profile %>%
    select(cluster,
           mean = !!sym(paste0(v, "_mean")),
           sd   = !!sym(paste0(v, "_sd"))) %>%
    mutate(across(where(is.numeric), ~round(., 3))) %>%
    print()
}

# --- B2: Firm-level profiles ---
cat("\n--- B2: Firm-Level Means by Cluster ---\n\n")

firm_profile <- plat_analysis %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  group_by(cluster) %>%
  summarize(
    n = n(),
    across(all_of(intersect(resource_vars, colnames(plat_analysis))),
           list(mean = ~mean(., na.rm = TRUE),
                sd   = ~sd(., na.rm = TRUE)),
           .names = "{.col}_{.fn}"),
    .groups = "drop"
  )

print(firm_profile %>%
        select(cluster, n, ends_with("_mean")) %>%
        mutate(across(where(is.numeric) & !matches("^n$"), ~round(., 3))))

# ============================================================================
# PART C: ANOVA / KRUSKAL-WALLIS ACROSS CLUSTERS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART C: STATISTICAL TESTS — CLUSTER DIFFERENCES IN OUTCOMES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

anova_results <- tibble(
  Variable = character(), Test = character(),
  Statistic = numeric(), df1 = numeric(), df2 = numeric(),
  p_value = numeric(), Sig = character()
)

for (v in intersect(outcome_vars, colnames(plat_analysis))) {
  cat(sprintf("--- %s ---\n", v))

  # Check normality within clusters (Shapiro-Wilk on subsample)
  normality_ok <- TRUE
  tryCatch({
    sw_results <- plat_analysis %>%
      group_by(cluster) %>%
      slice_sample(n = min(50, n())) %>%  # Shapiro max 5000
      shapiro_test(!!sym(v))

    cat("Shapiro-Wilk by cluster:\n")
    print(sw_results)
    if (any(sw_results$p < 0.05)) normality_ok <- FALSE
  }, error = function(e) {
    cat("  Shapiro-Wilk failed:", e$message, "\n")
    normality_ok <<- FALSE
  })

  # Check homogeneity of variances (Levene's test)
  levene_ok <- TRUE
  tryCatch({
    lev <- plat_analysis %>%
      levene_test(as.formula(paste(v, "~ cluster")))
    cat("\nLevene's test: F =", round(lev$statistic, 3),
        ", p =", round(lev$p, 4), "\n")
    if (lev$p < 0.05) levene_ok <- FALSE
  }, error = function(e) {
    cat("  Levene's test failed:", e$message, "\n")
    levene_ok <<- FALSE
  })

  # Choose test based on assumptions
  if (normality_ok && levene_ok) {
    # Standard one-way ANOVA
    aov_res <- aov(as.formula(paste(v, "~ cluster")), data = plat_analysis)
    f_table <- summary(aov_res)[[1]]
    cat(sprintf("\nOne-way ANOVA: F(%d, %d) = %.3f, p = %.4f\n",
                f_table$Df[1], f_table$Df[2],
                f_table$`F value`[1], f_table$`Pr(>F)`[1]))

    anova_results <- bind_rows(anova_results, tibble(
      Variable = v, Test = "ANOVA",
      Statistic = round(f_table$`F value`[1], 3),
      df1 = f_table$Df[1], df2 = f_table$Df[2],
      p_value = round(f_table$`Pr(>F)`[1], 4),
      Sig = ifelse(f_table$`Pr(>F)`[1] < .05, "Yes", "No")
    ))

  } else if (normality_ok && !levene_ok) {
    # Welch's ANOVA (heterogeneous variances)
    welch_res <- oneway.test(as.formula(paste(v, "~ cluster")),
                             data = plat_analysis, var.equal = FALSE)
    cat(sprintf("\nWelch's ANOVA: F(%.1f, %.1f) = %.3f, p = %.4f\n",
                welch_res$parameter[1], welch_res$parameter[2],
                welch_res$statistic, welch_res$p.value))

    anova_results <- bind_rows(anova_results, tibble(
      Variable = v, Test = "Welch ANOVA",
      Statistic = round(welch_res$statistic, 3),
      df1 = round(welch_res$parameter[1], 1),
      df2 = round(welch_res$parameter[2], 1),
      p_value = round(welch_res$p.value, 4),
      Sig = ifelse(welch_res$p.value < .05, "Yes", "No")
    ))

  } else {
    # Kruskal-Wallis (non-parametric)
    kw_res <- kruskal.test(as.formula(paste(v, "~ cluster")),
                           data = plat_analysis)
    cat(sprintf("\nKruskal-Wallis: H(%d) = %.3f, p = %.4f\n",
                kw_res$parameter, kw_res$statistic, kw_res$p.value))

    anova_results <- bind_rows(anova_results, tibble(
      Variable = v, Test = "Kruskal-Wallis",
      Statistic = round(kw_res$statistic, 3),
      df1 = kw_res$parameter, df2 = NA_real_,
      p_value = round(kw_res$p.value, 4),
      Sig = ifelse(kw_res$p.value < .05, "Yes", "No")
    ))
  }

  cat("\n")
}

cat("--- Omnibus Test Summary ---\n")
print(as.data.frame(anova_results))

# ============================================================================
# PART D: EFFECT SIZES AND PAIRWISE COMPARISONS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART D: EFFECT SIZES AND POST-HOC PAIRWISE COMPARISONS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

pairwise_all <- tibble()

for (v in intersect(outcome_vars, colnames(plat_analysis))) {
  cat(sprintf("--- %s ---\n\n", v))

  # Eta-squared (effect size for ANOVA)
  aov_fit <- aov(as.formula(paste(v, "~ cluster")), data = plat_analysis)
  eta <- tryCatch({
    effectsize::eta_squared(aov_fit, partial = FALSE)
  }, error = function(e) NULL)

  if (!is.null(eta)) {
    cat(sprintf("Eta-squared: %.4f", eta$Eta2))
    cat(sprintf("  [%.4f, %.4f]\n", eta$CI_low, eta$CI_high))
    interp <- case_when(
      eta$Eta2 >= 0.14 ~ "large",
      eta$Eta2 >= 0.06 ~ "medium",
      eta$Eta2 >= 0.01 ~ "small",
      TRUE             ~ "negligible"
    )
    cat(sprintf("Interpretation (Cohen, 1988): %s effect\n\n", interp))
  }

  # Pairwise comparisons (Games-Howell for unequal variances)
  pw <- tryCatch({
    plat_analysis %>%
      games_howell_test(as.formula(paste(v, "~ cluster")))
  }, error = function(e) {
    # Fallback to Tukey
    tryCatch({
      plat_analysis %>%
        tukey_hsd(as.formula(paste(v, "~ cluster")))
    }, error = function(e2) NULL)
  })

  if (!is.null(pw)) {
    cat("Post-hoc pairwise comparisons:\n")
    print(pw)
    cat("\n")
    pairwise_all <- bind_rows(pairwise_all,
                               pw %>% mutate(outcome = v))
  }
}

# ============================================================================
# PART E: MULTI-GROUP SEM (PHASE 1 MODEL BY CLUSTER)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART E: MULTI-GROUP SEM — DOES THE MODEL VARY BY CLUSTER?\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Check if we have the necessary standardized variables
sem_needed <- c("PR_z", "PA_z", "DV_z", "CD_z",
                "PR_x_CD", "PA_x_CD",
                "home_GDP_z", "host_GDP_z", "host_INET_z",
                "IND_GROW_z")

# Check if standardized vars exist (they should from script 11)
sem_exist <- intersect(sem_needed, colnames(plat_analysis))
sem_missing <- setdiff(sem_needed, colnames(plat_analysis))

if (length(sem_missing) > 0) {
  cat("Standardized SEM variables not in codebook. Computing them now...\n\n")

  # Compute standardized versions from raw
  raw_to_z <- function(x) as.numeric(scale(x))

  plat_analysis <- plat_analysis %>%
    mutate(
      PR_z  = raw_to_z(platform_resources),
      PA_z  = raw_to_z(platform_accessibility),   # composite of LV + PLV
      DV_z  = raw_to_z(MKT_SHARE_CHANGE),
      CD_z  = raw_to_z(cultural_distance),
      home_GDP_z  = raw_to_z(home_gdp_per_capita),
      host_GDP_z  = raw_to_z(host_gdp_per_capita),
      host_INET_z = raw_to_z(host_Internet_users),
      IND_GROW_z  = raw_to_z(IND_GROW),
      # Interactions
      PR_x_CD  = PR_z * CD_z,
      PA_x_CD  = PA_z * CD_z
    )
}

# Check minimum cluster sizes for multi-group
cluster_n <- plat_analysis %>% count(cluster)
min_n <- min(cluster_n$n)
cat("Minimum cluster size:", min_n, "dyads\n")

if (min_n < 50) {
  cat("⚠ Smallest cluster has < 50 dyads. Multi-group SEM may be unstable.\n")
  cat("  Proceeding with caution. Consider collapsing small clusters.\n\n")
}

# --- E1: Configural model (FREE parameters across clusters — NO labels) ---
# IMPORTANT: Labels force equality across groups in lavaan multi-group SEM.
# Configural model must have NO labels so each cluster gets its own estimates.
cat("--- E1: Configural Model (parameters FREE across clusters) ---\n")

model_config <- '
  # a path: Platform Resources → Platform Accessibility
  PA_z ~ PR_z + PR_x_CD + CD_z +
         home_GDP_z + host_GDP_z + host_INET_z +
         IND_GROW_z

  # b + c paths: → International Performance
  DV_z ~ PA_z + PR_z + PA_x_CD + CD_z +
         host_GDP_z + host_INET_z +
         IND_GROW_z
'

fit_config <- tryCatch({
  sem(model_config, data = plat_analysis, group = "cluster",
      estimator = "MLR")
}, error = function(e) {
  cat("  Configural SEM failed:", e$message, "\n")
  NULL
})

if (!is.null(fit_config)) {
  cat("  Configural fit:\n")
  print(fitMeasures(fit_config, c("chisq", "df", "pvalue",
                                   "cfi", "tli", "rmsea", "srmr")))

  # Show key paths by cluster (identify by position: PR→EA = a, EA→DV = b, PR→DV = c)
  params_mg <- parameterEstimates(fit_config, standardized = TRUE)

  # Extract a, b, c paths by variable names (not labels)
  key_paths <- params_mg %>%
    filter(
      (lhs == "PA_z" & op == "~" & rhs == "PR_z") |    # a path
      (lhs == "DV_z" & op == "~" & rhs == "PA_z") |    # b path
      (lhs == "DV_z" & op == "~" & rhs == "PR_z")      # c path
    ) %>%
    mutate(
      path = case_when(
        lhs == "PA_z" & rhs == "PR_z" ~ "a (PR→EA)",
        lhs == "DV_z" & rhs == "PA_z" ~ "b (EA→DV)",
        lhs == "DV_z" & rhs == "PR_z" ~ "c (PR→DV)"
      )
    ) %>%
    select(group, path, est, se, pvalue, std.all) %>%
    mutate(
      across(c(est, se, std.all), ~round(., 3)),
      pvalue = round(pvalue, 4),
      sig = case_when(pvalue < .001 ~ "***", pvalue < .01 ~ "**",
                      pvalue < .05 ~ "*", pvalue < .10 ~ "\u2020",
                      TRUE ~ "ns")
    )

  # Compute indirect effects per group from the free estimates
  a_vals <- key_paths %>% filter(grepl("^a ", path)) %>% select(group, a_est = est)
  b_vals <- key_paths %>% filter(grepl("^b ", path)) %>% select(group, b_est = est)
  indirect_by_group <- left_join(a_vals, b_vals, by = "group") %>%
    mutate(indirect = round(a_est * b_est, 3))

  cat("\n--- Key Path Coefficients by Cluster (FREE estimates) ---\n")
  for (pth in unique(key_paths$path)) {
    cat(sprintf("\n  %s:\n", pth))
    key_paths %>% filter(path == pth) %>% print()
  }
  cat("\n  Indirect effects (a * b) by cluster:\n")
  print(as.data.frame(indirect_by_group))

  # --- E2: Constrained model (EQUAL structural paths — labels force equality) ---
  cat("\n--- E2: Constrained Model (structural paths EQUAL across clusters) ---\n")

  model_constrain <- '
    PA_z ~ a*PR_z + PR_x_CD + CD_z +
           home_GDP_z + host_GDP_z + host_INET_z +
           IND_GROW_z

    DV_z ~ b*PA_z + c*PR_z + PA_x_CD + CD_z +
           host_GDP_z + host_INET_z +
           IND_GROW_z

    indirect := a * b
    total    := c + (a * b)
  '

  fit_constrain <- tryCatch({
    sem(model_constrain, data = plat_analysis, group = "cluster",
        estimator = "MLR")
  }, error = function(e) {
    cat("  Constrained model failed:", e$message, "\n")
    NULL
  })

  if (!is.null(fit_constrain)) {
    cat("  Constrained fit:\n")
    print(fitMeasures(fit_constrain, c("chisq", "df", "pvalue",
                                        "cfi", "tli", "rmsea", "srmr")))

    # Chi-square difference test
    cat("\n--- E3: Model Comparison (free vs constrained) ---\n")
    comp <- tryCatch({
      anova(fit_config, fit_constrain)
    }, error = function(e) {
      cat("  Comparison failed:", e$message, "\n")
      NULL
    })

    if (!is.null(comp)) {
      print(comp)

      chi_diff_p <- comp$`Pr(>Chisq)`[2]
      if (!is.na(chi_diff_p) && chi_diff_p < .05) {
        cat("\n-> Significant chi-square difference (p < .05):")
        cat("\n  The structural paths VARY across clusters.\n")
        cat("  This means the BR -> Performance relationship depends on\n")
        cat("  the type of resource configuration (cluster membership).\n")
      } else {
        cat("\n-> Non-significant chi-square difference (p >= .05):")
        cat("\n  The structural paths are INVARIANT across clusters.\n")
        cat("  The model operates similarly regardless of resource profile.\n")
      }
    }
  }

  # Save multi-group results
  write.csv(key_paths,
            file.path(output_path, "multigroup_sem_by_cluster.csv"),
            row.names = FALSE)
}

# ============================================================================
# PART F: VISUALIZATION
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART F: CLUSTER PROFILE VISUALIZATIONS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- F1: Radar/parallel coordinate plot of resource profiles ---
cat("--- F1: Resource Profile by Cluster ---\n")

firm_data <- plat_analysis %>%
  distinct(platform_ID, .keep_all = TRUE)

resource_exist <- intersect(resource_vars, colnames(firm_data))

if (length(resource_exist) >= 3) {
  profile_long <- firm_data %>%
    select(cluster, all_of(resource_exist)) %>%
    pivot_longer(-cluster, names_to = "Resource", values_to = "Z_Score") %>%
    mutate(
      Resource = gsub("Z_", "", Resource),
      Resource = gsub("_", " ", Resource),
      Resource = tools::toTitleCase(Resource)
    )

  p1 <- ggplot(profile_long, aes(x = Resource, y = Z_Score, fill = cluster)) +
    stat_summary(fun = mean, geom = "bar", position = position_dodge(0.8),
                 width = 0.7) +
    stat_summary(fun.data = mean_se, geom = "errorbar",
                 position = position_dodge(0.8), width = 0.3) +
    scale_fill_manual(values = c("Generalists"   = "#2ca02c",
                                  "Minimalists"   = "#d95f02",
                                  "Collaborators" = "#1f77b4",
                                  "Innovators"    = "#d62728")) +
    labs(x = "Resource Category (Z-Score)",
         y = "Mean Z-Score",
         fill = "Cluster") +
    theme_classic(base_family = "Times New Roman", base_size = 12) +
    theme(axis.text.x = element_text(angle = 30, hjust = 1),
          legend.position = "bottom",
          plot.title = element_blank(),
          plot.subtitle = element_blank())

  ggsave(file.path(output_path, "cluster_resource_profiles.png"),
         p1, width = 10, height = 6, dpi = 300)
  cat("  Saved: cluster_resource_profiles.png\n")
}

# --- F2: Outcome boxplots by cluster ---
cat("\n--- F2: Outcome Distributions by Cluster ---\n")

for (v in intersect(outcome_vars, colnames(plat_analysis))) {
  v_label <- switch(v,
    MKT_SHARE_CHANGE = "International Performance (Market Share Change)",
    platform_accessibility = "Platform Accessibility",
    v
  )

  p2 <- ggplot(plat_analysis, aes(x = cluster, y = !!sym(v), fill = cluster)) +
    geom_boxplot(alpha = 0.7, outlier.alpha = 0.3) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 3,
                 fill = "white") +
    scale_fill_manual(values = c("Generalists"   = "#2ca02c",
                                  "Minimalists"   = "#d95f02",
                                  "Collaborators" = "#1f77b4",
                                  "Innovators"    = "#d62728")) +
    labs(x = NULL, y = v_label) +
    theme_classic(base_family = "Times New Roman", base_size = 12) +
    theme(legend.position = "none",
          plot.title = element_blank(),
          plot.subtitle = element_blank())

  fname <- paste0("cluster_outcome_", tolower(gsub("[^a-zA-Z]", "_", v)), ".png")
  ggsave(file.path(output_path, fname), p2, width = 8, height = 6, dpi = 300)
  cat("  Saved:", fname, "\n")
}

# --- F3: Combined heatmap of cluster × category means ---
cat("\n--- F3: Cluster Profile Heatmap ---\n")

if (length(resource_exist) >= 3) {
  heatmap_data <- firm_data %>%
    group_by(cluster) %>%
    summarize(across(all_of(resource_exist), ~mean(., na.rm = TRUE)),
              .groups = "drop") %>%
    pivot_longer(-cluster, names_to = "Resource", values_to = "Mean_Z") %>%
    mutate(
      Resource = gsub("Z_", "", Resource),
      Resource = gsub("_", " ", Resource),
      Resource = tools::toTitleCase(Resource)
    )

  p3 <- ggplot(heatmap_data, aes(x = Resource, y = cluster, fill = Mean_Z)) +
    geom_tile(color = "white", linewidth = 1) +
    geom_text(aes(label = round(Mean_Z, 2)), size = 4) +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
                         midpoint = 0) +
    labs(fill = "Mean Z") +
    theme_classic(base_family = "Times New Roman", base_size = 12) +
    theme(axis.text.x = element_text(angle = 30, hjust = 1),
          plot.title = element_blank(),
          plot.subtitle = element_blank())

  ggsave(file.path(output_path, "cluster_heatmap.png"),
         p3, width = 9, height = 5, dpi = 300)
  cat("  Saved: cluster_heatmap.png\n")
}

# ============================================================================
# SECTION FINAL: SAVE ALL RESULTS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SCRIPT 14 COMPLETE — CLUSTER × PERFORMANCE ANALYSIS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Save CSVs
write.csv(anova_results,
          file.path(output_path, "cluster_anova_results.csv"),
          row.names = FALSE)

if (nrow(pairwise_all) > 0) {
  write.csv(pairwise_all,
            file.path(output_path, "cluster_pairwise_comparisons.csv"),
            row.names = FALSE)
}

write.csv(dyad_profile,
          file.path(output_path, "cluster_dyad_profiles.csv"),
          row.names = FALSE)

# ============================================================================
# APA WORD TABLE EXPORTS
# ============================================================================

cat("\n=== EXPORTING APA TABLES TO WORD ===\n\n")

library(flextable)
library(officer)

word_path <- file.path(tables_path, "14_Cluster_Performance_APA.docx")
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

# --- Table 1: Cluster Resource Profiles (firm-level) ---
doc <- doc %>%
  body_add_par("Table 1: Cluster Resource Profiles (Firm-Level Means)",
               style = "heading 2")

# Build a clean firm-level profile table
firm_tbl <- firm_profile %>%
  select(cluster, n, ends_with("_mean")) %>%
  mutate(across(where(is.numeric) & !matches("^n$"), ~round(., 3)))

# Clean column names
names(firm_tbl) <- gsub("_mean$", "", names(firm_tbl))
names(firm_tbl)[1:2] <- c("Cluster", "n")

doc <- doc %>%
  body_add_flextable(apa_table(as.data.frame(firm_tbl),
    "Firm-Level Resource Profiles by Cluster")) %>%
  body_add_par("")

# --- Table 2: ANOVA / Kruskal-Wallis Results ---
doc <- doc %>%
  body_add_par("Table 2: Statistical Tests — Cluster Differences in Outcomes",
               style = "heading 2")

anova_tbl <- anova_results %>%
  mutate(
    Statistic = sprintf("%.3f", Statistic),
    p_value   = ifelse(p_value < .001, "< .001", sprintf("%.3f", p_value))
  ) %>%
  select(Variable, Test, Statistic, df1, df2, `p` = p_value, Sig)

# Add effect sizes if available
if ("Effect_Size" %in% colnames(anova_results)) {
  anova_tbl$`η²` <- sprintf("%.3f", anova_results$Effect_Size)
}

doc <- doc %>%
  body_add_flextable(apa_table(as.data.frame(anova_tbl),
    "ANOVA / Kruskal-Wallis Tests for Cluster Differences")) %>%
  body_add_par("")

# --- Table 3: Pairwise Comparisons (if any) ---
if (nrow(pairwise_all) > 0) {
  doc <- doc %>%
    body_add_par("Table 3: Post-Hoc Pairwise Comparisons",
                 style = "heading 2")

  pw_tbl <- pairwise_all %>%
    mutate(across(where(is.numeric), ~round(., 3))) %>%
    as.data.frame()

  doc <- doc %>%
    body_add_flextable(apa_table(pw_tbl,
      "Pairwise Cluster Comparisons (Games-Howell / Dunn)")) %>%
    body_add_par("")
}

# --- Table 4: Dyad-Level Outcome Means by Cluster ---
doc <- doc %>%
  body_add_par("Table 4: Dyad-Level Outcome Means by Cluster",
               style = "heading 2")

# Build outcome summary table
outcome_cols <- intersect(outcome_vars, colnames(plat_analysis))
outcome_tbl <- dyad_profile %>%
  select(cluster, n_dyads, n_platforms)

for (v in outcome_cols) {
  mean_col <- paste0(v, "_mean")
  sd_col   <- paste0(v, "_sd")
  if (mean_col %in% colnames(dyad_profile) && sd_col %in% colnames(dyad_profile)) {
    outcome_tbl[[v]] <- sprintf("%.3f (%.3f)",
                                 dyad_profile[[mean_col]],
                                 dyad_profile[[sd_col]])
  }
}

names(outcome_tbl)[1:3] <- c("Cluster", "n (dyads)", "n (firms)")

doc <- doc %>%
  body_add_flextable(apa_table(as.data.frame(outcome_tbl),
    "Outcome Variable Means (SD) by Cluster")) %>%
  body_add_par("")

# --- Table 5: Multi-Group SEM Paths by Cluster (if available) ---
if (exists("key_paths") && !is.null(key_paths) && nrow(key_paths) > 0) {
  doc <- doc %>%
    body_add_par("Table 5: Multi-Group SEM — Key Path Coefficients by Cluster",
                 style = "heading 2")

  sem_tbl <- key_paths %>%
    mutate(
      est     = sprintf("%.3f", est),
      se      = sprintf("%.3f", se),
      pvalue  = ifelse(pvalue < .001, "< .001", sprintf("%.3f", pvalue)),
      std.all = sprintf("%.3f", std.all)
    ) %>%
    select(Cluster = group, Path = path, B = est, SE = se,
           p = pvalue, Beta = std.all, Sig = sig)

  doc <- doc %>%
    body_add_flextable(apa_table(as.data.frame(sem_tbl),
      "Structural Path Coefficients by Cluster (Configural Model)")) %>%
    body_add_par("")
}

# Write Word document
print(doc, target = word_path)
cat("Word tables saved:", word_path, "\n")

# Move charts to tables_path
for (png_file in c("cluster_resource_profiles.png",
                    "cluster_heatmap.png")) {
  src <- file.path(output_path, png_file)
  dst <- file.path(tables_path, paste0("14_", png_file))
  if (file.exists(src)) file.copy(src, dst, overwrite = TRUE)
}

# Copy outcome charts
outcome_pngs <- list.files(output_path, pattern = "^cluster_outcome_.*\\.png$",
                            full.names = TRUE)
for (src in outcome_pngs) {
  dst <- file.path(tables_path, paste0("14_", basename(src)))
  file.copy(src, dst, overwrite = TRUE)
}

cat("\nOutputs:\n")
cat("  CSVs: cluster_anova_results, cluster_pairwise_comparisons,\n")
cat("         cluster_dyad_profiles, multigroup_sem_by_cluster\n")
cat("  Word: 14_Cluster_Performance_APA.docx (Tables 1-5)\n")
cat("  Charts: 14_cluster_resource_profiles.png, 14_cluster_heatmap.png,\n")
cat("          14_cluster_outcome_*.png (copied to tables and charts)\n")

cat("\nFor Chapter IV 'Additional Exploratory Analysis', report:\n")
cat("  1. Cluster profiles (resource configuration typology)\n")
cat("  2. ANOVA/KW: do clusters differ on outcomes?\n")
cat("  3. Effect sizes and pairwise comparisons\n")
cat("  4. Multi-group SEM: does the model vary by cluster?\n")

cat("\n✓ Script 14 complete.\n")

# ============================================================================
# RESULTS LANGUAGE (Chapter IV — Additional Exploratory Analysis)
# ============================================================================
# "To further explore how distinct boundary resource configurations
# relate to international performance outcomes, we conducted a cluster-
# based analysis. Using the k-means cluster solution from the descriptive
# analysis (k = [4]; see Table [X]), we examined whether cluster
# membership predicted significant differences in platform accessibility
# and international performance (market share change).
#
# A [one-way ANOVA / Welch's ANOVA / Kruskal-Wallis test] revealed
# [significant / non-significant] differences in international
# performance across the [4] clusters, [F/H]([df]) = [X], p = [X],
# eta-squared = [X] ([small/medium/large] effect). Post-hoc [Games-Howell /
# Tukey HSD] comparisons indicated that [Cluster X] ('Full Ecosystem
# Builders') significantly outperformed [Cluster Y] ('API-First
# Minimalists') in market share change (mean difference = [X], p = [X]).
#
# A multi-group structural equation model tested whether the mediation
# paths varied across resource clusters. A chi-square difference test
# comparing the configural (free) and metric (constrained) models was
# [significant / non-significant] (Delta chi-sq = [X], Delta df = [X],
# p = [X]), [suggesting that the BR → EcoAccess → Performance pathway
# operates differently depending on the platform's resource configuration /
# indicating that the structural model is invariant across clusters]."
# ============================================================================
