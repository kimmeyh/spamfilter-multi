# Changelog

All notable changes to this project are documented in this file.
Format: `- **type**: Description (Issue #N)` where type is feat|fix|chore|docs

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** (this doc) | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## [Unreleased]

### 2026-04-19 (Sprint 35 - Sprint 34 Cleanup + WinWright E2E Execution)
- **fix**: BUG-S34-1: Update stale test assertion in `default_rule_set_service_test.dart` line 422 from `expect(resetResult.rules, 5)` to `expect(resetResult.rules, greaterThan(100))` to match sibling assertions and the post-F73 1638-rule baseline. Stale assertion escaped Sprint 34 review and broke develop after PR #236 merge. Test suite now 1363 passing / 0 failing (Issue #237)
- **test**: F69: WinWright E2E execution + triage. Drove all 7 Sprint 34 scenarios (navigation, settings tabs, manual scan, scan history, text selection, F56 block rule, F56 safe sender) via WinWright MCP primitives against a fresh Windows desktop dev build. 7 of 7 PASS. Sprint 34 JSON `run` schema is unsupported by WinWright CLI; pivoted to interactive MCP per Harold's Option 1 approval. Added project-level `.mcp.json` for WinWright server discovery. Updated `mobile-app/test/winwright/README.md` Status column and added Sprint 35 Execution Notes documenting selector drift adaptations and design observations (Settings header opens account-selection dialog by design; tab selectors collide with sibling text -- use Tab N of 4 form). No app bugs uncovered (Issue #237)
- **test**: F56 E2E scripts now self-clean. Both `test_f56_create_block_rule.json` and `test_f56_create_safe_sender.json` extended to full create -> verify-present -> delete -> verify-absent lifecycle. Test data retuned to avoid bundle collision: `.museum` TLD (no collision with bundled `._.xyz`) and `winwright-e2e-test.invalid` (RFC 6761 reserved TLD prevents real-world collision). Cleaned up two test artifacts (`manual_._.xyz_*` rule and `test-trusted-domain.com` safe sender) that the original Sprint 34 scripts left in the dev DB during Sprint 35 execution (Issue #237)
- **docs**: Sprint 35 plan: Manual Testing Notes section populated with per-script triage outcomes, in-scope adaptations, and zero new backlog candidates from F69 execution (Issue #237)
- **docs**: WinWright run policy formalized -- conditional per sprint (only run scripts whose tested surface is touched, not the full suite) and state-restoring (every script reverts any rule/safe sender/setting it modifies). Mapping table added to TESTING_STRATEGY.md, pointer added to SPRINT_EXECUTION_WORKFLOW.md Phase 5.3 (Issue #237)
- **docs**: Backlog updates -- BUG-S35-1 logged (Issue #239: manual rule UI accepts duplicates, surfaced when F69 created a `.xyz` rule that collided with bundled `._.xyz`); F79 logged as HOLD (Issue #240: full WinWright suite sweep, on-demand only, distinct from per-sprint conditional runs); ALL_SPRINTS_MASTER_PLAN.md candidates list updated (Issue #237)
- **docs**: Sprint 35 retrospective process improvements applied (4 of 5): P1 Phase Auto-Advance Rule (`CLAUDE.md` item 7 in Development Philosophy) -- phase boundaries do not require permission to cross under sprint plan approval; P2 Standing Approval Inventory (`docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 3.7) -- enumerated [OK]/[FAIL] action lists; P4 Model-Version Pitfalls appendix (`CLAUDE.md`) -- living list of behaviors to avoid, seeded with 5 Opus 4.7 entries; P5 Sprint Resume Pattern (`.claude/memory/feedback_sprint_resume.md`) -- 4-step compact resume sequence. P3 (1-page Phase Cheat Sheet) backlogged as F80 (Issue #241) for Sprint 36. Established to recover the ~4 wall-clock hours Opus 4.7 cost across Sprints 34-35 vs prior model behavior (Issue #237)
- **docs**: Sprint 35 Category 2 testing-gap closure: added Phase 5.1.1 step 2a "Test-assertion sibling sweep for structural-data changes" to `docs/SPRINT_EXECUTION_WORKFLOW.md` -- mechanical 5-min check that would have caught BUG-S34-1 before the Sprint 34 merge (Issue #237)
- **docs**: Sprint 35 retrospective document `docs/sprints/SPRINT_35_RETROSPECTIVE.md` -- 14 categories x 4 roles per CLAUDE.md mandate; Sprint 35 promoted to Last Completed Sprint in master plan (Issue #237)

### 2026-04-18 (Sprint 34 - Rule Management Foundation + UI Standards)
- **fix**: F73: Fix broken monolithic rule split + bundled YAML rebuild. Part A: new `splitMonolithicRules()` detects remaining monolithic rules at startup and splits into individual per-pattern rows with classification metadata. Part B: rebuild bundled rules.yaml from 5 monolithic blobs to 1,638 individual per-pattern entries (header_from only). Part C: rewrite `ensureTldBlockRules()` for individual-row insertion with backwards-compat detection (Issue #235)
- **feat**: F56: Manual rule creation UI. New `ManualRuleCreateScreen` with guided form for creating block rules (4 types: TLD, entire domain, exact domain, exact email) and safe sender rules (3 types: entire domain, exact domain, exact email). Input parsing handles bare email, bare domain, URL with protocol, URL with path. Pattern preview with ReDoS validation (SEC-1b). FAB added to Manage Rules and Manage Safe Senders screens (Issue #235)
- **docs**: ADR-0037: UI/Accessibility Standards -- WCAG 2.1 AA target, Semantics labeling strategy, SelectionArea/SelectableText standard, YAML round-trip invariant documentation (Issue #235)
- **chore**: F62: Dead code cleanup -- remove deprecated config/app_paths.dart, consolidate duplicate LocalRuleStore, move legacy OAuth screens to lib/ui/screens/ (Issue #235)
- **fix**: F72: Code hygiene -- remove 9 emojis from production code, add if(MSVC) guard in CMakeLists.txt, SEC-20 generic email validation messages (Issue #235)
- **test**: F69: WinWright E2E test scripts for Windows desktop -- 7 JSON test scripts (navigation, settings tabs, manual scan, scan history, text selection per ADR-0037, F56 block rule creation, F56 safe sender creation), PowerShell runner with auto screen-reader-flag setup (Issue #235)
- **docs**: Sprint 34 retro improvement: Phase 7 retrospective now follows the explicit 7-Step Retrospective Protocol (send prompt -> draft Claude in parallel -> record Harold verbatim -> combine+display -> propose improvements -> Harold decides now-vs-backlog -> apply approved). Updates SPRINT_EXECUTION_WORKFLOW.md, SPRINT_RETROSPECTIVE.md, SPRINT_CHECKLIST.md, and memory entry. Documents the protocol that 33 prior sprints implicitly followed (Issue #235)

### 2026-04-14 (Sprint 33 - Security Hardening + UX Polish)
- **feat**: F53: Add `@.*\.cc$` (Cocos Islands) and `@.*\.ne$` (Niger) TLD block patterns to the bundled SpamAutoDeleteHeader rule; includes idempotent post-seed migration (DefaultRuleSetService.ensureTldBlockRules) that adds the patterns to existing installations on startup (Issue #233)
- **docs**: F65: Verified Gmail onboarding already presents App Password (IMAP) as the recommended primary method with Google Sign-In (OAuth) as the alternative -- no code changes needed. Implementation from Issue #178 (Sprint 19) already aligns with ADR-0034 Option D (Dual Path) (Issue #233)
- **feat**: SEC-19: Add "Disable detailed auth logging" toggle in Settings > General > Privacy & Logging. When on, Redact.logSafe() becomes a no-op even in debug builds, suppressing sensitive auth traces. Setting is cached process-locally (Redact.setAuthLoggingDisabled) and loaded from DB at app startup to avoid per-call DB hits across 100+ log sites (Issue #233)
- **feat**: SEC-14: Unmatched-email retention + body-preview truncation. New `UnmatchedEmailStore.deleteOlderThan(days)` purges rows older than the retention window (default 30 days; configurable in Settings > General > Privacy & Logging via Forever / 7 / 30 / 90 / 365 day options). Cleanup runs at app startup and after every scan completion. Body previews are truncated to 100 characters at insert time via a new `truncateBodyPreview` helper + enforcement inside `UnmatchedEmail.toMap()` (Issue #233)
- **feat**: SEC-22: Per-account rate limit on failed IMAP authentication. New `AuthRateLimiter` tracks up to 10 failures in a rolling 1-hour window per `{platform}-{email}` identifier; once the threshold is hit the account is blocked for 1 hour. State persists in a new `auth_rate_limit` table (DB schema v3) so blocks survive app restart. Successful sign-in resets the counter. `GenericIMAPAdapter.loadCredentials` calls `assertNotBlocked` before network I/O and records failures on `AuthenticationException`. The account setup Test Connection flow surfaces a "Too many failed sign-in attempts. Try again at HH:MM." message instead of the generic auth error. Gmail OAuth is intentionally excluded (different threat model) (Issue #233)
- **feat**: SEC-1b: ReDoS runtime protection. Design decision: Option C (compile-time rejection of user patterns) over Option A/B (isolate-per-match). `PatternCompiler.compileWithProvenance(pattern, user|bundled)` now rejects user patterns that match `detectReDoS` heuristics, caching a never-match fallback and recording the rejection in `rejectedUserPatterns` for UI surfacing. Bundled patterns stay on the direct `regex.hasMatch()` fast path (no per-match overhead). Primary enforcement chokepoints: `RuleDatabaseStore.addRule`/`updateRule` and `SafeSenderDatabaseStore.addSafeSender`/`updateSafeSender` now call `PatternCompiler.detectReDoS` before persist and throw if any pattern is vulnerable -- blocks dangerous patterns at the persistence boundary so the scanner hot path never sees them (Issue #233)
- **feat**: SEC-8: Certificate pinning for Google OAuth endpoints. New `CertificatePinner` holds SPKI pins for `accounts.google.com`, `oauth2.googleapis.com`, `gmail.googleapis.com`, and `www.googleapis.com`. New `PinnedHttpClient` wraps `dart:io HttpClient` with a bad-cert callback that enforces the pin registry. `GmailWindowsOAuthHandler.exchangeCode`, `refreshAccessToken`, and `getUserEmail` now use the pinned client. Runtime kill switch via `CertificatePinner.setEnabled` (wired to a Settings > General > Privacy & Logging toggle and persisted in `app_settings`). Pin rotation procedure documented in the library dartdoc. IMAP pinning is NOT implemented because `enough_mail.ImapClient` does not expose a `SecurityContext` or bad-cert callback -- tracked as future work with comments in `generic_imap_adapter.dart` (Issue #233)
- **feat**: SEC-11 (partial): SQLite at-rest encryption infrastructure. Scope-limited to key management and the opt-in feature flag for this release; the actual SQLCipher DB swap is deferred until dedicated platform QA validates migration on real installs. Ships: `DatabaseEncryptionKeyService` (generates/stores 256-bit key in `flutter_secure_storage` per-device, base64 encoded for `PRAGMA key`), new `encrypt_database` app setting defaulting to `false`. Follow-up work (new backlog item) will add `sqflite_sqlcipher` + `sqlcipher_flutter_libs` deps, atomic plaintext→encrypted migration, and flip the flag default to `true`. Design rationale: ship plumbing now so the risky swap can land in a focused sprint without re-doing the key-storage work (Issue #233)
- **feat**: F66: User data deletion. New `DataDeletionService` provides two flows: `deleteAccountData(accountId)` removes one account's credentials, scan results, email actions, unmatched emails, per-account settings, rate-limit state, and the accounts-table row while preserving global rules/safe-senders/other-accounts; `wipeAllData()` calls `DatabaseHelper.deleteAllData` + `SecureCredentialsStore.deleteAllCredentials` for a fresh-install reset. UI wiring: Account Selection "Delete Account" button now runs the full per-account wipe (previously credentials-only) with an expanded confirmation explaining exactly what is removed. New Settings > General "Delete All App Data..." button runs behind a two-step confirmation (Continue -> Are you absolutely sure -> Delete Everything) (Issue #233)
- **fix**: F55: Results screen back button now uses `Navigator.pop` instead of `pushReplacement` so the nav stack stays consistent (previously "Back to Scan Progress" rebuilt Scan Progress, which broke back-navigation from the rebuilt screen). The "Back to Accounts" shortcut (popUntil) is kept intentionally per user feedback -- useful shortcut even though stack-inconsistent. (Issue #233)
- **feat**: F55: "Select Account" icon added to Manual Scan (ScanProgressScreen) and Results (ResultsDisplayScreen) AppBars. Taps popUntil the root route, returning the user directly to Account Selection in one click (Issue #233)
- **feat**: F54: Help system. New `HelpScreen` (scrollable single page, one anchored section per primary screen) + `HelpSection` enum + `openHelp(context, section)` helper. Help icon (?) added to every primary screen's AppBar (Select Account, Account Setup, Manual Scan, Results, Scan History, Settings, Manage Rules, Rule Quick Add, Rule Test, Manage Safe Senders, Folder Selection, YAML Import/Export). Tapping the icon deep-links to that screen's section; back button pops the Help screen and returns to origin. Content depth is tooltip-style (1-3 short paragraphs per section), not a full walkthrough (Issue #233)
- **docs**: ARCHITECTURE.md updated for Sprint 33: PatternCompiler provenance tracking + ReDoS enforcement chokepoints (SEC-1b); new `lib/core/security/` directory documented (AuthRateLimiter, CertificatePinner/PinnedHttpClient, DatabaseEncryptionKeyService); DataDeletionService + DefaultRuleSetService added to Other Services table; HelpScreen added to UI Screens table; DB schema table extended with `unmatched_emails` + `auth_rate_limit` (schema v3) and a schema version history; Sprint 33 Security Layers summary added to Security Considerations (Issue #233)

### 2026-04-16 (Sprint 33 - Manual Testing Feedback)
- **fix**: F55: Live-scan Results double-push. `_startRealScan` pushed Results on scan-start; `ScanProgress.build()` then pushed a second Results on scan-completed. Back from Results popped the top Results and landed on the duplicate underneath (looked like "refresh"); back from a post-Scan-Again ScanProgress also landed on the duplicate. Fix: removed the auto-push-on-completion; Results already `context.watch`es the provider and renders scanning -> completed naturally. Single push from scan-start is now the only path (Issue #233)
- **fix**: F55: Manual Scan staleness on return. ScanProgressScreen now implements `RouteAware.didPopNext` and calls `scanProvider.reset()` when Results is popped back to it, so the user lands on a clean "Ready to Scan" view (not the completed scan state) (Issue #233)
- **feat**: F55: Select Account icon rolled out to Scan History, Settings, Platform Selection, and Account Setup (both Gmail auth method + standard setup AppBars). Icon order standardized across the app: Download, Search, History, Accounts, Help, Settings, X (X auto-appended on Windows) (Issue #233)
- **feat**: F54: Help screen gets its own AppBar icon row (History, Accounts, Settings, X when account context is available). `openHelp()` helper grew optional `accountId`/`accountEmail`/`platformId`/`platformDisplayName` parameters; callers on Scan Progress, Results, Scan History, Folder Selection, and Settings thread account context through (Issue #233)
- **feat**: F54: Help screen structural improvements. Switched from `ListView` (lazy-build caused deep-link misses at default viewport size) to `SingleChildScrollView` + `Column` so every section is built up front and `Scrollable.ensureVisible` always resolves. Scrollbar is now always visible (`thumbVisibility: true`). Trailing 80%-viewport-height filler lets any section pin to the top of the viewport, even the last real section (Issue #233)
- **feat**: F54: Help content expanded. New sections: Demo Scan; General > Rules Management; General > Scan History; General > Privacy & Logging; Account > Folder Settings (with per-provider Gmail/AOL/Yahoo/Outlook.com/generic-IMAP suggestions); Manual Scan Settings (covers Scan Mode / Scan Range / Default Folders / Confirmation / Export Settings). Background Scanning section rewritten to cover only Enable / Test / Frequency / Debug (scan mode/range/folders covered in Manual Scan Settings instead of duplicated). Settings Help icon now deep-links to the section matching the currently visible tab (HelpSection enum grew from 12 to 19 values) (Issue #233)
- **feat**: SEC-11: "Encrypt database (experimental)" toggle added to Settings > General > Privacy & Logging. Provisions the 256-bit key via `DatabaseEncryptionKeyService` when enabled; the SQLCipher driver swap remains follow-up work (Issue #233)
- **fix**: Rule and safe-sender detail dialogs were not selectable because Flutter's `AlertDialog` sits in an overlay outside the screen-level `SelectionArea`. Both dialogs now wrap their content in a dialog-scoped `SelectionArea` and use `SelectableText` for the rule title so users can copy pattern text (Issue #233)
- **docs**: SEC-1b backlog note added to F56 (Manual rule creation UI) in ALL_SPRINTS_MASTER_PLAN.md -- the ReDoS compile-time rejection cannot be manually tested until an add/edit rule UI exists (Issue #233)

### 2026-04-14 (Sprint 32 - Code Review Fixes)
- **fix**: C2: SEC-12 OAuth revocation token now sent in form-encoded body instead of URL query string (RFC 7009 compliant, prevents token leakage via HTTP logs) (Issue #230)
- **fix**: H1: SEC-17 auth logging uses Redact.accountId() instead of Redact.email() for accountId values; extended Redact.accountId() to handle both plain email and prefixed formats (Issue #230)
- **fix**: H2: SEC-21 password length warning now shown as SnackBar (5s, orange) instead of log-only; removed password length from log to eliminate search-space oracle (Issue #230)
- **fix**: SEC-17 extended: background scan worker and UI files also redact account IDs (user-reported gap from background scan log review) -- 9 files, ~40 log sites across background_scan_windows_worker, background_scan_worker, account_selection_screen, account_setup_screen, account_store, scan_result_store, settings_store, settings_screen, email_scan_provider (Issue #230)
- **docs**: Added SEC-1b (ReDoS runtime protection, design work needed) and F72 (code hygiene cleanup) to backlog from Sprint 32 Phase 5.1.1 automated code review

### 2026-04-13 (Sprint 32 - Security Hardening)
- **fix**: SEC-1: ReDoS protection -- nested quantifier detection in PatternCompiler.validatePattern() and timeout-protected regex matching via safeHasMatch() (Issue #230)
- **fix**: SEC-10: YAML import file size limit -- reject files over 10 MB before parsing (Issue #230)
- **fix**: SEC-12: OAuth token revocation -- desktop signOut now calls Google revoke endpoint (Issue #230)
- **fix**: SEC-13: Fail-fast on empty OAuth client ID with setup instructions (Issue #230)
- **fix**: SEC-17: Auth logging -- replace unredacted email addresses with Redact.email() in secure_credentials_store.dart (26 log statements), redact OAuth config and token exchange logs (Issue #230)
- **fix**: SEC-18: Silent regex fallback logging -- add Logger.w() to catch blocks in safe_sender_list.dart and rule_quick_add_screen.dart (Issue #230)
- **fix**: SEC-20: Email format validation on account setup -- validate @ symbol, domain structure before IMAP connection (Issue #230)
- **fix**: SEC-21: Password minimum length warning -- informational message for entries shorter than 8 characters (Issue #230)
- **fix**: SEC-23: Windows binary hardening flags -- /GS, /DYNAMICBASE, /NXCOMPAT, /guard:cf in CMakeLists.txt (Issue #230)
- **docs**: SEC-16: Add dependency vulnerability check (dart pub outdated) to sprint pre-kickoff workflow and checklist (Issue #230)
- **test**: Add 13 new tests for ReDoS detection and timeout-protected matching (Issue #230)

### 2026-04-13 (Sprint 31 - Security Deep Dive)
- **docs**: Security audit - comprehensive review of dependencies, SQL injection, regex/ReDoS, credentials, OWASP Mobile Top 10, platform security (F68)
- **docs**: Identified 31 security findings: 3 Critical, 7 High, 13 Medium, 8 Low
- **docs**: Added 23 security backlog items (SEC-1 through SEC-23) to ALL_SPRINTS_MASTER_PLAN.md with severity ratings
- **docs**: Key findings: SQL injection [OK] secure (92+ ops), ReDoS vulnerability in regex eval, missing Android security config
- **fix**: SEC-2: Add android:allowBackup="false" to AndroidManifest.xml (prevents adb backup data extraction)
- **fix**: SEC-3: Firebase API keys restricted in Google Cloud Console (Android key: package+SHA-1, 4 APIs only; Browser key: domain restricted)
- **fix**: SEC-5: Remove password logging from IMAP adapter (no credential info in logs)
- **fix**: Scan History: tapping a background scan entry now shows correct results instead of stale live scan results for same account
- **test**: Add 3 integration tests for historical scan result loading (scan ID isolation, latest vs specific, email action partitioning)

### 2026-04-13 (Sprint 30 - Architecture Gap Analysis)
- **docs**: Architecture gap analysis - compared 36 ADRs, ARCHITECTURE.md, ARSD.md against codebase (F60, Issue #226)
- **docs**: Identified 26 gaps across 5 categories: documentation drift, dead code, partial ADRs, missing docs, unimplemented architecture
- **docs**: Added 7 new backlog items from gap analysis: F61 (doc refresh), F62 (dead code cleanup), F63 (responsive design), F64 (CI/CD, HOLD), F65 (Gmail onboarding update), F66 (user data deletion, off HOLD), F67 (iOS/Linux/macOS validation, HOLD)
- **docs**: User review of all 26 gaps -- corrected G11 (Gmail IMAP already implemented), took GP-11 off HOLD as F66, updated #163 scope
- **chore**: Fix startup-check skill to use PowerShell first for metadata updates (don't-ask mode compatible)
- **chore**: Close Sprint 29 issues #219, #220

### 2026-04-03 (Sprint 29 - UX + Quality + Features)
- **feat**: Make all page text selectable and copyable across 21 screens (F50, Issue #220)
- **feat**: Scan History enhancements - multi-account combined view, account/type filters, totals with tooltips, retention days in title (F48, Issue #212)
- **feat**: Default rule set creation - seed from bundled YAML on fresh install, Reset to Defaults button in Settings (F46, Issue #208)
- **test**: Add tests for email_scanner, default_rule_set_service, yaml_service parse methods (F42, Issue #203)
- **fix**: Results screen and email detail popup now support text selection (F50 testing feedback)
- **fix**: Account setup dialogs (AOL, Gmail, platform selection) now support text selection (F50 testing feedback)
- **fix**: Scan History account filter uses configured accounts, shows when multiple accounts exist (F48 testing feedback)
- **fix**: Manual Scan title shows account email instead of platform name
- **fix**: YAML round-trip test path after rules moved to assets/rules/ - fixes pre-existing test failure
- **docs**: Backlog refinement - removed completed items from ALL_SPRINTS_MASTER_PLAN.md

### 2026-04-02 (Sprint 28 - MSIX Sandbox Fix + UX Improvements)
- **fix**: Replace all hardcoded Platform.environment['APPDATA'] paths with path_provider for MSIX sandbox compatibility (B1, Issue #218)
- **fix**: Add MSIX detection (AppEnvironment.isMsixInstall) and skip Task Scheduler in MSIX context (B1, Issue #218)
- **fix**: app_identity_migration.dart uses path_provider instead of raw APPDATA (Issue #218)
- **fix**: dev_environment_seeder.dart uses path_provider instead of raw APPDATA (Issue #218)
- **fix**: background_scan_windows_worker.dart uses cached path_provider log directory (Issue #218)
- **feat**: Remove "Scan All N Accounts" button from account selection screen (F49, Issue #219)
- **feat**: View Scan History on account selection shows account selection dialog (F49, Issue #219)
- **feat**: Scan History title shows account email when filtered by account (F49, Issue #219)
- **feat**: Background settings: Scan Mode moved above Default Folders to match Manual Scan layout (F51, Issue #221)
- **fix**: Account selection dialog displays correct email and platform from cached data (Issue #219)
- **fix**: Test Background Scan runs all accounts regardless of Enable Background Scanning toggle
- **chore**: Add local MSIX testing support (create-test-cert.ps1, store/test toggle docs)

### 2026-03-30 (Sprint 27 - Desktop App E2E Testing with civyk-winwright)
- **feat**: Install civyk-winwright MCP server for automated Windows Desktop UI testing (F11)
- **feat**: Discover Flutter Desktop requires SPI_SETSCREENREADER flag for accessibility tree activation (F11)
- **feat**: Create enable-screen-reader-flag.ps1 utility for toggling Windows screen reader flag (F11)
- **feat**: Evaluate accessibility tree across 5 screens - GO decision for full E2E testing (F11)
- **feat**: Exploratory testing of all 11 screens - buttons, tabs, text input, dialogs, assertions all work (F11)
- **feat**: MCP HTTP server workflow for interactive desktop testing via JSON-RPC (F11)
- **docs**: Add automated E2E desktop testing section to TESTING_STRATEGY.md and ARCHITECTURE.md (F11)
- **docs**: Move F11 from HOLD to active in ALL_SPRINTS_MASTER_PLAN.md (F11)
- **docs**: Create SPRINT_27_ACCESSIBILITY_EVALUATION.md with full findings report (F11)
- **chore**: Fix /memory-save, /memory-restore, /startup-check skills - use Bash for .claude/ writes, add staleness validation
- **chore**: Add mandatory metadata update enforcement to /startup-check and /memory-restore skills
- **fix**: Patch Flutter SDK sqlite3 native assets PathExistsException on Windows (MSB8066 build failure)
- **fix**: Add pre-build native_assets cleanup to build-windows.ps1 (defense-in-depth for sqlite3 bug)
- **docs**: Create WINWRIGHT_SELECTORS.md quick reference for winwright selector patterns (F11)
- **docs**: Add B1 MSIX sandbox crash (Issue #218) to backlog as Priority 1 for Sprint 28
- **docs**: Add F49, F50, F51 retrospective feedback items to backlog (Issues #219-#221)

### 2026-03-22 (Sprint 26 - Settings UX, Excel Export, Provider Warnings, Multi-Account)
- **feat**: Folder settings selection UX - radio button auto-save, show current folder (F43, Issue #211)
- **feat**: "Go to View Scan History" link on Manual Scan settings page (F44, Issue #211)
- **feat**: Background scan Excel export with daily file grouping and updated field order (F45, Issue #211)
- **feat**: Email provider domain warning when creating domain-level rules (F47, Issue #211)
- **feat**: Settings General tab for app-wide settings (rules, scan history, about) (F36, Issue #211)
- **feat**: Multi-Account Scanning - "Scan All Accounts" button for sequential scanning (F7, Issue #211)
- **chore**: Action label "No rule" replaces "None" in CSV/Excel exports
- **fix**: Excel filename uses _dev suffix for dev environment, files stored in AppData dir (ADR-0035, Issue #211)
- **fix**: Live Scan Results - deleted emails removed from list immediately after block rule applied (Issue #211)
- **feat**: View Scan History icon added to Results Display and Account Selection AppBars (Issue #211)

### 2026-03-22 (Sprint 25 - Safe Sender Fixes, Scan Mode Rename, Background Scan Rebuild)
- **fix**: Safe sender INBOX skip bug - emails already in safe sender target folder were not being skipped (Issue #198)
- **fix**: Exact domain filter chip misclassification - determinePatternType and categorize priority reordered (F30, Issue #202)
- **fix**: Background scan task deleted on rebuild - add post-build Task Scheduler re-registration to build-windows.ps1 (F31, Issue #202)
- **feat**: Safe sender move diagnostic logging for debugging move execution (Issue #201)
- **chore**: Rename ScanMode enum values for clarity (readonly->readOnly, testLimit->rulesOnly, testAll->safeSendersOnly, fullScan->safeSendersAndRules) with backwards compatibility (Issue #202)
- **feat**: Live scan status indicator showing progress bar, completion, and error states in results summary card (F34, Issue #202)
- **feat**: Re-process emails via IMAP after inline rule changes - adds safe sender or block rule, then executes server-side actions on affected emails (F38, Issue #202)
- **test**: Add exact domain regex classification tests for SafeSenderCategory (Issue #202)
- **test**: Add ScanMode backwards compatibility tests for legacy DB enum names (F32, Issue #202)
- **test**: Add determinePatternType edge case and round-trip tests (F32, Issue #202)
- **test**: Add RuleSetProvider state management tests - load, add, remove, update rules and safe senders (F32, Issue #202)
- **chore**: F38 re-process changed from blocking dialog to non-blocking inline banner (Issue #202)
- **chore**: Set up prod worktree at spamfilter-multi-prod for side-by-side dev/prod execution (ADR-0035)

### 2026-03-21 (Sprint 24 - Windows Store Readiness: Privacy Policy, Store Assets, Submission)
- **feat**: Privacy policy website deployed to docs/website/ (index.html, privacy/index.html, delete/index.html) with CNAME for myemailspamfilter.com (Issue #197)
- **feat**: Microsoft Store listing created - app name reserved, store assets uploaded, MSIX package submitted for certification (Issue #197)
- **feat**: Store listing assets document with descriptions, screenshots, keywords, age ratings (Issue #197)
- **chore**: Rename Windows executable from spam_filter_mobile to MyEmailSpamFilter (CMakeLists.txt, Runner.rc, Package.appxmanifest, build-windows.ps1)
- **chore**: Rename Dart package from spam_filter_mobile to my_email_spam_filter (pubspec.yaml, 224 imports across 73 files)
- **chore**: Add msix v3.16.8 dev dependency for MSIX package building
- **chore**: Update pubspec.yaml msix_config with Partner Center identity (publisher, identity_name, publisher_display_name)
- **docs**: Add contact email (kimmeyh@outlook.com) to privacy policy website contact section
- **docs**: Update all docs referencing old executable name (WINDOWS_DEVELOPMENT_GUIDE, TROUBLESHOOTING, ALL_SPRINTS_MASTER_PLAN, ADR-0035)
- **docs**: Update LOGGING_CONVENTIONS.md with new package import name

### 2026-03-20 (Sprint 23 - Windows Store MSIX, Signing, Domain, Branding)
- **feat**: MSIX config fixes - enable store mode, fix logo path, sync version (Issue #194)
- **docs**: ADR-0036 MSIX signing strategy - Microsoft Store auto-signing for Store builds (Issue #194)
- **feat**: App icon and branding - email envelope + checkmark + funnel design (ADR-0031, Issue #194)
- **chore**: Add flutter_launcher_icons v0.14.4, generate Android adaptive icons and Windows .ico
- **chore**: Register myemailspamfilter.com domain + .net forwarding, DNS configured for GitHub Pages (Issue #166)

### 2026-03-19 (Sprint 22 - Windows Store Readiness Research)
- **docs**: Microsoft Store requirements research and codebase gap analysis (Issue #191)
- **docs**: Windows Store readiness backlog items #17-#22 added to ALL_SPRINTS_MASTER_PLAN.md (Issue #191)
- **chore**: Fix memory-save, memory-restore, startup-check skills - use absolute paths and bash-compatible commands

### 2026-03-18 (Sprint 21 - ADR-0035)
- **feat**: Production/Development side-by-side builds with environment-aware data directories (ADR-0035, Issue #189)
- **feat**: AppEnvironment class reads APP_ENV from --dart-define (dev/prod)
- **feat**: Dev builds use MyEmailSpamFilter_Dev data directory, window title shows [DEV]
- **feat**: Separate Task Scheduler task names per environment
- **feat**: First-run dev environment seeded from production database
- **feat**: Single-instance mutex per executable path prevents duplicate instances
- **feat**: build-windows.ps1 accepts -Environment parameter (dev/prod)
- **feat**: secrets.prod.json template for production credentials
- **chore**: Version bumped to 0.5.1 on develop (production stays 0.5.0)

### 2026-03-17 (Sprint 20 - Testing Feedback)
- **fix**: DB v2 migration checks for existing columns before ALTER TABLE
- **fix**: Scan Results folder display shows correct account folders after switching accounts
- **feat**: Demo-specific rules DB for consistent demo scan results (~20 safe / ~30 deleted / ~9 no-rule)
- **fix**: IMAP folder listing now recursive - shows [Gmail]/Trash, [Gmail]/Spam and other child folders
- **fix**: Non-selectable parent folders (e.g., [Gmail]) filtered from folder selection
- **fix**: Reclassify 266 TLD header patterns from exact_domain to top_level_domain
- **fix**: Convert 1,370 wildcard TLD patterns to .com and reclassify as entire_domain
- **fix**: Add Rule from scan results now sets patternCategory, patternSubType, sourceDomain
- **fix**: Quick rule from email detail popup now sets classification fields
- **fix**: YAML migration and export preserve classification fields
- **fix**: Safe sender matches in safe sender folder skipped from scan results (already where they belong)

### 2026-03-15 (Sprint 20)
- **fix**: Gmail IMAP folder scan errors - use PlatformRegistry for correct adapter routing (Issue #184)
- **feat**: Demo Scan expanded with 12 new sample emails across Safe Sender and Block Rule categories (Issue #185)
- **feat**: Speed up Add Rule re-evaluation with shared PatternCompiler cache (Issue #186)
- **chore**: Clean up all 46 analyzer warnings - zero issues remaining (Issue #187)
- **feat**: Add pattern classification fields (patternCategory, patternSubType, sourceDomain) to Rule model (Issue #149)
- **feat**: Remove YAML dual-write - database is sole source of truth for rules (Issue #149)
- **feat**: Standalone rule split script - splits 5 monolithic rules into ~3,291 individual rules (Issue #149)
- **feat**: Manage Rules UI overhaul - filter chips by category and sub-type, search, individual rule display (Issue #149)

### 2026-03-14 (Sprint 19 - Testing Feedback Round 2)
- **fix**: Safe Senders YAML export error - AppPaths not initialized in Import/Export screen (Issue #179)
- **fix**: Convert bare `@insightfinancialassociates.com` safe sender pattern to proper Entire Domain regex
- **feat**: Gmail auth method order - App Password (IMAP) listed first as Recommended, Google Sign-In second with re-auth note (Issue #178)
- **feat**: App Password instructions - selectable/copyable text, tappable URL links, updated step text, removed obsolete IMAP info box (Issue #178)
- **feat**: Scan Results Summary title now shows scanned folder names (e.g., "Summary - Read-Only - Folder(s): Bulk, Bulk Mail")
- **feat**: Live re-evaluation of all "No rule" emails after adding a block rule or safe sender from scan results
- **fix**: Scan History now filters by account - shows only scans for the current email account, not all accounts
- **test**: Added regex pattern validation tests for round-trip YAML export/import (rules and safe senders)

### 2026-02-28 (Sprint 19 - Testing Feedback Fixes)
- **fix**: Add About section in Settings > Account showing app version 0.5.0 (Issue #181)
- **fix**: Background scan worker log path updated from old com.example to MyEmailSpamFilter directory (Issue #182)
- **fix**: Demo Mode changed from toggle switch to direct-launch card on Select Email Provider screen

### 2026-02-27 (Sprint 19)
- **chore**: Tag v0.5.0 release, update pubspec.yaml version to 0.5.0+1 (Issue #181, GP-15)
- **feat**: Application identity rebranded to MyEmailSpamFilter with com.myemailspamfilter package (Issue #182, GP-1)
- **fix**: Auto-migrate app data from old com.example directory after identity change - preserves accounts, rules, credentials (Issue #182)
- **feat**: Folder selection now saves instantly on toggle - Cancel and Scan buttons removed in multi-select mode (Issue #172, F27)
- **feat**: Safe senders screen filter chips for pattern categories - Exact Email, Exact Domain, Entire Domain, Other (Issue #180, F26)
- **feat**: YAML import/export UI in Settings - export rules and safe senders to file, import from file with validation (Issue #179, F22)
- **feat**: Gmail dual-auth - choose Google Sign-In (OAuth) or App Password (IMAP) when adding Gmail account (Issue #178, F12B)

---

## [0.5.0] - 2026-02-27

First tagged release. Covers Sprints 1-18 plus hotfix #176.

### 2026-02-27 (Hotfix)
- **fix**: Windows Task Scheduler repetition trigger fails silently - changed from property-based Repetition setting to inline -RepetitionInterval/-RepetitionDuration parameters (Issue #176)

### 2026-02-25 (Sprint 18: Bug Fixes from Testing Feedback)
- **fix**: Conflict detection for "Block Entire Domain" now passes full email address to resolver instead of bare domain (Issue #154)
- **fix**: Scan History shows correct rule match info instead of "No rule" for all entries
- **fix**: Inline rule re-evaluation now updates filter counts and list membership immediately (Issue #168)
- **fix**: Background scan RepetitionDuration changed from 1 day to 365 days for reliable recurring execution
- **fix**: Settings > View Scan History now passes account context for email detail drill-down
- **feat**: Shared email provider hint in email detail popup for Gmail, Yahoo, etc. (Issue #167)

### 2026-02-24 (Sprint 18: Rule Quality and Testing Tooling)
- **fix**: Add conflict detection to inline rule assignment popup - safe sender and block rule conflicts now auto-resolved from Results screen (Issue #154)
- **docs**: Subject (S1-S6) and body (B1-B4) content rule pattern standards with guidelines, examples, and anti-patterns (Issue #141)
- **feat**: PatternCompiler.validatePattern() warns about unescaped dots, redundant wildcards, empty alternation, repeated chars (Issue #141)
- **feat**: Common email provider domain reference table - 15 providers, 50+ domains with O(1) lookup (Issue #167, F20)
- **feat**: Inline rule assignment re-evaluation - Results screen updates immediately after adding safe sender or block rule (Issue #168, F21)
- **feat**: Rule Testing and Simulation UI - test regex patterns against sample emails from recent scans with match highlighting (Issue #169, F8)
- **test**: 95 new tests (conflict resolver 16, pattern standards 48, email providers 30, rule test screen 17) - total 1088

### 2026-02-17 (Sprint 17: Scan History, Background Scan Fixes, Conflict Auto-Removal)
- **feat**: Consolidated Scan History screen replacing separate background scan log viewer - unified view of all manual and background scans with type filter chips, summary stats, and tap-to-view (Issue #158)
- **feat**: Scan history retention setting (3/7/14/30/90 days) with automatic purge of old entries (Issue #158)
- **feat**: Manual Scan screen shows configured scan mode and folders in idle status (Issue #156)
- **fix**: Clear Results screen before starting new Live Scan - no longer shows stale historical results (Issue #157)
- **fix**: Windows Task Scheduler background scan not running after reboot - changed trigger from -Once to -Daily with RepetitionInterval (Issue #161)
- **fix**: Auto-recreate missing Task Scheduler task on app startup when background scanning is enabled (Issue #161)
- **feat**: Test Background Scan button in Settings for manual verification of background scan functionality (Issue #159)
- **feat**: Auto-remove conflicting rules when adding safe sender, and vice versa - bidirectional conflict resolution (Issue #154)
- **fix**: Skip Task Scheduler management in debug mode - prevents broken scheduled tasks from temporary debug executable paths (Bug #3)
- **fix**: Prevent duplicate scan_results database records - UI-only startScan call no longer persists to database (Bug #2)
- **feat**: Reorganize Settings - move Test button before Frequency, move Scan History to Account tab (FB-4/FB-3)
- **feat**: Custom retention days input (1-999) with quick-select chips replacing dropdown (FB-2)
- **fix**: Scan History navigation - back button returns to Scan History screen instead of Scan Progress when viewing historical results (FB-1)
- **fix**: Retention days field saves on every keystroke, adds digits-only input validation with 3-char max
- **feat**: Background scan log includes full stats: Processed, Deleted, Moved, Safe, No Rule, Errors
- **fix**: Purge orphaned in_progress scan records during retention cleanup
- **feat**: Historical scan results use same interactive filter chips and folder filter as live scan results
- **fix**: Historical scan mode labels now use stored mode (not live provider default) - fullScan no longer shows "(not processed)"
- **feat**: Scan History subtitle consolidated: duration | mode | Folders in single line with updated mode names
- **fix**: Rename "Last Scan Results" to "Scan Results"
- **test**: Fix PowerShell script generator test assertion (RepetitionInterval -> Repetition.Interval)
- **docs**: Sprint retrospective improvements S1-S7 - phase transition checkpoints, mandatory sprint document creation, docs/sprints/ reorganization, /phase-check skill
- **chore**: Move 46 per-sprint documents from docs/ to docs/sprints/ with standardized uppercase naming

### 2026-02-16 (Sprint 16: Phase Renumbering)
- **docs**: Renumber sprint workflow phases from -1/0/1/2/3/4/4.5 to sequential 1-7 across 16 documents (Issue #160)

### 2026-02-15-16 (Sprint 16: User Testing Feedback)
- **feat**: Scan range slider always visible and interactive, "Scan all emails" checkbox overrides slider value (FB-1)
- **feat**: Background scan default changed to "all emails" instead of 7 days (FB-1)
- **feat**: Remove Scan Options dialog popup - Start Live Scan uses Settings directly (FB-2)
- **feat**: Simplify Manual Scan screen - remove stats bubbles, pause button, complete indicator; show progress only during active scan (FB-3)
- **feat**: View Results shows last completed scan (live or background) with scan type and timestamp (FB-4)
- **feat**: "No Results Yet" message only shown when no scan history exists at all (FB-5)
- **fix**: Auto-repair Windows Task Scheduler executable path after app rebuild (FB-6)
- **feat**: Persist individual email actions to database for historical View Results display - both manual and background scans (FB-7)
- **fix**: Historical View Results summary bubbles now show correct counts from database instead of empty live scan provider values (FB-8)

### 2026-02-14 (Sprint 16: Scan Configuration, Log Viewer, and Rule Conflict Detection)
- **feat**: Persistent days-back scan settings for Manual and Background scans with per-account overrides (Issue #153)
- **feat**: Scan Options dialog defaults to "Scan all emails" with saved preferences (Issue #150)
- **feat**: Rename "Scan Progress" screen to "Manual Scan" and remove folder selection button (Issue #151)
- **feat**: Background scan log viewer screen with account filter, summary stats, and expandable log cards (Issue #152)
- **feat**: Rule override/conflict detection - warns users when existing rules or safe senders would prevent new rule from being evaluated (Issue #139)
- **chore**: Remove unused imports from Sprint 16 changes (5 analyzer warnings fixed)
- **test**: 16 new unit tests for RuleConflictDetector (977 tests passing, 28 skipped)

### 2026-02-14-15 (Sprint 15: Bug Fixes, Performance, and Settings Management)
- **fix**: Resolve 100-delete limit bug - IMAP sequence IDs shifted after each delete, causing wrong messages to be targeted after ~100 operations. Switched to UID-based operations throughout (Issue #145)
- **feat**: Batch email processing - evaluate all emails first, then execute actions in batches using IMAP UID sequence sets. Reduces IMAP round-trips from 3N to ~3 batch operations (Issue #144)
- **feat**: Manage Safe Senders UI in Settings - view, search, delete safe sender patterns (Issue #147)
- **feat**: Manage Rules UI in Settings - view, search, delete block rules with rule type indicators (Issue #148)
- **feat**: Windows native directory browser for CSV export path selection (Issue #126)
- **feat**: Windows background scanning with Task Scheduler integration - headless scan mode, configurable frequency, per-account folder/mode settings (F5)
- **feat**: Debug CSV export toggle for background scans - writes scan results CSV after each background run
- **fix**: Background scan headless execution - account loading from SecureCredentialsStore, FK constraint compliance
- **fix**: Background scan uses correct per-account folders and scan mode (background-specific settings override)
- **fix**: Safe sender INBOX normalization for RFC 3501 compliance (mixed-case "Inbox" to "INBOX")
- **fix**: Processed count exceeding found count - batch progress messages no longer increment processedCount
- **docs**: Architecture Decision Records (ADR-0001 through ADR-0015) documenting 15 key architectural decisions
- **docs**: Sprint 14 Summary document
- **test**: Batch action result tests and batch operations mixin tests (961 tests passing, 28 skipped)

### 2026-02-07-08 (Sprint 14: Settings Restructure + UX Improvements)
- **feat**: Progressive folder-by-folder scan updates with 2-second refresh interval (Issue #128)
- **feat**: Settings Screen restructure - separate Manual Scan and Background Settings tabs (Issue #123)
- **feat**: Default Folders UI - reusable folder picker matching Select Folders screen (Issue #124)
- **feat**: Remove Scan Mode button from Scan Progress screen (single source of truth in Settings)
- **feat**: Manual and Background scans use independent scan mode settings from SettingsStore
- **feat**: Enhanced Demo Scan with 50+ sample emails for testing without live account (Issue #125)
- **feat**: Enhanced Deleted Email Processing - mark emails as read and tag with matched rule name (Issue #138)
- **fix**: Use email folder picker component for Safe Sender and Deleted Rule folder selection
- **fix**: Skip rule processing in testAll mode (safe senders evaluation only)
- **fix**: Ensure Found count is always greater than or equal to Processed count
- **chore**: Reduce analyzer warnings from 214 to 48 (target: <50) (Issue #130)
- **test**: All 937 tests passing (27 skipped)

### 2026-02-01 (Sprint 11 + Retrospective Implementation)
- **feat**: Implement functional keyboard shortcuts for Windows Desktop (Issue #107)
- **fix**: Resolve system tray icon initialization error and menu persistence (Issue #108)
- **feat**: Enhance scan options with continuous slider 1-90 days + All checkbox (Issue #109)
- **feat**: Enhance CSV export with 10 columns including scan timestamp (Issue #110)
- **CRITICAL**: Fix readonly mode bypass - now properly prevents email deletion (Issue #9)
- **CRITICAL**: Change IMAP delete to move-to-trash instead of permanent delete
- **feat**: Add Exit button to Windows AppBars with confirmation dialog
- **fix**: Add visual SnackBar feedback for Ctrl+R/F5 refresh
- **test**: Add integration test for readonly mode enforcement (prevents Issue #9 regression)
- **test**: Add integration test for delete-to-trash behavior (IMAP + Gmail)
- **docs**: Create WINDOWS_DEVELOPMENT_GUIDE.md (consolidates bash, Unicode, PowerShell, builds)
- **docs**: Create RECOVERY_CAPABILITIES.md (audit of all destructive operations)
- **docs**: Add Issue Backlog section to ALL_SPRINTS_MASTER_PLAN.md (tracks all open/fixed issues)
- **docs**: Update SPRINT_EXECUTION_WORKFLOW.md Phase 3.3 with pre-testing checklist
- **docs**: Update CLAUDE.md and QUICK_REFERENCE.md to reference new Windows guide
- **chore**: Create test email generators (generate-test-emails.ps1, send-test-emails.py)

### 2026-01-25
- **feat**: Implement SafeSenderDatabaseStore with exception support (Issue #66, Sprint 3 Task A)
- **feat**: Implement SafeSenderEvaluator with pattern matching and exceptions (Issue #67, Sprint 3 Task B)
- **feat**: Update RuleSetProvider to use SafeSenderDatabaseStore (Issue #68, Sprint 3 Task C)

### 2026-01-12
- **test**: Add Flutter integration tests for Windows Desktop UI (Issue #46)
- **feat**: Update Results screen to show folder • subject • rule format (Issue #47)
- **feat**: Add AOL Bulk/Bulk Email folder recognition as junk folders (Issue #48)

### 2026-01-07
- **chore**: Archive memory-bank files, consolidate documentation into CLAUDE.md
- **chore**: Clean up TODO comments, delete obsolete gmail_adapter.dart, create Issue #44 for Outlook
- **docs**: Add coding style guidelines - no contractions in documentation
- **fix**: Replace print() with Logger in production code (Issue #43)
- **fix**: Resolve navigation race condition, configurable test limit, per-account folders (Issues #39, #40, #41)
- **fix**: Strip Python-style inline regex flags (?i) for Dart compatibility (Issue #38)
- **fix**: Remove duplicate @ symbol from 23 safe sender patterns (Issue #38)

### 2026-01-06
- **feat**: Complete Phase 3.3 enhancements and bug fixes
- **chore**: Update .gitignore to exclude local Claude settings and log files
- **feat**: Add Claude Code MCP tools, skills, and hooks for enhanced development workflow
- **fix**: Extract email address from Gmail "From" header for rule matching
- **fix**: Reset _noRuleCount in startScan() to prevent accumulation
- **fix**: Add token refresh to Gmail folder discovery (Issue #37)
- **feat**: Dynamic folder discovery with enhanced UI (Issue #37)
- **feat**: Implement progressive UI updates with throttling (Issue #36)

### 2026-01-05
- **fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress
- **fix**: Folder selection now correctly scans selected folders (Issue #35)

### 2026-01-04
- **docs**: Update documentation for Phase 3.1 completion
- **feat**: Add "No rule" bubble to track emails with no rule match
- **fix**: Bubble counts now show proposed actions in all scan modes
- **fix**: Redesign Results Screen UI to match Scan Progress design (Issue #34)
- **feat**: Redesign Scan Progress UI - remove redundant elements, add bubbles, auto-navigate (Issue #33)
- **feat**: Add Full Scan mode with persistent mode selector and warning dialog (Issue #32)

---

## Version History

### Phase 3.3 - Enhancement Features (January 5-6, 2026)
**Status**: [OK] COMPLETE

**Features**:
- [OK] **Issue #36**: Progressive UI updates with throttling (every 10 emails OR 3 seconds)
- [OK] **Issue #37**: Dynamic folder discovery - fetches real folders from email providers
- [OK] **Gmail Token Refresh**: Folder discovery now uses `getValidAccessToken()` for automatic token refresh
- [OK] **Gmail Header Fix**: Extract email from "Name <email>" format for rule matching
- [OK] **Counter Bug Fix**: Reset `_noRuleCount` in `startScan()` to prevent accumulation across scans
- [OK] **Claude Code MCP Tools**: Custom MCP server for YAML validation, regex testing, rule simulation
- [OK] **Build Script Enhancements**: `-StartEmulator`, `-EmulatorName`, `-SkipUninstall` flags

**Impact**: Improved user experience with responsive UI updates, dynamic folder selection, and enhanced OAuth reliability

---

### Phase 3.2 - Bug Fixes (January 4-5, 2026)
**Status**: [OK] COMPLETE

**Fixes**:
- [OK] **Issue #35**: Folder selection now correctly scans selected folders (not just INBOX)
  - **Problem**: Selecting non-Inbox folders (e.g., "Bulk Mail") still only scanned Inbox
  - **Solution**: Added `_selectedFolders` field to EmailScanProvider, connected UI callback
- [OK] **Navigation Fix**: Prevent unwanted auto-navigation to Results when returning to Scan Progress
  - **Problem**: Returning to Scan Progress from Account Selection caused unwanted auto-navigation
  - **Solution**: Initialize `_previousStatus` in `initState()` before first build

**Files Modified**:
- `email_scan_provider.dart`
- `scan_progress_screen.dart`

---

### Phase 3.1 - UI/UX Enhancements (January 4, 2026)
**Status**: [OK] COMPLETE

**Features**:
- [OK] **Issue #32**: Full Scan mode added (4th scan mode) with persistent mode selector and warning dialogs
  - Added `ScanMode.fullScan` for permanent delete/move operations
  - Added persistent "Scan Mode" button on Scan Progress screen
  - Removed scan mode pop-up from account setup flow (default to readonly)
  - Added warning dialog for Full Scan mode (requires user confirmation)

- [OK] **Issue #33**: Scan Progress UI redesigned
  - Removed redundant progress bar and processed count text
  - Updated to 7-bubble row: Found (Blue), Processed (Purple), Deleted (Red), Moved (Orange), Safe (Green), No rule (Grey), Errors (Dark Red)
  - Added auto-navigation to Results screen when scan completes
  - Re-enabled buttons after scan completes

- [OK] **Issue #34**: Results Screen UI redesigned
  - Added `accountEmail` parameter to show email in title
  - Updated title format: "Results - <email> - <provider>"
  - Updated summary format: "Summary - <mode>"
  - Matched bubble row to Scan Progress (7 bubbles with exact same colors)

- [OK] **Bubble Counts Fix**: All scan modes now show proposed actions (what WOULD happen)
  - Changed `recordResult()` to always increment counts based on rule evaluation
  - Read-Only mode now useful for previewing results

- [OK] **No Rule Tracking**: Added "No rule" bubble (grey) to track emails with no rule match
  - Added `_noRuleCount` field and getter to EmailScanProvider
  - Tracks emails that did not match any rules (for future rule creation)

**Test Results**: 122/122 tests passing

**Files Modified**:
- `email_scan_provider.dart`
- `account_setup_screen.dart`
- `scan_progress_screen.dart`
- `results_display_screen.dart`

---

### Phase 3.0 and Earlier
See git history for detailed changes prior to Phase 3.1.

**Key Milestones**:
- Phase 2.2: Rule evaluation and pattern compiler enhancements
- Phase 2.1: Adapter and provider implementations
- Phase 2.0: AppPaths, SecureCredentialsStore, EmailScanProvider
- Phase 1: Core models, services, and foundation (27 tests)

---

## Version Links

[Unreleased]: https://github.com/kimmeyh/spamfilter-multi/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/kimmeyh/spamfilter-multi/releases/tag/v0.5.0
