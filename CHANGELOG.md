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

### 2026-06-24 (Sprint 43: F101 -- shorten background-scan DB-lock retry cap)
- **fix**: F101 (Harold direction 2026-06-23) -- the F98 Windows background-scan worker retried a "database is locked" error 1 min x 20 = ~20 min worst case. Capped `_dbLockMaxAttempts` to 15 (delay unchanged at 1 min between attempts, no trailing delay after the final attempt), so a genuinely stuck lock now fails in ~15 min instead of ~20. Constant + comment in `background_scan_windows_worker.dart`. (F101)

### 2026-06-24 (Sprint 43: F100 -- port WinWright read-only flows to integration_test)
- **test**: F100 -- ported the 6 read-only WinWright flows (navigation, settings-tabs, scan-history, text-selection, F25 rule-test, F35 rule-edit) to the in-VM `integration_test` lane as `integration_test/read_only_flows_test.dart`. Each pumps the screen directly against the F99 seeded temp DB and asserts its key content/behavior with `pumpAndSettle()` -- no out-of-process selector-settle flakiness, no live-window dependency. (F100)
- **chore**: F100 -- RETIRED the 6 ported WinWright scripts (`test_navigation`, `test_settings_tabs`, `test_scan_history`, `test_text_selection`, `test_f25_rule_test_tool`, `test_f35_rule_edit`); their coverage now lives in the integration_test lane. The WinWright default sweep is now empty; only the create/lifecycle reference scripts (`test_f56_*`, `test_f37_folder_selector`, already excluded from the sweep) remain. Updated `test/winwright/README.md`. (F100)

### 2026-06-24 (Sprint 43: F96 -- auth-state coverage for off-scan quick-add paths)
- **feat**: F96 -- the F89 anti-phishing RED warning now fires on the historical (Scan History reload) and email-detail quick-add paths, not just live scans. SPF/DKIM/DMARC authentication is only present in headers during a live scan; the off-scan paths reconstruct the email from the database with only From/Subject, so they previously always classified GREY and could never surface the RED "sender failed authentication" warning. The classification (GREEN/YELLOW/RED/GREY) is now captured at scan time and re-hydrated on those paths. (F96)
- **feat**: F96 (DB v8) -- added nullable `auth_classification` TEXT to both `email_actions` and `unmatched_emails`. Captured in `EmailScanProvider._persistEmailActions` from the live-scan headers; re-hydrated via the new `EmailMessage.authClassificationOverride` (history path) and `UnmatchedEmail.authClassification` (email-detail path). Per the Sprint 43 Class-1 decision, only the classification enum is persisted (not the raw `Authentication-Results` headers); a re-hydrated RED warning therefore fires but cannot reproduce the original per-protocol breakdown (a synthetic result drives the dialog). Rows scanned before v8 are null and fall back to GREY (pre-F96 behavior). (F96)
- **feat**: F96 -- the inline `_addSafeSender` on the Scan History reload path now gates whitelisting behind the RED `AuthWarningDialog` (it previously had no auth gate at all). New `AuthResultsParser` helpers: `classificationFromName`, `classificationToName`, `syntheticResultFor`. (F96)
- **test**: F96 -- new `f96_auth_classification_column_test.dart` (fresh-DB columns, round-trips, v7->v8 ALTER) and parser-helper tests in `auth_results_parser_test.dart`. (F96)

### 2026-06-23 (Sprint 43: F102 -- logging redaction policy + enforcement gate)
- **docs**: F102 -- codified the logging-redaction invariant as ADR-0030 "Logging & Redaction": never log raw account ids / email / tokens / email content; use the `Redact` utility. Applies to `Logger`, the headless `_bgLog`, and generated artifacts (PowerShell scripts, Task Scheduler task names). Cross-referenced in ARCHITECTURE.md "Sprint 33 Security Layers". (F102)
- **chore**: F102 -- enforcement gate. New `mobile-app/scripts/check-log-redaction.ps1` (build-failing CLI, `-SelfTest` 8/8) AND a Dart test `test/policy/log_redaction_test.dart` that fails `flutter test` when any `lib/` log call interpolates a raw account id / email / token without `Redact.*` (excludes non-PII like `$emailId` row ids and counts). Added a Phase 5 checklist line (5.1.7). (F102)
- **fix**: F102 -- the new gate caught + fixed 13 pre-existing PII-in-log leaks the Sprint-42 review missed: sender email in `safe_sender_evaluator` (x4), `${account.email}` in `account_maintenance_screen` (x5), raw account id in `background_scan_worker`, `$email` in `pattern_normalization`, `${email.fromEmail}` in `process_results_screen`, and an access-token reference in `folder_selection_screen` -- all now redacted. (F102)

### 2026-06-20 (Sprint 42: BUG-S37-2 -- bundled-rule TLD data quality)
- **fix**: BUG-S37-2 -- removed two more malformed bundled TLD block rules (`.sho`, `.sweeps`); neither is a registered IANA TLD (the Sprint-39 note that `.sweeps` was a "correct spelling" was wrong). Removed from the bundled `rules.yaml` for fresh installs and via a DB v7 migration for existing installs (same JSON-decode-then-delete approach as the v6 BUG-S37-2 cleanup). **ccTLD audit (Harold decisions 1c + 2a)**: the bundled list already blocks 247 of 248 IANA ccTLDs (only `.us` is unblocked), so NO ccTLD expansion or allow-list change was needed -- the bundled blocklist is an initial load the user overrides per-account via safe-sender rules. Updated the fresh-seed cleanliness test to assert `.sho`/`.sweeps` absence. (BUG-S37-2)

### 2026-06-20 (Sprint 42: F98 -- per-account background scanning, ADR-0039 implementation)
- **feat**: F98 (ADR-0039) -- background scanning is now configured **per account** instead of one app-wide global switch. Each enabled account gets its own OS-level scheduled entry running at its own frequency (Locked Decision 2: one task per enabled account). Windows: one Task Scheduler task per account named `SpamFilterBackgroundScan_<sanitizedAccountId><suffix>`, launched with `--background-scan --account-id=<id>`. Android: one WorkManager unique periodic task `background_scan_task::<accountId>` carrying the accountId in `inputData`. The Settings > Background tab now writes the per-account `background_enabled` / `background_frequency` overrides; the worker scans exactly the one account named on the command line / work input. (F98)
- **feat**: F98 one-time migration (Locked Decision 1: preserve today's behavior) -- on first launch after upgrade, if the global `background_scan_enabled` was ON, every saved account without an explicit override inherits enabled + the global frequency; accounts with an explicit override are left untouched. Idempotent, sentinel-guarded (`per_account_bg_migration_done`), no `ALTER TABLE` (Option A: `account_settings` key-value rows). Startup reconciliation ensures/repairs each enabled account's task, removes tasks for disabled accounts, and cleans up the legacy global task + orphaned per-account tasks. (F98)
- **fix**: F98 consolidates the divergent per-account enable keys -- the Android worker previously queried the dead key `background_scan_enabled` while the writer stored `background_enabled`, so the Android per-account check never fired. Both now use `SettingsStore.getEffectiveBackgroundEnabled` (canonical `background_enabled`). (F98)
- **chore**: F98 -- shared `sanitizeAccountId` helper (`@`->`_at_`, `.`->`_`) so the Task name, log filename, and CSV/XLSX filename derive the same token; per-account log filename `{prefix}background_scan_<sanitizedAccountId>_v0.5.3.log` so concurrent per-account runs do not interleave. 12 unit tests (CLI parse, task names, per-account frequency resolution, migration: inherit/preserve-override/global-off/idempotent). (F98)

### 2026-06-20 (Sprint 42: F99 -- Flutter integration_test E2E harness)
- **test**: F99 -- stood up the Flutter `integration_test` E2E harness as the in-VM second lane alongside WinWright. Added the `integration_test` dev-dependency and `integration_test/helpers/app_harness.dart`. **DB isolation**: the harness drives against an isolated temp data directory, never the dev DB. Two boot modes: `bootDbOnly` (preferred -- seeds a fresh temp DB with the bundled rules and pumps the specific screen under test; does NOT boot the full app) and `bootAppWithDevDbCopy` (boots the full `SpamFilterApp` against a copy of the dev DB, deleted on teardown -- Harold's "copy the DB, test on the copy" pattern). Verified the DB initializes under `%TEMP%\spamfilter_it_*`, not `MyEmailSpamFilter_Dev`; a `_assertTempDataPath` guard hard-fails if isolation ever resolves outside temp. (F99) [Final shipped API/scope -- 5 test files + per-file runner -- is in the 2026-06-20 F99 completion entries below.]
- **chore**: F99 -- added `AppPaths.testOverrideBaseDir` (test-only static seam, null in production). Required because `RuleSetProvider.initialize()` constructs its own `AppPaths()` and path_provider has no MethodChannel on Windows desktop, so neither `DatabaseHelper.setAppPaths()` nor channel-mocking isolates the app's data dir; the override makes the WHOLE app resolve its data dir to the test temp path. No production behavior change. (F99)
- **test**: F99-c -- rule create+delete lifecycle test (`integration_test/rule_lifecycle_test.dart`), the flow WinWright F56 could not run reliably. Drives the Add-Block-Rule screen in-VM: select Top-Level-Domain, enter a real IANA TLD chosen at runtime as one absent from the seeded rules, scroll the (ListView-lazy, off-screen) Save Rule button into view, tap it, then tap the SETTLED confirm dialog's Save (the WinWright failure point -- no settle race in-VM), verify the row persisted, delete it, verify gone. Added keyed widgets (`lib/ui/testing/widget_keys.dart`: `saveRuleButton`, `confirmDialogSaveButton`) on `ManualRuleCreateScreen`. (F99-c)
- **test**: F99 -- runner `scripts/run-integration-tests.ps1` invokes each `integration_test/*_test.dart` in its OWN `flutter test` process (Harold direction 2026-06-20). The app's process-wide singletons (`DatabaseHelper`, the fire-and-forget `RuleSetProvider.initialize()` async tail) bleed across files in a single shared `flutter test integration_test/` process; per-file processes are the standard Flutter isolation pattern for stateful apps. Within a file, multiple `testWidgets` share one process and reset via the harness -- NO app shutdown between tests (unlike the WinWright lane, which relaunches per script only because `winwright run` force-closes the app). (F99)

### 2026-06-13 (Sprint 41: F83 Phase 1 per-account bg-scan ADR + F97 WinWright F56 scripts + F76 visual regression)
- **docs**: ADR-0039 (per-account background scanning) added under `docs/adr/`. F83 Phase 1 deliverable: enumerates every site where the global `background_scan_enabled` setting is read, written, or assumed (Settings UI, `app_settings` DB key, Windows Task Scheduler service, Android WorkManager task, PowerShell script generator, `--background-scan` CLI arg, log/export paths, Help text) and proposes the per-account schema, scheduling, and task-naming convention. Includes the F98 implementation change-site table so F98 can be minute-estimated. Research + design only -- no implementation, no schema migration this sprint. Accepted by Harold (Chief Architect, Class-1 signoff) 2026-06-15; F98 implementation now eligible for Sprint 42. (F83 Phase 1)
- **test**: F97 -- authored the 2 deferred F56 create+delete lifecycle scripts (`test_f56_create_block_rule.json`, `test_f56_create_safe_sender.json`) to the current `testCases` schema, with the Add-Block-Rule input format confirmed live (TLD `museum` into `Edit[name*='Enter TLD']` after selecting the Top-Level-Domain radio Group; confirm `Button[name='Save']`; search -> details -> Delete x2 teardown). Reliable UNATTENDED execution is moved to F99 (Flutter `integration_test`): the scripts fail intermittently under WinWright out-of-process UIA (`Save` resolves 0 elements pre-settle; the script-runner has no `ww_wait`/`ww_assert` to bridge the settle, and `SetCursorPos`/animation races appear on 4K/DPI). The `.json` files remain as the F99 reference flow and are EXCLUDED from the default `run-winwright-tests.ps1` sweep (run explicitly with `-TestName f56`). (F97 -> F99)
- **test**: `test_f37_folder_selector` (Sprint-40 read-only script) also moved to F99 and excluded from the default sweep -- it hits the same Flutter dialog-settle race (the folder picker's `Edit "Search folders..."` is not in the UIA tree yet when the next step fires; resolves fine once settled). With f56 and f37 excluded, the default `run-winwright-tests.ps1` sweep is green at 6 read-only scripts (navigation, settings_tabs, scan_history, text_selection, f25_rule_test_tool, f35_rule_edit) with `DB Drift: none`. (F37 -> F99)
- **chore**: F76 (WinWright visual-regression) -- ABANDONED and folded into F99 (Flutter `integration_test` harness, pre-MVP). A tooling investigation (2026-06-17) proved the standalone WinWright CLI cannot read element `BoundingRectangle`: its commands are only `mcp | serve | run | heal | inspect | doctor` (no `get_attribute`), `inspect <pid>` JSON has no bounds fields, and the `run` script-runner rejects `ww_get_attribute`/`ww_assert*`. The non-working Sprint-41 artifacts (`winwright-visual-check.ps1`, the `-VisualCheck`/`-TestVisualOnly` runner wiring, and null baseline JSON) were reverted. Layout/alignment regression detection is delivered in F99 via golden-image + `RenderBox` assertions. (F76 -> F99)

### 2026-06-09 (Sprint 40: F79 -- WinWright E2E scripts re-ported + harness app-lifecycle fix)
- **test**: Re-authored the WinWright E2E scripts to the current `testCases` recorded-script schema. The Sprint 34 scripts used a legacy `{name, steps:[{action}]}` format that the installed WinWright `run` no longer parses (it silently reported `0 total`). The 7-script suite now runs unattended and green with zero net DB drift: 4 ported (`navigation`, `settings_tabs`, `scan_history`, `text_selection`) plus 3 new Sprint-40-UI coverage scripts (`f25_rule_test_tool`, `f35_rule_edit`, `f37_folder_selector`), all read-only with selectors verified against the live UI. (F79)
- **fix**: `run-winwright-tests.ps1` now launches a fresh dev-app instance at the home screen before each script. `winwright run` closes the app under test at end-of-run (on both pass and fail), so the original "one long-lived app shared across all scripts" design was unworkable -- script #1 closed the app and #2-#7 failed "no process". The runner defensively kills any stray instance, launches fresh, waits for the window, then runs; a post-sweep teardown ensures none lingers. (F79)
- **docs**: Rewrote `mobile-app/test/winwright/README.md` with the current schema, the per-script app-lifecycle model, the verified selector map (`_SELECTOR_MAP_2026-06-05.md`), and the authoring rules (action-only steps; `ww_invoke` for Back/animating buttons; no `ww_wait`/`ww_assert` steps; ambiguous `name='Close'` warning). (F79)
- **chore**: Deferred the 2 F56 create+delete lifecycle scripts and `manual_scan_flow` to follow-up F97 (Sprint 40 rule-creation rework changed the Add-Block-Rule input validation so the old TLD inputs no longer validate; `manual_scan_flow` ran a real network scan unsuitable for an unattended sweep). (F79 / F97 backlog)

### 2026-06-03 (Sprint 40 manual testing: BUG-S40-1 -- AOL silent move/delete failure)
- **fix**: BUG-S40-1 -- delete and move actions on AOL no longer silently leave messages behind or report false successes. Root cause (confirmed by source + RFC research, see `docs/research/BUG-S40-1-aol-uid-move.md`): AOL/Yahoo implement the IMAP MESSAGELIMIT extension (RFC 9738), under which a `UID MOVE` exceeding the server's per-command limit moves only a SUBSET, returns a tagged `OK` (not an error), and reports the unprocessed remainder in a `[MESSAGELIMIT n lowestUid]` response code. `enough_mail` 2.1.7 does not parse that response code, and the adapter sent all delete UIDs in a single un-chunked `UID MOVE`, so the unmoved tail was silently dropped and the same messages reappeared on every subsequent scan (a delete-loop). Observed 2026-06-03 on `kimmeyharold@aol.com`: scan 1 reported 482 deleted but 271 remained in Bulk Mail and were re-"deleted" on scan 2 (same IMAP UIDs -- true survivors, distinct from F91's re-injected new-UID copies). Fix in `GenericIMAPAdapter.moveToFolderBatch`: move in small chunks (50 UIDs) with a 250 ms inter-chunk delay to respect AOL/Yahoo rate limits; after each chunk re-search the source folder (`UID SEARCH`) to confirm the UIDs actually left; sweep the folder for up to 6 passes re-moving any survivors until none remain; abort early on a no-progress pass. UIDs still present after all passes are recorded as genuine FAILURES. New pure helpers `chunkUids` (6 unit tests) and `partitionByMoveSurvival` (5 unit tests) plus `_uidsStillPresent` verification search and `_moveFolderChunkedWithRetry`. Affects delete, moveToJunk, and safe-sender move (all route through `moveToFolderBatch`); non-AOL providers that complete a move on the first chunk are unaffected. (BUG-S40-1)

### 2026-05-30 (Sprint 40: F37 -- Folder selectors two-level listing + per-provider path separator)
- **feat**: Default Folders selector now renders a two-level collapsible tree (ExpansionTile, depth-2) so nested IMAP mailboxes group under their parent. Parent container rows are expand-only (no selection checkbox): IMAP parent containers are commonly `\NoSelect` on the server, so allowing parent selection would produce silent scan failures. (F37 Part A)
- **feat**: Safe Sender and Deleted-Rule single-select folder pickers now order the provider's canonical default first (`reorderForSingleSelect`: INBOX, then Trash, then alphabetical), so the most common target is the top choice. (F37 Part B)
- **feat**: Folder path-separator is detected per provider instead of being hardcoded to `/`. New `FolderInfo.hierarchyDelimiter` field (defaults to `/` for backward compatibility) is populated from the `enough_mail` `Mailbox.pathSeparator` returned by the IMAP LIST response for `GenericIMAPAdapter`; Gmail and mock adapters keep `/`. No new dependency. (F37 Part C)

### 2026-05-30 (Sprint 40: F35 -- Rule editing UI with regex generation)
- **feat**: Existing rules can now be edited from Manage Rules via a new "Edit" action (`RuleEditScreen`), next to the F25 "Test" action. The editor is dual-mode: guided plaintext-to-regex generation (reusing `ManualRulePatternGenerator`) or direct-regex editing with ReDoS and syntax validation, plus live pattern preview and metadata editing. Save preserves the rule name (database primary key). (F35)
- **fix**: `RuleSetProvider.updateRule` now rethrows on a UNIQUE-constraint violation instead of silently swallowing it, mirroring the BUG-S39-2 `addRule`/`addSafeSender` discipline. (F35)

### 2026-05-30 (Sprint 40: F25 -- Rule testing UI enhancements)
- **feat**: The Test Rule Pattern tool (Settings > Tools) pre-populates its match-against list from Demo Scan data, with a fallback when the database result is empty or unavailable (amber banner indicates demo data). (F25)
- **feat**: The Test tool can convert plain text to a regex pattern on Test via a checkbox above the input field, reusing the shared pattern generator; the generated regex is surfaced below the field. (F25)
- **feat**: Manage Rules can open an existing rule directly in the Test tool (new "Test" action in the rule-details dialog), mapping the rule's pattern category to the test tool's condition type. (F25)
- **chore**: Extracted the regex-generation building blocks out of `ManualRuleCreateScreen` into a new public `ManualRulePatternGenerator` utility (`generateTopLevelDomain`, `generateEntireDomain`, `generateExactDomain`, `generateExactEmail`, `generateFromPlaintext`) so the create flow, edit flow (F35), and test tool share one implementation. (F25)

### 2026-05-30 (Sprint 40: F75 -- Help walkthrough: end-to-end first-use guide)
- **feat**: Added an end-to-end first-use walkthrough reachable from the Help screen, authored as a Markdown asset (`assets/content/help/walkthrough.md`) loaded via the content manifest per ADR-0038 (not inline Dart). Covers install -> Demo scan -> read-only manual scan -> tuning safe senders/rules -> switch to move-all and re-scan -> ongoing daily background scanning -> how often to process "no rules", including the pattern recommendation hierarchy (Entire Domain / Exact Email / TLD-last-resort). (F75)

### 2026-05-30 (Sprint 40: F78 -- Widget tests for ManualRuleCreateScreen rendering)
- **test**: Added 11 `testWidgets` cases covering `ManualRuleCreateScreen` rendering: rule-type radio selection, input-field validation feedback, pattern-preview rendering, and the confirmation dialog. Reuses the Sprint 39 S38-CI-6 `runAsync` sqflite_ffi workaround. (F78)

### 2026-05-25 (Sprint 39: F91 -- AOL copy-not-move source-folder dedup)
- **feat**: Post-safe-sender-move source-folder dedup ("AOL copy-not-move" reconciliation). When a safe-sender email is rescued out of a source folder (for example AOL Bulk Mail) into INBOX, AOL's classifier re-injects a COPY with a new IMAP UID but the same RFC 5322 Message-ID. The scanner now searches the source folder for that Message-ID after the move and removes the re-injected copy to Trash (recoverable), preventing the rescue-loop and source-folder clutter. Dedup is skipped when the Message-ID was not captured, on Gmail OAuth (label-based, not folder-based), and when the source folder equals the target. A new "+N dup removed" summary chip surfaces the count only when greater than zero. (F91)
- **feat**: Capture the RFC 5322 `Message-ID` header into `EmailMessage.messageIdHeader` for IMAP (`GenericIMAPAdapter`) and Gmail (`GmailApiAdapter`) fetches; persisted on the `email_actions` table via a new DB v6 migration (`rfc5322_message_id`, nullable TEXT; existing rows null). (F91)

### 2026-05-24 (Sprint 39 warmup round 3: PR #259 Copilot review fixes)
- **fix**: PII redaction on the always-on live-scan log -- SCAN START, SCAN COMPLETE, and SCAN FAILED lines now use `Redact.accountId(accountId)` (e.g., `u***@example.com`) instead of writing the raw email to disk; Step 2 "Credentials loaded for" now uses `Redact.email(credentials.email)`. Matches the redaction pattern already in use in `BackgroundScanWindowsWorker._bgLog`. Live-scan log may be shared in bug reports, so default-PII-redacted is the right shape. (Copilot review on commit `840c6ea`, comments 1 + 4 + 5)
- **fix**: `LiveScanLogger.getLogDir()` and `LiveScanLogger.log()` now use `path.join` instead of hard-coded `\\` separators. Pre-fix, on Android (or any non-Windows platform), `'{appSupport.path}_Dev\\logs'` would create a literal `files\logs` directory name on the Linux filesystem rather than a nested `logs/` directory. `BackgroundScanWindowsWorker` is Windows-only so its hardcoded backslashes are intentional, but live scans run on every platform. (Copilot review on commit `840c6ea`, comment 2)
- **docs**: `SettingsStore.defaultLiveScanDebugCsv` docstring corrected -- the prior comment said "default true in dev and false in prod" but the constant is `false` in both environments and the unit test asserts the false default. Updated the comment to match actual behavior (default false in both; users opt in via the new Settings > Manual Scan tab Debug toggle). (Copilot review on commit `840c6ea`, comment 3)
- **docs**: New backlog item **F92** added to `docs/ALL_SPRINTS_MASTER_PLAN.md` (Priority 50, ~2-3h) -- dedicated tests for `LiveScanLogger` covering `getLogDir()` env-aware path + cross-platform separator, `log()` silent-on-IO-failure + append semantics, `exportCsvIfEnabled()` gating + CSV/XLSX regeneration on multi-scan accumulation. Implementation needs `path_provider` test mock pattern. Deferred because file-IO tests require a non-trivial test harness setup and the F90 functional behavior is already verified by manual smoke testing in PR #259 round 1. (Copilot review on commit `840c6ea`, comment 6)

### 2026-05-24 (Sprint 39 warmup round 2: F90 verbosity + BUG-S39-1 + BUG-S39-2 fixes + Settings UI)
- **feat**: F90 extended -- per-step `LiveScanLogger.log(...)` calls added throughout `EmailScanner.scanInbox` mirroring the verbosity of `BackgroundScanWindowsWorker._bgLog`. Live-scan log now captures: Step 1 platform adapter loaded, Step 2 credentials loaded + IMAP/provider connected, Step 2.5 deletedRuleFolder, Step 4 per-folder fetch results (and per-folder exceptions), Step 4 COMPLETE total messages, Step 5 rules + safe senders loaded, Step 6a evaluation summary (none/delete/moveToJunk/safeSender counts), Step 6b batch sizes + target folder, Step 6b-1 safe-sender move results + per-id failures + entire-batch exceptions, Step 6b-2 delete batch + failures + exceptions, Step 6b-3 moveToJunk batch + failures + exceptions. Previously logged only SCAN START / SCAN COMPLETE / SCAN FAILED. Sourced from 2026-05-24 testing feedback: "Log includes simple data, but not enough for debugging".
- **feat**: F90 -- Settings > Manual Scan tab now has a "Debug" section with an "Export CSV After Each Scan" toggle, mirroring the existing Background tab Debug section. Toggle wired to the `live_scan_debug_csv` app setting (default off). Previously the setting was reachable only via the SettingsStore API.
- **fix**: BUG-S39-1 -- `results_display_screen.dart._createBlockRule` rule-name generator no longer collapses `_`, `-`, `@`, `.` into `_`. New `_sanitizeForRuleName` helper preserves those four characters and replaces only whitespace/punctuation/non-ASCII with `_`. Pre-fix the lossy `[^a-zA-Z0-9]` -> `_` substitution produced identical rule names for distinct addresses like `account_update@amazon.com` (phishing) and `account-update@amazon.com` (legitimate). Combined with the UNIQUE constraint on `rules.name`, a second insert hit a UNIQUE-constraint violation. Sourced from 2026-05-23 bug 2 investigation. Also bumped Subject rule-name length cap from 20 to 40 chars while in there. (BUG-S39-1)
- **fix**: BUG-S39-2 -- `RuleSetProvider.addRule` and `addSafeSender` now RETHROW the underlying exception after setting the internal `_error` state, instead of swallowing silently. UI callers (the try/catch in `_createBlockRule` / `_addToSafeSenders`) already display a red "Failed to create rule" / "Failed to add safe sender" snackbar on the exception path -- but the pre-fix silent swallow meant the catch never fired, and the user saw a green "Created rule" snackbar despite no row being inserted. Second line of defense behind BUG-S39-1: even if any future rename collision or other constraint violation occurs, the user now sees the actual failure. (BUG-S39-2)
- **test**: 2 new tests in `mobile-app/test/unit/providers/rule_set_provider_test.dart` -- one for `addRule` rethrow on UNIQUE collision and one for `addSafeSender` rethrow on duplicate pattern. Test count 1458 -> 1460.

### 2026-05-23 (Sprint 39 warmup: F90 live-scan logging shipped)
- **feat**: F90 -- live-scan logging parity with background-scan logs. New `LiveScanLogger` service (`mobile-app/lib/core/services/live_scan_logger.dart`) writes a runtime log at `{logs}/{prefix}live_scan_v0.5.3.log` (always on -- tiny, scan start/complete events only) and an opt-in per-account per-day CSV + XLSX at `{logs}/live_scan_{email}_{date}{_dev}.data.csv` (gated by new `live_scan_debug_csv` app setting, default off). `EmailScanner.scanInbox` logs SCAN START (platformId, accountId, daysBack, folders, scanMode) and SCAN COMPLETE (found, processed, deleted, moved, safe, noRule, errors). Demo + background scans skip the logger (demo has no operational value; background already has `_bgLog`). Required for F91 debugging visibility and for any future post-build investigation that today relies on stdout (lost when app closes).
- **feat**: New `SettingsStore.getLiveScanDebugCsv` / `setLiveScanDebugCsv` paralleling `getBackgroundScanDebugCsv`. Defaults to false. UI surface (Settings > Manual Scan tab) to be added separately if Harold wants the user-facing toggle; for now the setting is reachable via the SettingsStore API.
- **test**: 3 new tests in `mobile-app/test/unit/storage/settings_store_test.dart` covering default value, persistence round-trip, and independence from the background-scan CSV setting. Test count 1455 -> 1458.
- **chore**: Backed out F90's status in `ALL_SPRINTS_MASTER_PLAN.md` from backlog -> shipped this sprint warmup. F91 (AOL copy-not-move dedup) is now unblocked for log-driven verification and is still tracked as a backlog candidate.

### 2026-05-23 (Sprint 39 backlog refinement: F90 live-scan logging + F91 AOL copy-not-move dedup)
- **docs**: New backlog item **F91** added to `docs/ALL_SPRINTS_MASTER_PLAN.md` (Priority 85, ~4-6h) -- post-safe-sender-move source-folder dedup to reconcile AOL's apparent "copy-not-move" classifier re-injection. After a `UID MOVE` to the safe-sender target folder succeeds, capture the moved message's RFC 5322 `Message-ID`, re-SELECT the source folder, `UID SEARCH HEADER Message-ID <id>`, and if a duplicate is found delete it to the configured `deletedRuleFolder` (Trash). Two-phase: Phase 1 captures `Message-ID` into a new `email_message.messageIdHeader` field + new `email_actions.rfc5322_message_id` column (DB v6 migration); Phase 2 wires the post-move dedup in EmailScanner's Phase 6b-1 with a new `_safeSenderDedupCount` summary chip sub-line. Sourced from 2026-05-23 manual testing on `kimmeyharold@aol.com`: same logical safe-sender emails (Toyota dealer "Happy Birthday", Pocket "Four new things") appeared with new UIDs each scan in Bulk Mail; Harold confirmed visually the originals ARE landing in INBOX, AND a duplicate is being re-injected into Bulk Mail. Root cause hypothesis: AOL's server-side spam classifier re-evaluates the message on appearance-in-INBOX and copies it back. Existing safe-sender behavior for providers that don't re-inject (Gmail OAuth, other IMAP variants) is unchanged -- dedup is a no-op when the source-folder search returns empty.
- **docs**: New backlog item **F90** added to `docs/ALL_SPRINTS_MASTER_PLAN.md` (Priority 80, ~3-4h) -- live-scan logging parity with background-scan logs. Today the app captures NO persistent live-scan logs to disk; live-scan output goes to stdout/stderr only and is lost when the app closes. Background scans write `{logs}/background_scan_v{version}.log` (worker process status) AND per-account `background_scan_{email}_{date}.data.csv` (per-message disposition). F90 wires the same dual-log pattern for live scans -- runtime log for cross-account events, per-account-per-day CSV for per-message disposition. Required for debugging F91 (need the live-scan log to verify the dedup is firing and to capture the IMAP transaction sequence for any future AOL-classifier-related issues). F91 depends on F90 for log-driven verification.
- **chore**: Investigation notes from 2026-05-23 retained in conversation history; root-cause findings carried into F91 spec. No code changes this round -- F90/F91 ship in Sprint 39 (or 40) per backlog refinement.

### 2026-05-21 (Sprint 39 backlog refinement: F89 surface auth-failure on quick-add)
- **docs**: New backlog item **F89** added to `docs/ALL_SPRINTS_MASTER_PLAN.md` -- surface SPF/DKIM/DMARC authentication-failure on every "add rule / add safe sender" quick-add prompt (RuleQuickAddScreen, SafeSenderQuickAddScreen, results_display inline affordances, email_detail inline affordances). Two-phase: Phase 1 adapter side populates `Authentication-Results` into `EmailMessage.headers`; Phase 2 UI side shows a colored auth badge and gates RED-state saves behind a confirmation dialog. RED-state dialog must explain in plain English **what specifically failed per protocol, why that matters for THIS quick-add action, and what alternatives to consider** -- the user must not need external research to interpret the warning. New DB v6 migration adds `created_with_auth_state` columns on `rules` + `safe_senders` for post-hoc audit. Sourced from 2026-05-21 manual triage of an Amazon-spoofed phishing email that was admitted by an overly-broad `@amazon.com` safe-sender pattern; AOL had already flagged the email Bulk, but the app overrode that judgment.

### 2026-05-19 (Sprint 38 Phase 7 follow-up: Copilot final-review nits)
- **docs**: `database_helper.dart` schema-version doc-comment extended with v4 (`last_history_id`, Sprint 37 F6c Phase 2) and v5 (`account_folder_cursors`, Sprint 38 F6c Phase 2 IMAP extension) entries. The constant `databaseVersion = 5` was correct; only the header comment was stale. (Copilot review on commit `a2dc68c`, comments 4 + 6)
- **docs**: `database_helper.cursorTypeImapUid` dartdoc corrected -- the prior comment claimed "we clean up any Round 1 rows on first launch" but no such cleanup exists. The constant is retained so the v5 table schema continues to accept legacy `imap_uid` rows that may have been written by Sprint 38 dev builds prior to the Round 4 redesign; new code uses `cursorTypeOldestNoRuleUid` exclusively. Production builds never wrote Round 1 rows. (Copilot review on commit `a2dc68c`, comment 4)
- **docs**: `main.cpp` `SPAMFILTER_APP_ENV` fallback now documents the rationale -- the "dev" fallback when the compile-time macro is undefined is intentional per Sprint 37 F52 design, so `flutter build windows` invoked directly (without `scripts/build-windows.ps1`) still produces a usable dev binary. Prod builds go through documented paths (`build-windows.ps1 -Environment prod`, `docs/STORE_RELEASE_PROCESS.md`) that always set `SPAMFILTER_APP_ENV=prod` before CMake configures. (Copilot review on commit `a2dc68c`, comment 2)
- **docs**: `copy_all_shortcut.dart` `Focus(autofocus: true)` now documents the focus-tree interaction with descendant `TextField`s (search bars on Manage Rules / Manage Safe Senders). When focus moves to the search EditableText, its built-in Ctrl+A handler wins because it is lower in the focus tree. Verified Sprint 38 Phase 5.3 manual testing. (Copilot review on commit `a2dc68c`, comment 3)
- **docs**: `PRESENTATION_FRAMEWORK.md` double-space typo "Chief  Test Engineer" -> "Chief Test Engineer" in the human-team role table. (Copilot review on commit `a2dc68c`, comment 1)
- **fix**: `scan_progress_screen.dart` `_startRealScan` now surfaces a user-visible snackbar warning when the 2s rule-set-ready poll deadline expires -- previously the scan would start silently with the previously-loaded rules. The new snackbar reads "New rules still loading -- scan will use previously-loaded rules. Re-scan when ready to apply the new rules." (Copilot review on commit `a2dc68c`, comment 5)
- **docs**: PR #258 description updated to reflect the F86 Round 1 redesign (post-scan reload, not per-message rebuild). The original Task 5 description claimed mid-scan rebuild at next message boundary; the shipped behavior reloads after `completeScan()` and after inline rule-add. The CHANGELOG was already accurate (2026-05-16 Round 1 entry); only the PR body needed correction. (Copilot review on commit `a2dc68c`, comment 7)

### 2026-05-18 (Sprint 38 Phase 7 follow-up: CLAUDE.md size reduction below 40K)
- **chore**: Reduced `CLAUDE.md` from 46,220 -> 38,747 bytes (16% reduction; 1,253-byte buffer below 40K threshold) while preserving full content via pointers. Three extractions applied (A, B, D from Harold's review):
  - **A**: "Changelog Policy" section moved to new `docs/CHANGELOG_POLICY.md` (full GitFlow / Adding Entries / Releasing / Best Practices). CLAUDE.md now carries a 1-paragraph quick-rule + pointer.
  - **B**: "Model-Version Pitfalls (Living Appendix)" section moved to new memory entry `feedback_opus_pitfalls.md` (Opus 4.7 fully populated; Opus 4.6 placeholder for Sprint 39 IMP-8 side-by-side). CLAUDE.md now carries a 2-paragraph pointer; memory is auto-loaded at session start.
  - **D**: Merged the two `## Development Workflow` sections (lines 57 and 635 pre-edit) into one consolidated section at line 57; deleted the duplicate.
- Skipped C/E/F proposals at Harold's direction.
- **docs**: Sprint 38 retrospective complete with 4 roles x 14 categories. 10 improvements proposed (IMP-1 through IMP-10); all 10 approved for "Now" application before Sprint 39. (`docs/sprints/SPRINT_38_RETROSPECTIVE.md`, `docs/sprints/SPRINT_38_SUMMARY.md`)
- **docs**: Master plan updated -- "Last Completed Sprint" set to Sprint 38; "Past Sprint Summary" row added; Sprint 39 carry-ins (S38-CI-1 through S38-CI-7) loaded into "Next Sprint Candidates". (`docs/ALL_SPRINTS_MASTER_PLAN.md`)
- **chore (IMP-2)**: `docs/SPRINT_STOPPING_CRITERIA.md` Criterion 9 clarified: wall-clock hours are NOT a stop signal by themselves; only stop on time if total sprint estimate exceeds 400 wall-clock hours AND the threshold has been met. New memory `feedback_stopping_400hr.md`.
- **chore (IMP-3 + IMP-10)**: Decision-Class Checkpoint Protocol added to `docs/SPRINT_EXECUTION_WORKFLOW.md`; companion "Decision-Class Taxonomy: STOP, Surface, Wait" subsection added to `CLAUDE.md` "Things Claude Should NOT Do". Three classes (Class 1 Architecture / Class 2 Development / Class 3 Sprint Execution) require explicit Chief Architect / Chief Developer / Scrum Master signoff at natural breaks. New memory `feedback_decision_class_taxonomy.md`.
- **chore (IMP-4)**: Canonical "Next Steps" progression codified in `docs/SPRINT_EXECUTION_WORKFLOW.md` and `docs/SPRINT_CHECKLIST.md`: Manual integration testing -> Loop on testing feedback -> Code review -> Sprint retrospective -> Merge -> Begin next sprint. Reordering not permitted.
- **chore (IMP-5)**: WinWright UI Test Sweep made mandatory in Phase 5.1.5 (`docs/SPRINT_EXECUTION_WORKFLOW.md` + `docs/SPRINT_CHECKLIST.md`). Supersedes prior per-sprint conditional policy in `feedback_winwright_policy.md`.
- **chore (IMP-7)**: New memory `feedback_echo_requirements.md` -- for multi-surface UI changes/refactors, echo the requirement back in one sentence and wait for confirmation.
- **feat (IMP-1)**: New `/sprint-compact` skill (`.claude/skills/sprint-compact/SKILL.md`) -- produces a compact resume-string (<2K chars) for use with `/compact`. Replaces `/memory-save` for sprint resume; carries only volatile state (sprint name, phase, last/next steps, HEAD, branch). Companion `docs/SPRINT_RESUME_GUIDE.md` carries durable context (phase definitions, decision-class taxonomy, stopping criteria, file paths, 4-step resume sequence) so the compact-string stays small.

### 2026-05-18 (Sprint 38 Round 10: Settings per-account header on Account/Manual Scan/Background tabs)
- **feat**: Settings > Account, Settings > Manual Scan, and Settings > Background tabs now show a single-line per-account header card "Account Settings - <email>" at the top, making it explicit which account these scoped settings apply to. The header is intentionally NOT shown on the General tab (those settings are cross-account). Email is loaded once during `_loadSettings` from SecureCredentialsStore and stored in a `_accountEmail` field so the header renders synchronously without per-tab FutureBuilders. The previous two-line "Account Settings / <email>" layout on the Account tab is replaced by the same single-line header. (Sprint 38 Round 10)

### 2026-05-18 (Sprint 38 Round 9 retest: background scan task verified working-as-designed)
- **chore**: Confirmed background scan scheduled task `SpamFilterBackgroundScan_Dev` is firing every 15 minutes as designed; intervals while foreground UI is running correctly skip per BUG-S37-1 mutex-probe design ("Background scan skipped: Foreground UI is running (mutex held); scan deferred to next interval"). Last successful scan: 2026-05-17 18:16 (immediately before Phase 5.3 manual testing started a continuously-running foreground session). No code change required; the skip is intentional to prevent SQLite DB-locked errors. To re-verify a scan run, close the dev app and wait one 15-minute interval. (Sprint 38 Round 9 retest, Issue #251 verification)

### 2026-05-17 (Sprint 38 Round 9: F82 cross-screen rule-add row hiding regardless of scan mode)
- **fix**: F82 newly-matched rows (from cross-screen rule-add) are now hidden in the unfiltered list, matching inline-rule-add behavior. Round 8 fixed the ordering so re-evaluation completes before first paint, but `_reProcessAffectedEmails` -- which is what populates `_hiddenEmailKeys` for visual hiding -- returns early when `scanProvider.scanMode == ScanMode.readOnly`. On a freshly-launched app with no live scan initiated this session, `scanMode` defaults to readOnly, so the override map updated correctly (chip "No rule" count + footer "M of N" reflected the cross-screen rule) but the matched rows still appeared in the unfiltered list. Round 9 adds an unconditional UI-only hiding pass after the re-process call: for each historical result whose `originalAction == none` and whose override now matches a rule or safe sender, add the key to `_hiddenEmailKeys`. No IMAP side effects (those remain gated by scanMode inside `_reProcessAffectedEmails`). Already-matched rows from the original scan (e.g., already-deleted entries) are skipped via the `originalAction == none` guard, so they continue to show in the unfiltered list as before. (Sprint 38 Round 9, Issue #252)

### 2026-05-17 (Sprint 38 Round 8: F82 cross-screen rule-add ordering -- re-eval before first paint)
- **fix**: F82 chip count / row-hiding / footer denominator now correct on the FIRST paint of Scan History > Scan Results after a cross-screen rule-add (Settings > Manage Rules > +). Round 7 introduced the re-eval but ran it AFTER `setState({_historicalLoaded = true})`, so the first paint cached `_initialNoRuleCount` and rendered the chip from the pre-eval state; only toggling the "No rule" filter (which forces a rebuild) reflected the post-eval overrides. Round 8 reorders `_loadLastCompletedScan` to: (1) stage `_lastCompletedScan/_hasEverScanned/_historicalResults` into fields WITHOUT calling setState, (2) run the full reload+re-eval+cursor+re-process sequence so `_evaluationOverrides` and `_hiddenEmailKeys` are populated, (3) call a single `setState({_historicalLoaded = true})` at the end. Result: first paint sees correct chip count, hidden rows, and footer "M of N" where N is the count of no-rules still unaddressed at the moment of re-entry (matches user mental model when reopening a historical scan). (Sprint 38 Round 8, Issue #252)

### 2026-05-17 (Sprint 38 Round 7: F82 cross-screen rule-add re-evaluation on Scan History re-entry)
- **fix**: F82 footer counter, header chip, and row-hiding now update on Scan History > Scan Results when a rule is added through a different screen (Settings > Manage Rules > +). Round 6 confirmed the inline rule-add path works; this round covers the cross-screen path. Root cause: `_loadLastCompletedScan` (called from `initState` when re-entering Scan Results) loaded the historical scan's email actions from DB but never (a) refreshed `RuleSetProvider` from DB -- `rules_management_screen.dart` writes via its own store without notifying the provider, leaving the in-memory ruleset stale -- nor (b) re-evaluated the loaded historical results against the (potentially newly-loaded) rules. Both gaps existed simultaneously, so even if the provider were freshened the override map for `_historicalResults` would still be empty. Fix mirrors the inline-rule-add sibling sequence at the end of `_loadLastCompletedScan`, gated on `widget.historicalScanId != null`: `ruleProvider.loadRules() + loadSafeSenders() + _reEvaluateNoRuleEmails() + _updateOldestNoRuleCursorsFromResults() + _reProcessAffectedEmails() + setState({})`. Failures inside the block are non-fatal (stale view falls back to last-known evaluation). Live-scan-open path is untouched. (Sprint 38 Round 7, Issue #252)

### 2026-05-17 (Sprint 38 Round 5: F82 historical-scan header map fix)
- **fix**: F82 footer counter + row-hiding on Scan History > Scan Results now works (was still broken after Round 4's result-set-resolver fix per Round 4 Image 9 testing). Root cause: historical EmailMessage objects reconstructed by `_loadLastCompletedScan` had `headers: {}` (empty map). Inline-add block rules use `RuleConditions(header: [pattern])`, so `RuleEvaluator._matchesHeaderList` iterates `message.headers.entries` looking for a `From` key -- with an empty map it found none, returned no match, no override stored, footer counter stayed at 0. Fix: populate `headers: { 'From': emailFrom, 'Subject': emailSubject }` so the matcher's `for entry in headers.entries` loop hits the `From` key (matcher then uses `message.from` directly for the test value, per its existing case-insensitive branch). Mirrors live-scan behavior per Harold's "make it work exactly like live" guidance. (Sprint 38 Round 5, Issue #252 + #254)

### 2026-05-17 (Sprint 38 Round 4: oldest-no-rule UID cursor redesign + F82 historical-scan helpers + build-script task verification)
- **fix**: IMAP UID cursor redesigned per Harold's Round 3 clarification (2026-05-17). The Round 1 cursor was "max UID seen" which caused subsequent scans to skip previously-no-rule emails -- the wrong behavior for the manual-scan re-evaluation workflow. Round 4 cursor is the **oldest unaddressed no-rule UID** per (account, folder). Each scan re-fetches the still-unaddressed backlog from cursor forward via `UID SEARCH UID cursor:*` and naturally includes anything newer that arrived since. As the user adds rules / safe senders that match the oldest no-rule emails, the cursor advances. When all no-rules are addressed for a folder, the cursor is cleared and the next scan falls back to the configured `daysBack` window. (Sprint 38 Round 4, Issue #250 extension)
- **chore**: `DatabaseHelper.cursorTypeOldestNoRuleUid = 'oldest_no_rule_uid'` is the new default cursor type. Round 1's `cursorTypeImapUid = 'imap_uid'` is retained as `@Deprecated` so the v5 `account_folder_cursors` table accepts both kinds. `getFolderCursor` / `setFolderCursor` default to the new type.
- **feat**: `EmailScanner._updateOldestNoRuleCursors(evaluatedEmails, platform)` writes the per-folder oldest-no-rule cursor after every scan complete. IMAP-only; non-IMAP platforms are no-ops. `results_display_screen.dart._updateOldestNoRuleCursorsFromResults` writes the same cursor after every rule-add / safe-sender-add in Scan Results (live OR historical path), so the cursor stays current as the user works through the backlog. Cleared per-folder when zero unaddressed no-rules remain.
- **fix**: F82 footer counter not updating + addressed rows not hiding on Scan History > Scan Results (Image 5 from Round 3 testing). Root cause: three helper methods (`_reEvaluateNoRuleEmails`, `_reProcessAffectedEmails`, `_computeNoRuleStats`) used `liveResults.isNotEmpty || isLiveScanActive` to choose between provider and historical results, missing the `widget.historicalScanId != null` check that the build method correctly does. On a historical-scan view where a prior Live Scan had left stale results in `EmailScanProvider`, all three helpers walked the wrong email set -- `_evaluationOverrides` and `_hiddenEmailKeys` never got populated for the historical emails, so the footer counter stayed at 0 and addressed rows never disappeared from the filtered list. Round 4 fix: all three helpers now match the build method's resolver. (Sprint 38 Round 4, Issue #252)
- **fix**: `build-windows.ps1` now explicitly verifies the re-registered background-scan task is Enabled (re-enables if disabled) and starts an immediate run for verification. Round 3 testing surfaced that re-registration alone did not always result in a running task post-rebuild. (Sprint 38 Round 4)

### 2026-05-16 (Sprint 38 Round 1: post-retro fixes -- IMAP incremental scans, F86 revision, F82 historical-scan fix)
- **feat**: F6c Phase 2 extended from Gmail-OAuth-only to ALSO cover IMAP-backed accounts (`gmail-imap`, `aol`, `yahoo`, custom IMAP). New per-(account, folder) UID cursor stored in a new `account_folder_cursors` table (DB v5 migration). `GenericIMAPAdapter` gains `fetchMessagesIncremental(startUid, folderName)` using `UID SEARCH UID lastUid+1:*` (standard RFC 3501) and `getCurrentMaxUid(folderName)` for first-scan cursor capture. `EmailScanner._fetchFolderMessages` now branches on platform type: `GmailApiAdapter` -> historyId path (Sprint 38 Task 3), `GenericIMAPAdapter` -> UID cursor path (this round), other -> full fetch. No "expired" state for IMAP since UIDs are monotonically increasing per RFC 3501. Manual test plan Round 1 used a `gmail-imap` account so this fixes the visible "no incremental scan" finding. (Sprint 38 Round 1, Issue #250 extension)
- **fix**: F86 redesigned per Harold's clarification (2026-05-16): rule reloads now happen AFTER each Live Scan completes AND AFTER processing new rules in Scan History > Scan Results. Removed the Sprint 38 Task 5 mid-scan evaluator rebuild (was solving the wrong problem -- Harold's actual workflow is "scan complete -> add rule -> next scan didn't see new rule"). `EmailScanner.scanInbox` now calls `ruleSetProvider.loadRules()` + `loadSafeSenders()` after `completeScan()`. Inline rule-add and safe-sender-add handlers in `results_display_screen.dart` also reload from DB after the provider mutation, so any conflict-resolved changes or seed-rule normalization are visible to subsequent re-evaluations. The `_ruleSetChangeCount` diagnostic counter is retained for any future pre-scan sync-pending UI affordance. (Sprint 38 Round 1, Issue #254)
- **fix**: F82 progress footer now appears on the Scan History > Scan Results path (was only showing on Live Scan). Root cause: `_captureInitialNoRuleCount` fired on first render BEFORE `_loadLastCompletedScan` async-completed `_historicalResults`, so the count cached as 0 and the footer's `initial <= 0` guard hid it permanently. Fix: skip capture when `total == 0` so the next rebuild (after async load) captures correctly. Genuine clean scans (zero no-rule emails) still do not show the footer, as intended. (Sprint 38 Round 1, Issue #252)
- **test**: 9 new tests -- 6 in `test/unit/storage/imap_folder_cursor_test.dart` (cursor round-trip, per-folder isolation, per-account isolation, insert-or-replace, delete-to-clear), 3 in `test/unit/adapters/imap_incremental_fetch_result_test.dart` (empty/standard/invariant shape contract). Test count: 1455 passing (was 1446).
- **docs**: Round 1 changes documented inline in the affected files' dartdoc + the dispatch comments in `_fetchFolderMessages`. Will be referenced from SPRINT_38_RETROSPECTIVE.md (Phase 7).

### 2026-05-14 (Sprint 38 -- Task 8: F85 Content management ADR + Help screen migration + Settings audit)
- **feat**: New ADR-0038 ("Content Management for Long Inline Strings") establishes the >500-character user-facing-content threshold above which Dart string literals must live as Markdown files under `mobile-app/assets/content/` and be loaded via the asset manifest at `assets/content/manifest.yaml`. Excluded: regex patterns, SQL DDL, log message templates, runtime-interpolated strings. Asset format decision: per-section `.md` files with a YAML manifest (rejected: one-big-YAML, one-big-Markdown, JSON). Loader strategy: build-time bake via `pubspec.yaml assets:` declaration; runtime fetch is out of scope for V1. i18n posture: directory structure leaves room for `en/`, `fr/`, etc. prefix when localization becomes a sprint priority. CLAUDE.md updated with the new coding-style rule pointing at ADR-0038. (Sprint 38 Task 8 Phase 1, Issue #257)
- **feat**: All 20 `HelpSection` enum bodies migrated from inline Dart string literals in `help_screen.dart` to `assets/content/help/*.md`. Section titles remain inline (titles are short labels, not content). `help_screen.dart` shrunk from 668 lines to ~270 lines. Bodies now load asynchronously via `FutureBuilder<String>` -> `ContentLoader().load('help', sectionKey)`. The original ~14,200 characters of user-facing prose now lives in 20 individual `.md` files that Harold can edit with any Markdown-capable tool without touching Dart source. Section title -> manifest key mapping is an explicit `switch` (not `.name`) so a future enum rename is caught at compile time. (Sprint 38 Task 8 Phase 2)
- **feat**: New `ContentLoader` service at `lib/core/services/content_loader.dart`. Singleton with process-lifetime in-memory cache; resolves `<namespace>.<key>` -> asset path via the parsed manifest. Throws `ArgumentError` on unknown namespace/key (catches manifest-vs-Dart drift at runtime if the build-time validator missed it).
- **feat**: New PowerShell validator `scripts/validate-content-manifest.ps1` performs three drift checks: (1) every manifest key resolves to an existing `.md` file; (2) every `.md` file under `assets/content/` is referenced by exactly one manifest key (orphan detection); (3) every `HelpSection` enum case has a corresponding `help:` namespace entry. Exit 0 on success, exit 1 with a per-issue diff on failure. Intended to be wired into CI / pre-commit; current Sprint 38 validation confirms 20/20 manifest entries match 20/20 disk files match 20/20 enum cases.
- **chore**: F85 Phase 3 codebase audit (documented in `assets/content/audit-log.md`): inspected every `lib/` file for Dart string literals exceeding 500 chars of user-facing content. Findings -- (a) all 20 `HelpSection` bodies migrated (above), (b) `settings_screen.dart` Settings tab subtitles are all short (single-sentence), no migration warranted, (c) other screens audited (account_setup_screen.dart, gmail_oauth_screen.dart, manual_rule_create_screen.dart, rule_test_screen.dart, rule_quick_add_screen.dart) -- nothing exceeds the threshold. Phase 3 is therefore a no-op for non-Help screens; nothing new migrated.
- **test**: 4 new tests in `test/unit/services/content_loader_test.dart` verify every HelpSection enum case loads from the asset bundle without throwing (drift detection), the cache returns the same instance on repeated calls, and unknown namespace/key throws ArgumentError. Updated `help_screen_other_ways_test.dart` to use `pumpAndSettle` since bodies now load via `FutureBuilder`. All 9 existing Help widget tests continue to pass against asset-loaded content.

### 2026-05-14 (Sprint 38 -- Task 7: F82 Scan Results "no rules" progress indicator)
- **feat**: Scan Results screen (both Live Scan and Scan History > Scan Results review surfaces) now shows an **"M of N No rule emails addressed -- K remaining"** progress footer above the email list, with a tiny linear progress bar on the right. Footer turns green with a check icon when all no-rule emails have been addressed; amber with a flag icon while progress is ongoing. Hidden when the scan had zero no-rule emails (clean scan, nothing for the user to triage). This makes it obvious how many "No rule" items remain in the pool to be handled, which was previously only visible via the chip count in the summary. Harold's Sprint 37 retro Cat 13 (Issue #252) called this out as the primary friction point when processing scans where background-scan already removed known matches. (Sprint 38 Task 7, Issue #252)
- **feat**: Inline rule-add and safe-sender-add snackbars now append "**N removed, K No rule remaining**" so each rule-add operation gives concrete progress feedback against the no-rules pool. Example: "Created block rule 'badnews.com' (removed 2 conflicting safe senders) -- 3 removed, 14 No rule remaining". When the rule does not match any pending items (rare -- usually adding a rule for a specific item the user is currently viewing), the wording shortens to "... -- 14 No rule remaining" or omits entirely if there is nothing left. (Sprint 38 Task 7)
- **chore**: New private `_computeNoRuleStats()` helper on `_ResultsDisplayScreenState` returns a `({remaining, addressed, initial})` record over the same `allResults` set the chip strip and re-process banner already use. The `initial` count is captured once via `_captureInitialNoRuleCount()` and unchanged for the session so the footer shows cumulative progress rather than just current remaining.
- **note**: Follows the Option A design from the F82 issue: mirror Live Scan exactly. Already-shipped infrastructure (`_evaluationOverrides`, `_getEffectiveAction`, `_hiddenEmailKeys`, `_reEvaluateNoRuleEmails`, `_reProcessAffectedEmails`) was reused -- F82 is mostly the missing user-facing progress indicator + snackbar wording. Manual testing in Phase 5.3 covers the live + historical paths.

### 2026-05-13 (Sprint 38 -- Task 6: F84 Sub-task A -- Ctrl+A select-all-to-clipboard on Manage Rules and Manage Safe Senders)
- **feat**: Ctrl+A (Windows/Linux) and Cmd+A (macOS) on Manage Rules and Manage Safe Senders now copy the **entire filtered list** to the clipboard, not just the items currently rendered in the viewport. Default Flutter behavior on a `ListView.builder` + `SelectionArea` only selects rendered viewport items; off-screen rows are skipped. New `CopyAllShortcut` widget (`lib/ui/widgets/copy_all_shortcut.dart`) bypasses Flutter's selection model entirely: it intercepts the keyboard shortcut, calls a caller-provided `textBuilder()` that returns the joined row text for the full in-memory `_filteredRules` / `_filteredSenders` list, and writes that text directly to the clipboard with a "Copied N rules/safe senders to clipboard" snackbar confirmation. Manage Rules format: `"$name\t$pattern"`. Manage Safe Senders format: `"$pattern\t$patternType"`. (Sprint 38 Task 6, Issue #253)
- **chore**: Sub-tasks B (Shift+Click extend selection) and C (Ctrl+Click-drag disjoint selection) from Issue #253 are deferred to a follow-up sprint. They require significant per-row state tracking (selection-anchor index, multi-range selection set) and a more invasive list-row refactor than fits Sprint 38's scope alongside the other 7 tasks. Sub-task A solves the most-common user pain (no way to extract the full list for sharing/auditing/support tickets) without that complexity. Issue #253 remains open with Sub-tasks B/C scoped for Sprint 39+.
- **test**: 4 new widget tests in `test/ui/widgets/copy_all_shortcut_test.dart` verify Ctrl+A clipboard write, Cmd+A clipboard write, empty-textBuilder silent no-op, and snackbar row-count formula. Clipboard access mocked via TestDefaultBinaryMessengerBinding.

### 2026-05-13 (Sprint 38 -- Task 5: F86 Live reload of rules/safe senders during active scan)
- **feat**: Adding, editing, or deleting a rule or safe sender from Settings (Manage Rules, Manage Safe Senders, or any quick-add affordance) while a Manual Scan is in progress now propagates to the running scan opportunistically. EmailScanner subscribes to `RuleSetProvider.notifyListeners()` at scan start; on each notification, the scanner marks the rule set as dirty. The per-message evaluation loop checks the dirty flag at every iteration and rebuilds the `RuleEvaluator` with `ruleSetProvider.rules` and `ruleSetProvider.safeSenders` before evaluating the next email. Already-evaluated emails are NOT re-evaluated -- the swap takes effect from the next message forward, mirroring the "next batch boundary" semantics in Issue #254. Demo platform is exempt (uses MockEmailData rules which do not change mid-scan). Per Harold's Sprint 38 direction, this is opportunistic-async -- the scan does not wait for rule changes, it just observes them at the next message. (Sprint 38 Task 5, Issue #254)
- **feat**: Re-scan trigger sync-pending coordination. When the user taps Start Scan and `RuleSetProvider.isLoading` is true (rule set still saving from a recent edit), `_startRealScan` now shows a brief "Applying new rule(s) before scan starts..." snackbar and polls for readiness (max 2s, 50ms intervals) BEFORE creating the EmailScanner. This handles the narrow window between save and re-scan trigger where the new rules have not yet finished writing to DB. Mid-scan rule changes (the more common case) are handled by the opportunistic-async listener above; the re-scan check is the safety net for the save-then-immediately-restart case.
- **chore**: Listener registration uses standard `addListener`/`removeListener` in `try/finally` so the listener is always removed, even on scan-error paths -- prevents listener leaks across scans on the same `RuleSetProvider` singleton.
- **test**: 4 new tests in `test/unit/services/email_scanner_f86_test.dart` verify the dirty-flag mechanism, `pendingRuleSetChanges` counter increments, and per-scanner instance isolation. Mid-scan evaluator rebuild requires a running scan with real emails and is verified manually per Phase 5.3.

### 2026-05-13 (Sprint 38 -- Task 4: F88 Gmail batchGet endpoint)
- **feat**: Gmail `fetchMessages` and `fetchMessagesIncremental` now use the true `/batch/gmail/v1` multipart endpoint instead of Sprint 37's parallel-fetch-of-individual-GETs. Each chunk of 100 message IDs becomes one HTTP request to Gmail (multipart/mixed body with N sub-requests inside) rather than 100 separate HTTP calls. With Sprint 37's 8-concurrent chunking preserved around the new batchGet calls, the effective concurrency is now "8 batches in flight, each containing up to 100 sub-requests" -- roughly **12-13x reduction in HTTP request count** vs Sprint 37, on top of the ~10x parallel-fetch speedup Sprint 37 delivered over the original serial loop. Net effect for a 1,000-message scan: ~10 HTTP requests (Sprint 38) vs ~125 (Sprint 37) vs ~1,000 (pre-Sprint 37). (Sprint 38 Task 4, Issue #255)
- **feat**: Per-chunk fallback to Sprint 37's individual `messages.get` path if batchGet fails (network error, auth failure, multipart parse failure, etc.). Matches the `_batchModifyLabels` fallback pattern at line 1216. Ensures a batchGet outage degrades to "same speed as Sprint 37" rather than "scan fails entirely." Sub-requests that fail INSIDE a successful batchGet response (404 for deleted message, label-excluded, etc.) are dropped silently -- matching the per-ID try/catch behavior of the Sprint 37 parallel-fetch path.
- **chore**: New private helper `_setGmailApi(headers)` rebuilds `_gmailApi` and caches the auth headers for the raw-HTTP batch endpoint. All 6 call sites that previously did `_gmailApi = gmail.GmailApi(_GoogleAuthClient(headers))` now route through this helper so cached headers stay in sync across re-authentication and token refresh.
- **test**: 12 new tests in `test/unit/adapters/gmail_batchget_parser_test.dart` pin the multipart/mixed response parser helpers (boundary extraction with/without quotes, multipart splitting including preamble handling, JSON extraction from each sub-response, error-response handling). Three helpers exposed via `@visibleForTesting` static methods (`extractBoundaryForTesting`, `parseMultipartMixedForTesting`, `extractJsonForTesting`). Full batchGet HTTP exchange deferred to Phase 5.3 manual testing against real Gmail account.

### 2026-05-13 (Sprint 38 -- Task 3: F6c Phase 2 wire incremental Gmail scans)
- **feat**: Gmail manual scans now use historyId-based incremental delta scans when a prior scan persisted a cursor. Sprint 37 F6c shipped the `GmailApiAdapter.fetchMessagesIncremental` adapter capability + DB v4 `last_history_id` column; Sprint 38 wires them into `EmailScanner._fetchFolderMessages` so live scans actually USE the capability. Three branches: (a) non-Gmail platforms fall through to the existing provider-agnostic `fetchMessages` call (AOL, IMAP, demo unaffected); (b) first-ever Gmail scan does the full fetch then captures `getCurrentHistoryId()` for the next scan; (c) subsequent Gmail scans call `fetchMessagesIncremental(startHistoryId, folderForLabel)` and persist `result.newHistoryId`. On `result.isExpired` (Gmail rotates history after ~7 days), `last_history_id` is cleared and the scan falls back to full-fetch + re-capture. Net effect: a steady-state Gmail user who scans every few days fetches the delta (typically a few-hundred new messages) instead of `daysBack * inbox-size` (typically tens of thousands), with no behavior change visible to non-Gmail users. Performance gain compounds with Sprint 38 F88 (true batchGet) since the incremental result set is smaller. (Sprint 38 Task 3, Issue #250)
- **feat**: New `DatabaseHelper.getLastHistoryId(accountId)` / `setLastHistoryId(accountId, historyId)` typed helpers for the Gmail cursor. Pass-throughs over the existing `getAccount` / `updateAccount` methods but make the intent explicit at call sites and provide a clearer test surface than ad-hoc map-key access.
- **test**: 5 new tests in `test/unit/storage/last_history_id_test.dart` pin the per-account cursor semantics (null for fresh account, persist non-null, clear via null, scoped per-account, overwrite replaces). 4 new tests in `test/unit/adapters/incremental_fetch_result_test.dart` pin the shape contract of `IncrementalFetchResult` (expired vs empty vs populated) that `_fetchFolderMessages` branches on. Full orchestration (real Gmail API + real DB) deferred to Phase 5.3 manual testing per Sprint 37 retrospective Category 2 disposition.

### 2026-05-13 (Sprint 38 -- Task 2: BUG-S37-1 background scan DB locked)
- **fix**: Background scan now performs a read-only mutex probe at startup. If the foreground UI is running (mutex held), the background scan logs a "skipped: foreground UI running" line to `[dev_]background_scan_v0.5.3.log` and exits cleanly. The Task Scheduler retries on the next interval. Previously, `--background-scan` bypassed the single-instance mutex entirely, opening a parallel SQLite connection to the same DB the UI process was using, producing `SqfliteFfiException(sqlite_error: 5, "database is locked")` errors. Sprint 37 Phase 5.3 prod-build manual testing surfaced this (PID 21772 held the prod DB while UI was running). Root-cause diagnosis: Mode A (intra-process via "Test Background Scan" button) is NOT a bug -- `DatabaseHelper` is a singleton; Mode B (inter-process via Task Scheduler launch) was the actual bug. Fix targets Mode B in `mobile-app/windows/runner/main.cpp` (12 lines added; same Global mutex name, but background-scan path uses `OpenMutexW(SYNCHRONIZE, FALSE, ...)` read-only probe rather than `CreateMutexW` acquisition). 2 new Dart tests pin the DatabaseHelper singleton invariant so a future refactor that breaks Mode A's "not a bug" diagnosis is caught immediately. ADR-0035 updated with Sprint 38 section documenting the read-only probe rationale. (Sprint 38 Task 2, Issue #256)
- **test**: New PowerShell integration test `mobile-app/scripts/test-background-scan-skip.ps1` verifies the BUG-S37-1 fix against the real built `.exe` and real Windows kernel mutex. Asserts that `--background-scan` exits 0 and appends a skip-log line when the foreground UI is running. Invoke standalone (`.\test-background-scan-skip.ps1 [-Environment prod]`) or as part of the build flow (`.\build-windows.ps1 -RunIntegrationTests`). New `-RunIntegrationTests` switch added to `build-windows.ps1`. This test pattern establishes the precedent for testing future `main.cpp` startup-logic changes (mutex naming, environment detection, single-instance behavior) that cannot be expressed in `flutter test`. Pattern documented in ADR-0035 "Integration Test Pattern" section. (Sprint 38 Task 2b, Issue #256)

### 2026-05-13 (Sprint 38 -- Task 1: F87 Settings icon on Scan History)
- **feat**: Scan History AppBar now includes a Settings IconButton (gear icon) so users can reach Settings from sub-screens with one tap rather than back-navigating. Inserted in F55 (Sprint 33 v3) icon order between Accounts and Help (`Refresh | Accounts | Settings | Help | [X auto]`). `onPressed` pushes `SettingsScreen(accountId: widget.accountId)` matching the pattern used in `results_display_screen.dart`, `scan_progress_screen.dart`, `account_selection_screen.dart`, `folder_selection_screen.dart`, and `help_screen.dart`. Investigation showed `AppBarWithExit` is a thin shared wrapper that only appends the Exit button on Windows; each calling screen owns its own `actions:` list. Component-level fix not appropriate; fix applied per-screen. Widget test dropped per Sprint 37 round-1 disposition (FakeAsync + sqflite_ffi + initState DB load hang); manual testing in Phase 5.3 verifies. (Sprint 38 Task 1, Issue #251)
- **chore**: Updated F55 icon-order comment in `scan_history_screen.dart` to reflect new Settings icon position.

### 2026-05-04 (Sprint 37 -- Phase 7 round 8: align safe-senders CSV with rules CSV)
- **chore**: Manage Safe Senders CSV export now uses the same column order as Manage Rules CSV for the columns that apply to both: `Source Domain | Rule Name | Pattern | Category | Sub-Type`. Safe-sender-only extras (`Date Added | Source | Exceptions`) follow as trailing columns so no information is lost vs the round-6 export. Columns that have no meaning for safe senders (`Action`, `Enabled`, `Execution Order`) are intentionally omitted. Source Domain is now extracted from the regex pattern using the same shape-recognition logic as `manual_rule_duplicate_checker.dart` (entire_domain `^[^@\s]+@(?:[a-z0-9-]+\.)*<base>$`, exact_domain `@<base>` or `^[^@\s]+@<base>$`, exact_email `^<user>@<domain>$`); falls back to the pattern itself for the Rule Name column when no extraction is possible. (Sprint 37 round 8, Harold's CSV-format-parity feedback 2026-05-04)

### 2026-05-04 (Sprint 37 -- Phase 7 round 7: leading icon clickable + CSV fixes + Settings reorg)
- **fix**: CSV export from Manage Rules + Manage Safe Senders now CSV-injection-safe per OWASP guidance. Cells whose first character is `=`, `+`, `-`, `@`, tab (`\t`), or CR (`\r`) are now prefixed with a single quote `'` so spreadsheet apps treat them as literal text rather than as a formula. Fixes Excel `#NAME?` error on rules with source domain `-offers.com`, and would have hit the same issue on Safe Senders patterns starting with `@(?:...)`. (Sprint 37 round 7, Harold's Excel screenshot 2026-05-04)
- **feat**: CSV export from Manage Rules now includes a `Pattern` column with the rule's regex pattern(s) joined with `; ` (header / from / subject / body lists are concatenated since one CSV cell, multiple condition buckets per rule). Manage Safe Senders Pattern column was already present. (Sprint 37 round 7, Harold's CSV feedback 2026-05-04)
- **feat**: Leading category icon on each Manage Rules + Manage Safe Senders row is now clickable -- matches the trailing info icon's open-details behavior. Same hover ring, tooltip ("View rule details" / "View safe sender details"), keyboard focus, and tap response. Implemented via `IconButton` wrapped in an explicit `SizedBox(36, 36)` so the round-5b "tight ListTile.leading constraints collapse the IconButton hit region" failure does not recur. Cross-row text selection (round 2) preserved -- the leading icon is outside the title/subtitle text region so selection drags through unchanged. (Sprint 37 round 7, Harold's UX feedback 2026-05-04)
- **chore**: Settings > Manual Scan > Export Settings moved to Settings > General > above Import / Export YAML. The CSV export directory is now used by Manage Rules + Manage Safe Senders + Manual Scan results -- general-purpose enough to live on the General tab next to the related YAML import/export action. (Sprint 37 round 7, Harold's UX feedback 2026-05-04)
- **chore**: Settings > General destructive actions (Reset Rules to Defaults, Delete All App Data...) moved to BOTTOM of the General tab in a new "Danger Zone" section, just above About. Originally lived under Rules Management at the top; moving them down avoids accidental taps during scrolling and keeps the irreversible-action pair grouped. (Sprint 37 round 7, Harold's UX feedback 2026-05-04)

### 2026-05-04 (Sprint 37 -- Phase 7 round 6: Alt-2 final UX redesign + Export CSV)
- **feat**: Manage Rules + Manage Safe Senders row affordance redesigned per UI consultant Alt-2 (chosen by Harold from 3 alternatives). Leading category icon is now decorative-only (label, not button) at 20px / 0.85 opacity. Trailing affordance is a hover/focus-revealed `info_outline` IconButton (visible only when the row is mouse-hovered or has keyboard focus, via `MouseRegion` + `Focus.onFocusChange` + `AnimatedOpacity duration: 120ms`). Trailing delete IconButton REMOVED from each row -- delete remains reachable inside the details dialog (existing button there). Net: cleaner rows, cross-row text selection (Sprint 37 round 2) preserved 100%, no accidental delete clicks, proper Button semantics + tooltip + keyboard focus + Material ink on the open-details affordance. (Sprint 37 Phase 7 round 6 supersedes rounds 1-5b on this affordance)
- **feat**: New "Export shown items as CSV" AppBar button on both Manage Rules and Manage Safe Senders screens. Exports the currently-filtered subset (search query + filter chips applied) -- the "filter is the selection" pattern. File is timestamped (`manage_rules_filtered_<iso>.csv` / `manage_safe_senders_filtered_<iso>.csv`) and written to the user's configured export directory (Settings) or to the platform's default documents/external-storage directory. Tooltip is dynamic: `'Export N shown rule(s) as CSV'` when the filter has results, `'Nothing to export'` (disabled) when filter returns empty. (Sprint 37 Phase 7 round 6, Harold's UX suggestion)
- **note**: Round-6 widget tests for hover/focus reveal + export button were attempted but hit the same `FakeAsync + sqflite_ffi + pumpWidget` hang that Sprint 37 round 1 widget tests hit (initState's `_loadRules`/`_loadSafeSenders` future never resolves under FakeAsync). Per the same disposition Harold approved on round 1 (option A "drop the failing widget tests"), the round-6 tests were dropped. Behavior verified via manual testing + code review.

### 2026-05-02 (Sprint 37 -- Phase 7 round 5: Copilot review responses)
- **fix**: Manage Rules + Manage Safe Senders details-dialog accessibility regression. Round-2 replaced `ListTile.onTap` with a bare `GestureDetector` on the leading icon, which lost Button semantics, focusability, tooltip, and Material ink for assistive tech. Round-5 replaces the `GestureDetector` with `IconButton` on both screens -- restoring full a11y on the dialog-open affordance while preserving the round-2 cross-row text selection. (Sprint 37 PR #249 Copilot review #2 + #3, applied 2026-05-02)
- **fix**: Gmail adapter `fetchMessages` (`scanInbox` path) had unbounded `Future.wait` over up to 100 `messages.get` calls. Gmail's per-user concurrency cap is roughly 10 simultaneous requests; the unbounded burst triggered 429 rate-limit errors that the per-message try/catch silently dropped as missing messages. Round-5 introduces a private `_fetchMessagesConcurrent` helper that chunks fetches at 8 concurrent at a time. (Sprint 37 PR #249 Copilot review #5, applied 2026-05-02)
- **fix**: Gmail adapter `fetchMessagesIncremental` had the same unbounded-concurrency problem on the F6c historyId delta-scan path. Now uses the same `_fetchMessagesConcurrent` helper. (Sprint 37 PR #249 Copilot review #6, applied 2026-05-02)
- **fix**: Gmail adapter `fetchMessagesIncremental` was calling `users.history.list` mailbox-wide (no folder scope), so once the F6c provider wiring lands (Issue #250) it would have surfaced Sent/Trash/Promotions/Drafts changes mislabeled as the caller's single folder. Round-5 adds `labelId: folderForLabel` to the `history.list` call AND applies a client-side post-filter against `_excludedLabels` (because `users.history.list` accepts an inclusion `labelId` filter but not an exclusion list). (Sprint 37 PR #249 Copilot review #7, applied 2026-05-02)
- **chore**: F88 added to ALL_SPRINTS_MASTER_PLAN.md -- F6a Phase 2 (true Gmail batchGet via `/batch/gmail/v1` multipart/mixed endpoint). Sprint 37 shipped a parallel-fetch optimization that gave ~10x speedup AND respects Gmail's concurrency cap, but the original Issue #247 acceptance criteria called for the batchGet endpoint specifically. The remaining work is collapsing N individual `messages.get` calls into a single multipart/mixed batchGet HTTP request per 100 IDs, with per-chunk fallback matching the existing `_batchModifyLabels` pattern. ~3-4h, P60. (Sprint 37 PR #249 Copilot review #4, deferred to backlog 2026-05-02)
- **note**: Copilot review #1 (subsumption-check ordering before exact-duplicate check in `manual_rule_create_screen.dart`) reviewed and declined. Ordering is intentional per BUG-S36-1 / Issue #246 acceptance criteria, which require the more-informative subsumption error message ("covered by entire_domain cwru.edu") to be surfaced when a broader rule exists, regardless of whether an exact duplicate also exists. Both code paths reject the insert; subsumption message is more useful to the user. Documented in retrospective Round 5 section.

### 2026-05-02 (Sprint 37 -- Phase 7 retrospective improvements, round 4 backlog additions)
- **chore**: F85 scope expanded from "Help text externalized to a file" to a general content-management architecture for any inline Dart string literal >500 characters. Phase 1 now mandates an ADR (`docs/adr/0036-content-management-for-long-strings.md` or next available) deciding format, loader, validation, and i18n posture. Phase 2 migrates Help. Phase 3 audits the rest of `lib/` for long user-facing strings; known candidate is Settings tab descriptions. Re-estimated 3-5h -> 6-10h. (Sprint 37 Phase 7 round-4 expansion of round-3 F85)
- **chore**: F86 added to ALL_SPRINTS_MASTER_PLAN.md -- live reload of rules / safe senders during an active Manual Scan. Today mid-scan additions via Settings do not apply until the scan is restarted. ~2-4h, P60. (Sprint 37 Phase 7 round-4 backlog addition; Harold Phase 5.3 round-3 manual testing observation)
- **chore**: F87 added to ALL_SPRINTS_MASTER_PLAN.md -- Settings icon missing from Scan History AppBar. Inconsistent with every other primary screen. ~1-2h, P55. (Sprint 37 Phase 7 round-4 backlog addition; Harold Phase 5.3 round-3 manual testing observation)

### 2026-05-02 (Sprint 37 -- Phase 7 retrospective improvements, round 3 fixes)
- **fix**: Help "Unwanted emails" Unsubscribe bullet moved from FIRST to LAST position in the section (after the FTC `See:` link). Rationale: leading position implicitly recommended Unsubscribe; placing it last after Junk/Spam + phishing forwarding + FTC reporting demotes it to "last-resort, only for Fortune 1000 / well-known senders" advice. Intra-bullet "(above)" cross-reference replaces round-2 "below". Test guard updated. (Sprint 37 Phase 7 Imp-2 round-3; Phase 5.3 round-3 manual testing feedback)
- **chore**: Two new backlog F-items added to ALL_SPRINTS_MASTER_PLAN.md: F84 (keyboard + multi-region selection enhancements: Ctrl+A select-all-across-virtualized-list, Shift+Click extend-selection, Ctrl+Click disjoint-range) and F85 (Help text externalized to a content-management file -- YAML/Markdown asset editable without Dart code changes). Both surfaced from Phase 5.3 round-3 manual testing.

### 2026-05-01 (Sprint 37 -- Phase 7 retrospective improvements, round 2 fixes)
- **fix**: Manage Rules + Manage Safe Senders text selection now sweeps across multiple rows. Round 1 wrapped each row title/subtitle in `SelectableText`, which created isolated selection scopes -- users could select one field at a time, not contiguous regions across rows. Round 2 wraps the entire list body in a single `SelectionArea` (Manage Rules; Manage Safe Senders already had one) and reverts row fields to plain `Text` widgets so the shared `SelectionArea` governs all selection. Drag now sweeps from any field of any row through any field of any other row. Tap on the leading category icon still opens the row details dialog. (Sprint 37 Phase 7 Imp-1 round-2; surfaced during Phase 5.3 round-2 manual testing.)
- **fix**: Help screen "unwanted emails" subsection was too generous about unsubscribe links. Round 1 said "use the Unsubscribe link in any email from a sender you once did business with"; Harold flagged that less-reputable list operators interpret an unsubscribe click as confirmation of a monitored address and respond by selling it at a premium. Section now restricts unsubscribe advice to "well-known, reputable companies (roughly Fortune 1000 / household-name brands)" and steers everyone else to the mark-as-Junk-or-Spam path. (Sprint 37 Phase 7 Imp-2 round-2)
- **fix**: Help screen "unwanted postal mail" subsection had the same address-confirmation problem with catalog opt-outs. Round 1 advised "for mail-order catalogs, contact each catalog directly to be removed"; round 2 inverts that bullet to advise AGAINST direct catalog contact and steers users to the DMAchoice.org bulk opt-out (removes upstream from the list-rental marketplace most catalogs draw from). (Sprint 37 Phase 7 Imp-2 round-2)
- **feat** (round 1 superseded by round-2 fix above): Manage Rules and Manage Safe Senders list rows are selectable for copy. Tap on the leading category icon still opens the rule/sender details dialog; tap on the row text now selects the text instead. (Sprint 37 Phase 7 Imp-1, Harold Category 1 feedback)
- **feat** (round 1, content adjusted by round-2 fixes above): New Help screen section "Other ways to reduce junk email, mail, texts, and phone calls" at the bottom of the Help screen. Sub-sections for unwanted emails (FTC, APWG `reportphishing@apwg.org`), unwanted texts (forward to `7726`, FTC `ReportFraud.ftc.gov`), unwanted postal mail (`OptOutPrescreen.com`, `DMAchoice.org`), and unwanted phone calls (`DoNotCall.gov`, `1-888-382-1222`, carrier spam-call services). Footer timestamp bumped to "Sprint 37 (May 2026)". 5 new widget tests covering section presence, key reporting destinations, footer timestamp, unsubscribe-warning content (round-2), and catalog-opt-out-warning content (round-2). (Sprint 37 Phase 7 Imp-2, Harold Category 13 feedback)
- **docs**: SPRINT_EXECUTION_WORKFLOW.md Phase 6.4 Copilot review step is now explicitly conditional on the Copilot reviewer being configured as a collaborator on the repo (gh CLI `--add-reviewer copilot-pull-request-reviewer` 422 = skip). Three sprints in a row (35/36/37) Copilot review was unavailable; previous "mandatory" framing was incorrect. (Sprint 37 Phase 7 Imp-6)
- **docs**: New Phase 3.2.2.2 sub-step in SPRINT_EXECUTION_WORKFLOW.md mandates re-estimation of remaining tasks when Phase 3.2.2.1 plan-to-branch-state verification produces scope-changing findings. Sprint 37 retro Effort Accuracy category found 2-4x over-estimation across BUG-S36-1 / F6 / F52 Phase 1 because original estimates assumed scaffolding that prior sprints had already shipped. (Sprint 37 Phase 7 Imp-7)
- **docs**: ALL_SPRINTS_MASTER_PLAN.md updated with Sprint 38 carry-ins and new backlog F-items: F52 Phase 2 (Android flavors, Issue #248), F82 (Scan History "no rules" progress indicator), F83 (per-account Background Scanning separation), BUG-S37-1 (background scan SQLite "database is locked"), BUG-S37-2 (TLD data quality + ccTLD blocklist expansion). F61 (architecture refresh, HOLD) extended to cover Sprint 37 additions (`SubsumingRuleInfo`, `IncrementalFetchResult`, schema v4). (Sprint 37 Phase 7 Imp-3, 4, 5, 8, 10, 12)
- **chore**: New GitHub Issue #250 ("F6c Phase 2: Wire EmailScanProvider to use Gmail historyId incremental scans") tracking the Sprint 38 carry-in for the F6c provider-wiring work; #247 closed-out comment links to it. (Sprint 37 Phase 7 Imp-9)

### 2026-04-29 (Sprint 37 -- F52 Phase 1 compile-time window title fix)
- **fix**: Window title for prod variant now correctly omits `[DEV]` suffix. Root cause: `windows/runner/main.cpp` was deciding the title at runtime by parsing `GetCommandLineW()` for the literal `APP_ENV=prod`, which works for `flutter run --dart-define=APP_ENV=prod` invocations but FAILS for direct-launch variants (`Start-Process .exe` with no args) AND for Microsoft Store MSIX where the Store launcher does not pass dart-define args. Fix bakes `SPAMFILTER_APP_ENV` into the .exe at compile time via a `target_compile_definitions` entry in `windows/runner/CMakeLists.txt`, sourced from the `SPAMFILTER_APP_ENV` environment variable that `build-windows.ps1` exports before invoking `flutter build windows`. Verified: `dist/prod/MyEmailSpamFilter.exe` launched via `Start-Process` with no args now shows window title `MyEmailSpamFilter` (no `[DEV]` suffix). Critical for store-bound builds. (Issue #248)

### 2026-04-29 (Sprint 37 -- F52 Phase 1 Phase 5.3 fixes)
- **fix**: F52 Phase 1 build-windows.ps1 robustness against back-to-back environment builds. Three changes:
  1. Variant dirs moved from `build/windows/x64/runner/Release-{env}/` to `mobile-app/dist/{env}/` (outside `build/`) so `flutter clean` does not wipe the prior variant on the next build.
  2. Step 1 now terminates running `MyEmailSpamFilter*.exe`, `dart.exe`, and `dartvm.exe` processes before `flutter clean`. Without this, file locks held by leftover Dart VMs cause `flutter clean` to silently no-op and the next `flutter build` reuses stale AOT artifacts (root cause of Phase 5.3 escape where building dev then prod produced a prod variant with the dev AOT baked in).
  3. Final-step launch replaced `flutter run` with `Start-Process $variantBuildTarget` (direct .exe launch). `flutter run` left a Dart VM attached after exit which defeated the next build's clean step.
- **chore**: `mobile-app/.gitignore` now excludes `/dist/` (env-specific variant artifacts).
- **docs**: ADR-0035 "Sprint 37 Update" section refreshed with new dist/ paths, the kill-stale-processes fix, and the direct-launch fix.
- Verified end-to-end: built dev, then `flutter clean` + built prod, both `dist/dev/MyEmailSpamFilter-Dev.exe` and `dist/prod/MyEmailSpamFilter.exe` coexist. (Issue #248)

### 2026-04-27 (Sprint 37)
- **feat**: F52 Phase 1 -- Windows multi-variant install. `build-windows.ps1` now post-build copies the canonical Flutter `Release/MyEmailSpamFilter.exe` to env-specific persistent paths so dev and prod can coexist on disk without rebuild. Dev -> `Release-dev/MyEmailSpamFilter-Dev.exe`, prod -> `Release-prod/MyEmailSpamFilter.exe`. Windows Task Scheduler scheduled task points to the env-specific variant exe so the prod and dev tasks reference distinct binaries. MSIX store builds are unaffected (PackageFamilyName isolation). ADR-0035 extended with "Sprint 37 Update" section documenting the variant layout. (Issue #248)
- **feat**: F6c Gmail historyId-based incremental delta scan -- adapter-side capability shipped. New `GmailApiAdapter.getCurrentHistoryId()` reads the current Gmail historyId; `fetchMessagesIncremental(startHistoryId)` calls `users.history.list` and returns only added/modified messages since the given point, plus the new historyId for the caller to persist. Returns `IncrementalFetchResult.expired()` on Gmail's 7-day historyId expiration so the caller can fall back to a full scan. Database v3 -> v4 migration adds `last_history_id TEXT` column to `accounts` table (additive, nullable, safe). Wiring into `EmailScanProvider` is staged for a follow-up commit. 5 new unit tests for the result shape; 2 new schema/round-trip tests. (Issue #247)
- **feat**: F6a/F6b Gmail scan-path optimization -- (a) parallelize Gmail `messages.get` fetches via `Future.wait` so a 100-message folder fetch runs ~10x faster than the previous serial loop; (b) optional server-side label filtering (`-label:CATEGORY_PROMOTIONS -label:CATEGORY_SOCIAL`) via new `GmailApiAdapter.setExcludedLabels(...)` method, lets callers skip Promotions/Social Gmail tabs without fetching the messages first. 8 new query-building unit tests. F6c (historyId incremental delta scan) tracked separately. (Issue #247)
- **fix**: BUG-S36-1 manual rule semantic subsumption -- pre-insert check rejects new `exact_email` / `exact_domain` rules when an existing broader rule (`exact_domain` / `entire_domain` with the same base domain) already covers them. Validation error names the existing covering rule (`"A safe sender already covers this: entire_domain cwru.edu."`). Same coverage matrix applied to safe senders. Coverage matrix per Issue #246: `exact_email` covered by `exact_domain` or `entire_domain`; `exact_domain` covered by `entire_domain`; `entire_domain` is broader and never covered; `top_level_domain` has no overlap with domain types. 14 new unit tests covering the matrix and edge cases (Issue #246)

### 2026-04-20 (Sprint 36 kickoff - dev version bump)
- **chore**: Bump dev version 0.5.2.0 -> 0.5.3.0 per ADR-0035 patch+1 convention after Sprint 35 store release of 0.5.2.0. Updated all 7 refs: `mobile-app/pubspec.yaml` (`version: 0.5.3+1`, `msix_version: 0.5.3.0`), `mobile-app/lib/main.dart` (background_scan log filename), `mobile-app/lib/ui/screens/settings_screen.dart` (About-screen version label), `mobile-app/lib/core/services/background_scan_windows_worker.dart` (log filename), and two CLAUDE.md example refs. Test suite: 1363 passing / 0 failing post-bump
- **chore**: New Stop-hook at `.claude/hooks/sprint-auto-advance.ps1` + wiring in `.claude/settings.local.json` to enforce the Phase Auto-Advance Rule (CLAUDE.md section 7) and Standing Approval Inventory (SPRINT_EXECUTION_WORKFLOW.md Phase 3.7). Doc-only controls proved insufficient for Opus 4.7; a hard forcing function is required. Hook blocks end-of-turn procedural questions on sprint branches while whitelisting legitimate SPRINT_STOPPING_CRITERIA.md §1-9 reasons. Test suite at `.claude/hooks/test-cases/*.json` (7 cases, all passing). Emergency bypass: append `_allow_stop_hook_bypass` to branch name. Companion memory: `feedback_auto_advance_hook.md`. Established after Opus 4.7 was observed violating its own Sprint 35 retro rule during Sprint 36 kickoff -- cost several hours projected if left unfixed (Issue #244)
- **docs**: Phase 1 Backlog Refinement is now MANDATORY every sprint (no PO request required). Updated `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 1 header and sub-steps 1.1/1.2/1.3 (promoted 1.2 to owned Phase 1 step: present candidates to user in BACKLOG_REFINEMENT.md bullet-list format, NOT grid tables, for selection). Updated `docs/SPRINT_CHECKLIST.md` with a new Phase 1 section ahead of Phase 2 plus a Phase 3 gate ("if Phase 1 was skipped, STOP and return to Phase 1 first"). Added a 6th Opus 4.7 entry to CLAUDE.md Model-Version Pitfalls appendix. Extended Stop-hook whitelist with 3 phrase families covering legitimate Phase 1 refinement presentations, Phase 3 plan-approval gates, and Phase 7 retrospective prompts (10/10 test cases passing, up from 7/7). Triggered by Sprint 36 kickoff skipping Phase 1 under the prior "OPTIONAL - On-Demand" language (Issue #244)

### 2026-04-21 (Sprint 36 Task 1 -- F81 Store Release Process Documentation)
- **docs**: F81 new `docs/STORE_RELEASE_PROCESS.md` -- end-to-end team-runnable checklist for Microsoft Store releases. Covers pre-release checklist, version bump 5-file procedure, `secrets.prod.json` recreation (project uses single shared OAuth Desktop client), supported MSIX build via `flutter pub run msix:create` (honors `build_windows_args` for dart-define injection), MSIX verification (manifest version, OAuth client ID embedded, size), `develop -> main` merge (Harold-only per branch policy), Microsoft Partner Center upload + submit walkthrough, post-submission steps, troubleshooting. Closes the docs gap surfaced by the Sprint 35 prod-worktree rebuild (Issue #242)
- **fix**: F81 root `.gitignore` line 120 `*.manifest` rule (PyInstaller legacy) was catching `mobile-app/windows/runner/runner.exe.manifest`, which the Windows CMakeLists references in `add_executable` and is required for fresh-worktree builds. Scoped to `Archive/**/*.manifest` + `Archive/**/*.spec` so the Flutter runner manifest is tracked. Committed `runner.exe.manifest` (Issue #242)
- **fix**: F81 `mobile-app/secrets.prod.json.template` key names corrected to match what `gmail_windows_oauth_handler.dart` actually reads: `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` / `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` (was `GMAIL_DESKTOP_CLIENT_ID` / `GMAIL_OAUTH_CLIENT_SECRET`). Dev template works through a fallback in the handler; prod template did not have the fallback safety net and would ship with empty credentials (Issue #242)
- **chore**: F81 `mobile-app/scripts/build-msix.ps1` deprecated -- file header now documents that the supported MSIX path is `flutter pub run msix:create` (honors `build_windows_args`) and this script's makeappx.exe path ships MSIX with empty OAuth credentials. Updated `generate-appinstaller.ps1` Update Workflow help text accordingly (Issue #242)
- **docs**: F81 CLAUDE.md Common Commands -- new "Microsoft Store Release (Windows)" subsection pointing at `docs/STORE_RELEASE_PROCESS.md`. Cross-reference added to ADR-0035 References list (Issue #242)
- **fix**: BUG-S35-1 pre-insert duplicate check on the manual rule creation path. The `rules` table has no schema-level UNIQUE constraint on pattern+sub_type (only `name` is UNIQUE, and manual names carry a timestamp so they never collide), which allowed a user-created `.xyz` TLD rule to silently duplicate the bundled `._.xyz` rule during Sprint 35 F69 execution. Cleanup required direct SQLite DELETE. New `ManualRuleDuplicateChecker` service runs a normalized (lowercase, trimmed) SELECT before the insert on both the block-rule and safe-sender paths; on match, the save flow throws a sentinel exception that the existing user-friendly error infrastructure maps to "A block rule/safe sender with this pattern already exists." Safe senders already have a DB UNIQUE on `pattern` -- the pre-insert check is the primary path there for UX symmetry; the DB constraint remains as belt-and-braces. 15 new unit tests cover exact/case/whitespace duplicates across all 4 block-rule sub-types and all 3 safe-sender sub-types. Test suite: 1378 passing / 0 failing (was 1363). `flutter analyze` clean (Issue #239)
- **docs**: F80 Phase Cheat Sheet prepended to `docs/SPRINT_EXECUTION_WORKFLOW.md` right after the Phase Numbering Reference. 7-row table with Phase | Top-3 Actions | Auto-Advance Trigger, plus 4 invariants (Phase Auto-Advance, Standing Approval, Stopping Criteria, Phase 1 gate). Each phase links to its detail section anchor so resuming a sprint mid-execution reads one compact table instead of the 1357-line full doc. P3 deferred from Sprint 35 retrospective (Issue #241)
- **fix**: BUG-S35-1 refinement -- duplicate detection runs BEFORE the Confirm dialog, not after. The initial Sprint 36 fix placed the check inside `_saveBlockRule` / `_saveSafeSender` which fire after the user taps Save in the confirmation dialog, meaning the user was walked through a misleading "Confirm Block Rule" step for something that would then fail. Harold caught this during Phase 5 manual testing. New `_isDuplicate()` helper is invoked from `_confirmAndSave` immediately after pattern generation and before `showDialog`; on hit, a SnackBar with the "already exists" message shows instead of the confirm dialog. The insert-path check remains as a second line of defense against a race where a duplicate is created between dialog open and Save tap. Existing 15 unit tests still pass (Issue #239)
- **docs**: BUG-S36-1 logged for Sprint 37 carry-in (Issue #246) -- semantic subsumption check on manual rule creation. Sprint 36 BUG-S35-1 catches exact duplicates only; an `exact_domain` safe sender for `cwru.edu` is still allowed even when an `entire_domain cwru.edu` rule already covers it. Sprint 37 will extend `ManualRuleDuplicateChecker` with coverage detection across the (exact_email, exact_domain, entire_domain) hierarchy. Surfaced during Sprint 36 Phase 5 manual testing (Issue #244)

### 2026-04-25 (Sprint 36 Phase 7 -- Retrospective + Process Improvements)
- **docs**: Sprint 36 retrospective (`docs/sprints/SPRINT_36_RETROSPECTIVE.md`) -- 14 categories x 4 roles per CLAUDE.md mandate. All 3 planned tasks shipped green (1378 tests / 0 fail, +15 new). Wall clock ~3h vs 8-10h estimate. Primary process thread: "general unwillingness to follow Sprint Execution docs when winging it feels faster in the moment" (Cat 9, recurring across Sprints 34/35/36). 5 improvements approved and applied (IMP-1 to IMP-5) (Issue #244)
- **docs**: IMP-1 -- new Phase 3.2.2.1 plan-to-branch-state verification gate in `docs/SPRINT_EXECUTION_WORKFLOW.md`. Before committing `SPRINT_N_PLAN.md`, verify each task against current branch state (file paths, function presence, kickoff-commit overlap). Sprint 36 escape: Task 1.3 was already done in kickoff 46e7b6d but listed as pending; plan cited wrong file for `.gitignore` line 120. Both surfaced at Phase 4 execution; this gate catches them at plan-write time (Issue #244)
- **docs**: IMP-2 -- new widget-test mandate in `docs/TESTING_STRATEGY.md` Widget Tests section. UX flow changes (dialog appears/skips, navigation step adds/removes) require a widget test before shipping; pure-data changes exempt. Sprint 36 escape: BUG-S35-1 fix shipped 15 DB-path tests but no widget test; pre-dialog UX defect caught only in Phase 5 manual testing (Issue #244)
- **docs/feat**: IMP-3 -- `/startup-check` skill extended with Phase 3.7 approval verification gate. On any `feature/*Sprint*` branch with `SPRINT_N_PLAN.md` present, skill checks PR comments, issue comments, and memory for approval-language evidence before allowing Phase 4 work. Hard stop equivalent to the Phase 1 gate. Sprint 36 escape: Claude resumed session, read plan, started Task 1 without verifying Phase 3.7 approval; Harold caught it manually. Companion memory `feedback_approval_verification.md` (Issue #244)
- **docs**: IMP-4 -- new entry 7 in CLAUDE.md Opus 4.7 Model-Version Pitfalls appendix: "Improvising around the Sprint Execution docs when following them would feel slower in the moment". Enumerates 6 concrete failure modes from Sprints 34-36 (skipped startup-check, skipped TaskList, skipped approval verification, skipped plan verification, skipped sibling sweep, raw flutter commands instead of project scripts) and the corrective behavior. Companion memory `feedback_follow_the_docs.md` (Issue #244)
- **docs**: IMP-5 -- new memory `feedback_background_task_stdout.md`. Before arming Monitor on a background-task output file, verify it is being written; 0-byte file = silent monitor regardless of build outcome. Sprint 36 cost ~10 min on this; recurring across sprints (Issue #244)

### 2026-04-20 (Sprint 35 close-out - Microsoft Store submission of 0.5.2.0)
- **release**: Microsoft Store submission of MyEmailSpamFilter 0.5.2.0 (16.56 MB MSIX, identity `KimmeyConsulting-Ohio.MyEmailSpamFilter`). Built from prod worktree on `main` post develop -> main merge with `APP_ENV=prod` and `secrets.prod.json`. Replaces 0.5.1.0 in store (Sprint 28 release) (Issue #237)
- **docs**: F81 (Issue #242) scope expanded after prod-worktree rebuild surfaced 3 silent-failure-prone gaps: (1) `secrets.prod.json` recreation procedure missing entirely (recreated by copying `secrets.dev.json` since project uses single shared OAuth client); (2) `mobile-app/.gitignore` line 120 (`*.manifest`) catches `runner.exe.manifest` which is required by Windows runner CMakeLists, breaking fresh worktree builds; (3) `msix:create` does NOT inherit dart-defines through its internal `flutter build windows` -- `build_windows_args` in `msix_config` is mandatory or the MSIX ships with empty OAuth credentials (Gmail sign-in fails for every user at runtime). All three now in-scope for Sprint 36 F81. Estimate revised 3-4h -> 5-6h (Issue #237)
- **chore**: prod worktree (`D:\Data\Harold\github\spamfilter-multi-prod`) now has `secrets.prod.json` (gitignored), `runner.exe.manifest` (gitignored, hand-copied), and `build_windows_args` line in `pubspec.yaml` `msix_config` block. Dev worktree pubspec NOT yet updated with matching `build_windows_args` -- F81 must add it for symmetry (Issue #237)

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
- **chore**: Bump dev version 0.5.1.0 -> 0.5.2.0 for next Microsoft Store submission. Updated `pubspec.yaml` (`version: 0.5.2+1`, `msix_version: 0.5.2.0`) plus 3 hardcoded refs (`lib/main.dart`, `lib/ui/screens/settings_screen.dart`, `lib/core/services/background_scan_windows_worker.dart`) plus CLAUDE.md examples. Built signed MSIX 0.5.2.0 (17.4 MB) at `mobile-app/build/windows/x64/runner/Release/my_email_spam_filter.msix` -- ready for store upload after develop -> main merge. Sprint 36 will bump dev to 0.5.3.0 (Issue #237)
- **fix**: `mobile-app/scripts/build-msix.ps1` -- escape literal angle brackets in Write-Host string that PowerShell parser was interpreting as redirection operators (`<path-to-msix>` -> `[path-to-msix]`). Note: actual MSIX build now uses `flutter pub run msix:create` (Dart `msix` package per `msix_config` in pubspec); the build-msix.ps1 script is the alternative makeappx.exe path (Issue #237)
- **docs**: Sprint 35 retrospective Category 13 addendum -- F81 added as Sprint 36 mandatory carry-in (Issue #242): document the end-to-end store release process so the team can run it without me. Scope: new `docs/STORE_RELEASE_PROCESS.md` covering version bump (5-file checklist), supported rebuild instructions (`flutter pub run msix:create`), MSIX verification, develop -> main merge, Microsoft Partner Center upload + submit walkthrough; deprecate or remove `mobile-app/scripts/build-msix.ps1`; cross-references in CLAUDE.md and ADR-0035. Triggered by Sprint 35 store-prep surfacing the gaps in real time (Issue #237)

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
