# Sprint 36 Summary

> **NOTE (Sprint 57 doc-audit, 2026-08-14)**: This summary was not found in the repository during a repo-wide sprint-documentation audit and has been reconstructed retroactively from PR #245's body/commits and the existing `SPRINT_36_PLAN.md` / `SPRINT_36_RETROSPECTIVE.md`. Figures not recoverable from those sources are not included rather than invented.

**Branch**: `feature/20260420_Sprint_36`
**PR**: [#245](https://github.com/kimmeyh/spamfilter-multi/pull/245)
**Issues**: #244 (sprint), #242 (F81), #239 (BUG-S35-1), #241 (F80); #246 (BUG-S36-1) opened as Sprint 37 carry-in
**Dates**: 2026-04-20 (kickoff) -> 2026-04-25 (retro, merged 2026-04-25)
**Retrospective**: `docs/sprints/SPRINT_36_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1363 -> **1378** passing / 0 failing (+15 new) |
| Analyzer | Clean |
| Manual Validation | Complete (Harold, Phase 5 -- Windows dev 0.5.3 build) |
| Effort | Estimated ~8-10h; actual ~3h wall-clock |
| Carry-forward | BUG-S36-1 (Issue #246) to Sprint 37 |

## Scope

Approved 2026-04-20 (Phase 3, Issue #244). Three tasks, dependency-ordered.

| Task | Feature | Result |
|---|---|---|
| 1 | F81 (Issue #242) | Store release process documentation shipped |
| 2 | BUG-S35-1 (Issue #239) | Manual rule duplicate prevention shipped, refined mid-sprint |
| 3 | F80 (Issue #241) | Phase Cheat Sheet shipped |

## What shipped

**F81 -- Store release process documentation.** New `docs/STORE_RELEASE_PROCESS.md`
(231 lines), a team-runnable checklist covering pre-release, the 5-file version
bump, `secrets.prod.json` recreation, the supported MSIX build path
(`flutter pub run msix:create` with the mandatory `build_windows_args` field),
MSIX verification, `develop -> main` merge, Microsoft Partner Center upload, and
post-submission steps. Closed three silent-failure gaps surfaced during the
Sprint 35 post-merge prod-worktree rebuild: root `.gitignore` `*.manifest` was
scoped to `Archive/` only (it had been catching the required
`runner.exe.manifest`, now committed); `secrets.prod.json.template` key names
were corrected to `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` /
`WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`; `mobile-app/scripts/build-msix.ps1` got a
deprecation header (the makeappx.exe path ships MSIX with empty OAuth
credentials). CLAUDE.md and ADR-0035 were cross-linked to the new doc.

**BUG-S35-1 -- manual rule duplicate prevention.** New
`core/services/manual_rule_duplicate_checker.dart` runs a normalized
(lowercase, trimmed) match against the `rules` and `safe_senders` tables before
insert, with 15 new unit tests across all 4 block-rule sub-types and all 3
safe-sender sub-types. A Phase 5 manual-testing finding (Harold) showed the
first version fired the duplicate check inside the Save path, after the
misleading Confirm dialog had already been shown -- fixed same-day by moving
the check into `_confirmAndSave`, before `showDialog`, so the SnackBar now
appears instead of the confirm flow. The insert-path check remains as a
second line of defense against a dialog-to-save race.

**F80 -- Phase Cheat Sheet.** A 24-line table (Phase | Top-3 Actions |
Auto-Advance Trigger) plus 4 invariants, prepended to
`docs/SPRINT_EXECUTION_WORKFLOW.md` with anchor links to the full per-phase
sections below.

**Pre-work also on this branch**: a Stop-hook
(`.claude/hooks/sprint-auto-advance.ps1`, plus `.claude/settings.json`)
enforcing the CLAUDE.md Phase Auto-Advance Rule was added at kickoff after the
executing model violated that rule in the same session that documented it; and
Phase 1 Backlog Refinement was changed from optional/on-request to mandatory
every sprint (`docs/SPRINT_EXECUTION_WORKFLOW.md`, `docs/SPRINT_CHECKLIST.md`).

## Found during Manual Validation

- Pre-dialog duplicate-check UX gap (see BUG-S35-1 above) -- fixed same sprint.
- **BUG-S36-1** (Issue #246, Sprint 37 carry-in): the duplicate checker catches
  exact duplicates only. It does not detect semantic subsumption -- e.g.
  creating an `exact_domain` safe sender when an `entire_domain` safe sender
  for the same base domain already covers it. Logged with a coverage matrix
  (exact_email/exact_domain covered by entire_domain; entire_domain not
  covered by the narrower types) for Sprint 37.

## Retrospective improvements (all applied)

| ID | Improvement |
|---|---|
| IMP-1 | New Phase 3.2.2.1 plan-to-branch-state verification gate (`SPRINT_EXECUTION_WORKFLOW.md`) |
| IMP-2 | Widget-test mandate for UX flow changes (`TESTING_STRATEGY.md`) |
| IMP-3 | `/startup-check` Phase 3.7 approval-verification gate |
| IMP-4 | CLAUDE.md Opus 4.7 pitfall entry 7 + memory `feedback_follow_the_docs.md` |
| IMP-5 | Memory `feedback_background_task_stdout.md` (verify output file is being written before arming Monitor) |

## Lessons worth carrying

1. **Session-resume approval checks need independent verification, not
   presumption.** The executing model read `SPRINT_36_PLAN.md` and presumed
   Phase 3.7 approval rather than confirming it; closed by IMP-3.
2. **A sprint plan can go stale between being written and being executed on
   the same branch.** Task 1.3 was already shipped in the kickoff commit but
   still listed pending in the plan; the plan also cited the wrong
   `.gitignore` file path. Closed by IMP-1.
3. **Trace the full caller chain before editing a save path.** The first
   BUG-S35-1 fix edited `_saveBlockRule`/`_saveSafeSender` without tracing
   through `_confirmAndSave`, so the duplicate check fired after the
   misleading confirm dialog rather than before it. Caught by Harold in
   Phase 5, not by review.
