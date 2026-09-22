# Sprint 72 Summary

**Dates**: 2026-09-22 (single continuous session)
**Branch**: `feature/20260919_Sprint_71` | **PR**: #420 -> develop
**Version**: 0.15.2+5 -> 0.15.3+6

**Note on the branch name**: Sprint 72 ran entirely on the Sprint 71 branch. Sprint 71 was never
separately executed -- its stub's carry-ins were folded into this sprint, and Harold approved
putting these commits into that branch's PR. `SPRINT_71_PLAN.md` is marked SUPERSEDED.

---

## What this sprint was for

Make failed mailbox actions **diagnosable and honest**. Every planned item came from Harold's own
device testing in Sprint 71: the app was telling him work had succeeded when it had not, and when
he tried to find out why, nothing had been written down.

## Delivered

- **F233** -- a diagnostic log that can actually be handed over, plus the header-only CSV export
  fix. The audit-first check found `LiveScanLogger` already existed, so this became "add a file
  sink" rather than "build a logger".
- **F232** -- rules created from a historical scan view now act on the mailbox. Mechanism A fixed;
  **mechanism B remains undiagnosed and is now instrumented rather than guessed at.**
- **F228** -- the per-action toast no longer claims success over a failed IMAP action.
- **F230 + F231** -- Skip moved out of the sender row, theme text styles, and a durable session
  activity record so a missed toast no longer loses the outcome.
- **F217** -- honest Android timing caveat. **The mechanism was deliberately NOT built**; see below.
- **F229** -- the export half shipped. The screen half was attempted and reverted.
- **Task 0** -- 22 unmerged documentation commits cleared, including a Gate 1c hook repair.

## Metrics

| | |
|---|---|
| Test suite | 2,155 -> **2,233** (+78) |
| Analyzer | clean |
| Hook suite | 75 passed / 0 failed |
| WinWright | 2/2 scripts, 29/29 steps, no DB drift (run twice) |
| CI | Analyze and Test, Android Build, Windows Build -- all pass |
| Review findings | **3 CRITICAL, 8 IMPORTANT across two reviews -- all fixed, 0 deferred** |
| Manual validation | 4 PASS, 1 failed-fixed-repassed, 1 N/A |
| Backlog filed | F234, F235 |
| Cards | #421-427, plus #428 (F235) |

## The five things worth remembering

**1. My own fix created the defect the plan had warned about.** F232's guard change went inside a
method THREE callers share. Two were the target. The third runs on screen load with no user intent,
and before the fix was inert only BY ACCIDENT -- so removing the accident meant **viewing a saved
scan could delete mail**. The plan named unintended deletion as the risk and the mitigation I wrote
addressed a different one. Caught by the Phase 5.1.1 review. Now IMP-1: grep every caller before
changing a guard.

**2. A green suite hid an unreachable feature.** F233 shipped a logger, settings keys, rotation and
a delete function -- with no toggle. Ten tests passed because every one used the test seam. Harold
opened Settings and asked "where". Now IMP-2: a feature is not done until a user can reach it.

**3. The diagnostic logger was silently destroying the records it existed to preserve.** Found by
the Phase 7 review and verified independently: `File.writeAsString(mode: append)` is not atomic, so
two concurrent failures produced ONE line and ten produced three. Every call site uses `unawaited`,
so the futures are explicitly left to overlap. **The class was built because F232 could not be
diagnosed, and it would have sent the next investigation down the same blind alley.**

**4. A conditional requirement stopped work that would have proceeded on a stale premise.** F217 was
approved on 2026-09-19 believing the battery exemption was the only route. Harold's instruction
built the check into the ask -- *"search to ensure this is the only way"* -- and it was not:
`setExactAndAllowWhileIdle()` fires in Doze with no permission, and Play restricts the exemption to
apps whose core function Doze breaks. Only the honest messaging shipped; the mechanism became F235
with a better approach. **Requirement design did that, not execution.**

**5. Harold found three things reading source did not.** *"The export may only be working if
requested"* named a cause. His background-scan A/B eliminated every environment-level explanation at
once. *"Where"* found the missing UI. Each came from USING the app.

## Validation

- **Windows**: F232, F228, F230/F231 all PASS. F233 failed (no UI), was fixed, and re-passed from
  Harold's screenshot. F217 is N/A on Windows.
- **Not validated**: F219 AC-1 and F227 still need an end-to-end sign-in on the Play build, and
  F217's mechanism does not exist yet to validate.

## Decisions Harold made

- **F232 scan-mode scope**: the MANUAL mode alone governs a foreground action from the results
  screen. He reasoned it out from the airplane-mode behavior and it matched what shipped.
- **F230 platform treatment**: accept larger text on Windows rather than branch -- *"not cause an
  unnecessary exception"* -- keeping it one shared change with no ADR-0042 exception.
- **Version bump**: PATCH (0.15.3), because F233 is developer tooling rather than a user feature.
- **Theme text styles** over raising hardcoded sizes, which also honours the OS font-size setting.
- **IMP-1..IMP-5 approved**, with IMP-3 extended: sweep the scratchpad periodically, and promote
  helpers that are written repeatedly.

## Backlog added

- **F234** -- read-only as a PREVIEW mode: record what WOULD have been deleted, so a broad rule's
  blast radius can be vetted before anything is removed. Harold's idea during validation.
- **F235** -- implement `setExactAndAllowWhileIdle()` for Android Doze. **Targeted for Sprint 73**,
  with the `USE_EXACT_ALARM` policy risk and the reboot-persistence regression already written in.

## Infrastructure added

- `scripts/test-hook.ps1` -- run any hook against a crafted payload with `-ExpectBlock` /
  `-ExpectAllow`. Promoted from a `probe.ps1` hand-written repeatedly; its value is making
  failure-path testing cheap.
- `scripts/clean-temp-scripts.ps1` -- sweeps scratchpad helpers older than 10 days and reports
  promotion candidates. Failure-path tested before being trusted.
- CLAUDE.md IMP-1 through IMP-5, plus three new MANDATORY card lines in `SPRINT_PLANNING.md`.
- The US-English convention, which had never been written down anywhere.
- A fourth silent trap recorded in the `copilot-pr-review` skill: the REST reviews endpoint returns
  `copilot-pull-request-reviewer[bot]`, so an exact-match watcher reports "no review" indefinitely.
  My own watcher did exactly that for 25 minutes while the review sat there.
