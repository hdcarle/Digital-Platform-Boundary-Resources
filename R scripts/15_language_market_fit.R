# ============================================================================
# 15 - LANGUAGE-MARKET FIT: EXPLORATORY ANALYSIS
# ============================================================================
# Author: Heather Carle
# Purpose: Construct and test a dyad-level "Language-Market Fit" dimension
#          that measures how well a platform's language offerings (both natural
#          and programming languages) match the needs of each host market.
#
#          Two sub-constructs:
#            (A) Natural Language Fit  — platform's offered natural languages
#                matched against host country official language(s), weighted
#                by host EF EPI (English proficiency). EF EPI is INTEGRATED
#                into this measure rather than used as a separate control.
#            (B) Programming Language Fit — platform's offered programming
#                languages matched against host country developer community
#                language profile (from Stack Overflow 2025 Developer Survey).
#
# Input:   MASTER_CODEBOOK_analytic.xlsx (from script 06)
#          country_language_lookup.csv (host country official languages + EPI)
#          stack-overflow-developer-survey-2025/survey_results_public.csv
#          PROGRAMMING_LANGUAGES_INDEX.md (authoritative language list)
#
# Output:  MASTER_CODEBOOK_analytic.xlsx (updated with LMF columns)
#          APA Word tables + visualizations → tables and charts folder
#
# Last Updated: February 2026
#
# THEORETICAL RATIONALE:
#   LINGUISTIC_VARIETY (script 06) captures breadth — how many languages a
#   platform supports. Language-market fit captures ALIGNMENT — whether those
#   languages serve the specific markets in the dyad. This is conceptually
#   distinct from platform accessibility and may show stronger effect power
#   because it measures targeted accessibility rather than general breadth.
#
#   EF EPI is integrated rather than controlled separately because it
#   represents the mechanism: English proficiency determines whether
#   English-only resources functionally "fit" a market. Baking it in captures
#   this directly rather than controlling it away.
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)
library(flextable)
library(officer)
library(ggplot2)

# moments package for skewness/kurtosis (install if needed)
if (!requireNamespace("moments", quietly = TRUE)) install.packages("moments")
library(moments)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"

codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
country_lookup_path <- file.path(base_path, "REFERENCE",
                                 "country_language_lookup.csv")
so_survey_path <- file.path(base_path, "dissertation data", "Control data",
                            "stack-overflow-developer-survey-2025",
                            "survey_results_public.csv")
output_tables <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

# ============================================================================
# SECTION 3: LOAD DATA
# ============================================================================

cat("=== LOADING DATA ===\n\n")

mc <- read_excel(codebook_path)
cat("  Master codebook:", nrow(mc), "rows,", ncol(mc), "columns\n")

country_lookup <- read.csv(country_lookup_path, stringsAsFactors = FALSE)
cat("  Country-language lookup:", nrow(country_lookup), "host countries\n")

so_raw <- read.csv(so_survey_path, stringsAsFactors = FALSE)
cat("  Stack Overflow survey:", nrow(so_raw), "respondents\n\n")

# ============================================================================
# SECTION 4: BUILD HOST COUNTRY OFFICIAL LANGUAGE LOOKUP
# ============================================================================

cat("=== BUILDING NATURAL LANGUAGE LOOKUP ===\n\n")

# Expand country_lookup so each row is one country × one official language
country_lang_long <- country_lookup %>%
  mutate(official_languages = str_split(official_languages, ";\\s*")) %>%
  unnest(official_languages) %>%
  rename(official_lang = official_languages) %>%
  mutate(official_lang = str_to_lower(str_trim(official_lang)))

cat("  Expanded to", nrow(country_lang_long), "country-language pairs\n")
cat("  Unique official languages:", n_distinct(country_lang_long$official_lang), "\n\n")

# ============================================================================
# SECTION 5: PARSE PLATFORM NATURAL LANGUAGE OFFERINGS
# ============================================================================

cat("=== PARSING PLATFORM NATURAL LANGUAGE OFFERINGS ===\n\n")

# The 8 _lang_list fields contain semicolon-separated natural languages
nat_lang_cols <- c("SDK_lang_list", "COM_lang_list", "GIT_lang_list",
                   "SPAN_lang_list", "ROLE_lang_list", "DATA_lang_list",
                   "STORE_lang_list", "CERT_lang_list")

# Build a single set of natural languages offered per platform
# (union across all 8 resource types)
platform_nat_langs <- mc %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  rowwise() %>%
  mutate(
    all_nat_langs_raw = paste(
      na.omit(c_across(all_of(nat_lang_cols))),
      collapse = "; "
    )
  ) %>%
  ungroup() %>%
  select(platform_ID, all_nat_langs_raw) %>%
  mutate(
    nat_lang_set = sapply(all_nat_langs_raw, function(x) {
      if (is.na(x) || x == "" || x == "NA") return(list(character(0)))
      langs <- unique(str_to_lower(str_trim(unlist(str_split(x, ";\\s*")))))
      langs <- langs[langs != "" & langs != "na"]
      list(langs)
    })
  )

# Quick diagnostic
n_with_nat_langs <- sum(sapply(platform_nat_langs$nat_lang_set, length) > 0)
cat("  Platforms with any natural language data:", n_with_nat_langs, "/",
    nrow(platform_nat_langs), "\n")

# Show distribution
nat_lang_counts <- sapply(platform_nat_langs$nat_lang_set, length)
cat("  Natural language count distribution:\n")
print(table(nat_lang_counts))
cat("\n")

# ============================================================================
# SECTION 6: COMPUTE NATURAL LANGUAGE FIT (WITH INTEGRATED EF EPI)
# ============================================================================

cat("=== COMPUTING NATURAL LANGUAGE FIT ===\n\n")

# For each dyad (firm × host country):
#   1. Check if platform offers ANY of the host country's official languages
#      across its 8 resource types → local_lang_match (0 or 1)
#   2. Check if platform offers English → english_available (0 or 1)
#   3. Get host country's EF EPI score → normalized to 0-1 scale
#   4. Compute:
#      NLF = local_lang_match + english_available × normalized_EPI × (1 - local_lang_match)
#
#      Interpretation: if the platform offers the local language, NLF ≥ 1
#      (full local coverage). If not, English partially substitutes based on
#      host country EPI. Countries with high EPI get more credit for English.
#      The (1 - local_lang_match) term prevents double-counting when both apply.
#
# Scale: 0 (no language fit) to 1 (full local language coverage)
#         with partial credit for English in high-EPI countries

# EF EPI normalization: min-max scale to [0, 1]
epi_min <- 400   # theoretical/observed floor
epi_max <- 700   # theoretical/observed ceiling
normalize_epi <- function(epi) {
  ifelse(is.na(epi), NA, pmin(pmax((epi - epi_min) / (epi_max - epi_min), 0), 1))
}

# Build lookup: platform_ID → language set (as named list for fast access)
plat_lang_lookup <- setNames(
  platform_nat_langs$nat_lang_set,
  platform_nat_langs$platform_ID
)

# Build lookup: host country → official languages (lowercase list)
host_lang_lookup <- setNames(
  lapply(country_lookup$official_languages, function(x) {
    str_to_lower(str_trim(unlist(str_split(x, ";\\s*"))))
  }),
  country_lookup$host_country_iso3c
)

# Vectorized computation using sapply over row indices
cat("  Computing NLF for", nrow(mc), "dyads...")

mc$host_epi_norm <- normalize_epi(as.numeric(mc$host_ef_epi_rank))

nlf_results <- sapply(seq_len(nrow(mc)), function(i) {
  pid <- mc$platform_ID[i]
  host_iso <- mc$host_country_iso3c[i]

  # Get platform language set
  p_langs <- plat_lang_lookup[[pid]]
  if (is.null(p_langs) || length(p_langs) == 0) return(NA_real_)

  # Get host official languages
  h_langs <- host_lang_lookup[[host_iso]]
  if (is.null(h_langs)) return(NA_real_)

  # Match checks
  local_match <- as.numeric(any(p_langs %in% h_langs))
  eng_avail <- as.numeric("english" %in% p_langs)
  epi_norm <- mc$host_epi_norm[i]

  # NLF formula
  if (is.na(epi_norm)) {
    return(local_match)  # no EPI → binary only
  }
  pmin(local_match + eng_avail * epi_norm * (1 - local_match), 1)
})

mc$nat_lang_fit <- nlf_results

# Also store intermediate columns for diagnostics
mc$local_lang_match <- sapply(seq_len(nrow(mc)), function(i) {
  p_langs <- plat_lang_lookup[[mc$platform_ID[i]]]
  h_langs <- host_lang_lookup[[mc$host_country_iso3c[i]]]
  if (is.null(p_langs) || length(p_langs) == 0 || is.null(h_langs)) return(NA_real_)
  as.numeric(any(p_langs %in% h_langs))
})

mc$english_available <- sapply(seq_len(nrow(mc)), function(i) {
  p_langs <- plat_lang_lookup[[mc$platform_ID[i]]]
  if (is.null(p_langs) || length(p_langs) == 0) return(NA_real_)
  as.numeric("english" %in% p_langs)
})

cat(" done.\n")

# Diagnostic
cat("Natural Language Fit distribution (PLAT firms, non-NA):\n")
nlf_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(nat_lang_fit)) %>%
  pull(nat_lang_fit)
cat(sprintf("  N = %d dyads\n", length(nlf_summary)))
cat(sprintf("  Mean = %.3f, SD = %.3f\n", mean(nlf_summary), sd(nlf_summary)))
cat(sprintf("  Min = %.3f, Max = %.3f\n", min(nlf_summary), max(nlf_summary)))
cat(sprintf("  Median = %.3f\n\n", median(nlf_summary)))

# ============================================================================
# SECTION 7: BUILD PROGRAMMING LANGUAGE COUNTRY PROFILES (STACK OVERFLOW)
# ============================================================================

cat("=== BUILDING PROGRAMMING LANGUAGE COUNTRY PROFILES ===\n\n")

# Map SO survey country names to ISO3C codes
so_country_map <- c(
  "Argentina" = "ARG", "Australia" = "AUS", "Austria" = "AUT",
  "Belgium" = "BEL", "Brazil" = "BRA", "Bulgaria" = "BGR",
  "Canada" = "CAN", "Chile" = "CHL", "China" = "CHN",
  "Colombia" = "COL", "Croatia" = "HRV", "Czech Republic" = "CZE",
  "Denmark" = "DNK", "Ecuador" = "ECU", "Egypt" = "EGY",
  "Finland" = "FIN", "France" = "FRA", "Germany" = "DEU",
  "Greece" = "GRC", "Hong Kong (S.A.R.)" = "HKG", "Hungary" = "HUN",
  "India" = "IND", "Indonesia" = "IDN", "Ireland" = "IRL",
  "Israel" = "ISR", "Italy" = "ITA", "Japan" = "JPN",
  "Kenya" = "KEN", "Malaysia" = "MYS", "Mexico" = "MEX",
  "Morocco" = "MAR", "Netherlands" = "NLD", "New Zealand" = "NZL",
  "Nigeria" = "NGA", "Norway" = "NOR", "Peru" = "PER",
  "Philippines" = "PHL", "Poland" = "POL", "Portugal" = "PRT",
  "Romania" = "ROU", "Russian Federation" = "RUS",
  "Saudi Arabia" = "SAU", "Singapore" = "SGP", "Slovakia" = "SVK",
  "South Africa" = "ZAF", "South Korea" = "KOR",
  "Republic of Korea" = "KOR",
  "Spain" = "ESP", "Sweden" = "SWE", "Switzerland" = "CHE",
  "Taiwan" = "TWN", "Thailand" = "THA", "Turkey" = "TUR",
  "Ukraine" = "UKR", "United Arab Emirates" = "ARE",
  "United Kingdom of Great Britain and Northern Ireland" = "GBR",
  "United States of America" = "USA",
  "Viet Nam" = "VNM", "Vietnam" = "VNM"
)

# Map SO programming language names to our index names
so_lang_name_map <- c(
  "Bash/Shell (all shells)" = "Bash/Shell",
  "COBOL" = "Cobol",
  "Visual Basic (.Net)" = "Visual Basic"
)

# Filter SO data to mapped countries and parse languages
so_filtered <- so_raw %>%
  filter(Country %in% names(so_country_map),
         !is.na(LanguageHaveWorkedWith),
         LanguageHaveWorkedWith != "") %>%
  mutate(iso3c = so_country_map[Country])

cat("  SO respondents in mapped countries:", nrow(so_filtered), "\n")
cat("  Countries covered:", n_distinct(so_filtered$iso3c), "\n\n")

# Compute country-level programming language shares
# For each country: what % of developers use each language?
so_country_profiles <- so_filtered %>%
  mutate(lang_list = str_split(LanguageHaveWorkedWith, ";\\s*")) %>%
  unnest(lang_list) %>%
  mutate(
    lang_list = str_trim(lang_list),
    # Apply name mapping
    lang_list = ifelse(lang_list %in% names(so_lang_name_map),
                       so_lang_name_map[lang_list],
                       lang_list)
  ) %>%
  group_by(iso3c, lang_list) %>%
  summarize(n_devs = n(), .groups = "drop") %>%
  # Get country totals

  left_join(
    so_filtered %>% group_by(iso3c) %>% summarize(n_total = n(), .groups = "drop"),
    by = "iso3c"
  ) %>%
  mutate(lang_share = n_devs / n_total) %>%
  rename(prog_lang = lang_list)

cat("  Country-language profiles:", nrow(so_country_profiles), "rows\n")
cat("  Example (USA top 5):\n")
so_country_profiles %>%
  filter(iso3c == "USA") %>%
  arrange(desc(lang_share)) %>%
  head(5) %>%
  mutate(lang_share = round(lang_share, 3)) %>%
  print()
cat("\n")

# Minimum sample size filter — require at least 30 respondents per country
# for reliable language profiles
country_sample_sizes <- so_filtered %>%
  group_by(iso3c) %>%
  summarize(so_n = n(), .groups = "drop")

cat("  Countries with n >= 30 SO respondents:\n")
cat("  ", sum(country_sample_sizes$so_n >= 30), "of",
    nrow(country_sample_sizes), "\n")
small_countries <- country_sample_sizes %>% filter(so_n < 30)
if (nrow(small_countries) > 0) {
  cat("  Countries with < 30 respondents (unreliable profiles):\n")
  print(small_countries)
}
cat("\n")

# ============================================================================
# SECTION 8: PARSE PLATFORM PROGRAMMING LANGUAGE OFFERINGS
# ============================================================================

cat("=== PARSING PLATFORM PROGRAMMING LANGUAGE OFFERINGS ===\n\n")

prog_lang_cols <- c("SDK_prog_lang_list", "GIT_prog_lang_list", "BUG_prog_lang_list")

# Build union of programming languages per platform
platform_prog_langs <- mc %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  rowwise() %>%
  mutate(
    all_prog_langs_raw = paste(
      na.omit(c_across(all_of(prog_lang_cols))),
      collapse = "; "
    )
  ) %>%
  ungroup() %>%
  select(platform_ID, all_prog_langs_raw) %>%
  mutate(
    prog_lang_set = sapply(all_prog_langs_raw, function(x) {
      if (is.na(x) || x == "" || x == "NA") return(list(character(0)))
      langs <- unique(str_trim(unlist(str_split(x, ";\\s*"))))
      langs <- langs[langs != "" & langs != "NA" & langs != "na"]
      list(langs)
    })
  )

n_with_prog <- sum(sapply(platform_prog_langs$prog_lang_set, length) > 0)
cat("  Platforms with programming language data:", n_with_prog, "/",
    nrow(platform_prog_langs), "\n\n")

# ============================================================================
# SECTION 9: COMPUTE PROGRAMMING LANGUAGE FIT
# ============================================================================

cat("=== COMPUTING PROGRAMMING LANGUAGE FIT ===\n\n")

# For each dyad:
#   1. Get platform's programming language set
#   2. Get host country's developer language profile (from SO)
#   3. Sum the market shares of all languages the platform supports
#      → "What fraction of this country's developers use languages
#         that this platform supports?"
#
# Scale: 0 (no overlap) to ~1 (platform covers most of the market's languages)
# Can theoretically exceed 1 since developers use multiple languages,
# but in practice stays below 1.

# Build lookups for fast access
plat_prog_lookup <- setNames(
  platform_prog_langs$prog_lang_set,
  platform_prog_langs$platform_ID
)

# Build country profile lookup: iso3c → named vector of (lang → share)
valid_so_countries <- country_sample_sizes$iso3c[country_sample_sizes$so_n >= 30]

country_prog_profiles <- list()
for (iso in valid_so_countries) {
  profile <- so_country_profiles %>% filter(iso3c == iso)
  country_prog_profiles[[iso]] <- setNames(profile$lang_share, profile$prog_lang)
}

# Vectorized computation
cat("  Computing PLF for", nrow(mc), "dyads...")

mc$prog_lang_fit <- sapply(seq_len(nrow(mc)), function(i) {
  pid <- mc$platform_ID[i]
  host_iso <- mc$host_country_iso3c[i]

  p_langs <- plat_prog_lookup[[pid]]
  if (is.null(p_langs) || length(p_langs) == 0 || is.na(host_iso)) return(NA_real_)

  profile <- country_prog_profiles[[host_iso]]
  if (is.null(profile)) return(NA_real_)

  # Sum market shares for languages the platform supports
  matched <- p_langs[p_langs %in% names(profile)]
  if (length(matched) == 0) return(0)

  pmin(sum(profile[matched]), 1)
})

cat(" done.\n")

# Diagnostic
cat("Programming Language Fit distribution (PLAT firms, non-NA):\n")
plf_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(prog_lang_fit)) %>%
  pull(prog_lang_fit)
cat(sprintf("  N = %d dyads\n", length(plf_summary)))
cat(sprintf("  Mean = %.3f, SD = %.3f\n", mean(plf_summary), sd(plf_summary)))
cat(sprintf("  Min = %.3f, Max = %.3f\n", min(plf_summary), max(plf_summary)))
cat(sprintf("  Median = %.3f\n\n", median(plf_summary)))

# ============================================================================
# SECTION 10: COMBINED LANGUAGE-MARKET FIT INDEX
# ============================================================================

cat("=== COMPUTING COMBINED LANGUAGE-MARKET FIT INDEX ===\n\n")

# Z-standardize both sub-constructs across PLAT firms, then average
plat_dyads <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

# Parameters from PLAT firms with valid data
nlf_mean <- mean(plat_dyads$nat_lang_fit, na.rm = TRUE)
nlf_sd   <- sd(plat_dyads$nat_lang_fit, na.rm = TRUE)
plf_mean <- mean(plat_dyads$prog_lang_fit, na.rm = TRUE)
plf_sd   <- sd(plat_dyads$prog_lang_fit, na.rm = TRUE)

cat(sprintf("  Nat Lang Fit:  mean=%.4f, sd=%.4f\n", nlf_mean, nlf_sd))
cat(sprintf("  Prog Lang Fit: mean=%.4f, sd=%.4f\n", plf_mean, plf_sd))

mc <- mc %>%
  mutate(
    z_nat_lang_fit  = (nat_lang_fit  - nlf_mean)  / nlf_sd,
    z_prog_lang_fit = (prog_lang_fit - plf_mean) / plf_sd,

    # Combined Language-Market Fit index
    # Average of z-scored sub-components (when both available)
    # Falls back to single component when only one is available
    language_market_fit = case_when(
      !is.na(z_nat_lang_fit) & !is.na(z_prog_lang_fit) ~
        (z_nat_lang_fit + z_prog_lang_fit) / 2,
      !is.na(z_nat_lang_fit) ~ z_nat_lang_fit,
      !is.na(z_prog_lang_fit) ~ z_prog_lang_fit,
      TRUE ~ NA_real_
    )
  )

cat("\nCombined Language-Market Fit (PLAT firms, non-NA):\n")
lmf_summary <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(language_market_fit)) %>%
  pull(language_market_fit)
cat(sprintf("  N = %d dyads\n", length(lmf_summary)))
cat(sprintf("  Mean = %.3f, SD = %.3f\n", mean(lmf_summary), sd(lmf_summary)))
cat(sprintf("  Min = %.3f, Max = %.3f\n", min(lmf_summary), max(lmf_summary)))
cat(sprintf("  Median = %.3f\n\n", median(lmf_summary)))

# ============================================================================
# SECTION 11: SAMPLE COVERAGE ANALYSIS
# ============================================================================

cat("=== SAMPLE COVERAGE ANALYSIS ===\n\n")

# --- 11a: Overall coverage ---
plat_dyads_all <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

# Count language data from the lookup objects (NOT from plat_dyads_all columns,
# since nat_lang_set and prog_lang_set are list-columns stored in separate
# intermediate objects, not joined to the main data frame)
nat_lang_plat_ids <- platform_nat_langs$platform_ID[
  sapply(platform_nat_langs$nat_lang_set, length) > 0]
prog_lang_plat_ids <- platform_prog_langs$platform_ID[
  sapply(platform_prog_langs$prog_lang_set, length) > 0]

n_nat_dyads <- sum(plat_dyads_all$platform_ID %in% nat_lang_plat_ids)
n_prog_dyads <- sum(plat_dyads_all$platform_ID %in% prog_lang_plat_ids)
n_nat_plats <- n_distinct(plat_dyads_all$platform_ID[
  plat_dyads_all$platform_ID %in% nat_lang_plat_ids])
n_prog_plats <- n_distinct(plat_dyads_all$platform_ID[
  plat_dyads_all$platform_ID %in% prog_lang_plat_ids])

coverage <- tibble(
  Measure = c("Total PLAT dyads",
              "With Natural Language data",
              "With Programming Language data",
              "With Host EF EPI",
              "With SO country profile (n >= 30)",
              "Natural Language Fit (non-NA)",
              "Programming Language Fit (non-NA)",
              "Combined LMF (both components)",
              "Combined LMF (any component)"),
  N_dyads = c(
    nrow(plat_dyads_all),
    n_nat_dyads,
    n_prog_dyads,
    sum(!is.na(plat_dyads_all$host_ef_epi_rank)),
    sum(plat_dyads_all$host_country_iso3c %in%
          country_sample_sizes$iso3c[country_sample_sizes$so_n >= 30]),
    sum(!is.na(plat_dyads_all$nat_lang_fit)),
    sum(!is.na(plat_dyads_all$prog_lang_fit)),
    sum(!is.na(plat_dyads_all$z_nat_lang_fit) &
          !is.na(plat_dyads_all$z_prog_lang_fit)),
    sum(!is.na(plat_dyads_all$language_market_fit))
  ),
  N_platforms = c(
    n_distinct(plat_dyads_all$platform_ID),
    n_nat_plats,
    n_prog_plats,
    n_distinct(plat_dyads_all$platform_ID[
      !is.na(plat_dyads_all$host_ef_epi_rank)]),
    n_distinct(plat_dyads_all$platform_ID[
      plat_dyads_all$host_country_iso3c %in%
        country_sample_sizes$iso3c[country_sample_sizes$so_n >= 30]]),
    n_distinct(plat_dyads_all$platform_ID[
      !is.na(plat_dyads_all$nat_lang_fit)]),
    n_distinct(plat_dyads_all$platform_ID[
      !is.na(plat_dyads_all$prog_lang_fit)]),
    n_distinct(plat_dyads_all$platform_ID[
      !is.na(plat_dyads_all$z_nat_lang_fit) &
        !is.na(plat_dyads_all$z_prog_lang_fit)]),
    n_distinct(plat_dyads_all$platform_ID[
      !is.na(plat_dyads_all$language_market_fit)])
  ),
  Pct_dyads = sprintf("%.1f%%",
    c(nrow(plat_dyads_all), n_nat_dyads, n_prog_dyads,
      sum(!is.na(plat_dyads_all$host_ef_epi_rank)),
      sum(plat_dyads_all$host_country_iso3c %in%
            country_sample_sizes$iso3c[country_sample_sizes$so_n >= 30]),
      sum(!is.na(plat_dyads_all$nat_lang_fit)),
      sum(!is.na(plat_dyads_all$prog_lang_fit)),
      sum(!is.na(plat_dyads_all$z_nat_lang_fit) &
            !is.na(plat_dyads_all$z_prog_lang_fit)),
      sum(!is.na(plat_dyads_all$language_market_fit))
    ) / nrow(plat_dyads_all) * 100)
)

cat("Overall Coverage:\n")
print(coverage, n = Inf)
cat("\n")

# --- 11b: Coverage by industry ---
industry_coverage <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  group_by(IND) %>%
  summarize(
    N_dyads = n(),
    N_platforms = n_distinct(platform_ID),
    NLF_n = sum(!is.na(nat_lang_fit)),
    NLF_pct = round(NLF_n / N_dyads * 100, 1),
    PLF_n = sum(!is.na(prog_lang_fit)),
    PLF_pct = round(PLF_n / N_dyads * 100, 1),
    LMF_n = sum(!is.na(language_market_fit)),
    LMF_pct = round(LMF_n / N_dyads * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(desc(LMF_pct))

cat("Coverage by Industry:\n")
print(industry_coverage, n = Inf)
cat("\n")

# --- 11c: Coverage by PLAT type ---
plat_type_coverage <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  group_by(PLAT) %>%
  summarize(
    N_dyads = n(),
    N_platforms = n_distinct(platform_ID),
    NLF_n = sum(!is.na(nat_lang_fit)),
    NLF_pct = round(NLF_n / N_dyads * 100, 1),
    PLF_n = sum(!is.na(prog_lang_fit)),
    PLF_pct = round(PLF_n / N_dyads * 100, 1),
    LMF_n = sum(!is.na(language_market_fit)),
    LMF_pct = round(LMF_n / N_dyads * 100, 1),
    .groups = "drop"
  )

cat("Coverage by Platform Type:\n")
print(plat_type_coverage, n = Inf)
cat("\n")

# ============================================================================
# SECTION 12: DESCRIPTIVE STATISTICS
# ============================================================================

cat("=== DESCRIPTIVE STATISTICS ===\n\n")

# --- 12a: Natural Language Fit descriptives ---
nlf_desc <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(nat_lang_fit)) %>%
  summarize(
    N = n(),
    M = round(mean(nat_lang_fit), 3),
    SD = round(sd(nat_lang_fit), 3),
    Mdn = round(median(nat_lang_fit), 3),
    Min = round(min(nat_lang_fit), 3),
    Max = round(max(nat_lang_fit), 3),
    Skew = round(moments::skewness(nat_lang_fit), 3),
    Kurt = round(moments::kurtosis(nat_lang_fit), 3)
  )

# --- 12b: Programming Language Fit descriptives ---
plf_desc <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(prog_lang_fit)) %>%
  summarize(
    N = n(),
    M = round(mean(prog_lang_fit), 3),
    SD = round(sd(prog_lang_fit), 3),
    Mdn = round(median(prog_lang_fit), 3),
    Min = round(min(prog_lang_fit), 3),
    Max = round(max(prog_lang_fit), 3),
    Skew = round(moments::skewness(prog_lang_fit), 3),
    Kurt = round(moments::kurtosis(prog_lang_fit), 3)
  )

# --- 12c: Combined LMF descriptives ---
lmf_desc <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(language_market_fit)) %>%
  summarize(
    N = n(),
    M = round(mean(language_market_fit), 3),
    SD = round(sd(language_market_fit), 3),
    Mdn = round(median(language_market_fit), 3),
    Min = round(min(language_market_fit), 3),
    Max = round(max(language_market_fit), 3),
    Skew = round(moments::skewness(language_market_fit), 3),
    Kurt = round(moments::kurtosis(language_market_fit), 3)
  )

desc_table <- bind_rows(
  nlf_desc %>% mutate(Variable = "Natural Language Fit", .before = 1),
  plf_desc %>% mutate(Variable = "Programming Language Fit", .before = 1),
  lmf_desc %>% mutate(Variable = "Language-Market Fit (combined)", .before = 1)
)

cat("Descriptive Statistics:\n")
print(desc_table)
cat("\n")

# --- 12d: Descriptives by Industry ---
desc_by_industry <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(language_market_fit)) %>%
  group_by(IND) %>%
  summarize(
    N = n(),
    n_plat = n_distinct(platform_ID),
    NLF_M = round(mean(nat_lang_fit, na.rm = TRUE), 3),
    NLF_SD = round(sd(nat_lang_fit, na.rm = TRUE), 3),
    PLF_M = round(mean(prog_lang_fit, na.rm = TRUE), 3),
    PLF_SD = round(sd(prog_lang_fit, na.rm = TRUE), 3),
    LMF_M = round(mean(language_market_fit, na.rm = TRUE), 3),
    LMF_SD = round(sd(language_market_fit, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(desc(LMF_M))

cat("Descriptives by Industry:\n")
print(desc_by_industry, n = Inf)
cat("\n")

# --- 12e: Descriptives by PLAT type ---
desc_by_plat <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(language_market_fit)) %>%
  group_by(PLAT) %>%
  summarize(
    N = n(),
    n_plat = n_distinct(platform_ID),
    NLF_M = round(mean(nat_lang_fit, na.rm = TRUE), 3),
    NLF_SD = round(sd(nat_lang_fit, na.rm = TRUE), 3),
    PLF_M = round(mean(prog_lang_fit, na.rm = TRUE), 3),
    PLF_SD = round(sd(prog_lang_fit, na.rm = TRUE), 3),
    LMF_M = round(mean(language_market_fit, na.rm = TRUE), 3),
    LMF_SD = round(sd(language_market_fit, na.rm = TRUE), 3),
    .groups = "drop"
  )

cat("Descriptives by Platform Type:\n")
print(desc_by_plat, n = Inf)
cat("\n")

# --- 12f: Correlation with existing measures ---
cor_data <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE) %>%
  select(language_market_fit, nat_lang_fit, prog_lang_fit,
         LINGUISTIC_VARIETY, programming_lang_variety,
         platform_accessibility, platform_resources) %>%
  filter(complete.cases(.))

if (nrow(cor_data) > 5) {
  cat("Correlations with existing measures (platform-level, N =", nrow(cor_data), "):\n")
  cor_mat <- cor(cor_data, use = "pairwise.complete.obs")
  print(round(cor_mat, 3))
  cat("\n")
}

# ============================================================================
# SECTION 12g: LANGUAGE CHARACTERIZATION — TOP LANGUAGES FOUND IN SAMPLE
# ============================================================================
# Produces frequency tables of individual natural languages and programming
# languages found across the 230 PLAT platforms (from adjudicated data).
# These describe WHAT languages appear, complementing the fit scores above.
# ============================================================================

cat("=== LANGUAGE CHARACTERIZATION ===\n\n")

# --- 12g.1: Top Natural Languages Across All Resource Types ---
# Parse all _lang_list columns to extract individual language mentions

nat_lang_list_cols <- c("SDK_lang_list", "COM_lang_list", "GIT_lang_list",
                        "SPAN_lang_list", "ROLE_lang_list", "DATA_lang_list",
                        "STORE_lang_list", "CERT_lang_list")

# Get unique PLAT platforms
plat_unique <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE)

n_plat_total <- nrow(plat_unique)
cat("  PLAT platforms for characterization:", n_plat_total, "\n\n")

# Parse each _lang_list per platform, get union of languages per platform
plat_nat_langs_parsed <- plat_unique %>%
  rowwise() %>%
  mutate(
    all_nat_raw = paste(na.omit(c_across(all_of(nat_lang_list_cols))), collapse = "; ")
  ) %>%
  ungroup() %>%
  select(platform_ID, all_nat_raw) %>%
  mutate(
    lang_list = lapply(all_nat_raw, function(x) {
      if (is.na(x) || x == "" || x == "NA") return(character(0))
      langs <- unique(str_to_title(str_trim(unlist(str_split(x, ";\\s*")))))
      langs[langs != "" & langs != "Na" & langs != "NA"]
    })
  )

# Explode to one row per platform × language, then count platforms per language
nat_lang_freq <- plat_nat_langs_parsed %>%
  unnest(lang_list) %>%
  rename(Language = lang_list) %>%
  distinct(platform_ID, Language) %>%
  count(Language, name = "n_platforms") %>%
  mutate(pct = round(n_platforms / n_plat_total * 100, 1)) %>%
  arrange(desc(n_platforms))

cat("--- Top 20 Natural Languages (platforms with at least 1 mention) ---\n")
print(nat_lang_freq %>% slice_head(n = 20), n = 20)
cat(sprintf("\n  Total distinct natural languages found: %d\n", nrow(nat_lang_freq)))

# Per-resource-type natural language frequency (how many platforms mention each
# language in each specific resource type)
nat_by_resource <- list()
resource_labels_nat <- c(
  SDK_lang_list = "SDK", COM_lang_list = "Communication",
  GIT_lang_list = "GitHub", SPAN_lang_list = "Boundary Spanning",
  ROLE_lang_list = "Role/Access", DATA_lang_list = "Data Governance",
  STORE_lang_list = "App Store", CERT_lang_list = "Certification"
)

for (col in nat_lang_list_cols) {
  parsed <- plat_unique %>%
    select(platform_ID, !!sym(col)) %>%
    filter(!is.na(!!sym(col)) & !!sym(col) != "" & !!sym(col) != "NA") %>%
    mutate(
      lang_list = lapply(!!sym(col), function(x) {
        unique(str_to_title(str_trim(unlist(str_split(x, ";\\s*")))))
      })
    ) %>%
    unnest(lang_list) %>%
    rename(Language = lang_list) %>%
    distinct(platform_ID, Language) %>%
    count(Language, name = "n_platforms") %>%
    mutate(Resource = resource_labels_nat[[col]])
  nat_by_resource[[col]] <- parsed
}

nat_by_resource_df <- bind_rows(nat_by_resource) %>%
  mutate(pct = round(n_platforms / n_plat_total * 100, 1))

# --- 12g.2: Top Programming Languages Across All 3 Sources ---
prog_lang_list_cols <- c("SDK_prog_lang_list", "BUG_prog_lang_list", "GIT_prog_lang_list")

plat_prog_langs_parsed <- plat_unique %>%
  rowwise() %>%
  mutate(
    all_prog_raw = paste(na.omit(c_across(all_of(prog_lang_list_cols))), collapse = "; ")
  ) %>%
  ungroup() %>%
  select(platform_ID, all_prog_raw) %>%
  mutate(
    lang_list = lapply(all_prog_raw, function(x) {
      if (is.na(x) || x == "" || x == "NA") return(character(0))
      langs <- unique(str_trim(unlist(str_split(x, ";\\s*"))))
      langs[langs != "" & langs != "NA" & langs != "na"]
    })
  )

prog_lang_freq <- plat_prog_langs_parsed %>%
  unnest(lang_list) %>%
  rename(Language = lang_list) %>%
  distinct(platform_ID, Language) %>%
  count(Language, name = "n_platforms") %>%
  mutate(pct = round(n_platforms / n_plat_total * 100, 1)) %>%
  arrange(desc(n_platforms))

cat("\n--- Top 20 Programming Languages (platforms with at least 1 mention) ---\n")
print(prog_lang_freq %>% slice_head(n = 20), n = 20)
cat(sprintf("\n  Total distinct programming languages found: %d\n", nrow(prog_lang_freq)))

# Per-source programming language frequency
resource_labels_prog <- c(
  SDK_prog_lang_list = "SDK", BUG_prog_lang_list = "Bug Tracking",
  GIT_prog_lang_list = "GitHub"
)

prog_by_source <- list()
for (col in prog_lang_list_cols) {
  parsed <- plat_unique %>%
    select(platform_ID, !!sym(col)) %>%
    filter(!is.na(!!sym(col)) & !!sym(col) != "" & !!sym(col) != "NA") %>%
    mutate(
      lang_list = lapply(!!sym(col), function(x) {
        unique(str_trim(unlist(str_split(x, ";\\s*"))))
      })
    ) %>%
    unnest(lang_list) %>%
    rename(Language = lang_list) %>%
    distinct(platform_ID, Language) %>%
    count(Language, name = "n_platforms") %>%
    mutate(Source = resource_labels_prog[[col]])
  prog_by_source[[col]] <- parsed
}

prog_by_source_df <- bind_rows(prog_by_source) %>%
  mutate(pct = round(n_platforms / n_plat_total * 100, 1))

# --- 12g.3: Build APA flextables for language characterization ---

# Table A: Top natural languages (top 20)
nat_lang_table <- nat_lang_freq %>%
  slice_head(n = 20) %>%
  rename(`Natural Language` = Language,
         `n Platforms` = n_platforms,
         `% of PLAT` = pct)

ft_nat_lang <- nat_lang_table %>%
  flextable() %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 10, part = "all") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "all") %>%
  bold(part = "header") %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  autofit()

# Table B: Top programming languages (top 20)
prog_lang_table <- prog_lang_freq %>%
  slice_head(n = 20) %>%
  rename(`Programming Language` = Language,
         `n Platforms` = n_platforms,
         `% of PLAT` = pct)

ft_prog_lang <- prog_lang_table %>%
  flextable() %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 10, part = "all") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "all") %>%
  bold(part = "header") %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  autofit()

# Table C: Programming languages by source (SDK vs BUG vs GIT, top 15 per source)
prog_by_source_wide <- prog_by_source_df %>%
  group_by(Source) %>%
  arrange(desc(n_platforms)) %>%
  slice_head(n = 15) %>%
  ungroup() %>%
  select(Language, Source, n_platforms) %>%
  pivot_wider(names_from = Source, values_from = n_platforms, values_fill = 0) %>%
  mutate(Total = rowSums(across(where(is.numeric)))) %>%
  arrange(desc(Total))

ft_prog_by_source <- prog_by_source_wide %>%
  rename(`Programming Language` = Language) %>%
  flextable() %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 10, part = "all") %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "all") %>%
  bold(part = "header") %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  autofit()

cat("\n  Language characterization tables prepared for Word export.\n\n")

# --- 12g.4: Language characterization bar charts ---

# Chart A: Top 15 natural languages
nat_top15 <- nat_lang_freq %>% slice_head(n = 15)
nat_top15$Language <- factor(nat_top15$Language, levels = rev(nat_top15$Language))

p_nat_char <- ggplot(nat_top15, aes(x = Language, y = n_platforms)) +
  geom_col(fill = "grey60", color = "black", width = 0.7, linewidth = 0.3) +
  geom_text(aes(label = paste0(n_platforms, " (", pct, "%)")),
            hjust = -0.1, size = 3, family = "Times New Roman") +
  coord_flip() +
  labs(
    subtitle = paste0("Top 15 Natural Languages Across PLAT Developer Portals (N = ",
                      n_plat_total, ")"),
    x = "", y = "Number of Platforms"
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black"),
    plot.title = element_text(face = "bold.italic", size = 12, hjust = 0),
    plot.subtitle = element_text(size = 10, hjust = 0)
  )

ggsave(file.path(output_tables, "Figure_15_0a_Top_Natural_Languages.png"),
       p_nat_char, width = 10, height = 6, dpi = 300)
cat("  Saved Figure 15.0a: Top Natural Languages\n")

# Chart B: Top 15 programming languages
prog_top15 <- prog_lang_freq %>% slice_head(n = 15)
prog_top15$Language <- factor(prog_top15$Language, levels = rev(prog_top15$Language))

p_prog_char <- ggplot(prog_top15, aes(x = Language, y = n_platforms)) +
  geom_col(fill = "grey60", color = "black", width = 0.7, linewidth = 0.3) +
  geom_text(aes(label = paste0(n_platforms, " (", pct, "%)")),
            hjust = -0.1, size = 3, family = "Times New Roman") +
  coord_flip() +
  labs(
    subtitle = paste0("Top 15 Programming Languages Across PLAT Developer Portals (N = ",
                      n_plat_total, ")"),
    x = "", y = "Number of Platforms"
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black"),
    plot.title = element_text(face = "bold.italic", size = 12, hjust = 0),
    plot.subtitle = element_text(size = 10, hjust = 0)
  )

ggsave(file.path(output_tables, "Figure_15_0b_Top_Programming_Languages.png"),
       p_prog_char, width = 10, height = 6, dpi = 300)
cat("  Saved Figure 15.0b: Top Programming Languages\n")

# Chart C: Programming languages by source (stacked bar)
prog_source_top10 <- prog_lang_freq %>% slice_head(n = 10) %>% pull(Language)
prog_source_plot <- prog_by_source_df %>%
  filter(Language %in% prog_source_top10) %>%
  mutate(
    Language = factor(Language, levels = rev(prog_source_top10)),
    Source = factor(Source, levels = c("SDK", "Bug Tracking", "GitHub"))
  )

p_prog_source <- ggplot(prog_source_plot,
                         aes(x = Language, y = n_platforms, fill = Source)) +
  geom_col(position = "dodge", width = 0.7, color = "black", linewidth = 0.2) +
  coord_flip() +
  scale_fill_manual(values = c("SDK" = "#4C72B0", "Bug Tracking" = "#DD8452",
                                "GitHub" = "#55A868")) +
  labs(
    subtitle = "Top 10 Programming Languages by Detection Source",
    x = "", y = "Number of Platforms", fill = "Source"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black"),
    plot.title = element_text(face = "bold.italic", size = 12, hjust = 0),
    plot.subtitle = element_text(size = 10, hjust = 0),
    legend.position = "bottom"
  )

ggsave(file.path(output_tables, "Figure_15_0c_Prog_Languages_by_Source.png"),
       p_prog_source, width = 10, height = 6, dpi = 300)
cat("  Saved Figure 15.0c: Programming Languages by Source\n\n")

# Export CSV summaries for reference
write.csv(nat_lang_freq,
          file.path(base_path, "dissertation analysis", "15_nat_lang_frequency.csv"),
          row.names = FALSE)
write.csv(prog_lang_freq,
          file.path(base_path, "dissertation analysis", "15_prog_lang_frequency.csv"),
          row.names = FALSE)
write.csv(prog_by_source_df,
          file.path(base_path, "dissertation analysis", "15_prog_lang_by_source.csv"),
          row.names = FALSE)
cat("  Exported 3 language frequency CSV files.\n\n")


# ============================================================================
# SECTION 13: APA FORMATTED WORD TABLE EXPORTS
# ============================================================================

cat("=== EXPORTING APA TABLES ===\n\n")

# Helper: APA table style
apa_style <- function(ft, title_text, note_text = NULL) {
  ft <- ft %>%
    font(fontname = "Times New Roman", part = "all") %>%
    fontsize(size = 10, part = "body") %>%
    fontsize(size = 10, part = "header") %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "all") %>%
    bold(part = "header") %>%
    border_remove() %>%
    hline_top(border = fp_border(width = 2), part = "header") %>%
    hline_bottom(border = fp_border(width = 1), part = "header") %>%
    hline_bottom(border = fp_border(width = 2), part = "body") %>%
    autofit()

  ft
}

# --- Table 1: Descriptive Statistics ---
ft_desc <- desc_table %>%
  flextable() %>%
  apa_style("Descriptive Statistics for Language-Market Fit Variables")

# --- Table 2: Coverage Summary ---
ft_coverage <- coverage %>%
  flextable() %>%
  apa_style("Language-Market Fit Sample Coverage")

# --- Table 3: Coverage by Industry ---
ft_ind_coverage <- industry_coverage %>%
  rename(Industry = IND) %>%
  flextable() %>%
  apa_style("Language-Market Fit Coverage by Industry")

# --- Table 4: Coverage by Platform Type ---
ft_plat_coverage <- plat_type_coverage %>%
  rename(`Platform Type` = PLAT) %>%
  flextable() %>%
  apa_style("Language-Market Fit Coverage by Platform Type")

# --- Table 5: Descriptives by Industry ---
ft_desc_ind <- desc_by_industry %>%
  rename(Industry = IND, `n (plat)` = n_plat) %>%
  flextable() %>%
  apa_style("Language-Market Fit Descriptive Statistics by Industry")

# --- Table 6: Descriptives by Platform Type ---
ft_desc_plat <- desc_by_plat %>%
  rename(`Platform Type` = PLAT, `n (plat)` = n_plat) %>%
  flextable() %>%
  apa_style("Language-Market Fit Descriptive Statistics by Platform Type")

# Assemble Word document
doc <- read_docx() %>%
  # Title page info
  body_add_par("Table 15.1", style = "Normal") %>%
  body_add_par("Descriptive Statistics for Language-Market Fit Variables",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_desc) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Natural Language Fit measures alignment between platform ",
    "language offerings and host country official languages, weighted by ",
    "EF EPI English proficiency. Programming Language Fit measures alignment ",
    "between platform programming language support and host country developer ",
    "community language profiles (Stack Overflow 2025 Developer Survey, N = ",
    format(nrow(so_filtered), big.mark = ","), "). Combined Language-Market ",
    "Fit is the mean of z-standardized sub-components."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table 15.2", style = "Normal") %>%
  body_add_par("Language-Market Fit Sample Coverage", style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_coverage) %>%
  body_add_break() %>%

  body_add_par("Table 15.3", style = "Normal") %>%
  body_add_par("Language-Market Fit Coverage by Industry", style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_ind_coverage) %>%
  body_add_break() %>%

  body_add_par("Table 15.4", style = "Normal") %>%
  body_add_par("Language-Market Fit Coverage by Platform Type",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_plat_coverage) %>%
  body_add_break() %>%

  body_add_par("Table 15.5", style = "Normal") %>%
  body_add_par("Language-Market Fit Descriptive Statistics by Industry",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_desc_ind) %>%
  body_add_break() %>%

  body_add_par("Table 15.6", style = "Normal") %>%
  body_add_par("Language-Market Fit Descriptive Statistics by Platform Type",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_desc_plat) %>%

# --- Language Characterization Tables (Tables 15.0a, 15.0b, 15.0c) ---
  body_add_break() %>%
  body_add_par("Table 15.0a", style = "Normal") %>%
  body_add_par("Top 20 Natural Languages Found Across PLAT Developer Portals",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_nat_lang) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. N = ", n_plat_total, " PLAT platforms. Counts reflect the number of ",
    "platforms where the language was found in at least one resource type ",
    "(SDK, communication, GitHub, boundary spanning, role/access, data governance, ",
    "app store, or certification documentation). Languages were identified from ",
    "adjudicated AI coding results using the Claude-primary, presence-wins rule."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table 15.0b", style = "Normal") %>%
  body_add_par("Top 20 Programming Languages Found Across PLAT Developer Portals",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_prog_lang) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. N = ", n_plat_total, " PLAT platforms. Counts reflect the number of ",
    "platforms where the programming language was found in at least one of three ",
    "sources: SDK client libraries, bug tracking/debugging tools, or GitHub ",
    "repositories. Only the 48 languages in the codebook-validated programming ",
    "language index were counted."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table 15.0c", style = "Normal") %>%
  body_add_par("Programming Languages by Detection Source (SDK, Bug Tracking, GitHub)",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_prog_by_source) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Counts show the number of platforms where each programming language ",
    "was detected, by source. SDK = languages with official SDK or client library ",
    "support. Bug Tracking = languages found in debugging/testing tools. ",
    "GitHub = languages detected from GitHub repository analysis. Total reflects ",
    "cumulative mentions (a language may appear in multiple sources for the same platform)."
  ), style = "Normal")

# Save Word document
doc_path <- file.path(output_tables, "15_Language_Market_Fit_Tables.docx")
print(doc, target = doc_path)
cat("  Saved APA tables:", doc_path, "\n\n")

# ============================================================================
# SECTION 14: VISUALIZATIONS
# ============================================================================

cat("=== GENERATING VISUALIZATIONS ===\n\n")

# Set APA-like theme
theme_apa <- theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black"),
    plot.title = element_text(face = "bold.italic", size = 12, hjust = 0),
    plot.subtitle = element_text(size = 10, hjust = 0),
    legend.position = "bottom"
  )

# --- Figure 1: Distribution of LMF components (faceted histogram) ---
plot_data <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  select(platform_ID, host_country_iso3c, nat_lang_fit, prog_lang_fit) %>%
  pivot_longer(cols = c(nat_lang_fit, prog_lang_fit),
               names_to = "Component",
               values_to = "Fit_Score") %>%
  filter(!is.na(Fit_Score)) %>%
  mutate(Component = case_when(
    Component == "nat_lang_fit" ~ "Natural Language Fit",
    Component == "prog_lang_fit" ~ "Programming Language Fit"
  ))

p1 <- ggplot(plot_data, aes(x = Fit_Score)) +
  geom_histogram(bins = 30, fill = "grey60", color = "black", linewidth = 0.3) +
  facet_wrap(~Component, scales = "free_y", ncol = 2) +
  labs(
    subtitle = "Distribution of Language-Market Fit Components (PLAT Firms)",
    x = "Fit Score",
    y = "Frequency"
  ) +
  theme_apa

ggsave(file.path(output_tables, "Figure_15_1_LMF_Distributions.png"),
       p1, width = 10, height = 5, dpi = 300)
cat("  Saved Figure 15.1: LMF component distributions\n")

# --- Figure 2: Mean LMF by Industry (bar chart with error bars) ---
plot_ind <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(language_market_fit)) %>%
  group_by(IND) %>%
  summarize(
    M = mean(language_market_fit, na.rm = TRUE),
    SE = sd(language_market_fit, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  arrange(M)

# Reorder factor for plotting
plot_ind$IND <- factor(plot_ind$IND, levels = plot_ind$IND)

p2 <- ggplot(plot_ind, aes(x = IND, y = M)) +
  geom_col(fill = "grey60", color = "black", width = 0.7, linewidth = 0.3) +
  geom_errorbar(aes(ymin = M - SE, ymax = M + SE),
                width = 0.2, linewidth = 0.4) +
  coord_flip() +
  labs(
    subtitle = "Mean Language-Market Fit by Industry (PLAT Firms)",
    x = NULL,
    y = "Mean Language-Market Fit (z-score)"
  ) +
  theme_apa

ggsave(file.path(output_tables, "Figure_15_2_LMF_by_Industry.png"),
       p2, width = 9, height = 6, dpi = 300)
cat("  Saved Figure 15.2: LMF by industry\n")

# --- Figure 3: Scatter — NLF vs PLF with LMF contours ---
scatter_data <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(nat_lang_fit), !is.na(prog_lang_fit)) %>%
  distinct(platform_ID, host_country_iso3c, .keep_all = TRUE)

if (nrow(scatter_data) > 10) {
  p3 <- ggplot(scatter_data, aes(x = nat_lang_fit, y = prog_lang_fit)) +
    geom_point(alpha = 0.3, size = 1.5, color = "grey30") +
    geom_smooth(method = "lm", se = TRUE, color = "black",
                linewidth = 0.8, linetype = "dashed") +
    labs(
      subtitle = "Natural Language Fit vs. Programming Language Fit (Dyad-Level)",
      x = "Natural Language Fit",
      y = "Programming Language Fit"
    ) +
    theme_apa

  ggsave(file.path(output_tables, "Figure_15_3_NLF_vs_PLF_Scatter.png"),
         p3, width = 7, height = 6, dpi = 300)
  cat("  Saved Figure 15.3: NLF vs PLF scatter\n")
}

# --- Figure 4: Heatmap — Mean Programming Language Fit by Country ---
heatmap_data <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(prog_lang_fit)) %>%
  group_by(host_country_iso3c) %>%
  summarize(
    M_PLF = mean(prog_lang_fit, na.rm = TRUE),
    N = n(),
    .groups = "drop"
  ) %>%
  filter(N >= 5) %>%
  arrange(desc(M_PLF))

if (nrow(heatmap_data) > 5) {
  heatmap_data$host_country_iso3c <- factor(
    heatmap_data$host_country_iso3c,
    levels = heatmap_data$host_country_iso3c
  )

  p4 <- ggplot(heatmap_data, aes(x = host_country_iso3c, y = M_PLF)) +
    geom_col(fill = "grey60", color = "black", width = 0.7, linewidth = 0.3) +
    labs(
      subtitle = "Mean Programming Language Fit by Host Country (PLAT Firms)",
      x = "Host Country",
      y = "Mean Programming Language Fit"
    ) +
    theme_apa +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8))

  ggsave(file.path(output_tables, "Figure_15_4_PLF_by_Country.png"),
         p4, width = 12, height = 6, dpi = 300)
  cat("  Saved Figure 15.4: PLF by host country\n")
}

cat("\n")

# ============================================================================
# SECTION 15: SEM — LANGUAGE-MARKET FIT AS ALTERNATIVE MEDIATOR
# ============================================================================
# Replaces platform_accessibility (LV + PLV breadth composite) with
# language-market fit (alignment-based) as the mediator.
# EF EPI is REMOVED from controls — it is baked into nat_lang_fit.
#
# Three test runs:
#   Test 1: Natural Language Fit only as mediator
#   Test 2: Programming Language Fit only as mediator
#   Test 3: Combined Language-Market Fit as mediator
#
# Each run: Phase 1 (composite PR) + Phase 2 (5 category Z-scores)
# Then comparison against script 11 Run A (original EA mediator)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SECTION 15: SEM — LANGUAGE-MARKET FIT MODELS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

library(lavaan)

# --- 15a: Prepare SEM dataset ---
# PLAT firms only, matching script 11 Run A
# Filter to dyads with cultural_distance available (see script 10)
df_sem <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(cultural_distance)) %>%
  mutate(across(c(platform_resources, platform_accessibility,
                   MKT_SHARE_CHANGE, cultural_distance,
                   Z_application, Z_development, Z_ai, Z_social, Z_governance,
                   IND_GROW,
                   host_gdp_per_capita, host_Internet_users,
                   home_gdp_per_capita,
                   nat_lang_fit, prog_lang_fit, language_market_fit),
                as.numeric))

# Standardize all SEM variables
df_sem <- df_sem %>%
  mutate(
    PR_z  = scale(platform_resources)[,1],
    DV_z  = scale(MKT_SHARE_CHANGE)[,1],
    CD_z  = scale(cultural_distance)[,1],

    # Original EA mediator (for comparison baseline)
    PA_z  = scale(platform_accessibility)[,1],

    # NEW: Language-market fit mediators
    NLF_z = scale(nat_lang_fit)[,1],
    PLF_z = scale(prog_lang_fit)[,1],
    LMF_z = scale(language_market_fit)[,1],

    # Category Z-scores
    Za_z  = scale(Z_application)[,1],
    Zd_z  = scale(Z_development)[,1],
    Zai_z = scale(Z_ai)[,1],
    Zs_z  = scale(Z_social)[,1],
    Zg_z  = scale(Z_governance)[,1],

    # Controls (NO EF EPI — it is integrated into NLF)
    IND_GROW_z  = scale(IND_GROW)[,1],
    host_GDP_z  = scale(log(host_gdp_per_capita + 1))[,1],
    host_INET_z = scale(host_Internet_users)[,1],
    home_GDP_z  = scale(log(home_gdp_per_capita + 1))[,1],

    # Interactions (for moderation by CD)
    PR_x_CD  = PR_z * CD_z,
    PA_x_CD  = PA_z * CD_z,
    NLF_x_CD = NLF_z * CD_z,
    PLF_x_CD = PLF_z * CD_z,
    LMF_x_CD = LMF_z * CD_z
  )

cat("SEM dataset:", nrow(df_sem), "PLAT dyads,",
    n_distinct(df_sem$platform_ID), "platforms\n")

# Check complete cases for each mediator
for (med in c("PA_z", "NLF_z", "PLF_z", "LMF_z")) {
  sem_core <- c("PR_z", med, "DV_z", "CD_z",
                 "IND_GROW_z", "host_GDP_z", "host_INET_z", "home_GDP_z")
  cc <- sum(complete.cases(df_sem[, sem_core]))
  cat(sprintf("  Complete cases with %s: %d\n", med, cc))
}
cat("\n")

# --- 15b: Generic Phase 1 and Phase 2 functions ---

run_lmf_phase1 <- function(df, med_var, med_int_var, label, n_boot = 2000) {

  cat(sprintf("\n--- PHASE 1 [%s]: Composite PR → %s → Performance ---\n",
              label, med_var))

  model <- sprintf('
    # a path: Platform Resources → Mediator
    %s ~ a*PR_z +
         a_cd*%s +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z + IND_GROW_z

    # b + c paths: → International Performance
    DV_z ~ b*%s +
            c*PR_z +
            b_cd*%s +
            CD_z +
            host_GDP_z + host_INET_z + IND_GROW_z

    # Defined parameters
    indirect := a * b
    total    := c + (a * b)
  ', med_var, med_int_var, med_var,
     # b_cd interaction: mediator × CD
     paste0(med_var, "_x_CD = ", med_var, " * CD_z\n    ",
            med_int_var))

  # Simpler approach: build model string with the right variable names
  model <- paste0('
    # a path: PR → Mediator
    ', med_var, ' ~ a*PR_z +
         a_cd*PR_x_CD +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z + IND_GROW_z

    # b + c paths: → Performance
    DV_z ~ b*', med_var, ' +
            c*PR_z +
            b_cd*', med_int_var, ' +
            CD_z +
            host_GDP_z + host_INET_z + IND_GROW_z

    # Defined parameters
    indirect := a * b
    total    := c + (a * b)
  ')

  # Check convergence
  fit_check <- tryCatch(
    sem(model, data = df, estimator = "ML"),
    error = function(e) { cat("  Error:", e$message, "\n"); NULL }
  )

  if (is.null(fit_check) || !lavInspect(fit_check, "converged")) {
    cat(sprintf("  ✗ Phase 1 [%s] did not converge.\n", label))
    n_used <- if (!is.null(fit_check)) lavInspect(fit_check, "nobs") else NA
    cat(sprintf("  lavaan used N = %s observations\n", n_used))
    return(list(fit = fit_check, params = NULL, converged = FALSE,
                fit_measures = NULL))
  }

  cat(sprintf("  ✓ Converges (N=%d). Running bootstrap (n=%d)...\n",
              lavInspect(fit_check, "nobs"), n_boot))
  fit <- sem(model, data = df, se = "bootstrap", bootstrap = n_boot,
             estimator = "ML")

  params <- parameterEstimates(fit, boot.ci.type = "perc",
                                standardized = TRUE)

  key_labels <- c("a", "b", "c", "indirect", "total", "a_cd", "b_cd")
  key_params <- params %>%
    filter(label %in% key_labels) %>%
    mutate(
      sig = case_when(
        pvalue < .001 ~ "***",
        pvalue < .01  ~ "**",
        pvalue < .05  ~ "*",
        pvalue < .10  ~ "+",
        TRUE          ~ "ns"
      )
    ) %>%
    select(label, est, se, pvalue, ci.lower, ci.upper, std.all, sig)

  cat("\n  Key Parameters:\n")
  print(as.data.frame(key_params))

  fit_vals <- fitMeasures(fit, c("chisq", "df", "pvalue",
                                  "cfi", "tli", "rmsea", "srmr",
                                  "aic", "bic"))
  cat("\n  Fit Indices:\n")
  print(fit_vals)

  return(list(fit = fit, params = key_params, converged = TRUE,
              fit_measures = fit_vals))
}

run_lmf_phase2 <- function(df, med_var, label, n_boot = 2000) {

  cat(sprintf("\n--- PHASE 2 [%s]: 5 BR Categories → %s → Performance ---\n",
              label, med_var))

  model <- paste0('
    # a paths: Each BR category → Mediator
    ', med_var, ' ~ a_app*Za_z + a_dev*Zd_z + a_ai*Zai_z +
                     a_soc*Zs_z + a_gov*Zg_z +
                     CD_z +
                     home_GDP_z + host_GDP_z + host_INET_z + IND_GROW_z

    # b + c paths: → Performance
    DV_z ~ b*', med_var, ' +
            c_app*Za_z + c_dev*Zd_z + c_ai*Zai_z +
            c_soc*Zs_z + c_gov*Zg_z +
            CD_z +
            host_GDP_z + host_INET_z + IND_GROW_z

    # Indirect effects per category
    ind_app := a_app * b
    ind_dev := a_dev * b
    ind_ai  := a_ai * b
    ind_soc := a_soc * b
    ind_gov := a_gov * b
  ')

  fit_check <- tryCatch(
    sem(model, data = df, estimator = "ML"),
    error = function(e) { cat("  Error:", e$message, "\n"); NULL }
  )

  if (is.null(fit_check) || !lavInspect(fit_check, "converged")) {
    cat(sprintf("  ✗ Phase 2 [%s] did not converge.\n", label))
    return(list(fit = fit_check, params = NULL, converged = FALSE,
                fit_measures = NULL))
  }

  cat(sprintf("  ✓ Converges (N=%d). Running bootstrap (n=%d)...\n",
              lavInspect(fit_check, "nobs"), n_boot))
  fit <- sem(model, data = df, se = "bootstrap", bootstrap = n_boot,
             estimator = "ML")

  params <- parameterEstimates(fit, boot.ci.type = "perc",
                                standardized = TRUE)

  cat_labels <- c("a_app", "a_dev", "a_ai", "a_soc", "a_gov",
                   "c_app", "c_dev", "c_ai", "c_soc", "c_gov",
                   "ind_app", "ind_dev", "ind_ai", "ind_soc", "ind_gov", "b")

  cat_params <- params %>%
    filter(label %in% cat_labels) %>%
    mutate(
      sig = case_when(
        pvalue < .001 ~ "***",
        pvalue < .01  ~ "**",
        pvalue < .05  ~ "*",
        pvalue < .10  ~ "+",
        TRUE          ~ "ns"
      )
    ) %>%
    select(label, est, se, pvalue, ci.lower, ci.upper, std.all, sig) %>%
    arrange(label)

  cat("\n  Category Effects:\n")
  print(as.data.frame(cat_params))

  fit_vals <- fitMeasures(fit, c("chisq", "df", "pvalue",
                                  "cfi", "tli", "rmsea", "srmr",
                                  "aic", "bic"))
  cat("\n  Fit Indices:\n")
  print(fit_vals)

  return(list(fit = fit, params = cat_params, converged = TRUE,
              fit_measures = fit_vals))
}

# --- 15c: TEST RUN 1 — Natural Language Fit as mediator ---
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST RUN 1: NATURAL LANGUAGE FIT AS MEDIATOR\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

t1_p1 <- run_lmf_phase1(df_sem, "NLF_z", "NLF_x_CD", "NLF", n_boot = 2000)
t1_p2 <- run_lmf_phase2(df_sem, "NLF_z", "NLF", n_boot = 2000)

# --- 15d: TEST RUN 2 — Programming Language Fit as mediator ---
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST RUN 2: PROGRAMMING LANGUAGE FIT AS MEDIATOR\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

t2_p1 <- run_lmf_phase1(df_sem, "PLF_z", "PLF_x_CD", "PLF", n_boot = 2000)
t2_p2 <- run_lmf_phase2(df_sem, "PLF_z", "PLF", n_boot = 2000)

# --- 15e: TEST RUN 3 — Combined Language-Market Fit as mediator ---
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST RUN 3: COMBINED LANGUAGE-MARKET FIT AS MEDIATOR\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

t3_p1 <- run_lmf_phase1(df_sem, "LMF_z", "LMF_x_CD", "LMF", n_boot = 2000)
t3_p2 <- run_lmf_phase2(df_sem, "LMF_z", "LMF", n_boot = 2000)

# --- 15f: BASELINE — Re-run original EA model for direct comparison ---
# (Same data subset, same controls minus EF EPI, for apples-to-apples)
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("BASELINE: ORIGINAL PLATFORM ACCESSIBILITY (Script 11 Run A equivalent)\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

t0_p1 <- run_lmf_phase1(df_sem, "PA_z", "PA_x_CD", "EA (baseline)", n_boot = 2000)

# ============================================================================
# SECTION 16: MODEL COMPARISON TABLE
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("MODEL COMPARISON: LMF vs ORIGINAL PLATFORM ACCESSIBILITY\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Build comparison from Phase 1 results
build_comparison_row <- function(result, model_name) {
  if (!isTRUE(result$converged)) {
    return(tibble(
      Model = model_name,
      a = NA, a_sig = "NC", b = NA, b_sig = "NC",
      c_direct = NA, c_sig = "NC",
      indirect = NA, ind_sig = "NC",
      CFI = NA, TLI = NA, RMSEA = NA, SRMR = NA,
      N = NA
    ))
  }

  p <- result$params
  fm <- result$fit_measures

  get_val <- function(lbl, col = "est") {
    row <- p[p$label == lbl, ]
    if (nrow(row) == 0) return(NA)
    row[[col]][1]
  }

  tibble(
    Model = model_name,
    a = round(get_val("a", "std.all"), 3),
    a_sig = get_val("a", "sig"),
    b = round(get_val("b", "std.all"), 3),
    b_sig = get_val("b", "sig"),
    c_direct = round(get_val("c", "std.all"), 3),
    c_sig = get_val("c", "sig"),
    indirect = round(get_val("indirect", "std.all"), 3),
    ind_sig = get_val("indirect", "sig"),
    chisq = round(as.numeric(fm["chisq"]), 2),
    df = as.integer(fm["df"]),
    chisq_p = round(as.numeric(fm["pvalue"]), 3),
    CFI = round(as.numeric(fm["cfi"]), 3),
    TLI = round(as.numeric(fm["tli"]), 3),
    RMSEA = round(as.numeric(fm["rmsea"]), 3),
    SRMR = round(as.numeric(fm["srmr"]), 3),
    AIC = round(as.numeric(fm["aic"]), 1),
    BIC = round(as.numeric(fm["bic"]), 1),
    N = lavInspect(result$fit, "nobs")
  )
}

comparison_table <- bind_rows(
  build_comparison_row(t0_p1, "Platform Accessibility (baseline)"),
  build_comparison_row(t1_p1, "Natural Language Fit"),
  build_comparison_row(t2_p1, "Programming Language Fit"),
  build_comparison_row(t3_p1, "Combined Language-Market Fit")
)

cat("Phase 1 Model Comparison (Standardized Coefficients):\n\n")
print(as.data.frame(comparison_table), width = 200)
cat("\n")

# Build Phase 2 comparison (b path = mediator → DV, aggregated)
build_p2_comparison <- function(result, model_name) {
  if (!isTRUE(result$converged)) {
    return(tibble(Model = model_name, b = NA, b_sig = "NC",
                  sig_a_paths = "NC", sig_c_paths = "NC",
                  sig_indirect = "NC"))
  }

  p <- result$params
  get_val <- function(lbl, col) {
    row <- p[p$label == lbl, ]
    if (nrow(row) == 0) return(NA)
    row[[col]][1]
  }

  # Count significant a-paths, c-paths, indirect effects
  a_labels <- c("a_app", "a_dev", "a_ai", "a_soc", "a_gov")
  c_labels <- c("c_app", "c_dev", "c_ai", "c_soc", "c_gov")
  ind_labels <- c("ind_app", "ind_dev", "ind_ai", "ind_soc", "ind_gov")

  sig_a <- sum(sapply(a_labels, function(l) {
    pv <- get_val(l, "pvalue")
    !is.na(pv) && pv < .05
  }))
  sig_c <- sum(sapply(c_labels, function(l) {
    pv <- get_val(l, "pvalue")
    !is.na(pv) && pv < .05
  }))
  sig_ind <- sum(sapply(ind_labels, function(l) {
    pv <- get_val(l, "pvalue")
    !is.na(pv) && pv < .05
  }))

  tibble(
    Model = model_name,
    b = round(get_val("b", "std.all"), 3),
    b_sig = get_val("b", "sig"),
    sig_a_paths = paste0(sig_a, "/5"),
    sig_c_paths = paste0(sig_c, "/5"),
    sig_indirect = paste0(sig_ind, "/5")
  )
}

p2_comparison <- bind_rows(
  build_p2_comparison(t1_p2, "Natural Language Fit"),
  build_p2_comparison(t2_p2, "Programming Language Fit"),
  build_p2_comparison(t3_p2, "Combined Language-Market Fit")
)

cat("Phase 2 Model Comparison:\n\n")
print(as.data.frame(p2_comparison), width = 200)
cat("\n")

# ============================================================================
# SECTION 17: EXPORT SEM COMPARISON TABLES TO WORD
# ============================================================================

cat("=== EXPORTING SEM COMPARISON TABLES ===\n\n")

# --- Comparison Table 1: Phase 1 across all models ---
ft_comp1 <- comparison_table %>%
  mutate(
    `a (β)` = ifelse(is.na(a), "NC", paste0(sprintf("%.3f", a), " ", a_sig)),
    `b (β)` = ifelse(is.na(b), "NC", paste0(sprintf("%.3f", b), " ", b_sig)),
    `c (β)` = ifelse(is.na(c_direct), "NC",
                      paste0(sprintf("%.3f", c_direct), " ", c_sig)),
    `Indirect (β)` = ifelse(is.na(indirect), "NC",
                             paste0(sprintf("%.3f", indirect), " ", ind_sig)),
    `χ²` = ifelse(is.na(chisq), "NC", sprintf("%.2f", chisq)),
    df = ifelse(is.na(df), "NC", as.character(df)),
    `χ² p` = ifelse(is.na(chisq_p), "NC",
                     ifelse(chisq_p < .001, "< .001", sprintf("%.3f", chisq_p))),
    CFI = ifelse(is.na(CFI), "NC", sprintf("%.3f", CFI)),
    TLI = ifelse(is.na(TLI), "NC", sprintf("%.3f", TLI)),
    RMSEA = ifelse(is.na(RMSEA), "NC", sprintf("%.3f", RMSEA)),
    SRMR = ifelse(is.na(SRMR), "NC", sprintf("%.3f", SRMR)),
    AIC = ifelse(is.na(AIC), "NC", sprintf("%.1f", AIC)),
    BIC = ifelse(is.na(BIC), "NC", sprintf("%.1f", BIC)),
    N = ifelse(is.na(N), "NC", as.character(N))
  ) %>%
  select(Model, `a (β)`, `b (β)`, `c (β)`, `Indirect (β)`,
         `χ²`, df, `χ² p`, CFI, TLI, RMSEA, SRMR, AIC, BIC, N) %>%
  flextable() %>%
  apa_style("Phase 1 Model Comparison")

# --- Comparison Table 2: Phase 2 summary ---
ft_comp2 <- p2_comparison %>%
  mutate(
    `b (β)` = ifelse(is.na(b), "NC", paste0(sprintf("%.3f", b), " ", b_sig))
  ) %>%
  select(Model, `b (β)`, `Sig a-paths` = sig_a_paths,
         `Sig c-paths` = sig_c_paths,
         `Sig indirect` = sig_indirect) %>%
  flextable() %>%
  apa_style("Phase 2 Model Comparison")

# --- Individual test run tables (Phase 1 key parameters) ---
make_key_param_table <- function(result, title) {
  if (!isTRUE(result$converged)) return(NULL)

  hypothesis_names <- c(
    a = "PR → Mediator (a path)",
    b = "Mediator → Performance (b path)",
    c = "H1: Direct effect (c path)",
    indirect = "H2: Indirect/Mediation (a × b)",
    total = "Total effect (c + a × b)",
    a_cd = "H3a: CD moderates a path",
    b_cd = "H3B: CD moderates b path"
  )

  result$params %>%
    mutate(
      Hypothesis = hypothesis_names[label],
      B = sprintf("%.3f", est),
      SE = sprintf("%.3f", se),
      p = ifelse(pvalue < .001, "< .001", sprintf("%.3f", pvalue)),
      `95% CI` = sprintf("[%.3f, %.3f]", ci.lower, ci.upper),
      `β` = sprintf("%.3f", std.all),
      Sig = sig
    ) %>%
    select(Label = label, Hypothesis, B, SE, p, `95% CI`, `β`, Sig) %>%
    flextable() %>%
    apa_style(title)
}

ft_t1 <- make_key_param_table(t1_p1, "Test 1: Natural Language Fit — Phase 1")
ft_t2 <- make_key_param_table(t2_p1, "Test 2: Programming Language Fit — Phase 1")
ft_t3 <- make_key_param_table(t3_p1, "Test 3: Combined LMF — Phase 1")

# Add SEM tables to the existing Word document
# Re-open the doc we already saved
doc2 <- read_docx(doc_path)

doc2 <- doc2 %>%
  body_add_break() %>%
  body_add_par("Table 15.7", style = "Normal") %>%
  body_add_par("Phase 1 Model Comparison: Language-Market Fit vs. Platform Accessibility",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_comp1) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. All models use PLAT firms only with bootstrap SEs (2,000 replications). ",
    "Baseline = Platform Accessibility (LINGUISTIC_VARIETY + programming_lang_variety, ",
    "z-scored). EF EPI is excluded from controls in all models (integrated into NLF). ",
    "NC = model did not converge. ",
    "*** p < .001, ** p < .01, * p < .05, + p < .10."
  ), style = "Normal") %>%
  body_add_break()

doc2 <- doc2 %>%
  body_add_par("Table 15.8", style = "Normal") %>%
  body_add_par("Phase 2 Model Comparison: Significant Category Effects by Mediator",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_comp2) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Sig a-paths = number of 5 BR categories significantly predicting the ",
    "mediator (p < .05). Sig c-paths = significant direct effects on performance. ",
    "Sig indirect = significant mediated effects through the mediator."
  ), style = "Normal") %>%
  body_add_break()

# ============================================================================
# TABLE 15.8b: EFFECT ABSORPTION — CD VARIANCE ACROSS ALL PATHS BY MODEL
# ============================================================================

cat("\n=== EFFECT ABSORPTION TABLE ===\n\n")

# Extract all path coefficients including unlabeled CD direct effects
build_absorption_row <- function(result, model_name) {
  if (!isTRUE(result$converged)) {
    return(tibble(
      Model = model_name, N = NA,
      a_beta = NA, a_sig = "NC",
      a_cd_beta = NA, a_cd_sig = "NC",
      b_beta = NA, b_sig = "NC",
      b_cd_beta = NA, b_cd_sig = "NC",
      c_beta = NA, c_sig = "NC",
      cd_on_med_beta = NA, cd_on_med_sig = "NC",
      cd_on_dv_beta = NA, cd_on_dv_sig = "NC",
      indirect_beta = NA, indirect_sig = "NC",
      total_beta = NA, total_sig = "NC"
    ))
  }

  # Get labeled params
  p <- result$params
  get_lab <- function(lbl, col = "std.all") {
    row <- p[p$label == lbl, ]
    if (nrow(row) == 0) return(NA)
    row[[col]][1]
  }
  get_sig <- function(lbl) {
    row <- p[p$label == lbl, ]
    if (nrow(row) == 0) return("NC")
    row[["sig"]][1]
  }

  # Get unlabeled CD_z direct effects from full parameter table
  all_params <- parameterEstimates(result$fit, boot.ci.type = "perc",
                                    standardized = TRUE)

  # CD_z in the mediator equation (a-path equation)
  cd_on_med <- all_params %>%
    filter(op == "~", rhs == "CD_z", lhs != "DV_z") %>%
    filter(label == "" | is.na(label) | label == "CD_z")
  cd_on_med_beta <- if (nrow(cd_on_med) > 0) round(cd_on_med$std.all[1], 3) else NA
  cd_on_med_p    <- if (nrow(cd_on_med) > 0) cd_on_med$pvalue[1] else NA
  cd_on_med_sig  <- if (is.na(cd_on_med_p)) "NC" else
    ifelse(cd_on_med_p < .001, "***",
    ifelse(cd_on_med_p < .01, "**",
    ifelse(cd_on_med_p < .05, "*",
    ifelse(cd_on_med_p < .10, "\u2020", "ns"))))

  # CD_z in the DV equation (b/c-path equation)
  cd_on_dv <- all_params %>%
    filter(op == "~", rhs == "CD_z", lhs == "DV_z") %>%
    filter(label == "" | is.na(label) | label == "CD_z")
  cd_on_dv_beta <- if (nrow(cd_on_dv) > 0) round(cd_on_dv$std.all[1], 3) else NA
  cd_on_dv_p    <- if (nrow(cd_on_dv) > 0) cd_on_dv$pvalue[1] else NA
  cd_on_dv_sig  <- if (is.na(cd_on_dv_p)) "NC" else
    ifelse(cd_on_dv_p < .001, "***",
    ifelse(cd_on_dv_p < .01, "**",
    ifelse(cd_on_dv_p < .05, "*",
    ifelse(cd_on_dv_p < .10, "\u2020", "ns"))))

  tibble(
    Model = model_name,
    N = lavInspect(result$fit, "nobs"),
    a_beta = round(get_lab("a"), 3),
    a_sig = get_sig("a"),
    a_cd_beta = round(get_lab("a_cd"), 3),
    a_cd_sig = get_sig("a_cd"),
    b_beta = round(get_lab("b"), 3),
    b_sig = get_sig("b"),
    b_cd_beta = round(get_lab("b_cd"), 3),
    b_cd_sig = get_sig("b_cd"),
    c_beta = round(get_lab("c"), 3),
    c_sig = get_sig("c"),
    cd_on_med_beta = cd_on_med_beta,
    cd_on_med_sig = cd_on_med_sig,
    cd_on_dv_beta = cd_on_dv_beta,
    cd_on_dv_sig = cd_on_dv_sig,
    indirect_beta = round(get_lab("indirect"), 3),
    indirect_sig = get_sig("indirect"),
    total_beta = round(get_lab("total"), 3),
    total_sig = get_sig("total")
  )
}

absorption_tbl <- bind_rows(
  build_absorption_row(t0_p1, "PA (baseline)"),
  build_absorption_row(t1_p1, "NLF"),
  build_absorption_row(t2_p1, "PLF"),
  build_absorption_row(t3_p1, "LMF")
)

cat("Effect Absorption Across Paths by Model:\n\n")
print(as.data.frame(absorption_tbl), width = 200)
cat("\n")

# Format for Word export
fmt_coef <- function(beta, sig) {
  ifelse(is.na(beta), "NC", paste0(sprintf("%.3f", beta), " ", sig))
}

absorption_word <- absorption_tbl %>%
  mutate(
    `a: PR→MED`         = fmt_coef(a_beta, a_sig),
    `CD×PR→MED`    = fmt_coef(a_cd_beta, a_cd_sig),
    `CD→MED`            = fmt_coef(cd_on_med_beta, cd_on_med_sig),
    `b: MED→DV`         = fmt_coef(b_beta, b_sig),
    `CD×MED→DV`    = fmt_coef(b_cd_beta, b_cd_sig),
    `CD→DV`             = fmt_coef(cd_on_dv_beta, cd_on_dv_sig),
    `c: PR→DV`          = fmt_coef(c_beta, c_sig),
    `Indirect (a×b)`    = fmt_coef(indirect_beta, indirect_sig),
    `Total`                   = fmt_coef(total_beta, total_sig),
    N = as.character(N)
  ) %>%
  select(Model, N,
         `a: PR→MED`, `CD×PR→MED`, `CD→MED`,
         `b: MED→DV`, `CD×MED→DV`, `CD→DV`,
         `c: PR→DV`,
         `Indirect (a×b)`, `Total`)

ft_absorption <- flextable(absorption_word) %>%
  fontsize(size = 8, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  bold(part = "header") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:ncol(absorption_word), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  # Add vertical separators between path groups
  vline(j = c(2, 5, 8, 9), border = fp_border(width = 0.5, color = "gray70"))

# Insert into Word doc before the individual test tables
doc2 <- doc2 %>%
  body_add_par("Table 15.8b", style = "Normal") %>%
  body_add_par("Effect Absorption: CD Variance Distribution Across Paths by Mediator Model",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_absorption) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Standardized coefficients (\u03B2) from Phase 1 SEM with bootstrap SEs ",
    "(2,000 replications). Each row shows a different mediator model. ",
    "a-path group: PR effect on mediator, CD moderation of PR\u2192MED, and CD direct ",
    "effect on mediator. b-path group: mediator effect on DV, CD moderation of ",
    "MED\u2192DV, and CD direct effect on DV. c-path: direct PR\u2192DV effect. ",
    "When the mediator carries meaningful signal (PA, NLF, LMF), CD variance is ",
    "distributed across mediated paths. When the mediator is null (PLF), CD variance ",
    "concentrates in the direct CD\u2192DV path, potentially altering its sign. ",
    "Sample sizes differ due to language data availability: PA uses the full PLAT sample, ",
    "while NLF, PLF, and LMF require EF EPI and/or programming language data. ",
    "NC = model did not converge. ",
    "\u2020 p < .10. * p < .05. ** p < .01. *** p < .001."
  ), style = "Normal") %>%
  body_add_break()

# Add individual test run tables
if (!is.null(ft_t1)) {
  doc2 <- doc2 %>%
    body_add_par("Table 15.9", style = "Normal") %>%
    body_add_par("Test Run 1: Natural Language Fit as Mediator — Phase 1 Results",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_t1) %>%
    body_add_break()
}

if (!is.null(ft_t2)) {
  doc2 <- doc2 %>%
    body_add_par("Table 15.10", style = "Normal") %>%
    body_add_par("Test Run 2: Programming Language Fit as Mediator — Phase 1 Results",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_t2) %>%
    body_add_break()
}

if (!is.null(ft_t3)) {
  doc2 <- doc2 %>%
    body_add_par("Table 15.11", style = "Normal") %>%
    body_add_par("Test Run 3: Combined Language-Market Fit — Phase 1 Results",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_t3) %>%
    body_add_break()
}

# Save updated Word document
print(doc2, target = doc_path)
cat("  Updated APA tables with SEM results:", doc_path, "\n\n")

# Save comparison CSV for reference
write.csv(comparison_table,
          file.path(base_path, "dissertation analysis",
                    "15_LMF_model_comparison.csv"),
          row.names = FALSE)
cat("  Saved comparison CSV: 15_LMF_model_comparison.csv\n\n")

# ============================================================================
# SECTION 19: SEM PATH DIAGRAMS — EFFECT SIZE VISUALIZATION
# ============================================================================
# Creates publication-quality path diagrams showing:
#   (A) Baseline EA model (Phase 1)
#   (B) PLF model — the only significant alternative mediator (Phase 1)
#   (C) Side-by-side Phase 2 comparison (5-category a-paths)
#   (D) Indirect effects comparison across all 4 models
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("SECTION 19: SEM PATH DIAGRAMS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

library(ggplot2)
library(grid)

# --- Helper: Draw a mediation path diagram with CD moderation ---
# Includes 4 nodes: PR, Mediator, DV, and Cultural Distance
# Shows: a path, b path, c' path, a_cd moderation, b_cd moderation, indirect
draw_path_diagram <- function(a_est, a_sig, b_est, b_sig, c_est, c_sig,
                               indirect_est, indirect_sig,
                               a_cd_est = NA, a_cd_sig = "ns",
                               b_cd_est = NA, b_cd_sig = "ns",
                               mediator_label = "Mediator",
                               title = "Path Diagram",
                               subtitle = NULL,
                               note = NULL) {

  # Diamond/kite layout matching script 11:
  #   CD at top (2, 6), Mediator upper-center (2, 4),
  #   PR at left (0, 2), DV at right (4, 2)
  x_iv  <- 0;  y_iv  <- 2    # PR (left)
  x_med <- 2;  y_med <- 4    # Mediator (upper center)
  x_dv  <- 4;  y_dv  <- 2    # DV (right)
  x_cd  <- 2;  y_cd  <- 6    # CD (top — ABOVE mediator)

  # Format coefficient labels
  fmt <- function(est, sig) {
    if (is.na(est)) return("--")
    sig_str <- switch(as.character(sig),
      "***" = "***", "**" = "**", "*" = "*",
      "+"   = "\u2020", "ns" = "", "")
    sprintf("%.3f%s", est, sig_str)
  }

  is_sig_check <- function(sig) sig %in% c("***", "**", "*")

  # Node colors matching script 11
  node_colors <- c(main = "#1f77b4", mediator = "#2ca02c",
                   outcome = "#d62728", moderator = "#7f7f7f")

  # --- Nodes ---
  nodes <- data.frame(
    x = c(x_iv, x_med, x_dv, x_cd),
    y = c(y_iv, y_med, y_dv, y_cd),
    label = c("Platform\nResources (PR)",
              mediator_label,
              "International\nPerformance (DV)",
              "Cultural\nDistance (CD)"),
    node_type = c("main", "mediator", "outcome", "moderator"),
    fill_color = c(node_colors["main"], node_colors["mediator"],
                   node_colors["outcome"], node_colors["moderator"]),
    stringsAsFactors = FALSE
  )

  # --- Main structural arrows (a, b, c') ---
  # Arrow offsets to avoid overlapping node labels
  main_arrows <- data.frame(
    x_start = c(x_iv + 0.55, x_med + 0.55, x_iv + 0.55),
    y_start = c(y_iv + 0.40, y_med - 0.40, y_iv - 0.15),
    x_end   = c(x_med - 0.55, x_dv - 0.55, x_dv - 0.55),
    y_end   = c(y_med - 0.40, y_dv + 0.40, y_dv - 0.15),
    coef    = c(fmt(a_est, a_sig), fmt(b_est, b_sig), fmt(c_est, c_sig)),
    path    = c("a", "b", "c'"),
    is_sig  = c(is_sig_check(a_sig), is_sig_check(b_sig), is_sig_check(c_sig)),
    stringsAsFactors = FALSE
  )

  # Label positions for main arrows
  main_arrows$label_x <- c((x_iv + x_med)/2 - 0.45,
                            (x_med + x_dv)/2 + 0.45,
                            (x_iv + x_dv)/2)
  main_arrows$label_y <- c((y_iv + y_med)/2 + 0.35,
                            (y_med + y_dv)/2 + 0.35,
                            y_iv - 0.65)

  # --- CD moderation arrows (dashed, from CD down to a-path and b-path midpoints) ---
  has_a_cd <- !is.na(a_cd_est)
  has_b_cd <- !is.na(b_cd_est)

  cd_arrows <- data.frame(
    x_start  = numeric(0), y_start  = numeric(0),
    x_end    = numeric(0), y_end    = numeric(0),
    coef     = character(0), path = character(0),
    is_sig   = logical(0),
    label_x  = numeric(0), label_y  = numeric(0),
    stringsAsFactors = FALSE
  )

  if (has_a_cd) {
    # CD → midpoint of a-path (PR→Med), midpoint at (1, 3)
    cd_arrows <- rbind(cd_arrows, data.frame(
      x_start = x_cd - 0.30, y_start = y_cd - 0.35,
      x_end   = 1.0, y_end   = 3.15,
      coef    = fmt(a_cd_est, a_cd_sig),
      path    = "H3a: CD x a",
      is_sig  = is_sig_check(a_cd_sig),
      label_x = 0.15, label_y = 5.0,
      stringsAsFactors = FALSE
    ))
  }

  if (has_b_cd) {
    # CD → midpoint of b-path (Med→DV), midpoint at (3, 3)
    cd_arrows <- rbind(cd_arrows, data.frame(
      x_start = x_cd + 0.30, y_start = y_cd - 0.35,
      x_end   = 3.0, y_end   = 3.15,
      coef    = fmt(b_cd_est, b_cd_sig),
      path    = "H3b: CD x b",
      is_sig  = is_sig_check(b_cd_sig),
      label_x = 3.85, label_y = 5.0,
      stringsAsFactors = FALSE
    ))
  }

  # --- Build plot ---
  # Arrow styling
  main_colors <- ifelse(main_arrows$is_sig, "black", "grey50")
  main_widths <- ifelse(main_arrows$is_sig, 1.2, 0.7)
  main_lt     <- ifelse(main_arrows$is_sig, "solid", "dashed")

  p <- ggplot() +
    # Main structural arrows
    geom_segment(data = main_arrows,
                 aes(x = x_start, y = y_start, xend = x_end, yend = y_end),
                 linewidth = main_widths, color = main_colors,
                 linetype = main_lt,
                 arrow = arrow(length = unit(0.025, "npc"), type = "closed"),
                 show.legend = FALSE)

  # CD moderation arrows (if any)
  if (nrow(cd_arrows) > 0) {
    cd_colors <- ifelse(cd_arrows$is_sig, "#B71C1C", "grey50")
    cd_widths <- ifelse(cd_arrows$is_sig, 0.9, 0.5)

    p <- p +
      geom_segment(data = cd_arrows,
                   aes(x = x_start, y = y_start, xend = x_end, yend = y_end),
                   linewidth = cd_widths, color = cd_colors,
                   linetype = "dotted",
                   arrow = arrow(length = unit(0.015, "npc"), type = "open"),
                   show.legend = FALSE) +
      # CD moderation labels
      geom_label(data = cd_arrows,
                 aes(x = label_x, y = label_y,
                     label = paste0(path, " = ", coef)),
                 fill = ifelse(cd_arrows$is_sig, "#FFCDD2", "#F5F5F5"),
                 color = ifelse(cd_arrows$is_sig, "#B71C1C", "grey40"),
                 size = 2.8, fontface = "italic", family = "Times New Roman",
                 label.padding = unit(0.25, "lines"))
  }

  p <- p +
    # Node boxes — colored fills with white text (matching script 11)
    geom_label(data = nodes,
               aes(x = x, y = y, label = label),
               fill = nodes$fill_color, color = "white",
               size = 3.5, fontface = "bold", family = "Times New Roman",
               label.padding = unit(0.4, "lines"),
               label.r = unit(0.15, "lines")) +
    # Main path coefficient labels
    geom_label(data = main_arrows,
               aes(x = label_x, y = label_y,
                   label = paste0(path, " = ", coef)),
               fill = ifelse(main_arrows$is_sig, "#D4E8D4", "#EDEDED"),
               color = ifelse(main_arrows$is_sig, "black", "grey30"),
               size = 3.2, fontface = "italic", family = "Times New Roman",
               label.padding = unit(0.3, "lines")) +
    # Indirect effect annotation
    annotate("label",
             x = 2.0, y = 0.5,
             label = paste0("Indirect (a x b) = ",
                            fmt(indirect_est, indirect_sig)),
             fill = ifelse(is_sig_check(indirect_sig), "#C8E6C9", "#E0E0E0"),
             color = "black", size = 3.5, fontface = "bold", family = "Times New Roman",
             label.padding = unit(0.4, "lines")) +
    # Significance legend
    annotate("text", x = 4.5, y = 0.5,
             label = "* p<.05  ** p<.01  *** p<.001",
             size = 2.5, color = "grey40", hjust = 1, family = "Times New Roman") +
    # Formatting — explicit white background, diamond/kite aspect
    coord_cartesian(xlim = c(-0.8, 4.8), ylim = c(0.0, 7.2)) +
    labs(title = title, subtitle = subtitle) +
    theme_void(base_family = "Times New Roman") +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      plot.title = element_text(face = "bold.italic", size = 13, hjust = 0.5),
      plot.subtitle = element_text(size = 10, hjust = 0.5, color = "grey30"),
      plot.margin = margin(15, 15, 15, 15)
    )

  if (!is.null(note)) {
    p <- p + labs(caption = note) +
      theme(plot.caption = element_text(size = 8, hjust = 0, color = "grey40"))
  }

  return(p)
}

# --- Helper: extract Phase 1 coefficients (including CD interactions) ---
get_p1_coefs <- function(result) {
  if (!isTRUE(result$converged)) return(NULL)
  p <- result$params
  get_v <- function(lbl, col = "std.all") {
    row <- p[p$label == lbl, ]
    if (nrow(row) == 0) return(NA)
    row[[col]][1]
  }
  list(
    a = get_v("a"),       a_sig = get_v("a", "sig"),
    b = get_v("b"),       b_sig = get_v("b", "sig"),
    c = get_v("c"),       c_sig = get_v("c", "sig"),
    indirect = get_v("indirect"), ind_sig = get_v("indirect", "sig"),
    a_cd = get_v("a_cd"), a_cd_sig = get_v("a_cd", "sig"),
    b_cd = get_v("b_cd"), b_cd_sig = get_v("b_cd", "sig")
  )
}

# --- Figure 19.1: Baseline EA Model Path Diagram ---
cat("--- Figure 19.1: Baseline EA Model ---\n")

ea_coefs <- get_p1_coefs(t0_p1)
if (!is.null(ea_coefs)) {
  p_ea <- draw_path_diagram(
    a_est = ea_coefs$a, a_sig = ea_coefs$a_sig,
    b_est = ea_coefs$b, b_sig = ea_coefs$b_sig,
    c_est = ea_coefs$c, c_sig = ea_coefs$c_sig,
    indirect_est = ea_coefs$indirect, indirect_sig = ea_coefs$ind_sig,
    a_cd_est = ea_coefs$a_cd, a_cd_sig = ea_coefs$a_cd_sig,
    b_cd_est = ea_coefs$b_cd, b_cd_sig = ea_coefs$b_cd_sig,
    mediator_label = "Platform\nAccessibility (PA)",
    subtitle = "Platform Accessibility as Mediator (Standardized Coefficients)",
    note = "Note. Bootstrap SE (2,000 replications). Yellow = moderator. Dotted = moderation path.\n*** p < .001, ** p < .01, * p < .05"
  )

  ggsave(file.path(output_tables, "Figure_15_5a_PA_Path_Diagram.png"),
         p_ea, width = 8, height = 5.5, dpi = 300, bg = "white")
  cat("  Saved: Figure_15_5a_PA_Path_Diagram.png\n")
}

# --- Figure 19.2: PLF Model Path Diagram ---
cat("--- Figure 19.2: Programming Language Fit Model ---\n")

plf_coefs <- get_p1_coefs(t2_p1)
if (!is.null(plf_coefs)) {
  p_plf <- draw_path_diagram(
    a_est = plf_coefs$a, a_sig = plf_coefs$a_sig,
    b_est = plf_coefs$b, b_sig = plf_coefs$b_sig,
    c_est = plf_coefs$c, c_sig = plf_coefs$c_sig,
    indirect_est = plf_coefs$indirect, indirect_sig = plf_coefs$ind_sig,
    a_cd_est = plf_coefs$a_cd, a_cd_sig = plf_coefs$a_cd_sig,
    b_cd_est = plf_coefs$b_cd, b_cd_sig = plf_coefs$b_cd_sig,
    mediator_label = "Programming\nLanguage Fit (PLF)",
    subtitle = "Programming Language Fit as Mediator (Standardized Coefficients)",
    note = "Note. Bootstrap SE (2,000 replications). Yellow = moderator. Dotted = moderation path.\n*** p < .001, ** p < .01, * p < .05"
  )

  ggsave(file.path(output_tables, "Figure_15_5b_PLF_Path_Diagram.png"),
         p_plf, width = 8, height = 5.5, dpi = 300, bg = "white")
  cat("  Saved: Figure_15_5b_PLF_Path_Diagram.png\n")
}

# --- Figure 19.3: NLF Model Path Diagram ---
cat("--- Figure 19.3: Natural Language Fit Model ---\n")

nlf_coefs <- get_p1_coefs(t1_p1)
if (!is.null(nlf_coefs)) {
  p_nlf <- draw_path_diagram(
    a_est = nlf_coefs$a, a_sig = nlf_coefs$a_sig,
    b_est = nlf_coefs$b, b_sig = nlf_coefs$b_sig,
    c_est = nlf_coefs$c, c_sig = nlf_coefs$c_sig,
    indirect_est = nlf_coefs$indirect, indirect_sig = nlf_coefs$ind_sig,
    a_cd_est = nlf_coefs$a_cd, a_cd_sig = nlf_coefs$a_cd_sig,
    b_cd_est = nlf_coefs$b_cd, b_cd_sig = nlf_coefs$b_cd_sig,
    mediator_label = "Natural\nLanguage Fit (NLF)",
    subtitle = "Natural Language Fit as Mediator (Standardized Coefficients)",
    note = "Note. Bootstrap SE (2,000 replications). Yellow = moderator. Dotted = moderation path.\n*** p < .001, ** p < .01, * p < .05"
  )

  ggsave(file.path(output_tables, "Figure_15_5c_NLF_Path_Diagram.png"),
         p_nlf, width = 8, height = 5.5, dpi = 300, bg = "white")
  cat("  Saved: Figure_15_5c_NLF_Path_Diagram.png\n")
}

# --- Figure 19.4: Combined LMF Model Path Diagram ---
cat("--- Figure 19.4: Combined LMF Model ---\n")

lmf_coefs <- get_p1_coefs(t3_p1)
if (!is.null(lmf_coefs)) {
  p_lmf <- draw_path_diagram(
    a_est = lmf_coefs$a, a_sig = lmf_coefs$a_sig,
    b_est = lmf_coefs$b, b_sig = lmf_coefs$b_sig,
    c_est = lmf_coefs$c, c_sig = lmf_coefs$c_sig,
    indirect_est = lmf_coefs$indirect, indirect_sig = lmf_coefs$ind_sig,
    a_cd_est = lmf_coefs$a_cd, a_cd_sig = lmf_coefs$a_cd_sig,
    b_cd_est = lmf_coefs$b_cd, b_cd_sig = lmf_coefs$b_cd_sig,
    mediator_label = "Language-Market\nFit (Combined)",
    subtitle = "Combined LMF as Mediator (Standardized Coefficients)",
    note = "Note. Bootstrap SE (2,000 replications). Yellow = moderator. Dotted = moderation path.\n*** p < .001, ** p < .01, * p < .05"
  )

  ggsave(file.path(output_tables, "Figure_15_5d_LMF_Path_Diagram.png"),
         p_lmf, width = 8, height = 5.5, dpi = 300, bg = "white")
  cat("  Saved: Figure_15_5d_LMF_Path_Diagram.png\n")
}

# --- Figure 19.5: Phase 1 Coefficient Comparison (bar chart) ---
cat("\n--- Figure 19.5: Phase 1 Coefficient Comparison ---\n")

# Build comparison data from Phase 1 results (include significance columns)
comp_data <- comparison_table %>%
  filter(!is.na(a)) %>%
  select(Model, a, a_sig, b, b_sig, c_direct, c_sig, indirect, ind_sig) %>%
  # Pivot beta values
  pivot_longer(cols = c(a, b, c_direct, indirect),
               names_to = "Path", values_to = "Beta") %>%
  # Pivot corresponding significance markers
  mutate(
    Sig = case_when(
      Path == "a"        ~ a_sig,
      Path == "b"        ~ b_sig,
      Path == "c_direct" ~ c_sig,
      Path == "indirect" ~ ind_sig
    ),
    is_sig = Sig %in% c("*", "**", "***"),
    Path = case_when(
      Path == "a"        ~ "a: PR \u2192 Mediator",
      Path == "b"        ~ "b: Mediator \u2192 DV",
      Path == "c_direct" ~ "c': Direct (PR \u2192 DV)",
      Path == "indirect" ~ "Indirect (a \u00d7 b)"
    ),
    Path = factor(Path, levels = c("a: PR \u2192 Mediator",
                                    "b: Mediator \u2192 DV",
                                    "c': Direct (PR \u2192 DV)",
                                    "Indirect (a \u00d7 b)")),
    Model = gsub(" \\(baseline\\)", "\n(baseline)", Model),
    Model = factor(Model),
    # Clean up sig marker: replace NA or "ns" with ""
    Sig_clean = ifelse(is.na(Sig) | Sig == "ns" | Sig == "", "", Sig),
    bar_label = paste0(sprintf("%.3f", Beta), Sig_clean)
  ) %>%
  select(Model, Path, Beta, Sig, Sig_clean, is_sig, bar_label)

p5 <- ggplot(comp_data, aes(x = Model, y = Beta, fill = Model)) +
  geom_col(width = 0.7, color = "black", linewidth = 0.3) +
  geom_hline(yintercept = 0, linewidth = 0.5) +
  # Add coefficient labels with significance stars on each bar
  geom_text(aes(label = bar_label,
                y = Beta + sign(Beta) * max(abs(Beta)) * 0.06),
            size = 2.8, family = "Times New Roman",
            position = position_identity()) +
  facet_wrap(~Path, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = c("grey70", "#A8D8EA", "#4A90D9", "#B8D4A8")) +
  labs(
    subtitle = "Phase 1 Standardized Path Coefficients by Mediator",
    x = NULL, y = "Standardized Coefficient (\u03b2)",
    caption = "Note. Standardized coefficients (\u03b2) from SEM with bootstrap SE (2,000 replications). N = 6,613 dyads.\n* p < .05. ** p < .01. *** p < .001."
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 30, hjust = 1, size = 8),
    legend.position = "none",
    strip.text = element_text(face = "bold", size = 10),
    panel.grid.major.x = element_blank(),
    plot.title = element_text(face = "bold.italic", size = 13),
    plot.subtitle = element_text(size = 10),
    plot.caption = element_text(size = 8, hjust = 0, color = "grey40")
  )

ggsave(file.path(output_tables, "Figure_15_6_Phase1_Comparison.png"),
       p5, width = 10, height = 7, dpi = 300)
cat("  Saved: Figure_15_6_Phase1_Comparison.png\n")

# --- Figure 19.6: Phase 2 — a-paths by category for PLF vs NLF ---
cat("\n--- Figure 19.6: Phase 2 Category a-path Comparison ---\n")

# Extract a-paths from Phase 2 results
extract_a_paths <- function(result, model_name) {
  if (!isTRUE(result$converged)) return(NULL)
  result$params %>%
    filter(grepl("^a_", label)) %>%
    mutate(
      Category = case_when(
        label == "a_app" ~ "Application",
        label == "a_dev" ~ "Development",
        label == "a_ai"  ~ "AI",
        label == "a_soc" ~ "Social",
        label == "a_gov" ~ "Governance"
      ),
      Model = model_name,
      is_sig = pvalue < .05
    ) %>%
    select(Model, Category, Beta = std.all, is_sig, sig)
}

p2_a_data <- bind_rows(
  extract_a_paths(t1_p2, "NLF"),
  extract_a_paths(t2_p2, "PLF"),
  extract_a_paths(t3_p2, "Combined LMF")
) %>%
  filter(!is.null(Category))

if (nrow(p2_a_data) > 0) {
  p2_a_data$Category <- factor(p2_a_data$Category,
    levels = c("Application", "Development", "AI", "Social", "Governance"))

  # Build bar label: coefficient value + significance stars
  p2_a_data <- p2_a_data %>%
    mutate(
      sig_clean = ifelse(is.na(sig) | sig == "ns" | sig == "", "", sig),
      bar_label = paste0(sprintf("%.3f", Beta), sig_clean)
    )

  p6 <- ggplot(p2_a_data, aes(x = Category, y = Beta, fill = Model)) +
    geom_col(position = position_dodge(0.8), width = 0.7,
             color = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0, linewidth = 0.5) +
    # Add coefficient labels with significance stars
    geom_text(aes(label = ifelse(is_sig, bar_label, ""),
                  y = Beta + sign(Beta) * 0.02),
              position = position_dodge(0.8), size = 2.8, vjust = 0,
              family = "Times New Roman") +
    scale_fill_manual(values = c("NLF" = "#A8D8EA",
                                  "PLF" = "#4A90D9",
                                  "Combined LMF" = "#B8D4A8")) +
    labs(
      subtitle = "Phase 2: Category a-Paths by Mediator Type (\u03b2)",
      x = "Boundary Resource Category",
      y = "Standardized Coefficient (\u03b2)",
      fill = "Mediator",
      caption = "Note. Standardized a-path coefficients (\u03b2) from Phase 2 SEM with bootstrap SE (2,000 replications).\nOnly significant coefficients labeled. N = 6,613 dyads.\n* p < .05. ** p < .01. *** p < .001."
    ) +
    theme_classic(base_family = "Times New Roman", base_size = 11) +
    theme(
      legend.position = "bottom",
      panel.grid.major.x = element_blank(),
      plot.title = element_text(face = "bold.italic", size = 13),
      plot.subtitle = element_text(size = 10),
      plot.caption = element_text(size = 8, hjust = 0, color = "grey40")
    )

  ggsave(file.path(output_tables, "Figure_15_7_Phase2_a_paths.png"),
         p6, width = 10, height = 6, dpi = 300)
  cat("  Saved: Figure_15_7_Phase2_a_paths.png\n")
}

# --- Figure 19.7: Phase 2 — Indirect effects by category for PLF ---
cat("\n--- Figure 19.7: Phase 2 Indirect Effects (PLF only) ---\n")

if (isTRUE(t2_p2$converged)) {
  ind_data <- t2_p2$params %>%
    filter(grepl("^ind_", label)) %>%
    mutate(
      Category = case_when(
        label == "ind_app" ~ "Application",
        label == "ind_dev" ~ "Development",
        label == "ind_ai"  ~ "AI",
        label == "ind_soc" ~ "Social",
        label == "ind_gov" ~ "Governance"
      ),
      is_sig = pvalue < .05,
      fill_color = case_when(
        !is_sig ~ "ns",
        std.all > 0 ~ "pos",
        TRUE ~ "neg"
      )
    )

  ind_data$Category <- factor(ind_data$Category,
    levels = c("Governance", "Application", "AI", "Development", "Social"))

  p7 <- ggplot(ind_data, aes(x = Category, y = std.all, fill = fill_color)) +
    geom_col(width = 0.6, color = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0, linewidth = 0.5) +
    geom_text(aes(label = paste0(sprintf("%.3f", std.all), sig),
                  y = std.all + sign(std.all) * 0.003),
              size = 3.5, vjust = ifelse(ind_data$std.all > 0, 0, 1),
              family = "Times New Roman") +
    scale_fill_manual(values = c("pos" = "#4A90D9", "neg" = "#D9534F",
                                  "ns" = "grey70"),
                      labels = c("pos" = "Positive (p < .05)",
                                 "neg" = "Negative (p < .05)",
                                 "ns" = "Not significant"),
                      name = "Effect") +
    labs(
      subtitle = "Indirect Effects Through Programming Language Fit (Phase 2)",
      x = "Boundary Resource Category",
      y = "Standardized Indirect Effect (\u03b2)"
    ) +
    theme_classic(base_family = "Times New Roman", base_size = 11) +
    theme(
      legend.position = "bottom",
      panel.grid.major.x = element_blank(),
      plot.title = element_text(face = "bold.italic", size = 13),
      plot.subtitle = element_text(size = 10)
    )

  ggsave(file.path(output_tables, "Figure_15_8_PLF_Indirect_Effects.png"),
         p7, width = 9, height = 6, dpi = 300)
  cat("  Saved: Figure_15_8_PLF_Indirect_Effects.png\n")
}

cat("\n--- Section 19 complete: Path diagrams saved to tables folder ---\n\n")

# ============================================================================
# SECTION 18: CLEAN UP AND SAVE
# ============================================================================

cat("=== SAVING UPDATED CODEBOOK ===\n\n")

# Drop intermediate columns that can't save to Excel (list columns, raw strings)
# Note: nat_lang_set and prog_lang_set were never joined to mc (used via lookups)
mc_save <- mc %>%
  select(-any_of(c("nat_lang_set", "prog_lang_set", "plat_langs",
                    "host_official", "official_languages",
                    "english_counts_as_covered")))

# Save back to codebook
write_xlsx(mc_save, codebook_path)
cat("  Saved updated codebook with LMF columns:", codebook_path, "\n")

# Print new columns added
new_cols <- c("all_nat_langs_raw", "local_lang_match", "english_available",
              "host_epi_norm", "nat_lang_fit", "all_prog_langs_raw",
              "prog_lang_fit", "z_nat_lang_fit", "z_prog_lang_fit",
              "language_market_fit")
cat("\n  New columns added:\n")
for (col in new_cols) {
  if (col %in% names(mc_save)) {
    cat(sprintf("    %-25s  non-NA: %d / %d\n", col,
                sum(!is.na(mc_save[[col]])), nrow(mc_save)))
  }
}

cat("\n=== SCRIPT 15 COMPLETE ===\n")
cat("Outputs:\n")
cat("  1. MASTER_CODEBOOK_analytic.xlsx (updated)\n")
cat("  2. 15_Language_Market_Fit_Tables.docx (Tables 15.0a-c, 15.1-15.11)\n")
cat("  3. Figure_15_0a_Top_Natural_Languages.png\n")
cat("  4. Figure_15_0b_Top_Programming_Languages.png\n")
cat("  5. Figure_15_0c_Prog_Languages_by_Source.png\n")
cat("  6. Figure_15_1_LMF_Distributions.png\n")
cat("  7. Figure_15_2_LMF_by_Industry.png\n")
cat("  8. Figure_15_3_NLF_vs_PLF_Scatter.png\n")
cat("  9. Figure_15_4_PLF_by_Country.png\n")
cat(" 10. Figure_15_5a-d: SEM Path Diagrams (EA, PLF, NLF, LMF)\n")
cat(" 11. Figure_15_6: Phase 1 Coefficient Comparison\n")
cat(" 12. Figure_15_7: Phase 2 Category a-path Comparison\n")
cat(" 13. Figure_15_8: PLF Indirect Effects by Category\n")
cat(" 14. 15_nat_lang_frequency.csv\n")
cat(" 15. 15_prog_lang_frequency.csv\n")
cat(" 16. 15_prog_lang_by_source.csv\n")
