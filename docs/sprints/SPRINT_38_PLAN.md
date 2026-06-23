# Sprint 38 Plan: UX Backlog + Gmail Incremental Scans + Content Architecture

**Sprint**: 38
**Date**: 2026-05-13 (Round 1 post-retro additions: 2026-05-16)
**Branch**: `feature/20260505_Sprint_38`
**Issues**: #250 (F6c Phase 2), #251 (F87), #252 (F82), #253 (F84), #254 (F86), #255 (F88), #256 (BUG-S37-1), #257 (F85)
**Type**: Mixed -- UX (F87, F82, F84, F86), Performance (F6c Phase 2, F88), Bug fix (BUG-S37-1), Architecture (F85)
**Estimated Effort**: ~27-41h (Round 1 additions: +~3-4h)
**Wall-clock target**: ~6-10h (based on Sprint 37 actual/estimate ratio of ~20-25%)

## Round 1 Post-Retro Additions (2026-05-16)

Manual testing surfaced four items that required Sprint-internal fixes:

- **F6c Phase 2 + F88 scope extension to IMAP**: original plan scoped these as Gmail-OAuth-only. Manual testing used a `gmail-imap` account so neither feature visibly fired. Scope expanded in Round 1: F6c Phase 2 now ALSO covers IMAP via per-(account, folder) UID cursors (new DB v5 schema + `GenericIMAPAdapter.fetchMessagesIncremental`). F88 IMAP equivalent is NOT shipped (IMAP has no batch endpoint; per `enough_mail`'s FETCH semantics, individual UID FETCHes are the per-message path). The Gmail OAuth path remains the only beneficiary of F88 batchGet.
- **F86 redesign**: original Task 5 design (mid-scan evaluator rebuild) solved the wrong problem. Harold's actual workflow is "scan A completes -> add rule -> scan B does not see new rule". Round 1 removes the mid-scan rebuild and adds post-scan + post-Scan-Results-rule-add reloads.
- **F82 historical-scan path**: the progress footer was hidden on Scan History > Scan Results because the initial-count capture fired BEFORE the async `_historicalResults` load completed, caching count=0 and hiding the footer permanently. Round 1 defers capture until results are loaded.
- **Test 4 batchGet runtime verification gap**: noted in retro Category 2; no code fix (would require dedicated diagnostic surface).

See CHANGELOG `### 2026-05-16` entry for full Round 1 details and the SPRINT_38_RETROSPECTIVE.md for the testing-feedback narrative.

---

## Sprint Objective

Eight items that collectively close out Sprint 37 carry-ins, ship the largest set of UX improvements since Sprint 33, finish the Gmail performance work started in Sprint 37, and establish content-management architecture for future maintainability. No single feature dominates -- this is a focused backlog burn-down with one architecture spike (F85 ADR) that lands during the sprint.

---

## Key Design Decisions

1. **F85 full scope ships in Sprint 38** (Harold direction 2026-05-13). All three phases -- ADR + Help migration + Settings audit -- in one PR rather than split across sprints. Avoids a mid-stream "ADR shipped but no implementation yet" state.

2. **F86 is opportunistic-async, not blocking** (Harold direction 2026-05-13). When user adds a rule during an active scan, the rule-set sync happens in the background without slowing the scan. Only if user triggers a re-scan AND the sync has not yet completed do we surface a status message ("Applying N new rule(s)...") before the re-scan starts. This means F86's implementation prioritizes non-blocking propagation, and adds a tiny re-scan coordination check rather than an across-the-board blocking sync.

3. **Execution order: quick wins first, architecture last.** F87 (1-2h) and BUG-S37-1 (2-4h) go first as warm-ups and to close pre-existing issues before adding new scope. F6c Phase 2 and F88 next (Gmail performance set, related code). F86 and F84 next (UX set, related provider/UI patterns). F82 next (UX + design phase). F85 last (architecture spike + Help migration + Settings audit) because it touches the most files and benefits from the freshest mental model of the surrounding code.

4. **F87 component-level fix preferred.** `scan_history_screen.dart` uses `AppBarWithExit` (shared component used by other screens too). Phase 4 first step: audit `AppBarWithExit` consumers. If Settings icon belongs on all of them, fix at component level. If only Scan History needs it, fix per-screen.

5. **F84 from scratch.** Phase 2 dependency check found ZERO existing `SelectionArea` / `Shortcuts` / `LogicalKeyboardKey.keyA` / `SelectAllIntent` references in `lib/`. Sprint 37 only added per-row `SelectableText`. Building from scratch -- expect 5-7h not 4-6h. Reusable `SelectableScrollableList` widget rather than per-screen duplication.

6. **F82 design phase first.** 1h Phase 4 step to produce 1-2 mock variants for Harold's selection (Option A: mirror Live Scan, Option B: visual badging, Option C: two-tab layout). Implementation only starts after Harold picks.

7. **F85 ADR first.** ADR is mandatory Phase 1 of F85 itself. ADR-0036 will be the next available ADR number. ADR decides asset format (YAML/Markdown/JSON/per-file), loader strategy, validation strategy. Phase 2 + Phase 3 of F85 depend on ADR decisions.

8. **BUG-S37-1 investigation-first.** This is a variable-effort task. If root cause is a simple mutex bypass: 1-2h. If root cause requires architectural change to how `--background-scan` invokes from CLI: 4h+. Phase 4 first step: reproduce reliably, then diagnose, then fix.

9. **No CHANGELOG churn during sprint.** CHANGELOG entries added per task in same commit, per CLAUDE.md changelog policy.

---

## Tasks

### Task 1: F87 -- Settings icon on Scan History pages (~1-2h, Haiku)

**Execution order**: 1 (warm-up; closes Sprint 37 backlog item)

**Issue**: #251

**Problem**: `mobile-app/lib/ui/screens/scan_history_screen.dart` uses `AppBarWithExit` which does not include the Settings icon. 22 other screens have `Icons.settings`. Inconsistent UX.

**Investigation first**: Is `AppBarWithExit` shared? If yes, audit consumers and decide whether Settings icon belongs at component level or per-screen.

**Acceptance Criteria** (from Issue #251):
- [ ] Settings IconButton (gear icon) appears in Scan History AppBar
- [ ] Component-level vs per-screen fix decided based on `AppBarWithExit` audit
- [ ] Tooltip: 'Settings', onPressed pushes `SettingsScreen(accountId: widget.accountId)`
- [ ] 1-2 widget tests asserting icon present + tappable
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Low. Likely 1-line change if per-screen; possibly broader if `AppBarWithExit` shared and other screens also need it.

---

### Task 2: BUG-S37-1 -- Background scan SQLite "database is locked" (~2-4h, Sonnet)

**Execution order**: 2 (closes pre-existing concurrency bug before adding scan-path changes)

**Issue**: #256

**Failure**: `SqfliteFfiException(sqlite_error: 5, "database is locked")` when foreground UI runs alongside background scan. Single-instance mutex (ADR-0035) was supposed to prevent this.

**Investigation Questions**:
1. Is the single-instance mutex correctly preventing duplicate prod processes from launching?
2. Does the background scan path open its own DB connection that conflicts within the same process?
3. Does `--background-scan` run as a separate process from the UI, bypassing the mutex (both would be valid "first" instances)?

**Files (likely)**:
- `mobile-app/lib/core/storage/database_helper.dart`
- Single-instance mutex code (per ADR-0035)
- Background scan worker code path (`--background-scan` invocation)

**Acceptance Criteria**:
- [ ] Reproduce reliably (start prod, leave running, trigger "Test Background Scan")
- [ ] Diagnose root cause: mutex bypass, intra-process connection conflict, or inter-process invocation
- [ ] Fix root cause (do NOT silently suppress the SqfliteFfiException)
- [ ] 2-3 tests covering diagnosed scenario
- [ ] ADR-0035 updated if architectural change needed

**Risk**: Variable. Could be 1h mutex tweak or 4h architectural change.

---

### Task 3: F6c Phase 2 -- Wire EmailScanProvider to use Gmail historyId incremental scans (~3-4h, Sonnet)

**Execution order**: 3 (closes Sprint 37 carry-in; uses already-shipped adapter capability)

**Issue**: #250

**Current state**: Sprint 37 F6c shipped `GmailApiAdapter.fetchMessagesIncremental(startHistoryId)` returning `IncrementalFetchResult` (full / partial / expired). DB v4 migration added `last_history_id TEXT` column on accounts. Provider integration to actually USE incremental scans was staged for Sprint 38.

**Files**:
- `mobile-app/lib/core/providers/email_scan_provider.dart`
- `mobile-app/lib/core/storage/database_helper.dart` (read/write last_history_id)

**Implementation**:
- On scan start, read `last_history_id` for the active account
- If null (first scan ever): full scan path (existing behavior). Persist the historyId of the resulting state after scan completes
- If non-null: call `fetchMessagesIncremental(startHistoryId: last_history_id)`
  - On `full` result: process emails as incremental delta; update `last_history_id` to new historyId
  - On `partial` result: process partial delta + continue from new cursor (Gmail returns multiple pages)
  - On `expired` result: history window expired -- fall back to full scan and refresh `last_history_id`
- Only applies to Gmail provider; AOL / IMAP scan path unchanged
- Update telemetry to log whether each scan was incremental or full

**Acceptance Criteria**:
- [ ] EmailScanProvider reads/writes `last_history_id` for Gmail accounts
- [ ] Branch logic for `full` / `partial` / `expired` IncrementalFetchResult
- [ ] `expired` falls back to full scan cleanly (no data loss)
- [ ] AOL / IMAP path unchanged (regression test)
- [ ] 5-8 new tests covering each result type + first-scan-no-history case
- [ ] Manual testing on real Gmail account confirms incremental scan runs after first full scan
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Low. Adapter is fully shipped; this is provider hook-up + DB read/write. Main risk: edge cases around `expired` result and first-scan state.

---

### Task 4: F88 -- True Gmail batchGet via /batch/gmail/v1 multipart endpoint (~3-4h, Sonnet+Opus)

**Execution order**: 4 (related to Task 3 -- same file, same code path; ride the context)

**Issue**: #255

**Gap from Sprint 37**: F6a shipped 8-concurrent parallel `messages.get` calls. Issue #247 acceptance criteria required true batchGet via `/batch/gmail/v1` multipart endpoint -- not yet done.

**Implementation**:
- New `_batchGetMessages(List<String> messageIds)` helper using `/batch/gmail/v1` HTTP endpoint with `multipart/mixed` body, 100 IDs per call
- Per-chunk fallback to individual `messages.get` on failure (mirror `_batchModifyLabels` pattern at line 1216)
- Refactor `_fetchMessagesConcurrent` to call `_batchGetMessages` (keep 8-concurrent chunking but around batchGet calls; cap at 2-3 concurrent batchGet for very large mailboxes)
- Apply same change to `fetchMessagesIncremental` so Task 3's incremental scans also benefit

**Acceptance Criteria**:
- [ ] `_batchGetMessages` implemented with multipart/mixed parsing
- [ ] Per-chunk fallback to individual `messages.get` on failure
- [ ] `_fetchMessagesConcurrent` refactored to use batchGet
- [ ] `fetchMessagesIncremental` uses batchGet for delta fetches too
- [ ] Existing parallel-fetch tests pass with batchGet underneath
- [ ] 2-3 new tests with mocked HTTP for multipart/mixed parsing
- [ ] Manual testing on real Gmail account: same `EmailMessage` outputs as Sprint 37 parallel-fetch path
- [ ] Issue #247 marked closed once verified

**Risk**: Medium. Multipart/mixed parsing is the highest-complexity sub-task. Mitigation: test with mocked HTTP; verify against real Gmail in Phase 5.3.

**Performance**: ~12-13x reduction in HTTP request count; ~1.5-2x wall-clock improvement over Sprint 37 baseline.

---

### Task 5: F86 -- Live reload of rules / safe senders during active Manual Scan (~2-3h, Sonnet)

**Execution order**: 5 (UX set begins; provider-pattern work)

**Issue**: #254

**Design (per Harold direction 2026-05-13)**: Opportunistic-async, not blocking.

**Implementation**:
- `EmailScanProvider` subscribes to `RuleSetProvider.notifyListeners()` on scan start
- On notification: mark rule-set as dirty (atomic flag), record what change came in
- At next email-batch boundary in scan: atomically swap in-memory `RuleSet` reference
- Already-evaluated emails NOT re-evaluated (avoid surprise reclassification)
- On user-triggered re-scan: check if rule-set sync has completed; if not, show "Applying N new rule(s)..." status message before starting re-scan
- Unsubscribe on scan end / provider dispose

**Files**:
- `mobile-app/lib/core/providers/email_scan_provider.dart`
- `mobile-app/lib/core/providers/rule_set_provider.dart` (verify notifyListeners coverage)
- `mobile-app/lib/ui/screens/scan_progress_screen.dart` (re-scan trigger surface)

**Acceptance Criteria**:
- [ ] Add/edit/delete rule from any management surface during scan -> new rule observed by scanner before next batch
- [ ] Same for safe senders
- [ ] Already-evaluated emails NOT re-evaluated
- [ ] On user-triggered re-scan with sync-pending: "Applying N new rule(s)..." message shows before re-scan starts
- [ ] 3-5 widget tests covering rule-add-during-scan, safe-sender-add-during-scan, rule-delete-during-scan
- [ ] 1-2 tests for re-scan sync-pending message path
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Low. Provider scaffolding ideal; mostly hook-up work.

**Out of scope**: Live-reload during Background Scan.

---

### Task 6: F84 -- Keyboard + multi-region selection on list screens (~5-7h, Sonnet+Opus)

**Execution order**: 6 (UX set continues; from-scratch Flutter shortcut/selection work)

**Issue**: #253

**Important note from Phase 2 dependency check**: ZERO existing `SelectionArea` / `Shortcuts` / `LogicalKeyboardKey.keyA` / `SelectAllIntent` references in `lib/`. Building from scratch. Estimate revised from master plan 4-6h to 5-7h.

**Sub-task A: Ctrl+A select-all across filtered list**
- Default Flutter `ListView.builder` only renders visible items; `SelectionArea` only sees rendered items
- **Approach**: Custom `Shortcuts` widget intercepts `Ctrl+A` on rule/safe-sender management screens. Handler reads `_filteredRules` / `_filteredSenders` in-memory list, joins to text, writes to clipboard. Skip Flutter's selection model for this case (most robust; works regardless of viewport)

**Sub-task B: Shift+LeftClick extend selection**
- Track selection anchor index in screen state
- On `Shift+Click`: select range from anchor to clicked index
- On plain click: reset anchor

**Sub-task C: Ctrl+LeftClick-and-drag disjoint range**
- Track list of selection ranges in screen state
- On `Ctrl+Click`: add clicked index to selection set (toggle behavior)
- On `Ctrl+Drag`: add dragged range to selection set without clearing prior

**Cross-platform**: macOS `Cmd+A`, `Shift+Click`, `Cmd+Click` map equivalently via Flutter's `SingleActivator(LogicalKeyboardKey.keyA, control: !Platform.isMacOS, meta: Platform.isMacOS)` pattern.

**Files**:
- `mobile-app/lib/ui/screens/rules_management_screen.dart`
- `mobile-app/lib/ui/screens/safe_senders_management_screen.dart`
- (Consider) `mobile-app/lib/ui/widgets/selectable_scrollable_list.dart` -- reusable widget if extracted

**Acceptance Criteria**:
- [ ] Ctrl+A on Manage Rules selects all filtered rule rows (text written to clipboard)
- [ ] Same for Manage Safe Senders
- [ ] Shift+Click extends current selection on both screens
- [ ] Ctrl+Click-drag creates disjoint selection on both screens
- [ ] Cmd-on-macOS shortcut equivalents work
- [ ] 3-5 widget tests via `WidgetTester.sendKeyEvent` covering each gesture
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Medium-high. Building from scratch; Flutter selection model is intricate; multi-platform shortcut handling needs care. Mitigation: ship Sub-task A first (simplest, highest user value); Sub-tasks B/C may extract `SelectableScrollableList` widget for reuse.

---

### Task 7: F82 -- Scan Results "no rules" progress indicator (~5-7h, Sonnet+Opus)

**Execution order**: 7 (UX set ends; design phase first)

**Issue**: #252

**Design Phase (~1h)**: Produce 1-2 mock variants for Harold's selection. Three candidate approaches enumerated in Issue #252:
- **Option A: Mirror Live Scan exactly** -- re-evaluate new rule, remove matching rows, toast + footer counter
- **Option B: Visual badging** -- mark addressed rows green/dimmed, "Hide addressed" toggle, dual counter
- **Option C: Two-tab layout** -- "Addressed" tab + "Pending (no rules)" tab with per-tab counter

**Implementation Phase (~3-4h, after Harold picks)**:
- Wire chosen design into Scan Results screen (`results_display_screen.dart` or whatever ends up being the Scan History detail surface)
- Async background-delete of matching emails (mirroring Live Scan pattern) so future background scans do not re-encounter
- Counter / badge updates on each rule-add
- 3-5 widget/integration tests covering rule-add -> list-update -> counter-update flow

**Acceptance Criteria** (placeholder; refined after design):
- [ ] Chosen design (A/B/C) implemented on Scan Results screen
- [ ] Counter / badge updates correctly on rule add
- [ ] Async delete of matching emails works (mirrors Live Scan)
- [ ] 3-5 widget tests
- [ ] Manual testing confirms UX matches design

**Risk**: Medium. Design selection is a user-facing decision; implementation complexity depends on choice (Option A simplest, Option C most work).

---

### Task 8: F85 -- Content-management architecture for long inline strings (~6-10h, Opus)

**Execution order**: 8 (architecture spike last; touches most files)

**Issue**: #257

**Phase 1: ADR (~2-3h, MANDATORY FIRST STEP)**:
- Create `docs/adr/0036-content-management-for-long-strings.md`
- Decide asset format (YAML / Markdown / JSON / per-section files)
- Decide loader strategy (build-time bake vs runtime fetch)
- Decide validation strategy (drift detection between enum and asset keys)
- Decide test strategy (read from asset, not hardcoded duplicates)
- i18n posture (room for future L10n)
- Link from CLAUDE.md

**Phase 2: Help screen migration (~2-3h)**:
- Refactor `mobile-app/lib/ui/screens/help_screen.dart` per ADR decisions
- ~250-300 lines of body text across 20 sections (HelpSection enum) migrate to assets
- All sections migrated in one PR; no mixed inline/external state

**Phase 3: Settings descriptions migration + codebase audit (~2-4h)**:
- Audit ALL `lib/` for string literals >500 characters that are user-facing content
- Known candidates: Settings tabs (General, Account, Manual Scan, Background) of `settings_screen.dart`
- Excluded: regex patterns, SQL DDL, YAML literals, debug log templates, runtime interpolations
- Document audit results in ADR or separate audit log

**Acceptance Criteria**:
- [ ] ADR-0036 shipped + linked from CLAUDE.md
- [ ] Help screen content lives in external asset(s) per ADR
- [ ] Settings tab descriptions migrated to external asset(s)
- [ ] Codebase audit doc enumerates every >500-char user-facing string found
- [ ] Harold can edit any migrated content by opening one asset file (no Dart code) and change appears in next build
- [ ] All pre-existing widget tests pass against asset-loaded content
- [ ] Build-time validation: drift between enum values and asset keys causes build to fail
- [ ] `flutter analyze` -> 0 issues
- [ ] `flutter test` -> all green

**Risk**: Medium. ADR decisions affect implementation; if asset format choice is wrong, Phase 2/3 cost balloons. Mitigation: ADR Phase 1 ships first as its own commit; if Harold redirects format choice, only ADR needs revising.

**Out of scope**: Localization runtime switching, rich content (images/embedded links), runtime asset fetching.

---

## Architecture Impact (Phase 3.6.1)

| Item | Architecture impact | Required updates |
|------|---------------------|-------------------|
| F87 | None (or `AppBarWithExit` widget extended) | None unless shared-component fix |
| BUG-S37-1 | Possibly ADR-0035 update if root cause = mutex architecture | ADR-0035 conditional |
| F6c Phase 2 | None new (DB v4 schema already shipped Sprint 37) | None |
| F88 | New `_batchGetMessages` helper inside Gmail adapter; no new components | F61 backlog (architecture refresh) gets +1 method |
| F86 | New cross-provider subscription pattern (EmailScanProvider listening to RuleSetProvider) | F61 backlog: document subscription pattern |
| F84 | New `SelectableScrollableList` widget (if extracted) | F61 backlog: new widget in UI catalog |
| F82 | None (UI-only change to existing screen) | None |
| F85 | **MAJOR**: new ADR (0036), new asset-loading subsystem, new build-time validation | ADR-0036 shipped this sprint; CLAUDE.md link added; ARCHITECTURE.md updated at Phase 7 |

**Net**: F85 is the only item that triggers an architecture deliverable IN this sprint (ADR-0036). Others either trigger no architecture work or feed the existing F61 (Architecture documentation refresh) HOLD backlog item.

---

## Test Plan

**Estimated new tests**: 22-32 across all tasks
- Task 1 (F87): 1-2 widget tests
- Task 2 (BUG-S37-1): 2-3 unit/integration tests
- Task 3 (F6c Phase 2): 5-8 unit tests + manual Gmail verification
- Task 4 (F88): 2-3 unit tests with mocked multipart + manual Gmail verification
- Task 5 (F86): 4-7 widget tests
- Task 6 (F84): 3-5 widget tests with keyboard events
- Task 7 (F82): 3-5 widget/integration tests
- Task 8 (F85): test strategy is per-ADR; expect 2-3 new asset-loader tests + existing Help/Settings widget tests refactored to read from assets

**Starting test count**: 1408 passing (Sprint 37 ship). Target Sprint 38 end: 1430-1440 passing.

**Manual testing (Phase 5.3)**: Required for F6c Phase 2 (Gmail account), F88 (Gmail account), F87 (visual), F82 (UX), F86 (multi-screen flow), F84 (keyboard gestures), F85 (Help screen + Settings tabs visual parity).

**WinWright runs (per `feedback_winwright_policy.md` memory)**: Conditional per script. Manage Rules + Manage Safe Senders scripts must run after F84. Help screen scripts must run after F85. Scan History + Scan Results scripts must run after F87 + F82.

---

## Standing Approval Inventory (Phase 3.7)

Per CLAUDE.md `Development Philosophy` item 7 and `docs/SPRINT_EXECUTION_WORKFLOW.md` Phase 3.7, approval of this plan covers Phases 4-7:

**Pre-approved (do not re-ask)**:
- All Task 1-8 implementation decisions needed to meet acceptance criteria
- Refactor vs extend choices on F87 component-level fix
- BUG-S37-1 root-cause-driven fix approach (mutex tweak vs architectural change)
- Method signature changes as needed for F6c Phase 2, F86, F84
- Widget structure / state management for F84, F82
- ADR-0036 format choice for F85 Phase 1
- Commit / push / PR-update on the sprint branch through Phase 7
- Phase 4 -> 5 -> 6 -> 7 advance without re-asking
- Code style fixes during implementation
- Adding tests beyond minimum acceptance criteria

**Requires explicit user input**:
- F82 design choice between Options A/B/C (Phase 4 sub-step within Task 7)
- Phase 7 retrospective feedback (mandatory)

**Stopping criteria** (per `docs/SPRINT_STOPPING_CRITERIA.md` 1-9): standard list; will stop and report rather than improvise around any of those.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| F84 from-scratch implementation underestimated | Medium | High (could blow 5-7h estimate to 10h+) | Ship Sub-task A first; B/C as time permits; defer remainder to Sprint 39 if needed |
| F85 ADR format decision wrong | Low-Medium | Medium (Phase 2/3 rework) | ADR ships first as its own commit; Harold review before Phase 2 begins |
| BUG-S37-1 root cause requires architectural change | Medium | Medium (could 2x the estimate) | Time-box investigation at 1h; if architectural change needed, document and decide whether to ship or defer |
| F82 Option C (two-tab) selected by Harold | Low | Medium (most-work option) | Recommend Option A in design phase unless Harold has strong reason for B/C |
| F88 multipart parsing edge cases | Medium | Low | Per-chunk fallback to individual `messages.get` matches `_batchModifyLabels` precedent |
| Mid-sprint scope addition (Sprint 37 had TLD list request) | Medium | Variable | Handle inline if quick; defer to Sprint 39 if not |
| F6c Phase 2 `expired` result edge case | Low | Medium | Test with mocked expired response; manual Gmail testing in Phase 5.3 |

---

## Approval Request

Harold, please confirm Phase 3 plan approval. Per Standing Approval Inventory above, your "approved" reply covers Phases 4-7 execution without further per-task approval.

**Expected reply formats**:
- "Approved" / "Go" / "Looks good" -> proceed
- "Approved with changes: X" -> note X, adjust, proceed
- "Hold on Y" -> revise plan, re-present

If approved, I will start Task 1 (F87) immediately and proceed through Tasks 2-8 in execution order without further check-ins (except for F82 design-variant selection in Task 7).
