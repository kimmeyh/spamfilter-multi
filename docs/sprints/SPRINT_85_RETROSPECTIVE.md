# Sprint 85 Retrospective
**Sprint**: 85 -- F350 risk-based test analysis, F352 default account, F354 DEV credential folder, F355 Android
background-scan ANR, F357 interrupted-row decisions, F341 first-run remainder, F307 audit (removal moved to Sprint 86),
F329-F335 Python batches (ADR-0051), carry-ins (F342 Fold check, MV-3c), version 0.25.0+23
**PR**: #559 (feature/20261108_Sprint_85 -> develop), DRAFT until 7.7.5
**Date**: 2026-11-19
**Manual Validation**: complete (Harold, 2026-11-18: MV-4 closed, "don't ask again"; MV-6 "all good"; MV-7 "all is
working as expected"; F357 q1 = 1, q2 = 1; and "Manual Validation complete" at the top of his retrospective feedback).

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded verbatim
below, counting for all three roles). The Claude Code Development Team lines are Claude's own (draft:
`docs/sprints/drafts/SPRINT_85_RETROSPECTIVE_claude_draft.md`). Harold's "Questions to be discussed before
ending the sprint": "none".

## 7.7.1 findings by class

Reviews (started 2026-11-18 at 7f90b650, PR #559 DRAFT, full diff 257 files): Copilot 1 Low; code-reviewer 0 C / 0 H /
2 M / 3 L (197 of 257 files read); silent-failure-hunter 0 C / 0 H / 4 M / 10 L (128 of 257 read); a second
code-reviewer pass on the 66 files neither had read: 0 findings (66 of 66 read), 2 of its 5 lower items fixed. All
fixed without asking. Fix commits 6b5cea9a, 1748bdc3, 893be44f, 48160d51. Full disposition: `SPRINT_85_PLAN.md`
"Phase 7.7.1 final code reviews".

- **Class A -- a failure that reaches only Logger or the opt-in diagnostic log** (3): the F354 copy failure (SF M4,
  CR M-1; the 5.1.2 M3 fix had moved it to the diagnostic log, which is off by default, and the card said the user
  need not know because the build is DEV-only); the F352 default-account read and seed failures (SF L2). RECURRING:
  Sprint 81 IMP-1. -> i3.
- **Class B -- a tool reports success after a failed or empty step** (8): `mutation-test.py` counted a command that
  could not start as KILLED (SF M1; its test faked exit code 9009, real cmd returns 1); `test-inventory.py` made every
  test "low risk" when git failed (SF M3); exit 0 when nothing was checked or a delete failed (SF L6, four scripts);
  server stderr hidden (SF L4); a failed process listing read as "none running" (SF L5); emulator not restored on an
  exception (SF L8). Two more of the same class were found by the 5.1.2 self-review on 11/10, recorded as "Not
  fixed, LOW", and were still open at 7.7.1 (`validate-yaml-rules.py` 0 patterns, `phone-log-health.py:117`); fixed
  48160d51. RECURRING: Sprint 83 IMP-3 (five tools). -> i1, i4.
- **Class C -- a gate keyed on a file type went quiet when the files changed type** (2): the version sweep did not read
  `.py` (CR M-2); the missing-scripts gate did not read live instruction `.md` files (SF L9). RECURRING (2 this
  sprint). -> i4.
- **Class D -- user-visible text that does not match the shipped behavior** (2): CHANGELOG "The app opens on that
  account" (the start screen does not change, ADR-0052 decision 3; CR L-4); Help > Select Account "swipe an account
  to delete" (it is the trash can icon) and no word on the default star (CR L-3). RECURRING: Sprint 81 class B,
  82, 83, 84 class A (Sprint 84 i1 was "skip, track: propose again if it recurs"). -> i2.
- **Class E -- docs still describe a script after its port** (2): ADR-0017 still PowerShell-only (Copilot); ADR-0027,
  ADR-0039 and the F77 note named the deleted `.ps1` (CR L-5). RECURRING: Sprint 83, Sprint 84 class D. The cards
  carried the Sprint 84 i4 "Old name search" line, but no card recorded its hits. -> i5.
- **Single findings, root cause recorded**: `setup-claude-mcp.py` wrote the placeholder over a real GitHub token
  when `GITHUB_TOKEN` was unset (SF M2): the port wrote the file unconditionally, as the original did, and its test
  started from an empty file. The F354 copy had no lock, so the UI process and a background scan could copy at once
  (SF L1): the card listed the two processes for the credential store but not for the copy itself. `build-with-
  secrets.py` claimed AOL for the Android build (SF L3): the provider check was copied from the `.ps1`, which
  predates F335.

## Sprint 85 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Every code task finished, and Manual Validation took about a week (11/13 handover to 11/18 close), most of it waiting for Fold evidence. The biggest single waste was the Windows build block 11/10-11/13: a Visual Studio update removed the Windows SDK manifest, and DEV could not be rebuilt until Harold ran the VS Repair. The parallel Python port batches (Tasks 10-15, five agents at once) were faster than estimated, but they loaded the machine, and the full suite later took 19 minutes instead of about 4 while another Claude session ran its tests (9 failures, 5 of them Task Scheduler timeouts that pass on an idle machine).

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: New tests were mutation-checked throughout (F352 11/11, F354 10/10, F330 64/64, F335 20/20, q2 and q10 KILLED; every 7.7.1 fix test KILLED). The WinWright sweep found the q10 gap at rehearsal (5.1.9): the account row was one accessibility element, so UI Automation could not reach the star, Start Scan or Delete. Gaps: (a) F124 failed 6 of 6 through the runner on 11/13 and passed on 11/18 with no change; cause still unknown (F360). (b) Tests for the ported scripts faked exit codes instead of running a real failing command, so `mutation-test.py` counted a command that could not start as KILLED (cmd returns 1, not the faked 9009) and its own test passed. (c) The first two 7.7.1 reviewers read 197 and 128 of 257 files; a second pass closed the gap (66 of 66, 0 findings). 7.7.1 classes: A (failure only in a log), B (tool reports success after a failed step), C (gate scope did not follow the port); see "7.7.1 findings by class".

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Python port batches came in under the estimate (F330 ~99 of 150-250, F333 ~82 of 180-300, F335 ~46 of 180-300). F352 was inside (~135 of 120-240). Several rows say "time not recorded" (Tasks 1, 2, 5, 7, 8), so their accuracy cannot be judged; that is a recording gap, and Sprint 84 had the same gap for Task 8. Manual Validation itself is not estimated anywhere and took the longest wall-clock time.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The plan put the F357 decisions behind the Fold evidence (Task 1 dependency), which was right: the log answered both questions and Harold chose no change. The port cards carried the Sprint 84 "Port of existing code" and "Old name search" lines, but their results were never recorded (no hit list in the plan, the commits or the cards), so the lines did not do their job (class E). The plan did not foresee the toolchain dependency (Windows SDK) or the need to run the full suite on an idle machine (now in 5.2 after q6).

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Cheapest-first held: Haiku for F331, F332, F334 (agent part); Sonnet for F330, F333, F335, F352, F329; Opus main session for F354 and the Phase 5 proofs, with reasons recorded. No escalations. The F307 R-1 audit (Haiku) needed its claims re-checked by the main session. The 7.7.1 Python fix agent's one over-strict change (L3 refused every AOL-only debug build) was narrowed by the main session on review.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two MV steps cost Harold a round: MV-1(a) did not name the screen to open Settings from, so he got the picker; and MV-4 asked for a Scan History row that was no longer on the Fold (its history started 11/14 1:30 PM when Harold looked on 11/18). I should have checked the history window against the row date before writing the step. Questions were answered in one round each.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Clear. F352 had ADR-0052 from Sprint 84; F354's scope came from file:line evidence. q1 (F307) surfaced that a removal card needs a coverage audit first, which the card did.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0051 and ADR-0052 current; ARCHITECTURE.md updated for F354. Reference ADRs (0017, 0027, 0039) still named the deleted `.ps1` scripts as current until the 7.7.1 review (Copilot found ADR-0017); the Help page still said "swipe to delete" and did not mention the default star, and the CHANGELOG said the app "opens on" the default account. All fixed in 6b5cea9a.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Own-process slips: (1) MV-1(a) step missing its starting screen; (2) MV-4 step not checked against the Scan History retention; (3) the 5.1.2 self-review found class B items and recorded them as "Not fixed, LOW" -- 7.7.1 then found the same class in the same files (`test-inventory.py` as MEDIUM M3), and two were still open until 48160d51; (4) the 5.1.2 M3 fix itself sent the F354 reason only to an opt-in log; (5) the Old name search and the port defect review were written into the cards and never recorded; (6) the WinWright runner leaves the screen-reader flag on (F360); (7) the full suite was run while another session loaded the machine. Sprint 84 tracked items: i1 (class A text) recurred as class D here; i7 (wasted first-run attempt) did not recur.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Production credentials were hash-checked before and after every step that could touch them (464DC179B98A1F67 unchanged on 11/10, 11/13, 11/17). The AAB was byte-scanned for the Windows secret (0) with a positive control (12), so the q2 fix is proven on the artifact, not only in the script. The 7.7.1 L3 fix now refuses a release build without the Gmail client id before the long build starts.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: F307 removal is Sprint 86 scope (q1). New cards F359 (Android emulator integration test) and F360 (runner flag restore, F124 runner-only failure). 0.25.0+23 AAB is built and not uploaded. 29 tracked `.ps1` files remain, so later ports will meet classes B, C and E again unless the proposals below hold.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0051 (Python for deterministic tooling) applied across 47 deleted scripts with no live caller left. ADR-0035 gained the F354 credential-store rule. ADR-0017, 0027 and 0039 now carry notes naming the Python ports.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: F307 removal (Priority 36, moved by Harold) is already a carry-in. Any 7.7.1 improvement-review finding over the size limit.

### 14. Function Updates for the Future Backlog

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: F359, F360 (already added). Candidate for the Step 5 proposals: a check that the Windows SDK manifest exists before a Windows build starts, so a toolchain update fails fast with its cause (i8).

## Improvement Decisions

Proposals i1-i8 presented 2026-11-19. Harold's answers, 2026-11-21 (verbatim): "i1. a i2. a i3. a i4. a i5. a i6. a
i7. a i8. e" and "add to next sprint backlog and rank in top 10 for next sprint: add to Improvements Effort, what the
change adds to full-suite and CI testing time".

- **i1. a -- APPLIED**: 5.1.2 findings are fixed at 5.1.2 under the 7.7.1 rule; no "Not fixed, LOW"; a finding
  over the size limit or decision-class becomes a numbered question at the MV handover.
  `SPRINT_EXECUTION_WORKFLOW.md` 5.1.2, `SPRINT_CHECKLIST.md` Phase 5.
- **i2. a -- APPLIED**: 5.1.2 class 3 lists every CHANGELOG line added and the Help page of every changed screen;
  each behavior claim is recorded as `<claim>: <file:line>`. Same two files.
- **i3. a -- APPLIED**: the class 6 "need not know" exception does not apply to a failure that changes what the user
  sees; that failure shows its reason on that screen. Same two files.
- **i4. a -- APPLIED**: the card template's "Port of existing code" line gains "Error paths" (with a test that runs a
  real failing command) and "Gates by file type". `SPRINT_PLANNING.md`.
- **i5. a -- APPLIED**: the card lines record RESULTS at completion; new close-out check 3d-4 in
  `.claude/hooks/verify-closeout-complete.py` (Sprint 86+) blocks a line with a `<...>` placeholder or with no
  file:line / "none found" / "no hits" / leading "N/A". Hook cases allow-12, violation-17, violation-18.
  `SPRINT_PLANNING.md` template note.
- **i6. a -- APPLIED**: 5.1.9 steps Claude cannot rehearse list their preconditions and record each readable one
  as `Precondition: <what>: <how checked>`. `SPRINT_EXECUTION_WORKFLOW.md` 5.1.9, `SPRINT_CHECKLIST.md`.
- **i7. a -- APPLIED**: the CODING_VELOCITY row is added with `Started <date HH:MM>` when the task starts.
  `SPRINT_EXECUTION_WORKFLOW.md` 3.2.2.3, `SPRINT_CHECKLIST.md` Phase 4.
- **i8. e -- TRACKED, not built**: Windows SDK check before a Windows build. Propose again if a toolchain update
  breaks the Windows build again.
- **New backlog item -- F361** (Priority 38, top 10 for Sprint 86): each retrospective improvement's Effort states
  what the change adds to full-suite and CI test time. `ALL_SPRINTS_MASTER_PLAN.md`.

## Completeness Validation (Phase 7.3/7.4 exit gate)

- [x] All 14 categories are present
- [x] Each category has all 4 roles (Harold's combined line counts for PO, SM and Lead Developer)
- [x] No line is empty or a placeholder
- [x] Category 13: Harold "none"; Claude: none beyond the recorded carry-ins
- [x] Category 14: Harold "none"; Claude's candidate goes to the Step 5 proposals for Harold to decide
