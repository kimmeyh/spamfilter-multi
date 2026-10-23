# Sprint 80 Summary

**Dates**: 2026-10-18 to 2026-10-23
**Branch**: `feature/20261018_Sprint_80` | **PR**: #490 -> develop
**Version**: 0.21.0+18 (bumped at plan approval; MINOR, confirmed at 7.7 because `[Unreleased]` has a `feat`)
**Suite**: 3,092 -> 3,189 passed (15 skipped, 0 failed) at Task 17 | Analyzer clean | WinWright 2/2 at `4d42c8dd`

## What this sprint was for

Finish the Fold checks on the 0.20.0 closed-test build (MV76-1, F277, F299). Put every Windows and Android difference
behind one seam (F294) and decide, before any iOS code, which iPhone behaviors cannot match (F295). Keep CI on the
local Flutter version (F296). Make rule and safe sender edits take effect at once (F298), hide mail that is already
gone from Review (F276), and start the rule-learning tools (F267, F268, F269). Gate the Play AAB requirements (F204).
Every card stated Windows + Android parity or declared an exception (ADR-0042).

## Delivered

- **F294 (#493)** -- `PlatformCapabilities` (what the host can do) and `PlatformPolicy` (what the app chooses) in
  `lib/core/platform/`; 62 call sites migrated; a policy test refuses new bare platform checks. ADR-0049 ACCEPTED
  (amends ADR-0042).
- **F295 (#494)** -- iPhone readiness research with a vendor source for each claim; ADR-0050 ACCEPTED (iOS background
  scans are best-effort BGAppRefreshTask; no new-mail trigger); iOS cards F67a-d, F95 and F95b in the backlog.
- **F296 (#495)** -- CI reads the Flutter version from `.fvmrc` (3.47.4); a test fails on drift.
- **F298 (#496)** -- editing, deleting or quick-adding a rule or safe sender takes effect at once; a failed reload
  says so.
- **F276 (#501)** -- each scan checks the listed Review emails of the folders it scans and hides the ones that are
  gone; an email that comes back is listed again.
- **F269 (#499)** -- a YAML import adds to the existing rules by default (Merge); Replace is still offered.
- **F267 (#497), F268 (#498)** -- developer tools: score candidate rules against scan history, and propose delete rules
  from mail the rules miss.
- **F204 (#502)** -- the Play bundle build fails on a target SDK below 36 or an AD_ID permission.
- **F292 (#492)** -- closed: the full-suite deaths did not reproduce (Harold Q4 = 1).
- **F299 (#500)** -- closed on evidence: 0 class-B rows over about 55 hours on 0.20.0.
- **Added at Manual Validation**: Task 15 (#503) the Windows window appears at once (30.9 s -> 1.8 s; Task Scheduler
  reconciliation after `runApp`); Task 16 (#504) the tray icon appears however the app starts, and its right-click
  menu opens; Task 17 (#505) one Android `new-mail-diagnostics` line at each start, with the five mail apps declared
  in `<queries>`.
- **Phone**: MV76-1 (#471, #433, #428) done except R-2; F277 (#472) closed by Harold (arm A and arm C complete; the
  interval floor stays 5).

## Not delivered, and why

- **F289** -- removed from scope by Harold (Q4b = 2); it waits on an upstream WinWright change and stays in the
  backlog.
- **R-2 (new-mail trigger on a real phone)** -- it has never fired on the Fold, cause unknown; Task 17 adds the line
  that will show why, read from the first 0.21.0 Fold log in Phase 8.

## What went right

- Parallel Sonnet and Haiku agents ran Tasks 6-10 and 14; approval to Manual Validation handover took about 10 hours.
- Every new test was mutation-verified; 15 of 17 task rows were inside or under their estimates.
- Both ADRs were decided at Manual Validation with a summary of what each decides.

## What cost time

- The MV-4 rehearsal reasoned that the tray icon was present instead of looking; it was missing (one round, Task 16;
  retro IMP-1 and IMP-1.1).
- Two MV step facts changed between the rehearsal and Harold's run (MV-1 base count, MV-3 row); MV-3 cost one
  question (IMP-4 skipped).
- A background Android build task stayed open about 11 hours after its script exited; cause unknown (IMP-2b).
- Three questions came back for more detail or because they had been answered (retro IMP-3).

## Manual Validation

Windows DEV 0.21.0: MV-1 PASS (Merge 1 added, 1 duplicate); MV-2 PASS; MV-3 PASS on field evidence (32 Review rows
hidden as gone); MV-4 PASS on the Task 16 build (tray icon and menu); MV-5 PASS (Exit from the tray, window in about
2 seconds). ADR-0049 and ADR-0050 accepted; F301 (Gmail 7-day sign-in) added to the backlog. Complete per Harold
(2026-10-22).

## Retrospective

Harold: all 12 rated categories Very Good; no carry-ins, no backlog items, no questions.
- IMP-1 applied: a native OS surface in an MV step is rehearsed by looking (5.1.9).
- IMP-1.1 applied: the WinWright sweep checks the tray icon first (`-TrayCheckOnly`).
- IMP-2a applied: `build-with-secrets.ps1 -StartEmulator` picks the highest-API AVD (`-SelfTest`); IMP-2b not
  reproduced, cause unknown.
- IMP-3 applied: a question states what it decides; standing facts are recorded and not asked again (CLAUDE.md).
- IMP-4 skipped. IMP-5 applied: the Phase 8 Fold-log check reads the first and a later start.
- 7.7.1 final code reviews (Copilot, code-reviewer, silent-failure-hunter): see `SPRINT_80_PLAN.md`.

## Carry-forward

- **Sprint 81 start**: 0.21.0 store builds; read the Fold `new-mail-diagnostics` line (R-2), first and later start.
- **Backlog**: F301 (Gmail 7-day sign-in), F300 (WinWright sweep time), F289, the iOS cards once Harold decides to
  go ahead with iOS.
