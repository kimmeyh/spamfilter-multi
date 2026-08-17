# Sprint 61 Plan

**Status**: **APPROVED (Harold, Phase 3.7, 2026-08-17)** -- executing.
**Branch**: `feature/20260816_Sprint_61` | **PR**: not yet created (Phase 3.3.1 fires at approval)
**Dates**: 2026-08-17 to TBD
**Prior sprint**: Sprint 60 CLOSED (PR #335 merged to develop and main); 0.10.0.0 / Submission 17 CERTIFIED AND LIVE 2026-08-16 (~26 minutes submit-to-live, measured).

## Sprint Goal

Encode the release cycle the project already runs but never wrote down, then close the highest-value UX and parity gaps surfaced by Sprint 60's Android walk-through -- with every change held to the cross-platform rule below.

## STANDING CONSTRAINT FOR EVERY TASK IN THIS SPRINT (Harold, 2026-08-17)

> Everything must account for BOTH the Windows app and the Android app. The governing rule --
> formalized as the parity ADR in Task 6 (F162) -- is: **functionality and UI are the SAME on both
> platforms unless they cannot be; where they cannot be, the difference is implemented as an
> explicit, minimal PLATFORM EXCEPTION covering only what is actually needed.**
> This applies to **all backend code, frontend code, data, architecture, development, security,
> testing, and deployment** -- not just widgets.

Practical consequences, applied to every card below:

1. **Shared-first**: a change lands in shared code unless a platform genuinely cannot support it. Eight screens do not get eight edits when one shared builder serves them (Task 5).
2. **Exceptions are declared, not implied**: any platform fork carries an inline comment naming WHAT cannot be shared and WHY, so a reader never has to guess whether a fork was deliberate.
3. **Tests cover both platforms**: a widget test exercising only one platform's branch does not satisfy a card whose behavior is cross-platform (the F143 pattern -- assert the touch branch AND the desktop guard).
4. **The precedent this rule exists to prevent**: in Sprint 60 the `scan_results` accounts-row creation lived ONLY in the Windows background worker, so Windows masked a shared-code gap for months while Android silently persisted nothing from any scan. Backend parity is not cosmetic.

## Scope -- 9 tasks

Execution order is the task order below. Task 0 is the pre-approved chore; Task 1 (F170) runs first among the feature work by Harold's explicit instruction.

| # | ID | Title | Priority | Model | Est |
|---|----|-------|----------|-------|-----|
| 0 | -- | Line-ending normalization (`.gitattributes` + renormalize) | pre-approved | Haiku | 20-40m |
| 1 | F170 | Encode the post-merge Release Cycle | 2 | Sonnet | 180-240m |
| 2 | F169 | Account filter: chip row -> dropdown | 4 | Sonnet | 60-120m |
| 3 | F168 | Background/bulk scan folder scope visibility | 6 | Sonnet | 60-120m |
| 4 | F172 | Version number on 8 screens | 10 | Haiku | 60-120m |
| 5 | F171 | Minimum-window UI sweep (1024x640 epx) | 8 | Sonnet | 120-180m |
| 6 | F162 | Windows-vs-Android parity audit + ADR | 18 | Fable/Opus | 240-300m |
| 7 | F167 | Android Help text adaptation | 22 | Sonnet | 120-180m |
| 8 | F161 | Android background-scan scheduler + POST_NOTIFICATIONS | 24 | Fable/Opus | 180-300m |

**Total Est-Effort**: ~1,040-1,600 minutes (~17-27 hours).

**Sequencing rationale** (not merely priority order):
- **Task 0 first**: a repo-wide content-neutral renormalization must not be tangled with feature diffs.
- **F170 next**: it fixes the process everything else runs inside, and its hook slice already stopped three false positives.
- **F172 before F171**: F172 ADDS an element to an AppBar row that already overflows at narrow widths, so the minimum-window sweep must run after it or it measures a layout about to change.
- **F162 before F167 and F161**: both are explicitly "governed by the parity ADR" -- doing them first would mean writing the exceptions before the rule that defines them.
- **F161 last**: largest, most self-contained, and the only task whose absence blocks nothing else.

---

### Task 0 -- Line-ending normalization (pre-approved chore, Harold 2026-08-16)

**Value**: This prevents every commit from emitting CRLF/LF warnings and removes a whole class of spurious diff noise.

**Requirements**:
- R-1: Add `.gitattributes` with `* text=auto eol=lf`, plus `*.bat`/`*.cmd`/`*.ps1` pinned `eol=crlf` (cmd.exe LF-label edge cases; Authenticode signature blocks assume CRLF).
- R-2: One-time `git add --renormalize .` commit, with that commit's hash recorded in `.git-blame-ignore-revs`.
- R-3: Runs as the FIRST commits on this branch so the repo-wide diff stays out of feature history.

**Affected components / files**: `.gitattributes` (new), `.git-blame-ignore-revs` (new), repo-wide renormalization.

**Dependencies / blockers**: None. Must precede all other tasks.

**Acceptance criteria**:
- AC-1: A subsequent commit produces no "LF will be replaced by CRLF" warnings.
- AC-2: `flutter test` and `flutter analyze` are green after renormalization (line-ending changes must not alter behavior).
- AC-3: The renormalize commit hash is in `.git-blame-ignore-revs`.

**Tests to write**: None new -- AC-2 is the existing full suite acting as the regression gate. Stated explicitly rather than inventing a test for a whitespace change.

**Definition of Done**: default task-level DoD PLUS:
- Watch-item recorded: if Visual Studio regenerates `windows/runner` files as phantom-dirty CRLF, add a targeted `eol=crlf` line for those paths rather than reverting the policy.

**Model**: Haiku -- *why not a cheaper tier*: n/a, cheapest tier. Mechanical and fully specified.

**Step-types**: DOCS, HOOK

**Est-Effort**: 20-40m

_**Risk & rollback**_: Risk -- a repo-wide rewrite touching many files. Mitigation: content-neutral by construction, guarded by the full suite (AC-2). Rollback: revert the two commits.

**COMPLETION NOTES (2026-08-17)**: DONE. `.gitattributes` added (LF everywhere; `.bat`/`.cmd`/`.ps1` pinned CRLF; binary asset types marked so they are never touched). **`git add --renormalize .` produced ZERO changed files** -- a useful finding: the repo was ALREADY LF-consistent in storage, so the constant "LF will be replaced by CRLF" warnings came entirely from checkout-time conversion, not from mixed content. Consequences: (a) there is no renormalization commit and blame history is untouched, so the anticipated `.git-blame-ignore-revs` entry does not exist; the file is still created, with that fact recorded, so the next bulk formatting change has an obvious home; (b) AC-1 (no warnings on a later commit) is verified by observation on subsequent commits rather than by the diff. AC-2 verified: `flutter analyze` clean, full suite **1,862 passed / 26 skipped / 0 failed**. AC-3 re-read against reality: no hash to record, and the file states why. Actual effort ~15m (est 20-40m).

---

### Task 1 -- F170: Encode the post-merge Release Cycle (Priority 2)

**Value**: This prevents the process the project actually runs from living only in a state file, and stops a hook from firing on correct work.

**Requirements** (numbered, detailed):
- R-1: The cycle is documented ONCE, in a named form, cross-referenced from every doc that touches it. The name must NOT be "Step 7" -- that already means two different things (`STORE_RELEASE_PROCESS.md` Step 7 = post-submission close-out; the retrospective protocol's Step 7 = apply improvements).
- R-2: Canonical order: sprint PR merged to `develop` -> **`develop` merged to `main` (Harold, runs IN PARALLEL -- not a blocking gate)** -> **Backlog Refinement pass 1 = COMPLETENESS SWEEP** (verify every sprint-close step was captured and completed) -> **Microsoft Store release** -> once the submission is in process, **Backlog Refinement pass 2 = SCOPE SELECTION** -> Phase 3 planning.
- R-2a (**Harold, 2026-08-17, answering the Phase 3.7 question**): the `main` merge is Harold's action and does **NOT block progress to Backlog Refinement pass 1** -- work continues while it happens. It becomes a **HARD DEPENDENCY at the MSIX build only**, because the Store MSIX is built from the prod worktree on `main`. The rule to encode is therefore: *do not wait for the `main` merge; DO confirm `main` is merged before building the MSIX.* Encode the confirmation as an explicit build-time precondition (verify `main` actually contains the sprint's merge -- e.g. the prod worktree is not N commits behind origin/main, the failure mode hit in Sprint 60 where the worktree sat 33 commits behind), not as a step that idles waiting.
- R-2b (**Harold, 2026-08-17**): the dev version bump may happen **before or after** the `main` merge. The bump lands in the NEXT sprint's branch, which never touches `main`, so the two are independent -- this DISSOLVES the R-7 ordering conflict rather than requiring a winner. Encode that independence explicitly so a future reader does not re-derive it as a conflict.
- R-3: `SPRINT_EXECUTION_WORKFLOW.md`'s "Canonical Next Steps progression" -- currently flagged MUST NOT be reordered -- is CORRECTED: rule 5 ("Sprint N+1 begins only AFTER merge to develop") jumps straight from the develop merge to the next sprint, omitting the `main` merge, the release, and both refinement passes.
- R-4: `SPRINT_CHECKLIST.md`'s Store section stops being conditional ("if applicable") and stops burying `Merge develop to main` as a Store sub-step; a refinement step appears after merge, which today it does not, in either pass.
- R-5: `BACKLOG_REFINEMENT.md` gains the two-pass distinction AND resolves its own contradiction: it says refinement is "on-demand / when requested by the Product Owner" while `SPRINT_EXECUTION_WORKFLOW.md` and `SPRINT_CHECKLIST.md` both say mandatory-every-sprint. `ALL_SPRINTS_MASTER_PLAN.md` carries the same stale trigger.
- R-6: `ALL_SPRINTS_MASTER_PLAN.md`'s Maintenance Guide gains a Store-release row (the release mutates that file today with no trigger listed) and splits its single undifferentiated "Backlog Refinement" row into the two passes.
- R-7: `STORE_RELEASE_PROCESS.md` states WHERE in the cycle a release sits. **RESOLVED by Harold 2026-08-17 (see R-2b): there is no conflict to adjudicate.** The version bump happens in the next sprint's branch and never touches `main`, so bump-before and bump-after are equally valid; the only real constraint is that `main` must be merged before the MSIX is BUILT. Rewrite the step ordering to state that constraint (a build-time precondition on `main`) instead of implying a fixed sequence, and remove the ambiguous parenthetical ("We usually merge first, then build ...") that shows the ambiguity was known and unresolved.
- R-8: The `backlog-refinement` skill gains the two-pass modes (its step 5 currently always captures a scope selection -- wrong for pass 1). `startup-check` gains a recognizable phase state for "in release cycle". `phase-check`'s 1-7 model accommodates the cycle.
- R-9: `sprint-auto-advance.ps1`'s exemption for this window becomes DELIBERATE. Today it survives only because no plan file exists yet -- and the checklist itself mandates a next-sprint stub at Phase 7.7, which breaks that accident.

**Affected components / files**:
- `docs/SPRINT_EXECUTION_WORKFLOW.md` -- Phase Numbering table, Phase 7.9 Next Steps menu, the canonical progression block
- `docs/SPRINT_CHECKLIST.md` -- Post-Merge Cleanup, conditional Store section, Ready-for-Next-Sprint
- `docs/BACKLOG_REFINEMENT.md` -- When-to-Conduct, six-step process, refinement checklist
- `docs/STORE_RELEASE_PROCESS.md` -- scope/audience header, Step 5 ordering, Step 7 terminal action
- `docs/ALL_SPRINTS_MASTER_PLAN.md` -- Maintenance Guide table
- `CLAUDE.md` -- branch policy (says WHO/HOW, never WHEN), Auto-Advance window (defined by two in-sprint endpoints; never names this outside-the-window region)
- `.claude/skills/backlog-refinement/`, `startup-check/`, `phase-check/`
- `.claude/hooks/sprint-auto-advance.ps1` -- deliberate cycle exemption
- `.claude/hooks/verify-closeout-complete.ps1` -- **ALREADY DONE 2026-08-16** (precondition on `plan_approved`, fixture + case, mutation-verified, suite 46/46)

**Dependencies / blockers**: Task 0 first (branch hygiene).

**Non-functional requirements**:
- Platform: N/A (process docs and tooling), but the cycle text must state that this Store release covers the WINDOWS app while the Android/Play track (F94, GP-*) is a SEPARATE future release path -- otherwise the cycle silently reads as Windows-only, violating the standing constraint by omission.
- Doc hygiene: four version footers are stale (workflow 2.0/Feb-2026, checklist 2.4/Apr-2026, refinement 1.3/Jul-2026, store process "first version"). Refresh those touched.

**Acceptance criteria** (measurable, traceable):
- AC-1: Searching the repo for the cycle's chosen name returns the single authoritative definition plus cross-references -- not multiple competing descriptions.
- AC-2: The corrected "Canonical Next Steps progression" contains the `main` merge, the Store release, and both refinement passes in Harold's order.
- AC-3: `BACKLOG_REFINEMENT.md` no longer says refinement is on-demand/PO-requested while two other docs call it mandatory; the two passes have distinct stated purposes and outputs.
- AC-4: Given a sprint at pre-kickoff (plan not approved, no scope), When a turn ends with a close-out claim, Then `verify-closeout-complete` allows it -- and Given an approved plan with a null `pr_number`, Then it still blocks. **(Already satisfied and mutation-verified; re-asserted here as a regression gate.)**
- AC-5: `.claude/hooks/run-test-cases.ps1` passes at 46/46 or higher, with any new cases covering the cycle window.

**Tests to write**:
- T-1 (verifies AC-4/AC-5) -- HOOK in `.claude/hooks/test-cases/`: pre-kickoff allow case **[DONE]**; add an auto-advance case covering "plan stub exists but plan not approved" (the accident R-9 removes).
- T-2 (verifies AC-1/AC-2/AC-3) -- DOCS: no automated test exists for prose. Verification is a same-turn read-back of each edited section against its requirement, recorded in the completion notes. Stated plainly rather than implying a gate.

**Definition of Done**: default task-level DoD PLUS:
- Every doc edited has its version footer and change-log line updated (they are the audit trail this task exists to restore).

**Model**: Sonnet -- *why not the cheaper tier*: multi-document consistency work with a known contradiction to resolve and an authoritative-but-wrong ordering statement to correct; Haiku is not a fit for reconciling conflicting sources of truth.

**Step-types**: DOCS, HOOK

**Est-Effort**: 180-240m

_**Risk & rollback**_: Risk -- rewriting a MUST-NOT-BE-REORDERED block could contradict a rule Harold still wants. Mitigation: the correction is additive (insert the missing steps, keep the five existing rules' intent), surfaced as Class-3 below. Rollback: docs-only, revert the commit.

_**Decision-class interrupts**_: **Class 3 (Scrum Master)** -- R-3 changes an explicitly frozen process statement; R-7 resolves an ordering conflict between two authoritative docs. Both surfaced HERE for Phase 3.7 approval rather than mid-execution.

---

### Task 2 -- F169: Review No Rule Items account filter -> single-select dropdown (Priority 4)

**Value**: This prevents an account being unreachable on a phone -- today the second chip clips and the third is off-screen entirely.

**Requirements** (numbered, detailed):
- R-1: The horizontally scrolling chip Row in `_buildAccountFilter` is replaced by ONE single-select dropdown, defaulting to "All Accounts".
- R-2: The face shows the active selection with its live count; each entry shows its account email and item count.
- R-3: EVERY configured account is reachable at any window width -- no horizontal scroll, no clipping (Harold: "All account must be viewable").
- R-4: Selecting an account preserves today's behavior exactly: sets `_accountFilter`, re-applies the filter, and calls `_clearSelection()` (the current chip handler does this; losing it would let a hidden selection carry across accounts).
- R-5: Reuse the F166 dropdown pattern from `results_display_screen` rather than inventing a second one; read that builder before diverging.

**Affected components / files**:
- `mobile-app/lib/ui/screens/no_rule_review_screen.dart:793-831` -- `_buildAccountFilter`, `_buildAccountChip`

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: shared widget, identical on Windows and Android -- Harold explicitly approved the same treatment on both. NO platform fork expected; if one proves necessary it is a declared exception per the standing constraint.
- Accessibility: the dropdown keeps an accessible name and stays keyboard-reachable on desktop (ADR-0037) -- a mouse/keyboard user must not lose the ability to switch accounts.
- Account-scoping: filtering stays per-account exactly as today.

**Acceptance criteria** (measurable, traceable):
- AC-1: At 599px width with 3 configured accounts, every account is selectable from the dropdown (current failure: accounts render off-viewport).
- AC-2 (behavioral): Given a selection is active under account A, When the user switches to account B, Then the selection is cleared and the list shows B's items.
- AC-3: The default face reads "All Accounts" with the total item count.
- AC-4: Desktop behavior is unchanged in substance -- switching still works by mouse and keyboard.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-WIDGET in `test/ui/screens/no_rule_review_account_dropdown_test.dart`: at phone width with 3 accounts seeded, every account is reachable from the opened dropdown.
- T-2 (verifies AC-2) -- TEST-WIDGET, same file: a selection made under account A is gone after switching to B.
- T-3 (verifies AC-3) -- TEST-WIDGET, same file: default face reads All Accounts with the total.

**Definition of Done**: default task-level DoD PLUS:
- Each new test mutation-verified (break what it guards, confirm red) -- Sprint 60 produced three tests that passed while proving nothing.

**Model**: Sonnet -- *why not the cheaper tier*: replaces an interaction model on the app's default screen with selection-state semantics to preserve; the F166 pattern must be read and followed, not approximated.

**Step-types**: UI-MOVE, TEST-WIDGET

**Est-Effort**: 60-120m

**COMPLETION NOTES (2026-08-17)**: DONE. Chip Row replaced by a `PopupMenuButton` dropdown mirroring the F166 pattern; face shows the active selection with its count, entries carry per-account counts and a check on the active one. `_clearSelection()` preserved via an extracted `_onAccountFilterChanged`. Dead `_buildAccountChip` removed (analyzer caught it as unreferenced). All 3 ACs tested at 411px phone width; AC-2 mutation-verified (removing `_clearSelection()` turns it red).

**TWO OVERFLOW DEFECTS FOUND AND FIXED, one of them PRE-EXISTING**: (a) the new menu-entry Row overflowed 7.7px at phone width -- fixed with Flexible + ellipsis; (b) **`_buildSelectionBar` overflowed by ~105px at 411px, and this was NOT caused by F169** -- verified by diff that the selection bar is untouched by this task; its fixed 40px gap plus three intrinsic-width children simply never fit a phone, and no prior test had rendered this screen at phone width. Fixed by flexing the label and replacing the fixed gap + Spacer with a single flexible spacer. This is exactly the defect class F171 (Task 5) exists to hunt, found early because F169's tests were written at the width the bug reproduces at.

**Suite note**: an initial full run reported 17 "loading" failures; re-running with the project's documented `--concurrency=4` gave **1,865 passed / 26 skipped / 0 failed**, confirming those were a resource artifact rather than real failures. Analyze clean. Actual effort ~35m (est 60-120m).

---

### Task 3 -- F168: Background/bulk scan folder scope visibility (Priority 6)

**Value**: This prevents a silently mis-scoped background scan from looking identical to "no spam found".

**Requirements** (numbered, detailed):
- R-1: The folder scope a background scan WILL use is visible where the user configures it -- not only in the results header after the fact.
- R-2: When a background scope omits the Inbox, the user is warned, since inbox coverage is the app's core purpose. Warning, not prohibition -- a deliberate Bulk-only scope stays possible.
- R-3: Evaluate whether background and manual scopes should remain INDEPENDENTLY editable, or whether one selection with an explicit opt-out is less error-prone. **Recommendation only** -- changing the model is a Class-1/2 decision surfaced for Harold, not made inside this task.
- R-4: No change to scan behavior. The scanner behaved correctly; only the configuration surface misled.

**Affected components / files**:
- `mobile-app/lib/ui/screens/settings_screen.dart` -- Background tab folder selection
- `mobile-app/lib/core/storage/settings_store.dart:712-732` -- `getEffectiveFolders` (read for resolution order; not expected to change under R-4)

**Dependencies / blockers**: None. Harold confirmed the root cause 2026-08-16 ("looks like I did not select inbox... but thought I had"), so no investigation phase is needed.

**Non-functional requirements**:
- Platform: the SETTINGS surface is shared, so the warning is shared. Android has no background scheduler until Task 8 -- so the Android presentation must not promise background scanning that does not run yet. That is a declared platform exception, worded in coordination with Task 8.
- Data: prod and dev keep independent settings stores (ADR-0035); verify against the PRODUCTION surface, and never write to the real prod data directory during testing (Sprint 56 F148 precedent).

**Acceptance criteria** (measurable, traceable):
- AC-1: The background folder scope is visible at configuration time, listing the folders that will actually be scanned.
- AC-2 (behavioral): Given a background scope excluding the Inbox, When the user views/saves it, Then a clear warning states the Inbox will not be scanned.
- AC-3: A scope INCLUDING the Inbox produces no warning (no false alarm).
- AC-4: `getEffectiveFolders` resolution behavior is unchanged (no scan-behavior regression).

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-WIDGET in `test/ui/screens/settings_background_scope_test.dart`: an Inbox-omitting scope surfaces the warning.
- T-2 (verifies AC-3) -- TEST-WIDGET, same file: an Inbox-including scope shows none.
- T-3 (verifies AC-4) -- TEST-UNIT in `test/unit/settings_store_folders_test.dart`: the background/manual resolution order is pinned so a UI change cannot silently alter which folders a scan uses.

**Definition of Done**: default task-level DoD PLUS:
- R-3's recommendation written up in the completion notes for Harold's decision, whether or not it is acted on.

**Model**: Sonnet -- *why not the cheaper tier*: a UX judgment about warning placement plus a settings-model recommendation; not a mechanical edit.

**Step-types**: UI-MOVE, TEST-WIDGET, TEST-UNIT

**Est-Effort**: 60-120m

_**Decision-class interrupts**_: **Class 1/2** -- R-3 (merging the two folder scopes) would change a persistence/configuration model. Recommend only; surface at Manual Validation.

---

### Task 4 -- F172: Version number on 8 screens, right of the `?` icon (Priority 10)

**Value**: This enables every screenshot -- bug report, MV round, Store listing -- to carry the build it came from.

**Requirements** (numbered, detailed):
- R-1: `Version <n>.<n>.<n>` renders immediately to the RIGHT of the `?` (Help) icon on: Review No Rule Items, Scan History, Scan Results, Manual Scan, Live Scan's Scan Results, Select Account, Settings, Help.
- R-2: The version comes from the existing runtime source `AppVersion.get()` (`lib/core/services/app_version.dart`) -- NOT a new literal. A hardcoded string would drift immediately and would be caught by `version_consistency_test`, which greps `lib/` for `Version <X.Y.Z>` strings.
- R-3: `AppEnvironment.displaySuffix` still appends, so dev builds keep showing `[DEV]`.
- R-4: Implemented ONCE in the shared `StandardAppBarActions.build` (where Help is already "ALWAYS LAST"), so all 8 screens inherit it -- not 8 separate edits. Any screen NOT in the list that also uses the shared builder will inherit it too; confirm that is acceptable rather than discovering it later.
- R-5: `test/policy/appbar_action_order_test.dart` asserts a canonical action order and carries an exemptions map -- update it deliberately, and keep it passing.

**Affected components / files**:
- `mobile-app/lib/ui/widgets/standard_app_bar_actions.dart:240+` -- append after the Help IconButton
- `mobile-app/lib/core/services/app_version.dart` -- read-only (the source)
- `mobile-app/test/policy/appbar_action_order_test.dart` -- canonical-order update

**Dependencies / blockers**: None, but Task 5 (F171) must run AFTER this.

**Non-functional requirements**:
- Platform: shared builder -> identical on Windows and Android. **This is the parity rule's easiest win and its clearest test: one edit, both apps.**
- Accessibility: the version text is informational; it must not steal focus order from the action buttons, and must meet contrast (ADR-0037).
- Layout: `AppVersion.get()` is ASYNC. The AppBar must not flicker or reflow when it resolves, and must not throw before it does -- render nothing (or a stable-width placeholder) until available.
- **Overflow risk (known)**: this row ALREADY overflows at ~411px in widget tests. Adding a text element makes that worse. The text must degrade (ellipsize/hide) at narrow widths rather than overflow; Task 5 re-checks it.

**Acceptance criteria** (measurable, traceable):
- AC-1: All 8 named screens display `Version <n>.<n>.<n>` to the right of the `?` icon.
- AC-2: The displayed version equals `pubspec.yaml`'s version (asserted, not eyeballed) and carries `[DEV]` on a dev build.
- AC-3: At 1024x640 epx and at phone width, the AppBar does not overflow with the version present.
- AC-4: `appbar_action_order_test` and `version_consistency_test` both pass.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-WIDGET in `test/ui/widgets/appbar_version_display_test.dart`: the version renders after the Help icon in the shared builder.
- T-2 (verifies AC-2) -- TEST-WIDGET, same file: the rendered string matches the runtime `AppVersion` value, and the dev suffix appears when set.
- T-3 (verifies AC-3) -- TEST-WIDGET, same file: no overflow at 1024x640 and at 411px.

**Definition of Done**: default task-level DoD PLUS:
- Confirm on BOTH a Windows build and the Android emulator that the version renders -- a shared-code claim verified on one platform is not verified.

**Model**: Haiku -- *why not a cheaper tier*: n/a, cheapest tier. Mechanical: one shared-widget edit against an existing runtime source, with the gates already written.

**Step-types**: UI-MOVE, TEST-WIDGET

**Est-Effort**: 60-120m

---

### Task 5 -- F171: Minimum-supported-window UI sweep at 1024x640 epx (Priority 8)

**Value**: This prevents shipping screens that are unusable at Microsoft's documented Windows 11 minimum window size.

**Requirements** (numbered, detailed):
- R-1: Walk the typical UI flows with the window at **1024x640 epx, maximized**, per Microsoft's stated Windows 11 minimum display.
- R-2: "Usable" is defined concretely BEFORE the sweep: nothing clipped, no primary action off-window or unreachable, no horizontal scrolling required to reach a control, no overlapping text, and popups/dialogs fully within the window.
- R-3: The screen/flow list walked is RECORDED so the next run is comparable rather than ad-hoc.
- R-4: Findings are fixed in-sprint if small; anything larger is filed with the failing size and screen named.
- R-5: Android is checked for the same CLASS of defect (clipping/unreachable controls at its own constrained sizes) per the parity rule -- the epx number is Windows-specific, the failure mode is not.

**Affected components / files**:
- Determined by findings. Likely candidates given Sprint 60 history: `standard_app_bar_actions.dart` (already overflows narrow), `results_display_screen.dart` (compact fold at <600), `no_rule_review_screen.dart`.

**Dependencies / blockers**: Runs AFTER Task 4, which adds an element to the AppBar row this sweep measures.

**Non-functional requirements**:
- Platform: Windows is the sized target; Android gets the equivalent-class check. Fixes land shared unless they genuinely cannot.
- Testing: where a defect is found, the regression test asserts at the SIZE THAT REPRODUCES IT -- Sprint 60's lesson, where a popup test at 900px stayed green against broken code and had to be tightened to 650px.

**Acceptance criteria** (measurable, traceable):
- AC-1: Every screen in the recorded list has a pass/fail result at 1024x640 epx.
- AC-2: Each failure names the screen, the symptom, and whether it was fixed in-sprint or filed.
- AC-3: Any in-sprint fix carries a regression test at a size that genuinely reproduces the pre-fix failure (mutation-verified).

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-WIDGET, per finding, in the relevant screen's existing test file: asserts the specific clipping/overflow does not recur at the reproducing size.

**Definition of Done**: default task-level DoD PLUS:
- The screen list and results recorded in the completion notes (a sweep with no recorded evidence cannot be audited -- Sprint 59 IMP-5).

**Model**: Sonnet -- *why not the cheaper tier*: judgment about what "usable" means per screen, plus fix-now vs file dispositions; a checklist-runner tier would produce findings without dispositions.

**Step-types**: TEST-WIDGET, UI-MOVE

**Est-Effort**: 120-180m

---

### Task 6 -- F162: Windows-vs-Android parity audit + parity ADR (Priority 18)

**Value**: This enables every future cross-platform decision to cite a rule instead of re-litigating it.

**Requirements** (numbered, detailed):
- R-1: A new ADR (next number after 0041) states Harold's rule: functionality and UI are the SAME on both platforms unless they cannot be; where they cannot be, the difference is an explicit, minimal PLATFORM EXCEPTION covering only what is needed.
- R-2: The ADR's scope is explicitly ALL layers -- backend code, frontend code, data, architecture, development, security, testing, deployment -- not just UI.
- R-3: The ADR defines HOW an exception is implemented and recorded (where the fork lives, how it is commented, how it is tested) so future exceptions are consistent and auditable.
- R-4: A full-functionality walk-through compares Windows against Android on VERIFIED-current installs (the Sprint 60 stale-app incident: an ancient `com.example` package made archaeology look like divergence -- `pm list packages` + version check FIRST).
- R-5: Every divergence found is filed REFERENCING the ADR rule it violates; where an existing backlog item already covers one, UPDATE it rather than duplicating (Harold's instruction at registration).
- R-6: Known divergences already on record are dispositioned: the AppBar icon row overflowing at phone widths, and Android having no background scheduler until Task 8.

**Affected components / files**:
- `docs/adr/00XX-cross-platform-parity.md` (new), `docs/adr/README.md` (index)
- `docs/ALL_SPRINTS_MASTER_PLAN.md` -- new/updated divergence items
- No production code changes expected; this task produces the rule and the findings.

**Dependencies / blockers**: Must land BEFORE Tasks 7 and 8, both governed by this ADR.

**Non-functional requirements**:
- Platform: this IS the platform task. Both apps exercised against verified-current builds.
- Testing: the ADR must state the testing consequence -- a cross-platform behavior needs coverage proving BOTH branches, not one (the F143 precedent).

**Acceptance criteria** (measurable, traceable):
- AC-1: The ADR exists, is indexed, and states the rule, its all-layers scope, and the exception mechanism.
- AC-2: The walk-through's screen/flow list and per-screen result are recorded, so the next run is comparable.
- AC-3: Every divergence found is either a filed item citing the ADR or an updated existing item -- with a stated COUNT, so "none found" is a claim rather than a silence.
- AC-4: The install verification (package name + version, both platforms) is recorded before any comparison.

**Tests to write**:
- T-1 (verifies AC-3) -- DOCS/audit: no automated test; the deliverable is the findings list. Stated plainly rather than implying a gate.
- T-2 (verifies AC-1's testing clause) -- TEST-POLICY (optional, only if cheaply assertable and non-noisy): a gate that a `Platform.` fork in `lib/` carries an explanatory comment. Otherwise record as deliberately unwatched.

**Definition of Done**: default task-level DoD PLUS:
- Harold's steering honored: he noted this may DESCOPE now that the stale-app confusion is resolved. If the walk-through finds few real divergences, say so and shrink the task rather than manufacturing findings.

**Model**: Fable/Opus -- *why not the cheaper tier*: authoring an ADR that will govern all future cross-platform decisions, plus a judgment-heavy audit; exactly the architectural-decision class reserved for the top tier.

**Step-types**: DOCS, TEST-INTEGRATION (walk-through)

**Est-Effort**: 240-300m

_**Decision-class interrupts**_: **Class 1 (Chief Architect)** -- an ADR IS an architectural decision. The draft is presented for approval before Tasks 7 and 8 treat it as binding.

---

### Task 7 -- F167: Android Help text adaptation (Priority 22)

**Value**: This prevents Android users reading Help that describes Windows-only surfaces.

**Requirements** (numbered, detailed):
- R-1: Help text is updated where it is Windows-specific, following the parity rule: everything the same unless not reasonably possible, then adapt as MINIMALLY as possible while still meeting what is reasonably needed.
- R-2: Every adaptation cites the Task 6 ADR rule that justifies it.
- R-3: Likely touchpoints: `walkthrough.md` and Help sections referencing Task Scheduler background scans, the system tray, window sizing, and keyboard/mouse selection idioms versus the F143 touch idioms.
- R-4: Content lives in `assets/content/` per ADR-0038 -- no long user-facing strings move into Dart source.
- R-5: Coordinate with Task 8: if F161 lands, Android background-scan Help describes real behavior; if it does not, Help must not promise it.

**Affected components / files**:
- `mobile-app/assets/content/help/*.md`, `mobile-app/assets/content/manifest.yaml` if sections change

**Dependencies / blockers**: Task 6 (ADR) first. Coordinates with Task 8.

**Non-functional requirements**:
- Platform: this task IS a platform exception by nature -- so each divergence must be minimal and justified, not a wholesale Android fork of the Help content.

**Acceptance criteria** (measurable, traceable):
- AC-1: No Help text presented on Android describes a Windows-only surface as if it were available.
- AC-2: Each platform-conditional passage is minimal and cites the ADR rule.
- AC-3: Windows Help content is unchanged except where a shared correction was warranted.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-POLICY in `test/policy/`: Help content served on Android does not reference the Windows-only terms enumerated during the task. Enumerate the term list in the test so it is auditable.

**Definition of Done**: default task-level DoD PLUS:
- Harold reviews the adapted Help content at Manual Validation (he confirmed the F154 content the same way).

**Model**: Sonnet -- *why not the cheaper tier*: judgment about what "reasonably needed" means per passage; a cheaper tier would either over-fork or miss Windows-only references.

**Step-types**: DOCS, TEST-POLICY

**Est-Effort**: 120-180m

---

### Task 8 -- F161: Android background-scan scheduler + POST_NOTIFICATIONS (Priority 24)

**Value**: This enables Android to run scheduled scans, which today it cannot -- the largest functional parity gap between the apps.

**Requirements** (numbered, detailed):
- R-1: Implement a WorkManager per-account unique periodic worker mirroring the Windows per-account Task Scheduler architecture (ADR-0039). F144's evaluation concluded the mapping is 1:1.
- R-2: Request POST_NOTIFICATIONS at runtime, gated on an actual notification call site (F144 corrected the premise that one existed; do not add the prompt without something to notify about).
- R-3: The scan pipeline itself is SHARED -- the Android worker calls the same scan path, it does not fork scan logic. Sprint 60's accounts-FK bug is the precedent: platform-specific persistence code masked a shared gap for months.
- R-4: Per-account settings resolution matches Windows (`getEffectiveFolders(isBackground: true)` and siblings), so Task 3's scope-visibility work applies to both platforms.
- R-5: Any Android-specific behavior (Doze, battery optimization, WorkManager minimum interval) is a DECLARED platform exception per the Task 6 ADR, with the constraint named.

**Affected components / files**:
- `mobile-app/lib/core/services/` -- new Android scheduler service (Sprint 60 F144 removed the unwired predecessor; `scan_frequency.dart` survives as the shared enum)
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- permissions
- `mobile-app/pubspec.yaml` -- `workmanager` dependency returns (F144 removed it as unwired)

**Dependencies / blockers**: Task 6 (ADR) defines how its platform exceptions are recorded. Coordinates with Tasks 3 and 7.

**Non-functional requirements**:
- Platform: Android-only implementation of a SHARED capability -- the textbook case for the ADR's exception mechanism.
- Security: no credential-handling changes; the worker uses the existing secure-storage path.
- Data: background scans write through the same persistence path -- and Sprint 60 proved that path was Windows-masked, so the Android worker must be verified to actually PERSIST (scan_results, email_actions, unmatched_emails), not merely to run.
- Deployment: adding a dependency and permissions affects the Play track (F94/GP-*), which stays out of scope.

**Acceptance criteria** (measurable, traceable):
- AC-1: A per-account periodic worker is scheduled on Android and observably runs.
- AC-2: A background scan on Android persists a scan_result plus its email_actions and unmatched_emails -- verified on-device, not inferred.
- AC-3: POST_NOTIFICATIONS is requested only where a notification call site exists.
- AC-4: Windows scheduling behavior is entirely unchanged.
- AC-5: Every Android-specific constraint is documented as a declared exception citing the ADR.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-UNIT in `test/unit/services/`: the scheduler registers/cancels per-account unique work with the expected constraints.
- T-2 (verifies AC-2) -- TEST-INTEGRATION in `integration_test/`: an on-device background scan persists all three record types (the Sprint 60 bug shape).
- T-3 (verifies AC-4) -- TEST-UNIT: the Windows scheduler path is untouched (regression guard).

**Definition of Done**: default task-level DoD PLUS:
- On-device verification on the emulator with the DB inspected directly (`adb run-as` + sqlite3) rather than trusting the UI -- the method that caught both Sprint 60 Android bugs.

**Model**: Fable/Opus -- *why not the cheaper tier*: concurrency and platform-lifecycle work (Doze, WorkManager guarantees) over a persistence path with a known history of silent failure; the deep-debugging class reserved for the top tier.

**Step-types**: SVC-EDIT, DATA, TEST-UNIT, TEST-INTEGRATION

**Est-Effort**: 180-300m

_**Risk & rollback**_: Risk -- re-adding `workmanager` reintroduces a dependency Sprint 60 deliberately removed; if the implementation stalls, the sprint ends with a dependency and no feature. Mitigation: the dependency returns in the SAME commit as a working scheduler, not ahead of it. Rollback: revert that commit; `scan_frequency.dart` is independent and stays.

_**Decision-class interrupts**_: **Class 1/2** -- re-adding a removed dependency and introducing a platform-specific scheduling service. Surfaced here; the Task 6 ADR governs how the exception is recorded.

---

## Not in scope, with reasons

- **F163 (skipped-tests remediation)**: Harold asked whether this was already complete. **It is not** -- verified by counting actual skip sites rather than reading the item: 22 `skip:` sites remain across 7 files (gmail_api_adapter, aol_folder_scan, credential_verification, delete_to_trash, email_scanner_readonly_mode, imap_adapter, yaml_migration_integration), and the suite reports 26 skipped. Sprint 60's F160 delivered the AUDIT and applied the 3 discontinues (29 -> 26); F163 is the IMPLEMENTATION of the 11 update-to-working verdicts, not yet done. Left out to protect this sprint's size; remains at Priority 26 and is a strong Sprint 62 candidate.
- **F164** (Android scan performance), **F165** (cloud rules sharing): unchanged in the backlog.
- **F173** (periodic testing deep dive): registered as a recurring HOLD template this sprint, to be TRIGGERED by Harold like F70/F71 rather than run now.

## Model assignment summary (cheapest-first per `/plan-sprint`)

- **Haiku**: 2 tasks (Task 0, F172) -- mechanical, fully specified.
- **Sonnet**: 5 tasks (F170, F169, F168, F171, F167) -- judgment or multi-file consistency work, below the architectural-decision bar.
- **Fable/Opus**: 2 tasks (F162, F161) -- an ADR governing future cross-platform decisions, and concurrency/platform-lifecycle work over a persistence path with a history of silent failure.

Two top-tier assignments out of nine, each justified above rather than defaulted.

## Phase 3.7 approval record (Harold, 2026-08-17)

**APPROVED.** All 9 tasks in scope. Answers recorded below; the two Class-3 items are resolved, the
Class-1 item is approved WITH a scoped mid-sprint exception, and sprint size is confirmed.

## Open questions for Phase 3.7 approval -- ALL ANSWERED

1. **Task 1 R-3** (Class 3): correcting the "Canonical Next Steps progression", currently flagged MUST NOT be reordered. Approve the correction? -- **ANSWERED implicitly by R-2a/R-2b: the progression must change, since it omits the `main` merge, the release, and both refinement passes. Treated as approved-in-substance; the correction will be shown in the completion notes for confirmation.**
2. **Task 1 R-7** (Class 3): store-process ordering. -- **ANSWERED (Harold, 2026-08-17): no conflict. The `main` merge does not block refinement; it is a precondition of the MSIX BUILD only. The version bump is independent because it lands in the next sprint's branch, which never touches `main`.** Encoded as R-2a/R-2b.
3. **Task 6** (Class 1): the parity ADR. **The question, restated (it was referenced without being explained -- Harold, 2026-08-17):** an ADR is a Class-1 architectural decision, which the Decision-Class Taxonomy forbids Claude from making unilaterally. The proposal was to DRAFT the ADR, then present it for Harold's approval BEFORE Tasks 7 (F167) and 8 (F161) build on it -- because both write platform exceptions that only make sense once the rule defining "exception" is settled; if the rule changed afterwards, both would need reworking. **ANSWERED (Harold, 2026-08-17): YES -- "mid-sprint ADR approval is OK as an exception for this sprint."** So Task 6 STOPS for approval once the ADR is drafted, and Tasks 7/8 do not begin until it is approved. **Scope of the exception, stated so it is not over-applied**: it covers the parity ADR in THIS sprint only. It is not a general licence to pause at other points -- everything else remains under the standing Phase 3.7 authorization and the Phase Auto-Advance Rule. While awaiting ADR approval, execution continues on tasks that do not depend on it rather than idling.
4. **Sprint size**: 9 tasks at ~17-27 hours. -- **ANSWERED (Harold, 2026-08-17): "not an issue." All 9 tasks confirmed in scope; F161 stays.**
