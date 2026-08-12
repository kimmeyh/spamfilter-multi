# Sprint 55 Plan

**Branch**: `feature/20260809_Sprint_55`
**Dates**: 2026-08-09 --
**Scope proposed by Harold** (2026-08-10): F145 (WinWright/integration_test Help-icon deep-link coverage) + F146 (mislabeled AOL error message) + F147 (scan-range setting silently overridden by no-rule cursor, with mandatory regression tests). **Pending Harold's Phase 3.7 approval -- this document is the proposal, not yet authorized.**

**Context**: This is the first sprint plan for Sprint 55. The branch opened via Phase 6.6 carry-forward from Sprint 54's merge (PR #298/#303). Backlog Refinement was underway (hygiene pass applied, commit `f4aec58`) when Harold pivoted mid-refinement to ship the 0.6.0.0 Store release (Submission 11, certified + live 2026-08-10). That release's Check C smoke test surfaced F146 and F147 live; F145 carries forward from the Sprint 54 retrospective (Category 14). All three backlog items are documented in `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" -- this plan is the first formal scoping of them into sprint tasks.

**Ordering rationale**: F147 first -- it is the highest-trust-impact item (a scan-range setting silently not doing what its own UI text promises) and the item Harold explicitly flagged as "critical functionality" requiring test coverage. F146 second -- small, well-scoped, no design ambiguity. F145 last -- testing-infrastructure work with a `[no-history]` time-box, matching the F140 precedent of ordering open-ended/exploratory items after well-defined fixes so they cannot crowd out smaller done-in-one-sitting work if the time-box runs long.

---

## Task 1 -- F147: Honor the "Scan all emails" / range setting instead of always preferring the no-rule cursor (Priority 10)

**Value**: This restores a broken promise the UI itself makes to the user ("Scan all emails - No date filter - scans entire mailbox") for both Manual and Background scan, on every IMAP-backed account. Left unfixed, users configuring a full-mailbox scan get a silently narrower result with no indication anything was skipped -- directly undermines trust in the spam-filtering coverage the app claims to provide.

**Requirements** (numbered, detailed):
- R-1: In `EmailScanner._fetchFolderMessagesImap` (`mobile-app/lib/core/services/email_scanner.dart:1120-1159`), the branch that currently prefers `imap.fetchMessagesIncremental` whenever an `oldest_no_rule_uid` cursor exists (`account_folder_cursors` table) must first check whether the calling scan's `daysBack` value represents "scan all" (`daysBack <= 0`, per the existing `_resolveDaysBackUidFloor` convention at line 1195). When "scan all" is active, bypass the cursor entirely and call `imap.fetchMessages(daysBack: daysBack, folderNames: [folderName])` (the true full fetch), matching the `oldestNoRuleUid == null` branch's existing behavior.
- R-2: When "scan all" is NOT active (a specific N-day window is configured) and a cursor exists, preserve the current incremental-cursor behavior -- this requirement only closes the "scan all" gap, it does not change the existing N-day-window + cursor interaction, which needs to be proven correct by a test, not redesigned.
- R-3: After a "scan all" bypass fetch (R-1), the no-rule cursor must still be recomputed/persisted for the folder afterward (via the existing post-scan cursor-update path in `_updateOldestNoRuleCursors`), so the NEXT scan (if it reverts to a windowed range) resumes incrementally from a correct state rather than an unset or stale cursor.
- R-4: Apply the same audit to Background scan's call path. Background scan uses its own independently-configurable range setting (`background_days_back` / its own "scan all" toggle, `account_settings` keys distinct from Manual's `manual_days_back`) -- confirm (via a test, not just code-reading) that Background scan's call into `_fetchFolderMessagesImap` passes the correct `daysBack` value reflecting ITS OWN setting, not Manual's, and that R-1's fix applies uniformly regardless of which caller (manual or background) triggered the scan.
- R-5: Investigate whether the equivalent bug exists on the Gmail API path (`_fetchFolderMessagesGmail`, `email_scanner.dart:1061`, historyId-based incremental fetch) -- the backlog scope note flagged this as "likely also affects... needs confirming." If confirmed, fix identically (bypass historyId-incremental in favor of a full fetch when "scan all" is set); if the Gmail path already handles this correctly (e.g., because `lastHistoryId == null` on first scan is a different trigger than a per-folder no-rule cursor), document why no fix is needed there, do not assume by analogy.

**Affected components / files**:
- `mobile-app/lib/core/services/email_scanner.dart:1120-1159` (`_fetchFolderMessagesImap`) -- primary fix
- `mobile-app/lib/core/services/email_scanner.dart:1061-1099` (`_fetchFolderMessagesGmail`) -- investigate per R-5, fix if confirmed broken
- `mobile-app/test/unit/services/email_scanner_test.dart` and `mobile-app/test/unit/services/email_scanner_no_rule_cursor_cap_test.dart` (confirmed existing -- the latter is a direct precedent for cursor-related test coverage, follow its patterns) -- extend with new test coverage; add a new file only if these two do not fit the new cases cleanly.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Account-scoping: the fix must respect that Manual and Background scan settings are independently configured per account (`account_settings` keyed by `account_id` + `setting_key`) -- a test must prove the fix does not accidentally cross-apply one scan type's range setting to the other.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given an IMAP account with a stored `oldest_no_rule_uid` cursor for a folder, When a Manual scan runs with "Scan all emails" enabled for that account, Then the fetch returns the full folder content (matching an external mail client's total message count for that folder), not just the post-cursor subset.
- AC-2: Given the same cursor state, When a Manual scan runs with a specific N-day window configured (not "scan all"), Then the existing incremental-cursor behavior is preserved (no regression) -- verified by an explicit test, not assumed from R-1 alone.
- AC-3: Given an account with NO cursor yet (first-ever scan for that folder), When any scan runs, Then behavior is unchanged from before this fix (full fetch either way, per existing first-scan handling).
- AC-4: AC-1 through AC-3 are each proven independently for Background scan using ITS OWN range settings (`background_days_back`/its "scan all" flag), not inferred from the Manual-scan tests passing.
- AC-5: R-5's Gmail-path investigation concludes with either a matching fix + test, or a documented reason no fix is needed -- not silence.
- AC-6 (behavioral, regression repro): Given a folder with 300+ messages, a stored no-rule cursor partway through, and "Scan all emails" enabled, When a scan runs, Then the reported "Found" count matches the folder's actual total message count (the exact AOL "Bulk Mail" 301-vs-8 discrepancy this item originated from, reproduced as an automated test rather than only a manual Outlook-vs-app comparison).

**Tests to write** (Harold, 2026-08-10: mandatory, not optional -- "this is critical functionality"):
- T-1 (verifies AC-1, AC-6) -- TEST-UNIT in the scanner's test file: mock/fake IMAP adapter with a stored cursor + "scan all" daysBack=0, assert `fetchMessages` (full) is called, not `fetchMessagesIncremental`.
- T-2 (verifies AC-2) -- TEST-UNIT: same setup but with a specific daysBack window, assert `fetchMessagesIncremental` (cursor path) is still called -- proves R-1's fix is scoped correctly and does not regress the existing windowed-scan behavior.
- T-3 (verifies AC-3) -- TEST-UNIT: no cursor stored, assert existing full-fetch behavior unchanged either way.
- T-4 (verifies AC-4) -- TEST-UNIT or TEST-INTEGRATION: repeat T-1/T-2/T-3's setup but driven through the Background scan call path with Background's own settings, confirming independence from Manual's settings.
- T-5 (verifies AC-5) -- TEST-UNIT for the Gmail path, shaped by whatever R-5 concludes (a fix-confirming test, or none if no fix is needed -- but the investigation conclusion itself must be recorded in this plan's completion notes either way).

**Definition of Done**: default task-level DoD PLUS:
- All 5 test groups (T-1 through T-5) pass, in addition to the full existing suite.
- The R-5 Gmail-path conclusion (fixed, or confirmed-not-applicable-and-why) is recorded in the PR/commit and in `ALL_SPRINTS_MASTER_PLAN.md`'s F147 entry when closed out.

**Model**: Sonnet -- *why not Haiku*: requires tracing and correctly modifying a cursor-vs-full-fetch branch decision that spans two call paths (Manual and Background) and touches a data-correctness invariant (users trusting the scan-range setting), not a single-file mechanical change. Not escalated to Fable/Opus: the fix shape is already identified (add a "scan all" bypass check before the existing cursor branch) -- this is scoped implementation against a known root cause, not open-ended architectural investigation.

**Executed-by**: _(fill at completion)_

**Step-types**: SVC-EDIT (email_scanner.dart), TEST-UNIT (T-1 through T-5)

**Est-Effort**: 45-75m -- SVC-EDIT band (5-18m) at the higher end for a two-call-path fix with a bypass-then-still-persist-cursor requirement (R-3), plus TEST-UNIT band (4-10m each) x5 test groups, plus time for the R-5 Gmail-path investigation itself (which may conclude "no fix needed" but still requires code-reading to confirm).

_**Risk & rollback**_: Medium -- an incorrect fix could either (a) not actually bypass the cursor (leaving the bug in place) or (b) bypass it too aggressively and break the legitimate windowed-scan + cursor interaction (regressing AC-2). Mitigation: T-2's explicit non-regression test is the primary guard, written before considering the task done, not after. Rollback: the fix is a single conditional branch addition; `git revert` the commit fully restores prior (buggy but familiar) behavior.

---

## Task 2 -- F146: Fix mislabeled "AOL copy-not-move" error message (Priority 20)

**Value**: This removes a misleading diagnostic message that actively points troubleshooting in the wrong direction -- a Gmail-IMAP user (or a future Claude session debugging a Gmail scan failure) seeing "(AOL copy-not-move)" in an error for a non-AOL account will waste time chasing an AOL-specific explanation for what is actually a provider-agnostic IMAP behavior.

**Requirements** (numbered, detailed):
- R-1: In `GenericIMAPAdapter.partitionByMoveSurvival` (`mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:1110-1131`), generalize the hardcoded failure-reason string (currently `'... (AOL copy-not-move)'`, line 1125) to name the actual mechanism rather than a specific provider -- e.g. `'... (server acknowledged the move without performing it)'` or similar wording that does not imply an AOL-only cause.
- R-2: Update the method's doc comment (lines 1097-1109, which also names "the AOL copy-not-move pathology") to reflect that this is a provider-agnostic IMAP behavior observed on at least AOL and Gmail-IMAP, not AOL-specific.
- R-3: Do NOT change the underlying retry/detection logic itself -- this task is a message/documentation correction, not a behavior change. If R-1's investigation surfaces evidence the pathology genuinely needs provider-specific handling (different retry strategy per provider), STOP and surface that as a separate backlog candidate rather than expanding this task's scope.

**Affected components / files**:
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:1097-1131` (doc comment + the hardcoded string in `partitionByMoveSurvival`)

**Dependencies / blockers**: None.

**Acceptance criteria** (measurable, traceable):
- AC-1: `Get-ChildItem mobile-app/lib -Recurse | Select-String "AOL copy-not-move"` returns 0 matches after the fix (executed via the Grep tool per Windows Tool Restrictions).
- AC-2: The replacement message text does not name any specific email provider, since the mechanism is confirmed provider-agnostic (fired on both AOL and Gmail-IMAP accounts in production).
- AC-3: Any existing test asserting on the literal old message string is updated to match, not left to silently pass on stale text or fail unexpectedly.

**Tests to write**:
- T-1 (verifies AC-1, AC-2) -- check `mobile-app/test/integration/imap_adapter_test.dart` (confirmed existing) for any hardcoded assertion on the old string; update in place. If no existing test asserts on the message text specifically, add one asserting the new message does not contain "AOL" (a targeted regression guard against this exact mislabeling recurring).

**Definition of Done**: default task-level DoD only -- no additions.

**Model**: Haiku -- *why not escalate*: single-file string + doc-comment correction with an explicit no-behavior-change constraint (R-3), directly comparable to Haiku's established "straightforward implementation, well-defined scope" heuristics. Escalate only if R-3's stop condition triggers (evidence the pathology needs real provider-specific handling).

**Executed-by**: _(fill at completion)_

**Step-types**: SVC-EDIT, TEST-UNIT (if a new/updated assertion is needed), DOCS (doc comment)

**Est-Effort**: 10-20m -- SVC-EDIT band (5-18m) for a string + comment change, toward the low-middle given the need to locate and update any existing test assertion first.

_**Risk & rollback**_: Low -- message-text-only change, no logic modified. Rollback: `git revert` the single commit.

---

## Task 3 -- F145: integration_test coverage for Help-icon deep-link, every screen (Priority 30)

**Value**: This closes a systematic regression gap -- the Help deep-link mechanism (`initialSection` -> `HelpSection` enum -> auto-scroll on arrival, shipped F54 Sprint 33) has 16 call sites across the app's screens but zero automated proof that any individual screen's Help icon actually lands on ITS OWN section rather than just opening `HelpScreen` at the top. A future refactor of `HelpSection` or a screen's `helpSection:` wiring could silently break one screen's deep-link with no test catching it.

**Requirements** (numbered, detailed):
- R-1 (Tooling-Capability Pre-Flight, per `SPRINT_PLANNING.md`): before committing to a full 16-screen test suite, run a single confirming spike -- write ONE test case (e.g. `rules_management_screen` -> `HelpSection.manageRules`) proving the `integration_test` harness (already proven working for semantics-tree assertions in `sprint52_surfaces_test.dart` and other existing files under `mobile-app/integration_test/`) can (a) tap a Help AppBar icon, (b) land on `HelpScreen`, and (c) verify the specific target section's content/anchor is scrolled into view (not just that `HelpScreen` opened). This is a confirmation spike, not a from-scratch feasibility question -- the harness pattern is already established in this codebase (F133-S52, F140), so expect this to succeed quickly; if it does NOT (e.g., scroll-position verification proves unreliable even in-VM), stop and re-scope before writing the other 15 cases.
- R-2: Enumerate all screens with a Help AppBar icon via `StandardAppBarActions` usage (confirmed via `helpSection:`/`includeHelp` grep -- currently 16 call sites across `account_selection_screen.dart`, `account_setup_screen.dart` (x2, two distinct entry points), `folder_selection_screen.dart`, `platform_selection_screen.dart`, `rules_management_screen.dart`, `rule_quick_add_screen.dart`, `no_rule_review_screen.dart`, `results_display_screen.dart` (conditional platformId), `rule_test_screen.dart`, `scan_history_screen.dart`, `safe_senders_management_screen.dart`, `scan_progress_screen.dart` (conditional platformId), `yaml_import_export_screen.dart`, `settings_screen.dart` (dynamic per-tab via `_helpSectionForActiveTab()` -- needs one case per tab, not just one for the screen)) -- re-verify this list against current `lib/` state at task start, since it may have changed since this plan was written.
- R-3: For each enumerated screen/tab, write one test case asserting: tapping the Help icon navigates to `HelpScreen`, AND the specific expected `HelpSection` anchor is the one scrolled into view (verified via the semantics tree, matching R-1's spike technique) -- not merely that `HelpScreen` rendered.
- R-4: Group the cases into one new `integration_test/help_deep_link_test.dart` file (following the existing `sprint52_surfaces_test.dart` file/group-per-concern convention), run via `.\scripts\run-integration-tests.ps1 -TestName help_deep_link` (matching the existing script's `-TestName` convention).

**Affected components / files**:
- `mobile-app/integration_test/help_deep_link_test.dart` (new)
- `mobile-app/integration_test/helpers/app_harness.dart` -- reuse existing harness; extend only if a genuinely new helper primitive is needed (e.g., "tap Help icon and capture the resulting HelpScreen's visible anchor") -- do not duplicate harness logic that already exists.

**Dependencies / blockers**: None.

**Acceptance criteria** (measurable, traceable):
- AC-1: R-1's spike case passes, proving the harness can verify a specific deep-link target (not just screen-opened), before the remaining cases are written.
- AC-2 (behavioral, per screen/tab): Given screen X is open, When its Help AppBar icon is tapped, Then `HelpScreen` opens AND the semantics tree shows section X's anchor/content scrolled into view.
- AC-3: All 16 (or however many R-2's re-verification confirms) call sites have a corresponding passing test case, with no site silently skipped.
- AC-4: `settings_screen.dart`'s per-tab dynamic resolution (`_helpSectionForActiveTab()`) is covered by one case per tab, not a single case for the whole screen.

**Tests to write**:
- T-1 (verifies AC-1) -- the R-1 spike case itself, in `help_deep_link_test.dart`.
- T-2 through T-N (verifies AC-2, AC-3, AC-4) -- one `integration_test` case per enumerated screen/tab from R-2, in the same file, grouped logically (e.g., by screen category matching the existing `sprint52_surfaces_test.dart` group style).

**Definition of Done**: default task-level DoD PLUS:
- If R-1's spike fails, the task stops, documents the failure and why (per the Tooling-Capability Pre-Flight rule's explicit re-scope instruction), and does NOT proceed to write the remaining 15 cases against a technique already shown not to work.
- The full new test file is run at least once via `.\scripts\run-integration-tests.ps1` (not just `flutter test`) to confirm it passes through the project's actual integration-test runner, matching how other `integration_test/` files in this repo are verified.

**Model**: Sonnet for R-1's spike design and any harness extension; Haiku-eligible for R-3's repetitive per-screen case authoring once the spike proves the pattern -- *why not all-Sonnet*: after R-1 confirms the technique, writing 15 more structurally-identical cases against an established pattern is exactly Haiku's "well-established testing patterns" strength (per `SPRINT_PLANNING.md`'s Haiku task examples, e.g. "Write unit tests for RuleEvaluator edge cases"). *Why Sonnet for R-1*: proving out a new verification technique against a third-party rendering/semantics boundary (even one with prior art in this codebase) requires judgment if the first attempt does not work cleanly, which is above Haiku's heuristics.

**Executed-by**: _(fill at completion)_

**Step-types**: WINWRIGHT-DISCOVERY-adjacent (R-1 spike, though this is `integration_test` not WinWright proper -- treat as `[no-history]` per the same "do not estimate discovery time" convention), TEST-INTEGRATION (R-3's per-screen cases, once the pattern is proven)

**Est-Effort**: `[no-history]`, TIME-BOXED. R-1 spike: time-box to 20-30m (matching F140's WINWRIGHT-DISCOVERY precedent of 30-90m total for a spike-plus-fallback item, here scoped to spike-only since the fallback is "re-scope," not a UI change). R-3's per-screen cases, once the pattern is proven: estimate at TEST-INTEGRATION band, roughly 8-15m per case x ~17 cases (16 screens + 1 extra for Settings' multi-tab) = roughly 135-255m for the bulk authoring, though this should compress once the first 2-3 cases establish a copy-adapt rhythm (expect actuals toward the low end, consistent with F133-S52's repetitive-case pattern running faster than a linear per-case estimate would suggest). Total time-box: 3-5 hours; if not complete, stop, document coverage achieved (X of 17 cases), and carry the remainder forward rather than open-endedly continuing -- consistent with F141's precedent of stopping at a time-box and recording gaps as follow-up.

_**Risk & rollback**_: Low -- this is pure test-authoring with no production code changes (unless R-1's spike reveals a genuine bug in the deep-link mechanism itself, in which case that finding gets surfaced as a NEW backlog item, not folded into this task's scope). Rollback: the new test file can be deleted with zero effect on the app; no risk to shipped behavior.

---

## Sprint-Level Notes

- **F147 is the trust-critical item** (Harold, 2026-08-10: "this is critical functionality to the app... ensure background scans are honoring the account-specific settings for scan range AND the manual scan settings are honoring the account-specific settings from scan range"). Its test-coverage requirement is non-negotiable per the Definition of Done -- a code fix without the T-1 through T-5 test groups passing is not an acceptable completion of this task.
- **No architecture changes are pre-approved by this plan.** All three tasks are scoped as bug fixes / test-infrastructure additions against already-identified root causes, not open-ended investigation. If any task's execution surfaces a Class-1/2/3 decision (per CLAUDE.md's Decision-Class Taxonomy) -- e.g., F147's R-5 Gmail-path investigation revealing a deeper historyId-semantics issue than expected -- it gets surfaced and waits for approval, per standing policy.
- **Backlog hygiene status**: Harold's five hygiene items (F125/F141 removal, F130-S51-through-F136/ENV-1 rollup, F-VERSION-DERIVE/F-PRECHECK collapse, F-COPILOT-INSTR closure) were already fully applied during the pre-release pivot (commit `f4aec58`, 2026-08-09) -- verified against current `docs/ALL_SPRINTS_MASTER_PLAN.md` state before writing this plan. No further pruning action is needed for those five items; this sprint's scope is F145/F146/F147 only.
