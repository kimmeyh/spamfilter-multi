# WinWright dev-DB snapshot and drift-detection helper
# Sprint 40, F79 (Issue #240)
#
# Captures a point-in-time snapshot of the three mutable tables in the dev DB
# (rules, safe_senders, app_settings) and compares two snapshots for row drift.
# Row drift after a WinWright sweep means a test script leaked state into the DB
# and did not clean up after itself.
#
# Usage (called by run-winwright-tests.ps1 -- do not invoke directly):
#   . .\winwright-db-snapshot.ps1          # dot-source to load functions
#
#   $snap = Invoke-DbSnapshot              # take snapshot; returns snapshot object
#   $drift = Compare-DbSnapshots $before $after
#   if ($drift.HasDrift) { ... }
#
# Synthetic leak test (self-test mode):
#   .\winwright-db-snapshot.ps1 -SelfTest  # exits 0 if logic is correct, 1 if broken

param(
    [switch]$SelfTest
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$DevDbPath = Join-Path $env:APPDATA "MyEmailSpamFilter\MyEmailSpamFilter_Dev\spam_filter.db"

# sqlite3.exe location -- prefer PATH, fall back to Android SDK location
$Sqlite3Exe = $null
$_sqlite3InPath = Get-Command "sqlite3" -ErrorAction SilentlyContinue
$_sqlite3Candidates = @(
    $(if ($null -ne $_sqlite3InPath) { $_sqlite3InPath.Source } else { $null }),
    "C:\Android\android-sdk\platform-tools\sqlite3.exe"
)
foreach ($candidate in $_sqlite3Candidates) {
    if ($candidate -and (Test-Path $candidate)) {
        $Sqlite3Exe = $candidate
        break
    }
}

# Tables that must not drift between pre- and post-sweep snapshots
$SnapshotTables = @("rules", "safe_senders", "app_settings")

# ---------------------------------------------------------------------------
# Internal helper: copy DB to a temp file (handles file-lock gracefully)
# ---------------------------------------------------------------------------

function Copy-DbToTemp {
    param([string]$SourcePath)

    if (-not (Test-Path $SourcePath)) {
        throw "[DB-SNAPSHOT] Dev DB not found at '$SourcePath'. Is the dev app built? (build-windows.ps1)"
    }

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Copy-Item -Path $SourcePath -Destination $tempFile -Force -ErrorAction Stop
    } catch {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        throw "[DB-SNAPSHOT] Cannot copy dev DB -- file may be locked by a running app instance. " +
              "Close the app and retry, or ensure WAL mode allows concurrent reads. Error: $_"
    }
    return $tempFile
}

# ---------------------------------------------------------------------------
# Internal helper: dump one table's rows as an ordered array of strings
# Each string is a pipe-delimited row representation for stable comparison.
# ---------------------------------------------------------------------------

function Get-TableRows {
    param(
        [string]$DbFilePath,
        [string]$TableName
    )

    if ($null -eq $Sqlite3Exe) {
        throw "[DB-SNAPSHOT] sqlite3.exe not found. Expected at C:\Android\android-sdk\platform-tools\sqlite3.exe or in PATH."
    }

    # Use .mode list (pipe-delimited) for deterministic, whitespace-stable output.
    # ORDER BY rowid ensures consistent ordering across runs.
    $query = ".mode list`nSELECT * FROM `"$TableName`" ORDER BY rowid;"
    $rows = $query | & $Sqlite3Exe $DbFilePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Table may not exist (e.g., first run before migration) -- treat as empty
        Write-Host "[DB-SNAPSHOT] Warning: table '$TableName' returned non-zero from sqlite3 (may not exist yet). Treating as empty." -ForegroundColor Yellow
        return @()
    }
    # Filter out empty lines; return as string array
    return @($rows | Where-Object { $_ -ne "" })
}

# ---------------------------------------------------------------------------
# Public: Invoke-DbSnapshot
# Takes a snapshot of all three tracked tables. Returns a hashtable with
# keys: Timestamp, Tables (hashtable of table -> string[]), TempDbPath
# ---------------------------------------------------------------------------

function Invoke-DbSnapshot {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Write-Host "[DB-SNAPSHOT] Taking snapshot at $timestamp from '$DevDbPath'..." -ForegroundColor Cyan

    $tempDb = Copy-DbToTemp -SourcePath $DevDbPath

    $tableData = @{}
    foreach ($table in $SnapshotTables) {
        $rows = Get-TableRows -DbFilePath $tempDb -TableName $table
        $tableData[$table] = $rows
        Write-Host "[DB-SNAPSHOT]   $table : $($rows.Count) row(s)" -ForegroundColor DarkCyan
    }

    Remove-Item $tempDb -Force -ErrorAction SilentlyContinue

    return @{
        Timestamp  = $timestamp
        Tables     = $tableData
        DevDbPath  = $DevDbPath
    }
}

# ---------------------------------------------------------------------------
# Public: Compare-DbSnapshots
# Compares two snapshots. Returns a result object with:
#   HasDrift   : bool
#   DriftLines : string[]  (human-readable, one line per leaked/removed row)
# ---------------------------------------------------------------------------

function Compare-DbSnapshots {
    param(
        [hashtable]$Before,
        [hashtable]$After
    )

    $driftLines = @()

    foreach ($table in $SnapshotTables) {
        $beforeRows = $Before.Tables[$table]
        $afterRows  = $After.Tables[$table]

        # Rows added after the sweep (potential leaks)
        $added = @($afterRows | Where-Object { $_ -notin $beforeRows })
        foreach ($row in $added) {
            $driftLines += "[LEAK] table '$table' added row: $row"
        }

        # Rows removed after the sweep (test deleted something it should not have)
        $removed = @($beforeRows | Where-Object { $_ -notin $afterRows })
        foreach ($row in $removed) {
            $driftLines += "[LEAK] table '$table' removed row: $row"
        }
    }

    return @{
        HasDrift   = ($driftLines.Count -gt 0)
        DriftLines = $driftLines
    }
}

# ---------------------------------------------------------------------------
# Write-DriftReport -- print drift to console in a clear format
# ---------------------------------------------------------------------------

function Write-DriftReport {
    param([hashtable]$DriftResult)

    if (-not $DriftResult.HasDrift) {
        Write-Host "[DB-SNAPSHOT] No drift detected -- dev DB is clean after sweep." -ForegroundColor Green
        return
    }

    Write-Host "" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "[DB-SNAPSHOT] DRIFT DETECTED -- WinWright sweep leaked state into the dev DB!" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    foreach ($line in $DriftResult.DriftLines) {
        Write-Host $line -ForegroundColor Red
    }
    Write-Host "" -ForegroundColor Red
    Write-Host "Action required: identify which test script created/deleted the row(s) above" -ForegroundColor Red
    Write-Host "and add a cleanup step to restore dev DB state before the script exits." -ForegroundColor Red
    Write-Host "See 'State-restore rule' in docs/TESTING_STRATEGY.md." -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Self-test mode (-SelfTest)
# Injects a synthetic row into the 'rules' table of a throwaway in-memory
# DB (not the real dev DB), takes before/after snapshots, verifies that
# Compare-DbSnapshots correctly identifies the injected row as a leak,
# then verifies a clean pair returns HasDrift=false.
# Exits 0 on success, 1 on failure.
# ---------------------------------------------------------------------------

if ($SelfTest) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[SELF-TEST] winwright-db-snapshot.ps1 synthetic leak test" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    if ($null -eq $Sqlite3Exe) {
        Write-Host "[SELF-TEST] FAIL: sqlite3.exe not found." -ForegroundColor Red
        exit 1
    }

    Write-Host "[SELF-TEST] sqlite3 found at: $Sqlite3Exe" -ForegroundColor DarkCyan

    # Create a temp DB with the same schema structure as the real dev DB
    $tempTestDb = [System.IO.Path]::GetTempFileName()
    Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
    $tempTestDb = $tempTestDb + ".db"

    # Minimal schema for the three tracked tables (enough for row-dump testing)
    $createSchema = @"
CREATE TABLE IF NOT EXISTS rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    pattern TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    rule_type TEXT,
    created_at TEXT
);
CREATE TABLE IF NOT EXISTS safe_senders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern TEXT NOT NULL,
    created_at TEXT
);
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
INSERT INTO app_settings (key, value) VALUES ('scan_mode', 'read_only');
INSERT INTO app_settings (key, value) VALUES ('background_enabled', '0');
"@

    $createSchema | & $Sqlite3Exe $tempTestDb
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[SELF-TEST] FAIL: Could not create temp test DB." -ForegroundColor Red
        Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[SELF-TEST] Created temp DB at: $tempTestDb" -ForegroundColor DarkCyan

    # Override $DevDbPath to point at the temp DB for snapshot functions
    $savedDevDbPath = $DevDbPath
    $DevDbPath = $tempTestDb

    # --- STEP 1: Take pre-snapshot ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 1: Taking pre-snapshot (clean state)..." -ForegroundColor Yellow
    $snapshotBefore = Invoke-DbSnapshot

    Write-Host "[SELF-TEST] Pre-snapshot: rules=$($snapshotBefore.Tables['rules'].Count), safe_senders=$($snapshotBefore.Tables['safe_senders'].Count), app_settings=$($snapshotBefore.Tables['app_settings'].Count)"

    # --- STEP 2: Inject a synthetic leak row into 'rules' ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 2: Injecting synthetic leak row into 'rules' table..." -ForegroundColor Yellow

    $injectSql = "INSERT INTO rules (name, pattern, enabled, rule_type) VALUES ('.xyz-SYNTHETIC-LEAK', '\.xyz$', 1, 'tld');"
    $injectSql | & $Sqlite3Exe $tempTestDb
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[SELF-TEST] FAIL: Could not inject synthetic row." -ForegroundColor Red
        Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[SELF-TEST] Injected: name='.xyz-SYNTHETIC-LEAK', pattern='\.xyz$', enabled=1, rule_type='tld'" -ForegroundColor DarkCyan

    # --- STEP 3: Take post-snapshot ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 3: Taking post-snapshot (contains leak)..." -ForegroundColor Yellow
    $snapshotAfter = Invoke-DbSnapshot

    Write-Host "[SELF-TEST] Post-snapshot: rules=$($snapshotAfter.Tables['rules'].Count), safe_senders=$($snapshotAfter.Tables['safe_senders'].Count), app_settings=$($snapshotAfter.Tables['app_settings'].Count)"

    # --- STEP 4: Compare -- expect HasDrift=true ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 4: Comparing snapshots (expect: drift detected)..." -ForegroundColor Yellow
    $driftResult = Compare-DbSnapshots -Before $snapshotBefore -After $snapshotAfter
    Write-DriftReport -DriftResult $driftResult

    if (-not $driftResult.HasDrift) {
        Write-Host "[SELF-TEST] FAIL: Drift was NOT detected even though a synthetic row was injected. Snapshot logic is broken." -ForegroundColor Red
        Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
        exit 1
    }

    if (-not ($driftResult.DriftLines -match "\.xyz-SYNTHETIC-LEAK")) {
        Write-Host "[SELF-TEST] FAIL: Drift detected but injected row name '.xyz-SYNTHETIC-LEAK' not found in output." -ForegroundColor Red
        Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[SELF-TEST] Step 4: PASS -- drift correctly detected with injected row named in output." -ForegroundColor Green

    # --- STEP 5: Remove the synthetic row (simulate cleanup) ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 5: Removing synthetic row (simulate test cleanup)..." -ForegroundColor Yellow
    $deleteSql = "DELETE FROM rules WHERE name='.xyz-SYNTHETIC-LEAK';"
    $deleteSql | & $Sqlite3Exe $tempTestDb

    # --- STEP 6: Take another post-snapshot ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 6: Taking clean post-snapshot (after simulated cleanup)..." -ForegroundColor Yellow
    $snapshotClean = Invoke-DbSnapshot

    # --- STEP 7: Compare -- expect HasDrift=false ---
    Write-Host ""
    Write-Host "[SELF-TEST] Step 7: Comparing snapshots (expect: no drift)..." -ForegroundColor Yellow
    $cleanResult = Compare-DbSnapshots -Before $snapshotBefore -After $snapshotClean
    Write-DriftReport -DriftResult $cleanResult

    if ($cleanResult.HasDrift) {
        Write-Host "[SELF-TEST] FAIL: Drift was detected after cleanup -- snapshot comparison has a false-positive." -ForegroundColor Red
        Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[SELF-TEST] Step 7: PASS -- no drift detected after cleanup." -ForegroundColor Green

    # Restore $DevDbPath
    $DevDbPath = $savedDevDbPath

    # Clean up temp DB
    Remove-Item $tempTestDb -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "[SELF-TEST] ALL STEPS PASSED" -ForegroundColor Green
    Write-Host "  - Snapshot captures rows correctly" -ForegroundColor Green
    Write-Host "  - Compare-DbSnapshots detects injected leak (FAIL path works)" -ForegroundColor Green
    Write-Host "  - Injected row name '.xyz-SYNTHETIC-LEAK' appears in drift report" -ForegroundColor Green
    Write-Host "  - No false-positive after cleanup (clean path works)" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    exit 0
}
