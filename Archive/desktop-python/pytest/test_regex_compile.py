import os
import yaml
import re
import pytest

ROOT = os.path.dirname(os.path.dirname(__file__))
# DEPRECATED 10/18/2025: Consolidated to single filenames
# RULES_REGEX = os.path.join(ROOT, 'rulesregex.yaml')
# SAFE_SENDERS_REGEX = os.path.join(ROOT, 'rules_safe_sendersregex.yaml')
RULES_REGEX = os.path.join(ROOT, 'rules.yaml')
SAFE_SENDERS_REGEX = os.path.join(ROOT, 'rules_safe_senders.yaml')


def _iter_rule_patterns(rules_doc):
    # rules_doc can be list or dict with "rules"
    rules = rules_doc
    if isinstance(rules_doc, dict) and 'rules' in rules_doc:
        rules = rules_doc['rules']
    if not isinstance(rules, list):
        return
    for rule in rules:
        if not isinstance(rule, dict):
            continue
        conditions = rule.get('conditions', {}) or {}
        for key in ['header', 'body', 'subject', 'from']:
            vals = conditions.get(key)
            if isinstance(vals, list):
                for v in vals:
                    yield v


def _normalize_for_compile(patt: str) -> str:
    # Transitional support: treat leading '*' as regex '.*' so patterns like '*@foo.com' compile.
    if isinstance(patt, str) and patt.startswith('*'):
        return '.*' + patt[1:]
    return patt


def _load_yaml(path):
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


# DEPRECATED 10/18/2025: Updated test names to reflect consolidated filenames
# @pytest.mark.skipif(not os.path.exists(RULES_REGEX), reason='rulesregex.yaml not present')
@pytest.mark.skipif(not os.path.exists(RULES_REGEX), reason='rules.yaml not present')
def test_rulesregex_patterns_compile():
    """Test that all regex patterns in rules.yaml compile successfully"""
    doc = _load_yaml(RULES_REGEX)
    compiled = 0
    for patt in _iter_rule_patterns(doc):
        try:
            re.compile(_normalize_for_compile(patt), re.IGNORECASE)
            compiled += 1
        except re.error as e:
            # DEPRECATED 10/18/2025: Updated error message to reflect consolidated filename
            # pytest.fail(f'Invalid regex in rulesregex.yaml: {patt} ({e})')
            pytest.fail(f'Invalid regex in rules.yaml: {patt} ({e})')
    assert compiled >= 0  # no-op assert; main purpose is to fail on first invalid


# DEPRECATED 10/18/2025: Updated test names to reflect consolidated filenames
# @pytest.mark.skipif(not os.path.exists(SAFE_SENDERS_REGEX), reason='rules_safe_sendersregex.yaml not present')
@pytest.mark.skipif(not os.path.exists(SAFE_SENDERS_REGEX), reason='rules_safe_senders.yaml not present')
def test_safe_sendersregex_patterns_compile():
    """Test that all regex patterns in rules_safe_senders.yaml compile successfully"""
    doc = _load_yaml(SAFE_SENDERS_REGEX)
    # Support both {'safe_senders': [...]} and plain list forms
    if isinstance(doc, dict) and 'safe_senders' in doc:
        patterns = doc['safe_senders']
    else:
        patterns = doc if isinstance(doc, list) else []
    for patt in patterns:
        try:
            re.compile(_normalize_for_compile(patt), re.IGNORECASE)
        except re.error as e:
            # DEPRECATED 10/18/2025: Updated error message to reflect consolidated filename
            # pytest.fail(f'Invalid regex in rules_safe_sendersregex.yaml: {patt} ({e})')
            pytest.fail(f'Invalid regex in rules_safe_senders.yaml: {patt} ({e})')
