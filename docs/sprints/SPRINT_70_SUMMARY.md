# Sprint 70 Summary

**Dates**: 2026-09-17 to 2026-09-19
**Branch**: `feature/20260914_Sprint_70` | **PR**: #418 -> develop, #419 develop -> main
**Version**: 0.15.1+4 -> 0.15.2+5

---

## What this sprint was for

Make the app work when a tester uses it normally. Five of the six planned items were defects two
external testers hit on the shipped build; the sixth removed a workaround that was shipping a
test-only library to those same testers.

## Delivered -- 6 of 6

- **F218** -- Flutter SDK 3.38.5 -> 3.47.4. The upgrade did NOT fix the `integration_test` defect
  it was meant to; the workaround was restored deliberately, which the card's Definition of Done
  had pre-authorised. That is a result, not a failure: "the current stable does not fix this" is
  now evidence rather than caution.
- **F220** -- backgrounding during a live scan wedged all scanning until app restart.
- **F221** -- interrupted scans stuck at "in progress"; manual scans gained a 30-minute timeout.
- **F212** -- re-processing after adding rules failed 100% on Gmail and lied about success on IMAP.
- **F219** -- Google Sign-In `null_intent`.
- **F217** -- background scans deferred; diagnosed and recommended only (Class-1).

**Also fixed in-sprint, not planned**: F223 (four swallowed error paths), F227 (a second OAuth
defect found by emulator probing), F225 (a hook-suite fixture that had aged out), and a Stop hook
that had silently stopped working.

## Metrics

| | |
|---|---|
| Test suite | 2,119 -> **2,155** |
| Analyzer | clean |
| Hook suite | 74 passed, 0 failed |
| Review findings | 1 Copilot HIGH, 2 CRITICAL, 4 IMPORTANT -- all addressed, 0 deferred |
| Backlog filed | F224, F225, F226, F227 (F225 and F227 also fixed) |

## The four things worth remembering

**1. Two shipping gates reported protection they did not provide.** The SEC-9 manifest gate
searched for a string that F227 had removed from the code, leaving only mentions inside comments --
so a security gate passed on the strength of English prose. The F220 lifecycle test asserted
against its own copy of the handler, so deleting the real fix from production left all six tests
green. Both were found by mutation, not by reading. A gate that advertises coverage it lacks is
worse than no gate, because it stops anyone looking.

**2. Three defects were introduced by earlier fixes in the same sprint.** H-2 fixed a set written
too eagerly; the correction made it written too permanently (Copilot's HIGH). Anchoring Gate 1c
fixed one false positive and created the opposite. Adding the timestamp footer silently disabled
every end-anchored pattern in the Stop hook. Each fix was correct in isolation and wrong in
context.

**3. Mutation testing did not save us, and it was being used correctly.** F220's test was
mutation-verified and still blind: it asserted the provider reached an error state and never
asserted the coordinator was freed. Mutation proves a test detects changes to code it already
covers; it cannot reveal code the test does not touch. That gap is now IMP-1.

**4. Probing found what reasoning did not.** The F227 defect was invisible in the source and
obvious to `pm query-activities` on an emulator: two activities claimed one OAuth scheme, so
Android showed a chooser instead of delivering the callback. Harold's Samsung battery check
likewise falsified the leading F217 hypothesis in one minute and changed which remedy was correct.

## Validation

- **Windows**: F212 verified by Harold. WinWright sweep green (both runnable scripts, 29/29 each,
  no DB drift).
- **Android emulator**: F219 task affinity, runtime launch gate, launcher start, return from
  recents -- all pass. The redirect probe FAILED and found F227, which was then fixed and
  re-verified (2 activities -> 1, redirect lands in the app's own task).
- **Carried to Sprint 71**: F219 AC-1, end-to-end sign-in with a listed test user. It needs a
  Play-signed build because the OAuth client is bound to the Play App Signing SHA-1, so no local
  build can test it.

## Decisions Harold made

- **F221 (Class-2)**: reversed the "manual scans have no timeout" decision. His reasoning was
  better than the recommendation he overruled -- the old premise ("a user is watching and can
  cancel") expires the moment the user navigates away, which the lifecycle fix does not cover.
- **F217 (Class-1)**: chose the battery-optimisation exemption, after his own device check ruled
  out the cheaper Samsung explanation.
- **Retrospective**: approved all five improvements to apply immediately.

## Backlog added

- **F224** -- user-facing scan cancel from Scan Results and the Manual Scan popup. Needs
  cooperative cancellation designed first; `Future.timeout` does not cancel work.
- **F226** -- WinWright scripts fail intermittently when run back-to-back in one sweep.
- **F217 implementation** -- under the decided option 1.
- **F219 AC-1 validation** -- once a Play build exists.

## Infrastructure added

- `.claude/hooks/status-footer.ps1` plus a shared copy at `~/.claude/scripts/` and a rule in the
  global `CLAUDE.md`, so every repo on this machine uses the same generated status footer.
- `docs/STATUS_FOOTER_SETUP_PROMPT.md` -- a portable prompt for repos on other machines.
- 9 new hook test cases covering the false positives and the Gate 1c regression.
- CLAUDE.md improvements IMP-1 through IMP-5.
