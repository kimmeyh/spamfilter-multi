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

- ✅ All sprint cards completed and closed
- ✅ All tests passing (100% pass rate)
- ✅ Zero code analysis errors
- ✅ Code review completed (via Copilot or user)
- ✅ PR created and documented
- ✅ No blockers remaining
- ✅ User notified and ready for merge approval

---

## After Sprint Approval

Once user approves PR:

1. **Merge to develop**
   - PR approved and merged
   - Branch deleted (locally and remote)

2. **Prepare Sprint Retrospective**
   - Document what went well
   - Identify improvements
   - Update heuristics if needed

3. **Plan Next Sprint**
   - Review next sprint in plan document
   - Gather any new requirements
   - Prepare for Sprint N+1 kickoff

---

**Version**: 1.0
**Last Updated**: January 24, 2026
**Reference**: Based on Sprint 1 execution experience
