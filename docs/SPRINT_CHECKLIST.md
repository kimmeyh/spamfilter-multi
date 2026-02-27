# Sprint Checklist

Single-page reference for sprint execution. Copy to sprint plan and check off during execution.

**[WARNING] PHASE TRANSITION PROTOCOL**: Before starting ANY new phase, re-read this checklist to verify all items for the current phase are complete and review the next phase requirements. This prevents skipping steps.

---

## Sprint Documents (Required)

These documents MUST be created/updated during each sprint:

| Document | When Created | Location |
|----------|-------------|----------|
| `SPRINT_N_PLAN.md` | Phase 3 (Sprint Start) | `docs/sprints/` |
| `SPRINT_N_RETROSPECTIVE.md` | Phase 7 (Sprint End) | `docs/sprints/` |
| `SPRINT_N_SUMMARY.md` | Phase 7 or Phase 3.2.1 of next sprint | `docs/sprints/` |
| CHANGELOG.md | Phase 4+ (ongoing) | Project root |
| ALL_SPRINTS_MASTER_PLAN.md | Phase 7 (completion metadata) | `docs/` |
| ARCHITECTURE.md | Phase 7 (if architecture changed) | `docs/` |

**Naming Convention**: Always uppercase `SPRINT_N_*.md` (e.g., `SPRINT_17_PLAN.md`)

---

## Phase 2: Pre-Kickoff

- [ ] Previous sprint PR merged to `develop`
- [ ] Previous sprint cards closed
- [ ] Working directory clean (`git status`)
- [ ] Local develop branch current (`git pull origin develop`)

**[CHECKPOINT]** Review Phase 3 checklist before proceeding.

## Phase 3: Kickoff & Planning

- [ ] Sprint number determined (N = previous + 1)
- [ ] Read ALL_SPRINTS_MASTER_PLAN.md "Next Sprint Candidates" table
- [ ] Created `docs/sprints/SPRINT_(N-1)_SUMMARY.md` for previous sprint (3.2.1)
- [ ] **Created `docs/sprints/SPRINT_N_PLAN.md`** for current sprint (3.2.2 - MANDATORY)
- [ ] Created feature branch: `feature/YYYYMMDD_Sprint_N`
- [ ] Created GitHub issues for all tasks
- [ ] Verified all issues are OPEN
- [ ] Sprint plan reviewed and approved by user
- [ ] **Draft PR created immediately** (optional but recommended)

**[CHECKPOINT]** Review Phase 4 checklist before proceeding.

## Phase 4: Execution

- [ ] Tasks assigned to appropriate models (Haiku/Sonnet/Opus)
- [ ] Each task: Code -> Build -> Test -> Analyze -> Commit
- [ ] Commits reference GitHub issues (`feat: ... (Issue #N)`)
- [ ] CHANGELOG.md updated with each user-facing change
- [ ] Progress tracked in GitHub issue comments
- [ ] Pushed to remote at least once during session

**[CHECKPOINT]** Review Phase 5 checklist before proceeding.

## Phase 5: Review & Testing

- [ ] Local code review complete
- [ ] Full test suite passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze` - target <50 warnings)
- [ ] Risk mitigations validated
- [ ] **App built for user testing** (Windows: `build-windows.ps1`)
- [ ] Manual testing complete (user)
- [ ] Issues from testing fixed

**[CHECKPOINT]** Review Phase 6 checklist before proceeding.

## Phase 6: Push & PR

- [ ] All changes committed and clean
- [ ] Risk review gate passed
- [ ] Pushed to remote: `git push origin feature/YYYYMMDD_Sprint_N`
- [ ] PR created: `feature/...` -> `develop` (NOT main)
- [ ] PR description complete with task summary
- [ ] PR references issues: `Closes #XX, #YY, #ZZ`
- [ ] User notified PR is ready

**[CHECKPOINT]** Review Phase 7 checklist before proceeding. Phase 7 is MANDATORY.

## Phase 7: Sprint Review (MANDATORY - DO NOT SKIP)

- [ ] Windows desktop build verified
- [ ] Sprint review offered to user
- [ ] User feedback gathered
- [ ] Claude feedback provided
- [ ] Improvement suggestions created
- [ ] Improvements decided (which to implement)
- [ ] **Sprint Documents updated**:
  - [ ] CHANGELOG.md updated (all sprint entries present)
  - [ ] ALL_SPRINTS_MASTER_PLAN.md updated (per Maintenance Guide rules)
  - [ ] `docs/sprints/SPRINT_N_RETROSPECTIVE.md` created (MANDATORY)
  - [ ] `docs/sprints/SPRINT_N_SUMMARY.md` created (or deferred to next sprint Phase 3.2.1)
  - [ ] ARCHITECTURE.md updated (if architecture changed)
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

**Version**: 2.0
**Updated**: February 21, 2026 (Sprint 17 retrospective improvements)
**Reference**: SPRINT_EXECUTION_WORKFLOW.md for detailed explanations
