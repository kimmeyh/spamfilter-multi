# Sprint 73 Summary

**Dates**: 2026-09-22 to 2026-09-23
**Branch**: `feature/20260922_Sprint_73` | **PR**: #435 -> develop
**Version**: 0.15.3+6 -> 0.16.0+7
**Suite**: 2,233 -> 2,305 | Analyzer clean | WinWright 2/2

---

## What this sprint was for

Act on what Harold's Sprint 72 device testing exposed: background scans that did not fire while
the phone was idle, a read-only account that refused silently instead of showing what a rule would
do, a scan with no way out, and a version that was invisible on exactly the screenshots used to
diagnose all of it.

## Delivered

- **F235** -- Android background scans now fire in Doze. The R-1 gate ran first and removed the
  whole policy risk: `setAndAllowWhileIdle()` needs **no permission**, where both exact variants
  carry a Google Play justification burden. Cost recorded rather than buried: a ~1 hour delivery
  window, which at the 15-minute setting is 4x the interval but strictly better than scans that
  frequently did not fire at all.
- **F234** -- read-only became a **rehearsal instead of a refusal**. Adding a rule on a read-only
  account now reports what it WOULD have filed or moved, mailbox untouched. Most valuable on
  Windows, which is configured read-only and therefore could never see a rule's effect.
- **F224 + F207** -- a running scan can be cancelled, from **both** surfaces a user reaches it
  from, and a dead background scan no longer produces a stale warning with a false wait estimate.
- **F229** -- the app version now appears on every screen at phone width, so a phone screenshot
  identifies its own build.
- **F226** -- the WinWright sweep warns before it drives the app and retries once, visibly.

## Not delivered, and why

- **Task 2 (F232 mechanism B)** and **Task 7 (F205)** need a device run with diagnostic logging
  enabled. Parked, not dropped.
- **MV step 6 (F235 on real hardware)** waits on the S24+ download. The Doze behaviour and reboot
  survival are the only evidence that matters and no unit test can supply it.

---

## The sprint's defining event: two CRITICAL defects, both inert features, both with green suites

The Phase 5.1 reviews -- one code, one test-coverage, run independently -- found **the same two
defects**, and both were mine, committed hours earlier.

- **F234's preview could never report anything but zero.** The read-only path forced
  `ScanMode.readOnly` into gates that match only the three ACTING modes, so both collection lists
  stayed empty, the `isEmpty` guard returned `nothingToDo()` first, and the preview block was
  unreachable. **The feature was inert from its first commit.**
- **F224's cancel did nothing on every real IMAP account.** I found and fixed the scanner's
  per-folder `catch (e, st)` and wrote a commit message about how easily it would have shipped.
  An identical swallow sat one layer below in the adapter, where `_fetchMessageDetails` awaits the
  scanner's `batchSink` from inside the adapter's own try. Gmail and demo worked; IMAP did not.
  Worse than "cancel does nothing": the flag stayed set, so every remaining folder was swallowed
  too and returned zero messages, and the scan then "completed" reporting a near-empty mailbox.

**One shared cause: verification by SOURCE TEXT rather than behaviour.** F234 is the second
occurrence on the same card in the same sprint -- the first was closed with a test named
"THE MUTATION GAP" that greps for a string which was still present while the bug moved 30 lines
upstream. A source gate proves a symbol EXISTS; it cannot prove a branch is TAKEN.

**And the first fix was not enough.** After extracting `classifyForReProcess` and testing it
properly, I re-ran the mutation and it SURVIVED -- the pure function was correct, the CALL SITE
was untested. "Correct abstraction, wrong wiring", found only by mutating again instead of
trusting that extracting-and-testing had settled it.

---

## What went right, and it is mostly "measure, do not argue"

- **F229's probe falsified the card's own premise before anything was built.** At 411px the six
  AppBar icons need 288px of a 283px budget -- over before any text exists. Removing "Select
  Account" (Harold's own suggested trade, which he had explicitly authorised) frees 43px against a
  120px need. So the trade was **recommended against and not spent**, on arithmetic.
- **F224's R-1 collapsed the design.** The card reserved a Class-1 escalation for threading a
  cancellation token; `scanInbox`'s existing `finally` already released the lease AND disconnected
  the session on every path including a throw, so cancellation became a throw at one funnel.
- **R-2 falsified all three causes the F207 card proposed.** The warning is a DATABASE row, not a
  lease -- and the blocker and its reconciler share one 30-minute constant, so the reconciler could
  never shorten the block.
- **Nothing was invented where a sibling existed.** F229 mirrors `SystemInsetWrapper` (F209),
  including its exempt-needs-a-reason rule; F224 extended `ScanCoordinator` and reused the existing
  `interrupted` status rather than adding an enum value that would have changed a stored value's
  meaning.
- **Two verification disciplines paid for themselves.** The F229 wiring script was genuinely broken
  -- it computed offsets against a comment-stripped copy and applied them to the original, landing
  inside a doc comment -- and the one-file dry run turned a 22-file corrupted commit into a
  five-minute fix. A second defect, a CRLF-blind import regex, was stopped by its own assert.

## Harold's corrections, which beat my analysis twice

- **"Do the WinWright failures occur when the laptop is locked?"** Yes, by documented design.
  Microsoft's `SetCursorPos` requires the caller to be on the current input desktop; locking
  switches that to `Winlogon`. The tell was in my own logs -- `ww_invoke` and tree reads passed
  while every `ww_click` failed -- and I had recorded that split twice without asking what produces
  it. I first called it an unrecoverable environmental block, then "transient", which is the worse
  answer because it names the observation and supplies no cause.
- **"Background scan is read-only so the other 6 are from prior block rules."** I had written "7
  delete-rule matches" without saying WHEN they matched, letting a pre-existing total read as the
  session's output. The 09:03 baseline row was in the same screenshot set: Deleted 6 -> 7, No Rule
  2 -> 1, which is the same +1 the preview reported. **The baseline was available and I did not
  take it.**

## Manual Validation

Steps 1-5 PASS on Windows 0.16.0 dev. F234 reported "Preview only: 1 would have been filed" --
**the count being 1 rather than 0 is the runtime proof the fix landed**. F224 validated on both
surfaces, with "Scan cancelled. 1 of 34 emails had been checked" and a clean immediate re-scan
(3s, Errors 0) proving no session leak. Step 6 awaits the S24+.

F229 was additionally verified on the RUNNING app via WinWright: at 500px the body line resolves
visible at `y=189, height=15`; at 1300px it resolves 0 while the AppBar label resolves 1. Exactly
one surface at any width, confirmed live in both directions.

## Carry-forward

Seven accepted review findings are recorded in `SPRINT_73_PLAN.md` rather than left in a
transcript. The sharpest: **F207's Android suppression may rest on a false mechanism claim.** If
the WorkManager scan runs in its own isolate, the coordinator reads idle while a scan is genuinely
live and the fix would hide a real warning. I could not settle it from source and said so rather
than recording a determination I cannot support. The Windows branch is unaffected and correctly
justified.
