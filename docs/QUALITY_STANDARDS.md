# Quality Standards

**Purpose**: Define quality standards for documentation and code to ensure consistency, maintainability, and professionalism across the spamfilter-multi project.

**Audience**: All contributors (Claude Code models, developers, reviewers)

**Last Updated**: January 31, 2026

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation. Reference these documents throughout sprint work:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** | Master plan for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 0-4.5) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 4.5) |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** (this doc) | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Documentation Standards](#documentation-standards)
2. [Code Quality Standards](#code-quality-standards)
3. [Testing Standards](#testing-standards)
4. [Enforcement](#enforcement)

---

## Documentation Standards

### File Size Limits

**Maximum File Size**: 40,000 characters per file

**Rationale**: Large files impact:
- Claude Code performance (context window usage)
- Developer navigation and readability
- Git diff review efficiency

**When Exceeded**:
1. Extract content to dedicated files (e.g., ARCHITECTURE.md from CLAUDE.md)
2. Use cross-references instead of duplication
3. Create topic-specific documents

**Example Refactoring**:
```markdown
Before (43.7k chars):
  CLAUDE.md (everything)

After (29.2k chars):
  CLAUDE.md (overview + quick reference)
  ARCHITECTURE.md (detailed architecture)
  RULE_FORMAT.md (YAML specification)
  TROUBLESHOOTING.md (common issues)
```

### Readability Standards

**Target Readability**: Flesch-Kincaid grade level 8-12

**Writing Guidelines**:
- Use clear, complete sentences
- No contractions ("do not" instead of "don't")
- Prefer active voice ("System validates input" not "Input is validated")
- Define technical terms on first use
- Use examples to illustrate complex concepts

**Structure Requirements**:
- **Headings**: Use hierarchical headings (##, ###, ####)
- **Table of Contents**: Required for files >20,000 characters
- **Code Examples**: Include for all technical guidance
- **Cross-References**: Link to related documents

**Example Structure**:
```markdown
# Document Title

**Purpose**: One-sentence description
**Audience**: Who should read this
**Last Updated**: YYYY-MM-DD

## SPRINT EXECUTION Documentation
[Standard table - see above]

---

## Table of Contents
[For large files only]

---

## Section 1
Content with examples...

## Section 2
Content with cross-references...
```

### Documentation Completeness

**Required Sections**:
1. **Purpose Statement**: Why this document exists
2. **Audience**: Who should read it
3. **Last Updated Date**: YYYY-MM-DD format
4. **SPRINT EXECUTION Documentation Table**: For sprint-related docs
5. **Content**: Well-organized, hierarchical sections
6. **Examples**: Code snippets, templates, or demos where applicable
7. **Cross-References**: Links to related documentation

**Optional Sections**:
- Table of Contents (mandatory for >20k chars)
- Quick Reference / Cheat Sheet
- FAQ
- Troubleshooting
- Version History

### Code Example Standards

**All Code Examples Must Include**:
1. **Language Identifier**: Markdown code fence with language
2. **Context**: Brief explanation before code
3. **Comments**: Inline comments for complex logic
4. **Complete**: Runnable or clearly incomplete (e.g., `// ...`)

**Example Format**:
```markdown
**Before (incorrect)**:
```dart
// Bad: Don't use this
print('Debug message');
```

**After (correct)**:
```dart
// Good: Use AppLogger with keyword prefix
AppLogger.debug('Debug message');
```
```

### Cross-Reference Format

**Internal Links**: Use relative paths
```markdown
See `docs/ARCHITECTURE.md` for system design.
See `SPRINT_EXECUTION_WORKFLOW.md` Phase 4.5 for retrospective.
```

**External Links**: Use full URLs with descriptive text
```markdown
See [Keep a Changelog](https://keepachangelog.com/) format.
```

---

## Code Quality Standards

### Complexity Limits

**Maximum Cyclomatic Complexity**: 10 per method/function

**What is Cyclomatic Complexity**:
- Number of independent paths through code
- Calculated as: branches (if/for/while/case) + 1
- Complexity >10 indicates method is doing too much

**Refactoring Example**:
```dart
// BAD: Complexity = 12 (too high)
bool validateEmail(String email, Map<String, String> rules) {
  if (email == null) return false;
  if (email.isEmpty) return false;
  if (!email.contains('@')) return false;
  if (rules.containsKey('maxLength')) {
    if (email.length > int.parse(rules['maxLength']!)) return false;
  }
  if (rules.containsKey('allowedDomains')) {
    if (!rules['allowedDomains']!.split(',').any((d) => email.endsWith(d))) {
      return false;
    }
  }
  // ... more conditions
  return true;
}

// GOOD: Complexity = 3 (refactored into smaller methods)
bool validateEmail(String email, Map<String, String> rules) {
  if (!_isValidFormat(email)) return false;
  if (!_meetsLengthRequirements(email, rules)) return false;
  if (!_isAllowedDomain(email, rules)) return false;
  return true;
}

bool _isValidFormat(String email) {
  return email != null && email.isNotEmpty && email.contains('@');
}

bool _meetsLengthRequirements(String email, Map<String, String> rules) {
  if (!rules.containsKey('maxLength')) return true;
  return email.length <= int.parse(rules['maxLength']!);
}

bool _isAllowedDomain(String email, Map<String, String> rules) {
  if (!rules.containsKey('allowedDomains')) return true;
  return rules['allowedDomains']!.split(',').any((d) => email.endsWith(d));
}
```

### File Length Limits

**Maximum File Length**: 500 lines per file

**Exceptions**:
- Generated code (build_runner, protobuf)
- Test files with extensive test data
- Complex UI screens (up to 700 lines with justification)

**When Exceeded**:
1. Extract helper classes to separate files
2. Split into logical modules
3. Move constants/enums to separate files
4. Extract test fixtures to separate files

### Code Organization

**File Structure**:
```dart
// 1. Imports (grouped)
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/email_message.dart';
import '../utils/app_logger.dart';

// 2. Constants
const int kMaxRetries = 3;
const Duration kTimeout = Duration(seconds: 30);

// 3. Class definition
class EmailScanner {
  // 4. Fields (private first, then public)
  final Logger _logger;
  String accountId;

  // 5. Constructor
  EmailScanner({required this.accountId}) : _logger = Logger();

  // 6. Public methods
  Future<void> scanInbox() async { /* ... */ }

  // 7. Private methods
  Future<void> _fetchEmails() async { /* ... */ }
}
```

### Logging Standards

**Production Code** (`lib/` directory):
- **MUST use**: `AppLogger` with keyword prefixes
- **NEVER use**: `print()` statements

**Test Code** (`test/` directory):
- **MAY use**: `print()` for test debugging
- **PREFER**: `AppLogger` for consistency

**AppLogger Keywords**:
- `AppLogger.email()` - Email operations
- `AppLogger.rules()` - Rule operations
- `AppLogger.scan()` - Scan progress
- `AppLogger.auth()` - Authentication
- `AppLogger.database()` - Database operations
- `AppLogger.error()` - Errors (with error and stackTrace)
- `AppLogger.warning()` - Warnings
- `AppLogger.debug()` - Debug messages

**Example**:
```dart
// [FAIL] BAD: Using print() in production code
print('Scanning 150 emails...');

// [OK] GOOD: Using AppLogger with keyword
AppLogger.scan('Starting inbox scan: 150 emails to process');
```

### Naming Conventions

**Classes**: PascalCase
```dart
class EmailScanner { }
class RuleEvaluator { }
```

**Methods/Functions**: camelCase
```dart
Future<void> scanInbox() async { }
bool evaluateRule(EmailMessage email) { }
```

**Constants**: camelCase with `k` prefix or SCREAMING_SNAKE_CASE
```dart
const int kMaxRetries = 3;
const String API_BASE_URL = 'https://api.example.com';
```

**Private Members**: Leading underscore
```dart
final Logger _logger;
Future<void> _fetchEmails() async { }
```

### Code Style

**Follow Dart Style Guide**: https://dart.dev/guides/language/effective-dart/style

**Key Points**:
- Use trailing commas for better git diffs
- Prefer single quotes for strings
- Use interpolation instead of concatenation
- Avoid unnecessary braces in string interpolation
- Use `const` constructors where possible

**Example**:
```dart
// [OK] GOOD
AppLogger.scan('Processing $count emails from $folder');
final widget = Container(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
);

// [FAIL] BAD
AppLogger.scan('Processing ${count} emails from ${folder}');  // Unnecessary braces
final widget = Container(
  padding: EdgeInsets.all(16), child: Text('Hello'));  // No trailing comma
```

---

## Testing Standards

See `docs/TESTING_STRATEGY.md` for comprehensive testing requirements.

**Minimum Test Coverage**: 80% for new code

**Required Test Types**:
- Unit tests for business logic
- Integration tests for multi-component workflows
- Widget tests for UI components (Flutter)

**Test Organization**:
```
mobile-app/test/
├── unit/           # Unit tests (models, services, utilities)
├── integration/    # Integration tests (workflows, adapters)
├── widgets/        # Widget tests (UI components)
└── fixtures/       # Test data and mocks
```

**Test Naming**:
```dart
// Pattern: test('<what> <should> <expected result>', () { ... });
test('evaluateRule should return delete action when from matches spam pattern', () {
  // Arrange
  final rule = createSpamRule();
  final email = createEmailFrom('spam@example.com');

  // Act
  final result = evaluator.evaluateRule(email, rule);

  // Assert
  expect(result.action, equals(EmailAction.delete));
});
```

**Test Coverage Measurement**:
```bash
# Generate coverage report
flutter test --coverage

# View coverage (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Enforcement

### Pre-Commit Checks

**Automated Checks** (via `.claude/hooks.json` or git hooks):
1. **File Size**: Warn if file >40k characters
2. **Analyzer**: Run `flutter analyze` (0 errors required)
3. **Tests**: Run `flutter test` (100% pass rate required)
4. **Format**: Run `dart format` (auto-fix)

### Code Review Checklist

**Reviewer Responsibilities**:
- [ ] Code meets complexity limits (cyclomatic complexity ≤10)
- [ ] Files are ≤500 lines (exceptions justified)
- [ ] Production code uses AppLogger (no print())
- [ ] Test coverage ≥80% for new code
- [ ] Documentation updated for API changes
- [ ] Examples included for complex features
- [ ] Cross-references valid and up-to-date

### Sprint Acceptance Criteria

**Every Sprint Must**:
1. Run `flutter analyze` with 0 errors in production code (`lib/`)
2. Run `flutter test` with 100% pass rate
3. Update documentation for all user-facing changes
4. Meet test coverage threshold (80% minimum)
5. Follow coding style guide (Dart effective-dart)

**Enforcement Points**:
- **Phase 3.2**: Run analyzer and tests before proceeding
- **Phase 4.5**: Verify quality standards met before PR approval
- **PR Approval**: User verifies standards before merge

---

## Continuous Improvement

### Metrics to Track

**Code Quality Metrics**:
1. Cyclomatic complexity (target: avg <8, max 10)
2. File size distribution (target: <500 lines)
3. Test coverage percentage (target: >80%)
4. Analyzer warnings (target: 0 in lib/)

**Documentation Quality Metrics**:
1. File size distribution (target: <40k chars)
2. Readability score (target: grade 8-12)
3. Broken link count (target: 0)
4. Missing cross-references (target: 0)

### Retrospective Review

**After Each Sprint**:
1. Review quality standard violations
2. Identify patterns (repeated issues)
3. Update standards if needed
4. Document exceptions and rationale

**Example**:
> Sprint 9: 11 analyzer warnings fixed (all unused imports/fields)
> Action: Add pre-commit hook to check for unused code
> Result: Prevent similar issues in Sprint 10+

---

## Version History

**Version**: 1.0
**Date**: January 31, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Updates**:
- 1.0 (2026-01-31): Initial version created from Sprint 9 retrospective approved recommendations
