# Sprint 72 Plan -- AWAITING APPROVAL (Phase 3.7)

**Status**: PROPOSED. Not approved. No task execution until Harold approves at Phase 3.7.
**Branch**: `feature/20260922_Sprint_72` (to be created from `develop` AFTER Task 0's PR merges)
**Version**: bumps at Phase 3.7.0b once scope is approved -- see Task 0b.

**Scope requested by Harold, 2026-09-22**: F233, F232, F228, F230, F231, F217, F219 AC-1, plus
clearing the unmerged documentation commits first.

---

## ADR-0042 applies to EVERY task in this sprint

Harold, 2026-09-22: *"everything needs to take into account both the Windows App and the Android
app and ADR stating that everything should be functionally and UI the same unless it cannot be -
and where it cannot be it should be implemented as a platform exception for what is needed -- this
applies to all backend code, frontend code, data, architecture, development, security, testing,
deployment."*

**This is a standing requirement on every card below, not a per-card afterthought.** Two rules
govern how it is satisfied, and the second is the one that was missed last sprint:

1. **A difference must be a DECLARED exception** -- narrow, justified, and covering only what
   genuinely cannot be shared.
2. **A PARITY claim needs the SAME verification as an exception** (CLAUDE.md IMP-5, from Sprint 70).
   "No exception needed" is not the safe default. For any shared code touching OS-level behavior,
   the card must NAME the OS behavior being assumed identical, or declare the exception.
   **Sprint 70 cost a rework cycle to exactly this**: F220's lifecycle handler ran on every
   platform under a comment asserting nothing was platform-specific, but `AppLifecycleState.paused`
   means "your sockets are gone" on Android and merely "your window is not visible" on Windows --
   so the handler killed healthy Windows scans. The comment declared parity while the code
   delivered divergence.

**Every card therefore carries an explicit `Platform parity` line** stating: same on both, or a
named exception with its justification. Where a card's behavior differs by platform, BOTH branches
are tested -- a test that exercises only the Android branch does not discharge this.

**Known platform asymmetries in this sprint's scope**, established before planning:

- **Scan mode by environment** (`project_scan_mode_by_environment`): Windows DEV and Prod are
  READ-ONLY with background scanning OFF; the Android closed test is the ONLY build that acts on
  mail. This is a CONFIGURATION difference, not a code exception -- the code must behave
  identically given the same configuration, which is what Task 2 tests.
- **Battery optimization (F217)** is Android-only at the OS level. Windows has no equivalent
  concept, so this is a genuine declared exception -- see Task 6.
- **Diagnostic log retrieval** differs: Windows exposes a filesystem path directly, Android needs a
  user-visible directory. The LOG ITSELF is shared code; only the default directory differs.

---

## Task 0 -- Merge the outstanding documentation commits (Priority: FIRST, separate)

**Value**: This clears 22 unmerged commits so Sprint 72 starts from a clean `develop`, and it lands
a real Stop-hook defect repair that is currently sitting only on a feature branch.

**Harold's condition, verified**: *"fix the 20 commits unmerged (only if they are not code
changes)"*. **Condition MET -- audited 2026-09-22**: `git diff --stat origin/develop...HEAD` shows
**zero `.dart` files, no `pubspec.yaml`, no gradle**. 25 files: 20 `.md`, 3 `0*.txt` (Harold's
working docs), `.claude/sprint_status.json`, and `.claude/hooks/` tooling (the Gate 1c repair plus
its test fixtures). The hooks are development tooling, not application code.

**Requirements**:
- R-1: PR `feature/20260919_Sprint_71` -> `develop`. Claude creates it; **Claude never merges it**.
- R-2: The hook suite passes before the PR is opened. **Verified 2026-09-22: 75 passed, 0 failed.**
- R-3: The PR description states plainly that this is documentation plus hook tooling with no
  application-code change, so the reviewer knows the risk surface.

**Affected components / files**: the 25 files listed above. No application code.

**Dependencies / blockers**: None. **This should land before Task 1 begins** so the sprint branch
forks from a current `develop`.

**Acceptance criteria**:
- AC-1: PR open against `develop` (never `main`), hook suite green, description names the
  no-code-change scope.
- AC-2: After Harold merges, `feature/20260922_Sprint_72` is created FROM the Sprint 71 branch per
  the carry-forward rule, and the Sprint 71 branch is NOT deleted.

**Tests to write**: None -- no application code changes. The hook suite (75/75) is the gate and it
already exists.

**Definition of Done**: default task-level DoD EXCEPT items 2 and 3 (no Flutter code changed, so no
new Flutter tests and no analyzer delta) PLUS: hook suite green, PR open, Harold notified.

**Model**: Haiku -- *why not cheaper*: n/a, this is the cheapest tier. Mechanical PR creation
against a verified-clean diff.

**Step-types**: DOCS, HOOK
**Est-Effort**: 10-20m

**Platform parity**: N/A -- no application behavior changes on either platform.

---

## Task 0b -- Version bump (Phase 3.7.0b, at approval)

**Value**: This keeps a tester able to tell a dev build from what shipped, which is the entire point
of F190, and it unblocks a currently-RED gate.

**Requirements**:
- R-1: `dev_version_ahead_test` is RED right now: dev `0.15.2+5` is NOT ahead of `0.15.2`, which is
  live on BOTH stores. Bump `version:` AND `msix_config.msix_version` AND the `+N` build number.
- R-2: **MINOR if the approved scope contains a `feat`, else PATCH.** This sprint is all fixes plus
  one new diagnostic capability (F233) -- **Harold decides which**, since F233's log could read as a
  feature. Recommendation: **0.15.3+6** (PATCH), because F233 is developer tooling rather than a
  user-facing feature.
- R-3: Play permanently consumes a versionCode once uploaded, so `+6` is required regardless.

**Affected components / files**:
- `mobile-app/pubspec.yaml` -- `version:` and `msix_config.msix_version`
- `docs/STORE_VERSION_STATUS.md` -- Dev worktree row

**Dependencies / blockers**: Harold's PATCH-vs-MINOR decision (R-2).

**Acceptance criteria**:
- AC-1: `flutter test test/policy/dev_version_ahead_test.dart test/policy/version_consistency_test.dart`
  is GREEN (both currently fail/would fail on the version row).

**Tests to write**: None new -- the two policy gates already exist and are the verification.

**Definition of Done**: default DoD PLUS: both version gates green.

**Model**: Haiku -- *why not cheaper*: n/a, cheapest tier.
**Step-types**: DATA, DOCS
**Est-Effort**: 10-15m

**Platform parity**: Same version literal on both platforms per ADR-0043 (one version across
platforms). `msix_version` is Windows-only by format (`X.Y.Z.0`) and `+N` is Play-only in effect --
both derive from the SAME `version:` field, so this is one source of truth, not an exception.

**Decision-class interrupts**: Class-3 (scope) -- R-2's PATCH vs MINOR is Harold's call at approval.

---

## Task 1 -- F233: A pullable diagnostic log, and fix the header-only CSV export (Priority 4)

**Value**: This enables every other diagnosis in this sprint. F232 and F228 both stall because the
decisive facts go to a console sink that does not exist on an installed build.

**Audit-first (MANDATORY check)**: **Is a diagnostic log already true in the codebase? PARTLY.**
- `LiveScanLogger` (`core/services/live_scan_logger.dart`) ALREADY writes a real file, is
  cross-platform, MSIX-safe, resolves via `path_provider`, redacts emails via `Redact.email`, and
  has an opt-in CSV/XLSX export gated by `live_scan_debug_csv`. **Do not rebuild it.**
- **Measured on the S24+ over MTP, 2026-09-21**: `Android/data/com.myemailspamfilter/` contains
  only `files/` with two old CSVs. **There is no `logs/` directory**, so `LiveScanLogger` has never
  written on that device.
- **The GAP is therefore**: (a) the failure-path call sites use a bare `Logger()` with no file sink,
  (b) there is no retention/deletion UI, (c) the CSV export ignores historical results.

**Requirements**:
- R-1: Route the failure paths through a file-backed logger. The five call sites that would have
  answered both open cards: `results_display_screen.dart:3329` (`[F38] Re-processing failed`),
  `:3266` (`[F38] Delete batch failed`), `generic_imap_adapter.dart:1140-1147` (the `allFailed`
  reason), `:1205` (`Invalid message UID`), `:993` (`no valid UIDs parsed ... skipping`).
- R-2: **Record the two failure SHAPES distinctly** -- an `allFailed` guard trip ("never connected")
  versus a thrown exception ("connected, server refused"). Today both render as "0 of N (N failed)"
  and are indistinguishable, which is precisely why F232 has two competing mechanisms.
- R-3: Settings toggle, **default OFF**, beside the existing CSV-export setting. Never log message
  bodies or credentials -- use the existing `Redact.email`.
- R-4: Retention flag + **a "Delete diagnostic logs" action in Settings showing total size**.
  Harold, 2026-09-21: *"if the user can easily get to them to delete the files"* -- the
  parenthetical is a HARD REQUIREMENT, not an aside.
- R-5: Default the log to the **user-chosen directory** (the existing CSV Export Directory pattern),
  NOT app-private storage. Rationale: app-private storage is readable over MTP only because this
  particular Samsung exposes it; a user-chosen folder is OEM-independent, visible in the phone's
  Files app, and deletable without the app.
- R-6: **Fix the CSV export.** `_exportResults` (`results_display_screen.dart:355-363`) calls
  `scanProvider.exportResultsToCSV()`, which iterates the PROVIDER's `_results` and **never
  consults `_historicalResults`** -- while every display path does (`:595`, `:598`, `:2566`). So
  exporting from a historical view writes a header with zero rows and reports success. Confirmed:
  3 of 5 CSVs pulled from the device are exactly 108 bytes.
- R-7: Log rotation or a size cap -- a permanently-on log on a phone needs one; `LiveScanLogger`
  appends unbounded today.
- R-8: Stamp app version + build number into the log header AND the CSV (see F229, Task 7).

**Affected components / files**:
- `mobile-app/lib/core/services/live_scan_logger.dart` -- add the diagnostic sink + rotation
- `mobile-app/lib/ui/screens/results_display_screen.dart:355-363` -- historical branch for export
- `mobile-app/lib/ui/screens/results_display_screen.dart:3266,3329` -- route through the file sink
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:993,1140-1147,1205`
- `mobile-app/lib/ui/screens/settings_screen.dart` -- toggle, retention flag, delete action
- `mobile-app/lib/core/storage/settings_store.dart` -- the new settings keys

**Dependencies / blockers**: **None -- and Tasks 2 and 3 DEPEND ON THIS.** Do this first.

**Non-functional requirements**:
- Security: never log bodies, credentials, or unredacted addresses. `Redact.email` already exists.
- Storage: rotation/cap required (R-7) before retention is offered (R-4).
- Account-scoping: log lines name the account they concern, redacted.

**Acceptance criteria**:
- AC-1: With the toggle ON, forcing a re-process failure writes a line naming the exception to a
  file retrievable without a debugger, on BOTH Windows and Android.
- AC-2: Given a batch that fails because the client is null, When the log is read, Then it is
  distinguishable from a batch that failed because the server refused (R-2).
- AC-3: Given a HISTORICAL scan view, When Export to CSV is tapped, Then the CSV contains one row
  per displayed result -- not a bare header.
- AC-4: Given the toggle OFF (default), When scans run, Then no diagnostic file is created.
- AC-5: Settings shows total diagnostic-log size and a delete action that empties it.

**Tests to write**:
- T-1 (verifies AC-1/AC-2) -- TEST-UNIT in `test/unit/services/diagnostic_logger_test.dart`: proves
  the two failure shapes produce distinguishable records.
- T-2 (verifies AC-3) -- TEST-WIDGET in `test/ui/screens/results_export_historical_test.dart`:
  proves export from a historical view yields rows. **This test fails against today's code** --
  that is the point.
- T-3 (verifies AC-4) -- TEST-UNIT: default-off produces no file.
- T-4 (verifies AC-5) -- TEST-WIDGET: delete action clears the files and the size display.
- T-5 (parity) -- TEST-UNIT: the directory resolver returns a valid path under BOTH a Windows and an
  Android path convention.
- **What these tests will NOT catch** (CLAUDE.md IMP-1): they do not prove the log is RETRIEVABLE
  over MTP on a real device -- that is a manual validation step, because no test can enumerate a
  phone over USB.

**Definition of Done**: default DoD PLUS: manually verify on the S24+ that the file is pullable over
MTP, and confirm the same on Windows by path.

**Model**: Sonnet -- *why not the cheaper tier*: spans six files with a new persisted setting, a
security constraint (redaction), and a cross-platform path resolver; Haiku's heuristics cover
single-file mechanical changes.

**Step-types**: SVC-EDIT, UI-MOVE, DATA, TEST-UNIT, TEST-WIDGET
**Est-Effort**: 180-300m

**Platform parity**: **SAME on both, with ONE declared exception.** The logger, the settings, the
redaction, the rotation and the CSV fix are shared code and must behave identically. The DECLARED
EXCEPTION is the default log DIRECTORY: Windows resolves a filesystem path directly, Android needs a
user-visible directory to satisfy R-4's deletability. **Parity claim verified per IMP-5**: the OS
behavior being assumed identical is file append + delete semantics, which `dart:io` provides on
both; what differs is only WHERE, and that difference is declared here and tested by T-5.

**Risk & rollback**: A permanently-on log could grow unbounded on a phone -- mitigated by R-7, which
must land in the same change, not after. Rollback: the toggle defaults OFF, so reverting the
setting disables the feature without a code rollback.

---

## Task 2 -- F232: Rules from a historical view must act on the mailbox (Priority 2)

**Value**: This prevents the app telling the user their mail was filed when nothing happened on the
server -- the most serious defect found in Sprint 71 testing.

**Audit-first**: **Is the correct behavior already true? NO, and two separate mechanisms are
involved.** Both confirmed in source; neither is speculative.

**Requirements**:
- R-1: **MECHANISM A -- the silent skip.** `_reProcessAffectedEmails()`
  (`results_display_screen.dart:3114-3118`) returns early when `scanMode == ScanMode.readOnly`, and
  `EmailScanProvider._scanMode` DEFAULTS to `readOnly` (`:165`), set only by `initializeScanMode()`
  whose call sites are all scan-STARTING paths (`background_scan_core.dart:125`,
  `account_setup_screen.dart:318`/`:1090`, `scan_progress_screen.dart:722`). **Nothing sets it when
  a historical scan is opened.** The Sprint 38 Round 9 comment at `:304` states this premise
  outright.
- R-2: **DECIDED BY HAROLD 2026-09-21 -- option 2, ACT NOW**: resolve the effective scan mode from
  SAVED SETTINGS rather than session state, and perform the action. Authorized Class-2 decision.
- R-3: **The mode is PER-ACCOUNT.** `SettingsStore.getAccountManualScanMode(accountId)` returns
  `ScanMode?` (null = app-wide default, `settings_store.dart:524`). Scan Results can show **All
  Accounts**, so a single resolved mode is WRONG -- resolve PER EMAIL, and a batch may legitimately
  mix act and read-only accounts.
- R-4: Therefore the single early return becomes a PARTITION: act where permitted, skip the rest,
  and report BOTH ("3 filed, 2 skipped -- those accounts are read-only"). A silent partial action is
  the same defect class this card exists to close.
- R-5: Use the **MANUAL** mode, not the background mode, for a user-initiated action.
- R-6: **Honour a configured read-only account genuinely** -- option 2 replaces "skip because no
  scan ran this session" with "act per the account's configured intent". It does NOT override a
  deliberate read-only choice. Windows DEV/Prod stay skip-and-SAY-SO.
- R-7: **MECHANISM B is UNDIAGNOSED and must be diagnosed before it is fixed.**
  `Screenshot_20260920_222506.png` shows `Re-processed 0 of 9 (9 failed)` at 22:25 **with full
  signal** -- a batch that RAN and failed, which the readOnly path cannot produce.
  **Eliminated already**: shared-adapter interference (`PlatformRegistry.getPlatform` returns a
  FRESH instance via `factory?.call()`); malformed UIDs (**falsified** -- every `Email ID` in the
  device's own CSV exports is a clean integer: 231203, 231201, 231200, 231199, 201936); and
  cross-folder batching (`moveToFolderBatch` DOES group by folder).
  **Remaining candidates**: `ScanCoordinator.acquire()` timing out behind a background scan (the
  22:20 background scans are 5 minutes before the 22:25 failure -- suggestive, NOT evidence);
  stale-but-valid UIDs already moved by that background scan; credentials/connect failure.
  **R-7 is satisfied by DIAGNOSIS, and the fix follows in the same task only if it is small.**
- R-8: **Harold's controlled comparison is the acceptance oracle**: *"the background scan that
  starts with the new rules ... correctly deletes all the email."* Same account, credentials,
  network and rules, minutes apart -- so the fixed re-process path must achieve what the background
  scan already achieves.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart:3114-3118` -- the early return -> partition
- `mobile-app/lib/core/providers/email_scan_provider.dart:165,696` -- mode resolution
- `mobile-app/lib/core/storage/settings_store.dart:524` -- per-account manual mode (read only)

**Dependencies / blockers**: **Task 1 (F233) must land first** -- R-7 cannot be diagnosed without
the log.

**Non-functional requirements**:
- Account-scoping: per-email resolution (R-3), NOT a single session value. This is the Sprint 19
  account-scoping rule applied to scan mode.
- Security: this creates a live-deletion path from a screen that never deleted before.

**Acceptance criteria**:
- AC-1: Given an account configured for live actions and a HISTORICAL scan opened with no scan
  started this session, When a block rule is created, Then the matching emails are actioned on the
  server (verified by re-fetching, not by the UI count).
- AC-2: Given an account configured READ-ONLY, When the same is done, Then nothing is actioned AND
  the user is told the account is read-only. **Not silent.**
- AC-3: Given a batch spanning a live account and a read-only account, When it runs, Then it reports
  both the filed count and the skipped count.
- AC-4 (R-7): The mechanism behind `0 of 9 (9 failed)` on a healthy connection is NAMED with
  evidence from the Task 1 log, and either fixed or filed with its cause.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-WIDGET in `test/ui/screens/f232_historical_reprocess_test.dart`:
  proves the action is ATTEMPTED when no scan ran this session. Fails against today's code.
- T-2 (verifies AC-2) -- TEST-UNIT: a read-only account is skipped AND reported.
- T-3 (verifies AC-3) -- TEST-UNIT: mixed-account batch reports both counts.
- T-4 (parity) -- TEST-UNIT: the same configuration produces the same decision on both platforms.
- **What these will NOT catch** (IMP-1): they prove the action is ATTEMPTED and reported, not that
  the IMAP server accepted it. A test asserting only that rows hid would pass today -- **that is
  exactly the gap Sprint 38 left**, and it is why AC-1 requires re-fetch verification in manual
  validation.

**Definition of Done**: default DoD PLUS: manual validation on the S24+ reproducing Harold's A/B --
create a rule from a historical view, confirm the mail is gone WITHOUT running a later scan.

**Model**: Fable/Opus -- *why not the cheaper tier*: R-7 is an open diagnosis with three live
hypotheses and a falsified one, and R-2 is an authorized Class-2 change to the meaning of
`scanMode` at this call site. Sonnet's heuristics cover multi-file implementation against a settled
design; this card has to determine the design.

**Step-types**: SVC-EDIT, DATA, TEST-UNIT, TEST-WIDGET
**Est-Effort**: 240-360m

**Platform parity**: **SAME on both -- and the parity claim is VERIFIED, not assumed (IMP-5).** The
OS behavior assumed identical is: none. This is pure Dart logic over a per-account setting, with no
OS-level dependency. The apparent platform difference (Windows does not delete) is a CONFIGURATION
difference -- Windows DEV/Prod are configured read-only per `project_scan_mode_by_environment` --
and the fixed code must reach the SAME decision given the SAME configuration on either platform,
which T-4 asserts. **No exception is declared, and that claim is discharged by T-4 rather than by
assertion.**

**Risk & rollback**: This creates a live-deletion path from a screen that previously never deleted.
Mitigation: R-6 keeps configured read-only genuinely read-only, so Windows DEV/Prod cannot start
deleting. Rollback: revert to the early return, which restores today's (wrong but safe) behavior.

**Decision-class interrupts**: Class-2 already surfaced and DECIDED (option 2, 2026-09-21). If R-7's
diagnosis reveals a Class-1 architectural cause, STOP and surface before fixing.

---

## Task 3 -- F228: The success toast must not claim success after a failed action (Priority 6)

**Value**: This prevents the user being told an action succeeded when the mailbox was never touched,
which invites them to move on from mail that was never filed.

**Audit-first**: **Is the correct behavior already true? PARTLY -- and the working half is the
model for the fix.** `:3363` (the batch summary) ALREADY does this correctly: it picks its color
from `failCount` (`failCount == 0 ? Colors.green : Colors.orange`) and reports
`Re-processed $successCount of $total ($failCount failed)`. **Do not touch it.**

**Requirements**:
- R-1: `results_display_screen.dart:3472-3480` shows the per-action toast with
  **`backgroundColor: Colors.green` HARDCODED**. It reports the RULE CREATION, which genuinely
  succeeded (a local DB + YAML write) -- but it fires AFTER `await _reProcessAffectedEmails()` at
  `:3461`, so the IMAP failure has already happened and the count is known. **The code has the
  information and does not use it.**
- R-2: Have `_reProcessAffectedEmails()` return its success/fail counts (it returns void today and
  reports only via its own snackbar), then color and word this toast from them.
- R-3: **REPRODUCTION, confirmed on demand** (Harold, S24+, airplane mode ON): each item gave a
  GREEN toast while the batch summary for the same actions was ORANGE `Re-processed 0 of 6
  (6 failed)`. Screenshots `Screenshot_20260921_221354.png` and `_221508.png`.
- R-4: **Do NOT re-couple the footer counters.** `addressed`/`remaining` come from rule EVALUATION
  and `failed` from IMAP outcome; F212 R-4 separated them deliberately so a failed action could
  never read as "addressed" (see the comment at `:3031`). Fix the TOAST, not the evaluation.
- R-5: **What is CORRECT and must not be "fixed"**: the rule IS created offline and that is right
  (rules are local state; the user's intent is recorded without a connection). `stats.remaining`
  legitimately drops. The bug is the CLAIM about the mailbox.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart:3472-3480` -- the toast
- `:3195-3352` -- `_reProcessAffectedEmails` signature change to return counts

**Dependencies / blockers**: **Task 2 should land first** -- its partition (R-4 there) changes what
counts exist to report.

**Acceptance criteria**:
- AC-1: Given the device is offline, When a block rule is created from Scan Results, Then the toast
  is NOT green and names the failure.
- AC-2: Given the action fully succeeds, Then the toast is green and reports the removal.
- AC-3: Given a PARTIAL failure, Then the toast reports both counts.
- AC-4: The batch summary at `:3363` is unchanged.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-WIDGET in `test/ui/screens/f228_toast_reflects_outcome_test.dart`:
  proves a failed IMAP action does not render a green toast. Fails against today's code.
- T-2 (verifies AC-3) -- TEST-UNIT: partial counts render both numbers.
- T-3 (verifies AC-4) -- source assertion that the `failCount == 0 ? green : orange` expression at
  `:3363` still exists.
- **What these will NOT catch** (IMP-1): they assert the COLOR and TEXT, not that the underlying
  IMAP action truly failed -- that is Task 2's territory.

**Definition of Done**: default DoD PLUS: reproduce Harold's airplane-mode recipe and confirm the
toast now tells the truth.

**Model**: Sonnet -- *why not the cheaper tier*: a signature change with callers, on a screen where
Sprint 70 proved that one fix creates the next defect. Not mechanical.

**Step-types**: UI-MOVE, SVC-EDIT, TEST-WIDGET, TEST-UNIT
**Est-Effort**: 90-150m

**Platform parity**: **SAME on both.** Verified per IMP-5: the OS behavior assumed identical is
none -- SnackBar rendering and color are Flutter-level, not OS-level. The airplane-mode
reproduction is available on Android; the equivalent on Windows is disabling the network adapter,
and AC-1 must be demonstrated on BOTH.

---

## Task 4 -- F230 + F231 TOGETHER: action-sheet layout and result durability (Priority 10)

**Value**: This lets the user actually read what happened and see the sender they are acting on.

**Planned as ONE task deliberately**: F230 moves Skip and F231 addresses a SnackBar whose fixed
`bottom: 80` margin is covered by the detail card. **Both change the same geometry**, and doing
them separately means solving that layout twice.

**Audit-first**: **Is any of this already true? NO for the layout; PARTLY for durability** -- the
data exists in Scan History (Harold's workaround), it is simply not surfaced on this screen.

**Requirements**:
- R-1 (F230a): the subtitle line is `fontSize: 12, grey[600]` (`:1924`) and the date/domain row is
  `fontSize: 11, grey.shade600` (`:1941,:1953`). Harold: too small on Android.
- R-2 (F230b): **Skip truncates the sender.** The sender is an `Expanded` + `ellipsis` in the SAME
  `Row` as Skip (`:1876-1913`), so Skip consumes sender width. At 411px it renders
  `kimmeyharold@help.ramirezo...`; identical code on Windows at ~993px shows the full address with
  room to spare. **A WIDTH problem, not a font problem.**
- R-3 (F230c): **Harold's fix**: move Skip from the TOP right to the BOTTOM right, aligned with the
  date/domain row where the screenshot shows clear space. **Constraint**: that row's domain `Text`
  has NO `Expanded`, so dropping Skip in unbounded MOVES the overflow. Bound it and re-test at
  411px -- same shape as the F172 AppBar overflow (~81px at 411px).
- R-4 (F230d): **PLATFORM DECISION, Harold 2026-09-22**: raise the sizes on BOTH platforms even
  though Windows shows no problem -- *"It would be OK if it was bigger on Windows in order to match
  Android and not cause an unnecessary exception."* **This keeps it ONE shared change with no
  ADR-0042 exception**, which is the cheaper long-term outcome.
- R-5 (F231a): **MEASURED ~1 second of readable time, not 3.** Harold timed them. All five
  SnackBars use `Duration(seconds: 3)` (`:3369,:3433,:3476,:3510,:3554`), which INCLUDES enter/exit
  animation, and each new action REPLACES the current SnackBar rather than queueing -- so in a
  burst every toast but the last is cut short.
- R-6 (F231b): **The detail card COVERS the toast entirely.** Harold: *"if you start at the top of
  the list, then the item detail card overlaps the footer status for success and failure, so you
  don't see any of them."* All five use `margin: const EdgeInsets.only(bottom: 80, ...)` -- a
  `const` that cannot account for an open detail card. Working top-down, the message is not
  shortened but **ABSENT**.
- R-7 (F231c): **PERSIST the outcomes** -- this is the fix that survives a missed toast, and it
  ranks above lengthening the timeout. A per-action record in the scan-history detail, or a session
  activity list on the screen.
- R-8: **Do NOT just raise 3s to 8s.** It leaves the permanent-loss problem untouched, and a
  long-lived SnackBar covers the list and the `Back to Scan History` control -- worse at 411px.
- R-9: **Keep Skip's behavior identical** -- it reuses `_quickActionThenAdvance` with a no-op action
  and a covers-nothing predicate so "next unaddressed item" matches every other button (F136).
  **Move the widget; do NOT reimplement it.**
- R-10: **Open question for Harold at approval**: hardcoded sizes vs theme text styles
  (`bodySmall`/`bodyMedium`). The theme route additionally honours the OS font-size accessibility
  setting. **Recommendation: theme styles**, which serves ADR-0037 accessibility.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart:1876-1960` -- header row, subtitle,
  date/domain row, Skip placement
- `:3369,:3433,:3476,:3510,:3554` -- SnackBar duration and margin
- `:2605-2660` -- `_buildSkipButton` (moved, not rewritten)

**Dependencies / blockers**: **Task 3 should land first** -- it changes the toast's color/text, and
this task changes its position and lifetime. Same widgets.

**Non-functional requirements**:
- Accessibility: per ADR-0037 and QUALITY_STANDARDS. R-10's theme route serves this directly.
- Platform: must be verified at 411px (phone) AND at the 1024x640 epx Windows minimum.

**Acceptance criteria**:
- AC-1: At 411px the full sender address renders without ellipsis in the action sheet.
- AC-2: Skip is at the bottom right of the same section, and the date/domain row does not overflow
  with a long domain.
- AC-3: Subtitle and date/domain text are larger than today on BOTH platforms.
- AC-4: Given the detail card is open, When an action completes, Then the result message is VISIBLE
  (not covered).
- AC-5: Given 5 actions in rapid succession, When they complete, Then all five outcomes are
  recoverable afterwards (R-7), not only the last.
- AC-6: No AppBar or row overflow at 411px or at 1024x640 epx.

**Tests to write**:
- T-1 (verifies AC-1/AC-2/AC-6) -- TEST-WIDGET at 411px: no overflow, no sender ellipsis.
- T-2 (verifies AC-6) -- TEST-WIDGET at 1024x640 epx: the Windows minimum.
- T-3 (verifies AC-4) -- TEST-WIDGET: result message not occluded with the detail card open.
- T-4 (verifies AC-5) -- TEST-UNIT: five rapid outcomes are all retrievable.
- T-5 (verifies AC-3) -- source assertion that the sizes increased (guards against silent revert).
- **What these will NOT catch** (IMP-1): a widget test cannot prove the text is COMFORTABLE to read
  on real hardware -- only that it is larger and does not overflow. Harold's judgement at manual
  validation is the real acceptance, on both a phone and the Windows app.

**Definition of Done**: default DoD PLUS: Harold confirms readability on the S24+ AND on Windows;
re-run the F169/F172 width tests; run `text_contrast_test`.

**Model**: Sonnet -- *why not the cheaper tier*: layout geometry with two width regimes, an
occlusion bug, and a persistence addition; Sprint 69 F209 proved that a plausible layout fix here
can break neighbours (the F178 popup and keyboard screens).

**Step-types**: UI-MOVE, SVC-EDIT, TEST-WIDGET, TEST-UNIT
**Est-Effort**: 180-300m

**Platform parity**: **SAME on both, NO exception -- by Harold's explicit choice (R-4).** Verified
per IMP-5: the OS behavior assumed identical is text rendering and layout constraints, which
Flutter provides identically; the only real difference is WINDOW WIDTH, which is a continuous
variable both platforms span (a narrow Windows window hits the same 411px-class regime). That is
why both T-1 and T-2 exist -- the parity claim is discharged by testing BOTH width regimes, not by
assuming the platforms differ.

**Risk & rollback**: `text_contrast_test` enforces WCAG ratios whose thresholds DEPEND ON FONT SIZE
-- larger text is held to a LOWER ratio, so raising a size can push text out of the large-text
exemption and turn a CONTRAST gate red **with no color change**. `grey.shade600` is already near
the boundary. **Fix by darkening the grey, not by reverting the size.**

**Decision-class interrupts**: R-10 (theme styles vs hardcoded) is a Class-2 development decision --
surface at approval.

---

## Task 5 -- F219 AC-1 + F227 re-verification on the Play build (Priority 6)

**Value**: This closes the last Sprint 70 acceptance criterion, which no local build could satisfy.

**Audit-first**: **Is it already verified? NO, and it could not have been.** The fix is implemented
and verified as far as a local build can go (on an Android 14 emulator the OAuth redirect reaches
the app instead of a system chooser). What remains is a listed test user completing sign-in on a
**Play-installed** build, because the Android OAuth client is bound to the Play App Signing SHA-1 --
any locally-signed build presents the wrong fingerprint. **Blocker CLEARED**: 0.15.2 is published to
closed testing and device-verified 2026-09-21 (S24+ Settings reads "Version 0.15.2").

**Requirements**:
- R-1: A listed test user completes Google Sign-In end to end on the Play build.
- R-2: F227 re-verification -- the full OAuth round trip against the real client. The emulator proved
  the redirect ROUTING is fixed (2 activities -> 1); the round trip is untested.
- R-3: **Harold's hands required** for the account picker and any password/2FA prompt.
- R-4: If it FAILS, capture the failure with the Task 1 diagnostic log enabled.

**Affected components / files**: None expected -- this is verification. If it fails, the card
becomes an investigation and the files are named then.

**Dependencies / blockers**: **Harold's availability.** Task 1 should land first so R-4 is possible.

**Acceptance criteria**:
- AC-1: Given a listed test user on the Play-installed 0.15.2, When they sign in with Google, Then
  the account is added and a scan can run.
- AC-2: The redirect lands in the app's own task -- no system chooser.

**Tests to write**: None automatable -- this is manual validation against a real OAuth client by
definition. The existing emulator probes remain the regression guard.

**Definition of Done**: default DoD EXCEPT items 2/3/5/6 (no code change expected) PLUS: the result
recorded in `SPRINT_72_PLAN.md` completion notes with a screenshot.

**Model**: Haiku -- *why not cheaper*: n/a. Claude's role is preparing steps and recording the
result; Harold performs it.

**Step-types**: DOCS (plus investigation only if it fails)
**Est-Effort**: 20-40m of Claude time; Harold's time separate

**Platform parity**: **DECLARED EXCEPTION -- Android only.** Google Sign-In via Play App Signing has
no Windows equivalent; Windows uses a Desktop OAuth client with a loopback redirect, which is a
different flow already working and already verified. Verified per IMP-5: the OS behavior that
differs is named -- Android binds the OAuth client to the APK signing certificate, Windows does not.

---

## Task 6 -- F217: Android background-scan battery exemption (Priority 6)

**Value**: This makes background scanning actually run on a real phone, which is the feature's whole
point for closed-test users.

**Audit-first**: **Is any of this already present? NO.** `grep` for
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `isIgnoringBatteryOptimizations` and
`ignoreBatteryOptimizations` across `android/` and `lib/` returns **nothing**. Genuine build work.
**Note the Sprint 70 correction**: a claim of "no battery-related permission at all" was made from
the SOURCE manifest; the MERGED manifest DOES carry `FOREGROUND_SERVICE` and `WAKE_LOCK` via
workmanager. **Check the MERGED manifest, not just the source.**

**Requirements**:
- R-1: **DECIDED BY HAROLD (Class-1, 2026-09-19): option 1 -- request a battery-optimization
  exemption.** His own device check FALSIFIED the Samsung sleeping-apps hypothesis (the app is in
  none of those lists and "Put unused apps to sleep" is off), which is what made this the correct
  remedy rather than the cheaper one.
- R-2: The prompt must be **CONTEXTUAL** -- fired at the moment the user enables background
  scanning, mirroring the F161 POST_NOTIFICATIONS pattern. **NOT at startup.**
- R-3: The app must behave **honestly when the user declines**: background scanning must not claim
  it will run reliably. Say what will happen.
- R-4: The permission is **scrutinised at Play review and needs a listing justification** -- draft
  it as part of this task.
- R-5: Verify against the MERGED manifest (see audit note).

**Affected components / files**:
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- the permission
- `mobile-app/lib/ui/screens/settings_screen.dart` -- contextual prompt at the background toggle
- `mobile-app/lib/core/services/` -- exemption-state check
- `docs/store-assets/android/LISTING_COPY.md` -- the justification (R-4)

**Dependencies / blockers**: Play review risk is a Harold-facing consequence, not a code blocker.

**Non-functional requirements**:
- Security/privacy: a scrutinised permission -- the justification must be accurate, not persuasive.
- Platform: Android-only by nature.

**Acceptance criteria**:
- AC-1: Given the user enables background scanning, When the toggle is turned on, Then the
  exemption is requested at that moment (not at startup).
- AC-2: Given the user DECLINES, Then the UI states plainly that background scans may be delayed or
  skipped. **No silent degradation.**
- AC-3: The merged manifest contains the permission exactly once.
- AC-4: Windows is unaffected -- no prompt, no behavior change.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-WIDGET: the prompt fires on the toggle, not at startup.
- T-2 (verifies AC-2) -- TEST-WIDGET: declining shows the honest message.
- T-3 (verifies AC-3) -- TEST-UNIT policy gate on the MERGED manifest (R-5).
- T-4 (verifies AC-4) -- TEST-WIDGET: the Windows branch shows no prompt.
- **What these will NOT catch** (IMP-1): they cannot prove background scans actually run more
  reliably on real hardware over hours -- that needs Harold's device over a real interval, and it is
  the only evidence that matters for the card's VALUE.

**Definition of Done**: default DoD PLUS: Harold confirms on the S24+ that background scans fire
while the app is backgrounded and the phone is locked, over at least one real interval.

**Model**: Sonnet -- *why not the cheaper tier*: native manifest work, a permission with store-review
consequences, and a platform-exception design; not a single-file mechanical change.

**Step-types**: NATIVE-WIN (Android equivalent), UI-MOVE, SVC-EDIT, TEST-WIDGET, TEST-UNIT, DOCS
**Est-Effort**: 240-480m

**Platform parity**: **DECLARED EXCEPTION -- Android only, and it is a genuine one.** Verified per
IMP-5: the OS behavior that differs is named -- Android's Doze/App Standby can defer or drop
background work, and exempting an app requires an explicit user-granted exemption. **Windows has no
equivalent concept**; its background scanning is a scheduled task with no OS battery arbiter. The
exception covers ONLY the permission request and its prompt; the background-scan scheduling logic
itself stays shared. AC-4 and T-4 verify Windows is untouched -- which is what the ADR requires and
what a bare parity claim would have skipped.

**Risk & rollback**: Play may question the permission at review (R-4). Rollback: remove the
permission and the prompt; background scanning returns to today's unreliable-but-shipping state.

**Decision-class interrupts**: Class-1 already surfaced and DECIDED (option 1, 2026-09-19).

---

## Task 7 -- F229: Make the build identifiable at phone width and in exports (Priority 12)

**Value**: This makes a tester's screenshot and a tester's export self-identifying, which this very
sprint needed and did not have.

**Audit-first**: **Is it already true? PARTLY, and the gap is precise.** `AppBarVersionLabel`
(`standard_app_bar_actions.dart:394+`) ALREADY renders the version on every screen using
`StandardAppBarActions` -- then deliberately returns `SizedBox.shrink()` **below 600px width**,
because at 411px the action row overflowed the AppBar by ~81px (F172, caught by the F169 tests).
**That reasoning is sound and must not simply be reverted.**

**Requirements**:
- R-1: The failed assumption is quoted in that code: *"Windows at its 1024x640 epx minimum is
  comfortably above this, so the label is always present where screenshots are actually taken."*
  Screenshots are now routinely taken on a 411px phone -- a 26-screenshot session produced NO
  version anywhere, and confirming the build needed a reconnect and a purpose-taken screenshot.
- R-2: **Do NOT just lower the 600px threshold.** Options: move the label out of the crowded action
  row into the title/subtitle line; show a short form (`0.15.2` without the `Version ` prefix) below
  the breakpoint; or an overflow-menu entry.
- R-3: **Keep the `[DEV]` suffix visible** -- that marker is what would have caught the 0.5.5/0.5.6
  Store dev-leak.
- R-4: **Stamp version + build number into EXPORTS.** The CSV pulled from the device is a bare
  header with no version, so an export cannot be attributed to the build that produced it.
  **Inspect the YAML export path too** -- same argument, NOT yet checked.
- R-5: Use the existing `AppVersion.get()` runtime lookup. **Do NOT introduce a literal** --
  `stale_footer_test` flags hardcoded version literals in `lib/ui/` and `version_consistency_test`
  asserts every literal matches `pubspec.yaml`.

**Affected components / files**:
- `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart:394+` -- the breakpoint behavior
- `mobile-app/lib/core/providers/email_scan_provider.dart:914` -- CSV header (audited: does NOT
  import `AppVersion` today)
- the YAML export path -- to be identified by R-4's inspection

**Dependencies / blockers**: **Task 4 should land first** -- it changes the same action row's
geometry, and F172's overflow is exactly what constrains this.

**Acceptance criteria**:
- AC-1: At 411px the app version is visible on the scan screens (Scan History, Scan Results, live
  scan), in some form.
- AC-2: No AppBar overflow at 411px (the F172 regression guard).
- AC-3: A CSV export contains the app version and build number.
- AC-4: `[DEV]` still renders on a dev build at 411px.

**Tests to write**:
- T-1 (verifies AC-1/AC-2) -- TEST-WIDGET at 411px: version visible AND no overflow.
- T-2 (verifies AC-3) -- TEST-UNIT: exported CSV carries the version.
- T-3 (verifies AC-4) -- TEST-WIDGET: the `[DEV]` suffix survives at narrow width.
- **What these will NOT catch** (IMP-1): they do not prove the label is legible at real phone DPI,
  only that it is present and does not overflow.

**Definition of Done**: default DoD PLUS: re-run the F169/F172 width tests.

**Model**: Haiku -- *why not the cheaper tier*: n/a, cheapest tier. The design constraint is decided
by R-2 at approval, after which this is a bounded widget + a CSV header change.

**Step-types**: UI-MOVE, DATA, TEST-WIDGET, TEST-UNIT
**Est-Effort**: 120-180m

**Platform parity**: **SAME on both.** Verified per IMP-5: the OS behavior assumed identical is
none -- this is Flutter layout and a string. Windows already satisfies AC-1 because its window
exceeds the breakpoint; the change makes the NARROW regime match, which a narrow Windows window
also enters. One shared implementation, no exception.

---

## Sprint summary

| Task | Item | Model | Est (min) | Depends on |
|---|---|---|---|---|
| 0 | Merge doc commits | Haiku | 10-20 | none -- FIRST |
| 0b | Version bump | Haiku | 10-15 | approval |
| 1 | F233 diagnostic log + CSV fix | Sonnet | 180-300 | Task 0 |
| 2 | F232 historical re-process | Fable/Opus | 240-360 | Task 1 |
| 3 | F228 honest toast | Sonnet | 90-150 | Task 2 |
| 4 | F230+F231 layout + durability | Sonnet | 180-300 | Task 3 |
| 5 | F219 AC-1 + F227 verify | Haiku | 20-40 | Task 1, Harold |
| 6 | F217 battery exemption | Sonnet | 240-480 | none |
| 7 | F229 version visibility | Haiku | 120-180 | Task 4 |

**Total estimated**: 1,090-1,845 minutes (~18-31 hours of coding time).

**Model mix**: Haiku 4 tasks, Sonnet 4 tasks, Fable/Opus 1 task. The single top-tier assignment is
Task 2, which carries an open diagnosis (F232 mechanism B) and an authorized Class-2 change.

**Critical path**: 0 -> 1 -> 2 -> 3 -> 4 -> 7. Tasks 5 and 6 are independent and can run in
parallel; Task 6 is the largest single item and does not block anything.

**This is a LARGE sprint** -- the upper estimate is ~31 hours. If that is too much, the natural cut
is **Task 6 (F217, 240-480m)**, which is independent, or **Task 7 (F229)**, which is the lowest
priority. Cutting Tasks 1-4 is not advisable: they share one root cause and one file, and splitting
them means paying the context cost twice.

## Open questions for Harold at approval

1. **Version bump (Task 0b)**: PATCH `0.15.3+6` or MINOR `0.16.0+6`? Recommendation: PATCH, because
   F233 is developer tooling rather than a user-facing feature.
2. **Task 4 R-10**: hardcoded font sizes or theme text styles? Recommendation: theme styles, which
   also honour the OS font-size accessibility setting.
3. **Sprint size**: ~18-31 hours. Accept in full, or cut Task 6 and/or Task 7?

## Phase 3.7 approval

**NOT APPROVED YET.** No task execution begins until Harold approves. Task 0 is the exception
Harold already authorized ("probably should be done first or separate agent") and can proceed on his
word alone, since it contains no application code.
