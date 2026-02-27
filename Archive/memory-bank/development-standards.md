# Development Standards for OutlookMailSpamFilter

## Feature Enhancement Request Process

### Core Principles

#### 1. Minimal Code Changes
- **ONLY change code that HAS to be CHANGED** to implement the recommendation
- Avoid unnecessary refactoring or cosmetic changes
- Focus on the specific functionality requested
- Preserve existing working code patterns

#### 2. Code Preservation Standards
- **Any code that should be removed should be commented out and NOT deleted**
- **Do not remove any commented out code** - preserve for reference and rollback capability
- Maintain historical context through commented code
- Use clear commenting to explain why code was changed

#### 3. Testing Requirements
- **Before confirming changes, all tests should run successfully**
- **Updates must be applied until all tests can be run without errors or warnings**
- **For all new features added, ensure an existing test covers the features or a new test is added to cover the features**
- **All test files must be located in the `pytest/` directory**
- **Use `python -m pytest pytest/ -v` to run all tests**
- Create comprehensive test coverage for new functionality
- Validate both positive and negative test cases
- Ensure import compatibility and syntax validation

## Quality Assurance Checklist

### Pre-Implementation
- [ ] Understand the exact requirement - what HAS to be changed
- [ ] Identify minimal set of code changes needed
- [ ] Plan preservation strategy for existing code

### During Implementation
- [ ] Comment out code instead of deleting
- [ ] Add clear comments explaining changes
- [ ] Preserve variable names where possible (use clear migration path)
- [ ] Maintain existing code patterns and conventions
- [ ] Ensure new features have test coverage (existing or new tests)

### Post-Implementation Validation
- [ ] **Syntax validation** - code compiles without errors
- [ ] **Import compatibility** - all imports work correctly
- [ ] **Test coverage validation** - all new features have test coverage
- [ ] **Functional testing** - new features work as expected
- [ ] **Regression testing** - existing features still work
- [ ] **Error handling** - graceful handling of edge cases
- [ ] **Zero errors and warnings** in all test runs

## Documentation Standards

### Change Documentation
- Update change log with timestamp and description
- Update in-code comments to reflect modifications
- Update memory-bank documentation
- Update README.md for user-facing changes

### Code Comments
```python
# Original code - preserved for reference
# EMAIL_BULK_FOLDER_NAME = "Bulk Mail"  # Commented out - now using list below

# Updated code - new functionality
EMAIL_BULK_FOLDER_NAMES = ["Bulk Mail", "bulk"]  # Changed from single folder to list of folders
```

## Example Implementation: Multi-Folder Enhancement

### What Was Done Right
1. **Minimal Changes**: Only modified variables and methods that directly related to folder processing
2. **Code Preservation**: Original `EMAIL_BULK_FOLDER_NAME` was commented out, not deleted
3. **Clear Migration**: `EMAIL_BULK_FOLDER_NAME` → `EMAIL_BULK_FOLDER_NAMES` with explanatory comments
4. **Comprehensive Testing**: Created multiple test files to validate all aspects
5. **Test Coverage**: New multi-folder functionality was covered by dedicated tests
6. **Zero Errors**: All tests passed without errors or warnings
7. **Documentation**: Updated memory-bank, README, and change logs

### Testing Strategy Used
- File content validation tests
- Import compatibility tests
- Syntax validation
- Variable reference validation
- Method signature validation
- **All tests organized in `pytest/` directory for consistency**
- **Test execution via `python -m pytest pytest/ -v`**
- **Proper import path management for test isolation**

## Backup and Recovery

### Backup Strategy
- Create timestamped backups before major changes
- Preserve commented-out code for reference
- Maintain version history in change logs
- Use git branching for experimental features

### Recovery Process
- Commented code provides immediate rollback option
- Timestamped backups available for major rollbacks
- Change logs document exactly what was modified
- Git history provides complete change tracking

## Future Enhancement Guidelines

### When Implementing New Features
1. **Analyze Impact**: Identify minimal code changes needed
2. **Preserve History**: Comment out old code, don't delete
3. **Ensure Test Coverage**: Verify existing tests cover new features or create new tests
4. **Test Thoroughly**: Ensure zero errors/warnings before completion
5. **Document Changes**: Update all relevant documentation
6. **Validate Completely**: Run full test suite successfully

### Red Flags to Avoid
- ❌ Deleting working code
- ❌ Removing commented code
- ❌ Making unnecessary changes
- ❌ Skipping comprehensive testing
- ❌ Accepting errors or warnings in tests
- ❌ Poor documentation of changes

This document serves as the standard for all future feature enhancements to ensure consistent, high-quality development practices.
