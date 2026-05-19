# Sprint 38 F85 (ADR-0038): validate the content manifest against the
# .md files on disk and the HelpSection enum in Dart source.
#
# The three drift checks (per ADR-0038):
#   1. Every key in manifest.yaml resolves to an existing .md file
#   2. Every .md file under assets/content/ is referenced by exactly one key
#      (catches orphan files left behind after a rename)
#   3. Every HelpSection enum case in lib/ui/screens/help_screen.dart has
#      a corresponding entry in manifest.yaml -> help: namespace
#
# Usage:
#   pwsh -File mobile-app/scripts/validate-content-manifest.ps1
#
# Exit codes:
#   0 = manifest is consistent with disk and Dart source
#   1 = one or more drift issues found (printed to stderr)

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$contentDir = Join-Path $repoRoot 'mobile-app\assets\content'
$manifestPath = Join-Path $contentDir 'manifest.yaml'
$helpScreenPath = Join-Path $repoRoot 'mobile-app\lib\ui\screens\help_screen.dart'

if (-not (Test-Path $manifestPath)) {
    Write-Error "Manifest not found: $manifestPath"
    exit 1
}
if (-not (Test-Path $helpScreenPath)) {
    Write-Error "help_screen.dart not found: $helpScreenPath"
    exit 1
}

# Parse manifest.yaml (lightweight regex-based parse -- avoids PowerShell-YAML
# module dependency). The manifest is a flat 2-level structure:
#   namespace:
#     key: relative/path.md
$manifestText = Get-Content $manifestPath -Raw
$currentNamespace = $null
$manifestEntries = @{}  # "namespace.key" -> "relative/path"
foreach ($line in ($manifestText -split "`r?`n")) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
    if ($line -match '^([a-zA-Z_]+):\s*$') {
        $currentNamespace = $matches[1]
        if ($Verbose) { Write-Host "[parse] namespace: $currentNamespace" }
    }
    elseif ($line -match '^\s+([a-zA-Z_][a-zA-Z0-9_]*):\s*(.+\.md)\s*$') {
        if ($null -eq $currentNamespace) {
            Write-Error "Manifest key '$($matches[1])' appears before any namespace heading"
            exit 1
        }
        $key = "$currentNamespace.$($matches[1])"
        $manifestEntries[$key] = $matches[2].Trim()
        if ($Verbose) { Write-Host "[parse]   $key -> $($matches[2])" }
    }
}

if ($manifestEntries.Count -eq 0) {
    Write-Error "Manifest is empty -- no namespace/key entries parsed"
    exit 1
}

$failures = @()

# Check 1: every key resolves to an existing .md file
foreach ($entry in $manifestEntries.GetEnumerator()) {
    $expectedFile = Join-Path $contentDir $entry.Value.Replace('/', '\')
    if (-not (Test-Path $expectedFile)) {
        $failures += "[Check 1] Manifest entry '$($entry.Key)' references missing file: $($entry.Value)"
    }
}

# Check 2: every .md file under assets/content/ (excluding audit-log.md
# which is meta-documentation, not content) is referenced by exactly one
# manifest key.
$mdFiles = Get-ChildItem -Path $contentDir -Recurse -Filter '*.md' |
    Where-Object { $_.Name -ne 'audit-log.md' } |
    ForEach-Object {
        # Convert absolute path to manifest-relative path (forward slashes)
        $rel = $_.FullName.Substring($contentDir.Length + 1).Replace('\', '/')
        $rel
    }

$referencedPaths = $manifestEntries.Values | Sort-Object -Unique
foreach ($mdRel in $mdFiles) {
    if ($mdRel -notin $referencedPaths) {
        $failures += "[Check 2] Orphan content file (not in manifest): $mdRel"
    }
}

# Detect duplicate references (same path mapped from two keys)
$pathCounts = @{}
foreach ($v in $manifestEntries.Values) {
    if ($pathCounts.ContainsKey($v)) {
        $pathCounts[$v] += 1
    } else {
        $pathCounts[$v] = 1
    }
}
foreach ($p in $pathCounts.GetEnumerator()) {
    if ($p.Value -gt 1) {
        $failures += "[Check 2] Duplicate manifest reference: $($p.Key) referenced $($p.Value) times"
    }
}

# Check 3: HelpSection enum cases must each have a manifest entry under
# help: namespace.
$helpDart = Get-Content $helpScreenPath -Raw
$enumMatch = [regex]::Match($helpDart, '(?ms)enum HelpSection \{(.+?)\}')
if (-not $enumMatch.Success) {
    $failures += "[Check 3] Could not parse HelpSection enum from help_screen.dart"
} else {
    $enumBody = $enumMatch.Groups[1].Value
    $enumCases = [regex]::Matches($enumBody, '(?m)^\s*([a-zA-Z][a-zA-Z0-9]*)\s*,') |
        ForEach-Object { $_.Groups[1].Value }
    foreach ($case in $enumCases) {
        $expectedKey = "help.$case"
        if (-not $manifestEntries.ContainsKey($expectedKey)) {
            $failures += "[Check 3] HelpSection.$case has no manifest entry under help: namespace"
        }
    }
    if ($Verbose) {
        Write-Host "[parse] HelpSection cases found: $($enumCases.Count)"
    }
}

# Report
if ($failures.Count -eq 0) {
    Write-Host "[OK] Content manifest is consistent with disk and HelpSection enum" -ForegroundColor Green
    Write-Host "     Manifest entries: $($manifestEntries.Count)"
    Write-Host "     Content .md files: $($mdFiles.Count)"
    exit 0
} else {
    Write-Host "[FAIL] $($failures.Count) drift issue(s) found:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
}
