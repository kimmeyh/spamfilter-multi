<#
.SYNOPSIS
    Turn Windows Error Reporting local crash dumps on or off for one app.

.DESCRIPTION
    When an app crashes, Windows keeps its dump only briefly (in WER\Temp) and
    then deletes it. This script sets the documented LocalDumps registry key so
    Windows writes a FULL dump of every crash of the named exe to a folder that
    stays. Must run as Administrator (the key is under HKLM).

    Registry key (Microsoft Learn, "Collecting User-Mode Dumps", checked
    2026-10-08: https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps):
      HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\<exe>
        DumpFolder (REG_EXPAND_SZ)  where dumps go
        DumpCount  (REG_DWORD)      how many to keep
        DumpType   (REG_DWORD)      2 = full dump

    Written for the Sprint 77 Manual Validation crash (0xc0000409, faulting
    module "unknown"), whose WER dump was deleted before it could be read.

.PARAMETER Exe
    The exe file name. Default: MyEmailSpamFilter-Dev.exe.

.PARAMETER Folder
    Where dumps are written. Default: %LOCALAPPDATA%\CrashDumps.

.PARAMETER Disable
    Remove the key again.

.EXAMPLE
    scripts\enable-crash-dumps.ps1
.EXAMPLE
    scripts\enable-crash-dumps.ps1 -Disable
#>
param(
    [string]$Exe = 'MyEmailSpamFilter-Dev.exe',
    [string]$Folder = '%LOCALAPPDATA%\CrashDumps',
    [int]$Count = 5,
    [switch]$Disable
)

$ErrorActionPreference = 'Stop'
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '[FAIL] Run this from an Administrator PowerShell.'
    exit 1
}

$key = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\$Exe"

if ($Disable) {
    if (Test-Path $key) { Remove-Item $key -Recurse }
    Write-Host "[OK] Local crash dumps OFF for $Exe"
    exit 0
}

New-Item -Path $key -Force | Out-Null
New-ItemProperty -Path $key -Name DumpFolder -PropertyType ExpandString -Value $Folder -Force | Out-Null
New-ItemProperty -Path $key -Name DumpCount -PropertyType DWord -Value $Count -Force | Out-Null
New-ItemProperty -Path $key -Name DumpType -PropertyType DWord -Value 2 -Force | Out-Null

$expanded = [Environment]::ExpandEnvironmentVariables($Folder)
Write-Host "[OK] Full crash dumps ON for $Exe"
Write-Host "     Dumps go to: $expanded (keeps $Count)"
Write-Host "     Turn off: scripts\enable-crash-dumps.ps1 -Disable"
