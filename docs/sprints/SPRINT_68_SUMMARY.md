# Sprint 68 Summary

**Dates**: 2026-09-09 to 2026-09-10 (single working session)
**Branch**: `feature/20260909_Sprint_68` | **PR**: #403 -> develop, #404 develop -> main
**Scope**: F199 (#398), F198 (#399), F191 (#400), F200 (#401), F197 (#402)
**Version**: 0.15.0 (MINOR -- `[Unreleased]` contained a `feat`; bumped at plan approval per F190)

**Theme**: ship two providers that were already built, and convert three recurring failure
classes into things that cannot recur.

## What shipped

**F191 -- Yahoo Mail and iCloud Mail were finished and unreachable.** Both adapters carried
real hosts, port 993 and TLS, structurally identical to `aol()`, which ships today. The only
thing between a user and a Yahoo account was a `phase` integer in the registry. Worse for
iCloud: the selection screen keeps `p.phase <= 2`, so iCloud at phase 3 was **not rendered at
all** -- anyone reading that screen would have concluded it was unimplemented. This is also the
defect behind the Sprint 66 Play listing that claimed both providers: the copy was traced to
the registry, which lists them, rather than to the screen, which hid them.

The code change was two integers. The work was proving they function, and writing app-password
instructions that do not fail -- which turned out to be the larger half.

**F200 -- the landing page made a privacy claim the app does not honour.**
`myemailspamfilter.com` told the public that email content "is processed in-memory only and is
never persisted to disk." False: scan history stores sender, subject, folder, the action taken,
and a 100-character preview for messages awaiting review. **The repo already knew** -- Sprint 63
deliberately corrected `PRIVACY_POLICY.md` to disclose exactly that. The correction landed in
the legal document and never reached the landing page, so the honest disclosure and the false
claim were served one click apart for about six months, on the page the Play listing cites as
its privacy host.

The inventory found more: **two live privacy policies** (the landing page linked the stale March
one while Play cited the current August one), `docs/website/` as a byte-identical copy of the
entire site, and an About section claiming Outlook.com and ProtonMail support that does not
exist.

**F197 -- a gate for the dark-mode defect class, not a sweep.** The card said "28 sites to fix";
that was a grep of `Colors.*.shadeNN` repo-wide, not a count of the defect. The real pattern is
MIXING a hardcoded surface with theme-derived text, which finds exactly two instances -- both
already fixed in Sprint 67. So the remaining value was entirely the gate that stops the third.

**F198 -- the analysis was the deliverable, and it concluded "do not build the hook."** See below.

**F199 -- the publisher rename finished.** Repo, Play developer name and the Partner Center
listing fields all landed. One item remains externally blocked.

## The sprint's defining pattern: four screenshots read wrong

Four times, an artifact supported two readings and I chose the more interesting one without
checking. Three were caught by Harold.

1. **The Yahoo folder picker.** I read his ticks as the app's pre-selection. The code showed
   `initialSelectedFolders` silently outranks `PRESELECT_FOLDER_TYPES`, so the app had
   *recommended* Bulk without *selecting* it -- a Recommended badge on an unchecked box.
2. **A Play Console line** recording CURRENT external state, rewritten as though it were a
   target to update.
3. **`deletedRuleFolder=Deleted Messages`** in a scan log, read as the scan resolving iCloud's
   real folder at runtime. It was Harold's saved setting, changed before the run -- and the
   wrong reading had narrowed F202's blast radius.
4. **The empty-state wording.** I compared a PRE-scan Android screen against a POST-scan Windows
   screen and invented a platform difference. Both strings live in the shared
   `empty_state.dart` behind one conditional; Android renders identical text in identical state.

None reached code and all four are corrected in the record, but each cost a rework cycle and put
a wrong claim into a committed record first. The shape is identical every time: **a screenshot
cannot distinguish "the app did this" from "Harold did this", or one app state from another --
and the source can.** That became retrospective IMP-1.

## F198 shipped no hook, deliberately

The card asked for a forcing function after the numbered-question rule was corrected four times.
The required R-1 comparison found two things that killed the hook:

- **The four violations are not one failure mode.** Three were AskUserQuestion tool-reflex; the
  fourth was PROSE. The memory's guidance addressed only the tool, so violation 4 was never
  covered. The rule was not repeated four times against a stable target -- the target moved.
- **The hook could not live where the violations happen.** Reusing
  `sprint-auto-advance.ps1`'s question detection looked obvious, but Gate 1c exits at Manual
  Validation BY DESIGN. All four violations happened outside the window; violation 4 happened
  during Manual Validation itself. A format hook would have had to gate the one region the repo
  deliberately leaves ungated.

The real gap, found by grep: the rule was **not in `CLAUDE.md` at all**, only in
selectively-recalled memory -- which is how violation 3 happened with the memory present and
unconsulted. Recorded as a decision with its counter-argument in
`docs/F198_QUESTION_FORMAT_ANALYSIS.md`.

## What the PR reviews found

Both reviewers ran. **Eight findings, no overlap, none deferred.**

The sharpest: **the F197 gate I shipped this sprint had the exact defect its own doc comment
warns about.** `isHardcodedSurface` rejected text colours by checking for `TextStyle` on the
same line -- but `dart format` splits `TextStyle(` from `color:` as soon as the call grows.
Measured: **63 lines matched as "surfaces" and 31 were text colours.** It stayed green only by
luck; adding one themed label to any of those correct, fully-hardcoded cards would have made the
gate block correct work while naming the wrong defect. Fixed with a bracket walk, re-mutated to
prove the fix had not made the gate inert.

**Copilot's `plan_approved: false` catch had a second half not visible from the diff.** That
flag was false all sprint despite explicit approval, so `require-sprint-cards.ps1:100` exited
early and card/PR enforcement was silently disabled for all of Sprint 68. Setting it true
**immediately blocked the next commit** -- correctly -- because the re-enabled hook found
`pr_number` null despite PR #403 existing: the PR had been recorded in a free-text field the
hook does not read. The flag that disabled enforcement was hiding the thing enforcement would
have caught.

## Metrics

| | Start | End |
|---|---|---|
| Tests passing | 2,060 | **2,074** |
| Tests failing | 0 | **0** |
| Policy gates | 99 | **109** |
| Hook suite | 53/53 | **53/53** |
| Analyzer | clean | **clean** |

**Effort**: estimated 400-755m, actual **~245m**. Four of five tasks at or under estimate; F200
came in at ~95m against 240-480m because the card specified a METHOD (inventory the live
artifact, do not reason from the repo) rather than only a goal.

## Manual Validation

F191 required a 2x2 matrix per ADR-0042. **All four cells PASS.**

| Provider | Windows | Android |
|---|---|---|
| Yahoo Mail | PASS | PASS |
| iCloud Mail | PASS | PASS |

Yahoo returned the same 41 messages with the same all-"No rule" outcome on both platforms --
two platforms observed agreeing, not assumed to agree because they share code. iCloud's evidence
is thin by VOLUME on both (a brand-new mailbox), recorded with that limit stated rather than
smoothed.

Two findings surfaced during validation and were filed rather than fixed in-sprint: **F202**
(per-provider folder defaults -- a new iCloud mailbox has ONE folder, and the app defaulted its
Deleted Rule Folder to `Trash`, which iCloud calls `Deleted Messages` and will never have) and
**F203** (`Found: 2, Processed: 0` is correct behaviour the user cannot see -- both messages
matched a safe sender already in the target folder).

## Post-merge: 0.15.0 reached a real device

Recorded because it is stronger evidence than the sprint itself produced. All Android
validation during Sprint 68 ran on the **emulator**. On 2026-09-10 at ~3:17pm, 0.15.0 reached
Harold's **physical Galaxy S24+** through the Play closed track -- and it arrived as an
**UPGRADE, not a fresh install**: 0.14.1 -> 0.14.2 -> 0.15.0, the same path every closed tester
walks.

**F191 CONFIRMED ON PHYSICAL HARDWARE.** Harold checked the Add Account list on the S24+ after
the upgrade: **Yahoo and iCloud are selectable there**, not "Coming Soon". That is the phase-gate
change verified on a real device rather than on the emulator, which was the sprint's only Android
evidence at Manual Validation.

Also worth recording because it LOOKS like a defect and is not: the phone shows **two** saved
accounts while Windows shows four. Accounts live in the app's local database and are per-device;
Yahoo and iCloud were added on Windows and never existed on the phone. Two saved accounts plus
four SELECTABLE providers is the correct state, and the distinction between "saved" and
"available" is what makes it correct.

That exercises things no emulator run touched:

- The full Play chain end to end -- versionCode 3 accepted, pre-review checks passed with no
  critical issues, review approved, published.
- **Package identity and signing key held across two version bumps.** An upgrade only succeeds
  if `applicationId` and the signing key match; a break shows as "app not installed", not a
  silent failure.
- The app updated **in place over an installed 0.14.2 carrying four configured accounts**,
  which is the only way to learn that a MINOR bump does not disturb existing user data.

## Retrospective outcome

Harold: Very Good across all 12 rated categories, none for 13 and 14. Five improvements
proposed, **all five approved and applied**:

- **IMP-1** `CLAUDE.md`: a screenshot proves STATE, never CAUSE
- **IMP-2** `dev_version_ahead_test.dart`: the old gate compared against the newest CHANGELOG
  heading, which lags the stores -- a version live on BOTH stores passed while byte-identical to
  production. Now reads every "Live" row in `STORE_VERSION_STATUS.md`
- **IMP-3** `provider_setup_steps_test.dart` (new): gates in-app-vs-doc agreement. Found a real
  gap on its first run -- no AOL section in the doc
- **IMP-4** `SPRINT_PLANNING.md`: single-session sprints and model deviation
- **IMP-5** `CLAUDE.md`: `git commit -F` for messages containing backticks

## Carried into Sprint 69

- **F202** per-provider folder defaults (~6-10h) -- Harold targeted this at Sprint 69, with his
  confirmed AOL/Gmail/Yahoo values recorded as observed truth and four decisions already made
- **F192** Custom IMAP host-entry UI (~4-6h)
- **F203** Found-vs-evaluated disclosure (~1-2h)
- **F199 remnant**: the Partner Center publisher display name, externally blocked -- Microsoft's
  own docs contradict each other on whether an Individual account can change it
