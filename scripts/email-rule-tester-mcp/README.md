# Email Rule Tester MCP Server

Custom MCP server for testing and validating spam filter email rules.

## Features

- **Validate YAML Files**: Check `rules.yaml` and `rules_safe_senders.yaml` for syntax and schema compliance
- **Test Regex Patterns**: Test patterns against sample email headers
- **Performance Analysis**: Detect catastrophic backtracking and measure pattern performance
- **Simulate Rule Evaluation**: Test how an email would be processed by your rules

## Installation

```powershell
cd scripts/email-rule-tester-mcp
npm install
```

## Configuration

Add to your `~/.claude/config.json`:

```json
{
  "mcpServers": {
    "email-rule-tester": {
      "command": "node",
      "args": ["D:\\Data\\Harold\\github\\spamfilter-multi\\scripts\\email-rule-tester-mcp\\server.js"]
    }
  }
}
```

**Note**: Replace the path with your actual repository path.

## Available Tools

### 1. `validate_rules_yaml`

Validates `rules.yaml` file for:
- YAML syntax correctness
- Required schema fields (version, rules)
- Regex pattern validity
- Performance issues (catastrophic backtracking)

**Example**:
```javascript
{
  "file_path": "D:/Data/Harold/github/spamfilter-multi/rules.yaml"
}
```

**Returns**:
```json
{
  "valid": true,
  "errors": [],
  "warnings": ["Rule 0: Performance warning: Multiple .* in sequence"],
  "ruleCount": 45
}
```

### 2. `validate_safe_senders`

Validates `rules_safe_senders.yaml` file for:
- YAML syntax correctness
- Required safe_senders field
- Duplicate patterns
- Regex validity

**Example**:
```javascript
{
  "file_path": "D:/Data/Harold/github/spamfilter-multi/rules_safe_senders.yaml"
}
```

**Returns**:
```json
{
  "valid": true,
  "errors": [],
  "warnings": ["Duplicate pattern at index 5"],
  "patternCount": 12
}
```

### 3. `test_regex_pattern`

Tests a regex pattern against sample strings.

**Example**:
```javascript
{
  "pattern": "^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com$",
  "test_strings": [
    "user@example.com",
    "John Doe <user@example.com>",
    "user@mail.example.com"
  ],
  "check_performance": true
}
```

**Returns**:
```json
{
  "pattern": "^[^@\\s]+@(?:[a-z0-9-]+\\.)*example\\.com$",
  "valid": true,
  "warnings": [],
  "results": [
    { "string": "user@example.com", "matches": true },
    { "string": "John Doe <user@example.com>", "matches": false },
    { "string": "user@mail.example.com", "matches": true }
  ],
  "performance": {
    "avgTimeMs": 0.0024,
    "rating": "fast"
  },
  "matchCount": 2,
  "totalCount": 3
}
```

### 4. `simulate_rule_evaluation`

Simulates how an email would be evaluated against your rules.

**Example**:
```javascript
{
  "rules_file": "D:/Data/Harold/github/spamfilter-multi/rules.yaml",
  "safe_senders_file": "D:/Data/Harold/github/spamfilter-multi/rules_safe_senders.yaml",
  "email": {
    "from": "spam@example.com",
    "subject": "URGENT: You won the lottery!",
    "body": "Click here to claim your prize..."
  }
}
```

**Returns**:
```json
{
  "result": "rule_matched",
  "rule": "SpamAutoDeleteSubject",
  "matchedConditions": [
    { "field": "subject", "pattern": ".*urgent.*" }
  ],
  "actions": {
    "delete": true
  }
}
```

## Usage with Claude Code

Once installed, you can ask Claude Code:

```
"Validate my rules.yaml file"
"Test this regex pattern against these email addresses: ..."
"Simulate how this email would be processed: from spam@example.com, subject: URGENT"
```

Claude Code will automatically use the MCP tools to provide detailed analysis.

## Troubleshooting

### "Module not found" error
Run `npm install` in the `scripts/email-rule-tester-mcp` directory.

### MCP server not connecting
1. Check that the path in `config.json` is absolute and correct
2. Restart Claude Code after changing config
3. Verify Node.js is installed: `node --version`

### Performance warnings
If you see catastrophic backtracking warnings:
- Avoid patterns like `.*.*` or `(.+)*`
- Use non-greedy quantifiers: `.*?` instead of `.*`
- Be specific: `[a-z]+` instead of `.+`

## See Also

- `validate-yaml-rules.ps1` - PowerShell validation script (standalone)
- `test-regex-patterns.ps1` - PowerShell regex tester (standalone)
- `memory-bank/yaml-schemas.md` - YAML schema documentation
- `memory-bank/regex-conventions.md` - Regex pattern conventions
