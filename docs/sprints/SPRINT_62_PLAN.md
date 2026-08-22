# Sprint 62 Plan -- STUB (scope NOT selected, plan NOT approved)

**Status**: Pre-kickoff stub created at Sprint 61 Phase 7.7 close-out (2026-08-21) per
SPRINT_CHECKLIST.md. Scope selection happens at Phase 8.4 (Backlog Refinement pass 2) after the
Sprint 61 merge and Store release; Phase 3 planning and Harold's 3.7 approval follow. Nothing in
this file is authorized work.

## Category 13 carry-ins from the Sprint 61 retrospective (apply during Phase 3)

1. **Manual Validation must include the Windows background-scan regression check (F161 AC-4)** --
   one glance at Windows Scan History confirming scheduled background scans kept running normally
   through the Sprint 61 scheduler refactor. Harold, 2026-08-20: "I believe it is working as
   expected" -- explicit verification carried here at his direction. Also registered in
   ALL_SPRINTS_MASTER_PLAN.md as a validation carry-over.
2. **Process note**: `sprint_status.json` `github_issues` empties at next-sprint branch rollover,
   NOT at card closure (the `require-sprint-cards` hook reads an empty array as "Phase 3.3.1
   never ran").

## Standing candidates flagged at Sprint 61 close (selection is Harold's at Phase 8.4)

- F168's follow-on settings-interplay question and the F175/F177 scan-robustness pair carry the
  freshest evidence (see ALL_SPRINTS_MASTER_PLAN.md "Next Sprint Candidates" priorities).
- F178 (Android review popup clips Block Subject) is small and screenshot-documented.
