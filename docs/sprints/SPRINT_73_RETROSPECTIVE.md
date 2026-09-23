# Sprint 73 Retrospective

**Sprint**: 73  
**Dates**: 2026-09-22 to 2026-09-23  
**Version**: 0.15.3+6 -> 0.16.0+7  
**Branch**: `feature/20260922_Sprint_73`  
**PR**: #435 (draft, -> `develop`)  
**Suite**: 2,233 -> 2,305, analyzer clean, WinWright 2/2

## Sprint 73 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **Efficient in output, and the efficiency came from measuring instead of arguing.** Six of eight tasks delivered, suite 2,233 -> 2,305. Two places where a measurement replaced a debate and saved the larger cost: F229's probe proved options 1-3 were arithmetic failures before any of them was built, and Task 4's R-1 found the teardown already existed, collapsing a token-threading design into one throw. **The waste was elsewhere**: two CRITICAL defects I introduced and the reviews caught, and a WinWright call I got wrong twice. None of that was slow work -- it was confident work that was wrong, which is more expensive because it reaches a commit before anyone checks it.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **This is the category the sprint failed, and it failed the same way twice in eight hours.** F234 and F224 both shipped INERT with fully green suites -- the preview could never report a non-zero count, and cancel was swallowed on every real IMAP account. Both were found by the Phase 5.1 reviews, not by me, and both had the identical cause: I verified with SOURCE-TEXT assertions instead of behavior. F234 is worse than a repeat, because I closed its first mutation gap with a test literally named "THE MUTATION GAP" that greps for a string which was still present while the bug moved 30 lines upstream. **A source gate proves a symbol EXISTS; it can never prove a branch is TAKEN.** The recovery is the useful part: both decisions are now extracted as pure seams (`classifyForReProcess`, `throwIfCancelled`), the review's own dead-coding mutation now turns the suite red, and F229 was built with a behavior test from the start and verified on the running app.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **Accurate totals, and two of the three estimates were right for the wrong reasons.** Task 4 came in UNDER (150-300m estimated, ~120m actual) because R-1 found the design already paid for -- the estimate priced work the existing `finally` made unnecessary. F229 landed inside 60-120m at ~95m while my stated basis was false: I costed "one attachment point in the shared Scaffold wrapper" when there is no shared wrapper and the global seam was the one F209 rejected. **An estimate that is right by coincidence teaches nothing**, so both are recorded in CODING_VELOCITY.md with the reasoning error rather than just the number.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **The cards were strong enough that following them falsified three of their own premises** -- which is what a good card does. R-1 removed the Class-1 escalation F224 had reserved; R-2 disproved all three causes the F207 card proposed; R-5's suspected F232-B overlap resolved NEGATIVE. F229's audit-first likewise proved that Harold's own suggested trade (remove an icon) buys 43px against a 120px need. The one planning gap was mine, not the cards': F234's audit said the data "already exists", I recorded that as half-right, and the half I got wrong was the half that made the feature inert.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No issues -- expectations met. Fable/Opus throughout, which the cards justified per task (R-1 an unsolved design problem, F229 a measured design decision across 22 screens). Worth noting for honesty: a cheaper tier would not have avoided this sprint's two CRITICALs, because they were a verification-discipline failure rather than a reasoning one -- the tests I wrote were the problem, and they were easy tests.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **Harold's questions repeatedly beat my analysis, and the pattern is worth naming.** "Do the WinWright failures occur when the laptop is locked?" produced a documented root cause after I had written two wrong explanations. "Background scan is read-only so the other 6 are from prior block rules" corrected a count I had attributed to the wrong session. In both cases he asked about CONTEXT I had not thought to establish, while I was reasoning from artifacts. My own communication failure: I twice wrote conclusions more confidently than the evidence supported, and the confidence is what made them costly.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No issues -- expectations met. The approval amendments were unambiguous and load-bearing: MINOR bump, F234 previews BOTH rule kinds, F229 may remove the Select Account icon. That last one mattered precisely because the measurement said not to spend it, and having the permission explicit made recommending against it a clean decision rather than an assumption.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **Documentation was where the sprint's real durable value landed.** The WinWright `SetCursorPos`-means-locked root cause went into the RUNNER'S OWN HEADER, where the next person hitting it will look, rather than only into a sprint plan nobody greps. Every correction is recorded with its reasoning error attached, not silently fixed. One thing I would flag: the sprint plan has grown large enough that finding a specific determination in it takes a search, which is a cost the next sprint inherits.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **The gates worked; I did not always work the gates.** The F193 evidence gate needed its 5.1.2 marker reshaped because my label wrapped and the colon never landed on the marker line -- caught by verifying against the hook's own regex (IMP-4) rather than the prose doc. The mutation-lock and one-file dry-run disciplines both paid: the F229 wiring script was genuinely broken and would have committed 22 corrupted files. **The process failure was that Phase 5.1 had to catch what Phase 4 should have** -- two inert features reached review because my own verification step was satisfied by text.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **Mixed, and the miss is instructive.** Managed well: F235's R-1 gate removed the Play policy risk entirely before any code; F229's measurement removed the overflow risk before implementation; the ADR-0042 exception on F207 was declared and BOTH branches tested. Missed: I fixed ONE instance of the cancel-swallow and declared the class closed, when an identical swallow sat one layer below in the adapter -- on the only path real accounts use. **Fixing an instance is not fixing a class**, and the grep that would have found the sibling took seconds.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Ready, with the open items explicitly parked rather than quietly dropped. Seven review findings are recorded as carry-forward, the sharpest being that F207's Android suppression may rest on a false mechanism claim if the WorkManager scan runs in its own isolate -- I could not settle that from source and said so rather than recording a determination I cannot support. Tasks 2, 7 and MV step 6 need the S24+.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **The best architectural decision this sprint was declining to invent anything.** F229 looked like it wanted a global wrapper; `SystemInsetWrapper` had solved that exact class in Sprint 69 and documented at length why per-screen is load-bearing, so F229 mirrors it including the exempt-needs-a-reason rule. F224 extended `ScanCoordinator` rather than adding a parallel cancellation path, and reused the existing `interrupted` status rather than adding an enum value that would have changed a stored value's meaning. Two Class-1 escalations were correctly avoided on evidence, not convenience.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Three, all from the Phase 5.1 reviews and all small: **I-2** scope `requestCancel` by `scanType` so it cannot flag a `reprocess` lease (inert today, but the user is told "Stopping the scan" when nothing will stop); **I-3** add `mounted` guards to the two cancel handlers before either gains an `await`; **MEDIUM** replace first-occurrence `indexOf` ordering assertions with `allMatches`/`lastIndexOf`, since several verify only the first of two matching pairs.

### 14. Function Updates for the Future Backlog

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Four: **(a)** settle the WorkManager isolate question on-device and correct the two mechanism comments either way -- this is a correctness dependency, not a stale comment; **(b)** decide and document the phase-6b cancellation boundary, currently the longest and ONLY destructive phase with no cancel check; **(c)** unit-test `cancelScan()` for AC-4 and `markScanCancelled()` for its status string and where-clause, both currently at zero coverage; **(d)** make the WinWright runner DETECT a locked workstation in preflight (`OpenInputDesktop` vs current desktop) and abort with a clear message instead of reporting script failures that read as UI regressions.


---

## Improvement Recommendations -- ALL SIX APPROVED AND APPLIED (Phase 7.5/7.6)

**Harold's steering, 2026-09-23**: *"For all IMP-* -- ensure that the solution is trying to prevent
the problem first, then implement additional controls if absolutely necessary. all now"*

**That reframing exposed a weakness in what I first proposed.** Four of my six suggestions were
"add a rule to CLAUDE.md" -- which is detection after the mistake, not prevention. And the evidence
against that approach was already in hand: **CLAUDE.md is ~790 lines, and BOTH of this sprint's
CRITICALs happened DESPITE rules that already covered the ground.** Sprint 70's IMP-1 requires
every bug-fix test to carry a "what would this test NOT catch?" line, and
`feedback_source_gates_verify_shape` says a source gate must be paired with a behaviour test.
**F234 and F224 both carried that paragraph. Both were still inert.** A rule that was followed and
did not help is not made effective by restating it.

So the revised implementations, in Harold's order of preference:

### PREVENTION -- mechanical, fails the build or the run

**IMP-1: `test/policy/behavioral_coverage_test.dart`** -- a policy gate, not a rule.

Measures one mechanical property per test file: the ratio of assertions made against source
*strings* to all assertions. Over 0.70, the file must carry a `SOURCE-TEXT VERIFIED:` declaration
naming what WOULD settle the behaviour.

- **Threshold grounded in a survey of the real corpus, not guessed**: of 21 files that read `.dart`
  source, seven sit at 0.73+ (near-total source verification) and cluster in the last two sprints'
  feature tests -- exactly where both CRITICALs lived. Files that pair source checks with real
  behavioural tests land well below: `f234_readonly_preview` is at 0.46 *after* its behavioural
  tests were added, and was far higher before. The threshold separates the two populations as they
  actually exist.
- **It does not forbid source-text assertions** -- proving a rethrow precedes a generic catch needs
  a live IMAP connection. It forbids doing so SILENTLY.
- **Caught all seven existing offenders on first run**, including
  `f233_settings_ui_test.dart` at 100% -- which is the Sprint 72 F233 defect that shipped with no
  UI at all. Strong confirmation the measure tracks the real problem.
- **Two mutations verified**: a rubber-stamp declaration (`SOURCE-TEXT VERIFIED: yes`) is rejected
  by name, and a NEW source-only test file is caught at the moment it would be written. That second
  one is the prevention property -- it fires on the next F234, not after it.
- All seven files were **fixed with declarations written for their individual situations**, not
  blanket-stamped. Following the project's own precedent (`ui_string_assertion_shadow_test.dart`,
  Sprint 65 IMP-3), which exists because a gate passed while proving less than it appeared to.

**IMP-6: `run-winwright-tests.ps1` refuses to start on a locked workstation.**

Calls `OpenInputDesktop` in preflight, beside the existing `winwright doctor` check, and aborts
with an actionable message. **A retry is deliberately NOT the fix** -- it only fails slower.
Verified it does not false-positive on an unlocked session (`-DryRun` clean, handle returned).
**The locked branch is unverified by direct test**, because proving it needs the workstation
locked; the API contract is documented and the unlocked branch is confirmed.

### ADDITIONAL CONTROL -- rules, but as EXTENSIONS to rules that already exist

Applied to the existing entries rather than added as new ones, because accumulation is the failure
mode being corrected. CLAUDE.md grew 787 -> 791 lines: three extensions, one new entry.

- **IMP-2** extends *"Don't fix ONE symptom of a skipped process step"* from PROCESS steps to CODE
  patterns -- the F224 adapter swallow was structurally identical to the one I had just fixed, one
  layer below, on the only path real accounts use.
- **IMP-3** extends the Sprint 70 mutation rule: **re-run the mutation after the FIX, not only
  after writing the test.** The F234 mutation SURVIVED my corrected, fully-tested pure function,
  because the bug was at its call site. "Correct abstraction, wrong wiring" had no name before.
- **IMP-5** extends the screenshot rule: **a COUNT is not a claim about WHEN it arose.** Take the
  baseline first -- the 09:03 row was in the same screenshot set and settles the "7 deleted"
  question by subtraction.
- **IMP-4** is the one genuinely new entry, because nothing covered it: **"transient", "flaky" and
  "intermittent" are not causes.** It is paired with IMP-6's mechanical check, so the rule is the
  backstop and the runner is the prevention.

**Verification**: 75/75 hook tests pass. Analyzer clean. Full suite re-run after the changes.

## Sprint 74 carry-ins (Harold, 2026-09-23: "1. and 2. add to sprint 74 Manual Validation")

Three items could not be settled in Sprint 73 because the only evidence that settles them is a run
on the S24+. **The code SHIPPED in all three cases** -- what is carried is the VALIDATION, and the
issues say so explicitly so Sprint 74 does not re-plan an implementation that already exists.

- **MV74-1 (#428)** F235 Doze: scans firing while idle, and surviving a reboot. The reboot case
  matters most -- without `BootReceiver` this is a REGRESSION against WorkManager's persisted work.
- **MV74-2 (#434)** F207's isolate question: the sharpest open item, and a CORRECTNESS dependency
  rather than a stale comment. If the WorkManager scan runs in its own isolate, the coordinator
  reads idle while a scan is live and the fix hides a warning for a LIVE scan.
- **MV74-3 (#422, #433)** F232 mechanism B and F205: both blocked on the same missing thing, and
  the route is already built -- F233's in-app export writes to a directory confirmed reachable over
  MTP, so no adb is needed. **Do not plan a fix until the log exists.**

Recorded in `ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" (the single prioritized list, not
a duplicate tracker) and as a comment on each of the four issues.
