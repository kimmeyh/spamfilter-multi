#!/usr/bin/env pwsh
# Phase 2.0 Testing Script
# Runs all tests to verify Phase 2.0 implementation and Phase 1 regression

param(
    [ValidateSet('all', 'phase1', 'phase2', 'unit', 'integration', 'coverage')]
    [string]$TestType = 'all',
    [switch]$Verbose
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Phase 2.0 Testing - Mobile Spam Filter            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Navigate to mobile-app directory
$projectPath = Join-Path (Get-Location) "mobile-app"
if (-not (Test-Path $projectPath)) {
    Write-Host "Error: mobile-app directory not found" -ForegroundColor Red
    exit 1
}

Push-Location $projectPath

Write-Host "📦 Checking dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null

Write-Host "🔍 Running code analysis..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Code analysis found issues" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

switch ($TestType) {
    'phase1' {
        Write-Host "🧪 Running Phase 1 Regression Tests..." -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Test 1: PatternCompiler (7 tests expected)" -ForegroundColor Green
        flutter test test/unit/pattern_compiler_test.dart --verbose:$Verbose
        
        Write-Host ""
        Write-Host "Test 2: SafeSenderList (8 tests expected)" -ForegroundColor Green
        flutter test test/unit/safe_sender_list_test.dart --verbose:$Verbose
        
        Write-Host ""
        Write-Host "Test 3: YAML Loading (3 passing + 1 known failure expected)" -ForegroundColor Green
        flutter test test/integration/yaml_loading_test.dart --verbose:$Verbose
        
        Write-Host ""
        Write-Host "Test 4: End-to-End Workflow (4 tests expected)" -ForegroundColor Green
        flutter test test/integration/end_to_end_workflow_test.dart --verbose:$Verbose
    }
    
    'phase2' {
        Write-Host "🧪 Running Phase 2.0 New Tests..." -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Test 1: AppPaths (7 tests expected)" -ForegroundColor Green
        flutter test test/unit/app_paths_test.dart --verbose:$Verbose
        
        Write-Host ""
        Write-Host "Test 2: SecureCredentialsStore (4 tests expected)" -ForegroundColor Green
        flutter test test/unit/secure_credentials_store_test.dart --verbose:$Verbose
        
        Write-Host ""
        Write-Host "Test 3: EmailScanProvider (12 tests expected)" -ForegroundColor Green
        flutter test test/unit/email_scan_provider_test.dart --verbose:$Verbose
    }
    
    'unit' {
        Write-Host "🧪 Running All Unit Tests..." -ForegroundColor Cyan
        flutter test test/unit/ --verbose:$Verbose
    }
    
    'integration' {
        Write-Host "🧪 Running All Integration Tests..." -ForegroundColor Cyan
        flutter test test/integration/ --verbose:$Verbose
    }
    
    'coverage' {
        Write-Host "📊 Running Tests with Coverage..." -ForegroundColor Cyan
        flutter test --coverage
        Write-Host ""
        Write-Host "Coverage report generated at: coverage/lcov.info" -ForegroundColor Green
    }
    
    'all' {
        Write-Host "🧪 Running All Tests (Phase 1 + Phase 2.0)..." -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "━━ PHASE 1 REGRESSION TESTS ━━" -ForegroundColor Green
        Write-Host ""
        flutter test test/unit/pattern_compiler_test.dart
        flutter test test/unit/safe_sender_list_test.dart
        flutter test test/integration/yaml_loading_test.dart
        flutter test test/integration/end_to_end_workflow_test.dart
        
        Write-Host ""
        Write-Host "━━ PHASE 2.0 NEW FEATURE TESTS ━━" -ForegroundColor Green
        Write-Host ""
        flutter test test/unit/app_paths_test.dart
        flutter test test/unit/secure_credentials_store_test.dart
        flutter test test/unit/email_scan_provider_test.dart
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Testing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Phase 1 (existing):  ~27 tests (should all still pass)" -ForegroundColor White
Write-Host "  Phase 2.0 (new):     23 tests (platform storage & state management)" -ForegroundColor White
Write-Host ""

Pop-Location
