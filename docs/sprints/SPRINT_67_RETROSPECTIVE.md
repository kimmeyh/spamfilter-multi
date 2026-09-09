# Sprint 67 Retrospective

**Sprint**: 67 (2026-09-08 to 2026-09-09)
**Branch**: `feature/20260908_Sprint_67`
**PR**: #396
**Scope**: F194 (#392), F195 (#393), F193 (#394), F196 (#395)
**Version**: 0.14.2

**Roles**: Harold wears Product Owner / Scrum Master / Lead Developer and provided combined
feedback per category. Claude Code Development Team is the 4th role.

**Completeness gate**: 14 categories x 4 roles, all addressed. Harold's words recorded
verbatim, not paraphrased.

**Outcome**: all four tasks delivered. Manual Validation passed on Windows across all five
recommended steps. Three of Claude's own test artifacts were found to prove nothing and were
fixed; two written fixes were withdrawn entirely as redundant.

---

## 1. Effective while as Efficient as Reasonably Possible

**Product Owner / Scrum Master / Lead Developer (Harold)**: *"Can you note as an update for
Copilot reviews 'On the Copilot request. gh pr edit --add-reviewer Copilot failed silently
exactly as the workflow documents -- success output, nothing attached. The REST call with
copilot-pull-request-reviewer[bot] worked. Worth noting for the workflow doc: gh pr view
--json reviewRequests returns [] even on success because it does not render bot reviewers, so
the timeline is the only reliable check'"*

**Claude Code Development Team**: Effective -- all four tasks landed, plus two defects found
mid-sprint and a third found by the review. The efficiency story is uncomfortable and worth
stating plainly: **three of my own artifacts this sprint looked like proof and were not.** The
F194 test pinned the store contract instead of the call; the F195 test measured Flutter's
stock themes rather than the app's seeded ones; the F193 gate was satisfied by any prose
mentioning a marker name, and my own F-PRECHECK writing defeated it within minutes. Each was
caught only because something external tried to break it -- a mutation, a review, or the
hook's own suite. Two fixes were written and WITHDRAWN entirely after the mutation refused to
fail; the underlying cause was diagnosing from the middle of a call chain without reading the
layer beneath it.

**Harold's Copilot finding, verified empirically this sprint**: `gh pr view 396 --json
reviewRequests` returns `[]` even immediately after a SUCCESSFUL REST request, while
`/issues/396/timeline` shows the `review_requested` event. Confirmed in both directions.
Applied to `SPRINT_EXECUTION_WORKFLOW.md` as IMP-1.

## 2. Testing Approach

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The sprint's strongest and weakest category
simultaneously. Strongest: mutation testing caught every one of the three defective
artifacts above -- not one was found by reading. Weakest: I keep writing the assertion first
and testing it second. The F193 gate shipped and then broke six of the hook's own test cases,
a suite I had not run after modifying the hook it tests.

## 3. Effort Accuracy

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Coding estimates held. F194 was estimated at 60-120m with
diagnosis explicitly unbounded, and diagnosis did dominate -- correctly predicted at planning
time. The unestimated work was review fallout: two criticals, a wrong count, and a test
retarget. A sprint that ADDS gates should budget for the gates being wrong.

## 4. Planning Quality

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The F194 card was written AFTER reading the code, which
shaped it well: it kept three candidate causes open and named the 30-minute reconciliation
window as designed behaviour rather than a second bug. Both mattered, because the actual cause
turned out to be a fourth thing -- the display -- and the card's structure did not obstruct
finding it.

## 5. Model Assignments

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: No issues -- expectations met.

## 6. Communication

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: One real violation, and it is a repeat. I asked the
emulator uninstall decision as prose with a recommendation instead of a plain numbered list
answerable by typing a digit. Harold flagged it: *"noting this is not how I have requested you
ask questions."* That format has been corrected three times previously
(`feedback_qa_style_plain_numbered`, 2026-08-10). A rule corrected four times is not a memory
problem, it is a missing forcing function.

## 7. Requirements Clarity

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Clear. Harold's Default Folders counter-example during F195
was the single most useful input of the sprint: it moved the diagnosis from "hardcoded colours
are bad" to the actual rule -- the defect is MIXING a hardcoded surface with theme-derived
text -- and prevented a 28-site sweep that would have churned working code.

## 8. Documentation

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Good, with one correction I had to make to my own writing. I
claimed the contrast pattern appeared "28 times, concentrated in `account_setup_screen.dart`".
Measured, it is two, and that file cannot contain the pattern at all because it never uses
`textTheme`. I had grepped the easy proxy and reported it as the defect count. ADR-0043 is the
sprint's most durable document -- it captures a decision that existed only in conversation.

## 9. Process Issues

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The emulator misdiagnosis is the one I would most want
back. I declared a working toolchain unfixable after ONE failed launch on a path I had
hardcoded, when `ANDROID_HOME` already pointed at a current emulator (36.2.12.0 vs the 2019
build at 29.3.4.0 that I invoked). Harold refused the conclusion on the grounds that the
emulator is the only pre-Store Android test path. He was right, and the fix took one command.
The general shape: I reported an environmental blocker without checking the environment's own
configuration.

## 10. Risk Management

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The F193 gate firing during Phase 4 was a live regression in
a control meant to protect the process. It broke six allow-cases, including the one whose
whole premise is that a turn ending in a period is not a violation. A gate that blocks correct
work trains people to bypass gates, which is worse than having no gate.

## 11. Next Sprint Readiness

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Ready. F197 is correctly scoped now -- a gate, not a sweep.
The closed test is live and waiting on tester recruitment, which is the real critical path to
Play production access.

## 12. Architecture Maintenance

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: ADR-0043 written and accepted (one version across all
platforms; release notes derived per store). No other architecture changed.

## 13. Minor Function Updates for the Next Sprint Plan

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

**Claude Code Development Team**: None beyond what Harold recorded.

## 14. Function Updates for the Future Backlog

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

**Claude Code Development Team**: F197 (contrast gate) was registered and rescoped during the
sprint. Harold's Copilot finding is a workflow-doc change rather than a backlog item.

## Questions to be discussed before ending the sprint

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

---

## Improvements (Steps 5-7)

Harold's decision, 2026-09-09: **"now for 1-3, add 4 to backlog and tentatively for the next
sprint"**.

**IMP-1 (applied) -- Copilot review request, corrected in the workflow doc.** Harold's
Category 1 finding, verified empirically on PR #396 before writing it down. The documented
`gh pr edit --add-reviewer` forms FAIL SILENTLY: success output, exit 0, nothing attached --
worse than a 422, because it looks like it worked. The REST endpoint with the `[bot]` suffix
works. And `gh pr view --json reviewRequests` returns `[]` even after a SUCCESSFUL request,
because gh does not render bot reviewers, so the `/issues/<PR#>/timeline` event is the only
reliable confirmation. Applied to `SPRINT_EXECUTION_WORKFLOW.md` § 6.4, with the superseded
forms kept so nobody re-derives them.

**IMP-2 (applied) -- run a hook's own test suite after modifying that hook.** `CLAUDE.md`,
Things Claude Should NOT Do, with the runner command named. The F193 gate shipped and broke 6
of that hook's own allow-cases; the regression was found by a code review two commits later,
not by me, because I never ran `run-test-cases.ps1` after editing the hook it tests.

**IMP-3 (applied) -- resolve tool paths through the configured environment variable.**
`CLAUDE.md`. Print the version of the binary actually invoked before declaring any tool
broken. Sprint 67 reported the Android emulator as an unfixable SDK fault after one failed
launch on a hardcoded path, while `ANDROID_HOME` pointed at a working emulator six major
versions newer. Already recorded symptom-first in `TROUBLESHOOTING.md`; this generalises it
past emulators.

**IMP-4 (backlog, F198, TENTATIVELY Sprint 68) -- forcing function for the numbered-question
format.** Registered at Priority 18. The card deliberately carries its own counter-argument:
a badly tuned check is worse than the current prose rule, Sprint 67 already shipped one gate
that blocked correct work, and the cheaper alternative (moving the rule from memory into
CLAUDE.md, which is read every session) must be evaluated before building a hook.
