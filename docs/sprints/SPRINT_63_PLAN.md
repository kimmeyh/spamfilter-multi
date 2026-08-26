# Sprint 63 Plan

**Status**: APPROVED (Harold, 2026-08-25) -- 'All Sprint tasks and sub-tasks are approved.' Cards #357-#365; draft PR #366.
**Dates**: 2026-08-24 start | **Branch**: `feature/20260824_Sprint_63` | **PR**: created at 3.3.1 after approval
**Theme**: Sprint 62 follow-through (E2E coverage, testLimit removal, deferred body fetch, sweep seeding, Android perf truth) + the first four steps of the ACTIVATED Google Play track.
**Scope selected by Harold (2026-08-24, Phase 8.4 pass 2)**: F184 (new -- E2E coverage), F182, F181, F164, F180 (re-scoped per Harold's body-rules feedback), GP-16, GP-5, GP-12, F94.

**GOVERNING CONSTRAINT (Harold, restated at scope selection; ADR-0042)**: everything takes into
account BOTH the Windows app and the Android app -- functionally and UI the same unless it cannot
be, and where it cannot be, implemented as a declared platform exception for exactly what is
needed. Applies to backend code, frontend code, data, architecture, development, security,
testing, deployment. Every card below carries a Platform-parity NFR stating how it complies or
what its declared exception is.

**Deep-dive verification performed at planning (Harold's instruction for the four GP items)**:
every GP/F94 card below was verified against the CURRENT code base, ADRs, and (for GP-16)
current-web Google policy on 2026-08-24. Findings that changed the cards are called out inline.
Two stale-doc corrections were applied during planning: ADR-0033 is Accepted (2026-02-15) -- the
master plan's two "Proposed" rows were stale and are now fixed; the F161 AC-4 carry-over note was
removed (completed in Sprint 62).

**Estimates**: MINUTE-based per `docs/CODING_VELOCITY.md` (recent actuals routinely land at or
under the low end; ranges below are deliberately honest, not padded).

**Task-level Definition of Done**: the default DoD in `SPRINT_PLANNING.md` "Task-Level Definition
of Done" applies to every card; cards list only additions.

---

### Task 1 -- F181: Remove the 50-email testLimit scan-mode option (Priority 18)

**Value**: This removes a user-facing safety promise ("only first 50 emails will be modified")
that the Issue #144 batch architecture no longer keeps -- an unenforced cap is worse than none.

**Requirements** (numbered, from the planning blast-radius inventory -- 48 hits across 11 files):
- R-1: The scan-mode dialog no longer offers or mentions a test-limit; the `_testLimit` field,
  its TextEditingController, the TextField, and the "Only first N emails will be modified" copy
  are removed from `account_setup_screen.dart`.
- R-2: `EmailScanProvider.initializeScanMode` loses its `testLimit:` parameter; `_emailTestLimit`,
  `emailTestLimit`, and the limit fragment of the init log are removed. Before deleting the
  `shouldExecuteAction` cap computation (`email_scan_provider.dart:735-736`), VERIFY whether it
  has any live caller (the F144 verdict-first discipline) -- record the verdict in the completion
  notes either way.
- R-3: DELIBERATE KEEPS (do NOT delete -- legacy data depends on them): the
  `case 'testLimit': return ScanMode.rulesOnly;` legacy parse in `settings_store.dart:852-853`,
  and the historical-value readers `results_display_screen.dart:990` and
  `scan_history_screen.dart:720`. Removing them silently degrades pre-#123/#124 rows and old
  scan records to readOnly. Each keep gets a one-line comment naming F181 and why it survives.
- R-4: The `ScanMode` enum is UNTOUCHED (planning verified no enum value exists solely for
  testLimit -- it was repurposed into `rulesOnly`); no persisted per-account numeric limit exists
  (runtime-only), so NO data migration is needed.
- R-5: All 22 test-side references updated; tests asserting the cap's existence are removed or
  inverted to assert its absence.

**Affected components / files**: `account_setup_screen.dart` (11 hits), `email_scan_provider.dart`
(10), `settings_screen.dart` (2 comments), `settings_store.dart` (1 keep), 5 test files (22 hits).

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform-parity (ADR-0042): all touched code is shared Dart -- identical behavior on both
  platforms by construction; no exception needed.

**Acceptance criteria**:
- AC-1: `grep -rn "testLimit\|_emailTestLimit" mobile-app/lib` returns EXACTLY the three R-3
  keeps (each carrying its F181 keep-comment) and zero other hits -- verified with an
  untruncated grep.
- AC-2: Given a legacy account whose persisted scan_mode string is `'testLimit'`, When settings
  are read, Then the effective mode resolves to `rulesOnly` (not readOnly).
- AC-3: The scan-mode dialog renders no limit field and no 50-email copy at any width; a
  `rulesOnly` scan modifies every matching email in a >50-email set (the cap is genuinely gone,
  not hidden).

**Tests to write**:
- T-1 (AC-1) -- the grep gate recorded in completion notes (process evidence, not a test file).
- T-2 (AC-2) -- TEST-UNIT extend `test/unit/storage/settings_store_test.dart`: legacy-string
  parse still maps `'testLimit'` -> rulesOnly.
- T-3 (AC-3) -- TEST-WIDGET extend the account-setup dialog test: limit field absent; TEST-UNIT
  in `email_scan_provider_test.dart`: >50 actions execute un-capped in rulesOnly mode.

**Definition of Done**: default DoD PLUS: the R-2 `shouldExecuteAction` caller verdict recorded.

**Model**: Sonnet -- *why not Haiku*: the deliberate-keeps vs delete-everything distinction and
the live-caller verdict need judgment across 11 files; a mechanical sweep would delete the
legacy parse and corrupt old data display.

**Step-types**: UI-MOVE + SVC-EDIT + TEST-UNIT + TEST-WIDGET
**Est-Effort**: 45-75m

---

### Task 2 -- F180 (RE-SCOPED): Deferred body fetch -- header-first evaluation, full body on demand (Priority 10)

**Harold's planning feedback, verbatim intent**: body rules must match the ENTIRE body, never a
stub; asks whether body contents can be requested only when needed and discarded on no-match;
notes most filtering is header data. **Planning answers**: (1) bodies are ALREADY discarded after
evaluation (F177 truncates retained records; the peak is in-flight fetch cost, verified -- no
retention leak); (2) yes, IMAP `BODY.PEEK[HEADER]` and Gmail `format=metadata` fetch headers
alone, and a per-message body fetch can follow on demand. (3) Live rule-set measurement
(2026-08-24, dev DB read-only): 3,874 rules = 3,112 header (80.3%) + 30 subject (0.8%) + 732
body (18.9%); the BUNDLED seed set is 100% header rules. So header+subject evaluation decides
most spam without a body, and the ORIGINAL F180 shape (truncate/cap the body) is REJECTED --
this re-scope replaces it.

**Value**: This removes the remaining ~1.0GB scan memory peak (20 full MIME bodies in flight per
chunk) by fetching at most ONE body at a time, only when a message actually needs body-rule
evaluation -- with body matching always against the full body.

**Requirements**:
- R-1: The IMAP chunk fetch becomes headers-first: `BODY.PEEK[HEADER]` for the chunk (subject +
  all headers populate `EmailMessage`; body empty at this stage).
- R-2: Evaluation becomes two-stage inside the existing `evaluateBatch` flow: stage A evaluates
  safe senders + header + subject rules from the header-only record; a message proceeds to stage
  B (body fetch + full evaluation) ONLY IF stage A produced no decisive verdict AND the active
  rule set contains at least one body rule, OR the stage-A matching rule carries body
  EXCEPTIONS (evaluator reads `exceptions.body` -- live count today is 0, but the contract must
  honor it).
- R-3: Stage B fetches ONE message's full body (`BODY.PEEK[TEXT]` or full `BODY.PEEK[]` --
  implementer's call, recorded), evaluates against the FULL body, and releases it immediately;
  retained records stay truncated exactly as F177 built.
- R-4: Gmail adapter mirrors the shape: `format=metadata` (+`metadataHeaders`) for the batch,
  per-message `format=full` on demand -- symmetric with R-1/R-3 (single design, two providers).
- R-5: OUTCOME EQUIVALENCE is the release gate: a pinned test set spanning header-matched,
  subject-matched, body-matched, body-exception, and no-match messages must produce per-message
  verdicts identical to a single-pass full-fetch evaluation. No truncated matching anywhere.
- R-6: When the account's rule set contains zero body rules and no body exceptions (the bundled
  default), stage B must never fire -- assert zero body fetches in that configuration.

**Affected components / files**: `generic_imap_adapter.dart` (`_fetchMessageDetails` fetch site +
a new per-message body fetch), `gmail_api_adapter.dart` (batch format + on-demand fetch),
`email_scanner.dart` (`evaluateBatch` two-stage flow), `rule_evaluator.dart` (stage-scoped
evaluation entry or an evaluation-scope parameter -- three body read sites: `:117`, `:136`,
`:209`), tests.

**Dependencies / blockers**: None (F177's onBatch structure is the foundation and is unchanged).

**Non-functional requirements**:
- Platform-parity (ADR-0042): shared scanner/evaluator; both adapters change symmetrically --
  identical behavior on Windows and Android by construction.
- Memory: peak in-flight full bodies == 1 (plus one chunk of headers); measured claim recorded
  in completion notes from a live scan.

**Acceptance criteria**:
- AC-1: Outcome-equivalence suite (R-5) green, including at least one >kBodyPreviewMaxLength
  body-rule match proving full-body matching.
- AC-2: Fake-adapter test proves the fetch sequence: one header fetch per chunk; body fetches
  only for stage-B messages; zero body fetches under a body-rule-free rule set (R-6).
- AC-3: Live F177-style survival scan (daysBack=0, all folders) completes with peak PSS
  materially below the Sprint 62 ~1.0GB baseline; number recorded.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT new `email_scanner_deferred_body_test.dart`: verdict equivalence
  across the five message classes.
- T-2 (AC-2) -- TEST-UNIT extend `generic_imap_adapter_chunked_fetch_test.dart` + a Gmail fake:
  fetch-sequence assertions.
- T-3 (AC-3) -- live measurement recorded in the plan (Manual Validation step, not a test file).

**Definition of Done**: default DoD PLUS: AC-3 measurement recorded; the stage-B trigger
predicate documented in ARCHITECTURE.md's scan workflow.

**Model**: Fable/Opus -- *why not Sonnet*: cross-adapter protocol redesign with a correctness
gate on rule-evaluation semantics (staged evaluation must be provably outcome-identical,
including the exceptions.body contract); this is the sprint's highest-blast-radius change.

**Step-types**: SVC-EDIT + IMAP + TEST-UNIT
**Est-Effort**: 120-180m
_**Risk & rollback**_: risk = subtle verdict divergence in staged evaluation; mitigation =
equivalence suite written FIRST against the current single-pass behavior, then the refactor must
keep it green. Rollback = the change is additive behind the fetch entry points; reverting the
two adapter fetch sites restores single-pass.

---

### Task 3 -- F184 (NEW): E2E coverage for Sprint 62's new UI (Priority 14)

**Value**: This closes the recorded Sprint 62 coverage gap -- none of the active E2E assets
exercise the F178 bottom-anchored popup, the F175 wait-and-start dialog, or the F176 account
label, so their regressions would only be caught by manual validation.

**Requirements** (grounded in the planning verification of the F99 `integration_test` harness --
which EXISTS with `bootDbOnly`/`bootApp`/`bootAppWithDevDbCopy` + temp-DB isolation guard):
- R-1: F175 wait dialog -- in-VM integration test via `bootDbOnly`: seed one `scan_results` row
  (`status='in_progress'`, `scan_type='background'`, fresh `started_at`), invoke `startRealScan`,
  assert the 'Background scan in progress' dialog with both actions; cover Cancel (no scan
  starts), Wait-and-start (proceeds), and the stale-row negative (row older than
  `ScanCoordinator.scanTimeout` -> no dialog).
- R-2: F178 popup -- in-VM integration test at a compact (<600px) surface with a simulated
  bottom inset: open the email-detail popup from the first row, assert bottom-anchoring within
  the safe area and 'Block Subject' reachable at full scroll (the exact Sprint 62 defect shape),
  complementing the existing widget tests at the integration level.
- R-3: F176 label -- assert `AccountEmailLabel` renders the account email on the Manual Scan
  screen body and the results summary in the same in-VM flows.
- R-4: WinWright: NO new sweep scripts for these surfaces (the wait dialog needs an active
  background scan a replayed script cannot arrange; the popup needs compact-width simulation) --
  record this as the declared division: in-VM integration_test owns these three surfaces.

**Affected components / files**: new `integration_test/sprint62_surfaces_test.dart`-style file
(mirror `sprint52_surfaces_test.dart`'s pattern), `integration_test/helpers/app_harness.dart`
(reuse, no changes expected).

**Dependencies / blockers**: None. (Task 2 changes scanner internals, not these UI surfaces;
still, run this task's tests after Task 2 lands to catch interactions.)

**Non-functional requirements**:
- Platform-parity (ADR-0042): all three surfaces are shared widgets; in-VM integration tests are
  platform-neutral and run on both. Declared exception: WinWright (Windows-only harness) is NOT
  extended -- parity of E2E coverage comes from the shared integration_test suite.

**Acceptance criteria**:
- AC-1: All R-1 branches pass (dialog shown / Cancel / Wait / stale-row negative).
- AC-2: Popup bottom edge within the simulated safe area and Block Subject tappable at full
  scroll at 411-500px widths.
- AC-3: Label assertions pass in the same flows; suite + analyze green.

**Tests to write**:
- T-1..T-3 (AC-1..AC-3) -- TEST-INTEGRATION in the new integration_test file, one group per
  surface.

**Definition of Done**: default DoD PLUS: register F184 in ALL_SPRINTS_MASTER_PLAN.md at
execution (new item created from the Sprint 62 retro carry-in).

**Model**: Sonnet -- *why not Haiku*: the wait-dialog test spans DB seeding, an async top-level
function, and dialog lifecycle; the harness patterns must be followed exactly (temp-DB guard).

**Step-types**: TEST-INTEGRATION
**Est-Effort**: 60-90m

---

### Task 4 -- F182: Deterministic seeding preamble for the WinWright no-rule sweep (Priority 30)

**Value**: This ends the thrice-repeated (Sprints 59/60/62) baseline-rot chore in mt2c -- the
sweep's asserted rows become synthetic constants instead of Harold's live mail.

**Requirements**:
- R-1: A seed step inserts (and a teardown step removes) two synthetic `unmatched_emails` rows
  (+ the parent `scan_results` row and `accounts` FK row if needed) using a reserved synthetic
  domain pair (e.g. `winwright-seed-a.invalid` / `winwright-seed-b.invalid` -- `.invalid` is
  RFC-reserved, can never match live mail or rules).
- R-2: The runner (`run-winwright-tests.ps1`) performs seed before the sweep and unseed after
  (also on failure paths), via the existing sqlite3 approach the DB-snapshot helper already uses.
- R-3: The DB-snapshot drift guard stays authoritative and green: either seed/unseed sits OUTSIDE
  the snapshot window, or the guard's tables are unaffected (`unmatched_emails`/`scan_results`
  are not snapshot tables today -- verify and record).
- R-4: `test_mt2c_no_rule_sweep.json` baselines switch to the synthetic domains; its header
  documents that the data precondition is now self-provisioned; the covered-item sweep must NOT
  collect the synthetic rows (no rule/safe-sender can match `.invalid` -- assert once live).

**Affected components / files**: `run-winwright-tests.ps1`, new `winwright-seed-no-rule.ps1` (or
inline), `test_mt2c_no_rule_sweep.json`, `test/winwright/README.md`.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform-parity (ADR-0042) -- declared exception: WinWright is the Windows-only E2E harness;
  the Android-side equivalent of this screen's coverage lives in the shared integration_test
  suite (`no_rule_review_screen_test` + F184), which needs no seeding preamble (temp-DB).

**Acceptance criteria**:
- AC-1: Full sweep green twice in a row from ANY dev-DB state (including zero live no-rule
  rows), DB drift none, and the dev DB byte-identical on the guarded tables afterward.
- AC-2: mt2c's row assertions reference only the synthetic domains; no live sender remains in
  any committed selector.

**Tests to write**:
- T-1 (AC-1) -- two consecutive live sweep runs recorded (date, pass counts, drift) in the plan.
- T-2 (AC-2) -- grep gate over `test/winwright/*.json` for `@` selectors: only synthetic domains.

**Definition of Done**: default DoD PLUS: sweep artifact with `sweep-head:` recorded (the new
Sprint 63 rule applies to this sprint).

**Model**: Sonnet -- *why not Haiku*: PS1 + sqlite seeding must interlock with the drift guard
and the app's covered-item sweep semantics; a wrong interaction silently corrupts the guard.

**Step-types**: HOOK/tooling + TEST-E2E + DOCS
**Est-Effort**: 45-75m

---

### Task 5 -- F164: Android live-scan performance -- release-vs-debug measured comparison (Priority 28)

**Value**: This replaces an impression ("Android feels slower") with numbers, on the post-F177
pipeline, and decides whether any REAL platform gap exists worth engineering work.

**Requirements**:
- R-1: Build a `--release` APK (post-F177+F180 code) and run the same mailbox/folder scan on the
  emulator as (a) the debug APK and (b) the Windows release build; record per-phase timings
  (connect, fetch, evaluate, persist) from the existing scan logs.
- R-2: Comparison anchor: Sprint 62's measured 181-email / 6m17s debug-APK manual full scan.
- R-3: Verdict recorded in the master plan: either "no genuine gap after removing debug/emulator
  factors -- item CLOSED" or a new, specific follow-up item with the measured hot phase.
- R-4: Serialize builds per the Sprint 62 IMP-3 rule (never Windows + Android concurrently).

**Affected components / files**: none (measurement task); scripts used as-is.

**Dependencies / blockers**: Task 2 (F180) should land first so the measurement reflects the
shipping fetch design. Emulator + Harold's account available.

**Non-functional requirements**:
- Platform-parity (ADR-0042): this task MEASURES parity -- its output is the evidence that the
  shared pipeline performs equivalently, or a declared exception item if it does not.

**Acceptance criteria**:
- AC-1: A table of per-phase timings for debug-APK vs release-APK vs Windows on the same
  mailbox, recorded in the plan completion notes.
- AC-2: The R-3 verdict recorded with the numbers.

**Tests to write**: none (investigation); the deliverable is the measurement record.

**Definition of Done**: default DoD items 1/6/7 apply; no code DoD items.

**Model**: Sonnet -- *why not Haiku*: multi-environment orchestration + interpreting per-phase
logs into an engineering verdict.

**Step-types**: INVESTIGATION + ANDROID-BUILD
**Est-Effort**: 45-75m

---

### Task 6 -- GP-12: Firebase Analytics removal (Priority 24) [DEEP-DIVE VERIFIED]

**Deep-dive result (2026-08-24)**: still needed, smaller than registered. `firebase-bom:34.7.0`
+ `firebase-analytics` remain live deps at `android/app/build.gradle.kts:55-63`; ZERO Dart
consumers (pubspec has no firebase package; the only greps are a doc-comment and a TLD string).
ADR-0030 directs: remove analytics deps, KEEP the google-services plugin and
`google-services.json` (required by Google Sign-In; the plugin runs for every build type, and CI
already injects its stub). ADR-0033 is Accepted (2026-02-15) -- the "reconcile ADR-0033" half of
the re-scope is DONE (its stale master-plan rows were corrected during this planning); what
remains is purely the removal.

**Value**: This executes the accepted zero-telemetry decision -- dead native weight out of the
APK before signing/obfuscation work validates against the final dependency set, and the future
Data Safety form becomes honest by construction.

**Requirements**:
- R-1: Remove the `firebase-bom` platform import and `firebase-analytics` implementation lines
  from `android/app/build.gradle.kts`; KEEP the google-services plugin (both gradle files) and
  the JSON (per ADR-0030:90-92 / ADR-0033:75-77).
- R-2: Debug APK builds and Google Sign-In still works on the emulator (the one behavior the
  kept plugin serves).
- R-3: APK size delta recorded (the analytics runtime is the removed weight).

**Affected components / files**: `mobile-app/android/app/build.gradle.kts:55-63` only.

**Dependencies / blockers**: None. Land BEFORE Task 8 (F94) so flavors are configured against
the final dependency set.

**Non-functional requirements**:
- Platform-parity (ADR-0042) -- declared exception: Android-only build metadata; Windows has no
  Firebase at all, so removal INCREASES parity (zero telemetry both platforms, now structurally).

**Acceptance criteria**:
- AC-1: `grep -n firebase android/app/build.gradle.kts` returns zero dependency hits; the
  google-services plugin lines remain; CI Android job green.
- AC-2: Emulator Google Sign-In completes after the removal.

**Tests to write**:
- T-1 (AC-1) -- the CI Android Build Verification job is the gate (no new test file).
- T-2 (AC-2) -- live emulator check recorded.

**Definition of Done**: default DoD PLUS: APK size before/after recorded.

**Model**: Haiku -- two build-file lines with the keeps explicitly enumerated above; verification
is mechanical.

**Step-types**: ANDROID-BUILD + DOCS
**Est-Effort**: 20-30m

---

### Task 7 -- GP-16: Google Play Developer Account Setup (Priority 20) [DEEP-DIVE VERIFIED -- Harold-driven, Claude preps]

**Deep-dive result (2026-08-24, current-web verification)**: still needed, and the registered
card was MISSING the requirement that now dominates planning: **personal developer accounts
created after 2023-11-13 must run a closed test with >= 12 testers opted in continuously for 14
days before production access** (reduced from 20 in Dec 2024; the 14 days did not change).
Organization accounts are EXEMPT from the tester gate but require a D-U-N-S number (free;
issuance can take days-to-weeks) plus org verification. Both types: $25 one-time, government ID
verification, 2-Step Verification, and (new personal accounts) Android-device verification via
the Play Console app. Sources verified 2026-08-24: Google Play Console Help "Play Console
Requirements", "App testing requirements for new personal developer accounts", "Required
information to create a Play Console developer account".

**Value**: This starts the longest external lead time in the whole Play track (identity
verification + possibly D-U-N-S + possibly a 14-day test window) so nothing else ever waits on
it.

**Requirements**:
- R-1 (Claude): a one-page decision + walkthrough doc `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`
  covering: personal-vs-organization decision (12-tester/14-day gate vs D-U-N-S lead time --
  including that "Kimmey Consulting - Ohio" is already the Microsoft Store publisher identity,
  which argues for evaluating the organization route), the verification artifact checklist (ID,
  payment, 2SV, device), and what the 14-day closed-test gate means for the track's schedule if
  personal is chosen (12 testers must be sourced).
- **DECIDED at approval (Harold, 2026-08-25): PERSONAL account -- no D-U-N-S available; the 12-testers/14-continuous-days closed-test gate is accepted.** The prep doc focuses the personal route; the closed-test window becomes a tracked prerequisite of the first production release (12 testers to be sourced).
- R-2 (Harold): create the account per the doc; record account type, the exact
  requirements Google presented (they change), and verification status.
- R-3 (Claude): record the decision + status in the master plan GP section; adjust downstream GP
  card notes if the account type changes the sequence (personal => a closed-testing milestone
  becomes a tracked prerequisite of the first production release).

**Affected components / files**: new `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md`; master plan GP notes.

**Dependencies / blockers**: External -- Google identity verification timing; Harold's
personal-vs-organization decision (Class-3-adjacent: it changes the track's schedule; the doc
presents both, Harold decides).

**Non-functional requirements**:
- Platform-parity: N/A (store-account infrastructure). Declared exception: inherently
  Android-store-specific, the Windows analogue (Partner Center) already exists.

**Acceptance criteria**:
- AC-1: The decision doc exists with both routes' current requirements and a recommendation.
- AC-2: Account created (Harold) OR the blocking verification step identified and in flight,
  status recorded.

**Tests to write**: none (infrastructure); the doc + recorded status are the deliverables.

**Definition of Done**: default DoD items 1/5/6/7; no code.

**Model**: Haiku for the doc assembly -- *content facts were gathered at planning by the top
tier*; drafting from provided facts is mechanical. Escalate only if Google's flow diverges from
the doc.

**Step-types**: DOCS + EXTERNAL
**Est-Effort**: 30-45m (Claude side) + Harold's session + external verification lead time

---

### Task 8 -- GP-5: Privacy Policy and Legal Documents (Priority 22) [DEEP-DIVE VERIFIED]

**Deep-dive result (2026-08-24)**: still needed, and stronger than registered: a privacy policy
is required by (a) Google Play for ALL apps (listing + Data Safety), (b) the Google API Services
User Data Policy for the Gmail scopes BOTH platforms already use TODAY (including the Limited
Use disclosure), and (c) Microsoft Store listing hygiene. ADR-0030 (Accepted) already fixes the
content pillars: zero telemetry, local-only storage, user's-own-OAuth model, no data sale.

**Value**: This unblocks GP-10 (Data Safety) and GP-6 (listing), closes a latent compliance gap
for the Gmail scopes already in production use, and serves BOTH stores from one document.

**Requirements**:
- R-1: `PRIVACY_POLICY.md` drafted from ADR-0030's decisions: what the app accesses (mailbox
  content via the user's own OAuth/IMAP credentials), what it stores (locally only: rules, scan
  results, credentials in OS-protected storage), what it transmits (nothing to the developer --
  zero telemetry), Gmail API Limited Use disclosure, data deletion (uninstall = deletion; F66
  cross-ref), contact info, effective date.
- R-2: Terms-of-use companion page (short; the app is local-first, no accounts with us).
- R-3: Published at a stable public URL via GitHub Pages from this repo; URL recorded for
  Play (GP-6/GP-10) AND added to the Microsoft Store listing at the next submission.
- R-4: Content review against the CURRENT app behavior (post-Sprint-62), not the ADR alone --
  one pass over AppPaths/credential storage/scan persistence to confirm every claim.
- R-5: Harold reviews and approves the text before publication (outward-facing legal content --
  Class-1-adjacent; drafted then surfaced, never auto-published).

**Affected components / files**: new `docs/legal/PRIVACY_POLICY.md` + `docs/legal/TERMS.md` +
GitHub Pages config; STORE listing notes.

**Dependencies / blockers**: publication URL choice (repo Pages vs a domain -- Harold's call,
presented in the draft); Harold's approval gate (R-5).

**Non-functional requirements**:
- Platform-parity (ADR-0042): ONE policy for the product across both stores and both platforms;
  no per-platform policy divergence.

**Acceptance criteria**:
- AC-1: Draft covers every R-1 pillar with zero claims contradicting the code (R-4 pass
  recorded).
- AC-2: Live URL loads the policy; recorded in the master plan for GP-6/GP-10 consumption.
- AC-3: Harold's approval recorded before the URL goes into any store listing.

**Tests to write**: none; R-4's code-verification pass is recorded as the evidence.

**Definition of Done**: default DoD items 1/5/6/7 PLUS: Harold approval recorded.

**Model**: Sonnet -- *why not Haiku*: legal-adjacent synthesis across ADR-0030, actual code
behavior, and two stores' requirements; wrong claims here are outward-facing.

**Step-types**: DOCS + CONTENT + EXTERNAL
**Est-Effort**: 90-150m

---

### Task 9 -- F94: Android dev/prod flavors (Priority 26) [DEEP-DIVE VERIFIED]

**Deep-dive result (2026-08-24)**: still needed; current state verified: `applicationId`
`com.myemailspamfilter` (:27), NO productFlavors, NO signingConfigs (release still signs with
debug keys -- template TODO at :48-50), the SEC-9 OAuth literal in defaultConfig (:43),
`google-services.json` present with BOTH the legacy `com.example.spamfilter_mobile` and current
`com.myemailspamfilter` clients -- the historical blocker is CLEARED (Sprint 59/F150). No
`.dev`/`.prod` clients exist yet, so suffixed flavors cannot sign in until Harold's four console
registrations land. Windows pattern to mirror: single `APP_ENV` dart-define driving
displaySuffix/dataDirSuffix/logPrefix/mutex (app_environment.dart:23-55; ADR-0035). ALSO found:
`build-with-secrets.ps1` uninstall/launch steps still target the pre-rename package names
(:514-515, :566-571) -- the auto-launch silently no-ops today; folded in as R-5.

**Value**: This gives Android the same dev/prod side-by-side isolation Windows has had since
ADR-0035 -- the build-infrastructure foundation for signing, store packaging, and safe on-device
testing against real accounts.

**Requirements**:
- R-1: `productFlavors { dev { applicationIdSuffix = ".dev" }, prod { } }` (+ a `store` flavor
  only if the Play packaging demands it later -- start with two, matching Windows' dev/prod),
  with `--dart-define=APP_ENV` passed in LOCKSTEP with `--flavor` so AppEnvironment/AppPaths
  agree with the installed package identity.
- R-2: Per-flavor `google-services.json` under `app/src/dev/` and `app/src/prod/` -- GATED on
  Harold's four console registrations (Firebase SHA-1 x2, GCP OAuth client x2, per the F94
  entry). Until they land: the dev flavor may temporarily reuse the base JSON WITHOUT a suffix
  (un-suffixed dev == today's behavior) -- the card ships the flavor MECHANISM with the suffix
  activation explicitly pending the external prerequisite; recorded, not silent.
- R-3: `build-with-secrets.ps1` gains `-Env dev|prod` emitting both `--flavor` and
  `--dart-define=APP_ENV=...` (mirroring `build-windows.ps1 -Environment`); defaults preserve
  today's behavior.
- R-4: Side-by-side install of dev + prod APKs on one emulator verified (distinct app labels
  strongly recommended: `[DEV]` suffix in the launcher label via a flavor manifest placeholder,
  mirroring the Windows window-title suffix).
- R-5: The stale package names in `build-with-secrets.ps1` (:514-515 uninstall, :566/:571
  launch) corrected to the flavor-aware current IDs.
- R-6: The SEC-9 OAuth literal (:43) becomes flavor-aware ONLY if the flavor split forces it
  this sprint; otherwise SEC-9 stays its own next-sprint item (do not scope-creep).

**Affected components / files**: `android/app/build.gradle.kts`, `android/app/src/{dev,prod}/`
(new), `scripts/build-with-secrets.ps1`, docs (ARCHITECTURE Android build section, ADR-0035
cross-ref note).

**Dependencies / blockers**: External -- Harold's four Firebase/GCP console registrations
(R-2); Task 6 (GP-12) lands first so flavors see the final dependency set.

**Non-functional requirements**:
- Platform-parity (ADR-0042): mirrors the Windows ADR-0035 dev/prod split -- same APP_ENV
  dart-define, same suffix semantics, same data isolation intent. Declared exception: Android
  additionally splits applicationId because OS-level side-by-side identity requires it (Windows
  achieves it with mutex + data dir alone).

**Acceptance criteria**:
- AC-1: `flutter build apk --flavor dev --dart-define=APP_ENV=dev` and the prod twin both build;
  dev + prod installed side by side on one emulator, each using its own data directory
  (AppPaths suffix verified from logs).
- AC-2: Given the console prerequisites are still pending, When the dev flavor runs, Then
  Google Sign-In still works via the recorded interim configuration (or the limitation is
  recorded as blocked-external with sign-in verified on the un-suffixed path).
- AC-3: `build-with-secrets.ps1 -Env dev -InstallToEmulator -Run` builds, installs, and LAUNCHES
  the correct package (the stale-name no-op fixed).

**Tests to write**:
- T-1 (AC-1) -- live dual-install verification recorded (screenshots/adb output) -- E2E evidence.
- T-2 (AC-3) -- script run recorded; CI Android job stays green (builds the default flavor).

**Definition of Done**: default DoD PLUS: ARCHITECTURE.md Android build/flavor section added;
CI implication checked (does the CI `flutter build apk --debug` need a `--flavor` now? -- must
stay green either way).

**Model**: Sonnet -- *why not Haiku*: gradle flavor mechanics interlock with google-services
per-variant resolution, dart-define lockstep, and CI; a wrong default breaks every Android build.
*Why not Fable/Opus*: the shape is fully specified above from the deep dive; execution is
well-bounded.

**Step-types**: ANDROID-BUILD + SVC-EDIT(scripts) + DOCS
**Est-Effort**: 90-150m (+ external console time, Harold)

---

## Sprint summary

- **Execution order**: T1 (F181) -> T2 (F180) -> T3 (F184) -> T4 (F182) -> T6 (GP-12) -> T9
  (F94) -> T5 (F164, after F180 so it measures shipping code) ; T7 (GP-16 doc) and T8 (GP-5
  draft) can interleave anytime (docs-only, no code coupling); Harold's external actions (GP-16
  account, F94 console registrations, GP-5 approval) run in parallel.
- **Model mix (cheapest-first)**: Haiku 2 (GP-12, GP-16 doc), Sonnet 6 (F181, F184, F182, F164,
  GP-5, F94), Fable/Opus 1 (F180). Planner/retro stay top-tier per SPRINT_PLANNING.md.
- **Est total (Claude-side)**: ~525-870m (~9-14.5h) -- the largest recent sprint; driven by the
  9-item scope Harold selected. External lead times (Google verification, console registrations,
  potential 14-day closed test) run in parallel and do not block the code tasks.
- **Decision-class interrupts registered**: GP-16 personal-vs-organization (Harold decides from
  the doc); GP-5 publication approval (Harold gates the outward-facing text); F180 re-scope is
  APPROVED BY THIS PLAN'S APPROVAL if granted (it replaces the registered truncation design).
- **Cards + draft PR**: created at Phase 3.3.1 immediately after approval; PR stays DRAFT
  through 7.7.
- **New Sprint 63 process rules in force**: Phase 5 evidence gate (hook 3d) + sweep-at-HEAD
  (3e) now ENFORCED for this sprint; serialized platform builds; inset-test rule.

## Category 13 carry-ins (from Sprint 62 retro) -- disposition
1. E2E coverage for Sprint 62 UI -> **Task 3 (F184)**.
2. Watch CI's first live run on PR #355 -> **DONE before planning** (3/3 green twice).
3. f129-into-mt2c merge -> executed in the Sprint 62 retro; no work remains.

## Manual Validation -- planned steps (to be refined at Phase 5.3)
1. F180 survival scan on Android (daysBack=0, all folders): completes, peak PSS recorded vs the
   ~1.0GB Sprint 62 baseline; verdicts spot-checked against Scan History.
2. F181: scan-mode dialog shows no limit option; a rulesOnly scan on >50 matching emails
   processes all of them.
3. F94: dev + prod side by side on the emulator; launcher labels distinct; data dirs isolated.
4. GP-12: Google Sign-In works post-removal.
5. GP-5 text review + GP-16 account-type decision (Harold).
6. F164 numbers reviewed; verdict agreed.
