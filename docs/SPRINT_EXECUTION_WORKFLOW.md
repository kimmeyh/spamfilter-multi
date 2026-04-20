# Sprint Execution Workflow

This document describes the step-by-step process for executing sprints in the spamfilter-multi project, based on actual experience from Sprint 1.

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** (this doc) | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## [WARNING] CRITICAL REMINDER: Phase 7 Sprint Review is MANDATORY

**IMPORTANT**: Phase 7 (Sprint Review) is a REQUIRED step for all sprints. It is not optional.

**What to Remember**:
1. Do NOT skip Phase 7 - it must be conducted after PR is submitted
2. Phase 7 provides critical feedback for continuous improvement
3. User can provide quick feedback - it does not take long
4. Phase 7 must complete BEFORE merging PR to develop
5. Documentation improvements from Phase 7 are applied to feature branch

**Location**: See Phase 7 section below (after Phase 6: Push to Remote & Create PR)

---

## Phase Numbering Reference

| Phase | Name | Purpose |
|-------|------|---------|
| **Phase 1** | Backlog Refinement | Optional, on-demand backlog grooming |
| **Phase 2** | Sprint Pre-Kickoff | Verify prerequisites before starting |
| **Phase 3** | Sprint Kickoff & Planning | Plan sprint, create branch and issues |
| **Phase 4** | Sprint Execution (Development) | Implement tasks, test, commit |
| **Phase 5** | Code Review & Testing | Final review, full test suite, manual testing |
| **Phase 6** | Push to Remote & Create PR | Finalize, push, create PR |
| **Phase 7** | Sprint Review & Retrospective | Mandatory review, feedback, documentation |

---

## Sprint Execution Checklist

### **Phase 1: Backlog Refinement** (OPTIONAL - On-Demand)

Backlog refinement is conducted **when requested by Product Owner**, not before every sprint.

- [ ] **1.1 Check if Refinement is Requested**
  - Product Owner explicitly requests backlog refinement
  - Skip to Phase 2 if refinement not requested
  - Quick priority changes can be handled during Phase 3 without full refinement

- [ ] **1.2 Conduct Refinement Session** (30-60 minutes, timeboxed)
  - **Prepare**: Read current backlog state from ALL_SPRINTS_MASTER_PLAN.md and ISSUE_BACKLOG.md
  - **Review**: Scan all items, identify stale entries (over 3 sprints old)
  - **Prioritize**: Re-order based on value, effort, and risk
  - **Estimate**: Update estimates with velocity calibration from recent sprints
  - **Add**: Capture newly identified work items
  - **Cleanup**: Remove obsolete items, update dependencies

- [ ] **1.3 Document Refinement Results**
  - Update ALL_SPRINTS_MASTER_PLAN.md "Future Features" section
  - Update ISSUE_BACKLOG.md if issues changed
  - Commit changes: `git commit -m "docs: Backlog refinement - [date] - [summary]"`

**Detailed Process**: See `BACKLOG_REFINEMENT.md` for complete step-by-step guide.

**When to Request Refinement**:
- Significant new features need scoping
- Priorities have shifted due to business changes
- Backlog items over 3 sprints old without review
- Major sprint completed that opens new possibilities
- Technical debt needs prioritization

---

### **Phase 2: Sprint Pre-Kickoff** [WARNING] CRITICAL PREREQUISITE

- [ ] **2.1 Cache Sprint Context** (Optimization)
  - Read ALL_SPRINTS_MASTER_PLAN.md ONCE
  - Verify "Last Completed Sprint" section reflects the most recent sprint (update if stale)
  - Review "Next Sprint Candidates" table for prioritized work items
  - Cache in memory:
    - Next Sprint Candidates: prioritized table of features, bugs, and tasks
    - Last Completed Sprint details: For summary creation in Phase 3.2.1
  - No re-reading needed until Phase 7.6 (updates)
  - **Efficiency Gain**: Reduces file reads from 3 to 1 per sprint
  - **Reference**: See "Maintenance Guide" at top of ALL_SPRINTS_MASTER_PLAN.md for update rules

---

- [ ] **2.2 Verify Previous Sprint is Merged**
  - Confirm previous sprint PR is merged to `develop`
  - Command: `git log develop --oneline -1` should show last sprint commits
  - Previous feature branch is deleted locally and remote

- [ ] **2.3 Verify All Sprint Cards Are Closed**
  - Run: `gh issue list --label sprint --state open`
  - All issues from previous sprint should be CLOSED
  - If any open, manually close them: `gh issue close #N --reason "completed"`

- [ ] **2.4 Ensure Working Directory is Clean**
  - Command: `git status` should show "nothing to commit, working tree clean"
  - No uncommitted changes left over from previous sprint
  - All work is pushed to remote (see 6.2)

- [ ] **2.5 Verify Develop Branch is Current**
  - Command: `git checkout develop`
  - Command: `git pull origin develop`
  - Local develop branch matches remote
  - Ready to create new sprint feature branch

- [ ] **2.6 Dependency Vulnerability Check** (SEC-16)
  - Command: `cd mobile-app && dart pub outdated`
  - Review output for:
    - Discontinued packages (replace or plan migration)
    - Major version bumps with known security fixes
    - Any packages flagged with security advisories
  - If critical vulnerabilities found: add to sprint scope or create backlog item
  - If only minor/major version drift: document in sprint plan, no action needed
  - Consider running `dart pub audit` if available in current Dart SDK

- [ ] **2.7 Now Proceed to Phase 3: Sprint Kickoff & Planning**
  - Create new feature branch for next sprint
  - Create sprint cards
  - Begin execution

**[CHECKPOINT]** Before proceeding to Phase 3, re-read Phase 3 items in `docs/SPRINT_CHECKLIST.md`.

---

### **Phase 3: Sprint Kickoff & Planning**

- [ ] **3.1 Determine Next Sprint Number**
  - Last completed sprint: Sprint 1
  - Next sprint: Sprint 2
  - Pattern: Increment by 1

- [ ] **3.2 Review Sprint Plan**
  - Read ALL_SPRINTS_MASTER_PLAN.md (if not cached in Phase 2.1)
  - Review "Next Sprint Candidates" table for prioritized work items
  - **Present candidates to user in sprint refinement format** (see BACKLOG_REFINEMENT.md "Backlog Presentation Format" section). Use the item format: `**<ID>. <Title> (~<effort>) Priority <N>**` with bullet point details. Do NOT use grid tables.
  - Select items for Sprint N based on priority, dependencies, and capacity
  - Review "Feature and Bug Details" section for selected items
  - Verify scope, tasks, and acceptance criteria
  - Note any changes needed based on previous sprint learnings

- [ ] **3.2.1 Create Sprint Summary for Previous Sprint** (Background Process - MANDATORY)
  - **When**: During planning for Sprint N+1, create `docs/sprints/SPRINT_<N>_SUMMARY.md` for completed Sprint N
  - **Purpose**: Archive historical sprint details from ALL_SPRINTS_MASTER_PLAN.md
  - **Template**: Use structure from SPRINT_RETROSPECTIVE.md or previous `docs/sprints/SPRINT_<N>_SUMMARY.md` files
  - **Content Sources** (in priority order):
    1. `docs/sprints/SPRINT_<N-1>_RETROSPECTIVE.md` (if exists from Phase 7.7)
    2. CHANGELOG.md (Sprint N-1 entries)
    3. Git history (PR description, commit messages)
    4. GitHub issues (closed sprint issues)

    **Do NOT extract from ALL_SPRINTS_MASTER_PLAN.md** - it was already cleaned up in previous sprint.
  - **Content to Include**:
    - Sprint objective and scope
    - Tasks completed (A, B, C, etc.)
    - Deliverables produced
    - Estimated vs actual duration
    - Key decisions made
    - Lessons learned
    - Process improvements implemented
    - Link to PR and GitHub issues
  - **Update ALL_SPRINTS_MASTER_PLAN.md**: Add entry to "Past Sprint Summary" table
  - **Example Entry**:
    ```markdown
    | N | docs/sprints/SPRINT_N_SUMMARY.md | [OK] Complete | ~Xh (MMM DD-DD, 2026) |
    ```
  - This keeps ALL_SPRINTS_MASTER_PLAN.md focused on current/future work while preserving history

- [ ] **3.2.2 Create Sprint Plan Document** (MANDATORY)
  - Create `docs/sprints/SPRINT_N_PLAN.md` for the current sprint
  - **Content**: Sprint objective, tasks (A, B, C...), acceptance criteria, risk assessment, model assignments
  - **Source**: Copy from ALL_SPRINTS_MASTER_PLAN.md Sprint N section and expand with implementation details
  - **Why**: Provides a durable, self-contained record of what was planned for this sprint
  - **Naming Convention**: Uppercase `SPRINT_N_PLAN.md` (e.g., `SPRINT_17_PLAN.md`)

- [ ] **3.3 Branch Management**
  - Check if repository is in a PR branch
  - If yes: Wait for PR approval/merge, then switch to main/develop
  - Create new feature branch: `feature/<YYYYMMDD>_Sprint_<N><optional_suffix>`
  - Example: `feature/20260124_Sprint_2` or `feature/20260124_Sprint_2_Rule_Migration`
  - Switch repository to new branch: `git checkout -b <branch-name>`

- [ ] **3.3.1 Create Draft PR Immediately** (RECOMMENDED - Early Visibility)
  - **When**: Immediately after branch creation and sprint plan approval (at Phase 4 start)
  - **Why**: Provides visibility into sprint progress from the start
  - **Important**: Create a NEW draft PR for each sprint. Do not reuse PRs from planning/architecture phases, as this makes the PR history and description less clean. The draft PR should represent the sprint work from the beginning.
  - **How**:
    ```powershell
    git push -u origin feature/YYYYMMDD_Sprint_N
    gh pr create --draft --title "Sprint N: [Title]" --body "Sprint plan: [link or summary]"
    ```
  - **Benefits**:
    - User can track progress via PR at any time
    - Commits appear in PR as work progresses
    - No end-of-sprint rush to create PR
    - Draft status indicates work in progress
  - **PR Body Template**:
    ```markdown
    ## Sprint N: [Title]

    **Status**: [DRAFT] In Progress

    ### Sprint Plan
    - [ ] Task A: [description]
    - [ ] Task B: [description]
    - [ ] Task C: [description]

    ### GitHub Issues
    - Closes #XX, #YY, #ZZ

    ---
    *This PR will be updated as tasks complete. Mark ready for review when Phase 5 testing passes.*
    ```
  - **Note**: Draft-to-ready conversion happens at Phase 6.4.5 (mandatory step, not advisory). Do NOT mark ready here at Phase 3.3.1 -- the PR stays draft until Phase 6 work is in and tests are green.

- [ ] **3.4 Create GitHub Sprint Cards** (MANDATORY - Never Skip)
  - **CRITICAL**: GitHub issues MUST be created for ALL sprint tasks, even if sprint plan is pre-approved
  - Create one GitHub issue per task (Task A, Task B, Task C, etc.)
  - Use sprint_card.yml template from `.github/ISSUE_TEMPLATE/`
  - Fill in:
    - **Sprint**: Sprint N
    - **Description**: What needs to be done and why
    - **Acceptance Criteria**: Specific, measurable criteria
    - **Model Assignment**: Task breakdown with Haiku/Sonnet/Opus assignments
    - **Complexity Score**: Cognitive load (Low/Medium/High)
  - Apply labels: `sprint`, `card`, `priority:high/medium/low`
  - Link to related issues (dependencies, related features)
  - **Rationale**: GitHub issues provide traceability, can be referenced in commits/PRs, and close automatically when PR merges

- [ ] **3.4.1 Verify Issue Accuracy** (before finalizing sprint cards)
  - For bug/fix issues: Verify the issue still exists (may have been fixed in previous sprint)
  - For test-related issues: Run `flutter test` to confirm current test state
  - For feature issues: Verify feature does not already exist in codebase
  - **If issue is already resolved**: Close the issue, do not include in sprint
  - **If issue description is outdated**: Update description to reflect current state
  - **Rationale**: Prevents wasted effort on already-resolved issues (learned from Sprint 12: Issue #119)

- [ ] **3.5 Verify All Sprint Cards Are OPEN**
  - Before execution, verify all sprint cards exist and are in OPEN state
  - Command: `gh issue list --label sprint --state closed`
  - If any closed cards exist for this sprint: Re-open them
  - Reason: Closed cards block execution (from Sprint 1 learning: Issue #52)
  - Update: Switch all closed sprint cards to OPEN state

- [ ] **3.6 Verify Sprint Readiness**
  - All sprint cards created, linked, and in OPEN state
  - No blocking issues or dependencies unresolved
  - Model assignments reviewed and finalized
  - Acceptance criteria clear, testable, and QUANTIFIABLE (see SPRINT_PLANNING.md Best Practices)
  - **VERIFY**: Sprint plan acceptance criteria match GitHub issue criteria EXACTLY (copy from issues)
  - **VERIFY**: All acceptance criteria are quantifiable and measurable (no subjective terms)
  - Dependencies on previous sprints verified as complete
  - Risk assessments documented for all tasks (even if "Low - maintenance work")
  - Effort estimates included for all tasks (with 20% buffer for manual testing tasks)

- [ ] **3.6.1 Architecture Impact Check** (MANDATORY - Added Sprint 30)
  - **Purpose**: Prevent architecture drift by catching documentation gaps BEFORE sprint approval
  - **Check**: Review planned sprint tasks against documented architecture:
    - `docs/ARCHITECTURE.md` -- Do planned changes affect documented components, patterns, or data flows?
    - `docs/ARSD.md` -- Do planned changes affect architecture requirements or design specifications?
    - `docs/adr/*.md` -- Do planned changes conflict with or extend any ADR decisions?
  - **Determine if sprint scope needs**:
    - New ADR (for new architectural decisions)
    - ADR update (for changes to existing decisions)
    - ARCHITECTURE.md update (for new services, screens, patterns, database tables)
    - ARSD.md update (for requirements or design spec changes)
  - **If updates needed**: Include architecture documentation tasks in the sprint plan
  - **If no impact**: Note "No architecture impact" in sprint plan and proceed
  - **Rationale**: Architecture drift accumulated over Sprints 20-29 because docs were not checked during planning. This step prevents recurrence. (Learned Sprint 30)

- [ ] **3.7 CRITICAL: Plan Approval = Task Execution Pre-Approval**
  - **SUGGESTION**: User may optionally run `/compact` before approving plan to refresh context for execution
    - **When Helpful**: After long planning discussions (>30K tokens used)
    - **Benefits**: Fresh context for Phases 4-7, all plan details preserved in ALL_SPRINTS_MASTER_PLAN.md + GitHub issues
    - **Not Required**: Optional optimization, not mandatory
  - User reviews complete sprint plan (Tasks A, B, C, etc.)
  - User approves Phase 3 sprint plan
  - **Plan Approval = Pre-Approval for ALL Tasks A-Z through Phase 7 (Sprint Review)**
  - Claude should NOT ask for approval on individual tasks
  - Claude should NOT ask before starting each task
  - Claude should work autonomously and continuously until:
    - (a) Blocked/escalated (Criterion 2 in SPRINT_STOPPING_CRITERIA.md)
    - (b) All tasks complete (Criterion 1 in SPRINT_STOPPING_CRITERIA.md)
    - (c) Sprint review requested (Criterion 5 in SPRINT_STOPPING_CRITERIA.md)
    - (d) Code review needed (Phase 7 checkpoint)
  - If user requests mid-sprint changes: Document scope change, get re-approval, resume
  - **Reference**: Approval Gates section below
  - **Additional Reference**: `docs/SPRINT_STOPPING_CRITERIA.md` for when to stop

  **CRITICAL CLARIFICATION - When to Ask vs When to Execute**:

  [OK] **Execute WITHOUT asking** (plan-approved):
  - Implementing tasks exactly as described in sprint plan
  - Making implementation decisions within scope (method signatures, class names, file structure)
  - Refactoring code to support task requirements
  - Adding tests to validate implementation
  - Fixing bugs discovered during task execution
  - Architectural decisions that were implied by task acceptance criteria

  [FAIL] **STOP and ask** (not plan-approved):
  - New requirements not in sprint plan
  - Scope change expanding beyond task definition
  - Blocked on external dependency or missing information
  - Design decision with multiple equally-valid approaches AND task does not specify which

  **Decision Rule**: If task acceptance criteria can be met with this decision, execute it. Only ask if acceptance criteria do not provide enough guidance.

  **Standing Approval Inventory (Sprint 35+)**: Sprint plan approval at Phase 3 grants the following standing authorizations until sprint close. None of these require a per-occurrence permission prompt.

  **[OK] Plan-approved actions (execute without asking)**:
  - All file edits implementing approved tasks
  - `git add` / `git commit` (single logical commits per task or task batch)
  - `git push` to the sprint feature branch (`feature/YYYYMMDD_Sprint_N`)
  - PR creation against `develop` and PR description / body updates on the sprint PR
  - `gh pr ready <PR-number>` to convert draft PR to ready for review (Phase 6.4.5)
  - Build commands: `build-windows.ps1`, `flutter test`, `flutter analyze`, `build-with-secrets.ps1` (for sprint-relevant build types)
  - Launching the desktop app for manual testing (Phase 5.3)
  - WinWright MCP interactions per the conditional + state-restoration rule (`docs/TESTING_STRATEGY.md` Desktop E2E section)
  - SQLite reads against the dev DB for diagnostic purposes
  - Sprint doc updates: `CHANGELOG.md`, `docs/sprints/SPRINT_N_PLAN.md`, `docs/sprints/SPRINT_N_RETROSPECTIVE.md`, `docs/sprints/SPRINT_N_SUMMARY.md`, `docs/ALL_SPRINTS_MASTER_PLAN.md`
  - GitHub issue creation for backlog items / bugs surfaced by sprint work (BUG-S##-#, F## entries)
  - Memory file writes under `.claude/memory/` per the auto-memory protocol
  - `gh pr view`, `gh issue view`, `gh issue list`, `gh pr list` (read-only GitHub CLI)

  **[FAIL] Always-confirm actions (ask each time, regardless of plan approval)**:
  - `git push --force` or `git push --force-with-lease`
  - `git reset --hard`, `git checkout --` against tracked files, `git branch -D`
  - Branch deletion (local or remote)
  - `git rebase -i` or any interactive git command
  - SQLite `DELETE` / `UPDATE` against the dev DB (Sprint 35 used this for cleanup; should have asked first)
  - Modifications to secrets files (`secrets.dev.json`, `secrets.prod.json`, `google-services.json`)
  - `flutter pub upgrade` or any dependency version change not explicitly in the plan
  - `git push` to `develop` or `main` (only Harold pushes to these)
  - Creating a PR against `main` (Claude PRs target `develop` only -- per CLAUDE.md branch policy)
  - Hooks: `--no-verify`, `--no-gpg-sign`, or any commit/push that bypasses configured hooks
  - Any action against shared infrastructure (CI configs, GitHub Actions workflows) outside the sprint plan

  **Rationale**: Per Sprint 35 retro Process Issues, Opus 4.7 has a higher tendency to confirm before visible/persistent actions than prior models. This inventory makes the autonomy boundary explicit: if the action is in the [OK] list, execute it; if it's in the [FAIL] list, confirm. Anything not enumerated falls back to the Decision Rule above.

**[CHECKPOINT]** Before proceeding to Phase 4, re-read Phase 4 items in `docs/SPRINT_CHECKLIST.md`.

---

### **Phase 4: Sprint Execution (Development)**

- [ ] **4.1 Start Task Execution**
  - Assign tasks to appropriate Claude Code models
  - Haiku starts with straightforward tasks
  - Sonnet available for escalation if needed
  - Opus available for complex issues

- [ ] **4.1.1 Review Architecture Guidance** (For Complex Tasks)
  - For tasks involving new components or architectural changes:
    - Read `docs/ARCHITECTURE.md` for system design patterns
    - Follow existing architectural principles
    - Document significant deviations in PR description

- [ ] **4.1.2 Review Performance Benchmarks** (For Performance-Sensitive Tasks)
  - For tasks affecting performance (database, scanning, UI rendering):
    - Read `docs/PERFORMANCE_BENCHMARKS.md` for baseline metrics
    - Benchmark before and after changes
    - Document performance impact in PR description

- [ ] **4.2 Testing Cycle (Per Task)**
  - **Compile**: Build the code
    - Command: `flutter build windows` or `flutter build apk` (as needed)
  - **Run Tests**: Execute test suite
    - Command: `flutter test`
    - Expected: All tests pass
    - **Strategic Test Runs** (Efficiency Tip): Only run tests AFTER fixing identified issue, not speculatively during investigation
      - Example: Run analyzer -> identify 5 warnings -> fix all 5 -> THEN run tests (not after each fix)
      - Saves time and reduces context switching
  - **Code Analysis**: Check for issues
    - Command: `flutter analyze`
    - Expected: Zero errors, acceptable warnings
    - **Batch Similar Operations** (Efficiency Tip): Collect all warnings of same type first, then fix in one pass
      - Example: Collect all "unused import" warnings -> fix all imports in one commit
      - Example: Collect all "unused field" warnings -> remove all unused fields in one commit
      - Reduces context switching and ensures consistency
  - **Fix Bugs**: Address any failures
    - Fix code issues
    - Update or add tests as needed
  - **Repeat**: Re-run compile/test cycle until all pass

- [ ] **4.2.1 Create Test Files**
  - For each new feature, create corresponding test file
  - Unit tests: `test/unit/<feature>_test.dart`
  - Integration tests: `test/integration/<feature>_integration_test.dart`
  - Widget tests: `test/widgets/<screen>_test.dart`
  - Minimum coverage: 80% for new code

- [ ] **4.3 Commit During Development**
  - Make focused commits per logical change
  - Commit messages should reference related GitHub issues
  - Format: `<type>: <description> (Issue #N)`
  - Example: `feat: Implement RuleDatabaseStore (Issue #56)`
  - **IMPORTANT: Commit after each task completes** (do not batch all commits to sprint end)
    - Provides intermediate save points for rollback
    - Enables better traceability of when changes were made
    - Smaller commits are easier to review
    - Reduces risk of losing work
  - **Push to remote at least once per session** to backup work
  - **Rationale**: Learned from Sprint 12 - all commits at end creates risk and reduces traceability

- [ ] **4.4 Track Progress**
  - Update GitHub issue comments with task progress
  - Note blockers immediately
  - Document decisions made during implementation
  - **Record actual time spent** (estimate vs. actual):
    - Note start time for each task
    - Note end time for each task
    - Calculate actual duration
    - Compare to estimated duration for calibration
    - Track Claude Code effort time (visible in usage stats)
  - **Document Risk Mitigations**:
    - For each task with Medium or High risk, note mitigation actions taken
    - Example: "Task B risk mitigation: Reviewed API design, validated with existing patterns"
    - Example: "Task C risk mitigation: Benchmarked performance before changes (baseline: 45ms avg)"
  - **Narrate Investigations**:
    - When running diagnostic commands (analyze, tests), explain what you are checking and why
    - Share findings immediately rather than silently making fixes
    - Example: "I'm checking git status to see which files are tracked... Interesting - the lib/ files are not showing up."
  - **Mid-Sprint Checkpoints**:
    - After ~50% task completion, offer brief summary of progress
    - Do NOT ask questions unless critical design or execution clarifications are essential
    - Example: "Completed Tasks A-B (3/5 tasks). Task C in progress. ETA: 1h remaining."
    - Keep user informed without interrupting flow

**[CHECKPOINT]** Before proceeding to Phase 5, re-read Phase 5 items in `docs/SPRINT_CHECKLIST.md`.

---

### **Phase 5: Code Review & Testing**

- [ ] **5.1 Local Code Review**
  - Review all changes for quality and correctness
  - Verify code follows project patterns
  - Check test coverage is adequate
  - Ensure documentation is updated

- [ ] **5.1.1 Automated Code Review** (Sprint 32 improvement - MANDATORY)
  - **Purpose**: Second-pass review by specialized agents catches issues that implementation-mode thinking can miss (convention adherence, subtle bugs, missing tests, silent failures, type design issues)
  - **Required agent**: `pr-review-toolkit:code-reviewer`
    - Runs on current sprint's git diff vs develop
    - Produces categorized findings (HIGH / MEDIUM / LOW)
  - **Optional agents** (run if sprint scope suggests):
    - `pr-review-toolkit:silent-failure-hunter` - when sprint includes error handling, catch blocks, or fallback logic
    - `pr-review-toolkit:comment-analyzer` - when sprint adds significant comments or docstrings
    - `pr-review-toolkit:type-design-analyzer` - when sprint introduces or refactors types
    - `pr-review-toolkit:pr-test-analyzer` - when sprint adds new functionality (test coverage analysis)
  - **Process**:
    1. Run `pr-review-toolkit:code-reviewer` agent with git diff as input
    2. **Related-patterns grep (MECHANICAL - always run)**: Instruct the reviewer to grep the codebase for patterns adjacent to the sprint changes. This is not optional -- it catches cross-cutting gaps that look file-scoped during implementation. Examples:
       - If sprint changes logging in file X, grep for similar `_logger.` sites in other files
       - If sprint adds validation in method Y, grep for other call sites that lack the same validation
       - If sprint changes error handling in class Z, grep for other catch blocks that might need the same treatment
       - If sprint redacts sensitive data in file A, grep for other places the same sensitive variable is logged
       - Include findings in the review output tagged as `POTENTIAL_MISS: similar pattern at <file:line>`
    2a. **Test-assertion sibling sweep for structural-data changes (MECHANICAL - run when applicable)**: When a sprint task changes a piece of structural data that tests assert against (seed count, default rule list size, default settings count, bundled YAML row count, schema field count, etc.), grep `test/` for ALL assertions that reference the old value or the data-producing function and verify each was updated. Do not rely on review judgment alone -- this is a 5-minute mechanical check.
       - Trigger: any sprint task that modifies a function whose return value is asserted by tests with a literal expected value (e.g., `expect(x.length, 5)`, `expect(rules.count, 1638)`)
       - Steps: (1) identify the changed data-producer (function, constant, bundled file); (2) `grep -rn "<producer-name>" test/`; (3) for each match, verify the literal expected value still holds; (4) if the change is structural (count, size, shape), prefer `greaterThan(N)` / `lessThan(N)` assertions over exact literals to make future structural changes non-breaking
       - Why: Sprint 34 F73 changed bundled YAML from 5 monolithic blobs to 1638 individual rows. Three of four sibling assertions in `default_rule_set_service_test.dart` were updated to `greaterThan(100)`; the fourth at line 422 was missed because the reviewer focused on the diff, not on every sibling. Result: post-merge develop test suite went red. Sprint 35 BUG-S34-1 fix.
       - Does not apply to: bug fixes that don't change data shape, refactors with no data change, doc-only updates
    3. **Two-phase review for cross-cutting policies (CONDITIONAL)**: When the sprint delivers a codebase-wide policy (not just a file-scoped change), run the code reviewer a second time with a feature-sweep prompt:
       - Applies when: feature is a cross-cutting policy (logging redaction, error handling pattern, input validation rule, accessibility attribute, etc.)
       - Does not apply when: feature is a single-screen UI change, a single-service implementation, or a bug fix
       - Prompt the reviewer: "The sprint applied <policy> in <files>. Search all of `lib/` for places where the same policy should apply but does not. Produce a list of gaps to fix or backlog."
       - Fix gaps that are <15 min each; backlog larger ones
    4. Address HIGH / CRITICAL findings before PR creation (fix or document why not)
    5. MEDIUM / LOW findings: fix if quick (<15 min), otherwise add to backlog
    6. Record findings and disposition in sprint retrospective
  - **Model**: Requires Opus (review analysis -- see SPRINT_PLANNING.md "Activities Requiring Opus")
  - **Learning (Sprint 32)**: Code reviewer focused on sprint diff missed SEC-17 gaps in adjacent files (background scan worker, UI screens). User manual testing of logs surfaced the gap. Step 2 (mechanical grep) and step 3 (two-phase review) were added to prevent recurrence.

- [ ] **5.2 Run Complete Test Suite**
  - Execute full test suite: `flutter test`
  - Verify all tests pass (not just new ones)
  - Check code analysis: `flutter analyze`
  - Ensure zero errors introduced
  - **(Optional) Efficiency Checkpoint**: If context usage > 60%, suggest user run `/compact` before Phase 6 to refresh context for final PR review phase

- [ ] **5.2.1 Validate Risk Mitigations** (MANDATORY - End-of-Sprint Test Gate)
  - **ALWAYS run full flutter test** before final commit, even for non-code tasks
  - For each high-impact task (Medium/High risk), verify mitigations were executed:
    - **Example - AppLogger migration**: Run app and check logs appear correctly
    - **Example - Testing task**: Generate coverage report to verify coverage metrics
    - **Example - Monitoring script**: Execute script on test suite to verify it works
    - **Example - API changes**: Verify all callers updated and tests cover new behavior
  - **Test New Tools** (MANDATORY when creating test tooling):
    - When creating scripts or tools (like monitor-tests.ps1, validation scripts), validate they work on actual data
    - Do NOT commit tools without running them on real test suite/data
    - Example: Run monitor-tests.ps1 on full test suite to verify output format and accuracy
    - Example: Run YAML validation script on actual rules.yaml to verify it catches errors
  - **Tool Documentation Requirement** (MANDATORY for new scripts/tools):
    - Include example output or demo in comments/README for all new tools
    - Show what success looks like and what failure looks like
    - Example: monitor-tests.ps1 should include sample output in file header comments
    - Example: YAML validation script should show example error messages in README
    - Makes tools self-documenting and easier to use
  - **Cross-Platform Validation** (MANDATORY for scripts/commands):
    - Test scripts/commands on both PowerShell and WSL before committing
    - Verify path separators work cross-platform (use `/` not `\\` in grep patterns)
    - Test PowerShell scripts on Windows PowerShell 5.1 AND PowerShell 7+
    - Document platform-specific requirements in script comments
    - Example: Test monitor-tests.ps1 on both PowerShell versions
    - Example: Verify grep patterns work with forward slashes on Windows
  - Document validation results:
    - "[OK] Task B risk mitigation validated: App runs, logs appear in console with correct keywords"
    - "[OK] Task C risk mitigation validated: Coverage report generated, shows 85% coverage"
    - "[OK] Task D tool validation: monitor-tests.ps1 executed on test suite, correctly identified 3 slow tests"
    - "[OK] Task D cross-platform validation: Script tested on PowerShell 5.1 and PowerShell 7, both work correctly"
  - If validation fails, fix issues before proceeding to Phase 6

- [ ] **5.2.2 Monitor Test Execution (Optional - For Debugging)**
  - Use parallel test monitoring to track long-running tests
  - Script: `mobile-app/scripts/monitor-tests.ps1`
  - Usage: `.\monitor-tests.ps1 -OutputFile test-output.txt`
  - Features:
    - Real-time test progress monitoring
    - Identifies slow tests
    - Logs test execution times
    - Useful for debugging test hangs or performance issues
  - When to use: Tests taking > 2 minutes, or investigating test failures

---

**COMPACT SUGGESTION (Optional for Efficiency)**

After Phase 5.2 all tests pass, context can be compacted for efficiency:
- **Savings**: ~10-15% of context budget (20K-30K tokens)
- **Timing**: Before Phase 6 (PR creation + Review)
- **User Command**: `/compact` (if available in Claude Code)
- **Effect**: Summarizes conversation history, preserves key context, fresh tokens for final phases
- **No Loss**: All sprint work is committed to git, can be easily reviewed

---

#### **PARALLEL TESTING WORKFLOW (Sprint 5+)**

**NEW IN SPRINT 5**: After Phase 5.2 tests pass, implement parallel workflow for efficiency:

1. **Notify User Immediately** (After 5.2 tests pass)
   - Message: "[OK] Code ready for testing in your VSCode repository"
   - Provide working branch name: `feature/YYYYMMDD_Sprint_N`
   - Give user VSCode workspace instructions
   - **Timing**: User can start testing RIGHT NOW

2. **Claude Proceeds to Phase 6 (In Parallel) - MANDATORY**
   - While user tests in VSCode, Claude:
     - **Creates PR (Phase 6.3)** - **REQUIRED, DO NOT SKIP**
       - Target: `develop` branch (NOT main)
       - Title format: "Sprint N: <summary>"
       - Include all commits from feature branch
       - Add sprint summary and task breakdown to PR description
     - Writes documentation
     - Conducts code review analysis
     - Prepares Phase 7 review
   - **[WARNING] CRITICAL**: PR creation is NOT optional - must happen during manual testing
   - **No blocking**: User testing does not wait for PR

   **Why PR Creation is Mandatory During Testing**:
   - Maximizes parallelization (independent work streams)
   - User can review PR when ready (no waiting)
   - All documentation complete when testing finishes
   - Reduces total sprint time by 30-60 minutes
   - No impact on quality (work is independent)

3. **Phase 7 Complete**
   - Claude message: "Sprint review complete, PR ready for approval"
   - User can now review PR with full context
   - All documentation ready for review

4. **Efficiency Gain**
   - **Estimated Savings**: 1-2 hours per sprint
   - **Mechanism**: Parallel execution of independent tasks
   - **Quality**: No reduction - same rigor, better parallelization
   - **User Control**: User can test at own pace while PR is prepared

**Implementation Notes**:
- User can take their time testing (no time pressure)
- Claude work is fully independent (no interdependencies)
- PR includes all Phase 6-7 work when user is ready to review
- Both activities benefit from independence (faster iteration)

- [ ] **5.3 Build App and Prepare for Manual Testing - PARALLEL WITH PHASE 6**

  **CRITICAL**: Claude Code MUST build and run the Windows Desktop App (or target platform) BEFORE declaring the sprint ready for manual testing. User should NOT have to build app themselves. This step is MANDATORY - do NOT skip it.

  **Pre-Testing Checklist** (Claude Code completes BEFORE handing to user):
  - [ ] **5.3.a Build the application**
    - Windows: `cd mobile-app/scripts && .\build-windows.ps1`
    - Android: `cd mobile-app/scripts && .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
    - Monitor build output for errors or warnings
    - If build fails: Fix errors, retry, document any issues
  - [ ] **5.3.b Verify build succeeded** without errors
    - Check build log for compilation errors
    - Note any warnings that may affect functionality
  - [ ] **5.3.c Launch the application**
    - Windows: App auto-launches from build script
    - Android: `adb shell am start -n com.myemailspamfilter/.MainActivity`
    - Verify app opens to expected screen
  - [ ] **5.3.d Sanity check** - quick verification before handing to user
    - App does not crash on launch
    - No database initialization errors in console
    - Key UI elements are visible
    - Console shows expected startup logging
  - [ ] **5.3.e Notify user app is ready**
    - Message: "[OK] App built and running, ready for manual testing"
    - Provide platform details (Windows desktop / Android emulator)
    - Note any warnings or known issues to watch for
  - [ ] **5.3.f Monitor app output** (Claude Code background task)
    - Watch console for errors during user testing
    - Report any crashes or exceptions immediately
    - Capture relevant logs for debugging if issues arise

  **User Manual Testing**:
  - Test on target platform (Android emulator, Windows desktop, etc.)
  - Verify user-facing changes work as expected
  - Check for regressions in existing features
  - Document any issues found

  **Reference**: See `docs/MANUAL_INTEGRATION_TESTS.md` for comprehensive test scenarios

  **Conditional WinWright E2E (Sprint 35 policy)**: If sprint changes touch any UI surface covered by a WinWright script, run the matching script(s) only -- not the full suite. See the When-to-Run table in `docs/TESTING_STRATEGY.md` (Desktop E2E section). Every script must obey the state-restore rule: any rule, safe sender, or setting it creates or modifies must be reverted before the script ends. The full WinWright sweep (F79, HOLD, Issue #240) is on-demand only.

  **NOTE**: Starting Sprint 5, user tests in parallel while Claude completes Phase 6-7
  - **User Ready?**: Yes -> Begin manual testing on running app
  - **Claude Meanwhile**: Proceeds to Phase 6.3 (PR creation) while monitoring app

- [ ] **5.4 Fix Issues from Testing**
  - Address any test failures
  - Fix any regressions discovered
  - Update code if needed
  - Re-run complete test cycle

- [ ] **5.5 Request Feedback (if important)**
  - Identify high-impact changes requiring review
  - Share with user for feedback if architectural decisions made
  - Document feedback received
  - Make any adjustments

**[CHECKPOINT]** Before proceeding to Phase 6, re-read Phase 6 items in `docs/SPRINT_CHECKLIST.md`.

---

## [OK] Approval Gates (Sprint 5+)

**User Approvals**: Only at these 4 points (NOT per-task):

1. **Sprint Plan Approval** (Phase 3)
   - User reviews and approves entire sprint plan
   - **Pre-approves all tasks** when plan is approved
   - No per-task approvals needed during execution
   - Confidence: HIGH (plan was detailed)

2. **Sprint Start** (Phase 3)
   - User confirms: "Ready to begin sprint"
   - Simple confirmation, not detailed approval
   - All task execution pre-approved

3. **Sprint Review Feedback** (Phase 7)
   - User provides feedback on effectiveness, efficiency, process
   - Claude adjusts based on feedback (documentation updates)
   - Not a blocker - more of a feedback collection point

4. **PR Approval** (Phase 6 - After Phase 7)
   - User reviews final PR and code
   - User approves for merge to develop
   - Last formal approval before merge

**Why NOT per-task?**
- All tasks are specified in the plan
- Plan approval means task approval
- Tasks are interdependent (can not skip/change without new plan)
- Per-task approval adds overhead without benefit
- Detailed plan provides sufficient control

**[WARNING] CRITICAL REMINDER FOR CLAUDE**:
- **DO NOT ask for approval between tasks** after sprint plan is approved
- **DO NOT ask "Should I proceed to Task B?"** - this is pre-approved
- **DO NOT ask "Ready for next task?"** - continue autonomously
- **ONLY STOP FOR**: Blockers, errors, scope changes, or Phase 7 review
- Sprint plan approval = approval for ALL tasks in sequence
- Asking for per-task approval violates this workflow and delays execution

**When to Stop Mid-Sprint**:
- Tests fail and cannot fix immediately
- Scope change discovered (requires re-planning)
- Blocked by external dependency
- User explicitly requests pause
- Phase 5.3 Manual Testing complete (proceed to Phase 6 in parallel)
- Phase 7 Sprint Review (REQUIRED)

**Reference**: See `docs/SPRINT_STOPPING_CRITERIA.md` for complete stopping criteria

---

### **Phase 6: Push to Remote & Create PR**

- [ ] **6.1 Finalize All Changes**
  - Ensure all commits are local and staged
  - Verify git status is clean
  - Double-check all tests pass
  - **Single PR Push** (Efficiency Tip for Maintenance Sprints):
    - For maintenance sprints (documentation, testing, cleanup), push all work at end
    - Do NOT push incrementally unless user explicitly requests interim review
    - Reduces PR update overhead and keeps git history clean
    - Exception: Feature sprints may benefit from incremental pushes for user testing
  - **Single-Pass Documentation Updates** (Efficiency Tip):
    - When updating workflow docs, read once and plan all changes before editing
    - Collect all required updates in a list
    - Make all edits in one pass
    - Reduces file reads and ensures consistency

- [ ] **6.1.1 Risk Review Gate** (MANDATORY before push to remote)
  - **Review all sprint risks** documented in sprint plan
  - **Confirm mitigations executed** for each risk:
    - Low risk tasks: Quick verification (tests passed, no regressions)
    - Medium risk tasks: Detailed validation (risk mitigation steps from Phase 5.2.1)
    - High risk tasks: Comprehensive validation (all acceptance criteria met, mitigations proven)
  - **Document risk review summary**:
    - Example: "Risk review complete: 3 tasks reviewed, all mitigations executed and validated"
    - Example: "Task A (Low risk): Tests passed. Task B (Medium risk): API design reviewed and validated. Task C (High risk): Performance benchmarked (45ms->38ms, target met)"
  - **No user approval needed** - this is a Claude-led review to ensure quality
  - If any risk mitigation failed or incomplete, fix before pushing to remote

- [ ] **6.2 Push to Remote**
  - Command: `git push origin feature/YYYYMMDD_Sprint_N`
  - Verify: All commits appear on GitHub branch
  - **CRITICAL**: This step must not be skipped - it ensures work is backed up

- [ ] **6.3 Create Pull Request**
  - Go to GitHub repository
  - **CRITICAL**: Create PR from `feature/YYYYMMDD_Sprint_N` -> `develop` branch (NOT main)
    - **Rule**: All Claude Code PRs target `develop` branch
    - **Why**: `develop` is integration branch; `main` is for user-approved releases only
    - **User Role**: Only user creates PRs to `main` after `develop` is stabilized
  - **PR Title**: `Sprint N: <Feature Name>`
  - **PR Description**: Include:
    - Summary of what is included
    - List of all tasks completed
    - Code quality metrics (lines added, test count, issues found)
    - Related GitHub issues closed
    - Files modified/created
    - Any blockers or concerns
  - Reference all sprint cards: `Closes #XX, #YY, #ZZ`

- [ ] **6.4 Assign Code Review**
  - **@kimmeyh** is auto-assigned via `.github/CODEOWNERS`.
  - **Copilot** is auto-assigned via Repository Ruleset (Settings -> Rules -> Rulesets -> enable "Automatically request Copilot code review"). Note: CODEOWNERS does NOT support the Copilot bot; the Ruleset is the only supported mechanism.
  - Fallback if Ruleset is not configured and Copilot review is desired: `gh pr edit <PR#> --add-reviewer "@copilot"` (requires gh CLI v2.88.0+).
  - Copilot instructions come from `.github/copilot-instructions.md` on the PR base branch (develop).

- [ ] **6.4.1 GitHub Copilot Review Response** (Sprint 32 improvement - if Copilot enabled)
  - **Purpose**: External review layer independent of Claude Code. Catches language-specific issues, convention violations, best-practice gaps.
  - **Trigger**: Wait for Copilot review to complete after PR creation (typically 1-3 minutes).
  - **Known gotcha**: The auto-assignment Ruleset fires on push to an existing PR, not reliably at PR creation. If a PR opens with a single initial commit and Copilot review does not appear within 3-5 minutes, push a follow-up commit or manually request via `gh pr edit <PR#> --add-reviewer "@copilot"`.
  - **Process**:
    1. Fetch Copilot review comments: `gh pr view <PR#> --json reviews,reviewThreads` or review on GitHub UI.
    2. For each Copilot comment, draft a response with these fields:
       - **What**: Copilot's feedback quoted or summarized.
       - **Why**: Context of the code being reviewed.
       - **Impact**: What would change if addressed (similar to mini-ADR).
       - **Recommendation**: One of:
         - `Fix now` (with proposed diff).
         - `Add to backlog` (with backlog item title + rationale).
         - `Not applicable` (with reasoning).
    3. Present all responses to user sequentially (or as a batch table) for decision:
       - **y** = approve recommendation.
       - **n** = decline recommendation (ask for alternative).
       - **comment** = user feedback; revise recommendation.
    4. Accumulate approved responses.
    5. Implement approved "Fix now" items as part of retrospective (Phase 7).
    6. Add approved "Add to backlog" items to ALL_SPRINTS_MASTER_PLAN.md.
    7. Post reply comments to Copilot threads explaining resolution.
  - **Model**: Requires Opus (review analysis -- see SPRINT_PLANNING.md "Activities Requiring Opus").
  - **Skip condition**: If Copilot review is not enabled in repo, skip this step (document in retrospective that Copilot review was unavailable).

- [ ] **6.4.5 Convert PR from draft to ready for review** (Sprint 35 retro addition -- MANDATORY)
  - **Trigger**: Phase 5.2 tests pass, Phase 5.1.1 code review complete, Phase 6.4 Copilot review (if any) handled, all Phase 6 commits pushed
  - **Action**: `gh pr ready <PR-number>` (or via the GitHub UI "Ready for review" button)
  - **Verify**: `gh pr view <PR-number> --json isDraft,mergeable --jq '{isDraft, mergeable}'` -- expect `isDraft: false` and `mergeable: MERGEABLE`
  - **Why this is its own step**: Sprint 35 PR #238 was created as a draft per Phase 3.3.1 (correct -- early visibility) but stayed draft through Phase 6 and Phase 7 close-out because no enumerated step required flipping it. Harold had to surface the issue manually, blocking merge until the draft was converted. The original Phase 3.3.1 note "Convert from draft to ready when Phase 5.2 tests pass" was advisory; this step makes it mandatory.
  - **Skip condition**: PR was created as non-draft (Phase 3.3.1 was skipped). In that case, just confirm `isDraft: false` is already true.

- [ ] **6.5 Notify User**
  - Inform user PR is ready for review
  - Provide summary of sprint results
  - Ask for approval or feedback
  - Note any follow-up items
  - **Verify before notifying**: `gh pr view <PR-number> --json isDraft,mergeable` shows `isDraft: false` and `mergeable: MERGEABLE`. If the PR is still draft, return to Phase 6.4.5 first.

**[CHECKPOINT]** [WARNING] Phase 7 is MANDATORY. Re-read Phase 7 items in `docs/SPRINT_CHECKLIST.md` before proceeding. DO NOT declare sprint complete until Phase 7 is finished.

---

---

**EFFICIENCY CHECKPOINT: Context Refresh (Optional)**

Before Phase 7, if context usage is high (>70%), user can optionally run `/compact`:
- Summarizes prior phases while preserving sprint context
- Refreshes tokens for final review and documentation phases
- No impact on sprint quality (all work is in git)
- Recommended if proceeding to next sprint in same conversation

---

### **Phase 7: Sprint Review & Retrospective (After PR Submitted) - MANDATORY FOR ALL SPRINTS**

[WARNING] **IMPORTANT**: Phase 7 is **MANDATORY and REQUIRED** for all sprints. Do NOT skip this phase.

**Why Phase 7 is Critical**:
- Captures lessons learned for future sprint improvements
- Provides user feedback for process optimization
- Documents architectural decisions and tradeoffs
- Identifies potential issues early
- Builds team knowledge base

#### **Pre-Review: Windows Desktop Build & Test (REQUIRED)**

Before conducting sprint review, build and test the Windows desktop app:

- [ ] **7.1 Build and Run Windows Desktop App**
  - **Purpose**: Verify Windows desktop build succeeds before PR approval
  - **Reference**: Manual Integration Tests - `docs/MANUAL_INTEGRATION_TESTS.md`
  - **Build Command**:
    ```powershell
    cd mobile-app/scripts
    .\build-windows.ps1
    ```
  - **What Happens**:
    - Clean Flutter rebuild (removes old artifacts)
    - Secrets injected from `secrets.dev.json`
    - Windows app compiled for debug mode
    - App launches automatically
    - Console displays detailed logging
  - **Verification Checklist**:
    - [ ] Build completes without errors
    - [ ] App launches successfully
    - [ ] No database initialization errors
    - [ ] No console warnings (FFI, credentials, auth)
    - [ ] Key features work as expected (accounts, scanning, results)
  - **If Build Fails**:
    - Document the error with full console output
    - Fix the issue or create follow-up GitHub issue
    - Do NOT proceed to PR approval until build succeeds
  - **Next Step**: After successful build, proceed to 7.2

- [ ] **7.2 Offer Sprint Review (REQUIRED)**
  - Ask user: "Would you like to conduct a sprint review before approving the PR? (Recommended)"
  - Sprint review is MANDATORY (not optional) but can be conducted quickly
  - User can provide brief feedback or skip answers
  - Timing: Conduct while user reviews PR, before merge
  - **DO NOT PROCEED TO MERGE WITHOUT COMPLETING PHASE 7**

- [ ] **7.3 Gather Sprint Retrospective Feedback (MANDATORY -- 4 ROLES x 14 CATEGORIES)**

  [CRITICAL] **A Sprint Retrospective is NEVER considered complete unless all 14 categories are addressed by all 4 roles. Missing roles or categories = retrospective is INCOMPLETE = sprint is NOT complete.**

  **The 4 mandatory roles** (in this single-developer project, Harold wears 3 of the 4 hats; Claude Code provides the 4th):
  1. **Product Owner** -- business value, user-facing impact, scope/priority, backlog implications
  2. **Scrum Master** -- process adherence, ceremony quality, blockers, team health, workflow friction
  3. **Lead Developer** -- technical quality, code/architecture, engineering decisions, technical debt
  4. **Claude Code Development Team** -- execution-side observations: where prompts/instructions were ambiguous, where tooling helped or hurt, where automation could improve

  Even when one human person provides 3 of the 4 perspectives, each role MUST be addressed separately because each looks through a different lens. Empty/silent rows are NOT acceptable. If a role has nothing to say, that role must explicitly write `No issues -- expectations met.` -- but the role MUST be addressed.

  **The 14 mandatory categories** (gather feedback from all 4 roles for EACH):
  1. **Effective while as Efficient as Reasonably Possible** -- Did we deliver the right outcome with the least reasonable effort? (Combines former Effectiveness/Efficiency + Sprint Execution.)
  2. **Testing Approach**
  3. **Effort Accuracy**
  4. **Planning Quality**
  5. **Model Assignments**
  6. **Communication**
  7. **Requirements Clarity**
  8. **Documentation**
  9. **Process Issues**
  10. **Risk Management**
  11. **Next Sprint Readiness**
  12. **Architecture Maintenance**
  13. **Minor Function Updates for the Next Sprint Plan** -- Small enhancements/fixes uncovered this sprint that should be folded into the NEXT sprint's plan as inline scope additions.
  14. **Function Updates for the Future Backlog** -- Larger or non-urgent items that should be added to `ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates".

  **Reference**: See `docs/SPRINT_RETROSPECTIVE.md` for full category definitions, per-role example feedback, and the verbatim feedback template to copy into `docs/sprints/SPRINT_N_RETROSPECTIVE.md`.

  **[CRITICAL] Phase 7.3 -- 7.6 Retrospective Protocol** (Updated Sprint 34, in response to a process violation):

  The retrospective is a 7-step protocol mapped onto Phases 7.3 through 7.7. Steps must run in order. Do NOT collapse, reorder, or skip steps to "save time" -- the velocity bias is exactly the trap that caused the Sprint 34 violation.

  **Roles**: Harold wears Product Owner / Scrum Master / Lead Developer (3 of 4). Claude is the Claude Code Development Team (4th). Harold's 3 roles produce one set of feedback (combined or separate, his choice). Claude produces the 4th separately.

  **Categories**: All 14, addressed by both feedback sets. Empty/silent rows NOT acceptable -- write `No issues -- expectations met.` if a role has nothing to say for a category. See `docs/SPRINT_RETROSPECTIVE.md` for category definitions.

  ---

  **STEP 1 (Phase 7.3) -- Send the prompt to Harold**

  Claude sends EXACTLY this message to Harold (substituting N) and then proceeds to Step 2. Do NOT write content into `docs/sprints/SPRINT_N_RETROSPECTIVE.md` yet.

  > Sprint N is ready for the Phase 7 retrospective. Per `docs/SPRINT_RETROSPECTIVE.md` Completeness Validation Gate, the Product Owner / Scrum Master / Lead Developer feedback for all 14 categories must come from you. While you write yours, I will draft my Claude Code Development Team feedback to `docs/sprints/drafts/SPRINT_N_RETROSPECTIVE_claude_draft.md`. After you reply I will combine both sets, display the combined retrospective for your review, propose improvements, and ask you for now-vs-backlog decisions per the Phase 7 protocol in `docs/SPRINT_EXECUTION_WORKFLOW.md`.
  >
  > Please provide your feedback for the 14 categories. You may answer one role at a time, one category at a time, in a single message, or however suits you. Combined PO/SM/Lead lines per category are acceptable. If a role has nothing to say for a category, write `No issues -- expectations met.` -- but every (role, category) pair must be addressed. Include any improvement suggestions you want considered for "apply now" or "add to backlog".
  >
  > The 14 categories: (1) Effective while as Efficient as Reasonably Possible; (2) Testing Approach; (3) Effort Accuracy; (4) Planning Quality; (5) Model Assignments; (6) Communication; (7) Requirements Clarity; (8) Documentation; (9) Process Issues; (10) Risk Management; (11) Next Sprint Readiness; (12) Architecture Maintenance; (13) Minor Function Updates for the Next Sprint Plan (carry-ins); (14) Function Updates for the Future Backlog.

  **STEP 2 (Phase 7.3 continued) -- Generate Claude's draft in parallel while Harold writes his**

  After sending the Step 1 prompt, Claude immediately drafts its Claude Code Development Team feedback for all 14 categories into `docs/sprints/drafts/SPRINT_N_RETROSPECTIVE_claude_draft.md`. The draft file has a header marking it as Claude-authored. The draft is for Step 3 use only -- it is never substituted for Harold's input and never written into the official retrospective file.

  This step runs in parallel with Harold's writing time. It does NOT proceed to Step 3 until Harold replies in Step 1.

  **STEP 3 (Phase 7.4) -- Record Harold's feedback verbatim**

  Once Harold replies:
  1. Open `docs/sprints/SPRINT_N_RETROSPECTIVE.md` and paste the 4-role x 14-category template from `docs/SPRINT_RETROSPECTIVE.md`.
  2. Write Harold's exact words into each (role, category) cell. Do NOT paraphrase. Do NOT "improve" wording. Combined PO/SM/Lead lines are acceptable if that is how Harold provided them -- record them as he wrote them.
  3. Copy the Claude Code Development Team lines for each category from the Step 2 draft into the official retrospective file.
  4. For Categories 13 and 14: if Harold answered "none", record that verbatim. Do NOT auto-add Claude's predicted items; if Claude has Category 14 candidates, surface them in Step 5 (improvement proposals) for Harold to decide on.

  **Phase 7.3/7.4 EXIT GATE -- Completeness Validation (MANDATORY)**:
  - [ ] All 14 categories present
  - [ ] All 4 roles addressed in each category (Harold's combined PO/SM/Lead line counts as 3 roles if he chose combined format)
  - [ ] No `[feedback]` placeholder text remaining
  - [ ] Harold's feedback recorded verbatim, not paraphrased

  If ANY box unchecked, Phase 7 is INCOMPLETE. Do NOT proceed to Step 4.

  **STEP 4 (Phase 7.4.5) -- Combine and display the retrospective**

  Display the combined retrospective in chat using this format (no border lines, header line OK, fields OK, wrapping within fields OK, spacing between fields OK):

  ```
  ## Sprint N Retrospective -- Combined Feedback

  ### 1. Effective while as Efficient as Reasonably Possible
  Product Owner / Scrum Master / Lead Developer (Harold): <verbatim>
  Claude Code Development Team: <verbatim>

  ### 2. Testing Approach
  Product Owner / Scrum Master / Lead Developer (Harold): <verbatim>
  Claude Code Development Team: <verbatim>

  ... (all 14 categories) ...
  ```

  Display in chat so Harold sees both sets together before reviewing improvement proposals. The official `docs/sprints/SPRINT_N_RETROSPECTIVE.md` already contains this same content from Step 3 -- the chat display is a presentation step, not a re-write.

  **STEP 5 (Phase 7.5) -- Propose improvements from the combined feedback**

  Claude reviews the combined retrospective and proposes specific improvements. Improvements may be of any type: process, code, tests, architecture, documentation, tooling.

  Sources for proposals:
  - Issues raised in any of the 14 categories by Harold's feedback
  - Issues raised by Claude's draft feedback
  - Any "proposed improvements" Harold included in his Step 1 reply
  - Cross-cutting themes that emerge when both feedback sets are read together

  Format each proposal:
  - **Title**: short summary
  - **Source**: which category / which role surfaced it
  - **Type**: process / code / tests / architecture / docs / tooling
  - **Effort**: rough estimate (S/M/L or hours)
  - **Recommendation**: apply now or add to backlog (with one-sentence rationale)

  Display all proposals in chat for Harold's review. Do NOT auto-apply any of them.

  **STEP 6 (Phase 7.6) -- Harold decides: apply now or add to backlog**

  Claude asks Harold for an explicit decision on each proposal. Default expectation (per Sprint 34 retro guidance): "almost all are faster to do now before the next sprint -- exceptions are directed to backlog."

  Prompt format:
  > For each proposal above, please indicate:
  > (a) apply now in this sprint
  > (b) add to backlog for a future sprint
  > (c) skip / no change
  >
  > A blanket "all now" or "all backlog" answer is acceptable if you want to apply the same disposition across all proposals.

  Wait for Harold's reply. Record his decisions inline in the retrospective document under a new "Improvement Decisions" section.

  **STEP 7 (Phase 7.7) -- Apply approved improvements as part of the current sprint**

  For each proposal Harold marked "apply now":
  - Implement it as additional commits on the existing sprint branch (not a follow-up PR)
  - This may include: doc updates, code changes, test additions, architecture doc updates, hookify rules, memory entries, etc.
  - Re-run analyzer + tests after code/test changes
  - Update CHANGELOG.md if user-facing
  - Push commits to the existing PR branch (PR #N still tracks the sprint)

  For each proposal Harold marked "add to backlog":
  - Add as a numbered F-item to `docs/ALL_SPRINTS_MASTER_PLAN.md` HOLD section (or appropriate priority tier)
  - Include detail section if non-trivial
  - Cross-reference the originating retrospective and category

  For each proposal Harold marked "skip":
  - Note in the retrospective "Improvement Decisions" section that it was reviewed and declined; no further action.

  After all approved improvements are applied and committed, proceed to the remaining Phase 7.7 mandatory completion updates (CHANGELOG entry for sprint summary if not already present, ALL_SPRINTS_MASTER_PLAN.md Last Completed Sprint update, Past Sprint Summary table row, etc.) and then to Phase 7.8.

  ---

  **Violation handling**: If you discover you have written Harold-role feedback yourself before receiving his input, OR you have skipped the combine-and-display step, OR you auto-applied improvements without Harold's now-vs-backlog decision: STOP immediately, move any incorrectly-authored content to `docs/sprints/drafts/`, mark the sprint Phase 7 as INCOMPLETE in `docs/ALL_SPRINTS_MASTER_PLAN.md`, and restart at Step 1. Do not attempt to retroactively justify the drafted content.

- [ ] **7.4 Record Harold's Feedback Verbatim** (was "Provide Claude Feedback" -- Claude's feedback is now drafted in 7.3 Step 2)
  - Open `docs/sprints/SPRINT_N_RETROSPECTIVE.md` and paste the 14-categories template
  - Record Harold's exact words per category (combined PO/SM/Lead line acceptable)
  - Copy Claude Code Development Team lines from the Step 2 draft
  - See Phase 7.3 Step 3 above for full instructions

- [ ] **7.4.1 Architecture Compliance Check** (MANDATORY - Added Sprint 30)
  - **Purpose**: Verify sprint code changes are consistent with documented architecture. Second safety net after Phase 3.6.1.
  - **Check**: Review all code changes in this sprint against:
    - `docs/ARCHITECTURE.md` -- Are new/changed components, services, screens, database tables reflected?
    - `docs/ARSD.md` -- Are design specifications still accurate after sprint changes?
    - `docs/adr/*.md` -- Were any ADR decisions violated or extended without documentation?
  - **Determine**:
    - (a) Do architecture docs need updating to reflect sprint changes? If yes, add to Phase 7.7 updates.
    - (b) Did code changes diverge from approved architecture without prior approval? If yes, flag for Scrum Master review -- code may need reverting or architecture may need formal update.
  - **If no code changes** (documentation/analysis sprint): Note "No code changes -- architecture compliance N/A" and proceed
  - **Rationale**: Catches architecture drift that slips through planning. Ensures docs stay current with every sprint. (Learned Sprint 30)

- [ ] **7.4.5 Combine and Display Retrospective** (Added Sprint 34, Step 4 of Retrospective Protocol)
  - Display the combined retrospective in chat per the format in Phase 7.3 Step 4 above
  - No border lines (header line OK, fields OK, wrapping within fields OK, spacing between fields OK)
  - Both Harold's and Claude's feedback shown together per category
  - This is a presentation step -- the official retrospective file already contains the same content from Step 3

- [ ] **7.5 Propose Improvements from Combined Feedback** (Updated Sprint 34, Step 5 of Retrospective Protocol)
  - Review the combined retrospective for improvement opportunities
  - Sources: any of the 14 categories from either Harold or Claude, plus Harold's explicit suggestions, plus cross-cutting themes
  - Improvements may be of ANY type: process, code, tests, architecture, documentation, tooling
  - Format per proposal: Title / Source / Type / Effort / Recommendation
  - Display all proposals in chat for Harold's review -- do NOT auto-apply

- [ ] **7.6 Harold Decides: Apply Now or Add to Backlog** (Updated Sprint 34, Step 6 of Retrospective Protocol)
  - Ask Harold for explicit decision on each proposal: (a) apply now, (b) add to backlog, (c) skip
  - Default expectation: most improvements are faster to do now before the next sprint
  - Blanket disposition (all now / all backlog) acceptable
  - Record Harold's decisions in retrospective document under "Improvement Decisions" section
  - Wait for Harold's reply before proceeding to 7.7

- [ ] **7.7 Apply Approved Improvements + Update Documentation** (Updated Sprint 34, Step 7 of Retrospective Protocol)

  **Step 7a: Apply "apply now" improvements to the current sprint**:
  - For each Step 6 proposal Harold marked "apply now":
    - Implement as additional commits on the existing sprint branch (NOT a follow-up PR)
    - Improvement type can be: process docs, code, tests, architecture, hookify rules, memory entries, tooling
    - Re-run `flutter analyze` and `flutter test` after any code/test changes
    - Update CHANGELOG.md if user-facing
    - Push commits to the existing PR branch (PR #N still tracks the sprint)
  - For each Step 6 proposal Harold marked "add to backlog":
    - Add as a numbered F-item to `docs/ALL_SPRINTS_MASTER_PLAN.md` HOLD section (or appropriate priority tier)
    - Include detail section if non-trivial
    - Cross-reference originating retrospective and category
  - For each Step 6 proposal Harold marked "skip":
    - Note in retrospective "Improvement Decisions" section that it was reviewed and declined
    - No further action

  **Step 7b: Mandatory sprint completion updates**:
  - [ ] **Update CHANGELOG.md** (MANDATORY - see Step 3 in "After Sprint Approval")
    - Add entry under `## [Unreleased]` section
    - Format: `### YYYY-MM-DD` with sprint summary
    - Include all user-facing changes from sprint
    - Reference PR number: `(PR #NNN)`
    - **Format Reference**: See CLAUDE.md Changelog Policy for detailed format

  - [ ] **Update ALL_SPRINTS_MASTER_PLAN.md** (MANDATORY - follow Maintenance Guide rules)
    - Update "Last Completed Sprint" section with Sprint N details (objective, tasks, PR link)
    - Add row to "Past Sprint Summary" table
    - Remove completed items from "Next Sprint Candidates" table
    - Remove completed feature/bug detail sections from "Feature and Bug Details"
    - Update priorities or add new items discovered during sprint
    - **Reference**: See "Maintenance Guide" at top of ALL_SPRINTS_MASTER_PLAN.md for all rules

  - [ ] **Create Sprint Retrospective Document** (MANDATORY)
    - Create `docs/sprints/SPRINT_N_RETROSPECTIVE.md`
    - Use template from `docs/SPRINT_RETROSPECTIVE.md`
    - Record feedback, improvements, and action items
    - **TIMING**: Do NOT create the retrospective document until AFTER manual testing (Phase 5) and all testing feedback rounds are complete. Creating it before testing produces stale metrics and incomplete scope. (Learned Sprint 19)

  - [ ] **Create Sprint Summary Document** (MANDATORY - can be deferred to Phase 3.2.1 of next sprint)
    - Create `docs/sprints/SPRINT_N_SUMMARY.md`
    - Content: Sprint objective, tasks completed, deliverables, estimated vs actual duration, key decisions, lessons learned
    - **If created now**: Use current sprint context (most accurate)
    - **If deferred**: Created in Phase 3.2.1 of Sprint N+1 from CHANGELOG, git history, and retrospective

  - [ ] **Update ARCHITECTURE.md** (CONDITIONAL - when architecture changes occur)
    - If sprint introduced new components, patterns, or architectural changes
    - Update relevant sections of `docs/ARCHITECTURE.md`
    - Skip if sprint was purely bug fixes, documentation, or minor UI changes

- [ ] **7.8 Summarize Review Results**
  - Provide summary of review findings
  - List which improvements were selected for implementation
  - Confirm PR is ready for user approval

- [ ] **7.9 Proactive Next Steps** (MANDATORY after sprint completion)
  - After sprint completion, present 3 options to user:
    1. **Sprint Review**: Conduct formal retrospective (if not already done in Phase 7)
    2. **Start Next Sprint**: Begin planning and execution of next sprint from ALL_SPRINTS_MASTER_PLAN.md
    3. **Ad-hoc Work**: Work on unplanned tasks or investigations outside sprint framework
  - **Template**:
    ```
    Sprint N complete! What would you like to do next?

    1. [CHECKLIST] Sprint Review (if not already conducted)
    2. Start Sprint N+1 (see ALL_SPRINTS_MASTER_PLAN.md for details)
    3. [CONFIG] Ad-hoc work (tasks outside sprint framework)

    Please let me know your preference.
    ```
  - Do NOT assume what user wants - always present options
  - This keeps momentum and clarifies next steps

---

## Branch Naming Convention

Format: `feature/<YYYYMMDD>_Sprint_<N><optional_suffix>`

**Examples**:
- `feature/20260124_Sprint_2` - Basic Sprint 2
- `feature/20260124_Sprint_2_Rule_Migration` - Sprint 2 focused on rule migration
- `feature/20260124_Sprint_3_Database_Cleanup` - Sprint 3 for database cleanup

**Components**:
- `feature/` - Branch type (always feature for sprint work)
- `YYYYMMDD` - Date sprint started (ISO 8601 format)
- `Sprint_<N>` - Sprint number (Sprint_1, Sprint_2, etc.)
- `<optional_suffix>` - Optional description of main focus area

---

## GitHub PR Template for Sprint PRs

```markdown
## Summary
Brief description of what this sprint delivers.

## What's Included

### Task A: <Task Name>
- Commit: <hash>
- Files: List of files
- Description: What was done

### Task B: <Task Name>
- Commit: <hash>
- Files: List of files
- Description: What was done

### Task C: <Task Name>
- Commit: <hash>
- Files: List of files
- Description: What was done

## Code Quality
- [OK] <N> tests passing (was <M> before)
- [OK] Zero code analysis issues
- [OK] <X> lines of code added
- [OK] <Y> lines of code removed/refactored

## Related GitHub Issues
- Closes #XX (Task A)
- Closes #YY (Task B)
- Closes #ZZ (Task C)

## Test Coverage
- Unit tests: <N> new tests
- Integration tests: <N> scenarios covered
- Manual testing: <list of scenarios tested>

## Files Modified/Created

### Created (<N> files):
- lib/core/storage/file.dart (X lines)
- test/unit/file_test.dart (Y lines)

### Modified (<N> files):
- pubspec.yaml
- lib/adapters/storage/app_paths.dart

## Next Steps
- [ ] Code review
- [ ] Manual integration testing
- [ ] Merge to develop when approved
- [ ] Begin Sprint <N+1>

Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Testing Cycle Details

### Compilation
```bash
# Windows desktop
cd mobile-app
flutter build windows

# Android
./scripts/build-apk.ps1

# Run app
flutter run
```

### Testing
```bash
# All tests
flutter test

# Specific test file
flutter test test/unit/rule_evaluator_test.dart

# With coverage
flutter test --coverage
```

### Code Quality
```bash
# Analysis
flutter analyze

# Format check
dart format --set-exit-if-changed lib/
```

---

## Common Issues & Resolutions

### Issue: Tests fail after changes
**Resolution**:
1. Identify failing test
2. Understand what changed
3. Update test or fix implementation
4. Re-run tests

### Issue: Code analysis shows new warnings
**Resolution**:
1. Fix the warning (do not ignore)
2. Add proper imports/types
3. Re-run analysis to verify

### Issue: Need to add tests
**Resolution**:
1. Create test file in appropriate directory
2. Write tests to cover new code paths
3. Run full test suite to verify

### Issue: Blocking bug discovered during Sprint
**Resolution**:
1. Document in GitHub issue
2. Assess impact on sprint scope
3. Either: (a) Add to sprint and adjust timeline, OR (b) Create follow-up issue for next sprint
4. Notify user immediately

---

## Success Criteria for Sprint Completion

### Before PR Submission (Phase 5 Complete)
- [OK] All sprint cards completed
- [OK] All tests passing (100% pass rate)
- [OK] Zero code analysis errors
- [OK] Local code review completed
- [OK] No blockers remaining

### When PR Submitted (Phase 6 Complete)
- [OK] All commits pushed to remote
- [OK] PR created to `develop` branch (NOT main - critical requirement)
- [OK] PR fully documented (see GitHub PR template)
- [OK] Sprint card issues referenced in PR description (Closes #XX, #YY, #ZZ)
- [OK] User notified and ready for review

### When PR Approved (Phase 7 Complete)
- [OK] Sprint review COMPLETED (MANDATORY - see Phase 7 above)
- [OK] User feedback collected
- [OK] Improvement suggestions documented
- [OK] Agreed-upon improvements applied to documentation
- [OK] Ready for merge

**[WARNING] CRITICAL**: Phase 7 must be completed BEFORE merge. This is not optional.

### After Merge (Cleanup Complete)
- [OK] PR merged to develop
- [OK] Feature branch deleted (locally and remote)
- [OK] All related GitHub issues closed
- [OK] Sprint retrospective documented (if applicable)
- [OK] Ready to begin next sprint

---

## After Sprint Approval - Merge & Cleanup

Once user approves PR:

1. **Merge to develop**
   - PR approved and merged via GitHub
   - Branch deleted on remote (automatic or manual)
   - Local branch deleted: `git branch -d feature/YYYYMMDD_Sprint_N`

2. **Close All Related GitHub Issues**
   - Find all sprint card issues referenced in PR (e.g., #60, #61)
   - Close each issue: `gh issue close #N --reason "completed"`
   - Verify all sprint cards show "Closed" status on GitHub
   - **Note**: GitHub auto-closes issues when PR is merged if PR mentions "Closes #N", but verify all are closed
   - **Review ALL open issues**: Run `gh issue list --state open` and close any that were resolved by this sprint or prior work but not yet closed

3. **Update Sprint Completion Documentation** (MANDATORY)

   - [ ] **Update CHANGELOG.md** (MANDATORY)
     - Add entry under `## [Unreleased]` section
     - Format: `### YYYY-MM-DD` with sprint summary
     - Include all user-facing changes from sprint
     - Reference PR number: `(PR #NNN)`
     - See CLAUDE.md Changelog Policy for format

   - [ ] **Update ALL_SPRINTS_MASTER_PLAN.md** (MANDATORY)
     - Navigate to Sprint N section
     - Add completion metadata:
       ```markdown
       ### Sprint N: [Title] (COMPLETED - YYYY-MM-DD)
       - Estimated Duration: Xh
       - Actual Duration: Yh (Z% variance)
       - Model Used: Haiku/Sonnet/Opus
       - Tasks Completed: N/N
       - Lessons Learned:
         - [Key lesson 1]
         - [Key lesson 2]
       - Improvements Implemented:
         - [Improvement 1] -> Updated [file]
       ```
     - Update future sprint dependencies if needed
     - Update risk assessments based on lessons learned

   - [ ] **Create Sprint Retrospective Document** (if review conducted)
     - Create `docs/sprints/SPRINT_N_RETROSPECTIVE.md`
     - Record what went well, what could improve
     - Document improvements implemented
     - Link to PR for code artifacts
     - See `docs/SPRINT_RETROSPECTIVE.md` for template

4. **Clean up feature branch (OPTIONAL - User Managed)**
   - Branch cleanup is optional and user-managed
   - Do NOT auto-delete branch after merge
   - User will manually delete when ready: `git branch -d feature/YYYYMMDD_Sprint_N`
   - Remote cleanup also user-managed: `git push origin --delete feature/YYYYMMDD_Sprint_N`
   - Keeps branch available for reference if needed

---

**Version**: 2.0
**Last Updated**: February 16, 2026
**Updates in 2.0**:
- Renumbered all phases for clarity and extensibility (Issue #160)
- Phase -1 -> Phase 1 (Backlog Refinement)
- Phase 0 -> Phase 2 (Sprint Pre-Kickoff)
- Phase 1 -> Phase 3 (Sprint Kickoff & Planning)
- Phase 2 -> Phase 4 (Sprint Execution)
- Phase 3 -> Phase 5 (Code Review & Testing)
- Phase 4 -> Phase 6 (Push to Remote & Create PR)
- Phase 4.5 -> Phase 7 (Sprint Review & Retrospective)
- Added Phase Numbering Reference table
- All sub-phase numbers updated consistently (e.g., 4.5.0 -> 7.1, 4.5.8 -> 7.9)

**Updates in 1.2**:
- Enhanced Phase 5.3 pre-testing checklist with explicit build/run steps (Issue #115)
- Added step-by-step sub-items: build, verify, launch, sanity check, notify, monitor
- Clarified Claude Code responsibilities for app preparation before user testing
- Added platform-specific build commands (Windows and Android)

**Updates in 1.1**:
- Added Phase 7: Sprint Review process (user feedback, improvements, documentation)
- Added Phase 2: Pre-Sprint Verification checklist (prevents missed steps on continuation)
- Added "After Sprint Approval - Merge & Cleanup" section
- Emphasized "Push to Remote" as CRITICAL step with note about preventing missed steps
- Updated Success Criteria to show progression through phases

**Reference**: Based on Sprint 1-16 execution experience
