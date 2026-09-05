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
| **SUBMITTED, IN CERTIFICATION** | 0.14.0.0 | 2026-09-05 12:01am ET (Harold: "submitted for certification") | Submission 21. MSIX 17.1 MB, built + verified 2026-09-04 (Check A dart-defines present; `--release-self-test --expected-version=0.14.0` RESULT: PASS on all 6 checks; manifest Version=0.14.0.0). Release notes from `docs/store-assets/RELEASE_NOTES_0.14.0.md`. **SUBMITTED IS NOT LIVE** -- 0.13.0.0 remains the live version until Partner Center says otherwise. Check Partner Center, never this file. |
| **Live/certified on Store** (cache) | 0.13.0.0 | 2026-08-27 ~10:55pm ET (direct Partner Center observation + INSTALLED-BUILD CHECK: Harold's Settings screenshot shows Version 0.13.0, no [DEV] marker -- the strongest verification class) | Submission 20, uploaded ~7:0x am ET 2026-08-27; certification completed sometime before the evening check (single-shot observation -- true elapsed unmeasured, likely the usual 20-30 min band). Seventh MINOR release (Sprint 63 feat entries F180/F94/F181). Superseded 0.12.0.0/Submission 19. |
| **Dev worktree** (authoritative -- mirrors `pubspec.yaml`) | 0.14.0+1 | 2026-09-04 | Bumped MINOR (0.13.0 -> 0.14.0) at the 0.14.0.0 release Step 1 on `feature/20260904_Sprint_65` (Sprint 64's `feat` entry: F186 Body Phrase rule type), per the enforced semver policy. Post-F-VERSION-DERIVE the bump is the two pubspec fields only (gate-verified, zero literals). |

## msix_version convention (which worktree's value ships)

**Store MSIX builds ALWAYS come from the PROD worktree** (`D:\Data\Harold\github\spamfilter-multi-prod\`), whose `msix_config.msix_version` is bumped **locally and uncommitted** at each release (F139-template Step 1) and verified by the release checks (build-log dart-defines + `--release-self-test --expected-version`). The DEV worktree's committed `msix_version` is therefore **never a Store build input** -- which is how it sat harmlessly stale at `0.6.0.0` from the 0.6.0 release until Sprint 59 refreshed it to `0.8.1.0` (matching the dev app version, per `STORE_RELEASE_PROCESS.md` Step 1 row 2). Concretely: Submission 14 shipped `0.7.0.0` and Submission 15 shipped `0.8.0.0`, both from prod-worktree-local values, regardless of the dev worktree's committed number. Neither `check-version-consistency.ps1` nor the version gate watches `msix_version` today -- tracked as backlog (metadata-under-gates item, Sprint 59 cowork review).

## Update this file every time

- **A Store submission certifies** -- update the Store row: version, date verified, submission number, and who/how it was verified (Partner Center screenshot, installed-build check, etc.).
- **`pubspec.yaml`'s top-level `version:` changes** -- update the Dev row to match. This should be nearly automatic since it is a direct mirror; if this row and `pubspec.yaml` ever disagree, `pubspec.yaml` wins and this file is wrong.

## Known client-side propagation lag (not our defect)

After a submission certifies and Partner Center confirms it live, the Store app UI (product detail page renders as skeleton placeholders, same as the 2026-07-28 incident -- reproduces on third-party listings too) and `winget upgrade`/`winget install --source msstore` (reports "No available upgrade found" even though Partner Center confirms the new version is live) can both lag behind the actual certified state. This happened again on the 0.5.9.0 release (2026-08-03), same day as certification. Partner Center's "Store presence" section is the authoritative signal -- if it shows the product "currently available" at the target version, treat it as live regardless of what the Store client or winget currently report.

**Workaround that resolved it (2026-08-03)**: `winget uninstall --id 9N5QK9G904C0` followed by `winget install --id 9N5QK9G904C0 --source msstore --accept-package-agreements --accept-source-agreements` forces a fresh acquisition rather than an upgrade-check, and this pulled the correct current version even while `winget show`/`winget upgrade` still reported stale metadata (`Version: Unknown`, "No available upgrade found"). No need to wait out the lag if you need the new version installed immediately -- the uninstall/reinstall bypasses it. (Note: the Store app's own "Get Updates"-style button, if one exists, was not verified in this incident and should not be assumed present without checking the actual UI first.)

## Related

- `docs/STORE_RELEASE_PROCESS.md` -- full release procedure; Step 7 (Post-Submission) updates this file when certification completes.
- `.claude/sprint_status.json` `store_release` block -- session-restore detail (in-flight submission notes, verification evidence, troubleshooting history). This file is the short-answer summary; that block is the working detail. Keep both in sync, but this file is what to open for a quick "what's live" check.
