<#
.SYNOPSIS
    Setup Claude Code MCP servers for spam filter development

.DESCRIPTION
    Installs and configures MCP (Model Context Protocol) servers to enhance
    Claude Code functionality for Flutter development, GitHub integration,
    YAML validation, and regex testing.

.PARAMETER InstallGitHub
    Install GitHub MCP server for issue tracking and PR management

.PARAMETER InstallFlutter
    Install Flutter MCP server for widget analysis and state management

.PARAMETER InstallYaml
    Install YAML validation MCP server

.PARAMETER InstallRegex
    Install Regex testing/validation MCP server

.PARAMETER InstallAll
    Install all recommended MCP servers

.EXAMPLE
    .\setup-claude-mcp.ps1 -InstallAll
    .\setup-claude-mcp.ps1 -InstallGitHub -InstallFlutter
#>

param(
    [switch]$InstallGitHub,
    [switch]$InstallFlutter,
    [switch]$InstallYaml,
    [switch]$InstallRegex,
    [switch]$InstallAll
)

$ErrorActionPreference = 'Stop'

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Claude Code MCP Server Setup" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Determine which servers to install
if ($InstallAll) {
    $InstallGitHub = $true
    $InstallFlutter = $true
    $InstallYaml = $true
    $InstallRegex = $true
}

if (-not ($InstallGitHub -or $InstallFlutter -or $InstallYaml -or $InstallRegex)) {
    Write-Host "[ERROR]: No MCP servers selected. Use -InstallAll or specify individual servers." -ForegroundColor Red
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\setup-claude-mcp.ps1 -InstallAll"
    Write-Host "  .\setup-claude-mcp.ps1 -InstallGitHub -InstallFlutter"
    exit 1
}

# Check if Node.js/npm is installed (required for most MCP servers)
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Cyan
try {
    $nodeVersion = & node --version 2>&1
    Write-Host "  [OK] Node.js installed: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Node.js not found. Install from: https://nodejs.org/" -ForegroundColor Red
    Write-Host "  MCP servers require Node.js/npm to run." -ForegroundColor Yellow
    exit 1
}

try {
    $npmVersion = & npm --version 2>&1
    Write-Host "  [OK] npm installed: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] npm not found. Reinstall Node.js." -ForegroundColor Red
    exit 1
}

# Create Claude config directory if it doesn't exist
$claudeConfigDir = Join-Path $env:USERPROFILE ".claude"
$configFile = Join-Path $claudeConfigDir "config.json"

if (-not (Test-Path $claudeConfigDir)) {
    Write-Host "[2/5] Creating Claude config directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
    Write-Host "  [OK] Created $claudeConfigDir" -ForegroundColor Green
} else {
    Write-Host "[2/5] Claude config directory exists" -ForegroundColor Green
}

# Load existing config or create new one
Write-Host "[3/5] Loading MCP configuration..." -ForegroundColor Cyan
$mcpConfig = @{
    mcpServers = @{}
}

if (Test-Path $configFile) {
    try {
        $existingConfig = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($existingConfig.mcpServers) {
            Write-Host "  [INFO] Found existing MCP configuration" -ForegroundColor Yellow
            $mcpConfig.mcpServers = $existingConfig.mcpServers
        }
    } catch {
        Write-Host "  [WARNING] Could not parse existing config, creating new one" -ForegroundColor Yellow
    }
}

# Install GitHub MCP Server
if ($InstallGitHub) {
    Write-Host "[4/5] Installing GitHub MCP Server..." -ForegroundColor Cyan
    
    # Check if GitHub token exists
    $githubToken = $env:GITHUB_TOKEN
    if (-not $githubToken) {
        Write-Host "  [WARNING] GITHUB_TOKEN not set in environment" -ForegroundColor Yellow
        Write-Host "  You'll need to create a Personal Access Token:" -ForegroundColor Gray
        Write-Host "    1. Go to: https://github.com/settings/tokens" -ForegroundColor Gray
        Write-Host "    2. Generate new token (classic)" -ForegroundColor Gray
        Write-Host "    3. Permissions needed: repo, issues, pull_requests" -ForegroundColor Gray
        Write-Host "    4. Set environment variable: `$env:GITHUB_TOKEN = 'your-token'" -ForegroundColor Gray
        Write-Host ""
        $githubToken = "YOUR_GITHUB_TOKEN_HERE"
    }
    
    $mcpConfig.mcpServers.github = @{
        command = "npx"
        args = @("-y", "@modelcontextprotocol/server-github")
        env = @{
            GITHUB_TOKEN = $githubToken
        }
    }
    Write-Host "  [OK] GitHub MCP server configured" -ForegroundColor Green
}

# Install Flutter MCP Server (if available)
if ($InstallFlutter) {
    Write-Host "[4/5] Checking for Flutter MCP Server..." -ForegroundColor Cyan
    
    # Note: As of now, there may not be an official Flutter MCP server
    # This is a placeholder for when one becomes available
    Write-Host "  [INFO] Flutter-specific MCP server not yet available" -ForegroundColor Yellow
    Write-Host "  [INFO] Using Serena MCP for code analysis (already active)" -ForegroundColor Cyan
    Write-Host "  [INFO] Recommended: Use 'flutter analyze' and 'flutter test' directly" -ForegroundColor Gray
}

# Install YAML MCP Server
if ($InstallYaml) {
    Write-Host "[4/5] Installing YAML Validation MCP..." -ForegroundColor Cyan
    
    # Using a generic file-system MCP that can validate YAML
    # Note: Specific YAML MCP may not exist yet
    Write-Host "  [INFO] Dedicated YAML MCP not available" -ForegroundColor Yellow
    Write-Host "  [INFO] Creating custom YAML validation script instead..." -ForegroundColor Cyan
    
    # We'll create this in step 2 (custom validation scripts)
}

# Install Regex MCP Server
if ($InstallRegex) {
    Write-Host "[4/5] Installing Regex Testing MCP..." -ForegroundColor Cyan
    
    # Note: May need custom implementation
    Write-Host "  [INFO] Dedicated Regex MCP not available" -ForegroundColor Yellow
    Write-Host "  [INFO] Creating custom regex testing script instead..." -ForegroundColor Cyan
    
    # We'll create this in step 2 (custom validation scripts)
}

# Write config file
Write-Host "[5/5] Writing MCP configuration..." -ForegroundColor Cyan
$mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
Write-Host "  [OK] Configuration saved to: $configFile" -ForegroundColor Green

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "MCP Setup Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""

# Show next steps
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""

if ($InstallGitHub) {
    Write-Host "GitHub MCP:" -ForegroundColor Cyan
    if ($githubToken -eq "YOUR_GITHUB_TOKEN_HERE") {
        Write-Host "  1. Create GitHub Personal Access Token" -ForegroundColor Gray
        Write-Host "  2. Set environment variable:" -ForegroundColor Gray
        Write-Host "     `$env:GITHUB_TOKEN = 'ghp_your_token_here'" -ForegroundColor Gray
        Write-Host "  3. Update config.json with real token" -ForegroundColor Gray
    } else {
        Write-Host "  [OK] GitHub MCP ready to use!" -ForegroundColor Green
    }
    Write-Host ""
}

Write-Host "Restart Claude Code to load new MCP servers" -ForegroundColor Yellow
Write-Host ""
Write-Host "Config file location: $configFile" -ForegroundColor Gray
Write-Host ""
