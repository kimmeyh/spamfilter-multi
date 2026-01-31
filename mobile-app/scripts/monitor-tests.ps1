#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor Flutter test execution in real-time with progress tracking

.DESCRIPTION
    This script monitors Flutter test execution, logging output and tracking progress.
    Useful for debugging long-running tests, identifying slow tests, and monitoring
    parallel test execution.

.PARAMETER OutputFile
    Optional output file to save test logs (default: test-monitor-{timestamp}.txt)

.PARAMETER ShowProgress
    Show real-time progress updates (default: true)

.PARAMETER HighlightSlow
    Highlight tests taking longer than specified seconds (default: 5)

.EXAMPLE
    .\monitor-tests.ps1
    Run with default settings

.EXAMPLE
    .\monitor-tests.ps1 -OutputFile my-tests.txt -HighlightSlow 10
    Save to specific file and highlight tests > 10 seconds

.NOTES
    Author: Claude Code
    Created: 2026-01-30
    Sprint: Sprint 9 Task D
#>

param(
    [string]$OutputFile = "",
    [switch]$ShowProgress = $true,
    [int]$HighlightSlow = 5
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Generate default output file if not specified
if ([string]::IsNullOrEmpty($OutputFile)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputFile = "test-monitor-$timestamp.txt"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Test Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Output File: $OutputFile" -ForegroundColor Yellow
Write-Host "Highlight Slow: > $HighlightSlow seconds" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test statistics
$stats = @{
    Total = 0
    Passed = 0
    Failed = 0
    Skipped = 0
    StartTime = Get-Date
    SlowTests = @()
}

# Start flutter test in background and capture output
$testProcess = Start-Process -FilePath "flutter" -ArgumentList "test", "--reporter", "expanded" `
    -NoNewWindow -PassThru -RedirectStandardOutput $OutputFile -Wait:$false

Write-Host "Test execution started (PID: $($testProcess.Id))" -ForegroundColor Green
Write-Host "Monitoring output..." -ForegroundColor Green
Write-Host ""

# Monitor the output file
$lastPosition = 0
$currentTest = ""
$testStartTime = $null

while (-not $testProcess.HasExited) {
    Start-Sleep -Milliseconds 500

    if (Test-Path $OutputFile) {
        $content = Get-Content $OutputFile -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content -and $content.Length -gt $lastPosition) {
            $newContent = $content.Substring($lastPosition)
            $lastPosition = $content.Length

            # Parse test output
            $lines = $newContent -split "`n"
            foreach ($line in $lines) {
                # Detect test start
                if ($line -match "^\d{2}:\d{2} \+\d+ -\d+: (.+)$") {
                    if ($null -ne $testStartTime -and -not [string]::IsNullOrEmpty($currentTest)) {
                        $duration = (Get-Date) - $testStartTime
                        if ($duration.TotalSeconds -gt $HighlightSlow) {
                            $stats.SlowTests += @{
                                Name = $currentTest
                                Duration = $duration.TotalSeconds
                            }
                            Write-Host "[SLOW] $currentTest took $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor Yellow
                        }
                    }
                    $currentTest = $matches[1]
                    $testStartTime = Get-Date
                }

                # Detect test pass
                if ($line -match "^\d{2}:\d{2} \+(\d+)") {
                    $stats.Passed = [int]$matches[1]
                }

                # Detect test fail
                if ($line -match "^\d{2}:\d{2} \+\d+ -(\d+)") {
                    $stats.Failed = [int]$matches[1]
                }

                # Detect test skip
                if ($line -match "^\d{2}:\d{2} \+\d+ ~(\d+)") {
                    $stats.Skipped = [int]$matches[1]
                }

                # Show progress if enabled
                if ($ShowProgress -and $line -match "^\d{2}:\d{2}") {
                    Write-Host $line -ForegroundColor Gray
                }

                # Highlight errors
                if ($line -match "Error|Exception|Failed") {
                    Write-Host $line -ForegroundColor Red
                }
            }
        }
    }
}

# Wait for process to complete
$testProcess.WaitForExit()
$exitCode = $testProcess.ExitCode

# Calculate final statistics
$stats.Total = $stats.Passed + $stats.Failed + $stats.Skipped
$duration = (Get-Date) - $stats.StartTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Execution Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host "Total Tests: $($stats.Total)" -ForegroundColor White
Write-Host "Passed: $($stats.Passed)" -ForegroundColor Green
Write-Host "Failed: $($stats.Failed)" -ForegroundColor $(if ($stats.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host "Skipped: $($stats.Skipped)" -ForegroundColor Yellow
Write-Host "Exit Code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
Write-Host ""

# Show slow tests summary
if ($stats.SlowTests.Count -gt 0) {
    Write-Host "Slow Tests (> $HighlightSlow seconds):" -ForegroundColor Yellow
    $stats.SlowTests | Sort-Object -Property Duration -Descending | ForEach-Object {
        Write-Host "  - $($_.Name): $([math]::Round($_.Duration, 2))s" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Full output saved to: $OutputFile" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

exit $exitCode
