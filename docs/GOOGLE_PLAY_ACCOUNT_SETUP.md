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
