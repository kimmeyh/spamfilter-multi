# Windows Bash Compatibility Guide for Claude Code

**Purpose**: Provide clear guidance on bash command compatibility on Windows with WSL (Windows Subsystem for Linux) installed.

**Audience**: Claude Code models executing bash commands in Windows WSL environment.

**Last Updated**: January 27, 2026

---

## Overview

When developing on Windows 11 with WSL installed, the system has two shell environments:
- **PowerShell**: Windows native shell (recommended for this project per CLAUDE.md)
- **Bash**: Unix-like shell via WSL (available but has compatibility issues with Windows paths)

This creates confusion when using bash commands with Windows paths. This guide clarifies what works, what does not, and recommended patterns.

---

## Quick Diagnosis

### How to Know Which Shell You are Using

When Claude Code executes a bash command, it uses WSL bash by default (not PowerShell). This causes errors when:
- Using Windows path syntax (`C:\path\to\file`)
- Using Windows-specific flags (e.g., `cd /d`)
- Mixing Windows and Unix path separators

### Error Signature

```bash
Error: Exit code 1
/usr/bin/bash: line 1: cd: too many arguments
```

**Root Cause**: Windows path with spaces is not properly quoted or escaped for bash.

---

## What Works vs What Does NOT

### [OK] What Works in Bash (WSL Environment)

| Operation | Command | Notes |
|-----------|---------|-------|
| **Git operations** | `git status` | Simple commands work fine |
| **Git clone** | `git clone <url>` | No path conversions needed |
| **Git branch** | `git branch --show-current` | Queries work fine |
| **Git log** | `git log --oneline -5` | Git-specific operations work |
| **Directory listing** | `ls -la` | Unix ls command works |
| **File listing** | `find . -name "*.dart"` | Unix find works in current dir |
| **Text processing** | `grep -r "pattern" .` | Relative paths work |

### [FAIL] What Does NOT Work in Bash

| Operation | Problem | Solution |
|-----------|---------|----------|
| **Change directory with Windows path** | `cd C:\Users\kimme\...` | Use WSL path: `cd /mnt/c/Users/kimme/...` OR use PowerShell |
| **Path with spaces (no quotes)** | `cd D:\Data\Harold\...` | Must quote: `cd "/mnt/d/Data/Harold/..."` |
| **Windows flags** | `cd /d D:\path` | `/d` flag is cmd.exe only, not bash |
| **Mixed separators** | `dir C:\path\*.dart` | `dir` is Windows cmd, not bash |
| **Complex path operations** | `cd "D:\Data\Harold\..."` | Even quoted, Windows paths cause confusion |
| **PowerShell cmdlets** | `Get-Process`, `Where-Object`, `Select-Object` | These are PowerShell only - see table below |

### [FAIL] PowerShell Cmdlets in Bash (EXIT CODE 127)

**Error Pattern**: `/usr/bin/bash: line 1: Get-Process: command not found`

PowerShell cmdlets do NOT work in bash. Here is the translation guide:

| PowerShell Cmdlet | Bash Error | Bash Equivalent |
|-------------------|------------|-----------------|
| `Get-Process` | "command not found" | `ps aux` |
| `Where-Object {...}` | "command not found" | `grep`, `awk` |
| `Select-Object Name, Id` | "command not found" | `awk '{print $2, $11}'` |
| `Get-ChildItem` | "command not found" | `ls`, `find` |
| `Set-Location` | "command not found" | `cd` |
| `Copy-Item` | "command not found" | `cp` |
| `Remove-Item` | "command not found" | `rm` |
| `New-Item -ItemType Directory` | "command not found" | `mkdir` |
| `New-Item -ItemType File` | "command not found" | `touch` |

**Why This Happens**:
- Bash tool uses WSL bash by default
- PowerShell cmdlets are NOT available in bash
- Must translate PowerShell cmdlets to Unix equivalents OR use PowerShell

**Example Error**:
```
Bash(Get-Process | Where-Object {$_.ProcessName -like "*spam_filter*"} | Select-Object ProcessName, Id)

Error: Exit code 127
/usr/bin/bash: line 1: Get-Process: command not found
/usr/bin/bash: line 1: Where-Object: command not found
/usr/bin/bash: line 1: Select-Object: command not found
```

**Correct Approaches**:

**Option 1: Use PowerShell (RECOMMENDED for Windows)**:
```powershell
# Find spam_filter processes
Get-Process | Where-Object {$_.ProcessName -like "*spam_filter*"} | Select-Object ProcessName, Id
```

**Option 2: Translate to Bash**:
```bash
# Find spam_filter processes
ps aux | grep 'spam_filter' | awk '{print $2, $11}'
```

**Translation Examples**:

| Task | PowerShell | Bash |
|------|------------|------|
| **List processes** | `Get-Process` | `ps aux` |
| **Filter processes** | `Where-Object {$_.Name -like "*pattern*"}` | `grep 'pattern'` |
| **Select columns** | `Select-Object Name, Id` | `awk '{print $2, $11}'` |
| **Kill process** | `Stop-Process -Name "name"` | `pkill name` or `kill PID` |
| **List files** | `Get-ChildItem` | `ls` or `find` |
| **Find files** | `Get-ChildItem -Recurse -Filter "*.dart"` | `find . -name "*.dart"` |
| **Count items** | `(Get-ChildItem).Count` | `ls -1 \| wc -l` |
| **Read file** | `Get-Content file.txt` | `cat file.txt` |
| **Test path** | `Test-Path file.txt` | `[ -f file.txt ] && echo exists` |

---

## Bash Command Patterns That Work Reliably

### Pattern 1: Git Operations (No Path Changes)

```bash
# [OK] WORKS: Stay in current directory, run git
git status
git branch --show-current
git log --oneline -1
git add .
git commit -m "message"
```

**Why it works**: Git operates in current directory; no explicit path changes needed.

### Pattern 2: Relative Path Operations

```bash
# [OK] WORKS: Relative paths from current directory
find . -name "*.dart"
grep -r "pattern" .
ls -la mobile-app/lib/
```

**Why it works**: Relative paths work fine in bash; no Windows path syntax.

### Pattern 3: WSL Path Conversion (If Needed)

```bash
# [OK] WORKS: Convert Windows path to WSL path
# Windows: C:\Users\kimme\path
# WSL: /mnt/c/Users/kimme/path

cd /mnt/c/Users/kimme/github/spamfilter-multi
```

**Why it works**: WSL paths use Unix syntax; bash understands them.

---

## Common Error Scenarios & Fixes

### Scenario 1: Bash Command with Windows Path

**Error**:
```
cd /d "D:\Data\Harold\github\spamfilter-multi" && git status
/usr/bin/bash: line 1: cd: too many arguments
```

**Why**: `cd /d` is cmd.exe syntax, not bash. Bash tries to interpret `/d` as separate argument.

**Fix Option 1**: Use PowerShell instead
```powershell
cd "D:\Data\Harold\github\spamfilter-multi"
git status
```

**Fix Option 2**: Use WSL path conversion
```bash
cd /mnt/d/Data/Harold/github/spamfilter-multi
git status
```

**Fix Option 3**: Stay in current directory (recommended for git)
```bash
# If already in correct directory:
git status
```

---

### Scenario 2: Path with Spaces in Bash

**Error**:
```
cd D:\Data\Harold\...
/usr/bin/bash: line 1: cd: D:\Data\Harold\...: No such file or directory
```

**Why**: Spaces in path are interpreted as separate arguments unless quoted/escaped.

**Fix**: Properly quote the path
```bash
# [OK] CORRECT: Single quotes work in bash
cd "/mnt/d/Data/Harold/github/spamfilter-multi"

# [OK] ALSO WORKS: Escape spaces with backslash
cd /mnt/d/Data/Harold\ /github/spamfilter-multi
```

---

### Scenario 3: Windows Backslashes in File Paths

**Error**:
```bash
wc -l D:\Data\Harold\github\spamfilter-multi\docs\ALL_SPRINTS_MASTER_PLAN.md
wc: 'D:DataHaroldgithubspamfilter-multidocsALL_SPRINTS_MASTER_PLAN.md': No such file or directory
```

**Why**: Bash interprets backslashes (`\`) as escape characters, not path separators. The `\D`, `\H`, `\g`, `\s`, `\d`, `\A` sequences are consumed as escape sequences, resulting in a mangled path.

**Fix Option 1**: Use forward slashes (recommended)
```bash
# [OK] CORRECT: Forward slashes work in bash on Windows
wc -l "D:/Data/Harold/github/spamfilter-multi/docs/ALL_SPRINTS_MASTER_PLAN.md"
```

**Fix Option 2**: Use WSL path conversion
```bash
# [OK] CORRECT: Convert to WSL path format
wc -l "/mnt/d/Data/Harold/github/spamfilter-multi/docs/ALL_SPRINTS_MASTER_PLAN.md"
```

**Fix Option 3**: Use PowerShell instead
```powershell
# [OK] CORRECT: PowerShell handles Windows paths natively
Get-Content "D:\Data\Harold\github\spamfilter-multi\docs\ALL_SPRINTS_MASTER_PLAN.md" | Measure-Object -Line
```

**Key Insight**: When using bash with absolute Windows paths, ALWAYS use forward slashes (`/`) instead of backslashes (`\`), or convert to WSL path format (`/mnt/d/...`).

---

### Scenario 4: Complex Commands Mixing Windows & Unix

**Error**:
```
cd C:\path && flutter test --coverage
/usr/bin/bash: line 1: cd: C:\path: No such file or directory
```

**Why**: Windows path syntax does not translate to bash.

**Fix**: Use PowerShell or ensure correct working directory first
```powershell
# PowerShell approach (RECOMMENDED)
cd "D:\Data\Harold\github\spamfilter-multi\mobile-app"
flutter test --coverage
```

---

## Decision Tree: Bash or PowerShell?

Use this flowchart to decide which shell to use:

```
START: Do I need to execute a shell command?
│
├─ Do I need to use PowerShell cmdlets (Get-Process, Where-Object, etc.)?
│  └─ YES → Use PowerShell (cmdlets do NOT work in bash)
│  └─ NO → Continue
│
├─ Is it a GIT operation with no path changes?
│  └─ YES → Use Bash (git status, git log, etc.)
│  └─ NO → Continue
│
├─ Do I need to change directories to a Windows path?
│  └─ YES → Use PowerShell
│  └─ NO → Continue
│
├─ Do I need to run flutter, npm, or other build tools?
│  └─ YES → Use PowerShell (build tools expect Windows paths)
│  └─ NO → Continue
│
├─ Am I searching/grepping in relative paths?
│  └─ YES → Bash is fine (git operations, find, grep)
│  └─ NO → Continue
│
└─ DEFAULT → Use PowerShell (safer, fewer compatibility issues)
```

---

## Recommended Practices for Claude Code

### For Git Operations

```bash
# [OK] GOOD: Simple git commands stay in current directory
git status
git branch --show-current
git log --oneline -1
git diff main..HEAD
```

### For Flutter/Build Operations

```powershell
# [OK] GOOD: Use PowerShell for build tools
cd "D:\Data\Harold\github\spamfilter-multi\mobile-app"
flutter test
flutter analyze
```

### For File Operations

```bash
# [OK] GOOD: Use relative paths in bash
grep -r "pattern" . --include="*.dart"
find . -name "*.dart" -type f
```

### For Complex Workflows

```powershell
# [OK] GOOD: Use PowerShell for multi-step operations
cd "D:\Data\Harold\github\spamfilter-multi"
git status
cd mobile-app
flutter test
flutter analyze
```

---

## Workarounds If Bash Must Be Used

If for some reason bash must be used for a complex operation, use these escape patterns:

### Escape Pattern 1: Quote the Entire Command

```bash
cd "/mnt/d/Data/Harold/github/spamfilter-multi" && git status && cd mobile-app && ls -la
```

### Escape Pattern 2: Use WSL Path Conversion Utility

Create a helper script `bash-helper.sh`:
```bash
#!/bin/bash
# Convert Windows path to WSL path
windows_path="$1"
wsl_path=$(wslpath "$windows_path")
echo "$wsl_path"
```

Then use it:
```bash
cd $(bash-helper.sh "D:\Data\Harold\github\spamfilter-multi")
```

---

## Setting Execution Context (For Claude Code Tools)

When Claude Code executes commands, it should consider:

1. **Default to PowerShell** for Windows development
2. **Use Bash only for git operations** (and keep working directory unchanged)
3. **Never mix Windows paths with bash** without proper WSL conversion
4. **Document any complex bash usage** in code comments

---

## Example: Correct Sprint Startup Commands

**Sprint Startup Checklist (Using Correct Shells)**:

```powershell
# Use PowerShell for Windows path operations
Write-Host "=== Sprint Startup Check ==="
cd "D:\Data\Harold\github\spamfilter-multi"
git status --short
git branch --show-current

# Switch to bash for simple git queries
# git log --oneline -1
# gh issue list --limit 1
```

**Why this works**:
- PowerShell handles Windows path changes
- Git operations work in bash (if needed)
- No mixing of shells in single command chain

---

## Reference: WSL Path Conversion

| Windows Path | WSL Path |
|--------------|----------|
| `C:\Users\kimme\...` | `/mnt/c/Users/kimme/...` |
| `D:\Data\...` | `/mnt/d/Data/...` |
| `E:\Projects\...` | `/mnt/e/Projects/...` |
| `.` (current) | `.` (same in both) |
| `..` (parent) | `..` (same in both) |

**Pattern**: `C:\path\to\file` → `/mnt/c/path/to/file` (lowercase drive letter)

---

## FAQ

**Q: Why does the project recommend PowerShell?**
A: PowerShell handles Windows paths natively. Bash requires WSL path conversion. For Windows-first development, PowerShell is more efficient.

**Q: Can I force Claude Code to use PowerShell?**
A: Currently, the Bash tool uses bash/WSL by default. Consider creating a PowerShell-specific skill or wrapper.

**Q: What if I have both WSL and Git Bash?**
A: Git Bash (Git for Windows) also has path compatibility issues. PowerShell is still recommended.

**Q: How do I know which bash I'm using?**
A: Run `bash --version`. If it shows "bash version 5.x.x (from WSL)" you are in WSL.

---

## Recommendations for Documentation Updates

**CLAUDE.md** (add to "Common Commands" section):
- Emphasize PowerShell as primary shell
- Note that bash should only be used for git operations
- Reference this document for troubleshooting

**SPRINT_EXECUTION_WORKFLOW.md** (add to Phase 0 or 1):
- Use PowerShell in all example commands
- If bash is used, explain why
- Reference this document for compatibility issues

**.claude/skills/** (create wrapper if needed):
- `bash-safe-git.ps1` - Wrapper that converts Windows paths to WSL paths automatically
- Allows safer bash usage without user thinking about conversion

---

**Document Version**: 1.0
**Created**: January 27, 2026
**Applies to**: Windows 11 with WSL and PowerShell development environment
**Reference**: CLAUDE.md § "Common Commands", SPRINT_EXECUTION_WORKFLOW.md § Phase 0-1
