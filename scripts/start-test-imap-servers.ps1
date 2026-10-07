<#
.SYNOPSIS
  Start the two local TEST IMAP servers used to validate custom IMAP accounts.

.DESCRIPTION
  Sprint 77 (F192 custom IMAP, SEC-15 local-address warning, SEC-8b certificate
  trust; Harold Q7 = 1). No public provider can exercise these paths, so two
  local servers do:

    1. GreenMail (Java, runs on Windows) -- IMAP SSL/TLS on port 3993 with
       GreenMail's built-in SELF-SIGNED certificate. Exercises the
       "Trust this server?" prompt, the local-address warning, and -- when
       restarted with -NewCertificate -- the "certificate changed" stop.
       GreenMail offers NO STARTTLS on IMAP (its CAPABILITY list has none;
       verified 2026-10-07), so:
    2. Dovecot (inside Ubuntu WSL) -- STARTTLS on port 143 and SSL/TLS on 993
       with Ubuntu's self-signed certificate; LOGIN is refused until STARTTLS
       succeeds (disable_plaintext_auth = yes). Reached from Windows at
       localhost:143 through WSL's localhost forwarding.

  Test account on both: username "tester", password "testpass". GreenMail's
  username is "tester@spamfilter.test". Test data only; nothing here touches a
  real mailbox. The GreenMail jar (Maven Central 2.1.14, SHA-1 checked) is kept
  in %LOCALAPPDATA%\spamfilter-test-imap, outside the repo.

.PARAMETER Stop
  Stop both servers and exit.

.PARAMETER NewCertificate
  Restart GreenMail with a freshly generated self-signed keystore, so an app
  that already trusted the old certificate sees a CHANGED certificate.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-test-imap-servers.ps1
#>
param(
    [switch]$Stop,
    [switch]$NewCertificate
)

$ErrorActionPreference = 'Stop'
$work = Join-Path $env:LOCALAPPDATA 'spamfilter-test-imap'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$jar = Join-Path $work 'greenmail-standalone-2.1.14.jar'
$jarUrl = 'https://repo1.maven.org/maven2/com/icegreen/greenmail-standalone/2.1.14/greenmail-standalone-2.1.14.jar'

function Stop-GreenMail {
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" |
        Where-Object { $_.CommandLine -match 'greenmail-standalone' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force; "Stopped GreenMail (pid $($_.ProcessId))" }
}

if ($Stop) {
    Stop-GreenMail
    wsl.exe -d Ubuntu -u root -- bash -lc 'pkill -x dovecot || true' | Out-Null
    'Stopped Dovecot (WSL).'
    exit 0
}

# --- GreenMail ---------------------------------------------------------------
if (-not (Test-Path $jar)) {
    Invoke-WebRequest -Uri $jarUrl -OutFile $jar -UseBasicParsing
    $want = (Invoke-WebRequest -Uri "$jarUrl.sha1" -UseBasicParsing).Content.Trim()
    $have = (Get-FileHash $jar -Algorithm SHA1).Hash.ToLower()
    if ($have -ne $want) { Remove-Item $jar; throw "GreenMail jar checksum mismatch ($have vs $want)" }
}
Stop-GreenMail
$javaArgs = @('-Dgreenmail.setup.test.all', '-Dgreenmail.users=tester:testpass@spamfilter.test', '-Dgreenmail.hostname=0.0.0.0')
if ($NewCertificate) {
    $ks = Join-Path $work 'greenmail-alt.p12'
    if (Test-Path $ks) { Remove-Item $ks }
    & keytool -genkeypair -alias greenmail -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=localhost' `
        -storetype PKCS12 -keystore $ks -storepass changeit -keypass changeit 2>&1 | Out-Null
    $javaArgs += @("-Dgreenmail.tls.keystore.file=$ks", '-Dgreenmail.tls.keystore.password=changeit')
}
$javaArgs += @('-jar', "`"$jar`"")
$p = Start-Process -FilePath java -ArgumentList $javaArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $work 'greenmail.out.log') -RedirectStandardError (Join-Path $work 'greenmail.err.log')
$up = $false
for ($i = 0; $i -lt 60 -and -not $up; $i++) {
    try { $t = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 3993); $t.Close(); $up = $true } catch { Start-Sleep -Milliseconds 500 }
}
if (-not $up) { throw 'GreenMail did not open port 3993' }
"GreenMail running (pid $($p.Id)): IMAP SSL/TLS on port 3993, self-signed" + $(if ($NewCertificate) { ' (NEW certificate)' } else { '' })

# --- Dovecot in WSL ----------------------------------------------------------
$setup = (Resolve-Path (Join-Path $PSScriptRoot 'test-imap\dovecot-wsl-setup.sh')).Path
$wslPath = '/mnt/' + $setup.Substring(0, 1).ToLower() + ($setup.Substring(2) -replace '\\', '/')
wsl.exe -d Ubuntu -u root -- bash -lc "tr -d '\r' < '$wslPath' > /tmp/dovecot-wsl-setup.sh && bash /tmp/dovecot-wsl-setup.sh" 2>&1 |
    ForEach-Object { $_ -replace "`0", '' }

''
'Use in the app (Add Account > Custom IMAP Server), username tester:'
'  SSL/TLS : server localhost or 127.0.0.1, port 3993 (GreenMail, user tester@spamfilter.test) or 993 (Dovecot)'
'  STARTTLS: server localhost, port 143 (Dovecot)'
'  Password: testpass'
'From the Fold, use this PC''s Wi-Fi address with port 3993 (GreenMail binds all interfaces).'
