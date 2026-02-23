# Multi-Coder Data Collection Workflow v2.0
## Final Version - February 15, 2026

This document describes the complete workflow for collecting platform boundary resource data using multiple coders (Human, Claude AI, ChatGPT AI) to establish inter-rater reliability.

---

## Overview

Three coders independently analyze developer portal content:

| Coder | Type | Platforms | Purpose |
|-------|------|-----------|---------|
| **Human** | Manual | 16 IRR subset | Ground truth for validation |
| **Claude** | AI (Anthropic) | All 230 PLAT platforms | Primary automated coder |
| **ChatGPT** | AI (OpenAI) | All 230 PLAT platforms | Secondary automated coder |

---

## Workflow Pipeline

### Stage 1: URL Collection
**Input:** Platform list with company names
**Output:** `ALL_PLATFORMS_URL_TRACKER.csv` (901 platforms across 10 industries, 230 with PLAT = PUBLIC/REGISTRATION/RESTRICTED after listwise deletion)

Manual research to identify developer portal URLs for each platform. URLs are verified and categorized by access type:
- **PUBLIC** - Freely accessible
- **REGISTRATION** - Requires free account
- **RESTRICTED** - Requires approval/payment

### Stage 2: Web Scraping
**Script:** `selenium_scraper.py`
**Input:** Tracker CSV with portal URLs
**Output:** `scraped_content/[Platform_ID]_[Name]/` folders

The Selenium-based scraper:
1. Uses headless Chrome to render JavaScript
2. Extracts navigation links using keyword matching
3. Scrapes up to 100 pages per platform
4. Records external links (GitHub, social media) without scraping
5. Saves combined content for AI processing

**Navigation Keywords:**
- API/Documentation: api, docs, reference, getting-started
- SDK: sdk, library, download, packages
- Community: forum, community, support, blog
- Governance: terms, privacy, pricing, marketplace
- Events: events, webinar, conference, hackathon

### Stage 2b: GitHub Data Injection (REQUIRED before AI Coding)
**Scripts:** `inject_github_urls.py`, `github_lang_scraper.py`
**Input:** `gemini_github_results.json` + scraped_content/ metadata.json files
**Output:** Updated COMBINED_CONTENT.txt with "GITHUB REPOSITORY LANGUAGES" section

This stage enriches scraped content with GitHub programming language data so AI coders can accurately code GIT_prog_lang:

1. **Gemini GitHub search** — Prompt Gemini to find official GitHub/GitLab org URLs for all platform firms. Save results as `gemini_github_results.json`. Two batches:
   - Batch 1: 112 platforms (original VG + mixed industries)
   - Batch 2: 140 platforms (103 CC banking + remaining industries)
   - Prompts: `gemini_github_search_prompt.txt` and `gemini_github_search_prompt_BATCH2.txt`
2. **inject_github_urls.py** — Reads Gemini JSON, injects `github_url` into each platform's `metadata.json`
3. **github_lang_scraper.py** — Queries GitHub API for repo programming languages, maps to codebook-valid languages (50 languages per PROGRAMMING_LANGUAGES_INDEX.md), injects results into COMBINED_CONTENT.txt

**Without this stage:** AI coders can detect GIT=1 from URL mentions but cannot code GIT_prog_lang.

**Coding implications:** GIT_prog_lang populated; SDK=1 if GitHub repos contain code samples (per coding prompt); programming_lang_variety may increase.

```bash
# Merge Gemini batches
python3 -c "import json; b1=json.load(open('gemini_github_results.json')); b2=json.load(open('gemini_github_results_BATCH2.json')); json.dump(b1+b2, open('gemini_github_results.json','w'), indent=2); print(f'{len(b1)}+{len(b2)}={len(b1+b2)}')"

# Inject URLs into metadata.json
python3 inject_github_urls.py scraped_content/

# Query GitHub API for languages (use token for 5000/hr rate limit)
export GITHUB_TOKEN='ghp_...'
python3 github_lang_scraper.py scraped_content/
```

### Stage 2c: GitHub URL Validation (REQUIRED after GitHub injection)
**Script:** `validate_github_urls.py`
**Input:** `gemini_github_results.json` + GitHub API
**Output:** Removes hallucinated URLs from metadata.json and COMBINED_CONTENT.txt

Gemini Deep Research hallucinated ~12.7% of GitHub URLs across both batches (28 of 221). This validation step tests all Gemini-provided URLs against the GitHub API and removes any that return 404. Scraper-found URLs (from the platform's own website) are kept even if they 404 — the platform genuinely advertised a dead link.

```bash
# Validate and remove bad Gemini URLs (dry run first)
python3 validate_github_urls.py scraped_content/ --token ghp_... --dry-run
python3 validate_github_urls.py scraped_content/ --token ghp_...
```

**Result (Feb 20, 2026):** 139 valid, 16 Gemini-hallucinated removed, 0 scraper-found 404s.

### Stage 3: AI Coding
**Scripts:** `claude_coder.py`, `chatgpt_coder.py`
**Input:** Scraped content folders (with validated GitHub data injected) + Tracker CSV
**Output:** JSON files per platform in results folders

Both AI coders receive identical:
- Scraped developer portal content (including GitHub language section if available)
- Coding prompt (see `AI_CODING_PROMPT_v2.0_FINAL.md`)
- Platform metadata (ID, name, portal URL, PLAT status)

### Stage 3b: GitHub Augmentation (AFTER AI Coding)
**Script:** `github_augment_results.py`
**Input:** scraped_content/ (with GitHub language sections) + coder results
**Output:** Updated coder result JSON files (GIT/API/SDK variables only)

A targeted supplemental pass that reads the `# GITHUB REPOSITORY LANGUAGES` section from COMBINED_CONTENT.txt and updates only GIT, GIT_url, GIT_prog_lang, GIT_prog_lang_list, API, and SDK in existing coder results. All other variables remain unchanged from the initial coding pass.

```bash
# Dry run first, then live
python3 github_augment_results.py scraped_content/ claude_results/ --dry-run
python3 github_augment_results.py scraped_content/ claude_results/
python3 github_augment_results.py scraped_content/ chatgpt_results/ --dry-run
python3 github_augment_results.py scraped_content/ chatgpt_results/
```

**Result (Feb 20, 2026):** 84 Claude / 87 ChatGPT platforms updated with GitHub language data.

### Stage 4: Human Coding
**Input:** `HUMAN_CODING_TEMPLATE.xlsx`
**Output:** `HUMAN_CODING_RESULTS.csv`

Human coder manually visits developer portals for 16-platform IRR subset and codes all variables following the same codebook.

### Stage 5: IRR Calculation
**Script:** `irr_calculator.py`
**Input:** Human results + AI results folders
**Output:** IRR reports with agreement percentages, Cohen's Kappa, ICC

---

## File Structure

```
dissertation_batch_api/
├── Scripts
│   ├── selenium_scraper.py     # Web scraping (Stage 2)
│   ├── inject_github_urls.py   # GitHub URL injection (Stage 2b)
│   ├── github_lang_scraper.py  # GitHub language scraping (Stage 2b)
│   ├── validate_github_urls.py # GitHub URL validation — removes hallucinated Gemini URLs (Stage 2c)
│   ├── claude_coder.py         # Claude AI coding (Stage 3)
│   ├── chatgpt_coder.py        # ChatGPT AI coding (Stage 3)
│   ├── github_augment_results.py # GitHub augmentation — updates GIT/API/SDK only (Stage 3b)
│   ├── irr_calculator.py       # IRR analysis (Stage 5)
│   └── convert_human_to_json.py # Human results conversion
│
├── Data Files
│   ├── ALL_PLATFORMS_URL_TRACKER.csv            # 901 platforms, all 10 industries (230 PLAT firms after listwise deletion)
│   ├── irr_16_tracker.csv                       # 16 IRR platforms
│   ├── gemini_github_results.json               # Gemini GitHub search (merged Batch 1+2)
│   ├── gemini_github_search_prompt.txt          # Gemini prompt Batch 1 (112 platforms)
│   ├── gemini_github_search_prompt_BATCH2.txt   # Gemini prompt Batch 2 (140 platforms)
│   └── github_validation_report.json            # Record of 16 hallucinated URLs removed
│
├── Results
│   ├── scraped_content/        # All scraped platform content (239 PLAT folders)
│   ├── claude_results/         # Claude coding output (all platforms)
│   ├── chatgpt_results/        # ChatGPT coding output (all platforms)
│   ├── irr_test/               # 16-platform IRR results — DO NOT MODIFY
│   │   ├── scraped_content/
│   │   ├── claude_results/
│   │   └── chatgpt_results/
│   ├── human_results/          # Human coding (JSON)
│   └── final_output/           # Merged output
│
REFERENCE/
├── PROGRAMMING_LANGUAGES_INDEX.md  # 50 valid languages + mapping rules
├── AI_CODING_PROMPT_v2.0_FINAL.md  # Coding instructions for AI coders
└── FULL_DATASET_TASK_CONTEXT.md    # Master task tracking document
```

---

## Variable Summary (91 Variables)

### Binary Variables (0/1)
| Category | Variables |
|----------|-----------|
| Development | DEVP, DOCS, SDK, BUG, STAN |
| AI | AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA, AI_MKT |
| Communication | COM_social_media, COM_forum, COM_blog, COM_help_support, COM_live_chat, COM_Slack, COM_Discord, COM_stackoverflow, COM_training, COM_FAQ, COM_tutorials, COM_Other |
| GitHub | GIT |
| Monetization | MON |
| Events | EVENT_webinars, EVENT_virtual, EVENT_in_person, EVENT_conference, EVENT_hackathon, EVENT_other |
| Spanners | SPAN_internal, SPAN_communities, SPAN_external |
| Governance | ROLE, DATA, STORE, CERT |

### Count Variables
| Variable | Description |
|----------|-------------|
| AGE | API/SDK version count |
| API | Distinct API products |
| APIspecs | Specification languages |
| SDK_lang | Natural languages for SDK |
| SDK_prog_lang | Programming languages for SDK |
| COM | Sum of communication channels |
| EVENT | Sum of event types |
| SPAN | Sum of spanner types |

### Ordinal Variables
| Variable | Scale | Description |
|----------|-------|-------------|
| METH | 0-2 | 0=None, 1=Read-only, 2=CRUD |
| OPEN | 0-2 | 0=Open, 1=Partial, 2=Closed |

### List Variables
All `_list` and `_lang_list` variables use semicolon-separated format:
- `SDK_lang_list`: "English; Japanese; German"
- `SDK_prog_lang_list`: "Python; JavaScript; Java"

---

## IRR Metrics

| Metric | Use Case | Interpretation |
|--------|----------|----------------|
| **Percent Agreement** | All variables | % of matching codes |
| **Cohen's Kappa** | Binary/Ordinal | Accounts for chance agreement |
| **ICC** | Count variables | Intraclass correlation |

**Target:** ≥80% agreement for binary variables

---

## Changes from v1.0 to v2.0

| Change | v1.0 | v2.0 | Rationale |
|--------|------|------|-----------|
| END variable | Count of endpoints | **Removed** | Unreliable without full API docs |
| END_pages | Count | **Removed** | Derived from END |
| API_pages | Count | **Removed** | Not needed for analysis |
| METH | Count (0-7) | Ordinal (0-2) | Captures capability, not count |
| COM_social_media | Count | Binary (0/1) | Reduces bias in COM total |
| SDK | Basic binary | Linked to GIT | If GitHub has samples, SDK=1 |

---

## Command Reference

### Scraping (Stage 2)
```bash
python3 selenium_scraper.py ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv --output scraped_content/ --skip-existing
```

### GitHub Data Injection (Stage 2b)
```bash
# After Gemini search: inject URLs, then scrape GitHub languages
python3 inject_github_urls.py scraped_content/
export GITHUB_TOKEN='ghp_...'
python3 github_lang_scraper.py scraped_content/
```

### AI Coding (Stage 3)
```bash
# Full dataset coding
export ANTHROPIC_API_KEY='your-key'
python3 claude_coder.py scraped_content/ ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv --output claude_results/

export OPENAI_API_KEY='your-key'
python3 chatgpt_coder.py scraped_content/ ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv --output chatgpt_results/
```

### IRR Analysis (Stage 5)
```bash
python3 irr_calculator.py claude_results/ chatgpt_results/ --human human_results/ --output full_results/irr_analysis/
```

---

## Data Flow and Reproducibility Guide

This section documents the exact data trail for each stage of the pipeline, intended to support reproducibility. All scripts are published alongside this document.

### Platform-Level File Structure

Each platform in `scraped_content/` follows this structure:

```
scraped_content/
└── CA16_CE_Info_Systems_Ltd/
    ├── metadata.json           # Platform metadata + external links (incl. GitHub URL)
    ├── main_portal.html        # Raw scraped HTML from developer portal
    ├── docs_page.html          # Additional scraped pages (varies per platform)
    └── COMBINED_CONTENT.txt    # All scraped text concatenated + GitHub language section
```

### Data Flow: GitHub Supplemental Pipeline

The GitHub pipeline enriches scraped content with programming language data that is not available from developer portal pages alone. This addresses a limitation of web scraping: developer portals link to GitHub but do not display repository language breakdowns.

**Step 1: Gemini GitHub Search → `gemini_github_results.json`**

Gemini Deep Research (Google) was prompted in two batches to find official GitHub organization URLs for each platform firm. The prompts (`gemini_github_search_prompt.txt`, `gemini_github_search_prompt_BATCH2.txt`) instructed Gemini to search for the company's official GitHub presence and return the URL or "NONE" if not found.

- Batch 1: 112 platforms → saved as initial `gemini_github_results.json`
- Batch 2: 140 platforms → merged into `gemini_github_results.json`
- Final: 252 entries total (155 with GitHub URLs, 97 marked NONE)

*Data location:* `dissertation_batch_api/gemini_github_results.json`

**Step 2: URL Injection → `metadata.json` (per platform)**

`inject_github_urls.py` reads `gemini_github_results.json` and, for each platform that does not already have a GitHub URL from the Selenium scraper, adds the Gemini-provided URL to the platform's `metadata.json` under `external_links.github`.

```json
{
  "platform_id": "CA16",
  "platform_name": "CE Info Systems Ltd",
  "portal_url": "https://www.mapmyindia.com/api/",
  "external_links": {
    "github": "https://github.com/mappls-api"
  }
}
```

- 99 platforms already had a GitHub URL from the Selenium scraper (scraper detected the link on the developer portal)
- 44 platforms received a new GitHub URL from Gemini
- Total: 143 platforms with GitHub URLs in metadata.json

*Data location:* `scraped_content/{platform_id}_{name}/metadata.json`

**Step 3: URL Validation → removes bad URLs**

`validate_github_urls.py` tests all 155 Gemini-provided URLs against the GitHub API (`/orgs/{owner}` and `/users/{owner}` endpoints). URLs returning HTTP 404 are classified as Gemini hallucinations. For hallucinated URLs, the script removes the `github` key from `metadata.json` and removes any `# GITHUB REPOSITORY LANGUAGES` section from `COMBINED_CONTENT.txt`.

Scraper-found URLs (from the platform's own website) are distinguished from Gemini-injected URLs by checking whether the GitHub URL appears in the raw scraped HTML files. Only Gemini-injected 404s are removed; scraper-found 404s are kept because the platform genuinely advertised the link.

- 139 URLs validated as real GitHub organizations/users
- 16 URLs identified as Gemini hallucinations and removed
- 0 scraper-found 404s (all dead links were Gemini-injected)
- Total Gemini hallucination rate: 12.7% (28 of 221 non-NONE URLs across both validation passes)

*Data location:* `dissertation_batch_api/github_validation_report.json`

**Step 4: GitHub Language Scraping → `COMBINED_CONTENT.txt` (per platform)**

`github_lang_scraper.py` reads the GitHub URL from each platform's `metadata.json`, queries the GitHub API for the organization's public repositories (first page only, up to 30 repos, sorted by most recently pushed), and appends a structured section to `COMBINED_CONTENT.txt`. This mirrors what a human researcher would observe visiting the organization's GitHub landing page.

The appended section follows this format:

```
# GITHUB REPOSITORY LANGUAGES
## Source: https://github.com/mappls-api
================================================================================

Top languages: Swift, HTML, Kotlin, Dart, Java, TypeScript

Repositories:
  mappls-location-capture-sdk-ios-distribution — Swift
  mappls-android-sdk — Kotlin
  mappls-flutter-sdk — Dart
  ...
```

API usage: 1-2 calls per platform (one to list repos, optionally one fallback from `/orgs/` to `/users/`). A GitHub personal access token provides 5,000 requests/hour vs. 60/hour unauthenticated.

- 101 platforms received GitHub language data
- 91 platforms had no GitHub URL to query
- 47 platforms had URLs but returned no data (404s, empty orgs, or no public repos)

*Data location:* Appended to `scraped_content/{platform_id}_{name}/COMBINED_CONTENT.txt`

**Step 5: AI Coding → `{coder}_results/{platform_id}_{coder}.json`**

Both AI coders (Claude Sonnet, GPT-4o) read the full `COMBINED_CONTENT.txt` for each platform, which now includes the GitHub language section alongside the scraped developer portal content. The coders see the GitHub data as part of the content they analyze and use it to code GIT=1, GIT_prog_lang, GIT_prog_lang_list, and to infer API/SDK presence from repository names and descriptions.

Each coder produces one JSON file per platform containing all 87+ variable codings plus metadata (analysis date, model, PLAT status, success/error).

*Data location:* `dissertation_batch_api/claude_results/{platform_id}_claude.json` and `dissertation_batch_api/chatgpt_results/{platform_id}_chatgpt.json`

**Step 6: GitHub Augmentation → updates existing JSON results**

`github_augment_results.py` is a targeted post-coding pass. It reads the `# GITHUB REPOSITORY LANGUAGES` section from `COMBINED_CONTENT.txt` and programmatically updates only 6 variables in existing coder results:

| Variable | Augmentation Logic |
|----------|-------------------|
| GIT | Set to 1 if platform has GitHub language data |
| GIT_url | Set to the GitHub organization URL |
| GIT_prog_lang | Count of distinct programming languages found |
| GIT_prog_lang_list | Semicolon-separated list of languages (mapped to codebook) |
| API | Incremented if repository names contain API keywords (api, rest-api, graphql, swagger) |
| SDK | Set to 1 if repository names contain SDK keywords (sdk, library, sample, quickstart) |

All other 81 variables are preserved unchanged from the initial coding pass. This two-pass approach was chosen because: (a) the initial coders correctly identify most variables from portal content, and (b) re-running the full coder would be expensive and could introduce non-deterministic variation in variables that were already correctly coded.

- Claude: 84 platforms updated, 16 no change needed
- ChatGPT: 87 platforms updated, 13 no change needed

*Data location:* Updates in-place in `claude_results/` and `chatgpt_results/`. Audit trail saved as `{results_dir}/github_augment_log.json`.

**Step 7: Language Normalization → `language_data/language_summary.csv`**

`normalize_languages.py` standardizes all language strings across both coder result sets to English:

- Maps native script labels (日本語→Japanese, 한국어→Korean, Русский→Russian, 简体中文→Simplified Chinese, etc.)
- Maps regional variants (Español (España)→Spanish, Português (Brasil)→Portuguese, English (UK)→English, etc.)
- Deduplicates after normalization (e.g., if both "Español" and "Spanish" appeared, they collapse to one)
- Updates corresponding `_lang` count variables after deduplication
- Exports `language_summary.csv` with all language data for R analysis (1808 rows: 904 platforms × 2 coders)

```bash
python3 normalize_languages.py claude_results/ chatgpt_results/ \
    --output language_data/ \
    --tracker ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv
```

*Data location:* `dissertation_batch_api/language_data/language_summary.csv`, `language_data/normalization_log.txt`

**Step 8: IRR Calculation → `irr_analysis/`**

`irr_calculator.py` computes inter-rater reliability across 45 variables (35 binary + 10 count):

- Binary variables: Gwet's AC1 (prevalence-resistant), Cohen's Kappa, Krippendorff's Alpha (nominal)
- Count variables: ICC(2,1), Krippendorff's Alpha (interval)
- All variables: Percent agreement

Variables excluded from IRR:
- `LINGUISTIC_VARIETY`, `programming_lang_variety` — computed in final R analysis, not coded
- `GIT_prog_lang` — deterministic from GitHub augmentation (100% agreement by design)
- `OPEN` — dropped for poor reliability (AC1 = 0.179)
- `END`, `API_pages` — dropped from codebook in v2.0
- `home_primary_lang` — coded separately by Claude, not adjudicated in IRR sample

```bash
python3 irr_calculator.py claude_results/ chatgpt_results/ --output irr_analysis/
```

**Step 9: Language Adjudication (Human Review)**

Before final analysis, a human reviewer adjudicates language disagreements using `Language_Disagreement_Review.xlsx` (in `dissertation analysis/`). This spreadsheet:

- Shows Claude vs ChatGPT side-by-side for all 8 natural language count variables and 2 programming language count variables
- Pre-fills FINAL columns where coders agree
- Highlights disagreements in yellow for human review
- Pink FINAL columns are the human's adjudicated values

After review, the adjudicated values are exported to the final dataset for R analysis.

### Reproducibility Checklist

To reproduce the full pipeline from scratch:

1. Ensure `ALL_PLATFORMS_URL_TRACKER.csv` is in `REFERENCE/` (901 platforms, 10 industries)
2. Run `selenium_scraper.py` to scrape developer portals
3. Run `dedup_scraped_content.py` to remove duplicate pages
4. Prepare `gemini_github_results.json` via Gemini Deep Research prompts
5. Run `inject_github_urls.py scraped_content/` to inject GitHub URLs
6. Run `validate_github_urls.py scraped_content/ --token ghp_...` to remove hallucinated URLs
7. Run `github_lang_scraper.py scraped_content/ --token ghp_...` to scrape GitHub languages
8. Run `claude_coder.py` and `chatgpt_coder.py` with the correct tracker
9. Run `github_augment_results.py` on both result sets
10. Run `normalize_languages.py` to standardize language strings to English
11. Run `irr_calculator.py` to compute inter-rater reliability
12. Human reviews `Language_Disagreement_Review.xlsx` and adjudicates disagreements
13. Export adjudicated dataset to R for final analysis

### R Analysis Scripts (in `dissertation analysis/`)

| Script | Purpose |
|--------|---------|
| `calculate_irr.R` | Reproduces IRR table from irr_calculator.py using R (45 variables: 35 binary + 10 count) |
| `dissertation_language_analysis.R` | Descriptive statistics on language variables by industry/PLAT type, Claude vs ChatGPT comparison |
| `01_import_and_dv.R` | Import MASTER_CODEBOOK, compute dependent variable |
| `02_ind_grow.R` | Import 5-year industry growth rates |
| `03_tables_3_and_4.R` | Apply exclusions, generate Tables 3 & 4 |
| `04_wdi_controls.R` | Import country-level controls (GDP, population, internet users) |

All scripts accept `--dry-run` for previewing changes and `--platforms` for targeted re-runs. API keys required: Anthropic (Claude coder), OpenAI (ChatGPT coder), GitHub personal access token (optional but recommended for rate limits).

---

## Contact

Questions about the coding methodology should be directed to the dissertation committee.

