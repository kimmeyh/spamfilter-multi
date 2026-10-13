# Sprint 78 Summary

**Dates**: 2026-10-09 to 2026-10-13
**Branch**: `feature/20261009_Sprint_78` | **PR**: #470 -> develop
**Version**: 0.19.0+16 (bumped at plan approval)
**Suite**: 2,918 -> 3,011 (15 skipped) | Analyzer clean | WinWright 2/2 at `82a35db` | Hook suite 125 -> 132

## What this sprint was for

Finish the phone checks on the 0.18.0 closed-test build and measure the battery cost of a 5-minute interval.
Put every file the app writes for the user in one `MyEmailSpamFilter` folder. Make Review No Rule Items work
like the Results screen. Take most of the WinWright sweep off the mouse. Redesign the "Scan every" control from
researched practice. Start a content history of Harold's own four mailboxes for future heuristics, ML and GenAI
work. Every card stated Windows + Android parity or declared an ADR-0042 exception.

## Delivered

- **F282 (#473)** -- one `MyEmailSpamFilter` folder in Documents for every file the app writes for the user, on
  both platforms. A folder the user chose stays exactly as chosen.
- **F281 (#478)** -- "Scan every" is a preset drop-down (5, 10, 15, 30 minutes; 1, 2, 4, 12, 24 hours) plus
  Custom, with a 24-hour maximum. It shows only when background scanning is on. Research in the repo.
- **F283 (#475)** -- Review No Rule Items is built on the Results screen's list pieces and pop-up: search, sort,
  account drop-down, the account named in the pop-up, Skip. Multi-select is removed.
- **F284 (#474)** -- the Settings tabs and the Review account face are invokable buttons; mt2c retired; fixed
  window size; the runner fails a script with any skipped step. Six mouse steps remain (backlog F289).
- **R76-4 (#476)** -- content history of Harold's own mailboxes, in dev builds only (ADR-0047 Accepted), with a
  switch and a delete control on Settings > General.
- **F199-b (#477)** -- repo records match Partner Center (`Kimmey Consulting - Ohio`); card to HOLD.
- **Manual Validation fixes**:
  - MV-1: the pop-up subject, date/account row and Skip button use the theme text color.
  - MV-2: for a shared email-provider sender the four domain actions are dimmed but still tappable.
  - MV-3: creating a rule no longer blanks Review No Rule Items (`RulesReadyGate`: the startup loading screen
    shows only before the first load).
  - MV-4: both search fields have readable text (shared `ResultSearchField`).
  - MV-6: a failed scan records `completed_at`, so Scan History stops showing "In progress".
  - MV-7: the Android Doze alarm skips an account scanned within two-thirds of its interval (ADR-0039 amended).
  - MV-5 withdrawn: stale Review rows leave through the 90-day retention setting.

## Not delivered, and why

- **Fold steps 8-11, the F277 battery runs, MV-7 on the phone, Android parity of F281/F282/F283** -- moved to
  Sprint 79 by Harold (2026-10-13: "push any further testing to next sprint"). The 0.18.0 F277 run had three
  accounts on, so it does not count.

## What went right

- All four Windows validation steps passed on the first try: the first sprint under the 5.1.9 rehearsal rule.
- Every mutation was KILLED, including the seven Manual Validation fixes.
- The new phone-log health check found a defect nobody had seen: 10 AOL scans on Oct 10-12 died mid-scan.

## What cost time

- No effort actuals were recorded at task completion; they were rebuilt from commit times (retro IMP-1).
- MV-7 and MV-6 sat in pulled phone logs for days before anyone read them for scan health (retro IMP-2).
- The first re-sweep failed on a selector that depended on which kind of scan was newest in Scan History.

## Manual Validation

Windows: W1-W4 PASS; the W3 re-check after MV-1/2/4 PASS. Fold: iCloud background is off (no scheduled
iCloud scans, correct); no new-mail trigger yet (Step 9 needs Notification access). Complete per Harold
(2026-10-13).

## Retrospective

Harold: all 14 categories Very Good; no carry-ins, no backlog items, no questions.
- IMP-1 applied: CODING_VELOCITY rows required at the Manual Validation boundary from Sprint 79; minutes required
  on every `Executed-by` line.
- IMP-2 applied: `scripts/phone-log-health.ps1`, run by every phone pull.
- IMP-4 applied: the contrast gate fails on pinned black text; it found and fixed the dark-mode Rule Test
  highlight.
- IMP-3 skipped (Harold).

## Carry-forward

- **Sprint 79 start**: Fold steps 8-11; F277 on 0.19.0 with one account on; MV-7 on the phone; the Gmail
  `invalid_grant` cause; Android parity of F281/F282/F283; the 10 AOL scans that died mid-scan.
- **Backlog**: F286 and F288 (target Sprint 79), F287, F289, F276-F280, F267-F275.
