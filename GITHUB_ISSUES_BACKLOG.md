# Code Review Issues Backlog

This document contains 11 prioritized issues from the comprehensive code review conducted on January 3, 2026. Each issue is ready to be copied into GitHub's issue creation interface.

**Summary:**
- 🎉 **0 Critical Issues Remaining** (ALL 4 completed!) - Production ready!
- ⚠️ **3 High Priority Issues** - Fix in next sprint
- 📝 **3 Medium/Low Priority Issues** - Technical debt

**Completed Issues:**
- ✅ **Issue #18** (Jan 3, 2026): RuleEvaluator comprehensive test suite - 32 tests, 97.96% coverage
- ✅ **Issue #8** (Jan 3, 2026): Header matching bug fixed - Rules now check headers correctly
- ✅ **Issue #4** (Jan 3, 2026): Regex compilation failures now logged
- ✅ **Issue #10** (Jan 3, 2026): Credential type confusion resolved - Explicit credential type handling
- ✅ **Issue #9** (Jan 3, 2026): Scan mode bypass CRITICAL FIXED - Readonly mode is now SAFE (no data loss risk)
- ✅ **Issue #14** (Jan 3, 2026): Duplicate scan mode logic removed - Simplified recordResult()

---

## 🔴 CRITICAL PRIORITY

### Issue #1: Header matching bug in RuleEvaluator - rules with header conditions never match

**Labels:** `bug`, `priority:critical`, `component:core`, `security`

**Description:**

The `RuleEvaluator` has a critical bug in both `_matchesConditions()` and `_matchesExceptions()` methods that prevents header-based spam filtering from working correctly.

**Root Cause:** The code checks `message.from` against header patterns instead of checking actual email headers from `message.headers`.

**Impact:**
- Rules targeting spam indicators in email headers (X-Spam-Status, Reply-To, Received, etc.) will **never match**
- Exception patterns for headers will also fail to match
- This severely limits the effectiveness of the spam filter for header-based detection
- Could allow spam through that should be caught

**Current Behavior**

In `_matchesConditions()` (lines 53-66):
```dart
bool _matchesConditions(EmailMessage message, RuleConditions conditions) {
  final matches = <bool>[
    _matchesPatternList(message.from, conditions.from),
    _matchesPatternList(message.from, conditions.header),  // ❌ WRONG: Checks from field, not headers
    _matchesPatternList(message.subject, conditions.subject),
    _matchesPatternList(message.body, conditions.body),
  ];
  // ...
}
```

In `_matchesExceptions()` (lines 68-73):
```dart
bool _matchesExceptions(EmailMessage message, RuleExceptions exceptions) {
  return _matchesPatternList(message.from, exceptions.from) ||
      _matchesPatternList(message.from, exceptions.header) ||  // ❌ WRONG: Checks from field, not headers
      _matchesPatternList(message.subject, exceptions.subject) ||
      _matchesPatternList(message.body, exceptions.body);
}
```

**Expected Behavior**

Header conditions and exceptions should check against actual email headers, not the from field.

**Proposed Solution**

Add a new helper method `_matchesHeaderList()` and update both methods:

```dart
bool _matchesConditions(EmailMessage message, RuleConditions conditions) {
  final matches = <bool>[
    _matchesPatternList(message.from, conditions.from),
    _matchesHeaderList(message.headers, conditions.header),  // ✅ Check actual headers
    _matchesPatternList(message.subject, conditions.subject),
    _matchesPatternList(message.body, conditions.body),
  ];
  // Rest of logic unchanged
}

bool _matchesExceptions(EmailMessage message, RuleExceptions exceptions) {
  return _matchesPatternList(message.from, exceptions.from) ||
      _matchesHeaderList(message.headers, exceptions.header) ||  // ✅ Check actual headers
      _matchesPatternList(message.subject, exceptions.subject) ||
      _matchesPatternList(message.body, exceptions.body);
}

// New helper method
bool _matchesHeaderList(Map<String, String> headers, List<String> patterns) {
  if (patterns.isEmpty) return false;

  // Convert headers to "key:value" format for matching (similar to desktop Python app)
  final headerString = headers.entries
      .map((e) => '${e.key.toLowerCase()}:${e.value.toLowerCase()}')
      .join(' ')
      .trim();

  return patterns.any((pattern) {
    try {
      final regex = compiler.compile(pattern);
      return regex.hasMatch(headerString);
    } catch (e) {
      _logger.w('Header pattern match failed for pattern: $pattern', error: e);
      return false;
    }
  });
}
```

**Acceptance Criteria**

- [ ] `_matchesHeaderList()` helper method created
- [ ] `_matchesConditions()` updated to use `_matchesHeaderList()` for header matching
- [ ] `_matchesExceptions()` updated to use `_matchesHeaderList()` for header matching
- [ ] Unit tests added to verify header-based rules match correctly
- [ ] Unit tests added to verify header-based exceptions work correctly
- [ ] Test with real spam emails containing suspicious headers (X-Spam-Status, Reply-To spoofing, etc.)
- [ ] All existing tests still pass (81/81)
- [ ] Manual test: Create rule `"header": ["^x-spam-status:.*yes"]` and verify it catches spam

**Files to Modify**

- `mobile-app/lib/core/services/rule_evaluator.dart` (lines 53-73, add new method)
- `mobile-app/test/unit/rule_evaluator_test.dart` (create if doesn't exist, add header matching tests)

**Testing Strategy**

1. Create unit test with mock EmailMessage containing headers
2. Create rule with header condition (e.g., `"header": ["^x-spam-status:.*yes"]`)
3. Verify rule matches when header exists
4. Verify rule doesn't match when header doesn't exist
5. Test exception patterns for headers
6. Test with multiple header patterns (OR logic)

**Related Issues**

Will reference Issue #11 (Missing RuleEvaluator unit tests) - Should be addressed together

**Priority Justification**

**Critical** because:
- Core spam filtering functionality is broken for header-based rules
- Could allow spam through that should be filtered
- No workaround available for users
- Affects production readiness

---

### Issue #2: Scan mode bypass in EmailScanner - readonly mode still deletes emails ✅ COMPLETE (Jan 3, 2026)

**Labels:** `bug`, `priority:critical`, `component:scanner`, `data-loss-risk`

**✅ COMPLETED** - See commit for implementation details

**Description:**

The `EmailScanner.scanInbox()` method directly executes delete/move actions without checking the scan mode from `EmailScanProvider`. This means the readonly, testLimit, and testAll modes are completely bypassed.

**Root Cause:** Action execution happens in EmailScanner without consulting EmailScanProvider's scan mode settings.

**Impact:**
- Users selecting "readonly" mode will still have emails **deleted/moved** ❌
- testLimit mode will not respect the email limit
- High risk of accidental data loss
- UI shows scan mode but it has no effect

**Current Behavior**

In `EmailScanner.scanInbox()` (lines 88-99):
```dart
if (result.shouldDelete) {
  action = EmailActionType.delete;
  try {
    await platform.takeAction(  // ❌ No scan mode check before deletion!
      message: message,
      action: FilterAction.delete,
    );
  } catch (e) {
    success = false;
    error = 'Delete failed: $e';
  }
}
```

**Expected Behavior**

The scanner should check `EmailScanProvider.scanMode` before executing any email modifications:
- **readonly**: Never execute actions, only log what would happen
- **testLimit**: Execute actions only until limit reached
- **testAll**: Execute all actions (with revert capability)

**Proposed Solution**

Add scan mode enforcement before action execution:

```dart
// Add at the top of scanInbox method
final scanMode = scanProvider.scanMode;
final testLimit = scanProvider.emailTestLimit;
int actionsExecuted = 0;

// Before executing each action
if (result.shouldDelete) {
  action = EmailActionType.delete;

  // ✅ Check scan mode before executing
  if (scanMode == ScanMode.readonly) {
    // Log only, don't execute
    _logger.i('[READONLY] Would delete: ${message.from} - ${message.subject}');
    success = true;  // Mark as would-succeed
  } else if (scanMode == ScanMode.testLimit && actionsExecuted >= (testLimit ?? 0)) {
    // Limit reached, don't execute
    _logger.i('[LIMIT REACHED] Skipping delete: ${message.from}');
    success = true;
  } else {
    // Execute action
    try {
      await platform.takeAction(
        message: message,
        action: FilterAction.delete,
      );
      actionsExecuted++;
    } catch (e) {
      success = false;
      error = 'Delete failed: $e';
    }
  }
}
```

**Acceptance Criteria**

- [ ] Scan mode is retrieved from EmailScanProvider at start of scanInbox()
- [ ] readonly mode: No emails deleted/moved (actions logged only)
- [ ] testLimit mode: Actions stop after limit reached
- [ ] testAll mode: All actions executed (unchanged behavior)
- [ ] Action counts updated correctly for UI display
- [ ] Unit tests verify scan mode enforcement
- [ ] Integration test: Run readonly scan, verify no emails modified
- [ ] Integration test: Run testLimit=10, verify exactly 10 actions executed
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/core/services/email_scanner.dart` (lines 66-125 - add mode checking)
- `mobile-app/test/integration/email_scanner_test.dart` (add scan mode tests)

**Testing Strategy**

1. Create integration test with mock email provider
2. Set scanMode to readonly, run scan, verify no takeAction() calls
3. Set scanMode to testLimit(5), verify exactly 5 takeAction() calls
4. Set scanMode to testAll, verify all actions executed
5. Manual test: Select readonly mode in UI, run scan, verify no emails deleted

**Related Issues**

Will reference Issue #7 (Duplicate scan mode logic in EmailScanProvider)

**Priority Justification**

**Critical** because:
- High risk of **accidental data loss** (emails deleted in readonly mode)
- UI feature (scan modes) is non-functional
- Users expect readonly mode to be safe
- Violates principle of least surprise
- Blocks production deployment (safety critical)

---

### Issue #3: Credential type confusion in SecureCredentialsStore ✅ COMPLETE (Jan 3, 2026)

**Labels:** `bug`, `priority:critical`, `component:auth`, `security`

**✅ COMPLETED** - See commit for implementation details

**Description:**

The `SecureCredentialsStore.getCredentials()` method silently falls back to Gmail OAuth tokens when standard IMAP credentials don't exist. This creates confusion between credential types (IMAP passwords vs OAuth tokens) and could lead to authentication failures.

**Root Cause:** Mixed credential types at the storage layer without caller awareness.

**Impact:**
- Callers don't know they received OAuth credentials instead of IMAP credentials
- Could attempt to use OAuth access tokens as IMAP passwords
- Makes debugging auth failures difficult
- Violates single responsibility principle

**Current Behavior**

In `SecureCredentialsStore.getCredentials()` (lines 137-161):
```dart
Future<Credentials?> getCredentials(String accountId) async {
  try {
    final email = await _storage.read(key: '${_credentialsPrefix}${accountId}_email');

    // If no standard credentials found, check Gmail tokens as fallback
    if (email == null) {
      final gmailTokens = await getGmailTokens(accountId);  // ❌ Silent fallback
      if (gmailTokens != null) {
        _logger.d('Using Gmail tokens for credentials: $accountId');
        return Credentials(
          email: gmailTokens.email,
          password: gmailTokens.accessToken,  // ❌ OAuth token as password!
          // ...
        );
      }
      return null;
    }
    // ...
  }
}
```

**Expected Behavior**

Credential retrieval should be explicit about type:
- Callers should explicitly choose between `getCredentials()` (IMAP) or `getGmailTokens()` (OAuth)
- No silent type conversion
- Clear separation of authentication methods

**Proposed Solution**

**Option 1: Remove the fallback (Recommended)**
```dart
Future<Credentials?> getCredentials(String accountId) async {
  final email = await _storage.read(key: '${_credentialsPrefix}${accountId}_email');
  if (email == null) {
    return null;  // ✅ No fallback - caller must check both methods
  }
  // ... rest of method unchanged
}

// Callers update to:
final credentials = await store.getCredentials(accountId) ??
                   await store.getGmailTokens(accountId)?.toCredentials();
```

**Option 2: Add opt-in parameter**
```dart
Future<Credentials?> getCredentials(
  String accountId, {
  bool includeOAuthFallback = false,  // ✅ Explicit opt-in
}) async {
  // ... check standard credentials first
  if (email == null && includeOAuthFallback) {
    final gmailTokens = await getGmailTokens(accountId);
    if (gmailTokens != null) {
      _logger.d('Falling back to Gmail tokens for: $accountId');
      return gmailTokens.toCredentials();
    }
  }
  return null;
}
```

**Option 3: Return wrapper indicating type**
```dart
class CredentialsResult {
  final Credentials credentials;
  final CredentialType type;  // enum: imap, oauth
}

Future<CredentialsResult?> getCredentials(String accountId) async {
  // ... check IMAP first, then OAuth
  // Return wrapper indicating which type was found
}
```

**Acceptance Criteria**

- [ ] Choose and implement one of the three proposed solutions
- [ ] Update all callers of `getCredentials()` to handle the new behavior
- [ ] Remove silent fallback logic
- [ ] Add logging when credential type switching occurs (if applicable)
- [ ] Unit tests verify no silent fallback
- [ ] Unit tests verify explicit OAuth retrieval still works
- [ ] All existing tests still pass (81/81)
- [ ] Manual test: Verify Gmail and IMAP accounts still authenticate correctly

**Files to Modify**

- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` (lines 137-161)
- All callers of `getCredentials()`:
  - `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`
  - `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`
  - `mobile-app/lib/ui/screens/account_selection_screen.dart`
  - Others as discovered

**Testing Strategy**

1. Unit test: Save IMAP credentials, verify `getCredentials()` returns them
2. Unit test: Save only Gmail tokens, verify `getCredentials()` returns null (not tokens)
3. Unit test: Save both, verify `getCredentials()` returns IMAP (not tokens)
4. Integration test: Verify Gmail auth flow still works
5. Integration test: Verify AOL IMAP auth flow still works

**Related Issues**

None

**Priority Justification**

**Critical** because:
- Security concern (credential type confusion)
- Could lead to authentication failures
- Violates principle of explicit over implicit
- Makes debugging difficult
- Affects code maintainability

---

### Issue #4: Silent regex compilation failures in PatternCompiler

**Labels:** `bug`, `priority:critical`, `component:core`, `user-experience`

**Description:**

The `PatternCompiler.compile()` method silently caches a "never matches" regex pattern when compilation fails. Users have no way to know their regex patterns are invalid, and rules silently stop working.

**Root Cause:** Exception handling swallows regex compilation errors without logging or notification.

**Impact:**
- Invalid regex patterns in rules.yaml silently fail
- Rules stop working with no user notification
- No visibility into which patterns failed
- Users waste time debugging why rules don't match
- Could allow spam through due to broken rules

**Current Behavior**

In `PatternCompiler.compile()` (lines 10-26):
```dart
RegExp compile(String pattern) {
  if (_cache.containsKey(pattern)) {
    _hits++;
    return _cache[pattern]!;
  }

  _misses++;
  try {
    final regex = RegExp(pattern, caseSensitive: false);
    _cache[pattern] = regex;
    return regex;
  } catch (e) {
    // Invalid regex - cache a pattern that never matches  // ❌ Silent failure!
    final fallback = RegExp(r'(?!)');
    _cache[pattern] = fallback;
    return fallback;
  }
}
```

**Expected Behavior**

Compilation failures should be:
1. Logged with the invalid pattern
2. Optionally reported to the user (UI notification or validation step)
3. Documented in pattern compilation metrics

**Proposed Solution**

**Option 1: Add logging (Minimal fix)**
```dart
} catch (e) {
  // ✅ Log the failure
  _logger.e('Invalid regex pattern: "$pattern" - Error: $e');

  // Cache a pattern that never matches
  final fallback = RegExp(r'(?!)');
  _cache[pattern] = fallback;
  return fallback;
}
```

**Option 2: Track failures for reporting (Better)**
```dart
class PatternCompiler {
  final Map<String, RegExp> _cache = HashMap();
  final Map<String, String> _failures = HashMap();  // ✅ Track failures
  int _hits = 0;
  int _misses = 0;

  RegExp compile(String pattern) {
    // ... existing cache check

    try {
      final regex = RegExp(pattern, caseSensitive: false);
      _cache[pattern] = regex;
      return regex;
    } catch (e) {
      // ✅ Log and track failure
      final errorMsg = e.toString();
      _logger.e('Invalid regex pattern: "$pattern" - Error: $errorMsg');
      _failures[pattern] = errorMsg;

      final fallback = RegExp(r'(?!)');
      _cache[pattern] = fallback;
      return fallback;
    }
  }

  // ✅ Add getter for failures
  Map<String, String> get compilationFailures => Map.unmodifiable(_failures);

  // ✅ Add method to check if pattern is valid
  bool isPatternValid(String pattern) => !_failures.containsKey(pattern);
}
```

**Option 3: Fail fast (Aggressive - could break loading)**
```dart
} catch (e) {
  _logger.e('Invalid regex pattern: "$pattern" - Error: $e');
  // ✅ Throw exception instead of returning fallback
  throw InvalidPatternException('Regex compilation failed for pattern "$pattern": $e');
}
```

**Acceptance Criteria**

- [ ] Choose and implement one of the three proposed solutions (recommend Option 2)
- [ ] All regex compilation failures are logged with pattern and error
- [ ] Add `compilationFailures` getter for UI to display warnings
- [ ] Add unit test that passes invalid regex, verifies logging
- [ ] Add unit test that invalid pattern never matches
- [ ] Consider adding UI warning when rules load with invalid patterns
- [ ] All existing tests still pass (81/81)
- [ ] Manual test: Add invalid regex to rules.yaml, verify logged warning

**Files to Modify**

- `mobile-app/lib/core/services/pattern_compiler.dart` (lines 10-26, add failure tracking)
- `mobile-app/lib/core/providers/rule_set_provider.dart` (optionally check for failures after loading)
- `mobile-app/test/unit/pattern_compiler_test.dart` (add invalid pattern tests)

**Testing Strategy**

1. Unit test: Compile invalid regex, verify logged error
2. Unit test: Verify invalid pattern cached as never-match
3. Unit test: Verify `compilationFailures` contains failed patterns
4. Unit test: Verify `isPatternValid()` returns false for invalid patterns
5. Integration test: Load rules.yaml with invalid pattern, verify warning displayed

**Related Issues**

None

**Priority Justification**

**Critical** because:
- Users have no visibility into broken rules
- Silent failures violate principle of least surprise
- Could allow spam through due to broken rules
- Wastes user time debugging
- Poor user experience
- Affects production readiness (validation requirement)

---

## ⚠️ HIGH PRIORITY

### Issue #5: Missing refresh token storage on Android breaks token refresh

**Labels:** `bug`, `priority:high`, `component:auth`, `platform:android`

**Description:**

When signing in via Google's native SDK on Android, the `GoogleAuthService` sets `refreshToken` to `null`. While the native SDK handles refresh internally, this prevents HTTP-based token refresh when the app is killed and restarted with expired tokens.

**Root Cause:** Refresh token not captured and stored during Android OAuth flow.

**Impact:**
- Android users may need to re-authenticate more frequently than necessary
- HTTP-based token refresh not available as fallback
- Inconsistent behavior between Android and Windows (Windows stores refresh token)

**Current Behavior**

In `GoogleAuthService._handleSignIn()` (lines 422-428):
```dart
final tokens = GmailTokens(
  accessToken: authorization.accessToken,
  refreshToken: null,  // ❌ Native SDK manages refresh internally
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  grantedScopes: _scopes,
  email: _currentUser!.email,
);
```

**Expected Behavior**

Refresh token should be stored for fallback HTTP-based refresh, even when native SDK is available.

**Proposed Solution**

Capture and store refresh token on Android:

```dart
// After successful sign-in
final authentication = await _currentUser!.authentication;

final tokens = GmailTokens(
  accessToken: authentication.accessToken,
  refreshToken: authentication.idToken,  // ✅ Store for HTTP fallback
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  grantedScopes: _scopes,
  email: _currentUser!.email,
);
```

Note: Verify if `google_sign_in` provides refresh token. If not, may need to use `googleapis_auth` for initial OAuth with refresh token, then use native SDK for refresh.

**Alternative:** Use `googleSignIn.signInSilently()` refresh mechanism but also store refresh token from initial authorization code exchange.

**Acceptance Criteria**

- [ ] Refresh token captured during Android sign-in
- [ ] Refresh token stored via SecureTokenStore
- [ ] HTTP-based refresh works as fallback when native refresh fails
- [ ] Token expiry handled correctly
- [ ] Unit tests verify refresh token storage
- [ ] Manual test on Android: Sign in, kill app, reopen after 1 hour, verify refresh works
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/adapters/auth/google_auth_service.dart` (lines 422-428)
- `mobile-app/test/adapters/auth/google_auth_service_test.dart` (add refresh token tests)

**Testing Strategy**

1. Unit test: Verify refresh token not null after Android sign-in
2. Unit test: Verify refresh token stored in secure storage
3. Integration test: Mock expired token scenario, verify refresh succeeds
4. Manual test: Sign in on Android, check secure storage for refresh token
5. Manual test: Force token expiry, verify HTTP refresh works

**Related Issues**

None

**Priority Justification**

**High** because:
- Affects user experience (frequent re-auth)
- Inconsistent cross-platform behavior
- Degrades security (encourages users to stay signed in longer)
- Workaround exists (native refresh) but not ideal

---

### Issue #6: Overly broad exception mapping in GenericIMAPAdapter hides auth errors

**Labels:** `bug`, `priority:high`, `component:email-adapter`, `observability`

**Description:**

The `GenericIMAPAdapter.loadCredentials()` catch block converts all unknown errors to `ConnectionException`, which could hide actual authentication errors and provide misleading error messages to users.

**Root Cause:** Fallback exception handling too broad.

**Impact:**
- Authentication errors disguised as connection errors
- Misleading error messages confuse users
- Difficult to debug actual issues
- Users may check network when problem is credentials

**Current Behavior**

In `GenericIMAPAdapter.loadCredentials()` (lines 146-165):
```dart
} catch (e) {
  print('[IMAP] Failed to load credentials: $e');
  _logger.e('[IMAP] Failed to load credentials: $e');
  if (e is AuthenticationException) {
    rethrow;
  }

  // Map handshake and network errors to connection failures
  if (e is HandshakeException) {
    throw ConnectionException('TLS certificate validation failed', e);
  }
  if (e is SocketException || e is TimeoutException) {
    throw ConnectionException('Network connection failed', e);
  }

  // Fallback: treat other errors as connection failures  // ❌ Too broad!
  throw ConnectionException('IMAP connection failed', e);
}
```

**Expected Behavior**

Only map known connection-related errors. Unknown errors should be rethrown with context.

**Proposed Solution**

```dart
} catch (e) {
  _logger.e('[IMAP] Failed to load credentials', error: e);

  if (e is AuthenticationException) {
    rethrow;
  }

  // Map known connection errors
  if (e is HandshakeException) {
    throw ConnectionException('TLS certificate validation failed', e);
  }
  if (e is SocketException || e is TimeoutException) {
    throw ConnectionException('Network connection failed', e);
  }

  // ✅ Rethrow unknown errors instead of converting
  _logger.e('[IMAP] Unexpected error during IMAP connection', error: e);
  rethrow;  // Let caller handle unknown errors appropriately
}
```

**Acceptance Criteria**

- [ ] Remove fallback `ConnectionException` for unknown errors
- [ ] Unknown errors rethrown with logging
- [ ] Known connection errors still mapped to ConnectionException
- [ ] AuthenticationException still rethrown
- [ ] Unit test: Verify unknown exception types are not converted
- [ ] Unit test: Verify HandshakeException converted to ConnectionException
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` (lines 146-165)
- `mobile-app/test/adapters/email_providers/generic_imap_adapter_test.dart` (add exception mapping tests)

**Testing Strategy**

1. Unit test: Throw custom exception, verify it's not converted to ConnectionException
2. Unit test: Throw HandshakeException, verify converted to ConnectionException
3. Unit test: Throw AuthenticationException, verify rethrown
4. Manual test: Force unknown error, verify correct error message displayed

**Related Issues**

None

**Priority Justification**

**High** because:
- Affects observability and debugging
- Misleads users about actual problems
- Hides authentication issues
- Makes support difficult

---

### Issue #7: Duplicate scan mode enforcement logic between EmailScanner and EmailScanProvider ✅ COMPLETE (Jan 3, 2026)

**Labels:** `technical-debt`, `priority:high`, `component:scanner`, `refactoring`

**✅ COMPLETED** - Resolved together with Issue #2 (scan mode bypass fix)

**Description:**

The `EmailScanProvider.recordResult()` method contains logic to determine whether actions should be executed based on scan mode, but this duplicates responsibility that should be in `EmailScanner`. The action has already been executed by the time `recordResult()` is called.

**Root Cause:** Scan mode enforcement implemented in wrong layer.

**Impact:**
- Confusing code organization
- `shouldExecuteAction` logic is too late (action already attempted)
- Makes it unclear where scan mode enforcement happens
- Risk of inconsistent behavior

**Current Behavior**

In `EmailScanProvider.recordResult()` (lines 315-358):
```dart
void recordResult(EmailActionResult result) {
  // ❌ This logic is too late - action already executed!
  bool shouldExecuteAction = _scanMode != ScanMode.readonly &&
      (_emailTestLimit == null || _lastRunActionIds.length < _emailTestLimit!);

  if (shouldExecuteAction) {
    // Track action for potential revert
    _lastRunActionIds.add(result.email.id);
    _lastRunActions.add(result);
    _logger.i('📝 Action recorded (will execute): ${result.action} - ${result.email.from}');
  } else {
    // Read-only or limit reached: log what would happen
    // ...
  }

  // Always record the result for UI/history
  _results.add(result);

  // Only update execution counts if the action should execute
  if (shouldExecuteAction) {
    switch (result.action) {
      case EmailActionType.delete:
        _deletedCount++;
        break;
      // ...
    }
  }
}
```

**Expected Behavior**

- EmailScanner should check scan mode BEFORE calling `platform.takeAction()`
- EmailScanProvider should only record results and update state
- Clear separation of concerns

**Proposed Solution**

This issue will be resolved by implementing Issue #2 (scan mode bypass fix). After that fix:

1. Remove `shouldExecuteAction` logic from `recordResult()`
2. Simplify `recordResult()` to just record results
3. Trust that EmailScanner only executed appropriate actions

```dart
void recordResult(EmailActionResult result) {
  // ✅ Simplified - just record results
  _results.add(result);

  // Track for revert (if scanMode allows revert)
  if (_scanMode == ScanMode.testAll && result.success) {
    _lastRunActionIds.add(result.email.id);
    _lastRunActions.add(result);
  }

  // Update counts based on what actually happened
  if (result.success) {
    switch (result.action) {
      case EmailActionType.delete:
        _deletedCount++;
        break;
      // ...
    }
  }

  notifyListeners();
}
```

**Acceptance Criteria**

- [ ] Issue #2 (scan mode bypass) implemented first
- [ ] Remove `shouldExecuteAction` logic from `recordResult()`
- [ ] `recordResult()` simplified to just record results
- [ ] All scan mode enforcement in EmailScanner
- [ ] Unit tests verify simplified recordResult() behavior
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/core/providers/email_scan_provider.dart` (lines 315-358 - simplify)
- `mobile-app/test/core/providers/email_scan_provider_test.dart` (update tests)

**Testing Strategy**

1. Unit test: Call `recordResult()` with various actions, verify counts updated
2. Unit test: Verify no scan mode logic in `recordResult()`
3. Integration test: Verify scan mode enforcement still works (in EmailScanner)

**Related Issues**

Depends on Issue #2 (scan mode bypass fix)

**Priority Justification**

**High** because:
- Code organization affects maintainability
- Confusing for new developers
- Risk of bugs from unclear responsibilities
- Should be fixed while working on Issue #2

---

### Issue #8: Inconsistent logging - mix of print() and Logger

**Labels:** `code-quality`, `priority:high`, `observability`

**Description:**

The codebase uses both `print()` statements (9 occurrences) and proper `_logger` calls (207 occurrences). This inconsistency makes it difficult to control log levels, filter logs, and disable logs in production.

**Impact:**
- Cannot filter or disable `print()` logs in production
- Inconsistent log format
- Some errors not captured by logger
- Difficult to debug production issues

**Occurrences:**

1. `mobile-app/lib/main.dart:22` - Print for migration errors
2. `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:110` - IMAP connection log
3. `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:136` - IMAP connection log
4. `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:144` - IMAP error log
5. `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:147` - IMAP error log
6. `mobile-app/lib/core/services/email_scanner.dart:140` - Disconnect error
7-9. Additional occurrences in other files

**Expected Behavior**

All logging should use the `Logger` package with appropriate log levels.

**Proposed Solution**

Replace all `print()` statements with appropriate `_logger` calls:

**Example 1: main.dart:22**
```dart
// Before:
print('Migration error: ${e.toString()}');

// After:
_logger.e('Migration error', error: e, stackTrace: stackTrace);
```

**Example 2: generic_imap_adapter.dart:110**
```dart
// Before:
print('[IMAP] Successfully connected to IMAP server');

// After:
_logger.i('[IMAP] Successfully connected to IMAP server');
```

**Example 3: email_scanner.dart:140**
```dart
// Before:
print('Failed to disconnect: $e');

// After:
_logger.w('Failed to disconnect', error: e);
```

**Acceptance Criteria**

- [ ] All `print()` calls replaced with `_logger` calls
- [ ] Appropriate log levels used (e.g., error for errors, info for success, debug for verbose)
- [ ] Logger initialized in all files that need it
- [ ] Search codebase for remaining `print(` - should return 0 results
- [ ] All existing tests still pass (81/81)
- [ ] Manual test: Verify logs appear in console with proper formatting

**Files to Modify**

- `mobile-app/lib/main.dart`
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`
- `mobile-app/lib/core/services/email_scanner.dart`
- Any other files with `print()` statements

**Testing Strategy**

1. Search codebase: `grep -r "print(" lib/` should return 0 results
2. Run app, verify all logs appear with Logger formatting
3. Test error scenarios, verify errors logged correctly

**Related Issues**

None

**Priority Justification**

**High** because:
- Affects production observability
- Cannot control log levels
- Inconsistent with project standards
- Easy fix with high value

---

## 📝 MEDIUM/LOW PRIORITY

### Issue #9: PatternCompiler cache grows unbounded - memory leak risk

**Labels:** `performance`, `priority:medium`, `memory`

**Description:**

The `PatternCompiler` cache stores compiled regex patterns but never automatically clears them. In typical usage with ~50 rules this is negligible, but if rules are frequently modified (e.g., user testing patterns), the cache could accumulate invalid entries.

**Impact:**
- Low for typical usage (50-100 patterns)
- Could accumulate stale patterns if rules frequently updated
- No automatic cleanup mechanism
- `clear()` method exists but never called

**Current Behavior**

In `PatternCompiler`:
```dart
final Map<String, RegExp> _cache = HashMap();

void clear() {  // ❌ Never called automatically
  _cache.clear();
  _hits = 0;
  _misses = 0;
}
```

**Expected Behavior**

Cache should either:
1. Clear when rules are reloaded, OR
2. Implement LRU eviction, OR
3. Document that `clear()` should be called when rules change

**Proposed Solution**

**Option 1: Clear on rule reload (Simplest)**
```dart
// In RuleSetProvider.loadRules()
Future<void> loadRules() async {
  // ... load rules from storage

  // ✅ Clear pattern cache when rules reload
  final compiler = PatternCompiler();
  compiler.clear();

  // ... rest of loading logic
}
```

**Option 2: LRU cache with max size**
```dart
class PatternCompiler {
  final Map<String, RegExp> _cache = LinkedHashMap();  // Preserves insertion order
  static const int _maxCacheSize = 1000;

  RegExp compile(String pattern) {
    if (_cache.containsKey(pattern)) {
      // Move to end (most recently used)
      final regex = _cache.remove(pattern)!;
      _cache[pattern] = regex;
      _hits++;
      return regex;
    }

    _misses++;
    try {
      final regex = RegExp(pattern, caseSensitive: false);

      // ✅ Evict oldest if cache full
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }

      _cache[pattern] = regex;
      return regex;
    } catch (e) {
      // ... error handling
    }
  }
}
```

**Option 3: Document manual clearing (Minimal)**
```dart
/// Pattern compiler with caching for regex patterns.
///
/// **Important:** Call [clear()] when rules are reloaded to prevent
/// stale patterns from accumulating in the cache.
class PatternCompiler {
  // ... existing implementation
}
```

**Acceptance Criteria**

- [ ] Choose and implement one of the three options (recommend Option 1 or 2)
- [ ] Document cache clearing strategy in code comments
- [ ] Unit test: Verify cache cleared when appropriate
- [ ] Unit test: If using LRU, verify eviction works correctly
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/core/services/pattern_compiler.dart`
- `mobile-app/lib/core/providers/rule_set_provider.dart` (if Option 1)
- `mobile-app/test/unit/pattern_compiler_test.dart` (add cache tests)

**Testing Strategy**

1. Unit test: Load 1000+ patterns, verify cache size stays reasonable
2. Unit test: Reload rules, verify cache cleared
3. Performance test: Measure memory usage with large cache

**Related Issues**

None

**Priority Justification**

**Medium** because:
- Low impact in typical usage
- No immediate risk
- Good housekeeping
- Documents expected behavior

---

### Issue #10: EmailMessage.getHeader() returns empty string instead of null

**Labels:** `code-quality`, `priority:low`, `null-safety`

**Description:**

The `EmailMessage.getHeader()` method signature returns `String?` (nullable) but always returns a string - empty string when header not found. This makes it impossible to distinguish between "header exists with empty value" and "header doesn't exist".

**Impact:**
- Cannot distinguish missing headers from empty headers
- Violates null safety conventions
- Signature misleading (says nullable but never null)
- Minor impact - rare to have empty header values

**Current Behavior**

In `EmailMessage.getHeader()` (lines 26-35):
```dart
String? getHeader(String key) {
  final lowerKey = key.toLowerCase();
  return headers.entries
      .firstWhere(
        (e) => e.key.toLowerCase() == lowerKey,
        orElse: () => const MapEntry('', ''),  // ❌ Returns empty string
      )
      .value;
}
```

**Expected Behavior**

Return `null` when header doesn't exist (matching method signature).

**Proposed Solution**

```dart
String? getHeader(String key) {
  final lowerKey = key.toLowerCase();
  final entry = headers.entries.firstWhere(
    (e) => e.key.toLowerCase() == lowerKey,
    orElse: () => const MapEntry('', ''),
  );
  // ✅ Return null if header not found
  return entry.key.isEmpty ? null : entry.value;
}
```

**Alternative (more explicit):**
```dart
String? getHeader(String key) {
  final lowerKey = key.toLowerCase();
  try {
    return headers.entries
        .firstWhere((e) => e.key.toLowerCase() == lowerKey)
        .value;
  } catch (StateError) {
    return null;  // ✅ Header not found
  }
}
```

**Acceptance Criteria**

- [ ] `getHeader()` returns `null` when header doesn't exist
- [ ] `getHeader()` returns actual value when header exists (including empty string if value is empty)
- [ ] Update any callers that check for empty string to check for null
- [ ] Unit tests verify null returned when header missing
- [ ] Unit tests verify empty string returned when header value is empty
- [ ] All existing tests still pass (81/81)

**Files to Modify**

- `mobile-app/lib/core/models/email_message.dart` (lines 26-35)
- Search for callers: `grep -r "getHeader(" lib/` and update null checks
- `mobile-app/test/core/models/email_message_test.dart` (add null return tests)

**Testing Strategy**

1. Unit test: Call `getHeader('NonExistent')`, verify returns `null`
2. Unit test: Add header with empty value, verify returns `""`
3. Unit test: Add header with value, verify returns value
4. Check all callers handle `null` correctly

**Related Issues**

Will affect Issue #1 (header matching) - should coordinate fixes

**Priority Justification**

**Low** because:
- Minor impact (rare use case)
- Workaround exists (check for empty string)
- Nice-to-have for code correctness
- Improves null safety compliance

---

### Issue #11: Missing unit tests for RuleEvaluator - core spam detection logic untested

**Labels:** `testing`, `priority:critical`, `component:core`

**Description:**

The `RuleEvaluator` is the **core spam detection component** but has **no unit tests**. This is a critical gap that allowed bugs #1 and #2 (header matching) to reach production undetected.

**Impact:**
- Core business logic not validated
- Bugs can reach production undetected (already happened)
- Difficult to refactor safely
- No regression protection
- High risk for critical component

**Current State**

- `mobile-app/lib/core/services/rule_evaluator.dart` exists (100+ lines)
- No corresponding test file exists
- Only covered indirectly through integration tests
- Header matching bugs prove inadequate coverage

**Expected Behavior**

Comprehensive unit test suite covering:
1. Rule condition matching (from, subject, body, **header**)
2. Exception handling (from, subject, body, **header**)
3. Condition type logic (AND vs OR)
4. Safe sender checking (takes precedence)
5. Multiple rules evaluation (execution order)
6. Edge cases (empty patterns, null values, invalid regex)

**Proposed Test Cases**

```dart
// test/unit/rule_evaluator_test.dart
void main() {
  group('RuleEvaluator', () {
    late RuleEvaluator evaluator;
    late PatternCompiler compiler;
    late SafeSenderList safeSenders;

    setUp(() {
      compiler = PatternCompiler();
      safeSenders = SafeSenderList(patterns: []);
      evaluator = RuleEvaluator(
        compiler: compiler,
        safeSenders: safeSenders,
      );
    });

    group('_matchesConditions', () {
      test('matches email when from pattern matches', () {
        // Test from matching
      });

      test('matches email when subject pattern matches', () {
        // Test subject matching
      });

      test('matches email when body pattern matches', () {
        // Test body matching
      });

      test('matches email when header pattern matches', () {
        // ✅ CRITICAL: Test header matching (would have caught bug #1)
        final email = EmailMessage(
          id: '1',
          from: 'user@example.com',
          subject: 'Test',
          body: 'Test',
          headers: {'X-Spam-Status': 'Yes, score=9.5'},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final rule = Rule(
          name: 'SpamHeaderRule',
          enabled: true,
          conditions: RuleConditions(
            type: ConditionType.or,
            header: ['^x-spam-status:.*yes'],
          ),
          actions: RuleActions(delete: true),
        );

        final result = evaluator.evaluate(email, [rule]);
        expect(result, isNotNull);
        expect(result!.shouldDelete, isTrue);
      });

      test('AND logic requires all conditions match', () {
        // Test AND logic
      });

      test('OR logic requires any condition match', () {
        // Test OR logic
      });
    });

    group('_matchesExceptions', () {
      test('email matches from exception', () {
        // Test from exception
      });

      test('email matches header exception', () {
        // ✅ CRITICAL: Test header exception (would have caught bug #1)
      });

      test('exception prevents rule from matching', () {
        // Test exception override
      });
    });

    group('safe sender priority', () {
      test('safe sender prevents rule match', () {
        // Test safe sender takes precedence
      });
    });

    group('edge cases', () {
      test('handles empty patterns list', () {
        // Test empty patterns
      });

      test('handles null header value', () {
        // Test null handling
      });

      test('handles invalid regex pattern gracefully', () {
        // Test invalid regex (relates to issue #4)
      });
    });
  });
}
```

**Acceptance Criteria**

- [ ] Create `mobile-app/test/unit/rule_evaluator_test.dart`
- [ ] **Minimum 20 unit tests** covering all scenarios above
- [ ] **Header matching tests** specifically added (prevent regression of bug #1)
- [ ] **Exception tests** specifically added (prevent regression of bug #1)
- [ ] All tests pass
- [ ] Code coverage for RuleEvaluator reaches **>90%**
- [ ] Integration tests still pass (complement unit tests)

**Files to Create**

- `mobile-app/test/unit/rule_evaluator_test.dart` (new file, ~300+ lines)

**Files to Reference**

- `mobile-app/lib/core/services/rule_evaluator.dart` (subject under test)
- `mobile-app/test/unit/safe_sender_list_test.dart` (similar test structure)
- `mobile-app/test/unit/pattern_compiler_test.dart` (similar test structure)

**Testing Strategy**

1. Create comprehensive test file with all scenarios
2. Run tests: `flutter test test/unit/rule_evaluator_test.dart`
3. Verify coverage: `flutter test --coverage`
4. Target >90% coverage for rule_evaluator.dart
5. Fix any failing tests by fixing bugs in RuleEvaluator

**Related Issues**

- Issue #1 (Header matching bug) - Tests would have caught this
- Issue #4 (Silent regex failures) - Should test invalid patterns

**Priority Justification**

**Critical** because:
- Core business logic completely untested
- Already allowed 2 critical bugs to reach production
- Required for safe refactoring
- Industry best practice: test critical paths
- Blocks production confidence
- Should have been part of Phase 2.1 verification

---

## Summary

**Total Issues: 11**
- 🔴 Critical Priority: 4 (Issues #1, #2, #3, #4)
- ⚠️ High Priority: 4 (Issues #5, #6, #7, #8)
- 📝 Medium Priority: 1 (Issue #9)
- 💡 Low Priority: 2 (Issues #10, #11 reclassified as Critical)

**Recommended Implementation Order:**

1. **Issue #11** (Create RuleEvaluator tests) - Foundation for fixing other issues safely
2. **Issue #1** (Fix header matching) - Critical bug
3. **Issue #2** (Fix scan mode bypass) - Critical safety issue
4. **Issue #4** (Add regex logging) - Critical UX issue
5. **Issue #3** (Fix credential confusion) - Critical architecture issue
6. **Issue #8** (Standardize logging) - Quick win, high value
7. **Issue #7** (Refactor scan mode logic) - Do while fixing #2
8. **Issue #6** (Fix exception mapping) - High priority
9. **Issue #5** (Android refresh token) - High priority
10. **Issue #10** (Fix null safety) - Do while fixing #1
11. **Issue #9** (Cache management) - Technical debt

**Estimated Total Effort:** 3-5 days for all issues

---

**Next Steps:**
1. Review and prioritize issues with team
2. Create GitHub issues by copying relevant sections
3. Assign issues to sprint
4. Begin implementation with Issue #11 (test foundation)
