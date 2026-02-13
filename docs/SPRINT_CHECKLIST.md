# Sprint Checklist

Single-page reference for sprint execution. Copy to sprint plan and check off during execution.

---

## Phase 0: Pre-Kickoff

- [ ] Previous sprint PR merged to `develop`
- [ ] Previous sprint cards closed
- [ ] Working directory clean (`git status`)
- [ ] Local develop branch current (`git pull origin develop`)

## Phase 1: Kickoff & Planning

- [ ] Sprint number determined (N = previous + 1)
- [ ] Read ALL_SPRINTS_MASTER_PLAN.md for Sprint N
- [ ] Created SPRINT_(N-1)_SUMMARY.md for previous sprint
- [ ] Created feature branch: `feature/YYYYMMDD_Sprint_N`
- [ ] Created GitHub issues for all tasks
- [ ] Verified all issues are OPEN
- [ ] Sprint plan reviewed and approved by user
- [ ] **Draft PR created immediately** (optional but recommended)

## Phase 2: Execution

- [ ] Tasks assigned to appropriate models (Haiku/Sonnet/Opus)
- [ ] Each task: Code → Build → Test → Analyze → Commit
- [ ] Commits reference GitHub issues (`feat: ... (Issue #N)`)
- [ ] Progress tracked in GitHub issue comments
- [ ] Pushed to remote at least once during session

## Phase 3: Review & Testing

- [ ] Local code review complete
- [ ] Full test suite passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze` - target <50 warnings)
- [ ] Risk mitigations validated
- [ ] **App built for user testing** (Windows: `build-windows.ps1`)
- [ ] Manual testing complete (user)
- [ ] Issues from testing fixed

## Phase 4: Push & PR

- [ ] All changes committed and clean
- [ ] Risk review gate passed
- [ ] Pushed to remote: `git push origin feature/YYYYMMDD_Sprint_N`
- [ ] PR created: `feature/...` → `develop` (NOT main)
- [ ] PR description complete with task summary
- [ ] PR references issues: `Closes #XX, #YY, #ZZ`
- [ ] User notified PR is ready

## Phase 4.5: Sprint Review (MANDATORY)

- [ ] Windows desktop build verified
- [ ] Sprint review offered to user
- [ ] User feedback gathered
- [ ] Claude feedback provided
- [ ] Improvement suggestions created
- [ ] Improvements decided (which to implement)
- [ ] **Documentation updated**:
  - [ ] CHANGELOG.md updated
  - [ ] ALL_SPRINTS_MASTER_PLAN.md updated
  - [ ] SPRINT_N_RETROSPECTIVE.md created (if review conducted)
  - [ ] .claude/sprint_status.json updated
- [ ] Review results summarized
- [ ] Next steps offered to user

## Post-Merge Cleanup

- [ ] PR merged to develop
- [ ] GitHub issues auto-closed (verify)
- [ ] Feature branch deleted (optional, user-managed)
- [ ] Ready for next sprint

---

## Quick Commands Reference

```powershell
# Branch
git checkout -b feature/YYYYMMDD_Sprint_N

# Push
git push -u origin feature/YYYYMMDD_Sprint_N

# PR (draft)
gh pr create --draft --title "Sprint N: Title" --base develop

# Tests
cd mobile-app && flutter test

# Analyze
flutter analyze

# Build Windows
cd mobile-app/scripts && .\build-windows.ps1

# Close issues
gh issue close #N --reason "completed"
```

---

## Stopping Criteria (ONLY stop for these)

1. All tasks complete
2. Blocked on external dependency
3. User requests scope change
4. Critical bug found
5. User requests early review
6. Sprint review complete
7. Fundamental design failure
8. Context limit approaching
9. Time limit reached

**NOT valid**: Implementation choices, approach uncertainty, code style, single test failure

---

**Version**: 1.0
**Created**: February 13, 2026
**Reference**: SPRINT_EXECUTION_WORKFLOW.md for detailed explanations
