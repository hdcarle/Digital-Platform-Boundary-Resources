# ============================================================================
# 08 - DESCRIPTIVE STATISTICS & SAMPLE TABLES
# ============================================================================
# Author: Heather Carle
# Purpose: Generate sample description tables (Table 3, Table 4) and
#          comprehensive descriptive statistics at both the firm level
#          and dyad level, organized by Industry, Country/Region,
#          and Platform Type. Produces APA-formatted summary tables.
# Input:   MASTER_CODEBOOK_analytic.xlsx (with all composites computed)
# Output:  Table 3 & 4 data, descriptive tables, cluster assignments
# Last Updated: February 2026
#
# ANALYSIS STRUCTURE:
#   Part A0: Table 3 & 4 (Sample Description)
#   Part A:  Firm-level descriptives (N=230 PLAT, N=901 all)
#   Part B:  Dyad-level descriptives (N=~6,613 dyads)
#   Part C:  By Industry
#   Part D:  By Region/Country
#   Part E:  By PLAT Type (PUBLIC/REGISTRATION/RESTRICTED)
#   Part F:  Correlation matrix for SEM variables
#   Part G:  Cluster analysis for resource-based platform typology
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)
library(ggplot2)

# ============================================================================
# SECTION 2: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis")
tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

mc <- read_excel(codebook_path)
cat("Loaded:", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "platforms\n\n")

# Create firm-level dataset (one row per platform)
firms <- mc %>%
  distinct(platform_ID, .keep_all = TRUE)

# PLAT subset
plat_firms <- firms %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

cat("Firm-level: ", nrow(firms), "total,", nrow(plat_firms), "PLAT\n")
cat("Dyad-level: ", nrow(mc), "total,", nrow(plat_dyads), "PLAT\n\n")

# ============================================================================
# PART A0: TABLE 3 & TABLE 4 (SAMPLE DESCRIPTION)
# ============================================================================
# These tables were previously in script 03. Moved here because they are
# sample description tables that belong with descriptive statistics.
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART A0: TABLE 3 & TABLE 4 (SAMPLE DESCRIPTION)\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- TABLE 3: Platform Classification of Firms by Industry ---
cat("=== TABLE 3 ===\n\n")

table3 <- mc %>%
  group_by(IND) %>%
  summarize(
    total_firms   = n_distinct(platform_ID),
    non_platform  = n_distinct(platform_ID[PLAT == "NONE"]),
    public        = n_distinct(platform_ID[PLAT == "PUBLIC"]),
    registration  = n_distinct(platform_ID[PLAT == "REGISTRATION"]),
    restricted    = n_distinct(platform_ID[PLAT == "RESTRICTED"]),
    countries     = n_distinct(host_country_name),
    dyads         = n(),
    .groups = "drop"
  ) %>%
  mutate(
    total_platform = public + registration + restricted,
    pct_platform   = round(100 * total_platform / total_firms, 1)
  ) %>%
  select(IND, total_firms, non_platform, public, registration, restricted,
         total_platform, pct_platform, countries, dyads) %>%
  arrange(IND)

# Add totals row
totals <- tibble(
  IND            = "Total",
  total_firms    = n_distinct(mc$platform_ID),
  non_platform   = n_distinct(mc$platform_ID[mc$PLAT == "NONE"]),
  public         = n_distinct(mc$platform_ID[mc$PLAT == "PUBLIC"]),
  registration   = n_distinct(mc$platform_ID[mc$PLAT == "REGISTRATION"]),
  restricted     = n_distinct(mc$platform_ID[mc$PLAT == "RESTRICTED"]),
  total_platform = n_distinct(mc$platform_ID[mc$PLAT != "NONE"]),
  pct_platform   = round(100 * n_distinct(mc$platform_ID[mc$PLAT != "NONE"]) /
                          n_distinct(mc$platform_ID), 1),
  countries      = n_distinct(mc$host_country_name),
  dyads          = nrow(mc)
)

table3_full <- bind_rows(table3, totals)

# Print formatted
cat("Table 3: Platform Classification of Firms by Industry\n")
cat(str_pad("Industry", 42), str_pad("Firms", 7, "left"),
    str_pad("Non-Pl", 8, "left"), str_pad("Public", 8, "left"),
    str_pad("Reg.", 6, "left"), str_pad("Rest.", 7, "left"),
    str_pad("Tot Pl", 8, "left"), str_pad("% Pl", 7, "left"),
    str_pad("Ctry", 6, "left"), str_pad("Dyads", 7, "left"), "\n")
cat(strrep("-", 100), "\n")

for (i in seq_len(nrow(table3_full))) {
  row <- table3_full[i, ]
  if (row$IND == "Total") cat(strrep("-", 100), "\n")
  cat(str_pad(row$IND, 42),
      str_pad(as.character(row$total_firms), 7, "left"),
      str_pad(as.character(row$non_platform), 8, "left"),
      str_pad(as.character(row$public), 8, "left"),
      str_pad(as.character(row$registration), 6, "left"),
      str_pad(as.character(row$restricted), 7, "left"),
      str_pad(as.character(row$total_platform), 8, "left"),
      str_pad(paste0(row$pct_platform, "%"), 7, "left"),
      str_pad(as.character(row$countries), 6, "left"),
      str_pad(as.character(row$dyads), 7, "left"), "\n")
}

# --- TABLE 4: Unique Platform Firms by Access Classification ---
cat("\n=== TABLE 4 ===\n\n")

table4 <- tibble(
  Classification = c("Public", "Registration", "Restricted",
                      "Total Platform Firms",
                      "Non-Platform Firms",
                      "Total Unique Firms"),
  Count = c(
    n_distinct(mc$platform_ID[mc$PLAT == "PUBLIC"]),
    n_distinct(mc$platform_ID[mc$PLAT == "REGISTRATION"]),
    n_distinct(mc$platform_ID[mc$PLAT == "RESTRICTED"]),
    n_distinct(mc$platform_ID[mc$PLAT != "NONE"]),
    n_distinct(mc$platform_ID[mc$PLAT == "NONE"]),
    n_distinct(mc$platform_ID)
  )
)

cat("Table 4: Unique Platform Firms by Access Classification\n")
cat(str_pad("Classification", 30), str_pad("Count", 8, "left"), "\n")
cat(strrep("-", 38), "\n")
for (i in seq_len(nrow(table4))) {
  row <- table4[i, ]
  if (row$Classification %in% c("Total Platform Firms", "Total Unique Firms")) {
    cat(str_pad(row$Classification, 30),
        str_pad(as.character(row$Count), 8, "left"), " **\n")
  } else {
    cat("  ", str_pad(row$Classification, 28),
        str_pad(as.character(row$Count), 8, "left"), "\n")
  }
}

# --- Table Notes ---
n_unique_firms <- n_distinct(mc$platform_ID)
n_countries <- n_distinct(mc$host_country_name)
n_dyads <- nrow(mc)
n_multi_industry <- mc %>%
  distinct(platform_ID, IND) %>%
  count(platform_ID) %>%
  filter(n > 1) %>%
  nrow()

n_public_pct <- table3_full %>%
  filter(IND == "Credit Card Transactions") %>%
  pull(pct_platform)

table3_note <- paste0(
  "Note. N = ", format(sum(table3$total_firms), big.mark = ","),
  " firm-industry combinations across ", n_countries,
  " host countries yielding ",
  format(n_dyads, big.mark = ","), " firm-country-industry dyads. ",
  "Within this set, ", n_multi_industry,
  " firms appear in multiple industries. ",
  "Four dyads in the Credit Card Transactions industry were excluded ",
  "due to unavailable Euromonitor industry growth data for the Netherlands. ",
  "Platform classifications: Public = openly accessible developer portal; ",
  "Reg. = registration required; Rest. = restricted access ",
  "(invitation, partnership, or NDA required). ",
  "Credit Card Transactions industry shows elevated Public classification (",
  n_public_pct, "%) largely driven by Open Banking/PSD2 regulatory mandates."
)

table4_note <- paste0(
  "Note. N = ", format(n_unique_firms, big.mark = ","),
  " unique firms across 10 Euromonitor industries. ",
  "Firms may appear in multiple industries in Table 3 but are counted ",
  "once here. Public = openly accessible developer portal; ",
  "Registration = free account registration required; ",
  "Restricted = invitation, partnership, or NDA required."
)

cat("\n\nTable 3 Note:\n", table3_note, "\n")
cat("\nTable 4 Note:\n", table4_note, "\n")

# Export table data
write.csv(table3_full, file.path(output_path, "table3_data.csv"),
          row.names = FALSE)
write.csv(table4, file.path(output_path, "table4_data.csv"),
          row.names = FALSE)
writeLines(table3_note, file.path(output_path, "table3_note.txt"))
writeLines(table4_note, file.path(output_path, "table4_note.txt"))

# Also export to tables and charts folder
write.csv(table3_full, file.path(tables_path, "table3_data.csv"),
          row.names = FALSE)
write.csv(table4, file.path(tables_path, "table4_data.csv"),
          row.names = FALSE)

# --- Firm Count Summary (for dissertation text) ---
n_firm_ind_combos     <- nrow(distinct(mc, platform_ID, IND))
n_plat_firm_ind       <- mc %>%
  filter(PLAT != "NONE") %>%
  distinct(platform_ID, IND) %>%
  nrow()
n_plat_unique_firms   <- n_distinct(mc$platform_ID[mc$PLAT != "NONE"])
pct_plat_of_total     <- round(100 * n_plat_unique_firms / n_unique_firms, 1)

cat("\n--- FIRM COUNT SUMMARY (for dissertation text) ---\n")
cat("  Total unique firms:                ", n_unique_firms, "\n")
cat("  Total firm-industry combinations:  ", n_firm_ind_combos, "\n")
cat("  Firms in multiple industries:      ", n_multi_industry, "\n")
cat("  Platform unique firms:             ", n_plat_unique_firms, "\n")
cat("  Platform firm-industry combos:     ", n_plat_firm_ind, "\n")
cat("  Platform firms as % of total:      ", pct_plat_of_total, "%\n")
cat("------------------------------------------------\n\n")

cat("\n✓ Table 3 & 4 data exported.\n\n")

# ============================================================================
# PART A: FIRM-LEVEL DESCRIPTIVES (PLAT firms, N=230)
# ============================================================================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("PART A: FIRM-LEVEL DESCRIPTIVES (PLAT Firms, N=", nrow(plat_firms), ")\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Helper function for descriptive stats
desc_stats <- function(x, digits = 2) {
  tibble(
    N     = sum(!is.na(x)),
    Mean  = round(mean(x, na.rm = TRUE), digits),
    SD    = round(sd(x, na.rm = TRUE), digits),
    Min   = round(min(x, na.rm = TRUE), digits),
    Median = round(median(x, na.rm = TRUE), digits),
    Max   = round(max(x, na.rm = TRUE), digits)
  )
}

# --- A1: Boundary Resource Variables (Binary) ---
cat("--- A1: Binary Resource Variables ---\n")
binary_vars <- c("API", "DEVP", "DOCS", "SDK", "BUG", "STAN",
                  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
                  "COM_social_media", "COM_forum", "COM_blog", "COM_help_support",
                  "COM_live_chat", "COM_Slack", "COM_Discord",
                  "COM_stackoverflow", "COM_training", "COM_FAQ",
                  "GIT", "MON",
                  "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
                  "EVENT_conference", "EVENT_hackathon", "EVENT_other",
                  "SPAN_internal", "SPAN_communities", "SPAN_external",
                  "ROLE", "DATA", "STORE", "CERT")

binary_desc <- plat_firms %>%
  summarize(
    across(all_of(binary_vars),
           list(
             n = ~sum(!is.na(.)),
             sum = ~sum(as.numeric(.), na.rm = TRUE),
             pct = ~round(100 * mean(as.numeric(.), na.rm = TRUE), 1)
           ))
  ) %>%
  pivot_longer(everything(),
               names_to = c("Variable", ".value"),
               names_pattern = "(.+)_(.+)")

cat(sprintf("%-25s %5s %6s %6s\n", "Variable", "N", "Count", "%"))
cat(strrep("-", 45), "\n")
for (i in seq_len(nrow(binary_desc))) {
  cat(sprintf("%-25s %5d %6d %5.1f%%\n",
              binary_desc$Variable[i], binary_desc$n[i],
              binary_desc$sum[i], binary_desc$pct[i]))
}

# --- A2: Count/Ordinal Variables ---
cat("\n--- A2: Count/Ordinal Variables ---\n")

# Count variables grouped by construct (matches Variable Table classifications)
# Application
count_vars_application <- c("METH")
# Development
count_vars_development <- c("SDK_lang", "SDK_prog_lang")
# Social/Community (composites + language counts)
count_vars_social <- c("COM", "COM_lang", "GIT_lang", "GIT_prog_lang",
                       "EVENT", "SPAN", "SPAN_lang")
# Governance (language counts)
count_vars_governance <- c("ROLE_lang", "DATA_lang", "STORE_lang", "CERT_lang")
# Composite/Derived
count_vars_derived <- c("BUG_prog_lang", "LINGUISTIC_VARIETY",
                        "programming_lang_variety")

count_vars <- c(count_vars_application, count_vars_development,
                count_vars_social, count_vars_governance,
                count_vars_derived)

count_desc <- bind_rows(
  lapply(count_vars, function(v) {
    if (v %in% colnames(plat_firms)) {
      x <- as.numeric(plat_firms[[v]])
      desc_stats(x) %>%
        mutate(
          Variable = v,
          `n>0`    = sum(x > 0, na.rm = TRUE),
          `%>0`    = round(100 * sum(x > 0, na.rm = TRUE) / sum(!is.na(x)), 1),
          .before = 1
        ) %>%
        relocate(Variable, .before = 1)
    }
  })
)
print(count_desc, n = 30)

# --- A2a: METH Ordinal Frequency Breakdown ---
# METH is ordinal (0=None, 1=Read-only GET, 2=Full CRUD).
# Show n and % at each level so readers can see distribution.
cat("\n--- A2a: METH API Method Capability Distribution ---\n")
if ("METH" %in% colnames(plat_firms)) {
  meth_dist <- plat_firms %>%
    filter(!is.na(METH)) %>%
    count(METH = as.integer(METH)) %>%
    mutate(pct = round(100 * n / sum(n), 1),
           Label = case_when(
             METH == 0 ~ "0 – No API methods",
             METH == 1 ~ "1 – Read-only (GET)",
             METH == 2 ~ "2 – Full CRUD",
             TRUE       ~ as.character(METH)
           )) %>%
    select(METH, Label, n, pct)
  print(meth_dist)
}

# --- A2b: COM channel distribution ---
# COM = sum of 10 binary COM_* variables. Report distribution to show
# how many community channels platforms typically offer.
cat("\n--- A2b: COM Channel Count Distribution ---\n")
if ("COM" %in% colnames(plat_firms)) {
  com_dist <- plat_firms %>%
    filter(!is.na(COM)) %>%
    count(COM = as.integer(COM)) %>%
    mutate(pct = round(100 * n / sum(n), 1),
           cum_pct = round(cumsum(pct), 1))
  cat(sprintf("  %-12s %6s %6s %8s\n", "COM count", "n", "%", "Cum %"))
  cat(strrep("-", 38), "\n")
  for (i in seq_len(nrow(com_dist))) {
    cat(sprintf("  %-12d %6d %5.1f%% %7.1f%%\n",
                com_dist$COM[i], com_dist$n[i],
                com_dist$pct[i], com_dist$cum_pct[i]))
  }
}

# --- A3: Composite Scores ---
# Organized by theoretical hierarchy (see Codebook Sections 9.1-9.3):
#
#   Platform Resources (PR) = (Za + Zd + ZAI + Zs + Zg) / 5
#     └─ Each class: raw = detected/total → Z-normalized across PLAT firms
#
#   Platform Accessibility (EA) = (Z_LV + Z_PLV) / 2
#     └─ Z_LV  = Z-standardized LINGUISTIC_VARIETY
#     └─ Z_PLV = Z-standardized programming_lang_variety
cat("\n--- A3: Composite Scores ---\n")

# Platform Resources hierarchy: top-level composite, then subcomponents
pr_vars <- c("platform_resources",
             "raw_application", "Z_application",
             "raw_development", "Z_development",
             "raw_ai", "Z_ai",
             "raw_social", "Z_social",
             "raw_governance", "Z_governance")

# Platform Accessibility hierarchy: top-level composite, then raw + Z subcomponents
ea_vars <- c("platform_accessibility",
             "LINGUISTIC_VARIETY", "z_linguistic_variety",
             "programming_lang_variety", "z_programming_variety")

composite_vars <- c(pr_vars, ea_vars)

# Category mapping for Word export grouping
comp_category <- c(
  platform_resources = "Platform Resources (PR)",
  raw_application    = "  PR: Application",
  Z_application      = "  PR: Application",
  raw_development    = "  PR: Development",
  Z_development      = "  PR: Development",
  raw_ai             = "  PR: AI Integration",
  Z_ai               = "  PR: AI Integration",
  raw_social         = "  PR: Social/Community",
  Z_social           = "  PR: Social/Community",
  raw_governance     = "  PR: Governance",
  Z_governance       = "  PR: Governance",
  platform_accessibility  = "Platform Accessibility (EA)",
  LINGUISTIC_VARIETY       = "  EA: Linguistic Variety",
  z_linguistic_variety     = "  EA: Linguistic Variety",
  programming_lang_variety = "  EA: Programming Variety",
  z_programming_variety    = "  EA: Programming Variety"
)

comp_desc <- bind_rows(
  lapply(composite_vars, function(v) {
    if (v %in% colnames(plat_firms)) {
      desc_stats(as.numeric(plat_firms[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)

# Console: print with construct grouping
cat("\n  --- Platform Resources (PR) = (Za + Zd + ZAI + Zs + Zg) / 5 ---\n")
pr_desc <- comp_desc %>% filter(Variable %in% pr_vars)
print(pr_desc, n = 20)
cat("\n  --- Platform Accessibility (EA) = (Z_LV + Z_PLV) / 2 ---\n")
ea_desc <- comp_desc %>% filter(Variable %in% ea_vars)
print(ea_desc, n = 10)

# ============================================================================
# PART B: DYAD-LEVEL DESCRIPTIVES
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART B: DYAD-LEVEL DESCRIPTIVES (PLAT dyads, N=", nrow(plat_dyads), ")\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Key dyad-level variables — includes all SEM model + control variables
dyad_vars <- c(
  # DV
  "MKT_SHARE_CHANGE", "market_share_pct",
  # IV / Mediator (firm-level but repeated per dyad)
  "platform_resources", "platform_accessibility",
  # Category Z-scores (Phase 2 decomposition)
  "Z_application", "Z_development", "Z_ai", "Z_social", "Z_governance",
  # Moderator
  "cultural_distance",
  # Controls
  "host_gdp_per_capita", "host_Internet_users",
  "home_gdp_per_capita", "home_internet_users",
  "IND_GROW"
)

dyad_desc <- bind_rows(
  lapply(dyad_vars, function(v) {
    if (v %in% colnames(plat_dyads)) {
      desc_stats(as.numeric(plat_dyads[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)
cat("--- Dyad-Level Variable Descriptives ---\n")
print(dyad_desc, n = 20)

# DV distribution
cat("\n--- MKT_SHARE_CHANGE Distribution (PLAT dyads) ---\n")
if ("MKT_SHARE_CHANGE" %in% colnames(plat_dyads)) {
  plat_dyads %>%
    filter(!is.na(MKT_SHARE_CHANGE)) %>%
    summarize(
      n = n(),
      positive = sum(MKT_SHARE_CHANGE > 0),
      zero     = sum(MKT_SHARE_CHANGE == 0),
      negative = sum(MKT_SHARE_CHANGE < 0),
      pct_positive = round(100 * sum(MKT_SHARE_CHANGE > 0) / n(), 1),
      pct_negative = round(100 * sum(MKT_SHARE_CHANGE < 0) / n(), 1)
    ) %>%
    print()
}

# ============================================================================
# PART B2: ANALYTIC SAMPLE (SEM-READY) DESCRIPTIVES
# ============================================================================
# The SEM in script 11 uses listwise deletion. This section characterizes the
# actual tested sample — dyads with non-missing values for ALL SEM variables:
#   PR, EA, DV, CD, IND_GROW, host_GDP, host_INET, home_GDP
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART B2: ANALYTIC SAMPLE (SEM-READY) DESCRIPTIVES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- B2.1: Define SEM-required source variables ---
sem_required <- c("platform_resources", "platform_accessibility",
                  "MKT_SHARE_CHANGE", "cultural_distance",
                  "IND_GROW", "host_gdp_per_capita",
                  "host_Internet_users", "home_gdp_per_capita")

# Flag each dyad as SEM-ready or not
plat_dyads <- plat_dyads %>%
  mutate(sem_ready = complete.cases(across(all_of(sem_required))))

# --- B2.2: Sample attrition flow ---
n_full_plat   <- nrow(plat_dyads)
n_sem_ready   <- sum(plat_dyads$sem_ready)
n_dropped     <- n_full_plat - n_sem_ready

# Which variable(s) cause the most attrition?
attrition_detail <- tibble(
  Variable = sem_required,
  N_available = sapply(sem_required, function(v)
    sum(!is.na(plat_dyads[[v]]))),
  N_missing   = sapply(sem_required, function(v)
    sum(is.na(plat_dyads[[v]]))),
  Pct_missing = round(100 * N_missing / n_full_plat, 1)
) %>%
  arrange(desc(N_missing))

cat("--- B2.2: Sample Attrition Flow ---\n\n")
cat(sprintf("  Full PLAT dyads:           %s\n",
            format(n_full_plat, big.mark = ",")))
cat(sprintf("  SEM-ready (complete cases): %s  (%.1f%%)\n",
            format(n_sem_ready, big.mark = ","),
            100 * n_sem_ready / n_full_plat))
cat(sprintf("  Dropped (listwise):         %s  (%.1f%%)\n\n",
            format(n_dropped, big.mark = ","),
            100 * n_dropped / n_full_plat))

cat("Missing data by variable:\n")
cat(sprintf("  %-30s %8s %8s %8s\n", "Variable", "Avail", "Missing", "% Miss"))
cat(strrep("-", 60), "\n")
for (i in seq_len(nrow(attrition_detail))) {
  r <- attrition_detail[i, ]
  cat(sprintf("  %-30s %8d %8d %7.1f%%\n",
              r$Variable, r$N_available, r$N_missing, r$Pct_missing))
}

# Firm-level attrition
sem_plat_firms <- plat_dyads %>%
  filter(sem_ready) %>%
  distinct(platform_ID)
n_firms_full <- n_distinct(plat_dyads$platform_ID)
n_firms_sem  <- nrow(sem_plat_firms)

cat(sprintf("\n  PLAT firms in full sample:    %d\n", n_firms_full))
cat(sprintf("  PLAT firms in SEM sample:     %d  (%.1f%%)\n",
            n_firms_sem, 100 * n_firms_sem / n_firms_full))

# --- B2.3: SEM sample — Coverage by Industry ---
cat("\n--- B2.3: SEM Sample Coverage by Industry ---\n")
sem_by_ind <- plat_dyads %>%
  group_by(IND) %>%
  summarize(
    full_dyads   = n(),
    sem_dyads    = sum(sem_ready),
    pct_retained = round(100 * sem_dyads / full_dyads, 1),
    full_firms   = n_distinct(platform_ID),
    sem_firms    = n_distinct(platform_ID[sem_ready]),
    pct_firms    = round(100 * sem_firms / full_firms, 1),
    .groups = "drop"
  ) %>%
  arrange(IND)

# Add totals
sem_by_ind_total <- tibble(
  IND          = "Total",
  full_dyads   = n_full_plat,
  sem_dyads    = n_sem_ready,
  pct_retained = round(100 * n_sem_ready / n_full_plat, 1),
  full_firms   = n_firms_full,
  sem_firms    = n_firms_sem,
  pct_firms    = round(100 * n_firms_sem / n_firms_full, 1)
)
sem_by_ind_full <- bind_rows(sem_by_ind, sem_by_ind_total)

cat(sprintf("%-42s %7s %7s %7s %6s %6s %6s\n",
    "Industry", "Dyads", "SEM", "%Ret", "Firms", "SEM", "%Ret"))
cat(strrep("-", 80), "\n")
for (i in seq_len(nrow(sem_by_ind_full))) {
  r <- sem_by_ind_full[i, ]
  if (r$IND == "Total") cat(strrep("-", 80), "\n")
  cat(sprintf("%-42s %7d %7d %6.1f%% %6d %6d %5.1f%%\n",
      r$IND, r$full_dyads, r$sem_dyads, r$pct_retained,
      r$full_firms, r$sem_firms, r$pct_firms))
}

# --- B2.4: SEM sample — Coverage by PLAT Type ---
cat("\n--- B2.4: SEM Sample Coverage by PLAT Type ---\n")
sem_by_plat <- plat_dyads %>%
  group_by(PLAT) %>%
  summarize(
    full_dyads   = n(),
    sem_dyads    = sum(sem_ready),
    pct_retained = round(100 * sem_dyads / full_dyads, 1),
    full_firms   = n_distinct(platform_ID),
    sem_firms    = n_distinct(platform_ID[sem_ready]),
    pct_firms    = round(100 * sem_firms / full_firms, 1),
    .groups = "drop"
  )
print(sem_by_plat, width = 100)

# --- B2.5: SEM sample — Descriptives on key variables ---
cat("\n--- B2.5: Analytic Sample Variable Descriptives ---\n")
sem_dyads <- plat_dyads %>% filter(sem_ready)

# Same variables as Part B but on the SEM sample
sem_dyad_vars <- c(
  "MKT_SHARE_CHANGE", "market_share_pct",
  "platform_resources", "platform_accessibility",
  "Z_application", "Z_development", "Z_ai", "Z_social", "Z_governance",
  "cultural_distance",
  "host_gdp_per_capita", "host_Internet_users",
  "home_gdp_per_capita", "home_internet_users",
  "IND_GROW"
)

sem_dyad_desc <- bind_rows(
  lapply(sem_dyad_vars, function(v) {
    if (v %in% colnames(sem_dyads)) {
      desc_stats(as.numeric(sem_dyads[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)
cat("Dyad-level descriptives (SEM sample):\n")
print(sem_dyad_desc, n = 20)

# --- B2.6: SEM sample — Firm-level resource descriptives ---
cat("\n--- B2.6: SEM Sample Resource Descriptives (Firm-Level) ---\n")
sem_firm_data <- plat_dyads %>%
  filter(sem_ready) %>%
  distinct(platform_ID, .keep_all = TRUE)

sem_composite_vars <- c("raw_application", "raw_development", "raw_ai",
                         "raw_social", "raw_governance",
                         "Z_application", "Z_development", "Z_ai",
                         "Z_social", "Z_governance",
                         "platform_resources",
                         "LINGUISTIC_VARIETY", "programming_lang_variety",
                         "platform_accessibility")

sem_comp_desc <- bind_rows(
  lapply(sem_composite_vars, function(v) {
    if (v %in% colnames(sem_firm_data)) {
      desc_stats(as.numeric(sem_firm_data[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)
cat("Firm-level composites (SEM sample):\n")
print(sem_comp_desc, n = 20)

# --- B2.7: Comparison — Full vs SEM sample means ---
cat("\n--- B2.7: Full vs. SEM Sample Comparison ---\n")
compare_vars <- c("platform_resources", "platform_accessibility",
                   "MKT_SHARE_CHANGE", "cultural_distance",
                   "host_gdp_per_capita", "host_Internet_users",
                   "home_gdp_per_capita", "IND_GROW")

sample_comparison <- bind_rows(
  lapply(compare_vars, function(v) {
    full_vals <- as.numeric(plat_dyads[[v]])
    sem_vals  <- as.numeric(sem_dyads[[v]])
    tibble(
      Variable     = v,
      Full_N       = sum(!is.na(full_vals)),
      Full_Mean    = round(mean(full_vals, na.rm = TRUE), 3),
      Full_SD      = round(sd(full_vals, na.rm = TRUE), 3),
      SEM_N        = sum(!is.na(sem_vals)),
      SEM_Mean     = round(mean(sem_vals, na.rm = TRUE), 3),
      SEM_SD       = round(sd(sem_vals, na.rm = TRUE), 3),
      Diff_pct     = round(100 * (mean(sem_vals, na.rm = TRUE) -
                    mean(full_vals, na.rm = TRUE)) /
                    sd(full_vals, na.rm = TRUE), 1)
    )
  })
)
cat("Full PLAT vs. SEM-ready sample (Diff_pct = difference in SD units):\n")
print(sample_comparison, width = 120)

# Export comparison data
write.csv(sem_by_ind_full,
          file.path(output_path, "08_sem_coverage_by_industry.csv"),
          row.names = FALSE)
write.csv(sample_comparison,
          file.path(output_path, "08_sem_sample_comparison.csv"),
          row.names = FALSE)

cat("\n✓ Part B2 complete. SEM analytic sample characterized.\n\n")

# ============================================================================
# PART C: BY INDUSTRY
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART C: BY INDUSTRY\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Industry-level summary
cat("--- C1: Firm Counts and Resource Intensity by Industry ---\n")
ind_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  group_by(IND) %>%
  summarize(
    n_firms = n_distinct(platform_ID),
    n_dyads = n(),
    n_countries = n_distinct(host_country_name),
    mean_PR = round(mean(platform_resources, na.rm = TRUE), 3),
    sd_PR   = round(sd(platform_resources, na.rm = TRUE), 3),
    mean_PA = round(mean(platform_accessibility, na.rm = TRUE), 3),
    mean_DV = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    sd_DV   = round(sd(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(n_firms))

print(ind_summary, n = 12, width = 120)

# --- C2: Binary Resource Adoption by Industry (% of PLAT firms with resource = 1) ---
cat("\n--- C2: Binary Resource Adoption by Industry ---\n")

# Key binary resources to cross-tabulate (subset for readability)
key_binary <- c("API", "DEVP", "DOCS", "SDK", "BUG", "STAN",
                "AI_MODEL", "AI_AGENT",
                "GIT", "MON",
                "COM_forum", "COM_blog", "COM_training",
                "ROLE", "DATA", "STORE", "CERT")

ind_binary <- plat_firms %>%
  group_by(IND) %>%
  summarize(
    n = n(),
    across(all_of(key_binary),
           ~round(100 * mean(as.numeric(.), na.rm = TRUE), 1),
           .names = "{.col}"),
    .groups = "drop"
  ) %>%
  arrange(IND)

cat("\nResource adoption rate (%) by industry:\n")
print(ind_binary, n = 12, width = 200)

# --- C3: Count/Ordinal Variables by Industry (Mean across PLAT firms) ---
cat("\n--- C3: Count/Ordinal Variables by Industry (Mean) ---\n")

key_count <- c("METH", "COM", "EVENT", "SPAN",
               "LINGUISTIC_VARIETY", "programming_lang_variety")

ind_count <- plat_firms %>%
  group_by(IND) %>%
  summarize(
    n = n(),
    across(all_of(key_count[key_count %in% colnames(plat_firms)]),
           ~round(mean(as.numeric(.), na.rm = TRUE), 2),
           .names = "{.col}"),
    .groups = "drop"
  ) %>%
  arrange(IND)

cat("\nCount/ordinal variable means by industry:\n")
print(ind_count, n = 12, width = 200)

# ============================================================================
# PART D: BY REGION/COUNTRY
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART D: BY REGION/COUNTRY\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# --- D1: Home Country (where firms are headquartered) ---
cat("--- D1: Home Country Distribution (PLAT firms) ---\n")
home_dist <- plat_firms %>%
  group_by(home_country_name) %>%
  summarize(
    n_firms = n(),
    mean_PR = round(mean(platform_resources, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(desc(n_firms))

print(home_dist, n = 20)

# --- D2: Host Country (market share observed) ---
cat("\n--- D2: Host Country Distribution (PLAT dyads) ---\n")
host_dist <- plat_dyads %>%
  group_by(host_country_name) %>%
  summarize(
    n_dyads = n(),
    n_firms = n_distinct(platform_ID),
    mean_DV = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    mean_CD = round(mean(cultural_distance, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(n_dyads))

print(host_dist, n = 25)

# --- D3: Cultural cluster-level aggregation ---
# Assign GLOBE cultural clusters (House et al., 2004)
cat("\n--- D3: By GLOBE Cultural Cluster ---\n")
cluster_lookup <- c(
  # Anglo
  "USA" = "Anglo", "CAN" = "Anglo", "GBR" = "Anglo", "IRL" = "Anglo",
  "AUS" = "Anglo", "NZL" = "Anglo", "ZAF" = "Anglo",
  # Germanic Europe
  "DEU" = "Germanic Europe", "AUT" = "Germanic Europe",
  "CHE" = "Germanic Europe", "NLD" = "Germanic Europe",
  # Nordic Europe
  "SWE" = "Nordic Europe", "NOR" = "Nordic Europe",
  "DNK" = "Nordic Europe", "FIN" = "Nordic Europe",
  # Latin Europe
  "FRA" = "Latin Europe", "ITA" = "Latin Europe", "ESP" = "Latin Europe",
  "PRT" = "Latin Europe", "BEL" = "Latin Europe", "GRC" = "Latin Europe",
  "ISR" = "Latin Europe",
  # Eastern Europe
  "POL" = "Eastern Europe", "CZE" = "Eastern Europe", "HUN" = "Eastern Europe",
  "ROU" = "Eastern Europe", "RUS" = "Eastern Europe", "UKR" = "Eastern Europe",
  # Latin America
  "MEX" = "Latin America", "BRA" = "Latin America", "ARG" = "Latin America",
  "COL" = "Latin America", "CHL" = "Latin America", "PER" = "Latin America",
  # Confucian Asia
  "CHN" = "Confucian Asia", "JPN" = "Confucian Asia", "KOR" = "Confucian Asia",
  "TWN" = "Confucian Asia", "HKG" = "Confucian Asia", "SGP" = "Confucian Asia",
  # Southern Asia
  "IND" = "Southern Asia", "PAK" = "Southern Asia", "BGD" = "Southern Asia",
  "LKA" = "Southern Asia", "IDN" = "Southern Asia", "THA" = "Southern Asia",
  "VNM" = "Southern Asia", "MYS" = "Southern Asia", "PHL" = "Southern Asia",
  "IRN" = "Southern Asia",
  # Middle East
  "TUR" = "Middle East", "EGY" = "Middle East", "MAR" = "Middle East",
  "SAU" = "Middle East", "ARE" = "Middle East",
  # Sub-Saharan Africa
  "NGA" = "Sub-Saharan Africa", "KEN" = "Sub-Saharan Africa"
)

mc <- mc %>%
  mutate(
    home_cluster = cluster_lookup[home_country_iso3c],
    host_cluster = cluster_lookup[host_country_iso3c]
  )

cluster_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(host_cluster)) %>%
  group_by(host_cluster) %>%
  summarize(
    n_dyads   = n(),
    n_firms   = n_distinct(platform_ID),
    n_countries = n_distinct(host_country_name),
    mean_DV   = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    sd_DV     = round(sd(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    mean_CD   = round(mean(cultural_distance, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(n_dyads))

print(cluster_summary, n = 10, width = 120)

# ============================================================================
# PART E: BY PLAT TYPE
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART E: BY PLAT TYPE\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

plat_type_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  group_by(PLAT) %>%
  summarize(
    n = n(),
    # Resource intensity
    mean_PR  = round(mean(platform_resources, na.rm = TRUE), 3),
    sd_PR    = round(sd(platform_resources, na.rm = TRUE), 3),
    # Category breakdowns
    mean_Za  = round(mean(Z_application, na.rm = TRUE), 3),
    mean_Zd  = round(mean(Z_development, na.rm = TRUE), 3),
    mean_Zai = round(mean(Z_ai, na.rm = TRUE), 3),
    mean_Zs  = round(mean(Z_social, na.rm = TRUE), 3),
    mean_Zg  = round(mean(Z_governance, na.rm = TRUE), 3),
    # Platform Accessibility
    mean_PA  = round(mean(platform_accessibility, na.rm = TRUE), 3),
    sd_PA    = round(sd(platform_accessibility, na.rm = TRUE), 3),
    # Key individual resources
    pct_API  = round(100 * mean(API > 0, na.rm = TRUE), 1),
    pct_SDK  = round(100 * mean(SDK > 0, na.rm = TRUE), 1),
    pct_GIT  = round(100 * mean(as.numeric(GIT), na.rm = TRUE), 1),
    .groups = "drop"
  )

print(plat_type_summary, width = 120)

# ============================================================================
# PART F: CORRELATION MATRIX (SEM Variables)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART F: CORRELATION MATRIX\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# For the correlation matrix, use dyad-level data (PLAT only)
# Include all SEM model variables + controls
# Use numbered labels so the table fits on a portrait page
sem_vars <- c("platform_resources",
              "Z_application", "Z_development", "Z_ai",
              "Z_social", "Z_governance",
              "platform_accessibility",
              "MKT_SHARE_CHANGE",
              "cultural_distance",
              "host_gdp_per_capita", "host_Internet_users",
              "home_gdp_per_capita",
              "LINGUISTIC_VARIETY", "programming_lang_variety",
              "IND_GROW")

# Short labels for APA table (numbered for compact column headers)
sem_labels <- c(
  "Platform Resources (PR)",
  "Z Application",
  "Z Development",
  "Z AI",
  "Z Social",
  "Z Governance",
  "Platform Access. (PA)",
  "Mkt Share Change (DV)",
  "Cultural Distance (CD)",
  "Host GDP/capita",
  "Host Internet Users",
  "Home GDP/capita",
  "Linguistic Variety",
  "Prog. Lang. Variety",
  "Industry Growth"
)

# Filter to variables that exist
sem_vars_present <- sem_vars[sem_vars %in% colnames(plat_dyads)]
sem_labels_present <- sem_labels[sem_vars %in% colnames(plat_dyads)]

cor_data <- plat_dyads %>%
  select(all_of(sem_vars_present)) %>%
  mutate(across(everything(), as.numeric))

cor_mat <- cor(cor_data, use = "pairwise.complete.obs")

# --- Compute p-value matrix for significance stars (APA) ---
p_mat <- matrix(NA, nrow = ncol(cor_data), ncol = ncol(cor_data))
for (i in seq_len(ncol(cor_data))) {
  for (j in seq_len(ncol(cor_data))) {
    if (i != j) {
      valid <- complete.cases(cor_data[, c(i, j)])
      if (sum(valid) > 3) {
        p_mat[i, j] <- cor.test(cor_data[[i]][valid],
                                cor_data[[j]][valid])$p.value
      }
    }
  }
}

# Star formatter: * p < .05, ** p < .01, *** p < .001
sig_stars <- function(p) {
  if (is.na(p)) return("")
  if (p < .001) return("***")
  if (p < .01)  return("**")
  if (p < .05)  return("*")
  return("")
}

cat("Correlation matrix (N=", nrow(plat_dyads), " PLAT dyads):\n\n")

# Print lower triangle with numbered labels and stars
for (i in seq_along(sem_vars_present)) {
  row_vals <- sapply(1:i, function(j) {
    if (i == j) return("   —  ")
    stars <- sig_stars(p_mat[i, j])
    sprintf("%6.3f%s", cor_mat[i, j], stars)
  })
  cat(sprintf("%2d. %-25s %s\n", i,
              sem_labels_present[i],
              paste(row_vals, collapse = " ")))
}

# --- Build lower-triangle data frame for APA Word export ---
n_vars <- length(sem_vars_present)

# Create the lower-triangle matrix with "—" on diagonal, stars on coefficients
cor_lower <- matrix("", nrow = n_vars, ncol = n_vars)
for (i in seq_len(n_vars)) {
  for (j in seq_len(n_vars)) {
    if (i == j) {
      cor_lower[i, j] <- "\u2014"  # em-dash on diagonal
    } else if (j < i) {
      stars <- sig_stars(p_mat[i, j])
      cor_lower[i, j] <- paste0(sprintf("%.2f", cor_mat[i, j]), stars)
    } else {
      cor_lower[i, j] <- ""  # blank above diagonal
    }
  }
}

# Compute M and SD for each variable (pairwise complete, dyad-level)
cor_means <- sapply(cor_data, function(x) sprintf("%.2f", mean(x, na.rm = TRUE)))
cor_sds   <- sapply(cor_data, function(x) sprintf("%.2f", sd(x, na.rm = TRUE)))

# Build data frame: Variable | M | SD | 1 | 2 | ... | n  (APA standard)
cor_df <- data.frame(
  Variable = paste0(seq_len(n_vars), ". ", sem_labels_present),
  M  = cor_means,
  SD = cor_sds,
  stringsAsFactors = FALSE
)
for (j in seq_len(n_vars)) {
  cor_df[[as.character(j)]] <- cor_lower[, j]
}

# Save full correlation matrix (for reference)
write.csv(round(cor_mat, 3),
          file.path(output_path, "correlation_matrix_sem_vars.csv"))

# ============================================================================
# PART G: CLUSTER ANALYSIS (Resource-Based Platform Typology)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART G: CLUSTER ANALYSIS — RESOURCE-BASED PLATFORM TYPES\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Use the 5 raw category scores + platform accessibility
cluster_vars <- c("raw_application", "raw_development", "raw_ai",
                   "raw_social", "raw_governance")

cluster_data <- plat_firms %>%
  select(platform_ID, platform_name, PLAT, IND,
         all_of(cluster_vars)) %>%
  filter(complete.cases(across(all_of(cluster_vars))))

# Scale for clustering
cluster_scaled <- scale(cluster_data[, cluster_vars])

# --- G1: Determine optimal k using within-cluster sum of squares ---
cat("--- G1: Optimal Number of Clusters (Elbow Method) ---\n")
set.seed(42)
wss <- sapply(2:8, function(k) {
  kmeans(cluster_scaled, k, nstart = 25)$tot.withinss
})
cat("k  WSS\n")
for (i in seq_along(wss)) {
  cat(sprintf("%d  %.1f\n", i + 1, wss[i]))
}

# --- G2: Fit k=3, k=4, k=5 and compare ---
for (k in 3:5) {
  cat(sprintf("\n--- G2: k=%d Cluster Solution ---\n", k))
  km <- kmeans(cluster_scaled, k, nstart = 50)
  cluster_data[[paste0("cluster_k", k)]] <- km$cluster

  # Cluster means (unscaled)
  cluster_profile <- cluster_data %>%
    group_by(!!sym(paste0("cluster_k", k))) %>%
    summarize(
      n = n(),
      across(all_of(cluster_vars), ~round(mean(., na.rm = TRUE), 3)),
      .groups = "drop"
    )
  print(cluster_profile)

  # PLAT type distribution within clusters
  cat("\nPLAT distribution per cluster:\n")
  cluster_data %>%
    group_by(!!sym(paste0("cluster_k", k)), PLAT) %>%
    summarize(n = n(), .groups = "drop") %>%
    pivot_wider(names_from = PLAT, values_from = n, values_fill = 0) %>%
    print()
}

# --- G3: Cluster Visualizations (k=4) ---
cat("\n--- G3: Cluster Visualizations ---\n")

# Use k=4 as primary solution
best_k <- 4
km_best <- kmeans(cluster_scaled, best_k, nstart = 50)
cluster_data$cluster <- factor(km_best$cluster)

# --- Chart 1: PCA-based scatter plot of clusters (with labels) ---
if (!require(ggrepel)) install.packages("ggrepel", repos = "https://cloud.r-project.org")
library(ggrepel)

pca_clust <- prcomp(cluster_scaled)
pca_df <- data.frame(
  PC1 = pca_clust$x[, 1],
  PC2 = pca_clust$x[, 2],
  Cluster = cluster_data$cluster,
  platform_name = cluster_data$platform_name
)

# Compute distance from each cluster centroid to find outliers
centroids <- pca_df %>%
  group_by(Cluster) %>%
  summarize(PC1 = mean(PC1), PC2 = mean(PC2), .groups = "drop")

pca_df <- pca_df %>%
  left_join(centroids, by = "Cluster", suffix = c("", "_cent")) %>%
  mutate(dist_from_center = sqrt((PC1 - PC1_cent)^2 + (PC2 - PC2_cent)^2))

# Label all Innovators + top 3 most extreme per other cluster
# (Innovator cluster ID determined dynamically below after profile analysis)
label_c4 <- pca_df  # placeholder — will be reassigned after cluster_names is built
label_others <- pca_df  # placeholder
label_df <- pca_df  # placeholder — reassigned below

# --- Automatic cluster labeling based on profile characteristics ---
# K-means assigns arbitrary cluster numbers each run, so we label by profile:
#   Innovators   = highest mean AI score (smallest group, AI standout)
#   Minimalists  = lowest overall mean across all 5 categories
#   Collaborators = highest mean Social score (excluding Innovators)
#   Generalists  = remaining cluster (broad moderate investment)
cluster_means <- cluster_data %>%
  group_by(cluster) %>%
  summarize(
    mean_app  = mean(raw_application, na.rm = TRUE),
    mean_dev  = mean(raw_development, na.rm = TRUE),
    mean_ai   = mean(raw_ai, na.rm = TRUE),
    mean_soc  = mean(raw_social, na.rm = TRUE),
    mean_gov  = mean(raw_governance, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(overall_mean = (mean_app + mean_dev + mean_ai + mean_soc + mean_gov) / 5)

# Step 1: Innovators = highest AI
innovator_id <- cluster_means$cluster[which.max(cluster_means$mean_ai)]

# Step 2: Minimalists = lowest overall mean (excluding Innovators)
remaining <- cluster_means %>% filter(cluster != innovator_id)
minimalist_id <- remaining$cluster[which.min(remaining$overall_mean)]

# Step 3: Collaborators = highest Social (excluding Innovators & Minimalists)
remaining2 <- remaining %>% filter(cluster != minimalist_id)
collaborator_id <- remaining2$cluster[which.max(remaining2$mean_soc)]

# Step 4: Generalists = whatever is left
generalist_id <- setdiff(levels(cluster_data$cluster),
                          c(as.character(innovator_id),
                            as.character(minimalist_id),
                            as.character(collaborator_id)))

cluster_names <- setNames(
  c("Generalists", "Minimalists", "Collaborators", "Innovators"),
  c(generalist_id, minimalist_id, collaborator_id, innovator_id)
)

cat("\nAutomatic cluster label assignment:\n")
for (nm in names(cluster_names)) {
  row <- cluster_means %>% filter(cluster == nm)
  cat(sprintf("  Cluster %s → %s (n=%d, overall_mean=%.3f, AI=%.3f, Social=%.3f)\n",
              nm, cluster_names[nm], row$n, row$overall_mean, row$mean_ai, row$mean_soc))
}

# Now build label_df using the dynamically identified Innovator cluster
label_c4 <- pca_df %>% filter(Cluster == innovator_id)
label_others <- pca_df %>%
  filter(Cluster != innovator_id) %>%
  group_by(Cluster) %>%
  slice_max(dist_from_center, n = 3) %>%
  ungroup()
label_df <- bind_rows(label_c4, label_others)

pca_df$Cluster_Name <- cluster_names[as.character(pca_df$Cluster)]
label_df$Cluster_Name <- cluster_names[as.character(label_df$Cluster)]
centroids$Cluster_Name <- cluster_names[as.character(centroids$Cluster)]

var_explained <- round(100 * summary(pca_clust)$importance[2, 1:2], 1)

p_scatter <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Cluster_Name)) +
  geom_point(alpha = 0.5, size = 2) +
  geom_point(data = centroids, aes(x = PC1, y = PC2),
             shape = 4, size = 5, stroke = 2, show.legend = FALSE) +
  stat_ellipse(level = 0.80, linetype = "dashed", linewidth = 0.5) +
  geom_text_repel(
    data = label_df,
    aes(label = platform_name),
    size = 2.5,
    family = "Times New Roman",
    max.overlaps = 20,
    segment.size = 0.3,
    segment.alpha = 0.5,
    show.legend = FALSE
  ) +
  labs(
    x = paste0("PC1 (", var_explained[1], "% variance)"),
    y = paste0("PC2 (", var_explained[2], "% variance)"),
    color = "Cluster"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 12) +
  theme(
    plot.title = element_blank(),
    legend.position = "right"
  ) +
  scale_color_manual(values = c("Generalists"   = "#2ca02c",   # dark green
                                 "Minimalists"   = "#d95f02",   # dark orange
                                 "Collaborators" = "#1f77b4",   # dark blue
                                 "Innovators"    = "#d62728"))   # dark pink/red

print(p_scatter)
ggsave(file.path(tables_path, "08_cluster_scatter.png"),
       p_scatter, width = 10, height = 7, dpi = 300)
cat("Cluster scatter plot saved.\n")

# --- Chart 2: Cluster profile plot (mean raw scores per category) ---
# Use the overall sample mean as the baseline for comparison
overall_means <- plat_firms %>%
  summarize(
    Application = mean(raw_application, na.rm = TRUE),
    Development = mean(raw_development, na.rm = TRUE),
    AI          = mean(raw_ai, na.rm = TRUE),
    Social      = mean(raw_social, na.rm = TRUE),
    Governance  = mean(raw_governance, na.rm = TRUE)
  )

profile_data <- cluster_data %>%
  group_by(cluster) %>%
  summarize(
    Application = mean(raw_application, na.rm = TRUE),
    Development = mean(raw_development, na.rm = TRUE),
    AI          = mean(raw_ai, na.rm = TRUE),
    Social      = mean(raw_social, na.rm = TRUE),
    Governance  = mean(raw_governance, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# Create labels with cluster names and n (reuse dynamic cluster_names from above)
profile_data$label <- paste0(cluster_names[as.character(profile_data$cluster)],
                              " (n=", profile_data$n, ")")

profile_long <- profile_data %>%
  select(label, Application:Governance) %>%
  pivot_longer(cols = Application:Governance,
               names_to = "Category", values_to = "Mean_Score") %>%
  mutate(Category = factor(Category,
         levels = c("Application", "Development", "AI", "Social", "Governance")))

# Overall means for reference line
overall_long <- overall_means %>%
  pivot_longer(cols = everything(),
               names_to = "Category", values_to = "Overall_Mean") %>%
  mutate(Category = factor(Category,
         levels = c("Application", "Development", "AI", "Social", "Governance")))

p_profile <- ggplot(profile_long,
                     aes(x = Category, y = Mean_Score, fill = label)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8),
           width = 0.7) +
  geom_point(data = overall_long,
             aes(x = Category, y = Overall_Mean),
             inherit.aes = FALSE,
             shape = 18, size = 4, color = "black") +
  geom_line(data = overall_long,
            aes(x = as.numeric(Category), y = Overall_Mean),
            inherit.aes = FALSE,
            linetype = "dashed", color = "black", linewidth = 0.5) +
  labs(
    x = "Resource Category",
    y = "Mean Raw Composite Score",
    fill = "Cluster"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 12) +
  theme(
    plot.title = element_blank(),
    axis.text.x = element_text(angle = 30, hjust = 1),
    legend.position = "bottom"
  ) +
  scale_fill_manual(values = {
    # Build color map: match each label to its cluster color
    color_map <- c("Generalists" = "#2ca02c", "Minimalists" = "#d95f02",
                    "Collaborators" = "#1f77b4", "Innovators" = "#d62728")
    label_colors <- sapply(unique(profile_long$label), function(lbl) {
      name <- sub(" \\(n=.*", "", lbl)
      color_map[[name]]
    })
    setNames(label_colors, names(label_colors))
  })

print(p_profile)
ggsave(file.path(tables_path, "08_cluster_profiles.png"),
       p_profile, width = 9, height = 6, dpi = 300)
cat("Cluster profile chart saved.\n")

# --- G4: Cluster Labels ---
cat("\n--- G4: Assign Cluster Labels ---\n")
cat("Review the scatter plot and profile chart above.\n")
cat("Based on the resource patterns, assign descriptive labels to each cluster.\n")
cat("TODO: Replace cluster numbers with meaningful labels in final write-up.\n")

# Add the named cluster label to cluster_data for export
cluster_data$cluster_label <- cluster_names[as.character(cluster_data$cluster)]

# Save cluster assignments
write.csv(
  cluster_data %>% select(platform_ID, platform_name, PLAT, IND,
                           cluster, cluster_label, starts_with("cluster_k")),
  file.path(output_path, "platform_cluster_assignments.csv"),
  row.names = FALSE
)
cat("\nCluster assignments saved to: platform_cluster_assignments.csv\n")
cat("NOTE: Cluster × performance outcome analysis is in 12_cluster_performance.R\n")

# ============================================================================
# PART H: Z-SCORE CHARTS BY INDUSTRY
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("PART H: Z-SCORE RESOURCE PROFILES BY INDUSTRY\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Compute mean Z-scores per industry (PLAT firms only)
z_vars <- c("Z_application", "Z_development", "Z_ai", "Z_social", "Z_governance")
z_labels <- c("Application", "Development", "AI", "Social", "Governance")

ind_z <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  group_by(IND) %>%
  summarize(
    across(all_of(z_vars), ~mean(., na.rm = TRUE)),
    n = n(),
    .groups = "drop"
  )

# Reshape for plotting
ind_z_long <- ind_z %>%
  pivot_longer(cols = all_of(z_vars),
               names_to = "Category",
               values_to = "Mean_Z") %>%
  mutate(
    Category = factor(Category,
                      levels = z_vars,
                      labels = z_labels),
    IND_label = paste0(IND, " (n=", n, ")")
  )

# --- Chart 1: Faceted by resource category — industries compared ---
p1 <- ggplot(ind_z_long, aes(x = reorder(IND, Mean_Z), y = Mean_Z,
                              fill = Mean_Z > 0)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_hline(yintercept = 0, linewidth = 0.5, color = "black") +
  scale_fill_manual(values = c("TRUE" = "#2166AC", "FALSE" = "#B2182B")) +
  facet_wrap(~Category, ncol = 3, scales = "free_x") +
  coord_flip() +
  labs(
    x = NULL,
    y = "Mean Standardized Score (Z)"
  ) +
  theme_minimal(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    strip.text = element_text(face = "bold", size = 10),
    panel.grid.major.y = element_blank(),
    plot.title = element_blank(),
    plot.subtitle = element_blank()
  )

print(p1)
ggsave(file.path(tables_path, "08_zscore_by_industry.png"),
       p1, width = 12, height = 8, dpi = 300)
cat("✓ Z-score by industry chart (faceted bars) saved.\n")

# --- Chart 1b: Cleveland dot plot — connected dots per industry ---
p1b <- ggplot(ind_z_long, aes(x = Mean_Z, y = reorder(IND, Mean_Z,
                               FUN = function(x) mean(x)))) +
  geom_vline(xintercept = 0, linewidth = 0.5, color = "grey50",
             linetype = "dashed") +
  geom_line(aes(group = IND), color = "grey70", linewidth = 0.5) +
  geom_point(aes(color = Category), size = 3.5) +
  labs(
    x = "Mean Standardized Score (Z)",
    y = NULL,
    color = "Resource\nCategory"
  ) +
  theme_minimal(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    panel.grid.major.y = element_line(color = "grey90"),
    panel.grid.minor = element_blank()
  ) +
  scale_color_brewer(palette = "Set1")

print(p1b)
ggsave(file.path(tables_path, "08_zscore_dotplot.png"),
       p1b, width = 10, height = 7, dpi = 300)
cat("✓ Z-score dot plot saved.\n")

# --- Chart 1c: Radar/spider chart per industry ---
# Using coord_polar to create radar effect
p1c <- ggplot(ind_z_long, aes(x = Category, y = Mean_Z, group = IND)) +
  geom_polygon(aes(fill = IND), alpha = 0.15, show.legend = FALSE) +
  geom_line(aes(color = IND), linewidth = 0.8) +
  geom_point(aes(color = IND), size = 1.5) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey50",
             linetype = "dotted") +
  coord_polar() +
  labs(
    color = "Industry",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    axis.text.y = element_text(size = 7),
    legend.position = "right",
    legend.text = element_text(size = 7)
  )

print(p1c)
ggsave(file.path(tables_path, "08_zscore_radar.png"),
       p1c, width = 10, height = 8, dpi = 300)
cat("✓ Z-score radar chart saved.\n")

# --- Chart 2: Heatmap — all industries × categories ---
ind_z_matrix <- ind_z_long %>%
  mutate(IND = reorder(IND, Mean_Z, FUN = mean))

p2 <- ggplot(ind_z_matrix, aes(x = Category, y = IND, fill = Mean_Z)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", Mean_Z)), size = 3.2) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC",
                        midpoint = 0, name = "Mean Z") +
  labs(
    x = NULL, y = NULL
  ) +
  theme_minimal(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    panel.grid = element_blank()
  )

print(p2)
ggsave(file.path(tables_path, "08_zscore_heatmap.png"),
       p2, width = 9, height = 6, dpi = 300)
cat("✓ Z-score heatmap saved.\n\n")

# ============================================================================
# SECTION FINAL: APA WORD TABLE EXPORTS
# ============================================================================

library(flextable)
library(officer)

desc_doc <- read_docx()

# --- Table 3: Platform Classification by Industry ---
desc_doc <- body_add_par(desc_doc, "Table 3. Platform Classification of Firms by Industry",
                          style = "heading 2")

t3_apa <- table3_full %>%
  rename(Industry = IND, Firms = total_firms, `Non-Platform` = non_platform,
         Public = public, Registration = registration, Restricted = restricted,
         `Total Platform` = total_platform, `% Platform` = pct_platform,
         Countries = countries, Dyads = dyads)

ft_t3 <- flextable(t3_apa) %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(t3_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  hline(i = nrow(t3_apa) - 1, border = fp_border(width = 1), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_t3)
desc_doc <- body_add_par(desc_doc, table3_note, style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table 4: Unique Firms by Access Classification ---
desc_doc <- body_add_par(desc_doc, "Table 4. Unique Platform Firms by Access Classification",
                          style = "heading 2")

ft_t4 <- flextable(table4) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2, align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_t4)
desc_doc <- body_add_par(desc_doc, table4_note, style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Binary Resource Variables (Firm-Level) ---
desc_doc <- body_add_par(desc_doc, "Table. Binary Boundary Resource Variables (PLAT Firms)",
                          style = "heading 2")

# Add theoretical category
br_theory <- c(
  API = "Application",
  DEVP = "Development", DOCS = "Development", SDK = "Development",
  BUG = "Development", STAN = "Development",
  AI_MODEL = "AI Integration", AI_AGENT = "AI Integration",
  AI_ASSIST = "AI Integration", AI_DATA = "AI Integration",
  AI_MKT = "AI Integration",
  COM_social_media = "Social: Communication", COM_forum = "Social: Communication",
  COM_blog = "Social: Communication", COM_help_support = "Social: Communication",
  COM_live_chat = "Social: Communication", COM_Slack = "Social: Communication",
  COM_Discord = "Social: Communication", COM_stackoverflow = "Social: Communication",
  COM_training = "Social: Communication", COM_FAQ = "Social: Communication",
  GIT = "Social: GitHub", MON = "Social: Monetization",
  EVENT_webinars = "Social: Events", EVENT_virtual = "Social: Events",
  EVENT_in_person = "Social: Events", EVENT_conference = "Social: Events",
  EVENT_hackathon = "Social: Events", EVENT_other = "Social: Events",
  SPAN_internal = "Social: Boundary Spanning",
  SPAN_communities = "Social: Boundary Spanning",
  SPAN_external = "Social: Boundary Spanning",
  ROLE = "Governance", DATA = "Governance", STORE = "Governance",
  CERT = "Governance"
)

binary_apa <- binary_desc %>%
  mutate(Category = br_theory[Variable]) %>%
  rename(N = n, Count = sum, `%` = pct) %>%
  select(Category, Variable, N, Count, `%`)

ft_bin <- flextable(binary_apa) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1:2, align = "left", part = "body") %>%
  align(j = 3:5, align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  merge_v(j = "Category")

desc_doc <- body_add_flextable(desc_doc, ft_bin)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT firms. Count = number of firms with resource present. %% = percentage adoption.",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Count/Ordinal Variables (with category grouping) ---
desc_doc <- body_add_par(desc_doc, "Table. Count/Ordinal Variable Descriptives (PLAT Firms)",
                          style = "heading 2")

# Add category grouping for readability
count_category <- c(
  METH = "Application",
  SDK_lang = "Development", SDK_prog_lang = "Development",
  COM = "Social/Community", COM_lang = "Social/Community",
  GIT_lang = "Social/Community", GIT_prog_lang = "Social/Community",
  EVENT = "Social/Community", SPAN = "Social/Community",
  SPAN_lang = "Social/Community",
  ROLE_lang = "Governance", DATA_lang = "Governance",
  STORE_lang = "Governance", CERT_lang = "Governance",
  BUG_prog_lang = "Composite/Derived",
  LINGUISTIC_VARIETY = "Composite/Derived",
  programming_lang_variety = "Composite/Derived"
)

count_desc_apa <- count_desc %>%
  mutate(Category = count_category[Variable]) %>%
  select(Category, Variable, everything())

ft_cnt <- flextable(count_desc_apa) %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1:2, align = "left", part = "body") %>%
  align(j = 3:ncol(count_desc_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  merge_v(j = "Category")

desc_doc <- body_add_flextable(desc_doc, ft_cnt)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT firms. METH = count of API HTTP methods (0-5). COM = sum of 10 communication channels; EVENT = sum of 6 event types; SPAN = sum of 3 boundary spanning indicators. _lang variables = number of distinct natural languages per resource. _prog_lang variables = number of programming languages per resource. LINGUISTIC_VARIETY = sum of 8 natural language counts. programming_lang_variety = union count of unique programming languages across SDK, GIT, and BUG. Categories align with Variable Table classifications.",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table 1.4a: METH Ordinal Frequency Breakdown ---
desc_doc <- body_add_par(desc_doc, "Table. API Method Capability (METH) Distribution",
                          style = "heading 2")
if ("METH" %in% colnames(plat_firms)) {
  meth_dist_doc <- plat_firms %>%
    filter(!is.na(METH)) %>%
    count(METH = as.integer(METH)) %>%
    mutate(`%` = round(100 * n / sum(n), 1),
           Level = case_when(
             METH == 0 ~ "No API methods",
             METH == 1 ~ "Read-only (GET)",
             METH == 2 ~ "Full CRUD (GET, POST, PUT, DELETE)",
             TRUE       ~ paste("Level", METH)
           )) %>%
    select(METH, Level, n, `%`)

  ft_meth <- flextable(meth_dist_doc) %>%
    fontsize(size = 10, part = "all") %>%
    font(fontname = "Times New Roman", part = "all") %>%
    align(align = "center", part = "all") %>%
    align(j = "Level", align = "left", part = "body") %>%
    autofit() %>%
    hline_top(border = fp_border(width = 2), part = "header") %>%
    hline_bottom(border = fp_border(width = 1), part = "header") %>%
    hline_bottom(border = fp_border(width = 2), part = "body")

  desc_doc <- body_add_flextable(desc_doc, ft_meth)
  desc_doc <- body_add_par(desc_doc,
    sprintf("Note. N = %d PLAT firms. METH coding: 0 = no API methods documented; 1 = read-only (GET only); 2 = full CRUD (GET, POST, PUT, DELETE). Used in Za composite as METH/2.",
            nrow(plat_firms)),
    style = "Normal")
  desc_doc <- body_add_par(desc_doc, "", style = "Normal")
}

# --- Table: Composite Score Descriptives ---
desc_doc <- body_add_par(desc_doc, "Table. Composite Score Descriptives (PLAT Firms)",
                          style = "heading 2")

# Add construct grouping column
comp_desc_apa <- comp_desc %>%
  mutate(Construct = comp_category[Variable]) %>%
  select(Construct, Variable, everything())

ft_comp <- flextable(comp_desc_apa) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1:2, align = "left", part = "body") %>%
  align(j = 3:ncol(comp_desc_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  merge_v(j = "Construct")

desc_doc <- body_add_flextable(desc_doc, ft_comp)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT firms. Platform Resources (PR) = (Za + Zd + ZAI + Zs + Zg) / 5. Each class: raw = detected resources / total in class; Z = standardized across firms. Platform Accessibility (EA) = (Z_LV + Z_PLV) / 2, where Z_LV = Z-standardized LINGUISTIC_VARIETY and Z_PLV = Z-standardized programming_lang_variety. See Codebook Section 9.",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Dyad-Level Variable Descriptives ---
desc_doc <- body_add_par(desc_doc, "Table. Dyad-Level Variable Descriptives (PLAT Dyads)",
                          style = "heading 2")

ft_dyad <- flextable(dyad_desc) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(dyad_desc), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_dyad)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT dyads.", nrow(plat_dyads)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Industry Summary ---
desc_doc <- body_add_par(desc_doc, "Table. Resource Intensity and Performance by Industry",
                          style = "heading 2")

ft_ind <- flextable(ind_summary) %>%
  set_header_labels(IND = "Industry", n_firms = "Firms", n_dyads = "Dyads",
                    n_countries = "Countries", mean_PR = "M(PR)", sd_PR = "SD(PR)",
                    mean_PA = "M(EA)", mean_DV = "M(DV)", sd_DV = "SD(DV)") %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(ind_summary), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_ind)
desc_doc <- body_add_par(desc_doc,
  "Note. PR = Platform Resources composite. EA = Platform Accessibility. DV = Annualized Market Share Change (pp/year).",
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Binary Resource Adoption by Industry ---
desc_doc <- body_add_par(desc_doc, "Table. Binary Resource Adoption by Industry (% of PLAT Firms)",
                          style = "heading 2")

# Transpose ind_binary for readability: rows = resources, columns = industries
ind_binary_t <- ind_binary %>%
  select(-n) %>%
  tidyr::pivot_longer(-IND, names_to = "Resource", values_to = "pct") %>%
  tidyr::pivot_wider(names_from = IND, values_from = pct)

# Add overall % from binary_desc
ind_binary_t <- ind_binary_t %>%
  left_join(
    binary_desc %>% select(Variable, pct) %>% rename(Resource = Variable, Overall = pct),
    by = "Resource"
  ) %>%
  relocate(Overall, .after = Resource)

ft_ind_bin <- flextable(ind_binary_t) %>%
  fontsize(size = 7, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(ind_binary_t), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_par(desc_doc, "", style = "Normal")
desc_doc <- body_add_flextable(desc_doc, ft_ind_bin)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. Values are percentage of PLAT firms (N = %d) within each industry that have the resource (= 1). Overall = full PLAT sample. Resources shown: Application (API), Development (DEVP, DOCS, SDK, BUG, STAN), AI (AI_MODEL, AI_AGENT), Social (GIT, MON, COM_forum, COM_blog, COM_training), Governance (ROLE, DATA, STORE, CERT).",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Count/Ordinal Variables by Industry ---
desc_doc <- body_add_par(desc_doc, "Table. Count/Ordinal Resource Means by Industry (PLAT Firms)",
                          style = "heading 2")

# Transpose ind_count: rows = variables, columns = industries
ind_count_t <- ind_count %>%
  select(-n) %>%
  tidyr::pivot_longer(-IND, names_to = "Variable", values_to = "mean") %>%
  tidyr::pivot_wider(names_from = IND, values_from = mean)

# Add overall mean from count_desc
ind_count_t <- ind_count_t %>%
  left_join(
    count_desc %>% select(Variable, Mean) %>% rename(Overall = Mean),
    by = "Variable"
  ) %>%
  relocate(Overall, .after = Variable)

ft_ind_cnt <- flextable(ind_count_t) %>%
  fontsize(size = 7, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(ind_count_t), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_par(desc_doc, "", style = "Normal")
desc_doc <- body_add_flextable(desc_doc, ft_ind_cnt)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. Values are means across PLAT firms (N = %d) within each industry. METH = API method capability (0–2 ordinal); COM = count of communication channels (0–10); EVENT = count of event types (0–6); SPAN = count of boundary spanning mechanisms (0–3); LINGUISTIC_VARIETY = count of distinct natural languages across 8 resources; programming_lang_variety = count of unique programming languages across SDK, GIT, BUG.",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: PLAT Type Summary ---
desc_doc <- body_add_par(desc_doc, "Table. Resource Profile by Platform Access Type",
                          style = "heading 2")

plat_type_apa <- plat_type_summary %>%
  rename(`Access Type` = PLAT, N = n,
         `M(PR)` = mean_PR, `SD(PR)` = sd_PR,
         `M(Za)` = mean_Za, `M(Zd)` = mean_Zd, `M(Zai)` = mean_Zai,
         `M(Zs)` = mean_Zs, `M(Zg)` = mean_Zg,
         `M(EA)` = mean_PA, `SD(EA)` = sd_PA,
         `% API` = pct_API, `% SDK` = pct_SDK, `% GIT` = pct_GIT)

ft_plat <- flextable(plat_type_apa) %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_plat)
desc_doc <- body_add_par(desc_doc,
  "Note. Za-Zg = standardized category composites (Application, Development, AI, Social, Governance). PR = overall Platform Resources. EA = Platform Accessibility.",
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Correlation Matrix (lower triangle, numbered, portrait-friendly) ---
desc_doc <- body_add_par(desc_doc, "Table. Bivariate Correlations Among SEM Variables",
                          style = "heading 2")

# Set fixed narrow column widths: variable name wider, number columns tight
# Landscape page = 11" - 2×1" margins = 9" usable
# Cols: Variable (1.6") + M (0.40") + SD (0.40") + 15 corr cols × 0.40" = 8.4"
var_col_width <- 1.6
desc_col_width <- 0.40
cor_col_width  <- 0.40

# Column indices: 1 = Variable, 2 = M, 3 = SD, 4+ = correlation numbers
cor_num_start <- 4
cor_num_end   <- ncol(cor_df)

ft_cor <- flextable(cor_df) %>%
  fontsize(size = 7, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(cor_df), align = "center", part = "body") %>%
  width(j = 1, width = var_col_width) %>%
  width(j = 2:3, width = desc_col_width) %>%
  width(j = cor_num_start:cor_num_end, width = cor_col_width) %>%
  padding(padding.left = 1, padding.right = 1, part = "all") %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_cor)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT dyads. Pairwise complete observations. Values are Pearson correlation coefficients (r). Em-dash (\u2014) on diagonal.\n*p < .05. **p < .01. ***p < .001.",
          nrow(plat_dyads)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: GLOBE Cluster Summary ---
desc_doc <- body_add_par(desc_doc, "Table. Performance and Cultural Distance by GLOBE Cluster",
                          style = "heading 2")

ft_reg <- flextable(cluster_summary) %>%
  set_header_labels(host_cluster = "GLOBE Cluster", n_dyads = "Dyads", n_firms = "Firms",
                    n_countries = "Countries", mean_DV = "M(DV)", sd_DV = "SD(DV)",
                    mean_CD = "M(CD)") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(cluster_summary), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_reg)
desc_doc <- body_add_par(desc_doc,
  "Note. DV = Annualized Market Share Change (pp/year). CD = Cultural Distance (Kogut-Singh index). GLOBE clusters from House et al. (2004).",
  style = "Normal")

# --- Table: Sample Attrition (Analytic Sample) ---
desc_doc <- body_add_par(desc_doc,
  "Table. Sample Attrition: Missing Data by SEM Variable",
  style = "heading 2")

attrition_apa <- attrition_detail %>%
  rename(`N Available` = N_available, `N Missing` = N_missing,
         `% Missing` = Pct_missing)

ft_att <- flextable(attrition_apa) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(attrition_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_att)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %s PLAT dyads. SEM estimation uses listwise deletion; %s dyads (%.1f%%) are retained as the analytic sample with complete data on all variables.",
          format(n_full_plat, big.mark = ","),
          format(n_sem_ready, big.mark = ","),
          100 * n_sem_ready / n_full_plat),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: SEM Coverage by Industry ---
desc_doc <- body_add_par(desc_doc,
  "Table. Analytic Sample Coverage by Industry",
  style = "heading 2")

sem_ind_apa <- sem_by_ind_full %>%
  rename(Industry = IND, `Full Dyads` = full_dyads,
         `SEM Dyads` = sem_dyads, `% Retained` = pct_retained,
         `Full Firms` = full_firms, `SEM Firms` = sem_firms,
         `% Firms` = pct_firms)

ft_sem_ind <- flextable(sem_ind_apa) %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(sem_ind_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  hline(i = nrow(sem_ind_apa) - 1, border = fp_border(width = 1), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_sem_ind)
desc_doc <- body_add_par(desc_doc,
  "Note. Full = all PLAT dyads. SEM = dyads with complete data on all SEM variables (platform resources, platform accessibility, market share change, cultural distance, industry growth, host GDP, host internet penetration, home GDP). % Retained = proportion of full sample available for hypothesis testing.",
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: SEM Coverage by PLAT Type ---
desc_doc <- body_add_par(desc_doc,
  "Table. Analytic Sample Coverage by Platform Access Type",
  style = "heading 2")

sem_plat_apa <- sem_by_plat %>%
  rename(`Access Type` = PLAT, `Full Dyads` = full_dyads,
         `SEM Dyads` = sem_dyads, `% Retained` = pct_retained,
         `Full Firms` = full_firms, `SEM Firms` = sem_firms,
         `% Firms` = pct_firms)

ft_sem_plat <- flextable(sem_plat_apa) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(sem_plat_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_sem_plat)
desc_doc <- body_add_par(desc_doc,
  "Note. Public = openly accessible developer portal. Registration = free account required. Restricted = invitation, partnership, or NDA required.",
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Full vs. SEM Sample Comparison ---
desc_doc <- body_add_par(desc_doc,
  "Table. Comparison of Full and Analytic Samples on Key Variables",
  style = "heading 2")

comp_apa <- sample_comparison %>%
  rename(`Full N` = Full_N, `Full M` = Full_Mean, `Full SD` = Full_SD,
         `SEM N` = SEM_N, `SEM M` = SEM_Mean, `SEM SD` = SEM_SD,
         `Diff (d)` = Diff_pct)

ft_comp_samp <- flextable(comp_apa) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(comp_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_comp_samp)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. Full = all %s PLAT dyads. SEM = %s dyads with complete data. Diff (d) = difference between sample means expressed as a percentage of the full sample SD. Values near zero indicate minimal selection bias from listwise deletion.",
          format(n_full_plat, big.mark = ","),
          format(n_sem_ready, big.mark = ",")),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Analytic Sample Composite Descriptives ---
desc_doc <- body_add_par(desc_doc,
  "Table. Composite Score Descriptives (Analytic Sample, Firm-Level)",
  style = "heading 2")

ft_sem_comp <- flextable(sem_comp_desc) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(sem_comp_desc), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_sem_comp)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT firms in analytic sample (firms with at least one SEM-ready dyad). Raw = detected resources / total in class. Z = standardized across firms. PR = (Za + Zd + ZAI + Zs + Zg) / 5. EA = (Z_LV + Z_PLV) / 2.",
          n_firms_sem),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Table: Analytic Sample Dyad-Level Descriptives ---
desc_doc <- body_add_par(desc_doc,
  "Table. Dyad-Level Variable Descriptives (Analytic Sample)",
  style = "heading 2")

ft_sem_dyad <- flextable(sem_dyad_desc) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(sem_dyad_desc), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_sem_dyad)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %s PLAT dyads in analytic sample (complete data on all SEM variables).",
          format(n_sem_ready, big.mark = ",")),
  style = "Normal")

# --- G2 Cluster Profile Tables ---
for (k in 3:5) {
  kcol <- paste0("cluster_k", k)
  if (kcol %in% colnames(cluster_data)) {
    # Cluster centroids
    clust_prof <- cluster_data %>%
      group_by(!!sym(kcol)) %>%
      summarize(
        n = n(),
        across(all_of(cluster_vars), ~round(mean(., na.rm = TRUE), 3)),
        .groups = "drop"
      ) %>%
      rename(Cluster = !!sym(kcol))

    desc_doc <- body_add_par(desc_doc,
      sprintf("Table G2. Cluster Centroids for k = %d Solution (N = %d)", k, sum(clust_prof$n)),
      style = "heading 3")
    ft_clust <- flextable(clust_prof) %>%
      colformat_double(digits = 2) %>%
      set_header_labels(
        raw_application = "Application",
        raw_development = "Development",
        raw_ai = "AI",
        raw_social = "Social",
        raw_governance = "Governance") %>%
      theme_booktabs() %>%
      autofit()
    desc_doc <- body_add_flextable(desc_doc, ft_clust)
    desc_doc <- body_add_par(desc_doc,
      sprintf("Note. Values represent mean raw sub-index scores (0-1 scale) for each cluster. N = %d PLAT firms.",
              sum(clust_prof$n)),
      style = "Normal")
    desc_doc <- body_add_par(desc_doc, "", style = "Normal")

    # PLAT distribution per cluster
    plat_dist <- cluster_data %>%
      group_by(!!sym(kcol), PLAT) %>%
      summarize(n = n(), .groups = "drop") %>%
      pivot_wider(names_from = PLAT, values_from = n, values_fill = 0) %>%
      rename(Cluster = !!sym(kcol))

    desc_doc <- body_add_par(desc_doc,
      sprintf("Table G2. PLAT Access Type Distribution by Cluster, k = %d", k),
      style = "heading 3")
    ft_plat_clust <- flextable(plat_dist) %>%
      theme_booktabs() %>%
      autofit()
    desc_doc <- body_add_flextable(desc_doc, ft_plat_clust)
    desc_doc <- body_add_par(desc_doc,
      "Note. PLAT = platform access type. Public = open; Registration = developer sign-up required; Restricted = approval required.",
      style = "Normal")
    desc_doc <- body_add_par(desc_doc, "", style = "Normal")
  }
}

# Save Word document
desc_word_path <- file.path(tables_path, "08_Descriptive_Tables_APA.docx")
print(desc_doc, target = desc_word_path)
cat("\n✓ APA descriptive tables saved to:", desc_word_path, "\n")

# ============================================================================
# SAVE ALL DESCRIPTIVE DATA
# ============================================================================

cat("\n✓ Script 08 complete.\n")
cat("  Outputs:\n")
cat("    08_Descriptive_Tables_APA.docx (16 APA tables)\n")
cat("    correlation_matrix_sem_vars.csv\n")
cat("    platform_cluster_assignments.csv\n")
cat("    08_sem_coverage_by_industry.csv\n")
cat("    08_sem_sample_comparison.csv\n")
cat("  Next: Run 09_sem_moderated_mediation.R for model estimation.\n")
