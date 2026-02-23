#!/usr/bin/env python3
"""
GitHub Language Scraper
=======================
Extracts programming languages from GitHub repositories linked in scraped platform data.

Reads GitHub URLs from metadata.json files in scraped_content/ directories,
queries the GitHub API for repository languages, and injects the results into
each platform's COMBINED_CONTENT.txt so the AI coders can see them.

Usage:
    python3 github_lang_scraper.py scraped_content/
    python3 github_lang_scraper.py irr_test/scraped_content/
    python3 github_lang_scraper.py scraped_content/ --token YOUR_GITHUB_TOKEN

Notes:
    - No authentication required for public repos (60 requests/hour limit)
    - With a GitHub personal access token: 5,000 requests/hour
    - Only processes github.com URLs (skips developer.*.com, open-source pages, etc.)
    - Injects a # GITHUB REPOSITORY LANGUAGES section into COMBINED_CONTENT.txt
"""

import os
import sys
import json
import time
import argparse
import re
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
import ssl

# Fix macOS SSL certificate issue
# Try certifi first, fall back to unverified context
SSL_CONTEXT = None
try:
    import certifi
    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    # No certifi available — create unverified context as fallback
    SSL_CONTEXT = ssl.create_default_context()
    SSL_CONTEXT.check_hostname = False
    SSL_CONTEXT.verify_mode = ssl.CERT_NONE


# Valid programming languages from the codebook (for filtering/matching)
VALID_PROG_LANGS = [
    "Ada", "Apex", "Assembly", "Bash/Shell", "C", "C#", "C++", "Clojure",
    "Cobol", "Crystal", "Dart", "Delphi", "Elixir", "Erlang", "F#",
    "Fortran", "GDScript", "Go", "Groovy", "Haskell", "HTML/CSS", "Java",
    "JavaScript", "Julia", "Kotlin", "Lisp", "Lua", "MATLAB", "MicroPython",
    "Nim", "Objective-C", "OCaml", "Perl", "PHP", "PowerShell", "Prolog",
    "Python", "R", "Ruby", "Rust", "Scala", "Solidity", "SQL", "Swift",
    "TypeScript", "VBA", "Visual Basic", "Zephyr"
]

# Map GitHub API language names to codebook names
LANG_MAP = {
    "Shell": "Bash/Shell",
    "Batchfile": "Bash/Shell",
    "HTML": "HTML/CSS",
    "CSS": "HTML/CSS",
    "SCSS": "HTML/CSS",
    "Sass": "HTML/CSS",
    "Less": "HTML/CSS",
    "Makefile": None,  # Not a programming language
    "Dockerfile": None,
    "CMake": None,
    "Jupyter Notebook": "Python",  # Typically Python
    "Objective-C++": "Objective-C",
    "Visual Basic .NET": "Visual Basic",
    "HLSL": None,  # Shader language, not in codebook
    "GLSL": None,
    "ShaderLab": None,
    "Starlark": None,
    "Nix": None,
    "Smarty": None,
    "Mustache": None,
    "Handlebars": None,
    "EJS": None,
    "Svelte": "JavaScript",
    "Vue": "JavaScript",
    "TSQL": "SQL",
    "PLpgSQL": "SQL",
    "Zig": None,  # Not in codebook
}


def is_github_url(url: str) -> bool:
    """Check if URL is actually a github.com URL (not developer.*.com etc.)."""
    parsed = urlparse(url)
    return 'github.com' in parsed.netloc.lower()


def extract_github_info(url: str) -> dict:
    """
    Parse a GitHub URL to extract owner and optional repo.
    Returns {'type': 'org'|'repo'|'unknown', 'owner': str, 'repo': str|None}
    """
    parsed = urlparse(url)
    path_parts = [p for p in parsed.path.strip('/').split('/') if p]

    if len(path_parts) == 0:
        return {'type': 'unknown', 'owner': None, 'repo': None}
    elif len(path_parts) == 1:
        # github.com/owner — this is an org or user page
        return {'type': 'org', 'owner': path_parts[0], 'repo': None}
    else:
        # github.com/owner/repo/... — specific repo
        return {'type': 'repo', 'owner': path_parts[0], 'repo': path_parts[1]}


def github_api_get(endpoint: str, token: str = None, retry_on_rate_limit: bool = True) -> dict:
    """Make a GitHub API request with rate limit handling."""
    url = f"https://api.github.com{endpoint}"
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'dissertation-lang-scraper'
    }
    if token:
        headers['Authorization'] = f'token {token}'

    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=30, context=SSL_CONTEXT) as resp:
            # Check remaining rate limit
            remaining = resp.headers.get('X-RateLimit-Remaining', '')
            if remaining and int(remaining) < 5:
                reset_ts = int(resp.headers.get('X-RateLimit-Reset', 0))
                wait_secs = max(reset_ts - int(time.time()), 0) + 2
                print(f"    ⏳ Only {remaining} API calls left. Waiting {wait_secs}s for reset...")
                time.sleep(wait_secs)
            return json.loads(resp.read().decode())
    except HTTPError as e:
        if e.code == 403:
            reset_ts = int(e.headers.get('X-RateLimit-Reset', 0))
            wait_secs = max(reset_ts - int(time.time()), 0) + 2
            if retry_on_rate_limit and wait_secs < 3700:
                print(f"    ⏳ Rate limited. Waiting {wait_secs}s for reset...")
                time.sleep(wait_secs)
                return github_api_get(endpoint, token, retry_on_rate_limit=False)
            else:
                print(f"    ⚠️  Rate limited. Reset in {wait_secs}s — too long, skipping.")
                return None
        elif e.code == 404:
            print(f"    ⚠️  Not found: {endpoint}")
            return None
        else:
            print(f"    ⚠️  HTTP {e.code}: {endpoint}")
            return None
    except URLError as e:
        print(f"    ⚠️  URL error: {e}")
        return None


def get_org_languages(owner: str, token: str = None) -> dict:
    """
    Get programming languages visible on a GitHub org's MAIN PAGE.
    Mirrors what a human sees visiting github.com/{owner}:
      - The "Top languages" bar at the top (most prominent languages)
      - The language tag on each repo scrolling down the page

    Uses 1-2 API calls total. The API returns first page of repos (up to 30),
    same as what loads on the org landing page. Each repo includes a 'language'
    field (its primary language). We collect all unique languages — this matches
    what a human sees scrolling through.

    Returns {'languages': {lang: count, ...}, 'repos_checked': int, 'top_repos': [...]}
    """
    # First try as org, then as user — first page only (what human sees)
    repos = github_api_get(f"/orgs/{owner}/repos?per_page=30&sort=pushed&direction=desc", token)
    if repos is None:
        repos = github_api_get(f"/users/{owner}/repos?per_page=30&sort=pushed&direction=desc", token)
    if repos is None or not isinstance(repos, list):
        return None

    # Filter out forks (human wouldn't count forked repos)
    non_fork_repos = [r for r in repos if not r.get('fork', False)]

    # Collect every unique primary language from repos on the page
    lang_counts = {}
    top_repos = []

    for repo in non_fork_repos:
        repo_name = repo.get('name', '')
        primary_lang = repo.get('language')
        if primary_lang:
            lang_counts[primary_lang] = lang_counts.get(primary_lang, 0) + 1
            top_repos.append({'name': repo_name, 'languages': {primary_lang: 1}})

    return {
        'languages': lang_counts,
        'repos_checked': len(non_fork_repos),
        'top_repos': top_repos  # all repos from the page, like human would see
    }


def get_repo_languages(owner: str, repo: str, token: str = None) -> dict:
    """Get programming languages for a specific repo."""
    langs = github_api_get(f"/repos/{owner}/{repo}/languages", token)
    if langs is None:
        return None

    return {
        'languages': langs,
        'repos_checked': 1,
        'top_repos': [{'name': repo, 'languages': langs}]
    }


def map_to_codebook_langs(github_langs: dict) -> list:
    """
    Map GitHub API language names to codebook programming language names.
    Returns sorted list of unique codebook language names.
    """
    codebook_langs = set()

    for github_lang, bytes_count in github_langs.items():
        # Direct match (case-insensitive)
        matched = False
        for valid in VALID_PROG_LANGS:
            if github_lang.lower() == valid.lower():
                codebook_langs.add(valid)
                matched = True
                break

        if not matched:
            # Check mapping table
            mapped = LANG_MAP.get(github_lang)
            if mapped:
                codebook_langs.add(mapped)
            elif mapped is None:
                pass  # Explicitly excluded
            else:
                # Unknown language — skip but log
                pass

    return sorted(codebook_langs)


def format_lang_section(github_url: str, lang_data: dict, codebook_langs: list) -> str:
    """
    Format the language data to inject into COMBINED_CONTENT.txt.
    Mimics what a human sees on the GitHub org main page:
      - "Top languages" bar showing most-used languages
      - Each repo listed with its primary language tag
    Does NOT pre-compute GIT_prog_lang — the AI coder should count
    the same way a human would from what's visible on the page.
    """
    lines = []
    lines.append("")
    lines.append("=" * 80)
    lines.append("## GITHUB REPOSITORY LANGUAGES")
    lines.append(f"## Source: {github_url}")
    lines.append("=" * 80)
    lines.append("")

    # "Top languages" bar — sorted by frequency, like the GitHub org page shows
    sorted_langs = sorted(lang_data['languages'].items(), key=lambda x: -x[1])
    top_lang_names = [lang for lang, _ in sorted_langs]

    lines.append(f"Top languages: {', '.join(top_lang_names)}")
    lines.append("")

    # Repo listing with language tags — like scrolling the org page
    if lang_data['top_repos']:
        lines.append("Repositories:")
        for repo in lang_data['top_repos']:
            repo_langs = ', '.join(repo['languages'].keys())
            lines.append(f"  {repo['name']} — {repo_langs}")
        lines.append("")

    return '\n'.join(lines)


def process_platform(platform_dir: str, token: str = None) -> bool:
    """Process a single platform directory. Returns True if languages were found."""
    meta_path = os.path.join(platform_dir, 'metadata.json')
    content_path = os.path.join(platform_dir, 'COMBINED_CONTENT.txt')

    if not os.path.exists(meta_path):
        return False

    meta = json.loads(open(meta_path).read())
    github_url = meta.get('external_links', {}).get('github', '')

    if not github_url or not is_github_url(github_url):
        return False

    platform_name = os.path.basename(platform_dir)
    print(f"\n  Processing {platform_name}")
    print(f"    GitHub URL: {github_url}")

    # Parse the GitHub URL
    info = extract_github_info(github_url)
    print(f"    Type: {info['type']}, Owner: {info['owner']}, Repo: {info['repo']}")

    if info['type'] == 'unknown' or not info['owner']:
        print(f"    ⚠️  Could not parse GitHub URL")
        return False

    # Get languages
    if info['type'] == 'repo' and info['repo']:
        lang_data = get_repo_languages(info['owner'], info['repo'], token)
    else:
        lang_data = get_org_languages(info['owner'], token)

    if not lang_data or not lang_data['languages']:
        print(f"    ⚠️  No languages found")
        return False

    # Map to codebook languages
    codebook_langs = map_to_codebook_langs(lang_data['languages'])
    print(f"    Found {len(lang_data['languages'])} GitHub languages → {len(codebook_langs)} codebook languages")
    print(f"    Languages: {'; '.join(codebook_langs)}")

    # Inject into COMBINED_CONTENT.txt
    if os.path.exists(content_path):
        content = open(content_path).read()

        # Remove existing GitHub language section if present (for re-runs)
        marker_start = "## GITHUB REPOSITORY LANGUAGES"
        if marker_start in content:
            # Find the section boundaries
            start_idx = content.index("=" * 80 + "\n" + marker_start) if ("=" * 80 + "\n" + marker_start) in content else content.index(marker_start)
            # Find end: next major section or end of file
            end_markers = ["\n================================================================================\n## PAGE:"]
            end_idx = len(content)
            for em in end_markers:
                idx = content.find(em, start_idx + len(marker_start))
                if idx != -1 and idx < end_idx:
                    end_idx = idx
            # Also look for double newline before next section marker
            content = content[:start_idx].rstrip() + content[end_idx:]

        # Inject after the header section
        lang_section = format_lang_section(github_url, lang_data, codebook_langs)

        # Insert after the header (after the first ===...=== separator line)
        header_end = content.find("\n================================================================================\n## PAGE:")
        if header_end != -1:
            content = content[:header_end] + lang_section + content[header_end:]
        else:
            # Append at end
            content = content + lang_section

        open(content_path, 'w').write(content)
        print(f"    ✅ Injected into COMBINED_CONTENT.txt")
    else:
        print(f"    ⚠️  No COMBINED_CONTENT.txt found")
        return False

    return True


def main():
    parser = argparse.ArgumentParser(
        description='Extract programming languages from GitHub repos linked in scraped platform data',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Process all platforms in scraped_content/:
    python3 github_lang_scraper.py scraped_content/

    # Process IRR test platforms:
    python3 github_lang_scraper.py irr_test/scraped_content/

    # With GitHub token for higher rate limits:
    python3 github_lang_scraper.py scraped_content/ --token ghp_xxxxxxxxxxxxx
        """
    )
    parser.add_argument('scraped_dir', help='Directory containing scraped platform folders')
    parser.add_argument('--token', '-t', help='GitHub personal access token (optional, increases rate limit)')
    parser.add_argument('--platforms', '-p', nargs='+', help='Only process specific platform IDs (e.g., VG1 VG4)')

    args = parser.parse_args()

    if not os.path.exists(args.scraped_dir):
        print(f"ERROR: Directory not found: {args.scraped_dir}")
        sys.exit(1)

    print("=" * 60)
    print("GITHUB LANGUAGE SCRAPER")
    print("=" * 60)
    print(f"Source: {args.scraped_dir}")
    print(f"Auth: {'Token provided' if args.token else 'No token (60 req/hr limit)'}")

    # Check rate limit
    if args.token:
        rate = github_api_get("/rate_limit", args.token)
        if rate:
            remaining = rate.get('resources', {}).get('core', {}).get('remaining', '?')
            print(f"API rate limit remaining: {remaining}")

    # Process platforms
    success = 0
    skipped = 0
    failed = 0

    for platform_dir_name in sorted(os.listdir(args.scraped_dir)):
        platform_path = os.path.join(args.scraped_dir, platform_dir_name)
        if not os.path.isdir(platform_path):
            continue

        # Filter by platform ID if specified
        if args.platforms:
            platform_id = platform_dir_name.split('_')[0]
            if platform_id not in args.platforms:
                continue

        result = process_platform(platform_path, args.token)
        if result:
            success += 1
        elif result is False:
            # Check if it had a github URL at all
            meta_path = os.path.join(platform_path, 'metadata.json')
            if os.path.exists(meta_path):
                meta = json.loads(open(meta_path).read())
                github_url = meta.get('external_links', {}).get('github', '')
                if github_url and is_github_url(github_url):
                    failed += 1
                else:
                    skipped += 1
            else:
                skipped += 1

        time.sleep(0.3)  # Brief pause between platforms

    print(f"\n{'=' * 60}")
    print(f"GITHUB LANGUAGE SCRAPING COMPLETE")
    print(f"{'=' * 60}")
    print(f"✅ Languages found: {success}")
    print(f"⏭️  No GitHub URL: {skipped}")
    print(f"❌ Failed: {failed}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
