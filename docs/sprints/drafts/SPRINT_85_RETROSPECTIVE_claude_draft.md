# Sprint 85 Retrospective -- Claude Code Development Team draft

[Claude-authored draft, Phase 7.3 Step 2. Written while Harold wrote his feedback. It is copied into the
Claude Code Development Team lines of `docs/sprints/SPRINT_85_RETROSPECTIVE.md`; it never replaces Harold's input.
The toolkit 7.7.1 findings are listed by class in Categories 2 and 9; Copilot's are added when its review arrives.]

## 1. Effective while as Efficient as Reasonably Possible
Every code task finished, and Manual Validation took about a week (11/13 handover to 11/18 close), most of it waiting
for Fold evidence. The biggest single waste was the Windows build block 11/10-11/13: a Visual Studio update removed
the Windows SDK manifest, and DEV could not be rebuilt until Harold ran the VS Repair. The parallel Python port batches
(Tasks 10-15, five agents at once) were faster than estimated, but they loaded the machine, and the full suite later
took 19 minutes instead of about 4 while another Claude session ran its tests (9 failures, 5 of them Task Scheduler
timeouts that pass on an idle machine).

## 2. Testing Approach
New tests were mutation-checked throughout (F352 11/11, F354 10/10, F330 64/64, F335 20/20, q2 and q10 KILLED). The
WinWright sweep found the q10 gap at rehearsal (5.1.9): the account row was one accessibility element, so UI Automation
could not reach the star, Start Scan or Delete. That is the rehearsal working as intended. Gaps: (a) F124 failed 6 of 6
through the runner on 11/13 and passed on 11/18 with no change; cause still unknown (F360). (b) The tests for the
ported scripts faked exit codes instead of running a real shell, so M1 (cmd returns 1, not 9009) passed its own
test. 7.7.1 classes (toolkit, 19 findings, 0 CRITICAL, 0 HIGH):
- **Failure that reaches only Logger or the opt-in diagnostic log** (silent M4, L2; code M-1): RECURRING. Sprint 81
  IMP-1 named this class, and the Sprint 85 5.1.2 M3 fix wrote the F354 reason to the diagnostic log, which is off by
  default, so the user still saw nothing. Fixed: Settings > General now shows the F354 reason; F352 catches go to the
  diagnostic log; docs corrected.
- **Python port reports success after a failed or empty step** (silent M1, M3, L4, L5, L6, L8): RECURRING (6 findings).
  The ports matched the `.ps1` happy path; their error paths (non-zero exit ignored, exit 0 when nothing was checked,
  no `finally`) were not compared with the originals.
- **Gate scope did not follow the port** (code M-2 `.py` not swept for version literals; silent L9 `.md` not
  scanned): RECURRING (2). A gate keyed on a file extension went quiet when the files changed extension.
- **Overwrite of an existing good value** (silent M2, `setup-claude-mcp.py` placeholder over a real token): single.
- **Two processes on one first-run path** (silent L1, F354 copy without a lock): single.
- **Docs describing a deleted script or wrong behavior** (code L-3, L-4, L-5): RECURRING (seen in Sprint 84 7.7.1).

## 3. Effort Accuracy
Python port batches came in under the estimate (F330 ~99 of 150-250, F333 ~82 of 180-300, F335 ~46 of 180-300).
F352 was inside (~135 of 120-240). Several pre-MV rows say "time not recorded" (Tasks 1, 2, 5, 7, 8), so their
accuracy cannot be judged; that is a recording gap. Manual Validation itself is not estimated anywhere and took the
longest wall-clock time.

## 4. Planning Quality
The plan put the F357 decisions behind the Fold evidence (Task 1 dependency), which was right: the log answered both
questions and Harold chose no change. The plan did not foresee the toolchain dependency (Windows SDK) or the need to
run the full suite on an idle machine (now in 5.2 after q6).

## 5. Model Assignments
Cheapest-first held: Haiku for F331, F332, F334 (agent part); Sonnet for F330, F333, F335, F352, F329; Opus main
session for F354 and the Phase 5 proofs, with reasons recorded. No escalations. The F307 R-1 audit (Haiku) needed its
claims re-checked by the main session.

## 6. Communication
Two MV steps cost Harold a round: MV-1(a) did not name the screen to open Settings from, so he got the picker; and
MV-4 asked for a Scan History row that was no longer on the Fold (its history started 11/14 1:30 PM when Harold
looked on 11/18). I should have checked the history window against the row date before writing the step. Questions were answered in one round each.

## 7. Requirements Clarity
Clear. F352 had ADR-0052 from Sprint 84; F354's scope came from file:line evidence. q1 (F307) surfaced that a removal
card needs a coverage audit first, which the card did.

## 8. Documentation
ADR-0051 and ADR-0052 current; ARCHITECTURE.md updated for F354. Reference ADRs (0017, 0027, 0039) still named the
deleted `.ps1` scripts as current until the 7.7.1 review; the Help page did not mention the default-account star.

## 9. Process Issues
Own-process slips: (1) MV-1(a) step missing its starting screen (rehearsed from a different screen); (2) MV-4 step
not checked against the Scan History retention; (3) the WinWright runner leaves the screen-reader flag on (F360);
(4) the full suite was run while another session loaded the machine. 7.7.1 classes as in Category 2; the recurring
ones are the port error-path class and the "only Logger" class.

## 10. Risk Management
Production credentials were hash-checked before and after every step that could touch them (464DC179B98A1F67
unchanged on 11/10, 11/13, 11/17). The AAB was byte-scanned for the Windows secret (0) with a positive control (12),
so the q2 fix is proven on the artifact, not only in the script.

## 11. Next Sprint Readiness
F307 removal is Sprint 86 scope (q1). New cards F359 (Android emulator integration test) and F360 (runner flag
restore, F124 runner-only failure). 0.25.0+23 AAB is built and not uploaded.

## 12. Architecture Maintenance
ADR-0051 (Python for deterministic tooling) applied across 47 deleted scripts with no live caller left. ADR-0035
gained the F354 credential-store rule.

## 13. Minor Function Updates for the Next Sprint Plan
F307 removal (Priority 36, moved by Harold). Any 7.7.1 improvement-review finding over the size limit.

## 14. Function Updates for the Future Backlog
F359, F360 (added). Candidate: a check that the Windows SDK manifest exists before a Windows build starts, so a
toolchain update fails fast with its cause.
