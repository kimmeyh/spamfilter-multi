# Sprint 85 Plan -- STUB (carry-ins from Sprint 84)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 84 carried in.

## Start of sprint

- **0.24.1 store updates** (Phase 8.3 of the Sprint 84 cycle) -- the Microsoft Store MSIX and the Google Play
  closed-test AAB for 0.24.1+22 (`docs/store-assets/RELEASE_NOTES_0.24.1_*.md`, re-derived 2026-11-07 at 7.7.1).
  Build from HEAD of `main` after the merge. Serialize the Windows and Android builds.
- **F342 Fold check after 0.24.1** -- once the Fold shows 0.24.1 (Settings top bar "Version 0.24.1"), pull the
  diagnostic log over MTP (`scripts/pull-phone-screenshots.ps1`) and check: a scan stopped by Android shows the
  F342 reason in Scan History, and the next background scan starts. The result decides F357 (Harold: q1 = c,
  q2 = a).
- **Emulator ANR (F355)** -- Harold reboots before this sprint (2026-11-07: "push it to next sprint and I will
  reboot before then").

## Manual Validation carried from Sprint 84 (Harold, 2026-11-07, q1 = a)

- **MV-3c (MV-5, Fold, YELLOW item)**: when a YELLOW No Rule item appears on the Fold, open its pop-up. Expected: one
  rule is marked "Suggested", and Block Subject, the regex note and the Skip row fit the cover screen with no
  clipping. Until then it is not testable (Harold: "Don't currently have any yellow no rule items").
- **iPhone (F67a #509, F304 #510, F67b #523)**: waits on Apple's approval of enrollment `R6QG2A9SHS` (stopping
  criterion 2).

## Carry-ins from the Sprint 84 retrospective

- Category 13: none (Harold); Claude: none beyond the carry-ins below.
- **i3 (live)**: a card that ports, rewrites or translates existing code has a "Port of existing code" line: the
  original is reviewed for defects first, each with file:line and whether the port fixes or keeps it; failure-path
  cases come from the spec, not from the original.
- **i4 (live)**: a card that moves, renames, replaces or retires a file, command, setting or name has an "Old name
  search" line: every repo hit (docs, CLAUDE.md, settings, scripts, `.codex/`) is updated or kept with a reason.
- **i5 (live)**: 5.1.9 lists each new guard test with its mutation verdict.
- **i6 (live)**: 5.1.2 class 1 searches nested forms of a code shape (multiline grep).
- **i1, i7 (tracked)**: propose again if class A text recurs in the 7.7.1 reviews, or a first-run attempt is wasted
  by a stored item that was missed.
- **i2 and q3**: in F329 (the fault-injection test for every hook; the live check of how a hook notice looks).

## Backlog created in Sprint 84 (for Phase 8.4 scope selection)

F341 remainder (live first-run checks 2, 6, 9 and the iOS screens); F346 device state on a WorkManager stop; F347
IMAP connect timeout phase; F348 stale sprint62_surfaces tests; F349 Task Scheduler test timeouts; F350 risk-based
test analysis (Priority 10); F351 AppBar icons on narrow phones; F352 default email account (Priority 12,
ADR-0052); F353 empty states on a short screen; F354 DEV credentials folder (Priority 14); F355 Android ANR on
enabling background scans (Priority 16); F356 Android first-run polish; F357 `interrupted` rows.
