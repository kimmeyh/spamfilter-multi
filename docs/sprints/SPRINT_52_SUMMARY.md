# Sprint 52 Summary

**Branch**: `feature/20260730_Sprint_52`
**PR**: [#292](https://github.com/kimmeyh/spamfilter-multi/pull/292)
**Issues**: #289, #290, #291
**Dates**: 2026-07-30 -> 2026-08-02
**Retrospective**: `docs/sprints/SPRINT_52_RETROSPECTIVE.md`

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1,815 -> **1,829** passing / 0 failing / 29 skipped |
| Analyzer | Clean |
| Windows build | Green |
| Hook harness | 34 -> **45** passing |
| Manual Validation | Complete (Harold, 2026-08-02) |
| Carry-forward | **None** |

## Scope

Approved 2026-07-30: F133-S52, F131, F134, F135, F136. Expanded twice
mid-sprint at Harold's direction -- SC-1 (F134 from 3 screens to all), SC-2/SC-3
(F133 remediation EXECUTED rather than planned-only, across every screen).

| Task | Feature | Result |
|---|---|---|
| 1 | F133-S52 | Accessibility audit, 24 active screens (27 total, 3 dead). **Only 5 of 27 used `Semantics` at all.** 9 findings -> 9 remediation items |
| 2 | F131 | WinWright create-path root cause -- **no app defect existed** |
| 3 | F134 | Canonical AppBar order, 3 named screens; `StandardAppBarActions` created |
| 4 | F135 | Session-scoped account selection + No-Rule default screen |
| 5 | F136 | Skip button in the No-Rule popup header |
| 6 | F134-ALL | Canonical order on the remaining 8 screens + policy gate |
| 7 | F133-REMEDIATE | All 9 remediation items complete, incl. R-7 and R-8 |

## What shipped

**Accessibility (F133)**. The audit's headline was that most of the app was
unaddressable by name -- to a screen reader or to automation. Remediation wrapped
the bare tappable sites across every screen, added tap-action assertions to the
existing semantics tests, and migrated 113 grey text sites to meet WCAG 2.1 AA
(`shade400` ~2.6:1 and `shade500` ~3.9:1 both FAIL; `shade600` ~5.4:1 passes).
New `docs/ACCESSIBILITY_STANDARDS.md` extends ADR-0037. Two build-failing gates
added (`appbar_action_order_test.dart`, `text_contrast_test.dart`).

**AppBar consistency (F134/F134-ALL)**. Twelve screens had each hand-rolled the
same icons in differing orders -- one under a comment asserting a "standardized"
order that matched no other screen. `StandardAppBarActions` is now the single
definition: Manual Scan, Review "No Rule" Items, View Scan History, Accounts,
Settings, **Help always last**, Exit auto-appended.

**Account selection (F135)**. The picker now appears only when no account is
selected AND the destination needs one. Settings resolves its account lazily,
per tab. `accountId` became nullable across 28 sites and `_accountId` now throws
`StateError` rather than silently defaulting to `''` -- that silent default was
the latent defect class, not a harmless fallback.

**F131 -- the card's premise was wrong.** No app defect and no accessibility
defect existed. A Sprint 41 comment recommended clicking the parent `Group`
instead of the `RadioButton`; Sprint 51 followed it, saw nothing happen, and
wrote "the radios do not select" into five documents as verified fact. The
radios always worked. Wrong findings were **struck through, not deleted** --
a wrong fix recorded as verified is worse than no note at all, and that lesson
only survives if the wrong note survives with it.

**Dead code removed (R-7)**. Three unreachable screens, 911 lines. The decisive
evidence: the Windows background-scan path is headless -- `main.dart` runs the
worker and exits **without ever calling `runApp`** -- so a "progress UI during a
background scan" cannot render on any path.

## Found during Manual Validation

- **MV-1**: the Accounts icon reached nothing on **every** screen. An
  intersection defect -- F134 and F135 were each correct alone, but `popUntil`
  could not reach Account Selection once F135 made No-Rule the desktop default.
  Fixed once in the shared builder, so every screen got it.
- Manual Scan was reachable only via the Accounts screen -> added a radar icon.
- Refresh on 4 screens completed silently and read as dead -> they now report
  what they did. Scan History mattered most: its reload PURGES past the retention
  window, so it could delete rows and say nothing.

## Retrospective improvements (all applied)

| ID | Improvement |
|---|---|
| IMP-1 | Behavior-level AppBar gate -- presses every action, asserts navigation |
| IMP-2 | Phase 3.3.1 gate -- blocks task commits when issue cards are missing |
| IMP-3 | Check whether a failure is already documented before investigating it |
| IMP-4 | Don't stage BLIND (corrected from "no `git add -A`" after Harold's challenge) |
| IMP-5 | Read how existing members of a shared abstraction behave first |
| IMP-6 | Extend the 3.3.1 gate to the draft PR -- the sprint ran to Phase 7 with none |

## Lessons worth carrying

1. **Source-text gates verify shape, not behavior.** The AppBar order gate proved
   every screen *called* the shared builder and was blind to a handler that went
   nowhere. Pair every source gate with one that presses the control.
2. **Prove a new test FAILS before trusting it.** Four mutation checks this
   sprint; two caught assertions of mine that passed while being worthless.
3. **One missed deliverable usually means a whole step was skipped.** IMP-2 fixed
   the missing issue cards; the draft PR from the *same* Phase 3.3.1 stayed
   missing until Harold flagged it. Enumerate everything a skipped step produces.
4. **Redundant soft fallbacks are not a safety net.** Four PR checkpoints each
   said "create it if missing" and all four passed silently.
