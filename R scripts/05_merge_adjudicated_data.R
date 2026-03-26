# ============================================================================
# 05 - MERGE ADJUDICATED AI-CODED DATA INTO MASTER_CODEBOOK
# ============================================================================
# Author: Heather Carle
# Purpose: Read 903 adjudicated JSON files (Claude primary coder, ChatGPT
#          validation, language adjudication applied) and populate the
#          resource variable columns in MASTER_CODEBOOK_analytic.xlsx
# Input:   MASTER_CODEBOOK_analytic.xlsx (from script 03)
#          adjudicated_results/*.json (903 files)
# Output:  MASTER_CODEBOOK_analytic.xlsx (updated with resource variables)
# Last Updated: February 2026
#
# NOTES:
#   - BRs are time-invariant: each platform_ID gets ONE set of resource values
#     that is replicated across all its dyads
#   - JSON structure: variables are nested inside category dicts
#     (application, development, ai, social, governance)
#   - Language variables were adjudicated using union rule (English-only = 1)
#   - Non-language variables: Claude primary, ChatGPT validation (upgrade rule)
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(jsonlite)
library(writexl)

# ============================================================================
# SECTION 2: FILE PATHS
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"

# Input codebook (from script 03 or 04)
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")

# Adjudicated JSON results directory
adj_dir <- file.path(base_path, "dissertation_batch_api",
                     "adjudicated_results")

# ============================================================================
# SECTION 3: DEFINE VARIABLE EXTRACTION MAP
# ============================================================================

# Maps: JSON nested key → variable name in codebook
# Format: list(category = c(var1, var2, ...))

var_map <- list(
  application = c(
    "API", "METH", "METH_list"
  ),
  development = c(
    "DEVP", "DOCS", "SDK",
    "SDK_lang", "SDK_lang_list",
    "SDK_prog_lang", "SDK_prog_lang_list",
    "BUG", "BUG_types", "BUG_prog_lang_list", "BUG_prog_lang",
    "STAN", "STAN_list"
  ),
  ai = c(
    "AI_MODEL", "AI_MODEL_types",
    "AI_AGENT", "AI_AGENT_platforms",
    "AI_ASSIST", "AI_ASSIST_tools",
    "AI_DATA", "AI_DATA_protocols",
    "AI_MKT", "AI_MKT_type"
  ),
  social = c(
    "COM_lang", "COM_lang_list",
    "COM_social_media", "COM_forum", "COM_blog",
    "COM_help_support", "COM_live_chat",
    "COM_Slack", "COM_Discord", "COM_stackoverflow",
    "COM_training", "COM_FAQ",
    "GIT", "GIT_url",
    "GIT_lang", "GIT_lang_list",
    "GIT_prog_lang", "GIT_prog_lang_list",
    "MON",
    "EVENT", "EVENT_webinars", "EVENT_virtual",
    "EVENT_in_person", "EVENT_conference", "EVENT_hackathon",
    "EVENT_other", "EVENT_countries",
    "SPAN", "SPAN_internal", "SPAN_communities", "SPAN_external",
    "SPAN_lang", "SPAN_lang_list", "SPAN_countries"
  ),
  governance = c(
    "ROLE", "ROLE_lang", "ROLE_lang_list",
    "DATA", "DATA_lang", "DATA_lang_list",
    "STORE", "STORE_lang", "STORE_lang_list",
    "CERT", "CERT_lang", "CERT_lang_list"
  )
)

# Also extract flat-level fields
flat_vars <- c("PLAT", "PLAT_Notes")

# Build complete list of variables we'll populate
all_coded_vars <- unlist(var_map, use.names = FALSE)

cat("Variables to populate:", length(all_coded_vars), "\n")

# ============================================================================
# SECTION 4: LOAD CODEBOOK
# ============================================================================

cat("\nLoading analytic codebook...\n")
mc <- read_excel(codebook_path)
cat("  Rows:", nrow(mc), "  Columns:", ncol(mc), "\n")
cat("  Unique platform_IDs:", n_distinct(mc$platform_ID), "\n\n")

# ============================================================================
# SECTION 5: READ ALL ADJUDICATED JSONs INTO PLATFORM-LEVEL TABLE
# ============================================================================

cat("=== READING ADJUDICATED JSON FILES ===\n\n")

json_files <- list.files(adj_dir, pattern = "_adjudicated\\.json$",
                         full.names = TRUE)
cat("  JSON files found:", length(json_files), "\n")

# Parse each JSON into a flat row
platform_data <- list()

for (f in json_files) {
  d <- fromJSON(f, simplifyVector = FALSE)
  pid <- d$platform_id

  row <- list(platform_ID = pid)

  # Extract nested variables
  for (cat_name in names(var_map)) {
    cat_vars <- var_map[[cat_name]]
    cat_data <- d[[cat_name]]

    for (var in cat_vars) {
      val <- NULL
      if (is.list(cat_data)) {
        val <- cat_data[[var]]
      }
      # Fallback to flat level
      if (is.null(val)) {
        val <- d[[var]]
      }
      # Handle lists (convert to comma-separated string)
      if (is.list(val)) {
        val <- paste(unlist(val), collapse = ", ")
      }
      if (is.null(val)) val <- NA
      row[[var]] <- val
    }
  }

  # Extract flat vars
  for (fv in flat_vars) {
    val <- d[[fv]]
    if (is.null(val)) val <- NA
    row[[paste0("adj_", fv)]] <- val
  }

  # Extract platform controls if present
  if (!is.null(d$platform_controls)) {
    row[["AGE"]] <- d$platform_controls$AGE
    row[["API_YEAR"]] <- d$platform_controls$API_YEAR
  }

  platform_data[[pid]] <- row
}

# Convert to data frame
platform_df <- bind_rows(lapply(platform_data, as_tibble))
cat("  Platforms parsed:", nrow(platform_df), "\n")

# ============================================================================
# SECTION 6: TYPE CONVERSION
# ============================================================================

# Numeric variables (binary + count)
numeric_vars <- c(
  "API", "METH",
  "DEVP", "DOCS", "SDK", "SDK_lang", "SDK_prog_lang",
  "BUG", "STAN",
  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
  "COM_social_media", "COM_forum", "COM_blog", "COM_help_support",
  "COM_live_chat", "COM_Slack", "COM_Discord", "COM_stackoverflow",
  "COM_training", "COM_FAQ",
  "GIT", "GIT_lang", "GIT_prog_lang", "MON",
  "EVENT", "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
  "EVENT_conference", "EVENT_hackathon",
  "SPAN", "SPAN_internal", "SPAN_communities", "SPAN_external",
  "COM_lang",
  "ROLE", "ROLE_lang",
  "DATA", "DATA_lang",
  "STORE", "STORE_lang",
  "CERT", "CERT_lang",
  "AGE"
)

for (v in numeric_vars) {
  if (v %in% colnames(platform_df)) {
    platform_df[[v]] <- suppressWarnings(as.numeric(platform_df[[v]]))
  }
}

# Set NAs to 0 for binary/count variables where platform is PLAT=NONE
# (auto-coded to zero per workflow)
plat_none_mask <- platform_df$adj_PLAT == "NONE"
for (v in numeric_vars) {
  if (v %in% colnames(platform_df)) {
    platform_df[[v]][plat_none_mask & is.na(platform_df[[v]])] <- 0
  }
}

cat("\n  Type conversion complete.\n")

# ============================================================================
# SECTION 7: COMPUTE DERIVED VARIABLES
# ============================================================================

# COM = sum of communication channel binary variables
platform_df <- platform_df %>%
  mutate(
    COM = COM_social_media + COM_forum + COM_blog + COM_help_support +
      COM_live_chat + COM_Slack + COM_Discord + COM_stackoverflow +
      COM_training + COM_FAQ,

    # LINGUISTIC_VARIETY = sum of all 8 natural language counts
    LINGUISTIC_VARIETY = SDK_lang + COM_lang + GIT_lang + SPAN_lang +
      ROLE_lang + DATA_lang + STORE_lang + CERT_lang,

    # BUG_prog_lang = count of programming languages in BUG_prog_lang_list
    BUG_prog_lang = sapply(BUG_prog_lang_list, function(x) {
      if (is.na(x) || trimws(x) == "") return(0L)
      length(unique(trimws(strsplit(as.character(x), ";")[[1]])))
    })
  )

# programming_lang_variety = count of UNIQUE languages across SDK, GIT, and BUG lists
# (union-based, not pmax — avoids double-counting shared languages)
platform_df <- platform_df %>%
  rowwise() %>%
  mutate(
    programming_lang_variety = {
      all_langs <- c(
        if (!is.na(SDK_prog_lang_list) && trimws(SDK_prog_lang_list) != "")
          trimws(strsplit(as.character(SDK_prog_lang_list), ";")[[1]]) else character(0),
        if (!is.na(GIT_prog_lang_list) && trimws(GIT_prog_lang_list) != "")
          trimws(strsplit(as.character(GIT_prog_lang_list), ";")[[1]]) else character(0),
        if (!is.na(BUG_prog_lang_list) && trimws(BUG_prog_lang_list) != "")
          trimws(strsplit(as.character(BUG_prog_lang_list), ";")[[1]]) else character(0)
      )
      all_langs <- all_langs[all_langs != ""]
      length(unique(all_langs))
    }
  ) %>%
  ungroup()

cat("  Computed: COM, LINGUISTIC_VARIETY, BUG_prog_lang, programming_lang_variety\n")
cat("  programming_lang_variety now uses union of SDK + GIT + BUG lists\n")

# ============================================================================
# SECTION 8: MERGE TO CODEBOOK
# ============================================================================

cat("\n=== MERGING TO MASTER_CODEBOOK ===\n\n")

# Variables to merge (only those that exist in both codebook and platform_df)
codebook_resource_cols <- intersect(colnames(mc), colnames(platform_df))
codebook_resource_cols <- setdiff(codebook_resource_cols, "platform_ID")

cat("  Columns to update:", length(codebook_resource_cols), "\n")
cat("  ", paste(codebook_resource_cols[1:10], collapse = ", "), "...\n\n")

# Clear existing resource data in codebook (will be replaced)
for (col in codebook_resource_cols) {
  mc[[col]] <- NULL
}

# Also add new computed columns if they don't exist
new_cols <- c("LINGUISTIC_VARIETY", "programming_lang_variety")
for (col in new_cols) {
  if (!col %in% colnames(mc) && col %in% colnames(platform_df)) {
    # Will be added via join
  }
}

# Select columns to merge from platform_df
merge_cols <- c("platform_ID", codebook_resource_cols,
                intersect(new_cols, colnames(platform_df)))
merge_cols <- unique(merge_cols)

# Merge: each platform_ID maps to all its dyads
mc <- mc %>%
  left_join(
    platform_df %>% select(any_of(merge_cols)),
    by = "platform_ID"
  )

# ============================================================================
# SECTION 9: DIAGNOSTICS
# ============================================================================

cat("=== MERGE DIAGNOSTICS ===\n\n")

# Check fill rates for key variables
key_vars <- c("API", "DEVP", "SDK", "AI_MODEL", "COM", "GIT",
              "ROLE", "DATA", "PLAT", "LINGUISTIC_VARIETY",
              "programming_lang_variety")

for (v in key_vars) {
  if (v %in% colnames(mc)) {
    n_filled <- sum(!is.na(mc[[v]]))
    pct <- round(100 * n_filled / nrow(mc), 1)
    cat(sprintf("  %-30s %d/%d (%.1f%%)\n", v, n_filled, nrow(mc), pct))
  }
}

# Check that PLAT firms have non-zero resources
cat("\n=== PLAT FIRM RESOURCE CHECK ===\n")
plat_check <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  group_by(PLAT) %>%
  summarize(
    n_dyads = n(),
    n_platforms = n_distinct(platform_ID),
    mean_API = mean(API, na.rm = TRUE),
    mean_SDK = mean(SDK, na.rm = TRUE),
    mean_COM = mean(COM, na.rm = TRUE),
    mean_GIT = mean(as.numeric(GIT), na.rm = TRUE),
    .groups = "drop"
  )
print(plat_check)

# Verify non-platform firms are zeroed
cat("\n=== NON-PLATFORM FIRM CHECK (should be ~0) ===\n")
none_check <- mc %>%
  filter(PLAT == "NONE") %>%
  summarize(
    mean_API  = mean(API, na.rm = TRUE),
    mean_SDK  = mean(SDK, na.rm = TRUE),
    mean_COM  = mean(COM, na.rm = TRUE),
    mean_DEVP = mean(DEVP, na.rm = TRUE)
  )
print(none_check)

# ============================================================================
# SECTION 10: SAVE
# ============================================================================

write_xlsx(mc, codebook_path)
cat("\n✓ Saved updated codebook to:", codebook_path, "\n")
cat("  ", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "platforms\n")
cat("  Resource variables populated from adjudicated JSON files.\n")

cat("\n✓ Script 05 complete.\n")
cat("  Next: Run 06_composite_scores.R to compute Z-scores and composites.\n")
