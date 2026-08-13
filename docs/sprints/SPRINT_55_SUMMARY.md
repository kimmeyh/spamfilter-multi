# Sprint 55 Summary

**Branch**: `feature/20260809_Sprint_55`
**PR**: [#304](https://github.com/kimmeyh/spamfilter-multi/pull/304)
**Issues**: #305, #306, #307
**Dates**: 2026-08-09 -> 2026-08-10
**Retrospective**: `docs/sprints/SPRINT_55_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1,850 -> **1,857** passing / 0 failing / 29 skipped |
| Analyzer | Clean |
| Windows build | Green |
| Manual Validation | Complete (Harold, 2026-08-10) -- 2 follow-ups found and fixed same-sprint |
| Store release | 0.6.0.0 certified + LIVE (Submission 11, 2026-08-10) -- mid-sprint pivot |
| Carry-forward | None |

## Scope

Approved 2026-08-09: F147, F146, F145. Plus a mid-sprint Store release pivot (Backlog Refinement candidate, promoted ahead of schedule) and 2 unplanned Manual Validation follow-ups.

| Task | Feature | Result |
|---|---|---|
| 1 | F147 | Scan-all-emails cursor bypass (IMAP no-rule backlog cursor + Gmail historyId cursor), 7 mutation-verified tests |
| 2 | F146 | Generalized "AOL copy-not-move" error message across 6 files (confirmed also firing on Gmail-IMAP) |
| 3 | F145 | Help-icon deep-link coverage; WinWright spike found a false-failure signal, re-scoped to `integration_test`, surfaced + fixed a real HelpScreen scroll-timing bug; 27 new tests |
| -- | Store release | 0.6.0.0 built, verified, submitted, certified, LIVE (Submission 11) |
| MV-1 | Follow-up | Settings tab-scoped Help deep-link fix, 4 new regression tests |
| MV-2 | Follow-up | Help > First-Use Walkthrough rewrite (8 steps, up from 6) |

## What shipped

**F147 -- scan-all-emails cursor bypass.** "Scan all emails" was silently overridden by the no-rule backlog cursor (IMAP) and the historyId cursor (Gmail OAuth), for both Manual and Background scan. Fixed by bypassing the cursor whenever `daysBack<=0`. 7 new mutation-verified tests in `email_scanner_scan_all_bypass_test.dart`.

**F146 -- generalized AOL error message.** The "AOL copy-not-move" error message was AOL-specific in wording but confirmed also firing on Gmail-IMAP; generalized across 6 files.

**F145 -- Help-icon deep-link coverage.** A genuine Tooling-Capability Pre-Flight spike drove WinWright live against the running app and found it produces a FALSE FAILURE for scroll-target verification (worse than a blind spot) -- documented as a durable rule in `docs/WINWRIGHT_SELECTORS.md`. Re-scoped to `integration_test`, which then surfaced and fixed a real `HelpScreen` scroll-timing bug: async section content had not settled before the deep-link scroll computed its target, landing later sections up to ~4000px short of the viewport top. 27 new tests in `integration_test/help_deep_link_test.dart` covering all 22 `HelpSection` values.

**Store release (mid-sprint pivot).** 0.6.0.0 built, verified (manifest version, `--release-self-test`, policy gates), uploaded by Harold, certified, and confirmed LIVE on the Microsoft Store (Submission 11, 2026-08-10) -- the first release under the semver policy enforced starting Sprint 54. Check C smoke test on the live Store build (Gmail sign-in, About screen, title bar) confirmed clean.

**Manual Validation follow-ups (same sprint, not deferred).** Settings screen's Help icon always deep-linked to the General tab's section regardless of which tab (Account, Manual Scan, Background) was actually visible -- root cause was a missing `setState()` on tab change; fixed with a dedicated `TabController` listener, 4 new regression tests. Help > First-Use Walkthrough rewritten per Harold's feedback (8 steps, up from 6) -- corrected one button-label reference against actual app code ("Block Exact Domain", not "Block Domain") before committing.

**Process gap found and fixed.** GitHub issue cards for F145/F146/F147 were only created retroactively when `require-sprint-cards.ps1` blocked the first commit -- all 3 tasks were already fully implemented by then. Second recurrence of the Sprint 52 retro IMP-2/IMP-6 failure class. New Phase 3.7.0 step added to `SPRINT_EXECUTION_WORKFLOW.md`: cards are now created in the SAME turn as plan-approval acknowledgment, before any task file is touched.

## GitHub Copilot review (PR #304)

Requested by Harold after merge-readiness. 2 real findings, both fixed in commit `e8fc7ce`:
- `settings_screen.dart`'s `TabController` listener called `setState()` on every notification (fires twice per tap with the same index) -- added an index-comparison guard.
- `.claude/sprint_status.json`'s `store_release.live_version`/`live_submission_number`/`previous_live_version` still showed the prior release despite the rest of the block correctly describing 0.6.0.0/Submission 11 as live -- updated to match.

Both threads replied to and resolved via GraphQL `resolveReviewThread`.

## Retrospective

All 14 categories rated Very Good. 1 improvement, applied: new Phase 3.7.0 step in `SPRINT_EXECUTION_WORKFLOW.md` (card-creation-ordering fix, detailed above).

## Merge

PR #304 merged to `develop` 2026-08-12 (Harold). `develop` -> `main` also merged same session (PR #308). Issues #305/#306/#307 closed by hand during Post-Merge Cleanup (verified via `gh issue list --label sprint --state open` returning empty). Sprint 56 branch opened via Phase 6.6 carry-forward immediately on merge notification.
