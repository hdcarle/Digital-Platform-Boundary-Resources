#!/usr/bin/env python3
"""
Human IRR Calculator - 3-Way Inter-Rater Reliability
=====================================================
Compares Human coding against Claude and ChatGPT for the 25 sample platforms.
Calculates pairwise and overall IRR statistics.

Usage:
    python3 human_irr_calculator.py final_output/HUMAN_CODING_TEMPLATE.xlsx claude_results/ chatgpt_results/

Output:
    - 3-way IRR report with agreement rates
    - Pairwise comparisons (Human-Claude, Human-ChatGPT, Claude-ChatGPT)
    - Disagreement analysis
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

try:
    import pandas as pd
    import numpy as np
except ImportError:
    print("ERROR: pandas/numpy not installed. Run: pip3 install pandas numpy openpyxl")
    sys.exit(1)

try:
    from scipy import stats
except ImportError:
    print("WARNING: scipy not installed. ICC calculations will be skipped.")
    stats = None


def load_human_coding(human_file):
    """Load human coding from Excel template."""
    df = pd.read_excel(human_file, sheet_name='Coding')
    results = {}
    for _, row in df.iterrows():
        pid = row['platform_ID']
        codes = {col: row[col] for col in df.columns if col != 'platform_ID'}
        results[pid] = codes
    return results


def load_ai_results(results_dir, coder_name):
    """Load AI coder results from JSON files."""
    results_path = Path(results_dir)
    results = {}

    for json_file in results_path.glob('*_*.json'):
        with open(json_file) as f:
            data = json.load(f)

        pid = data.get('platform_id', json_file.stem.split('_')[0])
        if 'coding' in data:
            results[pid] = data['coding']
        elif 'variables' in data:
            results[pid] = data['variables']

    return results


def calculate_agreement(val1, val2):
    """Calculate if two values agree."""
    # Handle NaN/None
    if pd.isna(val1) and pd.isna(val2):
        return True
    if pd.isna(val1) or pd.isna(val2):
        return False

    # Convert to comparable types
    try:
        v1 = float(val1)
        v2 = float(val2)
        return v1 == v2
    except (ValueError, TypeError):
        return str(val1).lower().strip() == str(val2).lower().strip()


def calculate_pairwise_irr(coder1_results, coder2_results, coder1_name, coder2_name):
    """Calculate IRR between two coders."""
    agreements = 0
    disagreements = 0
    comparisons = []

    common_platforms = set(coder1_results.keys()) & set(coder2_results.keys())

    for pid in common_platforms:
        codes1 = coder1_results[pid]
        codes2 = coder2_results[pid]

        for var in codes1.keys():
            if var in codes2:
                val1 = codes1[var]
                val2 = codes2[var]

                if calculate_agreement(val1, val2):
                    agreements += 1
                else:
                    disagreements += 1
                    comparisons.append({
                        'platform_id': pid,
                        'variable': var,
                        f'{coder1_name}_value': val1,
                        f'{coder2_name}_value': val2
                    })

    total = agreements + disagreements
    agreement_rate = agreements / total if total > 0 else 0

    return {
        'coder1': coder1_name,
        'coder2': coder2_name,
        'platforms': len(common_platforms),
        'agreements': agreements,
        'disagreements': disagreements,
        'total': total,
        'agreement_rate': agreement_rate,
        'disagreement_details': comparisons
    }


def calculate_three_way_agreement(human, claude, chatgpt):
    """Calculate agreement where all three coders agree."""
    all_agree = 0
    two_agree = 0
    none_agree = 0
    total = 0

    common_platforms = set(human.keys()) & set(claude.keys()) & set(chatgpt.keys())

    for pid in common_platforms:
        h_codes = human[pid]
        c_codes = claude[pid]
        g_codes = chatgpt[pid]

        for var in h_codes.keys():
            if var in c_codes and var in g_codes:
                total += 1
                h_val = h_codes[var]
                c_val = c_codes[var]
                g_val = g_codes[var]

                h_c = calculate_agreement(h_val, c_val)
                h_g = calculate_agreement(h_val, g_val)
                c_g = calculate_agreement(c_val, g_val)

                if h_c and h_g and c_g:
                    all_agree += 1
                elif h_c or h_g or c_g:
                    two_agree += 1
                else:
                    none_agree += 1

    return {
        'platforms': len(common_platforms),
        'total_comparisons': total,
        'all_three_agree': all_agree,
        'two_agree': two_agree,
        'none_agree': none_agree,
        'full_agreement_rate': all_agree / total if total > 0 else 0,
        'majority_agreement_rate': (all_agree + two_agree) / total if total > 0 else 0
    }


def main():
    parser = argparse.ArgumentParser(description='Calculate 3-way IRR with human coding')
    parser.add_argument('human_file', help='Human coding Excel file')
    parser.add_argument('claude_dir', help='Claude results directory')
    parser.add_argument('chatgpt_dir', help='ChatGPT results directory')
    parser.add_argument('--output', '-o', default='human_irr_results', help='Output directory')

    args = parser.parse_args()

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("3-WAY IRR CALCULATOR (Human + Claude + ChatGPT)")
    print("=" * 60)

    # Load results
    print("\nLoading results...")
    human = load_human_coding(args.human_file)
    claude = load_ai_results(args.claude_dir, 'claude')
    chatgpt = load_ai_results(args.chatgpt_dir, 'chatgpt')

    print(f"  Human: {len(human)} platforms")
    print(f"  Claude: {len(claude)} platforms")
    print(f"  ChatGPT: {len(chatgpt)} platforms")

    # Calculate pairwise IRR
    print("\nCalculating pairwise IRR...")

    human_claude = calculate_pairwise_irr(human, claude, 'Human', 'Claude')
    human_chatgpt = calculate_pairwise_irr(human, chatgpt, 'Human', 'ChatGPT')
    claude_chatgpt = calculate_pairwise_irr(claude, chatgpt, 'Claude', 'ChatGPT')

    # Calculate 3-way agreement
    print("Calculating 3-way agreement...")
    three_way = calculate_three_way_agreement(human, claude, chatgpt)

    # Print results
    print("\n" + "=" * 60)
    print("PAIRWISE AGREEMENT RATES")
    print("=" * 60)
    print(f"Human vs Claude:   {human_claude['agreement_rate']:.1%} ({human_claude['agreements']}/{human_claude['total']})")
    print(f"Human vs ChatGPT:  {human_chatgpt['agreement_rate']:.1%} ({human_chatgpt['agreements']}/{human_chatgpt['total']})")
    print(f"Claude vs ChatGPT: {claude_chatgpt['agreement_rate']:.1%} ({claude_chatgpt['agreements']}/{claude_chatgpt['total']})")

    print("\n" + "=" * 60)
    print("THREE-WAY AGREEMENT")
    print("=" * 60)
    print(f"Platforms compared: {three_way['platforms']}")
    print(f"Total comparisons:  {three_way['total_comparisons']}")
    print(f"All 3 agree:        {three_way['all_three_agree']} ({three_way['full_agreement_rate']:.1%})")
    print(f"At least 2 agree:   {three_way['all_three_agree'] + three_way['two_agree']} ({three_way['majority_agreement_rate']:.1%})")
    print(f"None agree:         {three_way['none_agree']}")

    # Save detailed report
    report_file = output_dir / 'human_irr_report.txt'
    with open(report_file, 'w') as f:
        f.write("3-WAY INTER-RATER RELIABILITY REPORT\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 60 + "\n\n")

        f.write("PAIRWISE AGREEMENT RATES\n")
        f.write("-" * 40 + "\n")
        f.write(f"Human vs Claude:   {human_claude['agreement_rate']:.1%}\n")
        f.write(f"Human vs ChatGPT:  {human_chatgpt['agreement_rate']:.1%}\n")
        f.write(f"Claude vs ChatGPT: {claude_chatgpt['agreement_rate']:.1%}\n\n")

        f.write("THREE-WAY AGREEMENT\n")
        f.write("-" * 40 + "\n")
        f.write(f"Full agreement (all 3): {three_way['full_agreement_rate']:.1%}\n")
        f.write(f"Majority agreement (2+): {three_way['majority_agreement_rate']:.1%}\n")

    print(f"\n✓ Report saved: {report_file}")

    # Save disagreements for review
    all_disagreements = (
        human_claude['disagreement_details'] +
        human_chatgpt['disagreement_details']
    )

    if all_disagreements:
        disagree_df = pd.DataFrame(all_disagreements)
        disagree_file = output_dir / 'human_disagreements.csv'
        disagree_df.to_csv(disagree_file, index=False)
        print(f"✓ Disagreements saved: {disagree_file}")

    # Save summary JSON
    summary = {
        'pairwise': {
            'human_claude': human_claude['agreement_rate'],
            'human_chatgpt': human_chatgpt['agreement_rate'],
            'claude_chatgpt': claude_chatgpt['agreement_rate']
        },
        'three_way': three_way
    }

    summary_file = output_dir / 'human_irr_summary.json'
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    print(f"✓ Summary saved: {summary_file}")

    print("\n" + "=" * 60)
    print("IRR ANALYSIS COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
