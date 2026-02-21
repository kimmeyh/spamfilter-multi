# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## FIRST: Run Startup Check

**BEFORE doing any work**, you MUST run `/startup-check` to verify the environment and restore any saved context.

This skill will:
1. Verify git status and branch
2. Verify GitHub CLI is working
3. Check for saved memory from previous session and restore it
4. Report readiness status

If any check fails, **STOP and resolve with user before accepting work**.

**Note on Firebase MCP**: This project uses Firebase only for Android Gmail OAuth registration (not backend services like Firestore/Auth/Storage). The Firebase MCP server is not needed for current development workflows. It can be added later if Firebase backend services are integrated.

## CRITICAL: Master Sprint Plan Location

**DO NOT LOSE THIS REFERENCE** - The master plan for all sprints is stored in:

**Repository File**: `docs/ALL_SPRINTS_MASTER_PLAN.md`
**Full Path**: `D:\Data\Harold\github\spamfilter-multi\docs\ALL_SPRINTS_MASTER_PLAN.md`
**GitHub URL**: `https://github.com/kimmeyh/spamfilter-multi/blob/develop/docs/ALL_SPRINTS_MASTER_PLAN.md`

**Contents**:
- Complete specifications for all sprints
- Sprint dependencies and critical path
- Task breakdown by model (Haiku/Sonnet/Opus)
- Effort estimates (actual vs estimated from previous sprints)
- Risk management and contingency plans
- Success criteria for sprint completion

**When You Need This**:
- Starting a new sprint (find Sprint X section)
- Creating detailed sprint plan (copy and expand from master)
- Planning dependencies (check cross-sprint dependency graph)
- Assigning models to tasks (reference model assignment by sprint)
- Understanding overall sprint roadmap

**Important**:
1. This document is IN THE REPOSITORY (not in Claude's plan storage)
2. It persists across conversations (unlike `.claude/plans/`)
3. Update it after each sprint completes (add actual duration, lessons learned, update future Sprint plans - as needed)
4. **BEFORE EVERY SPRINT**: Reference this document as very first step
   - Read this document before starting Phase 1: Sprint Kickoff & Planning
   - Check for updates from previous sprint retrospective
   - Verify Sprint N section includes actual vs estimated durations
   - Update the master plan with any lessons learned before planning next sprint
   - Then proceed to SPRINT_EXECUTION_WORKFLOW.md Phase 1
5. If you cannot find it, search: `find . -name "ALL_SPRINTS_MASTER_PLAN.md"` or `grep -r "sprint" docs/ALL_SPRINTS_MASTER_PLAN.md`

## Developer information
1. Using Windows 11 HP Omen with all current Windows Updates installed
2. When looking for information about the user, should always use Windows environment variables (however username is kimme as in C:\users\kimme)

## Development Workflow

Give Claude verification loops for 2-3x quality improvement:

1. Make changes
3. Run tests
4. Lint before committing
5. Commit changes and sync to repository
5. Before creating PR: run full lint and test suite

## [WARNING] CRITICAL: Pull Request Branch Policy

**RULE: All Claude Code PRs must target the `develop` branch, NEVER `main`.**

### Branch Hierarchy

```
main (release branch - ONLY user creates PRs to main)
  ^ (user merges stable develop)
develop (integration branch - ALL Claude Code PRs target this)
  ^ (Claude creates PRs from feature branches)
feature/YYYYMMDD_Sprint_N (feature branches - temporary, deleted after merge)
```

### Policy Details

- **Claude Code**: Creates PRs from `feature/YYYYMMDD_Sprint_N` -> `develop`
- **User**: Creates PRs from `develop` -> `main` when ready for release
- **Why**:
  - `develop` is the integration branch for all sprint work
  - `main` is the stable release branch for production versions
  - Only user can approve merges to `main` (maintains clear release control)
- **Enforcement**: All PR links in documentation and workflows reference `develop`

### Example

```bash
# [OK] CORRECT: Claude creates PR to develop
git push origin feature/20260126_Sprint_5
# Then create PR: feature/20260126_Sprint_5 -> develop

# [FAIL] INCORRECT: Claude creates PR to main
git push origin feature/20260126_Sprint_5
# Then create PR: feature/20260126_Sprint_5 -> main  (WRONG!)

# [OK] USER ONLY: User merges develop to main for release
git checkout main
git pull origin main
git merge develop
# Then create PR for release notes if needed
```

### Reference

- See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 6.3 for PR creation instructions
- See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 7.1 for Windows build verification before approval

## Things Claude Should NOT Do

<!-- Add mistakes Claude makes so it learns -->

- Don't skip error handling
- Don't commit without running tests first
- Don't make breaking changes without discussion
- Don't use Edit tool without first using Read tool on that file in the SAME conversation turn
- Don't assume file content from earlier reads - always re-read before editing after any significant work or context compaction
- Don't use Linux-only tools on Windows (see Windows Tool Restrictions below)

## Windows Tool Restrictions

**CRITICAL**: This is a Windows development environment. Many Linux tools are NOT available.

**DO NOT USE** these tools (not installed):
- `jq` - Use `gh --jq` flag or PowerShell `ConvertFrom-Json` instead
- `sed` - Use the Edit tool instead
- `awk` - Use PowerShell or the Grep tool instead
- `grep` (bash) - Use the Grep tool instead
- `find` (bash) - Use the Glob tool instead
- `cat` - Use the Read tool instead

**ALWAYS USE** native alternatives:
```powershell
# Instead of: gh issue view 123 --json body | jq '.body'
# Use: gh issue view 123 --json body --jq '.body'

# Instead of: cat file.txt | grep pattern
# Use: Grep tool with pattern and file path

# Instead of: find . -name "*.dart"
# Use: Glob tool with pattern "**/*.dart"
```

**GitHub CLI has built-in JSON processing**:
- `gh issue view 123 --json title,body` - returns JSON
- `gh issue view 123 --json title --jq '.title'` - extracts field
- `gh pr list --json number,title` - list with specific fields

## Development Philosophy: Co-Lead Developer Collaboration

**CRITICAL**: Treat the user as a co-lead developer, not a client. This means:

1. **Think Out Loud**: Share your investigation process, reasoning, and hypotheses before taking action
   - Explain what you're checking and why before running commands
   - Narrate your detective work when debugging ("I'm checking X because Y might be causing Z")
   - Share findings immediately rather than silently making fixes

2. **Collaborative Problem-Solving**: Debugging is a team effort
   - When you have multiple approaches, present options and discuss trade-offs
   - Ask for input when facing architectural decisions
   - Acknowledge when the user's insight completes your investigation (e.g., suspecting .gitignore issues)

3. **Full Transparency**: Provide complete information about what you're doing
   - Don't shortcut analysis - show the full picture
   - Explain both what you found AND what you did not find
   - Share context about why something matters

4. **Mutual Respect**: Together you are better than either individually
   - The user brings domain knowledge, project history, and strategic vision
   - You bring pattern recognition, systematic analysis, and code generation
   - Best results come from combining both perspectives

5. **Communication Style**:
   - Explain your thought process before and during actions
   - Use "Let me check..." or "I'm investigating..." instead of silent tool usage
   - Share intermediate findings, not just final conclusions

6. **Execution Autonomy During Sprints**: Sprint plan approval authorizes all task execution
   - **CRITICAL**: When user approves sprint plan (Phase 3), this pre-approves ALL tasks through Phase 7 (Sprint Review)
   - **DO NOT** ask for approval on individual tasks during execution
   - **DO NOT** ask before starting each task (learned in Sprint 6, reinforced in Sprint 13)
   - **DO NOT** stop for implementation decisions - make best engineering judgment and document
   - Work continuously and autonomously until: blocked/escalated, all tasks complete, or sprint review requested
   - This autonomy is core to sprint efficiency - per-task approvals add overhead without benefit
   - If mid-sprint changes needed: Document scope change, get re-approval, adjust plan and resume
   - See `docs/SPRINT_STOPPING_CRITERIA.md` for EXACT criteria when to stop working and why
   - **Sprint Stopping Criteria**: ONLY stop for these reasons:
     1. All tasks complete (Criterion 1)
     2. Blocked on external dependency (Criterion 2)
     3. User requests scope change (Criterion 3)
     4. Critical bug found (Criterion 4)
     5. User requests early review (Criterion 5)
     6. Sprint review complete (Criterion 6)
     7. Fundamental design failure (Criterion 7)
     8. Context limit approaching (Criterion 8)
     9. Time limit reached (Criterion 9)
   - **NOT valid stopping reasons**: Implementation choices, approach uncertainty, minor code style, single test failure
   - **Reference**: SPRINT_EXECUTION_WORKFLOW.md Phase 3.7 and SPRINT_STOPPING_CRITERIA.md

**Example of Good Co-Lead Collaboration**:
```
[BAD] [Silently runs git status, finds files missing, edits .gitignore, reports "Fixed!"]

[GOOD] "I'm checking git status to see which files are tracked... Interesting - the
mobile-app/lib/ files are not showing up. You opened .gitignore - good thinking! Let me
search for 'lib/' in there... Found it! Line 81 has a broad 'lib/' exclusion that's
catching both Python lib directories AND our Flutter source code. This is a mixed-repo
issue. Should I make it more specific to only exclude 'Archive/desktop-python/lib/'?"
```

### Sprint Execution Autonomy - Common Mistakes

**LEARN FROM PAST MISTAKES**: Do NOT stop for these reasons:SPRINT_CHECKLIST

| Situation | WRONG Behavior | CORRECT Behavior |
|-----------|---------------|------------------|
| Implementation choice | Stop and ask: "Should I use method A or B?" | Make best judgment, document, continue |
| Approach uncertainty | Stop and ask: "Is this the right approach?" | Implement, test, iterate if needed |
| Method signature change | Stop and ask: "Should I add parameter X?" | Add if needed for acceptance criteria, continue |
| Refactor vs extend | Stop and ask: "Should I refactor or extend?" | Choose based on code smell, document, continue |
| Single test failure | Stop and report | Fix the test, continue |
| Code style issue | Stop and ask | Fix it or note as tech debt, continue |
| Feature seems incomplete | Stop and verify | Complete acceptance criteria, continue |

**Remember**: Sprint plan approval = blanket approval for ALL implementation decisions needed to meet acceptance criteria. Only stop for the 9 criteria in SPRINT_STOPPING_CRITERIA.md.

## Sprint Planning and Development Workflow

**CRITICAL**: All development follows sprint-based planning with model-tiered task execution.

### Sprint Execution Documentation

All sprint work references the **SPRINT EXECUTION docs** - the authoritative set of sprint process documentation:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

**Quick Reference**: These 11 documents form the complete sprint execution knowledge base. Reference them frequently during sprint work.

### Sprint Structure
- **Sprints**: Time-boxed iterations focusing on one key enhancement
- **Cards**: GitHub issues representing sprint work items
- **Tasks**: Sub-tasks within cards, assigned by model capability

### Model Tiering Strategy
Work flows through models by complexity:
- **Haiku**: Straightforward implementation, bug fixes, tests, documentation
- **Sonnet**: Architectural decisions, complex refactoring, multi-file changes
- **Opus**: Deep debugging, performance optimization, critical path features

Claude determines model assignment using the `/plan-sprint` skill (see below).

### Detailed Process
See `docs/SPRINT_PLANNING.md` for complete sprint planning methodology, ceremonies, and GitHub issue workflows.

### Important: Sprints Replace Phases
As of January 24, 2026, **sprints replace the previous phase-based development model**. Historical references to "Phase 3.1", "Phase 3.2", etc., remain as archived milestones. All current and future work is organized into numbered sprints (Sprint 1, Sprint 2, etc.) following the methodology documented in `docs/SPRINT_PLANNING.md`. GitHub issues are labeled with `sprint` and numbered sequentially.

## Coding Style Guidelines

### Documentation and Comments
- **No contractions**: Use "do not" instead of "don't", "does not" instead of "doesn't", "cannot" instead of "can't", etc.
- **Clarity over brevity**: Write clear, complete sentences in documentation
- **Use Logger, not print()**: Production code (`lib/`) must use `Logger` for all logging. Test files (`test/`) may use `print()`.  Exception: unit and integration tests (ex. *_test.dart files)
- **No emojis**: Do not use emojis or special Unicode characters in code or documentation unless explicitly for customer-facing UI/UX
  - Use text alternatives in brackets: [OK] [FAIL] [WARNING] [PENDING] [NEW] [BUG] [STOP]
  - Exception: Customer-facing UI can use emojis when appropriate for user experience
  - Rationale: Emojis do not render consistently across terminals and are harder to search/grep

### Example
```dart
// [BAD] Don't use this pattern, it won't work correctly
// [GOOD] Do not use this pattern, it will not work correctly

// [BAD] Can't be null here
// [GOOD] Cannot be null here

// [BAD] Status: ✅ Complete
// [GOOD] Status: [OK] Complete

// [BAD] Warning: ⚠️ Check this
// [GOOD] Warning: [WARNING] Check this
```

## Project Overview

Cross-platform email spam filtering application built with 100% Flutter/Dart for all platforms (Windows, macOS, Linux, Android, iOS). The app uses IMAP/OAuth protocols to support multiple email providers (AOL, Gmail, Yahoo, Outlook.com, ProtonMail) with a single codebase and portable YAML rule sets.

**Current Status**: Sprint 17 complete (Feb 2026) - 977 tests passing, sprint-based development model.

**For detailed status**: See `CHANGELOG.md` for feature history and `docs/ALL_SPRINTS_MASTER_PLAN.md` for sprint roadmap and completion records.

## Repository Structure

```
spamfilter-multi/
├── mobile-app/           # Flutter application (all 5 platforms)
│   ├── lib/
│   │   ├── core/        # Business logic (provider-agnostic)
│   │   ├── adapters/    # Provider implementations (email, storage, auth)
│   │   └── ui/          # Flutter screens and widgets
│   ├── test/            # Unit, integration, and smoke tests
│   ├── scripts/         # Build automation scripts
│   └── android/         # Android-specific configuration
├── archive/
│   └── desktop-python/  # Original Outlook desktop app (reference only)
├── memory-bank/         # Development planning and documentation
├── rules.yaml           # Active spam filtering rules (regex, shared)
└── rules_safe_senders.yaml  # Active safe sender whitelist (regex, shared)
```

## Common Commands

**IMPORTANT - Development Environment**: This project uses **PowerShell** as the primary shell environment on Windows. All commands, scripts, and automation should use PowerShell syntax and cmdlets. Bash/sh commands should be avoided unless absolutely necessary.

**CRITICAL - Execution Context**: When running PowerShell commands programmatically (e.g., via automation tools), execute them directly in PowerShell context, NOT wrapped in Bash. Wrapping PowerShell in Bash (`bash -c "powershell ..."`) loses VSCode terminal environment variables and Flutter toolchain context, causing failures. Always use native PowerShell execution.

### Development

```powershell
# Navigate to Flutter app
cd mobile-app

# Install dependencies
flutter pub get

# Run app on connected device/emulator
flutter run

# Run all tests
flutter test

# Analyze code quality
flutter analyze
```

### Windows Development

**CRITICAL**: Always use `build-windows.ps1` for Windows builds and tests (not `flutter build windows` directly):

```powershell
cd mobile-app/scripts
.\build-windows.ps1               # Clean build, inject secrets, run app
.\build-windows.ps1 -RunAfterBuild:$false  # Build without running
```

### Android Development

```powershell
cd mobile-app/scripts

# Build release APK
.\build-apk.ps1

# Build with secrets and install to emulator
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator"

# Launch emulator and run
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -Run"
```

### Testing

```powershell
cd mobile-app

# Run all tests (81 tests)
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator"

# Run specific test file
flutter test test/unit/rule_evaluator_test.dart

# Run with coverage
flutter test --coverage
```

## Architecture

For detailed architecture documentation, see `docs/ARCHITECTURE.md`.

**Quick Summary**:
- **Provider-Agnostic Core**: Business logic independent of email providers
- **Adapter Pattern**: Common `EmailProvider` interface for Gmail, IMAP, Outlook
- **State Management**: Provider pattern for `RuleSetProvider` and `EmailScanProvider`
- **Platform-Agnostic Storage**: `AppPaths` supports all 5 platforms (Windows, macOS, Linux, Android, iOS)

**Key Components**:
- **Models**: EmailMessage, RuleSet, SafeSenderList, EvaluationResult
- **Services**: RuleEvaluator, PatternCompiler, YamlService, EmailScanner
- **Adapters**: GmailApiAdapter, GenericImapAdapter, GoogleAuthService
- **Providers**: RuleSetProvider, EmailScanProvider

For complete component details, data flow diagrams, and design patterns, see `docs/ARCHITECTURE.md`.

## YAML Rule Format

For complete YAML specification, see `docs/RULE_FORMAT.md`.

**Quick Summary**:
- All rules use **regex patterns only** (legacy wildcard mode removed 11/10/2025)
- **rules.yaml**: Spam filtering rules with conditions, actions, exceptions
- **rules_safe_senders.yaml**: Whitelist of trusted senders (bypass all rules)

**YAML Export Invariants**: Lowercase, trimmed, deduplicated, sorted, single quotes, timestamped backups

**Quick Pattern Reference**:
```yaml
# Block domain + subdomains
header: ["@(?:[a-z0-9-]+\\.)*spam\\.com$"]

# Allow domain + subdomains
safe_senders: ["^[^@\\s]+@(?:[a-z0-9-]+\\.)*trusted\\.com$"]
```

For complete structure, pattern conventions, examples, and validation rules, see `docs/RULE_FORMAT.md`.

## OAuth and Secrets Management

### CRITICAL: Never Commit Secrets

**Files excluded by .gitignore** (NEVER commit):
- `mobile-app/secrets.dev.json` - Build-time secrets (Gmail client ID/secret, AOL credentials)
- `mobile-app/android/app/google-services.json` - Firebase configuration for Android
- `client_secret_*.json` - OAuth client secret files from Google Cloud Console

### Secrets Configuration

1. **Copy template**: `cp mobile-app/secrets.dev.json.template mobile-app/secrets.dev.json`
2. **Fill credentials**:
   - **Gmail**: OAuth credentials from Google Cloud Console
   - **AOL**: Email and app password from AOL account settings
3. **Build with secrets**: Use `scripts/build-with-secrets.ps1` (auto-injects `--dart-define-from-file`)

### Gmail OAuth Setup

#### Android
- Requires Firebase project with Android app registered
- Must add SHA-1 fingerprint to Firebase Console
- Run `mobile-app/android/get_sha1.bat` to extract fingerprint
- Download `google-services.json` from Firebase Console -> `mobile-app/android/app/google-services.json`
- See `ANDROID_GMAIL_SIGNIN_QUICK_START.md` for complete setup

#### Windows Desktop
- Uses Desktop OAuth client ID from Google Cloud Console
- Requires client secret (must be in `secrets.dev.json`)
- Loopback redirect URI: `http://localhost:8080/oauth/callback`
- See `WINDOWS_GMAIL_OAUTH_SETUP.md` for complete setup

## Platform-Specific Considerations

### Android
- Emulator must use "Google APIs" image (NOT AOSP) for Google Sign-In
- Norton Antivirus "Email Protection" may intercept IMAP TLS connections (disable if needed)
- Multi-account support via unique accountId: `{platform}-{email}`

### Windows
- Always use `build-windows.ps1` script (not `flutter build windows` directly)
- Desktop OAuth requires browser-based flow with loopback redirect
- Secrets injected at build time via `--dart-define-from-file=secrets.dev.json`
- **App Data Directory**: `C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\`
- **Database Location**: `C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\spam_filter.db`
  - Rules database (imported from YAML, managed via UI)
  - Scan results history
  - App settings and configuration
- **Rules Directory**: `C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\rules\`
- **Credentials Directory**: `C:\Users\{username}\AppData\Roaming\com.example\spam_filter_mobile\credentials\`

### iOS/macOS/Linux
- Not yet validated but architecture supports all platforms
- Storage uses `AppPaths` for platform-specific directories

## Testing Strategy

**Total Tests**: 977 passing (as of Sprint 17, Feb 2026). Run `flutter test` to verify current count.

### Test Organization
```
mobile-app/test/
├── unit/          # Unit tests for models and services
├── integration/   # Integration tests for adapters and workflows
├── adapters/      # Adapter-specific tests
├── core/          # Core logic tests
├── fixtures/      # Test data and mock responses
└── smoke_test.dart  # Smoke test for app initialization
```

### Running Tests
```powershell
flutter test                                    # All tests
flutter test test/unit/rule_evaluator_test.dart # Specific file
flutter test --coverage                         # With coverage
```

## Common Issues and Fixes

For comprehensive troubleshooting, see `docs/TROUBLESHOOTING.md`.

**Quick fixes**:
- **Gmail Sign-In Cancelled**: Add SHA-1 fingerprint to Firebase Console (see `ANDROID_GMAIL_SIGNIN_QUICK_START.md`)
- **Norton Blocks IMAP**: Disable "Email Protection" in Norton Settings
- **Windows OAuth Fails**: Ensure `secrets.dev.json` contains `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`
- **Git Not Tracking Files**: Fixed Dec 2025 - update `.gitignore`

## Development Workflow

1. **Setup**: Follow `mobile-app/NEW_DEVELOPER_SETUP.md` for validated Windows 11 setup
2. **Secrets**: Configure `secrets.dev.json` with Gmail and/or AOL credentials
3. **Build**:
   - Windows: `.\scripts\build-windows.ps1`
   - Android: `.\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
4. **Test**: `flutter test` (verify all 185 tests passing)
5. **Analyze**: `flutter analyze` (ensure 0 issues)

## Changelog Policy

This project follows [Keep a Changelog](https://keepachangelog.com/) conventions.

### Adding Entries (During Development)

**CHANGELOG.md** should be updated with each commit that introduces user-facing changes:

1. **When to Update**: Update CHANGELOG.md in the same commit as the code changes (not after PR merge)
2. **Format**: `- **type**: Description (Issue #N)` where type is:
   - `feat`: New feature or enhancement
   - `fix`: Bug fix
   - `chore`: Maintenance, refactoring, dependencies
   - `docs`: Documentation only changes
   - `test`: Adding or updating tests
3. **Location**: Add entries under `## [Unreleased]` section, grouped by date (newest first)
4. **Issue References**: Always include GitHub issue number when applicable
5. **Commit Together**: Stage CHANGELOG.md with the related code changes in a single commit

**Example Entry**:
```markdown
### 2026-01-12
- **feat**: Update Results screen to show folder - subject - rule format (Issue #47)
- **feat**: Add AOL Bulk/Bulk Email folder recognition as junk folders (Issue #48)
```

### Releasing (After PR Merge to main)

This project uses **GitFlow**: feature branches -> `develop` -> `main`

- **PRs to `develop`**: Entries stay in `[Unreleased]` - these are integration builds
- **PRs to `main`**: Move entries from `[Unreleased]` to a versioned release - these are production releases

When `develop` is merged to `main`, create a versioned release:

1. **Check for merged PRs to develop**: Review what is included since last release
   ```powershell
   # PRs merged to develop since a date
   gh pr list --state merged --base develop --json number,title,mergedAt

   # Commits on develop not yet on main
   git rev-list --count origin/main..origin/develop
   ```

2. **Create version section**: Move relevant `[Unreleased]` entries to a new version heading
   ```markdown
   ## [1.0.0] - 2026-01-12
   ### 2026-01-12
   - **feat**: Update Results screen format (Issue #47)
   ...

   ## [Unreleased]
   (empty or new entries since release)
   ```

3. **Version numbering**: Follow [Semantic Versioning](https://semver.org/)
   - **MAJOR**: Breaking changes or major milestones (Phase releases)
   - **MINOR**: New features (feat)
   - **PATCH**: Bug fixes (fix)

4. **Update Version History**: Add summary to the `## Version History` section at bottom of CHANGELOG.md

5. **Link versions**: Add comparison links at bottom of CHANGELOG.md
   ```markdown
   [1.0.0]: https://github.com/kimmeyh/spamfilter-multi/compare/v0.9.0...v1.0.0
   [Unreleased]: https://github.com/kimmeyh/spamfilter-multi/compare/v1.0.0...HEAD
   ```

### Best Practices

- **Human-readable**: Write for users, not developers. Focus on "what changed" not "how"
- **Group by date**: Keep daily entries together for easy scanning
- **Do not delete**: Never remove entries; move them to versioned sections
- **PR description**: Use CHANGELOG entries as basis for PR descriptions

## Known Limitations

- **Outlook.com OAuth**: Deferred (MSAL integration incomplete)
- **Production Delete Mode**: Not yet validated with spam-heavy inbox (read-only mode tested)
- **iOS/macOS/Linux**: Not yet validated (architecture supports, testing pending)

## Issue Backlog

For current issue status, use GitHub Issues: `gh issue list --state open`

## Additional Resources

### Documentation Structure
```
spamfilter-multi/
├── 0*.md                     # Developer workflow files (DO NOT read or modify)
├── archive\                  # All archive files should be ignored unless specifically asked to read for reference (DO NOT read or modify)
├── CHANGELOG.md              # Feature/bug updates (newest first)
├── CLAUDE.md                 # Primary documentation (this file)
├── README.md                 # Project overview
├── docs/                     # Consolidated documentation
│   ├── OAUTH_SETUP.md        # Gmail OAuth for Android + Windows
│   ├── TROUBLESHOOTING.md    # Common issues and fixes
│   ├── ISSUE_BACKLOG.md      # Open issues and status
│   ├── ALL_SPRINTS_MASTER_PLAN.md    # Master plan for all future sprints and backlog items (features, issues, bugs...)
│   ├── SPRINT_PLANNING.md    # Sprint planning methodology
│   ├── SPRINT_EXECUTION_WORKFLOW.md # Step-by-step sprint execution checklist
│   ├── SPRINT_CHECKLIST.md   # Single-page sprint execution checklist
│   ├── SPRINT_STOPPING_CRITERIA.md # When/why to stop working (NEW - Sprint 6)
│   ├── WINDOWS_DEVELOPMENT_GUIDE.md # Windows development (bash, Unicode, PowerShell, builds)
│   └── sprints/              # Per-sprint documentation (plans, retrospectives, summaries)
│       ├── SPRINT_N_PLAN.md          # Created at sprint start (Phase 3)
│       ├── SPRINT_N_RETROSPECTIVE.md # Created at sprint end (Phase 7)
│       └── SPRINT_N_SUMMARY.md       # Created during next sprint planning (Phase 3.2.1)
├── mobile-app/
│   ├── README.md             # App-specific quick start
│   └── docs/
│       └── DEVELOPER_SETUP.md  # New developer onboarding (Windows 11)
└── scripts/
    └── email-rule-tester-mcp/  # Custom MCP server
```

### Quick Reference & Troubleshooting
- **QUICK_REFERENCE.md**: Command cheat sheet and skill reference
- **WINDOWS_DEVELOPMENT_GUIDE.md**: Windows development environment (bash/PowerShell, Unicode encoding, build scripts)
- **SPRINT_STOPPING_CRITERIA.md**: When and why to stop working during sprints
- **CLAUDE_CODE_SETUP_GUIDE.md**: MCP server, skills, hooks setup (if referenced)

### Claude Code Tooling
- **Custom MCP Server**: `scripts/email-rule-tester-mcp/`
- **Validation Scripts**: `scripts/validate-yaml-rules.ps1`, `scripts/test-regex-patterns.ps1`
- **Skills**:
  - `/startup-check` - Environment health check and memory restore
  - `/phase-check` - Sprint phase transition checkpoint (verify phase complete, preview next phase)
  - `/plan-sprint` - Sprint planning with model assignments
  - `/full-test` - Run all Flutter tests and analyze code quality
  - `/memory-save` and `/memory-restore` - Save/restore sprint context across sessions

### Archives (gitignored)
- **Archive/**: Historical docs, legacy Python desktop app, completed phase reports
