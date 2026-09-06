# Sprint 65 Plan

**Status**: APPROVED (Harold, 2026-09-05: "Sprint plan approved, proceed with execution. All Sprint tasks and sub-tasks are approved. Continue without additional approvals until Manual Validation.") Standing approval through Manual Validation per Phase 3.7.
**Branch**: `feature/20260904_Sprint_65` | **PR**: to be created at 3.3.1 (draft)
**Sprint theme**: Everything Google Play requires before the 14-day closed-test clock can start,
then starting it.
**Scope**: GP-10, GP-18, GP-7, GP-6, GP-17 (5 tasks) -- Harold selected "all of it" at Phase 8.4,
2026-09-05.

**Governing constraint (ADR-0042, restated by Harold at selection)**: everything takes into
account BOTH the Windows app and the Android app; functionally and UI the same unless it cannot
be, and where it cannot, implemented as a platform exception for what is needed -- backend,
frontend, data, architecture, development, security, testing, deployment. Per-card ADR-0042
notes classify each task as shared or declared-platform-exception.

**ADR-0042 note for this sprint specifically**: four of the five tasks are Play-console and
store-asset work with no Windows counterpart in the same sense -- the Microsoft Store equivalent
(Partner Center listing, already live through Submission 21) is the parity peer. That makes them
**deployment-infrastructure platform exceptions**, the same classification Sprint 64 used for the
Android release chain. Parity holds at the level of "each store has a complete, current listing",
not at the level of identical forms. Where a task touches APP CODE rather than console
configuration (GP-7's icon pipeline, GP-18's reviewer-access path), the Windows side is examined
explicitly and the finding recorded -- that is where a silent divergence could actually hide.

---

## The finding that reordered this sprint

Harold asked at refinement: *"does the list include known timing dependencies that should drive
the order these are completed to get onto the Google Play store as quickly as reasonably
possible?"* It did not, and the answer changed the sprint.

The slate had been ordered by BUILD dependency (only GP-6 needs GP-7's icon -- a few hours of
coupling). The dependency that governs the calendar is the 12-tester / 14-continuous-day closed
test that gates production for a post-2023-11-13 personal account.

My first correction was also wrong. I proposed starting the clock FIRST and doing the listing
work during the 14-day wait. **Verified research (2026-09-05, Google support sources) overturned
that**: closed testing sits behind the SAME "complete app setup" wall as production --

> "You can start a closed test after completing your app setup."

Full store listing, Data safety, content rating and every App content declaration must be
complete BEFORE a closed-track rollout. Only INTERNAL testing skips setup, and internal-test days
earn **zero** credit toward the 12/14. So the rollout is genuinely LAST; there is no way to start
the clock early and finish paperwork during the wait.

What CAN be parallelised is the one thing with no dependency: **tester recruitment starts on day
one** and runs alongside every other task.

Timeline consequence: setup work (this sprint) -> 14 days minimum of continuous opt-in -> up to
~7 days of substantive production-access review. Roughly 3-4 weeks from a complete listing to
production access, assuming no rejection.

---

## Task 1 -- GP-10: Data Safety form declarations (Priority 32)

**Value**: This unblocks the closed-track rollout -- Data safety is mandatory for closed tracks,
not just production, so nothing ships to testers until it is submitted.

**Requirements** (numbered, detailed):
- R-1: The Data safety form is completed and submitted in Play Console, declaring every category
  of data the app collects, shares, and stores, plus retention and deletion behaviour.
- R-2: Declarations are derived from CODE AND the 9-permission list from Sprint 64's GP-3 -- not
  from assumption. Any claim of "does not collect" is verified against the actual data paths
  (credentials store, scan results DB, unmatched-emails table, logs).
- R-3: The privacy policy URL (published Sprint 64 at `myemailspamfilter.com/legal`) is linked
  from the form.
- R-4: The declared answers are recorded IN THE REPO, so the next submission does not re-derive
  them from memory and drift.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- new "Data safety declarations (as submitted)" section.
- Evidence sources (read-only): `lib/core/storage/` (what is persisted),
  `lib/adapters/storage/app_paths.dart` (where), `docs/legal/PRIVACY_POLICY.md` (what was
  already promised publicly -- the two MUST agree).

**Dependencies / blockers**: None. GP-5 (privacy policy) shipped in Sprint 64.

**Non-functional requirements**:
- Security: no credential values or account identifiers in the recorded declarations.
- Platform: ADR-0042 **platform exception, deployment infrastructure** -- Play's Data safety form
  has no Microsoft Store counterpart. BUT the underlying factual claims are cross-platform: the
  app's data behaviour is shared Dart code, so any answer here that contradicts the published
  privacy policy is a defect on BOTH platforms. R-2 checks that agreement explicitly.

**Acceptance criteria** (measurable, traceable):
- AC-1: Play Console shows the Data safety section COMPLETE.
- AC-2: Every declared answer is traceable to a code path or to the privacy policy, recorded in
  the doc with its evidence.
- AC-3: Zero contradictions between the Data safety answers and `docs/legal/PRIVACY_POLICY.md`
  (explicit diff, item by item).

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-UNIT policy gate in `test/policy/`: assert the recorded Data safety
  declarations file exists and that the data-collection claims it contains match the claims in
  `docs/legal/PRIVACY_POLICY.md` (both are repo text; a drift between them is mechanically
  detectable and is exactly the kind of thing that rots silently).

**Definition of Done**: default task-level DoD PLUS:
- Console state confirmed by Harold (Claude cannot see the console).

**Model**: Sonnet -- *why not the cheaper tier*: R-2 requires reading persistence code across
several files and reconciling it against a published legal document; a wrong "we do not collect"
answer is a compliance defect, not a typo.

**Executed-by** (filled at completion):

**Step-types**: DOCS, TEST-UNIT
**Est-Effort**: **25-45m CODING** (DOCS 15-20 + TEST-UNIT 4-10, both from the Estimate Table; the
Sprint 64 GP-8/GP-3 DOCS+verify pair actually ran ~50m for two items). EXCLUDED from this number,
per the CODING_VELOCITY two-metric rule: Harold's Play Console form entry, which is people time.
_**Risk & rollback**_: an inaccurate declaration is a policy violation with real consequences.
Mitigation is R-2's code-traceability rule. Rollback: the form is editable and resubmittable.

---

## Task 2 -- GP-18: App content declarations, including App access (Priority 33)

**Value**: This removes the last non-asset blocker on the closed-track rollout, and closes a gap
nothing in the project tracked before 2026-09-05.

**Requirements** (numbered, detailed):
- R-1: Every item in Play's "App content" checklist is answered: content rating questionnaire,
  target audience and content, ads declaration, government apps, financial features, news app,
  health apps. Conditional items must be ANSWERED (as not-applicable), not skipped -- an
  unanswered declaration is an incomplete setup and blocks rollout.
- R-2: **App access** is provided. A spam filter demonstrates nothing without a working email
  account, so a reviewer cannot exercise the core flow unaided. Decide and implement ONE of:
  (a) a dedicated test email account with seeded spam, credentials supplied to Google; or
  (b) written step-by-step instructions if a reviewer can reach a meaningful state without an
  account (e.g. via Demo Mode).
  **R-2 is a decision point, surfaced to Harold before implementation** -- option (a) creates a
  real credential that lives outside the repo and must be maintained.
- R-3: Whichever option R-2 takes, the reviewer path is WALKED END TO END on a real device before
  submission -- not assumed to work.
- R-4: The answers are recorded in the repo alongside GP-10's, for the same anti-drift reason.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- new "App content declarations (as submitted)" section.
- If R-2 chooses Demo Mode as the reviewer path: `lib/ui/screens/platform_selection_screen.dart`
  (Demo Mode entry point) -- verify it is reachable and self-explanatory to someone with no
  account, no code change expected.

**Dependencies / blockers**: R-2 option (a) needs Harold to create the test account.

**Non-functional requirements**:
- Security: if R-2 picks option (a), the credential NEVER enters the repo, the logs, or a commit
  message. It lives where the signing config lives -- outside the repository.
- Platform: ADR-0042 **platform exception, deployment infrastructure**. Worth stating the
  asymmetry plainly: the Microsoft Store submission never required reviewer credentials, so this
  is a genuine Play-only obligation rather than a parity gap. The REVIEWER PATH itself, however,
  is shared app code -- if Demo Mode is the answer, it must behave identically on Windows, and
  T-2 checks that rather than assuming it.

**Acceptance criteria** (measurable, traceable):
- AC-1: Play Console shows every App content item COMPLETE (none in a "needs attention" state).
- AC-2: Given a fresh install and no configured account, When the reviewer follows the supplied
  App access instructions, Then they reach a screen that demonstrates spam filtering -- verified
  on a real device, not inferred.
- AC-3: Untruncated grep proves no test credential appears anywhere in the repo.

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-UNIT policy gate: assert no credential-shaped literal for the
  reviewer account exists in tracked files (extends the existing secret-hygiene gates).
- T-2 (verifies AC-2, if Demo Mode is the chosen path) -- TEST-WIDGET: Demo Mode is reachable
  from a zero-account first-run state and produces scan results, asserted on BOTH platform code
  paths (this is the ADR-0042 parity check).

**Definition of Done**: default task-level DoD PLUS:
- The reviewer path walked end to end on a real device (R-3), recorded with what was seen.

**Model**: Sonnet -- *why not the cheaper tier*: R-2 is a security-adjacent decision with a
credential-handling consequence, and R-3 is live verification. Per the Sprint 64 lesson, a
security-adjacent task is planned WITH its hardening pass rather than treating it as rework.

**Executed-by** (filled at completion):

**Step-types**: DOCS, TEST-UNIT, TEST-WIDGET
**Est-Effort**: **30-55m CODING** (DOCS 15-20 + TEST-UNIT 4-10 + TEST-WIDGET 20-25 if R-2 picks the
Demo Mode path; the widget harness is the real cost, per the table's TEST-WIDGET note). EXCLUDED:
Harold's console declarations, test-account creation, and the R-3 on-device reviewer walk.
_**Risk & rollback**_: a reviewer who cannot exercise the app is a rejection, and a rejection
costs a resubmission cycle. Mitigation is R-3's end-to-end walk. Rollback: declarations are
editable.
_**Decision-class interrupts**_: R-2 (test account vs instructions) is a Class-2 development
decision with a security dimension -- SURFACE TO HAROLD AND WAIT before implementing.

---

## Task 3 -- GP-7: Adaptive icons and app branding (Priority 34)

**Value**: This produces the launcher and listing icon Play requires, and GP-6 consumes.

**Requirements** (numbered, detailed):
- R-1: **Audit first, build second.** Adaptive icon config already exists
  (`mipmap-anydpi-v26/ic_launcher.xml` with foreground + background layers) and
  `ic_launcher_foreground.png` is present at all five densities. R-1 is to VERIFY that what
  exists is correct and complete before generating anything -- the Sprint 64 GP-8 lesson (the
  answer was already true in the codebase) applies directly.
- R-2: The icon renders correctly in every adaptive mask (circle, squircle, rounded square) with
  the safe zone respected -- the 16% inset is already configured; confirm the artwork survives it
  rather than assuming.
- R-3: The 512x512 Play listing icon is produced (32-bit PNG, no alpha per Play's requirement).
- R-4: Any gap found by R-1 is fixed at all five densities, not just the one that was noticed.

**Affected components / files**:
- `mobile-app/android/app/src/main/res/mipmap-*/ic_launcher.png` (5 densities)
- `mobile-app/android/app/src/main/res/drawable-*/ic_launcher_foreground.png` (5 densities)
- `mobile-app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (verify, likely no change)
- `mobile-app/assets/icon/icon.png` -- the shared source of truth
- `docs/store-assets/android/` -- NEW: the 512x512 listing icon master

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: ADR-0042 **shared source, platform-specific rendering**. The icon ARTWORK is one
  asset (`assets/icon/icon.png`) used by both platforms; only the packaging differs (Android
  adaptive layers + mipmap densities, Windows MSIX logo path). R-1 explicitly confirms both
  platforms still derive from that single source -- if Android's icon has silently diverged from
  the Windows one, that is a real ADR-0042 finding and gets recorded, not quietly fixed.

**Acceptance criteria** (measurable, traceable):
- AC-1: All five mipmap densities plus the adaptive XML are present and correct; any gap R-1
  found is fixed at every density.
- AC-2: The 512x512 listing icon exists at the recorded path, is 32-bit PNG, and has no alpha
  channel (mechanically checked, not eyeballed).
- AC-3: The launcher icon renders correctly under at least three adaptive masks on a real device.
- AC-4: Windows and Android icons demonstrably derive from the same source asset, or the
  divergence is recorded as an explicit finding.

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-UNIT policy gate: the listing icon exists, is 512x512, and carries
  no alpha channel (Play rejects alpha; this is mechanically checkable and worth gating because
  the failure appears only at upload).
- T-2 (verifies AC-1) -- TEST-UNIT policy gate: every declared density has both `ic_launcher.png`
  and `ic_launcher_foreground.png`, and the adaptive XML references layers that exist. This is
  the gate that would catch a partial regeneration.

**Definition of Done**: default task-level DoD PLUS:
- On-device visual confirmation under multiple masks (AC-3) -- a source gate proves the files
  exist, not that the artwork reads correctly (Sprint 52 MV-1 rule).

**Model**: Haiku -- *why not a cheaper tier*: n/a, this is the cheapest tier. Mechanical asset
generation against an existing, already-correct configuration. **Planned WITH a Fable review
pass** on the AC-4 parity question, per the Sprint 64 lesson that a Haiku task's hardening pass
should be planned rather than discovered.

**Executed-by** (filled at completion):

**Step-types**: DATA (assets), TEST-UNIT
**Est-Effort**: **20-40m CODING** (DATA 15-19 for asset regeneration + TEST-UNIT 4-10 x2 gates).
R-1 may find the work is largely already done -- adaptive icons exist at all five densities today --
in which case this lands at the low end, the way Sprint 64's GP-8 did when the answer was already
true in the codebase. EXCLUDED: the AC-3 on-device visual check across adaptive masks.
_**Risk & rollback**_: low. Assets are version-controlled; rollback is a revert.

---

## Task 4 -- GP-6: Play Store listing and assets (Priority 36)

**Value**: This completes the last gating requirement for the closed-track rollout -- a complete
store listing is required for closed tracks, not only production.

**Requirements** (numbered, detailed):
- R-1: All mandatory listing fields are supplied: app name, short description (80 char limit),
  full description (4000), app category, contact email, and the privacy policy URL.
- R-2: Required graphics are produced: the 1024x500 feature graphic (**Play will not publish a
  listing without it**) and at least 2 phone screenshots; tablet screenshots if tablet support is
  declared.
- R-3: Android screenshots are captured from the REAL Android build, not reused from the Windows
  Store assets -- the Windows masters in `docs/store-assets/windows/` are the reference for WHICH
  screens to show (provider choice, scan results, quick actions, manage rules, settings, help),
  not the images themselves.
- R-4: Listing copy is consistent with the Microsoft Store listing in substance -- same product,
  same claims -- while respecting each store's format. Any deliberate difference is recorded.
- R-5: No user-facing text claims a capability the Android build does not have, and no
  "not available on Android yet" caveats for capabilities that simply are not shipped anywhere
  (the no-caveats-for-unshipped-platforms rule).

**Affected components / files**:
- `docs/store-assets/android/` -- NEW: feature graphic, phone screenshots, tablet screenshots,
  listing copy master
- `docs/store-assets/windows/` -- read-only reference for screen selection and copy consistency
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- record the submitted listing values

**Dependencies / blockers**: GP-7 (Task 3) must land first -- the listing icon is a GP-7 output.

**Non-functional requirements**:
- Platform: ADR-0042 **platform exception, deployment infrastructure**, with a shared-substance
  requirement. The two stores' listings are separate artifacts by necessity (different formats,
  different asset specs), but R-4 makes the PRODUCT CLAIMS shared -- a feature described on one
  store and not the other, or described differently, is a divergence to record rather than a
  formatting choice.
- Accessibility: screenshots must show the app at a legible scale; text overlays, if any, meet
  contrast requirements per QUALITY_STANDARDS.md.

**Acceptance criteria** (measurable, traceable):
- AC-1: Play Console shows the Store listing section COMPLETE with no missing mandatory field.
- AC-2: Feature graphic is exactly 1024x500 and at least 2 phone screenshots meet Play's
  dimension rules (mechanically checked).
- AC-3: Every screenshot is demonstrably from an Android build (device frame / aspect ratio /
  content matches the Android UI, not the Windows one).
- AC-4: An explicit claim-by-claim comparison against the Microsoft Store listing is recorded,
  with any deliberate difference justified in one line.

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-UNIT policy gate: assert the feature graphic and screenshot masters
  exist at the recorded paths with correct dimensions. Play rejects wrong dimensions at upload,
  which is a slow feedback loop; a local gate is fast.
- T-2 (verifies AC-4) -- TEST-UNIT policy gate: assert the listing-copy master exists and that
  the recorded claim-comparison section is present and non-empty (structural, not semantic -- it
  forces the comparison to have been DONE and recorded).

**Definition of Done**: default task-level DoD PLUS:
- Harold confirms the listing renders acceptably in Play Console's preview before rollout.

**Model**: Sonnet -- *why not the cheaper tier*: R-4/R-5 require judgment about product claims
across two live store listings, and the copy is public-facing and hard to walk back.

**Executed-by** (filled at completion):

**Step-types**: DATA (assets), DOCS, TEST-UNIT
**Est-Effort**: **35-60m CODING** (DOCS 15-20 for the listing-copy master + TEST-UNIT 4-10 x2 gates,
plus DATA 15-19 for asset processing). **This is the estimate that was most wrong before**: the
previous 480-720m was an hour-anchored guess that counted SCREENSHOT CAPTURE AND COPYWRITING --
both people time, not coding. Capturing screenshots on devices and writing public listing copy are
Harold-side; the coding is the masters, the gates, and the recorded comparison.
_**Risk & rollback**_: public-facing copy. Mitigation is R-4's cross-store comparison and
Harold's preview confirmation. Rollback: listings are editable, though a published listing is
briefly visible.

---

## Task 5 -- GP-17: Tester recruitment and closed-track rollout (Priority 38)

**Value**: This starts the 14-day clock that gates the entire Play launch -- and it cannot start
until Tasks 1-4 are complete.

**Requirements** (numbered, detailed):
- R-1: **Recruitment starts on DAY ONE of the sprint, in parallel with Tasks 1-4.** It is the one
  piece with no dependency, and testers who are not yet found are the schedule risk.
- R-2: Recruit **14-16 testers, not exactly 12**. Opt-out breaks the streak and re-opting-in
  restarts the 14 days from zero, so margin protects the schedule against one person dropping.
  Each needs a Google account and an Android device.
- R-3: The closed-testing track is created and a signed release rolled out to it (the signed
  build already exists from Sprint 64 -- the build was never the blocker).
- R-4: Each tester's opt-in is CONFIRMED, not assumed. Testers count only after they open the
  link AND complete opt-in; an invitation is not an opt-in.
- R-5: The opt-in date per tester is recorded, so the earliest valid production-access
  application date is known rather than estimated.
- R-6: Real tester feedback is collected during the 14 days. Production access is a SUBSTANTIVE
  review asking what testers reported and what changed as a result -- thin or generic answers are
  a documented rejection cause.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- tester roster (roles, not names/emails), opt-in dates,
  earliest application date, feedback log.

**Dependencies / blockers**: **Tasks 1-4 ALL complete** -- Play gates a closed-track rollout on
completed app setup. Harold-driven throughout (recruitment, console actions).

**Non-functional requirements**:
- Security/privacy: the roster records ROLES and opt-in dates, never tester email addresses or
  personal details, in the repo.
- Platform: ADR-0042 **platform exception, deployment infrastructure** -- the Microsoft Store has
  no equivalent tester gate. Recorded as an exception rather than a parity gap; the Windows app
  reached the Store without one and is unaffected.

**Acceptance criteria** (measurable, traceable):
- AC-1: A closed-testing track exists with a rolled-out release.
- AC-2: At least 12 testers (target 14-16) have CONFIRMED opt-in, each date recorded.
- AC-3: The earliest valid production-access application date is computed from the LAST tester's
  opt-in date and recorded.
- AC-4: A feedback log exists and is non-empty by the end of the 14 days.

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-UNIT policy gate: assert the recorded roster contains an opt-in
  date per tester and a computed earliest-application date, and that no email-shaped literal
  appears in the roster (privacy). Structural, but it is what stops the date being guessed later.

**Definition of Done**: default task-level DoD PLUS:
- The 14-day wait itself is NOT part of this sprint's completion. The sprint is done when the
  clock is STARTED and the roster recorded; the application is a Sprint 66 action.

**Model**: Fable/Opus -- *why not the cheaper tier*: live interactive console work with an
irreversible schedule consequence -- a mis-started clock costs 14 days -- plus judgment about
recruitment adequacy and evidence quality.

**Executed-by** (filled at completion):

**Step-types**: DOCS, DATA (console configuration), TEST-UNIT
**Est-Effort**: **15-25m CODING** (DOCS 15-20 for the roster/feedback-log structure + TEST-UNIT 4-10
for the privacy/date gate). Everything else in this task is people time or waiting: recruitment,
console configuration, per-tester opt-in confirmation, and the 14-day external wait. None of it is
coding and none of it belongs in a coding estimate.
_**Risk & rollback**_: the highest-consequence task in the sprint and the least reversible. A
tester dropping out restarts their 14 days; R-2's margin is the mitigation. Rolling out to the
closed track is reversible (halt the release), but the clock is not recoverable.
_**Decision-class interrupts**_: none -- but note that Tasks 1-4 gating this one is a VERIFIED
fact, not a plan assumption. If any of them slips, this task cannot start early.

---

## Manual Validation -- planned steps (to be refined at Phase 5.3)

1. GP-10: Data safety section shows COMPLETE; recorded declarations match the privacy policy.
2. GP-18: every App content item COMPLETE; the reviewer path walked end to end on a real device.
3. GP-7: launcher icon under three adaptive masks on-device; listing icon dimensions and alpha.
4. GP-6: listing preview in Play Console; screenshots confirmed to be Android, not Windows.
5. GP-17: closed track live, opt-ins confirmed, roster and earliest-application date recorded.
6. Regression: the Windows app is unaffected by this sprint (no shared code changes expected --
   confirm rather than assume, since GP-7 touches a shared icon source).

## Sprint totals

**Coding effort (the only thing estimated here, per Harold 2026-09-05): 125-225 minutes.**

| Task | Coding Est-Effort | Dominant step-types |
|------|-------------------|---------------------|
| GP-10 Data safety | 25-45m | DOCS + TEST-UNIT |
| GP-18 App content + App access | 30-55m | DOCS + TEST-UNIT + TEST-WIDGET |
| GP-7 Icons | 20-40m | DATA + TEST-UNIT |
| GP-6 Listing masters | 35-60m | DOCS + DATA + TEST-UNIT |
| GP-17 Roster + rollout records | 15-25m | DOCS + TEST-UNIT |
| **Total** | **125-225m** | |

**Wall-clock ("when can I come back?")**: ~60-110m if the independent tasks run as parallel
sub-agents. GP-6 depends on GP-7's icon; the other three are independent of each other.

**These estimates were rebuilt, not converted.** The first draft gave 1,020-1,740 minutes, which
was hour-anchored guessing -- exactly the error CODING_VELOCITY.md was created to stop (Sprint 39:
"hour-based estimates ran ~10x too high"). The rebuild uses the Estimate Table medians per
step-type, cross-checked against Sprint 64's actuals for comparable work (GP-8+GP-3 DOCS+verify
~50m for two items; SEC-4 NATIVE-AND+TEST-UNIT ~40m; F188 ~57m).

**NOT included in any number above** (Harold's rule: coding estimates only):
- Play Console form entry, listing submission, tester recruitment -- people time.
- Screenshot capture on devices and public listing copywriting -- people time, and the single
  biggest reason the old GP-6 figure was inflated ~12x.
- On-device verification walks (adaptive masks, the reviewer path).
- The 14-day closed-test wait and the subsequent ~7-day production-access review -- external.

- Model mix: 1 Haiku (with a planned review pass), 3 Sonnet, 1 Fable/Opus.

## What this sprint does NOT include

- The production-access application itself (Sprint 66 -- it needs the 14 days to have elapsed).
- GP-4 (CASA verification) -- trigger is 2,500+ users or $5K/yr revenue; not reached.
- Any Windows app change. This sprint is Play-side; the Windows app shipped 0.14.0 to the
  Microsoft Store on 2026-09-05 and is untouched here.

---

## Phase 5 evidence gates

- **5.1.2 F-PRECHECK six classes** (2026-09-06): **four of the six are structurally
  inapplicable this sprint** -- `git diff --stat -- mobile-app/lib` is EMPTY, so no product
  code changed at all. That is not a pass by assertion; it is a pass by there being no
  surface. Class 1 (parallel sites): no product code, so no sibling to fall out of step.
  Class 2 (helper wired into production): no new production helper. Class 4 (fragile
  positional parsing): zero new `split`/`indexOf`/`substring` in `lib/`. Class 6 (silent
  failure): zero new `catch` in `lib/`. The two that DO apply are clean: class 3
  (doc-vs-code drift) -- the 100-character body-preview claim is consistent across
  `PRIVACY_POLICY.md`, `GOOGLE_PLAY_ACCOUNT_SETUP.md` and `LISTING_COPY.md`, checked by
  grep rather than by reading; class 5 (API scope) -- zero new external calls.
  PII sweep across every new tracked file returned only fictional demo-spam addresses.
- **5.1.5 WinWright UI sweep** (2026-09-06, `sweep-head: e9625d6779a0de2aec56e047d32f16dd0aa7f8ea`):
  **2/2 PASSED** (`test_f124_rule_labels` and `test_mt2c_no_rule_sweep`). 3 dialog-settle
  scripts excluded by the runner's own documented policy -- not re-derived (Sprint 52 IMP-3).
  DB drift: none. Note this sweep is a REGRESSION check here, not a verification of sprint
  work: no `lib/ui` file changed, so its value is proving the sprint did not disturb the
  Windows app.
- **5.2 Full suite**: 2,037 passed / 15 skipped / 0 failed (+26 this sprint); analyze clean.
- **5.1.6 Runtime launch gate**: **N/A -- no Android config touched.** The gate's trigger is
  a change to `res/xml/**`, `AndroidManifest.xml`, `build.gradle.kts` or ProGuard rules;
  this sprint changed none of them. Recorded as an explicit N/A rather than skipped
  silently, which is what the gate's own wording requires.
