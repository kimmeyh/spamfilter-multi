# Sprint 66 Plan

**Status**: APPROVED (Harold, 2026-09-07: "Sprint plan approved, proceed with execution. All Sprint tasks and sub-tasks are approved. Continue without additional approvals until Manual Validation.") Standing approval through Manual Validation per Phase 3.7.
**Branch**: `feature/20260907_Sprint_66` | **PR**: to be created at 3.3.1 (draft)
**Sprint theme**: Get the app in front of real testers and start the Play launch clock.
**Scope**: GP-19, GP-4 (2 tasks). F173 and F189 were considered and deferred to a future
sprint at Harold's direction.

**Governing constraint (ADR-0042, restated by Harold at selection)**: everything takes into
account BOTH the Windows app and the Android app; functionally and UI the same unless it
cannot be, and where it cannot, implemented as a platform exception for what is needed --
backend, frontend, data, architecture, development, security, testing, deployment.

**ADR-0042 note for this sprint**: both tasks are external-console and store-operations work
whose parity peer is the Microsoft Store (live at Submission 22). They are therefore
**deployment-infrastructure platform exceptions**, the same classification Sprints 64 and 65
used. The one place app CODE is touched is GP-4's dead-scope cleanup, which is shared Dart
and must not diverge -- that carries an explicit parity acceptance criterion rather than an
assumption.

---

## The planning correction that shaped this sprint

I originally planned this sprint around a 7-day OAuth refresh-token expiry, arguing that
GP-4 had to precede GP-19 or every tester would be signed out mid-test. **Harold's question
disproved it**: *"What am I using for my Gmail account because there is no 7-day expiration
as I have been using the same token for months."*

He was using **App Password (IMAP)**, not Google Sign-In. The app offers both, and it already
marks App Password as **"(Recommended)"** on the Gmail sign-in screen, on BOTH platforms.
Verified in code: that path connects to `imap.gmail.com` through the standard IMAP adapter
with no OAuth involved, so no token expiry exists on it at all.

**Consequences, all of them good**:
- App passwords do not expire on a schedule. Testers sign in ONCE and stay connected for the
  full 14 days.
- Gmail testers need no second account -- they use the path the app already recommends.
- **GP-4 no longer gates GP-19.** The two tasks are fully independent and run in parallel.

**The lesson worth keeping**: I planned around a documented constraint without first asking
which authentication path was actually in use. Harold had months of contrary evidence in
front of him; one question would have surfaced it before I reordered a sprint around it.

**Residual trade-off, accepted knowingly**: if every tester uses App Password, the 14-day
test never exercises the Google Sign-In path. It stays unvalidated before launch. Acceptable
because it is the secondary option the app steers users away from -- but it is a real gap,
recorded here rather than discovered later.

---

## Task 1 -- GP-19: Play Console entry, asset capture, and closed-track rollout (Priority 30)

**Value**: This starts the 14-day closed-test clock, which is the last thing standing between
the app and a live Google Play listing.

**Requirements** (numbered, detailed):
- R-1: **Recruit 14-16 testers and START THIS FIRST**, in parallel with everything else. The
  14-day clock begins on tester OPT-IN, not on rollout, so testers found late extend the
  calendar directly. 14-16 rather than exactly 12 because opt-out breaks the streak and
  re-opting-in restarts that tester's 14 days from ZERO.
- R-2: **Testers use App Password (IMAP), not Google Sign-In.** This is the path the app
  already recommends, it does not expire, and it keeps testers connected for the full 14
  days. Tester instructions must state the one prerequisite plainly: an app password
  requires 2-Step Verification enabled on the account.
- R-3: Enter the Data safety declarations in Play Console from the recorded answers in
  `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`. They are already traced to code; this is transcription,
  not re-derivation.
- R-4: Enter every App content declaration from the same document, including the App access
  reviewer instructions (Demo Mode path, no credential required).
- R-5: Capture the feature graphic and 5 phone screenshots per
  `docs/store-assets/android/ASSET_SPEC.md`, from the REAL Android build. **Use Demo Mode for
  every capture** so no personal address, subject, or sender ever appears in a public listing.
- R-6: Enter the listing copy from `docs/store-assets/android/LISTING_COPY.md` (short 78/80,
  full 2694/4000 -- both already measured).
- R-7: Create the closed-testing track, roll out the signed release, distribute the opt-in
  link, and **CONFIRM each opt-in landed**. An invitation is not an opt-in and starts no clock.
- R-8: Record each tester's confirmed opt-in date in the roster, and compute the earliest
  valid production-access application date from the LAST opt-in.
- R-9: Collect real tester feedback during the 14 days. Production access is a SUBSTANTIVE
  review asking what testers reported and what changed as a result; thin answers are a
  documented rejection cause.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- roster rows, opt-in dates, computed application date,
  feedback log, and the closed-track release record (all tables already exist and are empty).
- `docs/store-assets/android/` -- the captured feature graphic and 5 screenshots land here at
  the exact filenames `ASSET_SPEC.md` names, which is what lets the gate verify them.

**Dependencies / blockers**: Harold-driven throughout (console access, device capture,
recruitment). **Nothing in the repository blocks it** -- every input shipped in Sprint 65.

**Non-functional requirements**:
- Privacy: the roster records ROLES and dates only. No tester email addresses or names in the
  repository -- a leak there survives deletion. Enforced by `closed_test_roster_test.dart`.
- Privacy: screenshots come from Demo Mode, never a real mailbox.
- Platform: ADR-0042 **deployment-infrastructure platform exception**. The Microsoft Store has
  no tester-gate equivalent; the Windows app reached the Store without one and is unaffected.
  Recorded as an exception rather than a parity gap.

**Acceptance criteria** (measurable, traceable):
- AC-1: Play Console shows Data safety, App content, and Store listing all COMPLETE, with no
  section in a "needs attention" state.
- AC-2: The feature graphic and at least 2 phone screenshots exist at the specified paths and
  pass `play_listing_assets_test.dart` -- which today prints them as PENDING, so the gate
  flipping from pending to verified IS the evidence.
- AC-3: A closed-testing track exists with a rolled-out release.
- AC-4: At least 12 testers (target 14-16) have CONFIRMED opt-in, each date recorded.
- AC-5: The earliest valid production-access application date is computed from the LAST
  tester's opt-in and recorded.
- AC-6: Given a tester following the App Password instructions, When they connect a Gmail
  account, Then the connection persists for the full 14 days with no re-authentication.

**Tests to write**:
- T-1 (verifies AC-2) -- the EXISTING `play_listing_assets_test.dart` gate becomes live: it
  already checks dimensions and alpha for each named asset once the file exists. No new test
  needed; the assertion simply starts running. State the pending-to-verified transition in the
  completion record.
- T-2 (verifies AC-5) -- the EXISTING `closed_test_roster_test.dart` gate already asserts the
  roster carries opt-in confirmation and a computed application date, and that no email
  address appears. No new test needed.
  (Both gates were written in Sprint 65 precisely so this task needs no new test code --
  recorded here rather than leaving the "Tests to write" field looking empty by oversight.)

**Definition of Done**: default task-level DoD PLUS:
- Console state confirmed by Harold (Claude cannot see the console).
- The 14-day wait is NOT part of this sprint's completion. The sprint is done when the clock
  is STARTED and the roster recorded; the production-access application is a later action.

**Model**: Fable/Opus -- *why not the cheaper tier*: live external-console work with an
irreversible schedule consequence (a mis-started clock costs 14 days) plus judgment about
recruitment adequacy and evidence quality.

**Executed-by** (filled at completion):

**Step-types**: DOCS, DATA (assets + console configuration)
**Est-Effort**: **15-30m CODING** (DOCS 15-20 to record roster/dates/feedback; both gates
already exist). EXCLUDED per the CODING_VELOCITY two-metric rule: recruitment, console entry,
device screenshot capture, and the 14-day external wait -- all people time or waiting.
_**Risk & rollback**_: the highest-consequence task in the sprint and the least reversible. A
tester dropping out restarts their 14 days; R-1's 14-16 margin is the mitigation. Rolling out
to the closed track is reversible (halt the release); the clock is not recoverable.

---

## Task 2 -- GP-4: Gmail OAuth verification and the security-assessment question (Priority 32)

**Value**: This settles the one question that decides whether Play readiness costs two weeks
or two months, and removes the unverified-app constraints before they matter.

**Requirements** (numbered, detailed):
- R-1: **Determine and document whether any Gmail-derived data ever leaves the device.** This
  is THE question -- Google requires the third-party security assessment only if restricted-
  scope data is stored or transmitted on servers. **Verified during planning**: the only
  outbound hosts in `lib/` are Google's own OAuth and Gmail endpoints plus documentation
  links. No backend, no analytics, no crash reporting. Record it with the same code-evidence
  discipline the Data safety declarations used.
- R-2: **Ask Google to rule on the assessment rather than assuming the exemption.** The
  developer-facing pages state the server-side condition, but the authoritative API Services
  User Data Policy does not repeat the carve-out. State the client-only architecture
  explicitly in the submission and let Google decide. Asking is cheap; assuming is not.
- R-3: Remove dead scope declarations before submitting. The app declares a `gmail.send`
  constant it never requests (verified during planning); a reviewer assesses what is declared,
  so removing unused scope narrows the review surface.
- R-4: Prepare the consent-screen verification submission: verified domain ownership,
  homepage, privacy policy link, branding compliance, contact details, per-scope
  justification, and a demo video showing the authorisation flow and how the data appears in
  the app.
- R-5: **Do NOT publish the consent screen to production before verification completes.**
  Doing so imposes a 100-new-user cap for the LIFETIME of the project which cannot be reset
  or changed. This is a one-way door and the single most expensive mistake available in this
  task.
- R-6: Record every submitted field in the repository so a resubmission does not re-derive
  them from memory, and record Google's ruling on the assessment when it arrives -- whichever
  way it goes.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (or a new `docs/GMAIL_OAUTH_VERIFICATION.md` if the
  section grows past a screen) -- the submission record and the data-residency determination.
- `mobile-app/lib/adapters/auth/google_auth_service.dart` -- R-3 dead-scope removal.

**Dependencies / blockers**: **None.** Independent of GP-19 -- App Password testers mean
verification does not gate the closed test. External: Google's review runs on its own clock
(brand verification typically 2-3 business days; restricted-scope review potentially several
weeks).

**Non-functional requirements**:
- Security: an inaccurate data-residency claim to Google is a policy matter, not a typo. R-1's
  code-evidence rule is the mitigation.
- Platform: ADR-0042 -- Gmail OAuth is SHARED Dart code, so verification covers both Windows
  and Android, and R-3's scope cleanup touches that shared code. The console itself is a
  declared deployment platform exception (no Microsoft Store counterpart). **AC-4 makes the
  shared-code parity explicit rather than assumed.**

**Acceptance criteria** (measurable, traceable):
- AC-1: The data-residency determination is recorded with its code evidence (the outbound-host
  enumeration), not asserted.
- AC-2: The verification submission is prepared, submitted, and every field recorded in the
  repository.
- AC-3: The submission explicitly raises the client-only architecture and asks Google to
  confirm whether the security assessment applies. Google's answer is recorded when it
  arrives.
- AC-4: After R-3's scope cleanup, the requested scope set is IDENTICAL on Windows and
  Android -- verified by grep across both entry points, not assumed from a shared constant.
- AC-5: The consent screen remains in its current publishing status until verification
  completes (R-5 guard).

**Tests to write**:
- T-1 (verifies AC-4) -- TEST-UNIT policy gate in `test/policy/`: assert the Gmail scope set
  requested by the Windows and Android paths matches, and that no scope constant is declared
  but unrequested. This is the shared-code parity check, and it is exactly the class of drift
  ADR-0042 exists to prevent. Mutation-verify it.

**Definition of Done**: default task-level DoD PLUS:
- Submission confirmed by Harold (Claude cannot see the console).
- Google's ruling recorded when it arrives -- which may be AFTER this sprint closes. The
  sprint is done when the submission is IN, not when Google answers.

**Model**: Fable/Opus -- *why not the cheaper tier*: an incorrect data-residency claim to
Google is a compliance matter, and the submission's framing materially affects the outcome.

**Executed-by** (filled at completion):

**Step-types**: DOCS, SVC-EDIT (scope cleanup), TEST-UNIT
**Est-Effort**: **35-60m CODING** (DOCS 15-20 for the submission record + SVC-EDIT 5-18 for
the scope cleanup + TEST-UNIT 4-10 for the parity gate). EXCLUDED: Harold's console work, the
demo video recording, and Google's review time.
_**Risk & rollback**_: R-5's lifetime cap is irreversible -- that is the real risk, and it is
avoided by not touching the publishing status. The submission itself is editable and
resubmittable. If Google rules the assessment IS required, that is a multi-week, ~$500-$4,500
annually-recurring commitment and a Class-1 decision to surface to Harold, not absorb.

---

## Manual Validation -- planned steps (to be refined at Phase 5.3)

1. GP-19: Play Console shows Data safety, App content and Store listing COMPLETE; closed track
   live with a rolled-out release.
2. GP-19: roster shows 12+ CONFIRMED opt-ins with dates, and the computed earliest application
   date. `play_listing_assets_test` no longer prints PENDING for any asset.
3. GP-19: a tester (or Harold, simulating one) connects Gmail by App Password and the
   connection persists -- the AC-6 claim that motivated this sprint's re-plan.
4. GP-4: the submission is in, with the data-residency determination and the
   assessment question recorded.
5. GP-4: scope parity verified on both platforms by the new gate.
6. Regression: the Windows app is unaffected. GP-4's scope cleanup touches shared code, so
   confirm rather than assume -- Gmail sign-in still works on Windows.

## Sprint totals

**Coding effort: 50-90 minutes.** Both tasks are dominated by Harold-side console work and
external review time, which are excluded per the two-metric rule.

| Task | Coding Est-Effort | Dominant step-types |
|------|-------------------|---------------------|
| GP-19 Console + assets + rollout | 15-30m | DOCS, DATA |
| GP-4 OAuth verification + scope parity | 35-60m | DOCS, SVC-EDIT, TEST-UNIT |
| **Total** | **50-90m** | |

**Wall-clock ("when can I come back?")**: ~30-50m. The tasks are independent and can run in
parallel.

**NOT included** (people time or external): recruitment, console entry, screenshot capture,
demo video, the 14-day closed test, and Google's review.

## What this sprint does NOT include

- F173 (test coverage deep dive) and F189 (skills audit) -- considered and **deferred to a
  future sprint at Harold's direction**. Both remain periodic HOLD templates.
- The production-access application, which needs the 14 days to have elapsed.
- Any Google Sign-In path validation -- see the accepted trade-off above.

---

## Phase 5 evidence gates

- **5.1.2 F-PRECHECK six classes** (2026-09-07): one production file changed all sprint
  (`google_auth_service.dart`, the scope narrowing), so most classes have no surface. Class 1
  (parallel sites) is the exception and is the sprint's headline risk: the Gmail scope set is
  declared in TWO independent literals. That is not merely checked, it is now GATED by
  `gmail_scope_parity_test.dart`, mutation-verified in both directions. Class 4: zero new
  positional parsing. Class 6: zero new `catch` blocks. Classes 2, 3, 5: no new production
  helper, no changed default, no new external call.
- **5.1.5 WinWright UI sweep** (2026-09-07, `sweep-head: 511dd2c034f1823bc320a64230f6cb78bd0179c5`):
  **2/2 PASSED** on the retry, DB drift none. The FIRST run failed one script (MT2C-1, an
  errored step) -- Harold was interacting with the machine during it, which the sweep drives
  by real mouse and keyboard input. Retried clean rather than investigated, because the cause
  was known and stated. 3 dialog-settle scripts excluded by the runner's own documented policy
  (Sprint 52 IMP-3: do not re-derive a documented exclusion).
- **5.2 Full suite**: 2,048 passed / 15 skipped / 0 failed (+9 this sprint); analyze clean.
- **5.1.6 Runtime launch gate**: **N/A -- no Android config touched.** The trigger is a change
  to `res/xml/**`, `AndroidManifest.xml`, `build.gradle.kts` or ProGuard rules; this sprint
  changed none. Recorded as an explicit N/A per the gate's own wording rather than skipped.

### A false alarm worth recording, because it cost real time

The suite failed 4 tests twice, with DIFFERENT tests failing each run and every one passing in
isolation -- the textbook signature of concurrency flake. It was not flake.

My own earlier mutation test had added `sentry_flutter` to `pubspec.yaml` to prove the
data-residency gate fires. I restored `pubspec.yaml`, but **flutter had already resolved the
dependency**: `pubspec.lock` and the generated Windows plugin registration
(`generated_plugin_registrant.cc`, `generated_plugins.cmake`) still carried it, and were
compiled into every subsequent run. Runs went from ~1:45 to 6+ minutes, which was the real
tell.

A clean-tree baseline is what exposed it: 2,039/15/0 in 1:40 with my work stashed.

**Lesson: restoring `pubspec.yaml` does not restore what resolving it produced.** A mutation
on a dependency manifest has to revert the lock file and any generated registration too. Worth
carrying into the mutation-lock contract.

---

## Manual Validation -- results (Phase 5.3, IN PROGRESS 2026-09-07)

- **Version display** -- PASS. The dev app now reads 0.14.0 [DEV]. Harold's earlier "0.13.0
  [DEV] while production shows 0.14.0" was a STALE BINARY, not a source defect: the exe dated
  09-03, one day before the version bump landed on 09-04. Both worktrees and the live Store
  agree at 0.14.0. Rebuilt and confirmed.
- **Gmail background scan (Windows)** -- **PASS** (Harold: "Started background scan on gmail
  and it completed. as expected"). **This is the regression check that mattered most this
  sprint.** GP-4 removed two scope declarations from SHARED authentication code
  (`google_auth_service.dart`); both had zero call sites, but "zero call sites" is a static
  claim. A background scan that completes end to end exercises authentication, token handling,
  the provider connection and rule evaluation together, which is the behavioural proof the
  static check cannot give (`feedback_source_gates_verify_shape`).
- **AOL background scan (Windows)** -- Harold ran it; result pending. Worth having as a
  SECOND provider on a DIFFERENT code path: AOL authenticates by app password over IMAP while
  Gmail here uses the Gmail API path, so the two together cover both authentication routes the
  app ships.
- Steps 3-5 (Play Console entry, asset capture, tester recruitment) are Harold-driven and
  outstanding.

### A launch-diagnosis mistake worth recording

Harold reported the Windows app "not running" shortly after I had confirmed it launched
cleanly. Both were true: my diagnostic launch started the app, verified it, and then
deliberately killed it to read the exit state -- which from his side is indistinguishable from
a failed launch. Fixed by a new standing rule
(`feedback_launch_apps_without_asking`): never ask whether to start an app (the answer is
always yes), and LEAVE IT RUNNING; if a probe must terminate the process, relaunch it and say
so.
