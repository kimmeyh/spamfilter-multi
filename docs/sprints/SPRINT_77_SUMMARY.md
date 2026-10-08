# Sprint 77 Summary

**Dates**: 2026-10-06 to 2026-10-08
**Branch**: `feature/20261006_Sprint_77` | **PR**: #460 -> develop
**Version**: 0.18.0+15 (bumped at plan approval; no store upload this sprint -- MV-Q7 = 2)
**Suite**: 2,607 -> 2,918 (15 skipped) | Analyzer clean | JVM 21/21 | WinWright 2/3 at `4a5f2ac` (mt2c
display-size dependent, see below) | Hook suite 121 -> 125

## What this sprint was for

Close the phone checks on 0.17.6. Make background scanning configurable per account (interval and the
new-mail trigger) and measure its battery cost. Fix the two largest data defects: Gmail custom-label moves
and duplicate No Rule rows. Open the app to any IMAP server with a defined security posture. Research
content-based spam identification. Every card had to state Windows + Android parity, or declare an
ADR-0042 exception (Harold, 2026-10-06).

## Delivered

- **MV76-1 (#461, with #433 F205 and #428 MV74-1)** -- Fold checks on 0.17.6. Unattended background scans
  ran through a reboot with the app unopened, and Gmail renewed by refresh token.
- **F258 (#462)** -- Gmail moves and deletes to a user label send the label ID. A missing label leaves the
  email in place and names the label.
- **F245 (#463)** -- one No Rule row per email (identity upsert, DB v12, ADR-0045). 7,904 -> 583 rows on
  the dev DB. The export lists an unaddressed email once.
- **R76-1 (#464)** -- battery A/B arms 1-5 on the emulator. A debug-only shell notification hook is gated
  out of release builds.
- **F264 + R76-2 (#465)** -- per-account "Scan every" (Minutes/Hours, 1-99, minimum 5) and a per-account
  "Scan when new mail arrives". Fixed: 2h/4h scheduled nothing; the Windows restart reset intervals to
  15 minutes; task repair guessed the interval; the Android alarm rounded up.
- **F192 + SEC-15 (#466)** -- Custom IMAP Server with host validation (`ImapHostPolicy`).
- **SEC-8b (#467)** -- trust-on-first-use for Custom IMAP certificates (ADR-0046). The Google OAuth pin
  now checks every connection (it was inert before).
- **R76-3 (#468)** -- research on heuristics, ML and GenAI spam identification; backlog F266-F275.
- **Manual Validation additions**:
  - F266: 23 bundled safe senders that could never match; DB v13 repair.
  - Fixed 1-minute Windows start stagger per saved slot (ADR-0039 amended).
  - Re-adding a saved address asks before replacing its sign-in details.
  - "App Password" vs "Password" labels.
  - A refused IMAP LOGIN says "Sign-in failed" on every IMAP provider and counts toward the sign-in limit.
  - The diagnostic log records No Rule removals and reappearances.
  - A new account's first scan shows its results.
  - `scripts/enable-crash-dumps.ps1`.

## Not delivered, and why

- **Fold steps 7-11 and the 0.18.0 Store and Play updates** -- moved to the start of Sprint 78 by the
  Scrum Master (MV-Q7 = 2), so every Sprint 77 change ships in one update.
- **R76-1 arm 6** -- needs a Kotlin constant change; recorded with backlog F277-F280.
- **No Rule rows for mail deleted or moved in the mail client** -- there is no reliable "gone" signal
  (F276).

## What went right

- Planned work came in far under estimate: about 500 minutes for the planned task rows against
  917-1,615.
- The F-PRECHECK pass found 1 HIGH and 7 MEDIUM before validation; 9 of 10 were fixed, 15/15 mutants
  KILLED.
- Manual Validation found long-standing defects that tests had missed (the IMAP "check your internet"
  message, the 23 dead safe senders, silent account replacement).
- The DB v12 and v13 migrations ran on hash-verified backups of real data.

## What cost time

- Three handed-over validation steps were wrong (the GreenMail user, a 1-day rescan the backlog cursor
  ignores, a count of 5 that was 6) -> retro IMP-1 (rehearse every step).
- The WinWright mt2c investigation ran three rounds and ended display-dependent (~120 minutes).
- Unplanned work, about 460 minutes, roughly equal to the planned work, as in Sprint 76.

## Manual Validation

Windows: steps 1, 2, 3a-c and 5-10 PASS; step 4 N/A (App Password Gmail); the step 2 on-screen check
skipped by Harold (MV-Q22). OPEN: one 0xc0000409 crash on opening Review No Rule Items (cause unknown,
not reproduced; full local dumps enabled). WinWright at `4a5f2ac`: f124 29/29 and s75 27/27 PASS;
mt2c fails at ~1940x1040 because the seed rows sit below 11 pinned provider rows (it passed 30/30 at
3856x2128); not an app defect; folded into F283. Complete per Harold (2026-10-08).

## Retrospective

Harold: all 14 categories Very Good; no carry-ins, no backlog items, no questions.
- IMP-1 applied (Phase 5.1.9 rehearsal of every MV step: Flutter tests first, WinWright batched with
  the sweep; gated from Sprint 78).
- IMP-3 applied (`Executed-by` lines filled; close-out check 3d-3).
- IMP-4 waits for the crash to recur.
- IMP-2 (WinWright without screen takeover): see the retrospective's Improvement Decisions.

## Carry-forward

- **Sprint 78 start**: the 0.18.0 Microsoft Store and Google Play updates; Fold steps 7-11; trace the
  boot-time `main()` start (MV76-1 step 11).
- **Backlog**: F276, F277-F280, F281, F282 (one MyEmailSpamFilter folder under Documents, priority 7),
  F283 (Review No Rule Items on the Results layout, priority 8), F267-F275, F265 (HOLD).
