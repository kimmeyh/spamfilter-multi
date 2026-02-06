# Quick Reference Card

## 🚀 Installation (One-Time Setup)

```powershell
# Install custom MCP server
cd scripts
.\install-custom-mcp.ps1

# (Optional) Install GitHub MCP
$env:GITHUB_TOKEN = "ghp_your_token_here"
.\setup-claude-mcp.ps1 -InstallGitHub

# Restart Claude Code
```

---

## 💬 Ask Claude Code

```
"Validate my rules.yaml file"
"Test this regex: ^spam@.*\.com$ against: spam@example.com, user@gmail.com"
"Simulate processing email from spam@bad.com with subject URGENT"
"What MCP tools are available?"
"Create a GitHub issue for Phase 3.3"
```

---

## ⚡ Skills (Type `/skill <name>`)

| Command | Description |
|---------|-------------|
| `/skill validate-rules` | Validate YAML rules |
| `/skill test-regex` | Test regex pattern |
| `/skill full-test` | Run all tests + analyze |
| `/skill deploy-debug` | Deploy to emulator (keep accounts) |
| `/skill deploy-clean` | Deploy to emulator (fresh install) |
| `/skill check-coverage` | Generate test coverage |

---

## 🛠️ PowerShell Scripts

```powershell
# Validate YAML rules
.\scripts\validate-yaml-rules.ps1
.\scripts\validate-yaml-rules.ps1 -TestRegex

# Test regex pattern
.\scripts\test-regex-patterns.ps1 `
  -Pattern "^spam@.*\.com$" `
  -TestString "spam@example.com" `
  -PerformanceTest

# Build with emulator auto-start
.\mobile-app\scripts\build-with-secrets.ps1 `
  -BuildType debug `
  -InstallToEmulator `
  -StartEmulator `
  -SkipUninstall
```

---

## 🎣 Automated Hooks

| Event | Hook | Action |
|-------|------|--------|
| **Save *.yaml** | `on-save-yaml` | Auto-validates rules files |
| **git commit** | `pre-commit` | Validates YAML (blocks if fails) |
| **git checkout** | `post-checkout` | Runs `flutter pub get` |

---

## 📊 MCP Tools (via Claude)

### Validate Rules
```
"Validate my rules.yaml file"
```
Returns: Errors, warnings, pattern count, performance issues

### Test Regex
```
"Test regex ^spam@.*\.com$ against spam@example.com"
```
Returns: Match results, performance rating, warnings

### Simulate Email
```
"Simulate processing email: from spam@bad.com, subject URGENT"
```
Returns: Rule matched, actions to take

---

## 🔧 Common Workflows

### Add New Rule
1. Edit `rules.yaml`
2. Save → Auto-validates
3. `/skill test-regex` → Test pattern
4. `git commit` → Pre-commit validates
5. Done!

### Deploy & Test
1. `/skill deploy-debug`
2. Test on emulator
3. `/skill full-test`
4. Commit changes

### Debug Performance
1. Ask Claude: "Validate rules.yaml for performance"
2. Fix slow patterns
3. Test: `.\scripts\test-regex-patterns.ps1 -PerformanceTest`
4. Re-validate

---

## 📁 Important Files

```
.claude/
├── skills.json    # Custom skills
└── hooks.json     # Automated hooks

scripts/
├── validate-yaml-rules.ps1       # YAML validator
├── test-regex-patterns.ps1       # Regex tester
├── install-custom-mcp.ps1        # MCP installer
└── email-rule-tester-mcp/        # Custom MCP server
    └── server.js

~/.claude/config.json              # MCP configuration
```

---

## 🆘 Quick Fixes

**MCP not working?**
```powershell
node scripts/email-rule-tester-mcp/server.js  # Test server
# Restart Claude Code
```

**Hook not running?**
```powershell
.\scripts\validate-yaml-rules.ps1  # Test manually
Get-ExecutionPolicy                # Check policy
```

**Skill fails?**
```powershell
# Test command directly
.\mobile-app\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
```

---

## 📚 Documentation

- `CLAUDE_CODE_SETUP_GUIDE.md` - Complete setup guide
- `SETUP_COMPLETE_SUMMARY.md` - What was created
- `scripts/email-rule-tester-mcp/README.md` - MCP docs
- `mobile-app/scripts/EMULATOR_AUTO_START.md` - Emulator docs

---

**Print this for quick reference!** 📄
