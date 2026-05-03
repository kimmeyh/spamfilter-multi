# Sprint 37 Summary

**Dates**: April 27 - May 1, 2026
**Branch**: `feature/20260427_Sprint_37`
**PR**: [#249](https://github.com/kimmeyh/spamfilter-multi/pull/249) (against `develop`)
**Retrospective**: [docs/sprints/SPRINT_37_RETROSPECTIVE.md](SPRINT_37_RETROSPECTIVE.md)
**Plan**: [docs/sprints/SPRINT_37_PLAN.md](SPRINT_37_PLAN.md)

## Sprint Objective

Three planned tasks plus retrospective improvements:
1. BUG-S36-1 (Issue #246): Manual rule semantic subsumption pre-insert check
2. F6 (Issue #247): Gmail scan-path performance optimization (retargeted from "build batch ops" already shipped Sprint 25)
3. F52 Phase 1 (Issue #248): Windows multi-variant install (dev/prod side-by-side)
4. F52 Phase 2 (Issue #248): Android dev/prod/store flavors -- DEFERRED to Sprint 38 per Stopping Criterion 2 (external dependency)

## Tasks Completed

| Task | Issue | Estimate | Actual | Status |
|---|---|---|---|---|
| BUG-S36-1: Manual rule semantic subsumption | #246 | 3-5h | ~1.5h | [OK] Shipped |
| F6a: Parallel Gmail messages.get fetch | #247 | (within F6 10-12h) | ~0.5h | [OK] Shipped |
| F6b: Server-side label exclusion | #247 | (within F6 10-12h) | ~1h | [OK] Shipped |
| F6c: Gmail historyId adapter + DB v4 migration | #247 | (within F6 10-12h) | ~1.5h | [OK] Adapter shipped; provider wiring tracked in #250 |
| F52 Phase 1: Windows distinct .exe + dirs | #248 | 4-6h | ~1h | [OK] Shipped |
| F52 Phase 2: Android dev/prod/store flavors | #248 | 6-8h | 0h | [DEFERRED] Sprint 38 (Firebase Console + GCP setup prereq) |
| Phase 7 retrospective IMPs (1, 2, 6, 7, 8, 9, 11) | -- | -- | ~2h | [OK] Applied as additional commits on the sprint branch |

## Deliverables

- **Code (mobile-app/lib/...)**:
  - `core/services/manual_rule_duplicate_checker.dart` -- extended for subsumption detection (BUG-S36-1)
  - `adapters/email/gmail_api_adapter.dart` -- parallelized fetches (F6a), label exclusion (F6b), historyId fetch (F6c)
  - `core/storage/database_helper.dart` -- v3 -> v4 migration with `last_history_id` column
  - `ui/screens/rules_management_screen.dart`, `ui/screens/safe_senders_management_screen.dart` -- SelectableText on row title/subtitle (Phase 7 Imp-1)
  - `ui/screens/help_screen.dart` -- new "Other ways to reduce junk email/mail/texts/phone calls" section (Phase 7 Imp-2)
- **Build / scripts**:
  - `mobile-app/scripts/build-windows.ps1` -- multi-variant copy (`dist/dev/`, `dist/prod/`), kill-stale-Dart-VMs, direct-launch (no `flutter run` reattach)
  - `mobile-app/windows/runner/CMakeLists.txt` -- `target_compile_definitions` baking `SPAMFILTER_APP_ENV` into the .exe at compile time (fixes store/MSIX window title)
- **Docs**:
  - `docs/SPRINT_EXECUTION_WORKFLOW.md` -- new Phase 3.2.2.2 re-estimate sub-step (Imp-7); Phase 6.4 Copilot review marked conditional (Imp-6)
  - `docs/ALL_SPRINTS_MASTER_PLAN.md` -- F52 Phase 2 Sprint 38 carry-in row (Imp-8); 5 new backlog items (F82, F83, BUG-S37-1, BUG-S37-2, F61 extension)
  - `docs/adr/0035-...` -- "Sprint 37 Update" section refreshed with `dist/` paths, kill-stale-processes fix, direct-launch fix
- **GitHub**:
  - Issue #250 created: "F6c Phase 2: Wire EmailScanProvider to use Gmail historyId incremental scans" (Sprint 38 carry-in, sub-issue under #247)
  - Issue #248 deferral comment posted with the four Firebase / GCP prerequisites
- **Memory**:
  - `project_f52_phase2_blockers.md` -- Sprint 38 carry-in context for F52 Phase 2

## Tests + Quality

- `flutter test`: **1408 passing / 28 skipped / ~1 transient failure** (under investigation -- see retrospective Phase 5.3 notes)
- `flutter analyze`: **0 issues**
- New tests this sprint: 29 in main scope (BUG-S36-1 14, F6b 8, F6c 5+2) + 3 from Help screen widget tests = 32 total
- Manual testing (Phase 5.3): BUG-S36-1 [OK], F6a/F6b [OK], F52 Phase 1 [OK] dev+prod variants coexist on disk and run simultaneously

## Key Decisions

- **F6 retargeting (Phase 2 dependency check)**: original master-plan F6 entry was "build batch ops" but Sprint 25 already shipped that. Phase 2 retargeted to scan-path optimization (parallelize fetches, label-based pre-filter, historyId incremental). Saved ~6h of wasted re-implementation.
- **F52 Phase 2 deferral**: stopped at Stopping Criterion 2 rather than producing broken Android builds. Adding `productFlavors` with `applicationIdSuffix` requires Firebase Console SHA-1 registration + GCP OAuth client IDs for each variant BEFORE the code can produce a runnable build. Issue #248 stays open with the four prereqs documented.
- **F6c provider wiring staged separately**: adapter capability is independently testable; provider integration tracked as Sprint 38 carry-in (#250) so the F6c adapter could ship cleanly this sprint.
- **F52 Phase 1 architectural fixes mid-sprint**: Phase 5.3 testing surfaced (a) variants under `build/` get wiped by `flutter clean`; (b) leftover Dart VMs hold file locks; (c) `flutter run` reattaches and contaminates next env build's AOT. All three corrected during Sprint 37 (variants moved to `dist/`, stale-process termination, direct-launch).

## Lessons Learned

- **Re-estimate after Phase 2 dependency findings**: original effort estimates over-projected by 2-4x because they assumed scaffolding (Sprint 36 BUG-S35-1 infrastructure, Sprint 25 batch ops, ADR-0035 dev/prod scaffolding) was missing. Phase 2 dependency check correctly caught one case (F6 retargeting) but the other two estimates were not refreshed. Sprint 37 retrospective Imp-7 codified Phase 3.2.2.2 to fix this going forward.
- **External-dependency stopping criterion works as intended**: F52 Phase 2 stop saved ~6-8h of producing Android builds that would silently fail at OAuth time. The deferral comment + memory note + carry-in row in master plan ensure Sprint 38 picks this up without rediscovery cost.
- **Compile-time vs runtime env discrimination**: Phase 5.3 testing surfaced that `windows/runner/main.cpp` reading `GetCommandLineW()` for `APP_ENV=prod` works for `flutter run --dart-define` but FAILS for direct-launch and for Microsoft Store MSIX. Baking the env into the .exe via CMake `target_compile_definitions` is the correct architecture for store builds.
- **Copilot review unavailable across 3 sprints (35/36/37)**: SPRINT_EXECUTION_WORKFLOW.md previously framed Copilot review as mandatory, returning 422 every sprint. Sprint 37 Imp-6 made the step conditional.

## Process Improvements Applied This Sprint

7 of 12 retrospective improvements were applied as additional commits on the sprint branch (Imp-1, 2, 6, 7, 8, 9, 11). 5 were added to backlog (Imp-3 F82, Imp-4 F83, Imp-5 BUG-S37-2, Imp-10 F61 extension, Imp-12 BUG-S37-1).

The 7-Step Retrospective Protocol (Phase 7.3-7.7) ran cleanly: Step 1 prompt sent, Step 2 Claude draft generated in parallel, Step 3 Harold's verbatim feedback recorded ("Very Good" across 11 of 14 categories, with concrete suggestions in Categories 1, 13, 14), Step 4 combined retrospective displayed in chat, Step 5 12 improvement proposals presented, Step 6 Harold issued per-proposal apply-now / backlog decisions, Step 7 approved improvements applied + backlog items added to ALL_SPRINTS_MASTER_PLAN.md.

## Links

- [PR #249](https://github.com/kimmeyh/spamfilter-multi/pull/249)
- [Issue #246 BUG-S36-1](https://github.com/kimmeyh/spamfilter-multi/issues/246)
- [Issue #247 F6](https://github.com/kimmeyh/spamfilter-multi/issues/247)
- [Issue #248 F52](https://github.com/kimmeyh/spamfilter-multi/issues/248)
- [Issue #250 F6c provider wiring (Sprint 38 carry-in)](https://github.com/kimmeyh/spamfilter-multi/issues/250)
