# ============================================================================
# 03 - APPLY SAMPLE EXCLUSIONS → SAVE ANALYTIC SAMPLE
# ============================================================================
# Author: Heather Carle
# Purpose: Apply the Netherlands exclusion (missing IND_GROW) and save
#          MASTER_CODEBOOK_analytic.xlsx for all downstream scripts.
#
#          NOTE: Table 3 and Table 4 generation has been moved to
#          08_descriptive_statistics.R (Part A0) where it belongs with
#          the other sample description tables.
#
# Input:   MASTER_CODEBOOK_with_DV.xlsx (from scripts 01 & 02)
# Output:  MASTER_CODEBOOK_analytic.xlsx (REFERENCE/)
# Last Updated: February 2026
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"

codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_with_DV.xlsx")

tables_path <- file.path(base_path, "FINAL DISSERTATION",
                          "tables and charts")

# ============================================================================
# SECTION 3: LOAD AND APPLY SAMPLE EXCLUSIONS
# ============================================================================

cat("Loading MASTER_CODEBOOK_with_DV...\n")
mc <- read_excel(codebook_path)
cat("  Full dataset:", nrow(mc), "dyads,",
    n_distinct(mc$platform_ID), "unique platforms\n\n")

# ----- EXCLUSION: Drop dyads with missing IND_GROW -----
# These are 4 Netherlands Credit Card Transactions dyads where
# Euromonitor provides no industry growth data (reported as "-")

excluded <- mc %>% filter(is.na(IND_GROW))

cat("=== SAMPLE EXCLUSIONS ===\n")
cat("Dyads excluded (missing IND_GROW):", nrow(excluded), "\n")

if (nrow(excluded) > 0) {
  cat("\nExcluded dyads:\n")
  excluded %>%
    select(platform_ID, platform_name, host_country_name, IND) %>%
    print(n = 20)

  # Check if any firms are lost entirely
  excluded_pids <- unique(excluded$platform_ID)
  remaining_pids <- mc %>%
    filter(!is.na(IND_GROW)) %>%
    pull(platform_ID) %>%
    unique()

  firms_lost <- setdiff(excluded_pids, remaining_pids)
  cat("\nFirms lost entirely (only had excluded dyads):", length(firms_lost), "\n")
  if (length(firms_lost) > 0) {
    mc %>%
      filter(platform_ID %in% firms_lost) %>%
      distinct(platform_ID, platform_name, PLAT) %>%
      print()
  }
}

# Apply exclusion
mc_analytic <- mc %>% filter(!is.na(IND_GROW))

cat("\n=== ANALYTIC SAMPLE ===\n")
cat("Dyads:", nrow(mc_analytic), "\n")
cat("Unique platforms:", n_distinct(mc_analytic$platform_ID), "\n")
cat("Industries:", n_distinct(mc_analytic$IND), "\n")
cat("Countries:", n_distinct(mc_analytic$host_country_name), "\n\n")

# ============================================================================
# SECTION 4: SAVE ANALYTIC SAMPLE
# ============================================================================

# Save the analytic sample (with exclusions applied) for downstream scripts
analytic_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
write_xlsx(mc_analytic, analytic_path)

cat("\n✓ Analytic sample saved to:", analytic_path, "\n")
cat("  ", nrow(mc_analytic), "dyads,",
    n_distinct(mc_analytic$platform_ID), "unique platforms\n")
cat("  Downstream scripts (04+) should use this file.\n")
cat("  Table 3 & 4 generation is in 08_descriptive_statistics.R.\n")

cat("\n✓ Script 03 complete.\n")
