# F345: iOS Simulator job, test audit, privacy manifest (Sprint 84, Task 8)

Status: prepared locally on 2026-11-06. CI results (run ids, pass counts, artifact link) are filled in by the main
session after each `gh workflow run ios.yml --ref feature/20261105_Sprint_84`. Every cell marked "pending CI" is
UNVERIFIED until a run fills it.

## 1. The job

`ios-simulator` in `.github/workflows/ios.yml`, runner `macos-26`. It starts on the same triggers as `ios-build`
(a push that changes `mobile-app/ios/**` or the workflow file, and `workflow_dispatch`).

From run 3 the work is split into two jobs that run in parallel on two macOS runners (GitHub allows 5 concurrent macOS
jobs on every plan: https://docs.github.com/en/actions/reference/limits, read 2026-11-06; each job is limited to 6
hours, the job sets 75 minutes):
- `ios-simulator` (the verdict): checkout, Flutter (`.fvmrc`), `pub get`, pick an iPhone and an iPad Simulator on the
  newest iOS runtime, boot the iPhone, `flutter build ios --simulator --debug` (no signing, no secret, Google client IDs
  empty), check the privacy manifest is in the built `.app`, run the integration tests (one `flutter test` process per
  file) on the iPhone, upload the logs.
- `ios-simulator-screens`: same setup, boot both Simulators, capture the first-run screens on both sizes, diagnostic
  re-run of the two excluded files with unknown cause (outside the verdict), upload screens and logs. The separate iPad
  smoke run of runs 1-2 was dropped (8.8 min); the iPad leg is the screens test, which seeds the same temp-DB harness
  and renders five screens at iPad size.

Why the split (run 2, id 42252630431, measured from the job log, one job): checkout and Flutter 1.0 min; boot of both
Simulators 11.5 min; explicit simulator build 17.1 min (Xcode build 826.7 s); integration tests for five files 25.0
min (first file 9.4 min, later files 3.4 to 4.9 min each, because every `flutter test <file>` runs its own Xcode
build); iPad smoke 8.8 min; screens 9.8 min before the 75-minute limit cancelled the job. The files cannot share one
build: each test file is its own app entry point. Estimate for run 3: ios-simulator about 1 + 6 + 17 + 9.4 + 5 x 4.8 =
57 min; ios-simulator-screens about 1 + 11.5 + 2 x 9 + 2 x 5 + 1 = 42 min. Option if still too slow: drop the explicit
build step from ios-simulator (17 min) and take the manifest from the first test build.

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
not touch the database). `bootAppWithDevDbCopy` (which reads `%APPDATA%`, Windows only) is used by no test. The
harness uses `sqflite_common_ffi` (sqlite3 3.1.4 native assets); CI run 1 proved it loads and runs on iOS (the smoke
test, which seeds 1824 rules and 426 safe senders, passed).

CI run 1 (id 42236034252, commit 1bdc8018, iPhone 17, iOS 26.5): 4 of 9 files passed (smoke, help_deep_link,
sprint52, visual_layout), 5 failed (folder_picker, read_only_flows, rule_lifecycle, safe_sender_lifecycle, sprint62). The job's pass counter was wrong in run 1 (it read the
progress marker `+N`, which the GitHub reporter does not print as the final number); fixed to read "N tests passed".

CI run 2 (id 42252630431, commit 36656495): gate green for the five files it ran (smoke 1, help_deep_link 32,
rule_lifecycle 1, sprint52 2, visual_layout 2 = 38 passed tests; counter fixed), with folder_picker, read_only_flows,
safe_sender_lifecycle and sprint62 excluded. The privacy manifest step passed. The job was then cancelled by its
75-minute limit (see section 1).

CI run 3 (id 42268050125, commit 145d56a3, GREEN): `ios-simulator` 33 min, success; `ios-simulator-screens` 69 min, success
(close to the 75-minute limit; the diagnostic step that ran there in run 3 now lives in `ios-simulator`, which has the
room, to give the screens job about 10 minutes more margin); `ios-build` and the Build Verification job success;
TestFlight job skipped. Passed tests per file from the downloaded logs: app_boot_smoke 1, help_deep_link 32,
read_only_flows 6, rule_lifecycle 1, sprint52 2, visual_layout 2 = 44 passed tests in 6 files. Diagnostic re-run (outside
the verdict, with `ConnectHardwareKeyboard` set before boot): folder_picker 0 passed 1 failed at the same line 64;
safe_sender_lifecycle 0 passed 1 failed, still `Bad state: No element` from scrollUntilVisible (now line 65 after the
provider wrap). The keyboard preference did not fix either, so the on-screen keyboard hypothesis is NOT confirmed (the
preference may not apply to a headless boot). `integration_test/ios_diagnostic_probe_test.dart` (new, asserts nothing,
skips unless `IOS_PROBE=1`) prints view insets, widget counts and controller text at each step; run 4 shows the cause.

R-2 table (ran / did not run, with the reason; counts are from run 3 unless noted):
- app_boot_smoke_test.dart: RAN, PASSED (1 test), run 3 and run 2. AC-1 file.
- help_deep_link_test.dart: RAN, PASSED (32 tests).
- sprint52_surfaces_test.dart: RAN, passed (one case skipped by the test itself on non-Windows,
  `skip: !Platform.isWindows`).
- visual_layout_test.dart: RAN, PASSED (2 tests).
- rule_lifecycle_test.dart: RAN, now PASSED (1 test, runs 2 and 3). FAILED in run 1 for a reason that is NOT iOS: `ManualRuleCreateScreen._saveRule` calls
  `Provider.of<RuleSetProvider>` (`manual_rule_create_screen.dart:266`, added by commit 32059a86, Sprint 83 F298, PR #490,
  2026-10-23) and the test pumped the screen without a provider, so Save threw `ProviderNotFoundException`
  ("The following ProviderNotFoundException was thrown running a test"; the later `inTest` assertion is a consequence).
  The same code runs on Windows, so the test failed there too since that commit (by code reading; a local Windows run
  was started and abandoned because it builds the Windows app). Fix in this round: the test wraps the screen in
  `ChangeNotifierProvider<RuleSetProvider>`. Not excluded.
- safe_sender_lifecycle_test.dart: RAN, FAILED in run 1. It has the same missing provider (fixed the same way), but it
  failed EARLIER, at `scrollUntilVisible` for the Save button (`Bad state: No element`, after 50 drags the keyed button
  was never built). Cause NOT established. EXCLUDED from the verdict for now and re-run in the diagnostic step.
- folder_picker_test.dart: RAN, FAILED in run 1 at the last assertion (`Church` not found after clearing the search,
  line 64). A headless probe with `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` passes, so Dart-level
  iOS behavior is not the cause. Cause NOT established. Hypothesis, UNVERIFIED: the on-screen keyboard that a real
  iOS text field raises leaves the list almost no height. EXCLUDED from the verdict for now; diagnostic re-run.
- read_only_flows_test.dart: RAN in run 1, 5 passed, 1 FAILED: `F25: Rule Test tool runs a plaintext pattern`, "A
  RenderFlex overflowed by 27 pixels on the bottom" at `lib/ui/screens/rule_test_screen.dart:523`, constraints
  `0<=h<=63`. A real layout defect at a phone viewport, found by the Simulator. Fixed by commit c9130577 (the four
  Center > Padding > Column empty states became Center > SingleChildScrollView, with a phone-size widget test). Back in
  the gate from run 3: RAN, PASSED (6 of 6 tests), verified in the run 3 log.
- sprint62_surfaces_test.dart: RAN, 1 passed, 3 FAILED. EXCLUDED from the verdict. Cases, by test name:
  1. `F175: a FRESH in_progress background scan raises the wait dialog; Cancel starts nothing` (line 121): FAILS at
     `expect(find.text('Background scan in progress'), findsOneWidget)` (line 138), 0 widgets. Two stale reasons, both from
     code reading, not from a run on Windows: (a) the dialog is now titled `A scan is already running`
     (`scan_progress_screen.dart` `showScanAlreadyRunningDialog`, around line 837) and offers `OK` and the action
     `stopBackgroundScanActionLabel`, not `Cancel` and `Wait and start`; (b) the check became per ACCOUNT in Sprint 74
     (`scanResultStore.getActiveScanForAccount(accountId)`, call site comment "Harold Q4"), while the test seeds the
     background row under `bg-holder@example.com` and starts the scan as `demo-it@example.com`, so no row matches.
  2. `F175: Wait-and-start proceeds -- the scan actually runs after the dialog` (line 150): taps the removed `Wait and
     start` button; the following `processedCount > 0` check (line 177) then fails. Same two reasons.
  3. `F175 negative: a STALE in_progress row ... must NOT raise the dialog` (line 182): PASSED. It passes for a weak
     reason, because no dialog is raised for the other account either; it would not catch the stale-row rule.
  4. `F178 + F176: at compact width with a bottom inset, the popup is bottom-anchored in the safe area with Block
     Subject reachable; the summary carries the account email label` (line 214): FAILS at line 271,
     `expect(find.text('aol-user@aol.com'), findsWidgets)`, 0 widgets, message "AccountEmailLabel must render the
     account email". Cause NOT established: it may be stale, or it may be iOS-specific (the test overrides
     `tester.view.physicalSize` and `padding`, which a real-device binding may ignore). A card should first run it on
     Windows to tell the two apart.
  Needed for a card: update cases 1 and 2 to the Sprint 74/75 behavior (same account for the seeded row and the scan; the
  `A scan is already running` title; `OK`; the stop-background action), fix case 3 so it can fail, and settle case 4.

Not one of the nine: `ios_first_run_screens_test.dart` (new, F345 R-3). It skips itself unless `SCREENSHOT_DIR` is
passed, so on Windows it is one skipped file in `run-integration-tests.ps1`.

## 3. R-3 screens

`ios_first_run_screens_test.dart` pumps five screens inside a `RepaintBoundary` and writes a PNG for each:
1 empty state (`AccountSelectionScreen`, no accounts), 2 Add Account provider choice (`PlatformSelectionScreen`),
3 Add Account AOL form (`AccountSetupScreen`), 4 Settings, 5 Help. Names are `iphone-N-name.png` and `ipad-N-name.png`.
The screens are pumped directly, not reached by taps, because `xcrun simctl` cannot tap. They show the same widgets
as the real routes but not the transition into them. Where the PNG goes: a Simulator app is a process on the Mac, so a
File write to an absolute Mac path reaches the runner disk (verified in run 2). The test fails when a
file is not written, and the job adds a whole-screen `xcrun simctl io screenshot` per device as a second source.

Run 2 (id 42252630431): the iPhone leg wrote all five PNG files to the Mac path and the artifact holds them
(`iphone-1-empty-state.png` through `iphone-5-help.png`), so the host-path write works (verified, no longer
UNVERIFIED). `iphone-1-empty-state.png` was opened: it shows the Select Account screen with "No Accounts Yet", the
Add Account and "Try Demo Mode instead" actions, version "V0.24.1 [DEV]". The whole-screen `xcrun simctl io screenshot`
fallback captured only the Simulator home screen (the test app had exited), so it adds nothing and was removed in run
3. The iPad leg did not finish in run 2 (job timeout), so there are no iPad screens yet.

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
  Flutter engine (Flutter.framework) ships its own manifest (verified in the run 2 bundle listing below).

AC-4 evidence (run 2, step "Check the privacy manifest is in the built app"): `build/ios/iphonesimulator/Runner.app/PrivacyInfo.xcprivacy:
OK` (plutil -lint), and `plutil -p` printed the file: tracking false, no domains, no collected data, FileTimestamp
`C617.1`. The same step listed 28 manifests in the bundle, so the earlier UNVERIFIED point is settled:
`Frameworks/Flutter.framework/PrivacyInfo.xcprivacy` exists (the engine ships its own), as do bundles for app_links,
file_picker, flutter_appauth, flutter_local_notifications, flutter_secure_storage_darwin, google_sign_in_ios,
package_info_plus, path_provider_foundation, sqflite_darwin, and the native SDKs AppAuth, GoogleSignIn,
GoogleUtilities, GTMAppAuth, GTMSessionFetcher, MSAL, Promises, Reachability (connectivity_plus), SDWebImage, SwiftyGif
and TOCropViewController. battery_plus has no bundle in that list, consistent with the grep result above.

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

Prepared 2026-11-06 after run 3. One run shows it: the verdict job `ios-simulator` turns red in about 33 minutes. The
`ios-simulator-screens` job is not part of the proof and can be cancelled once `ios-simulator` has finished.

Ready-to-apply mutation, done by the main session on the feature branch and reverted in the next commit:
in `mobile-app/integration_test/app_boot_smoke_test.dart`, change `expect(find.text('harness ready'), findsOneWidget);`
to `expect(find.text('harness ready'), findsNothing);`. Expected: the step "Run the integration tests on the iPhone
Simulator" prints `app_boot_smoke_test.dart: FAILED (exit 1), 0 passed`, the job is red. Second mutation for the
zero-tests rule: set `EXCLUDED_TESTS` to all nine file names in the workflow env. Expected: the step fails with
"zero integration tests ran on the Simulator". Record both run ids here, then revert both edits.

## 6.1 R-3 screens, run 3 artifact

Artifact `ios-simulator-screens-and-logs`, ten PNG files (iPhone 17 and iPad (A16), iOS 26.5): `iphone-` and `ipad-` with
1-empty-state, 2-add-account, 3-add-account-aol-form, 4-settings, 5-help (sizes 70 KB to 550 KB, none empty). Opened:
`iphone-1-empty-state.png` and `ipad-4-settings.png`. Observations for Task 4 (read from the images, not from code):
- iPad Settings, General tab, shows "Export folder: Documents/MyEmailSpamFilter_Dev (default)" and the Content history
  text "in a file on this computer"; "this computer" is desktop wording on a phone or tablet. The folder shown is
  the dev default. ADR-0050 says the export folder is the app's Documents folder shown in the Files app, which is
  UNVERIFIED on a device.
- The iPad layout is the phone layout stretched: full-width buttons and a 90-day text box at tablet width.
- The screens are the Simulator's debug build ("[DEV]" and version 0.24.1 are shown).

## 7. Parity (ADR-0042 / ADR-0049 / ADR-0050)

The Simulator job is the iOS leg of the shared integration tests; Windows runs them through
`run-integration-tests.ps1`, Android has no integration test job (recorded, out of scope). The privacy manifest is
iOS-only by Apple requirement; Android's equivalent is the Play Data safety form (GP-10), Windows has none: a declared
exception.
