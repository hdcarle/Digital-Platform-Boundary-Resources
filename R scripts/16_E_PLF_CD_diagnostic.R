# ============================================================================
# 16-E: DIAGNOSTIC — PLF × CD Interaction Explorer
# ============================================================================
# Purpose: Visualize where programming language fit varies across countries
#          and cultural distance to understand the negative CD × a-path
#          moderation finding from the PLF exploratory model.
#
# DATA SOURCES (from script 15):
#   Platform side: GitHub API scraping (SDK_prog_lang_list, GIT_prog_lang_list,
#                  BUG_prog_lang_list) — via github_lang_scraper.py
#   Country side:  Stack Overflow Developer Survey 2025 — developer language
#                  profiles by country (% of devs using each language)
#   PLF formula:   min(Σ s(k), 1) for k ∈ P ∩ C
#                  where s(k) = SO market share of language k in host country
#
# CLUSTERS: Uses GLOBE cultural clusters (House et al., 2004) matching script 10.
#           to enable comparison with script 10 cluster output.
#
# PREREQUISITE: Run script 15 first (needs prog_lang_fit in codebook)
# OUTPUT: Diagnostic plots → FINAL DISSERTATION/tables and charts REVISED/
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(stringr)

# --- File Paths ---
base_path    <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE", "MASTER_CODEBOOK_analytic.xlsx")
so_survey_path <- file.path(base_path, "dissertation data", "Control data",
                            "stack-overflow-developer-survey-2025",
                            "survey_results_public.csv")
output_path  <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")

# --- GLOBE Cultural Cluster Lookup (from script 10) ---
# Matches exactly what script 10_cultural_distance_kogut_singh.R uses.
# Based on House et al. (2004), Culture, Leadership, and Organizations:
# The GLOBE Study of 62 Societies. Sage Publications.
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

# --- Load Data ---
mc <- read_excel(codebook_path)
cat("Loaded codebook:", nrow(mc), "rows\n")

# Filter to platform dyads with PLF and CD
df <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(prog_lang_fit),
         !is.na(cultural_distance)) %>%
  mutate(
    PLF = prog_lang_fit,
    CD  = cultural_distance,
    host_cluster = cluster_lookup[host_country_iso3c],
    home_cluster = cluster_lookup[home_country_iso3c]
  )

cat("Working dataset:", nrow(df), "dyads\n")
cat("Countries:", n_distinct(df$host_country_iso3c), "\n")
cat("Platforms:", n_distinct(df$platform_ID), "\n")
cat("Clusters mapped:", sum(!is.na(df$host_cluster)), "/", nrow(df), "dyads\n\n")


# ============================================================================
# PLOT 1: PLF by Country, colored by mean CD (sorted by PLF)
# ============================================================================

country_summary <- df %>%
  group_by(host_country_iso3c, host_cluster) %>%
  summarize(
    PLF_mean = mean(PLF, na.rm = TRUE),
    PLF_sd   = sd(PLF, na.rm = TRUE),
    CD_mean  = mean(CD, na.rm = TRUE),
    n_dyads  = n(),
    .groups  = "drop"
  ) %>%
  arrange(PLF_mean)

country_summary$host_country_iso3c <- factor(
  country_summary$host_country_iso3c,
  levels = country_summary$host_country_iso3c
)

p1 <- ggplot(country_summary,
             aes(x = host_country_iso3c, y = PLF_mean, fill = CD_mean)) +
  geom_col() +
  geom_errorbar(aes(ymin = pmax(PLF_mean - PLF_sd, 0),
                     ymax = pmin(PLF_mean + PLF_sd, 1)),
                width = 0.3, linewidth = 0.3) +
  scale_fill_gradient2(low = "steelblue", mid = "lightyellow",
                       high = "firebrick",
                       midpoint = median(country_summary$CD_mean, na.rm = TRUE),
                       name = "Mean CD") +
  labs(
    x = "Host Country (sorted by PLF)",
    y = "Mean PLF (0-1)"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 10) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 7),
        plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E1_PLF_by_Country_CD_colored.png"),
       p1, width = 14, height = 6, dpi = 300)
cat("\u2713 Saved: 16_E1_PLF_by_Country_CD_colored.png\n")


# ============================================================================
# PLOT 2: PLF vs CD scatter (dyad-level) with loess
# ============================================================================

p2 <- ggplot(df, aes(x = CD, y = PLF)) +
  geom_jitter(alpha = 0.15, width = 0.05, height = 0.01, size = 0.8,
              color = "grey40") +
  geom_smooth(method = "loess", se = TRUE, color = "firebrick",
              linewidth = 1) +
  geom_smooth(method = "lm", se = FALSE, color = "steelblue",
              linetype = "dashed", linewidth = 0.8) +
  labs(
    x = "Cultural Distance (Kogut-Singh index)",
    y = "Programming Language Fit (0-1)"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 12) +
  theme(plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E2_PLF_vs_CD_scatter.png"),
       p2, width = 8, height = 6, dpi = 300)
cat("\u2713 Saved: 16_E2_PLF_vs_CD_scatter.png\n")


# ============================================================================
# PLOT 3: PLF distribution by GLOBE cluster
# ============================================================================

p3 <- ggplot(df %>% filter(!is.na(host_cluster)),
             aes(x = reorder(host_cluster, PLF, FUN = median),
                 y = PLF, fill = host_cluster)) +
  geom_boxplot(outlier.alpha = 0.3, outlier.size = 0.5) +
  coord_flip() +
  labs(
    x = "", y = "PLF (0-1)"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 12) +
  theme(legend.position = "none",
        plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E3_PLF_by_Cluster.png"),
       p3, width = 8, height = 5, dpi = 300)
cat("\u2713 Saved: 16_E3_PLF_by_Cluster.png\n")


# ============================================================================
# PLOT 3b: Cluster summary table (mirrors script 10 format)
# ============================================================================
# Directly comparable to script 10's cluster_summary table

cluster_plf_summary <- df %>%
  filter(!is.na(host_cluster)) %>%
  group_by(host_cluster) %>%
  summarize(
    n_dyads     = n(),
    n_firms     = n_distinct(platform_ID),
    n_countries = n_distinct(host_country_iso3c),
    PLF_mean    = round(mean(PLF, na.rm = TRUE), 3),
    PLF_sd      = round(sd(PLF, na.rm = TRUE), 3),
    PLF_median  = round(median(PLF, na.rm = TRUE), 3),
    CD_mean     = round(mean(CD, na.rm = TRUE), 2),
    CD_sd       = round(sd(CD, na.rm = TRUE), 2),
    .groups     = "drop"
  ) %>%
  arrange(PLF_mean)

cat("\n--- GLOBE Cluster Summary (PLF + CD) ---\n")
cat("  (Compare with script 10 cluster table)\n\n")
print(as.data.frame(cluster_plf_summary))
cat("\n")


# ============================================================================
# PLOT 4: PLF by Industry × CD tertile
# ============================================================================

df <- df %>%
  mutate(IND_factor = factor(IND),
         CD_group = cut(CD,
                        breaks = quantile(CD, probs = c(0, 1/3, 2/3, 1),
                                          na.rm = TRUE),
                        labels = c("Low CD", "Medium CD", "High CD"),
                        include.lowest = TRUE))

p4 <- ggplot(df %>% filter(!is.na(IND_factor)),
             aes(x = IND_factor, y = PLF, fill = CD_group)) +
  geom_boxplot(outlier.alpha = 0.2, outlier.size = 0.5) +
  scale_fill_manual(values = c("Low CD" = "steelblue",
                                "Medium CD" = "lightyellow",
                                "High CD" = "firebrick"),
                    name = "Cultural Distance") +
  labs(
    x = "Industry", y = "PLF (0-1)"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1),
        plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E4_PLF_by_Industry_CD.png"),
       p4, width = 10, height = 6, dpi = 300)
cat("\u2713 Saved: 16_E4_PLF_by_Industry_CD.png\n")


# ============================================================================
# PLOT 4b: Industry × CD interaction detail
# ============================================================================
# Table version — mean PLF by industry × CD group

ind_cd_table <- df %>%
  filter(!is.na(IND_factor), !is.na(CD_group)) %>%
  group_by(IND_factor, CD_group) %>%
  summarize(
    PLF_mean = round(mean(PLF), 3),
    PLF_sd   = round(sd(PLF), 3),
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = CD_group,
              values_from = c(PLF_mean, PLF_sd, n),
              names_sep = "_")

cat("\n--- PLF by Industry × CD Tertile ---\n")
print(as.data.frame(ind_cd_table))
cat("\n")


# ============================================================================
# PLOT 5: Platform-level — which platforms have the most PLF variance?
# ============================================================================

platform_summary <- df %>%
  group_by(platform_ID) %>%
  summarize(
    PLF_mean     = mean(PLF),
    PLF_sd       = sd(PLF),
    PLF_min      = min(PLF),
    PLF_max      = max(PLF),
    PLF_range    = max(PLF) - min(PLF),
    n_countries  = n_distinct(host_country_iso3c),
    n_dyads      = n(),
    home_country = first(home_country_iso3c),
    industry     = first(IND_factor),
    .groups      = "drop"
  ) %>%
  filter(n_countries >= 5) %>%
  arrange(desc(PLF_range))

cat("\n--- Top 15 Platforms by PLF Variance ---\n")
print(head(platform_summary %>%
             select(platform_ID, home_country, industry,
                    PLF_mean, PLF_min, PLF_max, PLF_range, n_countries),
           15))

# Use platform name if available, otherwise ID
p5 <- ggplot(platform_summary %>% head(20),
             aes(x = reorder(platform_ID, PLF_range), y = PLF_range,
                 fill = home_country)) +
  geom_col() +
  geom_text(aes(label = sprintf("%.2f (n=%d)", PLF_range, n_countries)),
            hjust = -0.05, size = 2.8, family = "Times New Roman") +
  coord_flip() +
  labs(
    x = "Platform ID", y = "PLF Range (max - min)",
    fill = "Home Country"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E5_PLF_Variance_by_Platform.png"),
       p5, width = 12, height = 7, dpi = 300)
cat("\u2713 Saved: 16_E5_PLF_Variance_by_Platform.png\n")


# ============================================================================
# PLOT 6: Heatmap — Country × top programming languages (SO 2025)
# ============================================================================
# Country-side profiles come from Stack Overflow Developer Survey 2025
# (same source used in script 15 to compute PLF)
# Platform-side languages come from GitHub API scraping

if (file.exists(so_survey_path)) {

  cat("\n--- Loading Stack Overflow 2025 data for language heatmap ---\n")
  so_raw <- read.csv(so_survey_path, stringsAsFactors = FALSE)

  # Country mapping (same as script 15)
  so_country_map <- c(
    "Argentina" = "ARG", "Australia" = "AUS", "Austria" = "AUT",
    "Bangladesh" = "BGD", "Belgium" = "BEL", "Brazil" = "BRA",
    "Canada" = "CAN", "Chile" = "CHL", "China" = "CHN",
    "Colombia" = "COL", "Czech Republic" = "CZE", "Denmark" = "DNK",
    "Egypt" = "EGY", "Finland" = "FIN", "France" = "FRA",
    "Germany" = "DEU", "Greece" = "GRC", "Hungary" = "HUN",
    "India" = "IND", "Indonesia" = "IDN", "Iran" = "IRN",
    "Ireland" = "IRL", "Israel" = "ISR", "Italy" = "ITA",
    "Japan" = "JPN", "Kenya" = "KEN", "Malaysia" = "MYS",
    "Mexico" = "MEX", "Morocco" = "MAR", "Netherlands" = "NLD",
    "New Zealand" = "NZL", "Nigeria" = "NGA", "Norway" = "NOR",
    "Pakistan" = "PAK", "Peru" = "PER", "Philippines" = "PHL",
    "Poland" = "POL", "Portugal" = "PRT", "Romania" = "ROU",
    "Russia" = "RUS", "Saudi Arabia" = "SAU", "Singapore" = "SGP",
    "South Africa" = "ZAF", "South Korea" = "KOR", "Spain" = "ESP",
    "Sri Lanka" = "LKA", "Sweden" = "SWE", "Switzerland" = "CHE",
    "Taiwan" = "TWN", "Thailand" = "THA", "Turkey" = "TUR",
    "Ukraine" = "UKR", "United Arab Emirates" = "ARE",
    "United Kingdom of Great Britain and Northern Ireland" = "GBR",
    "United States of America" = "USA", "Vietnam" = "VNM"
  )

  so_filtered <- so_raw %>%
    filter(Country %in% names(so_country_map),
           !is.na(LanguageHaveWorkedWith),
           LanguageHaveWorkedWith != "") %>%
    mutate(iso3c = so_country_map[Country])

  # Top 8 platform-offered languages (from 15_prog_lang_frequency.csv)
  top_langs <- c("JavaScript", "Python", "Java", "TypeScript",
                 "C#", "Go", "C++", "Kotlin")

  country_lang_shares <- so_filtered %>%
    mutate(lang_list = str_split(LanguageHaveWorkedWith, ";\\s*")) %>%
    unnest(lang_list) %>%
    mutate(lang_list = str_trim(lang_list)) %>%
    filter(lang_list %in% top_langs) %>%
    group_by(iso3c, lang_list) %>%
    summarize(n_devs = n(), .groups = "drop") %>%
    left_join(
      so_filtered %>% group_by(iso3c) %>%
        summarize(n_total = n(), .groups = "drop"),
      by = "iso3c"
    ) %>%
    mutate(share = n_devs / n_total) %>%
    filter(n_total >= 30)

  # Add CD and cluster
  country_cd <- df %>%
    group_by(host_country_iso3c) %>%
    summarize(CD_mean = mean(CD, na.rm = TRUE),
              host_cluster = first(host_cluster),
              .groups = "drop")

  country_lang_shares <- country_lang_shares %>%
    left_join(country_cd, by = c("iso3c" = "host_country_iso3c"))

  # Sort countries by CD (low at bottom, high at top)
  country_order <- country_lang_shares %>%
    group_by(iso3c) %>%
    summarize(CD_mean = first(CD_mean),
              host_cluster = first(host_cluster),
              .groups = "drop") %>%
    filter(!is.na(CD_mean)) %>%
    arrange(CD_mean)

  country_lang_shares_plot <- country_lang_shares %>%
    filter(iso3c %in% country_order$iso3c) %>%
    mutate(iso3c = factor(iso3c, levels = country_order$iso3c))

  p6 <- ggplot(country_lang_shares_plot,
               aes(x = lang_list, y = iso3c, fill = share)) +
    geom_tile(color = "white", linewidth = 0.3) +
    scale_fill_gradient(low = "white", high = "steelblue",
                        name = "Developer\nShare",
                        labels = scales::percent) +
    labs(
      x = "Programming Language", y = "Host Country"
    ) +
    theme_classic(base_family = "Times New Roman", base_size = 10) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          axis.text.y = element_text(size = 7),
          plot.title = element_blank(), plot.subtitle = element_blank())

  ggsave(file.path(output_path, "16_E6_Language_Heatmap_by_CD.png"),
         p6, width = 10, height = 12, dpi = 300)
  cat("\u2713 Saved: 16_E6_Language_Heatmap_by_CD.png\n")

  # --- Also: which countries have the LEAST coverage of top 8 languages? ---
  cat("\n--- Countries with lowest coverage of top 8 platform languages ---\n")
  country_coverage <- country_lang_shares %>%
    group_by(iso3c, host_cluster, CD_mean) %>%
    summarize(
      n_top_langs = n_distinct(lang_list),
      avg_share   = round(mean(share), 3),
      .groups     = "drop"
    ) %>%
    arrange(avg_share)
  print(head(country_coverage, 15))

} else {
  cat("\u26A0 Stack Overflow survey file not found — skipping heatmap.\n")
  cat("  Expected at:", so_survey_path, "\n")
}


# ============================================================================
# PLOT 7: PLF by GLOBE Cluster × CD (faceted) — direct comparison with script 10
# ============================================================================

p7 <- ggplot(df %>% filter(!is.na(host_cluster)),
             aes(x = CD, y = PLF, color = host_cluster)) +
  geom_jitter(alpha = 0.2, size = 0.6) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 0.8) +
  facet_wrap(~host_cluster, scales = "free_x") +
  labs(
    x = "Cultural Distance", y = "PLF (0-1)"
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 10) +
  theme(legend.position = "none",
        plot.title = element_blank(), plot.subtitle = element_blank())

ggsave(file.path(output_path, "16_E7_PLF_vs_CD_by_Cluster.png"),
       p7, width = 12, height = 8, dpi = 300)
cat("\u2713 Saved: 16_E7_PLF_vs_CD_by_Cluster.png\n")


# ============================================================================
# DIAGNOSTIC SUMMARY
# ============================================================================
cat("\n\n=== DIAGNOSTIC SUMMARY ===\n\n")

cat("Overall PLF:\n")
cat(sprintf("  Mean = %.3f, SD = %.3f, Median = %.3f\n",
            mean(df$PLF), sd(df$PLF), median(df$PLF)))
cat(sprintf("  %% of dyads with PLF >= 0.90: %.1f%%\n",
            100 * mean(df$PLF >= 0.90)))
cat(sprintf("  %% of dyads with PLF >= 0.95: %.1f%%\n",
            100 * mean(df$PLF >= 0.95)))

cat("\nCorrelation PLF \u00D7 CD:", round(cor(df$PLF, df$CD, use = "complete"), 3), "\n")

cat("\nPLF by CD tertile:\n")
df %>%
  group_by(CD_group) %>%
  summarize(
    PLF_mean   = round(mean(PLF), 3),
    PLF_sd     = round(sd(PLF), 3),
    PLF_median = round(median(PLF), 3),
    n = n(),
    .groups = "drop"
  ) %>%
  print()

cat("\nPLF by GLOBE cluster (script 10 classification):\n")
df %>%
  filter(!is.na(host_cluster)) %>%
  group_by(host_cluster) %>%
  summarize(
    PLF_mean = round(mean(PLF), 3),
    PLF_sd   = round(sd(PLF), 3),
    CD_mean  = round(mean(CD), 3),
    n = n(),
    .groups = "drop"
  ) %>%
  arrange(PLF_mean) %>%
  print()

# ============================================================================
# SECTION: WHICH GLOBE CLUSTERS DRIVE THE CD EFFECTS?
# ============================================================================
# Split-sample regressions by GLOBE cluster for ALL FOUR mediators:
#   PA  = Platform Accessibility (original model)
#   NLF = Natural Language Fit (script 15 exploratory)
#   PLF = Programming Language Fit (script 15 exploratory — CD sign flips!)
#   LMF = Language-Market Fit composite (script 15 exploratory)
#
# For each mediator:
#   b-path: DV_z ~ MED + CD_z + MED×CD  (does MED→DV vary by cluster?)
#   a-path: MED ~ PR_z + CD_z + PR×CD   (does PR→MED vary by cluster?)
#   CD direct: sign and magnitude of CD_z  (direction of CD effect)
#
# KEY QUESTION: PLF shows a POSITIVE CD coefficient (sign flip relative
# to PA/NLF/LMF). Which clusters drive this? Hypothesis: clusters where
# programming languages are culturally neutral (e.g., Confucian Asia)
# may show that higher CD actually helps when platforms offer the right
# programming tools, because the code itself is universal.
# ============================================================================

cat("\n", strrep("=", 70), "\n")
cat("GLOBE CLUSTER ANALYSIS: WHICH CLUSTERS DRIVE CD EFFECTS?\n")
cat("  Testing PA, NLF, PLF, and LMF mediators by cluster\n")
cat(strrep("=", 70), "\n\n")

library(flextable)
library(officer)

# --- Standardize all mediators ---
df <- df %>%
  mutate(
    PR_z  = scale(platform_resources)[,1],
    PA_z  = scale(platform_accessibility)[,1],
    DV_z  = scale(MKT_SHARE_CHANGE)[,1],
    CD_z  = scale(cultural_distance)[,1],
    PA_x_CD = PA_z * CD_z,
    PR_x_CD = PR_z * CD_z
  )

# NLF, PLF, LMF — only if columns exist in codebook
has_nlf <- "nat_lang_fit" %in% colnames(df)
has_plf <- "prog_lang_fit" %in% colnames(df)  # should always be TRUE in this script
has_lmf <- "language_market_fit" %in% colnames(df)

if (has_nlf) {
  df <- df %>% mutate(
    NLF_z = scale(nat_lang_fit)[,1],
    NLF_x_CD = NLF_z * CD_z
  )
  cat("  NLF_z created. Non-NA:", sum(!is.na(df$NLF_z)), "\n")
}
if (has_plf) {
  df <- df %>% mutate(
    PLF_z = scale(prog_lang_fit)[,1],
    PLF_x_CD = PLF_z * CD_z
  )
  cat("  PLF_z created. Non-NA:", sum(!is.na(df$PLF_z)), "\n")
}
if (has_lmf) {
  df <- df %>% mutate(
    LMF_z = scale(language_market_fit)[,1],
    LMF_x_CD = LMF_z * CD_z
  )
  cat("  LMF_z created. Non-NA:", sum(!is.na(df$LMF_z)), "\n")
}
cat("\n")

# --- Cluster sample sizes ---
cluster_n <- df %>%
  filter(!is.na(host_cluster)) %>%
  count(host_cluster, name = "n_dyads") %>%
  mutate(n_firms = sapply(host_cluster, function(cl) {
    n_distinct(df$platform_ID[df$host_cluster == cl & !is.na(df$host_cluster)])
  })) %>%
  arrange(desc(n_dyads))

cat("Dyads by GLOBE cluster:\n")
print(as.data.frame(cluster_n))
cat("\n")

min_n <- 50
eligible <- cluster_n %>% filter(n_dyads >= min_n) %>% pull(host_cluster)
cat("Clusters with >=", min_n, "dyads:", length(eligible), "\n")
cat("  ", paste(eligible, collapse = ", "), "\n\n")

# --- Helper: significance stars ---
sig_star <- function(p) {
  case_when(
    is.na(p)   ~ "",
    p < .001   ~ "***",
    p < .01    ~ "**",
    p < .05    ~ "*",
    p < .10    ~ "\u2020",
    TRUE       ~ "ns"
  )
}

# ============================================================================
# GENERIC FUNCTION: Run split-sample by cluster for any mediator
# ============================================================================

## Helper: safely extract a row from coef(summary(mod)); returns NAs if missing
safe_coef_row <- function(s, varname) {
  ct <- coef(s)
  if (varname %in% rownames(ct)) {
    ct[varname, ]
  } else {
    cat(sprintf("    [Note: '%s' dropped from model — returning NAs]\n", varname))
    c(Estimate = NA_real_, `Std. Error` = NA_real_,
      `t value` = NA_real_, `Pr(>|t|)` = NA_real_)
  }
}

run_cluster_split <- function(df, med_z, med_x_cd, med_label) {
  # b-path: DV ~ MED + CD + MED×CD
  cat(sprintf("\n--- %s: b-path (MED \u2192 DV) by Cluster ---\n\n", med_label))

  bpath <- df %>%
    filter(host_cluster %in% eligible, !is.na(.data[[med_z]])) %>%
    group_by(host_cluster) %>%
    group_modify(~ {
      tryCatch({
        .x$MED_z    <- .x[[med_z]]
        .x$MED_x_CD <- .x[[med_x_cd]]
        mod <- lm(DV_z ~ MED_z + CD_z + MED_x_CD, data = .x)
        s <- summary(mod)
        med_row <- safe_coef_row(s, "MED_z")
        cd_row  <- safe_coef_row(s, "CD_z")
        int_row <- safe_coef_row(s, "MED_x_CD")
        tibble(
          n_dyads     = nrow(.x),
          n_firms     = n_distinct(.x$platform_ID),
          MED_beta    = med_row[1],
          MED_se      = med_row[2],
          MED_p       = med_row[4],
          CD_beta     = cd_row[1],
          CD_se       = cd_row[2],
          CD_p        = cd_row[4],
          CDxMED_beta = int_row[1],
          CDxMED_se   = int_row[2],
          CDxMED_p    = int_row[4],
          R2          = s$r.squared
        )
      }, error = function(e) {
        cat(sprintf("    [Cluster skipped: %s]\n", conditionMessage(e)))
        tibble(
          n_dyads = nrow(.x), n_firms = n_distinct(.x$platform_ID),
          MED_beta = NA_real_, MED_se = NA_real_, MED_p = NA_real_,
          CD_beta = NA_real_, CD_se = NA_real_, CD_p = NA_real_,
          CDxMED_beta = NA_real_, CDxMED_se = NA_real_, CDxMED_p = NA_real_,
          R2 = NA_real_
        )
      })
    }) %>%
    ungroup() %>%
    mutate(mediator = med_label, path = "b-path")

  cat(sprintf("  %s b-path results:\n", med_label))
  print(as.data.frame(bpath %>% select(host_cluster, n_dyads,
        MED_beta, MED_p, CD_beta, CD_p, CDxMED_beta, CDxMED_p, R2)),
        digits = 3)

  # a-path: MED ~ PR + CD + PR×CD
  cat(sprintf("\n--- %s: a-path (PR \u2192 MED) by Cluster ---\n\n", med_label))

  apath <- df %>%
    filter(host_cluster %in% eligible, !is.na(.data[[med_z]])) %>%
    group_by(host_cluster) %>%
    group_modify(~ {
      tryCatch({
        .x$MED_z <- .x[[med_z]]
        mod <- lm(MED_z ~ PR_z + CD_z + PR_x_CD, data = .x)
        s <- summary(mod)
        pr_row  <- safe_coef_row(s, "PR_z")
        cd_row  <- safe_coef_row(s, "CD_z")
        int_row <- safe_coef_row(s, "PR_x_CD")
        tibble(
          n_dyads     = nrow(.x),
          n_firms     = n_distinct(.x$platform_ID),
          PR_beta     = pr_row[1],
          PR_se       = pr_row[2],
          PR_p        = pr_row[4],
          CD_beta     = cd_row[1],
          CD_se       = cd_row[2],
          CD_p        = cd_row[4],
          CDxPR_beta  = int_row[1],
          CDxPR_se    = int_row[2],
          CDxPR_p     = int_row[4],
          R2          = s$r.squared
        )
      }, error = function(e) {
        cat(sprintf("    [Cluster skipped: %s]\n", conditionMessage(e)))
        tibble(
          n_dyads = nrow(.x), n_firms = n_distinct(.x$platform_ID),
          PR_beta = NA_real_, PR_se = NA_real_, PR_p = NA_real_,
          CD_beta = NA_real_, CD_se = NA_real_, CD_p = NA_real_,
          CDxPR_beta = NA_real_, CDxPR_se = NA_real_, CDxPR_p = NA_real_,
          R2 = NA_real_
        )
      })
    }) %>%
    ungroup() %>%
    mutate(mediator = med_label, path = "a-path")

  cat(sprintf("  %s a-path results:\n", med_label))
  print(as.data.frame(apath %>% select(host_cluster, n_dyads,
        PR_beta, PR_p, CD_beta, CD_p, CDxPR_beta, CDxPR_p, R2)),
        digits = 3)

  list(bpath = bpath, apath = apath)
}

# ============================================================================
# E8a-d: RUN ALL FOUR MEDIATORS
# ============================================================================

cat("\n", strrep("-", 60), "\n")
cat("E8: PA (Platform Accessibility) — BASELINE MODEL\n")
cat(strrep("-", 60), "\n")
res_PA <- run_cluster_split(df, "PA_z", "PA_x_CD", "PA")

if (has_nlf) {
  cat("\n", strrep("-", 60), "\n")
  cat("E9: NLF (Natural Language Fit)\n")
  cat(strrep("-", 60), "\n")
  res_NLF <- run_cluster_split(df, "NLF_z", "NLF_x_CD", "NLF")
}

if (has_plf) {
  cat("\n", strrep("-", 60), "\n")
  cat("E10: PLF (Programming Language Fit) — CD SIGN FLIP\n")
  cat(strrep("-", 60), "\n")
  res_PLF <- run_cluster_split(df, "PLF_z", "PLF_x_CD", "PLF")
}

if (has_lmf) {
  cat("\n", strrep("-", 60), "\n")
  cat("E11: LMF (Language-Market Fit Composite)\n")
  cat(strrep("-", 60), "\n")
  res_LMF <- run_cluster_split(df, "LMF_z", "LMF_x_CD", "LMF")
}

# ============================================================================
# E12: COMPARE CD SIGN ACROSS MEDIATORS — THE KEY TABLE
# ============================================================================

cat("\n", strrep("=", 70), "\n")
cat("E12: CD COEFFICIENT COMPARISON ACROSS MEDIATORS BY CLUSTER\n")
cat("     (Where does the PLF sign flip?)\n")
cat(strrep("=", 70), "\n\n")

# Extract CD_beta from b-path for each mediator
cd_compare <- res_PA$bpath %>%
  select(host_cluster, n_dyads, CD_beta_PA = CD_beta, CD_p_PA = CD_p)

if (has_nlf) {
  cd_compare <- cd_compare %>%
    left_join(res_NLF$bpath %>%
                select(host_cluster, CD_beta_NLF = CD_beta, CD_p_NLF = CD_p),
              by = "host_cluster")
}
if (has_plf) {
  cd_compare <- cd_compare %>%
    left_join(res_PLF$bpath %>%
                select(host_cluster, CD_beta_PLF = CD_beta, CD_p_PLF = CD_p),
              by = "host_cluster")
}
if (has_lmf) {
  cd_compare <- cd_compare %>%
    left_join(res_LMF$bpath %>%
                select(host_cluster, CD_beta_LMF = CD_beta, CD_p_LMF = CD_p),
              by = "host_cluster")
}

cat("CD direct effect (b-path) by cluster and mediator:\n")
cat("  Positive CD_beta = higher CD helps performance (after controlling for mediator)\n")
cat("  Negative CD_beta = higher CD hurts performance\n\n")
print(as.data.frame(cd_compare), digits = 3)

# Also extract CD×MED interaction from b-path
cat("\n\nCD\u00D7Mediator interaction (b-path) by cluster:\n")
int_compare <- res_PA$bpath %>%
  select(host_cluster, CDxPA = CDxMED_beta, CDxPA_p = CDxMED_p)

if (has_nlf) {
  int_compare <- int_compare %>%
    left_join(res_NLF$bpath %>%
                select(host_cluster, CDxNLF = CDxMED_beta, CDxNLF_p = CDxMED_p),
              by = "host_cluster")
}
if (has_plf) {
  int_compare <- int_compare %>%
    left_join(res_PLF$bpath %>%
                select(host_cluster, CDxPLF = CDxMED_beta, CDxPLF_p = CDxMED_p),
              by = "host_cluster")
}
if (has_lmf) {
  int_compare <- int_compare %>%
    left_join(res_LMF$bpath %>%
                select(host_cluster, CDxLMF = CDxMED_beta, CDxLMF_p = CDxMED_p),
              by = "host_cluster")
}
print(as.data.frame(int_compare), digits = 3)

# ============================================================================
# E13: FOREST PLOT — CD DIRECT EFFECT BY MEDIATOR × CLUSTER
# ============================================================================

cat("\n--- E13: Forest Plot — CD Direct Effect by Mediator and Cluster ---\n\n")

# Build forest data for CD direct effect in b-path, all mediators
build_forest_cd <- function(res, med_label) {
  res$bpath %>%
    mutate(
      mediator = med_label,
      beta = CD_beta,
      se   = CD_se,
      p    = CD_p,
      ci_lo = beta - 1.96 * se,
      ci_hi = beta + 1.96 * se,
      sig   = ifelse(p < 0.05, "p < .05", "ns")
    ) %>%
    select(host_cluster, mediator, beta, se, ci_lo, ci_hi, p, sig, n_dyads)
}

forest_all <- build_forest_cd(res_PA, "PA")
if (has_nlf) forest_all <- bind_rows(forest_all, build_forest_cd(res_NLF, "NLF"))
if (has_plf) forest_all <- bind_rows(forest_all, build_forest_cd(res_PLF, "PLF"))
if (has_lmf) forest_all <- bind_rows(forest_all, build_forest_cd(res_LMF, "LMF"))

# Order mediators for display
forest_all$mediator <- factor(forest_all$mediator,
                               levels = c("PA", "NLF", "PLF", "LMF"))

p_forest_cd <- ggplot(forest_all,
                       aes(x = beta, y = reorder(host_cluster, beta),
                           color = sig, shape = mediator)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(size = 2.5, position = position_dodge(width = 0.6)) +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi),
                 height = 0.15, position = position_dodge(width = 0.6)) +
  scale_color_manual(values = c("p < .05" = "red", "ns" = "gray40"),
                     name = "Significance") +
  scale_shape_manual(values = c("PA" = 16, "NLF" = 17, "PLF" = 15, "LMF" = 18),
                     name = "Mediator") +
  labs(x = "CD Direct Effect (\u03B2) in b-path Model",
       y = "",
       caption = "Positive = higher CD helps performance; Negative = higher CD hurts") +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(text = element_text(family = "Times New Roman"),
        legend.position = "bottom",
        plot.caption = element_text(size = 8, hjust = 0))

ggsave(file.path(output_path, "16_E13_CD_Direct_by_Mediator_Cluster.png"),
       p_forest_cd, width = 10, height = 7, dpi = 300)
cat("\u2713 Saved: 16_E13_CD_Direct_by_Mediator_Cluster.png\n")

# ============================================================================
# E14: FOREST PLOT — CD×MED INTERACTION BY MEDIATOR × CLUSTER
# ============================================================================

cat("\n--- E14: Forest Plot — CD\u00D7Mediator Interaction by Cluster ---\n\n")

build_forest_int <- function(res, med_label) {
  res$bpath %>%
    mutate(
      mediator = med_label,
      beta = CDxMED_beta,
      se   = CDxMED_se,
      p    = CDxMED_p,
      ci_lo = beta - 1.96 * se,
      ci_hi = beta + 1.96 * se,
      sig   = ifelse(p < 0.05, "p < .05", "ns")
    ) %>%
    select(host_cluster, mediator, beta, se, ci_lo, ci_hi, p, sig, n_dyads)
}

forest_int <- build_forest_int(res_PA, "PA")
if (has_nlf) forest_int <- bind_rows(forest_int, build_forest_int(res_NLF, "NLF"))
if (has_plf) forest_int <- bind_rows(forest_int, build_forest_int(res_PLF, "PLF"))
if (has_lmf) forest_int <- bind_rows(forest_int, build_forest_int(res_LMF, "LMF"))

forest_int$mediator <- factor(forest_int$mediator,
                               levels = c("PA", "NLF", "PLF", "LMF"))

p_forest_int <- ggplot(forest_int,
                        aes(x = beta, y = reorder(host_cluster, beta),
                            color = sig, shape = mediator)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(size = 2.5, position = position_dodge(width = 0.6)) +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi),
                 height = 0.15, position = position_dodge(width = 0.6)) +
  scale_color_manual(values = c("p < .05" = "red", "ns" = "gray40"),
                     name = "Significance") +
  scale_shape_manual(values = c("PA" = 16, "NLF" = 17, "PLF" = 15, "LMF" = 18),
                     name = "Mediator") +
  labs(x = "CD\u00D7Mediator Interaction (\u03B2)",
       y = "",
       caption = "Positive = CD strengthens mediator effect; Negative = CD weakens it") +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(text = element_text(family = "Times New Roman"),
        legend.position = "bottom",
        plot.caption = element_text(size = 8, hjust = 0))

ggsave(file.path(output_path, "16_E14_CDxMED_Interaction_by_Cluster.png"),
       p_forest_int, width = 10, height = 7, dpi = 300)
cat("\u2713 Saved: 16_E14_CDxMED_Interaction_by_Cluster.png\n")

# ============================================================================
# E15: PLF DEEP DIVE — SLOPE PLOT BY CLUSTER × CD LEVEL
# ============================================================================
# This is the key diagnostic: where does PLF help MORE in high-CD contexts?

cat("\n--- E15: PLF \u2192 DV Slopes by Cluster and CD Level ---\n\n")

if (has_plf) {
  df_eligible <- df %>%
    filter(host_cluster %in% eligible, !is.na(host_cluster), !is.na(PLF_z))

  p_plf_slopes <- ggplot(df_eligible,
                          aes(x = PLF_z, y = DV_z, color = CD_group)) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 0.8) +
    facet_wrap(~host_cluster, scales = "free") +
    scale_color_manual(values = c("Low CD" = "steelblue",
                                  "Medium CD" = "darkgoldenrod",
                                  "High CD" = "firebrick"),
                       name = "Cultural Distance") +
    labs(x = "Programming Language Fit (Z)",
         y = "Market Share Change (Z)",
         caption = "Where high-CD slopes diverge upward = PLF helps more in high-CD contexts") +
    theme_classic(base_family = "Times New Roman", base_size = 10) +
    theme(text = element_text(family = "Times New Roman"),
          legend.position = "bottom",
          strip.text = element_text(size = 9, face = "bold"),
          plot.caption = element_text(size = 8, hjust = 0))

  ggsave(file.path(output_path, "16_E15_PLF_DV_Slopes_by_Cluster_CD.png"),
         p_plf_slopes, width = 12, height = 8, dpi = 300)
  cat("\u2713 Saved: 16_E15_PLF_DV_Slopes_by_Cluster_CD.png\n")

  # Also do NLF for comparison
  if (has_nlf) {
    df_nlf_elig <- df %>%
      filter(host_cluster %in% eligible, !is.na(host_cluster), !is.na(NLF_z))

    p_nlf_slopes <- ggplot(df_nlf_elig,
                            aes(x = NLF_z, y = DV_z, color = CD_group)) +
      geom_smooth(method = "lm", se = TRUE, alpha = 0.15, linewidth = 0.8) +
      facet_wrap(~host_cluster, scales = "free") +
      scale_color_manual(values = c("Low CD" = "steelblue",
                                    "Medium CD" = "darkgoldenrod",
                                    "High CD" = "firebrick"),
                         name = "Cultural Distance") +
      labs(x = "Natural Language Fit (Z)",
           y = "Market Share Change (Z)") +
      theme_classic(base_family = "Times New Roman", base_size = 10) +
      theme(text = element_text(family = "Times New Roman"),
            legend.position = "bottom",
            strip.text = element_text(size = 9, face = "bold"))

    ggsave(file.path(output_path, "16_E15b_NLF_DV_Slopes_by_Cluster_CD.png"),
           p_nlf_slopes, width = 12, height = 8, dpi = 300)
    cat("\u2713 Saved: 16_E15b_NLF_DV_Slopes_by_Cluster_CD.png\n")
  }
}

# ============================================================================
# E16: COMPREHENSIVE WORD TABLE — ALL MEDIATORS × ALL CLUSTERS
# ============================================================================

cat("\n--- E16: Building Comprehensive Word Table ---\n\n")

# Build one row per cluster×mediator with b-path results
build_tbl_row <- function(res, med_label) {
  res$bpath %>%
    mutate(
      Mediator    = med_label,
      MED_coef    = sprintf("%.3f%s", MED_beta, sig_star(MED_p)),
      CD_coef     = sprintf("%.3f%s", CD_beta, sig_star(CD_p)),
      CDxMED_coef = sprintf("%.3f%s", CDxMED_beta, sig_star(CDxMED_p)),
      R2_fmt      = sprintf("%.3f", R2),
      CD_sign     = ifelse(CD_beta > 0, "+", "\u2013")
    ) %>%
    select(host_cluster, Mediator, n_dyads, MED_coef, CD_coef, CD_sign,
           CDxMED_coef, R2_fmt)
}

all_tbl <- build_tbl_row(res_PA, "PA")
if (has_nlf) all_tbl <- bind_rows(all_tbl, build_tbl_row(res_NLF, "NLF"))
if (has_plf) all_tbl <- bind_rows(all_tbl, build_tbl_row(res_PLF, "PLF"))
if (has_lmf) all_tbl <- bind_rows(all_tbl, build_tbl_row(res_LMF, "LMF"))

# Sort: by cluster, then mediator order
all_tbl$Mediator <- factor(all_tbl$Mediator, levels = c("PA", "NLF", "PLF", "LMF"))
all_tbl <- all_tbl %>% arrange(host_cluster, Mediator)

ft_all <- flextable(all_tbl) %>%
  set_header_labels(
    host_cluster = "GLOBE Cluster", Mediator = "Med.",
    n_dyads = "N (dyads)", MED_coef = "\u03B2 (MED)",
    CD_coef = "\u03B2 (CD)", CD_sign = "CD Sign",
    CDxMED_coef = "\u03B2 (CD\u00D7MED)", R2_fmt = "R\u00B2"
  ) %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  bold(part = "header") %>%
  align(align = "center", part = "header") %>%
  align(j = 1:2, align = "left", part = "body") %>%
  align(j = 3:ncol(all_tbl), align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

# Add horizontal lines between clusters for readability
cluster_names <- unique(all_tbl$host_cluster)
for (i in seq_along(cluster_names)[-1]) {
  row_idx <- min(which(all_tbl$host_cluster == cluster_names[i])) - 1
  ft_all <- hline(ft_all, i = row_idx, border = fp_border(width = 0.5, color = "gray70"))
}

doc_all <- read_docx() %>%
  body_add_par("Table E16: CD Effects by GLOBE Cluster and Mediator",
               style = "heading 2") %>%
  body_add_par("b-path model: DV_z ~ Mediator + CD_z + CD\u00D7Mediator",
               style = "Normal") %>%
  body_add_par("", style = "Normal") %>%
  body_add_flextable(ft_all)

# Compute total dyads and firms per mediator from results
pa_total_dyads  <- sum(res_PA$bpath$n_dyads, na.rm = TRUE)
pa_total_firms  <- sum(res_PA$bpath$n_firms, na.rm = TRUE)
nlf_total_dyads <- if (has_nlf) sum(res_NLF$bpath$n_dyads, na.rm = TRUE) else NA
plf_total_dyads <- if (has_plf) sum(res_PLF$bpath$n_dyads, na.rm = TRUE) else NA
lmf_total_dyads <- if (has_lmf) sum(res_LMF$bpath$n_dyads, na.rm = TRUE) else NA

note_text <- paste0(
    "Note. OLS regressions run separately by host-country GLOBE cluster ",
    "(House et al., 2004). The Phase 1 SEM uses Platform Accessibility (PA) ",
    "as the mediator with the full PLAT sample (",
    format(pa_total_firms, big.mark = ","), " firms; ",
    format(pa_total_dyads, big.mark = ","), " dyads across eligible clusters). ",
    "PA is computed from boundary resource scores (PR composite). ",
    "NLF (Natural Language Fit), PLF (Programming Language Fit), and ",
    "LMF (Language-Market Fit) are alternative mediators that capture ",
    "language-based mechanisms of platform accessibility. ",
    "NLF measures the match between a platform\u2019s supported natural languages ",
    "and host-country language demand; PLF measures programming language alignment; ",
    "LMF combines both into a single language-market fit index. ",
    "Sample sizes differ across mediators due to data availability: "
  )

  # Add mediator-specific Ns
med_ns <- c()
if (has_nlf && !is.na(nlf_total_dyads))
  med_ns <- c(med_ns, paste0("NLF = ", format(nlf_total_dyads, big.mark = ","), " dyads"))
if (has_plf && !is.na(plf_total_dyads))
  med_ns <- c(med_ns, paste0("PLF = ", format(plf_total_dyads, big.mark = ","), " dyads"))
if (has_lmf && !is.na(lmf_total_dyads))
  med_ns <- c(med_ns, paste0("LMF = ", format(lmf_total_dyads, big.mark = ","), " dyads"))
note_text <- paste0(note_text, paste(med_ns, collapse = "; "), ". ")

note_text <- paste0(note_text,
    "Differences in explanatory power across models should be interpreted ",
    "in light of these reduced sample sizes. ",
    "CD Sign column highlights where CD has a positive (+) vs. negative (\u2013) ",
    "direct effect on performance. ",
    "Only clusters with \u2265 ", min_n, " dyads shown. ",
    "\u2020 p < .10. * p < .05. ** p < .01. *** p < .001."
  )

doc_all <- doc_all %>%
  body_add_par(note_text, style = "Normal")

print(doc_all, target = file.path(output_path,
                                  "16_E16_All_Mediators_by_Cluster.docx"))
cat("\u2713 Saved: 16_E16_All_Mediators_by_Cluster.docx\n")


# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== GLOBE CLUSTER CD ANALYSIS COMPLETE ===\n\n")
cat("Output files:\n")
cat("  16_E13_CD_Direct_by_Mediator_Cluster.png  — Forest plot: CD direct effect\n")
cat("  16_E14_CDxMED_Interaction_by_Cluster.png   — Forest plot: CD\u00D7MED interaction\n")
cat("  16_E15_PLF_DV_Slopes_by_Cluster_CD.png    — PLF slope plot (KEY DIAGNOSTIC)\n")
if (has_nlf) cat("  16_E15b_NLF_DV_Slopes_by_Cluster_CD.png   — NLF slope plot (comparison)\n")
cat("  16_E16_All_Mediators_by_Cluster.docx      — Comprehensive table\n")
cat("\nLook at the CD Sign column in the E16 table to see where PLF flips positive.\n")
cat("Compare the PLF and NLF slope plots (E15 vs E15b) to see the visual difference.\n")


# ============================================================================
# TABLE E17: GLOBE CLUSTER LANGUAGE PROFILES
# ============================================================================
# Comprehensive table showing NLF, PLF, natural languages, and programming
# languages by GLOBE cultural cluster. For appendix use.
# ============================================================================

cat("\n=== E17: GLOBE CLUSTER LANGUAGE PROFILES ===\n\n")

# --- Build cluster-level dataset from FULL codebook (not just PLF-filtered df) ---
mc_plat <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  mutate(
    host_cluster = cluster_lookup[host_country_iso3c]
  ) %>%
  filter(!is.na(host_cluster))

# --- Panel A: NLF and PLF descriptives by cluster ---
panel_a <- mc_plat %>%
  group_by(host_cluster) %>%
  summarize(
    N_dyads       = n(),
    N_platforms    = n_distinct(platform_ID),
    N_countries    = n_distinct(host_country_iso3c),
    NLF_n         = sum(!is.na(nat_lang_fit)),
    NLF_mean      = round(mean(nat_lang_fit, na.rm = TRUE), 3),
    NLF_sd        = round(sd(nat_lang_fit, na.rm = TRUE), 3),
    NLF_median    = round(median(nat_lang_fit, na.rm = TRUE), 3),
    PLF_n         = sum(!is.na(prog_lang_fit)),
    PLF_mean      = round(mean(prog_lang_fit, na.rm = TRUE), 3),
    PLF_sd        = round(sd(prog_lang_fit, na.rm = TRUE), 3),
    PLF_median    = round(median(prog_lang_fit, na.rm = TRUE), 3),
    LMF_n         = sum(!is.na(language_market_fit)),
    LMF_mean      = round(mean(language_market_fit, na.rm = TRUE), 3),
    LMF_sd        = round(sd(language_market_fit, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(desc(N_dyads))

cat("Panel A: NLF/PLF/LMF descriptives by cluster\n")
print(as.data.frame(panel_a))

# --- Panel B: Top natural languages offered by platforms in each cluster ---
# Expand linguistic_variety_list (semicolon-separated) per platform, then
# aggregate by host cluster

platform_nat_langs <- mc_plat %>%
  distinct(platform_ID, host_cluster, .keep_all = TRUE) %>%
  filter(!is.na(linguistic_variety_list) & linguistic_variety_list != "") %>%
  mutate(nat_lang = str_split(linguistic_variety_list, ";\\s*")) %>%
  unnest(nat_lang) %>%
  mutate(nat_lang = str_trim(nat_lang)) %>%
  filter(nat_lang != "" & nat_lang != "NA")

# Count: how many platforms in each cluster offer each language
nat_lang_by_cluster <- platform_nat_langs %>%
  group_by(host_cluster, nat_lang) %>%
  summarize(n_platforms = n_distinct(platform_ID), .groups = "drop") %>%
  left_join(
    panel_a %>% select(host_cluster, N_platforms),
    by = "host_cluster"
  ) %>%
  mutate(pct = round(100 * n_platforms / N_platforms, 1)) %>%
  arrange(host_cluster, desc(pct))

# Top 5 natural languages per cluster
top_nat_by_cluster <- nat_lang_by_cluster %>%
  group_by(host_cluster) %>%
  slice_head(n = 5) %>%
  mutate(rank = row_number(),
         label = paste0(nat_lang, " (", pct, "%)")) %>%
  ungroup()

cat("\nPanel B: Top 5 natural languages by cluster\n")
for (cl in unique(top_nat_by_cluster$host_cluster)) {
  cat(cl, ":\n")
  sub <- top_nat_by_cluster %>% filter(host_cluster == cl)
  for (i in 1:nrow(sub)) {
    cat(sprintf("  %d. %s\n", sub$rank[i], sub$label[i]))
  }
  cat("\n")
}

# --- Panel C: Top programming languages offered by platforms in each cluster ---
platform_prog_langs <- mc_plat %>%
  distinct(platform_ID, host_cluster, .keep_all = TRUE) %>%
  filter(!is.na(programming_lang_variety_list) & programming_lang_variety_list != "") %>%
  mutate(prog_lang = str_split(programming_lang_variety_list, ";\\s*")) %>%
  unnest(prog_lang) %>%
  mutate(prog_lang = str_trim(prog_lang)) %>%
  filter(prog_lang != "" & prog_lang != "NA")

prog_lang_by_cluster <- platform_prog_langs %>%
  group_by(host_cluster, prog_lang) %>%
  summarize(n_platforms = n_distinct(platform_ID), .groups = "drop") %>%
  left_join(
    panel_a %>% select(host_cluster, N_platforms),
    by = "host_cluster"
  ) %>%
  mutate(pct = round(100 * n_platforms / N_platforms, 1)) %>%
  arrange(host_cluster, desc(pct))

# Top 5 programming languages per cluster
top_prog_by_cluster <- prog_lang_by_cluster %>%
  group_by(host_cluster) %>%
  slice_head(n = 5) %>%
  mutate(rank = row_number(),
         label = paste0(prog_lang, " (", pct, "%)")) %>%
  ungroup()

cat("Panel C: Top 5 programming languages by cluster\n")
for (cl in unique(top_prog_by_cluster$host_cluster)) {
  cat(cl, ":\n")
  sub <- top_prog_by_cluster %>% filter(host_cluster == cl)
  for (i in 1:nrow(sub)) {
    cat(sprintf("  %d. %s\n", sub$rank[i], sub$label[i]))
  }
  cat("\n")
}

# --- Panel D: Stack Overflow developer community language profile by cluster ---
# (Host country developer skill profiles — what the market uses)
# Reuse SO survey data already loaded earlier in this script

# Add GLOBE cluster to SO data (uses iso3c → cluster_lookup, same as df)
so_filtered <- so_filtered %>%
  mutate(host_cluster = cluster_lookup[iso3c]) %>%
  filter(!is.na(host_cluster))

so_with_cluster <- so_filtered %>%
  mutate(lang_list = str_split(LanguageHaveWorkedWith, ";\\s*")) %>%
  unnest(lang_list) %>%
  mutate(lang_list = str_trim(lang_list))

so_cluster_n <- so_filtered %>%
  group_by(host_cluster) %>%
  summarize(n_devs = n(), .groups = "drop")

so_cluster_langs <- so_with_cluster %>%
  group_by(host_cluster, lang_list) %>%
  summarize(n = n(), .groups = "drop") %>%
  left_join(so_cluster_n, by = "host_cluster") %>%
  mutate(pct = round(100 * n / n_devs, 1)) %>%
  arrange(host_cluster, desc(pct))

top_so_by_cluster <- so_cluster_langs %>%
  group_by(host_cluster) %>%
  slice_head(n = 5) %>%
  mutate(rank = row_number(),
         label = paste0(lang_list, " (", pct, "%)")) %>%
  ungroup()

cat("Panel D: Top 5 developer community languages by cluster (Stack Overflow)\n")
for (cl in unique(top_so_by_cluster$host_cluster)) {
  n_devs <- so_cluster_n$n_devs[so_cluster_n$host_cluster == cl]
  cat(cl, " (N=", n_devs, "):\n", sep = "")
  sub <- top_so_by_cluster %>% filter(host_cluster == cl)
  for (i in 1:nrow(sub)) {
    cat(sprintf("  %d. %s\n", sub$rank[i], sub$label[i]))
  }
  cat("\n")
}

# --- Build Word document with all 4 panels ---
library(flextable)
library(officer)

doc_e17 <- read_docx()

# Title
doc_e17 <- body_add_par(doc_e17,
  "Table E17: GLOBE Cluster Language Profiles",
  style = "heading 2")
doc_e17 <- body_add_par(doc_e17, "")

# ---- Panel A: NLF/PLF/LMF Descriptives ----
doc_e17 <- body_add_par(doc_e17,
  "Panel A: Language-Market Fit Descriptives by GLOBE Cluster",
  style = "heading 3")

ft_a <- flextable(panel_a %>%
  select(host_cluster, N_dyads, N_platforms, N_countries,
         NLF_n, NLF_mean, NLF_sd,
         PLF_n, PLF_mean, PLF_sd,
         LMF_n, LMF_mean, LMF_sd)) %>%
  set_header_labels(
    host_cluster = "GLOBE Cluster",
    N_dyads = "N (Dyads)", N_platforms = "N (Plat.)", N_countries = "N (Countries)",
    NLF_n = "n", NLF_mean = "M", NLF_sd = "SD",
    PLF_n = "n", PLF_mean = "M", PLF_sd = "SD",
    LMF_n = "n", LMF_mean = "M", LMF_sd = "SD"
  ) %>%
  add_header_row(
    values = c("", "Sample", "", "",
               "Natural Language Fit", "", "",
               "Programming Language Fit", "", "",
               "Language-Market Fit", "", ""),
    colwidths = rep(1, 13)
  ) %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 9, part = "all") %>%
  bold(part = "header") %>%
  autofit()

doc_e17 <- body_add_flextable(doc_e17, ft_a)

doc_e17 <- body_add_par(doc_e17,
  paste0("Note. NLF = Natural Language Fit (alignment of platform language ",
         "offerings with host country official languages, weighted by EF EPI). ",
         "PLF = Programming Language Fit (alignment of platform programming ",
         "languages with host country developer profiles from Stack Overflow 2025). ",
         "LMF = mean of z-standardized NLF and PLF. ",
         "GLOBE clusters follow House et al. (2004)."),
  style = "Normal")

doc_e17 <- body_add_par(doc_e17, "")

# ---- Panel B: Top Natural Languages (Platform Side) ----
doc_e17 <- body_add_par(doc_e17,
  "Panel B: Top 5 Natural Languages Offered by Platforms (by Host Cluster)",
  style = "heading 3")

# Pivot to wide: Rank × Cluster
clusters_ordered <- panel_a$host_cluster  # already sorted by N_dyads desc

wide_nat <- top_nat_by_cluster %>%
  select(host_cluster, rank, label) %>%
  pivot_wider(names_from = host_cluster, values_from = label) %>%
  rename(Rank = rank)

# Reorder columns to match cluster order
cols_present <- intersect(clusters_ordered, colnames(wide_nat))
wide_nat <- wide_nat %>% select(Rank, all_of(cols_present))

ft_b <- flextable(wide_nat) %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 9, part = "all") %>%
  bold(part = "header") %>%
  autofit()

doc_e17 <- body_add_flextable(doc_e17, ft_b)
doc_e17 <- body_add_par(doc_e17,
  paste0("Note. Percentages indicate the proportion of platforms in each ",
         "GLOBE cluster that offer content in that natural language across ",
         "any of the 8 coded resource types. Platforms may offer multiple languages."),
  style = "Normal")
doc_e17 <- body_add_par(doc_e17, "")

# ---- Panel C: Top Programming Languages (Platform Side) ----
doc_e17 <- body_add_par(doc_e17,
  "Panel C: Top 5 Programming Languages Supported by Platforms (by Host Cluster)",
  style = "heading 3")

wide_prog <- top_prog_by_cluster %>%
  select(host_cluster, rank, label) %>%
  pivot_wider(names_from = host_cluster, values_from = label) %>%
  rename(Rank = rank)

cols_present_prog <- intersect(clusters_ordered, colnames(wide_prog))
wide_prog <- wide_prog %>% select(Rank, all_of(cols_present_prog))

ft_c <- flextable(wide_prog) %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 9, part = "all") %>%
  bold(part = "header") %>%
  autofit()

doc_e17 <- body_add_flextable(doc_e17, ft_c)
doc_e17 <- body_add_par(doc_e17,
  paste0("Note. Percentages indicate the proportion of platforms in each ",
         "GLOBE cluster that support that programming language via SDK, ",
         "GitHub repository, or bug tracking tools. Platforms may support ",
         "multiple languages."),
  style = "Normal")
doc_e17 <- body_add_par(doc_e17, "")

# ---- Panel D: Developer Community Profile (Stack Overflow) ----
doc_e17 <- body_add_par(doc_e17,
  "Panel D: Top 5 Programming Languages Used by Host Country Developers (Stack Overflow 2025)",
  style = "heading 3")

wide_so <- top_so_by_cluster %>%
  select(host_cluster, rank, label) %>%
  pivot_wider(names_from = host_cluster, values_from = label) %>%
  rename(Rank = rank)

cols_present_so <- intersect(clusters_ordered, colnames(wide_so))
wide_so <- wide_so %>% select(Rank, all_of(cols_present_so))

ft_d <- flextable(wide_so) %>%
  font(fontname = "Times New Roman", part = "all") %>%
  fontsize(size = 9, part = "all") %>%
  bold(part = "header") %>%
  autofit()

doc_e17 <- body_add_flextable(doc_e17, ft_d)

# Add SO sample sizes as note
so_note_parts <- so_cluster_n %>%
  arrange(desc(n_devs)) %>%
  mutate(part = paste0(host_cluster, " n=", format(n_devs, big.mark = ","))) %>%
  pull(part)

doc_e17 <- body_add_par(doc_e17,
  paste0("Note. Percentages indicate the proportion of developers in each GLOBE ",
         "cluster who reported using that programming language (Stack Overflow ",
         "Developer Survey 2025). Developers may report multiple languages; ",
         "percentages do not sum to 100%. Sample sizes: ",
         paste(so_note_parts, collapse = "; "), ". ",
         "GLOBE clusters follow House et al. (2004)."),
  style = "Normal")

# Save
print(doc_e17, target = file.path(output_path,
                                  "16_E17_GLOBE_Cluster_Language_Profiles.docx"))
cat("\n✓ Saved: 16_E17_GLOBE_Cluster_Language_Profiles.docx\n")


cat("\n\n=== DONE ===\n")
cat("Check output folder for plots 16_E1 through 16_E17.\n")
