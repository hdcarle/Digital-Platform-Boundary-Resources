# Digital-Platform-Boundary-Resources

**PhD Dissertation — Designing Digital Platforms: Boundary Decisions that Impact the Development of Global Ecosystems**

Heather D. Carle | University of North Carolina at Greensboro | 2026

---

## About This Research

Digital platforms constitute a broad definition of strategic applications that utilize a core technology with a prescribed interface that enable external parties (complementors) to build complementary products (Ceccagnoli et al., 2012; Cusumano et al., 2019; Gawer & Cusumano, 2015; Van Alstyne et al., 2016b). This study uses a novel AI-powered research workflow within a qualitative content analysis — using multiple AI coding agents together with a human coder — to analyze web content and assess platform orchestration choices of application interface, development, AI, social, and governance boundary resources across 901 platforms in 10 industries.

Cultural distance, natural language, and computer programming language are examined as moderators of the relationship between boundary resource orchestration and international market performance.

---

## Repository Contents

This repository contains the source data files used for panel data as well as the summary coded data. In addition, all scripts used for data scraping, AI agent coding, and R files used for analysis are provided, enabling other researchers to reproduce the research project with the same or new firms.

**Estimated repository size: 9.1 MB**

### Documentation (`REFERENCE/`)

Methodology documentation, coding instructions, and workflow guides:

- `MULTI_CODER_WORKFLOW_v2.0_FINAL.md` — Full 9-stage pipeline workflow from URL collection through adjudication
- `AI_CODING_PROMPT_v2.0_FINAL.md` — Complete coding instructions provided to both Claude and ChatGPT AI coders (76 variables across 5 boundary resource classes)
- `Data_Collection_Codebook_v2.0.md` — Human-oriented codebook with detailed variable definitions
- `PROGRAMMING_LANGUAGES_INDEX.md` — Official list of 50 valid programming languages with mapping rules
- `SCRAPING_AND_LANG_CODING_CONTEXT.md` — Context document for web scraping and language coding

### Python Scripts (`dissertation_batch_api/`)

Automated data collection pipeline — 18 scripts covering web scraping, GitHub data enrichment, AI coding, inter-rater reliability, and result merging:

| Script | Stage | Purpose |
|--------|-------|---------|
| `selenium_scraper.py` | Scraping | Selenium + headless Chrome, crawl depth 3, max 100 pages |
| `claude_coder.py` | AI Coding | Codes boundary resources via Claude 3.5 Sonnet (Anthropic API) |
| `chatgpt_coder.py` | AI Coding | Codes boundary resources via GPT-4o (OpenAI API) |
| `irr_calculator.py` | IRR | Gwet's AC1, Cohen's Kappa, Krippendorff's Alpha, ICC |
| `merge_results.py` | Merge | Consensus-rule merge into MASTER_CODEBOOK |

See `COMPLETE_BEGINNER_GUIDE.md` in that directory for step-by-step instructions.

### R Scripts (`dissertation analysis/`)

Statistical analysis pipeline — 14 sequential scripts from data import through SEM and cluster analysis:

| Script | Purpose |
|--------|---------|
| `01_import_and_dv.R` | Import master codebook, compute DV and moderator |
| `06_composite_scores.R` | Boundary resource composite scores (5 classes) |
| `07_pca_resource_structure.R` | Principal Component Analysis |
| `11_sem_moderated_mediation.R` | SEM: moderated mediation (H1–H4) |
| `14_cluster_performance.R` | Cluster analysis of resource profiles |

### Data Files

- **`REFERENCE/MASTER_CODEBOOK.xlsx`** — Master codebook: 6,617 firm-country dyad rows × 126 columns
- **`REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv`** — 901 platforms across 10 industries with developer portal URLs
- **`dissertation_batch_api/claude_results/`** — Claude AI coding output (~242 JSON files)
- **`dissertation_batch_api/chatgpt_results/`** — ChatGPT AI coding output (~242 JSON files)
- **`dissertation_batch_api/adjudicated_results/`** — Final consensus-resolved codings (~903 JSON files)
- **`dissertation_batch_api/irr_test/`** — 16-platform IRR subset results (JSON only)
- **`dissertation analysis/`** — R output CSVs (correlation matrices, PCA loadings, cluster assignments, etc.)

### AI Coding Agent (`boundary-resource-coder/`)

Claude skill definition and reference files used by the AI boundary resource coding agent.

---

## Reproducing This Research

1. **Web scraping**: Run `selenium_scraper.py` with URLs from `ALL_PLATFORMS_URL_TRACKER.csv`
2. **GitHub enrichment**: Run `inject_github_urls.py` → `validate_github_urls.py` → `github_lang_scraper.py`
3. **AI coding**: Run `claude_coder.py` and `chatgpt_coder.py` (requires API keys)
4. **IRR & merge**: Run `irr_calculator.py` then `merge_results.py`
5. **Statistical analysis**: Run R scripts 01–14 sequentially in `dissertation analysis/`

See `REFERENCE/MULTI_CODER_WORKFLOW_v2.0_FINAL.md` for the complete pipeline documentation.

---

## Data Availability Notes

**Scraped developer portal content** (~239 platforms) is not included due to size constraints. Researchers can reproduce it by running `selenium_scraper.py` with the provided URL tracker.

**Third-party datasets** (Euromonitor Passport market share data, World Development Indicators, Hofstede cultural dimensions, GLOBE measures, CEPII geographic/linguistic data, EF English Proficiency Index, Stack Overflow Developer Survey) should be obtained from their original sources as documented in the dissertation methodology chapter.

---

## Citation

Carle, H. D. (2026). *Designing Digital Platforms: Boundary Decisions that Impact the Development of Global Ecosystems* [Doctoral dissertation, University of North Carolina at Greensboro].

## License

This repository is provided for academic research and reproducibility purposes.
