# Sprint 69 Plan

**Status**: APPROVED -- Harold, 2026-09-11. Blanket execution approval through Manual Validation.
**Branch**: `feature/20260910_Sprint_69`
**Planned**: 2026-09-11
**Scope selected by**: Harold, 2026-09-11 (Phase 8.4 backlog refinement pass 2)

## Sprint Goal

Fix what a closed tester actually hits. Every task in this sprint was found by using the
shipped app on real hardware, and four of the five block or mislead a tester on the build
8 people are running right now.

## Scope

- **F211** -- Google Sign-In fails for every tester (console-side). Priority 2. Est 30-60m.
- **F210** -- Dark-mode contrast: hardcoded surface + colourless text. Priority 6. Est 90-150m.
- **F208** -- YAML Import broken on Android. Priority 8. Est 60-120m.
- **F209** -- Android navigation bar overlaps screen bottoms. Priority 16. Est 120-240m.
- **F203** -- "Found N, evaluated 0" is unexplainable. Priority 22. Est 60-120m.

**Total estimated coding time**: 360-690 minutes (approximately 6 to 11.5 hours), inside
Harold's 6-10h target.

**F212 was DECLINED for this sprint (Harold, 2026-09-11): "next sprint".** It was filed during
planning from the S24+ screenshots and is proposed for Sprint 70 at Priority 4. Harold's
concurrency hypothesis materially improved that card during this same conversation -- see
`ALL_SPRINTS_MASTER_PLAN.md` F212, which now leads with the ScanCoordinator bypass.

**F211 branch decision (Harold, 2026-09-11)**: if R-1 finds a NEW OAuth client is required --
a repo change plus a new Play submission -- **STOP and re-plan**. Do not proceed inside this
sprint. This is recorded in the F211 card's DoD below.

## Standing constraint -- ADR-0042 cross-platform parity (Harold, restated verbatim)

> "everything needs to take into account both the Windows App and the Android app and ADR
> stating that everything should be functionally and UI the same unless it cannot be - and
> where it cannot be it should be implemented as a platform exception for what is needed --
> this applies to all backend code, frontend code, data, architecture, development, security,
> testing, deployment."

Applied per task, honestly:

- **F208 and F209 are ANDROID-ONLY BY NECESSITY**, and both are declared platform exceptions.
  F208: Android resolves `FileType.custom` through MIME types; Windows filters by extension.
  F209: Windows has no system navigation bar. Neither fork is a choice.
- **F210 and F203 are SHARED.** Both touch shared Flutter UI that renders identically on both
  platforms. Fixes must be verified on BOTH, and the F203 empty-state strings live in the
  shared `empty_state.dart` behind one conditional (proven in Sprint 68 after I wrongly
  claimed a platform difference).
- **F211 is console-side**, with no platform surface in the repo.

**One platform exception is anticipated (F209 inset handling) and one is confirmed (F208
picker filter).** Both must be declared in code comments per ADR-0042, not implemented
silently.

## Audit-first findings (MANDATORY per SPRINT_PLANNING.md, Sprint 65 retro IMP-2)

Performed at planning time, 2026-09-11. **Four cards changed:**

- **F210 is FOUR instances, not one.** The card described the Export Successful dialog. A
  tree-wide audit for a `Colors.xxx[NNN]` surface wrapping a `TextStyle` with no `color:`
  found four: `account_selection_screen.dart:825` (`Colors.red[50]`),
  `results_display_screen.dart:416` (`Colors.grey[200]`), `rule_test_screen.dart:383`
  (`Colors.grey[700]`), `safe_sender_quick_add_screen.dart:671` (`Colors.grey[100]`).
  Estimate raised accordingly.
- **F209 is WIDER than "add SafeArea to a few screens".** Only **2 of 23 screens** use
  `SafeArea` at all (`email_detail_view.dart`, `results_display_screen.dart`). This is the
  app-wide default, not a handful of misses. Confirms Harold's "almost all the pages" and
  confirms the fix belongs in a shared scaffold rather than 21 individual edits.
- **F208 is 4 call sites**, all in `yaml_import_export_screen.dart`. Fix once in a helper.
- **F211 may NOT be purely console-side.** `android/app/build.gradle.kts:96` sets
  `manifestPlaceholders["appAuthRedirectScheme"]`, derived from the client id. If the console
  fix requires a DIFFERENT OAuth client, the repo changes too and a new Play submission is
  needed. **R-1 resolves this before any console edit.**

---

## Task 1 -- F211: Google Sign-In fails for every tester (Priority 2)

**Value**: This unblocks the primary sign-in path for every closed tester.

**Requirements**:
- R-1: **Determine FIRST whether the fix is console-only.** Google's error is "Custom URI
  scheme is not enabled for your Android client". If enabling that setting on the EXISTING
  client resolves it, no repo change and no submission are needed. If it requires a new client
  id, `build.gradle.kts:96` and the secrets files change and a Play submission is required,
  which changes this task's cost and the sprint's shape. Resolve this before editing anything.
- R-2: Read the current control name in the Google Cloud Console rather than recalling it.
  Google has relocated this setting before.
- R-3: Verify with a Google account that has NEVER authorised this app. Harold's own accounts
  may carry prior consent that masks the failure.
- R-4: If the in-app error text simply relays Google's opaque 400, make it actionable. A
  tester hitting a dead end should be told that an app password works.

**Affected components / files**:
- Google Cloud Console (primary)
- `mobile-app/android/app/build.gradle.kts:96` -- ONLY if R-1 finds a new client is required
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- record the outcome

**Dependencies / blockers**:
- EXTERNAL, Harold: Google Cloud Console access.

**Non-functional requirements**:
- Security: do NOT widen OAuth scopes while in the console. GP-4 narrowed them deliberately
  and `gmail_scope_parity_test` asserts it.
- Platform: Android only. Windows uses a loopback redirect and is unaffected.

**Acceptance criteria**:
- AC-1: A Google account that has never authorised the app completes sign-in on the
  closed-test build without an app password.
- AC-2: The R-1 determination (console-only vs. new client) is recorded in
  `GOOGLE_PLAY_ACCOUNT_SETUP.md` with the date.
- AC-3: If no repo change was needed, that is stated explicitly. A silent absence is not a
  record.

**Tests to write**:
- T-1 (verifies AC-1) -- MANUAL, Android closed-test build, fresh Google account. No automated
  test can cover a console setting.
- T-2 (verifies no regression) -- TEST-POLICY, existing: `android_client_id_test` and
  `gmail_scope_parity_test` stay green.

**Definition of Done**: default task-level DoD PLUS:
- If R-1 finds a repo change is required, STOP and surface it. That is a Class-3 scope change
  (new Play submission) and needs approval before proceeding.

**Model**: Sonnet -- *why not Haiku*: R-1 is a branching diagnosis whose answer changes the
sprint's scope, not a mechanical edit.

**Step-types**: DOCS, conditionally DATA

**Est-Effort**: 30-60m

### R-1 DETERMINATION (recorded 2026-09-11) -- CONSOLE-ONLY. No repo change required.

> **CORRECTED 2026-09-11, after Harold opened the client.** The "no repo change" half of this
> determination still holds and is unchanged. The "one console setting" half was WRONG, and the
> error is worth naming precisely: I established that the redirect scheme is derived from the
> client id, concluded the fix was the Custom URI scheme checkbox, and never asked whether the
> client was otherwise correctly configured. Reading the client's own page took one screenshot
> and showed **three** problems, not one.
>
> **What the client actually says** (`577022808534-0ejd...`, the id in `secrets.*.json`):
>
> | Field | Console says | The shipped app is | Match? |
> |---|---|---|---|
> | Custom URI scheme | enabled (ticked) | required by `flutter_appauth` | OK |
> | Package name | `com.example.spamfiltermobile` | `com.myemailspamfilter` (`build.gradle.kts:27`) | **NO** |
> | SHA-1 | `F6:CF:21:...:8F:17` | that is `~/.android/debug.keystore` | **NO** for Play builds |
>
> An Android OAuth client is bound to a package name AND a certificate fingerprint. This one is
> configured for a LOCAL DEBUG build of an app whose package name is the unedited Flutter
> template default. Testers run a PLAY-SIGNED RELEASE build of `com.myemailspamfilter`. No field
> matches, so no request from the shipped app has ever reached this client.
>
> **Corroborated by the console itself, which I should have read as evidence rather than
> decoration**: "Last used date: January 17, 2026" and a warning that the client "will be deleted
> because it has not been used for over 6 months or it has no usage data recorded at all." That
> is what zero matching requests looks like.
>
> **Also found**: `google-services.json` registers TWO packages -- `com.example.spamfilter_mobile`
> (a third spelling, with an underscore) and `com.myemailspamfilter` -- and NEITHER records a
> certificate hash. The Firebase side likely needs the same fingerprint once the OAuth client is
> correct. Deliberately not changed in the same pass, so that one variable moves at a time.
>
> **Revised console work** (Harold chose option 1, 2026-09-11):
> 1. Save the Custom URI scheme checkbox. DONE on Harold's screen.
> 2. Change the package name to `com.myemailspamfilter`, and save.
> 3. Add the **Play App Signing** SHA-1 to the client, KEEPING the debug fingerprint so local
>    debug builds still work. Play re-signs the app with its own key, so the fingerprint Google
>    sees at sign-in is Play's, never the local keystore's.
>
> **Open decision, surfaced not decided**: dev builds append `.dev`
> (`build.gradle.kts:119`), so `com.myemailspamfilter.dev` and `com.myemailspamfilter` are two
> distinct packages and ONE OAuth client cannot serve both. Google Sign-In in dev builds needs a
> SECOND Android client. Not required for the tester blocker; recorded so it is a choice rather
> than a later surprise.
>
> **AC-1 still cannot be verified until all three console changes are in place and have
> propagated** (Google states 5 minutes to a few hours), and until it is tested with a Google
> account that has never authorised this app.
>
> **The lesson, for the retrospective**: this is the screenshot rule (Sprint 68 IMP-1) in a new
> costume. I did not misread an artifact -- I declined to look at one at all, and reasoned about
> the client from the code that consumes its id instead. "The fix is console-side" was a
> conclusion about a console I had never opened.


**Answer: the fix needs NO code change, NO rebuild and NO new Play submission.** The
stop-and-re-plan branch Harold set at approval is NOT triggered.

**Evidence**: `android/app/build.gradle.kts:96` computes the redirect scheme from whatever
client id the secrets file supplies --
`manifestPlaceholders["appAuthRedirectScheme"] = "com.googleusercontent.apps.$schemeIdPrefix"`,
where `schemeIdPrefix = resolvedClientId.substringBefore(".")`. Enabling the Custom URI scheme
setting on the EXISTING client leaves the id unchanged, so the manifest, the build and the
published package are all untouched. Only a change of client ID would force a rebuild and a
resubmission.

**R-2 (console wording, verified rather than recalled)**: Google's own developer blog says to
"enable the Custom URI scheme method for your app in the 'Advanced Settings' section of the
client configuration page on the Google API Console". Google disables this BY DEFAULT on
newly-created Android OAuth clients because a custom scheme can be claimed by another app on
the device. Changes take "5 minutes to a few hours" to take effect. Sources cited in
`docs/OAUTH_SETUP.md`.

**Standing migration risk recorded, not acted on**: Google calls Custom URI schemes the legacy
path, recommends the Google Identity Services for Android SDK, and states "In the future, we
may disallow Custom URI scheme methods." No cutoff date is published. Filed as future backlog
rather than sprint work.

**AC-3 compliance**: no repo change was needed for the sign-in fix itself. The code change made
under this task is R-4 only -- the actionable error hint -- which is a separate improvement to
the dead end, not part of the console repair.

**Remaining for Harold (external)**: the console change itself. Steps are in
`docs/OAUTH_SETUP.md`, Android Setup Step 5. AC-1 cannot be verified until that is done and has
propagated.

**Risk and rollback**: Changing the OAuth client could break the app-password path or the
Windows flow. Mitigation: change only the custom-URI-scheme setting and re-verify both paths.
Rollback: revert the console setting.

---

## Task 2 -- F210: Dark-mode contrast, surface plus colourless text (Priority 6)

**Value**: This prevents unreadable text in dark mode and closes the gap that let the F197
gate miss an entire variant.

**Requirements**:
- R-1: **Audit finding -- FOUR instances, not one**: `account_selection_screen.dart:825`,
  `results_display_screen.dart:416`, `rule_test_screen.dart:383`,
  `safe_sender_quick_add_screen.dart:671`. Fix all four.
- R-2: **Extend the F197 detector** in `test/policy/text_contrast_test.dart` to treat a
  `TextStyle` with NO `color:` as theme-derived. That is the valuable half; the four fixes are
  the cheap half.
- R-3: Cover `showDialog` bodies. The original F197 audit looked at cards and containers in
  screens and never at dialogs, which is why `results_display_screen.dart:416` survived.
- R-4: Mutation-verify. Reintroduce a colourless `TextStyle` on a hardcoded surface, confirm
  red, restore, confirm green. Hold a mutation lock while the file is broken.
- R-5: Do NOT widen the existing exemption map to make the new check pass.
- R-6 (ADR-0042): shared Flutter UI. The gate protects both platforms by construction.

**Affected components / files**:
- The four screen files named in R-1
- `mobile-app/test/policy/text_contrast_test.dart` -- extend the F197 group

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: WCAG 2.1 AA per ADR-0037, 4.5:1 for normal text.
- Platform: shared. No exception.

**Acceptance criteria**:
- AC-1: All four instances render at 4.5:1 or better in dark AND light mode.
- AC-2: The gate fails when a hardcoded surface encloses a `TextStyle` with no colour.
- AC-3: The gate still passes on a fully-hardcoded card (Default Folders, measured 7.56:1).
- AC-4: The gate passes against the tree with no new exemptions.

**Tests to write**:
- T-1 (verifies AC-2, AC-3) -- TEST-POLICY, self-check inside the gate, following the file's
  existing convention.
- T-2 (verifies AC-1) -- MANUAL, dark mode, both platforms.

**Definition of Done**: default task-level DoD PLUS:
- Mutation evidence recorded.
- If the detector cannot separate AC-2 from AC-3, STOP and surface rather than adding
  exemptions.

**Model**: Sonnet -- *why not Haiku*: extending a live gate with an exemption map, where the
true/false-positive boundary is the whole difficulty.

**Step-types**: UI-MOVE, TEST-POLICY

**Est-Effort**: 90-150m

---

## Task 3 -- F208: YAML Import broken on Android (Priority 8)

**Value**: This restores the app's only backup-and-restore path on Android.

**Requirements**:
- R-1: The root cause is the MIME filter, NOT the extension format. The code already passes
  dotless `['yaml','yml']`; the plugin's "drop the dot" message is a red herring. Do not "fix"
  the extensions.
- R-2: **Fix once in a shared helper.** Four call sites, confirmed by audit.
- R-3: Prefer `FileType.any` plus post-selection extension validation. The validation is
  needed regardless, since a MIME filter cannot be trusted, and it removes the platform
  difference rather than encoding it. If a platform fork IS chosen instead, declare it per
  ADR-0042.
- R-4: **Test with a REAL exported file** -- export, then import, a full round trip. The
  export half works, so this is the only proof that data is actually restored.
- R-5 (ADR-0042): this is a DECLARED platform exception if forked. Windows must keep working,
  and the no-regression side must be proven.

**Affected components / files**:
- `mobile-app/lib/ui/screens/yaml_import_export_screen.dart` -- 4 `FileType.custom` sites

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: Android-only defect. Windows is unaffected and must stay so.
- Data: import REPLACES all rules of that type. A wrong file must fail validation before any
  replacement occurs.

**Acceptance criteria**:
- AC-1 (behavioral): Given an exported rules YAML on the device, When it is imported on
  Android, Then the rules load and the count matches the export.
- AC-2: A non-YAML file is rejected with a clear message, not a PlatformException.
- AC-3: Windows import still works unchanged.

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-UNIT: extension validation accepts .yaml and .yml, rejects
  others.
- T-2 (verifies AC-1, AC-3) -- MANUAL on both platforms: export then import round trip.

**Definition of Done**: default task-level DoD PLUS:
- Round trip proven with a real file on Android, not a hand-made fixture.

**Model**: Sonnet -- *why not Haiku*: R-3 is a design choice between removing and encoding a
platform difference, on a data path that replaces all rules.

**Step-types**: UI-MOVE, SVC-EDIT, TEST-UNIT

**Est-Effort**: 60-120m

**Risk and rollback**: Import replaces all rules of a type. Mitigation: validate before
replacing and test against a backup. Rollback: re-import the known-good export.

---

## Task 4 -- F209: Android navigation bar overlaps screen bottoms (Priority 16)

**Value**: This makes the bottom of every screen readable and reachable on Android, including
error text that is currently cut off mid-sentence.

**Requirements**:
- R-1: **Audit finding -- this is the app-wide default, not a few screens.** Only **2 of 23**
  screens use `SafeArea` (`email_detail_view.dart`, `results_display_screen.dart`). This
  confirms Harold's "almost all the pages".
- R-2: **Fix in a SHARED scaffold or layout wrapper, not 21 individual edits.** Inventory
  first: confirm whether one shared container covers the affected screens before editing any.
- R-3: Proven non-cosmetic. The Import failure message is cut off mid-sentence by the nav
  buttons. Verify that exact screen after the fix.
- R-4: Android 15 and later enforce edge-to-edge by default, so this worsens on newer devices.
  Handle `MediaQuery.viewPadding.bottom`, not only `SafeArea`, where a scaffold body scrolls.
- R-5: **Gate it.** A widget test asserting bottom content clears `viewPadding.bottom`, or the
  next new screen reintroduces the defect.
- R-6 (ADR-0042): Windows has no system nav bar, so this is a DECLARED platform exception.
  Prove the desktop layout is unchanged.

**Affected components / files**:
- The shared scaffold or layout wrapper, identified at R-2
- `mobile-app/test/widget/` -- new inset test

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: bottom actions must be reachable, not merely visible.
- Platform: Android-shaped. Must not change the Windows layout.

**Acceptance criteria**:
- AC-1: The Import/Export error message is fully readable on the S24+.
- AC-2: Bottom-most content and actions clear the navigation bar on every affected screen.
- AC-3: The Windows layout is unchanged, proven rather than assumed.
- AC-4: A test fails if bottom content is occluded.

**Tests to write**:
- T-1 (verifies AC-4) -- TEST-WIDGET: simulated `viewPadding.bottom`, assert content clears it.
- T-2 (verifies AC-3) -- TEST-WIDGET: desktop no-regression guard, per the ADR-0042
  both-branches rule.
- T-3 (verifies AC-1, AC-2) -- MANUAL on the S24+.

**Definition of Done**: default task-level DoD PLUS:
- The platform exception is declared in a code comment naming WHAT cannot be shared and WHY.

**Model**: Sonnet -- *why not Haiku*: a shared-layout change affecting 21 screens, with a
desktop no-regression bar.

**Step-types**: UI-MOVE, TEST-WIDGET

**Est-Effort**: 120-240m

**Risk and rollback**: A shared-layout change touches every screen. Mitigation: one shared
container, both-branch tests, manual sweep. Rollback: revert the wrapper.

---

## Task 5 -- F203: "Found N, evaluated 0" is unexplainable (Priority 22)

**Value**: This stops the app reporting that nothing was found when messages were found and
deliberately skipped.

**Requirements**:
- R-1: The root cause is known. `email_scanner.dart:330` skips safe-sender emails already in
  the target folder -- do not count, do not display, do not process. Correct behaviour,
  invisible to the user.
- R-2: Surface the skips, for example a `Safe (already filed): N` counter beside the existing
  ones.
- R-3: Fix the empty-state text so it distinguishes "no emails fetched" from "nothing required
  action". `ScanCompleteNoEmailsEmptyState` currently asserts something false.
- R-4: **Do NOT count skipped emails as Processed.** They deliberately are not, and this path
  already carries a Sprint 58 Demo Mode exception. The fix is DISCLOSURE, not recounting.
- R-5 (ADR-0042): **SHARED, both halves.** Both empty-state strings live in `empty_state.dart`
  behind one conditional in `results_display_screen.dart:797-798`, verified in Sprint 68 after
  I wrongly claimed a platform difference. Scope nothing here as Windows-only.
- R-6: F212 (Sprint 70) is the same class of counter dishonesty -- a success message shown
  beside a failed batch. It is NOT in this sprint. Where F203 touches the counter row, leave the
  shape such that F212 extends it rather than rewriting it, but do not implement F212 here.

**Affected components / files**:
- `mobile-app/lib/core/services/email_scanner.dart` -- count the skips
- `mobile-app/lib/ui/widgets/empty_state.dart` -- the message
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the counter row

**Dependencies / blockers**:
- None. (The F212 overlap is noted in R-6; F212 ships in Sprint 70.)

**Non-functional requirements**:
- Platform: shared. No exception.

**Acceptance criteria**:
- AC-1: A scan that fetches N emails and skips all of them reports the skip count, not silence.
- AC-2: The empty-state text never claims no emails were found when some were.
- AC-3: `Processed` still excludes skipped emails.

**Tests to write**:
- T-1 (verifies AC-1, AC-3) -- TEST-UNIT: the skip path increments a skip counter and not
  `Processed`.
- T-2 (verifies AC-2) -- TEST-WIDGET: the fetched-but-all-skipped state renders the correct
  message.

**Definition of Done**: default task-level DoD. No additions.

**Model**: Sonnet -- *why not Haiku*: touches the scanner's counting semantics, where the R-4
distinction is easy to get wrong.

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET

**Est-Effort**: 60-120m

---

## Model assignment summary

- **F211** -- Sonnet. Why not Haiku: R-1 is a branching diagnosis that can change sprint scope.
- **F210** -- Sonnet. Why not Haiku: extending a live gate with an exemption map.
- **F208** -- Sonnet. Why not Haiku: platform-fork design choice on a data-replacing path.
- **F209** -- Sonnet. Why not Haiku: shared-layout change across 21 screens with a desktop
  no-regression bar.
- **F203** -- Sonnet. Why not Haiku: scanner counting semantics.

Planner and analyst tier stays top (Opus) per SPRINT_PLANNING.md.

**Single-session note (Sprint 68 IMP-4)**: if this sprint runs as one continuous interactive
session, execution will be on the session model regardless of assignment. Recorded once here
rather than as five per-task deviations.

## Sequencing

1. **F211** -- 30-60m, unblocks testers, and R-1 may change the sprint's shape (stop-and-re-plan
   if it needs a new OAuth client). Do it first so that branch is known early.
2. **F210** -- self-contained, and the gate extension is the sprint's most reusable output.
3. **F208** -- self-contained.
4. **F203** -- scanner counting plus empty-state text.
5. **F209** -- last. A shared-layout change touching 21 screens is best landed when nothing
   else is in flight, so the manual sweep is against a stable tree.

F210 and F208 are mutually independent and could run in parallel across agents.

## Carry-ins NOT selected (recorded so the drop is visible, not silent)

The Sprint 69 stub written at Phase 7.7 named two items Harold had targeted for this sprint.
Neither is in the approved scope, and that is his call to make, not mine to reverse. They are
recorded here so the change is on the record rather than lost:

- **F202. Per-provider folder defaults** (~6-10h, Priority 10). Targeted at Sprint 69 by Harold
  on 2026-09-09, before the tester findings arrived. It is the largest remaining item on the
  slate and its groundwork is already settled (no migration, no opt-in, a missing folder is not
  an error). **Not selected.** The tester-blocking work displaced it.
- **F192. Custom IMAP Server support** -- host-entry UI (~4-6h, Priority 32). Planned for
  Sprint 69 at the Sprint 68 scope selection. **Not selected.**

No action is requested. If either was meant to stay in, say so at approval and the sprint is
re-planned around it.

## Phase 3.7 approval (CLOSED)

Approved by Harold, 2026-09-11: *"All Sprint tasks and sub-tasks are approved. Continue without
addition approvals until Manual Validation."* Both open questions were answered at approval:

1. **F212**: DECLINED for this sprint -- *"next sprint"*. Moves to Sprint 70 at Priority 4.
2. **F211 branch**: if R-1 finds a new OAuth client is required, **STOP and re-plan**. Do not
   proceed inside this sprint.

Standing approval covers all task execution, commits, pushes to the sprint branch, and PR
updates through Phase 5.3 Manual Validation. The 9 SPRINT_STOPPING_CRITERIA remain the only
valid mid-sprint pauses.

## Phase 5.1 evidence (recorded 2026-09-11, BEFORE Manual Validation)

All three ran at `190a37f`, before Manual Validation was declared. Detail follows each marker.

- **5.1.1 automated code review**: 2026-09-11, `pr-review-toolkit:code-reviewer` over
  `408c84a..HEAD`. **7 findings, 3 CRITICAL, all addressed in-sprint, none deferred.** Two would
  have reached the S24+ (the F178 popup regression and the keyboard overshoot); the third was the
  F210 gate passing vacuously. Fixed in `190a37f`. Full detail below.
- **5.1.2 F-PRECHECK**: 2026-09-11, all six detection actions run against the sprint diff.
  **2 findings, both fixed**: a doc comment describing a message that was never shown, and
  `Platform.pathSeparator` parsing that would print a whole content URI where a file name belongs.
  Classes 1, 2, 5 and 6 clean. Per-class detail below.
- **5.1.5 WinWright sweep**: 2026-09-11, sweep-head `bd4bbc2`. 5 scripts present, 2 run
  (`f56`/`f37` excluded by a documented Class-3 decision). **1 PASS, 1 FAIL**, DB drift none.
  The failure is a selector this sprint never touched and is assessed as pre-existing; recorded
  rather than fixed blind. Detail below.


### 5.1.1 Automated code review -- DONE

Ran `pr-review-toolkit:code-reviewer` over `408c84a..HEAD` (the five task commits). It reported
**7 findings, and 3 of them were serious.** All 7 are addressed; none deferred. Every finding was
reproduced by executing the real code before being accepted, and every fix was re-verified the
same way.

- **CRITICAL 1 -- F209 would have broken the F178 action popup.** The first implementation applied
  raw `Padding` at `MaterialApp.builder`, which sits ABOVE the Navigator and shrank the Stack that
  dialog routes are positioned inside. `results_display_screen.dart` reads insets from the ROOT
  VIEW (`MediaQueryData.fromView`) precisely because inherited MediaQuery gets consumed -- so it
  could not see the shrink, and the popup would have landed 48px high and clipped again. That is
  a direct regression of the Sprint 62 fix Harold found from a screenshot of a clipped "Block
  Subject". **Probe-confirmed at 400x800: popup bottom 704 instead of 752.**
- **CRITICAL 2 -- F209 would have broken every keyboard screen.** The wrapper read `viewPadding`,
  which reports the physical inset regardless of the keyboard. Flutter zeroes `padding` when the
  keyboard covers the navigation bar; `viewPadding` stays at 48. **Probe-confirmed: content at 452
  instead of 500** on every text-entry screen while typing. The doc comment asserting Flutter
  handled this separately was simply wrong.
- **CRITICAL 3 -- the F210 gate passed vacuously on the commonest layout.** `insideMultiLineTextStyle`
  returned true whenever ANY `TextStyle(` appeared in a 6-line window while depth was negative --
  but depth goes negative on the `Container(` the surface itself lives in. So a CLOSED `TextStyle`
  above an unrelated Container made the gate SKIP a genuine pinned surface. **Probe-confirmed
  against the real Export-dialog defect with a label above it: not reported.** The same function
  is in the F197 group shipped in Sprint 68, so that gate had the defect too. Both fixed.
- **IMPORTANT 4** -- `textStyleDeclaresColour` checked `color:` before any bracket bookkeeping, so
  for a single-line `TextStyle` it read the NEXT widget's colour and suppressed a real violation.
  Also removed a 12-line cap that reported a long style as colourless.
- **IMPORTANT 5** -- `insideMultiLineIcon`'s 4-line window was one argument short of a wrapped
  five-argument `Icon`, a false positive that would have blocked correct work.
- **IMPORTANT 6** -- F211's hint matched bare `invalid_request` and `error 400`, generic OAuth2
  codes. A transient token-endpoint 400 (clock skew, expired code, code reused on retry) would
  have told the user to abandon Google Sign-In when a retry would have worked. Narrowed to
  Google-specific phrasing, and the wording now hedges rather than asserting.
- **MINOR 7** -- F208 dropped the "Import cancelled" acknowledgement when the picker was folded
  into a helper. Restored; leaving it silent contradicts F203 in this same sprint.

**Fix summary**: F209 was re-implemented. It now applies `SafeArea` (which reads `padding`, so the
keyboard case is correct, and CONSUMES what it applies, so nested SafeAreas do not double-inset)
around each screen's `Scaffold` rather than above the Navigator, so dialog routes are untouched.
25 sites across 21 files, guarded by a rewritten wiring gate with a per-screen exemption map.

**All three heuristic walks are now DEPTH-terminated rather than line-count-terminated**, and each
is decided by the line that opened the bracket. The three repros are pinned as self-check tests.

### 5.1.2 F-PRECHECK, the six recurring review classes -- DONE, 1 finding

1. **Mirror/parallel-site sync** -- CLEAN. The contrast gate has no PS1 twin. Platform-gated
   assertions checked: the F209 tests drive the branch through `debugIsAndroid` rather than the
   host platform, so they behave identically on the ubuntu CI job.
2. **Helper wired to the PRODUCTION path** -- CLEAN. All four verified by grep:
   `isYamlPath` (`yaml_import_export_screen.dart:397`), `actionableHint`
   (`gmail_oauth_screen.dart:613`), `recordSkippedAlreadyFiled` (`email_scanner.dart:335`),
   `SystemInsetWrapper` (25 screen sites).
3. **Doc-comment-vs-code drift** -- **1 FINDING, FIXED.** The `_pickYamlFile` caller comment said
   the helper "has already said which", but on cancel it said nothing at all. Comment corrected
   and the message restored (Minor 7 above).
4. **Fragile input parsing** -- **1 FINDING, FIXED.** `path.split(Platform.pathSeparator).last`
   would print a whole path where a file name belongs: a Windows path may contain forward slashes,
   and Android content URIs always do. Extracted as `fileNameOf`, splitting on both separators,
   with 5 tests.
5. **API scope vs caller intent** -- CLEAN. No new external or API calls this sprint.
6. **Silent failure** -- CLEAN. The diff adds no `catch` blocks. Confirmed by grepping the added
   lines.

### 5.1.5 WinWright UI sweep -- DONE, with one pre-existing failure

- **Date**: 2026-09-11
- **sweep-head**: `bd4bbc2`
- **Scripts**: 5 present, 2 run. `f56` and `f37` are excluded from the default sweep by
  `run-winwright-tests.ps1:258` -- a documented Class-3 decision (Harold, 2026-06-17) covering
  scripts that cross a dialog-settle boundary the script runner cannot wait on.
- **Result**: 1 PASS, 1 FAIL. **DB drift: none** (rules 3237, safe_senders 623, app_settings 10,
  identical before and after -- the state-restore rule held).
  - `test_f124_rule_labels.json` -- **PASS** (5m04s). Exercises Manage Rules, which F210 touched.
  - `test_mt2c_no_rule_sweep.json` -- **FAIL** at step 9: `Button[name='Clear']` resolved 0
    elements. Steps 1-8 passed, including every account-filter interaction.
- **Assessment of the failure**: NOT caused by this sprint. Sprint 69 did not touch
  `no_rule_review_screen.dart` beyond the F209 Scaffold wrap, and the wrap changes no selector,
  no accessible name and no widget identity. The failing step is a selector resolution for a
  button this sprint never renamed or moved. It is the same shape as the documented
  dialog-settle class: steps 1-8 are read-only interactions and step 9 is the first that acts.
- **Disposition**: filed for investigation rather than fixed blind, because fixing a selector
  without understanding why it moved is how a script quietly stops testing anything. Recorded
  here so the failure is not rediscovered as new.

## Definition of Done (sprint level)

Per `SPRINT_EXECUTION_WORKFLOW.md` Phases 5-7. Additions for this sprint:

- F203 manual validation recorded on BOTH platforms.
- F210 and F209 mutation and no-regression evidence recorded.
- F208 round trip proven with a real exported file on Android.
- Every platform exception declared in a code comment per ADR-0042.
- No un-surfaced Class-1, Class-2, or Class-3 decisions.
