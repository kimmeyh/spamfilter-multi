# Sprint 37 Plan: Manual-Rule Subsumption + Gmail Performance + Multi-Variant Build

**Sprint**: 37
**Date**: 2026-04-27
**Branch**: `feature/20260427_Sprint_37`
**Issues**: #246 (BUG-S36-1), #247 (F6), #248 (F52)
**Type**: Mixed -- Bug fix (BUG-S36-1), Performance (F6), Build/Release Infrastructure (F52)
**Estimated Effort**: ~23-31h

---

## Sprint Objective

Three independent deliverables in dependency order: (1) close the Sprint 36 carry-in BUG-S36-1 by extending the manual-rule duplicate checker to detect semantic subsumption (entire_domain covers exact_domain, etc.); (2) cut Gmail scan wall-clock time by replacing per-message HTTP fetches with batchGet, exploiting label-based server-side filtering, and persisting a historyId for incremental delta scans (F6 retargeted to Gmail-only per Phase 1 Q1=e); (3) extend ADR-0035 dev/prod separation (Windows-only today) to side-by-side install across Windows distinct .exe/dirs and full Android build flavors with `dev`/`prod`/`store` `applicationIdSuffix` (F52 Phase 1 + Phase 2 with store flavor as scaffolding -- iOS Phase 3 deferred).

---

## Key Design Decisions

1. **BUG-S36-1 ordering first.** Smallest, lowest-risk task; closes the open Sprint 36 carry-in (Issue #246) before adding new scope. Extends the already-shipped `ManualRuleDuplicateChecker` rather than adding a parallel class. New methods return the existing covering rule (not just a bool) so the validation error message can name it -- mandatory per the issue acceptance criteria.

2. **F6 scope retargeted during Phase 2 dependency check.** The master plan's "Gmail batch email operations via API" was already shipped in Sprint 25 (`gmail_api_adapter.dart` lines 752-1100: `batchModify`, `applyFlag`, `moveToFolder`, TRASH-label delete, chunked at 1000 IDs/call with single-message fallback). Real Sprint 37 F6 work is the **scan-path** optimization that was NOT done: (F6a) `users.messages.batchGet` to replace `Future.wait` of N individual `get` calls; (F6b) Gmail label query strings (`q:`) to push filtering server-side; (F6c) `users.history.list` for incremental delta scans persisting `historyId` per account. Phase 1 Q1=e selected Gmail-only; AOL bulk folder ops deferred.

3. **F52 phase split.** Phase 1 (Windows) + full Phase 2 (Android dev/prod/store flavors) are in. Phase 3 (iOS) is deferred -- requires macOS, Apple Developer Program, reserved bundle IDs (HOLD per master plan). Android `store` flavor is scaffolded now even though it cannot be fully tested until Google Play publication; the `applicationId` slot is reserved and the build pipeline supports it. This avoids a future Sprint having to retrofit a third flavor mid-release.

4. **Bug-S36-1 -> F6 -> F52 execution order.** BUG fix gives a fast win and a clean commit boundary. F6 is application code (Dart) and tests; it benefits from the freshest mental model of the rule/scan path. F52 is build infrastructure (Gradle, PowerShell, ADR docs) and runs cleanly at the end without context-switching back to Dart. Dependencies are independent -- can be reordered if a task blocks.

5. **F52 ADR strategy.** Extend ADR-0035 with a "Sprint 37 Update" section rather than create ADR-0036. Same architectural concern (build-time variants), broader scope (now multi-platform).

6. **F52 Android flavor naming.**
   - `dev` -> applicationId `com.myemailspamfilter.dev`, app name "SpamFilter Dev"
   - `prod` -> applicationId `com.myemailspamfilter.prod`, app name "SpamFilter Pro"
   - `store` -> applicationId `com.myemailspamfilter`, app name "SpamFilter" (matches what will be uploaded to Google Play)

   Rationale: store flavor keeps the canonical applicationId so a future Play Store upload uses the existing identifier. Dev and prod use suffixes so they install side-by-side with the store version on the same device.

7. **F52 Windows binary naming.**
   - dev -> `build/windows/x64/runner/Release-dev/MyEmailSpamFilter-Dev.exe`
   - prod -> `build/windows/x64/runner/Release-prod/MyEmailSpamFilter.exe`
   - store -> MSIX already separate via PackageFamilyName (no change)

8. **No CHANGELOG churn during sprint.** CHANGELOG entries added per task in same commit, per CLAUDE.md changelog policy. Versioned release section is created only when develop -> main merge happens (sprint deliverables stay under `[Unreleased]`).

---

## Tasks

### Task 1: BUG-S36-1 -- Manual rule semantic subsumption (~3-5h, Sonnet)

**Execution order**: 1 (closes Sprint 36 carry-in first)

**Issue**: #246

**Problem**: Sprint 36 BUG-S35-1 catches EXACT duplicates only (same pattern + same `pattern_sub_type`). It does NOT catch semantic subsumption -- e.g., a new `exact_domain` safe sender for `cwru.edu` when an `entire_domain` safe sender for `cwru.edu` already exists. The `entire_domain` rule already covers the `exact_domain` case, so the new rule is dead weight. Same for block rules. Discovered Sprint 36 Phase 5 manual testing (Harold, 2026-04-21).

**Coverage matrix (must enforce)**:
- New `exact_email` covered by existing `exact_domain` or `entire_domain` with matching domain
- New `exact_domain` covered by existing `entire_domain` with matching base domain
- New `entire_domain` is broader -- NOT covered by `exact_domain` or `exact_email`
- New `top_level_domain` (block only) has no overlap with domain types -- different comparison space

**Fix**:

- Extend `mobile-app/lib/core/services/manual_rule_duplicate_checker.dart`:
  - Add `Future<Rule?> findSubsumingBlockRule({required String emailOrDomain, required String patternSubType, required String patternCategory})` -- returns the existing covering rule or null
  - Add `Future<SafeSender?> findSubsumingSafeSender({required String emailOrDomain, required String patternType})` -- same shape for safe senders
  - Helper `_extractBaseDomainFromPattern(String pattern, String subType)` -- pulls `cwru.edu` out of `^[^@\s]+@(?:[a-z0-9-]+\.)*cwru\.edu$` regardless of which sub-type generated it. Reverse of the existing pattern compiler.
  - Coverage check: query rules where `pattern_category` matches and `pattern_sub_type` is broader, then in-Dart filter on extracted base domain match.

- Update `mobile-app/lib/ui/screens/manual_rule_create_screen.dart`:
  - On save, call `findSubsumingBlockRule` / `findSubsumingSafeSender` BEFORE the existing `blockRuleExists` / `safeSenderExists` exact check
  - If subsuming rule found, show validation error: `"A safe sender already covers this: entire_domain cwru.edu."` (template includes existing rule's sub-type and base domain)
  - Reuse existing error display surface (no new dialog)

- 5-8 new unit tests in `mobile-app/test/unit/manual_rule_duplicate_checker_test.dart`:
  - exact_email covered by existing exact_domain (same base) -> rejected, error names existing rule
  - exact_email covered by existing entire_domain -> rejected
  - exact_domain covered by existing entire_domain -> rejected
  - entire_domain NOT covered by exact_domain (broader -> insert succeeds)
  - entire_domain NOT covered by exact_email (broader -> insert succeeds)
  - Different base domain -> not covered (insert succeeds)
  - top_level_domain rule + domain rule -> no coverage relationship (both can coexist)
  - Same coverage matrix re-tested for safe senders (parallel test class or table-driven)

**Acceptance criteria**:
- [ ] `ManualRuleDuplicateChecker` exposes `findSubsumingBlockRule` and `findSubsumingSafeSender` returning the covering rule object (not just a bool)
- [ ] Manual rule create screen calls the subsumption check BEFORE the exact-duplicate check
- [ ] Validation error names the existing rule's sub-type and base domain in the message
- [ ] All 5 coverage matrix rows from issue have test coverage (block rules + safe senders)
- [ ] No regression in existing 4 BUG-S35-1 exact-duplicate tests
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green (1363+ / 0)

**Risk**: Low. Extension of existing class; no schema changes; no new screens. Risk concentrated in the `_extractBaseDomainFromPattern` helper -- the regex parsing must round-trip correctly for all four sub-types. Mitigation: explicit fixture test for each sub-type's pattern shape.

---

### Task 2: F6 -- Gmail scan-path optimization (~10-12h, Sonnet+Opus)

**Execution order**: 2

**Issue**: #247

**Problem**: Scan-path Gmail performance has three known inefficiencies:

1. **Per-message HTTP fetch**: `gmail_api_adapter.dart` line 265 calls `_gmailApi!.users.messages.get(...)` inside `Future.wait`. For a 1000-message inbox, this is 1000 separate HTTP requests. Gmail's `users.messages.batchGet` is not exposed by the googleapis package directly, but the underlying HTTP `/batch/gmail/v1` endpoint handles up to 100 sub-requests per HTTP call -- 10x reduction in connection count.

2. **No server-side label filtering**: Current scan iterates folders and pulls all messages. Gmail's `q:` parameter accepts the same query language as the Gmail web UI: `label:INBOX -label:CATEGORY_PROMOTIONS newer_than:7d`. Pre-filtering server-side avoids fetching messages the rules will never match. Currently `q:` is passed but only with the user's folder/query string, not enriched with label exclusions.

3. **Full re-scan every time**: Every scan re-fetches all messages in scope. Gmail's `users.history.list` returns delta since a `historyId`. Persisting `historyId` per account in `accounts` table allows incremental scans (only new/changed messages since last scan).

**Fix**:

- **F6a -- batchGet HTTP endpoint (~3-4h, Opus)**:
  - Add `_batchGetMessages(List<String> ids)` method in `gmail_api_adapter.dart`. Uses raw HTTP via `_GoogleAuthClient` (already wraps OAuth headers) since googleapis package does not expose `/batch/gmail/v1`.
  - Format: multipart/mixed body with N sub-requests, each a `GET /gmail/v1/users/me/messages/{id}`.
  - Parse response: multipart parser splits sub-responses; each is a JSON `Message`.
  - Chunk at 100 IDs per HTTP call (Gmail API limit).
  - Per-chunk fallback: on batchGet failure, fall back to `Future.wait` of individual `messages.get`. Same fallback shape as existing `_batchModifyLabels` (line 994).
  - Replace the `Future.wait` block in `scanInbox` (line ~265) to call `_batchGetMessages`.

- **F6b -- Label-based pre-filtering (~3-4h, Sonnet)**:
  - Extend `scanInbox` to accept optional `excludeLabels: List<String>?`. Default: `['CATEGORY_PROMOTIONS', 'CATEGORY_SOCIAL']` (configurable in Settings later -- this sprint adds the wiring only, UI deferred).
  - Build `q:` query string concatenating user's existing query with `-label:LABEL_NAME` clauses for each exclude.
  - Add toggle in `EmailScanProvider` for "Skip Gmail Promotions and Social tabs" (default ON for Gmail accounts, ignored for IMAP).
  - Settings persistence via existing `app_settings` SharedPreferences-backed service (no new DB column).

- **F6c -- Incremental delta scan via historyId (~4h, Opus)**:
  - Add `last_history_id TEXT` column to `accounts` table via migration (`mobile-app/lib/core/services/database_helper.dart`). Migration version bump.
  - On first scan: persist current profile `historyId` (from `users.getProfile`).
  - On subsequent scans: call `users.history.list(startHistoryId: last_history_id)` -> returns added/modified/deleted message IDs since that point.
  - Pass added/modified IDs through the existing scan path (now using batchGet from F6a). Skip full inbox iteration.
  - Edge case: 7-day historyId expiration. On `historyNotFound` error, fall back to full scan and persist new `historyId`.
  - User-facing toggle in Settings: "Incremental scan (faster)" default ON. Full-scan path retained as fallback and explicit user choice.

- **Performance benchmark task** (within F6c): document before/after on a representative 1000-message Gmail inbox in `docs/PERFORMANCE_BENCHMARKS.md`. Time the three operations independently: full-scan baseline, full-scan + batchGet only, incremental scan + batchGet.

**Acceptance criteria**:
- [ ] `_batchGetMessages` implemented with multipart/mixed body, 100-ID chunks, per-chunk fallback
- [ ] `scanInbox` uses batchGet instead of `Future.wait` of individual `messages.get`
- [ ] `q:` query string includes label exclusions when `excludeLabels` is set
- [ ] EmailScanProvider exposes `skipGmailPromoSocial` toggle (default true for Gmail)
- [ ] `accounts` table has `last_history_id` column via versioned migration
- [ ] Incremental scan path uses `users.history.list` and falls back to full scan on `historyNotFound`
- [ ] EmailScanProvider exposes `incrementalScanEnabled` toggle (default true)
- [ ] PERFORMANCE_BENCHMARKS.md updated with before/after numbers
- [ ] All existing Gmail adapter tests pass; new tests added for batchGet (mocked HTTP), label query construction, history.list flow
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Medium. `users.messages.batchGet` requires raw HTTP outside the googleapis package -- multipart parsing is the highest-risk piece. Mitigation: use a well-tested multipart library (`mime` package, already a transitive dep) or write a focused parser with comprehensive test fixtures. `users.history.list` historyId expiration is a known Gmail API quirk -- handled with explicit fallback. No schema-breaking changes (additive column with nullable default).

---

### Task 3: F52 -- Multi-variant side-by-side install (~10-14h, Sonnet)

**Execution order**: 3

**Issue**: #248

**Problem**: Today only one Windows variant (dev OR prod) is "current" at any time -- whichever was built last. Android has a single applicationId so only one install can exist. To compare dev vs prod behavior, test store builds without uninstalling, or reproduce store-only bugs while a fix is in dev, the user/developer must uninstall and rebuild.

**Phases in scope**:
- Phase 1: Windows distinct .exe + distinct dirs (~4-6h)
- Phase 2: Android flavors (~6-8h)
- Phase 3 (iOS): DEFERRED to later sprint (requires macOS + Apple Developer Program)

**Phase 1 -- Windows distinct .exe + distinct dirs (~4-6h)**:

- Update `mobile-app/scripts/build-windows.ps1`:
  - Output to `build/windows/x64/runner/Release-{env}/` instead of `Release/`
  - Rename .exe at build time: prod -> `MyEmailSpamFilter.exe`, dev -> `MyEmailSpamFilter-Dev.exe`
  - Update `$buildTarget` path resolution to use env-specific subdir
  - Update single-instance task name registration to use env-specific .exe name (already env-aware via mutex)
  - Update launch script line at end of build (line 250 area) to print env-specific .exe path
- Update `mobile-app/scripts/build-with-secrets.ps1` if it references Windows runner output paths (likely not -- it's Android-focused, but verify)
- Update `mobile-app/windows/runner/CMakeLists.txt` if needed for output filename rename (likely uses `${BINARY_NAME}` -- verify and parameterize)
- Verify Microsoft Store MSIX path is unaffected (msix:create installs to `Packages\{PackageFamilyName}\` -- separate from build output)
- Update CLAUDE.md "Windows Development" subsection to reflect new paths
- Update ADR-0035 "Sprint 37 Update" section: extend the original ADR with multi-variant naming rationale

**Phase 2 -- Android flavors (~6-8h)**:

- Configure `productFlavors` in `mobile-app/android/app/build.gradle.kts`:
  ```kotlin
  flavorDimensions += "channel"
  productFlavors {
    create("dev") {
      dimension = "channel"
      applicationIdSuffix = ".dev"
      versionNameSuffix = "-dev"
      manifestPlaceholders["appName"] = "SpamFilter Dev"
    }
    create("prod") {
      dimension = "channel"
      applicationIdSuffix = ".prod"
      versionNameSuffix = "-prod"
      manifestPlaceholders["appName"] = "SpamFilter Pro"
    }
    create("store") {
      dimension = "channel"
      // No suffix -- canonical applicationId for Google Play
      manifestPlaceholders["appName"] = "SpamFilter"
    }
  }
  ```
- Update `mobile-app/android/app/src/main/AndroidManifest.xml` to use `${appName}` placeholder for `android:label` (instead of hardcoded label string)
- Update `mobile-app/scripts/build-with-secrets.ps1`:
  - Add `-Flavor <dev|prod|store>` parameter (default `dev` for current behavior)
  - Pass `--flavor=<flavor>` to `flutter build apk` and `flutter run`
  - Update `-InstallToEmulator` path to honor flavor
- Generate per-flavor icons OR icon overlay strategy:
  - Simpler: ship 3 icons (dev with yellow stripe, prod with red stripe, store clean) under `mobile-app/android/app/src/{dev,prod,store}/res/mipmap-*/`
  - Use existing icon for store; generate dev/prod overlays with PowerShell ImageMagick or Flutter `flutter_launcher_icons` package (the latter is already in the dev_dependencies if present)
- Test acceptance: build APKs for all 3 flavors, install all 3 to emulator, verify 3 distinct app entries with distinct names and icons

**Acceptance criteria**:

Phase 1 (Windows):
- [ ] `build-windows.ps1` outputs to `Release-dev/` or `Release-prod/` based on `-Environment`
- [ ] dev binary is named `MyEmailSpamFilter-Dev.exe`; prod binary is `MyEmailSpamFilter.exe`
- [ ] Both binaries can coexist on disk (no rebuild required to switch)
- [ ] Both binaries can run simultaneously (mutex still works -- one mutex per env)
- [ ] Microsoft Store MSIX install verified unaffected (smoke test: install MSIX, run, verify it does not collide with sideloaded prod .exe)
- [ ] CLAUDE.md "Windows Development" updated
- [ ] ADR-0035 has Sprint 37 Update section

Phase 2 (Android):
- [ ] `productFlavors` block in `build.gradle.kts` defines `dev`/`prod`/`store` with correct suffixes
- [ ] `AndroidManifest.xml` uses `${appName}` placeholder
- [ ] `build-with-secrets.ps1` accepts `-Flavor` parameter
- [ ] Per-flavor icons or overlay generated and committed under correct flavor source dirs
- [ ] All 3 APKs installable on emulator simultaneously
- [ ] Each variant has distinct app name in launcher
- [ ] Each variant has distinct icon in launcher
- [ ] Each variant gets its own data directory (verified by Android automatic per-applicationId isolation)
- [ ] No regression in existing dev APK build flow (default flavor = dev preserves current behavior)

**Risk**: Medium. Phase 1 is mechanical -- low risk. Phase 2 has higher risk: (a) Flutter's `--flavor` interaction with `--dart-define-from-file` is subtle -- secrets must still inject correctly per flavor; (b) per-flavor icon generation, if done via package, may need new dev_dep; (c) Android Manifest placeholder syntax is sensitive to escape rules. Mitigation: build dev flavor first as no-op refactor (proves the pipeline still works), then add prod, then store. Each is a separate commit so any regression is bisectable.

---

## Total Effort and Order

| Task | Effort | Order | Model | Issue |
|---|---|---|---|---|
| Task 1: BUG-S36-1 subsumption | 3-5h | 1 | Sonnet | #246 |
| Task 2: F6 Gmail perf | 10-12h | 2 | Sonnet+Opus | #247 |
| Task 3: F52 Win+Android variants | 10-14h | 3 | Sonnet | #248 |
| **Total** | **23-31h** | | | |

---

## Out of Scope

- F6 AOL bulk folder operations (Q1=e selected Gmail-only)
- F6 Outlook Graph API (Outlook OAuth not yet implemented)
- F52 Phase 3 iOS (deferred -- requires macOS + Apple Developer Program)
- F6 Settings UI for new toggles (`skipGmailPromoSocial`, `incrementalScanEnabled` -- this sprint exposes the wiring; UI sprint can ship the toggle widgets)
- F52 store flavor end-to-end Google Play upload (scaffolding only -- actual store upload is post-Google Play app registration)
- ADR-0036 (we extend ADR-0035 instead per Decision 5)

---

## Dependencies and Pre-Conditions

- **BUG-S36-1**: Depends on Sprint 36 BUG-S35-1 (`ManualRuleDuplicateChecker` class). Confirmed shipped in Sprint 36 commits `814d92b` and `63b3cac`. Pre-condition: clean develop checkout.
- **F6**: No code dependencies. Requires Gmail account with 100+ messages for benchmarking. Pre-condition: `secrets.dev.json` populated with Gmail OAuth.
- **F52**: Depends on ADR-0035 dev/prod scaffolding (Sprint 19) for Windows. Pre-condition: Android emulator available for Phase 2 testing.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| F6a multipart parsing fragile | Medium | High (scan broken) | Per-chunk fallback to individual `messages.get`; comprehensive parser tests |
| F6c historyId expires unexpectedly | Medium | Low | Explicit `historyNotFound` -> full-scan fallback; preserved as Gmail API quirk |
| F52 Phase 2 secrets injection broken per flavor | Medium | High (OAuth fails) | Smoke test sign-in on dev flavor first as no-op refactor commit |
| F52 Phase 1 MSIX collision | Low | Medium | MSIX uses separate PackageFamilyName -- physically separate install path |
| BUG-S36-1 base-domain extraction wrong for edge cases | Low | Medium | Explicit fixture per sub-type pattern shape; round-trip property test |
| Sprint sizing (~23-31h) overruns | Medium | Low | Tasks are independent -- can defer F52 Phase 2 to Sprint 38 if F6 takes longer than estimated |

---

## Phase 3.2.2.1 Plan-to-Branch-State Verification (per Sprint 36 IMP-1)

Verified during Phase 2 dependency check. All file paths, class names, and config keys referenced in this plan exist in the current `develop` branch state at SHA `ea7e14c`:

- [OK] `mobile-app/lib/core/services/manual_rule_duplicate_checker.dart` exists; `blockRuleExists` and `safeSenderExists` defined at lines 38, 76
- [OK] `mobile-app/lib/ui/screens/manual_rule_create_screen.dart` exists
- [OK] `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` exists; `_gmailApi`, `users.messages.list`, `users.messages.get`, `users.messages.batchModify`, `users.labels.list/create` all present
- [OK] `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` line 265 confirms `Future.wait` of individual `messages.get` (target for F6a refactor)
- [OK] `mobile-app/scripts/build-windows.ps1` outputs to `Release/MyEmailSpamFilter.exe` (target for F52 Phase 1 split)
- [OK] `mobile-app/android/app/build.gradle.kts` has `applicationId = "com.myemailspamfilter"`, no `productFlavors` block (target for F52 Phase 2)
- [OK] `mobile-app/pubspec.yaml` confirms `googleapis: ^11.4.0`, `enough_mail: ^2.1.7`, `sqflite: ^2.3.0`
- [OK] `docs/adr/0035-production-development-side-by-side.md` exists (target for Sprint 37 Update extension)

---

## Phase 3.7 Approval Gate

This plan is committed to `feature/20260427_Sprint_37`. Per Sprint 36 IMP-3 approval verification gate, no Phase 4 task work begins until Harold explicitly approves with "approved" or equivalent in this session, on the draft PR, or on Issue #246.

---

## Standing Approval Inventory (Phase 3.7 reference)

After Phase 3.7 approval, the following actions are pre-approved for Sprint 37 execution per CLAUDE.md "Phase Auto-Advance Rule" and SPRINT_EXECUTION_WORKFLOW.md Phase 3.7:

[OK] **Pre-approved (do NOT ask)**:
- All file edits within `mobile-app/`, `docs/`, `mobile-app/test/` for the three tasks
- Git stage and commit on `feature/20260427_Sprint_37`
- Push to `feature/20260427_Sprint_37` remote branch
- Update PR description on the Sprint 37 draft PR
- Run `flutter test`, `flutter analyze`, `build-windows.ps1`, `build-with-secrets.ps1`
- Update CHANGELOG.md per task in same commit
- Cross-phase auto-advance (Phase N complete -> begin Phase N+1 first action)

[FAIL] **NOT pre-approved (must ask)**:
- Force-push, reset --hard, branch deletion, history rewrite
- Merging the PR (Harold-only per CLAUDE.md branch policy)
- New external service signups (e.g., Apple Developer)
- Schema-breaking DB migrations (additive nullable columns ARE pre-approved)
- Removing or downgrading existing `pubspec.yaml` dependencies (additions ARE pre-approved if minor-version)
