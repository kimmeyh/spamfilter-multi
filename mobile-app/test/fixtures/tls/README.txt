TEST ONLY. Never used by the app.

cert.pem and key.pem are a self-signed certificate (subject CN=localhost, subjectAltName DNS:localhost,
valid 100 years) and its private key. They exist so that
test/adapters/email_providers/generic_imap_adapter_custom_server_test.dart can run a real TLS handshake
against an in-process fake IMAP server, with no network access and no real mail server.

The test adds cert.pem to the trusted certificates of dart:io's default SecurityContext for the test
process only, then proves two things the unit level cannot:
- STARTTLS verifies the certificate against the host name the user typed (host "localhost" passes, host
  "127.0.0.1" fails with a name mismatch), and
- the password is never sent unless the TLS upgrade succeeded.

The key protects nothing. Regenerate with:
  openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 36500 \
    -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"
