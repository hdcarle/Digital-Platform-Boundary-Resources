# Digital-Platform-Boundary-Resources

**PhD Dissertation — Internationalization of Digital Platform Firms: An Exploration of Resource Orchestration, Platform Accessibility, and Cultural Distance**

Heather D. Carle | University of North Carolina at Greensboro | 2026

---

## About This Research

Digital platforms constitute a broad definition of strategic applications that utilize a core technology with a prescribed interface that enable external parties (complementors) to build complementary products (Ceccagnoli et al., 2012; Cusumano et al., 2019; Gawer & Cusumano, 2015; Van Alstyne et al., 2016b). This study uses a novel AI-powered research workflow within a qualitative content analysis — using multiple AI coding agents together with a human coder — to analyze web content and assess platform orchestration choices of application interface, development, AI, social, and governance boundary resources across 901 platforms in 10 industries.

Cultural distance, natural language, and computer programming language are examined as moderators of the relationship between boundary resource orchestration and international market performance.

---

## Repository Contents

This repository contains the source data files used for panel data as well as the summary coded data. In addition, all scripts used for data scraping, AI agent coding, and R files used for analysis are provided, enabling other researchers to reproduce the research project with the same or new firms.

### Documentation (`REFERENCE/`)

Methodology documentation, coding instructions, reference data, and workflow guides:

| File | Description |
|------|-------------|
| `MULTI_CODER_WORKFLOW_v2.0_FINAL.md` | Full 9-stage pipeline workflow from URL collection through adjudication |
| `AI_CODING_PROMPT_v3.0.md` | Complete coding instructions for both Claude and ChatGPT AI coders (76 variables across 5 boundary resource classes) |
| `Data_Collection_Codebook_v2.0.md` | Human-oriented codebook with detailed variable definitions |
| `PROGRAMMING_LANGUAGES_INDEX.md` | Official list of 50 valid programming languages with mapping rules |
| `SCRAPING_AND_LANG_CODING_CONTEXT.md` | Context document for web scraping and language coding |
| `MASTER_CODEBOOK.xlsx` | Master codebook: 6,617 firm-country dyad rows × 126 columns |
| `ALL_PLATFORMS_URL_TRACKER.csv` | 901 platforms across 10 industries with developer portal URLs |
| `coder_template.csv` / `coder_template_data_dictionary.csv` | Template and data dictionary for coding |
| `platform_list_for_coding.csv` | Platform list used as input for the coding pipeline |
| `country_language_lookup.csv` | Country-to-language reference mapping |
| `home_country_sources_filtered.csv` | Filtered home country source data |
| `irr_subset_for_human.csv` | 16-platform subset used for human inter-rater reliability |
| `PLATFORMS_SUCCESSFULLY_SCRAPED.csv` | Platforms with successful scraping results |
| `PLATFORMS_FAILED_SCRAPING.csv` | Platforms where scraping failed |
| `PLATFORMS_NO_URL_AVAILABLE.csv` | Platforms with no developer portal URL available |
| `merge_coder_outputs.py` | Utility script for merging coder outputs |

### Python Scripts (`Scripts/`)

Automated data collection pipeline — 17 scripts covering web scraping, GitHub data enrichment, AI coding, inter-rater reliability, and result merging:

| Script | Stage | Purpose |
|--------|-------|---------|
| `pre_scrape_diagnostic.py` | Pre-scrape | Validate URLs before scraping |
| `archive_out_of_sample.py` | Pre-scrape | Archive out-of-sample platforms |
| `selenium_scraper.py` | Scraping | Selenium + headless Chrome, crawl depth 3, max 100 pages |
| `dedup_scraped_content.py` | Scraping | Deduplicate scraped content |
| `inject_github_urls.py` | GitHub | Inject GitHub URLs into platform data |
| `validate_github_urls.py` | GitHub | Validate injected GitHub URLs |
| `github_lang_scraper.py` | GitHub | Scrape programming language data from GitHub repos |
| `claude_coder.py` | AI Coding | Code boundary resources via Claude Sonnet 4 (Anthropic API) |
| `chatgpt_coder.py` | AI Coding | Code boundary resources via GPT-4o (OpenAI API) |
| `github_augment_results.py` | Post-coding | Augment results with GitHub data |
| `normalize_languages.py` | Post-coding | Normalize programming language entries |
| `convert_human_to_json.py` | IRR | Convert human coder spreadsheet to JSON format |
| `fix_binary_values.py` | IRR | Fix binary value inconsistencies |
| `irr_calculator.py` | IRR | Gwet's AC1, Cohen's Kappa, Krippendorff's Alpha, ICC |
| `human_irr_calculator.py` | IRR | Calculate human-vs-AI inter-rater reliability |
| `inject_external_links.py` | Merge | Inject external links into results |
| `merge_results.py` | Merge | Consensus-rule merge into MASTER_CODEBOOK |

See `COMPLETE_BEGINNER_GUIDE.md` (root) for step-by-step instructions.

### R Scripts (`R scripts/`)

Statistical analysis pipeline — 17 sequential scripts from data import through SEM and cluster analysis:

| Script | Purpose |
|--------|---------|
| `01_import_and_dv.R` | Import master codebook, compute DV and moderator |
| `02_ind_grow.R` | Industry growth variable computation |
| `03_tables_3_and_4.R` | Dissertation Tables 3 and 4 |
| `04_wdi_controls.R` | World Development Indicator control variables |
| `05_merge_adjudicated_data.R` | Merge adjudicated coding data |
| `06_composite_scores.R` | Boundary resource composite scores (5 classes) |
| `07_pca_resource_structure.R` | Principal Component Analysis |
| `08_descriptive_statistics.R` | Descriptive statistics and tables |
| `09_validity_checks.R` | Validity and reliability checks |
| `10_cultural_distance_kogut_singh.R` | Cultural distance (Kogut-Singh index) |
| `11_sem_moderated_mediation.R` | SEM: moderated mediation (H1–H4) |
| `12_pca_aligned_sem.R` | PCA-aligned SEM robustness check |
| `14_cluster_performance.R` | Cluster analysis of resource profiles |
| `15_language_market_fit.R` | Language-market fit analysis |
| `16_E_PLF_CD_diagnostic.R` | GLOBE cluster × cultural distance analysis |
| `calculate_irr.R` | Inter-rater reliability calculations |
| `dissertation_language_analysis.R` | Programming and natural language analysis |

### Results (`Results/`)

AI coding output data:

| Path | Content |
|------|---------|
| `claude_results/` | Claude AI coding output (~242 JSON files) |
| `chatgpt_results/` | ChatGPT AI coding output (~242 JSON files) |
| `adjudicated_results/` | Final consensus-resolved codings (~903 JSON files) |
| `irr_test/` | 16-platform IRR subset results (JSON only) |

### Output CSV (`Output CSV/`)

R analysis output files including correlation matrices, PCA loadings, cluster assignments, and descriptive tables:

| File | Content |
|------|---------|
| `correlation_matrix_sem_vars.csv` | Correlation matrix for SEM variables |
| `correlation_matrix_sem_vars_updated.csv` | Updated correlation matrix |
| `platform_accessibility_draft.csv` | Platform accessibility mediator draft |
| `harmans_test_results.csv` | Harman's single-factor test (common method bias) |
| `internal_consistency_alpha.csv` | Cronbach's alpha internal consistency |
| `missing_data_report.csv` | Missing data diagnostics |
| `pca_component_scores.csv` | PCA component scores |
| `pca_loadings_varimax_5comp.csv` | PCA loadings with varimax rotation (5 components) |
| `platform_cluster_assignments.csv` | Platform cluster assignments |
| `table3_data.csv` / `table4_data.csv` | Dissertation table data |
| `z_score_parameters.csv` | Z-score standardization parameters |
| `Language_Disagreement_Review.xlsx` | Language disagreement review |

### GitHub Supplemental Data (`Github supplemental data/`)

| File | Content |
|------|---------|
| `gemini_github_results.json` | Gemini-assisted GitHub URL search results |
| `github_validation_report.json` | GitHub URL validation report |
| `gemini_github_search_prompt.txt` | Prompt used for Gemini GitHub searches |
| `gemini_github_search_prompt_BATCH2.txt` | Batch 2 search prompt |

### Dissertation Data (`dissertation data/`)

| Path | Content |
|------|---------|
| `ISO_Reference.csv` | ISO country code reference |
| `platform market share data/csv_converted/` | 10 industry-level 5-year growth CSVs converted from Euromonitor data |

---

## Reproducing This Research

1. **Web scraping**: Run `selenium_scraper.py` with URLs from `ALL_PLATFORMS_URL_TRACKER.csv`
2. **GitHub enrichment**: Run `inject_github_urls.py` → `validate_github_urls.py` → `github_lang_scraper.py`
3. **AI coding**: Run `claude_coder.py` and `chatgpt_coder.py` (requires API keys)
4. **IRR & merge**: Run `irr_calculator.py` then `merge_results.py`
5. **R analysis**: Run R scripts 01–16_E sequentially in `R scripts/` (note: `10_cultural_distance_kogut_singh.R` must run before `08_descriptive_statistics.R` if cultural distance variables are needed in descriptive tables)

See `REFERENCE/MULTI_CODER_WORKFLOW_v2.0_FINAL.md` for the complete pipeline documentation.

---

## Data Availability Notes

**Scraped developer portal content** (~239 platforms) is not included due to size constraints. Researchers can reproduce it by running `selenium_scraper.py` with the provided URL tracker.

**Third-party datasets** (Euromonitor Passport market share data, World Development Indicators, Hofstede cultural dimensions, GLOBE measures, CEPII geographic/linguistic data, EF English Proficiency Index, Stack Overflow Developer Survey) should be obtained from their original sources as documented in the dissertation methodology chapter.

---

## Citation

Carle, H. D. (2026). *Internationalization of Digital Platform Firms: An Exploration of Resource Orchestration, Platform Accessibility, and Cultural Distance* [Doctoral dissertation, University of North Carolina at Greensboro].

## License

This repository is provided for academic research and reproducibility purposes.
