# Google Play Policy Announcement of 2026-10-29: Impact Analysis (F364, Sprint 86)

Analysis date: 2026-11-24. Source announcement: "Policy announcement: October 29, 2026",
https://support.google.com/googleplay/android-developer/answer/18100766 (fetched 2026-11-24).

**Method and limits.** Every Google page below was fetched in this session (2026-11-24). The fetch tool returns a
summary with short quotes, so each quote is marked "as returned by the fetch". It is not a byte-for-byte copy of the
page. The Play Console cannot be read from this repository. A fact that lives only in the Console is classified
UNKNOWN and names the Console screen that settles it. No Microsoft Store or Apple App Store rule was fetched, so
every cross-store parity statement below is marked unverified. Short source forms map to full URLs:
"answer/N" is https://support.google.com/googleplay/android-developer/answer/N?hl=en, "table/12921780" is
https://support.google.com/googleplay/android-developer/table/12921780?hl=en, and "paymentscenter answer/N" is
https://support.google.com/paymentscenter/answer/N?hl=en. The full list is under Sources.

## BLUF

- **18 topics. 2 APPLY, 2 UNKNOWN, 14 DO NOT APPLY.**
- **No Google requirement in this announcement has a deadline for this app before 2026-12-31.** The only date
  before 2026-12-31 on the page is the Japan payments authorization (2026-12-01). It is tied to sales, and this app
  is free with no billing code, so it does not apply.
- **The "at least 30 days" window is a floor, not the deadline.** The Policy Deadlines page gives each new or
  updated policy its own date: 2027-01-27 (subscription discounts), 2027-04-14 (AppFunctions) and 2027-08-25 (Local
  Network, Manage Contacts). The card's estimate "ends about 2026-11-28" is not supported by that page. How Google
  counts the 30 days is not stated on any page fetched (unverified).
- **APPLIES 1, trader status.** Already declared NON-TRADER (Harold, 2026-11-23). Google's deadline is 2027-02-01.
  The only permissive condition the page gives is no distribution in the EEA or UK; the last recorded country list
  is United States only. There is a tension Harold must decide: the developer name is an LLC, and "business setup"
  and "legal status" are two of Google's four trader criteria.
- **APPLIES 2, deceptive behavior (review manipulation).** Applies to every app. No gap found: the app has no code
  that detects a review environment, and Demo Mode is a user-visible option. No card needed.
- **UNKNOWN 1, app quality memory thresholds (February 2027).** Only the Android vitals "Memory" section can
  settle it. The code-optimization half does not apply: DEX is 5.3 MB, below the 10 MB floor, and R8 is on.
- **UNKNOWN 2, Play Age Signals.** The fetched pages do not say it is mandatory. Whether a regional law obliges
  this app to use it is a legal question the pages do not settle.
- **Proposed cards: F365 to F368** (trader status decision and EEA/UK gate; Android vitals memory check before
  February 2027; restricted-permission gate in the AAB check; targetSdk 37 Local Network readiness).

## The 30-day window and the dates

- The announcement says (as returned by the fetch): "You'll have at least 30 days from October 29, 2026 to update
  your app". It points to the Policy Deadlines page.
- The Policy Deadlines page (https://support.google.com/googleplay/android-developer/table/12921780?hl=en) lists the
  2026-10-29 announcement with four dated rows: Local Network Permission 2027-08-25, Manage Contacts Permission
  2027-08-25, AppFunctions API 2027-04-14, Subscriptions with ongoing eligibility-based discounts 2027-01-27.
- The same page lists other rows with 2027-01-27 deadlines announced earlier: Contacts Permissions, Location
  Permissions, SMS or call log permission groups, and Foreground service (geofencing removed as an approved use).
- The page does not mention "at least 30 days" and does not explain how dates are counted. It says only that dates
  are in year, month, day format. **Unverified: how the 30 days are counted.** What would settle it: a Google page
  that defines the counting rule. In practice the per-row dates make the question moot for this app.
- **Items with a date before 2026-12-31:** only the Japan authorization (2026-12-01). The trader status item says
  "Starting November 2026" on the announcement, but the trader page sets the declaration deadline at 2027-02-01.

## Per-topic analysis

Repository evidence used by several topics:

- **The built bundle's permission list.** `mobile-app/dist/android-0.25.0+23/app-prod-release.aab` (the 0.25.0
  bundle; `docs/STORE_VERSION_STATUS.md:27` records it as uploaded to Play, from Harold's report), parsed with `get_manifest_facts()` from
  `mobile-app/scripts/verify-aab-play-requirements.py:145`. Result: targetSdk 36 and exactly 9 `uses-permission`
  entries: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SHORT_SERVICE,
  WAKE_LOCK, ACCESS_NETWORK_STATE, VIBRATE, INTERNET, com.myemailspamfilter.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
  This matches the 9-permission list in `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:161`.
- **Source manifests.** `mobile-app/android/app/src/main/AndroidManifest.xml:7` (POST_NOTIFICATIONS), `:18`
  (RECEIVE_BOOT_COMPLETED), `:30-32` (NFC, USE_BIOMETRIC, USE_FINGERPRINT removed), `:171-179` (notification
  listener service), `:187-202` (queries: PROCESS_TEXT and 5 named mail packages, no QUERY_ALL_PACKAGES). The
  `debug` and `profile` manifests add only INTERNET (line 6 of each). The `dev` source set has no manifest.
- **SDK levels.** `mobile-app/android/app/build.gradle.kts:12` `compileSdk = flutter.compileSdkVersion`, `:45`
  `targetSdk = flutter.targetSdkVersion`, `:44` minSdk. Flutter 3.47.4 (`.fvmrc`) sets both to 36
  (`D:\dev\flutter\packages\flutter_tools\gradle\src\main\kotlin\FlutterExtension.kt:23` and `:34`). The value
  floats with the Flutter SDK.
- **Plugins that add permissions** (pub cache, at the `pubspec.lock` versions): connectivity_plus 5.0.2
  (ACCESS_NETWORK_STATE, manifest line 3); flutter_local_notifications 22.3.2 (VIBRATE, POST_NOTIFICATIONS, lines
  3-4); google_sign_in_android 7.2.7 (INTERNET, line 4); workmanager_android 0.10.9 (POST_NOTIFICATIONS,
  FOREGROUND_SERVICE, FOREGROUND_SERVICE_SHORT_SERVICE, lines 3, 5, 23). The other 12 plugins with an Android
  manifest declare no permission. WAKE_LOCK and the DYNAMIC_RECEIVER permission come from transitive Maven
  libraries (androidx), which is why the built bundle, not the plugin list, is the authoritative list.
- **Monetization.** Price Free (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:465`); no ads (`:291`); no payments or financial
  features (`:303`); a grep of `mobile-app/pubspec.yaml` for in_app_purchase, billing, ads, location, contacts and
  age_signals finds nothing.
- **Distribution.** Closed testing (Alpha), Countries "United States" (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:865`,
  recorded at the 0.14.1 release); still closed testing only (`docs/STORE_VERSION_STATUS.md:26`). The current
  Console country list was not observed in this session.

### 1. Local Network Permission (new)

- **Requirement and date.** `ACCESS_LOCAL_NETWORK` is restricted to apps that need it for core functionality when
  device pickers are insufficient. Apps targeting API 37+ that request it must submit a Play Console declaration.
  Deadline 2027-08-25. Sources: answer/16909972 (preview policy) and table/12921780.
- **Platform behavior (Android Developers, local-network-permission page).** From API 37, "Local network is blocked
  by default for all apps that update their target SDK". An outgoing TCP connection to a local network address
  needs the permission. Apps targeting 36 or lower keep access through INTERNET and "don't add
  ACCESS_LOCAL_NETWORK to your manifest" (as returned by the fetch).
- **Repo evidence.** targetSdk 36 (built bundle); no ACCESS_LOCAL_NETWORK in the 9 permissions. But the app lets a
  user type a custom IMAP host: the Custom IMAP server fields on the account setup screen
  (`mobile-app/lib/ui/screens/account_setup_screen.dart:84`), stored under
  `mobile-app/lib/adapters/email_providers/custom_imap_settings.dart:52` `keyHost` and used at
  `generic_imap_adapter.dart:302` and `:343`. A user whose mail server sits on the home LAN would lose
  access once targetSdk becomes 37.
- **Classification: DOES NOT APPLY today** (targetSdk 36, permission not requested).
- **Action.** No policy action now. Proposed card F368 prepares for targetSdk 37 (a decision, because the fix is
  either a new restricted permission with a Play declaration or a user-visible "local server blocked" message).

### 2. Manage Contacts Permission (new)

- **Requirement and date.** `MANAGE_CONTACTS` is restricted to core-functionality need when system pickers are
  insufficient; a Play Console declaration is required (the preview text says for API 38+, the full policy text
  says all apps that still require it; the page is internally inconsistent, as returned by the fetch). Deadline
  2027-08-25. A separate Contacts Permissions policy (deadline 2027-01-27) restricts broad contacts access and
  points other apps to the Android Contact Picker. Sources: answer/16909972, answer/16558241, table/12921780.
- **Repo evidence.** No contacts permission in the built bundle; no contacts package; Data safety "Contacts: No"
  (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`, Contacts row).
- **Classification: DOES NOT APPLY.** Action: none.

### 3. AppFunctions API (new)

- **Requirement and date.** Developers building AppFunctions must comply with all Play policies; AppFunctions
  "do not deceive or manipulate AI agents, bypass security controls" or interfere with other apps (as returned by
  the fetch). Deadline 2027-04-14. Sources: answer/16909972, table/12921780.
- **Repo evidence.** A grep of `mobile-app/lib` and `mobile-app/android/app/src` for `AppFunction` finds nothing.
- **Classification: DOES NOT APPLY.** Action: none.

### 4. Subscriptions with ongoing eligibility-based discounts (updated)

- **Requirement and date.** Such subscriptions "must clearly disclose eligibility criteria, the verification
  process, and post-eligibility pricing and benefit changes" (as returned by the fetch). Deadline 2027-01-27.
  Sources: answer/18204939, table/12921780.
- **Repo evidence.** Free app, no billing code (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:465`, `:303`).
- **Classification: DOES NOT APPLY.** Action: none, unless a subscription is ever added.

### 5. Location Permission (clarification; mandatory 2027-01-27)

- **Requirement and date.** Minimum location scope; for API 37+ the Android location button is mandatory for
  one-time or infrequent requests; `ACCESS_FINE_LOCATION` needs a Play Console declaration justifying why coarse
  location or the button is insufficient. Effective 2027-01-27. Sources: answer/16909972, answer/16558241,
  table/12921780.
- **Repo evidence.** No location permission in the built bundle; Data safety "Location: No".
- **Classification: DOES NOT APPLY.** Action: none.
- **Related row, not in this announcement.** The Policy Deadlines page also lists a 2027-01-27 foreground-service
  change that removes geofencing as an approved use. The bundle requests FOREGROUND_SERVICE and
  FOREGROUND_SERVICE_SHORT_SERVICE (from workmanager_android) but no location permission, so geofencing is not used.
  Any other foreground-service declaration duty is outside this announcement and was not checked (unverified).

### 6. All Files Access Permission (clarification)

- **Requirement.** `MANAGE_EXTERNAL_STORAGE` only if platform intents are insufficient for core functionality, with
  a Play Console declaration. No date listed. Source: answer/16558241.
- **Repo evidence.** Not in the built bundle. (file_picker 8.3.7 declares no permission in its manifest.)
- **Classification: DOES NOT APPLY.** Action: none.

### 7. Accessibility API (clarification)

- **Requirement.** `isAccessibilityTool` is for apps whose core function directly supports people with
  disabilities; an AccessibilityService user needs a Play Console declaration and a demo video. No date listed.
  Source: answer/16558241.
- **Repo evidence.** The main manifest declares no AccessibilityService (`AndroidManifest.xml:147-179` lists two
  receivers and one notification listener service); no `isAccessibilityTool` string in the built bundle. The
  notification listener (`:171-179`) is a different API and is not part of this announcement.
- **Classification: DOES NOT APPLY.** Action: none.

### 8. Deceptive Behavior: review manipulation (clarification)

- **Requirement.** "Attempts to manipulate Play review processes" are prohibited; "Make sure your app behaves
  identically for a regular user and for a Google Play reviewer"; do not detect the review environment to hide
  features (as returned by the fetch). No date. Source: answer/17006354.
- **Repo evidence.** A grep of `mobile-app/lib` for reviewer or review-environment detection finds only code
  comments about code review. Demo Mode, which the App access instructions give to reviewers
  (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:320`), is a normal user-visible option (`mobile-app/lib/ui/screens/platform_selection_screen.dart:135` "Try Demo Mode").
- **Classification: APPLIES** (to every app). No gap found.
- **Action.** No card. Reason: the app has no reviewer-specific path. Keep it that way: Demo Mode must stay
  available to every user, not only to reviewers.

### 9. Families Self-Certified Ads SDK Program (clarification)

- **Requirement.** Ads shown to children must come only from self-certified ads SDK versions. Source:
  answer/9900633.
- **Repo evidence.** No ads (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:291`); adult target audience (`:283`).
- **Classification: DOES NOT APPLY.** Action: none.

### 10. Cryptocurrency (clarification)

- **Requirement.** Covers cryptocurrency exchanges and software wallets (Hong Kong licensing update). Source:
  answer/16329703.
- **Repo evidence.** No financial features (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:303`).
- **Classification: DOES NOT APPLY.** Action: none.

### 11. SMS or Call Log permission groups (clarification; READ_CALL_LOG change 2027-01-27)

- **Requirement and date.** SMS and call log permissions are for default SMS, Phone or Assistant handlers (with
  reviewed exceptions) and need a Permissions Declaration Form. From 2027-01-27, account verification by phone call
  is no longer a permitted use of `READ_CALL_LOG`. Sources: answer/10208820, table/12921780.
- **Repo evidence.** No SMS or call log permission in the built bundle.
- **Classification: DOES NOT APPLY.** Action: none. (The linked SMS User Consent API and alternative-API pages were
  not fetched; they are not needed for this classification.)

### 12. Payments through AI or agentic experiences (clarification)

- **Requirement.** Play-managed apps that facilitate purchases of digital goods follow the Payments policy, also
  when the purchase starts in a chat agent or an embedded third-party experience. Sources: answer/9858738 (Payments,
  applies to apps "requiring or accepting payment"), answer/10281818 (AI or agentic guidance).
- **Repo evidence.** Free, no billing, no AI agent feature.
- **Classification: DOES NOT APPLY.** Action: none.

### 13. Play Age Signals (reminder)

- **Requirement.** The announcement invites developers to use the API. The Android Developers overview says the
  tools help apps "meet your compliance obligation in different regulated regions" and that developers are
  responsible for compliance with applicable regulations (as returned by the fetch). Neither fetched page says Play
  requires the API. Sources: developer.android.com use-age-signals-api and overview pages.
- **Repo evidence.** No age_signals dependency; adult target audience (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:283`);
  distribution United States only (`:865`).
- **Classification: UNKNOWN.** Google does not mandate it on the pages fetched. Whether a regional law (for example
  a US state app-store age law) obliges this app is unverified and is a legal question. What would settle it: the
  Play "Age Signals API and User Data policy" page (answer/16585319, not fetched) and, if needed, legal advice for
  the distribution countries.
- **Action.** No card proposed. Raise as a question for Harold if the distribution grows beyond closed testing.

### 14. Japan authorization (reminder; 2026-12-01)

- **Requirement and date.** The announcement says sellers into or out of Japan must complete authorization by
  2026-12-01 or payments are held globally. The Payments center page applies it to developers outside Japan
  "selling to users in Japan" and says to complete it "by the deadline stated in your invitation" (as returned by
  the fetch). Source: paymentscenter answer/17595997.
- **Repo evidence.** Free app, no billing, United States only (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:465`, `:865`).
- **Classification: DOES NOT APPLY.** No sales, so nothing to authorize.
- **Action.** None. Only Harold can confirm that no invitation arrived: the Play Console Inbox and the payments
  profile email. If an invitation exists, the date in it governs.

### 15. Trader status (reminder; declare in Play Console)

- **Requirement and date.** "All active developer accounts must declare whether they are a trader or non-trader";
  existing accounts by **2027-02-01**, "regardless of where apps are targeted or distributed". From 2027-03-01,
  trader contact details become visible, and in the EEA and UK the developer name replaces Google in "Offered by".
  Source: answer/17594752. The announcement says "Starting November 2026".
- **Repo evidence.** Declared NON-TRADER (Harold, 2026-11-23, `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:20`). The
  declaration screen itself was not seen (the screenshot on record does not show it, `:19-20`).
- **Classification: APPLIES.** The deadline is met if the Console shows the declaration. See the non-trader
  section below for the tension.
- **Action.** Proposed card F365.

### 16. Car games (reminder)

- **Requirement.** The Games category for cars moved from beta to general availability (September 2026 update).
  The guidelines cover apps for Android Auto and Android Automotive OS. Source: developer.android.com car-app-quality.
- **Repo evidence.** No car app metadata in the main manifest; no `com.google.android.gms.car` or `automotive`
  string in the built bundle.
- **Classification: DOES NOT APPLY.** Action: none.

### 17. App quality: memory and code optimization (reminder; February 2027)

- **Requirement and date.** "From February 2027, apps and games on Play will need to meet new bad behavior
  thresholds" for memory (Anonymous RSS plus swap, and bitmap memory, 90th percentile over 28 days, mobile and
  tablet only; foreground limits for apps run from 2 GB on a 4 GB device to 4.25 GB on a 16 GB device). Code
  optimization: "a minimum of 25% optimization, obfuscation and shrinking", enforced only for "Apps with > 10 MB
  DEX code" (as returned by the fetch). No day in February is given. Missing a threshold "can affect an app's
  visibility and publishing capabilities". Sources: answer/17492799; Android Developers Blog, 2026-08-26.
- **Repo evidence, code optimization.** R8 and resource shrinking on for release
  (`mobile-app/android/app/build.gradle.kts:174` `isMinifyEnabled = true`, with `isShrinkResources` and the
  proguard files on the following lines). DEX in the 0.25.0 bundle: `classes.dex` 5,134,260 bytes plus
  `classes2.dex` 204,324 bytes, 5.3 MB total, below the 10 MB floor. The page does not say whether the size is
  compressed or uncompressed (unverified); these are uncompressed sizes.
- **Repo evidence, memory.** None. Memory is measured only in Play's Android vitals. With 5 monthly active devices
  (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:19`), Play may not have enough data to show a value (unverified).
- **Classification: UNKNOWN** for memory (open Play Console, Android vitals, overview, the "Memory" section; and
  the App bundle explorer for the optimization percentage). Code optimization: DOES NOT APPLY (below the floor).
- **Action.** Proposed card F366.

### 18. Android XR guidelines (reminder)

- **Requirement.** Quality guidelines for immersive and augmented XR experiences on XR headsets, wired XR glasses
  and audio and display glasses. Source: developer.android.com android-xr quality guidelines.
- **Repo evidence.** No XR feature or metadata in the main manifest or the built bundle.
- **Classification: DOES NOT APPLY.** Action: none.

## Non-trader declaration: what it requires and limits (R-5)

Source for every statement here: "Trader status declaration", answer/17594752 (fetched 2026-11-24, quotes as
returned by the fetch).

- **Who may declare non-trader.** "If you don't distribute apps in the European Economic Area or the United
  Kingdom, you can declare as a non-trader." The page does not say a non-trader is barred from the EEA or UK. It
  says the opposite consequence applies there: Google tells consumers in those regions that consumer-protection
  rights "do not apply" to contracts with a non-trader.
- **What a non-trader shows publicly.** The page states display rules for traders only (contact details, D-U-N-S
  number, terms-of-service link, and for an individual trader a phone number and address). A search summary
  claimed that non-traders show "only email address and country"; the page fetch did not confirm that.
  **Unverified.** What would settle it: the Play listing as seen from an EEA or UK account, or a Google page that
  states it.
- **The trader criteria (non-exhaustive).** Profit-seeking motive ("paid apps, in-app purchases, ad-sponsored
  apps"), transaction volume, business setup ("you manage your app development and publishing as a business"),
  legal status ("such as a D-U-N-S number").
- **Limits that follow.** Adding a paid app price, an in-app purchase, a subscription or ads meets the profit
  criterion. Adding an EEA or UK country removes the condition the declaration rests on. Either change means
  re-deciding status first. Google may ask a non-trader to confirm status if it detects trader activity; no
  response in time "can lead to app removal". Misdeclaring, for example "declaring non-trader status to bypass
  verification or self-certification", can lead to global account suspension or termination.
- **Changing status.** Allowed "at any time in Play Console".
- **The EU law named.** The page cites the EU Unfair Commercial Practices Directive (UCPD) and the UK Digital
  Markets, Competition and Consumers Act (DMCCA). It does not mention the Digital Services Act. The brief assumed
  the DSA; this page does not support that.
- **"EU declared development account".** No fetched page defines an "EU account". Harold's statement most likely
  refers to this trader declaration, which exists because of EEA and UK law. **UNKNOWN** until the Console
  declaration screen is seen (the page does not name the menu path).
- **The tension Harold must decide.** Arguments for non-trader: the app is free, has no ads and no purchases (no
  profit motive, no transactions); the page says "a personal hobby or other non-commercial activity is unlikely to
  make you a trader"; and the last recorded country list is United States only. Arguments for trader: the
  developer name is "Kimmey Consulting LLC" (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:5`), an Ohio LLC exists
  (`docs/LEGAL_ENTITY.md`), and "business setup" and "legal status" are two of the four criteria. The account is
  Personal. On 2026-08-25, before the LLC existed, "No D-U-N-S number is available"
  (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:71`). Whether the LLC has a D-U-N-S number today is not recorded in the repo. This analysis does not decide which
  side wins; that is Harold's call (card F365).

## Proposed cards

F364 is the highest F-number in `docs/ALL_SPRINTS_MASTER_PLAN.md` and in `docs/` (grep, 2026-11-24). The next free
numbers are F365 to F368. Effort figures are estimates (unverified against `docs/CODING_VELOCITY.md`). Only F365
closes an APPLIES gap. F366 settles an UNKNOWN, F367 is prevention, and F368 is a future trigger; any of the three
can be dropped without leaving an APPLIES topic uncovered (the other APPLIES topic, deceptive behavior, needs no
card, reason recorded in topic 8).

- **F365. Trader status: confirm the declaration and gate EEA/UK distribution.** Effort ~20-30 min (Harold opens
  the Console declaration screen; Claude records it; one release-process rule). Priority: high (account-level risk).
  Deadline 2027-02-01 (Google's declaration deadline), and before any EEA or UK country is added to any track.
  Scope: (1) Harold confirms on the Console screen that NON-TRADER is recorded and decides the LLC tension above as
  a numbered question; (2) add a step to `docs/STORE_RELEASE_PROCESS.md` (and the Play country-change procedure)
  that adding an EEA or UK country, a price, an in-app product or ads requires re-deciding trader status first.
  Windows and iPhone: no shared code. Whether the Microsoft Store or the Apple App Store has an equivalent trader
  declaration is unverified (not fetched in this session).
- **F366. Android vitals memory check before February 2027.** Effort ~20-30 min. Priority: medium. Deadline: before
  2027-02-01 (Google gives only "February 2027", so the first day is the safe reading). Scope: Harold opens Play
  Console, Android vitals, overview, "Memory", and the App bundle explorer; record the 90th-percentile values per
  state and the optimization percentage, or record "insufficient data". If a threshold is close, open a fix card.
  Windows and iPhone: memory use comes from shared Dart code, so any fix would be shared; neither the Microsoft
  Store nor the Apple App Store memory rules were fetched (unverified).
- **F367. Fail the AAB check on a Play-restricted permission.** Effort ~45-60 min (script plus tests). Priority:
  medium. Deadline: none (prevention). Scope: extend `mobile-app/scripts/verify-aab-play-requirements.py` (the F204
  check, which already parses the `uses-permission` list) to fail when the bundle requests a permission that needs a
  Play declaration: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, ACCESS_LOCAL_NETWORK,
  READ_CONTACTS, WRITE_CONTACTS, MANAGE_CONTACTS, the SMS and call log groups, MANAGE_EXTERNAL_STORAGE,
  READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, QUERY_ALL_PACKAGES, USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM, and an
  accessibility service. A plugin upgrade could add one silently; today the check catches only AD_ID. Windows and
  iPhone: Android-only by necessity (the check reads the Android bundle manifest). An iOS Info.plist equivalent is
  out of scope and unverified.
- **F368. targetSdk 37 readiness: Local Network access for a custom IMAP host.** Effort ~60-120 min (unverified;
  includes a decision). Priority: low. Deadline: the date Play requires target API 37 for updates (unverified; not
  in this announcement), or the Flutter release that raises `flutter.targetSdkVersion` to 37, whichever comes
  first. Scope: decide between (a) requesting `ACCESS_LOCAL_NETWORK` with a Play declaration (core-use test from
  answer/16909972) and (b) a user-visible message on the custom server screen when a LAN host is blocked. This is a
  decision-class choice for Harold. Windows and iPhone: whether either platform restricts LAN connections for this
  app is unverified; if the message route is chosen it belongs in shared UI and should read the same on all three.

## Claims not verified in this session

- How Google counts "at least 30 days" (no page fetched explains it).
- What a non-trader shows publicly (search summary only; the page fetch did not confirm).
- What "EU declared development account" refers to in the Console.
- Whether the DEX floor is measured compressed or uncompressed.
- Whether Play has enough data to show a Memory value for this app.
- Whether Play Age Signals is required for this app by any regional law; answer/16585319 was not fetched.
- The date Play will require target API 37.
- Every Microsoft Store and Apple App Store parity statement.
- The current Console country list (the repo record dates from the 0.14.1 release).
- Linked pages not fetched: answer/12955712 (Families SDK list), the SMS User Consent API page, the alternative-API
  page, answer/16585319.

## Sources (all fetched 2026-11-24)

- https://support.google.com/googleplay/android-developer/answer/18100766 (Policy announcement: October 29, 2026)
- https://support.google.com/googleplay/android-developer/table/12921780?hl=en (Policy Deadlines)
- https://support.google.com/googleplay/android-developer/answer/16909972?hl=en (Preview: Permissions and APIs that
  Access Sensitive Information)
- https://support.google.com/googleplay/android-developer/answer/16558241?hl=en (Permissions and APIs that Access
  Sensitive Information)
- https://support.google.com/googleplay/android-developer/answer/18204939?hl=en (Preview: Subscriptions)
- https://support.google.com/googleplay/android-developer/answer/17006354?hl=en (Deceptive Behavior)
- https://support.google.com/googleplay/android-developer/answer/9900633?hl=en (Families Self-Certified Ads SDK
  Program)
- https://support.google.com/googleplay/android-developer/answer/16329703?hl=en (Cryptocurrency Exchanges and
  Software Wallets)
- https://support.google.com/googleplay/android-developer/answer/10208820?hl=en (Use of SMS or Call Log permission
  groups)
- https://support.google.com/googleplay/android-developer/answer/9858738?hl=en (Payments)
- https://support.google.com/googleplay/android-developer/answer/10281818?hl=en (Understanding Google Play's
  Payments policy)
- https://support.google.com/paymentscenter/answer/17595997?hl=en (Selling into or out of Japan)
- https://support.google.com/googleplay/android-developer/answer/17594752?hl=en (Trader status declaration)
- https://support.google.com/googleplay/android-developer/answer/14659200?hl=en (General conditions of access for
  Google Play in the EEA; no trader or DSA content found, but the fetch was truncated)
- https://support.google.com/googleplay/android-developer/answer/17492799?hl=en (Play Console technical quality
  requirements)
- https://android-developers.googleblog.com/2026/08/app-quality-memory-optimization-secure-onboarding.html (Android
  Developers Blog, 2026-08-26)
- https://developer.android.com/google/play/age-signals/use-age-signals-api (Use the Play Age Signals API)
- https://developer.android.com/google/play/age-signals/overview (Play Age Signals overview)
- https://developer.android.com/docs/quality-guidelines/car-app-quality (Car app quality)
- https://developer.android.com/docs/quality-guidelines/android-xr (Android XR quality guidelines)
- https://developer.android.com/privacy-and-security/local-network-permission (Local network permission)
