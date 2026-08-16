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

**Executed-by**: _(fill at completion)_
**Step-types**: DATA (build config), DOCS
**Est-Effort**: 30-60m study; +<=2h only if the implement-in-item threshold is met

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

**Executed-by**: _(fill at completion)_
**Step-types**: DEVOPS (CI), DOCS
**Est-Effort**: 30-60m

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

**Executed-by**: _(fill at completion)_
**Step-types**: TEST-UNIT, HOOK (script)
**Est-Effort**: 45-60m

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

**Executed-by**: _(fill at completion)_
**Step-types**: UI-MOVE, TEST-WIDGET
**Est-Effort**: 60-90m

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

**Executed-by**: _(fill at completion)_
**Step-types**: SVC-EDIT, DATA (manifest), TEST-UNIT, DOCS
**Est-Effort**: 2-3h time-boxed (evaluation + POST_NOTIFICATIONS + removal certain; scheduler implementation only if it fits)

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

**Executed-by**: _(fill at completion)_
**Step-types**: TEST-INTEGRATION, SVC-EDIT (fixes as found), DOCS
**Est-Effort**: half-day time-boxed (~3-4h)

---

## Manual Validation recommendation (refine at execution end)

1. F160's decision table -- your per-test dispositions (the sprint's one guaranteed Harold-decision point).
2. F156's results table review + any flows flagged Harold-interactive (Gmail OAuth on the emulator).
3. F143's touch selection feel on the emulator (long-press/tap-toggle is a UX judgment, not just a test).
4. If F157 implemented: nothing visual -- the build evidence suffices.

## Model summary

Haiku 1 task (F159), Sonnet 6 tasks (F160 judgment-audit, F157 toolchain study, F158 config decision, F143 interaction redesign, F144 architecture evaluation, F156 exploratory walk-through) -- cheapest-first applied per task; no top-tier assignments; escalation triggers stated inline.

**Total Est-Effort**: ~7-10h (roughly 1.5-2 working days), dominated by F156's half-day box and F144's 2-3h box.
