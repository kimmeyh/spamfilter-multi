# ADR-0050: iOS Parity Exceptions Against ADR-0042

## Status

Accepted (Harold, Sprint 80 Manual Validation, 2026-10-22, Q2 = 1). Proposed in Sprint 80, F295, GitHub #494.

**Implemented by**: Sprint 81 Task 3 (F67b code, GitHub #511): every iOS answer in `PlatformCapabilities` now cites
this ADR, and `platform_capabilities_ios_test.dart` refuses an undecided one. The background task (F67c) and iOS
notification set-up are Sprint 82.

## Date

2026-10-19

## Context

ADR-0042 says Windows and Android are the same in function and UI unless a platform cannot support the shared
behavior, and every difference is a declared, minimal platform exception. iOS has never been built. Before any iOS
code is written, F295 settled from Apple's and Google's own documentation what an iPhone version can and cannot
match. The evidence, with links, read dates and quotes, is in `docs/research/F295_IOS_READINESS.md`.

F294 (ADR-0049, Proposed, written in the same sprint) adds `PlatformCapabilities` in
`mobile-app/lib/core/platform/platform_capabilities.dart`. Several of its iOS answers read "until ADR-0050" or
"(assumed; ADR-0050)". This ADR supplies those answers. **The capability names below are provisional**: they are the
names in the working tree on 2026-10-19 and follow whatever ADR-0049 settles.

## Decision

An iOS version keeps full parity for everything a user does in the foreground. It declares the exceptions below and
no others. Each names the ADR-0042 "cannot be" category, the capability that carries it, and what iOS does instead.

### Exception 1: Background scan scheduling is best effort

- **Category**: the API does not exist. iOS has no guaranteed periodic run. Apple: "the system doesn't guarantee
  launching the task at the specified date, but only that it won't begin sooner." A refresh task gets "up to 30
  seconds of background runtime".
- **Capability**: `backgroundScanMechanism` gains an iOS value (provisional name `bgAppRefresh`; today the seam
  returns `none` for iOS).
- **iOS instead**: the user's interval becomes the EARLIEST start of each `BGAppRefreshTask`; each run scans a
  time-boxed slice and resumes from the existing cursor (ADR-0039) on the next run; a completion notification is
  sent as on the other platforms (ADR-0048). The interval control stays the same control on every platform; the
  help text describes the operating-system scheduler, not per-platform timing (ADR-0042 caveat rule).
- **Known plugin behavior**: `workmanager_apple` 0.9.11 ignores the Dart `frequency:` on iOS and uses
  `initialDelay` as the earliest start (`WorkmanagerPlugin.swift:140-157`). The iOS implementation must pass the
  interval accordingly.
- **Not decided here**: whether `BGContinuedProcessingTask` (iOS 26) keeps a user-started manual scan alive when the
  user leaves the app. That is an improvement, not part of the exception.

### Exception 2: No "Scan when new mail arrives"

- **Category**: the API does not exist. Apple's notification framework covers only "your app or app extension"; no
  background mode reads another app's notifications. A held-open IMAP IDLE connection is also ruled out: a
  suspended app's sockets may be reclaimed, and Guideline 2.5.4 limits background services to their intended
  purposes (the VoIP socket exception is for VoIP apps).
- **Capability**: `hasNewMailNotificationTrigger` is false on iOS. This is the same answer as Windows, so no new
  branch is needed: the setting is hidden on iOS exactly as on Windows (ADR-0044).
- **iOS instead**: nothing, by decision. A Gmail-only server push (Gmail Cloud Pub/Sub to an APNs background push)
  is possible in principle but needs a backend server, which ADR-0030 rules out. It would need its own ADR first.

### Mechanism differences declared here (not behavior exceptions)

These keep user-visible parity. They are listed so that the seam's iOS answers are on record.

- `googleSignInFlow` = `native` and `gmailOAuthClient` = `ios`: Google requires an iOS client type for iOS, and the
  loopback redirect Windows uses is deprecated for iOS clients.
- `renewsGmailWithStoredRefreshToken`: **open**. An iOS client refreshes without a client secret and installed
  apps always get a refresh token, so the Android stored-refresh-token path can serve iOS. Whether the native SDK
  alone renews several accounts in a locked-phone background task is UNVERIFIED (F67c settles it). Until then the
  seam keeps false for iOS.
- `socketsCloseWhenBackgrounded` = true: confirmed (Apple TN2277); the "(assumed)" can be removed.
- `requestsNotificationPermissionAtRuntime` = true: confirmed (Apple, "you must obtain permission to use them");
  the "(assumed)" can be removed.
- `exportLocation`: iOS uses the system export sheet through `file_picker` with bytes, which is the existing
  ADR-0042 "YAML export save" branch for Android and iOS. The default folder is the app's own Documents folder,
  shown in the Files app through `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. Provisional value:
  `appDocumentsInFilesApp` (replacing `undecided`). Files app visibility is UNVERIFIED until the first device build.
- `hasBatteryOptimizationSetting` = false (no per-app battery screen on iOS). The nearest control is Background
  App Refresh; a new capability (provisional `hasBackgroundRefreshSetting`) would let Settings warn when
  `UIApplication.backgroundRefreshStatus` reports it off. This is the iOS form of the Android F252 hint.
- **New capability proposed: `secureCredentialStore` background accessibility.** Background scans need Keychain
  items readable while the phone is locked. Apple recommends "after first unlock" for background apps. The token
  and credential stores already set `first_unlock_this_device`; `DatabaseEncryptionKeyService` uses the plugin
  default (`unlocked`) and must change before database encryption (SEC-11b) ships on iOS. A seam entry (or a
  shared `IOSOptions` constant with a policy test) keeps every store on the same class.
- `drawsUnderSystemBars`: not settled by this research; checked at the first iOS build.

### Store and distribution facts (no exception)

Privacy manifest, App Privacy answers ("Data Not Collected" expected under ADR-0030), the in-app privacy policy
link, and TestFlight are submission tasks of the same kind as Google Play's Data Safety form. Guideline 4.8 does
not require Sign in with Apple for a mail client. Shipping needs a Mac on macOS Tahoe 26.2 or later, Xcode 26, and
an Apple Developer Program membership (the LLC's enrollment path is UNVERIFIED).

## Alternatives Considered

### Treat iOS background scanning as unsupported (`none`)
- **Description**: ship iOS with manual scans only, as the seam does today.
- **Pros**: no best-effort behavior to explain.
- **Cons**: drops a core feature that iOS can partly provide; breaks ADR-0042's "degrade, do not disappear".
- **Why Rejected**: best-effort refresh is real background scanning, and ADR-0042 prefers graceful degradation to
  absence.

### Hold an IMAP IDLE connection in the background for new-mail detection
- **Description**: keep a socket open while the app is in the background.
- **Pros**: would match Android's immediacy.
- **Cons**: the app is suspended and its sockets may be reclaimed; no background mode permits it for a mail app;
  Guideline 2.5.4.
- **Why Rejected**: not possible within Apple's rules.

### Add a push relay server now
- **Description**: Gmail Pub/Sub plus APNs to wake the app on new mail.
- **Pros**: the only iOS route to a new-mail trigger.
- **Cons**: reverses ADR-0030 (no backend); Gmail only; ongoing server cost and data handling.
- **Why Rejected**: an architecture change of its own, deferred to a separate card (F95b) and ADR.

## Consequences

### Positive
- Every iOS difference is decided before code exists, so the iOS port is a set of seam entries, not a hunt through
  platform checks.
- Two "(assumed)" seam answers are now confirmed by Apple's documentation.

### Negative
- iOS users get background scans at times the system picks, which help text must describe honestly.
- iOS has no new-mail trigger. iOS and Windows share that gap.

### Neutral
- Several items stay UNVERIFIED until a Mac and a real iPhone exist (F67a-F67c in the research document).
- The capability names follow ADR-0049; if that ADR renames them, this ADR's intent is unchanged.

## References
- `docs/research/F295_IOS_READINESS.md` (all sources, read dates and quotes)
- ADR-0008, ADR-0014, ADR-0026, ADR-0029, ADR-0030, ADR-0035, ADR-0039, ADR-0042, ADR-0043, ADR-0044, ADR-0048,
  ADR-0049
- `mobile-app/lib/core/platform/platform_capabilities.dart` (F294, in progress)
- Apple: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
- Apple: https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate
- Apple: https://developer.apple.com/app-store/review/guidelines/ (Last Updated: October 16, 2026)
- Google: https://developers.google.com/identity/protocols/oauth2/native-app
- Google: https://developers.google.com/identity/sign-in/ios/start-integrating
