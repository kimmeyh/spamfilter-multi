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

.PARAMETER Trash2Jsonl
  F308 trash2 mode: the JSONL file written by the read-only Trash2 probe (private
  mail text; keep it out of the repository). When set, the miner learns from the
  mail a delete rule caught in Trash2 and scores against No Rule and safe-sender
  mail. OutYaml then holds the F308 candidates (single parts and AND pairs).

.PARAMETER Safe
  F310 safe mode: learn what safe-sender mail has in common that delete-rule mail
  does not, and report sender-domain and signal candidates that require the auth
  gate (stored auth class green). OutYaml then holds safe_senders patterns.
  Trash2Jsonl is optional in this mode (extra delete-rule mail, auth unknown).

.PARAMETER ShowPhrases
  Trash2 mode: print phrase text in the report (default prints ids and counts).
  Safe mode: print sender domains.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_miner\rule_miner.ps1 -DbDir C:\temp\dbcopy -OutYaml C:\temp\proposed.yaml
#>
param(
    [Parameter(Mandatory)][string]$DbDir,
    [Parameter(Mandatory)][string]$OutYaml,
    [string]$OutReport = '',
    [string]$Trash2Jsonl = '',
    [switch]$Safe,
    [switch]$ShowPhrases
)
$ErrorActionPreference = 'Stop'
$app = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:RULE_MINER_DB_DIR = (Resolve-Path -LiteralPath $DbDir).Path
# PR #490 7.7.1: resolved against the CURRENT PowerShell location. The .NET
# GetFullPath used before resolves against the PROCESS folder, which stays where
# the session started, so a relative path could land in the repository.
$resolve = { param($p) $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$env:RULE_MINER_OUT_YAML = & $resolve $OutYaml
$env:RULE_MINER_MODE = if ($Safe) { 'safe' } elseif ($Trash2Jsonl) { 'trash2' } else { '' }
$env:RULE_MINER_TRASH_JSONL = if ($Trash2Jsonl) { (Resolve-Path -LiteralPath $Trash2Jsonl).Path } else { '' }
$env:RULE_MINER_SHOW_PHRASES = if ($ShowPhrases) { '1' } else { '' }
$env:RULE_MINER_OUT_REPORT = if ($OutReport) { & $resolve $OutReport } else { '' }
Push-Location $app
try {
    flutter test tool/rule_miner/rule_miner.dart --reporter expanded
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
