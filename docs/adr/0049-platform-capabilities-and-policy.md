# ADR-0049: Platform Capabilities and Platform Policy -- One Seam for Every Platform Difference

## Status

Accepted (Harold, Sprint 80 Manual Validation, 2026-10-22, Q1 = 1). The Class-1 change itself was approved at Sprint
80 plan approval, 2026-10-19, Q1 = 1: *"q1 a - and do any adr approval at Manual Validation"*.

## Date

2026-10-19 (Sprint 80, F294, Issue #493)

## Context

ADR-0042 requires Windows and Android to be functionally and visually the same unless a platform cannot match, and a
difference to be a declared platform exception. Before this ADR the differences were not declared in one place. They
were 62 bare `Platform.isAndroid` / `Platform.isWindows` / `Platform.isIOS` / `Platform.isMacOS` / `Platform.isLinux`
checks in 21 files under `mobile-app/lib/` (65 grep matches; 3 are in comments), counted 2026-10-18. Each check decided
a difference where it stood, so:

- adding a platform (iOS, F295 / ADR-0050) meant finding and deciding all 62 by hand, and a missed one fails silently;
- a check said WHICH platform, not WHY, so a reader could not tell a real OS limit from a style choice;
- tests could not run the Android branch on the Windows test host except through four ad hoc seams
  (`main.dart` `debugIsAndroid`, `settings_screen.dart` `debugIsAndroid`, `SystemInsetWrapper.debugIsAndroid`,
  `ScanCompleteNotifier.isAndroidOverride`), each shaped differently.

Flutter's own guidance (`docs.flutter.dev/ui/adaptive-responsive/capabilities`, Flutter 3.47 docs, page updated
2026-05-05, read 2026-10-19) says: *"Avoid using `Platform.isAndroid` and similar functions to make layout decisions or
assumptions about what a device can do. Instead, describe what you want to branch on in a method."* It separates *"A
capability defines what the code can do"* from *"A policy defines what the code should do"*, because *"making a logical
distinction between what apps can do and what they should do helps larger products respond to changes in what platforms
can do or require"*, and recommends *"Test the branching code by mocking capabilities and policies"*.

## Decision

1. **Two classes in `lib/core/platform/`**:
   - `PlatformCapabilities` -- what the code CAN do on this host: an API or plugin exists, an OS rule, a mechanism
     (background scheduling, sign-in flow, file system layout).
   - `PlatformPolicy` -- what the app SHOULD do on this host: design preferences (flat Fluent-style surfaces on
     Windows), controls a platform's users expect (an Exit button on the desktop), store rules.
2. **One detection point.** `HostPlatform detectHostPlatform()` in `lib/core/platform/host_platform.dart` is the ONLY
   place in `lib/` that reads `Platform.isX`. Both classes are built from a `HostPlatform` value.
3. **Names say what is branched on, never the device.** `hasSystemTray`, `backgroundScanMechanism`,
   `googleSignInFlow`, not `isWindows`. A getter's doc comment states its answer on Windows, Android and iOS (iOS
   "unknown until ADR-0050" where research has not settled it).
4. **One test seam.** `PlatformCapabilities.current` and `PlatformPolicy.current` return the detected instance unless a
   test sets `debugOverride` (a fixed host, or a subclass that answers one getter differently). The four ad hoc seams
   above are replaced by it.
5. **Enforced.** `test/policy/platform_check_seam_test.dart` fails on any `Platform.isX` in `lib/` outside
   `lib/core/platform/`, ignoring comments. `Platform.operatingSystem` in log text and `Platform.pathSeparator` are not
   platform DECISIONS and stay allowed.
6. **Amends ADR-0042.** A declared platform exception is now a capability or policy getter plus a test of each answer.
   The ADR-0042 exception list points at the getter.

## Site mapping (all 62 code checks, 2026-10-19)

Behavior is unchanged on Windows and Android for every site. "C" = capability, "P" = policy.

- `main.dart:146` sqflite FFI init on desktop -- C `usesFfiSqlite` (Windows true, Android false, iOS false).
- `main.dart:215` dev data seeding -- C `canBeMsixPackaged` (Windows true; it also governs the packaged desktop data layout) AND the existing dev check.
- `main.dart:222` app identity migration; `app_identity_migration.dart:58` -- same getter.
- `main.dart:302` WorkManager dispatcher registration; `main.dart:321` Task Scheduler handoff drain;
  `background_scan_scheduler.dart:145-146` scheduler adapter choice; `main.dart:473` "can schedule" --
  C `backgroundScanMechanism` (`taskScheduler` / `workManager` / `none`). `main.dart:473` keeps its
  `kReleaseMode` condition for Task Scheduler.
- `main.dart:450`, `main.dart:486` new-mail trigger -- C `hasNewMailNotificationTrigger` (Android true; Windows false,
  declared exception F253 / ADR-0044).
- `main.dart:545` desktop keyboard shortcuts; `main.dart:759` programmatic quit -- C `hasDesktopWindow`.
- `main.dart:721` scans interrupted when the app is backgrounded -- C `socketsCloseWhenBackgrounded` (Android true,
  Windows false; ADR-0042 Sprint 70 exception). `failScanInterruptedByBackgrounding` reads it itself (no bool parameter).
- `settings_screen.dart:109` (`showsAndroidBackgroundRows`, removed): its three uses became `hasNewMailNotificationTrigger`
  (new-mail row), `hasBatteryOptimizationSetting` (Doze timing note) and `hasNativeGoogleSignIn` (certificate pinning
  subtitle).
- `windows_system_tray_service.dart:31` -- C `hasSystemTray`.
- `windows_task_scheduler_service.dart:320,375,427` -- C `backgroundScanMechanism == taskScheduler`.
- `app_environment.dart:81` MSIX install detection -- C `canBeMsixPackaged`.
- `email_scanner.dart:394` platform name in a record -- `PlatformCapabilities.current.hostName` (`android` /
  `windows`), unchanged values.
- `export_directories.dart:81,93,128,230` -- C `exportLocation` (Windows Documents folder; Android shared storage
  through the document URI).
- `scan_complete_notifier.dart:60` -- C `notificationDelivery` (`androidChannel` / `windowsToast` / `undecided`; shared
  plugin, Android channel setup).
- `google_auth_service.dart:184` -- C `googleSignInFlow` (`nativeWithBrowserFallback` Android, `native` iOS,
  `browserLoopback` desktop); `:187` same getter; `:220`, `:698` browser fallback after native failure -- same getter;
  `:282` stored refresh-token renewal -- C `renewsGmailWithStoredRefreshToken` (Android true).
- `gmail_api_adapter.dart:190` reuse stored access token -- C `reusesStoredGmailAccessToken` (Windows true);
  `:401` interactive scope upgrade -- C `canUpgradeGmailScopesInteractively` (Windows true).
- `gmail_windows_oauth_handler.dart:80,92` which client ID to log -- C `gmailOAuthClient` (`desktop` / `android` /
  `ios`); `:110` redirect type -- C `usesCustomSchemeOAuthRedirect` (Android, iOS).
- `gmail_oauth_screen.dart:90,167,497,536` -- `googleSignInFlow`.
- `yaml_import_export_screen.dart:429,479` save / pick through the system sheet -- C `usesSystemFileSheet`
  (Android, iOS); `:846`, `results_display_screen.dart:705`, `rules_management_screen.dart:1125`,
  `safe_senders_management_screen.dart:783` path separator for display -- C `pathSeparator`.
- `settings_screen.dart:1708` Battery > Unrestricted row beside the background switch -- C
  `hasBatteryOptimizationSetting` (Android).
- `settings_screen.dart:1813` notification permission request -- C `requestsNotificationPermissionAtRuntime`
  (Android, iOS).
- `settings_screen.dart:1828,1849` test-background-scan and scheduler calls -- `backgroundScanMechanism`.
- `app_theme.dart` (10) -- P `prefersFlatSurfaces` (Windows true: Fluent-style flat cards, smaller radii).
- `app_bar_with_exit.dart:35` -- P `showsExitButton` (Windows true; an Android app is not exited by the user).
- `system_inset_wrapper.dart:100` -- C `drawsUnderSystemBars` (Android true; edge-to-edge).

The migration may split or rename a getter when a site turns out to branch on something else; the table above is then
updated in the same commit. Sprint 80 notes: `google_auth_service.dart` `_isDesktop` is `googleSignInFlow ==
browserLoopback` (the same answer on Windows, Android and iOS; macOS and Linux were also desktop before), and the
Windows OAuth log branch is `gmailOAuthClient == desktop`. The pure helpers `shouldTryStoredRefreshToken`
(`renewsWithStoredRefreshToken`) and `certificatePinningSubtitle` (`usesNativeSignIn`) take the capability as a
parameter instead of `isAndroid`.

## Consequences

- Adding iOS is one `HostPlatform` value plus one answer per getter (ADR-0050 fills them), and the policy test stops a
  new scattered check.
- Every platform difference is listed in two files, with its reason in its name and doc comment.
- Tests can run any branch on the Windows host through one override; the four ad hoc seams go away.
- Cost: one indirection at each site. The getters are plain `bool` / enum reads, so there is no runtime cost worth
  measuring.

## Alternatives considered

- **Keep the bare checks** (status quo): fails the iOS goal and the ADR-0042 "declared exception" rule.
- **One class only**: rejected; Flutter's guidance separates capability from policy, and so do this app's sites (the
  theme and the Exit button are choices, not limits).
- **`defaultTargetPlatform` instead of `dart:io` `Platform`**: overridable in widget tests, but it describes the
  target's look, not what the host can do, and it does not help non-widget code (scheduler, auth). Not used.
