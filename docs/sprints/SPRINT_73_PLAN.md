# Sprint 73 Plan -- STUB (not yet planned, not yet approved)

**Status**: PRE-KICKOFF. Scope is NOT selected -- that happens at Phase 8.4 refinement pass 2.
This stub exists so the items Sprint 72 identified are not lost between sprints.

**Branch**: `feature/20260922_Sprint_73` (created from the Sprint 72 branch per the carry-forward
rule, immediately on merge -- never from `develop`)
**Version**: 0.15.3+6 (bumps at Phase 3.7.0b once scope is approved)

**Store note**: Harold directed no store push for the 0.15.3 cycle (2026-09-22), so Phase 8.3 is
explicitly N/A for Sprint 72's release. **0.15.3 is therefore NOT on either store** -- the live
versions remain 0.15.2 on Play (closed testing) and 0.15.2.0 on the Microsoft Store. Anything
needing a shipped build has to wait for the next release that does go out.

---

## Carry-ins from Sprint 72

These are not new candidates. Each is unfinished work whose reason for being unfinished is
recorded.

- **F235 -- Android Doze via `setExactAndAllowWhileIdle()` (issue #428). TARGETED FOR THIS SPRINT
  BY HAROLD** on 2026-09-22. This is the mechanism half of F217; Sprint 72 shipped only the honest
  timing caveat because the search he required found the battery exemption is not the only route
  and carries a Play policy cost. **Two risks are already written into the card**: Android 12+
  restricts exact alarms and `USE_EXACT_ALARM` has its own Play justification burden (verify WHICH
  permission is needed before building -- if it is the burdensome one, the advantage over the
  exemption shrinks and the decision goes back to Harold); and an alarm does NOT survive reboot the
  way WorkManager persisted work does, which is a real regression risk versus today.
- **F232 mechanism B (issue #422)** -- a live batch failing 9 of 9 on a healthy connection, still
  undiagnosed. **It is now INSTRUMENTED rather than guessed at**: the F233 diagnostic logger
  distinguishes NOT_CONNECTED / SERVER_REFUSED / SKIPPED, which is exactly what could not be told
  apart before. The next attempt starts with data. Mechanism A shipped in Sprint 72.
- **F229 screen half (issue #427)** -- the AppBar action row cannot hold a version label at phone
  width. This is a MEASUREMENT, not an opinion: a short form still overflowed by 18px and turned
  four tests red. The export half shipped and closes the original evidence problem, so this may not
  be worth doing at all. Options are in the master plan.
- **F219 AC-1 + F227** -- end-to-end Google Sign-In with a listed test user on a Play-installed
  build. Blocked on a Play upload, and 0.15.3 is not being pushed, so this waits for the next
  release that ships.

## Backlog candidates filed during Sprint 72

Full detail in `ALL_SPRINTS_MASTER_PLAN.md`.

- **F234** -- read-only as a PREVIEW mode: record what WOULD have been deleted rather than only
  refusing. Harold's idea during manual validation. It turns read-only from a restriction into a
  rehearsal, so a broad rule's blast radius can be vetted before anything is removed. One open
  question for planning: block rules only, or safe-sender moves too?

## Open questions for Phase 3 planning

- None carried. Harold recorded "none" for retrospective categories 13 and 14.

---

**Next step**: Phase 8.4 backlog refinement pass 2, where scope is selected. Phase 8.3 (store
release) is N/A this cycle by Harold's direction.
