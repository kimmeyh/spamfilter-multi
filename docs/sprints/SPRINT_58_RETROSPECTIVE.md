# Sprint 58 Retrospective

**Date**: 2026-08-15
**Sprint scope**: F151 (Windows first-run/onboarding UX, 9 tasks total: F151a-g planned + F151h/F151i from Manual Validation feedback) -- see `SPRINT_58_PLAN.md`.
**Verification at close**: full suite 1,891 passed / 29 skipped / 0 failed; `flutter analyze` clean; Manual Validation complete (Harold, 2026-08-15, two rounds).

Harold's combined Product Owner / Scrum Master / Lead Developer feedback recorded verbatim
2026-08-15; Claude Code Development Team feedback drafted in parallel
(`drafts/SPRINT_58_RETROSPECTIVE_claude_draft.md`) per the Phase 7 7-Step Protocol.

## Sprint 58 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Good. Asked for recommendations to avoid the recurring `Select-Object: command not found` (exit 127) errors and the `TaskCreate` parameter error, and for an explanation of the repeated Dart "Target of URI doesn't exist / everything undefined" diagnostic walls (never seen before this sprint; possibly introduced by recent Sonnet or Claude Code v2.1.229 changes) -- they looked like a time waste and showed up multiple times during the development phase.
- **Scrum Master**: Good -- same three items as Product Owner.
- **Lead Developer**: Good -- same three items as Product Owner.
- **Claude Code Development Team**: Good, with root causes for all three flagged items. (1) The exit-127 errors were my own shell-context mixing: Bash-tool commands piping `powershell -Command` output into `Select-Object`, a PowerShell cmdlet the bash pipe cannot resolve -- at least 3 occurrences, each wasting a call plus retry. (2) The TaskCreate error was one unfamiliar-tool schema miss (passed a batch array to a one-per-call tool). (3) The Dart diagnostic walls are NOT errors I produced -- they are the Claude Code client's new language-server integration reporting after each edit; the whole-file "everything undefined" cascade signature means the analyzer lost package resolution (`flutter clean` deletes `.dart_tool/package_config.json`), not that code was wrong. I treated `flutter analyze` as authoritative throughout and took zero wrong actions from the noise, and the same integration produced genuinely useful signal (caught real call-site errors during F151c before any test ran) -- so the fix is noise-recognition, not disabling. All three addressed by retro improvements IMP-1/IMP-2 below.

### 2. Testing Approach

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. Every code change mutation-verified (13+ deliberate mutations, each caught by exactly its own test). F151i validated the highest-risk prediction (Markdown heights stressing the F145 deep-link scroll) with the full 31-test integration suite rather than assumption -- passed unchanged. Two durable test-design lessons recorded: `find.text()` cannot prove visibility on an eager-Column screen, and single-Text-widget content assertions break under Markdown rendering -- both corrected toward shape-independent assertions.

### 3. Effort Accuracy

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. All estimated tasks landed inside or below their minute bands; the one overrun (F151d, ~35m vs 10-15m) was a genuine surfaced-and-approved scope change, not estimation drift.

### 4. Planning Quality

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good, with an honest observation: three of seven planned tasks (F151d/e/f) had their written premise corrected by reading the actual code during execution -- in all three cases the corrected implementation was smaller and better-targeted, and the plan doc records the correction with reasoning. Lesson: for UI-fix tasks planned from walkthrough observations, a 2-minute read of the target widget during planning would write the right premise the first time.

### 5. Model Assignments

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. Cheapest-first held with recorded "why not cheaper" per Sonnet pick; the three premise corrections landed on exactly the tasks assigned Sonnet for live re-diagnosis capacity.

### 6. Communication

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. Scope changes surfaced before acting (F151d); mid-turn steering incorporated without re-litigating; the auto-mode question answered from verified settings contents, not recollection.

### 7. Requirements Clarity

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. All 8 MV items enumerated and tracked to completion; the one truncated item flagged and confirmed before implementation; the icon-order spec applied as an audit against a stated canonical order.

### 8. Documentation

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. Per-task completion notes including premise corrections; velocity actuals logged at completion; CHANGELOG in the same commits as code; the WinWright screen-reader-flag discovery propagated to F153 and the stale F139 reference corrected rather than left asserting a possibly-wrong limitation.

### 9. Process Issues

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. Both hook catches this sprint (require-sprint-cards on the unpopulated `github_issues` array; verify-closeout earlier) were legitimate and fixed properly rather than bypassed. The MV round followed Harold's "full planning + card for substantial items" steering with real cards (#319/#320) before execution.

### 10. Risk Management

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. The riskiest operation (clearing three data-persistence layers for true first-run testing) was backup-verified byte-for-byte before and after, restoration confirmed against live account data, zero loss. F151d's pipeline fix was constrained to Demo Mode with a 52-test regression proof before commit.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. F150 queued (blocked only on Harold's Firebase Console action); F153 at Priority 10 with a cheap concrete first step; F152 template ready for future first-run evaluations.

### 12. Architecture Maintenance

- **Product Owner**: Very Good.
- **Scrum Master**: Very Good.
- **Lead Developer**: Very Good.
- **Claude Code Development Team**: Very Good. One deliberate new dependency (flutter_markdown_plus, discontinued-upstream rationale documented in pubspec); the F134 single-builder architecture proved its value twice (one-line reorder fixed every screen). No ADR-level changes.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: None.
- **Scrum Master**: None.
- **Lead Developer**: None.
- **Claude Code Development Team**: None.

### 14. Function Updates for the Future Backlog

- **Product Owner**: None.
- **Scrum Master**: None.
- **Lead Developer**: None.
- **Claude Code Development Team**: None beyond what was registered in-sprint (F152, F153).

## Improvements

Both proposed improvements were approved by Harold ("apply both now", 2026-08-15) and applied:

- **IMP-1 (APPLIED)**: Memory note `feedback_shell_homogeneous_pipelines.md` -- never pipe
  Bash-tool output into PowerShell cmdlets (keep pipelines shell-homogeneous: whole pipeline
  inside the `powershell -Command` string, bash-native `head`/`tail`, or the PowerShell tool);
  check an unfamiliar tool's schema before first call. Addresses Category 1 items 1 and 2.
- **IMP-2 (APPLIED)**: Memory note `feedback_dart_lsp_noise_signature.md` -- a whole-file
  "everything undefined / material.dart doesn't exist" Dart diagnostics cascade after an edit is
  stale package-resolution noise from the Claude Code client's LSP integration (post-`flutter
  clean`); `flutter analyze` is authoritative; targeted single-file diagnostics from the same
  source ARE real signal and should be acted on. Addresses Category 1 item 3.

## Questions Discussed

None (Harold: none).
