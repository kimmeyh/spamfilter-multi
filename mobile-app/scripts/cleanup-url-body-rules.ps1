# cleanup-url-body-rules.ps1 -- F187 (Sprint 64, Issue #370)
#
# Removes Harold's F33-era URL-shape body rules: rules whose ONLY condition is a
# single body pattern of the shape (?:://|[/.])domain\.tld (the link-domain
# blocks). Phrase/phone/address body rules are NOT touched.
#
# Approved by Harold 2026-08-28 ("D2 approved") after dry-run presentation:
# 647 of 732 body rules matched on the dev snapshot; all 647 verified to carry
# exactly one body pattern and zero other conditions.
#
# Modes:
#   -Mode SelfTest          fixture check of the shape classifier (no DB)
#   -Mode DryRun -DbPath X  enumerate + count, NO changes (default mode)
#   -Mode Apply  -DbPath X  timestamped backup, delete, untruncated verify
#
# Discipline (F33/F144 pattern): backup BEFORE delete; post-delete verification
# uses full counts (never truncated); rollback = restore the backup file.

param(
    [ValidateSet("SelfTest", "DryRun", "Apply")]
    [string]$Mode = "DryRun",
    [string]$DbPath = ""
)

$ErrorActionPreference = "Stop"

# The classifier: the whole condition_body JSON is exactly one pattern that
# begins with the literal URL-shape prefix. SQL LIKE is used for enumeration;
# the JSON single-element constraint is enforced by json_array_length.
$PrefixLike = '["(?:://|[/.])%'
$Where = "condition_body LIKE '$($PrefixLike -replace "'", "''")%' AND json_array_length(condition_body) = 1 " +
         "AND (condition_from IS NULL OR condition_from = '[]' OR condition_from = '') " +
         "AND (condition_header IS NULL OR condition_header = '[]' OR condition_header = '') " +
         "AND (condition_subject IS NULL OR condition_subject = '[]' OR condition_subject = '')"

function Get-Sqlite {
    $candidates = @("sqlite3", "C:\Android\android-sdk\platform-tools\sqlite3.exe")
    foreach ($c in $candidates) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { return $c }
    }
    throw "[F187] sqlite3.exe not found."
}

if ($Mode -eq "SelfTest") {
    # Fixture check (T-1 intent): URL-shape IN, phrase/phone/address OUT.
    $inFixtures = @(
        '["(?:://|[/.])emailreunion\\.com"]',
        '["(?:://|[/.])50\\.193\\.138\\.95"]',
        '["(?:://|[/.])beautytoto\\.site"]'
    )
    $outFixtures = @(
        '["1501\\ yamato\\ road"]',
        '["\\(?800\\)?[-. ]?571[-. ]?7438"]',
        '["a\\ date\\ with"]',
        '["united\\ nations\\ compensation\\ commission"]',
        '["(?:://|[/.])a\\.com","second-pattern"]'
    )
    $fail = 0
    foreach ($f in $inFixtures) {
        $isSingle = ($f -notmatch '","')
        if (-not ($f.StartsWith('["(?:://|[/.])') -and $isSingle)) { Write-Host "[FAIL] should match: $f"; $fail++ }
        else { Write-Host "[OK] matches (delete set): $f" }
    }
    foreach ($f in $outFixtures) {
        $isSingle = ($f -notmatch '","')
        if ($f.StartsWith('["(?:://|[/.])') -and $isSingle) { Write-Host "[FAIL] should NOT match: $f"; $fail++ }
        else { Write-Host "[OK] excluded (keep set): $f" }
    }
    if ($fail -gt 0) { throw "[F187] SelfTest FAILED ($fail)" }
    Write-Host "[F187] SelfTest PASS (3 in, 5 out)"
    exit 0
}

if (-not $DbPath -or -not (Test-Path $DbPath)) { throw "[F187] -DbPath required and must exist (got '$DbPath')" }
$sqlite = Get-Sqlite

$total    = & $sqlite $DbPath "SELECT COUNT(*) FROM rules WHERE condition_body IS NOT NULL AND condition_body != '[]' AND condition_body != '';"
$matched  = & $sqlite $DbPath "SELECT COUNT(*) FROM rules WHERE $Where;"
$keepers  = [int]$total - [int]$matched
Write-Host "[F187] DB: $DbPath"
Write-Host "[F187] Body rules total: $total | URL-shape (delete set): $matched | keep: $keepers"

if ($Mode -eq "DryRun") {
    Write-Host "[F187] DryRun -- no changes made. Samples:"
    & $sqlite $DbPath "SELECT '  ' || name FROM rules WHERE $Where LIMIT 10;"
    exit 0
}

# Apply
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = "$DbPath.f187_backup_$stamp"
Copy-Item $DbPath $backup -Force
if (Test-Path "$DbPath-wal") { Copy-Item "$DbPath-wal" "$backup-wal" -Force }
Write-Host "[F187] Backup: $backup (pre-delete body-rule count: $total, delete set: $matched)"

& $sqlite $DbPath "DELETE FROM rules WHERE $Where;"
if ($LASTEXITCODE -ne 0) { throw "[F187] DELETE failed -- DB untouched content is in the backup" }

$remainingMatched = & $sqlite $DbPath "SELECT COUNT(*) FROM rules WHERE $Where;"
$remainingBody    = & $sqlite $DbPath "SELECT COUNT(*) FROM rules WHERE condition_body IS NOT NULL AND condition_body != '[]' AND condition_body != '';"
Write-Host "[F187] Post-delete: shape-matched remaining: $remainingMatched (expect 0); body rules remaining: $remainingBody (expect $keepers)"
if ([int]$remainingMatched -ne 0 -or [int]$remainingBody -ne $keepers) {
    throw "[F187] VERIFICATION FAILED -- restore from $backup"
}
Write-Host "[F187] Apply COMPLETE and VERIFIED. Rollback: restore $backup"
