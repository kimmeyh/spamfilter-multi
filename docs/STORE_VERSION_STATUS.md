# Store Version Status

**This file is a CACHE, not a source of truth.** The dev version below is
authoritative (it mirrors `mobile-app/pubspec.yaml`, which lives in git). The
STORE versions are NOT authoritative here -- **Microsoft Partner Center and the
Google Play Console are the only sources of truth** for what is actually
certified/live on their respective stores, and git has no visibility into
either. This file is a timestamped snapshot of the last time someone actually
looked.

**Two stores since 2026-09-09** (ADR-0043: one version across platforms, which
may advance without being submitted everywhere). The two rows can legitimately
disagree, and a version live on one store says nothing about the other.

**Before treating the Store row below as current fact, re-verify in Partner
Center**: https://partner.microsoft.com/dashboard/products/9N5QK9G904C0/submissions
This exact failure already happened once -- a stale value in
`.claude/sprint_status.json` was read and repeated as present-tense fact for a
full day before being caught. Do not repeat it here. If this file's date is
more than a few days old, or a submission may have completed since, check
Partner Center before saying anything about the Store version.

| | Version | Last verified | Notes |
|---|---|---|---|
| **Live/certified on Store** (cache) | 0.14.2.0 | 2026-09-09 (Partner Center: "Congrats! Your product is now updated"; Store presence = **Submission 25**, last modified 09/09/2026; product confirmed "currently available in the Microsoft Store") | **Submission 25 -- 0.14.2**, built from the prod worktree on `main` at `9e0e515` (PR #397). Carries the Sprint 67 UI fixes (F194 scan-status icons, F195 account-header contrast) plus the F199 listing-field edits (Copyright / Developed by -> Kimmey Consulting LLC), folded into this submission rather than paying a separate listing-only certification pass. **NOT yet verified by installing from the Store** -- the cached value above it was, and this one is Partner-Center-only so far. Do that before treating the installed-build behavior as confirmed. |
| **Live on Google Play** (cache) | 0.14.2 (versionCode 2) | 2026-09-09 (Play Console notification: "App update published. Users should see changes immediately"; Closed testing - Alpha track) | **Closed testing only -- NOT production.** 0.14.2 cleared review and is live to the closed-test track the same day it was submitted; 0.14.1 was the prior release (Sep 8, 2:00 PM). Production access is still gated on 12 testers x 14 CONTINUOUS days, which is a TESTER-COUNT gate, not a version gate -- shipping a new version does not advance it. Play is the source of truth here, same rule as the Store row above. |
| **Dev worktree** (authoritative -- mirrors `pubspec.yaml`) | 0.14.1+1 | 2026-09-08 | Bumped PATCH (0.14.0 -> 0.14.1) at Sprint 66 PLAN APPROVAL, not at release -- the first bump under **F190**, which moved it from Store-release Step 1 to Phase 3.7.0b so a tester can always tell a dev build from production. PATCH is correct because `[Unreleased]` contains no `feat` (3 chore, 6 docs, 1 fix), per the enforced semver policy. Two gates cover it: `version_consistency_test` (every literal matches pubspec) and `dev_version_ahead_test` (dev strictly ahead of the last released version, and `version:` agrees with `msix_version`). Post-F-VERSION-DERIVE the bump is the two pubspec fields only. Release Step 1 is now VERIFICATION, not a bump. |

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
