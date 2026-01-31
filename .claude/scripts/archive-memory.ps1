# Archive current memory and start fresh
$memoryDir = ".claude/memory"
$currentFile = "$memoryDir/current.md"
$metadataFile = "$memoryDir/memory_metadata.json"

if (!(Test-Path $currentFile)) {
    Write-Host "⚠️  No current memory file to archive"
    exit 0
}

# Create timestamped archive
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$archiveFile = "$memoryDir/$timestamp.md"

Copy-Item $currentFile $archiveFile
Write-Host "✅ Archived to $archiveFile"

# Update metadata
if (Test-Path $metadataFile) {
    $metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json

    $archivedEntry = @{
        file = $archiveFile
        sprint = $metadata.sprint
        date = $metadata.last_updated
        status = "archived"
    }

    # Initialize archived_saves as array if it does not exist
    if (!$metadata.archived_saves) {
        $metadata.archived_saves = @()
    }

    # Convert to ArrayList for easier manipulation
    $archivedList = [System.Collections.ArrayList]@($metadata.archived_saves)
    $archivedList.Add($archivedEntry) | Out-Null

    $metadata.archived_saves = $archivedList.ToArray()
    $metadata.status = "archived"

    $metadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $metadataFile -Encoding UTF8
}

# Remove current.md
Remove-Item $currentFile
Write-Host "✅ Current memory cleared"
Write-Host "ℹ️  Ready for next sprint"
