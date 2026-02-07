# Sprint 2: Rule Management Migration

**Status**: Ready for Kickoff
**Planned Start**: After Sprint 1 PR approval and merge
**Duration**: 2 weeks (estimated)
**Goal**: Replace YAML-based rule loading with database, implement auto-export to YAML

---

## Sprint Overview

Sprint 2 builds on the database foundation (Sprint 1) to migrate rule management from YAML files to SQLite database. The key focus is maintaining backward compatibility while enabling database-first rule editing.

### Key Deliverables
1. **RuleDatabaseStore** - CRUD operations for rules table
2. **RuleSetProvider migration** - Switch from YAML to database while preserving existing functionality
3. **YAML auto-export** - Dual-write pattern: database changes automatically export to YAML
4. **Regression testing** - Ensure all 122+ existing tests pass
5. **Complete rule evaluation chain** - Update RuleEvaluator to use database rules

---

## Tasks Breakdown

**Granularity Guidance**: Tasks keep tight dependencies together. If a task exceeds ~500 lines, consider breaking into subtasks (A1, A2, A3) while maintaining dependency cohesion.

### **Task A: Implement RuleDatabaseStore**
**Assigned Model**: Haiku
**Complexity**: Low (Straightforward CRUD following DatabaseHelper pattern)
**Estimated Time**: 3-4 hours (Calibrated: ~1.5-2 hours based on Sprint 1 data)
**Expected Lines**: 200-300 (will not exceed granularity threshold)

**Description**:
Create new database storage layer for rules that mirrors the existing `LocalRuleStore` API but reads/writes to SQLite instead of YAML.

**Acceptance Criteria**:
- [ ] `lib/core/storage/rule_database_store.dart` created (200-300 lines)
- [ ] Methods for:
  - `loadRules()` - Query all rules from database
  - `saveRules(RuleSet)` - Insert/update rules in database
  - `getRule(String name)` - Get single rule
  - `addRule(Rule)` - Add new rule
  - `deleteRule(String name)` - Delete rule
  - `updateRule(Rule)` - Update existing rule
- [ ] JSON serialization for arrays (conditions, actions, exceptions)
- [ ] Zero code analysis issues
- [ ] Unit tests for all CRUD operations

**Files to Create**:
- `lib/core/storage/rule_database_store.dart`

**Files to Modify**:
- `test/unit/storage/rule_database_store_test.dart` (new test file)

**Dependencies**:
- Sprint 1: DatabaseHelper (database_helper.dart)
- Sprint 1: EvaluationResult model

---

### **Task B: Update RuleSetProvider to use Database**
**Assigned Model**: Sonnet
**Complexity**: Medium (Refactor existing provider, maintain compatibility)
**Estimated Time**: 4-5 hours (Calibrated: ~2-2.5 hours based on Sprint 1 data)
**Expected Lines**: 150-200 (refactoring only, minimal new code)
**Granularity Note**: This is a refactoring task with tight dependencies to Task A. Keep together despite code changes (does not add new implementation, only changes initialization and internal dependencies).

**Description**:
Refactor `RuleSetProvider` to load rules from database via `RuleDatabaseStore` instead of `LocalRuleStore`. Must preserve existing ChangeNotifier pattern and all mutations.

**Key Changes**:
- Replace `LocalRuleStore` with `RuleDatabaseStore` initialization
- Update `loadRules()` to query database
- Update all rule mutation methods to write to database
- Trigger YAML auto-export after mutations
- Maintain backward compatibility with existing UI consumers

**Acceptance Criteria**:
- [ ] RuleSetProvider loads rules from database on initialization
- [ ] All rule mutations (add, update, delete) write to database
- [ ] ChangeNotifier listeners notified on changes
- [ ] Provider state consistent with database state
- [ ] No breaking changes to existing UI screens
- [ ] All 122+ existing tests pass
- [ ] New database-specific tests added

**Files to Modify**:
- `lib/core/providers/rule_set_provider.dart`
- Test files: Update imports and verification
- Test files: Add new database-specific tests

**Dependencies**:
- Task A: RuleDatabaseStore implementation
- Sprint 1: DatabaseHelper
- Existing: RuleSet model

**Blockers to Watch**:
- If RuleDatabaseStore incomplete, Task B blocked
- If existing tests fail, must fix before proceeding

---

### **Task C: Implement YAML Auto-Export**
**Assigned Model**: Haiku
**Complexity**: Low (Reverse of YAML import from Sprint 1)
**Estimated Time**: 2-3 hours (Calibrated: ~1-1.5 hours based on Sprint 1 data)
**Expected Lines**: 150-200 (follows MigrationManager pattern from Sprint 1)
**Granularity Note**: This is new implementation that extends Sprint 1's MigrationManager. Keep with its own tests; could be split if exceeds 500 lines, but unlikely given pattern.

**Description**:
Create service to export database rules back to YAML format whenever rules change. Maintains version control friendly YAML files as backup/reference.

**Implementation Pattern**:
- After successful rule mutation in RuleSetProvider
- Call `YamlExporter.exportRules()`
- Export to same location: `app_support_dir/rules.yaml`
- Create timestamped backup of previous version

**YAML Export Invariants** (from existing LocalRuleStore):
1. Lowercase conversion
2. Trimmed whitespace
3. De-duplication
4. Alphabetical sorting
5. Single quotes (avoid backslash escaping)
6. Timestamped backups to `Archive/` before overwrite

**Acceptance Criteria**:
- [ ] `lib/core/storage/yaml_exporter.dart` created (150-200 lines)
- [ ] `exportRules(RuleSet)` method generates YAML in correct format
- [ ] Exported YAML matches format of `rules.yaml`
- [ ] Timestamped backup created before export
- [ ] Error handling for permission/disk space issues
- [ ] Zero code analysis issues
- [ ] Tests verify export format correctness

**Files to Create**:
- `lib/core/storage/yaml_exporter.dart`

**Files to Modify**:
- `lib/core/providers/rule_set_provider.dart` (add auto-export call)
- `test/unit/storage/yaml_exporter_test.dart` (new test file)

**Dependencies**:
- Sprint 1: YamlService (for format reference)
- Sprint 1: AppPaths (for file location)
- Task A: RuleDatabaseStore

---

### **Task D: Update RuleEvaluator Integration**
**Assigned Model**: Haiku
**Complexity**: Low (Minimal change, already abstracted)
**Estimated Time**: 1-2 hours

**Description**:
Verify RuleEvaluator uses rules from RuleSetProvider without changes. RuleEvaluator is provider-agnostic, so database change transparent to it.

**Acceptance Criteria**:
- [ ] RuleEvaluator continues to work with RuleSetProvider
- [ ] No code changes to RuleEvaluator needed
- [ ] All existing RuleEvaluator tests pass
- [ ] Integration test: Load rules from database → Evaluate email → Correct result

**Files to Modify**:
- `lib/core/services/email_scanner.dart` - Verify integration (should be no changes)
- Tests: Verify existing tests still pass

**Dependencies**:
- Task B: RuleSetProvider using database
- Sprint 1: DatabaseHelper, RuleSet model

---

### **Task E: Regression Testing - All 122+ Tests Pass**
**Assigned Model**: Haiku
**Complexity**: Medium (Debugging failures, not new code)
**Estimated Time**: 2-3 hours

**Description**:
Run complete test suite multiple times throughout sprint to ensure no regressions. Address any test failures immediately.

**Test Stages**:
1. **After Task A**: Unit tests for RuleDatabaseStore
2. **After Task B**: RuleSetProvider tests + all existing rule-related tests
3. **After Task C**: YAML export tests
4. **Final**: Complete `flutter test` - all tests pass

**Acceptance Criteria**:
- [ ] All 122+ existing tests passing
- [ ] All new Sprint 2 tests passing (40+ new)
- [ ] No regressions in rule evaluation
- [ ] No regressions in UI screens using rules
- [ ] Code coverage maintained or improved

**Commands**:
```bash
flutter test                    # All tests
flutter test --coverage         # With coverage report
flutter analyze                 # No errors/warnings
```

**Dependencies**:
- Tasks A-D complete
- All code changes committed

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| **Tasks Complete** | 5/5 | ⏳ Pending |
| **Tests Passing** | 122+/122+ | ⏳ Pending |
| **Code Analysis Issues** | 0 | ⏳ Pending |
| **Code Review** | Approved | ⏳ Pending |
| **Lines Added** | 400-600 | ⏳ Pending |
| **Commits** | 4-5 | ⏳ Pending |

---

## Effort Calibration (Based on Sprint 1 Data)

**Sprint 1 Actual vs Estimated**:
- Estimated: 9-13 hours
- Actual: ~4 hours
- Variance: Estimates were 2.3x-3.25x higher due to conservative safety margins

**Sprint 2 Calibrated Estimates**:
When requirements are detailed (as with Sprint 2 plan):
- Original Task Estimates: 14-17 hours
- Calibrated Estimates: 5.5-7 hours (30-40% of conservative estimate)
- Rationale: Clear requirements + proven model assignments = efficient execution

**Note**: These calibrated estimates will be refined after each sprint. Track actual vs estimated time in GitHub issue comments during execution.

---

## Risk Assessment

### **High Confidence (>80%)**
- Task A (RuleDatabaseStore) - Straightforward CRUD, follows Sprint 1 patterns
- Task C (YAML export) - Reverse of migration, well-defined format
- Task D (RuleEvaluator) - No changes needed, well abstracted
- Task E (Testing) - Standard testing, no unknowns

### **Medium Confidence (70-80%)**
- Task B (RuleSetProvider) - Refactoring existing code, must preserve compatibility
  - Risk: Breaking change to provider interface
  - Mitigation: Keep existing API, only change internal implementation
  - Mitigation: Extensive test coverage, test each mutation type

---

## Dependencies & Blockers

### **Sprint 1 Dependencies**
- [OK] DatabaseHelper (Sprint 1 Task A) - Complete
- [OK] EvaluationResult model - Already exists
- [OK] AppPaths - Already exists
- [OK] YamlService - Already exists

### **Known Blockers**
- None identified
- All dependencies resolved in Sprint 1

### **External Dependencies**
- sqflite: ^2.3.0 (added in Sprint 1)
- path_provider (existing)
- yaml: ^3.1.2 (existing)

---

## Files Affected Summary

### **New Files (4)**
1. `lib/core/storage/rule_database_store.dart` (200-300 lines)
2. `lib/core/storage/yaml_exporter.dart` (150-200 lines)
3. `test/unit/storage/rule_database_store_test.dart` (150-200 lines)
4. `test/unit/storage/yaml_exporter_test.dart` (100-150 lines)

### **Modified Files (3)**
1. `lib/core/providers/rule_set_provider.dart` (change imports, initialization, add auto-export call)
2. `test/unit/providers/rule_set_provider_test.dart` (update to verify database usage)
3. `test/integration/rule_evaluation_test.dart` (verify end-to-end chain)

### **No Changes Needed (Architecture Already Supports)**
- `lib/core/services/rule_evaluator.dart` - Provider agnostic
- `lib/core/services/email_scanner.dart` - Already uses provider
- All UI screens - Already use RuleSetProvider

---

## Commit Strategy

**Commit 1**: Task A - RuleDatabaseStore
```
feat: Implement RuleDatabaseStore for database-backed rule storage (Sprint 2 Task A)
- Create new storage layer for rules with CRUD operations
- Mirror LocalRuleStore API but use SQLite backend
- JSON serialization for conditions, actions, exceptions
- Comprehensive unit tests for all operations
```

**Commit 2**: Task B - RuleSetProvider Migration
```
feat: Migrate RuleSetProvider from YAML to database storage (Sprint 2 Task B)
- Replace LocalRuleStore with RuleDatabaseStore initialization
- Update all rule mutations to write to database
- Trigger YAML auto-export after changes
- Maintain backward compatibility with existing provider API
- All 122+ existing tests passing
```

**Commit 3**: Task C - YAML Auto-Export
```
feat: Implement YAML auto-export for database rules (Sprint 2 Task C)
- Create YamlExporter service for rule synchronization
- Auto-export to rules.yaml on every rule mutation
- Maintain YAML format invariants (lowercase, dedup, sort, etc)
- Timestamped backups before overwrite
```

**Commit 4**: Test Completion
```
test: Verify Sprint 2 regression testing and rule migration (Sprint 2 Task E)
- All 122+ existing tests passing
- 40+ new Sprint 2 tests for database operations
- No regressions in rule evaluation or UI
- Code analysis clean
```

---

## Timeline & Milestones

**Kickoff**: After Sprint 1 PR approval
- Estimated: Jan 24-25, 2026
- Duration: ~15-20 minutes

**Development**: Tasks A-D
- Estimated: 10-14 hours
- Parallel: Some tasks independent (A and C can progress simultaneously)

**Testing & Integration**: Task E
- Estimated: 2-3 hours
- Must be after all other tasks complete

**Code Review & PR**
- Estimated: 1-2 hours
- GitHub Copilot automated review
- User manual review if architectural questions

**Total Sprint Duration**: 2 weeks (including review/feedback cycles)

---

## Notes for User

### From Sprint 1 Retrospective
- Clear requirements work well - keep detailed specification
- Model assignments were accurate - continue same approach
- Documentation excellent - continue comprehensive PRs
- Testing first is valuable - keep that pattern

### For Sprint 2 Specifically
- This sprint refactors existing code - risk of breaking changes
  - Mitigation: Keep RuleSetProvider API identical, change only internals
  - Mitigation: Run tests frequently during development
- YAML auto-export is critical for developer experience
  - Makes rule editing seamless (database + version control)
- This sets foundation for Sprints 3-10
  - Rule creation UI (Sprint 5) depends on this
  - Background scanning (Sprint 7-8) depends on this

---

**Plan Version**: 1.0
**Last Updated**: January 24, 2026
**Reference**: From Phase 3.5 Master Plan, Sprint 2 section
**Related Documents**:
- Phase 3.5 Planning (Master plan)
- SPRINT_EXECUTION_WORKFLOW.md (How to execute this sprint)
- SPRINT_PLANNING.md (Overall methodology)
