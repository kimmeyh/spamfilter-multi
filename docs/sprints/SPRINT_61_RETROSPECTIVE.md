# Sprint 61 Retrospective

**Sprint**: 61 (2026-08-16 to 2026-08-20)
**Branch**: `feature/20260816_Sprint_61`
**PR**: #347 (draft, -> develop)
**Scope delivered**: Task 0 (line endings), F170 (Phase 8 Release Cycle encoding), F169 (account
filter dropdown), F168 (background folder-scope visibility), F172 (AppBar version label), F171
(1024x640 minimum-window sweep), F162 (parity audit + ADR-0042), F167 (Help capability wording),
F161 (Android background-scan scheduling -- the ADR-0042 platform factory). All 9 tasks complete;
Manual Validation complete 2026-08-20 including the F161 count-parity PASS.

Harold's feedback below is recorded verbatim as a combined Product Owner / Scrum Master / Lead
Developer line per category (per SPRINT_RETROSPECTIVE.md, a combined line is acceptable).

## Sprint 61 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Good
- **Claude Code Development Team**: Mixed. Code tasks ran at or under estimate (F161 at ~120m of
  a 180-300m estimate) and the MV forensics converted every failure into a registered backlog
  item with root cause. But real wall-clock was lost to preventable operational mistakes:
  launching the emulator as a background-shell child (killed with its parent), a `-ColdBoot`
  switch that was recorded as delivered but never landed on disk, and re-deriving WorkManager
  retry-on-relaunch behavior live instead of reading the plugin's persistence model first.

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Needs
  improvement as noted by dev team during sprint
- **Claude Code Development Team**: Agreed, and the concrete case is ours: the F161 settings
  call-site reroute was labeled "mechanical" and shipped untested -- both call sites kept their
  `if (Platform.isWindows)` guards, so Android silently got no scheduling. Harold found it live
  in MV round 1. That is exactly the silent-claim failure shape ADR-0042 warns about, one file
  away from the factory whose adapters we tested thoroughly (9 mutation-verified tests). What
  worked: mutation verification, the policy gates (the version_consistency gate correctly caught
  a test sentinel), and DB-level verification catching real defects. The gap is call-site
  verification when an abstraction replaces platform-gated code -- see IMP-2.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Good
- **Claude Code Development Team**: Good. Per-task actuals recorded in the plan; F161 came in
  under estimate. Manual Validation consumed far more wall-clock than planned, but from live
  defects (the F175/F177 scan cascade), not estimation error -- the estimates covered build, not
  discovery.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Good
- **Claude Code Development Team**: Good. Running F170 first worked; front-loading ADR-0042 as
  the gate for F161/F167 was the right dependency call; the augmented card template kept
  acceptance criteria checkable. One planning note: the plan did not anticipate that F161
  validation would need emulator forensics tooling (log monitors, DB pulls, exit-info), which
  is where the schedule stretched.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Good
- **Claude Code Development Team**: The whole sprint executed on the top tier in one continuous
  session, including mechanical doc edits a cheaper tier could have done. Defensible because
  execution was interleaved with Harold-driven MV (context switching would have cost more than
  it saved), but it should stay a visible choice, not a default.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: Strong during MV forensics: live traces, memory arithmetic,
  explicit go/no-go asks before force-stops. The clear failure was three turn-ending violations
  early in execution (announcing the next task and then ending the turn) -- Harold flagged each,
  and they were pre-named for this retrospective. See IMP-1.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: Very good. Harold's steering was precise and immediately
  actionable ("was background scanning expected to work correctly or just work?", the F177
  batch-split ask with "can you figure out these", the F167 unshipped-platform correction). The
  echo-back pattern caught scope drift before it happened.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: Heavy and current: Phase 8 encoded across the workflow docs,
  ADR-0042 with the factory addendum, five findings (F174-F178) registered with evidence and fix
  shapes the same day they were found. Two defects on our side: a doc script clobbered F161
  completion notes by reusing a string read before an earlier save (caught by post-commit
  verification, restored), and the `-ColdBoot` switch was described in the sprint record without
  the edit actually landing (caught only when used). ARCHITECTURE.md coverage of the F161
  components was found missing at retro time and fixed before this document was written -- a
  same-turn catch, but the no-defer rule says it should have been updated before MV. See IMP-3.

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Good - see
  issues noted by dev team during sprint
- **Claude Code Development Team**: The sprint's list, all resolved same-day: (a) three
  turn-ending failures (the sprint's headline process issue); (b) a hook-blocked commit was
  retried with the fix CHAINED into the blocked command, re-learning a Sprint 60 lesson --
  fix standalone first, then commit; (c) `github_issues` was emptied at card closure, which
  `require-sprint-cards` correctly reads as "Phase 3.3.1 never ran" -- the array empties only at
  next-sprint rollover; (d) the emulator was launched as a background-Bash child and died with
  its parent shell -- GUI processes launch via PowerShell `Start-Process` only; (e) the
  recorded-but-not-landed `-ColdBoot` edit. Operational discoveries worth keeping: WorkManager
  persists killed tasks and re-fires them at every app launch until success (cleared by deleting
  `no_backup/androidx.work.workdb*` while stopped), and the Manual and Background tabs have
  SEPARATE Scan Range settings (the first Test scan ran at daysBack=0 because only the manual
  tab had been updated).

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: Very good under fire: the scan-cascade day was contained
  with force-stops and a surgical WorkManager-state clear rather than data-destructive resets;
  the memory root cause was proven from `dumpsys` exit records before any fix was proposed; and
  F177's fix parameters were computed and registered instead of hot-patching mid-validation.
  ReadOnly mode for all parity scans meant no real mail was ever at risk.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: Ready. F168 is already flagged TARGET NEXT SPRINT; F174-F178
  are registered with root causes and fix shapes; the Sprint 62 validation carry-over (Windows
  F161 AC-4 check) is recorded in the master plan; `sprint_status.json` is current.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: Very Good
- **Claude Code Development Team**: ADR-0042 was accepted and immediately exercised by F161 --
  the factory, the explicit no-op, and the declared platform exceptions all follow it, and MV
  round 1 proved WHY it exists (the un-rerouted call sites were precisely the failure it names).
  ARCHITECTURE.md was updated with the F161 components (BackgroundScanCore, the scheduler
  factory, the Android worker) -- late, at retro time rather than before MV, noted honestly in
  Category 8.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint 62.)

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: none
- **Claude Code Development Team**: (1) Sprint 62 Manual Validation must include the Windows
  background-scan regression check (F161 AC-4) -- one glance at Windows Scan History confirming
  scheduled scans ran normally through the scheduler refactor (Harold: "I believe it is working
  as expected"; registered in ALL_SPRINTS_MASTER_PLAN.md). (2) At branch rollover, empty
  `sprint_status.json` `github_issues` THEN -- not at card closure.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates"
with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined, Harold verbatim)**: none
- **Claude Code Development Team**: None new at retro time -- everything surfaced during the
  sprint was registered same-day: F174 (silent empty-folder fetch), F175 (scan concurrency +
  orphan reconciliation), F176 (account email on scan screens), F177 (chunked fetch, m=20),
  F178 (Android popup clips Block Subject), F173 (recurring test-coverage deep dive, HOLD).

### Questions to be discussed before ending the sprint

- **Harold (verbatim)**: none

## Improvements -- proposed, approved, applied

Harold approved ALL FOUR ("all", 2026-08-21). Each is applied with evidence:

- **IMP-1 (turn-ending guard) -- APPLIED**: `sprint-auto-advance.ps1` Gate 2 now also blocks a
  turn that ENDS on a future commitment ("Next: F169. I'll start with...") with no action taken,
  checked against the message tail so mid-message narration does not trip it. Two new test cases
  (violation-13, allow-16); hook suite 49/49. The violation case would have passed every
  pre-existing gate (no question mark, no procedural phrase), proving the new patterns are what
  catch it. Memory rule already covered by the hook plus this record.
- **IMP-2 (factory call-site verification) -- APPLIED**: ADR-0042's factory section gains the
  rule "call-site verification is part of introducing a factory, not optional cleanup", citing
  the F161 escape. First instance implemented: `test/policy/factory_call_site_test.dart` pins
  both `_updateScheduledScan` call sites in settings_screen as platform-free (exact count
  asserted, comment lines stripped so the explanatory comments cannot mask a real guard).
  Mutation-verified: re-adding `if (Platform.isWindows)` at a call site turns it red.
- **IMP-3 (claimed-change verification) -- APPLIED**: memory `feedback_claimed_change_verification`
  saved -- any completion note naming a specific file change requires a same-turn grep of that
  file. Covers both Sprint 61 instances (the never-landed `-ColdBoot` switch, the doc-script
  clobber).
- **IMP-4 (operational memory saves) -- APPLIED**: memories saved for WorkManager
  retry-on-relaunch persistence (and the workdb clearing procedure), the separate
  Manual/Background Scan Range settings, and the background-Bash-child variant added to the
  existing Start-Process memory (the emulator died when its parent background task's shell
  closed).
