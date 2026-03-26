# ============================================================================
# 09 - PRE-ANALYSIS VALIDITY CHECKS
# ============================================================================
# Author: Heather Carle
# Purpose: Pre-analysis checks for Chapter IV "Validity" section:
#          Part A: Missing Data Analysis
#          Part B: Common Method Bias (Harman's Single-Factor Test)
#          Part C: Intra-Rater Reliability (Full 230 PLAT Dataset)
#
# Input:   MASTER_CODEBOOK_analytic.xlsx
#          Claude JSON results (for intra-rater: two coding runs)
# Output:  Missing data summary, CMB results, intra-rater table
# Last Updated: February 2026
#
# NOTE: Model-specific diagnostics (normality, heteroskedasticity, VIF,
#       outliers, Heckman selection) remain in 09_sem_moderated_mediation.R
#       Section 9-10. This script covers SAMPLE-LEVEL validity checks.
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(writexl)

# ============================================================================
# SECTION 2: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis REVISED")
tables_path <- file.path(base_path, "FINAL DISSERTATION",
                          "tables and charts REVISED")

mc <- read_excel(codebook_path)
cat("Loaded:", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "platforms\n\n")

# PLAT subset
plat_firms <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE)

cat("PLAT firms:", nrow(plat_firms), "\n\n")

# ============================================================================
# PART A: MISSING DATA ANALYSIS
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART A: MISSING DATA ANALYSIS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- A1: Variable-level missingness ---

# Define analysis variables split by measurement level
# Firm-level: constant within a platform_ID (BR vars, composites, PA subcomponents)
firm_level_vars <- c(
  # Mediator
  "platform_accessibility",
  # IV composites
  "platform_resources",
  "Z_application", "Z_development", "Z_ai", "Z_social", "Z_governance",
  # Individual BR variables (for completeness)
  "API", "METH", "DEVP", "DOCS", "SDK", "BUG", "STAN",
  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
  "COM_forum", "COM_blog", "COM_help_support", "COM_live_chat",
  "COM_Slack", "COM_Discord", "COM_stackoverflow", "COM_training",
  "COM_FAQ", "COM_social_media", "GIT", "MON",
  "SPAN_internal", "SPAN_communities", "SPAN_external",
  "ROLE", "DATA", "STORE", "CERT",
  # PA subcomponents (feed into platform_accessibility mediator)
  "LINGUISTIC_VARIETY", "programming_lang_variety"
)

# Dyad-level: varies across host countries within a platform_ID
dyad_level_vars <- c(
  # DV
  "MKT_SHARE_CHANGE",
  # Moderator (computed from home-host country pair)
  "cultural_distance",
  # Controls (vary by host or home country)
  "IND_GROW",
  "host_gdp_per_capita", "host_Internet_users",
  "home_gdp_per_capita"
)

# Combined for dyad-level check
analysis_vars <- c(firm_level_vars, dyad_level_vars)

# Check which analysis variables exist in the data
existing_vars <- intersect(analysis_vars, colnames(mc))
missing_from_data <- setdiff(analysis_vars, colnames(mc))

if (length(missing_from_data) > 0) {
  cat("WARNING: These analysis variables not found in data:\n")
  cat("  ", paste(missing_from_data, collapse = ", "), "\n\n")
}

# Compute missingness for each variable at both dyad and firm levels
missing_dyad <- mc %>%
  summarize(across(all_of(existing_vars),
                   list(
                     n_miss = ~sum(is.na(.)),
                     pct_miss = ~round(100 * mean(is.na(.)), 2)
                   ))) %>%
  pivot_longer(everything(),
               names_to = c("variable", ".value"),
               names_pattern = "(.+)_(n_miss|pct_miss)") %>%
  arrange(desc(pct_miss))

cat("--- Missing Data Summary (Dyad Level, N =", nrow(mc), ") ---\n")
# Only show variables with any missingness
missing_any <- missing_dyad %>% filter(n_miss > 0)
if (nrow(missing_any) == 0) {
  cat("  No missing values in any analysis variable.\n")
} else {
  print(missing_any, n = Inf)
}

# Firm-level missingness (only firm-level variables — dyad-level vars like
# cultural_distance, MKT_SHARE_CHANGE, controls vary by host country and
# are meaningless when checked on one arbitrary row per firm)
existing_firm_vars <- intersect(firm_level_vars, colnames(mc))
missing_firm <- plat_firms %>%
  summarize(across(all_of(existing_firm_vars),
                   list(
                     n_miss = ~sum(is.na(.)),
                     pct_miss = ~round(100 * mean(is.na(.)), 2)
                   ))) %>%
  pivot_longer(everything(),
               names_to = c("variable", ".value"),
               names_pattern = "(.+)_(n_miss|pct_miss)") %>%
  arrange(desc(pct_miss))

cat("\n--- Missing Data Summary (Firm Level, N =", nrow(plat_firms), ") ---\n")
missing_firm_any <- missing_firm %>% filter(n_miss > 0)
if (nrow(missing_firm_any) == 0) {
  cat("  No missing values in any analysis variable at firm level.\n")
} else {
  print(missing_firm_any, n = Inf)
}

# --- A2: Exclusion documentation ---
cat("\n--- Sample Exclusions Applied ---\n")
cat("  1. Netherlands Credit Card Transactions: 4 dyads dropped (missing IND_GROW)\n")
cat("     See script 03 for exclusion details.\n")
cat("  2. Cultural distance (Kogut-Singh): missing Hofstede dimension scores\n")
cat("     for home/host countries prevent CD calculation for some dyads.\n")
cat("     Countries missing entirely from Hofstede: ARE, BHR, QAT, KEN.\n")
cat("     Home countries with incomplete data: ISL, CYP, ARE.\n")
cat("     Host countries with incomplete data: UKR, ARE, ZAF, EGY, NGA, SAU, KEN.\n")
cat("     PLAT sample: 383 dyads, 3 platforms, 2 host countries lost\n")
cat("       (n=227 platforms; 88.4% dyads, 97.7% platforms retained).\n")
cat("     Full sample: 751 dyads, 13 firms lost, no host countries lost\n")
cat("       (n=888 firms; 88.6% dyads, 98.6% firms retained).\n")
cat("     See script 10 Section 11 for full details.\n")
cat("  SEM models use listwise deletion — dyads without CD are excluded.\n")
cat("  All other analysis variables are complete (no imputation needed).\n")

# --- A3: Complete cases for SEM ---
sem_vars <- c("platform_resources", "platform_accessibility",
              "MKT_SHARE_CHANGE", "cultural_distance",
              "IND_GROW",
              "host_gdp_per_capita", "host_Internet_users",
              "home_gdp_per_capita")
# Note: LINGUISTIC_VARIETY and programming_lang_variety are PA subcomponents
# already captured inside platform_accessibility — not listed separately here.

sem_vars_exist <- intersect(sem_vars, colnames(mc))
plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

n_complete <- plat_dyads %>%
  select(all_of(sem_vars_exist)) %>%
  complete.cases() %>%
  sum()

cat("\n--- Complete Cases for SEM ---\n")
cat("  PLAT dyads:", nrow(plat_dyads), "\n")
cat("  Complete cases:", n_complete, "\n")
cat("  Listwise deletion loss:", nrow(plat_dyads) - n_complete, "dyads\n")

# Save missing data report
write.csv(missing_dyad,
          file.path(output_path, "missing_data_report.csv"),
          row.names = FALSE)

cat("\n✓ Part A complete. Missing data report saved.\n\n")

# ============================================================================
# PART B: COMMON METHOD BIAS — HARMAN'S SINGLE-FACTOR TEST
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART B: COMMON METHOD BIAS (HARMAN'S SINGLE-FACTOR TEST)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Rationale: All boundary resource IVs were coded from the same source
# (AI agent reading developer portals). If a single factor explains >50%
# of variance, common method bias may be present.

# Use all 33 individual BR indicator variables (before compositing)
br_vars <- c(
  # Application
  "API", "METH",
  # Development
  "DEVP", "DOCS", "SDK", "BUG", "STAN",
  # AI Integration
  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
  # Social/Community
  "COM_forum", "COM_blog", "COM_help_support", "COM_live_chat",
  "COM_Slack", "COM_Discord", "COM_stackoverflow", "COM_training",
  "COM_FAQ", "COM_social_media",
  "GIT", "MON",
  "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
  "EVENT_conference", "EVENT_hackathon", "EVENT_other",
  "SPAN_internal", "SPAN_communities", "SPAN_external",
  # Governance
  "ROLE", "DATA", "STORE", "CERT"
)

br_exist <- intersect(br_vars, colnames(plat_firms))

cat("Variables included in Harman's test:", length(br_exist), "\n")
cat("Firms:", nrow(plat_firms), "\n\n")

# Run unrotated PCA on the BR indicators
br_matrix <- plat_firms %>%
  select(all_of(br_exist)) %>%
  mutate(across(everything(), as.numeric))

# Remove zero-variance columns (if any)
col_vars <- apply(br_matrix, 2, stats::var, na.rm = TRUE)
zero_var <- names(col_vars[col_vars == 0 | is.na(col_vars)])
if (length(zero_var) > 0) {
  cat("WARNING: Removing zero-variance columns:", paste(zero_var, collapse = ", "), "\n")
  br_matrix <- br_matrix %>% select(-all_of(zero_var))
}

# Complete cases only
br_complete <- br_matrix[complete.cases(br_matrix), ]
cat("Complete cases for PCA:", nrow(br_complete), "\n\n")

# Unrotated PCA (Harman's test uses unrotated solution)
pca_harman <- prcomp(br_complete, center = TRUE, scale. = TRUE)

# Extract eigenvalues and variance explained
eigenvalues <- pca_harman$sdev^2
var_explained <- eigenvalues / sum(eigenvalues)
cum_var <- cumsum(var_explained)

# Harman's criterion: first factor < 50% = no CMB concern
first_factor_pct <- round(100 * var_explained[1], 2)

cat("=== HARMAN'S SINGLE-FACTOR TEST RESULTS ===\n\n")
cat("First (unrotated) component explains:", first_factor_pct, "% of variance\n")
cat("Threshold for concern: > 50%\n\n")

if (first_factor_pct > 50) {
  cat("⚠ WARNING: First factor exceeds 50%. Common method bias may be present.\n")
  cat("  Consider additional remedies (marker variable, CFA approach).\n")
} else {
  cat("✓ First factor is below 50%. No evidence of common method bias.\n")
  cat("  Result supports that a single common factor does not account for\n")
  cat("  the majority of variance in the boundary resource indicators.\n")
}

# Show first 10 components
cat("\nComponent variance explained (first 10):\n")
harman_table <- tibble(
  Component = 1:min(10, length(eigenvalues)),
  Eigenvalue = round(eigenvalues[1:min(10, length(eigenvalues))], 3),
  Pct_Variance = round(100 * var_explained[1:min(10, length(eigenvalues))], 2),
  Cumulative_Pct = round(100 * cum_var[1:min(10, length(eigenvalues))], 2)
)
print(harman_table, n = Inf)

# Save
write.csv(harman_table,
          file.path(output_path, "harmans_test_results.csv"),
          row.names = FALSE)

cat("\n✓ Part B complete. Harman's test saved.\n\n")

# ============================================================================
# PART C: INTRA-RATER RELIABILITY (FULL 230 PLAT FIRMS)
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART C: INTRA-RATER RELIABILITY (CODING STABILITY)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Rationale: To assess temporal stability of the AI coder, the same
# Claude model was run TWICE on all 230 PLAT firms. This section
# compares Run 1 vs Run 2 to compute intra-rater agreement.
#
# This uses the FULL 230 PLAT dataset (not the 16-platform IRR subset).
# If only one run exists, we report that and flag it as a TODO.

# --- C1: Check for dual-run data ---
# Look for two sets of Claude results (Run 1 = primary, Run 2 = retest)
claude_dir_1 <- file.path(base_path, "dissertation_batch_api", "claude_results")
claude_dir_2 <- file.path(base_path, "dissertation_batch_api", "claude_results_run2")

run1_exists <- dir.exists(claude_dir_1)
run2_exists <- dir.exists(claude_dir_2)

cat("Run 1 directory:", claude_dir_1, "→", ifelse(run1_exists, "EXISTS", "NOT FOUND"), "\n")
cat("Run 2 directory:", claude_dir_2, "→", ifelse(run2_exists, "EXISTS", "NOT FOUND"), "\n\n")

if (!run1_exists || !run2_exists) {
  cat("⚠ Intra-rater analysis requires TWO coding runs.\n")
  cat("  To complete this analysis:\n")
  cat("  1. Run the Claude coder a second time on all 230 PLAT firms\n")
  cat("  2. Save results to:", claude_dir_2, "\n")
  cat("  3. Re-run this script\n\n")
  cat("  Alternatively, if the second run is stored elsewhere, update\n")
  cat("  the 'claude_dir_2' path above.\n\n")

  # If we can't do dual-run, attempt a split-half approach as fallback
  cat("--- FALLBACK: Internal Consistency (Split-Half) ---\n\n")
  cat("As an alternative measure of measurement reliability, we compute\n")
  cat("Cronbach's alpha for each of the 5 boundary resource categories.\n\n")

  if (requireNamespace("psych", quietly = TRUE)) {
    library(psych)

    # Application resources
    app_items <- plat_firms %>%
      select(any_of(c("API", "METH"))) %>%
      mutate(across(everything(), as.numeric))

    # Development resources
    dev_items <- plat_firms %>%
      select(any_of(c("DEVP", "DOCS", "SDK", "BUG", "STAN"))) %>%
      mutate(across(everything(), as.numeric))

    # AI resources
    ai_items <- plat_firms %>%
      select(any_of(c("AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT"))) %>%
      mutate(across(everything(), as.numeric))

    # Social resources
    soc_items <- plat_firms %>%
      select(any_of(c("COM_forum", "COM_blog", "COM_help_support",
                       "COM_live_chat", "COM_Slack", "COM_Discord",
                       "COM_stackoverflow", "COM_training", "COM_FAQ",
                       "COM_social_media", "GIT", "MON",
                       "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
                       "EVENT_conference", "EVENT_hackathon", "EVENT_other",
                       "SPAN_internal", "SPAN_communities", "SPAN_external"))) %>%
      mutate(across(everything(), as.numeric))

    # Governance resources
    gov_items <- plat_firms %>%
      select(any_of(c("ROLE", "DATA", "STORE", "CERT"))) %>%
      mutate(across(everything(), as.numeric))

    categories <- list(
      Application = app_items,
      Development = dev_items,
      `AI Integration` = ai_items,
      `Social/Community` = soc_items,
      Governance  = gov_items
    )

    alpha_results <- tibble(
      Category = character(),
      N_Items  = integer(),
      Alpha    = numeric(),
      Interpretation = character()
    )

    for (cat_name in names(categories)) {
      cat_data <- categories[[cat_name]]
      n_items <- ncol(cat_data)

      if (n_items < 2) {
        cat(sprintf("  %s: Only %d item — alpha not applicable\n",
                    cat_name, n_items))
        alpha_results <- bind_rows(alpha_results, tibble(
          Category = cat_name, N_Items = n_items,
          Alpha = NA_real_, Interpretation = "< 2 items"
        ))
        next
      }

      # Suppress psych alpha warnings about low item count
      a <- tryCatch(
        suppressWarnings(psych::alpha(cat_data, check.keys = TRUE)),
        error = function(e) NULL
      )

      if (!is.null(a)) {
        alpha_val <- round(a$total$raw_alpha, 3)
        interp <- case_when(
          alpha_val >= 0.9 ~ "Excellent",
          alpha_val >= 0.8 ~ "Good",
          alpha_val >= 0.7 ~ "Acceptable",
          alpha_val >= 0.6 ~ "Questionable",
          alpha_val >= 0.5 ~ "Poor",
          TRUE             ~ "Unacceptable"
        )
        cat(sprintf("  %s: α = %.3f (%s), %d items\n",
                    cat_name, alpha_val, interp, n_items))
        alpha_results <- bind_rows(alpha_results, tibble(
          Category = cat_name, N_Items = n_items,
          Alpha = alpha_val, Interpretation = interp
        ))
      } else {
        cat(sprintf("  %s: Alpha computation failed\n", cat_name))
        alpha_results <- bind_rows(alpha_results, tibble(
          Category = cat_name, N_Items = n_items,
          Alpha = NA_real_, Interpretation = "Computation failed"
        ))
      }
    }

    cat("\n")
    print(alpha_results, n = Inf)

    write.csv(alpha_results,
              file.path(output_path, "internal_consistency_alpha.csv"),
              row.names = FALSE)

    cat("\n✓ Internal consistency (Cronbach's alpha) saved.\n")
    cat("  NOTE: This supplements but does not replace intra-rater reliability.\n")
    cat("  Full intra-rater analysis requires a second coding run.\n")

  } else {
    cat("  psych package not available. Install with: install.packages('psych')\n")
  }

} else {
  # --- C2: Load and compare two coding runs ---
  cat("Both runs found. Computing intra-rater agreement...\n\n")

  library(jsonlite)
  library(irr)   # kappa2, kripp.alpha
  library(psych)  # ICC

  # Define variables to compare (same as in calculate_irr.R)
  binary_vars <- c(
    "DEVP", "DOCS", "SDK", "BUG", "STAN",
    "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
    "GIT", "MON", "API",
    "ROLE", "DATA", "STORE", "CERT",
    "COM_social_media", "COM_forum", "COM_blog", "COM_help_support",
    "COM_live_chat", "COM_Slack", "COM_Discord", "COM_stackoverflow",
    "COM_training", "COM_FAQ",
    "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
    "EVENT_conference", "EVENT_hackathon", "EVENT_other",
    "SPAN_internal", "SPAN_communities", "SPAN_external"
  )

  count_vars <- c(
    "METH",
    "SDK_lang", "COM_lang", "GIT_lang", "SPAN_lang",
    "ROLE_lang", "DATA_lang", "STORE_lang", "CERT_lang",
    "SDK_prog_lang"
  )

  all_vars <- c(binary_vars, count_vars)

  # Helper: extract variables from a JSON file
  extract_from_json <- function(json_path, vars) {
    j <- fromJSON(json_path, flatten = TRUE)
    result <- setNames(rep(NA_real_, length(vars)), vars)

    # Try extracting from nested category structure
    for (cat_name in c("application", "development", "ai", "social", "governance")) {
      if (!is.null(j[[cat_name]]) && is.list(j[[cat_name]])) {
        for (v in vars) {
          if (v %in% names(j[[cat_name]])) {
            val <- j[[cat_name]][[v]]
            result[v] <- as.numeric(val %||% NA)
          }
        }
      }
    }

    # Also check top-level
    for (v in vars) {
      if (is.na(result[v]) && v %in% names(j)) {
        result[v] <- as.numeric(j[[v]] %||% NA)
      }
    }

    return(result)
  }

  # Get PLAT platform IDs
  plat_ids <- plat_firms$platform_ID

  # Load Run 1 and Run 2
  run1_data <- list()
  run2_data <- list()

  for (pid in plat_ids) {
    f1 <- file.path(claude_dir_1, paste0(pid, ".json"))
    f2 <- file.path(claude_dir_2, paste0(pid, ".json"))

    if (file.exists(f1) && file.exists(f2)) {
      run1_data[[pid]] <- extract_from_json(f1, all_vars)
      run2_data[[pid]] <- extract_from_json(f2, all_vars)
    }
  }

  n_paired <- length(run1_data)
  cat("Paired observations (both runs):", n_paired, "of", length(plat_ids), "PLAT firms\n\n")

  if (n_paired < 10) {
    cat("⚠ Too few paired observations for reliable intra-rater analysis.\n")
    cat("  Need at least 10. Found:", n_paired, "\n")
  } else {
    # Build comparison matrices
    run1_df <- bind_rows(run1_data) %>% mutate(platform_ID = names(run1_data))
    run2_df <- bind_rows(run2_data) %>% mutate(platform_ID = names(run2_data))

    # Compute intra-rater agreement per variable
    intra_results <- tibble(
      Variable   = character(),
      Type       = character(),
      N          = integer(),
      Agreement  = numeric(),
      Kappa      = numeric(),
      ICC        = numeric(),
      Category   = character()
    )

    # Map variables to categories
    var_categories <- c(
      API = "Application", METH = "Application",
      DEVP = "Development", DOCS = "Development", SDK = "Development",
      BUG = "Development", STAN = "Development",
      AI_MODEL = "AI Integration", AI_AGENT = "AI Integration",
      AI_ASSIST = "AI Integration", AI_DATA = "AI Integration",
      AI_MKT = "AI Integration",
      COM_forum = "Social/Community", COM_blog = "Social/Community",
      COM_help_support = "Social/Community", COM_live_chat = "Social/Community",
      COM_Slack = "Social/Community", COM_Discord = "Social/Community",
      COM_stackoverflow = "Social/Community", COM_training = "Social/Community",
      COM_FAQ = "Social/Community", COM_social_media = "Social/Community",
      GIT = "Social/Community", MON = "Social/Community",
      EVENT_webinars = "Social/Community", EVENT_virtual = "Social/Community",
      EVENT_in_person = "Social/Community", EVENT_conference = "Social/Community",
      EVENT_hackathon = "Social/Community", EVENT_other = "Social/Community",
      SPAN_internal = "Social/Community", SPAN_communities = "Social/Community",
      SPAN_external = "Social/Community",
      ROLE = "Governance", DATA = "Governance", STORE = "Governance",
      CERT = "Governance",
      SDK_lang = "Development", COM_lang = "Social/Community",
      GIT_lang = "Social/Community", SPAN_lang = "Social/Community",
      ROLE_lang = "Governance", DATA_lang = "Governance",
      STORE_lang = "Governance", CERT_lang = "Governance",
      SDK_prog_lang = "Development"
    )

    for (v in all_vars) {
      r1 <- run1_df[[v]]
      r2 <- run2_df[[v]]

      # Skip if all NA
      valid <- !is.na(r1) & !is.na(r2)
      n_valid <- sum(valid)
      if (n_valid < 5) next

      r1v <- r1[valid]
      r2v <- r2[valid]

      # Percent agreement
      agree_pct <- round(100 * mean(r1v == r2v), 1)

      # Cohen's kappa (for binary)
      kappa_val <- NA_real_
      icc_val <- NA_real_

      if (v %in% binary_vars) {
        k <- tryCatch(
          kappa2(cbind(r1v, r2v), weight = "unweighted"),
          error = function(e) NULL
        )
        if (!is.null(k)) kappa_val <- round(k$value, 3)
      }

      # ICC (for count vars, or all vars)
      icc_res <- tryCatch(
        ICC(cbind(r1v, r2v), missing = FALSE),
        error = function(e) NULL
      )
      if (!is.null(icc_res)) {
        icc_val <- round(icc_res$results$ICC[3], 3)  # ICC(3,1) = two-way mixed, consistency
      }

      intra_results <- bind_rows(intra_results, tibble(
        Variable  = v,
        Type      = ifelse(v %in% binary_vars, "Binary", "Count"),
        N         = n_valid,
        Agreement = agree_pct,
        Kappa     = kappa_val,
        ICC       = icc_val,
        Category  = var_categories[v] %||% "Other"
      ))
    }

    # Print results
    cat("=== INTRA-RATER RELIABILITY (Run 1 vs Run 2) ===\n\n")
    cat("N =", n_paired, "PLAT firms coded twice by same Claude model\n\n")

    # By category summary
    cat("--- Summary by Category ---\n")
    cat_summary <- intra_results %>%
      group_by(Category) %>%
      summarize(
        N_Vars = n(),
        Mean_Agreement = round(mean(Agreement, na.rm = TRUE), 1),
        Mean_Kappa = round(mean(Kappa, na.rm = TRUE), 3),
        Mean_ICC = round(mean(ICC, na.rm = TRUE), 3),
        .groups = "drop"
      )
    print(cat_summary, n = Inf)

    # Overall
    cat("\n--- Overall ---\n")
    cat(sprintf("  Mean agreement: %.1f%%\n",
                mean(intra_results$Agreement, na.rm = TRUE)))
    cat(sprintf("  Mean kappa (binary): %.3f\n",
                mean(intra_results$Kappa, na.rm = TRUE)))
    cat(sprintf("  Mean ICC: %.3f\n",
                mean(intra_results$ICC, na.rm = TRUE)))

    # Full table
    cat("\n--- Variable-Level Results ---\n")
    print(intra_results %>% arrange(Category, Variable), n = Inf)

    # Save
    write.csv(intra_results,
              file.path(output_path, "intra_rater_reliability.csv"),
              row.names = FALSE)
    write.csv(cat_summary,
              file.path(output_path, "intra_rater_by_category.csv"),
              row.names = FALSE)

    cat("\n✓ Intra-rater reliability saved.\n")
  }
}

# ============================================================================
# SECTION FINAL: APA WORD TABLE EXPORTS
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SECTION FINAL: EXPORTING APA WORD TABLES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

library(flextable)
library(officer)

val_doc <- read_docx()

# --- Table 1: Missing Data Summary (Dyad Level) ---
val_doc <- body_add_par(val_doc,
  "Table 1. Missing Data Analysis — Dyad Level",
  style = "heading 2")

miss_tbl <- missing_dyad %>%
  rename(Variable = variable,
         `N Missing` = n_miss,
         `% Missing` = pct_miss)

ft_miss <- flextable(miss_tbl) %>%
  colformat_double(digits = 2) %>%
  set_header_labels(Variable = "Variable",
                    `N Missing` = "N Missing",
                    `% Missing` = "% Missing") %>%
  theme_apa() %>%
  autofit()

val_doc <- body_add_flextable(val_doc, ft_miss)
val_doc <- body_add_par(val_doc, "")
cat("  Table 1: Missing data (dyad level) added.\n")

# --- Table 2: Missing Data Summary (Firm Level) ---
val_doc <- body_add_par(val_doc,
  "Table 2. Missing Data Analysis — Firm Level (PLAT Firms Only)",
  style = "heading 2")

miss_firm_tbl <- missing_firm %>%
  rename(Variable = variable,
         `N Missing` = n_miss,
         `% Missing` = pct_miss)

ft_miss_firm <- flextable(miss_firm_tbl) %>%
  colformat_double(digits = 2) %>%
  theme_apa() %>%
  autofit()

val_doc <- body_add_flextable(val_doc, ft_miss_firm)
val_doc <- body_add_par(val_doc, "")
cat("  Table 2: Missing data (firm level) added.\n")

# --- Table 3: Harman's Single-Factor Test ---
val_doc <- body_add_par(val_doc,
  "Table 3. Common Method Bias — Harman's Single-Factor Test",
  style = "heading 2")

val_doc <- body_add_par(val_doc, sprintf(
  "First unrotated component explains %.2f%% of variance (threshold: 50%%).",
  first_factor_pct))
val_doc <- body_add_par(val_doc, "")

ft_harman <- flextable(harman_table) %>%
  colformat_double(j = "Eigenvalue", digits = 3) %>%
  colformat_double(j = "Pct_Variance", digits = 2) %>%
  colformat_double(j = "Cumulative_Pct", digits = 2) %>%
  set_header_labels(
    Component = "Component",
    Eigenvalue = "Eigenvalue",
    Pct_Variance = "% Variance",
    Cumulative_Pct = "Cumulative %"
  ) %>%
  theme_apa() %>%
  autofit()

val_doc <- body_add_flextable(val_doc, ft_harman)
val_doc <- body_add_par(val_doc, "")
cat("  Table 3: Harman's test added.\n")

# --- Table 4: Internal Consistency OR Intra-Rater Reliability ---
if (exists("alpha_results")) {
  # Cronbach's alpha fallback
  val_doc <- body_add_par(val_doc,
    "Table 4. Internal Consistency — Cronbach's Alpha by Resource Category",
    style = "heading 2")

  ft_alpha <- flextable(alpha_results) %>%
    colformat_double(j = "Alpha", digits = 3) %>%
    set_header_labels(
      Category = "Resource Category",
      N_Items = "N Items",
      Alpha = "Cronbach's α",
      Interpretation = "Interpretation"
    ) %>%
    theme_apa() %>%
    autofit()

  val_doc <- body_add_flextable(val_doc, ft_alpha)
  val_doc <- body_add_par(val_doc, "")
  cat("  Table 4: Cronbach's alpha added.\n")
}

if (exists("intra_results")) {
  # Full intra-rater results
  val_doc <- body_add_par(val_doc,
    "Table 4. Intra-Rater Reliability — Category Summary",
    style = "heading 2")

  ft_intra_cat <- flextable(cat_summary) %>%
    colformat_double(digits = 3) %>%
    set_header_labels(
      Category = "Resource Category",
      N_Vars = "N Variables",
      Mean_Agreement = "Mean % Agreement",
      Mean_Kappa = "Mean κ",
      Mean_ICC = "Mean ICC(3,1)"
    ) %>%
    theme_apa() %>%
    autofit()

  val_doc <- body_add_flextable(val_doc, ft_intra_cat)
  val_doc <- body_add_par(val_doc, "")

  # Variable-level detail
  val_doc <- body_add_par(val_doc,
    "Table 5. Intra-Rater Reliability — Variable-Level Detail",
    style = "heading 2")

  intra_sorted <- intra_results %>% arrange(Category, Variable)
  ft_intra_var <- flextable(intra_sorted) %>%
    colformat_double(j = "Agreement", digits = 1) %>%
    colformat_double(j = "Kappa", digits = 3) %>%
    colformat_double(j = "ICC", digits = 3) %>%
    set_header_labels(
      Variable = "Variable",
      Type = "Type",
      N = "N",
      Agreement = "% Agreement",
      Kappa = "Cohen's κ",
      ICC = "ICC(3,1)",
      Category = "Category"
    ) %>%
    theme_apa() %>%
    autofit()

  val_doc <- body_add_flextable(val_doc, ft_intra_var)
  val_doc <- body_add_par(val_doc, "")
  cat("  Tables 4-5: Intra-rater reliability added.\n")
}

# --- Table: Complete Cases for SEM ---
val_doc <- body_add_par(val_doc,
  "Table. Complete Cases Summary for SEM Analysis",
  style = "heading 2")

sem_summary <- tibble(
  Metric = c("Total PLAT dyads", "Complete cases (all SEM variables)",
             "Listwise deletion loss"),
  N = c(nrow(plat_dyads), n_complete, nrow(plat_dyads) - n_complete)
)

ft_sem <- flextable(sem_summary) %>%
  theme_apa() %>%
  autofit()

val_doc <- body_add_flextable(val_doc, ft_sem)
val_doc <- body_add_par(val_doc, "")
cat("  Complete cases table added.\n")

# Save Word document
val_word_path <- file.path(tables_path, "09_Validity_Tables_APA.docx")
print(val_doc, target = val_word_path)
cat("\n✓ All validity tables saved to:", val_word_path, "\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SCRIPT 09 COMPLETE — PRE-ANALYSIS VALIDITY CHECKS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("Outputs:\n")
cat("  missing_data_report.csv\n")
cat("  harmans_test_results.csv\n")
cat("  intra_rater_reliability.csv (if dual-run data available)\n")
cat("  internal_consistency_alpha.csv (fallback if single run)\n")
cat("  09_Validity_Tables_APA.docx (Word tables)\n")
cat("\n")
cat("For Chapter IV 'Validity' section, report:\n")
cat("  1. Missing data: Complete dataset after NL exclusion (script 03)\n")
cat("  2. CMB: Harman's single-factor test (first factor < 50%)\n")
cat("  3. Intra-rater: Temporal stability of AI coding\n")
cat("  4. Model diagnostics: See script 11, Sections 9-10\n")
cat("     (Normality, heteroskedasticity, VIF, outliers, Heckman)\n")

cat("\n✓ Script 09 complete.\n")

# ============================================================================
# METHODS SECTION LANGUAGE
# ============================================================================
# "We conducted several pre-analysis validity checks. First, we examined
# missing data patterns across all analysis variables. After excluding
# four dyads with unavailable industry growth data for the Netherlands
# Credit Card Transactions segment (see Sample section), all firm-level
# boundary resource variables were complete. Cultural distance scores
# could not be computed for dyads involving countries missing from the
# Hofstede index (ARE, BHR, QAT, KEN) or with incomplete dimension
# data (see Table [X]). In the platform sample, this resulted in the
# exclusion of 383 dyads across 3 platform firms, retaining 227
# platforms (97.7%) and 88.4% of dyads. No imputation was performed;
# affected dyads were excluded via listwise deletion.
#
# Second, we assessed common method bias using Harman's single-factor
# test (Podsakoff et al., 2003), as all boundary resource indicators
# were coded from the same source (developer portal pages). An unrotated
# principal component analysis of the [N] boundary resource indicators
# revealed that the first factor explained [X]% of the total variance,
# well below the 50% threshold, suggesting that common method bias does
# not pose a significant concern.
#
# Third, to assess the temporal stability of the AI coding instrument,
# we re-coded all [N] platform developer portals using the same Claude
# model and prompt configuration. Intra-rater agreement averaged [X]%
# across [N] variables, with a mean Cohen's kappa of [X] for binary
# indicators and an average ICC(3,1) of [X] for count variables,
# indicating [excellent/good/acceptable] coding stability."
# ============================================================================
