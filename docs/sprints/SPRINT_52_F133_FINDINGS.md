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
| Screens in `lib/ui/screens/` | **27** at audit time -> **24** after R-7 |
| Active (reachable in a prod build) | **24** |
| Unreachable / dead | **3** (excluded from the audit -- see Finding A-9). **All 3 DELETED 2026-07-31**, Harold approved |
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
| A-9 | **3 screens are unreachable** (0 inbound references, verified by both filename and class-name search): `account_maintenance_screen` (559 lines), `background_scan_log_screen` (293), `background_scan_progress_screen` (59). `process_results_screen` has 1 partial reference. ~900 lines of unaudited, unshipped UI. | those 3 | **LOW** (not an a11y gap) | **RESOLVED 2026-07-31** -- all 3 DELETED (Harold approved). Re-verified dead three ways first; see "R-7 evidence" below. `process_results_screen` was NOT deleted -- it has a partial reference and was not part of the approved set. |

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
| R-7 | Confirm + remove or document the 3 dead screens | DOCS + deletion | 15-25m | LOW | **DONE 2026-07-31 (Harold approved the deletion).** See "R-7 evidence" below. |
| R-8 | ~~WinWright script coverage~~ **RE-SCOPED to `integration_test`** for newly-named surfaces | E2E `[no-history]` | time-box | MEDIUM | **DONE 2026-07-31 (Harold approved the re-scope).** `integration_test/sprint52_surfaces_test.dart`, 3 cases green. See "R-8 re-scope" below. |
| R-9 | Contrast-ratio policy gate (fail the build on `grey.shade400`-or-lighter text) | HOOK/policy test (5-8m) | 20-30m | MEDIUM | **DONE** (Task 7 -- `test/policy/text_contrast_test.dart`) |

**Original recommended slice** (superseded by the mid-sprint expansion, kept for the record): R-6 first,
then R-1 + R-2, then R-3; R-4/R-9 pair naturally; R-7 cleanup; R-8 depends on the others landing.
In the event R-6 *was* done first, and it earned its place -- the tap-action assertions are what make
the rest safe from silent regression.

**Carry-forward**: none. All 9 remediation items are complete as of 2026-07-31.

---

### R-7 evidence (the 3 deleted screens)

Harold approved deletion 2026-07-31 after review. Each was verified dead **three independent ways**
before the ask, because the audit's bare "0 inbound references" was not sufficient grounds to delete
~900 lines:

1. **Class-name and filename search across all of `lib/` and `test/`** -- each class appears ONLY
   inside its own file. Nothing constructs them; there is no route table entry and no conditional
   import.
2. **No test references** -- zero files under `test/` mention any of the three.
3. **The decisive one for `background_scan_progress_screen`**: the Windows background-scan path is
   **headless**. `main.dart` detects background mode, calls
   `BackgroundScanWindowsWorker.executeBackgroundScan(...)`, logs, and **exits without ever calling
   `runApp`**. So the "progress UI shown during a background scan" it was written for cannot render
   under any code path -- the design it belonged to was replaced by a headless worker.

| Screen | Lines | Added | Why dead |
|---|---|---|---|
| `account_maintenance_screen.dart` | 559 | `6f8c352` (2025-12-30) | Superseded by the account-selection / account-setup pair; never wired to a route |
| `background_scan_log_screen.dart` | 293 | `41c0d57` (2026-02-14, "closes #152") | Log viewing moved into Settings, which uses `BackgroundScanLogStore` (the STORE is alive -- do not confuse the two; that name collision is what made the first reference sweep look ambiguous) |
| `background_scan_progress_screen.dart` | 59 | `d47ac7a` (2026-01-30, Sprint 8) | Background scanning became headless -- see point 3 above |

**Verification after deletion**: `flutter analyze` clean, full suite **1,824 passing / 0 failing**
(unchanged), Windows build succeeds. Nothing referenced them.

**Worth recording**: this sprint's own Task 7 commit (`4e846be`) applied accessibility wrappers to two
of these three screens. That work was wasted -- ~900 lines of unreachable UI absorbed audit and
remediation effort across the sprint. Dead code is not free; it consumes the attention of every sweep
that does not know it is dead.

### R-8 re-scope (WinWright -> integration_test)

R-8 was written as "WinWright script coverage for newly-named surfaces". Harold approved re-scoping it
to the in-VM lane on 2026-07-31. **The original lane was wrong**, and Task 2 (F131) is the evidence:
the WinWright script runner skips `ww_wait` and rejects `ww_assert`, so it cannot bridge a Flutter
dialog-settle boundary. Any new script covering a dialog or an animated transition would have been
born quarantined, exactly like the two `test_f56_*` scripts.

The in-VM lane is also the **stronger instrument for what R-8 actually needs to prove**: the Sprint 52
work is about the SEMANTICS tree, and `integration_test` reads that tree directly rather than through
the Windows UIA projection that proved unreliable in Sprint 51.

`integration_test/sprint52_surfaces_test.dart` -- 3 cases, all green:

| Case | Proves |
|---|---|
| AppBar actions render in canonical order with Help LAST | The order a user RECEIVES. `test/policy/appbar_action_order_test.dart` proves each screen *calls* the shared builder (source-level); this asserts the built widget tree. Includes an explicit >=3-tooltip guard so a screen exposing no actions cannot pass the ordering assertions vacuously. |
| Skip announces itself AND exposes a tap action | **Mutation-verified**: removing `onTap` makes this FAIL on the tap-action assertion while the `isButton` flag still passes -- which is precisely why asserting the flag alone is insufficient, and precisely the defect that shipped in Sprint 51. |
| Manage Rules exposes named, addressable rows | Rows carry both a non-empty label AND a tap handler. Matches rows by their stable `hint` ('View rule details') rather than label text, so the test is not pinned to whatever the bundled seed contains. |

**A note on how the third case was built**: its first version asserted only "some semantics node has a
label longer than 2 characters". That passed -- but it passed on *incidental* labels (an AppBar
tooltip, a filter chip) and would not have noticed the rows regressing to bare. Tightening it made it
fail, which exposed that my filter (matching the literal word "rule") was wrong rather than the app:
rows are labelled with the rule's display name and category. A green assertion that cannot fail is not
coverage.

**Not duplicated here**: the F56 create+delete lifecycle already has in-VM coverage in
`rule_lifecycle_test.dart` (Sprint 42). That test taps `find.text('Top-Level Domain')` and **has passed
since Sprint 42** -- it was quietly contradicting the "the radios do not select" claim the entire time
that claim stood in three documents as verified fact.

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
