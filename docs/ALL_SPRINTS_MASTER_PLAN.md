# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: 2026-05-24 (F92 added: dedicated tests for `LiveScanLogger`, deferred from PR #259 Copilot review)

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
| 38 | docs/sprints/SPRINT_38_RETROSPECTIVE.md | [OK] Complete | May 5-18, 2026 |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 38** (May 5 -- May 18, 2026)
- **Type**: Mixed (UX progress indicator + IMAP incremental scans + Gmail batch + live reload + selection + content management + bug fix)
- **Feature**: 8 planned tasks shipped + 1 added mid-sprint (Task 2b PowerShell integration test) + 10 rounds of post-Phase-5.3 manual-testing fixes + 10 Phase 7 retrospective IMPs applied
- **Delivered**:
  - F87 (Settings icon): leading-icon clickable + Settings reorg.
  - BUG-S37-1: background scan SQLite "database is locked" -- main.cpp read-only mutex probe + PowerShell integration test (Task 2b, added mid-sprint).
  - F6c Phase 2 + Issue #250 extension: Gmail OAuth historyId incremental scans wired into EmailScanProvider; ALSO extended to IMAP-backed accounts via new `account_folder_cursors` DB v5 table + GenericIMAPAdapter `fetchMessagesIncremental(startUid, folderName)` using `UID SEARCH UID cursor:*`. Cursor semantics evolved Round 1->Round 4: from "max UID seen" (wrong -- skipped previously-no-rule emails) to **"oldest unaddressed no-rule UID"** per (account, folder); next scan re-fetches from cursor forward so the user's no-rule backlog stays visible until addressed. Cursor advances as rules are added; cleared per-folder when zero unaddressed remain (falls back to daysBack).
  - F88 (Gmail batchGet): batched `users.messages.batchGet` for Gmail OAuth path (gmail-imap intentionally excluded -- IMAP has no batch endpoint per RFC 3501).
  - F86 (live rule reload): post-scan-complete reload + post-rule-add reload pattern; rejected mid-scan rebuild in Round 1 retro.
  - F84 Sub-task A (Ctrl+A select-all): correctly selects all rows in a virtualized list. Sub-tasks B (Shift+Click extend) and C (Ctrl+Click-drag disjoint) deferred to Sprint 39 backlog.
  - F82 (Scan Results "No rule" progress indicator + cross-screen rule-add reload): footer "M of N No rule emails addressed -- K remaining" with progress bar; chip count updates; matched rows hide on inline AND cross-screen rule-add. Required 5 rounds (5, 7, 8, 9 post-test fixes) to converge: Round 5 populated historical EmailMessage `headers` map; Round 7 added re-eval on Scan History re-entry; Round 8 reordered re-eval before first paint; Round 9 decoupled `_hiddenEmailKeys` from scanMode for read-only viewing.
  - F85 (content-management ADR): ADR-0038 + asset manifest + 20 help/*.md files + loader for >500-char user-facing strings.
  - Phase 7 retrospective improvements applied this sprint (10 IMPs): IMP-1 new `/sprint-compact` skill + `docs/SPRINT_RESUME_GUIDE.md`; IMP-2 SPRINT_STOPPING_CRITERIA Criterion 9 clarified (400hr threshold); IMP-3 Decision-Class Checkpoint Protocol added to SPRINT_EXECUTION_WORKFLOW.md; IMP-4 canonical "Next Steps" progression codified; IMP-5 WinWright Phase 5.1.5 made mandatory; IMP-6 widget test for `_loadLastCompletedScan` added to Sprint 39 plan; IMP-7 new `feedback_echo_requirements.md` memory; IMP-8 Opus 4.6 vs 4.7 side-by-side eval added to Sprint 39 plan; IMP-9 Sprint 39 carry-ins recorded in this master plan; IMP-10 Decision-Class Taxonomy added to CLAUDE.md "Things Claude Should NOT Do".
- **Backlog additions** (Sprint 39 carry-ins from Sprint 38 retro Category 13/14): see "Sprint 39 Carry-Ins (Sprint 38 retrospective)" subsection below in "Next Sprint Candidates".
- **Tests**: 1455 passing / 28 skipped / 0 failed (vs 1437 entering sprint = +18 from this sprint scope); flutter analyze: 0 issues.
- **Effort**: ~7h main-sprint Phase 4 wall clock + ~14h Phase 5.3 manual testing across 10 rounds of fixes + ~3h Phase 7 retro and IMP application = ~24h total (vs estimate range 16-24h). 400-hr threshold not approached.
- **Retrospective**: docs/sprints/SPRINT_38_RETROSPECTIVE.md
- **PR**: #258 (against develop)
- **Key process changes**: Decision-Class Checkpoint Protocol (Class 1 architecture / Class 2 development / Class 3 sprint execution decisions need Chief signoff at natural breaks -- sprint-plan approval at Phase 3.7 is NOT durable for these). Wall-clock hours are no longer a stop signal below 400-hr estimate. WinWright sweep now mandatory in Phase 5.1.5.

---

## Next Sprint Candidates

**Last Reviewed**: May 25, 2026 (Sprint 39 Backlog Refinement -- see maintenance log row 5.15)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Sprint Assignment (Sprint 39 Backlog Refinement, 2026-05-25)

The active (non-HOLD) backlog is allocated across the next three sprints as follows:

- **Sprint 39** (in planning): S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3, F91, F89, S38-CI-4, F74, F92, BUG-S37-2, F77, F93
- **Sprint 40** (target): F75, F25, F35, F37, F78, F79, S38-CI-7
- **Sprint 41** (target): SEC-11b, F83

F77 + F93 (Claude-harness process items, ~2-3h combined) added to Sprint 39 per the F93 friction observed during this refinement session. S38-CI-7 (Opus 4.6 vs 4.7 head-to-head) moved to Sprint 40 (2026-05-25): its corrected intent -- 4+ tasks run on BOTH models on separate branches, scored on process/instruction/architecture/stopping-criteria/code-quality adherence -- is a ~6-10h experiment best run against the Sprint 40 task set, not bolted onto Sprint 39. Items moved to HOLD this session: F94 (was F52 Phase 2), F95 (was F52 Phase 3+), F63, SEC-15, SEC-8b, F6 -- all in the Android/GP HOLD group.

### Sprint 39 Carry-Ins (Sprint 38 retrospective, 2026-05-18)

These items were filed during Sprint 38 retrospective and are pre-loaded for the Sprint 39 plan. They are listed here because they came from Category 13 (Minor function updates for the next sprint plan) AND from Sprint 38 deferred-scope items. The Sprint 39 Backlog Refinement (Phase 1) confirms what enters the Sprint 39 plan.

**S38-CI-1. Window X-close button fix (~1-3h) Priority 80**
- Phase: Bug fix
- Platform: Windows desktop
- Symptom: The X close button in the Windows 11 title bar of MyEmailSpamFilter does NOT close the application. Other window controls work; only X is broken. (Image attachment pending from Harold.)
- Investigation hints: check `mobile-app/windows/runner/main.cpp` and `flutter_window.cpp` for WM_CLOSE message handling, and Flutter `WindowListener` / `window_manager` plugin configuration.
- Source: Sprint 38 retro Category 13.

**S38-CI-2. Settings > Manual Scan + Background: relocate "Default folders are account-specific" info card (~1h) Priority 70**
- Phase: UX polish
- Platform: All
- Today: the info card "Default folders are account-specific. Select an account first, then configure in Account Details > Folders." sits at the top of the Manual Scan tab. The Background tab does not show it.
- Change: move the info card to immediately BELOW the "Default Folders" section header on Manual Scan tab; ADD the same card in the same new position on the Background tab.
- Source: Sprint 38 retro Category 13.

**S38-CI-3. F84 Sub-tasks B + C: Shift+Click extend selection + Ctrl+Click-drag disjoint selection (~3-5h) Priority 65** (consolidated 2026-05-25: this is the single entry for F84's remaining work; standalone F84 entry removed to end the double-count)
- Phase: UX improvement
- Platform: Windows desktop (primary); macOS / Linux desktop (secondary -- adapt platform-specific shortcuts; macOS `Cmd+Click`, Linux uses Ctrl as on Windows)
- Source: Sprint 37 retrospective Phase 5.3 round-2 manual testing (Harold, 2026-05-01). Three desktop-standard selection gestures were identified on Manage Rules + Manage Safe Senders after the screen-level `SelectionArea` fix. **Sub-task A (Ctrl+A select-all across the full filtered list, not just the viewport) SHIPPED in Sprint 38.** Sub-tasks B and C remain:
- **Sub-task B**: `Shift+LeftClick` should "extend selection to here" (Windows-standard): preserve the existing selection's start anchor and update its end to the click position. Today an unmodified click resets selection.
- **Sub-task C**: `Ctrl+LeftClick`-and-drag should "add a new disjoint selection range" without clearing the prior selection (Windows-standard for non-contiguous select). Today this is not supported -- only one contiguous selection at a time.
- Tests: 3-5 widget tests covering Shift+Click extend-selection and Ctrl+Click disjoint-range. Real keyboard/pointer simulation via `WidgetTester.sendKeyEvent`.
- Related: applies to any screen with a long virtualized list of selectable text (Scan Results, Scan History detail rows, etc.) -- worth designing as a reusable `SelectableScrollableList` widget rather than duplicating per screen.

**S38-CI-4. IMAP cursor cap at daysBack-ago-UID (~2-3h) Priority 60**
- Phase: Refinement of Sprint 38 F6c IMAP extension
- Platform: All (cursor logic is in EmailScanner + results_display_screen)
- Today: the per-(account, folder) `oldest_no_rule_uid` cursor advances as the user addresses no-rules and is cleared when zero unaddressed remain. But if no-rules arrive ~every 15 minutes (Harold's 2026-05-17 observation), the cursor never naturally clears -- it stays anchored at the oldest UID ever recorded for the folder.
- Change: cap the cursor at the UID that corresponds to `now - daysBack` so the no-rule backlog is bounded by the user's configured retention window. Older-than-daysBack no-rules age out of the cursor naturally even if not addressed.
- **Current state (verified 2026-05-25)**: NOT DONE -- the daysBack-cap is entirely unimplemented. The base cursor works: `oldest_no_rule_uid` lives in the `account_folder_cursors` table (`database_helper.dart:107-116`); `EmailScanner._updateOldestNoRuleCursors()` (`email_scanner.dart:1018-1057`) persists the minimum no-rule UID unconditionally (no clamp); read path (`email_scanner.dart:974-999`) uses it as-is. Building blocks: `daysBack` setting exists (`email_scanner.dart:76,193`); cursor infra complete. MISSING: (1) a UID-for-date lookup to convert `now - daysBack` into a UID floor (no such mechanism today -- `generic_imap_adapter.dart:232-234` computes `sinceDate` as a date but never maps it to a UID), and (2) the clamp itself in `_updateOldestNoRuleCursors` (cap persisted cursor at `max(oldestNoRuleUid, daysBackUid)`).
- **Implementation note**: the UID-for-date lookup needs an IMAP `UID SEARCH SINCE <date>` round-trip; cache the resulting daysBack-UID per (account, folder) for the duration of the scan rather than re-searching on each batch boundary, to avoid an extra round-trip per batch.
- Source: Sprint 38 retro Category 13 + Round 4 deferred decision.

**S38-CI-6. Widget test for `_loadLastCompletedScan` cross-screen reload (~2h) Priority 70 -- testing debt**
- Phase: Testing
- Platform: Unit/widget test (Flutter)
- Add a widget test covering: open historical scan in Scan Results, mutate `RuleSetProvider` rules out-of-band (simulating Settings > Manage Rules > +), re-enter the scan, assert chip count + footer "M of N" + `_hiddenEmailKeys` reflect the new rule on FIRST paint (not after filter toggle).
- Sprint 38 Rounds 7/8/9 were three iterations of the same regression that a single such test would have caught in one go.
- Source: Sprint 38 retro Category 2 (Testing Approach) + Category 14 (Claude addition).

**S38-CI-7. Opus 4.6 vs 4.7 head-to-head model evaluation (~6-10h, procedural) Priority 50 -- MOVED TO SPRINT 40 (intent clarified Harold 2026-05-25)**
- Phase: Process / model evaluation
- **Intent (Harold, 2026-05-25)**: a true head-to-head, NOT two different tasks split across models. Select **at least 4 tasks**. Run EACH task on BOTH Opus 4.6 AND Opus 4.7, on **separate branches** (same task, two independent full runs, one per model), so the two model runs of the same task can be diffed against each other.
- **Evaluation dimensions** (judge the FULL task run on each, per task, per model):
  1. **Sprint-execution-doc process adherence** -- which model followed `SPRINT_EXECUTION_WORKFLOW.md` / phase gates / checklists more faithfully?
  2. **Instruction-following** -- which adhered to the task spec + CLAUDE.md rules + standing instructions better?
  3. **Architecture discipline** -- which deviated LESS from the current architecture (fewer unsanctioned Class-1/2 changes; respected ADRs)?
  4. **Stopping-criteria adherence** -- which respected `SPRINT_STOPPING_CRITERIA.md` (stopped only for valid reasons; did not over-stop or under-stop)?
  5. **Code quality (forward-looking)** -- which produced better code judged for future maintainability/extensibility, not just "passes tests now"?
- **Method**: pick 4+ representative tasks from the Sprint 40 plan; for each, create two branches (e.g., `...-opus46` / `...-opus47`), run the identical task brief on each model, capture the full transcript + diff + rounds-to-converge + any process deviations; score each dimension per the rubric above.
- **Output**: a comparison matrix (task x model x dimension) + narrative, documented in `SPRINT_40_RETROSPECTIVE.md`; feed conclusions into `feedback_opus_pitfalls.md` and model-assignment guidance.
- **Effort raised to ~6-10h**: 4+ tasks x 2 model runs each + scoring is materially larger than the original one-task-each framing.
- Source: Sprint 38 retro Category 5 (Model Assignments) + Category 14; intent corrected by Harold 2026-05-25.

---

### Core App

**F92. Dedicated tests for `LiveScanLogger` (~2-3h) Priority 50 -- BACKLOG from Sprint 39 warmup PR #259 Copilot review (2026-05-23)**
- Phase: Testing
- Platform: All (unit + integration tests)
- Source: Copilot review on PR #259 commit `840c6ea`: "New service `LiveScanLogger` adds file path construction plus setting-gated CSV/XLSX export, but there are no dedicated tests. Please add at least minimal unit coverage for the gating behavior (disabled returns 0/no writes) and basic filename/path construction."
- **Current state**: `mobile-app/lib/core/services/live_scan_logger.dart` shipped in PR #259 with no unit-test coverage. `SettingsStore.getLiveScanDebugCsv` is tested (3 tests in `settings_store_test.dart`) and the per-step log calls in `EmailScanner.scanInbox` are exercised indirectly by the full-suite tests, but the logger's own file IO, path construction, gating behavior, and CSV/XLSX writers are untested.
- **What to add (minimum bar)**:
  - `getLogDir()` returns environment-aware path -- verify dev vs prod suffix; verify cross-platform path separator (path.join) on Linux + Windows + macOS
  - `log(message)` is silent on IO failure (closed file handle, full disk simulation) -- assert no throw
  - `log(message)` appends a timestamped `[LIVE] <message>\n` line in append mode
  - `exportCsvIfEnabled` returns 0 and writes no file when the setting is off
  - `exportCsvIfEnabled` writes both `.data.csv` and `.xlsx` when the setting is on
  - `exportCsvIfEnabled` regenerates the XLSX from the accumulated CSV correctly (multiple-scan accumulation)
- **Implementation notes**:
  - `getApplicationSupportDirectory()` from `path_provider` requires either a test override or running under `PathProviderPlatform.instance` mock. The Flutter test harness's `setMockMethodCallHandler` pattern is the standard approach (see `mobile-app/test/unit/services/background_scan_*` for analogous patterns -- `BackgroundScanWindowsWorker` has similar file IO but is also untested at the file-IO layer, so the test pattern may need to be invented here).
  - Cross-platform path-separator test specifically requires running on multiple platforms or mocking `path.join` -- acceptable to assert against the `path.join`-produced string in a fixed test environment.
- **Acceptance criteria**: 5-8 new tests added; full suite remains green (1460+ -> 1465+); flutter analyze 0 issues.
- **Out of scope**: testing `LiveScanLogger.log` actually writes to the production log path on a live device -- that's manual smoke testing (already done in PR #259 round 1).

**F91. Post-safe-sender-move source-folder dedup (AOL "copy-not-move" reconciliation) (~4-6h, depends on F90 + new Message-ID capture) Priority 85 -- BACKLOG from Sprint 38 manual testing (Harold, 2026-05-23)**
- Phase: Bug fix / IMAP move-semantics reconciliation
- Platform: All IMAP-backed accounts (aol, yahoo, custom); Gmail OAuth path unaffected (Gmail uses labels, not folders)
- Source: Harold, 2026-05-23 live-scan testing on `kimmeyharold@aol.com`. Across scans 3424/3425/3426 the same logical safe-sender emails (e.g., `patriciamarcin@crm.toyotaclevelandheights.com` original `email_received_date 2026-05-14`) appeared with new UIDs each scan (`142989 -> 143113 -> 143127`) in Bulk Mail. The `UID MOVE` to INBOX was reporting success, and Harold confirmed visually that the email IS landing in INBOX -- AND a duplicate is also appearing in Bulk Mail with a fresh UID. AOL's server-side spam classifier is the most likely cause: when we `UID MOVE` a Bulk-Mail-classified message to INBOX, AOL evaluates the appearance-in-INBOX as a delivery event, re-classifies it as bulk, and copies (effectively) the message back into Bulk Mail with a new UID. The next scan sees the new-UID copy as a fresh safe-sender hit, rescues it again, and the loop repeats indefinitely.
- **Current behavior (problem)**:
  - Safe-sender hit in Bulk Mail -> `UID MOVE` to INBOX succeeds -> AOL re-injects a copy back into Bulk Mail with a new UID
  - Next scan sees the new-UID copy, matches it as safe-sender, rescues it again -- "Safe: N" chip stays non-zero forever, Bulk Mail accumulates fresh-UID copies of every rescued safe-sender email
  - Cosmetic for the user (the rescued copy IS in INBOX where they want it) but persistent visual clutter in Bulk Mail and persistent rescue-loop work in every scan
  - Foundational gap: app uses IMAP UID as the email identity (`email_message.id = uid`), so it cannot recognize "this is the same Message-ID I already rescued 30 seconds ago" across scans
- **Desired behavior**:
  - After a safe-sender `UID MOVE` to the target folder, capture the RFC 5322 `Message-ID` of the moved message
  - SELECT the source folder (the one we moved FROM), `UID SEARCH HEADER Message-ID <captured-id>`
  - If the same Message-ID exists in the source folder, **delete the source-folder copy** (move to the configured `deletedRuleFolder` / Trash, same safety semantics as a normal Delete action -- recoverable). This is the "AOL re-injected a duplicate -- clean it up" path
  - If the same Message-ID does NOT exist in the source folder (clean move; AOL did not re-inject), no further action
- **Phase 1 -- Capture RFC 5322 `Message-ID` header on every fetched email (~2h)**:
  - Extend `EmailMessage` to carry `messageIdHeader: String?` (the `<...@...>` value extracted from the RFC 5322 `Message-ID:` header)
  - `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`: when fetching `BODY.PEEK[HEADER]` (or whatever the current fetch field set is), ensure `Message-ID` is included; parse it into the new field
  - `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`: extract from `payload.headers` (Gmail returns the full RFC 5322 header list)
  - Persist in a new `email_actions.rfc5322_message_id` column (nullable; DB v6 migration). Existing rows get `null`.
  - 3-5 unit tests covering: standard `<id@host>` format, missing-header case (set to null), case-insensitive lookup
- **Phase 2 -- Post-move source-folder dedup (~2-3h)**:
  - In `EmailScanner` Phase 6b-1 (safe-sender move batch), AFTER `moveToFolderBatch` returns success:
    - For each successfully-moved message: SELECT source folder, `UID SEARCH HEADER MESSAGE-ID <messageIdHeader>` (case-insensitive per RFC 5322). Be careful with quoting / escaping the `<...>` brackets per IMAP `SEARCH HEADER` syntax (RFC 3501 §6.4.4).
    - If matches return (one or more UIDs in source folder): move those UIDs to `deletedRuleFolder` (Trash), using the SAME `deletedRuleFolder` setting as a normal Delete action
    - Increment a new counter `_safeSenderDedupCount` on `EmailScanProvider` (separate from `_deletedCount` -- this is "AOL re-injection cleanup", not a user-intent delete)
    - Display in the scan summary as a sub-line under "Safe: N" -- e.g., "Safe: 7 (5 source-folder duplicates removed)" -- only when count > 0, so unaffected providers (Gmail) show clean "Safe: N"
  - Log every dedup with the captured `Message-ID` so the new live-scan log (F90) makes the AOL-copy-not-move pattern visible to future debugging
  - Skip dedup entirely if: `messageIdHeader` is null (cannot match without it), platform is Gmail OAuth (uses labels, not folders), or source folder == target folder (no dedup possible)
  - 5-8 widget/integration tests with mocked IMAP responses covering: clean move (no source-folder duplicate -> no dedup), AOL-re-injection case (source-folder duplicate exists -> deleted), Message-ID missing (skip dedup, log warning), Gmail OAuth (skip dedup), source==target (skip dedup)
- **Acceptance criteria**:
  - After Sprint-39 build, a manual test on `kimmeyharold@aol.com` with the Toyota and Pocket safe-sender patterns should show: scan 1 rescues N safe-senders + deletes N source-folder duplicates; scan 2 minutes later finds 0 new safe-sender hits in Bulk Mail (assuming no genuinely-new mail from those senders)
  - The new live-scan log (F90) records every dedup line with the Message-ID so the AOL behavior is documented for future reference
  - Existing safe-sender behavior for providers that DON'T re-inject (Gmail OAuth, Yahoo with different classifier behavior) is unchanged -- the dedup is a no-op when the source-folder search returns empty
  - DB v6 migration ships clean (adds `rfc5322_message_id` column; existing rows null)
  - Trash safety preserved: the source-folder duplicate is moved to the configured `deletedRuleFolder` (default Trash), not hard-deleted. User can recover from Trash within AOL's retention window if anything goes wrong.
- **Out of scope**:
  - Cross-session dedup history ("we rescued this Message-ID yesterday too") -- per-scan-session dedup only
  - Changing the safe-sender move semantics for non-AOL providers (F91 only ADDS post-move cleanup; it does not modify the move itself)
  - Detecting the AOL re-injection PRE-emptively (e.g., by sniffing AOL's spam-classifier headers before moving) -- deferred; the post-move dedup is simpler and correct regardless of root cause
- **Related**: depends on F90 (live-scan log) for log-driven verification; standalone otherwise.

**F89. Surface SPF/DKIM/DMARC authentication failures on rule + safe-sender quick-add prompts (~6-10h, two-phase) Priority 75 -- BACKLOG from Sprint 38 phishing-bypass observation (Harold, 2026-05-21)**
- Phase: Security / UX -- anti-phishing
- Platform: All
- Source: Harold, 2026-05-21 manual triage of a phishing email (`account_update@amazon.com`, subject "Account Recovery: Sign-in and Verify your Amazon account") that was admitted by an overly-broad `@amazon.com` safe-sender pattern. AOL's own spam classifier had flagged it Bulk (almost certainly due to authentication failure), but the app then overrode that judgment because the broad safe-sender whitelist matched the spoofed `From:` header. Body analysis confirmed phishing (S3-bucket credential-harvest links + display-vs-href mismatch). The architectural lesson: a safe-sender whitelist should never honor a `From:` that the receiving server already flagged as unauthenticated. Equivalent risk exists when adding NEW rules / safe senders from email triage screens -- the user should see authentication state at the moment they decide to whitelist or rule-create against a sender.
- **Surfaces to update (all "update email to add a rule / safe-sender" pop-ups)**:
  - `mobile-app/lib/ui/screens/rule_quick_add_screen.dart` (RuleQuickAddScreen)
  - `mobile-app/lib/ui/screens/safe_sender_quick_add_screen.dart` (SafeSenderQuickAddScreen)
  - `mobile-app/lib/ui/screens/email_detail_view.dart` -- inline "Add rule" / "Add safe sender" affordances
  - `mobile-app/lib/ui/screens/results_display_screen.dart` -- inline-rule-add and inline-safe-sender-add affordances in Scan Results (Live + Historical)
  - Any future screen that opens a "create rule from this email" / "whitelist this sender" prompt (audit existing call sites; document a `requiresAuthCheck: true` parameter or a shared `EmailAuthBadge` widget so future surfaces inherit the behavior)
- **Phase 1 -- Adapter side: capture `Authentication-Results` header into `EmailMessage.headers` (~2-4h)**:
  - `EmailMessage.headers` (`Map<String, String>`) exists on the model but no current adapter populates `Authentication-Results`. Verify and extend:
    - `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`: Gmail's `users.messages.get` returns the full `payload.headers` array; ensure `Authentication-Results` (and `ARC-Authentication-Results`, `Received-SPF`) are propagated into `EmailMessage.headers`. Today the adapter likely drops these to save memory.
    - `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` (and any IMAP variant): when fetching `BODY.PEEK[HEADER]`, ensure the Authentication-Results, Received-SPF, DKIM-Signature, ARC-Authentication-Results, and DMARC headers are kept (today the adapter may strip to a small known-key allow-list).
  - Add a small parser `lib/core/services/auth_results_parser.dart` (or extend an existing utility) that reads the relevant headers and produces an `EmailAuthResult` struct: `{spf: pass|fail|softfail|neutral|none|temperror|permerror, dkim: pass|fail|none|...,  dmarc: pass|fail|none|..., raw: String}`. Reference: RFC 8601 Authentication-Results syntax; tolerate provider-specific variations (AOL/Yahoo/Gmail format minor differences).
  - 5-8 unit tests with fixture headers from each provider covering pass/fail/softfail/none.
- **Phase 2 -- UI side: warn-then-confirm on quick-add when authentication failed (~4-6h)**:
  - On every "create rule from this email" / "whitelist this sender" affordance: when opened, compute `EmailAuthResult` from the message headers. Display a compact badge near the affordance:
    - GREEN: all of SPF/DKIM/DMARC pass (sender is authenticated)
    - YELLOW: mixed (e.g., SPF pass + DKIM fail, or DMARC quarantine) -- warning, but not blocking
    - RED: SPF or DKIM fail AND DMARC fail (or DMARC reject) -- the sender failed to prove identity, likely spoofed
    - GREY: no Authentication-Results header present (older mail, internal mail, or provider that didn't sign) -- show as "unknown"
  - **Confirmation dialog content (RED state) -- explicit "why we are warning you" requirements**: the dialog must explain WHAT failed, WHY it matters, and WHAT the user should consider before proceeding. The user must be able to make an informed decision without external research. Required dialog structure:
    1. **Title** (one line, plain-English): "This email could not prove it came from `{displayed sender domain}`"
    2. **What specifically failed** (per-protocol, only show the ones that failed -- skip the ones that passed):
       - SPF: "The sending server is not on `{domain}`'s authorized list of mail servers."
       - DKIM: "The email was not cryptographically signed by `{domain}`, or the signature did not verify."
       - DMARC: "`{domain}` published a policy saying unauthenticated mail should be {rejected|quarantined}, and this email did not meet it."
       - Show the raw `Authentication-Results` header value in a collapsible "Show technical details" expander for users who want to verify.
    3. **What this means for whitelisting / rule-creating** (the consequence, customized by quick-add type):
       - Safe-sender quick-add: "If you whitelist this sender, future emails claiming to be from `{from address}` -- whether real or spoofed -- will bypass all your spam rules. Phishing attempts using the same `From:` will be admitted."
       - Block-rule quick-add: "If you add a block rule for this sender, it will catch real `{from address}` emails AND any other emails that fail authentication and forge this `From:`. The block is sound regardless of authentication; warning is informational only." (RED state should NOT block on block-rule add, only on safe-sender add and on rules that act as exceptions or whitelists -- adjust per rule action.)
    4. **What to consider instead** (alternatives that reduce risk):
       - "Use an exact-email match (`{from address}`) instead of an entire-domain match (`@{domain}`) so this whitelist applies only to this exact local-part."
       - "Verify with the sender out-of-band (phone, in-person) that this email is legitimate before whitelisting."
       - "If this looks like a phishing attempt, report it to your provider and delete it -- do not whitelist."
    5. **Action buttons**: `[Cancel]` (default focus, primary visual weight) and `[Add Anyway]` (secondary visual weight, requires deliberate click; consider a small delay before the button enables, e.g., 1-2s, so users do not click through reflexively).
  - **Confirmation dialog content (YELLOW state) -- inline caution, not modal**: a single line below the quick-add form's submit button explaining what partially passed and what the practical risk is. Example: "Partial authentication: SPF pass, DKIM fail. The sending server is on the domain's authorized list, but the message was not cryptographically signed -- a server compromise or man-in-the-middle could forge this sender. Consider an exact-email rule rather than entire-domain." No modal block; user can submit directly.
  - **Confirmation dialog content (GREY state) -- silent**: no dialog, no inline caution. The email has no Authentication-Results header (older mail, internal mail, a provider that does not sign). Treating GREY as a warning would create false-positive friction on legitimate mail; treating it as safe matches existing app behavior.
  - Persist the original auth result snapshot with the rule/safe-sender at creation time (new column `created_with_auth_state` on `rules` + `safe_senders` tables -- DB v6 migration): future audit query "show me all safe senders I added against unauthenticated email" surfaces past misjudgments.
  - 5-8 widget tests covering each badge state, the RED-state confirmation dialog (cancel + add-anyway paths), and the auth-snapshot column round-trip.
- **Acceptance criteria**:
  - All current quick-add surfaces (RuleQuickAddScreen, SafeSenderQuickAddScreen, email-detail inline affordances, results-display inline affordances) show the auth badge
  - RED state requires explicit confirmation before save; default action is Cancel
  - RED-state dialog explains, in plain English, **what specifically failed (per protocol), why that matters for this quick-add action, and what alternatives the user should consider** -- the user must not need external research to interpret the warning. Raw `Authentication-Results` header is available in a collapsible "Show technical details" expander but is NOT the primary explanation.
  - YELLOW state shows inline caution explaining the partial-authentication risk in plain English (not just "DKIM fail"); does not block save
  - GREY state (no auth header) does NOT block; only RED blocks -- avoid false-positive friction on legitimate internal mail
  - RED-state warning is calibrated to the action: safe-sender quick-add warns about phishing admission risk; block-rule quick-add either does not warn (block is sound regardless of auth) or shows informational-only context
  - The Sprint 38 Amazon phishing email would, with this feature, have shown RED at safe-sender quick-add with a dialog reading approximately: "This email could not prove it came from amazon.com. SPF fail: the sending server is not on amazon.com's authorized list. DKIM fail: the email was not cryptographically signed by amazon.com. DMARC fail: amazon.com publishes a policy saying unauthenticated mail should be rejected. If you whitelist this sender, future emails claiming to be from account_update@amazon.com -- whether real or spoofed -- will bypass all your spam rules. Consider: use exact-email instead of entire-domain; verify with sender out-of-band; or delete and report as phishing." Documenting that scenario as the lead test fixture
  - DB v6 migration ships clean (adds `created_with_auth_state` columns); existing rows get `null` (= "unknown, pre-feature")
  - Telemetry-free per `docs/PRIVACY_POLICY.md` -- the auth result is computed locally from headers and stored locally only
- **Out of scope**:
  - Re-evaluating EXISTING rules/safe-senders against new mail's auth state (separate F-item if/when needed -- requires touching the scan-evaluation hot path, which is heavier)
  - Provider-side DKIM key fetching / verification (we trust the receiving server's Authentication-Results header per industry convention; computing DKIM ourselves is significantly more code and CPU)
  - Per-account override "always trust this domain regardless of auth" -- if requested, add as a follow-up F-item
- **Related**:
  - Could subsume / coordinate with the architectural fix mentioned in the 2026-05-21 phishing email triage (auth-aware filtering as a Microsoft Store full-access release credibility marker).
  - Implementation note: keep the badge widget reusable as `lib/ui/widgets/email_auth_badge.dart` so future surfaces (e.g., the email detail view header) can drop it in without per-screen wiring.

**F74. FAQ section in Help (~2-4h) Priority 60 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Documentation / UX
- Platform: All
- Add a Frequently Asked Questions section to the in-app Help screen (built on F54 Help infrastructure from Sprint 33). Required topics: TLD concept, IANA TLD list, Entire/Exact Domain vs Exact Email vs TLD distinctions, Safe Sender precedence, why the scanner skips emails, ReDoS rejections, where data is stored, export/re-import rules.
- Was HOLD (post-Windows-Store); moved to active per Harold direction. Builds directly on the F85 content-management architecture (long Help strings -> assets) -- FAQ content should author as assets per ADR-0038, not inline Dart.
- [Detail](#f74-faq-section-in-help)

**F75. Help walkthrough: end-to-end first-use guide (~4-6h) Priority 58 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Documentation / UX
- Platform: All
- Step-by-step walkthrough on the Help screen guiding a first-time user: install -> Demo scan -> read-only manual scan with move-matched target -> tune safe senders/rules -> switch to move-all and re-scan. Recommendation hierarchy stated: Entire Domain (general best), Exact Email (transactional senders), TLD (last resort).
- Was HOLD (post-Windows-Store); moved to active per Harold direction. Same ADR-0038 asset-authoring note as F74. Can sprint together with F74 (shared Help-screen surface).
- [Detail](#f75-help-walkthrough-end-to-end-first-use-guide)

**F76. Visual regression testing for WinWright (~6-10h) Priority 54 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Testing infrastructure
- Platform: Windows desktop (initially)
- WinWright tests verify presence/clickability via the accessibility tree but cannot detect alignment, centering, or visual layout regressions. Add screenshot diffing or layout-bounds-check assertions to the WinWright suite (7 scripts as of Sprint 35).
- Was HOLD; moved to active per Harold direction. Source: Sprint 34 retro Category 14.

**F25. Rule Testing UI Enhancements (~6-8h) Priority 48 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Core Feature
- Platform: All
- Three enhancements to the Rule Testing screen (Settings > Tools > Test Rule Pattern): (1) pre-populate match-against list from Demo Scan data; (2) plain-text-to-regex conversion on Test; (3) open an existing rule in the test tool from Manage Rules.
- Was HOLD (post-Windows-Store); moved to active per Harold direction. See [Detail](#f25-rule-testing-ui-enhancements) for the verified current-state breakdown (all 3 NOT DONE as of 2026-05-25).

**F35. Rule editing UI with regex generation (~8-12h) Priority 46 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Core Feature
- Platform: All
- Edit existing rules from Manage Rules: plain-text-to-regex generation, direct-regex editing with validation, pattern preview, edit dialog/button, metadata field editing.
- Was HOLD (post-Windows-Store); moved to active per Harold direction. The Sprint 34 `ManualRuleCreateScreen` already provides the regex-generation building blocks (create-only), so the edit flow can reuse them. See [Detail](#rule-editing-ui) for the verified per-feature current-state breakdown (PARTIAL create-only; edit UI NOT DONE).

**F37. Folder selectors: two-level listing (~6-8h) Priority 44 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Core Feature
- Platform: All
- Part A: two-level collapsible folder tree for the Default Folders selector. Part B: provider-default-first flat lists for Safe Sender / Deleted Rule selectors. Per-provider path-separator detection (not hardcoded `/`).
- Was HOLD (post-Windows-Store); moved to active per Harold direction. See [Detail](#folder-selectors-two-level-listing) for the verified current-state breakdown (Part A NOT DONE; Part B PARTIAL; separator NOT DONE as of 2026-05-25).

**F78. Widget tests for ManualRuleCreateScreen rendering (~3-4h) Priority 42 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Testing
- Platform: All
- Add widget tests covering radio button selection, input-field validation feedback, pattern preview rendering, and confirmation dialog. From Sprint 34 retro Category 14.
- Was HOLD; moved to active per Harold direction. **Current state (verified 2026-05-25)**: claim still TRUE -- `mobile-app/test/ui/screens/manual_rule_create_screen_test.dart` (185 lines) is unit-only (no `testWidgets`/`WidgetTester`/`pumpWidget`); all 4 coverage areas NOT DONE (radio `RadioListTile<ManualRuleType>` ~L644-660, validation feedback, pattern preview ~L575-585, confirmation `AlertDialog` ~L566-609). Pairs naturally with F76 (both WinWright/widget testing infra).

**F79. WinWright full-sweep harness + UI-trigger cadence (~4-8h) Priority 50 -- MOVED OFF HOLD + RESCOPED (Sprint 39 Backlog Refinement, 2026-05-25, Issue #240)**
- Phase: Testing / Quality infrastructure
- Platform: Windows
- **Rescope rationale**: F79 was previously an on-demand *manual run* activity on HOLD. Harold's 2026-05-25 decision: build the automation harness first, then make the full sweep a near-every-sprint activity gated by a UI-change trigger. The thing blocking cheap full-sweeps is tooling (no one-command runner, no state-snapshot verification), not policy. This item now BUILDS that tooling; the cadence-policy change is documented in `docs/TESTING_STRATEGY.md` + `feedback_winwright_policy.md`.
- **Part 1 -- One-command runner (~2-3h)**: harden `mobile-app/scripts/run-winwright-tests.ps1` so all 7 scripts run unattended end-to-end against a fresh dev build. Today the Sprint 35 closeout (README L40-49) drove the scripts *interactively* via MCP primitives because selectors needed live adaptation (off-screen Save button -> `ww_invoke`, dynamic input-field names, `Tab N of 4` selectors). Bake those workarounds into the scripts/runner so no human-in-the-loop is needed. Auto-enable the screen-reader flag + run `doctor` as preflight.
- **Part 2 -- Pre/post dev-DB state snapshot (~2-3h)**: before the sweep, snapshot the dev `spam_filter.db` (rules, safe_senders, settings tables -- hash or row dump). After the sweep, re-snapshot and assert ZERO net change (every script's create -> verify -> delete -> verify-absent lifecycle left no residue). Fail loudly + name the offending rows if drift is found. This is the guard that prevents the Sprint 35 artifact-leak (`.xyz` rule, `test-trusted-domain.com` sender needing manual SQLite cleanup) from recurring.
- **Part 3 -- Cadence policy + docs (~1h)**: update `docs/TESTING_STRATEGY.md` "When to Run" table and `feedback_winwright_policy.md` so the new rule is: run the full sweep at the END of any sprint whose diff touched `lib/ui/**` (Phase 5); skip for pure-backend/docs sprints; the prior per-script conditional run remains available mid-sprint for targeted checks. (Policy docs updated 2026-05-25 ahead of the harness; harness implementation makes the policy cheap to honor.)
- **Acceptance criteria**:
  - `run-winwright-tests.ps1` runs all 7 scripts unattended on a fresh dev build, exits non-zero on any script failure
  - Pre/post DB snapshot verification integrated; a deliberately-leaky test script causes the run to FAIL with the leaked rows named
  - One full unattended sweep completes green with zero net DB change
  - `docs/TESTING_STRATEGY.md` when-to-run table + `feedback_winwright_policy.md` reflect the `lib/ui/**`-touched -> end-of-sprint-sweep cadence
  - Runtime target: full sweep completes in <10 min unattended
- **Out of scope**: adding NEW WinWright scripts for the newly-activated UI items (F25/F35/F37 will add their own scripts when those features ship); visual-regression assertions (that is F76, separate); cross-platform (Windows desktop only -- WinWright is Windows-specific).
- Source: Issue #240; cadence decision Harold 2026-05-25.

### Process

**F77. Hookify rule: block "want me to proceed?" patterns (~1h) Priority 52 -- MOVED OFF HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Process automation
- Platform: N/A (Claude Code harness)
- Sprint plan approval covers all tasks; Claude has paused mid-sprint for "should I continue?" Hookify rule should reject phrases like "want me to proceed?", "should I continue?", "ready to proceed with X?" with the sprint-plan-approval reminder.
- Was HOLD; moved to active per Harold direction. Source: Sprint 34 retro Category 14. Companion to the existing Stop-hook auto-advance enforcement (`feedback_auto_advance_hook.md`) and Phase Auto-Advance Rule (CLAUDE.md) -- this extends that enforcement to the prompt/question surface.

**F93. Auto-advance hook: exempt Backlog Refinement (Phase 1) from procedural-question blocking (~1-2h) Priority 50 -- NEW (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Process automation
- Platform: N/A (Claude Code harness)
- Source: Sprint 39 Backlog Refinement session (2026-05-25). The Stop-hook `.claude/hooks/sprint-auto-advance.ps1` blocks any end-of-turn question on a `feature/\d+_Sprint_\d+` branch. During Backlog Refinement (Phase 1) this produced 5 false positives in one session, because Refinement is PO-driven and surfacing PO decisions (prioritization, item grouping, scope removals) is REQUIRED by `docs/BACKLOG_REFINEMENT.md` Step 3 -- yet there is no SPRINT_N_PLAN.md / TaskList / Phase 3.7 approval to "advance" to. The branch carried the prior warmup-sprint name only because PR #259 shipped from it.
- **Fix options** (decide in design): (a) exempt when no `docs/sprints/SPRINT_N_PLAN.md` exists for the current sprint number (= not yet in Phase 4 execution); (b) add a Phase-1 sentinel file/flag the hook checks; (c) broaden the whitelist to recognize Backlog-Refinement decision phrasings. Option (a) is the cleanest proxy for "in sprint execution vs not."
- **Acceptance criteria**: hook allows PO-decision questions during Backlog Refinement (no SPRINT_N_PLAN.md present); hook still blocks procedural stalls during Phase 4-7 execution; add 2-3 test cases to `.claude/hooks/test-cases/*.json` covering the Phase-1-no-plan allow case.
- Companion memory: `feedback_hook_phase1_gap.md`. Related: F77 (proceed-pattern hookify), `feedback_auto_advance_hook.md`.

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

### HOLD Items (Android / Google Play Store)

**F94. Android dev/prod/store flavors (~6-8h) Priority HOLD (Issue #248) -- RENUMBERED from "F52 Phase 2" + MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Build and Release Infrastructure / Android Google Play Store Readiness
- Platform: Android
- Renumbered from the ambiguous "F52 Phase 2" to a distinct F# (was sharing F52 with the iOS phase, now F95). Sprint 37 shipped F52 Phase 1 (Windows distinct .exe + dirs); this Android-flavors work was deferred and is now grouped with the Android/GP HOLD track per Harold (2026-05-25).
- Android `productFlavors` with `applicationIdSuffix .dev` / `.prod`.
- **Prerequisites (external -- must be done BEFORE this work can produce a runnable Android build):**
  1. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.dev` applicationId
  2. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.prod` applicationId
  3. Google Cloud Console -- create OAuth client ID for `.dev` package + matching SHA-1
  4. Google Cloud Console -- create OAuth client ID for `.prod` package + matching SHA-1
- **Pre-existing investigation item**: `mobile-app/android/app/google-services.json` has `applicationId="com.example.spamfiltermobile"` while `build.gradle.kts` declares `applicationId="com.myemailspamfilter"`. Diagnose and fix this mismatch BEFORE adding flavor complexity (may explain intermittent Android Gmail OAuth).
- Memory note: `project_f52_phase2_blockers.md` has full Sprint 37 deferral context.
- Source: Sprint 37 retrospective Category 11 + Category 13; Issue #248 deferral comment.

**F95. iOS variants + cross-store hardening (~10-16h) Priority HOLD -- RENUMBERED from "F52 Phase 3+" + MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Build and Release Infrastructure
- Platform: iOS, plus polish across all 9 variants (3 stores x 3 channels: dev, production, store)
- Renumbered from the ambiguous "F52 Phase 3+" to a distinct F# (was sharing F52 with the Android phase, now F94). Moved to HOLD with the multi-variant track per Harold (2026-05-25) -- blocked until iOS development begins (requires macOS + Apple Developer account).
- All variants must run simultaneously without rebuild on same machine/device.
- [Detail](#f52-multi-variant-side-by-side-install)
- Source: ADR-0035 dev/prod separation.

**F63. Responsive design framework (~8-12h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: UX Improvement
- Platform: All
- Implement adaptive breakpoints per ARSD AR-7: phone (<600dp), tablet (600-900dp), desktop (>900dp); LayoutBuilder + breakpoints (ARSD A6). Priority screens: scan progress, results display, settings.
- Moved to HOLD per Harold (2026-05-25). Related: F55 (navigation consistency). Source: Sprint 30 gap analysis (gap G23).

**SEC-15. IMAP host validation for custom servers (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security
- Platform: All
- Reject internal/private IP ranges when custom IMAP is implemented. Depends on: F37 (custom IMAP). Moved to HOLD per Harold (2026-05-25). Source: Sprint 31 security audit (S19).

**SEC-8b. Certificate pinning for IMAP endpoints (~4-6h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security
- Platform: All
- OAuth HTTPS pinning shipped Sprint 33; IMAP pinning deferred because `enough_mail.ImapClient.connectToServer` exposes no `SecurityContext`/bad-cert callback. Options: fork enough_mail, wrap socket via `SecureSocket.connect`, or file upstream issue. Moved to HOLD per Harold (2026-05-25). Source: Sprint 33 SEC-8 notes.

**F6. Provider-Specific Optimizations (~10-12h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Performance
- Platform: All
- Moved to HOLD per Harold (2026-05-25). [Detail](#f6-provider-specific-optimizations)

**SEC-4. Android: Create network_security_config.xml (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Block cleartext traffic, pin domains for OAuth and IMAP; reference in AndroidManifest.xml
- Moved to HOLD with the rest of the Android track per Harold (2026-05-25) -- gated by the Google Play release, which is on HOLD. Source: Sprint 31 security audit (S11).

**SEC-6. Android: Configure release signing (~2h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Create release keystore, configure in build.gradle.kts. Overlaps with GP-2 (release signing). Source: Sprint 31 security audit (S12).

**SEC-7. Android: Enable R8 obfuscation + Dart obfuscation (~2h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Enable minifyEnabled, create proguard-rules.pro; use --obfuscate --split-debug-info for Dart. Overlaps with GP-9 (ProGuard/R8). Source: Sprint 31 security audit (S13).

**SEC-9. Move hardcoded Android client ID to build-time injection (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Move _androidClientId to --dart-define or google-services.json. Source: Sprint 31 security audit (S5).

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
- Ask: standardize the regex pattern conventions across `rules.yaml`/`rules_safe_senders.yaml` -- define a fixed taxonomy (exact-email / exact-domain / domain+subdomains / entire-TLD), add a new "domain + all TLDs" type, enforce the standard in tooling/UI, and refactor the ~3000+ inconsistent legacy patterns to conform.
- **Current state (verified 2026-05-25)**: PARTIAL. The standardized taxonomy + generators now exist for NEWLY created rules: `mobile-app/lib/core/utils/pattern_generation.dart` (`generateExactEmailPattern`, `generateDomainPattern`, `generateSubdomainPattern`, `detectPatternType`) and the user-facing `ManualRuleType` enum in `manual_rule_create_screen.dart` (entireDomain `@(?:[a-z0-9-]+\.)*domain$`, exactDomain `@domain$`, TLD `@.*\.tld$`), with `pattern_type` persisted to the DB. Subsumption/dedup (Sprints 36-38, `manual_rule_duplicate_checker.dart`) addresses the "consolidate duplicates" goal for new rules. **Remaining**: (1) the requested "domain + all TLDs" type (`@(?:[a-z0-9-]+\.)*spammer\..*$`) does NOT exist (the UI's `topLevelDomain` is the entire-TLD type, a different thing); (2) the ~3000 legacy `rules.yaml` patterns are NOT categorized/refactored/consolidated; (3) no YAML-schema pattern-type metadata field or build-time validation enforcing the standard on the YAML files. Standardization is prospective (manual-create path) only.

**H3. Requirements Documentation System (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: N/A
- Issue [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137)

**H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)
- Ask: add a "Sent Messages Scan for Safe Senders" flow -- read every message the account owner sent, collect normalized To:/CC: addresses as safe-sender candidates, flag/exclude ones hitting a delete rule or "unsubscribe," dedupe against existing safe senders, persist progress for resume, and give the user a filterable/sortable review UI (with auto-accept option) to approve additions.
- **Current state (verified 2026-05-25)**: NOT DONE -- entire feature remains. `email_scanner.dart` scans inbox/bulk folders only; no Sent-folder traversal and no safe-sender derivation. `CanonicalFolder.sent` exists as generic folder-classification plumbing in the adapters but nothing consumes it for a sent-scan. No sent-scan service, no resume-state store, no candidate-review UI. Reusable building blocks exist but are unwired: address normalization (`pattern_normalization.dart` `normalizeFromHeader`) and safe-sender storage (`safe_sender_database_store.dart`, `safe_senders_management_screen.dart`). Full scope remains: Sent-folder scan, To/CC candidate collection + normalization, delete-rule/unsubscribe flagging, dedup vs existing safe senders, resumable progress, and the approval UI.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- mostly NOT DONE. The unified `mobile-app/lib/ui/screens/folder_selection_screen.dart` handles both multi-select and single-select modes from a FLAT list.
- **Part A (two-level collapsible tree)**: NOT DONE. Folders render flat (~L520-606); no `ExpansionTile`/expandable groups, no non-selectable parent containers. A "Recommended" badge for junk/inbox exists (~L572-590) but that is not the auto-highlight-on-open behavior specified.
- **Part B (provider-default-first, flat, no sub-folders)**: PARTIAL. Single-select via `RadioListTile` exists (~L527-558), and folders are sorted by canonical type (Inbox, Junk) then alphabetically (~L163-175) -- but there is NO provider-specific default-first ordering and NO sub-folder exclusion.
- **Path-separator detection**: NOT DONE. Uses `mailbox.path` directly (`generic_imap_adapter.dart` ~L870-886); `FolderInfo` does not expose the IMAP separator, so callers cannot split paths per-provider. Hardcoded-`/` risk remains.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- but the landscape has shifted since this item was written (Sprint 20). The Sprint 34 `ManualRuleCreateScreen` (`mobile-app/lib/ui/screens/manual_rule_create_screen.dart`) now provides the plain-text-to-regex generation this item asked for, but ONLY for rule CREATION, not EDITING. Per-feature status:
- **(1) Plain-text -> regex generation**: PARTIAL (create-only). `_generatePattern` (~L147-249) converts plain-text email/domain/TLD/URL to regex by selected `ManualRuleType` (entire_domain, exact_domain, exact_email, top_level_domain). No edit mode -- the screen constructor (~L44-54) takes only `mode: ManualRuleMode` (blockRule | safeSender), no `initialRule`/`existingRule` param.
- **(2) Direct regex editing with real-time validation**: NOT DONE. Generated pattern is shown read-only (`SelectableText`, ~L739-766); no editable regex field, no validate-and-suggest-fix.
- **(3) Pattern preview against sample data (reuse Rule Testing UI)**: NOT DONE. `ManualRuleCreateScreen` does not import or link to `RuleTestScreen`.
- **(4) Edit button in rule details dialog**: NOT DONE. `rules_management_screen.dart` details dialog (`_showRuleDetails`, ~L248-329) has only Close / Toggle / Delete.
- **(5) Field editing (source_domain re-regex, category, sub_type, enabled/disabled)**: NOT DONE except enabled/disabled, which is editable via the existing toggle (`_toggleRule`, ~L155-181). source_domain / pattern_category / pattern_sub_type are not editable anywhere -- a rule can only be deleted and recreated.
- **Net**: the create-side regex-generation building blocks now exist and could be refactored into an edit flow; the actual edit UI (dialog Edit button, edit screen, direct-regex-edit, preview integration, metadata field editing) is all still to build. Revised remaining estimate likely toward the lower end of ~8-12h given the reusable generator.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- all 3 enhancements remain NOT DONE.
- **(1) Example email addresses from Demo data**: NOT DONE. `mobile-app/lib/ui/screens/rule_test_screen.dart` (`_loadSampleEmails`, ~L62-112) loads match-against samples only from recent scan history (`scanResultStore.getAllScanHistory(limit: 3)`); no Demo Mode / MockEmailProvider fallback.
- **(2) Plain-text-to-regex in the test tool**: NOT DONE. The screen validates that input is valid regex (~L124-134) but does not detect plain text and auto-convert. (Note: a separate plain-text-to-regex generator DOES exist in `manual_rule_create_screen.dart` for rule *creation* -- it is just not wired into the test screen.)
- **(3) Open existing rule in test tool from Manage Rules**: NOT DONE. `rules_management_screen.dart` has a toolbar icon that opens a BLANK test screen (~L439-446) and the rule details dialog (`_showRuleDetails`, ~L248-329) has only Close / Toggle / Delete -- no "edit and test" affordance that pre-fills the rule's pattern. (`RuleTestScreen` does accept `initialPattern`/`initialConditionType`, used from `rule_quick_add_screen.dart`, so wiring exists but is not connected from Manage Rules.)

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- the bulk/multi-select feature remains NOT DONE. `mobile-app/lib/ui/screens/results_display_screen.dart` has NO per-item checkbox/radial selection (`_buildResultTile` ~L1312-1348), no Ctrl+click / Shift+click / long-press selection mode, and no selection state (only `_selectedFolders` exists for the folder filter, ~L74). What DOES exist is the per-item (single-email) version: the email detail sheet (`_showEmailDetailSheet` ~L1367+) offers single-email quick-add safe-sender (exact email / domain / custom) and quick-add block rule (From / domain / body-URL / custom), with inline single-email re-evaluation via `_evaluationOverrides` (~L90, L1914, L2077). F39 is specifically the BULK version of these existing single-email actions; that bulk layer is entirely unbuilt.

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

5. **What ongoing, daily background scanning looks like** (added Sprint 39 refinement, Harold 2026-05-25):
   - **What it does day-to-day**: once Background Scanning is enabled (Settings > Background), the app scans the configured folders on a schedule (Windows Task Scheduler / Android WorkManager) without the app window being open. Known-rule matches are deleted (or moved per rule action) and safe-sender matches are moved to INBOX automatically -- so the user wakes up to an inbox that has already had the obvious spam cleared.
   - **What the user still sees / does**: the background scan does NOT auto-create rules. Emails that matched no rule ("no rules") are left in place and surfaced for review. So the steady-state daily loop is: background scan clears known spam overnight -> user opens Scan History > Scan Results periodically to process the "no rules" pool (add block rules / safe senders for senders the rules did not yet cover) -> those new rules apply on the next scan.
   - **Where to look**: Scan History shows each background run with its counts (deleted / moved / safe / no-rules). The per-account background log + CSV (F90, shipped) records per-message disposition for after-the-fact review.
   - **Expectation-setting**: the "no rules" count does not go to zero on its own -- it only shrinks as the user adds rules, and it grows as genuinely-new senders arrive. This is normal and expected; the goal is a *manageable* trickle, not zero.

6. **How often do I need to process the "no rules" section?** (added Sprint 39 refinement, Harold 2026-05-25):
   - **The hard constraint**: the scan only looks back `daysBack` days (the configured scan-range / retention window, Settings > Scan). A "no rules" email older than `daysBack` ages out of the scan window and will no longer appear in results. So the practical rule is: **review the "no rules" section at least once per `daysBack` window** if you want to catch every unaddressed sender before it falls out of range.
   - **Recommended cadence**: for a typical `daysBack` of 7-14 days, a weekly review of the "no rules" pool keeps the backlog bounded and ensures nothing ages out unreviewed. Heavy-mail accounts may prefer every 2-3 days.
   - **Why it is not "constant"**: the F82 "no rules" progress indicator (shipped Sprint 38) shows "M of N addressed -- K remaining" so the user can see at a glance whether the pool needs attention. If K is small and stable, the cadence can relax; if K is climbing, review more often or add broader rules (Entire Domain) to cover more senders per rule.
   - **Cross-reference S38-CI-4** (if shipped): the no-rule cursor is capped at the `daysBack` window, so the backlog is bounded by retention regardless of review cadence -- the walkthrough should state that older-than-`daysBack` no-rules age out automatically and are not lost data, just out of the active scan window.

**Implementation**:
- New `HelpSection.walkthrough` enum value
- Numbered step list with screenshots (or text-only initially) per step
- Each step links to the relevant in-app screen (e.g., "Open Settings > Scan" deep-link)
- Add a "First time? Start here" callout on the main Help screen entry pointing to the walkthrough
- Could be presented as a one-time onboarding overlay on first launch (out of scope for v1; flag for future consideration)

**Acceptance Criteria**:
- [ ] Walkthrough section accessible from Help screen
- [ ] All 6 numbered steps documented with concrete UI references
- [ ] Recommendation hierarchy stated clearly: Entire Domain (general best), Exact Email (provider/transactional senders), TLD (heavy-handed, last resort)
- [ ] Read-Only -> review -> tune -> move-all loop documented as the recommended adoption pattern
- [ ] Scan History referenced as the recovery path for unexpected actions
- [ ] Cross-references from Manual Rule Creation screen ("Need help choosing a rule type? See walkthrough")
- [ ] Step 5 explains ongoing daily background scanning: what runs automatically (delete known / move safe), what the user still does (process "no rules"), and where to look (Scan History + F90 logs)
- [ ] Step 6 answers "how often to process 'no rules'": at least once per `daysBack` window; weekly for typical 7-14 day ranges; explains the F82 progress indicator and that older-than-`daysBack` no-rules age out (not lost) per S38-CI-4

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
| 5.16 | 2026-05-25 | Sprint 39 Backlog Refinement (Phase 1, sprint allocation): Assigned active backlog across 3 sprints (summary table added under Next Sprint Candidates). Sprint 39: S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3, S38-CI-7, F91, F89, S38-CI-4, F74, F92, BUG-S37-2, F77, F93. Sprint 40 target: F75, F25, F35, F37, F78, F79. Sprint 41 target: SEC-11b, F83. Renumbered the ambiguous shared "F52 Phase 2/3+" into distinct F94 (Android flavors) + F95 (iOS variants) and moved both to the Android/GP HOLD group. Additional HOLD moves (supersede row 5.15's "stay active" note for these): F63 (responsive design), SEC-15, SEC-8b, F6 (provider optimizations). F75 expanded with two new walkthrough steps (Step 5 ongoing daily background scanning; Step 6 "how often to process 'no rules'" tied to daysBack window + F82 indicator). Created `docs/sprints/SPRINT_39_PLAN.md` for Phase 3.7 approval. |
| 5.17 | 2026-05-25 | Sprint 39 execution + scope adjustment: S38-CI-7 (Opus 4.6 vs 4.7 eval) moved Sprint 39 -> Sprint 40 and re-scoped per Harold's clarified intent (4+ tasks run on BOTH models on separate branches; scored on process-doc adherence / instruction-following / architecture discipline / stopping-criteria / forward-looking code quality; ~6-10h). Sprint 39 now 12 tasks (all shipped + tests green 1530/0). BUG-S37-2 corrective: removed 6 malformed bundled TLD rules (.c .giw .nwm .xd .sweepss .qzz.io) from rules.yaml + v6 cleanup migration; .sweeps/.ca retained; all 194 ccTLDs (except .us/.uk/.ca) confirmed kept per Harold. S38-CI-1 X-close fixed round 3 (removed setPreventClose interception; root cause = window_manager 0.3.9 destroy()=PostQuitMessage-only + swallowed WM_CLOSE -> engine teardown during process-exit unwind w/ orphaned tray) -- manually verified working by Harold. Phase 5.3 manual testing complete 2026-05-25 (Harold): X-close, F91 (AOL dedup), F89 (auth warnings) all verified. Sprint 39 committed as a2bb75e. |
| 5.15 | 2026-05-25 | Sprint 39 Backlog Refinement (Phase 1): Removed S38-CI-5 (IMAP batch research) and F61 (architecture doc refresh) from backlog per Harold. Moved OFF HOLD into active candidates: F74 (Help FAQ, P60), F75 (Help walkthrough, P58), F76 (WinWright visual regression, P54), F25 (Rule Testing UI, P48), F35 (Rule editing UI, P46), F37 (Folder selectors two-level, P44), F78 (ManualRuleCreateScreen widget tests, P42), F77 (hookify "proceed?" rule, P52). F79 moved off HOLD AND rescoped from on-demand manual-run to a harness-BUILD task (one-command unattended runner + pre/post dev-DB snapshot guard, P50, Issue #240); new cadence = full sweep at end of any sprint touching `lib/ui/**` once harness ships -- policy written into `docs/TESTING_STRATEGY.md` When-to-Run + `feedback_winwright_policy.md` memory. Verified-against-code current-state notes added to F25, F35, F37, F39, F78, F79, H2, H4 -- all confirmed NOT essentially complete (F35/H2 PARTIAL via Sprint 34-38 ManualRuleCreateScreen + pattern_generation; rest NOT DONE). Non-HOLD review (Step 6.1) removed 6 stale completed items: F90 (live-scan logging, shipped PR #259), F81 (store release docs, shipped Sprint 36 commit 602053e -- `docs/STORE_RELEASE_PROCESS.md` exists), F85 (content-management for long strings -- ALL 3 phases shipped Sprint 38: ADR-0038 Accepted, 21 Help `.md` files + manifest exist, Settings audit found nothing >500 chars per `assets/content/audit-log.md`), F82 (Scan History no-rules progress indicator -- shipped Sprint 38 Rounds 4-9, design option (a); `_buildNoRuleProgressFooter` + `_reEvaluateNoRuleEmails` in results_display_screen.dart, CHANGELOG 2026-05-17), BUG-S35-1 (duplicate TLD check, shipped Sprint 36), BUG-S36-1 (semantic subsumption, shipped Sprint 37 verified CHANGELOG L177). Second-pass CHANGELOG cross-check of all remaining active IDs (2026-05-25) caught 5 more shipped-but-still-listed stragglers, all Sprint 38: F86 (live reload of rules during scan, Task 5 / Round 1 redesign), F88 (true Gmail batchGet endpoint, Task 4), F87 (Settings icon on Scan History, Task 1), F80 (Phase Cheat Sheet, prepended to SPRINT_EXECUTION_WORKFLOW.md), BUG-S37-1 (background-scan DB-locked mutex probe, Task 2). Moved 4 Android security items to the Android/GP HOLD group (gated by the on-HOLD Play release): SEC-4, SEC-6, SEC-7, SEC-9. SEC-8b + SEC-11b stay active (Platform: All); SEC-15 stays active (now unblockable -- its F37 dependency was activated this session). Resolved S38-CI-3 / F84 double-count: both tracked the same Shift+Click / Ctrl+Click-drag selection work at P65 (F84 Sub-task A shipped Sprint 38; only B+C remain). Consolidated into the single S38-CI-3 carry-in entry; removed the redundant standalone F84 entry. |
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
