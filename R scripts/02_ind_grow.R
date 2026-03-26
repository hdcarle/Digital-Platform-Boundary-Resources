# ============================================================================
# 02 - IMPORT INDUSTRY GROWTH (IND_GROW) CONTROL VARIABLE
# ============================================================================
# Author: Heather Carle
# Purpose: Import 5-year industry growth rates from Euromonitor files and
#          merge to MASTER_CODEBOOK as the IND_GROW control variable
# Input:   MASTER_CODEBOOK_with_DV.xlsx (from 01_import_and_dv.R)
#          11 industry folders with 5-year period growth .xls files
# Output:  MASTER_CODEBOOK_with_DV.xlsx (updated with IND_GROW)
# Last Updated: February 2026
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

# Install if needed (uncomment and run once)
 install.packages(c("readxl", "dplyr", "tidyr", "stringr", "writexl"))

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"

# Input: codebook with DV already computed (from script 01)
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_with_DV.xlsx")

# Industry growth files folder (pre-converted CSVs)
ind_data_path <- file.path(base_path, "dissertation data",
                           "platform market share data", "csv_converted")

# ============================================================================
# SECTION 3: LOAD MASTER_CODEBOOK
# ============================================================================

cat("Loading MASTER_CODEBOOK_with_DV...\n")
mc <- read_excel(codebook_path)
cat("  Rows:", nrow(mc), "  Columns:", ncol(mc), "\n\n")

# ============================================================================
# SECTION 4: DEFINE INDUSTRY-TO-FILE MAPPING
# ============================================================================

# Each entry maps:
#   IND (as it appears in MASTER_CODEBOOK) →
#   folder name, filename, category to filter on, growth column name

ind_file_map <- tribble(
  ~IND,                                    ~csv_file,                                      ~category_filter,                      ~growth_col,
  "Computers and Peripherals",             "COMPUTERS_AND_PERIPHERALS_5yr_growth.csv",     "Computers and Peripherals",           "2020 - 2025 %",
  "Credit Card Transactions",              "FINANCIAL_CARDS_5yr_growth.csv",               "Credit Card Transactions",            "2020 - 2025 %",
  "Consumer Foodservice Online Ordering",  "FOODSERVICE_5yr_growth.csv",                   "Consumer Foodservice Online Ordering", "2019 - 2024 %",
  "In-Car Entertainment",                  "IN_CAR_ENTERTAINMENT_5yr_growth.csv",          "In-Car Entertainment",                "2020 - 2025 %",
  "In-Home Consumer Electronics",          "IN_HOME_CONSUMER_ELECTRONICS_5yr_growth.csv",  "In-Home Consumer Electronics",        "2020 - 2025 %",
  "Lodging (Destination)",                 "LODGING_5yr_growth.csv",                       "Lodging (Destination)",               "2020 - 2025 %",
  "Portable Consumer Electronics",         "PORTABLE_CONSUMER_ELECTRONICS_5yr_growth.csv", "Portable Consumer Electronics",       "2020 - 2025 %",
  "Traditional Toys and Games",            "TRADITIONAL_TOYS_AND_GAMES_5yr_growth.csv",    "Traditional Toys and Games",          "2019 - 2024 %",
  "Travel Modes",                          "TRAVEL_MODES_5yr_growth.csv",                  "Travel Modes",                        "2020 - 2025 %",
  "Video Game software",                   "VIDEO_GAME_5yr_growth.csv",                    "Video Games",                         "2019 - 2024 %"
)

cat("Industry mapping defined for", nrow(ind_file_map), "industries.\n\n")

# ============================================================================
# SECTION 5: COUNTRY NAME HARMONIZATION
# ============================================================================

# Euromonitor files use slightly different country names than MASTER_CODEBOOK
# This lookup standardizes them

country_harmonize <- c(
  "USA"              = "United States",
  "Hong Kong, China" = "Hong Kong SAR China"
  # Add more mappings here if needed after diagnostics
)

harmonize_country <- function(name) {
  ifelse(name %in% names(country_harmonize),
         country_harmonize[name],
         name)
}

# ============================================================================
# SECTION 6: READ AND COMBINE INDUSTRY GROWTH FILES
# ============================================================================

# Helper function to read one Euromonitor 5-year growth file
# These files have headers starting at variable rows, so we detect them
read_growth_file <- function(csv_file, category_filter, growth_col) {

  # Read the pre-converted CSV file
  file_path <- file.path(ind_data_path, csv_file)

  if (!file.exists(file_path)) {
    cat("  WARNING: CSV file not found:", csv_file, "\n")
    return(NULL)
  }

  cat("  Reading:", csv_file, "\n")
  raw <- read.csv(file_path, header = FALSE, stringsAsFactors = FALSE)

  # Find the header row (row containing "Geography")
  header_row <- which(raw[[1]] == "Geography")
  if (length(header_row) == 0) {
    cat("  WARNING: Could not find 'Geography' header in", files[1], "\n")
    return(NULL)
  }

  # Set column names from header row
  headers <- as.character(raw[header_row[1], ])
  data <- raw[(header_row[1] + 1):nrow(raw), ]
  colnames(data) <- headers

  # Remove footer rows (sources, copyright, blanks)
  data <- data %>%
    filter(!is.na(Geography)) %>%
    filter(!str_detect(Geography,
                       "Source|Exported|Euromonitor|©|Research|Date"))

  # Filter to the target category
  if (!is.null(category_filter)) {
    data <- data %>% filter(Category == category_filter)
  }

  # Some industries have both "modelled" and non-modelled rows for same country
  # Keep the non-modelled version when both exist
  if (any(str_detect(data$Category, "modelled"))) {
    non_modelled <- data %>% filter(!str_detect(Category, "modelled"))
    modelled_only <- data %>%
      filter(str_detect(Category, "modelled")) %>%
      filter(!Geography %in% non_modelled$Geography)
    data <- bind_rows(non_modelled, modelled_only)
  }

  # Extract Geography and growth %
  if (!growth_col %in% colnames(data)) {
    cat("  WARNING: Growth column '", growth_col, "' not found. ",
        "Available:", paste(colnames(data), collapse = ", "), "\n")
    return(NULL)
  }

  result <- data %>%
    select(Geography, all_of(growth_col)) %>%
    rename(
      host_country_name = Geography,
      IND_GROW = !!growth_col
    ) %>%
    mutate(
      # Harmonize country names to match MASTER_CODEBOOK
      host_country_name = harmonize_country(host_country_name),
      # Convert to numeric (some cells may have "-" for missing)
      IND_GROW = as.numeric(IND_GROW)
    )

  return(result)
}

# Loop through all industries and combine
cat("=== READING INDUSTRY GROWTH FILES ===\n\n")

all_growth <- list()

for (i in seq_len(nrow(ind_file_map))) {
  ind_name    <- ind_file_map$IND[i]
  csv_file    <- ind_file_map$csv_file[i]
  cat_filter  <- ind_file_map$category_filter[i]
  growth_col  <- ind_file_map$growth_col[i]

  cat("[", i, "/", nrow(ind_file_map), "]", ind_name, "\n")

  result <- read_growth_file(csv_file, cat_filter, growth_col)

  if (!is.null(result)) {
    result$IND <- ind_name
    all_growth[[i]] <- result
    cat("  ✓", nrow(result), "countries\n\n")
  }
}

# Combine all industry growth data
ind_grow_df <- bind_rows(all_growth)

cat("=== COMBINED INDUSTRY GROWTH DATA ===\n")
cat("Total rows:", nrow(ind_grow_df), "\n")
cat("Industries:", n_distinct(ind_grow_df$IND), "\n")
cat("Countries:", n_distinct(ind_grow_df$host_country_name), "\n\n")

# ============================================================================
# SECTION 7: MERGE IND_GROW TO MASTER_CODEBOOK
# ============================================================================

cat("=== MERGING IND_GROW TO MASTER_CODEBOOK ===\n\n")

# Check current state
if ("IND_GROW" %in% colnames(mc)) {
  cat("  NOTE: IND_GROW column already exists. Replacing.\n")
  mc <- mc %>% select(-IND_GROW)
}

# Merge by IND + host_country_name
mc <- mc %>%
  left_join(
    ind_grow_df %>% select(IND, host_country_name, IND_GROW),
    by = c("IND", "host_country_name")
  )

# ============================================================================
# SECTION 8: DIAGNOSTICS
# ============================================================================

cat("=== IND_GROW DIAGNOSTICS ===\n\n")

n_total <- nrow(mc)
n_matched <- sum(!is.na(mc$IND_GROW))
n_missing <- sum(is.na(mc$IND_GROW))

cat("Total dyads:", n_total, "\n")
cat("IND_GROW matched:", n_matched,
    sprintf("(%.1f%%)\n", 100 * n_matched / n_total))
cat("IND_GROW missing:", n_missing,
    sprintf("(%.1f%%)\n\n", 100 * n_missing / n_total))

# Distribution
cat("=== DISTRIBUTION ===\n")
print(summary(mc$IND_GROW))
cat("SD:", sd(mc$IND_GROW, na.rm = TRUE), "\n\n")

# By industry
cat("=== IND_GROW BY INDUSTRY ===\n")
mc %>%
  group_by(IND) %>%
  summarize(
    n_dyads  = n(),
    n_grow   = sum(!is.na(IND_GROW)),
    pct_covered = round(100 * sum(!is.na(IND_GROW)) / n(), 1),
    mean_grow   = round(mean(IND_GROW, na.rm = TRUE), 1),
    median_grow = round(median(IND_GROW, na.rm = TRUE), 1),
    min_grow    = round(min(IND_GROW, na.rm = TRUE), 1),
    max_grow    = round(max(IND_GROW, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(IND) %>%
  print(n = 12)

# Unmatched countries (if any)
cat("\n=== UNMATCHED COUNTRIES ===\n")
unmatched <- mc %>%
  filter(is.na(IND_GROW)) %>%
  distinct(IND, host_country_name) %>%
  arrange(IND, host_country_name)

if (nrow(unmatched) > 0) {
  cat("Dyads missing IND_GROW by industry and country:\n")
  unmatched %>%
    group_by(IND) %>%
    summarize(
      n_missing_countries = n(),
      countries = paste(host_country_name, collapse = ", "),
      .groups = "drop"
    ) %>%
    print(n = 12, width = 120)
} else {
  cat("All dyads matched! No missing IND_GROW values.\n")
}

# ============================================================================
# SECTION 9: SAVE
# ============================================================================

# Overwrite the DV file with the new IND_GROW column added
write_xlsx(mc, codebook_path)
cat("\n✓ Saved updated codebook to:", codebook_path, "\n")
cat("  IND_GROW column added.\n")

# ============================================================================
# SECTION 10: CORRELATION CHECK (IND_GROW vs MKT_SHARE_CHANGE)
# ============================================================================

cat("\n=== QUICK CORRELATION CHECK ===\n")
both_valid <- mc %>% filter(!is.na(IND_GROW), !is.na(MKT_SHARE_CHANGE))
cat("Dyads with both IND_GROW and MKT_SHARE_CHANGE:", nrow(both_valid), "\n")

if (nrow(both_valid) > 30) {
  r <- cor(both_valid$IND_GROW, both_valid$MKT_SHARE_CHANGE)
  cat("Pearson r:", round(r, 3), "\n")
  cat("(This is the bivariate correlation before controlling for other factors.)\n")
  cat("A moderate positive r is expected — firms in growing industries\n")
  cat("tend to gain share, validating IND_GROW as a relevant control.\n")
}
#Run significance test
cor.test(mc$IND_GROW, mc$MKT_SHARE_CHANGE, use = "complete.obs")

cat("\n✓ Script 02 complete. IND_GROW merged to MASTER_CODEBOOK.\n")
cat("  Next: Run 03_composite_scores.R\n")
