# Sprint 82 Plan -- STUB (carry-ins from Sprint 81)

**Status**: STUB, not approved. Scope is selected at Phase 8.4 (Backlog Refinement pass 2) and planned at
Phase 3; this stub only records what Sprint 81 carried in.

## Start of sprint

- **0.22.0 store updates** -- the Microsoft Store MSIX and the Google Play closed-test AAB for 0.22.0+19 (Phase 8.3
  of the Sprint 81 cycle). Also confirm 0.21.0 is live on both stores (installed 2026-10-24 per Harold).
- **MV-2: the Fold diagnostics line** (F303 AC-3, Harold: *"bring this back up in the next sprint"*) -- after the
  0.22.0 closed-test update on the Fold, pull the diagnostic log; its `[new-mail-diagnostics]` line lists every field
  with no `error:` text. Read the first start after the update AND a later start (Sprint 80 retro IMP-5).
- **iOS Part A (F67a, #509, and F304 signing + TestFlight, #510)** -- moved here by Harold 2026-10-26. The Apple
  Account could not be created on the web ("Your account cannot be created at this time", several attempts
  2026-10-26/27, a generic Apple refusal). Harold 2026-10-27: enroll with his EXISTING Apple ID (the iCloud test
  email account), so no new account is needed. Walk `docs/IOS_SETUP.md` Parts A-D one at a time, waiting for each
  (Harold 2026-10-25), starting at Part A step 2 (enrollment).

## Carry-ins from the Sprint 81 retrospective

- Category 13: none from Harold or Claude.
- **IMP-1 (live)**: a failure the user should know about names the screen and the exact text; the diagnostic log is
  evidence for Claude, not visibility for the user.
- **IMP-2 (live)**: a new signal, chip, badge or warning has a "Signal fires on" line counted on DEV data.
- **IMP-3 (live)**: the catch walk (every catch between a new throw and its handler) is a card line.
- **IMP-4 (live)**: the F302 gate reviews every `int.parse` / `int.tryParse` in `lib/` by its call text.
- **IMP-5 (live)**: a test must be able to fail (`TESTING_STRATEGY.md`).
- **IMP-7 (live)**: a question about a review finding carries its evidence and every practical option.
- **Standing fact (Harold)**: Fold notification access for the app is ON and stays on.

## Targeted at Sprint 82 (backlog cards, Harold 2026-10-25/26)

- **F306** one suggested safe-sender or block rule in the No Rule pop-up, with the two TLD replacement ideas; with
  **F312** (count emails with two or more Authentication-Results headers first).
- **F314** Gmail history cursor saved before the fetched mail is evaluated (7.7.1 SF M-6, pre-existing).
- **F315** count IMAP messages that arrive with no UID; design a date cursor only if any occur.
- **F317** keep delegated agent work safe across usage limits; restart where it stopped.
- **F318** the 7.7.1 toolkit review prompt lists every changed file (retro IMP-6).
- **WinWright coverage of No Rule Review** (Sprint 81 5.1.5 gap).

## Open items carried

- **Known limit (7.7.1 improvement review L-3)**: the missing-folder line could show on Results opened for a
  different account while the provider still holds another account's scan. Pre-existing, unverified; named in
  `results_display_missing_folder_test.dart`.

Details: `docs/ALL_SPRINTS_MASTER_PLAN.md` (F306, F312, F314-F318, F67a, F304 and the backlog).
