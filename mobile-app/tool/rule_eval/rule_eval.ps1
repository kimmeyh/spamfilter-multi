<#
.SYNOPSIS
  Score candidate rules against a COPY of the developer's scan history (F267).

.PARAMETER Candidate
  Candidate rules YAML (docs/RULE_FORMAT.md shape).

.PARAMETER DbDir
  Folder holding COPIES of spam_filter.db (with its -wal and -shm files) and
  content_history.db. A folder under %APPDATA%\MyEmailSpamFilter is refused.

.PARAMETER Out
  Optional file that also receives the report text (no email content).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_eval\rule_eval.ps1 -Candidate cand.yaml -DbDir C:\temp\dbcopy
#>
param(
    [Parameter(Mandatory)][string]$Candidate,
    [Parameter(Mandatory)][string]$DbDir,
    [string]$Out = ''
)
$ErrorActionPreference = 'Stop'
$app = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:RULE_EVAL_CANDIDATE = (Resolve-Path -LiteralPath $Candidate).Path
$env:RULE_EVAL_DB_DIR = (Resolve-Path -LiteralPath $DbDir).Path
$env:RULE_EVAL_OUT = $Out
Push-Location $app
try {
    flutter test tool/rule_eval/rule_eval.dart --reporter expanded
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
