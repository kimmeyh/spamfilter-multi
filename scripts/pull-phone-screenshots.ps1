<#
.SYNOPSIS
Pull this app's validation evidence from a phone over MTP: its screenshots,
diagnostic logs and CSV exports, and nothing else.

.DESCRIPTION
Copies recent files from a connected phone (S24+, Fold8, etc.) over MTP
(no adb; USB debugging is blocked by company policy). By default, saves into
a temporary folder (%TEMP%\phone-screenshots). When `-Sprint N` is given and `-Dest` is not
provided, saves to `validation-screenshots/sprint-NN/` instead, organizing
Manual Validation evidence by sprint.

A plain run (no -Folder, no -Pattern) collects ONLY (Sprint 77, Harold):
  - DCIM: Screenshot_<yyyyMMdd>_<HHmmss>.png with no suffix. Screenshots of
    other apps carry the app's name (Screenshot_..._Instagram.png) and are
    skipped. Exception: Screenshot_..._One UI Home.png IS collected -- that is
    how Samsung names a notification-shade capture (Sprint 78).
  - Documents and its subfolders: the app's diagnostic logs (diag_*.log) and
    its .csv exports. Local copies of these are refreshed, because they keep
    growing on the phone.
Company device-management logs and other apps' screenshots are never copied.
Note: the Documents rule copies every .csv under Documents, which can include
another app's CSV files; the destination is gitignored, so none can be committed.

Uses the Windows Shell.Application COM object to access MTP devices, avoiding
adb and driver dependencies.

.PARAMETER Dest
Destination directory. Defaults to %TEMP%\phone-screenshots.
If `-Sprint` is given and `-Dest` is not, the
destination is set to `validation-screenshots/sprint-NN/`.

.PARAMETER Sprint
Sprint number (e.g., 75) for organizing validation evidence. When provided
(and `-Dest` is not), sets the destination to `<repo>/validation-screenshots/sprint-NN/`.
Two-digit format is used (e.g., sprint-75).

.PARAMETER Pattern
Custom run only: file name REGEX to match. Giving -Pattern or -Folder replaces
the default set with ONE source (Folder default 'DCIM', Pattern default the
exact screenshot name).

.PARAMETER Folder
Custom run only: folder under the phone's "Internal storage", slash-separated.
Note: 'Android/data/<package>' is NOT visible over MTP on current Android, so
the app writes its logs and exports to Documents instead.

.PARAMETER Recurse
Custom run only: search subfolders of -Folder as well.

.PARAMETER Overwrite
Copy even when a file of the same name is already in -Dest. The default run
always refreshes logs and CSVs; this switch also refreshes screenshots.

.PARAMETER DeviceName
Device name filter to match among connected phones (default: 'S24|Fold|Galaxy|Harold').
Matches any phone name containing one of these substrings. Used to disambiguate
when multiple phones are plugged in.

.PARAMETER Days
Only copy files dated within this many days (default: 2), using the date in
the file NAME (Screenshot_yyyyMMdd_..., or yyyy-MM-dd in a log or CSV name).
A file with no date in its name is always copied.

.PARAMETER ListOnly
If specified, only list the destination and exit without copying files.

.EXAMPLE
# Collect screenshots, logs and CSVs into validation-screenshots/sprint-77/:
.\pull-phone-screenshots.ps1 -Sprint 77

# The same, for the last 5 days:
.\pull-phone-screenshots.ps1 -Sprint 77 -Days 5

# Copy to a custom location:
.\pull-phone-screenshots.ps1 -Dest 'C:\Users\kimme\desktop\my-screenshots'

# List where files would be saved:
.\pull-phone-screenshots.ps1 -Sprint 77 -ListOnly

# Custom run: only the scan exports:
.\pull-phone-screenshots.ps1 -Sprint 77 -Folder 'Documents' -Recurse -Pattern '\.data\.csv$' -Overwrite
#>

param(
    [string]$Dest,
    [int]$Sprint,
    [string]$Pattern = '',
    [string]$Folder = '',
    [switch]$Recurse,
    [switch]$Overwrite,
    [string]$DeviceName = "S24|Fold|Galaxy|Harold",
    [int]$Days = 2,
    [switch]$ListOnly
)

# Resolve destination: Sprint parameter sets Dest if not already provided
if ($Sprint -and -not $Dest) {
    $sprintPad = "{0:D2}" -f $Sprint
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $Dest = Join-Path (Join-Path $repoRoot "validation-screenshots") "sprint-$sprintPad"
}

# Fall back to a temporary folder. Never a session scratchpad path: that
# path names one Claude Code session and does not exist in the next one.
if (-not $Dest) {
    $Dest = Join-Path $env:TEMP 'phone-screenshots'
}

# If ListOnly is set, just print the destination and exit
if ($ListOnly) {
    "Would save to: $Dest"
    exit 0
}

if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

$sh = New-Object -ComObject Shell.Application
# Device-agnostic: matches the S24+, the Fold8 Ultra, or any phone Harold
# connects. Pass -DeviceName to disambiguate when two are plugged in.
$candidates = @($sh.NameSpace(17).Items() | Where-Object {
    $_.Name -match $DeviceName -and $_.IsFolder -and $_.Path -notmatch '^[A-Z]:\$'
})
$phone = $candidates | Select-Object -First 1
if ($candidates.Count -gt 1) {
    "NOTE: multiple devices matched; using '$($phone.Name)'. Others: " +
        (($candidates | Select-Object -Skip 1).Name -join ', ')
}
if (-not $phone) { 'ERROR: phone not found under This PC'; exit 1 }

$store = $sh.NameSpace($phone.Path).Items() | Where-Object { $_.Name -eq 'Internal storage' }
if (-not $store) { 'ERROR: "Internal storage" not found on the phone (is it unlocked and in File Transfer mode?)'; exit 1 }

# Sprint 77 (Harold): a plain run collects ONLY this app's evidence --
#   1. DCIM:      Screenshot_<yyyyMMdd>_<HHmmss>.png with NO suffix. Samsung
#                 appends the foreground app's name to other screenshots
#                 (Screenshot_..._Instagram.png, _Chrome.png); this app's own
#                 have none (201 of 222 earlier validation files).
#                 EXCEPTION (Sprint 78, 2026-10-10): a screenshot of the
#                 notification shade is named for the launcher underneath it
#                 (Screenshot_..._One UI Home.png), so the no-suffix rule
#                 silently skipped Harold's notification evidence for a whole
#                 morning. Those are collected too. They can show other apps'
#                 notifications; the destination is gitignored.
#   2. Documents (and its subfolders, where the app writes): the diagnostic
#                 logs diag_*.log and the .csv exports.
# Passing -Folder or -Pattern runs ONE custom source instead (the old shape).
$exactScreenshot = '^Screenshot_\d{8}_\d{6}(_One UI Home)?\.png$'
if ($Folder -or $Pattern) {
    $sources = @(@{
        Folder    = $(if ($Folder) { $Folder } else { 'DCIM' })
        Pattern   = $(if ($Pattern) { $Pattern } else { $exactScreenshot })
        Recurse   = [bool]$Recurse
        Overwrite = [bool]$Overwrite
    })
} else {
    $sources = @(
        @{ Folder = 'DCIM'; Pattern = $exactScreenshot; Recurse = $false; Overwrite = [bool]$Overwrite },
        # Logs and exports keep growing on the phone, so refresh local copies.
        @{ Folder = 'Documents'; Pattern = '^diag_.*\.log$|\.csv$'; Recurse = $true; Overwrite = $true }
    )
}

$destNs = $sh.NameSpace($Dest)

function Get-MatchingItems($shellFolder, $pattern, $recurse) {
    foreach ($item in $shellFolder.Items()) {
        if ($item.IsFolder) {
            if ($recurse) { Get-MatchingItems $item.GetFolder $pattern $recurse }
            continue
        }
        if ($item.Name -match $pattern) { $item }
    }
}

# Date from the FILENAME, because MTP item dates are unreliable and
# GetDetailsOf indices shift per device: Screenshot_yyyyMMdd_..., or a
# yyyy-MM-dd anywhere (diag_v0.17.6_2026-10-07.log, ..._2026-10-06.data.csv).
# A name with no date is always copied.
function Get-NameDate($name) {
    if ($name -match 'Screenshot_(\d{8})') {
        return [datetime]::ParseExact($Matches[1], 'yyyyMMdd', $null)
    }
    if ($name -match '(\d{4}-\d{2}-\d{2})') {
        return [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
    }
    return $null
}

$copied = 0
$names = @()
foreach ($src in $sources) {
    # Walk the folder one segment at a time. Screenshots sit DIRECTLY IN DCIM,
    # not in a DCIM/Screenshots subfolder (verified by listing DCIM); do not
    # reintroduce the subfolder assumption.
    # NOT named $folder: PowerShell variable names ignore case, so
    # "$folder = ..." overwrote the -Folder PARAMETER and the walk split
    # "System.__ComObject" (Sprint 77, found the first time it ran).
    $shellDir = $store.GetFolder
    $missing = $false
    foreach ($segment in ($src.Folder -split '[\\/]' | Where-Object { $_ })) {
        $next = $shellDir.Items() | Where-Object { $_.IsFolder -and $_.Name -eq $segment } | Select-Object -First 1
        if (-not $next) { "ERROR: folder '$segment' not found under Internal storage/$($src.Folder)"; $missing = $true; break }
        $shellDir = $next.GetFolder
    }
    if ($missing) { continue }

    foreach ($item in @(Get-MatchingItems $shellDir $src.Pattern $src.Recurse)) {
        $d = Get-NameDate $item.Name
        if ($d -and $d -lt (Get-Date).Date.AddDays(-$Days)) { continue }
        $target = Join-Path $Dest $item.Name
        if ((Test-Path $target) -and -not $src.Overwrite) { continue }
        if (Test-Path $target) { Remove-Item -LiteralPath $target -Force }
        # 16 = respond "Yes to All" to any dialog, 512 = do not confirm creating
        # a new directory (Folder.CopyHere flags, Microsoft Learn)
        $destNs.CopyHere($item, 16 -bor 512)
        $names += $item.Name
        $copied++
    }
}

# CopyHere is ASYNCHRONOUS. Wait until every queued file exists and the set of
# sizes stops changing -- a premature read gets partial files.
$stable = 0
$last = ''
for ($i = 0; $i -lt 120 -and $copied -gt 0; $i++) {
    Start-Sleep -Milliseconds 500
    $present = @($names | ForEach-Object { Get-Item -LiteralPath (Join-Path $Dest $_) -ErrorAction SilentlyContinue })
    $sig = ($present | ForEach-Object { "$($_.Name)=$($_.Length)" }) -join ';'
    if ($present.Count -eq $names.Count -and $sig -eq $last) { $stable++ } else { $stable = 0 }
    if ($stable -ge 4) { break }
    $last = $sig
}

"queued : $copied"
'--- copied this run ---'
$names | Sort-Object -Unique | ForEach-Object {
    $f = Get-Item -LiteralPath (Join-Path $Dest $_) -ErrorAction SilentlyContinue
    '{0,-56} {1,11:N0} bytes' -f $_, $(if ($f) { $f.Length } else { 0 })
}
