# Claude Code Setup Guide

Complete guide for setting up Claude Code with custom MCP servers, skills, and hooks for the spam filter project.

## Table of Contents

1. [MCP Server Installation](#mcp-server-installation)
2. [Custom Validation Scripts](#custom-validation-scripts)
3. [Custom MCP Server (Email Rule Tester)](#custom-mcp-server)
4. [Skills and Hooks](#skills-and-hooks)
5. [Usage Examples](#usage-examples)
6. [Troubleshooting](#troubleshooting)

---

## 1. MCP Server Installation

### Prerequisites

- Node.js (v16+) and npm installed
- PowerShell 5.1+ (Windows)
- Flutter SDK installed
- GitHub Personal Access Token (for GitHub MCP)

### Quick Setup

Run the automated setup script:

```powershell
cd scripts
.\setup-claude-mcp.ps1 -InstallAll
```

### Manual Setup

#### GitHub MCP Server

1. **Create GitHub Personal Access Token**:
   - Go to: https://github.com/settings/tokens
   - Generate new token (classic)
   - Required scopes: `repo`, `issues`, `pull_requests`, `workflow`
   - Copy token (you won't see it again!)

2. **Set environment variable**:
   ```powershell
   $env:GITHUB_TOKEN = "ghp_your_token_here"
   
   # Make permanent (add to system environment variables):
   [System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', 'ghp_your_token_here', 'User')
   ```

3. **Add to Claude config** (`~/.claude/config.json`):
   ```json
   {
     "mcpServers": {
       "github": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-github"],
         "env": {
           "GITHUB_TOKEN": "ghp_your_token_here"
         }
       }
     }
   }
   ```

4. **Restart Claude Code**

#### Verify Installation

Ask Claude Code:
```
"List my GitHub repositories"
"Create a GitHub issue for Phase 3.3"
```

---

## 2. Custom Validation Scripts

### YAML Rule Validator

**File**: `scripts/validate-yaml-rules.ps1`

**Features**:
- YAML syntax checking
- Schema validation (version, rules, safe_senders fields)
- Regex pattern validation
- Performance issue detection (catastrophic backtracking)
- Duplicate pattern detection

**Usage**:

```powershell
# Validate default files (rules.yaml + rules_safe_senders.yaml)
.\scripts\validate-yaml-rules.ps1

# Test regex patterns against samples
.\scripts\validate-yaml-rules.ps1 -TestRegex

# Custom file paths
.\scripts\validate-yaml-rules.ps1 -RulesFile "path/to/rules.yaml" -SafeSendersFile "path/to/safe_senders.yaml"
```

**Example Output**:
```
[1/3] Validating rules.yaml...
  [OK] Found 45 regex patterns, 45 valid

[2/3] Validating rules_safe_senders.yaml...
  [OK] Found 12 safe sender patterns, 12 valid
  [DUPLICATE WARNING] Found 1 duplicate patterns

[3/3] Skipping regex testing (use -TestRegex to enable)

✓ All validations passed!
Warnings: 1
```

### Regex Pattern Tester

**File**: `scripts/test-regex-patterns.ps1`

**Features**:
- Test regex against sample strings
- Performance benchmarking (1000 iterations)
- Catastrophic backtracking detection
- Match details and capture groups
- Interactive or batch mode

**Usage**:

```powershell
# Test single pattern
.\scripts\test-regex-patterns.ps1 `
  -Pattern "^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$" `
  -TestString "user@example.com"

# Test with multiple strings from file
.\scripts\test-regex-patterns.ps1 `
  -Pattern ".*urgent.*" `
  -File "test-emails.txt" `
  -ShowMatches

# Performance test
.\scripts\test-regex-patterns.ps1 `
  -Pattern "^.*@spam.*\.com$" `
  -TestString "spam@spam.com" `
  -PerformanceTest
```

**Example Output**:
```
[1/3] Validating regex pattern...
Pattern: ^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$
  [OK] Pattern is valid

[2/3] Checking for performance issues...
  [OK] No obvious performance issues detected

[3/3] Testing pattern matches...
  ✓ MATCH: user@example.com
  ✗ NO MATCH: John Doe <user@example.com>
  ✓ MATCH: admin@mail.example.com

Summary: 2 of 3 strings matched
```

---

## 3. Custom MCP Server (Email Rule Tester)

**Directory**: `scripts/email-rule-tester-mcp/`

Custom MCP server specifically for email spam filter rule testing.

### Installation

```powershell
cd scripts/email-rule-tester-mcp
npm install
```

### Configuration

Add to `~/.claude/config.json`:

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

**Important**: Use **absolute path** to `server.js`.

### Available Tools

1. **`validate_rules_yaml`** - Validate rules.yaml
2. **`validate_safe_senders`** - Validate safe senders file
3. **`test_regex_pattern`** - Test regex with performance analysis
4. **`simulate_rule_evaluation`** - Simulate email processing

### Usage with Claude Code

Once installed, ask Claude Code:

```
"Validate my rules.yaml file"
"Test this regex: ^spam@.*\.com$ against: spam@example.com, user@gmail.com"
"Simulate processing this email: from spam@bad.com, subject URGENT"
```

### Example Tool Call

**Request**:
```javascript
{
  "tool": "test_regex_pattern",
  "arguments": {
    "pattern": "^[^@\\s]+@gmail\\.com$",
    "test_strings": [
      "user@gmail.com",
      "John Doe <user@gmail.com>",
      "user@mail.gmail.com"
    ],
    "check_performance": true
  }
}
```

**Response**:
```json
{
  "pattern": "^[^@\\s]+@gmail\\.com$",
  "valid": true,
  "warnings": [],
  "results": [
    { "string": "user@gmail.com", "matches": true },
    { "string": "John Doe <user@gmail.com>", "matches": false },
    { "string": "user@mail.gmail.com", "matches": false }
  ],
  "performance": {
    "avgTimeMs": 0.0018,
    "rating": "fast"
  },
  "matchCount": 1,
  "totalCount": 3
}
```

---

## 4. Skills and Hooks

### Skills (`.claude/skills.json`)

Custom commands available in Claude Code.

#### Available Skills

1. **`validate-rules`** - Validate YAML rule files
2. **`test-regex`** - Test regex pattern (interactive)
3. **`full-test`** - Run all tests + analyze
4. **`quick-test`** - Run specific test file
5. **`deploy-debug`** - Build & deploy debug APK (preserves accounts)
6. **`deploy-clean`** - Build & deploy debug APK (clean install)
7. **`deploy-release`** - Build & deploy release APK
8. **`check-coverage`** - Run tests with coverage
9. **`setup-mcp`** - Setup MCP servers
10. **`commit-phase`** - Create structured phase commit

#### Using Skills

In Claude Code:
```
/skill validate-rules
/skill deploy-debug
/skill full-test
```

Or ask Claude:
```
"Run the validate-rules skill"
"Deploy debug build to emulator"
```

### Hooks (`.claude/hooks.json`)

Automated actions triggered by events.

#### Available Hooks

1. **`pre-commit`** - Validate YAML before commit ✅ **Enabled**
2. **`pre-push`** - Run all tests before push ⚠️ **Disabled** (slow)
3. **`post-checkout`** - Install Flutter deps after checkout ✅ **Enabled**
4. **`on-save-yaml`** - Validate YAML on file save ✅ **Enabled**

#### Hook Behavior

**Pre-Commit Hook**:
```powershell
git add rules.yaml
git commit -m "Update spam rules"

# Hook runs automatically:
# [1/3] Validating rules.yaml...
# [2/3] Validating rules_safe_senders.yaml...
# [3/3] Skipping regex testing...
# ✓ All validations passed!
# [main abc1234] Update spam rules
```

If validation fails, commit is blocked:
```
[YAML ERROR] rules.yaml contains tabs
YAML validation failed. Commit blocked.
error: failed to run hook: pre-commit
```

**On-Save Hook** (YAML files):
Automatically validates when you save `rules.yaml` or `rules_safe_senders.yaml`.

---

## 5. Usage Examples

### Example Workflow 1: Adding New Rule

1. **Edit `rules.yaml`** - Add new rule with regex pattern
2. **Auto-validation on save** - Hook validates immediately
3. **Test regex pattern**:
   ```
   /skill test-regex
   # Enter pattern: ^spam@.*\.com$
   # Enter test string: spam@example.com
   ```
4. **Validate full file**:
   ```
   /skill validate-rules
   ```
5. **Commit changes**:
   ```powershell
   git add rules.yaml
   git commit -m "feat: Add spam domain blocking rule"
   # Pre-commit hook validates automatically
   ```

### Example Workflow 2: Testing Phase 3.3 Changes

1. **Run all tests**:
   ```
   /skill full-test
   ```
2. **Deploy to emulator** (preserving test accounts):
   ```
   /skill deploy-debug
   ```
3. **Manual testing** on emulator
4. **Check coverage**:
   ```
   /skill check-coverage
   ```
5. **Commit phase changes**:
   ```
   /skill commit-phase
   # Enter phase: 3.3
   # Enter message: Implemented dynamic folder discovery
   ```

### Example Workflow 3: Using Custom MCP Server

**Ask Claude Code**:
```
"Validate my rules.yaml and tell me if there are any performance issues"
```

Claude will use `validate_rules_yaml` tool:
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    "Rule 12 (SpamUrgent): Performance warning: Multiple .* in sequence"
  ],
  "ruleCount": 45
}
```

**Ask Claude**:
```
"Test this regex pattern: ^.*urgent.*important.* against the string: 
URGENT: This is IMPORTANT message"
```

Claude will use `test_regex_pattern` tool and show performance analysis.

---

## 6. Troubleshooting

### MCP Server Not Connecting

**Symptom**: Claude Code doesn't recognize MCP tools

**Solutions**:
1. Verify `~/.claude/config.json` exists and has correct syntax
2. Use **absolute paths** (not relative)
3. Restart Claude Code completely
4. Check Node.js is installed: `node --version`
5. Test MCP server manually:
   ```powershell
   node scripts/email-rule-tester-mcp/server.js
   # Should output: "Email Rule Tester MCP server running on stdio"
   ```

### GitHub MCP "Authentication Failed"

**Symptom**: GitHub MCP returns 401/403 errors

**Solutions**:
1. Verify token has correct scopes (repo, issues, pull_requests)
2. Check token hasn't expired
3. Ensure `GITHUB_TOKEN` environment variable is set:
   ```powershell
   $env:GITHUB_TOKEN
   # Should output: ghp_your_token_here
   ```
4. Restart Claude Code after setting env var

### Hook Not Running

**Symptom**: Pre-commit hook doesn't validate YAML

**Solutions**:
1. Check hook is enabled in `.claude/hooks.json`
2. Verify PowerShell execution policy:
   ```powershell
   Get-ExecutionPolicy
   # Should be: RemoteSigned or Unrestricted
   ```
3. Test hook manually:
   ```powershell
   .\scripts\validate-yaml-rules.ps1
   ```
4. Check Claude Code settings for hook configuration

### Skill Fails with "Command not found"

**Symptom**: Running `/skill deploy-debug` fails

**Solutions**:
1. Verify `scripts/build-with-secrets.ps1` exists
2. Check working directory in skill definition
3. Use absolute paths in `.claude/skills.json`
4. Test command manually in PowerShell

### Regex Validation False Positives

**Symptom**: Valid regex marked as dangerous

**Solutions**:
1. Check pattern against known-bad patterns list
2. Run performance test: `.\scripts\test-regex-patterns.ps1 -PerformanceTest`
3. If false positive, consider pattern rewrite for clarity
4. Add note in `rules.yaml` explaining complex pattern

---

## Summary Checklist

After setup, verify:

- [ ] GitHub MCP server connected (ask: "List my repos")
- [ ] Email Rule Tester MCP server running (ask: "Validate my rules.yaml")
- [ ] Validation scripts executable (`.\scripts\validate-yaml-rules.ps1`)
- [ ] Skills available in Claude Code (`/skill` shows list)
- [ ] Hooks enabled (check `.claude/hooks.json`)
- [ ] Pre-commit hook validates YAML (test with dummy commit)

## Next Steps

1. **Test all MCP servers** - Verify tools work
2. **Run validation** - Check existing rules.yaml
3. **Try a skill** - Deploy debug build
4. **Test hooks** - Make a small commit
5. **Ask Claude** - "What MCP tools are available?"

## Support

- **MCP Documentation**: https://modelcontextprotocol.io/
- **Claude Code Docs**: https://github.com/anthropics/claude-code
- **Project Issues**: See `PHASE_3_GITHUB_ISSUES.md`

---

**Last Updated**: January 6, 2026  
**Phase**: 3.3 - Enhanced tooling and automation
