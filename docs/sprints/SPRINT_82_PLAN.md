# Sprint 82 Plan

**Status**: APPROVED 2026-10-30 (Harold: *"All Sprint tasks and sub-tasks are approved."*). Scope selected by Harold
at Phase 8.4 pass 2 (2026-10-30).
**Branch**: `feature/20261027_Sprint_82` | **PR**: draft, created at 3.3.1 (stays draft until 7.7.5)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads and one read-only
query of the DEV content history on 2026-10-30; file:line evidence is in each card.

## Objective

Get the iPhone app onto Harold's iPhone through TestFlight. Fix the highest-risk open bug (F314: the Gmail cursor
moves before the mail is evaluated). Count the evidence for two suspected defects (F312, F315) before fixing them.
Build the first No Rule suggestion (F306) on counted signals (F305). Make the No Rule list refresh when the user
comes back from a notification (F319, new). Close three process gaps (F317, F318, F320).

**Scope (Harold, 2026-10-30, verbatim)**: *"Sprint 82 Scope should include the below items. Please complete sprint
planning (/docs/sprint_planning.md) for the below items and present for approval."* The items: F67a remainder, F304
remainder, F67b remainder, F303 remainder, F314, F312 Step 1, F315 Step 1, F305 then F306, F318, F317, WinWright
coverage of No Rule Review, and: *"add to backlog for this sprint - when going from a notification to the app
(windows, android currently) it opens the "No Rules" screen, but does not refresh the screen. So while the
notification may say, "No rule 3 Deleted 2 Safe 0" the "No Rules" screens opens up with none (or whatever was there
the last time the user was on the screen if the app is still running in the background). Is there a way to trigger a
refresh on the screen so when "No rule 3 Deleted 2 Safe 0" shows in the notification the user is taken to the screen
and it shows the 3 No rule items. Noting this is per background job notification. Noting if the user manually does a
refresh via the icon, then it shows the current list of no rule items."*

Card ids assigned here: the notification refresh is **F319**; WinWright coverage of No Rule Review is **F320**.

**Parity (Harold, 2026-10-30, verbatim)**: *"everything needs to take into account the Windows App, Android app and
the iPhone app with the ADR stating that everything should be functionally and UI the same unless it cannot be - and
where it cannot be it should be implemented as a platform exception for what is needed -- this applies to all backend
code, frontend code, data, architecture, development, security, testing, deployment."* Every card has a **Parity
(ADR-0042 / ADR-0049 / ADR-0050)** line naming the Windows, Android and iOS paths. It either claims parity and names
the OS behavior assumed identical, or declares the exception and what the other platforms do instead. iOS answers
come from `PlatformCapabilities` (ADR-0049) and ADR-0050. No new bare `Platform.isX` checks (the F294 policy test
refuses them).

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control, then the instance fix.

## Phase 2 and 3 checks (2026-10-30)

- Top-tier model: Opus 5.5. DONE.
- 3.1 Sprint number: 82 (Sprint 81 merged: PR #507 -> develop `b79fa361`; develop -> main PR #520 `763753be`, tag
  `v0.22.0`). DONE.
- Phase 1 / 8.4 refinement: candidates presented 2026-10-27 in BACKLOG_REFINEMENT.md format; Harold selected 2026-10-30
  (above). DONE.
- 3.2.1 `docs/sprints/SPRINT_81_SUMMARY.md` exists; the Past Sprint Summary row for 81 exists. DONE.
- 3.2.2 this file. DONE (draft).
- 3.3 Branch `feature/20261027_Sprint_82` exists (cut from the Sprint 81 branch, carry-forward rule) and is pushed. DONE.
- 3.3.1 Draft PR: created with this plan (number recorded in `.claude/sprint_status.json`).
- 3.4 / 3.5 Cards: created at 3.7.0, the first action after approval (one per task).
- 3.6.1 Architecture Impact Check: below.
- Sprint 81 cards: #508, #511-#519 closed; #509 (F67a) and #510 (F304) stay open and carry into this sprint as the
  F67a and F304 cards (no duplicates are created at 3.7.0).
- 0.22.0 store uploads: built and verified 2026-10-27; Harold has not yet reported the uploads (open question U1).

## Tasks, order, models and estimates

Estimates are minutes. The existing cards keep the estimates Harold selected (2026-10-30). New and re-estimated
cards cite the `CODING_VELOCITY.md` Estimate Table row. `[no-history]` marks a step-type with no samples.

- **Task 0 -- Version bump 0.23.0+20** (3.7.0b). MINOR: F306 is a user-facing `feat`. Haiku. 10-15m.
- **Task 1 -- F67a remainder** (#509): Harold's console steps (Apple approval, Part B iOS OAuth client, Part C API
  key, Part D secrets); Claude walks each one and records results. Haiku (docs). ~30m + Apple's wait.
- **Task 2 -- F304 remainder** (#510): signing and the first TestFlight upload in `ios.yml`. Sonnet. 90-180m + 120m
  time-boxed signing discovery.
- **Task 3 -- F67b remainder**: the iPhone device check from the first TestFlight build. Sonnet. 60-120m.
- **Task 4 -- F303 remainder**: the Fold diagnostics line after the 0.22.0 closed-test update. Haiku. ~10m + a log pull.
- **Task 5 -- F314**: persist the Gmail history cursor only after the folder's mail is evaluated. Sonnet. 90-150m.
- **Task 6 -- Evidence probe for F312 Step 1 and F305**: a read-only header probe against the DEV AOL account, joined
  to the DEV content history by Message-ID. Sonnet. 45-75m (re-estimated, see 3.2.2.2).
- **Task 7 -- F315 Step 1**: total the per-scan no-UID count from the DEV and phone diagnostic logs. Haiku. ~30m.
- **Task 8 -- F306**: the suggested rule in the No Rule Item pop-up, on the basis Task 6 counts. Sonnet. 180-300m.
- **Task 9 -- F319 (new)**: the No Rule list reloads when the app returns to the foreground. Sonnet. 45-90m.
- **Task 10 -- F320 (new)**: WinWright coverage of No Rule Review. Sonnet. 30-60m + WINWRIGHT-DISCOVERY time-box 60m.
- **Task 11 -- F318**: the 7.7.1 toolkit prompt lists every changed file. Haiku. ~15m.
- **Task 12 -- F317**: keep delegated agent work safe across usage limits. Sonnet. 120-240m (unverified).
- **Conditional (asked first, not in the total)**: F312 Step 2 fix 60-120m, only if Task 6 finds a lower header whose
  verdict differs; F315 Step 2 design, only if Task 7 finds a message with no UID (Class 1, asked before code).
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 150-250m.

**Total**: Tasks 0-12 about 760-1,385 minutes, plus the 150-250 allowance, plus Harold's console and phone time and
Apple's wait.

**When can Harold come back (first Manual Validation handoff)**: about 6-9 hours of wall-clock after approval if run
serially. Tasks 5, 9, 11 and 6 touch different files and run as parallel sub-agents, which brings the first handoff
to about 4-6 hours. The iOS tasks (2, 3) wait for Apple's approval email and Harold's Parts B-D; they do not block
the rest.

**Order**:
1. 3.7.0 cards (F67a #509 and F304 #510 reused), 3.7.0b version bump, 3.7.1 PR body.
2. Task 1: whatever Apple and Google steps Harold can do next (Part B does not need Apple).
3. Parallel block (sub-agents, different files): Task 5 F314, Task 9 F319, Task 11 F318, Task 6 probe.
4. Task 6 results -> the Q4 decision (F306 basis), asked the moment the counts exist (a blocked-implementation
   decision, surfaced before Task 8 code). Task 8 F306 parts that do not depend on the basis (the Block Body cell,
   the highlight, storage) start in parallel.
5. Task 7 and Task 4 when the logs are pulled (Task 4 needs the 0.22.0 closed-test update on the Fold).
6. Task 12 F317 after Q5 (the requirement echo); Task 10 F320 after Task 8 (it covers the new pop-up too).
7. Task 2 once the Team ID, API key and secrets exist; Task 3 on Harold's iPhone once TestFlight has a build.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b)): Tasks 5, 6, 9 and
11 are delegated to sub-agents on their assigned tier before Manual Validation, with the delegation checklist
verbatim. Anything run in the main session executes on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand on the draft + pr-review-toolkit code-reviewer and
silent-failure-hunter), started with the retrospective prompt at Manual Validation complete. From this sprint the
toolkit prompt carries the changed-file list (Task 11).

**Cards**: created at Phase 3.7.0. One "Closes #N" per card in the PR body.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md` Standing Approval Inventory),
so they are not asked again: (a) Task 0 the version bump; (b) Task 2 edits to `.github/workflows/ios.yml` (shared CI
infrastructure) and the use of the repository secrets Harold creates; (c) Task 8 the database migration v16 -> v17
(backs up the dev DB first; no sqlite downgrade); (d) Task 12 and Task 11 changes under `.claude/` and their hook
tests (`.claude\hooks\run-test-cases.ps1` after any hook change); (e) Task 6 read-only IMAP access to the DEV AOL
account (EXAMINE, headers only, nothing written to the mailbox, counts only kept). Not covered, still asked: any
dependency version change, any edit to `secrets.*.json`.

## Phase 3.2.2.1 branch-state verification (summary)

- **F67a (#509)**: Part A paid 2026-10-28 on the web (Enrollment ID `R6QG2A9SHS`, recorded in `docs/IOS_SETUP.md`);
  approval not yet reported; Team ID unknown. Parts B-D not started. Part B does not need Apple.
- **F304 (#510)**: `ios.yml` builds with `--no-codesign` only (`.github/workflows/ios.yml:43-44`); no signing or
  upload step exists. Confirmed open.
- **F67b**: code done Sprint 81 (#511). Finding for the device check: `ScanCompleteNotifier._pluginShow`
  (`scan_complete_notifier.dart:182-191`) initializes the plugin with Android and Windows settings only, no Darwin
  settings. Background notifications on iOS belong to F67c (not in scope); Task 3 records what iOS does for the
  notification-permission check and does not change it.
- **F303**: code done Sprint 81 (5b87e362). Only the Fold check remains; it needs the 0.22.0 closed-test build on
  the Fold.
- **F314: confirmed.** Cursor read at `email_scanner.dart:1825`; written inside the fetch step at `:1846` (full
  fetch), `:1869` (cleared on expiry), `:1876` (after expiry), `:1884` (incremental). All five calls are in
  `_fetchFolderMessagesGmail` (`:1814-1890`); the setter is `database_helper.dart:1559`. Since F259 (Sprint 81) the
  cursor is per account and folder.
- **F312: confirmed, master-plan location corrected.** Last-wins header maps: `generic_imap_adapter.dart:2432`
  (`headersMap[header.name] = ...`, master plan said 2418-2419) and the LIVE Gmail path
  `gmail_api_adapter.dart:1330` (map literal `for (var header in headers) header.name ?? '': ...`). The master
  plan named `gmail_client.dart:284`; `GmailClient` has no caller outside its own file, so that path is likely dead
  code (recorded, not changed). **The content history stores no header count** (`content_history_store.dart:130-155`
  holds `auth_class` only), so Step 1 cannot be counted from the database: Task 6 is the method.
- **F315: confirmed.** Marker `kNoValidImapUid` (`imap_uid.dart:18`); per-scan count written by
  `generic_imap_adapter.dart:1745-1750`. Step 1 reads logs only.
- **F305: R-1 is not needed.** DEV content history (read-only query, 2026-10-30): 1,548 emails (delete 644, no_rule
  252, safe_sender 652); 1,534 carry a Message-ID; No Rule rows by account: AOL 245, Gmail 6, iCloud 1. Stored per
  row: `auth_class`, `list_unsubscribe`, `reply_to`. No Rule rows by (auth, unsubscribe, reply-to present): green
  216, yellow 35, red 1. `List-Id` and `Precedence` are NOT stored; Task 6 reads them from the probe. Harold's own
  decisions in the history: 69 (block:entireDomain 24, block:from 3, safe_sender:exact 34, safe_sender:exactDomain
  8). These 69 are the labeled set Task 6 and F313 use.
- **F306: confirmed open.** `email_detail_popup.dart:741-753` holds the Email / Exact Domain / Entire Domain row; no
  suggestion exists. DB schema is v16 (`database_helper.dart:94`); Task 8 is v17.
- **F318: confirmed open.** `SPRINT_EXECUTION_WORKFLOW.md` has no `name-only` instruction; the prompt text lives at
  `:1124-1128` and `:1327-1356`.
- **F317: confirmed open.** No `scripts/agent-work-status.ps1`; no "Progress and restart" text in `docs/` or
  `.claude/`.
- **F320: confirmed open.** No default WinWright script opens No Rule Review. The earlier scripts were retired
  (`test/winwright/README.md:102-108`: display-size dependence, real mouse, a seed script). Their contract stays in
  `test/ui/screens/no_rule_review_screen_test.dart`.
- **F319 (new): cause found.** See the card.

**Phase 3.2.2.2 (re-estimates)**: F305 drops R-1 (the DEV log line) because the content history already holds most
signals; F312 Step 1 needs a probe because no header count is stored. Both merge into Task 6: 30m (F312) + 60-90m
(F305) -> 45-75m. F67b 180-300m -> 60-120m (code done Sprint 81). F67a 45-90m -> ~30m (walkthroughs done).

## Phase 3.6.1 Architecture Impact Check

- **ADR-0050 / ADR-0049**: no new iOS exception. F319 uses the existing lifecycle model on all three platforms
  (parity claimed, OS behavior named in the card).
- **ADR-0047 (content history, DEV only)**: Task 6 reads it; no schema change.
- **Data model**: Task 8 adds the stored suggestion to the No Rule row (v17, Class 2, Q2). ARCHITECTURE.md and the
  data-model section gain it in the same commit.
- **F314** changes WHEN a stored value is written (Class 2, Q1); ARCHITECTURE.md's scan-flow text for the Gmail
  cursor is updated.
- **F312** (only if Step 2 runs): which header the auth verdict reads; ADR not needed, ARCHITECTURE.md auth section
  updated.
- **F315 Step 2** (only if the count is above zero): Class 1 (what the cursor means); asked before code.
- **F304**: ARCHITECTURE.md iOS build path gains signing and TestFlight upload.
- **F317 / F318**: process docs only (`SPRINT_EXECUTION_WORKFLOW.md`, scripts, hook tests).
- No ADR conflicts found.

## Phase 3.7 answers (Harold, 2026-10-30)

Verbatim: *"q1. 1 q2 1 q3 1 q4 2 (try this and see how it goes) q5 1 q6 1 q-s1 1 q-s2 1 u1 no plan to upload 0.22.0
and will wait for 0.23.0 is complete (noting that the release notes will nee to be combined release notes for 0.22
and 0.23.0"* and *"All Sprint tasks and sub-tasks are approved. Do not stop between tasks as they are all approved,
please continue to complete all tasks and without addition approvals until Manual Validation, providing your
recommendation for Manual Validation steps. Do not stop to ask questions unless meeting the criteria in
\docs\SPRINT_STOPPING_CRITERIA.md If questions must be asked, ask as late as possible - do everything that can be
done (all tasks and parts of tasks, without the answer to the question(s), then ask the question(s)"*.

- **Q1 = 1**: F314 saves the cursor per folder after evaluation; a part-way folder keeps the old cursor.
- **Q2 = 1**: F306 stores one suggestion per No Rule row (v17); body rules keep the regex only.
- **Q3 = 1**: Task 6 read-only header probe on the DEV AOL account.
- **Q4 = 2** ("try this and see how it goes"): the F306 basis is chosen by the fixed rule (a signal is used only
  when it fires on at least 10 percent of No Rule rows and agrees with at least 80 percent of the 69 decisions); the
  result is reported, no mid-sprint question.
- **Q5 = 1**: the F317 requirement echo is confirmed.
- **Q6 = 1**: F319 reloads on every return to the foreground, all accounts, all three platforms.
- **Q-S1 = 1, Q-S2 = 1**: models as assigned; version 0.23.0+20.
- **U1**: 0.22.0 will NOT be uploaded. The next store release is 0.23.0, and its release notes combine 0.22.0 and
  0.23.0 (Task 0 R-2). Consequence for Task 4 (F303 Fold check): it needs a 0.23.0 closed-test build on the Fold, so
  it moves to Manual Validation (a 0.23.0 AAB for closed testing is built at 5.3).
- **F312 Step 2 and F315 Step 2**: still asked only if their counts are above zero, as late as possible.

## Decision questions as asked (answered above)

**Q1. F314 (Class 2): when the Gmail history cursor is saved.** This would change a prior development decision:
today the scanner saves the new historyId during the FETCH (`email_scanner.dart:1846, 1876, 1884`). If the scan is
cancelled, fails or the app is killed after the fetch, the next scan starts after those messages and they are never
evaluated (no rule runs, no No Rule row is written). What the user sees today: nothing; the mail simply stays
unprocessed.
1. Hold the new cursor in memory per folder; save it only after that folder's messages are evaluated (and acted on in
   a live mode). A folder cancelled part way keeps the OLD cursor, so the next scan re-reads the whole delta
   (recommended; re-reading is expected to be safe because of the F203 already-filed check and the No Rule upsert,
   which the card verifies first as R-1).
2. Same as 1, but a folder cancelled part way saves a cursor up to the last evaluated message (smaller re-read; Gmail
   history IDs are per change, not per message, so this needs a design read first; more code).
3. Keep the save during the fetch, and add a "fetched but not evaluated" record that the next scan finishes first
   (more state; a second mechanism beside the cursor).
4. Backlog it.

**Q2. F306 (Class 2): store the suggestion on the No Rule row.** This would change a prior development decision: the
No Rule row today stores the auth verdict and F271 reason codes, not a rule. Your design says the suggestion is made
at scan time, so it must be stored for the pop-up to show it later.
1. Store one suggestion per No Rule row in new columns (v17): kind (safe or block), type (email, exact domain, entire
   domain, subject, body), the exact regex, and a reason code. Body suggestions keep only the computed regex, never
   body text (SEC-14) (recommended).
2. Compute the suggestion when the pop-up opens (nothing stored; differs from your "at scan time" design; body rules
   would fetch the body then).
3. Store header-based suggestions only (email and domain types) in v1; subject and body suggestions go to a later
   sprint.

**Q3. Task 6 method: a read-only header probe.** The F312 count needs every Authentication-Results header of each
email, and nothing stores them. The probe opens the DEV AOL account read-only (IMAP EXAMINE, headers only, no flags
or moves), reads the headers of the emails already in the DEV content history (matched by Message-ID), keeps counts
only, and stores no header text or address. AOL holds 1,468 of the 1,548 content-history emails.
1. Approve the probe on the DEV AOL account (recommended).
2. Approve it on AOL and on the Gmail account through the Gmail API (more setup; Gmail has 76 rows).
3. No probe: add a DEV-only diagnostic line to scans and count over the sprint (slower: the Windows DEV build has
   background scans off, so it fills only from manual scans).

**Q4. F306 basis: when to decide it.** F305's design point "what is the basis for a suggestion" is answered by Task
6's counts (which signals fire on No Rule mail and how often on your 69 decisions).
1. I ask it as one numbered question the moment Task 6's counts exist, with the counts in the question; Task 8 code
   that does not depend on it proceeds meanwhile (recommended).
2. I choose the basis by a rule set now (a signal is used only when it fires on at least 10 percent of No Rule rows
   and agrees with at least 80 percent of your 69 decisions) and report the result; no mid-sprint question.

**Q5. F317 requirement echo (the card requires confirmation before more than one file is touched).** My one-sentence
reading: every agent the sprint process launches writes its progress to files as it works and reads them on start,
so a stop at a usage limit loses nothing and a restart skips finished work; an hourly wake-up resumes any stopped
agent; and no resumed agent ever repeats a release or store action.
1. That is right.
2. Not quite (say what differs).

**Q6. F319: what a notification tap does.** Today a tap brings the app forward on the screen it was on; the No Rule
list is not reloaded (cause in the card).
1. The No Rule list reloads every time the app comes back to the foreground, on Windows, Android and iOS, for all
   accounts (the list you get from the refresh icon, without its message). One small change, full parity
   (recommended).
2. Option 1, plus a notification tap OPENS No Rule Review filtered to that notification's account. Android and iOS
   can carry the account in the notification; on Windows the tap starts a second process that hands focus to the
   running app and exits (`windows/runner/main.cpp:118-130`), so passing the account needs a new hand-off (a
   declared Windows exception, about +90-150m, and unverified until probed).
3. Option 1 now; option 2's account filter to the backlog.

**Q-S1. Models as assigned**: 1 approve.
**Q-S2. Version 0.23.0+20** (MINOR, F306 is a `feat`): 1 approve.

---

# Cards

## Task 0 -- Version bump 0.23.0+20 (3.7.0b)

**Value**: This lets a tester tell the Sprint 82 dev build from the 0.22.0 store builds.

**Requirements**:
- R-1: `pubspec.yaml` `version: 0.23.0+20`, `msix_config.msix_version: 0.23.0.0`.
- R-2: Same commit: provisional `RELEASE_NOTES_0.23.0_windows.md` and `_play.md` that COMBINE 0.22.0 and 0.23.0
  (U1: 0.22.0 is never uploaded); the Dev row in `STORE_VERSION_STATUS.md` -> 0.23.0+20; the 0.22.0 section marked
  "not submitted, superseded by 0.23.0 (Harold 2026-10-30)"; "Last uploaded to Play" stays 0.21.0 (versionCode 18).
- R-3: iOS takes the same version and build number (ADR-0043).

**Affected components / files**: `mobile-app/pubspec.yaml`, `docs/STORE_VERSION_STATUS.md`, `docs/store-assets/`.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: one version on Windows, Android and iOS.

**Dependencies / blockers**: plan approval.

**Acceptance criteria**: AC-1: `version_consistency_test`, `dev_version_ahead_test`, `release_notes_test` pass.

**Tests to write**: none new; T-1 (AC-1) runs the three gates.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: 10-15m.

## Task 1 -- F67a remainder: iOS prerequisites (#509, Priority 2)

**Value**: This unblocks the signed build (Task 2) and the device check (Task 3).

**Requirements**:
- R-1: Part A: Harold reports Apple's approval email; Claude records the dates, the Team ID and the seller name from
  Membership details in `docs/IOS_SETUP.md` "Results" and the seller name in `docs/LEGAL_ENTITY.md`. If no
  confirmation arrives within 24 hours of payment, Harold contacts Apple Developer Support with Enrollment ID
  `R6QG2A9SHS` (Apple's instruction, program-enrollment page read 2026-10-28).
- R-2: Part B (does not need Apple): the iOS OAuth client in Google Cloud Console, bundle ID `com.myemailspamfilter`;
  record the date and the restricted-scope status shown.
- R-3: Part C: the App Store Connect API key (after approval); record the date and the role.
- R-4: Part D: the six GitHub secrets; record the date. Claude never sees values.
- R-5: Each step is re-presented in full when Harold is asked to do it (re-present rule), and each external claim is
  checked on the vendor page the same day or marked unverified.

**Affected components / files**: `docs/IOS_SETUP.md`, `docs/LEGAL_ENTITY.md`, this plan.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: iOS only (store account and OAuth client). Windows and Android have
theirs (Partner Center, Play Console, their OAuth clients). A declared deployment exception of the same kind as
MSIX versus AAB.

**Dependencies / blockers**: Apple's approval; Harold's console time.

**Acceptance criteria**:
- AC-1: Apple approval, Team ID and seller name recorded.
- AC-2: the iOS OAuth client exists and its status is recorded.
- AC-3: the API key exists and the six secrets are set (date recorded).

**Tests to write**: none (external setup). T-1 (AC-1 to AC-3): `gh secret list` shows the six names (names only).

**Definition of Done**: default DoD plus: no secret value in any committed file.

**Model**: Haiku -- docs. **Step-types**: DOCS. **Est-Effort**: ~30m + Harold's time + Apple's wait.

_**Risk & rollback**_: Apple may not confirm; the support contact is the only path (forum reports). Nothing to roll
back.

## Task 2 -- F304 remainder: signing and the first TestFlight upload (#510, Priority 4)

**Value**: This gives the project a Mac it does not own: one command builds, signs and uploads an iOS build.

**Requirements**:
- R-1: Extend `.github/workflows/ios.yml` (`workflow_dispatch` only, `macos-26`, Flutter from `.fvmrc`) with signing
  by App Store Connect API key and Xcode automatic signing (`-allowProvisioningUpdates` with the key). No certificate,
  profile or key in the tree or in logs.
- R-2: The iOS Gmail client ID and reversed client ID come from repository secrets into a dart-define file written in
  the job and deleted in an `always()` step, the same way Windows and Android read theirs at build time.
- R-3: The job uploads the IPA to TestFlight, prints the build number, and keeps the IPA as a 7-day job artifact.
- R-4: After the first run, record the runner minutes GitHub billed (settles whether macOS minutes are free on this
  public repository, UNVERIFIED today).

**Affected components / files**: `.github/workflows/ios.yml`, `docs/IOS_SETUP.md`, `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: `ios.yml` (Sprint 81 unsigned job) and `flutter_version_sync_test` (already reads
`ios.yml`).

**Callers of any guard being changed**: none; `ci.yml` is not changed.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: iOS build path only; Windows (MSIX, Partner Center) and Android (AAB,
Play) keep theirs. Declared deployment exception.

**Dependencies / blockers**: Task 1 (Team ID, API key, secrets).

**Non-functional requirements**: Security: no signing material, key or client ID in the tree or logs.

**Acceptance criteria**:
- AC-1: `gh workflow run ios.yml --ref <branch>` is green and a build appears in TestFlight.
- AC-2: Harold installs it on his iPhone through TestFlight internal testing and the app opens.

**Tests to write**: T-1 (AC-1, AC-2): the workflow run and the install (manual, recorded).

**Definition of Done**: default DoD plus: AC-2 observed on Harold's iPhone.

**Model**: Sonnet -- *why not Haiku*: Apple signing in CI, multi-step, no project history.
**Step-types**: CI [no-history], DOCS. **Est-Effort**: 90-180m + 120m time-boxed signing discovery.

_**Risk & rollback**_: signing may loop; at 120m the time-box ends and Harold decides (rented Mac with Xcode, or a
second time-box). Rollback: revert the job steps; the unsigned job stays.

## Task 3 -- F67b remainder: iPhone device check (Priority 6)

**Value**: This proves the shared app runs on iPhone with the same functions and screens as Windows and Android.

**Requirements**:
- R-1: On the first TestFlight build, on Harold's iPhone (iOS 27.1): smoke test, IMAP scan (the iCloud test account),
  Gmail sign-in, rules, Review No Rule Items, Scan History, export to Files, notification permission. Each step
  names the screen and the exact item to find.
- R-2: Each step is rehearsed where it can be (5.1.9: widget tests for screens; the iOS-only steps are marked as not
  rehearsable on Windows).
- R-3: Any difference from Windows/Android is either fixed (if under the 7.7.1 size limit) or recorded as a declared
  exception or a backlog card with its evidence (screenshot over MTP or iPhone screenshot sent by Harold).
- R-4: Record what iOS shows for the notification permission (finding: `scan_complete_notifier.dart:182-191` has no
  Darwin settings; background notifications are F67c).

**Affected components / files**: this plan (results); code only if a fix is found.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: this task IS the parity check for iOS; the comparison baseline is the
0.23.0 Windows DEV build and the Android closed test.

**Dependencies / blockers**: Task 2 (a TestFlight build).

**Acceptance criteria**: AC-1: every R-1 step recorded PASS, or FAIL with evidence and a disposition.

**Tests to write**: none planned; a fix adds its own test.

**Definition of Done**: default DoD plus: results recorded per step.

**Model**: Sonnet -- *why not Haiku*: diagnosing a platform difference needs judgment across three platforms.
**Step-types**: MANUAL, DOCS. **Est-Effort**: 60-120m + Harold's phone time.

## Task 4 -- F303 remainder: Fold diagnostics line (Priority 18)

**Value**: This confirms the Sprint 81 fix reaches a real phone, where adb is blocked.

**Requirements**:
- R-1: After the 0.22.0 closed-test update on the Fold, pull the diagnostic log over MTP
  (`scripts/pull-phone-screenshots.ps1` family, MTP only). The `[new-mail-diagnostics]` line lists every field with
  no `error:` text. Read the first start after the update AND a later start (Sprint 80 retro IMP-5).

**Affected components / files**: this plan (result).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Android only. The new-mail trigger exists only on Android
(`PlatformCapabilities.hasNewMailNotificationTrigger`); Windows and iOS have no such line. Declared platform behavior
per ADR-0049.

**Dependencies / blockers**: the 0.22.0 AAB uploaded to Play closed testing and installed on the Fold (U1).

**Acceptance criteria**: AC-1: both log lines quoted in this plan; no `error:` field.

**Tests to write**: none (code tested in Sprint 81).

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: MANUAL. **Est-Effort**: ~10m + a log pull.

## Task 5 -- F314: save the Gmail history cursor only after the mail is evaluated (Priority 30)

**Value**: This prevents a cancelled or killed scan from skipping mail forever.

**Requirements**:
- R-1 (audit first): verify that re-evaluating the same delta is safe: the F203 already-filed check and the No Rule
  upsert make a second evaluation of the same message produce no duplicate row and no second action. Cite file:line.
  If either is not safe, stop and surface (Class 2).
- R-2: per Q1, `_fetchFolderMessagesGmail` returns the new historyId instead of saving it; the scan loop saves it
  for that folder only after the folder's messages are evaluated (and acted on in a live mode). A folder that is
  cancelled or fails keeps the old cursor.
- R-3: the expiry path (`:1869` clears, `:1876` re-captures) follows the same rule: clearing is safe at once (it forces
  a full fetch); the re-captured value waits for evaluation.
- R-4 (prevention): a test that fails if any `setGmailHistoryCursor` call runs before evaluation, extending the
  existing scanner test file rather than a new gate.

**Affected components / files**: `lib/core/services/email_scanner.dart:1814-1890` and the per-folder loop that calls
it; `test/unit/` scanner tests; `docs/ARCHITECTURE.md` (Gmail cursor timing).

**Existing behavior relied on**: per-folder cursor since F259 (`email_scanner.dart:1825`, `database_helper.dart:1549-1559`).

**Callers of any guard being changed**: every `setGmailHistoryCursor` call (`email_scanner.dart:1846, 1869, 1876,
1884`, all in one method) and every reader (`:1825`); the manual scan, the Android WorkManager scan and the Windows
background worker all reach this method through `EmailScanner.scanInbox` (verify at card time and list each).
- Catches between the new deferred save and its handler: list every `catch` in the per-folder loop and say whether
  a caught error skips the save (it must).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart; the same scanner runs on Windows, Android and iOS. Parity
claimed: the change depends on no OS behavior.

**Dependencies / blockers**: Q1.

**Acceptance criteria**:
- AC-1: a scan cancelled after the fetch and before evaluation leaves the stored historyId unchanged; the next scan
  evaluates the same messages. Mutation-verified.
- AC-2: a completed scan saves the new historyId per folder (no regression).

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: fake Gmail adapter, cancel after fetch, assert cursor unchanged and messages re-offered.
  What this does NOT catch: a kill of the process between evaluation and save (re-read is the designed outcome).
- T-2 (AC-2) -- TEST-UNIT: completed scan saves per folder.

**Definition of Done**: default DoD plus: the delegation checklist in the sub-agent prompt.

**Model**: Sonnet -- *why not Haiku*: changes when a stored value is written across a multi-step scan, with callers
on three entry paths. **Delegation checklist included**: yes.
**Step-types**: SVC-EDIT, TEST-UNIT. **Est-Effort**: 90-150m.

_**Decision-class interrupts**_: Class 2 (Q1).

**Result (Phase 4)**: done (Sonnet). The new historyId is held per folder and saved after `completeScan` stores the
scan's results, not right after the folder's evaluation: actions run after all folders and the No Rule rows are
written only inside `completeScan`, so an earlier save would still lose a folder's results if the app died before
it. This keeps Q1 = 1 (a folder cancelled part way keeps its old cursor) and is stricter. The expiry clear stays
immediate. Tests: `f259_gmail_label_cursor_test.dart` group F314, 15 of 15; mutation 5 of 5 KILLED (save in the
incremental fetch, save in the full fetch, save before `completeScan`, folder marked before evaluation, never
saved). Not caught: a kill between `completeScan` and the save (the next scan re-reads, by design); a
`completeScan` whose own persistence failed silently (`email_scan_provider.dart:664`, unchanged, cursor still moves).

## Task 6 -- Evidence probe: F312 Step 1 and F305 counts

**Value**: This decides two cards from data: whether the auth parser can be fooled on real mail (F312), and which
signals a No Rule suggestion can be built on (F305 -> F306).

**Requirements**:
- R-1: a scratch probe (session scratchpad or gitignored `test/scratch/`, never the tree) opens the DEV AOL account
  read-only (IMAP EXAMINE, headers only, `BODY.PEEK[HEADER]`), credentials from `secrets.dev.json` read in memory,
  nothing written to the mailbox. Per Q3.
- R-2: for each email in the DEV content history (matched by Message-ID), count: Authentication-Results headers; for
  two or more, whether a lower header's dmarc verdict differs from the top one; and the authserv-id of each.
- R-3 (F305): per outcome (no_rule, delete, safe_sender) and for Harold's 69 decisions, count which signals fire:
  auth class, List-Unsubscribe, Reply-To present and Reply-To domain different from From domain, List-Id, Precedence
  bulk/list, and the blocked-TLD match.
- R-4: keep counts only; no header text, address or subject in any output or file (SEC-14).
- R-5: record the counts in this plan (Task 6 results). If F312's differing count is zero, close F312 with the
  counts as evidence. If above zero, ask the F312 Step 2 question (options listed below). Then ask Q4's basis
  question if Q4 = 1.

**F312 Step 2 options (asked only if the differing count is above zero)**:
1. Read the TOP Authentication-Results header and accept it only when its authserv-id is the account's provider;
   otherwise show grey (master-plan fix direction; 60-120m).
2. Read the top header only, no authserv-id check (smaller; still trusts a planted header if the provider adds none).
3. Backlog with the counts.

**Affected components / files**: scratch only; this plan.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: a Windows DEV analysis tool; it changes no app code. The parser it
measures is shared Dart on all three platforms.

**Dependencies / blockers**: Q3.

**Acceptance criteria**:
- AC-1: counts recorded for R-2 and R-3, with the number of content-history emails matched and not matched.
- AC-2: no header text or address in any output.

**Tests to write**: none (analysis); the probe prints its match rate so a silent zero is visible.

**Definition of Done**: None -- default DoD only (no CHANGELOG line; no app change).

**Model**: Sonnet -- *why not Haiku*: IMAP read-only safety and RFC 8601 parsing need care.
**Step-types**: DATA, IMAP. **Est-Effort**: 45-75m.

_**Risk & rollback**_: a wrong IMAP command could set the Seen flag; EXAMINE and BODY.PEEK prevent that, and the
probe asserts EXAMINE before the first fetch.

### Task 6 results (2026-10-30)

**F305 counts (DEV content history, read-only; script `scratchpad/task6/f305_signals.py`)**: 1,551 rows; 254 No
Rule; 69 decisions by Harold (safe 42: exact 34, exact domain 8; block 27: entire domain 24, email 3). History signals
use only rows seen earlier (time split, F313 R-2).

- auth yellow -> block: fires on 35 of 254 No Rule rows (14%); agrees with 5 of 6 decisions (83%). **PASS**.
- auth green -> safe: 217 (85%); 41 of 63 (65%). fail (agreement).
- auth red -> block: 2 (1%); 0 decisions. fail (rate). (A RED email is never suggested safe regardless, R-5.)
- Reply-To differs -> block: 26 (10%); 7 of 9 (78%). fail (agreement, near miss).
- unsubscribe present -> block: 145 (57%); 11 of 19 (58%). fail.
- unsubscribe absent -> safe: 109 (43%); 34 of 50 (68%). fail.
- free-mail sender -> safe: 7 (3%); 8 of 10 (80%). fail (rate).
- domain made safe before -> safe: 24 (9%); 12 of 12 (100%). fail (rate, near miss).
- sender made safe before -> safe: 18 (7%); 11 of 11 (100%). fail (rate).
- domain deleted before -> block: 21 (8%); 2 of 3 (67%). fail.

**Q4 = 2 result**: one signal passes, auth yellow -> block. It gives a suggestion on 35 of 254 No Rule rows (14%),
with no conflicts. The rule type follows Harold's decisions: block -> Block Entire Domain (24 of 27), or Block Email
for a free-mail domain (`gmail.com`, `aol.com` and similar, where blocking the domain blocks everyone). Caveats:
5 of 6 is a small sample; the history signals use the content history, which exists only in DEV builds (ADR-0047),
so a shipped build could not use them even if they passed. Signal "Signal fires on" line for Task 8: **fires on 35
of 254 No Rule rows; agrees with 5 of 6 decisions.** The basis is a list in code, so a change of basis is a one-line
change (reported at Manual Validation, per "try this and see how it goes").

**F312 Step 1**: NOT RUN. The approved probe method (Q3 = 1) assumed AOL credentials in `secrets.dev.json`; that file
holds only the Gmail client IDs, and the AOL app password is only in the DEV app's encrypted Windows secure store.
Reading it from a script would extract a stored password, which was not approved. Asked at the end of execution
(late question).

## Task 7 -- F315 Step 1: count IMAP messages with no UID (Priority 32)

**Value**: This decides from data whether a date cursor is needed.

**Requirements**:
- R-1: total the per-scan no-UID diagnostic count (`generic_imap_adapter.dart:1745-1750`) from the DEV diagnostic
  logs and the phone logs pulled over MTP, per account and folder, across the sprint.
- R-2: record the totals here. Zero: close F315 with the counts. Above zero: ask the Step 2 question (Class 1) with
  these options: 1 design a date cursor beside the UID (stored oldest No Rule date, search SINCE); 2 show the message
  on Review No Rule Items without a cursor (no move or delete); 3 backlog.

**Affected components / files**: this plan.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared IMAP adapter on all three platforms; the logs come from Windows
DEV and the Android phones (iOS has no build yet).

**Dependencies / blockers**: logs from the sprint's scans.

**Acceptance criteria**: AC-1: totals per account and folder recorded, with the log files and date range read.

**Tests to write**: none.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DATA. **Est-Effort**: ~30m.

### Task 7 results (interim, 2026-10-30)

- DEV diagnostic logs `Documents\MyEmailSpamFilter_Dev\diagnostics_Dev\` (5 files, 2026-10-26 00:00 to 2026-10-30
  09:22, with gaps where a file rotated to `.bak` and was not kept): 1,171 `scan/persist` lines (AOL IMAP 680, Gmail
  491). Lines "message has no valid IMAP UID" (`imap_uid.dart:62`) or "FETCH answer had no UID"
  (`generic_imap_adapter.dart:2453`): **0**.
- Phone logs (Fold, S24+) over MTP: pulled at Manual Validation and added here. If they also show 0, F315 closes
  with these counts.

## Task 8 -- F306: suggested rule in the No Rule Item pop-up (Priority 34)

**Value**: This tells the user, for each No Rule email, the one rule most likely right, with its regex and why; the
user still decides.

**Requirements** (Harold's design, 2026-10-25, quoted in the master plan):
- R-1: at scan time, when the No Rule outcome is decided (manual and background scans), compute at most ONE
  suggestion: a safe sender (Exact Email, Exact Domain, Entire Domain) or a block rule (Block Email, Block Exact
  Domain, Block Entire Domain, Block Subject, Block Body or body URL), on the basis decided by Q4. Store it per Q2.
- R-2: the pop-up highlights the suggested button (colored, shaded or bold border) and shows the exact regex and a
  one-sentence reason next to it. The user still taps to apply; a suggestion never acts on mail.
- R-3: a new Block Body button shares the row Block Subject uses today (two half-width cells).
- R-4: the rule is saved through the existing quick actions, so the same Safe Sender Folder and Deleted Rule Folder
  apply.
- R-5: every suggestion reads the receiving provider's DMARC result; a RED email is never suggested as a safe sender.
- R-6: the regex follows `docs/RULE_FORMAT.md` and the existing quick-action builders (no hand-built patterns).

**Affected components / files**: `lib/ui/widgets/email_detail_popup.dart` (`:741-753` row, the Block Subject row);
`lib/core/storage/unmatched_email_store.dart` and `database_helper.dart` (v17); the scanner where No Rule rows are
written; `lib/core/services/heuristic_signals.dart` (basis); `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: the quick-action pattern builders used by the pop-up buttons, and
`heuristic_signals.dart` (F271) -- named at card time; no new pattern builder.

**User-reachable control**: Review No Rule Items > tap an email > the pop-up shows the highlighted button with the
regex and reason; tapping it saves the rule.

**Signal fires on**: auth YELLOW -> block: fires on 35 of 254 No Rule rows (14 percent); agrees with 5 of 6 of the
69 decisions that touched it (83 percent). The only signal that meets the Q4 rule (Task 6 results). The card's 252
was the planning-time count; Task 6 counted 254.

**Observable behavior -- before / after**: BEFORE: the pop-up shows the buttons with no hint which one fits; there
is no Block Body button. AFTER: one button carries a highlighted border, and under it the exact rule and one
sentence of reason; Block Subject and Block Body share one row.

**Dependencies / blockers**: Q2, Q4, Task 6.

**Non-functional requirements**:
- Accessibility: the highlight is not color alone (border weight plus the text "Suggested"); semantics label names
  the suggestion (ADR-0037).
- Security: no body text stored (SEC-14).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart UI and data on Windows, Android and iOS. Parity claimed:
same pop-up widget on all three; the half-width row is checked at phone width (Android, iOS) and desktop width.

**Acceptance criteria**:
- AC-1: for a fixture No Rule row with a stored suggestion, the pop-up shows the highlighted button, the regex and
  the reason.
- AC-2: tapping the suggested button saves exactly the shown rule through the existing quick action.
- AC-3: a RED-auth fixture never gets a safe-sender suggestion. Mutation-verified.
- AC-4: Given a phone-width screen, When the pop-up opens, Then Block Subject and Block Body sit in one row with no
  clipping.
- AC-5: migration v16 -> v17 keeps every existing row; a dev DB copy is migrated in rehearsal.

**Tests to write**:
- T-1 (AC-1, AC-4) -- TEST-WIDGET `test/ui/widgets/email_detail_popup_suggestion_test.dart` (new; the existing
  pop-up tests are `test/ui/widgets/sprint78_mv_popup_style_test.dart` and
  `test/ui/screens/results_display_popup_width_test.dart`, whose width harness it reuses).
- T-2 (AC-2) -- TEST-WIDGET: tap saves the shown pattern.
- T-3 (AC-3) -- TEST-UNIT on the suggestion function.
- T-4 (AC-5) -- TEST-UNIT migration test (extend the existing migration tests).

**Definition of Done**: default DoD plus: the Signal fires on line filled; dev DB backed up before the migration.

**Model**: Sonnet -- *why not Haiku*: a data migration plus a new UI element plus a scoring rule across shared code.
**Delegation checklist included**: yes (if delegated). **Step-types**: UI-NEW, SVC-NEW, DB-MIGRATE, TEST-WIDGET.
**Est-Effort**: 180-300m (unverified).

_**Risk & rollback**_: migration adds columns only; rollback is to ignore them (no data removed).

_**Decision-class interrupts**_: Class 2 (Q2); basis (Q4).

## Task 9 -- F319 (new): No Rule list reloads when the app comes back to the foreground

**Value**: This makes the list match the notification the user just tapped ("No rule 3" shows the 3 items) without
pressing Refresh.

**Requirements**:
- R-1: `NoRuleReviewScreen` observes the app lifecycle; on `resumed` it reloads the list quietly
  (`_loadItems(showSpinner: false)`, no message), skipped while one of the screen's own actions is in flight
  (`_ownActionsInFlight`).
- R-2: if Q6 = 2: the notification carries the account; a tap opens No Rule Review filtered to that account (Android
  and iOS through the plugin's tap callback; Windows through a new hand-off from the second process, a declared
  exception).
- R-3 (prevention): the refresh rule is written once in the screen, not per caller; the card lists every way the
  user reaches this screen (default screen, AppBar icon, Scan History) and shows all are covered by the observer.

**Affected components / files**: `lib/ui/screens/no_rule_review_screen.dart` (`:150-182` initState/dispose); for
Q6 = 2 also `lib/core/services/scan_complete_notifier.dart:182-191` and `windows/runner/main.cpp:118-130`.

**Existing behavior relied on**: (a) the plugin is initialized with no tap callback and `post` sets no payload
(`scan_complete_notifier.dart:182-191`, `post` at `:94-125`), so a tap only brings the app forward: Windows via the
single-instance hand-off (`main.cpp:118-130`), Android via `launchMode="singleTop"` (`AndroidManifest.xml:75`).
(b) No Rule Review is the default screen (`main_navigation_screen.dart:93`), which is why the tap "opens" it.
(c) the screen reloads only in `initState` (`:153`), on rule changes (`:164-174`), after its own actions, after
Manual Scan (`:238`) and on Refresh (`:244`); nothing on resume. (d) a cold start already loads fresh rows in
`initState`. So the defect is the warm case: the app is running and the rows were written by another process
(Windows background worker) or isolate (Android WorkManager).

**Existing abstraction checked**: the same resume-refresh pattern exists at `account_selection_screen.dart:135`,
`battery_optimization_row.dart:45`, `new_mail_trigger_row.dart:121`; the app root observer is `main.dart:742`. The
card mirrors the sibling screens.

**Callers of any guard being changed**: none changed; a new trigger is added. Callers of `_loadItems`: initState,
`_onRulesChanged`, `_openManualScan`, `_refreshFromUserAction`, `_openCreateRule`, `_applyQuickActionInner`; the new
call uses the same `showSpinner: false` path the quick actions already use while a pop-up is open.

**User-reachable control**: none (automatic). Refresh icon unchanged.

**Observable behavior -- before / after**: BEFORE: tap the notification "No rule 3 Deleted 2 Safe 0"; the app comes
forward showing the old list (none, or what was there before) until you press Refresh. AFTER: the app comes forward
and the list shows the 3 new No Rule items within a moment, with no message and no button press. Same on Windows,
Android and iOS. The reload also runs whenever you switch back to the app for any reason.

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: shared Dart; parity claimed. OS behavior assumed identical: Flutter
reports `AppLifecycleState.resumed` when the app returns to the foreground. Windows: when the window regains focus
(after the toast tap's second process calls `SetForegroundWindow`); Android: `onResume` after the notification's
intent brings the singleTop activity forward; iOS: when the app becomes active. UNVERIFIED: that a Windows toast tap
foregrounds the window for both the unpackaged DEV build and the MSIX build; checked in the 5.1.9 rehearsal and MV.

**Dependencies / blockers**: Q6.

**Acceptance criteria**:
- AC-1: Given the screen shows 0 rows and the store gains 3 rows from outside the screen, When the app lifecycle
  goes to `resumed`, Then the screen shows 3 rows with no snackbar. Mutation-verified (remove the observer: red).
- AC-2: a resume while a quick action is in flight does not reload.
- AC-3 (MV): on Windows DEV and on the Fold, after a background scan notification, tapping it shows the new rows.

**Tests to write**:
- T-1 (AC-1) -- TEST-WIDGET `test/ui/screens/no_rule_review_screen_test.dart` (extend). What this does NOT catch:
  whether the OS delivers `resumed` on a notification tap; AC-3 covers that.
- T-2 (AC-2) -- TEST-WIDGET.

**Definition of Done**: default DoD plus: AC-3 observed on Windows and Android.

**Model**: Sonnet -- *why not Haiku*: lifecycle timing beside in-flight actions and an open pop-up needs care.
**Delegation checklist included**: yes. **Step-types**: UI-MOVE, TEST-WIDGET. **Est-Effort**: 45-90m (Q6 = 2 adds
90-150m).

## Task 10 -- F320 (new): WinWright coverage of No Rule Review

**Value**: This puts the default screen into the end-of-sprint WinWright sweep, which the Sprint 81 sweep could not
reach.

**Requirements**:
- R-1: one default script opens Review No Rule Items, opens one item's pop-up, reads the buttons (including the F306
  suggestion and Block Body) and closes it, without creating a rule.
- R-2: pattern and invoke steps only, no cursor-driven steps (so it runs on a locked workstation); the runner's fixed
  1600x1000 window.
- R-3: rows come from a dev DB copy the runner restores after the run (no seed script in the tree; state restored per
  the WinWright policy). If no deterministic row source exists inside the 60m discovery time-box, stop and record why.
- R-4: does not replace HOLD F289 (the default sweep with no mouse steps); it adds one script that already meets it.

**Affected components / files**: `mobile-app/test/winwright/` (new script), `README.md` there,
`run-winwright-tests.ps1` if the copy step is needed.

**Callers of any guard being changed**: the runner launches and stops the app exe; the new step must not stop a
background scan (Sprint 75 IMP-4: Windows DEV background is off, verify at card time).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: Windows-only test tool (WinWright drives Windows UI Automation). Android
and iOS cover the same screen with the shared widget tests (`no_rule_review_screen_test.dart`). Declared testing
exception.

**Dependencies / blockers**: Task 8 (so the script covers the new pop-up).

**Acceptance criteria**: AC-1: the script passes twice in a row in the 5.1.5 sweep, and fails when the pop-up's
suggestion row is removed (mutation).

**Tests to write**: T-1 (AC-1): the script itself.

**Definition of Done**: default DoD plus: README lists the script and its row source.

**Model**: Sonnet -- *why not Haiku*: WinWright discovery has walls nothing predicts (CODING_VELOCITY note).
**Step-types**: WINWRIGHT-SCRIPT, WINWRIGHT-DISCOVERY [no-history, time-boxed]. **Est-Effort**: 30-60m + 60m time-box.

## Task 11 -- F318: the 7.7.1 toolkit prompt lists every changed file (Priority 30)

**Value**: This prevents a changed file from being reviewed by Copilot alone (Sprint 81: `build-with-secrets.ps1`).

**Requirements**:
- R-1: `SPRINT_EXECUTION_WORKFLOW.md` 7.7.1 (`:1124-1128`, `:1327-1356`): the toolkit prompt (code-reviewer,
  silent-failure-hunter, and the improvement review) includes `git diff --name-only origin/develop...HEAD`, minus
  `0*` files at the repo root and `archive/`.
- R-2: each reviewer's report confirms every listed file was read, or names the files skipped and why.
- R-3: the 7.7.1 evidence line template gains "files given N / confirmed read M".

**Affected components / files**: `docs/SPRINT_EXECUTION_WORKFLOW.md`, `docs/SPRINT_CHECKLIST.md` (7.7.1 line).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development process; applies to changes on all three platforms alike.

**Acceptance criteria**: AC-1: the Sprint 82 7.7.1 evidence line records the file count given and confirmed read.

**Tests to write**: none (process); AC-1 is the check.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: ~15m.

## Task 12 -- F317: keep delegated agent work safe across usage limits (Priority 30)

**Value**: This prevents a usage-limit stop from losing an agent's work, and a restart from repeating a release
action.

**Requirements** (master plan R-1 to R-6, in short):
- R-0 (verify first): read the Claude Code docs pages named in the master plan for the usage-limit behavior and
  record `claude --version` and both settings files; any claim not found stays UNVERIFIED in the card.
- R-1: a "Progress and restart" section in every subagent launch prompt the repo keeps (7.7.1 reviews, the
  improvement review, the CI-fix agent, delegated tasks): progress files in the agent's own scratch folder, finished
  units skipped, the final reply says what was resumed.
- R-2: mutation locks across a stop: an agent holding a lock restores and verifies the file, then removes the lock;
  the wake-up prompt reports any lock older than one hour.
- R-3: `scripts/agent-work-status.ps1` (`.SYNOPSIS`), from files only: each agent task's state, held locks, sprint
  phase.
- R-4: an hourly wake-up prompt (off-minute) that resumes stopped agents and keeps the auto-advance closing
  convention; its 7-day expiry reported.
- R-5: never repeat a published or release action on resume (Phase 8, store uploads, tags).
- R-6: a hook test case that fails if a launch prompt loses its restart section (proven red, then restored);
  `.claude\hooks\run-test-cases.ps1` after any hook change.

**Affected components / files**: `docs/SPRINT_EXECUTION_WORKFLOW.md`, `scripts/agent-work-status.ps1` (new),
`.claude/hooks/test-cases/` (new case), CHANGELOG.

**Existing abstraction checked**: `.claude/hooks/mutation-lock.ps1` (locks), `scripts/test-hook.ps1` (hook probes).

**Parity (ADR-0042 / ADR-0049 / ADR-0050)**: development environment (Windows); no app code.

**Dependencies / blockers**: Q5 (requirement echo).

**Acceptance criteria**:
- AC-1: the status script reports a fabricated in-progress task, a finished task and a held lock correctly.
- AC-2: the hook test fails with the restart section cut and passes restored.
- AC-3: every launch-prompt location in the workflow doc carries the section.

**Tests to write**: T-1 (AC-2) hook test case; T-2 (AC-1) a script run on fabricated files in the scratchpad.

**Definition of Done**: default DoD plus: hook suite green.

**Model**: Sonnet -- *why not Haiku*: process design across several prompts, a script and a hook test.
**Step-types**: HOOK, DOCS. **Est-Effort**: 120-240m (unverified).
