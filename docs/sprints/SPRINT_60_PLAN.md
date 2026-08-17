# Sprint 60 Plan

**Branch**: `feature/20260815_Sprint_60`
**Dates**: 2026-08-16 --
**Scope defined by Harold** (2026-08-16): F160 (NEW: skipped-tests audit), F156, F157, F158, F159, F143, F144.
**Theme**: the Android rollout sprint -- F150 reopened the platform; this sprint modernizes the Android build config (F157), guards it in CI (F158), adapts the two remaining platform-specific gaps (F143 selection, F144 background scanning), and validates everything with the full walk-through (F156) -- plus two hygiene items (F160 audit, F159 metadata gates).

**Proposed execution order** (differs from priority order, with reasons): F160 (independent analysis, gives Harold the decision table early) -> F157 (may change the gradle config everything downstream builds against) -> F158 (CI job should guard the FINAL config) -> F159 (independent, small) -> F143 -> F144 (Android code changes) -> **F156 LAST** (the walk-through validates the sprint's final state -- running it first would test a config and codebase this sprint is about to change). Priority order (F156 = 10) reflects importance, not sequence; if the sprint must stop early, completed Android changes still get walk-through coverage scoped to what landed.

**In-flight (not a task)**: 0.9.0.0 / Submission 16 in certification. Step 7 close-out (Live row, CHANGELOG [0.9.0], dev bump 0.9.1) runs when Harold confirms certification.

---

### Task 1 -- F160: Skipped-tests audit -- 29 tests: purpose, skip reason, recommendation (Priority 8)

**Value**: This gives Harold a per-test decision basis for suite hygiene -- 29 tests have been skipped in every full run for many sprints with no consolidated record of why or whether they still earn their place.

**Requirements** (numbered, detailed):
- R-1: Reconcile the 25 skip SITES (planning inventory: 9 files) against the 29 skipped TESTS the runner reports (group-level skips expand to multiple tests) -- the audit covers all 29, exactly.
- R-2: For each test: (1) what it does and its original purpose (from the test body + git history where needed), (2) why it is skipped (the recorded skip reason, verified against current reality -- a stale reason is itself a finding), (3) a recommendation: **discontinued** / **updated to working** / **kept for special-purpose testing**, each with a one-line justification.
- R-3: Present as a decision table (plain markdown list-per-file in chat per Harold's presentation preferences; table form in the doc) for Harold's per-test or per-group disposition.
- R-4: Scope guard: implementing dispositions is NOT in this task -- unless a disposition is trivially small (e.g. deleting a test file Harold discontinues), in which case apply-on-approval within the sprint. Larger "update to working" work becomes follow-up items.

**Affected components / files**: read-only analysis of `test/adapters/email_providers/gmail_api_adapter_test.dart`, `test/integration/{aol_folder_scan, credential_verification, delete_to_trash, email_scanner_readonly_mode, imap_adapter, yaml_migration_integration}_test.dart`, `test/unit/rule_evaluator_test.dart`; audit lands in this plan (completion notes) or `docs/SKIPPED_TESTS_AUDIT.md` if it outgrows the card.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: All 29 skipped tests enumerated with the three answers each; the 25-site/29-test reconciliation shown.
- AC-2: Every recommendation is one of the three verdicts with a justification; no test left "unknown".
- AC-3: Presented to Harold for disposition (his decisions recorded; implementation scoped per R-4).

**Tests to write**: None (analysis deliverable).

**Definition of Done**: default task-level DoD (test/CHANGELOG items N/A -- analysis) PLUS: Harold's dispositions recorded next to the table.

**Model**: Sonnet -- *why not Haiku*: the keep/update/discontinue judgment requires weighing each test against the current architecture (several skip reasons reference refactorings that later happened or were superseded).

**Executed-by**: Fable 5 (session model; executed inline)
**Step-types**: DOCS (analysis)
**Est-Effort**: 45-60m -- **Actual: ~35m**

**COMPLETION NOTES (2026-08-16) -- THE AUDIT. Reconciliation: 25 static skip sites + the `email_scanner_readonly_mode` GROUP skip expanding to 4 tests + 1 runtime `markTestSkipped` (f33 snapshot test, env-gated) = 29 skipped tests, matching the runner (the 9 static files alone report ~28; the f33 test is the 29th). A second runtime-skip site (`domain_dns_verification_test.dart`) skips only on network loss and is NOT among the standing 29.**

| # | Test (file: name) | Purpose | Why skipped | Recommendation |
|---|---|---|---|---|
| 1-3 | `gmail_api_adapter_test.dart`: fetch / listFolders / testConnection "without authentication" | Assert the UNAUTHENTICATED error paths (StateError thrown; isConnected=false) | `skip: true // Requires real Gmail account and OAuth` -- but the bodies test the NO-auth paths; the real blocker is the adapter's calls hitting google_sign_in platform channels in a unit environment | **UPDATE TO WORKING** -- the stated skip reason contradicts the test intent; with the channel stubbed (same seam sibling tests use) these become real unit tests of error paths. Fallback if the adapter cannot run channel-stubbed: discontinue (they assert almost nothing as written). |
| 4-6 | `aol_folder_scan_test.dart`: migration+rules loaded / scan Bulk Mail Testing folder / connect+list folders | Live diagnostic scan of Harold's REAL AOL mailbox verifying rules match real spam | Requires real AOL credentials + network (and path_provider for one) | **KEEP for special-purpose** -- live diagnostics by design (they even guard on credentials being present). |
| 7-10 | `credential_verification_test.dart`: storage available / all accounts verify / AOL specifically / Gmail specifically | Verify REAL saved credentials decrypt and authenticate per adapter | Requires platform-native secure storage (device/integration runner) | **KEEP for special-purpose** -- an on-device diagnostic tool validating Harold's actual stored credentials; channel-stubbing would destroy its purpose. |
| 11-13 | `delete_to_trash_test.dart`: IMAP moves to Trash (not permanent) / Gmail uses trash API / moveToJunk uses move (not copy+delete) | Guard the SAFETY property that deletes are recoverable | `Requires adapter refactoring for DI` -- written before the adapters had injectable seams; never revisited | **UPDATE TO WORKING** -- the highest-value candidates in the audit: they guard data-loss safety, currently covered only implicitly. Needs a small seam investigation. |
| 14-17 | `email_scanner_readonly_mode_test.dart` (GROUP of 4): readOnly prevents takeAction / safeSendersAndRules allows / rulesOnly respects limit / readonly logs proposed actions | Issue #9 prevention: read-only mode must NEVER act on real mail | `Pending Issue #117 - requires RuleSetProvider refactoring` (stale -- the provider architecture has since changed twice) | **UPDATE TO WORKING** -- the enforcement property is genuinely uncovered elsewhere (`scan_mode_enforcement_test.dart` covers mode MANAGEMENT, not action prevention). Read-only is the default mode and the product's core safety promise. |
| 18-24 | `imap_adapter_test.dart`: 7 credential-gated tests (auth failure, connect, list folders, fetch inbox, fetch bulk, parse headers, ...) | Live IMAP integration against real AOL when TEST_EMAIL/TEST_PASSWORD env vars are set | `skip: testEmail.isEmpty || testPassword.isEmpty` -- deliberate env-var gating, self-activating when credentials provided | **KEEP for special-purpose** -- correctly designed opt-in live tests; no change needed. |
| 25 | `yaml_migration_integration_test.dart`: "Migration handles malformed YAML gracefully" | Asserts partial-import-with-errors on malformed YAML | Implementation deliberately THROWS on malformed YAML instead (fail-loud won) | **DISCONTINUE** -- asserts a rejected design; the accepted throw behavior deserves its own small positive test if not already covered by `migration_test.dart`'s neighboring cases. |
| 26 | `yaml_migration_integration_test.dart`: "Migration creates backups of YAML files" | Asserts the timestamped-backup invariant (a documented YAML-export invariant) | `Backup creation timing differs from test expectation` -- an assert-timing bug in the TEST, not a product gap | **UPDATE TO WORKING** -- the backup invariant is real and documented; the test raced the backup write. Small fix. |
| 27 | `yaml_migration_integration_test.dart`: "Migration handles missing condition type gracefully" | Asserts report-and-continue on missing condition type | Implementation deliberately THROWS instead | **DISCONTINUE** -- same class as #25: asserts the rejected alternative. |
| 28 | `rule_evaluator_test.dart:425` (headers[From] matching) | Asserted header-based From matching | `RuleEvaluator uses message.from (display), not headers[From] - intentional design` | **DISCONTINUE** -- a permanently-skipped test is a poor home for a design note; the design decision is stable and better carried as a code comment. |
| 29 | `f33_cleaned_patterns_compile_test.dart` (runtime skip) | Safety net: every F33-cleaned body-rule pattern compiles + passes the ReDoS guard, against a dev-DB snapshot | Runs only when `F33_PATTERN_SNAPSHOT` points at an exported snapshot -- by design (no hardcoded machine path, Copilot review Sprint 46) | **KEEP for special-purpose** -- correctly env-gated one-shot verification tool; self-documents its export command. |

**Verdict tally (by test)**: UPDATE TO WORKING: 11 (gmail x3, delete_to_trash x3, readonly-group x4, yaml-backup x1) across 4 work items; DISCONTINUE: 3; KEEP special-purpose: 15. Per R-4: none of the update items are trivially small (each needs a seam investigation or a timing fix), so implementation is follow-up scope pending Harold's dispositions at Manual Validation -- proposed as one follow-up item per file-group if approved.

---

### Task 2 -- F157: Impact study -- adopt the Flutter-suggested gradle/minSdk modernization (Priority 12)

**Value**: This lets us absorb the toolchain's own migration (which WILL keep re-applying itself on Android builds) instead of fighting it -- per Harold's carry-little-tech-debt call when IMP-6 was skipped.

**Requirements** (numbered, detailed):
- R-1: Determine what `flutter.minSdkVersion` resolves to on the current toolchain, and whether it satisfies F108's hard floor (flutter_secure_storage 10 requires API >= 23).
- R-2: Run the migrator deliberately (a throwaway `flutter build apk --debug`) and capture EVERYTHING it wants to change ("Upgrading build.gradle.kts" and any siblings) -- the study covers the full suggested change-set, not just minSdk.
- R-3: Decide per change: adopt as-is / adopt with the floor expressed Flutter's way (e.g. `maxOf(flutter.minSdkVersion, 23)` or keeping the literal if resolution < 23) / reject with reason.
- R-4: **Implement in-item if the measured impact is < 200 LOC AND < 2h wall-clock** (Harold's explicit threshold); otherwise report findings and split implementation to a follow-up item.
- R-5: Verified by a real debug build + emulator install after any adoption; the F108 comment block updated to reflect the final form.

**Affected components / files**: `mobile-app/android/app/build.gradle.kts` (and any sibling gradle files the migrator touches); possibly `mobile-app/android/settings.gradle.kts` / gradle wrapper.

**Dependencies / blockers**: None. Runs BEFORE F158 so CI guards the final config.

**Acceptance criteria**:
- AC-1: A written change-set inventory with per-change disposition and the minSdk resolution answer.
- AC-2: If implemented: `flutter build apk --debug` green, APK installs/launches on the emulator, F108's >= 23 floor demonstrably preserved (resolution value recorded).
- AC-3: The watch-item ("migrator may re-apply on any build") is either RETIRED (config now matches the migrator's target) or explicitly kept with the reason.

**Tests to write**: None beyond the real-build verification (build config); F159's gate work is separate.

**Definition of Done**: default task-level DoD PLUS: master-plan F157 entry updated with the outcome.

**Model**: Sonnet -- *why not Haiku*: toolchain-behavior investigation with a compatibility judgment against a documented hard floor.

**Executed-by**: Fable 5 (session model; executed inline)
**Step-types**: DATA (build config), DOCS
**Est-Effort**: 30-60m study; +<=2h only if the implement-in-item threshold is met -- **Actual: ~25m total (study + implement)**

**COMPLETION NOTES (2026-08-16)**:
- R-1: `flutter.minSdkVersion` = **24** on this toolchain (read directly from the Flutter gradle plugin's `FlutterExtension.kt`) -- above F108's 23 floor.
- R-2: full change-set captured via a deliberate throwaway `flutter build apk --debug`: the migrator rewrote exactly ONE line (`minSdk = 23` -> `minSdk = flutter.minSdkVersion`, "Upgrading build.gradle.kts"); no sibling gradle files touched.
- R-3/R-4: ADOPTED, implemented in-item (1 line + comment, minutes -- far under the 200-LOC/2h threshold), as `minSdk = maxOf(flutter.minSdkVersion, 23)`: tracks Flutter's floor automatically AND keeps F108's requirement explicit in code instead of trusting Flutter's default never to drop. Effective floor rises 23 -> 24 (drops Android 6.0; F108's own negligible-user-base reasoning applies).
- R-5/AC-2: clean rebuild with the maxOf form: **zero "Upgrading" messages and no migrator diff** -- the form does not match the migrator's literal-value pattern, so the rewrite loop is broken. Fresh APK installed + launched on the emulator (old install removed first -- the AVD hit INSTALL_FAILED_INSUFFICIENT_STORAGE with two 173MB debug APKs; noted for F156's walk-through hygiene); `dumpsys package` confirms effective `minSdk=24`.
- AC-3: the Sprint 59 watch-item ("migrator may re-apply on future builds") is RETIRED.

_**Risk & rollback**_: build-config changes are fully covered by git revert of the gradle files; the debug build + emulator launch is the acceptance gate before anything is kept.

---

### Task 3 -- F158: CI guard for the F150 regression class -- Android debug build job (Priority 14)

**Value**: This prevents the F150 class (Android build broken for months, discovered only when someone finally built) from ever recurring silently.

**Requirements** (numbered, detailed):
- R-1: Add an Android debug build job (`flutter build apk --debug`) to `.github/workflows/ci.yml`, additive to the existing analyze/test + Windows jobs.
- R-2: Resolve the `google-services.json` question deliberately: the file is gitignored and the build fails without it. Options to evaluate: (a) commit a CI-only copy under a non-ignored path, copied into place by the job (google-services.json is configuration, not a credential -- but make this an explicit decision); (b) inject via a repo secret; (c) a minimal valid stub with the correct package name. Record the decision and rationale in the workflow file comment.
- R-3: Empty-string dart-defines follow the established CI convention (F127 decision) -- the job verifies the BUILD, never runs the app.
- R-4: Job must run on PRs to develop like the existing jobs; runtime kept reasonable (use gradle/pub caching consistent with the existing jobs' style).

**Affected components / files**: `.github/workflows/ci.yml`; possibly a new `mobile-app/android/ci/google-services.ci.json` (or secret), per R-2's decision.

**Dependencies / blockers**: After F157 (guard the final gradle config).

**Acceptance criteria**:
- AC-1: CI run on this sprint's PR shows the Android job green against the final config.
- AC-2: The R-2 decision is written in the workflow comment (12-month readability).
- AC-3: Negative check reasoned in-plan: the job would have caught F150 (a config missing the real applicationId fails `processDebugGoogleServices` in CI).

**Tests to write**: The CI job IS the test; AC-1 is its verification.

**Definition of Done**: default task-level DoD PLUS: CHANGELOG `test` entry.

**Model**: Sonnet -- *why not Haiku*: R-2 is a security/config judgment call, not mechanical YAML.

**Executed-by**: Fable 5 (session model; executed inline)
**Step-types**: DEVOPS (CI), DOCS
**Est-Effort**: 30-60m -- **Actual: ~25m**

**COMPLETION NOTES (2026-08-16)**:
- R-2 decision: option (c) STUB, committed at `android/ci/google-services.ci.json` -- real package name, deliberately fake values, self-documenting comment. Rationale written in the workflow: PUBLIC repo rules out committing the real config (Firebase API key); a secret buys nothing while CI never RUNS the app (F127 philosophy); the stub exercises exactly what the F150 class breaks (config/applicationId matching).
- Local pre-verification: stub PASSES `:app:processDebugGoogleServices`; MUTATION (package swapped to a wrong name) FAILS with the exact F150 signature 'No matching client found' -- both run against the real gradle task, real config backed up and restored (verified) around both checks.
- Job: ubuntu-latest + temurin JDK 17 + the same pinned Flutter as the sibling jobs; runs on PRs to develop.
- AC-1 VERIFIED: PR #335 CI run -- 'Analyze and Test: pass, Android Build Verification: pass, Windows Build Verification: pass'.
- AC-3: the negative check is the mutation above -- the F150 state is exactly 'config without the real applicationId', and it fails the job's core task.

---

### Task 4 -- F159: Metadata-under-gates -- msix_version + dependency floors (Priority 16)

**Value**: This closes the cowork review's named pattern ("version or constraint metadata no gate watches" -- the same class as WinWright scripts sitting outside the rename net): dev `msix_version` drifted silently for ~10 releases, and the `^17.0.0`-vs-17.2.1 floor error shipped in a comment claiming the opposite.

**Requirements** (numbered, detailed):
- R-1: Extend `version_consistency_test.dart` + `check-version-consistency.ps1` to assert the DEV worktree's `msix_config.msix_version` equals pubspec `version`'s `X.Y.Z` + `.0` (the convention documented in `STORE_VERSION_STATUS.md` since Sprint 59).
- R-2: Evaluate a cheap dependency-floor sanity check: where a pubspec comment cites an upstream fix version ("first released in N"), assert the constraint floor >= N. If not cheaply assertable in a robust way, implement the msix_version half only and record what is deliberately left unwatched (honest scope, per the F160-style verdict discipline).
- R-3: Both new assertions mutation-verified (introduce a drift, gate goes red, restore).

**Affected components / files**: `mobile-app/test/policy/version_consistency_test.dart`, `mobile-app/scripts/check-version-consistency.ps1`.

**Dependencies / blockers**: None.

**Acceptance criteria**:
- AC-1: Setting dev `msix_version` to a stale value fails the suite with a message naming the convention.
- AC-2: R-2's outcome recorded either as a working check (mutation-verified) or a written left-unwatched decision.
- AC-3: Full suite green; gate self-checks pass.

**Tests to write**: T-1 (verifies AC-1) -- TEST-UNIT extension in `test/policy/version_consistency_test.dart`; T-2 -- mutation checks for each new assertion (procedure recorded in completion notes).

**Definition of Done**: default task-level DoD PLUS: mutation evidence in completion notes.

**Model**: Haiku -- the msix_version half is a tightly-spec'd mechanical gate extension mirroring existing matcher patterns in the same file. *(Escalate to Sonnet only if R-2's floor-check design proves non-trivial -- and de-scoping R-2 per its own escape hatch is preferred over escalating.)*

**Executed-by**: Fable 5 (session model; executed inline -- faster than delegating for a 2-file change; the Haiku assignment's escalation clause was not needed)
**Step-types**: TEST-UNIT, HOOK (script)
**Est-Effort**: 45-60m -- **Actual: ~15m**

**COMPLETION NOTES (2026-08-16)**:
- R-1: new `msix_version tracks pubspec version as X.Y.Z.0` test in `version_consistency_test.dart` + equivalent check appended to `check-version-consistency.ps1` (both fail loudly if the msix_config line disappears, per the moved-block failure mode).
- R-2 escape hatch TAKEN as pre-declared: dependency-floor claims left unwatched, with the decision recorded IN the gate's own comment (prose-claim-to-constraint matching needs NLP or a new comment convention; neither robust-cheap).
- R-3: mutation-verified BOTH paths -- msix_version set to the historically-stale 0.6.0.0: Dart gate red (+2 -1), CLI exit 1 with the convention message; restored: Dart 3/3 green, CLI [OK], `-SelfTest` still ALL PASSED.

---

### Task 5 -- F143: Android entry point + touch-adapted selection for the Review No Rule Items screen (Priority 20)

**Value**: This makes the app's default screen actually usable on Android -- its multi-select is Ctrl/Shift/right-click only (a genuine platform "cannot" for touch), and its AppBar icon is Windows-gated pending exactly this redesign.

**Requirements** (numbered, detailed):
- R-1: Touch selection model per the F141 direction: long-press a row to enter selection mode (selects that row); while in selection mode, plain taps toggle rows; a contextual bar (the existing selection bar) carries the count/Clear/Apply Rule menu, which already works by tap unchanged.
- R-2: Desktop behavior UNCHANGED: plain click select/toggle, Ctrl/Shift semantics, right-click menu, checkboxes -- all exactly as F129/F115 shipped them (policy gates + existing tests must stay green untouched except where a test asserts the desktop-only gate removed below).
- R-3: Un-gate the AppBar entry-point icon: `StandardAppBarActions`'s `Platform.isWindows` gate on the Review No Rule Items icon is removed (F142's R-3 explicitly deferred this to F143), so Android gets the icon on non-default screens too. Update the tests that pin the Windows-gating (they document it as awaiting F143 by name).
- R-4: Long-press must not conflict with the existing row semantics (Semantics labels, checkbox tooltips -- F129's accessibility work stays intact).

**Affected components / files**: `mobile-app/lib/ui/screens/no_rule_review_screen.dart` (tap/long-press handling), `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart` (gate removal), `test/ui/widgets/appbar_action_navigation_test.dart` + `test/ui/screens/results_display_no_rule_reload_test.dart` (Windows-gate pins), new widget tests.

**Dependencies / blockers**: None (F142 landed Sprint 57; F150 resolved). F156 validates it on-device afterwards.

**Non-functional requirements**:
- Accessibility: F129 semantics preserved (row labels, per-row checkbox names).
- Platform: selection MODEL is input-driven (long-press works on desktop too, harmlessly); the gate removal is the only platform-conditional change.

**Acceptance criteria**:
- AC-1 (behavioral): Given the screen with items on a touch device, When a row is long-pressed, Then selection mode activates with that row selected and the selection bar appears.
- AC-2 (behavioral): Given selection mode active, When another row is tapped, Then it toggles into/out of the selection (and Clear exits selection mode).
- AC-3: All existing desktop-selection tests pass unmodified; the un-gated icon appears in the Android path (widget test with the platform override seam the existing gate tests use).
- AC-4: Full suite green; analyze clean.

**Tests to write**: T-1 (AC-1/AC-2) -- TEST-WIDGET in `test/ui/screens/no_rule_review_touch_selection_test.dart`: long-press activates + tap toggles + Clear exits; T-2 (AC-3) -- update the gate-pin tests to assert the icon on BOTH platforms; T-3 -- mutation check (re-gate the icon, updated tests go red).

**Definition of Done**: default task-level DoD PLUS: on-emulator touch verification folded into F156's walk-through checklist.

**Model**: Sonnet -- *why not Haiku*: an interaction-model change on the app's default screen with strict do-not-regress desktop semantics.

**Executed-by**: Fable 5 (session model; executed inline)
**Step-types**: UI-MOVE, TEST-WIDGET
**Est-Effort**: 60-90m -- **Actual: ~70m (of which ~35m was test-harness archaeology)**

**COMPLETION NOTES (2026-08-16)**:
- R-1: long-press ADDS the row (wired on all platforms -- harmless extra path on desktop, one code path); on touch platforms (Theme platform android/iOS) a plain tap while a selection is active TOGGLES the tapped row. The existing selection bar/Apply Rule menu serves as the contextual bar unchanged.
- R-2 VERIFIED: desktop replace-single semantics pinned by a dedicated regression-guard test (AC-3); all 12 pre-existing screen tests plus the F129 semantics tests untouched and green.
- R-3: `Platform.isWindows` gate removed from the builder (comment now records the F142->F143 history); `dart:io` import dropped; both gate-pin tests updated to assert the icon on EVERY platform (they previously ran the assertion Windows-only, which kept it out of CI).
- Platform seam decision: `Theme.of(context).platform` rather than `defaultTargetPlatform` -- the global `debugDefaultTargetPlatformOverride` trips the foundation-vars test invariant in this Flutter version even when reset via addTearDown (discovered empirically); the Theme seam is per-tree and invariant-clean.
- Test-harness lesson re-learned (the sibling test's header documents it): sqflite_ffi calls never resolve in the fake-async widget-test zone -- the new test uses runAsync + mountAndLoadDbWidget, plus the secure-storage stub must serve the `saved_accounts` key because `_loadItems` enumerates accounts from secure storage, NOT the DB.
- MUTATIONS: (a) icon suppressed in the builder -> both updated gate-pin tests red (+4 -2); (b) touch branch disabled -> AC-2 red while the desktop guard stays green (+2 -1); both restored, all green.
- Verification: new suite 3/3; `flutter analyze` clean; full suite **1,897 passed / 29 skipped / 0 failed**.

---

### Task 6 -- F144: Android background scanning re-evaluation (WorkManager) + POST_NOTIFICATIONS runtime request (Priority 22)

**Value**: This replaces dead code (an unwired pre-architecture `BackgroundScanManager`/`BackgroundScanService`) with a decision -- and closes the Android-13+ notification gap that would otherwise make every notification silently never show.

**Requirements** (numbered, detailed):
- R-1: EVALUATION FIRST (time-boxed): map the current Windows background-scan architecture (per-account scheduling, ADR-0039/0040, F98, Task Scheduler + execution alias) against what Android's WorkManager can express; produce a written design verdict -- what mirrors 1:1, what WorkManager genuinely substitutes, what cannot carry over.
- R-2: The old zero-call-site `BackgroundScanManager`/`BackgroundScanService` are REMOVED (dead code) unless the evaluation finds parts genuinely reusable under the Windows-mirroring design -- per the clarified 2026-08-03 direction, Windows' architecture takes precedence, not the old code's own decisions.
- R-3: Add the `POST_NOTIFICATIONS` runtime permission request (Android 13+/API 33+) at the appropriate first-notification-need moment, with the graceful denied path.
- R-4: IMPLEMENTATION of the mirrored Android scheduler is IN-item ONLY if the evaluation sizes it inside this task's time-box; otherwise the design verdict + dead-code removal + POST_NOTIFICATIONS ship now and the implementation becomes a sized follow-up item. **Class-3 note**: that split is pre-declared here, so taking it is executing the plan, not de-scoping.

**Affected components / files**: `mobile-app/lib/core/services/background_scan_manager.dart` + `background_scan_service.dart` (likely removal), notification permission request site (Android path of `background_scan_notification_service.dart` or first-run flow), `AndroidManifest.xml` (verify declaration), design verdict in completion notes.

**Dependencies / blockers**: After F143 (same screen/test surface churn); F156 validates on-device.

**Non-functional requirements**:
- Platform: all changes Android-pathed; Windows background scanning untouched (its policy gates must stay green).

**Acceptance criteria**:
- AC-1: Written design verdict per R-1 (mirrors / substitutes / cannot) in completion notes.
- AC-2: Zero references to the removed classes; full suite green after removal.
- AC-3: POST_NOTIFICATIONS requested at runtime on Android 13+ (verified on the emulator -- API 34 image), denied path does not crash or spam.
- AC-4: If R-4's in-item threshold met: a background scan schedules and fires on the emulator; else the follow-up item is registered and sized.

**Tests to write**: T-1 (AC-2) -- suite green post-removal is the regression net; T-2 (AC-3) -- TEST-UNIT for the permission-request logic seam (channel-mocked), on-device confirmation via F156.

**Definition of Done**: default task-level DoD PLUS: master-plan F144 entry updated with the verdict; ARCHITECTURE.md updated if the Android scheduler design lands.

**Model**: Sonnet -- *why not Haiku*: an architecture-mirroring evaluation with a removal decision. *(Escalate to Fable/Opus only on a genuine design blocker per SPRINT_PLANNING.md triggers.)*

**Executed-by**: Fable 5 (session model; executed inline)
**Step-types**: SVC-EDIT, DATA (manifest), TEST-UNIT, DOCS
**Est-Effort**: 2-3h time-boxed -- **Actual: ~50m (evaluation + removal; scheduler split out per the pre-declared threshold)**

**COMPLETION NOTES (2026-08-16)**:
- R-1 DESIGN VERDICT (Windows architecture as the reference, per the 2026-08-03 direction):
  - MIRRORS 1:1: per-account scheduling (WorkManager unique periodic work per accountId = per-account Task Scheduler tasks, ADR-0039/0040); frequency vocabulary (`ScanFrequency` unchanged; WorkManager's 15-min minimum period aligns exactly with `every15min`); settings-driven per-account frequency (same `SettingsStore` keys).
  - GENUINE SUBSTITUTIONS: WorkManager's in-process callback dispatch replaces the execution-alias + headless-exe model (no Android analogue of launching a versioned exe; this is the one place the old code's shape was right); network-connected constraint replaces Task Scheduler conditions.
  - CANNOT CARRY OVER: exact-time firing -- WorkManager defers under Doze/battery optimization; acceptable for this workload (scans are periodic hygiene, not alarms).
- R-2 EXECUTED: all four dead files removed (`background_scan_manager.dart`, `background_scan_service.dart`, `background_scan_worker.dart`, `background_scan_notification_service.dart` -- the last was itself transitively dead, referenced only by the dead service) plus their dead tests; `workmanager` dependency dropped (its only consumers). LIVE salvage: `ScanFrequency` extracted to `scan_frequency.dart` (it is the Windows path's frequency vocabulary -- 6 live importers retargeted), its tests consolidated into `scan_frequency_test.dart`; the background-scan INTEGRATION test kept (it exercises live stores) minus its two dead-symbol tests. Untruncated verification grep: every remaining mention of the removed symbols is comment-only.
- R-3 PREMISE CORRECTED (recorded, not silently skipped): the evaluation revealed there is NO Android notification call site at all -- the notification service was dead code too. A POST_NOTIFICATIONS runtime request with nothing behind it would prompt the user for a permission nothing can use (and reads badly in Play review). The request therefore ships WITH the scheduler in F161, at the genuine first-notification-need moment. AC-3's on-emulator verification moves to F161 accordingly.
- R-4 THRESHOLD APPLIED as pre-declared: the mirrored scheduler sized ~3-5h (scheduler + settings wiring + notification rebuild + permission + tests) -- outside this task's box. **F161 registered** (Priority 24) carrying the design verdict.
- Verification: `flutter analyze` clean after retargeting 6 importers + 4 test files; full suite **1,853 passed / 29 skipped / 0 failed** post-removal (down 44 from 1,897 -- exactly the deleted dead-code tests; the 29 standing skips are untouched, so F160's audit table remains accurate).

_**Risk & rollback**_: dead-code removal is git-revertible and gated on zero-reference proof; permission request is additive with an explicit denied path.

---

### Task 7 -- F156: Full Android app testing walk-through (Priority 10, executed LAST by design)

**Value**: This is the sprint's integration validation -- the first systematic exercise of the whole app on Android since the platform reopened, over the FINAL config and code this sprint produces. Errors are expected and are the point (Harold: "They are not a problem, just need to fix them").

**Requirements** (numbered, detailed):
- R-1: Walk the primary flows on the emulator (API 34 image): first-run/zero-accounts, add account (IMAP path; Google Sign-In now that SHA-1 is registered), Demo Scan, manual scan + results, Review No Rule Items (incl. F143's touch selection), rules/safe-senders management, Settings tabs, Help/deep links, notifications (F144's POST_NOTIFICATIONS).
- R-2: Automate where possible, per Harold: `integration_test` suites that run on the Android device (the F99 harness), plus adb-driven flows (screencap, uiautomator dump, input injection, logcat) for what integration_test cannot reach. Record per-flow HOW it was verified (automated / adb-driven / manual-with-Harold).
- R-3: Errors found: FIX AS FOUND when scoped inside the walk-through's time-box; larger findings become numbered follow-up items with repro notes. Every error gets root-caused or explicitly filed -- none silently noted.
- R-4: Real-credential flows (Gmail OAuth, live IMAP) are Harold-interactive -- coordinate live, same as F150's console walkthrough.
- R-5: Deliverable: a per-flow results table (flow / method / result / fixes / follow-ups) in completion notes.

**Affected components / files**: potentially anywhere in `lib/` (fixes as found); `integration_test/` additions where flows are automatable.

**Dependencies / blockers**: LAST in sprint (validates F157/F158/F143/F144 output). Harold availability for R-4 flows.

**Non-functional requirements**:
- Platform: fixes must not regress Windows -- full suite + analyze after every fix batch, same discipline as any sprint.

**Acceptance criteria**:
- AC-1: Every R-1 flow has a recorded result and method; no flow skipped silently.
- AC-2: All in-time-box errors fixed with tests where the fix is code; all out-of-box findings filed as numbered items.
- AC-3: Full suite green + analyze clean at walk-through end; the walk-through's own integration_test additions run green on the Android device.

**Tests to write**: Per-fix tests as errors surface (each fix carries its regression test, standing rule); new `integration_test` coverage for automatable flows (named per flow at execution).

**Definition of Done**: default task-level DoD PLUS: the R-5 results table; Manual Validation recommendation updated with anything needing Harold's eyes.

**Model**: Sonnet -- *why not Haiku*: exploratory testing with live root-causing across the whole app surface.

**Executed-by**: Fable 5 (session model; executed inline -- interactive adb driving with live diagnosis)
**Step-types**: TEST-INTEGRATION, SVC-EDIT (fixes as found), DOCS
**Est-Effort**: half-day time-boxed (~3-4h) -- **Actual: ~2h including the three fixes**

**RESULTS TABLE (R-5) -- flow / method / result** (fresh install, API-34 emulator, sprint-final build):

| Flow | Method | Result |
|---|---|---|
| First-run launch (zero accounts) | adb launch + screencap | PASS -- F151a welcome state renders; F143's un-gated Review No Rule Items icon now present in the Android AppBar |
| Demo Mode entry | adb tap + screencap | PASS -- Manual Scan in DEMO MODE, Read-Only, INBOX |
| Demo Scan | adb tap + screencap | **ERROR FOUND -> FIXED**: every scan failed at `PRAGMA busy_timeout` -- Android's SQLiteDatabase rejects value-returning PRAGMAs via execSQL; `journal_mode=WAL` was ALSO silently failing into its catch (Android never had WAL). Fixed with `rawQuery` for both (works on Android AND desktop FFI). Post-fix: scan completes in 1s -- Found 59 / Processed 59 / Deleted 26 / **Safe 21 (F151d verified on Android)** / No rule 12 / Errors 0; no dead Moved chip; provider-sender grouping renders |
| Scan-failure error surface | screenshot inspection | **SECONDARY FINDING -> FIXED**: the status header showed a DOUBLED prefix + raw exception ('Scan failed: Scan failed: DatabaseException(...) sql ...'). `email_scanner.dart` now routes through `ErrorMessages.humanize` (F151f's helper); errorScan keeps the single prefix. Existing tests assert only the prefix -- still green |
| Review No Rule Items entry (F143 icon) | adb tap + screencap | PASS -- screen opens via the new Android entry point; '0 items' is CORRECT (demo items live under the unsaved demo account; same behavior as Windows) |
| Touch selection (F143) | -- | Model covered by the 3 new widget tests; on-device interaction NEEDS REAL ROWS -> **Harold-interactive at MV** (add real account, scan, long-press) |
| Help deep-link from the screen (F154/F145/F151i/F155) | adb tap + screencap | PASS -- lands directly on 'Review No Rule Items', Markdown-rendered, new name, Copilot-corrected wording visible |
| Help content vs F143 | content review | **CONTENT GAP FOUND -> FIXED**: the F154 section described desktop-only selection (written pre-F143); a touch-selection sentence added to `review_no_rule_items.md` |
| Settings from zero-account screen | adb tap + fast screencap | PASS (initially looked like a dead icon -- a 1s-recapture showed the deliberate 'Please add an email account first' SnackBar; account-scoping behavior matches Windows) |
| Help deep-link suite (all 23 sections + conditional resolution) | **integration_test ON the emulator device** | **PASS 32/32 on the Android device** -- the sprint's automated on-device coverage |
| Gmail OAuth / live IMAP add-account / rules mgmt rendering / touch selection with real rows | -- | **Harold-interactive at Manual Validation** (same pattern as the F150 console walkthrough) |
| Notifications / POST_NOTIFICATIONS | -- | N/A this sprint -- no Android notification path exists until F161 (F144's verdict) |

---

## Manual Validation recommendation (refine at execution end)

1. F160's decision table -- your per-test dispositions (the sprint's one guaranteed Harold-decision point).
2. F156's results table review + any flows flagged Harold-interactive (Gmail OAuth on the emulator).
3. F143's touch selection feel on the emulator (long-press/tap-toggle is a UX judgment, not just a test).
4. If F157 implemented: nothing visual -- the build evidence suffices.

## Model summary

Haiku 1 task (F159), Sonnet 6 tasks (F160 judgment-audit, F157 toolchain study, F158 config decision, F143 interaction redesign, F144 architecture evaluation, F156 exploratory walk-through) -- cheapest-first applied per task; no top-tier assignments; escalation triggers stated inline.

**Total Est-Effort**: ~7-10h (roughly 1.5-2 working days), dominated by F156's half-day box and F144's 2-3h box.

**F156 verification at close**: on-device integration suite 32/32; local full suite **1,853 passed / 29 skipped / 0 failed**; `flutter analyze` clean. (One intermediate run failed 1: the humanize change collided with `email_scanner_test`'s pinned platform-not-supported message -- resolved with the app-authored-Exception pass-through rule, which is the better behavior anyway: informative app messages reach the user, raw internals get humanized.) AC-2 status: all in-box errors fixed with the fixes recorded above; no out-of-box findings needed filing. AC-1: every planned flow has a recorded result; Gmail OAuth / live IMAP / touch-with-real-rows are the Harold-interactive MV items by design (R-4).

---

## Manual Validation round 1 (Harold, 2026-08-16) -- findings and resolutions

- **F160 dispositions: ALL RECOMMENDATIONS APPROVED.** Applied in-sprint: the 3 discontinues deleted (yaml_migration malformed-YAML + missing-condition-type tests -- both asserted the rejected partial-import design; rule_evaluator headers[From] design-note skip -- the design decision now lives only in the code comment it always pointed at). Skips drop 29 -> 26. The 11 update-to-working verdicts registered as **F163** (4 work items, Priority 26). The 15 keeps unchanged.
- **Windows popup fit (fix requested, FIXED)**: popups opened from the first list rows clipped their bottom action rows off-window -- the position logic used an ESTIMATED height it neither clamped against nor enforced. Fix: `top` clamped so top + cap stays on-screen, and the popup hard-capped at the estimate with the existing inner scroll as fallback. Mutation discipline note: the first regression test (900px window) stayed GREEN against the pre-fix code -- worthless -- and was tightened to a 650px window where the pre-fix overflow genuinely reproduces (red under mutation, green after restore).
- **Android "divergences" (demo dataset of 10, dead summary-chip buttons, old Select Scan Mode dialog): ROOT-CAUSED AS A STALE APP, not current-code defects.** The "Select Scan Mode" dialog was removed from the codebase in February 2026 (Issue #123); none of the observed strings exist in current lib/. The emulator AVD had reverted state (dropping the sprint install entirely) and still carried the ANCIENT `com.example.spamfiltermobile` package -- which is what Harold's session exercised. Resolution: stale package UNINSTALLED from the AVD; sprint-final APK reinstalled and verified the only spamfilter package present. Note: the real AOL account Harold added during that session lived in the stale app's storage and went with it -- re-add in the current app for the interactive flows.
- **Parity audit + ADR (Harold's backlog ask): registered as F162** (Priority 18) -- full Windows-vs-Android walk-through, a new ADR defining same-vs-may-differ-vs-how-managed, divergences filed as ADR-referencing items, existing items updated rather than duplicated. The stale-app incident is written into the item as the verify-the-install-first cautionary rule.

## Manual Validation round 2 (Harold, 2026-08-16, CURRENT Android app) -- findings and resolutions

- **netsimd.exe crash on emulator start (x2)**: benign emulator sidecar (network-simulation daemon); the emulator falls back to its legacy network stack and nothing we use is affected. Optional fix offered: update the emulator package in the C:\Android SDK after the session.
- **"Not enough room to scroll" (FIXED)**: the Results screen's fixed header stack consumed nearly the whole phone height. On widths < 600px the summary/banners now fold INTO the scrolling list (full-screen list, header scrolls away); desktop keeps the fixed layout, pinned by a dedicated regression-guard test. Mutation-verified (isCompact forced false -> fold test red).
- **Filter-banner X dead on second scan (FIXED)**: root cause was unconditional -- the X called `_toggleFilter(null)`, a no-op whenever only the DEFAULT Processed special filter was active (the initState default). New `_clearAllFilters` clears action + special + folder filters. Mutation-verified (old handler restored -> X test red).
- **EmptyState overflow (FIXED, found via the new tests)**: the shared EmptyState Column overflowed short viewports (~44px in the Results screen's 40%-height box on a phone); now scrollable + min-sized, layout unchanged in normal viewports.
- **KNOWN, deferred to F162**: the AppBar icon row overflows at phone widths in widget-test asserts (~21px at the Pixel's 411 logical px; the real device ellipsizes the title and renders acceptably). Narrow-screen icon crowding (overflow menu? fewer icons on mobile?) is a design question for the parity ADR, not a spot fix -- recorded in the F162 context.
- Verification: new 3-test suite green + both fixes mutation-verified; all Results-screen suites green; full suite result recorded in the round-2 commit.

## Manual Validation round 3 (Harold, 2026-08-16, current Android app) -- findings and resolutions

- **CRITICAL FIX -- Android scan persistence was entirely broken** (Harold: "3 full scans, but scan history is empty on the re-launch... nothing shows in the No Rule screen"). Root-caused with on-device DB forensics (`adb run-as` pull of the WAL-mode DB): 0 `accounts` rows, 0 `scan_results`, 0 `email_actions`, 0 `unmatched_emails` -- while Harold's 2 safe-sender adds WERE present (428 safe_senders). Cause: `scan_results` has an FK to `accounts`, and the ONLY code creating the accounts row was the WINDOWS background worker's `_ensureAccountInDatabase` -- so Windows masked the shared gap for months while Android hit the FK on every scan (caught, logged 'Failed to create scan result', scan continued without persistence -- textbook silent failure). Fixed by ensuring the accounts row in the SHARED live-scan path (`EmailScanProvider._ensureAccountRow`, mirroring the worker). Regression test seeds NO accounts row -- every sibling persistence test pre-created one ("required for FK constraints" in its own harness comment), which is exactly why this class never showed in tests. Mutation-verified.
- **Answer to Harold's "is the scan a functional match?"**: YES -- one shared pipeline, zero platform forks in scan logic; the observed differences were this persistence defect (now fixed), the PRAGMA defect (fixed earlier today), and debug-APK + emulator speed (F164). Separate per-device STORAGE is a fact (F165 explores sync) but was not the cause of any observed difference.
- **F166 EXECUTED** (planned + card #336 per Harold's plan-then-execute steering): filter dropdown (No rule default; mode-adaptive Safe/Deleted labels; Errors; Processed; 'All: <found>' fallback face after the banner X) + Folders chip on one line; six stat chips and their builders removed; default filter changed Processed -> No rule (also resolves 'added safe senders but they still appear' -- Results rows are the scan's record by design, and the default filter now hides addressed ones); 'Scan complete <duration>' inline after 'Live Scan' (indicator rows min-sized for the Wrap); no-rule banner flag icon + progress bar removed; email-detail popup full-width on compact screens. Tests updated to drive the dropdown (open-menu count assertions; no activation tap needed for the default filter); compact-fold test reseeded 20 no-rule rows.
- **Backlog registered**: F164 (Android scan performance -- analysis says no architectural gap: debug-JIT APK vs release Windows + emulator overhead + the now-fixed missing WAL), F165 (cross-device rules-DB sharing via user cloud storage + $4/yr hosted-tier option -- product direction), F166 (executed in-sprint).

## Manual Validation round 4 (Harold, 2026-08-16, current Android app) -- findings and resolutions

- **"Scan history shows Background scan, No Rule 12 -> 9 on open, but Review No Rule Items is empty" -- ROOT-CAUSED via a second on-device DB pull; the persistence fix is CONFIRMED WORKING and the empty Review screen is CORRECT behavior for the device's current state.** Device DB: `scan_results` id 1 = account `demo@example.com`, type `demo`, completed, 59 found / 12 no-rule; `unmatched_emails` = 12 rows, 0 processed. The scan in history is the DEMO scan (with no account configured at that moment, Demo was the only scan possible). Review No Rule aggregates the latest completed scan of each CONFIGURED account (secure-storage `saved_accounts`); the demo pseudo-account is deliberately never a configured account, so demo no-rule items never feed Review -- identical behavior on Windows (parity, by design). Harold's re-added AOL account had zero completed scans on-device, hence 0 items. Resolution path: run Manual Scan > Live Scan with the configured account; Review then populates. The 12 -> 9 drop on opening the historical results is the current-rules sweep working as designed.
- **Demo scan mislabeled "Background" in Scan History (FIXED)**: the card badge was a binary `scanType == 'manual' ? 'Manual' : 'Background'`, so type `demo` displayed as "Background" -- on a platform with no background scheduler at all. Three-way label (Manual/Demo/Background; unknown still Background). Pinned by `scan_history_demo_label_test.dart`; mutation-verified (binary label restored -> test red; exactly-one-Background assertion catches the mislabeled card).
- Cosmetic note (accepted): `_ensureAccountRow` records the demo pseudo-account with platform `unknown` (accountId `demo@example.com` has no `platform-` prefix to parse). FK satisfied; no user-visible surface reads that row.

## End-of-sprint WinWright sweep evidence (2026-08-16, Phase 7.7 -- IMP-5 rule)

- Windows dev build rebuilt at HEAD (analyze clean) and launched fresh for the sweep.
- Sweep result: **3/3 scripts PASS, DB drift none** -- `test_f124_rule_labels.json` (10 steps, 5m05s), `test_f129_no_rule_review.json` (10 steps, 1m47s), `test_mt2c_no_rule_sweep.json` (25 steps, 4m09s).
- First run failed mt2c at step 6 exactly as its header documents for the data-precondition case: the two baseline sender rows had been ADDRESSED by Harold's MV rule/safe-sender additions (checked against the runner/README/script header FIRST -- known, not new evidence). Baselines refreshed from the live dev DB (`usecadence@wholehealthup.com`, `reminder@healthyfocusinsights.com`, 3 unaddressed rows available); re-run PASS. F166's header redesign did not break any script (none reference the retired chips, as the winwright_script_strings policy gate already guaranteed).

## PR #335 review round (2026-08-16) -- Copilot + Claude cowork

**Copilot (5 comments)**
- C1 exception classification: REFUTED with a direct Dart probe -- `Exception('x').runtimeType` IS `_Exception`, so the app-authored pass-through matches as intended (and `email_scanner_test` pins the behavior). No change.
- C2 accountId guess-parsing: VALID, FIXED. `startScan` now takes an explicit `platformId` threaded from EmailScanner (mirroring the Windows worker); the email is recovered only by stripping the known `<platformId>-` prefix, so `my-name@gmail.com` is no longer split into platform `my`. New regression test covers both dash cases.
- C3 mock-handler leak: FIXED (tearDown clears the secure-storage channel handler; the touch test already had one -- the duplicate was removed after the cowork review flagged it).
- C4 `AIza...` stub key: FIXED -> `ci-stub-not-a-real-api-key` (no secret-scanner bait).
- C5 hardcoded SDK root: FIXED -- `start-emulator.ps1` gained `-SdkRoot` (default unchanged).

**Claude cowork -- F166 scope (9 findings)**
1. Empty-state chain regression (MOST SEVERE): the chain branched on `_filter != null` to mean "your filter hid everything", but F166 made a No-rule filter the DEFAULT, so a never-scanned account was told its filters hid emails that never existed. FIXED: branch on `allResults.isNotEmpty` instead. A widget test for this was attempted and DELETED -- the empty-account path hangs both the DB harness and a plain pumpAndSettle (the screen awaits data that never arrives); the fix is verified by reading the branch chain and by analyze, and is NOT pinned by a test. Recorded as a known gap rather than shipped as a hanging test.
2. X-clears-all-dimensions test was not mutation-meaningful: FIXED -- it now activates the FOLDER dimension too and asserts `Folders: All` after the X; mutation-verified (removing `_selectedFolders = {}` turns it red).
3. F151c chip tooltips silently lost, guarding test passing vacuously off AppBar tooltips: FIXED -- all five Harold-approved F151c explanations restored VERBATIM as dropdown-entry subtitles, the Found explanation moved onto the chip-face tooltip, and the test rewritten to assert those exact strings; mutation-verified.
4. Stale banner instruction "Tap chip again to clear filter" (chips no longer exist, dropdown has no toggle-off): FIXED -> "Tap X to clear filters".
5. Popup show-above branch could sit up to 8px off-window: FIXED -- the `+8` gap is now inside the guard (`spaceAbove >= popupHeight + 8`).
6. `minWidth: 400` inert under FractionallySizedBox's tight constraint: FIXED (removed, with the reason recorded).
7. `ScanStartedEmptyState` not overflow-proofed alongside its sibling: FIXED (scrollable + min-sized).
8. Dead `SpecialFilter.found`: REMOVED.
9. "Scan complete <duration>" grew on every rebuild (30s scan read 12m 30s after 12 min of triage): FIXED -- duration frozen at `completeScan` via a new `scanEndTime`.

**Claude cowork -- F143 scope (4 findings)**
1. Help text promised tap-toggle "on a touch screen" while the code gates on Android/iOS (wrong on Windows touchscreens): FIXED -- wording now names Android and iOS.
2. `scan_history_screen._buildNoRuleChipWithReviewIcon` was the last `Platform.isWindows` gate on a Review entry point, with a comment claiming Windows-gating was the convention F143 had just removed everywhere else: FIXED -- un-gated, comment corrected.
3. AC-1 long-press was not mutation-meaningful (deleting `onLongPress` degrades to a plain tap that produces the identical asserted state): FIXED -- AC-1 now long-presses an ALREADY-SELECTED row and asserts it stays selected (a degraded tap would deselect); mutation-verified red with the wiring removed.
4. Duplicated tearDown from the Copilot fix: removed.

**Copilot second pass (1 further finding, FIXED)**
- The dash-guessing fix had corrected only the SHARED path; `BackgroundScanWindowsWorker._ensureAccountInDatabase` still carried the identical heuristic (a genuine miss -- the reviewer caught the sibling I did not sweep). Fixed there too. While fixing it, a SECOND dash site surfaced in the same file: the platform-inference fallback would read "my" out of `my-name@gmail.com` and then strip it, so it is now guarded to only accept a dash BEFORE the '@'. New policy gate `test/policy/account_id_no_dash_parsing_test.dart` pins both writers (scoped to the email-recovery region so legitimate dash scans stay legal); mutation-verified red against the restored heuristic. This is the "enumerate every site, not just the reported one" lesson recurring -- the first fix was symptom-scoped.

**Copilot third pass (1 finding, FIXED -- last round per Harold's steering)**
- `test_mt2c_no_rule_sweep.json` selectors carried two REAL correspondent addresses from Harold's live mailbox in a public repo. Valid, and a regression of Sprint 59's own anonymization (commit 891411b anonymized the account-chip selectors for exactly this reason; my 2026-08-16 baseline refresh reintroduced the pattern on the ROW selectors). Fixed: selectors now match the correspondent's DOMAIN only, never the local part, keeping the two baselines distinct as the assertion requires. Verified live that the anonymized selectors resolve and click (step 6 passed); the run then hit 'Cannot access a disposed object' at step 7 -- a harness/app-teardown fault unrelated to the selectors, recorded in the script header for re-verification at the next sweep. The Sprint 60 3/3 sweep evidence above was captured before this change.
- Per Harold's steering (2026-08-16): Copilot rounds stop here; any further comments roll to the next PR.
