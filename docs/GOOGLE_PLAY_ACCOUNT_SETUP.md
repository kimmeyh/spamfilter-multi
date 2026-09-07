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

## App content declarations (as submitted) (GP-18, Sprint 65, Issue #381)

**Why this section exists**: Play's "App content" checklist gates a closed-track rollout, not
only production -- "you can start a closed test after completing your app setup" (Play Console
help). A conditional item left unanswered is an incomplete setup, and an incomplete setup blocks
the rollout the same way a wrong answer would. Every item below is recorded as ANSWERED, with a
one-line justification traced to the code or to the plain fact of what this app is, so nothing is
silently skipped and nothing has to be re-derived from memory on the next submission.

### Content rating questionnaire

| Item | Answer | Justification |
|---|---|---|
| App category for rating | Utility / Tools | The app is a client-side email spam filter: it reads a user's own mailbox (their configured account) and applies user-authored or default pattern rules to flag, move, or delete matching messages. No content is created, browsed, or shared through the app. |
| Violence | None | No such content exists in the app. The only body text the app ever displays is the user's own email content, rendered as-is (never generated or curated by the app). |
| Sexual content / nudity | None | Same as above -- no generated content, and the app does not moderate or display third-party media. |
| Profanity / crude humor | None | Same as above. |
| Controlled substances (alcohol, tobacco, drugs) | None | The app has no content or feature related to controlled substances. |
| Gambling (simulated or real-money) | None | No gambling mechanic exists anywhere in `lib/`. |
| User-generated content shared with other users | No | Rules and safe-sender patterns a user types are stored locally per-device only (`RuleDatabaseStore`, `SafeSenderDatabaseStore`) and are never transmitted to any other user or to the developer -- confirmed by the Data safety section above ("Data sharing, all categories": no data is shared with any third party). |
| Unrestricted internet access / web browsing | No | The app's only network destinations are the user's own configured email provider and Google's OAuth token-revoke endpoint (Data safety section above); there is no in-app browser or unrestricted URL navigation surface. |

### Target audience and content

| Item | Answer | Justification |
|---|---|---|
| Target age group | Adults (18+) primarily; not designed or marketed for children | An email account presupposes an email provider account, which itself requires an adult or a supervised account under the provider's own terms (Gmail's minimum age policy, for example). The app has no child-directed design, content, or marketing. |
| Appeals to children (COPPA / Designed For Families) | No | No child-directed UI, characters, or content exists anywhere in `lib/ui/`; confirmed by grep -- no "children", "kids", or age-gating code path exists in the codebase (the only textual hits are unrelated Dart `children:` widget-list parameters). |
| Ads targeted to children | Not applicable | The app shows no ads at all (see Ads declaration below), so no ad-targeting question applies. |

### Ads declaration

| Item | Answer | Justification |
|---|---|---|
| Does the app contain ads? | No | Verified by grep across `pubspec.yaml` for every ad SDK Play recognizes (AdMob, Google Mobile Ads, Unity Ads, AppLovin, Facebook Audience Network, ironSource, Vungle, Chartboost) -- zero matches. `pubspec.yaml`'s dependency list contains no ads/monetization package of any kind. The Android manifest carries no `com.google.android.gms.ads` metadata and no `AD_ID` permission (also independently confirmed in the Data safety section's "Device or other IDs" row). |

### Government apps

| Item | Answer | Justification |
|---|---|---|
| Is this a government app? | No | The app is developed and published under a personal developer account (Kimmey Consulting, Ohio -- see ACCOUNT CREATED above) with no affiliation to any government entity, and implements no government service, ID, or benefit. |

### Financial features

| Item | Answer | Justification |
|---|---|---|
| Does the app provide financial services (payments, lending, crypto, trading, etc.)? | No | No payment, billing, lending, or financial-account code exists anywhere in `lib/` -- confirmed by grep for payment/billing/card/crypto SDK names and fields, zero matches (same grep already relied on by the Data safety section's "Financial info" row). The one "banking" hit in the codebase is inside `mock_email_data.dart`, a hardcoded Demo Mode SAMPLE email subject line ("New Features in Mobile Banking") used to exercise the spam-filtering rule engine -- decoy content, not a real financial feature. |

### News app

| Item | Answer | Justification |
|---|---|---|
| Is this a news app? | No | The app does not aggregate, curate, or publish news content of any kind; it only filters the user's own existing email. |

### Health apps

| Item | Answer | Justification |
|---|---|---|
| Does the app provide health-related services (medical records, fitness tracking, telehealth, etc.)? | No | No health, medical, or fitness code, permission, or data model exists anywhere in `lib/`. |

## App access (GP-18, R-2, Sprint 65)

**The decision (R-2)**: option (b) -- written reviewer instructions pointing at the app's existing
Demo Mode, NOT a dedicated test email account (option a). Below is the verification that led to
this choice, followed by the exact instructions to paste into Play Console.

### Why Demo Mode was verified, not assumed (R-2 decision record)

A spam filter demonstrates nothing without a working email account, so option (b) is only valid
if a reviewer with NO account can reach a state that actually shows filtering happening -- not
merely a screen that LOOKS like the app. The full path was traced through the source, end to end,
before this decision was recorded:

1. **Reachability with no account.** `PlatformSelectionScreen`
   (`mobile-app/lib/ui/screens/platform_selection_screen.dart`, ~line 122) shows a direct-launch
   card, "Try Demo Mode" / "Test with 50+ sample emails (no email account needed)", on the FIRST
   screen the app shows -- no account picker, no setup form, no credential prompt precedes it.
   `_startDemoMode` (~line 30) navigates straight to `ScanProgressScreen` with
   `platformId: 'demo'`.
2. **A second, unambiguous tap target.** `ScanProgressScreen` shows two buttons: "Start Live
   Scan" (would fail with no account -- NOT the reviewer's path) and "Start Demo Scan (Testing)"
   (`_startDemoScan`, ~line 479), which is the one that must be named in the instructions.
3. **The scan is self-contained -- no rule-seeding dependency.** `EmailScanner.scanInbox`
   (`mobile-app/lib/core/services/email_scanner.dart`, ~line 246) special-cases
   `platformId == 'demo'`: it uses `MockEmailData.getDemoRuleSet()` /
   `getDemoSafeSenderList()` instead of the app's real `RuleSetProvider.rules`. This means Demo
   Mode does not depend on default rules having been seeded, or on any rule ever having been
   configured -- it carries its own purpose-built rule set matched to its own sample data,
   regardless of what state the rest of the app is in.
4. **The sample data is deliberately spam-shaped.** `MockEmailData.generateSampleEmails()`
   (`mobile-app/lib/core/services/mock_email_data.dart`) returns 59 messages including senders
   like `winner@lottery-scam.com` ("YOU WON $1,000,000!!!"), `security@paypa1-verification.com`
   ("URGENT: Verify Your PayPal Account Now"), and `sales@cheap-meds-online.biz`
   ("V1AGRA & C1AL1S - 70% OFF TODAY") -- an obvious phishing/scam/spam mix, not neutral filler.
5. **A real deletion outcome, not just navigation.** On completion, `_startDemoScan` navigates to
   `ResultsDisplayScreen` showing the scan summary. This was verified with an actual run of the
   traced code path (not inferred): **found=59, processed=59, deleted=26, moved=0, safe=21,
   noRule=12, errors=0** -- a demo scan run this way deletes 26 of 59 sample messages via the real
   `RuleEvaluator`, and the results screen shows the matched rule name against each. A reviewer
   following the instructions below sees actual spam-filtering behavior, not a static
   demonstration.

Option (a) was rejected on this evidence, not by default: option (b) reaches a materially
equivalent (arguably clearer, since the sample data is deliberately spam-shaped) demonstration of
the core value with no live credential to create, rotate, or ever risk leaking, which is exactly
the NFR this card calls out ("option (a) creates a real credential that lives outside the repo
and must be maintained").

**ADR-0042 note**: the entire traced path (`PlatformSelectionScreen`, `ScanProgressScreen`,
`EmailScanner`, `MockEmailProvider`, `MockEmailData`) is shared Dart code with no `Platform.is*`
branch anywhere in it -- Demo Mode is not an Android-specific feature, so the reviewer path
behaves identically on Windows. `test/ui/screens/demo_mode_reviewer_path_test.dart` proves
reachability and a real filtering outcome from a zero-account, zero-initialization state, which is
the platform-agnostic form of this same guarantee (T-2).

### Reviewer instructions (paste verbatim into Play Console's App access form)

```
This app requires no login for a reviewer to evaluate its core functionality. Follow these
steps from a fresh install:

1. Launch the app. On a fresh install the first screen is "Select Account", showing
   "No Accounts Yet" with two options: "+ Add Account" and, below it,
   "Try Demo Mode instead".
2. Tap "Try Demo Mode instead". (If the app instead opens "Select Email Provider" --
   which happens when an account already exists -- tap the "Try Demo Mode" card near the
   top, above the provider list. Both routes reach the same place.)
3. The app opens a "Ready to Scan" screen showing a "DEMO MODE" badge.
4. Tap the button labeled "Start Demo Scan (Testing)" (the second of two buttons on this
   screen -- do NOT tap "Start Live Scan", which requires a real email account).
5. The app processes a built-in set of 50+ realistic sample emails (a mix of obvious spam --
   fake lottery winnings, phishing/account-verification scams, pharmacy spam -- and normal
   mail) against its spam-filtering rule engine. This takes a few seconds.
6. The app navigates automatically to a Results screen showing a scan summary: counts of
   emails processed, deleted (identified as spam and simulated/removed), and left
   unmatched, plus a per-email list showing which rule matched each deleted message.

No account, credentials, or network access to any email provider is required to reach this
screen. This exercises the same rule-evaluation engine used for a real account's live scan.
```

### R-3: end-to-end reviewer-path walk (record when performed)

R-3 requires the reviewer path above to be walked end to end on a real device before
submission -- not assumed to work from the source trace alone. Record here when performed:

| Date | Device | What was seen | Matches instructions above? |
|---|---|---|---|
| (pending) | | | |

## Tester onboarding instructions (GP-19, Sprint 66)

**Send this to each tester.** Recruitment is the long pole -- the 14-day clock starts when a
tester OPTS IN, not when the build is rolled out -- so send it as soon as the closed track
exists rather than waiting for everything else to be perfect.

### Why App Password and not "Sign in with Google"

The app offers both. **Testers should use App Password (IMAP)**, which is the option the app
already labels "(Recommended)" on the Gmail sign-in screen.

The reason is specific to a 14-day test: an app password does not expire on a schedule, so a
tester signs in ONCE and stays connected for the whole test. Google Sign-In on an app that has
not completed OAuth verification expires its token after about 7 days, which would sign every
tester out halfway through and generate "the app logged me out" reports that have nothing to do
with spam filtering -- during exactly the window whose evidence Google reviews.

This applies to Gmail testers too. They do NOT need a second, non-Gmail account: Gmail via app
password is a first-class path in the app.

### What to send a tester

> Thanks for helping test MyEmailSpamFilter on Android.
>
> **What it does**: it scans your inbox and filters spam using rules you control. Everything
> runs on your device -- nothing is sent anywhere.
>
> **Before you start**, you need an app password for your email account. This requires 2-Step
> Verification to be turned on. For Gmail: turn on 2-Step Verification in your Google account
> security settings, then create an app password there. AOL, Yahoo and iCloud have the same
> feature under their own security settings.
>
> **Then**:
> 1. Open the closed-test link I sent and tap to join. **This step is what counts** -- if you
>    do not complete it, you are not registered as a tester.
> 2. Install the app from Google Play.
> 3. Open it, tap "Add Account", choose your provider.
> 4. For Gmail, choose **"App Password (IMAP)"** -- the first option, marked Recommended. Do
>    NOT choose "Google Sign-In".
> 5. Enter your email address and the app password you created (not your normal password).
> 6. Run a scan and see what it finds.
>
> **Please stay opted in for at least 14 days.** If you leave and rejoin, the clock restarts
> for you, which delays the whole launch.
>
> **Tell me anything you notice** -- confusing screens, wrong decisions about your mail, things
> you expected and did not find. Google asks what testers reported and what changed as a
> result, so genuine feedback is more useful than reassurance.

### The one step that trips people

Creating an app password requires 2-Step Verification to be enabled first. If a tester says the
app password option is missing from their account settings, that is why. Say it up front rather
than debugging it later.

### What counts, and what does not

- An INVITATION is not an opt-in. A tester counts only after they open the link and complete
  the join. Confirm each one rather than assuming.
- Opting out breaks the streak. Re-joining restarts that tester's 14 days from ZERO, which is
  why the target is 14-16 testers rather than exactly 12.

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

## Gmail OAuth verification -- data-residency determination (GP-4, Sprint 66)

**Why this section decides the cost of verification.** Google requires an annual third-party
security assessment (CASA) for restricted-scope apps **that store or transmit restricted-scope
data on servers**. An app that keeps Gmail data on the user's own device is a different case.
The difference is roughly two weeks of documentation versus several weeks plus an assessment
fee that recurs annually, so this is the single most consequential question in the submission.

**Determination: no Gmail-derived data ever leaves the user's device.**

Evidence, gathered from the code rather than asserted:

| Claim | Evidence |
|---|---|
| No backend of any kind | The app has no server component. Every outbound host in `lib/` is enumerated below. |
| No analytics, crash reporting, or advertising | `pubspec.yaml` contains zero matches for analytics, crashlytics, sentry, amplitude, mixpanel or admob. Firebase Analytics was deliberately REMOVED in Sprint 63 (GP-12) per ADR-0030/0033. |
| Mail is read directly from the provider to the device | Gmail API calls go from the device to `gmail.googleapis.com`; IMAP connects device-to-provider. Nothing intermediates. |
| Mail content is stored locally only | The rules database, scan history and unmatched-email previews live in the app-support directory (`app_paths.dart`). Nothing uploads them. |
| Body retention is bounded and local | `kBodyPreviewMaxLength = 100`, enforced at the write boundary in `unmatched_email_store.dart` so a caller cannot bypass it. Full bodies are never persisted. |

**Every outbound host in `lib/`** (complete enumeration, not a sample):

- `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com` -- Google's own OAuth
  endpoints. Authentication only.
- `gmail.googleapis.com` -- Google's own Gmail API. The user's mail, from Google to the user's
  device.
- `data.iana.org` -- the public TLD list, used for rule validation. Carries no user data.
- `graph.microsoft.com`, `login.microsoftonline.com` -- **unreachable**. Both appear only as
  COMMENTED-OUT constants in `outlook_adapter.dart`, an adapter that is not registered in
  `platform_registry.dart` (its factory and its `PlatformInfo` entry are both commented out).
  Outlook support is deferred, not shipped.
- `developer.mozilla.org`, `developers.google.com`, `github.com`, `example.com` --
  documentation links and test fixtures. Not network calls with user data.

**No third party ever receives Gmail data**, because there is no third party in the path at all.

### What to state in the verification submission

Raise this explicitly and ask Google to rule, rather than assuming the exemption applies.
Google's developer-facing pages state the server-side condition plainly, but the authoritative
API Services User Data Policy does not repeat the carve-out. **Asking is cheap; assuming is
not** -- and a wrong assumption surfaces late, after the submission has been reviewed on the
wrong basis.

Suggested wording:

> This application has no server component. Gmail data is requested by the user's own device
> directly from Google's APIs and is stored only in the application's local data directory on
> that device. It is never transmitted to any server operated by the developer or by any third
> party. The application contains no analytics, crash-reporting, or advertising SDK. We
> understand the annual third-party security assessment applies to applications that store or
> transmit restricted-scope data on servers, and we request confirmation that it does not apply
> to this architecture.

### Scopes requested (narrowed for this submission)

| Scope | Classification | Why the app needs it |
|---|---|---|
| `gmail.modify` | Restricted | The app deletes spam and moves mail between folders. Read-only is insufficient. |
| `userinfo.email` | Non-sensitive | Identifies WHICH account was authorised, so rules and scan history attribute correctly in a multi-account app. |

**Two scopes were REMOVED before submitting** (Sprint 66, GP-4 R-3): `gmail.readonly`, which
was redundant because `modify` already covers reading, and `gmail.send`, which the app never
uses. Both were declared constants with zero call sites. A reviewer assesses what is declared,
and a send scope on a spam filter invites a question that should never arise.
`test/policy/gmail_scope_parity_test.dart` now fails if either is re-declared, and fails if the
Windows and Android scope sets ever diverge.

### The one irreversible action to avoid

**Do not set the OAuth consent screen to "In production" before verification completes.**
Publishing while unverified imposes a cap of 100 new users **for the lifetime of the project**,
which cannot be reset or raised. Leave the publishing status alone until Google confirms
verification.
