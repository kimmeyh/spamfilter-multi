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

**Executed-by**: _(fill at completion)_
**Step-types**: DATA (external config), DOCS
**Est-Effort**: 30-60m (interactive; depends on console round-trips)

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

**Executed-by**: _(fill at completion)_
**Step-types**: WINWRIGHT-DISCOVERY, DOCS
**Est-Effort**: 30-45m (time-boxed)

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

**Executed-by**: _(fill at completion)_
**Step-types**: UI-MOVE (strings), TEST-UNIT, CONTENT, DOCS
**Est-Effort**: 20-30m

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

**Executed-by**: _(fill at completion)_
**Step-types**: CONTENT, UI-MOVE, TEST-WIDGET, TEST-INTEGRATION
**Est-Effort**: 45-60m

---

## Execution order and Manual Validation

**Order**: Task 1 (F150, interactive -- Harold available) -> Task 2 (F153) -> Task 3 (F155 rename) -> Task 4 (F154 help section).

**Manual Validation recommendation** (refine at execution end): (1) review the new Review No Rule Items help content (explicit R-2 ask); (2) verify the rename on every screen surface (tooltips, screen title, help text); (3) if F150 lands, optionally eyeball the app on the Android emulator (F142's deferred visual check); (4) F153's outcome is docs -- review the corrected WinWright capability statements.

**Model summary**: Haiku 1 task (F155), Sonnet 3 tasks (F150 interactive-external, F153 investigation, F154 content) -- cheapest-first applied; no top-tier tasks.
**Total Est-Effort**: ~125-195m plus Harold-dependent console round-trips.
