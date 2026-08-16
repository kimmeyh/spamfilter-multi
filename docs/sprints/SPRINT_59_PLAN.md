# Sprint 59 Plan

**Branch**: `feature/20260815_Sprint_59`
**Dates**: 2026-08-15 --
**Scope defined by Harold** (2026-08-15): F150 (Android build blocker -- FIRST, interactive), F153 (WinWright/UIA re-test), plus two new items registered this refinement: F155 (rename Review "No Rule" Items -> Review No Rule Items) and F154 (Help section for the Review No Rule Items screen). Task order: F150 -> F153 -> F155 -> F154 (rename BEFORE the new help content so the content is written under the final name).

**In-flight (not a task)**: Store Submission 15 (0.8.0.0) is in certification; post-cert close-out (Check C, STORE_VERSION_STATUS, CHANGELOG [0.8.0] heading, next dev bump) happens when Harold confirms certification, independent of these tasks.

---

## Task 1 -- F150: Android debug builds fail outright -- google-services.json/applicationId mismatch (Priority 10, Issue #315) (FIRST -- interactive with Harold)

**Value**: This unblocks ALL Android work (every debug/release build fails unconditionally at `:app:processDebugGoogleServices`), which in turn unblocks F143/F144 and the Google Play track.

**Requirements** (numbered, detailed):
- R-1: Firebase Console -- register the app's real `applicationId` (`com.myemailspamfilter`) as an Android app in the existing Firebase project. **Harold-driven** (console access is Harold-only); Claude guides the steps and consumes the output. SHA-1 fingerprint registration (via `mobile-app/android/get_sha1.bat`) is required for Google Sign-In to work but is NOT required just to make the build pass -- do both while in the console.
- R-2: Download the fresh `google-services.json` containing the `com.myemailspamfilter` client and place it at `mobile-app/android/app/google-services.json` (replacing the stale `com.example.spamfiltermobile` one). This file is gitignored -- verify it stays untracked.
- R-3: Verify the fix with a REAL build: `build-with-secrets.ps1 -BuildType debug -InstallToEmulator` completes past `:app:processDebugGoogleServices` and installs to the emulator (Android Studio emulator, the designated environment per the 2026-08-12 tooling decision).
- R-4: Scope guard: this is the BASELINE fix only (one working `google-services.json` for the current un-flavored applicationId). The `.dev`/`.prod` flavor variants remain F94 (HOLD) -- do not expand into flavor work.

**Affected components / files**: `mobile-app/android/app/google-services.json` (replaced, gitignored); no source changes expected.

**Dependencies / blockers**: Harold's Firebase Console access -- this is why the task runs FIRST while Harold is available for the walkthrough/questions.

**Acceptance criteria**:
- AC-1: `build-with-secrets.ps1 -BuildType debug` completes with no `No matching client found for package name 'com.myemailspamfilter'` error.
- AC-2: The debug APK installs and launches on the emulator (F142's deferred T-3 manual check becomes possible -- run it opportunistically: confirm the app opens to the shared default-screen decision).
- AC-3: `google-services.json` remains untracked (`git status` clean of it).

**Tests to write**: None (external-config fix; the build itself is the test). Record the F142 T-3 opportunistic result in completion notes.

**Definition of Done**: default task-level DoD (items 2/5 partially N/A -- no code, no CHANGELOG user-facing entry unless behavior changes; log actuals) PLUS: completion notes record what was registered in Firebase and the build/launch evidence.

**Model**: Sonnet -- *why not Haiku*: interactive external-system walkthrough with live diagnosis if the console output does not match expectations.

**Executed-by**: Fable 5 (session model; interactive walkthrough with Harold driving the console)
**Step-types**: DATA (external config), DOCS
**Est-Effort**: 30-60m (interactive; depends on console round-trips) -- **Actual: ~45m including the masked second blocker**

**COMPLETION NOTES (2026-08-15)**:
- R-1: Harold registered `com.myemailspamfilter` in Firebase project spamfilter-multi via screenshot-guided steps. One round-trip miss caught live: browser autofill silently substituted the OLD package into the registration form; the wrong entry was verified via Project settings (packages are immutable), removed (30-day-delete flow, all-checkbox acknowledgment), and re-registered correctly with the name typed by hand. Interesting artifact: the ORIGINAL stale Firebase entry is `com.example.spamfilter_mobile` (underscore) while the local stale json carried `com.example.spamfiltermobile` -- two different stale identities, which is why the autofilled duplicate was not rejected. SHA-1 field no longer exists on the registration form in the current console; fingerprint ADDED same-day (2026-08-15, Harold via 'Add fingerprint' on the app card, verified on-screen) and the refreshed google-services.json (with the web OAuth client entries) installed. The SHA-1-keyed type-1 android OAuth client materializes server-side; re-download the json at Android-track time if sign-in misbehaves.
- R-2: `google-services (2).json` (downloads redirect to D:\Data\Temp\Downloads) verified to contain the `com.myemailspamfilter` client, installed to `mobile-app/android/app/google-services.json`; old file backed up to session scratchpad; confirmed gitignored.
- R-3/AC-1: build passed `:app:processDebugGoogleServices` on the first post-fix run -- which UNMASKED a second, pre-existing blocker: `flutter_local_notifications` 16.3.3 fails to compile against Android SDK 34 (upstream `bigLargeIcon` ambiguity, famous issue, fixed upstream in 17.0.0). Bumped to ^17.0.0 (resolved 17.2.4) with a pubspec comment; our usage is initialize/show/AndroidNotificationDetails only -- v17's breaking changes are in scheduling APIs we do not call. Analyze clean; full suite re-run after the bump (result recorded below).
- AC-2: debug APK (173.7 MB) installed to the `pixel34_updated` emulator (launch quirks solved: that AVD belongs to the SECOND SDK at C:\Android\android-sdk -- its own emulator.exe must be used; the LOCALAPPDATA SDK's emulator cannot read its system image, and the old Nexus x86 AVD no longer boots under current WHPX. `netsimd.exe` crash dialog during boot is a known benign emulator sidecar failure.) App launched: `MainActivity` foreground, screenshot captured.
- F142 T-3 opportunistic check PASSED: fresh install (zero accounts) lands on Select Account per the shared `appDefaultScreenFor` decision; F151a's welcome/orientation empty state ("No Accounts Yet" + explanation + "Try Demo Mode instead") renders on Android.
- AC-3: `git check-ignore` confirms the config file untracked.
- R-4 scope guard held: no flavor work (F94 stays HOLD).
- Post-bump verification: `flutter analyze` clean; full suite **1,893 passed / 29 skipped / 0 failed**. (First full-suite run had a single failure in `default_rule_set_service_test.dart` 'pattern_type classification' -- passed 22/22 in isolation and green on the clean full re-run; unrelated to the plugin bump, looks like cross-shard ffi-DB interference. Flagged for the retro as a flake data point.)
- MV results (Harold, 2026-08-15): F154 help section working as expected; F155 rename + Sprint 58 search back-arrow working as expected. F156 registered (full Android app testing walk-through, errors expected). The unexplained build.gradle.kts minSdk un-pin was root-caused to Flutter's OWN gradle-file migrator ('Upgrading build.gradle.kts' in the first build log) -- reverted to the F108 pin; the migrator may re-apply it on future Android builds, so watch git status after any flutter build apk.
- Also delivered on request: the app icon added to the emulator home screen via `adb input draganddrop` (drawer -> home), screenshot-verified.

---

## Task 2 -- F153: Re-investigate Flutter Windows UIA/WinWright with the SPI_SETSCREENREADER flag (Priority 10)

**Value**: This determines whether F140's "Flutter exposes zero UIA patterns" finding (Sprint 54) was a real platform ceiling or an artifact of the missing screen-reader flag -- and corrects the documented limitations that other processes (F139's smoke-test recipe, WINWRIGHT_SELECTORS.md) currently inherit.

**Requirements** (numbered, detailed):
- R-1: Confirm `enable-screen-reader-flag.ps1 status` -> True at the start (it was left enabled 2026-08-15; re-enable if a reboot cleared it -- and RECORD whether it survived the reboot, since flag persistence across sessions is itself an open question).
- R-2: Re-run F140's original spike against a running dev build: `ww_dump_tree` with `includePatterns: true` -- do elements now expose real UIA control patterns (InvokePattern on Buttons, TogglePattern on CheckBoxes, ScrollPattern on containers)?
- R-3: Re-test scroll deliberately: `ww_scroll` in all 3 modes (direction, into_view, find_target) against the Help screen (long scroll) -- including the direction-inversion oddity observed in Sprint 58 (asked "up", content moved down). Characterize what reliably works.
- R-4: Re-test the specific F140 failure case: can automation now scroll to the Settings > General bottom-of-tab version text?
- R-5: Correct documentation to match findings: `docs/WINWRIGHT_SELECTORS.md` (prerequisite section promoted to a MUST-check pre-flight; F140 section updated), F139's "Known gap, STATUS UNCERTAIN" note in the master plan, and F153's own entry (resolved or re-scoped). If a sprint-process pre-flight step is warranted (check the flag before any WinWright work), add it to `SPRINT_PLANNING.md`'s Tooling-Capability Pre-Flight section.
- R-6: TIME-BOXED investigation -- if the flag does not explain everything, record the precise residual gaps and stop; upstream Flutter research (the original F153 scope) becomes a follow-up item, not an in-sprint expansion.

**Affected components / files**: docs only (`WINWRIGHT_SELECTORS.md`, `ALL_SPRINTS_MASTER_PLAN.md`, possibly `SPRINT_PLANNING.md`); no app code.

**Dependencies / blockers**: None. Needs a running dev build (build+launch is standard).

**Acceptance criteria**:
- AC-1: A definitive, evidence-backed statement of what WinWright CAN and CANNOT do against this app with the flag enabled (patterns, click, scroll, off-screen reach), replacing the confounded Sprint 54/58 record.
- AC-2: All three documentation sites (R-5) updated consistently with the findings.
- AC-3: Findings recorded in this plan's completion notes with the raw evidence (tree/pattern outputs summarized).

**Tests to write**: None (tooling investigation).

**Definition of Done**: default task-level DoD (test/CHANGELOG items N/A -- docs-only) PLUS: the three doc sites verified consistent in the same session.

**Model**: Sonnet -- *why not Haiku*: evidence interpretation against a confounded historical record, and a docs-consistency sweep.

**Executed-by**: Fable 5 (session model; ran inline rather than delegating -- the probe was interactive tool-driving with live evidence interpretation at each step)
**Step-types**: WINWRIGHT-DISCOVERY, DOCS
**Est-Effort**: 30-45m (time-boxed) -- **Actual: ~25m**

**COMPLETION NOTES (2026-08-15) -- F140 refuted; WinWright works. Raw evidence:**
- R-1: flag `True` at session start (persisted since the Sprint 58 same-day enablement; reboot-survival still unverified -- always run `status`).
- **New root-cause discovery**: Flutter builds its semantics tree LAZILY. First `ww_dump_tree` after app launch returned only the opaque `FLUTTERVIEW` pane (with the flag on); after ONE `ww_get_snapshot` (48 interactive elements, full labels/bounds), the SAME `ww_dump_tree` returned the full 66-element tree. This plus the missing flag fully explains F140's Sprint 54 empty-tree record.
- R-2: `ww_invoke` (pure InvokePattern) succeeded on Buttons (Help, Settings) -- "zero patterns" refuted. `ww_dump_tree includePatterns: true` still prints no pattern annotations: pattern REPORTING is incomplete while pattern INVOCATION works; test the verb, never the dump.
- R-3: `ww_scroll` direction mode works, direction semantics CORRECT (down = advance; Sprint 58's inversion did not reproduce). ~165px per call regardless of line/page; Help (~6000px) needs many calls; live element `bounds.y` via a selector dump is the position probe. into_view BROKEN two ways (handleId -> `PropertyNotSupportedException` on RuntimeId; selector -> `success, method:"none"` false success, screenshot-verified no movement). find_target = tree lookup (found, 0 steps, for content 4500px below the fold) -- existence only, not visibility.
- R-4: F140's failure case is moot AND closed: Settings > General version text now sits at the TOP of the tab (`Version 0.8.0 [DEV]` read directly via `name*="Version 0.8"`, on-screen) and the whole tab fits the default window (bottom element `Go to View Scan History` at y=827, on-screen). F139's version check can be automated.
- R-5: all three doc sites updated consistently -- `WINWRIGHT_SELECTORS.md` (Prerequisites promoted to MUST-check two-step pre-flight; F140 section superseded by a verified capability/gap list), master plan (F139 gap note closed; F153 entry marked RESOLVED), `SPRINT_PLANNING.md` (WinWright pre-flight added to Tooling-Capability Pre-Flight).
- R-6: no upstream Flutter research needed -- residual gaps are WinWright-tool-mode specifics (into_view/find_target), not engine ceilings. Bonus observations: F145 deep-link behavior visible via automation (Help opened from the No Rule screen landed on "Results"); F151i Markdown rendering confirmed live; selector syntax that works: `name="X"`, `name*="partial"`, `type="Pane"`.

---

## Task 3 -- F155: Rename "Review \"No Rule\" Items" -> "Review No Rule Items" app-wide, forward-looking (Priority 10, NEW this refinement)

**Value**: This removes the awkward nested-quotes name (the same collision class Copilot flagged in walkthrough Step 7) from every current surface -- icons/tooltips, screen title, help text, tests, and active process/backlog text -- so all future content (including Task 4's new help section) uses one clean name.

**Requirements** (numbered, detailed):
- R-1: Rename the user-visible string `Review "No Rule" Items` to `Review No Rule Items` in: the shared AppBar tooltip (`standard_app_bar_actions.dart`), the screen's own AppBar title (`no_rule_review_screen.dart`), and every other lib/ occurrence (planning grep: 13 occurrences across 10 files, including comments that state the live name).
- R-2: Update the 5 test files that assert the old string (including the F134 policy gate's `standardActionTooltips` list and the full-canonical-order test) -- the gates must ENFORCE the new name, not merely tolerate it.
- R-3: Update current-content occurrences: `assets/content/help/walkthrough.md` (Step 7 references). Verify with a final repo-wide grep that no lib/, test/, or assets/content/ occurrence of the old quoted form remains.
- R-4: FORWARD-LOOKING ONLY (Harold): do NOT touch historical records -- past sprint docs (`docs/sprints/SPRINT_1..58_*`), CHANGELOG history entries, closed issues, memory files describing past events. Master-plan text describing CURRENT/future work (e.g. F143's entry) IS current and gets the new name.
- R-5: Identifiers/enum/file names (`NoRuleReviewScreen`, `no_rule_review_screen.dart`, `includeNoRuleReview`, `HelpSection` values) are NOT renamed -- they contain no quotes and are not user-visible; renaming them is churn with no user value. Only display strings, tooltips, comments-stating-the-live-name, and current doc text change.

**Affected components / files**: 10 lib files (13 occurrences), 5 test files, `walkthrough.md`, current master-plan entries (F143 etc.).

**Dependencies / blockers**: None. Runs BEFORE Task 4 so the new help content is authored under the final name.

**Acceptance criteria**:
- AC-1: Repo-wide grep for `Review "No Rule" Items` returns zero hits in `lib/`, `test/`, `assets/content/`, and current master-plan/current-process text (historical sprint docs excluded).
- AC-2: The policy gate and appbar tests pass asserting the NEW string (mutation check: reintroducing the old tooltip string fails the gate).
- AC-3: Full suite green; `flutter analyze` clean.

**Tests to write**: T-1 -- update existing gates/tests to the new string (they ARE the regression net); mutation-verify the gate once.

**Definition of Done**: default task-level DoD PLUS: the final verification grep output recorded in completion notes.

**Model**: Haiku -- mechanical, fully-enumerated rename with existing gates as the net. *(Escalate only if a test reveals a hidden coupling.)*

**Executed-by**: Fable 5 (session model; executed inline -- the replacement was a single scripted pass, cheaper in wall-clock than delegating)
**Step-types**: UI-MOVE (strings), TEST-UNIT, CONTENT, DOCS
**Est-Effort**: 20-30m -- **Actual: ~8m**

**COMPLETION NOTES (2026-08-15)**: 31 replacements total -- 13 in 10 lib files, 15 in 6 test files (planning said 5; `integration_test/sprint52_surfaces_test.dart` was the 6th, found by the execution grep), 3 in `walkthrough.md` (including the secondary `update "No Rule" items` phrase, de-quoted for consistency; the `"No rule"` chip-label quotation kept -- it cites the chip's actual literal label). CHANGELOG historical entries and past sprint docs untouched per Harold. Master plan's only hit is the F155 item description itself (intentionally names the old name). Verification: `flutter analyze` clean; all 29 affected-suite tests green; final grep of lib/ + test/ + integration_test/ + assets/content/ = zero old-name hits; policy gate mutation-verified (old tooltip reintroduced -> 2 tests red -> restored -> 6/6 green).

---

## Task 4 -- F154: Help section for the Review No Rule Items screen (Priority 10, NEW this refinement)

**Value**: The app's DEFAULT screen (when accounts exist) is the only primary screen with no Help section of its own -- its Help icon currently deep-links to the Results section as "nearest match" (a gap explicitly noted in `no_rule_review_screen.dart`'s own comment and deferred since F133-S52). First-time users land on this screen first; it should explain itself.

**Requirements** (numbered, detailed):
- R-1: New `HelpSection.reviewNoRuleItems` enum value, positioned with the screen-anchored sections (after `scanHistory`, before the Settings sub-sections) so on-page order mirrors app structure. Section title: "Review No Rule Items" (Task 3's new name).
- R-2: New content file `assets/content/help/review_no_rule_items.md` + `manifest.yaml` entry + pubspec asset entry (follow the ADR-0038 pattern; `scripts/validate-content-manifest.ps1` must pass). **Content drafted from ACTUAL functionality** (per Harold) by reading `no_rule_review_screen.dart`: what the screen shows (cross-account unaddressed no-rule items, account filter chips with counts), where items come from (latest scans; background scans feed it), what actions exist (click an item -> rule/safe-sender popup with Skip; multi-select via checkboxes, Ctrl/Shift-click, right-click menu -- Windows; bulk actions), what Reload does (re-reads stored results, does NOT fetch new mail -- the tooltip's own distinction), and how items leave the list (addressed by rule/safe-sender/skip). Style-matched to existing sections (1-3 short tooltip-style paragraphs + a short list, Markdown per F151i). **Draft flagged for Harold's review during Manual Validation** (explicit request).
- R-3: `no_rule_review_screen.dart`'s `helpSection:` changes from `HelpSection.resultsDisplay` to the new section; the "nearest match" comment is replaced with the resolution note.
- R-4: Adjust all related tests: `help_screen_test.dart` enum count (22 -> 23) + heading list; `integration_test/help_deep_link_test.dart` (verify whether it auto-iterates `HelpSection.values` -- if yes it covers the new section automatically, confirm green; if it enumerates explicitly, add the case); any other help-link assertions surfaced by the suite.
- R-5: Audit other screens' help-link choices for knock-on effects: any OTHER caller using `resultsDisplay` as a stand-in for no-rule context (e.g. filtered views) switches only if the new section is genuinely the better target -- record each decision.

**Affected components / files**: `help_screen.dart` (enum + section + manifest key switch), `no_rule_review_screen.dart`, `assets/content/manifest.yaml`, new `assets/content/help/review_no_rule_items.md`, `pubspec.yaml` (asset entry), `help_screen_test.dart`, `integration_test/help_deep_link_test.dart`.

**Dependencies / blockers**: Task 3 (rename) first, so content and title use the final name.

**Acceptance criteria**:
- AC-1: Given the Review No Rule Items screen, When the Help icon is tapped, Then Help opens scrolled to the new "Review No Rule Items" section.
- AC-2: The section renders as formatted Markdown with content describing the actual current functionality (verified against the screen's code, then by Harold at Manual Validation).
- AC-3: All 23 `HelpSection` values pass the deep-link integration suite; content-manifest validator passes; full suite green.

**Tests to write**: T-1 -- `help_screen_test.dart` updates (count + heading), T-2 -- deep-link coverage for the new section (auto or explicit per R-4), T-3 -- mutation-verify the screen's help-link change (point it back at resultsDisplay, the deep-link/heading assertions must catch it if feasible; else record why not).

**Definition of Done**: default task-level DoD PLUS: content draft explicitly listed in the Manual Validation recommendation for Harold's review.

**Model**: Sonnet -- *why not Haiku*: authoring accurate user-facing content from reading real screen behavior, plus the R-5 judgment audit. The wiring alone would be Haiku-able; the content is the hard part.

**Executed-by**: Fable 5 (session model; executed inline -- content research was already in-context from planning)
**Step-types**: CONTENT, UI-MOVE, TEST-WIDGET, TEST-INTEGRATION
**Est-Effort**: 45-60m -- **Actual: ~30m**

**COMPLETION NOTES (2026-08-15)**:
- Content (`review_no_rule_items.md`) written from a read of `no_rule_review_screen.dart` itself: cross-account latest-scan aggregation, filter chips with counts, plain/Ctrl/Shift click selection semantics (verified against `_handleItemTap` -- plain click is select/toggle, NOT open-detail; this screen is triage-only), right-click + Apply Rule bulk menu (3 safe-sender + 3 block + Remove Current Rule described by label AND effect: dismisses as reviewed without creating a rule), auto-removal of rule-covered items on reload (`_sweepCoveredItems`), and the Reload tooltip's own does-not-fetch-mail distinction. **DRAFT FOR HAROLD'S REVIEW AT MANUAL VALIDATION** (explicit R-2 ask).
- Wiring: `HelpSection.reviewNoRuleItems` placed after `scanHistory` (screen-anchored order); `_section()` entry titled "Review No Rule Items" (F155 name); `_manifestKeyFor` case; manifest + pubspec asset entries; `no_rule_review_screen.dart` helpSection switched from the resultsDisplay stand-in (comment updated to the resolution note).
- R-5 audit: the only other `resultsDisplay` caller is `results_display_screen.dart` linking to its OWN section (plus its demo branch) -- correct as-is, no change.
- Tests: enum-count 22 -> 23 (`help_screen_test.dart`, plus its "22 sections" comment); `help_deep_link_test.dart` `_allSections` += reviewNoRuleItems (map is explicit, not values-derived -- the enum-count gate is what forces this map to be revisited); NEW `test/ui/screens/no_rule_review_help_link_test.dart` pinning the screen-side wiring end to end (pumps the real screen with the sibling tests' secure-storage channel stub + DatabaseTestHelper, taps Help, asserts the section title lands at the Scrollable top per the F145 pattern). MUTATION-VERIFIED: switching the screen back to resultsDisplay turns the new test red; restored green. Validator 23/23; `flutter analyze` clean.
- Harness note: `pumpAndSettle` on the pumped screen times out (ambient animations); bounded pumps used, matching sibling tests.

---

## Unplanned in-sprint work: WinWright sweep restoration (2026-08-15)

The end-of-sprint WinWright sweep (mandatory: lib/ui touched) failed 3/3 on first run and was restored to green (3/3 scripts, 66/66 steps). Root causes, all pre-existing except one:
- All three active scripts still assumed the PRE-F135 UI (Sprint 52): a home-screen entry-point icon (the screen has BEEN home since F135 and suppresses its own icon), the Settings account-picker overlay (removed by F135's lazy resolution), 'Refresh' tooltips (renamed Sprint 52), and July-era baseline sender rows. The sweep had not actually run green since 2026-07-28 -- Sprints 52-58 all touched lib/ui, so the end-of-sprint sweep step was evidently skipped or not verified for 7 sprints. **Process finding for the retrospective.**
- One miss was this sprint's (F155): a `head -5`-truncated verification grep hid 2 old-name selectors in `test_mt2c_no_rule_sweep.json`.
- A NEW launch-timing race: post-F135 the home screen runs the covered-item sweep against the full rule set BEFORE the window titles itself (~10-16s measured), racing the runner's 12s wait + 2s settle -- symptom was 'No main window found' on step 2 of every script. Runner hardened to 30s + 8s with the rationale in a comment.
- **Claude cowork review point (relayed by Harold) implemented**: WinWright scripts encode user-facing strings but sat outside the Dart rename net. New policy gate `test/policy/winwright_script_strings_test.dart` fails the suite if any script references a retired string (old screen name, `name='Refresh'` selectors, the removed account-picker); mutation-verified red/green.
- Residual finding (NOT fixed, time-boxed): the runner's DB snapshot guard errors (`Parse error near line 1: near "."`) and continues without the drift guard -- pre-existing, surfaced in every run this session. Backlog candidate.
- MT2C-3's premise ("cold re-mount on re-entry") is unreachable post-F135 (the root route stays alive); reworked as a navigation round-trip with the fresh-mount case delegated to the widget test, documented in the script.

## Execution order and Manual Validation

**Order**: Task 1 (F150, interactive -- Harold available) -> Task 2 (F153) -> Task 3 (F155 rename) -> Task 4 (F154 help section).

**Manual Validation recommendation** (refine at execution end): (1) review the new Review No Rule Items help content (explicit R-2 ask); (2) verify the rename on every screen surface (tooltips, screen title, help text); (3) if F150 lands, optionally eyeball the app on the Android emulator (F142's deferred visual check); (4) F153's outcome is docs -- review the corrected WinWright capability statements.

**Model summary**: Haiku 1 task (F155), Sonnet 3 tasks (F150 interactive-external, F153 investigation, F154 content) -- cheapest-first applied; no top-tier tasks.
**Total Est-Effort**: ~125-195m plus Harold-dependent console round-trips.
