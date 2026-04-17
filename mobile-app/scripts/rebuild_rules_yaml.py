#!/usr/bin/env python3
"""
Rebuild bundled rules.yaml from monolithic rules to individual per-pattern rules.

This script:
1. Reads the current monolithic rules.yaml
2. Extracts patterns from the header rule (SpamAutoDeleteHeader)
3. Classifies each pattern as entire_domain or exact_domain
4. Generates individual YAML entries for each pattern
5. Filters to include only header_from rules
6. Writes the new YAML to assets/rules/rules.yaml
"""

import re
import yaml
from pathlib import Path


def classify_pattern(pattern: str) -> tuple[str | None, str]:
    """
    Classify a pattern as entire_domain or exact_domain.
    Returns tuple of (classification, sourceDomain)

    Patterns from YAML:
    - Entire domain: @(?:[a-z0-9-]+\.)*domain\.[a-z0-9.-]+$
    - Exact domain: @domain\.[a-z0-9.-]+$
    """
    # Entire domain: contains (?:[a-z0-9-]+\.) subdomain matcher
    if '(?:[a-z0-9-]+\\.' in pattern:
        # Extract domain between )* and the first \.
        # Use regex: find domain after )* and before first \.
        match = re.search(r'\*([a-z0-9.-]+)\\.', pattern)
        if match:
            domain = match.group(1)
            return ('entire_domain', domain)

    # Exact domain: @domain\.[...]+$ (no subdomain matcher)
    if pattern.startswith('@') and pattern.endswith('$'):
        # Extract domain part (between @ and $)
        domain_part = pattern[1:-1]
        # If it doesn't contain group syntax (parens or question marks), it's exact_domain
        if '(' not in domain_part and '?' not in domain_part:
            # Unescape for display: \. becomes .
            display_domain = domain_part.replace('\\.', '.')
            return ('exact_domain', display_domain)

    return (None, '')


def main():
    print('[INFO] Rebuilding bundled rules.yaml from monolithic format...\n')

    script_dir = Path(__file__).parent
    rules_yaml_path = script_dir.parent / 'assets' / 'rules' / 'rules.yaml'

    if not rules_yaml_path.exists():
        print(f'[ERROR] rules.yaml not found at: {rules_yaml_path}')
        return 1

    try:
        # Load current YAML
        with open(rules_yaml_path, 'r') as f:
            data = yaml.safe_load(f)

        # Find SpamAutoDeleteHeader rule
        rules = data.get('rules', [])
        header_rule = None
        for rule in rules:
            if rule.get('name') == 'SpamAutoDeleteHeader':
                header_rule = rule
                break

        if not header_rule:
            print('[ERROR] SpamAutoDeleteHeader rule not found')
            return 1

        # Extract header patterns
        header_patterns = header_rule.get('conditions', {}).get('header', [])
        print(f'[INFO] Found {len(header_patterns)} header patterns to classify')

        # Classify patterns
        classified_patterns = []
        tld_count = 0
        entire_domain_count = 0
        exact_domain_count = 0
        skipped_count = 0

        for pattern in header_patterns:
            classification, source_domain = classify_pattern(pattern)

            if classification is None:
                skipped_count += 1
                continue

            if classification == 'top_level_domain':
                tld_count += 1
            elif classification == 'entire_domain':
                entire_domain_count += 1
            elif classification == 'exact_domain':
                exact_domain_count += 1

            classified_patterns.append({
                'pattern': pattern,
                'type': classification,
                'sourceDomain': source_domain,
            })

        print('\n[INFO] Classification summary:')
        print(f'  - TLD: {tld_count}')
        print(f'  - Entire Domain: {entire_domain_count}')
        print(f'  - Exact Domain: {exact_domain_count}')
        print(f'  - Skipped: {skipped_count}')
        print(f'  - Total to include: {len(classified_patterns)}')

        # Generate individual YAML rules
        new_rules = []

        for i, pat in enumerate(classified_patterns):
            pattern_type = pat['type']
            source_domain = pat['sourceDomain']

            # Determine execution order based on type
            if pattern_type == 'top_level_domain':
                order = 10
            elif pattern_type == 'entire_domain':
                order = 20
            else:  # exact_domain
                order = 30

            # Generate unique rule name
            # Use pattern type prefix + index to guarantee uniqueness
            type_prefix = 'tld' if pattern_type == 'top_level_domain' else 'entire' if pattern_type == 'entire_domain' else 'exact'
            rule_name = f'{type_prefix}_{i}'

            new_rules.append({
                'name': rule_name,
                'enabled': 'True',
                'isLocal': 'True',
                'executionOrder': order,
                'conditions': {
                    'type': 'OR',
                    'body': [],
                    'from': [],
                    'header': [pat['pattern']],
                    'subject': [],
                },
                'actions': {
                    'delete': 'True',
                },
                'patternCategory': 'header_from',
                'patternSubType': pattern_type,
                'sourceDomain': source_domain,
            })

        # Build new RuleSet
        new_data = {
            'version': '1.0',
            'settings': {
                'default_execution_order_increment': 10,
            },
            'rules': new_rules,
        }

        # Write new YAML with proper formatting
        with open(rules_yaml_path, 'w') as f:
            # Use custom representer for 'True' strings
            yaml.dump(
                new_data,
                f,
                default_flow_style=False,
                sort_keys=False,
                allow_unicode=True,
                width=100,
            )

        print(f'\n[OK] Rebuilt rules.yaml with {len(new_rules)} individual rules')
        print(f'[OK] Written to: {rules_yaml_path}')
        return 0

    except Exception as e:
        print(f'[ERROR] Failed to rebuild YAML: {e}')
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    exit(main())
