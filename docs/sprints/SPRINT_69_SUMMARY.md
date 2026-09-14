# Sprint 69 Summary

**Sprint**: 69 -- Android tester experience
**Dates**: 2026-09-11 to 2026-09-14
**Branch**: `feature/20260910_Sprint_69`
**PRs**: #410 (-> `develop`), #411 (`develop` -> `main`)
**Version**: 0.15.0+3 -> **0.15.1+4** (msix 0.15.1.0)

## What this sprint was for

Every item was found by using the shipped app on real hardware -- four of the five by Harold or
his first external tester on a Galaxy S24+ running the 0.15.0 closed test. None came from a test
suite or a code audit.

## Delivered -- 5 of 5

| ID | What | Issue |
|---|---|---|
| F211 | Google Sign-In dead end made actionable; the console defect diagnosed | #405 (open) |
| F210 | Dark-mode contrast, **9 instances**, plus the gate that finds them | #406 |
| F208 | YAML import restored on Android | #407 |
| F209 | Android navigation bar no longer covers screen bottoms | #408 |
| F203 | Skipped safe senders disclosed instead of reported as nothing found | #409 |

## Metrics

| | Start | End |
|---|---|---|
| Test suite | 2,074 passed | **2,119 passed**, 15 skipped, 0 failed |
| Policy gates | 109 | **114** |
| Analyzer | clean | clean |

Code review: **7 findings first pass, 1 critical second pass, all addressed, none deferred.**
F-PRECHECK: 2 findings, both fixed. Copilot: 1 finding, which led to 4 more by sweep.

## The three things worth remembering

**1. Every card the audit touched got bigger.** F210 was filed as 1 instance, raised to 4 by the
planning audit, and finished at 9 once the extended gate could see the whole class -- the last 5
all in dialogs, exactly where the card predicted they would hide. F209 was filed as "some screens"
and turned out to be 21 of 23. The audit-first check is what converted both from guesses into
scope.

**2. My own gates were the least reliable code in the sprint.** The F210 detector passed its
mutation test and was still blind to the defect in the commonest layout in the codebase, because
bracket depth goes negative on an enclosing `Container(` as readily as on a `TextStyle(`. The same
flaw was in the F197 gate shipped in Sprint 68 -- reviewed, merged, and wrong twice. Then the F209
wiring gate reported green while two screens were genuinely unwrapped, because it matched
`return Scaffold(` and those screens return a wrapper. And when that was fixed, it STILL passed,
because a comment mentioning the widget satisfied a substring test.

Three gates, three different ways of being green and wrong.

**3. F209 was delivered twice.** The first implementation worked -- content cleared the navigation
bar -- and would have re-broken the F178 action popup Harold found by screenshot in Sprint 62,
plus pushed every keyboard screen 48 logical pixels too high. Both were found by review before
they reached his phone, and both were reproduced by probe rather than argued about.

## Validation

**Windows: complete.** F210 7 of 9 cells confirmed, F203 confirmed, no-regression confirmed.

**Carried forward, not waived:**
- F210's remaining 2 cells (sign-in failure details; Gmail manual token warning) need a real
  sign-in failure to provoke.
- F208 and F209 need a Play-installed Android build. Harold: *"These have to wait until live on
  Google Play (after next update)."*
- F211 AC-1 needs the console changes plus a Google account that has never authorised the app.
  **#405 is deliberately left OPEN for this reason.**

## Retrospective

All 14 categories x 4 roles. Harold: Very Good across 12, none for 13.

**Category 14 produced the most consequential finding of the sprint**: background scans not
running while the phone is locked, corroborated by a Scan History screenshot showing 2h42m between
runs against a 15-minute schedule. Filed as **F217, Priority 6**.

**IMP-4 was rejected**, and the rejection reshaped the outcome. Harold: *"instead of expecting
re-work, we should be improving the prompts sent in order to reduce the chance of rework."*
Sorting 13 rework events across two sprints by cause put 11 of them in two buckets -- concluding
without opening the thing being concluded about (7), and verifying the happy path but not the
failure path (4). Two rules replaced the estimate-padding proposal.

## Backlog added

**F212** re-processing fails 100% (Priority 4) - **F213** Custom URI schemes are Google's legacy
path - **F214** slider margins, from the tester - **F215** wire the screenshot folder into every
process - **F216** supporting text smaller than adjacent text, 3 screens - **F217** background
scans deferred for hours (Priority 6)

## Infrastructure added

`validation-screenshots/` with a tracked per-sprint INDEX -- 56 screenshots pulled off the S24+
over MTP, gitignored but durable, closing the gap where validation evidence existed only in a chat
session.
