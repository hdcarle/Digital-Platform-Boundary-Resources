#!/usr/bin/env python3
"""
Deduplication script for scraped developer portal content.

Identifies duplicate files within each platform directory using MD5 hashing,
moves them to an archive folder (preserving directory structure), and
regenerates COMBINED_CONTENT.txt for each affected platform.

Usage:
    python3 dedup_scraped_content.py scraped_content/ --archive scraped_content_dupes/
    python3 dedup_scraped_content.py scraped_content/ --archive scraped_content_dupes/ --dry-run
"""

import os
import sys
import hashlib
import shutil
import argparse
import json
from collections import defaultdict
from datetime import datetime


def md5_file(filepath):
    """Calculate MD5 hash of a file."""
    h = hashlib.md5()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def regenerate_combined(platform_dir, platform_id=None):
    """Regenerate COMBINED_CONTENT.txt from remaining files."""
    combined_path = os.path.join(platform_dir, "COMBINED_CONTENT.txt")

    # Gather all non-combined text files
    files = []
    for f in sorted(os.listdir(platform_dir)):
        fp = os.path.join(platform_dir, f)
        if os.path.isfile(fp) and f != "COMBINED_CONTENT.txt":
            files.append((f, fp))

    if not files:
        return 0

    # Read the old combined to get the header info
    header_lines = []
    if os.path.exists(combined_path):
        with open(combined_path, 'r', errors='replace') as f:
            for line in f:
                header_lines.append(line)
                if line.startswith("# PAGES SCRAPED:"):
                    break

    # Build new combined content
    parts = []

    # Keep original header but update page count
    if header_lines:
        for line in header_lines:
            if line.startswith("# PAGES SCRAPED:"):
                parts.append(f"# PAGES SCRAPED: {len(files)}\n")
            else:
                parts.append(line)

    parts.append("=" * 80 + "\n")
    parts.append("\n")

    for fname, fpath in files:
        with open(fpath, 'r', errors='replace') as f:
            content = f.read()
        parts.append("\n")
        parts.append("=" * 80 + "\n")
        parts.append(f"## FILE: {fname}\n")
        parts.append("=" * 80 + "\n")
        parts.append("\n")
        parts.append(content)
        parts.append("\n")

    combined_text = "".join(parts)

    with open(combined_path, 'w') as f:
        f.write(combined_text)

    return len(combined_text)


def dedup_platform(platform_dir, archive_base, dry_run=False):
    """Deduplicate files in a single platform directory."""
    dirname = os.path.basename(platform_dir)

    # Get all files except COMBINED_CONTENT.txt
    files = {}
    for f in sorted(os.listdir(platform_dir)):
        fp = os.path.join(platform_dir, f)
        if os.path.isfile(fp) and f != "COMBINED_CONTENT.txt":
            files[f] = {
                'path': fp,
                'size': os.path.getsize(fp),
                'md5': md5_file(fp)
            }

    if not files:
        return None

    # Group by hash - keep first alphabetically, rest are dupes
    hash_groups = defaultdict(list)
    for fname in sorted(files.keys()):
        hash_groups[files[fname]['md5']].append(fname)

    dupes = []
    for md5, fnames in hash_groups.items():
        if len(fnames) > 1:
            dupes.extend(fnames[1:])  # Keep first, archive rest

    if not dupes:
        return None

    # Get before stats
    combined_path = os.path.join(platform_dir, "COMBINED_CONTENT.txt")
    before_combined = os.path.getsize(combined_path) if os.path.exists(combined_path) else 0
    before_files = len(files)
    before_size = sum(f['size'] for f in files.values())

    # Move duplicates to archive
    archive_dir = os.path.join(archive_base, dirname)
    if not dry_run:
        os.makedirs(archive_dir, exist_ok=True)

    dupe_size = 0
    for fname in dupes:
        src = files[fname]['path']
        dst = os.path.join(archive_dir, fname)
        dupe_size += files[fname]['size']
        if not dry_run:
            shutil.move(src, dst)

    # Regenerate COMBINED_CONTENT.txt
    after_combined = 0
    if not dry_run:
        after_combined = regenerate_combined(platform_dir)
    else:
        # Estimate: subtract dupe content from combined
        after_combined = before_combined  # approximate

    after_files = before_files - len(dupes)
    after_size = before_size - dupe_size

    return {
        'platform': dirname,
        'before_files': before_files,
        'after_files': after_files,
        'dupes_moved': len(dupes),
        'before_size': before_size,
        'after_size': after_size,
        'size_saved': dupe_size,
        'before_combined_chars': before_combined,
        'after_combined_chars': after_combined,
    }


def main():
    parser = argparse.ArgumentParser(description='Deduplicate scraped content')
    parser.add_argument('content_dir', help='Path to scraped_content directory')
    parser.add_argument('--archive', default=None, help='Archive directory for duplicates')
    parser.add_argument('--dry-run', action='store_true', help='Show what would happen without making changes')
    args = parser.parse_args()

    content_dir = args.content_dir
    archive_dir = args.archive or os.path.join(os.path.dirname(content_dir.rstrip('/')), 'scraped_content_dupes')

    if not os.path.isdir(content_dir):
        print(f"Error: {content_dir} is not a directory")
        sys.exit(1)

    if args.dry_run:
        print("=== DRY RUN - No changes will be made ===\n")

    print(f"Content directory: {content_dir}")
    print(f"Archive directory: {archive_dir}")
    print()

    if not args.dry_run:
        os.makedirs(archive_dir, exist_ok=True)

    # Process each platform
    results = []
    for dirname in sorted(os.listdir(content_dir)):
        platform_path = os.path.join(content_dir, dirname)
        if not os.path.isdir(platform_path):
            continue

        result = dedup_platform(platform_path, archive_dir, args.dry_run)
        if result:
            results.append(result)
            print(f"  {dirname}: moved {result['dupes_moved']} dupes, "
                  f"saved {result['size_saved']/1024:.0f}K")

    # Summary
    total_dupes = sum(r['dupes_moved'] for r in results)
    total_saved = sum(r['size_saved'] for r in results)

    print(f"\n{'='*60}")
    print(f"DEDUPLICATION COMPLETE")
    print(f"{'='*60}")
    print(f"Platforms processed: {len(results)}")
    print(f"Duplicate files moved: {total_dupes}")
    print(f"Space saved: {total_saved/1024/1024:.1f} MB")

    # Save results JSON
    report_path = os.path.join(os.path.dirname(content_dir.rstrip('/')), 'dedup_report.json')
    with open(report_path, 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'content_dir': content_dir,
            'archive_dir': archive_dir,
            'dry_run': args.dry_run,
            'summary': {
                'platforms_affected': len(results),
                'total_dupes_moved': total_dupes,
                'total_size_saved': total_saved,
            },
            'platforms': results,
        }, f, indent=2)
    print(f"Report saved: {report_path}")


if __name__ == '__main__':
    main()
