# Save current sprint context to memory file
param(
    [string]$SprintName = "",
    [string]$CustomNotes = ""
)

$memoryDir = ".claude/memory"
$currentFile = "$memoryDir/current.md"
$metadataFile = "$memoryDir/memory_metadata.json"

# Create memory directory if not exists
if (!(Test-Path $memoryDir)) {
    New-Item -ItemType Directory -Path $memoryDir | Out-Null
}

# Get sprint context from user input or git branch
if ([string]::IsNullOrEmpty($SprintName)) {
    $branch = git branch --show-current 2>$null
    if ($branch -match "Sprint_(\d+)") {
        $SprintName = "Sprint $($matches[1])"
    } else {
        $SprintName = "Unknown Sprint"
    }
}

# Create context save template
$contextTemplate = @"
# Sprint Context Save

**Sprint**: $SprintName
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Branch**: $(git branch --show-current 2>$null)
**Status**: In Progress

## Current Tasks

- [ ] Task A: [Description]
- [ ] Task B: [Description]
- [ ] Task C: [Description]

## Recent Work

[Summarize what was completed in last session]

## Next Steps

[What needs to be done when resuming]

## Blockers/Notes

$CustomNotes

---

**Instructions for Claude on Resume**:
1. Read this context file on startup
2. Verify git branch matches sprint
3. Continue from "Next Steps" section above
4. Check if any tasks marked complete since last save
"@

# Write context to current.md
$contextTemplate | Out-File -FilePath $currentFile -Encoding UTF8

# Update metadata
$metadata = @{
    current_save = $currentFile
    last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    sprint = $SprintName
    status = "active"
    archived_saves = @()
}

# Load existing metadata if exists
if (Test-Path $metadataFile) {
    $existingMetadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
    if ($existingMetadata.archived_saves) {
        $metadata.archived_saves = $existingMetadata.archived_saves
    }
}

$metadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $metadataFile -Encoding UTF8

Write-Host "Sprint context saved to $currentFile"
Write-Host "Edit this file to add specific context before exiting Claude"
