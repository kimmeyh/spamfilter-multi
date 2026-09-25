# Sprint 74 Plan -- APPROVED, IN EXECUTION

**Status**: **APPROVED 2026-09-25, Phase 4 EXECUTION.** Amendments recorded under "Phase 3.7 approval".
**Branch**: `feature/20260924_Sprint_74` | **PR**: #440 (draft, Phase 3.3.1)
**Issues**: #428 (MV74-1), #434 (MV74-2), #422 (F232, MV74-3), #433 (F205, MV74-3), #437 (F222), #438 (F202), #439 (F206)
**Version**: 0.16.0+7 -> **0.17.0+8** (Task 0)

**Scope selected by Harold, 2026-09-24 (Phase 8.4)**: MV74-1, MV74-2, MV74-3, F202, F222, F232,
F206, F205.

**Store note**: 0.16.0 was submitted to BOTH stores on 2026-09-24 (Harold: "rollouts of 0.16.0 are
in process"). Not yet observed live. MV74-1 needs 0.16.0 on the S24+, so it can start the moment
the Play rollout reaches that device -- it does not wait for any code in this sprint.

**Model note (SPRINT_PLANNING.md "Activities Requiring Fable/Opus")**: planned on Opus 5.5. The
document prefers Fable 5 when enabled; Sprints 72 and 73 were planned and run as "Fable/Opus" and
the Sprint 73 retrospective recorded that as expectations met. Flagged, not blocking.

**Single-session note (SPRINT_PLANNING.md, Sprint 68 IMP-4, option (a))**: this sprint is expected
to run as one interactive session, with Harold's device runs interleaving. Assignments below reflect
task SHAPE; execution will be the session model, and `Executed-by` cites this line rather than
repeating the reason per task.

---

## ADR-0042 applies to EVERY task in this sprint

Harold, restated 2026-09-24: *"everything needs to take into account both the Windows App and the
Android app and ADR stating that everything should be functionally and UI the same unless it cannot
be - and where it cannot be it should be implemented as a platform exception for what is needed --
this applies to all backend code, frontend code, data, architecture, development, security,
testing, deployment."*

1. **A difference must be a DECLARED exception** -- narrow, justified, covering only what genuinely
   cannot be shared.
2. **A PARITY claim needs the SAME verification as an exception** (CLAUDE.md IMP-5, Sprint 70). For
   shared code touching OS-level behavior, the card NAMES the OS behavior assumed identical, or
   declares the exception.

Every card carries a **`Platform parity`** line. Where behavior differs, BOTH branches are tested.

**Known platform asymmetries in this sprint's scope** (all verified during planning, 2026-09-24):

- **Background-scan isolation (MV74-2)**: on Android the WorkManager scan runs in its OWN Dart
  isolate -- `workmanager_android` 0.10.6 `BackgroundWorker.kt:101` creates a new `FlutterEngine`
  per worker, `:147` runs the Dart callback in it, `:309` destroys it. On Windows the background
  scan is a separate PROCESS (Task Scheduler). **Neither platform shares the UI's `ScanCoordinator`
  with a background scan.** The comment at `scan_coordinator.dart:26-27` ("On Android every scan
  shares one process, so this coordinator IS the whole guarantee") is false.
- **File export destination (F206)**: Android app-private storage is unreachable by the user and
  has no browsable Downloads path; Windows has a browsable AppData/Documents path. A genuine
  declared exception, shaped as a platform factory (ADR-0042's preferred shape, prior art F161).
- **Doze (MV74-1)** is Android-only at the OS level.
- **Scan mode by environment**: Windows DEV/Prod are READ-ONLY with background OFF; the Android
  closed test is the only build that acts on mail. A CONFIGURATION difference, not a code
  exception -- and it is why MV74-3, F232 and F205 must be reproduced on the S24+.

---

## Phase 3.2.2.1 findings (plan-to-branch-state gate) -- they change four cards

Three read-only audits ran against the branch on 2026-09-24. Each finding below is cited in its
card; the two load-bearing claims were re-verified directly, not relayed.

1. **MV74-2's open question is SETTLED from source** (above). It is no longer an investigation --
   it is a fix, and it raises a question the card did not ask (Open question 3).
2. **F222: the card's premise was wrong twice.** The screen DOES sort -- by folder, then sender
   domain, then address (`results_display_screen.dart:728-745`). And the card's suggested helper
   `_baseDomainFor` does not strip subdomains; the right one already exists
   (`PatternNormalization.extractRootDomain`).
3. **F222 found a real Gmail defect.** `gmail_api_adapter.dart:1061` parses the RFC 2822 `Date`
   header with `DateTime.tryParse`, which accepts ISO-8601 only. Verified by running it:
   `Tue, 23 Sep 2026 14:05:11 -0400` -> `null`, so every Gmail message's received date silently
   becomes THE SCAN TIME. Date ordering cannot work for Gmail until this is fixed.
4. **F206: partly delivered, partly misdescribed.** F233 shipped a log WRITER with Settings
   controls, not an export button. With no folder configured, the Android diagnostic log and
   live-scan CSV land in app-private storage. The Android background CSV is never written. The
   Settings label "Downloads folder (default)" is false on both platforms. And a latent defect:
   changing the export folder does not invalidate `DiagnosticLogger`'s cached directory
   (`diagnostic_logger.dart:86-100` says it must; neither setter does, `settings_screen.dart:1322`,
   `:1357`).
5. **F202: the resolver to extend already exists** -- `SettingsStore.getEffectiveFolders`
   (`settings_store.dart:761-781`) -- and its app-wide tier is UNREACHABLE for any real account
   (`:780`, pinned by `settings_store_test.dart:185-194`). F113 already ships AOL and Gmail scan
   defaults that match Harold's confirmed values. There are THREE provider maps, two with no caller
   in `lib/` (`JunkFolderConfigService`, `JUNK_FOLDERS_BY_PROVIDER`).
6. **MV74-3 has a sequencing trap.** With no CSV export folder configured, the Android diagnostic
   log writes to app-private storage (`diagnostic_logger.dart:122-144`) -- unreachable over MTP.
   The Sprint 73 note "export writes to Android/data/..." described the CSV default, not the log.
   So MV74-3 needs EITHER Task 4 (F206) first OR Harold to set the export folder before the run.

**Phase 3.2.2.2 re-estimates** follow from these and are stated per card.

---

## Task 0 -- Version bump (Phase 3.7.0b, at approval)

**Value**: This keeps a tester able to tell a dev build from what shipped (F190).

**Requirements**:
- R-1: Bump `version:`, `msix_config.msix_version` and the `+N` build number.
- R-2: **PATCH vs MINOR is Harold's call.** F202 (per-provider folder overrides) and F206 (export
  as a platform capability, clear scan history) are new user-facing capabilities. Recommendation:
  **MINOR `0.17.0+8`**.
- R-3: `+8` regardless -- Play consumed versionCode 7 with 0.16.0.

**Affected components / files**: `mobile-app/pubspec.yaml`, `docs/STORE_VERSION_STATUS.md` dev row.
**Existing abstraction checked**: N/A. **Callers of any guard being changed**: none.
**User-reachable control**: N/A.
**Dependencies / blockers**: Harold's R-2 decision.

**Acceptance criteria**:
- AC-1: `dev_version_ahead_test` and `version_consistency_test` both GREEN.

**Tests to write**: none new -- the two policy gates are the verification.
**Definition of Done**: default DoD PLUS both version gates green.
**Model**: Haiku -- *why not cheaper*: n/a, cheapest tier.
**Step-types**: DATA, DOCS
**Est-Effort**: 10-15m

**Platform parity**: one `version:` field feeds both platforms (ADR-0043). One source of truth, not
an exception.

**Decision-class interrupts**: Class-3 -- R-2 at approval.

---

## Task 1 -- MV74-2 / F207: background scans run in a separate isolate -- make the warning honest (Priority 2, Issue #434)

**Value**: This prevents the "background scan in progress" warning from being either stale (a dead
scan blocking for 30 minutes) or silent (a live scan hidden), on both platforms.

**Requirements**:
- R-1: **DONE at planning -- the isolate question is settled from source** (see the asymmetry
  section). Record the determination in the card's issue and drop the device experiment the card
  proposed; it would only re-prove what the plugin source shows.
- R-2: Correct every comment that asserts a one-process or in-process guarantee that does not hold:
  `scan_coordinator.dart:1`, `:26-27`, `:109`; `DozeScanTrigger.kt:21-22`;
  `scan_progress_screen.dart:790-807` (including the log line at `:803-807` that can never fire).
- R-3: Add a **liveness heartbeat** to `scan_results`: a nullable `last_heartbeat_at` column (DB v9,
  PRAGMA-guarded `ALTER`, following the v8 block at `database_helper.dart:571-597`, and added to
  `_createTables`). The scanning isolate writes it at start and at least once per folder/batch.
- R-4: The warning (`shouldWarnAboutBackgroundScan`, `scan_progress_screen.dart:757-763`, via
  `scan_result_store.dart:528-552`) treats a background row as ACTIVE only if its heartbeat (or,
  for pre-v9 rows, `started_at`) is within a freshness window SHORTER than the 30-minute timeout.
  Proposed: 5 minutes. A row with a stale heartbeat is not active, so a dead scan stops blocking
  within minutes rather than 30.
- R-5: **Open question 3** -- whether this task also adds real cross-isolate MUTUAL EXCLUSION (the
  background worker skips an account whose fresh manual row is in progress). Planned as optional
  sub-task R-5; built only on approval.

**Affected components / files**:
- `lib/core/storage/database_helper.dart` -- v9 column (schema + upgrade)
- `lib/core/storage/scan_result_store.dart:528-552` -- freshness query; new heartbeat writer
- `lib/core/providers/email_scan_provider.dart` / `lib/core/services/email_scanner.dart` -- heartbeat
  call points
- `lib/core/services/scan_coordinator.dart`, `android/.../DozeScanTrigger.kt`,
  `lib/ui/screens/scan_progress_screen.dart` -- comment corrections

**Existing abstraction checked**: `ScanResultStore` active-row query (extended, not duplicated);
`ScanCoordinator.scanTimeout` (the 30-minute constant stays the reconciler's bound).
**Callers of any guard being changed**: the active-row query is read by (a) the manual-scan warning
and (b) nothing else found at planning -- the executor re-greps before changing it and records the
result here.
**User-reachable control**: N/A (behavior of an existing warning).
**Dependencies / blockers**: None for R-1..R-4. R-5 waits on Open question 3.

**Non-functional requirements**:
- Persistence: v9 migration is additive and nullable; downgrade is not supported (house rule, no
  SQLite downgrades).
- Concurrency: WAL + 30s busy timeout are already set (`database_helper.dart:109-111`); heartbeat
  writes must be single-row UPDATEs, not transactions spanning the scan.

**Acceptance criteria**:
- AC-1: No comment in `lib/` or the Kotlin sources asserts that the UI `ScanCoordinator` guards a
  background scan (grep result recorded).
- AC-2: Given a background row `in_progress` whose heartbeat is older than the freshness window,
  When the user starts a manual scan, Then no stale-scan warning appears.
- AC-3: Given a background row `in_progress` with a fresh heartbeat, When the user starts a manual
  scan, Then the warning appears.
- AC-4: A v8 database upgrades to v9 with existing rows intact and the new column NULL.

**Tests to write**:
- T-1 (AC-2, AC-3) -- TEST-UNIT in `test/unit/ui/f207_stale_background_warning_test.dart`: fresh vs
  stale heartbeat decide the warning. **What this would NOT catch**: a scanner that never WRITES the
  heartbeat -- T-3 covers that.
- T-2 (AC-4) -- TEST-UNIT in the existing migration test file: v8 -> v9 upgrade.
- T-3 -- TEST-UNIT: a scan writes the heartbeat at least once per folder (mutation: delete the write
  call; T-3 must go red).

**Definition of Done**: default DoD PLUS ARCHITECTURE.md `ScanCoordinator` row corrected (process vs
isolate) and the `scan_results` schema listing updated.
**Model**: Sonnet -- *why not cheaper*: a schema migration plus a cross-isolate concurrency argument;
Haiku has no margin for the migration's failure modes.
**Step-types**: DB-MIGRATE, SVC-EDIT, TEST-UNIT, DOCS
**Est-Effort**: 90-150m (R-5 adds 60-90m if approved). *Re-estimate (3.2.2.2)*: card said 30-60m
plus 120-180m if confirmed; confirmation is now a planning fact, so the investigation half is gone
and the fix half is costed from the step-types.

**Platform parity**: SAME on both. The heartbeat is written by whichever process or isolate runs the
scan, and read from the shared DB. OS behavior assumed identical: SQLite WAL across two writers --
two isolates on Android, two processes on Windows -- which is the same guarantee in both cases.

_**Risk & rollback**_: DATA task. Risk: a heartbeat too sparse marks a live scan stale. Mitigation:
write per batch, window 5 minutes against batches that take seconds. Rollback: the column is
nullable and ignored if the query reverts.

_**Decision-class interrupts**_: **Class-1 (architecture)** -- R-5 adds cross-isolate mutual
exclusion that ADR/F175 never provided. Surfaced as Open question 3.

---

## Task 2 -- F222: order scan results newest-first, clustered by base domain (Priority 22, Issue #437)

**Value**: This makes the results list read like the inbox, which a tester called "quite confusing"
today.

**Requirements**:
- R-1: **Fix Gmail's received date first.** Use the message's `internalDate` (epoch ms) --
  documented in `googleapis` 11.4.0 `gmail/v1.dart:5498` as the timestamp "which determines ordering
  in the inbox" and "more reliable than the `Date` header" -- instead of `DateTime.tryParse` on the
  RFC 2822 header (`gmail_api_adapter.dart:1061`), which returns null and falls back to scan time.
  Keep the header only as a fallback, parsed with an RFC 2822-capable parser.
- R-2: Replace the existing comparator at `results_display_screen.dart:728-745` (folder, domain,
  address) with Harold's specified ordering: take the newest remaining email; emit it and every other
  remaining email sharing its BASE domain, newest-first within the cluster; repeat.
- R-3: The provider section stays pinned at the top, unchanged: the new ordering applies WITHIN each
  group produced by `ProviderSenderGrouping.partitionProviderFirst` (a stable partition,
  `provider_sender_grouping.dart:30-44`).
- R-4: Base domain = `PatternNormalization.extractRootDomain` over
  `EmailBodyParser.extractDomainFromEmail`. NOT `_baseDomainFor`, which keeps subdomains.
- R-5: The sort must operate on a copy -- never reorder the provider's own list (the in-place sort at
  `:729` is safe today only because an earlier filter copies it).
- R-6: **Open question 5** -- whether the Review No Rule Items screen
  (`no_rule_review_screen.dart:275`, sorted by DB `createdAt`, with a NULLABLE `emailDate`) gets the
  same ordering. Recommended: yes, nulls last.

**Affected components / files**:
- `lib/adapters/email_providers/gmail_api_adapter.dart:1058-1063`
- `lib/ui/screens/results_display_screen.dart:728-745`
- `lib/ui/screens/no_rule_review_screen.dart:275` (if R-6 approved)
- `test/ui/screens/results_display_no_rule_reload_test.dart:289-292` -- pins the OLD order; update it

**Existing abstraction checked**: `PatternNormalization.extractRootDomain` (reused);
`ProviderSenderGrouping.partitionProviderFirst` (reused); `_baseDomainFor` (rejected, with reason).
**Callers of any guard being changed**: `_getFilteredResults` feeds every view -- live, historical,
and the five re-reads at `:2858, 3063, 3109, 3224, 3746` -- AND the No-rule auto-advance
(`:2865-2885`), whose walk order therefore changes too. Stated so the validation step covers it.
**User-reachable control**: N/A (ordering of an existing list).
**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: A Gmail message whose `Date` header is RFC 2822 gets a `receivedDate` equal to its
  `internalDate`, not the scan time.
- AC-2: Given results from three base domains with interleaved dates, the rendered order is newest
  email, then its whole domain cluster newest-first, then the next newest remaining, and so on.
- AC-3: `news.example.com` and `example.com` cluster together; `example.co.uk` and `other.co.uk` do not.
- AC-4: The provider group is still first and its size (`_providerGroupCount`) unchanged.
- AC-5 (behavioral): Given a No-rule review in progress, When the user acts on an item, Then
  auto-advance moves to the next item in the NEW order.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: Gmail message mapping with an RFC 2822 header and an `internalDate`.
  **What this would NOT catch**: an IMAP date bug -- IMAP uses `decodeDate()`, a different path.
- T-2 (AC-2, AC-3, AC-4) -- TEST-UNIT on the extracted pure ordering function.
- T-3 (AC-5) -- TEST-WIDGET: extend the existing no-rule reload test (which pins the old order today).
- Mutation: revert the call site to the old comparator; T-3 must go red (the Sprint 73 "correct
  abstraction, wrong wiring" rule -- testing the pure function alone is not enough).

**Definition of Done**: default DoD PLUS CHANGELOG notes the Gmail date fix separately (it changes
CSV "Received Date" values too).
**Model**: Sonnet -- *why not cheaper*: the algorithm is specified, but it touches an adapter, two
screens and an existing test that pins the old order; Haiku would likely fix the function and miss
the wiring.
**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET
**Est-Effort**: 90-150m. *Re-estimate (3.2.2.2)*: card said 45-90m; +Gmail date defect, +second
screen, +an existing test to rewrite.

**Platform parity**: SAME on both -- one shared screen and one shared adapter; the only `Platform.is*`
checks in this screen are for export paths (`:573`, `:593`), untouched.

---

## Task 3 -- F202: per-provider folder defaults with an overall default (Priority 10, Issue #438)

**Value**: This prevents a new account from scanning INBOX only and never looking at its spam folder.

**Requirements**:
- R-1: **Audit first -- DONE at planning.** Already true: F113 ships AOL (`Inbox, Bulk, Bulk Mail`) and
  Gmail (`INBOX, [Gmail]/Spam, Unwanted`) scan-folder defaults via
  `SettingsStore.providerDefaultFolders` (`settings_store.dart:85-128`), matching Harold's confirmed
  values. Missing: Yahoo/iCloud/IMAP scan defaults, ANY provider default for Safe Sender and Deleted
  Rule folders, and a reachable overall default.
- R-2: Resolution order for ALL FOUR settings: account override -> provider default -> overall
  default. Extend `getEffectiveFolders` (`:761-781`) so the overall tier is reachable for real
  accounts, and add `getEffectiveSafeSenderFolder` / `getEffectiveDeletedRuleFolder` in the same
  shape (siblings of `getEffectiveScanMode`, `:738-753`).
- R-3: Remove the hardcoded fallbacks from the scan path in favor of the resolvers:
  `email_scanner.dart:268` (`?? 'INBOX'`), `:708` (`?? 'Trash'`), the `['INBOX']` fallbacks in
  `email_scan_provider.dart`, and `results_display_screen.dart:3958`. **Keep** the Gmail API's
  `?? 'TRASH'` -- a label ID, correct for that API.
- R-4: ONE provider map. `providerDefaultFolders` is the live one; `JunkFolderConfigService` and
  `JUNK_FOLDERS_BY_PROVIDER` have no caller in `lib/`. Fold the confirmed values into the live map
  and retire the dead two (or state why one must stay).
- R-5: Provider detection uses the account's stored `platformId`, not string-matching the accountId
  (`:113-127`).
- R-6: **Missing folder is not an error** (Harold's decision 3). Distinguish "folder does not exist"
  (skip silently, log at info) from "folder failed to fetch" (keep F174's `recordFolderFetchError`).
  F174 must NOT be reverted.
- R-7: **Harold's decision 1 -- no migration, no opt-in.** Existing saved selections win (tier 1).
- R-8: **Open question 2** -- whether provider defaults are user-editable in Settings or code-only.
- R-9: Values: use Harold's confirmed values only; unknown ones fall through to the overall default.
  **Open question 4** asks for Yahoo Deleted Rule, iCloud Junk and iCloud Safe Sender.

**Affected components / files**: `lib/core/storage/settings_store.dart`,
`lib/core/services/email_scanner.dart`, `lib/core/providers/email_scan_provider.dart`,
`lib/ui/screens/results_display_screen.dart`, `lib/ui/screens/settings_screen.dart` (if R-8 is
user-editable), `lib/adapters/email_providers/junk_folder_config.dart` (retire), missing-folder
handling at `email_scanner.dart:478-518`.

**Existing abstraction checked**: `SettingsStore.getEffectiveFolders` and the
`getEffective*` family (extended, not duplicated -- the Sprint 72 IMP-5 failure was a hand-rolled
copy of exactly this family).
**Callers of any guard being changed** (the resolver is the guard; all found at planning):
manual scan (`scan_progress_screen.dart:130, 943`), background scan on BOTH platforms
(`background_scan_core.dart:109`, via the Windows worker `:541` and the Android worker `:133`),
Deleted Rule consumers (`email_scanner.dart:203-204, 708, 1378-1379`, `results_display_screen.dart:
3895-3899`), Safe Sender consumers (`email_scanner.dart:265-269`, `results_display_screen.dart:
3956-3963`), the Results title (`:1226`), and the adapters' `setDeletedRuleFolder`. Effect on each:
none for an account with a saved value (tier 1 unchanged); for an account without one, provider
then overall default replace the hardcoded literal. **The re-process path (`:3895`, `:3956`) is a
LIVE-DELETION path** (Sprint 72 F232), so a changed Deleted Rule default changes where real mail
goes -- Manual Validation must cover it on the S24+.
**User-reachable control**: Settings > General > "Folder defaults" (overall + per provider) if R-8 is
user-editable; otherwise N/A and the existing Account-tab rows show the resolved default with its
source ("provider default" / "overall default") instead of the hardcoded "(default)" text.
**Dependencies / blockers**: Open questions 2 and 4 before R-8/R-9 values; the mechanism can be
built against the confirmed AOL/Gmail/Yahoo values meanwhile.

**Non-functional requirements**:
- Account-scoping: every resolver takes `accountId`; no app-wide state leaks across accounts.
- Persistence: provider overrides (if user-editable) live in the existing `app_settings` key/value
  table (`provider.<id>.<setting>`) -- NO schema change.

**Acceptance criteria**:
- AC-1: For each provider x each of the four settings, the resolver returns: saved account value if
  present; else the provider default if defined; else the overall default.
- AC-2: A new Yahoo account with no saved selection scans `Inbox` and `Bulk`.
- AC-3: A new iCloud account's Deleted Rule folder resolves to `Deleted Messages`, never `Trash`.
- AC-4: A scan whose configured folder does not exist completes with `errorCount` unchanged by that
  folder; a folder that exists but fails to fetch still increments it.
- AC-5: An existing account with a saved selection resolves exactly as before (no migration).
- AC-6: No hardcoded `['INBOX']` / `'Trash'` fallback remains in the scan path (policy gate).

**Tests to write**:
- T-1 (AC-1, AC-5) -- TEST-UNIT in `test/unit/storage/settings_store_test.dart`: the full matrix.
  Update `:185-194`, which PINS the unreachable-overall-tier behavior this card changes.
- T-2 (AC-2, AC-3) -- TEST-UNIT: provider values.
- T-3 (AC-4) -- TEST-UNIT against the scanner's folder loop: missing vs failed. **What this would NOT
  catch**: a provider whose IMAP server reports a missing folder with an error string the classifier
  does not recognize -- the classifier's input is recorded in the log so a device run can tell.
- T-4 (AC-6) -- policy gate: grep-based, then mutation-verified by re-adding one literal.
- Mutation: shadow the provider map with a hardcoded fallback; T-1 must go red.

**Definition of Done**: default DoD PLUS ARCHITECTURE.md settings-resolution section updated; the
F174 distinction documented where F174 is described.
**Model**: Fable/Opus -- *why not cheaper*: a resolver change with ten callers, one of them a
live-deletion path, plus the F174 distinction -- exactly the IMP-1 "caller safe by accident" shape.
**Step-types**: SVC-EDIT, UI-NEW (if R-8 editable), TEST-UNIT, DOCS
**Est-Effort**: 215-330m (UI-NEW adds 60-90 of that; code-only is 155-240m). *Re-estimate (3.2.2.2)*:
card said 150-240m; +three-map consolidation, +the missing-vs-failed distinction the card itself
identified, +an existing test that pins the old behavior.

**Platform parity**: SAME on both, no exception. Both background workers resolve folders through the
shared `BackgroundScanCore.scanAccount`; no `Platform.is*` exists in the folder paths (verified).
OS behavior assumed identical: none -- folder names are the PROVIDER's, not the OS's.

_**Risk & rollback**_: changes where mail is moved on the re-process path. Mitigation: tier 1 is
unchanged, so only accounts with no saved value are affected; validated on the S24+. Rollback:
resolvers are additive; reverting restores the literals.

_**Decision-class interrupts**_: **Class-2** -- the overall tier becomes reachable for real accounts
(changes `getEffectiveFolders` semantics, pinned by an existing test). Authorized by the card's
requirement; restated here for the record.

---

## Task 4 -- F206: diagnostic export as a platform capability, plus clear scan history (Priority 14, Issue #439)

**Value**: This gets scan and diagnostic data off the device on every platform, which MV74-3, F232
and F205 all depend on.

**Requirements**:
- R-1: **Audit first -- DONE at planning.** Remaining work only (finding 4 above).
- R-2 (Part A): a user-reachable **Clear scan history** action that deletes scan-history rows (and so
  resets the Scan History totals, which are computed on screen from those rows,
  `scan_history_screen.dart:381-433`). Uses the existing `deleteScanResult` /
  `deleteScanResultsByAccount` (`scan_result_store.dart:591, 618`); scope = current account filter,
  with confirmation. NOT `wipeAllData`.
- R-3 (Part B): a `DiagnosticExporter` platform factory mirroring `background_scan_scheduler.dart`
  (interface `:41`, no-op `:80`, factory `:115-131`) -- Windows writes to a browsable path; Android
  hands the file to the system share sheet (`share_plus`, NEW dependency) so the user chooses the
  destination. Registered in `test/policy/factory_call_site_test.dart`.
- R-4 (Part B): route the diagnostic log, the scan-results CSV, and the live-scan CSV through the
  factory. On Android nothing the user asked to export may land in app-private storage.
- R-5 (Part B): fix the false "Downloads folder (default)" label (`settings_screen.dart:1302`) to
  state the real destination per platform.
- R-6 (Part B): the Android background-scan CSV toggle (`settings_screen.dart:1629`) is not
  platform-gated but never writes on Android (`background_scan_windows_worker.dart` only). Either
  make it work through the factory or hide it on Android as a DECLARED exception. Recommended: make
  it work.
- R-7: fix the latent defect -- invalidate `DiagnosticLogger`'s cached directory when the export
  folder changes (`settings_screen.dart:1322`, `:1357`), as `diagnostic_logger.dart:86-100` requires.
- R-8 (Part C): **Open question 6** -- a redacted export mode (sender/subject/message id masked) for
  sharing outside the team. No CSV export redacts anything today.

**Affected components / files**: new `lib/core/services/diagnostic_exporter.dart`;
`diagnostic_logger.dart`, `live_scan_logger.dart`, `results_display_screen.dart:529-600`,
`settings_screen.dart`, `scan_history_screen.dart`, `scan_result_store.dart`, `pubspec.yaml`
(`share_plus`), `test/policy/factory_call_site_test.dart`.

**Existing abstraction checked**: `BackgroundScanScheduler` factory (prior art, mirrored); the three
duplicated CSV directory blocks (consolidated into the factory, not a fourth copy).
**Callers of any guard being changed**: the directory-resolution logic duplicated at
`results_display_screen.dart:573-575`, `rules_management_screen.dart:1111-1113`,
`safe_senders_management_screen.dart:787-789` -- rules and safe-senders CSV exports move to the
factory too, or are recorded as intentionally untouched.
**User-reachable control**: Scan History screen -> "Clear history" (with confirmation); every export
button (Results, Rules, Safe Senders, Settings > diagnostic log "Export") opens the share sheet on
Android and saves to the shown path on Windows.
**Dependencies / blockers**: Open question 6 for R-8 only.

**Non-functional requirements**:
- Security: exports contain sender/subject (not message bodies). ADR-0030 redaction applies to LOGS
  only today; Part C decides exports. `share_plus` needs no storage permission.
- Platform: declared ADR-0042 exception for the destination mechanism only.
- Play Data safety: user-initiated export via the share sheet -- whether it changes the Data safety
  answers is **unverified**; checked against Google's page during execution before any console edit.

**Acceptance criteria**:
- AC-1: On Android, exporting scan results, the diagnostic log, and the live-scan CSV each opens the
  system share sheet with the file attached; on Windows each writes to the path the dialog shows.
- AC-2: Given Scan History filtered to one account, When the user confirms Clear history, Then that
  account's rows are gone, totals read 0, and other accounts' rows remain.
- AC-3: After changing the export folder, the next diagnostic log line is written to the NEW folder.
- AC-4: The Settings export-folder subtitle names the real default on each platform.
- AC-5: `factory_call_site_test` passes with the new factory registered.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: factory resolution per platform (both branches, via the test seam).
- T-2 (AC-2) -- TEST-UNIT: scoped delete. **What this would NOT catch**: the share sheet actually
  appearing -- that is Manual Validation on the S24+.
- T-3 (AC-3) -- TEST-UNIT: cache invalidation (mutation: remove the invalidate call).
- T-4 (AC-4) -- TEST-WIDGET.

**Definition of Done**: default DoD PLUS ARCHITECTURE.md gains the `DiagnosticExporter` row and the
declared exception; ADR-0042's exception list updated.
**Model**: Sonnet -- *why not cheaper*: a new platform factory, a new dependency with Android
manifest implications, and four call sites.
**Step-types**: SVC-NEW, SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET, DOCS
**Est-Effort**: 210-330m for Parts A + B; Part C adds 45-75m. *Re-estimate (3.2.2.2)*: card said
120-210m; the audit found three export paths (not one) plus two latent defects.

**Platform parity**: DECLARED EXCEPTION for the destination (share sheet vs file path) only. Content,
format, redaction, triggers and UI are identical.

_**Risk & rollback**_: new dependency. Risk: `share_plus` version conflicts with the pinned plugin
set (the Sprint 73 build lesson applies -- judge the build by its final line). Rollback: the
factory's Windows branch is today's behavior; removing the Android branch restores it.

---

## Task 5 -- MV74-1: F235 Doze scheduling on the S24+ (Priority 2, Issue #428)

**Value**: This proves background scans fire on a real dozing phone and survive a reboot -- the only
evidence that settles F235.

**Requirements**:
- R-1: Harold runs 0.16.0 (from the Play rollout) on the S24+ with background scanning ON.
- R-2: Observe (a) scans firing while idle / screen off over several hours; (b) after a REBOOT, scans
  resume without opening the app. The reboot case matters most -- without `BootReceiver` it is a
  regression against WorkManager.
- R-3: Evidence = Scan History rows (type Background) with timestamps across the idle window and
  across the reboot, captured by screenshot and pulled over MTP.

**Affected components / files**: none (validation).
**User-reachable control**: Settings > Background (existing).
**Dependencies / blockers**: 0.16.0 installed on the S24+ via Play.
**Acceptance criteria**:
- AC-1: At least two Background rows while the screen was off, spaced within the expected ~1 hour
  window.
- AC-2: At least one Background row after a reboot with no app launch in between.
**Tests to write**: none -- no unit test can prove an alarm fired on a dozing phone (IMP-1).
**Definition of Done**: evidence recorded in this plan and on #428; #428 closed only if both ACs hold.
**Model**: Haiku -- *why not cheaper*: n/a. Reading screenshots and recording evidence.
**Step-types**: DOCS
**Est-Effort**: 20-40m of team time, plus hours of elapsed device time.
**Platform parity**: Android-only, declared (Doze has no Windows equivalent).

---

## Task 6 -- MV74-3: device run with diagnostic logging (Priority 4, Issues #422, #433)

**Value**: This produces the data F232 mechanism B and F205 have been blocked on for two sprints.

**Requirements**:
- R-1: Sequencing (finding 6): run AFTER Task 4 lands, or Harold first sets Settings > General >
  CSV Export Directory to a reachable folder. Otherwise the log is written to app-private storage.
- R-2: Enable Settings > diagnostic log; reproduce F232 (open a saved scan, add a block rule, observe
  the re-process result) and run a Gmail manual scan (F205); export the log.
- R-3: Pull the file over MTP (adb is unavailable by company policy).
**Acceptance criteria**:
- AC-1: A diagnostic log from the S24+ containing at least one F232 re-process attempt with its
  per-message outcome, and one scan's error entries if any occur.
**Tests to write**: none (data collection).
**Definition of Done**: file pulled and its path recorded in this plan.
**Model**: Haiku -- *why not cheaper*: n/a.
**Step-types**: DOCS
**Est-Effort**: 30-60m of team time.
**Platform parity**: Android for the reproduction (only the closed test acts on mail); any fix follows
ADR-0042.

---

## Task 7 -- F232 mechanism B: a live batch fails 9 of 9 on a healthy connection (Priority 6, Issue #422)

**Value**: This stops the app from showing every sign of success while nothing happens on the mail
server.

**Requirements**:
- R-1: **Do NOT plan a fix before the Task 6 log exists** (the card's own rule, held since Sprint 73).
- R-2: From the log: distinguish an `allFailed` return (guard tripped, "not connected") from a thrown
  exception (server refused the messages), and record the ids and the selected mailbox.
- R-3: Fix the confirmed cause; if the log does not settle it, record what it DID show and carry the
  card with a narrower question rather than guessing.

**Affected components / files**: `results_display_screen.dart` re-process path (`:3636` onward),
`generic_imap_adapter.dart` batch path -- confirmed only after the log.
**Callers of any guard being changed**: to be enumerated once the fix site is known (IMP-1).
**User-reachable control**: N/A (existing action).
**Dependencies / blockers**: Task 6.
**Acceptance criteria**:
- AC-1: The cause is named from log evidence, or the card records why the log could not settle it.
- AC-2: If fixed: on the S24+, adding a block rule from a saved scan moves the matching messages,
  and the result toast reports N of N succeeded.
**Tests to write**: T-1 -- a regression test at the confirmed fix site. **What it would NOT catch**
is stated once the cause is known.
**Definition of Done**: default DoD PLUS Manual Validation on the S24+ (live-deletion path).
**Model**: Fable/Opus -- *why not cheaper*: an open diagnosis on a live-deletion path.
**Step-types**: IMAP, SVC-EDIT, TEST-UNIT
**Est-Effort**: 60-120m after the log (card estimate held).
**Platform parity**: shared code; the reproduction is on Android because only that build acts on mail.

---

## Task 8 -- F205: classify the 53 errors (Priority 18, Issue #433)

**Value**: This explains the only unexplained number on the Scan History screen before the tester
count reaches 12.

**Requirements**:
- R-1: First confirm whether NEW errors accrue on 0.16.0 (the card narrowed the 53 to Gmail and
  pre-0.15.0).
- R-2: If none: record that and close #433. If some: classify from the Task 6 log and fix or file.
- R-3: Note: after Task 3's R-6, a missing folder no longer counts as an error -- recheck the count
  after Task 3 lands before attributing anything.
**Acceptance criteria**:
- AC-1: Every error on the current build is classified by cause, or the count is zero and recorded.
**Tests to write**: only if a fix results.
**Model**: Haiku -- *why not cheaper*: n/a.
**Step-types**: DOCS (plus a fix step-type if one results)
**Est-Effort**: 30-60m.
**Dependencies / blockers**: Task 6; Task 3 R-6 (changes what counts as an error).
**Platform parity**: Android for data; check Windows for the same class.

---

## Progress (live)

- Task 0 -- DONE `dfa4881` (0.17.0+8). Missed the F196 release notes the bump made due; added in `3a3690e`.
- Task 1 MV74-2 -- DONE `3a3690e` (heartbeat v9, honest warning, cross-isolate exclusion). Review round: C-2 write test.
- Task 2 F222 -- DONE `5bea2a2` (ordering + Gmail internalDate).
- Task 4 F206 -- DONE `f9ee85c` (ExportDirectories, shared per-scan export, clear history, redaction). ADR-0042 correction: one conditional, not a factory.
- Task 3 F202 -- DONE `f95a346` (code-only; the editable-defaults question is asked at Manual Validation).
- Tasks 5-8 -- device work on the S24+: Manual Validation.

## Phase 5 evidence (F193 gate)

- **5.1.1 automated code review**: 2026-09-25, TWO independent reviews of `4c64a30..HEAD` (pr-review-toolkit code-reviewer + pr-test-analyzer). Code review: 0 CRITICAL, 4 IMPORTANT, 4 MINOR. Test review: 2 CRITICAL, 6 IMPORTANT. Dispositions:
  - FIXED: DEV/PROD shared one diagnostics folder and each could delete the other's logs (env-suffixed `diagnostics_Dev`); mid-day redaction mixed rows in one daily file (`_redacted` file name); exact-sender RULE PATTERNS leaked addresses through "domain only" redaction (addresses masked in Rule/Match Condition); Android 7-10 cannot write public Documents without a permission (probe + fallback to the app's own folder); a stored `platform_id='unknown'` bypassed the heuristic; the Clear history count could undercount (store-side count); no test proved the heartbeat WRITES (injectable interval + real-write test + interval/freshness invariant); worker post-scan branch untested (`BackgroundScanCore.completeAccount` seam + both branches + wiring gate); Gmail API vs gmail-imap untested at the scanner/adapter boundary (3 recording-fake scanner tests); the doc comment claiming the exclusion covers re-processing was FALSE (corrected in code, ARCHITECTURE.md and ADR-0039).
  - SURFACED, Class-2, not implemented: a manual scan writes its `scan_results` row only AFTER connecting, and re-processing writes no row -- so the exclusion has a window of seconds per scan start and does not cover re-processing. Closing both is an ordering change (a pre-connect failure would then leave an `error` row in Scan History). Asked at Manual Validation.
  - SURFACED, product: exports default ON (F113), so every scan now writes files into Downloads/Documents. Asked at Manual Validation.
  - NOTED, not changed: a Windows skip is logged as an empty success row (M-2); same-day append to a daily file left by an earlier Android install can fail (I-4 remainder).
  - NOT COVERED by tests (named, not dropped): the Clear history button/dialog and the redaction toggle wiring -- Manual Validation steps.
  - Mutations for the round: 6 KILLED (heartbeat write, env suffix, redacted file, pattern redaction, probe fallback, unknown platform).
- **5.1.2 F-PRECHECK**: 2026-09-25, all six ACTIONS run against `git diff 4c64a30..HEAD` -- 2 FOUND AND FIXED, 4 CLEAN:
  1. Mirror-site sync -- CLEAN: manual + background scan paths share `scanInbox` (resolvers applied there) and the re-process path was updated the same way; live + background exports share `ScanSheetExport`; Android + Windows workers both call `BackgroundScanExport`; the CI-Linux vs local-Windows pair: the one platform-gated assertion (export label) is platform-aware.
  2. Helper wired into production -- CLEAN: all 11 new helpers have a runtime call site (grep recorded in the session).
  3. Doc-comment drift -- FOUND 4, FIXED: `DiagnosticLogger.resolveLogDir` doc (old app-support fallback), `LiveScanLogger` header + method doc (pointed at the removed Windows function and `{logs}`), `defaultCsvExportDirectory` comment.
  4. Fragile parsing -- CLEAN: `publicDocumentsFrom` returns null on an unexpected shape (caller falls back); `inferPlatformId` checks `gmail-imap-` before `gmail-`; `int.tryParse` for internalDate.
  5. API scope -- CLEAN: `listFolders` is account-wide and only answers "does this folder exist on THIS account"; clear-history and the exclusion query are account-scoped; `getActiveBackgroundScan` stays any-account by design (F175 notice).
  6. Silent failure -- FOUND 5, FIXED: five new `catch (_)` fallbacks now log at warning (ExportDirectories x2, Gmail date, folder listing, platform-id read). None was destructive; each falls back conservatively.
- **5.1.5 WinWright sweep**: 2026-09-25 at `92411c5` (dev exe rebuilt 09:45 from that commit; it contains every `lib/ui` change of the sprint) -- **2 of 2 scripts PASSED, 29/29 steps each, no DB drift**, workstation-unlocked check passed. Scripts: `test_f124_rule_labels.json` (17s), `test_mt2c_no_rule_sweep.json` (21s). New UI with NO script yet -> Sprint 75 carry-in (5.1.5 step 5): Scan History Clear history, Settings "Hide sender details in exports", the Account tab's resolved-default folder rows.

  sweep-head: `92411c5`

- **5.1.6 Runtime Launch Gate**: N/A -- no Android config touched (the only `android/` change is a comment in `DozeScanTrigger.kt`; no manifest, res/xml, gradle or R8 change).

## Manual Validation decisions -- Harold, 2026-09-25

- **Q1 -- close both exclusion gaps** (Class-2, approved): *"ensure a scan that fails before connecting updates that the scan is no longer running."* DONE: the scan row is written right after the lease and before connecting; a pre-connect failure closes it `error` (proven by test); re-processing holds a heartbeating `reprocess` claim row. 4 mutations KILLED.
- **Q2 -- per-scan exports OFF by default** (reverses F113's ON). DONE.
- **Q3 -- F202 provider defaults stay code-only.** No Settings editor.
- **Q4 -- "the normal way"**: read as Harold uploading 0.17.0 through Google Play closed testing. The AAB is rebuilt after Q1/Q2.
- **Device note**: the S24+ is being replaced by a Galaxy Z Fold8 Ultra; device steps apply to either (same USB-debugging policy, MTP for files).

## Phase 3.6.1 Architecture Impact Check

- **ARCHITECTURE.md** -- updates REQUIRED (included in each card's DoD, done before Manual Validation
  per the no-defer rule):
  - `ScanCoordinator` row: currently says scans "never run concurrently within a process" -- true,
    but it implies a guarantee against background scans that does not exist. Correct it (Task 1).
  - `scan_results` schema: `last_heartbeat_at`, DB v9 (Task 1).
  - Settings resolution: the four folder settings' three-tier order (Task 3).
  - New `DiagnosticExporter` platform factory (Task 4).
- **ADRs**:
  - ADR-0042: add the F206 destination exception to its exception list (Task 4).
  - If Open question 3 approves cross-isolate exclusion: a NEW ADR, because it changes the F175
    concurrency model. Otherwise no new ADR.
- **ARSD.md**: no requirement changes identified.
- **Schema**: one additive migration (v8 -> v9).

## Dependency watch (Phase 2 pre-kickoff)

`dart pub outdated` reports one DISCONTINUED package: `js` 0.6.7, pulled in only by
`connectivity_plus` 5.0.2 and web-only, so no effect on Windows or Android. Upgrading
`connectivity_plus` to 7.x removes it. Not in scope; recorded so it is not rediscovered.

---

## Sprint summary

| Task | Item | Model | Est (min) | Depends on |
|---|---|---|---|---|
| 0 | Version bump | Haiku | 10-15 | approval |
| 1 | MV74-2 heartbeat + honest comments | Sonnet | 90-150 (+60-90 if Q3) | Q3 for R-5 only |
| 2 | F222 ordering + Gmail date fix | Sonnet | 90-150 | Q5 for the second screen |
| 3 | F202 folder defaults | Fable/Opus | 215-330 | Q2, Q4 |
| 4 | F206 export factory + clear history | Sonnet | 210-330 (+45-75 if Q6) | Q6 for Part C only |
| 5 | MV74-1 Doze on the S24+ | Haiku | 20-40 (+device hours) | 0.16.0 on the S24+ |
| 6 | MV74-3 device log run | Haiku | 30-60 | Task 4, or export folder set |
| 7 | F232 mechanism B | Fable/Opus | 60-120 | Task 6 |
| 8 | F205 classify errors | Haiku | 30-60 | Tasks 6 and 3 |

**Total estimated**: **755-1,255 minutes (~12.5-21 hours)** before optional sub-tasks; with R-5
(Task 1) and Part C (Task 4), 860-1,420 minutes.

**Model mix**: Haiku 4, Sonnet 3, Fable/Opus 2. The two top-tier assignments are the resolver change
with a live-deletion caller (Task 3) and the open diagnosis (Task 7).

**Suggested order**: 0 -> 1 -> 2 -> 4 -> 3, with Task 5 running on the device in parallel from the
start, and Task 6 as soon as Task 4 lands. Task 4 before Task 3 because MV74-3 needs a reachable log,
and Tasks 7 and 8 wait on that.

**Calibration note**: Sprint 73 tasks landed in or under estimate (F234 45-90 -> ~75; F224+F207
150-300 -> ~120). These estimates are derived from step-types plus those actuals, per
`CODING_VELOCITY.md` Rule 2 -- not converted from hours.

## Open questions for Harold at approval

1. **Version bump (Task 0)**: MINOR `0.17.0+8` or PATCH `0.16.1+8`? Recommendation: MINOR.
2. **F202 provider defaults (Task 3, R-8)**: user-editable per provider in Settings > General, or
   code-only (Harold-confirmed values, editable only per account as today)? Recommendation:
   user-editable -- your own words were that the team cannot decide a provider's folders, and an
   editable default is how a user corrects one without waiting for a release. Costs 60-90m.
3. **Cross-isolate exclusion (Task 1, R-5, Class-1)**: planning CONFIRMED that on Android a manual
   scan and a background scan can run at the same time on the same account -- the only barrier is the
   user answering the warning. Add real exclusion (the background worker skips an account with a
   fresh manual row), or ship the honest warning only? Recommendation: add it -- two concurrent IMAP
   sessions on one account is the Sprint 61 failure the coordinator was built to prevent. Needs a new
   ADR.
4. **F202 values (Task 3, R-9)**: what are Yahoo's Deleted Rule folder, and iCloud's Junk and Safe
   Sender folders? Unknown ones fall through to the overall default until supplied.
5. **F222 second screen (Task 2, R-6)**: apply the same ordering to Review No Rule Items?
   Recommendation: yes, undated items last.
6. **F206 Part C (Task 4, R-8)**: build the redacted export mode this sprint (+45-75m), or backlog it?
   Recommendation: backlog -- the exports go to you today, not outside the team.
7. **Sprint size**: ~12.5-21 hours across 9 tasks, the largest planned in some time. Accept in full,
   or defer Task 4 Part A (Clear history, ~45-75m), which nothing else depends on?

## Phase 3.7 approval

**APPROVED 2026-09-25 by Harold, as amended.** Verbatim: *"Sprint plan approved as amended (with any
comments I provided), proceed with execution. All Sprint tasks and sub-tasks are approved. Do not
stop between tasks as they are all approved, please continue to complete all tasks and without
addition approvals until Manual Validation, providing your recommendation for Manual Validation
steps. Do not stop to ask questions unless meeting the criteria in SPRINT_STOPPING_CRITERIA.md. If
questions must be asked, ask as late as possible."*

**Amendments (Harold's answers, 2026-09-25)**:
- **Models**: every Fable/Opus task runs on **Opus 5.5** this sprint.
- **Q1 -- MINOR `0.17.0+8`.**
- **Q2 -- answered as the EXPORT destination**: *"Android - Documents / Windows -
  %USERPROFILE%\Downloads"*. Applied to Task 4: the default export folder is the public
  `Documents` directory on Android and `%USERPROFILE%\Downloads` on Windows. This REPLACES the
  share-sheet design -- files are written directly, so no `share_plus` dependency. (Android
  Documents writes are proven on this device: the F205 card records a CSV written to
  `/storage/emulated/0/Documents` and pulled over MTP on 2026-09-10.)
  **The F202 question Q2 actually asked -- per-provider defaults user-editable in Settings or
  code-only -- is UNANSWERED.** Per Harold's instruction to ask as late as possible, Task 3 builds
  everything that does not depend on it (provider map, resolvers, missing-vs-failed) and the
  question is asked at Manual Validation.
- **Q3 -- YES, add real cross-isolate exclusion**, and *"update/append current ADR"* rather than a new
  one: appended to ADR-0039 (per-account background scanning), which no other ADR supersedes for
  this. Task 1 R-5 is IN scope.
- **Q4 -- values**: Yahoo Deleted Rule `Trash`, Safe Sender `Inbox`; iCloud Safe Sender `INBOX`,
  Deleted Rule `Deleted Messages`. iCloud Junk remains unknown -> overall default.
- **Q5 -- NO**: the new ordering applies to Scan Results only; Review No Rule Items is unchanged.
- **Q6 -- BUILD the redacted export mode now** (Task 4 Part C in scope).
- **Q7 -- all 9 tasks** ("All Sprint tasks and sub-tasks are approved").
