# Sprint 74 Retrospective

**Sprint**: 74 -- device carry-ins, per-provider folder defaults, result ordering, platform export, one-scan-per-account lock
**Branch / PR**: `feature/20260924_Sprint_74` / #440 (draft until Phase 7.7)
**Version**: 0.17.0+8 (dev). **Release**: 0.17.0 on HOLD for both stores until F238 (#441) ships in Sprint 75; no AAB until the Sprint 74 and Sprint 75 PRs are both merged.
**Manual Validation**: COMPLETE (Harold, 2026-09-29). Phone checks for 0.17.0 moved to Sprint 75 Manual Validation (no AAB).
**Final evidence**: suite 2,417 passed / 15 skipped / 0 failed; analyzer clean; WinWright 2/2 at `46fd173`; all mutations in the sprint KILLED.

Harold supplied ONE combined Product Owner / Scrum Master / Lead Developer response; it is recorded verbatim under each of those three roles.

## Sprint 74 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The planned code tasks landed under estimate, but Manual Validation became the largest block of the sprint: five rounds, with most of the work unplanned (F232 fix, the scan lock, F222 rework, Android YAML export, Gmail tokens, busy retry, subject-rule label). Avoidable waste: F222 was built to the card text and rebuilt (~60 min); a script edit with a wrong end anchor deleted a neighboring widget test (caught by the analyzer, restored from HEAD); a Python heredoc wrote real line breaks into a Dart string (the Sprint 72 IMP-3 failure, repeated); two mutation runs failed to start because the helper could not match a Unicode bullet or CRLF line endings.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Every new test was mutation-checked (M26-M58, all KILLED), and each test file names what it does NOT catch. The review agent found two real IMPORTANT defects in the lock (a timed-out scan kept running; a database error counted as success). Gaps named, not closed: two real SQLite connections contending (device only); `GoogleAuthService` has no seam, so the token rule is a source gate; the first subject-rule failure was never explained. The WinWright DB-drift check reported a false leak because its snapshot ignores the WAL file.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Planned tasks came in at or under estimate (CODING_VELOCITY actuals recorded). The estimate did not include Manual Validation rework, which was most of the effort, and three device tasks (MV74-1, F205, the Task 7 live-deletion check) could not be executed once the AAB was held -- they move to Sprint 75 rather than being counted as done.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The F222 card described the ordering as an implementation ("newest-first, clustered by base domain") and never stated the observable before/after, so plan approval could not catch that it was not what Harold meant. The plan also assumed phone validation inside the sprint; the "no AAB until both PRs merge" decision moved it, which the plan could not have foreseen.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No issues -- expectations met. Opus 5.5 on every top-tier task per Harold's instruction; the independent review agent (Phase 5.1.1) was worth its cost twice. F238 is assigned Fable 5.1 as Harold named.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Questions were numbered and answerable by a digit. One miss: the PR #440 description went stale across two MV rounds until the advisor flagged it. One improvement worth keeping: for Q3 I answered the premise ("shared database") with evidence before building, which avoided building a global lock that would have starved accounts in a Doze batch.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two instructions needed interpretation and I stated each reading for correction: "finds the DB busy ... then starts" (read as one more attempt through the lock, never bypassing it) and "grouped by from email providers" (read as the existing top-of-list group). The F222 intent was the one real miss (see Category 4).

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: ADR-0039 gained two amendments (the lock; the busy retry), ADR-0042 two declared exceptions (export default; YAML save), ARCHITECTURE.md and CHANGELOG kept in the same commits; the unreleased F222 CHANGELOG line was edited in place instead of contradicted. A false code comment was corrected (F208 claimed Android YAML export was verified; the plugin version made that impossible).

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Four tooling defects cost time: (1) the WinWright DB snapshot copies `spam_filter.db` without `-wal`, so a migration looked like a sweep leak; (2) the scratch `mutate.ps1` reads spec files in the system code page and matches line endings literally -- two anchors missed; (3) a span-replacing script did not assert what the span contained and deleted a test; (4) a heredoc-piped Python edit mangled `\n`. A user-visible string also asserted behavior that did not exist: the manual-scan dialog offered "Wait and start" while nothing waited.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Two defects in my own lock code were found before shipping (`reset()` stopping a live scan's heartbeat; a refused scan closing the previous scan's row). The release hold on 0.17.0 is the right call. Residual risk is concentrated in Sprint 75: every phone behavior of 0.17.0 (lock under real Doze batching, the 2-6 minute wait against Android's ~10-minute worker limit, live deletion, Doze/reboot) is unverified on a device.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Ready. F238 (#441) has a full card (R-1..R-6, AC-1..AC-4, T-1..T-4, DB v11, Class-1 interrupt); the Sprint 75 device checklist is written in the plan; F239 (#442) is filed. The dev database was backed up before v10 (`spam_filter.db.pre_v10_20260929_230138`).

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: DB v9 (scan heartbeat) and v10 (subject rules reclassified, data only). The per-account semaphore is documented as the ADR-0039 mechanism, with its unverified assumption (separate SQLite connections per isolate) named. One unused query (`getActiveBackgroundScan`) is kept and noted.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: (a) Sprint 75 Manual Validation device checklist (MV74-1 Doze + reboot, Task 7 AC-2 live deletion, F205 error classification, the lock under a real Doze batch, the 2-6 minute wait vs the ~10-minute worker limit, Android YAML export). (b) WinWright scripts for the new UI with no script yet: Sort chip, "A scan is already running" dialog, Scan History Clear history, "Hide sender details in exports", resolved-default folder rows.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: (a) Body-rule sub-type consistency: quick-add and the default split store body rules as `entire_domain` while manual and imported body rules use `keyword`. (b) Remove or wire `ScanResultStore.getActiveBackgroundScan` (no production caller). F239 (#442) is already filed.

## Completeness Validation Gate (Phase 7.3)

- [x] All 14 categories present
- [x] Each category has all 4 roles
- [x] No placeholder text
- [x] Category 13 carry-ins documented (Claude items; Harold: none)
- [x] Category 14 items tracked for Phase 7.7 (Claude items; Harold: none)

## Summary

Harold rated all twelve assessed categories Very Good, with no carry-ins, no backlog items and no open questions. The sprint delivered all code tasks, F232's cause and fix, and a real per-account scan lock -- the answer to the Fold8's four-scans-at-once finding -- plus six Manual Validation fixes. Three device tasks move to Sprint 75 because 0.17.0 is held for F238. The waste this sprint came from four tooling defects and one card that described an implementation instead of the behavior the user would see; the improvements below target those causes.

## Improvement Recommendations

Completeness walk of Harold's feedback (categories 1-14 and questions): every line is a "Very Good" rating or "none" with no embedded request -- **no actionable item** from Harold's lines. All proposals below come from the Claude Code Development Team lines. Each prevents first and extends an existing mechanism where one exists.

1. **IMP-1 -- Cards that change what a user sees state the observable BEFORE and AFTER.** Source: Cat 4, 7. Type: process. Root cause: the F222 card described an implementation ("newest-first, clustered by base domain"), so approval could not see it differed from Harold's intent; ~60 min of rework. Prevention: add a mandatory "Observable behavior -- before / after" line to the augmented card template (`SPRINT_PLANNING.md`), mandatory when the card changes anything a user sees; it is the requirement echo `feedback_echo_requirements` already asks for, moved into the card Harold approves. Effort: S (15 min). Recommendation: apply now.
2. **IMP-2 -- A user-visible string that claims a behavior is verified like a code comment.** Source: Cat 9. Type: process. Root cause: the dialog button "Wait and start" promised a wait that did not exist. Prevention: extend CLAUDE.md IMP-2 (Sprint 70: a comment asserting a mechanism is verified in the same turn) to button labels, dialog text and toasts. Effort: S (10 min). Recommendation: apply now.
3. **IMP-3 -- The WinWright DB snapshot includes the WAL.** Source: Cat 2, 9. Type: tooling. Root cause: `winwright-db-snapshot.ps1` copies only `spam_filter.db`; an un-checkpointed migration looked like a 32-row sweep leak and failed the run. Prevention: copy `-wal` and `-shm` with the database (SQLite reads them together), and extend its `-SelfTest` with a WAL-only change case. Extends the F79 snapshot guard. Effort: S-M (30 min). Recommendation: apply now.
4. **IMP-4 -- Promote the mutation runner to `scripts/mutation-test.ps1` and fix its two defects.** Source: Cat 1, 9. Type: tooling. Root cause: written twice in this project (`mutate.py`, then `mutate.ps1`); the scratch version read specs in the system code page (a Unicode anchor never matched) and matched line endings literally (a CRLF anchor never matched). Prevention: one repo script with a `.SYNOPSIS`, UTF-8 spec reading, find/replace line endings normalized to the target file, the existing mutation lock, and a restore check. Extends the Sprint 72 IMP-3 promotion rule. Effort: M (45 min). Recommendation: apply now.
5. **IMP-5 -- A script that replaces a span between two anchors asserts what the span contains.** Source: Cat 1. Type: process. Root cause: an end anchor matched one test too far and deleted a neighboring widget test; only an unused-import warning revealed it. Prevention: extend CLAUDE.md IMP-3 ("every mutation script asserts its anchor matched") -- a span replacement also asserts the span's content (e.g. exactly one `testWidgets(`), and the test count before and after is compared. Effort: S (10 min). Recommendation: apply now.
6. **IMP-6 -- Block heredoc-piped Python that contains a backslash.** Source: Cat 1. Type: tooling (new control). Root cause: CLAUDE.md IMP-3 already bans this; it recurred (three times in Sprint 72, once here), writing real line breaks into a Dart string. The rule alone has not prevented it, which is the case for an added control. Proposal: extend the existing PreToolUse Bash guard (the stash-guard pattern) to refuse `python ... <<` commands whose body contains a backslash, with test cases in `.claude/hooks/test-cases/` and the hook suite run. Effort: M (45 min). Recommendation: apply now.
7. **IMP-7 -- Refresh the PR description after every Manual Validation round commit.** Source: Cat 6. Type: process. Root cause: PR #440's body described superseded behavior across two MV rounds. Prevention: add the step to `SPRINT_CHECKLIST.md` Phase 5.3 ("after each MV-round commit: update the PR body"). Effort: S (5 min). Recommendation: apply now.

Category 13 carry-ins (Sprint 75 plan) and Category 14 backlog items are listed in those categories above and are applied in Phase 7.7 regardless of these decisions.

## Improvement Decisions (Harold, 2026-09-29: "now - imp-1, 2, 3, 4, 6")

- **IMP-1 -- APPLY NOW -- DONE.** `SPRINT_PLANNING.md` augmented card template: mandatory "Observable behavior -- before / after" line.
- **IMP-2 -- APPLY NOW -- DONE.** CLAUDE.md IMP-2 (Sprint 70) extended to user-visible text that promises a behavior.
- **IMP-3 -- APPLY NOW -- DONE.** `winwright-db-snapshot.ps1` copies the dev DB with `sqlite3 .backup` (reads through the WAL) instead of `Copy-Item`; self-test Step 8 holds a committed row in the WAL and requires it in the snapshot. Verified: self-test all steps PASS; the old file copy mutated back in (M63) fails Step 8 -- KILLED; a live `-DryRun` snapshot read the running dev DB (3,241 rules).
- **IMP-4 -- APPLY NOW -- DONE.** `scripts/mutation-test.ps1` (UTF-8 specs, target-file line endings, `test` or `command` checks, lock + verified restore). Verified on its first run: M59 (hook disabled), M60 (non-ASCII anchor -- the defect-1 case) and M61 (LF anchor on a CRLF file -- the defect-2 case) all KILLED; a comment-only mutation (M62) reported SURVIVED with exit 1. Listed in CLAUDE.md IMP-3.
- **IMP-6 -- APPLY NOW -- DONE.** `.claude/hooks/block-heredoc-python-backslash.ps1`, registered on the PreToolUse Bash/PowerShell entry; 8 test cases in `test-cases/heredoc-guard/` (5 allow, 3 block); hook suite 83/83; M59 shows the suite catches the hook being disabled. Recorded in CLAUDE.md IMP-3.
- **IMP-5 -- ADD TO BACKLOG** (Harold, 2026-10-02). Filed as F242 in ALL_SPRINTS_MASTER_PLAN.md.
- **IMP-7 -- SKIP** (Harold, 2026-10-02: "imp-7 no"). Reviewed and declined; no change.

## PR #440 Reviews (Phase 7.7.5, 2026-09-29)

- **Copilot** (copilot-pull-request-reviewer[bot]): overview only -- "Findings: None", no inline comments; flagged the size (migrations, cross-isolate locking, live-deletion paths) for human review. Nothing to resolve.
- **Claude code review** (pr-review-toolkit:code-reviewer): 1 IMPORTANT, 3 MINOR -- all FIXED:
  - IMPORTANT: an unchanged Save in the rule editor rewrote a subject/keyword rule as a BODY rule (a regression from the same-day subject-rule label fix). Subject rules now always open in direct-regex mode, which keeps the category. Widget test; M64 KILLED.
  - Re-process now ends its claim BEFORE releasing the lease (a queued manual scan could otherwise be refused by a finished rule update). No seam for a test -- recorded.
  - A redacted export's FILE NAME no longer contains the account address (`acct_` + 10 hex of SHA-256). Test; M66 KILLED.
  - `scripts/mutation-test.ps1` runs the check under a local 'Continue' and pops the location in `finally`, so a failing check writing stderr cannot abort the run.
- **Claude test review** (pr-review-toolkit:pr-test-analyzer): 4 IMPORTANT, 5 MINOR:
  - FIXED: the claim heartbeat now proven to WRITE (M67 KILLED); the toast decision extracted to `describeActionOutcome` and a busy outcome pinned as never-success (M68 KILLED); Windows skip-before-export order gated; the heredoc hook now catches path-prefixed interpreters and piped heredocs (2 violation cases + 1 allow case; hook suite 86/86); the chip filter (not just the count) tested (M70 KILLED); the stale T-1 header corrected (the method is F241).
  - SPRINT 75 CARRY-IN (with the WinWright scripts for the same controls): MINOR 5, 7, 8, 9 -- widget tests for the refusal status row, the OK-only dialog and refusal snackbar, the redaction toggle, and Clear history.
- The new heredoc hook blocked one of MY OWN commands during this round (Python with `\n` piped through a heredoc) -- the control working as intended on the author who asked for it.
- Suite after the round: 2,424 passed / 15 skipped / 0 failed; analyzer clean.
