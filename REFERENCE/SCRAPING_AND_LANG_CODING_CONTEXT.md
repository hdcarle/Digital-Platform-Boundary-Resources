# Scraping & Language Coding Context Document
## For use in the next Cowork session

**Created:** 2026-02-18
**Purpose:** Handoff document so the next conversation has full context for web scraping developer portals and generating the LANGUAGE_CODING_WORKSHEET.

---

## 1. Current State of Scraping

### What's Been Scraped
- **146 platform folders** in `dissertation_batch_api/scraped_content/`
- **2,222 total files** (text files of scraped developer portal pages)
- Each platform folder contains individual page files (e.g., `api.txt`, `documentation.txt`) plus a `COMBINED_CONTENT.txt`

### Deduplication Completed
- A prior session ran `dedup_scraped_content.py` to remove duplicate pages
- **68 platforms affected**, **191 duplicate files moved** to `scraped_content_dupes/`
- **6.6 MB saved** in duplicate content
- Dedup report: `dissertation_batch_api/dedup_report.json`

### What Still Needs Scraping
- **120 platforms** have URLs but no scraped content yet
- **102 of these are CC (Credit Card/Banking)** — newly classified as platform firms after Gemini PLAT verification identified Open Banking/PSD2 developer portals
- Remaining 18: 7 VG, 5 PE, 4 CA, 2 CP

### Scraper Configuration
- **Script:** `dissertation_batch_api/selenium_scraper.py`
- **Requirements:** `selenium`, `webdriver-manager`, `pandas`
- **Key settings (updated in prior session):**
  - Crawl depth: 3 (was 1)
  - MAX_PAGES: 50 (was 100)
  - Min content threshold: 200 chars
  - Max content cap: 500K chars per platform
  - `--force` flag available for re-scraping
- **Must run on user's local machine** (requires Chrome browser + internet access)

### Tracker File for Scraping
- **Primary:** `REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv` (901 platforms, 230 with URLs after listwise deletion)
- Columns: `platform_ID, platform_name, industry, home_country_name, home_country_iso3c, developer_portal_url, PLAT, PLAT_Notes, search_status`

---

## 2. Language Coding Worksheet

### What It Is
The LANGUAGE_CODING_WORKSHEET is a list of platforms needing human coding for language-related variables (`_lang` variables). These were excluded from automated IRR because the AI coders can't reliably count natural languages on non-English pages.

### Why It Can't Be Generated Yet
The worksheet requires scraped content to identify which platforms have multi-language developer portals. The 120 unscraped platforms (especially the 102 CC banking portals) need to be scraped first.

### Variables That Need Human Coding
- `SDK_lang` (count of SDK languages)
- `COM_lang` (count of community languages)
- `GIT_lang` (count of Git repo languages)
- `SPAN_lang` (count of boundary spanning languages)
- `ROLE_lang` (count of role documentation languages)
- `DATA_lang` (count of data governance languages)
- `STORE_lang` (count of app store languages)
- `CERT_lang` (count of certification languages)
- ~~`OPEN_lang`~~ — DROPPED (OPEN variable dropped from analysis)
- `LINGUISTIC_VARIETY` (total distinct natural languages)
- `programming_lang_variety` (total programming languages)

### Excluded from Automated IRR
These `_lang` variables plus `OPEN` were excluded from the IRR calculations in `irr_summary_no_lang.json`, bringing the variable set from 46 → 36.

---

## 3. Key Files

| File | Location | Purpose |
|------|----------|---------|
| URL Tracker | `REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv` | Master list of 901 platforms with URLs |
| Master Codebook | `REFERENCE/MASTER_CODEBOOK.xlsx` | 6,617 dyadic rows, 126 columns |
| Selenium Scraper | `dissertation_batch_api/selenium_scraper.py` | Web scraping script (run locally) |
| Dedup Script | `dissertation_batch_api/dedup_scraped_content.py` | Post-processing deduplication |
| Dedup Report | `dissertation_batch_api/dedup_report.json` | Results of last dedup run |
| Scraped Content | `dissertation_batch_api/scraped_content/` | 146 folders, 2,222 files |
| Scraped Dupes | `dissertation_batch_api/scraped_content_dupes/` | 68 folders of removed duplicates |

---

## 4. Workflow for Next Session

1. **Set up environment** on local machine:
   ```bash
   pip3 install selenium webdriver-manager pandas
   ```

2. **Scrape the 120 remaining platforms:**
   ```bash
   cd dissertation_batch_api
   python3 selenium_scraper.py ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv --output scraped_content/
   ```
   Note: This will only scrape platforms that don't already have folders.

3. **Run deduplication:**
   ```bash
   python3 dedup_scraped_content.py scraped_content/ --archive scraped_content_dupes/
   ```

4. **Generate LANGUAGE_CODING_WORKSHEET** from scraped content (script TBD — needs to identify multi-language platforms and create a checklist for human coding)

---

## 5. Important Notes

- **CC Banking portals** may require special handling — many use OAuth/redirect flows that Selenium may struggle with
- **Non-English portals** (e.g., CP90 Pantum at developer.pantum.com) exist and are valid — the scraper should capture content even if it's in another language
- **URLs were verified** in the current session — all 238 platform URLs are confirmed working as of Feb 18, 2026
- **openpyxl workaround** for this VM: If editing the MASTER_CODEBOOK.xlsx, you need `sys.path.insert(0, '/tmp/pyfix')` before importing openpyxl due to urllib corruption in the sandbox
- **PLAT distribution after all changes:** PUBLIC=135, REGISTRATION=82, RESTRICTED=25, NONE=661
