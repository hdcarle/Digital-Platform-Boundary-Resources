#!/usr/bin/env python3
"""
validate_github_urls.py
========================
Validates all GitHub URLs from gemini_github_results.json against the GitHub API.
Identifies 404s and removes Gemini-injected bad URLs from metadata.json.
Also flags affected coder results where GIT should be corrected.

Usage:
    python3 validate_github_urls.py scraped_content/ --token YOUR_TOKEN --dry-run
    python3 validate_github_urls.py scraped_content/ --token YOUR_TOKEN

Steps:
    1. Tests each Gemini GitHub URL against GitHub API
    2. For 404s: checks if URL was Gemini-injected (not from scraper)
    3. Removes bad Gemini URLs from metadata.json
    4. Outputs list of platforms needing GIT correction in coder results
"""

import json
import os
import sys
import argparse
import time
import ssl
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse

# SSL setup
SSL_CONTEXT = None
try:
    import certifi
    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CONTEXT = ssl.create_default_context()
    SSL_CONTEXT.check_hostname = False
    SSL_CONTEXT.verify_mode = ssl.CERT_NONE


def github_api_check(endpoint, token=None):
    """Check if a GitHub API endpoint exists. Returns True/False."""
    url = f"https://api.github.com{endpoint}"
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'dissertation-url-validator'
    }
    if token:
        headers['Authorization'] = f'token {token}'

    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=30, context=SSL_CONTEXT) as resp:
            remaining = resp.headers.get('X-RateLimit-Remaining', '')
            if remaining and int(remaining) < 5:
                reset_ts = int(resp.headers.get('X-RateLimit-Reset', 0))
                wait_secs = max(reset_ts - int(time.time()), 0) + 2
                print(f"    Rate limit low. Waiting {wait_secs}s...")
                time.sleep(wait_secs)
            return True
    except HTTPError as e:
        if e.code == 404:
            return False
        elif e.code == 403:
            reset_ts = int(e.headers.get('X-RateLimit-Reset', 0))
            wait_secs = max(reset_ts - int(time.time()), 0) + 2
            print(f"    Rate limited. Waiting {wait_secs}s...")
            time.sleep(wait_secs)
            return github_api_check(endpoint, token)
        else:
            print(f"    HTTP {e.code} for {endpoint}")
            return False
    except URLError as e:
        print(f"    URL error: {e}")
        return None  # Network error, can't determine


def validate_github_url(github_url, token=None):
    """Validate a GitHub URL by checking if the org/user/repo exists."""
    parsed = urlparse(github_url)
    path_parts = [p for p in parsed.path.strip('/').split('/') if p]

    if len(path_parts) == 0:
        return False, "empty path"

    owner = path_parts[0]

    if len(path_parts) >= 2:
        # Specific repo: github.com/owner/repo
        repo = path_parts[1]
        exists = github_api_check(f"/repos/{owner}/{repo}", token)
        return exists, f"repo {owner}/{repo}"
    else:
        # Org/user: github.com/owner
        exists = github_api_check(f"/orgs/{owner}", token)
        if exists:
            return True, f"org {owner}"
        exists = github_api_check(f"/users/{owner}", token)
        if exists:
            return True, f"user {owner}"
        return False, f"org/user {owner}"


def was_gemini_injected(platform_id, gemini_url, scraped_dir):
    """
    Determine if a GitHub URL was injected by Gemini or found by scraper.

    Logic: Check COMBINED_CONTENT.txt for the URL. If it appears ONLY in the
    '# GITHUB REPOSITORY LANGUAGES' section or metadata reference, and NOT in
    the actual scraped page content, it was likely Gemini-injected.

    Simpler approach: check if the URL appears in the raw scraped HTML files
    (not COMBINED_CONTENT.txt which we may have modified).
    """
    # Find platform dir
    for d in os.listdir(scraped_dir):
        if d.startswith(platform_id + '_'):
            platform_path = os.path.join(scraped_dir, d)

            # Check all .html and .txt files EXCEPT COMBINED_CONTENT.txt and metadata.json
            for fname in os.listdir(platform_path):
                if fname in ('COMBINED_CONTENT.txt', 'metadata.json'):
                    continue
                fpath = os.path.join(platform_path, fname)
                if os.path.isfile(fpath):
                    try:
                        with open(fpath, encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                        if gemini_url.lower() in content.lower():
                            return False  # Found in scraped content = scraper found it
                        # Also check for the owner name in github URLs
                        parsed = urlparse(gemini_url)
                        owner = parsed.path.strip('/').split('/')[0]
                        if f'github.com/{owner}' in content.lower():
                            return False  # Scraper found a github link to this owner
                    except:
                        pass

            return True  # Not found in any scraped files = Gemini injected

    return True  # No directory found, assume Gemini


def remove_github_from_metadata(platform_id, scraped_dir, dry_run=False):
    """Remove the github URL from a platform's metadata.json."""
    for d in os.listdir(scraped_dir):
        if d.startswith(platform_id + '_'):
            meta_path = os.path.join(scraped_dir, d, 'metadata.json')
            if os.path.isfile(meta_path):
                with open(meta_path) as f:
                    meta = json.load(f)

                old_url = meta.get('external_links', {}).get('github', '')
                if old_url:
                    if dry_run:
                        print(f"    [DRY RUN] Would remove github URL from metadata.json")
                    else:
                        del meta['external_links']['github']
                        with open(meta_path, 'w') as f:
                            json.dump(meta, f, indent=2, ensure_ascii=False)
                        print(f"    Removed github URL from metadata.json")
                return True
    return False


def remove_github_from_combined(platform_id, scraped_dir, dry_run=False):
    """Remove the GITHUB REPOSITORY LANGUAGES section from COMBINED_CONTENT.txt."""
    for d in os.listdir(scraped_dir):
        if d.startswith(platform_id + '_'):
            combined_path = os.path.join(scraped_dir, d, 'COMBINED_CONTENT.txt')
            if os.path.isfile(combined_path):
                with open(combined_path) as f:
                    content = f.read()

                if '# GITHUB REPOSITORY LANGUAGES' in content:
                    # Remove the section
                    idx = content.index('# GITHUB REPOSITORY LANGUAGES')
                    # Find the end (next # header or end of file)
                    rest = content[idx:]
                    lines = rest.split('\n')
                    end_idx = len(lines)
                    for i, line in enumerate(lines[1:], 1):
                        if line.startswith('# ') and 'GITHUB' not in line:
                            end_idx = i
                            break
                    section = '\n'.join(lines[:end_idx])
                    new_content = content.replace(section, '').strip() + '\n'

                    if dry_run:
                        print(f"    [DRY RUN] Would remove GITHUB REPOSITORY LANGUAGES section")
                    else:
                        with open(combined_path, 'w') as f:
                            f.write(new_content)
                        print(f"    Removed GITHUB REPOSITORY LANGUAGES section")
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Validate Gemini GitHub URLs")
    parser.add_argument('scraped_dir', help='Path to scraped_content directory')
    parser.add_argument('--token', '-t', help='GitHub personal access token')
    parser.add_argument('--dry-run', action='store_true', help='Show what would change')
    parser.add_argument('--results', default=None, help='Path to gemini_github_results.json')
    args = parser.parse_args()

    # Load Gemini results
    if args.results:
        results_path = args.results
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        results_path = os.path.join(script_dir, 'gemini_github_results.json')

    with open(results_path) as f:
        gemini_data = json.load(f)

    gemini_urls = {e['platform_id']: e['github_url'] for e in gemini_data
                   if e['github_url'] not in ('NONE', '') and e['github_url'] is not None}

    print("=" * 60)
    print("GITHUB URL VALIDATOR")
    print("=" * 60)
    print(f"Gemini URLs to validate: {len(gemini_urls)}")
    print(f"Auth: {'Token provided' if args.token else 'No token'}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    print()

    valid_urls = []
    invalid_urls = []
    gemini_injected_invalid = []
    scraper_found_invalid = []
    network_errors = []

    for pid, url in sorted(gemini_urls.items()):
        print(f"  {pid}: {url}")
        exists, detail = validate_github_url(url, args.token)

        if exists is None:
            print(f"    ⚠️  Network error — skipping")
            network_errors.append(pid)
            continue
        elif exists:
            print(f"    ✅ Valid ({detail})")
            valid_urls.append(pid)
        else:
            print(f"    ❌ 404 NOT FOUND ({detail})")
            invalid_urls.append(pid)

            # Check if this was Gemini-injected or scraper-found
            is_gemini = was_gemini_injected(pid, url, args.scraped_dir)
            if is_gemini:
                print(f"    🔴 GEMINI-INJECTED — removing")
                gemini_injected_invalid.append((pid, url))
                remove_github_from_metadata(pid, args.scraped_dir, args.dry_run)
                remove_github_from_combined(pid, args.scraped_dir, args.dry_run)
            else:
                print(f"    🟡 SCRAPER-FOUND — platform advertises dead link (keeping)")
                scraper_found_invalid.append((pid, url))

    # Summary
    print()
    print("=" * 60)
    print("VALIDATION SUMMARY")
    print("=" * 60)
    print(f"Total validated: {len(gemini_urls)}")
    print(f"  ✅ Valid: {len(valid_urls)}")
    print(f"  ❌ Invalid (404): {len(invalid_urls)}")
    print(f"  ⚠️  Network errors: {len(network_errors)}")
    print()
    print(f"  🔴 Gemini-injected 404s (REMOVED): {len(gemini_injected_invalid)}")
    for pid, url in gemini_injected_invalid:
        print(f"     {pid}: {url}")
    print()
    print(f"  🟡 Scraper-found 404s (kept — platform advertises dead link): {len(scraper_found_invalid)}")
    for pid, url in scraper_found_invalid:
        print(f"     {pid}: {url}")

    if gemini_injected_invalid:
        print()
        print("⚠️  CODER RESULTS TO FIX:")
        print("The following platforms may have GIT=1 due to Gemini-injected URLs that don't exist.")
        print("After re-coding or manual review, GIT should be set to 0 for these (unless")
        print("the platform has a GitHub reference in its actual scraped content):")
        for pid, url in gemini_injected_invalid:
            print(f"  - {pid}")

    # Save report
    report = {
        'valid': valid_urls,
        'invalid_gemini': [(p, u) for p, u in gemini_injected_invalid],
        'invalid_scraper': [(p, u) for p, u in scraper_found_invalid],
        'network_errors': network_errors
    }
    report_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'github_validation_report.json')
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"\nReport saved to: {report_path}")


if __name__ == '__main__':
    main()
