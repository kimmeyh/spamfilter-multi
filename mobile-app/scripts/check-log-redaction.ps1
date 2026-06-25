# F102 (Sprint 43) -- Logging redaction enforcement gate.
# F110 (Sprint 43) -- NARROWED: only the app user's OWN account address is PII.
#
# Fails (exit 1) when a log call in lib/ interpolates a raw SENSITIVE identifier
# (ACCOUNT ID, token, or secret) WITHOUT a Redact.* wrapper. This codifies the
# narrowed ADR-0030 "Logging & Redaction" invariant as an automated check so new
# leaks are caught at author/CI time -- not at code review.
#
# NARROWED RULE (F110, Harold 2026-06-25): the redaction invariant protects the
# APP USER'S OWN identity, NOT arbitrary correspondents. So:
#   - ACCOUNT IDs stay STRICT -- they embed the user's email; always redact
#     ($accountId, $bgAccountId, $_backgroundAccountId, bare $account).
#   - TOKENS / SECRETS stay STRICT ($token, $accessToken, $refreshToken,
#     $appPassword, $clientSecret).
#   - SENDER / recipient EMAIL ADDRESSES are now ALLOWED in the clear -- a
#     spammer's / phisher's address IS the security signal a reviewer needs.
#     The user's-OWN-address case (a self-spoof) is masked at the call site via
#     Redact.senderForLog(addr, userAccountEmails); logging a bare $fromEmail /
#     $senderEmail is NO LONGER a violation.
#
# Scope: lib/**/*.dart. Log sinks matched: `_logger.i/d/w/e(...)`,
# `Logger().i/d/w/e(...)`, and the headless file logs `_bgLog(...)` / `bgLog(...)`.
#
# A line is a VIOLATION when it is a log call that contains a raw SENSITIVE
# variable interpolation and does NOT contain `Redact.` (redaction is applied
# inline, so a redacted line always mentions Redact).
#
# SENSITIVE variable patterns (account-id / token / secret family):
#   $accountId, $bgAccountId, $_backgroundAccountId, $account  (bare account id)
#   $token, $accessToken, $refreshToken, $appPassword, $clientSecret
# Deliberately NOT flagged:
#   - email-address family ($email, $fromEmail, $senderEmail, $toEmail, ...) --
#     allowed in the clear per the F110 narrowing (use Redact.senderForLog for
#     the user's own address).
#   - counts / row ids ($emailId, $emails, $accountIds list, $accountCount).
#
# Usage:
#   .\check-log-redaction.ps1            # scan lib/, exit 1 on any violation
#   .\check-log-redaction.ps1 -SelfTest  # offline self-test (no repo scan)

param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

# A log-sink call on the line.
$logCallRe = '(_logger\.(i|d|w|e)|Logger\(\)\.(i|d|w|e)|_bgLog|[^A-Za-z]bgLog)\s*\('

# Raw SENSITIVE identifier interpolations (account id / token / secret only --
# F110 dropped the email-address family). \b-anchored with negative lookahead so
# $accountIds (list) / $accountCount do NOT match.
$piiRe = '\$\{?(accountId(?!s)|bgAccountId|_backgroundAccountId|account(?!Id|Ids|Count|s\b)|accessToken|refreshToken|token|appPassword|clientSecret)\b'

function Test-Line {
    param([string]$Line)
    if ($Line -notmatch $logCallRe) { return $false }       # not a log call
    if ($Line -match 'Redact\.')    { return $false }       # redaction applied inline
    if ($Line -match $piiRe)        { return $true }        # raw PII in a log call
    return $false
}

if ($SelfTest) {
    Write-Host "[SELF-TEST] check-log-redaction.ps1" -ForegroundColor Cyan
    $cases = @(
        @{ line = '_logger.i(for account $accountId)';             expect = $true  ; name = 'raw accountId in logger' },
        @{ line = 'await _bgLog(account $accountId missing)';      expect = $true  ; name = 'raw accountId in bgLog' },
        @{ line = '_logger.w(token=$accessToken)';                 expect = $true  ; name = 'raw token in logger' },
        @{ line = '_logger.d(x $emailAddress y)';                  expect = $false ; name = 'sender email now allowed (F110)' },
        @{ line = 'await _bgLog(Phishing: $fromEmail failed)';     expect = $false ; name = 'sender fromEmail now allowed (F110)' },
        @{ line = 'await _bgLog(${Redact.senderForLog(from, u)})'; expect = $false ; name = 'senderForLog ok' },
        @{ line = '_logger.i(${Redact.accountId(accountId)})';     expect = $false ; name = 'redacted accountId ok' },
        @{ line = '_logger.d(Deleted email $emailId)';            expect = $false ; name = 'emailId row id ok' },
        @{ line = '_logger.i(scans=$scans emails=$emails)';        expect = $false ; name = 'counts ok' },
        @{ line = 'final accountId = $accountId;';                 expect = $false ; name = 'not a log call ok' }
    )
    $pass = $true
    foreach ($c in $cases) {
        $got = Test-Line -Line $c.line
        $ok = ($got -eq $c.expect)
        if (-not $ok) { $pass = $false }
        Write-Host ("  [{0}] {1}" -f ($(if ($ok) {'PASS'} else {'FAIL'}), $c.name))
    }
    if ($pass) { Write-Host "[SELF-TEST] ALL PASSED" -ForegroundColor Green; exit 0 }
    else       { Write-Host "[SELF-TEST] FAILURES" -ForegroundColor Red;     exit 1 }
}

$libDir = Join-Path $PSScriptRoot "..\lib"
$violations = @()
Get-ChildItem -Path $libDir -Recurse -Filter '*.dart' | ForEach-Object {
    $file = $_.FullName
    $n = 0
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        $n++
        if (Test-Line -Line $line) {
            $violations += [PSCustomObject]@{ File = $file; Line = $n; Text = $line.Trim() }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "[FAIL] Logging-redaction violations (ADR-0030 'Logging & Redaction', F102):" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host ("  {0}:{1}" -f $v.File, $v.Line) -ForegroundColor Red
        Write-Host ("    {0}" -f $v.Text) -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Wrap the identifier with Redact.accountId()/Redact.email()/Redact.token() (mobile-app/lib/util/redact.dart)." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] No logging-redaction violations found." -ForegroundColor Green
exit 0
