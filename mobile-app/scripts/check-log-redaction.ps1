# F102 (Sprint 43) -- Logging redaction enforcement gate.
#
# Fails (exit 1) when a log call in lib/ interpolates a raw PII identifier
# (account id, email address, token) WITHOUT a Redact.* wrapper. This codifies
# the ADR-0030 "Logging & Redaction" invariant as an automated check so new
# leaks are caught at author/CI time -- not at code review (Sprint 42 F98
# introduced ~19 such leaks that only Copilot caught on PR #263).
#
# Scope: lib/**/*.dart. Log sinks matched: `_logger.i/d/w/e(...)`,
# `Logger().i/d/w/e(...)`, and the headless file logs `_bgLog(...)` / `bgLog(...)`.
#
# A line is a VIOLATION when it is a log call that contains a raw PII variable
# interpolation and does NOT contain `Redact.` (the redaction is applied inline,
# so a redacted line always mentions Redact).
#
# PII variable patterns (the email-address / account-id / token family):
#   $email, $emailAddress, $fromEmail, $senderEmail, $userEmail, $toEmail
#   $accountId, $bgAccountId, $_backgroundAccountId, $account  (bare account id)
#   $token, $accessToken, $refreshToken, $appPassword, $clientSecret
# Deliberately EXCLUDED (not PII -- counts / row ids):
#   $emailId, $emailIds, $emails, $emailCount, $accountIds (list), $accountCount
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

# Raw PII identifier interpolations. \b-anchored and with negative lookahead so
# $emailId / $emails / $accountIds / $accountCount do NOT match.
$piiRe = '\$\{?(email(?!Id|Ids|Count|s\b)|emailAddress|fromEmail|senderEmail|userEmail|toEmail|accountId(?!s)|bgAccountId|_backgroundAccountId|account(?!Id|Ids|Count|s\b)|accessToken|refreshToken|token|appPassword|clientSecret)\b'

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
        @{ line = '_logger.d(x $emailAddress y)';                  expect = $true  ; name = 'raw email in logger' },
        @{ line = '_logger.i(for account $accountId)';             expect = $true  ; name = 'raw accountId in logger' },
        @{ line = 'await _bgLog(account $accountId missing)';      expect = $true  ; name = 'raw accountId in bgLog' },
        @{ line = '_logger.d(x ${Redact.email(emailAddress)} y)'; expect = $false ; name = 'redacted email ok' },
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
