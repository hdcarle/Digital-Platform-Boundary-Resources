# ============================================================================
# 06 - COMPUTE COMPOSITE SCORES, Z-SCORES, AND MEDIATOR
# ============================================================================
# Author: Heather Carle
# Purpose: Compute 5 boundary resource category scores, Z-standardize them,
#          compute overall Platform Resources composite, and the Platform
#          Accessibility mediator variable. Also compute programming_lang_variety.
# Input:   MASTER_CODEBOOK_analytic.xlsx (from script 05, with resources populated)
# Output:  MASTER_CODEBOOK_analytic.xlsx (updated with composite scores)
# Last Updated: February 2026
#
# COMPOSITE FORMULA (from codebook Section 9.2):
#   Category score = (sum of detected resources in category) /
#                    (number of possible resources in category)
#   Z-scored across all platforms, then averaged:
#   Platform_Resources = (Za + Zd + Zai + Zs + Zg) / 5
#
# IMPORTANT:
#   - Z-scores are computed across PLAT firms only (N=242) since
#     non-platform firms are all zeros by definition
#   - But the z-score parameters (mean, sd) are saved so we can apply
#     them to the full 903 for the robustness check
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(writexl)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis REVISED")

# ============================================================================
# SECTION 3: LOAD DATA
# ============================================================================

cat("Loading analytic codebook...\n")
mc <- read_excel(codebook_path)
cat("  Rows:", nrow(mc), "  Columns:", ncol(mc), "\n\n")

# ============================================================================
# SECTION 4: DEFINE CATEGORY COMPOSITIONS
# ============================================================================

# Each category: which variables contribute, and their max possible values
# Binary vars contribute 0 or 1; count vars are capped or treated as-is

# APPLICATION RESOURCES
#   API (binary 0/1), METH (ordinal 0/1/2 → rescale to 0-1)
# DEVELOPMENT RESOURCES
#   DEVP (0/1), DOCS (0/1 presence), SDK (0/1 presence),
#   BUG (0/1), STAN (0/1)
# AI RESOURCES
#   AI_MODEL (0/1), AI_AGENT (0/1), AI_ASSIST (0/1),
#   AI_DATA (0/1), AI_MKT (0/1)
# SOCIAL RESOURCES
#   COM_forum, COM_blog, COM_help_support, COM_live_chat,
#   COM_Slack, COM_Discord, COM_stackoverflow, COM_training,
#   COM_FAQ, COM_social_media (10 binary → proportion),
#   GIT (0/1), MON (0/1),
#   SPAN_internal, SPAN_communities, SPAN_external (3 binary)
# GOVERNANCE RESOURCES
#   ROLE (0/1), DATA (0/1), STORE (0/1), CERT (0/1)

cat("=== COMPUTING CATEGORY RAW SCORES ===\n\n")

mc <- mc %>%
  mutate(
    # Ensure numeric
    across(c(API, METH, DEVP, DOCS, SDK, BUG, STAN,
             AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA, AI_MKT,
             COM_forum, COM_blog, COM_help_support, COM_live_chat,
             COM_Slack, COM_Discord, COM_stackoverflow, COM_training,
             COM_FAQ, COM_social_media,
             GIT, MON, SPAN_internal, SPAN_communities, SPAN_external,
             ROLE, DATA, STORE, CERT),
           ~as.numeric(.)),

    # APPLICATION: 2 indicators
    #   API (0/1) + METH rescaled (0/2 → 0/1)
    raw_application = (pmin(API, 1) + METH / 2) / 2,

    # DEVELOPMENT: 5 binary indicators
    raw_development = (pmin(DEVP, 1) + pmin(as.numeric(DOCS > 0), 1) +
                         pmin(as.numeric(SDK > 0), 1) + BUG + STAN) / 5,

    # AI: 5 binary indicators
    raw_ai = (AI_MODEL + AI_AGENT + AI_ASSIST + AI_DATA + AI_MKT) / 5,

    # SOCIAL: COM channels (10 binary → proportion) + GIT + MON + 3 SPAN
    #   Total 15 indicators
    raw_social = (COM_forum + COM_blog + COM_help_support + COM_live_chat +
                    COM_Slack + COM_Discord + COM_stackoverflow +
                    COM_training + COM_FAQ + COM_social_media +
                    GIT + MON +
                    SPAN_internal + SPAN_communities + SPAN_external) / 15,

    # GOVERNANCE: 4 binary indicators
    raw_governance = (ROLE + DATA + STORE + CERT) / 4
  )

# Quick check
cat("Raw category score ranges (PLAT firms only):\n")
mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  summarize(
    across(starts_with("raw_"), list(
      min = ~min(., na.rm = TRUE),
      mean = ~round(mean(., na.rm = TRUE), 3),
      max = ~max(., na.rm = TRUE)
    ))
  ) %>%
  pivot_longer(everything(),
               names_to = c("category", ".value"),
               names_pattern = "raw_(.+)_(.+)") %>%
  print()

# ============================================================================
# SECTION 5: Z-STANDARDIZE ACROSS PLAT FIRMS
# ============================================================================

cat("\n=== Z-STANDARDIZING CATEGORY SCORES ===\n")
cat("(Computed across 230 PLAT firms, then applied to all)\n\n")

# Get platform-level data (one row per platform)
plat_firms <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE)

cat("PLAT firms for Z-score computation:", nrow(plat_firms), "\n")

# Compute means and SDs from PLAT firms
z_params <- list()
raw_cols <- c("raw_application", "raw_development", "raw_ai",
              "raw_social", "raw_governance")

for (col in raw_cols) {
  z_params[[col]] <- list(
    mean = mean(plat_firms[[col]], na.rm = TRUE),
    sd   = sd(plat_firms[[col]], na.rm = TRUE)
  )
  cat(sprintf("  %s: mean=%.4f, sd=%.4f\n",
              col, z_params[[col]]$mean, z_params[[col]]$sd))
}

# Apply Z-standardization to ALL rows (using PLAT parameters)
mc <- mc %>%
  mutate(
    Z_application = (raw_application - z_params$raw_application$mean) /
      z_params$raw_application$sd,
    Z_development = (raw_development - z_params$raw_development$mean) /
      z_params$raw_development$sd,
    Z_ai = (raw_ai - z_params$raw_ai$mean) / z_params$raw_ai$sd,
    Z_social = (raw_social - z_params$raw_social$mean) /
      z_params$raw_social$sd,
    Z_governance = (raw_governance - z_params$raw_governance$mean) /
      z_params$raw_governance$sd
  )

# ============================================================================
# SECTION 6: PLATFORM RESOURCES COMPOSITE
# ============================================================================

mc <- mc %>%
  mutate(
    platform_resources = (Z_application + Z_development + Z_ai +
                            Z_social + Z_governance) / 5
  )

cat("\n=== PLATFORM RESOURCES COMPOSITE ===\n")
mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  pull(platform_resources) %>%
  summary() %>%
  print()

# ============================================================================
# SECTION 7: PLATFORM ACCESSIBILITY MEDIATOR
# ============================================================================

cat("\n=== COMPUTING PLATFORM ACCESSIBILITY ===\n\n")

# Two components:
#   1. Linguistic Variety  = count of distinct natural languages across 8 resource types
#   2. Programming Language Variety = union count across SDK, GIT, and BUG prog_lang_lists
#
# Both Z-scored (across PLAT firms), then averaged into a composite index.
#
# Methodological justification: When combining continuous measures of the same
# underlying construct on different scales, the arithmetic mean of z-scores
# provides a valid composite index. The geometric mean is an alternative but
# requires no zero values; 55% of platforms have zero programming languages,
# ruling it out here. Equal weighting treats both dimensions of accessibility
# as equally important.
# Reference: Gerstein, H.C. (2021). Creating composite indices from continuous
#   variables for research: The geometric mean. Diabetes Care, 44(5), 1135-1137.
#   DOI: 10.2337/dc20-2446

mc <- mc %>%
  mutate(
    LINGUISTIC_VARIETY = as.numeric(LINGUISTIC_VARIETY),
    programming_lang_variety = as.numeric(programming_lang_variety)
  )

# Z-score parameters from PLAT firms
lv_mean <- mean(plat_firms$LINGUISTIC_VARIETY, na.rm = TRUE)
lv_sd   <- sd(plat_firms$LINGUISTIC_VARIETY, na.rm = TRUE)
plv_mean <- mean(plat_firms$programming_lang_variety, na.rm = TRUE)
plv_sd   <- sd(plat_firms$programming_lang_variety, na.rm = TRUE)

cat(sprintf("  Linguistic Variety: mean=%.2f, sd=%.2f\n", lv_mean, lv_sd))
cat(sprintf("  Prog Lang Variety:  mean=%.2f, sd=%.2f\n", plv_mean, plv_sd))

mc <- mc %>%
  mutate(
    z_linguistic_variety = (LINGUISTIC_VARIETY - lv_mean) / lv_sd,
    z_programming_variety = (programming_lang_variety - plv_mean) / plv_sd,

    # Platform Accessibility = average of the two z-scored components
    platform_accessibility = (z_linguistic_variety + z_programming_variety) / 2
  )

cat("\nPlatform Accessibility distribution (PLAT firms):\n")
mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  pull(platform_accessibility) %>%
  summary() %>%
  print()

# ============================================================================
# SECTION 8: SAVE Z-SCORE PARAMETERS FOR ROBUSTNESS CHECK
# ============================================================================

# Save parameters so the full-901 robustness check uses the same
# standardization as the PLAT-only analysis
z_param_df <- tibble(
  variable = c(raw_cols,
               "LINGUISTIC_VARIETY", "programming_lang_variety"),
  mean = c(sapply(z_params, function(p) p$mean),
           lv_mean, plv_mean),
  sd = c(sapply(z_params, function(p) p$sd),
         lv_sd, plv_sd)
)

write.csv(z_param_df,
          file.path(output_path, "z_score_parameters.csv"),
          row.names = FALSE)
cat("\n  Z-score parameters saved to: z_score_parameters.csv\n")

# ============================================================================
# SECTION 9: DIAGNOSTICS
# ============================================================================

cat("\n=== COMPOSITE SCORE DIAGNOSTICS ===\n\n")

# Correlation matrix of category Z-scores (PLAT firms only)
plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE)

z_cols <- c("Z_application", "Z_development", "Z_ai",
            "Z_social", "Z_governance",
            "platform_resources", "platform_accessibility")

cat("Correlation matrix (PLAT firms, N=", nrow(plat_dyads), "):\n")
cor_mat <- cor(plat_dyads[, z_cols], use = "complete.obs")
print(round(cor_mat, 3))

# Cronbach's alpha for the 5-category composite
cat("\n--- Internal Consistency ---\n")
alpha_data <- plat_dyads %>% select(Z_application, Z_development, Z_ai,
                                      Z_social, Z_governance)
alpha_val <- (5 / 4) * (1 - sum(apply(alpha_data, 2, stats::var, na.rm = TRUE)) /
                            stats::var(rowSums(alpha_data, na.rm = TRUE), na.rm = TRUE))
cat("Cronbach's alpha (5 categories):", round(alpha_val, 3), "\n")

# By PLAT type
cat("\n--- Mean Composites by PLAT Type ---\n")
mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  group_by(PLAT) %>%
  summarize(
    n = n(),
    mean_PR  = round(mean(platform_resources, na.rm = TRUE), 3),
    sd_PR    = round(sd(platform_resources, na.rm = TRUE), 3),
    mean_PA  = round(mean(platform_accessibility, na.rm = TRUE), 3),
    sd_PA    = round(sd(platform_accessibility, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  print()

# ============================================================================
# SECTION 10: SAVE
# ============================================================================

write_xlsx(mc, codebook_path)
cat("\n✓ Saved updated codebook to:", codebook_path, "\n")
cat("  New columns: Z_application, Z_development, Z_ai, Z_social,\n")
cat("               Z_governance, platform_resources,\n")
cat("               z_linguistic_variety, z_programming_variety,\n")
cat("               platform_accessibility\n")

cat("\n✓ Script 06 complete.\n")
cat("  Next: Run 07 for cultural distance (if not already computed),\n")
cat("        then 08_descriptive_statistics.R\n")
