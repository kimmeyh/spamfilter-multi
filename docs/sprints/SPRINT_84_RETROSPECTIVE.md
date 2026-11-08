# Sprint 84 Retrospective
**Sprint**: 84 -- F342 Fold background errors, F280 Doze network (not reproduced, reverted), F341 first-run
evaluation (Android leg done, rest moved to the next sprint), F326 / F327 / F328 hooks to Python, F345 iOS
Simulator and privacy manifest, version 0.24.1+22, MV-3c / MV-4 phone checks
**PR**: #548 (feature/20261105_Sprint_84 -> develop), DRAFT until 7.7.5
**Date**: 2026-11-07
**Manual Validation**: complete (Harold, 2026-11-07: q1 = a, and "Manual Validation complete" at the top of
his retrospective feedback). MV-1, MV-3, MV-4 PASS; MV-2 N/A; MV-5 Phase 8 carry-in; MV-6 moved to F341.

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim
below, counting for all three roles). The Claude Code Development Team lines are Claude's own (draft:
`docs/sprints/drafts/SPRINT_84_RETROSPECTIVE_claude_draft.md`). Harold's "Questions to be discussed before
ending the sprint": "none".

## 7.7.1 findings by class

Reviews (started 2026-11-07 19:36, PR #548 DRAFT): Copilot 1 High / 1 Low; code-reviewer 0 C / 0 H / 3 M / 5 L
(66 of 73 files read); silent-failure-hunter 0 C / 0 H / 6 M / 13 L (67 of 73 read). Five pairs were the same issue.
All fixed without asking except four questions (q1-q4). Fix commits 0e80c9fb, a71025e0, 9eb90397, d4178c5b, 98477e31.
Full disposition: `SPRINT_84_PLAN.md` "Phase 7.7.1 final code reviews".

- **Class A -- user-visible text or a record promises behavior that is not proven or did not ship** (5): the 0.24.1
  release notes claimed reverted F280 and a Windows fix that is Android-only (CR M2 = SF M3); F342 "restart is not
  refused" in code, CHANGELOG and ARCHITECTURE (CR M1); the F342 reason promised a next scan after an app cancel
  (SF M1); the iOS test header named a screenshot fallback that does not exist (CR L3 = SF L10). RECURRING: Sprint 81
  class B, Sprint 82 (F314 "results stored first"), Sprint 83 (0.24.0 notes still PROVISIONAL at 7.7). -> i1.
- **Class B -- a hook check returns silently when its input fails** (9): closeout 3e, 3a-2, 3c, 3d (missing plan),
  the non-JSON message, a non-object status file, a failed `git branch`, an empty cwd, the internal-error first line
  (SF M4, M5, L4-L9, CR L1). RECURRING: Sprint 82 IMP-1, Sprint 83 F6-1 (fixed for `gh` only). -> i2.
- **Class C -- a port copies a defect of its original** (3): the card gate counted any non-empty dict (Copilot H);
  the stash guard allowed `list && pop` and `git -C` (SF M6 = CR L5); a missing plan passed 3d (SF L4). Parity probes
  proved the port equal to a defective original. RECURRING with Sprint 83 IMP-1 (a second copy that drifts). -> i3.
- **Class D -- pointers left on the old file after a migration** (2): CLAUDE.md and `.codex/hooks.json` named the
  unregistered `.ps1` hooks (CR M3); the iOS docs described one job after the split (CR L3). RECURRING with Sprint 83
  (ADR-0051 "Proposed" in three files after acceptance). -> i4.
- **Class E -- a test that cannot fail for the defect it names** (2): the F342 wiring test was a source-text check
  (CR L4); the Rule Test short-viewport tests had no mutation record (SF L11; mutation run 2026-11-07, 2 of 2 KILLED,
  so the tests were good, the record was missing). RECURRING (Sprint 73 IMP-3). -> i5.
- **Class F -- mirror sites missed by a narrow grep** (1 here, plus 5.1.2 F1-1 this sprint): six more empty states
  (CR L2), added to F353. -> i6.
- **Single findings, root cause recorded**: F342 handler order (CR M1 = SF M2): the Sprint 79 stop handler wrote its
  log line first, and the F342 close was appended after it without asking what runs if the process dies mid-handler.
  SF L1 (count lost), SF L3 (registration outside `try`), SF L12 (ints written as strings by a hand edit).
  Questions: SF L2 (q1), the Doze-alarm recent-scan check (q2), SF L13 notice rendering (q3), the 26 s worst case
  against the 20 s hook timeout (q4).

## Sprint 84 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: All nine tasks finished. Parallel block A (Tasks 2, 5, 8 as sub-agents on separate files) worked as planned, and the three hook batches (Tasks 5, 6, 7) ran one at a time on `.claude/settings.json` with no collision. The largest waits were the iOS CI runs (8 runs, 08:54-19:44 wall clock for Task 8) and the emulator windows for F280. Waste: one MV-6 Windows attempt (14:14-14:21) that could not be a first run (shared credential file, F354); it was stopped and restored with 286 of 286 hashes matching, so it cost about 7 minutes plus the diagnosis, and it found F354.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Every code task mutation-checked its new tests (Task 2 7/7, Task 5 11/11, Task 6 15/15, Task 7 19/19 KILLED) and the hook ports ran parity probes against the PowerShell originals (Task 6 0/45, Task 7 1 of 454 payloads, explained). F280 did not reproduce on three emulator arms, so the constraint was reverted on Harold's call instead of shipping an untested fix. Gap: the clean Android first run found an ANR (F355) that no test covers: turning on background scanning starts the worker at once, and no test runs that path with a real engine. 7.7.1 classes: B (nine hook checks that skipped silently had no
failure-path case) and E (a text-only wiring test; a layout test with no mutation record).

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Within the estimate: Task 0 (~15 of 10-15), Task 5 (~109 of 90-150). Under: Task 6 (~83 of 120-200), Task 7 (~104 of 150-260). Over: Task 2 (~104 of 30-90; 11 logs and a fix the card did not plan), Task 3 (~191 of 60-120; three 20-minute emulator arms plus setup). Task 8 active time was not recorded (only the wall clock of 8 CI runs), so its estimate cannot be judged; that is a recording gap, not a result.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The 3.2.2.2 audit re-estimated Tasks 3, 4 and 8 before approval, and those re-estimates held better than the original numbers. The plan named the MV-6 pre-flight risks (production seeding, the `com.example` migration) but not the credential plugin's own storage folder; that gap is what F354 now records.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Cheapest-first held: Haiku did Task 5 as assigned; Sonnet did Tasks 2, 3, 6, 7, 8 as assigned. Task 0 ran in the main session with the reason recorded (same turn as approval). No escalations.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two misses, both caught by Harold or by me in the same session: (a) F350 Q1 was re-asked without saying what "part 6" was (Harold: "I cannot understand what part 6 is without further context"); memory and the represent rule now say an option that names a part must say what it is. (b) a clock time was written as "13:4x" (estimated) and replaced with "time not recorded". The new i/q question format (Harold, 2026-11-07) was used for the last two rounds and answered in one message each time.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Clear. Harold's F352 request was detailed enough to design from; the three placement and startup questions were answered in one round and recorded as ADR-0052.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0052 and the missing `SelectedAccountProvider` section in ARCHITECTURE.md were added the same day as the decision. The retrospective improvement format moved into STEP 5 with pointers from three other files. One record was wrong for about 10 minutes: check 10 first said "no way to send feedback" from a search whose file filter matched nothing; corrected to "the GitHub issues address is plain text (`help_screen.dart:369`)".

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Own-process slips: (1) the MV-6 pre-flight checked two seeding paths but not where the credential plugin keeps its file, so the clean run was not clean (F354); (2) a zero-result search was reported as a finding without checking that the filter matched any file (check 10); (3) the emulator DEV app was a day old (before 36b724ac); this was caught before the evaluation, by comparing install time with the last `lib/` commit. 7.7.1 classes: A (release notes
marked "re-derive at 7.7" were not re-derived before the reviews), C (the Python port proved parity with a defective
original), D (pointers to the old hooks were not grepped after the port).

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The MV-6 Windows swap was hash-checked before and after and kept an evidence folder; nothing in production was touched. F354 is the open risk: if the Store app reads the same credential file, a DEV account delete removes production credentials. It is Priority 14 next sprint.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Ready: F350 (P10), F352 (P12, ADR-0052 accepted), F354 (P14), F355 (P16), F341 remainder, F353. Carry-ins: MV-5 and F342 on the Fold after 0.24.1 reaches it.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0052 recorded before any code; ADR-0035 data separation has a known gap (F354) recorded with file:line evidence.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: None beyond the recorded carry-ins (MV-5, F342 phone check).

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: Already carded this sprint: F352, F353, F354, F355; F341 updated with what is left. Candidates from the Android first run that are not yet cards (for the Step 5 proposals): the demo scan labelled "Live Scan", the Read-Only meaning of "Deleted (not processed)", the outdated walkthrough, no message after notifications are refused, cut titles and the "Backgrou / nd" tab label.

## Improvement Decisions

Harold, 2026-11-08, verbatim: *"i1. e i2. b. i3. a i4. a i5. a i6. a i7. e. i8. a q1. c q2. a q3. more details on
what a "hook notice" is and what it looks like (do all the other i and q items first before providing) q4. can you
get it to go faster, otherwise a"*

- i1: e -- skip this sprint, track. Release notes keep the manual 7.7 re-derive step; no Source line and no test.
  Track: if class A (text that promises more than shipped) recurs in the Sprint 85 7.7.1 reviews, propose i1 again.
- i2: b -- backlog. Added to F329 (the fault-injection test for every hook).
- i3: a -- done. `SPRINT_PLANNING.md` card template: new "Port of existing code" line.
- i4: a -- done. `SPRINT_PLANNING.md` card template: new "Old name search" line.
- i5: a -- done. `SPRINT_EXECUTION_WORKFLOW.md` 5.1.9 and `SPRINT_CHECKLIST.md`: each new guard test is listed with
  its mutation verdict.
- i6: a -- done. `SPRINT_EXECUTION_WORKFLOW.md` 5.1.2 class 1: the search for a code shape covers nested forms.
- i7: e -- skip this sprint, track. Track: if a first-run attempt is wasted again by a stored item that was missed,
  propose i7 again.
- i8: a -- one backlog card, F356 "Android first-run polish".
- q1: c -- backlog until the Fold check; recorded in F357.
- q2: a -- backlog card F357, decided with the F342 Fold evidence.
- q3: Harold asked what a "hook notice" is and what it looks like, after the other items. Explained in the session
  2026-11-08; the decision is still open.
- q4: "can you get it to go faster, otherwise a": faster, so `.claude/settings.json` is unchanged (20 seconds).
  `verify-closeout-complete.py` now runs its two gh calls at the same time and gives all git and gh calls one
  15 second budget; a call with no time left is not made and its check adds a "did not run" notice.

## Completeness Validation (Phase 7.3/7.4 exit gate)

- [x] All 14 categories are present
- [x] Each category has all 4 roles (Harold's combined line counts for PO, SM and Lead Developer)
- [x] No line is empty or a placeholder
- [x] Category 13: Harold "none"; Claude: none beyond the recorded carry-ins
- [x] Category 14: Harold "none"; Claude's candidates go to the Step 5 proposals for Harold to decide
