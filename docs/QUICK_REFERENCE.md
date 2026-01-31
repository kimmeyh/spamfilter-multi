# Quick Reference: Critical Files & Directories

**Purpose**: Fast lookup for commonly-used paths, commands, and resources during sprint execution.

**Last Updated**: January 30, 2026

---

## Project Structure

| Component | Path |
|-----------|------|
| **Project Root** | `D:\Data\Harold\github\spamfilter-multi` |
| **Flutter App** | `D:\Data\Harold\github\spamfilter-multi\mobile-app` |
| **Scripts** | `D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts` |
| **Documentation** | `D:\Data\Harold\github\spamfilter-multi\docs` |
| **Tests** | `D:\Data\Harold\github\spamfilter-multi\mobile-app\test` |
| **Claude Config** | `D:\Data\Harold\github\spamfilter-multi\.claude` |
| **Archive** | `D:\Data\Harold\github\spamfilter-multi\archive` |

---

## Critical Files

| Purpose | Path | Notes |
|---------|------|-------|
| **Rules (Active)** | `rules.yaml` | Production spam filtering rules |
| **Safe Senders** | `rules_safe_senders.yaml` | Whitelist of trusted senders |
| **Secrets (Dev)** | `mobile-app\secrets.dev.json` | OAuth credentials (gitignored) |
| **Package Config** | `mobile-app\pubspec.yaml` | Flutter dependencies |
| **Claude Guide** | `CLAUDE.md` | Primary Claude Code documentation |
| **Changelog** | `CHANGELOG.md` | Version history and changes |
| **README** | `README.md` | Project overview |

---

## Build & Run Scripts

| Task | Script Path | Command | Notes |
|------|-------------|---------|-------|
| **Build Windows** | `scripts\build-windows.ps1` | `cd mobile-app/scripts && .\build-windows.ps1` | Clean build + secrets injection |
| **Run Windows** | `scripts\run-windows.ps1` | `cd mobile-app/scripts && .\run-windows.ps1` | Launch Windows app |
| **Build Android Debug** | `scripts\build-with-secrets.ps1` | `cd mobile-app/scripts && .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator` | Build APK with secrets |
| **Build APK Release** | `scripts\build-apk.ps1` | `cd mobile-app/scripts && .\build-apk.ps1` | Release APK |

---

## Logs & Monitoring

| Log Type | Command/Path | Filter/Notes |
|----------|--------------|--------------|
| **Android Logcat (All)** | `adb logcat -s flutter,System.err,AndroidRuntime,DEBUG` | Flutter + system errors |
| **Android Logcat (Filtered)** | `adb logcat -s flutter \| grep -E '\[EMAIL\]\|\[RULES\]\|\[EVAL\]\|\[ERROR\]\|\[SCAN\]'` | Keyword-based filtering |
| **Flutter Console** | Captured during `build-windows.ps1` or `run-windows.ps1` | Look for ERROR, WARNING |
| **Windows App** | Console output from app launch | Real-time app logs |

### Log Keyword Prefixes

| Category | Prefix | Example |
|----------|--------|---------|
| Email Operations | `[EMAIL]` | `[EMAIL] Fetched 50 messages from INBOX` |
| Rules | `[RULES]` | `[RULES] Loaded 250 rules from rules.yaml` |
| Rule Evaluation | `[EVAL]` | `[EVAL] Email matched rule 'SpamAutoDelete'` |
| Database | `[DB]` | `[DB] Migrated 250 rules to database` |
| Authentication | `[AUTH]` | `[AUTH] OAuth token refreshed` |
| Scanning | `[SCAN]` | `[SCAN] Processing 150 emails` |
| Errors | `[ERROR]` | `[ERROR] Failed to delete email` |
| Performance | `[PERF]` | `[PERF] Evaluation took 45ms` |

---

## Databases

| Platform | Path | Access Method |
|----------|------|---------------|
| **Windows** | `C:\Users\kimme\AppData\Roaming\spam_filter_mobile\databases\` | File explorer or code |
| **Android** | `/data/data/com.spamfilter.mobile_app/databases/` | `adb shell` or device file explorer |

**Runtime Path**: Use `AppPaths.getDatabasePath()` in code to get platform-specific database directory.

---

## Sprint Documentation

| Document | Path | Purpose |
|----------|------|---------|
| **Master Plan** | `docs\ALL_SPRINTS_MASTER_PLAN.md` | All 10 Phase 3.5 sprints, dependencies, estimates |
| **Execution Workflow** | `docs\SPRINT_EXECUTION_WORKFLOW.md` | Step-by-step sprint process (Phase 0-4.5) |
| **Stopping Criteria** | `docs\SPRINT_STOPPING_CRITERIA.md` | When/why to stop working (10 criteria) |
| **Sprint Planning** | `docs\SPRINT_PLANNING.md` | Planning methodology, ceremonies |
| **Retrospective Template** | `docs\SPRINT_RETROSPECTIVE_INTEGRATION.md` | Sprint review structure |

---

## Testing Documentation

| Document | Path | Purpose |
|----------|------|---------|
| **Manual Integration Tests** | `docs\MANUAL_INTEGRATION_TESTS.md` | Comprehensive test scenarios |
| **Test Directory** | `mobile-app\test\` | Unit, integration, adapter tests |

---

## Common Commands

### Git Operations

```bash
# Check repository status
git status --short

# Show current branch
git branch --show-current

# View recent commits
git log --oneline -5

# List open issues
gh issue list --label sprint --state open
```

### Flutter Development

```powershell
# Run all tests
cd mobile-app
flutter test

# Run specific test file
flutter test test/unit/rule_evaluator_test.dart

# Code analysis
flutter analyze

# Build for Windows
cd mobile-app/scripts
.\build-windows.ps1

# Build for Android
cd mobile-app/scripts
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
```

### Log Monitoring

```bash
# Android - Filter by keywords
adb logcat -s flutter | grep -E '\[EMAIL\]|\[RULES\]|\[ERROR\]'

# Android - Show only errors
adb logcat -s flutter | grep '\[ERROR\]'

# Android - Show rules + evaluation
adb logcat -s flutter | grep -E '\[RULES\]|\[EVAL\]'
```

```powershell
# Windows - Filter console output
flutter run | Select-String '\[ERROR\]'
```

---

## Architecture Reference

For detailed architecture information, see:
- **Architecture Overview**: `docs/ARCHITECTURE.md` (if exists)
- **Rule Format Spec**: `docs/RULE_FORMAT.md` (if exists)
- **Platform Setup**: Platform-specific setup in `CLAUDE.md`

---

## Troubleshooting

For common issues and fixes, see:
- **General Troubleshooting**: `docs/TROUBLESHOOTING.md`
- **Bash Compatibility**: `docs/WINDOWS_BASH_COMPATIBILITY.md`
- **OAuth Setup**: `docs/OAUTH_SETUP.md`

---

## Quick Lookup: By Task

| I Need To... | Command/Path |
|--------------|--------------|
| **Build Windows app** | `cd mobile-app/scripts && .\build-windows.ps1` |
| **Run all tests** | `cd mobile-app && flutter test` |
| **Check code quality** | `cd mobile-app && flutter analyze` |
| **View Android logs** | `adb logcat -s flutter,System.err,AndroidRuntime,DEBUG` |
| **Find spam rules** | `rules.yaml` |
| **Find safe senders** | `rules_safe_senders.yaml` |
| **Check database path** | Windows: `C:\Users\kimme\AppData\Roaming\spam_filter_mobile\databases\` |
| **Start new sprint** | Read `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 0-1 |
| **View sprint plan** | `docs/ALL_SPRINTS_MASTER_PLAN.md` |
| **Check when to stop** | `docs/SPRINT_STOPPING_CRITERIA.md` |

---

**Document Version**: 1.0
**Created**: January 30, 2026
**Machine-Readable Version**: `.claude/quick-reference.json`
