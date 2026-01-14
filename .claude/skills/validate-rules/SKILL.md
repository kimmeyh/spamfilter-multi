---
name: validate-rules
description: Validate YAML rule files (rules.yaml and rules_safe_senders.yaml) for syntax errors and regex pattern issues
allowed-tools: Bash, Read
user-invocable: true
---

# Validate Rules

Validates the YAML rule files used for spam filtering.

## Instructions

Run the PowerShell validation script to check rules.yaml and rules_safe_senders.yaml for:
- YAML syntax errors
- Invalid regex patterns
- Missing required fields
- Duplicate entries

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-yaml-rules.ps1
```

## When to Use

- Before committing changes to rule files
- After editing rules.yaml or rules_safe_senders.yaml
- When debugging rule matching issues
