# =============================================================================
# Language Variable Analysis — Claude vs ChatGPT Comparison
# =============================================================================
# Produces descriptive statistics and coder comparison tables for the
# Methods section of the dissertation.
#
# Updated: February 20, 2026
#
# Input:  language_summary.csv (exported by normalize_languages.py)
#         — 1808 rows: 904 platforms × 2 coders (Claude + ChatGPT)
#         — All language strings normalized to English
#
# Output: Console tables + CSV exports for charts and discussion
#
# Variables analyzed:
#   Natural language counts (8): SDK_lang, COM_lang, GIT_lang, SPAN_lang,
#                                ROLE_lang, DATA_lang, STORE_lang, CERT_lang
#   Programming language counts (3): SDK_prog_lang, BUG_prog_lang, GIT_prog_lang
#   Computed: unique_natural_langs, is_multilingual
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

# Adjust path if running from RStudio with different working directory
base_path <- "../dissertation_batch_api/language_data"
lang_df <- read_csv(file.path(base_path, "language_summary.csv"),
                    show_col_types = FALSE)

# Output directory: consistent with other scripts (e.g., 15_language_market_fit.R)
output_tables <- file.path("..", "FINAL DISSERTATION", "tables and charts REVISED")
if (!dir.exists(output_tables)) dir.create(output_tables, recursive = TRUE)

cat(sprintf("Loaded %d rows (%d platforms × %d coders)\n",
            nrow(lang_df), n_distinct(lang_df$platform_id), n_distinct(lang_df$coder)))

# Industry labels for readable output
industry_labels <- c(
  CA = "Consumer Appliances",
  CC = "Credit Cards",
  CP = "Computer & Peripherals",
  FO = "Food & Nutrition",
  HO = "Hotels & Accommodation",
  IH = "Industrial & Home Improvement",
  PE = "Personal Electronics",
  TG = "Toys & Games",
  TR = "Travel & Tourism",
  VG = "Video Games"
)

lang_df <- lang_df %>%
  mutate(
    industry_label = industry_labels[industry],
    # Ensure PLAT firms only for most analyses
    is_plat = plat %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")
  )

# Natural language count columns
nat_lang_vars <- c("SDK_lang", "COM_lang", "GIT_lang", "SPAN_lang",
                   "ROLE_lang", "DATA_lang", "STORE_lang", "CERT_lang")

# Programming language count columns (3 sources: SDK, BUG, GIT)
prog_lang_vars <- c("SDK_prog_lang", "BUG_prog_lang", "GIT_prog_lang")


# =============================================================================
# 2. DESCRIPTIVE STATISTICS — PLAT FIRMS ONLY
# =============================================================================

plat_df <- lang_df %>% filter(is_plat)
cat(sprintf("\nPLAT firms: %d rows (%d platforms × 2 coders)\n",
            nrow(plat_df), n_distinct(plat_df$platform_id)))

# --- 2a. Overall natural language counts by coder ---
cat("\n", strrep("=", 60), "\n")
cat("NATURAL LANGUAGE COUNTS BY CODER (PLAT firms only)\n")
cat(strrep("=", 60), "\n")

nat_summary_by_coder <- plat_df %>%
  group_by(coder) %>%
  summarise(
    n_platforms = n(),
    across(all_of(nat_lang_vars),
           list(mean = ~mean(., na.rm = TRUE),
                sd = ~sd(., na.rm = TRUE),
                median = ~median(., na.rm = TRUE),
                max = ~max(., na.rm = TRUE),
                nonzero = ~sum(. > 0, na.rm = TRUE)),
           .names = "{.col}__{.fn}"),
    .groups = "drop"
  )

# Reshape for display
for (var in nat_lang_vars) {
  cat(sprintf("\n--- %s ---\n", var))
  for (cd in c("Claude", "ChatGPT")) {
    row <- nat_summary_by_coder %>% filter(coder == cd)
    cat(sprintf("  %s: mean=%.2f, sd=%.2f, median=%.0f, max=%.0f, nonzero=%d/%d\n",
                cd,
                row[[paste0(var, "__mean")]],
                row[[paste0(var, "__sd")]],
                row[[paste0(var, "__median")]],
                row[[paste0(var, "__max")]],
                row[[paste0(var, "__nonzero")]],
                row[["n_platforms"]]))
  }
}

# --- 2b. Unique natural languages and multilingual status ---
cat("\n", strrep("=", 60), "\n")
cat("UNIQUE NATURAL LANGUAGES & MULTILINGUAL STATUS\n")
cat(strrep("=", 60), "\n")

multilingual_summary <- plat_df %>%
  group_by(coder) %>%
  summarise(
    n_platforms = n(),
    any_lang_coded = sum(unique_natural_langs > 0, na.rm = TRUE),
    multilingual = sum(is_multilingual == 1, na.rm = TRUE),
    mean_unique_langs = mean(unique_natural_langs, na.rm = TRUE),
    sd_unique_langs = sd(unique_natural_langs, na.rm = TRUE),
    max_unique_langs = max(unique_natural_langs, na.rm = TRUE),
    .groups = "drop"
  )
print(multilingual_summary)


# =============================================================================
# 3. CODER AGREEMENT ON NATURAL LANGUAGE VARIABLES
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("CODER AGREEMENT ON NATURAL LANGUAGE COUNTS\n")
cat(strrep("=", 60), "\n")

# Pivot to wide: one row per platform, Claude vs ChatGPT side by side
wide_nat <- plat_df %>%
  select(platform_id, coder, all_of(nat_lang_vars)) %>%
  pivot_wider(names_from = coder, values_from = all_of(nat_lang_vars),
              names_sep = "_")

# For each variable, compute agreement metrics
nat_agreement <- map_dfr(nat_lang_vars, function(var) {
  claude_col <- paste0(var, "_Claude")
  gpt_col <- paste0(var, "_ChatGPT")
  v_c <- wide_nat[[claude_col]]
  v_g <- wide_nat[[gpt_col]]
  valid <- !is.na(v_c) & !is.na(v_g)
  v_c <- v_c[valid]; v_g <- v_g[valid]; n <- length(v_c)

  exact_agree <- sum(v_c == v_g)
  agree_pct <- exact_agree / n * 100
  mean_diff <- mean(v_c - v_g)
  sd_diff <- sd(v_c - v_g)
  # Direction of disagreement
  claude_higher <- sum(v_c > v_g)
  gpt_higher <- sum(v_g > v_c)
  cor_val <- tryCatch(cor(v_c, v_g), error = function(e) NA_real_)

  tibble(
    Variable = var,
    N = n,
    Exact_Agreement = exact_agree,
    Agree_Pct = round(agree_pct, 1),
    Mean_Diff_C_minus_G = round(mean_diff, 2),
    SD_Diff = round(sd_diff, 2),
    Claude_Higher = claude_higher,
    ChatGPT_Higher = gpt_higher,
    Correlation = round(cor_val, 3)
  )
})
print(nat_agreement, width = Inf)

# --- Which coder finds more languages overall? ---
cat("\nOverall pattern:\n")
cat(sprintf("  Claude codes higher: %d of %d comparisons (%.1f%%)\n",
            sum(nat_agreement$Claude_Higher),
            sum(nat_agreement$N),
            sum(nat_agreement$Claude_Higher) / sum(nat_agreement$N) * 100))
cat(sprintf("  ChatGPT codes higher: %d of %d comparisons (%.1f%%)\n",
            sum(nat_agreement$ChatGPT_Higher),
            sum(nat_agreement$N),
            sum(nat_agreement$ChatGPT_Higher) / sum(nat_agreement$N) * 100))


# =============================================================================
# 4. CODER AGREEMENT ON PROGRAMMING LANGUAGE VARIABLES
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("CODER AGREEMENT ON PROGRAMMING LANGUAGE COUNTS\n")
cat(strrep("=", 60), "\n")

wide_prog <- plat_df %>%
  select(platform_id, coder, all_of(prog_lang_vars)) %>%
  pivot_wider(names_from = coder, values_from = all_of(prog_lang_vars),
              names_sep = "_")

prog_agreement <- map_dfr(prog_lang_vars, function(var) {
  claude_col <- paste0(var, "_Claude")
  gpt_col <- paste0(var, "_ChatGPT")
  v_c <- wide_prog[[claude_col]]
  v_g <- wide_prog[[gpt_col]]
  valid <- !is.na(v_c) & !is.na(v_g)
  v_c <- v_c[valid]; v_g <- v_g[valid]; n <- length(v_c)

  exact_agree <- sum(v_c == v_g)
  agree_pct <- exact_agree / n * 100
  mean_diff <- mean(v_c - v_g)
  claude_higher <- sum(v_c > v_g)
  gpt_higher <- sum(v_g > v_c)
  cor_val <- tryCatch(cor(v_c, v_g), error = function(e) NA_real_)

  tibble(
    Variable = var,
    N = n,
    Exact_Agreement = exact_agree,
    Agree_Pct = round(agree_pct, 1),
    Mean_Diff_C_minus_G = round(mean_diff, 2),
    Claude_Higher = claude_higher,
    ChatGPT_Higher = gpt_higher,
    Correlation = round(cor_val, 3)
  )
})
print(prog_agreement, width = Inf)

cat("\nNote: GIT_prog_lang is deterministic from GitHub augmentation (100% agreement expected).\n")
cat("SDK_prog_lang and BUG_prog_lang are independently coded by each coder.\n")


# =============================================================================
# 5. DESCRIPTIVE STATISTICS BY INDUSTRY
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("NATURAL LANGUAGE COUNTS BY INDUSTRY (Mean across coders)\n")
cat(strrep("=", 60), "\n")

# Average across coders for each platform, then summarize by industry
platform_avg <- plat_df %>%
  group_by(platform_id, industry, industry_label, plat) %>%
  summarise(
    across(all_of(c(nat_lang_vars, prog_lang_vars, "unique_natural_langs")),
           ~mean(., na.rm = TRUE)),
    is_multilingual = max(is_multilingual, na.rm = TRUE),
    .groups = "drop"
  )

industry_nat <- platform_avg %>%
  filter(!is.na(industry) & industry != "") %>%
  group_by(industry, industry_label) %>%
  summarise(
    n_platforms = n(),
    n_plat_firms = sum(!is.na(unique_natural_langs)),
    mean_unique_langs = round(mean(unique_natural_langs, na.rm = TRUE), 1),
    sd_unique_langs = round(sd(unique_natural_langs, na.rm = TRUE), 1),
    pct_multilingual = round(mean(is_multilingual, na.rm = TRUE) * 100, 1),
    mean_SDK_lang = round(mean(SDK_lang, na.rm = TRUE), 1),
    mean_COM_lang = round(mean(COM_lang, na.rm = TRUE), 1),
    mean_ROLE_lang = round(mean(ROLE_lang, na.rm = TRUE), 1),
    mean_DATA_lang = round(mean(DATA_lang, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_unique_langs))

print(industry_nat, width = Inf)


# =============================================================================
# 6. DESCRIPTIVE STATISTICS BY PLATFORM TYPE
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("NATURAL LANGUAGE COUNTS BY PLATFORM TYPE\n")
cat(strrep("=", 60), "\n")

plat_type_summary <- platform_avg %>%
  filter(plat %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  group_by(plat) %>%
  summarise(
    n_platforms = n(),
    mean_unique_langs = round(mean(unique_natural_langs, na.rm = TRUE), 1),
    sd_unique_langs = round(sd(unique_natural_langs, na.rm = TRUE), 1),
    pct_multilingual = round(mean(is_multilingual, na.rm = TRUE) * 100, 1),
    mean_SDK_lang = round(mean(SDK_lang, na.rm = TRUE), 1),
    mean_COM_lang = round(mean(COM_lang, na.rm = TRUE), 1),
    mean_SDK_prog_lang = round(mean(SDK_prog_lang, na.rm = TRUE), 1),
    mean_BUG_prog_lang = round(mean(BUG_prog_lang, na.rm = TRUE), 1),
    mean_GIT_prog_lang = round(mean(GIT_prog_lang, na.rm = TRUE), 1),
    .groups = "drop"
  )
print(plat_type_summary, width = Inf)


# =============================================================================
# 7. PROGRAMMING LANGUAGE STATISTICS BY INDUSTRY
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("PROGRAMMING LANGUAGE COUNTS BY INDUSTRY\n")
cat(strrep("=", 60), "\n")

industry_prog <- platform_avg %>%
  filter(!is.na(industry) & industry != "") %>%
  group_by(industry, industry_label) %>%
  summarise(
    n_platforms = n(),
    mean_SDK_prog = round(mean(SDK_prog_lang, na.rm = TRUE), 2),
    sd_SDK_prog = round(sd(SDK_prog_lang, na.rm = TRUE), 2),
    mean_BUG_prog = round(mean(BUG_prog_lang, na.rm = TRUE), 2),
    sd_BUG_prog = round(sd(BUG_prog_lang, na.rm = TRUE), 2),
    mean_GIT_prog = round(mean(GIT_prog_lang, na.rm = TRUE), 1),
    sd_GIT_prog = round(sd(GIT_prog_lang, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_GIT_prog))

print(industry_prog, width = Inf)


# =============================================================================
# 8. MOST COMMON LANGUAGES FOUND
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("MOST COMMON NATURAL LANGUAGES (across all _lang_list fields)\n")
cat(strrep("=", 60), "\n")

# Parse natural_lang_list_all to find individual languages
parse_lang_list <- function(df, list_col) {
  df %>%
    select(platform_id, coder, !!sym(list_col)) %>%
    filter(!is.na(!!sym(list_col)) & !!sym(list_col) != "") %>%
    separate_rows(!!sym(list_col), sep = ";\\s*") %>%
    mutate(language = str_trim(!!sym(list_col))) %>%
    filter(language != "")
}

# Use natural_lang_list_all which aggregates across all _lang_list fields
all_nat_parsed <- parse_lang_list(plat_df, "natural_lang_list_all")

nat_freq_by_coder <- all_nat_parsed %>%
  group_by(coder) %>%
  mutate(n_platforms_coder = n_distinct(platform_id)) %>%
  ungroup() %>%
  count(coder, language, n_platforms_coder = first(n_platforms_coder)) %>%
  mutate(pct = round(n / n_platforms_coder * 100, 1)) %>%
  arrange(coder, desc(n))

# Top 15 languages per coder
for (cd in c("Claude", "ChatGPT")) {
  cat(sprintf("\n--- Top 15 Natural Languages (%s) ---\n", cd))
  nat_freq_by_coder %>%
    filter(coder == cd) %>%
    slice_head(n = 15) %>%
    select(language, n, pct) %>%
    print()
}


# =============================================================================
# 9. MOST COMMON PROGRAMMING LANGUAGES
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("MOST COMMON PROGRAMMING LANGUAGES\n")
cat(strrep("=", 60), "\n")

# Parse SDK_prog_lang_list, BUG_prog_lang_list, and GIT_prog_lang_list
sdk_prog_parsed <- parse_lang_list(plat_df, "SDK_prog_lang_list")
bug_prog_parsed <- parse_lang_list(plat_df, "BUG_prog_lang_list")
git_prog_parsed <- parse_lang_list(plat_df, "GIT_prog_lang_list")

# GIT_prog_lang should be identical between coders (deterministic)
# SDK_prog_lang and BUG_prog_lang are independently coded
cat("\n--- Top SDK Programming Languages (by coder) ---\n")
sdk_prog_freq <- sdk_prog_parsed %>%
  count(coder, language, sort = TRUE) %>%
  group_by(coder) %>%
  slice_head(n = 10) %>%
  ungroup()
print(sdk_prog_freq, n = 30)

cat("\n--- Top BUG Programming Languages (by coder) ---\n")
bug_prog_freq <- bug_prog_parsed %>%
  count(coder, language, sort = TRUE) %>%
  group_by(coder) %>%
  slice_head(n = 10) %>%
  ungroup()
print(bug_prog_freq, n = 30)

cat("\n--- Top GitHub Programming Languages (should be identical) ---\n")
git_prog_freq <- git_prog_parsed %>%
  count(coder, language, sort = TRUE) %>%
  group_by(coder) %>%
  slice_head(n = 10) %>%
  ungroup()
print(git_prog_freq, n = 30)


# =============================================================================
# 10. CODER DISAGREEMENT PATTERNS — WHICH PLATFORMS DIFFER MOST?
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("PLATFORMS WITH LARGEST CODER DISAGREEMENTS\n")
cat(strrep("=", 60), "\n")

# Compute total absolute difference across all nat lang vars
wide_all <- plat_df %>%
  select(platform_id, platform_name, industry, plat, coder,
         all_of(nat_lang_vars), unique_natural_langs) %>%
  pivot_wider(names_from = coder,
              values_from = c(all_of(nat_lang_vars), unique_natural_langs),
              names_sep = "_")

wide_all <- wide_all %>%
  mutate(
    total_abs_diff = rowSums(
      across(ends_with("_Claude"), .names = "{.col}") -
        across(ends_with("_ChatGPT"), .names = "{.col}"),
      na.rm = TRUE
    ) %>% abs(),
    unique_diff = unique_natural_langs_Claude - unique_natural_langs_ChatGPT
  )

# Recompute total_abs_diff correctly
wide_all$total_abs_diff <- 0
for (var in nat_lang_vars) {
  c_col <- paste0(var, "_Claude")
  g_col <- paste0(var, "_ChatGPT")
  wide_all$total_abs_diff <- wide_all$total_abs_diff +
    abs(wide_all[[c_col]] - wide_all[[g_col]])
}

cat("\n--- Top 20 platforms by total language disagreement ---\n")
wide_all %>%
  arrange(desc(total_abs_diff)) %>%
  select(platform_id, platform_name, industry, plat,
         unique_diff, total_abs_diff) %>%
  slice_head(n = 20) %>%
  print(width = Inf)

# Agreement breakdown
cat(sprintf("\nPlatforms with perfect agreement (all nat lang vars): %d / %d (%.1f%%)\n",
            sum(wide_all$total_abs_diff == 0),
            nrow(wide_all),
            sum(wide_all$total_abs_diff == 0) / nrow(wide_all) * 100))
cat(sprintf("Platforms with any disagreement: %d / %d (%.1f%%)\n",
            sum(wide_all$total_abs_diff > 0),
            nrow(wide_all),
            sum(wide_all$total_abs_diff > 0) / nrow(wide_all) * 100))


# =============================================================================
# 11. EXPORT SUMMARY TABLES FOR CHARTS
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("EXPORTING SUMMARY TABLES\n")
cat(strrep("=", 60), "\n")

# CSVs go to FINAL DISSERTATION/tables and charts REVISED (output_tables, set at top)

# Table: Coder agreement on natural language variables
write_csv(nat_agreement, file.path(output_tables, "coder_agreement_nat_lang.csv"))

# Table: Coder agreement on programming language variables
write_csv(prog_agreement, file.path(output_tables, "coder_agreement_prog_lang.csv"))

# Table: Industry summary
write_csv(industry_nat, file.path(output_tables, "industry_nat_lang_summary.csv"))

# Table: Platform type summary
write_csv(plat_type_summary, file.path(output_tables, "plat_type_lang_summary.csv"))

# Table: Top disagreements
write_csv(
  wide_all %>%
    arrange(desc(total_abs_diff)) %>%
    select(platform_id, platform_name, industry, plat,
           unique_natural_langs_Claude, unique_natural_langs_ChatGPT,
           unique_diff, total_abs_diff),
  file.path(output_tables, "language_disagreements_ranked.csv")
)

cat(sprintf("Exported 5 CSV files to %s/\n", output_tables))

# --- 11b. WORD TABLE EXPORT (APA style, matching script 15 format) ---
library(flextable)
library(officer)

apa_style <- function(ft, title_text = NULL, note_text = NULL) {
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

# --- Table LA-1: Coder Agreement on Natural Language Variables ---
ft_nat_agree <- nat_agreement %>%
  rename(
    `Agree %` = Agree_Pct,
    `Mean Diff (C-G)` = Mean_Diff_C_minus_G,
    `SD Diff` = SD_Diff,
    `Claude Higher` = Claude_Higher,
    `ChatGPT Higher` = ChatGPT_Higher,
    r = Correlation
  ) %>%
  flextable() %>%
  apa_style()

# --- Table LA-2: Coder Agreement on Programming Language Variables ---
ft_prog_agree <- prog_agreement %>%
  rename(
    `Agree %` = Agree_Pct,
    `Mean Diff (C-G)` = Mean_Diff_C_minus_G,
    `Claude Higher` = Claude_Higher,
    `ChatGPT Higher` = ChatGPT_Higher,
    r = Correlation
  ) %>%
  flextable() %>%
  apa_style()

# --- Table LA-3: Natural Language Counts by Industry ---
ft_ind_nat <- industry_nat %>%
  rename(
    Industry = industry_label,
    n = n_platforms,
    `Mean Unique` = mean_unique_langs,
    `SD` = sd_unique_langs,
    `% Multilingual` = pct_multilingual,
    `SDK` = mean_SDK_lang,
    `COM` = mean_COM_lang,
    `ROLE` = mean_ROLE_lang,
    `DATA` = mean_DATA_lang
  ) %>%
  select(-industry) %>%
  flextable() %>%
  apa_style()

# --- Table LA-4: Natural Language Counts by Platform Type ---
ft_plat_type <- plat_type_summary %>%
  rename(
    `Platform Type` = plat,
    n = n_platforms,
    `Mean Unique` = mean_unique_langs,
    `SD` = sd_unique_langs,
    `% Multilingual` = pct_multilingual,
    `SDK Nat` = mean_SDK_lang,
    `COM Nat` = mean_COM_lang,
    `SDK Prog` = mean_SDK_prog_lang,
    `BUG Prog` = mean_BUG_prog_lang,
    `GIT Prog` = mean_GIT_prog_lang
  ) %>%
  flextable() %>%
  apa_style()

# --- Table LA-5: Top 20 Platforms by Coder Disagreement ---
ft_disagree <- wide_all %>%
  arrange(desc(total_abs_diff)) %>%
  select(platform_name, industry, plat,
         unique_natural_langs_Claude, unique_natural_langs_ChatGPT,
         total_abs_diff) %>%
  slice_head(n = 20) %>%
  rename(
    Platform = platform_name,
    Industry = industry,
    `PLAT Type` = plat,
    `Unique (Claude)` = unique_natural_langs_Claude,
    `Unique (ChatGPT)` = unique_natural_langs_ChatGPT,
    `Total |Diff|` = total_abs_diff
  ) %>%
  flextable() %>%
  apa_style()

# --- Build Word document ---
doc <- read_docx() %>%
  body_add_par("Language Variable Analysis Tables", style = "heading 1") %>%
  body_add_par("") %>%

  body_add_par("Table LA-1", style = "Normal") %>%
  body_add_par("Coder Agreement on Natural Language Count Variables (PLAT Firms, N = 226)",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_nat_agree) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Exact Agreement = platforms where both coders assigned identical counts. ",
    "Mean Diff = Claude minus ChatGPT (positive = Claude coded higher). ",
    "r = Pearson correlation. SPAN_lang r = NA (ChatGPT coded 0 for all platforms)."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table LA-2", style = "Normal") %>%
  body_add_par("Coder Agreement on Programming Language Count Variables (PLAT Firms, N = 226)",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_prog_agree) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. GIT_prog_lang is deterministic from GitHub augmentation (100% agreement expected). ",
    "SDK_prog_lang and BUG_prog_lang are independently coded by each AI coder."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table LA-3", style = "Normal") %>%
  body_add_par("Natural Language Counts by Industry (Mean Across Coders)",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_ind_nat) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Mean values averaged across Claude and ChatGPT coders for each platform. ",
    "SDK = SDK documentation, COM = community pages, ROLE = role descriptions, DATA = data storage pages."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table LA-4", style = "Normal") %>%
  body_add_par("Language Counts by Platform Access Type",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_plat_type) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. PUBLIC = open access; REGISTRATION = requires account; RESTRICTED = limited access. ",
    "Nat = natural language counts; Prog = programming language counts."
  ), style = "Normal") %>%
  body_add_break() %>%

  body_add_par("Table LA-5", style = "Normal") %>%
  body_add_par("Top 20 Platforms by Total Coder Disagreement on Natural Language Variables",
               style = "Normal") %>%
  body_add_par("") %>%
  body_add_flextable(ft_disagree) %>%
  body_add_par("") %>%
  body_add_par(paste0(
    "Note. Total |Diff| = sum of absolute differences across all 8 natural language ",
    "count variables between Claude and ChatGPT coders."
  ), style = "Normal")

doc_path <- file.path(output_tables, "Language_Analysis_Tables.docx")
print(doc, target = doc_path)
cat(sprintf("Saved Word tables: %s\n", doc_path))

# =============================================================================
# 12. SUMMARY FOR METHODS SECTION
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("SUMMARY FOR METHODS SECTION\n")
cat(strrep("=", 70), "\n")

n_plat <- n_distinct(plat_df$platform_id)

# Compute coder-specific summary stats
claude_plat <- plat_df %>% filter(coder == "Claude")
gpt_plat <- plat_df %>% filter(coder == "ChatGPT")

cat(sprintf("\nDataset: %d PLAT firms coded by two AI coders\n", n_plat))
cat(sprintf("\nClaude found non-zero natural language counts on %d/%d platforms (%.1f%%)\n",
            sum(claude_plat$unique_natural_langs > 0, na.rm = TRUE), n_plat,
            sum(claude_plat$unique_natural_langs > 0, na.rm = TRUE) / n_plat * 100))
cat(sprintf("ChatGPT found non-zero natural language counts on %d/%d platforms (%.1f%%)\n",
            sum(gpt_plat$unique_natural_langs > 0, na.rm = TRUE), n_plat,
            sum(gpt_plat$unique_natural_langs > 0, na.rm = TRUE) / n_plat * 100))

cat(sprintf("\nClaude identified multilingual support on %d platforms (%.1f%%)\n",
            sum(claude_plat$is_multilingual == 1, na.rm = TRUE),
            sum(claude_plat$is_multilingual == 1, na.rm = TRUE) / n_plat * 100))
cat(sprintf("ChatGPT identified multilingual support on %d platforms (%.1f%%)\n",
            sum(gpt_plat$is_multilingual == 1, na.rm = TRUE),
            sum(gpt_plat$is_multilingual == 1, na.rm = TRUE) / n_plat * 100))

# Mean agreement across nat lang vars
cat(sprintf("\nMean exact agreement across 8 natural language count variables: %.1f%%\n",
            mean(nat_agreement$Agree_Pct)))
cat(sprintf("Mean correlation between coders: %.3f\n",
            mean(nat_agreement$Correlation, na.rm = TRUE)))

cat(sprintf("\nMean exact agreement on programming language counts: %.1f%%\n",
            mean(prog_agreement$Agree_Pct)))

cat("\n--- Key Finding ---\n")
cat("Claude systematically codes more languages than ChatGPT,\n")
cat("particularly for natural language counts. This likely reflects\n")
cat("Claude's tendency to infer 'English' support from English-language\n")
cat("portal content, while ChatGPT requires explicit multilingual\n")
cat("documentation to code language support.\n")
cat("\nThis systematic difference supports the decision to have a human\n")
cat("reviewer adjudicate language disagreements before final analysis.\n")


# =============================================================================
# 13. EF EPI GAP × RESOURCE INVESTMENT ANALYSIS
# =============================================================================
# Purpose: Examine whether the English proficiency gap between home and host
# countries predicts differential resource investment patterns.
#
# Key question (from Heather): Is there a pattern where certain resources +
# accessibility are over-invested, driven by the EF EPI gap?
#
# NOTE: EF EPI gap is treated as a signal about investment effort, NOT as a
# proxy for linguistic distance. The framing is: when platforms face larger
# English proficiency gaps in their host markets, where do they concentrate
# boundary resource investment?
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("13. EF EPI GAP × RESOURCE INVESTMENT ANALYSIS\n")
cat(strrep("=", 70), "\n")

# --- 13a. Load codebook for dyad-level analysis ---
codebook_path <- file.path("..", "REFERENCE", "MASTER_CODEBOOK_analytic.xlsx")
if (!file.exists(codebook_path)) {
  codebook_path <- file.path("~", "Dissertation", "REFERENCE", "MASTER_CODEBOOK_analytic.xlsx")
}

if (file.exists(codebook_path)) {
  library(readxl)

  mc <- read_excel(codebook_path)
  cat(sprintf("Loaded codebook: %d rows, %d columns\n", nrow(mc), ncol(mc)))

  # Filter to PLAT firms with both EPI values
  plat_dyads <- mc %>%
    filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
    filter(!is.na(home_ef_epi_rank) & !is.na(host_ef_epi_rank)) %>%
    mutate(
      epi_gap = abs(home_ef_epi_rank - host_ef_epi_rank),
      access_type = ifelse(PLAT == "PUBLIC", "Public", "Private")
    )

  cat(sprintf("PLAT dyads with both EPI values: %d (%d unique platforms)\n",
              nrow(plat_dyads), n_distinct(plat_dyads$platform_ID)))

  # --- 13b. Load adjudicated BR data from JSON ---
  # Since the codebook hasn't been run through the full pipeline,
  # we need to load resource variables from adjudicated JSON files
  adj_dir <- file.path("..", "dissertation_batch_api", "adjudicated_results")
  if (!dir.exists(adj_dir)) {
    adj_dir <- file.path("~", "Dissertation", "dissertation_batch_api", "adjudicated_results")
  }

  library(jsonlite)

  json_files <- list.files(adj_dir, pattern = "\\.json$", full.names = TRUE)
  cat(sprintf("Found %d adjudicated JSON files\n", length(json_files)))

  # Extract BR variables from JSON
  br_data_list <- lapply(json_files, function(f) {
    d <- fromJSON(f, simplifyVector = TRUE)
    pid <- d$platform_id
    plat_type <- d$PLAT

    # Extract individual BR variables
    br_vars <- list()
    for (cat_name in c("application", "development", "ai", "social", "governance")) {
      cat_data <- d[[cat_name]]
      if (is.list(cat_data)) {
        for (vname in names(cat_data)) {
          val <- cat_data[[vname]]
          if (is.numeric(val) || is.logical(val) || is.character(val)) {
            br_vars[[vname]] <- as.numeric(val)
          }
        }
      }
    }

    # Language counts from platform_controls
    pc <- d$platform_controls
    br_vars$AGE <- as.numeric(pc$AGE %||% NA)

    # Parse list lengths for language variety
    parse_len <- function(x) {
      if (is.null(x)) return(0)
      if (is.list(x) || is.vector(x)) return(length(x))
      if (is.character(x)) {
        x <- trimws(x)
        if (x %in% c("", "None", "N/A", "NA", "null", "[]", "0")) return(0)
        tryCatch({
          parsed <- fromJSON(x)
          if (is.vector(parsed)) return(length(parsed))
        }, error = function(e) NULL)
        return(length(strsplit(x, "[,;|]")[[1]]))
      }
      return(0)
    }

    # Natural language lists
    nat_cols <- c("SDK_lang_list", "COM_lang_list", "GIT_lang_list", "SPAN_lang_list",
                  "ROLE_lang_list", "DATA_lang_list", "STORE_lang_list", "CERT_lang_list")

    # Collect all unique natural languages
    all_nat <- c()
    for (col_name in nat_cols) {
      for (cat_name in c("development", "social", "governance")) {
        if (!is.null(d[[cat_name]][[col_name]])) {
          val <- d[[cat_name]][[col_name]]
          all_nat <- c(all_nat, unlist(strsplit(as.character(val), "[,;|]")))
        }
      }
    }
    br_vars$n_nat_lang <- length(unique(trimws(all_nat[all_nat != "" & !is.na(all_nat)])))

    # Programming languages
    prog_cols <- c("SDK_prog_lang_list", "GIT_prog_lang_list")
    all_prog <- c()
    for (col_name in prog_cols) {
      for (cat_name in c("development", "social")) {
        if (!is.null(d[[cat_name]][[col_name]])) {
          val <- d[[cat_name]][[col_name]]
          all_prog <- c(all_prog, unlist(strsplit(as.character(val), "[,;|]")))
        }
      }
    }
    br_vars$n_prog_lang <- length(unique(trimws(all_prog[all_prog != "" & !is.na(all_prog)])))

    br_vars$platform_ID <- pid
    br_vars$PLAT <- plat_type
    return(as.data.frame(br_vars, stringsAsFactors = FALSE))
  })

  br_df <- bind_rows(br_data_list)
  br_plat <- br_df %>% filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"))

  cat(sprintf("BR data extracted for %d PLAT firms\n", nrow(br_plat)))

  # --- 13c. Compute composite resource scores ---
  # Application resources
  app_vars <- c("API", "METH", "DEVP", "DOCS")
  dev_vars <- c("SDK", "BUG", "STAN")
  ai_vars <- c("AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT")
  soc_vars <- c("COM_forum", "COM_blog", "COM_help_support", "COM_live_chat",
                "COM_Slack", "COM_Discord", "COM_stackoverflow", "COM_training",
                "COM_FAQ", "COM_social_media", "GIT", "MON",
                "SPAN_internal", "SPAN_communities", "SPAN_external")
  gov_vars <- c("ROLE", "DATA", "STORE", "CERT")

  safe_rowmean <- function(df, vars) {
    existing <- vars[vars %in% names(df)]
    if (length(existing) == 0) return(rep(NA_real_, nrow(df)))
    rowMeans(df[, existing, drop = FALSE], na.rm = TRUE)
  }

  # Step 1: Convert BR variables to numeric
  br_plat <- br_plat %>%
    mutate(across(any_of(c(app_vars, dev_vars, ai_vars, soc_vars, gov_vars)),
                  ~suppressWarnings(as.numeric(.))))

  # Step 2: Compute composite resource scores
  br_plat$raw_application  <- safe_rowmean(br_plat, app_vars)
  br_plat$raw_development  <- safe_rowmean(br_plat, dev_vars)
  br_plat$raw_ai           <- safe_rowmean(br_plat, ai_vars)
  br_plat$raw_social       <- safe_rowmean(br_plat, soc_vars)
  br_plat$raw_governance   <- with(br_plat, (ROLE + DATA + STORE + CERT) / 4)
  br_plat$total_lang_variety   <- with(br_plat, n_nat_lang + n_prog_lang)
  br_plat$resource_intensity   <- with(br_plat, raw_application + raw_development +
                                         raw_social + raw_governance)

  # --- 13d. Merge BR data into dyad-level data ---
  # Drop columns from codebook that will be replaced by freshly computed BR data
  join_cols <- c("raw_application", "raw_development", "raw_ai",
                 "raw_social", "raw_governance", "resource_intensity",
                 "n_nat_lang", "n_prog_lang", "total_lang_variety", "AGE")
  epi_br <- plat_dyads %>%
    select(-any_of(join_cols)) %>%
    left_join(
      br_plat %>% select(platform_ID, all_of(join_cols)),
      by = "platform_ID"
    )

  cat(sprintf("Merged EPI + BR data: %d dyads\n", nrow(epi_br)))

  # ---------------------------------------------------------------
  # 13e. EF EPI GAP BY PLAT TYPE
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13e. EF EPI GAP BY PLAT TYPE\n")
  cat(strrep("-", 60), "\n")

  epi_by_plat <- epi_br %>%
    group_by(PLAT) %>%
    summarise(
      n_dyads = n(),
      n_platforms = n_distinct(platform_ID),
      mean_gap = mean(epi_gap, na.rm = TRUE),
      median_gap = median(epi_gap, na.rm = TRUE),
      sd_gap = sd(epi_gap, na.rm = TRUE),
      .groups = "drop"
    )
  print(epi_by_plat)

  # ANOVA: EPI gap ~ PLAT type
  aov_plat <- aov(epi_gap ~ PLAT, data = epi_br)
  cat("\nANOVA: EPI gap ~ PLAT type:\n")
  print(summary(aov_plat))

  # ---------------------------------------------------------------
  # 13f. EF EPI GAP BY INDUSTRY
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13f. EF EPI GAP BY INDUSTRY\n")
  cat(strrep("-", 60), "\n")

  epi_by_ind <- epi_br %>%
    group_by(IND) %>%
    summarise(
      n_dyads = n(),
      n_platforms = n_distinct(platform_ID),
      mean_gap = mean(epi_gap, na.rm = TRUE),
      sd_gap = sd(epi_gap, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(mean_gap))
  print(epi_by_ind, width = Inf)

  # ANOVA: EPI gap ~ Industry
  aov_ind <- aov(epi_gap ~ IND, data = epi_br)
  cat("\nANOVA: EPI gap ~ Industry:\n")
  print(summary(aov_ind))

  # ---------------------------------------------------------------
  # 13g. EPI GAP × RESOURCE INVESTMENT
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13g. RESOURCE INVESTMENT PATTERNS BY EPI GAP\n")
  cat(strrep("-", 60), "\n")
  cat("Question: Do platforms facing larger English proficiency gaps\n")
  cat("invest MORE heavily in certain boundary resource categories?\n\n")

  # Tertile split on EPI gap for interpretable groups
  epi_br <- epi_br %>%
    mutate(
      gap_tertile = ntile(epi_gap, 3),
      gap_group = case_when(
        gap_tertile == 1 ~ "Low Gap (T1)",
        gap_tertile == 2 ~ "Medium Gap (T2)",
        gap_tertile == 3 ~ "High Gap (T3)"
      ),
      gap_group = factor(gap_group, levels = c("Low Gap (T1)", "Medium Gap (T2)", "High Gap (T3)"))
    )

  # Resource means by gap tertile
  resource_by_gap <- epi_br %>%
    group_by(gap_group) %>%
    summarise(
      n = n(),
      mean_application = mean(raw_application, na.rm = TRUE),
      mean_development = mean(raw_development, na.rm = TRUE),
      mean_social = mean(raw_social, na.rm = TRUE),
      mean_governance = mean(raw_governance, na.rm = TRUE),
      mean_intensity = mean(resource_intensity, na.rm = TRUE),
      mean_nat_lang = mean(n_nat_lang, na.rm = TRUE),
      mean_prog_lang = mean(n_prog_lang, na.rm = TRUE),
      mean_total_variety = mean(total_lang_variety, na.rm = TRUE),
      .groups = "drop"
    )

  cat("--- Resource Investment by EPI Gap Tertile (Dyad Level) ---\n")
  print(resource_by_gap, width = Inf)

  # ANOVA for each resource category
  cat("\n--- ANOVA Tests: Resource ~ EPI Gap Tertile ---\n")
  resource_cols <- c("raw_application", "raw_development", "raw_social",
                     "raw_governance", "resource_intensity",
                     "n_nat_lang", "n_prog_lang", "total_lang_variety")
  resource_labels <- c("Application", "Development", "Social", "Governance",
                       "Total Intensity", "Natural Lang Variety",
                       "Prog Lang Variety", "Total Lang Variety")

  anova_results <- data.frame(
    Resource = character(), F_stat = numeric(), p_value = numeric(),
    sig = character(), stringsAsFactors = FALSE
  )

  for (i in seq_along(resource_cols)) {
    formula_str <- paste(resource_cols[i], "~ gap_group")
    aov_res <- tryCatch(
      aov(as.formula(formula_str), data = epi_br),
      error = function(e) NULL
    )
    if (!is.null(aov_res)) {
      s <- summary(aov_res)[[1]]
      f_val <- s$`F value`[1]
      p_val <- s$`Pr(>F)`[1]
      sig <- ifelse(p_val < .001, "***",
             ifelse(p_val < .01, "**",
             ifelse(p_val < .05, "*", "ns")))
      anova_results <- rbind(anova_results, data.frame(
        Resource = resource_labels[i], F_stat = round(f_val, 3),
        p_value = round(p_val, 4), sig = sig
      ))
    }
  }
  print(anova_results)

  # ---------------------------------------------------------------
  # 13h. EPI GAP × PLAT TYPE INTERACTION ON RESOURCES
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13h. EPI GAP × PLAT TYPE INTERACTION\n")
  cat(strrep("-", 60), "\n")
  cat("Does the relationship between EPI gap and resource investment\n")
  cat("differ by platform access type?\n\n")

  resource_by_gap_plat <- epi_br %>%
    group_by(gap_group, access_type) %>%
    summarise(
      n = n(),
      application = mean(raw_application, na.rm = TRUE),
      development = mean(raw_development, na.rm = TRUE),
      social = mean(raw_social, na.rm = TRUE),
      governance = mean(raw_governance, na.rm = TRUE),
      intensity = mean(resource_intensity, na.rm = TRUE),
      nat_lang = mean(n_nat_lang, na.rm = TRUE),
      prog_lang = mean(n_prog_lang, na.rm = TRUE),
      total_variety = mean(total_lang_variety, na.rm = TRUE),
      .groups = "drop"
    )

  cat("--- Resource Investment by EPI Gap Tertile × Access Type ---\n")
  print(resource_by_gap_plat, width = Inf)

  # Two-way ANOVA: resource ~ gap_group * access_type
  cat("\n--- Two-Way ANOVA: Resource ~ Gap × Access Type ---\n")
  for (i in seq_along(resource_cols)) {
    formula_str <- paste(resource_cols[i], "~ gap_group * access_type")
    aov_res <- tryCatch(
      aov(as.formula(formula_str), data = epi_br),
      error = function(e) NULL
    )
    if (!is.null(aov_res)) {
      s <- summary(aov_res)[[1]]
      # Interaction term is row 3
      if (nrow(s) >= 3) {
        f_int <- s$`F value`[3]
        p_int <- s$`Pr(>F)`[3]
        sig <- ifelse(p_int < .001, "***",
               ifelse(p_int < .01, "**",
               ifelse(p_int < .05, "*", "ns")))
        cat(sprintf("  %-20s  Gap×Access interaction: F=%6.3f  p=%6.4f %s\n",
                    resource_labels[i], f_int, p_int, sig))
      }
    }
  }

  # ---------------------------------------------------------------
  # 13i. EPI GAP × INDUSTRY INTERACTION ON RESOURCES
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13i. EPI GAP × INDUSTRY: RESOURCE INVESTMENT PATTERNS\n")
  cat(strrep("-", 60), "\n")

  resource_by_gap_ind <- epi_br %>%
    group_by(gap_group, IND) %>%
    summarise(
      n = n(),
      social = mean(raw_social, na.rm = TRUE),
      governance = mean(raw_governance, na.rm = TRUE),
      intensity = mean(resource_intensity, na.rm = TRUE),
      total_variety = mean(total_lang_variety, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(IND, gap_group)

  cat("--- Social & Governance Investment by Gap × Industry ---\n")
  print(resource_by_gap_ind, width = Inf, n = 50)

  # Two-way ANOVA: resource ~ gap_group * IND
  cat("\n--- Two-Way ANOVA: Resource ~ Gap × Industry ---\n")
  for (i in seq_along(resource_cols)) {
    formula_str <- paste(resource_cols[i], "~ gap_group * IND")
    aov_res <- tryCatch(
      aov(as.formula(formula_str), data = epi_br),
      error = function(e) NULL
    )
    if (!is.null(aov_res)) {
      s <- summary(aov_res)[[1]]
      if (nrow(s) >= 3) {
        f_int <- s$`F value`[3]
        p_int <- s$`Pr(>F)`[3]
        sig <- ifelse(p_int < .001, "***",
               ifelse(p_int < .01, "**",
               ifelse(p_int < .05, "*", "ns")))
        cat(sprintf("  %-20s  Gap×IND interaction: F=%6.3f  p=%6.4f %s\n",
                    resource_labels[i], f_int, p_int, sig))
      }
    }
  }

  # ---------------------------------------------------------------
  # 13j. LANGUAGE VARIETY COMBINATION × OBSERVABLE RESOURCE DENSITY
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13j. LANGUAGE VARIETY COMBINATION × OBSERVABLE RESOURCE DENSITY\n")
  cat(strrep("-", 60), "\n")
  cat("The combination of natural language + programming language variety\n")
  cat("as a marker of publicly visible resource breadth.\n\n")

  # Classify platforms by observable language breadth
  epi_br <- epi_br %>%
    mutate(
      nat_high = n_nat_lang > median(n_nat_lang, na.rm = TRUE),
      prog_high = n_prog_lang > median(n_prog_lang, na.rm = TRUE),
      lang_quad = case_when(
        nat_high & prog_high ~ "High Both",
        nat_high & !prog_high ~ "High Nat Only",
        !nat_high & prog_high ~ "High Prog Only",
        TRUE ~ "Low Both"
      ),
      lang_quad = factor(lang_quad,
        levels = c("Low Both", "High Nat Only", "High Prog Only", "High Both"))
    )

  lang_quad_resources <- epi_br %>%
    group_by(lang_quad) %>%
    summarise(
      n = n(),
      n_platforms = n_distinct(platform_ID),
      mean_gap = mean(epi_gap, na.rm = TRUE),
      application = mean(raw_application, na.rm = TRUE),
      development = mean(raw_development, na.rm = TRUE),
      social = mean(raw_social, na.rm = TRUE),
      governance = mean(raw_governance, na.rm = TRUE),
      intensity = mean(resource_intensity, na.rm = TRUE),
      .groups = "drop"
    )

  cat("--- Resource Profiles by Language Variety Quadrant ---\n")
  print(lang_quad_resources, width = Inf)

  # Are high-variety platforms facing larger EPI gaps?
  cat("\n--- ANOVA: EPI Gap ~ Language Variety Quadrant ---\n")
  aov_gap_quad <- aov(epi_gap ~ lang_quad, data = epi_br)
  print(summary(aov_gap_quad))

  # ---------------------------------------------------------------
  # 13k. THE KEY QUESTION: RESOURCE VISIBILITY × ACCESSIBILITY BY GAP
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13k. RESOURCE VISIBILITY × ACCESSIBILITY BY EPI GAP\n")
  cat(strrep("-", 60), "\n")
  cat("Is there a pattern where certain resource categories show\n")
  cat("DISPROPORTIONATE visibility (relative to overall intensity)\n")
  cat("in high-gap contexts? This reveals what complementors observe.\n\n")

  # Compute resource "share" (proportion of total intensity)
  epi_br <- epi_br %>%
    mutate(
      share_application = raw_application / pmax(resource_intensity, 0.001),
      share_development = raw_development / pmax(resource_intensity, 0.001),
      share_social = raw_social / pmax(resource_intensity, 0.001),
      share_governance = raw_governance / pmax(resource_intensity, 0.001)
    )

  share_by_gap <- epi_br %>%
    group_by(gap_group) %>%
    summarise(
      n = n(),
      share_app = mean(share_application, na.rm = TRUE),
      share_dev = mean(share_development, na.rm = TRUE),
      share_soc = mean(share_social, na.rm = TRUE),
      share_gov = mean(share_governance, na.rm = TRUE),
      .groups = "drop"
    )

  cat("--- Resource Share (Proportion of Total) by EPI Gap Tertile ---\n")
  print(share_by_gap, width = Inf)

  # Same but crossed with access type
  share_by_gap_access <- epi_br %>%
    group_by(gap_group, access_type) %>%
    summarise(
      n = n(),
      share_app = mean(share_application, na.rm = TRUE),
      share_dev = mean(share_development, na.rm = TRUE),
      share_soc = mean(share_social, na.rm = TRUE),
      share_gov = mean(share_governance, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\n--- Resource Share by Gap Tertile × Access Type ---\n")
  print(share_by_gap_access, width = Inf)

  # ANOVA on shares
  cat("\n--- ANOVA: Resource SHARE ~ Gap Tertile ---\n")
  share_cols <- c("share_application", "share_development",
                  "share_social", "share_governance")
  share_labels <- c("Application Share", "Development Share",
                    "Social Share", "Governance Share")

  for (i in seq_along(share_cols)) {
    aov_res <- tryCatch(
      aov(as.formula(paste(share_cols[i], "~ gap_group")), data = epi_br),
      error = function(e) NULL
    )
    if (!is.null(aov_res)) {
      s <- summary(aov_res)[[1]]
      f_val <- s$`F value`[1]
      p_val <- s$`Pr(>F)`[1]
      sig <- ifelse(p_val < .001, "***",
             ifelse(p_val < .01, "**",
             ifelse(p_val < .05, "*", "ns")))
      cat(sprintf("  %-25s  F=%6.3f  p=%6.4f %s\n",
                  share_labels[i], f_val, p_val, sig))
    }
  }

  # Three-way: share ~ gap * access
  cat("\n--- Two-Way ANOVA: Resource Share ~ Gap × Access Type ---\n")
  for (i in seq_along(share_cols)) {
    aov_res <- tryCatch(
      aov(as.formula(paste(share_cols[i], "~ gap_group * access_type")), data = epi_br),
      error = function(e) NULL
    )
    if (!is.null(aov_res)) {
      s <- summary(aov_res)[[1]]
      if (nrow(s) >= 3) {
        f_int <- s$`F value`[3]
        p_int <- s$`Pr(>F)`[3]
        sig <- ifelse(p_int < .001, "***",
               ifelse(p_int < .01, "**",
               ifelse(p_int < .05, "*", "ns")))
        cat(sprintf("  %-25s  Gap×Access: F=%6.3f  p=%6.4f %s\n",
                    share_labels[i], f_int, p_int, sig))
      }
    }
  }

  # ---------------------------------------------------------------
  # 13l. CORRELATIONS: EPI GAP × RESOURCES (continuous)
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13l. CORRELATIONS: EPI GAP × RESOURCE VARIABLES\n")
  cat(strrep("-", 60), "\n")

  cor_vars <- c("raw_application", "raw_development", "raw_social",
                "raw_governance", "resource_intensity",
                "n_nat_lang", "n_prog_lang", "total_lang_variety",
                "share_application", "share_development",
                "share_social", "share_governance")
  cor_labels <- c("Application", "Development", "Social", "Governance",
                  "Total Intensity", "Natural Lang Variety",
                  "Prog Lang Variety", "Total Lang Variety",
                  "Application Share", "Development Share",
                  "Social Share", "Governance Share")

  cat("\n--- Pearson Correlations: EPI gap × Resources (All dyads) ---\n")
  for (i in seq_along(cor_vars)) {
    valid <- complete.cases(epi_br[, c("epi_gap", cor_vars[i])])
    n_valid <- sum(valid)
    if (n_valid > 30) {
      ct <- cor.test(epi_br$epi_gap[valid], epi_br[[cor_vars[i]]][valid])
      sig <- ifelse(ct$p.value < .001, "***",
             ifelse(ct$p.value < .01, "**",
             ifelse(ct$p.value < .05, "*", "ns")))
      cat(sprintf("  %-25s  r=%7.4f  p=%6.4f %s  (n=%d)\n",
                  cor_labels[i], ct$estimate, ct$p.value, sig, n_valid))
    }
  }

  # By access type
  for (at in c("Public", "Private")) {
    cat(sprintf("\n--- Correlations: EPI gap × Resources (%s only) ---\n", at))
    sub <- epi_br %>% filter(access_type == at)
    for (i in seq_along(cor_vars)) {
      valid <- complete.cases(sub[, c("epi_gap", cor_vars[i])])
      n_valid <- sum(valid)
      if (n_valid > 20) {
        ct <- cor.test(sub$epi_gap[valid], sub[[cor_vars[i]]][valid])
        sig <- ifelse(ct$p.value < .001, "***",
               ifelse(ct$p.value < .01, "**",
               ifelse(ct$p.value < .05, "*", "ns")))
        cat(sprintf("  %-25s  r=%7.4f  p=%6.4f %s  (n=%d)\n",
                    cor_labels[i], ct$estimate, ct$p.value, sig, n_valid))
      }
    }
  }

  # ---------------------------------------------------------------
  # 13m. EXPORT EPI GAP ANALYSIS TABLES
  # ---------------------------------------------------------------
  cat("\n", strrep("-", 60), "\n")
  cat("13m. EXPORTING EPI GAP ANALYSIS TABLES\n")
  cat(strrep("-", 60), "\n")

  # CSVs go to FINAL DISSERTATION/tables and charts REVISED (output_tables, set at top)

  write_csv(resource_by_gap,
            file.path(output_tables, "epi_gap_resource_visibility.csv"))
  write_csv(resource_by_gap_plat,
            file.path(output_tables, "epi_gap_resource_by_access.csv"))
  write_csv(resource_by_gap_ind,
            file.path(output_tables, "epi_gap_resource_by_industry.csv"))
  write_csv(lang_quad_resources,
            file.path(output_tables, "lang_variety_quadrant_resources.csv"))
  write_csv(share_by_gap_access,
            file.path(output_tables, "epi_gap_resource_shares.csv"))

  cat(sprintf("Exported 5 EPI gap CSV files to %s/\n", output_tables))

  # --- 13m.2: WORD TABLES FOR EPI GAP ANALYSIS ---

  # Table EPI-1: Resource Investment by EPI Gap Tertile
  ft_resource_gap <- resource_by_gap %>%
    mutate(across(where(is.numeric) & !matches("^n$"), ~round(., 3))) %>%
    rename(
      `Gap Group` = gap_group,
      `Application` = mean_application,
      `Development` = mean_development,
      `Social` = mean_social,
      `Governance` = mean_governance,
      `Intensity` = mean_intensity,
      `Nat Lang` = mean_nat_lang,
      `Prog Lang` = mean_prog_lang,
      `Total Variety` = mean_total_variety
    ) %>%
    flextable() %>%
    apa_style()

  # Table EPI-2: Resource by Gap × Access Type
  ft_resource_gap_plat <- resource_by_gap_plat %>%
    mutate(across(where(is.numeric) & !matches("^n$"), ~round(., 3))) %>%
    rename(
      `Gap Group` = gap_group,
      `Access` = access_type,
      `App` = application,
      `Dev` = development,
      `Soc` = social,
      `Gov` = governance,
      `Intensity` = intensity,
      `Nat Lang` = nat_lang,
      `Prog Lang` = prog_lang,
      `Variety` = total_variety
    ) %>%
    flextable() %>%
    apa_style()

  # Table EPI-3: Language Variety Quadrant × Resource Density
  ft_lang_quad <- lang_quad_resources %>%
    mutate(across(where(is.numeric) & !matches("^n$|^n_"), ~round(., 3))) %>%
    rename(
      Quadrant = lang_quad,
      `n dyads` = n,
      `n plat` = n_platforms,
      `Mean Gap` = mean_gap,
      `App` = application,
      `Dev` = development,
      `Soc` = social,
      `Gov` = governance,
      `Intensity` = intensity
    ) %>%
    flextable() %>%
    apa_style()

  # Table EPI-4: Resource Shares by Gap × Access
  ft_shares <- share_by_gap_access %>%
    mutate(across(where(is.numeric) & !matches("^n$"), ~round(., 3))) %>%
    rename(
      `Gap Group` = gap_group,
      `Access` = access_type,
      `App Share` = share_app,
      `Dev Share` = share_dev,
      `Soc Share` = share_soc,
      `Gov Share` = share_gov
    ) %>%
    flextable() %>%
    apa_style()

  # Table EPI-5: ANOVA results
  ft_anova <- anova_results %>%
    flextable() %>%
    apa_style()

  # Build EPI Gap Word document
  epi_doc <- read_docx() %>%
    body_add_par("EF EPI Gap × Resource Investment Tables", style = "heading 1") %>%
    body_add_par("") %>%

    body_add_par("Table EPI-1", style = "Normal") %>%
    body_add_par("Mean Resource Investment by EPI Gap Tertile (Dyad Level)",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_resource_gap) %>%
    body_add_par("") %>%
    body_add_par(paste0(
      "Note. EPI Gap tertiles based on absolute difference in EF English Proficiency Index rank ",
      "between home and host countries. Resource scores are composite means of constituent variables."
    ), style = "Normal") %>%
    body_add_break() %>%

    body_add_par("Table EPI-2", style = "Normal") %>%
    body_add_par("Resource Investment by EPI Gap Tertile and Platform Access Type",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_resource_gap_plat) %>%
    body_add_par("") %>%
    body_add_par(paste0(
      "Note. Public = open access developer portals; Private = registration-required ",
      "or restricted portals."
    ), style = "Normal") %>%
    body_add_break() %>%

    body_add_par("Table EPI-3", style = "Normal") %>%
    body_add_par("Resource Profiles by Language Variety Quadrant",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_lang_quad) %>%
    body_add_par("") %>%
    body_add_par(paste0(
      "Note. Quadrants defined by median splits on natural and programming language counts. ",
      "Intensity = sum of application, development, social, and governance composite scores."
    ), style = "Normal") %>%
    body_add_break() %>%

    body_add_par("Table EPI-4", style = "Normal") %>%
    body_add_par("Resource Allocation Shares by EPI Gap Tertile and Access Type",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_shares) %>%
    body_add_par("") %>%
    body_add_par(paste0(
      "Note. Shares represent proportion of total resource intensity attributable to each ",
      "category. Shares sum to approximately 1.0 within each row."
    ), style = "Normal") %>%
    body_add_break() %>%

    body_add_par("Table EPI-5", style = "Normal") %>%
    body_add_par("One-Way ANOVA: Resource Variables by EPI Gap Tertile",
                 style = "Normal") %>%
    body_add_par("") %>%
    body_add_flextable(ft_anova) %>%
    body_add_par("") %>%
    body_add_par(paste0(
      "Note. * p < .05, ** p < .01, *** p < .001. ",
      "Resource variables tested: application, development, social, governance composites, ",
      "total intensity, and language variety counts."
    ), style = "Normal")

  epi_doc_path <- file.path(output_tables, "EPI_Gap_Analysis_Tables.docx")
  print(epi_doc, target = epi_doc_path)
  cat(sprintf("Saved EPI gap Word tables: %s\n", epi_doc_path))

  cat("\n--- KEY INTERPRETATION NOTES ---\n")
  cat("  EF EPI gap = observable proficiency differential, NOT linguistic distance proxy\n")
  cat("  Focus: WHAT do complementors observe on developer portals when\n")
  cat("         the home-host English proficiency gap is larger?\n")
  cat("  Resource SHARE = proportion of total visible intensity → reveals\n")
  cat("         RELATIVE composition of observable resources\n")
  cat("  Language variety quadrant shows whether nat+prog language\n")
  cat("         breadth co-occurs with specific resource density patterns\n")
  cat("  Significant Gap×Access interactions reveal differential\n")
  cat("         observable profiles by platform type for the same challenge\n")

  # ---------------------------------------------------------------
  # 14. VISUALIZATIONS: LANGUAGE VARIETY QUADRANT × RESOURCE DENSITY
  # ---------------------------------------------------------------
  # What complementors OBSERVE: platforms classified by their
  # publicly visible natural + programming language breadth,
  # cross-tabulated with the density of observable boundary resources.
  # ---------------------------------------------------------------
  cat("\n", strrep("=", 60), "\n")
  cat("14. LANGUAGE VARIETY QUADRANT × RESOURCE DENSITY CHARTS\n")
  cat(strrep("=", 60), "\n")

  library(ggplot2)
  library(tidyr)

  # Charts go to same output folder as CSVs and other scripts
  chart_dir <- output_tables

  # --- APA theme for all figures ---
  theme_apa <- theme_minimal(base_family = "Times New Roman", base_size = 11) +
    theme(
      plot.title = element_blank(),         # APA: title goes in figure note, not on plot
      plot.subtitle = element_blank(),
      plot.caption = element_text(size = 9, hjust = 0, face = "plain",
                                  margin = margin(t = 10)),
      axis.title = element_text(size = 11),
      axis.text = element_text(size = 10, color = "black"),
      axis.line = element_line(color = "black", linewidth = 0.5),
      axis.ticks = element_line(color = "black", linewidth = 0.3),
      panel.grid.major.y = element_line(color = "grey85", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_blank(),
      legend.title = element_text(size = 10, face = "bold"),
      legend.text = element_text(size = 9),
      legend.position = "bottom",
      legend.key.size = unit(0.4, "cm"),
      strip.text = element_text(size = 10, face = "bold")
    )

  # APA-friendly grayscale fills (4 resource categories)
  apa_fills <- c("Application" = "grey20", "Development" = "grey45",
                 "Social" = "grey65", "Governance" = "grey85")

  # --- 14a. Faceted bar chart: Each resource category as its own panel ---
  # Faceting makes group comparisons much clearer than dodged bars

  quad_long <- lang_quad_resources %>%
    select(lang_quad, n_platforms, application, development, social, governance) %>%
    pivot_longer(
      cols = c(application, development, social, governance),
      names_to = "resource",
      values_to = "mean_density"
    ) %>%
    mutate(
      resource = factor(str_to_title(resource),
                        levels = c("Application", "Development", "Social", "Governance")),
      quad_short = case_when(
        lang_quad == "Low Both"       ~ "Low Both",
        lang_quad == "High Nat Only"  ~ "High Nat",
        lang_quad == "High Prog Only" ~ "High Prog",
        lang_quad == "High Both"      ~ "High Both",
        TRUE ~ as.character(lang_quad)
      )
    )

  # Order by total intensity
  quad_intensity_order <- lang_quad_resources %>%
    arrange(intensity) %>%
    mutate(quad_short = case_when(
      lang_quad == "Low Both"       ~ "Low Both",
      lang_quad == "High Nat Only"  ~ "High Nat",
      lang_quad == "High Prog Only" ~ "High Prog",
      lang_quad == "High Both"      ~ "High Both",
      TRUE ~ as.character(lang_quad)
    )) %>%
    pull(quad_short)
  quad_long$quad_short <- factor(quad_long$quad_short, levels = quad_intensity_order)

  # Build caption with n per group
  n_labels <- lang_quad_resources %>%
    mutate(quad_short = case_when(
      lang_quad == "Low Both"       ~ "Low Both",
      lang_quad == "High Nat Only"  ~ "High Nat",
      lang_quad == "High Prog Only" ~ "High Prog",
      lang_quad == "High Both"      ~ "High Both"
    ))
  n_note <- paste(paste0(n_labels$quad_short, " (n = ", n_labels$n_platforms, ")"),
                  collapse = "; ")

  p1 <- ggplot(quad_long, aes(x = quad_short, y = mean_density)) +
    geom_col(fill = "grey35", width = 0.6) +
    geom_text(aes(label = sprintf("%.2f", mean_density)),
              vjust = -0.4, size = 3, family = "Times New Roman") +
    facet_wrap(~ resource, nrow = 1, scales = "free_y") +
    labs(
      x = "Language Variety Quadrant",
      y = "Mean Composite Score",
      caption = paste0(
        "Figure 14a. Mean boundary resource density by language variety quadrant.\n",
        "Quadrants defined by median splits on natural and programming language counts. ",
        n_note, "."
      )
    ) +
    theme_apa +
    theme(axis.text.x = element_text(size = 8, angle = 30, hjust = 1))

  ggsave(file.path(chart_dir, "fig_14a_resource_by_quadrant.png"),
         p1, width = 10, height = 5, dpi = 300)
  cat("Saved: fig_14a_resource_by_quadrant.png\n")

  # --- 14b. Stacked bar: Resource share composition by quadrant ---
  # Shows relative allocation at a glance — easier to compare than a heatmap

  quad_shares <- epi_br %>%
    group_by(lang_quad) %>%
    summarise(
      n = n_distinct(platform_ID),
      Application = mean(share_application, na.rm = TRUE),
      Development = mean(share_development, na.rm = TRUE),
      Social = mean(share_social, na.rm = TRUE),
      Governance = mean(share_governance, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(quad_short = case_when(
      lang_quad == "Low Both"       ~ "Low Both",
      lang_quad == "High Nat Only"  ~ "High Nat",
      lang_quad == "High Prog Only" ~ "High Prog",
      lang_quad == "High Both"      ~ "High Both"
    ))

  quad_shares_long <- quad_shares %>%
    pivot_longer(
      cols = c(Application, Development, Social, Governance),
      names_to = "resource",
      values_to = "share"
    ) %>%
    mutate(
      resource = factor(resource, levels = rev(c("Application", "Development",
                                                 "Social", "Governance")))
    )
  quad_shares_long$quad_short <- factor(quad_shares_long$quad_short,
                                        levels = quad_intensity_order)

  p2 <- ggplot(quad_shares_long, aes(x = quad_short, y = share, fill = resource)) +
    geom_col(width = 0.6, color = "white", linewidth = 0.3) +
    scale_fill_manual(
      values = rev(apa_fills),
      name = "Resource Category",
      breaks = c("Application", "Development", "Social", "Governance")
    ) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.02))) +
    labs(
      x = "Language Variety Quadrant",
      y = "Share of Total Resource Intensity",
      caption = paste0(
        "Figure 14b. Relative resource allocation profile by language variety quadrant.\n",
        "Bars show the proportion of total observable boundary resource intensity attributable to each\n",
        "category. Resource shares sum to 100% within each quadrant."
      )
    ) +
    theme_apa +
    guides(fill = guide_legend(reverse = FALSE, nrow = 1))

  ggsave(file.path(chart_dir, "fig_14b_resource_shares_by_quadrant.png"),
         p2, width = 8, height = 5.5, dpi = 300)
  cat("Saved: fig_14b_resource_shares_by_quadrant.png\n")

  # --- 14c. Paired bar: Total resource intensity with EPI gap side by side ---
  # Two metrics on one chart using dual y-axis simulation via facets

  quad_summary <- lang_quad_resources %>%
    mutate(quad_short = case_when(
      lang_quad == "Low Both"       ~ "Low Both",
      lang_quad == "High Nat Only"  ~ "High Nat",
      lang_quad == "High Prog Only" ~ "High Prog",
      lang_quad == "High Both"      ~ "High Both"
    ))
  quad_summary$quad_short <- factor(quad_summary$quad_short,
                                    levels = quad_intensity_order)

  # Reshape to long: two metrics side by side
  quad_dual <- quad_summary %>%
    select(quad_short, n_platforms, intensity, mean_gap) %>%
    pivot_longer(cols = c(intensity, mean_gap),
                 names_to = "metric", values_to = "value") %>%
    mutate(metric = factor(
      ifelse(metric == "intensity", "Resource Intensity", "Mean EPI Gap"),
      levels = c("Resource Intensity", "Mean EPI Gap")
    ))

  p3 <- ggplot(quad_dual, aes(x = quad_short, y = value)) +
    geom_col(fill = "grey35", width = 0.55) +
    geom_text(aes(label = sprintf("%.1f", value)),
              vjust = -0.4, size = 3.2, family = "Times New Roman") +
    facet_wrap(~ metric, scales = "free_y", nrow = 1) +
    labs(
      x = "Language Variety Quadrant",
      y = "",
      caption = paste0(
        "Figure 14c. Total resource intensity and mean EPI gap by language variety quadrant.\n",
        "Resource Intensity = sum of application, development, social, and governance composite scores.\n",
        "EPI Gap = absolute difference in EF English Proficiency Index rank between home and host countries.\n",
        n_note, "."
      )
    ) +
    theme_apa

  ggsave(file.path(chart_dir, "fig_14c_intensity_and_gap.png"),
         p3, width = 9, height = 5, dpi = 300)
  cat("Saved: fig_14c_intensity_and_gap.png\n")

  # --- 14d. Faceted by access type: Resource density comparison ---
  # One panel per resource, bars grouped by Public vs Private within each quadrant

  quad_by_access <- epi_br %>%
    group_by(lang_quad, access_type) %>%
    summarise(
      n = n_distinct(platform_ID),
      Application = mean(raw_application, na.rm = TRUE),
      Development = mean(raw_development, na.rm = TRUE),
      Social = mean(raw_social, na.rm = TRUE),
      Governance = mean(raw_governance, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(n >= 3) %>%
    mutate(quad_short = case_when(
      lang_quad == "Low Both"       ~ "Low Both",
      lang_quad == "High Nat Only"  ~ "High Nat",
      lang_quad == "High Prog Only" ~ "High Prog",
      lang_quad == "High Both"      ~ "High Both"
    ))
  quad_by_access$quad_short <- factor(quad_by_access$quad_short,
                                      levels = quad_intensity_order)

  quad_access_long <- quad_by_access %>%
    pivot_longer(
      cols = c(Application, Development, Social, Governance),
      names_to = "resource",
      values_to = "mean_density"
    ) %>%
    mutate(resource = factor(resource,
                             levels = c("Application", "Development",
                                        "Social", "Governance")))

  p4 <- ggplot(quad_access_long,
               aes(x = quad_short, y = mean_density, fill = access_type)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6,
             color = "black", linewidth = 0.2) +
    facet_wrap(~ resource, nrow = 1, scales = "free_y") +
    scale_fill_manual(
      values = c("Public" = "grey30", "Private" = "grey75"),
      name = "Access Type"
    ) +
    labs(
      x = "Language Variety Quadrant",
      y = "Mean Resource Density",
      caption = paste0(
        "Figure 14d. Boundary resource density by language variety quadrant and platform access type.\n",
        "Public = open access developer portals; Private = registration-required or restricted portals.\n",
        "Only quadrant-access combinations with n >= 3 platforms are shown."
      )
    ) +
    theme_apa +
    theme(axis.text.x = element_text(size = 8, angle = 30, hjust = 1)) +
    guides(fill = guide_legend(nrow = 1))

  ggsave(file.path(chart_dir, "fig_14d_resource_by_quadrant_access.png"),
         p4, width = 11, height = 5, dpi = 300)
  cat("Saved: fig_14d_resource_by_quadrant_access.png\n")

  cat("\n--- All 4 language variety quadrant charts saved to tables and charts REVISED/ ---\n")

} else {
  cat("WARNING: Could not find MASTER_CODEBOOK.xlsx\n")
  cat("Skipping EPI gap analysis. Ensure codebook is in REFERENCE/ folder.\n")
}
