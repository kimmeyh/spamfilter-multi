<#
.SYNOPSIS
    Quick install script for custom Email Rule Tester MCP server

.DESCRIPTION
    Installs npm dependencies and configures Claude Code to use the custom
    Email Rule Tester MCP server.

.EXAMPLE
    .\install-custom-mcp.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Email Rule Tester MCP Installation" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Get repository root
$repoRoot = Split-Path -Parent $PSScriptRoot
$mcpDir = Join-Path $PSScriptRoot "email-rule-tester-mcp"
$serverPath = Join-Path $mcpDir "server.js"

# Check Node.js
Write-Host "[1/4] Checking Node.js installation..." -ForegroundColor Cyan
try {
    $nodeVersion = & node --version 2>&1
    Write-Host "  [OK] Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Node.js not found!" -ForegroundColor Red
    Write-Host "  Install from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Install npm dependencies
Write-Host "[2/4] Installing npm dependencies..." -ForegroundColor Cyan
Push-Location $mcpDir
try {
    & npm install
    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed"
    }
    Write-Host "  [OK] Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] npm install failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

# Test server
Write-Host "[3/4] Testing MCP server..." -ForegroundColor Cyan
$testJob = Start-Job -ScriptBlock {
    param($serverPath)
    & node $serverPath 2>&1
} -ArgumentList $serverPath

Start-Sleep -Seconds 2
$jobOutput = Receive-Job $testJob
Stop-Job $testJob
Remove-Job $testJob

if ($jobOutput -match "Email Rule Tester MCP server running") {
    Write-Host "  [OK] Server starts successfully" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Server may have issues:" -ForegroundColor Yellow
    Write-Host "  $jobOutput" -ForegroundColor Gray
}

# Configure Claude Code
Write-Host "[4/4] Configuring Claude Code..." -ForegroundColor Cyan
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$configFile = Join-Path $claudeDir "config.json"

if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

$config = @{
    mcpServers = @{
        "email-rule-tester" = @{
            command = "node"
            args = @($serverPath)
        }
    }
}

if (Test-Path $configFile) {
    try {
        $existing = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($existing.mcpServers) {
            $existing.mcpServers.'email-rule-tester' = $config.mcpServers.'email-rule-tester'
            $config = $existing
        }
    } catch {
        Write-Host "  [WARNING] Could not parse existing config, will overwrite" -ForegroundColor Yellow
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
Write-Host "  [OK] Configuration saved to: $configFile" -ForegroundColor Green

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Restart Claude Code" -ForegroundColor Gray
Write-Host "  2. Ask Claude: 'What MCP tools are available?'" -ForegroundColor Gray
Write-Host "  3. Test: 'Validate my rules.yaml file'" -ForegroundColor Gray
Write-Host ""
Write-Host "MCP Server Location:" -ForegroundColor Cyan
Write-Host "  $serverPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Claude Config:" -ForegroundColor Cyan
Write-Host "  $configFile" -ForegroundColor Gray
Write-Host ""
