# ============================================================================
# 10 - KOGUT-SINGH CULTURAL DISTANCE INDEX
# ============================================================================
# Author: Heather Carle
# Purpose: Compute Kogut-Singh Cultural Distance for all firm-country dyads
#          using Hofstede's cultural dimension scores, then merge back to
#          the analytic codebook. Re-exports descriptive tables with
#          cultural distance included.
#
# Formula (Kogut & Singh, 1988):
#   CD_jk = (1/n) * Σ [(I_ij - I_ik)² / V_i]
#
# Input:   MASTER_CODEBOOK_analytic.xlsx (from prior scripts)
#          6-dimensions-for-website-2015-12-08-0-100.csv (Hofstede)
# Output:  MASTER_CODEBOOK_analytic.xlsx (updated with cultural_distance)
#          Re-exported descriptive tables (08_Descriptive_Tables_APA.docx)
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
library(ggplot2)
library(countrycode)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis")
tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

# Hofstede data — try both CSV files
hofstede_dir <- file.path(base_path, "dissertation data", "Culture measures")
hofstede_file <- file.path(hofstede_dir, "6-dimensions-for-website-2015-12-08-0-100.csv")
if (!file.exists(hofstede_file)) {
  hofstede_file <- file.path(hofstede_dir, "6-dimensions-for-website-2015-08-16.csv")
}

# ============================================================================
# SECTION 3: LOAD CODEBOOK
# ============================================================================

cat("Loading analytic codebook...\n")
mc <- read_excel(codebook_path)
cat("  Rows:", nrow(mc), " Columns:", ncol(mc), "\n")
cat("  Unique home countries:", n_distinct(mc$home_country_iso3c), "\n")
cat("  Unique host countries:", n_distinct(mc$host_country_iso3c), "\n\n")

# ============================================================================
# SECTION 4: LOAD HOFSTEDE DATA
# ============================================================================

cat("Loading Hofstede dimension data...\n")
cat("  File:", hofstede_file, "\n")

# Read CSV — semicolon-delimited (standard Hofstede website format)
hof_raw <- read.csv(hofstede_file, stringsAsFactors = FALSE, check.names = FALSE, sep = ";")
cat("  Columns:", paste(colnames(hof_raw), collapse = ", "), "\n")
cat("  Rows:", nrow(hof_raw), "\n\n")

# Standardize column names and trim whitespace from all values
names(hof_raw) <- trimws(tolower(names(hof_raw)))
hof_raw <- hof_raw %>% mutate(across(everything(), trimws))

cat("  Columns after cleanup:", paste(names(hof_raw), collapse = ", "), "\n")
cat("  First few ctr values:", paste(head(hof_raw$ctr, 5), collapse = ", "), "\n")

# Rename to standard names (Hofstede file has: ctr, country, pdi, idv, mas, uai, ltowvs, ivr)
hofstede <- hof_raw %>%
  rename(
    hof_code = ctr,
    country_name = country,
    PDI = pdi,
    IDV = idv,
    MAS = mas,
    UAI = uai,
    LTO = ltowvs,
    IVR = ivr
  )

# Convert #NULL! to NA, then make numeric
hofstede <- hofstede %>%
  mutate(across(c(PDI, IDV, MAS, UAI, LTO, IVR),
                ~as.numeric(ifelse(. == "#NULL!", NA, .))))

cat("Dimension coverage:\n")
for (d in c("PDI", "IDV", "MAS", "UAI", "LTO", "IVR")) {
  n_valid <- sum(!is.na(hofstede[[d]]))
  cat(sprintf("  %s: %d/%d countries\n", d, n_valid, nrow(hofstede)))
}

# --- Map Hofstede custom codes to ISO3C ---
# Hofstede uses non-standard 3-letter codes (e.g., AUL=Australia, NET=Netherlands)
# This is a comprehensive mapping from Hofstede ctr codes to ISO 3166-1 alpha-3
hof_to_iso <- c(
  "AFE" = NA,        # Africa East (region, not country)
  "AFW" = NA,        # Africa West (region, not country)
  "ALB" = "ALB",     # Albania
  "ALG" = "DZA",     # Algeria
  "AND" = "AND",     # Andorra
  "ARA" = NA,        # Arab countries (region)
  "ARG" = "ARG",     # Argentina
  "ARM" = "ARM",     # Armenia
  "AUL" = "AUS",     # Australia
  "AUT" = "AUT",     # Austria
  "AZE" = "AZE",     # Azerbaijan
  "BAN" = "BGD",     # Bangladesh
  "BEF" = "BEL",     # Belgium French → use Belgium
  "BEL" = "BEL",     # Belgium
  "BEN" = "BEL",     # Belgium Netherl → use Belgium
  "BLR" = "BLR",     # Belarus
  "BOS" = "BIH",     # Bosnia
  "BRA" = "BRA",     # Brazil
  "BUF" = "BFA",     # Burkina Faso
  "BUL" = "BGR",     # Bulgaria
  "CAF" = "CAN",     # Canada French → use Canada
  "CAN" = "CAN",     # Canada
  "CHI" = "CHN",     # China
  "CHL" = "CHL",     # Chile
  "COL" = "COL",     # Colombia
  "COS" = "CRI",     # Costa Rica
  "CRO" = "HRV",     # Croatia
  "CYP" = "CYP",     # Cyprus
  "CZE" = "CZE",     # Czech Rep
  "DEN" = "DNK",     # Denmark
  "DOM" = "DOM",     # Dominican Rep
  "ECA" = "ECU",     # Ecuador
  "EGY" = "EGY",     # Egypt
  "EST" = "EST",     # Estonia
  "ETH" = "ETH",     # Ethiopia
  "FIN" = "FIN",     # Finland
  "FRA" = "FRA",     # France
  "GBR" = "GBR",     # Great Britain
  "GEE" = "DEU",     # Germany East → use Germany
  "GEO" = "GEO",     # Georgia
  "GER" = "DEU",     # Germany
  "GHA" = "GHA",     # Ghana
  "GRE" = "GRC",     # Greece
  "GUA" = "GTM",     # Guatemala
  "HOK" = "HKG",     # Hong Kong
  "HUN" = "HUN",     # Hungary
  "ICE" = "ISL",     # Iceland
  "IDO" = "IDN",     # Indonesia
  "IND" = "IND",     # India
  "IRA" = "IRN",     # Iran
  "IRE" = "IRL",     # Ireland
  "IRQ" = "IRQ",     # Iraq
  "ISR" = "ISR",     # Israel
  "ITA" = "ITA",     # Italy
  "JAM" = "JAM",     # Jamaica
  "JOR" = "JOR",     # Jordan
  "JPN" = "JPN",     # Japan
  "KOR" = "KOR",     # Korea South
  "KYR" = "KGZ",     # Kyrgyz Rep
  "LAT" = "LVA",     # Latvia
  "LIT" = "LTU",     # Lithuania
  "LUX" = "LUX",     # Luxembourg
  "MAC" = "MKD",     # Macedonia Rep
  "MAL" = "MYS",     # Malaysia
  "MEX" = "MEX",     # Mexico
  "MLI" = "MLI",     # Mali
  "MLT" = "MLT",     # Malta
  "MNG" = "MNE",     # Montenegro
  "MOL" = "MDA",     # Moldova
  "MOR" = "MAR",     # Morocco
  "NET" = "NLD",     # Netherlands
  "NIG" = "NGA",     # Nigeria
  "NOR" = "NOR",     # Norway
  "NZL" = "NZL",     # New Zealand
  "PAK" = "PAK",     # Pakistan
  "PAN" = "PAN",     # Panama
  "PER" = "PER",     # Peru
  "PHI" = "PHL",     # Philippines
  "POL" = "POL",     # Poland
  "POR" = "PRT",     # Portugal
  "PUE" = "PRI",     # Puerto Rico
  "ROM" = "ROU",     # Romania
  "RUS" = "RUS",     # Russia
  "RWA" = "RWA",     # Rwanda
  "SAF" = "ZAF",     # South Africa
  "SAL" = "SLV",     # El Salvador
  "SAU" = "SAU",     # Saudi Arabia
  "SAW" = "ZAF",     # South Africa white → use South Africa
  "SER" = "SRB",     # Serbia
  "SIN" = "SGP",     # Singapore
  "SLK" = "SVK",     # Slovak Rep
  "SLV" = "SVN",     # Slovenia
  "SPA" = "ESP",     # Spain
  "SUR" = "SUR",     # Suriname
  "SWE" = "SWE",     # Sweden
  "SWF" = "CHE",     # Switzerland French → use Switzerland
  "SWG" = "CHE",     # Switzerland German → use Switzerland
  "SWI" = "CHE",     # Switzerland
  "TAI" = "TWN",     # Taiwan
  "TAN" = "TZA",     # Tanzania
  "THA" = "THA",     # Thailand
  "TRI" = "TTO",     # Trinidad and Tobago
  "TUR" = "TUR",     # Turkey
  "UGA" = "UGA",     # Uganda
  "UKR" = "UKR",     # Ukraine
  "URU" = "URY",     # Uruguay
  "USA" = "USA",     # U.S.A.
  "VEN" = "VEN",     # Venezuela
  "VIE" = "VNM",     # Vietnam
  "ZAM" = "ZMB",     # Zambia
  "ZIM" = "ZWE"      # Zimbabwe
)

hofstede$iso3c <- hof_to_iso[hofstede$hof_code]

# Diagnostics: check mapping
n_mapped <- sum(!is.na(hofstede$iso3c))
n_unmapped <- sum(is.na(hofstede$iso3c))
cat(sprintf("\n--- ISO3C Mapping Diagnostics ---\n"))
cat(sprintf("  Mapped: %d, Unmapped: %d, Total: %d\n", n_mapped, n_unmapped, nrow(hofstede)))
if (n_mapped == 0) {
  cat("  WARNING: No codes mapped! Checking hof_code values:\n")
  cat("  First 10 hof_codes:", paste(head(hofstede$hof_code, 10), collapse = ", "), "\n")
  cat("  nchar of first code:", nchar(hofstede$hof_code[1]), "\n")
  cat("  chartr check:", chartr(" ", ".", hofstede$hof_code[1]), "\n")
}
cat("  Sample mappings: ",
    paste(head(hofstede$hof_code, 5), "→", head(hofstede$iso3c, 5), collapse = ", "), "\n")

# For duplicate ISO3C entries (e.g., Belgium, Canada, Switzerland, Germany, South Africa)
# Keep only the main entry (not the regional sub-entries)
hofstede <- hofstede %>%
  filter(!is.na(iso3c)) %>%
  group_by(iso3c) %>%
  slice(1) %>%
  ungroup()

cat("\nHofstede countries mapped to ISO3C:", nrow(hofstede), "\n")
cat("ISO3C values in Hofstede:", paste(sort(hofstede$iso3c), collapse = ", "), "\n")

# Check which countries in our codebook are covered
codebook_countries <- unique(c(mc$home_country_iso3c, mc$host_country_iso3c))
covered <- intersect(codebook_countries, hofstede$iso3c)
missing_countries <- setdiff(codebook_countries, hofstede$iso3c)
missing_countries <- missing_countries[!is.na(missing_countries)]

cat("Codebook countries:", length(codebook_countries), "\n")
cat("Covered by Hofstede:", length(covered), "\n")
if (length(missing_countries) > 0) {
  cat("Missing from Hofstede:", paste(missing_countries, collapse = ", "), "\n")
} else {
  cat("All countries covered!\n")
}

# ============================================================================
# SECTION 5: COMPUTE DIMENSION VARIANCES
# ============================================================================

dims_4 <- c("PDI", "IDV", "MAS", "UAI")
dims_6 <- c("PDI", "IDV", "MAS", "UAI", "LTO", "IVR")

# Variances across all countries (denominator in KSI formula)
variances_4 <- hofstede %>%
  select(all_of(dims_4)) %>%
  summarise(across(everything(), ~var(., na.rm = TRUE))) %>%
  unlist()

variances_6 <- hofstede %>%
  select(all_of(dims_6)) %>%
  summarise(across(everything(), ~var(., na.rm = TRUE))) %>%
  unlist()

cat("\n--- Dimension Variances (4-dim) ---\n")
print(round(variances_4, 2))
cat("\n--- Dimension Variances (6-dim) ---\n")
print(round(variances_6, 2))

# ============================================================================
# SECTION 6: KSI COMPUTATION FUNCTION
# ============================================================================

compute_ksi <- function(home_iso, host_iso, hofstede_df, dims, vars) {
  home <- hofstede_df %>% filter(iso3c == home_iso)
  host <- hofstede_df %>% filter(iso3c == host_iso)

  if (nrow(home) == 0 | nrow(host) == 0) return(NA_real_)

  home_scores <- as.numeric(home[1, dims])
  host_scores <- as.numeric(host[1, dims])

  if (any(is.na(home_scores)) | any(is.na(host_scores))) return(NA_real_)

  n <- length(dims)
  cd <- sum(((home_scores - host_scores)^2) / vars) / n
  return(cd)
}

# ============================================================================
# SECTION 7: COMPUTE CULTURAL DISTANCE FOR ALL DYADS
# ============================================================================

cat("\nComputing cultural distance for", nrow(mc), "dyads...\n")

# Use a for loop for reliability (same approach as script 01)
mc$cultural_distance <- NA_real_
mc$cultural_distance_6dim <- NA_real_

for (i in seq_len(nrow(mc))) {
  home_iso <- mc$home_country_iso3c[i]
  host_iso <- mc$host_country_iso3c[i]

  # Same country = 0 cultural distance
  if (!is.na(home_iso) & !is.na(host_iso) & home_iso == host_iso) {
    mc$cultural_distance[i] <- 0
    mc$cultural_distance_6dim[i] <- 0
    next
  }

  mc$cultural_distance[i] <- compute_ksi(home_iso, host_iso,
                                          hofstede, dims_4, variances_4)
  mc$cultural_distance_6dim[i] <- compute_ksi(home_iso, host_iso,
                                               hofstede, dims_6, variances_6)
}

n_computed <- sum(!is.na(mc$cultural_distance))
n_missing <- sum(is.na(mc$cultural_distance))
cat(sprintf("  Computed: %d/%d (%.1f%%)\n", n_computed, nrow(mc),
            100 * n_computed / nrow(mc)))
cat(sprintf("  Missing: %d\n", n_missing))

# ============================================================================
# SECTION 8: DIAGNOSTICS
# ============================================================================

cat("\n=== CULTURAL DISTANCE DIAGNOSTICS ===\n\n")

# Summary statistics
cat("--- Overall Descriptives (4-dim KSI) ---\n")
cd_stats <- mc %>%
  filter(!is.na(cultural_distance)) %>%
  summarise(
    N = n(),
    Mean = round(mean(cultural_distance), 3),
    SD = round(sd(cultural_distance), 3),
    Min = round(min(cultural_distance), 3),
    Median = round(median(cultural_distance), 3),
    Max = round(max(cultural_distance), 3)
  )
print(cd_stats)

# Missing dyads
if (n_missing > 0) {
  cat("\n--- Missing Cultural Distance ---\n")
  missing_dyads <- mc %>%
    filter(is.na(cultural_distance)) %>%
    distinct(home_country_iso3c, host_country_iso3c) %>%
    arrange(home_country_iso3c, host_country_iso3c)
  print(missing_dyads, n = 30)

  missing_isos <- unique(c(
    missing_dyads$home_country_iso3c[!missing_dyads$home_country_iso3c %in% hofstede$iso3c],
    missing_dyads$host_country_iso3c[!missing_dyads$host_country_iso3c %in% hofstede$iso3c]
  ))
  if (length(missing_isos) > 0) {
    cat("Countries not in Hofstede:", paste(missing_isos, collapse = ", "), "\n")
  }
}

# Domestic dyads (CD = 0) — FULL SAMPLE
n_domestic <- sum(mc$cultural_distance == 0, na.rm = TRUE)
n_cd_valid <- sum(!is.na(mc$cultural_distance))
cat(sprintf("\n--- Full Sample (all dyads) ---\n"))
cat(sprintf("Domestic dyads (CD = 0): %d (%.1f%%)\n",
            n_domestic, 100 * n_domestic / n_cd_valid))
cat(sprintf("Cross-border (CD > 0):   %d (%.1f%%)\n",
            n_cd_valid - n_domestic, 100 * (n_cd_valid - n_domestic) / n_cd_valid))

# Domestic dyads (CD = 0) — PLAT SAMPLE (retained for SEM)
plat_cd <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(cultural_distance))
n_plat_domestic <- sum(plat_cd$cultural_distance == 0)
n_plat_cross    <- sum(plat_cd$cultural_distance > 0)
n_plat_cd       <- nrow(plat_cd)

cat(sprintf("\n--- PLAT Sample (SEM retained) ---\n"))
cat(sprintf("PLAT dyads with CD:      %d\n", n_plat_cd))
cat(sprintf("Domestic (CD = 0):       %d (%.1f%%)\n",
            n_plat_domestic, 100 * n_plat_domestic / n_plat_cd))
cat(sprintf("Cross-border (CD > 0):   %d (%.1f%%)\n",
            n_plat_cross, 100 * n_plat_cross / n_plat_cd))
cat(sprintf("Mean CD (all PLAT):      %.3f\n", mean(plat_cd$cultural_distance)))
cat(sprintf("Mean CD (cross-border):  %.3f\n",
            mean(plat_cd$cultural_distance[plat_cd$cultural_distance > 0])))
cat(sprintf("SD CD (all PLAT):        %.3f\n", sd(plat_cd$cultural_distance)))
cat(sprintf("Median CD:               %.3f\n", median(plat_cd$cultural_distance)))
cat(sprintf("Max CD:                  %.3f\n", max(plat_cd$cultural_distance)))

# --- Skewness & Kurtosis (PLAT sample) ---
cat("\n--- CD Distribution Shape (PLAT sample) ---\n")
if (requireNamespace("moments", quietly = TRUE)) {
  cd_plat_vals <- plat_cd$cultural_distance
  cd_skew <- moments::skewness(cd_plat_vals)
  cd_kurt <- moments::kurtosis(cd_plat_vals)  # excess kurtosis = kurtosis - 3
  cat(sprintf("Skewness:  %.3f  %s\n", cd_skew,
              ifelse(abs(cd_skew) < 1, "(acceptable)",
                     ifelse(abs(cd_skew) < 2, "(moderate — consider log transform)", "(severe)"))))
  cat(sprintf("Kurtosis:  %.3f  (excess = %.3f) %s\n", cd_kurt, cd_kurt - 3,
              ifelse(abs(cd_kurt - 3) < 2, "(acceptable)", "(heavy tails)")))
  # Also for cross-border only (excluding CD=0 floor effect)
  cd_cross_vals <- plat_cd$cultural_distance[plat_cd$cultural_distance > 0]
  cat(sprintf("\nCross-border only (excl. domestic CD=0):\n"))
  cat(sprintf("Skewness:  %.3f\n", moments::skewness(cd_cross_vals)))
  cat(sprintf("Kurtosis:  %.3f  (excess = %.3f)\n",
              moments::kurtosis(cd_cross_vals), moments::kurtosis(cd_cross_vals) - 3))
} else {
  cat("Install 'moments' package for skewness/kurtosis: install.packages('moments')\n")
}

# --- Most/Least Culturally Distant Pairings (PLAT sample) ---
cat("\n--- Most Culturally Distant PLAT Dyads (Top 10) ---\n")
plat_cd %>%
  filter(cultural_distance > 0) %>%
  arrange(desc(cultural_distance)) %>%
  distinct(home_country_iso3c, host_country_iso3c, .keep_all = TRUE) %>%
  select(platform_name, home_country_iso3c, host_country_iso3c,
         cultural_distance, IND) %>%
  head(10) %>%
  print()

cat("\n--- Least Culturally Distant Cross-Border PLAT Dyads (Bottom 10) ---\n")
plat_cd %>%
  filter(cultural_distance > 0) %>%
  arrange(cultural_distance) %>%
  distinct(home_country_iso3c, host_country_iso3c, .keep_all = TRUE) %>%
  select(platform_name, home_country_iso3c, host_country_iso3c,
         cultural_distance, IND) %>%
  head(10) %>%
  print()

# --- Hofstede Dimension Descriptives (across sample countries) ---
cat("\n--- Hofstede Dimension Descriptives (Sample Countries) ---\n")
# Get unique countries in PLAT sample
plat_countries <- unique(c(plat_cd$home_country_iso3c, plat_cd$host_country_iso3c))
hof_sample <- hofstede %>% filter(iso3c %in% plat_countries)
cat(sprintf("Countries in PLAT sample with Hofstede scores: %d of %d\n",
            nrow(hof_sample), length(plat_countries)))

dim_names <- c("PDI", "IDV", "MAS", "UAI")
dim_labels <- c("Power Distance (PDI)", "Individualism (IDV)",
                "Masculinity (MAS)", "Uncertainty Avoidance (UAI)")
cat(sprintf("\n%-30s %6s %6s %6s %6s\n", "Dimension", "M", "SD", "Min", "Max"))
cat(strrep("-", 60), "\n")
for (k in seq_along(dim_names)) {
  vals <- hof_sample[[dim_names[k]]]
  vals <- vals[!is.na(vals)]
  cat(sprintf("%-30s %6.1f %6.1f %6.0f %6.0f\n",
              dim_labels[k], mean(vals), sd(vals), min(vals), max(vals)))
}

# Variance contribution to KSI
cat("\n--- Dimension Variance Contribution to KSI ---\n")
cat("(Higher variance = larger contribution to cultural distance)\n")
for (k in seq_along(dim_names)) {
  v <- var(hof_sample[[dim_names[k]]], na.rm = TRUE)
  cat(sprintf("  %s: Var = %.1f\n", dim_labels[k], v))
}

# --- Country Coverage Summary ---
cat("\n--- Hofstede Coverage Summary ---\n")
all_home <- unique(plat_cd$home_country_iso3c)
all_host <- unique(plat_cd$host_country_iso3c)
home_covered <- sum(all_home %in% hofstede$iso3c)
host_covered <- sum(all_host %in% hofstede$iso3c)
home_missing <- all_home[!all_home %in% hofstede$iso3c]
host_missing <- all_host[!all_host %in% hofstede$iso3c]

cat(sprintf("Home countries: %d total, %d covered (%.1f%%)\n",
            length(all_home), home_covered, 100 * home_covered / length(all_home)))
cat(sprintf("Host countries: %d total, %d covered (%.1f%%)\n",
            length(all_host), host_covered, 100 * host_covered / length(all_host)))
if (length(home_missing) > 0) cat("  Missing home:", paste(home_missing, collapse = ", "), "\n")
if (length(host_missing) > 0) cat("  Missing host:", paste(host_missing, collapse = ", "), "\n")

# --- CD by Access Type × Industry (PLAT sample) ---
cat("\n--- CD by Access Type × Industry ---\n")
cd_plat_cross <- plat_cd %>%
  group_by(IND, PLAT) %>%
  summarize(
    n = n(),
    Mean_CD = round(mean(cultural_distance), 3),
    SD_CD   = round(sd(cultural_distance), 3),
    Pct_Domestic = round(100 * mean(cultural_distance == 0), 1),
    .groups = "drop"
  ) %>%
  arrange(IND, PLAT)
print(cd_plat_cross, n = 40)

# Correlation between 4-dim and 6-dim
cor_4_6 <- cor(mc$cultural_distance, mc$cultural_distance_6dim,
               use = "complete.obs")
cat(sprintf("Correlation 4-dim vs 6-dim: r = %.3f\n", cor_4_6))

# By industry
cat("\n--- Cultural Distance by Industry ---\n")
mc %>%
  filter(!is.na(cultural_distance)) %>%
  group_by(IND) %>%
  summarise(
    N = n(),
    Mean_CD = round(mean(cultural_distance), 3),
    SD_CD = round(sd(cultural_distance), 3),
    .groups = "drop"
  ) %>%
  arrange(desc(Mean_CD)) %>%
  print(n = 12)

# --- Chart 1: Distribution excluding domestic (CD=0) dyads ---
cd_cross <- mc %>%
  filter(!is.na(cultural_distance), cultural_distance > 0)

n_domestic <- sum(mc$cultural_distance == 0, na.rm = TRUE)
n_cross <- nrow(cd_cross)

p_cd1 <- ggplot(cd_cross, aes(x = cultural_distance)) +
  geom_histogram(bins = 40, fill = "steelblue", color = "white", alpha = 0.8) +
  geom_vline(xintercept = mean(cd_cross$cultural_distance),
             linetype = "dashed", color = "red", linewidth = 0.7) +
  annotate("text",
           x = mean(cd_cross$cultural_distance) + 0.1,
           y = Inf, vjust = 2, hjust = -0.1,
           label = sprintf("Mean = %.2f", mean(cd_cross$cultural_distance)),
           color = "red", size = 3.5, family = "Times New Roman") +
  labs(
    subtitle = sprintf("Excluding %s domestic dyads (CD = 0). N = %s cross-border dyads.",
                        format(n_domestic, big.mark = ","),
                        format(n_cross, big.mark = ",")),
    x = "Kogut-Singh Cultural Distance Index",
    y = "Count"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(text = element_text(family = "Times New Roman"),
        plot.title = element_blank(),
        plot.subtitle = element_blank())

print(p_cd1)
ggsave(file.path(tables_path, "12d_cultural_distance_crossborder.png"),
       p_cd1, width = 8, height = 5, dpi = 300)
cat("✓ Cross-border CD distribution saved.\n")

# --- Chart 2: Box plot of CD by industry ---
cd_by_ind <- mc %>%
  filter(!is.na(cultural_distance),
         PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

p_cd2 <- ggplot(cd_by_ind, aes(x = reorder(IND, cultural_distance, FUN = median),
                                 y = cultural_distance)) +
  geom_boxplot(fill = "steelblue", alpha = 0.5, outlier.size = 1) +
  coord_flip() +
  labs(
    x = NULL,
    y = "Kogut-Singh Cultural Distance Index"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(text = element_text(family = "Times New Roman"), plot.title = element_blank(), plot.subtitle = element_blank())

print(p_cd2)
ggsave(file.path(tables_path, "12d_cultural_distance_by_industry.png"),
       p_cd2, width = 9, height = 6, dpi = 300)
cat("✓ CD by industry box plot saved.\n")

# --- Chart 3: Domestic vs Cross-Border breakdown ---
cd_summary <- mc %>%
  filter(!is.na(cultural_distance),
         PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  mutate(Dyad_Type = ifelse(cultural_distance == 0, "Domestic", "Cross-Border")) %>%
  summarize(n = n(), .by = c(IND, Dyad_Type))

p_cd3 <- ggplot(cd_summary, aes(x = reorder(IND, n, FUN = sum),
                                  y = n, fill = Dyad_Type)) +
  geom_bar(stat = "identity", position = "stack") +
  coord_flip() +
  scale_fill_manual(values = c("Domestic" = "#2ca02c", "Cross-Border" = "#d95f02")) +
  labs(
    x = NULL,
    y = "Number of Dyads",
    fill = "Dyad Type"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(text = element_text(family = "Times New Roman"),
        legend.position = "bottom")

print(p_cd3)
ggsave(file.path(tables_path, "12d_domestic_vs_crossborder.png"),
       p_cd3, width = 9, height = 6, dpi = 300)
cat("✓ Domestic vs cross-border chart saved.\n")

# ============================================================================
# SECTION 9: SAVE UPDATED CODEBOOK
# ============================================================================

write_xlsx(mc, codebook_path)
cat("\n✓ Codebook saved with cultural_distance columns.\n")

# ============================================================================
# SECTION 10: RE-EXPORT DESCRIPTIVE TABLES (from script 08)
# ============================================================================
# Since cultural_distance was missing when script 08 ran, we regenerate
# the key descriptive tables here with the complete data.

cat("\n=== RE-EXPORTING DESCRIPTIVE TABLES WITH CULTURAL DISTANCE ===\n\n")

library(flextable)
library(officer)

# Rebuild the key objects script 08 needs
firms <- mc %>% distinct(platform_ID, .keep_all = TRUE)
plat_firms <- firms %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))
plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

cat("PLAT firms:", nrow(plat_firms), " PLAT dyads:", nrow(plat_dyads), "\n")

# --- Helper function ---
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

# --- Composite Scores (with LINGUISTIC_VARIETY and programming_lang_variety) ---
composite_vars <- c("raw_application", "raw_development", "raw_ai",
                     "raw_social", "raw_governance",
                     "Z_application", "Z_development", "Z_ai",
                     "Z_social", "Z_governance",
                     "platform_resources",
                     "LINGUISTIC_VARIETY", "programming_lang_variety",
                     "platform_accessibility")

comp_desc <- bind_rows(
  lapply(composite_vars, function(v) {
    if (v %in% colnames(plat_firms)) {
      desc_stats(as.numeric(plat_firms[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)

# --- Dyad-Level Variables (now includes cultural_distance) ---
dyad_vars <- c("MKT_SHARE_CHANGE", "market_share_pct",
                "cultural_distance",
                "host_gdp_per_capita", "host_Internet_users",
                "home_gdp_per_capita", "home_internet_users",
                "IND_GROW")

dyad_desc <- bind_rows(
  lapply(dyad_vars, function(v) {
    if (v %in% colnames(plat_dyads)) {
      desc_stats(as.numeric(plat_dyads[[v]]), digits = 3) %>%
        mutate(Variable = v, .before = 1)
    }
  })
)

# --- Correlation Matrix: SEM MODEL VARIABLES ONLY ---
# Only include variables that actually enter the SEM model
sem_vars <- c("platform_resources",
              "platform_accessibility",
              "MKT_SHARE_CHANGE",
              "cultural_distance",
              "IND_GROW",
              "home_gdp_per_capita",
              "host_gdp_per_capita",
              "host_Internet_users")

# APA-friendly short labels for the table
sem_labels <- c("PR" = "platform_resources",
                "PA" = "platform_accessibility",
                "DV" = "MKT_SHARE_CHANGE",
                "CD" = "cultural_distance",
                "IND_GROW" = "IND_GROW",
                "Home GDP" = "home_gdp_per_capita",
                "Host GDP" = "host_gdp_per_capita",
                "Host Internet" = "host_Internet_users")

sem_vars_present <- sem_vars[sem_vars %in% colnames(plat_dyads)]
cor_data <- plat_dyads %>%
  select(all_of(sem_vars_present)) %>%
  mutate(across(everything(), as.numeric))
cor_mat <- cor(cor_data, use = "pairwise.complete.obs")

# Rename rows/cols with short labels
label_map <- setNames(names(sem_labels), sem_labels)
new_names <- label_map[colnames(cor_mat)]
new_names[is.na(new_names)] <- colnames(cor_mat)[is.na(new_names)]
colnames(cor_mat) <- new_names
rownames(cor_mat) <- new_names

# --- ALSO keep full 12-var matrix for reference CSV ---
sem_vars_full <- c("platform_resources",
              "Z_application", "Z_development", "Z_ai",
              "Z_social", "Z_governance",
              "platform_accessibility",
              "MKT_SHARE_CHANGE",
              "cultural_distance",
              "LINGUISTIC_VARIETY", "programming_lang_variety",
              "IND_GROW")
sem_vars_full_present <- sem_vars_full[sem_vars_full %in% colnames(plat_dyads)]
cor_data_full <- plat_dyads %>%
  select(all_of(sem_vars_full_present)) %>%
  mutate(across(everything(), as.numeric))
cor_mat_full <- cor(cor_data_full, use = "pairwise.complete.obs")

# --- Cultural Cluster Summary (now includes CD) ---
# Clusters based on GLOBE Study (House et al., 2004):
#   House, R.J., Hanges, P.J., Javidan, M., Dorfman, P.W., & Gupta, V. (Eds.).
#   Culture, Leadership, and Organizations: The GLOBE Study of 62 Societies.
#   Sage Publications.
# Countries not in the original GLOBE sample are assigned to their nearest
# cluster based on geographic, linguistic, and cultural proximity.
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

# ============================================================================
# BUILD UPDATED WORD DOCUMENT (same tables as 08, but with CD data)
# ============================================================================

desc_doc <- read_docx()

# --- Composite Score Descriptives ---
desc_doc <- body_add_par(desc_doc, "Table. Composite Score Descriptives (PLAT Firms) — Updated",
                          style = "heading 2")

ft_comp <- flextable(comp_desc) %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(comp_desc), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_comp)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT firms. Raw = mean of binary indicators. Z = standardized composite. platform_resources = mean of 5 Z-scores. platform_accessibility = weighted sum. Now includes LINGUISTIC_VARIETY and programming_lang_variety.",
          nrow(plat_firms)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Dyad-Level Variable Descriptives (with CD) ---
desc_doc <- body_add_par(desc_doc, "Table. Dyad-Level Variable Descriptives (PLAT Dyads) — Updated",
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
  sprintf("Note. N = %d PLAT dyads. Cultural distance now populated via Kogut-Singh Index.",
          nrow(plat_dyads)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Correlation Matrix (SEM variables only, APA lower-triangle) ---
desc_doc <- body_add_par(desc_doc,
  "Table. Bivariate Correlations Among SEM Model Variables",
  style = "heading 2")

# Build APA lower-triangle format with numbered columns
n_vars <- ncol(cor_mat)
var_names <- colnames(cor_mat)

# Create lower triangle: blank above diagonal, em-dash on diagonal
cor_lower <- matrix("", nrow = n_vars, ncol = n_vars)
for (i in seq_len(n_vars)) {
  for (j in seq_len(n_vars)) {
    if (i == j) {
      cor_lower[i, j] <- "\u2014"          # em-dash on diagonal
    } else if (j < i) {
      cor_lower[i, j] <- sprintf("%.3f", cor_mat[i, j])
    }
  }
}

# Compute M and SD for each variable
cor_means <- sapply(cor_data, function(x) sprintf("%.2f", mean(x, na.rm = TRUE)))
cor_sds   <- sapply(cor_data, function(x) sprintf("%.2f", sd(x, na.rm = TRUE)))

# Compute p-values for significance stars
p_mat <- matrix(NA, nrow = n_vars, ncol = n_vars)
for (i in seq_len(n_vars)) {
  for (j in seq_len(n_vars)) {
    if (i != j) {
      valid <- complete.cases(cor_data[, c(i, j)])
      if (sum(valid) > 3) {
        p_mat[i, j] <- cor.test(cor_data[[i]][valid],
                                cor_data[[j]][valid])$p.value
      }
    }
  }
}

sig_stars <- function(p) {
  if (is.na(p)) return("")
  if (p < .001) return("***")
  if (p < .01)  return("**")
  if (p < .05)  return("*")
  return("")
}

# Rebuild lower triangle with significance stars
cor_lower_stars <- matrix("", nrow = n_vars, ncol = n_vars)
for (i in seq_len(n_vars)) {
  for (j in seq_len(n_vars)) {
    if (i == j) {
      cor_lower_stars[i, j] <- "\u2014"
    } else if (j < i) {
      stars <- sig_stars(p_mat[i, j])
      cor_lower_stars[i, j] <- paste0(sprintf("%.3f", cor_mat[i, j]), stars)
    }
  }
}

cor_apa <- data.frame(
  Variable = paste0(seq_len(n_vars), ". ", var_names),
  M  = cor_means,
  SD = cor_sds,
  cor_lower_stars,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
colnames(cor_apa) <- c("Variable", "M", "SD", as.character(seq_len(n_vars)))

ft_cor <- flextable(cor_apa) %>%
  fontsize(size = 8, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(cor_apa), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_cor)
desc_doc <- body_add_par(desc_doc,
  sprintf("Note. N = %d PLAT dyads. Pairwise complete observations. PR = Platform Resources; EA = Platform Accessibility; DV = Annualized Market Share Change (pp/year); CD = Cultural Distance (Kogut-Singh 4-dim); IND_GROW = 5-year industry growth rate; Home/Host GDP = GDP per capita (USD); Host Internet = internet users (%%). * p < .05. ** p < .01. *** p < .001.",
          nrow(plat_dyads)),
  style = "Normal")
desc_doc <- body_add_par(desc_doc, "", style = "Normal")

# --- Cultural Cluster Summary (with CD) ---
desc_doc <- body_add_par(desc_doc, "Table. Performance and Cultural Distance by GLOBE Cluster — Updated",
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
  "Note. DV = Annualized Market Share Change (pp/year). CD = Cultural Distance (Kogut-Singh 4-dim KSI). Clusters based on GLOBE Study (House et al., 2004).",
  style = "Normal")

# --- Cultural Distance Descriptives (new table) ---
desc_doc <- body_add_par(desc_doc, "", style = "Normal")
desc_doc <- body_add_par(desc_doc, "Table. Cultural Distance Descriptives",
                          style = "heading 2")

cd_by_type <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(cultural_distance)) %>%
  group_by(PLAT) %>%
  summarize(
    N = n(),
    Mean = round(mean(cultural_distance), 3),
    SD = round(sd(cultural_distance), 3),
    Min = round(min(cultural_distance), 3),
    Median = round(median(cultural_distance), 3),
    Max = round(max(cultural_distance), 3),
    .groups = "drop"
  )

ft_cd <- flextable(cd_by_type) %>%
  set_header_labels(PLAT = "Access Type") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

desc_doc <- body_add_flextable(desc_doc, ft_cd)
desc_doc <- body_add_par(desc_doc,
  "Note. Cultural distance computed using Kogut-Singh Index (1988) with Hofstede's 4 dimensions (PDI, IDV, MAS, UAI). Domestic dyads = 0.",
  style = "Normal")

# Save updated tables
updated_word_path <- file.path(tables_path, "10_Updated_Descriptive_Tables.docx")
print(desc_doc, target = updated_word_path)
cat("\n✓ Updated descriptive tables saved to:", updated_word_path, "\n")

# Save correlation matrix CSVs
write.csv(round(cor_mat, 3),
          file.path(output_path, "correlation_matrix_sem_vars_updated.csv"))
write.csv(round(cor_mat_full, 3),
          file.path(output_path, "correlation_matrix_all_vars_reference.csv"))

# ============================================================================
# SECTION 11: CULTURAL DISTANCE COVERAGE IMPACT ANALYSIS
# ============================================================================
# Compare full analytic sample vs. listwise-complete sample (with CD)
# to assess what is lost when cultural_distance is required in the model.

cat("\n=== CULTURAL DISTANCE COVERAGE IMPACT ===\n\n")

# --- PLAT-only sample (SEM model) ---
plat_all <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))
plat_cd <- plat_all %>%
  filter(!is.na(cultural_distance))

# Platforms completely lost (all dyads missing CD)
plat_ids_with_cd <- unique(plat_cd$platform_ID)
plat_ids_all <- unique(plat_all$platform_ID)
plat_ids_lost <- setdiff(plat_ids_all, plat_ids_with_cd)

cat("--- PLAT Sample (SEM Model) ---\n")
cat(sprintf("  Full sample:     %d dyads, %d platforms, %d host countries, %d industries\n",
            nrow(plat_all), n_distinct(plat_all$platform_ID),
            n_distinct(plat_all$host_country_iso3c),
            n_distinct(plat_all$IND)))
cat(sprintf("  With CD:         %d dyads, %d platforms, %d host countries, %d industries\n",
            nrow(plat_cd), n_distinct(plat_cd$platform_ID),
            n_distinct(plat_cd$host_country_iso3c),
            n_distinct(plat_cd$IND)))
cat(sprintf("  Lost:            %d dyads, %d platforms, %d host countries\n",
            nrow(plat_all) - nrow(plat_cd),
            length(plat_ids_lost),
            n_distinct(plat_all$host_country_iso3c) - n_distinct(plat_cd$host_country_iso3c)))
cat(sprintf("  Retention:       %.1f%% dyads, %.1f%% platforms\n",
            100 * nrow(plat_cd) / nrow(plat_all),
            100 * n_distinct(plat_cd$platform_ID) / n_distinct(plat_all$platform_ID)))

# --- Full sample (all firms, robustness) ---
full_all <- mc
full_cd <- mc %>% filter(!is.na(cultural_distance))

full_ids_with_cd <- unique(full_cd$platform_ID)
full_ids_all <- unique(full_all$platform_ID)
full_ids_lost <- setdiff(full_ids_all, full_ids_with_cd)

cat("\n--- Full Sample (All Firms, Robustness) ---\n")
cat(sprintf("  Full sample:     %d dyads, %d firms, %d host countries, %d industries\n",
            nrow(full_all), n_distinct(full_all$platform_ID),
            n_distinct(full_all$host_country_iso3c),
            n_distinct(full_all$IND)))
cat(sprintf("  With CD:         %d dyads, %d firms, %d host countries, %d industries\n",
            nrow(full_cd), n_distinct(full_cd$platform_ID),
            n_distinct(full_cd$host_country_iso3c),
            n_distinct(full_cd$IND)))
cat(sprintf("  Lost:            %d dyads, %d firms, %d host countries\n",
            nrow(full_all) - nrow(full_cd),
            length(full_ids_lost),
            n_distinct(full_all$host_country_iso3c) - n_distinct(full_cd$host_country_iso3c)))
cat(sprintf("  Retention:       %.1f%% dyads, %.1f%% firms\n",
            100 * nrow(full_cd) / nrow(full_all),
            100 * n_distinct(full_cd$platform_ID) / n_distinct(full_all$platform_ID)))

# --- Detail: which platforms are completely lost? ---
if (length(plat_ids_lost) > 0) {
  cat("\n--- Platforms Completely Lost from PLAT SEM Sample ---\n")
  lost_detail <- plat_all %>%
    filter(platform_ID %in% plat_ids_lost) %>%
    distinct(platform_ID, .keep_all = TRUE) %>%
    select(platform_ID, any_of(c("firm_name", "home_country_iso3c",
                                  "home_country_name", "PLAT", "IND"))) %>%
    arrange(platform_ID)
  print(lost_detail, n = 30)
}

# --- Detail: which countries are causing the gaps? ---
cat("\n--- Countries Missing Hofstede Scores ---\n")
missing_home <- plat_all %>%
  filter(is.na(cultural_distance)) %>%
  distinct(home_country_iso3c) %>%
  filter(!home_country_iso3c %in% hofstede$iso3c |
           home_country_iso3c %in% (hofstede %>% filter(is.na(PDI) | is.na(IDV) | is.na(MAS) | is.na(UAI)) %>% pull(iso3c)))

missing_host <- plat_all %>%
  filter(is.na(cultural_distance)) %>%
  distinct(host_country_iso3c) %>%
  filter(!host_country_iso3c %in% hofstede$iso3c |
           host_country_iso3c %in% (hofstede %>% filter(is.na(PDI) | is.na(IDV) | is.na(MAS) | is.na(UAI)) %>% pull(iso3c)))

cat("  Home countries with missing/incomplete Hofstede data:",
    paste(missing_home$home_country_iso3c, collapse = ", "), "\n")
cat("  Host countries with missing/incomplete Hofstede data:",
    paste(missing_host$host_country_iso3c, collapse = ", "), "\n")

# --- By-industry breakdown ---
cat("\n--- Impact by Industry ---\n")
ind_impact <- plat_all %>%
  group_by(IND) %>%
  summarize(
    dyads_full = n(),
    dyads_cd = sum(!is.na(cultural_distance)),
    dyads_lost = sum(is.na(cultural_distance)),
    plat_full = n_distinct(platform_ID),
    plat_cd = n_distinct(platform_ID[!is.na(cultural_distance)]),
    plat_lost = plat_full - plat_cd,
    pct_dyads_retained = round(100 * dyads_cd / dyads_full, 1),
    .groups = "drop"
  ) %>%
  arrange(pct_dyads_retained)
print(ind_impact, n = 12)

# --- Export APA Word Table ---
cat("\n--- Exporting Coverage Impact Table ---\n")

impact_plat <- tibble(
  Sample = "PLAT firms (SEM)",
  `Dyads (Full)` = nrow(plat_all),
  `Dyads (With CD)` = nrow(plat_cd),
  `Dyads Lost` = nrow(plat_all) - nrow(plat_cd),
  `Platforms (Full)` = n_distinct(plat_all$platform_ID),
  `Platforms (With CD)` = n_distinct(plat_cd$platform_ID),
  `Platforms Lost` = length(plat_ids_lost),
  `Host Countries (Full)` = n_distinct(plat_all$host_country_iso3c),
  `Host Countries (With CD)` = n_distinct(plat_cd$host_country_iso3c),
  `Industries` = n_distinct(plat_cd$IND),
  `% Dyads Retained` = sprintf("%.1f%%", 100 * nrow(plat_cd) / nrow(plat_all))
)

impact_full <- tibble(
  Sample = "All firms (Robustness)",
  `Dyads (Full)` = nrow(full_all),
  `Dyads (With CD)` = nrow(full_cd),
  `Dyads Lost` = nrow(full_all) - nrow(full_cd),
  `Platforms (Full)` = n_distinct(full_all$platform_ID),
  `Platforms (With CD)` = n_distinct(full_cd$platform_ID),
  `Platforms Lost` = length(full_ids_lost),
  `Host Countries (Full)` = n_distinct(full_all$host_country_iso3c),
  `Host Countries (With CD)` = n_distinct(full_cd$host_country_iso3c),
  `Industries` = n_distinct(full_cd$IND),
  `% Dyads Retained` = sprintf("%.1f%%", 100 * nrow(full_cd) / nrow(full_all))
)

impact_table <- bind_rows(impact_plat, impact_full)

ft_impact <- flextable(impact_table) %>%
  set_header_labels(Sample = "Sample") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(impact_table), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

# By-industry table
ft_ind <- flextable(ind_impact) %>%
  set_header_labels(IND = "Industry", dyads_full = "Dyads (Full)",
                    dyads_cd = "Dyads (CD)", dyads_lost = "Lost",
                    plat_full = "PLAT (Full)", plat_cd = "PLAT (CD)",
                    plat_lost = "Lost", pct_dyads_retained = "% Retained") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(ind_impact), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

# Add to existing desc_doc (re-read it since it was already saved)
impact_doc <- read_docx()

impact_doc <- body_add_par(impact_doc, "Table X", style = "Normal")
impact_doc <- body_add_par(impact_doc, "", style = "Normal")

# Bold + italic title paragraph
impact_doc <- body_add_par(impact_doc,
  "Cultural Distance Coverage: Impact on Analytic Sample",
  style = "Normal")

impact_doc <- body_add_par(impact_doc, "", style = "Normal")
impact_doc <- body_add_flextable(impact_doc, ft_impact)
impact_doc <- body_add_par(impact_doc,
  sprintf("Note. Cultural distance computed using Kogut-Singh Index (Kogut & Singh, 1988) with Hofstede's four original dimensions (PDI, IDV, MAS, UAI). Missing countries: %s (host) and %s (home). Dyads are lost when either the home or host country lacks complete Hofstede dimension scores. All %d industries retained in both samples.",
          paste(missing_host$host_country_iso3c, collapse = ", "),
          paste(missing_home$home_country_iso3c, collapse = ", "),
          n_distinct(plat_cd$IND)),
  style = "Normal")
impact_doc <- body_add_par(impact_doc, "", style = "Normal")

impact_doc <- body_add_par(impact_doc, "Table X", style = "Normal")
impact_doc <- body_add_par(impact_doc, "", style = "Normal")
impact_doc <- body_add_par(impact_doc,
  "Cultural Distance Coverage Impact by Industry",
  style = "Normal")
impact_doc <- body_add_par(impact_doc, "", style = "Normal")
impact_doc <- body_add_flextable(impact_doc, ft_ind)
impact_doc <- body_add_par(impact_doc,
  "Note. PLAT = platform firms only. Industries sorted by % dyads retained (ascending). Lost = dyads or platforms with no cultural distance due to missing Hofstede data.",
  style = "Normal")

impact_word_path <- file.path(tables_path, "Table_Cultural_Distance_Impact.docx")
print(impact_doc, target = impact_word_path)
cat("✓ Coverage impact table saved to:", impact_word_path, "\n")

# ============================================================================
# SECTION 12: COMPLETE
# ============================================================================

cat("\n✓ Script 10 complete.\n")
cat("  Outputs:\n")
cat("    MASTER_CODEBOOK_analytic.xlsx — cultural_distance + cultural_distance_6dim added\n")
cat("    10_Updated_Descriptive_Tables.docx — 5 tables with cultural distance\n")
cat("    Table_Cultural_Distance_Impact.docx — coverage impact tables\n")
cat("    12d_cultural_distance_crossborder.png\n")
cat("    12d_cultural_distance_by_industry.png\n")
cat("    12d_domestic_vs_crossborder.png\n")
cat("    correlation_matrix_sem_vars_updated.csv\n")
cat("  Coverage:", n_computed, "/", nrow(mc), "dyads\n")
cat("  Platforms completely lost from PLAT SEM:", length(plat_ids_lost), "\n")
