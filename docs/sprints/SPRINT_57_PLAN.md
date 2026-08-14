# Sprint 57 Plan

**Branch**: `feature/20260813_Sprint_57`
**Dates**: 2026-08-13 --
**Scope defined by Harold** (2026-08-13, expanded 2026-08-14): F142 (Android navigation model) AND F149 (safe-sender Inbox/Bulk oscillation bug). F143 and F144 are explicitly tagged for the NEXT sprint, not this one -- both depend on F142 landing first.

**Context (F142)**: Sprint 54's F141 Android/Google Play deep dive found that `MainNavigationScreen`'s bottom-nav shell has 2 of its 3 tabs as dead-end `_PlaceholderScreen`s ("Manage rules from the Account Details screen" / "Configure account settings from Account Details screen") -- scaffolding that predates and diverges from the Sprint 51/52 desktop navigation overhaul (`SelectedAccountProvider` session-scoped account context, `StandardAppBarActions` canonical AppBar-icon order, F135's `NoRuleReviewScreen`-as-default pattern). Harold's governing direction (2026-08-03): Windows' current architecture takes precedence; Android should adopt the same pattern, not be preserved as-is or given a separate bespoke design.

**Context (F149)**: Harold reported (2026-08-13) live production duplicates -- safe-sender messages oscillating between Inbox and Bulk/Spam on the AOL account. Root cause clarified by Harold: AOL's own Outlook-side account rules independently demote any Inbox message not from an AOL/Outlook-defined safe sender to Bulk, entirely outside this app's control; this app then sees the same message as one of ITS OWN safe senders and promotes it back to Inbox, fighting AOL's rule every scan cycle. Harold's stated expectation: the app should not re-promote a safe-sender message to Inbox if it is already there, or if a copy of it already exists there.

---

## Task 1 -- F142: Android navigation model -- adopt desktop's shared AppBar-icon + session-account pattern (Priority 10)

**Value**: This enables Android reaching the same default screen (`NoRuleReviewScreen`, the app's core cross-account workflow) and the same session-scoped account UX desktop users already have. This prevents Android users from hitting 2 non-functional dead-end tabs, which currently makes the Android build feel broken/incomplete relative to desktop.

**Requirements** (numbered, detailed):
- R-1: Remove `MainNavigationScreen`'s `Platform.isAndroid` bottom-navigation branch (the `NavigationBar` + `_screens` list backing "Accounts" / "Rules" / "Settings" tabs, where "Rules" and "Settings" are `_PlaceholderScreen`s). Android should fall through to the SAME decision logic the desktop `else` branch already uses (`_DesktopDefaultScreen` -> `desktopDefaultScreenFor(hasAccounts:)` -> `NoRuleReviewScreen` when accounts exist, `AccountSelectionScreen` when they do not).
- R-2: Because `desktopDefaultScreenFor()` (`main_navigation_screen.dart:154-164`) is a pure, `@visibleForTesting` function already independent of any platform check, R-1 should NOT require inventing new decision logic -- only removing the `if (Platform.isAndroid) { ... } else { ... }` branch structure so BOTH platforms take the path currently labeled `else`. Confirm during implementation whether the `_DesktopDefaultScreen`/`desktopDefaultScreenFor` naming should be updated to drop "Desktop" now that Android shares it, or left as-is with an updated doc comment -- Haiku/Sonnet judgment call, not a blocking decision.
- R-3 (sequencing decision, must be resolved and recorded, not silently defaulted): `StandardAppBarActions.build()` gates the "Review No Rule Items" AppBar icon to `Platform.isWindows` (`standard_app_bar_actions.dart:139`), with the code comment explicitly noting "Windows-desktop scoped, matching the existing F112/F39 entry points." F143 (next sprint, not this one) is what adapts `NoRuleReviewScreen`'s multi-item SELECTION mechanism for touch (the screen currently reads `isControlPressed`/`isShiftPressed` and opens a right-click context menu, neither of which has a touch equivalent). Decide: (a) extend the icon to Android now, accepting that multi-select will not work correctly on touch until F143 lands, or (b) leave it Windows-gated and let Android reach `NoRuleReviewScreen` only via the R-1 default-screen path (view-only / single-tap actions still functional, just no working bulk-select). Recommendation: (b) -- avoid shipping a visibly broken selection interaction; R-1's default-screen routing already gets Android users to the screen without needing the AppBar icon. Surface this recommendation to Harold at Manual Validation if not already confirmed during planning approval.
- R-4: Confirm no other code path assumes `MainNavigationScreen`'s Android branch exists (e.g., any test, deep link, or navigation helper hardcoding the old bottom-nav route). Grep `main_navigation_screen.dart` callers and `_screens`/`_destinations` references before removing.

**Affected components / files**:
- `mobile-app/lib/ui/screens/main_navigation_screen.dart` -- remove the `Platform.isAndroid` branch and its backing `_destinations`/`_screens`/`_onDestinationSelected`/`_PlaceholderScreen` (all now dead once the branch is removed); Android and desktop both render `_DesktopDefaultScreen()`.
- `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart:139` -- the `Platform.isWindows` gate on the "Review No Rule Items" icon; per R-3, likely left unchanged (recommendation is to keep it Windows-only this sprint), but the decision must be explicit in the plan completion notes either way.
- `mobile-app/test/ui/screens/desktop_default_screen_test.dart` -- existing coverage exercises the (now-shared) default-screen decision logic on the host OS; per T-2 below, needs a companion Android-branch-specific case.

**Dependencies / blockers**:
- None to scope. F143 (touch-adapted No-Rule Review selection) and F144 (Android background scanning re-evaluation) both depend on this landing first -- explicitly tagged for Sprint 58, not bundled here.

**Non-functional requirements**:
- Platform: this is an Android-Flutter-layer change; no native Android code, no `build.gradle.kts`/manifest changes expected. Desktop (Windows) behavior must be provably unchanged (the desktop `else` branch's logic is being reused verbatim, not modified).
- Account-scoping: `SelectedAccountProvider` is already registered app-wide (unconditional `ChangeNotifierProvider` in `main.dart:408-410`, not platform-gated) and already implements the lazy-picker session-scoped model this task needs -- confirmed during planning research, no changes needed to the provider itself.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given an Android build with >=1 saved account, When the app launches, Then the Android device shows the SAME `NoRuleReviewScreen` the Windows desktop build shows as its default, reached via the same `_DesktopDefaultScreen`/`desktopDefaultScreenFor` decision path (not a separate Android-specific code path).
- AC-2: Given an Android build with 0 saved accounts, When the app launches, Then the Android device shows `AccountSelectionScreen` (same as desktop's empty-account behavior).
- AC-3: The `Platform.isAndroid` bottom-navigation branch, its `NavigationBar`/`_destinations`/`_screens` list, and the two `_PlaceholderScreen` instances are removed from `main_navigation_screen.dart` -- confirmed by their absence (grep clean) and by AC-1/AC-2 passing without them.
- AC-4: The R-3 sequencing decision (extend the No-Rule-Review AppBar icon to Android now, or leave Windows-gated) is explicitly recorded in this plan's completion notes with the reasoning, not left as an unstated side effect of the code change.
- AC-5: `flutter analyze` clean; full existing test suite passes unchanged (no desktop-behavior regression).

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1, AC-2) -- TEST-WIDGET, extend `mobile-app/test/ui/screens/desktop_default_screen_test.dart`: the existing "WIRING: MainNavigationScreen..." test pumps the real screen and only exercises whatever `Platform.isX` is true on the test host (Windows for `flutter test`). Since `dart:io.Platform.isAndroid` cannot be overridden in a widget test without an injectable seam, and this codebase has no existing pattern for that (confirmed absent during planning research), the practical choice is to test `desktopDefaultScreenFor()` (the pure decision function, already `@visibleForTesting` and platform-independent) directly for both the has-accounts and no-accounts cases -- this proves the DECISION logic is correct and platform-agnostic, which is what R-1/R-2 actually change. A true device-level confirmation that Android literally reaches this code path is a MANUAL verification (T-3), not a unit/widget test, since faking `Platform.isAndroid` would require production-code changes out of scope for this task.
- T-2 (verifies AC-3) -- TEST-STATIC (grep-based, matching this codebase's existing policy-gate pattern in `test/policy/`): assert `main_navigation_screen.dart` no longer contains `Platform.isAndroid`, `_PlaceholderScreen`, or `NavigationBar` -- a source-text gate proving the dead code was actually removed, not just unreachable. Pair with T-1's behavior test per the project's "source gates prove existence, not behavior" standing lesson.
- T-3 (verifies AC-1, AC-2 end-to-end on real Android) -- MANUAL, per Harold's 2026-08-12 tooling decision (Android Studio Emulator, Google Play system image already installed at `C:\Android\android-sdk`): build and run on the emulator with both a populated and an empty account list, confirm the SAME default-screen behavior as the Windows desktop build. This is the Manual Validation step for this sprint, not optional.
- T-4 (verifies AC-4) -- DOCS: record the R-3 decision and its reasoning in this plan's completion notes section (added at task completion).

**Definition of Done**: default task-level DoD PLUS:
- T-3's manual Android-emulator verification is actually performed and its result (pass/fail, with what was observed) recorded before this task is considered done -- this is genuinely new platform-branching logic with no existing test seam for direct automated coverage of the Android path, so the manual check is the only end-to-end proof available this sprint.
- The R-3 sequencing decision is recorded explicitly, with reasoning, before Manual Validation begins (not deferred to retrospective).

**Model**: Sonnet -- *why not Haiku*: this removes and restructures existing platform-branching UI code that other screens/tests implicitly depend on (R-4's "confirm no other code path assumes the old branch exists" is a cross-cutting concern, not a single-file mechanical change), and requires the R-3 sequencing judgment call against F143's not-yet-built scope -- beyond Haiku's heuristics for well-defined single-file work. Not escalated to Fable/Opus: the target pattern (`_DesktopDefaultScreen`) already exists and is proven in production; this is applying an established pattern to a second platform, not designing a new one.

**Executed-by**: _(fill at completion)_

**Step-types**: UI-NEW (adapting the shared default-screen pattern to a second platform counts as new integration work, not a move), SVC-EDIT (removing the dead branch), TEST-WIDGET (T-1), HOOK-adjacent (T-2's source-text gate, following the `test/policy/` pattern)

**Est-Effort**: `[no-history]` -- no prior sample of "remove an Android-specific placeholder branch and adopt an existing desktop pattern" in `CODING_VELOCITY.md`'s Estimate Table. Time-boxed per the project's `[no-history]` convention rather than inventing a range. Rough expectation based on file scope (1 primary file edit, 1 test file extension, 1 new policy-gate test, no native code): likely in the same band as a UI-NEW item (30-40m Est-Effort per the table's F25/F35/F37 median) plus T-3's manual emulator round-trip (Est-Wall only, not Est-Effort -- emulator cold boot is ~22s per Harold's 2026-08-12 tooling decision, plus install/launch/verify time).

_**Risk & rollback**_: Low-Medium. Risk: R-4's cross-cutting check (confirming nothing else references the old Android branch) could surface an unexpected dependency, expanding scope; mitigation is to grep BEFORE deleting, not after. Rollback: this is a subtractive change to one screen file plus a possible one-line revert in `standard_app_bar_actions.dart` if R-3 is later reconsidered -- `git revert` fully restores the placeholder bottom-nav shell if needed, though Harold's governing direction (Sprint 54) makes reverting to the old Android-first pattern an unlikely outcome regardless of this task's result.

_**Decision-class interrupts**_: R-3 (whether to extend the No-Rule-Review AppBar icon to Android this sprint) is presented above with a recommendation (keep Windows-gated) but is NOT unilaterally decided -- confirm with Harold at plan approval or flag explicitly at Manual Validation if approval does not address it. This is not a Class-1/2/3 architecture/development-decision change in the CLAUDE.md sense (it is squarely within the already-approved F142 scope and Sprint 54's governing direction), but it is exactly the kind of "small design choice with a stated recommendation" the augmented card template exists to surface rather than bury in a commit.

---

## Task 2 -- F149: Safe-sender messages no longer re-promoted to Inbox when already present or duplicated there (Priority 10)

**Value**: This prevents an active, user-visible production defect -- safe-sender messages repeatedly oscillating between Inbox and Bulk/Spam on the AOL account, producing duplicate-feeling clutter in the Inbox and undermining trust that safe senders "just work."

**Requirements** (numbered, detailed):
- R-1: Before executing a safe-sender move-to-target-folder action for a given message, check whether a message with the SAME Message-ID already exists in the TARGET folder (`safeSenderTarget`, normally Inbox). If it does, skip the move for that message entirely (do not re-promote something that is already there, or that AOL's rule is actively fighting over) -- this is the gap in the existing F91 (Sprint 39) dedup, which only reconciles the SOURCE folder AFTER a move, never the TARGET before one.
- R-2: Reuse the existing `SpamFilterPlatform.searchByMessageId(folder, messageId)` capability (already used by `dedupSafeSenderSourceFolder`) for the target-folder pre-check -- this is a genuinely existing IMAP primitive, not a new one, so no Tooling-Capability Pre-Flight spike is required per `SPRINT_PLANNING.md`'s trigger condition (that rule applies to bolting a NEW capability onto an external tool; this reuses a capability already proven in production since Sprint 39).
- R-3: Preserve F91's existing post-move source-folder dedup (`dedupSafeSenderSourceFolder`) UNCHANGED as a second layer of defense -- R-1's pre-move check and F91's post-move cleanup are complementary, not redundant: R-1 stops an unnecessary re-promotion before it happens (the new gap this task closes); F91 still cleans up any genuine same-scan re-injection race that slips past R-1 (e.g., AOL's rule fires between the pre-check and the move completing). Do not remove or weaken F91.
- R-4: Scope the pre-check to IMAP-backed platforms only, mirroring F91's existing `platform is! GenericIMAPAdapter` skip (Gmail OAuth uses labels, not folders, and has no reproducible version of this bug reported).
- R-5: Investigate whether this is a genuine regression of F91 or an always-existing gap in F91's original design (F91 never claimed to check the target folder; its own doc comments describe only source-folder reconciliation) -- record the finding in this task's completion notes. This determines whether the CHANGELOG entry frames this as a "fix: regression" or "fix: gap in the original F91 design," which matters for accurate project history.

**Affected components / files**:
- `mobile-app/lib/core/services/email_scanner.dart` -- new pre-move target-folder check, inserted into the same evaluation loop that currently builds `safeSenderMoveEmails` (around line 407-419), likely as a new `@visibleForTesting` async function mirroring `dedupSafeSenderSourceFolder`'s existing shape and code style (same file, `dedupSafeSenderSourceFolder` at line 854 is the direct sibling to follow).
- `mobile-app/test/unit/services/f91_safe_sender_dedup_test.dart` -- extend using the EXISTING `_FakeImapPlatform` test harness (already mocks `searchByMessageId` and `moveToFolderBatch`, already covers the AOL-re-injection scenario) rather than building new test infrastructure.

**Dependencies / blockers**:
- None to scope. Independent of F142 (different subsystem entirely -- IMAP scan/move logic vs. UI navigation).

**Non-functional requirements**:
- Platform: this affects any IMAP-backed account (AOL, Yahoo, generic IMAP), not Android/Windows-specific -- the bug is provider-behavior-driven (AOL's server-side rule), not platform-UI-driven.
- The evaluation loop currently building `safeSenderMoveEmails` (line 399-424) is synchronous; R-1's per-message target-folder check requires an async IMAP search, so this loop -- or the filtering step -- needs to become async. Mirror how `dedupSafeSenderSourceFolder` already handles this (an async `for` loop over candidates, one `searchByMessageId` call per message) rather than inventing a new concurrency pattern.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given a safe-sender message whose Message-ID ALREADY has a matching message in the target folder (Inbox), When the scan evaluates it for a safe-sender move, Then the move is skipped for that message (not executed), and this is logged distinctly from the existing "already in target folder" skip (line 413-415, which only catches the message's OWN current folder being the target -- AC-1 covers a DIFFERENT message/UID with the same Message-ID already sitting there).
- AC-2: Given a safe-sender message whose Message-ID has NO match in the target folder, When the scan evaluates it, Then the move proceeds normally (no regression to the existing clean-move path).
- AC-3: Given the IMAP search for AC-1 fails or throws, When the scan proceeds, Then the message's move is NOT silently skipped by the failure (fail open to the pre-existing behavior, matching F91's own "search/move failure degrades to a no-op, scan never breaks" precedent) -- record which failure-handling choice was actually made and why in completion notes, since "fail open" (attempt the move anyway) and "fail closed" (skip the move) have different risk profiles and this is worth an explicit decision, not a default.
- AC-4: F91's existing `dedupSafeSenderSourceFolder` behavior is unchanged -- all 7 existing scenarios in `f91_safe_sender_dedup_test.dart` (per that file's own doc-comment list) still pass without modification to their assertions.
- AC-5: R-5's investigation finding (regression vs. always-existing gap) is recorded in this task's completion notes with supporting evidence (e.g., git blame / commit history reasoning), not asserted without a check.

**Tests to write** (one intent per AC; name pyramid level + target file):
- T-1 (verifies AC-1) -- TEST-UNIT in `test/unit/services/f91_safe_sender_dedup_test.dart` (or a new sibling file if the existing one is judged better left untouched structurally -- Sonnet judgment call): using `_FakeImapPlatform`, set up a safe-sender message with a Message-ID that has a match in `searchResponses[targetFolder]`, assert `moveToFolderBatch` is NEVER called for that message.
- T-2 (verifies AC-2) -- TEST-UNIT, same harness: no target-folder match -> assert the move proceeds (existing "clean move" scenario extended to also assert the NEW pre-check ran and returned empty).
- T-3 (verifies AC-3) -- TEST-UNIT, same harness: `throwOnSearch: true` on the target-folder pre-check -> assert the chosen fail-open/fail-closed behavior (the move proceeds if fail-open is chosen; is skipped if fail-closed is chosen) and that the failure is logged, not silently swallowed.
- T-4 (verifies AC-4) -- regression: run the full existing `f91_safe_sender_dedup_test.dart` suite unmodified in assertions, confirm all 7 scenarios still pass.
- T-5 (verifies AC-1/AC-2 end-to-end, if feasible) -- MANUAL, per Harold's own AOL account if a real affected message can be identified and observed across 2+ scan cycles; likely NOT feasible to force-reproduce on demand (depends on AOL's rule timing, which is outside this app's control) -- if not reproducible on demand, T-1 through T-4's unit coverage is the primary proof, and this becomes a "monitor in production over the following days" verification instead of a blocking Manual Validation step. Record which path was taken in completion notes.

**Definition of Done**: default task-level DoD PLUS:
- R-5's regression-vs-gap investigation finding recorded with evidence.
- AC-3's fail-open-vs-fail-closed decision recorded with reasoning.
- T-5's feasibility outcome recorded (real-world reproduction attempted and result, OR explicitly deferred to production monitoring with reasoning).

**Model**: Sonnet -- *why not Haiku*: requires understanding an existing, non-trivial IMAP reconciliation mechanism (F91) well enough to extend it correctly without breaking its existing guarantees, plus a genuine root-cause judgment call (R-5) about whether this is a regression or a gap -- beyond Haiku's heuristics for well-defined single-file work. Not escalated to Fable/Opus: the fix pattern (reuse `searchByMessageId` for a pre-check, mirroring the existing post-check) is already fully diagnosed and scoped during backlog refinement; this is targeted implementation against an existing, well-tested pattern, not open-ended architectural investigation.

**Executed-by**: _(fill at completion)_

**Step-types**: SVC-EDIT (email_scanner.dart), IMAP (searchByMessageId reuse), TEST-UNIT (T-1 through T-4)

**Est-Effort**: `[no-history]` -- no prior sample of "extend an existing IMAP dedup mechanism with a symmetric pre-check" in `CODING_VELOCITY.md`'s Estimate Table, though it is closely related to F91's own original IMAP/SVC-EDIT work (13-40m band, bundled). Time-boxed rather than inventing a precise range; expect the SVC-EDIT band's higher end given the existing test harness significantly reduces T-1/T-2/T-3/T-4's authoring cost.

_**Risk & rollback**_: Medium. Risk: AC-3's fail-open/fail-closed choice has real behavioral consequences under IMAP flakiness (fail-open risks the original bug persisting under search failures; fail-closed risks safe-sender messages never reaching Inbox if the target-folder search is persistently broken) -- must be a deliberate choice, not a default, and should match F91's own established "degrade to no-op, never break the scan" philosophy unless Harold's stated expectation ("should not move if already in Inbox, or a copy is in Inbox") is read as prioritizing correctness over move-liveness under failure. Rollback: additive change (new pre-check function + one call site); `git revert` fully restores current behavior; F91's existing mechanism is untouched so no compounding risk.

_**Decision-class interrupts**_: None anticipated -- this is a targeted bug fix within already-diagnosed scope, not an architecture or prior-development-decision change. If R-1's implementation reveals the fix needs to touch shared infrastructure beyond `email_scanner.dart` (e.g., a change to `SpamFilterPlatform`'s interface contract), surface that as a Class-2 development decision before proceeding.

---

## Sprint-Level Notes

- **Sprint scope is F142 + F149** (F149 added 2026-08-14, expanding the sprint after initial F142-only approval). F143 and F144 are explicitly deferred to the NEXT sprint per Harold's direct instruction -- both depend on F142 landing first, so that boundary is unchanged.
- **The two tasks are independent** (Android UI navigation vs. IMAP scan/move logic) and can proceed in either order or in parallel; no shared files, no dependency between them.
- **No architecture changes are pre-approved beyond what's scoped above.** If either task's implementation surfaces a need for broader changes (F142: navigation/deep-link redesign; F149: a `SpamFilterPlatform` interface change), that is out of scope for this sprint and gets surfaced as a new backlog candidate or a Class-2 decision point, not folded in silently.
- **Standing execution authorization** (Harold, 2026-08-14): "Continue without additional approvals until Manual Validation... Do not stop to ask questions unless meeting the criteria in SPRINT_STOPPING_CRITERIA.md." Both tasks proceed under this blanket approval; a Manual Validation recommendation for both is provided once implementation completes.
