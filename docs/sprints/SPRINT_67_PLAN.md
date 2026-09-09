# Sprint 67 Plan

**Dates**: 2026-09-08 to TBD
**Branch**: `feature/20260908_Sprint_67` | **PR**: #396 (draft)
**Scope**: F194 (#392), F195 (#393), F193 (#394), F196 (#395)
**Version**: 0.14.2 -- bumped at plan approval per F190 (Phase 3.7.0b). PATCH, because no
task here is a `feat`.

**Theme**: fix what the closed test will hit, and close the two process gaps Sprint 66
exposed.

## APPROVED

Harold, 2026-09-08: *"Sprint plan approved, proceed with execution. All Sprint tasks and
sub-tasks are approved. Continue without addition approvals until Manual Validation,
providing your recommendation for Manual Validation steps. Do not stop to ask questions
unless meeting the criteria in \docs\SPRINT_STOPPING_CRITERIA.md"*

## Cross-platform parity (ADR-0042) -- applies to EVERY task

Harold's standing constraint, restated at scope selection: *"everything needs to take into
account both the Windows App and the Android app and ADR stating that everything should be
functionally and UI the same unless it cannot be -- and where it cannot be it should be
implemented as a platform exception for what is needed -- this applies to all backend code,
frontend code, data, architecture, development, security, testing, deployment."*

Each card below states its Windows and Android position explicitly. Where behaviour cannot
be shared, the card declares the platform exception and why. F193 is tooling rather than app
code, and says so rather than omitting the question.

## Why this scope

F194 gates recruitment. A background scan that hangs is what all twelve closed-test testers
will hit over fourteen days, and it is the feature that justifies keeping the app installed.
It should be fixed before the remaining nine testers are recruited.

F195 pairs with it: same screen, same device session. The account header sits on the
Background tab that F194 work will already have open.

F193 and F196 are the two process gaps Sprint 66 exposed -- one where a mandatory review was
skipped and caught late, one where release notes were improvised twice.

---

## Task 1 -- F194: Background scan hangs on Android (Priority 2, Issue #392)

**Value**: This prevents every closed-test tester concluding the app's core unattended
feature is broken, during the one 14-day window Google reviews.

**Requirements**:
- R-1: **Diagnose before fixing.** RUNNING at 4 minutes with every counter zero is consistent
  with three distinct causes -- the task never fired, it fired and threw before the first
  fetch, or it is genuinely waiting. These need different fixes; do not presume one.
- R-2: `reconcileStaleInProgressScans` (F175, Sprint 62, `scan_result_store.dart:449`)
  ALREADY handles dead rows, but runs only at app startup (`main.dart:276`, sole call site)
  and only on rows older than `ScanCoordinator.scanTimeout` = 30 minutes
  (`scan_coordinator.dart:78`). At 4 minutes with the app open, a dead scan is
  indistinguishable from a live one BY DESIGN -- the age guard is deliberate, because on
  Windows the worker scans in a separate process. Decide whether that window is right for a
  user watching Scan History, rather than assuming it is a second bug.
- R-3: whatever the trigger, a background scan that fails must record an error rather than
  leaving zeroes. Silent failure is the defect regardless of cause.
- R-4 (ADR-0042): `background_scan_windows_worker.dart` and
  `android_background_scan_worker.dart` are separate implementations over shared
  `background_scan_core.dart`. Determine whether the fault is in the shared core (fix once)
  or the Android worker (platform exception, declared).

**Affected components / files**:
- `lib/core/services/android_background_scan_worker.dart:53` -- `Workmanager().executeTask`
- `lib/core/services/background_scan_scheduler.dart:214-274` -- registration/cancel/periodic
- `lib/core/services/background_scan_core.dart:142` -- shared scan path
- `lib/core/storage/scan_result_store.dart:449` -- reconciliation
- `lib/main.dart:276` -- the only reconcile call site

**Dependencies / blockers**: Harold's device for reproduction; USB debugging for `adb logcat`.

**Non-functional requirements**:
- Account-scoping: per-account periodic tasks (F161) -- a fix must not collapse them into one
- Platform: Android worker is `Platform.isAndroid`-gated; any exception declared per ADR-0042

**Acceptance criteria**:
- AC-1: cause identified and stated WITH EVIDENCE (logcat, background-scan log, or a failing
  test) -- not inferred
- AC-2: Given background scanning enabled and a scheduled scan fires, When it completes, Then
  Scan History shows a completed row with non-zero processed for a non-empty mailbox
- AC-3: Given a background scan that fails for any reason, When it terminates, Then the row
  records status and a non-empty error message, never zeroes with `in_progress`
- AC-4: the Windows position is stated -- same fault (fixed in shared core) or not
  (documented, with why)

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-UNIT: a worker whose scan throws records an error row rather
  than leaving `in_progress` with zero counters
- T-2 (verifies AC-2) -- TEST-UNIT: a successful background scan writes non-zero processed
  and a terminal status
- T-3 (verifies AC-4) -- TEST-UNIT: whichever invariant the fix establishes holds for both
  worker paths, or the platform exception is asserted explicitly

**Definition of Done**: default PLUS real-device verification on Harold's S24+ -- a
SCHEDULED (not Test-button) background scan completing with non-zero counts.

**Model**: Fable/Opus -- *why not the cheaper tier*: diagnosis-first with three candidate
causes across a native/plugin boundary, and `feedback_diagnose_before_patching` applies. This
is the failure mode where guessing costs more than thinking.

**Step-types**: SVC-EDIT, TEST-UNIT, possibly NATIVE-WIN
**Est-Effort**: 60-120m coding; diagnosis may dominate and is NOT bounded by that.

**Risk & rollback**: a wrong fix could disable background scanning entirely. Mitigation: T-2
proves the success path still works. Rollback: revert the commit; the feature returns to its
current state, which at least schedules.

---

## Task 2 -- F195: Account header contrast (Priority 22, Issue #393)

**Value**: This prevents the screen every tester visits reading as unfinished, and fixes a
likely accessibility failure.

**Requirements**:
- R-1: MEASURE the current contrast ratio; do not judge by eye
- R-2: meet WCAG AA -- 4.5:1 normal text, 3:1 large
- R-3 (ADR-0042): determine whether the widget is shared with Windows. If shared, fix once;
  if not, fix both to the same standard and declare the exception
- R-4: check whether the same widget appears on other screens BEFORE changing it -- a colour
  fixed in one place and not its siblings is this project's recurring UI defect shape
  (Sprint 52 IMP-5)

**Affected components / files**: Settings Manual Scan + Background tab account header
(exact widget to be located; likely `lib/ui/screens/settings_screen.dart`).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: WCAG AA per QUALITY_STANDARDS.md / ADR-0037
- Platform: shared widget preferred; exception declared if not

**Acceptance criteria**:
- AC-1: measured contrast ratio >= 4.5:1, recorded in this plan
- AC-2: Given the Settings Background tab on both platforms, When rendered, Then the account
  header is legible at the same standard

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-UNIT: computes the ratio from the theme's colour pair and
  asserts >= 4.5:1, so a future theme change cannot silently regress it

**Definition of Done**: default PLUS visual confirmation on both a Windows build and the
Android device.

**Model**: Haiku -- mechanical once the widget is located and the standard is fixed.

**Step-types**: UI-MOVE, TEST-UNIT
**Est-Effort**: 20-40m

---

## Task 3 -- F193: Gate Phase 5 evidence at the MV boundary (Priority 12, Issue #394)

**Value**: This prevents Harold validating unreviewed code -- which happened in Sprint 62 and
again in Sprint 66.

**Requirements**:
- R-1: fire when MV is DECLARED, not at close-out. `verify-closeout-complete.ps1` already
  performs the check correctly; it is wired to the wrong event
- R-2: NOT another prose rule. CLAUDE.md's "open the checklist" rule was followed in Sprint 66
  and still failed
- R-3: must not fire on sprints before 63, which predate the artifact conventions -- this
  hook has a false-positive history, and a check that fires on historically-correct state
  trains bypass
- R-4 (ADR-0042): N/A -- tooling, not app code. Stated rather than omitted.

**Affected components / files**:
- `.claude/hooks/sprint-auto-advance.ps1` -- already reads `sprint_status.json`
  `current_sprint.status` for its Gate 1c bound, so it already watches this transition
- `.claude/hooks/verify-closeout-complete.ps1:233` -- the existing check to relocate or share
- `docs/SPRINT_EXECUTION_WORKFLOW.md` -- document the new enforcement point

**Dependencies / blockers**: `.claude/` writes need Harold's approval in don't-ask mode.

**Acceptance criteria**:
- AC-1: declaring MV with any of the three markers absent FAILS
- AC-2: declaring MV with all three present passes
- AC-3: sprints before 63 unaffected

**Tests to write**:
- T-1 (verifies AC-1/AC-2) -- HOOK self-test, MUTATION-VERIFIED not inspected: remove a
  marker, confirm red; restore, confirm green. Sprint 66 proved twice that a gate can pass
  while catching nothing

**Definition of Done**: default PLUS the mutation evidence recorded in this plan.

**Model**: Sonnet -- *why not the cheaper tier*: hook logic with an ordering constraint and a
false-positive history. Haiku-level pattern-matching is what produced the Sprint 66 gate that
passed while inert.

**Step-types**: HOOK, DOCS
**Est-Effort**: 45-70m

---

## Task 4 -- F196: Per-store release notes (Priority 14, Issue #395)

**Value**: This prevents each store's users being shown the other platform's changelog, and
removes the improvisation that cost three re-measurements in Sprint 66.

**Requirements**:
- R-1: one `CHANGELOG.md` remains the engineering record. This adds a DERIVATION step, not a
  second changelog
- R-2: produce `RELEASE_NOTES_<version>_windows.md` and `RELEASE_NOTES_<version>_play.md`
- R-3: handle the version-shipped-to-one-store case -- a store's notes must cover every change
  since the last version THAT STORE received, not since the last version
- R-4: encode the known limits -- Play 500 chars/language with `<en-US>` tags; Microsoft Store
  "What's new in this version" appears only once a package is attached
- R-5 (ADR-0042): the notes DIFFER per store by design and that is not a parity violation --
  behaviour is identical, only the audience differs. What must stay identical is the
  underlying CLAIM
- R-6: write the ADR for the versioning decision Harold raised 2026-09-08 (all platforms on
  one version even when a release applies to one; a version may advance without being
  submitted everywhere)

**Affected components / files**:
- `docs/STORE_RELEASE_PROCESS.md` -- the derivation step
- `docs/CHANGELOG_POLICY.md` -- how entries carry platform applicability
- `docs/adr/` -- new ADR for cross-platform version lockstep
- `docs/store-assets/` -- where generated notes live

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: the procedure produces both files for 0.14.2, each containing only entries applicable
  to that store
- AC-2: the Play notes measure <= 500 characters, verified BY COUNT not estimate (Sprint 66
  got this wrong three times running by estimating)
- AC-3: the ADR states the lockstep decision, its rationale, and the advance-without-
  submitting refinement

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-UNIT in `test/policy/`: measures the Play notes file against
  500 and fails over
- T-2 (verifies AC-1) -- TEST-UNIT: both files exist for the current version and are non-empty

**Definition of Done**: default PLUS both files generated for 0.14.2 as the worked example.

**Model**: Sonnet -- *why not the cheaper tier*: requires a judgment rule for platform
applicability that does not yet exist in the repo.

**Step-types**: DOCS, TEST-UNIT
**Est-Effort**: 50-80m

---

## Totals

**Coding: 175-310 minutes**, plus F194 diagnosis which is genuinely unbounded.

**Sequencing**: F194 first (gates recruitment). F195 alongside (same screen, same device
session). F193 and F196 independent, can run in parallel.

**Flagged at planning**: if F194's cause turns out to be Samsung's battery management rather
than app code, the fix may be documentation and user guidance rather than code -- a different
task. That will be surfaced as a Class-2 decision if the evidence points there.

## Phase 5 evidence (filled during execution)

- **5.1.1 automated code review** (2026-09-09, `pr-review-toolkit:code-reviewer` on
  `cd8ff34..HEAD`): RUN BEFORE Manual Validation, which is the whole point of F193 --
  and it immediately justified itself by finding a LIVE regression.
  - **CRITICAL 1 (fixed, `e37d0d9`)**: the F193 gate fired during Phase 4 and broke
    **6 of this hook's own test cases**. Gate 1c matched "Manual Validation" as a
    SUBSTRING, and the live status says "...standing approval through Manual
    Validation" as prose. Anchored to the start of the status string.
  - **CRITICAL 2 (fixed, `e37d0d9`)**: the block message went to stdout while every
    other blocking path in `.claude/hooks/` uses stderr -- and the test runner
    discards stdout. The gate would have blocked with its reason thrown away.
  - **HIGH 3 (fixed, `e37d0d9`)**: the gate had ZERO test coverage, which is how the
    two criticals shipped. Added `violation-14` and `allow-17` with Sprint-67
    fixtures. Hook suite now 53/53 (was 45/6).
  - **HIGH 4 (fixed)**: the F195 test asserted Flutter's stock themes, not
    `AppTheme`. Independently caught here while preparing the MV steps.
  - **MEDIUM 5 (accepted, recorded)**: the F194 test mirrors the screen's ternary
    rather than calling it, so it guards the DESIGN RULE but cannot catch
    divergence. The reviewer mutation-tested it and confirmed the assertions are
    live logic, not vacuous -- materially better than the Sprint 66 gates. Left as
    is; the honest fix (extract a shared function) is recorded rather than rushed.
  - **MEDIUM 6 (fixed below)**: the F196 leak regex missed `F1234` (capped at 3
    digits) and lowercase `issue #392`.
  - **Verified clean by the reviewer**: the Sprint 66 ``-in-a-non-raw-string class
    does not recur (all 194 `RegExp(` sites use raw strings); F194 is complete for
    the display path; F195's `copyWith(color:)` does win over enclosing styles.
- **5.1.2 F-PRECHECK six classes** (2026-09-09, against `cd8ff34..HEAD`):
  1. *Mirror-site sync*: CLEAN. `Icons.access_time` appears at exactly one site
     (`scan_history_screen.dart:661`) -- the icon logic is not duplicated, so the F194 fix
     has no sibling to drift from.
  2. *Helper-wired-to-production*: CLEAN, but noted as a real limitation rather than a
     pass. `presentationFor` exists only in the test; it MIRRORS the screen's ternary
     rather than calling it, so the test can stay green if the screen alone regresses.
     Raised explicitly with the 5.1.1 reviewer instead of being defended.
  3. *Doc-vs-code drift*: CLEAN. The plan's own PENDING markers were the only mismatch,
     and this entry is what resolves one of them.
  4. *Fragile parsing*: FOUR new regexes, all reviewed. The one carrying real risk is the
     hook's `N/?A` -- word-boundary behaviour around a slash is worth an adversarial
     read, so it was named specifically in the 5.1.1 brief rather than assumed correct.
  5. *API scope*: CLEAN. Production changes are confined to two UI files
     (`scan_history_screen.dart`, `settings_screen.dart`), 47 insertions. No new external
     surface, no signature changes.
  6. *Silent failure*: CLEAN. No new catch blocks in production code; the only `catch`
     matches in the diff are inside prose and comments.
- **5.1.5 WinWright UI sweep** (2026-09-09): RUN, not waived. 2 scripts, 29 assertions,
  **2/2 PASS, 0 failed, 0 errors**, ~35s total.
  `sweep-head: 04890ecff86a713c427b0bb349aa842ec7ab7e04`
  **RE-RUN at HEAD 2026-09-09**, and the re-run was the point. The first sweep recorded
  `52fbc7d`, and TWO later commits then changed `scan_history_screen.dart` -- including the
  "Interrupted" -> "Not finished" wording Harold requested at Manual Validation. The recorded
  sweep therefore proved an OLDER UI, which is exactly the Sprint 61 F169 rot class the
  sweep-head rule exists to catch. The close-out hook caught it; I did not.
  Recording a hash is only half the rule -- the other half is RE-RUNNING when `lib/ui` changes
  after it. Second run: 2/2 PASS, 29 assertions, 0 failed, 0 errors (~10.5 min, slower only
  because each script launches a cold-built app).
  Scripts: `test_f124_rule_labels.json`, `test_mt2c_no_rule_sweep.json` -- the two that
  exercise the screens this sprint touched (Scan History, Settings).
  It would have been defensible to claim N/A here: every `lib/ui/` change is an icon or
  colour VALUE, and WinWright selectors match on text, structure and automation ids, none
  of which moved. But that is reasoning, and the sweep is cheap -- so it was run rather
  than argued.
