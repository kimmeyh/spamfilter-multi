Three switches plus a retention picker that control what the app logs and stores on disk:
- Disable detailed auth logging: when on, debug-only authentication log lines (redacted tokens, account IDs) are suppressed. Errors and warnings still log. Turn off only to diagnose sign-in issues.
- Unmatched Emails Retention: how many days to keep the pool of "emails that matched no rule" used by Rule Test / Rule Quick Add. 0 disables retention; 30-90 days is a typical sweet spot.
- Pin Google OAuth certificates: Google sign-in connects only when the server certificate was issued by Google Trust Services, checked on every connection. Turn off only if Google sign-in fails with a certificate message on a network you trust. This switch does not affect Custom IMAP servers, which ask you to confirm a certificate your device does not trust.
- Encrypt database (experimental): provisions a 256-bit key in the system keychain for future SQLCipher-backed encryption. The database itself is not yet encrypted -- the key is stored early so the later driver-swap release can migrate in place.

The red "Delete All App Data" button wipes every account, credential, rule, scan result, and setting. Two-step confirmation required; no undo.
