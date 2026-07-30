# Sprint 51 Summary

**Sprint**: 51
**Dates**: 2026-07-27 -- 2026-07-30
**Branch**: `feature/20260727_Sprint_51` (created FROM `feature/20260723_Sprint_50` per Phase 6.6)
**PR**: #285 -> `develop`
**Scope** (Harold 2026-07-27): F130-S51 (do first, time-boxed by tier), F128-residual, F129
**Outcome**: 3/3 planned tasks complete. Manual Validation 5/5 closed. Retrospective complete.

---

## What shipped

### Task 1 -- F130-S51: Process-Docs Consistency Deep Dive (first run of the F130 template)

**28 contradictions found, 28 corrected, 0 outstanding**, across all three planned tiers.

The highest-consequence finding: **`CLAUDE.md` named the msix credential-injection key as
`build_windows_args`** -- the F119 typo that is not a real msix key, is silently ignored by the msix
package, and had already shipped a **credential-less 0.5.4 to the Microsoft Store**.
`test/policy/msix_config_test.dart` is a build-failing gate asserting that exact string never
appears, so the most-read document in the repo instructed using the one key a test forbids. The
identical sentence in `AGENTS.md` and a matching reference in the master plan were caught **only by
the DoD re-grep**, invisible to the audit pass itself -- which is the argument for that rule.

Second most consequential: **`.claude/sprint_status.json` was mandatory in `SPRINT_CHECKLIST.md` but
entirely absent from `SPRINT_RETROSPECTIVE.md`**, the document that actually drives Phase 7.7. That
orphan-instruction shape is why the file drifted 15 sprints before Sprint 50 caught it.

Also corrected: the `/full-test` skill prescribed bare `flutter test` (the exact command the Sprint 49
concurrency policy forbids for full suites) plus 5 more sites; `/plan-sprint` contained a
score-then-pick-tier procedure contradicting the CHEAPEST-FIRST rule stated in the same file, 7
hardcoded "Opus" top-tier references, and 2 invocations of commands that have never existed;
estimating guidance was de-houred and re-anchored to the measured minute-based table (a UI-MOVE
measures 3-6 MINUTES; the backlog table said XS = "1-2 hours"); 6 dead file references, including two
script families each documented as living in the other's root.

**Three hook false positives fixed** (R-2, R-2a, plus the close-out hook), each with regression cases.
The hook test harness was generalized from one hook to directory-based routing -- it had been
hard-wired to a single hook, which is precisely why two of those false positives shipped unnoticed.

**One Class-3 item surfaced rather than decided** (R-6): `/memory-restore` and `/startup-check` step 3
still drove the retired `.claude/memory/current.md` path, frozen at Sprint 39 and inert only because
`pending_restore` happened to be false. Harold decided (retire `/memory-restore` to a tombstone, point
`/startup-check` at `sprint_status.json`) and it was applied the same day.

### Task 2 -- F128-residual: sibling silent-no-op early-returns

`removeRule`, `updateRule` and `removeSafeSender` each returned silently when the provider cache was
unloaded, so a caller could report success with nothing persisted. All three now load on demand and
throw `StateError` if the cache is still unavailable. Completes the F128 fix, which covered only
`addRule`/`addSafeSender`.

### Task 3 -- F129: WinWright coverage for the three Sprint-50-touched screens

Three scripts, all green, zero DB drift: `test_f129_no_rule_review.json`,
`test_f124_rule_labels.json` (32 steps), `test_mt2c_no_rule_sweep.json` (28 steps).

**A defect this sprint shipped and then caught.** The account-picker accessibility fix went in
**broken**: `Semantics(button:)` without `excludeSemantics` left the inner `ListTile`'s node in place,
so each entry projected as **two stacked Buttons with the same name**. Automation matched the outer
wrapper, which has no tap handler -- selecting an account reported success and did nothing, silently
blocking the entire Settings path. Ordinary mouse input was unaffected, which is why it looked fine.
Adding `excludeSemantics: true` then collapsed the node correctly but **removed the tap target**. The
working shape is `excludeSemantics: true` **plus `onTap` on the `Semantics` node itself**.

**Durable lesson**: a tree dump proves a name exists; only an interaction proves the node still works.

Harness constraints discovered and documented (several by failing runs, not reasoning): a
per-control-type tool rule (`ww_invoke` for Buttons; `ww_click`+`useInvokePattern:false` for tabs,
`Text` and `CheckBox`); the Flutter semantics tree builds **lazily on query, not on a timer** (a
10-second wait does not help); `ww_invoke` reports success on **off-screen** elements without pressing
them; the search box cannot be cleared by automation. A mid-sprint claim that `useInvokePattern:true`
never activates Flutter controls was retested, did not reproduce, and was **retracted**.

---

## Retrospective outcome

All 7 improvements approved APPLY NOW.

- **IMP-7 shipped in-sprint**: the auto-advance hook gained the **enforcement-window upper bound**
  Harold specified -- the rule applies only between Phase 3.7 approval and the start of Manual
  Validation. That missing upper bound was the root cause of every false positive the hook has
  produced; 30+ whitelist rows had accumulated treating symptoms. The suite caught a regression in the
  first cut (an unscoped retrospective-file check would have exempted every historical sprint branch
  and defanged the hook entirely). Suite 33/33.
- **IMP-2 / IMP-3 foundations shipped**: `StandardAppBarActions` (one builder, canonical order,
  applied to Manual Scan) and `SelectedAccountProvider` (session-scoped, lazy prompting).
- **IMP-1/2/3/4 remainder carded for Sprint 52** at Harold's direction, for detail planning: **F133** +
  **F133-S52** (accessibility audit template, **superseding and retiring F132**), **F134**, **F135**,
  **F136**. Each card records exactly what is DONE vs REMAINING.

---

## Release

**`0.5.8` is LIVE in the Microsoft Store**, certified 2026-07-29 as Partner Center Submission 9.

Caught during this sprint: 0.5.8 had been sitting **In draft** at Partner Center since the 07-27 build
while `sprint_status.json` asserted "in certification" for a full day, and that claim was repeated as
fact rather than verified. **BUILT + VALIDATED is not SUBMITTED** -- release state is verified in
Partner Center, never from a tracking file.

Post-certification close-out completed: CHANGELOG `[0.5.8]` release heading + comparison links, dev
version bumped `0.5.8 -> 0.5.9` (one file -- `pubspec.yaml` -- the F-VERSION-DERIVE payoff, gate
verified), master plan Store status LIVE.

---

## Verification

| Gate | Result |
|---|---|
| `flutter test --concurrency=4` | **1,814 passed / 29 skipped / 0 failed** |
| `flutter analyze` | clean |
| Hook regression suite | **33/33** |
| WinWright default sweep | **3/3 PASS, no DB drift** |
| Policy gates (msix_config, version_consistency, stale_footer) | green |
| Manual Validation (MV-1..MV-5) | **5/5 closed by Harold** |

---

## Environment finding (machine-local, not an app defect)

**ENV-1 -- RESOLVED.** An Acronis file-system filter driver was blocking `AppXSvc` cleanup
(`C:\Program Files\WindowsApps\Deleted`, event Id 493, every 6 minutes, growing 21 -> 176 stuck
files), which wedged the Microsoft Store client: search and Library rendered, but app detail pages
never populated and install/update controls were disabled. Fixed by an **Acronis Protection
exclusion** -- verified by 23 hours of uptime with zero 493 events, plus the Store client
self-updating (which requires a working deployment pipeline). The filter drivers remain loaded, so
backup protection was not disabled.

Twice mis-read as "fixed" because a page rendered; the event log disproved it both times. Judge that
issue from the 493 log, never the UI.

---

## Documents

`SPRINT_51_PLAN.md` · `SPRINT_51_F130_FINDINGS.md` (28 findings + harness findings) ·
`SPRINT_51_RETROSPECTIVE.md` (14 categories x 4 roles) ·
`drafts/SPRINT_51_RETROSPECTIVE_claude_draft.md`
