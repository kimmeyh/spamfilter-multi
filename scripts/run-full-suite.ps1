<#
.SYNOPSIS
  Run the full Flutter test suite with the evidence a failed or hung run needs:
  commit charge over time, test-load failures, and a stall watchdog.
.DESCRIPTION
  F292 (Sprint 79). Twice in Sprint 78 a full `flutter test` run lost test files
  ("Failed to load ... Connection closed before test suite loaded", "did not
  complete") or stopped writing for 17 minutes, and nothing was recorded about
  the machine at the time, so the cause could not be named. This runner records:
    - boot time and page-file size (so a run is labeled before/after a reboot),
    - whether the DEV app is running,
    - Committed Bytes, Commit Limit and the flutter_tester count every 30 s,
    - test-RUNNER load failures only (the app's own "Failed to load credentials"
      log lines are excluded -- they counted 63 false hits in the first draft),
    - STALLED when the log does not grow for -StallMinutes; the run's
      flutter_tester processes are then stopped and the last test line kept.
  Promoted from a Sprint 79 scratch helper (used for three runs) per the
  CLAUDE.md promotion rule; named for the job, not the incident.
.PARAMETER Label
  A short label for the run (e.g. "postreboot-1"); used in file names.
.PARAMETER OutDir
  Where the log, the CSV and results.txt go. Default: %TEMP%\full-suite-runs.
.PARAMETER StallMinutes
  Minutes without log growth before the run is called STALLED. Default 10.
.PARAMETER Concurrency
  flutter test --concurrency. Default 4.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-full-suite.ps1 -Label postreboot-1
.NOTES
  Exit code: flutter test's exit code, 2 when STALLED, 3 when the self-test
  branch ran without -SelfTestStall (a runner defect), 4 when the job gave no
  exit code or no test progress line was written (no tests ran). One line is appended
  to <OutDir>\results.txt per run.
#>
param(
    [Parameter(Mandatory)][string]$Label,
    [string]$OutDir,
    [int]$StallMinutes = 10,
    [int]$Concurrency = 4,
    # Failure-path self-test: instead of flutter test, write one line and hang.
    # Expected: STALLED after -StallMinutes, exit 2.
    [switch]$SelfTestStall
)
$ErrorActionPreference = 'Continue'
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP 'full-suite-runs' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$appDir = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'mobile-app'
if (-not (Test-Path -LiteralPath (Join-Path $appDir 'pubspec.yaml'))) { throw "mobile-app not found at $appDir" }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $OutDir "suite_${Label}_$stamp.log"
$csv = Join-Path $OutDir "suite_${Label}_$stamp.csv"
$os = Get-CimInstance Win32_OperatingSystem
$pf = Get-CimInstance Win32_PageFileUsage | Select-Object -First 1
$dev = @(Get-Process MyEmailSpamFilter-Dev -ErrorAction SilentlyContinue).Count
"boot=$($os.LastBootUpTime) pagefileMB=$($pf.AllocatedBaseSize) devAppProcs=$dev label=$Label" | Set-Content -Encoding UTF8 $csv
'time,committedGB,limitGB,flutter_tester,logKB' | Add-Content -Encoding UTF8 $csv

$before = @(Get-Process flutter_tester -ErrorAction SilentlyContinue | ForEach-Object Id)
$job = Start-Job -ScriptBlock {
    param($appDir, $log, $conc, $selfTest)
    if ($selfTest) { '00:00 +0: self-test, now hanging' | Set-Content $log; Start-Sleep -Seconds 3600; return 0 }
    Set-Location $appDir
    flutter test "--concurrency=$conc" *> $log
    $LASTEXITCODE
} -ArgumentList @($appDir, $log, $Concurrency, $SelfTestStall.IsPresent)
# Sprint 79: the argument above was `[bool]$SelfTestStall`, which in argument
# mode is the STRING "[bool]False" -- non-empty, so truthy -- and every real
# run silently executed the self-test hang instead of flutter test. Guard:
# a run that did not ask for the self-test must never write the self-test line.

$start = Get-Date
$lastSize = -1
$lastGrowth = Get-Date
$stalled = $false
while ($job.State -eq 'Running') {
    Start-Sleep -Seconds 30
    # 7.7.1 review L-4: a failed counter read (for example localized counter
    # names) is written as n/a, never as a silent 0.00.
    $commit = 'n/a'; $limit = 'n/a'
    try {
        $c = (Get-Counter '\Memory\Committed Bytes', '\Memory\Commit Limit' -ErrorAction Stop).CounterSamples
        $commit = '{0:F2}' -f ($c[0].CookedValue / 1GB); $limit = '{0:F2}' -f ($c[1].CookedValue / 1GB)
    } catch { }
    $n = @(Get-Process flutter_tester -ErrorAction SilentlyContinue).Count
    $size = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
    '{0},{1},{2},{3},{4}' -f (Get-Date -Format 'HH:mm:ss'), $commit, $limit, $n, [int]($size / 1KB) |
        Add-Content -Encoding UTF8 $csv
    if ($size -ne $lastSize) { $lastSize = $size; $lastGrowth = Get-Date }
    elseif (((Get-Date) - $lastGrowth).TotalMinutes -ge $StallMinutes) {
        $stalled = $true
        # Stop only the testers this run started, not any that existed before.
        Get-Process flutter_tester -ErrorAction SilentlyContinue |
            Where-Object { $before -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
        Stop-Job $job
        break
    }
}
$jobState = $job.State
# A job that never started flutter writes no log; the reads below need one.
if (-not (Test-Path -LiteralPath $log)) { New-Item -ItemType File -Path $log | Out-Null }
$raw = if ($stalled) { $null } else { Receive-Job $job | Select-Object -Last 1 }
$code = if ($stalled) { 2 } elseif ("$raw" -match '^-?\d+$') { [int]"$raw" } else { 4 }
if (-not $SelfTestStall -and (Select-String -Path $log -Pattern 'self-test, now hanging' -Quiet -ErrorAction SilentlyContinue)) {
    Write-Output "RUNNER DEFECT: the self-test branch ran without -SelfTestStall; no tests were run."
    $code = 3
}
Remove-Job $job -Force

$mins = [int]((Get-Date) - $start).TotalMinutes
$summary = (Get-Content $log -Tail 400 -ErrorAction SilentlyContinue | Select-String -Pattern '^\d\d:\d\d \+\d+' | Select-Object -Last 1).Line
if (-not $summary) { $summary = '(no test progress line)' }
# Sprint 79 7.7.1 H-3: `[int]$null` is 0, so a job that never ran flutter
# (not on the job's PATH, a Failed/Stopped job, no output) read as exit=0 --
# a pass with no tests run. A real run has a job exit code AND a progress line.
if (-not $stalled -and $code -ne 3 -and
    ($jobState -ne 'Completed' -or $null -eq $raw -or "$raw" -notmatch '^-?\d+$' -or
     $summary -eq '(no test progress line)')) {
    Write-Output "RUNNER DEFECT: no exit code or no tests ran (job=$jobState, exit='$raw'); see $log"
    $code = 4
}
$loadFail = @(Select-String -Path $log -Pattern '^\d\d:\d\d .*: loading .*\[E\]|Failed to load "|did not complete|Connection closed before test suite loaded' -ErrorAction SilentlyContinue).Count
$peak = (Get-Content $csv | Select-Object -Skip 2 | ForEach-Object { $_.Split(',')[1] } |
    Where-Object { $_ -match '^\d+(\.\d+)?$' } | ForEach-Object { [double]$_ } | Measure-Object -Maximum).Maximum
if ($null -eq $peak) { $peak = 'n/a' }
$state = if ($stalled) { "STALLED(${StallMinutes}m)" } else { "exit=$code" }
$line = "RESULT label=$Label $state minutes=$mins loadFailures=$loadFail peakCommittedGB=$peak devAppProcs=$dev last='$($summary.Substring(0, [Math]::Min(80, $summary.Length)))'"
Write-Output $line
Write-Output "log: $log"
Write-Output "csv: $csv"
Add-Content -Path (Join-Path $OutDir 'results.txt') -Value $line -Encoding UTF8
exit $code
