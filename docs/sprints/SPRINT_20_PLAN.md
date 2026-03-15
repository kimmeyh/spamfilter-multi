# Sprint 20 Plan

**Sprint**: Sprint 20 - Gmail Fix, Demo Scan, Rules UI, Performance, and Cleanup
**Date**: March 15, 2026
**Branch**: `feature/20260315_Sprint_20`
**Base**: `develop`
**Estimated Total Effort**: ~24-36h

---

## Sprint Goal

Fix Gmail folder scanning errors, expand Demo Scan sample data, overhaul the Manage Rules UI with split views and search/filter, speed up Add Rule performance from scan results, and clean up pre-existing analyzer warnings.

---

## Tasks

### Task A: Gmail Folder Scan Errors (Bug #12)

**Issue**: [#184](https://github.com/kimmeyh/spamfilter-multi/issues/184)
**Estimated Effort**: ~2-4h
**Model**: Sonnet
**Value**: This fixes a blocking bug that prevents Gmail users from scanning folders.

**Acceptance Criteria**:
- [ ] Root cause identified for Gmail folder scan errors
- [ ] Fix implemented and tested with Gmail IMAP account
- [ ] Gmail OAuth and Gmail App Password (IMAP) paths both handle folder listing correctly
- [ ] No regression on AOL or other provider folder scanning
- [ ] Unit/integration tests added for Gmail folder handling

**Risks**: Medium - may require changes to GenericIMAPAdapter or GmailApiAdapter folder listing logic. Gmail IMAP uses `[Gmail]/` prefix for special folders which may differ from standard IMAP.

---

### Task B: Demo Scan Expanded Sample Data (Enhancement #13)

**Issue**: [#185](https://github.com/kimmeyh/spamfilter-multi/issues/185)
**Estimated Effort**: ~4-6h
**Model**: Haiku
**Value**: This enables new users to see all app capabilities through a realistic demo without needing a live email account.

**Acceptance Criteria**:
- [ ] Demo scan includes at least 3 Safe Sender - Exact Email examples using 3 different email providers (e.g., Gmail, Yahoo, Outlook)
- [ ] Demo scan includes at least 3 Safe Sender - Exact Domain examples using made-up addresses from: irs.gov, allstate.com, venmo.com
- [ ] Demo scan includes at least 3 Block Rule - Block Email examples using 3 different email providers (different providers from safe sender examples)
- [ ] Demo scan includes at least 3 Block Rule - Block Entire Domain examples using domains from existing block rules in rules.yaml
- [ ] Safe Sender and Block Rule provider examples do not overlap (different providers for each)
- [ ] Examples use realistic sender names and subject lines
- [ ] Demo scan results demonstrate all filter categories in results screen
- [ ] Existing demo scan tests updated for new sample data
- [ ] All tests pass after changes

**Risks**: Low - additive changes to mock_email_data.dart with clear requirements.

---

### Task C: Manage Rules UI Overhaul (Enhancement #2)

**Issue**: [#149](https://github.com/kimmeyh/spamfilter-multi/issues/149)
**Estimated Effort**: ~12-16h
**Model**: Sonnet
**Value**: This enables users to effectively manage large rule sets by splitting combined rules into separate views with search and filter capabilities.

**Acceptance Criteria**:
- [ ] Combined rules split into separate views (block rules vs safe senders, or by rule type)
- [ ] Search functionality for filtering rules by name, pattern, or domain
- [ ] Filter capability (e.g., by rule type, enabled/disabled status)
- [ ] Existing rule management functionality preserved (edit, delete, enable/disable)
- [ ] UI is responsive and handles large rule sets (400+ rules) without lag
- [ ] All existing tests pass, new tests for search/filter logic
- [ ] Account-scoped: rules display correctly per account context

**Risks**: Medium - touches core UI for rule management, must not break existing edit/delete workflows.

---

### Task D: Scan Results - Speed Up Add Rule Performance (Enhancement #10)

**Issue**: [#186](https://github.com/kimmeyh/spamfilter-multi/issues/186)
**Estimated Effort**: ~4-6h
**Model**: Sonnet
**Value**: This improves UX when users add rules from scan results, reducing wait time for rule addition and re-evaluation.

**Acceptance Criteria**:
- [ ] Profiled Add Rule action to identify performance bottleneck
- [ ] Optimized the slow path (rule addition, re-evaluation, or UI rebuild)
- [ ] Add Rule completes noticeably faster than current baseline
- [ ] No regression in rule accuracy or scan results display
- [ ] All tests pass

**Risks**: Low - performance optimization with clear before/after measurement.

---

### Task E: Clean Up Analyzer Warnings in Test Files (Tech Debt #11)

**Issue**: [#187](https://github.com/kimmeyh/spamfilter-multi/issues/187)
**Estimated Effort**: ~2-4h
**Model**: Haiku
**Value**: This improves signal-to-noise ratio for `flutter analyze`, making new warnings immediately visible.

**Acceptance Criteria**:
- [ ] All addressable analyzer warnings in test files resolved
- [ ] No new warnings introduced
- [ ] All tests still pass after cleanup
- [ ] `flutter analyze` warning count reduced significantly (target: <10 remaining)

**Risks**: Low - mechanical cleanup, no logic changes.

---

## Execution Order

1. **Task A** (Gmail folder fix - bug fix first, higher risk)
2. **Task E** (Analyzer warnings cleanup - quick win, low risk)
3. **Task B** (Demo scan data - additive, low risk)
4. **Task D** (Add Rule performance - profile and optimize)
5. **Task C** (Manage Rules UI overhaul - largest task, last)

---

## Sprint Scope Notes

- **Total estimated effort**: ~24-36h across 5 tasks
- **Ambitious sprint**: Task C is the largest item; if time runs short it may carry over
- **Dependencies**: None between tasks, but execution order optimizes for quick wins first
