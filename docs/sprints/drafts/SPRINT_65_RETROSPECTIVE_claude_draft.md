# Sprint 65 Retrospective -- Claude Code Development Team DRAFT

**Author**: Claude (Opus 5), Phase 7.3 Step 2. Claude-authored draft for Step 3 use only.
**Never** substituted for Harold's Product Owner / Scrum Master / Lead Developer input.

**Date**: 2026-09-06

---

### 1. Effective while as Efficient as Reasonably Possible

All five tasks shipped, and the sprint's defining moment was Harold's refinement question --
"does the list include known timing dependencies that should drive the order?" -- which
exposed that my slate was ordered by BUILD dependency when the calendar was governed by the
12-tester / 14-day closed test. My first correction was ALSO wrong: I proposed starting the
clock first and doing listing work during the wait. Verified research overturned that,
because closed testing sits behind the same complete-setup wall as production. Two wrong
orderings caught before any work was done is cheap; the same discovery made mid-sprint
would have cost the sprint. The efficiency defect worth naming is the opposite: I ran three
agents in parallel on a shared tree and then committed into their mutation windows twice.

### 2. Testing Approach

Every new gate was mutation-verified, and three of them were only trustworthy BECAUSE of
that discipline. But the sprint's sharpest testing lesson came from Manual Validation, not
from the gates: Harold's zero-account screenshot proved the reviewer instructions named a
screen a fresh install never shows, and my gate passed the whole time because "Try Demo
Mode" is a SUBSTRING of the real label "Try Demo Mode instead". A containment assertion
cannot distinguish a label from a longer label that contains it. That is a general lesson
about `contains` in gates that assert exact UI text, not a one-off.

### 3. Effort Accuracy

Estimates were rebuilt in minutes from the velocity table after Harold caught them stated in
hours and counting his people time as coding. The rebuild put the sprint at 125-225m coding;
GP-6 alone went from 480-720m to 35-60m, roughly 12x, purely by removing screenshot capture
and copywriting. **Actuals were not recorded**: `CODING_VELOCITY.md` has zero Sprint 65 rows,
which violates the coverage guarantee (every implemented Item gets a row, logged at task
completion rather than batched). That is a real miss and it degrades the next sprint's
estimates, which is the whole point of the tracker.

### 4. Planning Quality

The plan's task ordering was derived from verified external research rather than assumption,
and the research paid for itself twice: it overturned my proposed ordering AND surfaced
GP-18 (App content declarations, including reviewer access) as a gap nothing in the project
tracked. Without it, App access would have been discovered as a blocker mid-rollout. The one
planning weakness: GP-7's card assumed icon work was needed when an audit-first requirement
revealed it was already complete -- the same shape as Sprint 64's GP-8. Two sprints running,
a "build it" card turned out to be a "verify it" card, which suggests the planning question
should be "is this already true?" before "how do we do this?".

### 5. Model Assignments

Cheapest-first held: Haiku for the icon audit, Sonnet for the three documentation-plus-gate
tasks, and the top tier reserved for planning, research and review. The Haiku task was
planned WITH its review pass per Sprint 64's IMP-5, and that worked exactly as intended --
no surprise rework. The reviewing agent also earned its tier: it mutation-tested the gates
rather than reading them, which is what surfaced both Phase 5.1.1 findings.

### 6. Communication

Harold's four-part message ("1 yes 2 all of it 3 not seeing the emulator 4 see 3") was
enumerated and answered part by part, which is the behaviour the multi-part-request rule
asks for. The semaphore question deserved a real answer rather than agreement: a counting
semaphore is the wrong primitive because the two parties are asymmetric, and the enforcement
belongs on the commit rather than the mutation. Saying so, and explaining why, was more
useful than building what was literally asked for.

### 7. Requirements Clarity

The ADR-0042 constraint was restated at selection and shaped every card: four tasks were
classified as deployment-infrastructure platform exceptions with the Microsoft Store listing
as the parity peer, and the two that touch app code carried explicit parity acceptance
criteria rather than assumptions. The GP-6 scope boundary (capture and copywriting are
Harold's people time) was stated in the card and held throughout -- no agent drifted into
attempting screenshots.

### 8. Documentation

The declarations are recorded WITH their code evidence rather than as bare answers, so the
next submission re-verifies from the document instead of re-deriving from memory. The
cross-store comparison did real work: it found two places where the LIVE Windows listing is
stale (a superseded privacy URL, and a "never stored" claim that is no longer accurate), and
correctly recorded them for Harold rather than propagating the inaccuracy to Play or editing
a live listing out of scope.

### 9. Process Issues

Three defects, all mine:

- **Two commit races.** `c2ec59b` swept up a live mutation probe; `c5fb46b` captured a FALSE
  Play declaration ("news app: Yes") while the justification in the same row said the
  opposite. Both commits were diff-reviewed first. Neither review caught it, because a
  one-word change inside a 150-line document is exactly what diff review misses.
- **A self-inflicted hook defect on first use.** My mutation-lock hook matched "git commit"
  anywhere in a command and immediately blocked the self-test written to verify it.
- **The security review then found three more holes in that same hook**, the worst being
  that a commit MESSAGE mentioning the override token disabled the gate entirely. Testing
  that fix surfaced a fourth bug of my own: a double timezone conversion that aged fresh
  locks and deleted them as stale.

The pattern across all of these: I built the safety mechanism correctly in concept and
shipped it with holes I only found by adversarial probing.

### 10. Risk Management

The highest-risk item was a false declaration reaching Google, and it happened -- briefly,
in committed history, caught by the review and repaired against the last-good blob rather
than retyped. The mutation-lock gate now makes that class structurally difficult rather than
dependent on vigilance. The residual risk I would name: the 12-tester recruitment has not
started, and its clock cannot start until every Sprint 65 deliverable reaches the console.
Nothing in the repo can move that date.

### 11. Next Sprint Readiness

Sprint 66 is well-defined: Harold enters the declarations and listing in the console,
captures the assets against `ASSET_SPEC.md`, then the closed-track rollout starts the 14-day
clock. Recruitment is the long pole and should begin immediately rather than after the
console work. The two stale Windows Store listing claims are queued for the next Windows
listing edit.

### 12. Architecture Maintenance

No architecture changed this sprint -- zero product-code diff. The ADR-0042 classification
was applied per card rather than assumed, and the one genuinely architectural observation is
the mutation-lock gate itself: it is now part of the testing contract and documented in
`TESTING_STRATEGY.md` with its verified behaviour table and the runtime-mismatch lesson.

### 13. Minor Function Updates for the Next Sprint Plan

None beyond what Sprint 66 already carries (console entry, asset capture, rollout).

### 14. Function Updates for the Future Backlog

Two candidates, surfaced for Step 5 decision rather than auto-added:
- Correct the two stale Microsoft Store listing claims (superseded privacy URL; the "never
  stored" body-preview claim) at the next Windows listing edit.
- A gate lint that flags `contains()` assertions on exact UI strings where a longer label
  containing the asserted substring exists in `lib/` -- the general form of the MV finding.
