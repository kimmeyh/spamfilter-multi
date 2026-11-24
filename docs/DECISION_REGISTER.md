# Decision Register: questions, decisions and improvements

**Purpose**: one file that holds, in full, every question Claude asks Harold, every decision Harold makes, and
every improvement proposed to him. Items can cross sprints and some are not part of any sprint plan, so they live
here and not in `SPRINT_N_PLAN.md`. Source: Harold, 2026-11-22 and 2026-11-23 (d1 below). Backlog card F362.

## How to use this file

- **Ids**: `q<n>` question, `d<n>` decision, `i<n>` improvement. Each counter runs across all sprints and an id is
  never reused, so `q1` always means the same item. Ids used inside older sprint documents (for example the Sprint
  85 retrospective's i1-i8) are separate and stay where they are.
- **Find an item**: search for its heading, for example `^### q1\.` (Grep tool, or `rg "^### q1\." docs`). The
  Open index below lists every item that still needs an answer.
- **Full text**: each entry holds what it decides, every option with its pros and cons, the recommendation, and
  later Harold's verbatim answer and the date. A message that needs an answer copies the full entry from here.
- **Close an item**: add `- **Answer (Harold, <date>)**: "<verbatim>"` and what was done, then move its line from
  Open to Closed in the index. Never delete an entry.

## Index

### Open


### Closed

- q1. Sprint 85: how to record six task rows that have no minutes -- answered 2 (Harold, 2026-11-23)
- q2. F363: may the task-clock gates add new hook matchers to `.claude/settings.json` -- answered 1 (Harold, 2026-11-23)
- d4. F364 (Google Play policy and Console changes: analysis and compliance cards) is in Sprint 86 (Harold, 2026-11-23)
- d3. Backlog refinement shows ALL open items with details for all (Harold, 2026-11-23)
- d1. Questions, decisions and improvements live in this register with short ids (Harold, 2026-11-23)
- d2. F363 (task clock: minutes recorded for every task) is in Sprint 86 (Harold, 2026-11-23)

## Questions

### q1. Sprint 85: how to record six task rows that have no minutes

- **Asked**: 2026-11-21 04:15 at Phase 7.7.5 (Sprint 85). Old label: q-S85-min.
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23)**: "q1 2".
- **Done (2026-11-23 14:01)**: the six `**Executed-by**` lines in `docs/sprints/SPRINT_85_PLAN.md` and the six
  Sprint 85 rows in `docs/CODING_VELOCITY.md` now carry estimated minutes, each marked "estimated from commit
  times (Harold, register q1 = 2)" with its method: Task 1 ~10 (low confidence, no commit names it), Task 2 ~110,
  Task 4 ~23, Task 5 ~20, Task 7 ~17, Task 8 ~8 (main-session part only; the Haiku agent's time cannot be read
  from commits).
- **What it decides**: Sprint 85 Tasks 1, 2, 4, 5, 7 and 8 never had their minutes recorded. Their
  `**Executed-by**` lines in `docs/sprints/SPRINT_85_PLAN.md` say "actual minutes not recorded, 0 min logged ...
  (Sprint 85 retro i7)", and close-out check 3d-3 accepted that text. How should these six rows be recorded?
- **Options**:
  1. Keep "actual minutes not recorded, 0 min logged" (Recommendation). Pro: it does not invent numbers. F363
     makes the miss impossible from Sprint 86 on. Con: the velocity table has six rows with no time.
  2. Write estimated minutes from the commit times, each marked "estimated". Pro: the velocity table has a number
     for each task. Con: the time between commits includes reviews, builds and idle time, so a number can be wrong
     by a large amount.
- **Note (2026-11-23)**: Harold's reply to this question was the instruction that became F363 ("This cannot happen
  for any task ever again"). It did not choose option 1 or 2 for the six existing rows, so the question stays open.

### q2. F363: may the task-clock gates add new hook matchers to `.claude/settings.json`

- **Asked**: 2026-11-23 13:49 (Sprint 85 cycle, Phase 8.3).
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23)**: "q2 1". F363 adds all three gates (Agent, Edit|Write|NotebookEdit, commit);
  recorded on the F363 card.
- **What it decides**: F363 needs hooks that run on tools no hook watches today. `.claude/settings.json` now
  registers hooks only for `Bash|PowerShell` (PreToolUse) and Stop. F363 adds:
  - **Agent** (PreToolUse and PostToolUse): records a sub-agent task's start at handoff and its end at handback,
    with no step for Claude to forget.
  - **Edit|Write|NotebookEdit** (PreToolUse): blocks a code edit during Phases 4-5 when no task clock is open.
    This is the gate that catches a main-session task, which is where five of the six Sprint 85 misses happened.
  - The commit gate stays on `Bash|PowerShell`.
- **Options**:
  1. Add all three gates (Recommendation). Pro: covers sub-agent and main-session tasks, so no task can run
     without a clock. Con: every Edit and Write in Phases 4-5 runs one more hook (measured target: under 100 ms),
     and an edit outside a task (a plan typo fix) needs a short "no task" exemption list.
  2. Agent and commit gates only, no Edit gate. Pro: fewer hooks. Con: a main-session task can still run with no
     clock until its first commit, which is the Sprint 85 failure.
  3. Script and documentation only, no new gates. Pro: no settings change. Con: it relies on Claude remembering,
     which is what failed in Sprint 85.

## Decisions

### d1. Questions, decisions and improvements live in this register with short ids

- **Harold, 2026-11-23 (verbatim)**: "your memory is good for recent items. Should be in a repository file outside
  of Sprint_??_plan.md as they could cross sprints and some are not related to the plan (improvements, some
  questions and some decisions). Make sure you can get to the questions easily via search (whatever you use) or
  index. But keep the item for me simple (i1, i2... q1, q2.. d1, d2...)"
- **Done**: this file; the Sprint 86 plan's "Open questions" section moved here (q1); F362 R-1 and R-2 changed to
  name this file.

### d2. F363 (task clock: minutes recorded for every task) is in Sprint 86

- **Harold, 2026-11-23 (verbatim)**: "This cannot happen for any task ever again - how do you propose doing it -
  checklist at the end of each task, post start at handoff/send back, post finish at hand back - when the handback
  passe, update... Please figure it out, write a sprint card, add to this sprint as we have been tracking task
  details 20+ sprints and it should never fail for even one task."
- **Done**: card F363 in `docs/ALL_SPRINTS_MASTER_PLAN.md` (Priority 32); listed in `docs/sprints/SPRINT_86_PLAN.md`
  "Start of sprint". The rest of Sprint 86 scope is still selected at Phase 8.4.

### d3. Backlog refinement shows ALL open items with details for all

- **Harold, 2026-11-23 (verbatim)**: "Need to tweek the backlog_refinement.md display for this and all future
  sprints - can you have it include all open backlog items in priority order, group by non-on hold the by on hold,
  then for details, include details for all of the items listed in the first part."
- **Done**: `docs/BACKLOG_REFINEMENT.md` "Backlog Presentation Format" (version 1.6), the backlog-refinement skill,
  `SPRINT_CHECKLIST.md` 1.2 and Phase 1, and `SPRINT_EXECUTION_WORKFLOW.md` Phase 1.2. The index lists every open
  active item, then every HOLD item; details follow for all of them in the same order ("Details", then "ON HOLD
  Details"). Replaces the F293 limit of 20.

### d4. F364 (Google Play policy and Console changes: analysis and compliance cards) is in Sprint 86

- **Harold, 2026-11-23 (verbatim)**: "add to backlog for next sprint: analyze changes to google play store/console
  and their impact on this repository. Follow-up analysis with suggested additions to the backlog to bring the
  repository into compliance https://support.google.com/googleplay/android-developer/answer/18100766"
- **Same message**: "I have a EU declared development account. Make note in the repository".
- **Done**: card F364 in `docs/ALL_SPRINTS_MASTER_PLAN.md` (Priority 30); listed in `docs/sprints/SPRINT_86_PLAN.md`
  "Start of sprint"; EU note in `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (account section).

## Improvements

None open. Sprint 85 improvements i1-i8 were decided on 2026-11-21 and are recorded in
`docs/sprints/SPRINT_85_RETROSPECTIVE.md`; from Sprint 86 on, each retrospective improvement gets an `i<n>` entry
here.
