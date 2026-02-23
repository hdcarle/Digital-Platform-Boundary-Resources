#!/usr/bin/env python3
"""
github_augment_results.py
=========================
Supplemental GitHub data augmentation pass.

After the main AI coders have coded all 87 variables, this script performs a
TARGETED update of only GIT, API, and SDK variables based on the newly injected
GitHub language data in COMBINED_CONTENT.txt.

This avoids re-running the full coders (saving cost and time) while ensuring
that GitHub-related variables reflect the newly available data.

Variables updated:
  - GIT (0/1) — set to 1 if GitHub language section found in COMBINED_CONTENT.txt
  - GIT_url — set to the GitHub URL from the language section
  - GIT_prog_lang — count of codebook programming languages found
  - GIT_prog_lang_list — comma-separated list of codebook languages
  - API (0/1) — set to 1 if GIT=1 AND repos contain API-related names (v2.2 rule)
  - SDK (0/1) — set to 1 if GIT=1 AND repos contain code samples/SDKs (existing rule)

All other variables are preserved unchanged.

Usage:
    # Dry run (shows what would change)
    python3 github_augment_results.py scraped_content/ claude_results/ --dry-run

    # Actually update results
    python3 github_augment_results.py scraped_content/ claude_results/

    # Update both coders
    python3 github_augment_results.py scraped_content/ claude_results/
    python3 github_augment_results.py scraped_content/ chatgpt_results/

    # Only process specific platforms
    python3 github_augment_results.py scraped_content/ claude_results/ --platforms VG102 CC1 CC5
"""

import os
import sys
import json
import re
import argparse
from datetime import datetime

# Valid programming languages from codebook (must match PROGRAMMING_LANGUAGES_INDEX.md)
VALID_PROG_LANGS = [
    "Ada", "Apex", "Assembly", "Bash/Shell", "C", "C#", "C++", "Clojure",
    "Cobol", "Crystal", "Dart", "Delphi", "Elixir", "Erlang", "F#",
    "Fortran", "GDScript", "Go", "Groovy", "Haskell", "HTML/CSS", "Java",
    "JavaScript", "Julia", "Kotlin", "Lisp", "Lua", "MATLAB", "MicroPython",
    "Nim", "Objective-C", "OCaml", "Perl", "PHP", "PowerShell", "Prolog",
    "Python", "R", "Ruby", "Rust", "Scala", "Solidity", "SQL", "Swift",
    "TypeScript", "VBA", "Visual Basic", "Zephyr"
]

# Map GitHub language names to codebook names (same as github_lang_scraper.py)
LANG_MAP = {
    "Shell": "Bash/Shell",
    "Batchfile": "Bash/Shell",
    "HTML": "HTML/CSS",
    "CSS": "HTML/CSS",
    "SCSS": "HTML/CSS",
    "Sass": "HTML/CSS",
    "Less": "HTML/CSS",
    "Jupyter Notebook": "Python",
    "Objective-C++": "Objective-C",
    "Visual Basic .NET": "Visual Basic",
    "Svelte": "JavaScript",
    "Vue": "JavaScript",
    "TSQL": "SQL",
    "PLpgSQL": "SQL",
}

# Keywords in repo names that suggest API presence (v2.2 rule)
API_REPO_KEYWORDS = [
    "api", "rest-api", "api-client", "api-sdk", "api-wrapper",
    "openapi", "swagger", "graphql", "grpc", "webhook"
]

# Keywords in repo names that suggest SDK presence
SDK_REPO_KEYWORDS = [
    "sdk", "client-library", "library", "sample", "example",
    "quickstart", "starter", "demo", "tutorial", "boilerplate"
]


def parse_github_section(content: str) -> dict:
    """
    Parse the GITHUB REPOSITORY LANGUAGES section from COMBINED_CONTENT.txt.
    Returns dict with 'url', 'top_languages', 'repos' or None if not found.
    """
    if "GITHUB REPOSITORY LANGUAGES" not in content:
        return None

    result = {
        'url': '',
        'top_languages': [],
        'repos': []
    }

    # Extract URL
    url_match = re.search(r'## Source: (https://github\.com/\S+)', content)
    if url_match:
        result['url'] = url_match.group(1)

    # Extract top languages line
    top_match = re.search(r'Top languages: (.+)', content)
    if top_match:
        result['top_languages'] = [lang.strip() for lang in top_match.group(1).split(',')]

    # Extract repository list
    repo_section = re.findall(r'  (\S+) — (.+)', content)
    for repo_name, langs in repo_section:
        result['repos'].append({
            'name': repo_name,
            'languages': [l.strip() for l in langs.split(',')]
        })

    return result


def map_to_codebook_langs(github_langs: list) -> list:
    """Map GitHub language names to codebook programming language names."""
    codebook_langs = set()

    for github_lang in github_langs:
        github_lang = github_lang.strip()
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

    return sorted(codebook_langs)


def check_api_from_repos(repos: list) -> bool:
    """
    Check if any repo names suggest API presence (v2.2 rule).
    'If GIT=1 and GitHub repositories contain API client libraries,
     REST API wrappers, or repos with "api" in the name → API=1'
    """
    for repo in repos:
        repo_name_lower = repo['name'].lower()
        for keyword in API_REPO_KEYWORDS:
            if keyword in repo_name_lower:
                return True
    return False


def check_sdk_from_repos(repos: list) -> bool:
    """
    Check if any repo names suggest SDK presence (existing rule).
    'If GIT=1 and GitHub repo contains code samples → SDK=1'
    """
    for repo in repos:
        repo_name_lower = repo['name'].lower()
        for keyword in SDK_REPO_KEYWORDS:
            if keyword in repo_name_lower:
                return True
    return False


def augment_result(result_data: dict, github_data: dict) -> dict:
    """
    Update a single coder result with GitHub data.
    Returns dict of changes made (empty if no changes).
    """
    changes = {}

    social = result_data.get('social', {})
    application = result_data.get('application', {})
    development = result_data.get('development', {})

    # --- GIT variables ---
    old_git = social.get('GIT', 0)
    old_git_url = social.get('GIT_url', '')
    old_git_prog_lang = social.get('GIT_prog_lang', 0)
    old_git_prog_lang_list = social.get('GIT_prog_lang_list', '')

    # Set GIT=1 if GitHub section found
    if github_data is not None:
        # Map languages to codebook
        all_github_langs = list(github_data['top_languages'])
        for repo in github_data['repos']:
            all_github_langs.extend(repo['languages'])
        codebook_langs = map_to_codebook_langs(all_github_langs)

        new_git = 1
        new_git_url = github_data['url']
        new_git_prog_lang = len(codebook_langs)
        new_git_prog_lang_list = '; '.join(codebook_langs)

        if old_git != new_git:
            changes['GIT'] = f'{old_git} → {new_git}'
        if old_git_url != new_git_url and new_git_url:
            changes['GIT_url'] = f'"{old_git_url}" → "{new_git_url}"'
        if old_git_prog_lang != new_git_prog_lang:
            changes['GIT_prog_lang'] = f'{old_git_prog_lang} → {new_git_prog_lang}'
        if old_git_prog_lang_list != new_git_prog_lang_list:
            changes['GIT_prog_lang_list'] = f'"{old_git_prog_lang_list}" → "{new_git_prog_lang_list}"'

        social['GIT'] = new_git
        social['GIT_url'] = new_git_url
        social['GIT_prog_lang'] = new_git_prog_lang
        social['GIT_prog_lang_list'] = new_git_prog_lang_list

        # --- API variable (v2.2 rule) ---
        old_api = application.get('API', 0)
        if old_api == 0 and check_api_from_repos(github_data['repos']):
            application['API'] = 1
            changes['API'] = f'{old_api} → 1 (GitHub repos contain API-related names)'

        # --- SDK variable ---
        old_sdk = development.get('SDK', 0)
        if old_sdk == 0 and check_sdk_from_repos(github_data['repos']):
            development['SDK'] = 1
            changes['SDK'] = f'{old_sdk} → 1 (GitHub repos contain SDK/samples)'

    result_data['social'] = social
    result_data['application'] = application
    result_data['development'] = development

    return changes


def main():
    parser = argparse.ArgumentParser(
        description='Augment AI coder results with GitHub language data (GIT/API/SDK only)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script performs a TARGETED update of only GIT, API, and SDK variables
based on the GitHub language section in COMBINED_CONTENT.txt. All other
variables from the original coding are preserved unchanged.

Examples:
    python3 github_augment_results.py scraped_content/ claude_results/ --dry-run
    python3 github_augment_results.py scraped_content/ claude_results/
    python3 github_augment_results.py scraped_content/ chatgpt_results/
        """
    )
    parser.add_argument('scraped_dir', help='Path to scraped_content directory')
    parser.add_argument('results_dir', help='Path to coder results directory (e.g., claude_results/)')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without modifying files')
    parser.add_argument('--platforms', '-p', nargs='+', help='Only process specific platform IDs')

    args = parser.parse_args()

    if not os.path.isdir(args.scraped_dir):
        print(f"ERROR: Scraped content directory not found: {args.scraped_dir}")
        sys.exit(1)
    if not os.path.isdir(args.results_dir):
        print(f"ERROR: Results directory not found: {args.results_dir}")
        sys.exit(1)

    print("=" * 70)
    print("GITHUB AUGMENT RESULTS — Supplemental GIT/API/SDK Update")
    print("=" * 70)
    print(f"Scraped content: {args.scraped_dir}")
    print(f"Results dir:     {args.results_dir}")
    print(f"Mode:            {'DRY RUN' if args.dry_run else 'LIVE'}")
    print(f"Date:            {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print()

    # Build lookup: platform_id -> scraped_content path
    scraped_lookup = {}
    for d in os.listdir(args.scraped_dir):
        full_path = os.path.join(args.scraped_dir, d)
        if os.path.isdir(full_path):
            pid = d.split('_')[0]
            scraped_lookup[pid] = full_path

    # Process each result file
    updated = 0
    skipped_no_content = 0
    skipped_no_github = 0
    skipped_no_change = 0
    skipped_filter = 0
    all_changes = []

    for result_file in sorted(os.listdir(args.results_dir)):
        if not result_file.endswith('.json'):
            continue

        # Extract platform_id from filename (e.g., "VG102_claude.json" -> "VG102")
        pid = result_file.split('_')[0]

        # Filter by platform if specified
        if args.platforms and pid not in args.platforms:
            skipped_filter += 1
            continue

        result_path = os.path.join(args.results_dir, result_file)

        # Load existing result
        with open(result_path) as f:
            result_data = json.load(f)

        # Skip auto-coded (PLAT=NONE) platforms
        if result_data.get('auto_coded', False):
            skipped_no_content += 1
            continue

        # Skip failed codings
        if not result_data.get('success', False):
            skipped_no_content += 1
            continue

        # Find scraped content directory
        if pid not in scraped_lookup:
            skipped_no_content += 1
            continue

        # Read COMBINED_CONTENT.txt
        cc_path = os.path.join(scraped_lookup[pid], 'COMBINED_CONTENT.txt')
        if not os.path.exists(cc_path):
            skipped_no_content += 1
            continue

        content = open(cc_path).read()

        # Parse GitHub section
        github_data = parse_github_section(content)
        if github_data is None:
            skipped_no_github += 1
            continue

        # Augment the result
        changes = augment_result(result_data, github_data)

        if not changes:
            skipped_no_change += 1
            continue

        # Record changes
        change_record = {
            'platform_id': pid,
            'file': result_file,
            'changes': changes
        }
        all_changes.append(change_record)

        if args.dry_run:
            print(f"  [DRY RUN] {pid}:")
            for var, desc in changes.items():
                print(f"    {var}: {desc}")
        else:
            # Add augmentation metadata
            if 'augmentation' not in result_data:
                result_data['augmentation'] = {}
            result_data['augmentation']['github_augment'] = {
                'date': datetime.now().strftime('%Y-%m-%d'),
                'script': 'github_augment_results.py',
                'changes': changes
            }

            with open(result_path, 'w') as f:
                json.dump(result_data, f, indent=2, ensure_ascii=False)
            print(f"  UPDATED: {pid} — {', '.join(changes.keys())}")

        updated += 1

    # Summary
    print()
    print("=" * 70)
    print(f"{'DRY RUN ' if args.dry_run else ''}SUMMARY")
    print("=" * 70)
    print(f"  Results updated:         {updated}")
    print(f"  No change needed:        {skipped_no_change}")
    print(f"  No GitHub lang section:  {skipped_no_github}")
    print(f"  No content/auto-coded:   {skipped_no_content}")
    if args.platforms:
        print(f"  Filtered out:            {skipped_filter}")
    print()

    # Detailed change log
    if all_changes:
        print("CHANGE LOG:")
        print("-" * 70)
        # Count by variable
        var_counts = {}
        for record in all_changes:
            for var in record['changes']:
                var_counts[var] = var_counts.get(var, 0) + 1

        for var, count in sorted(var_counts.items()):
            print(f"  {var}: {count} platforms changed")

        print()
        print(f"Total platforms with at least one change: {len(all_changes)}")

        # Save change log
        log_path = os.path.join(args.results_dir, 'github_augment_log.json')
        if not args.dry_run:
            with open(log_path, 'w') as f:
                json.dump({
                    'date': datetime.now().strftime('%Y-%m-%d %H:%M'),
                    'mode': 'live',
                    'scraped_dir': args.scraped_dir,
                    'results_dir': args.results_dir,
                    'total_updated': updated,
                    'changes': all_changes
                }, f, indent=2)
            print(f"\nChange log saved: {log_path}")
        else:
            print(f"\n[DRY RUN] Change log would be saved to: {log_path}")

    print("=" * 70)


if __name__ == "__main__":
    main()
