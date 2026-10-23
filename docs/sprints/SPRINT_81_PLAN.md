# Sprint 81 Plan -- STUB (carry-ins from Sprint 80)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 80 carried in.

## Start of sprint

- **0.21.0 store updates** -- the Microsoft Store MSIX and the Google Play closed-test AAB for 0.21.0+18 (Phase 8.3
  of the Sprint 80 cycle). Release notes were re-derived at Sprint 80 Phase 7.7. Also confirm 0.20.0 went live on
  both stores (submitted 2026-10-18, not yet observed).
- **R-2: the new-mail trigger on the Fold** (#471 remainder) -- read the `new-mail-diagnostics` line (Task 17) from
  the first 0.21.0 Fold log. Read the FIRST start after the update AND a later start (Sprint 80 retro IMP-5): on the
  emulator the first start after install wrote no log lines (cause unknown). If the Fold's first start is missing
  too, open a backlog card with that evidence. The `launch:` part also records why `MainActivity` started (R-4).
- **Gmail on the Fold** -- Harold may switch the Fold's Gmail back to IMAP; nothing needs Google sign-in on the phone.

## Carry-ins from the Sprint 80 retrospective

- Category 13: none from Harold or Claude.
- **IMP-1 (live)**: a native OS surface in an MV step (tray, window, notification, dialog) is rehearsed by looking;
  `Rehearsed:` names the UIA element or screenshot.
- **IMP-1.1 (live)**: every WinWright sweep checks the tray icon first; `run-winwright-tests.ps1 -TrayCheckOnly`
  alone.
- **IMP-2a (live)**: `build-with-secrets.ps1 -StartEmulator` launches the highest-API AVD.
- **IMP-3 (live)**: each question states what it decides; standing facts are recorded and not asked again.
- **Standing fact (Harold)**: Fold notification access for the app is ON and stays on.

## Carry-ins from the Sprint 80 7.7.1 final code reviews (Harold, 2026-10-23)

- **F302** IMAP: a separate sequence-number field; a missing UID gets a standard "no valid UID" value (Q1 = 2).
- **F303** Android new-mail diagnostics: each field reported on its own, errors into the diagnostic log (Q2 = 1).
- **Process (Q3 = 1, Q4 = 1, Q5 = 2, live from this sprint)**: the PR stays DRAFT until 7.7.5. At Manual Validation
  complete, in ONE turn: both 7.7.1 final code reviews on the draft (Copilot by hand works on a draft) and the
  retrospective prompt. Findings feed the retrospective by class; a recurring class (2+ findings this sprint, or seen
  in an earlier sprint) gets a prevention proposal. The retrospective's commits get ONE 7.7.1 improvement review:
  fixes under 4 code files and 600 lines are made, larger ones come to the next Phase 1 refinement. Then
  `gh pr ready`, CI green on that HEAD, and the readiness announcement. **CI runs twice (Q6)**: run 1 by hand on
  the draft with the improvement review (`gh workflow run ci.yml --ref <branch>`; first possible this sprint, once
  PR #490 is on develop), run 2 on `ready_for_review`. Toolkit prompts name the excluded files
  (`0*`, `archive/`). Recorded on the 7.7.1 line (close-out check 3d-2).

## Open items carried

- IMP-2b: a background task that stays open after its script prints an error -- capture its process tree
  (`Get-CimInstance Win32_Process`, ParentProcessId) to settle the Sprint 80 11-hour case.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (F301, F300, F289, the iOS cards and the backlog).
