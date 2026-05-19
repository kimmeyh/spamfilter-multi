# Sprint Resume Guide

**Purpose**: Give Claude Code everything it needs to resume a sprint mid-stream after `/compact`, after a fresh session start, or after context loss -- WITHOUT requiring the compact-string itself to carry all the context.

**Audience**: Claude Code re-loading state after `/compact` or new session.

**Source**: Sprint 38 retrospective IMP-1 (2026-05-18). The companion `/sprint-compact` skill produces a short `<compact-string>` that points here for bulky context.

---

## How To Use This Guide

1. The `/sprint-compact` skill produces a `<compact-string>` of ~1-2K chars containing only volatile state: sprint name, current phase, last 2 checklist steps completed, next 2 steps, HEAD commit, branch.
2. After `/compact`, the next session sees the compact-string in the new context.
3. The compact-string ends with: `Resume context: read docs/SPRINT_RESUME_GUIDE.md.`
4. This guide carries the durable, non-volatile context that does NOT change session-to-session.

If you (Claude) are reading this file because a compact-string told you to: confirm sprint identity from the compact-string, then proceed with the workflow gates below.

---

## What This Guide Carries (Durable -- Does Not Change Per Session)

### 1. This is a sprint, not vibe coding

Sprint-based work has explicit phases (1-7), a single PR per sprint, mandatory retrospective, and Phase 3.7 durable approval. Vibe-coding patterns (skipping phases, ad-hoc feature additions, "I'll just fix this real quick") are explicitly out-of-bounds. See `CLAUDE.md` § "Sprint Planning and Development Workflow".

### 2. The 7 Phases (one-line each)

| Phase | What | Done When |
|-------|------|-----------|
| 1 | Backlog Refinement (MANDATORY) | User picks items for the sprint |
| 2 | Sprint Pre-Kickoff | All prerequisite gates green |
| 3 | Sprint Kickoff & Planning | User approves plan (Phase 3.7) -- durable through Phase 7 |
| 4 | Sprint Execution (Development) | All acceptance criteria met; test suite green |
| 5 | Code Review & Testing | Manual test golden-path + edge cases verified; no regressions |
| 6 | Push to Remote & Create PR | PR ready for review |
| 7 | Sprint Review & Retrospective | 4 roles × 14 categories addressed; improvements applied |

Detail: `docs/SPRINT_EXECUTION_WORKFLOW.md`. Quick: `docs/SPRINT_CHECKLIST.md`. Stop signals: `docs/SPRINT_STOPPING_CRITERIA.md`.

### 3. Decision-Class Checkpoint (Sprint 38 retro)

Three classes of decisions need explicit user approval AT natural breaks (Backlog Refinement, Manual Testing, Retrospective):

- **Architecture** (Chief Architect): data-model changes, control-flow inversions, persistence semantic shifts, ADR pattern changes.
- **Development** (Chief Developer): function signature changes, removed abstractions, runtime field-meaning shifts.
- **Sprint Execution** (Scrum Master): shortening/de-scoping/deferring approved tasks -- unless SPRINT_STOPPING_CRITERIA 1-9 is met AND SM approves.

Surface phrasing: "This would change a prior [architecture/development/sprint scope] decision: ... Should I proceed?"

Full: CLAUDE.md "Decision-Class Taxonomy" + SPRINT_EXECUTION_WORKFLOW.md "Decision-Class Checkpoint Protocol".

### 4. Stopping Criteria

Only these reasons are valid (full doc: `docs/SPRINT_STOPPING_CRITERIA.md`):

1. All tasks complete
2. Blocked on external dependency
3. User requests scope change
4. Critical bug found
5. User requests early review
6. Sprint review complete
7. Fundamental design failure
8. Context limit approaching (rare on 1M-context)
9. **Time limit reached -- ONLY if total sprint estimate >400 wall-clock hours AND threshold met**. Wall-clock hours are NOT a stop signal by themselves.

NOT valid: implementation choices, approach uncertainty, code style, single test failure, "this is taking long".

### 5. Phase Auto-Advance Rule

When work for the current phase completes, proceed IMMEDIATELY to the next phase's first action. Do NOT ask "want me to proceed to Phase N+1?". Sprint-plan approval at Phase 3 is durable authorization through Phase 7. The stop-hook will block paraphrased procedural questions on sprint feature branches.

Standing approval inventory (no permission needed): commits, pushes, PR-description updates, test/analyze runs, build-and-launch for manual testing.

### 6. Canonical "Next Steps" Progression (Sprint 38 retro)

After development tasks complete, the sequence is:

1. Manual integration testing (Phase 5.3)
2. **LOOP** until Manual integration testing noted complete by Lead Developer
   - Feedback from testing
   - In-sprint fixes (not always)
   - Backlog additions (not always)
3. Code review
4. Sprint retrospective (Phase 7, mandatory)
5. Merge to develop when approved
6. Begin next sprint

Do NOT reorder. Do NOT present Code Review before Manual Testing is loop-complete.

### 7. Resume Sequence (4 Steps -- run these in order on resume)

When a compact-string tells you to resume:

1. **Read the compact-string** -- it carries sprint name, current phase, HEAD, branch, last/next steps.
2. **Read `docs/sprints/SPRINT_N_PLAN.md`** (where N is from the compact-string) -- get the task list, acceptance criteria, and Phase 3.7 approval evidence.
3. **Run `git log -5 --oneline`** -- confirm HEAD matches the compact-string. If it doesn't match, the compact-string is stale; trust `git log` and update mental model.
4. **Execute the "next step" from the compact-string** -- do not re-read the full SPRINT_EXECUTION_WORKFLOW.md unless you hit genuine uncertainty.

### 8. Per-Sprint Docs Convention

- `docs/sprints/SPRINT_N_PLAN.md` -- created Phase 3
- `docs/sprints/SPRINT_N_RETROSPECTIVE.md` -- created Phase 7
- `docs/sprints/SPRINT_N_SUMMARY.md` -- created Phase 7 or Sprint N+1 Phase 3.2.1
- `CHANGELOG.md` -- updated mid-sprint with each user-facing change

Master plan: `docs/ALL_SPRINTS_MASTER_PLAN.md` -- update Phase 7 with completion metadata and "Past Sprint Summary" row.

### 9. Memory Index (Sprint Execution Gates)

These memory entries collectively govern sprint execution -- consult on uncertainty:

- `feedback_decision_class_taxonomy.md` -- 3 decision classes, Chief signoff
- `feedback_stopping_400hr.md` -- wall-clock hours are not a stop signal
- `feedback_echo_requirements.md` -- echo multi-surface requirements back
- `feedback_phase7_prompt_protocol.md` -- 7-step Phase 7 protocol
- `feedback_auto_advance_hook.md` -- stop-hook enforcement
- `feedback_sprint_resume.md` -- resume 4-step sequence (this section's source)
- `feedback_follow_the_docs.md` -- run the checklist step BEFORE productive work
- `feedback_mirror_working_code.md` -- when broken has working sibling, mirror it

### 10. Critical File Locations

- Project root: `D:\Data\Harold\github\spamfilter-multi`
- Flutter app: `mobile-app/`
- Build script: `mobile-app/scripts/build-windows.ps1`
- Test command: `cd mobile-app && flutter test` then `flutter analyze`
- Memory dir: `C:\Users\kimme\.claude\projects\D--Data-Harold-github-spamfilter-multi\memory\`
- Dev app data: `C:\Users\kimme\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`
- Dev DB: `{dev app data}\spam_filter.db`
- Background scan log: `{dev app data}\logs\dev_background_scan_v{VERSION}.log`

### 11. What `/sprint-compact` Does NOT Carry (So You Look Them Up Here)

The compact-string skill explicitly omits these because they live here permanently:

- The phase-by-phase definition above
- The decision-class taxonomy
- The stopping-criteria definitions
- The canonical Next Steps progression
- The 4-step resume sequence
- The critical file locations
- The memory index

This keeps the compact-string under ~2K characters and reduces token usage at every `/compact` boundary.

---

## When This Guide Itself Changes

Update this guide at sprint retrospective if any of the following change:

- Phase definitions or count
- Decision-class taxonomy
- Stopping criteria list
- Standing Approval Inventory
- "Next Steps" canonical progression
- Resume sequence steps
- Critical file paths (e.g., new build script, dev app data directory move)

When updating, also update the `/sprint-compact` skill if any field it outputs needs to change. Both files share the same source-of-truth contract: compact-string carries volatile state, this guide carries durable state.
