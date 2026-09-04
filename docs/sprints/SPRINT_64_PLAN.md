# Sprint 64 Plan

**Status**: APPROVED (Harold, 2026-08-27: "sprint approved as planned"). Standing approval
through Manual Validation per Phase 3.7; the three pre-declared decision points (ADR-0027,
F187 deletion set, GP-5 URL) remain interactive by design.
**Branch**: `feature/20260827_Sprint_64` | **PR**: draft (created at 3.3.1)
**Sprint theme**: Google Play readiness -- account + release-build chain -- plus the body-rules
follow-through trio from Sprint 63 MV.
**Scope selected by Harold (Phase 8.4, 2026-08-27)**: GP-16 (+GP-5 folded), F186, F187, F188,
SEC-9, GP-2, GP-9, GP-8, GP-3, SEC-4 -- all 11 items in one sprint (Harold chose option 1:
Group A + the intact Group B release-build chain together).

**Governing constraint (ADR-0042, restated by Harold at selection)**: everything takes into
account BOTH the Windows app and the Android app; functionally and UI the same unless it
cannot be, and where it cannot, implemented as a platform exception for what is needed --
backend, frontend, data, architecture, development, security, testing, deployment. Per-card
ADR-0042 notes below classify each task as shared or declared-platform-exception.

**Release-build chain rule (from selection discussion)**: SEC-9, GP-2, GP-9, SEC-4 all change
what the signed release AAB IS; GP-8 and GP-3 are verifies OF it. They execute in dependency
order and converge on ONE final signed-minified release-build validation cycle at the end of
Phase 4 -- no interim per-task release validations, and no build-input edits while any build
runs (Sprint 63 IMP-6).

**Store context**: 0.13.0.0 / Submission 20 in certification at planning time; certification
watch is a Phase 8 tail of the PREVIOUS cycle, not sprint scope.

---

## Task 1 -- GP-16 (+GP-5): Google Play account setup -- guided walkthrough + legal publication (Priority 20)

**Value**: This unblocks every Play-side deliverable (uploads, forms, listing) and starts
Google's multi-day identity verification at the earliest possible moment.

**Requirements** (numbered, detailed):
- R-1: Harold is walked step-by-step through creating the PERSONAL Google Play developer
  account per `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (personal route, $25 one-time, no DUNS),
  with the 12-testers/14-day closed-test gate's schedule implications restated at the start.
- R-2: The GP-5 hosting/URL decision is made during the walkthrough (GitHub Pages is the
  recorded default) and the approved `docs/legal/PRIVACY_POLICY.md` + `TERMS.md` are
  published at that URL.
- R-3: Every `[SET AT PUBLICATION -- Harold approval required]` placeholder in both legal
  docs is replaced with the real URL/date and the published copies match the approved text.
- R-4: Account state at sprint end is recorded (verification submitted / verified), including
  any external wait that carries past the sprint.

**Affected components / files**:
- `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` -- walkthrough source; annotate with any step that
  deviated from the guide (guide-accuracy feedback loop).
- `docs/legal/PRIVACY_POLICY.md`, `docs/legal/TERMS.md` -- placeholder fill + publication.
- Hosting target (GitHub Pages branch/settings) per the decision made in R-2.

**Dependencies / blockers**: Harold-driven (payment, identity documents); external Google
verification lead time (multi-day) -- the walkthrough STARTS first for exactly this reason.

**Non-functional requirements**:
- Security: no credentials or identity-document contents ever enter the repo or logs.
- Platform: N/A (console + docs work). ADR-0042: platform exception, deployment
  infrastructure -- Google Play has no Windows counterpart; the Microsoft Store equivalent
  (Partner Center) already exists, so parity holds at the "each store has an account" level.

**Acceptance criteria** (measurable, traceable):
- AC-1: Play Console account exists and identity verification is submitted (or complete).
- AC-2: Privacy Policy + Terms are reachable at a public URL over HTTPS and their text
  matches the Harold-approved drafts (diff = placeholder fills only).
- AC-3: Zero remaining `[SET AT PUBLICATION` markers in `docs/legal/` (untruncated grep).
- AC-4: Account/verification state + the chosen URL recorded in the plan and sprint_status.

**Tests to write**:
- T-1 (verifies AC-3) -- TEST-UNIT in `test/policy/legal_docs_test.dart`: policy gate
  asserting no `[SET AT PUBLICATION` marker remains in `docs/legal/` once the URL is set
  (skips/passes trivially while GP-5 publication has not happened; goes permanent after).
  (Reference: TESTING_STRATEGY.md; intent only.)

**Definition of Done**: default task-level DoD PLUS:
- Publication URL cross-referenced from `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` and the master
  plan GP-10 entry (it is GP-10's input).

**Model**: Fable/Opus -- *why not the cheaper tier*: live interactive walkthrough of an
external console with real payment/identity steps and a publication decision; judgment and
recovery matter more than throughput.

**Executed-by** (filled at completion):

**Step-types**: DOCS, DATA (publication), HOOK-none
**Est-Effort**: 120-240m (Harold-driven pace dominates)
_**Risk & rollback**_: external-service steps are not rollback-able (payment); mitigation is
the written guide + confirming each console step before Harold commits it. Publication is
rollback-able (unpublish/re-publish).

## Task 2 -- F186: Add/update BODY rules through the UI, including via Manage Rules (Priority 22)

**Value**: This enables authoring the body rules that F180/F185 made first-class -- today the
732 live body rules exist only from legacy import and cannot be created in-app.

**Requirements** (numbered, detailed):
- R-1: The manual rule CREATE flow (reached from Manage Rules) gains a Body rule type with
  pattern entry using the same plaintext-to-regex assist the other types have; category/
  sub-type recorded as 'body' (Harold ask 1 and 2, verbatim enumeration 2026-08-26).
- R-2: Create -> display -> edit round-trip: a body rule created in R-1 appears in Manage
  Rules under the Body category (F124 chips), opens in `RuleEditScreen`, and its body
  condition round-trips through the existing `case 'body'` edit path unchanged.
- R-3: The F25 rule tester exercises body patterns against sample bodies for rules created
  via R-1 (verify; extend only if it does not).
- R-4: Follow the sibling pattern of the existing rule types in `ManualRuleCreateScreen` --
  no new abstraction, no opt-in divergence (Sprint 52 IMP-5 sibling-pattern rule).

**Affected components / files**:
- `mobile-app/lib/ui/screens/manual_rule_create_screen.dart` -- add Body type (sibling of
  existing types).
- `mobile-app/lib/ui/screens/rule_edit_screen.dart:378-380` -- existing body edit path
  (verify round-trip; expected no change).
- `mobile-app/lib/ui/screens/rule_test_screen.dart` -- R-3 verify.

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: shared Dart UI -- identical on Windows and Android (ADR-0042: shared, no
  exception). MV checks both.
- Accessibility: new controls follow QUALITY_STANDARDS.md semantics like their siblings.

**Acceptance criteria** (measurable, traceable):
- AC-1: Given Manage Rules -> create rule, When the user selects the Body type, enters a
  plaintext phrase, and saves, Then a rule with a 'body' condition list containing the
  assisted regex exists in the DB and is enabled.
- AC-2: The created rule displays under the Body category chip and re-opens in RuleEditScreen
  with the same body pattern (round-trip byte-equal after normalization).
- AC-3: A scan (or rule-tester run) against a message whose body matches the created pattern
  produces a match; a non-matching body does not (proves F180 defer + F185 decode path
  end-to-end with an authored rule).
- AC-4: Existing rule types' create flow behavior is unchanged (regression AC).

**Tests to write**:
- T-1 (AC-1) -- TEST-WIDGET in `test/widget/manual_rule_create_screen_test.dart`: body-type
  create flow persists a body-condition rule.
- T-2 (AC-2) -- TEST-WIDGET (same file or rule_edit test): created body rule round-trips
  through edit.
- T-3 (AC-3) -- TEST-UNIT in `test/unit/services/` (extend rule evaluator/scanner tests):
  authored-shape body rule matches through evaluateWithoutBody-defer -> full evaluate.
  Isolated single-rule fixture per the Sprint 63 isolated-branch rule.
- T-4 (AC-4) -- TEST-WIDGET: one existing type's create flow still green (regression intent).

**Definition of Done**: default task-level DoD PLUS:
- Mutation-verify T-1/T-3 (break the wiring, confirm red) per feedback_mutation_verify_new_tests.
- WinWright sweep impact check: if selectors on Manage Rules/create screens changed, update
  scripts in the 5.1.5 sweep (lib/ui touched -> sweep-at-HEAD required).

**Model**: Sonnet -- *why not the cheaper tier*: new rule-type surface across the create flow
with regex-assist integration and cross-screen round-trip semantics; beyond a mechanical
Haiku pattern-copy, below Fable-tier design work.

**Executed-by** (filled at completion): Sonnet (as assigned; background agent). COMPLETE
2026-08-28 -- 36/36 widget + 4/4 unit green, full suite 1,965/15/0, analyze clean; T-1 and
T-3 mutation-verified (exactly one red each, reverts byte-clean). Bonus fix in scope-shape:
pre-existing `_isDuplicate()` hardcoded `header_from` category -- now routes by type. R-3
verified: RuleTestScreen already supports body patterns, no change. Recorded deviations:
tests live in existing `test/ui/screens/` path (house convention); T-1/T-4 verify the
confirm-dialog content + exact DB write shape rather than tapping Save end-to-end (a
pre-existing FakeAsync/DB widget-test hazard on this screen, reproduced on the unmodified
sibling path -- honest gap documented; the evaluator path is independently covered by T-3).
Actual ~340m vs 90-150m est: ~110m implementation (in estimate) + ~230m diagnosing the
pre-existing test-harness hazard (velocity row logged).
**MV finding + fix (2026-09-02, Harold option 1 of 3)**: the first real Android create
("a local girl") displayed the internal `manual_a_local_girl_<ms>` name and stored the
bare-space pattern `a local girl`, while the legacy Windows rule showed `a\ local\ girl`.
Regex-equivalent (backslash-space is a literal space), but two gaps: (1) `source_domain`
was left NULL for body rules, and it is the UI display value (`sourceDomain ?? name`), so the
internal name leaked; (2) `RegExp.escape` does not escape spaces, so the text-comparing
duplicate checker could not recognise the 84/85 legacy body rules in the `\ ` form. Fixed:
generator now emits `\ ` for spaces; create screen stores the plain phrase as the display
value, names the rule from the plain phrase, and labels the dialog line "Phrase:" for body
rules. +4 generator unit tests (mutation-verified: escape removal reds exactly the 2 escape
tests), T-1 widget test updated to the new shape; analyze clean. Both platforms rebuilt
(signed prod release APK installed in place on the AVD; Windows dev exe). ~45m.
**Second MV finding (2026-09-03, from Harold's item-5 screenshot)**: the duplicate checker
queried `condition_header` for EVERY category, so a body phrase was compared against a
NULL column and body duplicates were never detected on any platform (the Sprint 64 "bonus
fix" routed the category but not the column). Also learned the Android dev DB holds legacy
body rules in the BARE-space form (`united nations compensation commission`) while both
Windows DBs hold `\ `, so one emitted form cannot text-match both. Fixed: column follows the
category via a fixed map; both sides space-normalized (`REPLACE` on the JSON text, `\ ` ->
space in Dart). +5 checker tests, mutation-verified twice (column routing removed -> 3 red;
Dart-side normalization removed -> 2 red; restored 33/33). Both builds rebuilt again. ~35m.

**Step-types**: UI-MOVE, SVC-EDIT, TEST-WIDGET, TEST-UNIT
**Est-Effort**: 90-150m

## Task 3 -- F187: Remove the personal URL-shape body rules (Priority 24)

**Value**: This removes 647 obsolete link-block body rules from Harold's live rule sets --
and with F180 live, removes the main trigger of deferred body fetches on his real scans.

**Requirements** (numbered, detailed):
- R-1: The removal set is enumerated by PATTERN SHAPE `(?:://|[/.])domain\.tld` (the F33-era
  link-domain blocks), NOT by name prefix (only 306 carry the `body_.` prefix). Measured at
  registration: 647 of 732 body rules in the dev DB; the 85 phrase/phone/address body rules
  are OUT of scope and stay.
- R-2: F33/F144 discipline: present the exact count + samples for Harold's confirmation
  BEFORE deletion; timestamped DB backup before deleting; YAML export invariants preserved;
  post-delete count verification with an UNTRUNCATED query.
- R-3: Applied to BOTH Windows installs (dev `MyEmailSpamFilter_Dev` and prod
  `MyEmailSpamFilter` databases) via a guarded one-time cleanup script.
- R-4: The Android dev DB is NOT separately cleaned this sprint unless Harold asks -- it is a
  test environment seeded from the same lineage; record the decision either way. The
  sprint63_mv_demo rule is explicitly excluded from the removal set (phrase rule, not
  URL-shape; Harold chose to keep it).

**Affected components / files**:
- New guarded script under `mobile-app/scripts/` (pattern: prior F126/F123 live-data repair
  scripts) -- enumerate, back up, delete, verify.
- Harold's live databases (dev + prod) -- DATA, not code.

**Dependencies / blockers**: Harold confirmation of the enumerated set (R-2) at MV or a
mid-sprint natural break.

**Non-functional requirements**:
- Data safety: timestamped backups retained; rollback = restore backup.
- Platform: ADR-0042 shared-data note -- the rule DB schema and script logic are platform
  neutral; execution targets Windows installs where the live data lives (declared exception:
  data residency, not behavior).

**Acceptance criteria** (measurable, traceable):
- AC-1: Dry-run output lists exactly the shape-matched set with count + 10 samples, and
  Harold approves it verbatim before any delete.
- AC-2: Post-delete: shape-matched count = 0; total body rules reduced by exactly the
  approved count; the 85 out-of-scope body rules all still present (untruncated queries).
- AC-3: Backups exist for both DBs with pre-delete counts recorded.
- AC-4: A post-delete full scan on the dev build completes normally (no rule-load errors) --
  and the F180 Step 6a counter shows deferred fetches reduced vs the Sprint 63 baseline.

**Tests to write**:
- T-1 (AC-1/AC-2 logic) -- TEST-UNIT in `test/unit/` or script self-test: the shape matcher
  classifies known URL-shape patterns IN and the phrase/phone/address samples OUT (fixture
  set drawn from real anonymized shapes).
  (The live apply itself is DATA, verified by AC queries, not unit tests.)

**Definition of Done**: default task-level DoD PLUS:
- Both backups' paths recorded in the plan; scratch probes stay out of test/ (Sprint 63 rule).

**Model**: Fable/Opus -- *why not the cheaper tier*: destructive deletion on BOTH of Harold's
live personal databases; asymmetric error cost dominates the mechanical simplicity
(precedent: Sprint 50 live prod-data repairs ran top tier).

**Executed-by** (filled at completion): Fable (main session). COMPLETE 2026-08-28, both DBs:
- Dev (approved 647 set): 647 deleted, 85 keepers, backup f187_backup_20260828_002529,
  untruncated verify 0-remaining PASS.
- Prod: found at DIFFERENT numbers than presented (1470 total / 1300 matched / 170 keep) --
  the per-DB approval discipline (AC-1) STOPPED the apply; analysis showed the 1300 = 368
  distinct link-domains duplicated 2-4x by legacy import eras (same semantic class, all
  single-body-pattern/zero-other-conditions); Harold explicitly approved the prod numbers;
  applied with backup f187_backup_20260828_082559, verify: 0 shape-matched remaining,
  exactly 170 keepers. App confirmed not running at both applies.
- SelfTest fixtures 3-in/5-out green; sprint63_mv_demo rule untouched (phrase class).
- AC-4 (post-delete scan + deferred-fetch delta vs Sprint 63) lands at MV chain validation.

**Step-types**: DATA, SVC-EDIT (script), TEST-UNIT
**Est-Effort**: 45-90m
_**Risk & rollback**_: wrong-set deletion of live rules; mitigated by dry-run + Harold
approval + timestamped backups; rollback = restore backup file.

## Task 4 -- F188: Warn when a rule's condition string is silently neutralized (Priority 26)

**Value**: This prevents a protection the user believes exists from silently not being
evaluated (live-found silent-failure class, F-PRECHECK class 6).

**Requirements** (numbered, detailed):
- R-1: `_decodeJsonArray` (RuleDatabaseStore) logs a WARNING via Logger naming the rule and
  column when condition JSON fails to parse (today: silent empty list).
- R-2: Manage Rules flags a rule whose EVERY condition list is empty as "invalid -- matches
  nothing" instead of rendering it as healthy.
- R-3: One-time integrity sweep at rules load (or a callable maintenance action) counts
  unparseable condition columns and logs the total when nonzero.

**Affected components / files**:
- `mobile-app/lib/core/storage/rule_database_store.dart` -- `_decodeJsonArray` + sweep.
- `mobile-app/lib/ui/screens/rules_management_screen.dart` -- invalid flag rendering.

**Dependencies / blockers**: None. (F187 ordering note: run F188's sweep AFTER F187's
cleanup on live DBs so the sweep baseline reflects the cleaned set -- soft ordering only.)

**Non-functional requirements**:
- Platform: shared Dart -- identical both platforms (ADR-0042: shared, no exception).
- Logging: rule NAMES are fine in logs; no account identifiers (F110 policy unchanged).

**Acceptance criteria** (measurable, traceable):
- AC-1: A rules row with invalid condition JSON produces exactly one Logger warning naming
  rule and column at load, and the rule loads (does not crash the load path).
- AC-2: Given Manage Rules with such a rule present, Then it renders with the invalid
  marker; a healthy rule with a deliberately empty optional list does NOT get the marker
  (marker fires only when ALL condition lists are empty).
- AC-3: The integrity sweep reports the correct count on a fixture DB containing 2 corrupted
  of N rules.

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT in `test/unit/storage/rule_database_store_test.dart` (extend):
  invalid JSON -> warning logged + empty-list load (no throw).
- T-2 (AC-2) -- TEST-WIDGET in `test/widget/`: invalid-flag rendering, both branches
  (isolated fixtures per the Sprint 63 isolated-branch rule).
- T-3 (AC-3) -- TEST-UNIT: sweep count on fixture DB.

**Definition of Done**: default task-level DoD PLUS: mutation-verify T-1 (remove the warning
call, confirm red).

**Model**: Haiku -- (cheapest tier fits: single-store change + one rendering flag with a
clear spec and named sites; escalate on any surprise in the load path).

**Executed-by** (filled at completion): Haiku (background agent) + Fable hardening pass.
COMPLETE 2026-08-28 -- warning + invalid marker + auditUnparseableConditions sweep; suite
1,968/15/0, analyze clean. Main-session verification found the agent's T-1 did NOT assert
the warning (deleting Logger.w stayed green -- the Sprint 63 isolated-branch class);
hardened with an injectable Logger + MemoryOutput assertion, mutation re-run: exactly T-1
red ("expected 1 F188 warning, got 0"), restored, all green. Lesson feeds retro Category 2:
agent mutation claims are verified by re-running the mutation, not by reading the report.

**Step-types**: SVC-EDIT, UI-MOVE, TEST-UNIT, TEST-WIDGET
**Est-Effort**: 30-60m

## Task 5 -- SEC-9: Move hardcoded Android client ID to build-time injection (Priority 28)

**Value**: This removes the per-flavor literal-edit trap in build config and aligns Android
credential handling with the Windows dart-define pattern.

**Requirements** (numbered, detailed):
- R-1: The Android OAuth client id currently embedded in
  `mobile-app/android/app/build.gradle.kts:43` (`appAuthRedirectScheme` placeholder) and any
  Dart-side literal (grep `_androidClientId` -- currently referenced from
  `gmail_windows_oauth_handler.dart`'s family; enumerate ALL sites first, F-PRECHECK class 1)
  is sourced from build-time injection (`--dart-define` via `secrets.*.json` for Dart;
  gradle property/manifest placeholder fed from the same source for the manifest scheme).
- R-2: Design targets the APPAUTH path (the flow that actually consumes the id -- Sprint 63
  finding: google-services.json is NOT consulted by sign-in).
- R-3: Existing behavior is bit-identical when the injected value equals today's literal:
  same redirect scheme, same client id, dev and prod flavors both sign in.
- R-4: A missing injected value FAILS THE BUILD loudly (no silent empty credential -- the
  F119 lesson applied to Android).

**Affected components / files**:
- `mobile-app/android/app/build.gradle.kts:43` -- placeholder sourcing.
- `mobile-app/scripts/build-with-secrets.ps1` -- passes the value per -Env.
- Dart site(s) of `_androidClientId` -- switch to `String.fromEnvironment` per the Windows
  handler pattern (mirror the working sibling).
- `mobile-app/secrets.dev.json.template` -- document the key.

**Dependencies / blockers**: None; MUST land before GP-2/GP-9 validation (part of the
release-build chain -- its build-config edit belongs inside the one validation cycle).

**Non-functional requirements**:
- Security: client id is not a secret (public in the APK by nature) -- the goal is
  maintainability + flavor-correctness, not concealment; record this in the card outcome.
- Platform: ADR-0042 -- mirrors the Windows dart-define mechanism (parity of METHOD);
  manifest-placeholder half is a declared Android platform exception (manifests are
  Android-only).

**Acceptance criteria** (measurable, traceable):
- AC-1: Zero hardcoded client-id literals in gradle/Dart outside the secrets files
  (untruncated grep for the id fragment).
- AC-2: Dev-flavor debug build signs in to Gmail on the emulator exactly as before.
- AC-3: A build invoked without the key fails with an actionable message (R-4 proven).

**Tests to write**:
- T-1 (AC-1) -- TEST-UNIT policy gate (extend `test/policy/`): asserts the literal id
  fragment does not reappear in build.gradle.kts / lib (the F119-style regression pin).
- T-2 (AC-3) -- script-level check in build-with-secrets.ps1 (verified by invocation, not
  Dart test).

**Definition of Done**: default task-level DoD PLUS: live dev-flavor sign-in check at MV
(AC-2 is Harold-observable).

**Model**: Sonnet -- *why not the cheaper tier*: build-injection change with a documented
silent-failure history (F119 family); requires enumerating consumption sites across
gradle/manifest/Dart and designing the loud-fail path.

**Executed-by** (filled at completion): Sonnet (background agent). COMPLETE 2026-08-28 --
4 consumption sites enumerated (+1 dead reference: the manifest embedded the literal
directly, so the gradle placeholder was never referenced -- pre-existing bug, fixed);
release builds FAIL loudly without the property, debug/CI warn + obvious placeholder (F127
alignment); merged-manifest scheme verified BYTE-IDENTICAL to the pre-change literal; dev
APK build-verified; policy gate 8/8, all gates 42/42, suite 1,978/15/0, mutation-verified.
Two real defects caught only by the actual build (XML comment syntax; suffix leak into the
scheme). Deviation: local secrets.dev.json had a STALE mismatched ANDROID_GMAIL_CLIENT_ID
value (F94-era) -- corrected locally to the working literal. AC-2 live sign-in check
deferred to MV per DoD. ~130m vs 30-60m est (defect diagnosis; velocity row logged).

**Step-types**: SVC-EDIT, HOOK (build script), TEST-UNIT, DOCS
**Est-Effort**: 30-60m
_**Risk & rollback**_: broken sign-in if a site is missed; mitigated by the all-sites grep +
AC-2 live check; rollback = revert commit (no data involved).

## Task 6 -- GP-2: Release Signing and Play App Signing (Priority 30)

**Value**: This enables ANY Play upload (closed test included) -- nothing ships unsigned --
and decides ADR-0027.

**Requirements** (numbered, detailed) -- CORRECTED at execution (2026-08-28): ADR-0027 was
found already ACCEPTED (2026-02-15) with Option B decided -- build-time keystore injection
via the build-with-secrets.ps1 pattern, key.properties explicitly REJECTED (its Option A),
Play App Signing enrollment, AAB for Play + APK for testing. The card as planned assumed a
Proposed ADR and the key.properties shape; the card is corrected to EXECUTE the accepted
decision (the GP-12 pattern -- no new architecture decision is being made):
- R-1: Create the upload keystore with Harold (he holds the passwords; keystore stored
  OUTSIDE the repository with documented location + backup guidance).
- R-2: `signingConfigs` in `build.gradle.kts` sources keystore path/alias/passwords from
  build-time parameters (environment variables / gradle -P) supplied by
  `build-with-secrets.ps1` at release-build time -- per the accepted ADR, NO key.properties
  file (`build.gradle.kts:79` currently debug-signs release: the exact line this replaces).
- R-3: Play App Signing enrollment (Google holds the app signing key; ours = upload key) is
  the ADR's accepted choice -- happens at first Play Console upload; record enrollment
  outcome when it occurs.
- R-4: `.gitignore` covers `*.jks`/`*.keystore` BEFORE the keystore exists (order matters).
- R-5: Both flavors x debug/release still build; debug behavior unchanged; release build
  FAILS loudly when signing parameters are absent.

**Affected components / files**:
- `mobile-app/android/app/build.gradle.kts` -- signingConfigs + release signingConfig swap.
- `mobile-app/android/key.properties` (NEW, gitignored), keystore file (outside repo).
- `.gitignore`, `docs/adr/0027-*.md`, `mobile-app/scripts/build-with-secrets.ps1` (release
  path passes nothing secret -- gradle reads key.properties directly).

**Dependencies / blockers**: Harold for keystore passwords + the ADR-0027 decision (Class-1
surface: "This would decide ADR-0027: upload-key + Play App Signing. Should I proceed?" at a
natural break). Part of the release-build chain.

**Non-functional requirements**:
- Security: keystore + passwords never in repo/logs; loud build failure if key.properties
  missing for a release build (debug unaffected).
- Platform: ADR-0042 declared exception -- Android release signing has no Windows
  counterpart (MSIX signing is Store-managed); parity holds at the "store manages final
  signing" level (Play App Signing chosen for exactly that symmetry).

**Acceptance criteria** (measurable, traceable):
- AC-1: `flutter build appbundle --flavor prod` (with dart-defines per Sprint 64 chain)
  produces an AAB signed by the upload key (verified via apksigner/keytool fingerprint).
- AC-2: Release build FAILS with an actionable message when key.properties is absent; debug
  builds remain unaffected.
- AC-3: ADR-0027 status Accepted with the Play App Signing decision recorded.
- AC-4: No keystore/password material in git (untruncated grep + git status accounting).

**Tests to write**:
- T-1 (AC-4) -- TEST-UNIT policy gate (extend `test/policy/`): no key.properties/keystore
  path committed; gitignore rule present.
  (AC-1/AC-2 are build-invocation verifications recorded in the plan, not Dart tests.)

**Definition of Done**: default task-level DoD PLUS: fingerprint of the upload key recorded
in the plan (public info, needed later for API console registrations).

**Model**: Fable/Opus -- *why not the cheaper tier*: carries the ADR-0027 architecture
decision + release-credential handling design (Class-1 adjacent); the gradle mechanics alone
would be Sonnet, the decision record is what pulls the tier.

**Executed-by** (filled at completion): Fable (main session). COMPLETE 2026-08-28 --
gradle signingConfigs from four signing parameters per the accepted ADR-0027 Option B
(key.properties correctly NOT used); release-without-params throws (proven by direct gradle
invocation); debug path proven unaffected; build-with-secrets.ps1 injects from the
outside-repo signing JSON, gains -Output aab; .gitignore + policy gate
android_signing_test.dart (4 tests, incl. git ls-files scan); ADR-0027 implementation note;
suite 1,982/15/0 (one flaky-red run traced to my gradle dry-runs executing DURING the
suite -- retro note: serialize gradle invocations against test runs).
CEREMONY + PROOF (2026-08-28 morning): Harold created the upload keystore (regenerated once
for a stronger password; old file deleted pre-upload so zero consequence) + signing JSON;
JSON-opens-keystore verified via keytool -list without displaying secrets. LIVE DEFECT
found on first real use: the -P command-line injection was EATEN by the flutter .bat shim
when the password contained cmd metacharacters (&) -- switched to ENVIRONMENT-VARIABLE
injection (gradle's documented fallback), which also keeps secrets out of process command
lines; cleared in the script's finally. First genuinely-signed AAB built:
app-prod-release.aab 55.85 MB; **AC-1 PASS: keystore cert SHA-256 == AAB signer SHA-256
(68:75:8B:9B:7B:EB:CE:0E:C3:EA:3F:A4:05:12:1F:0D:0A:9A:D8:35:01:62:67:5C:61:C3:4C:DA:AD:CD:49:58)**.
Play App Signing enrollment happens at first upload (Sprint 65). Harold's DPAPI-vs-plaintext
storage decision for the signing JSON: OPEN at completion (asked; env-var change already
removed command-line exposure) -- carry to MV/retro if unanswered.

**Step-types**: SVC-EDIT, NATIVE-AND (gradle), DOCS (ADR), TEST-UNIT
**Est-Effort**: 120-240m (includes Harold keystore + ADR interaction)
_**Risk & rollback**_: losing the upload key = Play recovery process (mitigated by Play App
Signing + documented backup); a leaked keystore = rotate via Play Console. Rollback of the
gradle change = revert commit.

## Task 7 -- GP-9: ProGuard/R8 + Dart obfuscation (Priority 32)

**Value**: This prevents our FIRST minified build from being the Play submission itself --
minification breakage gets found and fixed this sprint, inside our own validation cycle.

**Requirements** (numbered, detailed):
- R-1: Release builds enable R8 (`isMinifyEnabled = true`, `isShrinkResources = true`) with a
  `proguard-rules.pro` covering our plugin set (appauth, sqlite/sqflite, workmanager,
  flutter_secure_storage, mail libs -- enumerate from pubspec).
- R-2: Dart-side `--obfuscate --split-debug-info=<dir>` wired into the release build path of
  `build-with-secrets.ps1` (and documented for the AAB command); symbol files retained
  outside the repo, path recorded.
- R-3: Debug builds unchanged (no minification).
- R-4: The FULL app surface is exercised on the minified release build at validation:
  sign-in (both providers), scan, rules CRUD incl. the new F186 body create, background scan
  registration -- reflection breakage hides in rarely-exercised paths.

**Affected components / files**:
- `mobile-app/android/app/build.gradle.kts` -- release buildType minify/shrink + proguard ref.
- `mobile-app/android/app/proguard-rules.pro` (NEW).
- `mobile-app/scripts/build-with-secrets.ps1` -- obfuscation flags on release.

**Dependencies / blockers**: After GP-2 (signing config exists first so the validation build
is the real artifact shape). Part of the release-build chain.

**Non-functional requirements**:
- Platform: ADR-0042 declared exception -- R8 is Android-only; Windows release has no
  equivalent step (Dart obfuscation applies to both in principle; Windows adoption is NOT in
  scope -- note for a future refinement item rather than silent divergence).
- Crash triage: split-debug-info symbols retained so obfuscated stack traces stay readable.

**Acceptance criteria** (measurable, traceable):
- AC-1: Signed prod-flavor release AAB/APK builds with R8 on; size delta recorded.
- AC-2: The R-4 surface list passes on the minified build on-device/emulator with zero
  runtime errors attributable to minification (logcat clean of ClassNotFound/NoSuchMethod).
- AC-3: Debug build behavior/config unchanged (diff of debug buildType = none).
- AC-4: Symbol files exist for the built version at the recorded path.

**Tests to write**:
- T-1 -- the validation checklist itself (AC-2) recorded step-by-step in the plan; no Dart
  test can see minification. TEST-INTEGRATION intent: existing suite still runs against
  non-minified debug (unchanged) -- minified verification is manual/scripted on-device.

**Definition of Done**: default task-level DoD PLUS: proguard-rules.pro entries each carry a
one-line reason comment (no cargo-cult rules).

**Model**: Sonnet -- *why not the cheaper tier*: plugin-reflection breakage diagnosis across
the dependency set is investigative; a Haiku rule-file copy risks cargo-cult keep rules.

**Executed-by** (filled at completion): Sonnet (background agent). CODE COMPLETE 2026-08-28
-- per-plugin audit (15 native packages, consumer-rules checked in each package cache)
produced exactly ONE keep rule (workmanager: WorkManager instantiates BackgroundWorker by
name via reflection; silent background-scan failure class), all exclusions reasoned in the
file header. Verified by a REAL minified signed release build (throwaway scratchpad
keystore, deleted after): 67.4MB vs same-commit unminified 77.3MB (-12.8%), mapping.txt
present, missing_rules EMPTY. Dart --obfuscate/--split-debug-info wired, symbols outside
repo. AC-2 on-device surface validation deferred to chain validation as planned. Suite
1,985 green (run strictly serialized after builds). ~75m, in estimate.

**Step-types**: NATIVE-AND (gradle), SVC-EDIT (script), TEST-INTEGRATION (on-device)
**Est-Effort**: 60-150m
_**Risk & rollback**_: runtime breakage on minified builds only; rollback = flip
isMinifyEnabled off (one line) while keeping rules for retry.

## Task 8 -- GP-8: Android Target SDK + 16 KB Page Size -- verify (Priority 34)

**Value**: This surfaces any Play-requirement gap (target API level, 16 KB page-size native
alignment) THIS sprint, while a fix still has runway before submission.

**Requirements** (numbered, detailed):
- R-1: Resolve and record the EFFECTIVE compileSdk/targetSdk/minSdk (build.gradle.kts uses
  `flutter.targetSdkVersion` indirection -- resolve the actual numbers from the toolchain).
- R-2: Check against CURRENT Play requirements (verify the requirement itself from Google's
  documentation -- target API level policy and the 16 KB page-size mandate timeline -- do not
  answer from memory).
- R-3: 16 KB check: verify all packaged native `.so` libraries (ours + plugins) are 16
  KB-aligned per Google's guidance on the release AAB from the chain build.
- R-4: Findings-only task: any gap found becomes a fix item (in-sprint if small per stopping
  criterion 4a, else carded for Sprint 65 with the measurement attached).

**Affected components / files**: none expected (verify); report lands in the plan.

**Dependencies / blockers**: Runs against the chain's release AAB (after GP-2/GP-9).

**Non-functional requirements**: Platform: Android-only verify (ADR-0042 exception:
platform-requirement compliance).

**Acceptance criteria** (measurable, traceable):
- AC-1: Effective SDK numbers recorded with the resolution evidence.
- AC-2: Pass/fail verdict against the verified-current Play requirements, each with a source
  link and checked-date.
- AC-3: 16 KB alignment result per packaged .so listed (untruncated).

**Tests to write**: none (verify task; evidence recorded in plan).

**Definition of Done**: default DoD items 1/7/8 apply; test items N/A (no code change).

**Model**: Haiku -- (verify-and-report with an explicit method; escalate only if a gap needs
design).

**Executed-by** (filled at completion): Fable (main session; ran directly against the chain
artifact rather than spawning an agent). COMPLETE 2026-08-28, verdict **PASS on all
requirements**:
- Effective SDKs from the merged release manifest: **targetSdk 36, minSdk 24** (resolved
  from flutter.targetSdkVersion by the current toolchain).
- Requirement (verified from Google's pages, checked 2026-08-28): new apps submitted after
  Aug 31, 2026 must target **API 36**; extension to Nov 1, 2026 available. WE ALREADY
  TARGET 36 -- no gap (sources: Play target-API policy pages, support.google.com answers
  11926878/16561298).
- 16 KB page size (required for API 35+ targets; update deadline Feb 1, 2027): `zipalign -c
  -P 16 -v 4` = "Verification successful"; ELF LOAD alignment, ALL 64-bit libs, untruncated:
  arm64-v8a libapp.so 2**16, libflutter.so 2**16, libsqlite3.arm64.android.so 2**14;
  x86_64 libapp.so 2**16, libflutter.so 2**16, libsqlite3.x64.android.so 2**14 -- all at or
  above the 2**14 requirement. PASS.
- No fix items produced; nothing carried to Sprint 65 from this verify.

**Step-types**: DOCS (verification report), NATIVE-AND (inspection)
**Est-Effort**: 30-60m

## Task 9 -- GP-3: Android Manifest Permissions -- merged-manifest verify (Priority 36)

**Value**: This prevents a Play review rejection from a stray transitive-plugin permission
nobody declared on purpose.

**Requirements** (numbered, detailed):
- R-1: Produce the MERGED release manifest for the prod flavor (gradle merged-manifest
  output from the chain build) -- not the source manifest.
- R-2: Every permission in it is classified: required (with the feature that needs it) or
  unexpected (with the contributing library via manifest-merger blame).
- R-3: Unexpected permissions are removed (`tools:node="remove"`) or justified in writing;
  removals re-verified on the merged output.
- R-4: The final permission list is recorded as the input for GP-10's Data Safety form.

**Affected components / files**:
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- only if removals needed.
- Report in the plan (GP-10 input).

**Dependencies / blockers**: Chain build (after GP-2/GP-9 so the merged output is the real
artifact's).

**Non-functional requirements**: Platform: Android-only (ADR-0042 exception: manifests).
Windows parity note: capabilities in the MSIX manifest are the Windows analogue and are
already minimal (internetClient family) -- record the comparison line in the report.

**Acceptance criteria** (measurable, traceable):
- AC-1: Merged-manifest permission list captured verbatim (untruncated) with per-permission
  classification.
- AC-2: Zero unexpected permissions remain unhandled (removed or written justification).
- AC-3: Post-removal merged manifest re-captured proving removals took effect.

**Tests to write**: none mandatory (verify task); optional policy pin if a removal lands
(assert the removed permission stays absent from the merged output is build-level, not Dart).

**Definition of Done**: default DoD items 1/7/8; report cross-linked from GP-10's master-plan
entry.

**Model**: Haiku -- (mechanical extract-classify-report with a defined method; merger-blame
reading is documented gradle tooling).

**Executed-by** (filled at completion): Fable (main session; ran directly against the chain
artifact). COMPLETE 2026-08-28. Merged RELEASE manifest captured (untruncated): 12
permissions found, 9 required-and-justified (POST_NOTIFICATIONS F161; INTERNET IMAP/OAuth;
FOREGROUND_SERVICE + SHORT_SERVICE, WAKE_LOCK, RECEIVE_BOOT_COMPLETED workmanager; VIBRATE
notifications; ACCESS_NETWORK_STATE connectivity_plus; DYNAMIC_RECEIVER_NOT_EXPORTED
androidx self-permission), 3 UNEXPECTED with merger blame: NFC (com.yubico.yubikit) and
USE_BIOMETRIC + USE_FINGERPRINT (androidx.biometric), all transitive via msal_auth whose
code path is dead (outlook_adapter fully commented out). REMOVED via tools:node="remove"
with written justification in the manifest; post-removal merged manifest re-captured:
exactly the 9 justified remain. This final permission list is GP-10's Data Safety input.
Bonus lesson: my removal comment initially used the house double-hyphen and broke the XML
parse -- the same defect class the SEC-9 agent documented an hour earlier; comment now
warns against "fixing" the punctuation. Windows-parity note: the MSIX capability set
(internetClient family) remains the minimal Windows analogue.

**Step-types**: NATIVE-AND (inspection), DOCS
**Est-Effort**: 30-60m

## Task 10 -- SEC-4: Android network_security_config.xml (Priority 38)

**Value**: This makes TLS-only network policy explicit and Play-reviewer-visible instead of
implicit in library defaults.

**Requirements** (numbered, detailed):
- R-1: `network_security_config.xml` declaring cleartext traffic DISABLED app-wide (no
  per-domain exceptions -- IMAP/OAuth endpoints are all TLS; localhost OAuth loopback is
  Windows-only and does not exist on Android's appauth flow -- verify this claim against the
  Android sign-in flow before finalizing, and add the loopback exception ONLY if the verify
  proves it needed).
- R-2: Referenced from the application element of the manifest.
- R-3: Live verification on-device: Gmail sign-in + AOL IMAP scan still work with the config
  active (proves no hidden cleartext dependency).

**Affected components / files**:
- `mobile-app/android/app/src/main/res/xml/network_security_config.xml` (NEW).
- `mobile-app/android/app/src/main/AndroidManifest.xml` -- `android:networkSecurityConfig`.

**Dependencies / blockers**: Part of the release-build chain (manifest edit -- lands before
the final validation cycle).

**Non-functional requirements**: Platform: Android-only mechanism (ADR-0042 exception);
parity note: both platforms are TLS-only in behavior -- this makes Android's declaration
explicit.

**Acceptance criteria** (measurable, traceable):
- AC-1: Config present, referenced, and `cleartextTrafficPermitted="false"` effective
  (merged-manifest + resource verified in the chain build).
- AC-2: R-3 live checks pass on the release-chain build.

**Tests to write**: none mandatory (config + live verify); the GP-3 merged-manifest capture
doubles as AC-1 evidence.

**Definition of Done**: default DoD.

**Model**: Haiku -- (single config file + manifest attribute with a written spec; the one
judgment point (loopback) has an explicit verify instruction).

**Executed-by** (filled at completion): Haiku (background agent) + Fable chain-validation
fix. Agent code 2026-08-28 (~40m): loopback verify solid, manifest wiring correct -- but the
config file itself was WRONG TWICE: root element domain-config (runtime-invalid; must be
network-security-config) scoped to a literal example.com (not app-wide). AAPT accepted it
(well-formedness only); the app CRASHED AT STARTUP on the first real launch of the chain
build ("Failed to parse XML configuration from network_security_config") -- caught by chain
validation within minutes, exactly the step designed to catch it. Fable fix: correct
base-config structure with a structure-note comment; policy gate hardened from
attribute-grep to structure pins (network-security-config root + base-config +
no-domain-config, comments stripped before matching; 4/4 green; mutation-equivalent proof =
the live crash itself). Fixed build relaunched: process stable, Flutter engine up. Retro
Cat-2 seed: a Haiku config task with a runtime-only failure mode needs either a
structure-pinning gate up front or an immediate launch check -- attribute greps prove
existence, not validity (source-gates-verify-shape, third instance this sprint).

**Step-types**: NATIVE-AND, DOCS
**Est-Effort**: 20-40m

---

## Execution order and the single validation cycle

1. **Task 1 GP-16 (+GP-5) FIRST** (Harold's fixed decision) -- starts Google's external
   verification clock; Harold-driven.
2. Group A parallel-friendly: Task 2 (F186), Task 4 (F188), then Task 3 (F187 -- needs
   Harold's set confirmation; F188 sweep runs after F187's cleanup).
3. Release-build chain in order: Task 5 (SEC-9) -> Task 6 (GP-2) -> Task 7 (GP-9) -> Task 10
   (SEC-4) -> ONE signed-minified prod-flavor release build -> Task 8 (GP-8 verify) + Task 9
   (GP-3 verify) against that artifact -> full on-device validation list (GP-9 R-4).
4. No build-input edits while any build runs; Windows and Android builds serialized.

## Sprint-level notes

- **Model summary**: Fable/Opus 3 (Tasks 1, 3, 6 -- walkthrough judgment, live-data
  deletion, ADR decision), Sonnet 3 (Tasks 2, 5, 7), Haiku 4 (Tasks 4, 8, 9, 10).
  Cheapest-first walked per card; "why not cheaper" on every non-Haiku line.
- **Est total**: 575-1,060m coding/verify (~10-18h) plus Harold-driven walkthrough pace.
- **Decision-class interrupts known in advance**: ADR-0027 signing decision (Task 6,
  Class-1, surfaced at a natural break); F187 deletion-set confirmation (Task 3, data
  approval); GP-5 hosting URL (Task 1, in-walkthrough).
- **Architecture Impact Check (3.6.1)**: ADR-0027 decided in-sprint (Task 6);
  ARCHITECTURE.md gains the Android release-build chain (signing/R8/netsec) section;
  ADR-0042 exception register grows by the declared exceptions above; no other ADR touched.
- **Carry context**: 0.13.0.0/Submission 20 certification watch is Phase 8 tail work, not
  sprint scope. F94 console-prereq re-scope note stands in the master plan (SEC-9 R-2
  embodies the appauth finding).
- **MV preview (refined at 5.3)**: GP-16 account state review; published legal URLs; F186
  body-rule create/round-trip on BOTH apps; F187 set approval + post-delete scan; F188
  invalid-rule flag; SEC-9 dev sign-in; chain validation -- signed minified prod AAB installed,
  full surface list (GP-9 R-4) on the emulator; GP-8/GP-3 reports reviewed.

## Manual Validation -- planned steps (to be refined at Phase 5.3)

1. Task 1 outcomes: account + verification state, URLs live, placeholders gone.
2. F186: create a body rule on Windows AND Android; round-trip + live match demo.
3. F187: approve enumerated set; post-delete counts + scan; deferred-fetch delta vs Sprint 63.
4. F188: corrupted-rule fixture shows the invalid marker + warning log.
5. Release chain: install the signed minified prod AAB; run the full GP-9 R-4 surface list;
   review GP-8/GP-3/SEC-4 evidence.
6. SEC-9: dev-flavor sign-in unchanged.

## Manual Validation -- results (Phase 5.3, IN PROGRESS 2026-09-02)

**Android chain validation** on `pixel34_updated`, signed + R8-minified + Dart-obfuscated
prod release APK (0.13.0, uid 10193). The release build's Logger filter is silent by design,
so evidence is device-level (sockets, activity state, logcat system lines), not app logs.

- Setup note: the AVD had restored a pre-08-28 snapshot (the 08-28 emulator was killed
  without a snapshot save), so the debug-signed 0.12.0 was back; `adb install -r` refused the
  upload-key build (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) -> uninstall + fresh install. Later
  in-place installs (same key) kept accounts and rules.
- Item 1 Gmail sign-in -- **PASS** (Harold): the prod uid holds an ESTABLISHED port-993
  session to a Google IMAP address; that session only authenticates with a live XOAUTH2
  token, so the injected client id produced a working consent flow on the minified build
  (SEC-9 AC-2).
- Item 2 AOL re-add -- **PASS** (Harold): ESTABLISHED port-993 session to an AOL address
  from the same uid with cleartext disabled app-wide (SEC-4 AC-2 live TLS).
- Item 3 live scan -- **PASS** as the Android chain proof (Harold: "scan complete"; zero
  FATAL/AndroidRuntime lines, pid stable). Note: F187 AC-4's deferred-fetch delta is defined
  against the WINDOWS dev build (the cleaned DB); the Android DB was deliberately untouched
  (F187 R-4). The fresh install seeds 1,824 bundled rules and reported 97 no-rule messages;
  the Windows dev DB (~2,580 rules post-F187) left 2 of 181 unmatched on 08-22. Windows scan
  for AC-4 pending (dev exe built).
- Item 4 Body Phrase create -- **FINDING x2 -> FIXED -> RETEST PASS** (2026-09-03, Harold,
  on the rebuilt 0.13.0 release APK). Screenshot evidence: the Manage Rules row and the
  detail dialog both title the rule `a local girl` (the internal
  `manual_a_local_girl_1788485170302` now appears only on its own "Rule Name" detail line,
  which is the domain-rule convention); Body filter count 1; pattern renders `a\ local\ girl`,
  identical to the legacy Windows form; the create screen's summary reads "Phrase: a local
  girl" (not "Source:"). Second create of the same phrase was REFUSED with "A block rule with
  this pattern already exists" -- the duplicate-check fix working against a body rule, which
  was impossible before (header column compared for every category).
- Item 5 F188 glance -- **PASS** (Harold): 1,825 rules seeded and listed with zero false
  invalid markers; category counts consistent (Header/From 1824 = 1370 entire + 9 exact + 445
  TLD; Subject 0; Body 1); "1825 active" badge agrees with the row count.
- Item 6 Background registration (workmanager keep rule) -- **PASS** (device evidence, the
  sprint's strongest R8 proof): on the MINIFIED build WorkManager resolved
  `dev.fluttercommunity.workmanager.BackgroundWorker` BY FULL NAME and started it
  (`WM-WorkerWrapper: Starting work for dev.fluttercommunity.workmanager.BackgroundWorker`),
  and `dumpsys jobscheduler` shows the registered SystemJobService job for uid u0a193
  RUNNABLE/ALLOWED_IN_DOZE. Without the ONE reasoned keep rule R8 would have renamed that
  class and instantiation would have failed -- GP-9 R-4 surface proven, not inferred.
  Zero FATAL/AndroidRuntime lines across the segment; pid stable.
- Open decision carried to this break: signing JSON password at rest (DPAPI vs plaintext).

**Android chain validation COMPLETE: 6 of 6 PASS.** Remaining MV work is Windows-side
(F187 AC-4 deferred-fetch delta on the dev build) plus Harold's overall MV verdicts.

## Phase 5 evidence gates

- **5.1.1 Automated code review** (2026-09-04, at `80180b3`): three parallel passes -- Android
  release chain, rule authoring, and a dedicated silent-failure hunt (chosen because this
  sprint had ALREADY produced three silent-failure defects, so the class was known live).
  **8 findings, every one verified against source before fixing, all fixed with tests.**
  2 critical (both in `RuleEditScreen`, both silent and user-reachable: the `'keyword'`
  sub-type had no INBOUND mapping so a body rule reopened as a domain rule and a plain Save
  rewrote its type; and the save path derived the condition bucket from the ORIGINAL rule
  while the sub-type followed the selection, so switching any rule to Body Phrase wrote the
  phrase into `condition_header` -- looked right in the list, could never match). 6 more:
  LIKE-wildcard false-positive duplicates, the edit screen as the un-swept parallel site,
  two unlogged `_decodeJsonArray` shapes, two build-script flag combinations that failed
  late or silently dropped obfuscation, and five unguarded sqlite calls plus a two-instant
  WAL backup in the F187 script. **Notably, the category fix stayed GREEN under mutation --
  proof the fix had no test -- which is what prompted the round-trip save test that now reds
  it.** +11 tests.
- **5.1.2 F-PRECHECK six classes** (2026-09-04): **class 1 (mirror/parallel-site sync) CAUGHT
  A REAL ONE** -- `RuleEditScreen` calls the same generator as the create screen and still
  held the pre-fix empty display value plus the wrong "Source" label. Classes 2-6 clean, each
  by an actual detection command rather than a read-through: class 2 confirmed every new
  helper has a live production call site; class 3 found no stale doc comment on a changed
  default; class 4's single new `split` is on a Google client id, a fixed-shape public
  identifier; class 5 added no external API call; class 6's only new bare `catch` is the JSON
  probe where the parse failure IS the counted signal, reported via the aggregate warning.
- **5.1.5 WinWright UI sweep** (2026-09-04, `sweep-head: 80180b38fb2c7d01745c68301e9cedcc5c24d395`):
  **2/2 PASSED** (`test_f124_rule_labels` 29/29, `test_mt2c_no_rule_sweep` 29/29). 3
  dialog-settle scripts excluded by the runner's own documented policy, not re-derived.
  DB drift: none.
- **5.1.6 Runtime launch gate** (the new IMP-6 gate, FIRST USE): **PASS** (2026-09-04, on the
  final signed release APK rebuilt at `d4ae5d7`, installed in place on a cold-booted AVD).
  Live pid 5049 at the 10s mark, zero FATAL/AndroidRuntime lines, no
  network_security_config parse errors. Cost: about 2 minutes, as scoped.
  The gate was initially recorded as PASS from the chain-validation launch -- caught and
  corrected before close-out, because that launch predated the Phase 5.1.1 review fixes and
  the gate's entire purpose is to exercise the sprint's FINAL artifact. This sprint is
  exactly why it exists (SEC-4 passed every static gate and crashed at startup).
- **5.2 Full suite**: 2,011 passed / 15 skipped / 0 failed; analyzer clean.
