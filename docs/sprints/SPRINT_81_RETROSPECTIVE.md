# Sprint 81 Retrospective

**Sprint**: 81 -- iPhone start (F67a Apple prerequisites, F304 iOS build pipeline, F67b iOS project), IMAP no-UID
constant (F302), Android diagnostics field by field (F303), missing Gmail label and per-folder history cursor (F259),
Gmail 7-day sign-in made visible (F301), No Rule reason chips and Create rule (F271), notifications with no scan
(F278), WinWright sweep cost (F300), background task that stays open (IMP-2b) (0.22.0)
**PR**: #507 (feature/20261023_Sprint_81 -> develop), DRAFT until 7.7.5
**Date**: 2026-10-26
**Manual Validation**: complete (Harold: "Manual Validation complete"; MV-1 PASS with direction -> F306/F307; MV-2
moved to Sprint 82; MV-3 "OK")

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim below,
counting for all three roles). The Claude Code Development Team lines are Claude's own. From this sprint the 7.7.1
final code reviews ran BEFORE the retrospective (Sprint 80 Q3 = 1), so their findings are grouped by class below and
every recurring class has a prevention proposal.

## 7.7.1 findings by class

Reviews: Copilot "No open issues" (0 comments). code-reviewer 0 High / 1 Medium / 8 Low (+ 2 potential misses).
silent-failure-hunter 0 Critical / 0 High / 6 Medium / 7 Low. Three pairs were the same issue (CR L-1 = SF M-1,
CR L-8 = SF M-3, CR L-3 = SF L-3). Fixed: f80ede27, 3f3a2a7a, 7199bba8. "Recurring" = two or more this sprint, or
in an earlier sprint's 7.7.1 line.

- **A. A failure or skip the user cannot see** (recurring: 6 this sprint; Sprint 79 H-2, Sprint 80 most of hunter's
  16): SF M-2 missing Gmail label only in the opt-in log; SF M-3 / CR L-8 rules read failure; SF M-5 migration count;
  CR L-7 no-UID messages not counted; SF L-6b fallback export folder; SF L-7 failed sign-in post. -> IMP-1.
- **B. Text that promises what the code does not do** (recurring: 4; Sprint 80 Copilot doc comment): the "Blocked
  TLD" chip text (the chip could fire only for a disabled rule); the Task 6 card title "visible" met by an opt-in log;
  a doc comment asserting Gmail's label case rule (unverified); CR L-2 comment missing the Windows test path. -> IMP-2.
- **C. A new throw placed outside its handler** (recurring: 2; Sprint 75 IMP-3, Sprint 79 H-1): CR L-1 = SF M-1, the
  F259 label check ran before the 403 scope handler, so a scope failure read as a folder error; SF L-5 the expected
  exception logged at error level by the outer catch. -> IMP-3.
- **D. A sibling the shared helper or gate missed** (recurring: 4; Sprint 73 rule): SF L-1 and L-2 batch fallbacks
  lost the no-UID reason; `ProviderEmailIdentifier.imapUid` parsed without the F302 helper; the F302 policy regex
  did not cover the name `identifierValue`. -> IMP-4.
- **E. A test that does not test** (recurring: 3): CR L-4 a stale test for a removed field; CR L-5 a version
  assertion unlike its siblings; CR L-6 a requested test that could not fail (Not applicable, Harold Q4 = 1). -> IMP-5.
- **F. Log volume** (single): CR L-3 = SF L-3, one line per no-UID message. Root cause: a per-message log inside a
  loop with no bound. Fixed with a 10-minute window per folder. No improvement proposed.
- **G. Pre-existing** (single): SF M-6, the Gmail history cursor saved before evaluation -> F314, Sprint 82.
- **Review coverage gap**: the code-reviewer prompt named top-level `scripts/`, so `mobile-app/scripts/
  build-with-secrets.ps1` (Task 11) was reviewed by Copilot only. -> IMP-6.

## Sprint 81 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective for the code cards: Tasks 0 and 3-11 are done, mutation-verified, and
  the pre-MV build reached handover within about a day because five Sonnet agents ran in parallel. Not finished:
  Task 1 AC-2/AC-3 and Task 2 signing and TestFlight wait on Harold's Apple enrollment (stopping criterion 2); on
  2026-10-26 creating the Apple Account failed and is retried 2026-10-27. Less efficient: the 7.7.1 decisions took an
  extra round, because four of my questions were too thin to answer (see 6).

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong at unit and widget level. The suite went from 3,204 to 3,283 passed, 0
  failed, analyzer clean. Every new test was mutation-verified (Tasks 3-8: 9 + 26 + 7 + 7 + 17 mutants; 7.7.1 fixes:
  7 + 4 + 3), and one 7.7.1 mutant first SURVIVED, which tightened its test. Gaps: (a) class E above: three tests
  that could not fail; (b) the default WinWright scripts do not open No Rule Review, so the F271 screen was rehearsed
  by widget tests only (Sprint 82 carry-in); (c) the live DEV window was not rehearsed because the PC was locked.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Planned 745-1,365 minutes; the 12 task rows total about 435. Every row is inside
  or under its band except Task 11 (~35 against 15-30, the cause was reproduced and fixed). Large unders (Task 3,
  Task 5) came from parallel agents and the iOS template. Only Tasks 9 and 11 were recorded at completion; the other
  ten rows were rebuilt from commit times, which CODING_VELOCITY.md Rule 4 does not intend. The 7.7.1 fix time
  (three commits) is not yet in a row; it goes in at close-out, from commit times.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. Two misses: (a) the F271 card designed a "Blocked TLD" chip without asking
  whether a No Rule email can come from a blocked TLD; an enabled TLD rule blocks it first (DEV: 443 TLD rules, all
  enabled). My own MV finding on 2026-10-24 wrote that fact down and I did not connect it to the chip; the review did.
  (b) The Task 6 title promised "visible" and the card's ACs accepted a diagnostic log line, which the user does not
  see by default.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Cheapest-first held. Sonnet agents did Tasks 3, 4 + 6, 5, 7 (code) and 8; Opus
  did the ADR-0029 record, Tasks 0, 1, 9, 11 (single-session note), the merges and every verification re-run. No
  escalations. One 7.7.1 fix (the Q2 "Folder not found" chip) ran as a background fork while I answered Harold.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Decisions were numbered and re-presented. Misses: (a) Q1, Q4 and Q6 of the 7.7.1
  decisions gave 2-3 options and one line of context; Harold: *"need more detail and more options"*, and for Q4 *"would
  seem like there are more than the 2 options provided"*. The second version gave the evidence (DEV counts), what the
  user sees today, and 4-5 options each. (b) I first overstated the forged Authentication-Results risk (F312), then
  corrected it. (c) I briefly told myself the effort actuals were missing; a correct search showed them, so nothing
  wrong reached Harold, but the first search was the wrong shape.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. The parity statement was quoted in the plan and every card has a Parity
  line. Harold's MV-1 direction (one suggested rule in the pop-up, F306) and his F312 count-first rule were
  unambiguous. One open question I could not settle from the card: whether "visible" meant on screen (it did).

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0029 amended (Phase 1 made visible). `IOS_SETUP.md` Parts A-D with each
  claim marked VERIFIED or UNVERIFIED; Part A's fee and Individual requirements verified on Apple's page 2026-10-26.
  CHANGELOG has a line per fix. The master plan gained F305-F317. Gaps: class B above (one doc comment asserted an
  unverified Gmail rule), and the F302 known limit (old pre-v14 rows may hold a sequence number) still needs its line
  in the Task 4 record.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) The Sprint 75 IMP-3 catch walk exists and was not run for the F259 label
  check (class C). (b) The 7.7.1 toolkit prompt named directories, not the changed file list (coverage gap above).
  (c) The new Phase 7 order worked: reviews before the retrospective let this file group the findings by class.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. Three migrations (v14-v16) each ran on a dev-DB copy first, with a backup
  before the first 0.22.0 launch. Builds were serialized. Open risks, each with what settles it: (a) iOS signing is
  unproven until enrollment (Task 2); (b) MV-2, the Fold diagnostics line, needs 0.22.0 on the Fold (Sprint 82);
  (c) how often an IMAP server sends a message with no UID is unknown (F315 counts it); (d) the Gmail history cursor
  can skip mail after a cancelled scan (F314).

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready. Sprint 82 candidates already carded: F306 (suggested rule, with the TLD
  ideas), F312 (count first), F314 (Gmail cursor, design first), F315 (no-UID count), F317 (agent restart safety),
  MV-2 Fold diagnostics, WinWright coverage of No Rule Review, and the iOS Task 1/2 remainder once Apple approves.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sound. iOS answers come from `PlatformCapabilities` (ADR-0049) with the ADR-0050
  exceptions; no bare platform checks. Every IMAP id parse goes through `hasValidImapUid` / `parseImapUid`, enforced
  by a policy test. The Gmail cursor is per account and folder. The removed `blocked_tld` code is documented as never
  to be reused, because old rows may hold it.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: MV-2 Fold `new-mail-diagnostics` line (Harold: *"bring this back up in the next
  sprint"*); WinWright coverage of No Rule Review; iOS Task 1 AC-2/AC-3 (IOS_SETUP Parts A-D, starting with Part A)
  and Task 2 signing/TestFlight (Harold 2026-10-26: *"move to next sprint"*).

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: Already added with numbers: F314 (Gmail cursor), F315 (no-UID count), F316
  (fallback export folder visible), F317 (agent work across usage limits, from Harold's prompt), and the TLD ideas on
  F306 / F311. Nothing further.

**Questions to be discussed before ending the sprint (Harold)**: none

## Completeness Validation (Phase 7.3/7.4 exit gate)

- 14 of 14 categories present; each has the combined PO/SM/Lead line (3 roles) and the Claude line (4th role).
- No placeholder text. Harold's words recorded verbatim.
- Category 13: three carry-ins. Category 14: F314-F317 already in the master plan.

## Improvement Recommendations (proposed -- awaiting Harold's decision)

### High Priority (Implement Now)

1. **IMP-1 "The user sees it" means a screen, never the diagnostic log** (class A)
   - **Root Cause**: six findings were failures or skips written only to the console or the opt-in diagnostic log.
     CLAUDE.md IMP-2 (Sprint 72) requires a user-facing feature to name its control and screen; it says nothing about
     a FAILURE the user should know about, so a log line read as "visible".
   - **Proposed Solution (extending Sprint 72 IMP-2 and the 5.1.2 F-PRECHECK silent-failure class)**: (1.1) CLAUDE.md
     IMP-2 gains one sentence: a card or fix that makes a failure "visible" names the screen and the exact text; the
     diagnostic log is evidence for Claude, not visibility for the user. (1.2) The 5.1.2 F-PRECHECK silent-failure
     class adds one question per catch or skip: "where does the USER learn of this?" An answer of "the log" is a
     finding unless the card says the user need not know.
   - **Effort**: about 15 minutes.
   - **Impact**: class A is found at 5.1.2, before Manual Validation, not at 7.7.1.
   - **Files to Update**: `CLAUDE.md`, `docs/SPRINT_EXECUTION_WORKFLOW.md` (5.1.2), `docs/SPRINT_CHECKLIST.md`.

2. **IMP-2 A new signal, chip or flag states the input that makes it fire, checked on DEV data** (class B and the
   chip)
   - **Root Cause**: the Blocked TLD chip could fire only for a disabled rule, and its text implied an active rule.
     The data to see this (443 enabled TLD rules; my own MV note) existed before the review.
   - **Proposed Solution (extending the F271-style card and the Sprint 74 IMP-2 user-visible text rule)**: a card that
     adds a signal, chip, badge or warning has an AC: "Fires when <input>; on DEV data (rules table or content history,
     ADR-0047) it fires on N of M rows." Zero is allowed only with a reason. Its user text is checked against that
     input in the same turn.
   - **Effort**: about 10 minutes (SPRINT_PLANNING.md card template line).
   - **Impact**: a signal that cannot fire, or says something untrue, is found at planning.
   - **Files to Update**: `docs/SPRINT_PLANNING.md` (card template), `CLAUDE.md` (Sprint 74 IMP-2 bullet).

3. **IMP-3 The catch walk is a card line, not only a CLAUDE.md rule** (class C)
   - **Root Cause**: Sprint 75 IMP-3 requires listing every catch between a new throw and its handler. Task 6 added
     an early throw and the card had no place for that list, so the walk did not happen.
   - **Proposed Solution (extending the existing "Callers of any guard being changed" card line)**: the card
     template's line becomes "Callers of any guard changed, and catches between any new throw and its handler: <list,
     or none>". The delegation checklist copies it into the agent prompt.
   - **Effort**: about 10 minutes.
   - **Impact**: the three catch-order findings of Sprints 75, 79 and 81 had this one cause.
   - **Files to Update**: `docs/SPRINT_PLANNING.md` (card template and delegation checklist).

### Medium Priority (Next Sprint)

4. **IMP-4 The F302 policy gate matches the operation, not a list of names** (class D)
   - **Root Cause**: the gate matched known variable names; `identifierValue` was not on the list, so a raw parse
     passed.
   - **Proposed Solution (extending `f302_imap_uid_helper_test.dart`)**: fail on every `int.tryParse(` / `int.parse(`
     in `lib/` whose argument reads a message id or identifier, with an allowlist of reviewed non-UID parses. A new
     name cannot slip past it. Mutation-verify with a probe file.
   - **Effort**: about 30-45 minutes.
   - **Impact**: the next UID consumer cannot bypass the helper by being named differently.
   - **Files to Update**: `mobile-app/test/policy/f302_imap_uid_helper_test.dart`.

5. **IMP-5 A reviewer-requested or renamed-value test is mutation-checked before it is written** (class E)
   - **Root Cause**: L-4 and L-5 were stale after a field and version change; L-6 asked for a test no mutation could
     make fail.
   - **Proposed Solution (extending the existing mutation rule)**: before writing a test a reviewer asked for, name
     the mutation it would catch; if none exists, answer Not applicable with that reason. When a value is renamed or
     removed, grep `test/` for the old literal in the same commit.
   - **Effort**: about 10 minutes (TESTING_STRATEGY.md).
   - **Impact**: no tests that only look like coverage.
   - **Files to Update**: `docs/TESTING_STRATEGY.md`.

6. **IMP-6 The 7.7.1 toolkit prompt lists the changed files** (coverage gap)
   - **Root Cause**: the prompt named directories, and `mobile-app/scripts/` was not one of them.
   - **Proposed Solution (extending the 7.7.1 prompt in SPRINT_EXECUTION_WORKFLOW.md)**: the prompt includes the
     output of `git diff --name-only origin/develop...HEAD`, minus `0*` files and `archive/`, and asks the reviewer to
     confirm each file was read.
   - **Effort**: about 10 minutes.
   - **Impact**: no changed file is reviewed by Copilot alone.
   - **Files to Update**: `docs/SPRINT_EXECUTION_WORKFLOW.md` (7.7.1).

7. **IMP-7 A finding's decision question carries its evidence and every practical option** (Communication 6a)
   - **Root Cause**: Sprint 80 IMP-3 asks for 1-3 lines on what is decided; for review findings that was too thin.
   - **Proposed Solution (extending Sprint 80 IMP-3 in CLAUDE.md)**: a decision question about a finding states what
     the user sees today, the evidence (a count or file:line), and every practical option, including a partial fix,
     count-first, and backlog.
   - **Effort**: about 5 minutes.
   - **Impact**: one round per decision instead of two.
   - **Files to Update**: `CLAUDE.md`.

### Low Priority (Future)

None.

## Improvement Decisions

Harold, 2026-10-26, verbatim: *"do now 1, 2, 3, 4, 5, 7 - 6 backlog for next sprint"*

- **IMP-1 "The user sees it" means a screen** -- APPLIED. `CLAUDE.md` (sub-bullet under Sprint 72 IMP-2);
  `SPRINT_EXECUTION_WORKFLOW.md` 5.1.2 class 6 and the `SPRINT_CHECKLIST.md` 5.1.2 line ask "where does the USER
  learn of this?" for every catch and skip; the `SPRINT_PLANNING.md` "User-reachable control" note covers failures.
- **IMP-2 A signal states what makes it fire, counted on DEV data** -- APPLIED. `SPRINT_PLANNING.md` card template
  gains the "Signal fires on" line; `CLAUDE.md` sub-bullet under Sprint 74 IMP-2.
- **IMP-3 The catch walk is a card line** -- APPLIED. `SPRINT_PLANNING.md`: a "Catches between any NEW throw ..." line
  under "Callers of any guard being changed", and delegation checklist item 7.
- **IMP-4 The F302 gate matches the operation** -- APPLIED. `f302_imap_uid_helper_test.dart` compares every
  `int.parse` / `int.tryParse` in `lib/` (calls and tear-offs) with a reviewed list keyed by exact call text and count
  (30 sites in 16 files plus the helper, each file with a reason), so a new parse fails whatever its argument is
  named, including an id copied into a local first (a gap the old header named). The improvement review found the
  first cut (a per-file count) passed a swap of one call for another, and missed tear-offs; both fixed (M-2, L-1).
  Probes: direct, renamed (`identifierValue`), via a local, tear-off, an extra call, and a swap -- all caught.
  Mutations IMP4-M1 (raw `int.tryParse(identifierValue)`) and IMP4-M2 (an extra parse in `email_scanner.dart`)
  KILLED.
- **IMP-5 A test must be able to fail** -- APPLIED. `TESTING_STRATEGY.md` section "A test must be able to fail".
- **IMP-6 The toolkit prompt lists the changed files** -- BACKLOG, Sprint 82: F318.
- **IMP-7 A finding's question carries evidence and every option** -- APPLIED. `CLAUDE.md` sub-bullet under the
  numbered-list rule.
