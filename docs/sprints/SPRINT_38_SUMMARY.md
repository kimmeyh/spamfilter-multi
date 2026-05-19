# Sprint 38 Summary

**Sprint**: 38
**Dates**: 2026-05-05 -- 2026-05-18
**PR**: #258 (`feature/20260505_Sprint_38` -> `develop`)
**Status**: Complete

## What Shipped

Eight planned tasks + one mid-sprint addition + 10 rounds of post-Phase-5.3 manual-testing fixes + 10 Phase 7 retrospective improvements applied.

### Features and Fixes

- **F87 (Issue #256)** -- Settings icon: leading-icon clickable, Settings reorg.
- **BUG-S37-1 (Issue #251)** -- Background scan SQLite "database is locked": main.cpp read-only mutex probe + PowerShell integration test (Task 2b, added mid-sprint).
- **F6c Phase 2 + Issue #250 extension** -- Incremental scans:
  - Gmail OAuth: historyId path wired through `EmailScanProvider`.
  - IMAP-backed (aol, yahoo, gmail-imap, custom): new `account_folder_cursors` DB v5 table; `GenericIMAPAdapter.fetchMessagesIncremental(startUid, folderName)` via `UID SEARCH UID cursor:*`.
  - Cursor semantics: **oldest unaddressed no-rule UID** per (account, folder). Next scan re-fetches from cursor forward, keeping no-rule backlog visible until addressed. Advances as rules are added; cleared per-folder when zero unaddressed remain (falls back to daysBack).
- **F88 (Issue #255)** -- Gmail batchGet: batched `users.messages.batchGet` for Gmail OAuth path. IMAP equivalent deferred (carry-in S38-CI-5).
- **F86 (Issue #254)** -- Live rule reload: post-scan-complete + post-rule-add reload (not mid-scan rebuild).
- **F84 Sub-task A (Issue #253)** -- Ctrl+A select-all on virtualized lists. Sub-B/C deferred (S38-CI-3).
- **F82 (Issue #252)** -- Scan Results "No rule" progress indicator + cross-screen rule-add reload: footer "M of N No rule emails addressed -- K remaining", chip count updates, matched rows hide on inline AND cross-screen rule-add.
- **F85 (Issue #257)** -- Content-management ADR: ADR-0038, asset manifest, 20 help/*.md files, loader for >500-char user-facing strings.

### Tests

- 1455 passing / 28 skipped / 0 failed (+18 from sprint scope).
- `flutter analyze`: 0 issues.

### Effort

- Estimate: 17-27h across 8 tasks.
- Actual: ~24h (Phase 4 ~7h + Phase 5.3 manual-testing fixes ~14h across 10 rounds + Phase 7 retro ~3h).

## Key Process Changes (Phase 7 Outputs)

- **SPRINT_STOPPING_CRITERIA.md** Criterion 9 -- wall-clock hours are not a stop signal unless total sprint estimate exceeds 400 wall-clock hours and the threshold has been met.
- **SPRINT_EXECUTION_WORKFLOW.md** -- new "Decision-Class Checkpoint Protocol" section (Class 1 Architecture / Class 2 Development / Class 3 Sprint Execution). Sprint-plan approval at Phase 3.7 is NOT durable for these classes; explicit Chief Architect / Chief Developer / Scrum Master signoff required at natural breaks (Backlog Refinement → Sprint Plan approval, Manual Testing, Retrospective).
- **SPRINT_EXECUTION_WORKFLOW.md** -- new Phase 5.1.5 "WinWright UI Test Sweep" (mandatory) before Phase 5.2 test-suite run.
- **SPRINT_EXECUTION_WORKFLOW.md** + **SPRINT_CHECKLIST.md** -- canonical "Next Steps" progression: Manual integration testing -> Loop on testing feedback -> Code review -> Sprint retrospective -> Merge -> Begin next sprint. Do NOT present Code Review before Manual Testing is loop-complete.
- **CLAUDE.md** -- new "Decision-Class Taxonomy: STOP, Surface, Wait" subsection under "Things Claude Should NOT Do".
- **New skill** `/sprint-compact` -- generates a compact resume-string for `/compact` use. Replaces `/memory-save` for sprint resume. Companion to new `docs/SPRINT_RESUME_GUIDE.md`.
- **New memory entries** -- `feedback_decision_class_taxonomy.md`, `feedback_stopping_400hr.md`, `feedback_echo_requirements.md`.

## Sprint 39 Carry-Ins

Loaded into ALL_SPRINTS_MASTER_PLAN.md "Sprint 39 Carry-Ins" subsection:

- **S38-CI-1** -- Window X-close button fix (Windows desktop bug)
- **S38-CI-2** -- Settings > Manual Scan + Background: relocate "Default folders are account-specific" info card
- **S38-CI-3** -- F84 Sub-tasks B + C: Shift+Click extend selection, Ctrl+Click-drag disjoint selection
- **S38-CI-4** -- IMAP cursor cap at daysBack-ago-UID (refinement of Sprint 38 F6c IMAP extension)
- **S38-CI-5** -- F88 IMAP batch equivalent (HOLD pending feasibility research)
- **S38-CI-6** -- Widget test for `_loadLastCompletedScan` cross-screen reload (testing debt)
- **S38-CI-7** -- Opus 4.6 vs 4.7 side-by-side prompt evaluation (procedural)

## Retrospective

Full retrospective: [SPRINT_38_RETROSPECTIVE.md](SPRINT_38_RETROSPECTIVE.md).

10 IMPs proposed; all 10 approved for "Now" application by Harold. Applied during Phase 7 close-out before Sprint 39 starts.
