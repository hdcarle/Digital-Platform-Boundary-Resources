# ============================================================================
# 04 - IMPORT COUNTRY-LEVEL CONTROL VARIABLES (GDP, POPULATION, INTERNET)
# ============================================================================
# Author: Heather Carle
# Purpose: Import GDP per capita, population, and internet user % for both
#          home and host countries, then merge to analytic codebook
# Input:   MASTER_CODEBOOK_analytic.xlsx (from script 03)
#          WDI_GDP_Population_2024_Cleaned.xlsx (World Bank)
#          Passport_Stats_14-12-2025_1840_GMT.xls (Euromonitor internet data)
# Output:  MASTER_CODEBOOK_analytic.xlsx (updated with country controls)
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

# Input: analytic codebook (from script 03, with NL exclusion applied)
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")

# WDI data (pre-cleaned download from World Bank)
wdi_path <- file.path(base_path, "dissertation data", "Control data",
                      "WDI_GDP_Population_2024_Cleaned.xlsx")

# Euromonitor internet user data
internet_path <- file.path(base_path, "dissertation data",
                           "Internet user data",
                           "Internet_Users_Converted.csv")

# ============================================================================
# SECTION 3: LOAD ANALYTIC CODEBOOK
# ============================================================================

cat("Loading analytic codebook...\n")
mc <- read_excel(codebook_path)
cat("  Rows:", nrow(mc), " Columns:", ncol(mc), "\n")
cat("  Unique home countries:", n_distinct(mc$home_country_iso3c), "\n")
cat("  Unique host countries:", n_distinct(mc$host_country_iso3c), "\n")
cat("  All unique ISO3 codes:", n_distinct(c(mc$home_country_iso3c,
                                             mc$host_country_iso3c)), "\n\n")

# ============================================================================
# SECTION 4: LOAD WDI DATA (GDP + POPULATION)
# ============================================================================

cat("=== LOADING WDI DATA ===\n\n")

wdi <- read_excel(wdi_path)
cat("  WDI rows:", nrow(wdi), "\n")
cat("  Columns:", paste(colnames(wdi), collapse = ", "), "\n\n")

# Standardize column names
wdi <- wdi %>%
  rename(
    iso3c        = ISO_Code,
    country_name = Country,
    gdp_usd      = GDP_current_USD_2024,
    population   = Population_2024
  ) %>%
  filter(!is.na(iso3c)) %>%
  mutate(
    gdp_usd    = as.numeric(gdp_usd),
    population = as.numeric(population),
    # Compute GDP per capita
    gdp_per_capita = ifelse(population > 0, gdp_usd / population, NA_real_)
  )

cat("  Countries with GDP per capita:", sum(!is.na(wdi$gdp_per_capita)), "\n")
cat("  Countries with population:", sum(!is.na(wdi$population)), "\n\n")

# ----- ADD TAIWAN MANUALLY -----
# Taiwan is not in World Bank data. Values from IMF World Economic Outlook 2024.
# GDP: $782.44 billion (current USD) / Population: 23,112,793
# Internet: handled separately from Euromonitor

taiwan_row <- tibble(
  iso3c          = "TWN",
  country_name   = "Taiwan",
  gdp_usd        = 782440000000,
  population     = 23112793,
  gdp_per_capita = 782440000000 / 23112793  # ~$33,856
)

# Only add if Taiwan not already in WDI
if (!"TWN" %in% wdi$iso3c) {
  wdi <- bind_rows(wdi, taiwan_row)
  cat("  ✓ Taiwan added manually (IMF WEO 2024)\n")
  cat("    GDP per capita: $", round(taiwan_row$gdp_per_capita), "\n")
  cat("    Population:", format(taiwan_row$population, big.mark = ","), "\n\n")
}

# ----- CHECK COVERAGE FOR OUR 65 COUNTRIES -----
our_isos <- unique(c(mc$home_country_iso3c, mc$host_country_iso3c))
wdi_coverage <- wdi %>% filter(iso3c %in% our_isos)

cat("=== WDI COVERAGE ===\n")
cat("  Countries needed:", length(our_isos), "\n")
cat("  Countries found in WDI:", nrow(wdi_coverage), "\n")

missing_wdi <- setdiff(our_isos, wdi$iso3c)
if (length(missing_wdi) > 0) {
  cat("  MISSING from WDI:", paste(missing_wdi, collapse = ", "), "\n")
} else {
  cat("  ✓ All countries covered\n")
}

missing_gdp <- our_isos[!our_isos %in% wdi$iso3c[!is.na(wdi$gdp_per_capita)]]
missing_pop <- our_isos[!our_isos %in% wdi$iso3c[!is.na(wdi$population)]]
if (length(missing_gdp) > 0) cat("  Missing GDP:", paste(missing_gdp, collapse = ", "), "\n")
if (length(missing_pop) > 0) cat("  Missing Pop:", paste(missing_pop, collapse = ", "), "\n")
cat("\n")

# ============================================================================
# SECTION 5: LOAD EUROMONITOR INTERNET USER DATA
# ============================================================================

cat("=== LOADING EUROMONITOR INTERNET DATA ===\n\n")

# Euromonitor Passport files have metadata rows at top
# Header row contains "Geography" in column 1
raw_internet <- read.csv(internet_path, header = FALSE, stringsAsFactors = FALSE)

# Find header row
header_row <- which(raw_internet[[1]] == "Geography")
cat("  Header found at row:", header_row, "\n")

# Set column names
headers <- as.character(raw_internet[header_row, ])
internet_data <- raw_internet[(header_row + 1):nrow(raw_internet), ]
colnames(internet_data) <- headers

# Filter to "Percentage of Population Using The Internet" category
internet_pct <- internet_data %>%
  filter(Category == "Percentage of Population Using The Internet") %>%
  filter(!is.na(Geography)) %>%
  filter(!str_detect(Geography, "Source|Exported|Euromonitor|©|Research|Date"))

cat("  Countries with internet %:", nrow(internet_pct), "\n")
cat("  Years available:", paste(headers[6:length(headers)], collapse = ", "), "\n\n")

# ----- COUNTRY NAME TO ISO3C MAPPING -----
# Euromonitor uses country names; we need ISO3c to match MASTER_CODEBOOK
# Build a lookup from the codebook's existing country names to iso3c

# Create mapping from both home and host country names in codebook
name_to_iso <- mc %>%
  select(host_country_name, host_country_iso3c) %>%
  distinct() %>%
  rename(country_name = host_country_name, iso3c = host_country_iso3c)

name_to_iso <- bind_rows(
  name_to_iso,
  mc %>%
    select(home_country_name, home_country_iso3c) %>%
    distinct() %>%
    rename(country_name = home_country_name, iso3c = home_country_iso3c)
) %>%
  distinct()

# Euromonitor country name harmonization
# (matching the pattern from 02_ind_grow.R)
euro_to_codebook <- c(
  "USA"                = "United States",
  "Hong Kong, China"   = "Hong Kong SAR China",
  "South Korea"        = "South Korea",
  "Czech Republic"     = "Czech Republic",
  "Russia"             = "Russia",
  "Turkey"             = "Turkey",
  "Taiwan"             = "Taiwan",
  "Vietnam"            = "Vietnam"
)

# Get the most recent year column (2024) for internet %
# Use the last numeric year column
year_cols <- headers[6:length(headers)]
latest_year <- year_cols[length(year_cols)]
cat("  Using internet data from year:", latest_year, "\n\n")

# Extract internet % and harmonize country names
internet_clean <- internet_pct %>%
  select(Geography, all_of(latest_year)) %>%
  rename(
    euro_name    = Geography,
    internet_pct = !!latest_year
  ) %>%
  mutate(
    internet_pct = as.numeric(internet_pct),
    # Harmonize Euromonitor names to MASTER_CODEBOOK names
    country_name = case_when(
      euro_name %in% names(euro_to_codebook) ~ euro_to_codebook[euro_name],
      TRUE ~ euro_name
    )
  )

# Join to get ISO3c codes
internet_with_iso <- internet_clean %>%
  left_join(name_to_iso, by = "country_name")

# Check coverage
our_iso_internet <- internet_with_iso %>%
  filter(iso3c %in% our_isos)

cat("=== INTERNET DATA COVERAGE ===\n")
cat("  Countries needed:", length(our_isos), "\n")
cat("  Matched:", nrow(our_iso_internet), "\n")

missing_internet <- setdiff(our_isos, our_iso_internet$iso3c)
if (length(missing_internet) > 0) {
  cat("  MISSING internet data:", paste(missing_internet, collapse = ", "), "\n")

  # Try to find matches by looking at unmatched Euromonitor names
  unmatched_euro <- internet_with_iso %>%
    filter(is.na(iso3c)) %>%
    pull(euro_name)

  cat("  Unmatched Euromonitor names (first 20):\n")
  cat("   ", paste(head(unmatched_euro, 20), collapse = ", "), "\n")
} else {
  cat("  ✓ All countries covered\n")
}
cat("\n")

# ============================================================================
# SECTION 6: COMBINE INTO COUNTRY-LEVEL CONTROLS TABLE
# ============================================================================

cat("=== BUILDING COUNTRY CONTROLS TABLE ===\n\n")

# Start with WDI data for our countries
country_controls <- wdi %>%
  filter(iso3c %in% our_isos) %>%
  select(iso3c, country_name, gdp_per_capita, population)

# Add internet data
country_controls <- country_controls %>%
  left_join(
    our_iso_internet %>% select(iso3c, internet_pct),
    by = "iso3c"
  )

# Log-transform GDP per capita (standard in international business research)
country_controls <- country_controls %>%
  mutate(
    log_gdp_per_capita = log(gdp_per_capita)
  )

cat("Country controls table:\n")
cat("  Countries:", nrow(country_controls), "\n")
cat("  GDP per capita: ",
    sum(!is.na(country_controls$gdp_per_capita)), "non-null\n")
cat("  Population: ",
    sum(!is.na(country_controls$population)), "non-null\n")
cat("  Internet %: ",
    sum(!is.na(country_controls$internet_pct)), "non-null\n\n")

# Summary statistics
cat("=== SUMMARY STATISTICS ===\n\n")

cat("GDP per capita (current USD):\n")
print(summary(country_controls$gdp_per_capita))
cat("SD:", sd(country_controls$gdp_per_capita, na.rm = TRUE), "\n\n")

cat("Log GDP per capita:\n")
print(summary(country_controls$log_gdp_per_capita))
cat("SD:", sd(country_controls$log_gdp_per_capita, na.rm = TRUE), "\n\n")

cat("Population:\n")
print(summary(country_controls$population))
cat("\n")

cat("Internet users (% of population):\n")
print(summary(country_controls$internet_pct))
cat("SD:", sd(country_controls$internet_pct, na.rm = TRUE), "\n\n")

# ============================================================================
# SECTION 7: MERGE TO MASTER_CODEBOOK (HOME + HOST)
# ============================================================================

cat("=== MERGING CONTROLS TO CODEBOOK ===\n\n")

# Clear existing control columns if they exist (they're currently empty/0%)
control_cols <- c("home_gdp_per_capita", "home_internet_users", "home_population",
                  "host_gdp_per_capita", "host_Internet_users", "host_population")

for (col in control_cols) {
  if (col %in% colnames(mc)) {
    mc[[col]] <- NULL
    cat("  Cleared existing column:", col, "\n")
  }
}

# ----- JOIN HOME COUNTRY CONTROLS -----
mc <- mc %>%
  left_join(
    country_controls %>%
      select(iso3c, gdp_per_capita, population, internet_pct,
             log_gdp_per_capita) %>%
      rename(
        home_gdp_per_capita     = gdp_per_capita,
        home_population         = population,
        home_internet_users     = internet_pct,
        home_log_gdp_per_capita = log_gdp_per_capita
      ),
    by = c("home_country_iso3c" = "iso3c")
  )

# ----- JOIN HOST COUNTRY CONTROLS -----
mc <- mc %>%
  left_join(
    country_controls %>%
      select(iso3c, gdp_per_capita, population, internet_pct,
             log_gdp_per_capita) %>%
      rename(
        host_gdp_per_capita     = gdp_per_capita,
        host_population         = population,
        host_Internet_users     = internet_pct,
        host_log_gdp_per_capita = log_gdp_per_capita
      ),
    by = c("host_country_iso3c" = "iso3c")
  )

cat("\n  ✓ Home and host country controls merged\n\n")

# ============================================================================
# SECTION 8: DIAGNOSTICS
# ============================================================================

cat("=== MERGE DIAGNOSTICS ===\n\n")

# Fill rates
diag_cols <- c("home_gdp_per_capita", "home_population", "home_internet_users",
               "home_log_gdp_per_capita",
               "host_gdp_per_capita", "host_population", "host_Internet_users",
               "host_log_gdp_per_capita")

for (col in diag_cols) {
  if (col %in% colnames(mc)) {
    n_filled <- sum(!is.na(mc[[col]]))
    pct <- round(100 * n_filled / nrow(mc), 1)
    cat(sprintf("  %-30s %d/%d (%s%%)\n", col, n_filled, nrow(mc), pct))
  } else {
    cat(sprintf("  %-30s COLUMN NOT FOUND\n", col))
  }
}

# Check for missing home countries
cat("\n=== MISSING HOME COUNTRY DATA ===\n")
missing_home <- mc %>%
  filter(is.na(home_gdp_per_capita)) %>%
  distinct(home_country_iso3c, home_country_name)

if (nrow(missing_home) > 0) {
  print(missing_home)
} else {
  cat("  ✓ All home countries have GDP data\n")
}

# Check for missing host countries
cat("\n=== MISSING HOST COUNTRY DATA ===\n")
missing_host <- mc %>%
  filter(is.na(host_gdp_per_capita)) %>%
  distinct(host_country_iso3c, host_country_name)

if (nrow(missing_host) > 0) {
  print(missing_host)
} else {
  cat("  ✓ All host countries have GDP data\n")
}

# Quick correlation between home and host GDP
cat("\n=== HOME vs HOST GDP CORRELATION ===\n")
r_gdp <- cor(mc$home_gdp_per_capita, mc$host_gdp_per_capita,
             use = "complete.obs")
cat("Pearson r (GDP per capita):", round(r_gdp, 3), "\n")

# Distribution by industry
cat("\n=== HOST GDP PER CAPITA BY INDUSTRY ===\n")
mc %>%
  group_by(IND) %>%
  summarize(
    n_dyads   = n(),
    mean_gdp  = round(mean(host_gdp_per_capita, na.rm = TRUE)),
    mean_pop  = round(mean(host_population, na.rm = TRUE)),
    mean_inet = round(mean(host_Internet_users, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(IND) %>%
  print(n = 12)

# ============================================================================
# SECTION 9: SAVE
# ============================================================================

write_xlsx(mc, codebook_path)
cat("\n✓ Saved updated codebook to:", codebook_path, "\n")
cat("  New columns: home/host_gdp_per_capita, home/host_population,\n")
cat("               home/host_internet_users, home/host_log_gdp_per_capita\n")
cat("  ", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "unique platforms\n")

cat("\n✓ Script 04 complete. Country controls merged.\n")
cat("  Next: Run 05 for remaining controls (cultural distance, etc.)\n")
