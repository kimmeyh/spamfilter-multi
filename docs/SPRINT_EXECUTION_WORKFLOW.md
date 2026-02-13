# Sprint Execution Workflow

This document describes the step-by-step process for executing sprints in the spamfilter-multi project, based on actual experience from Sprint 1.

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** (this doc) | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## [WARNING] CRITICAL REMINDER: Phase 4.5 Sprint Review is MANDATORY

**IMPORTANT**: Phase 4.5 (Sprint Review) is a REQUIRED step for all sprints. It is not optional.

**What to Remember**:
1. Do NOT skip Phase 4.5 - it must be conducted after PR is submitted
2. Phase 4.5 provides critical feedback for continuous improvement
3. User can provide quick feedback - it does not take long
4. Phase 4.5 must complete BEFORE merging PR to develop
5. Documentation improvements from Phase 4.5 are applied to feature branch

**Location**: See Phase 4.5 section below (after Phase 4: Push to Remote & Create PR)

---

## Sprint Execution Checklist

### **Phase -1: Backlog Refinement** (OPTIONAL - On-Demand)

Backlog refinement is conducted **when requested by Product Owner**, not before every sprint.

- [ ] **-1.1 Check if Refinement is Requested**
  - Product Owner explicitly requests backlog refinement
  - Skip to Phase 0 if refinement not requested
  - Quick priority changes can be handled during Phase 1 without full refinement

- [ ] **-1.2 Conduct Refinement Session** (30-60 minutes, timeboxed)
  - **Prepare**: Read current backlog state from ALL_SPRINTS_MASTER_PLAN.md and ISSUE_BACKLOG.md
  - **Review**: Scan all items, identify stale entries (over 3 sprints old)
  - **Prioritize**: Re-order based on value, effort, and risk
  - **Estimate**: Update estimates with velocity calibration from recent sprints
  - **Add**: Capture newly identified work items
  - **Cleanup**: Remove obsolete items, update dependencies

- [ ] **-1.3 Document Refinement Results**
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

### **Phase 0: Sprint Pre-Kickoff** [WARNING] CRITICAL PREREQUISITE

- [ ] **0.0.1 Cache Sprint Context** (Optimization)
  - Read ALL_SPRINTS_MASTER_PLAN.md ONCE
  - Cache in memory:
    - Sprint N (current) details: Objective, tasks, acceptance criteria, risks
    - Sprint N-1 (previous) details: For summary creation in Phase 1.2.1
  - No re-reading needed until Phase 4.5.6 (updates)
  - **Efficiency Gain**: Reduces file reads from 3 to 1 per sprint

---

- [ ] **0.1 Verify Previous Sprint is Merged**
  - Confirm previous sprint PR is merged to `develop`
  - Command: `git log develop --oneline -1` should show last sprint commits
  - Previous feature branch is deleted locally and remote

- [ ] **0.2 Verify All Sprint Cards Are Closed**
  - Run: `gh issue list --label sprint --state open`
  - All issues from previous sprint should be CLOSED
  - If any open, manually close them: `gh issue close #N --reason "completed"`

- [ ] **0.3 Ensure Working Directory is Clean**
  - Command: `git status` should show "nothing to commit, working tree clean"
  - No uncommitted changes left over from previous sprint
  - All work is pushed to remote (see 4.2)

- [ ] **0.4 Verify Develop Branch is Current**
  - Command: `git checkout develop`
  - Command: `git pull origin develop`
  - Local develop branch matches remote
  - Ready to create new sprint feature branch

- [ ] **0.5 Now Proceed to Phase 1: Sprint Kickoff & Planning**
  - Create new feature branch for next sprint
  - Create sprint cards
  - Begin execution

---

### **Phase 1: Sprint Kickoff & Planning**

- [ ] **1.1 Determine Next Sprint Number**
  - Last completed sprint: Sprint 1
  - Next sprint: Sprint 2
  - Pattern: Increment by 1

- [ ] **1.2 Review Sprint Plan**
  - Read ALL_SPRINTS_MASTER_PLAN.md
  - Identify Sprint N in "Current Sprint" or "Next Sprint" section
  - Verify scope, tasks, and acceptance criteria
  - Note any changes needed based on previous sprint learnings

- [ ] **1.2.1 Create Sprint Summary for Previous Sprint** (Background Process - MANDATORY)
  - **When**: During planning for Sprint N+1, create SPRINT_<N>_SUMMARY.md for completed Sprint N
  - **Purpose**: Archive historical sprint details from ALL_SPRINTS_MASTER_PLAN.md
  - **Template**: Use structure from SPRINT_RETROSPECTIVE.md or previous SPRINT_<N>_SUMMARY.md files
  - **Content Sources** (in priority order):
    1. SPRINT_<N-1>_RETROSPECTIVE.md (if exists from Phase 4.5.6)
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
    | N | SPRINT_N_SUMMARY.md | [OK] Complete | ~Xh (MMM DD-DD, 2026) |
    ```
  - This keeps ALL_SPRINTS_MASTER_PLAN.md focused on current/future work while preserving history

- [ ] **1.3 Branch Management**
  - Check if repository is in a PR branch
  - If yes: Wait for PR approval/merge, then switch to main/develop
  - Create new feature branch: `feature/<YYYYMMDD>_Sprint_<N><optional_suffix>`
  - Example: `feature/20260124_Sprint_2` or `feature/20260124_Sprint_2_Rule_Migration`
  - Switch repository to new branch: `git checkout -b <branch-name>`

- [ ] **1.3.1 Create Draft PR Immediately** (RECOMMENDED - Early Visibility)
  - **When**: Immediately after branch creation and sprint plan approval
  - **Why**: Provides visibility into sprint progress from the start
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
    *This PR will be updated as tasks complete. Mark ready for review when Phase 3 testing passes.*
    ```
  - **Note**: Convert from draft to ready when Phase 3.2 tests pass

- [ ] **1.4 Create GitHub Sprint Cards** (MANDATORY - Never Skip)
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

- [ ] **1.4.1 Verify Issue Accuracy** (before finalizing sprint cards)
  - For bug/fix issues: Verify the issue still exists (may have been fixed in previous sprint)
  - For test-related issues: Run `flutter test` to confirm current test state
  - For feature issues: Verify feature does not already exist in codebase
  - **If issue is already resolved**: Close the issue, do not include in sprint
  - **If issue description is outdated**: Update description to reflect current state
  - **Rationale**: Prevents wasted effort on already-resolved issues (learned from Sprint 12: Issue #119)

- [ ] **1.5 Verify All Sprint Cards Are OPEN**
  - Before execution, verify all sprint cards exist and are in OPEN state
  - Command: `gh issue list --label sprint --state closed`
  - If any closed cards exist for this sprint: Re-open them
  - Reason: Closed cards block execution (from Sprint 1 learning: Issue #52)
  - Update: Switch all closed sprint cards to OPEN state

- [ ] **1.6 Verify Sprint Readiness**
  - All sprint cards created, linked, and in OPEN state
  - No blocking issues or dependencies unresolved
  - Model assignments reviewed and finalized
  - Acceptance criteria clear, testable, and QUANTIFIABLE (see SPRINT_PLANNING.md Best Practices)
  - **VERIFY**: Sprint plan acceptance criteria match GitHub issue criteria EXACTLY (copy from issues)
  - **VERIFY**: All acceptance criteria are quantifiable and measurable (no subjective terms)
  - Dependencies on previous sprints verified as complete
  - Risk assessments documented for all tasks (even if "Low - maintenance work")
  - Effort estimates included for all tasks (with 20% buffer for manual testing tasks)

- [ ] **1.7 CRITICAL: Plan Approval = Task Execution Pre-Approval**
  - **SUGGESTION**: User may optionally run `/compact` before approving plan to refresh context for execution
    - **When Helpful**: After long planning discussions (>30K tokens used)
    - **Benefits**: Fresh context for Phases 2-4.5, all plan details preserved in ALL_SPRINTS_MASTER_PLAN.md + GitHub issues
    - **Not Required**: Optional optimization, not mandatory
  - User reviews complete sprint plan (Tasks A, B, C, etc.)
  - User approves Phase 1 sprint plan
  - **Plan Approval = Pre-Approval for ALL Tasks A-Z through Phase 4.5 (Sprint Review)**
  - Claude should NOT ask for approval on individual tasks
  - Claude should NOT ask before starting each task
  - Claude should work autonomously and continuously until:
    - (a) Blocked/escalated (Criterion 2 in SPRINT_STOPPING_CRITERIA.md)
    - (b) All tasks complete (Criterion 1 in SPRINT_STOPPING_CRITERIA.md)
    - (c) Sprint review requested (Criterion 5 in SPRINT_STOPPING_CRITERIA.md)
    - (d) Code review needed (Phase 4.5 checkpoint)
  - If user requests mid-sprint changes: Document scope change, get re-approval, resume
  - **Reference**: §211-241 "Approval Gates - Only 4 checkpoint points"
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

---

### **Phase 2: Sprint Execution (Development)**

- [ ] **2.1 Start Task Execution**
  - Assign tasks to appropriate Claude Code models
  - Haiku starts with straightforward tasks
  - Sonnet available for escalation if needed
  - Opus available for complex issues

- [ ] **2.1.1 Review Architecture Guidance** (For Complex Tasks)
  - For tasks involving new components or architectural changes:
    - Read `docs/ARCHITECTURE.md` for system design patterns
    - Follow existing architectural principles
    - Document significant deviations in PR description

- [ ] **2.1.2 Review Performance Benchmarks** (For Performance-Sensitive Tasks)
  - For tasks affecting performance (database, scanning, UI rendering):
    - Read `docs/PERFORMANCE_BENCHMARKS.md` for baseline metrics
    - Benchmark before and after changes
    - Document performance impact in PR description

- [ ] **2.2 Testing Cycle (Per Task)**
  - **Compile**: Build the code
    - Command: `flutter build windows` or `flutter build apk` (as needed)
  - **Run Tests**: Execute test suite
    - Command: `flutter test`
    - Expected: All tests pass
    - **Strategic Test Runs** (Efficiency Tip): Only run tests AFTER fixing identified issue, not speculatively during investigation
      - Example: Run analyzer → identify 5 warnings → fix all 5 → THEN run tests (not after each fix)
      - Saves time and reduces context switching
  - **Code Analysis**: Check for issues
    - Command: `flutter analyze`
    - Expected: Zero errors, acceptable warnings
    - **Batch Similar Operations** (Efficiency Tip): Collect all warnings of same type first, then fix in one pass
      - Example: Collect all "unused import" warnings → fix all imports in one commit
      - Example: Collect all "unused field" warnings → remove all unused fields in one commit
      - Reduces context switching and ensures consistency
  - **Fix Bugs**: Address any failures
    - Fix code issues
    - Update or add tests as needed
  - **Repeat**: Re-run compile/test cycle until all pass

- [ ] **2.2.1 Create Test Files**
  - For each new feature, create corresponding test file
  - Unit tests: `test/unit/<feature>_test.dart`
  - Integration tests: `test/integration/<feature>_integration_test.dart`
  - Widget tests: `test/widgets/<screen>_test.dart`
  - Minimum coverage: 80% for new code

- [ ] **2.3 Commit During Development**
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

- [ ] **2.4 Track Progress**
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

---

### **Phase 3: Code Review & Testing**

- [ ] **3.1 Local Code Review**
  - Review all changes for quality and correctness
  - Verify code follows project patterns
  - Check test coverage is adequate
  - Ensure documentation is updated

- [ ] **3.2 Run Complete Test Suite**
  - Execute full test suite: `flutter test`
  - Verify all tests pass (not just new ones)
  - Check code analysis: `flutter analyze`
  - Ensure zero errors introduced
  - **(Optional) Efficiency Checkpoint**: If context usage > 60%, suggest user run `/compact` before Phase 4 to refresh context for final PR review phase

- [ ] **3.2.1 Validate Risk Mitigations** (MANDATORY - End-of-Sprint Test Gate)
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
  - If validation fails, fix issues before proceeding to Phase 4

- [ ] **3.3.1 Monitor Test Execution (Optional - For Debugging)**
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

**⚡ COMPACT SUGGESTION (Optional for Efficiency)**

After Phase 3.2 all tests pass, context can be compacted for efficiency:
- **Savings**: ~10-15% of context budget (20K-30K tokens)
- **Timing**: Before Phase 4 (PR creation + Review)
- **User Command**: `/compact` (if available in Claude Code)
- **Effect**: Summarizes conversation history, preserves key context, fresh tokens for final phases
- **No Loss**: All sprint work is committed to git, can be easily reviewed

---

#### ⚡ **PARALLEL TESTING WORKFLOW (Sprint 5+)**

**NEW IN SPRINT 5**: After Phase 3.2 tests pass, implement parallel workflow for efficiency:

1. **Notify User Immediately** (After 3.2 tests pass)
   - Message: "[OK] Code ready for testing in your VSCode repository"
   - Provide working branch name: `feature/YYYYMMDD_Sprint_N`
   - Give user VSCode workspace instructions
   - **Timing**: User can start testing RIGHT NOW

2. **Claude Proceeds to Phase 4 (In Parallel) - MANDATORY**
   - While user tests in VSCode, Claude:
     - **Creates PR (Phase 4.3)** - **REQUIRED, DO NOT SKIP**
       - Target: `develop` branch (NOT main)
       - Title format: "Sprint N: <summary>"
       - Include all commits from feature branch
       - Add sprint summary and task breakdown to PR description
     - Writes documentation
     - Conducts code review analysis
     - Prepares Phase 4.5 review
   - **[WARNING] CRITICAL**: PR creation is NOT optional - must happen during manual testing
   - **No blocking**: User testing doesn't wait for PR

   **Why PR Creation is Mandatory During Testing**:
   - Maximizes parallelization (independent work streams)
   - User can review PR when ready (no waiting)
   - All documentation complete when testing finishes
   - Reduces total sprint time by 30-60 minutes
   - No impact on quality (work is independent)

3. **Phase 4.5 Complete**
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
- PR includes all Sprint 4-4.5 work when user is ready to review
- Both activities benefit from independence (faster iteration)

- [ ] **3.3 Manual Testing  - PARALLEL WITH PHASE 4**

  **CRITICAL**: Claude Code will build and run the Windows Desktop App (or target platform) so that user can complete manual testing. User should NOT have to build app themselves.

  **Pre-Testing Checklist** (Claude Code completes BEFORE handing to user):
  - [ ] **3.3.a Build the application**
    - Windows: `cd mobile-app/scripts && .\build-windows.ps1`
    - Android: `cd mobile-app/scripts && .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator`
    - Monitor build output for errors or warnings
    - If build fails: Fix errors, retry, document any issues
  - [ ] **3.3.b Verify build succeeded** without errors
    - Check build log for compilation errors
    - Note any warnings that may affect functionality
  - [ ] **3.3.c Launch the application**
    - Windows: App auto-launches from build script
    - Android: `adb shell am start -n com.example.spam_filter_mobile/.MainActivity`
    - Verify app opens to expected screen
  - [ ] **3.3.d Sanity check** - quick verification before handing to user
    - App does not crash on launch
    - No database initialization errors in console
    - Key UI elements are visible
    - Console shows expected startup logging
  - [ ] **3.3.e Notify user app is ready**
    - Message: "[OK] App built and running, ready for manual testing"
    - Provide platform details (Windows desktop / Android emulator)
    - Note any warnings or known issues to watch for
  - [ ] **3.3.f Monitor app output** (Claude Code background task)
    - Watch console for errors during user testing
    - Report any crashes or exceptions immediately
    - Capture relevant logs for debugging if issues arise

  **User Manual Testing**:
  - Test on target platform (Android emulator, Windows desktop, etc.)
  - Verify user-facing changes work as expected
  - Check for regressions in existing features
  - Document any issues found

  **Reference**: See `docs/MANUAL_INTEGRATION_TESTS.md` for comprehensive test scenarios

  **NOTE**: Starting Sprint 5, user tests in parallel while Claude completes Phase 4-4.5
  - **User Ready?**: Yes → Begin manual testing on running app
  - **Claude Meanwhile**: Proceeds to Phase 4.3 (PR creation) while monitoring app

- [ ] **3.4 Fix Issues from Testing**
  - Address any test failures
  - Fix any regressions discovered
  - Update code if needed
  - Re-run complete test cycle

- [ ] **3.5 Request Feedback (if important)**
  - Identify high-impact changes requiring review
  - Share with user for feedback if architectural decisions made
  - Document feedback received
  - Make any adjustments

---

## [OK] Approval Gates (Sprint 5+)

**User Approvals**: Only at these 4 points (NOT per-task):

1. **Sprint Plan Approval** (Phase 1)
   - User reviews and approves entire sprint plan
   - **Pre-approves all tasks** when plan is approved
   - No per-task approvals needed during execution
   - Confidence: HIGH (plan was detailed)

2. **Sprint Start** (Phase 1)
   - User confirms: "Ready to begin sprint"
   - Simple confirmation, not detailed approval
   - All task execution pre-approved

3. **Sprint Review Feedback** (Phase 4.5)
   - User provides feedback on effectiveness, efficiency, process
   - Claude adjusts based on feedback (documentation updates)
   - Not a blocker - more of a feedback collection point

4. **PR Approval** (Phase 4 - After 4.5)
   - User reviews final PR and code
   - User approves for merge to develop
   - Last formal approval before merge

**Why NOT per-task?**
- All tasks are specified in the plan
- Plan approval means task approval
- Tasks are interdependent (can't skip/change without new plan)
- Per-task approval adds overhead without benefit
- Detailed plan provides sufficient control

**[WARNING] CRITICAL REMINDER FOR CLAUDE**:
- **DO NOT ask for approval between tasks** after sprint plan is approved
- **DO NOT ask "Should I proceed to Task B?"** - this is pre-approved
- **DO NOT ask "Ready for next task?"** - continue autonomously
- **ONLY STOP FOR**: Blockers, errors, scope changes, or Phase 4.5 review
- Sprint plan approval = approval for ALL tasks in sequence
- Asking for per-task approval violates this workflow and delays execution

**When to Stop Mid-Sprint**:
- Tests fail and cannot fix immediately
- Scope change discovered (requires re-planning)
- Blocked by external dependency
- User explicitly requests pause
- Phase 3.3 Manual Testing complete (proceed to Phase 4 in parallel)
- Phase 4.5 Sprint Review (REQUIRED)

**Reference**: See `docs/SPRINT_STOPPING_CRITERIA.md` for complete stopping criteria

---

### **Phase 4: Push to Remote & Create PR**

- [ ] **4.1 Finalize All Changes**
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

- [ ] **4.1.1 Risk Review Gate** (MANDATORY before push to remote)
  - **Review all sprint risks** documented in sprint plan
  - **Confirm mitigations executed** for each risk:
    - Low risk tasks: Quick verification (tests passed, no regressions)
    - Medium risk tasks: Detailed validation (risk mitigation steps from Phase 3.2.1)
    - High risk tasks: Comprehensive validation (all acceptance criteria met, mitigations proven)
  - **Document risk review summary**:
    - Example: "Risk review complete: 3 tasks reviewed, all mitigations executed and validated"
    - Example: "Task A (Low risk): Tests passed. Task B (Medium risk): API design reviewed and validated. Task C (High risk): Performance benchmarked (45ms→38ms, target met)"
  - **No user approval needed** - this is a Claude-led review to ensure quality
  - If any risk mitigation failed or incomplete, fix before pushing to remote

- [ ] **4.2 Push to Remote**
  - Command: `git push origin feature/YYYYMMDD_Sprint_N`
  - Verify: All commits appear on GitHub branch
  - **CRITICAL**: This step must not be skipped - it ensures work is backed up

- [ ] **4.3 Create Pull Request**
  - Go to GitHub repository
  - **CRITICAL**: Create PR from `feature/YYYYMMDD_Sprint_N` → `develop` branch (NOT main)
    - **Rule**: All Claude Code PRs target `develop` branch
    - **Why**: `develop` is integration branch; `main` is for user-approved releases only
    - **User Role**: Only user creates PRs to `main` after `develop` is stabilized
  - **PR Title**: `Sprint N: <Feature Name>`
  - **PR Description**: Include:
    - Summary of what's included
    - List of all tasks completed
    - Code quality metrics (lines added, test count, issues found)
    - Related GitHub issues closed
    - Files modified/created
    - Any blockers or concerns
  - Reference all sprint cards: `Closes #XX, #YY, #ZZ`

- [ ] **4.4 Assign Code Review**
  - Assign GitHub Copilot for automated review
  - Add user as reviewer if manual review needed
  - Request specific review focus if applicable

- [ ] **4.5 Notify User**
  - Inform user PR is ready for review
  - Provide summary of sprint results
  - Ask for approval or feedback
  - Note any follow-up items

---

---

**⚡ EFFICIENCY CHECKPOINT: Context Refresh (Optional)**

Before Phase 4.5, if context usage is high (>70%), user can optionally run `/compact`:
- Summarizes prior phases while preserving sprint context
- Refreshes tokens for final review and documentation phases
- No impact on sprint quality (all work is in git)
- Recommended if proceeding to next sprint in same conversation

---

### **Phase 4.5: Sprint Review (After PR Submitted) - MANDATORY FOR ALL SPRINTS**

[WARNING] **IMPORTANT**: Phase 4.5 is **MANDATORY and REQUIRED** for all sprints. Do NOT skip this phase.

**Why Phase 4.5 is Critical**:
- Captures lessons learned for future sprint improvements
- Provides user feedback for process optimization
- Documents architectural decisions and tradeoffs
- Identifies potential issues early
- Builds team knowledge base

#### **Pre-Review: Windows Desktop Build & Test (REQUIRED)**

Before conducting sprint review, build and test the Windows desktop app:

- [ ] **4.5.0 Build and Run Windows Desktop App**
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
  - **Next Step**: After successful build, proceed to 4.5.1

- [ ] **4.5.1 Offer Sprint Review (REQUIRED)**
  - Ask user: "Would you like to conduct a sprint review before approving the PR? (Recommended)"
  - Sprint review is MANDATORY (not optional) but can be conducted quickly
  - User can provide brief feedback or skip answers
  - Timing: Conduct while user reviews PR, before merge
  - **DO NOT PROCEED TO MERGE WITHOUT COMPLETING PHASE 4.5**

- [ ] **4.5.2 Gather User Feedback (if review desired)**
  - Ask user for feedback on optional topics:
    - **Effort Accuracy**: Did actual effort match estimate?
    - **Planning Quality**: Was the sprint plan clear and complete?
    - **Model Assignments**: Were Haiku/Sonnet task assignments correct?
    - **Communication**: Was progress clear? Any unanswered questions?
    - **Requirements Clarity**: Was the specification clear?
    - **Testing Approach**: Did the test-first approach work well?
    - **Documentation**: Was code/PR documentation sufficient?
    - **Process Issues**: Any friction in the sprint workflow?
    - **Risk Management**: Were identified risks handled well?
    - **Next Sprint Readiness**: How prepared are we for next sprint?
  - Document user feedback verbatim

- [ ] **4.5.3 Provide Claude Feedback**
  - Share my assessment of what went well (quality, architecture, patterns)
  - Share what could be improved (edge cases, documentation gaps)
  - Provide specific, actionable observations
  - Format: "What Went Well" + "What Could Be Improved"

- [ ] **4.5.4 Create Improvement Suggestions**
  - Identify common improvements from both feedbacks
  - Prioritize: High, Medium, Low
  - Group by category: Documentation, Process, Testing, Architecture, etc.
  - Make suggestions optional, not mandatory

- [ ] **4.5.5 Decide on Improvements**
  - Ask user which improvements should be implemented
  - Improvements are applied to documentation/process, not code
  - Examples: Update SPRINT_EXECUTION_WORKFLOW.md, Create `.claude/model_assignment_heuristics.json`, etc.
  - User selects which changes to make

- [ ] **4.5.6 Update Documentation** (MANDATORY UPDATES)

  **Process Improvements** (from retrospective feedback):
  - Apply agreed-upon improvements to relevant documents
  - Update version/date on modified documents
  - Create new documents if needed
  - Commit improvements to feature branch

  **MANDATORY Sprint Completion Updates**:
  - [ ] **Update CHANGELOG.md** (MANDATORY - see Step 3 in "After Sprint Approval")
    - Add entry under `## [Unreleased]` section
    - Format: `### YYYY-MM-DD` with sprint summary
    - Include all user-facing changes from sprint
    - Reference PR number: `(PR #NNN)`
    - **Format Reference**: See CLAUDE.md § Changelog Policy for detailed format

  - [ ] **Update ALL_SPRINTS_MASTER_PLAN.md** (MANDATORY - see Step 3 in "After Sprint Approval")
    - Navigate to Sprint N section
    - Add completion metadata (estimated vs actual duration, lessons learned)
    - Update future sprint dependencies if needed
    - Update risk assessments based on lessons learned

  - [ ] **Create Sprint Retrospective Document** (if review conducted)
    - Create `docs/SPRINT_N_RETROSPECTIVE.md`
    - Use template from `docs/SPRINT_RETROSPECTIVE.md`
    - Record feedback, improvements, and action items

- [ ] **4.5.7 Summarize Review Results**
  - Provide summary of review findings
  - List which improvements were selected for implementation
  - Confirm PR is ready for user approval

- [ ] **4.5.8 Proactive Next Steps** (MANDATORY after sprint completion)
  - After sprint completion, present 3 options to user:
    1. **Sprint Review**: Conduct formal retrospective (if not already done in 4.5)
    2. **Start Next Sprint**: Begin planning and execution of next sprint from ALL_SPRINTS_MASTER_PLAN.md
    3. **Ad-hoc Work**: Work on unplanned tasks or investigations outside sprint framework
  - **Template**:
    ```
    Sprint N complete! What would you like to do next?

    1. [CHECKLIST] Sprint Review (if not already conducted)
    2. ➡️ Start Sprint N+1 (see ALL_SPRINTS_MASTER_PLAN.md for details)
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

🤖 Generated with [Claude Code](https://claude.com/claude-code)
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
1. Fix the warning (don't ignore)
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

### Before PR Submission (Phase 3 Complete)
- [OK] All sprint cards completed
- [OK] All tests passing (100% pass rate)
- [OK] Zero code analysis errors
- [OK] Local code review completed
- [OK] No blockers remaining

### When PR Submitted (Phase 4 Complete)
- [OK] All commits pushed to remote
- [OK] PR created to `develop` branch (NOT main - critical requirement)
- [OK] PR fully documented (see GitHub PR template)
- [OK] Sprint card issues referenced in PR description (Closes #XX, #YY, #ZZ)
- [OK] User notified and ready for review

### When PR Approved (Phase 4.5 Complete)
- [OK] Sprint review COMPLETED (MANDATORY - see Phase 4.5 above)
- [OK] User feedback collected
- [OK] Improvement suggestions documented
- [OK] Agreed-upon improvements applied to documentation
- [OK] Ready for merge

**[WARNING] CRITICAL**: Phase 4.5 must be completed BEFORE merge. This is not optional.

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

3. **Update Sprint Completion Documentation** (MANDATORY)

   - [ ] **Update CHANGELOG.md** (MANDATORY)
     - Add entry under `## [Unreleased]` section
     - Format: `### YYYY-MM-DD` with sprint summary
     - Include all user-facing changes from sprint
     - Reference PR number: `(PR #NNN)`
     - See CLAUDE.md § Changelog Policy for format

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
         - [Improvement 1] → Updated [file]
       ```
     - Update future sprint dependencies if needed
     - Update risk assessments based on lessons learned

   - [ ] **Create Sprint Retrospective Document** (if review conducted)
     - Create `docs/SPRINT_N_RETROSPECTIVE.md`
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

**Version**: 1.2
**Last Updated**: February 1, 2026
**Updates in 1.2**:
- Enhanced Phase 3.3 pre-testing checklist with explicit build/run steps (Issue #115)
- Added step-by-step sub-items: build, verify, launch, sanity check, notify, monitor
- Clarified Claude Code responsibilities for app preparation before user testing
- Added platform-specific build commands (Windows and Android)

**Updates in 1.1**:
- Added Phase 4.5: Sprint Review process (user feedback, improvements, documentation)
- Added Phase 0: Pre-Sprint Verification checklist (prevents missed steps on continuation)
- Added "After Sprint Approval - Merge & Cleanup" section
- Emphasized "Push to Remote" as CRITICAL step with note about preventing missed steps
- Updated Success Criteria to show progression through phases

**Reference**: Based on Sprint 1-11 execution experience
