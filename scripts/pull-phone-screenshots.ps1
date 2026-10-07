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
File name REGEX to match (default: 'Screenshot_'). Only files matching this
pattern are copied. Examples: 'diag_.*\.log$' for diagnostic logs,
'\.data\.csv$' for scan exports.

.PARAMETER Folder
Folder under the phone's "Internal storage", slash-separated (default: 'DCIM',
where this phone keeps screenshots). Sprint 77 (Harold Q25 = 1): generalized so
the same script pulls the diagnostic log and scan exports instead of hand
copying -- e.g. 'Android/data/com.myemailspamfilter/files' or 'Documents'.
Pass -Recurse to search below it.

.PARAMETER Recurse
Search subfolders of -Folder as well (for example the export folder's
'scan_exports' and 'diagnostics' children).

.PARAMETER Overwrite
Copy even when a file of the same name is already in -Dest. Use it for files
that keep growing on the phone (the diagnostic log); without it an existing
local copy is kept, which is right for screenshots.

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

# Pull the app's diagnostic logs (refreshing copies that already exist):
.\pull-phone-screenshots.ps1 -Sprint 77 -Folder 'Android/data/com.myemailspamfilter/files' -Recurse -Pattern 'diag_.*\.log$' -Overwrite

# Pull scan exports from the export folder:
.\pull-phone-screenshots.ps1 -Sprint 77 -Folder 'Documents' -Recurse -Pattern '\.data\.csv$' -Overwrite
#>

param(
    [string]$Dest,
    [int]$Sprint,
    [string]$Pattern = 'Screenshot_',
    [string]$Folder = 'DCIM',
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

# Walk -Folder one segment at a time. The default 'DCIM' keeps the original
# behavior: this phone stores screenshots DIRECTLY IN DCIM, not in a
# DCIM/Screenshots subfolder (verified by listing DCIM: every Screenshot_*.png
# has IsFolder=False at that level). Do not reintroduce the subfolder assumption.
$folder = $store.GetFolder
foreach ($segment in ($Folder -split '[\\/]' | Where-Object { $_ })) {
    $next = $folder.Items() | Where-Object { $_.IsFolder -and $_.Name -eq $segment } | Select-Object -First 1
    if (-not $next) { "ERROR: folder '$segment' not found under Internal storage/$Folder"; exit 1 }
    $folder = $next.GetFolder
}

$destNs = $sh.NameSpace($Dest)

function Get-MatchingItems($shellFolder) {
    foreach ($item in $shellFolder.Items()) {
        if ($item.IsFolder) {
            if ($Recurse) { Get-MatchingItems $item.GetFolder }
            continue
        }
        if ($item.Name -match $Pattern) { $item }
    }
}

$copied = 0
$names = @()
foreach ($item in @(Get-MatchingItems $folder)) {
    # Date-filter from the FILENAME (Screenshot_YYYYMMDD_...), because MTP
    # item dates are unreliable and GetDetailsOf indices shift per device.
    # Files without a date in the name (logs, exports) are not date-filtered.
    if ($item.Name -match 'Screenshot_(\d{8})') {
        $d = [datetime]::ParseExact($Matches[1], 'yyyyMMdd', $null)
        if ($d -lt (Get-Date).AddDays(-$Days)) { continue }
    }
    $target = Join-Path $Dest $item.Name
    if ((Test-Path $target) -and -not $Overwrite) { continue }
    if (Test-Path $target) { Remove-Item -LiteralPath $target -Force }
    # 16 = respond "Yes to All" to any dialog, 512 = do not confirm creating
    # a new directory (Folder.CopyHere flags, Microsoft Learn)
    $destNs.CopyHere($item, 16 -bor 512)
    $names += $item.Name
    $copied++
}

# CopyHere is ASYNCHRONOUS. Wait until every queued file exists and the set of
# sizes stops changing -- a premature read gets partial files. (Counting only
# *.png, as before, never settled for logs or exports.)
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
'--- on disk ---'
Get-ChildItem $Dest -File | Where-Object { $_.Name -match $Pattern } | Sort-Object Name | ForEach-Object {
    '{0,-46} {1,9:N0} bytes' -f $_.Name, $_.Length
}
