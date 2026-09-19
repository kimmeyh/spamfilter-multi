# Sprint 71 Plan -- STUB (not yet planned, not yet approved)

**Status**: PRE-KICKOFF. Scope is NOT selected. This stub exists to carry forward the items
Sprint 70 identified, so they are not lost between sprints.

**Branch**: `feature/20260919_Sprint_71` (created from the Sprint 70 branch to carry `a7a8297`,
committed after PR #418 merged)
**Version**: 0.15.2+5 (bumps at Phase 3.7.0b once scope is approved)

---

## Carry-ins from Sprint 70 (Category 13 -- minor updates for the next plan)

These are not new candidates. They are unfinished work with a named blocker that has now cleared,
or is about to.

- **F219 AC-1 -- end-to-end Google Sign-In validation.** The fix is implemented and verified as far
  as a local build can go: on an Android 14 emulator the OAuth redirect reaches the app instead of
  a system chooser. What remains is a listed test user completing sign-in on a **Play-installed**
  build. It cannot be tested locally because the Android OAuth client is bound to the Play App
  Signing SHA-1, so any locally-signed build presents the wrong fingerprint and Google rejects it
  before the redirect is reached. **Blocker clears with the 0.15.2 Play upload**, which is part of
  the Phase 8 release cycle now in progress.
- **F227 re-verification on the Play build.** Same upload. The emulator proved the redirect routing
  is fixed; the full sign-in round trip against the real OAuth client is untested.
- **F217 implementation.** Harold decided the remedy on 2026-09-19 (option 1: request a
  battery-optimisation exemption). The diagnosis is complete and the Samsung hypothesis is
  falsified by his own device check, so this is ready to implement rather than ready to
  investigate. Constraints recorded in the master plan: the permission is scrutinised at Play
  review and needs a listing justification; the prompt must be CONTEXTUAL (at the moment the user
  enables background scanning, mirroring the F161 POST_NOTIFICATIONS pattern), not fired at
  startup; and the app must behave honestly when the user declines.

## Backlog candidates filed during Sprint 70

Full detail in `ALL_SPRINTS_MASTER_PLAN.md`. Listed here so scope selection has them in view.

- **F224** -- user-facing scan cancel, from View Scan Results and from the Manual Scan popup.
  **The buttons are the easy half**: `Future.timeout` does not cancel underlying work, so a cancel
  that only released the coordinator lease would let a second scan open an IMAP session while the
  first still holds one -- the Sprint 61 per-account session-cap failure. Cooperative cancellation
  must be designed first.
- **F226** -- WinWright scripts fail intermittently when run back-to-back in one sweep, and which
  one fails swaps between runs. Each passes 29/29 in isolation. A sweep that is red for unrelated
  reasons cannot answer the question it exists to answer.
- **F222** -- scan results ordering (newest first, grouped by base domain, providers in their own
  section at the top). Harold specified the ordering in Sprint 70 refinement.

## Open questions for Phase 3 planning

- None carried. Harold recorded "none" for retrospective categories 13 and 14.

---

**Next step**: Phase 8.2 backlog refinement pass 1 (completeness sweep -- does NOT select scope),
then the Store release processes for 0.15.2, then Phase 8.4 refinement pass 2 where scope is
selected.
