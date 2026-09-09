# Sprint 67 Summary

**Dates**: 2026-09-08 to 2026-09-09
**Branch**: `feature/20260908_Sprint_67` | **PR**: #396 -> develop
**Scope**: F194 (#392), F195 (#393), F193 (#394), F196 (#395)
**Version**: 0.14.2 (PATCH, bumped at plan approval per F190)

**Theme**: fix what the closed test will hit, and close the two process gaps Sprint 66
exposed.

## What shipped

**F194 -- Scan History drew a DEAD scan with the running-scan icon.** The background scan was
never broken. `scan_history_screen.dart` chose its status icon with a TWO-branch ternary over
FOUR statuses, so an `interrupted` row -- one that F175 startup reconciliation had already
detected and marked -- was drawn identically to a scan still running. The duration text beside
it already read correctly; a PR #355 Copilot review had added that. The icon was never updated
to match, so text and icon contradicted each other on the same row. `interrupted` now gets
its own grey `Icons.cancel`, and the text reads **"Not finished"** (Harold's wording, chosen
at Manual Validation over "Interrupted").

**F195 -- the account header measured 1.14:1 in dark mode.** A hardcoded `Colors.blue.shade50`
surface with theme-derived text: 18.39:1 in light mode, 1.14:1 in dark, against a 4.5:1 WCAG
AA requirement. Anyone testing in light mode saw nothing wrong. Now pairs
`secondaryContainer` with `onSecondaryContainer`, so Material guarantees the relationship in
both modes rather than it holding by coincidence.

**F193 -- Phase 5 evidence is gated at the Manual-Validation boundary.** The check already
existed and was already correct; it was wired to the wrong event, firing on a close-out claim
when the checklist requires the artifacts BEFORE Manual Validation. It now runs inside
`sprint-auto-advance.ps1` Gate 1c, which was already watching that exact transition. Its first
genuine use came the same sprint: it ALLOWED the MV transition because all three artifacts
were recorded, and would have blocked had any read `PENDING`.

**F196 -- release notes are derived per store.** One `CHANGELOG.md` remains the engineering
record; entries may now carry `[android]` / `[windows]` / `[internal]` tags, with no tag
meaning all platforms. `STORE_RELEASE_PROCESS.md` Step 1b derives
`RELEASE_NOTES_<version>_windows.md` and `_play.md` from it. **ADR-0043** records the
versioning decision Harold raised, which until then existed only in conversation: one version
across all platforms, advanced in lockstep, with a version permitted to advance without being
submitted everywhere.

## The sprint's defining pattern: three artifacts that looked like proof and were not

Worth recording as one story rather than three incidents, because the shape repeated.

**The F194 test pinned the store contract, not the call.** Deleting the fix left it green.

**Two F194 fixes were written and WITHDRAWN entirely** -- a catch-all for non-timeout throws
and a coordinator lease release beside it. Both were redundant: `EmailScanner.scanInbox`
already calls `errorScan()` on any exception and already releases the lease in its `finally`.
Production code ended byte-identical to where it started. The cause was diagnosing from the
middle of a call chain without reading the layer beneath it.

**The F195 test measured Flutter's stock themes**, not the app's. The app builds its schemes
with `ColorScheme.fromSeed` in `AppTheme` and ships `themeMode: ThemeMode.system` -- which is
how Harold hit the defect in the first place. The test proved a fact about Flutter.

**The F193 gate was satisfied by any prose mentioning a marker name**, and my own F-PRECHECK
writing defeated it within minutes of shipping: two sentences referring to "the 5.1.1
reviewer" convinced the gate that 5.1.1 was recorded while the real marker still read
`PENDING`.

**Not one of these was found by reading.** Each was caught by something trying to break it --
a mutation that refused to fail, a review, or the hook's own test suite.

## What the Phase 5.1.1 review found

Run BEFORE Manual Validation, which is exactly what F193 exists to enforce, and it justified
itself immediately by finding a **live regression**:

- **The F193 gate fired during Phase 4** and broke **6 of that hook's own test cases**. Gate 1c
  matched "Manual Validation" as a SUBSTRING, and the live status line reads "...standing
  approval through Manual Validation" as prose. Same defect class as the one fixed a commit
  earlier, surviving one level up in the condition that decides whether to run the check.
- **The block message went to stdout** while every other blocking path uses stderr, and the
  test runner discards stdout -- it would have blocked with the reason thrown away.
- **The gate had zero test coverage**, which is how both shipped.
- **A claim of mine was simply wrong**: I said the contrast pattern appeared "28 times,
  concentrated in `account_setup_screen.dart`". Measured, it is TWO, and that file cannot
  contain the pattern at all because it never uses `textTheme`. I had grepped the easy proxy
  (`shade50`, 29 hits) and reported it as the defect count. F197 was rewritten from a 28-site
  sweep into a gate, since after fixing the second instance there is nothing left to sweep.

## The emulator was never broken

Reported as an unfixable SDK toolchain fault after ONE failed launch. Harold refused the
conclusion -- the emulator is the only pre-Store Android test path, so "it MUST work".

This machine has TWO Android SDK installs: `C:\Android\android-sdk\emulator` at **36.2.12.0**,
which `ANDROID_HOME` correctly points at, and a 2019 leftover at `%LOCALAPPDATA%` at
**29.3.4.0**, which I hardcoded. Emulator 29 predates the kernel format Android 34 images use,
producing "Can't find 'Linux version' string in kernel image file" -- an error that reads like
a corrupt image and is really a version mismatch. The kernel file was present and full-sized
the whole time. The fix was one command.

Recorded in `TROUBLESHOOTING.md` and generalised into `CLAUDE.md` as IMP-3.

## Harold's counter-example, and why it mattered

At F195 he noted that Settings > Manual Scan > Default Folders is a similar-looking
blue-on-pale-blue box that reads perfectly. It does -- because it pins BOTH halves
(`blue.shade900` on `blue.shade50`, measured 7.56:1).

That single observation moved the diagnosis from "hardcoded colours are bad" to the actual
rule: **the defect is MIXING a hardcoded surface with theme-derived text.** It prevented a
28-site sweep that would have churned working code, and it is why F197 is now scoped as a gate
rather than a rewrite.

## Metrics

- Commits: 12 on the sprint branch
- Test suite: **2,060 passing / 15 skipped / 0 failing**
- Policy suite: 99 passing (was 96)
- Hook suite: **53 passing / 0 failing** (was 45/6 when the review found the regression)
- Analyzer: clean
- WinWright: 2/2, 29 assertions, sweep-head `52fbc7d`
- New tests: 3 files; 2 new hook test cases with Sprint-67 fixtures
- New ADR: 0043

## Phase 5 evidence

All three recorded in `SPRINT_67_PLAN.md` BEFORE Manual Validation, which is the ordering F193
now enforces mechanically:
- **5.1.1**: `pr-review-toolkit:code-reviewer` on `cd8ff34..HEAD` -- found the live regression
- **5.1.2**: F-PRECHECK, all six classes
- **5.1.5**: WinWright 2/2 at sweep-head `52fbc7d` -- run rather than argued as N/A

## Manual Validation

Harold, on Windows, all five recommended steps PASSED: account header readable in dark and
light, interrupted row shows its own icon, a running scan still shows the orange clock and
flips to a green check on completion, dark-mode info strip fixed. One wording change
requested and applied: "Interrupted" -> **"Not finished"**.

Android emulator validation was blocked, then unblocked once the path mistake above was
found. A clean debug install of 0.14.2 is on `pixel34_updated`.

## Retrospective outcome

Harold rated 11 categories "Very Good"; Categories 13 and 14 "none"; no open questions.
Category 1 was a documentation request rather than a rating -- the Copilot reviewer-visibility
finding, verified empirically before being written down.

Four improvements: **1-3 applied now** (Copilot request method in the workflow doc; run a
hook's own test suite after modifying it; resolve tool paths through the configured
environment variable). **IMP-4 to the backlog as F198**, tentatively Sprint 68: a forcing
function for the numbered-question format, after a fourth correction of the same rule.

## Carried into Sprint 68

F198 (tentative), plus the standing critical path: tester recruitment for the Play closed test.
Nine more testers are needed, and the application date is set by the twelfth person to opt in.
