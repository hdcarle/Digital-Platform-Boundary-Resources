#!/usr/bin/env python3
"""
Fix DOCS and SDK values in Claude results to be binary (0/1) instead of counts.
"""

import json
import os
from pathlib import Path

# The 16 test platforms
TEST_PLATFORMS = [
    'VG1', 'VG4', 'VG7', 'VG26', 'VG28', 'VG29', 'VG76', 'VG79',
    'VG80', 'VG91', 'VG98', 'VG100', 'VG102', 'VG110', 'VG121', 'VG173'
]

# Variables that should be binary (by section)
BINARY_VARS_BY_SECTION = {
    'development': ['DEVP', 'DOCS', 'SDK', 'BUG', 'STAN'],
    'ai': ['AI_MODEL', 'AI_AGENT', 'AI_ASSIST', 'AI_DATA', 'AI_MKT'],
    'social': [
        'COM_social_media', 'COM_forum', 'COM_blog', 'COM_help_support',
        'COM_live_chat', 'COM_Slack', 'COM_Discord', 'COM_stackoverflow',
        'COM_training', 'COM_FAQ', 'COM_tutorials', 'COM_Other',
        'GIT', 'MON',
        'EVENT_webinars', 'EVENT_virtual', 'EVENT_in_person', 'EVENT_conference', 'EVENT_hackathon',
        'SPAN_internal', 'SPAN_communities', 'SPAN_external'
    ],
    'governance': ['ROLE', 'DATA', 'STORE', 'CERT']
}

def fix_claude_results(results_dir='claude_results'):
    """Fix all binary variables to be 0/1 in Claude results."""

    fixed_count = 0

    for platform_id in TEST_PLATFORMS:
        filepath = os.path.join(results_dir, f"{platform_id}_claude.json")

        if not os.path.exists(filepath):
            print(f"  {platform_id}: File not found")
            continue

        with open(filepath, 'r') as f:
            data = json.load(f)

        changes = []

        # Fix variables in each section
        for section, vars_list in BINARY_VARS_BY_SECTION.items():
            if section in data:
                for var in vars_list:
                    if var in data[section]:
                        old_val = data[section][var]
                        if old_val not in [0, 1]:
                            # Convert to binary: 0 stays 0, any positive value becomes 1
                            new_val = 1 if old_val > 0 else 0
                            data[section][var] = new_val
                            changes.append(f"{var}: {old_val} -> {new_val}")

        if changes:
            # Save fixed file
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2)
            print(f"  {platform_id}: Fixed - {', '.join(changes)}")
            fixed_count += 1
        else:
            print(f"  {platform_id}: Already binary")

    return fixed_count

if __name__ == "__main__":
    import sys

    results_dir = sys.argv[1] if len(sys.argv) > 1 else 'claude_results'

    print(f"Fixing binary variables in {results_dir}...")
    print("-" * 60)

    fixed = fix_claude_results(results_dir)

    print("-" * 60)
    print(f"Total platforms fixed: {fixed}")
