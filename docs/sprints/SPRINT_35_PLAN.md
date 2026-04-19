# Sprint 35 Plan: Sprint 34 Cleanup + WinWright Test Execution

**Sprint**: 35
**Date**: April 19, 2026
**Branch**: `feature/20260419_Sprint_35`
**Issue**: #237
**Type**: Mixed -- Bug fix (BUG-S34-1), Testing (F69 execution)
**Estimated Effort**: ~6-9h (small recovery sprint after 14-task Sprint 34)

---

## Sprint Objective

Restore the green test suite on develop after the Sprint 34 escape (BUG-S34-1) and complete the F69 WinWright E2E execution work that Sprint 34 deferred (test scripts shipped; actual run-against-live-build acceptance criterion was not checked).

---

## Key Design Decisions

1. **Small recovery sprint**: Sprint 34 was a 14-task multi-session effort. Sprint 35 is intentionally scoped small to leave room for surfacing follow-up issues from F69 execution and to recover bandwidth before tackling larger items (F6, F52, F63 deferred to Sprint 36+).

2. **F69 acceptance criterion alignment**: Sprint 34 plan listed `[ ] Tests pass on Windows desktop dev build` as a F69 acceptance criterion that was never checked. Sprint 35 closes that gap by actually running the 7 scripts against a fresh Windows dev build and triaging any failures discovered.

3. **First task = test fix**: BUG-S34-1 must run first so that subsequent F69 work happens against a green baseline. Mixing F69 failures with the known stale-assertion failure would muddy diagnosis.

4. **Failures from F69 execution stay in scope if small**: If a F69 script fails because of a small selector mismatch or app text drift, fix it. If it fails because of a real app bug needing >2h, log and defer to Sprint 36 (per SPRINT_STOPPING_CRITERIA.md §4a).

---

## Tasks

### Task 1: BUG-S34-1 -- Stale test assertion fix (~10min, Haiku)

**Execution order**: 1 (must restore green baseline before F69)

**Problem**: After Sprint 34's F73 monolithic split rebuild, `mobile-app/test/unit/services/default_rule_set_service_test.dart` line 422 still expects 5 rules from `resetToDefaults()`. The rebuilt bundled YAML now seeds 1638 individual per-pattern rules. Sibling assertions in the same file (lines 105, 122, 173) were updated during F73 to use `greaterThan(100)`; line 422 was missed during review and broke develop after PR #236 merge.

**Fix**: Change line 422 from `expect(resetResult.rules, 5)` to `expect(resetResult.rules, greaterThan(100))` to match the convention already used in the other three assertions in this file.

**Acceptance criteria**:
- [ ] `flutter test test/unit/services/default_rule_set_service_test.dart` passes
- [ ] Full `flutter test` suite passes (all ~1362 tests, no regressions)
- [ ] Comment near the assertion notes the post-F73 expected count for future reviewers

### Task 2: F69 -- WinWright E2E test execution + triage (~6-8h, Sonnet)

**Execution order**: 2 (depends on green baseline from Task 1)

**Problem**: Sprint 34 shipped 7 WinWright JSON test scripts, README, and the `run-winwright-tests.ps1` runner, but never executed the suite against a live Windows desktop build. Sprint 34 plan acceptance criterion `[ ] Tests pass on Windows desktop dev build` was not checked.

**Steps**:
1. Build fresh Windows desktop dev build (`mobile-app/scripts/build-windows.ps1`)
2. Verify WinWright doctor passes (`C:\Tools\WinWright\Civyk.WinWright.Mcp.exe doctor`)
3. Run the full suite: `cd mobile-app/scripts && .\run-winwright-tests.ps1`
4. For each script in `mobile-app/test/winwright/`:
   - `test_navigation.json`
   - `test_manual_scan_flow.json`
   - `test_settings_tabs.json`
   - `test_text_selection.json`
   - `test_f56_create_block_rule.json`
   - `test_f56_create_safe_sender.json`
   - `test_scan_history.json`
5. Triage failures:
   - **Selector mismatch / text drift**: fix the script, retry
   - **Test logic bug**: fix the script, retry
   - **Real app bug, fix <2h**: fix in scope (per SPRINT_STOPPING_CRITERIA.md §4a)
   - **Real app bug, fix >2h or new design**: log as new candidate, defer to Sprint 36
6. Update `mobile-app/test/winwright/README.md` Status column with PASS/FAIL/DEFERRED per script
7. Document the triage results in this plan's "Manual Testing Notes" section before Phase 7

**Acceptance criteria**:
- [ ] Fresh Windows desktop dev build runs successfully
- [ ] All 7 WinWright scripts have a recorded PASS / FAIL+fixed / DEFERRED outcome
- [ ] At least 5 of 7 scripts reach PASS state by sprint end (allow 2 deferrals for newly-discovered work)
- [ ] README.md Status column updated
- [ ] Any deferred work documented as new candidate in master plan

---

## Task Summary Table

| # | Task | Estimate | Model | Dependencies |
|---|------|---------|-------|--------------|
| 1 | BUG-S34-1: stale test assertion fix | ~10min | Haiku | None |
| 2 | F69: WinWright E2E execution + triage | ~6-8h | Sonnet | Task 1 (green baseline) |

**Total estimate**: ~6-9h. Small intentional scope (recovery sprint).

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| F69 scripts fail en masse (selector drift since Sprint 34) | Medium | Medium | Triage per script; fix small drift, defer large rework |
| F69 execution surfaces new app bugs needing >2h | Low-Medium | Medium | Per §4a, defer to Sprint 36 with backlog entry |
| Windows desktop build flakiness (build-windows.ps1) | Low | Low | Established workflow, retry once on failure |
| Screen reader flag / WinWright doctor failure | Low | High | Documented in README; rerun setup script |

---

## Architecture Impact Check (Phase 3.6.1)

**Reviewed against**:
- `docs/ARCHITECTURE.md`: No documented components affected. F69 adds test execution only. BUG-S34-1 fixes one test assertion.
- `docs/ARSD.md`: No requirements or design specifications affected.
- `docs/adr/*.md`: ADR-0037 (UI/Accessibility Standards from Sprint 34) is *validated* by F69 execution but not modified.

**Result**: **No architecture impact.** No ADR/ARCHITECTURE/ARSD updates anticipated.

---

## Dependency Vulnerability Check (Phase 2.6 result)

- **Discontinued**: `js` (transitive only) -- no urgent action, monitor
- **Available updates**: 31 minor/patch (no security flags)
- **Action**: None this sprint

---

## Sprint Stopping Criteria

Per `docs/SPRINT_STOPPING_CRITERIA.md`. Stop only for:
1. All tasks complete
2. Blocked on external dependency (e.g., WinWright tooling failure)
3. User requests scope change
4. Critical bug found (e.g., F69 reveals data-corruption bug)
5. User requests early review
6. Sprint review complete
7. Fundamental design failure
8. Context > 95%
9. Time limit reached

**4a applies**: User-found gap in sprint theme (same category, <2h, no new design) extends scope without stopping.

---

## Carry-ins from Previous Sprint Retrospective

From Sprint 34 retro Category 13 (Minor Function Updates for Sprint 35):
- (None recorded; Sprint 34 retro Category 14 items routed to backlog as F76, F77, F78)

---

## Manual Testing Notes

*(To be populated during Phase 5)*

### F69 Script Triage Results
*(Filled in during Task 2 execution)*

| Script | Result | Notes |
|--------|--------|-------|
| test_navigation.json | TBD | |
| test_manual_scan_flow.json | TBD | |
| test_settings_tabs.json | TBD | |
| test_text_selection.json | TBD | |
| test_f56_create_block_rule.json | TBD | |
| test_f56_create_safe_sender.json | TBD | |
| test_scan_history.json | TBD | |
