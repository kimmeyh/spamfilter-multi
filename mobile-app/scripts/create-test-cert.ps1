# Create a self-signed certificate for local MSIX testing
# This certificate matches the publisher CN in pubspec.yaml msix_config

$subject = "CN=84EA8722-0CA5-4EC0-9B10-07EE79B66062"

# Check if cert already exists
$existing = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $subject }
if ($existing) {
    Write-Host "Certificate already exists: $($existing.Thumbprint)"
    Write-Host "To use: dart run msix:create --store false --certificate-subject '$subject'"
    exit 0
}

# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $subject `
    -KeyUsage DigitalSignature `
    -FriendlyName "MyEmailSpamFilter Local Test" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")

Write-Host "Certificate created: $($cert.Thumbprint)"
Write-Host "To use: dart run msix:create --store false --certificate-subject '$subject'"
