# ============================================================================
# 01 - IMPORT MASTER_CODEBOOK & COMPUTE DEPENDENT VARIABLE
# ============================================================================
# Author: Heather Carle
# Purpose: Import MASTER_CODEBOOK, compute MKT_SHARE_CHANGE (5-year market
#          share change) and TIME_RANGE moderator variable
# Last Updated: February 2026
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

# Install if needed (uncomment and run once)
install.packages(c("readxl", "dplyr", "tidyr", "writexl", "ggplot2"))

library(readxl)
library(dplyr)
library(tidyr)
library(writexl)
library(ggplot2)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

# Set your base path - adjust if your Dissertation folder is elsewhere
base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"

# MASTER_CODEBOOK location
codebook_path <- file.path(base_path, "REFERENCE", "MASTER_CODEBOOK_analytic.xlsx")

# Output will go back to REFERENCE (updated codebook) and dissertation analysis
output_path <- file.path(base_path, "dissertation analysis")

# ============================================================================
# SECTION 3: IMPORT MASTER_CODEBOOK
# ============================================================================

cat("Loading MASTER_CODEBOOK...\n")
mc <- read_excel(codebook_path)

cat("  Rows:", nrow(mc), "\n")
cat("  Columns:", ncol(mc), "\n")
cat("  Unique platforms:", n_distinct(mc$platform_ID), "\n")
cat("  Unique dyads:", n_distinct(mc$Dyad_ID), "\n")
cat("  Industries:", paste(sort(unique(mc$IND)), collapse = ", "), "\n\n")

# ============================================================================
# SECTION 4: DEFINE 5-YEAR WINDOWS BY INDUSTRY
# ============================================================================

# Industries with 2019 data but no 2025 → window is 2019-2024
# Industries with 2025 data but no 2019 → window is 2020-2025
# This is based on Euromonitor data availability per industry

window_lookup <- tribble(
  ~IND,                                ~start_year, ~end_year,
  "Video Game software",               "2019",      "2024",
  "Credit Card Transactions",          "2019",      "2024",
  "Consumer Foodservice Online Ordering", "2019",   "2024",
  "Computers and Peripherals",         "2020",      "2025",
  "In-Car Entertainment",              "2020",      "2025",
  "In-Home Consumer Electronics",      "2020",      "2025",
  "Lodging (Destination)",             "2020",      "2025",
  "Portable Consumer Electronics",     "2020",      "2025",
  "Traditional Toys and Games",        "2020",      "2025",
  "Travel Modes",                      "2020",      "2025"
)

cat("=== TIME RANGE ASSIGNMENT ===\n")
cat("2019-2024 industries:\n")
window_lookup %>% filter(start_year == "2019") %>% pull(IND) %>% cat(sep = "\n  ")
cat("\n\n2020-2025 industries:\n")
window_lookup %>% filter(start_year == "2020") %>% pull(IND) %>% cat(sep = "\n  ")
cat("\n\n")

# ============================================================================
# SECTION 5: COMPUTE MKT_SHARE_CHANGE AND TIME_RANGE
# ============================================================================

# Join window info to each row
mc <- mc %>%
  left_join(window_lookup, by = "IND")

# Create TIME_RANGE label (e.g., "2019-2024" or "2020-2025")
mc <- mc %>%
  mutate(
    TIME_RANGE = paste0(start_year, "-", end_year)
  )

# For each dyad, find the earliest and latest available year within its window,
# compute market share change, then annualize (divide by years between)

year_cols <- c("2019", "2020", "2021", "2022", "2023", "2024", "2025")

# Initialize new columns
mc$share_start       <- NA_real_
mc$year_start_actual <- NA_integer_
mc$share_end         <- NA_real_
mc$year_end_actual   <- NA_integer_
mc$years_between     <- NA_integer_
mc$MKT_SHARE_CHANGE  <- NA_real_

for (i in seq_len(nrow(mc))) {
  sy <- as.integer(mc$start_year[i])
  ey <- as.integer(mc$end_year[i])
  window_years <- as.character(seq(sy, ey))
  available <- intersect(window_years, year_cols)

  vals <- as.numeric(mc[i, available, drop = TRUE])
  names(vals) <- available
  valid <- vals[!is.na(vals)]

  if (length(valid) >= 2) {
    mc$share_start[i]       <- valid[1]
    mc$year_start_actual[i] <- as.integer(names(valid)[1])
    mc$share_end[i]         <- valid[length(valid)]
    mc$year_end_actual[i]   <- as.integer(names(valid)[length(valid)])
    mc$years_between[i]     <- mc$year_end_actual[i] - mc$year_start_actual[i]
    if (mc$years_between[i] > 0) {
      mc$MKT_SHARE_CHANGE[i] <- (mc$share_end[i] - mc$share_start[i]) / mc$years_between[i]
    }
  }
}

cat("Annualized MKT_SHARE_CHANGE computed for", sum(!is.na(mc$MKT_SHARE_CHANGE)),
    "of", nrow(mc), "dyads.\n")

# ============================================================================
# SECTION 6: DIAGNOSTICS
# ============================================================================

cat("=== MKT_SHARE_CHANGE DIAGNOSTICS (ANNUALIZED) ===\n\n")

# Coverage
n_total <- nrow(mc)
n_computed <- sum(!is.na(mc$MKT_SHARE_CHANGE))

cat("Total dyads:", n_total, "\n")
cat("MKT_SHARE_CHANGE computed:", n_computed,
    sprintf("(%.1f%%)\n", 100 * n_computed / n_total))
cat("Missing (fewer than 2 data points in window):", n_total - n_computed, "\n\n")

# Show how many used full 5-year span vs shorter
cat("=== YEAR SPAN USED ===\n")
mc %>%
  filter(!is.na(years_between)) %>%
  count(years_between) %>%
  mutate(pct = sprintf("%.1f%%", 100 * n / sum(n))) %>%
  print()

# Summary stats
cat("\n=== DISTRIBUTION (annualized pp/year) ===\n")
summary(mc$MKT_SHARE_CHANGE)
cat("\nSD:", sd(mc$MKT_SHARE_CHANGE, na.rm = TRUE), "\n\n")

# By TIME_RANGE
cat("=== BY TIME RANGE ===\n")
mc %>%
  group_by(TIME_RANGE) %>%
  summarize(
    n = n(),
    n_valid = sum(!is.na(MKT_SHARE_CHANGE)),
    mean_change = mean(MKT_SHARE_CHANGE, na.rm = TRUE),
    median_change = median(MKT_SHARE_CHANGE, na.rm = TRUE),
    sd_change = sd(MKT_SHARE_CHANGE, na.rm = TRUE),
    min_change = min(MKT_SHARE_CHANGE, na.rm = TRUE),
    max_change = max(MKT_SHARE_CHANGE, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

# By industry
cat("\n=== BY INDUSTRY ===\n")
mc %>%
  group_by(IND, TIME_RANGE) %>%
  summarize(
    n = n(),
    n_valid = sum(!is.na(MKT_SHARE_CHANGE)),
    mean_change = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    median_change = round(median(MKT_SHARE_CHANGE, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(TIME_RANGE, IND) %>%
  print(n = 15)

# Check for extreme values
cat("\n=== EXTREME VALUES (|annualized change| > 5 pp/year) ===\n")
mc %>%
  filter(abs(MKT_SHARE_CHANGE) > 5) %>%
  select(platform_name, host_country_name, IND, share_start, share_end,
         year_start_actual, year_end_actual, years_between,
         MKT_SHARE_CHANGE) %>%
  arrange(desc(abs(MKT_SHARE_CHANGE))) %>%
  print(n = 20)
# Install if needed (run once)
install.packages(c("flextable", "officer"))

library(flextable)
library(officer)

# --- Table 1: Year Span Used ---
tbl1 <- mc %>%
  filter(!is.na(years_between)) %>%
  count(years_between) %>%
  mutate(pct = sprintf("%.1f%%", 100 * n / sum(n))) %>%
  rename(`Year Span` = years_between, `N` = n, `%` = pct)

# --- Table 2: By Time Range ---
tbl2 <- mc %>%
  group_by(TIME_RANGE) %>%
  summarize(
    N = n(),
    M = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    Mdn = round(median(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    SD = round(sd(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    Min = round(min(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    Max = round(max(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  rename(`Time Range` = TIME_RANGE)

# --- Table 3: By Industry ---
tbl3 <- mc %>%
  group_by(IND, TIME_RANGE) %>%
  summarize(
    N = n(),
    M = round(mean(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    Mdn = round(median(MKT_SHARE_CHANGE, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(TIME_RANGE, IND) %>%
  rename(Industry = IND, `Time Range` = TIME_RANGE)

# --- APA formatting function ---
apa_table <- function(ft) {
  ft %>%
    font(fontname = "Times New Roman", part = "all") %>%
    fontsize(size = 12, part = "all") %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "body") %>%
    hline_top(border = fp_border(width = 2), part = "header") %>%
    hline_bottom(border = fp_border(width = 1), part = "header") %>%
    hline_bottom(border = fp_border(width = 2), part = "body") %>%
    border_remove() %>%
    hline_top(border = fp_border(width = 2), part = "header") %>%
    hline_bottom(border = fp_border(width = 1), part = "header") %>%
    hline_bottom(border = fp_border(width = 2), part = "body") %>%
    autofit()
}

# --- Build Word doc ---
doc <- read_docx() %>%
  body_add_par("Table X", style = "heading 1") %>%
  body_add_par("Year Span Used for Annualized Market Share Change",
               style = "Normal") %>%
  body_add_flextable(apa_table(flextable(tbl1))) %>%
  body_add_par("") %>%
  body_add_par("Note. Year span indicates the number of years between the earliest and latest available market share data within each dyad\u2019s measurement window.",
               style = "Normal") %>%
  body_add_break() %>%
  body_add_par("Table X", style = "heading 1") %>%
  body_add_par("Annualized Market Share Change by Time Range (pp/year)",
               style = "Normal") %>%
  body_add_flextable(apa_table(flextable(tbl2))) %>%
  body_add_par("") %>%
  body_add_par("Note. M = mean; Mdn = median; SD = standard deviation. Values represent annualized market share change in percentage points per year.",
               style = "Normal") %>%
  body_add_break() %>%
  body_add_par("Table X", style = "heading 1") %>%
  body_add_par("Annualized Market Share Change by Industry",
               style = "Normal") %>%
  body_add_flextable(apa_table(flextable(tbl3))) %>%
  body_add_par("") %>%
  body_add_par("Note. M = mean; Mdn = median. Values represent annualized market share change in percentage points per year. N = 6,617 firm-country dyads across 10 industries.",
               style = "Normal")

# --- Save Word doc ---
out_file <- file.path(base_path, "FINAL DISSERTATION", "tables and charts",
                      "Table_DV_Diagnostics.docx")
print(doc, target = out_file)
cat("Saved to:", out_file, "\n")

# ============================================================================
# SECTION 7: POPULATE market_share_pct (OPTIONAL - SNAPSHOT COLUMN)
# ============================================================================

# If you want market_share_pct to hold the most recent year's share:
#mc <- mc %>%
#  mutate(
#    market_share_pct = share_end
#  )
#
#cat("\nmarket_share_pct populated with end-year share.\n")

# ============================================================================
# SECTION 8: CLEAN UP HELPER COLUMNS
# ============================================================================

# Remove temporary columns used for computation
mc <- mc %>%
  select(-start_year, -end_year, -share_start, -share_end,
         -year_start_actual, -year_end_actual, -years_between)

# Verify new columns are present
new_cols <- c("MKT_SHARE_CHANGE", "TIME_RANGE")
cat("\n=== NEW COLUMNS ADDED ===\n")
for (col in new_cols) {
  cat(sprintf("  %s: %d non-null of %d\n", col,
              sum(!is.na(mc[[col]])), nrow(mc)))
}

# ============================================================================
# SECTION 9: SAVE
# ============================================================================

# Save updated codebook (new file - does not overwrite original)
output_file <- file.path(base_path, "REFERENCE",
                         "MASTER_CODEBOOK_with_DV.xlsx")
write_xlsx(mc, output_file)
cat("\nSaved to:", output_file, "\n")

# Also save a diagnostic summary
cat("\n✓ Script complete. MKT_SHARE_CHANGE and TIME_RANGE added.\n")

# ============================================================================
# SECTION 10: QUICK VISUALIZATION (OPTIONAL)
# ============================================================================

# Histogram of MKT_SHARE_CHANGE by TIME_RANGE
p <- ggplot(mc %>% filter(!is.na(MKT_SHARE_CHANGE)),
            aes(x = MKT_SHARE_CHANGE, fill = TIME_RANGE)) +
  geom_histogram(binwidth = 1, alpha = 0.7, position = "identity") +
  facet_wrap(~TIME_RANGE, ncol = 1) +
  labs(
    title = "Distribution of 5-Year Market Share Change",
    subtitle = "Annualized by measurement time range",
    x = "Market Share Change (percentage points)",
    y = "Count of Dyads",
    fill = "Time Range"
  ) +
  theme_minimal(base_family = "Times New Roman") +
  theme(legend.position = "none")

# Uncomment to display:
# print(p)

# Uncomment to save:
# ggsave(file.path(output_path, "MKT_SHARE_CHANGE_distribution.png"),
#        p, width = 8, height = 6, dpi = 300)
