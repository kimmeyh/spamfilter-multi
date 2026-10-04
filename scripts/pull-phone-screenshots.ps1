<#
.SYNOPSIS
Pull recent phone screenshots over MTP and save to a sprint validation folder.

.DESCRIPTION
Copies recent screenshots from a connected phone (S24+, Fold8, etc.) over MTP
(no adb; USB debugging is blocked by company policy). By default, saves into
a temporary folder (%TEMP%\phone-screenshots). When `-Sprint N` is given and `-Dest` is not
provided, saves to `validation-screenshots/sprint-NN/` instead, organizing
Manual Validation evidence by sprint.

Uses the Windows Shell.Application COM object to access MTP devices, avoiding
adb and driver dependencies.

.PARAMETER Dest
Destination directory for screenshots. Defaults to %TEMP%\phone-screenshots.
If `-Sprint` is given and `-Dest` is not, the
destination is set to `validation-screenshots/sprint-NN/`.

.PARAMETER Sprint
Sprint number (e.g., 75) for organizing validation evidence. When provided
(and `-Dest` is not), sets the destination to `<repo>/validation-screenshots/sprint-NN/`.
Two-digit format is used (e.g., sprint-75).

.PARAMETER Pattern
File name pattern to match (default: 'Screenshot_'). Only files matching this
pattern are copied.

.PARAMETER DeviceName
Device name filter to match among connected phones (default: 'S24|Fold|Galaxy|Harold').
Matches any phone name containing one of these substrings. Used to disambiguate
when multiple phones are plugged in.

.PARAMETER Days
Only copy files newer than this many days (default: 2). Screenshots older than
this threshold are skipped, keeping the initial copy set manageable.

.PARAMETER ListOnly
If specified, only list the destination and exit without copying files.

.EXAMPLE
# Copy to %TEMP%\phone-screenshots (default):
.\pull-phone-screenshots.ps1

# Copy to validation-screenshots/sprint-75/:
.\pull-phone-screenshots.ps1 -Sprint 75

# Copy to a custom location:
.\pull-phone-screenshots.ps1 -Dest 'C:\Users\kimme\desktop\my-screenshots'

# List where files would be saved:
.\pull-phone-screenshots.ps1 -Sprint 75 -ListOnly
#>

param(
    [string]$Dest,
    [int]$Sprint,
    [string]$Pattern = 'Screenshot_',
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
$dcim  = $store.GetFolder.Items() | Where-Object { $_.Name -eq 'DCIM' }

# This phone stores screenshots DIRECTLY IN DCIM, not in a DCIM/Screenshots
# subfolder. Verified by listing DCIM: every Screenshot_*.png has IsFolder=False
# at that level, and no Screenshots folder exists. Do not reintroduce the
# subfolder assumption.
$folder = $dcim.GetFolder

$destNs = $sh.NameSpace($Dest)

$copied = 0
foreach ($item in $folder.Items()) {
    if ($item.IsFolder) { continue }
    if ($item.Name -notmatch $Pattern) { continue }
    # Date-filter from the FILENAME (Screenshot_YYYYMMDD_...), because MTP
    # item dates are unreliable and GetDetailsOf indices shift per device.
    if ($item.Name -match 'Screenshot_(\d{8})') {
        $d = [datetime]::ParseExact($Matches[1], 'yyyyMMdd', $null)
        if ($d -lt (Get-Date).AddDays(-$Days)) { continue }
    }
    $target = Join-Path $Dest $item.Name
    if (Test-Path $target) { continue }
    # 16 = respond "Yes to All" to any dialog, 512 = do not confirm creating
    # a new directory (Folder.CopyHere flags, Microsoft Learn)
    $destNs.CopyHere($item, 16 -bor 512)
    $copied++
}

# CopyHere is ASYNCHRONOUS. Wait for the file count to settle rather than
# assuming completion -- a premature read gets partial files.
$stable = 0
$last = -1
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    $n = @(Get-ChildItem $Dest -Filter *.png -ErrorAction SilentlyContinue).Count
    if ($n -eq $last) { $stable++ } else { $stable = 0 }
    if ($stable -ge 6 -and $n -gt 0) { break }
    $last = $n
}

"queued : $copied"
'--- on disk ---'
Get-ChildItem $Dest -Filter *.png | Sort-Object Name | ForEach-Object {
    '{0,-46} {1,9:N0} bytes' -f $_.Name, $_.Length
}
