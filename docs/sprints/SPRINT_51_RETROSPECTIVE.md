# Sprint 51 Retrospective

**Sprint**: 51
**Dates**: 2026-07-27 -- 2026-07-30
**Branch**: `feature/20260727_Sprint_51`
**Scope**: F130-S51 (process-docs consistency deep dive, time-boxed by tier), F128-residual, F129
**Manual Validation**: COMPLETE -- all 5 items (MV-1..MV-5) validated by Harold 2026-07-30, all "Working as expected. Can be closed."

**Roles**: Harold provided combined Product Owner / Scrum Master / Lead Developer feedback (3 of the
4 mandatory roles). Claude provides the Claude Code Development Team role (4th). All 14 categories
addressed by both.

---

## 1. Effective while as Efficient as Reasonably Possible

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Mixed, and honestly weaker than the pass rate suggests. The three
planned tasks landed and every verification gate is green, but a material share of the sprint went to
rework I caused: the account-picker semantics shipped BROKEN mid-sprint (named but unclickable), and
I burned three WinWright runs on wrong diagnoses -- a settle-timing theory, then a priming theory --
before finding the real defect. Efficient work would have driven the control once after changing it
instead of reasoning about tree dumps. Genuinely efficient: running the two Tier-2 audits as parallel
read-only agents with the authoritative facts supplied as an explicit checklist. That produced 16
findings with exact line numbers and zero false positives, and is the single practice most worth
repeating.

## 2. Testing Approach

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Strong where it counted and the weak spot is now named. The
widget/WinWright split worked: WinWright proved reachability end-to-end while widget tests proved
semantics deterministically, which matters because the Windows UIA projection proved unreliable as a
verification instrument (MCP snapshot and CLI `inspect` disagreed on the same process at the same
moment). The gap this sprint exposed: **a tree dump proves a name exists; only an interaction proves
the node still works.** Both broken picker shapes looked correct in a dump. Every future
accessibility change needs a script that DRIVES the control, not one that inspects it. Also
confirmed: the F56 create-path scripts are stale, not merely excluded -- their documented workaround
did not reproduce. Filed as F131 rather than left as a trap.

## 3. Effort Accuracy

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The `[no-history]` discipline held and proved its worth. Task 1 was
time-boxed by tier rather than estimated, which was correct -- discovery ran to 28 findings across
three tiers, and any up-front number would have been fiction. Task 3 was flagged `[no-history]` and
genuinely was: authoring the scripts was minutes; discovering the harness constraints and my own
defect was the real cost, and nothing in `CODING_VELOCITY.md` predicts that. Actuals should be
recorded for the WinWright step-type so the next F129-class item is the first genuinely estimated one.

## 4. Planning Quality

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The plan held up under a sprint that expanded considerably. Two
elements earned their keep: the Phase 3.2.2.1 branch-state gate (verified all three tasks were
genuinely unstarted before work began), and Task 1's tier structure, which made "stop at a tier
boundary" a planned outcome rather than a failure -- though in the event all three tiers completed.
Weak spot: Task 3's acceptance criteria said "three scripts" and I marked it complete with two. The
plan was right; my tracking of it was not.

## 5. Model Assignments

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: No friction. The planner/analyst work (audit, findings synthesis,
retrospective) ran top-tier per `SPRINT_PLANNING.md`; the mechanical doc corrections would have
suited a cheaper tier and were executed inline because they were single-line edits discovered
mid-audit rather than planned tasks. Worth noting for honesty: no task this sprint was deliberately
designed-for-Haiku-first, because the sprint was audit- and discovery-shaped rather than
implementation-shaped.

## 6. Communication

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Two failures worth recording. I reported Task 3 complete when one of
three required scripts did not exist, and I twice reported the Store issue "fixed" on the strength of
a page rendering, when the event log said otherwise. Both are the same error: reporting a conclusion
from a partial signal instead of the authoritative one. What worked: stating corrections plainly when
evidence contradicted me (the `ww_click` retraction, the "Manage Rules unreachable" correction)
rather than quietly moving on.

## 7. Requirements Clarity

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Harold's scope was unambiguous throughout, including the mid-sprint
accessibility instruction ("add all semantic tree elements as needed") which was broad but clearly
bounded. The one genuine ambiguity I hit was MT-2c's contract -- whether to prove the sweep by
creating a rule or by proving stability -- and that resolved cleanly once the create path proved
undrivable.

## 8. Documentation

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The strongest dimension this sprint. 28 contradictions found and
corrected, including one (`build_windows_args` in CLAUDE.md) that actively contradicted a
build-failing test and had previously shipped a broken Store build. The `sprint_status.json` orphan
-- mandatory in the checklist, absent from the retrospective doc that drives Phase 7.7 -- was exactly
the shape F130 was chartered to find. The DoD re-grep rule proved itself: finding 27 (AGENTS.md
carrying the identical wrong msix key) was invisible to the audit pass and visible only to
verification.

## 9. Process Issues

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Three hooks fired on correct work across Sprints 50-51, and the root
cause is consistent: hooks key on shape (branch name, question form, string match) with no notion of
context. This sprint added a new instance -- `sprint-auto-advance` blocking a question about
uninstalling Harold's security software, which no sprint plan authorizes Claude to decide. The hook's
pressure was to answer anyway and proceed; complying would have been the wrong behavior. Recorded as
an F130 finding rather than fixed, because in-sprint hook edits were themselves a Sprint 51 finding.

## 10. Risk Management

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Handled well on the release side and poorly on one self-assessment.
Well: the Partner Center check caught that 0.5.8 was sitting in DRAFT and had never been submitted,
despite `sprint_status.json` asserting "in certification" for a full day. Poorly: I repeated that
file's claim as fact rather than verifying it, and reasoned from it publicly several times. The
durable lesson is already recorded in the file itself -- BUILT + VALIDATED is not SUBMITTED, and
release state is verified in Partner Center, never from a tracking file.

## 11. Next Sprint Readiness

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Good. Three carry-in candidates are carded with evidence rather than
intuition (F131, F132, ENV-1 resolved), the backlog is current, and `sprint_status.json` now reflects
true state including the 0.5.8 LIVE status and the four unblocked post-cert close-out items. Harold's
Category 14 items add a well-defined accessibility spike plus a set of concrete UI ordering changes.

## 12. Architecture Maintenance

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: No architectural changes this sprint, so no ADR work was required.
ADR-0037 (UI/Accessibility Standards) is directly relevant to the F132 proposal and already sets WCAG
2.1 AA as the target -- the accessibility spike Harold requested should extend that ADR rather than
create a competing document. One note: the semantics wrapper pattern established this sprint
(`excludeSemantics` + `onTap` on the Semantics node) is currently documented only in
`test/winwright/README.md`. It belongs in the accessibility reference F132 will produce.

## 13. Minor Function Updates for the Next Sprint Plan

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

**Claude Code Development Team**: None from Claude beyond Harold's Category 14 list. Harold's four
UI-ordering items and the "No Rule" default-screen change are well-specified and small; the Skip
button is the only one with real design surface.

## 14. Function Updates for the Future Backlog

**Product Owner / Scrum Master / Lead Developer (Harold)** (verbatim):

> - Add to backlog as a repeatable HOLD item and assign a copy to the next sprint
>   - Accessibility audit
>     - please do spike research on Accessibility best practices and standards.
>     - Add/update a repository copy of Accessibility best practices for future reference
>     - Identify gaps in the current Application and code base (focused on the UI for each active, prod UI) and plan tasks to resolve the gaps
>   - Should include, but not limited to: colors, screen reader needs, flutter testing needs, WinWright testing needs,
>     - One known current gaps is semantic tree elements that as needed for accessibility and WinWright testing on all screens
> - Add to backlog for next sprint
>   - On the all the settings pages, update the icons so they appear in this order: Review "No Rules Items, View Scan History, Accounts, Settings, Help
>   - On the Manual Scan screen, update the icons so they appear in this order: Review "No Rules Items, View Scan History, Accounts, Settings, Help
>   - On the Results - Demo Scan screen and Live Scan Screen, update the icons so they appear in this order: Download, Find, Review "No Rules Items, View Scan History, Accounts, Settings, Help
>   - Need to add the following icons to the Review "No Rules" Items screen: Help, View Scan History, Accounts, Settings -- so they appear in this order: Refresh, View Scan History, Accounts, Settings, Help
> - Add to backlog for next sprint
>   - If one or more accounts exist, the new "default" screen will the Review "No Rules" Items screen
>   - When going to the settings screen, the account selection pop-up is not needed.
>   - When the user, while in settings, goes to the
> - Add to backlog for next sprint
>   - In the Live Scan and Scan Results pages > "No rule" filter selected > item pop-up
>     - can you add a "Skip" button in the header - leaves the current item unaffected and goes to the next unaddressed item in the list - button should be about the same size as the safe sender and rules buttons.
> The Select Account pop-up

**Claude Code Development Team**: Already carded this sprint: F131 (WinWright create-path undrivable;
F56 scripts stale) and F132 (systematic accessibility sweep). Harold's Category 14
accessibility-spike request should supersede or absorb F132 rather than duplicate it -- his framing
is broader and better (research + repository standards doc + gap analysis), and two overlapping cards
would be exactly the duplication F130 warns about.

---

## Questions to be discussed before ending the sprint

**Harold**: none

**Claude**: One incomplete item in Harold's Category 14 feedback needs clarification before it can be
carded -- see Improvement Decisions below.

---

## Improvement Decisions

Harold, 2026-07-30: **all 7 proposals APPLY NOW.** ("apply now imp-1, 2, 3 ... apply now 4, 5, 6, 7
(needed now).")

| # | Improvement | Disposition |
|---|---|---|
| IMP-1 | Accessibility audit as repeatable HOLD template (F133), absorbing F132 | APPLY NOW |
| IMP-2 | AppBar icon ordering across five surfaces (F134) | APPLY NOW |
| IMP-3 | No-Rule default screen + session-scoped account selection (F135) | APPLY NOW |
| IMP-4 | Skip button in the No-Rule item popup (F136) | APPLY NOW |
| IMP-5 | Record WinWright actuals in CODING_VELOCITY.md | APPLY NOW |
| IMP-6 | "Drive it, don't dump it" rule for accessibility changes | APPLY NOW |
| IMP-7 | Hook context-awareness for non-sprint turns | APPLY NOW ("needed now") |

### IMP-3 clarification (Harold, verbatim)

> If an account is selected while the app is running, the app should keep track of this setting and
> assume any other needs for the account resolve to this selection unless the user returns to the
> Account page and selects another. The pop-up should appear only as needed: 1) an account has not
> been selected AND 2) the user gets to a page that needs it (3 account-specific settings pages and
> the Manual Live Scan page).

This resolves the truncated Category-14 bullet and defines the account-resolution rule: a
**session-scoped selected account**, set by choosing an account on the Account page, cleared only by
choosing a different one. The picker becomes **lazy** -- shown only when no account is selected AND
the destination requires one (Settings Account / Manual Scan / Background tabs, and the Manual Live
Scan page). The General tab is cross-account and must NOT prompt.

### IMP-7 note

Claude recommended deferring this because in-sprint hook edits were themselves a Sprint 51 finding.
Harold overrode with "needed now" -- the hook is actively blocking legitimate non-sprint turns, so
the cost of leaving it is higher than the cost of touching it mid-sprint. Applied with regression
test cases, consistent with how the other two hook fixes were handled this sprint.
