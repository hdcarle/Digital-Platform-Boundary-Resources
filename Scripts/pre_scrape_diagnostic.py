#!/usr/bin/env python3
"""
Pre-Scrape Diagnostic Script
=============================
Run this BEFORE the selenium scraper to see exactly what will happen.

Outputs:
  1. Console summary of what needs scraping
  2. platforms_to_scrape.csv — the exact list that will be scraped
  3. platforms_previously_failed.csv — platforms that failed before (need URL review)
  4. scrape_readiness_report.txt — full diagnostic report

Usage:
    cd Dissertation/dissertation_batch_api
    python3 pre_scrape_diagnostic.py
"""

# Fix for sandbox urllib issue
import sys
sys.path.insert(0, '/tmp/pyfix')

import pandas as pd
import re
from pathlib import Path
import json
from datetime import datetime

# ── Configuration ──────────────────────────────────────────────────────
TRACKER_FILE = Path("REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv")
# Also check parent REFERENCE folder
if not TRACKER_FILE.exists():
    TRACKER_FILE = Path("../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv")

SCRAPED_DIR = Path("scraped_content")
FAILED_FILE = Path("../REFERENCE/PLATFORMS_FAILED_SCRAPING.csv")
if not FAILED_FILE.exists():
    FAILED_FILE = Path("REFERENCE/PLATFORMS_FAILED_SCRAPING.csv")

OUTPUT_DIR = Path(".")

def safe_folder_name(platform_id, platform_name):
    """Replicate the scraper's folder naming convention exactly."""
    safe_name = re.sub(r'[^\w\-_]', '_', platform_name)
    return f"{platform_id}_{safe_name}"


def main():
    print("=" * 70)
    print("PRE-SCRAPE DIAGNOSTIC REPORT")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    # ── Load tracker ──
    if not TRACKER_FILE.exists():
        print(f"\n❌ ERROR: Cannot find tracker at {TRACKER_FILE}")
        print("   Make sure you're running from dissertation_batch_api/")
        return

    df = pd.read_csv(TRACKER_FILE)
    print(f"\n📊 Loaded tracker: {len(df)} total platforms")

    # ── Filter platforms with URLs ──
    has_url = df[
        (df['PLAT'] != 'NONE') &
        (df['developer_portal_url'].notna()) &
        (df['developer_portal_url'].str.strip() != '')
    ].copy()
    print(f"   Platforms with URLs (PLAT ≠ NONE): {len(has_url)}")

    # ── Check scraped content folders ──
    if not SCRAPED_DIR.exists():
        print(f"\n❌ ERROR: scraped_content/ directory not found")
        return

    existing_folders = set(d.name for d in SCRAPED_DIR.iterdir() if d.is_dir())
    print(f"   Existing scraped folders: {len(existing_folders)}")

    # ── Classify each platform ──
    to_scrape = []
    already_done = []
    will_skip_combined = []  # Has folder + COMBINED_CONTENT.txt > 100 bytes

    for _, row in has_url.iterrows():
        pid = row['platform_ID']
        pname = row['platform_name']
        url = row['developer_portal_url']
        plat = row['PLAT']
        folder = safe_folder_name(pid, pname)
        folder_path = SCRAPED_DIR / folder
        combined = folder_path / "COMBINED_CONTENT.txt"

        status = "NEEDS_SCRAPING"
        if combined.exists() and combined.stat().st_size > 100:
            status = "ALREADY_DONE"
            will_skip_combined.append({
                'platform_ID': pid, 'platform_name': pname,
                'PLAT': plat, 'folder': folder,
                'combined_size_kb': round(combined.stat().st_size / 1024, 1)
            })
        elif folder_path.exists():
            # Folder exists but no valid COMBINED_CONTENT.txt
            status = "INCOMPLETE"
            to_scrape.append({
                'platform_ID': pid, 'platform_name': pname,
                'PLAT': plat, 'developer_portal_url': url,
                'folder': folder, 'note': 'Folder exists but COMBINED_CONTENT.txt missing/empty'
            })
        else:
            to_scrape.append({
                'platform_ID': pid, 'platform_name': pname,
                'PLAT': plat, 'developer_portal_url': url,
                'folder': folder, 'note': ''
            })

    # ── Load failed platforms ──
    failed_platforms = set()
    if FAILED_FILE.exists():
        failed_df = pd.read_csv(FAILED_FILE)
        failed_platforms = set(failed_df['platform_ID'].values)
        print(f"   Previously failed platforms: {len(failed_platforms)}")

    # ── Mark which to_scrape platforms previously failed ──
    for item in to_scrape:
        if item['platform_ID'] in failed_platforms:
            item['note'] = 'PREVIOUSLY FAILED — check URL validity'

    # ── Summary ──
    print(f"\n{'─' * 70}")
    print(f"SCRAPING PLAN SUMMARY")
    print(f"{'─' * 70}")
    print(f"  ✅ Already scraped (will auto-skip): {len(will_skip_combined)}")
    print(f"  🔄 Need scraping:                    {len(to_scrape)}")

    # Breakdown by PLAT
    plat_counts = {}
    for item in to_scrape:
        p = item['PLAT']
        plat_counts[p] = plat_counts.get(p, 0) + 1
    print(f"\n  Breakdown of platforms to scrape:")
    for plat_type in ['PUBLIC', 'REGISTRATION', 'RESTRICTED', 'NONE']:
        if plat_type in plat_counts:
            print(f"    {plat_type:15s} {plat_counts[plat_type]:>4d}")

    # Breakdown by industry
    industry_counts = {}
    for item in to_scrape:
        ind = item['platform_ID'][:2]
        industry_counts[ind] = industry_counts.get(ind, 0) + 1
    print(f"\n  Breakdown by industry:")
    for ind in sorted(industry_counts.keys()):
        print(f"    {ind:5s} {industry_counts[ind]:>4d}")

    # Previously failed
    failed_in_queue = [i for i in to_scrape if 'PREVIOUSLY FAILED' in i.get('note', '')]
    if failed_in_queue:
        print(f"\n  ⚠️  {len(failed_in_queue)} previously failed platforms in queue:")
        for item in failed_in_queue:
            print(f"      {item['platform_ID']:8s} {item['platform_name'][:40]}")

    # ── Time estimate ──
    avg_time_per_platform = 45  # seconds (conservative estimate)
    total_seconds = len(to_scrape) * avg_time_per_platform
    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    print(f"\n  ⏱️  Estimated scraping time: ~{hours}h {minutes}m")
    print(f"      (at ~45 sec/platform average, some banking sites may take longer)")

    # ── Save outputs ──

    # 1. Platforms to scrape
    scrape_df = pd.DataFrame(to_scrape)
    scrape_file = OUTPUT_DIR / "platforms_to_scrape.csv"
    scrape_df.to_csv(scrape_file, index=False)
    print(f"\n📁 Saved: {scrape_file} ({len(to_scrape)} platforms)")

    # 2. Full report
    report_file = OUTPUT_DIR / "scrape_readiness_report.txt"
    with open(report_file, 'w') as f:
        f.write("PRE-SCRAPE READINESS REPORT\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 70 + "\n\n")

        f.write(f"Total platforms in tracker: {len(df)}\n")
        f.write(f"Platforms with URLs: {len(has_url)}\n")
        f.write(f"Already scraped (will skip): {len(will_skip_combined)}\n")
        f.write(f"Need scraping: {len(to_scrape)}\n")
        f.write(f"Previously failed: {len(failed_in_queue)}\n\n")

        f.write("PLATFORMS TO SCRAPE:\n")
        f.write("-" * 70 + "\n")
        for item in to_scrape:
            note = f" [{item['note']}]" if item.get('note') else ""
            f.write(f"  {item['platform_ID']:8s} {item['platform_name'][:35]:35s} "
                    f"{item['PLAT']:15s} {item['developer_portal_url'][:50]}{note}\n")

        f.write(f"\n\nALREADY SCRAPED (will auto-skip):\n")
        f.write("-" * 70 + "\n")
        for item in will_skip_combined[:10]:
            f.write(f"  {item['platform_ID']:8s} {item['platform_name'][:35]:35s} "
                    f"{item['combined_size_kb']:>8.1f} KB\n")
        if len(will_skip_combined) > 10:
            f.write(f"  ... and {len(will_skip_combined) - 10} more\n")

    print(f"📁 Saved: {report_file}")

    # ── Command to run ──
    print(f"\n{'─' * 70}")
    print("READY TO SCRAPE — Run this command:")
    print(f"{'─' * 70}")
    print(f"""
cd Dissertation/dissertation_batch_api
python3 selenium_scraper.py ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv \\
    --output scraped_content/
""")
    print("The scraper will automatically skip the already-scraped platforms.")
    print("No --skip-existing flag needed — it checks for COMBINED_CONTENT.txt.\n")

    # ── Dry run suggestion ──
    print("💡 TIP: Run with --dry-run first to preview without actually scraping:")
    print(f"""
python3 selenium_scraper.py ../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv \\
    --output scraped_content/ --dry-run
""")


if __name__ == "__main__":
    main()
