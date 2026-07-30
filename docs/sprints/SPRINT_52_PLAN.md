# Sprint 52 Plan

**Sprint**: 52
**Status**: **STUB -- NOT YET SCOPED.** Created at Sprint 51 Phase 7.7 per the checklist
("Next Sprint Plan stub created/updated with Category 13 carry-ins"). Scope is selected by Harold at
Phase 1 Backlog Refinement; this file records only what Sprint 51 handed forward.
**Branch**: not yet created -- opened FROM `feature/20260727_Sprint_51` at Phase 6.6 on merge of
PR #285 (never from `develop`, never via `git stash`).

---

## Carry-ins from Sprint 51

### Category 13 (minor updates for the next sprint plan)

Harold recorded **none** at the Sprint 51 retrospective.

### Category 14 -> carded backlog items (Harold approved 2026-07-30)

All four came from Harold's retrospective Category 14 and were approved APPLY NOW, then redirected to
Sprint 52 for detail planning: *"can you add to backlog and assign to next sprint so we can do detail
planning for it."* Full definitions live in `ALL_SPRINTS_MASTER_PLAN.md` -- do NOT restate them here;
plan against that definition.

| Item | Priority | State entering Sprint 52 |
|---|---|---|
| **F133-S52** -- Accessibility audit, first run of the F133 template | 12 | Not started. Tiered time-box, not estimated. **Absorbs IMP-5** (record WinWright actuals in `CODING_VELOCITY.md`) and **IMP-6** (the drive-it-don't-dump-it verification rule). |
| **F134** -- Canonical AppBar icon order | 14 | **PARTIAL.** `standard_app_bar_actions.dart` (the shared builder) DONE and applied to Manual Scan. **Remaining**: Settings, Results (with Download + Find leading), and Review "No Rule" Items (+4 icons). |
| **F135** -- Session-scoped account selection + No-Rule default screen | 15 | **PARTIAL.** `SelectedAccountProvider` + lazy resolver + stale/delete handling DONE. **Remaining**: Settings per-tab prompting (General must NOT prompt), Manual Live Scan wiring, and the default-screen change. |
| **F136** -- "Skip" button in the No-Rule item popup | 16 | Not started. |

### Open questions to settle AT PLANNING (do not assume)

- **F135 default-screen change is a Class-1 decision** -- it alters app startup behavior. Decide
  explicitly: what does a user with ZERO configured accounts see, and does Back from the No-Rule
  screen exit the app?
- **F136 "next unaddressed item"** needs a precise definition: next in the CURRENT filtered/sorted
  order, behavior at end-of-list (wrap / close / disable), and whether a skipped item stays skipped
  for the session.
- **F134** depends on **F135** for the No-Rule screen's Settings icon (that screen is cross-account and
  has no `accountId` of its own).

---

## Other candidates on the board (not yet selected)

- **F131** -- WinWright create-path is not drivable; the two `test_f56_*` scripts are **stale, not
  merely excluded** (their documented radio workaround did not reproduce). Priority 13.
- **F133** -- the repeatable HOLD template itself (F133-S52 above is its first run).
- See `ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" for the full prioritized list.

---

## Release state entering Sprint 52

- **`0.5.8` is LIVE** in the Microsoft Store (certified 2026-07-29, Submission 9). Harold verified the
  installed build has **no `[DEV]` title** -- closing the F119 family.
- Dev worktree is at **0.5.9**.
- **Outstanding**: confirm the Store build's About version and that **Gmail sign-in works**. The clean
  title proves `APP_ENV`/`NATIVE_APP_ENV` resolved to prod; it does NOT prove the OAuth credentials
  were embedded (separate dart-defines), which is what F119 originally broke.
- **Android / Google Play readiness** remains the next major track (off HOLD since 2026-07-24).
