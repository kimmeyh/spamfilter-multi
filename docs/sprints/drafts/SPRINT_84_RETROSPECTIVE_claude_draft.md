# Sprint 84 Retrospective -- Claude Code Development Team draft

[Claude-authored draft, Phase 7.3 Step 2. Written while Harold wrote his feedback. It is copied into the
Claude Code Development Team lines of `docs/sprints/SPRINT_84_RETROSPECTIVE.md`; it never replaces Harold's input.
The 7.7.1 findings by class are added to Categories 2 and 9 when the three reviews are dispositioned.]

## 1. Effective while as Efficient as Reasonably Possible
All nine tasks finished. Parallel block A (Tasks 2, 5, 8 as sub-agents on separate files) worked as planned, and the
three hook batches (Tasks 5, 6, 7) ran one at a time on `.claude/settings.json` with no collision. The largest waits
were the iOS CI runs (8 runs, 08:54-19:44 wall clock for Task 8) and the emulator windows for F280. Waste: one MV-6
Windows attempt (14:14-14:21) that could not be a first run (shared credential file, F354); it was stopped and
restored with 286 of 286 hashes matching, so it cost about 7 minutes plus the diagnosis, and it found F354.

## 2. Testing Approach
Every code task mutation-checked its new tests (Task 2 7/7, Task 5 11/11, Task 6 15/15, Task 7 19/19 KILLED) and the
hook ports ran parity probes against the PowerShell originals (Task 6 0/45, Task 7 1 of 454 payloads, explained).
F280 did not reproduce on three emulator arms, so the constraint was reverted on Harold's call instead of shipping an
untested fix. Gap: the clean Android first run found an ANR (F355) that no test covers: turning on background
scanning starts the worker at once, and no test runs that path with a real engine. 7.7.1 classes: [added after the
reviews].

## 3. Effort Accuracy
Within the estimate: Task 0 (~15 of 10-15), Task 5 (~109 of 90-150). Under: Task 6 (~83 of 120-200), Task 7 (~104 of
150-260). Over: Task 2 (~104 of 30-90; 11 logs and a fix the card did not plan), Task 3 (~191 of 60-120; three
20-minute emulator arms plus setup). Task 8 active time was not recorded (only the wall clock of 8 CI runs), so its
estimate cannot be judged; that is a recording gap, not a result.

## 4. Planning Quality
The 3.2.2.2 audit re-estimated Tasks 3, 4 and 8 before approval, and those re-estimates held better than the
original numbers. The plan named the MV-6 pre-flight risks (production seeding, the `com.example` migration) but not
the credential plugin's own storage folder; that gap is what F354 now records.

## 5. Model Assignments
Cheapest-first held: Haiku did Task 5 as assigned; Sonnet did Tasks 2, 3, 6, 7, 8 as assigned. Task 0 ran in the
main session with the reason recorded (same turn as approval). No escalations.

## 6. Communication
Two misses, both caught by Harold or by me in the same session: (a) F350 Q1 was re-asked without saying what "part 6"
was (Harold: "I cannot understand what part 6 is without further context"); memory and the represent rule now say an
option that names a part must say what it is. (b) a clock time was written as "13:4x" (estimated) and replaced with
"time not recorded". The new i/q question format (Harold, 2026-11-07) was used for the last two rounds and answered
in one message each time.

## 7. Requirements Clarity
Clear. Harold's F352 request was detailed enough to design from; the three placement and startup questions were
answered in one round and recorded as ADR-0052.

## 8. Documentation
ADR-0052 and the missing `SelectedAccountProvider` section in ARCHITECTURE.md were added the same day as the
decision. The retrospective improvement format moved into STEP 5 with pointers from three other files. One record
was wrong for about 10 minutes: check 10 first said "no way to send feedback" from a search whose file filter matched
nothing; corrected to "the GitHub issues address is plain text (`help_screen.dart:369`)".

## 9. Process Issues
Own-process slips: (1) the MV-6 pre-flight checked two seeding paths but not where the credential plugin keeps its
file, so the clean run was not clean (F354); (2) a zero-result search was reported as a finding without checking that
the filter matched any file (check 10); (3) the emulator DEV app was a day old (before 36b724ac); this was caught
before the evaluation, by comparing install time with the last `lib/` commit. 7.7.1 classes: [added after the
reviews].

## 10. Risk Management
The MV-6 Windows swap was hash-checked before and after and kept an evidence folder; nothing in production was
touched. F354 is the open risk: if the Store app reads the same credential file, a DEV account delete removes
production credentials. It is Priority 14 next sprint.

## 11. Next Sprint Readiness
Ready: F350 (P10), F352 (P12, ADR-0052 accepted), F354 (P14), F355 (P16), F341 remainder, F353. Carry-ins: MV-5 and
F342 on the Fold after 0.24.1 reaches it.

## 12. Architecture Maintenance
ADR-0052 recorded before any code; ADR-0035 data separation has a known gap (F354) recorded with file:line evidence.

## 13. Minor Function Updates for the Next Sprint Plan
None beyond the recorded carry-ins (MV-5, F342 phone check).

## 14. Function Updates for the Future Backlog
Already carded this sprint: F352, F353, F354, F355; F341 updated with what is left. Candidates from the Android first
run that are not yet cards (for the Step 5 proposals): the demo scan labelled "Live Scan", the Read-Only meaning of
"Deleted (not processed)", the outdated walkthrough, no message after notifications are refused, cut titles and the
"Backgrou / nd" tab label.
