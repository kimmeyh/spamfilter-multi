# Issue Backlog

Code review issues tracked in GitHub. Last updated: January 7, 2026.

## Status Summary

| Status | Count | Issues |
|--------|-------|--------|
| ✅ Fixed | 8 | #4, #8, #18, #38, #39, #40, #41, #43 |
| 🔄 Open | 6 | #9, #10, #12, #13, #14, #44 |
| 📋 Created | 1 | #44 (Outlook implementation) |

---

## ✅ Fixed Issues

### Issue #4: Silent regex compilation failures
- **Fixed**: Jan 3, 2026
- **Solution**: PatternCompiler now logs and tracks invalid patterns
- **Tests**: 9 new tests added

### Issue #8: Header matching bug in RuleEvaluator
- **Fixed**: Jan 3, 2026
- **Solution**: Rules now properly check email headers
- **Tests**: 32 new tests with 97.96% coverage

### Issue #18: Missing RuleEvaluator unit tests
- **Fixed**: Jan 3, 2026
- **Solution**: Comprehensive test suite created
- **File**: `test/unit/rule_evaluator_test.dart`

### Issue #38: Python-style inline regex flags
- **Fixed**: Jan 6, 2026
- **Solution**: PatternCompiler strips `(?i)`, `(?m)`, `(?s)`, `(?x)` flags
- **Also fixed**: 23 double-@ patterns in rules_safe_senders.yaml

### Issue #39: Auto-navigation race condition
- **Fixed**: Jan 7, 2026
- **Solution**: Update `_previousStatus` inside condition block

### Issue #40: Hardcoded test limit
- **Fixed**: Jan 7, 2026
- **Solution**: Added configurable slider (5-200)

### Issue #41: Cross-account folder leakage
- **Fixed**: Jan 7, 2026
- **Solution**: Per-account folder storage with `_selectedFoldersByAccount` map
- **Tests**: 7 new tests added

### Issue #43: print() vs Logger inconsistency
- **Fixed**: Jan 7, 2026
- **Solution**: Replaced 6 print() statements with Logger calls

---

## 🔄 Open Issues

### Issue #9: Scan mode bypass in EmailScanner
**Priority**: Critical | **Labels**: `bug`, `data-loss-risk`

Readonly mode may still delete emails. Action execution happens without checking scan mode.

**File**: `email_scanner.dart:66-125`

### Issue #10: Credential type confusion
**Priority**: Critical | **Labels**: `bug`, `security`

Silent fallback from IMAP credentials to OAuth tokens in SecureCredentialsStore.

**File**: `secure_credentials_store.dart:137-161`

### Issue #12: Missing refresh token on Android
**Priority**: High | **Labels**: `bug`, `platform:android`

Refresh token set to null during Android OAuth flow.

**File**: `google_auth_service.dart:422-428`

### Issue #13: Overly broad exception mapping
**Priority**: High | **Labels**: `bug`, `observability`

All unknown errors converted to ConnectionException in GenericIMAPAdapter.

**File**: `generic_imap_adapter.dart:146-165`

### Issue #14: Duplicate scan mode logic
**Priority**: High | **Labels**: `technical-debt`

Scan mode enforcement duplicated between EmailScanner and EmailScanProvider.

**File**: `email_scan_provider.dart:315-358`

### Issue #44: Outlook.com OAuth implementation
**Priority**: Deferred | **Labels**: `enhancement`, `platform:outlook`

Complete Outlook.com/Office 365 OAuth implementation with MSAL.

**File**: `outlook_adapter.dart` (stub)

---

## Test Coverage

| Metric | Value |
|--------|-------|
| Total Tests | 138 |
| Passing | 138 |
| Skipped | 13 (integration tests requiring credentials) |

---

## References

- [GitHub Issues](https://github.com/kimmeyh/spamfilter-multi/issues)
- [CHANGELOG.md](../CHANGELOG.md) - Recent fixes
- [CLAUDE.md](../CLAUDE.md) - Architecture details
