# Sprint 52 -- F133-S52 Accessibility Audit: Findings

**Run**: first instance of the F133 template
**Date**: 2026-07-30
**Auditor**: Claude Opus 5 (1M)
**Scope + method**: defined in `docs/ALL_SPRINTS_MASTER_PLAN.md` under **F133** -- not restated here.
**Standards produced**: `docs/ACCESSIBILITY_STANDARDS.md` (Tier 1 deliverable)

**Tier status** (the time-box is on BREADTH, per the plan):

| Tier | Scope | Status |
|---|---|---|
| 1 | Research + repository accessibility standards document | **COMPLETE** -- `docs/ACCESSIBILITY_STANDARDS.md` |
| 2 | Per-screen gap analysis across active prod UI | **COMPLETE** -- 24 active screens audited (see below) |
| 3 | Remediation task planning + WinWright velocity actuals | **COMPLETE** -- 9 remediation items, actuals recorded |

**Method note**: the screen inventory is **generated from the filesystem**
(`lib/ui/screens/*.dart`), not recalled, per the task DoD. Marker counts are measured by regex across
each file, not sampled. A first attempt at the import-reachability query returned "0 imports" for all
27 screens -- an obviously wrong result caused by a broken glob, not a finding. It was re-run
correctly rather than reported. **Recording this because a plausible-looking wrong number is exactly
what this audit exists to catch.**

---

## Headline numbers

| Measure | Value |
|---|---|
| Screens in `lib/ui/screens/` | **27** |
| Active (reachable in a prod build) | **24** |
| Unreachable / dead | **3** (excluded from the audit -- see Finding A-9) |
| Screens using `Semantics` at all | **5 of 27** |
| Screens using `Semantics` that Sprint 51 did NOT touch | **2** |
| `tooltip:` uses (the pattern that works) | **87** |
| `InkWell` / `GestureDetector` sites | **16 across 8 screens** |
| Of those, sites on screens with NO `Semantics` | **11 across 6 screens** |
| Hardcoded `Colors.grey.shadeNNN` uses | **113** |

**The single most useful number**: only **5 of 27** screens use `Semantics`, and **3 of those 5** are
the screens Sprint 51 fixed reactively (`account_selection`, `no_rule_review`, `results_display`).
The pattern was never applied systematically -- it was applied wherever a test happened to fail.

---

## Gap findings

| # | Gap | Screens affected | Severity | Remediation |
|---|---|---|---|---|
| A-1 | **Bare `InkWell`/`GestureDetector` with no `Semantics` wrapper** -- renders as an unnamed node; a screen reader announces nothing actionable and automation cannot address it. This is exactly what the MT-1 quick-action grid was before Sprint 51. | `account_setup` (6 sites), `results_display` (5), `gmail_manual_token` (1), `gmail_oauth` (1), `rules_management` (1), `safe_senders_management` (1), `scan_history` (1), `no_rule_review` (1) | **HIGH** | R-1: wrap each per `ACCESSIBILITY_STANDARDS.md` §2 |
| A-2 | **`account_setup_screen` is the worst single offender**: 6 tappable sites, 0 `Semantics`, 1,347 lines. It is also the FIRST screen a brand-new Store user meets. | `account_setup` | **HIGH** | R-2: dedicated pass |
| A-3 | **Composite list rows without a merged named node** -- `Card`/`ListTile` rows announce as unnamed `Group`s. 22 of 27 screens have no `Semantics` at all; the management screens (`rules_management` 1,051 lines, `safe_senders_management` 837, `scan_history` 653) are list-heavy by nature. | `rules_management`, `safe_senders_management`, `scan_history`, `folder_selection`, `yaml_import_export`, others | **HIGH** | R-3: apply the §2 wrapper to row builders |
| A-4 | **113 hardcoded grey shades**; `grey.shade400` (~2.6:1 on white) and `grey.shade500` (~3.9:1) FAIL WCAG AA for normal text. Used for subtitle/hint text in multiple screens. | repo-wide | **MEDIUM** | R-4: audit each site; `shade600`+ for text, lighter for decoration only |
| A-5 | **Theme colors bypassed** -- hardcoded `Colors.*` rather than `Theme.of(context).colorScheme.*` means dark mode cannot inherit correctly (ADR-0037 cross-platform standard). | repo-wide | **MEDIUM** | R-5: fold into R-4 |
| A-6 | **No activation assertions in existing widget tests** -- before the Copilot finding on PR #285, every semantics test asserted LABELLING only. Labelling survives the `excludeSemantics`-without-`onTap` defect, so those tests would pass against a live regression. | `test/ui/screens/` | **HIGH** | R-6: add tap-action assertions wherever a semantics label is asserted |
| A-7 | **The proven wrapper pattern lived only in a test-harness README** -- repo knowledge in `mobile-app/test/winwright/README.md`, invisible to anyone writing UI code. | N/A | **RESOLVED** | Absorbed into `ACCESSIBILITY_STANDARDS.md` §2 (this sprint) |
| A-8 | **No accessibility checklist at code-review time** -- ADR-0037 says "enforced in code review" but supplies no checklist to enforce against. | N/A | **RESOLVED** | `ACCESSIBILITY_STANDARDS.md` §6 (this sprint) |
| A-9 | **3 screens are unreachable** (0 inbound references, verified by both filename and class-name search): `account_maintenance_screen` (559 lines), `background_scan_log_screen` (293), `background_scan_progress_screen` (59). `process_results_screen` has 1 partial reference. ~900 lines of unaudited, unshipped UI. | those 3 | **LOW** (not an a11y gap) | R-7: confirm dead, then remove or document why retained |

---

## What is already GOOD (do not "fix")

Recording this so a future run does not churn working code:

- **`IconButton` coverage is strong** -- 87 `tooltip:` uses. Tooltips satisfy both the screen-reader
  label and the Windows UIA projection, so this is the pattern that has been working all along.
- **`help_screen` is the most-referenced screen (15 inbound)** and already carries tooltips on all 3
  of its icon buttons.
- **The 5 screens Sprint 51 touched now carry correct, tested `Semantics`** -- and
  `account_selection_semantics_test.dart` now asserts the tap ACTION, not just the label.
- **`SelectionArea` is applied at the Scaffold-body level on the main screens**, satisfying the
  ADR-0037 text-selectability standard.

---

## Remediation tasks (Tier 3)

Sized against the `CODING_VELOCITY.md` Estimate Table. ~~These are PLANNED, not executed~~ --
**STATUS UPDATED 2026-07-31.** These were originally scoped as *next-sprint* work (fixing every gap was
out of the audit's own scope). Harold then expanded Sprint 52 mid-sprint (SC-2, then SC-3: *"please
fully re-plan the current scope to include all the screens"*), so **7 of the 9 were executed in this
sprint** as Task 7. R-7 and R-8 remain open and carry forward.

| ID | Task | Step-type | Est-Effort | Priority | Status |
|---|---|---|---|---|---|
| R-1 | Wrap the 11 bare tappable sites on non-Sprint-51 screens | UI-MOVE x11 (3-6m ea) | 35-65m | HIGH | **DONE** (Task 7) |
| R-2 | `account_setup_screen` dedicated pass (6 sites, first-run UX) | UI-MOVE x6 + TEST-WIDGET | 40-60m | HIGH | **DONE** (Task 7) |
| R-3 | Row-builder wrappers on the 3 list-heavy management screens | UI-MOVE x3 + TEST-WIDGET x3 | 70-100m | HIGH | **DONE** (Task 7) |
| R-4 | Contrast audit: 113 grey sites -> `shade600`+ for text | UI-MOVE (bulk) | 45-70m | MEDIUM | **DONE** (Task 7) |
| R-5 | Theme-color migration (folded into R-4) | -- | included | MEDIUM | **DONE** (with R-4) |
| R-6 | Add tap-action assertions to existing semantics tests | TEST-WIDGET x5 (20-25m ea) | 100-125m | HIGH | **DONE** (Task 7) |
| R-7 | Confirm + remove or document the 3 dead screens | DOCS + deletion | 15-25m | LOW | **OPEN -- carries forward.** No `lib/` deletions were made this sprint (verified via `git diff --name-status`). Deleting a screen is a Class-2 development decision and was never surfaced for approval, so it was correctly left alone rather than done silently. |
| R-8 | WinWright script coverage for newly-named surfaces | E2E `[no-history]` | time-box | MEDIUM | **OPEN -- carries forward.** Deliberately NOT attempted: the script runner cannot bridge a Flutter dialog-settle boundary (skips `ww_wait`, rejects `ww_assert`), which is exactly what Task 2/F131 re-confirmed. New E2E coverage belongs in `integration_test` (F99), not in more WinWright scripts. |
| R-9 | Contrast-ratio policy gate (fail the build on `grey.shade400`-or-lighter text) | HOOK/policy test (5-8m) | 20-30m | MEDIUM | **DONE** (Task 7 -- `test/policy/text_contrast_test.dart`) |

**Original recommended slice** (superseded by the mid-sprint expansion, kept for the record): R-6 first,
then R-1 + R-2, then R-3; R-4/R-9 pair naturally; R-7 cleanup; R-8 depends on the others landing.
In the event R-6 *was* done first, and it earned its place -- the tap-action assertions are what make
the rest safe from silent regression.

**Carry-forward**: R-7 (needs a Class-2 decision on deleting vs documenting the 3 dead screens) and
R-8 (should be re-scoped as `integration_test` coverage rather than WinWright scripts).

---

## Velocity actuals recorded (R-7 of the task card)

Added to `docs/CODING_VELOCITY.md` -- the **WINWRIGHT** step-type had no prior sample, so every F129
estimate was `[no-history]`. Sprint 51 actuals now make the next one estimable.

---

## Method note for the next F133 run

What worked, and is worth repeating:

1. **Generate the inventory from the filesystem**, never from memory -- and re-run any query whose
   result looks implausible before reporting it (see the "0 imports" artifact above).
2. **Count markers across ALL files rather than sampling.** The "5 of 27 screens use Semantics"
   number is what turned a vague sense of "we should do accessibility" into a specific, sized backlog.
3. **Record what is already GOOD.** Without the tooltip-coverage finding, a future run could
   "improve" 87 working call sites.
4. **Separate the audit from the fixing.** Tier 3 produces sized tasks; executing them is a separate
   scope decision for the Product Owner.
