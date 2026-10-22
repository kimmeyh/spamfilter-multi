# F295: iPhone Readiness Research

**Sprint**: 80, Task 5 (GitHub #494). **Type**: time-boxed research spike. No app code changed.
**Date of research**: 2026-10-19. Every source below was read on 2026-10-19 unless a different date is given.
**Companion ADR**: `docs/adr/0050-ios-parity-exceptions.md` (Status: Accepted by Harold 2026-10-22, Sprint 80 Manual Validation).

**Quotation convention**: quotations are verbatim. The only normalization is punctuation: a curly apostrophe is
written as `'` and an em dash inside a quotation is written as ` -- `. Nothing else is changed. Apple developer
documentation was read from the machine-readable form of each page
(`https://developer.apple.com/tutorials/data/documentation/<path>.json`), which carries the same text as the
rendered page at `https://developer.apple.com/documentation/<path>`. Plugin claims cite the version in
`mobile-app/pubspec.lock` and, where the source was read, `file:line` in the local pub cache
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<package>-<version>\`).

## Bottom line

An iPhone version can match Windows and Android on everything a user does in the foreground: scanning, rules, safe
senders, Gmail and IMAP sign-in, review screens, notifications, and export. It CANNOT match the two unattended
features. iOS has no guaranteed periodic background run (the system picks the time, and a refresh task gets about
30 seconds), and iOS has no documented way to read another app's notifications, so "Scan when new mail arrives" cannot exist
there. Both are "the API does not exist" exceptions under ADR-0042. Two smaller items are open and marked
UNVERIFIED: how Gmail renewal works for several Gmail accounts in a background task on iOS, and how the publishing
LLC enrolls with Apple. Building and shipping needs a Mac on macOS Tahoe 26.2 or later with Xcode 26, and a paid
Apple Developer Program membership.

## Verdict summary

- **Q1 Background scheduling**: EXCEPTION. Best-effort `BGAppRefreshTask` (system-chosen time, about 30 seconds).
  No 15-minute guarantee. Category: the API does not exist.
- **Q2 New-mail trigger**: EXCEPTION. No API reads another app's notifications; IMAP IDLE cannot run while
  suspended; push needs a server the app does not have (ADR-0030). iOS joins Windows (no trigger). Category: the
  API does not exist.
- **Q3 Gmail OAuth**: PARITY possible for sign-in (native Google Sign-In with an iOS client ID). Background
  renewal for several accounts is UNVERIFIED.
- **Q4 Credential storage**: PARITY possible. Keychain with "after first unlock" accessibility. The app's token and
  credential stores already ask for it. One store does not (not used in production today).
- **Q5 App Store privacy and review**: PARITY possible, with work: privacy manifest, App Privacy answers, a privacy
  policy link in the app. Sign in with Apple is NOT required (Guideline 4.8 mail-client exemption).
- **Q6 Build and distribution**: no parity question. Prerequisites: Mac, Xcode 26, Apple Developer Program
  (organization path for the LLC is UNVERIFIED), TestFlight for testers.
- **Q7a Notifications**: PARITY possible (same plugin as ADR-0048; runtime permission, like Android 13+).
- **Q7b Export**: PARITY possible (same system save sheet contract as Android; the app's Documents folder can be
  shown in the Files app).

---

## Q1. iOS background scheduling

### Finding

iOS runs background work only when the system decides. The app can set an EARLIEST start time, never a guaranteed
one. A refresh task gets "up to 30 seconds". A processing task can run for minutes, but the system picks when,
typically at times of low activity such as overnight charging. There is no exact-alarm equivalent of Android's
Doze alarm and no equivalent of Windows Task Scheduler. The user can also turn Background App Refresh off, and Low
Power Mode turns it off automatically.

The Flutter `workmanager` plugin supports iOS through `workmanager_apple` (BGTaskScheduler). Source reading shows
that on iOS the Dart `frequency:` argument of `registerPeriodicTask` is NOT used: only `initialDelay` sets the first
`earliestBeginDate`.

### Sources

1. `earliestBeginDate`, https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate
   - "Setting the property indicates that the background task shouldn't start any earlier than this date. However,
     the system doesn't guarantee launching the task at the specified date, but only that it won't begin sooner."
2. Choosing background strategies for your app,
   https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
   - "The system decides the best time to launch your background task, and provides your app up to 30 seconds of
     background runtime. Complete your work within this time period and call setTaskCompleted(success:), or the
     system terminates your app."
   - On processing tasks: "you can schedule backgrounds tasks for periods of low activity, such as overnight when the
     device charges." and "Schedule these types of background tasks using BGProcessingTask, and the system decides
     the best time to launch your background task."
3. Using background tasks to update your app,
   https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app
   - Apple's own sample: "// Fetch no earlier than 15 minutes from now." with
     `request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)`. This is a floor, not a schedule (source 1).
   - "In iOS 13 and later, adding a BGTaskSchedulerPermittedIdentifiers key to the Info.plist disables the
     application(_:performFetchWithCompletionHandler:) and setMinimumBackgroundFetchInterval(_:) methods."
4. `setMinimumBackgroundFetchInterval(_:)`,
   https://developer.apple.com/documentation/uikit/uiapplication/setminimumbackgroundfetchinterval(_:)
   - Deprecated in iOS 13.0. Deprecation note: "For apps supporting iOS 13 and higher use BGAppRefreshTask."
5. `BGContinuedProcessingTaskRequest` (iOS 26),
   https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest
   - "The app submits this request from the foreground. Submission needs to occur as a result of a person's action,
     such as tapping a button." This can keep a user-started MANUAL scan alive when the user leaves the app. It does
     not start unattended scans.
6. `backgroundRefreshStatus`, https://developer.apple.com/documentation/uikit/uiapplication/backgroundrefreshstatus
   - "Background App Refresh is disabled automatically when a device is operating in low-power mode. When this
     happens, the time available for performing background tasks is reduced to save power."
7. workmanager 0.10.10 (locked), https://pub.dev/packages/workmanager, and its README in the pub cache
   (`workmanager-0.10.10/README.md:27`): "A Flutter wrapper around [Android's WorkManager](...), [iOS Background
   Tasks](...), and macOS `NSBackgroundActivityScheduler`". README line 71: "**workmanager_apple**: iOS
   implementation using BGTaskScheduler + macOS implementation using NSBackgroundActivityScheduler".
8. workmanager documentation, https://docs.page/fluttercommunity/flutter_workmanager/quickstart
   - "iOS completely controls when Background Fetch runs (typically once per day based on user app usage
     patterns)."
   - "iOS: 30-second limit, execution depends on user patterns and device state."
   - "iOS 14.0 or later is required."
9. workmanager_apple 0.9.11 (locked) source,
   `workmanager_apple-0.9.11/ios/workmanager_apple/Sources/workmanager_apple/WorkmanagerPlugin.swift`
   (the iOS region is `#if os(iOS)` at line 104 to `#endif` at line 306; the macOS implementation starts at
   `#if os(macOS)` on line 334. The API shape agrees: the iOS path reaches `BGAppRefreshTaskRequest` at line 735,
   an iOS-only API, while the macOS path at lines 377-381 passes `frequencySeconds` as `interval:` to
   `MacOSActivityScheduler`, the `NSBackgroundActivityScheduler` wrapper):
   - Lines 140-157: the iOS `registerPeriodicTask` reads `request.initialDelaySeconds` and passes it as
     `earliestBeginInSeconds`. `request.frequencySeconds` is not read in this region.
   - Lines 733-741: `schedulePeriodicTask` builds a `BGAppRefreshTaskRequest` and sets only `earliestBeginDate`.
   - Lines 512-513: after each run, "Schedule the next occurrence (iOS will determine actual timing based on usage
     patterns)", reusing the `earliestBeginInSeconds` value captured when the launch handler was registered (lines
     880-899, supplied by the native `registerPeriodicTask(withIdentifier:earliestBeginInSeconds:)` at line 710).
     I did not trace every path that registers the launch handler; treat the exact reschedule value as a lead to
     confirm on a device.

### Comparison

- **Windows**: Task Scheduler runs per account at the chosen interval (ADR-0014, ADR-0039). Exact.
- **Android**: WorkManager 15-minute periodic safety net plus an exact alarm that survives Doze (ADR-0039, F264).
  Near-exact.
- **iOS**: `BGAppRefreshTask` with an earliest-start floor; the system decides; up to 30 seconds per run; disabled
  by Low Power Mode or by the user. No guarantee of any interval. A scan of a large mailbox can take longer than
  30 seconds (inference; not measured on iOS), so an iOS background scan must be resumable across runs. The app's
  backlog cursor (ADR-0039) is the existing mechanism for that.

### Parity verdict

**EXCEPTION needed** (ADR-0042 category: the API does not exist). iOS instead: best-effort background refresh with
the user's interval as the earliest-start floor, a time-boxed scan slice per run that resumes from the cursor, and
honest UI text (the interval is a minimum, not a schedule). `BGContinuedProcessingTask` is a candidate for letting
a user-started manual scan finish in the background (iOS 26 and later).

**UNVERIFIED**:
- Typical real-world iOS refresh frequency for a mail-style app. No Apple page gives a number. Settle by a device
  test: log every `BGAppRefreshTask` launch for 7 days on a real iPhone with normal use.
- Whether a `BGProcessingTask` with `requiresNetworkConnectivity` helps a large first scan. Settle by the same
  device log.

---

## Q2. "Scan when new mail arrives" on iOS

### Finding

iOS has no equivalent of Android's `NotificationListenerService`. Apple's notification framework covers only "your
app or app extension". Apple's own inventory of ways to run in the background (the strategies page and the
background-mode table) has no entry that reads another app's notifications. A persistent IMAP IDLE connection
cannot work while the app is suspended, and Guideline 2.5.4 limits background services to their intended purposes.
The supported "new mail" route on iOS is a remote push from a server: Gmail can publish to Cloud Pub/Sub, and a
server would then send an APNs background push. The app has no backend server by decision (ADR-0030), so that route
is a separate architecture decision, not a parity port. AOL, Yahoo and other IMAP accounts offer no push the app
could use without a server that holds the user's credentials.

This is a negative finding. It rests on Apple's enumerated lists, not on a sentence that says "no such API".

### Sources

1. `UNUserNotificationCenter`, https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
   - "The central object for managing notification-related activities for your app or app extension."
   - "Manage the already delivered notifications the system displays in Notification Center." (the app's own
     notifications).
2. Configuring background execution modes,
   https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
   - "Typically, an app is in a suspended state when it's in the background. However, there are a limited number of
     background execution modes your app can support".
   - The complete mode table lists: audio, location, voip, external-accessory, bluetooth-central,
     bluetooth-peripheral, screen-capture, fetch, remote-notification, processing, workout-processing,
     nearby-interaction, push-to-talk. None observes other apps or holds a mail connection open.
3. Choosing background strategies (URL in Q1)
   - "an email app that processes incoming mail without alerting the user" is Apple's own example for a background
     push, which needs a server: "When sending a background push, set content-available: to 1 without alert, sound,
     or badge. The system decides when to launch the app to download the content."
   - "If you send background pushes more frequently than three times per hour, the system imposes rate
     limitations."
   - Notification Service Extension: "Upon receiving a push notification, your service extension wakes up and
     obtains background runtime". Also server-driven.
4. TN2277 Networking and Multitasking, https://developer.apple.com/library/archive/technotes/tn2277/_index.html
   (archived; revision 2011-03-30; Apple marks it as no longer updated)
   - "while the app is suspended the system may choose to reclaim resources out from underneath a network socket
     used by the app, thereby closing the network connection represented by that socket."
   - "IMAP supports an IDLE command that allows clients to be notified asynchronously when a mailbox changes.
     There's no point having your app receive these notifications while it is suspended, so you definitely want to
     cancel these IDLE requests when going into the background."
   - The only exception it describes is a VoIP socket, which is not available to a mail app (source 5).
5. App Review Guidelines 2.5.4, https://developer.apple.com/app-store/review/guidelines/ (page shows "Last Updated:
   October 16, 2026")
   - "Multitasking apps may only use background services for their intended purposes: VoIP, audio playback,
     location, task completion, local notifications, etc."
6. Gmail push notifications, https://developers.google.com/workspace/gmail/api/guides/push (last updated
   2026-09-15)
   - "The Gmail API uses the Cloud Pub/Sub API to deliver push notifications."
   - "You must call the watch method at least once every 7 days".

### Parity verdict

**EXCEPTION needed** (ADR-0042 category: the API does not exist; for the VoIP-socket route, a platform policy
forbids it). iOS instead: no new-mail trigger; the setting is hidden, exactly as on Windows today
(`hasNewMailNotificationTrigger` is already false on Windows). A server-relayed push is possible in principle for
Gmail only and is recorded as a future option that would first need a new ADR superseding ADR-0030's "no backend
server".

**Also confirmed by the same sources**: `socketsCloseWhenBackgrounded` is true on iOS (TN2277 source 4, and the
"suspended state" sentence in source 2). The seam's "(assumed)" can be removed for iOS.

---

## Q3. Gmail OAuth on iOS

### Finding

Google documents one path for iOS: an OAuth client of type **iOS**, used through the Google Sign-In SDK, with the
reversed client ID registered as a URL scheme. `google_sign_in` (7.2.0 locked) supports iOS through
`google_sign_in_ios` (6.2.4 locked; 6.3.8 current). A loopback redirect (the Windows method) is deprecated for iOS
clients. An iOS client has no client secret, and installed apps always receive a refresh token.

There is a documentation tension that must be resolved by a test, not by reading. Google's general native-app page
says custom URI schemes are "no longer supported", while Google's own iOS guide and the plugin both configure a
reversed-client-ID URL scheme. The native SDK path is the one Google documents for iOS today.

Background renewal: the plugin can renew without UI (`refreshTokensIfNeeded`). It keeps signed-in users in an
in-process map and restores only the previous user, so renewal of SEVERAL Gmail accounts inside a background task is
not proven. The app also has a stored-refresh-token renewal path (Android fallback, Sprint 76) that could serve iOS,
because an iOS client refreshes without a secret.

### Sources

1. Google Sign-In for iOS, Get started, https://developers.google.com/identity/sign-in/ios/start-integrating (last
   updated 2026-03-22)
   - "For iOS and macOS apps the OAuth client ID application type must be configured as iOS."
   - "The reversed client ID is your client ID with the order of the dot-delimited fields reversed."
2. OAuth 2.0 for iOS and Desktop Apps, https://developers.google.com/identity/protocols/oauth2/native-app (last
   updated 2026-10-16)
   - "The loopback IP address redirect option is DEPRECATED for Android, Chrome app and iOS OAuth client types."
   - "Custom URI schemes are no longer supported due to the risk of app impersonation." and, in the redirect
     parameter section, "Custom URI schemes are no longer supported on Android and Chrome apps." (iOS is not named.)
   - "Note that refresh tokens are always returned for installed applications."
   - On refreshing: "(The `client_secret` is not applicable to requests from clients registered as Android, iOS, or
     Chrome applications.)"
   - "Refresh tokens are valid until the user revokes access or the refresh token expires."
   - Libraries named for iOS: Google Sign-In for iOS and OpenID Foundation's AppAuth for iOS, in place of embedded
     web views.
3. `google_sign_in` 7.2.0, https://pub.dev/packages/google_sign_in
   - Platform table lists iOS 12.0+.
   - "Server auth codes are not always available on all platforms."
4. `google_sign_in_ios` (6.3.8 current; 6.2.4 locked), https://pub.dev/packages/google_sign_in_ios
   - Setup: add `GIDClientID` to `ios/Runner/Info.plist`, and a `CFBundleURLTypes` entry whose
     `CFBundleURLSchemes` value is the `REVERSED_CLIENT_ID`.
5. `GIDGoogleUser`, https://developers.google.com/identity/sign-in/ios/reference/Classes/GIDGoogleUser (last
   updated 2025-05-19)
   - `refreshTokensIfNeeded`: "Refresh the user's access and ID tokens if they have expired or are about to expire."
6. `google_sign_in_ios-6.2.4/darwin/google_sign_in_ios/Sources/google_sign_in_ios/FLTGoogleSignInPlugin.m`
   - Lines 180-186: `restorePreviousSignInWithCompletion` (one previous user).
   - Lines 211-231: `refreshedAuthorizationTokensForUser` looks the user up in `self.usersByIdentifier` and fails
     with "The user is no longer signed in." when that in-process map has no entry; otherwise it calls
     `refreshTokensIfNeededWithCompletion`.
7. `flutter_appauth` (12.0.2 locked; 12.1.0 current), https://pub.dev/packages/flutter_appauth
   - iOS setup adds a `CFBundleURLSchemes` entry in `Info.plist`; `preferEphemeralSession` is available "On iOS
     (versions 13 and above)".
8. `ASWebAuthenticationSession`,
   https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
   - "ASWebAuthenticationSession ensures that only the calling app's session receives the authentication callback,
     even when more than one app registers the same callback URL scheme."

### Parity verdict

**PARITY possible** for interactive sign-in (the seam already answers `googleSignInFlow = native` and
`gmailOAuthClient = ios` for iOS; both are consistent with source 1). The Windows loopback flow is not available
on iOS (source 2), so the flow is a mechanism difference that the seam already declares, not a user-visible one.

**UNVERIFIED**:
- **Background renewal for several Gmail accounts** (`renewsGmailWithStoredRefreshToken` on iOS). Settle by a
  device spike: two Gmail accounts, a `BGAppRefreshTask` with the phone locked, and a log of whether each account's
  token renews through `google_sign_in_ios`; if not, test the stored-refresh-token HTTP path with the iOS client ID
  (no secret, source 2).
- **Browser fallback (`flutter_appauth`) with an iOS client ID and the reversed-client-ID scheme**. Source 2 and
  source 1 conflict on custom schemes. Settle by a sign-in test on a device with the real iOS client in Google Cloud
  Console.
- **Keychain accessibility of the Google Sign-In SDK's own stored session**. The SDK stores its session itself; its
  accessibility class is not stated in any page read. Settle by reading the GoogleSignIn-iOS and GTMAppAuth source
  at the version `google_sign_in_ios` resolves, or by the locked-phone device test above.
- **Verification**: whether Google's restricted-scope verification (ADR-0029) must be repeated for a new iOS client
  in the same project. Settle in Google Cloud Console (OAuth consent screen, verification status) when the iOS
  client is created.

---

## Q4. Credential storage

### Finding

iOS Keychain supports background access through the "after first unlock" accessibility classes. Apple recommends
exactly that for background apps. `flutter_secure_storage` (10.3.1 locked; 11.2.0 current) defaults to `unlocked`,
which would fail when the phone is locked. The app's two credential stores already set
`KeychainAccessibility.first_unlock_this_device`. `DatabaseEncryptionKeyService` uses the default, but it is not used
in production today (SEC-11b HOLD); it must set the same class before database encryption ships on iOS.

### Sources

1. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
   https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly
   - "The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by
     the user."
   - "After the first unlock, the data remains accessible until the next restart. This is recommended for items
     that need to be accessed by background applications. Items with this attribute do not migrate to a new device."
2. Restricting keychain item accessibility,
   https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
   - "by default, you can only access keychain items when the device is unlocked."
   - "Always use the most restrictive option that makes sense for your app."
3. `flutter_secure_storage` README (10.3.1, pub cache `README.md:109-111`; same text on pub.dev 11.2.0):
   - "`first_unlock`: Enables access to secure values after the device is unlocked for the first time after a
     reboot."
   - "`unlocked` (default): Values are accessible only when the device is unlocked."
4. `flutter_secure_storage_darwin-0.3.2/.../FlutterSecureStorage.swift:96`: `"first_unlock_this_device"` maps to
   `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; line 97 shows the default is `kSecAttrAccessibleWhenUnlocked`.
5. App code: `mobile-app/lib/adapters/auth/secure_token_store.dart:43-45` and
   `mobile-app/lib/adapters/storage/secure_credentials_store.dart:82-84` set `first_unlock_this_device`;
   `mobile-app/lib/core/security/database_encryption_key_service.dart:45` uses the default.

### Parity verdict

**PARITY possible** (Android Keystore and Windows Credential Manager equivalents, ADR-0008). One consequence is
shared with Android: after a reboot, before the first unlock, a background scan cannot read credentials and must
skip cleanly. The "ThisDeviceOnly" class means credentials do not move to a new iPhone through a backup, so the user
signs in again after a device change. That is likely the same outcome as Android's Keystore today (inference; not
verified in this spike).

---

## Q5. App Store privacy and review rules

### Finding

1. **Privacy manifest**: required for an app or SDK that uses a "required reason" API; App Store Connect rejects an
   upload that uses one without a declared reason (since 2024-05-01). Flutter ships manifests for the engine, and
   plugins are expected to ship their own; the app still needs its own `PrivacyInfo.xcprivacy` for any covered API
   its own code calls.
2. **App Privacy (nutrition label)**: data processed only on the device is not "collected". The app reads mail on
   the device and has no server (ADR-0030), so the expected answer is "Data Not Collected". This is a reasonable
   inference from Apple's definition, not an Apple ruling; App Review decides.
3. **Review rules**: a privacy policy link is required in App Store Connect and inside the app (the app already has
   one for Google Play). Data minimization applies. Guideline 4.8 does NOT require Sign in with Apple, because the
   app is a client that signs in to the user's mail account. Background services may be used only for their
   intended purposes (2.5.4), which a background refresh for content fits.
4. No guideline read singles out apps that delete or move mail. Deleting mail is the app's stated core function;
   accurate description and purpose strings are the general requirement (2.5.1, 5.1.1).

### Sources

1. Privacy manifest files, https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
   - "By default, the file is named PrivacyInfo.xcprivacy; this is the required file name for bundled privacy
     manifests."
2. Describing use of required reason API,
   https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
   - "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file
     aren't accepted by App Store Connect."
3. App privacy details, https://developer.apple.com/app-store/app-privacy-details/
   - "Data that is processed only on device is not "collected" and does not need to be disclosed in your answers."
   - Data type definition: "Emails or Text Messages: Including subject line, sender, recipients, and contents of the
     email or message".
   - "You're responsible for keeping your responses accurate and up to date."
4. App Review Guidelines, https://developer.apple.com/app-store/review/guidelines/ ("Last Updated: October 16,
   2026")
   - 4.8 exemption: "Your app is a client for a specific third-party service and users are required to sign in to
     their mail, social media, or other third-party account directly to access their content."
   - 5.1.1(i): "All apps must include a link to their privacy policy in the App Store Connect metadata field and
     within the app in an easily accessible manner."
   - 5.1.1(iii): "Apps should only request access to data relevant to the core functionality of the app and should
     only collect and use data that is required to accomplish the relevant task."
   - 2.5.1: "Apps may only use public APIs and must run on the currently shipping OS."
5. Flutter 3.24 and 3.27 release notes, https://docs.flutter.dev/release/release-notes/release-notes-3.24.0 and
   https://docs.flutter.dev/release/release-notes/release-notes-3.27.0. These were seen only as search-result
   text on docs.flutter.dev, not opened, so they are leads: entries "Add PrivacyInfo.xcprivacy to plugin template"
   (3.24) and "Assert iOS framework artifact contains xcprivacy manifest" (3.27). Flutter's plugin-author guidance:
   https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors. The claim that Flutter
   ships manifests for the engine is therefore UNVERIFIED (settled by the Xcode privacy report below).

### Parity verdict

**PARITY possible**. These are store-submission tasks, the same kind as the Google Play Data Safety form and the
Microsoft Store privacy policy. No functional exception.

**UNVERIFIED**:
- Which required-reason API categories the final iOS binary uses (for example file timestamp or `UserDefaults`
  APIs from plugins). Settle by building the iOS app and running Xcode's privacy report (Product > Archive, then
  Generate Privacy Report) on the archive.
- Whether each locked plugin version ships its own `PrivacyInfo.xcprivacy`. Settle by the same privacy report, or
  by checking each plugin's `ios/` or `darwin/` folder in the pub cache.
- Whether App Review accepts "Data Not Collected" for this app. Settle only by submission.

---

## Q6. Build and distribution requirements

### Finding

- A Mac is required. Flutter: "You must use a device running macOS to follow this guide." Xcode 26.6 needs macOS
  Tahoe 26.2 or later.
- Since 2026-04-28, uploads must be built with Xcode 26 and the iOS 26 SDK.
- Flutter supports iOS 13 and later; the plugins this app uses raise that floor (workmanager and file_picker state
  iOS 14.0). Apple now requires a deployment target of iOS 13 or later (2026-09-09 entry).
- Apple Developer Program: 99 USD per year. An organization needs a legal entity, a D-U-N-S Number, a public website
  on its own domain, and a work email on that domain. The individual path is for "an individual or sole
  proprietor/single person business".
- TestFlight: up to 100 internal testers and 10,000 external testers; each build can be tested for 90 days; the
  first build for external testers goes through App Review.
- Lead, UNVERIFIED (seen only in docs.flutter.dev search-result text, page not opened): Flutter 3.44 moved iOS
  native dependencies to Swift Package Manager and CocoaPods is in maintenance mode. Settle by reading the Flutter
  3.44 release notes on docs.flutter.dev before the first iOS build.

### Sources

1. Flutter, Build and release an iOS app, https://docs.flutter.dev/deployment/ios (page last updated 2026-07-31;
   reflects Flutter 3.47)
   - "Xcode is required to build and release your app. You must use a device running macOS to follow this guide."
   - "To publish your app to the App Store, you must first enroll in the Apple Developer Program."
   - "Flutter supports iOS 13 and later."
2. Upcoming requirements, https://developer.apple.com/news/upcoming-requirements/
   - "Apps uploaded to App Store Connect must be built with Xcode 26 or later using an SDK for iOS 26, iPadOS 26,
     tvOS 26, visionOS 26, or watchOS 26." (effective April 28, 2026)
   - "iOS and iPadOS apps uploaded to App Store Connect must target iOS 13 or later." (entry dated September 9,
     2026)
3. Xcode system requirements, https://developer.apple.com/xcode/system-requirements/
   - Xcode 26.6 row, supported macOS: "macOS Tahoe 26.2 - macOS Tahoe 26.x".
4. Enrollment, https://developer.apple.com/programs/enroll/
   - "Your organization must be a legal entity that can enter into contracts with Apple. We do not accept DBAs,
     fictitious business names, trade names, or branches."
   - "Your organization (excluding government entities) must have a D-U-N-S Number so that we can verify your
     organization's identity, legal entity status, and address."
   - "Your organization's website must be publicly available and functional, and its domain name must be associated
     with your organization."
   - "If you're an individual or sole proprietor/single person business, you'll need an Apple Account with
     two-factor authentication turned on and be the legal age of majority in your region."
   - "The Apple Developer Program is 99 USD per membership year."
5. TestFlight overview, https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
   - "You can test a build for up to 90 days."
   - "When you add the first build of your app to a group, the build gets sent to App Review to make sure it follows
     the App Review Guidelines."
6. TestFlight, https://developer.apple.com/testflight/
   - "You can also invite up to 10,000 external testers to join your beta program."

### Parity verdict

Not a parity question. It is a set of prerequisites (no Mac is on hand today; the project is Windows-only).

**UNVERIFIED**:
- **Which enrollment path the LLC takes.** The enrollment page does not mention an LLC. A single-member LLC is a
  legal entity, which points to the organization path (D-U-N-S Number, domain website, domain email), and the
  seller name shown on the App Store would then be the LLC's name. Settle by Apple's enrollment flow or Apple
  Developer Support, and by checking whether the LLC already has a D-U-N-S Number (the Google Play organization
  account may have needed one).
- **Whether a cloud Mac is acceptable** in place of buying one. Apple's pages read do not address it. Settle by
  choosing a provider and confirming it offers macOS Tahoe 26.2 or later with Xcode 26 and a GUI session for
  signing.

---

## Q7. Local notifications and export location

### Finding

- **Notifications**: `flutter_local_notifications` (22.3.2 locked, the plugin ADR-0048 chose for both platforms)
  supports iOS. iOS asks the user for permission at runtime, as Android 13+ does. iOS keeps at most 64 pending
  notifications; this app shows notifications immediately and does not schedule them, so the limit does not apply.
  The AppDelegate needs the plugin's delegate line, and a background engine needs the plugin registrant callback.
- **Export**: `file_picker` 8.3.7 (locked) uses the same contract on iOS as on Android: the app passes the bytes, and
  the system export sheet writes the file where the user picks (Files app, iCloud Drive, or another provider). The
  ADR-0042 "YAML export save" exception already covers both Android and iOS. Separately, the app's own Documents
  folder can be shown in the Files app with two Info.plist keys, which can carry the F282 "Documents/MyEmailSpamFilter"
  default.

### Sources

1. Asking permission to use notifications,
   https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
   - "Because a person might consider notification-based interactions disruptive, you must obtain permission to use
     them."
   - "The first time your app makes this authorization request, the system prompts the person to grant or deny the
     request and records that response."
2. `flutter_local_notifications`, https://pub.dev/packages/flutter_local_notifications (22.3.2)
   - Platform list includes iOS. iOS setup adds
     `UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate` to
     `application:didFinishLaunchingWithOptions:`; permissions through `DarwinInitializationSettings`
     (`requestAlertPermission`, `requestBadgePermission`, `requestSoundPermission`).
   - iOS keeps only the 64 most recently set pending notifications (iOS 10 and newer).
3. `file_picker-8.3.7/lib/src/file_picker_io.dart:148-151`: on iOS and Android, `saveFile` throws "Bytes are required
   on Android & iOS when saving a file." when bytes are missing.
4. `file_picker-8.3.7/ios/file_picker/Sources/file_picker/FilePickerPlugin.m:199`: the iOS save uses
   `UIDocumentPickerViewController ... inMode:UIDocumentPickerModeExportToService` (the system export sheet).
5. `UIFileSharingEnabled`,
   https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled
   - "If you set this key to YES, your app can share files with the user. Place the files in a Documents folder
     located in the app's home directiory." (Apple's spelling.)
6. `LSSupportsOpeningDocumentsInPlace`,
   https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsopeningdocumentsinplace
   - "A Boolean value indicating whether the app may open the original document from a file provider, rather than a
     copy of the document."

### Parity verdict

- **Notifications: PARITY possible** (`requestsNotificationPermissionAtRuntime` is true on iOS, confirmed by source
  1; the seam's "(assumed)" can be removed).
- **Export: PARITY possible.** The save sheet contract is the existing Android branch. The default folder is a
  mechanism difference (the app's sandboxed Documents, exposed in the Files app) rather than a behavior difference,
  the same kind as the Android/Windows "how Documents is found" difference ADR-0042 already records.

**UNVERIFIED**:
- That the Files app shows the app's Documents folder with `UIFileSharingEnabled` and
  `LSSupportsOpeningDocumentsInPlace` set, and that the export sheet can start in it. Apple's pages define the keys
  but do not show the Files app result. Settle by a device test.
- Showing a notification from a `workmanager` background engine on iOS. The plugin page does not describe it.
  Settle by the Q1 device spike (scan completes, notification appears).

---

## Other seam answers found on the way

- `hasBatteryOptimizationSetting`: iOS has no per-app battery optimization screen. The closest user control is
  Background App Refresh (system-wide and per app), which `UIApplication.backgroundRefreshStatus` reports (Q1 source
  6: "You can use this property to determine whether Background App Refresh -- an app's ability to open in the
  background to perform refresh tasks -- is enabled, and warn the user if it is not."). Parity possible as a
  warning that points to iOS Settings, not as the Android "Unrestricted" switch.
- `drawsUnderSystemBars`: not researched in this spike (UI layout, not a platform capability question). Leave as the
  seam has it and check during the first iOS build.

---

## Replacement cards for F67 and F95

These replace the iOS parts of F67 and F95. Linux and macOS stay on F67; the multi-variant (side-by-side install)
part of F95 stays as it is. Effort is in the backlog's hour format. Do not merge before Harold accepts ADR-0050.

**F67a. iOS prerequisites: Apple Developer enrollment, Mac, iOS OAuth client (~3-6h plus Apple and D-U-N-S lead time) Priority HOLD**
- Phase: Multi-Platform Readiness
- Platform: iOS
- Scope: decide the enrollment path for the LLC (organization: D-U-N-S Number, domain website, domain email); enroll
  (99 USD per year); get a Mac on macOS Tahoe 26.2 or later with Xcode 26 (owned or cloud); create the iOS OAuth
  client in Google Cloud Console (bundle ID per ADR-0026) and check the verification status of the restricted Gmail
  scope for it.
- Settles UNVERIFIED items: LLC enrollment path, cloud Mac acceptability, Gmail verification for the iOS client.
- Depends on: Harold's go decision for iOS; ADR-0050 accepted.

**F67b. iOS first build and foreground parity validation (~6-10h) Priority HOLD**
- Phase: Multi-Platform Readiness
- Platform: iOS
- Scope: `flutter build ios` on Xcode 26 with Swift Package Manager; deployment target iOS 14 (plugin floor);
  Info.plist (`GIDClientID`, reversed-client-ID URL scheme, background modes `fetch`, `BGTaskSchedulerPermittedIdentifiers`,
  `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`); AppDelegate lines for notifications and workmanager;
  fill every `PlatformCapabilities` iOS answer from ADR-0050; smoke test, IMAP scan, Gmail sign-in, rules, review
  screens, export to Files, notification permission.
- Settles UNVERIFIED items: custom-scheme browser fallback, Files app visibility, `drawsUnderSystemBars`.
- Depends on: F67a; F294 seam merged.

**F67c. iOS background scan spike on a real iPhone (~6-10h plus a 7-day observation window) Priority HOLD**
- Phase: Multi-Platform Readiness
- Platform: iOS
- Scope: `BGAppRefreshTask` per the ADR-0050 exception (interval is a floor; a time-boxed scan slice that resumes
  from the cursor; confirm the `workmanager_apple` `frequency` finding and pass the interval as the earliest start);
  locked-phone run with two Gmail accounts and one IMAP account; log every background launch for 7 days; completion
  notification from the background engine; Background App Refresh "off" warning in Settings; decide whether
  `BGContinuedProcessingTask` keeps a manual scan alive (iOS 26).
- Settles UNVERIFIED items: real refresh frequency, multi-account Gmail renewal while locked, Google Sign-In SDK
  keychain accessibility, background notification.
- Depends on: F67b. Outcome may change the Gmail renewal design (a Class 2 decision to surface).

**F67d. iOS store readiness: privacy manifest, App Privacy, TestFlight (~4-6h) Priority HOLD**
- Phase: Build and Release Infrastructure
- Platform: iOS
- Scope: Xcode privacy report on an archive; app `PrivacyInfo.xcprivacy` with the required-reason entries the report
  finds; App Store Connect App Privacy answers (expected "Data Not Collected", ADR-0030); privacy policy link in app
  and metadata; release notes per ADR-0043; TestFlight internal group, then an external group (first build goes
  through App Review); help and store text that describe background scanning as best effort on iOS without a
  platform caveat (ADR-0042 rule on caveats).
- Settles UNVERIFIED items: required-reason API set, plugin manifests.
- Depends on: F67c.

**F95 (revised). iOS variants: dev and prod side by side on one iPhone (~3-5h) Priority HOLD**
- Phase: Build and Release Infrastructure
- Platform: iOS
- Scope: separate bundle IDs for dev and prod (ADR-0035 on iOS), so both install on one device; separate OAuth iOS
  clients or URL schemes per variant; separate keychain items and app data by construction (separate bundle IDs);
  TestFlight as the "store" channel. The cross-store multi-variant polish for Windows and Android stays on the
  existing F95.
- Depends on: F67b.

**F95b. Gmail new-mail push through a server (~16-30h) Priority HOLD -- needs a new ADR first**
- Phase: Architecture
- Platform: iOS (Gmail accounts only)
- Scope: only if Harold wants "Scan when new mail arrives" on iPhone. Gmail `users.watch` to Cloud Pub/Sub, a relay
  that sends an APNs background push, renewal of the watch at least every 7 days. Background pushes are rate
  limited above three per hour. Requires an ADR superseding ADR-0030's "No backend server".
- Depends on: F67c; a Class 1 decision by Harold.

---

## Elapsed time

Started 2026-10-19 00:29:56 (PDT). Finished 2026-10-19 00:45 (PDT). Elapsed: about 16 minutes against a 90-120
minute time-box. The device-dependent items are left UNVERIFIED by design; no amount of reading settles them.
