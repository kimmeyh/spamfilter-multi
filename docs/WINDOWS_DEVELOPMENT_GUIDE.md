# Windows Development Guide for Claude Code

**Purpose**: Comprehensive guide for Windows 11 development environment covering shell compatibility, Unicode encoding, PowerShell execution, and build scripts.

**Audience**: Claude Code models working in Windows development environment

**Last Updated**: February 1, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Shell Selection: PowerShell vs Bash](#shell-selection-powershell-vs-bash)
3. [Unicode Encoding Issues](#unicode-encoding-issues)
4. [PowerShell Best Practices](#powershell-best-practices)
5. [Build Script Usage](#build-script-usage)
6. [Common Error Scenarios](#common-error-scenarios)
7. [Quick Reference](#quick-reference)

---

## Overview

### Windows Development Environment

This project uses **Windows 11** as the primary development platform with:
- **PowerShell**: Primary shell (recommended per CLAUDE.md)
- **Bash/WSL**: Available but has compatibility issues
- **Python**: Used for scripts and automation
- **Flutter**: Cross-platform app framework

### Key Challenges

1. **Path Syntax**: Windows uses `\` (backslash), Unix uses `/` (forward slash)
2. **Unicode Encoding**: Windows console (cp1252) doesn't support Unicode characters
3. **PowerShell vs Bash**: Different command syntax and capabilities
4. **Build Scripts**: Must handle secrets, paths, and platform differences

---

## Shell Selection: PowerShell vs Bash

### Decision Tree

Use this flowchart to decide which shell to use:

```
START: Do I need to execute a shell command?
│
├─ Do I need PowerShell cmdlets (Get-Process, Where-Object, etc.)?
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

### [OK] What Works in Bash (WSL)

| Operation | Command | Notes |
|-----------|---------|-------|
| **Git operations** | `git status` | Simple commands work fine |
| **Git log** | `git log --oneline -5` | Git-specific operations work |
| **Directory listing** | `ls -la` | Unix ls command works |
| **File search** | `find . -name "*.dart"` | Relative paths work |
| **Text processing** | `grep -r "pattern" .` | Relative paths work |

### [FAIL] What Does NOT Work in Bash

| Operation | Problem | Solution |
|-----------|---------|----------|
| **Windows path** | `cd C:\Users\kimme\...` | Use PowerShell or WSL path `/mnt/c/...` |
| **Path with spaces** | `cd D:\Data\Harold\...` | Must quote: `cd "/mnt/d/..."` |
| **Windows flags** | `cd /d D:\path` | `/d` is cmd.exe only, not bash |
| **PowerShell cmdlets** | `Get-Process`, `Where-Object` | Use PowerShell or translate to Unix |

### PowerShell Cmdlet Translation

| PowerShell | Bash Equivalent | Use Case |
|------------|----------------|----------|
| `Get-Process` | `ps aux` | List processes |
| `Where-Object {...}` | `grep`, `awk` | Filter output |
| `Select-Object Name, Id` | `awk '{print $2, $11}'` | Select columns |
| `Get-ChildItem` | `ls`, `find` | List files |
| `Stop-Process -Name "app"` | `pkill app` | Kill process |
| `Test-Path file.txt` | `[ -f file.txt ]` | Check file exists |

**Error Pattern** (using PowerShell cmdlets in bash):
```
/usr/bin/bash: line 1: Get-Process: command not found
```

**Solution**: Use PowerShell for these operations.

---

## Unicode Encoding Issues

### The Problem

**Error Pattern**:
```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2713' in position 0: character maps to <undefined>
```

**Root Cause**: Windows console uses cp1252 encoding by default, which doesn't support Unicode characters like ✓ (U+2713) or [OK] (U+2705).

### Sprint 10 & 11 Examples

Multiple attempts to fix Unicode errors all failed:
```powershell
# Attempt 1: iconv (not available)
python script.py 2>&1 | iconv -f UTF-8 -t ASCII//TRANSLIT

# Attempt 2: sed replacement (didn't work - literal characters in file)
cat script.py | sed 's/\\u2713/[OK]/g' | python

# Attempt 3: PowerShell replace (didn't work - unicode literals in source)
(Get-Content script.py) -replace '✓','OK' | Set-Content temp.py
```

### Solutions

#### Solution 1: Set Environment Variable (RECOMMENDED)

Add to build scripts:
```powershell
# At start of script
$env:PYTHONIOENCODING = 'utf-8'

# Then run Python
python script.py
```

This tells Python to use UTF-8 for input/output instead of cp1252.

#### Solution 2: Change Console Code Page

Before running Python:
```powershell
# Change console to UTF-8
chcp 65001

# Run Python
python script.py

# Restore (optional)
chcp 1252
```

#### Solution 3: Avoid Unicode in Output (FALLBACK)

For maximum compatibility, avoid Unicode characters in Python print statements:
```python
# [FAIL] BAD: Unicode characters
print('\u2713 Success')
print('[OK] Done')

# [OK] GOOD: ASCII only
print('[OK] Success')
print('[DONE] Done')
```

### Build Script Integration

Update `build-windows.ps1`:
```powershell
# At script start
param(
    [switch]$RunAfterBuild = $true
)

# Set UTF-8 encoding for Python scripts
$env:PYTHONIOENCODING = 'utf-8'

# Rest of script...
```

Update `build-with-secrets.ps1`:
```powershell
# At script start
$env:PYTHONIOENCODING = 'utf-8'

# Rest of script...
```

---

## PowerShell Best Practices

### Proper Path Quoting

```powershell
# [OK] GOOD: Quote paths with spaces
cd "D:\Data\Harold\github\spamfilter-multi"

# [FAIL] BAD: No quotes
cd D:\Data\Harold\github\spamfilter-multi  # Error: multiple arguments
```

### Command Chaining

```powershell
# [OK] GOOD: Use semicolons or separate commands
cd "D:\path"
flutter test

# [OK] ALSO GOOD: Semicolon separator
cd "D:\path"; flutter test

# [FAIL] BAD: Mixing shell syntaxes
cd "D:\path" && flutter test  # && is bash syntax
```

### Process Management

```powershell
# Kill process by name
Stop-Process -Name "spam_filter_mobile" -Force -ErrorAction SilentlyContinue

# Find process
Get-Process | Where-Object {$_.ProcessName -like "*spam_filter*"}

# Wait before continuing
Start-Sleep -Seconds 2
```

### Executing Python Scripts

```powershell
# [OK] RECOMMENDED: Set encoding first
$env:PYTHONIOENCODING = 'utf-8'
python script.py

# [OK] ALTERNATIVE: Inline Python (avoids file encoding)
python -c "print('Hello from Python')"

# [OK] HEREDOC for multi-line Python (avoids unicode issues)
python << 'PYEOF'
# Python code here (no unicode output)
import sys
print('ASCII only output')
PYEOF
```

---

## Build Script Usage

### Windows Desktop Build

**Always use** `build-windows.ps1` (not `flutter build windows` directly):

```powershell
cd mobile-app/scripts

# Build and run
.\build-windows.ps1

# Build without running
.\build-windows.ps1 -RunAfterBuild:$false
```

**Why**: Script injects secrets from `secrets.dev.json` automatically.

### Android Build

```powershell
cd mobile-app/scripts

# Build release APK
.\build-apk.ps1

# Build debug and install to emulator
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator

# Launch emulator and run
.\build-with-secrets.ps1 -BuildType debug -Run
```

### Script Parameters

| Script | Parameters | Purpose |
|--------|-----------|---------|
| `build-windows.ps1` | `-RunAfterBuild:$false` | Build without running |
| `build-with-secrets.ps1` | `-BuildType debug\|release` | Android build type |
| `build-with-secrets.ps1` | `-InstallToEmulator` | Install to emulator |
| `build-with-secrets.ps1` | `-Run` | Launch app after build |
| `build-with-secrets.ps1` | `-StartEmulator` | Start emulator first |
| `build-with-secrets.ps1` | `-EmulatorName "name"` | Specific emulator |
| `build-with-secrets.ps1` | `-SkipUninstall` | Don't uninstall old version |

---

## Common Error Scenarios

### Scenario 1: Bash with Windows Path

**Error**:
```
/usr/bin/bash: line 1: cd: too many arguments
```

**Cause**: Using Windows path syntax in bash:
```bash
cd /d "D:\Data\Harold\..."  # /d is cmd.exe only
```

**Fix**: Use PowerShell
```powershell
cd "D:\Data\Harold\github\spamfilter-multi"
```

### Scenario 2: Unicode in Python Output

**Error**:
```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2713'
```

**Cause**: Python printing Unicode characters to Windows console

**Fix**: Set environment variable
```powershell
$env:PYTHONIOENCODING = 'utf-8'
python script.py
```

### Scenario 3: PowerShell Cmdlets in Bash

**Error**:
```
/usr/bin/bash: line 1: Get-Process: command not found
```

**Cause**: Trying to use PowerShell cmdlets in bash

**Fix**: Use PowerShell or translate to bash
```powershell
# PowerShell (recommended)
Get-Process | Where-Object {$_.Name -like "*spam*"}
```

```bash
# Bash equivalent
ps aux | grep 'spam'
```

### Scenario 4: Build Executable Locked

**Error**:
```
LINK : fatal error LNK1104: cannot open file '...\spam_filter_mobile.exe'
```

**Cause**: App is still running from previous build

**Fix**: Stop process first
```powershell
Stop-Process -Name "spam_filter_mobile" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
.\build-windows.ps1
```

### Scenario 5: Backslashes in Bash File Paths

**Error**:
```bash
wc -l D:\Data\Harold\...\file.md
wc: 'D:DataHarold...file.md': No such file or directory
```

**Cause**: Bash interprets `\` as escape character, not path separator

**Fix**: Use forward slashes or WSL paths
```bash
# Option 1: Forward slashes (works in bash on Windows)
wc -l "D:/Data/Harold/github/spamfilter-multi/docs/file.md"

# Option 2: WSL path
wc -l "/mnt/d/Data/Harold/github/spamfilter-multi/docs/file.md"

# Option 3: Use PowerShell
Get-Content "D:\Data\Harold\...\file.md" | Measure-Object -Line
```

---

## Quick Reference

### Recommended Shell by Task

| Task Type | Shell | Example |
|-----------|-------|---------|
| Git operations | Bash | `git status` |
| Flutter build | PowerShell | `flutter build windows` |
| Path navigation | PowerShell | `cd "D:\path"` |
| Process management | PowerShell | `Stop-Process -Name "app"` |
| File search (relative) | Bash | `find . -name "*.dart"` |
| Build scripts | PowerShell | `.\build-windows.ps1` |
| Python scripts | PowerShell + UTF-8 | `$env:PYTHONIOENCODING='utf-8'; python script.py` |

### Environment Setup Checklist

```powershell
# At start of development session
cd "D:\Data\Harold\github\spamfilter-multi"

# Set UTF-8 encoding for Python
$env:PYTHONIOENCODING = 'utf-8'

# Verify git status
git status

# Ready to work
```

### WSL Path Conversion

| Windows Path | WSL Path |
|--------------|----------|
| `C:\Users\kimme\...` | `/mnt/c/Users/kimme/...` |
| `D:\Data\...` | `/mnt/d/Data/...` |
| `.` (current) | `.` (same in both) |

**Pattern**: `C:\path\to\file` → `/mnt/c/path/to/file` (lowercase drive letter)

---

## Version History

**Version**: 1.0
**Date**: February 1, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Consolidates**:
- WINDOWS_BASH_COMPATIBILITY.md (Sprint 6)
- Unicode encoding fixes (Sprint 10 & 11 feedback)
- PowerShell best practices (Sprint 11)
- Build script documentation

**Updates**:
- 1.0 (2026-02-01): Initial comprehensive guide combining all Windows development topics
