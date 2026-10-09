TEST ONLY. Never used by the app.

cert.pem / key.pem, cert2.pem / key2.pem, cert3.pem / key3.pem are three independent self-signed
certificates (subject CN=localhost; cert2 adds O=Second Test Certificate, cert3 O=Third Test Certificate;
subjectAltName DNS:localhost; valid 100 years) and their private keys. They exist so tests can run real
TLS handshakes against in-process fake servers, with no network access and no real mail server:

- test/adapters/email_providers/generic_imap_adapter_custom_server_test.dart (F192) trusts cert.pem in
  dart:io's default SecurityContext for its own test process and proves STARTTLS verifies the typed host
  name and never sends the password unless the TLS upgrade succeeded.
- test/integration/imap_certificate_trust_test.dart (SEC-8b) trusts cert.pem only; cert2/cert3 play
  self-signed server certificates the device does not trust (trust-on-first-use, "changed" detection).
- test/unit/security/certificate_pinner_test.dart (SEC-8b) trusts cert3.pem only; cert2.pem plays a pinned
  root, cert3.pem a certificate the device trusts but the pin must refuse.

google_accounts_chain_20261007.pem is the PUBLIC certificate chain accounts.google.com served on
2026-10-07 (leaf, WR2, GTS Root R1 cross-signed), recorded with
  openssl s_client -connect accounts.google.com:443 -servername accounts.google.com -showcerts
It contains no key. certificate_pinner_test.dart checks it leads to a pinned Google root.

The keys protect nothing. Regenerate a pair with (n = 2 or 3; omit n for cert.pem):
  openssl req -x509 -newkey rsa:2048 -nodes -keyout key<n>.pem -out cert<n>.pem -days 36500 \
    -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"
