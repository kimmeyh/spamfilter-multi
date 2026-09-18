# Sprint 70 Plan

**Status**: APPROVED -- Harold, 2026-09-17, "as recommended". Blanket execution approval
through Manual Validation.
**Branch**: `feature/20260914_Sprint_70`
**Planned**: 2026-09-17
**Scope selected by**: Harold, 2026-09-17 (Phase 8.4 backlog refinement pass 2)

## Sprint Goal

Make the app work when a tester uses it normally. Five of the six tasks are defects two external
testers hit on the shipped build; the sixth removes a workaround currently shipping a test
library to those same testers.

## Scope

- **F219** -- Google Sign-In returns `null_intent`. Priority 4. Est 120-240m.
- **F212** -- Re-processing after adding rules fails 100%. Priority 4. Est 120-240m.
- **F220** -- Backgrounding during a live scan wedges scanning until restart. Priority 4. Est 180-360m.
- **F217** -- Background scans do not run while backgrounded or locked. Priority 6. Est 240-480m.
- **F221** -- A superseded live scan stays "in progress" forever. Priority 6. Est 120-240m.
- **F218** -- Flutter SDK upgrade; remove the one-time Gradle workaround. Priority 8. Est 240-480m.

**Total estimated coding time**: 1,020-2,040 minutes (**17 to 34 hours**).

**This is materially larger than recent sprints** (Sprint 69 was 6-11.5h). Flagged, not
challenged -- the scope is Harold's call, and every item in it was found by a real user. But the
upper bound is roughly three Sprint 69s, so the sequencing below puts the riskiest work where a
stopping decision is still cheap.

## Standing constraint -- ADR-0042 cross-platform parity (Harold, restated verbatim)

> "everything needs to take into account both the Windows App and the Android app and ADR
> stating that everything should be functionally and UI the same unless it cannot be - and
> where it cannot be it should be implemented as a platform exception for what is needed --
> this applies to all backend code, frontend code, data, architecture, development, security,
> testing, deployment."

Applied per task, honestly:

- **F219 is ANDROID-ONLY BY NECESSITY.** Windows uses a loopback redirect and has no Android task
  affinity. The manifest is Android's alone; there is no Windows equivalent to fork.
- **F217 is ANDROID-ONLY BY NECESSITY.** Doze and App Standby do not exist on Windows, which uses
  Task Scheduler (ADR-0039). The existing declaration at `background_scan_scheduler.dart:188`
  must be REWRITTEN, not merely kept -- it currently records an expectation the field contradicts.
- **F212, F220 and F221 are SHARED and this is the sprint's main parity risk.** All three touch
  `ScanCoordinator` and the scan lifecycle, which are single platform-blind code paths. A fix
  verified only on Android is not verified. **Every one of these needs a Windows pass**, and F220
  in particular may behave differently because Windows has no equivalent of "the OS tore down
  your sockets".
- **F218 is ALL-PLATFORM by definition.** The SDK is shared; a Windows regression would not
  surface from an Android test.

**Two platform exceptions are anticipated (F219 manifest, F217 background policy).** Both must be
declared in code comments naming WHAT cannot be shared and WHY.

## Audit-first findings (MANDATORY per SPRINT_PLANNING.md, Sprint 65 retro IMP-2)

Performed at planning, 2026-09-17. Every card's central claim was checked against the code.
**All six confirmed; two gained useful detail:**

- **F219** -- `AndroidManifest.xml:31-32` carries `launchMode="singleTop"` and `taskAffinity=""`,
  both confirmed present. Already established 2026-09-16: these are **Flutter template defaults**
  (`flutter create` on 3.38.5 emits them verbatim), not deliberate choices, so there is no
  original intent to preserve.
- **F212** -- `grep ScanCoordinator lib/ui/screens/results_display_screen.dart` returns **nothing**.
  The re-process path genuinely bypasses the coordinator. Harold's hypothesis confirmed.
- **F220 -- PRIOR ART EXISTS, and the card did not know it.** `account_selection_screen.dart:113`
  already implements `didChangeAppLifecycleState`, handling `resumed` to refresh the account list.
  So the pattern is established in this codebase and F220 should MIRROR it rather than invent one.
  That lowers the design risk; the estimate stays because the hard part is what to DO on pause,
  not how to observe it.
- **F217** -- `AndroidManifest.xml` declares **zero** battery-related permissions (no
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `FOREGROUND_SERVICE`, or `WAKE_LOCK`). The app has never
  asked the OS for any exemption, which strongly supports the Doze hypothesis.
- **F221 -- the backstop is narrower than "startup".** `reconcileStaleInProgressScans` exists and
  is sound, but has exactly **ONE caller**: `main.dart:278`. Nothing runs it on resume, on scan
  start, or on screen entry. That is why a restart is the only thing that clears a stuck row.
- **F218** -- both halves still present: the Gradle workaround at
  `android/app/build.gradle.kts` (1 occurrence) and the Flutter SDK's local patch (`git status`
  in `D:\dev\flutter` shows exactly 1 modified file).

---

## Task 1 -- F219: Google Sign-In returns `null_intent` (Priority 4)

**Value**: This restores the primary sign-in path, which is the first thing a new tester tries.

**Requirements**:
- R-1: **Reproduce before changing anything.** Sean and Harold both hit this; confirm it is the
  same failure and capture the exact exception, not the on-screen summary.
- R-2: The leading suspect is `AndroidManifest.xml:32`'s `taskAffinity=""`. Already established
  as a Flutter template default, so there is no original intent to protect -- but **the fix is
  not automatically "delete the line"**. The flutter_appauth threads show both removing it and
  setting an explicit affinity; neither is stated as canonical. **Probe on the S24+ rather than
  reasoning from the issue tracker**, because the reports single out Samsung.
- R-3: **Verify the NEIGHBOURS.** Task affinity governs which task an activity launches into, so
  it affects the whole app, not the OAuth flow. Check: launching from the launcher, returning
  from recents, and the deep-link paths (`app_links` is a dependency).
- R-4: If the fix does not work, the next candidate is the Google Cloud Console **Data Access**
  page listing NO scopes while the app requests `gmail.modify` and `userinfo.email`. Recorded as
  a candidate, not a finding.
- R-5 (ADR-0042): Android-only by necessity. Windows uses a loopback redirect. Declare it.

**Affected components / files**:
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- lines 31-32
- `docs/OAUTH_SETUP.md` -- record the outcome

**Dependencies / blockers**: none. Reproducible on the S24+ today.

**Non-functional requirements**:
- Security: do NOT widen OAuth scopes. `gmail_scope_parity_test` asserts the current set.
- Platform: Android only; Windows unaffected and must stay so.

**Acceptance criteria**:
- AC-1: A listed test user completes Google Sign-In on a Play-installed build without an app
  password.
- AC-2: Launcher start, return-from-recents, and deep-link navigation all still work.
- AC-3: The outcome is recorded in `OAUTH_SETUP.md` -- including if the manifest change was NOT
  what fixed it.

**Tests to write**:
- T-1 (verifies AC-1) -- MANUAL on a Play-installed build, listed test user. No automated test can
  cover an OS-level redirect.
- T-2 (verifies AC-2) -- MANUAL. The neighbour check is the part most likely to be skipped.
- T-3 -- TEST-POLICY: `android_client_id_test` and `gmail_scope_parity_test` stay green.

**Definition of Done**: default PLUS: if the manifest change is not the fix, say so explicitly
rather than leaving a changed line that did nothing.

**Model**: Sonnet -- *why not Haiku*: R-2 is a choice between two documented remedies with
app-wide blast radius, settled by probing rather than by rule.

**Step-types**: DATA (manifest), DOCS, MANUAL

**Est-Effort**: 120-240m

**Risk and rollback**: a task-affinity change affects every activity launch. Mitigation: probe
first, then check the three neighbour paths. Rollback: revert two manifest lines.

---

## Task 2 -- F212: Re-processing after adding rules fails 100% (Priority 4)

**Value**: This restores the app's primary workflow -- review "No rule" mail, add a rule, and have
it actually applied.

**Requirements**:
- R-1: **Get the exception first.** `results_display_screen.dart:3142` logs it. The whole-batch
  `failCount` shape (6 of 6, 8 of 8) indicates ONE throw, not N failures.
- R-2: Harold's hypothesis is code-confirmed and is the leading candidate: the re-process path
  **bypasses `ScanCoordinator` entirely**. The only acquisition site is
  `email_scanner.dart:170`; `results_display_screen.dart:3064` builds its own platform and
  connects directly. So a background scan holding an IMAP session and a user tapping "add rule"
  open two sessions to the same account -- the exact failure F175 was built to prevent.
- R-3: **Route re-processing through the coordinator** if R-1 confirms R-2. Note this makes the
  user wait behind a background scan, which needs the same "waiting for the active scan" message
  the scanner already shows.
- R-4: **Fix the contradictory messaging REGARDLESS of cause.** A green "All 9 'No rule' emails
  addressed." must never appear beside a failed batch.
- R-5 (ADR-0042): SHARED. Verify on Windows AND Android. Do not assume Android-only because that
  is where it was seen.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- approx 3040-3170

**Dependencies / blockers**: **overlaps F220 and F221** -- all three touch coordinator lease
lifetime. Sequence them together.

**Non-functional requirements**:
- Account-scoping: the re-process path builds a fresh platform per account. Keep it scoped.
- Security: credentials load in this path. Do not log them.

**Acceptance criteria**:
- AC-1: The actual exception is recorded before any fix is written.
- AC-2 (behavioral): Given a scan result with "No rule" emails, When a blocking rule is added,
  Then matching emails are acted on and the counter reports the true number.
- AC-3: No success message is displayed when the batch failed, in whole or in part.
- AC-4: Verified on Windows AND Android.

**Tests to write**:
- T-1 (AC-2) -- TEST-UNIT: `successCount` matches actions actually executed.
- T-2 (AC-3) -- TEST-WIDGET: a failed batch renders no "addressed" banner.
- T-3 (AC-4) -- MANUAL, both platforms.

**Definition of Done**: default PLUS: the root cause is named in the commit. "Fixed by retrying"
is not done.

**Model**: Fable/Opus -- *why not Sonnet*: IMAP session state plus coordinator semantics; Sprint 38
showed this area produces Class-1 decisions.

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET

**Est-Effort**: 120-240m

**Risk and rollback**: re-processing DELETES real mail on the closed-test build. Test in read-only
mode first. Rollback: revert the screen file.

---

## Task 3 -- F220: Backgrounding during a live scan wedges scanning (Priority 4)

**Value**: This stops the app silently losing live-scan capability when a user does something
completely ordinary.

**Requirements**:
- R-1: **MIRROR the existing lifecycle observer**, do not invent one.
  `account_selection_screen.dart:113` already implements `didChangeAppLifecycleState` (handling
  `resumed`). Follow that shape -- CLAUDE.md requires reading how existing members of a shared
  abstraction behave before adding a new one.
- R-2: Observe `AppLifecycleState.paused` during an ACTIVE scan and fail the scan explicitly, so
  the `finally` runs and the coordinator lease is released. **That release is the actual fix** --
  the wedge is a held lease, not a stalled socket.
- R-3: **Reconsider the no-timeout decision for manual scans.** `background_scan_core.dart:140`
  justifies it as *"a user is watching and can cancel"*. That premise is false once backgrounded.
  Either add a timeout or state why the lifecycle fix makes one unnecessary -- **this is a
  Class-2 decision** (changing a prior development decision) and must be surfaced, not silently
  reversed.
- R-4: Add `reconcileStaleInProgressScans` on RESUME as a cheap backstop, independent of R-2.
- R-5 (ADR-0042): SHARED code, but the TRIGGER is Android-shaped -- Windows does not tear down
  sockets on minimise. Verify Windows is unaffected rather than assuming; a lifecycle observer
  fires on desktop too.

**Affected components / files**:
- `mobile-app/lib/ui/screens/scan_progress_screen.dart`
- `mobile-app/lib/core/services/email_scanner.dart`
- `mobile-app/lib/main.dart` -- if R-4 adds a resume hook

**Dependencies / blockers**: overlaps F212 and F221.

**Non-functional requirements**:
- The lease MUST be released on every failure path, which is the invariant F175 exists to hold.

**Acceptance criteria**:
- AC-1: Start a live scan, background the app, return -- a new live scan starts successfully
  without restarting the app.
- AC-2: The interrupted scan's row does not remain `in_progress`.
- AC-3: Windows behaviour is unchanged -- proven, not assumed.
- AC-4: The coordinator lease is released when a scan is interrupted.

**Tests to write**:
- T-1 (AC-4) -- TEST-UNIT: a scan failed mid-flight releases its lease.
- T-2 (AC-2) -- TEST-UNIT: an interrupted scan's row resolves.
- T-3 (AC-1, AC-3) -- MANUAL, both platforms.

**Definition of Done**: default PLUS: R-3's decision is surfaced to Harold before implementation,
not reported afterwards.

**Model**: Fable/Opus -- *why not Sonnet*: lease lifetime and failure-path semantics in the
component every scan depends on; a wrong fix here deadlocks all scanning.

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT

**Est-Effort**: 180-360m

**Risk and rollback**: this touches the coordinator every scan type shares. A mistake blocks
scanning entirely. Mitigation: unit-test the lease invariant first. Rollback: revert the observer.

**Decision-class interrupts**: R-3 is Class-2. Surface it.

---

## Task 4 -- F217: Background scans do not run while backgrounded or locked (Priority 6)

**Value**: This is the app's core value proposition on Android. If it does not hold, the product
does not do what it claims.

**Requirements**:
- R-1: **Diagnose with the OS before touching code.** `adb shell dumpsys jobscheduler`,
  `adb shell am get-standby-bucket com.myemailspamfilter` while the phone sits idle. Establish
  what Android thinks it is doing.
- R-2: **Check Samsung's own battery settings** (Settings > Battery > Background usage limits).
  This alone may explain the whole report, and it is free to check.
- R-3: The scheduling code is CORRECT -- `registerPeriodicTask`, 15 minutes, per-account unique
  names, network constraint, exponential backoff. **Do not start by rewriting it.**
- R-4: Audit finding -- the manifest declares NO battery-related permission, so the app has never
  requested any exemption. That is the strongest evidence for the Doze hypothesis.
- R-5: **REWRITE the ADR-0042 declaration** at `background_scan_scheduler.dart:188`. It currently
  says inexact timing is an "accepted difference" because "the scan is periodic hygiene, not a
  deadline" -- written expecting minutes of drift. The field shows 2h42m. The declaration is now
  wrong and must reflect measured behaviour.
- R-6: Confirm whether "no notifications" is a SYMPTOM (no scan ran, so nothing notified) or a
  SECOND defect. Do not assume.

**Affected components / files**:
- `mobile-app/lib/core/services/background_scan_scheduler.dart` -- the declaration, at minimum
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- only if a permission is agreed

**Dependencies / blockers**: EXTERNAL -- needs the S24+ idle for a period to observe real
deferral.

**Non-functional requirements**:
- Battery: any fix trades battery for timeliness. That trade is Harold's to make.
- Play policy: a battery-optimisation exemption is scrutinised at review and needs a listing
  justification.

**Acceptance criteria**:
- AC-1: The OS-level diagnosis is recorded -- what bucket, what the scheduler shows.
- AC-2: The ADR-0042 declaration matches measured behaviour.
- AC-3: If a fix is implemented, background scans run on a schedule a user would recognise as
  periodic with the phone locked.
- AC-4: Windows Task Scheduler behaviour is unchanged.

**Tests to write**:
- T-1 (AC-1) -- MANUAL, adb diagnosis recorded in the card.
- T-2 (AC-3) -- MANUAL, phone locked and idle for a measured interval.
- T-3 (AC-4) -- TEST-POLICY: existing Windows scheduler tests stay green.

**Definition of Done**: default PLUS:
- **The FIX is a Class-1 decision and must be SURFACED, not chosen.** A battery-optimisation
  exemption prompt or a foreground service with a permanent notification both change the app's
  relationship with the OS and with the Play listing. Diagnose fully, present the options, wait.

**Model**: Fable/Opus -- *why not Sonnet*: an OS-behaviour diagnosis whose remedy is an
architectural decision affecting the Play listing.

**Step-types**: DOCS, DATA, MANUAL

**Est-Effort**: 240-480m (diagnosis-heavy; the fix may not land this sprint by design)

**Decision-class interrupts**: Class-1. The card is scoped to DIAGNOSE and RECOMMEND.

---

## Task 5 -- F221: A superseded live scan stays "in progress" forever (Priority 6)

**Value**: This makes Scan History trustworthy and tells the user what the app is doing when they
tap scan twice.

**Requirements**:
- R-1: **Do NOT make a new scan cancel the running one.** The FIFO queue is correct and
  deliberate (F175, built after four stacked AOL scans hit the per-account session cap). Undoing
  it re-opens the Sprint 61 failure. The queue is right; the bookkeeping and messaging are not.
- R-2: **Two defects wearing one symptom**, and they should be fixed as two things:
  (a) the superseded row stays `in_progress`; (b) the user gets no visible explanation that their
  tap queued rather than started.
- R-3: **Audit finding** -- `reconcileStaleInProgressScans` has exactly ONE caller,
  `main.dart:278`, at startup. Nothing runs it on resume, on scan start, or on screen entry.
  Widening WHEN it runs is likely cheaper and safer than new bookkeeping.
- R-4: The scanner already builds a "Waiting for the active scan in progress..." message
  (`email_scanner.dart:151-167`). Check whether it actually REACHES the user before writing a new
  one -- it may exist and be invisible.
- R-5 (ADR-0042): SHARED. Both the coordinator and the scan-result store are platform-blind.

**Affected components / files**:
- `mobile-app/lib/core/storage/scan_result_store.dart` -- the reconciliation call sites
- `mobile-app/lib/core/services/email_scanner.dart` -- the waiting message path
- `mobile-app/lib/main.dart`

**Dependencies / blockers**: overlaps F220 heavily -- a wedged scan is WHY rows stick. **Do F220
first**; part of this may resolve with it.

**Acceptance criteria**:
- AC-1: Starting a second live scan leaves no row permanently `in_progress`.
- AC-2: The user sees that their scan is queued, not ignored.
- AC-3: Concurrent scans are still SERIALISED -- F175's invariant holds.
- AC-4: Verified on Windows and Android.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT: a superseded scan's row resolves.
- T-2 (AC-3) -- TEST-UNIT: the existing coordinator serialisation tests stay green. **This is the
  regression guard that matters most.**
- T-3 (AC-2) -- TEST-WIDGET or MANUAL.

**Definition of Done**: default PLUS: F175's serialisation invariant is proven intact.

**Model**: Sonnet -- *why not Haiku*: touches shared scan state, but the change is bounded once
F220 lands and the existing reconciliation is reused rather than replaced.

**Step-types**: SVC-EDIT, TEST-UNIT

**Est-Effort**: 120-240m

**Risk and rollback**: breaking serialisation re-opens a Sprint 61 production failure. Mitigation:
T-2 first.

---

## Task 6 -- F218: Flutter SDK upgrade; remove the Gradle workaround (Priority 8)

**Value**: This removes a workaround currently shipping a test-only library to testers, and ends
a 9-month SDK drift.

**Requirements**:
- R-1: **Back up first.** `pubspec.lock`, the repo commit, and the Flutter SDK commit. A rollback
  point was recorded 2026-09-14: repo `c1473a0`, SDK `f6ff1529fd6`.
- R-2: `flutter upgrade` will REFUSE -- the SDK checkout carries a deliberate local patch
  (`native_assets.dart`, documented in `TROUBLESHOOTING.md`) that stops a duplicate
  `sqlite3.x64.windows.dll` copy from **failing every Windows build**. Audit-confirmed still
  present (exactly 1 modified file in `D:\dev\flutter`).
- R-3: **Re-apply the patch only IF still needed.** Check whether upstream fixed the double-run
  first; carrying a redundant local modification is its own defect. If the code moved, re-derive
  from the symptom rather than pasting.
- R-4: **35 caret-ranged dependencies will re-resolve.** Read the `pubspec.lock` diff rather than
  assuming it is benign.
- R-5: **Remove the workaround and confirm the release build still succeeds WITHOUT it.** That
  removal IS the test that the upgrade fixed the underlying defect. **The upgrade is NOT
  guaranteed to fix it** -- the `--config-only` remedy the upstream issue recommends does not
  exist in 3.38.5, and no maintainer statement names a fix version.
- R-6 (ADR-0042): the SDK is shared. **Re-verify BOTH platforms.** The MSIX in Submission 27 was
  built on the OLD SDK, so a Windows regression would not surface from an Android test.

**Affected components / files**:
- `D:\dev\flutter` (the SDK itself -- outside the repo)
- `mobile-app/android/app/build.gradle.kts` -- remove `releaseImplementation(project(":integration_test"))`
- `mobile-app/pubspec.lock`

**Dependencies / blockers**: none, but **do this EARLY in the sprint, never near a release**.

**Acceptance criteria**:
- AC-1: `flutter build appbundle --release` succeeds WITHOUT the Gradle workaround.
- AC-2: The Windows build succeeds, with the native-assets patch re-applied or proven unnecessary.
- AC-3: Full test suite and analyzer green on the new SDK.
- AC-4: The `pubspec.lock` diff is reviewed, not merely accepted.

**Tests to write**:
- T-1 (AC-3) -- the existing suite is the test. A 9-month SDK jump either passes 2,119 tests or
  it does not.
- T-2 (AC-1, AC-2) -- MANUAL: one release build per platform.

**Definition of Done**: default PLUS:
- If the upgrade does NOT fix the `integration_test` defect, say so and RESTORE the workaround
  rather than shipping a broken Play build. That is a legitimate outcome, not a failure.

**Model**: Sonnet -- *why not Haiku*: a toolchain migration with a hand-applied SDK patch and 35
dependency re-resolutions, verified across two platforms.

**Step-types**: DATA, TEST-POLICY, MANUAL

**Est-Effort**: 240-480m

**Risk and rollback**: HIGHEST-BLAST-RADIUS TASK IN THE SPRINT. It changes the toolchain under
both platforms. Mitigation: R-1's backups, and do it first so a rollback is cheap. Rollback:
`git checkout` the SDK commit, restore `pubspec.lock`, restore the workaround.

---

## Model assignment summary

- **F219** -- Sonnet. Why not Haiku: two documented remedies, app-wide blast radius, settled by probe.
- **F212** -- Fable/Opus. Why not Sonnet: IMAP session state plus coordinator semantics; Sprint 38 precedent.
- **F220** -- Fable/Opus. Why not Sonnet: lease lifetime in the component every scan depends on.
- **F217** -- Fable/Opus. Why not Sonnet: OS diagnosis whose remedy is an architectural decision.
- **F221** -- Sonnet. Why not Haiku: shared scan state, bounded once F220 lands.
- **F218** -- Sonnet. Why not Haiku: toolchain migration across two platforms.

Planner and analyst tier stays top (Opus) per SPRINT_PLANNING.md.

**Single-session note (Sprint 68 IMP-4)**: if this sprint runs as one continuous interactive
session, execution will be on the session model regardless of assignment. Recorded once here
rather than as six per-task deviations.

## Risk assessment

- **SDK upgrade breaks a platform** -- Likelihood Medium, Impact High. Mitigation: do it FIRST,
  backups recorded, rollback rehearsed. A failed upgrade that restores the workaround is an
  acceptable outcome.
- **A coordinator fix deadlocks scanning** -- Likelihood Low, Impact High. Three tasks touch lease
  lifetime. Mitigation: unit-test the lease invariant before behaviour changes; F175's
  serialisation tests are the regression guard.
- **F217's fix is not chosen this sprint** -- Likelihood High, Impact Low. The card is scoped to
  diagnose and recommend precisely because the remedy is Class-1.
- **The sprint overruns** -- Likelihood Medium, Impact Medium. 17-34h against a recent norm of
  6-12h. Mitigation: the sequencing puts the riskiest work first, so a stopping decision at the
  halfway point is still cheap.

**Risk Level**: **High** -- the highest of any recent sprint. Three tasks touch the one component
every scan depends on, and a fourth changes the toolchain beneath both platforms.

## Sequencing

1. **F218 FIRST.** It changes the toolchain everything else is built and tested on. Doing it after
   five other tasks means re-verifying all of them. Doing it first means one clean baseline.
2. **F220** -- the lease-lifetime root cause. F221 and part of F212 may resolve with it.
3. **F221** -- immediately after F220, while the coordinator is fresh.
4. **F212** -- the third coordinator task; benefits from what 2 and 3 establish.
5. **F219** -- independent of the coordinator work; can run in parallel across agents.
6. **F217** -- last. Diagnosis-heavy, needs the phone idle for real intervals, and its Class-1
   decision is better raised once the rest is stable.

## Phase 3.7 approval (CLOSED)

Approved by Harold, 2026-09-17: *"Sprint plan approved as recommended, proceed with execution.
All Sprint tasks and sub-tasks are approved. Do not stop between tasks."*

Both open questions were answered by "as recommended":

1. **Sprint size**: APPROVED AS-IS at 17-34h, with the stated sequencing.
2. **F217 scope**: CONFIRMED as diagnose-and-recommend. The Class-1 fix is surfaced mid-sprint,
   not landed silently.

Standing approval covers all task execution, commits, pushes to the sprint branch, and PR updates
through Phase 5.3 Manual Validation. The 9 SPRINT_STOPPING_CRITERIA remain the only valid
mid-sprint pauses -- and the two pre-declared decision-class interrupts (F220 R-3 Class-2,
F217 Class-1) are surfacings, not stops.

## Definition of Done (sprint level)

Per `SPRINT_EXECUTION_WORKFLOW.md` Phases 5-7. Additions for this sprint:

- F212, F220 and F221 manual validation recorded on BOTH platforms.
- F175's serialisation invariant proven intact after every coordinator change.
- Both platform exceptions (F219 manifest, F217 background policy) declared in code.
- F218's outcome stated plainly, including if the upgrade did not fix the defect.
- No un-surfaced Class-1 or Class-2 decisions -- F220 R-3 and F217's fix are both expected.

---

## Phase 5 Completion Notes (evidence gate -- recorded before Manual Validation)

**Evidence markers (canonical list form -- the detail for each is in the sections below):**

- **5.1.1 automated code review**: DONE 2026-09-18, `pr-review-toolkit:code-reviewer` over
  `37d9816~1..HEAD` scoped to `mobile-app/lib/`. Found 1 CRITICAL (C-1: F220 was not actually
  fixed), 4 HIGH, 4 MEDIUM, 2 LOW. All verified against the code and all fixed in commit `f180ad0`.
  Suite 2,138 -> 2,148.
- **5.1.2 F-PRECHECK**: DONE 2026-09-18, all six detection ACTIONS run against the sprint diff.
  Clean on classes 1, 2, 5, 6; class 4 N/A (no new positional parsing in the diff); class 3 found
  and fixed two stale doc comments (`background_scan_core.dart` manual-timeout claim,
  `background_scan_scheduler.dart` ADR-0042 drift declaration).
- **5.1.5 WinWright sweep**: DONE 2026-09-18, sweep-head `f180ad0`, re-run after the code-review
  fixes because `lib/ui` changed. 2 of 5 scripts runnable (`f56` x2 and `f37` are the runner's own
  documented exclusions at `run-winwright-tests.ps1:258`); BOTH pass 29/29 in isolation with no DB
  drift, including `test_mt2c_no_rule_sweep` which covers `results_display_screen.dart`, the screen
  F212 changed. Back-to-back sweep flakiness filed as F226.
- **5.1.6 runtime launch gate**: PARTIAL -- Windows launched successfully twice via
  `build-windows.ps1`. Android runtime launch is OWED and listed under "Still owed" below; the
  F219 `AndroidManifest.xml` edit is not proven until the app starts on the S24+.

### 5.1.1 Automated code review -- DONE, and it found a CRITICAL defect

Run 2026-09-18 via `pr-review-toolkit:code-reviewer` over `37d9816~1..HEAD`, scoped to
`mobile-app/lib/` (8 production files). Every finding was independently verified against the code
before acting; all were real.

**C-1 (CRITICAL): F220 was NOT actually fixed.** The handler called `errorScan` and its doc comment
claimed "the scanner's own `finally` then releases the lease". False: `EmailScanProvider.errorScan`
never touches `ScanCoordinator`, `EmailScanner.scanInbox` never reads `scanProvider.status` (its two
mentions are log lines), and there is no cancellation token. The lease stayed HELD and the
coordinator stayed wedged; only the screen looked recovered. **My own test is why it shipped green
-- it asserted `provider.status == ScanStatus.error` and never asserted `coordinator.active == null`,
testing the half that worked.** Fixed by releasing the lease in the handler; new test is
mutation-verified (reverting turns three tests red).

Also fixed: **H-4** (handler lived on a screen that the "Scan Again" path disposes, so the main
rescan route was unwatched -- moved to the app root), **H-2** (F212's R-4 defeated on the common
partial-failure path by an unconditional re-add loop), **H-3** (state mutated outside `setState`),
**H-5** (a queued scan's timeout could force-release a LIVE scan's lease), **M-6/M-7** (ADR-0042:
declared parity while delivering divergence -- the handler killed healthy Windows scans, since
`paused` means "sockets gone" on Android but only "window hidden" on Windows; now a narrow declared
exception with both branches tested), **M-8** (`disconnect()` left `_imapClient` non-null when
`logout()` threw, so the new F212 guards never fired for "connection died" -- the failure mode users
actually hit), plus L-11 and M-10.

Commit: `f180ad0`. Suite 2,138 -> 2,148.

### 5.1.2 F-PRECHECK (six recurring review classes) -- DONE, clean

Each detection ACTION was run against the Sprint 70 diff, not merely read:

1. **Mirror/parallel-site sync**: CLEAN. The manual and background timeouts both read
   `ScanCoordinator.scanTimeout` (verified at `scan_progress_screen.dart` and
   `background_scan_core.dart`), and `f221_superseded_scan_row_test.dart` gates against either
   hardcoding a literal. No `BatchActionResult.allSuccess` call sites remain in either adapter.
2. **Helper wired to PRODUCTION path**: CLEAN. `_recordBatchFailures` has 6 call sites on the
   re-process path; `_reProcessFailedKeys` is consumed by the footer;
   `reconcileStaleInProgressScans` went from ONE caller (startup) to two (startup + resume).
3. **Doc-comment-vs-code drift**: FOUND AND FIXED (2). The `background_scan_core.dart` comment
   still said manual scans deliberately have no timeout after F221 gave them one; the
   `background_scan_scheduler.dart` ADR-0042 declaration still called 2h42m drift an "accepted
   difference". Both rewritten rather than deleted, so the reversal stays readable.
4. **Fragile input parsing**: N/A -- no new `split`/`indexOf`/`substring` on id-shaped input in
   this diff (verified by grepping the diff, not assumed).
5. **API scope matches caller intent**: CLEAN. `acquire()` is process-wide and the re-process
   caller wants exactly that (closing the bypass IS the fix); `releaseActiveByOwner` is
   owner-matched so it cannot evict another scan -- though the review's H-5 showed owner-matching
   alone was insufficient for two manual scans on one account, now fixed by a lease-identity check.
6. **Silent failure**: CLEAN. One new `catch` in the diff (`main.dart` resume backstop); it logs at
   `Logger().w()` and converts no unreadable input into a destructive classification.

### 5.1.5 WinWright UI sweep -- DONE

- **Date**: 2026-09-18
- **sweep-head**: `f180ad0`
- **Scripts run**: 2 of 5. `test_f56_create_block_rule` and `test_f56_create_safe_sender` are
  QUARANTINED and `f37` is excluded by the runner itself (`run-winwright-tests.ps1:258`,
  `$excludedFromSweep = @("f56","f37")`) -- a documented dialog-settle limitation moved to F99
  integration_test, checked BEFORE investigating rather than re-derived.
- **Result**: BOTH PASS, 29/29 assertions each, no DB drift.
  - `test_mt2c_no_rule_sweep.json` PASS -- this is the script that exercises
    `results_display_screen.dart`, the screen F212 changed. This is the coverage that matters.
  - `test_f124_rule_labels.json` PASS
- **Finding (filed, not swept under)**: the two scripts fail INTERMITTENTLY when run back-to-back
  in one sweep, and the failure swaps between them run to run (f124 failed in run 1, mt2c in run 2).
  Each passes 29/29 in isolation. That is a runner/app-state interaction, not a sprint regression --
  filed as **F226**. Recorded rather than ignored because a sweep that is red for unrelated reasons
  destroys its own value as a signal.
- **Re-run after the code-review fixes**: yes. `lib/ui` changed in `f180ad0` after the first sweep,
  so the sweep was re-run against the rebuilt app and `sweep-head` names the later commit.

### 5.1.6 Runtime launch gate

DONE. `AndroidManifest.xml` was touched (F219 `taskAffinity` removal), which triggers this gate.
The Windows app was built and launched successfully twice for the WinWright sweeps
(`build-windows.ps1`). **Android runtime launch is still OWED** and is part of the device
validation below -- an XML change that AAPT accepts can still fail at OS parse time (Sprint 64
SEC-4), so the manifest edit is not proven until the app launches on the S24+.

### Still owed at Manual Validation (stated plainly, not implied complete)

- **F219 AC-1/AC-2**: device testing on a Play-installed build (sign-in; launcher start, return
  from recents, deep links). No Android device was attached during implementation.
- **F217 AC-1/R-1/R-2**: `adb` standby-bucket and jobscheduler capture, plus the Samsung
  Background usage limits check.
- **F212 AC-4**: re-processing verified on BOTH platforms.
- **F217 remedy**: a Class-1 decision, three options recorded in `ALL_SPRINTS_MASTER_PLAN.md`,
  awaiting Harold. Not chosen by Claude.
