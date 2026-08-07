# Sprint 54 Plan

**Branch**: `feature/20260803_Sprint_54`
**Dates**: 2026-08-03 --
**Scope defined by Harold** (2026-08-03): F137 + F140 + F125 (in that priority order), then F141 (Android/Google Play re-expansion deep dive) LAST, after all other sprint items. Q&A exception granted for F141 specifically -- questions should be batched together up front or as late as possible, grouping dependent questions together, rather than interrupting one at a time.

**Context**: This is the first sprint after the 0.5.9.0 Store release (Sprint 53). No code changes shipped in 0.5.9.0 were left over; this sprint's first three items are small, independent Core-App-Quality/Process cleanups, and the fourth is the opening investigation for the Android/Google Play track promoted off HOLD on 2026-07-24 (per the Store-release promotion trigger).

**Ordering rationale** (Harold's explicit instruction): F141 is investigation/analysis work that produces backlog items and findings, not shippable app code -- it goes last so the smaller, well-defined, shippable items (F137/F140/F125) are not put at risk of running out of sprint time behind an open-ended deep dive.

---

## Task 1 -- F137: Verify and remove dead `process_results_screen.dart` (Priority 10)

**Value**: This removes confirmed-dead code, keeping the codebase's actual surface area matched to what the Sprint 52 accessibility audit and future greps will find, preventing a repeat "1 partial reference" false flag.

**Requirements** (numbered, detailed):
- R-1: Re-verify zero references to `ProcessResultsScreen` (class name) and `process_results_screen.dart` (file name) anywhere under `mobile-app/lib/` using both a filename grep and a class-name grep, matching the verification standard used for the three screens removed in Sprint 52's R-7.
- R-2: If genuinely zero references, delete the file.
- R-3: If a reference is found this time (the file moves fast between audits), STOP deletion and document why it is retained instead, in this plan and in a CHANGELOG entry.

**Affected components / files**:
- `mobile-app/lib/ui/screens/process_results_screen.dart` -- delete (if R-1 confirms dead)

**Dependencies / blockers**: None.

**Acceptance criteria** (measurable, traceable):
- AC-1: `Get-ChildItem mobile-app/lib -Recurse | Select-String "process_results_screen"` returns 0 matches outside the file itself (pre-deletion) or the file does not exist (post-deletion). (Executed in-turn via the Grep tool, not a literal bash `grep -r` -- this repo is Windows/PowerShell-first per CLAUDE.md's Windows Tool Restrictions.)
- AC-2: `Get-ChildItem mobile-app/lib -Recurse | Select-String "ProcessResultsScreen"` returns 0 matches outside the file itself (pre-deletion) or the file does not exist (post-deletion). (Same tooling note as AC-1.)
- AC-3: `flutter analyze` and `flutter test` remain clean after deletion (no import broke).

**Tests to write**:
- T-1 (verifies AC-1, AC-2, AC-3) -- no new test needed; this is a dead-code removal verified by the existing full suite staying green post-deletion, consistent with how the Sprint 52 R-7 removals were verified (no new test file, suite + analyze green).

**Definition of Done**: default task-level DoD PLUS:
- If NOT deleted (a live reference turns up), the plan and CHANGELOG explicitly record why, rather than silently carrying the file forward again.

**Model**: Haiku -- *why not escalate*: single-file grep-verify-delete, no ambiguity, matches the existing Sprint 52 R-7 pattern exactly.

**Executed-by**: _(fill at completion)_

**Step-types**: DOCS (verification), and a deletion (no step-type code for "delete a file" -- closest is SVC-EDIT at the low end)

**Est-Effort**: 10-15m -- based on the CODING_VELOCITY.md SVC-EDIT band (5-18m) at the low end, since this is a verify-then-delete with no logic change.

_**Risk & rollback**_: Low risk -- if AC-1/AC-2 turn up a reference, the task simply stops at "document why retained" with no deletion. Rollback (if deletion breaks something despite the grep): `git revert` the single commit.

---

## Task 2 -- F140: Investigate WinWright/UIA reachability for end-of-page content on Settings > General and Help (Priority 20)

**Value**: This closes a testing-infrastructure gap discovered live during the F-STORE-53 smoke test -- WinWright could not independently verify the About-screen version display, forcing reliance on Harold's manual check every release. Fixing or working around this restores an automated check for the exact user-facing signal (`Version X.Y.Z`, no `[DEV]` suffix) that the F119 defect family made painfully important.

**Requirements** (numbered, detailed):
- R-1: Per `SPRINT_PLANNING.md`'s Tooling-Capability Pre-Flight rule (mandatory for "bolt X onto tool Y" items), the FIRST sub-task is a short capability spike proving (or disproving) that WinWright/UIA CAN reach an off-screen Flutter semantics-tree element via some mechanism -- before designing a fix. Candidates to try, in order: (a) a different `ww_scroll` container selector than was tried during the smoke test; (b) simulated mouse-wheel scroll (`ww_scroll` direction mode against a properly-targeted scrollable container handle, not the outer window); (c) `ww_dump_tree` raw inspection to see if the semantics tree actually implements `ScrollItemPattern`/`ScrollPattern` at all, or if WinWright's wrapper is the gap.
- R-2: If the spike succeeds (a working scroll/reach mechanism is found), implement it as the durable fix -- likely a WinWright usage-pattern correction documented in `docs/WINWRIGHT_SELECTORS.md`, not an app code change.
- R-3: If the spike fails (Flutter's Windows semantics tree genuinely does not expose a workable scroll pattern to UIA), fall back to relocating or duplicating the version display (and the Help screen's equivalent end-of-page content) nearer the top of its page/tab, so both a human and an automation tool can see it without scrolling.
- R-4: Document the outcome (spike result + chosen path) in `docs/WINWRIGHT_SELECTORS.md` and update the F139 template's known-gap note (currently references this exact limitation) to reflect the fix or confirm the manual-check workaround remains necessary.

**Affected components / files**:
- `docs/WINWRIGHT_SELECTORS.md` -- update with the finding (either a new selector/technique, or a documented dead-end)
- IF R-3 fallback: `mobile-app/lib/ui/screens/settings_screen.dart`, `mobile-app/lib/ui/screens/help_screen.dart` -- relocate/duplicate version or key content near the top

**Dependencies / blockers**: None to start. The Tooling-Capability Pre-Flight spike (R-1) determines whether R-2 or R-3 is the actual path -- this is an explicit branch point, not a blocker.

**Non-functional requirements**:
- Accessibility: if R-3's UI relocation happens, the moved/duplicated content must retain (or gain) proper `Semantics` wrapping per `ACCESSIBILITY_STANDARDS.md` -- this is exactly the kind of UI change the Sprint 52 audit would flag if done carelessly.

**Acceptance criteria** (measurable, traceable):
- AC-1: The capability spike (R-1) produces a definitive yes/no answer, recorded with the actual command/tool-call tried and its result -- not a assumption carried over from the smoke-test failure alone.
- AC-2 (behavioral, if R-2 path): Given the app is running with WinWright attached, When the documented new technique is used to reach the About-screen version text, Then the element is found and its value is readable (matching the live version string).
- AC-3 (behavioral, if R-3 path): Given the app is running, When the General or Help tab is opened, Then the version/key content is visible without scrolling.
- AC-4: `docs/WINWRIGHT_SELECTORS.md` is updated with the outcome either way.

**Tests to write**:
- T-1 (verifies AC-2, if R-2 path) -- no new automated test; this is a WinWright usage-pattern fix, proven by a live interactive session against the running app (same as how F131's root-cause fix was proven in Sprint 52 -- live verification, not a new test file).
- T-2 (verifies AC-3, if R-3 path) -- TEST-WIDGET in the relevant screen's existing widget test file: assert the version/key text renders within the visible initial viewport without requiring a scroll action.

**Definition of Done**: default task-level DoD PLUS:
- The spike result (R-1) is explicitly stated in the PR/commit, not left implicit in which path was taken.

**Model**: Sonnet -- *why not Haiku*: this is an open-ended investigation into a third-party tool's (WinWright/Flutter UIA integration) actual capability, requiring judgment about what to try next when an attempt fails -- exactly the kind of ambiguous, escalation-prone work Haiku's heuristics exclude. Not escalated to Fable/Opus: this is bounded tooling investigation, not architecture-wide reasoning or a security-critical judgment call.

**Executed-by**: _(fill at completion)_

**Step-types**: WINWRIGHT-DISCOVERY (R-1 spike, per CODING_VELOCITY.md `[no-history] -- time-box, do not estimate`), then either HOOK-adjacent (docs) or UI-MOVE (if R-3 fallback)

**Est-Effort**: 30-90m total (per Harold's own estimate on this candidate) -- the spike itself is `[no-history]`/time-boxed per WINWRIGHT-DISCOVERY guidance (do not estimate discovery time). Time-box the spike to 20-30m; if inconclusive by then, take the R-3 fallback rather than continuing to search. IF R-3 fallback triggers: UI-MOVE band is 3-6m per file, so R-3 adds roughly 10-15m for two screens plus test updates.

_**Risk & rollback**_: Low risk either way -- R-2 is a documentation/usage-pattern change with no app-code risk; R-3 is a small, easily-reverted UI relocation. Rollback: `git revert` the single commit if the relocated UI reads worse than before.

---

## Task 3 -- F125: One-shot release self-test probe (Priority 30)

**Value**: This collapses the current multi-step manual release verification (separate build-log check, `--print-env` invocation, manifest grep, size check) into a single command, reducing the chance any one check is skipped under time pressure during a real release -- directly addresses the F119-family root cause (a skipped verification step shipping a dev-flagged build).

**Requirements** (numbered, detailed):
- R-1: Extend the existing `--print-env` headless probe (already implemented, used in Sprint 53's F-STORE-53 verification) into a `--release-self-test` (or similarly named) mode that checks, in one invocation: `APP_ENV=prod`, `NATIVE_APP_ENV=prod`, empty `displaySuffix`/`dataDirSuffix`, `windowTitle` matches the expected non-dev title, and the running binary's version matches the expected target version (passed as an argument or read from a bundled asset).
- R-2: The probe outputs a single PASS/FAIL summary line plus the individual check results, so it can be grepped for a pass/fail signal in a script or read directly by a human.
- R-3: Fold the new probe into `docs/STORE_RELEASE_PROCESS.md` Step 4.0, replacing (or supplementing, if some manual checks remain irreplaceable, like the manifest-version-vs-package check which happens outside the running binary) the current multi-step description.

**Affected components / files**:
- `mobile-app/lib/main.dart` -- extend the existing `--print-env` argument-handling block with the new self-test mode
- `docs/STORE_RELEASE_PROCESS.md` -- Step 4.0 updated to reference the new one-shot probe

**Dependencies / blockers**: None. Builds directly on the existing `--print-env` mechanism (Sprint 47/49), not new infrastructure.

**Acceptance criteria** (measurable, traceable):
- AC-1: Running the probe against a known-good prod build outputs a PASS summary and each individual check as PASS.
- AC-2 (behavioral): Given a build with `APP_ENV=dev` (simulating the F119 defect class), When the probe is run, Then it outputs FAIL with the specific failing check named (not just a generic failure).
- AC-3: `docs/STORE_RELEASE_PROCESS.md` Step 4.0 documents the new command and its expected output shape.

**Tests to write**:
- T-1 (verifies AC-1, AC-2) -- TEST-UNIT or a small integration-style check in `test/` exercising the probe's check logic directly (not requiring an actual built binary) for both the all-pass and a simulated-fail case, mirroring how `test/policy/msix_config_test.dart` verifies build-config invariants without needing a real MSIX build.

**Definition of Done**: default task-level DoD PLUS:
- The probe is exercised against the ACTUAL current dev build (not just unit-tested) at least once, confirming it produces a real PASS on a known-good build, before being declared done.

**Model**: Sonnet -- *why not Haiku*: touches `main.dart`'s existing release-verification logic (a Class-1/2-adjacent surface given its F119-family history) and requires designing a check that must correctly distinguish pass/fail states without false-negatives on a real release -- higher stakes than a routine single-file addition. Not escalated to Fable/Opus: this is additive to an existing, well-understood mechanism, not a novel investigation.

**Executed-by**: _(fill at completion)_

**Step-types**: SVC-EDIT (main.dart extension), TEST-UNIT, DOCS (STORE_RELEASE_PROCESS.md update)

**Est-Effort**: 60-120m -- toward the higher end of Harold's own ~1-2h estimate, reflecting SVC-EDIT (5-18m) for the core logic plus TEST-UNIT (4-10m) plus DOCS (15-20m) plus integration/verification against a real build (not free per the DoD above); banded generously since this touches release-gating logic where correctness matters more than speed.

_**Risk & rollback**_: Medium -- a probe with a false-negative (reports PASS when something is actually wrong) would be worse than no probe, since it could create false confidence during a real release. Mitigation: AC-2's explicit simulated-fail test proves the probe actually detects the F119-class failure mode, not just that it runs. Rollback: the probe is purely additive (new flag/mode); reverting the commit fully removes it with no effect on existing release steps.

---

## Task 4 -- F141: Android / Google Play re-expansion deep dive (Priority 40, LAST)

**Value**: This produces an accurate, current backlog for the Android/Google Play track (promoted off HOLD 2026-07-24) before any implementation sprint starts -- preventing wasted effort executing against F94/F63/GP-* HOLD items that may be stale, already partially resolved, or missing newly-relevant Play Store policy requirements, and ensures UI/accessibility/backend gaps are identified up front rather than discovered mid-implementation.

**Requirements** (numbered, detailed):
- R-1: Re-verify the current state of every GP-* HOLD item (GP-2 Release Signing, GP-3 Manifest Permissions, GP-4 OAuth CASA Verification, GP-5 Privacy Policy/Legal, GP-6 Listing/Assets, GP-7 Adaptive Icons, GP-8 Target SDK/16KB pages, GP-9 ProGuard/R8, GP-10 Data Safety Form, GP-12 Firebase Analytics, GP-16 Developer Account Setup) against the current codebase and current published Google Play policy (these entries date to Sprint 39, 2026-05-25 refinement -- over a year of policy drift is possible).
- R-2: Re-verify F94 (Android dev/prod/store flavors) -- including its noted pre-existing `google-services.json` applicationId mismatch investigation item -- and F95 (iOS variants, likely stays HOLD/deferred since no macOS/Apple Developer account exists) against current repo state.
- R-3: Assess UI adaptation needs: for each of the app's ~24 active screens, determine (a) works as-is on phone/tablet/large-tablet (8x11) form factors, (b) needs layout adaptation, or (c) needs a different interaction pattern for touch vs. desktop mouse/keyboard -- cross-referencing F63 (Responsive design framework, currently HOLD) and explicitly folding in accessibility compatibility (per `ACCESSIBILITY_STANDARDS.md`, Sprint 52) as a hard requirement of any proposed adaptation, not a follow-up concern.
- R-4: Assess non-UI/backend changes needed: WorkManager-based background scanning (Android's scheduling model differs from Windows' Task Scheduler integration), Android-specific credential/storage paths, and any other adapter-layer assumptions that may not transfer cleanly from the Windows-first development that has dominated recent sprints.
- R-5: Produce a findings document plus concrete backlog updates in `ALL_SPRINTS_MASTER_PLAN.md`: re-scope/re-estimate existing items found stale, add new F#/GP items for gaps found, and explicitly flag anything that should stay HOLD vs. become an active candidate for the next Android-focused sprint.

**Affected components / files**:
- `docs/sprints/SPRINT_54_F141_ANDROID_DEEP_DIVE.md` (new) -- findings document, following the F103 (Architecture Deep Dive) / F104 (Security Deep Dive) precedent format
- `docs/ALL_SPRINTS_MASTER_PLAN.md` -- Android/Google Play HOLD section updated with findings-driven re-scoping

**Dependencies / blockers**: None to start. This is read/analysis/planning work -- no app code changes this sprint.

**Non-functional requirements**:
- This task produces NO shippable app code. Its Definition of Done is a findings document and backlog updates, not a code diff.

**Acceptance criteria** (measurable, traceable):
- AC-1: Every GP-* HOLD item and F94/F95 has a current status note (confirmed-still-accurate / stale-needs-rescoping / already-partially-done / superseded-by-new-policy), not just a re-read with no updated conclusion.
- AC-2: A per-screen UI-adaptation assessment exists for all active screens, each tagged works-as-is / needs-adaptation / needs-new-pattern, with accessibility compatibility explicitly addressed per screen (not a blanket statement).
- AC-3: A backend/non-UI changes list exists, covering at minimum background-scan scheduling, credential storage, and the F94 applicationId mismatch.
- AC-4: `ALL_SPRINTS_MASTER_PLAN.md`'s Android/Google Play HOLD section reflects the findings -- items re-scoped, new items added with real F#/GP identifiers, superseded items marked as such.

**Tests to write**:
- T-1 -- N/A. This is an analysis/planning task with a documentation deliverable, not code; there is no test to write. (Per the augmented template's right-sizing note: analysis-only tasks list "N/A" here rather than forcing an artificial test entry.)

**Definition of Done**: default task-level DoD (items 1/2/3/4 N/A since no code changes) PLUS:
- Findings document created and committed.
- `ALL_SPRINTS_MASTER_PLAN.md` backlog updates committed in the same session.
- Decision-class check: any finding that would imply an architecture change (e.g., a data-model change needed for Android) is flagged as a Class-1 item for Harold's review, NOT silently scoped into a future sprint's plan without surfacing.

**Model**: Sonnet for the bulk of the research/assessment work; **escalate the final synthesis to Fable/Opus** -- *why not Sonnet alone*: this deep dive spans build config, UI/accessibility, AND backend/architecture simultaneously, closely matching the "Architecture Deep Dives" and "Research Spikes" activities that `SPRINT_PLANNING.md` mandates the top available tier for (cross-cutting analysis of ADRs, code, and documentation; exploratory investigation with open-ended scope). Sonnet can execute the mechanical re-verification sub-steps (R-1, R-2); the cross-cutting synthesis (R-3/R-4/R-5, and especially the accessibility+responsive-design intersection) needs top-tier judgment, matching the F103/F104 precedent (both deep dives ran on the top-tier model).

**Executed-by**: _(fill at completion)_

**Step-types**: DOCS (findings document, `[no-history]` for the deep-dive format specifically, though F103/F104/F133 provide a structural precedent)

**Est-Effort**: `[no-history]`, TIME-BOXED -- following the F133-S52 precedent (first-run accessibility audit, also `[no-history, TIME-BOXED]`, actual ~85m for a comparably-scoped all-screens sweep). Time-box this deep dive to approximately 90-150m total given it spans three distinct assessment axes (Play Store readiness, UI/accessibility, backend) rather than F133's single axis. If the time-box is reached before all four requirements are addressed with reasonable depth, stop, document what was and was not covered, and note remaining gaps as follow-up rather than open-endedly continuing.

_**Risk & rollback**_: Low risk -- this is analysis/documentation work with no app-code risk. The main risk is scope creep (open-ended investigation running well past the time-box) -- mitigated by the explicit time-box and the instruction to stop and document gaps rather than continue. No rollback needed since nothing is shipped; a findings document that turns out incomplete is simply revised in a follow-up sprint.

_**Decision-class interrupts**_: Any UI-adaptation or backend finding that implies a genuine architecture change (e.g., a data-model or persistence-layer change to support Android-specific constraints) must be surfaced to Harold as a Class-1 item per the Decision-Class Checkpoint Protocol, not silently written into the backlog as if it were a routine estimate.

---

## Sprint-Level Notes

- **Q&A exception for F141** (Harold, 2026-08-03): normal sprint-plan-approval durable-authorization rules apply to Tasks 1-3. For Task 4 (F141) specifically, Harold has explicitly granted an exception allowing mid-task questions -- but batched together up front where possible, or as late as possible where a question depends on earlier findings, grouping dependent questions together rather than interrupting one at a time. This does not relax the Decision-Class Checkpoint Protocol (architecture-class findings still get surfaced individually per that protocol) -- it applies to scoping/clarification questions within F141's open-ended investigation.
- **Ordering is fixed**: F137, F140, F125, then F141 last -- per Harold's explicit instruction, not a priority-number coincidence (though the priority numbers 10/20/30/40 also happen to reflect this order).
- **No architecture changes are pre-approved by this plan.** F141 in particular may surface Class-1 findings (see its Decision-class interrupts note) -- those get surfaced and wait for approval, they are not implemented this sprint regardless of what F141 finds.
