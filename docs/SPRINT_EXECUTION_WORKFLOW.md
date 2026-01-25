# Sprint Execution Workflow

This document describes the step-by-step process for executing sprints in the spamfilter-multi project, based on actual experience from Sprint 1.

---

## Sprint Execution Checklist

### **Phase 1: Sprint Kickoff & Planning**

- [ ] **1.1 Determine Next Sprint Number**
  - Last completed sprint: Sprint 1
  - Next sprint: Sprint 2
  - Pattern: Increment by 1

- [ ] **1.2 Review Sprint Plan**
  - Read comprehensive plan document (e.g., `Phase 3.5 Planning` document)
  - Identify Sprint 2 in the plan
  - Verify scope, tasks, and acceptance criteria
  - Note any changes needed based on Sprint 1 learnings

- [ ] **1.3 Branch Management**
  - Check if repository is in a PR branch
  - If yes: Wait for PR approval/merge, then switch to main/develop
  - Create new feature branch: `feature/<YYYYMMDD>_Sprint_<N><optional_suffix>`
  - Example: `feature/20260124_Sprint_2` or `feature/20260124_Sprint_2_Rule_Migration`
  - Switch repository to new branch: `git checkout -b <branch-name>`

- [ ] **1.4 Create GitHub Sprint Cards**
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
  - Acceptance criteria clear and testable
  - Dependencies on previous sprints verified as complete

---

### **Phase 2: Sprint Execution (Development)**

- [ ] **2.1 Start Task Execution**
  - Assign tasks to appropriate Claude Code models
  - Haiku starts with straightforward tasks
  - Sonnet available for escalation if needed
  - Opus available for complex issues

- [ ] **2.2 Testing Cycle (Per Task)**
  - **Compile**: Build the code
    - Command: `flutter build windows` or `flutter build apk` (as needed)
  - **Run Tests**: Execute test suite
    - Command: `flutter test`
    - Expected: All tests pass
  - **Code Analysis**: Check for issues
    - Command: `flutter analyze`
    - Expected: Zero errors, acceptable warnings
  - **Fix Bugs**: Address any failures
    - Fix code issues
    - Update or add tests as needed
  - **Repeat**: Re-run compile/test cycle until all pass

- [ ] **2.3 Commit During Development**
  - Make focused commits per logical change
  - Commit messages should reference related GitHub issues
  - Format: `<type>: <description> (Issue #N)`
  - Example: `feat: Implement RuleDatabaseStore (Issue #56)`

- [ ] **2.4 Track Progress**
  - Update GitHub issue comments with task progress
  - Note blockers immediately
  - Document decisions made during implementation
  - Record actual time spent (estimate vs. actual)

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

- [ ] **3.3 Manual Testing (if applicable)**
  - Test on target platform (Android emulator, Windows desktop, etc.)
  - Verify user-facing changes work as expected
  - Check for regressions in existing features
  - Document any issues found

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

### **Phase 4: Push to Remote & Create PR**

- [ ] **4.1 Finalize All Changes**
  - Ensure all commits are local and staged
  - Verify git status is clean
  - Double-check all tests pass

- [ ] **4.2 Push to Remote**
  - Command: `git push origin feature/YYYYMMDD_Sprint_N`
  - Verify: All commits appear on GitHub branch
  - **CRITICAL**: This step must not be skipped - it ensures work is backed up

- [ ] **4.3 Create Pull Request**
  - Go to GitHub repository
  - Create PR from `feature/YYYYMMDD_Sprint_N` → `develop` branch
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

### **Phase 4.5: Sprint Review (After PR Submitted)**

- [ ] **4.5.1 Offer Sprint Review**
  - Ask user: "Would you like to conduct a sprint review before approving the PR? (y/n)"
  - Sprint review is optional but recommended for continuous improvement
  - Timing: Conduct while user reviews PR, before merge

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

- [ ] **4.5.6 Update Documentation**
  - Apply agreed-upon improvements to relevant documents
  - Update version/date on modified documents
  - Create new documents if needed (e.g., sprint retrospective)
  - Commit improvements to feature branch

- [ ] **4.5.7 Summarize Review Results**
  - Provide summary of review findings
  - List which improvements were selected for implementation
  - Confirm PR is ready for user approval

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
- ✅ <N> tests passing (was <M> before)
- ✅ Zero code analysis issues
- ✅ <X> lines of code added
- ✅ <Y> lines of code removed/refactored

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
- ✅ All sprint cards completed
- ✅ All tests passing (100% pass rate)
- ✅ Zero code analysis errors
- ✅ Local code review completed
- ✅ No blockers remaining

### When PR Submitted (Phase 4 Complete)
- ✅ All commits pushed to remote
- ✅ PR created and fully documented (see GitHub PR template)
- ✅ Sprint card issues referenced in PR description (Closes #XX, #YY, #ZZ)
- ✅ User notified and ready for review

### When PR Approved (Phase 4.5 Complete)
- ✅ Sprint review conducted (if desired by user)
- ✅ Improvement suggestions documented
- ✅ Agreed-upon improvements applied to documentation
- ✅ Ready for merge

### After Merge (Cleanup Complete)
- ✅ PR merged to develop
- ✅ Feature branch deleted (locally and remote)
- ✅ All related GitHub issues closed
- ✅ Sprint retrospective documented (if applicable)
- ✅ Ready to begin next sprint

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

3. **Update Sprint Completion Documentation**
   - If sprint review was conducted: Create `docs/SPRINT_N_RETROSPECTIVE.md`
   - Record what went well, what could improve
   - Document improvements implemented
   - Link to PR for code artifacts

---

## Before Starting Next Sprint - Verification

Before beginning next sprint execution:

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

**Version**: 1.1
**Last Updated**: January 24, 2026
**Updates in 1.1**:
- Added Phase 4.5: Sprint Review process (user feedback, improvements, documentation)
- Added Phase 0: Pre-Sprint Verification checklist (prevents missed steps on continuation)
- Added "After Sprint Approval - Merge & Cleanup" section
- Emphasized "Push to Remote" as CRITICAL step with note about preventing missed steps
- Updated Success Criteria to show progression through phases

**Reference**: Based on Sprint 1 & 2 execution experience
