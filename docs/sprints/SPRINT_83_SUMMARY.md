# Sprint 83 Summary

**Dates**: 2026-10-31 to 2026-11-05
**Branch**: `feature/20261031_Sprint_83` | **PR**: #534 -> develop
**Version**: 0.24.0+21 (bumped at plan approval; MINOR, F322 and F270 are user-facing `feat`s)
**Suite**: 3,360 -> 3,587 passed, 15 skipped (local run 2026-11-05, before c9f21abf: 8 failed, of which 5 pass when
run alone and 3 Task Scheduler tests time out; `Get-ScheduledTask` takes 7-21 s on this machine, cause unknown) | CI
run 1 and run 2 green (analyze and test, Windows build, Android build) | Analyzer clean | Hook suite 178/178

## What this sprint was for

Act on what Sprint 82 counted: a scan notification only when there is something to review (F322), the next No Rule
suggestions with a "could not check" rule (F323), and the user told when an account's background scanning is off or
its sign-in failed (F324). Start safe-sender discovery (F270) and mine Harold's own mail for rule patterns (F308,
F310, research F309). Count the No Rule signals before widening them (F305 R-2). Pilot Python for deterministic
tooling (F321, ADR-0051). Quiet the Kotlin build noise (F237). Run the first-run evaluation (F325). Finish the
Sprint 82 phone checks (MV-3, MV-4). Every card named its Windows, Android and iPhone paths (ADR-0042, ADR-0049,
ADR-0050).

## Delivered

- **F322 (#536)** -- Settings > Background "Scan notifications": "Every Completed Scan" or "Only when one or more No
  Rule items" (the new default). Android uses two channels with the same names, so each can be turned off in the
  phone's settings.
- **F323 (#537)** -- F306 v2: no Block suggestion when a sender check could not finish (including a saved scan with
  no headers); Block Body in the pop-up (the first link domain that is not the sender's or a safe sender); a
  `news_`-style sender offers "Block sender pattern", with Block Entire Domain as the Suggested item.
- **F324 (#538)** -- account settings kept across remove and re-add; the account list shows a "background scanning
  is off" line with "Turn on" (the same enable path as Settings); IMAP accounts (AOL, Yahoo, iCloud, custom) show
  "Sign In Again" after a refused password, and get no background login or pop-up read until the user signs in again.
- **F270 v1 (#539)** -- Manage Safe Senders shows suggested safe senders from stored history, with Accept and
  Reject; a candidate that a block rule matches is not offered.
- **F305 R-2 (#540)** -- signal counts from the DEV content history; Harold's Q6 = 2 applied: a Reply-To mismatch
  suggests Block, and its chip reads "Reply-to email mismatch".
- **F308 (#541), F310 (#543)** -- developer mining tools and reports for delete-rule and safe-sender patterns.
- **F309 (#542)** -- research report on trusted-sender sources; the hint decision is F343.
- **F321 pilot (#544)** -- Python hook library and pilot hooks; ADR-0051 accepted; backlog cards F326-F340 and F344
  for everything not converted.
- **F237 (#545)** -- `kotlin.incremental=false`: 30 daemon traces to 0, build not slower.
- **F325 part A (#546)** -- static first-run pass (`docs/research/F325_FIRST_RUN_EVALUATION_S83.md`).
- **Task 1** -- MV-3a, MV-3b PASS on the Fold; MV-4 counts closed F303 (#524) and F315 (#527); M-6 toast click PASS.
- **Version (#535)** -- 0.24.0+21.
- **Manual Validation fixes** -- Select Account rows neutral while loading; the email pop-up grows to fit the
  default window, with a compact header; the notification list opens below its row.
- **7.7.1 review fixes** -- one background-enable path, one IMAP id list, one body-text selection for the pop-up and
  the rules (HTML-only mail now matches body rules, with link addresses kept), no login while an IMAP account is
  flagged, the lockout count kept on re-save.

## Not delivered, and why

- **F325 part B (live first-run run)** -- moved to F341 by Harold (*"Wait this to a future sprint"*, Class 3).
- **MV-3c ("Suggested" on a YELLOW item)** -- no YELLOW No Rule item existed on the phones; it waits for one (Q3 = 1).
- **F67a (#509), F304 (#510), F67b (#523)** -- still wait on Apple's approval of enrollment `R6QG2A9SHS`.

## What went right

- The 7.7.1 reviews again ran before the retrospective, and the retrospective worked from finding classes; all four
  improvements were applied the same day.
- Evidence came before changes: F305 R-2 and the MV-4 counts settled their questions with numbers.
- Every guard fix and every new test that guards a bug was mutation-checked; all mutants KILLED.
- The improvement review found a real regression in a review fix (link addresses lost on Gmail HTML-only mail)
  before it shipped.

## What cost time

- Copies that drifted from the code they copied (three 7.7.1 findings): fixed by merging each into one shared path;
  IMP-1 now asks for the existing code on the card.
- Text that still described the behavior before a Manual Validation change (eight places): IMP-2 (b) adds a sweep
  record.
- Tools that reported success when they did nothing, including `test-hook.ps1` passing a crashed hook: IMP-3.
- Agent time lost across usage-limit stops (Tasks 1, 2, 4 and 10 have no full actual): IMP-4 adds RUN STARTED and
  RUN STOPPED lines.

## Manual Validation

Windows DEV 0.24.0 and the Fold (0.23.0 from Play), four rounds. W-3 to W-6 as expected (M-6 toast click PASS with
the app open and closed); W-1 and A-1 renamed at Harold's request ("Every Completed Scan" / "Only when one or more No
Rule items"); W-2 and W-7 rehearsed by test only. Fixes in ec5f94b8, 92692871, 42d7e722, 62546100, 90e924fb,
f07575af. MV-3c carried; F325 live run to F341. Complete per Harold (2026-11-04).

## Retrospective

Harold: all categories Very Good.
- IMP-1 applied (option 1): the card gains "Existing code reused"; 5.1.2 checks the code calls it and that each
  test's name matches its checks.
- IMP-2 (b) applied: an MV answer that renames or changes a behavior records a "Swept:" line.
- IMP-3 applied: `test-hook.ps1` exits 1 on a crashed hook and survives PowerShell 5.1 stderr; the "never report
  success when nothing ran" rule is in TESTING_STRATEGY and the 5.1.2 questions.
- IMP-4 applied: agent progress files record RUN STARTED and RUN STOPPED; `agent-work-status` adds them up.
- 7.7.1 final code reviews, improvement review and CI: see `SPRINT_83_PLAN.md` "7.7.1 final code reviews".

## Carry-forward

- **Next sprint**: MV-3c when a YELLOW item appears; iOS Tasks 1-3 when Apple approves.
- **Backlog**: F341 (live first-run run), F342 (Fold background log errors), F343 (trusted-sender hint), F344
  (prompts as Python tools), F326-F340 (Python conversion batches and audits).
