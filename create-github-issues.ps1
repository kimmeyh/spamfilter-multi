# PowerShell script to create GitHub issues from code review
# Run this after restarting your terminal or adding gh to PATH
# Usage: .\create-github-issues.ps1

Write-Host "Creating 11 GitHub issues from code review..." -ForegroundColor Cyan
Write-Host ""

# Use full path to gh.exe
$gh = "C:\Program Files\GitHub CLI\gh.exe"

# Check if gh is available
if (-not (Test-Path $gh)) {
    Write-Host "✗ GitHub CLI not found at: $gh" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install GitHub CLI or update the path in this script" -ForegroundColor Yellow
    exit 1
}

try {
    $ghVersion = & $gh --version 2>&1
    Write-Host "✓ GitHub CLI found: $($ghVersion[0])" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to run GitHub CLI" -ForegroundColor Red
    exit 1
}

# Check authentication
Write-Host "Checking GitHub authentication..." -ForegroundColor Cyan
& $gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Please authenticate with GitHub first:" -ForegroundColor Yellow
    Write-Host "  & '$gh' auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Creating issues..." -ForegroundColor Cyan
Write-Host ""

# Issue #1: Header matching bug (CRITICAL)
Write-Host "[1/11] Creating Issue #1: Header matching bug..." -ForegroundColor Yellow
& $gh issue create `
    --title "🐛 [CRITICAL] Header matching bug in RuleEvaluator - rules with header conditions never match" `
    --label "bug,priority:critical,component:core,security" `
    --body @"
## Problem

The \`RuleEvaluator\` has a critical bug in both \`_matchesConditions()\` and \`_matchesExceptions()\` methods that prevents header-based spam filtering from working correctly.

**Root Cause:** The code checks \`message.from\` against header patterns instead of checking actual email headers from \`message.headers\`.

**Impact:**
- Rules targeting spam indicators in email headers (X-Spam-Status, Reply-To, Received, etc.) will **never match**
- Exception patterns for headers will also fail to match
- This severely limits the effectiveness of the spam filter for header-based detection

## Current Behavior

### In \`_matchesConditions()\` (lines 53-66):
\`\`\`dart
bool _matchesConditions(EmailMessage message, RuleConditions conditions) {
  final matches = <bool>[
    _matchesPatternList(message.from, conditions.from),
    _matchesPatternList(message.from, conditions.header),  // ❌ WRONG
    // ...
  ];
}
\`\`\`

## Acceptance Criteria

- [ ] \`_matchesHeaderList()\` helper method created
- [ ] \`_matchesConditions()\` updated to use \`_matchesHeaderList()\`
- [ ] \`_matchesExceptions()\` updated to use \`_matchesHeaderList()\`
- [ ] Unit tests added for header matching
- [ ] All existing tests pass (81/81)

## Files

- \`mobile-app/lib/core/services/rule_evaluator.dart\` (lines 53-73)

See \`GITHUB_ISSUES_BACKLOG.md\` for complete details and code examples.
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #1 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #1" -ForegroundColor Red
}

# Issue #2: Scan mode bypass (CRITICAL)
Write-Host "[2/11] Creating Issue #2: Scan mode bypass..." -ForegroundColor Yellow
gh issue create `
    --title "🚨 [CRITICAL] Scan mode bypass in EmailScanner - readonly mode still deletes emails" `
    --label "bug,priority:critical,component:scanner,data-loss-risk" `
    --body @"
## Problem

The \`EmailScanner.scanInbox()\` method directly executes delete/move actions without checking the scan mode from \`EmailScanProvider\`.

**Impact:**
- Users selecting "readonly" mode will still have emails **deleted/moved** ❌
- testLimit mode will not respect the email limit
- High risk of accidental data loss

## Current Behavior

\`\`\`dart
if (result.shouldDelete) {
  await platform.takeAction(  // ❌ No scan mode check!
    message: message,
    action: FilterAction.delete,
  );
}
\`\`\`

## Expected Behavior

Check \`EmailScanProvider.scanMode\` before executing actions:
- **readonly**: Never execute, only log
- **testLimit**: Execute until limit
- **testAll**: Execute all

## Acceptance Criteria

- [ ] Scan mode checked before all actions
- [ ] readonly mode: No emails deleted/moved
- [ ] testLimit mode: Respects limit
- [ ] Unit tests verify enforcement
- [ ] All existing tests pass (81/81)

## Files

- \`mobile-app/lib/core/services/email_scanner.dart\` (lines 66-125)

See \`GITHUB_ISSUES_BACKLOG.md\` for complete solution.
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #2 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #2" -ForegroundColor Red
}

# Issue #3: Credential confusion (CRITICAL)
Write-Host "[3/11] Creating Issue #3: Credential type confusion..." -ForegroundColor Yellow
gh issue create `
    --title "⚠️ [CRITICAL] Credential type confusion in SecureCredentialsStore" `
    --label "bug,priority:critical,component:auth,security" `
    --body @"
## Problem

\`SecureCredentialsStore.getCredentials()\` silently falls back to Gmail OAuth tokens when IMAP credentials don't exist, creating confusion between credential types.

**Impact:**
- OAuth tokens treated as IMAP passwords
- Authentication failures difficult to debug
- Violates single responsibility principle

## Proposed Solution

Remove silent fallback - callers must explicitly check both credential types.

## Acceptance Criteria

- [ ] Remove silent fallback to OAuth tokens
- [ ] Update all callers
- [ ] Unit tests verify no silent conversion
- [ ] All existing tests pass (81/81)

## Files

- \`mobile-app/lib/adapters/storage/secure_credentials_store.dart\` (lines 137-161)

See \`GITHUB_ISSUES_BACKLOG.md\` for detailed solutions.
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #3 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #3" -ForegroundColor Red
}

# Issue #4: Silent regex failures (CRITICAL)
Write-Host "[4/11] Creating Issue #4: Silent regex failures..." -ForegroundColor Yellow
gh issue create `
    --title "🤐 [CRITICAL] Silent regex compilation failures in PatternCompiler" `
    --label "bug,priority:critical,component:core,user-experience" `
    --body @"
## Problem

\`PatternCompiler.compile()\` silently caches "never matches" patterns when compilation fails. Users have no way to know their regex patterns are invalid.

**Impact:**
- Invalid patterns in rules.yaml silently fail
- Rules stop working with no notification
- Could allow spam through

## Proposed Solution

Add logging for all compilation failures:

\`\`\`dart
} catch (e) {
  _logger.e('Invalid regex pattern: "\$pattern" - Error: \$e');
  // ... cache fallback
}
\`\`\`

## Acceptance Criteria

- [ ] All regex failures logged
- [ ] Add compilationFailures getter
- [ ] Unit tests for invalid patterns
- [ ] Consider UI warning for invalid patterns

## Files

- \`mobile-app/lib/core/services/pattern_compiler.dart\` (lines 10-26)

See \`GITHUB_ISSUES_BACKLOG.md\` for complete solution.
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #4 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #4" -ForegroundColor Red
}

# Issue #5: Android refresh token (HIGH)
Write-Host "[5/11] Creating Issue #5: Android refresh token..." -ForegroundColor Yellow
gh issue create `
    --title "🔄 [HIGH] Missing refresh token storage on Android" `
    --label "bug,priority:high,component:auth,platform:android" `
    --body @"
## Problem

Android OAuth flow sets \`refreshToken\` to \`null\`, preventing HTTP-based token refresh fallback.

**Impact:**
- Android users may need to re-authenticate more frequently
- Inconsistent with Windows behavior

## Solution

Store refresh token even when using native SDK:

\`\`\`dart
final tokens = GmailTokens(
  accessToken: authentication.accessToken,
  refreshToken: authentication.idToken,  // ✅ Store for fallback
  // ...
);
\`\`\`

## Acceptance Criteria

- [ ] Refresh token stored on Android
- [ ] HTTP refresh works as fallback
- [ ] Manual test: Verify refresh after token expiry

## Files

- \`mobile-app/lib/adapters/auth/google_auth_service.dart\` (lines 422-428)
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #5 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #5" -ForegroundColor Red
}

# Issue #6: Exception mapping (HIGH)
Write-Host "[6/11] Creating Issue #6: Exception mapping..." -ForegroundColor Yellow
gh issue create `
    --title "🔍 [HIGH] Overly broad exception mapping in GenericIMAPAdapter" `
    --label "bug,priority:high,component:email-adapter,observability" `
    --body @"
## Problem

GenericIMAPAdapter converts all unknown errors to ConnectionException, hiding actual authentication errors.

**Impact:**
- Auth errors disguised as connection errors
- Misleading error messages
- Difficult to debug

## Solution

Rethrow unknown errors instead of converting:

\`\`\`dart
// ✅ Rethrow unknown errors
_logger.e('[IMAP] Unexpected error during connection', error: e);
rethrow;
\`\`\`

## Acceptance Criteria

- [ ] Remove fallback ConnectionException
- [ ] Rethrow unknown errors with logging
- [ ] Unit tests verify no silent conversion

## Files

- \`mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart\` (lines 146-165)
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #6 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #6" -ForegroundColor Red
}

# Issue #7: Duplicate scan mode logic (HIGH)
Write-Host "[7/11] Creating Issue #7: Duplicate scan mode logic..." -ForegroundColor Yellow
gh issue create `
    --title "♻️ [HIGH] Duplicate scan mode enforcement logic" `
    --label "technical-debt,priority:high,component:scanner,refactoring" `
    --body @"
## Problem

\`EmailScanProvider.recordResult()\` has logic to determine if actions should execute, but actions already executed by the time it's called.

**Impact:**
- Confusing code organization
- Unclear responsibility
- Risk of inconsistent behavior

## Solution

Move scan mode enforcement to EmailScanner (Issue #2). Simplify recordResult() to just record results.

**Depends on:** Issue #2

## Acceptance Criteria

- [ ] Remove shouldExecuteAction logic from recordResult()
- [ ] Simplify recordResult() to just record
- [ ] All enforcement in EmailScanner

## Files

- \`mobile-app/lib/core/providers/email_scan_provider.dart\` (lines 315-358)
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #7 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #7" -ForegroundColor Red
}

# Issue #8: Inconsistent logging (HIGH)
Write-Host "[8/11] Creating Issue #8: Inconsistent logging..." -ForegroundColor Yellow
gh issue create `
    --title "📝 [HIGH] Inconsistent logging - mix of print() and Logger" `
    --label "code-quality,priority:high,observability" `
    --body @"
## Problem

Codebase uses both \`print()\` (9 occurrences) and \`_logger\` (207 occurrences).

**Impact:**
- Cannot filter or disable print() logs
- Inconsistent log format
- Difficult to debug production issues

## Solution

Replace all \`print()\` with appropriate \`_logger\` calls:

\`\`\`dart
// Before
print('Migration error: \${e.toString()}');

// After
_logger.e('Migration error', error: e);
\`\`\`

## Acceptance Criteria

- [ ] All print() replaced with _logger
- [ ] grep -r "print(" lib/ returns 0 results
- [ ] All tests pass

## Files

- \`mobile-app/lib/main.dart\`
- \`mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart\`
- \`mobile-app/lib/core/services/email_scanner.dart\`
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #8 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #8" -ForegroundColor Red
}

# Issue #9: Cache management (MEDIUM)
Write-Host "[9/11] Creating Issue #9: Cache management..." -ForegroundColor Yellow
gh issue create `
    --title "💾 [MEDIUM] PatternCompiler cache grows unbounded" `
    --label "performance,priority:medium,memory" `
    --body @"
## Problem

PatternCompiler cache never clears, could accumulate stale patterns if rules frequently updated.

**Impact:**
- Low for typical usage (~50 patterns)
- Could grow if rules frequently modified

## Solutions

1. Clear cache when rules reload (simplest)
2. Implement LRU eviction with max size
3. Document manual clearing requirement

## Acceptance Criteria

- [ ] Choose and implement solution
- [ ] Document cache strategy
- [ ] Unit tests verify behavior

## Files

- \`mobile-app/lib/core/services/pattern_compiler.dart\`
- \`mobile-app/lib/core/providers/rule_set_provider.dart\` (if option 1)
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #9 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #9" -ForegroundColor Red
}

# Issue #10: Null safety (LOW)
Write-Host "[10/11] Creating Issue #10: Null safety..." -ForegroundColor Yellow
gh issue create `
    --title "🔢 [LOW] EmailMessage.getHeader() returns empty string instead of null" `
    --label "code-quality,priority:low,null-safety" `
    --body @"
## Problem

\`getHeader()\` signature says \`String?\` but returns empty string instead of null when header not found.

**Impact:**
- Cannot distinguish missing headers from empty headers
- Violates null safety conventions

## Solution

\`\`\`dart
String? getHeader(String key) {
  final entry = headers.entries.firstWhere(
    (e) => e.key.toLowerCase() == key.toLowerCase(),
    orElse: () => const MapEntry('', ''),
  );
  return entry.key.isEmpty ? null : entry.value;  // ✅ Return null
}
\`\`\`

## Acceptance Criteria

- [ ] Returns null when header missing
- [ ] Returns value (including empty) when exists
- [ ] Update callers to check null
- [ ] Unit tests added

## Files

- \`mobile-app/lib/core/models/email_message.dart\` (lines 26-35)
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #10 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #10" -ForegroundColor Red
}

# Issue #11: Missing tests (CRITICAL)
Write-Host "[11/11] Creating Issue #11: Missing RuleEvaluator tests..." -ForegroundColor Yellow
gh issue create `
    --title "🧪 [CRITICAL] Missing unit tests for RuleEvaluator" `
    --label "testing,priority:critical,component:core" `
    --body @"
## Problem

RuleEvaluator is **core spam detection** but has **no unit tests**. This allowed header matching bugs to reach production.

**Impact:**
- Core business logic not validated
- Bugs reach production undetected
- Difficult to refactor safely
- No regression protection

## Solution

Create comprehensive unit test suite:

\`\`\`dart
// test/unit/rule_evaluator_test.dart
void main() {
  group('RuleEvaluator', () {
    test('matches email when header pattern matches', () {
      // Would have caught Issue #1
    });
    // ... 20+ tests
  });
}
\`\`\`

## Acceptance Criteria

- [ ] Create test/unit/rule_evaluator_test.dart
- [ ] **Minimum 20 unit tests**
- [ ] Header matching tests specifically added
- [ ] Exception tests specifically added
- [ ] Code coverage >90%
- [ ] All tests pass

## Files

- Create: \`mobile-app/test/unit/rule_evaluator_test.dart\` (~300+ lines)

See \`GITHUB_ISSUES_BACKLOG.md\` for complete test scenarios.
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Issue #11 created" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Issue #11" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ All 11 issues created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "View issues: gh issue list" -ForegroundColor Yellow
Write-Host "Or visit: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/issues" -ForegroundColor Yellow
