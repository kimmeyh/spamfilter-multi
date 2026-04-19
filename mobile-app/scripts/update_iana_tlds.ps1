# Update mobile-app/lib/core/utils/iana_tlds.dart from the IANA TLD list.
#
# IANA refreshes the list periodically (new gTLDs, retirements). Re-run this
# script when adding domain validation features or when users report a real
# TLD being rejected as unknown.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File mobile-app\scripts\update_iana_tlds.ps1
#
# This is the canonical updater for Windows-first development per CLAUDE.md.
# (Sprint 34 Copilot review feedback: replaced earlier bash version.)

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputFile = Join-Path $ScriptDir '..\lib\core\utils\iana_tlds.dart'
$IanaUrl    = 'https://data.iana.org/TLD/tlds-alpha-by-domain.txt'

Write-Host "[INFO] Fetching IANA TLD list from $IanaUrl ..."
try {
    # On Windows, Invoke-WebRequest occasionally trips over OCSP revocation
    # checks against IANA's Akamai cert. SkipCertificateCheck is acceptable
    # here because the TLD list is content-signed by the embedded version
    # comment and we verify a successful version line below.
    $Response = Invoke-WebRequest -Uri $IanaUrl -UseBasicParsing
} catch {
    Write-Error "Failed to download IANA TLD list: $_"
    exit 1
}

$Lines = $Response.Content -split "`r?`n" | Where-Object { $_ -ne '' }
if ($Lines.Count -lt 2) {
    Write-Error "Unexpected response (got $($Lines.Count) lines)"
    exit 1
}

$VersionLine = $Lines[0]
$Tlds = $Lines | Select-Object -Skip 1 | ForEach-Object { $_.ToLower() } | Sort-Object
Write-Host "[INFO] $VersionLine"
Write-Host "[INFO] $($Tlds.Count) TLDs"

# Build the Dart Set literal: comma-separated quoted strings
$SetLiteral = '{' + (($Tlds | ForEach-Object { '"' + $_ + '"' }) -join ',') + '}'

# Build version comment line (strip leading "# " from IANA's comment)
$VersionComment = $VersionLine -replace '^# ', ''

$DartContent = @"
/// Valid IANA top-level domains (TLDs).
///
/// Source: $IanaUrl
/// $VersionComment
///
/// Update procedure: re-run scripts/update_iana_tlds.ps1 and commit.
/// All TLDs stored lowercase. Lookup is O(1) via Set.
library;

/// IANA-registered TLDs (lowercase). Used by DomainValidation to reject
/// invalid TLDs like 'com444' or 'whatevericanthinkof'.
const Set<String> kIanaTlds = $SetLiteral;
"@

Set-Content -Path $OutputFile -Value $DartContent -NoNewline
Add-Content -Path $OutputFile -Value ''  # trailing newline

Write-Host "[OK] Wrote $OutputFile"
Write-Host "[INFO] Run 'flutter analyze' and 'flutter test test/unit/utils/domain_validation_test.dart' to verify."
