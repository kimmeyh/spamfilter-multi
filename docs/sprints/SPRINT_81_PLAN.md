# Sprint 81 Plan

**Status**: APPROVED 2026-10-23 (Harold: *"Sprint plan approved as amended (with any comments I provided), proceed with execution. All Sprint tasks and sub-tasks are approved."*). Scope selected by Harold at Phase 8.4 pass 2 (2026-10-23).
**Branch**: `feature/20261023_Sprint_81` | **PR**: draft, created at 3.3.1 (stays draft until 7.7.5)
**Planner**: Opus 5.5 (top tier, `SPRINT_PLANNING.md:94-110`). Phase 3.2.2.1 audits by spot reads on 2026-10-23;
file:line evidence is in each card.

## Objective

Start the iPhone app: enroll with Apple, build a signed iOS pipeline on a GitHub macOS runner, and write the iOS
project and platform answers, so Sprint 82 can test on Harold's iPhone and Sprint 83 can upload to the App Store.
Alongside: fix two silent-failure classes found by the Sprint 80 reviews (F302 IMAP ids, F303 Android diagnostics),
make a missing Gmail label visible and keep a history cursor per folder (F259), choose the Gmail 7-day sign-in path
(F301), show why a No Rule email looks like spam (F271), and settle two open investigations (F278, F300, IMP-2b).

**Scope (Harold, 2026-10-23, verbatim)**: *"IMP-2b, F302, F303, F301, F300, F259; F271. Heuristic reasons and rule
suggestions on No Rule Review; F278. Notifications that produced no scan, and alarm + WorkManager scans coexisting;
F67a, F304, the F67b code. move to HOLD F289, F246"*.

**Answers recorded (Harold, 2026-10-23)**: *"q1 1, q2 1, q3 1 q5 1"*.
- Q1 = 1: Apple Developer Program as an **Individual** (extends the 2026-09-09 decision in `docs/LEGAL_ENTITY.md`;
  no D-U-N-S Number).
- Q2 = 1: build machine is a **GitHub Actions `macos-26` runner** (F304 path a).
- Q3 = 1: Harold **has an iPhone on iOS 26**. Model not yet stated (asked again below, Q-S3).
- Q5 = 1: SEC-11b stays on HOLD.
- F289 and F246 moved to HOLD.

**Parity (Harold, 2026-10-23, verbatim)**: *"everything needs to take into account the Windows App, Android app and the
iPhone app with the ADR stating that everything should be functionally and UI the same unless it cannot be - and where
it cannot be it should be implemented as a platform exception for what is needed -- this applies to all backend code,
frontend code, data, architecture, development, security, testing, deployment."* Every card has a **Parity
(ADR-0042 / ADR-0049 / ADR-0050)** line naming the Windows, Android and iOS paths, and either claims parity (naming the
OS behavior assumed identical) or declares the exception and what the other platforms do instead. iOS answers come
from `PlatformCapabilities` (ADR-0049) and ADR-0050; no new bare `Platform.isX` checks (the F294 policy test refuses
them).

**Prevention first** (Harold, 2026-10-06): every defect fix states its prevention first, extending the connected
existing control, then the instance fix.

## Phase 2 pre-kickoff checks (2026-10-23)

- 2.1 Master plan read; Last Completed Sprint is Sprint 80 (current).
- 2.2 Sprint 80 merged: PR #490 -> develop (f301cdee); develop -> main PR #506 (2d81264a), tag `v0.21.0`.
- 2.3 DONE 2026-10-23: the 18 Sprint 80 cards the PR body missed (#492-#505, #471, #433, #428, #472) closed by
  Claude with a comment naming the cause; `gh issue list --label sprint --state open` is empty. Harold: *"close...
  - always and there is no reason to ask me about these unless it is a very unusual situation"*. Prevention already
  applied: one "Closes" per card in the PR template (eb9f0b82).
- 2.4 Working tree clean before this plan.
- 2.5 Branch `feature/20261023_Sprint_81` was cut from the Sprint 80 branch (carry-forward rule), pushed.
- 2.6 `dart pub outdated` (2026-10-23): 68 locked-older and 14 constrained-older packages; no security advisory shown.
  One discontinued package: `js` (transitive). No action this sprint; no dependency changes are planned.
- 3.2.1 `docs/sprints/SPRINT_80_SUMMARY.md` exists; the Past Sprint Summary row for 80 exists.

## Tasks, order, models and estimates

Estimates are minutes from the `CODING_VELOCITY.md` Estimate Table, low end of each band (planned cards ran about 4x
under in Sprint 78). `[no-history]` marks a step-type with no samples.

- **Task 0 -- Version bump 0.22.0+19** (3.7.0b). MINOR: F271 is a user-facing `feat`. Haiku. 10-15m.
- **Task 1 -- F67a** iOS prerequisites: Harold enrolls, creates the iOS OAuth client and the App Store Connect API key;
  Claude writes the walkthroughs and records results. Haiku (docs). 30-60m + Harold console time + Apple processing.
- **Task 2 -- F304** iOS signed build pipeline on `macos-26` to TestFlight. Sonnet. 90-180m + 120m time-boxed signing
  discovery. After Task 1 (needs the account and the API key).
- **Task 3 -- F67b code** iOS project, Info.plist, AppDelegate, `PlatformCapabilities` iOS answers. Sonnet. 120-200m.
  Can start at once (no Mac needed to write it); compiles through Task 2.
- **Task 4 -- F302** IMAP sequence-number field and a "no valid UID" constant. Sonnet. 60-120m.
- **Task 5 -- F303** Android diagnostics field by field. Sonnet. 45-90m.
- **Task 6 -- F259** missing Gmail label is visible; history cursor per account + folder. Sonnet. 90-150m.
- **Task 7 -- F301** Gmail 7-day sign-in: the decision and its ADR-0029 record (Q1 below), then the chosen path.
  Fable/Opus for the decision record (ADR authoring, `SPRINT_PLANNING.md:107`); the path itself 30-90m by its model.
- **Task 8 -- F271** heuristic reason chips and "Create rule" on No Rule Review. Sonnet. 150-210m. Class 2 (Q2).
- **Task 9 -- F278** notifications that produced no scan (R77-BAT-2 on the emulator). Haiku analysis, Sonnet if a
  log line must be added. 45-90m + emulator windows.
- **Task 10 -- F300** WinWright sweep per-step cost. Sonnet. 60-90m.
- **Task 11 -- IMP-2b** process tree of a background task that stays open after an error. Haiku. 15-30m, opportunistic.
- **Unplanned allowance (named, not padded into cards)**: Manual Validation fixes, phone rounds and 7.7.1 review
  fixes, 150-250m.

**Total**: Tasks 0-11 about 745-1,365 minutes, plus the 150-250 allowance, plus Harold's console and phone time.

**When can Harold come back (first Manual Validation handoff)**: about 7-10 hours of wall-clock after approval if run
serially; Tasks 4, 5, 6, 10 and 3 touch different files and run as parallel sub-agents, which brings it to about 4-6
hours. The iOS pipeline (Task 2) is gated on Harold's Apple enrollment and cannot finish before Apple approves it.

**Order**:
1. 3.7.0 cards, 3.7.0b version bump, 3.7.1 PR body.
2. Task 1 walkthroughs FIRST, so Harold can enroll the same day (Apple processing is the longest wait).
3. Parallel block: Task 3, Task 4, Task 5, Task 6, Task 10 (sub-agents, different files).
4. Task 7 decision record (top tier) while the block runs; Task 8 after Q2; Task 9 in emulator windows.
5. Task 2 once enrollment and the API key exist; first TestFlight build installs on Harold's iPhone.
6. Task 11 whenever a background task stays open after an error.

**Single interactive session -- model deviation note** (`SPRINT_PLANNING.md:358-379`, option (b)): Tasks 3, 4, 5, 6
and 10 are delegated to sub-agents on their assigned tier before Manual Validation, with the delegation checklist
verbatim. Anything run in the main session executes on the session model, and its `Executed-by` line cites this note.

**Code reviews**: the 7.7.1 pair (Copilot by hand on the draft + pr-review-toolkit code-reviewer and
silent-failure-hunter), started with the retrospective prompt at Manual Validation complete.

**Cards**: created at Phase 3.7.0, the first action after approval. One "Closes #N" per card in the PR body.

**Always-confirm actions covered by this approval** (`SPRINT_EXECUTION_WORKFLOW.md:479-486`), so they are not asked
again: (a) Task 0 the version bump; (b) Task 2 a new workflow file `.github/workflows/ios.yml` (shared CI
infrastructure) and the use of repository secrets Harold creates for it; (c) Tasks 4 and 6 database migrations (each
backs up the dev DB first; no sqlite downgrade). Not covered, still asked: any dependency version change, any edit to
`secrets.*.json`.

## Phase 3.2.2.1 branch-state verification (summary)

- **F67b: no iOS project exists.** `mobile-app/ios/` holds only `Flutter/` (generated by `pub get`) and
  `Runner/GeneratedPluginRegistrant.*`, which `mobile-app/.gitignore:91` ignores; `git ls-files mobile-app/ios` is
  empty. Task 3 starts by generating the project. `PlatformCapabilities` already has an iOS branch for every member
  (`lib/core/platform/platform_capabilities.dart:23-247`), several marked "until ADR-0050" or "(assumed)"
  (`:23, :50, :62, :113, :130, :136, :141, :186, :203, :225, :231`). ADR-0050 is accepted, so those become answers.
- **F302: confirmed.** `generic_imap_adapter.dart:2363` `?? mimeMessage.sequenceId?.toString()`, warning at `:2366`.
- **F303: confirmed.** `MainActivity.kt:203` `"diagnostics" ->` builds the map in one expression.
- **F259: confirmed.** `gmail_api_adapter.dart:1464` `_labelIdFor` (callers `:860, :970, :1197, :1415, :1422`); the
  cursor is per account: `database_helper.dart:1424` `getLastHistoryId(String accountId)`, `:1435` setter; read and
  written at `email_scanner.dart:1805, 1826, 1848, 1855, 1863`.
- **F271: partly true.** The auth verdict is already stored per No Rule row
  (`unmatched_email_store.dart:75` `authClassification`, column `auth_classification` at `:115`). Reply-To and
  List-Unsubscribe are read only by the dev-only content history (`content_history.dart:209, 217`). No reason chips
  exist. **Finding that changes the card**: the No Rule Review screen loads rows from the database after the scan, so
  reasons "computed and shown, not stored" cannot reach that screen. They must be stored as reason CODES on the row
  (as `auth_classification` already is), never header text. That is a data change -- Q2.
- **F278: confirmed open.** Protocol at `docs/research/R76-1_BATTERY_AB_RESULTS.md:237-250` (arms A-C, decision rule).
- **F300: confirmed open.** No per-step timing exists in the runner output.
- **F301: confirmed.** ADR-0029 Phase 1 (line 94) accepts weekly re-authentication; Phase 2 (line 103) is app
  passwords over IMAP; Phase 3 (line 113) is CASA, on hold.
- **IMP-2b**: no code; waits for the next occurrence.

**Phase 3.2.2.2**: fired -- F67b estimate rises for project generation (120-200m); F271 gains a storage requirement
and Q2; F67a's estimate falls (Individual: no D-U-N-S, no domain work).

## Phase 3.6.1 Architecture Impact Check

- **ADR-0050**: iOS answers move from "(assumed)" to declared in `PlatformCapabilities` (Task 3). No new exception.
- **ADR-0035** (dev/prod side by side): iOS ships prod-only at first; F95 (revised) adds the dev variant after the
  upload. Recorded as a known gap, not a change to ADR-0035.
- **ADR-0029**: Task 7 records the chosen Phase for the 7-day sign-in, amending the ADR's status section.
- **F127 decision (CI secrets unset)**: its trigger fires for the iOS job only -- a TestFlight build is a shipped
  artifact that needs the iOS client ID and signing material. `ci.yml` stays secret-free; `ios.yml` uses its own
  secrets. ARCHITECTURE.md gains the iOS build path.
- **Data model**: Task 4 adds a sequence-number column and a UID constant (approved Q1 = 2, 2026-10-23); Task 6 moves
  the Gmail history cursor from per-account to per-account-and-folder (Class 2, Q3); Task 8 adds reason codes to No
  Rule rows (Class 2, Q2).
- No other ADR conflicts found.

## Phase 3.7 answers (Harold, 2026-10-23: *"q1 1 q2 1 q3 1 q-s3 it is running ios 27.1 as of yesterday"*)

- **Q1 = 1**: F301 keeps ADR-0029 Phase 1 and makes it visible (tester instructions + a notification on a Gmail
  background skip for sign-in).
- **Q2 = 1**: F271 stores reason CODES in one new column on the No Rule row (Class 2, approved).
- **Q3 = 1**: F259 history cursor per account and folder, migration copies the current cursor to INBOX (Class 2,
  approved).
- **Q-S1, Q-S2**: covered by the plan approval (models as assigned; version 0.22.0+19).
- **Q-S3**: Harold's iPhone runs **iOS 27.1** (updated 2026-10-22); model not stated and not needed. The deployment
  target stays at the plugin floor (iOS 14, ADR-0050 Q6) so older test devices still install; iOS 27.1 is the
  first test device.
- **DB schema versions assigned** (three migrations this sprint, current v13): Task 4 F302 = v14, Task 6 F259 = v15,
  Task 8 F271 = v16.

## Decision questions as asked (answered above)

- **Q1. F301: which path for the Gmail 7-day sign-in expiry?** Today every tester's Gmail sign-in dies after 7 days
  because the consent screen is in "Testing" and the app is unverified.
  1. Keep ADR-0029 Phase 1 and make it visible: tester instructions name the weekly sign-in, and a Gmail background
     skip for sign-in shows a notification (recommended; small, no Google process; the App Store reviewer uses an
     IMAP demo account).
  2. ADR-0029 Phase 2: offer Gmail by app password over IMAP as the documented path (what you use on the Fold); OAuth
     stays for those who want it.
  3. Decide after I read Google's documentation on moving the consent screen to "In production" unverified (the
     master plan says doing so may cap the project at 100 users for life; that claim is re-verified first).
- **Q2. F271 (Class 2): store reason codes on each No Rule row?** This would change a prior development decision:
  the card said reasons are "computed and shown, not stored". The No Rule Review screen reads saved rows, so the
  reasons must be saved to be shown there.
  1. Store short reason CODES only (for example `reply_to_differs`, `no_unsubscribe`), in one new column, like the
     existing `auth_classification`; no header text is stored (recommended).
  2. Show reasons only on the live Results screen right after a scan; nothing stored; No Rule Review shows none.
- **Q3. F259 (Class 2): history cursor per account AND folder?** This would change a prior development decision: one
  Gmail history cursor per account becomes one per account and folder, so a custom label or SPAM no longer reads
  from "now" after INBOX saves first. A migration copies the current cursor to INBOX.
  1. Approve (recommended).
  2. Fix only the missing-label visibility; leave the cursor per account.
- **Q-S1. Models as assigned**: 1 approve.
- **Q-S2. Version 0.22.0+19**: 1 approve.
- **Q-S3. Which iPhone model and iOS version** will you test on (type it)? Task 3 sets the deployment target from it
  (the plugin floor is iOS 14).

---

# Cards

## Task 0 -- Version bump 0.22.0+19 (3.7.0b)

**Value**: This lets a tester tell the Sprint 81 dev build from the 0.21.0 store builds.

**Requirements**:
- R-1: `pubspec.yaml` `version: 0.22.0+19`, `msix_config.msix_version: 0.22.0.0`.
- R-2: Same commit: `STORE_VERSION_STATUS.md` "Last uploaded to Play" -> 0.21.0 (versionCode 18) and the Dev row ->
  0.22.0+19; CHANGELOG `[Unreleased]` 0.21.0 entries under `## [0.21.0] - 2026-10-23`; provisional
  `RELEASE_NOTES_0.22.0_windows.md` and `_play.md`.
- R-3: the iOS build takes the same version and build number (ADR-0043; Flutter maps `version` to
  `CFBundleShortVersionString` and `CFBundleVersion` -- unverified until Task 3's first build, checked there).

**Affected components / files**: `mobile-app/pubspec.yaml`, `docs/STORE_VERSION_STATUS.md`, `CHANGELOG.md`,
`docs/store-assets/`.

**Parity**: one version on Windows, Android and iOS (ADR-0043).

**Dependencies / blockers**: plan approval.

**Acceptance criteria**: AC-1: `version_consistency_test`, `dev_version_ahead_test`, `release_notes_test` pass.

**Tests to write**: none new; T-1 (AC-1) runs the three gates.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: 10-15m.

## Task 1 -- F67a: iOS prerequisites (Priority 2)

**Value**: This enables every other iOS task; Apple processing is the longest wait in the 3-sprint plan.

**Requirements**:
- R-1: A walkthrough Harold can follow, in `docs/IOS_SETUP.md` (new): enroll in the Apple Developer Program as an
  Individual (Q1 = 1), with each screen and field named. Each external claim cites Apple's page with its read date,
  or says unverified.
- R-2: A walkthrough to create the iOS OAuth client in Google Cloud Console, bundle ID `com.myemailspamfilter`
  (mirrors the Android applicationId, ADR-0026), and to read the restricted-scope verification status shown for it.
- R-3: A walkthrough to create an App Store Connect API key (Team key, App Manager role) for Task 2, and the exact
  GitHub repository secret names Task 2 reads. Harold enters the secrets; Claude never sees the key file contents.
- R-4: Record in `docs/LEGAL_ENTITY.md`: Apple = Individual (Harold, 2026-10-23), and the seller name Apple shows,
  read from the enrollment screen (UNVERIFIED until then).
- R-5: Record the results (enrollment date, approval date, client ID created, key created) in this plan's Task 1.

**Affected components / files**: `docs/IOS_SETUP.md` (new), `docs/LEGAL_ENTITY.md`, this plan.

**Existing behavior relied on**: the Play and Partner Center walkthrough shape in `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`
-- verified by read at execution.

**Parity**: iOS only (store account and OAuth client). Windows and Android already have theirs.

**Dependencies / blockers**: Harold's console actions (Apple, Google Cloud, App Store Connect).

**Acceptance criteria**:
- AC-1: `docs/IOS_SETUP.md` covers R-1 to R-3 with every external claim cited or marked unverified.
- AC-2: Harold reports enrollment submitted; approval recorded when it arrives.
- AC-3: the iOS OAuth client ID exists and its verification status is recorded.

**Tests to write**: none (docs and external setup). T-1 (AC-1): read-through against Apple's and Google's pages.

**Definition of Done**: default DoD plus: no secret value in any committed file.

**Model**: Haiku -- docs. **Step-types**: DOCS. **Est-Effort**: 30-60m + Harold time.

_**Risk & rollback**_: Apple may take days to approve; Task 2 waits. Nothing to roll back.

## Task 2 -- F304: iOS signed build pipeline to TestFlight (Priority 4)

**Value**: This gives the project a Mac it does not own: one command builds, signs and uploads an iOS build.

**Requirements**:
- R-1: New `.github/workflows/ios.yml`, `workflow_dispatch` only, `runs-on: macos-26`, Flutter from `.fvmrc`
  (extends the F296 single-version rule; `flutter_version_sync_test` gains the new file).
- R-2: Signing with an App Store Connect API key and Xcode automatic signing (`-allowProvisioningUpdates` with the
  key); certificate and profile created by Apple, not committed. Secrets read from repository secrets named in Task 1.
- R-3: The iOS Gmail client ID is injected at build time from a repository secret, the same way Windows and Android
  read theirs (`--dart-define-from-file` written in the job from secrets, then deleted).
- R-4: The job uploads the IPA to TestFlight and prints the build number; the IPA is kept as a job artifact for 7 days.
- R-5: After the first run, record the runner minutes GitHub billed (Settings > Billing), which settles whether
  macOS minutes are free on this public repository (UNVERIFIED today).

**Affected components / files**: `.github/workflows/ios.yml` (new), `test/policy/flutter_version_sync_test.dart`,
`docs/IOS_SETUP.md`, `docs/ARCHITECTURE.md`.

**Existing abstraction checked**: `.github/workflows/ci.yml` (`.fvmrc` read at `flutter-version-file`), and
`flutter_version_sync_test` -- the new workflow follows both.

**Callers of any guard being changed**: none (new workflow). `ci.yml` is not changed.

**Parity**: iOS build path only. Windows (MSIX, Partner Center) and Android (AAB, Play) keep theirs; each store's
build is its own platform mechanism (ADR-0042 deployment exception, the same kind as MSIX versus AAB).

**Dependencies / blockers**: Task 1 (account approved, API key and secrets created); Task 3 (an iOS project to build).

**Non-functional requirements**:
- Security: no signing material, key or client ID in the tree or in logs; the secret file written in the job is
  deleted in an `always()` step.

**Acceptance criteria**:
- AC-1: `gh workflow run ios.yml --ref <branch>` completes green and a build appears in TestFlight.
- AC-2: Harold installs it on his iPhone through TestFlight internal testing and the app opens.
- AC-3: `flutter_version_sync_test` fails if `ios.yml` pins a different Flutter version (mutation-verified).

**Tests to write**:
- T-1 (AC-3) -- TEST-UNIT policy: extend `flutter_version_sync_test` to read `ios.yml`.
- T-2 (AC-1, AC-2): the workflow run and the TestFlight install (manual, recorded).

**Definition of Done**: default DoD plus: AC-2 observed on Harold's iPhone.

**Model**: Sonnet -- *why not Haiku*: new CI platform plus Apple signing, multi-step with no project history.
**Step-types**: CI [no-history], DOCS. **Est-Effort**: 90-180m + 120m time-boxed signing discovery (not estimated).

_**Risk & rollback**_: signing may loop; time-box at 120m, then Harold decides on a rented Mac for interactive Xcode.
Rollback: delete the workflow file; nothing else depends on it.

## Task 3 -- F67b code: iOS project and platform answers (Priority 6)

**Value**: This puts a buildable iOS app in the repo with every platform difference declared, so Sprint 82 tests it.

**Requirements**:
- R-1: Generate the iOS project (`flutter create --platforms=ios .` in `mobile-app`). Whether this runs on Windows is
  UNVERIFIED; if it does not, the Task 2 runner generates it once and the files are committed. Bundle ID
  `com.myemailspamfilter`; display name as on Android.
- R-2: `Info.plist`: `GIDClientID` and the reversed-client-ID URL scheme (read from the build-time value, not
  hard-coded), `UIBackgroundModes` `fetch`, `BGTaskSchedulerPermittedIdentifiers`, `UIFileSharingEnabled`,
  `LSSupportsOpeningDocumentsInPlace` (ADR-0050 Q1, Q3, Q7).
- R-3: `AppDelegate.swift`: the `flutter_local_notifications` delegate line and the workmanager registration
  (ADR-0050 Q7a, Q1). The background TASK itself is F67c (Sprint 82); this card only registers it.
- R-4: Deployment target from Q-S3, not below iOS 14 (plugin floor, ADR-0050 Q6).
- R-5: `PlatformCapabilities`: every iOS answer marked "until ADR-0050" or "(assumed)" becomes the ADR-0050 answer,
  with the doc comment citing the ADR-0050 section. Members still unverified on a device (for example
  `renewsGmailWithStoredRefreshToken`) say "unverified until F67c" and keep the safe answer.
- R-6: `AppPaths` and the export folder resolve on iOS to the app's Documents folder (ADR-0050 Q7b); the F282
  `MyEmailSpamFilter` folder name is the same on all three.
- R-7 (prevention): the F294 policy test already refuses bare `Platform.isIOS`; a test runs every `PlatformCapabilities`
  member with the host set to iOS and fails on any member that still throws or returns a placeholder.

**Affected components / files**: `mobile-app/ios/**` (new, generated + edited), `mobile-app/.gitignore` (keep
generated files ignored), `lib/core/platform/platform_capabilities.dart`, `lib/core/platform/platform_policy.dart`,
`lib/core/storage/app_paths.dart` (or its iOS branch), tests under `test/core/platform/`.

**Existing abstraction checked**: `PlatformCapabilities` and `PlatformPolicy` (ADR-0049) -- every iOS answer goes
there; `HostPlatform.ios` already exists (`platform_capabilities.dart:90`).

**Existing behavior relied on**: the F294 policy test refuses bare platform checks -- verified at execution by
running it with a probe file.

**Parity**: shared Dart on all three. iOS differences are the two ADR-0050 exceptions (background schedule is best
effort; no new-mail trigger, exactly as Windows) and mechanism differences already declared (native Google sign-in
as on Android; Documents folder found differently, as on Android and Windows).

**Dependencies / blockers**: none to write; Task 2 to compile. Q-S3 for the deployment target.

**Acceptance criteria**:
- AC-1: every `PlatformCapabilities` member returns an ADR-0050 answer for iOS; none says "until ADR-0050".
- AC-2: Windows and Android answers are unchanged (existing tests green).
- AC-3: the first `ios.yml` run (Task 2) compiles the project.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT `test/core/platform/platform_capabilities_ios_test.dart`: every member on iOS.
- T-2 (AC-2): existing platform tests.
- T-3 (AC-3): the Task 2 workflow run.

**Definition of Done**: default DoD plus: ARCHITECTURE.md iOS row; ADR-0050 "implemented by" line.

**Model**: Sonnet -- *why not Haiku*: generated native project plus seam edits across 3-5 files with platform rules.
**Delegation checklist included in the sub-agent prompt**: yes. **Step-types**: NATIVE-IOS [no-history], SVC-EDIT,
TEST-UNIT. **Est-Effort**: 120-200m.

_**Risk & rollback**_: generated files may differ by Flutter version; regenerate from `.fvmrc`'s version. Rollback:
remove `mobile-app/ios/` additions; no other platform touched.

## Task 4 -- F302: IMAP sequence number in its own field; "no valid UID" constant (Priority 16)

**Value**: This prevents a sequence number being used as a UID, which can move or delete the wrong message.

**Requirements** (from the master-plan card, Harold's design 2026-10-23):
- R-1: `EmailMessage` and the stored rows that carry the IMAP id gain a separate sequence-number field, set from
  `mimeMessage.sequenceId`.
- R-2: when `mimeMessage.uid` is null, the UID field holds ONE named constant (`kNoValidImapUid`), never the sequence
  number and never an empty string.
- R-3 (prevention): every UID consumer (presence check, move, delete, re-sighting, the No Rule store) refuses the
  constant through one shared helper and writes a `DiagnosticLogger` line naming the folder. A policy test fails any
  new UID consumer in `lib/` that does not use the helper.
- R-4: the `[IMAP] Message has no UID` warning stays and also reaches the diagnostic log.

**Affected components / files**: `generic_imap_adapter.dart:2362-2367`, `lib/core/models/email_message.dart`, the
stores that persist the id (enumerated at execution), a DB migration, `test/policy/`.

**Callers of any guard being changed**: every reader of the IMAP message id -- enumerated by grep at execution and
listed in this card before the change (CLAUDE.md IMP-1).

**Parity**: shared IMAP adapter; Windows, Android and iOS run the same Dart. No exception.

**Dependencies / blockers**: None. Dev-DB backup before the migration.

**Acceptance criteria**:
- AC-1: a fake FETCH with no UID gives UID = the constant, sequence field = the number; presence check, move and
  delete skip it and log it.
- AC-2: the policy test fails on a probe UID consumer that bypasses the helper.

**Tests to write**: T-1 (AC-1) TEST-UNIT adapter test; T-2 (AC-2) policy test with a probe; both mutation-verified.

**Definition of Done**: default DoD plus: migration tested on a copy of the dev DB.

**Model**: Sonnet -- *why not Haiku*: data-model change with a migration and a caller sweep. **Delegation checklist**:
yes. **Step-types**: IMAP, DB-MIGRATE, TEST-UNIT. **Est-Effort**: 60-120m.

_**Risk & rollback**_: migration on existing DBs; additive column only, so rollback is ignoring it.

_**Decision-class interrupts**_: Class 2 approved by Harold (Q1 = 2, 2026-10-23).

## Task 5 -- F303: Android new-mail diagnostics, each field on its own (Priority 18)

**Value**: This makes a failing diagnostics field visible in the log Harold pulls, since adb is blocked.

**Requirements**:
- R-1: `MainActivity.kt` `"diagnostics"` (line 203): each field read in its own guard; a failing field reports
  `"<field>": "error: <Type>: <message>"` and the others are still returned.
- R-2 (prevention): `NewMailTrigger.formatDiagnostics` writes per-field errors into the diagnostic-log line.

**Affected components / files**: `android/app/src/main/kotlin/com/myemailspamfilter/MainActivity.kt:203-222`,
`lib/core/services/new_mail_trigger.dart` (or its location), an Android JVM test, a Dart test.

**Parity**: Android only. The new-mail trigger exists only on Android (`hasNewMailNotificationTrigger` false on Windows
and iOS, ADR-0049 / ADR-0050 Q2). No Windows or iOS change.

**Dependencies / blockers**: None.

**Acceptance criteria**: AC-1: JVM test with one field forced to throw returns the others plus that error. AC-2: a Dart
test shows the error text in the formatted line. AC-3: on the Fold, the 0.22.0 diagnostic line shows every field.

**Tests to write**: T-1 (AC-1) JVM unit test (`gradlew.bat :app:testDevDebugUnitTest`); T-2 (AC-2) TEST-UNIT.

**Definition of Done**: None -- default DoD only (plus AC-3 at Manual Validation).

**Model**: Sonnet -- *why not Haiku*: Kotlin plus a JVM test harness in this project. **Delegation checklist**: yes.
**Step-types**: NATIVE-ANDROID, TEST-UNIT. **Est-Effort**: 45-90m.

## Task 6 -- F259: missing Gmail label visible; history cursor per account + folder (Priority 35)

**Value**: This prevents a renamed Gmail label from scanning empty forever with no trace, and a label or SPAM from
skipping mail because INBOX saved the cursor first.

**Requirements**:
- R-1 (prevention): `_labelIdFor` returning null goes through the existing F202 missing-folder classification
  (extend that classifier, do not add a new path) and writes a diagnostic line; the null is not cached.
- R-2: the label lookup is case-insensitive, matching how Gmail shows labels.
- R-3 (Q3 = 1): the history cursor is stored per account and folder; a migration copies today's per-account cursor
  to INBOX; other folders start with no cursor (one full fetch).

**Affected components / files**: `gmail_api_adapter.dart:1464` and callers `:860, :970, :1197, :1415, :1422`;
`database_helper.dart:1424-1440`; `email_scanner.dart:1805-1863`; a migration; tests.

**Callers of any guard being changed**: the five `_labelIdFor` callers (fetch, move, folder test, label move source
and target) -- each one's behavior on null listed in the card at execution before the change.

**Existing abstraction checked**: the F202 missing-folder classifier (found by grep at execution).

**Parity**: shared Gmail adapter; same on Windows, Android and iOS. No exception.

**Dependencies / blockers**: Q3. Dev-DB backup before the migration.

**Acceptance criteria**: AC-1: a fake label list without the folder gives a missing-folder result and a log line, and
a renamed label found on retry. AC-2: two folders keep separate cursors; INBOX saving does not advance SPAM.

**Tests to write**: T-1 (AC-1), T-2 (AC-2) TEST-UNIT, mutation-verified.

**Definition of Done**: default DoD plus: migration tested on a copy of the dev DB.

**Model**: Sonnet -- *why not Haiku*: cursor semantics and a migration. **Delegation checklist**: yes.
**Step-types**: SVC-EDIT, DB-MIGRATE, TEST-UNIT. **Est-Effort**: 90-150m.

_**Decision-class interrupts**_: Class 2 -- Q3.

## Task 7 -- F301: Gmail 7-day sign-in expiry, decide and apply (Priority 10)

**Value**: This ends the weekly surprise for testers, on Android, Windows and (from Sprint 82) iOS.

**Requirements**:
- R-1: Harold's Q1 answer recorded in ADR-0029 (status section, date, his words).
- R-2 (Q1 = 1): tester instructions (Play closed-test notes and `docs/`) name the weekly sign-in; a Gmail background
  skip for sign-in shows a user notification (overlaps F244 -- that card is closed into this one if done here).
- R-3 (Q1 = 2): the account setup screen offers Gmail by app password over IMAP as a documented choice, with the help
  text; OAuth stays.
- R-4 (Q1 = 3): read Google's OAuth documentation on publishing an unverified app and quote it before any proposal.

**Affected components / files**: `docs/adr/0029-*.md`; per path: `background_scan_core` skip handling and the
notification service, or the account setup screen and help content.

**User-reachable control**: path 1 -- the notification on the phone and the Windows toast; path 2 -- the account setup
screen choice.

**Parity**: Windows, Android and iOS all use Google OAuth for Gmail; the chosen path applies to all three. Windows shows
a toast and Android/iOS a notification through the same notification service (ADR-0048).

**Dependencies / blockers**: Q1.

**Acceptance criteria**: AC-1: ADR-0029 records the path. AC-2 (path 1): a background skip for sign-in produces one
notification per account per day, tested. AC-3 (path 2): the choice is reachable on the account setup screen.

**Tests to write**: per path, TEST-UNIT for the skip notification or TEST-WIDGET for the setup choice.

**Definition of Done**: default DoD plus: tester instructions updated before the next closed-test upload.

**Model**: Fable/Opus for R-1 (ADR authoring); Sonnet for the path code -- *why not Haiku*: notification path crosses
the background isolate. **Step-types**: DOCS, SVC-EDIT, TEST-UNIT. **Est-Effort**: 30-90m.

## Task 8 -- F271: heuristic reasons and "Create rule" on No Rule Review (Priority 32)

**Value**: This shows why an email looks like spam and gives a one-tap candidate rule.

**Requirements**:
- R-1: Signals computed at scan time from headers already fetched (no body fetch): Reply-To domain differs from From,
  authentication failed (the existing `auth_classification`), lookalike domain, a TLD already blocked by a rule, bulk
  mail without List-Unsubscribe.
- R-2 (Q2 = 1): stored as reason CODES in one new column on the No Rule row; no header text stored.
- R-3: shown as chips on each No Rule Review row; "Create rule" opens the existing quick-add screen prefilled.
- R-4: signals never act on mail.
- R-5: two-header comparisons are Dart, not YAML grammar (a grammar change would be Class 2).

**Affected components / files**: the scan path that creates No Rule rows; `unmatched_email_store.dart:75-184`; a
migration; `lib/ui/screens/no_rule_review_screen.dart`; the quick-add screens; a new `heuristic_signals.dart`.

**Existing abstraction checked**: `AuthResultsParser` (`auth_results_parser.dart`) and the stored
`authClassification` -- reused, not re-parsed.

**User-reachable control**: No Rule Review screen -- reason chips on each row and a "Create rule" action.

**Observable behavior -- before / after**: BEFORE: a No Rule row shows sender, subject and date; the user must guess
why it might be spam. AFTER: the row also shows short chips such as "Reply-To differs" or "No unsubscribe"; tapping
"Create rule" opens quick-add already filled in for that sender's domain.

**Parity**: shared Dart UI and logic on Windows, Android and iOS. Chips wrap on a phone and sit in one line on desktop
(layout only, same content). No exception.

**Dependencies / blockers**: Q2. F267 (shipped Sprint 80).

**Non-functional requirements**: Accessibility: chips have semantics labels (ADR-0037). Privacy: codes only (R-2);
the privacy policy needs no change because no new content is stored (re-check `data_safety_declarations_test`).

**Acceptance criteria**:
- AC-1: each signal has a unit test with a header set that triggers it and one that does not.
- AC-2: Given a No Rule row with reason codes, When the screen opens, Then the chips show; When "Create rule" is
  tapped, Then quick-add opens with the domain filled in.
- AC-3: rows saved before the migration show no chips and no error.

**Tests to write**: T-1 (AC-1) TEST-UNIT `test/core/heuristic_signals_test.dart`; T-2 (AC-2) TEST-WIDGET on the No
Rule Review screen; T-3 (AC-3) migration test.

**Definition of Done**: default DoD plus: WinWright sweep touches the screen (lib/ui changed).

**Model**: Sonnet -- *why not Haiku*: scan path + migration + UI across 4-6 files. **Delegation checklist**: yes.
**Step-types**: SVC-NEW, DB-MIGRATE, UI-NEW, TEST-UNIT, TEST-WIDGET. **Est-Effort**: 150-210m.

_**Decision-class interrupts**_: Class 2 -- Q2.

## Task 9 -- F278: notifications that produced no scan (Priority 34)

**Value**: This prevents a silent loss of new-mail triggers.

**Requirements**:
- R-1: run R77-BAT-2 arms A-C on the emulator (`R76-1_BATTERY_AB_RESULTS.md:237-250`); record posts that started a
  worker, posts logged as skipped, posts with no log line.
- R-2 (decision rule): if any post leaves no log line, add a log line at the drop point; if every drop is explained
  by `kMinScanSpacing`, record that and close.
- R-3: record whether alarm and WorkManager starts still coexist on 0.22.0, with counts.

**Affected components / files**: the results doc; if R-2 fires, the listener or trigger drop point.

**Parity**: Android only (the trigger exists only on Android; Windows and iOS have none, ADR-0049 / ADR-0050).

**Dependencies / blockers**: emulator windows (about 20 minutes each).

**Acceptance criteria**: AC-1: the three arms recorded with counts. AC-2: every post has a log line, or the added
line is tested.

**Tests to write**: T-1 (AC-2) TEST-UNIT for any added log line; else none.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku for the analysis; Sonnet if a log line is added -- *why*: native listener code. **Step-types**: DATA,
TEST-UNIT. **Est-Effort**: 45-90m + emulator time.

## Task 10 -- F300: WinWright sweep per-step cost (Priority 30)

**Value**: This shortens the Phase 5 sweep from about 15 minutes, or names why it cannot be shorter.

**Requirements**:
- R-1: time each `ww_*` call in one default-sweep run; report the slowest step types.
- R-2: compare with the semantics-tree delay seen in Sprint 80 (10-41 s after the window appears).
- R-3: lower `WaitForWindowSec` and `stepTimeoutMs` where the measurement supports it.

**Affected components / files**: `scripts/run-winwright-tests.ps1` (timing output), the master-plan card.

**Callers of any guard being changed**: the runner is launched by Phase 5.1.5 only; no app code changes.

**Parity**: Windows test harness only; Android and iOS have no WinWright sweep (their UI tests are Flutter widget
tests, which run on every platform's shared code).

**Dependencies / blockers**: PC unlocked during the run (the runner refuses a locked PC).

**Acceptance criteria**: AC-1: the sweep runs under 5 minutes with 0 skipped steps and no DB drift, or the per-step cost
is named with its mechanism and a vendor or source citation.

**Tests to write**: T-1 (AC-1): two timed sweep runs, before and after.

**Definition of Done**: None -- default DoD only.

**Model**: Sonnet -- *why not Haiku*: diagnosis with an unknown cause. **Step-types**: WINWRIGHT-DISCOVERY (time-box
90m). **Est-Effort**: 60-90m.

## Task 11 -- IMP-2b: process tree of a background task that stays open (Sprint 80 carry-in)

**Value**: This settles the cause of the Sprint 80 11-hour open task.

**Requirements**:
- R-1: the next time a background task stays open after its script prints an error, capture
  `Get-CimInstance Win32_Process` with ParentProcessId for its tree, and record it in this plan.
- R-2: if no occurrence by Manual Validation, record "not reproduced" and keep the instruction in
  `SPRINT_RESUME_GUIDE.md`.

**Affected components / files**: this plan; `docs/SPRINT_RESUME_GUIDE.md`.

**Parity**: N/A (developer tooling on Windows).

**Dependencies / blockers**: an occurrence.

**Acceptance criteria**: AC-1: a captured tree with the holding process named, or "not reproduced" recorded.

**Tests to write**: none.

**Definition of Done**: None -- default DoD only.

**Model**: Haiku. **Step-types**: DOCS. **Est-Effort**: 15-30m.

## Execution record (Phase 4)

Delegation: Tasks 3, 4+6, 5 and 7 ran as Sonnet sub-agents in the shared tree (no git; the main session staged by
name and committed); Task 8 ran as a Sonnet sub-agent in its own git worktree and was cherry-picked. Every prompt
carried the delegation checklist verbatim. The main session (Opus 5.5) did the planning, Tasks 0, 1, the ADR-0029
record, the merges and every verification re-run.

- **Task 0 (#508)**: DONE 3e27e5d5. Version gates 12 passed. Executed-by: Opus 5.5 main session -- 10-minute
  bookkeeping bundled with the approval commit (single-session note above).
- **Task 1 (#509)**: walkthroughs DONE b726683e (`docs/IOS_SETUP.md`); AC-2/AC-3 wait on Harold's console steps.
  Executed-by: Opus 5.5 main session (single-session note).
- **Task 2 (#510)**: unsigned compile job DONE (7eadfe2e); run 40012148625 on `macos-26` GREEN (`flutter build ios
  --release --no-codesign`). Signing and TestFlight BLOCKED on Harold (enrollment + API key; stopping criterion 2).
  Finding: `workflow_dispatch` needs the file on the default branch (gh: "HTTP 404: workflow ios.yml not found on
  the default branch"), so a feature-branch `push` trigger limited to `mobile-app/ios/**` was added.
- **Task 3 (#511)**: DONE 506a789a (project generated on Windows -- settles the R-1 unverified line), 508cb8e4
  (plist, AppDelegate, capabilities). 57 tests; 9 of 9 mutants killed; AC-3 met by run 40012148625. Judgment: the
  database stays in Application Support (only exports in Documents); deployment target iOS 15.0 (template floor).
  Known gap for F67c: no iOS notification initialization yet (failures are caught). Executed-by: Sonnet sub-agent.
- **Task 4 (#512) + Task 6 (#514)**: DONE fd12e065 (one commit: both edit the same database_helper and
  email_scanner regions). Schema v14 and v15. 26 of 26 mutants killed; dev-DB copy migrated v13 -> v15 with 13,584
  email_actions rows kept. Executed-by: Sonnet sub-agent.
- **Task 5 (#513)**: DONE 5b87e362. JVM 3 + Dart 10 tests; 7 mutants killed (Kotlin mutants' compile judged by
  reading -- mutation-test.ps1 does not parse Kotlin errors). AC-3 (Fold log) at Manual Validation. Executed-by:
  Sonnet sub-agent.
- **Task 7 (#515)**: ADR-0029 amended b726683e; code DONE cad811f4. 7 new tests, 7 of 7 mutants killed. Executed-by:
  Opus 5.5 for the ADR record (as assigned), Sonnet sub-agent for the code.
- **Task 8 (#516)**: DONE d7ee2c2f (cherry-pick of worktree 2ba7514e, schema v16). 17 of 17 mutants killed. Full
  suite on the merged tree: 3,275 passed, 15 skipped, 0 failed; flutter analyze clean. Executed-by: Sonnet sub-agent.
- **Task 9 (#517)**: emulator arms after the Task 10 sweep (builds serialized).
- **Task 10 (#518)**: runner timing DONE 27b99ad4; sweep measured about 62 s on the 0.22.0 dev build (bc4676de). AC
  met.
- **Task 11 (#519)**: DONE. AC-1 met: holding process named, the adb server (`adb -L tcp:5037 fork-server server`).
  Occurrences: two Task 9 background builds (2026-10-23 6:25 PM and 7:03 PM) printed "Done!" and stayed open;
  `gradlew --stop` did not release the first; `adb kill-server` released both within 6 s. Mechanism, by probe
  (2026-10-24, `scratchpad\t11\probe.ps1`): the build script kills every adb process and the next inline
  `& adb devices 2>&1` auto-starts a server that inherits the script's handles; the task hangs only when the caller
  redirects the script (`*> build.log`) -- inline start and capture alone closed normally. Prevention (scope
  addition, developer tooling, 1 file): `build-with-secrets.ps1` `Start-AdbServerDetached` at all 3 start points;
  the probe under the redirect closed in the same second, and the real background build (2026-10-24) closed at
  01:15:52, the second its log ended "Done!", with the server it started at 1:15:48 still running.
  `Start-Process -Wait` was tried first and hangs too (waits for the process tree). Guide: `SPRINT_RESUME_GUIDE.md`
  section 10a. Earlier event (not this shape): a `flutter_tester` (PID 57940) held `sqlite3.x64.windows.dll` after
  its agent was stopped.
- **Dev DB**: `spam_filter.db.pre_v16_20261023_154626` (+ -shm, -wal) taken with the dev app stopped, before the first
  0.22.0 launch migrates v13 -> v16.

## Carry-ins (kept from the stub)

- **0.21.0 store updates** (Harold): DONE 2026-10-24. Harold's screenshot shows the prod Windows app (no [DEV]) on
  Review No Rule Items at "Version 0.21.0", and Harold: *"phone app updated to 0.21.0 with phone tethered for
  download"*.
- **R-2: the new-mail trigger on the Fold** (#471 remainder): read the `new-mail-diagnostics` line from the first
  0.21.0 Fold log, the first start after the update AND a later start (Sprint 80 retro IMP-5).
- **Sprint 80 retro IMPs live**: IMP-1 (native OS surfaces rehearsed by looking), IMP-1.1 (tray icon first),
  IMP-2a (highest-API AVD), IMP-3 (questions carry what they decide; standing facts not asked again).
- **Standing facts (Harold)**: Fold notification access for the app is ON and stays on.
- **Process (Sprint 80 Q3-Q6, live)**: PR draft until 7.7.5; 7.7.1 reviews on the draft with the retrospective prompt;
  one improvement review; CI run 1 by hand on the draft, run 2 at `gh pr ready`.
