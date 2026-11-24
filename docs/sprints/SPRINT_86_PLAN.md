# Sprint 86 Plan

**Status**: APPROVED 2026-11-24 (Harold: "Sprint plan approved as amended (with any comments I provided), proceed with execution."; answers "q7. 1 q8. 1 q9. 2 and track q10. 2"). Written 2026-11-23.
**Branch**: `feature/20261122_Sprint_86` (from the Sprint 85 branch). **PR**: #577 (draft, to `develop`).
**Cards**: Task 0 #578 (version), Task 1 #579, Task 2 #568 (reused), Task 3 #580, Task 4 #581, Task 5 #582,
Task 6 #583, Task 7 #584, Task 8 #585, Task 9 #586, Task 10 #587, Task 11 #588.
**Version**: 0.26.0+24 (register q10 = 2, MINOR), bumped at 3.7.0b on 2026-11-24; "Last uploaded to Play" moved to
0.25.0 (versionCode 23) in the same commit.

## Scope source

- **Harold, 2026-11-23 (verbatim)**: "Sprint 86 Scope should include the below items. Please complete sprint
  planning (/docs/sprint_planning.md) for the below items and present for approval. Note that everything needs to
  take into account the Windows App, Android app and the iPhone app with the ADR stating that everything should be
  functionally and UI the same unless it cannot be - and where it cannot be it should be implemented as a platform
  exception for what is needed -- this applies to all backend code, frontend code, data, architecture, development,
  security, testing, deployment." Items: F362, F307, F336, F361, F346, F347, F359, F340, F344.
- **Not in that list, but placed in Sprint 86 earlier by Harold**: F363 task clock (register d2) and F364 Google
  Play policy analysis (register d4). Planned below as Tasks 10 and 11; **register q7 = 1, keep both** (Harold, 2026-11-24) (keep both, drop
  both, or keep one).
- Register q6 (scope additions) is answered by the list above.

## Carried in from the Sprint 85 stub

- **0.25.0 store updates**: DONE in the Sprint 85 cycle Phase 8.3; MSIX and AAB submitted, in rollout (Harold,
  2026-11-23). Android 0.25.0 seen running on the Fold (`docs/STORE_VERSION_STATUS.md`).
- **Manual Validation carried from Sprint 85**: iPhone (F67a #509, F304 #510, F67b #523) waits on Apple's approval of
  enrollment `R6QG2A9SHS` (stopping criterion 2). None else.
- **Sprint 85 retrospective carry-ins (Harold, 2026-11-21)**:
  - i1 (live): 5.1.2 findings are fixed at 5.1.2 under the 7.7.1 rule; a finding left open is a numbered question at
    the MV handover and is recorded as `5.1.2 open findings: <list> / none` in the plan's MV section.
  - i2 (live): 5.1.2 class 3 traces every CHANGELOG line added and the Help page of every changed screen to code, as
    `<claim>: <file:line>` in the F-PRECHECK record.
  - i3 (live): a failure that changes what the user sees shows its reason on that screen.
  - i4 (live): port cards fill "Error paths" (with a test that runs a real failing command) and "Gates by file type".
  - i5 (live, gated): "Port of existing code" and "Old name search" lines hold their RESULTS on the line itself;
    close-out check 3d-4 blocks this sprint's close-out otherwise.
  - i6 (live): 5.1.9 steps Claude cannot rehearse record `Precondition: <what>: <how checked>`.
  - i7 (live): each task's CODING_VELOCITY row gets `Started <date HH:MM>` when the task starts.
  - i8 (tracked): a Windows SDK check before a Windows build; propose again if a toolchain update breaks the build.

## Sprint objective

Finish the decision-register process (F362, F361), remove the dead "Create rule" page (F307), add the two log lines
that name the cause of the phone's background-scan stops and IMAP timeouts (F346, F347), put the phone-only Android
paths under an emulator test (F359), and continue the Python tooling work (F336, F340, F344). With q7 = keep: the
task clock (F363) and the Play policy compliance analysis (F364).

## Platform parity (ADR-0042, ADR-0050) -- applies to every card

Every card names its effect on the **Windows app, the Android app and the iPhone app**. Shared Dart is the default
and behaves the same on all three. A difference is allowed only where the platform cannot do the same thing, and
then it is a declared platform exception (ADR-0042; iOS exceptions in ADR-0050) with both branches tested. Cards
that change only development tooling (scripts, hooks, docs) say so; tooling runs on the Windows development PC, and
the iPhone build runs on the GitHub `macos-26` runner. The iPhone device checks still wait on Apple's approval of
enrollment `R6QG2A9SHS` (F67a/F304/F67b), so iPhone evidence in this sprint is the iOS Simulator CI job and code
review, not a device.

## Model assignment summary (cheapest first)

- Haiku: Task 2 (F307), Task 4 (F361), Task 8 (F340), Task 1 docs part (F362).
- Sonnet: Task 3 (F336), Task 5 (F346), Task 6 (F347), Task 7 (F359), Task 9 (F344), Task 10 (F363).
- Fable/Opus: Task 11 (F364) -- policy research where a wrong claim drives a compliance decision.
- Sub-agent tasks run on their assigned tier with the delegation checklist. Main-session work runs on the session
  model; each `Executed-by` line names the model that ran it.

## Estimates

Card estimates from the refinement slate, in minutes (CODING_VELOCITY step-type bands; DOCS and SVC-EDIT at the low
end per the Sprint 49 note). Phase 3.2.2.1 findings below changed none of them.

- Harold's nine: 545-855m.
- With F363 and F364 (q7 = keep both): 785-1245m.

## Phase 3.2.2.1 plan-to-branch verification (2026-11-23)

- F307: `RuleQuickAddScreen` is still called from `no_rule_review_screen.dart:603` (the card said :520; the line moved)
  and `email_detail_view.dart:551`; tests in `f298_quick_add_test.dart`, `rule_quick_add_screen_test.dart`,
  `no_rule_review_heuristics_test.dart:202,210`; help `assets/content/help/rule_quick_add.md` (manifest key
  `ruleQuickAdd`); `docs/ARCHITECTURE.md:801`. Not done.
- F346: `onWorkerStopped` at `lib/core/services/android_background_scan_worker.dart:107`; reason map at :244. The
  battery channel `isIgnoringBatteryOptimizations` exists (`android_battery_status.dart:34`, `MainActivity.kt:125`).
  Not done.
- F347: the 20 s timeout is `lib/core/security/imap_certificate_trust.dart:371` (`ImapTlsConnector.connect`; the card
  path said `adapters/...`). `connectivity_plus ^5.0.0` is already a dependency (`pubspec.yaml:59`). Not done.
- F359: `integration_test/` has no WorkManager, lock or enable-dialog test. Not done.
- F336: the seven `.ps1` files exist, 820 lines. Not done.
- F340: `.claude/scripts/` holds the three `.ps1` files; `.claude/skills/memory-restore/SKILL.md` exists. Not done.
- F344: no inventory exists. Not done.
- F361: Effort line is `SPRINT_EXECUTION_WORKFLOW.md:1382` ("Effort: <minutes, and the number of files>"). Not done.
- F362: `docs/DECISION_REGISTER.md` exists (q1-q6, d1-d4). R-1 to R-3 practised since 2026-11-23; R-4 and R-5 not done.
- F363: no `task-clock.py`; `.claude/settings.json` matchers are `Bash|PowerShell` only. Not done.
- F364: no analysis file. Not done.

## Architecture impact check (3.6.1)

- F307 removes a screen: `docs/ARCHITECTURE.md:801` row removed; the help asset and manifest key removed.
- F363 (if kept) adds hooks and a ledger file: `docs/ARCHITECTURE.md` has no hook section; the hook list in
  `.claude/hooks/README` (if present) and CLAUDE.md are updated in the card.
- F336, F340, F344 follow ADR-0051 (Python for deterministic tooling); each records its file classification there.
- F346, F347 add log lines only; no ADR change. F346 declares an Android exception (WorkManager stop has no Windows
  equivalent; iOS checked in the card).
- No new ADR.

## Tasks

### Task 1 -- F362: Store every question, decision and improvement in full, and re-ask an open one in full (Priority 34)

**Value**: This prevents a question or decision from existing only in the terminal, where it scrolls away.

**Requirements**:
- R-1: every question, decision and improvement put to Harold is written to `docs/DECISION_REGISTER.md` in full when
  asked: id (q/i/d, counters never reused), what it decides, each option with pros and cons, the recommendation,
  later Harold's verbatim answer and date. (Practised since 2026-11-23; this card writes it into the process docs.)
- R-2: the register Index lists every open item; an item leaves Open only when answered or withdrawn.
- R-3: a message that needs an answer copies the full entry from the register.
- R-4: per register q9: either (1) close-out check in `verify-closeout-complete.py` blocks while an Open item from this
  sprint has no answer, or (2) documentation only.
- R-5: CLAUDE.md (question-format rule), `SPRINT_EXECUTION_WORKFLOW.md` 7.3 STEP 5, `SPRINT_RETROSPECTIVE.md`
  template name the register as the place to write them.

**Affected components / files**: `docs/DECISION_REGISTER.md`, `CLAUDE.md`, `docs/SPRINT_EXECUTION_WORKFLOW.md`,
`docs/SPRINT_RETROSPECTIVE.md`; with q9 = 1 also `.claude/hooks/verify-closeout-complete.py` and
`.claude/hooks/test-cases/`.

**Existing abstraction checked**: close-out checks in `verify-closeout-complete.py` (3d-2, 3d-3, 3d-4); a new check
follows their pattern (fail closed, prints what it read).

**Platform**: development process only; no app code. Windows, Android and iPhone apps unchanged.

**Dependencies / blockers**: register q9 answered before approval.

**Acceptance criteria**:
- AC-1: the three docs name `docs/DECISION_REGISTER.md` (grep shows each). RESULT 2026-11-24: CLAUDE.md 1,
  SPRINT_EXECUTION_WORKFLOW.md 2, SPRINT_RETROSPECTIVE.md 1, SPRINT_CHECKLIST.md 1 (the q9 "track" line).
- AC-2: DROPPED by register q9 = 2 (Harold, 2026-11-24: documentation only, "and track"). Replaced by the close-out
  checklist line "Decision register open items listed" and the retrospective Category 9 count.

**Tests to write**:
- T-1 (AC-1) -- the grep above. No gate, so no hook case (q9 = 2).

**Definition of Done**: default DoD. Effort for test time (F361): +0 (q9 = 2, no gate).

**Model**: Haiku for the docs (the gate half was dropped by q9 = 2).
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: Opus main session (not Haiku: four short doc edits beside the main-session Task 10 work; delegating would cost more than the edits) -- 20 min (task clock 2026-11-24 01:54 to 2026-11-24 02:14, 1 segment(s))
**Step-types**: DOCS, HOOK
**Est-Effort**: 45-60m

### Task 2 -- F307: Remove the "Create rule" page (RuleQuickAddScreen) (Priority 36)

**Value**: This removes a page whose Subject, Body and Body URL fields cannot be edited and whose pencil does
nothing, so the user is not offered a broken rule editor.

**Requirements**:
- R-1 (audit first): confirm the F306 rule popup on Review No Rule Items covers what the page did for each of its
  four condition buckets (From header, subject, body, body URL); record the result per bucket with file:line. A gap
  stops the removal and becomes a question.
- R-2: delete `lib/ui/screens/rule_quick_add_screen.dart`, its two callers (`no_rule_review_screen.dart:593-610`
  "Create rule" action, `email_detail_view.dart:551`), its help asset `assets/content/help/rule_quick_add.md` and
  the manifest key `ruleQuickAdd`.
- R-3: delete or update the tests: `rule_quick_add_screen_test.dart`, `f298_quick_add_test.dart` (the cases that
  open the page), `no_rule_review_heuristics_test.dart:202,210`.
- R-4: update `docs/ARCHITECTURE.md:801`, the comments in `rule_conflict_resolver.dart:5,44`, and the Help text of
  Review No Rule Items if it names "Create rule".

**Affected components / files**: listed in R-2 to R-4.

**Existing behavior relied on**: F306 covers the four buckets -- verified at task start (R-1), not assumed.

**Old name search**: `RuleQuickAddScreen`, `rule_quick_add`, `ruleQuickAdd`, "Create rule" -- hits (2026-11-24): none
in `lib/`, `integration_test/`, `scripts/`; `assets/` only `assets/content/audit-log.md` (history). Kept on purpose:
"Create rule" in `test/integration/sprint_6_quick_add_workflow_test.dart` and `enhanced_deletion_test.dart` (means
"make a rule"), and in `no_rule_review_heuristics_test.dart` (asserts the button is gone); sprint history, CHANGELOG
history and `docs/research/R76-3` (history).

**Result**: R-1 audit, no gap. From header (Block Email / Exact Domain / Entire Domain) and Block Subject are on the
pop-up (`email_detail_popup.dart` ~1095-1227, saved by `rule_quick_action_service.dart:447-474`); a typed body phrase
is on Rules > Add block rule (`ManualRuleType.bodyPhrase`). The removed page never stored subject, body or URL text
(controllers never set; pencil a no-op at `rule_quick_add_screen.dart:715-719`). One partial: the pop-up blocks the
FIRST outside link domain only, while `EmailDetailView`'s removed item offered up to 5 -- but `EmailDetailView` has no
production caller (tests only), so no user loses a route; recorded, not reopened. `flutter analyze` clean; T-1
mutants (button re-added; row tap no-op) KILLED.

**Callers of any guard being changed**: N/A (a removal; the two callers are removed with it).

**Observable behavior -- before / after**: BEFORE: Review No Rule Items shows a "Create rule" button that opens a page
with a From pattern and three uneditable patterns. AFTER: no "Create rule" button; rules are made from the existing
rule popup (F306) on the same screen.

**Platform**: shared Dart; the same removal on Windows, Android and iPhone. No exception.

**Dependencies / blockers**: F306 (shipped Sprint 82). Card #568 (reused).

**Acceptance criteria**:
- AC-1: the Old name search finds no hit in `lib/`, `test/`, `integration_test/`, `assets/` (docs history excepted).
- AC-2: Given Review No Rule Items with a No rule email, When the user opens its actions, Then no "Create rule" action
  is shown and the F306 rule popup still opens.
- AC-3: `flutter analyze` clean; full suite green; the iOS Simulator CI job green.

**Tests to write**:
- T-1 (AC-2) -- TEST-WIDGET in `test/ui/screens/no_rule_review_heuristics_test.dart`: the action list has no "Create
  rule" and the rule popup opens.
- T-2 (AC-1) -- the grep, recorded on the Old name search line.

**Definition of Done**: default DoD; CHANGELOG `fix`/`chore` entry naming the removal; WinWright scripts that
navigated to the page updated (grep `test_*.json`).

**Model**: Haiku -- the R-1 audit result decides go or stop; removal is mechanical.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: Haiku sub-agent (as assigned) -- 87 min (task clock 2026-11-24 01:46 to 2026-11-24 04:25, 1 segment(s)); the agent ran about 150 min (harness duration 9017984 ms); the clock closed at its first interim stop at 87 min, an F363 defect fixed the same day (a later SubagentStop now moves the end)
**Step-types**: UI-MOVE, TEST-WIDGET, DOCS
**Est-Effort**: 45-75m
_**Decision-class interrupts**_: an R-1 gap (the popup cannot make a rule the page could) is a Class-2 question.

### Task 3 -- F336: Python conversion batch S7: emulator, adb and Android helper scripts (Priority 37)

**Value**: This finishes the ADR-0051 move of the Android helper scripts to Python, so one tested language runs the
tooling.

**Requirements**:
- R-1: port `mobile-app/scripts/run-emulator.ps1` (83), `start-emulator.ps1` (54), `setup-android-oauth.ps1` (163),
  `export-tokens-for-android.ps1` (114), `capture-diagnostic-logs.ps1` (303), `enable-screen-reader-flag.ps1` (46),
  `fix-flutter-git.ps1` (57) to Python (`py -3.14` style of the existing `scripts/*.py`), or record "stays PowerShell"
  with the reason (`enable-screen-reader-flag` is a Windows API call; decide).
- R-2: resolve tools through `ANDROID_HOME` / `flutter_support.find_tool`, never a hardcoded path (CLAUDE.md
  Sprint 67 IMP-3).
- R-3: each original reviewed for defects first; the port fixes or keeps each with a note.
- R-4: delete each ported `.ps1` and update every reference (Old name search).

**Affected components / files**: the seven scripts; new `mobile-app/scripts/*.py`; `scripts/tests/`; docs that name
them.

**Port of existing code**: (results at completion, per file)
- Error paths: (at completion) ; real failing command tested in: (at completion)
- Gates by file type: (at completion)

**Old name search**: each `.ps1` name -- hits: (at completion)

**Platform**: development tooling on the Windows PC; targets the Android emulator (adb is allowed on the emulator,
never on the phones). Windows and iPhone apps unchanged. iPhone has no equivalent scripts (the Mac runner builds it).

**Dependencies / blockers**: none.

**Acceptance criteria**:
- AC-1: each ported script runs against the emulator (launched and left running) with the same result as the `.ps1`.
- AC-2: a unittest per script covers path resolution and one REAL failing command (missing executable or non-zero
  exit) reported as a failure.
- AC-3: Old name search shows no live reference to a deleted `.ps1`.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT in `scripts/tests/test_android_helpers.py`.
- T-2 (AC-1) -- manual emulator run, recorded in the plan.

**Definition of Done**: default DoD; close-out check 3d-4 passes on this card's Port and Old name lines.
Effort for test time (F361): +7-10 unittests, about +1-2 s locally and in CI.

**Model**: Sonnet -- *why not Haiku*: ports need defect review and real failure-path tests (Sprint 85 7.7.1 found 8
class-B port defects).
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: (at completion)
**Step-types**: SVC-NEW (tooling), TEST-UNIT
**Est-Effort**: 150-260m [estimate unverified]
_**Risk & rollback**_: a broken port blocks emulator work; rollback is `git revert` of the port commit (the `.ps1`
returns).

### Task 4 -- F361: Retrospective improvement Effort states what the change adds to full-suite and CI test time (Priority 38)

**Value**: This shows the cost of each improvement in test time before Harold approves it.

**Requirements**:
- R-1: `SPRINT_EXECUTION_WORKFLOW.md:1382` Effort field gains: time added to the local full suite (`flutter test`,
  Python tests, hook cases) and to CI, in seconds or minutes, with how it was measured or estimated; "+0" when none.
- R-2: the CLAUDE.md retrospective-improvement exception line and `SPRINT_RETROSPECTIVE.md` template say the same.

**Affected components / files**: `docs/SPRINT_EXECUTION_WORKFLOW.md`, `CLAUDE.md`, `docs/SPRINT_RETROSPECTIVE.md`.

**Platform**: development process only; no app code.

**Dependencies / blockers**: pairs with Task 1 (same docs; serialize the edits).

**Acceptance criteria**:
- AC-1: the three docs carry the two-part Effort text (grep).

**Tests to write**:
- T-1 (AC-1) -- the grep, recorded at completion.

**Definition of Done**: None -- default DoD only. Effort for test time: +0.

**Model**: Haiku -- doc wording.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: Opus main session (not Haiku: three one-line doc edits in files Task 1 had just edited; serialized in-session as the plan required) -- 5 min (task clock 2026-11-24 02:15 to 2026-11-24 02:19, 1 segment(s))
**Step-types**: DOCS
**Est-Effort**: 30-45m

### Task 5 -- F346: Log the device state when WorkManager stops a background scan (Priority 38)

**Value**: This names which device state stopped a background scan, so the 3 unexplained AOL stops
(`reason=deviceState raw=4`) can be diagnosed.

**Requirements**:
- R-1: at `onWorkerStopped` (`android_background_scan_worker.dart:107`), write one diagnostic line with power-save
  mode, device-idle mode and thermal status (Android `PowerManager`).
- R-2: read them through the existing battery method channel (`android_battery_status.dart`, `MainActivity.kt:125`),
  extended with the three values; a value that cannot be read is logged as "unknown", never skipped.
- R-3: iPhone: check whether `workmanager_apple` exposes a BGTask expiration callback; if yes, log the same line
  there; if no, record the declared ADR-0050 exception (no stop event to log).

**Affected components / files**: `android_background_scan_worker.dart`, `android_battery_status.dart`,
`MainActivity.kt`.

**Existing abstraction checked**: `AndroidBatteryStatus` channel -- the new values are new members of it.

**Existing behavior relied on**: the method channel is reachable from the WorkManager background isolate -- verified
at task start (`MainActivity` registers it on the main engine; the worker engine may not have it). If not reachable,
read the values in a background-engine channel and record it.

**Platform**: Android exception (ADR-0042: only WorkManager reports a stop reason). Windows: Task Scheduler gives no
stop event; no change. iPhone: R-3.

**Dependencies / blockers**: none.

**Acceptance criteria**:
- AC-1: a stop with `reason=deviceState` writes a line containing `powerSave=`, `deviceIdle=`, `thermal=` values.
- AC-2: a channel failure writes the line with `unknown` values and does not throw out of `onWorkerStopped`.

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-UNIT in `test/core/services/android_background_scan_worker_test.dart` with a faked channel.
- T-2 (AC-1) -- emulator check in Task 7's harness if it reaches `onWorkerStopped`; else a manual emulator run.

**Definition of Done**: default DoD; mutation-checked T-1.

**Model**: Sonnet -- *why not Haiku*: a method channel from a background isolate (the Sprint 79 wrong-thread
`onStopped` history).
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: (at completion)
**Step-types**: SVC-EDIT, NATIVE-ANDROID, TEST-UNIT
**Est-Effort**: 30m (likely 30-60m if the background isolate needs its own channel)

### Task 6 -- F347: Log the phase and network type of an IMAP connect timeout (Priority 40)

**Value**: This names where an IMAP connect stalls (DNS, TCP, TLS) and on which network, so the AOL 20-second
timeouts on the phone can be diagnosed.

**Requirements**:
- R-1: in `ImapTlsConnector.connect` (`imap_certificate_trust.dart:366-371`), time and name each phase (DNS lookup,
  TCP connect, TLS handshake); on a timeout, log the phase that did not finish and the elapsed time of each.
- R-2: log the network type at the time (wifi, mobile, ethernet, none) from the existing `connectivity_plus`
  dependency; "unknown" if it cannot be read.
- R-3: the timeout value and error the caller sees stay the same.

**Affected components / files**: `lib/core/security/imap_certificate_trust.dart`; tests beside
`imap_certificate_trust_test.dart`.

**Existing behavior relied on**: AOL and the other app-password providers connect through `ImapTlsConnector.connect`
-- verified at task start (grep its callers in `generic_imap_adapter.dart`).

**Callers of any guard being changed**: every IMAP account connect goes through it; R-3 keeps their behavior.
- Catches between any NEW throw and its handler: none (no new throw; logging only).

**Platform**: shared Dart, the same on Windows, Android and iPhone; `connectivity_plus` supports all three. No
exception.

**Dependencies / blockers**: none.

**Acceptance criteria**:
- AC-1: a forced TCP-phase timeout logs `phase=tcp` with the network type; a forced TLS-phase timeout logs
  `phase=tls`.
- AC-2: the exception type and message thrown to the caller are unchanged (test asserts both).

**Tests to write**:
- T-1 (AC-1, AC-2) -- TEST-UNIT in `test/core/security/imap_certificate_trust_test.dart` with a local socket that
  accepts and never answers TLS, and an unroutable address for TCP.

**Definition of Done**: default DoD; mutation-checked; no email address or host secret in the log line (redaction
gate `scripts/check-log-redaction.py`).

**Model**: Sonnet -- *why not Haiku*: the connect path every IMAP account uses.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: (at completion)
**Step-types**: IMAP, TEST-UNIT
**Est-Effort**: 45m

### Task 7 -- F359: Android emulator integration test for the paths only a phone found (Priority 40)

**Value**: This catches on the emulator the Android-only defects that, in Sprints 78-84, only a phone found.

**Requirements**:
- R-1: an `integration_test` run on the Android emulator for: WorkManager worker start and stop, the per-process
  file lock in the diagnostic log (two isolates, one process), and the background-scan enable dialog.
- R-2: a runner entry (`scripts/run-integration-tests.py` option) that launches the emulator through `ANDROID_HOME`,
  leaves it running, and reports per-test results.
- R-3: iPhone: the per-process lock is also a POSIX record lock on iOS; add the lock case to the iOS Simulator CI
  gate if it runs there; else record why not.

**Affected components / files**: `integration_test/android_phone_paths_test.dart` (new);
`scripts/run-integration-tests.py`.

**Platform**: Android exception for the WorkManager case (ADR-0042). The lock case runs on Android and iOS Simulator;
on Windows the lock is per handle and is covered by the existing host tests. The enable dialog is shared Dart; its
host widget test already covers Windows.

**Dependencies / blockers**: the emulator image (Google APIs) present; Windows and Android builds serialized.

**Acceptance criteria**:
- AC-1: the three cases pass on the emulator; each fails when its guarded code is broken (mutation run on the
  emulator, recorded).
- AC-2: the runner returns non-zero when a case fails.

**Tests to write**:
- T-1 (AC-1) -- TEST-INTEGRATION `integration_test/android_phone_paths_test.dart`.
- T-2 (AC-2) -- TEST-UNIT in `scripts/tests/` for the runner exit code.

**Definition of Done**: default DoD; emulator left running. Effort for test time (F361): local +2-4 min per emulator
run (not in the default suite); CI +0 (no emulator job).

**Model**: Sonnet -- *why not Haiku*: a new emulator harness and isolate-level lock test.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: (at completion)
**Step-types**: TEST-INTEGRATION
**Est-Effort**: 120-180m

### Task 8 -- F340: Audit the `.claude/scripts/` memory scripts and the retired `memory-restore` skill (Priority 40)

**Value**: This removes retired tooling that could restore Sprint-39 state into a current session.

**Requirements**:
- R-1: grep callers of `archive-memory.ps1`, `check-memory-on-startup.ps1`, `save-memory.ps1` and the
  `memory-restore` skill (hits today: `.claude/settings.local.json`, the skill itself, `CLAUDE.md`,
  `docs/ALL_SPRINTS_MASTER_PLAN.md`, `docs/PRESENTATION_FRAMEWORK.md`).
- R-2: delete what nothing live calls; convert a survivor under ADR-0051; update every reference.
- R-3: a `.claude/settings.local.json` change is shown to Harold before it is made (local settings file).

**Old name search**: the four names -- hits (grep 2026-11-24, excluding `archive/` and `0*`): no hook, skill, setting
or script calls the three `.ps1` files. Updated: `docs/PRESENTATION_FRAMEWORK.md:391,404-406` and
`docs/adr/0051-python-for-deterministic-tooling.md:179-182`. Kept because they are history: `CHANGELOG.md`,
`docs/sprints/SPRINT_8_*`, `SPRINT_12/22/27/33/51_*`, the backlog slate and the master-plan F340 card. Kept because
the skill stays: `memory-restore` in `CLAUDE.md:822`, `AGENTS.md:650`, `.agents/skills/memory-restore/SKILL.md` and
`.claude/settings.local.json:36` (skill visibility, no change, so R-3 had nothing to show).

**Result (AC-1)**: DELETED `.claude/scripts/archive-memory.ps1`, `check-memory-on-startup.ps1`, `save-memory.ps1`
(the folder is now gone). KEPT `.claude/skills/memory-restore/` -- it is the Sprint 51 tombstone Harold chose over
deletion (F130-S51, CHANGELOG 725); deleting it would reverse that decision, and it holds no script to convert.

**Platform**: development tooling only.

**Acceptance criteria**:
- AC-1: a kept/deleted list with grep evidence; no live reference to a deleted file.

**Tests to write**:
- T-1 (AC-1) -- the grep, recorded on the Old name search line.

**Definition of Done**: default DoD; `/startup-check` still runs.

**Model**: Haiku -- grep and delete.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: Opus main session (not Haiku: the audit found the memory-restore tombstone is a prior Harold decision, a judgment the plan flagged as Class-2) -- 20 min (task clock 2026-11-24 02:21 to 2026-11-24 02:41, 1 segment(s))
**Step-types**: DOCS, HOOK
**Est-Effort**: 20-40m [estimate unverified]

### Task 9 -- F344: Prompts: rewrite the deterministic ones as Python tools; shared helpers for the rest (Priority 39)

**Value**: This moves fixed steps out of prompts into tested Python, so they run the same way every time.

**Requirements**:
- R-1: inventory the prompts outside skills: `.claude/agents/*.md` (5), `docs/STATUS_FOOTER_SETUP_PROMPT.md`, review
  prompts and agent briefs in `docs/`, hook-delivered prompts. Mark each deterministic, hybrid or GenAI.
- R-2: for deterministic and hybrid ones, name the Python helper; build the helpers used by two or more prompts first,
  under `scripts/` with a `.SYNOPSIS` header, and change the prompts to call them.
- R-3: per register q8: move the hook registrations in `.claude/settings*.json` from `python` (3.12.10) to
  `py -3.14`, then run `python .claude/hooks/run-test-cases.py`; or leave them.
- R-4: skill scripts are F339 (not in this sprint); do not duplicate them.

**Affected components / files**: `docs/research/F344_PROMPT_INVENTORY.md` (new), new `scripts/*.py`, the prompts
changed, `.claude/settings.json` (q8 = 1).

**Platform**: development tooling only.

**Dependencies / blockers**: register q8 answered before approval.

**Acceptance criteria**:
- AC-1: the inventory lists every prompt with a disposition.
- AC-2: each shared helper has a unittest including one real failing input; the prompts that use it call it.
- AC-3 (q8 = 1): the hook suite passes under `py -3.14`.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT in `scripts/tests/`.
- T-2 (AC-3) -- `python .claude/hooks/run-test-cases.py` output recorded.

**Definition of Done**: default DoD. Effort for test time (F361): about +1 s per helper unittest file.

**Result**: AC-1 `docs/research/F344_PROMPT_INVENTORY.md`: 28 prompts outside skills, 10 deterministic (9 are the
hooks, already Python), 16 hybrid, 2 GenAI. AC-2: two shared helpers built -- `scripts/quality-gate.py` (analyze
then test, one PASS/FAIL verdict; 8 agent and command prompts call it) and `scripts/subagent-brief.py` (`block`
prints the Progress and restart block, 6 prompts; `files` prints the review file list with the `0*` and `archive/`
exclusions, 3 review prompts); 11 + 10 unittests with real failing inputs; 4 mutants KILLED. Three one-caller
helpers named, not built. AC-3 (q8 = 1): all 12 registrations in `.claude/settings.json` now `py -3.14 ...`
(Python 3.14.10); hook suite 230/230 under it; `run-test-cases.py` and `scripts/test-hook.py` now READ the
interpreter from settings.json (`common.hook_interpreter`; Windows: missing = error; CI: python3 fallback with a
NOTE), so the suite keeps testing the program the real hooks use; runner 30, test-hook 19, settings 5 tests pass.
Test time measured on a loaded machine: 51 s + 95 s for the two new files (unloaded estimate +1-3 s each).

**Model**: Sonnet -- *why not Haiku*: classifying a prompt as deterministic or GenAI is judgment.
**Delegation checklist included in the sub-agent prompt**: yes
**Executed-by**: Sonnet sub-agent (R-1, R-2, R-4, as assigned) plus Opus main session (R-3: a .claude/settings.json change and the runner interpreter design) -- 50 min (task clock 2026-11-24 03:27 to 2026-11-24 04:45, 1 segment(s))
**Step-types**: DOCS, SVC-NEW (tooling), TEST-UNIT
**Est-Effort**: 60-120m [estimate unverified]

### Task 10 -- F363: Task clock (Priority 32) (#587; q7 = 1)

Full card: `docs/ALL_SPRINTS_MASTER_PLAN.md` F363 (R-1 to R-8, AC-1 to AC-5; q2 = 1: Agent, Edit|Write|NotebookEdit
and commit gates). If kept, it runs FIRST so every other task is clocked by it.

**Platform**: development process only; no app code.
**Model**: Sonnet -- *why not Haiku*: three new fail-closed hook matchers that gate every edit and commit.
**Executed-by**: Opus main session (Sonnet assigned; run in-session because every later task depends on the gate, and the gate needed same-session hook facts) -- 109 min (task clock 2026-11-24 01:07 to 2026-11-24 02:55, 1 segment(s)); work began about 01:01, 6 min before the clock existed (the task builds the clock); a first finish at 02:56 failed on a missing Executed-by line and stamped the finish, and the 4 min fix after it is not in the total
**Step-types**: HOOK, TEST-UNIT, DOCS
**Est-Effort**: 180-270m
_**Risk & rollback**_: a wrong gate blocks all work. Built with NO bypass token (the draft said one would exist): the
way past the edit gate is `task-clock.py start <task>`, and the files that fix a broken state (plan, ledger,
CODING_VELOCITY, register, sprint_status.json) are exempt. The 11 mutants were killed before registration and the
full hook suite passed just after it (230/230); rollback is
removing the `task-clock-gate.py` entries from `.claude/settings.json`.
**Result**: `scripts/task-clock.py`, `.claude/hooks/lib/task_clock.py`, `.claude/hooks/task-clock-gate.py`, close-out
`check_task_clock`. Live check 2026-11-24 01:46: four background agents (Tasks 2, 5, 6, 11) each got a ledger start
and their agentId mapped. Tests: 36 unittests, 13 route cases, close-out AC-1 case, git fault-injection test; hook
suite 230/230; mutants 12/12 KILLED. AC-5 (Sprint 86 closes out clocked) is checked at close-out.

### Task 11 -- F364: Google Play policy and Console changes: analysis and compliance cards (Priority 30) (#588; q7 = 1)

Full card: `docs/ALL_SPRINTS_MASTER_PLAN.md` F364 (R-1 to R-5, AC-1 to AC-3). Output
`docs/GOOGLE_PLAY_POLICY_2026-10-29_ANALYSIS.md` and proposed cards as register items. Account is EU non-trader
(register q4 = 2).

**Platform**: Android (Play) analysis; each finding also states whether the Microsoft Store or the App Store has the
same rule, so a fix stays the same on all three where it can (ADR-0042).
**Model**: Fable/Opus -- *why not Sonnet*: every claim needs a same-session source and drives a compliance decision
(CLAUDE.md Sprint 66 IMP-2).
**Executed-by**: Opus sub-agent (as assigned) -- 71 min (task clock 2026-11-24 01:46 to 2026-11-24 03:24, 1 segment(s))
**Step-types**: DOCS (research)
**Est-Effort**: 60-120m [estimate unverified]
**Result**: `docs/GOOGLE_PLAY_POLICY_2026-10-29_ANALYSIS.md` -- 18 topics: 2 APPLY (trader status; deceptive
behavior, no gap), 2 UNKNOWN (memory thresholds, Age Signals), 14 DO NOT APPLY. No deadline for this app before
2026-12-31; the per-rule dates on Google's Policy Deadlines page are 2027-01-27, 2027-04-14 and 2027-08-25, so the
"about 2026-11-28" risk below did not hold. R-5: one bullet in `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`
(`data_safety_declarations_test` 7/7 after it). AC-2: proposed cards F365-F368 are register q12; the trader
decision is register q11; both are asked at Manual Validation.
_**Risk & rollback**_: the 30-day window from 2026-10-29 may already have ended (about 2026-11-28; counting
unverified). Run it first among the analysis tasks.

## Execution order

1. Task 10 F363 (if kept), so every later task is clocked.
2. Task 11 F364 (if kept) and Task 2 F307 in parallel (independent).
3. Tasks 5 F346 and 6 F347 (app logging), then Task 7 F359 (its harness can exercise Task 5).
4. Tasks 1 F362 and 4 F361 (same docs, one after the other), Task 8 F340.
5. Tasks 3 F336 and 9 F344 (tooling).
Windows and Android builds are never run at the same time.

## Manual Validation (Phase 5.3) -- drafted, rehearsed at 5.1.9

- Windows DEV: Review No Rule Items has no "Create rule" action; the rule popup opens (Task 2).
- Android (Fold, closed-test build after release or a DEV build): after the next background stop, the diagnostic log
  has the device-state line (Task 5); after an IMAP timeout, the phase line (Task 6).
- iPhone: Simulator CI evidence only until Apple approves enrollment.

## Standing facts (Harold)

- Background scanning notification access is on and stays on (Sprint 80).

## Open questions (register)

None open. Answered 2026-11-24 (Harold, verbatim "q7. 1 q8. 1 q9. 2 and track q10. 2"):
- q7 = 1: keep F363 and F364 (Tasks 10, 11).
- q8 = 1: Task 9 moves the hook registrations to `py -3.14` and runs the hook suite.
- q9 = 2 "and track": Task 1 adds NO close-out gate (AC-2 and T-1 are dropped). Instead the close-out checklist
  lists every register item still Open as a report line, and the retrospective counts any question that reached
  close-out unanswered; a gate is proposed again if that count is above zero.
- q10 = 2: version 0.26.0+24.
