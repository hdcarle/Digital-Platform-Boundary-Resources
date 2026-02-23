#!/usr/bin/env python3
"""
Convert human coding CSV to JSON format for IRR comparison.
"""

import csv
import json
import os
from pathlib import Path

# Define the mapping from CSV columns to our standard variable names
VARIABLE_MAPPING = {
    'DEVP': 'DEVP',
    'BUG': 'BUG',
    'STAN': 'STAN',
    'AI_MODEL': 'AI_MODEL',
    'AI_AGENT': 'AI_AGENT',
    'AI_ASSIST': 'AI_ASSIST',
    'AI_DATA': 'AI_DATA',
    'AI_MKT': 'AI_MKT',
    'GIT': 'GIT',
    'MON': 'MON',
    'ROLE': 'ROLE',
    'DATA': 'DATA',
    'STORE': 'STORE',
    'CERT': 'CERT',
    'COM_social_media': 'COM_social_media',
    'COM_forum': 'COM_forum',
    'COM_blog': 'COM_blog',
    'COM_help_support': 'COM_help_support',
    'COM_live_chat': 'COM_live_chat',
    'COM_Slack': 'COM_Slack',
    'COM_Discord': 'COM_Discord',
    'COM_stackoverflow': 'COM_stackoverflow',
    'COM_training': 'COM_training',
    'COM_FAQ': 'COM_FAQ',
    'COM_tutorials': 'COM_tutorials',
    'COM_Other': 'COM_Other',
    'EVENT_webinars': 'EVENT_webinars',
    'EVENT_virtual': 'EVENT_virtual',
    'EVENT_in_person': 'EVENT_in_person',
    'EVENT_conference': 'EVENT_conference',
    'EVENT_hackathon': 'EVENT_hackathon',
    'SPAN_internal': 'SPAN_internal',
    'SPAN_communities': 'SPAN_communities',
    'SPAN_external': 'SPAN_external',
    'API': 'API',
    'END': 'END',
    'METH': 'METH',
    'DOCS': 'DOCS',
    'SDK': 'SDK',
    'COM': 'COM',
    'EVENT': 'EVENT',
    'SPAN': 'SPAN',
    'LINGUISTIC_VARIETY': 'LINGUISTIC_VARIETY',
    'programming_lang_variety': 'programming_lang_variety',
    'OPEN': 'OPEN'
}

# Binary variables
BINARY_VARS = {
    'DEVP', 'BUG', 'STAN', 'AI_MODEL', 'AI_AGENT', 'AI_ASSIST', 'AI_DATA', 'AI_MKT',
    'GIT', 'MON', 'ROLE', 'DATA', 'STORE', 'CERT',
    'COM_social_media', 'COM_forum', 'COM_blog', 'COM_help_support', 'COM_live_chat',
    'COM_Slack', 'COM_Discord', 'COM_stackoverflow', 'COM_training', 'COM_FAQ',
    'COM_tutorials', 'COM_Other',
    'EVENT_webinars', 'EVENT_virtual', 'EVENT_in_person', 'EVENT_conference', 'EVENT_hackathon',
    'SPAN_internal', 'SPAN_communities', 'SPAN_external',
    'DOCS', 'SDK'  # These were coded binary by human
}

# Count variables
COUNT_VARS = {'API', 'END', 'METH', 'COM', 'EVENT', 'SPAN', 'LINGUISTIC_VARIETY', 'programming_lang_variety'}

# Ordinal variables
ORDINAL_VARS = {'OPEN'}

def parse_value(value, var_name):
    """Parse a value from CSV, handling empty strings and converting types."""
    if value is None or value == '' or value == ' ':
        return None

    # Try to convert to number
    try:
        val = float(value)
        if val.is_integer():
            val = int(val)

        # For binary variables, ensure 0 or 1
        if var_name in BINARY_VARS:
            return 1 if val > 0 else 0

        return val
    except (ValueError, TypeError):
        return None

def convert_human_csv_to_json(csv_path, output_dir):
    """Convert human coding CSV to individual JSON files."""

    os.makedirs(output_dir, exist_ok=True)

    # The 16 platforms that were actually coded by human
    coded_platforms = {
        'VG1', 'VG4', 'VG7', 'VG26', 'VG28', 'VG29', 'VG76', 'VG79',
        'VG80', 'VG91', 'VG98', 'VG100', 'VG102', 'VG110', 'VG121', 'VG173'
    }

    converted_count = 0

    with open(csv_path, 'r', encoding='utf-8') as f:
        # Skip header rows until we find the actual data header
        for line in f:
            if line.startswith('platform_ID,platform_name,AGE'):
                break

        # Now read the rest as CSV with the header we just found
        reader = csv.DictReader(f, fieldnames=line.strip().split(','))

        for row in reader:
            platform_id = row.get('platform_ID', '')
            platform_name = row.get('platform_name', '')

            # Skip if not in the coded platforms
            if platform_id not in coded_platforms:
                continue

            # Build the coding result
            result = {
                'platform_id': platform_id,
                'platform_name': platform_name,
                'coder': 'human',
                'variables': {}
            }

            # Extract each variable
            for csv_col, var_name in VARIABLE_MAPPING.items():
                if csv_col in row:
                    value = parse_value(row[csv_col], var_name)
                    if value is not None:
                        result['variables'][var_name] = value

            # Save to JSON file
            output_path = os.path.join(output_dir, f"{platform_id}_human.json")
            with open(output_path, 'w') as outf:
                json.dump(result, outf, indent=2)

            converted_count += 1
            print(f"Converted: {platform_id} - {platform_name}")

    print(f"\nTotal platforms converted: {converted_count}")
    return converted_count

if __name__ == "__main__":
    csv_path = "final_output/HUMAN_CODING_RESULTS.csv"
    output_dir = "human_results"

    convert_human_csv_to_json(csv_path, output_dir)
