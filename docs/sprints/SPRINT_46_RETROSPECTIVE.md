# Sprint 46 Retrospective

**Date**: 2026-07-11
**Branch**: `feature/20260702_Sprint_46` (PR #270, draft until end of 7.7)
**Scope delivered**: F64 (CI/CD pipeline via GitHub Actions), F39 (cross-account "No rule" review screen with multi-select bulk actions), F33 (body rules cleanup -- 647 converted / 84 reclassified / 375 removed, applied to dev DB), plus 3 manual-testing improvements (popup position, "No rule" auto-advance, auto-advance speed) and a historical-path regression test.
**Tests**: 1731 passed / 29 skipped / 0 failed (from 1692). `flutter analyze`: clean. CI green on the PR.

4 roles x 14 categories. Harold wears PO / SM / Lead Dev; Claude provides the Claude Code Development Team role.

---

## Sprint 46 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Good overall -- 3 planned items plus 3 manual-testing improvements landed with a green suite throughout. Three avoidable losses: ~25 minutes re-diagnosing the known sqflite-FFI widget-test hang before recalling the documented runAsync workaround; two failed `-SkipClean` rebuilds (flaky native-assets issue) before applying the documented clean-rebuild remedy; CHANGELOG.md entries lagged until Phase 6 instead of accompanying each Phase 4 commit.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Strong sprint for testing: suite grew 1692 -> 1731 (+39). F33 got 18 classification unit tests plus a compile/ReDoS safety net over all 732 post-cleanup patterns; F39 got 9 service + 6 utility + 5 widget tests with behavior-parity verified against 20 pre-existing screen tests; the auto-advance got a historical-mode regression test. F64 means every future PR runs the suite on CI -- and its first run caught a real cross-platform bug.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Mixed. F64 within estimate (~30m vs 25-40m). F39 at the top of the revised estimate (~130m vs 90-140m) after the scope restructure. F33 ran 1.5-2x over (~120m vs 55-85m) -- the classification code was quick, but the live-data edge cases (escaped hyphens, phone numbers, truncated families) and the clarifying rounds were the real work, and the estimate did not model them. Manual-testing fixes were reactive/unestimated per convention.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: The plan was structurally sound but two of three items changed materially mid-flight: F39's real requirement (cross-account aggregation, latest-scan-only) only surfaced when I asked a clarifying question during implementation, and F33 went through Option A -> Option B plus special-case rounds. Harold's up-front relaxation of stopping rules for this sprint is what made those pivots cheap; without it both items would have been built wrong first.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Cheapest-first held as planned: Haiku-class work for F64's mechanical CI config, Sonnet-class for F33/F39 judgment work, Opus-class for planning/retro. No assignment mismatches surfaced during execution.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Grouped-questions-early worked exactly as Harold intended -- the F33 three-question batch and the F39 batching/screen question each resolved in one round. Mid-turn steering messages (adamshetzner removals, Option B, phone-number conversion) were absorbed without rework. One self-observation: I asked the F33 questions once, then re-surfaced them at two turn-ends while blocked, which read as repetition.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: F39's backlog text ("add multi-select to Scan Results") did not describe the actual need (a cross-account weekly-triage screen); the clarifying-question protocol caught it before code was written to the wrong spec. F33's acceptance criteria could not have anticipated the live-data reality (misclassified keywords, truncated families) -- dry-run-first was the correct structure for discovering requirements from the data itself.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: F33 shipped with a full findings report and revert path; velocity ledger rows recorded for all 7 items including reactive fixes. One miss: CHANGELOG.md was not updated with each user-facing change during Phase 4 (the checklist line exists) and was backfilled at Phase 6.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Three worth recording: (1) the sqflite-FFI + fake-async widget-test hang has now cost time in 3+ sprints -- the runAsync workaround lives as copy-paste lore in one test file and should become a shared helper; (2) the `-SkipClean` build path is unreliable under the known flaky native-assets hook -- two failed builds before applying the documented remedy; (3) CHANGELOG lag per Category 8.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: F33 was the risk center and was handled conservatively: dry-run report reviewed before apply, timestamped DB backup, post-apply count verification, and a compile/ReDoS safety net proving no cleaned pattern became invalid or dangerous. Prod DB deliberately untouched (separate `--env prod --apply` run, post-rollout). CI secrets not yet populated is documented and non-blocking (empty dart-defines still compile).

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: Carry-ins are clear: dev version bump 0.5.4 -> 0.5.5 (Harold's standing instruction); F33 prod-DB apply after the 0.5.4 Store rollout; `CI_*` repo secrets one-time setup; the open Android F108 retest. Backlog is otherwise HOLD-only.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
- **Claude Code Development Team**: No ADR-level changes. F39 added a new screen plus a shared core service (`RuleQuickActionService`) and a shared utility (`extractRootDomain`) -- ARCHITECTURE.md's component inventory gains the new service as part of 7.7 sprint-completion updates (flagged here so it is not deferred).

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner / Scrum Master / Lead Developer (Harold)**, verbatim:
  - "Minor function updates to be completed now - add to backlog, plan for and then do now:
    - In all presentations of Scan Results
      - sort the items with all 'email provider' (i.e. \<name\>@gmail.com) items at the top. If there are any, then before these items include a heading indicating what the items are, and at the end some kind of indicator (use UI best practices). If there are none, then do not include the heading or border. This is because they should be processed together and first."
  - "Minor function updates that need to be added to the next sprint plan: none"
- **Claude Code Development Team**: (a) dev version bump to 0.5.5; (b) F33 `--env prod --apply` run once the 0.5.4 Store rollout is confirmed; (c) populate the 5 `CI_*` GitHub repo secrets; (d) Android F108 retest if an emulator/device session is planned.

### 14. Function Updates for the Future Backlog

- **Product Owner / Scrum Master / Lead Developer (Harold)**: none
- **Claude Code Development Team**: (a) a shared widget-test helper encapsulating the runAsync/sqflite-FFI mount pattern (recurring cost, 3+ sprints); (b) F39 mobile variant (Android/iOS touch multi-select) if ever prioritized -- explicitly deferred this sprint; (c) optional: auto-advance without the "No rule" filter active (currently scoped to the filter per spec).

---

## Combined Summary

Sprint 46 delivered all three planned items -- F64 CI/CD (which caught a real cross-platform bug on its first run), the F39 cross-account "No rule" review screen (scope-corrected mid-flight to the real weekly-triage need), and the F33 body-rules cleanup (1109 rules classified with zero left ambiguous; 647 converted, 84 reclassified, 375 removed, dev DB backed up and verified) -- plus three manual-testing improvements that turned the Results-screen triage flow into a fast click-through loop. Harold rated all 12 assessment categories "Very Good" with one do-now function request (email-provider grouping in Scan Results, Category 13) and no future-backlog items. Claude's self-assessment concurs, flagging three efficiency losses as improvement candidates: the recurring sqflite-FFI widget-test hang (3+ sprints), the unreliable `-SkipClean` build path, and CHANGELOG lag until Phase 6. The relaxed-stopping-rules experiment for this sprint was a clear success -- both mid-flight scope corrections (F39 restructure, F33 Option B) happened before any wrong code was written.

## Improvement Decisions (Harold, 2026-07-11)

- **IMP-1 -- Provider-sender grouping in scan results** (Harold Cat 13): **DO NOW -- DONE.** Harold: "most applicable to 'No rule', but good to have for all filters. F39 - yes." Implemented in `ResultsDisplayScreen` (live + Scan History > scan results, all filters) AND `NoRuleReviewScreen` via shared `ProviderSenderGrouping` utility + `ProviderGroupHeader`/`ProviderGroupEnd` widgets; heading/end indicator only when the group is non-empty. 10 new tests.
- **IMP-2 -- Shared db-widget-test harness** (Claude Cat 9/14): **NOW -- DONE.** `test/helpers/db_widget_test_harness.dart` (`mountAndLoadDbWidget` + the two documented rules); both prior usage sites refactored to it.
- **IMP-3 -- CHANGELOG cadence** (Claude Cat 8/9): Harold: per-commit "seems too often" -- asked for the next 2 best alternatives. Alternatives presented (A: per-completed-item in its final commit; B: Phase-5-entry gate). **Decision not made this sprint -- carried to Sprint 47 planning** (Harold directed PR prep before deciding). Interim behavior: Claude practiced Alternative A for the Sprint 46 fix commits.
- **IMP-4 -- ARCHITECTURE.md component update** (Claude Cat 12): **DO NOW -- DONE** (mandatory per the architecture-docs-never-deferred rule). `RuleQuickActionService` + `no_rule_review_screen.dart` added to the component inventories.
- **IMP-5 -- `-SkipClean` build guard** (Claude Cat 9): **DO NOW -- DONE.** Root cause found deeper during implementation: `-SkipClean` was deterministically broken (the mandatory pre-build `native_assets` deletion -- the PathExistsException workaround -- is never regenerated by an incremental build). `-SkipClean` now warns and falls back to a full clean until the upstream Flutter bug is gone.
