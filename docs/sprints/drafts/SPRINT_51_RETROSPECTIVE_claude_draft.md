# Sprint 51 Retrospective -- Claude Code Development Team draft

**Author**: Claude (Claude Code Development Team role only)
**Purpose**: Step 2 artifact of the 7-Step Retrospective Protocol. Feeds Step 3 of
`docs/sprints/SPRINT_51_RETROSPECTIVE.md`. This is NEVER a substitute for Harold's PO/SM/Lead input.
**Date**: 2026-07-30

---

## 1. Effective while as Efficient as Reasonably Possible

Mixed, and honestly weaker than the pass rate suggests. The three planned tasks landed and every
verification gate is green, but a material share of the sprint went to rework I caused: the
account-picker semantics shipped BROKEN mid-sprint (named but unclickable), and I burned three
WinWright runs on wrong diagnoses -- a settle-timing theory, then a priming theory -- before finding
the real defect. Efficient work would have driven the control once after changing it instead of
reasoning about tree dumps.

Genuinely efficient: running the two Tier-2 audits as parallel read-only agents with the
authoritative facts supplied as an explicit checklist. That produced 16 findings with exact line
numbers and zero false positives, and is the single practice most worth repeating.

## 2. Testing Approach

Strong where it counted and the weak spot is now named. The widget/WinWright split worked: WinWright
proved reachability end-to-end while widget tests proved semantics deterministically, which matters
because the Windows UIA projection proved unreliable as a verification instrument (MCP snapshot and
CLI `inspect` disagreed on the same process at the same moment).

The gap this sprint exposed: **a tree dump proves a name exists; only an interaction proves the node
still works.** Both broken picker shapes looked correct in a dump. Every future accessibility change
needs a script that DRIVES the control, not one that inspects it.

Also confirmed: the F56 create-path scripts are stale, not merely excluded -- their documented
workaround did not reproduce. Filed as F131 rather than left as a trap.

## 3. Effort Accuracy

The `[no-history]` discipline held and proved its worth. Task 1 was time-boxed by tier rather than
estimated, which was correct -- discovery ran to 28 findings across three tiers, and any up-front
number would have been fiction. Task 3 was flagged `[no-history]` and genuinely was: authoring the
scripts was minutes; discovering the harness constraints and my own defect was the real cost, and
nothing in `CODING_VELOCITY.md` predicts that.

Actuals should be recorded for the WinWright step-type so the next F129-class item is the first
genuinely estimated one.

## 4. Planning Quality

The plan held up under a sprint that expanded considerably. Two elements earned their keep: the
Phase 3.2.2.1 branch-state gate (verified all three tasks were genuinely unstarted before work
began), and Task 1's tier structure, which made "stop at a tier boundary" a planned outcome rather
than a failure -- though in the event all three tiers completed.

Weak spot: Task 3's acceptance criteria said "three scripts" and I marked it complete with two. The
plan was right; my tracking of it was not.

## 5. Model Assignments

No friction. The planner/analyst work (audit, findings synthesis, retrospective) ran top-tier per
`SPRINT_PLANNING.md`; the mechanical doc corrections would have suited a cheaper tier and were
executed inline because they were single-line edits discovered mid-audit rather than planned tasks.
Worth noting for honesty: no task this sprint was deliberately designed-for-Haiku-first, because the
sprint was audit- and discovery-shaped rather than implementation-shaped.

## 6. Communication

Two failures worth recording. I reported Task 3 complete when one of three required scripts did not
exist, and I twice reported the Store issue "fixed" on the strength of a page rendering, when the
event log said otherwise. Both are the same error: reporting a conclusion from a partial signal
instead of the authoritative one.

What worked: stating corrections plainly when evidence contradicted me (the `ww_click` retraction,
the "Manage Rules unreachable" correction) rather than quietly moving on.

## 7. Requirements Clarity

Harold's scope was unambiguous throughout, including the mid-sprint accessibility instruction ("add
all semantic tree elements as needed") which was broad but clearly bounded. The one genuine ambiguity
I hit was MT-2c's contract -- whether to prove the sweep by creating a rule or by proving stability
-- and that resolved cleanly once the create path proved undrivable.

## 8. Documentation

The strongest dimension this sprint. 28 contradictions found and corrected, including one
(`build_windows_args` in CLAUDE.md) that actively contradicted a build-failing test and had
previously shipped a broken Store build. The `sprint_status.json` orphan -- mandatory in the
checklist, absent from the retrospective doc that drives Phase 7.7 -- was exactly the shape F130 was
chartered to find.

The DoD re-grep rule proved itself: finding 27 (AGENTS.md carrying the identical wrong msix key) was
invisible to the audit pass and visible only to verification.

## 9. Process Issues

Three hooks fired on correct work across Sprints 50-51, and the root cause is consistent: hooks key
on shape (branch name, question form, string match) with no notion of context. This sprint added a
new instance -- `sprint-auto-advance` blocking a question about uninstalling Harold's security
software, which no sprint plan authorizes Claude to decide. The hook's pressure was to answer anyway
and proceed; complying would have been the wrong behavior.

Recorded as an F130 finding rather than fixed, because in-sprint hook edits were themselves a Sprint
51 finding.

## 10. Risk Management

Handled well on the release side and poorly on one self-assessment. Well: the Partner Center check
caught that 0.5.8 was sitting in DRAFT and had never been submitted, despite `sprint_status.json`
asserting "in certification" for a full day. Poorly: I repeated that file's claim as fact rather than
verifying it, and reasoned from it publicly several times.

The durable lesson is already recorded in the file itself -- BUILT + VALIDATED is not SUBMITTED, and
release state is verified in Partner Center, never from a tracking file.

## 11. Next Sprint Readiness

Good. Three carry-in candidates are carded with evidence rather than intuition (F131, F132, ENV-1
resolved), the backlog is current, and `sprint_status.json` now reflects true state including the
0.5.8 LIVE status and the four unblocked post-cert close-out items. Harold's Category 14 items add a
well-defined accessibility spike plus a set of concrete UI ordering changes.

## 12. Architecture Maintenance

No architectural changes this sprint, so no ADR work was required. ADR-0037 (UI/Accessibility
Standards) is directly relevant to the F132 proposal and already sets WCAG 2.1 AA as the target --
the accessibility spike Harold requested should extend that ADR rather than create a competing
document.

One note: the semantics wrapper pattern established this sprint (`excludeSemantics` + `onTap` on the
Semantics node) is currently documented only in `test/winwright/README.md`. It belongs in the
accessibility reference F132 will produce.

## 13. Minor Function Updates for the Next Sprint Plan

None from Claude beyond Harold's list. Harold's four UI-ordering items and the "No Rule" default-screen
change are well-specified and small; the Skip button is the only one with real design surface.

## 14. Function Updates for the Future Backlog

Already carded this sprint: F131 (WinWright create-path undrivable; F56 scripts stale) and F132
(systematic accessibility sweep). Harold's Category 14 accessibility-spike request should supersede
or absorb F132 rather than duplicate it -- his framing is broader and better (research + repository
standards doc + gap analysis), and two overlapping cards would be exactly the duplication F130 warns
about.
