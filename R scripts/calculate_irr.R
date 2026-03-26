# =============================================================================
# Inter-Rater Reliability Analysis — Full Dataset
# =============================================================================
# Reproduces the IRR table from irr_calculator.py using R
# Updated: February 20, 2026
#
# Dataset: 903 platforms (242 PLAT firms + 661 auto-zeroed)
# Coders: Claude (Anthropic) vs ChatGPT (OpenAI)
# Codebook: v2.1
#
# Variables: 45 total
#   35 binary (presence/absence 0/1)
#   10 count (METH ordinal 0-2, 8 natural language counts, 1 prog lang count)
#
# Excluded from IRR:
#   LINGUISTIC_VARIETY, programming_lang_variety — computed in final analysis
#   GIT_prog_lang — deterministic from GitHub augmentation (100% agreement)
#   home_primary_lang — coded separately, not adjudicated in IRR sample
# =============================================================================

library(tidyverse)
library(irr)       # kappa2, kripp.alpha
library(psych)     # ICC
library(jsonlite)

# =============================================================================
# CONFIGURATION
# =============================================================================

base_path <- "../dissertation_batch_api"
claude_dir <- file.path(base_path, "claude_results")
chatgpt_dir <- file.path(base_path, "chatgpt_results")
output_dir <- file.path(base_path, "irr_analysis")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Variable definitions matching irr_calculator.py exactly
binary_vars <- c(
  "DEVP", "DOCS", "SDK", "BUG", "STAN",
  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
  "GIT", "MON",
  "API",           # Changed from count to binary in codebook v2.1
  "ROLE", "DATA", "STORE", "CERT",
  "COM_social_media", "COM_forum", "COM_blog", "COM_help_support",
  "COM_live_chat", "COM_Slack", "COM_Discord", "COM_stackoverflow",
  "COM_training", "COM_FAQ",
  "EVENT_webinars", "EVENT_virtual", "EVENT_in_person",
  "EVENT_conference", "EVENT_hackathon",
  "SPAN_internal", "SPAN_communities", "SPAN_external"
)

count_vars <- c(
  "METH",
  # Natural language counts (independently coded)
  "SDK_lang", "COM_lang", "GIT_lang", "SPAN_lang",
  "ROLE_lang", "DATA_lang", "STORE_lang", "CERT_lang",
  # Programming language count (independently coded)
  "SDK_prog_lang"
)

all_vars <- c(binary_vars, count_vars)
cat(sprintf("Variables: %d binary + %d count = %d total\n",
            length(binary_vars), length(count_vars), length(all_vars)))

# =============================================================================
# LOAD JSON RESULTS
# =============================================================================

load_coder_results <- function(results_dir, coder_label) {
  json_files <- list.files(results_dir, pattern = "\\.json$", full.names = TRUE)
  json_files <- json_files[!grepl("summary", json_files)]

  results_list <- lapply(json_files, function(f) {
    tryCatch({
      data <- fromJSON(f, simplifyVector = FALSE)
      pid <- data$platform_id %||% data$platform_ID
      if (is.null(pid)) return(NULL)

      # Flatten nested categories
      flat <- list(platform_id = pid)
      for (cat_name in names(data)) {
        cat_data <- data[[cat_name]]
        if (is.list(cat_data) && !cat_name %in% c("metadata")) {
          for (var_name in names(cat_data)) {
            flat[[var_name]] <- cat_data[[var_name]]
          }
        }
      }
      flat
    }, error = function(e) NULL)
  })

  results_list <- results_list[!sapply(results_list, is.null)]

  # Convert to dataframe
  df <- bind_rows(lapply(results_list, function(r) {
    row <- tibble(platform_id = as.character(r$platform_id))
    for (var in all_vars) {
      val <- r[[var]]
      row[[var]] <- if (is.null(val) || length(val) == 0) NA_real_ else as.numeric(val)
    }
    row
  }))

  return(df)
}

cat("Loading results...\n")
claude_df <- load_coder_results(claude_dir, "Claude")
chatgpt_df <- load_coder_results(chatgpt_dir, "ChatGPT")
cat(sprintf("  Claude: %d platforms\n  ChatGPT: %d platforms\n", nrow(claude_df), nrow(chatgpt_df)))

# =============================================================================
# GWET'S AC1 (Primary metric — prevalence-resistant)
# =============================================================================

gwet_ac1 <- function(x, y) {
  tab <- table(factor(x, levels = c(0, 1)), factor(y, levels = c(0, 1)))
  n <- sum(tab)
  if (n == 0) return(NA_real_)
  pa <- sum(diag(tab)) / n
  pi_bar <- ((tab[1,1] + tab[1,2])/n + (tab[1,1] + tab[2,1])/n) / 2
  pe <- 2 * pi_bar * (1 - pi_bar)
  if (pe >= 1) return(NA_real_)
  return((pa - pe) / (1 - pe))
}

# =============================================================================
# CALCULATE IRR FOR EACH VARIABLE
# =============================================================================

merged <- inner_join(
  claude_df %>% select(platform_id, all_of(all_vars)),
  chatgpt_df %>% select(platform_id, all_of(all_vars)),
  by = "platform_id", suffix = c("_c", "_g")
)
cat(sprintf("\nPlatforms compared: %d\n", nrow(merged)))

irr_results <- map_dfr(all_vars, function(var) {
  v1 <- merged[[paste0(var, "_c")]]
  v2 <- merged[[paste0(var, "_g")]]
  valid <- !is.na(v1) & !is.na(v2)
  v1 <- v1[valid]; v2 <- v2[valid]; n <- length(v1)
  var_type <- if (var %in% binary_vars) "binary" else "count"

  agree_pct <- (sum(v1 == v2) / n) * 100
  disagreements <- sum(v1 != v2)

  ac1 <- if (var_type == "binary") tryCatch(gwet_ac1(v1, v2), error = function(e) NA_real_) else NA_real_

  kr_alpha <- tryCatch({
    kripp.alpha(rbind(v1, v2), method = if (var_type == "binary") "nominal" else "interval")$value
  }, error = function(e) NA_real_)

  kappa_val <- if (var_type == "binary") {
    tryCatch(kappa2(data.frame(v1, v2))$value, error = function(e) NA_real_)
  } else NA_real_

  icc_val <- if (var_type == "count") {
    tryCatch(ICC(data.frame(v1, v2))$results$ICC[2], error = function(e) NA_real_)
  } else NA_real_

  tibble(Variable = var, Type = var_type, N = n,
         Agree_Pct = round(agree_pct, 1),
         AC1 = round(ac1, 3), Kr_Alpha = round(kr_alpha, 3),
         Kappa = round(kappa_val, 3), ICC = round(icc_val, 3),
         Disagreements = disagreements)
})

# =============================================================================
# SUMMARY
# =============================================================================

bin_res <- irr_results %>% filter(Type == "binary")
cnt_res <- irr_results %>% filter(Type == "count")

cat(sprintf("\n%s\n", strrep("=", 60)))
cat("IRR RESULTS: Claude vs ChatGPT (Full Dataset)\n")
cat(sprintf("%s\n\n", strrep("=", 60)))
cat(sprintf("Overall Agreement: %.1f%%\n", mean(irr_results$Agree_Pct)))
cat(sprintf("Mean AC1: %.3f (%d binary vars)\n", mean(bin_res$AC1, na.rm = TRUE), sum(!is.na(bin_res$AC1))))
cat(sprintf("Mean Kappa: %.3f\n", mean(bin_res$Kappa, na.rm = TRUE)))
cat(sprintf("Mean Kr-Alpha: %.3f\n", mean(irr_results$Kr_Alpha, na.rm = TRUE)))
cat(sprintf("Mean ICC: %.3f (%d count vars)\n", mean(cnt_res$ICC, na.rm = TRUE), nrow(cnt_res)))

print(irr_results, n = 50)

# =============================================================================
# SAVE
# =============================================================================

write_csv(irr_results, file.path(output_dir, "irr_results_R.csv"))

summary_df <- tibble(
  Metric = c("Overall Agreement", "Mean AC1 (binary)", "Mean Kappa (binary)",
             "Mean Kr-Alpha (all)", "Mean ICC (count)"),
  Value = c(sprintf("%.1f%%", mean(irr_results$Agree_Pct)),
            sprintf("%.3f", mean(bin_res$AC1, na.rm = TRUE)),
            sprintf("%.3f", mean(bin_res$Kappa, na.rm = TRUE)),
            sprintf("%.3f", mean(irr_results$Kr_Alpha, na.rm = TRUE)),
            sprintf("%.3f", mean(cnt_res$ICC, na.rm = TRUE))),
  N_Variables = c(nrow(irr_results), sum(!is.na(bin_res$AC1)),
                  sum(!is.na(bin_res$Kappa)), sum(!is.na(irr_results$Kr_Alpha)),
                  nrow(cnt_res))
)
write_csv(summary_df, file.path(output_dir, "irr_summary_R.csv"))

cat(sprintf("\nSaved: %s/irr_results_R.csv\n", output_dir))
cat(sprintf("Saved: %s/irr_summary_R.csv\n", output_dir))
