#!/usr/bin/env python3
"""
inject_github_urls.py
Reads Gemini's GitHub search results and injects the URLs into each platform's metadata.json.

Usage:
    python3 inject_github_urls.py <scraped_content_dir> [--results gemini_github_results.json] [--dry-run]

Examples:
    # Dry run first to see what would change
    python3 inject_github_urls.py scraped_content/ --dry-run

    # Actually inject into full dataset
    python3 inject_github_urls.py scraped_content/

    # Inject into IRR test subset
    python3 inject_github_urls.py irr_test/scraped_content/

    # Use a custom results file
    python3 inject_github_urls.py scraped_content/ --results my_results.json
"""

import json
import os
import sys
import argparse
from pathlib import Path


def load_gemini_results(results_path):
    """Load and parse the Gemini GitHub search results."""
    with open(results_path) as f:
        data = json.load(f)

    # Build a lookup: platform_id -> github_url
    lookup = {}
    found_count = 0
    none_count = 0
    for entry in data:
        pid = entry["platform_id"]
        url = entry["github_url"]
        if url and url != "NONE":
            lookup[pid] = url
            found_count += 1
        else:
            none_count += 1

    print(f"Loaded {len(data)} Gemini results: {found_count} with GitHub URLs, {none_count} marked NONE")
    return lookup


def find_platform_dirs(scraped_dir):
    """Find all platform directories and map platform_id -> dir path."""
    platform_dirs = {}
    for d in os.listdir(scraped_dir):
        full_path = os.path.join(scraped_dir, d)
        if not os.path.isdir(full_path):
            continue
        # Extract platform ID (e.g., "VG1" from "VG1_Activision_Blizzard_Inc")
        pid = d.split("_")[0]
        platform_dirs[pid] = full_path
    return platform_dirs


def inject_urls(scraped_dir, lookup, dry_run=False):
    """Inject GitHub URLs into metadata.json files."""
    platform_dirs = find_platform_dirs(scraped_dir)

    updated = 0
    skipped_no_dir = 0
    skipped_no_meta = 0
    skipped_already_has = 0
    skipped_not_in_results = 0

    for pid, github_url in sorted(lookup.items()):
        if pid not in platform_dirs:
            skipped_no_dir += 1
            continue

        meta_path = os.path.join(platform_dirs[pid], "metadata.json")
        if not os.path.exists(meta_path):
            print(f"  WARNING: No metadata.json for {pid} at {meta_path}")
            skipped_no_meta += 1
            continue

        with open(meta_path) as f:
            meta = json.load(f)

        # Check if already has a GitHub URL
        existing = meta.get("external_links", {}).get("github", "")
        if existing and "github.com" in existing.lower():
            skipped_already_has += 1
            continue

        # Inject the GitHub URL
        if "external_links" not in meta:
            meta["external_links"] = {}
        meta["external_links"]["github"] = github_url

        dir_name = os.path.basename(platform_dirs[pid])
        if dry_run:
            print(f"  [DRY RUN] Would add github={github_url} to {dir_name}")
        else:
            with open(meta_path, "w") as f:
                json.dump(meta, f, indent=2, ensure_ascii=False)
            print(f"  UPDATED: {dir_name} -> {github_url}")

        updated += 1

    print(f"\n{'DRY RUN ' if dry_run else ''}SUMMARY for {scraped_dir}:")
    print(f"  Updated: {updated}")
    print(f"  Already had GitHub: {skipped_already_has}")
    print(f"  No directory found: {skipped_no_dir}")
    print(f"  No metadata.json: {skipped_no_meta}")
    print(f"  Total in lookup: {len(lookup)}")

    return updated


def main():
    parser = argparse.ArgumentParser(description="Inject Gemini GitHub URLs into metadata.json files")
    parser.add_argument("scraped_dir", help="Path to scraped_content directory")
    parser.add_argument("--results", default=None, help="Path to gemini_github_results.json (default: same dir as script)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be changed without modifying files")
    args = parser.parse_args()

    # Find results file
    if args.results:
        results_path = args.results
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        results_path = os.path.join(script_dir, "gemini_github_results.json")

    if not os.path.exists(results_path):
        print(f"ERROR: Results file not found: {results_path}")
        sys.exit(1)

    if not os.path.isdir(args.scraped_dir):
        print(f"ERROR: Directory not found: {args.scraped_dir}")
        sys.exit(1)

    print(f"Results file: {results_path}")
    print(f"Target directory: {args.scraped_dir}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    print()

    lookup = load_gemini_results(results_path)
    inject_urls(args.scraped_dir, lookup, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
