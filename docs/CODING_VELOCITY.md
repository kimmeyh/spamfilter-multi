# Coding Velocity Tracker

**Purpose**: Record ACTUAL development time per Item so future estimates are grounded in history, not anchored guesses. Established Sprint 39 (2026-05-25) after Harold flagged that hour-based estimates ran ~10x too high. Extended Sprint 41 (2026-06-13) to track TWO metrics (effort vs. wall-clock) and to GUARANTEE every Item is covered.

## The Two Metrics (Sprint 41, Harold's definition)

Every Item carries **two estimates and two actuals**, all in **minutes**:

- **Effort** = the sum of every sub-agent's individual elapsed run time. "How much development happened."
- **Wall-clock** = (completion timestamp of the LAST sub-agent to finish) minus T_start. "How long Harold was away." Always <= Effort when sub-agents run in parallel; the gap IS the parallelism benefit.
- **T_start** = sprint-approval time (Phase 3.7) for sprint tasks; work-start time for mid-sprint / between-sprint Items.
- **Measurement method (no stopwatch needed)**: log a clock reading at T_start; log a clock reading when the last sub-agent reports complete (sort sub-agent completion times, take the max) = T_end. Wall-clock = T_end - T_start. Effort = sum of per-agent durations.
- Both metrics EXCLUDE: time waiting on Harold (decisions, manual testing), and build/launch time.

### The number Harold cares about: "when can I come back?"

= the **wall-clock sum of every Item scheduled before the Manual Testing handoff (Phase 5.3)**, accounting for parallel sub-agent execution (critical path, not effort sum). Give Harold ONE window at sprint approval (e.g. "~20-35 min"); refine to a single number when execution starts; flag immediately if it slips.

## Rules (MANDATORY for all future estimating)

1. **Estimate in MINUTES, not hours.** No 1-hour floor. (Calibration note, Sprint 41: 400 HOURS is large; 400 MINUTES is small. A multi-surface feature is tens of minutes, not hundreds.)
2. **Base every estimate on the Estimate Table below**, matched by step-type. If no matching history exists, estimate conservatively and flag `[no-history]`.
3. **Record both actuals immediately on Item completion** -- append a row to the Actuals Log. Do not batch at sprint end (memory decays).
4. **COVERAGE GUARANTEE**: EVERY Item that gets implemented gets a row -- sprint tasks AND mid-sprint scope from testing feedback AND retro IMPs AND between-sprint work (e.g. issue cleanup, bug reports, tooling fixes). The moment an Item is picked up, it gets a Coverage Ledger row. No Item is ever missed.
5. **Recompute the Estimate Table each sprint retro** (Phase 7) from the accumulated Actuals Log: per step-type, median of recorded Act-Effort = next estimate; note the range and sample count.
6. **Phase 7 EXIT GATE**: every Item touched this sprint has a Coverage Ledger row with both estimates and both actuals, OR the retrospective is INCOMPLETE. Enforced like the 14-category rule.
7. **Update the Accuracy Trend table each retro** so the estimate-vs-actual error ratio is visible sprint-over-sprint (the whole point: estimates must get more accurate over time).

## Step-Type Taxonomy

Classify each task by its dominant step-type so estimates aggregate meaningfully:

| Code | Step-type | Examples |
|------|-----------|----------|
| UI-MOVE | Move/relocate existing widget, add icon | S38-CI-2, F87 |
| UI-NEW | New screen/dialog/widget from scratch | F89 badge, F35 edit screen |
| UI-GESTURE | Keyboard/pointer interaction logic | S38-CI-3 selection |
| TEST-UNIT | Add unit tests to existing code | F92, S38-CI-6 |
| TEST-WIDGET | Add widget tests | F78 |
| SVC-NEW | New service/parser class | F89 auth parser |
| SVC-EDIT | Modify existing service logic | S38-CI-4 cursor cap |
| DB-MIGRATE | Schema migration + column plumbing | F91/F89 DB v6 |
| IMAP | IMAP protocol work (SEARCH/FETCH/MOVE) | F91 dedup |
| NATIVE-WIN | C++ runner / window_manager | S38-CI-1 X-close |
| CONTENT | Markdown/asset authoring (ADR-0038) | F74 FAQ |
| HOOK | .claude/hooks / harness tooling | F77, F93 |
| DATA | Bundled rules.yaml / DB seed data | BUG-S37-2 |
| DOCS | Plan/retro/changelog/ADR prose | sprint docs |

## Estimate Table (current best estimates, in minutes)

**Recomputed 2026-06-13 (Sprint 41) from the Sprint 39+40 Actuals Log** -- replaces the 2026-05-25 `[no-history]` seed, which ran ~6x high (median error-ratio ~0.15 across Sprint 39). Effort and wall-clock are equal here because almost every recorded Item so far ran as a single agent (solo Item -> Effort == Wall-clock). Per-type samples are still thin (n=1-3); precision firms up over Sprint 41+. The DIRECTION (~6x lower than the old hour-anchored table) is solid.

| Step-type | Est-Effort (min) | Basis |
|-----------|------------------|-------|
| UI-MOVE | 3-6 | median 3, n=1 (S38-CI-2) |
| UI-NEW | 30-40 | median 35, n=3 (F25/F35/F37) -- the one type that was ~right |
| UI-GESTURE | 7-15 | median 7, n=1 (S38-CI-3) |
| TEST-UNIT | 4-10 | median 4, n=1 (F92) |
| TEST-WIDGET | 20-25 | median 22, n=2 (F78/S38-CI-6) -- harness setup is the real cost |
| SVC-NEW | 5-18 | n=1 (F89 bundle) |
| SVC-EDIT | 5-18 | n=2 (S38-CI-4 ~5, mixed) |
| DB-MIGRATE | 13-20 | median 13, n=1 (F91) |
| IMAP | 13-40 | bundled w/ SVC (F91/S38-CI-4) |
| NATIVE-WIN | 10-15 | median 10, n=3 incl retries (S38-CI-1) -- high variance |
| CONTENT | 5-18 | median ~11, n=2 (F74 ~5 / F75 ~18) |
| HOOK | 5-8 | median 6, n=3 (F77/F93/F79-tooling) |
| DATA | 15-19 | median 17, n=2 (BUG-S37-2) |
| DOCS | 15-20 | n=1 (S38-CI-7 prep ~18) |

## Coverage Ledger (no Item missed)

Every Item that is implemented gets ONE row here the moment it is picked up -- sprint tasks, mid-sprint scope (testing feedback / retro IMPs), and between-sprint work. This is the master per-Item table (Harold's "Velocity log only" choice -- single source of truth). The Actuals Log below holds the detailed per-step notes; this ledger is the audit that NOTHING slipped.

`Status`: PLANNED -> IN-PROGRESS -> DONE. An Item is not "done" for retro purposes until both actuals are filled.

| Item | Sprint | Status | Est-Effort | Est-Wall | Act-Effort | Act-Wall | Notes |
|------|--------|--------|-----------|----------|-----------|----------|-------|
| BETWEEN-S40/41: MCP npx Windows fix + Anthropic bug report | 40->41 | DONE | [no-est, reactive] | -- | ~8 | ~8 | Diagnosed `spawn EINVAL` on `.cmd` shims; fixed 4 plugin `.mcp.json` (later reverted by user); wrote ANTHROPIC_BUG_REPORT_npx_mcp_windows.md. Between-sprint Item logged per coverage guarantee. |
| BETWEEN-S40/41: Completed-issue cleanup (16 issues closed) | 40->41 | DONE | [no-est, reactive] | -- | ~12 | ~12 | Verified 16 open issues against CHANGELOG + Sprint 36-40 summaries; closed with explanatory comments. Between-sprint Item logged per coverage guarantee. |
| F97: WinWright F56 create+delete scripts re-port | 41 | DONE (pending sweep) | 6-10 | 6-10 | ~25 | (parallel) | Est 2.5-4x LOW. Agent confirmed accepted TLD input by source (radio-select-before-type was the S40 blocker, not the input string); authored 2 self-cleaning scripts w/ `xyz`. Scripts authored, JSON valid; live sweep pending manual testing. |
| F76: WinWright visual regression testing | 41 | DONE (baselines pending) | 8-14 | 8-14 | ~38 | (serial after F97) | Est 2.7-4.75x LOW. Chose layout-bounds (not pixel-diff -- AA noise); new winwright-visual-check.ps1 + runner -VisualCheck param; self-test PASSED (exit 0, 5 steps). Real baselines pending capture in manual testing. |
| F83 Phase 1: Per-account bg-scan research + ADR | 41 | DONE | 10-16 | 10-16 | ~22 | (parallel) | Est 1.4-2.2x LOW. ADR-0039 (Proposed), 24 change-sites inventoried, 3 locked decisions baked in. Surfaced latent Android key-mismatch bug + orphaned bg_scan_schedule table (both -> F98). Awaiting Chief-Architect ADR approval. |
| --- BATCH WALL-CLOCK (Sprint 41 Phase 4) | 41 | DONE | -- | 24-40 | Effort sum: ~85 | Wall: ~16.5 | T_start 2026-06-13 21:47 EDT, T_end 22:03:30 (last agent). 3 agents (F83+F97 parallel, F76 serial). Effort 85m vs Wall 16.5m = 5.1x parallelism benefit. Est-Effort total 24-40m ran ~2-3.5x LOW -- estimates now UNDER for the first time (prior sprints were over); flag for retro Category 3. |

## Accuracy Trend (estimates must improve sprint-over-sprint)

One row per sprint. `Median Error-ratio` = median(Act-Effort / Est-Effort); 1.0 = perfect, <1 = over-estimated, >1 = under-estimated. `MAPE` = mean absolute percentage error. Goal: error-ratio -> 1.0 and MAPE shrinks each sprint.

| Sprint | Items (n) | Median Est-Effort | Median Act-Effort | Median Error-ratio | MAPE | Notes |
|--------|-----------|-------------------|-------------------|--------------------|------|-------|
| 39 | 11 | ~40 (old seed) | ~6 | ~0.15 | ~85% | Baseline. Old hour-anchored seed ran ~6-7x high. Confirmed Harold's "10x too large". |
| 40 | 7 | ~45 (seed, partial) | ~28 | ~0.6 | ~45% | UI-NEW estimates (F25/F35/F37) were close; CONTENT/TEST near. Improvement from S39 as seed got partial correction mid-table. |
| 41 | TBD | -- | -- | -- | -- | First sprint estimated entirely from the recomputed (S39+40) table. Target: error-ratio 0.7-1.3, MAPE <30%. |

## Actuals Log

Append one row per completed task. `Est` = pre-task estimate (min). `Actual` = recorded wall-clock (min). Keep newest at top.

| Date | Sprint | Task | Step-type(s) | Est (min) | Actual (min) | Notes |
|------|--------|------|--------------|-----------|--------------|-------|
| 2026-05-30 | 40 | S38-CI-7 PREP (4 briefs + productive-notes + rubric) | DOCS | 90-150 (full eval) | ~18 (prep only) | EVAL-RUN portion deferred to external 4.6 session: in-session Agent tool model enum is sonnet/opus/haiku with no version pin, so 4.7-subagent dispatch cannot produce a faithful 4.6-vs-4.7 head-to-head. Surfaced as Class-3 ambiguity per CLAUDE.md; option (c) prep-only chosen to preserve experiment integrity. 6 artifacts under docs/sprints/s38-ci-7-eval-briefs/: README, 4 verbatim briefs, productive-run notes w/ scoring rubric template. Full ~90-150 min estimate stands for the eventual 4.6 re-runs + scoring. |
| 2026-05-30 | 40 | F79 WinWright harness + DB-snapshot guard | HOOK/tooling+SVC-EDIT+DOCS | 45-75 | ~35 | Part 1: -SnapshotDb/-DryRun/-TestSnapshotOnly params; runner 100->248 lines (preserves -TestName + screen-reader + doctor). Part 2: new winwright-db-snapshot.ps1 (341 lines) snapshots rules/safe_senders/settings via sqlite3 (uses Android SDK's sqlite3.exe, no new dep); -SelfTest synthetic-leak mode injects bogus row, verifies drift detection, cleans up. Part 3: TESTING_STRATEGY.md + winwright/README updated; policy memory already correct. Synthetic-leak test PASSED. Physical sweep NOT run (sandbox limit). Within estimate. |
| 2026-05-30 | 40 | F37 Folder selectors two-level + separator [EVAL SUBJECT] | UI-NEW+SVC-EDIT | 40-60 | ~35 | Part A: ExpansionTile-based depth-2 tree (groupFoldersForTree pure fn); parent rows expand-only (no checkbox -- IMAP \NoSelect rationale documented). Part B: reorderForSingleSelect places INBOX/TRASH first then alpha. Part C: FolderInfo.hierarchyDelimiter added (defaulted '/' backward-compat); IMAP uses mailbox.pathSeparator from enough_mail (live LIST response), Gmail/Outlook/Mock hardcoded '/'. 19 new tests. Suite 1612 -> 1631 pass / 28 skip / 0 fail (+19). Analyze clean. Within estimate. |
| 2026-05-30 | 40 | F35 Rule editing UI [EVAL SUBJECT] | UI-NEW | 30-50 | ~30 | New RuleEditScreen (mirrors ManualRuleCreateScreen pattern w/ dual-mode plaintext/direct-regex); Edit button added to _showRuleDetails dialog next to F25 Test button; RuleSetProvider.updateRule rethrow fix (BUG-S39-2 discipline mirrored); 25 new tests (23 widget + 2 unit). Suite 1588 -> 1612 pass / 28 skip / 0 fail (+24). Analyze clean. Reused F25's ManualRulePatternGenerator. No shared widgets needed extraction. At mid-estimate. |
| 2026-05-30 | 40 | F25 Rule Testing UI 3 sub-features [EVAL SUBJECT] | UI-NEW+SVC-EDIT | 30-45 | ~38 | (1) demo fallback in _loadSampleEmails (+ amber banner); (2) plaintext->regex checkbox + generated-regex echo (extracted ManualRulePatternGenerator public utility, 5 static methods); (3) "Test" button in _showRuleDetails dialog -> RuleTestScreen w/ initialPattern+conditionType. Suite 1541 -> 1588 pass / 28 skip / 0 fail (+47). Also fixed F75 regression I missed (help_screen_test count 21->22). Analyze clean. At top of estimate -- 3 sub-features + extraction + 49 tests. |
| 2026-05-30 | 40 | F75 Help walkthrough | CONTENT | 15-25 | ~18 | 965-word walkthrough.md (6 steps + recommendation hierarchy); enum + manifest + _section + switch + pubspec asset + content_loader_test mapping; 4/4 content_loader tests pass; analyze clean. Mirrored F74 exactly (F74 was 5 min for 8 short Q&A; F75 is larger -- 6 narrative steps + 965 words). Within estimate. |
| 2026-05-30 | 40 | F78 ManualRuleCreateScreen widget tests | TEST-WIDGET | 25-40 | ~25 | 11 testWidgets cases added (4 coverage areas); file 185 -> 364 lines; suite 1530 -> 1541 pass / 28 skip / 0 fail; analyze clean. Mirrored rule_quick_add_screen_test.dart pattern. Note: pattern-preview test asserts Form/ListView structure rather than text-update on type -- thinner than plan called for; flag for Phase 5.2 review. At top end of estimate (TEST-WIDGET median was 20 min n=1; harness already established). |
| 2026-05-25 | 39 | S38-CI-1 X-close FIX ROUND 3 | NATIVE-WIN | -- | ~10 | Rounds 1+2 crashed. ROOT CAUSE (agent traced plugin source): window_manager 0.3.9 destroy()=PostQuitMessage only (no DestroyWindow) + setPreventClose swallowed runner's WM_CLOSE -> engine torn down in stack-unwind after CoUninitialize w/ orphaned tray icon. FIX: remove setPreventClose+addListener entirely; let native WM_CLOSE->WM_DESTROY->SetQuitOnClose handle it (why every other app's X works). Retain tray service globally; dispose tray in Exit path. Pending re-test. |
| 2026-05-25 | 39 | S38-CI-1 X-close FIX ROUND 2 | NATIVE-WIN | -- | ~12 | Round 1 crashed (exit(0) after destroy raced teardown -> "stopped working" loop). Verified window_manager docs via Context7; fix = destroy() only, no exit(0). STILL CRASHED -- diagnosis incomplete. |
| 2026-05-25 | 39 | BUG-S37-2 typo removal (corrective) | DATA | -- | ~15 | Removed 6 typo TLDs (.c .giw .nwm .xd .sweepss .qzz.io) from rules.yaml via script + v6 cleanup migration for existing installs + test. .sweeps/.ca retained. |
| 2026-05-25 | 39 | BUG-S37-2 TLD audit + ccTLD gap-fill | DATA | 30-60 | ~19 | 194 ccTLDs added (premise correction: NOT almost-all-present). 19/19 tests. |
| 2026-05-25 | 39 | S38-CI-4 cursor cap | SVC-EDIT+IMAP | 40-70 | ~5 | firstUidSince + per-scan cache + clamp; 8 tests. Est 8-14x high. |
| 2026-05-25 | 39 | S38-CI-1 X-close fix | NATIVE-WIN | 30-90 | ~3 | Root cause = setPreventClose w/o onWindowClose listener; Dart-only fix. Pending Phase 5.3 manual verify. |
| 2026-05-25 | 39 | F89 auth-failure warnings | SVC-NEW+UI-NEW+DB | 90-150 | ~18 | parser+badge+dialog+v6 column+26 tests. inline email-detail badges deferred (no persisted auth headers). Est 5-8x high. |
| 2026-05-25 | 39 | F91 AOL dedup | DB-MIGRATE+IMAP | 60-110 | ~13 | DB v6 opened; Message-ID capture + post-move dedup; 18 tests. Est 4-8x high. |
| 2026-05-25 | 39 | S38-CI-3 selection gestures | UI-GESTURE | 40-75 | ~7 | New ListSelectionController mixin; 5 tests. Est 5-10x high. |
| 2026-05-25 | 39 | F74 Help FAQ | CONTENT | 20-40 | ~5 | 8-Q faq.md asset + manifest; caused content_loader_test regression -> fixed same session. |
| 2026-05-25 | 39 | F92 LiveScanLogger tests | TEST-UNIT | 15-30 | ~4 | 10 tests green; agent duration ~3.6 min. Est was 4-8x high. |
| 2026-05-25 | 39 | S38-CI-6 reload widget test | TEST-WIDGET | 20-40 | ~20 | 1 test green; sqflite_ffi hang worked around (runAsync). At low end of est -- widget-test harness setup is the real cost. |
| 2026-05-25 | 39 | S38-CI-2 info-card relocate | UI-MOVE | 10-20 | ~3 | Shared widget extracted; analyze clean. Est 3-7x high. |
| 2026-05-25 | 39 | F77 hookify proceed-rule | HOOK | 15-25 | ~5 | Routed through existing hook (no separate rule); decision doc written. |
| 2026-05-25 | 39 | F93 hook Phase-1 exempt | HOOK | 15-30 | ~6 | 13/13 hook tests pass. Est 3-5x high. |

## How This Improves Over Time

- After each Item: append both actuals -> the gap (Est vs Act, effort AND wall-clock) is visible immediately.
- At each sprint retro (Phase 7): recompute the Estimate Table medians from the Actuals Log; update the `Basis` column sample counts; add the sprint's row to the Accuracy Trend table.
- The Accuracy Trend table is the proof Harold asked for: the median error-ratio should march toward 1.0 and MAPE should shrink each sprint. If it does not, the estimating method needs revision (raise it in retro Category 3).
- Cross-reference: Sprint retro Category 3 (Effort Accuracy) reads from this file; the Phase 7 EXIT GATE (Rule 6) blocks retro completion until every touched Item has a Coverage Ledger row with both actuals.
- ALL_SPRINTS_MASTER_PLAN.md item estimates should cite step-types so they map to the Estimate Table.
