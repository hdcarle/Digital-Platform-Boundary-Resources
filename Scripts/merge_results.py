#!/usr/bin/env python3
"""
Merge Results Script for Multi-Coder Workflow
==============================================
Reconciles Claude and ChatGPT coding results using majority vote logic.
Creates final dataset in CODE_BOOK format (124 columns, dyadic structure).

Usage:
    python3 merge_results.py claude_results/ chatgpt_results/ --tracker tracker.xlsx --output final_results/
    python3 merge_results.py claude_results/ chatgpt_results/ --countries countries.csv
    python3 merge_results.py claude_results/ chatgpt_results/ --dry-run

Input:
    - Claude results folder (from claude_coder.py)
    - ChatGPT results folder (from chatgpt_coder.py)
    - Tracker file with platform metadata
    - Countries file for dyadic expansion

Output:
    - Merged results CSV (reconciled codings)
    - Disagreement log (for human review)
    - Final CODE_BOOK format Excel file
"""

import os
import sys
import json
import argparse
from datetime import datetime
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    print("ERROR: pandas not installed. Run: pip3 install pandas openpyxl")
    sys.exit(1)


# ============================================================================
# CONFIGURATION
# ============================================================================

# All BR variables to code (matching CODE_BOOK_v_1_27_26_updated.xlsx columns M-CU)
BR_VARIABLES = {
    # Application (M-T)
    'API': {'type': 'count', 'category': 'application'},
    'API_pages': {'type': 'count', 'category': 'application'},
    'APIspecs': {'type': 'count', 'category': 'application'},
    'APIspec_list': {'type': 'text', 'category': 'application'},
    'END': {'type': 'count', 'category': 'application'},
    'END_Pages': {'type': 'count', 'category': 'application'},
    'METH': {'type': 'count', 'category': 'application'},
    'METH_list': {'type': 'text', 'category': 'application'},

    # Development (U-AF)
    'DEVP': {'type': 'binary', 'category': 'development'},
    'DOCS': {'type': 'count', 'category': 'development'},
    'SDK': {'type': 'count', 'category': 'development'},
    'SDK_lang': {'type': 'count', 'category': 'development'},
    'SDK_lang_list': {'type': 'text', 'category': 'development'},
    'SDK_prog_lang': {'type': 'count', 'category': 'development'},
    'SDK_prog_lang_list': {'type': 'text', 'category': 'development'},
    'BUG': {'type': 'binary', 'category': 'development'},
    'BUG_types': {'type': 'text', 'category': 'development'},
    'BUG_prog_lang_list': {'type': 'text', 'category': 'development'},
    'STAN': {'type': 'binary', 'category': 'development'},
    'STAN_list': {'type': 'text', 'category': 'development'},

    # AI (AG-AP)
    'AI_MODEL': {'type': 'binary', 'category': 'ai'},
    'AI_MODEL_types': {'type': 'text', 'category': 'ai'},
    'AI_AGENT': {'type': 'binary', 'category': 'ai'},
    'AI_AGENT_platforms': {'type': 'text', 'category': 'ai'},
    'AI_ASSIST': {'type': 'binary', 'category': 'ai'},
    'AI_ASSIST_tools': {'type': 'text', 'category': 'ai'},
    'AI_DATA': {'type': 'binary', 'category': 'ai'},
    'AI_DATA_protocols': {'type': 'text', 'category': 'ai'},
    'AI_MKT': {'type': 'binary', 'category': 'ai'},
    'AI_MKT_type': {'type': 'text', 'category': 'ai'},

    # Social - COM (AQ-BF)
    'COM': {'type': 'count', 'category': 'social'},
    'COM_lang': {'type': 'count', 'category': 'social'},
    'COM_lang_list': {'type': 'text', 'category': 'social'},
    'COM_social_media': {'type': 'binary', 'category': 'social'},
    'COM_forum': {'type': 'binary', 'category': 'social'},
    'COM_blog': {'type': 'binary', 'category': 'social'},
    'COM_help_support': {'type': 'binary', 'category': 'social'},
    'COM_live_chat': {'type': 'binary', 'category': 'social'},
    'COM_Slack': {'type': 'binary', 'category': 'social'},
    'COM_Discord': {'type': 'binary', 'category': 'social'},
    'COM_stackoverflow': {'type': 'binary', 'category': 'social'},
    'COM_training': {'type': 'binary', 'category': 'social'},
    'COM_FAQ': {'type': 'binary', 'category': 'social'},
    'COM_tutorials': {'type': 'binary', 'category': 'social'},
    'COM_Other': {'type': 'binary', 'category': 'social'},
    'COM_Other_notes': {'type': 'text', 'category': 'social'},

    # Social - GIT (BG-BL)
    'GIT': {'type': 'binary', 'category': 'social'},
    'GIT_url': {'type': 'text', 'category': 'social'},
    'GIT_lang': {'type': 'count', 'category': 'social'},
    'GIT_lang_list': {'type': 'text', 'category': 'social'},
    'GIT_prog_lang': {'type': 'count', 'category': 'social'},
    'GIT_prog_lang_list': {'type': 'text', 'category': 'social'},

    # Social - MON, EVENT, SPAN (BM-CB)
    'MON': {'type': 'binary', 'category': 'social'},
    'EVENT': {'type': 'count', 'category': 'social'},
    'EVENT_webinars': {'type': 'binary', 'category': 'social'},
    'EVENT_virtual': {'type': 'binary', 'category': 'social'},
    'EVENT_in_person': {'type': 'binary', 'category': 'social'},
    'EVENT_conference': {'type': 'binary', 'category': 'social'},
    'EVENT_hackathon': {'type': 'binary', 'category': 'social'},
    'EVENT_other': {'type': 'text', 'category': 'social'},
    'EVENT_countries': {'type': 'text', 'category': 'social'},
    'SPAN': {'type': 'count', 'category': 'social'},
    'SPAN_internal': {'type': 'binary', 'category': 'social'},
    'SPAN_communities': {'type': 'binary', 'category': 'social'},
    'SPAN_external': {'type': 'binary', 'category': 'social'},
    'SPAN_lang': {'type': 'count', 'category': 'social'},
    'SPAN_lang_list': {'type': 'text', 'category': 'social'},
    'SPAN_countries': {'type': 'text', 'category': 'social'},

    # Governance (CC-CQ)
    'ROLE': {'type': 'binary', 'category': 'governance'},
    'ROLE_lang': {'type': 'count', 'category': 'governance'},
    'ROLE_lang_list': {'type': 'text', 'category': 'governance'},
    'DATA': {'type': 'binary', 'category': 'governance'},
    'DATA_lang': {'type': 'count', 'category': 'governance'},
    'DATA_lang_list': {'type': 'text', 'category': 'governance'},
    'STORE': {'type': 'binary', 'category': 'governance'},
    'STORE_lang': {'type': 'count', 'category': 'governance'},
    'STORE_lang_list': {'type': 'text', 'category': 'governance'},
    'CERT': {'type': 'binary', 'category': 'governance'},
    'CERT_lang': {'type': 'count', 'category': 'governance'},
    'CERT_lang_list': {'type': 'text', 'category': 'governance'},
    'OPEN': {'type': 'ordinal', 'category': 'governance'},
    'OPEN_lang': {'type': 'count', 'category': 'governance'},
    'OPEN_lang_list': {'type': 'text', 'category': 'governance'},

    # Note: LINGUISTIC_VARIETY and programming_lang_variety removed - these are
    # computed variables calculated in final R analysis, not coded by AI coders
}

# CODE_BOOK column structure (124 columns matching CODE_BOOK_v_1_27_26_updated.xlsx)
CODE_BOOK_COLUMNS = [
    # Identification (A-L)
    'Dyad_ID', 'platform_ID', 'platform_name', 'home_country_name', 'home_country_iso3c',
    'host_country_name', 'host_country_iso3c', 'developer_portal_url', 'PLAT', 'PLAT_Notes',
    'IND', 'ID_IND',

    # Application (M-T)
    'API', 'API_pages', 'APIspecs', 'APIspec_list', 'END', 'END_Pages', 'METH', 'METH_list',

    # Development (U-AF)
    'DEVP', 'DOCS', 'SDK', 'SDK_lang', 'SDK_lang_list', 'SDK_prog_lang', 'SDK_prog_lang_list',
    'BUG', 'BUG_types', 'BUG_prog_lang_list', 'BUG_prog_lang', 'STAN', 'STAN_list',

    # AI (AG-AP)
    'AI_MODEL', 'AI_MODEL_types', 'AI_AGENT', 'AI_AGENT_platforms', 'AI_ASSIST', 'AI_ASSIST_tools',
    'AI_DATA', 'AI_DATA_protocols', 'AI_MKT', 'AI_MKT_type',

    # Social - COM (AQ-BF)
    'COM', 'COM_lang', 'COM_lang_list', 'COM_social_media', 'COM_forum', 'COM_blog',
    'COM_help_support', 'COM_live_chat', 'COM_Slack', 'COM_Discord', 'COM_stackoverflow',
    'COM_training', 'COM_FAQ', 'COM_tutorials', 'COM_Other', 'COM_Other_notes',

    # Social - GIT (BG-BL)
    'GIT', 'GIT_url', 'GIT_lang', 'GIT_lang_list', 'GIT_prog_lang', 'GIT_prog_lang_list',

    # Social - MON, EVENT, SPAN (BM-CB)
    'MON', 'EVENT', 'EVENT_webinars', 'EVENT_virtual', 'EVENT_in_person', 'EVENT_conference',
    'EVENT_hackathon', 'EVENT_other', 'EVENT_countries', 'SPAN', 'SPAN_internal',
    'SPAN_communities', 'SPAN_external', 'SPAN_lang', 'SPAN_lang_list', 'SPAN_countries',

    # Governance (CC-CQ)
    'ROLE', 'ROLE_lang', 'ROLE_lang_list', 'DATA', 'DATA_lang', 'DATA_lang_list',
    'STORE', 'STORE_lang', 'STORE_lang_list', 'CERT', 'CERT_lang', 'CERT_lang_list',
    'OPEN', 'OPEN_lang', 'OPEN_lang_list',

    # Moderators (CR-CU)
    # Note: LINGUISTIC_VARIETY and programming_lang_variety removed - computed in R analysis

    # Controls (CV-CY)
    'home_primary_lang', 'language_notes', 'AGE', 'API_YEAR',

    # Controls
    'IND_GROW', 'home_gdp_per_capita', 'home_internet_users', 'home_population',
    'host_gdp_per_capita', 'host_Internet_users', 'host_population', 'home_ef_epi_rank',
    'host_ef_epi_rank', 'cultural_distance', 'market_share_pct',

    # Metadata (DP-DT)
    'analysis_date', 'pages_analyzed', 'Coder', 'Human_reviewed', 'coding_notes'
]


# ============================================================================
# MERGER CLASS
# ============================================================================

class ResultsMerger:
    """Merges and reconciles multi-coder results."""

    def __init__(self, output_dir: str, verbose: bool = True):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose

    def log(self, msg: str):
        if self.verbose:
            print(msg)

    def load_coder_results(self, results_dir: str, coder_name: str) -> dict:
        """Load all results from a coder's output directory."""
        results_dir = Path(results_dir)
        results = {}

        # Load individual JSON files
        for json_file in results_dir.glob("*.json"):
            if json_file.name in ['coding_summary.json', 'coding_prompt.txt', 'summary']:
                continue

            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    platform_id = data.get('platform_id', json_file.stem)

                    # Flatten nested category structure
                    flat = {
                        'platform_id': platform_id,
                        'platform_name': data.get('platform_name'),
                        'plat_status': data.get('PLAT') or data.get('plat_status'),
                        'portal_url': data.get('portal_url') or data.get('developer_portal_url'),
                    }

                    # Flatten category-level codings
                    for category in ['application', 'development', 'ai', 'social', 'governance', 'moderators']:
                        if category in data and isinstance(data[category], dict):
                            flat.update(data[category])

                    # Also check for 'codings' key (alternative structure)
                    if 'codings' in data and isinstance(data['codings'], dict):
                        flat.update(data['codings'])

                    results[platform_id] = flat

            except Exception as e:
                self.log(f"  Warning: Could not load {json_file}: {e}")

        self.log(f"  Loaded {len(results)} results from {coder_name}")
        return results

    def reconcile_value(self, val1, val2, var_name: str, var_info: dict) -> tuple:
        """
        Reconcile two coder values using majority vote logic.
        Returns (final_value, agreement_status, needs_review).
        """
        # Handle None/missing values
        if val1 is None and val2 is None:
            return None, 'both_missing', False
        if val1 is None:
            return val2, 'coder1_missing', True
        if val2 is None:
            return val1, 'coder2_missing', True

        # Check agreement
        if val1 == val2:
            return val1, 'agree', False

        # Disagreement - apply type-specific logic
        var_type = var_info.get('type', 'binary')

        if var_type == 'binary':
            # For binary, 1 wins (presence is harder to fake)
            if val1 == 1 or val2 == 1:
                return 1, 'disagree_presence_wins', True
            return 0, 'disagree_default_zero', True

        elif var_type == 'count':
            # For counts, take the average (rounded up)
            try:
                avg = (int(val1) + int(val2)) / 2
                return int(avg + 0.5), 'disagree_averaged', True
            except:
                return val1, 'disagree_coder1_default', True

        elif var_type == 'categorical':
            # For categorical, prefer non-None/non-empty
            if val1 in [None, '', 'None', 'Unknown']:
                return val2, 'disagree_coder2_valid', True
            if val2 in [None, '', 'None', 'Unknown']:
                return val1, 'disagree_coder1_valid', True
            # True disagreement - default to coder1 but flag for review
            return val1, 'disagree_coder1_default', True

        else:
            return val1, 'disagree_unknown_type', True

    def merge_platform(self, platform_id: str, claude_data: dict, chatgpt_data: dict) -> dict:
        """Merge results for a single platform."""
        merged = {
            'platform_id': platform_id,
            'platform_name': claude_data.get('platform_name') or chatgpt_data.get('platform_name'),
            'plat_status': claude_data.get('plat_status') or chatgpt_data.get('plat_status'),
            'portal_url': claude_data.get('portal_url') or chatgpt_data.get('portal_url'),
            'merge_date': datetime.now().isoformat(),
            'codings': {},
            'disagreements': [],
            'agreement_count': 0,
            'disagreement_count': 0,
        }

        # Variables are at top level after flattening in load_coder_results
        claude_codings = claude_data
        chatgpt_codings = chatgpt_data

        # Merge each variable
        for var_name, var_info in BR_VARIABLES.items():
            val1 = claude_codings.get(var_name)
            val2 = chatgpt_codings.get(var_name)

            final_val, status, needs_review = self.reconcile_value(val1, val2, var_name, var_info)

            merged['codings'][var_name] = final_val

            if status == 'agree':
                merged['agreement_count'] += 1
            else:
                merged['disagreement_count'] += 1
                if needs_review:
                    merged['disagreements'].append({
                        'variable': var_name,
                        'claude_value': val1,
                        'chatgpt_value': val2,
                        'final_value': final_val,
                        'resolution': status
                    })

        return merged

    def merge_all(self, claude_dir: str, chatgpt_dir: str, tracker_file: str = None) -> dict:
        """Merge all results from both coders."""
        self.log(f"\n{'='*60}")
        self.log("MERGING CODER RESULTS")
        self.log(f"{'='*60}")

        # Load results
        self.log("\nLoading Claude results...")
        claude_results = self.load_coder_results(claude_dir, "Claude")

        self.log("Loading ChatGPT results...")
        chatgpt_results = self.load_coder_results(chatgpt_dir, "ChatGPT")

        # Find common platforms
        claude_ids = set(claude_results.keys())
        chatgpt_ids = set(chatgpt_results.keys())
        common_ids = claude_ids & chatgpt_ids
        only_claude = claude_ids - chatgpt_ids
        only_chatgpt = chatgpt_ids - claude_ids

        self.log(f"\nPlatform coverage:")
        self.log(f"  Both coders: {len(common_ids)}")
        self.log(f"  Claude only: {len(only_claude)}")
        self.log(f"  ChatGPT only: {len(only_chatgpt)}")

        # Merge common platforms
        merged_results = {
            'merge_date': datetime.now().isoformat(),
            'claude_dir': str(claude_dir),
            'chatgpt_dir': str(chatgpt_dir),
            'platforms_both': len(common_ids),
            'platforms_claude_only': len(only_claude),
            'platforms_chatgpt_only': len(only_chatgpt),
            'platforms': [],
            'all_disagreements': []
        }

        self.log(f"\nMerging {len(common_ids)} platforms...")

        for platform_id in sorted(common_ids):
            merged = self.merge_platform(
                platform_id,
                claude_results[platform_id],
                chatgpt_results[platform_id]
            )
            merged_results['platforms'].append(merged)
            merged_results['all_disagreements'].extend(merged['disagreements'])

        # Add platforms only in one coder (use their data directly)
        for platform_id in only_claude:
            data = claude_results[platform_id]
            data['source'] = 'claude_only'
            data['merge_date'] = datetime.now().isoformat()
            merged_results['platforms'].append(data)

        for platform_id in only_chatgpt:
            data = chatgpt_results[platform_id]
            data['source'] = 'chatgpt_only'
            data['merge_date'] = datetime.now().isoformat()
            merged_results['platforms'].append(data)

        # Calculate summary stats
        total_vars = len(BR_VARIABLES)
        total_comparisons = len(common_ids) * total_vars
        total_agreements = sum(p.get('agreement_count', 0) for p in merged_results['platforms'] if 'agreement_count' in p)

        merged_results['summary'] = {
            'total_platforms': len(merged_results['platforms']),
            'total_variables': total_vars,
            'total_comparisons': total_comparisons,
            'total_agreements': total_agreements,
            'total_disagreements': len(merged_results['all_disagreements']),
            'overall_agreement_rate': total_agreements / total_comparisons if total_comparisons > 0 else 0
        }

        return merged_results

    def create_codebook_df(self, merged_results: dict, tracker_file: str = None, countries_file: str = None) -> pd.DataFrame:
        """Create DataFrame in CODE_BOOK format (124 columns, dyadic structure)."""

        # Load tracker for additional metadata
        tracker_df = None
        if tracker_file and os.path.exists(tracker_file):
            if tracker_file.endswith('.csv'):
                tracker_df = pd.read_csv(tracker_file)
            else:
                tracker_df = pd.read_excel(tracker_file, header=1)
            tracker_df = tracker_df.set_index('platform_ID')

        # Load countries for dyadic expansion
        countries = ['USA']  # Default
        if countries_file and os.path.exists(countries_file):
            countries_df = pd.read_csv(countries_file)
            if 'country' in countries_df.columns:
                countries = countries_df['country'].tolist()
            elif 'host_country' in countries_df.columns:
                countries = countries_df['host_country'].tolist()

        rows = []

        for platform_data in merged_results['platforms']:
            platform_id = platform_data.get('platform_id')
            codings = platform_data.get('codings', {})

            # Get tracker metadata if available
            tracker_meta = {}
            if tracker_df is not None and platform_id in tracker_df.index:
                tracker_meta = tracker_df.loc[platform_id].to_dict()

            # Create row for each country (dyadic expansion)
            for country in countries:
                row = {col: None for col in CODE_BOOK_COLUMNS}

                # Identification
                row['platform_ID'] = platform_id
                row['platform_name'] = platform_data.get('platform_name') or tracker_meta.get('platform_name')
                row['host_country'] = country
                row['developer_portal_url'] = platform_data.get('portal_url') or tracker_meta.get('developer_portal_url')
                row['PLAT'] = platform_data.get('plat_status') or tracker_meta.get('PLAT')
                row['scrape_date'] = platform_data.get('merge_date', datetime.now().isoformat())[:10]
                row['coder'] = 'merged_claude_chatgpt'

                # Copy tracker metadata
                for key in ['platform_industry', 'platform_sub_industry', 'host_region']:
                    if key in tracker_meta:
                        row[key] = tracker_meta[key]

                # Copy BR codings
                for var_name, value in codings.items():
                    if var_name in row:
                        row[var_name] = value

                rows.append(row)

        df = pd.DataFrame(rows, columns=CODE_BOOK_COLUMNS)
        return df

    def save_results(self, merged_results: dict, tracker_file: str = None, countries_file: str = None):
        """Save all merge outputs."""

        # Save merged JSON
        merged_file = self.output_dir / "merged_results.json"
        with open(merged_file, 'w') as f:
            json.dump(merged_results, f, indent=2, default=str)
        self.log(f"\n✓ Saved merged JSON: {merged_file}")

        # Save disagreements log
        if merged_results['all_disagreements']:
            disagree_df = pd.DataFrame(merged_results['all_disagreements'])
            disagree_file = self.output_dir / "disagreements_for_review.csv"
            disagree_df.to_csv(disagree_file, index=False)
            self.log(f"✓ Saved disagreements: {disagree_file}")

        # Create and save CODE_BOOK format
        codebook_df = self.create_codebook_df(merged_results, tracker_file, countries_file)

        csv_file = self.output_dir / "merged_results.csv"
        codebook_df.to_csv(csv_file, index=False)
        self.log(f"✓ Saved CSV: {csv_file}")

        excel_file = self.output_dir / "CODE_BOOK_merged.xlsx"
        codebook_df.to_excel(excel_file, index=False, sheet_name='Coded Data')
        self.log(f"✓ Saved Excel: {excel_file}")

        # Print summary
        self.log(f"\n{'='*60}")
        self.log("MERGE SUMMARY")
        self.log(f"{'='*60}")
        summary = merged_results.get('summary', {})
        self.log(f"Total platforms: {summary.get('total_platforms', 0)}")
        self.log(f"Total comparisons: {summary.get('total_comparisons', 0)}")
        self.log(f"Agreements: {summary.get('total_agreements', 0)}")
        self.log(f"Disagreements: {summary.get('total_disagreements', 0)}")
        self.log(f"Agreement rate: {summary.get('overall_agreement_rate', 0):.1%}")
        self.log(f"\nOutput directory: {self.output_dir}")
        self.log(f"{'='*60}\n")

        return codebook_df


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Merge Claude and ChatGPT coding results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 merge_results.py claude_results/ chatgpt_results/ --output final/
    python3 merge_results.py claude_results/ chatgpt_results/ --tracker tracker.xlsx
    python3 merge_results.py claude_results/ chatgpt_results/ --countries countries.csv
        """
    )
    parser.add_argument('claude_dir', help='Directory with Claude coder results')
    parser.add_argument('chatgpt_dir', help='Directory with ChatGPT coder results')
    parser.add_argument('--output', '-o', default='merged_results', help='Output directory')
    parser.add_argument('--tracker', '-t', help='Tracker file with platform metadata')
    parser.add_argument('--countries', '-c', help='Countries file for dyadic expansion')
    parser.add_argument('--dry-run', action='store_true', help='Preview without saving')
    parser.add_argument('--quiet', '-q', action='store_true', help='Minimal output')

    args = parser.parse_args()

    # Validate inputs
    if not os.path.isdir(args.claude_dir):
        print(f"ERROR: Claude results directory not found: {args.claude_dir}")
        sys.exit(1)

    if not os.path.isdir(args.chatgpt_dir):
        print(f"ERROR: ChatGPT results directory not found: {args.chatgpt_dir}")
        sys.exit(1)

    # Run merger
    merger = ResultsMerger(
        output_dir=args.output,
        verbose=not args.quiet
    )

    merged_results = merger.merge_all(
        claude_dir=args.claude_dir,
        chatgpt_dir=args.chatgpt_dir,
        tracker_file=args.tracker
    )

    if not args.dry_run:
        merger.save_results(
            merged_results,
            tracker_file=args.tracker,
            countries_file=args.countries
        )

        print(f"\nNext steps:")
        print(f"  1. Review disagreements in: {args.output}/disagreements_for_review.csv")
        print(f"  2. Final dataset ready: {args.output}/CODE_BOOK_merged.xlsx")
        print(f"  3. Run IRR analysis: python3 irr_calculator.py {args.claude_dir}/ {args.chatgpt_dir}/")
    else:
        print(f"\n🔍 DRY RUN - Results not saved")
        print(f"Would merge {merged_results['summary']['total_platforms']} platforms")


if __name__ == "__main__":
    main()
