# Coding Velocity Tracker

**Purpose**: Record ACTUAL wall-clock coding time per task/step so future sprint estimates are grounded in history, not anchored guesses. Established Sprint 39 (2026-05-25) after Harold flagged that hour-based estimates ran ~10x too high (actuals ~10% of estimate; no single task had exceeded ~1h, yet every estimate used a 1-hour floor).

## Rules (MANDATORY for all future estimating)

1. **Estimate in MINUTES, not hours.** No 1-hour floor. A 1-line UI move is ~5-15 min, not "1h".
2. **Base every estimate on the historical actuals table below**, matched by step-type. If no matching history exists, estimate conservatively in minutes and flag it as `[no-history]`.
3. **Record the actual immediately on task completion** -- append a row to the Actuals Log. Do not batch at sprint end (memory decays).
4. **Wall clock = elapsed coding time** from starting the task to tests-green/analyze-clean. Excludes time waiting on Harold (manual testing, decisions) and excludes build/launch time.
5. **Recompute the Estimate Table each sprint retro** (Phase 7) from the accumulated Actuals Log: per step-type, use the median of recorded actuals as the next estimate, and note the range.

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

**Seeded 2026-05-25 with NO historical actuals yet** -- these are first-pass minute-based guesses to replace the old hour anchors. They will be replaced by medians from the Actuals Log after Sprint 39. All marked `[no-history]` until then.

| Step-type | Estimate (min) | Basis |
|-----------|----------------|-------|
| UI-MOVE | 10-20 | [no-history] |
| UI-NEW | 30-60 | [no-history] |
| UI-GESTURE | 40-75 | [no-history] |
| TEST-UNIT | 15-30 | [no-history] |
| TEST-WIDGET | 20-40 | [no-history] |
| SVC-NEW | 30-50 | [no-history] |
| SVC-EDIT | 20-40 | [no-history] |
| DB-MIGRATE | 25-45 | [no-history] |
| IMAP | 40-70 | [no-history] |
| NATIVE-WIN | 30-90 | [no-history] (high variance; native debugging) |
| CONTENT | 20-40 | [no-history] |
| HOOK | 15-30 | [no-history] |
| DATA | 30-60 | [no-history] |
| DOCS | 15-40 | [no-history] |

## Actuals Log

Append one row per completed task. `Est` = pre-task estimate (min). `Actual` = recorded wall-clock (min). Keep newest at top.

| Date | Sprint | Task | Step-type(s) | Est (min) | Actual (min) | Notes |
|------|--------|------|--------------|-----------|--------------|-------|
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

- After each task: append actual -> the gap (Est vs Actual) is visible immediately.
- At each sprint retro (Phase 7): recompute the Estimate Table medians from the log; update the `Basis` column from `[no-history]` to `median of N samples (range X-Y)`.
- Cross-reference: Sprint retro Category 3 (Effort Accuracy) reads from this file; ALL_SPRINTS_MASTER_PLAN.md item estimates should cite step-types so they map to this table.
