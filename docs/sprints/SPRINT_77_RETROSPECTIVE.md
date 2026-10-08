# Sprint 77 Retrospective

**Sprint**: 77 -- per-account background scanning, No Rule dedup, Custom IMAP with certificate trust, Gmail label IDs (0.18.0)
**PR**: #460 (feature/20261006_Sprint_77 -> develop)
**Date**: 2026-10-08
**Manual Validation**: complete (Harold: "Manual Validation complete"; MV-Q22: the step 2 on-screen check skipped -- "assuming step 2 fix is correct and without error (always expected prior to manual validation)")

Harold provided combined Product Owner / Scrum Master / Lead Developer feedback per category (recorded
verbatim below, counting for all three roles). Claude Code Development Team lines are from
`docs/sprints/drafts/SPRINT_77_RETROSPECTIVE_claude_draft.md`.

## Sprint 77 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Effective. All 8 cards delivered, plus 9 fixes from Manual Validation. MV found real, long-standing defects that no test had caught: a refused IMAP login read "check your internet connection" on every IMAP provider; 23 bundled safe senders could never match; re-adding an address silently replaced its server and password. Less efficient than it should have been: 3 of my validation steps were wrong (GreenMail user name, the step 5 rescan, the expected count of 5), and each cost Harold a round. The WinWright mt2c diagnosis went through 4 recorded states (verified, disproved, resolved, display-dependent).

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Strong at unit level. The suite grew from 2,607 to 2,918, and every sprint mutation was KILLED (F-PRECHECK 15/15; MV fixes ES1-ES2, LG1, L1-L3, Q8a-c, R1-R2, S1-S4). Weak at the UI-automation level. The close-out sweep is 2 of 3: `test_mt2c_no_rule_sweep` depends on the monitor's size. I declared it "RESOLVED" after one pass on the 3856x2128 monitor, and the close-out sweep on a ~1940x1040 display failed it. A pass in one environment proves that environment only.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Cannot be measured this sprint, and that is my miss. Every task card's `Executed-by` line still reads "(filled at completion)", and no per-task actuals were recorded in `CODING_VELOCITY.md` (only the planning row). The plan estimated 917-1,615 minutes plus a 120-minute emulator time-box. The sprint spanned 2026-10-06 20:58 to 10-08 16:37 elapsed (53 commits), which includes Harold's validation time and idle time, so it is not a work actual.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good. Three parallel card-draft agents plus 28 questions answered one at a time gave cards that held up. Audit-first findings were accurate, and the SEC-8b spike gate worked. One gap: the plan's MV steps did not name the preconditions the scanner imposes (the backlog cursor ignores the day count), which is the Sprint 75 IMP-5 class again.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: One interactive Opus session executed most tasks, under the plan's recorded single-session deviation. Agents were used where they fit: 3 Fable card drafts, a general-purpose agent for F245, a read-only Opus F-PRECHECK pass and a fix agent. No escalation problems. The `Executed-by` lines that would show this per task were never filled (see 3).

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Mostly good: decisions were asked one at a time as numbered lists, and MV steps were re-presented in full. Two misses: I told Harold the diagnostic log had "stopped" when the export folder had moved (a false alarm), and I reported the mt2c fix as resolved before it had run on a second display.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Clear. Harold's parity and prevention-first statements were quoted at the top of the plan and applied per card. The MV-Q answers (Q1-Q22) settled every ambiguity as it arose. F282 and F283 were drafted with their questions answered before they entered the backlog.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: ADR-0045 and ADR-0046 accepted; ADR-0039 amended twice. The DB v12/v13 notes, CHANGELOG and the F-PRECHECK evidence were recorded. Gaps found at 7.4.1 and fixed now: `ARCHITECTURE.md` still said "no delay at 15 minutes or less" after the MV-Q2 fixed stagger, and the ADR index row for 0039 omitted the Sprint 77 amendments. The PR description was a 1,426-character stub until Phase 6 (PR checkpoint #3 in Phase 5 says to update it).

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: (a) Recurring: validation steps written without tracing their preconditions (Sprint 75 IMP-5 restated it; it happened 3 times again). (b) Environment-specific "fixed" claims: the WinWright result was generalized from one monitor. (c) Placeholder lines that no gate reads ("(filled at completion)") let the effort record go empty. (d) The 5.1.5 sweep was first refused by the locked-workstation pre-flight, which worked as designed.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Good on the risky items: the DB v12 and v13 migrations ran on backed-up real data with hash-verified backups; certificate trust never accepts an untrusted certificate silently; the cross-account and scheduler changes were caller-enumerated. Open risk carried: the 0xc0000409 fail-fast crash on opening Review No Rule Items (cause unknown, not reproduced). Full local crash dumps are now enabled so the next occurrence is diagnosable.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Ready, with a known start sequence. Sprint 78 opens with the 0.18.0 Store and Play builds, Fold steps 7-11, and tracing the boot-time `main()` start. F282 and F283 are fully decided cards. The open crash and the mt2c rewrite are recorded (F283 holds the test rewrite).

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer (combined)**: Very Good
- **Claude Code Development Team**: Sound. One identity rule for No Rule entries (ADR-0045) replaced per-scan duplication (7,904 -> 583 rows); one TLS connect path for custom servers; one credential-label helper replaced four inconsistent strings; one login point maps a refused LOGIN for every IMAP provider. Doc drift as noted in 8 is fixed.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: The Sprint 78 start items already recorded: the 0.18.0 Store and Play builds, Fold steps 7-11, and the boot-time `main()` trace. Nothing new.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer (combined)**: none
- **Claude Code Development Team**: A card for the open 0xc0000409 crash, so it does not live only in this sprint's plan (proposed as IMP-4 for Harold to decide).

### Questions to be discussed before ending the sprint

- **Product Owner / Scrum Master / Lead Developer (combined)**: none

## 7.4.1 Architecture Compliance Check

- `ARCHITECTURE.md` Windows background section said "at 15 minutes or less there is no delay"; since MV-Q2 the code applies a fixed per-account slot stagger. Doc corrected (code is right).
- `docs/adr/README.md` row for ADR-0039 omitted the F264 and MV-Q2 amendments; corrected.
- ADR-0045 and ADR-0046 rows: present and Accepted. DB v12/v13 notes present. Custom IMAP, `ImapTlsConnector`, `ImapHostPolicy` and the corrected pinner are described. No code-versus-doc conflict requiring a revert.

## Summary

PENDING -- written after the Step 6 decisions.

## Improvement Decisions

PENDING -- Step 6.
