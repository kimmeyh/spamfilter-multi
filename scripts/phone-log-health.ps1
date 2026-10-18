<#
.SYNOPSIS
Summarize background-scan health from the app's diagnostic logs (diag_*.log).

.DESCRIPTION
Sprint 78 retro IMP-2 (Harold, 2026-10-13). The Fold logs showed AOL scanned
about twice per interval (558 scans in 3.4 days, MV-7), and an F277 battery run
with three accounts on instead of one -- both visible in logs that had already
been pulled, and both found only when Harold asked a question. This script
reads those logs and prints, per account:
  - background starts, and outcomes (completed / error / refused / other)
  - starts that never reached an outcome (unfinished)
  - "skip" lines, and the worker triggers seen (doze-alarm, periodic, test, ...)
  - completed scans per hour and the median gap between starts
and a FLAG line for each problem:
  - more scans per hour than the interval allows (x1.5): double scheduling
  - unfinished scans, errors
  - with -SingleAccount: more than one account scanning in the background

pull-phone-screenshots.ps1 runs it on the diagnostic logs of the pull window.
It reads files only; it changes nothing.

.PARAMETER Path
One or more diag_*.log files (wildcards allowed).

.PARAMETER IntervalMinutes
The FALLBACK background interval (default 15, the closed-test setting). Each
account's own interval is read from its worker skip lines
("skipped: ... (interval 240m; doze alarm)") when the log has one, and that
wins. (Sprint 79: one interval for all accounts missed Yahoo at 6.2 scans/hour
on 15 minutes while AOL was on 5, and raised a false flag on AOL at 15.)

.PARAMETER Since
Only lines at or after this time (for one overnight run, for example).

.PARAMETER SingleAccount
Flag when more than one account scanned in the background (F277 runs).

.PARAMETER SelfTest
Run against built-in sample logs and assert the flags; exit 0 on pass, 1 on fail.

.EXAMPLE
.\phone-log-health.ps1 -Path ..\validation-screenshots\sprint-78\diag_v0.18.0_2026-10-13.log
.\phone-log-health.ps1 -Path ..\validation-screenshots\sprint-78\diag_*.log -Since '2026-10-13 01:00' -SingleAccount
.\phone-log-health.ps1 -SelfTest
#>
param(
    [string[]]$Path,
    [int]$IntervalMinutes = 15,
    [datetime]$Since,
    [switch]$SingleAccount,
    [switch]$SelfTest
)

$scanRx    = '^\[(?<ts>[0-9T:.\-]+)\] \[SCAN\] \[scan/background\] (?<acct>\S+) (?<ev>start|outcome|skip) --\s*(?<rest>.*)$'
$triggerRx = '^\[(?<ts>[0-9T:.\-]+)\] \[SCAN\] \[worker/android\] start (?<acct>\S+) trigger=(?<trig>[a-z-]+)'
$intervalRx = '\[worker/android\] account (?<acct>\S+) skipped: .*\(interval (?<min>\d+)m'

function Get-Health {
    param([string[]]$Lines, [int]$Interval, $From, [switch]$OneAccount)
    $acc = @{}
    $intervals = @{}
    $recognized = 0
    foreach ($line in $Lines) {
        $iv = [regex]::Match($line, $intervalRx)
        if ($iv.Success) {
            $ia = $iv.Groups['acct'].Value
            if (-not $intervals.ContainsKey($ia)) { $intervals[$ia] = New-Object System.Collections.Generic.SortedSet[int] }
            [void]$intervals[$ia].Add([int]$iv.Groups['min'].Value)
        }
        $m = [regex]::Match($line, $scanRx)
        $t = [regex]::Match($line, $triggerRx)
        if (-not $m.Success -and -not $t.Success) { continue }
        $recognized++
        $hit = if ($m.Success) { $m } else { $t }
        $ts = [datetime]::Parse($hit.Groups['ts'].Value, [Globalization.CultureInfo]::InvariantCulture)
        if ($From -and $ts -lt $From) { continue }
        $a = $hit.Groups['acct'].Value
        if (-not $acc.ContainsKey($a)) {
            # Open is a STACK of start times. Two isolates can scan one account at
            # once; the second is refused at its claim and ends FIRST, so the scans
            # nest and an outcome closes the NEWEST open start. A start that never
            # finishes stays at the bottom with its own timestamp. (A FIFO was tried
            # first: one real unfinished scan made every later pairing lag, and the
            # report then named the last scans of the log, all of which had finished.)
            $acc[$a] = [ordered]@{ Starts = New-Object System.Collections.ArrayList; Outcomes = @{}; Skips = 0;
                                   Triggers = @{}; Unfinished = 0; UnfinishedAt = New-Object System.Collections.ArrayList;
                                   Open = New-Object System.Collections.Stack; Last = $ts }
        }
        $r = $acc[$a]
        if ($ts -gt $r.Last) { $r.Last = $ts }
        if ($t.Success) {
            $k = $t.Groups['trig'].Value
            $r.Triggers[$k] = 1 + [int]$r.Triggers[$k]
            continue
        }
        switch ($m.Groups['ev'].Value) {
            'start' {
                [void]$r.Starts.Add($ts); $r.Open.Push($ts)
            }
            'outcome' {
                $kind = ($m.Groups['rest'].Value -split '\s+')[0]
                $r.Outcomes[$kind] = 1 + [int]$r.Outcomes[$kind]
                if ($r.Open.Count -gt 0) { [void]$r.Open.Pop() }
            }
            'skip' { $r.Skips++ }
        }
    }

    $logEnd = ($acc.Values | ForEach-Object { $_.Last } | Measure-Object -Maximum).Maximum
    $out = New-Object System.Collections.ArrayList
    $flags = New-Object System.Collections.ArrayList
    $scanning = 0
    foreach ($a in ($acc.Keys | Sort-Object)) {
        $r = $acc[$a]
        # A start still unpaired more than 30 minutes before the log ends never finished.
        foreach ($o in $r.Open) {
            if (($logEnd - $o).TotalMinutes -gt 30) { $r.Unfinished++; [void]$r.UnfinishedAt.Add($o) }
        }
        $n = $r.Starts.Count
        if ($n -gt 0) { $scanning++ }
        $completed = [int]$r.Outcomes['completed']
        $errors = [int]$r.Outcomes['error']
        $hours = 0
        $median = $null
        if ($n -ge 2) {
            $hours = ($r.Starts[$n - 1] - $r.Starts[0]).TotalHours
            $gaps = @(for ($i = 1; $i -lt $n; $i++) { ($r.Starts[$i] - $r.Starts[$i - 1]).TotalMinutes }) | Sort-Object
            $median = $gaps[[int][math]::Floor($gaps.Count / 2)]
        }
        # N scans across a span hold N-1 intervals: two scans 240 minutes apart are
        # 0.25/hour, not 0.5 (Sprint 79 false flag on a 240-minute account).
        $perHour = if ($hours -ge 1 -and $completed -ge 2) { [math]::Round(($completed - 1) / $hours, 2) } else { $null }
        $outText = ($r.Outcomes.Keys | Sort-Object | ForEach-Object { "$_=$($r.Outcomes[$_])" }) -join ' '
        $trigText = ($r.Triggers.Keys | Sort-Object | ForEach-Object { "$_=$($r.Triggers[$_])" }) -join ' '
        # The account's own interval (from its skip lines) wins over the fallback.
        # When the interval changed inside the window (Gmail 5m -> 240m on
        # 2026-10-13), the SHORTEST one is used: the rate check must not flag a
        # window that was legitimately faster for part of its length.
        $own = $intervals.ContainsKey($a)
        $iv = if ($own) { $intervals[$a].Min } else { $Interval }
        $ivText = if (-not $own) { "interval ${iv}m (assumed)" }
                  elseif ($intervals[$a].Count -gt 1) { "interval $($intervals[$a] -join '/')m (log, changed; checked at ${iv}m)" }
                  else { "interval ${iv}m (log)" }
        [void]$out.Add(('{0}: starts={1} {2} unfinished={3} skips={4} | triggers {5} | {6}/hour, median gap {7} min | {8}' -f
            $a, $n, $outText, $r.Unfinished, $r.Skips, $(if ($trigText) { $trigText } else { 'none' }),
            $(if ($null -ne $perHour) { $perHour } else { '-' }),
            $(if ($null -ne $median) { [math]::Round($median, 1) } else { '-' }), $ivText))
        $allowed = 1.5 * 60 / $iv
        if ($null -ne $perHour -and $perHour -gt $allowed) {
            [void]$flags.Add(('FLAG: {0} completed {1} scans/hour; a {2}-minute interval allows about {3}. Double scheduling? (MV-7 class)' -f
                $a, $perHour, $iv, [math]::Round(60 / $iv, 1)))
        }
        if ($r.Unfinished -gt 0) {
            $at = ($r.UnfinishedAt | Sort-Object | Select-Object -First 3 | ForEach-Object { $_.ToString('MM-dd HH:mm:ss') }) -join ', '
            [void]$flags.Add("FLAG: $a has $($r.Unfinished) scan(s) that started and never reached an outcome (first: $at).")
        }
        if ($errors -gt 0) { [void]$flags.Add("FLAG: $a has $errors scan error(s).") }
    }
    if ($OneAccount -and $scanning -gt 1) {
        [void]$flags.Add("FLAG: $scanning accounts scanned in the background; a single-account run needs exactly one.")
    }
    [pscustomobject]@{ Lines = $out; Flags = $flags; Accounts = $scanning; Recognized = $recognized }
}

if ($SelfTest) {
    $base = [datetime]'2026-10-13T01:00:00'
    $sample = New-Object System.Collections.ArrayList
    function Add-Scan($list, $time, $acct, $trigger, $outcome) {
        $ts = $time.ToString('yyyy-MM-ddTHH:mm:ss.ffffff')
        [void]$list.Add("[$ts] [SCAN] [worker/android] start $acct trigger=$trigger")
        [void]$list.Add("[$ts] [SCAN] [scan/background] $acct start -- platform=aol folders=3 daysBack=1")
        if ($outcome) { [void]$list.Add("[$ts] [SCAN] [scan/background] $acct outcome -- $outcome found=1") }
    }
    # double@x: scanned by BOTH triggers, about every 7.5 minutes for 3 hours.
    for ($i = 0; $i -lt 24; $i++) { Add-Scan $sample $base.AddMinutes($i * 7.5) 'd***@x.com' $(if ($i % 2) { 'periodic' } else { 'doze-alarm' }) 'completed' }
    # clean@x: every 15 minutes, one error.
    for ($i = 0; $i -lt 12; $i++) { Add-Scan $sample $base.AddMinutes($i * 15 + 1) 'c***@x.com' 'periodic' $(if ($i -eq 3) { 'error IEa: test' } else { 'completed' }) }
    # Unfinished: one start with no outcome, two hours before the log ends.
    Add-Scan $sample $base.AddMinutes(30) 'u***@x.com' 'periodic' $null
    Add-Scan $sample $base.AddMinutes(45) 'u***@x.com' 'periodic' 'completed'
    $lines = $sample | Sort-Object

    $failures = @()
    $h = Get-Health -Lines $lines -Interval 15
    $f = $h.Flags -join "`n"
    if ($f -notmatch 'd\*\*\*@x\.com completed [0-9.]+ scans/hour') { $failures += 'double scheduling not flagged' }
    if ($f -match 'c\*\*\*@x\.com completed') { $failures += 'clean 15-minute account flagged as double' }
    if ($f -notmatch 'c\*\*\*@x\.com has 1 scan error') { $failures += 'error not flagged' }
    if ($f -notmatch 'u\*\*\*@x\.com has 1 scan\(s\) that started and never') { $failures += 'unfinished scan not flagged' }
    if ($f -match 'accounts scanned in the background') { $failures += 'single-account flag raised without -SingleAccount' }
    $h1 = Get-Health -Lines $lines -Interval 15 -OneAccount
    if (($h1.Flags -join "`n") -notmatch '3 accounts scanned in the background') { $failures += 'multi-account run not flagged' }
    $clean = $lines | Where-Object { $_ -match 'c\*\*\*@x\.com' } | ForEach-Object { $_ -replace 'error IEa: test', 'completed' }
    $h2 = Get-Health -Lines $clean -Interval 15 -OneAccount
    if ($h2.Flags.Count -ne 0) { $failures += "clean single-account log raised $($h2.Flags.Count) flag(s): $($h2.Flags -join '; ')" }
    # Two scans of one account overlap: the second is refused, then the first completes.
    $o = @('[2026-10-13T02:00:00.000000] [SCAN] [scan/background] o***@x.com start -- a',
           '[2026-10-13T02:00:01.000000] [SCAN] [scan/background] o***@x.com start -- b',
           '[2026-10-13T02:00:02.000000] [SCAN] [scan/background] o***@x.com outcome -- refused',
           '[2026-10-13T02:00:09.000000] [SCAN] [scan/background] o***@x.com outcome -- completed found=1',
           '[2026-10-13T03:00:00.000000] [SCAN] [scan/background] o***@x.com start -- c',
           '[2026-10-13T03:00:05.000000] [SCAN] [scan/background] o***@x.com outcome -- completed found=0')
    $h3 = Get-Health -Lines $o -Interval 15
    if (($h3.Flags -join "`n") -match 'never reached') { $failures += 'overlapping refused scan counted as unfinished' }
    # Unparseable input is counted, so the caller can refuse to say "No flags.".
    $h4 = Get-Health -Lines @('garbage line', '[2026-10-13T02:00:00.000000] [SCAN] [scan/renamed] x start -- a') -Interval 15
    if ($h4.Recognized -ne 0) { $failures += "unparseable lines counted as recognized ($($h4.Recognized))" }
    if ($h.Recognized -lt 1) { $failures += 'sample scan lines not counted as recognized' }
    # Per-account interval from skip lines (Sprint 79). f@x runs every 6 minutes
    # and its log says 5m: healthy, even with a 15-minute fallback. y@x runs every
    # 7.5 minutes and its log says 15m: double, even with a 5-minute fallback.
    $pa = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt 30; $i++) { Add-Scan $pa $base.AddMinutes($i * 6) 'f***@x.com' 'doze-alarm' 'completed' }
    for ($i = 0; $i -lt 24; $i++) { Add-Scan $pa $base.AddMinutes($i * 7.5) 'y***@x.com' 'periodic' 'completed' }
    [void]$pa.Add('[2026-10-13T01:01:00.000000] [SCAN] [worker/android] account f***@x.com skipped: a scan started 60s ago (interval 5m; doze alarm)')
    [void]$pa.Add('[2026-10-13T01:02:00.000000] [SCAN] [worker/android] account y***@x.com skipped: a scan started 120s ago (interval 15m; doze alarm)')
    $pl = $pa | Sort-Object
    $f5 = (Get-Health -Lines $pl -Interval 15).Flags -join "`n"
    if ($f5 -match 'f\*\*\*@x\.com completed') { $failures += 'account logged at 5m flagged against the 15m fallback' }
    $f6 = (Get-Health -Lines $pl -Interval 5).Flags -join "`n"
    if ($f6 -notmatch 'y\*\*\*@x\.com completed [0-9.]+ scans/hour; a 15-minute') { $failures += 'account logged at 15m not flagged under a 5m fallback' }
    # g@x: exactly two scans, one 240-minute interval apart, its log says 240m.
    $g = New-Object System.Collections.ArrayList
    Add-Scan $g $base 'g***@x.com' 'periodic' 'completed'
    Add-Scan $g $base.AddMinutes(240) 'g***@x.com' 'periodic' 'completed'
    [void]$g.Add('[2026-10-13T01:15:00.000000] [SCAN] [worker/android] account g***@x.com skipped: a scan started 900s ago (interval 240m; doze alarm)')
    $f7 = (Get-Health -Lines ($g | Sort-Object) -Interval 15).Flags -join "`n"
    if ($f7 -match 'g\*\*\*@x\.com completed') { $failures += 'two scans one 240m interval apart flagged as double' }
    # h@x: every 5 minutes for 2 hours (log says 5m), then the interval became
    # 240m. One window holds both: no flag.
    $hh = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt 24; $i++) { Add-Scan $hh $base.AddMinutes($i * 5) 'h***@x.com' 'doze-alarm' 'completed' }
    Add-Scan $hh $base.AddMinutes(360) 'h***@x.com' 'periodic' 'completed'
    [void]$hh.Add('[2026-10-13T01:01:00.000000] [SCAN] [worker/android] account h***@x.com skipped: a scan started 60s ago (interval 5m; doze alarm)')
    [void]$hh.Add('[2026-10-13T07:15:00.000000] [SCAN] [worker/android] account h***@x.com skipped: a scan started 900s ago (interval 240m; doze alarm)')
    $f8 = (Get-Health -Lines ($hh | Sort-Object) -Interval 15).Flags -join "`n"
    if ($f8 -match 'h\*\*\*@x\.com completed') { $failures += 'interval changed 5m -> 240m inside the window flagged as double' }
    if ($failures.Count -eq 0) { 'SELFTEST PASS (14 checks)'; exit 0 }
    'SELFTEST FAIL:'; $failures | ForEach-Object { "  - $_" }; exit 1
}

if (-not $Path) { 'Give -Path <diag_*.log> or -SelfTest.'; exit 2 }
# "-Path a,b" through powershell -File arrives as ONE string "a,b"; split it.
# Sprint 79 7.7.1 L-2: a -Path entry that matches nothing is named, and no
# match at all is an error, never "No flags" over half the data or none.
$files = @($Path | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object {
    $hit = @(Get-ChildItem -Path $_ -File -ErrorAction SilentlyContinue)
    if ($hit.Count -eq 0) { "WARNING: -Path '$_' matched no file; it is NOT in this check." }
    $hit
}) | Sort-Object Name -Unique
$missing = @($files | Where-Object { $_ -is [string] })
$missing
$files = @($files | Where-Object { $_ -isnot [string] })
if ($files.Count -eq 0) { 'No diagnostic logs found. Health NOT checked.'; exit 4 }
$all = foreach ($fi in $files) { Get-Content -LiteralPath $fi.FullName }
$res = Get-Health -Lines $all -Interval $IntervalMinutes -From $Since -OneAccount:$SingleAccount
"--- background scan health ($($files.Count) log(s), interval $IntervalMinutes min$(if ($Since) { ", since $Since" })) ---"
$res.Lines
# 7.7.1 silent-failure M-1: unparseable input must never read as healthy. If
# the logs have lines but none is a scan line, the format changed (a renamed
# tag) or no background scan ran -- either way "No flags." would be a lie.
if (@($all).Count -gt 0 -and $res.Recognized -eq 0) {
    "WARNING: 0 scan lines recognized in $($files.Count) log(s) -- log format changed, or no background scan ran. Health NOT checked."
    exit 3
}
if ($res.Flags.Count -eq 0) { 'No flags.' } else { $res.Flags }
