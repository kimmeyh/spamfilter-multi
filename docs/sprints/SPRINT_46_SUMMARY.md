# Sprint 46 Summary

> **NOTE (Sprint 57 doc-audit, 2026-08-14)**: This summary was not found in the repository during a repo-wide sprint-documentation audit and has been reconstructed retroactively from PR #270's body/commits and the existing `SPRINT_46_PLAN.md` / `SPRINT_46_RETROSPECTIVE.md` / `SPRINT_46_F33_BODY_RULES_REPORT.md`. Figures not recoverable from those sources are not included rather than invented.

**Branch**: `feature/20260702_Sprint_46`
**PR**: [#270](https://github.com/kimmeyh/spamfilter-multi/pull/270) (merged 2026-07-12)
**Issues**: none opened as GitHub issue cards (backlog tracked directly in `ALL_SPRINTS_MASTER_PLAN.md` per Sprint 46-era process)
**Dates**: 2026-07-02 -> 2026-07-11 (planning through retrospective); merged 2026-07-12
**Retrospective**: `docs/sprints/SPRINT_46_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1692 -> **1731** passing / 0 failing / 29 skipped |
| Analyzer | Clean |
| CI | Green on the PR (first-ever run on this repo; caught and led to fixing a real cross-platform test bug) |
| Manual Validation | Complete, three feedback rounds (Harold, 2026-07-11) |
| Carry-forward | Dev version bump 0.5.4 -> 0.5.5; F33 prod-DB apply deferred to a separate post-Store-rollout run; `CI_*` repo secrets one-time setup; open Android F108 retest |

## Scope

Approved 2026-07-02: F64 (CI/CD pipeline), F33 (body rules cleanup), F39 (cross-account "No rule" review screen with bulk actions) -- all three taken off HOLD in that day's backlog refinement and assigned Priority 10/20/30.

| Task | Feature | Result |
|---|---|---|
| 1 | F64 | `.github/workflows/ci.yml` added: `flutter analyze` + `flutter test` on `ubuntu-latest`, Windows release-build verification on `windows-latest`; OAuth via `CI_*` encrypted repo secrets |
| 2 | F33 | Group-first body-rules cleanup applied to dev DB: 647 domain rules converted to URL-anchored regex (G1), 84 keyword rules reclassified (G2), 371 truncated/bare-label rules removed (G6), 2 duplicates removed, 3 hand-decided specials, 0 ambiguous. Backup retained; patterns verified valid + ReDoS-safe |
| 3 | F39 | New Windows-desktop-scoped screen aggregating unprocessed "No rule" items across all accounts' latest scans; account filter; multi-select (checkbox/Ctrl/Shift-click); 7 bulk actions with one summary notification per operation; shared `RuleQuickActionService` extracted |

## What shipped

**F64 -- CI/CD pipeline.** First GitHub Actions workflow for the repo, gating every PR to `develop` with the same checks already run manually in Phase 5 (analyze clean, full suite green, Windows build succeeds), plus a Windows build-verification job on `windows-latest`. Its first run surfaced a real cross-platform test bug, which was fixed as part of the sprint.

**F33 -- Body rules cleanup.** A group-first classification pass (G1-G6 plus a small hand-decided SPECIAL set) over 1109 body-condition rules in the dev DB, restructured mid-sprint (Harold, 2026-07-02) from a single classify-and-rewrite pass into grouping first, then per-group conversion. Net result: 648 patterns converted to URL-anchored regex, 84 reclassified, 377 removed (truncated/orphan/duplicate), 0 left ambiguous. Full findings report at `docs/sprints/SPRINT_46_F33_BODY_RULES_REPORT.md`. The prod-DB equivalent was deliberately deferred to a separate `--env prod --apply` run after the 0.5.4 Windows Store rollout, not part of this PR.

**F39 -- Cross-account "No rule" review screen.** Scope was materially restructured during Phase 4 after a clarifying question surfaced the real need: not "add multi-select to the existing per-account Results screen" (the original backlog wording) but a single aggregated, account-filterable list of each account's latest-scan "No rule" items, with multi-select and 7 bulk rule-application actions (Add Safe Sender / Add Block Rule x Exact Email / Exact Domain / Entire Domain, plus Remove Current Rule) collapsed into one summary notification per bulk operation instead of one per item. Delivered as a new screen (not grafted onto the 2812-line existing Results screen) reusing rule-creation logic via a newly extracted `RuleQuickActionService`. Android/iOS multi-select was explicitly deferred, not attempted.

**Manual-testing improvements** (found and fixed during the three Harold validation rounds, 2026-07-11): detail popup opens one email lower so the next item stays clickable; "No rule" filter auto-advance so a quick action immediately opens the next uncovered item's popup (works on live and historical results, regression-tested); and a production bug fix -- `unmatched_emails` had no production writer since a Sprint 4 placeholder, so the review screen always showed 0 items until scan completion was wired to batch-write the "No rule" subset.

## Retrospective improvements (from Sprint 46, executed within-sprint or carried forward)

| ID | Improvement |
|---|---|
| IMP-1 | Provider-sender grouping in all scan-result lists (Results screen all filters + Review screen) -- executed same sprint per Harold's Category 13 do-now feedback |
| IMP-2 | Shared `db_widget_test_harness.dart` for the recurring sqflite-FFI widget-test hang |
| IMP-4 | ARCHITECTURE.md component inventories updated (new `RuleQuickActionService`, `extractRootDomain` utility) |
| IMP-5 | `-SkipClean` build path root-caused (deterministically broken by the native_assets deletion workaround) -- falls back to a full clean |
| IMP-3 | CHANGELOG cadence -- alternatives presented, decision carried to Sprint 47 planning |

## Notes

Retrospective recorded all 12 assessed categories (excluding the two verbatim-feedback categories) as "Very Good" from the Harold PO/SM/Lead-Developer perspective; the Claude Code Development Team self-assessment noted three concrete efficiency losses (sqflite-FFI widget-test hang re-diagnosis, two failed `-SkipClean` rebuilds, CHANGELOG lag until Phase 6) and an effort-accuracy miss on F33 (ran 1.5-2x over estimate due to live-data edge cases not modeled in the original estimate).
