$t = Get-ScheduledTask -TaskName 'SpamFilterBackgroundScan' -ErrorAction SilentlyContinue
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName 'SpamFilterBackgroundScan'
    Write-Host "FOUND"
    Write-Host "State: $($t.State)"
    Write-Host "Enabled: $($t.Settings.Enabled)"
    Write-Host "Exe: $($t.Actions[0].Execute)"
    Write-Host "Args: $($t.Actions[0].Arguments)"
    Write-Host "RepInterval: $($t.Triggers[0].Repetition.Interval)"
    Write-Host "RepDuration: $($t.Triggers[0].Repetition.Duration)"
    Write-Host "LastRun: $($info.LastRunTime)"
    Write-Host "NextRun: $($info.NextRunTime)"
    Write-Host "LastResult: $($info.LastTaskResult)"
} else {
    Write-Host "NOT FOUND"
}
