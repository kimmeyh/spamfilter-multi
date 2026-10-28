# Sprint 81 Summary

**Dates**: 2026-10-23 to 2026-10-27
**Branch**: `feature/20261023_Sprint_81` | **PR**: #507 -> develop
**Version**: 0.22.0+19 (bumped at plan approval; MINOR, F271 is a user-facing `feat`)
**Suite**: 3,204 -> 3,287 passed (15 skipped, 0 failed) at `c262b0ee` | Analyzer clean | WinWright 2/2 at `bc4676de`

## What this sprint was for

Start the iPhone app: Apple prerequisites (F67a), a signed build pipeline to TestFlight (F304) and the iOS project
with its platform answers (F67b). Fix three data defects: an IMAP sequence number stored as a UID (F302), a missing
Gmail label that failed silently, with one history cursor shared by every folder (F259), and Android diagnostics that
failed as one block (F303). Make the Gmail 7-day sign-in expiry visible (F301), explain No Rule rows with reason
chips and a "Create rule" button (F271), and close three investigations (F278, F300, IMP-2b). Every card stated
Windows + Android parity or declared an exception (ADR-0042).

## Delivered

- **F67b (#511)** -- the iOS project, Info.plist, AppDelegate and the `PlatformCapabilities` iOS answers; an unsigned
  `flutter build ios --release --no-codesign` is green on `macos-26` (run 40012148625).
- **F302 (#512)** -- a message with no valid IMAP UID is marked with one constant and never acted on by sequence
  number; schema v14; a policy test reviews every `int.parse` / `int.tryParse` in `lib/` by its call text.
- **F303 (#513)** -- each Android new-mail diagnostic field is read on its own, so one failure no longer hides the rest.
- **F259 (#514)** -- the Gmail history cursor is kept per account and folder (schema v15); a missing folder or label
  shows "Folder not found: <name>" on the Results screen.
- **F301 (#515)** -- ADR-0029 Phase 1 kept and made visible: a "Gmail sign-in needed" notification, once a day per
  account, retried after 1 hour if it fails to post.
- **F271 (#516)** -- No Rule rows carry stored reason codes (schema v16) shown as chips, and a "Create rule" button;
  the "Blocked TLD" chip was removed at 7.7.1 (it could fire only for a disabled rule).
- **F278 (#517)** -- 10 of 10 notifications produced a scan; the drop did not reproduce. A split diagnostic log was
  found and fixed.
- **F300 (#518)** -- the WinWright sweep is timed per script (62-70 s).
- **IMP-2b (#519)** -- the background build that stayed open was the adb server inheriting the script's handles;
  `Start-AdbServerDetached` fixes it.
- **Version (#508)** -- 0.22.0+19.
- **Found by the 7.7.1 full suite** -- the diagnostic log lost lines under load when several isolates wrote at once
  (the no-lock retries ran back to back); fixed in `c262b0ee`.

## Not delivered, and why

- **F67a (#509) and the F304 signing and TestFlight part (#510)** -- moved to Sprint 82 by Harold (*"move to next
  sprint"*, 2026-10-26). The walkthroughs (`docs/IOS_SETUP.md`) and the unsigned compile job are done; the Apple
  Account could not be created ("Your account cannot be created at this time", several attempts 2026-10-26/27);
  Harold will enroll with his existing Apple ID (the iCloud test email account) instead.
- **MV-2 (Fold diagnostics line)** -- moved to Sprint 82 by Harold (*"bring this back up in the next sprint"*); the
  Fold had 0.21.0 during Manual Validation.

## What went right

- Tasks 3-8 ran as parallel Sonnet sub-agents (Task 8 in its own worktree); every new test was mutation-verified.
- 11 of 12 task rows finished inside or under their estimates (Task 11 over: 35 against 15-30, a scope addition);
  Tasks 3, 4, 5, 6 and 8 were far under.
- The 7.7.1 reviews ran before the retrospective for the first time, so the retrospective worked from finding classes
  (A-G) and six of seven improvements were applied the same day.

## What cost time

- Six 7.7.1 findings were failures that reached only the opt-in log while a card promised "visible" (class A; IMP-1).
- The "Blocked TLD" chip shipped with text that its own MV note contradicted (class B; IMP-2).
- Four 7.7.1 decision questions came back for more detail and more options (IMP-7).
- The improvement review found the first "Folder not found" fix hidden in the very case it exists for (fixed in
  `2ae82a26`), and the full suite found a pre-existing log-lock race (fixed in `c262b0ee`).

## Manual Validation

Windows DEV 0.22.0: MV-1 PASS (the "Create rule" button shows; the No Rule pop-up unchanged) with Harold's direction
for one suggested rule in that pop-up -> F306, and removal of the Create rule page in Sprint 86 -> F307. MV-2 moved
to Sprint 82. MV-3 "OK" (not on demand). F305 and F308-F313 added to the backlog from the MV-1 discussion. Complete
per Harold.

## Retrospective

Harold: categories 1-12 Very Good; none for 13, 14 and questions.
- IMP-1 applied: a failure the user should know about names the screen and the text (CLAUDE.md, 5.1.2 question).
- IMP-2 applied: a new signal states what makes it fire, counted on DEV data (card "Signal fires on" line).
- IMP-3 applied: the catch walk is a card line. IMP-4 applied: the F302 gate matches the operation.
- IMP-5 applied: "A test must be able to fail" (TESTING_STRATEGY.md). IMP-6 -> F318 (Sprint 82).
- IMP-7 applied: a question about a finding carries its evidence and every practical option.
- 7.7.1 final code reviews, improvement review and CI: see `SPRINT_81_PLAN.md` "Phase 7 evidence".

## Carry-forward

- **Sprint 82**: F67a/F304 remainder (Apple Account, enrollment, signing, TestFlight), F306 with the TLD ideas and
  F312, F314 (Gmail cursor saved before evaluation), F315, F317, F318, MV-2 Fold diagnostics line, WinWright coverage
  of No Rule Review.
- **Backlog**: F305, F307 (Sprint 86), F308-F311, F313, F316.
