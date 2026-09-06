# Google Play Developer Account Setup (GP-16)

## ACCOUNT CREATED (Sprint 64, 2026-08-28)

- **Developer name (public)**: Kimmey Consulting, Ohio (matches the Microsoft Store
  publisher identity)
- **Account type**: Personal | **Account ID**: 6597324007880348667
- **Developer Google account**: myemailspamfilter.dev@gmail.com (dedicated account created
  same night; 2-Step Verification ON; Gmail auto-forwards to Harold's personal address --
  spam is NOT forwarded, check the dedicated spam folder during verification windows)
- **Public developer email**: myemailspamfilter.dev@gmail.com (deliberately the dedicated
  address, not the personal one)
- **Private contact email/phone**: Harold's personal (OTP-verified at signup; phone
  verification completes AFTER identity approval per the console)
- **Signup walkthrough deviations from this guide**: signup asked for a Website
  (identity-verification aid, not shown publicly) -- used the Microsoft Store listing
  https://apps.microsoft.com/detail/9N5QK9G904C0; an "About you" experience questionnaire
  and sensitive-app-categories checklist (None of the above) were presented; contact phone
  field requires strict E.164 with no spaces (+1216...).
- **Verification state at creation**: 3 pending -- (1) identity (ID upload; multi-day
  Google review = the critical path), (2) Android device access via the Play Console app,
  (3) contact phone (auto-unlocks after identity approval). App creation is LOCKED until
  verifications complete ("Create app" greyed out).
- **VERIFICATIONS CLEARED same session (2026-08-28, ~30-60 min after ID submission)**: the
  console home shows no setup banner and "Create app" is ACTIVE. The guide's "may take a
  few days" is the worst case; a clean ID submission cleared in under an hour. Account is
  fully operational. "Create app" deliberately deferred until the listing inputs exist
  (GP-5 published URL, GP-6/GP-7 assets, signed AAB from GP-2).
- **GP-5 PUBLISHED (2026-08-28)**: discovery during publication -- GitHub Pages was ALREADY
  enabled on the repo with Harold's custom domain https://myemailspamfilter.com serving
  `main:/docs`, so the legal docs were already live (with placeholders showing). Canonical
  URLs: https://myemailspamfilter.com/legal/PRIVACY_POLICY.html and .../TERMS.html.
  Placeholders filled in docs/legal (effective date August 28, 2026; contact
  myemailspamfilter.dev@gmail.com -- same address as the public developer email); the
  filled text goes live when the Sprint 64 branch reaches main (next merge). Placeholder
  regression gate: test/policy/legal_docs_test.dart. A briefly-created gh-pages branch was
  removed as redundant (the site serves main, not gh-pages).

**Decision (Harold, 2026-08-25, at Sprint 63 plan approval)**: PERSONAL account. No D-U-N-S
number is available, and the 12-testers / 14-continuous-days closed-test gate is accepted.

**Facts verified 2026-08-24** against Google's current documentation (requirements change --
re-check the pages below if this doc is more than a few months old):
- [Play Console Requirements](https://support.google.com/googleplay/android-developer/answer/10788890)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312)

## What the personal route means for the track's schedule

Personal accounts created after 2023-11-13 must, BEFORE any app can go to production:

1. Run a **closed test** of the app with **at least 12 testers opted in continuously for 14
   days**. Testers count only after they open the closed-testing link AND complete opt-in.
2. Then apply for production access (Google reviews the testing evidence).

Consequences:
- The 14-day clock cannot start until a build is uploadable (signing = GP-2, flavors = F94)
  and 12 testers are sourced. **Start recruiting the 12 testers early** -- friends/family
  with Android devices qualify; each needs a Google account and must install via the closed
  track link and stay opted in for the full 14 days.
- Once production access is granted for the account's first app, updates never need the
  tester gate again, and the same 12 testers can serve any future app.
- The closed test itself is useful, not overhead: it is a real-device validation window for
  the Android build before any public user sees it.

## Account creation checklist (Harold-driven; ~30-60 minutes active time)

Prerequisites to have ready BEFORE starting:
- [ ] A Google account for the developer identity (decide: personal Gmail vs a dedicated
      account -- a dedicated account keeps app administration separable later). **2-Step
      Verification must be enabled** on it.
- [ ] Government-issued photo ID matching the account holder's legal name (identity
      verification is mandatory; processing can take days).
- [ ] A payment method for the **$25 one-time** registration fee.
- [ ] An Android device with the **Play Console app** installed (new personal accounts must
      verify device access through it).
- [ ] A developer contact email and phone number (Google OTP-verifies both). CORRECTED
      2026-08-27 against the requirements page: the contact email/phone are PRIVATE ("NOT
      shown to users on Google Play") -- the publicly shown address is the separate
      "developer email" field on the public developer profile, set later before the listing
      goes live. Personal email is fine for the private contact fields.
- Ownership note (verified 2026-08-27): the owning Google account can be CHANGED later via
  the supported self-service ownership transfer (Users and permissions -> Make account
  owner; new owner re-verifies identity, must not already own a console account,
  payments-profile admin added first). Choosing an account now is not a lock-in.

Steps:
1. Go to https://play.google.com/console/signup and choose **Yourself** (personal account).
2. Complete the developer profile (legal name exactly as on the ID, contact details).
3. Pay the $25 fee.
4. Complete identity verification (ID upload) when prompted -- if Google defers it, it will
   be required before the first app can be published; do it immediately anyway.
5. Verify the contact email + phone when the codes arrive.
6. Install the Play Console app on the Android device, sign in, complete device verification.
7. Record in this repo (master plan GP section): account created date, developer name shown,
   verification status, and any requirement Google presented that this doc does not list.

## What Claude prepares in parallel (no account needed)

- GP-5 privacy policy (required before any listing/Data Safety work).
- F94 flavors + GP-2 signing groundwork so an uploadable closed-test build exists as soon as
  the account clears verification.

## The road not taken (recorded for completeness)

An **organization** account (e.g. "Kimmey Consulting - Ohio", the Microsoft Store publisher
identity) is exempt from the 12-tester/14-day gate but requires a D-U-N-S number (free;
issuance can take up to ~30 days), organization verification documents, and an organization
website/email. Declined 2026-08-25: no D-U-N-S available, and the tester gate is acceptable.
If the account is ever migrated to an organization later, Google supports converting via
support -- not planned.

## Data safety declarations (as submitted) (GP-10, Sprint 65, Issue #380)

**Why this section exists**: Play's Data safety form asks the developer to declare, per data
category, what the app collects, shares, and stores. A wrong "does not collect" answer is a
policy violation, not a typo, so every answer below is traced to the code path that proves it
rather than assumed. This section is the recorded input for the Play Console form; re-derive
nothing from memory on the next submission -- read this section and re-verify only if the code
has changed.

**Cross-check rule (R-2/AC-3)**: every claim here must agree with the published privacy policy
at `docs/legal/PRIVACY_POLICY.md` (also published live at
https://myemailspamfilter.com/legal/PRIVACY_POLICY.html) -- the app's data behavior is shared
Dart code, so a Play declaration that contradicts the privacy policy is a defect on both
platforms (Windows Store and Play). `test/policy/data_safety_declarations_test.dart` checks
this mechanically.

**Permission list input (from GP-3, Sprint 64)**: the merged release manifest carries 9
justified permissions -- POST_NOTIFICATIONS (local notifications), INTERNET (IMAP/OAuth to the
user's own provider), FOREGROUND_SERVICE + FOREGROUND_SERVICE_SHORT_SERVICE + WAKE_LOCK +
RECEIVE_BOOT_COMPLETED (WorkManager background scan), VIBRATE (notifications),
ACCESS_NETWORK_STATE (connectivity_plus), DYNAMIC_RECEIVER_NOT_EXPORTED (androidx
self-permission). None of the 9 imply location, contacts, photos, or a device/advertising
identifier -- confirmed independently below per category.

**Encryption in transit**: all provider connections are TLS. Evidence:
`mobile-app/android/app/src/main/res/xml/network_security_config.xml` sets
`cleartextTrafficPermitted="false"` at the app-wide `base-config` level (SEC-4, Sprint 64,
Issue #377); `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` defaults
`isSecure` to `true` at every call site (line 97, 112, 123, 134, 144). No code path opens a
cleartext connection.

**Privacy policy URL for the form**: https://myemailspamfilter.com/legal/PRIVACY_POLICY.html

### Per-category declarations

| Play category | Collected | Shared | Ephemeral processing | User can request deletion | Code evidence |
|---|---|---|---|---|---|
| Personal info (name, email address) | Yes (email address only) | No | No -- persisted locally | Yes | `mobile-app/lib/adapters/storage/secure_credentials_store.dart` stores the account email under `credentials_<accountId>_email` in `FlutterSecureStorage` (OS-encrypted: EncryptedSharedPreferences on Android). `mobile-app/lib/core/services/data_deletion_service.dart` `deleteAccountData()` / `wipeAllData()` remove it. No name field is requested or stored beyond what the provider's own OAuth/IMAP handshake returns. |
| Financial info | No | No | N/A | N/A | No payment, billing, or financial-account code exists anywhere in `lib/`. Confirmed by grep: zero matches for payment/billing/card SDKs or fields in the codebase. |
| Location | No | No | N/A | N/A | No location permission is requested (absent from the GP-3 merged manifest's 9-permission list) and no geolocation package appears in `pubspec.yaml`. |
| Email and other messages | Yes (email metadata and, for a subset, a short body excerpt) | No | Partially -- most evaluation is header-only and nothing is retained from that path | Yes | `mobile-app/lib/core/storage/database_helper.dart` `email_actions` table (lines 190-206) persists `email_from`, `email_subject`, `email_folder`, `matched_rule_name` per processed message -- no body column. `unmatched_emails` table (lines 302-322) additionally persists `body_preview`. `mobile-app/lib/core/storage/unmatched_email_store.dart` `truncateBodyPreview()` (lines 15-30) hard-caps `body_preview` at `kBodyPreviewMaxLength = 100` characters; full message bodies are never written to any table. Privacy policy: "a short body preview (at most 100 characters). Full message bodies are never stored." -- matches exactly. |
| Photos/videos | No | No | N/A | N/A | No image/media picker, camera, or gallery package is used; email attachments are never downloaded or stored (confirmed: no attachment-persistence code path in `lib/core/services/email_scanner.dart` or the storage layer). |
| Files/docs | No (user-initiated exports are user-directed writes, not app collection) | No | N/A | N/A | `mobile-app/lib/core/services/live_scan_logger.dart` writes CSV/XLSX exports and the runtime log to the app's own local log directory (`{appSupport}{_Dev}/logs`) for the user's own diagnostic use; these files never leave the device and are not "collected" by the developer under Play's definition (nothing is transmitted). |
| Contacts | No | No | N/A | N/A | No contacts/address-book package is used; safe-sender and rule patterns are user-typed strings, not sourced from a device contacts API. |
| App activity (app interactions, in-app search history) | No | No | N/A | N/A | No analytics, telemetry, or usage-tracking SDK exists in `pubspec.yaml` (grep for `analytics`, `admob`, `ads` returns no matches). The only non-provider network call in the codebase is `mobile-app/lib/adapters/auth/google_auth_service.dart:549-550`, `POST https://oauth2.googleapis.com/revoke` -- part of the Google OAuth sign-out flow itself, not app-activity telemetry. |
| App info and performance (crash logs, diagnostics) | No | No | N/A | N/A | No crash-reporting SDK (Crashlytics, Sentry, or similar) exists in `pubspec.yaml` or `lib/`. Diagnostic logs (`live_scan_logger.dart`, `background_scan_windows_worker.dart` background logs) are written to local files only and are never uploaded; they are not "collected" by the developer. |
| Device or other IDs | No | No | N/A | N/A | No advertising ID, Android ID, or other device-identifier API is read anywhere in `lib/` (grep for `advertising_id`, `android_id`, `Settings.Secure` returns no matches); no ads/analytics package that would require one is present in `pubspec.yaml`. The GP-3 merged manifest carries no `AD_ID` permission. |

### Retention and deletion, all categories

`mobile-app/lib/core/services/data_deletion_service.dart`:
- `deleteAccountData()` removes one account's credentials (from `SecureCredentialsStore`),
  per-account settings, scan results, email actions, and unmatched emails (with their
  `body_preview` excerpts) -- other accounts and global rules are untouched.
- `wipeAllData()` clears every database table and every stored credential, returning the app
  to a fresh-install state.
- Uninstalling the app removes all remaining app data via the OS (no server-side copy exists
  anywhere, so there is nothing left to delete after uninstall).

This matches `docs/legal/PRIVACY_POLICY.md` "Deleting your data" verbatim: "Remove an account
in the app: deletes that account's credentials, scan history, and settings from your device."
and "Uninstall the app: your operating system removes all app data."

### Data sharing, all categories

No data is shared with any third party in any category. The only network destinations the app
ever contacts are: (a) the user's own configured email provider (Gmail API or IMAP, per
account, at the user's direction) and (b) Google's OAuth token-revoke endpoint as part of
Gmail sign-out. Both are consistent with `docs/legal/PRIVACY_POLICY.md` "Data sharing": "We
share data with no one. The only network connections the app makes are to your own email
provider."

### Contradiction check result (AC-3)

Zero contradictions found between these declarations and `docs/legal/PRIVACY_POLICY.md`. Every
"collected" answer above (email address, email metadata, 100-character body preview) has a
matching, non-contradictory statement in the privacy policy; every "not collected" answer is
independently confirmed by the absence of the corresponding permission, package, or code path.

## Closed-test tester roster and the 14-day clock (GP-17, Sprint 65)

**Why this section exists**: the 12-tester / 14-continuous-day closed test is the single longest
item on the path to a live Play listing, and its clock is easy to restart by accident. Recording
opt-in dates here means the earliest valid application date is a computed fact rather than
somebody's recollection.

### The rules that actually govern the schedule

Verified against Google's documentation, 2026-09-05:

- **The clock is per-tester and measures OPT-IN duration**, not the release date. Google checks
  backward from the moment you apply: at least 12 testers must have been opted in continuously
  for the preceding 14 days.
- **An invitation is not an opt-in.** A tester counts only after they open the closed-track link
  AND complete opt-in. Sending 14 invitations and assuming means the clock has not started.
- **Opting out breaks the streak, and re-opting-in restarts that tester's 14 days from zero.**
  This is why the target is 14-16 testers rather than exactly 12: one person leaving should not
  reset the sprint's schedule.
- **A closed-track rollout requires COMPLETED APP SETUP** -- the full store listing, Data safety,
  content rating and every App content declaration. Only internal testing skips setup, and
  internal-test days earn ZERO credit toward the 12/14. There is no way to start the clock early
  and finish the paperwork during the wait.
- **Production access is a substantive review, not a checkbox.** It asks what testers reported,
  what feedback came back, and what changed as a result. Thin or generic answers are a documented
  rejection cause, and a rejection costs a reapplication cycle. That is why the feedback log below
  is a deliverable rather than a nicety.

### Roster

Record ROLES and dates only. **No names, no email addresses** -- this file is in the repository.

| # | Tester (role only) | Invited | Opt-in CONFIRMED | Still opted in? | Notes |
|---|---|---|---|---|---|
| 1 | (pending) | | | | |
| 2 | (pending) | | | | |
| 3 | (pending) | | | | |
| 4 | (pending) | | | | |
| 5 | (pending) | | | | |
| 6 | (pending) | | | | |
| 7 | (pending) | | | | |
| 8 | (pending) | | | | |
| 9 | (pending) | | | | |
| 10 | (pending) | | | | |
| 11 | (pending) | | | | |
| 12 | (pending) | | | | |
| 13 | (pending, margin) | | | | |
| 14 | (pending, margin) | | | | |

**Confirmed opt-ins**: 0 of 12 required (target 14-16)
**Latest confirmed opt-in date**: (none yet)
**Earliest valid production-access application date**: (latest opt-in date) + 14 days -- compute
from the LAST tester to opt in, not the first. One late joiner moves this date.

### Tester feedback log

Collected during the 14 days and used verbatim in the production-access application.

| Date | Tester (role) | What they reported | What changed as a result |
|---|---|---|---|
| | | | |

### Closed-track release record

| Field | Value |
|---|---|
| Track created | (pending) |
| Release rolled out | (pending) |
| Version / build | (pending -- the signed release chain shipped in Sprint 64, so the build is not the blocker) |
| Opt-in link distributed | (pending) |
