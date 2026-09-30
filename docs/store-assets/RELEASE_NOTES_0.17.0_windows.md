# Release notes -- 0.17.0 -- Microsoft Store

**Re-derived at Sprint 74 Phase 7.7 (2026-09-29) from the finished CHANGELOG** (STORE_RELEASE_PROCESS.md
Step 1b). No entry carries a platform tag, so every Sprint 74 entry applies to both stores.

**Range**: everything after the last version this store received (0.16.0, submitted 2026-09-24).

**Not yet submitted -- RELEASE HOLD.** Harold, 2026-09-27: 0.17.0 does not ship until the "stop the
background scan and start mine" action lands (Sprint 75). If Sprint 75 bumps the version before
release, these notes carry forward into that version's notes.

**Excluded from this file** (engineering or Android-only detail, not a Windows user change): the
Android export-folder fallback, the Android YAML export fix, the Android background export setting,
separate development/production diagnostic logs.

---

Scan results are easier to work through. Each email shows the date it arrived, and a new Sort
button switches between the usual order (folder, then sender domain, then sender address) and
newest first.

Adding a rule or safe sender while reviewing a saved scan works again. It used to fail for every
email.

Only one scan runs on an account at a time, whether you started it or it runs in the background.
A scan that stops responding is closed so the next one can start, instead of showing
"In progress" for hours. If a scan is already running, the app tells you.

New accounts start with the right folders for their email provider, including its spam folder.
A folder that does not exist on your account is skipped instead of reported as an error.

A Gmail account keeps its sign-in when a renewal fails, instead of showing "Missing credentials".
Gmail emails also show the date they arrived, not the time of the scan.

Exports go to your Downloads folder unless you choose another, are off by default after each scan,
can hide sender details, and Scan History can be cleared.

Manage Rules labels subject rules correctly.
