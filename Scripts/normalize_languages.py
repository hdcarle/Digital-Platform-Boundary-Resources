#!/usr/bin/env python3
"""
Language String Normalizer
==========================
Normalizes all natural language strings in coder result JSON files to
standardized English names. This ensures consistent language labels for
analysis in R.

Also exports a CSV summary of all language data for R analysis.

Usage:
    python3 normalize_languages.py claude_results/ chatgpt_results/ --output language_data/
    python3 normalize_languages.py claude_results/ chatgpt_results/ --output language_data/ --dry-run

Input: Coding result directories with *_claude.json / *_chatgpt.json files
Output:
    - Normalized JSON files (in-place)
    - language_data/language_summary.csv (all platforms × all lang variables)
    - language_data/normalization_log.txt
"""

import os
import sys
import json
import glob
import csv
import argparse
from datetime import datetime
from pathlib import Path
from collections import Counter

# =============================================================================
# LANGUAGE NORMALIZATION MAP
# =============================================================================
# Maps all observed non-English language labels to standardized English names.
# Includes native script labels, regional variants, and inconsistent spellings.

LANGUAGE_MAP = {
    # East Asian
    '日本語': 'Japanese',
    '한국어': 'Korean',
    '简体中文': 'Simplified Chinese',
    '繁體中文': 'Traditional Chinese',
    '中文 – 简体': 'Simplified Chinese',
    '中文': 'Chinese',
    'Simplified Chinese': 'Simplified Chinese',
    'Traditional Chinese': 'Traditional Chinese',
    'Chinese': 'Chinese',

    # European - Germanic
    'Deutsch': 'German',
    'Nederlands': 'Dutch',
    'Svenska': 'Swedish',
    'Norsk': 'Norwegian',
    'Dansk': 'Danish',

    # European - Romance
    'Français': 'French',
    'Français (Europe)': 'French',
    'Français (France)': 'French',
    'Español': 'Spanish',
    'Español (América Latina)': 'Spanish',
    'Español (España)': 'Spanish',
    'Español - España': 'Spanish',
    'Español - Latinoamérica': 'Spanish',
    'Spanish (España)': 'Spanish',
    'Spanish (México)': 'Spanish',
    'Spanish - Spain': 'Spanish',
    'Spanish - Latin America': 'Spanish',
    'Português': 'Portuguese',
    'Português (Brasil)': 'Portuguese',
    'Português (Portugal)': 'Portuguese',
    'Português – Brasil': 'Portuguese',
    'Português - Portugal': 'Portuguese',
    'Português - Brasil': 'Portuguese',
    'Portuguese (Brasil)': 'Portuguese',
    'Portuguese - Portugal': 'Portuguese',
    'Portuguese - Brazil': 'Portuguese',
    'Italiano': 'Italian',
    'Română': 'Romanian',
    'Catalan': 'Catalan',

    # European - Slavic
    'Русский': 'Russian',
    'Polski': 'Polish',
    'Čeština': 'Czech',
    'Українська': 'Ukrainian',
    'Български': 'Bulgarian',
    'Hrvatski': 'Croatian',
    'Slovenčina': 'Slovak',
    'Slovenščina': 'Slovenian',

    # European - Other
    'Magyar': 'Hungarian',
    'Suomi': 'Finnish',
    'Ελληνικά': 'Greek',

    # Middle Eastern / African
    'Türkçe': 'Turkish',
    'العربية': 'Arabic',
    'עברית': 'Hebrew',

    # Southeast Asian
    'Tiếng Việt': 'Vietnamese',
    'ไทย': 'Thai',
    'Indonesia': 'Indonesian',
    'Bahasa Indonesia': 'Indonesian',
    'Bahasa Melayu': 'Malay',

    # English variants → English
    'English (ANZ)': 'English',
    'English (UK)': 'English',
    'English (India)': 'English',
}

# Languages that are already in correct English form (no mapping needed)
VALID_ENGLISH_NAMES = {
    'English', 'Japanese', 'Korean', 'Chinese', 'Simplified Chinese',
    'Traditional Chinese', 'Spanish', 'French', 'German', 'Portuguese',
    'Italian', 'Russian', 'Arabic', 'Turkish', 'Thai', 'Vietnamese',
    'Indonesian', 'Dutch', 'Polish', 'Czech', 'Hungarian', 'Ukrainian',
    'Bulgarian', 'Romanian', 'Greek', 'Hebrew', 'Swedish', 'Norwegian',
    'Danish', 'Finnish', 'Croatian', 'Slovak', 'Slovenian', 'Catalan',
    'Malay', 'Hindi', 'Bengali', 'Urdu', 'Persian', 'Swahili',
}


def normalize_lang(lang_str):
    """Normalize a single language string to English."""
    lang_str = lang_str.strip()
    if not lang_str:
        return ''

    # Check mapping first
    if lang_str in LANGUAGE_MAP:
        return LANGUAGE_MAP[lang_str]

    # Check if already valid
    if lang_str in VALID_ENGLISH_NAMES:
        return lang_str

    # Case-insensitive check
    for valid in VALID_ENGLISH_NAMES:
        if lang_str.lower() == valid.lower():
            return valid

    # Check mapping case-insensitive
    for key, val in LANGUAGE_MAP.items():
        if lang_str.lower() == key.lower():
            return val

    # Return as-is if unknown (will be logged)
    return lang_str


def normalize_lang_list(lang_list_str):
    """Normalize a semicolon-separated language list string."""
    if not lang_list_str or not lang_list_str.strip():
        return '', 0, []

    langs = [l.strip() for l in lang_list_str.split(';') if l.strip()]
    normalized = []
    seen = set()
    for lang in langs:
        norm = normalize_lang(lang)
        if norm and norm not in seen:
            normalized.append(norm)
            seen.add(norm)

    new_list = '; '.join(normalized)
    new_count = len(normalized)
    return new_list, new_count, normalized


# =============================================================================
# MAIN PROCESSING
# =============================================================================

LANG_LIST_VARS = [
    'SDK_lang_list', 'COM_lang_list', 'GIT_lang_list', 'SPAN_lang_list',
    'ROLE_lang_list', 'DATA_lang_list', 'STORE_lang_list', 'CERT_lang_list',
]

LANG_COUNT_VARS = [
    'SDK_lang', 'COM_lang', 'GIT_lang', 'SPAN_lang',
    'ROLE_lang', 'DATA_lang', 'STORE_lang', 'CERT_lang',
]


def process_directory(results_dir, dry_run=False):
    """Process all JSON files in a coder results directory."""
    changes = []
    unknown_langs = Counter()

    for json_file in sorted(glob.glob(os.path.join(results_dir, '*.json'))):
        if 'summary' in os.path.basename(json_file):
            continue

        try:
            with open(json_file) as f:
                data = json.load(f)
        except:
            continue

        pid = data.get('platform_id') or data.get('platform_ID', '?')
        modified = False

        # Walk through all categories to find lang variables
        for cat_name, cat_data in data.items():
            if not isinstance(cat_data, dict):
                continue

            for list_var, count_var in zip(LANG_LIST_VARS, LANG_COUNT_VARS):
                if list_var in cat_data:
                    old_list = cat_data[list_var]
                    old_count = cat_data.get(count_var, 0)

                    if old_list:
                        new_list, new_count, norm_langs = normalize_lang_list(old_list)

                        if new_list != old_list or new_count != old_count:
                            changes.append({
                                'platform_id': pid,
                                'variable': list_var,
                                'old_list': old_list,
                                'new_list': new_list,
                                'old_count': old_count,
                                'new_count': new_count,
                            })
                            cat_data[list_var] = new_list
                            cat_data[count_var] = new_count
                            modified = True

                        # Track any languages we couldn't normalize
                        for lang in [l.strip() for l in old_list.split(';') if l.strip()]:
                            norm = normalize_lang(lang)
                            if norm not in VALID_ENGLISH_NAMES and norm not in LANGUAGE_MAP.values():
                                unknown_langs[norm] += 1

        # Remove variety variables if still present
        for cat_name, cat_data in data.items():
            if isinstance(cat_data, dict):
                for drop_var in ['LINGUISTIC_VARIETY', 'linguistic_variety_list',
                                 'programming_lang_variety', 'programming_lang_variety_list']:
                    if drop_var in cat_data:
                        del cat_data[drop_var]
                        modified = True

        if modified and not dry_run:
            with open(json_file, 'w') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

    return changes, unknown_langs


def export_language_csv(results_dirs, output_dir, tracker_path):
    """Export language data from all coders as a single CSV for R analysis."""

    # Load tracker for industry and PLAT
    tracker = {}
    with open(tracker_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            tracker[row['platform_ID']] = {
                'industry': row.get('industry', ''),
                'plat': row.get('PLAT', ''),
                'platform_name': row.get('platform_name', ''),
                'country': row.get('home_country_name', ''),
            }

    rows = []
    for results_dir in results_dirs:
        coder_name = 'Claude' if 'claude' in results_dir.lower() else 'ChatGPT'

        for json_file in sorted(glob.glob(os.path.join(results_dir, '*.json'))):
            if 'summary' in os.path.basename(json_file):
                continue
            try:
                with open(json_file) as f:
                    data = json.load(f)
            except:
                continue

            pid = data.get('platform_id') or data.get('platform_ID', '')
            pname = data.get('platform_name', '')

            flat = {}
            for cat_name, cat_data in data.items():
                if isinstance(cat_data, dict) and cat_name not in ('metadata',):
                    flat.update(cat_data)

            info = tracker.get(pid, {})

            row = {
                'platform_id': pid,
                'platform_name': pname,
                'industry': info.get('industry', ''),
                'plat': info.get('plat', ''),
                'country': info.get('country', ''),
                'coder': coder_name,
            }

            # Add all lang count and list variables
            for var in LANG_COUNT_VARS:
                row[var] = flat.get(var, 0)
            for var in LANG_LIST_VARS:
                row[var] = flat.get(var, '')

            # Add programming language variables
            for var in ['SDK_prog_lang', 'GIT_prog_lang', 'SDK_prog_lang_list', 'GIT_prog_lang_list']:
                row[var] = flat.get(var, 0 if 'list' not in var else '')

            # Add home_primary_lang for reference
            row['home_primary_lang'] = flat.get('home_primary_lang', '')

            # Compute platform-level aggregates
            all_langs = set()
            for lvar in LANG_LIST_VARS:
                lst = flat.get(lvar, '')
                if lst:
                    for lang in [l.strip() for l in lst.split(';') if l.strip()]:
                        all_langs.add(lang)
            row['unique_natural_langs'] = len(all_langs)
            row['natural_lang_list_all'] = '; '.join(sorted(all_langs)) if all_langs else ''
            row['is_multilingual'] = 1 if len(all_langs) > 1 else 0

            rows.append(row)

    # Write CSV
    output_path = os.path.join(output_dir, 'language_summary.csv')
    fieldnames = ['platform_id', 'platform_name', 'industry', 'plat', 'country', 'coder'] + \
                 LANG_COUNT_VARS + LANG_LIST_VARS + \
                 ['SDK_prog_lang', 'GIT_prog_lang', 'SDK_prog_lang_list', 'GIT_prog_lang_list',
                  'home_primary_lang', 'unique_natural_langs', 'natural_lang_list_all', 'is_multilingual']

    with open(output_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Exported {len(rows)} rows to {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(description='Normalize language strings in coder results')
    parser.add_argument('results_dirs', nargs='+', help='Coder result directories')
    parser.add_argument('--output', default='language_data/', help='Output directory')
    parser.add_argument('--tracker', default=None, help='Path to ALL_PLATFORMS_URL_TRACKER.csv')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without modifying files')
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Auto-detect tracker path
    tracker_path = args.tracker
    if not tracker_path:
        for candidate in ['../REFERENCE/ALL_PLATFORMS_URL_TRACKER.csv',
                          'ALL_PLATFORMS_URL_TRACKER.csv']:
            if os.path.exists(candidate):
                tracker_path = candidate
                break

    print("=" * 60)
    print("LANGUAGE STRING NORMALIZATION")
    print("=" * 60)
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    print(f"Directories: {args.results_dirs}")
    print()

    all_changes = []
    all_unknown = Counter()

    for results_dir in args.results_dirs:
        coder = 'Claude' if 'claude' in results_dir.lower() else 'ChatGPT'
        print(f"\nProcessing {coder} ({results_dir})...")
        changes, unknown = process_directory(results_dir, dry_run=args.dry_run)
        all_changes.extend(changes)
        all_unknown.update(unknown)
        print(f"  {len(changes)} strings normalized")

    # Write log
    log_path = output_dir / 'normalization_log.txt'
    with open(log_path, 'w') as f:
        f.write(f"Language Normalization Log\n")
        f.write(f"Date: {datetime.now().isoformat()}\n")
        f.write(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}\n")
        f.write(f"Total changes: {len(all_changes)}\n\n")

        for c in all_changes:
            f.write(f"{c['platform_id']} | {c['variable']}\n")
            f.write(f"  Old: {c['old_list']} (count={c['old_count']})\n")
            f.write(f"  New: {c['new_list']} (count={c['new_count']})\n\n")

        if all_unknown:
            f.write(f"\nUnknown languages (not in normalization map):\n")
            for lang, count in all_unknown.most_common():
                f.write(f"  {lang}: {count}\n")

    print(f"\nTotal changes: {len(all_changes)}")
    if all_unknown:
        print(f"\nUnknown languages not in map:")
        for lang, count in all_unknown.most_common():
            print(f"  '{lang}': {count}")

    # Export CSV
    if tracker_path:
        print(f"\nExporting language CSV...")
        export_language_csv(args.results_dirs, str(output_dir), tracker_path)
    else:
        print("\nWARNING: No tracker CSV found, skipping language CSV export")

    print(f"\nLog saved to {log_path}")
    if args.dry_run:
        print("\nDRY RUN complete. Re-run without --dry-run to apply changes.")


if __name__ == '__main__':
    main()
