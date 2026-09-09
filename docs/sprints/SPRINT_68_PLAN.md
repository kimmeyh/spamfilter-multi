# Sprint 68 Plan

**Status**: STUB -- created at Sprint 67 close-out (Phase 7.7). **NOT APPROVED.**
Scope is selected by Harold at Phase 8.4 (Backlog Refinement pass 2), after the
Store release step. Nothing here is authorized to start.

**Branch**: not yet created (opened at Phase 6.6, from the Sprint 67 branch, on merge)
**Version**: bump at plan approval per F190 (Phase 3.7.0b) -- 0.14.2 -> 0.14.3 if
this sprint carries no `feat`, 0.15.0 if it does.

## Category 13 carry-ins from Sprint 67

**Harold: "none".** Recorded verbatim; nothing was carried in from the
retrospective's Category 13.

## Candidates (NOT scope -- Harold selects at Phase 8.4)

**F198. Forcing function for the numbered-question format (~45-75m) Priority 18**
- Harold at Sprint 67 retro: *"add 4 to backlog and tentatively for the next
  sprint"*. **Tentative, not selected.**
- Four corrections of the same rule (`feedback_qa_style_plain_numbered`) is what
  moved this from a memory item to a candidate control.
- The card carries its own counter-argument deliberately: a badly tuned check is
  worse than the prose rule, Sprint 67 already shipped one gate that blocked
  correct work, and the cheaper alternative -- moving the rule into CLAUDE.md,
  which is read every session, rather than memory recalled selectively -- must be
  evaluated before building a hook.

**GP-19 carry-forward: tester recruitment.** The standing critical path, and it is
not code. The Play closed test is live; 3 of 12 testers are opted in. The
production-access application date is set by the TWELFTH person to opt in, not the
first, so the nine remaining recruits gate everything downstream.

**F197. Dark-mode contrast GATE (~45-90m) Priority 26.** Rescoped during Sprint 67
from a 28-site sweep to a gate: both known instances of the mixing defect are
already fixed, so what remains is preventing the third.

## Reminders for whoever plans this sprint

- Read `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" FIRST (CLAUDE.md
  rule), then `SPRINT_PLANNING.md` for the augmented card template. Do not write
  cards from memory.
- ADR-0042 parity applies to every task: state the Windows and Android position
  explicitly, and declare a platform exception where behaviour genuinely cannot be
  shared. Tooling tasks say "N/A -- tooling" rather than omitting the question.
- Sprint 67's lesson, if this sprint adds any gate: **budget for the gate being
  wrong.** Three artifacts there looked like proof and were not, and none was found
  by reading -- only by mutation, review, or the hook's own suite.
