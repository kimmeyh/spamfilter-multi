# Sprint 64 Retrospective -- Claude Code Development Team DRAFT

**Author**: Claude (Fable 5.1), Phase 7.3 Step 2. Claude-authored draft for Step 3 use only.
**Never** substituted for Harold's Product Owner / Scrum Master / Lead Developer input.

**Date**: 2026-09-03

---

### 1. Effective while as Efficient as Reasonably Possible

All 11 scoped items shipped. The single-sprint choice for the Group B release chain was
vindicated: SEC-9, GP-2, GP-9, GP-8, GP-3 and SEC-4 all converge on one signed minified
artifact, and every one of them was proven against that same artifact rather than against a
convenient debug build. Two efficiency defects are worth naming honestly. First, background
command output was trimmed on read twice before the full-capture rule was re-followed, each
time hiding the actual failure detail and costing a re-run -- this is the SAME defect class
as Sprint 59 IMP-2, which means the memory entry did not survive contact with a long sprint.
Second, the emulator's stale quickboot snapshot silently reverted the installed build three
separate times, and I did not diagnose the snapshot as the cause until the third occurrence;
Harold tested against the wrong build once as a direct result.

### 2. Testing Approach

Mutation verification carried this sprint. Four separate times a test was only trusted after
the thing it guards was deliberately broken and confirmed red: F188's warning assertion (an
agent's mutation claim did not survive my re-run), F186's space escaping (2 red), the
duplicate-check column routing (3 red), and the Dart-side space normalization (2 red). The
Sprint 63 lesson that a source-text gate proves a symbol exists but not that it works was
directly responsible for catching the SEC-4 defect class. The honest gap: policy gates are
static-text assertions, and SEC-4 proved a config file can pass every static gate and still
crash the app at runtime. Only launching a build that carries the file exercises the runtime
parser. The same is true of F186's two MV findings -- 36 widget tests and 4 unit tests all
passed on a feature whose UI displayed the wrong string, because nothing asserted the
display value.

### 3. Effort Accuracy

F186 was the outlier at ~340m against a 90-150m estimate, and the overage was almost
entirely a pre-existing FakeAsync/DB widget-test hazard rather than the feature. The two MV
fixes added ~80m more, so F186 finished at roughly 3x its estimate. That is a real miss, but
the cause is diagnostic, not scoping: the estimate assumed a healthy test harness on that
screen. Everything else landed close. The verify-only tasks (GP-8, GP-3) were faster than
estimated because the answers were already true in the codebase -- targetSdk 36 was already
set, and the permission excess was three dead transitive entries rather than a design
problem.

### 4. Planning Quality

The augmented card template earned its keep on the release chain. GP-2's card was written
proposing a decision that ADR-0027 had already Accepted; the card was corrected to execute
the existing ADR instead, which is exactly the check the template's Deps field exists to
force. The plan's pre-declared interactive points (ADR-0027, F187 set confirmation, GP-5 URL)
also worked -- each one arrived as a clean decision rather than a mid-task interruption. One
planning gap: F186's acceptance criteria specified the DB write shape and the round-trip, but
never specified what the user SEES in the rule list. Both MV findings live in that gap.

### 5. Model Assignments

Cheapest-first held. Haiku handled F188 and SEC-4's initial implementation, Sonnet took F186
and SEC-9 and GP-9, and Fable was reserved for the chain-level work where a wrong call is
expensive: the keystore ceremony, the prod DB deletion, and the runtime diagnosis of SEC-4.
The escalation pattern is worth recording: both Haiku-authored tasks needed a Fable hardening
pass, and in both cases the hardening found a real defect (F188's unasserted mutation claim,
SEC-4's runtime-invalid XML). That is the ladder working as designed, not a mis-assignment,
but it means a Haiku task on a security-adjacent surface should be planned WITH the hardening
pass rather than treating it as rework.

### 6. Communication

Two standing rules were established mid-sprint from Harold's direct correction, and both were
written to memory the same turn: the timestamp footer on decision-point responses, and the
80-character limit on commands Harold pastes himself. The second was the more valuable
correction because Harold noted it had recurred over 100 times across 8 months -- terminal
line-wrap becomes real newlines on copy, and I had been generating multi-line commands the
whole time without ever connecting the failures. The fix (script file plus short invoker) is
now the default. One communication defect on my side: I reported a chain build as validation-
ready when the AVD had silently reverted it, so a "ready" claim reached Harold that the device
state did not support.

### 7. Requirements Clarity

Harold's ADR-0042 constraint was restated verbatim in the scope message and it shaped every
task -- each of the four release-chain layers is documented as an explicit platform exception
rather than an undeclared Android-only behavior. The F187 per-database approval discipline
was also unambiguous and it paid off directly: the prod numbers came back 1300 of 1470 against
the presented dev figures of 647 of 732, I stopped rather than proceeding, diagnosed the
difference as 368 distinct domains times legacy-import duplicates, and got explicit approval
before deleting. A blanket approval would have made that stop impossible.

### 8. Documentation

ARCHITECTURE.md gained the "Android release-build chain" section describing all four
converging layers, which is the durable artifact of this sprint -- the chain is exactly the
kind of knowledge that decays into folklore if it lives only in commit messages. The SEC-4
config file carries an inline structure note warning that a domain-config root passes AAPT and
crashes at runtime, and the GP-3 manifest comment warns against restoring double-hyphen
punctuation. Both are notes written for the reader 12 months out who will otherwise repeat the
exact defect.

### 9. Process Issues

Four defects, all recorded with their triggers:

- **XML double-hyphen comment, hit twice.** The SEC-9 agent hit it, I read its lesson, and
  then I repeated it myself in the GP-3 manifest comment. Reading a lesson is not the same as
  internalizing it.
- **Background output trimmed on read, twice.** Same class as Sprint 59 IMP-2.
- **Gradle-vs-test-suite contention.** My gradle dry-runs ran during a full suite and produced
  a flake that looked like a real failure. Serializing fixed it.
- **Emulator snapshot reversion, three times.** The AVD's quickboot snapshot predated the
  sprint and every shutdown failed to overwrite it ("Not saving state: RAM not mapped as
  shared"), so each boot restored an August 25 debug build. This cost Harold one wasted test
  cycle against the wrong build.

### 10. Risk Management

The two highest-risk actions of the sprint were the prod database deletion and the keystore
ceremony, and both were handled with the right caution: timestamped backups before deletion,
untruncated verification after, and a per-database approval gate that actually fired. The
keystore fingerprint was proven identical on the keystore, the AAB, and the APK, which is the
claim that matters for Play App Signing enrollment. The signing password's plaintext storage
was surfaced as a decision rather than silently accepted; Harold has now chosen to leave it
plaintext, which is a reasonable call for a file outside the repo on a single-user machine.
The residual risk I would name: the upload keystore is a single point of failure with no
recorded backup location.

### 11. Next Sprint Readiness

Sprint 65's runway is clear and sequenced: GP-7, then GP-6, then GP-10, then the closed-test
submission. Play App Signing enrolls at first upload, and the 12-tester 14-day closed-test gate
is the long pole, so tester recruitment should start before the code work rather than after.
GP-10's Data Safety form has its input already prepared as the 9-permission list from GP-3.

### 12. Architecture Maintenance

The four release-chain layers are documented as ADR-0042 platform exceptions in ARCHITECTURE.md
and ADR-0027 gained its IMPLEMENTED note. No architecture decision was made silently this
sprint. The one architectural observation worth carrying: `source_domain` is doing double duty
as both a data field and the UI display value (`sourceDomain ?? name`), and F186's first MV
finding is exactly what happens when a new rule type does not know that. A field whose name
describes its origin but whose real contract is "what the user sees" is a naming defect waiting
to bite the next rule type.

### 13. Minor Function Updates for the Next Sprint Plan

None beyond what is already sequenced for Sprint 65.

### 14. Function Updates for the Future Backlog

Two candidates, surfaced here for Harold's Step 5 decision rather than auto-added:
- A widget-level assertion that every rule type renders its intended display value in Manage
  Rules, which is the test that would have caught F186's first MV finding.
- An upload-keystore backup and recovery procedure, since losing it means losing the ability to
  update the Play listing.
