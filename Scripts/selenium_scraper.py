#!/usr/bin/env python3
"""
Selenium-based Page Scraper for Developer Portals
==================================================
Uses headless Chrome to render JavaScript and capture full page content.
Handles modern SPAs (React/Vue/Angular) that require JS execution.

Usage:
    python3 selenium_scraper.py tracker.csv --platforms VG1,VG4,VG7
    python3 selenium_scraper.py tracker.csv --output scraped_content/

Requirements:
    pip3 install selenium webdriver-manager pandas
"""

import os
import sys
import json
import time
import hashlib
import argparse
import re
from datetime import datetime
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import pandas as pd
except ImportError:
    print("ERROR: pandas not installed. Run: pip3 install pandas")
    sys.exit(1)

try:
    from selenium import webdriver
    from selenium.webdriver.chrome.service import Service
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.common.exceptions import TimeoutException, WebDriverException
except ImportError:
    print("ERROR: selenium not installed. Run: pip3 install selenium")
    sys.exit(1)

try:
    from webdriver_manager.chrome import ChromeDriverManager
except ImportError:
    print("ERROR: webdriver-manager not installed. Run: pip3 install webdriver-manager")
    sys.exit(1)


# ============================================================================
# CONFIGURATION
# ============================================================================

MAX_PAGES_PER_SITE = 50
PAGE_LOAD_TIMEOUT = 30  # seconds to wait for page load
JS_RENDER_WAIT = 3  # seconds to wait for JS to render after page load
REQUEST_DELAY = 2  # seconds between requests
MIN_PAGE_CHARS = 200  # Skip pages with less content than this (login walls, empty shells)
MAX_COMBINED_CHARS = 500000  # Cap combined content file size
CONTENT_HASH_DEDUP = True  # Enable content-based deduplication

# Keywords to find important pages in navigation
# Mapped to coding variables: API, DOCS, SDK, GIT, COM_*, DATA, STORE, CERT, ROLE, OPEN, etc.
NAV_KEYWORDS = {
    # APPLICATION RESOURCES (API, END, METH)
    'api': ['api', 'apis', 'reference', 'endpoints', 'rest', 'graphql', 'openapi', 'swagger'],

    # DEVELOPMENT RESOURCES (DOCS, SDK, BUG, STAN)
    'documentation': ['docs', 'documentation', 'guide', 'guides', 'getting-started', 'quickstart', 'overview'],
    'sdk': ['sdk', 'sdks', 'library', 'libraries', 'download', 'client', 'packages'],
    'sandbox': ['sandbox', 'test', 'testing', 'debug', 'playground', 'console', 'try-it'],
    'bug': ['bug', 'bugs', 'issue', 'issues', 'known-issues', 'troubleshoot', 'troubleshooting', 'problem', 'error'],
    'standards': ['standard', 'standards', 'specification', 'spec', 'protocol', 'rfc', 'openapi', 'swagger', 'schema'],
    'samples': ['sample', 'samples', 'example', 'examples', 'demo', 'demos', 'code-samples', 'starter'],
    'changelog': ['changelog', 'release-notes', 'releases', 'version', 'whats-new', 'updates'],

    # SOCIAL - COMMUNITY (COM_*)
    'forum': ['forum', 'forums', 'community', 'discuss', 'discussions', 'devtalk'],
    'support': ['support', 'help', 'contact', 'help-center', 'helpdesk', 'ticket'],
    'faq': ['faq', 'frequently-asked', 'questions', 'q-and-a', 'knowledge-base'],
    'blog': ['blog', 'news', 'announcements', 'devblog', 'engineering-blog'],
    'training': ['training', 'learn', 'academy', 'courses', 'tutorials', 'education', 'workshop'],
    'status': ['status', 'uptime', 'incidents', 'health', 'system-status'],

    # SOCIAL - GITHUB (GIT)
    'github': ['github', 'github.com', 'gitlab', 'bitbucket', 'repository', 'source-code', 'open-source', 'samples', 'examples'],

    # SOCIAL - EXTERNAL LINKS (social media for COM_social_media)
    'social_twitter': ['twitter', 'x.com', '@'],
    'social_youtube': ['youtube', 'video', 'channel'],
    'social_linkedin': ['linkedin'],
    'social_discord': ['discord', 'discord.gg', 'discord.com'],
    'social_slack': ['slack', 'slack.com'],
    'social_stackoverflow': ['stackoverflow', 'stack-overflow'],

    # SOCIAL - EVENTS (EVENT_*)
    'events': ['events', 'webinar', 'webinars', 'conference', 'meetup', 'hackathon', 'summit', 'workshop'],

    # SOCIAL - BOUNDARY SPANNERS (SPAN_*)
    'partners': ['partner', 'partners', 'partnership', 'alliance', 'integrators', 'reseller'],
    'devrel': ['advocate', 'ambassador', 'champion', 'expert', 'mvp', 'developer-relations'],

    # GOVERNANCE (ROLE, DATA, STORE, CERT, OPEN)
    'terms': ['terms', 'tos', 'terms-of-service', 'terms-of-use', 'agreement', 'developer-agreement'],
    'privacy': ['privacy', 'privacy-policy', 'data-policy', 'gdpr', 'data-protection'],
    'legal': ['legal', 'compliance', 'policy', 'policies'],
    'pricing': ['pricing', 'plans', 'billing', 'subscription', 'free-tier', 'quota'],
    'store': ['marketplace', 'app-store', 'store', 'gallery', 'directory', 'catalog', 'exchange'],
    'certification': ['certification', 'certified', 'approval', 'review', 'verify', 'badge', 'validated'],
    'roles': ['permissions', 'roles', 'access', 'scope', 'rbac', 'admin', 'authentication', 'oauth'],

    # MONETIZATION (MON)
    'monetization': ['monetize', 'revenue', 'earn', 'payout', 'commission', 'affiliate', 'rewards'],
}


# ============================================================================
# SELENIUM SCRAPER CLASS
# ============================================================================

class SeleniumScraper:
    """Scrapes developer portals using headless Chrome for JS rendering."""

    def __init__(self, output_dir: str, headless: bool = True, verbose: bool = True):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose
        self.headless = headless
        self.driver = None

    def log(self, msg: str):
        if self.verbose:
            print(msg)

    def _is_duplicate_content(self, text: str, seen_hashes: set) -> bool:
        """Check if content is a duplicate using MD5 hash of first 500 chars."""
        if not CONTENT_HASH_DEDUP:
            return False
        content_hash = hashlib.md5(text[:500].encode()).hexdigest()
        if content_hash in seen_hashes:
            return True
        seen_hashes.add(content_hash)
        return False

    def setup_driver(self):
        """Initialize Chrome WebDriver."""
        options = Options()
        if self.headless:
            options.add_argument('--headless=new')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--window-size=1920,1080')
        options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

        # Suppress logging
        options.add_argument('--log-level=3')
        options.add_experimental_option('excludeSwitches', ['enable-logging'])

        try:
            # Selenium 4.6+ has built-in driver management
            # Try direct Chrome first (no ChromeDriverManager needed)
            try:
                self.driver = webdriver.Chrome(options=options)
            except Exception:
                # Fall back to webdriver-manager if direct fails
                service = Service(ChromeDriverManager().install())
                self.driver = webdriver.Chrome(service=service, options=options)
            self.driver.set_page_load_timeout(PAGE_LOAD_TIMEOUT)
            return True
        except Exception as e:
            self.log(f"  ❌ Failed to initialize Chrome: {e}")
            return False

    def close_driver(self):
        """Close the WebDriver."""
        if self.driver:
            self.driver.quit()
            self.driver = None

    def fetch_page(self, url: str) -> tuple:
        """Fetch a page and wait for JS to render. Returns (html, error).
        Automatically recovers from browser session crashes."""
        for attempt in range(3):  # Up to 3 attempts (1 original + 2 retries)
            try:
                self.driver.get(url)
                # Wait for body to be present
                WebDriverWait(self.driver, PAGE_LOAD_TIMEOUT).until(
                    EC.presence_of_element_located((By.TAG_NAME, "body"))
                )
                # Additional wait for JS to render
                time.sleep(JS_RENDER_WAIT)

                html = self.driver.page_source
                return html, None
            except TimeoutException:
                return None, "Page load timeout"
            except WebDriverException as e:
                error_msg = str(e)
                if 'invalid session id' in error_msg or 'session deleted' in error_msg:
                    self.log(f"  🔄 Browser session died, restarting Chrome (attempt {attempt + 1}/3)...")
                    self.close_driver()
                    time.sleep(5)
                    if self.setup_driver():
                        self.log(f"  ✅ Chrome restarted successfully")
                        continue  # Retry the fetch
                    else:
                        return None, "Failed to restart Chrome after session crash"
                return None, error_msg[:100]
            except Exception as e:
                return None, str(e)[:100]
        return None, "Failed after 3 attempts"

    def extract_text(self, html: str) -> str:
        """Extract visible text from rendered page, preserving link URLs."""
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'html.parser')

        # Remove script, style, noscript, iframe elements
        for element in soup(['script', 'style', 'noscript', 'iframe']):
            element.decompose()

        # Convert links to [text](url) format so URLs are preserved in text
        for link in soup.find_all('a'):
            href = link.get('href', '')
            text = link.get_text(strip=True)
            if href and text and href.startswith('http'):
                link.string = f"[{text}]({href})"
            elif href and not text:
                # Icon-only links (social media buttons, etc.)
                aria = link.get('aria-label', '') or link.get('title', '')
                if aria and href.startswith('http'):
                    link.string = f"[{aria}]({href})"

        text = soup.get_text(separator='\n', strip=True)
        # Clean up multiple newlines
        text = re.sub(r'\n{3,}', '\n\n', text)
        return text

    def find_nav_links(self, base_url: str) -> dict:
        """Find navigation links in header, footer, and sidebars."""
        found_links = {}
        external_links = {}  # For GitHub, social media, etc.
        base_domain = urlparse(base_url).netloc
        # Also accept subdomains
        base_domain_parts = base_domain.split('.')
        if len(base_domain_parts) > 2:
            root_domain = '.'.join(base_domain_parts[-2:])
        else:
            root_domain = base_domain

        # External domains we want to capture (not scrape, just record)
        EXTERNAL_DOMAINS = {
            'github.com': 'github',
            'gitlab.com': 'github',
            'bitbucket.org': 'github',
            'twitter.com': 'social_twitter',
            'x.com': 'social_twitter',
            'youtube.com': 'social_youtube',
            'linkedin.com': 'social_linkedin',
            'discord.gg': 'social_discord',
            'discord.com': 'social_discord',
            'slack.com': 'social_slack',
            'stackoverflow.com': 'social_stackoverflow',
        }

        try:
            # Find all anchor elements
            links = self.driver.find_elements(By.TAG_NAME, 'a')
            self.log(f"    Found {len(links)} total links on page")

            for link in links:
                try:
                    href = link.get_attribute('href')
                    # Get text from link - try multiple methods
                    text = link.text.strip()
                    if not text:
                        text = link.get_attribute('aria-label') or ''
                    if not text:
                        text = link.get_attribute('title') or ''
                    text = text.lower()

                    if not href:
                        continue

                    # Skip anchors, javascript, mailto, tel
                    if href.startswith(('#', 'javascript:', 'mailto:', 'tel:')):
                        continue

                    # Make absolute URL
                    if not href.startswith('http'):
                        href = urljoin(base_url, href)

                    href_lower = href.lower()
                    link_domain = urlparse(href).netloc.lower()

                    # Check for external links (GitHub, social media, etc.)
                    for ext_domain, category in EXTERNAL_DOMAINS.items():
                        if ext_domain in link_domain and category not in external_links:
                            external_links[category] = href
                            display_text = text[:30] if text else "(no text)"
                            self.log(f"    Found external {category}: {display_text} -> {href[:60]}...")
                            break

                    # Check if same domain or subdomain for internal links
                    link_domain_parts = link_domain.split('.')
                    if len(link_domain_parts) > 2:
                        link_root = '.'.join(link_domain_parts[-2:])
                    else:
                        link_root = link_domain

                    # Skip external links for internal navigation (already captured above)
                    if link_root != root_domain:
                        continue

                    # Check against keywords for internal pages
                    for category, keywords in NAV_KEYWORDS.items():
                        if category in found_links:
                            continue  # Already found this category
                        for keyword in keywords:
                            if keyword in text or keyword in href_lower:
                                found_links[category] = href
                                display_text = text[:30] if text else "(no text)"
                                self.log(f"    Found {category}: {display_text} -> {href[:60]}...")
                                break
                except Exception as e:
                    continue

        except Exception as e:
            self.log(f"    Error finding links: {e}")

        # Merge external links (they won't be scraped but will be recorded)
        found_links.update(external_links)
        return found_links

    def scrape_platform(self, platform_id: str, platform_name: str, portal_url: str) -> dict:
        """Scrape a single platform's developer portal."""
        result = {
            'platform_id': platform_id,
            'platform_name': platform_name,
            'portal_url': portal_url,
            'scrape_date': datetime.now().isoformat(),
            'pages_scraped': [],
            'errors': [],
            'success': False
        }

        visited_urls = set()
        seen_hashes = set()  # For content deduplication

        # Create platform folder
        safe_name = re.sub(r'[^\w\-_]', '_', platform_name)
        platform_dir = self.output_dir / f"{platform_id}_{safe_name}"
        platform_dir.mkdir(exist_ok=True)

        self.log(f"  Fetching main portal: {portal_url}")

        # Fetch main portal
        html, error = self.fetch_page(portal_url)

        if error:
            result['errors'].append(f"Main page: {error}")
            self.log(f"  ❌ Error: {error}")
            return result

        visited_urls.add(portal_url)

        # Save main page
        main_text = self.extract_text(html)
        if len(main_text) >= MIN_PAGE_CHARS:
            self._is_duplicate_content(main_text, seen_hashes)  # Register hash
            main_file = platform_dir / "main_portal.txt"
            main_file.write_text(main_text, encoding='utf-8')
            result['pages_scraped'].append({
                'name': 'main_portal',
                'url': portal_url,
                'chars': len(main_text)
            })
            self.log(f"  ✓ Main portal: {len(main_text):,} chars")
        else:
            self.log(f"  ⚠️  Main portal too short ({len(main_text)} chars), saving anyway")
            main_file = platform_dir / "main_portal.txt"
            main_file.write_text(main_text, encoding='utf-8')
            result['pages_scraped'].append({
                'name': 'main_portal',
                'url': portal_url,
                'chars': len(main_text)
            })

        # Find navigation links
        self.log(f"  🔍 Scanning for navigation links...")
        nav_links = self.find_nav_links(portal_url)

        if not nav_links:
            self.log(f"  ⚠️  No navigation links found")

        # Separate internal vs external links
        external_prefixes = ['social_', 'github']
        external_links = {k: v for k, v in nav_links.items()
                          if any(k.startswith(p) for p in external_prefixes) or
                          'github.com' in v or 'discord' in v or 'slack' in v or
                          'twitter.com' in v or 'x.com' in v or 'linkedin' in v or
                          'youtube' in v or 'stackoverflow' in v}
        internal_links = {k: v for k, v in nav_links.items() if k not in external_links}

        # Record external links in result (won't scrape them)
        result['external_links'] = external_links
        if external_links:
            self.log(f"  📎 External links found: {list(external_links.keys())}")

        pages_scraped = 1

        # Scrape each internal page (not external)
        for page_name, page_url in internal_links.items():
            if pages_scraped >= MAX_PAGES_PER_SITE:
                self.log(f"  ⚠️  Max pages reached ({MAX_PAGES_PER_SITE})")
                break

            if page_url in visited_urls:
                continue

            time.sleep(REQUEST_DELAY)
            self.log(f"  Fetching {page_name}: {page_url[:60]}...")

            page_html, page_error = self.fetch_page(page_url)
            visited_urls.add(page_url)

            if page_error:
                result['errors'].append(f"{page_name}: {page_error}")
                self.log(f"    ❌ Error: {page_error}")
                continue

            page_text = self.extract_text(page_html)

            # Dedup and min-size checks
            if len(page_text) < MIN_PAGE_CHARS:
                self.log(f"    ⚠️  Skipping {page_name}: too short ({len(page_text)} chars)")
                continue
            if self._is_duplicate_content(page_text, seen_hashes):
                self.log(f"    ⚠️  Skipping {page_name}: duplicate content")
                continue

            page_file = platform_dir / f"{page_name}.txt"
            page_file.write_text(page_text, encoding='utf-8')

            result['pages_scraped'].append({
                'name': page_name,
                'url': page_url,
                'chars': len(page_text)
            })
            pages_scraped += 1
            self.log(f"  ✓ {page_name}: {len(page_text):,} chars")

            # Find sub-links from this page (depth 2)
            sub_links = self.find_nav_links(page_url)
            for sub_name, sub_url in sub_links.items():
                if pages_scraped >= MAX_PAGES_PER_SITE:
                    break
                if sub_url in visited_urls:
                    continue
                # Allow sub-pages even if the category was found at depth 1
                # (e.g., documentation -> getting-started is also "documentation")
                if sub_name in internal_links and sub_url == internal_links.get(sub_name):
                    continue  # Only skip if it's the exact same URL

                time.sleep(REQUEST_DELAY)
                self.log(f"  Fetching {sub_name} (from {page_name}): {sub_url[:50]}...")

                sub_html, sub_error = self.fetch_page(sub_url)
                visited_urls.add(sub_url)

                if sub_error:
                    continue

                sub_text = self.extract_text(sub_html)

                # Dedup and min-size checks
                if len(sub_text) < MIN_PAGE_CHARS:
                    self.log(f"    ⚠️  Skipping {page_name}_{sub_name}: too short ({len(sub_text)} chars)")
                    continue
                if self._is_duplicate_content(sub_text, seen_hashes):
                    self.log(f"    ⚠️  Skipping {page_name}_{sub_name}: duplicate content")
                    continue

                sub_file = platform_dir / f"{page_name}_{sub_name}.txt"
                sub_file.write_text(sub_text, encoding='utf-8')

                result['pages_scraped'].append({
                    'name': f"{page_name}_{sub_name}",
                    'url': sub_url,
                    'chars': len(sub_text)
                })
                pages_scraped += 1
                self.log(f"  ✓ {page_name}_{sub_name}: {len(sub_text):,} chars")

                # Depth 3: follow links from depth-2 pages
                if pages_scraped < MAX_PAGES_PER_SITE:
                    depth3_links = self.find_nav_links(sub_url)
                    for d3_name, d3_url in depth3_links.items():
                        if pages_scraped >= MAX_PAGES_PER_SITE:
                            break
                        if d3_url in visited_urls:
                            continue

                        time.sleep(REQUEST_DELAY)
                        self.log(f"  Fetching {d3_name} (depth 3, from {sub_name}): {d3_url[:50]}...")

                        d3_html, d3_error = self.fetch_page(d3_url)
                        visited_urls.add(d3_url)

                        if d3_error:
                            continue

                        d3_text = self.extract_text(d3_html)

                        if len(d3_text) < MIN_PAGE_CHARS:
                            self.log(f"    ⚠️  Skipping depth-3 {d3_name}: too short ({len(d3_text)} chars)")
                            continue
                        if self._is_duplicate_content(d3_text, seen_hashes):
                            self.log(f"    ⚠️  Skipping depth-3 {d3_name}: duplicate content")
                            continue

                        d3_file = platform_dir / f"{page_name}_{sub_name}_{d3_name}.txt"
                        d3_file.write_text(d3_text, encoding='utf-8')

                        result['pages_scraped'].append({
                            'name': f"{page_name}_{sub_name}_{d3_name}",
                            'url': d3_url,
                            'chars': len(d3_text)
                        })
                        pages_scraped += 1
                        self.log(f"  ✓ {page_name}_{sub_name}_{d3_name}: {len(d3_text):,} chars (depth 3)")

        # Create combined content file
        self.create_combined_content(platform_dir, result)

        # Save metadata
        metadata_file = platform_dir / "metadata.json"
        metadata_file.write_text(json.dumps(result, indent=2), encoding='utf-8')

        result['success'] = len(result['pages_scraped']) > 0
        return result

    def create_combined_content(self, platform_dir: Path, result: dict):
        """Combine all scraped pages into a single file."""
        combined = []
        combined.append(f"# PLATFORM: {result['platform_name']}")
        combined.append(f"# ID: {result['platform_id']}")
        combined.append(f"# PORTAL URL: {result['portal_url']}")
        combined.append(f"# SCRAPE DATE: {result['scrape_date']}")
        combined.append(f"# PAGES SCRAPED: {len(result['pages_scraped'])}")
        total_content = sum(p.get('chars', 0) for p in result['pages_scraped'])
        combined.append(f"# TOTAL CONTENT: {total_content:,} characters")
        combined.append(f"# CRAWL DEPTH: 3")

        # Add external links section for Claude to see
        if result.get('external_links'):
            combined.append(f"# EXTERNAL LINKS FOUND:")
            for link_type, url in result['external_links'].items():
                combined.append(f"#   {link_type}: {url}")

        combined.append("=" * 80)
        combined.append("")

        for page_info in result['pages_scraped']:
            page_file = platform_dir / f"{page_info['name']}.txt"
            if page_file.exists():
                combined.append("")
                combined.append("=" * 80)
                combined.append(f"## PAGE: {page_info['name'].upper()}")
                combined.append(f"## URL: {page_info['url']}")
                combined.append("=" * 80)
                combined.append("")
                combined.append(page_file.read_text(encoding='utf-8'))

        combined_text = '\n'.join(combined)

        # Cap combined content file size
        total_chars = len(combined_text)
        if total_chars > MAX_COMBINED_CHARS:
            combined_text = combined_text[:MAX_COMBINED_CHARS]
            combined_text += f"\n\n[CONTENT TRUNCATED at {MAX_COMBINED_CHARS:,} chars - original was {total_chars:,} chars]"
            self.log(f"  ⚠️  Combined content capped at {MAX_COMBINED_CHARS:,} chars (was {total_chars:,})")

        combined_file = platform_dir / "COMBINED_CONTENT.txt"
        combined_file.write_text(combined_text, encoding='utf-8')

    def scrape_from_tracker(self, tracker_file: str, platform_ids: list = None,
                           limit: int = None, dry_run: bool = False, force: bool = False) -> dict:
        """Scrape platforms from a tracker file."""

        # Read tracker file
        if tracker_file.endswith('.csv'):
            df = pd.read_csv(tracker_file)
        else:
            df = pd.read_excel(tracker_file, header=1)

        # Filter to platforms with portals
        has_portal = df[df['PLAT'] != 'NONE'].copy()
        has_portal = has_portal[has_portal['developer_portal_url'].notna()]

        # Filter by specific platform IDs
        if platform_ids:
            has_portal = has_portal[has_portal['platform_ID'].isin(platform_ids)]
            self.log(f"Filtering to {len(platform_ids)} specified platforms")

        if limit:
            has_portal = has_portal.head(limit)

        total = len(has_portal)

        self.log(f"\n{'='*60}")
        self.log(f"SELENIUM DEVELOPER PORTAL SCRAPER")
        self.log(f"{'='*60}")
        self.log(f"Input file: {tracker_file}")
        self.log(f"Platforms to scrape: {total}")
        self.log(f"Output directory: {self.output_dir}")
        self.log(f"Headless mode: {self.headless}")

        if dry_run:
            self.log(f"\n🔍 DRY RUN - Not actually scraping\n")
            for _, row in has_portal.iterrows():
                self.log(f"  Would scrape: {row['platform_name']} ({row['PLAT']})")
                self.log(f"    URL: {row['developer_portal_url']}")
            return {'dry_run': True, 'platforms': total}

        self.log(f"{'='*60}\n")

        # Initialize driver
        if not self.setup_driver():
            return {'error': 'Failed to initialize Chrome WebDriver'}

        results = {
            'scrape_date': datetime.now().isoformat(),
            'total_platforms': total,
            'successful': 0,
            'failed': 0,
            'platforms': []
        }

        try:
            for idx, (_, row) in enumerate(has_portal.iterrows(), 1):
                platform_id = row['platform_ID']
                platform_name = row['platform_name']
                portal_url = row['developer_portal_url']
                plat_status = row['PLAT']

                # Skip already-scraped platforms (resume support) unless --force
                safe_name = re.sub(r'[^\w\-_]', '_', platform_name)
                platform_dir = self.output_dir / f"{platform_id}_{safe_name}"
                combined_file = platform_dir / "COMBINED_CONTENT.txt"
                if not force and combined_file.exists() and combined_file.stat().st_size > 100:
                    self.log(f"\n[{idx}/{total}] {platform_name} ({plat_status}) - SKIPPING (already scraped)")
                    results['successful'] += 1
                    continue
                elif force and combined_file.exists():
                    self.log(f"\n[{idx}/{total}] {platform_name} ({plat_status}) - FORCE RE-SCRAPING")
                    # Clear old content
                    import shutil
                    if platform_dir.exists():
                        shutil.rmtree(platform_dir)
                    platform_dir.mkdir(exist_ok=True)

                self.log(f"\n[{idx}/{total}] {platform_name} ({plat_status})")
                self.log("-" * 60)

                result = self.scrape_platform(platform_id, platform_name, portal_url)
                results['platforms'].append(result)

                if result['success']:
                    results['successful'] += 1
                    self.log(f"  ✅ Success - {len(result['pages_scraped'])} pages scraped")
                else:
                    results['failed'] += 1
                    self.log(f"  ❌ Failed")

                if idx < total:
                    time.sleep(REQUEST_DELAY)

        finally:
            self.close_driver()

        # Save summary
        summary_file = self.output_dir / "scrape_summary.json"
        summary_file.write_text(json.dumps(results, indent=2), encoding='utf-8')

        self.log(f"\n{'='*60}")
        self.log("SCRAPING COMPLETE")
        self.log(f"{'='*60}")
        self.log(f"✅ Successful: {results['successful']}")
        self.log(f"❌ Failed: {results['failed']}")
        self.log(f"📁 Output: {self.output_dir}")

        return results


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Selenium-based scraper for JS-rendered developer portals',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 selenium_scraper.py tracker.csv --output scraped_content/
    python3 selenium_scraper.py tracker.csv --platforms VG1,VG4,VG7
    python3 selenium_scraper.py tracker.csv --no-headless  # See browser
    python3 selenium_scraper.py tracker.csv --dry-run
        """
    )
    parser.add_argument('input_file', help='Search tracker file (xlsx or csv)')
    parser.add_argument('--output', '-o', default='scraped_content', help='Output directory')
    parser.add_argument('--platforms', '-p', help='Comma-separated platform IDs (e.g., VG1,VG4,VG7)')
    parser.add_argument('--limit', '-l', type=int, help='Limit number of platforms')
    parser.add_argument('--no-headless', action='store_true', help='Show browser window')
    parser.add_argument('--dry-run', action='store_true', help='Preview without scraping')
    parser.add_argument('--force', '-f', action='store_true', help='Force re-scrape even if already scraped')
    parser.add_argument('--quiet', '-q', action='store_true', help='Minimal output')

    args = parser.parse_args()

    if not os.path.exists(args.input_file):
        print(f"ERROR: Input file not found: {args.input_file}")
        sys.exit(1)

    # Parse platforms list
    platform_ids = None
    if args.platforms:
        platform_ids = [p.strip() for p in args.platforms.split(',')]

    scraper = SeleniumScraper(
        output_dir=args.output,
        headless=not args.no_headless,
        verbose=not args.quiet
    )

    results = scraper.scrape_from_tracker(
        tracker_file=args.input_file,
        platform_ids=platform_ids,
        limit=args.limit,
        dry_run=args.dry_run,
        force=args.force
    )

    if not args.dry_run and 'error' not in results:
        print(f"\nNext steps:")
        print(f"  1. Review scraped content in: {args.output}/")
        print(f"  2. Run Claude coder: python3 claude_coder.py {args.output}/ tracker.csv")


if __name__ == "__main__":
    main()
