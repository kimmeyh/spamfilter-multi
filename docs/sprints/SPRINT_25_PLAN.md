# Sprint 25 Plan

**Sprint**: Sprint 25 - Safe Sender Bug Fixes + Quality Improvements
**Date**: March 22, 2026
**Branch**: `feature/20260322_Sprint_25`
**Base**: `main`
**Issue**: #202
**Estimated Total Effort**: ~18-35h

---

## Sprint Goal

Fix safe sender scanning bugs found during Sprint 24 testing, improve scan status UX, add re-process capability after rule changes, and improve test coverage.

---

## Tasks

### Task A: Scan Mode Enum Rename (~1h)

**Model**: Haiku
**Execution**: Autonomous

Rename scan mode enum values for clarity:
- `testLimit` -> `rulesOnly`
- `testAll` -> `safeSendersOnly`
- `fullScan` -> `safeSendersAndRules`

Update all references in code, tests, and docs.

**Acceptance Criteria**:
- [ ] Enum values renamed
- [ ] All references updated
- [ ] All tests passing
- [ ] No functional changes

### Task B: F40 - Gmail IMAP Safe Sender Results Bug (Issue #198, ~2-4h)

**Model**: Haiku
**Execution**: Autonomous

Fix safe sender matches showing in results when emails are already in the safe sender folder (INBOX) for Gmail IMAP accounts.

**Acceptance Criteria**:
- [ ] Debug logging added to identify root cause
- [ ] Root cause identified and fixed
- [ ] Safe sender emails in INBOX skipped during Gmail IMAP scan
- [ ] Tests added for the fix
- [ ] INBOX/Inbox/inbox treated case-insensitively

### Task C: F41 - AOL Bulk Mail Safe Sender Move Bug (Issue #201, ~2-4h)

**Model**: Haiku
**Execution**: Autonomous

Fix safe sender emails in AOL Bulk Mail folder not being moved to the safe sender folder (Inbox).

**Acceptance Criteria**:
- [ ] Debug logging added to identify root cause
- [ ] Root cause identified and fixed
- [ ] Safe sender emails in non-safe-sender folders are moved during scan
- [ ] Tests added for the fix

### Task D: F30 - Safe Senders "Exact Domain" Filter 0 Results (~1-2h)

**Model**: Haiku
**Execution**: Autonomous

Fix SafeSenderCategory "Exact Domain" filter chip returning 0 results.

**Acceptance Criteria**:
- [ ] Root cause identified (classification vs filter logic)
- [ ] Fix applied
- [ ] Exact domain patterns show correct count in filter chip
- [ ] Tests added

### Task E: F31 - Background Scan Task Deleted on Rebuild (~4-6h)

**Model**: Haiku
**Execution**: Autonomous

Fix Windows Task Scheduler entry being lost after flutter clean/rebuild.

**Acceptance Criteria**:
- [ ] Task Scheduler entry survives flutter clean and rebuild
- [ ] App detects missing scheduled task and recreates on launch
- [ ] Tests added

### Task F: F34 - Live Scan: In-Progress/Completed Status Indicator (~2-4h)

**Model**: Haiku
**Execution**: Autonomous

Add visual indicator showing scan status (in-progress vs completed). Position at the top of results screen, near or above the filter tabs. Research platform best practices for status indicators across Windows 11, Android, and iOS.

**Acceptance Criteria**:
- [ ] Platform best practices researched (W11, Android, iOS)
- [ ] Status indicator visible at top of results screen (near/above filter tabs)
- [ ] Shows in-progress state during scan (animated/dynamic)
- [ ] Shows completed state after scan finishes
- [ ] Consistent with platform conventions
- [ ] Tests added

### Task G: F38 - Live Scan: Re-process Emails After Rule Changes (~8-12h)

**Model**: Sonnet
**Execution**: Autonomous

Enable re-evaluation of scan results when rules are changed during a scan session (e.g., after adding a block rule or safe sender from the results screen).

**Acceptance Criteria**:
- [ ] After adding a rule/safe sender, remaining results re-evaluated
- [ ] Updated results reflect new rule immediately
- [ ] Performance acceptable for large result sets
- [ ] Tests added

### Task H: F32 - Test Coverage Analysis + Sprint 20 Feature Tests (~4-6h)

**Model**: Haiku
**Execution**: Autonomous

Analyze test coverage gaps, particularly for Sprint 20 features, and add missing tests.

**Acceptance Criteria**:
- [ ] Coverage gaps identified
- [ ] Priority gaps filled with new tests
- [ ] All tests passing

---

## Execution Order

```
Task A (enum rename) -> Task B (F40 Gmail bug) -> Task C (F41 AOL bug) ->
Task D (F30 filter) -> Task E (F31 Task Scheduler) -> Task F (F34 indicator) ->
Task G (F38 re-process) -> Task H (F32 test coverage)
```

## Dependencies

```
Task A ──> Task B (clearer enums make debugging easier)
Task A ──> Task C (same reason)
Task D: independent
Task E: independent
Task F: independent
Task G: independent (but benefits from A-C fixes)
Task H: last (captures any new gaps from A-G)
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Safe sender bug has deeper root cause | Medium | Medium | Debug logging first, then fix |
| Task G (re-process) scope creep | Medium | High | Timebox, implement simple version first |
| Task Scheduler fix requires elevated permissions | Low | Medium | Test with/without admin |

**Risk Level**: Low-Medium
