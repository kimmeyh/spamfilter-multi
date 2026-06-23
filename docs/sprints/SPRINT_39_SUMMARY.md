# Sprint 39 Summary

**Sprint**: 39
**Dates**: 2026-05-25 (single-session execution; warmup PR #259 merged 2026-05-24)
**PR**: #260 (`feature/20260523_Sprint_39` -> `develop`, DRAFT -- Chief Developer merges after retro + follow-ups)
**Status**: Complete (pending Chief Developer merge)

## What Shipped

12 planned tasks, all complete, full suite green. Executed in 3 parallel waves (independent tasks run as concurrent sub-agents; F91->F89 serialized on the shared DB v6 migration).

### Features and Fixes

- **F91** -- AOL "copy-not-move" source-folder dedup. RFC 5322 Message-ID capture (`EmailMessage.messageIdHeader`, DB v6 `email_actions.rfc5322_message_id`); after a safe-sender UID MOVE, `searchByMessageId` finds AOL's re-injected copy in the source folder and moves it to Trash. Skips Gmail OAuth / null Message-ID / source==target. New `_safeSenderDedupCount`.
- **F89** -- SPF/DKIM/DMARC auth-failure warnings on quick-add. New `AuthResultsParser` -> `EmailAuthResult` (GREEN/YELLOW/RED/GREY); `email_auth_badge` + `auth_warning_dialog`; RED state gates safe-sender quick-add with an informed-consent dialog. `created_with_auth_state` snapshot (DB v6) on rules + safe_senders.
- **F74** -- Help FAQ section (8 Q&A authored as ADR-0038 Markdown assets; cross-referenced from rule creation).
- **S38-CI-3** -- Shift+Click range-extend + Ctrl/Cmd+Click disjoint selection on Manage Rules / Safe Senders (`ListSelectionController` mixin). Sub-task A had shipped Sprint 38.
- **S38-CI-1** -- Windows X-close fix (3 rounds). Root cause: `setPreventClose(true)` swallowed WM_CLOSE + window_manager 0.3.9 `destroy()` is `PostQuitMessage`-only, tearing down the engine during process-exit unwind with an orphaned tray icon. Fix: remove the interception; let the native WM_CLOSE->WM_DESTROY->SetQuitOnClose path run. Manually verified.
- **S38-CI-2** -- Default-folders info card relocated below the Default Folders header on Manual Scan; added to Background tab.
- **S38-CI-4** -- IMAP no-rule cursor capped at the daysBack window (`firstUidSince` UID-for-date lookup, cached per folder per scan; clamp in `_updateOldestNoRuleCursors`).
- **S38-CI-6** -- Regression-guard widget test for cross-screen no-rule reload (the Sprint 38 Rounds 7/8/9 churn).
- **F92** -- LiveScanLogger unit tests (10).
- **BUG-S37-2** -- Removed 6 malformed bundled TLD rules (`.c .giw .nwm .xd .sweepss .qzz.io`) from rules.yaml + v6 cleanup migration for existing installs; ccTLD gap-fill adding every ISO 3166-1 ccTLD except `.us`/`.uk`/`.ca`. No UI (existing Manage Rules covers edits).
- **F93** -- Auto-advance Stop-hook exempts Phase 1 (Backlog Refinement: no SPRINT_N_PLAN.md = allow). **F77** -- decision documented to route the proceed-pattern block through the existing hook rather than a redundant hookify rule.

### Tests

- 1530 passing / 28 skipped / 0 failed (+~70 from sprint scope).
- `flutter analyze`: 0 issues.
- Phase 5.3 manual testing verified by Harold: X-close, F91 AOL dedup, F89 auth warnings.

### Effort

- Estimate (plan): ~30-45h across 12 tasks (hour-based).
- Actual: ~2h Phase-4 wall-clock (estimates ran 4-14x high -- the central Effort-Accuracy finding). See `docs/CODING_VELOCITY.md` for 12 recorded task actuals.

## Key Process Changes (Phase 7 Outputs)

- **`docs/CODING_VELOCITY.md`** (new) + **SPRINT_EXECUTION_WORKFLOW.md Phase 3.2.2.3** -- estimate in MINUTES from step-type velocity history; record actuals each task; recompute medians each retro (S39-IMP-1).
- **SPRINT_EXECUTION_WORKFLOW.md Phase 5.2.3** -- Architecture Documentation Gate: architecture-change docs are NEVER deferred; updated before manual testing; only exception is Chief-Architect Q&A surfaced during Manual Testing (S39-IMP-2 + amendment; memory `feedback_architecture_docs_no_defer.md`).
- **SPRINT_EXECUTION_WORKFLOW.md Invariant** -- phase-boundary checklist gate: run the Phase Cheat Sheet line and state which steps were done before declaring a phase complete (S39-IMP-3).
- **`docs/ARCHITECTURE.md`** -- updated for DB v4/v5/v6 history, `EmailMessage.messageIdHeader`, AuthResultsParser + LiveScanLogger services, `searchByMessageId`/`firstUidSince` adapter methods, the new UI widgets, and the BUG-S37-2 ccTLD gap-fill (S39-IMP-4).
- **Memory additions**: estimating-in-minutes, fix-failures-as-found, 12-month code lens, PR lifecycle (draft at 3.7; Claude never merges), diagnose-native-bugs-before-patching, architecture-docs-no-defer.

## Scope Adjustments

- **S38-CI-7** (Opus 4.6 vs 4.7 evaluation) moved to Sprint 40 and re-scoped: 4+ tasks run on BOTH models on separate branches, scored on process-doc adherence / instruction-following / architecture discipline / stopping-criteria / forward-looking code quality.
- **Backlog refinement** (pre-plan): removed 12 stale/shipped items; moved 9 off HOLD; moved 6 to the Android/GP HOLD group; renumbered F52 Phase 2/3+ -> F94/F95.

## Carry-Ins to Sprint 40

F75, F25, F35, F37, F78, F79, S38-CI-7. (Sprint 41 target: SEC-11b, F83.)
