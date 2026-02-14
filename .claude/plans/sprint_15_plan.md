# Sprint 15 Plan: Bug Fix - 100 Delete Limit

**Sprint Number**: 15
**Branch**: `feature/20260214_Sprint_15`
**Start Date**: February 14, 2026
**Status**: PLANNING

---

## Sprint Objective

Fix critical bug where email scan stops after deleting exactly 100 emails, preventing full inbox processing.

---

## Issues

### Issue #145: Bug - Scan stops after deleting 100 emails (HIGH PRIORITY)
**Priority**: Critical
**Type**: Bug Fix
**Estimated Effort**: 4-8 hours

**Problem Statement**:
When running manual scan with "Process Safe Senders and Rules" mode, the scan stops processing after exactly 100 delete operations. Safe sender moves do not count toward this limit.

**Test Data**:
| Test | Found | Processed | Deleted | Safe |
|------|-------|-----------|---------|------|
| 1 | - | 102 | 100 | - |
| 2 | - | 106 | 100 | - |
| 3 | 491 | 105 | 100 | 4 |

**Root Cause Hypothesis**:
- AOL IMAP server rate limiting on MOVE commands
- IMAP connection dropping silently after 100 operations
- Server error not being propagated correctly

**Tasks**:

#### Task A: Investigation and Logging (Sonnet)
- Add detailed logging around IMAP MOVE operations
- Log connection state before/after each delete
- Capture any IMAP server responses/errors
- Test with enhanced logging to identify exact failure point

**Acceptance Criteria**:
- [ ] Logging captures exact point of failure
- [ ] IMAP server response logged for each MOVE
- [ ] Connection state verified after operations

#### Task B: Implement Fix (Sonnet)
Based on investigation, implement one of:
1. **Reconnect Strategy**: Reconnect IMAP session every N deletes (e.g., 50)
2. **Error Recovery**: Catch connection drops and reconnect automatically
3. **Batch Operations**: Use IMAP message sequence sets for batch moves
4. **Rate Limiting**: Add delay between operations if server throttling

**Acceptance Criteria**:
- [ ] Scan processes >100 delete operations successfully
- [ ] Errors are caught and handled gracefully
- [ ] User notified of any partial failures
- [ ] Progress continues after recoverable errors

#### Task C: Testing (Haiku)
- Test with AOL account having >100 spam emails
- Verify scan completes all found emails
- Test error recovery scenarios
- Add unit/integration tests for new functionality

**Acceptance Criteria**:
- [ ] Manual testing confirms >100 deletes work
- [ ] New tests cover reconnect/retry logic
- [ ] All existing tests pass (939+)
- [ ] Analyzer warnings remain <50

---

### Issue #144: Performance - Batch Email Processing (OPTIONAL - if time permits)
**Priority**: Medium
**Type**: Enhancement
**Estimated Effort**: 6-10 hours (DEFER if #145 takes full sprint)

**Note**: Only include if #145 fix is quick. Otherwise defer to Sprint 16.

---

## Sprint Schedule

| Phase | Task | Status |
|-------|------|--------|
| 1 | Sprint Kickoff & Planning | IN PROGRESS |
| 2.A | Investigation and Logging | PENDING |
| 2.B | Implement Fix | PENDING |
| 2.C | Testing | PENDING |
| 3 | Code Review & Testing | PENDING |
| 4 | Push & Create PR | PENDING |
| 4.5 | Sprint Review | PENDING |

---

## Model Assignments

| Task | Model | Rationale |
|------|-------|-----------|
| Task A (Investigation) | Sonnet | Debugging, log analysis |
| Task B (Implementation) | Sonnet | IMAP protocol, error handling |
| Task C (Testing) | Haiku | Test writing, validation |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Root cause different than expected | Medium | Medium | Thorough investigation first |
| AOL-specific issue not reproducible | Low | High | Test with actual AOL account |
| Fix causes regression | Low | Medium | Run full test suite |
| IMAP reconnect breaks other flows | Low | Medium | Test all scan modes |

---

## Dependencies

- AOL account with >100 spam emails for testing
- Access to IMAP server logs (if available)
- Sprint 14 complete (PR #143 merged)

---

## Success Criteria

- [ ] Issue #145 resolved - scans process >100 deletes
- [ ] All tests passing (939+)
- [ ] Analyzer warnings <50
- [ ] Manual testing confirms fix
- [ ] PR created and ready for review

---

## Notes

- This is a focused bug-fix sprint
- #144 (batch processing) may naturally emerge from #145 fix
- Keep scope tight to ensure quality fix
