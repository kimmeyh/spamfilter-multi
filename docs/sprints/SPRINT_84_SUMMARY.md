# Sprint 84 Summary

**Dates**: 2026-11-05 to 2026-11-08
**Branch**: `feature/20261105_Sprint_84` | **PR**: #548 -> develop
**Version**: 0.24.1+22 (bumped at plan approval; PATCH, the user-facing changes are `fix` entries)
**Suite**: 3,619 passed, 15 skipped, 3 failed (local run 2026-11-06 at `--concurrency=4`; the 3 failures are the
known Task Scheduler 30 s timeouts, F349) | CI run 1 green (42457200807, all three jobs); CI run 2 green (42528115315, at 7.7.5) |
Analyzer clean | Hook suite 208/208 | test_pylib 95 OK

## What this sprint was for

Explain the Fold background log errors (F342) and test whether alarm scans under Doze need a network wait (F280).
Run the live first-run evaluation that Sprint 83 prepared (F341). Port the five most-used hooks to Python (F326,
F327, F328). Add an iOS Simulator check and the iOS privacy manifest (F345). Close the Sprint 83 phone carry-ins
(MV-3c, the 0.24.0 notification channels). Every card named its Windows, Android and iPhone paths (ADR-0042,
ADR-0049, ADR-0050).

## Delivered

- **F342 (#551)** -- 11 Fold logs in 9 groups, each with a cause or a next check
  (`docs/research/F342_FOLD_BACKGROUND_ERRORS_S84.md`). One fix: when Android stops the background worker, the scan
  row is closed and Scan History says "The phone stopped this background scan before it finished. The next scan
  will try again." (or names an app cancel). Follow-up cards F346, F347, F357.
- **F280 (#552)** -- not reproduced: 0 failed host lookups in each of three emulator arms. Harold chose to revert the
  network constraint; nothing ships.
- **F341 part B (#553)** -- the Android emulator leg (checks 1, 3, 4, 5, 7, 10 and layout) and the Windows checks
  with accounts present. The rest stays on F341 (Harold: "mv-6 move to next sprint").
- **F326 (#554), F327 (#555), F328 (#556)** -- the three PreToolUse guards, the close-out Stop hook and the
  auto-advance Stop hook run in Python, with the same cases passing before and after; the `.ps1` copies go in F329.
- **F345 (#557)** -- an iOS Simulator CI workflow (integration tests and first-run screens on the macos-26 runner)
  and `PrivacyInfo.xcprivacy`.
- **Task 1 (#550)** -- MV-4: the Fold shows the two 0.24.0 notification channels (PASS).
- **Version (#549)** -- 0.24.1+22.
- **Small-screen fixes** -- the Rule Test messages, the shared error display, the Settings placeholder and the empty
  states scroll on a short screen; the Scan History filter chips wrap on a phone-width screen.
- **7.7.1 review fixes** -- the F342 row is closed before the log write; hook checks that cannot run say so; the
  stash-guard bypasses are closed; the card gate counts only this sprint's cards; release notes no longer claim
  reverted F280.

## Not delivered, and why

- **F341 remainder** -- check 6, check 2 (Gmail sign-in), check 9 (Fold), the iOS screen comparison: moved by Harold
  (Class 3, 2026-11-07). The clean Windows first run is blocked by F354 (DEV credentials in the production-named
  folder).
- **MV-3c (MV-5)** -- no YELLOW No Rule item on the Fold yet.
- **F67a (#509), F304 (#510), F67b (#523)** -- still wait on Apple's approval of enrollment `R6QG2A9SHS`.

## What went right

- The 7.7.1 reviews ran before the retrospective again, and the retrospective worked from finding classes (A-F).
- Evidence settled F280 before any code shipped: the emulator arms showed no failure, so the change was reverted.
- Every new guard test and fix was mutation-checked; all mutants KILLED (11, 15, 19 in the hook ports, 18 in the
  hook fixes, 3 in the improvement review).
- The improvement review found a real defect in a retrospective fix (a Windows timeout that did not end a child
  process) before it shipped.

## What cost time

- Text that promised more than shipped (class A, 5 findings): tracked under i1.
- Hook checks that passed silently when `git` or `gh` failed (class B, 9 findings): fixed; the fault-injection test
  is in F329 (i2).
- Ports that copied a defect of the original (class C, 3 findings): the card template now has "Port of existing
  code" (i3).
- F345 took 8 macOS CI runs of 35-75 minutes each: a job timeout (split into two jobs), a probe flag that did not
  match, and, found in runs 6-7, the iOS soft keyboard left open after text entry.
- The first Windows first-run attempt found saved accounts (F354), so the clean Windows run did not happen.

## Manual Validation

Windows DEV 0.24.1, the Fold (0.24.0 from Play) and the Android emulator, three rounds. MV-1 PASS (iCloud password
re-entered), MV-2 N/A (no older No Rule rows), MV-3 PASS, MV-4 PASS, MV-5 carried, MV-6 Android leg and Windows
checks done, the rest to F341. Cards decided during validation: F350, F352 (with ADR-0052), F353, F354, F355. Complete per
Harold (2026-11-07, q1 = a).

## Retrospective

Harold: all categories Very Good.
- i3, i4, i5, i6 applied: the card template has "Port of existing code" and "Old name search"; 5.1.9 lists each
  guard test with its mutation verdict; 5.1.2 class 1 searches nested forms of a code shape.
- i2 (b) and q3 (a) added to F329; i8 (a) is F356; q1 (c) and q2 (a) are F357; i1 and i7 tracked.
- q4: the close-out hook runs its `gh` calls at the same time inside one 15 second budget, kills the whole process
  tree on a timeout, and has a 17 second watchdog; `.claude/settings.json` is unchanged.
- 7.7.1 final code reviews, improvement review and CI: see `SPRINT_84_PLAN.md` "Phase 7.7.1 final code reviews".

## Carry-forward

- **Next sprint**: the 0.24.1 store updates; the F342 Fold check after 0.24.1 (feeds F357); MV-3c when a YELLOW
  item appears; iOS Tasks when Apple approves.
- **Backlog**: F341 remainder, F346-F357 (F350 Priority 10, F352 Priority 12, F354 Priority 14, F355 Priority 16),
  F329 with the i2 and q3 steps.
