# Sprint 76 Retrospective

**Sprint**: 76 -- 0.17.0 field issues and unattended Android background scanning (0.17.1 -> 0.17.6)
**PR**: #455 (feature/20261004_Sprint_76 -> develop)
**Date**: 2026-10-06
**Manual Validation**: complete (Harold: "Manual Validation complete")

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded
verbatim below, counting for all three roles). Claude Code Development Team lines are from
`docs/sprints/drafts/SPRINT_76_RETROSPECTIVE_claude_draft.md`.

## Sprint 76 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective on the goal Harold set -- the Fold now filters unattended (overnight 0.17.4: 95 worker starts, 111/113 completed, 10 spam deletions with nobody opening the app). Less efficient than it could have been: six closed-test builds (0.17.1-0.17.6) in two days, two of them forced by my own misses (the lock that is per-process on Android; the AAB wiped by a later Windows build), and one dart-format pass that rewrote 900 lines and had to be reverted by hand.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong where it mattered: every fix was mutation-checked (M118-M205), and two mutants exposed real limits (M188 proved the lock mattered on Windows; M189 was mis-specified, not a gap). The weak spot was platform semantics: the 4-isolate lock test passed on Windows and the same code failed on Android, because Windows locks are per handle and Android's are per process. A host test cannot prove an OS guarantee -- the Fold log did. First JVM unit test added (CI does not run it).

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: The original plan (Tasks 0-4, 250-530 minutes) was overtaken by scope added at Harold's direction (F251-F253, the MV decisions, four log defects, two follow-up fixes). The added work landed in roughly a day of session time, but estimates were not re-baselined when scope grew, so the plan's numbers no longer describe the sprint.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Tasks 2 and 3 were correctly planned as "diagnose from the phone log first"; F248 made that possible and both causes were named from evidence. Weakest planning moment: the F253 card claimed "the existing incremental cursors already do this", which was only partly true (Scan all = full fetch); it was corrected the same day from the log, before it shipped wrong.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Single interactive session on Opus 5.5 throughout (Sprint 68 IMP-4 case (a)); the two Phase 5.1.1 reviewers ran as Opus sub-agents in parallel and independently found the same HIGH, which is the strongest argument for running both.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Two misses: I reported the AAB as ready when a later Windows build had deleted it (Harold found it at upload), and I rebuilt 0.17.5 without knowing it was already uploaded, so its versionCode was spent. I also had a stop-hook block for ending on an announced next step. Good: decisions went to Harold as numbered lists with concrete evidence (log lines, screenshots), and his answers arrived fast.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Harold's reframing was decisive: "we are ONLY wanting to do the same thing that the email app currently does" collapsed eleven options to one, and "if < 5 minutes can it delay until 5 minutes" turned a skip rule into a better spacing rule. One ambiguity cost a round: export item 3 (DB vs export dedupe) -- resolved by folding into F245.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0044 (notification listener) and ADR-0039 amendments (KEEP, spacing, fetch-nothing = failure) landed with the code; ARCHITECTURE and CHANGELOG were kept current per commit; the plan's Progress section became the field-evidence log. Release notes were re-derived for every build and kept inside the Play 500-character gate.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) Built the AAB, then a Windows build for WinWright -- `flutter clean` wiped the AAB (memory updated: AAB last, re-check in the message that hands it over). (b) Staged with `git add -A` before reading `git status`, sweeping a `0*` file into a version commit with no mention. (c) Ran `dart format` on two large files during a fix -- 900 lines of unrelated churn, reverted by hand. (d) Put an inner `try` at the same indent as its `if` to avoid reformatting -- readable but off-style.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Held the right items as Class 1/2 and surfaced them with evidence (REPLACE vs KEEP, refresh-token renewal, notification listener) rather than deciding them. A risk I did not see: the OS lock semantics differ by platform -- the fix was proven on the wrong platform first.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready: MV76-1 carry-in lists the six Fold checks; 0.17.6 is built and verified; backlog F245 (with the export side), F246, F254 recorded. Open question for Sprint 77: does the native Gmail sign-in still matter now that refresh-token renewal works?

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Two shared rules extracted instead of copied (`safeSenderAlreadyInTarget`; `summarizeBatchFailureReasons`), plus `retryOnFailureFor`; the `reason` on stop is now required. One structural note: `GmailWindowsOAuthHandler` now serves Android too (mobile refresh) -- its name no longer describes it.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**:
  - Deep dive on how to minimize battery usage for Android when set to run Background jobs on “scan when new mail arrives” while maintaining functionality.
    - then add potential items to the backlog in priority order based on your most likely success. Should be written like A/B tests to be tested on the android simulator
    - OK to apply to both Windows and Android - but primarily targeting Android (if necessary, can split solutions between Android and Windows if it will greatly benefit Android but hurt Windows performance - although I don’t think this is likely
  - Since the new Scan when new mail arrives affects all accounts, should it be moved to the General tab?
    - if so, do a deep dive on how the total “Background scanning” settings and help text should be adjusted.
  - Deep dive on tools that can be used with stored email content for Heuristics, ML and GenAI spam identification tools
    - Should result in one or more backlog items to develop Heuristic, ML and GenAI pipelines and how they can be used:
      - Updates to YAML imports:
    - new delete rules: new known bad domains (...domain.TLD) of domains, subject string regex and body regex
        - New tools to find and identify safe senders
      - One device Heuristics, ML or GenAI tools
  - Store history of email content for future use of Heuristics, ML and GenAI spam identifiers (exact methods TBD)
    - Probably a database of fields - design and implement
    - Can use all of my personal emails via Windows App, Android App (eventually iPhone) scans
    - no duplicate emails in DB
    - can initially populate from existing delete rules and safe sender rules on Windows/Android
    - I have a partial history of deleted emails we can run through to get additional email examples
- **Claude Code Development Team**: MV76-1 (the six carried Fold checks); confirm the AOL/Yahoo package names for F253 on the device.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: Candidates surfaced as Step 5 improvement proposals for Harold's decision (not auto-added).

### Questions to be discussed before ending the sprint

- **Harold**: none

## Summary

Sprint 76 set out to fix the 0.17.0 field issues (F248-F250) and, at Harold's direction, grew into making
unattended Android background scanning work: diagnostics for every scan (F248), stop/spacing/KEEP fixes
(F249), Gmail renewal by stored refresh token (F250), the No Rule banner (F251), the battery setting and
wake timing (F252), the notification trigger (F253), and nine Manual Validation fixes. Six closed-test
builds (0.17.1-0.17.6) carried the work to the Fold; the 0.17.4 overnight run showed 95 unattended worker
starts, 111/113 completed and 10 spam deletions without the app being opened. Harold rated every category
Very Good. The process misses were all execution-side and are the subject of the improvement proposals.

## Improvement Decisions

(Recorded at Step 6.)
