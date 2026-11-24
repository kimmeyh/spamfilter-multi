# F344 Prompt Inventory (Sprint 86, Task 9)

## BLUF

28 prompts outside skills were inventoried: 10 deterministic, 16 hybrid, 2 GenAI. Two helpers are shared by two or
more prompts and are built: `scripts/quality-gate.py` (8 prompts) and `scripts/subagent-brief.py` (6 prompts for
`block`, 3 for `files`). Both have a unittest with real failing inputs and a mutation check. The prompts that call
them were changed. Three more helpers are named and not built because only one prompt would call each. Skill scripts
are F339 and are not touched here (R-4).

Date: 2026-11-24. Evidence for each row is the file read in this turn. ADR-0051 listed `.claude/commands/` and
`.claude/agents/` as "prompts to a model, stay `.md`" and did not classify them; this file does. They stay `.md`
(their judgment parts are GenAI), and their fixed steps now call a helper.

## Method

- Disposition rule (ADR-0051): deterministic = every step is fixed, so it is code, not a prompt. Hybrid = a script can
  do the fixed part and the model judges the rest. GenAI = judgment only.
- Scope: text that tells a model what to do and lives outside `.claude/skills/`. Harold-facing message templates (the
  retrospective prompt in 7.3 Step 1, the Manual Validation handover, the backlog-refinement presentation) are output
  formats owned by their phase documents and by the `backlog-refinement` skill (F339 side). They are NOT inventoried
  here; see "Not inventoried" at the end.
- A shared helper = a fixed step that two or more prompts repeat. Counted from this inventory.

## A. Agents (`.claude/agents/`, 5)

- `build-validator.md`: hybrid. Fixed: build commands, analyze, test, format. Helper: `scripts/quality-gate.py`
  (analyze and test, BUILT). The Windows and Android builds keep their own scripts (`build-windows.ps1`,
  `build-with-secrets.py`); the report is judgment. Changed: steps 3 and 4 merged into one gate call.
- `code-architect.md`: GenAI. Design review and recommendations. No fixed step.
- `code-simplifier.md`: hybrid. Fixed: the closing "run tests and analyze" check. Helper: `scripts/quality-gate.py`
  (BUILT). Simplifying code is judgment. Changed: process steps 4 and 5.
- `oncall-guide.md`: hybrid. Fixed: "run flutter test" and "flutter analyze" in the investigation, resolution and
  command list. Helper: `scripts/quality-gate.py` (BUILT). Severity and root-cause work is judgment. Changed: three
  places.
- `verify-app.md`: hybrid. Fixed: analyze and the full test run, the stale "138+ tests" rule. Helper:
  `scripts/quality-gate.py` (BUILT). Manual and edge-case verification is judgment. Changed: step 1, guidelines.

## B. Commands (`.claude/commands/`, 5)

- `commit-push-pr.md`: hybrid. Fixed: the analyze and test check. Helper: `scripts/quality-gate.py` (BUILT). Commit
  message and PR text are judgment. Changed: step 2. (A skill of the same name exists; skills are F339.)
- `first-principles.md`: GenAI. It only tells the model to invoke the skill.
- `quick-commit.md`: hybrid. Fixed: analyze and test. Helper: `scripts/quality-gate.py` (BUILT). Changed: step 2.
- `review-changes.md`: hybrid. Fixed: analyze, test and the format check. Helper: `scripts/quality-gate.py` (BUILT);
  `dart format --check` stays a command (one prompt). The per-file review is GenAI. Changed: step 3.
- `test-and-fix.md`: hybrid. Fixed: run the suite, check the pass count, re-run. Helper: `scripts/quality-gate.py`
  (BUILT). Fixing failures is GenAI. Changed: steps 1, 3 and 6.

## C. Prompts and briefs in `docs/` (9, plus two notes that are not counted)

- `docs/STATUS_FOOTER_SETUP_PROMPT.md`: hybrid. A portable prompt that makes Claude build a footer script in ANOTHER
  repo. Fixed part: the footer itself, done by `.claude/hooks/status-footer.py` (exists). Not changed: the prompt is
  deliberately self-contained so it works in a repo that has no copy of the script (its own header says so).
- "Progress and restart" block (`docs/SPRINT_EXECUTION_WORKFLOW.md` lines 1163-1192): deterministic. Fixed text pasted
  verbatim into every subagent prompt. Helper: `scripts/subagent-brief.py block` (BUILT) prints it from the document
  with `<task-name>` and `<SCRATCH>` filled in.
- Delegation checklist (`docs/SPRINT_PLANNING.md` lines 447-469): hybrid. Fixed: item 8 (paste the block), items 1 and 2
  (run the tests, run `scripts/mutation-test.py`). Judgment: items 3 to 7. Helper: `subagent-brief.py block` for item 8
  (BUILT); the other fixed items already have scripts. Changed: item 8 now names the command.
- 7.7.1 code-reviewer prompt (workflow line 1454 and Phase 7 order): hybrid. Fixed: the file list "Files to review
  (N)", the exclusion sentence, the "Files read: M of N" instruction, the block. Helper: `subagent-brief.py files`
  and `block` (BUILT). The review is GenAI. Changed: line 1454 names the command.
- 7.7.1 silent-failure-hunter prompt: hybrid. Same fixed parts and helpers as the code-reviewer prompt.
- 7.7.1 improvement review prompts (code-reviewer and silent-failure-hunter, one pass): hybrid. Same helpers; the range
  is `<last 7.7.1 fix commit>..HEAD`, which `files --range` takes.
- Background CI-fix agent prompt (7.7.1 CI run 1): hybrid. Fixed: the block. Helper: `subagent-brief.py block` (BUILT).
  The fix is GenAI.
- Phase 4.1 delegated-task prompt: hybrid. Fixed: the block and the delegation checklist. Helper: `subagent-brief.py
  block` (BUILT). The task is GenAI.
- Hourly wake-up prompt (workflow lines 1203-1222, the cron text): hybrid. Fixed: run the status script (step 2), list
  old mutation locks (step 4), the footer (step 7). Those three are already scripts: `scripts/agent-work-status.py`
  and `.claude/hooks/status-footer.py`. Step 5 (read `current_sprint.status`, decide whether the Auto-Advance window
  applies) is a fixed rule but only this one prompt uses it: future candidate, not built.
- 5.1.2 "every language in the diff" search (workflow line 687): not a prompt to a subagent. It uses the same
  `git diff --name-only origin/develop...HEAD` command as the review prompts; it was NOT changed (it wants the raw list,
  not the review text).
- Copilot review request: the `copilot-pr-review` skill owns it (skill, F339 side). Not counted.

## D. Hook-delivered text (`.claude/hooks/`, 9)

Each hook prints a fixed message to Claude (a block reason or a warning). The text is fixed, the decision is a regex or
file check, and every hook is already Python (ADR-0051, F326 to F329). Disposition for all nine: deterministic, no
action. Their tests are the recorded cases under `.claude/hooks/test-cases/`, run by
`python .claude/hooks/run-test-cases.py`.

- `block-blind-staging.py`, `block-carry-forward-stash.py`, `block-commit-during-mutation.py`,
  `block-heredoc-python-backslash.py`, `require-sprint-cards.py`, `sprint-auto-advance.py`,
  `verify-closeout-complete.py`, `warn-commit-without-velocity.py`, `task-clock-gate.py`.

## Counts

- Deterministic (10): the Progress and restart block, and the nine hooks.
- Hybrid (16): build-validator, code-simplifier, oncall-guide, verify-app, commit-push-pr, quick-commit,
  review-changes, test-and-fix, STATUS_FOOTER_SETUP_PROMPT, delegation checklist, 7.7.1 code-reviewer, 7.7.1
  silent-failure-hunter, 7.7.1 improvement review, background CI-fix agent, Phase 4.1 delegated task, hourly wake-up.
- GenAI (2): code-architect, first-principles.
- Total 28 = 5 agents + 5 commands + 9 docs prompts + 9 hooks. The Progress and restart block is a docs row counted as
  deterministic; the two review-pass rows (code-reviewer, silent-failure-hunter) and the improvement review are one
  row each.

## Shared-step counts (R-2)

- Analyze plus full test run with a pass rule: 8 prompts (build-validator, code-simplifier, oncall-guide, verify-app,
  commit-push-pr, quick-commit, review-changes, test-and-fix). BUILT: `scripts/quality-gate.py`. Existing scripts
  checked first: `mobile-app/scripts/run-tests.py` runs a fixed subset of files and treats analyze as a warning;
  `scripts/run-full-suite.py` runs the full suite with stall evidence but not analyze. Neither gives one analyze-plus-
  tests verdict, so the gate is new and reuses `mobile-app/scripts/flutter_support.py` (find flutter, run it, parse the
  summary line).
- Print the Progress and restart block: 6 prompts (7.7.1 code-reviewer, 7.7.1 silent-failure-hunter, 7.7.1 improvement
  review, CI-fix agent, Phase 4.1 delegated task, delegation checklist item 8). BUILT: `subagent-brief.py block`.
- Build the "Files to review (N)" text: 3 prompts (code-reviewer, silent-failure-hunter, improvement review). BUILT:
  `subagent-brief.py files`.
- Step 5 of the wake-up (window check): 1 prompt. Not built.
- Run `agent-work-status.py` and print the footer: 1 prompt each, and both scripts already exist.

## Helpers built

- `scripts/quality-gate.py` (tests: `scripts/tests/test_quality_gate.py`).
- `scripts/subagent-brief.py` (tests: `scripts/tests/test_subagent_brief.py`).

## Prompt edits and how the prompts call the helpers

The four review prompts, the CI-fix prompt and the 4.1 prompt reach the block and the file list through the canonical
sections they already reference, because the policy test `progress_and_restart_block_test.dart` pins their anchor lines
(each must keep the phrase "Progress and restart block"). The command is written once at the canonical section and
at the delegation checklist:

- `docs/SPRINT_EXECUTION_WORKFLOW.md:1163` (block command), `:1454` (files command).
- `docs/SPRINT_PLANNING.md:470` (checklist item 8).

## Helpers named, not built

- Wake-up window check (`scripts/wake-up-status.py`, working name): one prompt (the hourly wake-up). It would combine
  `agent-work-status.py` with a check of `current_sprint.status` against the Auto-Advance window. Build when a second
  prompt needs the window check.
- Reviewer "Files read: M of N" checker: the lead would run it on a reviewer's report. It is called by the lead, not by a
  prompt, and the report format is not fixed. Build when the report format is pinned.
- `dart format --check` wrapper: one prompt (review-changes). Not worth a script.

## Not inventoried

- Harold-facing templates owned by a phase doc: the 7.3 Step 1 retrospective prompt, the Manual Validation handover, the
  7.7.5 readiness announcement. They are output formats checked by `verify-closeout-complete.py` and
  `sprint-auto-advance.py`. A later pass can list them.
- Prompts inside skills (F339) and `.claude/skills/*` scripts (R-4).
