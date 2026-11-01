# Release notes -- 0.22.0 -- Microsoft Store

DERIVED 2026-10-27 (Sprint 81 cycle Phase 8.3, STORE_RELEASE_PROCESS.md Step 1b) from the finished CHANGELOG. The
provisional text written at Phase 3.7.0b was not re-derived at Phase 7.7 as it said; it is replaced here.

**Range**: everything after 0.21.0 (installed from the Store 2026-10-24): CHANGELOG `[Unreleased]` entries under
"Sprint 81" (2026-10-23, 2026-10-25, 2026-10-27).

**Excluded from this file**: the iOS project and iOS compile workflow (not shipped to Windows); the two Android-only
diagnostic fixes (new-mail diagnostic line, split log folder); `test`, `docs` and `chore` entries; the "Blocked TLD"
reason named in the 2026-10-23 F271 entry (the chip was removed before release, 2026-10-25).

---

Review No Rule Items now shows why an email may be spam (a Reply-To address on a different domain, a failed sender check, a lookalike domain, or bulk mail with no unsubscribe link) and adds a Create rule button that opens the rule screen for that sender.

Gmail accounts: Google asks you to sign in again about once a week while the app is in testing. The app now notifies you, at most once a day per account, when an account needs that sign-in and will not be scanned until you sign in again.

A Gmail label or mail folder that was renamed or deleted now shows as "Folder not found" on the Results screen instead of scanning zero messages, and Gmail remembers its place separately for each folder, so Spam and custom labels no longer skip waiting mail.

Reliability: a mail server that does not send a message ID can no longer cause the wrong message to be moved or deleted, and the optional diagnostic log no longer loses lines when several scans write at once.
