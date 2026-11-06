# F345: iOS Simulator job, test audit, privacy manifest (Sprint 84, Task 8)

Status: prepared locally on 2026-11-06. CI results (run ids, pass counts, artifact link) are filled in by the main
session after each `gh workflow run ios.yml --ref feature/20261105_Sprint_84`. Every cell marked "pending CI" is
UNVERIFIED until a run fills it.

## 1. The job

`ios-simulator` in `.github/workflows/ios.yml`, runner `macos-26`. It starts on the same triggers as `ios-build`
(a push that changes `mobile-app/ios/**` or the workflow file, and `workflow_dispatch`).

Steps: checkout, Flutter (`.fvmrc`), `pub get`, pick an iPhone and an iPad Simulator on the newest iOS runtime, boot
both, `flutter build ios --simulator --debug` (no signing, no secret, Google client IDs empty), check the privacy
manifest is in the built `.app`, run the integration tests (one `flutter test` process per file), run the smoke test
on the iPad, capture the first-run screens on both sizes, upload screens and logs.

Shared steps: the checkout, Flutter and `pub get` steps are copied from `ios-build`, not shared. A composite action or
YAML anchor would mean editing `ios-build` and `ios-testflight`, which cannot be tested on this Windows machine and
which the card says must not change. The Flutter action SHA is the same in all three jobs.

R-6 (never green on nothing). The job fails when: a test file exits non-zero; a file exits zero with zero tests run;
the total passed is zero; fewer than five screens per device size are written; the manifest is not in the bundle.

Vendor facts used (read 2026-11-06):
- Runner image macos-26 (arm64), image 20261026.0455.2: default Xcode 26.6; iOS 26.5 Simulators include "iPhone 17",
  "iPhone 17 Pro", "iPad (A16)", "iPad Pro 11-inch (M5)".
  Source: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md
  The job reads the device list from `xcrun simctl` at run time, so an image update does not break it.
- Cost. GitHub's billing page: "The use of standard GitHub-hosted runners is free: ... In public repositories."
  It also says macOS runners "cost more to run" than Linux (macOS 3-core or 4-core: $0.062 per minute) and
  "Larger runners are not free for public repositories".
  Sources: https://docs.github.com/en/billing/concepts/product-billing/github-actions and
  https://docs.github.com/en/billing/reference/actions-minute-multipliers
  Whether the label `macos-26` is a standard (free) runner and not a larger runner: UNVERIFIED on those pages. The
  existing `ios-build` job already runs on `macos-26` in this public repository; the GitHub billing usage page for the
  account settles it. Harold can check it there.

## 2. R-2 audit: the nine integration test files

Reading the files (2026-11-06): none needs a real account, a network sign-in or a secret. Eight of nine boot the
isolated temp database through `bootDbOnly` (`folder_picker_test.dart` pumps a screen with injected folders and does
not touch the database). `bootAppWithDevDbCopy` (which reads `%APPDATA%`, Windows only) is used by no test. The harness
uses `sqflite_common_ffi` (sqlite3 3.1.4 native assets), so whether that loads on iOS is the main open question.
The `EXCLUDED_TESTS` list in the job is empty at the start; a file is added to it, with a reason, only after a run
shows it cannot run on iOS. A test that cannot run is not edited to pass.

- app_boot_smoke_test.dart: expected to run. Seeds the temp DB, pumps a widget. AC-1 file. Result: pending CI.
- folder_picker_test.dart: expected to run. Injected folders, no account. Result: pending CI.
- help_deep_link_test.dart: expected to run. HelpScreen with the harness. Result: pending CI.
- read_only_flows_test.dart: expected to run. Pumps Manage Rules, Settings, Scan History, Help, Rule Test, Rule Edit
  against the seeded DB. Result: pending CI.
- rule_lifecycle_test.dart: expected to run. Creates and deletes a rule in the temp DB. Result: pending CI.
- safe_sender_lifecycle_test.dart: expected to run. Same, for safe senders. Result: pending CI.
- sprint52_surfaces_test.dart: expected to run, with one case skipped by the test itself on non-Windows
  (`skip: !Platform.isWindows`, the No-Rule review action is Windows scoped). Result: pending CI.
- sprint62_surfaces_test.dart: expected to run. Sets a 500 x 731 view size, which works on any platform. Result:
  pending CI.
- visual_layout_test.dart: expected to run. Relational layout assertions, viewport independent. Result: pending CI.

Not one of the nine: `ios_first_run_screens_test.dart` (new, F345 R-3). It skips itself unless `SCREENSHOT_DIR` is
passed, so on Windows it is one skipped file in `run-integration-tests.ps1`.

## 3. R-3 screens

`ios_first_run_screens_test.dart` pumps five screens inside a `RepaintBoundary` and writes a PNG for each:
1 empty state (`AccountSelectionScreen`, no accounts), 2 Add Account provider choice (`PlatformSelectionScreen`),
3 Add Account AOL form (`AccountSetupScreen`), 4 Settings, 5 Help. Names are `iphone-N-name.png` and `ipad-N-name.png`.
The screens are pumped directly, not reached by taps, because `xcrun simctl` cannot tap. They show the same widgets
as the real routes but not the transition into them. Where the PNG goes: a Simulator app is a process on the Mac, so a
File write to an absolute Mac path should reach the runner disk (UNVERIFIED until the first run). The test fails when a
file is not written, and the job adds a whole-screen `xcrun simctl io screenshot` per device as a second source.

## 4. R-4 privacy manifest

Apple sources, read 2026-11-06 (the pages are rendered by script, so the text was read from Apple's documentation data
files at `developer.apple.com/tutorials/data/documentation/bundleresources/...`, the same content):
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype

Apple: "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file
aren't accepted by App Store Connect." Apple: "Your third-party SDK can't rely on the privacy manifest files for apps that
link the third-party SDK ... to report your third-party SDK's use of required reasons API." So each SDK reports itself,
and the app reports its own code.

`mobile-app/ios/Runner/PrivacyInfo.xcprivacy` declares:
- `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty, `NSPrivacyCollectedDataTypes` empty (ADR-0030: no
  backend; mail travels only between the device and the user's own mail provider. The App Store Connect "App Privacy"
  answers are a separate submission task).
- `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1`. Apple: "Declare this reason to access the
  timestamps, size, or other metadata of files inside the app container, app group container, or the app's CloudKit
  container." The app's Dart code reads such timestamps: `lib/adapters/storage/local_rule_store.dart:206`
  (`statSync().modified` on backup files) and `lib/core/services/diagnostic_logger.dart:347` (`lockFile.lastModified()`).
  Whether Flutter's own framework manifest already covers the Dart runtime is checked by the job (it lists every
  manifest in the bundle); the app entry stays because the app's own code does this and it is accurate.

Categories NOT declared, and why: UserDefaults (no `UserDefaults` or `shared_preferences` use in `ios/Runner/*.swift`
or `lib/`; settings are in SQLite), system boot time, disk space, active keyboards (none in the Runner sources; grep on
2026-11-06). Reason codes for the categories, from Apple: FileTimestamp C617.1 / 3B52.1 / DDA9.1 / 0A2A.1;
SystemBootTime 35F9.1 / 8FFB.1 / 3D61.1; DiskSpace 85F4.1 / E174.1 / 7D9E.1 / B728.1; ActiveKeyboards 3EC4.1 / 54BD.1;
UserDefaults CA92.1 / 1C8F.1 / C56D.1 / AC6B.1.

Plugins at the versions in `pubspec.lock`, checked in the local pub cache (file path inside each package):
- Ship their own `PrivacyInfo.xcprivacy` (not repeated in the Runner file): app_links 6.4.1, file_picker 8.3.7,
  flutter_appauth 12.0.2, flutter_local_notifications 22.3.2, flutter_secure_storage_darwin 0.3.2,
  google_sign_in_ios 6.2.4, msal_auth 3.3.0, package_info_plus 9.0.1, path_provider_foundation 2.5.1,
  sqflite_darwin 2.4.2, url_launcher_ios 6.3.6, webview_flutter_wkwebview 3.23.5, workmanager_apple 0.9.11.
- Ship none: battery_plus 5.0.3 and connectivity_plus 5.0.2. Their `ios/Classes` sources contain no `UserDefaults`,
  `stat(`, `systemUptime`, `mach_absolute_time`, `volumeAvailable` or `activeInputModes` (grep, 2026-11-06). The
  Flutter engine (Flutter.framework) ships its own manifest in current Flutter; UNVERIFIED here, the job lists it.

Project membership: `project.pbxproj` gains a `PBXFileReference` (F345A0010000000000000001), a `PBXBuildFile`
(F345A0020000000000000002), a Runner group entry and a Runner "Resources" phase entry. Both IDs were checked absent
before the edit. AC-4 proof: the job step "Check the privacy manifest is in the built app" fails unless
`Runner.app/PrivacyInfo.xcprivacy` exists, then runs `plutil -lint` and prints it.

## 5. R-5: what the Simulator does NOT prove

- Gmail sign-in. The Simulator build has empty Google client IDs and no network sign-in is run. Google sign-in on a
  real device (the iOS client type, the URL scheme, the native SDK) is proven only by a TestFlight build.
- The notification permission prompt. The Simulator can show it, but no test taps it, and a Simulator does not
  deliver real notifications the way a device does.
- Real background scheduling. `BGAppRefreshTask` runs at times the system picks on a device; the Simulator does not
  run the system scheduler (ADR-0050 Exception 1). No background scan is exercised.
- Real-device performance (CPU, memory, battery, SQLite speed on flash storage). The runner is a Mac VM running an
  Apple-silicon Simulator process.
- The signed build: entitlements, provisioning, Keychain access groups and App Store processing.
- The Files-app export folder (UNVERIFIED in ADR-0050) and the system export sheet.
- Screens reached by tapping: the first-run screens are pumped directly.

## 6. AC-5 failing-path proof (apply in a later CI round, then revert)

Ready-to-apply mutation, done by the main session on the feature branch and reverted in the next commit:
in `mobile-app/integration_test/app_boot_smoke_test.dart`, change `expect(find.text('harness ready'), findsOneWidget);`
to `expect(find.text('harness ready'), findsNothing);`. Expected: the step "Run the integration tests on the iPhone
Simulator" prints `app_boot_smoke_test.dart: FAILED (exit 1), 0 passed`, the job is red. Second mutation for the
zero-tests rule: set `EXCLUDED_TESTS` to all nine file names in the workflow env. Expected: the step fails with
"zero integration tests ran on the Simulator". Record both run ids here, then revert both edits.

## 7. Parity (ADR-0042 / ADR-0049 / ADR-0050)

The Simulator job is the iOS leg of the shared integration tests; Windows runs them through
`run-integration-tests.ps1`, Android has no integration test job (recorded, out of scope). The privacy manifest is
iOS-only by Apple requirement; Android's equivalent is the Play Data safety form (GP-10), Windows has none: a declared
exception.
