#!/usr/bin/env python3
"""
Inter-Rater Reliability (IRR) Calculator
=========================================
Compares Claude vs ChatGPT vs Human coding results and calculates IRR metrics:
- Percent Agreement (pairwise and overall)
- Cohen's Kappa (for binary/ordinal variables)
- ICC (Intraclass Correlation) for count variables
- Fleiss' Kappa (for 3-way comparison)
- Disagreement report with flagged variables

Usage (2-way):
    python3 irr_calculator.py claude_results/ chatgpt_results/ --output irr_analysis/

Usage (3-way with human):
    python3 irr_calculator.py claude_results/ chatgpt_results/ --human human_results/ --output irr_analysis/

Input: Coding result directories from claude_coder.py, chatgpt_coder.py, and/or human coders
Output: IRR statistics, disagreement report, and summary JSON
"""

import os
import sys
import json
import argparse
from datetime import datetime
from pathlib import Path
from collections import defaultdict

try:
    import pandas as pd
    import numpy as np
except ImportError:
    print("ERROR: pandas/numpy not installed. Run: pip3 install pandas numpy")
    sys.exit(1)

try:
    from sklearn.metrics import cohen_kappa_score
except ImportError:
    print("WARNING: sklearn not installed. Cohen's Kappa will not be calculated.")
    print("Run: pip3 install scikit-learn")
    cohen_kappa_score = None


# ============================================================================
# CONFIGURATION
# ============================================================================

# Variables by type (for appropriate IRR calculation)
# Note: DOCS, SDK, GIT are coded as Binary 0/1 (presence/absence)
BINARY_VARIABLES = [
    'DEVP', 'DOCS', 'SDK', 'BUG', 'STAN',
    'AI_MODEL', 'AI_AGENT', 'AI_ASSIST', 'AI_DATA', 'AI_MKT',
    'GIT', 'MON',
    'API',  # Changed from count to binary (0/1) in codebook v2.1
    'ROLE', 'DATA', 'STORE', 'CERT',
    # 'OPEN',  # DROPPED from IRR — poor reliability (0.179 Gwet AC1), theoretically captured by PLAT
    'COM_social_media', 'COM_forum', 'COM_blog', 'COM_help_support',
    'COM_live_chat', 'COM_Slack', 'COM_Discord', 'COM_stackoverflow',
    'COM_training', 'COM_FAQ',
    'EVENT_webinars', 'EVENT_virtual', 'EVENT_in_person',
    'EVENT_conference', 'EVENT_hackathon',
    'SPAN_internal', 'SPAN_communities', 'SPAN_external'
]

COUNT_VARIABLES = [
    'METH',
    # Natural language count variables (independently coded)
    'SDK_lang', 'COM_lang', 'GIT_lang', 'SPAN_lang',
    'ROLE_lang', 'DATA_lang', 'STORE_lang', 'CERT_lang',
    # 'OPEN_lang',  # DROPPED with OPEN
    # Programming language count variables (independently coded)
    'SDK_prog_lang',
]
# NOTE: Removed from IRR:
#   - END (dropped from codebook)
#   - EVENT (sum of EVENT sub-components which ARE in BINARY_VARIABLES)
#   - SPAN (sum of SPAN sub-components which ARE in BINARY_VARIABLES)
#   - LINGUISTIC_VARIETY (computed in R analysis, not coded)
#   - programming_lang_variety (computed in R analysis, not coded)
#   - GIT_prog_lang (deterministic from GitHub augmentation script, not independently coded)

ORDINAL_VARIABLES = []  # OPEN moved to BINARY (now coded 0/1)

# All primary variables for IRR
PRIMARY_VARIABLES = BINARY_VARIABLES + COUNT_VARIABLES + ORDINAL_VARIABLES


# ============================================================================
# IRR CALCULATOR CLASS
# ============================================================================

class IRRCalculator:
    """Calculates inter-rater reliability between coders."""

    def __init__(self, output_dir: str, verbose: bool = True):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose

    def log(self, msg: str):
        if self.verbose:
            print(msg)

    def load_results(self, results_dir: str) -> dict:
        """Load coding results from a directory."""
        results_path = Path(results_dir)
        results = {}

        # Always prefer individual JSON files (CSV summaries may be incomplete
        # if coding was done in batches or re-runs overwrote the summary)
        # Only fall back to CSV if no JSON files are found
        for json_file in results_path.glob("*.json"):
            if 'summary' in json_file.name:
                continue
            try:
                data = json.loads(json_file.read_text())
                platform_id = data.get('platform_id') or data.get('platform_ID')
                if platform_id:
                    # Flatten nested structure
                    flat = {'platform_id': platform_id, 'platform_name': data.get('platform_name', '')}

                    # Handle Claude/ChatGPT nested category structure
                    for category in ['application', 'development', 'ai', 'social', 'governance', 'moderators']:
                        if category in data:
                            flat.update(data[category])

                    # Handle Human flat "variables" structure
                    if 'variables' in data:
                        flat.update(data['variables'])

                    results[platform_id] = flat
            except Exception as e:
                self.log(f"  Warning: Could not load {json_file}: {e}")

        # Fall back to CSV only if no JSON files were found
        if not results:
            csv_files = list(results_path.glob("*_coding_results.csv"))
            if csv_files:
                df = pd.read_csv(csv_files[0])
                for _, row in df.iterrows():
                    platform_id = row.get('platform_ID') or row.get('platform_id')
                    if platform_id:
                        results[platform_id] = row.to_dict()

        return results

    def _normalize_value(self, v, var):
        """Convert a value to a comparable numeric type."""
        try:
            if v is None:
                return None
            if isinstance(v, str) and v.strip() == '':
                return None
            if isinstance(v, float) and pd.isna(v):
                return None
            return int(float(v))
        except (ValueError, TypeError):
            return None

    def calculate_agreement(self, values1: list, values2: list) -> float:
        """Calculate percent agreement between two lists (ignoring None pairs)."""
        valid_pairs = [(v1, v2) for v1, v2 in zip(values1, values2)
                       if v1 is not None and v2 is not None]
        if len(valid_pairs) == 0:
            return None
        matches = sum(1 for v1, v2 in valid_pairs if v1 == v2)
        return matches / len(valid_pairs)

    def calculate_kappa(self, values1: list, values2: list) -> float:
        """Calculate Cohen's Kappa for binary/ordinal variables."""
        if cohen_kappa_score is None:
            return None
        try:
            valid_pairs = [(v1, v2) for v1, v2 in zip(values1, values2)
                           if v1 is not None and v2 is not None]
            if len(valid_pairs) < 2:
                return None
            v1, v2 = zip(*valid_pairs)
            return cohen_kappa_score(v1, v2)
        except Exception:
            return None

    def calculate_icc(self, values1: list, values2: list) -> float:
        """Calculate ICC(2,1) for count variables (two raters)."""
        try:
            valid_pairs = [(v1, v2) for v1, v2 in zip(values1, values2)
                           if v1 is not None and v2 is not None and
                           not (pd.isna(v1) or pd.isna(v2))]
            if len(valid_pairs) < 3:
                return None

            v1, v2 = zip(*valid_pairs)
            v1, v2 = np.array(v1, dtype=float), np.array(v2, dtype=float)

            n = len(v1)
            mean_v1 = np.mean(v1)
            mean_v2 = np.mean(v2)
            grand_mean = (mean_v1 + mean_v2) / 2

            row_means = (v1 + v2) / 2
            MS_rows = 2 * np.sum((row_means - grand_mean) ** 2) / (n - 1)
            MS_error = np.sum((v1 - row_means) ** 2 + (v2 - row_means) ** 2) / n
            MS_cols = n * ((mean_v1 - grand_mean) ** 2 + (mean_v2 - grand_mean) ** 2)

            if (MS_rows + MS_error) == 0:
                return None
            icc = (MS_rows - MS_error) / (MS_rows + MS_error + 2 * (MS_cols - MS_error) / n)
            return max(-1, min(1, icc))
        except Exception:
            return None

    def calculate_icc_multi(self, *value_lists) -> float:
        """Calculate ICC(2,1) for count variables with 3+ raters."""
        try:
            k = len(value_lists)  # number of raters
            n = len(value_lists[0])  # number of subjects

            # Build matrix: rows = subjects, cols = raters
            # Only include rows where ALL raters have valid values
            valid_rows = []
            for i in range(n):
                vals = [vl[i] for vl in value_lists]
                if all(v is not None and not pd.isna(v) for v in vals):
                    valid_rows.append([float(v) for v in vals])

            if len(valid_rows) < 3:
                return None

            data = np.array(valid_rows)
            n = data.shape[0]
            k = data.shape[1]

            grand_mean = np.mean(data)
            row_means = np.mean(data, axis=1)
            col_means = np.mean(data, axis=0)

            SS_total = np.sum((data - grand_mean) ** 2)
            SS_rows = k * np.sum((row_means - grand_mean) ** 2)
            SS_cols = n * np.sum((col_means - grand_mean) ** 2)
            SS_error = SS_total - SS_rows - SS_cols

            MS_rows = SS_rows / (n - 1)
            MS_cols = SS_cols / (k - 1) if k > 1 else 0
            MS_error = SS_error / ((n - 1) * (k - 1)) if (n - 1) * (k - 1) > 0 else 0

            # ICC(2,1)
            denom = MS_rows + (k - 1) * MS_error + k * (MS_cols - MS_error) / n
            if denom == 0:
                return None
            icc = (MS_rows - MS_error) / denom
            return max(-1, min(1, icc))
        except Exception:
            return None

    def calculate_gwet_ac1(self, values1: list, values2: list) -> float:
        """
        Calculate Gwet's AC1 for two raters.
        AC1 is resistant to the prevalence/kappa paradox that affects Cohen's Kappa
        when category distributions are heavily skewed.
        """
        try:
            valid_pairs = [(v1, v2) for v1, v2 in zip(values1, values2)
                           if v1 is not None and v2 is not None]
            if len(valid_pairs) < 2:
                return None
            v1, v2 = zip(*valid_pairs)
            n = len(v1)

            # Observed agreement
            matches = sum(1 for a, b in zip(v1, v2) if a == b)
            pa = matches / n  # proportion agreement

            # Find all categories
            all_vals = list(v1) + list(v2)
            categories = sorted(set(all_vals))
            q = len(categories)

            if q < 2:
                return None  # Only one category observed

            # Marginal proportions for each category (pooled across both raters)
            pi_k = {}
            for cat in categories:
                count = sum(1 for v in all_vals if v == cat)
                pi_k[cat] = count / (2 * n)

            # Expected agreement by chance under AC1
            pe = (1.0 / (q - 1)) * sum(pk * (1 - pk) for pk in pi_k.values())

            if pe == 1.0:
                return None

            ac1 = (pa - pe) / (1 - pe)
            return ac1
        except Exception:
            return None

    def calculate_gwet_ac1_multi(self, ratings_matrix: list) -> float:
        """
        Calculate Gwet's AC1 for 3+ raters (multi-rater version).
        ratings_matrix: list of lists, each inner list = ratings from all raters for one subject.
        """
        try:
            valid_rows = [row for row in ratings_matrix if all(v is not None for v in row)]
            if len(valid_rows) < 2:
                return None

            n = len(valid_rows)  # subjects
            k = len(valid_rows[0])  # raters

            # Find all categories
            all_vals = set()
            for row in valid_rows:
                all_vals.update(row)
            categories = sorted(all_vals)
            q = len(categories)

            if q < 2:
                return None

            # Build category count matrix
            cat_idx = {c: i for i, c in enumerate(categories)}
            counts = np.zeros((n, q))
            for i, row in enumerate(valid_rows):
                for val in row:
                    counts[i, cat_idx[val]] += 1

            # Observed agreement (Fleiss-style)
            P_i = (np.sum(counts ** 2, axis=1) - k) / (k * (k - 1))
            P_bar = np.mean(P_i)

            # Marginal proportions (pooled)
            pi_k = np.sum(counts, axis=0) / (n * k)

            # Expected agreement under AC1
            pe = (1.0 / (q - 1)) * np.sum(pi_k * (1 - pi_k))

            if pe == 1.0:
                return None

            ac1 = (P_bar - pe) / (1 - pe)
            return ac1
        except Exception:
            return None

    def calculate_krippendorff_alpha(self, *value_lists, level='nominal') -> float:
        """
        Calculate Krippendorff's Alpha for 2+ raters.
        Handles missing data naturally.
        level: 'nominal' for binary/categorical, 'ordinal' for ordinal, 'ratio' for counts.
        """
        try:
            n_subjects = len(value_lists[0])
            n_raters = len(value_lists)

            # Build reliability data matrix (subjects x raters), with None for missing
            data = []
            for i in range(n_subjects):
                row = [vl[i] for vl in value_lists]
                data.append(row)

            # Filter to subjects with at least 2 non-None values
            valid_data = []
            for row in data:
                non_none = [v for v in row if v is not None]
                if len(non_none) >= 2:
                    valid_data.append(row)

            if len(valid_data) < 2:
                return None

            # Collect all observed values
            all_values = []
            for row in valid_data:
                for v in row:
                    if v is not None:
                        all_values.append(v)

            if len(set(all_values)) < 2:
                return None  # Only one value observed

            n = len(valid_data)

            # Difference function based on level
            if level == 'nominal':
                def delta(a, b):
                    return 0.0 if a == b else 1.0
            elif level == 'ordinal':
                sorted_vals = sorted(set(all_values))
                val_to_rank = {v: i for i, v in enumerate(sorted_vals)}
                def delta(a, b):
                    return (val_to_rank[a] - val_to_rank[b]) ** 2
            else:  # ratio/interval
                def delta(a, b):
                    return (a - b) ** 2

            # Observed disagreement (Do)
            Do = 0.0
            total_pairs = 0
            for row in valid_data:
                non_none = [(i, v) for i, v in enumerate(row) if v is not None]
                m_u = len(non_none)
                if m_u < 2:
                    continue
                for i in range(len(non_none)):
                    for j in range(i + 1, len(non_none)):
                        Do += delta(non_none[i][1], non_none[j][1])
                        total_pairs += 1

            if total_pairs == 0:
                return None

            Do = Do / total_pairs

            # Expected disagreement (De)
            De = 0.0
            total_expected_pairs = 0
            values_flat = all_values  # all non-None values
            n_total = len(values_flat)
            for i in range(n_total):
                for j in range(i + 1, n_total):
                    De += delta(values_flat[i], values_flat[j])
                    total_expected_pairs += 1

            if total_expected_pairs == 0:
                return None

            De = De / total_expected_pairs

            if De == 0:
                return None

            alpha = 1.0 - (Do / De)
            return alpha
        except Exception:
            return None

    def calculate_fleiss_kappa(self, ratings_matrix: list) -> float:
        """
        Calculate Fleiss' Kappa for 3+ raters.
        ratings_matrix: list of lists, each inner list = ratings from all raters for one subject.
        """
        try:
            # Filter rows where all raters provided values
            valid_rows = [row for row in ratings_matrix if all(v is not None for v in row)]
            if len(valid_rows) < 2:
                return None

            n = len(valid_rows)  # subjects
            k = len(valid_rows[0])  # raters

            # Find all unique categories
            all_vals = set()
            for row in valid_rows:
                all_vals.update(row)
            categories = sorted(all_vals)
            q = len(categories)  # number of categories

            if q < 2:
                return None  # Perfect agreement, kappa undefined

            # Build category count matrix
            cat_idx = {c: i for i, c in enumerate(categories)}
            counts = np.zeros((n, q))
            for i, row in enumerate(valid_rows):
                for val in row:
                    counts[i, cat_idx[val]] += 1

            # Fleiss' Kappa calculation
            p_j = np.sum(counts, axis=0) / (n * k)  # proportion of each category
            P_i = (np.sum(counts ** 2, axis=1) - k) / (k * (k - 1))  # agreement per subject
            P_bar = np.mean(P_i)  # mean observed agreement
            P_e = np.sum(p_j ** 2)  # expected agreement by chance

            if P_e == 1.0:
                return None  # Undefined
            kappa = (P_bar - P_e) / (1 - P_e)
            return kappa
        except Exception:
            return None

    def compare_coders(self, coder1_results: dict, coder2_results: dict,
                       coder1_name: str = "Claude", coder2_name: str = "ChatGPT") -> dict:
        """Compare two coders and calculate IRR statistics."""

        common_ids = sorted(set(coder1_results.keys()) & set(coder2_results.keys()))
        self.log(f"  Common platforms: {len(common_ids)}")

        variable_data = defaultdict(lambda: {'coder1': [], 'coder2': [], 'disagreements': []})

        for platform_id in common_ids:
            r1 = coder1_results[platform_id]
            r2 = coder2_results[platform_id]

            for var in PRIMARY_VARIABLES:
                v1 = self._normalize_value(r1.get(var), var)
                v2 = self._normalize_value(r2.get(var), var)

                variable_data[var]['coder1'].append(v1)
                variable_data[var]['coder2'].append(v2)

                if v1 != v2 and v1 is not None and v2 is not None:
                    variable_data[var]['disagreements'].append({
                        'platform_id': platform_id,
                        'platform_name': r1.get('platform_name', platform_id),
                        coder1_name: v1,
                        coder2_name: v2
                    })

        irr_results = []
        for var in PRIMARY_VARIABLES:
            data = variable_data[var]
            v1, v2 = data['coder1'], data['coder2']

            valid_pairs = [(a, b) for a, b in zip(v1, v2) if a is not None and b is not None]
            n_valid = len(valid_pairs)

            result = {
                'variable': var,
                'type': 'binary' if var in BINARY_VARIABLES else ('count' if var in COUNT_VARIABLES else 'ordinal'),
                'n': n_valid,
                'agreement': self.calculate_agreement(v1, v2),
                'kappa': None,
                'icc': None,
                'n_disagreements': len(data['disagreements']),
                'disagreements': data['disagreements']
            }

            if var in BINARY_VARIABLES or var in ORDINAL_VARIABLES:
                result['kappa'] = self.calculate_kappa(v1, v2)
                result['gwet_ac1'] = self.calculate_gwet_ac1(v1, v2)
                # Krippendorff's Alpha
                kr_level = 'ordinal' if var in ORDINAL_VARIABLES else 'nominal'
                result['kripp_alpha'] = self.calculate_krippendorff_alpha(v1, v2, level=kr_level)
            if var in COUNT_VARIABLES:
                result['icc'] = self.calculate_icc(v1, v2)
                result['kripp_alpha'] = self.calculate_krippendorff_alpha(v1, v2, level='ratio')

            irr_results.append(result)

        # Overall statistics
        agreements = [r['agreement'] for r in irr_results if r['agreement'] is not None]
        kappas = [r['kappa'] for r in irr_results if r['kappa'] is not None and not np.isnan(r['kappa'])]
        iccs = [r['icc'] for r in irr_results if r['icc'] is not None and not np.isnan(r['icc'])]
        ac1s = [r.get('gwet_ac1') for r in irr_results if r.get('gwet_ac1') is not None and not np.isnan(r.get('gwet_ac1', float('nan')))]
        kripp_alphas = [r.get('kripp_alpha') for r in irr_results if r.get('kripp_alpha') is not None and not np.isnan(r.get('kripp_alpha', float('nan')))]
        n_kappa_nan = sum(1 for r in irr_results
                          if r['kappa'] is not None and np.isnan(r['kappa']))

        summary = {
            'comparison_date': datetime.now().isoformat(),
            'coder1': coder1_name,
            'coder2': coder2_name,
            'n_platforms': len(common_ids),
            'platform_ids': common_ids,
            'n_variables': len(PRIMARY_VARIABLES),
            'overall_agreement': float(np.mean(agreements)) if agreements else None,
            'mean_kappa': float(np.mean(kappas)) if kappas else None,
            'n_kappa_valid': len(kappas),
            'n_kappa_perfect_agreement': n_kappa_nan,
            'mean_gwet_ac1': float(np.mean(ac1s)) if ac1s else None,
            'n_ac1_valid': len(ac1s),
            'mean_kripp_alpha': float(np.mean(kripp_alphas)) if kripp_alphas else None,
            'n_kripp_valid': len(kripp_alphas),
            'mean_icc': float(np.mean(iccs)) if iccs else None,
            'variables': irr_results
        }

        return summary

    def compare_three_way(self, claude_results: dict, chatgpt_results: dict,
                          human_results: dict) -> dict:
        """
        Run three-way comparison: Claude vs ChatGPT vs Human.
        Returns pairwise comparisons + overall three-way statistics.
        """
        self.log(f"\n{'='*60}")
        self.log("THREE-WAY IRR ANALYSIS (Claude vs ChatGPT vs Human)")
        self.log(f"{'='*60}")

        # Find platforms common to ALL three coders
        common_all = sorted(
            set(claude_results.keys()) & set(chatgpt_results.keys()) & set(human_results.keys())
        )
        self.log(f"\nPlatforms coded by all 3 coders: {len(common_all)}")
        self.log(f"  IDs: {', '.join(common_all)}")

        # ---- Pairwise comparisons ----
        self.log(f"\n--- Pairwise: Claude vs ChatGPT ---")
        pair_claude_chatgpt = self.compare_coders(claude_results, chatgpt_results, "Claude", "ChatGPT")

        self.log(f"\n--- Pairwise: Claude vs Human ---")
        pair_claude_human = self.compare_coders(claude_results, human_results, "Claude", "Human")

        self.log(f"\n--- Pairwise: ChatGPT vs Human ---")
        pair_chatgpt_human = self.compare_coders(chatgpt_results, human_results, "ChatGPT", "Human")

        # ---- Three-way statistics (on common_all platforms only) ----
        three_way_vars = []
        for var in PRIMARY_VARIABLES:
            claude_vals = []
            chatgpt_vals = []
            human_vals = []
            disagreements_3way = []

            for pid in common_all:
                vc = self._normalize_value(claude_results[pid].get(var), var)
                vg = self._normalize_value(chatgpt_results[pid].get(var), var)
                vh = self._normalize_value(human_results[pid].get(var), var)

                claude_vals.append(vc)
                chatgpt_vals.append(vg)
                human_vals.append(vh)

                # Track three-way disagreements
                if vc is not None and vg is not None and vh is not None:
                    if not (vc == vg == vh):
                        disagreements_3way.append({
                            'platform_id': pid,
                            'platform_name': claude_results[pid].get('platform_name', pid),
                            'Claude': vc,
                            'ChatGPT': vg,
                            'Human': vh
                        })

            # Three-way agreement: all three agree
            valid_triples = [(c, g, h) for c, g, h in zip(claude_vals, chatgpt_vals, human_vals)
                             if c is not None and g is not None and h is not None]
            n_valid = len(valid_triples)
            if n_valid > 0:
                n_agree = sum(1 for c, g, h in valid_triples if c == g == h)
                three_way_agree = n_agree / n_valid
            else:
                three_way_agree = None

            # Fleiss' Kappa, Gwet's AC1, Krippendorff's Alpha for binary/ordinal
            fleiss_k = None
            gwet_ac1_3 = None
            kripp_alpha_3 = None
            icc_3 = None
            if var in BINARY_VARIABLES or var in ORDINAL_VARIABLES:
                ratings = []
                for c, g, h in zip(claude_vals, chatgpt_vals, human_vals):
                    if c is not None and g is not None and h is not None:
                        ratings.append([c, g, h])
                fleiss_k = self.calculate_fleiss_kappa(ratings)
                gwet_ac1_3 = self.calculate_gwet_ac1_multi(ratings)
                kr_level = 'ordinal' if var in ORDINAL_VARIABLES else 'nominal'
                kripp_alpha_3 = self.calculate_krippendorff_alpha(
                    claude_vals, chatgpt_vals, human_vals, level=kr_level)

            # ICC + Krippendorff's Alpha for count variables with 3 raters
            if var in COUNT_VARIABLES:
                icc_3 = self.calculate_icc_multi(claude_vals, chatgpt_vals, human_vals)
                kripp_alpha_3 = self.calculate_krippendorff_alpha(
                    claude_vals, chatgpt_vals, human_vals, level='ratio')

            three_way_vars.append({
                'variable': var,
                'type': 'binary' if var in BINARY_VARIABLES else ('count' if var in COUNT_VARIABLES else 'ordinal'),
                'n': n_valid,
                'three_way_agreement': three_way_agree,
                'fleiss_kappa': fleiss_k,
                'gwet_ac1': gwet_ac1_3,
                'kripp_alpha': kripp_alpha_3,
                'icc_3way': icc_3,
                'n_disagreements': len(disagreements_3way),
                'disagreements': disagreements_3way
            })

        # Overall three-way stats
        tw_agreements = [v['three_way_agreement'] for v in three_way_vars if v['three_way_agreement'] is not None]
        tw_fleiss = [v['fleiss_kappa'] for v in three_way_vars
                     if v['fleiss_kappa'] is not None and not np.isnan(v['fleiss_kappa'])]
        tw_ac1s = [v['gwet_ac1'] for v in three_way_vars
                   if v.get('gwet_ac1') is not None and not np.isnan(v.get('gwet_ac1', float('nan')))]
        tw_kripp = [v['kripp_alpha'] for v in three_way_vars
                    if v.get('kripp_alpha') is not None and not np.isnan(v.get('kripp_alpha', float('nan')))]
        tw_iccs = [v['icc_3way'] for v in three_way_vars
                   if v['icc_3way'] is not None and not np.isnan(v['icc_3way'])]

        three_way_summary = {
            'n_platforms': len(common_all),
            'platform_ids': common_all,
            'n_variables': len(PRIMARY_VARIABLES),
            'overall_three_way_agreement': float(np.mean(tw_agreements)) if tw_agreements else None,
            'mean_fleiss_kappa': float(np.mean(tw_fleiss)) if tw_fleiss else None,
            'n_fleiss_valid': len(tw_fleiss),
            'mean_gwet_ac1': float(np.mean(tw_ac1s)) if tw_ac1s else None,
            'n_ac1_valid': len(tw_ac1s),
            'mean_kripp_alpha': float(np.mean(tw_kripp)) if tw_kripp else None,
            'n_kripp_valid': len(tw_kripp),
            'mean_icc_3way': float(np.mean(tw_iccs)) if tw_iccs else None,
            'variables': three_way_vars
        }

        return {
            'analysis_type': 'three_way',
            'analysis_date': datetime.now().isoformat(),
            'coders': ['Claude', 'ChatGPT', 'Human'],
            'pairwise': {
                'claude_vs_chatgpt': pair_claude_chatgpt,
                'claude_vs_human': pair_claude_human,
                'chatgpt_vs_human': pair_chatgpt_human
            },
            'three_way': three_way_summary
        }

    def _kappa_interpretation(self, kappa):
        """Return Landis & Koch interpretation of kappa value."""
        if kappa is None:
            return "N/A"
        if kappa >= 0.81:
            return "Almost Perfect"
        elif kappa >= 0.61:
            return "Substantial"
        elif kappa >= 0.41:
            return "Moderate"
        elif kappa >= 0.21:
            return "Fair"
        elif kappa >= 0.0:
            return "Slight"
        else:
            return "Poor"

    def generate_pairwise_report_section(self, pair_summary: dict) -> list:
        """Generate report lines for a single pairwise comparison."""
        lines = []
        c1 = pair_summary['coder1']
        c2 = pair_summary['coder2']

        lines.append(f"\n{'='*70}")
        lines.append(f"PAIRWISE: {c1} vs {c2}")
        lines.append(f"{'='*70}")
        lines.append(f"Platforms compared: {pair_summary['n_platforms']}")
        lines.append(f"Variables: {pair_summary['n_variables']}")
        lines.append("")

        # Overall
        if pair_summary['overall_agreement'] is not None:
            lines.append(f"Overall Agreement: {pair_summary['overall_agreement']:.1%}")
        else:
            lines.append("Overall Agreement: N/A")

        if pair_summary.get('mean_gwet_ac1') is not None:
            lines.append(f"Mean Gwet's AC1: {pair_summary['mean_gwet_ac1']:.3f} "
                          f"({pair_summary.get('n_ac1_valid', '?')} variables) [PRIMARY - prevalence-resistant]")
            lines.append(f"  Interpretation: {self._kappa_interpretation(pair_summary['mean_gwet_ac1'])}")

        if pair_summary.get('mean_kripp_alpha') is not None:
            lines.append(f"Mean Krippendorff's Alpha: {pair_summary['mean_kripp_alpha']:.3f} "
                          f"({pair_summary.get('n_kripp_valid', '?')} variables)")
            lines.append(f"  Interpretation: {self._kappa_interpretation(pair_summary['mean_kripp_alpha'])}")

        if pair_summary['mean_kappa'] is not None:
            lines.append(f"Mean Cohen's Kappa: {pair_summary['mean_kappa']:.3f} "
                          f"({pair_summary.get('n_kappa_valid', '?')} variables with variance)")
            lines.append(f"  Interpretation: {self._kappa_interpretation(pair_summary['mean_kappa'])}")
            if pair_summary.get('n_kappa_perfect_agreement', 0) > 0:
                lines.append(f"  Note: {pair_summary['n_kappa_perfect_agreement']} variables had perfect agreement "
                              "(Kappa undefined, excluded from mean)")
        else:
            lines.append("Mean Cohen's Kappa: N/A")

        if pair_summary['mean_icc'] is not None:
            lines.append(f"Mean ICC(2,1): {pair_summary['mean_icc']:.3f}")
        else:
            lines.append("Mean ICC(2,1): N/A")
        lines.append("")

        # Variable-level table
        lines.append(f"{'Variable':<22} {'Type':<7} {'N':<4} {'Agree%':<7} {'AC1':<7} {'Kr-α':<7} {'Kappa':<7} {'ICC':<7} {'Dis':<4}")
        lines.append("-" * 75)

        for var in pair_summary['variables']:
            agree = f"{var['agreement']:.1%}" if var['agreement'] is not None else "N/A"
            kappa_str = "N/A"
            if var.get('kappa') is not None:
                if np.isnan(var['kappa']):
                    kappa_str = "perf."
                else:
                    kappa_str = f"{var['kappa']:.3f}"
            ac1_str = "N/A"
            if var.get('gwet_ac1') is not None:
                if np.isnan(var['gwet_ac1']):
                    ac1_str = "perf."
                else:
                    ac1_str = f"{var['gwet_ac1']:.3f}"
            kripp_str = "N/A"
            if var.get('kripp_alpha') is not None:
                if np.isnan(var['kripp_alpha']):
                    kripp_str = "perf."
                else:
                    kripp_str = f"{var['kripp_alpha']:.3f}"
            icc_str = f"{var['icc']:.3f}" if var.get('icc') is not None else "N/A"
            lines.append(f"{var['variable']:<22} {var['type']:<7} {var['n']:<4} "
                          f"{agree:<7} {ac1_str:<7} {kripp_str:<7} {kappa_str:<7} {icc_str:<7} {var['n_disagreements']:<4}")

        # Flag low agreement
        lines.append("")
        flagged = [v for v in pair_summary['variables']
                   if v['agreement'] is not None and v['agreement'] < 0.80]
        if flagged:
            lines.append(f"Variables with <80% agreement ({len(flagged)}):")
            for var in flagged:
                lines.append(f"  {var['variable']}: {var['agreement']:.1%} "
                              f"({var['n_disagreements']} disagreements)")
        else:
            lines.append("All variables have >=80% agreement.")

        # Disagreement details
        has_disagreements = any(v['disagreements'] for v in pair_summary['variables'])
        if has_disagreements:
            lines.append("")
            lines.append("Disagreement Details:")
            for var in pair_summary['variables']:
                if var['disagreements']:
                    lines.append(f"\n  {var['variable']} ({var['n_disagreements']} disagreements):")
                    for d in var['disagreements']:
                        lines.append(f"    {d['platform_name']}: {c1}={d[c1]} vs {c2}={d[c2]}")

        return lines

    def generate_three_way_report(self, analysis: dict) -> str:
        """Generate full three-way IRR report."""
        lines = []
        lines.append("=" * 70)
        lines.append("INTER-RATER RELIABILITY REPORT")
        lines.append("Three-Way Comparison: Claude vs ChatGPT vs Human")
        lines.append("=" * 70)
        lines.append(f"Date: {analysis['analysis_date']}")
        lines.append(f"Coders: {', '.join(analysis['coders'])}")
        lines.append("")

        # ---- THREE-WAY SUMMARY ----
        tw = analysis['three_way']
        lines.append("=" * 70)
        lines.append("THREE-WAY AGREEMENT (All 3 coders must agree)")
        lines.append("=" * 70)
        lines.append(f"Platforms coded by all 3: {tw['n_platforms']}")
        lines.append(f"Platform IDs: {', '.join(tw['platform_ids'])}")
        lines.append(f"Variables: {tw['n_variables']}")
        lines.append("")

        if tw['overall_three_way_agreement'] is not None:
            lines.append(f"Overall Three-Way Agreement: {tw['overall_three_way_agreement']:.1%}")
        if tw.get('mean_gwet_ac1') is not None:
            lines.append(f"Mean Gwet's AC1: {tw['mean_gwet_ac1']:.3f} "
                          f"({tw['n_ac1_valid']} variables) [PRIMARY - prevalence-resistant]")
            lines.append(f"  Interpretation: {self._kappa_interpretation(tw['mean_gwet_ac1'])}")
        if tw.get('mean_kripp_alpha') is not None:
            lines.append(f"Mean Krippendorff's Alpha: {tw['mean_kripp_alpha']:.3f} "
                          f"({tw['n_kripp_valid']} variables)")
            lines.append(f"  Interpretation: {self._kappa_interpretation(tw['mean_kripp_alpha'])}")
        if tw['mean_fleiss_kappa'] is not None:
            lines.append(f"Mean Fleiss' Kappa: {tw['mean_fleiss_kappa']:.3f} "
                          f"({tw['n_fleiss_valid']} variables)")
            lines.append(f"  Interpretation: {self._kappa_interpretation(tw['mean_fleiss_kappa'])}")
        if tw['mean_icc_3way'] is not None:
            lines.append(f"Mean ICC(2,1) 3-way: {tw['mean_icc_3way']:.3f}")
        lines.append("")

        # Three-way variable table
        lines.append(f"{'Variable':<22} {'Type':<7} {'N':<4} {'3-Way%':<7} {'AC1':<7} {'Kr-α':<7} {'Fl-κ':<7} {'ICC-3':<7} {'Dis':<4}")
        lines.append("-" * 75)
        for var in tw['variables']:
            agree = f"{var['three_way_agreement']:.1%}" if var['three_way_agreement'] is not None else "N/A"
            fleiss = "N/A"
            if var['fleiss_kappa'] is not None:
                if np.isnan(var['fleiss_kappa']):
                    fleiss = "perf."
                else:
                    fleiss = f"{var['fleiss_kappa']:.3f}"
            ac1 = "N/A"
            if var.get('gwet_ac1') is not None:
                if np.isnan(var['gwet_ac1']):
                    ac1 = "perf."
                else:
                    ac1 = f"{var['gwet_ac1']:.3f}"
            kripp = "N/A"
            if var.get('kripp_alpha') is not None:
                if np.isnan(var['kripp_alpha']):
                    kripp = "perf."
                else:
                    kripp = f"{var['kripp_alpha']:.3f}"
            icc3 = f"{var['icc_3way']:.3f}" if var['icc_3way'] is not None else "N/A"
            lines.append(f"{var['variable']:<22} {var['type']:<7} {var['n']:<4} "
                          f"{agree:<7} {ac1:<7} {kripp:<7} {fleiss:<7} {icc3:<7} {var['n_disagreements']:<4}")

        # Three-way disagreement details
        lines.append("")
        lines.append("Three-Way Disagreement Details:")
        for var in tw['variables']:
            if var['disagreements']:
                lines.append(f"\n  {var['variable']} ({var['n_disagreements']} disagreements):")
                for d in var['disagreements']:
                    lines.append(f"    {d['platform_name']}: Claude={d['Claude']}, "
                                  f"ChatGPT={d['ChatGPT']}, Human={d['Human']}")

        # ---- PAIRWISE COMPARISONS ----
        lines.append("")
        lines.append("")
        lines.append("#" * 70)
        lines.append("PAIRWISE COMPARISON DETAILS")
        lines.append("#" * 70)

        for pair_key, pair_label in [
            ('claude_vs_chatgpt', 'Claude vs ChatGPT'),
            ('claude_vs_human', 'Claude vs Human'),
            ('chatgpt_vs_human', 'ChatGPT vs Human')
        ]:
            pair = analysis['pairwise'][pair_key]
            lines.extend(self.generate_pairwise_report_section(pair))

        # ---- COMPARISON MATRIX ----
        lines.append("")
        lines.append("")
        lines.append("=" * 70)
        lines.append("AGREEMENT COMPARISON MATRIX")
        lines.append("=" * 70)
        lines.append("")

        cc = analysis['pairwise']['claude_vs_chatgpt']
        ch = analysis['pairwise']['claude_vs_human']
        gh = analysis['pairwise']['chatgpt_vs_human']

        # Build comparison table: variable | Claude-ChatGPT | Claude-Human | ChatGPT-Human | 3-Way
        lines.append(f"{'Variable':<25} {'Cl-GPT%':<10} {'Cl-Hum%':<10} {'GPT-Hum%':<10} {'3-Way%':<10}")
        lines.append("-" * 65)

        for i, var in enumerate(PRIMARY_VARIABLES):
            cc_agree = cc['variables'][i]['agreement']
            ch_agree = ch['variables'][i]['agreement']
            gh_agree = gh['variables'][i]['agreement']
            tw_agree = tw['variables'][i]['three_way_agreement']

            cc_str = f"{cc_agree:.1%}" if cc_agree is not None else "N/A"
            ch_str = f"{ch_agree:.1%}" if ch_agree is not None else "N/A"
            gh_str = f"{gh_agree:.1%}" if gh_agree is not None else "N/A"
            tw_str = f"{tw_agree:.1%}" if tw_agree is not None else "N/A"

            lines.append(f"{var:<25} {cc_str:<10} {ch_str:<10} {gh_str:<10} {tw_str:<10}")

        # Overall row
        cc_oa = cc['overall_agreement']
        ch_oa = ch['overall_agreement']
        gh_oa = gh['overall_agreement']
        tw_oa = tw['overall_three_way_agreement']
        lines.append("-" * 65)
        overall_parts = ["OVERALL".ljust(25)]
        for val in [cc_oa, ch_oa, gh_oa, tw_oa]:
            overall_parts.append((f"{val:.1%}" if val is not None else "N/A").ljust(10))
        lines.append(''.join(overall_parts))

        lines.append("")
        lines.append("=" * 70)
        lines.append("END OF REPORT")
        lines.append("=" * 70)

        return "\n".join(lines)

    def generate_report(self, irr_summary: dict) -> str:
        """Generate a human-readable IRR report for a two-way comparison."""
        lines = []
        lines.append("=" * 70)
        lines.append("INTER-RATER RELIABILITY REPORT")
        lines.append("=" * 70)
        lines.append(f"Date: {irr_summary['comparison_date']}")
        lines.append(f"Coders: {irr_summary['coder1']} vs {irr_summary['coder2']}")
        lines.append(f"Platforms: {irr_summary['n_platforms']}")
        lines.append(f"Variables: {irr_summary['n_variables']}")
        lines.append("")

        lines.extend(self.generate_pairwise_report_section(irr_summary))

        lines.append("")
        lines.append("=" * 70)
        lines.append("END OF REPORT")
        lines.append("=" * 70)

        return "\n".join(lines)

    def run_analysis(self, coder1_dir: str, coder2_dir: str,
                     coder1_name: str = "Claude", coder2_name: str = "ChatGPT",
                     human_dir: str = None) -> dict:
        """Run full IRR analysis (2-way or 3-way if human_dir provided)."""

        self.log(f"\n{'='*60}")
        self.log("IRR ANALYSIS")
        self.log(f"{'='*60}")

        # Load AI coder results
        self.log(f"\nLoading {coder1_name} results from: {coder1_dir}")
        coder1_results = self.load_results(coder1_dir)
        self.log(f"  Loaded {len(coder1_results)} platforms")

        self.log(f"Loading {coder2_name} results from: {coder2_dir}")
        coder2_results = self.load_results(coder2_dir)
        self.log(f"  Loaded {len(coder2_results)} platforms")

        # ---- THREE-WAY ANALYSIS ----
        if human_dir and os.path.exists(human_dir):
            self.log(f"\nLoading Human results from: {human_dir}")
            human_results = self.load_results(human_dir)
            self.log(f"  Loaded {len(human_results)} platforms")

            analysis = self.compare_three_way(coder1_results, coder2_results, human_results)

            # Generate three-way report
            report = self.generate_three_way_report(analysis)

            # Save results
            summary_file = self.output_dir / "irr_summary_3way.json"
            summary_file.write_text(json.dumps(analysis, indent=2, default=str))
            self.log(f"\nSaved three-way IRR summary: {summary_file}")

            report_file = self.output_dir / "irr_report_3way.txt"
            report_file.write_text(report)
            self.log(f"Saved three-way IRR report: {report_file}")

            # Export all disagreements to CSV (three-way)
            disagreements = []
            for var in analysis['three_way']['variables']:
                for d in var['disagreements']:
                    disagreements.append({
                        'variable': var['variable'],
                        'platform_id': d['platform_id'],
                        'platform_name': d['platform_name'],
                        'Claude': d['Claude'],
                        'ChatGPT': d['ChatGPT'],
                        'Human': d['Human']
                    })
            if disagreements:
                df = pd.DataFrame(disagreements)
                df.to_csv(self.output_dir / "disagreements_3way.csv", index=False)
                self.log(f"Saved three-way disagreements: {self.output_dir}/disagreements_3way.csv")

            # Also save individual pairwise disagreement CSVs
            for pair_key in ['claude_vs_chatgpt', 'claude_vs_human', 'chatgpt_vs_human']:
                pair = analysis['pairwise'][pair_key]
                pair_disagrees = []
                for var in pair['variables']:
                    for d in var['disagreements']:
                        pair_disagrees.append({
                            'variable': var['variable'],
                            'platform_id': d['platform_id'],
                            'platform_name': d['platform_name'],
                            pair['coder1']: d[pair['coder1']],
                            pair['coder2']: d[pair['coder2']]
                        })
                if pair_disagrees:
                    df = pd.DataFrame(pair_disagrees)
                    df.to_csv(self.output_dir / f"disagreements_{pair_key}.csv", index=False)

            # Print summary
            self.log(f"\n{'='*60}")
            self.log("THREE-WAY IRR SUMMARY")
            self.log(f"{'='*60}")
            tw = analysis['three_way']
            if tw['overall_three_way_agreement'] is not None:
                self.log(f"Overall Three-Way Agreement: {tw['overall_three_way_agreement']:.1%}")
            if tw.get('mean_gwet_ac1') is not None:
                self.log(f"Mean Gwet's AC1: {tw['mean_gwet_ac1']:.3f} "
                          f"({self._kappa_interpretation(tw['mean_gwet_ac1'])}) [PRIMARY]")
            if tw.get('mean_kripp_alpha') is not None:
                self.log(f"Mean Krippendorff's Alpha: {tw['mean_kripp_alpha']:.3f} "
                          f"({self._kappa_interpretation(tw['mean_kripp_alpha'])})")
            if tw['mean_fleiss_kappa'] is not None:
                self.log(f"Mean Fleiss' Kappa: {tw['mean_fleiss_kappa']:.3f} "
                          f"({self._kappa_interpretation(tw['mean_fleiss_kappa'])})")

            self.log(f"\nPairwise Agreements:")
            for pair_key, label in [('claude_vs_chatgpt', 'Claude vs ChatGPT'),
                                    ('claude_vs_human', 'Claude vs Human'),
                                    ('chatgpt_vs_human', 'ChatGPT vs Human')]:
                pair = analysis['pairwise'][pair_key]
                oa = pair['overall_agreement']
                mk = pair['mean_kappa']
                self.log(f"  {label}: {oa:.1%} agreement" + (f", Kappa={mk:.3f}" if mk else ""))
            self.log(f"{'='*60}\n")

            return analysis

        # ---- TWO-WAY ANALYSIS ----
        else:
            self.log(f"\nComparing {coder1_name} vs {coder2_name}...")
            irr_summary = self.compare_coders(coder1_results, coder2_results, coder1_name, coder2_name)

            report = self.generate_report(irr_summary)

            summary_file = self.output_dir / "irr_summary.json"
            summary_file.write_text(json.dumps(irr_summary, indent=2, default=str))
            self.log(f"\nSaved IRR summary: {summary_file}")

            report_file = self.output_dir / "irr_report.txt"
            report_file.write_text(report)
            self.log(f"Saved IRR report: {report_file}")

            # Export disagreements to CSV
            disagreements = []
            for var in irr_summary['variables']:
                for d in var['disagreements']:
                    disagreements.append({
                        'variable': var['variable'],
                        'platform_id': d['platform_id'],
                        'platform_name': d['platform_name'],
                        coder1_name: d[coder1_name],
                        coder2_name: d[coder2_name]
                    })
            if disagreements:
                df = pd.DataFrame(disagreements)
                df.to_csv(self.output_dir / "disagreements.csv", index=False)
                self.log(f"Saved disagreements: {self.output_dir}/disagreements.csv")

            # Print summary
            self.log(f"\n{'='*60}")
            self.log("IRR SUMMARY")
            self.log(f"{'='*60}")
            self.log(f"Overall Agreement: {irr_summary['overall_agreement']:.1%}" if irr_summary['overall_agreement'] else "Overall Agreement: N/A")
            self.log(f"Mean Kappa: {irr_summary['mean_kappa']:.3f} ({irr_summary.get('n_kappa_valid', '?')} variables)" if irr_summary['mean_kappa'] else "Mean Kappa: N/A")
            self.log(f"Mean ICC: {irr_summary['mean_icc']:.3f}" if irr_summary['mean_icc'] else "Mean ICC: N/A")
            self.log(f"{'='*60}\n")

            return irr_summary


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Calculate Inter-Rater Reliability between AI coders and optional human coder',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Two-way comparison (Claude vs ChatGPT):
    python3 irr_calculator.py claude_results/ chatgpt_results/ --output irr_analysis/

    # Three-way comparison (Claude vs ChatGPT vs Human):
    python3 irr_calculator.py irr_test/claude_results/ irr_test/chatgpt_results/ \\
        --human human_results/ --output irr_test/irr_analysis/
        """
    )
    parser.add_argument('coder1_dir', help='Directory with first coder results (default: Claude)')
    parser.add_argument('coder2_dir', help='Directory with second coder results (default: ChatGPT)')
    parser.add_argument('--output', '-o', default='irr_analysis', help='Output directory')
    parser.add_argument('--coder1-name', default='Claude', help='Name of first coder')
    parser.add_argument('--coder2-name', default='ChatGPT', help='Name of second coder')
    parser.add_argument('--human', help='Human coder results directory for 3-way comparison')
    parser.add_argument('--quiet', '-q', action='store_true', help='Minimal output')

    args = parser.parse_args()

    for dir_path in [args.coder1_dir, args.coder2_dir]:
        if not os.path.exists(dir_path):
            print(f"ERROR: Directory not found: {dir_path}")
            sys.exit(1)

    if args.human and not os.path.exists(args.human):
        print(f"ERROR: Human results directory not found: {args.human}")
        sys.exit(1)

    calculator = IRRCalculator(
        output_dir=args.output,
        verbose=not args.quiet
    )

    calculator.run_analysis(
        coder1_dir=args.coder1_dir,
        coder2_dir=args.coder2_dir,
        coder1_name=args.coder1_name,
        coder2_name=args.coder2_name,
        human_dir=args.human
    )


if __name__ == "__main__":
    main()
