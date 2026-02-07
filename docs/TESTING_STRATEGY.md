# Testing Strategy

**Purpose**: Define testing approach, requirements, and best practices for the spamfilter-multi project.

**Audience**: All contributors (Claude Code models, developers, testers)

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
| **TESTING_STRATEGY.md** (this doc) | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Types and Coverage](#test-types-and-coverage)
3. [Test Organization](#test-organization)
4. [Test Execution](#test-execution)
5. [Test Quality Standards](#test-quality-standards)
6. [Integration Testing](#integration-testing)
7. [Testing Tools and Scripts](#testing-tools-and-scripts)

---

## Testing Philosophy

### Core Principles

1. **Test-Driven Development (TDD)**: Write tests before or alongside code changes
2. **Comprehensive Coverage**: Aim for 80%+ test coverage on new code
3. **Fast Feedback**: Tests should run quickly to enable rapid iteration
4. **Isolation**: Unit tests should not depend on external systems (use mocks)
5. **Readability**: Tests document expected behavior and serve as examples

### When to Write Tests

**ALWAYS write tests for**:
- New features (before or during implementation)
- Bug fixes (reproduce bug first, then fix)
- Refactoring (ensure behavior preserved)
- Complex logic (rule evaluation, pattern matching)

**OPTIONAL tests for**:
- Trivial getters/setters
- Generated code (build_runner)
- Third-party library wrappers (adapter tests may suffice)

---

## Test Types and Coverage

### Test Pyramid

```
        /\
       /  \      E2E Tests (Manual)
      /    \     - Full app workflows
     /------\    - Platform-specific (Android, Windows)
    /        \
   /  Widget  \  Widget Tests
  /   Tests    \ - UI components
 /              \- Screen interactions
/--------------\
/   Integration \ Integration Tests
/     Tests      \- Multi-component workflows
/                \- Adapter + Provider interactions
/------------------\
/    Unit Tests     \ Unit Tests
/                    \- Models, Services, Utilities
/______________________\- Pure business logic
```

### Unit Tests

**Purpose**: Test individual functions, methods, and classes in isolation

**Location**: `mobile-app/test/unit/`

**Coverage Target**: 90%+ for core business logic

**Examples**:
- `rule_evaluator_test.dart` (32 tests, 97.96% coverage)
- `pattern_compiler_test.dart` (regex compilation, error tracking)
- `email_message_test.dart` (model validation)
- `yaml_service_test.dart` (YAML parsing)

**Template**:
```dart
import 'package:test/test.dart';
import 'package:spamfilter/core/models/email_message.dart';

void main() {
  group('EmailMessage', () {
    test('should parse email address from "Name <email>" format', () {
      // Arrange
      final email = EmailMessage(
        id: '123',
        from: 'John Doe <john@example.com>',
        subject: 'Test',
        body: 'Body',
        headers: {},
      );

      // Act
      final extractedEmail = email.fromEmail;

      // Assert
      expect(extractedEmail, equals('john@example.com'));
    });
  });
}
```

### Integration Tests

**Purpose**: Test interactions between multiple components

**Location**: `mobile-app/test/integration/`

**Coverage Target**: 70%+ for critical workflows

**Examples**:
- `email_scanner_integration_test.dart` (scanner + provider + evaluator)
- `rule_loading_integration_test.dart` (YAML service + RuleSetProvider + LocalRuleStore)
- `gmail_auth_flow_test.dart` (OAuth flow + token storage + API adapter)

**What to Test**:
- Data flow between components
- State management (Provider updates)
- Error handling across boundaries
- Persistence workflows (save/load)

**Template**:
```dart
import 'package:test/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spamfilter/core/services/email_scanner.dart';
import 'package:spamfilter/core/providers/email_scan_provider.dart';

void main() {
  group('EmailScanner Integration', () {
    late EmailScanner scanner;
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
      scanner = EmailScanner(scanProvider: provider);
    });

    test('should update provider during scan', () async {
      // Arrange
      final mockAdapter = MockEmailProvider();
      when(mockAdapter.fetchEmails(any)).thenAnswer((_) async => [email1, email2]);

      // Act
      await scanner.scanInbox(mockAdapter);

      // Assert
      expect(provider.processedCount, equals(2));
      expect(provider.status, equals(ScanStatus.completed));
    });
  });
}
```

### Widget Tests

**Purpose**: Test Flutter UI components and interactions

**Location**: `mobile-app/test/widgets/`

**Coverage Target**: 60%+ for critical UI flows

**Examples**:
- `scan_progress_screen_test.dart` (bubble display, navigation)
- `results_display_screen_test.dart` (result categorization, filtering)
- `account_selection_screen_test.dart` (account list, delete confirmation)

**What to Test**:
- Widget rendering (correct text, colors, icons)
- User interactions (button taps, form submissions)
- Navigation (screen transitions)
- State-driven UI updates (Provider changes)

**Template**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spamfilter/ui/screens/scan_progress_screen.dart';
import 'package:spamfilter/core/providers/email_scan_provider.dart';

void main() {
  testWidgets('should display bubble counts', (WidgetTester tester) async {
    // Arrange
    final provider = EmailScanProvider();
    provider.recordResult(EmailActionType.delete, 'Rule1');
    provider.recordResult(EmailActionType.move, 'Rule2');

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: ScanProgressScreen(accountId: 'test'),
        ),
      ),
    );

    // Assert
    expect(find.text('Deleted: 1'), findsOneWidget);
    expect(find.text('Moved: 1'), findsOneWidget);
  });
}
```

### End-to-End Tests

**Purpose**: Test complete user workflows on real devices/emulators

**Location**: Manual testing (not automated)

**Coverage**: All critical user paths

**When to Run**: Before every sprint PR approval

**Examples**:
- Add Gmail account → Scan inbox → View results → Delete account
- Add AOL account → Select Bulk Mail folder → Full Scan → Verify deletions
- Windows build → OAuth flow → Folder discovery → Scan 100+ emails

---

## Test Organization

### Directory Structure

```
mobile-app/test/
├── unit/                     # Unit tests (models, services, utilities)
│   ├── rule_evaluator_test.dart
│   ├── pattern_compiler_test.dart
│   ├── email_message_test.dart
│   └── yaml_service_test.dart
├── integration/              # Integration tests (workflows, multi-component)
│   ├── email_scanner_integration_test.dart
│   ├── rule_loading_integration_test.dart
│   └── gmail_auth_flow_test.dart
├── widgets/                  # Widget tests (UI components)
│   ├── scan_progress_screen_test.dart
│   ├── results_display_screen_test.dart
│   └── account_selection_screen_test.dart
├── fixtures/                 # Test data and mocks
│   ├── sample_emails.dart
│   ├── sample_rules.yaml
│   └── mock_adapters.dart
└── smoke_test.dart           # Smoke test (app initialization)
```

### Naming Conventions

**File Names**: `<class_name>_test.dart` (e.g., `rule_evaluator_test.dart`)

**Test Names**: Use descriptive, complete sentences:
```dart
// [OK] GOOD: Describes what, condition, and expected result
test('should return delete action when from matches spam pattern', () { });
test('should throw FormatException when YAML is invalid', () { });
test('should display "No results yet" when scan has not started', () { });

// [FAIL] BAD: Vague or incomplete
test('delete action', () { });
test('invalid YAML', () { });
test('no results', () { });
```

**Group Names**: Organize by class or feature:
```dart
group('RuleEvaluator', () {
  group('evaluateRule', () {
    test('should match from field with regex pattern', () { });
    test('should match subject field with regex pattern', () { });
  });

  group('safe sender check', () {
    test('should return safe sender action when email matches whitelist', () { });
  });
});
```

---

## Test Execution

### Running Tests

**All Tests**:
```bash
cd mobile-app
flutter test
```

**Specific File**:
```bash
flutter test test/unit/rule_evaluator_test.dart
```

**With Coverage**:
```bash
flutter test --coverage
```

**Generate HTML Coverage Report** (requires `lcov`):
```bash
# Windows (PowerShell)
flutter test --coverage
perl C:\ProgramData\chocolatey\lib\lcov\tools\bin\genhtml coverage\lcov.info -o coverage\html
start coverage\html\index.html

# Linux/macOS
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test Execution Workflow

**During Development**:
1. Write failing test (TDD)
2. Implement feature until test passes
3. Run affected tests: `flutter test test/unit/<file>_test.dart`
4. Refactor if needed, re-run tests

**Before Commit**:
1. Run all tests: `flutter test`
2. Verify 100% pass rate
3. Commit only if all tests pass

**Before Sprint PR**:
1. Run full test suite: `flutter test`
2. Run analyzer: `flutter analyze` (0 errors required)
3. Generate coverage report: `flutter test --coverage`
4. Verify coverage ≥80% for new code
5. Manual E2E test on Windows and Android

### Test Monitoring

**Use Test Monitoring Script** (`mobile-app/scripts/monitor-tests.ps1`):
```powershell
cd mobile-app\scripts
.\monitor-tests.ps1
```

**Features**:
- Real-time test execution monitoring
- Pass/fail count tracking
- Duration measurement
- Failure details extraction

---

## Test Quality Standards

### Test Structure (Arrange-Act-Assert)

**Every test should follow AAA pattern**:
```dart
test('should return delete action when from matches spam pattern', () {
  // Arrange: Set up test data and dependencies
  final rule = RuleSet(
    name: 'SpamRule',
    conditions: Conditions(
      type: 'OR',
      from: [r'^spam@.*\.com$'],
    ),
    actions: Actions(delete: true),
  );
  final email = EmailMessage(
    id: '123',
    from: 'spam@example.com',
    subject: 'Test',
    body: 'Body',
    headers: {},
  );
  final evaluator = RuleEvaluator();

  // Act: Execute the behavior being tested
  final result = evaluator.evaluateRule(email, rule);

  // Assert: Verify the expected outcome
  expect(result.action, equals(EmailActionType.delete));
  expect(result.ruleName, equals('SpamRule'));
});
```

### Test Independence

**Tests MUST be independent**:
- [OK] Each test can run in isolation
- [OK] No shared mutable state between tests
- [OK] Use `setUp()` and `tearDown()` for common setup/cleanup
- [FAIL] Do not rely on test execution order

**Example**:
```dart
group('EmailScanProvider', () {
  late EmailScanProvider provider;

  setUp(() {
    provider = EmailScanProvider(); // Fresh instance per test
  });

  test('should start with idle status', () {
    expect(provider.status, equals(ScanStatus.idle));
  });

  test('should update status to scanning when scan starts', () {
    provider.startScan(totalEmails: 10);
    expect(provider.status, equals(ScanStatus.scanning));
  });
});
```

### Test Coverage Requirements

**Minimum Coverage**:
- **Core Business Logic** (lib/core/): 90%
- **Adapters** (lib/adapters/): 70%
- **UI** (lib/ui/): 60%
- **Overall Project**: 80%

**Measuring Coverage**:
```bash
flutter test --coverage
# View coverage/lcov.info for line-by-line coverage
```

**Exclusions** (acceptable to skip):
- Generated code (`*.g.dart`, `*.freezed.dart`)
- Third-party library wrappers (if trivial)
- Platform-specific code requiring real devices (document manual test instead)

---

## Integration Testing

### What to Test

**Integration tests should verify**:
1. **Data Flow**: Data passed correctly between components
2. **State Management**: Provider updates propagate to listeners
3. **Error Handling**: Errors from one component handled by another
4. **Persistence**: Data saved and loaded correctly
5. **Workflows**: Multi-step processes complete end-to-end

**Example - Email Scanning Workflow**:
```dart
test('should scan inbox and update provider with results', () async {
  // Arrange
  final provider = EmailScanProvider();
  final mockAdapter = MockEmailProvider();
  final scanner = EmailScanner(scanProvider: provider);

  final testEmails = [
    EmailMessage(id: '1', from: 'spam@example.com', ...),
    EmailMessage(id: '2', from: 'safe@company.com', ...),
  ];

  when(mockAdapter.fetchEmails(any)).thenAnswer((_) async => testEmails);

  // Act
  await scanner.scanInbox(mockAdapter);

  // Assert
  expect(provider.processedCount, equals(2));
  expect(provider.deleteCount, greaterThan(0)); // spam detected
  expect(provider.status, equals(ScanStatus.completed));
});
```

### Mocking Dependencies

**Use `mockito` for mocking**:
```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([EmailProvider, SecureCredentialsStore])
import 'integration_test.mocks.dart';

void main() {
  test('should handle provider errors gracefully', () async {
    // Arrange
    final mockAdapter = MockEmailProvider();
    when(mockAdapter.fetchEmails(any)).thenThrow(Exception('Network error'));

    // Act & Assert
    expect(
      () async => await scanner.scanInbox(mockAdapter),
      throwsA(isA<Exception>()),
    );
  });
}
```

---

## Testing Tools and Scripts

### Test Monitoring Script

**Location**: `mobile-app/scripts/monitor-tests.ps1`

**Purpose**: Real-time test execution monitoring with pass/fail tracking

**Usage**:
```powershell
cd mobile-app\scripts
.\monitor-tests.ps1
```

**Output**:
```
=== Flutter Test Monitor ===
Starting at: 2026-01-31 10:30:00

[10:30:05] Tests: 122 passed, 0 failed (Duration: 12.3s)
[10:30:10] Tests: 122 passed, 0 failed (Duration: 12.1s)
```

### YAML Validation Script

**Location**: `mobile-app/scripts/validate-yaml-rules.ps1`

**Purpose**: Validate `rules.yaml` and `rules_safe_senders.yaml` for syntax errors

**Usage**:
```powershell
cd mobile-app\scripts
.\validate-yaml-rules.ps1
```

### Regex Pattern Tester

**Location**: `mobile-app/scripts/test-regex-patterns.ps1`

**Purpose**: Test regex patterns against sample emails

**Usage**:
```powershell
cd mobile-app\scripts
.\test-regex-patterns.ps1 -Pattern "^spam@.*\.com$" -TestString "spam@example.com"
```

---

## Best Practices

### 1. Test Naming

**Use complete sentences** that describe the behavior:
```dart
// [OK] GOOD
test('should return safe sender action when email matches whitelist', () { });
test('should throw FormatException when YAML is invalid', () { });

// [FAIL] BAD
test('safe sender', () { });
test('invalid YAML', () { });
```

### 2. Test One Thing

**Each test should verify one behavior**:
```dart
// [OK] GOOD: Two separate tests
test('should match from field with regex pattern', () {
  final result = evaluator.evaluateRule(email, fromRule);
  expect(result.action, equals(EmailActionType.delete));
});

test('should match subject field with regex pattern', () {
  final result = evaluator.evaluateRule(email, subjectRule);
  expect(result.action, equals(EmailActionType.delete));
});

// [FAIL] BAD: Testing multiple behaviors in one test
test('should match from and subject fields', () {
  final fromResult = evaluator.evaluateRule(email, fromRule);
  final subjectResult = evaluator.evaluateRule(email, subjectRule);
  expect(fromResult.action, equals(EmailActionType.delete));
  expect(subjectResult.action, equals(EmailActionType.delete));
});
```

### 3. Use Descriptive Variables

**Name test data descriptively**:
```dart
// [OK] GOOD
final spamEmail = EmailMessage(from: 'spam@example.com', ...);
final safeEmail = EmailMessage(from: 'trusted@company.com', ...);
final deleteRule = RuleSet(actions: Actions(delete: true));

// [FAIL] BAD
final email1 = EmailMessage(from: 'spam@example.com', ...);
final email2 = EmailMessage(from: 'trusted@company.com', ...);
final rule1 = RuleSet(actions: Actions(delete: true));
```

### 4. Test Error Cases

**Always test both success and failure paths**:
```dart
group('PatternCompiler', () {
  test('should compile valid regex pattern', () {
    final result = compiler.compile(r'^test@example\.com$');
    expect(result.isValid, isTrue);
  });

  test('should track invalid regex pattern', () {
    final result = compiler.compile(r'[invalid(regex');
    expect(result.isValid, isFalse);
    expect(result.errorMessage, isNotNull);
  });
});
```

### 5. Use Fixtures for Complex Data

**Extract complex test data to fixtures**:
```dart
// test/fixtures/sample_emails.dart
class SampleEmails {
  static final spamEmail = EmailMessage(
    id: '123',
    from: 'spam@example.com',
    subject: 'Urgent: You won a prize!',
    body: 'Click here to claim...',
    headers: {},
  );

  static final safeEmail = EmailMessage(
    id: '456',
    from: 'colleague@company.com',
    subject: 'Meeting notes',
    body: 'Here are the notes from today...',
    headers: {},
  );
}

// test/unit/rule_evaluator_test.dart
import '../fixtures/sample_emails.dart';

test('should delete spam email', () {
  final result = evaluator.evaluateRule(SampleEmails.spamEmail, spamRule);
  expect(result.action, equals(EmailActionType.delete));
});
```

---

## Troubleshooting

### Common Test Failures

**Issue**: `MissingPluginException` in widget tests

**Cause**: Flutter bindings not initialized

**Fix**:
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Add this

  testWidgets('should display account list', (tester) async {
    // ... test code
  });
}
```

**Issue**: Tests timeout when testing async code

**Cause**: Not awaiting async calls or infinite loops

**Fix**:
```dart
// [FAIL] BAD: Missing await
test('should fetch emails', () {
  scanner.scanInbox(adapter); // Missing await!
  expect(provider.status, equals(ScanStatus.completed));
});

// [OK] GOOD: Properly awaited
test('should fetch emails', () async {
  await scanner.scanInbox(adapter);
  expect(provider.status, equals(ScanStatus.completed));
});
```

**Issue**: Tests pass locally but fail in CI

**Cause**: Platform-specific dependencies or timing issues

**Fix**:
- Use `TestWidgetsFlutterBinding.ensureInitialized()` for Flutter tests
- Add `await tester.pumpAndSettle()` after async UI changes
- Mock platform-specific APIs (e.g., `SecureStorage`)

---

## Version History

**Version**: 1.0
**Date**: January 31, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Updates**:
- 1.0 (2026-01-31): Initial version created from Sprint 9 retrospective approved recommendations
