# Sprint 74 Summary

**Dates**: 2026-09-24 to 2026-09-29
**Branch**: `feature/20260924_Sprint_74` | **PR**: #440 -> develop
**Version**: 0.16.0+7 -> 0.17.0+8 -- **RELEASE HOLD** on both stores until F238 (#441) ships (Harold, 2026-09-27)
**Suite**: 2,314 -> 2,417 | Analyzer clean | WinWright 2/2 (at `46fd173`) | Hook suite 75 -> 83

## What this sprint was for

Settle the device-blocked Sprint 73 carry-ins (MV74-1 Doze, MV74-2 cross-isolate exclusion, MV74-3 a
device run with diagnostic logging), and deliver F202 (per-provider folder defaults), F222 (result
ordering), F206 (exports and scan history), F232 mechanism B and F205 (error classification). Every
task carried ADR-0042: identical on Windows and Android unless it cannot be.

## Delivered

- **MV74-2 -> one scan per account at a time, of ANY type.** A 30-second liveness heartbeat on the
  scan row (DB v9); then, after the Fold8 showed four background scans on one account inside a
  minute, a per-account semaphore in the database (`ScanResultStore.claimAccountScan`): one
  `BEGIN IMMEDIATE` transaction that closes dead holders (heartbeat > 5 min or age > 30 min),
  refuses if anything holds the account, else inserts. Fail closed. Manual, demo, background and
  re-processing all take it. A timed-out scan now stops (revoked lease). A busy background scan
  waits a random 2-6 minutes and tries once more (replacing the Windows-only 15 x 1-minute retry).
- **F232 mechanism B -- fixed.** The Fold8 log read `Platform  not supported`: Scan History split
  the accountId on a dash and got an empty platform, so every rule added from a saved scan failed.
- **F222 -- reworked at Manual Validation.** Default order folder -> domain -> address kept; a Sort
  chip switches to newest first; each row shows its received date (the pop-up shows date and time);
  Gmail emails carry their real received date.
- **F202** -- new accounts start with their provider's folders for all four folder settings;
  a missing folder is skipped, not an error.
- **F206** -- exports go to Downloads (Windows) / Documents (Android), off by default after each
  scan, optional redaction, Clear history; Android YAML export fixed (file_picker needs the bytes).
- **Also from Manual Validation**: the Results screen shows the address once; Gmail keeps its
  sign-in when a renewal fails (no more "Missing credentials"); rule taps are written to the
  diagnostic log; subject rules are labeled "Keyword" (DB v10) and the Header / From chips count
  header rules only.

## Not delivered, and why

- **MV74-1 (Doze + reboot), F205 (error classification), the Task 7 live-deletion check, the lock
  under real Doze batching, Android YAML export** -- all need a 0.17.0 phone build, and Harold ruled
  no AAB until both the Sprint 74 and Sprint 75 PRs merge. They are Sprint 75 Manual Validation.
- **The cause of the four-at-once background burst** -- not established. Each account has exactly
  one Doze alarm, so duplicate alarms are unlikely; the lock prevents the harm whichever trigger
  fired.
- **Why the first subject-rule tap saved nothing** -- not established; rule creation now logs
  requested / saved / not saved, so a repeat leaves evidence.

## What went right

- **The log named the cause.** Turning on the diagnostic log in Sprint 73 (F233) paid off: one line
  settled F232 mechanism B, which had been open for two sprints.
- **Asking before building.** Harold's Q3 answer ("one scan across all accounts ... shared db,
  right?") was answered with evidence first; the per-account lock plus a jittered retry replaced a
  global lock that would have skipped all but one account in every Doze batch.
- **Reviews and self-checks found real defects before shipping**: a live scan's heartbeat stopped
  by `reset()`, a refused scan able to close the previous row, a timed-out scan that kept running,
  a database error counted as success.

## What cost time

- F222 built to the card's implementation text, not the intent (retro IMP-1).
- Tooling: a script deleted a neighboring test; a heredoc mangled a `\n`; the mutation helper missed
  non-ASCII and CRLF anchors; the WinWright snapshot ignored the WAL and reported a false leak
  (retro IMP-3, IMP-4, IMP-6).

## Manual Validation

Windows: all steps PASS across five rounds (lock dialog, Sort chip, row dates, single address line,
Scan History rule adds, YAML export, subject rule). Phone: the 0.16.0 run on the Fold8 produced the
findings; 0.17.0 phone checks moved to Sprint 75.

## Retrospective

Harold: all categories Very Good; no carry-ins, no backlog items, no questions. Claude: Category 13
carry-ins (device checklist; WinWright scripts for new UI) and Category 14 backlog (F240 body-rule
sub-types, F241 unused query). Improvements applied: IMP-1 (card before/after line), IMP-2 (verify
UI text that promises a behavior), IMP-3 (snapshot via `.backup`), IMP-4 (`scripts/mutation-test.ps1`),
IMP-6 (heredoc-backslash hook). IMP-5 and IMP-7: no decision given.

## Carry-forward

- **Sprint 75**: F238 (#441, Fable 5.1) -- "Stop the background scan and start mine", RELEASE
  BLOCKER for 0.17.0, DB v11. Plus the device checklist above. Stub: `SPRINT_75_PLAN.md`.
- **Backlog**: F239 (#442) Gmail headless renewal + "Sign In Again"; F240; F241.
