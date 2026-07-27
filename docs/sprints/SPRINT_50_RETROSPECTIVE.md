# Sprint 50 Retrospective

**Sprint**: 50
**Dates**: 2026-07-25 -- 2026-07-26
**Branch**: `feature/20260723_Sprint_50`
**PR**: [#278](https://github.com/kimmeyh/spamfilter-multi/pull/278) (draft -> develop)
**Issues**: #279 (F126), #280 (F122), #281 (F123), #282 (F124), #283 (F127-residual)
**Model**: Fable 5 (execution); Opus 5 (1M) from Phase 7 onward
**Retrospective date**: 2026-07-26

---

## Sprint Summary

Five planned tasks (F126, F122, F123, F124, F127-rescoped) plus five mid-sprint
items from manual validation (MT-1, MT-2, MT-2b, MT-2c, MT-3) and one backlog
item filed (F128). Two live-database repairs executed against the production
rules DB (F126: 4 legacy TLD rows removed, 5,887 -> 5,883; F123: 350 mislabeled
`pattern_type` rows repaired, plus 341 in dev), each rehearsed on a copy first
with timestamped backups retained. Harold validated every item: "All working as
expected and can be closed."

**Actual effort**: ~223m across ten items (estimated ~135-235m).
**Verification**: full suite green; `flutter analyze` clean; CI green on both jobs
(one cross-platform test escape found at the Phase 6.1.1 gate and fixed in `3405a40`).

---

## Sprint 50 Retrospective Feedback

_Harold's feedback is recorded verbatim as provided (combined Product Owner /
Scrum Master / Lead Developer, per his standing format). Claude Code Development
Team feedback is the 4th role._

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Ten items delivered against five planned, ~223m actual against ~135-235m estimated. The Sprint 49 anti-stop rule (IMP-1) worked as intended -- all five planned tasks ran end-to-end with no mid-sprint stop; the only turn-ends were criterion-2 blocks on Harold-exclusive manual validation. Two genuine efficiency losses: (a) the MT-2 fix shipped three times (MT-2 -> MT-2b -> MT-2c) because I fixed the narrow symptom before implementing the full requirement -- Harold's original sentence already contained "re-checking the list for other items still in the list that are now covered by rules", which IS the MT-2c behavior; (b) ~15m lost to auto-mode classifier denials on the F123 live apply, requiring a Harold-side settings change.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Strong on data mutation -- both live-DB tasks were rehearsed against a scratchpad copy before touching live data, and both live runs matched their rehearsals exactly. Every mid-sprint UI item got a pinning test rather than manual-only verification: the MT-1 test asserts actual column x-alignment geometry, and the MT-2b test seeds a second scan behind the mounted screen to reproduce Harold's race. One real gap: the MT-3 assertion assumed a Windows host while the button is `Platform.isWindows`-scoped, so it passed locally and failed the ubuntu CI job. The Phase 6.1.1 gate caught it pre-retrospective, but F-PRECHECK class-1 should have caught it at 5.1.2 -- "local Windows vs CI Linux" was not on my parallel-site list.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Best accuracy to date -- all ten items landed within or near band (F126 ~20m of 15-25; F122 ~10m of 10-20; F123 ~35m effort/~50m wall of 25-40; F124 ~20m of 15-25; F127-residual ~5m of 5-10; MT-1 ~30m of 25-40; MT-2 ~35m of 30-45; MT-2b ~25m of 20-35; MT-2c ~35m of 25-40; MT-3 ~8m of 5-10). The Sprint 49 guidance to prefer the low end of band for S-size items held. F123 is the only item where wall-clock exceeded effort (~50 vs ~35), entirely from the classifier-denial detour -- external friction, not an estimation error.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The augmented card template kept paying off: F123's card carried an explicit conditional Class-2 interrupt (R-3), so when the root cause turned out to be data rather than display precedence, the pre-agreed decision rule applied without interrupting Harold. Phase 3.2.2.1 verification caught that the F127 fix had already shipped, correctly re-scoping Task 5 from ~30m to a ~5m verification. The plan did not anticipate mid-sprint manual-validation scope (five MT items, roughly as much work as the planned scope) -- normal for this project, but the plan had no "manual-validation scope" section until I added one at close-out.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Honest gap worth recording despite the Very Good: all five tasks were ASSIGNED Haiku (x3) / Sonnet (x2) under cheapest-first, and all ten items were EXECUTED by the session model (Fable 5). The `Executed-by` field (Sprint 49 IMP-3) made this visible for the first time -- the improvement working as designed. Two assignments were arguably wrong in hindsight: F123 was assigned Sonnet as a display-logic fix and became a 350-row live data repair (genuinely top-tier work), while F122 and MT-3 were true Haiku-class mirror edits. Recommend either genuinely delegating mechanical tasks or recording an explicit "executed in-session because X" per task.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold's screenshots were the highest-signal input of the sprint -- the two Review-No-Rule screenshots (6 items, then 1 item) settled in seconds what log analysis had not. The AskUserQuestion previews for MT-1 (ASCII grid mockups) and MT-2 (scenario walkthroughs) produced clean single-word decisions with zero follow-up clarification, suggesting concrete options beat prose descriptions. One miss on my side: after the MT-2 fix I reported the scenario fixed when it was only fixed for the bulk-action path -- Harold's next screenshot showed the on-open case. I should have stated the boundary of what the fix covered.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold's manual-validation reports were precise, with reproduction steps and expected end state. The MT-2 requirement in particular was complete in his first message -- the gap was my reading of it, not his writing of it (see Category 1). The one genuinely ambiguous item was MT-1 ("do you have a suggestion so that Block Entire Domain is always in the same place"), an open design question where presenting three concrete layouts with previews was the right resolution path.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: CHANGELOG, CODING_VELOCITY (all ten rows with both metrics), the plan document, and the master plan were updated in-commit rather than batched at sprint end. F128 was filed in the same commit that shipped its workaround, so the backlog entry cannot drift from the code. Carry-forward gap found during this retro: Harold's Sprint 49 request to rename "manual testing" -> "manual validation" (475 occurrences repo-wide; 81 in active scope) was never converted into a numbered Sprint 49 improvement proposal and so was never applied -- a Step-5 protocol leak. Harold approved folding it into Sprint 50 (2026-07-26).

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Three worth recording. (a) Edit-verification discipline (Sprint 49 IMP-2) was only partially followed -- no string-not-found failures, but one 2-match ambiguity error on a duplicated block in `no_rule_review_screen.dart`, where the rule says grep the exact region first. (b) Auto-mode classifier denials blocked the F123 live apply twice AND blocked me from editing settings to fix it, requiring Harold's intervention; captured in memory `feedback_automode_permissions`. (c) Retro Step-5 leakage -- the Sprint 49 rename shows Harold-flagged items inside category feedback can be lost if not mechanically converted into numbered proposals.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The riskiest work (two live mutations against Harold's real production data) went cleanly: dry-run default, abort-unless-exact-count gate, rehearsal on a copy, timestamped backups retained (verified present on disk at the Phase 6.1.1 gate), post-apply verification that a re-run finds nothing, and app-closed window coordination each time. Residual risk accepted knowingly: the MT-2c full-set sweep runs on every load of the Review screen, so a very large rule set adds load latency -- mitigated with F120-style time-based yields but not benchmarked against the 5,883-rule prod DB.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Sprint 51 has a clear candidate set: F128 (provider silent no-op, Priority 18), the WinWright coverage carry-in for the three sprint-touched screens, plus the standing backlog (F-COPILOT-INSTR, F125, F94/Android track). Branch clean, CI green, PR #278 draft and current. The Android/Google Play track remains the next major track per the 0.5.7 promotion trigger.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No architecture change this sprint, and that is a deliberate finding rather than an omission: F123's conditional Class-2 (stored-`patternType`-precedence change) did NOT trigger, because the root cause was mislabeled data written by older classifier versions, not the Sprint 37 precedence decision. ADR-0041 and existing ARCHITECTURE/ARSD content remain accurate. F128 is a defect against an existing pattern, not a new architectural decision. Nothing requires Chief Architect approval.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: Candidates offered for Harold's decision (he recorded "none"): (a) F128 provider silent-no-op fix including sibling early-returns; (b) add "local Windows vs CI Linux" as an explicit parallel-site pair in the F-PRECHECK class-1 checklist; (c) benchmark the MT-2c sweep against the prod-size rule set.

### 14. Function Updates for the Future Backlog

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: Candidates offered for Harold's decision (he recorded "none"): (a) WinWright coverage for the quick-action grid, Manage Rules display, and Review-No-Rule screen (5.1.5 exit-criteria carry-in); (b) a delegation policy that makes cheapest-first assignment real. F128 is already filed in the master plan at Priority 18 regardless.

### Questions to be discussed before ending the sprint

- **Harold**: none

---

## Improvement Decisions (Phase 7.6)

Harold's decisions, 2026-07-26. Blanket disposition: apply IMP-1 through IMP-4 now;
IMP-7 resolved by his steering ("recorded justification when not completed by the
planned model") and applied now; IMP-5 and IMP-6 to backlog.

- **IMP-1 "manual testing" -> "manual validation" rename -- APPLIED**. Case-preserving sweep of 81 occurrences across 32 files: active process docs (`SPRINT_EXECUTION_WORKFLOW`, `SPRINT_PLANNING`, `SPRINT_CHECKLIST`, `SPRINT_RETROSPECTIVE`, `SPRINT_STOPPING_CRITERIA`, `SPRINT_RESUME_GUIDE`, `TESTING_STRATEGY`, `QUALITY_STANDARDS`, `PRESENTATION_FRAMEWORK`, `MANUAL_INTEGRATION_TESTS`, `CODING_VELOCITY`, `ALL_SPRINTS_MASTER_PLAN`), root docs (`CLAUDE.md`, `AGENTS.md`, `CLAUDE_CODE_SETUP_GUIDE.md`), the sprint-card issue template, Sprint 50's own documents, and code/test/script comments.
  - **Deliberately EXCLUDED from scope** (475 total occurrences exist repo-wide): `archive/` and `Archive/`, `.claude/worktrees/`, `.claude/plans/`, `docs/archive/`, historical `docs/sprints/SPRINT_<=49_*` records, and CHANGELOG published-release history. Rationale: those are historical records of what was said at the time -- rewriting them would falsify the record, and the term appears there as part of completed narratives.
  - One self-referential garble introduced by the sweep (a retro line describing the rename became "manual validation -> manual validation") was caught in verification and repaired.
- **IMP-2 Retro Step-5 completeness gate -- APPLIED**. `SPRINT_EXECUTION_WORKFLOW.md` Step 5 now requires walking Harold's feedback category-by-category and stating, per category, either the numbered proposal(s) it produced or `no actionable item` explicitly; documents the Sprint 49 rename as the concrete failure it closes.
- **IMP-3 Platform-gated widgets as a parallel-site pair -- APPLIED**. F-PRECHECK class-1 (workflow 5.1.2) now names "local Windows host + CI Linux host" as a twin pair, with the detection action: grep the widget's build site for `Platform.is` and make the expectation platform-aware.
- **IMP-4 Fix-boundary statement rule -- APPLIED**. Memory `feedback_state_fix_boundary`: when reporting a fix, state which paths it covers AND which it does not; cites the MT-2 -> MT-2b -> MT-2c triple as the cost of omitting it.
- **IMP-7 Recorded justification when not executed by the planned model -- APPLIED** (Harold's steering). `SPRINT_PLANNING.md` task template + `SPRINT_EXECUTION_WORKFLOW.md` 4.1: whenever `Executed-by` differs from the assigned `Model:`, the line MUST carry a concrete reason in one of four shapes (in-session/coupled-context, in-session/round-trip-exceeds-task, escalated/scope-grew, delegated). Retro Category 5 reads these lines; an all-"in-session" sprint with no distinguishing reasons is itself a signal to surface.
- **IMP-5 F128 provider silent-no-op fix -- BACKLOG**. Already registered in `ALL_SPRINTS_MASTER_PLAN.md` at Priority 18.
- **IMP-6 WinWright coverage for the three sprint-touched screens -- BACKLOG**. Phase 5.1.5 exit-criteria carry-in for Sprint 51.

---

## Sprint 49 Improvement Verification (carry-in audit)

Verified against repo state at Sprint 50 Phase 7, not from memory:

- **IMP-1 anti-stop task-inventory rule** -- APPLIED and EFFECTIVE. `SPRINT_EXECUTION_WORKFLOW.md` Phase 4.1.0 present; no mid-sprint stop occurred in Sprint 50.
- **IMP-2 Edit exact-bytes discipline** -- APPLIED, PARTIALLY EFFECTIVE. Memory file present; zero string-not-found failures, but one 2-match ambiguity error occurred (grep-the-region step skipped).
- **IMP-3 Executed-by field** -- APPLIED and EFFECTIVE. Present in `SPRINT_PLANNING.md` + workflow; used in the Sprint 50 plan and surfaced the assignment-vs-execution gap (Category 5).
- **IMP-4 ADR-0041** -- APPLIED. `docs/adr/0041-environment-propagation-single-source.md` present.
- **IMP-5 `--concurrency=4` policy** -- APPLIED and EFFECTIVE. In `TESTING_STRATEGY.md`; the four Sprint 50 full-suite load-failures were correctly diagnosed as concurrency flakes (all four files pass in isolation).
- **IMP-6 Phase 6.6 carry-forward** -- APPLIED. Workflow 6.6 rewritten to branch-from-current-feature-branch.
- **"manual testing" -> "manual validation" rename (Harold, Sprint 49 Category 8)** -- NOT APPLIED IN SPRINT 49. Never converted into a numbered improvement proposal, so it was never applied. Harold approved folding it into Sprint 50 (2026-07-26).
