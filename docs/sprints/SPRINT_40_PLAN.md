# Sprint 40 Plan: Help Content + Rule/Folder UI + Test Tooling + Model Head-to-Head

**Sprint**: 40
**Date**: 2026-05-26 (Backlog Refinement / Phase 1-3)
**Branch**: `feature/20260525_Sprint_40`
**Status**: EXECUTION COMPLETE (Phase 3.7 approved 2026-06-04). F75/F78/F25/F35/F37/F79 done; S38-CI-7 CANCELLED (Harold, 2026-06-04 -- model eval no longer reasonable with Opus 4.8). F79 WinWright suite re-ported + harness app-lifecycle fix 2026-06-09; full sweep green, zero DB drift. F56 create+delete + manual_scan_flow deferred to F97. Ready for Phase 6.3 PR + Phase 7 retro.
**Type**: Mixed -- Docs/UX (F75), Core Feature UI (F25, F35, F37), Testing (F78), Test tooling (F79), Process/model evaluation (S38-CI-7)
**Estimated Effort (coding)**: ~3.0-5.0h pure coding + ~1.5-2.5h eval orchestration = **~4.5-7.5h total**
**Estimating method**: MINUTE-based per `docs/CODING_VELOCITY.md` (Sprint 39 actuals; hour-based estimates ran 4-14x high). Per-task basis cited inline.

> **Carry-in source**: All 7 items moved off HOLD / carried in at the Sprint 39 Backlog Refinement (2026-05-25). See ALL_SPRINTS_MASTER_PLAN.md "Sprint Assignment" table (Sprint 40 target: F75, F25, F35, F37, F78, F79, S38-CI-7).

---

## Sprint Objective

Ship the first end-to-end Help walkthrough (F75), the deferred rule/folder UI cluster (F25 rule testing, F35 rule editing, F37 folder selectors), close the ManualRuleCreateScreen widget-test gap (F78), build the unattended WinWright sweep harness with DB-drift guard (F79), and run the Opus 4.6-vs-4.7 head-to-head evaluation (S38-CI-7) using the real F25/F35/F37/F78 tasks as eval subjects.

---

## Sprint Scope (7 items, confirmed at 2026-05-26 Backlog Refinement)

F75, F25, F35, F37, F78, F79, S38-CI-7.

> **[SCOPE UPDATE 2026-06-04]** S38-CI-7 eval-RUN was CANCELLED by Harold (active model is now Opus 4.8; the 4.6-vs-4.7 head-to-head is moot). Only the prep artifacts shipped. Delivered scope = F75, F25, F35, F37, F78, F79 + BUG-S40-1 (in-sprint manual-testing find) + S38-CI-7 prep-only.

**Harold decisions (2026-05-26)**:
- **Scope = all 7 candidates** (option 2a). No deferral.
- **S38-CI-7 eval subjects = the real F25/F35/F37/F78 Sprint 40 tasks** (option 1a). The eval rides on planned work; zero throwaway coding; diffs are directly comparable apples-to-apples.

(Sprint 41 target: SEC-11b, F83.)

---

## Re-estimation Note (why these numbers differ ~10x from the master plan)

The master-plan hour estimates (F75 4-6h, F25 6-8h, F35 8-12h, F37 6-8h, F78 3-4h, F79 4-8h) predate the Sprint 39 Effort-Accuracy finding. Sprint 39 recorded 15 actuals; **no coding task exceeded ~20 min** and estimates ran 4-14x high. Per-step-type medians computed from the Sprint 39 Actuals Log:

| Step-type | Sprint 39 median (min) | n | Used here for |
|-----------|------------------------|---|---------------|
| CONTENT | 5 | 1 | F75 |
| UI-NEW | ~18 (in combo) | 1 | F25, F35, F37 |
| UI-GESTURE | 7 | 1 | -- |
| SVC-EDIT | 5 | 1 | F25, F37 |
| TEST-WIDGET | 20 (setup-bound) | 1 | F78 |
| HOOK/tooling | 5-6 | 2 | F79 (no close analogue) |

Where no close historical analogue exists (F79 unattended runner, S38-CI-7 orchestration), the estimate is held CONSERVATIVE and flagged `[no-history]` rather than minimized.

---

## Key Design Decisions

1. **The four UI tasks reuse existing infrastructure.** F25/F35 reuse the Sprint 34 `ManualRuleCreateScreen` regex-generation building blocks (create-only today). F35 adds an edit flow over those blocks; F25 adds three small wirings (Demo-data pre-populate, plaintext->regex on Test, open-existing-rule). This is why their re-estimates are minutes, not hours.

2. **F37 is the highest UI risk.** Part A (two-level collapsible folder tree) is a novel widget from scratch with no historical analogue -- estimated conservatively. Part B (provider-default-first flat lists) is PARTIAL already; per-provider separator detection is small.

3. **F79 is the largest genuine unknown.** PowerShell runner hardening + pre/post dev-DB snapshot diffing has no close Sprint 39 analogue. The HOOK median (~5 min) undersells real tooling work, so F79 is estimated conservatively. F79 builds tooling only -- it does NOT add new WinWright scripts for F25/F35/F37 (those ship with their features) and excludes visual regression (that is F76, not in this sprint).

4. **S38-CI-7 does NOT shrink with the minute-based method.** The per-task coding shrinks, but S38-CI-7 re-runs F25/F35/F37/F78 a SECOND time on Opus 4.6 (separate branches) plus 5-dimension scoring. The orchestration/transcript-capture/scoring overhead is irreducible (~90-150 min) and is additive on top of the eval-subject tasks' own time.

5. **Eval-subject tasks run TWICE.** F25/F35/F37/F78 are first executed on Opus 4.7 (the productive Sprint 40 run that ships to `develop`). S38-CI-7 then re-runs the identical task briefs on Opus 4.6 on throwaway `*-opus46` branches purely to capture the comparison transcript/diff; the 4.6 output is NOT merged.

6. **No CHANGELOG churn during sprint.** CHANGELOG entries added per task in the same commit, per CLAUDE.md changelog policy.

---

## Tasks (execution order)

### Task 1: F78 -- Widget tests for ManualRuleCreateScreen rendering (~25-40 min, Haiku)
**Execution order**: 1 (warm-up; establishes the widget-test harness the rest can lean on; also an eval subject)
**Step-type**: TEST-WIDGET `[basis: TEST-WIDGET median 20 min n=1; harness-setup amortized across 4 areas]`
**Current state (verified 2026-05-25)**: `mobile-app/test/ui/screens/manual_rule_create_screen_test.dart` (185 lines) is unit-only -- no `testWidgets`/`pumpWidget`. All 4 coverage areas NOT DONE.
**Approach**: add `testWidgets` coverage for: radio selection (`RadioListTile<ManualRuleType>` ~L644-660), input-field validation feedback, pattern preview rendering (~L575-585), confirmation dialog (`AlertDialog` ~L566-609). Reuse the Sprint 39 S38-CI-6 `runAsync` sqflite_ffi workaround.
**Acceptance Criteria**:
- [ ] Widget tests cover radio selection, validation feedback, pattern preview, confirmation dialog
- [ ] All new tests green; existing 185-line unit suite still passes
- [ ] `flutter analyze` clean
**Risk**: Low. Test-only; pattern established in Sprint 39.

### Task 2: F75 -- Help walkthrough: end-to-end first-use guide (~15-25 min, Haiku)
**Execution order**: 2 (content authoring; isolated from the UI cluster)
**Step-type**: CONTENT (ADR-0038 asset Markdown) + light Help-screen wiring `[basis: CONTENT median 5 min n=1 (F74); scaled up -- 6 walkthrough steps + recommendation hierarchy vs F74's 8 short Q&A]`
**Approach**: author the walkthrough as a Markdown asset under `mobile-app/assets/content/` + manifest entry (ADR-0038), surfaced on the Help screen. Steps: install -> Demo scan -> read-only manual scan with move-matched target -> tune safe senders/rules -> switch to move-all and re-scan -> Step 5 (ongoing daily background scanning) -> Step 6 ("how often to process 'no rules'" tied to daysBack + F82 indicator). State recommendation hierarchy: Entire Domain (general best) / Exact Email (transactional) / TLD (last resort).
**Acceptance Criteria**:
- [ ] Walkthrough authored as Markdown asset + manifest entry (NOT inline Dart >500 chars per ADR-0038)
- [ ] Reachable from Help screen; renders cleanly
- [ ] Recommendation hierarchy + Steps 5 & 6 present
- [ ] `content_loader_test` passes (watch for the F74-style manifest regression)
**Risk**: Low. Mirrors F74 surface.

### Task 3: F25 -- Rule Testing UI enhancements (~30-45 min, Sonnet) [EVAL SUBJECT]
**Execution order**: 3 (first UI-cluster task; eval subject for S38-CI-7)
**Step-type**: UI-NEW + SVC-EDIT `[basis: UI-NEW ~18 min + SVC-EDIT ~5 min, three small wirings]`
**Current state (verified 2026-05-25)**: all 3 sub-features NOT DONE.
**Approach**: Settings > Tools > Test Rule Pattern: (1) pre-populate match-against list from Demo Scan data; (2) plaintext-to-regex conversion on Test (reuse ManualRuleCreateScreen pattern-gen); (3) "open in test tool" action from Manage Rules.
**Acceptance Criteria**:
- [ ] Match-against list pre-populates from Demo Scan data
- [ ] Test converts plain text to regex using existing pattern-gen
- [ ] Manage Rules can open an existing rule in the test tool
- [ ] Tests cover all three; `flutter analyze` clean
**Risk**: Low-Medium. Reuses existing regex-gen.

### Task 4: F35 -- Rule editing UI with regex generation (~30-50 min, Sonnet) [EVAL SUBJECT]
**Execution order**: 4 (eval subject)
**Step-type**: UI-NEW (edit dialog) over existing create-only blocks `[basis: UI-NEW ~18 min n=1; PARTIAL groundwork lowers risk]`
**Current state (verified 2026-05-25)**: PARTIAL -- create-only `ManualRuleCreateScreen` exists; edit UI NOT DONE.
**Approach**: edit existing rules from Manage Rules -- plaintext-to-regex generation, direct-regex editing with validation, pattern preview, edit dialog/button, metadata field editing. Reuse create-flow building blocks.
**Acceptance Criteria**:
- [ ] Edit existing rule from Manage Rules (dialog/button)
- [ ] Plaintext->regex generation + direct-regex editing with validation + pattern preview
- [ ] Metadata field editing
- [ ] Tests cover edit flow; `flutter analyze` clean
**Risk**: Medium. New edit flow, but reuses create infra.

### Task 5: F37 -- Folder selectors: two-level listing (~40-60 min, Sonnet) [EVAL SUBJECT]
**Execution order**: 5 (highest UI risk; eval subject)
**Step-type**: UI-NEW (collapsible tree, Part A -- novel widget) + SVC-EDIT (separator detection) `[basis: UI-NEW ~18 min; held CONSERVATIVE for novel tree widget]`
**Current state (verified 2026-05-25)**: Part A NOT DONE; Part B PARTIAL; separator NOT DONE.
**Approach**: Part A -- two-level collapsible folder tree for Default Folders selector. Part B -- provider-default-first flat lists for Safe Sender / Deleted Rule selectors. Per-provider path-separator detection (not hardcoded `/`).
**Acceptance Criteria**:
- [ ] Default Folders selector shows two-level collapsible tree
- [ ] Safe Sender / Deleted Rule selectors show provider-default-first flat lists
- [ ] Path separator detected per provider (not hardcoded)
- [ ] Tests cover tree + separator; `flutter analyze` clean
**Risk**: Medium-High. Novel tree widget from scratch.

### Task 6: F79 -- WinWright full-sweep harness + UI-trigger cadence (~45-75 min, Sonnet)
**Execution order**: 6 (test tooling; after UI tasks so the sweep can exercise new UI)
**Step-type**: HOOK/tooling (PS runner) + SVC-EDIT (DB snapshot guard) + DOCS `[no-history for unattended runner; CONSERVATIVE]`
**Approach** (3 parts, Issue #240):
- **Part 1 -- one-command runner**: harden `mobile-app/scripts/run-winwright-tests.ps1` so all 7 scripts run unattended on a fresh dev build; bake in the Sprint 35 interactive workarounds (off-screen Save -> `ww_invoke`, dynamic field names, `Tab N of 4` selectors); auto-enable screen-reader flag + `doctor` preflight.
- **Part 2 -- pre/post dev-DB snapshot**: snapshot `spam_filter.db` (rules, safe_senders, settings) before/after; assert ZERO net change; fail loudly naming offending rows on drift.
- **Part 3 -- cadence policy + docs**: update `docs/TESTING_STRATEGY.md` when-to-run + `feedback_winwright_policy.md` (full sweep at END of any sprint touching `lib/ui/**`).
**Acceptance Criteria**:
- [ ] `run-winwright-tests.ps1` runs all 7 scripts unattended on fresh dev build; exits non-zero on any failure
- [ ] Pre/post DB snapshot integrated; a deliberately-leaky script FAILS the run with leaked rows named
- [ ] One full unattended sweep green with zero net DB change
- [ ] Docs reflect the `lib/ui/**`-touched -> end-of-sprint-sweep cadence
- [ ] Runtime target: full sweep < 10 min unattended
**Risk**: Medium-High. No close historical analogue; native MCP-driven interactive workarounds to automate.
**Note**: Sprint 40 touches `lib/ui/**` (F25/F35/F37) -- so once F79 ships, an end-of-sprint full sweep is the new cadence trigger (Phase 5).

### Task 7: S38-CI-7 -- Opus 4.6 vs 4.7 head-to-head evaluation (~90-150 min, Opus) [META-TASK] -- EVAL-RUN CANCELLED (Harold 2026-06-04)

> **[CANCELLED 2026-06-04]** The eval-RUN is cancelled (not deferred). Active model is now Opus 4.8, so a 4.6-vs-4.7 head-to-head is moot, and the in-session Agent selector has no version pin to dispatch a faithful re-run. Prep-only artifacts (4 task briefs + rubric + comparison-matrix template) were produced under `docs/sprints/s38-ci-7-eval-briefs/` and are retained as a record of the intended method. No comparison matrix or 4.6 re-run branches will be produced. Acceptance criteria below are VOID. See ALL_SPRINTS_MASTER_PLAN.md S38-CI-7 (CANCELLED).

**Execution order**: 7 (last; depends on F25/F35/F37/F78 being fully specified as eval subjects)
**Step-type**: procedural meta-task `[no-history; intentionally NOT minimized]`
**Eval subjects (Harold 2026-05-26, option 1a)**: F25, F35, F37, F78 -- the real Sprint 40 tasks.
**Method**: for each of the 4 subjects, create a `*-opus46` branch and re-run the IDENTICAL task brief on Opus 4.6 (the 4.7 run is the productive Sprint 40 run already on the feature branch). Capture full transcript + diff + rounds-to-converge + process deviations per run.
**Evaluation dimensions** (judge full task run, per task, per model):
1. Sprint-execution-doc process adherence (phase gates / checklists)
2. Instruction-following (task spec + CLAUDE.md + standing instructions)
3. Architecture discipline (fewer unsanctioned Class-1/2 changes; ADR respect)
4. Stopping-criteria adherence (SPRINT_STOPPING_CRITERIA.md; no over/under-stop)
5. Code quality (forward-looking maintainability, not just passing tests now)
**Acceptance Criteria**:
- [ ] All 4 subjects run on BOTH 4.6 and 4.7 on separate branches (4.6 runs on throwaway `*-opus46` branches, NOT merged)
- [ ] Comparison matrix (task x model x dimension) + narrative in `SPRINT_40_RETROSPECTIVE.md`
- [ ] Conclusions fed into `feedback_opus_pitfalls.md` + model-assignment guidance
**Risk**: Medium. Procedural; main risk is transcript-capture/scoring rigor, not code.

---

## Model Assignments

| Task | Model | Rationale |
|------|-------|-----------|
| F78 widget tests | Haiku | Straightforward; pattern established Sprint 39 |
| F75 Help walkthrough | Haiku | Content authoring; mirrors F74 |
| F25 rule testing UI | Sonnet | Multi-file UI; reuses regex-gen |
| F35 rule editing UI | Sonnet | New edit flow over existing blocks |
| F37 folder selectors | Sonnet | Novel tree widget + separator logic |
| F79 WinWright harness | Sonnet | PS tooling + DB-snapshot guard |
| S38-CI-7 model eval | Opus | The eval IS the comparison meta-task; orchestrates 4.6 re-runs |

---

## Execution Order Summary

1. F78 (test harness warm-up)  ->  2. F75 (content)  ->  3. F25  ->  4. F35  ->  5. F37 (UI cluster; eval subjects)  ->  6. F79 (harness; then end-of-sprint sweep trigger)  ->  7. S38-CI-7 (re-run subjects on 4.6 + score)

---

## Standing Approval Inventory (Phase 3.7)

On Phase 3.7 approval, the following are pre-authorized through Phase 7 (no per-task re-approval):
- All 7 tasks AS PLANNED above
- Commit + push to `feature/20260525_Sprint_40`
- Draft PR creation to `develop` (Chief Developer merges after retro + follow-ups; Claude NEVER merges)
- CHANGELOG entries per task
- End-of-sprint WinWright full sweep (lib/ui/** touched)

NOT pre-authorized (surface per Decision-Class Taxonomy at next natural break):
- Any Class-1 (architecture), Class-2 (development-decision), or Class-3 (scope change) decision outside this plan
- Scope reduction / task deferral without a met SPRINT_STOPPING_CRITERIA criterion + SM approval

---

**Status**: AWAITING PHASE 3.7 APPROVAL. Do not begin Phase 4 task work until Harold approves this plan.
