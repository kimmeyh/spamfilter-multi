# Sprint 70 Plan

**Status**: STUB -- NOT PLANNED, NOT APPROVED. Scope is not selected until Phase 8.4.
**Branch**: `feature/20260914_Sprint_70` (created at Phase 6.6 from
`feature/20260910_Sprint_69` at `b5f6ae0`)
**Created**: 2026-09-14

## Carry-ins from Sprint 69

**Retrospective Category 13 (minor function updates for the next sprint plan): NONE.** All four
roles said so explicitly.

### Carried VALIDATION, not carried development

These are finished features whose acceptance criteria a human has not yet confirmed. They are not
new work, and they should not be re-planned as tasks -- they need a device or a console.

- **F208 + F209 on Android.** Both need a build installed FROM PLAY, not a local debug build.
  Harold, 2026-09-11: *"These have to wait until live on Google Play (after next update)."*
  - F208: export rules to Documents, import that exact file back, confirm the count matches.
    Then import a `.csv` and confirm it is refused in plain language.
  - F209: walk the screens and confirm nothing sits under the three navigation buttons. Start
    with the Import/Export failure message, which
    `validation-screenshots/sprint-69/Screenshot_20260910_200433.png` shows cut off mid-sentence.
    Also open an email's action popup and a text-entry screen with the keyboard up -- those are
    what the first F209 implementation would have broken.
- **F210, 2 of 9 cells.** The sign-in failure "technical details" panel and the Gmail manual token
  security warning. Both need a real sign-in failure to provoke. Harold: *"can't test now, add
  test to next sprint validation testing."*
- **F211 AC-1** (#405, still OPEN). Needs the Google Cloud Console package name and SHA-1 saved,
  Google's propagation window, and a test with an account that has NEVER authorised this app.

### The strongest scope candidate

**F217. Background scans do not run while the app is backgrounded or the phone is locked**
(~4-8h, Priority 6).

Corroborated by evidence rather than report: `Screenshot_20260913_202951.png` shows AOL background
scans at 5:15 PM and 7:57 PM -- **2h42m apart against a 15-minute schedule** -- with both accounts
firing at the same minute, which is Android batching deferred work rather than two independent
timers.

The scheduling code is correct. The leading hypothesis is Doze plus App Standby, supported by the
manifest declaring no battery-related permission at all. **The fix is a Class-1 decision** -- a
battery-optimisation exemption prompt that Play scrutinises, or a foreground service with a
permanent notification -- and must be surfaced, not chosen.

Why it matters more than its position on the slate suggests: background scanning is the app's core
value on Android and the only build that acts on mail. It also means **every closed-test
observation so far may reflect scans that ran on app-open rather than on schedule.**

### Also on the slate (filed Sprint 69)

- **F212** re-processing after adding rules fails 100% (Priority 4). Harold's own hypothesis --
  the re-process path bypasses `ScanCoordinator` entirely -- is code-confirmed as a real bypass.
- **F216** supporting text smaller than the text it should match, three screens (Priority 32).
  Sizes measured; Harold chose to match the list subtitle at 14sp.
- **F215** wire the validation-screenshot folder into every process (Priority 30).
- **F214** slider margins (Priority 34), from the tester.
- **F213** migrate off Custom URI schemes (Priority 40). Not urgent; filed so it is not
  rediscovered under pressure.

## Not yet done

Phase 8.4 backlog refinement pass 2 selects the scope. This stub exists because Phase 7.7
requires it, not because scope is decided.
