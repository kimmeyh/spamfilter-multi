<#
.SYNOPSIS
    Interactive regex pattern tester for email spam filter rules

.DESCRIPTION
    Test regex patterns against email headers before deploying to rules.yaml.
    Helps catch pattern errors, test match behavior, and verify performance.

.PARAMETER Pattern
    Regex pattern to test (required)

.PARAMETER TestString
    String to test pattern against (optional, prompts if not provided)

.PARAMETER File
    File containing test strings (one per line)

.PARAMETER ShowMatches
    Display all matches and capture groups

.PARAMETER PerformanceTest
    Run pattern 1000 times to check for performance issues

.EXAMPLE
    .\test-regex-patterns.ps1 -Pattern "^user@example\.com$" -TestString "user@example.com"
    .\test-regex-patterns.ps1 -Pattern "^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$" -File test-emails.txt
    .\test-regex-patterns.ps1 -Pattern ".*urgent.*" -PerformanceTest
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Pattern,
    
    [string]$TestString = "",
    
    [string]$File = "",
    
    [switch]$ShowMatches,
    
    [switch]$PerformanceTest
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Regex Pattern Tester" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Validate pattern
Write-Host "[1/3] Validating regex pattern..." -ForegroundColor Cyan
Write-Host "Pattern: $Pattern" -ForegroundColor Gray
Write-Host ""

try {
    $regex = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    Write-Host "  [OK] Pattern is valid" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Invalid regex pattern: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check for dangerous patterns
Write-Host "[2/3] Checking for performance issues..." -ForegroundColor Cyan
$dangerousPatterns = @{
    '(\.\*){2,}' = 'Multiple .* in sequence (catastrophic backtracking risk)'
    '\(\.\*\+' = '.* followed by + (catastrophic backtracking risk)'
    '\(\.\+\)\*' = '(.+)* pattern (catastrophic backtracking risk)'
    '\(\[.*\]\+\)\*' = '([...]+)* pattern (catastrophic backtracking risk)'
}

$hasDangerousPattern = $false
foreach ($dangerous in $dangerousPatterns.Keys) {
    if ($Pattern -match $dangerous) {
        Write-Host "  [WARNING] $($dangerousPatterns[$dangerous])" -ForegroundColor Yellow
        $hasDangerousPattern = $true
    }
}

if (-not $hasDangerousPattern) {
    Write-Host "  [OK] No obvious performance issues detected" -ForegroundColor Green
}
Write-Host ""

# Performance test
if ($PerformanceTest) {
    Write-Host "[3/3] Running performance test (1000 iterations)..." -ForegroundColor Cyan
    
    $testStrings = @(
        "user@example.com",
        "John Doe <user@example.com>",
        "noreply@mail.example.com",
        "This is a very long email subject with lots of text to test performance issues",
        "urgent: please respond immediately to this email about your account"
    )
    
    $totalTime = 0
    foreach ($testStr in $testStrings) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 1000; $i++) {
            $null = $regex.IsMatch($testStr)
        }
        $sw.Stop()
        $totalTime += $sw.ElapsedMilliseconds
    }
    
    $avgTime = $totalTime / ($testStrings.Count * 1000)
    
    Write-Host "  Average time per match: $([math]::Round($avgTime, 4)) ms" -ForegroundColor Cyan
    
    if ($avgTime -gt 1) {
        Write-Host "  [WARNING] Pattern is slow (>1ms per match)" -ForegroundColor Yellow
        Write-Host "  This may cause performance issues with large email volumes" -ForegroundColor Yellow
    } elseif ($avgTime -gt 0.1) {
        Write-Host "  [OK] Pattern performance is acceptable" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Pattern is fast" -ForegroundColor Green
    }
    Write-Host ""
}

# Test against strings
Write-Host "[3/3] Testing pattern matches..." -ForegroundColor Cyan

$testStrings = @()

if ($File) {
    if (Test-Path $File) {
        $testStrings = Get-Content $File
        Write-Host "  Loaded $($testStrings.Count) test strings from $File" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] File not found: $File" -ForegroundColor Red
        exit 1
    }
} elseif ($TestString) {
    $testStrings = @($TestString)
} else {
    # Interactive mode
    Write-Host "  Enter test strings (one per line, blank line to finish):" -ForegroundColor Yellow
    while ($true) {
        $input = Read-Host "  Test string"
        if ([string]::IsNullOrWhiteSpace($input)) { break }
        $testStrings += $input
    }
}

if ($testStrings.Count -eq 0) {
    Write-Host "  [WARNING] No test strings provided" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Testing $($testStrings.Count) string(s):" -ForegroundColor Cyan
Write-Host ""

$matchCount = 0
foreach ($str in $testStrings) {
    $match = $regex.Match($str)
    
    if ($match.Success) {
        $matchCount++
        Write-Host "  [MATCH] $str" -ForegroundColor Green
        
        if ($ShowMatches -and $match.Groups.Count -gt 1) {
            Write-Host "    Capture groups:" -ForegroundColor Gray
            for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                Write-Host "      Group ${i}: $($match.Groups[$i].Value)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  [NO MATCH] $str" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Summary: $matchCount of $($testStrings.Count) strings matched" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Provide usage suggestions
Write-Host "Usage Suggestions:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Add to rules.yaml:" -ForegroundColor Cyan
Write-Host "  - name: `"MyRule`"" -ForegroundColor Gray
Write-Host "    conditions:" -ForegroundColor Gray
Write-Host "      type: `"OR`"" -ForegroundColor Gray
Write-Host "      from: [`"$Pattern`"]" -ForegroundColor Gray
Write-Host ""
Write-Host "Add to rules_safe_senders.yaml:" -ForegroundColor Cyan
Write-Host "  safe_senders:" -ForegroundColor Gray
Write-Host "    - `"$Pattern`"" -ForegroundColor Gray
Write-Host ""
