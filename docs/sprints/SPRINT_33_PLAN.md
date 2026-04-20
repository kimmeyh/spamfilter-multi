# Sprint 33 Plan - Security Hardening + UX Polish

**Sprint**: 33
**Date**: April 14, 2026
**Branch**: `feature/20260414_Sprint_33`
**Type**: Mixed (Critical security + Tech debt + UX features)
**Estimated Effort**: ~38-66h (multi-session sprint, Path C confirmed)
**Sprint Issue**: TBD (created in Phase 3.5)

---

## Sprint Objective

Address remaining critical security gaps from Sprint 31 audit, add user-facing improvements (Help system, navigation consistency, data deletion), and complete the SEC-1 ReDoS work by integrating runtime protection into the evaluator hot path.

This is a deliberately large sprint (Path C decision) covering both security and UX. Will likely span 2-3 sessions with mid-sprint check-ins.

---

## Sprint Scope (Final)

| # | Item | Severity / Pri | Effort | Model | Notes |
|---|------|----------------|--------|-------|-------|
| 1 | SEC-1b | CRITICAL / 35 | 6-10h | Opus | ReDoS runtime protection (design + integrate safeHasMatch) |
| 2 | SEC-8 | HIGH / 42 | 4-6h | Opus | Cert pinning OAuth + IMAP |
| 3 | SEC-11 | MEDIUM / 60 | 4-8h | Opus | SQLite encryption (SQLCipher) |
| 4 | SEC-14 | MEDIUM / 62 | 2h | Sonnet | Unmatched emails retention + body preview truncation |
| 5 | SEC-19 | MEDIUM / 65 | 1-2h | Haiku | Auth log level control (runtime disable) |
| 6 | SEC-22 | LOW / 80 | 2h | Sonnet | Rate limiting: 10 attempts → 1h delay (per user spec) |
| 7 | F53 | MEDIUM / 60 | 1h | Haiku | Add `.cc` and `.ne` TLD block rules |
| 8 | F54 (revised) | MEDIUM / 64 | 6-10h | Opus | Help system: Help icon every screen + Help screen + content |
| 9 | F55 | MEDIUM / 66 | 4-6h | Sonnet | Navigation consistency + Select Account icon on Manual Scan/Results |
| 10 | F65 | MEDIUM / 45 | <2h | Haiku | Verify Gmail onboarding recommends app passwords (may already be done) |
| 11 | F66 | MEDIUM / 50 | 4-6h | Opus | User data deletion (per-account + full wipe) |
| | **Total** | | **~34-54h** | | |

**Excluded from this sprint** (per planning discussion):
- Android SEC items (SEC-4, SEC-6, SEC-7, SEC-9): Bundle with Issue #163 in dedicated Android sprint
- SEC-15: Blocked by F37 (custom IMAP folder selectors, on HOLD)
- F61: Moved to HOLD (per user direction)
- F72: Defer to Sprint 34 (code hygiene, not urgent)

---

## Task Details and Acceptance Criteria

### Task 1: SEC-1b — ReDoS Runtime Protection (CRITICAL)

**Model**: Opus
**Files**: `lib/core/services/pattern_compiler.dart`, `lib/core/services/rule_evaluator.dart`, `lib/core/services/safe_sender_evaluator.dart`, `lib/core/services/rule_conflict_detector.dart`, new tests

**Background**: Sprint 32 added `safeHasMatch()` and `detectReDoS()` but the evaluator hot path still calls `regex.hasMatch()` directly. SEC-1 is structurally complete but functionally vulnerable.

**Design decision needed (resolve at start of task)**: Choose ONE of:
- **Option A**: Shared isolate/worker pool — fast but complex
- **Option B**: Batch-level timeout (abort entire scan if any match exceeds N seconds) — simple, blunt
- **Option C**: Opt-in per-pattern timeout for user-supplied patterns only (trusted bundled patterns use direct hasMatch) — pragmatic, lowest perf cost

**Recommendation**: Option C (opt-in). Rationale: bundled rules.yaml patterns are known-safe; user-created patterns (from F35/F56 future work) are the actual attack surface. Pay the isolate overhead only when it matters.

**Acceptance criteria**:
- [ ] Design decision documented in PatternCompiler dartdoc
- [ ] User-provided patterns route through safeHasMatch()
- [ ] Trusted bundled patterns continue to use direct hasMatch (perf)
- [ ] PatternCompiler tracks pattern provenance (bundled vs. user-supplied)
- [ ] Tests cover: timeout firing on dangerous user pattern, no perf regression on bundled patterns
- [ ] Existing 1239 tests still pass

---

### Task 2: SEC-8 — Certificate Pinning (HIGH)

**Model**: Opus
**Files**: `lib/adapters/auth/google_auth_service.dart`, `lib/adapters/email_providers/gmail_windows_oauth_handler.dart`, `lib/adapters/email_providers/generic_imap_adapter.dart`

**Implementation**:
- Pin SPKI hashes for: `accounts.google.com`, `oauth2.googleapis.com`, `imap.gmail.com`, `imap.aol.com`, `gmail.googleapis.com`
- Use `dart:io` `SecurityContext` for HTTP, IMAP cert callback for IMAP connections
- Document pin rotation procedure in CLAUDE.md
- Fail closed on pin mismatch, log to security log

**Acceptance criteria**:
- [ ] Connections to pinned hosts succeed with valid certs
- [ ] Tampered cert fails connection with clear error
- [ ] Test against actual servers in dev mode (manual verification)
- [ ] Pin rotation procedure documented

---

### Task 3: SEC-11 — SQLite Database Encryption (MEDIUM)

**Model**: Opus
**Files**: `lib/core/storage/database_helper.dart`, pubspec.yaml (add sqlcipher_flutter_libs or equivalent)

**Implementation**:
- Use `sqlcipher_flutter_libs` + `sqflite_sqlcipher` for transparent SQLite encryption
- Encryption key stored in `flutter_secure_storage` (per-device, generated on first launch)
- Migration: existing unencrypted DB → encrypted DB (copy + verify + replace)
- Backward compatibility: detect unencrypted DB on launch, migrate transparently

**Acceptance criteria**:
- [ ] Fresh installs use encrypted DB from start
- [ ] Existing installs migrate on first launch after upgrade
- [ ] Migration is atomic (no data loss if interrupted)
- [ ] App data inspection (e.g., DB Browser) shows encrypted blob, not readable
- [ ] Tests: encryption/decryption roundtrip, migration from plaintext

---

### Task 4: SEC-14 — Unmatched Emails Retention (MEDIUM)

**Model**: Sonnet
**Files**: `lib/core/storage/unmatched_email_store.dart`, settings to control retention

**Implementation**:
- Auto-cleanup unmatched emails older than N days (default 30, configurable)
- Truncate `body_preview` field to 100 characters when storing
- Run cleanup on app startup and after each scan

**Acceptance criteria**:
- [ ] Body previews capped at 100 chars on insert
- [ ] Old unmatched emails (> retention days) auto-deleted
- [ ] Retention setting in Settings > Privacy
- [ ] Tests: insert oversize body → truncated; old records → deleted

---

### Task 5: SEC-19 — Auth Log Level Control (MEDIUM)

**Model**: Haiku
**Files**: `lib/util/redact.dart`, settings

**Implementation**:
- Add settings toggle: "Disable detailed auth logging in production"
- When toggle ON: `Redact.logSafe()` becomes no-op even in debug builds
- Default: OFF (logs are already debug-only via kDebugMode check)

**Acceptance criteria**:
- [ ] Setting persists across launches
- [ ] When ON, no auth logs appear in console
- [ ] When OFF, current behavior preserved
- [ ] Test: toggle ON → no log output from Redact.logSafe()

---

### Task 6: SEC-22 — Rate Limiting on Failed Auth (LOW)

**Model**: Sonnet
**Files**: `lib/adapters/email_providers/generic_imap_adapter.dart`, `lib/adapters/auth/google_auth_service.dart`, new `lib/core/security/auth_rate_limiter.dart`

**User spec**: 10 failed attempts → 1 hour cooldown.

**Implementation**:
- Per-account counter: failed auth attempts in last 1 hour
- Failed = wrong password / token rejected by server
- After 10 failures within rolling 1-hour window: block further attempts for 1 hour
- Counter persists in DB (survives app restart)
- UI: show clear message with unlock time when blocked

**Acceptance criteria**:
- [ ] 10th failure within 1h triggers 1h block
- [ ] Block expires automatically after 1h
- [ ] Counter resets on successful login
- [ ] Block persists across app restart
- [ ] User sees clear "Too many attempts. Try again at HH:MM" message
- [ ] Tests: 10 failures → blocked, 11th rejected with cooldown msg, after 1h → unblocked

---

### Task 7: F53 — TLD Block Rules (.cc, .ne)

**Model**: Haiku
**Files**: `mobile-app/assets/rules.yaml`, migration in `lib/core/services/default_rule_set_service.dart`

**Implementation**:
- Add `@.*\.cc$` (Cocos Islands) and `@.*\.ne$` (Niger) patterns to bundled `rules.yaml`
- Add migration: insert these rules for existing users on app startup if not present
- Mirror existing `@.*\.ru$` pattern style

**Acceptance criteria**:
- [ ] Bundled rules.yaml contains both patterns
- [ ] Existing user's DB gets the rules added on app launch (idempotent)
- [ ] Tests: rule matches `spam@example.cc` and `spam@example.ne`, doesn't match `spam@example.cca` or `spam@cc.com`

---

### Task 8: F54 (revised) — Help System

**Model**: Opus
**Files**: New `lib/ui/screens/help_screen.dart`, edits to all primary screens' AppBars, new `mobile-app/assets/help/help_content.md` or constants

**User-confirmed design**:
- Help icon (`?`) on every primary screen's AppBar
- Push to Help screen, popping back to origin
- Format: scrollable single page with anchored sections (one section per app screen)
- Content depth: brief tooltips-as-paragraphs (not full walkthroughs)
- Per-screen Help icon deep-links to that screen's section (anchor scroll)

**Screens needing Help icon**:
1. Select Account
2. Account Setup
3. Manual Scan / Scan Progress
4. Results Display
5. Scan History
6. Settings (and tabs: General, Scan, Background, Account Overrides)
7. Manage Rules / Rule Quick Add / Rule Test
8. Manage Safe Senders
9. Folder Selection
10. YAML Import/Export

**Implementation**:
- Define `HelpSection` enum mapping each screen to its anchor
- `HelpScreen(initialSection: HelpSection.X)` scrolls to that anchor on open
- Common AppBar widget or extension to add Help icon consistently
- Initial content drafted for each section (short paragraphs)

**Acceptance criteria**:
- [ ] Every primary screen has a Help icon in AppBar
- [ ] Tapping Help opens HelpScreen scrolled to that screen's section
- [ ] Back button pops HelpScreen, returning to origin
- [ ] Content drafted for all sections (1-3 paragraphs each)
- [ ] Help screen accessible without account context (read-only info)
- [ ] Tests: deep-link to each section works; widget tests for Help icon visibility

---

### Task 9: F55 — Navigation Consistency

**Model**: Sonnet
**Files**: `lib/ui/screens/results_display_screen.dart`, `lib/ui/screens/scan_progress_screen.dart`, `lib/ui/screens/account_setup_screen.dart`

**Bugs to fix**:
1. Results back button uses `pushReplacement` instead of `pop` (breaks stack)
2. "Back to Accounts" button on Results uses `popUntil` (skips Manual Scan) — **KEEP this behavior per user feedback** (useful shortcut)
3. Results → Manual Scan auto-navigation on scan complete uses `pushReplacement` (should be `push`)

**Add**:
- Select Account icon on Manual Scan and Results screens (per user feedback, "needed almost every time")
- Icon target: existing Select Account screen (popUntil to root)

**Acceptance criteria**:
- [ ] Results back button uses `Navigator.pop` (preserves stack)
- [ ] "Back to Accounts" button still works via `popUntil` (intentional shortcut)
- [ ] Manual Scan → Results → back goes to Manual Scan (not Results→Manual Scan with broken stack)
- [ ] Select Account icon present on Manual Scan and Results AppBars
- [ ] Select Account icon navigates back to Select Account screen
- [ ] Existing navigation flows still work (no regressions)
- [ ] Tests: navigation widget tests for stack behavior

---

### Task 10: F65 — Gmail Onboarding Verification

**Model**: Haiku
**Files**: Inspect `lib/ui/screens/account_setup_screen.dart` and onboarding text

**Acceptance criteria**:
- [ ] Inspect current Gmail account setup screen
- [ ] If app passwords are already presented as primary/recommended: close as already done, document
- [ ] If OAuth is presented as primary: update text to recommend app passwords; mark OAuth as "Advanced"
- [ ] Update ADR-0034 status if applicable

---

### Task 11: F66 — User Data Deletion

**Model**: Opus
**Files**: New `lib/core/services/data_deletion_service.dart`, edits to Settings, possibly Account Selection

**Two flows**:

**Per-account deletion** (Settings > Account Overrides > [account] > Delete Account Data):
- Confirmation dialog: "Delete all data for X@aol.com? This includes: scan history, rules customizations, safe sender lists, OAuth tokens. Cannot be undone."
- Removes: account credentials, OAuth tokens, scan results, account-specific settings, unmatched emails for this account
- Preserves: app-wide rules, app-wide settings, other accounts' data

**Full data wipe** (Settings > General > Reset App > Delete All Data):
- Confirmation dialog: "Delete ALL app data? This cannot be undone. App will restart in fresh state."
- Removes: everything (all accounts, all rules, all settings, all DB tables)
- Resets settings to defaults
- Optionally restarts app

**External deletion form** (Microsoft Store / Google Play Store policy compliance):
- Investigation: does Microsoft Store require external (web) deletion form?
- If yes: GitHub Pages stub explaining "App is local-only; uninstall removes all data"
- If no: skip

**Acceptance criteria**:
- [ ] Per-account deletion removes only that account's data
- [ ] Full wipe removes all app data
- [ ] Confirmation dialogs prevent accidental deletion
- [ ] Tests: insert account+data, delete, verify gone; insert multiple accounts, delete one, verify others intact
- [ ] Tests: full wipe leaves DB in fresh-install state
- [ ] Microsoft Store policy researched and documented

---

## Architecture Impact Check (Phase 3.6.1)

**Will affect documented architecture**:
- **SEC-11**: Adds SQLCipher dependency. ARCHITECTURE.md DB section will need update.
- **F54**: Adds new HelpScreen + per-screen Help icons. ARCHITECTURE.md UI section.
- **F66**: Adds DataDeletionService. ARCHITECTURE.md services section.
- **SEC-1b**: Modifies PatternCompiler design (provenance tracking). ARCHITECTURE.md services section.

**Will not affect architecture**:
- SEC-8, SEC-14, SEC-19, SEC-22, F53, F55, F65: Implementation changes within existing patterns.

**Doc updates required at end of sprint**: ARCHITECTURE.md (4 changes above) — bundled into Sprint 33 (not deferred).

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SEC-11 migration corrupts existing data | Low | Critical | Atomic copy+verify+replace; backup before migration; manual test on dev DB |
| SEC-8 cert pinning blocks legitimate connections | Medium | High | Test with actual servers before commit; document pin rotation |
| SEC-1b Option C requires API change to PatternCompiler | High | Low | Caller updates are mechanical; tests catch integration |
| F54 Help system scope creep (more screens, deeper content) | High | Medium | Strict scope: 1-3 paragraphs per section, no walkthroughs |
| Sprint scope too large for one session | Certain | Medium | Plan for 2-3 sessions; commit per-task; mid-sprint check-ins |
| F66 user accidentally wipes data | Medium | Critical | Two-step confirmation; show what will be deleted before delete |

---

## Execution Order

1. **F53** (~1h, Haiku) — fastest item, gets a quick win
2. **F65** (~5min-2h, Haiku) — verify Gmail onboarding state first
3. **SEC-19** (~1-2h, Haiku) — small, isolated
4. **SEC-14** (~2h, Sonnet) — small, isolated
5. **SEC-22** (~2h, Sonnet) — small, isolated
6. **SEC-1b** (~6-10h, Opus) — CRITICAL, design + integrate; do early when context is fresh
7. **SEC-8** (~4-6h, Opus) — security
8. **SEC-11** (~4-8h, Opus) — security with migration risk
9. **F66** (~4-6h, Opus) — features
10. **F55** (~4-6h, Sonnet) — UX
11. **F54** (~6-10h, Opus) — Help system, largest UX item, do late so other screens are stable
12. **Doc updates** — ARCHITECTURE.md per Architecture Impact Check above

**Mid-sprint check-in points**: After items 5, 8, and 11 — pause, status update, verify direction.

---

## Sprint Approval

This plan represents Path C (full scope) per planning discussion on 2026-04-14.

User decisions captured:
- Path C confirmed (mega-sprint, multi-session)
- F54 = full Help system (icon every screen, deep-link, scrollable single page, brief paragraphs)
- F61 → moved to HOLD
- F55 "Back to Accounts" button → KEEP (useful shortcut, even though stack-inconsistent)
- F55 Select Account icon on Manual Scan + Results → ADD (needed almost every time)
- SEC-22 spec: 10 attempts → 1h delay
- Android SEC items (4/6/7/9) → deferred to dedicated Android sprint with Issue #163

Sprint plan approval = pre-authorization for all 11 task implementations through Phase 7 per CLAUDE.md autonomy rules.
