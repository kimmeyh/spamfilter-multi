# Check for saved context on startup
$memoryDir = ".claude/memory"
$currentFile = "$memoryDir/current.md"
$metadataFile = "$memoryDir/memory_metadata.json"

if (Test-Path $currentFile) {
    Write-Host "📋 Found saved sprint context!"
    Write-Host ""

    # Load metadata
    if (Test-Path $metadataFile) {
        $metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json

        # Check if status is "active"
        if ($metadata.status -eq "active") {
            Write-Host "🔄 Restoring context for $($metadata.sprint)..."
            Write-Host "📅 Last updated: $($metadata.last_updated)"
            Write-Host ""
            Write-Host "─────────────────────────────────────────"
            Get-Content $currentFile
            Write-Host "─────────────────────────────────────────"
            Write-Host ""
            Write-Host "✅ Context restored. Ready to continue sprint work."
        } else {
            Write-Host "⚠️  Found archived context (status: $($metadata.status))"
            Write-Host "   Run '.claude/scripts/archive-memory.ps1' to clear or manually edit .claude/memory/memory_metadata.json"
        }
    } else {
        Write-Host "⚠️  Found current.md but no metadata file"
        Write-Host "   Context may be from previous session"
    }
} else {
    Write-Host "ℹ️  No saved context found. Starting fresh."
}
