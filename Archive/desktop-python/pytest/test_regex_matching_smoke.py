import os
import re
import importlib


def test_regex_match_simple_sender(monkeypatch, tmp_path):
    mod = importlib.import_module('withOutlookRulesYAML')
    agent = mod.OutlookSecurityAgent(test_mode=True)
    agent.set_active_mode(True)

    # Build minimal in-memory rules doc
    rules_doc = {
        'rules': [
            {
                'name': 'SpamAutoDeleteFrom',
                'enabled': True,
                'conditions': {
                    'from': [r'^.*@example\.com$']
                },
                'exceptions': {},
                'actions': {'delete': True},
                'metadata': {}
            }
        ]
    }
    safe = {'safe_senders': []}

    # Compile helper should accept the pattern
    compiled = agent._compile_pattern_list(rules_doc['rules'][0]['conditions']['from'])
    ok, pat = agent._any_regex_match(compiled, 'user@example.com')
    assert ok is True
    assert pat == r'^.*@example\.com$'


def test_compile_error_logged(monkeypatch, capsys):
    mod = importlib.import_module('withOutlookRulesYAML')
    agent = mod.OutlookSecurityAgent(test_mode=True)
    bad_patterns = ['(+invalid']
    compiled = agent._compile_pattern_list(bad_patterns)
    # It should skip invalid and return empty list
    assert compiled == []
