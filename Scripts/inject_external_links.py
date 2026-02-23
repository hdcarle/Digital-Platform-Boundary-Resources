#!/usr/bin/env python3
"""
Post-Processing Script: Inject External Links into COMBINED_CONTENT.txt
========================================================================
Reads metadata.json from each scraped platform folder and injects
external links and page category summaries at the top of COMBINED_CONTENT.txt.

This ensures AI coders (Claude/ChatGPT) can see social media, blog, support,
and GitHub links that were discovered during scraping but not included in
the text extraction.

Usage:
    python3 inject_external_links.py scraped_content/
    python3 inject_external_links.py irr_test/scraped_content/
    python3 inject_external_links.py scraped_content/ --dry-run
"""

import json
import sys
import os
from pathlib import Path


def categorize_pages(pages_scraped: list) -> dict:
    """Categorize scraped pages by type for COM variable coding."""
    categories = {
        'blog': [],
        'forum': [],
        'support': [],
        'training': [],
        'faq': [],
        'tutorials': [],
        'github': [],
        'events': [],
        'sdk': [],
        'documentation': [],
        'api': [],
        'pricing': [],
        'legal': [],
        'other': []
    }

    for page in pages_scraped:
        name = page.get('name', '').lower()
        url = page.get('url', '')

        if 'blog' in name or 'news' in name or 'announcement' in name:
            categories['blog'].append(url)
        elif 'forum' in name or 'community' in name or 'discuss' in name:
            categories['forum'].append(url)
        elif 'support' in name or 'help' in name or 'contact' in name:
            categories['support'].append(url)
        elif 'training' in name or 'course' in name or 'learn' in name or 'codelab' in name or 'academy' in name:
            categories['training'].append(url)
        elif 'faq' in name:
            categories['faq'].append(url)
        elif 'tutorial' in name or 'guide' in name or 'getting_started' in name or 'quickstart' in name:
            categories['tutorials'].append(url)
        elif 'github' in name or 'gitlab' in name or 'github.com' in url or 'gitlab.com' in url:
            categories['github'].append(url)
        elif 'event' in name or 'conference' in name or 'hackathon' in name or 'webinar' in name:
            categories['events'].append(url)
        elif 'sdk' in name or 'download' in name or 'library' in name:
            categories['sdk'].append(url)
        elif 'doc' in name or 'reference' in name:
            categories['documentation'].append(url)
        elif 'api' in name or 'endpoint' in name:
            categories['api'].append(url)
        elif 'pricing' in name or 'plan' in name:
            categories['pricing'].append(url)
        elif 'terms' in name or 'legal' in name or 'privacy' in name or 'policy' in name:
            categories['legal'].append(url)

    # Remove empty categories
    return {k: v for k, v in categories.items() if v}


def build_links_section(metadata: dict) -> str:
    """Build the external links section to inject into COMBINED_CONTENT.txt."""
    lines = []
    lines.append("=" * 70)
    lines.append("EXTERNAL LINKS AND RESOURCES DISCOVERED DURING SCRAPING")
    lines.append("(Use these to help code COM, GIT, and other variables)")
    lines.append("=" * 70)
    lines.append("")

    # External links (social media, GitHub, etc.)
    external_links = metadata.get('external_links', {})
    if external_links:
        lines.append("## EXTERNAL LINKS FOUND ON PORTAL:")
        for link_type, url in external_links.items():
            # Map link types to readable labels
            label = link_type.replace('social_', 'Social: ').replace('_', ' ').title()
            lines.append(f"  - {label}: {url}")
        lines.append("")
    else:
        lines.append("## EXTERNAL LINKS: None detected by scraper")
        lines.append("")

    # Categorized pages from pages_scraped
    pages_scraped = metadata.get('pages_scraped', [])
    if pages_scraped:
        categories = categorize_pages(pages_scraped)

        if categories:
            lines.append("## PAGES SCRAPED BY CATEGORY:")

            # Map categories to COM variable hints
            category_labels = {
                'blog': 'Blog/News (COM_blog)',
                'forum': 'Forum/Community (COM_forum)',
                'support': 'Help/Support (COM_help_support)',
                'training': 'Training/Courses (COM_training)',
                'faq': 'FAQ (COM_FAQ)',
                'tutorials': 'Tutorials/Guides (COM_tutorials)',
                'github': 'GitHub/GitLab (GIT)',
                'events': 'Events (EVENT)',
                'sdk': 'SDK/Downloads (SDK)',
                'documentation': 'Documentation (DOCS)',
                'api': 'API Reference (API)',
                'pricing': 'Pricing (OPEN)',
                'legal': 'Legal/Terms (DATA)',
                'other': 'Other'
            }

            for cat, urls in categories.items():
                label = category_labels.get(cat, cat.title())
                lines.append(f"  {label}:")
                for url in urls[:5]:  # Limit to 5 URLs per category
                    lines.append(f"    - {url}")
                if len(urls) > 5:
                    lines.append(f"    - ... and {len(urls) - 5} more")
            lines.append("")

    # Also extract any social links from page names
    social_pages = [p for p in pages_scraped if 'social' in p.get('name', '').lower()
                    or 'twitter' in p.get('url', '').lower()
                    or 'x.com' in p.get('url', '').lower()
                    or 'linkedin' in p.get('url', '').lower()
                    or 'youtube' in p.get('url', '').lower()
                    or 'discord' in p.get('url', '').lower()
                    or 'slack' in p.get('url', '').lower()
                    or 'stackoverflow' in p.get('url', '').lower()]

    if social_pages:
        lines.append("## SOCIAL MEDIA / COMMUNITY LINKS FROM SCRAPED PAGES:")
        for page in social_pages:
            lines.append(f"  - {page.get('name', 'unknown')}: {page.get('url', '')}")
        lines.append("")

    lines.append("=" * 70)
    lines.append("")

    return "\n".join(lines)


def process_platform(platform_dir: Path, dry_run: bool = False) -> dict:
    """Process a single platform directory."""
    metadata_file = platform_dir / "metadata.json"
    combined_file = platform_dir / "COMBINED_CONTENT.txt"

    result = {
        'platform': platform_dir.name,
        'status': 'skipped',
        'external_links': 0,
        'page_categories': 0
    }

    if not metadata_file.exists():
        result['status'] = 'no_metadata'
        return result

    if not combined_file.exists():
        result['status'] = 'no_combined'
        return result

    # Read metadata
    try:
        with open(metadata_file, 'r', encoding='utf-8') as f:
            metadata = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        result['status'] = f'error: {str(e)}'
        return result

    # Build the links section
    links_section = build_links_section(metadata)

    # Count what we found
    result['external_links'] = len(metadata.get('external_links', {}))
    result['page_categories'] = len(categorize_pages(metadata.get('pages_scraped', [])))

    if dry_run:
        result['status'] = 'would_inject'
        return result

    # Read existing content
    with open(combined_file, 'r', encoding='utf-8') as f:
        existing_content = f.read()

    # Check if we already injected (avoid double injection)
    if "EXTERNAL LINKS AND RESOURCES DISCOVERED" in existing_content:
        result['status'] = 'already_injected'
        return result

    # Find the insertion point (after the header comments)
    lines = existing_content.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('#'):
            insert_idx = i + 1
        else:
            break

    # Also skip any blank line after headers
    while insert_idx < len(lines) and lines[insert_idx].strip() == '':
        insert_idx += 1

    # Insert the links section
    new_content = '\n'.join(lines[:insert_idx]) + '\n\n' + links_section + '\n' + '\n'.join(lines[insert_idx:])

    # Write back
    with open(combined_file, 'w', encoding='utf-8') as f:
        f.write(new_content)

    result['status'] = 'injected'
    return result


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 inject_external_links.py <scraped_content_dir> [--dry-run]")
        print("Example: python3 inject_external_links.py scraped_content/")
        print("         python3 inject_external_links.py irr_test/scraped_content/ --dry-run")
        sys.exit(1)

    scraped_dir = Path(sys.argv[1])
    dry_run = '--dry-run' in sys.argv

    if not scraped_dir.exists():
        print(f"ERROR: Directory not found: {scraped_dir}")
        sys.exit(1)

    # Find all platform directories
    platform_dirs = sorted([d for d in scraped_dir.iterdir() if d.is_dir()])

    print(f"\n{'='*60}")
    print(f"INJECT EXTERNAL LINKS INTO COMBINED_CONTENT.txt")
    print(f"{'='*60}")
    print(f"Source directory: {scraped_dir}")
    print(f"Platform folders found: {len(platform_dirs)}")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print(f"{'='*60}\n")

    # Process each platform
    stats = {'injected': 0, 'already_injected': 0, 'skipped': 0, 'errors': 0}

    for platform_dir in platform_dirs:
        result = process_platform(platform_dir, dry_run=dry_run)

        status = result['status']
        ext_count = result['external_links']
        cat_count = result['page_categories']

        if status == 'injected' or status == 'would_inject':
            stats['injected'] += 1
            marker = "✅" if not dry_run else "🔍"
            print(f"  {marker} {result['platform']}: {ext_count} external links, {cat_count} page categories")
        elif status == 'already_injected':
            stats['already_injected'] += 1
            print(f"  ⏭️  {result['platform']}: already processed")
        elif status.startswith('error'):
            stats['errors'] += 1
            print(f"  ❌ {result['platform']}: {status}")
        else:
            stats['skipped'] += 1
            print(f"  ⚠️  {result['platform']}: {status}")

    # Summary
    print(f"\n{'='*60}")
    print(f"COMPLETE")
    print(f"{'='*60}")
    print(f"{'Injected' if not dry_run else 'Would inject'}: {stats['injected']}")
    print(f"Already done: {stats['already_injected']}")
    print(f"Skipped: {stats['skipped']}")
    print(f"Errors: {stats['errors']}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
