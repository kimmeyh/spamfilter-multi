# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## FIRST: How to run a sprint -- the SPRINT EXECUTION docs

**This file does not describe the sprint process. The sprint execution docs do, and they are authoritative.**
Read them; do not work from a summary. Where this file and a sprint doc differ, the sprint doc wins.
(Harold, 2026-10-23: AGENTS.md refers to the sprint execution docs for how to run a sprint. Copies of the process
in this file drifted out of date -- for example the PR draft rule -- so they were replaced with this list.)

Read in this order:
1. `.claude/sprint_status.json` -- the current sprint, phase, PR and next actions. Check that its branch matches
   `git branch --show-current` before trusting it.
2. `docs/SPRINT_RESUME_GUIDE.md` -- how to resume mid-sprint: phase definitions, decision classes, stopping
   criteria, the resume sequence.
3. `docs/ALL_SPRINTS_MASTER_PLAN.md` -- the master plan: backlog, priorities, last completed sprint. Read it
   before every sprint.
4. `docs/SPRINT_CHECKLIST.md` -- the one-page checklist. Open it at every phase boundary and walk it line by line.
5. `docs/SPRINT_EXECUTION_WORKFLOW.md` -- the step-by-step workflow, Phases 1-8: backlog refinement, planning,
   cards and the draft PR, execution, Manual Validation, the final code reviews, the retrospective, close-out,
   the release cycle. It also holds the Decision-Class Checkpoint Protocol, the Phase Auto-Advance rule and its
   enforcement window, and the Standing Approval Inventory.
6. `docs/SPRINT_PLANNING.md` -- planning method, card template, model assignment (cheapest tier first).
7. `docs/BACKLOG_REFINEMENT.md` -- the Phase 1 presentation format.
8. `docs/SPRINT_STOPPING_CRITERIA.md` -- the only 9 reasons to stop work mid-sprint.
9. `docs/SPRINT_RETROSPECTIVE.md` -- the retrospective template (4 roles x 14 categories).

Supporting docs: `docs/TESTING_STRATEGY.md`, `docs/QUALITY_STANDARDS.md`, `docs/TROUBLESHOOTING.md`,
`docs/ARCHITECTURE.md`, `docs/CHANGELOG_POLICY.md`, `docs/STORE_RELEASE_PROCESS.md`.

**Hooks do not run for you.** The process gates in `.claude/hooks/` (cards and draft PR, close-out, blind staging,
mutation lock, auto-advance) are Claude Code hooks. When you work in this repository they do not fire, so follow
the checklist steps they enforce by hand.

**Note on Firebase MCP**: This project uses Firebase only for Android Gmail OAuth registration (not backend services like Firestore/Auth/Storage). The Firebase MCP server is not needed for current development workflows.

## Developer information
1. Using Windows 11 HP Omen with all current Windows Updates installed
2. When looking for information about the user, should always use Windows environment variables (however username is kimme as in C:\users\kimme)

## Development Workflow

Give Codex verification loops for 2-3x quality improvement:

1. Make changes
3. Run tests
4. Lint before committing
5. Commit changes and sync to repository
5. Before creating PR: run full lint and test suite

## [WARNING] CRITICAL: Pull Request Branch Policy

**RULE: All Codex PRs must target the `develop` branch, NEVER `main`.**

### Branch Hierarchy

```
main (release branch - ONLY user creates PRs to main)
  ^ (user merges stable develop)
develop (integration branch - ALL Codex PRs target this)
  ^ (Codex creates PRs from feature branches)
feature/YYYYMMDD_Sprint_N (feature branches - temporary, deleted after merge)
```

### Policy Details

- **Codex**: Creates PRs from `feature/YYYYMMDD_Sprint_N` -> `develop`
- **User**: Creates PRs from `develop` -> `main` when ready for release
- **Why**:
  - `develop` is the integration branch for all sprint work
  - `main` is the stable release branch for production versions
  - Only user can approve merges to `main` (maintains clear release control)
- **Enforcement**: All PR links in documentation and workflows reference `develop`

### Example

```bash
# [OK] CORRECT: Codex creates PR to develop
git push origin feature/20260126_Sprint_5
# Then create PR: feature/20260126_Sprint_5 -> develop

# [FAIL] INCORRECT: Codex creates PR to main
git push origin feature/20260126_Sprint_5
# Then create PR: feature/20260126_Sprint_5 -> main  (WRONG!)

# [OK] USER ONLY: User merges develop to main for release
git checkout main
git pull origin main
git merge develop
# Then create PR for release notes if needed
```

### Default branch and the release step (Sprint 79, F288, 2026-10-14)

`develop` is the GitHub default branch since 2026-10-14. A sprint PR merged into `develop` therefore fires its
`Closes #N` keywords and closes the cards; close-out VERIFIES this and closes any card that did not close.
The release step is: PR `develop` -> `main`, merged by Harold (the owner), then tag the merge commit on `main`
`vX.Y.Z` (annotated) and push the tag. See `docs/STORE_RELEASE_PROCESS.md` Step 5 for the commands. CI runs on PRs
into `develop` only.

### Reference

- See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 6.3 for PR creation instructions
- See `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 7.1 for Windows build verification before approval

## Things Codex Should NOT Do

<!-- Add mistakes Codex makes so it learns -->

- Don't skip error handling
- Don't commit without running tests first
- Don't make breaking changes without discussion
- Don't use Edit tool without first using Read tool on that file in the SAME conversation turn
- Don't assume file content from earlier reads - always re-read before editing after any significant work or context compaction
- Don't use Linux-only tools on Windows (see Windows Tool Restrictions below)
- **Don't report a checklist section, phase, or close-out as complete without OPENING the checklist and walking it line by line in that same turn.** "I believe I did that" is not verification. Every line gets an explicit `DONE (<evidence>)` / `N/A (<why>)` / `NOT DONE -> doing it now`. (Sprint 50 escape: close-out reported complete with 5 issues open, `sprint_status.json` 15 sprints stale, and no next-sprint stub. Enforced by the `verify-closeout-complete` Stop hook.)
- **Don't treat a multi-part user request as a theme.** Enumerate every discrete ask before starting, and restate each ask with its status before ending the turn. A request with a terminal condition ("continue until X") is not satisfied by doing the first part well.

### Decision classes: STOP, surface, wait

Architecture, development and sprint-scope decisions are Harold's (Chief Architect, Chief Developer, Scrum Master).
Plan approval does not authorize them. Surface each one at the next natural break and wait. The rule, its
examples and the surfacing template are in `docs/SPRINT_EXECUTION_WORKFLOW.md` "Decision-Class Checkpoint
Protocol" and `docs/SPRINT_STOPPING_CRITERIA.md`.

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

6. **Sprint execution autonomy, phase auto-advance and stopping**: follow `docs/SPRINT_EXECUTION_WORKFLOW.md`
   (Phase 3.7, the Standing Approval Inventory, the Phase Auto-Advance rule and its enforcement window) and
   `docs/SPRINT_STOPPING_CRITERIA.md`. In short: after plan approval, execute the approved tasks without asking;
   stop only for the 9 stopping criteria.

**Example of Good Co-Lead Collaboration**:
```
[BAD] [Silently runs git status, finds files missing, edits .gitignore, reports "Fixed!"]

[GOOD] "I'm checking git status to see which files are tracked... Interesting - the
mobile-app/lib/ files are not showing up. You opened .gitignore - good thinking! Let me
search for 'lib/' in there... Found it! Line 81 has a broad 'lib/' exclusion that's
catching both Python lib directories AND our Flutter source code. This is a mixed-repo
issue. Should I make it more specific to only exclude 'Archive/desktop-python/lib/'?"
```

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

**Current Status**: Sprint 27 in progress (Mar 2026) - 977+ tests passing, sprint-based development model.

**For detailed status**: See `CHANGELOG.md` for feature history and `docs/ALL_SPRINTS_MASTER_PLAN.md` for planned work and sprint history.

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
.\build-windows.ps1                          # Dev build (default), run app
.\build-windows.ps1 -Environment prod        # Production build
.\build-windows.ps1 -RunAfterBuild:$false    # Build without running
```

### Production/Development Side-by-Side (ADR-0035)

Production (main branch) and development (feature/develop) builds coexist on the same machine:

```powershell
# Development (default) - uses MyEmailSpamFilter_Dev data directory
.\build-windows.ps1

# Production - uses MyEmailSpamFilter data directory
# Run from production worktree: D:\Data\Harold\github\spamfilter-multi-prod\
.\build-windows.ps1 -Environment prod
```

- **Dev builds**: data in `MyEmailSpamFilter_Dev\`, window title shows `[DEV]`
- **Prod builds**: data in `MyEmailSpamFilter\`, no suffix
- **Version**: dev = `0.5.3`, prod = `0.5.2` after Sprint 35 store release / Sprint 36 dev bump (dev always patch+1)
- **Secrets**: dev uses `secrets.dev.json`, prod uses `secrets.prod.json`
- **Single-instance**: mutex prevents duplicate same-environment instances

### Microsoft Store Release (Windows)

Store release is a distinct workflow from day-to-day dev/prod builds. The supported MSIX build command is:

```powershell
cd D:\Data\Harold\github\spamfilter-multi-prod\mobile-app
flutter clean
flutter pub get
flutter pub run msix:create
```

`flutter pub run msix:create` honors the `msix_config` block in `pubspec.yaml`, including the critical `windows_build_args` field that injects OAuth credentials via `--dart-define-from-file`. **The key is `windows_build_args`, NOT `build_windows_args`** -- the transposed form is not a real msix key, is silently ignored, and is exactly the F119 defect that shipped a credential-less 0.5.4 to the Store. `test/policy/msix_config_test.dart` is a build-failing gate asserting the typo never reappears. **Do NOT use `scripts/build-msix.ps1`** -- that is a deprecated makeappx.exe path that produces an MSIX with empty credentials (silent Gmail sign-in failure).

For the full end-to-end procedure (version bump 5-file checklist, `secrets.prod.json` recreation, verification steps, Partner Center upload walkthrough, post-submission), see **`docs/STORE_RELEASE_PROCESS.md`**.

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

### Desktop E2E Testing (civyk-winwright)

```powershell
# Verify winwright environment
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe doctor

# Inspect accessibility tree of running app
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe inspect

# Replay a recorded test script
C:\Tools\WinWright\Civyk.WinWright.Mcp.exe run <script.json>
```

civyk-winwright is also available as an MCP server in Codex for interactive desktop app testing. See `docs/TESTING_STRATEGY.md` for full details.

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
- **App Data Directory** (ADR-0035: environment-aware):
  - Production: `C:\Users\{username}\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\`
  - Development: `C:\Users\{username}\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`
  - Note: Changed from `com.example\spam_filter_mobile\` in Sprint 19 (v0.5.0). A one-time migration copies old data on first launch.
- **Database Location**: `{App Data Directory}\spam_filter.db`
  - Rules database (DB is sole source of truth since Sprint 20)
  - Scan results history
  - App settings and configuration
- **Rules Directory**: `{App Data Directory}\rules\`
- **Credentials Directory**: `{App Data Directory}\credentials\`
- **Background Scan Log**: `{App Data Directory}\logs\{prefix}background_scan_v{VERSION}.log`
  - Production: `background_scan_v0.5.0.log`
  - Development: `dev_background_scan_v0.5.3.log`
  - Log filename includes app version (e.g., `background_scan_v0.5.0.log`) to distinguish logs from different builds/branches running concurrently

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

## Process lessons

Lessons from past sprints live in the sprint docs and in `docs/sprints/SPRINT_N_RETROSPECTIVE.md`. They are
applied to the sprint execution docs when Harold approves them, so the docs above are the current version.

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
├── AGENTS.md                 # Primary documentation (this file)
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

### Codex Tooling
- **Custom MCP Server**: `scripts/email-rule-tester-mcp/`
- **Validation Scripts**: `scripts/validate-yaml-rules.ps1`, `scripts/test-regex-patterns.ps1`
- **Skills**:
  - `/startup-check` - Environment health check and memory restore
  - `/phase-check` - Sprint phase transition checkpoint (verify phase complete, preview next phase)
  - `/plan-sprint` - Sprint planning with model assignments
  - `/full-test` - Run all Flutter tests and analyze code quality
  - `/memory-save` - Produce a compact-string save point for the next session
  - `/memory-restore` - **RETIRED (Sprint 51)**. Sprint state lives in `.claude/sprint_status.json` (maintained at Phase 7.7); `/startup-check` reads it with staleness checks. The old `.claude/memory/current.md` path is frozen at Sprint 39 and must not be restored.

### Archives (gitignored)
- **Archive/**: Historical docs, legacy Python desktop app, completed phase reports
