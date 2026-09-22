# Sprint 72 Retrospective

**Date**: 2026-09-22
**Branch**: `feature/20260919_Sprint_71` | **PR**: #420 (draft, `-> develop`)
**Version**: 0.15.2+5 -> 0.15.3+6
**Scope**: F233, F232, F228, F230, F231, F217, F219 AC-1, plus clearing 22 unmerged doc commits

**Roles**: Harold wears Product Owner, Scrum Master and Lead Developer and gave COMBINED feedback.
Claude provides the fourth role, Claude Code Development Team.

---

## 1. Effective while as Efficient as Reasonably Possible

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Effective, and the efficiency came from two specific places.
> The **audit-first check** turned F233 from "build a logger" into "add a sink to the one that
> exists" -- `LiveScanLogger` was already cross-platform, MSIX-safe and redacting emails. That is
> ~150 minutes against a 180-300 estimate, and the saving came from reading before building.
> Second, **F229's screen half delivered nothing and the time was still well spent**: the attempt
> overflowed by 18px and turned four tests red, which answered Harold's "if room" question by
> measurement rather than opinion. A reverted change that produces a firm answer is not waste.
> **Against that**: I did the F233 work and never built its UI, so the most visible part of the
> sprint's headline card was inert until manual validation caught it. That is the opposite of
> efficient -- it cost a validation round trip.

## 2. Testing Approach

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: 74 new tests, and every headline fix was mutation-verified --
> the CSV export, the F232 guard, the F228 outcome semantics, the bounded domain, and the C-1
> review fix all go red when the fix is reverted. **But the approach has a demonstrated blind
> spot, and it fired twice in one sprint.** The F233 tests set the enabled flag through
> `DiagnosticLogger.debugSetEnabled` -- the test seam -- and asserted the logger behaved. Ten
> green, none through the path a user has, and the feature was unreachable. Separately, the
> original F232 tests asserted the resolution tiers and nothing about the historical-load path,
> which is where the CRITICAL defect was. Both are the same shape: green tests exercising the half
> that works. The repo already has a rule for this ("source gates prove a symbol EXISTS, not that
> it WORKS") and I wrote a "what these tests do NOT catch" note on the very file that failed.

## 3. Effort Accuracy

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Seven rows logged, and the variances are informative rather
> than noise -- which is what the velocity file is for. F232 mechanism A came in at ~90 against
> 240-360, and that is **not** evidence of overestimation: the estimate assumed diagnosing
> mechanism B as well, and B is still undiagnosed. The card was two cards. F217 came in at ~70
> against 240-480 because the mechanism was not built, with 170-410 minutes still owed if Harold
> picks the exemption. Recording WHY a number moved is more useful than the number.

## 4. Planning Quality

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: The plan's strongest feature was naming traps before
> implementation hit them -- the `text_contrast_test` WCAG-thresholds-depend-on-font-size warning,
> the "bounding the domain or the overflow just relocates" note, and the F172 precedent. All three
> were real and all three were handled because the card said so. **The plan's worst failure was
> F233's R-3 and R-4**: I wrote the Settings toggle and the delete action into the requirements and
> then did not build them, and no gate noticed because the card's acceptance criteria were about
> the logger's behavior rather than its reachability.

## 5. Model Assignments

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Assignments were cheapest-first with recorded justifications,
> but **everything actually executed on Opus** because the sprint ran as one continuous session.
> That is the Sprint 68 IMP-4 pattern and it should be recorded honestly rather than left implied.
> The one genuinely top-tier task (F232, an open diagnosis plus a Class-2 change) justified it; the
> Haiku-assigned tasks did not need it.

## 6. Communication

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Harold's mid-turn corrections were consistently the highest-value
> input in the sprint, and three of them changed outcomes: *"The export may only be working if
> requested"* turned a hypothesis into a confirmed defect with a named cause; his A/B comparison
> (the background scan deletes the same mail minutes later) eliminated every environment-level
> explanation at once; and *"where"* found an unreachable feature. **What I should do differently**:
> in each case he saw it because he was USING the app and I was reading source.

## 7. Requirements Clarity

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Two instructions were unusually well-specified and both paid
> off. The ADR-0042 standing requirement -- *"this applies to all backend code, frontend code,
> data, architecture, development, security, testing, deployment"* -- made every card carry a
> parity line, which surfaced the F233 directory exception and the F217 Doze exception explicitly
> rather than by accident. And the **conditional** instruction on F217 (*"search to ensure this is
> the only way"*) was the single best-designed requirement of the sprint: it built the verification
> into the ask, so when the premise failed the work stopped instead of proceeding on a stale
> decision.

## 8. Documentation

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Comments carried the WHY and the evidence, which is the house
> style. **But three comment defects shipped and the 5.1.1 review caught all three**: a claim that
> the batch was PARTITIONED per account (neither half true), a stale Sprint 38 comment describing a
> mechanism F232 had removed, and an F217 block that orphaned the F109a comment from its function.
> The first is the Sprint 70 CRITICAL pattern exactly -- a comment asserting a safety property that
> nothing implements -- in the sprint whose own IMP-2 is about that.

## 9. Process Issues

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: **I went straight from plan approval into execution and skipped
> Phase 3.3.1 entirely** -- no issue cards, no draft PR. The `require-sprint-cards` hook blocked the
> first task commit and was right; its own text names the trigger (a branch that already exists from
> carry-forward, so the first commit feels like execution is underway). That is exactly what
> happened. The gate worked; the process step did not. Separately, three Python-through-bash
> heredocs lost backslashes and one produced a silent no-op whose success message lied -- the fix is
> to write scripts to files rather than pipe them through the shell.

## 10. Risk Management

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: The plan named the unintended-deletion risk for F232 and I
> introduced it anyway. C-1: the fix went inside a method THREE callers share, and the third runs
> on screen load with no user intent -- so viewing history could delete mail on a live-configured
> account. The mitigation I wrote ("R-6 keeps configured read-only genuinely read-only") addressed
> a different risk than the one that materialised. **Naming a risk is not managing it**; what
> managed it was the 5.1.1 review, and I should treat "which callers share this method" as a
> mandatory question whenever a guard is changed.

## 11. Next Sprint Readiness

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: Ready, with three items carrying real evidence rather than
> intentions: F235 (Doze mechanism, targeted by Harold, with the `USE_EXACT_ALARM` policy risk and
> the reboot-persistence regression already written into the card), F234 (read-only as preview),
> and F232 mechanism B -- which is now INSTRUMENTED rather than guessed at, so the next attempt
> starts with data.

## 12. Architecture Maintenance

> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

> **Claude Code Development Team**: No ADR changes needed; three ADR-0042 exceptions declared with
> their OS-level justifications named per IMP-5. **The architecture failure was C-2b**: I
> hand-rolled a scan-mode resolver while `SettingsStore.getEffectiveScanMode` already existed, was
> correct, and was documented -- and my copy implemented two of its three tiers. That is the repo's
> own "do not design a new member of a shared abstraction without reading the existing one" rule,
> broken in the sprint that cites it.

## 13. Minor function updates that need to be added to the next sprint plan

> **Product Owner / Scrum Master / Lead Developer (Harold)**: none

> **Claude Code Development Team**: None beyond what is already targeted (F235, F234, F232-B).

## 14. Function updates that can be added to the backlog for a future sprint

> **Product Owner / Scrum Master / Lead Developer (Harold)**: none

> **Claude Code Development Team**: None. The backlog gained F234 and F235 during the sprint and
> both are filed with full cards.

---

## Questions to be discussed before ending the sprint

> **Harold**: none

> **Claude**: none blocking. Two decisions remain open and are recorded rather than pressed:
> whether F229's screen half is worth the AppBar-title change, and whether F234's preview covers
> safe-sender moves as well as block rules.

---

## Metrics

| | |
|---|---|
| Test suite | 2,155 -> **2,229** (+74) |
| Analyzer | clean |
| Hook suite | 75 passed / 0 failed |
| WinWright | 2/2 scripts, 29/29 steps, no DB drift (run twice) |
| Review findings | 2 CRITICAL, 3 IMPORTANT -- all fixed, 0 deferred |
| Manual validation | 4 PASS, 1 failed-fixed-repassed, 1 N/A |
| Backlog filed | F234, F235 |
| Cards | #421-427, plus #428 for F235 |

## The four things worth remembering

**1. A green test suite hid an unreachable feature.** F233's tests set the enabled flag through
the test seam and asserted the logger worked. Ten passed. There was no way for a user to turn it
on. The same shape hid the F232 CRITICAL: tests asserted the resolution tiers, not the
historical-load path where the defect lived. **Both were tests exercising the half that works.**

**2. The fix was applied one level too deep.** F232's guard change went inside a method three
callers share. Two were the target; the third runs on screen load with no user intent, and before
the fix it was inert BY ACCIDENT. Removing the accident created a deletion path from viewing
history. "Which callers share this method?" belongs in the checklist whenever a guard changes.

**3. Harold found what reading source did not, three times.** "The export may only be working if
requested" named a cause; the background-scan A/B eliminated every environment explanation at once;
"where" found the missing UI. Each came from USING the app.

**4. A conditional requirement stopped work that would otherwise have proceeded on a stale
premise.** F217 was approved on 2026-09-19 on the belief that the battery exemption was the only
route. Harold's instruction built the check into the ask -- *"search to ensure this is the only
way"* -- and it was not, so only the honest messaging shipped and the mechanism became F235 with a
better approach. **The requirement design did that, not the execution.**
