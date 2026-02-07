# Sprint 3 Plan: Safe Sender Exceptions

**Sprint**: Sprint 3
**Date**: January 24, 2026
**Focus**: Safe Sender Exceptions - Domain safe senders with email/subdomain exceptions
**Duration**: Estimated 10-14 hours
**Status**: 🔵 PLANNED - Ready for kickoff

---

## Executive Summary

Sprint 3 adds exception support to safe senders, enabling fine-grained whitelist control. For example, allow emails from a trusted company domain (@company.com) except for specific email addresses or subdomains that have been compromised or should not be trusted.

This feature builds on Sprint 2's database foundation and maintains the dual-write pattern (database + YAML export).

---

## Sprint Objectives

### Primary Goals
1. [OK] Implement SafeSenderDatabaseStore with exception support
2. [OK] Create SafeSenderEvaluator with exception matching logic
3. [OK] Update UI for managing safe sender exceptions
4. [OK] Comprehensive testing for exception scenarios

### Secondary Goals
- Maintain zero regressions in existing tests
- Keep YAML export working with new exception fields
- Clear documentation of exception patterns and use cases

---

## Task Breakdown

### **Task A: Implement SafeSenderDatabaseStore**
**Model Assignment**: 🟢 Haiku
**Complexity**: Low-Medium
**Estimated Time**: 2-3 hours

**Description**:
- Create `lib/core/storage/safe_sender_database_store.dart`
- CRUD operations for safe_senders table
- JSON serialization for exception_patterns field
- Handle pattern type detection (email, domain, subdomain)
- Proper error handling with custom exceptions

**Acceptance Criteria**:
- [ ] SafeSenderDatabaseStore fully implements safe sender CRUD
- [ ] JSON serialization works for exception_patterns array
- [ ] All CRUD operations tested (add, remove, get, update)
- [ ] Pattern type detection working (email vs domain vs subdomain)
- [ ] Tests: 10+ unit tests, 90%+ pass rate

**Key Files**:
- `lib/core/storage/safe_sender_database_store.dart` (NEW, ~250 lines)
- `test/unit/storage/safe_sender_database_store_test.dart` (NEW, ~350 lines)

---

### **Task B: Implement SafeSenderEvaluator with Exceptions**
**Model Assignment**: 🟠 Sonnet
**Complexity**: Medium
**Estimated Time**: 3-4 hours

**Description**:
- Create `lib/core/services/safe_sender_evaluator.dart`
- Evaluate email against safe sender pattern
- Check exceptions if pattern matches
- Return true only if no exception matches
- Handle regex compilation and caching
- Support email, domain, and subdomain patterns

**Pattern Matching Logic**:
```
1. Load safe sender pattern (e.g., @company.com)
2. Try to match email against pattern
3. If no match: return FALSE (not a safe sender)
4. If match: load exception patterns
5. For each exception: try to match email
6. If any exception matches: return FALSE
7. If no exception matches: return TRUE
```

**Example Use Cases**:
- Safe sender: `@company.com`, Exception: `spammer@company.com`
  - Result: `user@company.com` → TRUE (safe), `spammer@company.com` → FALSE
- Safe sender: `@company.com`, Exception: `@marketing.company.com`
  - Result: `user@company.com` → TRUE, `user@marketing.company.com` → FALSE

**Acceptance Criteria**:
- [ ] SafeSenderEvaluator correctly evaluates patterns with exceptions
- [ ] Email exact match exceptions working
- [ ] Domain/subdomain exceptions working
- [ ] Multiple exceptions supported
- [ ] Regex patterns compiled and cached
- [ ] Tests: 15+ unit tests covering all scenarios

**Key Files**:
- `lib/core/services/safe_sender_evaluator.dart` (NEW, ~200 lines)
- `test/unit/services/safe_sender_evaluator_test.dart` (NEW, ~400 lines)

---

### **Task C: Update RuleSetProvider to Use SafeSenderDatabaseStore**
**Model Assignment**: 🟢 Haiku
**Complexity**: Low
**Estimated Time**: 2-3 hours

**Description**:
- Update RuleSetProvider to load safe senders from SafeSenderDatabaseStore
- Replace LocalRuleStore safe sender loading with database loading
- Maintain dual-write pattern: database-first, YAML-second
- Update addSafeSender and removeSafeSender methods to include exceptions
- Test with existing 262+ tests to ensure no regressions

**Changes to RuleSetProvider**:
- Import SafeSenderDatabaseStore
- Replace `_ruleStore.loadSafeSenders()` with `_databaseStore.loadSafeSenders()`
- Update CRUD methods to save to database first
- Continue YAML export for version control

**Acceptance Criteria**:
- [ ] RuleSetProvider loads safe senders from database
- [ ] YAML export still working
- [ ] All existing tests passing (262+)
- [ ] No regressions in rule evaluation

**Key Files**:
- `lib/core/providers/rule_set_provider.dart` (MODIFIED, ~30-50 lines)

---

### **Task D: Create UI for Managing Safe Sender Exceptions**
**Model Assignment**: 🟢 Haiku
**Complexity**: Medium
**Estimated Time**: 3-4 hours

**Description**:
- Create `lib/ui/screens/safe_sender_list_screen.dart` (if not exists)
- List all safe sender patterns
- Show exceptions for each pattern
- Add/remove exception patterns UI
- Modal or expandable UI for exception management
- Search and filter safe senders

**UI Flow**:
1. Safe Senders List Screen
   - Shows: Pattern, Pattern Type, Exception Count
   - Actions: Add, Edit, Delete, Expand
2. Safe Sender Details (Expanded)
   - Show pattern details
   - List exceptions with "Remove" buttons
   - "Add Exception" button
3. Add Exception Modal
   - Input: Exception pattern
   - Type selector: Email, Domain, Subdomain (auto-detect)
   - Save button

**Acceptance Criteria**:
- [ ] Safe sender list screen showing all patterns
- [ ] Exception display working
- [ ] Add exception functionality working
- [ ] Remove exception functionality working
- [ ] Search/filter working for large lists
- [ ] UI responsive on Android and Windows

**Key Files**:
- `lib/ui/screens/safe_sender_list_screen.dart` (NEW, ~400 lines)
- `lib/ui/widgets/exception_input_widget.dart` (NEW, ~150 lines - optional)

---

### **Task E: Integration Testing**
**Model Assignment**: 🟢 Haiku
**Complexity**: Medium
**Estimated Time**: 2-3 hours

**Description**:
- Create comprehensive test suite for safe sender exceptions
- Test database persistence
- Test SafeSenderEvaluator with various exception scenarios
- Test UI interactions
- Regression testing with existing 262+ tests

**Test Scenarios**:
1. Domain safe sender with email exception
   - Safe sender: `@company.com`
   - Exception: `spammer@company.com`
   - Test: `user@company.com` is safe, `spammer@company.com` is not

2. Domain safe sender with subdomain exception
   - Safe sender: `@company.com`
   - Exception: `@marketing.company.com`
   - Test: `user@company.com` is safe, `user@marketing.company.com` is not

3. Multiple exceptions
   - Safe sender: `@company.com`
   - Exceptions: `spammer1@company.com`, `@temp.company.com`
   - Test: Both exceptions work correctly

4. Persistence
   - Add safe sender with exceptions
   - Close app, reopen
   - Verify exceptions still present

5. YAML Export
   - Add safe sender with exceptions
   - Check rules_safe_senders.yaml
   - Verify format

**Acceptance Criteria**:
- [ ] 15+ integration tests passing
- [ ] All exception scenarios covered
- [ ] Database persistence verified
- [ ] YAML export verified
- [ ] Zero regressions in existing tests (262+)

**Key Files**:
- `test/integration/safe_sender_exception_test.dart` (NEW, ~500 lines)

---

## Database Schema Updates

The safe_senders table already supports exceptions (from Sprint 2):

```sql
CREATE TABLE safe_senders (
  id INTEGER PRIMARY KEY,
  pattern TEXT NOT NULL UNIQUE,
  pattern_type TEXT NOT NULL,           -- 'email', 'domain', 'subdomain'
  exception_patterns TEXT,               -- JSON array of exception patterns
  date_added INTEGER NOT NULL,
  created_by TEXT DEFAULT 'manual'
);
```

**Example Records**:
```
pattern: @company.com
pattern_type: domain
exception_patterns: ["spammer@company.com", "@marketing.company.com"]

pattern: user@example.com
pattern_type: email
exception_patterns: null
```

---

## YAML Export Format

Safe senders in YAML (rules_safe_senders.yaml) will NOT include exceptions (too complex for manual editing). Database is source of truth for exceptions.

```yaml
safe_senders:
  - "^[^@\\s]+@(?:[a-z0-9-]+\\.)*company\\.com$"
  - "^user@example\\.com$"
```

Exceptions are preserved in database, not exported to YAML.

---

## Model Assignment & Complexity

| Task | Model | Complexity | Confidence | Hours |
|------|-------|-----------|-----------|-------|
| A | Haiku | Low-Medium | 90% | 2-3 |
| B | Sonnet | Medium | 85% | 3-4 |
| C | Haiku | Low | 95% | 2-3 |
| D | Haiku | Medium | 80% | 3-4 |
| E | Haiku | Medium | 85% | 2-3 |

**Total Estimated Effort**: 12-17 hours (conservative estimate)
**Realistic Effort**: 10-14 hours (with Sprint 2 learnings)

---

## Success Criteria for Sprint 3

### Code Quality
- [OK] All new tests passing (40+ tests)
- [OK] Zero code analysis errors
- [OK] Zero regressions in existing 262+ tests
- [OK] Final: 302+ tests passing

### Functionality
- [OK] Safe sender exceptions working in database
- [OK] SafeSenderEvaluator correctly handles all exception scenarios
- [OK] UI allows adding/removing exceptions
- [OK] YAML export maintains safe sender patterns

### Documentation
- [OK] Code comments explain exception matching logic
- [OK] Test comments document exception scenarios
- [OK] PR description clearly describes changes

### Process
- [OK] Time tracking logged (using sprint card template from Sprint 2)
- [OK] All commits pushed to remote
- [OK] Sprint review conducted (Phase 4.5)
- [OK] GitHub issues closed

---

## Dependencies & Blockers

### Dependencies
- [OK] Sprint 1 & 2: Database and RuleSetProvider complete
- [OK] safe_senders table already supports exceptions field
- [OK] All required infrastructure in place

### Potential Blockers
- None identified for core functionality
- UI complexity depends on framework features (expandable lists, modals)

---

## Risks & Mitigations

### Risk 1: Regex Complexity with Exceptions
**Probability**: Medium
**Impact**: Medium
**Mitigation**: Comprehensive test suite, clear documentation of pattern format

### Risk 2: UI Performance with Large Exception Lists
**Probability**: Low
**Impact**: Low
**Mitigation**: Implement pagination if needed, lazy loading

### Risk 3: YAML Export Complexity
**Probability**: Low
**Impact**: Low
**Mitigation**: Exclude exceptions from YAML (database is source of truth)

---

## Next Steps (After Sprint 3 Approval)

Sprint 4 will likely focus on:
- Scan Results Persistence (if not started)
- Email action recording
- Unmatched email processing
- Results history and statistics

---

## References

- **Phase 3.5 Plan**: Safe Sender Exceptions (from earlier phase planning)
- **Sprint 2 Retrospective**: `docs/SPRINT_2_RETROSPECTIVE.md`
- **Sprint Execution Workflow**: `docs/SPRINT_EXECUTION_WORKFLOW.md`
- **Database Helper**: `lib/core/storage/database_helper.dart`

---

**Version**: 1.0
**Created**: January 24, 2026
**Status**: 🔵 PLANNED - Ready for Phase 1 Kickoff
