<#
.SYNOPSIS
    Asserts two Google Play requirements from the BUILT Android App Bundle (F204 gaps 1 and 2).

.DESCRIPTION
    Reads base/manifest/AndroidManifest.xml from the .aab itself (the artifact, not gradle config)
    and fails (exit 1) if:
      - targetSdkVersion is below -MinTargetSdk (default 36), or is not declared, or
      - the permission com.google.android.gms.permission.AD_ID is present (the app declares
        "no advertising ID" in Play Console Data safety; a transitive ads dependency would make
        that answer false), or
      - android.permission.INTERNET is not found: then the permission list was not read and the
        AD_ID answer would rest on nothing (PR #490 7.7.1).

    Why a built-in protobuf reader: inside an AAB the manifest is Android resource XML encoded as
    PROTOBUF (aapt2 XmlNode), so a text regex cannot read an integer attribute. Tools were tested
    on this machine on 2026-10-19: aapt2 35.0.0 and 34.0.0 dump xmltree both reject an .aab
    ("could not identify format of APK"), and no runnable bundletool jar is installed (the Gradle
    cache holds only library jars that need their dependencies). This script therefore decodes the
    few protobuf messages it needs with no external tool: XmlNode(1 element) -> XmlElement(3 name,
    4 attribute, 5 child) -> XmlAttribute(2 name, 3 value, 6 compiled_item) -> Item(7 prim) ->
    Primitive(6 int_decimal, 7 int_hex). The decoder is proven against the real bundle by -SelfTest.

    Android-only by nature (Play requirements). The Windows MSIX equivalent is --release-self-test
    and test/policy/msix_config_test.dart (ADR-0042 declared exception).

.PARAMETER AabPath
    Path to the built .aab. Required unless -SelfTest is used.

.PARAMETER MinTargetSdk
    Minimum acceptable targetSdkVersion. Default 36.

.PARAMETER SelfTest
    Run the helper against the real bundle (-AabPath, default: newest mobile-app/dist/android-*/app-prod-release.aab;
    FAILS if none exists) and against crafted manifests that must fail each rule. Exit 0 only if
    every expectation holds.

.EXAMPLE
    .\verify-aab-play-requirements.ps1 -AabPath ..\dist\android-0.20.0+17\app-prod-release.aab
.EXAMPLE
    .\verify-aab-play-requirements.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string]$AabPath,
    [int]$MinTargetSdk = 36,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:AdIdPermission = 'com.google.android.gms.permission.AD_ID'
$script:InternetPermission = 'android.permission.INTERNET'

# ---- protobuf wire reader ---------------------------------------------------

function Read-Varint {
    param([byte[]]$Bytes, [ref]$Pos)
    [long]$result = 0
    $shift = 0
    while ($true) {
        if ($Pos.Value -ge $Bytes.Length) { throw 'Truncated protobuf varint.' }
        $b = $Bytes[$Pos.Value]
        $Pos.Value++
        $result = $result -bor ([long]($b -band 0x7F) -shl $shift)
        if (($b -band 0x80) -eq 0) { break }
        $shift += 7
        if ($shift -gt 63) { throw 'Protobuf varint too long.' }
    }
    return $result
}

# Returns fields of one message in [Start, Start+Length): objects with F (field no), W (wire type),
# V (varint value), S/L (offset and length for length-delimited fields).
function Get-Fields {
    param([byte[]]$Bytes, [int]$Start, [int]$Length)
    $fields = New-Object System.Collections.ArrayList
    $pos = $Start
    $end = $Start + $Length
    while ($pos -lt $end) {
        $tag = Read-Varint -Bytes $Bytes -Pos ([ref]$pos)
        $f = [int]($tag -shr 3)
        $w = [int]($tag -band 7)
        $o = [pscustomobject]@{ F = $f; W = $w; V = [long]0; S = 0; L = 0 }
        switch ($w) {
            0 { $o.V = Read-Varint -Bytes $Bytes -Pos ([ref]$pos) }
            1 { $o.S = $pos; $o.L = 8; $pos += 8 }
            2 {
                $len = [int](Read-Varint -Bytes $Bytes -Pos ([ref]$pos))
                $o.S = $pos; $o.L = $len; $pos += $len
            }
            5 { $o.S = $pos; $o.L = 4; $pos += 4 }
            default { throw "Unsupported protobuf wire type $w." }
        }
        if ($pos -gt $end) { throw 'Protobuf field runs past its message.' }
        [void]$fields.Add($o)
    }
    return , $fields
}

function Get-Utf8 {
    param([byte[]]$Bytes, $Field)
    return [System.Text.Encoding]::UTF8.GetString($Bytes, $Field.S, $Field.L)
}

# XmlElement -> @{ Name; Attrs = @{name=value}; Children = @(element...) }
function ConvertFrom-XmlElement {
    param([byte[]]$Bytes, [int]$Start, [int]$Length)
    $el = @{ Name = ''; Attrs = @{}; Children = @() }
    foreach ($f in (Get-Fields -Bytes $Bytes -Start $Start -Length $Length)) {
        if ($f.F -eq 3 -and $f.W -eq 2) { $el.Name = Get-Utf8 $Bytes $f }
        elseif ($f.F -eq 4 -and $f.W -eq 2) {
            $aName = ''; $aValue = ''; $aPrim = $null
            foreach ($a in (Get-Fields -Bytes $Bytes -Start $f.S -Length $f.L)) {
                if ($a.F -eq 2 -and $a.W -eq 2) { $aName = Get-Utf8 $Bytes $a }
                elseif ($a.F -eq 3 -and $a.W -eq 2) { $aValue = Get-Utf8 $Bytes $a }
                elseif ($a.F -eq 6 -and $a.W -eq 2) {
                    # compiled_item (Item) -> prim (7) -> int_decimal (6) / int_hexadecimal (7)
                    foreach ($i in (Get-Fields -Bytes $Bytes -Start $a.S -Length $a.L)) {
                        if ($i.F -eq 7 -and $i.W -eq 2) {
                            foreach ($p in (Get-Fields -Bytes $Bytes -Start $i.S -Length $i.L)) {
                                if (($p.F -eq 6 -or $p.F -eq 7) -and $p.W -eq 0) { $aPrim = [string]$p.V }
                            }
                        }
                    }
                }
            }
            if ($aName) { $el.Attrs[$aName] = @{ Value = $aValue; Prim = $aPrim } }
        }
        elseif ($f.F -eq 5 -and $f.W -eq 2) {
            # child XmlNode -> element (1)
            foreach ($n in (Get-Fields -Bytes $Bytes -Start $f.S -Length $f.L)) {
                if ($n.F -eq 1 -and $n.W -eq 2) {
                    $el.Children += , (ConvertFrom-XmlElement -Bytes $Bytes -Start $n.S -Length $n.L)
                }
            }
        }
    }
    return $el
}

function Get-ManifestFacts {
    param([byte[]]$ManifestBytes)
    $root = $null
    foreach ($n in (Get-Fields -Bytes $ManifestBytes -Start 0 -Length $ManifestBytes.Length)) {
        if ($n.F -eq 1 -and $n.W -eq 2) { $root = ConvertFrom-XmlElement -Bytes $ManifestBytes -Start $n.S -Length $n.L }
    }
    if ($null -eq $root -or $root.Name -ne 'manifest') { throw 'Manifest root element is not <manifest>; not a proto manifest?' }
    $target = $null
    $perms = @()
    foreach ($c in $root.Children) {
        if ($c.Name -eq 'uses-sdk' -and $c.Attrs.ContainsKey('targetSdkVersion')) {
            $a = $c.Attrs['targetSdkVersion']
            $raw = if ($a.Prim) { $a.Prim } else { $a.Value }
            $parsed = 0
            if (-not [int]::TryParse($raw, [ref]$parsed)) { throw "targetSdkVersion value '$raw' is not an integer." }
            $target = $parsed
        }
        if ($c.Name -eq 'uses-permission' -or $c.Name -eq 'uses-permission-sdk-23') {
            if ($c.Attrs.ContainsKey('name')) { $perms += $c.Attrs['name'].Value }
        }
    }
    return @{ TargetSdk = $target; Permissions = $perms }
}

function Read-AabManifest {
    param([string]$Path)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry('base/manifest/AndroidManifest.xml')
        if ($null -eq $entry) { throw "base/manifest/AndroidManifest.xml not found in $Path (is it an .aab?)." }
        $ms = New-Object System.IO.MemoryStream
        $s = $entry.Open()
        try { $s.CopyTo($ms) } finally { $s.Dispose() }
        return , $ms.ToArray()
    } finally { $zip.Dispose() }
}

# Returns @{ Ok; Messages } for already-decoded facts.
function Test-PlayFacts {
    param($Facts, [int]$Min)
    $ok = $true
    $msgs = @()
    if ($null -eq $Facts.TargetSdk) {
        $ok = $false; $msgs += '[FAIL] targetSdkVersion is not declared in the bundle manifest.'
    } elseif ($Facts.TargetSdk -lt $Min) {
        $ok = $false; $msgs += "[FAIL] targetSdkVersion = $($Facts.TargetSdk), below the required minimum $Min."
    } else {
        $msgs += "[OK] targetSdkVersion = $($Facts.TargetSdk) (minimum $Min)."
    }
    # PR #490 7.7.1: "AD_ID absent" is only evidence if the permission list was
    # actually read. The app cannot work without INTERNET, so a list without it
    # means the reader missed the permissions -- fail, never pass on nothing.
    if ($Facts.Permissions -notcontains $script:InternetPermission) {
        $ok = $false; $msgs += "[FAIL] $script:InternetPermission not found ($(@($Facts.Permissions).Count) permissions read): the permission list was not read, so AD_ID cannot be checked."
    } elseif ($Facts.Permissions -contains $script:AdIdPermission) {
        $ok = $false; $msgs += "[FAIL] $script:AdIdPermission is present (advertising ID requested)."
    } else {
        $msgs += "[OK] $script:AdIdPermission absent ($(@($Facts.Permissions).Count) permissions read)."
    }
    return @{ Ok = $ok; Messages = $msgs }
}

function Invoke-AabCheck {
    param([string]$Path, [int]$Min)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Bundle not found: $Path" }
    # PR #490 7.7.1: .NET (ZipFile.OpenRead) resolves a relative path against the
    # PROCESS folder, PowerShell against the current location; resolve once here.
    $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
    $facts = Get-ManifestFacts -ManifestBytes (Read-AabManifest -Path $Path)
    return Test-PlayFacts -Facts $facts -Min $Min
}

# ---- crafted-manifest encoder (self-test only) --------------------------------

function ConvertTo-Varint { param([long]$V)
    $out = New-Object System.Collections.Generic.List[byte]
    while ($V -ge 0x80) { $out.Add([byte](($V -band 0x7F) -bor 0x80)); $V = $V -shr 7 }
    $out.Add([byte]$V); return , $out.ToArray()
}
function New-LenField { param([int]$F, [byte[]]$Body)
    return , ([byte[]](ConvertTo-Varint (($F -shl 3) -bor 2)) + [byte[]](ConvertTo-Varint $Body.Length) + $Body)
}
function New-VarField { param([int]$F, [long]$V)
    return , ([byte[]](ConvertTo-Varint ($F -shl 3)) + [byte[]](ConvertTo-Varint $V))
}
function New-Str { param([int]$F, [string]$S) return , (New-LenField $F ([System.Text.Encoding]::UTF8.GetBytes($S))) }
function New-Attr { param([string]$Name, [string]$Value, $IntValue = $null)
    $b = [byte[]](New-Str 2 $Name)
    if ($null -ne $IntValue) {
        $prim = New-VarField 6 $IntValue
        $item = New-LenField 7 $prim
        $b += [byte[]](New-LenField 6 $item)
    } else { $b += [byte[]](New-Str 3 $Value) }
    return , (New-LenField 4 $b)
}
function New-El { param([string]$Name, [byte[]]$Attrs = @(), [byte[]]$Children = @())
    $b = [byte[]](New-Str 3 $Name) + $Attrs + $Children
    return , (New-LenField 1 $b)   # XmlNode { element = 1 }
}
function New-Manifest { param($Target, [string[]]$Perms)
    $kids = [byte[]]@()
    if ($null -ne $Target) { $kids += [byte[]](New-LenField 5 (New-El 'uses-sdk' (New-Attr 'targetSdkVersion' "$Target" $Target))) }
    foreach ($p in $Perms) { $kids += [byte[]](New-LenField 5 (New-El 'uses-permission' (New-Attr 'name' $p))) }
    return , (New-El 'manifest' ([byte[]]@()) $kids)
}

# ---- main -------------------------------------------------------------------

if ($SelfTest) {
    $fail = 0
    function Expect { param([string]$Name, [bool]$Cond)
        if ($Cond) { Write-Host "[SELFTEST OK]   $Name" } else { Write-Host "[SELFTEST FAIL] $Name" -ForegroundColor Red; $script:fail++ }
    }
    # Real bundle (never silently skipped).
    $real = $AabPath
    if (-not $real) {
        $dist = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'
        $cand = Get-ChildItem -Path $dist -Filter 'app-prod-release.aab' -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($cand) { $real = $cand.FullName }
    }
    if (-not $real -or -not (Test-Path -LiteralPath $real)) {
        Write-Host "[SELFTEST FAIL] No real bundle found under mobile-app/dist/android-*/app-prod-release.aab. Build one with build-with-secrets.ps1 -Output aab or pass -AabPath." -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] Real bundle: $real"
    $r = Invoke-AabCheck -Path $real -Min $MinTargetSdk
    $r.Messages | ForEach-Object { Write-Host "         $_" }
    Expect "real bundle passes (min $MinTargetSdk)" $r.Ok
    $r2 = Invoke-AabCheck -Path $real -Min 1000
    Expect 'real bundle FAILS the SDK rule with -MinTargetSdk 1000' (-not $r2.Ok)
    # Crafted manifests through the same decoder + rules.
    $cases = @(
        @{ N = 'crafted good (36, no AD_ID)';          T = 36;    P = @('android.permission.INTERNET'); Ok = $true },
        @{ N = 'crafted old target (35) fails';        T = 35;    P = @('android.permission.INTERNET'); Ok = $false },
        @{ N = 'crafted AD_ID present fails';          T = 36;    P = @('android.permission.INTERNET', $script:AdIdPermission); Ok = $false },
        @{ N = 'crafted missing uses-sdk target fails'; T = $null; P = @('android.permission.INTERNET'); Ok = $false },
        @{ N = 'crafted target 37 passes';             T = 37;    P = @('android.permission.INTERNET'); Ok = $true },
        @{ N = 'crafted NO permissions read fails';    T = 36;    P = @(); Ok = $false }
    )
    foreach ($c in $cases) {
        $facts = Get-ManifestFacts -ManifestBytes ([byte[]](New-Manifest $c.T $c.P))
        $res = Test-PlayFacts -Facts $facts -Min $MinTargetSdk
        Expect $c.N ($res.Ok -eq $c.Ok)
    }
    if ($fail -gt 0) { Write-Host "[SELFTEST] $fail expectation(s) failed." -ForegroundColor Red; exit 1 }
    Write-Host '[SELFTEST] All expectations held.' -ForegroundColor Green
    exit 0
}

if (-not $AabPath) { Write-Host '[ERROR] -AabPath is required (or use -SelfTest).' -ForegroundColor Red; exit 2 }
try {
    $res = Invoke-AabCheck -Path $AabPath -Min $MinTargetSdk
} catch {
    Write-Host "[ERROR] Could not read the bundle manifest: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
Write-Host "[INFO] Play requirements check on $AabPath"
$res.Messages | ForEach-Object { Write-Host "       $_" }
if (-not $res.Ok) { Write-Host '[FAIL] Bundle does not meet Google Play requirements.' -ForegroundColor Red; exit 1 }
Write-Host '[OK] Bundle meets the checked Google Play requirements.' -ForegroundColor Green
exit 0
