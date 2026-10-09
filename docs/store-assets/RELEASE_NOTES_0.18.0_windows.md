# Release notes -- 0.18.0 -- Microsoft Store

Re-derived from the finished CHANGELOG at Sprint 77 Phase 7.7 (2026-10-08, STORE_RELEASE_PROCESS.md Step 1b);
replaces the provisional text written at plan approval.

**Range**: everything after 0.17.6 (Submission 31).

**Excluded from this file**: Android-only entries (per-account "Scan when new mail arrives"; the Android alarm interval
fix; the debug-only notification test hook), research and test-only entries, and internal diagnostics wording.

---

You can now choose how often each account is scanned in the background, from every 5 minutes to every 99 hours. Accounts on short intervals now start one minute apart instead of all at once.

You can now add an email account from any provider that supports IMAP, with a server address, port and encryption you enter. If your own server uses a certificate your PC does not recognize, the app shows its details and asks once whether to trust it.

Clearer sign-in: password fields now say whether your provider needs an App Password or your normal password, and a wrong password now says "Sign-in failed" instead of asking you to check your internet connection. Adding an account you already saved asks before replacing its sign-in details.

Fixes: moving Gmail mail to a label you created; each "No rule" email is listed once instead of once per scan; 23 built-in safe senders (including banking and Microsoft account senders) that were never matched are now protected; scan intervals of 2 or 4 hours are now scheduled; and a new account's first scan now shows its results.
