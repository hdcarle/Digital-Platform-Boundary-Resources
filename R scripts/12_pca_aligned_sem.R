# ============================================================================
# 12 - PCA-ALIGNED SEM: COMPARE THEORY vs EMPIRICAL STRUCTURE
# ============================================================================
# Author: Heather Carle
# Purpose: Re-run the Phase 2 SEM using PCA-aligned component scores (RC1-RC5)
#          from script 07 instead of theory-based 5 categories.
#
#          This provides a direct comparison:
#            Model A: Theory-based (Z_application..Z_governance) — from script 11
#            Model B: PCA-aligned  (PCA_RC1..PCA_RC5) — this script
#
#          If Model B fits better, the empirical structure is a better
#          representation of how resources cluster.
#          If Model A fits better, the theoretical categories hold.
#
#          IMPORTANT: PCA component labels (RC1-RC5) are DATA-DRIVEN.
#          Heather assigns the interpretive labels based on loadings table.
#          The PCA loadings from script 07 determine which variables
#          load on each RC. This script uses the RC scores as-is.
#
# Input:   MASTER_CODEBOOK_analytic.xlsx (with PCA_RC1-RC5 from script 07)
# Output:  Model comparison table (fit indices + parameter comparison)
# Last Updated: February 2026
# ============================================================================

# ============================================================================
# SECTION 1: PACKAGES
# ============================================================================

library(tidyverse)
library(lavaan)
library(readxl)

# ============================================================================
# SECTION 2: LOAD DATA
# ============================================================================

base_path <- "~/Library/Mobile Documents/com~apple~CloudDocs/Dissertation"
codebook_path <- file.path(base_path, "REFERENCE",
                           "MASTER_CODEBOOK_analytic.xlsx")
output_path <- file.path(base_path, "dissertation analysis")

mc <- read_excel(codebook_path)
cat("Full dataset:", nrow(mc), "dyads,", n_distinct(mc$platform_ID), "platforms\n")

# Verify PCA scores exist
pca_cols <- c("PCA_RC1", "PCA_RC2", "PCA_RC3", "PCA_RC4", "PCA_RC5")
missing_pca <- setdiff(pca_cols, colnames(mc))
if (length(missing_pca) > 0) {
  stop("Missing PCA columns: ", paste(missing_pca, collapse = ", "),
       "\n  Run script 07 first to compute PCA component scores.")
}

# ============================================================================
# SECTION 3: PREPARE PLAT DATASET
# ============================================================================

# Filter to PLAT firms with cultural_distance available (see script 10)
df_plat <- mc %>%
  filter(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED"),
         !is.na(cultural_distance)) %>%
  mutate(across(c(all_of(pca_cols),
                  platform_resources, platform_accessibility,
                  MKT_SHARE_CHANGE, cultural_distance,
                  LINGUISTIC_VARIETY, programming_lang_variety,
                  Z_application, Z_development, Z_ai, Z_social, Z_governance,
                  IND_GROW,
                  host_gdp_per_capita, host_Internet_users,
                  home_gdp_per_capita),
                as.numeric))

cat("PLAT firms (with CD):", nrow(df_plat), "dyads,",
    n_distinct(df_plat$platform_ID), "platforms\n\n")

# ============================================================================
# SECTION 4: STANDARDIZE FOR SEM
# ============================================================================

df_plat <- df_plat %>%
  mutate(
    # DV and mediator
    PA_z  = scale(platform_accessibility)[,1],
    DV_z  = scale(MKT_SHARE_CHANGE)[,1],

    # PCA component scores (already standardized from PCA, but re-scale
    # within the analysis sample for consistency)
    RC1_z = scale(PCA_RC1)[,1],
    RC2_z = scale(PCA_RC2)[,1],
    RC3_z = scale(PCA_RC3)[,1],
    RC4_z = scale(PCA_RC4)[,1],
    RC5_z = scale(PCA_RC5)[,1],

    # Theory-based (for direct comparison)
    Za_z  = scale(Z_application)[,1],
    Zd_z  = scale(Z_development)[,1],
    Zai_z = scale(Z_ai)[,1],
    Zs_z  = scale(Z_social)[,1],
    Zg_z  = scale(Z_governance)[,1],

    # Moderators and controls
    CD_z       = scale(cultural_distance)[,1],
    LV_z       = scale(LINGUISTIC_VARIETY)[,1],
    PLV_z      = scale(programming_lang_variety)[,1],
    IND_GROW_z = scale(IND_GROW)[,1],
    host_GDP_z  = scale(log(host_gdp_per_capita + 1))[,1],
    host_INET_z = scale(host_Internet_users)[,1],
    home_GDP_z  = scale(log(home_gdp_per_capita + 1))[,1]
  )

# ============================================================================
# SECTION 5: MODEL A — THEORY-BASED 5 CATEGORIES (Baseline)
# ============================================================================

cat("=== MODEL A: THEORY-BASED 5 CATEGORIES ===\n\n")

model_theory <- '
  # a paths: Each BR category → Platform Accessibility
  # NOTE: LV_z and PLV_z removed — PA is computed as (Z_LV + Z_PLV)/2,
  #        so including them creates perfect multicollinearity (R²≈1.0)
  PA_z ~ a_app*Za_z +
         a_dev*Zd_z +
         a_ai*Zai_z +
         a_soc*Zs_z +
         a_gov*Zg_z +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z +
         IND_GROW_z

  # b + c paths: → International Performance
  DV_z ~ b*PA_z +
          c_app*Za_z +
          c_dev*Zd_z +
          c_ai*Zai_z +
          c_soc*Zs_z +
          c_gov*Zg_z +
          CD_z +
          host_GDP_z + host_INET_z +
          IND_GROW_z

  # Indirect effects per category
  ind_app := a_app * b
  ind_dev := a_dev * b
  ind_ai  := a_ai  * b
  ind_soc := a_soc * b
  ind_gov := a_gov * b
'

fit_theory <- sem(model_theory, data = df_plat,
                  se = "bootstrap", bootstrap = 5000, estimator = "ML")

cat("Theory-based model fitted.\n")
summary(fit_theory, standardized = TRUE, fit.measures = TRUE)

# ============================================================================
# SECTION 6: MODEL B — PCA-ALIGNED 5 COMPONENTS
# ============================================================================

cat("\n=== MODEL B: PCA-ALIGNED 5 COMPONENTS ===\n\n")
cat("NOTE: RC1-RC5 labels are from the PCA rotation in script 07.\n")
cat("      Heather assigns interpretive names based on the loadings table.\n\n")

model_pca <- '
  # a paths: Each PCA component → Platform Accessibility
  # NOTE: LV_z and PLV_z removed — PA is computed from them (perfect collinearity)
  PA_z ~ a_rc1*RC1_z +
         a_rc2*RC2_z +
         a_rc3*RC3_z +
         a_rc4*RC4_z +
         a_rc5*RC5_z +
         CD_z +
         home_GDP_z + host_GDP_z + host_INET_z +
         IND_GROW_z

  # b + c paths: → International Performance
  DV_z ~ b*PA_z +
          c_rc1*RC1_z +
          c_rc2*RC2_z +
          c_rc3*RC3_z +
          c_rc4*RC4_z +
          c_rc5*RC5_z +
          CD_z +
          host_GDP_z + host_INET_z +
          IND_GROW_z

  # Indirect effects per PCA component
  ind_rc1 := a_rc1 * b
  ind_rc2 := a_rc2 * b
  ind_rc3 := a_rc3 * b
  ind_rc4 := a_rc4 * b
  ind_rc5 := a_rc5 * b
'

fit_pca <- sem(model_pca, data = df_plat,
               se = "bootstrap", bootstrap = 5000, estimator = "ML")

cat("PCA-aligned model fitted.\n")
summary(fit_pca, standardized = TRUE, fit.measures = TRUE)

# ============================================================================
# SECTION 7: MODEL COMPARISON
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("MODEL COMPARISON: THEORY vs PCA\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Fit indices side-by-side
fit_names <- c("chisq", "df", "pvalue", "cfi", "tli", "rmsea",
               "rmsea.ci.lower", "rmsea.ci.upper", "srmr",
               "aic", "bic")

fit_theory_vals <- fitMeasures(fit_theory, fit_names)
fit_pca_vals    <- fitMeasures(fit_pca, fit_names)

fit_comparison <- tibble(
  Measure     = fit_names,
  Theory      = round(fit_theory_vals, 4),
  PCA_Aligned = round(fit_pca_vals, 4),
  Difference  = round(fit_pca_vals - fit_theory_vals, 4),
  Better      = case_when(
    Measure %in% c("cfi", "tli") & Difference > 0 ~ "PCA",
    Measure %in% c("cfi", "tli") & Difference < 0 ~ "Theory",
    Measure %in% c("rmsea", "srmr", "aic", "bic") & Difference < 0 ~ "PCA",
    Measure %in% c("rmsea", "srmr", "aic", "bic") & Difference > 0 ~ "Theory",
    TRUE ~ "Tie"
  )
)

print(fit_comparison, n = Inf)

# ============================================================================
# SECTION 8: PARAMETER COMPARISON — CATEGORY vs PCA EFFECTS
# ============================================================================

cat("\n=== PARAMETER COMPARISON ===\n\n")

# Theory parameters
params_theory <- parameterEstimates(fit_theory, boot.ci.type = "perc",
                                     standardized = TRUE)
theory_effects <- params_theory %>%
  filter(label %in% c("a_app", "a_dev", "a_ai", "a_soc", "a_gov",
                        "c_app", "c_dev", "c_ai", "c_soc", "c_gov",
                        "ind_app", "ind_dev", "ind_ai", "ind_soc", "ind_gov",
                        "b")) %>%
  select(label, est, se, pvalue, std.all) %>%
  mutate(sig = case_when(
    pvalue < .001 ~ "***",
    pvalue < .01  ~ "**",
    pvalue < .05  ~ "*",
    pvalue < .10  ~ "†",
    TRUE          ~ "ns"
  ))

cat("--- Theory-Based Category Effects ---\n")
print(as.data.frame(theory_effects))

# PCA parameters
params_pca <- parameterEstimates(fit_pca, boot.ci.type = "perc",
                                  standardized = TRUE)
pca_effects <- params_pca %>%
  filter(label %in% c("a_rc1", "a_rc2", "a_rc3", "a_rc4", "a_rc5",
                        "c_rc1", "c_rc2", "c_rc3", "c_rc4", "c_rc5",
                        "ind_rc1", "ind_rc2", "ind_rc3", "ind_rc4", "ind_rc5",
                        "b")) %>%
  select(label, est, se, pvalue, std.all) %>%
  mutate(sig = case_when(
    pvalue < .001 ~ "***",
    pvalue < .01  ~ "**",
    pvalue < .05  ~ "*",
    pvalue < .10  ~ "†",
    TRUE          ~ "ns"
  ))

cat("\n--- PCA-Aligned Component Effects ---\n")
print(as.data.frame(pca_effects))

# ============================================================================
# SECTION 9: R-SQUARED COMPARISON
# ============================================================================

cat("\n=== R-SQUARED COMPARISON ===\n\n")

r2_theory <- lavInspect(fit_theory, "rsquare")
r2_pca    <- lavInspect(fit_pca, "rsquare")

cat("Variance Explained (R²):\n")
cat(sprintf("  %-25s Theory    PCA\n", "Outcome"))
cat(sprintf("  %-25s ------    ---\n", ""))
for (var_name in names(r2_theory)) {
  cat(sprintf("  %-25s %.4f    %.4f\n", var_name,
              r2_theory[var_name], r2_pca[var_name]))
}

# ============================================================================
# SECTION 10: VIF CHECK FOR PCA COMPONENTS
# ============================================================================

cat("\n=== VIF: PCA COMPONENT MULTICOLLINEARITY ===\n\n")
cat("(PCA components are orthogonal by construction, so VIF should be ~1.0)\n\n")

vif_pca <- lm(PA_z ~ RC1_z + RC2_z + RC3_z + RC4_z + RC5_z, data = df_plat)
print(car::vif(vif_pca))

cat("\nCompare to theory-based VIF:\n")
vif_theory <- lm(PA_z ~ Za_z + Zd_z + Zai_z + Zs_z + Zg_z, data = df_plat)
print(car::vif(vif_theory))

# ============================================================================
# SECTION 11: ROBUSTNESS — PCA MODEL ON FULL 903
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("ROBUSTNESS: PCA MODEL ON FULL 903 FIRMS\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

df_full <- mc %>%
  filter(!is.na(cultural_distance)) %>%
  mutate(
    is_PLAT = as.numeric(PLAT %in% c("PUBLIC", "REGISTRATION", "RESTRICTED")),
    across(c(all_of(pca_cols),
             platform_accessibility, MKT_SHARE_CHANGE,
             cultural_distance, LINGUISTIC_VARIETY, programming_lang_variety,
             IND_GROW,
             host_gdp_per_capita, host_Internet_users, home_gdp_per_capita),
           as.numeric)
  ) %>%
  mutate(
    PA_z  = scale(platform_accessibility)[,1],
    DV_z  = scale(MKT_SHARE_CHANGE)[,1],
    RC1_z = scale(PCA_RC1)[,1],
    RC2_z = scale(PCA_RC2)[,1],
    RC3_z = scale(PCA_RC3)[,1],
    RC4_z = scale(PCA_RC4)[,1],
    RC5_z = scale(PCA_RC5)[,1],
    CD_z       = scale(cultural_distance)[,1],
    LV_z       = scale(LINGUISTIC_VARIETY)[,1],
    PLV_z      = scale(programming_lang_variety)[,1],
    IND_GROW_z = scale(IND_GROW)[,1],
    host_GDP_z  = scale(log(host_gdp_per_capita + 1))[,1],
    host_INET_z = scale(host_Internet_users)[,1],
    home_GDP_z  = scale(log(home_gdp_per_capita + 1))[,1]
  )

fit_pca_full <- sem(model_pca, data = df_full,
                    se = "bootstrap", bootstrap = 5000, estimator = "ML")

cat("Full 903 PCA model fitted.\n")
summary(fit_pca_full, standardized = TRUE, fit.measures = TRUE)

# ============================================================================
# SECTION 12: SAVE
# ============================================================================

# Save fit comparison
write.csv(fit_comparison,
          file.path(output_path, "model_comparison_theory_vs_pca.csv"),
          row.names = FALSE)

# Save PCA effects
write.csv(pca_effects,
          file.path(output_path, "pca_aligned_sem_effects.csv"),
          row.names = FALSE)

# Save theory effects
write.csv(theory_effects,
          file.path(output_path, "theory_based_sem_effects.csv"),
          row.names = FALSE)

# ============================================================================
# SECTION 13: APA WORD TABLE EXPORTS
# ============================================================================

cat("\n=== EXPORTING APA TABLES TO WORD ===\n\n")

library(flextable)
library(officer)

tables_path <- file.path(base_path, "FINAL DISSERTATION", "tables and charts REVISED")
word_path <- file.path(tables_path, "12_PCA_vs_Theory_Comparison_APA.docx")
doc <- read_docx()

# --- Helper: APA-formatted flextable ---
apa_table <- function(df, caption = "") {
  ft <- flextable(df) %>%
    theme_booktabs() %>%
    fontsize(size = 10, part = "all") %>%
    font(fontname = "Times New Roman", part = "all") %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "body") %>%
    autofit() %>%
    set_caption(caption = caption)
  return(ft)
}

# --- Table 1: Fit Index Comparison ---
doc <- doc %>%
  body_add_par("Table 1: Model Fit Comparison — Theory-Based vs PCA-Aligned",
               style = "heading 2")

fit_names <- c("chisq", "df", "pvalue", "cfi", "tli",
               "rmsea", "rmsea.ci.lower", "rmsea.ci.upper",
               "srmr", "aic", "bic")
fit_labels <- c("χ²", "df", "p (χ²)", "CFI", "TLI",
                "RMSEA", "RMSEA 90% CI Lower", "RMSEA 90% CI Upper",
                "SRMR", "AIC", "BIC")

fit_theory_vals <- fitMeasures(fit_theory, fit_names)
fit_pca_vals    <- fitMeasures(fit_pca, fit_names)

fit_table <- data.frame(
  Measure = fit_labels,
  Theory  = sprintf("%.3f", fit_theory_vals),
  PCA     = sprintf("%.3f", fit_pca_vals),
  Delta   = sprintf("%.3f", fit_pca_vals - fit_theory_vals),
  stringsAsFactors = FALSE
)

doc <- doc %>%
  body_add_flextable(apa_table(fit_table, "Model Fit: Theory-Based (5 Categories) vs PCA-Aligned (5 Components)")) %>%
  body_add_par("Note. Theory = five theory-based BR category composites; PCA = five varimax-rotated PCA component scores. Lower AIC/BIC indicates better fit. RMSEA 90% CI = 90% confidence interval for RMSEA. Delta = PCA value minus Theory value.", style = "Normal") %>%
  body_add_par("")

# --- Table 2: Theory-Based Path Coefficients ---
doc <- doc %>%
  body_add_par("Table 2: Theory-Based Model — Path Coefficients",
               style = "heading 2")

theory_labels <- c(
  a_app = "Application → PA (a)", a_dev = "Development → PA (a)",
  a_ai = "AI Integration → PA (a)", a_soc = "Social/Community → PA (a)",
  a_gov = "Governance → PA (a)",
  b = "PA → Performance (b)",
  c_app = "Application → Perf (c')", c_dev = "Development → Perf (c')",
  c_ai = "AI Integration → Perf (c')", c_soc = "Social/Community → Perf (c')",
  c_gov = "Governance → Perf (c')",
  ind_app = "Application (indirect)", ind_dev = "Development (indirect)",
  ind_ai = "AI Integration (indirect)", ind_soc = "Social/Community (indirect)",
  ind_gov = "Governance (indirect)"
)

t2 <- theory_effects %>%
  mutate(
    Path = theory_labels[label],
    B    = sprintf("%.3f", est),
    SE   = sprintf("%.3f", se),
    p    = ifelse(pvalue < .001, "< .001", sprintf("%.3f", pvalue)),
    Beta = sprintf("%.3f", std.all)
  ) %>%
  select(Path, B, SE, p, Beta, Sig = sig)

doc <- doc %>%
  body_add_flextable(apa_table(t2, "Theory-Based Category Effects (PLAT Sample)")) %>%
  body_add_par("Note. B = unstandardized coefficient; SE = standard error; Beta = standardized coefficient. Bootstrap SE with 5,000 replications.", style = "Normal") %>%
  body_add_par("* p < .05. ** p < .01. *** p < .001. † p < .10.", style = "Normal") %>%
  body_add_par("")

# --- Table 3: PCA-Aligned Path Coefficients ---
doc <- doc %>%
  body_add_par("Table 3: PCA-Aligned Model — Path Coefficients",
               style = "heading 2")

# Component labels — update these based on loadings interpretation
pca_labels <- c(
  a_rc1 = "RC1 (Core Platform) → PA (a)",
  a_rc2 = "RC2 (Boundary Spanning & AI Services) → PA (a)",
  a_rc3 = "RC3 (AI Agent Integration) → PA (a)",
  a_rc4 = "RC4 (Community Ecosystem) → PA (a)",
  a_rc5 = "RC5 (Developer Communication) → PA (a)",
  b = "PA → Performance (b)",
  c_rc1 = "RC1 (Core Platform) → Perf (c')",
  c_rc2 = "RC2 (Boundary Spanning & AI Services) → Perf (c')",
  c_rc3 = "RC3 (AI Agent Integration) → Perf (c')",
  c_rc4 = "RC4 (Community Ecosystem) → Perf (c')",
  c_rc5 = "RC5 (Developer Communication) → Perf (c')",
  ind_rc1 = "RC1 (Core Platform) indirect",
  ind_rc2 = "RC2 (Boundary Spanning & AI Services) indirect",
  ind_rc3 = "RC3 (AI Agent Integration) indirect",
  ind_rc4 = "RC4 (Community Ecosystem) indirect",
  ind_rc5 = "RC5 (Developer Communication) indirect"
)

t3 <- pca_effects %>%
  mutate(
    Path = pca_labels[label],
    B    = sprintf("%.3f", est),
    SE   = sprintf("%.3f", se),
    p    = ifelse(pvalue < .001, "< .001", sprintf("%.3f", pvalue)),
    Beta = sprintf("%.3f", std.all)
  ) %>%
  select(Path, B, SE, p, Beta, Sig = sig)

doc <- doc %>%
  body_add_flextable(apa_table(t3, "PCA-Aligned Component Effects (PLAT Sample)")) %>%
  body_add_par("Note. B = unstandardized coefficient; SE = standard error; Beta = standardized coefficient. Bootstrap SE with 5,000 replications. Component labels based on varimax-rotated PCA loadings from script 07.", style = "Normal") %>%
  body_add_par("* p < .05. ** p < .01. *** p < .001. † p < .10.", style = "Normal") %>%
  body_add_par("")

# --- Table 4: R-Squared Comparison ---
doc <- doc %>%
  body_add_par("Table 4: Variance Explained (R²)",
               style = "heading 2")

r2_theory <- lavInspect(fit_theory, "rsquare")
r2_pca    <- lavInspect(fit_pca, "rsquare")

r2_table <- data.frame(
  Outcome = names(r2_theory),
  Theory  = sprintf("%.3f", r2_theory),
  PCA     = sprintf("%.3f", r2_pca),
  stringsAsFactors = FALSE
)

doc <- doc %>%
  body_add_flextable(apa_table(r2_table, "R² Comparison: Theory vs PCA")) %>%
  body_add_par("")

# Write Word document
print(doc, target = word_path)
cat("Word tables saved:", word_path, "\n")

# ============================================================================
# SECTION 14: COMPARISON CHARTS
# ============================================================================

cat("\n=== GENERATING COMPARISON CHARTS ===\n\n")

library(ggplot2)

# --- Chart 1: Side-by-side a-path comparison (→ PA) ---
a_theory <- theory_effects %>%
  filter(grepl("^a_", label)) %>%
  mutate(
    Model = "Theory",
    Component = c("Application", "Development", "AI Integration",
                   "Social/Community", "Governance")
  ) %>%
  select(Component, Model, est, se, sig)

a_pca <- pca_effects %>%
  filter(grepl("^a_", label)) %>%
  mutate(
    Model = "PCA",
    Component = c("RC1 (Core Platform)", "RC2 (Boundary Span/AI Svc)",
                   "RC3 (AI Agent)", "RC4 (Community)",
                   "RC5 (Dev Comm)")
  ) %>%
  select(Component, Model, est, se, sig)

a_combined <- bind_rows(a_theory, a_pca) %>%
  mutate(Component = factor(Component, levels = rev(unique(Component))))

p_a <- ggplot(a_combined, aes(x = est, y = Component, fill = Model)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_errorbarh(aes(xmin = est - 1.96*se, xmax = est + 1.96*se),
                  position = position_dodge(width = 0.7), height = 0.2) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(values = c("Theory" = "#2166AC", "PCA" = "#B2182B")) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Standardized Coefficient (β)",
    y = NULL
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(file.path(tables_path, "12_a_paths_comparison.png"),
       p_a, width = 9, height = 6, dpi = 300, bg = "white")
cat("a-path comparison chart saved.\n")

# --- Chart 2: Side-by-side c-path comparison (→ Performance direct) ---
c_theory <- theory_effects %>%
  filter(grepl("^c_", label)) %>%
  mutate(
    Model = "Theory",
    Component = c("Application", "Development", "AI Integration",
                   "Social/Community", "Governance")
  ) %>%
  select(Component, Model, est, se, sig)

c_pca <- pca_effects %>%
  filter(grepl("^c_", label)) %>%
  mutate(
    Model = "PCA",
    Component = c("RC1 (Core Platform)", "RC2 (Boundary Span/AI Svc)",
                   "RC3 (AI Agent)", "RC4 (Community)",
                   "RC5 (Dev Comm)")
  ) %>%
  select(Component, Model, est, se, sig)

c_combined <- bind_rows(c_theory, c_pca) %>%
  mutate(Component = factor(Component, levels = rev(unique(Component))))

p_c <- ggplot(c_combined, aes(x = est, y = Component, fill = Model)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_errorbarh(aes(xmin = est - 1.96*se, xmax = est + 1.96*se),
                  position = position_dodge(width = 0.7), height = 0.2) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(values = c("Theory" = "#2166AC", "PCA" = "#B2182B")) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Standardized Coefficient (β)",
    y = NULL
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(file.path(tables_path, "12_c_paths_comparison.png"),
       p_c, width = 9, height = 6, dpi = 300, bg = "white")
cat("c-path comparison chart saved.\n")

# --- Chart 3: Indirect effects comparison ---
ind_theory <- theory_effects %>%
  filter(grepl("^ind_", label)) %>%
  mutate(
    Model = "Theory",
    Component = c("Application", "Development", "AI Integration",
                   "Social/Community", "Governance")
  ) %>%
  select(Component, Model, est, se, sig)

ind_pca <- pca_effects %>%
  filter(grepl("^ind_", label)) %>%
  mutate(
    Model = "PCA",
    Component = c("RC1 (Core Platform)", "RC2 (Boundary Span/AI Svc)",
                   "RC3 (AI Agent)", "RC4 (Community)",
                   "RC5 (Dev Comm)")
  ) %>%
  select(Component, Model, est, se, sig)

ind_combined <- bind_rows(ind_theory, ind_pca) %>%
  mutate(Component = factor(Component, levels = rev(unique(Component))))

p_ind <- ggplot(ind_combined, aes(x = est, y = Component, fill = Model)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_errorbarh(aes(xmin = est - 1.96*se, xmax = est + 1.96*se),
                  position = position_dodge(width = 0.7), height = 0.2) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(values = c("Theory" = "#2166AC", "PCA" = "#B2182B")) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Standardized Indirect Effect",
    y = NULL
  ) +
  theme_classic(base_family = "Times New Roman", base_size = 11) +
  theme(
    text = element_text(family = "Times New Roman"),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(file.path(tables_path, "12_indirect_effects_comparison.png"),
       p_ind, width = 9, height = 6, dpi = 300, bg = "white")
cat("Indirect effects comparison chart saved.\n")

cat("\n✓ Script 12 complete.\n")
cat("  Outputs:\n")
cat("    model_comparison_theory_vs_pca.csv\n")
cat("    pca_aligned_sem_effects.csv\n")
cat("    theory_based_sem_effects.csv\n")
cat("    12_PCA_vs_Theory_Comparison_APA.docx (Tables 1-4)\n")
cat("    12_a_paths_comparison.png\n")
cat("    12_c_paths_comparison.png\n")
cat("    12_indirect_effects_comparison.png\n")
cat("  Compare AIC/BIC/CFI/RMSEA to determine which structure fits better.\n")

# ============================================================================
# METHODS SECTION LANGUAGE
# ============================================================================
# "To evaluate whether the theoretical five-category structure or an
# empirically-derived structure better represents the boundary resource
# architecture, we compared two lavaan models using identical path
# structures but different predictor groupings. Model A used the five
# theory-based category composites (Application, Development, AI, Social,
# Governance). Model B replaced these with five varimax-rotated PCA
# component scores from a principal component analysis of the 33 individual
# resource indicators (see Section [X]). We compared models using AIC,
# BIC, CFI, TLI, RMSEA, and SRMR. The PCA components are orthogonal by
# construction, eliminating multicollinearity concerns present in the
# theory-based composites (VIF comparison reported). This approach follows
# the recommendation of Hair et al. (2019) to compare theory-driven and
# data-driven measurement structures when theory alignment is below 60%."
# ============================================================================
