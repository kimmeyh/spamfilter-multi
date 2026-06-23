# Microsoft Store Release Process

**Purpose**: End-to-end runnable checklist for shipping a new version of MyEmailSpamFilter to the Microsoft Store.

**Audience**: Any team member. The procedure should be followable without asking Harold.

**Scope**: Windows desktop MSIX builds submitted to Microsoft Partner Center. Android/iOS store releases are out of scope.

**Status**: Sprint 36 (2026-04-21) -- first version of this doc. Captures the procedure used for the 0.5.2.0 submission (Sprint 35, 2026-04-20) plus the three silent-failure gaps surfaced during that rebuild.

**Related docs**:
- `docs/adr/0035-production-development-side-by-side.md` -- why production and development builds coexist with different data directories.
- `CLAUDE.md` -- Common Commands / Windows Development section for day-to-day dev builds (separate from store release).

---

## Table of Contents

- [Pre-Release Checklist](#pre-release-checklist)
- [Step 1: Version Bump](#step-1-version-bump)
- [Step 2: Recreate secrets.prod.json](#step-2-recreate-secretsprodjson-if-missing-from-prod-worktree)
- [Step 3: Build the MSIX](#step-3-build-the-msix)
- [Step 4: Verify the MSIX](#step-4-verify-the-msix)
- [Step 5: Merge develop -> main](#step-5-merge-develop---main-harold-only)
- [Step 6: Upload to Microsoft Partner Center](#step-6-upload-to-microsoft-partner-center)
- [Step 7: Post-Submission](#step-7-post-submission)
- [Troubleshooting](#troubleshooting)

---

## Pre-Release Checklist

Before starting a store release, confirm all of these:

- [ ] `develop` branch is green: `flutter test` passes, `flutter analyze` has 0 issues.
- [ ] Most recent sprint retrospective is complete (Phase 7 done, `docs/sprints/SPRINT_N_RETROSPECTIVE.md` committed).
- [ ] Target version is chosen. By convention we release from production worktree at `X.Y.Z.0` and dev is always `X.Y.(Z+1).0` (per ADR-0035 patch+1).
- [ ] `docs/ALL_SPRINTS_MASTER_PLAN.md` "Last Completed Sprint" is up to date.
- [ ] CHANGELOG.md entries for the version are assembled under `## [Unreleased]` ready to move under a versioned heading.

If any of the above are not true, complete them before proceeding. A store release is not the place to cut corners.

---

## Step 1: Version Bump

The version string is referenced in **5 files** in the dev worktree. Miss any one and the MSIX version, the in-app "About" screen, and the background-scan log filename can drift.

**Operate in the dev worktree** (`D:\Data\Harold\github\spamfilter-multi\`) on the `feature/YYYYMMDD_Sprint_N` branch for the current sprint. The version bump is a Sprint 36-style kickoff commit that lands first on develop, then gets merged to main during the release itself.

Target version fields (example: bumping dev from `0.5.2.0` to `0.5.3.0`):

| # | File | String to update |
|---|------|------------------|
| 1 | `mobile-app/pubspec.yaml` | Top-level `version: 0.5.2+1` -> `0.5.3+1` |
| 2 | `mobile-app/pubspec.yaml` | `msix_config.msix_version: 0.5.2.0` -> `0.5.3.0` |
| 3 | `mobile-app/lib/main.dart` | `background_scan_v0.5.2.log` -> `background_scan_v0.5.3.log` in the log path |
| 4 | `mobile-app/lib/ui/screens/settings_screen.dart` | `'Version 0.5.2${AppEnvironment.displaySuffix}'` -> `'Version 0.5.3${AppEnvironment.displaySuffix}'` |
| 5 | `mobile-app/lib/core/services/background_scan_windows_worker.dart` | `background_scan_v0.5.2.log` -> `background_scan_v0.5.3.log` |

Plus `CLAUDE.md` (Windows App Data Directory section + Version line) if the comment examples mention the old version.

**Note**: The dev worktree version is always `patch+1` relative to the last prod release. At release time the prod worktree's `pubspec.yaml` gets bumped to the dev version *minus 1* -- for example, when dev is at `0.5.3`, the release itself ships from prod at `0.5.3.0` and immediately after, dev bumps to `0.5.4`.

Commit the version bump as `chore: version bump X.Y.Z.0 -> X.Y.(Z+1).0` on the sprint feature branch.

---

## Step 2: Recreate secrets.prod.json (if missing from prod worktree)

The project uses a **single shared Gmail OAuth Desktop client** for both dev and prod builds. If `mobile-app/secrets.prod.json` is missing from the prod worktree (it is `.gitignore`d and can be deleted/lost when rebuilding the worktree), recreate it by copying from the dev worktree.

**From the dev worktree**:

```powershell
# Verify dev secrets exist
Get-Content D:\Data\Harold\github\spamfilter-multi\mobile-app\secrets.dev.json | Select-Object -First 1

# Copy to prod worktree
Copy-Item D:\Data\Harold\github\spamfilter-multi\mobile-app\secrets.dev.json `
          D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\secrets.prod.json
```

**Required keys** (see `mobile-app/secrets.prod.json.template`):

| Key | Source |
|-----|--------|
| `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` | Google Cloud Console -> APIs & Services -> Credentials -> OAuth 2.0 Client IDs -> Desktop client. Ends with `.apps.googleusercontent.com`. |
| `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` | Same Google Cloud Console entry. Download client secret JSON and copy `client_secret` field. |
| `GMAIL_REDIRECT_URI` | `http://localhost:8080/oauth/callback` (constant) |
| `AOL_EMAIL` / `AOL_APP_PASSWORD` | Optional. Only needed if building with AOL credentials for testing. |

**Do NOT use the incorrect key names** (`GMAIL_DESKTOP_CLIENT_ID`, `GMAIL_OAUTH_CLIENT_SECRET`) -- those were in the template pre-Sprint 36 and cause the build to silently ship with empty credentials. The runtime code in `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart` reads `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` (with a fallback to the old name for dev compatibility).

---

## Step 3: Build the MSIX

**Operate in the prod worktree** (`D:\Data\Harold\github\spamfilter-multi-prod\`) on the `main` branch *after* the develop -> main merge. (We usually merge first, then build -- but if you prefer to sanity-check the MSIX pre-merge, build from a local `main` with develop merged in and discard the working tree after upload.)

**Supported command** (the only path that injects dart-defines correctly):

```powershell
cd D:\Data\Harold\github\spamfilter-multi-prod\mobile-app
flutter clean
flutter pub get
flutter pub run msix:create
```

**Why this specific invocation**: `msix:create` runs `flutter build windows` internally and does **not** inherit any `--dart-define` flags from its own command line. The OAuth credentials are injected via the `build_windows_args` field inside `msix_config` in `pubspec.yaml`:

```yaml
msix_config:
  ...
  msix_version: 0.5.3.0
  ...
  build_windows_args: --dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json
  store: true
  install_certificate: false
```

Without the `build_windows_args` line, the MSIX builds successfully, the manifest looks correct, and the installed app silently fails at runtime when the user tries to sign in to Gmail because `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` is empty. There is no visible error during the build. **This is the single most dangerous failure mode in the release process** -- verify the field is present (Step 4 below) every time.

**Do NOT use `mobile-app/scripts/build-msix.ps1`**. That script uses a separate makeappx.exe code path that does not inject dart-defines, and any MSIX built with it will ship with empty OAuth credentials. It was deprecated in Sprint 36; the file header now notes this.

**Output**: `mobile-app/build/windows/x64/runner/Release/my_email_spam_filter.msix` (approx 16-17 MB).

---

## Step 4: Verify the MSIX

Run these three checks before uploading. Skipping any one has historically caused a failed submission or a user-visible runtime bug.

### 4.1 Verify manifest version

```powershell
cd D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\build\windows\x64\runner\Release

# Extract the AppxManifest.xml from the MSIX
Expand-Archive -Path my_email_spam_filter.msix -DestinationPath .\msix_unpack -Force

# Grep the version
Select-String -Path .\msix_unpack\AppxManifest.xml -Pattern 'Version="'
```

The `Identity` element's `Version` attribute should match the target (`0.5.3.0`). Clean up `msix_unpack/` after verification.

### 4.2 Verify OAuth credentials are embedded

The dart-define values end up as UTF-16 strings inside the packaged `flutter_assets/kernel_blob.bin` or embedded in the compiled executable. The simplest sanity check is to:

1. Install the MSIX locally: `Add-AppxPackage .\my_email_spam_filter.msix` (requires a code-signing certificate or dev mode enabled).
2. Launch the app.
3. Attempt Gmail sign-in.
4. Confirm the OAuth browser page opens with the real client ID in the URL (`client_id=577022808534-...` or your project's desktop client ID).

If the browser URL shows `client_id=` with an empty or placeholder value, the `build_windows_args` line in `pubspec.yaml` was missing or `secrets.prod.json` was missing. Rebuild from Step 3.

### 4.3 Verify size and structure

```powershell
Get-Item my_email_spam_filter.msix | Format-List Name, Length, LastWriteTime
```

Expected size: ~16-17 MB. A size below 5 MB or above 50 MB is suspicious -- investigate before uploading.

---

## Step 5: Merge develop -> main (Harold only)

Per `CLAUDE.md` branch policy, **only Harold** creates PRs from develop to main. This step documents what Harold does; other team members skip to Step 6 with an already-merged main.

```powershell
cd D:\Data\Harold\github\spamfilter-multi
git checkout main
git pull origin main
git merge develop --no-ff -m "chore: release X.Y.Z.0"
git push origin main
git checkout develop
```

Then pull `main` into the prod worktree:

```powershell
cd D:\Data\Harold\github\spamfilter-multi-prod
git fetch
git checkout main
git pull origin main
```

Now the prod worktree is ready for Step 3 (build MSIX).

---

## Step 6: Upload to Microsoft Partner Center

1. Navigate to https://partner.microsoft.com/dashboard/ and sign in.
2. Apps and games -> select **MyEmailSpamFilter** (product name; ID is stable across submissions).
3. On the app overview, click **Start update** (or "Create a new submission" the first time).
4. The submission form has 4 sections. For a routine version update, only the **Packages** section needs changes; the other three (Pricing and availability, Properties, Store listings) carry over from the previous submission.
5. **Packages** section:
   - Click **Add packages** (or drag-drop the `.msix`).
   - Wait for cert + validation. Takes 1-3 minutes. If validation fails, fix the MSIX per the error message (most common: version number already used -- go back to Step 1 and bump again).
   - Confirm the version number shown matches the target.
6. Leave the other sections untouched unless you have specific release-note or metadata updates.
7. Click **Submit for certification** (bottom of overview page).
8. Microsoft runs automated + manual review. Turnaround is usually 24-72 hours.

**Submission artifact path** (for future reference / sprint documentation):

```
D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\build\windows\x64\runner\Release\my_email_spam_filter.msix
```

Include the size and version in the sprint retrospective store-submission section.

---

## Step 7: Post-Submission

Within 24 hours of submission:

- [ ] Partner Center shows submission status = "In certification" or further along. If stuck at "Preliminary review" past 24h, investigate.
- [ ] Note the submission timestamp in the sprint retrospective (close-out addendum if the sprint is already closed).

When certification completes:

- [ ] **If passed**: App is live on the Store within a few hours. Download the Store version on a test machine, sign in, confirm the OAuth flow works end-to-end, confirm the About screen shows the new version.
- [ ] **If failed**: Partner Center emails the contact account with a rejection reason. Common reasons:
  - Missing privacy policy URL -> update in Store listings.
  - Accessibility issue -> fix and resubmit (does not require a version bump if the fix is UI-only and the MSIX is rebuilt from the same source version).
  - Functional failure during review -> fix, bump version (Store does not accept the same version twice), resubmit.
- [ ] Update `docs/ALL_SPRINTS_MASTER_PLAN.md` "Last Completed Sprint" with store release outcome.
- [ ] Bump dev worktree to the next patch version (per Step 1, run Step 1 again with dev now one version ahead of prod).
- [ ] Move the CHANGELOG `[Unreleased]` entries under a new `## [X.Y.Z] - YYYY-MM-DD` section and update comparison links.

---

## Troubleshooting

### "No SOURCES given to target: MyEmailSpamFilter" during `flutter pub run msix:create`

**Cause**: `mobile-app/windows/runner/runner.exe.manifest` is missing. The Windows CMakeLists references it directly in `add_executable`.

**Fix**: Sprint 36 corrected the root `.gitignore` to scope `*.manifest` to `Archive/` only and committed `runner.exe.manifest`. If you are on an old branch or checkout where this has not been pulled in, copy the file from a working checkout or pull the Sprint 36 fix.

### Gmail sign-in fails on installed MSIX; OAuth URL shows empty client_id

**Cause**: `build_windows_args` missing from `msix_config` in `pubspec.yaml`, OR `secrets.prod.json` missing/malformed.

**Fix**:
1. Verify `pubspec.yaml` line: `build_windows_args: --dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json`
2. Verify `secrets.prod.json` has `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` (not the old `GMAIL_DESKTOP_CLIENT_ID` key).
3. Rebuild from Step 3.

### Partner Center rejects MSIX: "Version already submitted"

**Cause**: The version in `msix_config.msix_version` matches an already-submitted MSIX (including rejected ones).

**Fix**: Bump the version (Step 1) and rebuild. Microsoft does not allow version reuse even after rejection.

### `flutter pub run msix:create` succeeds but no .msix file appears

**Cause**: Typically build failure silently swallowed. Run `flutter build windows --release` directly first to see the actual error.

---

## Appendix: Product Identity (Reference)

From `mobile-app/pubspec.yaml` `msix_config`:

| Field | Value |
|-------|-------|
| display_name | MyEmailSpamFilter |
| publisher_display_name | Kimmey Consulting - Ohio |
| identity_name | KimmeyConsulting-Ohio.MyEmailSpamFilter |
| publisher | CN=84EA8722-0CA5-4EC0-9B10-07EE79B66062 |
| logo_path | assets/icon/icon.png |
| capabilities | internetClient, internetClientServer, privateNetworkClientServer |
| store | true |
| install_certificate | false |

These fields rarely change between releases. Do not edit them unless the publisher identity is being reissued.
