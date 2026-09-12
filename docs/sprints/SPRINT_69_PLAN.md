# Sprint 69 Plan

**Status**: AWAITING PHASE 3.7 APPROVAL (not approved; no task work has started)
**Branch**: `feature/20260910_Sprint_69`
**Planned**: 2026-09-11
**Scope selected by**: Harold, 2026-09-11 (Phase 8.4 backlog refinement pass 2)

## Sprint Goal

Fix what a closed tester actually hits. Every task in this sprint was found by using the
shipped app on real hardware, and four of the five block or mislead a tester on the build
8 people are running right now.

## Scope

- **F211** -- Google Sign-In fails for every tester (console-side). Priority 2. Est 30-60m.
- **F212** -- Re-processing after adding rules fails 100%. Priority 4. Est 120-240m. **NEW, see below.**
- **F210** -- Dark-mode contrast: hardcoded surface + colourless text. Priority 6. Est 90-150m.
- **F208** -- YAML Import broken on Android. Priority 8. Est 60-120m.
- **F209** -- Android navigation bar overlaps screen bottoms. Priority 16. Est 120-240m.
- **F203** -- "Found N, evaluated 0" is unexplainable. Priority 22. Est 60-120m.

**Total estimated coding time**: 480-930 minutes (approximately 8 to 15.5 hours).

**SCOPE ADDITION, surfaced for approval**: Harold selected F211 + F210 + F208 + F209 + F203.
**F212 was filed DURING this planning session** from screenshots supplied with the scope
request, and is proposed at Priority 4. It is a 100 percent failure of the app's primary
workflow on the closed-test build. **This is a Class-3 decision (sprint scope) and needs
explicit approval.** If declined, the sprint is the five originally selected items and F212
moves to Sprint 70.

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
- **F212 is UNKNOWN, and that is the point.** Observed on Android;
  `results_display_screen.dart` is shared code, so Windows is likely affected too and has
  simply not been exercised the same way. **R-1 requires reproducing on Windows before
  concluding it is Android-specific.**
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

**Risk and rollback**: Changing the OAuth client could break the app-password path or the
Windows flow. Mitigation: change only the custom-URI-scheme setting and re-verify both paths.
Rollback: revert the console setting.

---

## Task 2 -- F212: Re-processing after adding rules fails 100% (Priority 4)

**Value**: This restores the app's primary workflow -- review "No rule" mail, add a rule, and
have it actually applied.

**Requirements**:
- R-1: **Reproduce on BOTH platforms before diagnosing.** `results_display_screen.dart` is
  shared code. If Windows also fails, this is a core defect; if only Android fails, the fork
  is itself the finding. Do not assume Android-specific merely because that is where it was
  seen.
- R-2: **Get the exception before designing a fix.** The logger call at
  `results_display_screen.dart:3142` carries it. The outer catch sets
  `failCount = toDelete.length + toMoveSafe.length`, so "6 of 6" and "8 of 8" indicate ONE
  throw, not N independent failures.
- R-3: Evaluate the stale-result hypothesis explicitly. The result set came from a BACKGROUND
  scan, and the closed-test build scans every 15 minutes and really deletes. The messages may
  already be gone when the user acts. If so, the fix concerns staleness, not connectivity.
- R-4: **Fix the contradictory messaging REGARDLESS of the cause.** A green "All 9 'No rule'
  emails addressed." must never appear alongside a failed batch. Same class as F203, so do
  them in one pass.
- R-5 (ADR-0042): shared code. Verify the fix on Windows and Android.

**Affected components / files**:
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- re-process path, approx 3040-3170
- Possibly `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`, depending on
  R-2

**Dependencies / blockers**:
- Needs a reproduction. The device log or a manual CSV export supplies the exception.

**Non-functional requirements**:
- Account-scoping: the re-process path builds a fresh platform per account. Keep it scoped.
- Security: credentials are loaded in this path. Do not log them.
- Platform: shared. No exception anticipated.

**Acceptance criteria**:
- AC-1: The actual exception is recorded in the card and the commit before any fix is written.
- AC-2 (behavioral): Given a scan result containing "No rule" emails, When a blocking rule is
  added, Then the matching emails are acted on and the counter reports the true number.
- AC-3: No success message is displayed when the batch failed, in whole or in part.
- AC-4: Verified on Windows AND Android.

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-UNIT: the re-process path reports a `successCount` matching the
  actions actually executed.
- T-2 (verifies AC-3) -- TEST-WIDGET: a failed batch does not render the "addressed" banner.
- T-3 (verifies AC-4) -- MANUAL, both platforms, recorded in Phase 5 evidence.

**Definition of Done**: default task-level DoD PLUS:
- The root cause is stated in the commit. "Fixed by retrying" without a named cause is not
  done.

**Model**: Fable/Opus -- *why not Sonnet*: unknown root cause in the app's primary workflow,
touching IMAP state and possibly stale-UID semantics. Sprint 38 showed that cursor and state
semantics in this area produce Class-1 decisions.

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET

**Est-Effort**: 120-240m

**Risk and rollback**: Re-processing DELETES real mail on the closed-test build. Test in
read-only mode first; do not iterate against a live mailbox. Rollback: revert the screen file.

**Decision-class interrupts**: if R-3 proves the cause is stale background-scan results, the
fix may change when results are considered valid. That is a Class-1 (data semantics) decision
to surface, not to implement.

---

## Task 3 -- F210: Dark-mode contrast, surface plus colourless text (Priority 6)

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

## Task 4 -- F208: YAML Import broken on Android (Priority 8)

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

## Task 5 -- F209: Android navigation bar overlaps screen bottoms (Priority 16)

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

## Task 6 -- F203: "Found N, evaluated 0" is unexplainable (Priority 22)

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
- R-6: Coordinate with F212 R-4. The same class of counter dishonesty. Do them in one pass.

**Affected components / files**:
- `mobile-app/lib/core/services/email_scanner.dart` -- count the skips
- `mobile-app/lib/ui/widgets/empty_state.dart` -- the message
- `mobile-app/lib/ui/screens/results_display_screen.dart` -- the counter row

**Dependencies / blockers**:
- Overlaps F212 (Task 2). Sequence F212 first so both messaging fixes land together.

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
- **F212** -- Fable/Opus. Why not Sonnet: unknown root cause in the primary workflow, possible
  Class-1 state semantics.
- **F210** -- Sonnet. Why not Haiku: extending a live gate with an exemption map.
- **F208** -- Sonnet. Why not Haiku: platform-fork design choice on a data-replacing path.
- **F209** -- Sonnet. Why not Haiku: shared-layout change across 21 screens with a desktop
  no-regression bar.
- **F203** -- Sonnet. Why not Haiku: scanner counting semantics.

Planner and analyst tier stays top (Opus) per SPRINT_PLANNING.md.

**Single-session note (Sprint 68 IMP-4)**: if this sprint runs as one continuous interactive
session, execution will be on the session model regardless of assignment. Recorded once here
rather than as six per-task deviations.

## Sequencing

1. **F211** -- 30-60m, unblocks testers, and R-1 may change the sprint's shape. Do it first.
2. **F212** -- largest and most valuable. R-2 needs a reproduction that may take wall-clock
   time, so start it early.
3. **F203** -- immediately after F212, so both messaging fixes land in one pass (F212 R-4).
4. **F210** -- self-contained.
5. **F208** -- self-contained.
6. **F209** -- last. A shared-layout change is best landed when nothing else is in flight.

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

## Open questions for Phase 3.7 approval

1. **F212 scope addition**: approve adding it at Priority 4 (recommended), or hold it for
   Sprint 70 and run the five originally selected?
2. **F211 branch**: if R-1 finds a NEW OAuth client is required -- a repo change plus a Play
   submission -- proceed within this sprint, or stop and re-plan?

## Definition of Done (sprint level)

Per `SPRINT_EXECUTION_WORKFLOW.md` Phases 5-7. Additions for this sprint:

- F212 and F203 manual validation recorded on BOTH platforms.
- F210 and F209 mutation and no-regression evidence recorded.
- F208 round trip proven with a real exported file on Android.
- Every platform exception declared in a code comment per ADR-0042.
- No un-surfaced Class-1, Class-2, or Class-3 decisions.
