# Sprint 85 Summary

**Dates**: 2026-11-08 to 2026-11-21
**Branch**: `feature/20261108_Sprint_85` | **PR**: #559 -> develop
**Version**: 0.25.0+23 (bumped at plan approval; MINOR, F352 adds a user-facing capability)
**Suite**: 3,672 passed, 15 skipped, 0 failed (2026-11-10 21:04-21:09 at e110499b, `run-full-suite.py
--concurrency 6`, idle machine) | Analyzer clean | Hook cases 216/216 | Hook unit tests 145 OK | Script tests 379 OK |
CI run 1 (44873531314): Flutter analyze and test and both builds green, 1 Linux-only Python test failed and was fixed;
CI run 2: first run (44882990189) failed one hook unit test that read the real `git branch` (fixed in the test,
15d0c941); retry (44887869324) green on every job. Details: `SPRINT_85_PLAN.md` "7.7.1 final code reviews"
**Merged**: 2026-11-22 by Harold -- develop 328f6e29 (PR #559), main 8f2e6f5c (PR #576)

## What this sprint was for

Let the user choose a default email account (F352). Stop Windows DEV builds from sharing the production credential
file (F354). Decide which tests run when, by risk (F350). Port the remaining PowerShell tooling to Python (F329-F335,
ADR-0051). Settle the Sprint 84 open items: the Android "isn't responding" report (F355), the `interrupted` rows
(F357), the rest of the live first-run evaluation (F341) and the F342 Fold check. Every card named its Windows,
Android and iPhone paths (ADR-0042, ADR-0049, ADR-0050).

## Delivered

- **F352 (#563)** -- a star on the Select Account screen sets the default account; Settings and scans use it
  without asking (ADR-0052). Deleting the default clears it; a failed read keeps it.
- **F354 (#564)** -- Windows DEV builds copy the sign-ins once into their own folder and never change the installed
  app's file. The production credential file was hash-checked before and after every step (unchanged throughout).
- **F350 (#562)** -- `scripts/test-inventory.py` lists every test artifact with a risk tier; Harold's decisions q4
  (tight tier rule), q5 (mutation policy unchanged) and q6 (one full run on an idle machine; changed-file tests
  during work) are in the workflow.
- **F329-F335 (#569-#575)** -- the hook test tooling and the remaining scripts ported to Python; the PowerShell
  copies deleted; CI runs the Python script tests on Linux.
- **q2 (Harold)** -- the Android app and Play bundle no longer hold the Windows Gmail client secret (byte scan: 0,
  control key: 12).
- **q10 (Harold)** -- the star, Start Scan and Delete buttons in each account row are reachable by screen readers.
- **F355 (#565)** -- not repeated: 0 ANR in 9 emulator tries and none on the Fold (MV-3); closed with the evidence.
- **F357 (#566)** -- no code: 4 real worker stops on the Fold, each row closed as `interrupted`, none overwritten.
- **F341 (#567)** -- check 6 on the emulator became F358; the iOS Simulator screens were compared; checks 2 and 9
  passed at Manual Validation.
- **Task 1 (#561)** -- F342 Fold check (MV-4, log evidence) and MV-3c (MV-5 PASS). **Version (#560)** 0.25.0+23.
- **7.7.1 review fixes** -- the F354 failure is shown in Settings > General; the F352 read failure reaches the
  diagnostic log; the Python tools never report success after a failed or empty step; Help and CHANGELOG text
  matches the app; ADR-0017, 0027 and 0039 name the Python ports.

## Not delivered, and why

- **F307 removal (#568)** -- Task 8 did the R-1 coverage audit only; Harold moved the removal to Sprint 86 (q1).
- **F67a (#509), F304 (#510), F67b (#523)** -- still wait on Apple's approval of enrollment `R6QG2A9SHS`.

## What went right

- The parallel Python port batches finished under their estimates (for example F335 ~46 of 180-300 minutes).
- Every new guard test was mutation-checked; all mutants KILLED (including 10 of 10 for close-out check 3d-4).
- The WinWright rehearsal found the screen-reader gap (q10) before Harold did, and the q2 fix was proven on the
  built bundle, not only in the script.

## What cost time

- A Visual Studio update removed the Windows SDK manifest; DEV could not be rebuilt from 11/10 to 11/13 (i8,
  tracked).
- Tools that reported success after a failed or empty step (class B, 8 findings plus 2 left open by 5.1.2): i1, i4.
- User-visible text that did not match the app (class D, 2 findings; recurring since Sprint 81): i2.
- Card lines for ports and renames that never recorded their results (class E): i5 and check 3d-4.
- Two MV steps cost Harold a round each (MV-1(a) starting screen, MV-4 Scan History retention): i6.
- Several velocity rows say "time not recorded" (Tasks 1, 2, 4, 5, 7, 8): i7.

## Manual Validation

Windows DEV 0.25.0+23, the Fold (0.24.1 from Play) and the Android emulator, handed over 2026-11-13. MV-1 PASS
except (a), a rehearsal gap; MV-2, MV-3, MV-5, MV-6 checks 2 and 9, MV-7 PASS; MV-4 closed by Harold on the log
evidence. Decisions q1-q11, F357 q1/q2 and T1 recorded in `SPRINT_85_PLAN.md`. Complete per Harold (2026-11-18).

## Retrospective

Harold: all 14 categories Very Good; categories 13 and 14 none.
- i1-i7 applied (a): 5.1.2 findings fixed at 5.1.2; CHANGELOG and Help claims traced to code; a failure that changes
  a screen shows its reason there; port cards record error paths, file-type gates and results; close-out check 3d-4
  (from Sprint 86); 5.1.9 preconditions; task start times.
- i8 tracked (e). F361 added at Priority 38 (Harold: top 10 for Sprint 86).
- 7.7.1 final code reviews, improvement review and CI: see `SPRINT_85_PLAN.md` "Phase 7.7.1 final code reviews".

## Carry-forward

- **Next sprint**: the 0.25.0 store updates (rebuild from `main`); F307 removal; iOS Tasks when Apple approves.
- **Backlog**: F358 (Priority 52), F359 (Priority 40), F360 (Priority 42), F361 (Priority 38).
