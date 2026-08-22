---
name: backlog-refinement
description: Run Phase 1 Backlog Refinement deterministically -- read the authoritative format, present candidates in EXACTLY the prescribed template, capture the PO selection, document and commit
user-invocable: true
---

# Backlog Refinement Skill (deterministic -- zero improvisation)

Phase 1 Backlog Refinement is a DETERMINISTIC process (Harold, Sprint 50): there is
nothing to figure out, only a template to follow exactly, every time. This skill
encodes it so the presentation can never drift again.

## WHICH PASS ARE YOU IN? (F170, Sprint 61 -- decide this FIRST)

Refinement runs TWICE per cycle, as Phase 8.2 and Phase 8.4. The steps below are shared, but
**step 5 applies to pass 2 only**:

- **Pass 1 -- COMPLETENESS SWEEP (Phase 8.2)**, immediately after the sprint PR merges to `develop`:
  confirm every sprint-close step was captured and completed (cards closed, docs triad present,
  master plan rolled, status file current, shipped items pruned). **SKIP step 5 -- this pass does
  NOT select scope.** Selecting here is premature: the Store release has not happened and close-out
  gaps may still be open.
- **Pass 2 -- SCOPE SELECTION (Phase 8.4)**, once the Store submission is in process: present the
  slate and capture the selection. **Step 5 applies.**

If you cannot tell which pass you are in, read `.claude/sprint_status.json`
`current_sprint.status`, and see `SPRINT_EXECUTION_WORKFLOW.md` "Phase 8: The Release Cycle".

## Steps (in order, no substitutions)

1. **READ THE FORMAT FIRST -- IN THIS TURN**: Read `docs/BACKLOG_REFINEMENT.md`
   section "Backlog Presentation Format" (near the bottom, under Quick Reference).
   A read from an earlier turn does NOT count. The chat presentation IS the
   refinement output and mirrors that template exactly.

2. **Prepare** (BACKLOG_REFINEMENT.md Step 1): read
   `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" + "Last Completed
   Sprint" carry-ins; run `gh issue list --state open` ; note stale items
   (3+ sprints unreviewed).

3. **Assign real identifiers** (Step 5.3): every candidate gets a registered id --
   F# (next available; check the master plan for conflicts), WS-*, GP-#, or
   Issue #N. NEVER present an unregistered slug (AMBIG-ROWS-style names are the
   Sprint 50 violation).

4. **Present in the EXACT template** -- opening with the REQUIRED Summary Index
   ("## Candidates at a glance": every item's header line only, in order, plus a
   one-line HOLD ids row), then the detailed sections. Per item:

   ```markdown
   **<ID>. <Title> (~<effort>) Priority <N>**
   - Phase: <phase name>
   - Platform: <Windows Desktop | Android | All | N/A>
   - <description bullet>
   - Depends on: <dependencies, if any>
   ```

   - Items grouped under `### <Phase Name>` section headers (real phase names,
     never invented "tiers")
   - Priorities NUMERIC: increments of 10; sprint-together items increments of 2
   - HOLD items: `Priority HOLD`, grouped in `### HOLD Items (<reason>)` at the
     bottom
   - NO grid tables, NO selection-numbering prefixes, NO ad-hoc groupings
   - Include observations / alternative sprint compositions AFTER the formatted
     list, not woven into it

5. **Capture the Product Owner's selection** for the Phase 3 plan doc.
   **PASS 2 ONLY** -- in pass 1 (the completeness sweep) skip this step entirely; there is no
   selection to make yet (F170, Sprint 61).

6. **Document + commit** (Step 6): update ALL_SPRINTS_MASTER_PLAN.md (new items
   in the same format, re-prioritized order, obsolete items removed with reason);
   commit `docs: Backlog refinement - [date] - [summary]`.

## Hard rules

- Producing the presentation without executing step 1 in the same turn is a
  process violation -- stop and do step 1.
- If the master plan and this skill ever disagree on format,
  `docs/BACKLOG_REFINEMENT.md` "Backlog Presentation Format" wins; flag the
  discrepancy to Harold.
