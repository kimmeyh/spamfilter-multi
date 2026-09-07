# Sprint 65 Summary

**Dates**: 2026-09-04 to 2026-09-07
**Branch**: `feature/20260904_Sprint_65` | **PR**: #385 -> develop
**Scope**: GP-10 (Data safety, Issue #380), GP-18 (App content + App access, Issue #381),
GP-7 (adaptive icons, Issue #382), GP-6 (listing copy + assets, Issue #383), GP-17
(closed-test roster, Issue #384). Five tasks, selected by Harold at Phase 8.4 as "all of it".

**Theme**: everything Google Play requires BEFORE the 14-day closed-test clock can start.

## The question that shaped the sprint

At refinement Harold asked: *"does the list include known timing dependencies that should
drive the order these are completed to get onto the Google Play store as quickly as
reasonably possible?"*

It did not. My slate was ordered by BUILD dependency -- only GP-6 needed GP-7's icon, a few
hours of coupling -- while the calendar was governed by the 12-tester / 14-continuous-day
closed test that gates production for a personal developer account.

**My first correction was also wrong.** I proposed starting the clock first and doing the
listing work during the 14-day wait. Verified research against Google's own documentation
overturned it: closed testing sits behind the SAME "complete app setup" wall as production.
Only internal testing skips setup, and internal-test days earn zero credit toward the 12/14.
So the rollout is genuinely last, and there is no way to start the clock early.

That research paid for itself twice. It also surfaced **App access** -- a Play requirement
nothing in the project tracked. A spam filter demonstrates nothing without a working email
account, so a reviewer cannot exercise the core flow unaided. Registered as GP-18; without
it, this would have been discovered as a blocker mid-rollout.

## What Shipped

- **GP-10**: Play Data safety declarations recorded WITH their code evidence -- every answer
  traced to a real persistence path rather than asserted. Confirmed no analytics, crash, or
  advertising SDK exists anywhere, nothing is shared, and stored message content is limited
  to sender, subject, folder, and a body preview capped at 100 characters (enforced at the
  write boundary, so a caller cannot bypass it). Zero contradictions with the published
  privacy policy.
- **GP-18**: every App content declaration answered, plus reviewer access. **Decision: Demo
  Mode, not a test account.** The agent verified rather than accepted my preliminary read
  and found the path sturdier than assumed -- `EmailScanner` special-cases `platformId ==
  'demo'` to use Demo Mode's own rule set, so it works on a completely fresh install with no
  seeded rules. No live credential is ever created, which removes an entire leak class.
- **GP-7**: **audit-first paid off.** The adaptive icon config and all five densities were
  ALREADY correct, so nothing was regenerated -- the same shape as Sprint 64's GP-8. Only
  the 512x512 listing icon was genuinely produced (verified: no alpha channel, which Play
  rejects at upload).
- **GP-6**: listing copy master (short description 78/80, full 2694/4000, both MEASURED not
  trusted), asset capture specification, and a cross-store claim comparison.
- **GP-17**: tester roster distinguishing CONFIRMED opt-in from invitation -- only a
  completed opt-in starts a tester's clock -- and computing the earliest application date
  from the LAST tester rather than the first.

## Verification

- Full suite at close: **2,039 passed / 15 skipped / 0 failed** (+28 this sprint). Analyzer
  clean. WinWright 2/2 with no DB drift. **Zero product-code diff** -- this was a
  documentation-and-gates sprint.
- **Manual Validation: all four steps PASSED**, and step 3 matched the prediction exactly --
  59 processed, 26 deleted, 21 safe, 12 no-rule, 0 errors. The same numbers the widget test
  asserts in the VM, confirmed on a real device.
- **Phase 5.1.1 review**: 2 findings, both real, both fixed. **Copilot review**: 1 finding,
  real, fixed and resolved.

## The findings worth remembering

- **A FALSE Play declaration reached committed history.** During a mutation test the
  reviewing agent flipped "Is this a news app?" to Yes; my evidence commit landed inside
  that window and captured it, while the justification in the same table row explained the
  app aggregates and publishes nothing. Caught by review, repaired against the last-good
  blob rather than retyped.
- **That was the second commit race of the sprint**, and both were diff-reviewed before
  landing. Neither review caught them, because a one-word change inside a 150-line document
  is exactly what diff review misses. Harold asked whether a semaphore could prevent this;
  the answer was a mutation-lock gate instead, since the two parties are asymmetric and the
  enforcement belongs on the commit rather than the mutation.
- **A gate that asserted a document's claim about itself.** The Ads check required the prose
  to contain "verified by grep" -- which passes if someone types the phrase. It now reads
  `pubspec.yaml` directly.
- **A gate defeated by a substring.** Manual Validation found the reviewer instructions
  named a screen a fresh install never shows. The gate passed the whole time because
  "Try Demo Mode" is a SUBSTRING of the real label "Try Demo Mode instead".
- **A fixed-duration test wait living on the wrong side of its own margin.** Copilot found
  the demo-scan test waited a flat 5 seconds for a scan whose own wall time is ~5.9s. Now a
  bounded poll, mutation-verified by tripling the mock's delay.

## Store release (Submission 22, listing-only)

Mid-sprint, the GP-6 cross-store comparison found two claims in the LIVE Microsoft Store
listing that had drifted from shipped behaviour: a superseded privacy policy URL, and a
"never stored" claim contradicted by the 100-character preview. Harold shipped a
**listing-only submission** (no new package) correcting both, plus a third item found while
reviewing the Properties page against the new text: the OneDrive automatic-backup product
declaration, which would have let Windows copy the app's data folder to the cloud while the
description promised everything stays on the device. Unchecked, so the promise needs no
asterisk. 0.14.0.0 remained live throughout.

## Backlog Movement

- DONE: GP-10, GP-18, GP-7, GP-6, GP-17.
- **Sprint 66 is Harold-driven console work**: enter the declarations and listing, capture
  the assets per `ASSET_SPEC.md`, then roll out to the closed track to start the 14-day
  clock. **Recruitment is the long pole and should start first** -- the clock cannot begin
  until every deliverable reaches the console AND testers have opted in.
- After the 14 days: production access is a SUBSTANTIVE ~7-day review asking what testers
  reported and what changed as a result. Thin answers are a documented rejection cause, so
  the feedback log is a deliverable, not a nicety.
