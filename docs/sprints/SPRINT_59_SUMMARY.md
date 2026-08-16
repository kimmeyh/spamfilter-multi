# Sprint 59 Summary

**Dates**: 2026-08-15 (single day)
**Branch**: `feature/20260815_Sprint_59` | **PR**: #326 -> develop
**Scope**: F150 (Android build blocker, Issue #322/#315), F153 (WinWright/UIA re-test, Issue #323),
F155 (Review No Rule Items rename, Issue #324), F154 (dedicated Help section, Issue #325), plus
unplanned WinWright sweep restoration. Same-day context: 0.8.0.0 / Submission 15 certified and
live on the Microsoft Store; Step 7 release close-out; dev bumped to 0.8.1+1.

## What Shipped

- **F150**: Android debug builds restored end to end. Harold registered `com.myemailspamfilter`
  in Firebase Console (screenshot-guided; one browser-autofill mis-registration caught BEFORE
  download and removed); the fresh `google-services.json` fixed `:app:processDebugGoogleServices`
  immediately, unmasking a second pre-existing blocker: `flutter_local_notifications` 16.x does
  not compile against Android SDK 34 (upstream `bigLargeIcon` ambiguity) -- bumped to ^17.0.0
  (we use only initialize/show, not the scheduling APIs where v17's breaking changes live).
  Debug APK installs and launches on the emulator; F142's deferred visual check passed
  opportunistically (zero accounts lands on Select Account; F151a's welcome state renders on
  Android); app icon added to the emulator home screen via adb drag-drop. SHA-1 fingerprint
  registered same-day and the refreshed config installed -- Google Sign-In unblocked for the
  Android track.
- **F153**: F140's Sprint 54 "Flutter exposes zero UIA patterns" conclusion REFUTED by a clean
  re-test with the `SPI_SETSCREENREADER` flag enabled. New root cause found: Flutter builds its
  semantics tree lazily -- the first raw query after launch is empty even with the flag on; one
  `ww_get_snapshot` primes it. Verified working: InvokePattern on Buttons, direction-mode
  scrolling with correct semantics (~165px/call), full off-screen tree visibility, direct
  automation read of the Settings version text (closes F139's "Known gap"). Verified broken:
  `ww_scroll` into_view (RuntimeId unsupported via handle; silent false-success via selector).
  Three doc sites corrected consistently; a mandatory two-step WinWright pre-flight added to
  SPRINT_PLANNING.md.
- **F155**: 'Review "No Rule" Items' -> 'Review No Rule Items' everywhere current -- 31
  occurrences across 10 lib files, 6 test files, walkthrough.md; policy gates enforce the NEW
  name (mutation-verified); historical records untouched per Harold's forward-only instruction.
- **F154**: the app's default screen finally has its own Help section
  (`HelpSection.reviewNoRuleItems`, 22 -> 23; ADR-0038 content pipeline; content written from the
  screen's actual behavior). The screen's Help icon deep-links there instead of the
  `resultsDisplay` stand-in carried since F133-S52; new wiring test mutation-verified against
  exactly that regression. Harold confirmed the content at Manual Validation.
- **Unplanned -- WinWright sweep restoration**: the end-of-sprint sweep failed 3/3 and was
  restored to green (3/3 scripts, 66/66 steps). All three active scripts had been structurally
  stale since F135 (Sprint 52) -- the sweep had not actually run green since 2026-07-28. Runner
  launch-wait hardened (the post-F135 home screen runs its covered-item sweep before the window
  titles itself); new `winwright_script_strings_test.dart` policy gate fails the Dart suite if
  scripts reference retired UI strings (implements a Claude cowork review suggestion).

## Verification

- Full suite at close: **1,893 passed / 29 skipped / 0 failed** (from 1,891 at Sprint 58 close);
  deep-link integration 32/32; WinWright sweep 3/3 with the DB drift guard operational;
  `flutter analyze` clean throughout; every new/changed gate mutation-verified.
- Manual Validation: complete (Harold, 2026-08-15) -- F154 and F155 confirmed working as expected.

## Notable Process Events

- The 7-sprint silent WinWright sweep skip (Sprints 52-58 all touched lib/ui) became the sprint's
  central process lesson: checklist lines that leave no artifact cannot be audited. IMP-5 now
  requires recorded sweep evidence in the plan's completion notes.
- The runner's DB snapshot guard turned out to be silently broken all along: Windows PowerShell
  5.1 writes a UTF-8 BOM when piping to sqlite3, so every table read failed and was treated as
  empty. Fixed (no stdin, `-list` flag, loud failure); the runner now refuses to sweep unguarded
  unless explicitly waived.
- Flutter's own gradle-file migrator silently rewrote the F108 `minSdk = 23` pin during the first
  Android build -- caught at commit-time `git status` review, reverted. Harold declined a
  pin-protecting gate (IMP-6 skipped: keep upgrade freedom) and instead registered F157: an
  impact study on adopting the modernization, implementing in-item if < 200 LOC and < 2h.
- Store release 0.8.0.0 (Submission 15) uploaded, certified, and confirmed live the same day;
  second MINOR release under the enforced semver policy.
- Retro: Harold rated ALL 14 categories "Very Good"; 6 improvements proposed, 5 approved and
  applied (IMP-1 grep-truncation memory, IMP-2 unfiltered-logs memory, IMP-3 DEV-scoped
  WinWright attach, IMP-4 snapshot-guard fix, IMP-5 sweep artifact rule), IMP-6 skipped with
  recorded rationale. F156 (full Android walk-through) and F157 registered in the backlog.

## Reference Docs

`SPRINT_59_PLAN.md` (per-task cards + completion notes incl. sweep evidence),
`SPRINT_59_RETROSPECTIVE.md`, `drafts/SPRINT_59_RETROSPECTIVE_claude_draft.md`,
CHANGELOG.md 2026-08-15 Sprint 59 entries, `docs/WINWRIGHT_SELECTORS.md` (rewritten capability
record).
