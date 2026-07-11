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
| F64: CI/CD pipeline with GitHub Actions | 46 | DONE | 25-40 | 25-40 | ~30 | ~30 | `.github/workflows/ci.yml`: analyze+test on ubuntu-latest, Windows build-verification on windows-latest, OAuth secrets via GitHub encrypted repo secrets (not yet populated -- documented in CLAUDE.md as a one-time setup step). First CI run surfaced a REAL cross-platform test bug (`powershell_script_generator_test.dart` hardcoded a Windows `\` path separator, silently divergent from the production `path.join()` code on Linux) -- fixed, verified locally, 2nd CI run fully green. Within estimate; the CI-path alternatives analysis (GitHub Actions vs self-hosted vs analyze-only) was done at planning time, not counted against this Item's execution time. |
| F39: Cross-account "No rule" review screen + bulk actions | 46 | DONE | 90-140 | 90-140 | ~130 | ~130 | Scope RESTRUCTURED mid-implementation (Harold clarifying Q): new cross-account aggregation screen (latest scan per account only), not "add multi-select to existing screen". Built in 3 committed steps: (1) extract shared RuleQuickActionService from ResultsDisplayScreen's _addSafeSender/_createBlockRule (9 unit tests, behavior parity verified against 20 existing screen tests); (2) extract PatternNormalization.extractRootDomain (6 unit tests); (3) new NoRuleReviewScreen + entry point + 5 widget tests. +20 net tests (1692->1712). Lost ~25m to the sqflite-FFI widget-test hang before recalling the documented runAsync workaround (results_display_no_rule_reload_test.dart) -- flag for retro: this hang has now bitten 3+ sprints; the workaround should be a reusable test helper, not copy-pasted lore. Top of estimate due to the restructure + hang detour. |
| S46-MT-1: detail popup one item lower (manual-testing feedback) | 46 | DONE | [no-est, reactive] | -- | ~10 | ~10 | Harold item 1: popup covered the next list item; when spaceBelow >= popupHeight + one item-height, drop the popup one email lower so the next item stays clickable. UI-MOVE-class change; existing 14 screen tests green. |
| S46-MT-3: auto-advance speed -- pick-next-first, process-async (manual-testing round 2) | 46 | DONE | [no-est, reactive] | -- | ~20 | ~20 | Harold: advance waited on the full pipeline (incl. IMAP re-process) = seconds of dead time. Restructured to his design: pick next non-covered item FIRST (per-action coveredByAction predicates: same email / exact domain / root domain / subject-contains), unawaited(action()), popup opens immediately. 20 screen tests green. |
| S46-MT-2: "No rule" filter auto-advance popup (manual-testing feedback) | 46 | DONE | [no-est, reactive] | -- | ~25 | ~25 | Harold item 2: with the No-rule filter active, a quick action auto-opens the next remaining item's popup at the same anchor. Captures following-item keys BEFORE the action (rule may wipe multiple items), picks first survivor after re-evaluation; extracted _currentResults() shared resolution; rewired all 7 popup buttons through _quickActionThenAdvance. 20 screen tests green. |
| F33: Body rules cleanup script (DB-only) | 46 | DONE | 55-85 | 55-85 | ~120 | ~120 | Est ~1.5-2x LOW. Group-first classification script over 1109 live DB body rules; dry-run-first then --apply (backs up DB). Scope grew through several Harold clarifying rounds during execution (his approved model this sprint): Option B (convert ALL domain-shaped, not just /-prefixed); G6 removal of truncated/bare no-tld patterns (all anchor forms); 3 hand-decided special cases (phone-number -> format-tolerant regex, 2 removals). Real bug found + fixed during dry-run: escaped hyphens (`\-`) in domain labels broke both G1 conversion and G6 classification (silently dumped ~300 valid domains into "ambiguous"); fixed the label regexes to handle `\-`. Final: 647 converted + 84 reclassified + 375 removed + 3 special, 0 ambiguous, reconciles to 1109. Applied to dev DB (4141->3764 rules); prod cleanup deferred to a separate deliberate --env prod run. 18 unit tests. The clarifying rounds (not coding) drove most of the overage -- classification code itself was quick; nailing the live-data edge cases (hyphens, phone numbers, path fragments) was the real work. |
| BETWEEN-S40/41: MCP npx Windows fix + Anthropic bug report | 40->41 | DONE | [no-est, reactive] | -- | ~8 | ~8 | Diagnosed `spawn EINVAL` on `.cmd` shims; fixed 4 plugin `.mcp.json` (later reverted by user); wrote ANTHROPIC_BUG_REPORT_npx_mcp_windows.md. Between-sprint Item logged per coverage guarantee. |
| BETWEEN-S40/41: Completed-issue cleanup (16 issues closed) | 40->41 | DONE | [no-est, reactive] | -- | ~12 | ~12 | Verified 16 open issues against CHANGELOG + Sprint 36-40 summaries; closed with explanatory comments. Between-sprint Item logged per coverage guarantee. |
| F97: WinWright F56 create+delete scripts re-port | 41 | DONE (pending sweep) | 6-10 | 6-10 | ~25 | (parallel) | Est 2.5-4x LOW. Agent confirmed accepted TLD input by source (radio-select-before-type was the S40 blocker, not the input string); authored 2 self-cleaning scripts w/ `xyz`. Scripts authored, JSON valid; live sweep pending manual testing. |
| F76: WinWright visual regression testing | 41 | DONE (baselines pending) | 8-14 | 8-14 | ~38 | (serial after F97) | Est 2.7-4.75x LOW. Chose layout-bounds (not pixel-diff -- AA noise); new winwright-visual-check.ps1 + runner -VisualCheck param; self-test PASSED (exit 0, 5 steps). Real baselines pending capture in manual testing. |
| F83 Phase 1: Per-account bg-scan research + ADR | 41 | DONE | 10-16 | 10-16 | ~22 | (parallel) | Est 1.4-2.2x LOW. ADR-0039 (Proposed), 24 change-sites inventoried, 3 locked decisions baked in. Surfaced latent Android key-mismatch bug + orphaned bg_scan_schedule table (both -> F98). Awaiting Chief-Architect ADR approval. |
| --- BATCH WALL-CLOCK (Sprint 41 Phase 4) | 41 | DONE | -- | 24-40 | Effort sum: ~85 | Wall: ~16.5 | T_start 2026-06-13 21:47 EDT, T_end 22:03:30 (last agent). 3 agents (F83+F97 parallel, F76 serial). Effort 85m vs Wall 16.5m = 5.1x parallelism benefit. Est-Effort total 24-40m ran ~2-3.5x LOW -- estimates now UNDER for the first time (prior sprints were over); flag for retro Category 3. |
| F97 FIX r1 (manual-testing feedback): F56 save-button selectors | 41 | SUPERSEDED | 3-6 | 3-6 | ~6 | ~6 | Round-1 fix (`Save block rule`->`Save Rule`) was correct but INSUFFICIENT -- sweep round 2 still failed. The save selector was only 1 of 3 bugs. Superseded by FIX r2. |
| F97 FIX r2 (manual-testing feedback round 2): 3 root causes | 41 | DONE (re-run pending) | 8-15 | 8-15 | ~30 (agent) + ~25 (my live inspect) = ~55 | ~30 | Harold's screenshot exposed the real chain. 3 LIVE-VERIFIED root causes: (1) radio select must click `Group[name*='Top-Level Domain']` not the inner `RadioButton` (ww_click on RadioButton no-ops; Group click -> IsSelected=True); (2) input field is mode-dependent: TLD mode = `Edit[name*='Enter TLD']`, Entire-Domain = `Edit[name='Enter email, domain, or URL']`; (3) Save Rule is off-screen at default window size -> `ww_invoke` no-ops on off-screen Flutter buttons -> must `ww_window_state maximize` then `ww_click`. Also test data: `xyz` was already in DB (source_domain='*.xyz') -> switched to `museum`. DB verified clean post-test (rules=4037/safe=578, zero leftover). LESSON: I reasoned from SOURCE twice (duplicate-check, dialog) and was wrong both times; the live UIA tree + Harold's screenshot were the truth. Re-run sweep pending Harold. |
| F97 FIX r3 (manual-testing round 3): ww_click->ww_invoke (FAILED) | 41 | SUPERSEDED | 2-4 | 2-4 | ~10 | ~10 | Changed F56 Save/Delete + F37 picker buttons to ww_invoke. Sweep round 3 STILL failed: Save resolves 0 elements (timing, not click verb); F37 step #5 moved failure forward; Group radio cannot be invoked (no InvokePattern). LESSON (2nd partial-fix-as-done miss this sprint, after r1): changing the click VERB never addressed the dialog-settle ROOT CAUSE. Should have diagnosed before patching. Superseded by the F99 fold decision. |
| TOOLING INVESTIGATION: WinWright CLI bounds + Playwright vs integration_test | 41 | DONE | [no-est, reactive] | -- | ~45 (live CLI probing + web research) | ~45 | Proved standalone WinWright CLI cannot read BoundingRectangle (commands = mcp|serve|run|heal|inspect|doctor; no get_attribute; inspect JSON has no bounds; run rejects ww_get_attribute/ww_assert*). Researched Playwright (drives browser DOM only -- cannot see native Flutter desktop widget tree) -> recommended keep WinWright + add Flutter integration_test as 2nd lane. Outcome: F99 created (pre-MVP). High-value reactive investigation; no estimate (unplanned). |
| F76 RETIRE + F99 create + F56/F37 fold-to-F99 | 41 | DONE | [no-est, reactive] | -- | ~35 (reverts + 3 doc surfaces x 3 commits) | ~35 | Reverted non-working F76 artifacts (deleted winwright-visual-check.ps1 696 lines + -VisualCheck wiring + null baselines); generalized sweep exclusion to {f56,f37}; restored both to as-authored; F99 backlog item authored (absorbs F76+F56+F37); README/CHANGELOG/master-plan updated across 3 commits. Default sweep verified green 6/6, DB drift none, no orphans. 3 Class-2/3 decisions surfaced + approved before acting. |
| TOOLING SIDEBAR: Norton HTTPS-interception git-push fix | 41 | DONE | [no-est, reactive] | -- | ~20 (diagnosis) | ~20 | git push failed "SSL peer certificate not OK". Root cause: Norton-360 LiveUpdate (~23:46) re-asserted TLS interception, presenting a "Norton Web/Mail Shield" cert the openssl git backend rejects. Confirmed via openssl s_client (issuer=Norton). Fix: Harold disabled Norton "Encrypted connections scanning" (verified issuer flipped to Sectigo). Researched current Norton-360 v26.4 UI steps. Unplanned but blocking; logged per coverage guarantee. |
| F99: Flutter integration_test E2E harness | 42 | DONE | 80-120 | 60-90 | ~150 | ~150 | TEST-INFRA. Est ~1.5x LOW on effort. Big hidden cost was DB ISOLATION: the app self-inits real AppPaths and path_provider has no MethodChannel on Windows desktop, so 2 isolation attempts failed (one wrote to dev DB) before the AppPaths.testOverrideBaseDir seam. Then a cross-file singleton-bleed race (database_closed) -> Harold's per-file-process decision. 5 test files (smoke, block-rule + safe-sender lifecycle, folder picker, layout-bounds), all green per-file; runner + 2 test seams (testOverrideBaseDir, debugFoldersOverride) + TESTING_STRATEGY two-harness docs. |
| F98: Per-account background scanning (ADR-0039 impl) | 42 | DONE | 100-160 | 70-110 | ~140 | ~140 | DB-MIGRATE+UI-NEW+NATIVE-WIN+SVC-EDIT+CONTENT. Within estimate (ADR's 24-site inventory made this predictable -- the value of F83 Phase 1). All 23 active sites + migration + 12 unit tests. Design fully locked by ADR + Harold "one task per account" -> no mid-sprint Class-1 stop. |
| BUG-S37-2: bundled TLD data quality | 42 | DONE | 30-45 | 25-35 | ~20 | ~20 | DATA. Est ~1.5-2x HIGH. Audit found the ccTLD list was already 247/248 complete -> Harold 1c (no expansion/allow-list change) + 2a (remove .sho/.sweeps typos only). Just a DB v7 cleanup migration + YAML edit + test update. Smaller than estimated because the "expansion" turned out unnecessary. |
| F98 FIX r1 (manual testing): Test-scan account scoping | 42 | DONE | [no-est, reactive] | -- | ~8 | ~8 | Test Background Scan button called executeBackgroundScan(isTest:true) with NO accountId -> scanned all accounts + shared log. One missed call site (scheduled --account-id path was correct). Pass widget.accountId. |
| F98 FIX r2 (manual testing): DB-lock resilience | 42 | DONE | [no-est, reactive] | -- | ~35 | ~35 | "database is locked (code 5)" on concurrent per-account scans. 3 layers: WAL + busy_timeout=30s (onConfigure); worker _withDbLockRetry (1min x 20, Harold spec); start-jitter (-RandomDelay 14/29/59min Windows every firing; random 1..N initialDelay Android). +2 PS-gen tests. |

## Accuracy Trend (estimates must improve sprint-over-sprint)

One row per sprint. `Median Error-ratio` = median(Act-Effort / Est-Effort); 1.0 = perfect, <1 = over-estimated, >1 = under-estimated. `MAPE` = mean absolute percentage error. Goal: error-ratio -> 1.0 and MAPE shrinks each sprint.

| Sprint | Items (n) | Median Est-Effort | Median Act-Effort | Median Error-ratio | MAPE | Notes |
|--------|-----------|-------------------|-------------------|--------------------|------|-------|
| 39 | 11 | ~40 (old seed) | ~6 | ~0.15 | ~85% | Baseline. Old hour-anchored seed ran ~6-7x high. Confirmed Harold's "10x too large". |
| 40 | 7 | ~45 (seed, partial) | ~28 | ~0.6 | ~45% | UI-NEW estimates (F25/F35/F37) were close; CONTENT/TEST near. Improvement from S39 as seed got partial correction mid-table. |
| 41 | 3 planned (+7 reactive) | ~10 | ~25 | ~2.4 | ~140% | First sprint estimated from the recomputed (S39+40) table -- estimates ran UNDER for the first time (prior sprints ran over). Planned items (F83/F97/F76) each ~2-3.5x LOW on effort. MISSED the 0.7-1.3 target in the OPPOSITE direction. BUT the 7 reactive items (F97 fix rounds, tooling investigation, F76 retire/F99 fold, Norton fix) dominated actual wall-clock and were entirely unestimated -- the real lesson is not "estimates too low" but "this sprint was mostly unplanned discovery/rework, which the estimate model does not capture." See retro Category 3. |
| 42 | 3 planned (+2 reactive fixes) | ~100 | ~140 | ~1.3 | ~45% | BEST accuracy yet. F98 within estimate (ADR-0039's 24-site inventory de-risked it -- the payoff of F83 Phase 1 design-first). F99 ~1.5x low (DB-isolation + per-file-process discovery were hidden costs). BUG-S37-2 ~1.5-2x HIGH (audit found the ccTLD expansion unnecessary). 2 reactive manual-testing fixes (Test-scan scoping; DB-lock resilience). Error-ratio 1.3 sits at the top edge of the 0.7-1.3 target -- the design-first ADR is the biggest accuracy lever. |

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
