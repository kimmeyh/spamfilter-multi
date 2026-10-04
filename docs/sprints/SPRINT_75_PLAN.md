# Sprint 75 Plan -- APPROVED 2026-10-03

**Status**: **APPROVED 2026-10-03 by Harold, as amended** (see Phase 3.7 approval). Executing.
**Branch**: `feature/20261002_Sprint_75` | **PR**: #448 (draft, Phase 3.3.1)
**Issues**: #441 (F238), #442 (F239), #444 (F216), #445 (F214), #446 (F236), #447 (F215), #449 (Task 7), #450 (F243, Task 8 -- added at Manual Validation)
**Version**: **0.17.0+8 -- NO BUMP this sprint (EXCEPTION, Harold 2026-10-02)**: *"no store release
was done after the last sprint, so keep 0.17.0 for this sprint (note as an exception)"*. F190
normally bumps MINOR at plan approval; it is skipped because 0.17.0 never reached a store, so the
release that carries F238 ships as 0.17.0 and its notes (`RELEASE_NOTES_0.17.0_*.md`) are
re-derived at Phase 7.7 to add this sprint's entries.

**Scope selected by Harold, 2026-10-02 (Phase 8.4)**: F238, F216, F214, F236, F239, F215.

**Release note**: 0.17.0 is on hold on BOTH stores until F238 ships (Harold, 2026-09-27; re-confirmed
2026-10-02). No AAB until the Sprint 74 and Sprint 75 PRs are both merged.

**Model note**: planned on Opus 5.5. F238 is assigned **Fable 5.1** by Harold and will be executed by a
Fable 5.1 sub-agent (Agent tool, `model: fable`), not by the session model.

**Execution note (SPRINT_PLANNING.md Sprint 68 IMP-4, option (b))**: the cheap independent tasks
(F214, F236, F215) are front-loaded as a delegable block on their assigned tier BEFORE Manual
Validation; F216 runs on Sonnet; F239 runs on the session model (Opus 5.5). Same-file work is
serialized (F216 and F238 both avoid each other's files; see Affected components).

---

## ADR-0042 applies to EVERY task in this sprint

Harold, restated 2026-10-02: *"everything needs to take into account both the Windows App and the
Android app and ADR stating that everything should be functionally and UI the same unless it cannot
be - and where it cannot be it should be implemented as a platform exception for what is needed --
this applies to all backend code, frontend code, data, architecture, development, security,
testing, deployment."*

Per task: F238, F216, F214, F236 are shared code and UI with NO platform exception expected. F239 is
the one task with a genuine platform difference (Android sign-in has no refresh token and no
Activity in a background worker; Windows renews over HTTP) -- its Android-only renewal is a DECLARED
exception; the "Sign In Again" path is identical on both. F215 is process/docs (N/A).

---

## Phase 3.2.2.1 findings (audit-first, Sprint 65 IMP-2) -- what is ALREADY true

- **F216 -- PARTLY DONE.** Sprint 72's F230 already raised the action pop-up's
  folder/subject/rule line to `bodyMedium` (14sp) -- Harold's 2026-09-12 decision "2. a". Still
  open: the pop-up's date and domain row is `bodySmall` (12sp; Harold asked for 14sp,
  `results_display_screen.dart` ~:2363 and ~:2385); the supporting text on
  `manual_rule_create_screen.dart` (:628 confirm dialog, :815 `Type:`/`Phrase:` lines, the
  `Examples:` hint and the field's floating label) and `rule_edit_screen.dart` (:956, :965).
- **F214 -- NOT DONE.** `settings_screen.dart:2409-2423` still flanks the Scan Range slider with
  `Text('1')` / `Text('90')` inside a Row; no other slider exists in `lib/ui` (one grep).
- **F236 -- NOT DONE.** `YamlService.renderRules` / `renderSafeSenders` (`yaml_service.dart:80,85`,
  added Sprint 74) emit no version; `AppVersion.get()` exists (`app_version.dart:27`).
- **F215 -- PARTLY DONE.** `validation-screenshots/` with `sprint-69/`, `sprint-70/` and its README
  exist; the MTP pull script exists only in Claude memory
  (`memory/pull_phone_screenshots.ps1`, `-Dest` free-form). The five process references the card
  lists are not written.
- **F238 -- NOT DONE.** No cancel-request channel exists (`cancel_requested` greps to nothing).
  DB is v10 (`database_helper.dart:58`), so the new column is **v11**.
- **F239 -- NOT DONE.** `error_display.dart:118/215` has a "Sign In Again" action no screen uses;
  Android renewal goes through `attemptLightweightAuthentication` (fails with `NO_ACTIVITY` in a
  worker). Mechanism evidence below (Task 5 R-1).

---

## Task 0 -- Version: NO bump (exception) (Phase 3.7.0b)

**Value**: This keeps the version honest: 0.17.0 never shipped, so the release carrying F238 is
still 0.17.0.

**Requirements**:
- R-1: Do NOT run the F190 bump; record the exception in this plan, `sprint_status.json` and
  `STORE_VERSION_STATUS.md`.
- R-2: At Phase 7.7 re-derive `RELEASE_NOTES_0.17.0_windows.md` / `_play.md` to include Sprint 75
  user-facing entries (the CHANGELOG range is Sprint 74 + Sprint 75).

**Affected components / files**: `docs/STORE_VERSION_STATUS.md`, `.claude/sprint_status.json`.
**Acceptance criteria**: AC-1: `pubspec.yaml` still reads `0.17.0+8`; `version_consistency_test`
passes unchanged.
**Tests to write**: none (existing `version_consistency_test` covers it).
**Definition of Done**: None -- default DoD only.
**Model**: Haiku -- *why not cheaper*: n/a. **Step-types**: DOCS. **Est-Effort**: 5-10m.

---

## Task 1 -- F238: Offer to stop a running background scan in favor of a manual scan (Priority 1, Issue #441)

**Value**: This lets a user who taps Start Scan get the scan they asked for, instead of a dead end
behind a background scan they cannot see or stop.

**Requirements**:
- R-1: When a manual scan is refused because a BACKGROUND scan holds the account, the "A scan is
  already running" dialog offers a third action, **"Stop the background scan and start mine"**.
- R-2: Cross-isolate / cross-process cancel request through the database: a new nullable column
  `scan_results.cancel_requested_at` (DB **v11**, guarded additive migration). The UI writes it on
  the holder row (`WHERE id = ? AND status = 'in_progress'`).
- R-3: The scanning isolate checks its own row on its EXISTING heartbeat tick
  (`EmailScanProvider._startHeartbeat`, 30 s) and, when set, requests cancel through the EXISTING
  F224 path in its own isolate (`ScanCoordinator.requestCancel`), so the scan stops at its next
  batch boundary, records `interrupted` with its partial counts, releases its lease and closes its
  IMAP session.
- R-4: The stopped row's reason reads that the user stopped it for a manual scan -- never an error.
- R-5: The manual side shows "Stopping the background scan..." and waits, BOUNDED (90 s), for the
  holder row to close (or its heartbeat to go stale, which the claim reaps), then starts the manual
  scan through the normal path (the claim decides). If the bound expires, the user is told and
  nothing starts; nothing is left `in_progress` forever.
- R-6: Only a BACKGROUND holder can be stopped. A manual scan or rule update holding the account
  keeps the OK-only dialog.
- R-7: Parity -- the same dialog and the same row-based cancel on Android (worker isolate) and
  Windows (worker process). No platform exception.

**Affected components / files**:
- `lib/core/storage/database_helper.dart` -- v11 column + migration.
- `lib/core/storage/scan_result_store.dart` -- `requestCancel(scanId)`, `isCancelRequested(scanId)`.
- `lib/core/providers/email_scan_provider.dart:301` -- heartbeat tick reads the request;
  `cancelScan` takes a reason.
- `lib/ui/screens/scan_progress_screen.dart:769-850` -- third action, waiting state, bounded wait.
- `lib/core/services/email_scanner.dart` -- no change expected (F224 path already honors cancel at
  the batch boundary with the scan's own lease).

**Existing abstraction checked**: F224 `ScanCoordinator.requestCancel` / `throwIfCancelled(lease)`
and the MV74-2 heartbeat timer -- REUSED; no second cancel path and no second timer.

**Callers of any guard being changed**: `claimAccountScan` is NOT changed (the manual scan claims
after the holder closes). `cancelScan` gains an optional reason: callers are the scanner's
`ScanCancelledException` catch (user Cancel button -- unchanged text) and the new
stop-for-manual path (new text).

**User-reachable control**: Manual Scan screen > Start Live Scan > "A scan is already running" >
"Stop the background scan and start mine".

**Observable behavior -- before / after**: BEFORE: a background scan is running on the account; you
tap Start Live Scan and see "A scan is already running ... Start this scan again when it finishes"
with OK only; nothing starts. AFTER: the same dialog also offers "Stop the background scan and
start mine"; tapping it shows "Stopping the background scan..." for up to about a minute and a half,
then your manual scan starts; Scan History shows the background scan as "Not finished" with the
reason "Stopped so your manual scan could start". If the background scan does not stop in time,
you are told and nothing starts. When a MANUAL scan or a rule update holds the account, you still
see OK only.

**Dependencies / blockers**: None (Sprint 74 lock merged).

**Non-functional requirements**:
- Account-scoping: the request targets the holder row by id; never another account's scan.
- Persistence: DB v10 -> v11, guarded; back up the dev DB before the first migration run.
- Accessibility: the new action has a semantics label (WinWright-addressable).
- Platform: identical; cross-isolate on Android, cross-process on Windows.

**Acceptance criteria**:
- AC-1: Given a live background row on account A, When the stop action runs, Then the request is
  written, the scanning provider's next tick requests cancel, and the row ends `interrupted` with the
  stop-for-manual reason.
- AC-2: Given the holder closes, Then the waiting manual start proceeds and the claim is granted;
  at no point do two `in_progress` rows exist for A.
- AC-3: Given the holder does not close within the bound, Then the user sees the not-stopped message,
  no manual row is written, and the holder is reaped by the claim once its heartbeat is stale.
- AC-4: Given a MANUAL holder or a `reprocess` holder, Then the dialog offers OK only.
- AC-5: The v11 migration adds the column to a v10 database and keeps existing rows.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT `test/unit/storage/`: request written; a provider heartbeat tick (short
  interval) honors it and the row ends `interrupted` with the reason.
- T-2 (AC-2, AC-3) -- TEST-UNIT: the bounded wait returns "closed" when the holder closes and
  "timed out" when it does not; no second live row.
- T-3 (AC-4) -- TEST-WIDGET: dialog actions for background vs manual vs reprocess holders.
- T-4 (AC-5) -- TEST-UNIT: real `DatabaseHelper` upgrade v10 -> v11.
- What these do NOT catch: real cross-isolate timing on a dozing phone and a long single IMAP fetch
  delaying the batch boundary -- Manual Validation (Windows now; phone per Open question 3).

**Definition of Done**: default DoD PLUS: Windows Manual Validation with a background scan really
running IN ANOTHER PROCESS (dev exe started with `--background-scan --account-id=<account>`
first, then the app opened and Start Live Scan on that account -- NOT Settings > Test Background
Scan, which runs in-process on Windows; review H-2, 2026-10-03); ADR-0039
amendment (the cancel channel); ARCHITECTURE.md (schema v11, the dialog flow).

**Model**: **Fable 5.1** (Harold named it) -- *why not cheaper*: cross-isolate/cross-process control
through the database on the live-deletion path, with a migration.
**Step-types**: DATA, SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET, DOCS
**Est-Effort**: 180-300m (Sprint 74 lock actuals: claim + mapping ~110m; dialog + wait state on top).

**Risk & rollback**: a request written but not honored leaves the user waiting -- bounded wait +
claim reaping. Rollback: the dialog reverts to OK-only; the column is additive and unused.

**Decision-class interrupts**: **Class-1** -- a new cross-isolate control channel through the database
and DB v11. Asked at approval (Open question 1).

---

## Task 2 -- F216: Supporting text matches the text it supports (Priority 32)

**Value**: This makes the text a user reads while creating a rule, or confirming which email they
are about to block, as legible as the text next to it.

**Requirements**:
- R-1 (audit first -- done above): only the parts not already fixed by F230 are in scope.
- R-2: Action pop-up: the date and domain row goes from `bodySmall` (12sp) to `bodyMedium` (14sp),
  matching its folder/subject/rule line (Harold, 2026-09-12, "2. a"). The sender line is NOT changed.
- R-3: Manual rule screen (block rules AND safe senders, one screen) and the rule editor: the
  supporting text for the field being filled in -- the `Examples:` hint, the generated `Type:` and
  `Phrase:/Source:` lines, and the same pair in the confirm dialog -- goes to `bodyMedium`. Genuinely
  ambient labels elsewhere stay `bodySmall` (the theme's hierarchy is kept).
- R-4: Check `no_rule_review_screen.dart` and `scan_history_screen.dart` metadata lines; change them
  only if they show the same mismatch on the same kind of line, and record what was found either way.
- R-5: Verify in BOTH themes (light and dark).

**Affected components / files**: `lib/ui/screens/results_display_screen.dart` (~:2363, ~:2385),
`lib/ui/screens/manual_rule_create_screen.dart` (:628, :815, the Examples hint and field label),
`lib/ui/screens/rule_edit_screen.dart` (:956, :965).

**User-reachable control**: N/A (existing screens).

**Observable behavior -- before / after**: BEFORE: in the email pop-up the date and domain are
smaller than the folder/subject line above them; on Add Rule / Add Safe Sender and Edit Rule the
"Examples: ...", "Type: ..." and "Phrase: ..." text is smaller than "Block emails whose body..."
beside it. AFTER: those lines are the same size as the text they sit next to, in both light and dark
mode. Sender names, titles and other secondary labels are unchanged.

**Dependencies / blockers**: None. Do not run concurrently with Task 1 on the same files (no overlap).

**Non-functional requirements**: Accessibility -- size change keeps the F210 contrast pairing (colors
unchanged); text scaling still follows the system setting.

**Acceptance criteria**:
- AC-1: The pop-up's date/domain row and its folder/subject line use the same text style.
- AC-2: On the manual rule screen and the rule editor, the Examples / Type / Phrase lines use the
  same style as the option subtitles beside them.
- AC-3: R-4 findings recorded in the card (changed or not, with the reason).

**Tests to write**:
- T-1 (AC-1) -- TEST-WIDGET: open the pop-up; the date text and the subject line resolve to the same
  font size.
- T-2 (AC-2) -- TEST-WIDGET: manual rule screen and rule editor; the Type/Phrase lines resolve to the
  subtitle size.
- What these do NOT catch: how it looks at phone width -- Manual Validation (screenshots, both themes).

**Definition of Done**: default DoD PLUS: Windows Manual Validation in light and dark mode.
**Model**: Sonnet -- *why not cheaper*: the survey (supporting vs ambient text) is a judgment call;
the edits themselves are mechanical.
**Step-types**: UI-MOVE, TEST-WIDGET
**Est-Effort**: 40-75m (F230-style style edits; the pop-up half is two lines).

---

## Task 3 -- F214: Scan Range slider lines up with the controls above it (Priority 34)

**Value**: This removes the one control on the Scan Range card that does not line up with its
neighbours, which a tester noticed.

**Requirements**:
- R-1 (audit first -- done above): the slider at `settings_screen.dart:2409-2423` is flanked by
  `Text('1')` / `Text('90')`; it is the only slider in `lib/ui`.
- R-2: Remove the flanking "1" / "90" labels; the slider's own value label (shown while dragging) and
  the existing "N days" text carry the value. (Candidate (a) on the card -- fewest moving parts.)
- R-3: The slider's track starts at the same left edge as the "Scan all emails" checkbox above it,
  on both the Manual and Background tabs (both use the same widget).

**Affected components / files**: `lib/ui/screens/settings_screen.dart:2405-2425`.

**User-reachable control**: N/A (existing control).

**Observable behavior -- before / after**: BEFORE: the Scan Range slider sits between a "1" and a
"90", so its track starts noticeably further in from the card edge than the checkbox above it.
AFTER: no "1" / "90" beside the slider; the track lines up with the controls above it; dragging still
shows the number of days, and the days text under the slider still updates.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: No `Text('1')` / `Text('90')` flanks the slider; the slider still sets 1-90 days.
- AC-2: The slider's left edge equals the checkbox row's left edge (measured in a widget test).

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-WIDGET in `test/ui/screens/`: the slider's left edge matches the checkbox
  tile's left edge within 1 px; dragging changes the stored days.
- What this does NOT catch: the tester's phone width -- Manual Validation screenshot.

**Definition of Done**: None -- default DoD only (plus a Windows screenshot at Manual Validation).
**Model**: Haiku -- *why not cheaper*: n/a (cheapest tier).
**Step-types**: UI-MOVE, TEST-WIDGET
**Est-Effort**: 20-40m.

---

## Task 4 -- F236: Stamp the app version into the YAML rules export (Priority 36)

**Value**: This tells anyone reading an exported rules file which app version wrote it.

**Requirements**:
- R-1: `YamlService.renderRules` and `renderSafeSenders` start with a YAML comment carrying
  `AppVersion.get()` and the export date. No version literal anywhere (`version_consistency_test`,
  `stale_footer_test`).
- R-2: The import path ignores the comment; the export invariants (lowercase, trimmed, sorted,
  single quotes) are unchanged.

**Affected components / files**: `lib/core/services/yaml_service.dart:80-85` (the two renders become
async or take the version as a parameter; callers in `yaml_import_export_screen.dart`).

**User-reachable control**: N/A (existing export).

**Observable behavior -- before / after**: BEFORE: an exported `rules.yaml` / `rules_safe_senders.yaml`
starts directly with the rules. AFTER: its first line is a comment such as
`# Exported by MyEmailSpamFilter 0.17.0 on 2026-10-05`; importing the file works exactly as before.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: Both exports begin with the version comment; the version equals `AppVersion.get()`.
- AC-2: Re-importing an exported file yields the same rules (round trip).

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-UNIT `test/unit/services/`: render -> first line is the comment with the
  current version; render -> parse -> equal rule set.
- What this does NOT catch: a third-party YAML reader that mishandles a leading comment (standard YAML
  allows it).

**Definition of Done**: None -- default DoD only.
**Model**: Haiku -- *why not cheaper*: n/a.
**Step-types**: SVC-EDIT, TEST-UNIT
**Est-Effort**: 20-40m.

---

## Task 5 -- F239: Gmail on Android renews its sign-in without the app open, plus "Sign In Again" (Priority 12, Issue #442)

**Value**: This lets a Gmail account keep scanning in the background past the first hour, and lets a
user whose Gmail session expired sign in again without deleting the account.

**Requirements**:
- R-1 **(capability spike FIRST -- Tooling-Capability Pre-Flight rule)**: prove on the Android
  emulator, from a background (non-Activity) context, that the platform interface's
  `clientAuthorizationTokensForScopes` with the stored account EMAIL and `promptIfUnauthorized: false`
  returns an access token for already-granted Gmail scopes. Evidence gathered at planning:
  - Google, *Authorization* (developer.android.com/identity/authorization, updated 2025-10-27):
    *"If the access was previously granted"* the request returns the token with no UI
    (`hasResolution()` false), and *"call the same method to obtain an access token ... without any
    user interaction"*. The page does NOT say whether a background context works -- hence the spike.
  - google_sign_in_android 7.2.7 builds the `AuthorizationClient` from the APPLICATION context and
    needs an Activity only to SHOW a prompt; the step that fails in a worker today is
    `attemptLightweightAuthentication` (Credential Manager, `NO_ACTIVITY`), which this path skips.
  - google_sign_in 7.2.0's instance-level `authorizationClient` passes NO account hint; the platform
    interface accepts `email`, which is why the spike uses it.
- R-2 (if the spike passes; Class-1 approved conditionally at Open question 2): on Android, renewal
  calls that path with the stored email instead of lightweight sign-in, in the app AND the worker.
  A declared ADR-0042 exception (Windows already renews over HTTP).
- R-3: If renewal still fails, the background scan for that account is recorded as SKIPPED with the
  reason "Gmail needs you to sign in again" -- not an error, not a success -- and tokens are kept
  (Sprint 74 rule).
- R-4: Wire the existing "Sign In Again" action (`error_display.dart`) where an expired Gmail session
  is reported: the account list row and the scan error. It re-runs the interactive sign-in for the
  SAME account and saves the tokens under the same account id -- the account is never deleted.
  Identical on Windows and Android.
- R-5: `getValidAccessToken` never falls back to another account's id.
- R-6: If the spike FAILS: stop, record what it showed, and surface the alternatives (server auth
  code + a token-exchange service; or "Sign In Again" only) before building R-2. R-4 and R-5 do not
  depend on the spike and proceed either way.

**Affected components / files**: `lib/adapters/auth/google_auth_service.dart` (:188, :286, :392);
`lib/adapters/email_providers/gmail_api_adapter.dart`; `lib/ui/screens/account_selection_screen.dart`
(the error row ~:879); `lib/ui/widgets/error_display.dart`; `lib/core/services/background_scan_core.dart`
(skip reason); `pubspec.yaml` (direct dependency on `google_sign_in_platform_interface`, already
present transitively).

**Existing abstraction checked**: `GoogleAuthService` renewal paths and `AuthErrorDisplay`
("Sign In Again", unused) -- REUSED.

**Callers of any guard being changed**: `getValidAccessToken` (R-5) -- callers: `GmailApiAdapter`
token validation, `gmail_client.dart`, `folder_selection_screen.dart`; each passes or has a current
account set -- the card records each at implementation.

**User-reachable control**: Account list (Select Account) > a Gmail row whose session expired >
"Sign In Again"; and the scan error banner for that account.

**Observable behavior -- before / after**: BEFORE: on Android, about an hour after signing in, Gmail
background scans stop working; a Gmail account whose sign-in expired shows an error you can only
fix by deleting the account and adding it again. AFTER: Gmail background scans keep working past the
hour (if the spike passes); if Gmail ever does need you, the account row and the scan error show
"Sign In Again", which signs you in again and keeps the account, its settings and its history.

**Dependencies / blockers**: the emulator spike needs a Google account signed in on the emulator and
a debug build that completes (pre-flight at task start). Device confirmation follows Open question 3.

**Non-functional requirements**: Security -- tokens stay in secure storage; nothing new is logged
(Redact). Account-scoping -- the email hint is the account's own stored email.

**Acceptance criteria**:
- AC-1: The spike result is recorded with its evidence (pass or fail).
- AC-2 (if pass): with an expired stored token, the Android renewal returns a token without an
  Activity; tokens are saved under the same account id.
- AC-3: A failed renewal in a background scan is recorded as SKIPPED with the reason.
- AC-4: Given an expired Gmail session, When the user taps "Sign In Again" and completes sign-in, Then
  the account keeps its id, settings and history, and the next scan succeeds.
- AC-5: `getValidAccessToken` with no current account returns null rather than another account's token.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT: renewal routes through a fake platform interface with the stored email and
  no prompt; tokens saved under the same id.
- T-2 (AC-3) -- TEST-UNIT: background core maps a renewal failure to a skip with the reason.
- T-3 (AC-4) -- TEST-WIDGET: the account row shows "Sign In Again" for an expired Gmail session and
  calls sign-in for that account.
- T-4 (AC-5) -- TEST-UNIT.
- What these do NOT catch: real Google behavior on a device in Doze -- Manual Validation.

**Definition of Done**: default DoD PLUS: ADR (Class-1 auth mechanism -- amend the OAuth ADR or a new
one), ARCHITECTURE.md (renewal path), ADR-0042 exception recorded.
**Model**: Fable/Opus (session: Opus 5.5) -- *why not cheaper*: an auth-mechanism spike with a
Class-1 outcome.
**Step-types**: SPIKE, SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET, DOCS
**Est-Effort**: 240-480m (spike 30-60m; renewal 60-120m; Sign In Again 90-180m; docs 30-60m).

**Risk & rollback**: the spike may fail or the emulator sign-in may not work -- R-6 bounds it; R-4/R-5
still ship. Rollback: renewal reverts to the current path; "Sign In Again" is additive.

**Decision-class interrupts**: **Class-1** (auth mechanism) -- conditional approval asked at Open
question 2; a failed spike is surfaced, not worked around.

---

## Task 6 -- F215: Wire the validation-screenshot folder into every Android screenshot process (Priority 30)

**Value**: This keeps Manual Validation evidence after the chat ends, under names that say what it
shows.

**Requirements** (the card's five places, plus the script):
- R-1: Promote `memory/pull_phone_screenshots.ps1` to `scripts/pull-phone-screenshots.ps1` (written
  and reused across sprints -- the IMP-4 promotion rule) with `-Sprint N` defaulting `-Dest` to
  `validation-screenshots/sprint-NN/`, and a `.SYNOPSIS`.
- R-2: `SPRINT_EXECUTION_WORKFLOW.md` Phase 5.3: save phone screenshots to
  `validation-screenshots/sprint-NN/` with descriptive names before discussing them.
- R-3: Backlog-card authoring (`BACKLOG_REFINEMENT.md` Step 5): cite the relative path of any image a
  card is written from.
- R-4: `SPRINT_RETROSPECTIVE.md`: validation evidence points at the folder.
- R-5: `TESTING_STRATEGY.md`: name the folder as the home for manual-validation evidence.
- R-6: Record the retention decision (keep indefinitely; no pruning) in the folder README, and note
  the per-session image cache (`~/.claude/image-cache/`) as usable WITHIN a session only.

**Affected components / files**: `scripts/pull-phone-screenshots.ps1` (new), the four docs above,
`validation-screenshots/README.md`, the memory pointer.

**User-reachable control**: N/A (process).
**Observable behavior -- before / after**: N/A (no app change).
**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: `scripts/pull-phone-screenshots.ps1 -Sprint 75 -ListOnly` (or equivalent) runs and names the
  destination `validation-screenshots/sprint-75/`.
- AC-2: The four docs each reference the folder (grep).

**Tests to write**: T-1 (AC-2) -- a grep check recorded in the card; no app tests.
**Definition of Done**: None -- default DoD only (no CHANGELOG entry: not user-facing).
**Model**: Haiku -- *why not cheaper*: n/a.
**Step-types**: DOCS, SCRIPT
**Est-Effort**: 30-60m.

---

## Task 7 -- Sprint 74 carry-ins: WinWright scripts + widget tests for the new controls (Harold Q4 = add)

**Value**: This puts the controls added in Sprints 74-75 under the same automated checks as the
older screens, so a later change cannot silently break them.

**Requirements**:
- R-1: WinWright scripts (`test/winwright/`, run by `run-winwright-tests.ps1`) for: the Scan Results
  Sort chip (toggles the label), Scan History Clear history (dialog opens and cancels -- no data
  change), Settings "Hide sender details in exports" (toggle and restore), the resolved-default folder
  rows (visible). Each script restores any state it changes (WinWright policy).
- R-2: Widget tests (PR #440 test review MINOR 5/7/8/9): the Results "another scan is running" row
  uses the info style, never the error style; the Manual Scan OK-only dialog and the refusal
  snackbar; the redaction toggle persists `getExportRedacted()`; Clear history's zero-finished
  snackbar and scope text.
- R-3: The F238 dialog action (Task 1) gets its widget test in Task 1 (T-3); a WinWright script for it
  is added here only if a background scan can be held deterministically -- otherwise recorded as
  Manual Validation only.

**Affected components / files**: `mobile-app/test/winwright/*.json` (new), `mobile-app/test/ui/screens/`
(new widget tests); `docs/WINWRIGHT_SELECTORS.md` if new selectors are used.

**User-reachable control**: N/A (tests). **Observable behavior -- before / after**: N/A (no app change).
**Dependencies / blockers**: Task 1 (the dialog), WinWright pre-flight (screen-reader flag, unlocked
workstation).

**Acceptance criteria**:
- AC-1: The new scripts pass in the sweep with no DB drift.
- AC-2: The four widget tests pass and each is mutation-checked (`scripts/mutation-test.ps1`).

**Tests to write**: as R-1 and R-2.
**Definition of Done**: default DoD (no CHANGELOG entry: not user-facing).
**Model**: Sonnet -- *why not cheaper*: WinWright selector work needs judgment on the semantics tree.
**Step-types**: TEST-WIDGET, TEST-E2E
**Est-Effort**: 105-165m.

---

## Task 8 -- F243: Windows background scans run while the app is open (Issue #450; added at Manual Validation, Harold 2026-10-03)

**Value**: This keeps Windows background scans protecting the mailbox while the app is open -- as Android already does -- instead of stopping for as long as the window stays open.

**Requirements**:
- R-1: A `--background-scan` launch no longer exits because the foreground app is running. `windows/runner/main.cpp`'s read-only mutex probe (BUG-S37-1, Sprint 38) is removed; the background process never takes the UI mutex (unchanged), so the UI can still open during a background scan.
- R-2: "Not during a live scan" is decided by the database, PER ACCOUNT (Harold Sprint 74 Q4: one scan per account of any type): the Sprint 74 claim (`ScanResultStore.claimAccountScan`, `in_progress` row + `last_heartbeat_at`) refuses a background scan of an account a live scan holds -> skip, one retry after 2-6 min (`BackgroundScanCore.scanAccount`). A background scan that started FIRST is stopped by the user through the F238 offer (`cancel_requested_at`). No new field, no new lock.
- R-3: Remove the Windows texts that would become false: Settings > Background "Background scans pause while this app is open..." (F109a) and the Scan History hint (F109b). Old `deferred` rows stay readable; the F109c ingest stays (it consumes a stale handoff file, harmlessly).
- R-4: The BUG-S37-1 integration script (`scripts/test-background-scan-skip.ps1`) is inverted: with the UI open, a background launch must RUN (no "mutex held" skip line), not exit.
- R-5: ADR-0039 amendment + ARCHITECTURE: the deferral is replaced by the claim; record why it is now safe (WAL + 30 s busy_timeout in `database_helper.dart`; claim; busy retry) and that Windows now matches Android (ADR-0042, no exception).

**Affected components / files**:
- `mobile-app/windows/runner/main.cpp` -- probe + `LogBackgroundScanSkip` / `RecordBackgroundScanDeferral` / `ExtractAccountId` removed (`/W4 /WX`: unused statics would fail the build).
- `mobile-app/lib/ui/screens/settings_screen.dart` -- F109a status line + its deferral lookup removed.
- `mobile-app/lib/ui/screens/scan_history_screen.dart` -- F109b hint removed.
- `mobile-app/scripts/test-background-scan-skip.ps1` -- assertion inverted.
- `mobile-app/test/unit/ui/f217_doze_honesty_test.dart` -- its "Windows sibling untouched" assertion becomes "Windows line removed (F243)".
- `docs/adr/0039-per-account-background-scanning.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`.

**Existing abstraction checked**: `ScanResultStore.claimAccountScan` + `BackgroundScanCore.scanAccount` busy retry + F238 `requestCancel` -- REUSED; nothing new added.

**Callers of any guard being changed**: the probe has ONE caller path -- `wWinMain` with `--background-scan` (Task Scheduler per-account tasks, and a manual CLI launch). Foreground launches are untouched (they still take the mutex and activate an existing window). Effect on that path: it now proceeds to `executeBackgroundScan`, which reaches the claim BEFORE any IMAP connection (MV74-2 early check, then the atomic claim).

**User-reachable control**: N/A (no new control) -- the existing Settings > Background > Enable Background Scanning now also scans while the app is open.

**Observable behavior -- before / after**: BEFORE: on Windows, while the app window is open, scheduled background scans do not run ("deferred"); Settings and Scan History say so. AFTER: they run on schedule with the app open; an account you are scanning by hand is skipped by the background scan (and retried a few minutes later); a background scan already running when you start a Live Scan offers "Stop the background scan and start mine". The "pause while this app is open" texts are gone.

**Dependencies / blockers**: Task 1 (F238) -- landed.

**Non-functional requirements**:
- Platform: the change REMOVES a Windows-only behavior, bringing Windows to Android's (ADR-0042) -- no new platform branch.
- Persistence: two processes on one DB file -- WAL + busy_timeout 30 s (verified in `database_helper.dart` at planning); the claim is one `BEGIN IMMEDIATE`.

**Acceptance criteria**:
- AC-1: Given the dev app is open, When `MyEmailSpamFilter-Dev.exe --background-scan --account-id=<a>` runs for an account with background enabled, Then the background log shows the worker scanning that account (no "mutex held" skip).
- AC-2: Given a Live Scan holds account A, When a background scan of A starts, Then it records a skip (no second session on A).
- AC-3: Given a background scan of A is running, When the user starts a Live Scan on A, Then the F238 offer appears (the Manual Validation F238 check, now runnable with the app open).
- AC-4: Neither "pause while this app is open" text is shown anywhere.

**Tests to write**:
- T-1 (AC-1) -- TEST-INTEGRATION (native): `scripts/test-background-scan-skip.ps1`, inverted, against the rebuilt exe.
- T-2 (AC-2) -- already covered: `mv74_2_scan_heartbeat_test.dart` ("SKIPS the account while a manual scan is live", "busy -> one wait"); re-run, no new test.
- T-3 (AC-4) -- TEST-UNIT source gate in `f217_doze_honesty_test.dart`: neither text nor key remains in lib/ (mutation-checked by restoring one).
- AC-3 -- Manual Validation (two real processes).

**Definition of Done**: default DoD PLUS: Windows rebuild; T-1 run green; the Manual Validation F238 check re-run with the app open.

**Model**: Fable/Opus (main session) -- *why not cheaper*: reverses a Class-1 decision across native C++ and two processes on one DB; the claim/retry reasoning is the whole task.

**Step-types**: NATIVE-WIN, UI-MOVE, TEST-INTEGRATION, TEST-UNIT, DOCS.

**Est-Effort**: 60-90m.

_**Risk & rollback**_: Risk -- a "database is locked" mid-scan write that outlasts the 30 s busy timeout while the UI writes heavily (the BUG-S37-1 symptom). Mitigation: WAL readers never block the writer; the claim/busy retry. Rollback: restore the probe in `main.cpp` (one block) and the two texts.

_**Decision-class interrupts**_: Class 1 (reverses BUG-S37-1 / F109) and Class 3 (scope added at MV) -- both approved by Harold, 2026-10-03 ("OK to create a full sprint plan for this item ... and then do now"); per-account scope taken as the recommended option.

---

## Carry-ins from the Sprint 74 retrospective (Category 13) -- WinWright + widget tests are now Task 7 (Q4 = add)

- **Phone validation checklist** (0.17.0 phone build; timing per Open question 3):
  1. MV74-1 -- background scans fire in Doze; the schedule survives a reboot (#428).
  2. A block rule added from a saved scan moves the mail; the toast reports N of N (F232 AC-2).
  3. F205 -- classify every scan error on the current build, or record zero (#433).
  4. The per-account lock under a real Doze batch -- never two `in_progress` rows for one account.
  5. The 2-6 minute busy wait against Android's ~10-minute worker limit.
  6. Android YAML export saves through the system dialog.
  7. (Sprint 75) F238 stop-for-manual and F239 renewal / Sign In Again on the phone.
- **WinWright scripts** for new UI with none yet (~60-90m): Sort chip, "A scan is already running"
  dialog (and F238's new action), Scan History Clear history, "Hide sender details in exports",
  resolved-default folder rows.
- **Widget tests** for the same controls (PR #440 test review MINOR 5/7/8/9, ~45-75m): the Results
  "another scan is running" row uses the info style; the Manual Scan OK-only dialog and refusal
  snackbar; the redaction toggle persists; Clear history's zero-finished snackbar and scope text.

## Progress (live)

- **Manual Validation round 2 decisions (Harold, 2026-10-03)**: Q2 Scan History reason on every "Not finished" row -- KEEP; Q3 the two Sprint 74 refusal defects -- FIX NOW (6320a9d: header "Scan not started"; Results refusal row reachable via `showLiveRefusal`; M107-M109 KILLED); Q4 one-time notification for a needs-sign-in skip -- BACKLOG as F244; Q5 YAML export save dialog ignored the export folder -- FIX NOW (a730d1a: `ExportDirectories.saveDialogStart`, document URI on Android; M110-M112 KILLED); Q7 F243 per account -- KEEP. Round 3: checks 1-3 (YAML export folder on both platforms; "Scan not started") PASSED; Gmail added on the emulator and scanned, but the add flow returned to the sign-in page -- since Sprint 19 F27 the folder screen saves per tick and is left with the back arrow, which returns no list. Harold: Q2 Gmail Setup sentence -- FIX NOW; Q3 Gmail add flow -- finish "the same that is done after adding AOL and Yahoo" -- FIX NOW (no folder step; GmailOAuthScreen returns the address; AccountSetupScreen `_finishAccountAdded` shared with the IMAP path; M113-M115 KILLED, M115 after tightening a presence-only gate). Q1 (Windows background sign-in) still awaiting an answer. F238 PASSED on Windows (row 6841 interrupted with the stop reason; manual scan 6842 started 22 s after the request).
- **Task 8 F243 -- DONE** (7478eb1; added at Manual Validation, Harold 2026-10-03). Windows background scans run with the app open; the per-account claim decides. Native integration script inverted and PASS on the rebuilt exe; M106 (old exit restored + rebuilt) KILLED; M104/M105 (removed texts reintroduced) KILLED. Finding, not fixed: an account-scoped Windows run that matches no account (or only a disabled one) exits 1 / logs "FAILURE" -- pre-existing worker accounting. Executed-by: Opus 5.5 (main session), as assigned.
- **Task 3 F214 -- DONE** (commit 1f80ecd). Flank labels removed. The agent's first test passed
  vacuously (no Slider rendered with no account); rewritten on the one-account harness to measure the
  slider's left edge and width against the "Scan all emails" tile. M76 KILLED.
- **Task 4 F236 -- DONE** (1f80ecd). **Parity defect found in review**: the header was added only to
  `renderRules` / `renderSafeSenders` (the Android/iOS save path); Windows writes through
  `exportRules` / `exportSafeSenders` and would have shipped no header. Both now take `appVersion`;
  both paths tested. The agent's test did not compile (nonexistent `models/rule.dart`); rewritten.
  M77, M78 KILLED.
- **Task 6 F215 -- DONE** (1f80ecd). AC-1: `-Sprint 75 -ListOnly` names
  `validation-screenshots\sprint-75`. AC-2: grep finds the folder in all four docs. Fixed in review:
  the script's default destination hardcoded THIS session's scratchpad path (now `%TEMP%`), and the
  README's `~/.claude/image-cache/` claim -- that folder does not exist on 2026-10-03; images now live
  only inside the session transcript (verified: 28 image entries in this session's `.jsonl`).
- **Task 1 F238 -- DONE**. 12 agent mutations KILLED. **Defect found in review (agent's flagged
  Decision 2)**: the scanner swallows a cancel, so a stopped background scan EXPORTED and NOTIFIED
  "scan complete", and as a plain skip it would also have taken the 2-6 minute busy retry. Fixed in
  `BackgroundScanCore` (`stopped: true` skip). M82, M83 KILLED. Agent Decision 1 (Scan History now
  shows the reason on EVERY interrupted row, including user Cancel and reaper text) -- shown to Harold
  at Manual Validation. Decision 3 (v11 guard also requires the table to exist) and 4
  (`subject_rule_keyword_test` version `>= 10`) accepted.
- **Task 2 F216 -- DONE**. 8 mutations KILLED; tests read the painted `RenderParagraph` size.
  Floating label deliberately unchanged (Flutter paints it at 0.75x, so `bodyMedium` would SHRINK it
  to 10.5sp; reaching 14sp needs a literal, which ADR-0037 forbids). No Rule Review and Scan History
  title/subtitle pairs left as a hierarchy, not peers.
- **Task 5 F239 -- R-3, R-4, R-5 DONE; R-1 spike pending.** M71-M75, M79-M81, M80b KILLED.
  - R-5: `getValidAccessToken({accountId})`; real cross-account bug fixed in `folder_selection_screen`.
  - R-4: account-list "Sign In Again"; `signIn({expectedAccountId})` refuses another account before
    saving tokens.
  - R-3: `GmailSignInRequiredException` -> background SKIP (`needsSignIn`, no busy retry).
    **Development-decision change, surfaced at Manual Validation**: the Windows background worker's
    interactive sign-in fallback (it opened a browser with nobody watching) is REMOVED; a background
    scan now flags the account instead. **Known limit**: the scan row still reads `error` with the
    reason, because the claim creates it before sign-in fails and there is no `skipped` row status
    (adding one is Class 1 -- not done).
  - R-4 second surface: the scan screen offers Sign In Again when a scan failed for this reason;
    one `SignInAgain` helper serves both surfaces. M73b, M74b, M84-M86 KILLED.
  - **Three gaps found by a review of the committed work, all fixed**: (1) the Windows
    insufficient-scopes path neither flagged the account nor threw the typed exception; (2) an
    OFFLINE Windows background scan flagged a healthy account, because renewal swallows network
    errors -- the first Gmail call now fails as a connection error without entering renewal;
    (3) VERIFIED (no change): a Gmail account id is its email on both sign-in paths, so the flag,
    token lookup and expected-account check share one key -- written into ADR-0011 as an invariant.
    M87-M90 KILLED.

## Phase 5 evidence

- **5.1.1 automated code review**: 2026-10-03, `pr-review-toolkit:code-reviewer` (opus) + `pr-review-toolkit:silent-failure-hunter` (opus) on the post-approval diff (1f80ecd..d9f241b), with the mandatory related-patterns grep. No CRITICAL. Fixed in 8a1234a (mutations M96-M98, M100-M103 KILLED):
  - H-1 (both reviewers): the per-folder catch swallowed `GmailSignInRequiredException` (Windows scopes path) -- background "completed" and notified; no Sign In Again on the scan screen. Rethrown now.
  - H-2: Windows "Test Background Scan" runs IN-PROCESS; the F238 cross-process recipe was wrong. ADR-0039 + this plan corrected; Manual Validation uses `--background-scan --account-id`.
  - Same refused token handed back by renewal cleared the flag (SF-2); 429/5xx no longer read as sign-in; Android exceptions no longer flagged (M-2); renewal and connect refuse a different account (M-4, SF-4); `authorizeWithoutActivity` gated OFF until the spike (M-3); release-build warning logs for renewal failures (SF-3); scan text keeps the wrong-account detail (SF-6); stale heartbeat tick cannot cancel the next scan (M-1); locked close retried (SF-5); Sign In Again double tap (SF-9). ADR-0011 amendment rewritten -- it overstated parity.
  - Accepted / recorded, not fixed: SF-7 (Windows refresh-call outage can still flag -- ADR-0011 known limit); SF-8 (a failed flag write plus a silent skip leaves no signal -- backlog candidate: one-time notification for a needs-sign-in skip); SF-10 (token lifetime set to 1 h, pre-existing pattern); SF-11 (Windows bg log row reads `success` for a sign-in skip, per the MV74-2 skip decision); SF-12 (Android: cancelling the native picker may fall back to the browser -- unverified, pre-existing); LOW: `gmail_client.dart` and `GmailApiAdapter.signIn()` have no production callers; no cancel checkpoint after the last fetch batch (outcome still safe); a creds-less Gmail row's Start Scan fails with "No credentials" (the row itself offers Sign In Again).
- **5.1.2 F-PRECHECK** (2026-10-03, run against the sprint diff):
  1. Mirror/parallel sites: CLEAN -- sign-in skip and stopped skip live in the shared `BackgroundScanCore` (both workers); Windows-only adapter tests carry `skip: !Platform.isWindows`, classifier/humanize tests run on CI too; no `Platform.is` gate behind the new scan-screen button.
  2. Helper wired into production: CLEAN -- `SignInAgain` (account list + scan screen), `isNetworkError`/`isTransientApiError` (loadCredentials), `needsSignIn`/`stopped` (scanAccount), `requestCancel` (startRealScan). `authorizeWithoutActivity` is deliberately NOT wired (gated until the spike) -- stated in ADR-0011.
  3. Doc-comment drift: FOUND by review and fixed (ADR-0011 rules 5-7, ADR-0039 recipe).
  4. Fragile parsing: FOUND -- the new lock retry matched "database is locked" by hand although `BackgroundScanCore.isDatabaseLocked` exists (also matches code 5); switched to it. `isSignInRequiredMessage` matches a shared constant (content, not position).
  5. API scope: CLEAN -- `requestCancel`/`markScanCancelled` are per row id; the no-Activity authorization names one email (its token scope is unverified, hence gated).
  6. Silent failure: covered by the silent-failure hunter (above); every new catch logs at warning or higher.
- **5.1.5 WinWright sweep**: 2026-10-03, re-run after the MV round-3 fixes (7e807d5 changed lib/ui) on the dev build of 7e807d5: 3 scripts, 3 PASS on first attempt, 0 FAIL, DB drift none (test_f124_rule_labels, test_mt2c_no_rule_sweep, test_s75_new_controls -- the last is new this sprint, Task 7 R-1). f37/f56 excluded by the runner as documented (dialog-settle). Earlier runs at d56b557, 16d15c1 and 6c3bb81 also 3/3. Full suite at 7e807d5: 2,508 passed, 15 skipped, 0 failed.
  - **F243 side effect on the harness, found and fixed**: the first sweep at 7e807d5 FAILED mt2c twice ("Clear" resolved 0 after a checkbox tick). Background was ON for the AOL dev account, and since F243 its scans RAN with the app open every 15-20 min (21 runs from 15:45; about 115 no-rule rows each) -- one was in progress during the sweep, and the runner's per-script cleanup (stop every process of this exe) also killed background scans, orphaning rows. The runner now pauses this environment's ENABLED background tasks for the sweep and re-enables exactly those afterwards (`[WW-BG]`, verified Ready -> Disabled -> Ready). With that, mt2c passed first time. Cause of the selection loss itself: consistent with data changing under the script, not proven at widget level.
  sweep-head: 7e807d5
- **F243 native integration test**: `scripts/test-background-scan-skip.ps1` (inverted) PASS on the rebuilt exe; mutation M106 (old exit restored, rebuilt) KILLED. Full suite after F243: 2,496 passed, 15 skipped, 0 failed; analyzer clean.
- **5.2 full suite**: 2,496 passed, 15 skipped, 0 failed; `flutter analyze` clean (d56b557, run with nothing concurrent). An earlier run that overlapped the WinWright sweep lost 16 FILES at load ("Connection closed before full header was received" from flutter_tester to its local runner, starting the minute the sweep launched); those 16 files then passed alone (215 tests). Mechanism of the interference not established -- the rule taken from it: never run the suite and the sweep at the same time.
- **5.1.6 Runtime launch gate**: N/A -- no Android config touched (`android/**`, manifest, gradle, ProGuard unchanged; `pubspec.yaml` gained a Dart dependency only).

## Phase 3.6.1 Architecture Impact Check

- **ARCHITECTURE.md** -- updates REQUIRED (each card's DoD, before Manual Validation):
  - `scan_results` schema: `cancel_requested_at`, DB **v11** (Task 1).
  - The scan-lock paragraph: the stop-for-manual flow (Task 1).
  - Gmail token renewal on Android (Task 5, if the spike passes) and the "Sign In Again" path.
- **ADRs**:
  - ADR-0039: amendment for the cross-isolate cancel request (Task 1).
  - OAuth ADR amendment (or new ADR) for the Android renewal mechanism (Task 5, Class-1).
  - ADR-0042: Task 5's Android-only renewal recorded as a declared exception.
- **ARSD.md**: no requirement changes identified.
- **Schema**: one additive migration (v10 -> v11).

## Dependency watch (Phase 2 pre-kickoff, 2026-10-02)

`dart pub outdated`: unchanged from Sprint 74 -- one DISCONTINUED package, `js` 0.6.7, web-only via
`connectivity_plus` 5.0.2; no effect on Windows or Android. Task 5 adds
`google_sign_in_platform_interface` as a DIRECT dependency (already resolved transitively; no version
change).

---

## Sprint summary

| Task | Item | Model | Est (min) | Depends on |
|---|---|---|---|---|
| 0 | Version: no bump (exception) | Haiku | 5-10 | approval |
| 1 | F238 stop background for manual | Fable 5.1 (sub-agent) | 180-300 | Q1 |
| 2 | F216 supporting text size | Sonnet | 40-75 | -- |
| 3 | F214 slider alignment | Haiku | 20-40 | -- |
| 4 | F236 version in YAML export | Haiku | 20-40 | -- |
| 5 | F239 Gmail renewal + Sign In Again | Fable/Opus (Opus 5.5) | 240-480 | Q2; emulator pre-flight |
| 6 | F215 screenshot folder wiring | Haiku | 30-60 | -- |

**Total estimated**: **535-1,005 minutes (~9-17 hours)**.

**Model mix**: Haiku 4, Sonnet 1, Fable 5.1 1, Opus 1.

**Suggested order**: 0 -> {3, 4, 6 as one delegated Haiku block} -> 1 (Fable sub-agent) in parallel
with 2 (no shared files) -> 5 (spike first). Task 1 first among the large items because it is the
release blocker.

**Calibration note**: Sprint 74 planned tasks landed at or under estimate; the unplanned Manual
Validation work was most of the effort. These estimates do not include MV rework.

---

## Open questions for Harold at approval

1. **F238 (Class-1)**: approve the cross-isolate cancel request through the database -- a new
   `cancel_requested_at` column (DB v11) that the background scan checks on its 30-second heartbeat?
   - 1. Yes, as specified
   - 2. No -- discuss another mechanism first
2. **F239 (Class-1, conditional)**: if the emulator spike proves Android can renew a Gmail token
   from the background by account email with no prompt, may I build it without a further stop?
   - 1. Yes -- build it if the spike passes; stop and surface if it fails
   - 2. No -- stop after the spike either way and show me the result
3. **Phone checks timing** (carried from 10/02): the Sprint 74 phone checks plus Sprint 75's F238/F239
   need a phone build, and there is no AAB until this PR merges.
   - 1. After the Sprint 75 merge, before the 0.17.0 store submission (recommended)
   - 2. During Sprint 75 Manual Validation, with a closed-test AAB built as an exception
4. **Sprint 74 carry-ins** (WinWright scripts + widget tests for the new controls, ~105-165m):
   - 1. Add them to Sprint 75 (they cover F238's new dialog action too)
   - 2. Leave them in the backlog

## Phase 3.7 approval

**APPROVED 2026-10-03 by Harold, as amended.** Verbatim: *"Sprint plan approved as amended (with any
comments I provided), proceed with execution. All Sprint tasks and sub-tasks are approved. Do not
stop between tasks as they are all approved, please continue to complete all tasks and without
addition approvals until Manual Validation, providing your recommendation for Manual Validation
steps. Do not stop to ask questions unless meeting the criteria in \docs\SPRINT_STOPPING_CRITERIA.md
If questions must be asked, ask as late as possible - do everything that can be done (all tasks and
parts of takss, without the answer to the question(s), then ask the question(s)"*

**Amendments (Harold's answers, 2026-10-03)**:
- **Q1 -- 1**: F238's cross-isolate cancel request through the database (DB v11) APPROVED (Class-1).
- **Q2 -- 1**: F239 -- build the Android renewal if the emulator spike passes; stop and surface if it
  fails (Class-1, conditional approval).
- **Q3**: *"Can't run until 0.17.0 goes live (next sprint)"* -- the phone validation checklist moves to
  Sprint 76; Sprint 75 Manual Validation is Windows (plus the emulator for F239).
- **Q4 -- 1**: the Sprint 74 carry-ins (WinWright scripts + widget tests) are ADDED as Task 7.
