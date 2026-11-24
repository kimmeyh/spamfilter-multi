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

- None.

### Closed

- q7. Keep F363 and F364 in Sprint 86 -- answered 1, keep both (Harold, 2026-11-24)
- q8. Hooks to `py -3.14` -- answered 1, move and run the hook suite (Harold, 2026-11-24)
- q9. Close-out gate on unanswered questions -- answered 2, documentation only, and track (Harold, 2026-11-24)
- q10. Sprint 86 version -- answered 2, 0.26.0 (Harold, 2026-11-24)
- q6. Sprint 86: which more items join F364, F363, F362 and F307 -- answered with a scope list (Harold, 2026-11-23)
- q3. Where the all-items backlog details are shown when they are too long for one message -- answered 2 (Harold, 2026-11-23)
- q5. Commit the generated backlog slate file -- answered 1 (Harold, 2026-11-23)
- q4. Which EU status was declared in Play Console -- answered 2, non-trader (Harold, 2026-11-23)
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

### q3. Where the all-items backlog details are shown when they are too long for one message

- **Asked**: 2026-11-23 (Sprint 85 cycle, Phase 8.4); in full at 19:33.
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23)**: "q3. 2".
- **Done**: `docs/BACKLOG_REFINEMENT.md` "Presentation order" (version 1.7): several consecutive chat messages,
  index first, details split between cards, "Part n of m".
- **What it decides**: the d3 presentation (all items, details for all) was 50 active and 29 HOLD items, 1,059 lines,
  about 115,000 characters, far more than one message.
- **Options**: 1. Repo file plus the full index in chat (Recommendation). Pro: complete, searchable, in git. Con:
  details read in VS Code. 2. Several chat messages in a row. Pro: all in chat. Con: scrolling; hard to find an item
  later. 3. A private web page with expandable details. Pro: readable, linkable. Con: outside the repo; drifts.

### q5. Commit the generated backlog slate file

- **Asked**: 2026-11-23 19:33 (Sprint 85 cycle, Phase 8.4).
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23)**: "q5. 1".
- **Done**: `docs/sprints/SPRINT_86_BACKLOG_SLATE.md` committed; rule in `docs/BACKLOG_REFINEMENT.md` 1.7.
- **What it decides**: whether the script-generated slate is kept in git as the pass 2 record.
- **Options**: 1. Commit it (Recommendation). Pro: a fixed record of what was chosen from. Con: a second copy that
  ages. 2. Do not commit; regenerate when needed. Pro: no duplicate. Con: no record.

### q6. Sprint 86: which more items join F364, F363, F362 and F307

- **Asked**: 2026-11-23 (Sprint 85 cycle, Phase 8.4 pass 2), after the all-items slate
  (`docs/sprints/SPRINT_86_BACKLOG_SLATE.md`, 50 active and 29 HOLD) was shown in 8 parts.
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23, verbatim)**: "Sprint 86 Scope should include the below items. Please complete sprint
  planning (/docs/sprint_planning.md) for the below items and present for approval." Items: F362, F307, F336, F361,
  F346, F347, F359, F340, F344 (option 3: the recommendation plus F336 and F344). F363 and F364 are not in the list;
  see q7.
- **What it decides**: the rest of Sprint 86 scope. Already in: F364 (~60-120m), F363 (~180-270m), F362 (~45-60m),
  F307 (~45-75m) = ~330-525m.
- **Options**:
  1. Add F361 (~30-45m), F346 (~30m), F347 (~45m), F359 (~120-180m) and F340 (~20-40m) (Recommendation). Total
     about 575-865m. Pro: F361 pairs with F362 (both change how retrospective items are written); F346 and F347 add
     the logging that names the cause of the phone errors still seen (AOL errors on 11-22); F359 puts the
     phone-only defect paths under an automatic test; F340 is a small cleanup. Con: F363 is a large tooling item and
     comes first, so the app work starts later in the sprint.
  2. No additions: only F364, F363, F362, F307 (~330-525m). Pro: a short sprint, F363 and the Play deadline get full
     attention. Con: no app quality work this sprint.
  3. Option 1 plus items Harold names by id. Pro: Harold's own picks. Con: a larger sprint.
- **Left out of the recommendation**: F336 (~150-260m, another large tooling item beside F363); the iOS items
  F67a-F67d and F304 wait on Apple.

### q7. Sprint 86: keep F363 (task clock) and F364 (Play policy analysis)

- **Asked**: 2026-11-23, with the Sprint 86 plan for approval. **Status**: CLOSED.
- **Answer (Harold, 2026-11-24, verbatim: "q7. 1 q8. 1 q9. 2 and track q10. 2")**: option 1, keep both. Done: Tasks 10 (F363) and 11 (F364) are in the approved plan.
- **What it decides**: the 2026-11-23 scope list names nine items and leaves out F363 (register d2, "add to this
  sprint") and F364 (register d4, "add to backlog for next sprint"). The plan carries both as Tasks 10 and 11, pending
  this answer.
- **Options**:
  1. Keep both (Recommendation). Pro: F363 is the gate that stops a task closing with no minutes, and it runs first so
     every Sprint 86 task uses it; F364 has a Play window that ends about 2026-11-28 (counting unverified). Con: adds
     240-390m (sprint 785-1245m).
  2. Keep F364 only. Pro: the deadline item stays. Con: Sprint 86 minutes are recorded by hand again, the Sprint 85
     failure. Adds 60-120m.
  3. Keep F363 only. Pro: minutes are gated. Con: the Play analysis waits a sprint past its window. Adds 180-270m.
  4. Drop both to Sprint 87. Pro: the nine-item sprint (545-855m). Con: both cons above.

### q8. F344: move the hook registrations from Python 3.12 to `py -3.14`

- **Asked**: 2026-11-23, with the Sprint 86 plan. **Status**: CLOSED.
- **Answer (Harold, 2026-11-24, verbatim: "q7. 1 q8. 1 q9. 2 and track q10. 2")**: option 1. Done in Task 9: the hook registrations move to `py -3.14` and the hook suite runs.
- **What it decides**: F344 R-3. `.claude/settings*.json` runs every hook with `python` (3.12.10 on PATH). Harold
  chose Python 3.14 for tooling (Sprint 83 MV Question D = 2); changing the registrations is a `.claude` settings
  change, so it is asked now, not mid-sprint.
- **Options**:
  1. Move to `py -3.14`, then run the full hook suite (Recommendation). Pro: one Python version for hooks and scripts.
     Con: if a hook fails under 3.14, every tool call is affected until it is fixed; the suite run is the check.
  2. Leave the hooks on 3.12. Pro: no risk to the hooks this sprint. Con: two Python versions stay in use.

### q9. F362 R-4: does close-out block on an unanswered register question

- **Asked**: 2026-11-23, with the Sprint 86 plan. **Status**: CLOSED.
- **Answer (Harold, 2026-11-24, verbatim: "q7. 1 q8. 1 q9. 2 and track q10. 2")**: option 2, documentation only, "and track". Done in Task 1: no blocking gate. Read as "track": the close-out checklist lists every register item still Open as a report line (not a block), and the retrospective counts any question that reached close-out unanswered; a gate is proposed again if that count is above zero.
- **What it decides**: whether `verify-closeout-complete.py` gets a check that blocks sprint close-out while a register
  question asked in that sprint is still Open with no answer.
- **Options**:
  1. Add the check (Recommendation). Pro: an unanswered question cannot be forgotten at close-out (the Sprint 85 q1
     rows were found only at 7.7.5). Con: +3-4 hook cases, under 2 s locally and in CI; a question Harold wants to
     leave open must be moved to the next sprint by name.
  2. Documentation only. Pro: no new gate. Con: relies on remembering, which failed in Sprint 85.

### q10. Sprint 86 version: 0.25.1 or 0.26.0

- **Asked**: 2026-11-23, with the Sprint 86 plan. **Status**: CLOSED.
- **Answer (Harold, 2026-11-24, verbatim: "q7. 1 q8. 1 q9. 2 and track q10. 2")**: option 2, 0.26.0+24 (MINOR). Done at Phase 3.7.0b.
- **What it decides**: the 3.7.0b bump (versionCode 24 either way).
- **Options**:
  1. 0.25.1+24, PATCH (Recommendation). Pro: the sprint adds no new user feature; the user-visible change is the
     removal of a broken page plus log lines. Con: a removed page is a visible change some would call MINOR.
  2. 0.26.0+24, MINOR. Pro: marks the removed page as a visible change. Con: no new capability to justify a MINOR.

### q4. Which EU status was declared in Play Console

- **Asked**: 2026-11-23 19:12 (Sprint 85 cycle, Phase 8.4), after Harold's "I have a EU declared development
  account".
- **Status**: CLOSED.
- **Answer (Harold, 2026-11-23)**: "q4. 2".
- **Done**: `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` account section and F364 R-5 record NON-TRADER.
- **What it decides**: which trader status the account declared, so F364 checks the right requirements.
- **Options**: 1. Trader. 2. Non-trader. 3. Not sure; send a Play Console > Settings > Developer account screenshot.

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
