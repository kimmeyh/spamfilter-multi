# Sprint 76 Summary

**Dates**: 2026-10-04 to 2026-10-06
**Branch**: `feature/20261004_Sprint_76` | **PR**: #455 -> develop
**Version**: 0.17.0+8 -> 0.17.6+14 (six Play closed-test builds, 0.17.1-0.17.6; versionCodes 9-14)
**Suite**: 2,508 -> 2,601 (15 skipped) | Analyzer clean | WinWright 3/3, 85 steps (at `18392ad`) | Hook suite
91 -> 104 | First JVM unit test (5)

## What this sprint was for

Fix the 0.17.0 field issues -- no diagnostics for scans (F248), a background scan that could not be
stopped (F249), and the Gmail double account pick (F250). At Harold's direction (2026-10-05: *"the app
makes no sense if it can't run without the user going to the app"*), it grew into making unattended
Android background scanning work: *"we are ONLY wanting to do the same thing that the email app
currently does - periodically wake up, scan for new emails, update the app and go quit again."*

## Delivered

- **F248 (#452)** -- the diagnostic log records every scan (start, claim, connect, each folder's count and
  path, action plan and results, outcome with duration and already-filed count, why it stopped), sign-in
  and renewal steps, the worker's trigger and delay, and rule-update failures with their reasons.
  Settings shows where it writes, or why it cannot. Cross-isolate lock-file mutex.
- **F249 (#453)** -- cancel checkpoints after connect, at each folder and after the last; the Doze
  one-off uses KEEP (REPLACE cancelled running scans); 5-minute spacing between an account's scans,
  never a skip (Harold's refinement); a scan where every folder failed is a failure and is retried.
- **F250 (#454)** -- the native failure named (`[16] Account reauth failed`); OAuth clients verified;
  Android renewal falls back to the stored refresh token with the Android client -- confirmed on the
  Fold in the foreground, in background workers, and overnight.
- **F251 (#456)** No Rule banner total; **F252 (#457)** "Keep background scans running" battery row and
  wake-to-scan timing; **F253 (#458)** "Scan when new mail arrives" notification listener (ADR-0044,
  package name and post time only, off by default, app-wide).
- **Manual Validation fixes**: Gmail safe-sender move out of Spam; Gmail incremental fetch resolves
  custom label IDs; the scan screen no longer zeroes a running scan's counters; a rule update skips a
  safe sender already in the target; scan-export header row.

## Not delivered, and why

- **Fold checks on 0.17.6** -- moved to Sprint 77 as MV76-1 at Harold's direction: a scan started by a
  notification (F253 AC-5; no mail-app notification fired during the sprint), the reboot half of MV74-1,
  the export header, the rule-update fix, the F250 account state, MV74-3.
- **F250 native sign-in itself** -- the cause is outside the changed code and the OAuth clients match;
  with refresh-token renewal working, whether it still matters is a Sprint 77 question.

## What went right

- Field evidence drove every decision: the 0.17.4 overnight run showed 95 unattended worker starts,
  111/113 completed and 10 spam deletions with the app unopened.
- Both Phase 5.1.1 reviewers found the same HIGH independently (the notification retry trap) before it
  reached a tester. Copilot: Findings None.
- Every fix was mutation-checked (M118-M209).

## What cost time

- The log lock was proven on Windows (per-handle locks) and failed on Android (per-process locks):
  one closed-test build (retro IMP-3).
- A verified AAB was wiped by a later Windows build's `flutter clean` (IMP-1); 0.17.5 was rebuilt after
  its versionCode was already uploaded (IMP-2).
- `git add -A` before `git status` swept a `0*` file into a commit (IMP-4); a `dart format` run
  rewrote 900 lines and was reverted by hand.

## Manual Validation

Fold (Play closed testing, 0.17.1-0.17.5): F248 lines present; F249 stops honored; Gmail renewal by
refresh token PASS; spacing PASS; KEEP no orphaned rows; overnight Doze run PASS (MV74-1 Doze half);
Gmail safe-sender rescue PASS; zero broken log lines on 0.17.5. Windows: WinWright 3/3. Complete per
Harold (2026-10-06).

## Retrospective

Harold: all 14 categories Very Good; four carry-ins (battery A/B deep dive, General-tab placement,
Heuristics/ML/GenAI deep dive, email-content history database); no backlog items; no questions.
Improvements IMP-1, 2, 3, 4, 6 applied (kept AAB in `dist/`, versionCode-reuse gate, OS-primitive rule,
blind-staging hook, "Existing behavior relied on" card line); IMP-5, 7, 8b skipped; IMP-8a/c to backlog
(F256, F257).

## Carry-forward

- **Sprint 77**: MV76-1 and the four retro carry-ins R76-1 to R76-4 (stub: `SPRINT_77_PLAN.md`).
- **Backlog**: F245 (now including the export side), F246, F254, F256, F257, plus F240-F244.
