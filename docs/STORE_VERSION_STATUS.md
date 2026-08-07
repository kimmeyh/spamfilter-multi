# Store Version Status

**This file is a CACHE, not a source of truth.** The dev version below is
authoritative (it mirrors `mobile-app/pubspec.yaml`, which lives in git). The
Store version is NOT authoritative here -- Microsoft Partner Center is the only
source of truth for what is actually certified/live, and git has no visibility
into it. This file is a timestamped snapshot of the last time someone actually
looked.

**Before treating the Store row below as current fact, re-verify in Partner
Center**: https://partner.microsoft.com/dashboard/products/9N5QK9G904C0/submissions
This exact failure already happened once -- a stale value in
`.claude/sprint_status.json` was read and repeated as present-tense fact for a
full day before being caught. Do not repeat it here. If this file's date is
more than a few days old, or a submission may have completed since, check
Partner Center before saying anything about the Store version.

| | Version | Last verified | Notes |
|---|---|---|---|
| **Live/certified on Store** (cache) | 0.5.9.0 | 2026-08-03 (Harold, Store-INSTALLED build via `winget install`: no `[DEV]` in header or Settings, Settings shows "Version 0.5.9") | Submission 10, certified and published 2026-08-03. Submission 11 auto-opened as the next draft slot (normal Partner Center behavior, not a new release in progress) -- shows the same v0.5.9.0 package "Unchanged". This is the strongest possible verification: the actual Store-signed, Store-distributed package, freshly installed and directly observed clean. |
| **Dev worktree** (authoritative -- mirrors `pubspec.yaml`) | 0.5.10+1 | 2026-08-03 | Post-cert patch+1 bump applied per ADR-0035 convention (Sprint 53 close-out, PR #298). `msix_version` deliberately left at `0.5.9.0` until the next release build. |

## Update this file every time

- **A Store submission certifies** -- update the Store row: version, date verified, submission number, and who/how it was verified (Partner Center screenshot, installed-build check, etc.).
- **`pubspec.yaml`'s top-level `version:` changes** -- update the Dev row to match. This should be nearly automatic since it is a direct mirror; if this row and `pubspec.yaml` ever disagree, `pubspec.yaml` wins and this file is wrong.

## Known client-side propagation lag (not our defect)

After a submission certifies and Partner Center confirms it live, the Store app UI (product detail page renders as skeleton placeholders, same as the 2026-07-28 incident -- reproduces on third-party listings too) and `winget upgrade`/`winget install --source msstore` (reports "No available upgrade found" even though Partner Center confirms the new version is live) can both lag behind the actual certified state. This happened again on the 0.5.9.0 release (2026-08-03), same day as certification. Partner Center's "Store presence" section is the authoritative signal -- if it shows the product "currently available" at the target version, treat it as live regardless of what the Store client or winget currently report.

**Workaround that resolved it (2026-08-03)**: `winget uninstall --id 9N5QK9G904C0` followed by `winget install --id 9N5QK9G904C0 --source msstore --accept-package-agreements --accept-source-agreements` forces a fresh acquisition rather than an upgrade-check, and this pulled the correct current version even while `winget show`/`winget upgrade` still reported stale metadata (`Version: Unknown`, "No available upgrade found"). No need to wait out the lag if you need the new version installed immediately -- the uninstall/reinstall bypasses it. (Note: the Store app's own "Get Updates"-style button, if one exists, was not verified in this incident and should not be assumed present without checking the actual UI first.)

## Related

- `docs/STORE_RELEASE_PROCESS.md` -- full release procedure; Step 7 (Post-Submission) updates this file when certification completes.
- `.claude/sprint_status.json` `store_release` block -- session-restore detail (in-flight submission notes, verification evidence, troubleshooting history). This file is the short-answer summary; that block is the working detail. Keep both in sync, but this file is what to open for a quick "what's live" check.
