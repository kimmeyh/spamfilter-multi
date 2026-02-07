# Logging Conventions

**Purpose**: Establish consistent keyword-based logging for easy filtering in logcat and console output.

**Created**: January 30, 2026
**Status**: Active

---

## Overview

All logging in the spamfilter-multi mobile app uses `AppLogger` utility with standardized keyword prefixes. This enables efficient log filtering during development and testing.

**Key Benefits**:
- Quick isolation of specific functionality (emails, rules, auth, etc.)
- Easy error tracking with `[ERROR]` prefix
- Performance monitoring with `[PERF]` prefix
- Consistent format across entire codebase

---

## Logging Utility

**File**: `mobile-app/lib/core/utils/app_logger.dart`

**Usage**: Import and call specific logging methods instead of using `print()` or direct `Logger()` calls.

```dart
import 'package:spam_filter_mobile/core/utils/app_logger.dart';

// Example usage
AppLogger.email('Fetched 50 messages from INBOX for user@example.com');
AppLogger.rules('Loaded 250 rules from rules.yaml');
AppLogger.eval('Email matched rule "SpamAutoDelete"');
AppLogger.error('Failed to connect to IMAP server', error: e, stackTrace: st);
```

---

## Keyword Prefixes

| Prefix | Category | When to Use | Example |
|--------|----------|-------------|---------|
| `[EMAIL]` | Email Operations | Fetching, parsing, sending emails | `[EMAIL] Fetched 50 messages from INBOX` |
| `[RULES]` | Rules Management | Loading, saving, updating rules | `[RULES] Loaded 250 rules from rules.yaml in 45ms` |
| `[EVAL]` | Rule Evaluation | Pattern matching, rule testing | `[EVAL] Email from spam@example.com matched rule "SpamAutoDelete"` |
| `[DB]` | Database | CRUD operations, migrations | `[DB] Migrated 250 rules to database` |
| `[AUTH]` | Authentication | OAuth, token refresh, login | `[AUTH] OAuth token refreshed for user@gmail.com` |
| `[SCAN]` | Scanning Progress | Scan status, progress updates | `[SCAN] Processing email 50/150 (33%)` |
| `[ERROR]` | Errors | Exceptions, failures | `[ERROR] Failed to delete email: IMAP connection lost` |
| `[PERF]` | Performance | Timing, metrics | `[PERF] Rule evaluation: 150 emails in 8.5s (57ms/email)` |
| `[UI]` | UI Events | Button clicks, nav changes | `[UI] User clicked Start Scan button` |
| `[DEBUG]` | Debug | General debug info | `[DEBUG] Initializing scanner with folder: INBOX` |
| `[INFO]` | Info | General informational | `[INFO] App initialized successfully` |
| `[WARNING]` | Warnings | Non-critical issues | `[WARNING] Rule uses deprecated wildcard syntax` |

---

## Filtering Logs

### Android (adb logcat)

```bash
# Show only email operations
adb logcat -s flutter | grep '\[EMAIL\]'

# Show only errors
adb logcat -s flutter | grep '\[ERROR\]'

# Show rules + evaluation
adb logcat -s flutter | grep -E '\[RULES\]|\[EVAL\]'

# Show all except debug
adb logcat -s flutter | grep -v '\[DEBUG\]'

# Show scanning progress (real-time)
adb logcat -s flutter | grep --line-buffered '\[SCAN\]'

# Combine multiple categories
adb logcat -s flutter | grep -E '\[EMAIL\]|\[RULES\]|\[EVAL\]|\[ERROR\]|\[SCAN\]'
```

### Windows (PowerShell)

```powershell
# Show only email operations
flutter run | Select-String '\[EMAIL\]'

# Show only errors
flutter run | Select-String '\[ERROR\]'

# Show multiple categories
flutter run | Select-String -Pattern '\[EMAIL\]', '\[RULES\]', '\[ERROR\]'
```

### Saving Logs to File

```bash
# Android - Save filtered logs with timestamp
adb logcat -s flutter | grep -E '\[EMAIL\]|\[RULES\]|\[ERROR\]' > test_logs_$(date +%Y%m%d_%H%M%S).txt

# Windows - Save all logs
.\build-windows.ps1 | Tee-Object -FilePath "test_logs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
```

---

## Migration Guide

### Current State
- Some files use `print()`
- Some files use direct `Logger().i()`, `Logger().d()`, `Logger().e()`
- No standardized keywords

### Migration Plan

**Phase 1** (Sprint 9): High-traffic files
- `lib/core/services/rule_evaluator.dart` → `AppLogger.eval()`
- `lib/core/services/email_scanner.dart` → `AppLogger.scan()`
- `lib/core/providers/email_scan_provider.dart` → `AppLogger.scan()`, `AppLogger.email()`
- `lib/adapters/email_providers/gmail_api_adapter.dart` → `AppLogger.email()`, `AppLogger.auth()`
- `lib/adapters/email_providers/generic_imap_adapter.dart` → `AppLogger.email()`, `AppLogger.auth()`

**Phase 2** (Sprint 10): Storage and auth files
- `lib/adapters/storage/local_rule_store.dart` → `AppLogger.rules()`, `AppLogger.database()`
- `lib/adapters/auth/google_auth_service.dart` → `AppLogger.auth()`
- `lib/adapters/storage/secure_credentials_store.dart` → `AppLogger.auth()`

**Phase 3** (Sprint 10+): Remaining files
- All other files with logging
- Remove all `print()` statements
- Replace direct `Logger()` calls with `AppLogger`

### Migration Steps Per File

1. Add import: `import 'package:spam_filter_mobile/core/utils/app_logger.dart';`
2. Replace `print()` with appropriate `AppLogger` method
3. Replace `_logger.i()` with `AppLogger.<category>()`
4. Replace `_logger.d()` with `AppLogger.debug()` or specific category
5. Replace `_logger.e()` with `AppLogger.error()`
6. Remove Logger instance field if no longer used

### Example Migration

**Before**:
```dart
final Logger _logger = Logger();

void evaluate(EmailMessage message) {
  _logger.i('Evaluating email: ${message.subject}');
  // ...
  if (matched) {
    _logger.i('Email matched rule: ${rule.name}');
  }
}
```

**After**:
```dart
import 'package:spam_filter_mobile/core/utils/app_logger.dart';

void evaluate(EmailMessage message) {
  AppLogger.eval('Evaluating email: ${message.subject} (from: ${message.from})');
  // ...
  if (matched) {
    AppLogger.eval('Email from ${message.from} matched rule "${rule.name}" (pattern: ${pattern})');
  }
}
```

---

## Best Practices

### 1. Include Context in Messages

[FAIL] BAD:
```dart
AppLogger.email('Fetched messages');
```

[OK] GOOD:
```dart
AppLogger.email('Fetched 50 messages from INBOX for user@example.com');
```

### 2. Use Appropriate Log Levels

- **Info** (`AppLogger.email()`, `AppLogger.rules()`, etc.): Normal operations
- **Debug** (`AppLogger.debug()`): Detailed debugging info (verbose)
- **Warning** (`AppLogger.warning()`): Non-critical issues
- **Error** (`AppLogger.error()`): Failures and exceptions

### 3. Include Performance Metrics

```dart
final stopwatch = Stopwatch()..start();
// ... do work ...
stopwatch.stop();
AppLogger.perf('Rule evaluation: ${emailCount} emails in ${stopwatch.elapsedMilliseconds}ms (${stopwatch.elapsedMilliseconds / emailCount}ms/email)');
```

### 4. Log Errors with Context

```dart
try {
  await emailProvider.deleteEmail(emailId);
} catch (e, stackTrace) {
  AppLogger.error('Failed to delete email $emailId: $e', error: e, stackTrace: stackTrace);
}
```

### 5. Avoid Sensitive Data

Do NOT log:
- Passwords or credentials
- Full OAuth tokens (log "Token refreshed" not the token value)
- Email message bodies (log subject lines only if needed)
- Personal identifying information (PII)

[OK] SAFE:
```dart
AppLogger.auth('OAuth token refreshed for user@gmail.com');
```

[FAIL] UNSAFE:
```dart
AppLogger.auth('OAuth token: ya29.a0AfH6SMBx...');
```

---

## Testing Log Output

### Unit Test Verification

```dart
void main() {
  test('AppLogger uses correct prefixes', () {
    // Capture log output (requires log capturing infrastructure)
    AppLogger.email('Test email log');
    AppLogger.rules('Test rules log');
    AppLogger.error('Test error log');

    // Manual verification: Check console output has correct prefixes
    // Automated verification would require log interceptor
  });
}
```

### Manual Verification

1. Build and run app: `.\build-windows.ps1`
2. Trigger functionality (e.g., scan emails)
3. Check console output for keyword prefixes
4. Filter with `grep` to verify filtering works

---

## Reference

- **AppLogger Source**: `mobile-app/lib/core/utils/app_logger.dart`
- **Usage Examples**: See high-traffic files after Phase 1 migration
- **Log Monitoring**: `docs/MANUAL_INTEGRATION_TESTS.md` § Log Monitoring

---

**Document Version**: 1.0
**Last Updated**: January 30, 2026
