# Fix header patterns in rules.yaml by adding 'from:.*' prefix
# This fixes the bug where header patterns don't match because they're missing the header key prefix

$rulesPath = "D:\Data\Harold\github\spamfilter-multi\rules.yaml"

Write-Host "Fixing header patterns in rules.yaml..." -ForegroundColor Yellow
Write-Host ""

# Read current rules
$content = Get-Content $rulesPath -Raw

# Count current patterns (those starting with '@(?:')
$matches = [regex]::Matches($content, "'(@\(\?\:[a-z0-9-]+\\.)\*")
$patternCount = $matches.Count
Write-Host "Found $patternCount header patterns to fix" -ForegroundColor White

# Create backup
$backupPath = $rulesPath + ".backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $rulesPath $backupPath
Write-Host "Backup saved to: $backupPath" -ForegroundColor Green

# Fix patterns: Add 'from:.*' prefix to all patterns starting with '@(?:'
# Pattern explanation:
#   - Match: '@ at start of quoted string (domain patterns)
#   - Replace with: 'from:.*@ (add header key prefix and wildcard)
$fixed = $content -replace "    - '(@\(\?\:[a-z0-9-]+\\\.)\*", "    - 'from:.*`$1*"

# Write fixed version
Set-Content -Path $rulesPath -Value $fixed -NoNewline

# Count fixed patterns
$fixedMatches = [regex]::Matches($fixed, "'from:\.\*@\(\?\:")
$fixedCount = $fixedMatches.Count

Write-Host ""
Write-Host "✓ Fixed $fixedCount patterns" -ForegroundColor Green
Write-Host "✓ Rules file updated: $rulesPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the changes: git diff rules.yaml" -ForegroundColor White
Write-Host "2. Test with the app to verify rules now match" -ForegroundColor White
Write-Host "3. If successful, commit the fix" -ForegroundColor White
