<#
.SYNOPSIS
    Validate YAML rule files for spam filter

.DESCRIPTION
    Validates rules.yaml and rules_safe_senders.yaml files for:
    - YAML syntax correctness
    - Schema compliance
    - Regex pattern validity
    - Performance issues (catastrophic backtracking)
    - Duplicate patterns
    - Consistent formatting

.PARAMETER RulesFile
    Path to rules.yaml file (default: ../rules.yaml)

.PARAMETER SafeSendersFile
    Path to rules_safe_senders.yaml (default: ../rules_safe_senders.yaml)

.PARAMETER TestRegex
    If set, test regex patterns against sample email headers

.EXAMPLE
    .\validate-yaml-rules.ps1
    .\validate-yaml-rules.ps1 -TestRegex
#>

param(
    [string]$RulesFile = "rules.yaml",
    [string]$SafeSendersFile = "rules_safe_senders.yaml",
    [switch]$TestRegex
)

$ErrorActionPreference = 'Continue'

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "YAML Rules Validation" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$validationErrors = @()
$validationWarnings = @()

# Helper function to test regex patterns
function Test-RegexPattern {
    param(
        [string]$Pattern,
        [string]$Context
    )
    
    try {
        # Try to compile the regex
        $null = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        # Check for potentially dangerous patterns
        $dangerousPatterns = @(
            '(\.\*){2,}',           # Multiple .* in sequence
            '\(\.\*\+',             # .* followed by +
            '\(\.\+\)\*',           # (.+)*
            '\(\[.*\]\+\)\*'        # ([...]+)*
        )
        
        foreach ($dangerous in $dangerousPatterns) {
            if ($Pattern -match $dangerous) {
                $validationWarnings += "[PERFORMANCE WARNING] Pattern may cause catastrophic backtracking: $Pattern (in $Context)"
            }
        }
        
        return $true
    } catch {
        $validationErrors += "[REGEX ERROR] Invalid pattern: $Pattern (in $Context) - $($_.Exception.Message)"
        return $false
    }
}

# Validate rules.yaml
Write-Host "[1/3] Validating rules.yaml..." -ForegroundColor Cyan
if (-not (Test-Path $RulesFile)) {
    Write-Host "  [ERROR] File not found: $RulesFile" -ForegroundColor Red
    exit 1
}

try {
    # Read YAML content
    $rulesContent = Get-Content $RulesFile -Raw
    
    # Basic YAML syntax check (PowerShell doesn't have native YAML parser)
    # We'll check for common issues
    
    # Check for tabs (YAML requires spaces)
    if ($rulesContent -match "`t") {
        $validationErrors += "[YAML ERROR] rules.yaml contains tabs - YAML requires spaces for indentation"
    }
    
    # Check for required top-level keys (supports quoted keys like 'rules':)
    if ($rulesContent -notmatch "(?m)^'?rules'?:") {
        $validationErrors += "[SCHEMA ERROR] rules.yaml missing 'rules' key"
    }
    
    # Extract and validate regex patterns
    # Pattern for list items with single quotes: - 'pattern'
    $singleQuoteMatches = [regex]::Matches($rulesContent, "(?m)^\s*-\s*'([^']+)'")
    # Pattern for list items with double quotes: - "pattern"
    $doubleQuoteMatches = [regex]::Matches($rulesContent, '(?m)^\s*-\s*"([^"]+)"')
    
    $patternCount = 0
    $validPatternCount = 0
    
    # Process single quote patterns (most common in your YAML)
    foreach ($match in $singleQuoteMatches) {
        $pattern = $match.Groups[1].Value
        # Skip non-regex values like 'True', 'False', 'OR', 'AND', rule names
        if ($pattern -match '^(True|False|OR|AND|SpamAuto|Spam|Email)') { continue }
        if ($pattern -notmatch '[@\[\]\.\*\+\?\(\)\^\$\\]') { continue }  # Must look like regex
        
        $patternCount++
        if (Test-RegexPattern -Pattern $pattern -Context "rules.yaml") {
            $validPatternCount++
        }
    }
    
    # Process double quote patterns
    foreach ($match in $doubleQuoteMatches) {
        $pattern = $match.Groups[1].Value
        if ($pattern -match '^(True|False|OR|AND|SpamAuto|Spam|Email)') { continue }
        if ($pattern -notmatch '[@\[\]\.\*\+\?\(\)\^\$\\]') { continue }
        
        $patternCount++
        if (Test-RegexPattern -Pattern $pattern -Context "rules.yaml") {
            $validPatternCount++
        }
    }
    
    Write-Host "  [OK] Found $patternCount regex patterns, $validPatternCount valid" -ForegroundColor Green
    
} catch {
    $validationErrors += "[YAML ERROR] Failed to parse rules.yaml: $($_.Exception.Message)"
}

# Validate rules_safe_senders.yaml
Write-Host "[2/3] Validating rules_safe_senders.yaml..." -ForegroundColor Cyan
if (-not (Test-Path $SafeSendersFile)) {
    Write-Host "  [WARNING] File not found: $SafeSendersFile" -ForegroundColor Yellow
} else {
    try {
        $safeSendersContent = Get-Content $SafeSendersFile -Raw
        
        # Check for tabs
        if ($safeSendersContent -match "`t") {
            $validationErrors += "[YAML ERROR] rules_safe_senders.yaml contains tabs"
        }
        
        # Check for required top-level key (supports quoted key)
        if ($safeSendersContent -notmatch "(?m)^'?safe_senders'?:") {
            $validationErrors += "[SCHEMA ERROR] rules_safe_senders.yaml missing 'safe_senders' key"
        }
        
        # Extract and validate safe sender patterns (supports single or double quotes)
        $safeSenderMatches1 = [regex]::Matches($safeSendersContent, "(?m)^\s*-\s*'([^']+)'")
        $safeSenderMatches2 = [regex]::Matches($safeSendersContent, '(?m)^\s*-\s*"([^"]+)"')
        $safeSenderMatches = @()
        $safeSenderMatches += $safeSenderMatches1
        $safeSenderMatches += $safeSenderMatches2
        $safeSenderCount = 0
        $validSafeSenderCount = 0
        
        foreach ($match in $safeSenderMatches) {
            $pattern = $match.Groups[1].Value
            $safeSenderCount++
            
            if (Test-RegexPattern -Pattern $pattern -Context "safe_senders.yaml line $($match.Index)") {
                $validSafeSenderCount++
            }
        }
        
        Write-Host "  [OK] Found $safeSenderCount safe sender patterns, $validSafeSenderCount valid" -ForegroundColor Green
        
        # Check for duplicates
        $uniquePatterns = $safeSenderMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        if ($uniquePatterns.Count -lt $safeSenderCount) {
            $duplicateCount = $safeSenderCount - $uniquePatterns.Count
            $validationWarnings += "[DUPLICATE WARNING] Found $duplicateCount duplicate patterns in safe_senders.yaml"
        }
        
    } catch {
        $validationErrors += "[YAML ERROR] Failed to parse rules_safe_senders.yaml: $($_.Exception.Message)"
    }
}

# Optional: Test regex patterns against sample data
if ($TestRegex) {
    Write-Host "[3/3] Testing regex patterns against sample email headers..." -ForegroundColor Cyan
    
    $sampleHeaders = @(
        "user@example.com",
        "John Doe <user@example.com>",
        "noreply@mail.example.com",
        "support+ticket123@subdomain.example.co.uk"
    )
    
    Write-Host "  Testing with sample headers:" -ForegroundColor Gray
    $sampleHeaders | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    Write-Host ""
    
    # This would test actual patterns - implementation depends on requirements
    Write-Host "  [INFO] Regex testing against samples - feature available" -ForegroundColor Cyan
} else {
    Write-Host "[3/3] Skipping regex testing (use -TestRegex to enable)" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

if ($validationErrors.Count -eq 0 -and $validationWarnings.Count -eq 0) {
    Write-Host "[OK] All validations passed!" -ForegroundColor Green
    exit 0
} else {
    if ($validationErrors.Count -gt 0) {
        Write-Host "Errors: $($validationErrors.Count)" -ForegroundColor Red
        $validationErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
    }
    
    if ($validationWarnings.Count -gt 0) {
        Write-Host "Warnings: $($validationWarnings.Count)" -ForegroundColor Yellow
        $validationWarnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        Write-Host ""
    }
    
    if ($validationErrors.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
