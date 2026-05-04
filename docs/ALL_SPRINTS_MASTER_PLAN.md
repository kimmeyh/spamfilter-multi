# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: April 19, 2026 (Sprint 35 retrospective + 0.5.2.0 store MSIX shipped; F81 added as Sprint 36 carry-in (Issue #242) -- store release process documentation; Sprint 36 will bump dev to 0.5.3.0)

## How to Maintain This Document

This section describes when and how to update this document during sprint execution. Referenced by SPRINT_EXECUTION_WORKFLOW.md (Phases 2.1, 3.2, 7.7), SPRINT_CHECKLIST.md, SPRINT_PLANNING.md, and SPRINT_RETROSPECTIVE.md.

### When to Update

| Sprint Phase | What to Update |
|-------------|----------------|
| **Phase 2 (Pre-Kickoff)** | Verify "Last Completed Sprint" is current; confirm all items from completed sprint are marked done or removed |
| **Phase 3 (Planning)** | Review "Next Sprint Candidates" for completeness; add any new items found in GitHub Issues; re-prioritize list; move selected items into sprint plan |
| **Phase 7 (Retrospective)** | Update "Past Sprint Summary" table; update "Last Completed Sprint"; remove completed feature/bug detail sections; add new issues discovered during sprint |
| **Backlog Refinement** | Full review of all sections; re-prioritize; add/remove items; verify GitHub Issue alignment |

### Maintenance Rules

1. **One list of incomplete work**: The "Next Sprint Candidates" section is THE single prioritized list. Do not create duplicate tracking elsewhere in this document.
2. **Remove completed work**: When a feature, bug, or spike is completed, remove its detail section from "Feature and Bug Details". History lives in sprint docs (`docs/sprints/`), CHANGELOG.md, and closed GitHub Issues.
3. **GitHub Issue alignment**: Every item in "Next Sprint Candidates" should reference a GitHub Issue number if one exists. Items without issues get issues created when added to a Sprint Plan.
4. **HOLD items last**: Items on HOLD are grouped at the bottom of the candidates list with a brief reason.
5. **Keep it current**: The "Last Updated" date at the top must reflect the most recent edit. Stale content erodes trust in the document.
6. **Minimal history**: Past Sprint Summary is a table of links. No completed feature details, no completed retrospective actions, no completed MVP feature lists.
7. **Detail sections are optional**: Not every candidate needs a detail section. Simple bugs or small features can be fully described in GitHub Issues alone. Only add detail sections for items that need architecture notes, task breakdowns, or context beyond what fits in a GitHub Issue.
8. **Cross-reference integrity**: When updating this document, verify that SPRINT_EXECUTION_WORKFLOW.md and SPRINT_CHECKLIST.md references remain accurate. Both reference this Maintenance Guide by name.

---

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** (this doc) | Master plan and backlog for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Past Sprint Summary](#past-sprint-summary)
2. [Last Completed Sprint](#last-completed-sprint)
3. [Next Sprint Candidates](#next-sprint-candidates)
4. [Feature and Bug Details](#feature-and-bug-details)
5. [Google Play Store Readiness (HOLD)](#google-play-store-readiness-hold)

---

## Past Sprint Summary

Historical sprint information lives in individual documents in `docs/sprints/` and CHANGELOG.md.

| Sprint | Summary Document | Status | Duration |
|--------|------------------|--------|----------|
| 1 | docs/sprints/SPRINT_1_RETROSPECTIVE.md | [OK] Complete | ~4h (Jan 19-24, 2026) |
| 2 | docs/sprints/SPRINT_2_RETROSPECTIVE.md | [OK] Complete | ~6h (Jan 24, 2026) |
| 3 | docs/sprints/SPRINT_3_SUMMARY.md | [OK] Complete | ~8h (Jan 24-25, 2026) |
| 8 | docs/sprints/SPRINT_8_SUMMARY.md | [OK] Complete | ~12h (Jan 31, 2026) |
| 9 | docs/sprints/SPRINT_9_SUMMARY.md | [OK] Complete | ~2h (Jan 30-31, 2026) |
| 10 | docs/sprints/SPRINT_10_SUMMARY.md | [OK] Complete | ~20h (Feb 1, 2026) |
| 11 | docs/sprints/SPRINT_11_SUMMARY.md | [OK] Complete | ~12h (Jan 31 - Feb 1, 2026) |
| 12 | docs/sprints/SPRINT_12_SUMMARY.md | [OK] Complete | ~48h (Feb 1-6, 2026) |
| 13 | docs/sprints/SPRINT_13_PLAN.md | [OK] Complete | ~3h (Feb 6, 2026) |
| 14 | docs/sprints/SPRINT_14_PLAN.md | [OK] Complete | ~8h (Feb 7-13, 2026) |
| 15 | docs/sprints/SPRINT_15_PLAN.md | [OK] Complete | ~16h (Feb 14-15, 2026) |
| 16 | docs/sprints/SPRINT_16_PLAN.md | [OK] Complete | ~6h (Feb 15-16, 2026) |
| 17 | docs/sprints/SPRINT_17_SUMMARY.md | [OK] Complete | ~20h (Feb 17-21, 2026) |
| 18 | docs/sprints/SPRINT_18_RETROSPECTIVE.md | [OK] Complete | Feb 24-27, 2026 |
| 19 | docs/sprints/SPRINT_19_SUMMARY.md | [OK] Complete | Feb 27 - Mar 15, 2026 |
| 20 | docs/sprints/SPRINT_20_RETROSPECTIVE.md | [OK] Complete | Mar 15-17, 2026 |
| 21 | docs/sprints/SPRINT_21_RETROSPECTIVE.md | [OK] Complete | Mar 18, 2026 |
| 22 | docs/sprints/SPRINT_22_RETROSPECTIVE.md | [OK] Complete | Mar 19, 2026 |
| 23 | docs/sprints/SPRINT_23_RETROSPECTIVE.md | [OK] Complete | Mar 20, 2026 |
| 24 | docs/sprints/SPRINT_24_RETROSPECTIVE.md | [OK] Complete | Mar 20-21, 2026 |
| 25 | docs/sprints/SPRINT_25_RETROSPECTIVE.md | [OK] Complete | Mar 22, 2026 |
| 26 | docs/sprints/SPRINT_26_RETROSPECTIVE.md | [OK] Complete | Mar 22-24, 2026 |
| 27 | docs/sprints/SPRINT_27_RETROSPECTIVE.md | [OK] Complete | Mar 29 - Apr 2, 2026 |
| 28 | docs/sprints/SPRINT_28_RETROSPECTIVE.md | [OK] Complete | Apr 2, 2026 |
| 29 | docs/sprints/SPRINT_29_RETROSPECTIVE.md | [OK] Complete | Apr 3-13, 2026 |
| 30 | docs/sprints/SPRINT_30_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |
| 31 | docs/sprints/SPRINT_31_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |
| 32 | docs/sprints/SPRINT_32_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |
| 33 | docs/sprints/SPRINT_33_RETROSPECTIVE.md | [OK] Complete | Apr 14-16, 2026 |
| 34 | docs/sprints/SPRINT_34_RETROSPECTIVE.md | [OK] Complete | Apr 17-18, 2026 |
| 35 | docs/sprints/SPRINT_35_RETROSPECTIVE.md | [OK] Complete | Apr 19, 2026 |
| 36 | docs/sprints/SPRINT_36_RETROSPECTIVE.md | [OK] Complete | Apr 20-25, 2026 |
| 37 | docs/sprints/SPRINT_37_RETROSPECTIVE.md | [OK] Complete | Apr 27 - May 1, 2026 |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 37** (April 27 -- May 1, 2026)
- **Type**: Mixed (bug fix + perf optimization + build infrastructure + retrospective improvements)
- **Feature**: 3 main tasks (BUG-S36-1 Issue #246; F6 Issue #247; F52 Phase 1 Issue #248) + 7 retrospective IMPs applied at Phase 7
- **Delivered**:
  - BUG-S36-1 (Issue #246): Manual rule semantic subsumption pre-insert check. Coverage matrix (`exact_email` covered by `exact_domain`/`entire_domain`; `exact_domain` covered by `entire_domain`; `entire_domain` not covered; TLD no overlap). 14 new unit tests. New `SubsumingRuleInfo` type carries the covering-rule details to the user-facing validation error.
  - F6a/F6b/F6c (Issue #247): Gmail scan-path optimization. F6a parallelized `messages.get` via `Future.wait` (~10x fetch speedup); F6b added optional server-side label exclusion via new `setExcludedLabels(...)`; F6c shipped the Gmail historyId adapter (`fetchMessagesIncremental(startHistoryId)` returns `IncrementalFetchResult` full / partial / expired). DB schema v3 -> v4 migration adds `last_history_id` column to `accounts`. EmailScanProvider wiring tracked separately for Sprint 38 (Issue #250).
  - F52 Phase 1 (Issue #248): Windows distinct .exe + dirs. `dist/dev/MyEmailSpamFilter-Dev.exe` + `dist/prod/MyEmailSpamFilter.exe` coexist on disk; build-windows.ps1 kills stale Dart VMs before flutter clean and direct-launches the variant binary (no Dart VM reattach). CMakeLists.txt bakes `SPAMFILTER_APP_ENV` at compile time so window title is correct in store/MSIX builds. F52 Phase 2 (Android flavors) deferred to Sprint 38 -- external Firebase Console + GCP setup prerequisites surfaced.
  - Phase 7 retrospective improvements applied this sprint (7 IMPs): IMP-1 SelectableText on Manage Rules + Manage Safe Senders rows (UX); IMP-2 Help screen "Other ways to reduce junk email/mail/texts/phone calls" section (UX, sources FTC + DoNotCall.gov); IMP-6 Phase 6.4 Copilot review marked conditional in SPRINT_EXECUTION_WORKFLOW.md; IMP-7 new Phase 3.2.2.2 re-estimate-after-dependency-findings sub-step; IMP-8 F52 Phase 2 carry-in row in master plan (this section); IMP-9 Issue #250 created tracking F6c provider wiring; IMP-11 build-windows.ps1 fixes verified already-shipped mid-sprint.
- **Backlog additions** (5 new items from Phase 7 Imp-3/4/5/10/12): F82 Scan Results "no rules" progress indicator (UX), F83 per-account Background Scanning separation (architecture, multi-sprint), BUG-S37-1 background scan SQLite "database is locked", BUG-S37-2 TLD data quality cleanup + ccTLD blocklist expansion (with 4 design-option scoping alternatives), F61 extended to cover Sprint 37 type/schema additions.
- **Tests**: +29 in main sprint scope (BUG-S36-1 14, F6b 8, F6c 5+2) + 3 from Imp-2 widget tests = 1409 total passing / 0 failing / 0 analyzer issues. Imp-1 widget tests dropped (FakeAsync + sqflite_ffi `pumpWidget` incompatibility; trivial `Text -> SelectableText` swap covered by manual testing + code review).
- **Effort**: ~5h main-sprint wall clock vs 23-31h estimate (~20% of estimate); +~2h Phase 7 IMPs application = ~7h total
- **Retrospective**: docs/sprints/SPRINT_37_RETROSPECTIVE.md
- **PR**: #249 (against develop)

---

## Next Sprint Candidates

**Last Reviewed**: April 16, 2026 (Sprint 33 completion -- removed F53, F54, F55, F65, F66, SEC-1b, SEC-8, SEC-14, SEC-19, SEC-22 and partial SEC-11)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Core App

**F52 Phase 2. Android dev/prod/store flavors (~6-8h) Priority 90 (Issue #248) -- SPRINT 38 CARRY-IN from Sprint 37**
- Phase: Build and Release Infrastructure
- Platform: Android
- Sprint 37 shipped Phase 1 (Windows distinct .exe + dirs); Phase 2 (Android `productFlavors` with `applicationIdSuffix .dev` / `.prod`) was deferred per SPRINT_STOPPING_CRITERIA.md Criterion 2 (external dependency).
- **Prerequisites (must be done BEFORE this work can produce a runnable Android build):**
  1. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.dev` applicationId
  2. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.prod` applicationId
  3. Google Cloud Console -- create OAuth client ID for `.dev` package + matching SHA-1
  4. Google Cloud Console -- create OAuth client ID for `.prod` package + matching SHA-1
- **Pre-existing investigation item (surfaced during Sprint 37 Phase 2 dependency check)**: `mobile-app/android/app/google-services.json` has `applicationId="com.example.spamfiltermobile"` while `build.gradle.kts` declares `applicationId="com.myemailspamfilter"`. This mismatch should be diagnosed and fixed BEFORE adding flavor complexity (could be why current Android Gmail OAuth has been intermittent).
- Memory note: `project_f52_phase2_blockers.md` has full Sprint 37 deferral context.
- Source: Sprint 37 retrospective Category 11 + Category 13; Issue #248 deferral comment

**F52 Phase 3+. iOS variants + cross-store hardening (remaining ~10-16h) Priority 88**
- Phase: Build and Release Infrastructure
- Platform: iOS, plus polish across all 9 variants (3 stores x 3 channels: dev, production, store)
- All variants must run simultaneously without rebuild on same machine/device
- [Detail](#f52-multi-variant-side-by-side-install)
- Source: ADR-0035 dev/prod separation

**F63. Responsive design framework (~8-12h) Priority 70**
- Phase: UX Improvement
- Platform: All
- Implement adaptive breakpoints per ARSD AR-7: phone (<600dp), tablet (600-900dp), desktop (>900dp)
- LayoutBuilder + breakpoints approach (ARSD A6 recommendation)
- Priority screens: scan progress, results display, settings
- Related: F55 (navigation consistency) should be done before or with this
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G23)

**F84. Keyboard + multi-region selection enhancements on list screens (~4-6h) Priority 65 -- BACKLOG from Sprint 37**
- Phase: UX Improvement
- Platform: Windows desktop (primary); macOS / Linux desktop (secondary -- adapt platform-specific shortcuts)
- Source: Sprint 37 retrospective Phase 5.3 round-2 manual testing (Harold, 2026-05-01) -- after the screen-level `SelectionArea` fix on Manage Rules + Manage Safe Senders, three desktop-standard selection gestures still do not work as users expect:
- **Sub-task A**: `Ctrl+A` should select ALL text across the entire filtered list, not just the items currently rendered in the viewport. Today (Flutter `SelectionArea` default behavior on a `ListView.builder`), only items that have been laid out in the viewport are selectable -- items below the visible region are not yet built and are skipped. Fix likely involves: (1) precomputing the row strings into one synthesized `SelectionContainer` with all text content even for off-screen rows, OR (2) switching the list to a non-virtualized layout for the selection scope (acceptable for typical list sizes -- Manage Rules ~200-1500 rows, Manage Safe Senders ~500-1000), OR (3) custom `Ctrl+A` Shortcuts handler that reads `_filteredRules` / `_filteredSenders` and writes the joined text to clipboard directly (skip Flutter's selection model for this case).
- **Sub-task B**: `Shift+LeftClick` should "extend selection to here" (Windows-standard): preserve the existing selection's start anchor and update its end to the click position. Today an unmodified click resets selection.
- **Sub-task C**: `Ctrl+LeftClick`-and-drag should "add a new disjoint selection range" without clearing the prior selection (Windows-standard for non-contiguous select). Today this is not supported -- only one contiguous selection at a time.
- Cross-platform parity: macOS `Cmd+A`, `Shift+Click`, `Cmd+Click` should map equivalently. Linux uses Ctrl as on Windows.
- Tests: 3-5 widget tests covering Ctrl+A select-all (assert the in-memory list of strings ends up in clipboard, not just the viewport subset), Shift+Click extend-selection, Ctrl+Click disjoint-range. Real keyboard simulation via `WidgetTester.sendKeyEvent`.
- Related: applies to any screen with a long virtualized list of selectable text (Scan Results, Scan History detail rows, etc.) -- worth designing as a reusable `SelectableScrollableList` widget rather than duplicating per screen.

**F85. Content-management architecture for long inline strings (~6-10h, ADR + Help refactor + Settings audit) Priority 50 -- BACKLOG from Sprint 37**
- Phase: Architecture / Documentation
- Platform: All
- Source: Sprint 37 Phase 5.3 round-2 question from Harold (2026-05-01); scope expanded round-3 (2026-05-02) to be a general content-management architecture rather than Help-only.
- **Driving threshold**: any Dart string literal **longer than 500 characters** (whether one continuous string or a concatenation across adjacent line-continuation `'...' '...'` literals) is a candidate for extraction. Threshold chosen because at that length the string is content authored for end-users, not a prompt or label, and editing it via Dart-source-edit + rebuild + commit is significantly more friction than editing a plain-text asset.
- **Phase 1 -- ADR (mandatory first step, ~2-3h)**: Create `docs/adr/0036-content-management-for-long-strings.md` (or next available ADR number). The ADR must:
  1. State the >500-character threshold rule and the rationale.
  2. Survey + decide between candidate formats:
     - **(a) YAML keyed by enum / route key**: structured, build-time-validatable, supports lists-of-bullets without ad-hoc parsing.
     - **(b) Markdown with H2/H3 anchors**: readable as standalone docs, but requires `flutter_markdown` and richer parsing.
     - **(c) JSON keyed by enum / route key**: same as YAML; matches Flutter's L10n asset format.
     - **(d) Per-section .md files** (one file per section): friendliest for non-technical editors and diff review; needs an index registry.
  3. Decide loader strategy: build-time bake (asset bundle) vs. runtime fetch (fallback for ship-without-rebuild updates -- probably out of scope for V1).
  4. Decide validation strategy: how does CI verify that every (enum value or route key) has a matching asset entry, and that every asset entry has a matching (enum value or route key)? Failure mode: drift between Dart code and assets.
  5. Decide on test strategy: existing widget tests must still pass; tests must read from the loaded asset, not hardcoded duplicate strings.
  6. Decide on i18n posture: leave room for future L10n by structuring asset paths or keys to allow language suffixes (`help_content.en.yaml` vs `help_content.yaml`), even if V1 is English-only.
- **Phase 2 -- Help screen migration (~2-3h)**: Refactor `mobile-app/lib/ui/screens/help_screen.dart` per the ADR. Today ~250-300 lines of body text across 20 sections (multiple sections >500 chars after concatenation). All migrated in one PR; no mixed state where some sections are inline and others are external.
- **Phase 3 -- Settings descriptions migration + codebase audit (~2-4h)**: Audit ALL `lib/` for string literals >500 characters that are user-facing content (not prompts, not error messages, not regex patterns). Concrete known candidates as of Sprint 37:
  - **Settings tabs** -- the descriptive subtitles / explainer paragraphs on the General, Account, Manual Scan, and Background tabs of `lib/ui/screens/settings_screen.dart` (some explainer paragraphs run multi-paragraph and would benefit from external authoring).
  - Any other screen explainer paragraph the audit surfaces.
  - **Excluded**: regex pattern strings; SQL DDL strings; YAML rule literals; debug log message templates; string interpolation that needs runtime values (those stay inline).
- **Acceptance criteria**:
  - ADR shipped + linked from CLAUDE.md
  - Harold can edit any of the migrated content by opening one asset file (no Dart code touched) and the change appears in the next build
  - All pre-existing widget tests pass against asset-loaded content
  - Build-time validation step in CI/build scripts: drift between enum values and asset keys causes the build to fail (catches "added a section to enum but forgot the asset content")
  - Codebase audit doc enumerates every >500-char user-facing string found and shows it now lives in an asset
  - Single-source-of-truth: removing a section removes both the enum/route key AND the asset entry
- **Out of scope**: localization runtime switching (separate F-item if/when needed); rich content (images, embedded links opened in browser) -- text-only for V1; runtime asset fetching (future enhancement).

**F86. Live reload of rules / safe senders during an active Manual Scan (~2-4h) Priority 60 -- BACKLOG from Sprint 37**
- Phase: UX / Core App
- Platform: All
- Source: Sprint 37 Phase 5.3 round-3 manual testing observation (Harold, 2026-05-02): "adding safe-sender or rules via Settings does not apply in live scan until exit and re-enter."
- **Current behavior (problem)**: Manual Scan / Live Scan caches the active rule set + safe sender list at scan start. If the user navigates away to Settings, adds a new rule or safe sender, and returns to Manual Scan, the in-flight scan continues using the old cached rule set. The new rule does not apply until the user exits the Manual Scan screen and re-enters it (which restarts the scan from scratch).
- **Desired behavior**: When a rule or safe sender is added/edited/deleted via Settings (Manage Rules, Manage Safe Senders, or any quick-add affordance), the change propagates to the active scan's rule evaluator without requiring a screen-level restart. The user sees the new rule applied to remaining-to-be-evaluated emails on the next batch boundary.
- **Acceptance criteria**:
  - Add/edit/delete a rule from any rule-management surface while a scan is in progress -> the new rule set is observed by the scanner before the next email batch is evaluated
  - Same for safe senders
  - Already-evaluated emails in the current scan are NOT re-evaluated (avoid surprise reclassification of completed work)
  - 3-5 widget tests covering rule-add-during-scan, safe-sender-add-during-scan, rule-delete-during-scan
- **Implementation sketch**: Subscribe `EmailScanProvider` (or whichever owns the running scan) to the rule + safe-sender database streams (or a `RuleSetProvider.notifyListeners()` signal). On change notification, atomically swap the in-memory `RuleSet` reference at a batch boundary; do not re-evaluate already-completed emails.
- **Out of scope**: live-reload during Background Scan (the background pipeline is shorter-lived per invocation; user-initiated mid-scan rule additions are less frequent there).
- **Note**: This unblocks a UX pattern Harold uses heavily on the Live Scan results screen (add a rule for a "no rules" hit, see remaining matches removed) -- today that pattern only works at the per-rule async-delete level, not for newly-added rules being applied to the still-in-progress scan.

**F88. F6a Phase 2: true Gmail batchGet via /batch/gmail/v1 multipart endpoint (~3-4h) Priority 60 -- BACKLOG from Sprint 37 Copilot review**
- Phase: Performance / Gmail adapter
- Platform: Gmail (all hosting platforms)
- Source: Sprint 37 PR #249 Copilot review #4 (2026-05-02). Gap surfaced when comparing implementation against the Issue #247 acceptance criteria.
- **Current state (Sprint 37 ship)**: `gmail_api_adapter.dart` `fetchMessages` parallelizes individual `users.messages.get` calls via `_fetchMessagesConcurrent` (8-concurrent chunked `Future.wait`). This delivered ~10x speedup over the prior serial loop AND respects Gmail's per-user concurrency cap (Copilot review #5 fix).
- **Gap vs Issue #247 acceptance criteria**: Issue #247 F6a explicitly required `users.messages.batchGet` via the `/batch/gmail/v1` HTTP endpoint (multipart/mixed body, 100 IDs per call, per-chunk fallback to individual `messages.get` matching the existing `_batchModifyLabels` fallback pattern). Sprint 37 shipped the parallel-fetch optimization but NOT the batchGet endpoint. The PR description and CHANGELOG correctly described the parallel-fetch shipping, but Issue #247's acceptance line "`scanInbox` uses batchGet instead of `Future.wait` of individual `messages.get`" remains unsatisfied.
- **Acceptance criteria for F6a Phase 2**:
  - Implement `_batchGetMessages(List<String> messageIds)` using `/batch/gmail/v1` HTTP endpoint with `multipart/mixed` body, 100 IDs per call.
  - Per-chunk fallback to individual `messages.get` on failure -- match the existing `_batchModifyLabels` fallback pattern in this file (look for `_batchModifyLabels` near lines 752-1100).
  - Refactor `_fetchMessagesConcurrent` (Sprint 37) to call `_batchGetMessages` instead of N individual `messages.get` calls. Keep the 8-concurrent chunking around the batchGet HTTP calls themselves (a single batchGet HTTP request can wrap up to 100 sub-requests, so concurrency is much less critical post-batchGet -- but still cap at 2-3 concurrent batchGet calls for very large mailboxes).
  - Apply same change to `fetchMessagesIncremental` so incremental delta scans also use batchGet.
  - Update Issue #247 acceptance check: re-verify on real Gmail account that scan path produces same `EmailMessage` outputs as the Sprint 37 parallel-fetch path.
  - Tests: existing `_fetchMessagesConcurrent` tests pass with batchGet implementation underneath; add 2-3 new tests with mocked HTTP for the `multipart/mixed` request/response parsing.
- **Performance expected over Sprint 37 baseline**: One HTTP request per 100 messages instead of 100 (with 8 concurrent), so ~12-13x reduction in HTTP request count. Wall-clock improvement depends on Gmail batchGet latency vs N parallel small calls; expect modest additional speedup (~1.5-2x over Sprint 37) plus much-reduced rate-limit risk for very large mailboxes.
- **Out of scope**: AOL / IMAP equivalents (no batch endpoint exists for IMAP folder-scoped FETCH); changes to the `_fetchMessagesConcurrent` public-ish signature (callers should not need to change).

**F87. Settings icon on Scan History pages (~1-2h) Priority 55 -- BACKLOG from Sprint 37**
- Phase: UX consistency
- Platform: All
- Source: Sprint 37 Phase 5.3 round-3 manual testing observation (Harold, 2026-05-02): "Setting icon is missing from all Scan history pages, can you add it to all Scan History pages (may only be one)."
- **Current state**: `mobile-app/lib/ui/screens/scan_history_screen.dart` AppBar (and any sub-screens like a Scan Results detail view reached from a history row) does not include the Settings icon that every other primary screen has. Inconsistent with the rest of the app where Settings is one tap away from any AppBar.
- **Acceptance criteria**:
  - Settings IconButton (gear icon) appears in the Scan History AppBar with the same `tooltip: 'Settings'` and `onPressed` behavior as other screens (push `SettingsScreen(accountId: widget.accountId)` route)
  - If there are sub-screens reached from Scan History (e.g., a Scan Results detail), they get the same icon
  - Verify against any AppBar widget standardization (Sprint 33+ navigation consistency work) -- if there is a shared AppBar component, fix at the component level rather than per-screen
  - 1-2 widget tests asserting the Settings icon is present + tappable
- **Implementation note**: Likely a one-line addition (`IconButton` in `actions:`) per affected AppBar. Investigate first whether there is one Scan History screen or several -- Harold's note ("may only be one") suggests possibly only `scan_history_screen.dart` itself.

**F82. Scan History > Scan Results "no rules" progress indicator (~4-8h, design + impl) Priority 75 -- SPRINT 38 CARRY-IN from Sprint 37**
- Phase: UX Improvement
- Platform: All
- Source: Sprint 37 retrospective Category 13 (Harold) -- "What would you suggest for this screen?"
- **Problem**: Users frequently use Scan History > Scan Results to add rules for items showing "no rules". When background scanning is enabled, known-rule matches are deleted and safe-sender matches are moved away, so what remains is the "no rules" pool. Users need to see which items have already had rules added (this session) vs. which still need rules so they can quickly process the entire pool.
- **Reference pattern**: Manual Scan > Live Scan > Results already does this well -- adding a rule removes ALL matching rows from the visible list and async-deletes matching emails. The Scan History > Scan Results screen needs equivalent behavior.
- **Design phase first** (~1-2h, do in Phase 3): produce 1-2 mock variants for Harold's selection. Three candidate approaches:
  - **(a) Mirror Live Scan exactly**: re-evaluate the new rule against in-memory result set; remove all matching rows; toast "Rule applied -- N items removed, M 'no rules' items remaining"; footer counter "M no-rules remaining / total".
  - **(b) Visual badging**: keep all rows but mark addressed rows green/dimmed and remaining "no rules" rows with a yellow flag; "Hide addressed" toggle; counter "[2 addressed / 17 no-rules remaining]".
  - **(c) Two-tab layout**: split Scan Results into "Addressed (rules created this session)" and "Pending (no rules)" tabs with per-tab counter.
- **Implementation phase** (~3-6h, Phase 4): wire the chosen design + 3-5 widget/integration tests covering rule-add -> list-update -> counter-update flow. Async background-delete of matching emails (mirroring Live Scan) so future background scans do not re-encounter them.

### Process

**F81. Store release process documentation (~5-6h) Priority 100 -- SPRINT 36 CARRY-IN (Issue #242)**
- Phase: Documentation / Release Engineering
- Platform: Windows (Microsoft Store)
- Mandatory Sprint 36 task -- not backlog. Carry-in from Sprint 35 retrospective Category 13 addendum (post-retro 2026-04-19); scope expanded 2026-04-20 after the prod-worktree rebuild surfaced 3 additional gaps (see Issue #242 comment).
- New `docs/STORE_RELEASE_PROCESS.md`: end-to-end walkthrough -- pre-release checklist, version bump (5-file checklist), supported rebuild instructions (`flutter pub run msix:create` + the mandatory `build_windows_args` config), MSIX verification, develop -> main merge process, Microsoft Partner Center upload + submit walkthrough, post-submission steps
- Deprecate or remove `mobile-app/scripts/build-msix.ps1` (had a PowerShell parser bug patched in Sprint 35; the Dart `msix` package path is the supported one and is what's wired in `pubspec.yaml`)
- Fix `mobile-app/.gitignore` line 120 (`*.manifest` blocks `runner.exe.manifest` which is required by Windows runner CMakeLists -- breaks fresh worktree builds with "No SOURCES given to target")
- Document `secrets.prod.json` recreation procedure (3 required keys: `WINDOWS_GMAIL_DESKTOP_CLIENT_ID`, `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`, `GMAIL_REDIRECT_URI`); update `secrets.prod.json.template` to use the actual key names the code reads (template currently lists wrong key names)
- Document `build_windows_args` in `msix_config` as a hard requirement (without it, `msix:create` silently produces MSIX with empty OAuth credentials -- Gmail sign-in fails at runtime for every user)
- Update CLAUDE.md Common Commands and ADR-0035 cross-references
- Source: Sprint 35 store-prep + 2026-04-20 prod rebuild made all gaps visible

**F80. 1-page Phase Cheat Sheet for SPRINT_EXECUTION_WORKFLOW.md (~45min) Priority 80 (Issue #241)**
- Phase: Process / Documentation
- Platform: N/A (Claude Code workflow)
- Add a compact (~30-line) Phase Cheat Sheet at the top of SPRINT_EXECUTION_WORKFLOW.md (currently 1357 lines) so models can identify current phase + next action without reading the full doc
- Format: 7-row table (Phase | Purpose | Top-3 Actions | Auto-advance trigger) with anchor links to detailed sections
- Source: Sprint 35 retrospective Process Issues -- proposal P3 (Opus 4.7 phase-boundary overhead)
- Companion to Sprint 35 fixes already shipped: Phase Auto-Advance Rule (CLAUDE.md), Standing Approval Inventory (Phase 3.7), Model-Version Pitfalls appendix (CLAUDE.md)

**F83. Per-account Background Scanning -- separation of concerns (~2 sprints, design + impl + cross-platform validation) Priority 60 -- SPRINT 38+ from Sprint 37**
- Phase: Architecture refactor + code
- Platform: All (Windows, Android, iOS) x (dev, prod, store)
- Source: Sprint 37 retrospective Category 14 (Harold) -- "Important for separation of concerns and future debugging"
- **Current behavior (problem)**: Background Scanning is currently treated as an app-wide setting -- enabling it on ANY account causes ALL accounts to be scanned by the background pipeline. There is no way to enable background scanning for one account but not another.
- **Desired behavior**: Full per-account / per-(provider, email-address) separation of background-scan state, scheduling, and artifacts. Enabling on one account must NOT enable it on another.
- **Phase 1 -- Deep code research (~1 sprint)**: produce a written design doc / ADR enumerating every place in the code that the global background-scan setting is read, written, or assumed, and every artifact path it influences. Required scope:
  - Settings UI -- per-account toggle vs. app-wide toggle
  - Settings storage -- DB schema additions (`background_scan_enabled` per account row vs. a single global key)
  - Task Scheduler entries (Windows) -- one entry per account vs. one global entry that iterates accounts; naming convention for per-account tasks
  - WorkManager entries (Android) -- equivalent
  - Log file separation -- per-account log paths under `logs/`
  - CSV / .xlsx export file separation -- include accountId in filenames
  - Scan modes per account -- already per-account in Sprint 31; verify
  - Scan range per account -- already per-account; verify
  - Selected folders per account -- already per-account; verify
  - Background-scan invocation: `--background-scan` CLI arg currently scans all accounts; change to `--background-scan --account-id=<id>`
  - Help text updates -- explain per-account toggle and what it controls
  - Cross-cutting variant correctness: must work correctly across {Windows Store, Android, iOS} x {dev, prod}
- **Phase 2 -- Implementation (~1 sprint)**: against approved Phase 1 design.
- **Phase 3 -- Cross-platform validation**: Windows dev + prod + Store, Android dev + prod, iOS (when available) dev + prod.
- **Out of scope**: per-account scan-history retention (already handled per-account); per-account safe-sender list (already per-account via accountId).

### Bugs

**BUG-S35-1. Manual rule creation allows duplicate TLD entries (~2-3h) Priority 70 (Issue #239) -- SHIPPED Sprint 36**
- Phase: Bug fix
- Platform: All (rule logic), Windows (where discovered)
- File: `mobile-app/lib/core/services/manual_rule_creator.dart` (or equivalent), plus widget validation in `ManualRuleCreateScreen`
- Failure: Saving a TLD block rule for a TLD already in the bundled rules table (e.g., `.xyz`) silently inserts a duplicate row. Two rules with identical pattern and identical sub-type both run on every scan.
- Fix: Add a uniqueness check on save -- compare normalized pattern + condition_type + sub_type against existing rules table; reject with validation error if match found. Same logic for safe senders.
- Discovery: Sprint 35 F69 execution; required direct SQLite cleanup because UI delete path was non-deterministic when two rules shared the same visible label.
- Source: Sprint 35 F69 manual testing (`docs/sprints/SPRINT_35_PLAN.md` Manual Testing Notes)

**BUG-S36-1. Manual rule creation allows semantic subsumption (~3-5h) Priority 70 (Issue #246) -- NEXT SPRINT (Sprint 37) CARRY-IN**
- Phase: Bug fix / UX enhancement
- Platform: All (rule logic), Windows (where discovered)
- File: `mobile-app/lib/core/services/manual_rule_duplicate_checker.dart` (extend), `mobile-app/lib/ui/screens/manual_rule_create_screen.dart`
- Failure: Sprint 36 BUG-S35-1 catches EXACT duplicates only (same pattern + same sub-type). It does NOT catch semantic subsumption -- e.g., an `exact_domain` safe sender for `cwru.edu` when an `entire_domain` safe sender for `cwru.edu` already exists (the entire-domain rule covers the exact-domain case including all subdomains). Same applies to block rules. Harold found this during Sprint 36 Phase 5 manual testing.
- Fix: Extend duplicate checker to also detect coverage relationships. For safe senders and block rules, if a new rule's pattern is a strict subset of an existing rule's pattern (by sub-type semantics, not regex-subset computation), reject with a validation error that names the existing rule. Coverage matrix:
  - New `exact_email` covered by existing `exact_domain` or `entire_domain` with matching domain
  - New `exact_domain` covered by existing `entire_domain` with matching base domain
  - New `entire_domain` NOT covered by `exact_domain` or `exact_email` (broader type)
  - TLD (block only) has no coverage overlap with domain types -- different comparison space
- Error message must name the existing covering rule so the user knows what's already in place: "A safe sender already covers this: entire_domain cwru.edu."
- 5-8 new unit tests covering the coverage matrix plus the null case (no coverage -> insert succeeds).
- Source: Sprint 36 Phase 5 manual testing feedback (Harold, 2026-04-21)
- Dependencies: Sprint 36 BUG-S35-1 pre-insert checker infrastructure (already shipped in `manual_rule_duplicate_checker.dart`)

**BUG-S37-1. Background scan SQLite "database is locked" when foreground UI is also running (~2-3h) Priority 65 -- SPRINT 38+ from Sprint 37**
- Phase: Bug fix / Concurrency / Single-instance enforcement
- Platform: Windows (where discovered; investigate cross-platform implications)
- Files (likely): `mobile-app/lib/core/storage/database_helper.dart`, the single-instance mutex code (per ADR-0035), background scan worker code path (`--background-scan` invocation)
- Failure: During Sprint 37 Phase 5.3 prod-build manual testing, "Test Background Scan" failed with `SqfliteFfiException(sqlite_error: 5, "database is locked")`. Cause confirmed via `tasklist`: a leftover prod variant process (PID 21772) was holding the prod DB open while the foreground UI also queried it. The single-instance mutex was supposed to make this impossible per ADR-0035.
- **Investigation questions**:
  1. Is the single-instance mutex correctly preventing duplicate prod processes from launching, OR did the user manage to launch a second prod process despite the mutex?
  2. Does the background scan path open its own DB connection that conflicts with the UI's connection within the same process?
  3. Does `--background-scan` run as a separate process from the UI, and if so does it bypass the single-instance mutex (since they would both be valid "first" instances)?
- **Acceptance criteria**:
  - Reproduce reliably (start prod variant, leave running, attempt "Test Background Scan" from same UI -- or some equivalent that triggers the lock).
  - Diagnose whether root cause is mutex bypass, intra-process connection conflict, or inter-process `--background-scan` invocation.
  - Fix root cause (do not silently suppress the SqfliteFfiException).
  - Add 2-3 tests covering the diagnosed scenario.
- Source: Sprint 37 retrospective Category 14 (Phase 5.3 manual testing surfaced this; pre-existing -- not a Sprint 37 regression).

**BUG-S37-2. Bundled-rule TLD data quality + country-TLD blocklist expansion (~3-5h) Priority 50 -- SPRINT 38+ from Sprint 37**
- Phase: Bug fix / Data quality / Bundled rules
- Platform: All
- File: bundled `rules.yaml` + `rules_safe_senders.yaml`, plus `condition_header` rows where `pattern_sub_type='top_level_domain'` in the seeded DB
- **Two combined sub-tasks**:
  - **(a) Data quality cleanup** -- audit existing bundled TLD rules for typos and miscategorizations:
    - Likely typos (single-character TLDs, double-suffix typos): `*.c`, `*.giw`, `*.nwm`, `*.sweepss`, `*.xd`, `*.xn-*`
    - Miscategorized second-level domains masquerading as TLDs: `*.de.com`, `*.in.net`, `*.jp.com`, `*.qzz.io`, `*.sa.com`, `*.uk.com`, `*.us.kg`
    - Approach: script-driven sweep that outputs candidates for Harold review; do NOT auto-apply changes.
  - **(b) Country-TLD (ccTLD) blocklist expansion** -- pre-populate the bundled blocklist with country-code TLDs.
    - **Stated scope (Harold, Sprint 37 retro)**: "Add all 'country' TLD's except US and UK -- open to other suggestions."
    - **Design phase first** (~1h, Phase 3 of whichever sprint takes this): pick a scoping strategy. Four candidate options:
      - **(a) Strict per stated scope**: block all ~250 ccTLDs except `.us` and `.uk`. Simplest, broadest. Risk: blocks legitimate mail from `.ca` Canada, `.au` Australia, `.ie` Ireland, `.nz` New Zealand which Harold may interact with.
      - **(b) English-speaking allies allowlist**: allow `.us`, `.uk`, `.ca`, `.au`, `.nz`, `.ie`. Block all other ccTLDs. Lower false-positive risk for North American / Oceania / Ireland correspondents.
      - **(c) High-spam ccTLDs only**: block known abuse-heavy ccTLDs (`.tk`, `.ml`, `.ga`, `.cf`, `.gq` -- the Freenom set; plus `.ru`, `.cn`, `.top`, etc.). More surgical, fewer false positives, but requires curated source list.
      - **(d) Allowlist-driven**: user configures allowed ccTLDs at first run; default-block everything else. Most flexible, most setup friction.
    - Source for the canonical ccTLD list: ICANN ISO 3166-1 alpha-2 list.
- **Implementation phase**: produce a YAML patch / DB migration with the chosen TLDs as `pattern_sub_type='top_level_domain'` block rules. Include a one-time migration that removes the typos identified in sub-task (a) so the cleanup ships with the expansion.
- Source: Sprint 37 retrospective Category 14 (Claude + Harold combined). Could roll into F33 (HOLD) when reactivated, OR ship standalone as a smaller Sprint 38+ task.

### Security Hardening (Sprint 31 Audit)

**SEC-4. Android: Create network_security_config.xml (~1h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Block cleartext traffic, pin domains for OAuth and IMAP
- Reference in AndroidManifest.xml
- Source: Sprint 31 security audit (S11)


**SEC-6. Android: Configure release signing (~2h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Create release keystore, configure in build.gradle.kts
- Overlaps with GP-2 (release signing)
- Source: Sprint 31 security audit (S12)

**SEC-7. Android: Enable R8 obfuscation + Dart obfuscation (~2h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Enable minifyEnabled, create proguard-rules.pro
- Use --obfuscate --split-debug-info for Dart
- Overlaps with GP-9 (ProGuard/R8)
- Source: Sprint 31 security audit (S13)

**SEC-8b. Certificate pinning for IMAP endpoints (~4-6h) Priority 42 -- HIGH**
- Phase: Security
- Platform: All
- OAuth HTTPS pinning shipped Sprint 33 (CertificatePinner + PinnedHttpClient for accounts.google.com, oauth2.googleapis.com, gmail.googleapis.com, www.googleapis.com)
- Gap: `enough_mail.ImapClient.connectToServer` does not expose a `SecurityContext` or bad-cert callback, so IMAP pinning (imap.gmail.com, imap.aol.com, etc.) was deferred
- Options: (1) fork `enough_mail` to expose the callback; (2) wrap the socket manually via `SecureSocket.connect` with a custom `SecurityContext` before handing it to the IMAP client; (3) file upstream issue on `enough_mail`
- Source: Sprint 33 SEC-8 implementation notes (CertificatePinner dartdoc)

**SEC-9. Move hardcoded Android client ID to build-time injection (~1h) Priority 42 -- HIGH**
- Phase: Security
- Platform: Android
- Move _androidClientId to --dart-define or google-services.json
- Source: Sprint 31 security audit (S5)

**SEC-11b. SQLCipher driver swap + plaintext-to-encrypted migration (~6-10h) Priority 60 -- MEDIUM**
- Phase: Security
- Platform: All
- Sprint 33 shipped the infrastructure: DatabaseEncryptionKeyService (256-bit key in flutter_secure_storage), opt-in `encrypt_database` settings toggle (default off)
- Gap: DatabaseHelper still uses the plaintext sqflite driver. Flipping requires:
  - Add deps: `sqflite_sqlcipher` + `sqlcipher_flutter_libs`
  - Platform plugin registration for Windows + Android
  - Atomic plaintext-to-encrypted migration on first opt-in (backup, re-open with key, copy, swap, verify, delete backup)
  - QA on real installs (Windows desktop + Android emulator + physical device)
  - Flip `encrypt_database` default to true after QA
- Source: Sprint 33 SEC-11 scoping decision (partial completion)

**SEC-15. IMAP host validation for custom servers (~1h) Priority 62 -- MEDIUM**
- Phase: Security
- Platform: All
- Reject internal/private IP ranges when custom IMAP is implemented
- Dependency: F37 (folder selectors / custom IMAP)
- Source: Sprint 31 security audit (S19)

**F6. Provider-Specific Optimizations (~10-12h) Priority 100**
- Phase: Performance
- Platform: All
- [Detail](#f6-provider-specific-optimizations)

**F61. Architecture documentation refresh (~4-6h) Priority HOLD**
- Phase: Documentation
- Platform: All
- Update ARCHITECTURE.md: remove Dual-Write pattern (superseded Sprint 20), add missing services (DefaultRuleSetService, RuleConflictDetector, EmailAvailabilityChecker, EmailBodyParser, DevEnvironmentSeeder), add missing screens (yaml_import_export, rule_test), add missing DB tables (unmatched_emails, background_scan_log)
- Update ARSD.md: remove Dual-Write from design patterns table, update Store certification status to "Passed", update Glossary
- **Sprint 37 additions** (added 2026-05-01 from Sprint 37 retrospective Imp-10): also add the new types and schema introduced after the original F61 scope was written:
  - `manual_rule_duplicate_checker.dart` -- new service that owns subsumption + duplicate detection (Sprint 36 BUG-S35-1, Sprint 37 BUG-S36-1).
  - `SubsumingRuleInfo` class -- carries the "covering rule" details surfaced to the user when a manual rule attempt is rejected (Sprint 37).
  - `IncrementalFetchResult` class -- Gmail-specific incremental scan result (full / partial / expired) returned by `GmailApiAdapter.fetchIncrementalChanges` (Sprint 37 F6c).
  - `Gmail batch operations` (Sprint 25) and parallel `messages.get` fetch (Sprint 37 F6a) -- both should appear in the Gmail adapter section of ARCHITECTURE.md.
  - DB schema v4 migration (`last_history_id` column on the per-account state table, Sprint 37 F6c) -- ARCHITECTURE.md DB schema section should reflect v4.
- HOLD rationale: Moved to HOLD during Sprint 33 planning (April 14, 2026) per user direction. Sprint 33 includes ARCHITECTURE.md updates for new components (SQLCipher, HelpScreen, DataDeletionService, PatternCompiler revisions) so partial doc refresh happens organically. Full F61 work can be reactivated when next periodic architecture review is scheduled.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gaps G1-G6, G16-G22) + Sprint 37 retrospective Category 12 + Imp-10

**F64. CI/CD pipeline with GitHub Actions (~4-6h) Priority HOLD**
- Phase: DevOps
- Platform: All
- GitHub Actions workflow for: flutter analyze, flutter test, build verification
- Trigger on PR to develop
- HOLD rationale: Current CI/CD equivalent is handled by Claude Code sprint execution workflow (flutter analyze, flutter test, Windows build in Phase 5). Could be implemented later if beneficial to dev team, maintenance team, or instructed by Product Owner.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G24)

### HOLD Items (Periodic Reviews)

**F70. Periodic Security Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Security Spike (reusable template)
- Platform: All
- **Generic scope**: Security review based on Application Development Best Practices and OWASP Mobile Top 10 (use current year edition)
- **Application-specific scope**:
  - Dependency CVEs (flutter pub outdated, known vulnerability databases)
  - SQL injection and parameterization audit
  - Regex injection and ReDoS pattern review
  - Credential storage and logging audit
  - Platform-specific security: Windows 11 Store (MSIX sandbox, AppContainer), Android (APK/AAB signing, manifest permissions, ProGuard), iOS (App Transport Security, keychain, sandbox), Linux (file permissions, desktop integration)
  - App store compliance: Microsoft Store certification requirements, Google Play data safety policies, Apple App Store review guidelines
  - Device-specific concerns: biometric auth, secure enclave, clipboard access, screenshot protection
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic security review is needed.
- Source: Sprint 31 retrospective feedback

**F71. Periodic Architecture Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Architecture Spike (reusable template)
- Platform: All
- **Generic scope**: Architecture review based on Application Development Best Practices
- **Application-specific scope**:
  - ADR drift detection: compare all ADRs against current codebase implementation
  - ARCHITECTURE.md alignment: verify documented components, services, and patterns match code
  - ARSD.md alignment: verify architectural requirements and standards document is current
  - Platform-specific architecture: Windows 11 Store (MSIX packaging, single-instance mutex, app data paths), Android (activity lifecycle, WorkManager, flavors), iOS (SwiftUI/UIKit bridge, entitlements, provisioning), Linux (GTK integration, libsecret, packaging)
  - App store constraints: store-specific sandboxing, capability declarations, update mechanisms
  - Device constraints: screen size breakpoints, input methods (touch, mouse, keyboard), offline capability
  - Dead code and deprecated class detection
  - Test coverage gaps relative to architecture
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic architecture review is needed.
- Source: Sprint 31 retrospective feedback (based on Sprint 30 architecture deep dive experience)

### HOLD Items (Post-Windows Store)

**F33. Body rules cleanup script (~4-6h) Priority HOLD**
- Phase: Core App Quality
- Platform: All
- Post-Windows Store release
- [Detail](#body-rules-cleanup-script)

**F25. Rule Testing UI Enhancements (~6-8h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#f25-rule-testing-ui-enhancements)

**F35. Rule editing UI with regex generation (~8-12h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#rule-editing-ui)

**F37. Folder selectors: two-level listing (~6-8h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#folder-selectors-two-level-listing)

**F74. FAQ section in Help (~2-4h) Priority HOLD**
- Phase: Documentation / UX
- Platform: All
- Post-Windows Store release
- [Detail](#f74-faq-section-in-help)

**F75. Help walkthrough: end-to-end first-use guide (~4-6h) Priority HOLD**
- Phase: Documentation / UX
- Platform: All
- Post-Windows Store release
- [Detail](#f75-help-walkthrough-end-to-end-first-use-guide)

**F76. Visual regression testing for WinWright (~6-10h) Priority HOLD**
- Phase: Testing infrastructure
- Platform: Windows desktop (initially)
- From Sprint 34 retro Category 14: WinWright tests verify presence/clickability via accessibility tree but cannot detect alignment, centering, or visual layout issues. Add screenshot diffing or layout-bounds-check assertions to F69 test suite.

**F77. Hookify rule: block "want me to proceed?" patterns (~1h) Priority HOLD**
- Phase: Process automation
- Platform: N/A (Claude Code harness)
- From Sprint 34 retro Category 14: Sprint plan approval covers all tasks; Claude paused twice for "should I continue?" mid-sprint. Hookify rule should reject phrases like "want me to proceed?", "should I continue?", "ready to proceed with X?" with the sprint-plan-approval reminder.

**F78. Widget tests for ManualRuleCreateScreen rendering (~3-4h) Priority HOLD**
- Phase: Testing
- Platform: All
- From Sprint 34 retro Category 14: Only logic-level tests for F56 exist. Add widget tests covering radio button selection, input field validation feedback, pattern preview rendering, and confirmation dialog.

**F79. Full WinWright E2E test sweep (run entire suite end-to-end) (~4-8h) Priority HOLD (Issue #240)**
- Phase: Testing / Quality
- Platform: Windows
- Run the *entire* WinWright suite (currently 7 scripts) end-to-end against a fresh Windows desktop dev build, with strict pre/post snapshot of DB state to verify zero test artifacts left behind
- Distinct from per-sprint conditional WinWright runs (which only execute scripts whose tested surface was touched by sprint changes)
- Triggers: major release prep, large UI refactor (>10 files in `lib/ui/`), accessibility-tree change, or Product Owner request
- HOLD rationale: On-demand only; not a recurring sprint item. Activate when a trigger condition is met.

### HOLD Items (Android / Google Play Store)

**Issue #163. Android app not tested in several sprints (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Validation sprint needed to verify Android app still works
- Expanded scope (Sprint 30 review): ADR-0028 permission validation (POST_NOTIFICATIONS not needed initially, add when background scanning implemented)
- Expanded scope (Sprint 30 review): Include unique UI tests via Playwright/WinWright as needed/appropriate

**F4. Background Scanning - Android (~14-16h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- [Detail](#f4-background-scanning-android)

**GP-2. Release Signing and Play App Signing (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-3. Android Manifest Permissions (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-4. Gmail API OAuth Verification / CASA (~40-80h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Trigger: 2,500+ users or $5K/yr revenue

**GP-5. Privacy Policy and Legal Documents (~8-16h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-6. Play Store Listing and Assets (~8-12h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-7. Adaptive Icons and App Branding (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-8. Android Target SDK + 16 KB Page Size (~4-8h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-9. ProGuard/R8 Code Optimization (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-10. Data Safety Form Declarations (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-11. Account and Data Deletion Feature** -- Moved to F66 (off HOLD, all platforms including Windows Store). See F66 in Core App section above.

**GP-12. Firebase Analytics Decision (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-16. Google Play Developer Account Setup (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

### HOLD Items (Multi-Platform)

**F67. Platform validation - iOS, Linux, macOS (~4-6h per platform) Priority HOLD**
- Phase: Multi-Platform Readiness
- Platform: iOS, Linux, macOS
- Shared tasks (all 3): validation build, smoke test, IMAP scan test, storage path verification, auth flow testing
- iOS-specific: Xcode config, signing, keychain access for credentials
- macOS-specific: entitlements, sandbox config, notarization requirements
- Linux-specific: desktop entry, packaging (snap/flatpak/AppImage), dependency verification (GTK, libsecret)
- HOLD rationale: No current business need. Activate when distribution is prioritized by Product Owner.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G25)

### HOLD Items (Post-MVP)

**H1. GenAI Pattern Suggestions - Crowdsourced Spam Intelligence (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#142](https://github.com/kimmeyh/spamfilter-multi/issues/142)

**H2. Rule Pattern Consistency - Domain Matching Standards (~4-6h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#140](https://github.com/kimmeyh/spamfilter-multi/issues/140)

**H3. Requirements Documentation System (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: N/A
- Issue [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137)

**H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)

**H5. Outlook.com OAuth Implementation (~16-20h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44)

**F39. Scan Results: Multi-Select and Bulk Rule Application (~12-16h) Priority HOLD**
- Phase: Post-MVP, Post-Windows Store
- Platform: All (may need platform-specific UI)
- [Detail](#f39-scan-results-multi-select-and-bulk-rule-application)

---

## Feature and Bug Details

This section contains detailed specifications for incomplete items only. Completed features have their details in sprint documents and CHANGELOG.md.

### Folder Selectors: Two-Level Listing (F37)

**Status**: New (Sprint 20 testing feedback)
**Estimated Effort**: ~6-8h
**Phase**: Core Feature
**Platform**: All

**Overview**: Update folder selector UI (used by Safe Sender Folder, Deleted Rule Folder, and Default Folders settings) with context-aware behavior: two-level collapsible folders for Default Folders, and flat lists with provider defaults first for Safe Sender and Deleted Rule folder selectors.

**Part A: Default Folders selector (multi-select for scan)**

Two-level collapsible folder tree:

```
INBOX
Bulk Mail
Bulk Email
[Gmail] >              (expandable group, collapsed by default)
    [Gmail]/Trash
    [Gmail]/Spam
    [Gmail]/Sent Mail
    [Gmail]/Drafts
    [Gmail]/All Mail
Notes >                (expandable group)
    Notes/Work
    Notes/Personal
```

- Top-level folders shown flat (INBOX, Bulk Mail, etc.)
- Folders with children shown as expandable groups (chevron icon)
- Only first level of children shown (not grandchildren)
- Collapsed by default -- user expands to see children
- Junk/Trash folders auto-highlighted regardless of nesting depth
- Non-selectable parent containers (e.g., `[Gmail]`) shown as group headers only

**Part B: Safe Sender Folder and Deleted Rule Folder selectors (single-select)**

Flat list with provider default first:

- **Safe Sender Folder**: Provider default safe sender folder listed first (e.g., INBOX), remaining folders alphabetical, no sub-folders
- **Deleted Rule Folder**: Provider default deleted folder listed first (e.g., Trash or [Gmail]/Trash), remaining folders alphabetical, no sub-folders

Provider defaults:
- AOL: Deleted Rule = Trash, Safe Sender = INBOX
- Gmail IMAP: Deleted Rule = [Gmail]/Trash, Safe Sender = INBOX
- Gmail OAuth: Deleted Rule = TRASH, Safe Sender = INBOX
- Yahoo: Deleted Rule = Trash, Safe Sender = INBOX

**Provider-Specific Folder Hierarchies** (research before implementation):
- **Gmail IMAP**: `[Gmail]/` prefix for system folders. Custom labels may also use `/` hierarchy. Separator: `/`
- **AOL**: Flat folder structure (INBOX, Bulk Mail, Bulk Email, Sent, Trash). No sub-folders typically. Separator: `/`
- **Yahoo**: Flat structure similar to AOL (Inbox, Bulk, Sent, Trash, Draft). Separator: `/`
- **iCloud**: May have nested folders. Separator: `/`
- **Custom IMAP**: Unknown hierarchy -- must handle any structure. Separator: varies (usually `/` or `.`)

**Implementation Note**: The path separator varies by provider and is returned by the IMAP server in `listMailboxes()` response. Use `mailbox.pathSeparator` to split paths into parent/child, do not hardcode `/`.

**Acceptance Criteria**:
- [ ] Research and document actual folder hierarchy for each supported provider before implementation
- [ ] Part A: FolderSelectionScreen groups child folders under their parent (Default Folders only)
- [ ] Part A: Parent folders with children show expand/collapse toggle
- [ ] Part A: Groups collapsed by default, only first-level children shown
- [ ] Part A: Non-selectable parent containers cannot be selected, only expanded
- [ ] Part B: Safe Sender Folder selector shows provider default first, flat list, no sub-folders
- [ ] Part B: Deleted Rule Folder selector shows provider default first, flat list, no sub-folders
- [ ] Part B: Provider defaults configured per provider
- [ ] Path separator detected per-provider (not hardcoded)
- [ ] Works for Gmail IMAP, Gmail OAuth, AOL, Yahoo, and custom IMAP
- [ ] Existing folder selection behavior preserved for providers without sub-folders

---

### Rule Editing UI (F35)

**Status**: New (Sprint 20 testing feedback)
**Estimated Effort**: ~8-12h
**Phase**: Core Feature
**Platform**: All

**Overview**: Add the ability to edit existing rules from the Manage Rules screen. Since rules use regex patterns, the UI must help users who are not familiar with regex syntax.

**Key Features**:
1. **User-friendly input**: User enters a domain, email, or keyword in plain text, and the app generates the correct regex pattern
2. **Regex validation**: If the user edits the regex directly, validate it in real-time and show errors with suggested corrections
3. **Pattern preview**: Show what the pattern would match against sample text (reuse Rule Testing UI from Sprint 18)
4. **Edit dialog**: Tap a rule in Manage Rules > Edit button in details dialog
5. **Field editing**: Edit source_domain (regenerates regex), pattern_category, pattern_sub_type, enabled/disabled

**Acceptance Criteria**:
- [ ] Edit button in rule details dialog opens edit screen
- [ ] Plain-text domain/email input generates correct regex pattern
- [ ] Direct regex editing with real-time validation
- [ ] Invalid regex shows error message with suggested fix
- [ ] Pattern preview shows match results against sample data
- [ ] Changes saved to database
- [ ] Rule name updated if source_domain changes

---

### F52: Multi-Variant Side-by-Side Install

**Status**: New (April 8, 2026)
**Estimated Effort**: ~16-24h (phased per platform)
**Phase**: Build and Release Infrastructure
**Platform**: All (Windows, Android, iOS)

**Overview**: Extend the existing dev/prod separation (ADR-0035, Windows only) to support all 9 build variants -- 3 channels (dev, production, store) across 3 platforms (Windows, Android, iOS) -- running simultaneously on the same machine/device without rebuilds.

**The 9 Variants**:

| Platform | Dev (feature/develop) | Production (main) | Store (downloaded) |
|----------|----------------------|-------------------|--------------------|
| Windows | [OK] Built today | [OK] Built today | Microsoft Store install |
| Android | TBD | TBD | Google Play install |
| iOS | TBD | TBD | App Store install |

**Current State**:
- **Windows dev/prod**: ADR-0035 implemented in Sprint 19. Same .exe path, but different `secrets.*.json` builds use different data dirs (`MyEmailSpamFilter` vs `MyEmailSpamFilter_Dev`), task names, and mutexes. Whichever was built last is what runs.
- **Windows store**: MSIX submitted to Microsoft Store (Sprint 28). Installs to `Packages\{PackageFamilyName}\` -- separate from dev/prod data dirs.
- **Android**: Single applicationId (`com.example.my_email_spam_filter`). No flavors configured.
- **iOS**: Not yet built.

**Problem**: A user/developer needs to be able to run any combination of these 9 variants simultaneously to:
- Compare dev vs prod behavior on same data
- Test store version against local builds without uninstalling
- Reproduce store-only bugs while a fix is in dev
- Demonstrate prod features while continuing dev work

The Windows dev/prod current implementation requires a rebuild to switch -- only one is "current" at a time.

**Industry Best Practices**:

**Android (Build Flavors)** -- See [Android docs](https://developer.android.com/build/build-variants):
- Use `productFlavors` in `build.gradle.kts` with distinct `applicationIdSuffix` per flavor
- Example: `com.example.app` (store), `com.example.app.prod` (sideloaded prod), `com.example.app.dev` (dev)
- Each variant gets its own data directory, app icon, and Launcher entry
- Side-by-side install works automatically on the same device
- Use Manifest Placeholders for distinct app names (e.g., "SpamFilter", "SpamFilter PROD", "SpamFilter DEV")

**iOS (Bundle ID + Targets/Configurations)** -- See [Xcode multi-config](https://medium.com/@danielgalasko/run-multiple-versions-of-your-app-on-the-same-device-using-xcode-configurations-1fd3a220c608):
- iOS identifies apps by bundle identifier; cannot have two apps with the same ID
- Create distinct bundle IDs per variant: `com.example.spamfilter`, `com.example.spamfilter.prod`, `com.example.spamfilter.dev`
- Use Xcode build configurations or separate targets to switch bundle ID at build time
- Each variant becomes a distinct app on the device with its own data, icon, and TestFlight stream
- TestFlight typically uses a `.test` or `.beta` suffix to avoid colliding with App Store releases

**Windows (MSIX Package Family + Distinct .exe Names)**:
- MSIX uses `PackageFamilyName` for identity. Different `Identity Name` values produce distinct sandboxed installs.
- For non-MSIX (sideloaded) builds, distinct .exe filenames + distinct install directories enable coexistence
- Currently: `MyEmailSpamFilter.exe` is the same filename for dev and prod (only data dirs differ)
- Recommendation: build to environment-specific subdirs (`Release-dev/`, `Release-prod/`) and use environment-specific .exe names (`MyEmailSpamFilter.exe`, `MyEmailSpamFilter-Dev.exe`)

**Cross-Platform Pattern**:
1. **Single source tree, build-time variants**: Use Flutter's `--dart-define` + `flutter run --flavor` for entry points
2. **Distinct identifiers per variant**: applicationId/bundle ID/package family
3. **Distinct visual markers**: app name, icon overlay (e.g., yellow stripe for dev, red for staging)
4. **Distinct data isolation**: separate data dirs (already done for Windows; automatic for Android/iOS via OS)
5. **Build matrix in CI**: each push to `main` builds prod variants, each push to `develop` builds dev variants

**Key Decisions Needed (during sprint planning)**:
1. **Naming convention**: `SpamFilter` (store) / `SpamFilter Pro` (sideloaded prod) / `SpamFilter Dev` (dev)? Or use suffixes?
2. **Build artifact location**: Should dev and prod Windows builds output to separate dirs to enable coexistence without rebuild?
3. **Icon variants**: Acceptable to ship 3 icon designs (or icon overlays generated at build time)?
4. **Store identifier strategy**: Reserve all bundle IDs in advance (App Store Connect, Google Play Console, Microsoft Partner Center)?

**Implementation Phases**:

**Phase 1: Windows distinct .exe + distinct dirs (~4-6h)**
- Update `build-windows.ps1` to output to `build/windows/x64/runner/Release-{env}/`
- Rename .exe to `MyEmailSpamFilter.exe` (prod) and `MyEmailSpamFilter-Dev.exe` (dev) at build time
- Verify Microsoft Store MSIX is unaffected (it installs separately)
- Update launch scripts and docs to reference env-specific paths
- Test: prod and dev builds present simultaneously, both runnable

**Phase 2: Android flavors (~6-8h)**
- Configure `productFlavors` in `mobile-app/android/app/build.gradle.kts`
- Define `dev`, `prod`, `store` flavors with distinct `applicationIdSuffix`
- Add Manifest Placeholder for app name
- Generate distinct icons per flavor (or use icon overlay)
- Update build scripts (`build-with-secrets.ps1`) to take a flavor parameter
- Test: install all 3 variants on emulator side-by-side
- Note: Cannot fully test "store" flavor until app is in Google Play (use `prod` flavor as proxy with different applicationId)

**Phase 3: iOS bundle IDs (~6-10h, requires macOS)**
- Configure Xcode build configurations or targets for `dev`, `prod`, `store`
- Set distinct bundle IDs per configuration
- Configure provisioning profiles for each variant
- Update CI to build correct variant per branch
- Note: Requires Apple Developer Program account and reserved bundle IDs
- HOLD until iOS development begins

**Acceptance Criteria**:
- [ ] Windows: dev, prod, and store builds all installable and runnable simultaneously
- [ ] Android: dev, prod, and store flavors all installable and runnable simultaneously on emulator
- [ ] iOS: dev, prod, and store configurations defined (full validation deferred to iOS dev)
- [ ] All 9 variants have distinct data directories (no cross-contamination)
- [ ] All 9 variants have visual markers (different name and/or icon)
- [ ] Build scripts updated to support variant selection
- [ ] Documentation updated: ADR (extend ADR-0035 or create new ADR), CLAUDE.md, build script READMEs
- [ ] No regression in existing dev/prod Windows separation
- [ ] CI builds correct variant per branch (main = prod+store, develop = dev)

**Dependencies**:
- iOS phase blocked until iOS development begins
- Android store flavor blocked until app is published to Google Play
- Windows store flavor already in place (MSIX from Sprint 28)

**Notes**:
- Phase 1 (Windows) is the only phase that can be done now without external dependencies
- Phases 2 and 3 should be combined with broader Android/iOS work
- Consider whether "store" flavor is really needed as a separate build, or if the actual store-downloaded app suffices

---

### F4: Background Scanning - Android

**Status**: HOLD (Android Google Play Store Readiness)
**Estimated Effort**: ~14-16h
**Phase**: Android Google Play Store Readiness
**Platform**: Android

**Overview**: Automatic periodic background scanning on Android with user-configured frequency using WorkManager.

**Key Features**:
- WorkManager for periodic background jobs
- Configurable scan frequency (hourly, daily, weekly)
- Battery-aware scheduling (defer when battery low)
- Notification on scan completion with results summary

**Dependencies**: Settings infrastructure (completed Sprint 12)

---

### F6: Provider-Specific Optimizations

**Status**: Idea
**Estimated Effort**: ~10-12h
**Phase**: Performance
**Platform**: All

**Overview**: Provider-specific optimizations leveraging unique API capabilities.

**Potential Features**:
- AOL: Bulk folder operations
- Gmail: Label-based filtering (faster than IMAP folder scans)
- Gmail: Batch email operations via API
- Outlook: Graph API integration (when implemented)

**Dependencies**: Core functionality complete

**Notes**: Defer until MVP complete. May not be needed if current performance acceptable.

---

### Body Rules Cleanup Script (F33)

**Status**: New (Sprint 21 testing feedback)
**Estimated Effort**: ~4-6h
**Phase**: Core App Quality
**Platform**: All

**Overview**: One-time Dart CLI script to clean up body rules. Many body rules are URL-targeting patterns that need better regex (similar to header Exact Domain / Entire Domain patterns but appropriate for URLs in email body content). Other body rules target non-URL body content and should not be affected.

**Issues to Address**:

1. **URL-targeting regex improvement**: Body rules that target URLs should use regex that specifically matches URLs, not arbitrary body text. Non-URL body rules (e.g., keyword matching) should remain unchanged.

2. **Duplicate consolidation**: Patterns like `.adamshetzner.com` and `adamshetzner.com` are duplicates and should be consolidated into a single rule.

**Acceptance Criteria**:
- [ ] Script identifies body rules that are URL-targeting vs non-URL patterns
- [ ] URL-targeting patterns converted to proper URL-matching regex
- [ ] Non-URL body rules left unchanged
- [ ] Duplicate patterns consolidated (e.g., `.domain.com` and `domain.com`)
- [ ] Backup DB before changes
- [ ] Report: patterns converted, duplicates removed, unchanged patterns
- [ ] All tests pass after cleanup

---

### F25: Rule Testing UI Enhancements

**Status**: Planned
**Estimated Effort**: ~6-8h
**Phase**: Core Feature
**Platform**: All

**Overview**: Enhance the Rule Testing screen (Settings > Tools > Test Rule Pattern) with additional capabilities to make it a more complete rule authoring tool.

**Enhancements**:
1. **Example Email Addresses**: Pre-populate the "Match against" list with email addresses from the Demo Scan data, giving users real addresses to test against without needing a live scan
2. **Plain Text to Regex Conversion**: When a user enters a plain text pattern (no regex metacharacters) and presses Enter/Test, automatically convert it to the equivalent regex pattern and display both
3. **Edit Rules with Test Tool**: Add a way to open an existing rule in the test tool from the Manage Rules screen, allowing users to modify and test patterns before saving

**Dependencies**: None (builds on existing Rule Testing UI from Sprint 18)

---

### F39: Scan Results Multi-Select and Bulk Rule Application

**Status**: HOLD (Post-MVP, Post-Windows Store)
**Estimated Effort**: ~12-16h
**Phase**: Post-MVP, Post-Windows Store
**Platform**: All (may need platform-specific UI patterns)

**Overview**: Allow users to select multiple emails in Scan Results (live and history) and apply a rule action to all selected items at once, rather than one at a time.

**Selection Mechanics**:
- Radial button (checkbox) to the left of each item for select/unselect
- Ctrl+click to add individual items to selection (Windows/desktop)
- Shift+click to select a range of items between two clicked items (Windows/desktop)
- Selection applies only to the currently filtered list (respects active filter chips)
- Touch-friendly selection for mobile (long-press to enter selection mode, tap to toggle)

**Bulk Actions (right-click context menu / action bar)**:
7 options:
1. Add Safe Sender - Exact Email
2. Add Safe Sender - Exact Domain
3. Add Safe Sender - Entire Domain
4. Add Block Rule - Exact Email
5. Add Block Rule - Exact Domain
6. Add Block Rule - Entire Domain
7. Remove Current Rule

**Platform-Specific UI Considerations**:
- **Windows Desktop**: Right-click context menu, Ctrl+click and Shift+click selection, radial buttons
- **Android/iOS**: Long-press to enter selection mode, floating action bar for bulk actions, tap to toggle selection
- **Display size**: Compact layouts may need bottom sheet instead of context menu
- UI investigation needed before implementation to determine best pattern per platform

**Dependencies**: Scan Results screen (completed Sprint 12), Rule management (completed Sprint 20)

**Acceptance Criteria**:
- [ ] UI investigation completed: document recommended selection and action patterns per platform
- [ ] Multi-select works with Ctrl+click and Shift+click on desktop
- [ ] Radial button per item for direct select/unselect
- [ ] Selection scoped to current filter results only
- [ ] Right-click (desktop) or action bar (mobile) shows 7 bulk action options
- [ ] Bulk action applies chosen rule to all selected emails
- [ ] Works in both live scan results and scan history views
- [ ] Platform-appropriate UI for Windows, Android, and iOS

### F74: FAQ Section in Help

**Status**: HOLD (Post-Windows Store)
**Estimated Effort**: ~2-4h
**Phase**: Documentation / UX
**Platform**: All
**Added**: April 18, 2026 (Sprint 34 testing feedback)

**Overview**: Add a Frequently Asked Questions section to the in-app Help screen (F54 from Sprint 33 added the Help infrastructure). Users have asked about technical concepts during F56 testing that warrant FAQ-style answers rather than burying them in walkthrough text.

**Required FAQ topics**:
- **What is a TLD (Top-Level Domain)?** -- explain TLD concept (.com, .uk, .xyz), how the app's TLD block rules work, why blocking a TLD is heavy-handed (blocks everything from that TLD), and when to use entire-domain rules instead.
- **What is the IANA TLD list and why does the app use it?** -- explain IANA's role as the authority for valid TLDs, why the app rejects fake TLDs (`.com444`, `.whatevericanthinkof`), how the list is updated (`scripts/update_iana_tlds.sh`), and what to do if a real new TLD is rejected (file an issue).
- **What is the difference between Entire Domain, Exact Domain, Exact Email, and Top-Level Domain?** -- with concrete examples and matched/unmatched email lists for each.
- **What is a Safe Sender?** -- explain whitelist precedence over block rules.
- **Why does the scanner skip some emails?** -- explain Read-Only mode, default folders setting, retention.
- **What does "ReDoS" mean and why was my pattern rejected?** -- explain catastrophic backtracking in plain language with the rejected pattern shown.
- **Where is my data stored?** -- per ADR-0030 (privacy/zero telemetry), point to `MyEmailSpamFilter` AppData directory.
- **How do I export and re-import my rules?** -- point to Settings > Data Management.

**Implementation**:
- New `HelpSection.faq` enum value
- New `_buildFaqSection()` method in `help_screen.dart`
- ExpansionTile per question for collapsible Q&A
- Add `Help` icon entry on the Help screen jumping to FAQ
- Cross-reference from manual rule creation screen ("Learn more about TLDs" link)

**Acceptance Criteria**:
- [ ] FAQ section accessible from Help screen
- [ ] At least 8 questions answered (the topics above)
- [ ] Each answer fits on one screen (no scrolling within an answer)
- [ ] TLD/IANA answers explain the F56 validation behavior users encountered
- [ ] Cross-references from rule creation screens to relevant FAQ entries

### F75: Help Walkthrough -- End-to-End First-Use Guide

**Status**: HOLD (Post-Windows Store)
**Estimated Effort**: ~4-6h
**Phase**: Documentation / UX
**Platform**: All
**Added**: April 18, 2026 (Sprint 34 testing feedback)

**Overview**: Add a step-by-step walkthrough to the in-app Help screen that guides a first-time user through the recommended workflow from install to confident production use. Builds on the F54 Help infrastructure (Sprint 33).

**Walkthrough steps to document**:

1. **Install + first launch** -- account setup, choose provider, OAuth or app-password flow, first-run rule seeding (1638 default block rules from F73).

2. **Run a Demo scan first** -- explain the Demo Mode (ADR-0020) with synthetic emails. Lets users see how rule matching, results display, and the Process Results flow work without touching real email.

3. **Read-only manual scan with "move matched" target folder**:
   - Set Manual Scan to **Read-Only Mode** (Settings > Scan)
   - Set the **Default Folders > Spam folder** target to a safe destination (e.g., a user-created `Review-Spam` folder) so matched emails get **moved** rather than deleted
   - Run a manual scan
   - Walk through Results: which emails matched which rules
   - **For false positives** (legitimate emails matched as spam): use F56 to add a Safe Sender (recommend Entire Domain as the general best path; recommend Exact Email for transactional senders like banks/airlines/utilities where only one specific address is trusted)
   - **For real spam** that matched correctly: confirm the rule, no action needed
   - **For real spam not matched**: use F56 Add Block Rule -- recommend Entire Domain as default best practice; recommend Exact Email only for one-off senders that share a domain with legitimate mail (e.g., a single bad sender at gmail.com)

4. **Switch to "move all" mode and re-scan**:
   - After tuning rules and safe senders, change Manual Scan back to delete/move based on rule actions (not Read-Only)
   - Run another manual scan
   - Verify behavior matches expectations from the dry-run pass
   - If unexpected results: revert via Scan History -> per-email undo (where supported), then refine rules

**Implementation**:
- New `HelpSection.walkthrough` enum value
- Numbered step list with screenshots (or text-only initially) per step
- Each step links to the relevant in-app screen (e.g., "Open Settings > Scan" deep-link)
- Add a "First time? Start here" callout on the main Help screen entry pointing to the walkthrough
- Could be presented as a one-time onboarding overlay on first launch (out of scope for v1; flag for future consideration)

**Acceptance Criteria**:
- [ ] Walkthrough section accessible from Help screen
- [ ] All 4 numbered steps documented with concrete UI references
- [ ] Recommendation hierarchy stated clearly: Entire Domain (general best), Exact Email (provider/transactional senders), TLD (heavy-handed, last resort)
- [ ] Read-Only -> review -> tune -> move-all loop documented as the recommended adoption pattern
- [ ] Scan History referenced as the recovery path for unexpected actions
- [ ] Cross-references from Manual Rule Creation screen ("Need help choosing a rule type? See walkthrough")

---

## Google Play Store Readiness (HOLD)

**Added**: February 15, 2026
**Status**: HOLD -- All GP items are on hold pending Product Owner prioritization
**Objective**: Features, configurations, and policy compliance needed to publish on the Google Play Store.

### Current App Assessment

The app is approximately 60-70% ready for Play Store publication. Core spam filtering functionality is complete and production-ready. The remaining work is primarily administrative (signing, permissions, policies, branding) and compliance-related (Gmail API verification, privacy policy, data safety declarations).

### Gap Analysis Summary

| Area | Current State | Play Store Required | Gap Severity |
|------|--------------|---------------------|-------------|
| Application ID | `com.example.spamfiltermobile` | Unique reverse-domain ID | BLOCKING |
| Release Signing | Debug keys only | Production keystore + Play App Signing | BLOCKING |
| App Bundle Format | APK builds only | AAB (Android App Bundle) required | BLOCKING |
| Privacy Policy | None | Publicly hosted URL required | BLOCKING |
| Gmail OAuth Verification | Unverified (dev-only) | Restricted scope verification + CASA audit | BLOCKING |
| Android Permissions | INTERNET only (debug/profile) | INTERNET, POST_NOTIFICATIONS, WAKE_LOCK, etc. | BLOCKING |
| Data Safety Form | Not started | Required in Play Console | BLOCKING |
| Content Rating | Not started | IARC questionnaire required | BLOCKING |
| App Version | 0.1.0 | Must be 1.0.0+ for release | HIGH |
| Adaptive Icons | No (only legacy mipmap) | Required for Android 8+ (API 26+) | HIGH |
| ProGuard/R8 Rules | None configured | Needed for obfuscation and size | HIGH |
| Store Listing Assets | None | Icon 512x512, feature graphic 1024x500, screenshots | HIGH |
| App Label | `spamfilter_mobile` | User-friendly display name | HIGH |
| Target SDK | Flutter default (~34) | API 35 required now; API 36 expected by Aug 2026 | MEDIUM |
| 16 KB Page Size | Unknown | Required for updates by May 1, 2026 | MEDIUM |

### GP Feature List

GP items on HOLD. When taken off hold, they are added to "Next Sprint Candidates" above.

| ID | Title | Est. Effort | ADR | Priority | Status |
|----|-------|-------------|-----|----------|--------|
| GP-1 | Application Identity and Branding | ~4-6h | ADR-0026 (Accepted) | BLOCKING | [OK] COMPLETE (Sprint 19) |
| GP-2 | Release Signing and Play App Signing | ~4-6h | ADR-0027 (Proposed) | BLOCKING | HOLD |
| GP-3 | Android Manifest Permissions | ~4-6h | ADR-0028 (Proposed) | BLOCKING | HOLD |
| GP-4 | Gmail API OAuth Verification (CASA) | ~40-80h | ADR-0029 (Accepted) | BLOCKING | HOLD -- trigger: 2,500+ users or $5K/yr revenue |
| GP-5 | Privacy Policy and Legal Documents | ~8-16h | ADR-0030 (Accepted) | BLOCKING | HOLD |
| GP-6 | Play Store Listing and Assets | ~8-12h | -- | HIGH | HOLD |
| GP-7 | Adaptive Icons and App Branding | ~4-6h | ADR-0031 (Proposed) | HIGH | HOLD |
| GP-8 | Android Target SDK + 16 KB Page Size | ~4-8h | -- | MEDIUM | HOLD |
| GP-9 | ProGuard/R8 Code Optimization | ~4-6h | -- | HIGH | HOLD |
| GP-10 | Data Safety Form Declarations | ~2-4h | -- | BLOCKING | HOLD |
| GP-11 | Account and Data Deletion Feature | ~8-12h | ADR-0032 (Proposed) | HIGH | HOLD |
| GP-12 | Firebase Analytics Decision | ~2-4h | ADR-0033 (Proposed) | MEDIUM | HOLD |
| GP-13 | Persistent Gmail Auth for Production | 0h | -- | -- | RESOLVED (merged with F12, see ADR-0029/0034) |
| GP-14 | IMAP vs Gmail REST API Decision | 0h | ADR-0034 (Accepted) | -- | RESOLVED (dual-path, no migration needed) |
| GP-15 | Version Numbering and Release Strategy | ~2-4h | -- | HIGH | [OK] COMPLETE (Sprint 19) |
| GP-16 | Google Play Developer Account Setup | ~2-4h | -- | BLOCKING | HOLD |

**Total Estimated Effort**: ~112-202 hours (plus 2-6 months for CASA verification if triggered)

### GP Detail Sections

Full detail for each GP item is preserved below for reference when these items are taken off hold.

#### GP-1: Application Identity and Branding

**Status**: [OK] Completed (Sprint 19, Issue #182)
**ADR**: ADR-0026 (Accepted)

Application rebranded to MyEmailSpamFilter with `com.myemailspamfilter` package. Firebase re-registration deferred until domain is registered (Issue #166).

---

#### GP-2: Release Signing and Play App Signing

**ADR**: ADR-0027 (Proposed)
**Estimated Effort**: ~4-6h

Configure production signing for release builds and enroll in Google Play App Signing.

**Tasks**:
- Generate production keystore (upload key)
- Configure `signingConfigs.release` in `build.gradle.kts`
- Secure keystore file (NEVER commit to git)
- Build AAB (Android App Bundle) instead of APK
- Test signed release build on physical device

---

#### GP-3: Android Manifest Permissions

**ADR**: ADR-0028 (Proposed)
**Estimated Effort**: ~4-6h

Declare all required permissions and implement runtime permission requests.

**Permissions Needed**: INTERNET, POST_NOTIFICATIONS (API 33+), RECEIVE_BOOT_COMPLETED, WAKE_LOCK, FOREGROUND_SERVICE (API 34+), FOREGROUND_SERVICE_DATA_SYNC (API 34+)

---

#### GP-4: Gmail API OAuth Verification (CASA)

**ADR**: ADR-0029 (Accepted)
**Estimated Effort**: ~40-80h (2-6 months elapsed)

Complete Google's three-tier verification for restricted Gmail scopes. CASA security assessment by approved third-party lab.

**ON HOLD** -- Trigger: 2,500+ active Gmail IMAP users at $3/yr or $5,000/yr revenue.

**Cost**: Tier 2 ($500-$1,800/yr), Tier 3 ($4,500-$8,000+/yr)

**Phased approach** (per ADR-0029): Phase 1 uses unverified OAuth for alpha/beta (up to 100 users). Phase 2 adds Gmail app passwords via IMAP for general users. Phase 3 (this GP item) pursues CASA when revenue justifies cost.

---

#### GP-5: Privacy Policy and Legal Documents

**ADR**: ADR-0030 (Accepted)
**Estimated Effort**: ~8-16h

Create and publish privacy policy, terms of service, and data handling documentation required by Play Store and Google API Services User Data Policy.

**Decision** (per ADR-0030): Host on `myemailspamfilter.com` via GitHub Pages. Zero telemetry (remove Firebase Analytics). Indefinite local storage with user-controlled deletion. In-app + web page account deletion. Template-based legal review.

---

#### GP-6: Play Store Listing and Assets

**Estimated Effort**: ~8-12h

Create all required Play Store listing assets: icon (512x512), feature graphic (1024x500), screenshots, descriptions, content rating, Data Safety form.

---

#### GP-7: Adaptive Icons and App Branding

**ADR**: ADR-0031 (Proposed)
**Estimated Effort**: ~4-6h

Create adaptive icons (required for Android 8+), replace legacy mipmap icons, establish visual identity.

---

#### GP-8: Android Target SDK and 16 KB Page Size

**Estimated Effort**: ~4-8h

Update target SDK to API 35+, ensure 16 KB page size compatibility (required by May 1, 2026 for app updates).

---

#### GP-9: ProGuard/R8 Code Optimization

**Estimated Effort**: ~4-6h

Configure R8 for code shrinking, obfuscation, and optimization in release builds.

---

#### GP-10: Data Safety Form Declarations

**Estimated Effort**: ~2-4h (after GP-5 privacy policy)

Complete Google Play Data Safety form. All data is on-device only, no sharing, no advertising SDKs.

---

#### GP-11: Account and Data Deletion Feature

**ADR**: ADR-0032 (Proposed)
**Estimated Effort**: ~8-12h

Implement user account and data deletion (required by Google Play policy). Must be discoverable in-app and via web interface.

---

#### GP-12: Firebase Analytics Decision

**ADR**: ADR-0033 (Proposed)
**Estimated Effort**: ~2-4h

Decide whether to use Firebase Analytics/Crashlytics or remove Firebase dependency. Impacts GP-5 and GP-10 disclosures.

---

#### GP-15: Version Numbering and Release Strategy

**Status**: [OK] Completed (Sprint 19, Issue #181)

Tagged v0.5.0, updated pubspec.yaml to 0.5.0+1, established semver convention.

---

#### GP-16: Google Play Developer Account Setup

**Estimated Effort**: ~2-4h

Register Google Play Developer account ($25 one-time), complete identity verification, set up payment profile.

---

### Architectural Decisions Required

| ADR | Title | Blocking Feature | Status |
|-----|-------|-----------------|--------|
| ADR-0026 | Application Identity and Package Naming | GP-1 | Accepted |
| ADR-0027 | Android Release Signing Strategy | GP-2 | Proposed |
| ADR-0028 | Android Permission Strategy | GP-3 | Proposed |
| ADR-0029 | Gmail API Scope and Verification Strategy | GP-4 | Accepted |
| ADR-0030 | Privacy and Data Governance Strategy | GP-5 | Accepted |
| ADR-0031 | App Icon and Visual Identity | GP-7 | Proposed |
| ADR-0032 | User Data Deletion Strategy | GP-11 | Proposed |
| ADR-0033 | Analytics and Crash Reporting Strategy | GP-12 | Proposed |
| ADR-0034 | Gmail Access Method for Production | GP-14 | Accepted |

### Recommended Sequencing (when taken off hold)

1. **Immediate**: GP-16 (Developer Account) + GP-1 (Application Identity) + ADR-0026
2. **Early**: GP-5 (Privacy Policy) + ADR-0030
3. **Sprint Work**: GP-2, GP-3, GP-7, GP-8, GP-9 (Technical features) + related ADRs
4. **After Privacy Policy**: GP-10 (Data Safety Form) + GP-11 (Account Deletion) + ADR-0032
5. **Before Submission**: GP-6 (Store Listing) + GP-15 (Versioning)
6. **Decision**: GP-12 (Analytics) + ADR-0033
7. **Deferred**: GP-4 (CASA Verification) -- trigger: revenue/user threshold

### Cost Estimates

| Item | Cost | Frequency |
|------|------|-----------|
| Google Play Developer Account | $25 | One-time |
| CASA Security Assessment (Tier 2) | $500-$1,800 | Annual |
| CASA Security Assessment (Tier 3) | $4,500-$8,000+ | Annual |
| Domain registration | $12-$20/year | Annual |
| Privacy policy hosting | $0-$10/month | Monthly (or free via GitHub Pages) |

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 5.14 | 2026-04-19 | Sprint 35 retro Category 13 addendum: F81 added as Sprint 36 carry-in (mandatory, not backlog -- Issue #242). Store release process documentation -- new `docs/STORE_RELEASE_PROCESS.md`, deprecate faulty `build-msix.ps1`, walk team through Partner Center upload. Triggered by Sprint 35 store-prep gap-finding. |
| 5.13 | 2026-04-19 | Sprint 35 store release prep: Bumped dev version 0.5.1.0 -> 0.5.2.0 (prod at 0.5.1.0 in store; 0.5.2.0 is next submission). Built signed MSIX (17.4 MB) at `mobile-app/build/windows/x64/runner/Release/my_email_spam_filter.msix`. Sprint 36 to bump dev to 0.5.3.0. |
| 5.12 | 2026-04-19 | Sprint 35 retrospective complete (Phase 7): Applied four of five proposed process improvements -- P1 Phase Auto-Advance Rule (CLAUDE.md item 7), P2 Standing Approval Inventory (Phase 3.7), P4 Model-Version Pitfalls appendix (CLAUDE.md), P5 Sprint Resume Pattern memory. Backlogged P3 as F80 (Phase Cheat Sheet, Issue #241). Closed Category 2 testing gap by adding Phase 5.1.1 step 2a (test-assertion sibling sweep for structural-data changes). Promoted Sprint 35 to Last Completed Sprint; added Sprint 35 row to Past Sprint Summary. |
| 5.11 | 2026-04-19 | Sprint 35 in progress: Removed BUG-S34-1 and F69 (both shipping in Sprint 35 PR #238). Added BUG-S35-1 (manual rule UI accepts duplicates -- Issue #239) discovered during F69 execution; cleanup required direct SQLite delete because UI couldn't disambiguate the duplicate from the bundled rule. Added F79 (Full WinWright E2E sweep) as HOLD item -- Issue #240, on-demand only, distinct from per-sprint conditional WinWright runs. |
| 5.10 | 2026-04-19 | Sprint 34 post-merge cleanup (pre-Sprint-35 backlog refinement): Removed F56, F73, F62, F72 from Next Sprint Candidates -- all four shipped in Sprint 34 (PR #236, see CHANGELOG 2026-04-18). Master plan now reflects only incomplete work for Sprint 35 planning. F69 (WinWright E2E) kept on list -- Sprint 34 shipped only the JSON test scripts (line 35 of CHANGELOG); execution work remains. |
| 5.9 | 2026-04-19 | Sprint 34 post-merge: Added BUG-S34-1 (stale `expect(resetResult.rules, 5)` assertion in default_rule_set_service_test.dart that escaped F73 review and broke develop after PR #236 merge). Carry-in for Sprint 35 per Harold (option 3). |
| 5.8 | 2026-04-16 | Sprint 33 completion: Removed F53, F54, F55, F65, F66 (features) and SEC-1b, SEC-14, SEC-19, SEC-22 (security). SEC-8 split -- HTTPS pinning done; SEC-8b tracks remaining IMAP pinning. SEC-11 split -- infrastructure done; SEC-11b tracks SQLCipher driver swap + migration. Added Sprint 33 to Past Sprint Summary. Updated Last Completed Sprint. |
| 5.7 | 2026-04-14 | Sprint 33 planning: Moved F61 to HOLD per user direction (partial doc refresh happens organically in Sprint 33 via ARCHITECTURE.md updates for SQLCipher/HelpScreen/DataDeletionService/PatternCompiler). |
| 5.6 | 2026-04-14 | Sprint 32 code review findings: Added SEC-1b (ReDoS runtime protection -- design work needed) and F72 (code hygiene cleanup -- emoji, MSVC guard, email message softening) from Phase 5.1.1 automated code review. |
| 5.5 | 2026-04-13 | Sprint 32 completion: Removed 10 completed security items (SEC-1/10/12/13/16/17/18/20/21/23). Added Sprint 32 to Past Sprint Summary. Updated Last Completed Sprint. |
| 5.4 | 2026-04-13 | Sprint 31 retrospective: Added F70 (Periodic Security Deep Dive template) and F71 (Periodic Architecture Deep Dive template) as HOLD items. |
| 5.3 | 2026-03-24 | Sprint 26: Marked F7, F36, F43, F44, F45, F47 complete. Removed F7/F36/F45/F47 detail sections. Added F48 (scan history enhancements). Updated Last Completed Sprint. |
| 5.2 | 2026-03-22 | Sprint 25: Marked F30, F31, F34, F38, F40, F41 complete. Removed F31/F32/F38 detail sections. Added F42 (coverage gaps, on hold). Updated Last Completed Sprint. |
| 5.1 | 2026-03-21 | Sprint 24: Marked WS items complete. Added F40, F41. Updated Last Completed Sprint. |
| 5.0 | 2026-03-19 | Sprint 22: New backlog presentation format (priority-ordered, phase/platform fields, F# identifiers). Assigned F28-F38 to unnamed items. Moved Android/GP items to HOLD. Unholded H0 as F29. Removed old table format. |
| 4.1 | 2026-02-27 | Sprint 18 completion: removed completed items (#154, #141, #167, #168, #169), added F27 (Folder Selection UX), updated Last Completed Sprint and Past Sprint Summary |
| 4.0 | 2026-02-24 | Major restructure: added Maintenance Guide, unified Next Sprint Candidates list, removed completed feature details (F1/F2/F3/F5/F9/F10/F12/F17/F18), removed stale sections (Next Sprint TBD, Issue Backlog, Sprint 11/12 actions), integrated GP items into single priority view, condensed GP details |
| 3.3 | 2026-02-15 | Added Google Play Store Readiness section (GP-1 through GP-16, ADR-0026 through ADR-0034) |
| 3.2 | 2026-02-06 | Sprint 13 completed |
| 3.1 | 2026-02-01 | Added F12 to Sprint 13 |
| 3.0 | 2026-02-01 | Backlog refinement, reprioritized features |
| 2.0 | 2026-01-31 | Restructured to focus on current/future sprints |
| 1.0 | 2026-01-25 | Initial version |
