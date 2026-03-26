# ============================================================================
# 07 - PCA OF BOUNDARY RESOURCE VARIABLES
# ============================================================================
# Author: Heather Carle
# Purpose: Exploratory PCA on all coded boundary resource variables to
#          evaluate how they load empirically vs. the 5 theoretical categories
#          (Application, Development, AI, Social, Governance).
#
#          KEY FINDINGS (from preliminary Python analysis, N=230 PLAT):
#            - Kaiser criterion → 9 components (eigenvalue > 1)
#            - 5-component varimax rotation → 52.4% variance explained
#            - 56.2% of variables load on their theoretical category
#            - RC1 = Core Platform Infrastructure (App + Dev + Gov blend)
#            - RC2 = Boundary Spanning & AI Services (SPAN + AI_ASSIST/AI_MODEL)
#            - RC3 = AI Agent Integration (AI_AGENT + AI_DATA)
#            - RC4 = Community Ecosystem (Social + SDK/GIT/MON/STORE)
#            - RC5 = Developer Communication Channels (Slack + StackOverflow)
#
#          This script provides evidence for a PCA-aligned composite structure
#          that can be compared against the theory-based 5-category model.
#
# Input:   MASTER_CODEBOOK_analytic.xlsx (from script 06)
# Output:  PCA loadings, scree data, PCA-aligned composite scores
# Last Updated: February 2026
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(psych)       # principal(), fa.parallel(), KMO
library(GPArotation) # Varimax rotation
library(writexl)
library(ggplot2)

# ============================================================================
# SECTION 2: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis REVISED")

mc <- read_excel(codebook_path)

# Platform-level data (one row per PLAT firm)
plat_firms <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")) %>%
  distinct(platform_ID, .keep_all = TRUE)

cat("PLAT firms for PCA:", nrow(plat_firms), "\n\n")

# ============================================================================
# SECTION 3: SELECT VARIABLES FOR PCA
# ============================================================================

# Include all binary/ordinal resource indicators
# Exclude: list variables, URL fields, counts that are sums of sub-items,
# and language variety variables (part of Platform Accessibility mediator)
# (e.g., COM is sum of COM_* so exclude COM to avoid double-counting)
# (e.g., EVENT is sum of EVENT_* sub-types)
# (e.g., SPAN is sum of SPAN_internal + SPAN_communities + SPAN_external)
# (SDK_prog_lang excluded — feeds into programming_lang_variety in mediator)

pca_vars <- c(
  # Application
  "API", "METH",
  # Development
  "DEVP", "DOCS", "SDK", "BUG", "STAN",
  # AI
  "AI_MODEL", "AI_AGENT", "AI_ASSIST", "AI_DATA", "AI_MKT",
  # Social (individual indicators, not summary COM/EVENT/SPAN)
  "COM_forum", "COM_blog", "COM_help_support", "COM_live_chat",
  "COM_Slack", "COM_Discord", "COM_stackoverflow",
  "COM_training", "COM_FAQ", "COM_social_media",
  "GIT", "MON",
  "SPAN_internal", "SPAN_communities", "SPAN_external",
  # Governance
  "ROLE", "DATA", "STORE", "CERT"
)

# Theoretical category labels for each variable
theory_cat <- c(
  rep("Application", 2),
  rep("Development", 5),
  rep("AI", 5),
  rep("Social", 15),
  rep("Governance", 4)
)
names(theory_cat) <- pca_vars

# Extract and convert to numeric
pca_data <- plat_firms %>%
  select(platform_ID, all_of(pca_vars)) %>%
  mutate(across(-platform_ID, as.numeric))

# Replace NAs with 0 (missing = not present)
pca_data[is.na(pca_data)] <- 0

# Remove zero-variance columns
col_vars <- sapply(pca_data[, -1], stats::var)
zero_var_cols <- names(col_vars[col_vars == 0])
if (length(zero_var_cols) > 0) {
  cat("Removing zero-variance variables:", paste(zero_var_cols, collapse = ", "), "\n")
  pca_data <- pca_data %>% select(-all_of(zero_var_cols))
  pca_vars <- setdiff(pca_vars, zero_var_cols)
}

cat("Variables for PCA:", length(pca_vars), "\n\n")

# ============================================================================
# SECTION 4: ADEQUACY CHECKS
# ============================================================================

cat("=== PCA ADEQUACY ===\n\n")

# KMO measure of sampling adequacy
kmo_result <- KMO(pca_data[, -1])
cat("Kaiser-Meyer-Olkin (KMO):", round(kmo_result$MSA, 3), "\n")
cat("  (> 0.6 = acceptable, > 0.8 = meritorious)\n\n")

# Bartlett's test of sphericity
bart_test <- cortest.bartlett(cor(pca_data[, -1]), n = nrow(pca_data))
cat("Bartlett's test: chi-sq =", round(bart_test$chisq, 1),
    ", df =", bart_test$df,
    ", p =", format.pval(bart_test$p.value, digits = 3), "\n\n")

# ============================================================================
# SECTION 5: PARALLEL ANALYSIS (Determine N components)
# ============================================================================

cat("=== PARALLEL ANALYSIS ===\n")
cat("(Compare actual eigenvalues to random data eigenvalues)\n\n")

set.seed(42)
pa <- fa.parallel(pca_data[, -1], fm = "pa", fa = "pc",
                   n.iter = 100, show.legend = FALSE,
                   main = "")

cat("Suggested number of components:", pa$ncomp, "\n\n")

# Save scree plot to tables and charts folder
scree_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED",
                        "Figure_Scree_Plot.png")
png(scree_path, width = 8, height = 5, units = "in", res = 300)
eigenvalues <- eigen(cor(pca_data[, -1]))$values
plot(1:length(eigenvalues), eigenvalues, type = "b",
     pch = 19, col = "black", lwd = 1.5,
     xlab = "Component Number", ylab = "Eigenvalue",
     main = "", axes = FALSE,
     ylim = c(0, max(eigenvalues) * 1.1))
axis(1, at = 1:length(eigenvalues))
axis(2, las = 1)
abline(h = 1, lty = 2, col = "grey50")
text(length(eigenvalues) * 0.7, 1.15, "Kaiser criterion (eigenvalue = 1)",
     cex = 0.8, col = "grey40")
box()
dev.off()
cat("  Scree plot saved to:", scree_path, "\n")

# ============================================================================
# SECTION 6: PCA WITH VARIMAX ROTATION
# ============================================================================

# Run with 5 components (theory-aligned) for comparison
cat("=== 5-COMPONENT PCA (Theory-Aligned) ===\n\n")

pca5 <- principal(pca_data[, -1], nfactors = 5, rotate = "varimax",
                   scores = TRUE)

cat("Variance explained:", round(sum(pca5$Vaccounted[2, 1:5]) * 100, 1), "%\n\n")
cat("Per component:\n")
for (i in 1:5) {
  cat(sprintf("  RC%d: %.1f%%\n", i,
              pca5$Vaccounted[2, i] * 100))
}

# Loadings matrix
cat("\n--- VARIMAX-ROTATED LOADINGS ---\n")
loadings_df <- as.data.frame(unclass(pca5$loadings))
loadings_df$Variable <- rownames(loadings_df)
loadings_df$Theory <- theory_cat[loadings_df$Variable]
loadings_df$MaxRC <- apply(abs(loadings_df[, 1:5]), 1, which.max)

cat(sprintf("\n%-22s %-12s %7s %7s %7s %7s %7s  Best\n",
            "Variable", "Theory", "RC1", "RC2", "RC3", "RC4", "RC5"))
cat(strrep("-", 85), "\n")
for (i in seq_len(nrow(loadings_df))) {
  cat(sprintf("%-22s %-12s %7.3f %7.3f %7.3f %7.3f %7.3f  RC%d\n",
              loadings_df$Variable[i], loadings_df$Theory[i],
              loadings_df$RC1[i], loadings_df$RC2[i], loadings_df$RC3[i],
              loadings_df$RC4[i], loadings_df$RC5[i],
              loadings_df$MaxRC[i]))
}

# ============================================================================
# SECTION 7: COMPONENT INTERPRETATION
# ============================================================================

cat("\n=== COMPONENT INTERPRETATION (Top 5 Loaders) ===\n\n")

for (rc in 1:5) {
  rc_name <- paste0("RC", rc)
  top5 <- loadings_df %>%
    arrange(desc(abs(!!sym(rc_name)))) %>%
    head(7)

  # Dominant category
  cat_counts <- table(top5$Theory)
  dominant <- names(sort(cat_counts, decreasing = TRUE))[1]

  cat(sprintf("RC%d → Dominant: %s (%d/7 top loaders)\n", rc, dominant,
              max(cat_counts)))
  for (j in seq_len(nrow(top5))) {
    flag <- ifelse(top5$Theory[j] == dominant, "✓", "✗")
    cat(sprintf("  %d. %-22s (%-12s) loading=%7.3f %s\n",
                j, top5$Variable[j], top5$Theory[j],
                top5[[rc_name]][j], flag))
  }
  cat("\n")
}

# ============================================================================
# SECTION 8: CONGRUENCE ANALYSIS
# ============================================================================

cat("=== THEORY-DATA CONGRUENCE ===\n\n")

# Assign each RC to a dominant theoretical category
rc_dominant <- character(5)
for (rc in 1:5) {
  rc_name <- paste0("RC", rc)
  top7 <- loadings_df %>% arrange(desc(abs(!!sym(rc_name)))) %>% head(7)
  rc_dominant[rc] <- names(sort(table(top7$Theory), decreasing = TRUE))[1]
}
names(rc_dominant) <- paste0("RC", 1:5)
cat("RC → Category mapping:\n")
for (i in 1:5) cat(sprintf("  RC%d → %s\n", i, rc_dominant[i]))

# Variable-level congruence
congruent <- 0
mismatches <- list()
for (i in seq_len(nrow(loadings_df))) {
  best_rc <- paste0("RC", loadings_df$MaxRC[i])
  assigned <- rc_dominant[best_rc]
  actual <- loadings_df$Theory[i]
  if (assigned == actual) {
    congruent <- congruent + 1
  } else {
    mismatches[[length(mismatches) + 1]] <- data.frame(
      Variable = loadings_df$Variable[i],
      Theory = actual,
      LoadsOn = best_rc,
      RCCategory = assigned,
      Loading = loadings_df[[best_rc]][i]
    )
  }
}

total <- nrow(loadings_df)
cat(sprintf("\nCongruent: %d/%d (%.1f%%)\n", congruent, total,
            100 * congruent / total))
cat(sprintf("Cross-loading: %d variables\n\n", length(mismatches)))

if (length(mismatches) > 0) {
  mismatch_df <- bind_rows(mismatches)
  print(mismatch_df)
}

# ============================================================================
# SECTION 9: COMPUTE PCA-ALIGNED COMPOSITE SCORES
# ============================================================================

cat("\n=== PCA-ALIGNED COMPOSITE SCORES ===\n\n")

# Based on the PCA results, create empirically-aligned composites
# IMPORTANT: The actual loadings determine which variables go where
# The labels below are PLACEHOLDERS — Heather will assign final labels

# Extract component scores for each platform
scores <- as.data.frame(pca5$scores)
scores$platform_ID <- pca_data$platform_ID
colnames(scores)[1:5] <- paste0("PCA_RC", 1:5)

cat("Component score descriptives (PLAT firms):\n")
scores %>%
  select(starts_with("PCA_")) %>%
  summarize(across(everything(), list(
    mean = ~round(mean(.), 3),
    sd = ~round(sd(.), 3)
  ))) %>%
  pivot_longer(everything(),
               names_to = c("Component", ".value"),
               names_pattern = "(.+)_(.+)") %>%
  print()

# Merge PCA scores back to full codebook
# (Each platform_ID gets its PCA score, replicated across dyads)
# First remove any existing PCA columns from prior runs to avoid .x/.y duplicates
mc <- mc %>%
  select(-any_of(c("PCA_RC1", "PCA_RC2", "PCA_RC3", "PCA_RC4", "PCA_RC5",
                    "PCA_RC1.x", "PCA_RC2.x", "PCA_RC3.x", "PCA_RC4.x", "PCA_RC5.x",
                    "PCA_RC1.y", "PCA_RC2.y", "PCA_RC3.y", "PCA_RC4.y", "PCA_RC5.y",
                    "platform_resources_pca"))) %>%
  left_join(scores %>% select(platform_ID, starts_with("PCA_")),
            by = "platform_ID")

# Also compute PCA-aligned overall composite
mc <- mc %>%
  mutate(
    platform_resources_pca = (PCA_RC1 + PCA_RC2 + PCA_RC3 +
                                PCA_RC4 + PCA_RC5) / 5
  )

# ============================================================================
# SECTION 10: APA WORD TABLE EXPORTS
# ============================================================================

library(flextable)
library(officer)

apa_doc <- read_docx()

# --- Table 1: PCA Adequacy Tests ---
apa_doc <- body_add_par(apa_doc, "Table 1. PCA Adequacy Tests", style = "heading 2")

adequacy_df <- data.frame(
  Test = c("Kaiser-Meyer-Olkin (KMO)", "Bartlett's Test of Sphericity"),
  Statistic = c(
    round(kmo_result$MSA, 3),
    round(bart_test$chisq, 1)
  ),
  df = c("—", bart_test$df),
  p = c("—", ifelse(bart_test$p.value < .001, "< .001",
                     round(bart_test$p.value, 3))),
  Interpretation = c(
    ifelse(kmo_result$MSA >= 0.8, "Meritorious",
           ifelse(kmo_result$MSA >= 0.6, "Acceptable", "Poor")),
    "Significant"
  )
)

ft1 <- flextable(adequacy_df) %>%
  set_header_labels(Test = "Test", Statistic = "Statistic",
                    df = "df", p = "p", Interpretation = "Interpretation") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1, align = "left", part = "body") %>%
  align(j = 2:5, align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

apa_doc <- body_add_flextable(apa_doc, ft1)
apa_doc <- body_add_par(apa_doc, sprintf("Note. N = %d platform firms. %d variables entered into PCA.",
                                          nrow(plat_firms), length(pca_vars)),
                         style = "Normal")
apa_doc <- body_add_par(apa_doc, "", style = "Normal")

# --- Table 2: Variance Explained by Component ---
apa_doc <- body_add_par(apa_doc, "Table 2. Variance Explained by Component (Varimax Rotation)",
                         style = "heading 2")

var_df <- data.frame(
  Component = paste0("RC", 1:5),
  Eigenvalue = round(pca5$values[1:5], 3),
  Variance_Pct = sprintf("%.1f%%", pca5$Vaccounted[2, 1:5] * 100),
  Cumulative_Pct = sprintf("%.1f%%", cumsum(pca5$Vaccounted[2, 1:5]) * 100)
)

ft2 <- flextable(var_df) %>%
  set_header_labels(Component = "Component", Eigenvalue = "Eigenvalue",
                    Variance_Pct = "% Variance", Cumulative_Pct = "Cumulative %") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

apa_doc <- body_add_flextable(apa_doc, ft2)
apa_doc <- body_add_par(apa_doc,
  sprintf("Note. Total variance explained = %.1f%%. Extraction: Principal Component Analysis. Rotation: Varimax with Kaiser normalization.",
          sum(pca5$Vaccounted[2, 1:5]) * 100),
  style = "Normal")
apa_doc <- body_add_par(apa_doc, "", style = "Normal")

# --- Table 2b: Full Eigenvalue Table (All Components) ---
apa_doc <- body_add_par(apa_doc,
  "Table 2b. Eigenvalues and Variance Explained for All Components",
  style = "heading 2")

n_vars <- ncol(pca_data[, -1])
all_eigenvalues <- pca5$values[1:n_vars]
eigen_df <- data.frame(
  Component = 1:n_vars,
  Eigenvalue = round(all_eigenvalues, 3),
  Pct_Variance = sprintf("%.1f%%", (all_eigenvalues / sum(all_eigenvalues)) * 100),
  Cumulative_Pct = sprintf("%.1f%%", cumsum(all_eigenvalues / sum(all_eigenvalues)) * 100)
)

ft2b <- flextable(eigen_df) %>%
  set_header_labels(Component = "Component", Eigenvalue = "Eigenvalue",
                    Pct_Variance = "% Variance", Cumulative_Pct = "Cumulative %") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body") %>%
  bold(i = 1:5, part = "body")  # Bold retained components

apa_doc <- body_add_flextable(apa_doc, ft2b)
apa_doc <- body_add_par(apa_doc,
  "Note. Bold rows indicate retained components (5-component solution). Kaiser criterion (eigenvalue > 1) identified 9 components. Extraction: Principal Component Analysis.",
  style = "Normal")
apa_doc <- body_add_par(apa_doc, "", style = "Normal")

# --- Table 3: Varimax-Rotated Loadings ---
apa_doc <- body_add_par(apa_doc, "Table 3. Varimax-Rotated Component Loadings",
                         style = "heading 2")

loadings_apa <- loadings_df %>%
  select(Variable, Theory, RC1, RC2, RC3, RC4, RC5) %>%
  mutate(across(RC1:RC5, ~round(., 3))) %>%
  arrange(Theory, Variable)

ft3 <- flextable(loadings_apa) %>%
  set_header_labels(Variable = "Variable", Theory = "Theoretical Category",
                    RC1 = "RC1", RC2 = "RC2", RC3 = "RC3",
                    RC4 = "RC4", RC5 = "RC5") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "header") %>%
  align(j = 1:2, align = "left", part = "body") %>%
  align(j = 3:7, align = "center", part = "body") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

# Bold loadings > |.40| for readability
for (rc_col in c("RC1", "RC2", "RC3", "RC4", "RC5")) {
  high_rows <- which(abs(loadings_apa[[rc_col]]) >= 0.40)
  if (length(high_rows) > 0) {
    ft3 <- bold(ft3, i = high_rows, j = rc_col)
  }
}

apa_doc <- body_add_flextable(apa_doc, ft3)
apa_doc <- body_add_par(apa_doc,
  sprintf("Note. N = %d. Loadings |>= .40| shown in bold. Variables sorted by theoretical category.",
          nrow(plat_firms)),
  style = "Normal")
apa_doc <- body_add_par(apa_doc, "", style = "Normal")

# --- Table 4: Component-to-Theory Mapping ---
apa_doc <- body_add_par(apa_doc, "Table 4. Component-to-Theoretical Category Mapping",
                         style = "heading 2")

mapping_df <- data.frame(
  Component = paste0("RC", 1:5),
  Dominant_Category = rc_dominant,
  Variance_Pct = sprintf("%.1f%%", pca5$Vaccounted[2, 1:5] * 100)
)

ft4 <- flextable(mapping_df) %>%
  set_header_labels(Component = "Component",
                    Dominant_Category = "Dominant Theoretical Category",
                    Variance_Pct = "% Variance") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

apa_doc <- body_add_flextable(apa_doc, ft4)
apa_doc <- body_add_par(apa_doc,
  sprintf("Note. Congruent variables: %d/%d (%.1f%%). Dominant category assigned by majority of top-7 loading variables per component.",
          congruent, total, 100 * congruent / total),
  style = "Normal")
apa_doc <- body_add_par(apa_doc, "", style = "Normal")

# --- Table 5: Cross-Loading Variables ---
if (length(mismatches) > 0) {
  apa_doc <- body_add_par(apa_doc, "Table 5. Cross-Loading Variables (Theory-Data Mismatches)",
                           style = "heading 2")

  mismatch_apa <- mismatch_df %>%
    mutate(Loading = round(Loading, 3)) %>%
    select(Variable, Theory, LoadsOn, RCCategory, Loading) %>%
    arrange(Theory, Variable)

  ft5 <- flextable(mismatch_apa) %>%
    set_header_labels(Variable = "Variable",
                      Theory = "Theoretical Category",
                      LoadsOn = "Loads On",
                      RCCategory = "RC Dominant Category",
                      Loading = "Loading") %>%
    fontsize(size = 10, part = "all") %>%
    font(fontname = "Times New Roman", part = "all") %>%
    align(align = "center", part = "header") %>%
    align(j = 1:2, align = "left", part = "body") %>%
    align(j = 3:5, align = "center", part = "body") %>%
    autofit() %>%
    border_remove() %>%
    hline_top(border = fp_border(width = 2), part = "header") %>%
    hline_bottom(border = fp_border(width = 1), part = "header") %>%
    hline_bottom(border = fp_border(width = 2), part = "body")

  apa_doc <- body_add_flextable(apa_doc, ft5)
  apa_doc <- body_add_par(apa_doc,
    "Note. These variables loaded most strongly on a component whose dominant category differs from their theoretical assignment.",
    style = "Normal")
  apa_doc <- body_add_par(apa_doc, "", style = "Normal")
}

# --- Table 6: PCA Component Score Descriptives ---
apa_doc <- body_add_par(apa_doc, "Table 6. PCA Component Score Descriptives (PLAT Firms)",
                         style = "heading 2")

score_desc <- scores %>%
  select(starts_with("PCA_")) %>%
  summarize(across(everything(), list(
    M = ~round(mean(.), 3),
    SD = ~round(sd(.), 3),
    Min = ~round(min(.), 3),
    Max = ~round(max(.), 3)
  ))) %>%
  pivot_longer(everything(),
               names_to = c("Component", ".value"),
               names_pattern = "(.+)_(.+)")

ft6 <- flextable(score_desc) %>%
  set_header_labels(Component = "Component", M = "M", SD = "SD",
                    Min = "Min", Max = "Max") %>%
  fontsize(size = 10, part = "all") %>%
  font(fontname = "Times New Roman", part = "all") %>%
  align(align = "center", part = "all") %>%
  autofit() %>%
  border_remove() %>%
  hline_top(border = fp_border(width = 2), part = "header") %>%
  hline_bottom(border = fp_border(width = 1), part = "header") %>%
  hline_bottom(border = fp_border(width = 2), part = "body")

apa_doc <- body_add_flextable(apa_doc, ft6)
apa_doc <- body_add_par(apa_doc,
  sprintf("Note. N = %d platform firms. Scores derived from 5-component varimax-rotated PCA.",
          nrow(plat_firms)),
  style = "Normal")

# Save Word document
tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")
pca_word_path <- file.path(tables_path, "07_PCA_Tables_APA.docx")
print(apa_doc, target = pca_word_path)
cat("\n✓ APA tables saved to:", pca_word_path, "\n")

# ============================================================================
# SECTION 11: SAVE
# ============================================================================

# Save loadings table
loadings_export <- loadings_df %>%
  select(Variable, Theory, RC1:RC5, MaxRC)
write.csv(loadings_export,
          file.path(output_path, "pca_loadings_varimax_5comp.csv"),
          row.names = FALSE)

# Save PCA scores
write.csv(scores,
          file.path(output_path, "pca_component_scores.csv"),
          row.names = FALSE)

# Save updated codebook
write_xlsx(mc, codebook_path)

cat("\n✓ Script 07 complete.\n")
cat("  Outputs:\n")
cat("    07_PCA_Tables_APA.docx (6 APA tables)\n")
cat("    pca_loadings_varimax_5comp.csv\n")
cat("    pca_component_scores.csv\n")
cat("  PCA_RC1-RC5 and platform_resources_pca added to codebook.\n")
cat("  Next: Run 08 for descriptive statistics, then 09 for SEM.\n")
