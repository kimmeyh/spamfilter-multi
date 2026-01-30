#!/usr/bin/env powershell
<#
.SYNOPSIS
Captures Flutter diagnostics logs for zero-rules-match investigation

.DESCRIPTION
This script makes it easy to capture and analyze logs while testing the Bulk Mail folder scan.
It sets up log capture, lets you run the scan, then automatically filters and displays key diagnostics.

.PARAMETER Action
- Start: Begin capturing logs to file
- Stop: Stop log capture and filter results
- Analyze: Analyze existing log file

.PARAMETER LogFile
Path to log file (default: diagnostic_bulk_mail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log)

.EXAMPLE
# Start capturing logs
.\capture-diagnostic-logs.ps1 -Action Start

# After running your scan in the app, stop and analyze:
.\capture-diagnostic-logs.ps1 -Action Stop

# Analyze a specific log file:
.\capture-diagnostic-logs.ps1 -Action Analyze -LogFile "diagnostic_bulk_mail_20260128_143022.log"
#>

param(
    [ValidateSet("Start", "Stop", "Analyze")]
    [string]$Action = "Start",
    
    [string]$LogFile = $null
)

$ErrorActionPreference = "Stop"

# Helper function to display colored output
function Write-Status {
    param([string]$Message, [string]$Color = "Green")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

# Ensure adb is available
function Test-AdbAvailable {
    try {
        $null = & adb version 2>&1
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-AdbAvailable)) {
    Write-Status "ERROR: adb not found in PATH. Please install Android SDK tools." Red
    exit 1
}

# Get list of attached devices
function Get-DeviceList {
    $output = & adb devices
    $devices = $output | Where-Object { $_ -match "device$" } | ForEach-Object { $_.Split()[0] }
    return $devices
}

# ACTION: Start capturing logs
if ($Action -eq "Start") {
    Write-Section "Starting Log Capture"
    
    $devices = Get-DeviceList
    if ($devices.Count -eq 0) {
        Write-Status "WARNING: No devices detected. Please connect your device/emulator." Yellow
        Write-Status "Waiting for device connection..."
        & adb wait-for-device
        $devices = Get-DeviceList
    }
    
    if ($devices.Count -gt 1) {
        Write-Status "Multiple devices found. Using first device: $($devices[0])" Yellow
    } else {
        Write-Status "Device found: $($devices[0])" Green
    }
    
    if (-not $LogFile) {
        $LogFile = "diagnostic_bulk_mail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }
    
    Write-Status "Clearing previous logs..." Green
    & adb logcat -c
    
    Write-Status "Starting log capture to: $LogFile" Green
    Write-Host ""
    
    # Start capturing logs in background
    $process = Start-Process -FilePath "adb" -ArgumentList "logcat" `
        -RedirectStandardOutput $LogFile `
        -NoNewWindow -PassThru
    
    Write-Status "Log capture started (Process ID: $($process.Id))" Green
    Write-Status "Saving process ID for later stopping..." Green
    $process.Id | Out-File ".logcat_pid" -Force
    
    Write-Host ""
    Write-Section "Next Steps"
    Write-Host "1. In the app, go to: Account Selection → Select kimmeyharold@aol.com" -ForegroundColor White
    Write-Host "2. Click 'Start Live Scan' (NOT Demo Scan)" -ForegroundColor White
    Write-Host "3. Select 'Bulk Mail Testing' folder" -ForegroundColor White
    Write-Host "4. Wait for scan to complete or process ~20 emails" -ForegroundColor White
    Write-Host "5. Once done, run: .\capture-diagnostic-logs.ps1 -Action Stop" -ForegroundColor White
    Write-Host ""
    Write-Status "Logs are being captured. Run the scan now..." Yellow
}

# ACTION: Stop capturing and analyze
elseif ($Action -eq "Stop") {
    Write-Section "Stopping Log Capture"
    
    $pidFile = ".logcat_pid"
    if (-not (Test-Path $pidFile)) {
        Write-Status "ERROR: No active log capture found. Start with: -Action Start" Red
        exit 1
    }
    
    $pid = Get-Content $pidFile -Raw | ForEach-Object { $_.Trim() }
    
    try {
        $process = Get-Process -Id $pid -ErrorAction Stop
        Write-Status "Stopping log capture process (PID: $pid)..." Green
        Stop-Process -Id $pid -Force
        Start-Sleep -Milliseconds 500
        Remove-Item $pidFile -Force
        Write-Status "Log capture stopped." Green
    } catch {
        Write-Status "Process already stopped." Yellow
    }
    
    # Find the most recent log file if not specified
    if (-not $LogFile) {
        $LogFile = Get-ChildItem "diagnostic_bulk_mail_*.log" -ErrorAction SilentlyContinue `
            | Sort-Object LastWriteTime -Descending `
            | Select-Object -First 1 -ExpandProperty Name
        
        if (-not $LogFile) {
            Write-Status "ERROR: No log files found matching 'diagnostic_bulk_mail_*.log'" Red
            exit 1
        }
    }
    
    Write-Status "Log file: $LogFile" Green
    Write-Host ""
    
    # Analyze the log file
    & powershell -Command @"
        `$logFile = '$LogFile'
        
        Write-Section "DIAGNOSTIC SUMMARY"
        
        # Extract diagnostic block
        `$diag = Select-String -Path `$logFile -Pattern "=== SCAN DIAGNOSTICS ===" -A 10 | Select-Object -First 1
        if (`$diag) {
            Write-Host "`$(`$diag.Line)`n`$(`$diag.Context.PostContext -join \"`n\`")"
        } else {
            Write-Host "No diagnostic block found!" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Section "RULE MATCHES"
        `$matches = @(Select-String -Path `$logFile -Pattern "✓ Email.*matched rule")
        Write-Status "✓ Matched: `$(`$matches.Count) emails" Green
        if (`$matches.Count -gt 0) {
            `$matches | Select-Object -First 5 | ForEach-Object { Write-Host "  `$(`$_.Line)" }
            if (`$matches.Count -gt 5) {
                Write-Host "  ... and `$(`$matches.Count - 5) more"
            }
        }
        
        Write-Host ""
        Write-Section "NO MATCHES"
        `$noMatches = @(Select-String -Path `$logFile -Pattern "✗ Email.*did not match")
        Write-Status "✗ No Match: `$(`$noMatches.Count) emails" Yellow
        
        Write-Host ""
        Write-Section "ERRORS AND WARNINGS"
        `$errors = @(Select-String -Path `$logFile -Pattern "(ERROR|Exception|EXCEPTION|failed)")
        if (`$errors.Count -gt 0) {
            Write-Status "Found `$(`$errors.Count) error/exception entries" Red
            `$errors | Select-Object -First 10 | ForEach-Object { Write-Host "  `$(`$_.Line)" }
        } else {
            Write-Status "No errors found" Green
        }
        
        Write-Host ""
        Write-Section "MIGRATION STATUS"
        `$migration = @(Select-String -Path `$logFile -Pattern "(migration|Migration|YAML|Imported)")
        if (`$migration.Count -gt 0) {
            `$migration | ForEach-Object { Write-Host "  `$(`$_.Line)" }
        } else {
            Write-Host "No migration messages found (might be expected if not first run)" -ForegroundColor Yellow
        }
"@
}

# ACTION: Analyze existing log file
elseif ($Action -eq "Analyze") {
    if (-not $LogFile -or -not (Test-Path $LogFile)) {
        Write-Status "ERROR: Log file not found: $LogFile" Red
        exit 1
    }
    
    Write-Section "Analyzing Log File: $LogFile"
    Write-Host ""
    
    # Extract diagnostic block
    Write-Section "DIAGNOSTIC OUTPUT"
    $diag = Select-String -Path $LogFile -Pattern "=== SCAN DIAGNOSTICS ===" -A 10 | Select-Object -First 1
    if ($diag) {
        Write-Host $diag.Line
        $diag.Context.PostContext | ForEach-Object { Write-Host $_ }
    } else {
        Write-Status "No diagnostic block found!" Red
    }
    
    Write-Host ""
    Write-Section "RULE MATCHING SUMMARY"
    
    $matches = @(Select-String -Path $LogFile -Pattern "✓ Email.*matched rule")
    Write-Status "✓ Matched: $($matches.Count) emails" Green
    
    $noMatches = @(Select-String -Path $LogFile -Pattern "✗ Email.*did not match")
    Write-Status "✗ No Match: $($noMatches.Count) emails" Yellow
    
    Write-Host ""
    Write-Section "DETAILED MATCHES (first 10)"
    if ($matches.Count -gt 0) {
        $matches | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Line)" -ForegroundColor Green
        }
        if ($matches.Count -gt 10) {
            Write-Host "  ... and $($matches.Count - 10) more" -ForegroundColor Gray
        }
    } else {
        Write-Host "  (no matches found)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Section "SAMPLE NO-MATCHES (first 5)"
    if ($noMatches.Count -gt 0) {
        $noMatches | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $($_.Line)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  (all emails matched!)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Section "ERROR CHECK"
    $errors = @(Select-String -Path $LogFile -Pattern "(ERROR|Exception|EXCEPTION|failed)")
    if ($errors.Count -gt 0) {
        Write-Status "Found $($errors.Count) error/exception entries" Red
        $errors | ForEach-Object {
            Write-Host "  $($_.Line)" -ForegroundColor Red
        }
    } else {
        Write-Status "No errors found" Green
    }
    
    Write-Host ""
    Write-Section "RULES STATUS"
    $rulesLoaded = Select-String -Path $LogFile -Pattern "Rules loaded:" | Select-Object -First 1
    if ($rulesLoaded) {
        Write-Host "  $($rulesLoaded.Line)"
        
        # Extract the number
        if ($rulesLoaded.Line -match "Rules loaded: (\d+)") {
            $count = [int]$matches[1]
            if ($count -eq 0) {
                Write-Status "WARNING: No rules loaded! Migration may have failed." Red
            } elseif ($count -lt 40) {
                Write-Status "WARNING: Only $count rules loaded (expected 40+)" Yellow
            } else {
                Write-Status "✓ Rules loaded: $count (expected)" Green
            }
        }
    }
    
    Write-Host ""
    Write-Section "SAFE SENDERS STATUS"
    $safeSenders = Select-String -Path $LogFile -Pattern "Safe senders loaded:" | Select-Object -First 1
    if ($safeSenders) {
        Write-Host "  $($safeSenders.Line)"
    }
}

Write-Host ""
