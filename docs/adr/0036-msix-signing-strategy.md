# ADR-0036: MSIX Signing Strategy for Windows Store Submission

## Status

Accepted

## Date

2026-03-19

## Context

The app is a Flutter Windows Desktop application (MyEmailSpamFilter) targeting the Microsoft Store. MSIX packages must be signed before installation. The signing strategy differs significantly between Store distribution and local/sideload distribution.

### Current State

The `pubspec.yaml` msix_config is configured for Store submission:

```yaml
msix_config:
  display_name: MyEmailSpamFilter
  publisher_display_name: MyEmailSpamFilter
  identity_name: MyEmailSpamFilter
  publisher: CN=MyEmailSpamFilter
  msix_version: 0.5.1.0
  logo_path: windows/runner/resources/app_icon.ico
  capabilities: internetClient, internetClientServer, privateNetworkClientServer, runFullTrust
  store: true
  install_certificate: false
```

The `store: true` flag instructs the `msix` Flutter package to produce an MSIX that omits the developer certificate from the package (as required for Partner Center upload). The `install_certificate: false` flag prevents the local build tool from attempting to install a certificate, which is correct for Store builds.

### How MSIX Signing Works

MSIX packages cannot be installed unless they are signed by a trusted certificate. There are two distinct signing paths depending on the distribution channel:

**Microsoft Store (Partner Center) path**:
1. Developer builds an unsigned MSIX (or signs with any valid certificate for upload validation)
2. Developer uploads to Partner Center
3. Microsoft re-signs the package with a Microsoft-trusted certificate before distribution
4. End users receive a Microsoft-signed package; no certificate trust configuration required on end-user machines

**Sideload / direct distribution path**:
1. Developer signs the MSIX with a code signing certificate
2. If using a self-signed certificate, the end user must manually install and trust that certificate in the Windows Certificate Store (Local Machine > Trusted Root Certification Authorities)
3. If using a purchased EV (Extended Validation) or OV (Organization Validation) code signing certificate from a trusted Certificate Authority, no manual trust step is required on end-user machines
4. Developer certificate must be kept secure and backed up

### Current Development Build State

Development builds (from `build-windows.ps1`) produce a standard Windows executable but do not currently produce a signed MSIX. The script builds and launches the app directly from the Flutter build output directory, bypassing MSIX packaging entirely during development. This is intentional: MSIX packaging and signing add overhead that is unnecessary for iterative development and testing.

### MSIX Package Tool Behavior with `store: true`

When `store: true` is set in `msix_config`, the `msix` Flutter package:
- Produces an MSIX with the Store identity fields populated (publisher identity must match the Partner Center account)
- Does not embed a developer signing certificate in the package
- Does not attempt to install a certificate locally
- The resulting MSIX is intended solely for upload to Partner Center, not for local installation

### Partner Center Publisher Identity

For Store submission, the `publisher` field in `msix_config` must match the publisher identity string from the Microsoft Partner Center account (format: `CN=Publisher Name, O=Organization, C=Country`). The current placeholder value `CN=MyEmailSpamFilter` must be updated with the actual Partner Center publisher identity before submission.

### CI/CD Considerations

This project does not currently have a CI/CD pipeline (all builds are local on the developer's Windows 11 machine). When a CI/CD pipeline is established:
- Store builds: The pipeline uploads the MSIX to Partner Center; Microsoft handles signing
- No code signing certificate or key material needs to be stored in CI/CD secrets for Store builds
- If sideload distribution is needed from CI/CD, a code signing certificate would need to be stored as a CI/CD secret (base64-encoded) and injected at build time

## Decision

Use **Microsoft Store auto-signing** for Store distribution. Do not purchase or manage a code signing certificate for the Store distribution path.

Specifically:
1. **Store builds** (`store: true`): Build the MSIX locally with `flutter pub run msix:create` (or equivalent), upload to Partner Center. Microsoft signs before distribution. No developer certificate required.
2. **Development builds**: Continue using the direct `flutter build windows` + `build-windows.ps1` approach. No MSIX packaging during development.
3. **Sideload distribution**: Not a current use case. If sideload distribution is needed in the future, revisit this decision (see Alternatives Considered).
4. **Publisher identity**: Update `publisher` in `msix_config` to the actual Partner Center publisher identity string before the first Store submission.

### Rationale

Microsoft Store auto-signing is the correct choice because:
- It eliminates the cost and complexity of purchasing and managing a code signing certificate
- End users receive a Microsoft-signed package with no trust warnings
- It is the standard and recommended path for Store-distributed apps
- The `store: true` configuration in `msix_config` already implements this correctly
- There is no current requirement for sideload distribution

## Alternatives Considered

### Option A: Purchase OV/EV Code Signing Certificate for All Builds

- **Description**: Purchase a code signing certificate from a Certificate Authority (e.g., DigiCert, Sectigo). Sign the MSIX with this certificate for both Store uploads and potential sideload distribution.
- **Pros**:
  - Single signing approach for all distribution channels
  - Sideload distribution works without per-user certificate trust step
  - OV/EV certificates establish organizational identity
- **Cons**:
  - Annual cost ($100-$400/year depending on certificate type)
  - Certificate and private key must be securely stored and backed up
  - EV certificates often require a hardware token (USB HSM), adding complexity
  - For Store distribution, Microsoft re-signs anyway, making the developer certificate redundant in the final package
  - Additional complexity in build scripts to inject signing credentials
- **Why Rejected**: The cost and complexity are not justified when the primary distribution channel is the Microsoft Store and sideload distribution is not a current requirement.

### Option B: Self-Signed Certificate for Sideload + Store Auto-Signing for Store

- **Description**: Create a self-signed certificate (via PowerShell `New-SelfSignedCertificate`) for sideload testing, while using Store auto-signing for Store distribution.
- **Pros**:
  - Enables local MSIX installation for testing the MSIX package format itself
  - No certificate purchase required
  - Store path remains the same (no change to current approach)
- **Cons**:
  - Self-signed certificates are not trusted by other machines without manual certificate installation
  - Sideload recipients must install the developer certificate before installing the MSIX
  - Two signing paths add complexity to build scripts
  - Testing MSIX installation locally is valuable but not currently a blocker
- **Why Rejected**: Sideload distribution is not a current requirement. If it becomes needed, this option can be adopted at that time without modifying the Store submission path. The complexity is not justified now.

### Option C: Microsoft Trusted Signing Service (Azure)

- **Description**: Use the Microsoft Trusted Signing service (formerly Azure Code Signing) to sign MSIX packages. This is a cloud-based HSM service with per-signing pricing rather than annual certificate cost.
- **Pros**:
  - Certificates are issued by Microsoft-trusted roots (no per-user trust step for sideload)
  - No hardware token required (cloud-based HSM)
  - Per-signing pricing model (low cost for low volume)
  - Integrates with CI/CD pipelines
- **Cons**:
  - Requires Azure subscription and account setup
  - Additional complexity for a solo developer project
  - For Store distribution, Microsoft re-signs anyway, making this redundant in the Store path
  - Primarily beneficial when sideload distribution at scale is required
- **Why Rejected**: Adds Azure dependency and setup overhead for a capability (sideload at scale) that is not currently needed. Revisit if the app distribution strategy expands beyond the Store.

## Consequences

### Positive

- No code signing certificate cost or management overhead
- No private key material to secure or back up for signing purposes
- End users receive Microsoft-signed packages with full trust (no warnings)
- `msix_config` is already correctly configured (`store: true`, `install_certificate: false`)
- Store submission build process is straightforward: build MSIX, upload to Partner Center

### Negative

- The MSIX produced locally cannot be installed on other machines without first going through Partner Center (because it lacks a locally trusted signature)
- Local MSIX installation testing is not possible without either a self-signed certificate or Partner Center round-trip
- If sideload distribution is needed in the future, this decision must be revisited

### Neutral

- The `publisher` field in `msix_config` must be updated to match the Partner Center publisher identity before the first Store submission. This is a one-time configuration step, not an ongoing signing concern.
- Development workflow (direct `flutter build windows`) is unaffected by this decision
- If a CI/CD pipeline is added for Store builds, no signing secrets are needed (the pipeline only needs to upload to Partner Center)

## Implementation Notes

### Build Command for Store Submission

```powershell
# From the mobile-app directory
flutter pub run msix:create
# Output: build\windows\x64\runner\Release\MyEmailSpamFilter.msix
# Upload this file to Microsoft Partner Center
```

### Partner Center Publisher Identity

Before first submission, retrieve the publisher identity from Partner Center:
1. Sign in to https://partner.microsoft.com/dashboard
2. Navigate to the app -> App identity
3. Copy the "Package/Identity/Publisher" value (format: `CN=..., O=..., L=..., C=...`)
4. Update `publisher` in `pubspec.yaml` msix_config

### Local Installation Testing (If Needed)

If testing the MSIX package format locally becomes necessary, generate a temporary self-signed certificate:

```powershell
# Generate self-signed certificate (one-time, developer machine only)
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=MyEmailSpamFilter" `
    -KeyUsage DigitalSignature -FriendlyName "MyEmailSpamFilter Dev" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
# Export and install in Trusted Root (requires admin) for local testing only
```

This is a developer-only workaround and does not affect the Store submission path.

## References

- `mobile-app/pubspec.yaml` - msix_config section (lines 77-86)
- `mobile-app/scripts/build-windows.ps1` - Windows build script (no MSIX packaging currently)
- ADR-0026: Application Identity and Package Naming (publisher identity context)
- ADR-0027: Android Release Signing Strategy (parallel signing ADR for Android)
- ADR-0035: Production and Development Builds Side-by-Side (build environment context)
- [MSIX package signing overview](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview) - Microsoft documentation
- [Sign an MSIX package with Device Guard signing](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-device-guard-signing) - Alternative signing approaches
- [Publish MSIX packages to the Microsoft Store](https://learn.microsoft.com/en-us/windows/msix/publish-package/publish-msix-packages-to-the-microsoft-store) - Partner Center upload process
- [msix Flutter package](https://pub.dev/packages/msix) - Flutter MSIX packaging tool (`store` flag documentation)
- [Microsoft Trusted Signing](https://learn.microsoft.com/en-us/azure/trusted-signing/) - Azure-based code signing service
- Issue #194 - Windows Store readiness: MSIX signing strategy ADR
