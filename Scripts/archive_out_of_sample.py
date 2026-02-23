#!/usr/bin/env python3
"""
Archive Out-of-Sample Scraped Content
======================================
Moves scraped content folders that are NOT in the final sample to an archive.

This includes:
  - Orphan folders: scraped platforms no longer in the tracker at all
  - PLAT=NONE folders: platforms reclassified as having no developer portal
  - Dropped IRR platforms: test platforms removed during sample narrowing

Usage:
    cd Dissertation/dissertation_batch_api
    python3 archive_out_of_sample.py                    # Dry run (preview only)
    python3 archive_out_of_sample.py --execute          # Actually move folders

Output:
    scraped_content_archive/   (archived folders moved here)
    archive_manifest.csv       (record of what was moved and why)
"""

import sys
sys.path.insert(0, '/tmp/pyfix')

import pandas as pd
import re
import shutil
import argparse
from pathlib import Path
from datetime import datetime

# ── Configuration ──────────────────────────────────────────────────────
TRACKER_FILE = Path("../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv")
SCRAPED_DIR = Path("scraped_content")
ARCHIVE_DIR = Path("scraped_content_archive")


def safe_folder_name(platform_id, platform_name):
    """Replicate the scraper's folder naming convention."""
    safe_name = re.sub(r'[^\w\-_]', '_', platform_name)
    return f"{platform_id}_{safe_name}"


def main():
    parser = argparse.ArgumentParser(description="Archive out-of-sample scraped content")
    parser.add_argument('--execute', action='store_true',
                        help='Actually move folders (default is dry run)')
    args = parser.parse_args()

    print("=" * 70)
    if args.execute:
        print("ARCHIVE OUT-OF-SAMPLE CONTENT — EXECUTE MODE")
    else:
        print("ARCHIVE OUT-OF-SAMPLE CONTENT — DRY RUN (preview only)")
        print("  Add --execute to actually move folders")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # ── Load tracker ──
    df = pd.read_csv(TRACKER_FILE)
    print(f"\nLoaded tracker: {len(df)} platforms")

    # Build lookup: platform_ID -> PLAT status
    plat_lookup = dict(zip(df['platform_ID'], df['PLAT']))

    # Build expected folder names for platforms WITH portals (PLAT != NONE)
    in_sample_folders = set()
    for _, row in df[df['PLAT'] != 'NONE'].iterrows():
        folder = safe_folder_name(row['platform_ID'], row['platform_name'])
        in_sample_folders.add(folder)

    # ── Scan scraped_content ──
    existing_folders = [d for d in SCRAPED_DIR.iterdir() if d.is_dir()]
    print(f"Scraped content folders: {len(existing_folders)}")

    # ── Classify each folder ──
    to_archive = []
    keeping = []

    for folder_path in sorted(existing_folders):
        folder_name = folder_path.name
        # Extract platform_ID from folder name (everything before first underscore)
        pid = folder_name.split('_')[0]

        reason = None
        if folder_name not in in_sample_folders:
            if pid not in plat_lookup:
                reason = "ORPHAN — platform not in tracker"
            elif plat_lookup[pid] == 'NONE':
                reason = "PLAT=NONE — no developer portal"
            else:
                # Folder name mismatch but platform exists with portal
                # Check if there's a matching folder name we expect
                matching = [f for f in in_sample_folders if f.startswith(pid + '_')]
                if matching:
                    reason = None  # Name variation, keep it
                else:
                    reason = f"NO_MATCH — platform {pid} exists but folder name doesn't match expected"

        if reason:
            # Calculate folder size
            size_bytes = sum(f.stat().st_size for f in folder_path.rglob('*') if f.is_file())
            to_archive.append({
                'folder': folder_name,
                'platform_ID': pid,
                'reason': reason,
                'size_kb': round(size_bytes / 1024, 1),
                'file_count': sum(1 for f in folder_path.rglob('*') if f.is_file())
            })
        else:
            keeping.append(folder_name)

    # ── Report ──
    print(f"\n{'─' * 70}")
    print(f"  Keeping in sample:  {len(keeping)}")
    print(f"  To archive:         {len(to_archive)}")
    print(f"{'─' * 70}")

    if to_archive:
        print(f"\nFolders to archive:")
        total_size = 0
        for item in to_archive:
            print(f"  {item['folder'][:50]:50s} {item['size_kb']:>8.1f} KB  {item['reason']}")
            total_size += item['size_kb']
        print(f"\n  Total archive size: {total_size:.1f} KB ({total_size/1024:.1f} MB)")

    # ── Execute or save manifest ──
    if args.execute and to_archive:
        ARCHIVE_DIR.mkdir(exist_ok=True)
        moved = 0
        for item in to_archive:
            src = SCRAPED_DIR / item['folder']
            dst = ARCHIVE_DIR / item['folder']
            if src.exists():
                shutil.move(str(src), str(dst))
                moved += 1
                print(f"  ✓ Moved: {item['folder']}")
        print(f"\n✅ Archived {moved} folders to {ARCHIVE_DIR}/")

    # Save manifest either way
    manifest_df = pd.DataFrame(to_archive)
    manifest_file = Path("archive_manifest.csv")
    manifest_df.to_csv(manifest_file, index=False)
    print(f"\n📁 Saved manifest: {manifest_file}")

    if not args.execute and to_archive:
        print(f"\n⚠️  DRY RUN — no folders were moved.")
        print(f"    Run with --execute to archive these {len(to_archive)} folders.")


if __name__ == "__main__":
    main()
