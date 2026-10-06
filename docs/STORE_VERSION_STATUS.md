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
| **Live/certified on Store** (cache) | 0.17.0.0 | 2026-10-04 ~11:20pm ET (Harold: "both live", from Partner Center; installed Store build shows title "MyEmailSpamFilter" with NO [DEV] and header "Version 0.17.0" -- Check C title/version half) | Built from the prod worktree at `main` e724faa; self-test PASS. Submitted ~10:40pm ET. The PUBLIC Store product API still showed the 0.16.0 listing (LastUpdateDateUtc 2026-09-24) at 11:14pm and 11:2x -- the known certification-day propagation lag; Partner Center is authoritative. Gmail sign-in URL check (Step 4.2) not yet reported. Previous: 0.15.2.0 (Submission 28, 2026-09-21); 0.16.0 submitted 2026-09-24. |
| **Live on Google Play** (cache) | 0.17.0 (versionCode 8) | 2026-10-04 ~11:20pm ET (**DEVICE-VERIFIED**: Fold screenshots 23:20-23:25 read "Version 0.17.0" on every screen; Harold: "both live") | **Closed testing (Alpha) only -- NOT production.** versionCode 8 confirmed by the console at upload ("8 (0.17.0)", target SDK 36). A first draft was lost; re-attached from the library. **Device finding**: the F238 stop did NOT stop an AOL background scan stuck at Found 0 (see Sprint 76 plan). Previous: 0.16.0 (versionCode 7, 2026-09-24). |
| **Dev worktree** (authoritative -- mirrors `pubspec.yaml`) | 0.17.6+14 | 2026-10-06 | Bumped mid-Sprint 76: 0.17.5 (versionCode 13) was already uploaded to Play closed testing (Harold, 2026-10-06) when the scan-export header row landed. PATCH. versionCode 14. Gates: `version_consistency_test`, `dev_version_ahead_test`. |

## 0.17.0 -- RELEASE HOLD (Harold, 2026-09-27)

**0.17.1 (versionCode 9) -- GOOGLE PLAY CLOSED TESTING: SUBMITTED 2026-10-05 ~12:45am ET** (Harold's Publishing overview screenshot: "Changes in review", Closed testing - Alpha, 9 (0.17.1) Start full rollout, quick checks running; managed publishing off). Sprint 76 diagnostic build (F248 log, F249 part 1). Artifact verified from the file: versionName 0.17.1, versionCode 9, targetSdk 36, no `.dev`, OAuth scheme present, AD_ID absent, 67.2 MB. Not yet observed live. Microsoft Store: not submitted (Harold's call at release).

**MICROSOFT STORE: SUBMITTED FOR CERTIFICATION 2026-10-04 ~10:40pm ET** (Harold's report; not yet observed live -- the public Store product API still showed the 0.16.0 listing, LastUpdateDateUtc 2026-09-24T12:51:35Z, at 10:41pm). **Google Play: upload not yet reported.**

**BUILT + VERIFIED (2026-10-04, Sprint 75 cycle Phase 8.3)** -- record a submission only after seeing it in each console:
- **MSIX 0.17.0.0**: prod worktree pulled to `main` e724faa (it was 74 commits behind); `msix:create` log shows `--dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json`; `--release-self-test --expected-version=0.17.0` RESULT: PASS (6/6); manifest Identity `Version="0.17.0.0"`; 18.4 MB. `D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\build\windows\x64\runner\Release\my_email_spam_filter.msix`. Open: Step 4.2 / Check C (Gmail sign-in URL and About screen on an installed build).
- **AAB 0.17.0 (versionCode 8)**: built from the dev worktree (app code identical to `main`); read FROM THE ARTIFACT: versionName 0.17.0, versionCode 8, targetSdk 36, minSdk 24, package `com.myemailspamfilter` (no `.dev`), Gmail OAuth scheme present, `AD_ID` absent; 67.2 MB. `D:\Data\Harold\github\spamfilter-multi\mobile-app\build\app\outputs\bundle\prodRelease\app-prod-release.aab`. Open: confirm versionCode 8 is unused in Play Console's App bundle explorer (the superseded 2026-09-25 AAB also carried +8).

**HOLD SATISFIED (2026-10-04)**: F238 shipped in Sprint 75 (PR #448, Manual Validation PASS on Windows). 0.17.0 may be built from `main` after #448 and the develop -> main merge. Build a NEW AAB; the 2026-09-25 one stays superseded. Release notes re-derived: `docs/store-assets/RELEASE_NOTES_0.17.0_windows.md` and `_play.md`.

**0.17.0 is NOT submitted to either store until F238 (Issue #441, Sprint 75) ships** -- the
"stop the background scan and start mine" action. Harold: *"0.17.0 cannot ship without a fix"*,
*"it is the largest bug that we have."* **No AAB is built until BOTH the Sprint 74 and Sprint 75
PRs are merged.** The 0.17.0+8 AAB built on 2026-09-25 is superseded and must not be uploaded.

**VERSION EXCEPTION (Harold, 2026-10-02)**: Sprint 75 does NOT bump the version -- *"no store release was done after the last sprint, so keep 0.17.0 for this sprint (note as an exception)"*. The release carrying F238 is therefore **0.17.0**, not 0.18.0 (this supersedes the 0.18.0 wording below).

**Re-confirmed by Harold, 2026-10-02 (option 1): keep the hold.** The next store release ships AFTER Sprint 75, with F238 included, under Sprint 75's version (0.18.0 after the plan-approval bump). The 0.17.0 notes carry forward into it. Weighed against: 0.16.0 (live) still has colliding scans, failing rule adds from saved scans, Gmail "Missing credentials" and the Android YAML export failure; 0.17.0 fixes those but has the F238 dead end on BOTH platforms.

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
