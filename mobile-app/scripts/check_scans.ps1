$dbPath = "$env:APPDATA\com.example\spam_filter_mobile\spam_filter.db"
if (Test-Path $dbPath) {
    Write-Host "Database found: $dbPath"
    # Use sqlite3 to query scan_results
    $query = "SELECT id, account_id, scan_type, scan_mode, datetime(started_at/1000, 'unixepoch', 'localtime') as started, datetime(completed_at/1000, 'unixepoch', 'localtime') as completed, total_emails, processed_count, deleted_count, status, folders_scanned FROM scan_results ORDER BY started_at DESC LIMIT 20;"
    Write-Host "Query: $query"
    Write-Host ""
    # Try to use sqlite3 if available
    $sqlite3 = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($sqlite3) {
        sqlite3 $dbPath $query
    } else {
        Write-Host "sqlite3 not found - please install sqlite3 or use DB Browser for SQLite"
        Write-Host "DB path: $dbPath"
    }
} else {
    Write-Host "Database not found at: $dbPath"
}
