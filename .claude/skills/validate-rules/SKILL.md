---
name: validate-rules
description: Validate YAML rule files (rules.yaml and rules_safe_senders.yaml) for syntax errors and regex pattern issues
allowed-tools: Bash, Read
user-invocable: true
model: haiku
---

# Validate Rules

Validates the YAML rule files used for spam filtering.

## Instructions

Run the Python validation script to check rules.yaml and rules_safe_senders.yaml for:
- YAML syntax errors
- Invalid regex patterns
- Missing required fields
- Duplicate entries

## Command

```bash
python scripts/validate-yaml-rules.py
```

With no arguments it checks `rules.yaml` and `rules_safe_senders.yaml` in the current folder when they exist there,
otherwise the repository copies in `mobile-app/assets/rules/`. Options: `--rules-file PATH`,
`--safe-senders-file PATH`, `--test-regex`. Exit code 0 means no errors (warnings and "not checked" patterns are
listed); exit code 1 means at least one error.

## When to Use

- Before committing changes to rule files
- After editing rules.yaml or rules_safe_senders.yaml
- When debugging rule matching issues
