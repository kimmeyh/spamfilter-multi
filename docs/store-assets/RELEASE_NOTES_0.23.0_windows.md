# Release notes -- 0.23.0 -- Microsoft Store

PROVISIONAL (Sprint 82 Phase 3.7.0b, 2026-10-30). Re-derive from the finished CHANGELOG at Phase 7.7 and again at
Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b).

**Range**: everything after 0.21.0 (the last version on the Store). 0.22.0 was never uploaded (Harold, 2026-10-30), so
this file covers the CHANGELOG sections `[0.22.0]` and `[Unreleased]` (0.23.0).

**Excluded from this file**: the iOS project, the iOS build workflow and TestFlight (not shipped to Windows);
Android-only diagnostic fixes; `test`, `docs` and `chore` entries.

---

Review No Rule Items now shows why an email may be spam and adds a Create rule button. When an email's sender checks (SPF, DKIM, DMARC) did not fully pass, its pop-up marks one rule as "Suggested" and shows the exact rule and the reason; you still choose whether to apply it.

The No Rule list now updates by itself when you return to the app, so the emails a background scan just reported are already listed.

A Gmail scan that is stopped or fails part way no longer skips the mail it had not finished checking.

Gmail accounts: Google asks you to sign in again about once a week while the app is in testing. The app now notifies you, at most once a day per account, when an account needs that sign-in.

A Gmail label or mail folder that was renamed or deleted now shows as "Folder not found" on the Results screen, and Gmail remembers its place separately for each folder.

Reliability: a mail server that does not send a message ID can no longer cause the wrong message to be moved or deleted, and the optional diagnostic log no longer loses lines when several scans write at once.
