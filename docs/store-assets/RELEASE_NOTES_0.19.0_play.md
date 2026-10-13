# Release notes -- 0.19.0 -- Google Play

Re-derived 2026-10-13 (Sprint 78 cycle, Phase 8.3) from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b,
GOOGLE_PLAY_RELEASE_PROCESS.md Step 2), replacing the provisional text written at plan approval.

**Range**: everything after 0.18.0 (versionCode 15, closed testing). This build is versionCode 16.

**Excluded from this file**: dev-build-only features (content history, R76-4), test tooling and policy gates,
Windows-only fixes (the export fallback to the app's AppData folder), the internal deletion-path fix, and smaller
items cut to fit 500 characters (pop-up colors, dimmed provider buttons, the hidden authentication warning, the
reload banner) -- the Windows notes carry them.

Paste the en-US block below into the Play Console release-notes field, tags included.

---

<en-US>
Background scans no longer run about twice per interval, which saves battery.

Files the app saves now go to one folder: MyEmailSpamFilter in Documents.

Review No Rule Items works like the Results screen: search, filters, sort and email details.

"Scan every" now offers 5 minutes to 24 hours.

Fixes: no blank list after adding a rule, failed scans no longer show "In progress", and the search text is readable in the dark theme.
</en-US>
