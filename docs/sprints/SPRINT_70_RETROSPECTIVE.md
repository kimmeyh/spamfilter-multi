# Sprint 70 Retrospective

**Sprint**: 70 -- scan lifecycle, sign-in, and the toolchain
**Dates**: 2026-09-17 to 2026-09-19
**Scope**: F218 + F220 + F221 + F212 + F219 + F217 (6 tasks, all delivered)
**Branch**: `feature/20260914_Sprint_70` | **PR**: #418 (merged to develop), #419 (develop to main)
**Version**: 0.15.1+4 -> 0.15.2+5

## Outcome

| | |
|---|---|
| Tasks delivered | 6 of 6 |
| Test suite | 2,119 -> **2,155** passed, 15 skipped, **0 failed** |
| Analyzer | clean |
| Hook suite | 74 passed, **0 failed** (first fully green run this sprint) |
| Code-review findings | 1 Copilot HIGH + 2 CRITICAL + 4 IMPORTANT, all addressed, 0 deferred |
| F-PRECHECK findings | 2 found, 2 fixed |
| New backlog items filed | 5 (F223 fixed in-sprint, F224-F227; F227 also fixed in-sprint) |

**Manual Validation**: Windows complete (F212 verified by Harold). Android emulator verified the
F219 task-affinity fix, the runtime launch gate, launcher start, and return-from-recents, and
FOUND F227 -- a second defect on the same OAuth path, fixed and re-verified. F219 AC-1 (end-to-end
sign-in with a listed test user) requires a Play-signed build and is carried to Sprint 71.

**Three defects were found by review layers rather than by implementation**, and two of them were
gates that reported protection they did not provide. That is the sprint's central finding.

---

## Sprint 70 Retrospective Feedback

**Harold** wears three roles (Product Owner, Scrum Master, Lead Developer) and gave combined
feedback. **Claude Code Development Team** feedback is the execution-side view, drafted in
parallel per the 7-Step Protocol and recorded verbatim from
`docs/sprints/drafts/SPRINT_70_RETROSPECTIVE_claude_draft.md`.

**Note on divergence**: Claude's ratings are LOWER than Harold's in five categories. That is
deliberate and is the useful part of this record -- a retrospective where the execution role
agrees with every rating is echoing, not providing a second perspective.

### 1. Effective while as Efficient as Reasonably Possible
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good, not Very Good.**
>
> Delivered: 6 planned tasks plus 3 defects found during validation (F223, F227, plus the
> auto-advance hook), suite 2,119 -> 2,149, both platforms addressed.
>
> The efficiency problem is concentrated and measurable: **F220 was delivered twice.** The first
> implementation was committed, documented with a confident doc comment, and was not a fix. The
> review found the mechanism claim was false, and the whole task was re-done. That is the same shape
> as Sprint 69's F209 (delivered twice, caught by review), which means the class was known and
> recurred anyway.
>
> Against that: the emulator probing was genuinely efficient. Three questions -- how many activities
> claim the scheme, where does the redirect land, what is the task affinity -- replaced an argument
> with an answer in minutes, and found F227, a defect nobody had reported.

---

### 2. Testing Approach
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Mixed. Strong practice, one severe hole.**
>
> Good: every new test was mutation-verified before being trusted. That caught a test of my own that
> was wrong on first write (the F220 queue test applied an outer `Future.timeout`, so it proved
> `Future.timeout` works and would have passed with the coordinator gutted). It also caught a source
> gate that could have passed vacuously.
>
> **The hole is the important finding of this sprint.** F220's test asserted
> `provider.status == ScanStatus.error` and never asserted `coordinator.active == null`. It passed,
> it was mutation-verified, and it was testing the half that worked while the actual defect was
> untouched. Mutation testing did not save me, because I mutated the thing the test covered rather
> than asking whether the test covered the right thing.
>
> CLAUDE.md already carries "verify the FAILURE path, not just the happy path". I followed the letter
> (I broke things and watched tests go red) and missed the intent (I never asked what the test would
> NOT catch).

---

### 3. Effort Accuracy
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good.**
>
> Estimates held for the planned work. What they did not cover was the sprint's actual shape: three
> defects discovered during Phase 5 (F223 forced by a build gate, F227 by emulator probing, plus the
> auto-advance hook), and one full re-do of F220. Roughly a third of the sprint's real effort went to
> work that was not in the plan.
>
> That is not an estimation failure -- unknown defects cannot be estimated. It is an argument that
> "validation" is not a cheap tail-end phase, which is worth carrying into planning rather than
> treating each sprint's overrun as a surprise.

---

### 4. Planning Quality
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good, with a caveat the plan itself could not have avoided.**
>
> The plan's requirements were unusually strong at directing behaviour. R-1 on F212 ("get the
> exception first"), R-4 on F221 ("check whether the message REACHES the user before writing a new
> one"), R-2 on F219 ("probe rather than reasoning from the issue tracker") each prevented wasted
> work. F221's R-4 in particular stopped me writing a message that already existed.
>
> **Two cards had incorrect premises, and both were caught by following the plan's own instructions:**
> - **F221 R-2(a)** assumed the superseded scan's row sticks. It cannot -- the persisted row is
>   created after the lease is acquired, so a queued scan holds no row at all.
> - **F212 R-2** named coordinator bypass as the leading cause. The bypass was real but was not the
>   cause; the adapters disagreeing about "not connected" was.
>
> Both are evidence the plan was written carefully enough to be falsifiable, which is better than a
> plan too vague to be wrong.

---

### 5. Model Assignments
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Acceptable, but the assignment step is becoming ritual.**
>
> Every task was assigned cheapest-first at plan time, and every task executed in-session on Opus 5.
> That is the "10/10 assigned Haiku/Sonnet, 10/10 executed by the session model" pattern Sprint 50's
> IMP-7 flagged, and CLAUDE.md says a sprint where every line reads "in-session" with no
> distinguishing reason is a signal to surface it. I am surfacing it.
>
> For this sprint the justification is real: F220/F221/F212 shared coordinator lease semantics and
> in-flight context, and splitting them across models would have cost more in context transfer than
> it saved. But the honest read is that the assignment step did not influence execution at all, and
> a step that never changes the outcome should either be given teeth or acknowledged as advisory.

---

### 6. Communication
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Needs improvement -- two failures, one repeated.**
>
> **I twice announced a task as started and then ended the turn without starting it.** "Starting F219
> now." followed by nothing. Harold caught both: *"you did not start F219"*. The second occurrence
> came after I had already acknowledged and corrected the first, which means my correction did
> nothing.
>
> The root cause turned out to be mechanical and worth the finding: the Stop hook that exists to
> catch exactly this had two holes, and one of them I created when I added the timestamp footer
> Harold requested -- every commitment pattern was end-anchored, so a trailing footer made them
> unmatchable. A documentation preference silently disabled a safety gate and nothing announced it.
>
> **I also reported a false timestamp**, carrying `12:18am` forward from an earlier message when the
> real time was `1:15am`. Harold asked directly whether it was the system clock. In that same footer
> the phase and sprint number were correct, because they came from files I read; the one field filled
> from memory was the one that was wrong.

---

### 7. Requirements Clarity
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Very Good.**
>
> Harold's requirements were specific and, in the F221 case, better reasoned than my own position. I
> recommended against a manual-scan timeout on the grounds that F220's lifecycle fix made one
> unnecessary. Harold's correction -- *"Once a user switches screens they can no longer cancel"* --
> identified a case my argument did not cover, and he was right. His instruction that the timeout
> must survive navigation is what drove placing it in a top-level function; putting it in the State
> class would have silently failed the exact case he specified.
>
> Mid-sprint steering was equally precise: *"it makes no sense to include F219 in any additional
> phrasing as <> could be any of the backlog items"* corrected a hook fix that would have been
> overfitted to one identifier.

---

### 8. Documentation
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good, with one self-inflicted defect.**
>
> Every fix carries its reasoning, superseded decisions are rewritten rather than deleted (the
> F221 timeout reversal, the F217 parity declaration), and the F227 manifest comment records the
> measured evidence so the next person inherits the finding rather than the conclusion.
>
> **The defect: F220's doc comment asserted a mechanism that did not exist.** "The scanner's own
> `finally` then releases the lease" was written confidently and was false. That is worse than no
> comment -- it would have actively misled the next reader into believing the path was covered.
> Documentation confidence must be bounded by verification, and it was not.

---

### 9. Process Issues
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: The gates worked. I did not.**
>
> The F193 evidence gate blocked Manual Validation twice, and was right both times:
> - First block: I had genuinely skipped 5.1.1, 5.1.2 and 5.1.5. Running 5.1.1 then found C-1.
> - Second block: the work was done but recorded as `###` headings rather than the canonical bullet
>   form the gate reads. I guessed at a format instead of reading the hook's patterns.
>
> **This is the sprint's clearest lesson: the automated review found a CRITICAL defect that my own
> verification, mutation testing included, did not.** Had the gate not blocked, Harold would have
> validated a build where F220 was unfixed.
>
> Also found: the hook suite had a pre-existing failure (F225) unrelated to my changes, which I
> verified by restoring the original hook rather than assuming.

---

### 10. Risk Management
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good.**
>
> The riskiest change -- altering the return semantics of four widely-used adapter methods -- was
> handled correctly: the review traced every caller before and after, and found the one genuine
> behaviour change was in the intended direction.
>
> **Risk I under-weighted**: I fixed four batch methods when the bug report named two, which was
> right, but I did not initially notice that `disconnect()` left `_imapClient` non-null on the
> failure path (M-8). That bounded the entire F212 fix to "never connected" while the failure mode
> users actually hit is "connection died". The fix was correct and nearly useless until the review
> found it.

---

### 11. Next Sprint Readiness
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Very Good.**
>
> Sprint 71 has a clear, evidence-backed slate: F224 (cancel affordances, with the cooperative-
> cancellation design problem already identified), F217's implementation under Harold's decided
> option 1, F225 and F226 (tooling), F222, and F219 AC-1 validation once a Play build exists.
>
> F217 in particular is ready to implement rather than ready to investigate: the diagnosis is done,
> the Samsung hypothesis is falsified by direct observation, and the remedy is chosen.

---

### 12. Architecture Maintenance
> **Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good
> **Claude Code Development Team**:
>
> **Rating: Good.**
>
> ADR-0042 was applied correctly in the end, but only after the review caught me declaring parity
> while delivering divergence. The F220 handler originally ran on every platform with a comment
> asserting "there is nothing platform-specific to declare" -- while `paused` means "your sockets are
> gone" on Android and merely "your window is not visible" on Windows. It was killing healthy Windows
> scans.
>
> The corrected version is a narrow declared exception with a test seam and both branches covered,
> which is what the ADR requires. The lesson: **asserting parity is a claim that needs verification
> exactly as much as asserting a difference does.** A parity declaration is not the safe default.

---

### 13. Minor Function Updates for the Next Sprint Plan
> **Product Owner / Scrum Master / Lead Developer (Harold)**: none
> **Claude Code Development Team**:
>
> - **F219 AC-1 validation** -- carried to Sprint 71 per Harold; requires a Play-signed build on the
>   S24+. Not a code change, but it must appear in the plan or it will be forgotten.
> - **Re-verify F227 on the Play build** at the same time -- the emulator proved the redirect reaches
>   the app, but the full sign-in round trip against the real OAuth client is untested.

---

### 14. Function Updates for the Future Backlog
> **Product Owner / Scrum Master / Lead Developer (Harold)**: none
> **Claude Code Development Team**:
>
> Already filed this sprint, no new items beyond them:
> - **F224** -- user-facing scan cancel (cooperative cancellation design required first)
> - **F225** -- `verify-closeout-complete` fails its own allow-case
> - **F226** -- WinWright back-to-back sweep flakiness
> - **F227** -- FIXED this sprint, kept for the record

---

## Improvement Decisions (Step 6)

Harold approved all five proposals with "1-5 now" (2026-09-19). All were applied in commit
`ca59cc7` before the PR went ready.

| # | Improvement | Decision | Where applied |
|---|---|---|---|
| IMP-1 | Every new test guarding a bug fix carries a one-line "what would this test NOT catch?" | **Apply now** | `CLAUDE.md` |
| IMP-2 | When a doc comment asserts a MECHANISM, verify it in the same turn | **Apply now** | `CLAUDE.md` |
| IMP-3 | Run the hook suite after ANY change to output conventions, not only hook edits | **Apply now** | `CLAUDE.md` |
| IMP-4 | When a HOOK enforces a format, the hook is authoritative, not the prose doc | **Apply now** | `CLAUDE.md` |
| IMP-5 | An ADR-0042 PARITY claim needs the same verification as an exception | **Apply now** | `CLAUDE.md` |

**Not proposed, deliberately**: anything that budgets for rework. Harold rejected that class in
Sprint 69 -- *"Eliminating waste is much more important than improving estimates to account for
it."* All five target causes rather than accommodating the cost.

---

## Post-retrospective work (same sprint, after Step 7)

The PR reviews ran after the retrospective and produced more findings than the retrospective did:

- **Copilot, 1 HIGH**: failed keys were never cleared after a later success. This was a regression
  introduced by the fix for H-2 from the earlier review -- one fix creating the next defect.
- **Claude full-PR review, 2 CRITICAL**: the SEC-9 manifest gate had become a prose-matching no-op
  after F227 removed the string it searched for, and the F220 lifecycle test was hollow (deleting
  the production fix left all six tests green).
- **4 IMPORTANT**: hook false positives that blocked correct work, a Gate 1c regression that
  blocked legitimate Phase 7/8 questions, and two stale doc/comment claims contradicting the code.
- **F225 fixed**, and its real root cause was NOT the one guessed when filing it: a test fixture
  with a hardcoded date had aged past a 30-day staleness check.

All addressed in `b08420e`; nothing deferred.
