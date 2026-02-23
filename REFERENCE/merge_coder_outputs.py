"""
Multi-Coder Resolution and Merge Script
========================================
Merges coding outputs from Claude, ChatGPT, and Human coders
Calculates agreement scores and applies resolution rules
Merges resolved coding onto CODE_BOOK dyads

Author: Dissertation Data Collection Workflow
Date: 2026-02-07
"""

import pandas as pd
import numpy as np
from datetime import datetime
from collections import Counter
import warnings
warnings.filterwarnings('ignore')

# ============================================================================
# CONFIGURATION
# ============================================================================

# File paths (update these as needed)
CODEBOOK_PATH = 'CODE_BOOK_v_2_5_26_filtered.csv'
COUNTRY_LANG_LOOKUP_PATH = 'country_language_lookup.csv'
CLAUDE_CODING_PATH = 'claude_platform_coding.csv'
CHATGPT_CODING_PATH = 'chatgpt_platform_coding.csv'
HUMAN_CODING_PATH = 'human_platform_coding.csv'  # subset only
OUTPUT_PATH = 'CODE_BOOK_final.csv'
RESOLUTION_LOG_PATH = 'coder_resolution_log.csv'

# Variable types for resolution rules
BINARY_VARS = [
    'PLAT', 'DEVP', 'DOCS', 'SDK', 'BUG', 'STAN',
    'AI_MODEL', 'AI_AGENT', 'AI_ASSIST', 'AI_DATA', 'AI_MKT',
    'COM_forum', 'COM_blog', 'COM_help_support', 'COM_live_chat',
    'COM_Slack', 'COM_Discord', 'COM_stackoverflow', 'COM_training',
    'COM_FAQ', 'COM_tutorials', 'COM_Other', 'GIT', 'MON',
    'EVENT', 'EVENT_webinars', 'EVENT_virtual', 'EVENT_in_person',
    'EVENT_conference', 'EVENT_hackathon', 'EVENT_other',
    'SPAN', 'SPAN_internal', 'SPAN_communities', 'SPAN_external',
    'ROLE', 'DATA', 'STORE', 'CERT'
]

COUNT_VARS = [
    'AGE', 'API', 'API_pages', 'APIspecs', 'END', 'END_Pages', 'METH',
    'COM', 'COM_social_media',
    'SDK_lang', 'SDK_prog_lang', 'COM_lang', 'GIT_lang', 'GIT_prog_lang',
    'SPAN_lang', 'ROLE_lang', 'DATA_lang', 'STORE_lang', 'CERT_lang', 'OPEN_lang',
    'pages_analyzed'
]

LIST_VARS = [
    'APIspec_list', 'METH_list', 'SDK_lang_list', 'SDK_prog_lang_list',
    'BUG_types', 'BUG_prog_lang_list', 'STAN_list',
    'AI_MODEL_types', 'AI_AGENT_platforms', 'AI_ASSIST_tools',
    'AI_DATA_protocols', 'AI_MKT_type',
    'COM_lang_list', 'COM_Other_notes', 'GIT_url', 'GIT_lang_list',
    'GIT_prog_lang_list', 'EVENT_countries',
    'SPAN_lang_list', 'SPAN_countries',
    'ROLE_lang_list', 'DATA_lang_list', 'STORE_lang_list',
    'CERT_lang_list', 'OPEN_lang_list',
    'coding_notes'
]

TEXT_VARS = ['PLAT_Notes', 'developer_portal_url', 'API_YEAR']

# ============================================================================
# RESOLUTION FUNCTIONS
# ============================================================================

def resolve_binary(claude_val, chatgpt_val, human_val=None):
    """
    Resolve binary variables using majority vote
    Returns: (resolved_value, source_code)
    Source codes: C=Claude, G=ChatGPT, H=Human, CG=agreement, CGH=all agree, ADJ=needs adjudication
    """
    values = []
    if pd.notna(claude_val): values.append(('C', int(claude_val)))
    if pd.notna(chatgpt_val): values.append(('G', int(chatgpt_val)))
    if pd.notna(human_val): values.append(('H', int(human_val)))

    if len(values) == 0:
        return np.nan, 'MISSING'

    if len(values) == 1:
        return values[0][1], values[0][0]

    # Check for agreement
    unique_vals = set(v[1] for v in values)

    if len(unique_vals) == 1:
        # All agree
        sources = ''.join(sorted(v[0] for v in values))
        return values[0][1], sources

    # Disagreement - use majority
    counts = Counter(v[1] for v in values)
    majority_val, majority_count = counts.most_common(1)[0]

    if majority_count > 1:
        # Clear majority
        sources = ''.join(sorted(v[0] for v in values if v[1] == majority_val))
        return majority_val, sources

    # No majority - needs adjudication
    return np.nan, 'ADJ'


def resolve_count(claude_val, chatgpt_val, human_val=None, tolerance=1):
    """
    Resolve count variables using median if within tolerance
    Returns: (resolved_value, source_code)
    """
    values = []
    if pd.notna(claude_val): values.append(('C', float(claude_val)))
    if pd.notna(chatgpt_val): values.append(('G', float(chatgpt_val)))
    if pd.notna(human_val): values.append(('H', float(human_val)))

    if len(values) == 0:
        return np.nan, 'MISSING'

    if len(values) == 1:
        return int(values[0][1]), values[0][0]

    nums = [v[1] for v in values]

    # Check if within tolerance
    if max(nums) - min(nums) <= tolerance:
        median_val = int(np.median(nums))
        sources = ''.join(sorted(v[0] for v in values))
        return median_val, sources

    # Large disagreement - needs adjudication
    return int(np.median(nums)), 'ADJ'


def resolve_list(claude_val, chatgpt_val, human_val=None):
    """
    Resolve list variables by taking union of all values
    Returns: (resolved_value, source_code)
    """
    all_items = set()
    sources = []

    for val, code in [(claude_val, 'C'), (chatgpt_val, 'G'), (human_val, 'H')]:
        if pd.notna(val) and str(val).strip():
            sources.append(code)
            # Split by semicolon, comma, or newline
            items = str(val).replace(',', ';').replace('\n', ';').split(';')
            for item in items:
                item = item.strip()
                if item:
                    all_items.add(item)

    if not all_items:
        return '', 'MISSING'

    resolved = ';'.join(sorted(all_items))
    source_code = ''.join(sorted(sources))

    return resolved, source_code


def resolve_text(claude_val, chatgpt_val, human_val=None):
    """
    Resolve text variables - prefer human, then longest response
    Returns: (resolved_value, source_code)
    """
    if pd.notna(human_val) and str(human_val).strip():
        return str(human_val), 'H'

    vals = []
    if pd.notna(claude_val) and str(claude_val).strip():
        vals.append(('C', str(claude_val)))
    if pd.notna(chatgpt_val) and str(chatgpt_val).strip():
        vals.append(('G', str(chatgpt_val)))

    if not vals:
        return '', 'MISSING'

    # Return longest
    vals.sort(key=lambda x: len(x[1]), reverse=True)
    return vals[0][1], vals[0][0]


# ============================================================================
# LINGUISTIC VARIETY CALCULATION
# ============================================================================

def calculate_linguistic_variety(row):
    """
    Calculate linguistic variety as count of unique natural languages
    across all _lang_list columns
    """
    lang_cols = [col for col in row.index if col.endswith('_lang_list')]

    all_langs = set()
    for col in lang_cols:
        if pd.notna(row[col]) and str(row[col]).strip():
            langs = str(row[col]).replace(',', ';').split(';')
            for lang in langs:
                lang = lang.strip()
                if lang:
                    all_langs.add(lang)

    return len(all_langs), ';'.join(sorted(all_langs))


def calculate_programming_variety(row):
    """
    Calculate programming language variety
    """
    prog_cols = ['SDK_prog_lang_list', 'BUG_prog_lang_list', 'GIT_prog_lang_list']

    all_langs = set()
    for col in prog_cols:
        if col in row.index and pd.notna(row[col]) and str(row[col]).strip():
            langs = str(row[col]).replace(',', ';').split(';')
            for lang in langs:
                lang = lang.strip()
                if lang:
                    all_langs.add(lang)

    return len(all_langs), ';'.join(sorted(all_langs))


# ============================================================================
# ECOSYSTEM DEVELOPMENT CALCULATION
# ============================================================================

def calculate_ecosystem_development(platform_df, country_lang_lookup):
    """
    Calculate ecosystem development score for a platform
    E = (countries with resources in their language) / (total host countries)

    For multilingual countries: ALL official languages must be available
    For high-English-proficiency countries: English also counts
    """
    # Get unique languages available for this platform
    lang_cols = [col for col in platform_df.columns if col.endswith('_lang_list')]

    all_langs = set()
    for col in lang_cols:
        for val in platform_df[col].dropna():
            if str(val).strip():
                langs = str(val).replace(',', ';').split(';')
                for lang in langs:
                    lang = lang.strip()
                    if lang:
                        all_langs.add(lang.lower())

    # Get host countries for this platform
    host_countries = platform_df['host_country_iso3c'].dropna().unique()

    countries_covered = 0

    for country_iso in host_countries:
        if country_iso in country_lang_lookup.index:
            country_info = country_lang_lookup.loc[country_iso]

            # Get official languages for this country
            official_langs = str(country_info['official_languages']).split(';')
            official_langs = [lang.strip().lower() for lang in official_langs]

            # Check if ALL official languages are covered
            all_covered = all(lang in all_langs for lang in official_langs)

            # Or check if English counts and English is available
            english_counts = country_info['english_counts_as_covered'] == 1
            english_available = 'english' in all_langs

            if all_covered or (english_counts and english_available):
                countries_covered += 1

    total_countries = len(host_countries)

    if total_countries == 0:
        return 0.0

    return countries_covered / total_countries


# ============================================================================
# MAIN MERGE FUNCTION
# ============================================================================

def merge_coder_outputs(codebook_path, country_lang_path, claude_path, chatgpt_path,
                        human_path=None, output_path='CODE_BOOK_final.csv'):
    """
    Main function to merge all coder outputs and produce final CODE_BOOK
    """
    print("=" * 60)
    print("MULTI-CODER RESOLUTION AND MERGE")
    print("=" * 60)

    # Load files
    print("\n1. Loading files...")
    codebook = pd.read_csv(codebook_path, low_memory=False)
    country_lang = pd.read_csv(country_lang_path)
    country_lang = country_lang.set_index('host_country_iso3c')

    claude_df = pd.read_csv(claude_path)
    chatgpt_df = pd.read_csv(chatgpt_path)
    human_df = pd.read_csv(human_path) if human_path else None

    print(f"   CODE_BOOK: {len(codebook)} dyads")
    print(f"   Claude coding: {len(claude_df)} platforms")
    print(f"   ChatGPT coding: {len(chatgpt_df)} platforms")
    if human_df is not None:
        print(f"   Human coding: {len(human_df)} platforms")

    # Get unique platforms
    platforms = codebook['platform_name'].unique()
    print(f"\n2. Processing {len(platforms)} platforms...")

    # Create resolution log
    resolution_log = []

    # Process each platform
    resolved_coding = []

    for platform in platforms:
        claude_row = claude_df[claude_df['platform_name'] == platform]
        chatgpt_row = chatgpt_df[chatgpt_df['platform_name'] == platform]
        human_row = human_df[human_df['platform_name'] == platform] if human_df is not None else None

        resolved_row = {'platform_name': platform}

        # Get values for each variable type
        for var in BINARY_VARS:
            c_val = claude_row[var].iloc[0] if len(claude_row) > 0 and var in claude_row.columns else np.nan
            g_val = chatgpt_row[var].iloc[0] if len(chatgpt_row) > 0 and var in chatgpt_row.columns else np.nan
            h_val = human_row[var].iloc[0] if human_row is not None and len(human_row) > 0 and var in human_row.columns else np.nan

            resolved_val, source = resolve_binary(c_val, g_val, h_val)
            resolved_row[var] = resolved_val
            resolved_row[f'{var}_source'] = source

            if source == 'ADJ':
                resolution_log.append({
                    'platform': platform, 'variable': var, 'type': 'binary',
                    'claude': c_val, 'chatgpt': g_val, 'human': h_val,
                    'resolved': resolved_val, 'status': 'NEEDS_ADJUDICATION'
                })

        for var in COUNT_VARS:
            c_val = claude_row[var].iloc[0] if len(claude_row) > 0 and var in claude_row.columns else np.nan
            g_val = chatgpt_row[var].iloc[0] if len(chatgpt_row) > 0 and var in chatgpt_row.columns else np.nan
            h_val = human_row[var].iloc[0] if human_row is not None and len(human_row) > 0 and var in human_row.columns else np.nan

            resolved_val, source = resolve_count(c_val, g_val, h_val)
            resolved_row[var] = resolved_val
            resolved_row[f'{var}_source'] = source

            if source == 'ADJ':
                resolution_log.append({
                    'platform': platform, 'variable': var, 'type': 'count',
                    'claude': c_val, 'chatgpt': g_val, 'human': h_val,
                    'resolved': resolved_val, 'status': 'NEEDS_ADJUDICATION'
                })

        for var in LIST_VARS:
            c_val = claude_row[var].iloc[0] if len(claude_row) > 0 and var in claude_row.columns else np.nan
            g_val = chatgpt_row[var].iloc[0] if len(chatgpt_row) > 0 and var in chatgpt_row.columns else np.nan
            h_val = human_row[var].iloc[0] if human_row is not None and len(human_row) > 0 and var in human_row.columns else np.nan

            resolved_val, source = resolve_list(c_val, g_val, h_val)
            resolved_row[var] = resolved_val
            resolved_row[f'{var}_source'] = source

        for var in TEXT_VARS:
            c_val = claude_row[var].iloc[0] if len(claude_row) > 0 and var in claude_row.columns else np.nan
            g_val = chatgpt_row[var].iloc[0] if len(chatgpt_row) > 0 and var in chatgpt_row.columns else np.nan
            h_val = human_row[var].iloc[0] if human_row is not None and len(human_row) > 0 and var in human_row.columns else np.nan

            resolved_val, source = resolve_text(c_val, g_val, h_val)
            resolved_row[var] = resolved_val
            resolved_row[f'{var}_source'] = source

        # Add coder metadata
        coder_names = []
        if len(claude_row) > 0: coder_names.append('Claude')
        if len(chatgpt_row) > 0: coder_names.append('ChatGPT')
        if human_row is not None and len(human_row) > 0: coder_names.append('Human')
        resolved_row['Coder'] = ';'.join(coder_names)
        resolved_row['analysis_date'] = datetime.now().strftime('%Y-%m-%d')

        resolved_coding.append(resolved_row)

    resolved_df = pd.DataFrame(resolved_coding)

    # Calculate linguistic variety
    print("\n3. Calculating linguistic variety...")
    resolved_df['LINGUISTIC_VARIETY'], resolved_df['linguistic_variety_list'] = zip(
        *resolved_df.apply(calculate_linguistic_variety, axis=1)
    )
    resolved_df['programming_lang_variety'], resolved_df['programming_lang_variety_list'] = zip(
        *resolved_df.apply(calculate_programming_variety, axis=1)
    )

    # Merge onto CODE_BOOK
    print("\n4. Merging onto CODE_BOOK dyads...")

    # Get columns from resolved coding (exclude _source columns for main merge)
    main_cols = [col for col in resolved_df.columns if not col.endswith('_source')]
    source_cols = [col for col in resolved_df.columns if col.endswith('_source')]

    # Merge platform-level variables
    final_df = codebook.merge(
        resolved_df[main_cols],
        on='platform_name',
        how='left',
        suffixes=('_old', '')
    )

    # Calculate ecosystem development for each platform
    print("\n5. Calculating ecosystem development scores...")
    eco_dev_scores = {}

    for platform in platforms:
        platform_dyads = final_df[final_df['platform_name'] == platform]
        eco_dev = calculate_ecosystem_development(platform_dyads, country_lang)
        eco_dev_scores[platform] = eco_dev

    final_df['ecosystem_development'] = final_df['platform_name'].map(eco_dev_scores)

    # Save outputs
    print("\n6. Saving outputs...")
    final_df.to_csv(output_path, index=False)
    print(f"   Final CODE_BOOK: {output_path}")

    if resolution_log:
        resolution_log_df = pd.DataFrame(resolution_log)
        resolution_log_df.to_csv(RESOLUTION_LOG_PATH, index=False)
        print(f"   Resolution log: {RESOLUTION_LOG_PATH}")
        print(f"   ⚠️  {len(resolution_log)} items need human adjudication")

    # Summary statistics
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total dyads: {len(final_df)}")
    print(f"Total platforms: {len(platforms)}")
    print(f"Mean linguistic variety: {resolved_df['LINGUISTIC_VARIETY'].mean():.2f}")
    print(f"Mean ecosystem development: {final_df['ecosystem_development'].mean():.3f}")

    return final_df, resolved_df


# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == '__main__':
    # Example usage
    print("""
    To run this script:

    1. Ensure coder output files are in the same directory:
       - claude_platform_coding.csv
       - chatgpt_platform_coding.csv
       - human_platform_coding.csv (optional, for IRR subset)

    2. Run:
       python merge_coder_outputs.py

    3. Check outputs:
       - CODE_BOOK_final.csv (merged dyads with all coding)
       - coder_resolution_log.csv (items needing adjudication)
    """)

    # Uncomment to run:
    # final_df, resolved_df = merge_coder_outputs(
    #     CODEBOOK_PATH, COUNTRY_LANG_LOOKUP_PATH,
    #     CLAUDE_CODING_PATH, CHATGPT_CODING_PATH, HUMAN_CODING_PATH
    # )
