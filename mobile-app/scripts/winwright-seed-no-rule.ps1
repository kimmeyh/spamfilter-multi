# F182 (Sprint 63) -- deterministic seeding for the WinWright no-rule sweep.
#
# test_mt2c_no_rule_sweep.json asserts that NAMED rows survive the Review No
# Rule Items screen's covered-item sweep. Its baselines were Harold's LIVE
# scanned senders, which rotted every time Manual Validation rule work
# addressed them (refreshed Sprints 59, 60, and 62). This script makes the
# baselines synthetic constants:
#
#   seed-a@winwright-seed-a.invalid   (attached to the FIRST  account)
#   seed-b@winwright-seed-b.invalid   (attached to the SECOND account, or the
#                                      first again if only one exists)
#
# `.invalid` is RFC 2606-reserved: no live mail, rule, or safe sender can ever
# legitimately match it, so the covered-item sweep can never collect the rows
# and no real correspondent address is committed to the repo.
#
# One row is seeded per account (two accounts expected in the dev DB) so the
# F169 account-filter dropdown is guaranteed a menu entry for BOTH accounts --
# the other data-dependence mt2c used to carry.
#
# Marker discipline: every seeded row is identified EXACTLY -- scan_results
# rows carry folders_scanned = '["WINWRIGHT-SEED"]' and unmatched_emails rows
# carry the reserved domains. Unseed deletes ONLY by these markers.
#
# DRIFT-GUARD INTERACTION (R-3, verified at authoring): the DB-snapshot guard
# tracks rules / safe_senders / app_settings ONLY (winwright-db-snapshot.ps1
# $SnapshotTables). This script writes scan_results + unmatched_emails, so the
# guard is structurally unaffected -- but unseed still restores the tables it
# touches to their pre-seed state (Sprint 37 restore-what-you-modify policy).
#
# Usage:
#   .\winwright-seed-no-rule.ps1 seed     # insert the synthetic rows
#   .\winwright-seed-no-rule.ps1 unseed   # remove them (idempotent)
#   .\winwright-seed-no-rule.ps1 status   # count currently-seeded rows

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("seed", "unseed", "status")]
    [string]$Action
)

$ErrorActionPreference = "Stop"

$DbPath = Join-Path $env:APPDATA "MyEmailSpamFilter\MyEmailSpamFilter_Dev\spam_filter.db"

# sqlite3.exe location -- same resolution as winwright-db-snapshot.ps1.
$_sqlite3InPath = Get-Command "sqlite3" -ErrorAction SilentlyContinue
$_sqlite3Candidates = @(
    $(if ($null -ne $_sqlite3InPath) { $_sqlite3InPath.Source } else { $null }),
    "C:\Android\android-sdk\platform-tools\sqlite3.exe"
)
$Sqlite3 = $null
foreach ($candidate in $_sqlite3Candidates) {
    if ($null -ne $candidate -and (Test-Path $candidate)) { $Sqlite3 = $candidate; break }
}
if ($null -eq $Sqlite3) {
    throw "[WW-SEED] sqlite3.exe not found (PATH or C:\Android\android-sdk\platform-tools)."
}
if (-not (Test-Path $DbPath)) {
    throw "[WW-SEED] Dev DB not found at $DbPath"
}

# ASCII-only temp SQL file (the snapshot script's BOM lesson: piping a BOM
# into sqlite3 breaks the first statement).
function Invoke-Sql([string]$Sql) {
    $tmp = Join-Path $env:TEMP ("ww_seed_" + [guid]::NewGuid().ToString("N") + ".sql")
    [System.IO.File]::WriteAllText($tmp, $Sql, [System.Text.UTF8Encoding]::new($false))
    try {
        # Quote the path for the dot-command: an unquoted temp path with a
        # space would be parsed as multiple arguments (Copilot review, PR #366).
        $out = & $Sqlite3 $DbPath ".read `"$($tmp -replace '\\', '/')`"" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "[WW-SEED] sqlite3 failed: $out" }
        return $out
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

$MarkerFolders = '["WINWRIGHT-SEED"]'
$DomainA = "winwright-seed-a.invalid"
$DomainB = "winwright-seed-b.invalid"

switch ($Action) {
    "status" {
        $count = Invoke-Sql "SELECT COUNT(*) FROM unmatched_emails WHERE from_email LIKE '%.invalid';"
        Write-Host "[WW-SEED] Seeded unmatched rows present: $count"
        exit 0
    }
    "unseed" {
        Invoke-Sql @"
DELETE FROM unmatched_emails WHERE from_email LIKE '%@$DomainA' OR from_email LIKE '%@$DomainB';
DELETE FROM scan_results WHERE folders_scanned = '$MarkerFolders';
"@ | Out-Null
        Write-Host "[WW-SEED] Unseeded (markers removed)." -ForegroundColor Green
        exit 0
    }
    "seed" {
        # Idempotent: clear any leftovers from a crashed prior run first.
        Invoke-Sql @"
DELETE FROM unmatched_emails WHERE from_email LIKE '%@$DomainA' OR from_email LIKE '%@$DomainB';
DELETE FROM scan_results WHERE folders_scanned = '$MarkerFolders';
"@ | Out-Null

        $accounts = @(Invoke-Sql "SELECT account_id FROM accounts ORDER BY date_added LIMIT 2;")
        if ($accounts.Count -eq 0) {
            throw "[WW-SEED] No accounts in the dev DB -- cannot attach seed rows."
        }
        $acctA = $accounts[0]
        $acctB = if ($accounts.Count -gt 1) { $accounts[1] } else { $accounts[0] }
        if ($accounts.Count -lt 2) {
            Write-Warning "[WW-SEED] Only one account present -- both rows attach to it (the mt2c @gmail menu step may fail)."
        }

        $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        foreach ($pair in @(@($acctA, $DomainA, "a"), @($acctB, $DomainB, "b"))) {
            $acct = $pair[0]; $domain = $pair[1]; $tag = $pair[2]
            Invoke-Sql @"
INSERT INTO scan_results (account_id, scan_type, scan_mode, started_at, completed_at, total_emails,
  processed_count, deleted_count, moved_count, safe_sender_count, no_rule_count, error_count,
  status, folders_scanned)
VALUES ('$acct', 'manual', 'readOnly', $now, $now, 1, 1, 0, 0, 0, 1, 0, 'completed', '$MarkerFolders');
INSERT INTO unmatched_emails (scan_result_id, provider_identifier_type, provider_identifier_value,
  from_email, from_name, subject, body_preview, folder_name, email_date, processed, created_at)
VALUES (last_insert_rowid(), 'uid', 'ww-seed-$tag',
  'seed-$tag@$domain', 'WinWright Seed $tag', 'WinWright synthetic baseline $tag',
  'synthetic', 'INBOX', $now, 0, $now);
"@ | Out-Null
        }
        Write-Host "[WW-SEED] Seeded 2 synthetic no-rule rows ($DomainA -> $acctA; $DomainB -> $acctB)." -ForegroundColor Green
        exit 0
    }
}
