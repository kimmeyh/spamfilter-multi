# ADR-0046: IMAP certificate trust and the Google OAuth issuing-authority pin

**Status**: Proposed (implemented Sprint 77; Accepted when Harold signs off at Manual Validation)
**Date**: 2026-10-07
**Deciders**: Harold (Chief Architect / Product Owner)
**Sprint**: 77 (SEC-8b, Issue #467; decisions Q4 = 1 and Q5 = 1)

## Context

F192 (Sprint 77) lets a user add any IMAP server. Many personal servers use a
self-signed or private-CA certificate (a home server, a local bridge). Before
this ADR the app had two certificate behaviors, both inherited by accident:

1. **IMAP**: enough_mail 2.1.7 validated against the device trust store and
   nothing else. An untrusted certificate failed with "TLS certificate
   validation failed"; there was no way to use such a server, and no record of
   which certificate a server had used before. Two code comments
   (`generic_imap_adapter.dart`, `certificate_pinner.dart`) said enough_mail
   exposes no certificate hook. That was wrong: `ImapClient` accepts
   `onBadCertificate`, and `ClientBase.connect(socket, connectionInformation:)`
   accepts a socket the app opened itself. What enough_mail does NOT do is pass
   a callback during STARTTLS (`ClientBase.upgradeToSslSocket` calls
   `SecureSocket.secure(socket)` with no callback), and it exposes no peer
   certificate.
2. **Google OAuth (SEC-8, Sprint 33)**: `PinnedHttpClient` was documented as
   SPKI pinning of Google intermediates, but enforced nothing on the normal
   path: `badCertificateCallback` runs only when the device already
   distrusts the certificate, `send()` checked only the URL scheme,
   `matches()` had no production caller, and `fingerprint()` hashed the whole
   certificate while the pins were described as SPKI hashes. The two stored
   pin values did not match any current Google root. The effective control was
   device validation plus the scheme check.

Facts that bound the design (verified 2026-10-07):

- dart:io gives Dart code only the server's LEAF certificate
  (`SecureSocket.peerCertificate`, `HttpClientResponse.certificate`). The
  intermediate certificates are never exposed, so an intermediate SPKI pin
  cannot be computed in Dart.
- `onBadCertificate` / `badCertificateCallback` run only when the context's
  trust anchors reject the chain or the host name (a name mismatch DOES invoke
  it; proven by `imap_certificate_trust_test.dart`).
- A `SecurityContext(withTrustedRoots: false)` with explicit roots makes
  BoringSSL (inside the Dart runtime, on Windows and Android) validate the full
  chain against only those roots.
- Google Trust Services publishes its roots at https://pki.goog/repository/
  (data: https://pki.goog/repo/repo.json): GTS Root R1, R2, R3, R4 and
  GlobalSign ECC Root CA - R4, all valid to 2036 or later. On 2026-10-07 all
  four pinned Google hosts served leaf -> WR2 -> GTS Root R1 (plus R1
  cross-signed by GlobalSign Root CA).
- enough_mail fails any command queued before the server greeting (the
  R-0 spike against imap.aol.com, 2026-10-07: LOGIN after an awaited greeting
  reached the server and got `AUTHENTICATIONFAILED`; LOGIN before it failed
  locally).

## Decision

### 1. Known IMAP providers: platform validation only, no pin

AOL, Yahoo, Gmail (IMAP) and iCloud keep enough_mail's `connectToServer` and
the device trust store. Their leaf certificates are NOT pinned (Q4 option 4
rejected): leaf certificates rotate, and a stale leaf pin locks every user
out. AOL's leaf on 2026-10-07 was issued by DigiCert and expires 2026-11-25.

### 2. Custom IMAP servers: trust-on-first-use with user acceptance

For platform `imap` only, `ImapTlsConnector` (`lib/core/security/imap_certificate_trust.dart`)
opens the TLS socket itself for SSL/TLS and for STARTTLS, then hands the
finished socket to enough_mail and waits for the greeting before any command.

- **Device trusts the certificate**: connect. Record its SHA-256 (whole
  certificate DER) per account if it differs from the stored one, so a later
  switch to an untrusted certificate reads as "changed".
- **Device does not trust it**: connect ONLY when its SHA-256 equals the
  fingerprint stored for the account. Otherwise abort the TLS handshake and
  throw `ServerCertificateNotTrustedException` (`notTrusted` when nothing is
  stored, `changed` when a different fingerprint is stored). No IMAP command,
  and so no password, is sent.
- **First use / change, in the foreground**: the setup form (Add Account >
  Custom IMAP Server > Test Connection, or Save) catches the exception and asks
  "Trust this server?", showing the fingerprint (colon pairs), subject, issuer
  (marked self-signed when it signed itself), validity dates and server. Yes
  stores the fingerprint for that exact host, port and encryption; No stores
  nothing (Save does not save). Save performs a certificate check without
  LOGIN before storing the account. A network failure during that check does
  not block Save; the certificate is then checked on the first connection.
- **Background**: a scan can never show a dialog. An untrusted or changed
  certificate fails the scan with a named reason, "Server certificate changed
  -- open the app and confirm the server." (or "... not trusted ..."), plus how
  to confirm it. The reason reaches the scan record through
  `ErrorMessages.humanize` (`email_scanner.dart` failure path) and survives a
  mid-scan reconnect.
- **Storage**: the fingerprint is the `SecureCredentialsStore` side key
  `credentials_<accountId>_imapTrustedCertSha256`, in
  `CustomImapSettings.paramKeys`, so it is saved, read and deleted with the
  other F192 keys. A malformed stored value reads as no trust (ask again),
  never as permission to skip the check.
- **Accepting a name mismatch**: a certificate whose name does not match the
  host is rejected by the device and goes through the same question. If the
  user trusts it, that exact certificate is accepted for that server. This is
  deliberate: personal servers are often reached by an address their
  certificate does not name, and the user has seen the exact fingerprint.
- **STARTTLS**: the connector sends STARTTLS itself and refuses (password never
  sent) unless the greeting is `* OK`, the reply is a tagged OK, and the server
  sent NO byte between that OK and the TLS handshake (the plaintext-injection
  shape). Because the server sends no greeting after TLS, the connector gives
  enough_mail a fixed greeting with no capabilities and asks for capabilities
  again over TLS (RFC 3501 section 6.2.1).
- **How to confirm a changed certificate later**: there is no edit screen for
  a Custom IMAP account yet (F192: delete and add again). The message tells the
  user to add the account again (Accounts > Add Account > Custom IMAP Server >
  Test Connection); saving the same address replaces the stored settings.

The Settings switch "Pin Google OAuth certificates" does NOT affect this rule.

### 3. Google OAuth: pin the issuing authority (roots), enforced on every connection

`PinnedHttpClient` routes a pinned host (accounts.google.com,
oauth2.googleapis.com, gmail.googleapis.com, www.googleapis.com) through an
`HttpClient` whose `SecurityContext` trusts ONLY the five Google Trust Services
roots bundled in `certificate_pinner.dart`. Every handshake to those hosts is
validated by the TLS library against those roots, on the normal path. A chain
that does not lead to them, including one the DEVICE trusts (an installed
inspection-proxy CA, another public CA), is refused with
`CertificatePinMismatchException` naming the host and the presented
certificate; the request is never sent. There is no silent fallback. A network
or protocol error keeps its own type.

- The bundled PEMs are checked in tests against the SHA-256 values Google
  publishes; the recorded 2026-10-07 chain is checked to lead to GTS Root R1 by
  name and by key; a live test (network) proves today's Google endpoints pass
  and a DigiCert site fails.
- The kill switch is kept (Settings > General, "Pin Google OAuth
  certificates"): off means device validation only.
- `fingerprint()` and `matches()` were removed (no production caller; the
  hash mode was wrong).
- Error text: `ErrorMessages.humanize` and the desktop sign-in and refresh
  paths show a plain sentence naming the Settings switch, instead of "Session
  expired" (which would send the user into the same refusal).

## Platforms (ADR-0042)

Parity, no exception. All of this is shared Dart over dart:io on Windows and
Android: the TLS handshake and chain validation run in BoringSSL inside the
Dart runtime on both; `onBadCertificate` and `peerCertificate` behave the same.
What differs by OS is the DEVICE trust store (Windows root store versus Android
system CAs), which only changes which custom servers fall in the
"device trusts" branch; the rule is identical. The OAuth pin does not consult
the device store at all. Background workers (Windows Task Scheduler process,
Android WorkManager isolate) read the fingerprint through the same
`SecureCredentialsStore.getCredentials` call as every reconnect path. Scope
note (unchanged): Android's native Google sign-in and its AppAuth refresh use
the platform HTTP stack and are not routed through `PinnedHttpClient`.

## Consequences

- A self-signed personal server can be used safely after one explicit
  confirmation; a later certificate change is never accepted silently.
- A certificate rotation on a custom server that the device does NOT trust
  (for example a self-signed certificate re-issued) stops background scans
  until the user confirms it in the app. A rotation to a device-trusted
  certificate is silent and recorded.
- Google OAuth now fails closed if Google moves these hosts outside the GTS
  roots. Google lists new roots in its repository before using them; the live
  test fails in CI on such a move, and the kill switch is the field release
  valve.
- enough_mail's non-exported `ConnectionInfo` is imported from its `src/`
  path (one `implementation_imports` ignore, documented at the import). The
  dependency is `^2.1.7`; a breaking change fails compilation and the tests.

## Rejected alternatives

- Leaf pins for known providers (Q4 option 4): rotation breakage.
- TOFU with device validation still required (Q4 option 2): excludes the
  self-signed servers F192 exists for.
- SPKI hashes of Google intermediates: not computable from dart:io (leaf only),
  and intermediates (WR1-WR5, WE1-WE5) rotate more often than roots.
- Replacing `SecurityContext.defaultContext` process-wide: not possible
  (read-only) and would affect every connection.
- Leaving the OAuth pinner as is and correcting the dartdoc (Q5 option 3):
  Harold chose to fix it (Q5 = 1).
