# Sprint 31 Security Audit Report

**Sprint**: 31
**Date**: April 13, 2026
**Scope**: Full codebase security review -- dependencies, SQL, regex, credentials, OWASP, platform security
**App**: MyEmailSpamFilter v0.5.1+1 (Flutter/Dart, Windows + Android)

---

## Executive Summary

The codebase demonstrates **solid foundational security practices**: parameterized SQL queries (92+ operations, zero injection vulnerabilities), PKCE-based OAuth, platform-native encrypted credential storage, and proper .gitignore exclusions. However, the audit identified **31 security findings** across 4 severity levels that should be addressed through prioritized backlog items.

**Key strengths**: SQL injection protection, OAuth PKCE implementation, flutter_secure_storage usage
**Key weaknesses**: ReDoS vulnerability in regex evaluation, missing Android security config, unencrypted SQLite database

---

## Findings Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 3 | Firebase API key in git history, Android allowBackup, regex ReDoS |
| High | 7 | Missing network security config, no code obfuscation, password logging, cert pinning |
| Medium | 13 | YAML parsing limits, unencrypted SQLite, input validation gaps, logging controls |
| Low | 8 | Email format validation, memory credential cleanup, rate limiting, WebView headers |
| **Total** | **31** | |

---

## Category 1: SQL Injection

### Result: [OK] SECURE -- No vulnerabilities found

All 92+ database operations across 9 store classes use parameterized queries via sqflite's safe APIs. No string interpolation in SQL, no dynamic table/column names from user input.

**Files reviewed**: database_helper.dart, account_store.dart, rule_database_store.dart, safe_sender_database_store.dart, scan_result_store.dart, unmatched_email_store.dart, background_scan_log_store.dart, settings_store.dart, migration_manager.dart

**Patterns verified**:
- All WHERE clauses use `?` placeholders with `whereArgs`
- All inserts use map-based `db.insert()` (not string interpolation)
- All rawQuery calls pass parameters via array
- Dynamic WHERE construction only adds SQL keywords, never user input

**Recommendation**: Maintain current practices. Add SQL injection prevention to code review checklist for future development.

---

## Category 2: Regex Injection and ReDoS

### S1. ReDoS -- No timeout protection on regex evaluation (CRITICAL)

**Severity**: Critical
**Files**: rule_evaluator.dart, safe_sender_evaluator.dart, rule_test_screen.dart, safe_sender_list.dart
**Impact**: A malicious or accidentally complex regex pattern can freeze the app indefinitely

All regex matching uses `RegExp.hasMatch()` or `RegExp.firstMatch()` without any timeout mechanism. Dart's RegExp has no built-in timeout. Since regex evaluation happens on the UI thread, a ReDoS pattern will make the app completely unresponsive.

Current rule patterns like `@(?:[a-z0-9-]+\.)*domain\.com$` use nested quantifiers that could theoretically cause backtracking on crafted input, though current patterns are unlikely to trigger in practice.

**Risk increases with**: F56 (manual rule creation UI) and F35 (rule editing UI) which will allow users to enter arbitrary regex patterns.

**Recommended fix**:
- Add timeout-protected regex matching (run in isolate or with timer)
- Add ReDoS pattern detection to PatternCompiler.validatePattern()
- Detect nested quantifiers: `(a+)+`, `(a*)*`, `(a|b)*` patterns
- Flag patterns with exponential backtracking risk before saving

### S2. Pattern validation incomplete -- no ReDoS detection (HIGH)

**Severity**: High
**File**: pattern_compiler.dart (lines 88-127)
**Impact**: Dangerous patterns pass validation and get cached

PatternCompiler.validatePattern() checks syntax but not complexity. Patterns like `(a+)+` compile successfully and pass validation but can cause catastrophic backtracking.

**Recommended fix**: Add nested quantifier detection regex and warn/block on match.

### S3. Silent exception fallback in regex matching (MEDIUM)

**Severity**: Medium
**Files**: safe_sender_list.dart:88-96, rule_quick_add_screen.dart:119-132, rule_quick_add_screen.dart:143-157
**Impact**: Invalid patterns silently fall back to exact string match, hiding errors

Multiple places catch regex compilation exceptions and silently fall back to literal string matching. This hides broken patterns from users and could lead to unexpected rule behavior.

**Recommended fix**: Log warnings on invalid patterns. Consider returning false instead of falling back to literal match.

---

## Category 3: Credential and Data Storage

### S4. Firebase API key committed to git history (CRITICAL)

**Severity**: Critical
**File**: mobile-app/android/app/google-services.json
**Impact**: API key publicly accessible in git history

The Firebase API key `AIzaSyB3x...` and Android certificate hash are in the git history. While .gitignore now excludes the file, the key remains in previous commits.

**Recommended fix**:
- Restrict API key in Google Cloud Console (Android package name + cert hash only)
- Regenerate key if repository is public
- Consider using BFG Repo-Cleaner if needed (note: repo rewrite is disruptive)

### S5. Hardcoded Android OAuth client ID in source (HIGH)

**Severity**: High
**File**: gmail_windows_oauth_handler.dart:35
**Impact**: Client ID extractable via reverse engineering

`_androidClientId` is hardcoded as a constant string. While OAuth client IDs are not secrets (they are public identifiers), hardcoding them makes rotation difficult.

**Recommended fix**: Move to build-time injection via `--dart-define` or `google-services.json`.

### S6. IMAP password partially logged (HIGH)

**Severity**: High
**File**: generic_imap_adapter.dart:164-168
**Impact**: Password information visible in logs

Password is "masked" by replacing with asterisks but still logged with length information. Email address logged in plaintext. Debug logs are accessible via logcat on Android.

**Recommended fix**: Remove password logging entirely. Use `Redact.logSafe()` from existing util/redact.dart for any auth-related logging.

### S7. SQLite database not encrypted (MEDIUM)

**Severity**: Medium
**Files**: database_helper.dart, all store classes
**Impact**: Email addresses, subjects, scan results readable on rooted/compromised devices

The SQLite database stores email addresses, message subjects, body previews, and account metadata in plaintext. On rooted Android devices or if Windows file system is compromised, this data is directly readable.

Credentials (passwords, OAuth tokens) are properly stored in flutter_secure_storage (encrypted), so the highest-value secrets are protected.

**Recommended fix**: Consider SQLCipher for database encryption. Alternatively, encrypt sensitive fields (email, subject, body_preview) before storage. Prioritize based on threat model -- local app on user's own device has lower risk than shared/enterprise devices.

### S8. Email body previews stored indefinitely (MEDIUM)

**Severity**: Medium
**File**: database_helper.dart (unmatched_emails table)
**Impact**: Sensitive email content cached locally without retention limits

Email body previews in the unmatched_emails table can accumulate indefinitely. May contain sensitive content (medical, financial, personal).

**Recommended fix**: Implement automatic cleanup of unmatched_emails older than configurable retention period. Limit body_preview to first 100 characters.

### S9. No credential cleanup from memory after use (LOW)

**Severity**: Low
**Files**: generic_imap_adapter.dart, secure_credentials_store.dart
**Impact**: Credentials may remain in Dart string objects in memory

Dart strings are immutable -- they cannot be zeroed out after use. IMAP adapter retains `_credentials` field in memory. This is a language limitation, not a code defect.

**Recommended fix**: Document as known limitation. Clear credential references when no longer needed (set to null). No perfect solution exists in Dart.

---

## Category 4: OWASP Mobile Top 10

### S10. Android: Missing allowBackup="false" (CRITICAL)

**Severity**: Critical
**File**: mobile-app/android/app/src/main/AndroidManifest.xml
**Impact**: App data (including database) can be backed up via adb, potentially exposing sensitive data

Without `android:allowBackup="false"`, the entire app data directory can be extracted via `adb backup`.

**Recommended fix**: Add `android:allowBackup="false"` to `<application>` tag.

### S11. Android: Missing network_security_config.xml (HIGH)

**Severity**: High
**File**: Missing -- mobile-app/android/app/src/main/res/xml/
**Impact**: Cleartext HTTP traffic may be allowed on older Android versions

Without a network security config, Android SDK < 28 allows cleartext traffic by default. This app should enforce HTTPS for all connections.

**Recommended fix**: Create network_security_config.xml that blocks cleartext traffic and reference it in AndroidManifest.xml.

### S12. Android: Release build uses debug signing (HIGH)

**Severity**: High
**File**: mobile-app/android/app/build.gradle.kts (lines 39-44)
**Impact**: Production APK signed with debug key

Release build type uses `signingConfigs.getByName("debug")`. Production APKs should use a dedicated release keystore.

**Recommended fix**: Create release signing configuration with secure keystore. Store keystore password in secrets management (not in code).

### S13. Android: No R8/ProGuard obfuscation (HIGH)

**Severity**: High
**File**: mobile-app/android/app/build.gradle.kts
**Impact**: APK can be trivially decompiled to extract logic, API keys, OAuth flow

No minification or obfuscation configured for release builds.

**Recommended fix**: Enable R8 minification with `minifyEnabled = true` and add proguard-rules.pro. Also use Dart obfuscation: `flutter build apk --obfuscate --split-debug-info=...`

### S14. No certificate pinning for critical endpoints (HIGH)

**Severity**: High
**Files**: generic_imap_adapter.dart:145-162, gmail_windows_oauth_handler.dart
**Impact**: MITM attacks possible with compromised CA

Standard TLS validation only. No certificate pinning for Google OAuth endpoints, Gmail API, or IMAP servers. Comments acknowledge the gap but no implementation exists.

**Recommended fix**: Implement certificate pinning for `accounts.google.com`, `oauth2.googleapis.com`, `imap.gmail.com`, `imap.aol.com`. Use `SecurityContext` with pinned certificates.

### S15. OAuth token not explicitly revoked on logout (MEDIUM)

**Severity**: Medium
**File**: google_auth_service.dart (lines 494-501)
**Impact**: Tokens may remain valid on Google's servers after user signs out

Current signOut deletes local tokens but does not call Google's token revocation endpoint.

**Recommended fix**: Call `https://oauth2.googleapis.com/revoke?token=<access_token>` during signOut.

### S16. Placeholder OAuth client ID falls through to runtime (MEDIUM)

**Severity**: Medium
**File**: gmail_windows_oauth_handler.dart:21-24
**Impact**: Confusing errors if secrets not injected at build time

Default value is `'YOUR_CLIENT_ID.apps.googleusercontent.com'` which looks valid but is not. OAuth will fail with unclear error messages.

**Recommended fix**: Use empty string as default, fail-fast with clear error message if client ID is empty.

### S17. No rate limiting on authentication attempts (LOW)

**Severity**: Low
**Files**: google_auth_service.dart, generic_imap_adapter.dart
**Impact**: Brute force attacks possible on IMAP app passwords

No exponential backoff or account lockout after failed authentication attempts.

**Recommended fix**: Implement exponential backoff after 3+ failed login attempts per account.

---

## Category 5: Input Validation

### S18. YAML import: no file size limit (MEDIUM)

**Severity**: Medium
**File**: yaml_service.dart:14-16, 37, 44
**Impact**: Importing a very large YAML file could cause memory exhaustion

No file size check before reading YAML content. Dart's yaml package is safer than Python's (no arbitrary object instantiation) but deeply nested YAML could still cause issues.

**Recommended fix**: Add file size limit (e.g., 10 MB) before parsing. Validate YAML structure after parsing.

### S19. No IMAP host validation for custom servers (MEDIUM)

**Severity**: Medium
**File**: generic_imap_adapter.dart:55-128
**Impact**: SSRF potential if custom IMAP UI is added in the future

`GenericIMAPAdapter.custom()` accepts any hostname without validation. Currently not exposed in UI (only hardcoded hosts used), but F37 (folder selectors) or future custom IMAP provider UI would expose this.

**Recommended fix**: Add host validation to reject internal/private IP ranges (127.x, 10.x, 192.168.x, 172.16-31.x) when custom IMAP is implemented.

### S20. Email address format not validated on input (LOW)

**Severity**: Low
**File**: account_setup_screen.dart:538-546
**Impact**: Invalid email addresses accepted (server will reject)

TextField uses `TextInputType.emailAddress` (keyboard hint only) with no format validation. Low risk since IMAP server will reject invalid emails, but poor UX.

**Recommended fix**: Add basic email regex validation before attempting connection.

### S21. Password field has no minimum length check (LOW)

**Severity**: Low
**File**: account_setup_screen.dart:550-558
**Impact**: Empty or very short passwords accepted (server will reject)

**Recommended fix**: Add minimum length check (app passwords are typically 16 characters).

---

## Category 6: Platform-Specific

### S22. Windows: MSIX uses runFullTrust capability (MEDIUM)

**Severity**: Medium
**File**: mobile-app/windows/Package.appxmanifest:39
**Impact**: Grants unrestricted system access, bypasses Windows sandbox

The `runFullTrust` capability is required for Flutter desktop apps that use FFI (SQLite, system_tray, etc.). This is a Flutter platform limitation, not a code defect. The Microsoft Store accepted this configuration.

**Recommended fix**: Document as known limitation. Monitor Flutter progress on reduced-capability desktop apps. No action needed for current Store submission.

### S23. Windows: No binary hardening flags (LOW)

**Severity**: Low
**File**: mobile-app/windows/CMakeLists.txt
**Impact**: Missing DEP/NX, ASLR, stack canaries in build config

**Recommended fix**: Add `/GS /DYNAMICBASE /NXCOMPAT` compiler flags. Low priority -- Flutter's build system may already enable some of these.

### S24. WebView JavaScript unrestricted (LOW)

**Severity**: Low
**File**: mobile-app/lib/screens/gmail_webview_oauth_screen.dart:45-49
**Impact**: JavaScript enabled in OAuth WebView

`JavaScriptMode.unrestricted` is enabled for the OAuth fallback WebView. Required for Google OAuth to function. Only loads Google's HTTPS pages.

**Recommended fix**: No change needed for OAuth WebView. Ensure any future WebView usage validates content source.

---

## Category 7: Supply Chain

### S25. No automated dependency vulnerability scanning (MEDIUM)

**Severity**: Medium
**Impact**: CVEs in dependencies may go unnoticed

No `dart pub audit`, GitHub Dependabot, or similar scanning configured.

**Recommended fix**: Add `dart pub outdated` to sprint pre-kickoff checklist. Consider enabling GitHub Dependabot alerts.

### S26. Firebase Analytics dependency present but unused (LOW)

**Severity**: Low
**File**: pubspec.yaml
**Impact**: Unnecessary dependency surface area

Firebase packages included but analytics not initialized (per ADR-0033). Adds unnecessary transitive dependencies.

**Recommended fix**: Remove Firebase Analytics dependency entirely (already tracked as GP-12).

---

## Category 8: Logging and Privacy

### S27. Debug logging includes email addresses in IMAP adapter (MEDIUM)

**Severity**: Medium
**File**: generic_imap_adapter.dart:168
**Impact**: Email addresses visible in logs

IMAP login logging includes plaintext email address. Accessible via logcat on Android or console on Windows.

**Recommended fix**: Use `Redact.logSafe()` for email addresses in all auth-related logging.

### S28. Log level control is build-mode only (MEDIUM)

**Severity**: Medium
**File**: util/redact.dart:34-35
**Impact**: Release builds still log at WARNING level

`kDebugMode` controls log level but release builds still emit warnings. No runtime disable for sensitive operations.

**Recommended fix**: Add feature flag or configuration for auth logging. Consider stripping sensitive logs from release builds.

---

## Backlog Items Generated

### Security Backlog (Prioritized)

| ID | Severity | Description | Effort | Dependencies |
|----|----------|-------------|--------|--------------|
| SEC-1 | Critical | ReDoS protection: timeout + pattern validation for regex evaluation | ~4-6h | None |
| SEC-2 | Critical | Android: Add allowBackup="false" to manifest | ~15min | None |
| SEC-3 | Critical | Firebase API key: restrict in Google Cloud Console | ~30min | None |
| SEC-4 | High | Android: Create network_security_config.xml | ~1h | None |
| SEC-5 | High | Remove password logging from IMAP adapter | ~30min | None |
| SEC-6 | High | Android: Configure release signing (not debug key) | ~2h | GP-2 (release signing) |
| SEC-7 | High | Android: Enable R8 obfuscation + Dart obfuscation | ~2h | GP-9 (ProGuard) |
| SEC-8 | High | Certificate pinning for OAuth and IMAP endpoints | ~4-6h | None |
| SEC-9 | High | Move hardcoded Android client ID to build-time injection | ~1h | None |
| SEC-10 | Medium | YAML import: add file size limit | ~30min | None |
| SEC-11 | Medium | SQLite database encryption (SQLCipher) | ~4-8h | None |
| SEC-12 | Medium | OAuth token revocation on logout | ~1h | None |
| SEC-13 | Medium | Placeholder OAuth client ID: fail-fast on empty | ~30min | None |
| SEC-14 | Medium | Unmatched emails: retention limit and body preview truncation | ~2h | None |
| SEC-15 | Medium | IMAP host validation for custom servers (SSRF prevention) | ~1h | F37 |
| SEC-16 | Medium | Enable GitHub Dependabot or dart pub audit in process | ~1h | None |
| SEC-17 | Medium | Log redaction: use Redact.logSafe() for all auth logging | ~1-2h | None |
| SEC-18 | Medium | Silent regex fallback: log warnings instead of silent literal match | ~1h | None |
| SEC-19 | Medium | Log level control: add runtime disable for sensitive operations | ~1-2h | None |
| SEC-20 | Low | Email format validation on account setup input | ~30min | None |
| SEC-21 | Low | Password minimum length check on account setup | ~15min | None |
| SEC-22 | Low | Rate limiting on failed auth attempts | ~2h | None |
| SEC-23 | Low | Windows binary hardening flags (CMakeLists.txt) | ~30min | None |
| SEC-24 | Low | Document Dart string immutability credential limitation | ~15min | F61 |
| SEC-25 | Low | Remove Firebase Analytics dependency | ~30min | GP-12 |

### Overlap with Existing Backlog

| SEC Item | Existing Item | Relationship |
|----------|---------------|--------------|
| SEC-6 | GP-2 (Release signing) | Same work, SEC-6 is security framing |
| SEC-7 | GP-9 (ProGuard/R8) | Same work, SEC-7 is security framing |
| SEC-15 | F37 (Folder selectors) | SEC-15 needed when F37 adds custom IMAP |
| SEC-24 | F61 (Architecture doc refresh) | Can include in F61 scope |
| SEC-25 | GP-12 (Firebase Analytics decision) | Same work |

---

## Architecture Health Score (Security)

| Dimension | Score | Notes |
|-----------|-------|-------|
| SQL injection protection | 10/10 | All 92+ operations properly parameterized |
| Credential storage | 9/10 | flutter_secure_storage used correctly; -1 for password logging |
| Input validation | 6/10 | Regex ReDoS risk, no YAML limits, minimal form validation |
| Network security | 6/10 | TLS used but no pinning, missing Android network config |
| Platform configuration | 5/10 | Missing allowBackup, debug signing, no obfuscation |
| Supply chain | 7/10 | Verified sources, but no automated scanning |
| Privacy and logging | 7/10 | Redact utility exists but not consistently used |

**Overall Security Posture**: 7/10 -- Solid foundation with specific gaps to address
