<#
.SYNOPSIS
  Propose delete rules from mail the current rules miss (F268). Read-only.

.PARAMETER DbDir
  Folder holding COPIES of spam_filter.db (with its -wal and -shm files) and
  content_history.db. A folder under %APPDATA%\MyEmailSpamFilter is refused.

.PARAMETER OutYaml
  Where the PASS candidates are written (docs/RULE_FORMAT.md shape). Keep it on
  this PC and out of the repository.

.PARAMETER OutReport
  Optional file that also receives the side report (counts, ids, domains).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_miner\rule_miner.ps1 -DbDir C:\temp\dbcopy -OutYaml C:\temp\proposed.yaml
#>
param(
    [Parameter(Mandatory)][string]$DbDir,
    [Parameter(Mandatory)][string]$OutYaml,
    [string]$OutReport = ''
)
$ErrorActionPreference = 'Stop'
$app = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:RULE_MINER_DB_DIR = (Resolve-Path -LiteralPath $DbDir).Path
# PR #490 7.7.1: resolved against the CURRENT PowerShell location. The .NET
# GetFullPath used before resolves against the PROCESS folder, which stays where
# the session started, so a relative path could land in the repository.
$resolve = { param($p) $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$env:RULE_MINER_OUT_YAML = & $resolve $OutYaml
$env:RULE_MINER_OUT_REPORT = if ($OutReport) { & $resolve $OutReport } else { '' }
Push-Location $app
try {
    flutter test tool/rule_miner/rule_miner.dart --reporter expanded
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
