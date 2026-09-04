# Sprint 64 Retrospective

**Sprint**: 64 (2026-08-27 to 2026-09-03)
**Branch**: `feature/20260827_Sprint_64`
**PR**: #378
**Scope**: GP-16 (+GP-5 folded), F186, F187, F188, SEC-9, GP-2, GP-9, GP-8, GP-3, SEC-4 -- 11 items, one sprint (Harold's option 1, Group B release-build chain kept intact)

**Roles**: Harold wears Product Owner / Scrum Master / Lead Developer and provided combined
feedback per category (his stated format). Claude Code Development Team is the 4th role.

**Completeness gate**: 14 categories x 4 roles, all addressed. Harold's words recorded
verbatim, not paraphrased.

---

## 1. Effective while as Efficient as Reasonably Possible

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: All 11 scoped items shipped. The single-sprint choice for
the Group B release chain was vindicated: SEC-9, GP-2, GP-9, GP-8, GP-3 and SEC-4 all converge
on one signed minified artifact, and every one of them was proven against that same artifact
rather than against a convenient debug build. Two efficiency defects are worth naming honestly.
First, background command output was trimmed on read twice before the full-capture rule was
re-followed, each time hiding the actual failure detail and costing a re-run -- this is the
SAME defect class as Sprint 59 IMP-2, which means the memory entry did not survive contact
with a long sprint. Second, the emulator's stale quickboot snapshot silently reverted the
installed build three separate times, and I did not diagnose the snapshot as the cause until
the third occurrence; Harold tested against the wrong build once as a direct result.

## 2. Testing Approach

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Mutation verification carried this sprint. Four separate
times a test was only trusted after the thing it guards was deliberately broken and confirmed
red: F188's warning assertion (an agent's mutation claim did not survive my re-run), F186's
space escaping (2 red), the duplicate-check column routing (3 red), and the Dart-side space
normalization (2 red). The Sprint 63 lesson that a source-text gate proves a symbol exists but
not that it works was directly responsible for catching the SEC-4 defect class. The honest
gap: policy gates are static-text assertions, and SEC-4 proved a config file can pass every
static gate and still crash the app at runtime. Only launching a build that carries the file
exercises the runtime parser. The same is true of F186's two MV findings -- 36 widget tests
and 4 unit tests all passed on a feature whose UI displayed the wrong string, because nothing
asserted the display value.

## 3. Effort Accuracy

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: F186 was the outlier at ~340m against a 90-150m estimate,
and the overage was almost entirely a pre-existing FakeAsync/DB widget-test hazard rather than
the feature. The two MV fixes added ~80m more, so F186 finished at roughly 3x its estimate.
That is a real miss, but the cause is diagnostic, not scoping: the estimate assumed a healthy
test harness on that screen. Everything else landed close. The verify-only tasks (GP-8, GP-3)
were faster than estimated because the answers were already true in the codebase -- targetSdk
36 was already set, and the permission excess was three dead transitive entries rather than a
design problem.

## 4. Planning Quality

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The augmented card template earned its keep on the release
chain. GP-2's card was written proposing a decision that ADR-0027 had already Accepted; the
card was corrected to execute the existing ADR instead, which is exactly the check the
template's Deps field exists to force. The plan's pre-declared interactive points (ADR-0027,
F187 set confirmation, GP-5 URL) also worked -- each one arrived as a clean decision rather
than a mid-task interruption. One planning gap: F186's acceptance criteria specified the DB
write shape and the round-trip, but never specified what the user SEES in the rule list. Both
MV findings live in that gap.

## 5. Model Assignments

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Cheapest-first held. Haiku handled F188 and SEC-4's initial
implementation, Sonnet took F186 and SEC-9 and GP-9, and Fable was reserved for the chain-level
work where a wrong call is expensive: the keystore ceremony, the prod DB deletion, and the
runtime diagnosis of SEC-4. The escalation pattern is worth recording: both Haiku-authored
tasks needed a Fable hardening pass, and in both cases the hardening found a real defect
(F188's unasserted mutation claim, SEC-4's runtime-invalid XML). That is the ladder working as
designed, not a mis-assignment, but it means a Haiku task on a security-adjacent surface should
be planned WITH the hardening pass rather than treating it as rework.

## 6. Communication

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Two standing rules were established mid-sprint from Harold's
direct correction, and both were written to memory the same turn: the timestamp footer on
decision-point responses, and the 80-character limit on commands Harold pastes himself. The
second was the more valuable correction because Harold noted it had recurred over 100 times
across 8 months -- terminal line-wrap becomes real newlines on copy, and I had been generating
multi-line commands the whole time without ever connecting the failures. The fix (script file
plus short invoker) is now the default. One communication defect on my side: I reported a
chain build as validation-ready when the AVD had silently reverted it, so a "ready" claim
reached Harold that the device state did not support.

## 7. Requirements Clarity

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Harold's ADR-0042 constraint was restated verbatim in the
scope message and it shaped every task -- each of the four release-chain layers is documented
as an explicit platform exception rather than an undeclared Android-only behavior. The F187
per-database approval discipline was also unambiguous and it paid off directly: the prod
numbers came back 1300 of 1470 against the presented dev figures of 647 of 732, I stopped
rather than proceeding, diagnosed the difference as 368 distinct domains times legacy-import
duplicates, and got explicit approval before deleting. A blanket approval would have made that
stop impossible.

## 8. Documentation

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: ARCHITECTURE.md gained the "Android release-build chain"
section describing all four converging layers, which is the durable artifact of this sprint --
the chain is exactly the kind of knowledge that decays into folklore if it lives only in commit
messages. The SEC-4 config file carries an inline structure note warning that a domain-config
root passes AAPT and crashes at runtime, and the GP-3 manifest comment warns against restoring
double-hyphen punctuation. Both are notes written for the reader 12 months out who will
otherwise repeat the exact defect.

## 9. Process Issues

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Four defects, all recorded with their triggers:
- **XML double-hyphen comment, hit twice.** The SEC-9 agent hit it, I read its lesson, and then
  I repeated it myself in the GP-3 manifest comment. Reading a lesson is not the same as
  internalizing it.
- **Background output trimmed on read, twice.** Same class as Sprint 59 IMP-2.
- **Gradle-vs-test-suite contention.** My gradle dry-runs ran during a full suite and produced
  a flake that looked like a real failure. Serializing fixed it.
- **Emulator snapshot reversion, three times.** The AVD's quickboot snapshot predated the
  sprint and every shutdown failed to overwrite it ("Not saving state: RAM not mapped as
  shared"), so each boot restored an August 25 debug build. This cost Harold one wasted test
  cycle against the wrong build.

## 10. Risk Management

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The two highest-risk actions of the sprint were the prod
database deletion and the keystore ceremony, and both were handled with the right caution:
timestamped backups before deletion, untruncated verification after, and a per-database
approval gate that actually fired. The keystore fingerprint was proven identical on the
keystore, the AAB, and the APK, which is the claim that matters for Play App Signing
enrollment. The signing password's plaintext storage was surfaced as a decision rather than
silently accepted; Harold has now chosen option 2 (leave it plaintext), which is a reasonable
call for a file outside the repo on a single-user machine. The residual risk I would name: the
upload keystore is a single point of failure with no recorded backup location.

## 11. Next Sprint Readiness

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: Sprint 65's runway is clear and sequenced: GP-7, then GP-6,
then GP-10, then the closed-test submission. Play App Signing enrolls at first upload, and the
12-tester 14-day closed-test gate is the long pole, so tester recruitment should start before
the code work rather than after. GP-10's Data Safety form has its input already prepared as the
9-permission list from GP-3.

## 12. Architecture Maintenance

**Product Owner / Scrum Master / Lead Developer (Harold)**: Very Good

**Claude Code Development Team**: The four release-chain layers are documented as ADR-0042
platform exceptions in ARCHITECTURE.md and ADR-0027 gained its IMPLEMENTED note. No
architecture decision was made silently this sprint. The one architectural observation worth
carrying: `source_domain` is doing double duty as both a data field and the UI display value
(`sourceDomain ?? name`), and F186's first MV finding is exactly what happens when a new rule
type does not know that. A field whose name describes its origin but whose real contract is
"what the user sees" is a naming defect waiting to bite the next rule type.

## 13. Minor Function Updates for the Next Sprint Plan

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

**Claude Code Development Team**: None beyond what is already sequenced for Sprint 65.

## 14. Function Updates for the Future Backlog

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

**Claude Code Development Team**: Two candidates, surfaced for Step 5 decision rather than
auto-added: (a) a widget-level assertion that every rule type renders its intended display
value in Manage Rules, which is the test that would have caught F186's first MV finding;
(b) an upload-keystore backup and recovery procedure, since losing it means losing the ability
to update the Play listing.

## Questions to be discussed before ending the sprint

**Product Owner / Scrum Master / Lead Developer (Harold)**: none

---

## Improvement Decisions (Phase 7.6)

**Harold's decision (2026-09-03): "apply all now"**, with one steer on IMP-6 recorded verbatim:
*"for 6: this only needs to be done once per sprint, more of an integration test prior to
manual validation as this kind of test is time and token expensive. Apply the 'effective while
as efficient as reasonably possible' guideline for this implementation."*

| # | Improvement | Type | Decision | Applied |
|---|-------------|------|----------|---------|
| 1 | Fix the AVD's stale quickboot snapshot | tooling | apply now | Removed `default_boot`; set `forceColdBoot = yes` / `forceFastBoot = no` in `pixel34_updated.avd/config.ini` (backup `config.ini.bak_s64`). Root cause was "Not saving state: RAM not mapped as shared" on every shutdown, so each boot restored an Aug 25 debug build. |
| 2 | Display-value assertion for every rule type | tests | apply now | New gate `test/policy/rule_display_value_test.dart` (3 tests). Mutation-verified against the EXACT pre-fix F186 code (`isBody ? null : _sourceDomain` + `sourceDomain = ''`): 2 red, revert clean. |
| 3 | Upload-keystore backup and recovery procedure | docs | apply now | New section in ADR-0027 with the three artifacts to back up, the public SHA-256 fingerprint as the verification value, the restore-verification command, and the total-loss path (Play upload-key reset; the published app survives via Play App Signing). |
| 4 | Strengthen the background-output rule | process | apply now | `feedback_background_logs_unfiltered` memory now records the Sprint 64 recurrence and sharpens the rule: any non-zero exit triggers a full-log grep, never `tail` alone, before forming a hypothesis. |
| 5 | Plan the hardening pass into Haiku security tasks | process | apply now | `feedback_cheapest_first_model` memory extended: a Haiku task on a security-adjacent surface is planned as "Haiku implement + top-tier harden", because both Sprint 64 instances found a real defect. |
| 6 | Runtime launch gate for runtime-only config failures | process | apply now (scoped per Harold) | New Phase 5.1.6 in `SPRINT_EXECUTION_WORKFLOW.md`. Deliberately cheap per Harold's steer: ONE launch per sprint on the final build immediately before Manual Validation, conditional on the sprint touching Android config at all, ~2 minutes, with `N/A -- no Android config touched` as an explicit outcome. |

**Post-improvement verification**: 2,001 tests passing / 15 skipped / 0 failing (+3 from the new
gate). Analyzer clean.

---

## Sprint 64 Outcome Summary

**Delivered**: 11 of 11 scoped items.

- **GP-16 + GP-5**: Play developer account "Kimmey Consulting, Ohio" created and ALL
  verifications cleared same evening; legal docs published at `myemailspamfilter.com/legal`.
- **F186**: Body Phrase manual rule type, plus two Manual Validation fixes (display value,
  space escaping, and the duplicate check that had never worked for body rules).
- **F187**: 647 obsolete URL-shape body rules removed from dev, 1300 from prod, each behind a
  per-database approval with timestamped backups and untruncated verification.
- **F188**: unparseable-condition warning, invalid marker, and audit sweep.
- **Release chain (SEC-9, GP-2, GP-9, GP-8, GP-3, SEC-4)**: client-id injection with release
  loud-fail; signing per ADR-0027 Option B via environment variables; R8 + resource shrink +
  Dart obfuscation at -12.8% APK; targetSdk 36 and 16KB alignment verified; permissions reduced
  to exactly 9; cleartext disabled app-wide.

**Metrics**: 1,998 tests passing / 15 skipped / 0 failing. Analyzer clean.

**Android chain validation**: 6 of 6 PASS on the signed R8-minified 0.13.0 release APK.
The strongest single piece of evidence is item 6: WorkManager resolved
`dev.fluttercommunity.workmanager.BackgroundWorker` by full name on the minified build and
jobscheduler registered the job, proving the one R8 keep rule rather than inferring it.

**Manual Validation decisions**: F186 fix option 1 (fix both findings now, retest) -- retest
PASS. Signing-file password option 2 (leave plaintext) -- no change made.
