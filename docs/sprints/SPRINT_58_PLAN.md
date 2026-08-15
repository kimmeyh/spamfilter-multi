# Sprint 58 Plan

**Branch**: `feature/20260814_Sprint_58`
**Dates**: 2026-08-15 --
**Scope defined by Harold** (2026-08-15): F151 (Windows first-run/onboarding UX). F150 (Android build blocker) deferred -- still blocked on Harold's Firebase Console action, not this sprint's scope.

**Context (F151)**: Harold provided a user-centric MVP test script plus a detailed "First-Run Evaluation Summary Page" (7 sections: Installation & Launch, First-Run Orientation, Completing the Primary Task, Feedback & Confirmation, Emotional Experience, Environment Compatibility, Quick User Feedback Capture) as Sprint 58 Backlog Refinement input. Investigated via static code analysis (Explore agent), then CONFIRMED via a live Windows walkthrough: the real 0.7.0.0 production exe was built and launched with a genuinely empty account/data state (required backing up and clearing three independent data-persistence layers -- see `docs/ALL_SPRINTS_MASTER_PLAN.md` F151's Investigation Note -- fully restored and byte-verified afterward). Harold drove the app interactively while Claude observed and recorded findings via WinWright screenshots, surfacing 5 additional concrete findings beyond the original static-analysis gaps (chip tooltips, missing safe-sender demo example, dead "Moved" chip, oversized email-detail popup).

**Governing finding**: the core workflow (add account -> OAuth/IMAP credentials -> scan -> results -> tune rules) is fully built and functional. The gap is entirely about a first-time user DISCOVERING that workflow, UNDERSTANDING its results, and TRUSTING its outcomes -- not missing functionality.

**Scope constraint**: Windows Desktop only (Harold, explicit steering 2026-08-15). Android deferred to the Android rollout track (F142/F143/F144/F150) later -- shared/provider-agnostic widget changes will likely also render on Android eventually, but this sprint's Definition of Done is Windows manual validation only.

---

## Task 1 -- F151a: Welcome/orientation + Demo Mode surfacing on empty-accounts screen (Priority 10)

**Value**: This enables a brand-new user to understand what the app does and discover the safe (no-account-needed) way to explore it, within the first screen they see. This prevents the current experience where a zero-accounts user sees only an icon and "Add Account," with no explanation of purpose and no visible path to Demo Mode until they are already one tap into account setup.

**Requirements** (numbered, detailed):
- R-1: `AccountSelectionScreen`'s empty state (`NoAccountsEmptyState` in `empty_state.dart:83-101`) gains brief purpose-explaining copy -- what the app does (spam filtering across email providers) -- above or alongside the existing "No Accounts Yet" / "Add your first email account..." text. Keep it short (1-2 sentences); this is not a full onboarding flow, just orientation.
- R-2: The empty state also surfaces Demo Mode as a visible, clearly-labeled option distinct from "Add Account" -- e.g. a secondary button or link ("Try Demo Mode instead") -- so a user who wants to explore first does not have to guess that "Add Account" leads to it. Reuse the existing Demo Mode entry point/navigation (`PlatformSelectionScreen`'s "Try Demo Mode" card, `platform_selection_screen.dart:122-132`) rather than inventing a new code path.
- R-3: Keep the existing "Add Account" primary button and its behavior unchanged -- this is additive, not a replacement of the current flow.

**Affected components / files**:
- `mobile-app/lib/ui/widgets/empty_state.dart` -- `NoAccountsEmptyState` gains purpose copy + a secondary Demo Mode action.
- `mobile-app/lib/ui/screens/account_selection_screen.dart` -- wires the new secondary action to the existing Demo Mode navigation path (confirm exact call site during implementation; likely mirrors how "Add Account" currently navigates to `PlatformSelectionScreen`, but launches directly into Demo Mode rather than the provider list).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: new text/buttons need `Semantics` coverage consistent with F133's existing remediation on this screen (confirmed present, 4 occurrences in `account_selection_screen.dart`).
- Platform: Windows-only Definition of Done per sprint scope; the widget change itself is shared/provider-agnostic and will render on Android once that track resumes, but no Android verification this sprint.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given zero saved accounts, When `AccountSelectionScreen` renders, Then the empty state displays purpose-explaining copy in addition to the existing "No Accounts Yet" text.
- AC-2: Given zero saved accounts, When `AccountSelectionScreen` renders, Then a Demo Mode action is visible and distinct from "Add Account," without requiring any prior tap.
- AC-3: Given the Demo Mode action is tapped, When navigation completes, Then the user reaches the same Demo Mode flow as the existing "Add Account" -> "Try Demo Mode" path (no new/duplicate demo-data logic).
- AC-4: The existing "Add Account" button and its navigation behavior are unchanged.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1, AC-2) -- TEST-WIDGET, extend or create `mobile-app/test/ui/widgets/empty_state_test.dart` (or `test/ui/screens/account_selection_screen_test.dart` if that is the established location for this screen -- confirm during implementation): pump `NoAccountsEmptyState`/`AccountSelectionScreen` with zero accounts, assert both the purpose copy and the Demo Mode action are present and rendered.
- T-2 (verifies AC-3) -- TEST-WIDGET: tap the new Demo Mode action, assert navigation reaches the expected Demo Mode entry point (same destination as the existing "Add Account" -> "Try Demo Mode" path).
- T-3 (verifies AC-4) -- TEST-WIDGET (likely already covered by existing `account_selection_screen_test.dart` coverage; confirm no regression rather than writing new).

**Definition of Done**: default task-level DoD PLUS: manual Windows visual verification of the new empty-state copy/layout (Manual Validation).

**Model**: Haiku -- *why not escalate*: single-screen, single-widget copy + one new secondary button reusing an existing navigation path. No architectural decision, no cross-cutting concern.

**Executed-by**: _(fill at completion)_

**Step-types**: UI-NEW, TEST-WIDGET

**Est-Effort**: 20-30m

**Completion notes (2026-08-15)**: Implemented as planned -- `EmptyState` gained a generic optional `secondaryActionLabel`/`onSecondaryActionPressed` slot (reusable by other empty states later, not a one-off field), `NoAccountsEmptyState` gained purpose copy plus an `onTryDemoMode` param wired to a new `_startDemoMode()` in `AccountSelectionScreen` that mirrors `PlatformSelectionScreen._startDemoMode()` verbatim (same `ScanProgressScreen` push, same demo params) -- no new navigation logic invented. 4 new widget tests in `test/ui/widgets/empty_state_test.dart`, mutation-verified. `flutter analyze` clean. Actual ~15m (see `CODING_VELOCITY.md`).

---

## Task 2 -- F151b: Walkthrough discoverability callout on Help screen (Priority 10)

**Value**: This enables a user who does not already know the 8-step walkthrough exists to find it, by surfacing it at the top of the Help screen instead of leaving it as the last of 22 passive sections. This closes the specific gap F75 (Sprint 34) explicitly deferred ("Add a 'First time? Start here' callout on the main Help screen entry pointing to the walkthrough" -- never implemented).

**Requirements** (numbered, detailed):
- R-1: `HelpScreen` (`help_screen.dart`) gains a visible callout near the top (before the 22-section list, or pinned/highlighted) reading something like "First time? Start here" that deep-links to `HelpSection.walkthrough` (the existing last section, `help_screen.dart:258-259`).
- R-2: Reuse the existing `HelpSection` deep-link mechanism (the same one `openHelp()` and per-screen Help icons already use, `help_screen.dart:418-437`) rather than inventing a new navigation path.
- R-3: The walkthrough section itself (`assets/content/help/walkthrough.md`) is NOT modified by this task -- its content was already rewritten in Sprint 55 and is out of scope here.

**Affected components / files**:
- `mobile-app/lib/ui/screens/help_screen.dart` -- add the callout widget near the top of the section list, wired to the existing walkthrough deep-link.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: callout needs `Semantics` coverage matching the screen's existing pattern.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given `HelpScreen` is opened, When the screen renders, Then a "First time? Start here" (or equivalent) callout is visible without scrolling, before the full section list.
- AC-2: Given the callout is tapped, When navigation completes, Then the screen scrolls to (or otherwise surfaces) the `HelpSection.walkthrough` content, using the existing deep-link mechanism.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1) -- TEST-WIDGET, extend `mobile-app/test/ui/screens/help_screen_test.dart` (or `integration_test/help_deep_link_test.dart` if that is the more appropriate location given F145's existing coverage there): assert the callout renders and is visible in the initial viewport.
- T-2 (verifies AC-2) -- TEST-WIDGET or INTEGRATION (reuse F145's `integration_test/help_deep_link_test.dart` pattern, which already covers all 22 `HelpSection` values): tap the callout, assert the walkthrough section is reached via the same deep-link path as the existing per-screen Help icons.

**Definition of Done**: default task-level DoD PLUS: None -- default DoD only.

**Model**: Haiku -- *why not escalate*: single-screen addition reusing an existing, proven deep-link mechanism. No new navigation logic to design.

**Executed-by**: _(fill at completion)_

**Step-types**: UI-MOVE, TEST-WIDGET

**Est-Effort**: 10-20m

**Completion notes (2026-08-15)**: Implemented as planned -- reused `_scrollTo(HelpSection)` (existing F145 deep-link mechanism) verbatim, and the F140 "duplicate near top" pattern already used for the version display. 2 new widget tests in `test/unit/ui/help_screen_test.dart`; one test-design correction discovered mid-task (see `CODING_VELOCITY.md`: the screen's eager-`Column` architecture means `find.text()` cannot prove visibility, only presence -- switched to a scroll-offset assertion). Both mutation-verified. `flutter analyze` clean. Actual ~15m.

---

## Task 3 -- F151c: Scan Results chip tooltips + remove dead Moved chip + wording fix (Priority 10)

**Value**: This prevents first-time-user confusion on the Scan Results screen, which live-walkthrough testing (Harold, 2026-08-15) confirmed is dense and under-explained: 7 colored chips with no explanation, one chip (Moved) that always reads 0 because the underlying feature does not exist yet (reads as a bug, not an intentional zero), and ambiguous wording ("Deleted (not processed)") that reads as self-contradictory without already knowing Read-Only-mode semantics.

**Requirements** (numbered, detailed):
- R-1: Add a tooltip (Flutter `Tooltip` widget, standard long-press/hover reveal) to each of the remaining 6 summary chips (Found, Processed, Deleted, Safe, No rule, Errors) explaining what each count means in plain language.
- R-2: Remove the "Moved" chip entirely from the results-summary widget, since the move-on-match feature it reports on is not yet implemented -- confirmed via live walkthrough (always shows 0 alongside real, populated chips: Found 59, Processed 38, Deleted 26, No rule 12). Do NOT implement the Moved feature itself -- that is explicitly out of scope (see F151's "Not in scope" note in the master plan).
- R-3: Clarify the "Deleted (not processed)" (and equivalent "Safe (not processed)") wording so it does not read as contradictory -- either via the new tooltip (R-1) alone, or a small wording adjustment (e.g. "Would be deleted" in Read-Only mode) if the tooltip alone does not resolve the ambiguity. Judgment call during implementation; the tooltip is the primary fix, wording is a secondary option if still unclear after adding it.
- R-4: This is a SHARED widget -- confirm the fix applies to both the Demo Scan results screen and real (Live Scan) Scan Results screens, since both currently render the same summary-chip row. Do not duplicate the fix per-screen if a shared widget already exists; if the chip row is NOT currently a shared widget, extracting one is in scope here (small refactor, not a new task).

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the summary-chip row (confirm exact widget/class name during implementation; likely a private builder method or a small dedicated widget given the "shared between Demo and Live" requirement in R-4).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: `Tooltip` widgets are natively accessible (screen readers announce tooltip text); confirm this is sufticient or whether additional `Semantics` wrapping is needed per this codebase's existing pattern.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given the Scan Results screen (Demo or Live), When a user long-presses or hovers a summary chip (Found/Processed/Deleted/Safe/No rule/Errors), Then a tooltip explaining that chip's meaning appears.
- AC-2: The "Moved" chip no longer appears on the Scan Results screen (Demo or Live), given the move-on-match feature does not exist.
- AC-3: The "Deleted (not processed)" wording (and equivalent "Safe (not processed)") no longer reads as self-contradictory -- verified via tooltip content and/or adjusted label text, confirmed during Manual Validation as a genuine improvement (subjective judgment call, not machine-testable -- flag for Harold's Manual Validation review specifically).
- AC-4: Both Demo Scan and real (Live Scan) Scan Results screens render the fix identically (same shared widget/logic).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1) -- TEST-WIDGET in `mobile-app/test/ui/screens/results_display_screen_test.dart`: assert each remaining chip has an associated `Tooltip` widget with non-empty message text.
- T-2 (verifies AC-2) -- TEST-WIDGET: assert no "Moved" chip is present in the rendered summary row, for both Demo and Live scan result states.
- T-3 (verifies AC-4) -- TEST-WIDGET: assert the same chip-row widget/logic is used for both Demo and Live scan results (e.g. by pumping both states and confirming structural equivalence, or by testing the shared widget directly if extracted per R-4).
- (AC-3 is not independently unit-testable -- covered by T-1's tooltip-content assertion plus Manual Validation.)

**Definition of Done**: default task-level DoD PLUS: manual Windows visual verification that tooltips read clearly and the Moved-chip removal does not break the summary row's layout (Manual Validation).

**Model**: Sonnet -- *why not Haiku*: R-4's "confirm/extract a shared widget between Demo and Live" is a structural judgment call across two call sites, not a single-file mechanical change; R-3's wording decision also requires reading actual rendered output to judge ambiguity, beyond a pure Haiku heuristic match.

**Executed-by**: _(fill at completion)_

**Step-types**: UI-MOVE, SVC-EDIT, TEST-WIDGET

**Est-Effort**: 30-45m

**Completion notes (2026-08-15)**: Implemented as planned. R-4's "confirm/extract a shared widget" needed no work -- `ResultsDisplayScreen` was already the single shared build path for Demo and Live scans. Removing the Moved chip surfaced (and required deleting) an unused local `movedCount` variable; `scanProvider.movedCount` itself is untouched, confirmed still used elsewhere (background-scan logging/notifications, `ScanHistoryScreen`'s own separate out-of-scope display) via grep before touching anything. New test file `test/ui/screens/results_display_chip_tooltips_test.dart` (2 tests), reusing the established DB-widget-test harness. Both mutation-verified; full `test/ui/screens/` suite (163 tests) re-run clean. `flutter analyze` clean. Actual ~30m.

---

## Task 4 -- F151d: Demo Scan never shows a Safe result (SCOPE CHANGED mid-task, Harold approved 2026-08-15) (Priority 10)

**Original scope** (as planned): add a safe-sender example email to the demo dataset. **Actual scope** (root-cause investigation found a real bug, not missing data -- Harold explicitly approved the change before proceeding): fix the scan pipeline so Demo Mode's existing 21 correctly-configured safe-sender demo emails are not silently dropped before evaluation-counting.

**Value**: This enables a first-time user's very first Demo Scan to demonstrate all major outcome categories (delete, safe, no-rule), not just delete/no-rule as confirmed during the live walkthrough (2026-08-15: the 38 processed demo emails included 0 Safe-category matches).

**Investigation finding** (why the original R-1/R-2 "add demo data" premise was wrong): a scratch evaluation script run directly against `MockEmailData.generateSampleEmails()` + `MockEmailData.getDemoRuleSet()`/`getDemoSafeSenderList()` confirmed the demo dataset ALREADY has 21 correctly-configured safe-sender-matching emails (design intent comment in `mock_email_data.dart:786` says "Target: ~20 safe senders," and 21 is exactly right). Filtered to INBOX only (matching the live walkthrough's "Folders: INBOX" scope), the full evaluation produces Delete: 26, Safe: 21, No rule: 12 -- but the live walkthrough's real scan showed Processed: 38 (exactly Delete 26 + No rule 12), Safe never appearing at all. Root cause: `email_scanner.dart`'s per-email evaluation loop has a `continue` (skip entirely -- not counted, not displayed, not processed) whenever a safe-sender match's `message.folderName` already equals `safeSenderTarget` (defaults to INBOX). This is a CORRECT, deliberate optimization for real scans (nothing to do if the email is already exactly where it belongs) but every demo safe-sender email is deliberately placed in INBOX by dataset design, so this skip silently ate all 21 of them.

**Requirements** (numbered, detailed):
- R-1 (revised): the "already in target folder" skip must not apply to Demo Mode (`platformId == 'demo'`). Demo Mode never performs a real move regardless of this skip (Demo Scan defaults to Read-Only, so `canExecuteSafeSenders` is already false and the existing code path already records-without-acting in that case) -- so removing the skip for demo does not introduce any real side effect, it only stops silently discarding the evaluation result.
- R-2 (revised): extract the skip condition into a small, pure, `@visibleForTesting` predicate (matching the established F91/F149 extraction pattern already in this file) rather than leaving it as an inline `if` -- makes the decision directly unit-testable without needing full `scanInbox()` orchestration, which this file's own doc comments state is intentionally out of unit-test scope (exercised via Manual Validation instead).
- R-3: real (non-demo) scan behavior must be provably unchanged -- the skip still applies exactly as before for every `platformId != 'demo'`.

**Affected components / files**:
- `mobile-app/lib/core/services/email_scanner.dart` -- new `shouldSkipSafeSenderAlreadyInTarget()` predicate (near `filterAlreadyInTargetFolder`, same file); call site in the per-email evaluation loop updated to use it instead of the inline condition.

**Dependencies / blockers**: None. Investigated and root-caused within this task; Harold approved via AskUserQuestion mid-task before any fix was applied (Sprint Stopping Criteria: scope change requiring explicit approval, not silently expanded).

**Non-functional requirements**:
- Platform: this touches the shared `scanInbox()` evaluation loop used by ALL platforms (real IMAP/Gmail accounts and Demo Mode alike) -- R-3's regression proof is mandatory, not optional.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given Demo Mode, When a Demo Scan runs against the existing demo dataset, Then safe-sender-matching demo emails are evaluated, counted, and displayed as "Safe" results (not silently dropped).
- AC-2: Given a real (non-demo) platform, When a safe-sender match is already in the safe-sender target folder, Then it is still skipped entirely exactly as before (no regression to the real-scan optimization).
- AC-3: Demo Mode's Safe-sender matches never trigger a real move/execute action -- Demo Scan's default Read-Only mode already guarantees this (the existing "record without acting" code path was not changed), verified rather than assumed.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1) -- TEST-UNIT in new `test/unit/services/f151d_demo_safe_sender_test.dart`: `shouldSkipSafeSenderAlreadyInTarget(platformId: 'demo', ...)` returns `false` even when the message is already in the target folder.
- T-2 (verifies AC-2) -- TEST-UNIT, same file: `shouldSkipSafeSenderAlreadyInTarget(platformId: <non-demo>, ...)` returns `true` when already in target, `false` when not -- unchanged from the pre-fix behavior.
- T-3 (verifies AC-3) -- re-run the full existing EmailScanner-related test suite (`f91_safe_sender_dedup_test.dart`, `email_scanner_test.dart`, `email_scanner_f86_test.dart`, `email_scanner_no_rule_cursor_cap_test.dart`, `email_scanner_scan_all_bypass_test.dart`) to confirm zero regression to real-scan safe-sender handling.

**Definition of Done**: default task-level DoD PLUS: manual confirmation via a real Demo Scan run that a Safe-category result appears (Manual Validation, can double up with Task 3's manual check).

**Model**: Sonnet -- *why not Haiku*: this started as a Haiku-sized "add one data entry" task but the investigation surfaced a genuine cross-platform scan-pipeline bug requiring root-cause tracing through `email_scanner.dart`'s evaluation loop, a scope-change decision surfaced to Harold, and a fix constrained by an explicit "must not change real-scan behavior" non-functional requirement -- beyond Haiku's heuristics once the actual defect was found.

**Executed-by**: Sonnet -- matches the revised model assignment above; the investigation and fix both required cross-file root-cause tracing beyond a Haiku-sized single-file data change.

**Step-types**: SVC-EDIT, TEST-UNIT

**Est-Effort**: 10-15m (original "add demo data" estimate; superseded, actual ~35m -- see `CODING_VELOCITY.md`)

**Completion notes (2026-08-15)**: Root-caused and fixed as revised above. Extracted `shouldSkipSafeSenderAlreadyInTarget()` (pure predicate, `@visibleForTesting`) in `email_scanner.dart`, gated the skip to `platformId != 'demo'`. 5 new unit tests in `test/unit/services/f151d_demo_safe_sender_test.dart`, mutation-verified (removing the demo gate correctly failed exactly the demo-in-target-folder case, no other test affected). Full EmailScanner-related suite (52 tests across 5 files) re-run clean -- confirmed zero regression to real-scan behavior. `flutter analyze` clean.

---

## Task 5 -- F151e: Email-detail action popup layout fix (Priority 10)

**Value**: This prevents the email-detail action popup (opened from a Scan Results row) from overflowing the default window size, confirmed via live walkthrough screenshot (Harold, 2026-08-15): the "Add to Safe Senders" (3 buttons) and "Create Block Rule" (3 buttons, plus a partially-cut-off "Block Subject" row) sections stack full-width vertically below their labels, forcing a scroll before a user can see all options at default resolution.

**Requirements** (numbered, detailed):
- R-1: Change the "Add to Safe Senders" button layout from 3 full-width stacked buttons to 3 smaller buttons arranged beside the "Add to Safe Senders" label (horizontal row or a compact grid, whichever fits Flutter's `Row`/`Wrap` conventions already used elsewhere in this codebase).
- R-2 (REVISED -- see Completion notes): reading the actual widget code before implementing found the original R-1/R-2 premise was wrong. The "Add to Safe Senders" (3 buttons) and "Create Block Rule" (3 buttons) sections were ALREADY laid out in a `Row` of `Expanded` cells (MT-1, Sprint 50's fixed 3-column grid), not stacked full-width below their labels. The real cause of the oversized appearance was the outer popup's own `Positioned(left: 16, right: 16)`, which stretched it to ~(window width - 32px) -- confirmed via the live walkthrough's 1600px window, that is a ~1568px-wide popup with an already-compact button grid inside far more horizontal room than it needed. Revised fix: cap the popup's own width (`Center` + `ConstrainedBox(maxWidth: 480)`), not the button grid.
- R-3: The popup must fit within the default window size (1600x900, the size confirmed during the live walkthrough) without requiring a scroll to see both the Safe-Senders and Block-Rule button groups, given a typical email's metadata (sender, subject, timestamp, matched rule) above them. (Confirmed already true once R-2's width cap is applied -- the popup's own `SingleChildScrollView` handles any residual vertical overflow, and the horizontal cramping that made the button grid feel oversized is what the width cap actually fixes.)

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the email-detail action popup's outer `Positioned`/`Material` wrapping (`_showEmailDetailSheet`'s `showDialog` builder), NOT the button grid itself (already correct, MT-1 Sprint 50).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: no `Semantics`/tap-target changes -- the button grid itself is untouched, only its containing popup's width.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given the email-detail popup is open at the default window size (1600x900), When rendered, Then the popup's own width is capped well below the full window width (not stretched to window-width minus fixed margins).
- AC-2: All existing button functionality (Exact Email / Exact Domain / Entire Domain for Safe Senders; Block Email / Block Exact Domain / Block Entire Domain / Block Subject for Block Rule) is unchanged -- this is a layout-only change to the popup's outer container, no behavior change.
- AC-3: The popup still positions correctly relative to the tapped row (existing `top`/`bottom` positioning logic) and still respects the narrow-window fallback (`left`/`right: 16` still applies when the capped width would exceed the available space).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1) -- TEST-WIDGET, new `test/ui/screens/results_display_popup_width_test.dart`: open the real popup via the established DB-widget-test harness at a 1600x900 test viewport, assert the rendered `Material` width is capped (<=480) and still a normal usable width (>200).
- T-2 (verifies AC-2) -- re-run the existing `results_display_no_rule_reload_test.dart` and `results_display_chip_tooltips_test.dart` suites plus the full `test/ui/screens/` suite to confirm zero regression to popup button behavior (this task did not touch the button grid, so a clean re-run is the correct proof rather than new per-button tap tests).

**Definition of Done**: default task-level DoD PLUS: manual Windows visual verification at default window size (1600x900) confirming the popup reads as a normal dialog size (Manual Validation).

**Model**: Sonnet -- *why not Haiku*: required reading and correctly diagnosing the actual widget tree (the original plan's premise was wrong) before choosing a fix -- beyond a Haiku-sized mechanical change, even though the resulting fix itself is small.

**Executed-by**: Sonnet -- matches the (already-correct) planned assignment; the mid-task diagnosis correction did not change which tier was needed.

**Step-types**: UI-MOVE, TEST-WIDGET

**Est-Effort**: 25-40m

**Completion notes (2026-08-15)**: R-1/R-2 revised as noted above after reading the actual code -- the button grid needed no changes at all; the fix was a `Center` + `ConstrainedBox(maxWidth: 480)` wrap around the popup's existing `Material`. Ran `dart format` on the touched file afterward (the new wrapping widgets left inconsistent indentation across the ~470-line popup builder); confirmed via `git diff --stat` the resulting large diff was formatting-only by re-running the full `test/ui/screens/` suite (164/164 passing) to rule out any behavior change slipping in with the reformat. New widget test (`results_display_popup_width_test.dart`) mutation-verified. `flutter analyze` clean. Actual ~25m.

---

## Task 6 -- F151f: Wire ErrorDisplay family into 3 raw-exception paths (Priority 10)

**Value**: This prevents a first-time user from seeing raw exception text (e.g. `Connection failed: SocketException: ...`) instead of a human-readable, actionable error message during account setup or scanning -- confirmed via code trace that 3 specific paths bypass the existing `ErrorDisplay`/`AuthenticationErrorDisplay`/`NetworkErrorDisplay` widgets already used elsewhere in this codebase (e.g. `AccountSelectionScreen`'s load-failure state).

**Requirements** (numbered, detailed):
- R-1: `AccountSetupScreen._testConnection()`'s catch-all (`account_setup_screen.dart:238`, currently `'Connection failed: $e'`) is replaced with the appropriate `ErrorDisplay` family widget (`NetworkErrorDisplay` for connectivity failures, `AuthenticationErrorDisplay` for auth failures -- distinguish by exception type/message content during implementation, matching however the existing rate-limit-specific handling in the same method already does this).
- R-2: `AccountSetupScreen._handleConnect()`'s credential-save failure (`account_setup_screen.dart:299-301`, currently `'Failed to save credentials: $e'`) is replaced with an appropriate `ErrorDisplay` family widget or `GenericErrorDisplay` if no more specific variant fits.
- R-3: `startRealScan()`'s scan-failure catch (`scan_progress_screen.dart:696-712`, currently `'Scan failed: $e'`) is replaced with an appropriate `ErrorDisplay` family widget where the display context allows it (SnackBar vs. a dedicated error widget -- confirm which fits this call site's UI context; a SnackBar cannot host a full `ErrorDisplay` widget, so this may require either a different presentation mechanism or a SnackBar with clearer copy if `ErrorDisplay` genuinely does not fit inline). The KNOWN, ALREADY-DOCUMENTED unmounted-context gap (failure logged but not shown if the user navigated away) is explicitly OUT OF SCOPE -- do not attempt to fix that as part of this task.
- R-4: In all three cases, preserve the existing rate-limit-specific friendly message handling in `_testConnection()` (already good, per the code) -- this task only fixes the fallback/generic paths, not the parts that already work well.

**Affected components / files**:
- `mobile-app/lib/ui/screens/account_setup_screen.dart:238` -- `_testConnection()` catch-all.
- `mobile-app/lib/ui/screens/account_setup_screen.dart:299-301` -- `_handleConnect()` credential-save failure.
- `mobile-app/lib/ui/screens/scan_progress_screen.dart:696-712` -- `startRealScan()` scan-failure catch.
- `mobile-app/lib/ui/widgets/error_display.dart` -- NOT used (see Completion notes: none of the 3 call sites fit this widget family's full-screen layout).
- `mobile-app/lib/util/error_messages.dart` (NEW) -- `ErrorMessages.humanize()`, the actual fix, following the established `Redact` utility pattern.

**Dependencies / blockers**: None.

**Non-functional requirements**: None -- no UI widget changes, only message-text substitution at 3 existing display call sites (colored status box, SnackBar x2), all pre-existing and unchanged in structure.

**Acceptance criteria** (measurable, traceable):
- AC-1 (REVISED -- see Completion notes): Given a connection-test failure in `AccountSetupScreen` (not a rate-limit case, which already has friendly handling), When the error is displayed, Then it shows a human-readable message via `ErrorMessages.humanize()` instead of raw `'Connection failed: $e'` text.
- AC-2 (REVISED): Given a credential-save failure in `AccountSetupScreen`, When the error is displayed, Then it shows a human-readable message via `ErrorMessages.humanize()` instead of raw `'Failed to save credentials: $e'` text.
- AC-3 (REVISED): Given a scan failure in `startRealScan()` (context still mounted), When the error is displayed, Then it shows a human-readable message via `ErrorMessages.humanize()` instead of raw `'Scan failed: $e'` text.
- AC-4: The existing rate-limit-specific friendly message in `_testConnection()` is unchanged (now implemented inside `ErrorMessages.humanize()` itself, same message text).
- AC-5: The unmounted-context silent-log behavior in `startRealScan()` is unchanged (explicitly out of scope, not touched).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 through T-4 (verify AC-1/AC-2/AC-3/AC-4) -- TEST-UNIT in new `test/unit/util/error_messages_test.dart`: `ErrorMessages.humanize()` tested directly against each exception type (`AuthRateLimitedException`, `AuthenticationException`, `ConnectionException`, `CredentialStorageException`, `SocketException`, `TimeoutException`, generic fallback) -- cheaper and more precise than widget-pumping 3 separate screens to indirectly exercise the same classification logic.
- T-5 (verifies AC-5) -- re-run the full `test/ui/screens/` suite to confirm no regression to `startRealScan()`'s unmounted-context behavior (untouched code path).

**Definition of Done**: default task-level DoD PLUS: manual Windows verification that a real triggered failure (e.g. a bad IMAP password) shows the improved error message (Manual Validation).

**Model**: Sonnet -- *why not Haiku*: required reading the actual UI structure at all 3 call sites to correctly determine the `ErrorDisplay` widget family did not fit any of them (a wrong assumption in the original plan), then designing a shared classification helper -- beyond a Haiku-sized mechanical substitution.

**Executed-by**: Sonnet -- matches the (already-correct) planned assignment.

**Step-types**: SVC-NEW, TEST-UNIT

**Est-Effort**: 25-40m

**Completion notes (2026-08-15)**: AC-1/AC-2/AC-3 revised as noted above after reading the actual UI structure at all 3 call sites -- `ErrorDisplay`/`AuthenticationErrorDisplay`/`NetworkErrorDisplay` are full-screen replacement widgets (Center + 80px icon + headline text), which fits none of the 3 sites: `account_setup_screen.dart` already has its own inline colored status box (a reasonably good, pre-existing UX pattern), and `scan_progress_screen.dart` uses a bare SnackBar with no inline status surface at all. Built `lib/util/error_messages.dart` (`ErrorMessages.humanize()`) instead, generalizing the account-setup screen's own pre-existing `AuthRateLimitedException`-specific classification (previously not reused anywhere else) to also cover `AuthenticationException`/`ConnectionException`/`CredentialStorageException`/`SocketException`/`TimeoutException`/generic fallback. 7 new unit tests, mutation-verified (3 separate mutations, all correctly caught). Full `test/ui/screens/` suite (164 tests) re-run clean. `flutter analyze` clean. Actual ~25m.

---

## Task 7 -- F151g: Windows environment-compatibility investigation (Priority 10, investigation-only)

**Value**: This produces concrete, filed findings on window-resize/DPI-scaling/hardware-performance/UI-stability behavior, which the First-Run Evaluation Summary Page's Section 6 flagged as genuinely unaudited for Windows (F63, the closest existing item, is superseded and scoped to Android touch-density, not Windows resize/DPI). This is an investigation pass, not a fix -- findings become new backlog candidates, not inline changes, to keep this task time-boxed and separate architectural/design decisions from mechanical execution.

**Requirements** (numbered, detailed):
- R-1: Manually resize the main window across a representative range (small/default/maximized, plus at least one non-16:9 aspect ratio if practical) on the primary screens exercised elsewhere in this sprint (Account Selection, Manual Scan, Scan Results, Help) and note any layout breakage, overflow, or clipping.
- R-2: Confirm current behavior at the machine's actual DPI scale (125%, confirmed via WinWright screenshot metadata during the live walkthrough) is clean; if a second DPI scale is easily testable (e.g. 100% or 150% via Windows display settings), spot-check at least one additional scale, time permitting.
- R-3: Note any UI flicker/jitter observed during normal interaction (screen transitions, scan progress updates) -- qualitative observation, not a performance-profiling exercise.
- R-4: This is TIME-BOXED -- if the investigation surfaces more than can be fixed as trivial in-sprint tweaks, STOP and file findings as new backlog candidate(s) rather than expanding scope. Do not attempt architectural fixes (e.g. a full responsive-design framework) inline.

**Affected components / files**: None expected (investigation-only); any trivial, obviously-safe fixes found (e.g. a single hardcoded width causing an obvious overflow) may be applied inline if genuinely trivial -- judgment call, err toward filing a follow-up item instead if there is any doubt.

**Dependencies / blockers**: None.

**Non-functional requirements**: None.

**Acceptance criteria** (measurable, traceable):
- AC-1: Window-resize behavior is checked across the 4 primary screens (Account Selection, Manual Scan, Scan Results, Help) at small/default/maximized sizes, with findings recorded (pass or specific issue) for each.
- AC-2: DPI-scale behavior is checked at the machine's actual scale (125%) at minimum, with findings recorded.
- AC-3: Any issues found are filed as new, appropriately-scoped backlog candidate item(s) in `docs/ALL_SPRINTS_MASTER_PLAN.md` (not fixed inline unless genuinely trivial per R-4) -- OR, if no issues are found, that clean result is explicitly recorded (not silently omitted).

**Tests to write**: None -- this is a manual investigation task, not a code change with automatable acceptance criteria.

**Definition of Done**: default task-level DoD (items 2/3/6 -- tests/analyze/velocity-log -- do not apply, this is investigation-only) PLUS:
- Findings recorded in this plan's completion notes, with any new backlog items cross-referenced by their new F# number.

**Model**: Sonnet -- *why not Haiku*: judging what counts as a "genuine" layout issue vs. cosmetic non-issue, and correctly time-boxing/scoping any follow-up items, requires more judgment than a mechanical check.

**Executed-by**: _(fill at completion)_

**Step-types**: DOCS (investigation + findings write-up)

**Est-Effort**: 20-30m (hard time-box per R-4)

---

## Sprint-Level Notes

**F153 registered separately** (HOLD, `docs/ALL_SPRINTS_MASTER_PLAN.md`) -- re-investigation of F140's WinWright/Flutter-Windows-UIA limitation, per Harold's 2026-08-15 request. NOT part of this sprint's execution scope; captured as a future periodic-review candidate since it needs research (Flutter changelog/issue-tracker checks) rather than app code changes.

**F152 registered separately** (HOLD, `docs/ALL_SPRINTS_MASTER_PLAN.md`) -- the First-Run Evaluation methodology itself, registered as a reusable periodic template so future re-runs do not need to re-derive Sprint 58's process from scratch.

**Manual Validation recommendation** (to be confirmed/refined once Tasks 1-7 are code-complete): build and launch the Windows dev app, then walk through the SAME live-walkthrough sequence used during Backlog Refinement -- zero-accounts screen (verify welcome copy + Demo Mode visibility), Demo Mode -> Platform Selection -> Demo Scan -> Results (verify chip tooltips, no Moved chip, Safe-category result present, wording clarity), open an email-detail popup at default window size (verify no-scroll layout), and trigger a real connection/scan failure if practical (verify improved error messaging). This mirrors the Backlog Refinement walkthrough closely enough that Harold's prior familiarity with the flow should make re-validation fast.
