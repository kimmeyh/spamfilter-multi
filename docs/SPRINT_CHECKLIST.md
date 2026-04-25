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

## Phase 1: Backlog Refinement (MANDATORY -- every sprint, no PO request needed)

**Sprint 36 policy change (2026-04-20)**: Phase 1 is MANDATORY on every sprint. Do NOT ask the user "should we do backlog refinement?" -- just run it. Skipping or asking is a process violation.

- [ ] Read current `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" section
- [ ] Scan for stale items (>3 sprints old without review)
- [ ] Re-prioritize if needed (value, effort, risk)
- [ ] Update estimates with velocity from recent sprints
- [ ] Capture newly identified work items
- [ ] Remove obsolete items
- [ ] **Present candidates to user in BACKLOG_REFINEMENT.md bullet-list format** (NOT grid tables). Required format: `**<ID>. <Title> (~<effort>) Priority <N>**` with bullet details per item, grouped by priority tier, HOLD items at bottom, include observations/alternative composition options when scope is tight
- [ ] User selects items for Sprint N; record selection for Phase 3 plan doc
- [ ] Commit refinement changes if ALL_SPRINTS_MASTER_PLAN.md was updated: `git commit -m "docs: Backlog refinement - [date] - [summary]"`

**Detailed Process**: See `BACKLOG_REFINEMENT.md`.

**[CHECKPOINT]** Review Phase 2 checklist before proceeding.

## Phase 2: Pre-Kickoff

- [ ] Previous sprint PR merged to `develop`
- [ ] Previous sprint cards closed
- [ ] Working directory clean (`git status`)
- [ ] Local develop branch current (`git pull origin develop`)
- [ ] Dependency vulnerability check (`cd mobile-app && dart pub outdated`) -- flag discontinued or vulnerable packages

**[CHECKPOINT]** Review Phase 3 checklist before proceeding.

## Phase 3: Kickoff & Planning

- [ ] **Verify active model is Opus** (sprint planning requires Opus per SPRINT_PLANNING.md "Activities Requiring Opus")
- [ ] Sprint number determined (N = previous + 1)
- [ ] **Phase 1 Backlog Refinement complete** (candidates presented in BACKLOG_REFINEMENT.md format, user selected items) -- if Phase 1 was skipped, STOP and return to Phase 1 first
- [ ] **Verify** `docs/sprints/SPRINT_(N-1)_SUMMARY.md` exists for previous sprint (created in Phase 7)
- [ ] **Created `docs/sprints/SPRINT_N_PLAN.md`** for current sprint (3.2.2 - MANDATORY) using items selected in Phase 1.2
- [ ] Created feature branch: `feature/YYYYMMDD_Sprint_N`
- [ ] Created GitHub issues for all tasks
- [ ] Verified all issues are OPEN
- [ ] **Architecture Impact Check** (3.6.1): Review planned changes against ARCHITECTURE.md, ARSD.md, and ADRs. Include doc updates in sprint scope if needed.
- [ ] Sprint plan reviewed and approved by user
- [ ] **Draft PR created immediately** (optional but recommended)

**[CHECKPOINT]** Review Phase 4 checklist before proceeding. **[CONTEXT CHECK]** Verify context < 85% before starting Phase 4.

## Phase 4: Execution

- [ ] **[CONTEXT CHECK]** Verify context < 85% (estimate task cost; `/compact` if next task would exceed 95%)
- [ ] Tasks assigned to appropriate models (Haiku/Sonnet/Opus)
- [ ] Each task: **[CONTEXT CHECK]** -> Code -> Build -> Test -> Analyze -> Commit
- [ ] Commits reference GitHub issues (`feat: ... (Issue #N)`)
- [ ] CHANGELOG.md updated with each user-facing change
- [ ] Progress tracked in GitHub issue comments
- [ ] Pushed to remote at least once during session

**[CHECKPOINT]** Review Phase 5 checklist before proceeding. **[CONTEXT CHECK]** Verify context < 85% before starting Phase 5.

## Phase 5: Review & Testing

- [ ] Local code review complete
- [ ] **Automated code review**: Run `pr-review-toolkit:code-reviewer` agent on sprint diff (always include related-patterns grep step); for cross-cutting policy sprints, run a second feature-sweep pass; address HIGH/CRITICAL findings (see SPRINT_EXECUTION_WORKFLOW.md § 5.1.1)
- [ ] Full test suite passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze` - target <50 warnings)
- [ ] Risk mitigations validated
- [ ] **Desktop E2E tests** (if UI changes): Run winwright accessibility tests on affected screens (see `docs/WINWRIGHT_SELECTORS.md`)
- [ ] **App built for user testing** (Windows: `build-windows.ps1`)
- [ ] **Platform-specific UI verified** at native level (Win32 window title, system tray, notifications) -- Flutter UI layer may not control platform-level behavior (learned Sprint 21)
- [ ] Manual testing complete (user)
- [ ] Issues from testing fixed

**[CHECKPOINT]** Review Phase 6 checklist before proceeding. **[CONTEXT CHECK]** Verify context < 85% before starting Phase 6.

## Phase 6: Push & PR

- [ ] All changes committed and clean
- [ ] Risk review gate passed
- [ ] Pushed to remote: `git push origin feature/YYYYMMDD_Sprint_N`
- [ ] PR created: `feature/...` -> `develop` (NOT main)
- [ ] PR description complete with task summary
- [ ] PR references issues: `Closes #XX, #YY, #ZZ`
- [ ] **GitHub Copilot review responded to** (if Copilot enabled): draft Fix/Backlog/NA recommendations per comment, get user approval, implement approved items (see SPRINT_EXECUTION_WORKFLOW.md § 6.4.1)
- [ ] User notified PR is ready

**[CHECKPOINT]** Review Phase 7 checklist before proceeding. Phase 7 is MANDATORY. **[CONTEXT CHECK]** Verify context < 85% before starting Phase 7.

## Phase 7: Sprint Review (MANDATORY - DO NOT SKIP)

[CRITICAL] **A Sprint Retrospective follows the 7-Step Retrospective Protocol in `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 7.3-7.7. All 14 categories must be addressed by all 4 roles. Steps must run in order; do NOT collapse, reorder, or skip steps. Missing roles, missing categories, skipped steps = retrospective is INCOMPLETE = sprint is NOT complete.**

- [ ] **Verify active model is Opus** (retrospective analysis requires Opus per SPRINT_PLANNING.md "Activities Requiring Opus")
- [ ] **7.1** Windows desktop build verified
- [ ] **7.2** Sprint review offered to user

**7-Step Retrospective Protocol (Steps 1-7)**:

- [ ] **Step 1 (7.3)**: Send the verbatim Phase 7.3 prompt to Harold asking for his Product Owner / Scrum Master / Lead Developer feedback across all 14 categories
- [ ] **Step 2 (7.3)**: While waiting for Harold, draft Claude Code Development Team feedback for all 14 categories into `docs/sprints/drafts/SPRINT_N_RETROSPECTIVE_claude_draft.md` (header marks it Claude-authored)
- [ ] **Step 3 (7.4)**: Once Harold replies, paste 14-category template into `docs/sprints/SPRINT_N_RETROSPECTIVE.md`, record his words verbatim per category, copy Claude's lines from Step 2 draft
- [ ] **Phase 7.3/7.4 EXIT GATE -- Completeness Validation passed**:
  - [ ] All 14 categories present in retrospective doc
  - [ ] All 4 roles addressed in each category (Harold's combined PO/SM/Lead line counts as 3 roles)
  - [ ] No `[feedback]` placeholder text remaining
  - [ ] Harold's feedback recorded verbatim, not paraphrased
- [ ] **7.4.1 Architecture Compliance Check**: Verify code changes match documented architecture. Flag gaps for doc update or code revert.
- [ ] **Step 4 (7.4.5)**: Combine and display the retrospective in chat using the no-borders format (header line OK, fields OK, wrapping within fields OK, spacing between fields OK)
- [ ] **Step 5 (7.5)**: Propose improvements from combined feedback. Any type (process, code, tests, architecture, docs, tooling). Format: Title / Source / Type / Effort / Recommendation. Display in chat -- do NOT auto-apply.
- [ ] **Step 6 (7.6)**: Ask Harold for explicit decision per proposal: (a) apply now, (b) add to backlog, (c) skip. Default expectation: most improvements faster to do now before next sprint. Record decisions in retrospective "Improvement Decisions" section.
- [ ] **Step 7 (7.7)**: Apply "apply now" improvements as additional commits on the existing sprint branch. Add "backlog" items to `ALL_SPRINTS_MASTER_PLAN.md`. Note "skip" items in retrospective.

**Mandatory sprint completion updates (Phase 7.7 continued)**:
  - [ ] CHANGELOG.md updated (all sprint entries present, including any Step 7 improvements)
  - [ ] ALL_SPRINTS_MASTER_PLAN.md updated (per Maintenance Guide rules) -- includes Category 14 backlog additions and Step 6 backlog dispositions
  - [ ] Next Sprint Plan stub created/updated with Category 13 carry-ins
  - [ ] `docs/sprints/SPRINT_N_RETROSPECTIVE.md` created/finalized (MANDATORY -- with all 14 categories x 4 roles filled + "Improvement Decisions" section from Step 6)
  - [ ] `docs/sprints/SPRINT_N_SUMMARY.md` created (MANDATORY - do not defer)
  - [ ] ARCHITECTURE.md updated (if architecture changed)
  - [ ] .claude/sprint_status.json updated
- [ ] **7.8** Review results summarized
- [ ] **7.9** Next steps offered to user

## Post-Merge Cleanup

- [ ] PR merged to develop
- [ ] **Review and close all resolved GitHub issues** (`gh issue list --state open` - close any resolved by this sprint)
- [ ] GitHub issues auto-closed (verify Closes #N references worked)
- [ ] Feature branch deleted (optional, user-managed)

## Post-Merge: Store Submission (if applicable)

If the sprint included changes that affect the Microsoft Store build (UI changes, bug fixes, MSIX fixes):

- [ ] Merge develop to main (user)
- [ ] Build Store MSIX: set `store: true` in pubspec.yaml, run `dart run msix:create`
- [ ] Upload MSIX to Microsoft Partner Center
- [ ] Submit for certification
- [ ] **Notify user** when build is ready for upload or when submission is complete

## Ready for Next Sprint

- [ ] All post-merge steps complete
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
4a. User-found gap in sprint theme (same category, <2h, no new design, user-reported) -- extend scope without stopping
5. User requests early review
6. Sprint review complete
7. Fundamental design failure
8. Context > 85%: `/compact` first; > 95%: STOP and prompt user
9. Time limit reached

**NOT valid**: Implementation choices, approach uncertainty, code style, single test failure

---

**Version**: 2.4
**Updated**: April 18, 2026 (Sprint 34 retrospective improvement: Phase 7.3-7.7 now follows the 7-Step Retrospective Protocol -- Step 1 send prompt, Step 2 draft Claude feedback in parallel, Step 3 record Harold verbatim, Step 4 combine and display, Step 5 propose improvements from combined feedback, Step 6 Harold decides now-vs-backlog, Step 7 apply approved improvements + sprint completion docs. See SPRINT_EXECUTION_WORKFLOW.md Phase 7.3 for the authoritative protocol.)
**Reference**: SPRINT_EXECUTION_WORKFLOW.md for detailed explanations
