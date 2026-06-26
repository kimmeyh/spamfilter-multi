# Sprint 43 Retrospective

**Date**: 2026-06-25
**Branch**: `feature/20260623_Sprint_43`
**Scope delivered**: F102 (logging-redaction policy + gate), F103 (architecture deep dive), F96 (auth coverage for off-scan quick-add paths, DB v8), F100 (port read-only WinWright flows to integration_test), F101 (DB-lock retry cap 20->15), F104 (security deep dive), F105 (version bump 0.5.3->0.5.4), F110 (phishing auth-failure visibility + narrowed redaction). SEC-11b removed/deferred to Post-MVP (cipher switched to SQLite3MultipleCiphers).
**Tests**: +1684 ~28 green. **Windows build**: green.

This retrospective follows the 4-roles x 14-categories rule. Harold wears Product Owner / Scrum Master / Lead Developer; Claude provides the Claude Code Development Team role.

---

## 1. Effective while as Efficient as Reasonably Possible

- **PO/SM/Lead Dev (Harold)**: (no issue noted in this category)
- **Claude Code Development Team**: Two avoidable efficiency losses this sprint, both self-inflicted and now codified into memory so they do not recur:
  1. The `sqlite3` 2.x downgrade "fix" for the native-asset build-hook failure was both unnecessary (the failure was a polluted build cache from killed runs -- a clean rebuild fixed it) AND harmful (it broke reading the real dev DB with a false "malformed schema code 11"). Cost ~1 hour of investigation + a revert. Memory `feedback_no_sqlite_downgrade` written.
  2. Long-running `flutter test` invocations appeared to hang for many minutes; root cause was piping through `grep|tail` (buffers to 0 bytes until exit) plus a pileup of stray `flutter_tester.exe` from killed runs. Memory `feedback_longrun_process_checks` written; now run to a file + cap concurrency + clean stray procs first. Otherwise the per-task minute-level execution was efficient.

## 2. Testing Approach

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: The F99 integration_test harness paid off this sprint -- F100 ported 6 read-only flows in-VM cleanly, and the F102/F110 redaction gates (PowerShell CLI + Dart mirror) caught real issues and stayed green. No-issue, expectations met.

## 3. Effort Accuracy

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: Minute-level estimates held; the only scope additions (F109, F110, the build-hook detour) came from manual-testing discovery, not estimate misses. No issue.

## 4. Planning Quality

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: The user-specified execution order (F102 first so F104 could verify it; F105 last) sequenced cleanly. The one planning miss is the Model Assignments item below (category 5), not the task plan itself.

## 5. Model Assignments

- **PO/SM/Lead Dev (Harold)**: Noticed NONE of the Sprint 43 items were assigned to Haiku. Asked whether the design process is "design for Haiku first (keep solutions simple / reduce cost); escalate to Sonnet only if heuristics say Haiku is inappropriate; escalate to Opus only if Sonnet is inappropriate" -- and to reconfigure the process to reflect this if it does not already.
- **Claude Code Development Team**: Harold is correct -- Sprint 43 assigned everything to Opus and nothing to Haiku, and the current process does NOT enforce cheapest-first. The existing `plan-sprint` skill + SPRINT_PLANNING.md assess complexity top-down (score the task, then pick a tier), which biases upward. Several Sprint 43 items were genuinely Haiku-appropriate (F101 = a one-constant change; F105 = a mechanical version bump; arguably F100's mechanical port). They ran on Opus because the whole sprint ran on Opus, not because a per-task heuristic demanded it. This is a real process gap -> IMP-1.

## 6. Communication

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: The "echo the requirement back and wait" practice worked well for F110 (a multi-surface, security-sensitive change) -- the clarifying-question round prevented building the wrong thing (I had initially built a green/yellow/red classification column; the conversation corrected it to a failed-checks list + narrowed redaction). No issue.

## 7. Requirements Clarity

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: F110 started ambiguous (two readings of "every email that matches must be in the CSV and log") and the clarifying-questions protocol resolved it before implementation. No issue.

## 8. Documentation

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: ADR-0030 was amended in-process for the F110 redaction narrowing (Class-1), CHANGELOG kept current per commit, the F103/F104 deep-dive docs produced. No deferred doc debt. No issue.

## 9. Process Issues

- **PO/SM/Lead Dev (Harold)** [two comments combined per Harold's request into the single most-sensible Claude Code Team action]: **The sprint PR was marked "Ready for Review" early in the sprint (before the plan was even approved), which triggered an unwanted GitHub Copilot review on every commit thereafter.** The workflow says the draft->ready conversion must not happen until end of Phase 7.7. The fix: add explicit, repeated guards in the sprint-execution docs so that EVERY interaction with the PR keeps it in DRAFT, and it is marked "Ready for Review" ONLY at the single end-of-7.7 step (after post-retrospective improvements are implemented).
- **Claude Code Development Team**: Confirmed and agreed. The workflow doc already *says* "keep it draft until the Phase 7 gate," but it states this as prose at a few steps rather than as a hard, unmissable guard at every PR-touch point -- so the PR slipped to ready early in practice. This warrants an explicit "NEVER mark ready except at 7.7" rule attached to each PR-touch step + the `gh pr create --draft` / no-`gh pr ready`-until-7.7 mechanics. -> IMP-2.

## 10. Risk Management

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: The two Class-1 decisions (SEC-11b deferral/cipher-switch, F110 redaction narrowing) were surfaced and approved at natural breaks rather than unilaterally taken. The dev DB was backed up before the v8 migration. No issue.

## 11. Next Sprint Readiness

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: Backlog has F107 (ADR-0037 status review), F108 (security-relevant dep bumps), F109 (background-deferral UX). develop is clean; next branch should open off develop immediately on merge (Phase 6.6). No issue.

## 12. Architecture Maintenance

- **PO/SM/Lead Dev (Harold)**: Very Good.
- **Claude Code Development Team**: F103 deep dive confirmed docs current; ADR-0030 amended for F110; SEC-11b's Post-MVP re-scope fully captured in the master plan with the sqlite3mc integration caveat. No issue.

## 13. Minor function updates for the NEXT sprint plan

- **PO/SM/Lead Dev (Harold)**: None.
- **Claude Code Development Team**: None.

## 14. Function updates for the FUTURE backlog

- **PO/SM/Lead Dev (Harold)**: None.
- **Claude Code Development Team**: None (F107/F108/F109 already filed during the sprint).

---

## Combined Summary

Sprint 43 delivered 8 items plus two manual-testing-driven additions (F109 filed, F110 implemented), full suite green at +1684 ~28, Windows build green. Quality bar was high: every category rated "Very Good" by the PO/SM/Lead Dev except two with actionable feedback -- **Model Assignments** (nothing ran on Haiku; the process does not enforce cheapest-first design) and **Process Issues** (the PR was marked Ready-for-Review too early, triggering unwanted Copilot reviews). The Claude Code Development Team additionally self-reported two efficiency losses (the sqlite3 downgrade misstep and the test-run-hang diagnosis), both now codified into memory. Two improvement suggestions follow.

---

## Suggestions for Improvement (for review and approval)

### IMP-1 -- Cheapest-first model-assignment process (addresses Category 5)
**Problem**: Sprint 43 ran entirely on Opus; the current process scores complexity top-down and does not bias toward the cheapest capable model, so simple tasks (F101 one-constant change, F105 version bump) ran on Opus.
**Proposed change**: reconfigure the model-assignment process to be **bottom-up / cheapest-first**, exactly as Harold described:
- For each task, FIRST design it to be completed by **Haiku** (this pressure keeps the solution simple and reduces cost). If the design fits Haiku per the heuristics -> assign Haiku.
- ELSE design it for **Sonnet** (again, keep it simple). If it fits Sonnet per heuristics -> assign Sonnet.
- ELSE design it for **Opus** -> assign Opus.
- Record the assigned tier AND a one-line "why not the cheaper tier" note in `SPRINT_N_PLAN.md`, so an all-Opus sprint is a visible, justified choice rather than a default.
**Where**: rewrite the assignment logic in `.claude/skills/plan-sprint/SKILL.md` and the "Model Tiering Strategy" / "Activities Requiring Opus" sections of `docs/SPRINT_PLANNING.md` to describe the Haiku->Sonnet->Opus escalation as the DEFAULT design order. (The "Activities Requiring Opus" list for planning/analysis/retro stays -- that is about the PLANNER model, not the per-task implementer.)
**Effort**: ~30-45 min (docs + skill only).

### IMP-2 -- PR stays DRAFT until the single end-of-7.7 ready step (addresses Category 9)
**Problem**: the sprint PR was marked Ready-for-Review early (before plan approval), triggering a Copilot review on every commit. The workflow intends draft-until-7.7 but does not guard every PR-touch point.
**Proposed change**: add an explicit, unmissable guard to `docs/SPRINT_EXECUTION_WORKFLOW.md` (and the one-page `SPRINT_CHECKLIST.md`):
- A bolded rule at the PR-lifecycle definition: **"The PR is created as a draft (3.3.1) and stays DRAFT through Phases 3-7. It is converted to Ready-for-Review at EXACTLY ONE point: end of Phase 7.7, after all 'apply now' retrospective improvements are implemented + committed. Never run `gh pr ready` (or click 'Ready for review') at any other step."**
- Attach a one-line "**keep DRAFT -- do not mark ready (see 7.7)**" reminder to each PR-touch step (3.3.1 create, 3.7.1 update-to-approved, Phase 6 update, Phase 7 interim).
- Add a note on the Copilot consequence: marking ready early triggers a Copilot review per commit; draft status suppresses that until the work is actually ready.
**Where**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (Phase 3.3.1, 3.7.1, 6, 7.7) + `docs/SPRINT_CHECKLIST.md`.
**Effort**: ~20-30 min (docs only).

---

**Both suggestions are docs/skill-only, no code.**

**Decision (Harold, 2026-06-25): YES on both -- implement now (this sprint, before the PR ready-gate).**

**Implementation status**:
- **IMP-1 DONE**: cheapest-first design ladder added to `docs/SPRINT_PLANNING.md` ("Core Principle: CHEAPEST-FIRST DESIGN") and `.claude/skills/plan-sprint/SKILL.md` ("CHEAPEST-FIRST assignment rule"), with the mandatory per-task "why not the cheaper tier" justification for any Sonnet/Opus assignment. The planner-stays-Opus scope note is preserved.
- **IMP-2 DONE**: draft-until-7.7 guard added to `docs/SPRINT_EXECUTION_WORKFLOW.md` (a [CRITICAL] block at the PR-lifecycle definition + `[keep DRAFT]` markers on every PR-touch step + the Copilot-per-commit consequence note) and mirrored into `docs/SPRINT_CHECKLIST.md`.
