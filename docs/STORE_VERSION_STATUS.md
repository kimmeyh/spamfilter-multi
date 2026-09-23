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
| **Live/certified on Store** (cache) | 0.15.2.0 | 2026-09-21 (Partner Center: "Congrats! Your product is now updated"; Store presence = **Submission 28**, last modified 09/21/2026) | **Submission 28 -- 0.15.2**, built from the prod worktree on `main` at `a3f2031` after Step 3.0 found it 33 commits behind. Release self-test 6/6 PASS (APP_ENV=prod, NATIVE_APP_ENV=prod, both suffixes empty, no [DEV] marker, version matches). Publisher reads "Kimmey Consulting - Ohio", so the Submission 26 rejection cause is absent. **INSTALLED-BUILD VERIFIED**: the running Windows app title bar reads "Version 0.15.2" (Harold screenshot, 2026-09-21) -- the strongest form of evidence per Step 7, not merely a console claim. **Certification took ~2 days, the SLOWEST on record** (submitted 2026-09-19/20, certified 09-21) against a measured 20-30 min band for Submissions 17/18/19; still inside Microsoft's stated "up to 3 business days". No cause was ever visible -- Partner Center exposes stage, not reason. Submission 27 (0.15.1) was the prior Store presence. |
| **Live on Google Play** (cache) | 0.15.2 (versionCode 5) | 2026-09-21 (**DEVICE-VERIFIED**: Galaxy S24+ Settings > General reads "Version 0.15.2") | **Closed testing only -- NOT production.** **0.15.2 DEVICE-VERIFIED 2026-09-21** (S24+ Settings reads "Version 0.15.2"). This unblocks F219 AC-1 and the F227 re-verification, which still need an actual sign-in run. Hardware history, which applies to 0.15.0 and NOT to this version: Harold updated a Galaxy S24+ and it was an UPGRADE, not a fresh install (0.14.1 -> 0.14.2 -> 0.15.0), which exercises the real tester path and confirms package identity and signing key held across two bumps. F191 confirmed on device -- Yahoo and iCloud selectable in Add Account. **Corrected 2026-09-14**: this row was cached at 0.14.2 / versionCode 2 for four days after 0.15.0 went live, while calling itself a cache of the live state. Production access is still gated on 12 testers x 14 CONTINUOUS days -- a TESTER-COUNT gate, not a version gate. 8 on the list, FOUR SHORT. |
| **Dev worktree** (authoritative -- mirrors `pubspec.yaml`) | 0.16.0+7 | 2026-09-23 | Bumped at Sprint 69 PLAN APPROVAL (Phase 3.7.0b) per **F190**, so a tester can always tell a dev build from production. **PATCH is correct**: Sprint 69 shipped five fixes and no `feat` -- the one `feat` in `[Unreleased]` belongs to Sprint 68 and already shipped as 0.15.0. Build number +3 -> +4 because Play permanently consumes a versionCode once uploaded, and 3 went with the live 0.15.0. Two gates cover this row: `version_consistency_test` (every literal in lib/, windows/runner/ and scripts/ matches pubspec) and `dev_version_ahead_test` (dev strictly ahead of every Live row IN THIS FILE, and `version:` agrees with `msix_version`). That second gate is why a stale row here is a test defect rather than a documentation one. |

## msix_version convention (which worktree's value ships)

## 0.15.2 release -- COMPLETE ON BOTH STORES (2026-09-21)

**Microsoft Store: CERTIFIED AND LIVE 2026-09-21 as Submission 28.** Partner Center shows
"Congrats! Your product is now updated" and Store presence = Submission 28. The installed
Windows app reads "Version 0.15.2" in its title bar, so this is installed-build verified
rather than console-reported. Certification took ~2 days -- the slowest observed, against a
measured 20-30 min band -- with no reason ever surfaced by the console. MSIX built from the prod worktree at `a3f2031` after Step 3.0
found it **33 commits behind** -- the fourth consecutive sprint that check has caught a stale
worktree, and the failure is silent: everything builds and the new version number wraps old code.
Release self-test 6/6 PASS (APP_ENV=prod, NATIVE_APP_ENV=prod, both suffixes empty, no [DEV]
marker, version matches 0.15.2). Publisher reads "Kimmey Consulting - Ohio", so the Submission 26
rejection cause is absent.

**Google Play: PUBLISHED 2026-09-20, DEVICE-VERIFIED 2026-09-21.** **Step 6 COMPLETE** -- the
Galaxy S24+ Settings > General reads "Version 0.15.2", and a real testing session on that build
confirmed F212, F220 and F221 all behaving correctly. One new defect found: F228 (the
"could not be applied" footer contradicts the mailbox after a batch-level exception).

Observed on the 0.15.2 build during a real testing session, 2026-09-20 22:21-22:26:

- **F212 works**: "No rule" went 12 -> 10 -> 0, the emails were deleted, and the new block rules
  were named on each row. This was the sprint's headline fix and it holds on a Play-signed build.
- **F220 / F221 work**: a live manual scan progressed normally ("Scanning... 0 of 115"), with no
  wedge and no stuck in-progress rows. Background scans completed and posted notifications.
- **Per-scan Errors: 0.** The Scan History screen shows a cumulative **"Errors: 111"**, which is a
  LIFETIME counter and not a current fault. Recorded because it reads alarming at a glance; do not
  re-diagnose it as a defect.
- **Version confirmation needed a purpose-taken screenshot**, because none of the 26 screenshots
  from the session showed a version at phone width. That is now filed as F229.

Build provenance, verified before upload:

- Path: `D:\Data\Harold\github\spamfilter-multi\mobile-app\build\app\outputs\bundle\prodRelease\app-prod-release.aab`
- 66.9 MB, valid bundle (548 entries, base module present)
- **versionCode 5, versionName 0.15.2** -- read from the bundle's own protobuf manifest, not
  inferred from pubspec. Live Play is versionCode 3, so 5 is correctly ahead. Play permanently
  consumes a versionCode once uploaded, which is why this must be verified before upload rather
  than after a rejection.
- Signed with the **UPLOAD** key (`META-INF/UPLOAD.RSA`). Correct: Play re-signs with the app
  signing key on ingest. Do not confuse the two fingerprints -- that mistake was nearly made in
  Sprint 69 and was caught only because Harold sent the Console page showing both.
- Package `com.myemailspamfilter` (prod flavor, NOT the `.dev` suffix).
- **`integration_test` entries in the release bundle: 0.** Worth stating, because the F218
  workaround re-adds that dependency to the release classpath and the whole point of the card was
  that it was shipping a test-only library to testers. It is not in this bundle.

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
