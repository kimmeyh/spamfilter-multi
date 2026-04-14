# Sprint 32 Plan - Security Hardening: Quick Wins + Critical Fix

**Sprint**: 32
**Date**: April 13, 2026
**Branch**: `feature/20260413_Sprint_32`
**Type**: Security Hardening (code changes + process improvement)
**Estimated Effort**: ~10-14h

---

## Sprint Objective

Implement 10 security hardening items from the Sprint 31 security audit: 1 CRITICAL (ReDoS protection), 6 MEDIUM, and 3 LOW severity fixes. This sprint addresses all quick-win security items plus the critical ReDoS vulnerability that blocks future user-facing rule creation features (F56, F35).

---

## Sprint Scope

| # | Item | Severity | Effort | Model | Description |
|---|------|----------|--------|-------|-------------|
| 1 | SEC-1 | CRITICAL | ~4-6h | Opus | ReDoS protection: timeout + pattern validation |
| 2 | SEC-10 | MEDIUM | ~30min | Haiku | YAML import: add file size limit |
| 3 | SEC-12 | MEDIUM | ~1h | Sonnet | OAuth token revocation on logout |
| 4 | SEC-13 | MEDIUM | ~30min | Haiku | Placeholder OAuth client ID: fail-fast on empty |
| 5 | SEC-16 | MEDIUM | ~1h | Haiku | Enable dependency vulnerability scanning (process) |
| 6 | SEC-17 | MEDIUM | ~1-2h | Sonnet | Auth logging: use Redact.logSafe() consistently |
| 7 | SEC-18 | MEDIUM | ~1h | Haiku | Silent regex fallback: log warnings |
| 8 | SEC-20 | LOW | ~30min | Haiku | Email format validation on account setup |
| 9 | SEC-21 | LOW | ~15min | Haiku | Password minimum length check |
| 10 | SEC-23 | LOW | ~30min | Haiku | Windows binary hardening flags |

---

## Task Details and Acceptance Criteria

### Task 1: SEC-1 -- ReDoS Protection (CRITICAL)

**Model**: Opus
**Files**: `lib/core/services/pattern_compiler.dart`, new test file

**Current state**: PatternCompiler.validatePattern() has static warnings for common mistakes but no ReDoS detection or timeout protection. Malicious patterns with catastrophic backtracking could hang the app.

**Implementation**:
1. Add ReDoS pattern detection to PatternCompiler.validatePattern():
   - Detect nested quantifiers (e.g., `(a+)+`, `(a*)*`, `(a+)*`)
   - Detect overlapping alternation with quantifiers
   - Return validation error with user-friendly message
2. Add timeout-protected regex matching:
   - Wrap RegExp.hasMatch() / allMatches() calls with a timeout mechanism
   - Use Dart Isolate or Future.timeout for protection
   - Default timeout: 2 seconds per pattern match
3. Add tests for ReDoS detection and timeout behavior

**Acceptance criteria**:
- [ ] Nested quantifier patterns rejected by validatePattern() with clear error
- [ ] Regex execution protected by timeout (does not hang on slow patterns)
- [ ] Timeout configurable (default 2s)
- [ ] Existing valid patterns continue to work (no false positives)
- [ ] Tests cover: nested quantifier detection, timeout on slow pattern, normal patterns unaffected

---

### Task 2: SEC-10 -- YAML Import File Size Limit (MEDIUM)

**Model**: Haiku
**Files**: `lib/core/services/yaml_service.dart`

**Current state**: No file size check before YAML parsing. Large files could cause memory exhaustion.

**Implementation**:
- Add file size check (10 MB limit) before readAsString()
- Return descriptive error if file exceeds limit

**Acceptance criteria**:
- [ ] Files larger than 10 MB rejected with clear error message
- [ ] Normal YAML imports unaffected
- [ ] Test covers size limit enforcement

---

### Task 3: SEC-12 -- OAuth Token Revocation on Logout (MEDIUM)

**Model**: Sonnet
**Files**: `lib/adapters/auth/google_auth_service.dart`

**Current state**: Desktop/web platforms do not revoke tokens at the Google endpoint. Only native Google Sign-In has revocation via disconnect().

**Implementation**:
- Add HTTP POST to `https://oauth2.googleapis.com/revoke?token={token}` during signOut on desktop platforms
- Revoke refresh token if available, otherwise access token
- Handle revocation failure gracefully (log warning, continue signOut)

**Acceptance criteria**:
- [ ] Desktop OAuth signOut calls Google revoke endpoint
- [ ] Revocation failure does not block signOut flow
- [ ] Tokens still cleared from local storage regardless of revocation result
- [ ] Test covers revocation call and graceful failure handling

---

### Task 4: SEC-13 -- Fail-Fast on Empty OAuth Client ID (MEDIUM)

**Model**: Haiku
**Files**: `lib/adapters/email_providers/gmail_windows_oauth_handler.dart`

**Current state**: Windows client ID uses String.fromEnvironment() with a placeholder fallback. If secrets are not injected, OAuth silently uses a non-functional placeholder.

**Implementation**:
- Replace placeholder with empty string default
- Add guard check: if client ID is empty, throw descriptive error before attempting OAuth
- Error message should guide developer to configure secrets.dev.json

**Acceptance criteria**:
- [ ] Empty client ID throws clear error with setup instructions
- [ ] Non-empty client ID works as before
- [ ] Test covers fail-fast behavior

---

### Task 5: SEC-16 -- Dependency Vulnerability Scanning (MEDIUM)

**Model**: Haiku
**Files**: `docs/SPRINT_EXECUTION_WORKFLOW.md`, `docs/SPRINT_CHECKLIST.md`

**Current state**: No systematic dependency vulnerability checking in sprint workflow.

**Implementation**:
- Add `dart pub outdated` check to Phase 2 (Pre-Kickoff) in SPRINT_EXECUTION_WORKFLOW.md
- Add checklist item to SPRINT_CHECKLIST.md Phase 2
- Run `dart pub outdated` now and document current state
- Evaluate GitHub Dependabot setup (add .github/dependabot.yml if beneficial)

**Acceptance criteria**:
- [ ] `dart pub outdated` added to Phase 2 pre-kickoff checklist
- [ ] Current dependency status documented in sprint plan
- [ ] Dependabot evaluated (implement if low-effort, document decision if deferred)

---

### Task 6: SEC-17 -- Auth Logging Consistency (MEDIUM)

**Model**: Sonnet
**Files**: `lib/adapters/auth/google_auth_service.dart`, other auth-related files

**Current state**: Redact.logSafe() is used in most places but there may be minor gaps where email addresses or tokens are logged without redaction.

**Implementation**:
- Audit all auth-related logging across the codebase
- Replace any direct email/token logging with Redact.logSafe() or Redact.logError()
- Verify no sensitive data appears in non-debug log levels

**Acceptance criteria**:
- [ ] All auth-related files audited for logging
- [ ] No unredacted email addresses or tokens in log statements
- [ ] Redact.logSafe() used consistently for sensitive data
- [ ] Audit results documented (files checked, changes made)

---

### Task 7: SEC-18 -- Silent Regex Fallback Logging (MEDIUM)

**Model**: Haiku
**Files**: `lib/core/models/safe_sender_list.dart`, `lib/ui/screens/rule_quick_add_screen.dart`

**Current state**: Some catch blocks silently fall back to literal matching or default values without logging warnings.

**Implementation**:
- Add Logger.w() calls to silent catch blocks in safe_sender_list.dart and rule_quick_add_screen.dart
- Log the pattern that failed and the fallback behavior taken

**Acceptance criteria**:
- [ ] All silent regex catch blocks now log warnings
- [ ] Log messages include the failed pattern and fallback action
- [ ] No functional behavior changes (same fallback logic, just with logging)
- [ ] Tests verify no regressions

---

### Task 8: SEC-20 -- Email Format Validation (LOW)

**Model**: Haiku
**Files**: `lib/ui/screens/account_setup_screen.dart`

**Current state**: Account setup only checks for empty email/password. No format validation.

**Implementation**:
- Add basic email format validation (must contain @, valid domain structure)
- Show validation error before attempting IMAP connection
- Use simple regex: contains @, has text before and after @, domain has at least one dot

**Acceptance criteria**:
- [ ] Invalid email format rejected with clear error message
- [ ] Valid emails accepted (standard formats including + addressing)
- [ ] Validation runs before IMAP connection attempt
- [ ] Test covers valid and invalid email formats

---

### Task 9: SEC-21 -- Password Minimum Length Check (LOW)

**Model**: Haiku
**Files**: `lib/ui/screens/account_setup_screen.dart`

**Current state**: No password length validation. App passwords are typically 16 characters.

**Implementation**:
- Add minimum length warning (not hard block) for passwords shorter than 8 characters
- Show informational message: "App passwords are typically 16 characters. Short passwords may indicate an incorrect entry."
- Do not block login -- some providers may use shorter passwords

**Acceptance criteria**:
- [ ] Passwords shorter than 8 characters show a warning (not a hard block)
- [ ] Warning message is informational, not blocking
- [ ] Normal-length passwords show no warning
- [ ] Test covers warning display

---

### Task 10: SEC-23 -- Windows Binary Hardening Flags (LOW)

**Model**: Haiku
**Files**: `mobile-app/windows/runner/CMakeLists.txt`

**Current state**: Standard Flutter template with no security-specific compiler flags.

**Implementation**:
- Add MSVC security flags: /GS (buffer security), /DYNAMICBASE (ASLR), /NXCOMPAT (DEP)
- Add /guard:cf (Control Flow Guard) if supported
- Verify build still succeeds with flags

**Acceptance criteria**:
- [ ] Security flags added to CMakeLists.txt
- [ ] Windows build succeeds with flags
- [ ] No runtime regressions
- [ ] Flags documented in CMakeLists.txt with comments

---

## Architecture Impact Check (Phase 3.6.1)

- **SEC-1**: Adds timeout mechanism to PatternCompiler -- extends existing service, no new architectural components
- **SEC-12**: Adds HTTP call to google_auth_service.dart signOut -- extends existing auth adapter
- **All others**: Configuration changes, validation guards, or process updates -- no architecture impact
- **Architecture docs**: No updates needed

---

## Execution Order

1. SEC-23 (Windows binary hardening) -- build infrastructure first
2. SEC-10 (YAML file size limit) -- quick win
3. SEC-13 (fail-fast OAuth client ID) -- quick win
4. SEC-20 (email format validation) -- quick win
5. SEC-21 (password length check) -- quick win
6. SEC-18 (silent regex fallback logging) -- quick win
7. SEC-17 (auth logging consistency) -- audit + fixes
8. SEC-12 (OAuth token revocation) -- medium effort
9. SEC-1 (ReDoS protection) -- largest item, do last when all quick wins are banked
10. SEC-16 (dependency scanning) -- process update, can be done anytime

---

## Risk Assessment

- **SEC-1 (ReDoS)**: Highest risk -- timeout mechanism could affect legitimate long-running patterns. Mitigation: generous default timeout (2s), thorough testing with existing rule sets.
- **SEC-23 (hardening flags)**: Medium risk -- compiler flags could cause build failures. Mitigation: test build immediately after adding flags.
- **SEC-12 (token revocation)**: Low risk -- network failure during revocation must not break signOut. Mitigation: fire-and-forget with error logging.
- **All others**: Minimal risk -- validation guards and logging additions.
