# Sprint 52 Plan: Accessibility audit + UI consistency + harness repair

**Sprint**: 52
**Date**: 2026-07-30
**Branch**: `feature/20260730_Sprint_52` (created FROM `feature/20260727_Sprint_51` per the Phase 6.6 carry-forward flow)
**PR**: not yet created (Phase 3.3.1 creates it as a DRAFT once this plan is drafted)
**Status**: **AWAITING PHASE 3.7 APPROVAL** -- no task work starts until Harold approves.
**Scope source**: Harold 2026-07-30, Phase 1 backlog refinement -- F133-S52, F131, F134, F135, F136.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`, matched by step-type
against the Estimate Table. **Two of the five tasks are `[no-history]`** and are time-boxed rather
than estimated -- see the Estimating Integrity note.

**Card template**: augmented per-task template (Value / R-N / AC-N / T-N / Deps / NFRs / DoD) per
`SPRINT_PLANNING.md` "Sprint-Card Task Template (Sprint 47 Spike)". Cards list only *additions or
deviations* to the default Task-Level DoD.

---

## Phase 3.2.2.1 Plan-to-Branch-State Verification (gate result)

Each task verified against actual branch state before this plan was committed -- confirming what is
already DONE so no task re-does shipped work:

- **Task 1 (F133-S52)**: no accessibility standards document exists in the repo. `ADR-0037` sets
  WCAG 2.1 AA as the target and states the Semantics labelling rules, but there is no gap analysis and
  no per-screen audit. The wrapper pattern proven in Sprint 51 lives only in
  `mobile-app/test/winwright/README.md`. Confirms the gap.
- **Task 2 (F131)**: `test_f56_create_block_rule.json` and `test_f56_create_safe_sender.json` both
  exist and both still carry the "click the PARENT GROUP instead of the RadioButton" workaround in
  their `description` fields -- the workaround that did not reproduce on 2026-07-28. Confirms the
  stale-artifact risk.
- **Task 3 (F134)**: `lib/ui/widgets/standard_app_bar_actions.dart` EXISTS and is applied to
  `scan_progress_screen.dart` only. `settings_screen.dart`, `results_display_screen.dart` and
  `no_rule_review_screen.dart` still hand-roll their own action lists. Confirms 3 screens remain.
- **Task 4 (F135)**: `lib/core/providers/selected_account_provider.dart` EXISTS, is registered in
  `main.dart`, and `_resolveAccountForScopedDestination()` exists in `account_selection_screen.dart`.
  `settings_screen.dart` has no per-tab prompting and the app still opens on Account Selection.
  Confirms the remaining scope.
- **Task 5 (F136)**: no Skip control exists in the No-Rule item popup. Confirms not started.

**Phase 3.2.2.2 re-estimate**: no scope-changing findings. Task 3 and Task 4 are smaller than their
card titles imply because their foundations shipped in Sprint 51; both estimates reflect the remaining
work only.

---

## Sprint Objective

Close the accessibility gap systematically rather than reactively -- Sprint 51 fixed four surfaces,
each discovered only when a script hit a wall -- and finish the two UI-consistency items whose
foundations already shipped. Repair the WinWright create path so two committed scripts stop being a
trap for the next session.

---

## Estimating Integrity note

Per `CODING_VELOCITY.md` rule 2, any step-type without a prior sample is flagged `[no-history]` and
time-boxed rather than given an invented range. Sprint 51 established why this matters: a fabricated
"~3-6h" once dominated a sprint total and had to be withdrawn.

- **Task 1 (F133-S52)** is **TIME-BOXED BY TIER, not estimated**. Discovery is unbounded; the F130-S51
  precedent (same shape) ran to 28 findings across 3 tiers.
- **Task 2 (F131)** is `[no-history]` -- diagnosing a UIA/app-side interaction failure has no
  comparable step-type. Time-boxed with an explicit decision point.
- **Tasks 3, 4, 5** are calibrated against the Estimate Table (UI-MOVE 3-6m, UI-NEW 30-40m,
  UI-GESTURE 7-15m, TEST-WIDGET 20-25m).

Every task records its ACTUAL on completion (`CODING_VELOCITY.md` rule 3).

---

## Sprint Scope

### Task 1 -- F133-S52: Accessibility audit, first run (Priority 12) -- DO FIRST

**Value**: This enables a stated, verifiable accessibility standard for the app instead of
screen-by-screen guesswork. This prevents the Sprint 51 pattern where every accessibility defect was
found reactively, by a test failing, after the code shipped.

**Requirements** (numbered):
- R-1: Execute the F133 template scope defined in `ALL_SPRINTS_MASTER_PLAN.md` -- do NOT restate it
  here; execute against that definition.
- R-2: Produce a repository accessibility standards document. It must **extend ADR-0037** (which
  already sets WCAG 2.1 AA and the Semantics labelling rules), not duplicate or compete with it.
- R-3: The standards doc must absorb the wrapper pattern currently stranded in
  `mobile-app/test/winwright/README.md`: `Semantics` outside / `Tooltip` inside / real control
  innermost, with `excludeSemantics: true` **plus `onTap` on the Semantics node**, and the three
  failure shapes that were each proven by a failing test.
- R-4: Cover, at minimum: colors and contrast ratios, screen-reader needs, Flutter testing approach,
  WinWright testing approach.
- R-5: Produce a per-screen gap analysis across the **active prod UI** (every screen under
  `lib/ui/screens/` reachable in a prod build), recording for each: does every interactive element
  expose an accessible name, AND does it remain activatable.
- R-6: Produce planned remediation tasks from the gaps. Planning only -- fixing every gap is NOT in
  this sprint's scope.
- R-7: Record WinWright actuals in `docs/CODING_VELOCITY.md` (absorbs Sprint 51 IMP-5), so the next
  F129-class item is the first genuinely estimated one.
- R-8: Record the "drive it, don't dump it" verification rule in the standards doc (absorbs Sprint 51
  IMP-6).

**Affected components / files**:
- NEW: a repository accessibility standards document (location decided in Tier 1; `docs/` or
  `docs/adr/` as an ADR-0037 extension)
- `docs/adr/0037-ui-accessibility-standards.md` -- extended or cross-referenced
- `docs/CODING_VELOCITY.md` -- WinWright actuals (R-7)
- NEW: `docs/sprints/SPRINT_52_F133_FINDINGS.md` -- the gap analysis (R-5)

**Dependencies / blockers**: none. Harold's instruction is to do this FIRST.

**Time-box (replaces an estimate)**:
- `[no-history]`. Run in **risk order**, completing each tier before starting the next so the work is
  releasable at any tier boundary:
  1. **Tier 1**: research + the standards document (R-2, R-3, R-4, R-8)
  2. **Tier 2**: per-screen gap analysis across active prod UI (R-5)
  3. **Tier 3**: remediation task planning (R-6) + velocity actuals (R-7)
- If Tier 1 alone exceeds a reasonable session, STOP at the tier boundary, commit the findings doc
  with later tiers marked NOT STARTED, and carry them forward. That is scope management, not an
  unplanned stop.
- `SPRINT_STOPPING_CRITERIA.md` Criterion 9 (400 wall-clock hours) will not be the reason this ends.

**Acceptance criteria**:
- AC-1: The standards document exists, states WCAG 2.1 AA as the target by reference to ADR-0037, and
  covers all four R-4 areas.
- AC-2: The document contains the working wrapper pattern AND the three rejected shapes, each with the
  reason it fails.
- AC-3: The gap analysis lists every active prod screen with an explicit per-screen finding -- no
  screen omitted, and screens with no gaps recorded as "no gaps found" rather than left blank.
- AC-4: Every gap has a proposed remediation task with a step-type from `CODING_VELOCITY.md`.
- AC-5: Tiers not reached are explicitly marked NOT STARTED (never implied complete by omission).
- AC-6: `CODING_VELOCITY.md` contains a WinWright step-type row with the Sprint 51 actuals.

**Tests to write**:
- T-1 (verifies AC-1..AC-5) -- not an automated test: the standards doc and findings doc ARE the
  artifacts. Verified by inspection against the tier list and the screen inventory.
- T-2 (verifies AC-3) -- DOCS: the screen inventory is generated from `lib/ui/screens/*.dart` rather
  than recalled, so no screen can be silently missed.

**Definition of Done**: default task-level DoD PLUS:
- The screen inventory in the gap analysis is derived from the filesystem, not from memory.
- Any pattern recorded in the standards doc is one that was PROVEN by a passing test or a live
  interaction -- not inferred. (Sprint 51: two documented patterns turned out to be wrong.)

**Model**: Fable/Opus -- *why not the cheaper tier*: research synthesis plus a cross-cutting audit that
must reconcile ADR-0037, live code, and harness behavior; the F130-S51 precedent showed cheaper tiers
would need the same reconciliation re-done.

**Step-types**: DOCS (15-20m per doc unit, n=1) + audit discovery `[no-history]`

**Est-Effort**: `[no-history]` -- time-boxed by tier
**Est-Wall**: `[no-history]` -- includes Harold's review at tier boundaries

---

### Task 2 -- F131: WinWright create-path not drivable (Priority 13)

**Value**: This prevents the next session trusting two committed scripts whose own comments assert a
fix that does not work. This enables a decision on whether the create path is a harness limit or an
app-side accessibility defect.

**Requirements** (numbered):
- R-1: Determine the root cause of the Rule Type `RadioButton` selection failure. **Check FIRST**
  whether the radios still expose `SelectionItemPattern` in the UIA projection -- if they do not, this
  is an **accessibility defect** (a radio group unusable by assistive technology), not merely a
  tooling annoyance, and that is the outcome with real user impact.
- R-2: Determine whether the off-screen `Save Rule` button and the input-validation rejection are
  separate causes or consequences of R-1.
- R-3: Based on R-1/R-2, EITHER (a) fix the two `test_f56_*` scripts and re-verify them green, OR
  (b) mark them RETIRED in `mobile-app/test/winwright/README.md` with the reason.
- R-4: If (b), confirm where the coverage those scripts claimed actually lives before retiring them.
  Deleting them without that check converts a visible stale artifact into an invisible coverage hole.
- R-5: Remove or correct the "click the PARENT GROUP" workaround text in both scripts' `description`
  fields either way -- it is currently a documented fix that does not work.

**Affected components / files**:
- `mobile-app/test/winwright/test_f56_create_block_rule.json`
- `mobile-app/test/winwright/test_f56_create_safe_sender.json`
- `mobile-app/test/winwright/README.md`
- `mobile-app/lib/ui/screens/rule_quick_add_screen.dart` -- only if R-1 finds an app-side defect

**Dependencies / blockers**: requires a running dev build for live UIA inspection.

**Acceptance criteria**:
- AC-1: The root cause of the radio-selection failure is stated with evidence (a live tree dump or
  pattern query), not inferred.
- AC-2: An explicit determination is recorded: harness limitation OR app-side accessibility defect.
- AC-3: If app-side, an accessibility remediation task is created (and folded into the Task 1 gap
  analysis rather than duplicated).
- AC-4: Both `test_f56_*` scripts are either green or explicitly marked RETIRED with the reason; the
  non-reproducing workaround text is gone from both.
- AC-5: If retired, the README states where their coverage now lives.

**Tests to write**:
- T-1 (verifies AC-4) -- E2E: if fixed, both scripts run green via the WinWright runner with zero DB
  drift. If retired, no test -- the README entry is the artifact.
- T-2 (verifies AC-3) -- TEST-WIDGET in `test/ui/screens/`: only if R-1 finds an app-side defect;
  proves the radio group exposes a selectable, activatable semantics node.

**Definition of Done**: default task-level DoD PLUS:
- Any claim about UIA behavior is backed by a live probe recorded in the findings, per the Sprint 51
  lesson that a documented-but-unverified harness claim caused three failed runs.

**Model**: Sonnet -- *why not the cheaper tier*: investigation across the UIA projection, the Flutter
widget tree, and the harness; Haiku heuristics cover bounded single-file changes, and the root cause is
not yet known.

**Step-types**: NATIVE-WIN-adjacent investigation `[no-history]` + DOCS

**Est-Effort**: `[no-history]` -- **time-box: stop at the R-1/R-2 determination** and record it. Fixing
(R-3a) versus retiring (R-3b) is a scope decision to make once the cause is known, not before.
**Est-Wall**: `[no-history]`

---

### Task 3 -- F134: Standardize AppBar icon order, remaining 3 screens (Priority 14)

**Value**: This enables one canonical icon order across every screen. This prevents the drift that had
five screens hand-rolling the same five icons in four different orders, under a comment asserting a
"standardized" order that matched none of them.

**Requirements** (numbered):
- R-1: Apply `StandardAppBarActions.build()` to `settings_screen.dart`, producing
  `Review "No Rule" Items, View Scan History, Accounts, Settings, Help`.
- R-2: Apply it to `results_display_screen.dart` (Demo Scan and Live Scan) with **Download** and
  **Find** as `leading` screen-specific actions, before the standard block.
- R-3: Apply it to `no_rule_review_screen.dart`, ADDING the four missing icons so the order becomes
  `Refresh, View Scan History, Accounts, Settings, Help`.
- R-4: Help is LAST on every surface (Harold confirmed 2026-07-30).
- R-5: No screen may keep a hand-rolled copy of the standard block afterwards -- the builder is the
  single definition.

**Affected components / files**:
- `mobile-app/lib/ui/screens/settings_screen.dart`
- `mobile-app/lib/ui/screens/results_display_screen.dart`
- `mobile-app/lib/ui/screens/no_rule_review_screen.dart`
- `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart` -- only if a new `leading`/include flag is
  needed

**Dependencies / blockers**: **Depends on Task 4 (F135)** for the No-Rule screen's Settings icon --
that screen is cross-account and has no `accountId` of its own, so it needs the session-scoped
resolver to know which account Settings should open.

**Acceptance criteria**:
- AC-1: All three screens render the canonical order, verified on a live build.
- AC-2: The No-Rule screen shows all five icons (`Refresh` + the four added).
- AC-3: `grep` for hand-rolled `IconButton(tooltip: 'View Scan History')` (and the other four) returns
  matches ONLY inside `standard_app_bar_actions.dart`.
- AC-4: Help is the last action before the auto-appended Exit on every screen.

**Tests to write**:
- T-1 (verifies AC-1/AC-2/AC-4) -- TEST-WIDGET in `test/ui/widgets/`: pumps each screen's AppBar and
  asserts the action tooltips appear in the canonical ORDER (order is the contract, not mere
  presence).
- T-2 (verifies AC-3) -- policy-style test or a documented grep in the DoD: no screen re-declares a
  standard action outside the builder.

**Definition of Done**: default task-level DoD PLUS:
- Verified on a live Windows build, not only in widget tests -- icon order is a visual contract.

**Model**: Haiku -- *why not the cheaper tier*: n/a, this IS the cheapest tier. The builder already
exists and each screen is a mechanical call-site replacement.

**Step-types**: UI-MOVE x3 (3-6m each, median 3) + TEST-WIDGET (20-25m, median 22)

**Est-Effort**: 30-45m
**Est-Wall**: 60m (includes a live-build visual check)

---

### Task 4 -- F135: Session-scoped account selection + No-Rule default screen (Priority 15)

**Value**: This enables the app to stop re-asking which account the user already chose. This prevents
the account picker appearing on screens that do not need an account at all.

**Requirements** (numbered):
- R-1: Settings tabs prompt **per tab**: the Account, Manual Scan and Background tabs are
  account-scoped and may prompt; the **General tab must NOT prompt** (it is cross-account -- rules,
  retention, privacy).
- R-2: Manual Live Scan resolves through the same `_resolveAccountForScopedDestination()` rule.
- R-3: When one or more accounts exist, the app's default screen becomes **Review "No Rule" Items**
  rather than Account Selection.
- R-4: A session selection, once made, satisfies every later account-scoped destination until the user
  returns to the Account page and selects another (Harold's rule, verbatim in the retrospective).
- R-5: Screens that are cross-account -- Review "No Rule" Items, Scan History, Settings > General --
  must never trigger the picker.

**Affected components / files**:
- `mobile-app/lib/ui/screens/settings_screen.dart` -- per-tab resolution (R-1)
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` / the Manual Scan entry path (R-2)
- `mobile-app/lib/main.dart` -- default route (R-3)
- `mobile-app/lib/core/providers/selected_account_provider.dart` -- already exists; extend only if
  needed

**Dependencies / blockers**: none. **Task 3 depends on THIS.**

**Non-functional requirements**:
- The selection stays **session-only** (not persisted) -- Harold approved option A explicitly.
  Persisting it would change startup semantics.

**Acceptance criteria** (Gherkin -- behavioral UI):
- AC-1: Given no account has been selected this session, When the user opens Settings > General, Then
  no picker appears.
- AC-2: Given no account has been selected, When the user opens Settings > Account (or Manual Scan, or
  Background), Then the picker appears once; When they then open another account-scoped tab, Then it
  does NOT appear again.
- AC-3: Given exactly one account is configured, When any account-scoped destination is opened, Then
  no picker appears and that account is used.
- AC-4: Given one or more accounts exist, When the app starts, Then the Review "No Rule" Items screen
  is shown.
- AC-5: Given zero accounts exist, When the app starts, Then the Account Selection screen is shown
  (there is nothing to review).
- AC-6: Given an account is selected and then deleted, When an account-scoped destination is opened,
  Then the stale selection is discarded and the picker appears.

**Tests to write**:
- T-1 (verifies AC-1/AC-2/AC-5) -- TEST-WIDGET in `test/ui/screens/settings_screen_test.dart`: proves
  which tabs prompt and which do not.
- T-2 (verifies AC-3/AC-6) -- TEST-UNIT in `test/unit/selected_account_provider_test.dart`: single
  account auto-selects; `clearIfSelected` discards only the matching account.
- T-3 (verifies AC-4/AC-5) -- TEST-WIDGET: default route with accounts vs without.

**Definition of Done**: default task-level DoD PLUS:
- The zero-account startup path is manually verified, not only unit-tested -- it is the first thing a
  brand-new Store user sees.

**Model**: Sonnet -- *why not the cheaper tier*: R-3 changes app startup routing and interacts with
account lifecycle; Haiku heuristics cover single-file bounded changes, and this spans routing,
Settings tab state, and provider lifecycle.

**Step-types**: UI-GESTURE (7-15m, median 7) + UI-MOVE (3-6m) + TEST-WIDGET x2 (20-25m each) +
TEST-UNIT (4-10m)

**Est-Effort**: 60-90m
**Est-Wall**: 120m (includes manual verification of both startup paths)

**Decision-class interrupts**:
- **Class-1 (Chief Architect)**: R-3 changes the app's default screen -- a startup-behavior change.
  Surfaced here for approval AS PART OF this plan. Two sub-decisions to confirm at approval:
  (a) zero-account startup goes to Account Selection (AC-5 above -- my recommendation), and
  (b) whether **Back** from the default No-Rule screen exits the app or is suppressed. This plan
  assumes Back exits (standard root-screen behavior); say otherwise and I will change it.

---

### Task 5 -- F136: "Skip" button in the No-Rule item popup (Priority 16)

**Value**: This enables triaging a long No-Rule list without acting on every item. This prevents the
user having to close and reopen the popup to move past an item they do not want to rule on yet.

**Requirements** (numbered):
- R-1: Add a **Skip** button to the item popup header, sized comparably to the safe-sender and rule
  buttons (Harold's wording).
- R-2: Skip leaves the current item **completely unaffected** -- no rule, no safe sender, no processed
  flag, no DB write.
- R-3: Skip advances to the **next unaddressed item** in the CURRENT filtered and sorted order.
- R-4: "Unaddressed" means: not actioned during this popup session and not already covered by a rule
  or safe sender.
- R-5: At the end of the list, Skip closes the popup (rather than wrapping) -- confirm at approval.
- R-6: A skipped item stays in the list; skipping is a navigation action, not a state change.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the popup (Live Scan / Scan Results, with
  the "No rule" filter selected)

**Dependencies / blockers**: none.

**Acceptance criteria** (Gherkin -- behavioral UI):
- AC-1: Given the popup is open on item N, When Skip is pressed, Then item N is unchanged in the DB
  and the popup shows the next unaddressed item.
- AC-2: Given items N+1..N+3 were already actioned this session, When Skip is pressed on item N, Then
  the popup shows item N+4.
- AC-3: Given item N is the last unaddressed item, When Skip is pressed, Then the popup closes.
- AC-4: The Skip button's rendered width is within 10% of the Block Entire Domain button's.
- AC-5: Skip carries a tooltip and an accessible name (per the Task 1 standards doc).

**Tests to write**:
- T-1 (verifies AC-1/AC-2/AC-3) -- TEST-WIDGET in `test/ui/screens/`: navigation order and end-of-list
  behavior with a seeded item list.
- T-2 (verifies AC-1) -- TEST-UNIT: proves no persistence call is made on skip (the "completely
  unaffected" contract).
- T-3 (verifies AC-5) -- TEST-WIDGET: the semantics node is named AND activatable (the Sprint 51
  lesson -- assert the tap ACTION, not just the label).

**Definition of Done**: default task-level DoD PLUS:
- None beyond the default.

**Model**: Haiku -- *why not the cheaper tier*: n/a, cheapest tier. Bounded single-file UI addition
with a clear contract once R-5 is confirmed.

**Step-types**: UI-NEW (30-40m, median 35 -- new control with navigation logic) + TEST-WIDGET
(20-25m) + TEST-UNIT (4-10m)

**Est-Effort**: 55-75m
**Est-Wall**: 90m

---

## Sprint Totals

| Task | Item | Model | Est-Effort | Est-Wall |
|---|---|---|---|---|
| 1 | F133-S52 accessibility audit | Fable/Opus | `[no-history]` time-boxed by tier | `[no-history]` |
| 2 | F131 WinWright create path | Sonnet | `[no-history]` time-boxed to the determination | `[no-history]` |
| 3 | F134 AppBar order (3 screens) | Haiku | 30-45m | 60m |
| 4 | F135 account selection + default screen | Sonnet | 60-90m | 120m |
| 5 | F136 Skip button | Haiku | 55-75m | 90m |

**Calibrated subtotal (Tasks 3-5)**: 145-210m Est-Effort / 270m Est-Wall.
**Tasks 1-2 are NOT folded into a total** -- adding an invented number to a real one produces a total
that looks calibrated and is not (Sprint 51 Estimating Integrity note).

**Execution order**: Task 1 first (Harold's instruction), then **Task 4 before Task 3** (F134 depends
on F135 for the No-Rule Settings icon), then Task 5. Task 2 is independent and can run at any point;
suggest after Task 1's Tier 2, since its R-1 finding may feed the gap analysis.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Task 1 discovery exceeds the sprint | High | Medium | Tiered time-box; releasable at any tier boundary; later tiers marked NOT STARTED |
| Task 2 root cause is app-side, expanding scope | Medium | Medium | Time-boxed to the DETERMINATION; fix-vs-retire is a separate decision once known |
| F135 default-screen change surprises users | Medium | High | Class-1 surfaced at approval; both startup paths manually verified |
| Accessibility fixes named-but-unclickable again | Medium | High | Task 1 DoD requires proven patterns; T-3 on Task 5 asserts the tap ACTION |
| Task 3 blocked waiting on Task 4 | Low | Low | Execution order puts Task 4 first; Task 3's other two screens are unblocked |

---

## Definition of Ready check

All five tasks have Value, Requirements, Affected files, Dependencies, Acceptance criteria and
Tests-to-write filled in. **One open Class-1 question remains** (Task 4's default-screen sub-decisions),
surfaced above for resolution at Phase 3.7 approval rather than assumed.
