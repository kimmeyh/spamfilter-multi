# Sprint 77 Plan -- STUB (carry-ins from Sprint 76)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 76 carried in.

## Carry-ins

- **MV76-1** -- finish the Sprint 76 Fold checks on 0.17.6: a scan started by a mail app's notification
  (`trigger=notification`; confirm the AOL/Yahoo package names), background scans after a reboot
  (MV74-1), the export header row, a rule update for an Inbox safe sender with no failure, the F250
  Google account state, MV74-3 error classification.
- **R76-1** -- battery deep dive for "Scan when new mail arrives", written as A/B tests on the Android
  emulator, prioritized by likely success (Sprint 76 retro Cat 13).
- **R76-2** -- should "Scan when new mail arrives" move to the General tab; if so, how the Background
  scanning settings and help text change (Cat 13).
- **R76-3** -- deep dive on Heuristics, ML and GenAI spam identification from stored email content,
  ending in backlog items (Cat 13).
- **R76-4** -- design and implement a history of email content for those identifiers; no duplicates;
  seeded from existing rules and Harold's partial deleted-mail history (Cat 13).

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md`, "Sprint 77 carry-in".

## Open question carried

- Does the native Gmail sign-in (F250) still matter now that refresh-token renewal works?
