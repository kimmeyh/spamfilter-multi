# Sprint 39 Plan: Sprint 38 Carry-In Burn-Down + AOL/Auth Hardening + Process Tooling

**Sprint**: 39
**Date**: 2026-05-25 (Backlog Refinement / Phase 1-3)
**Branch**: `feature/20260523_Sprint_39`
**Status**: AWAITING PHASE 3.7 APPROVAL
**Type**: Mixed -- Bug fix (S38-CI-1, S38-CI-4, BUG-S37-2), UX (S38-CI-2, S38-CI-3), AOL/IMAP + anti-phishing (F91, F89), Docs/UX (F74), Testing (S38-CI-6, F92), Process tooling (F77, F93)
**Estimated Effort**: ~33-49h
**Wall-clock target**: ~7-12h (based on Sprint 37-38 actual/estimate ratio of ~20-25%)

> **Note**: A Sprint 39 "warmup" already shipped via PR #259 (merged to develop as 8d048c3): F90 (live-scan logging), BUG-S39-1 (rule-name collision), BUG-S39-2 (UNIQUE-violation rethrow). This plan covers the formal Sprint 39 scope confirmed at the 2026-05-25 Backlog Refinement.

---

## Sprint Objective

Burn down the Sprint 38 retrospective carry-ins, ship the two highest-value reliability/security items surfaced in recent manual testing (F91 AOL copy-not-move dedup; F89 SPF/DKIM/DMARC auth warnings), add the first user-facing Help content (F74 FAQ), and fix the process tooling that has been generating friction during this very refinement session (F93 + F77). No single feature dominates; this is a focused backlog burn-down with two substantive features (F91, F89) and a cluster of small carry-ins.

---

## Sprint Scope (12 items, confirmed at 2026-05-25 Backlog Refinement)

S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3, F91, F89, S38-CI-4, F74, F92, BUG-S37-2, F77, F93.

**S38-CI-7 moved to Sprint 40** (2026-05-25): the Opus 4.6 vs 4.7 head-to-head experiment was re-scoped (4+ tasks on BOTH models on separate branches, scored on process/instruction/architecture/stopping-criteria/code-quality adherence; ~6-10h) and belongs against the Sprint 40 task set.

(Sprint 40 target: F75, F25, F35, F37, F78, F79, S38-CI-7. Sprint 41 target: SEC-11b, F83. See ALL_SPRINTS_MASTER_PLAN.md "Sprint Assignment" table.)

---

## Key Design Decisions

1. **F91 and F89 both introduce DB v6 migration.** F91 adds `rfc5322_message_id` (Message-ID capture); F89 adds `created_with_auth_state`. To avoid two separate migrations, bundle both columns into a single DB v6 migration shipped with whichever task lands first; the second task adds its column to the same v6 step. Decide at execution: land F91 first (higher priority P85), have it open DB v6, F89 extends.

2. **F93 + F77 are tiny process-tooling items, scheduled early.** They harden the Claude-harness question/stop surface. F93 specifically fixes the false-positive that fired 5x during this refinement session (auto-advance hook has no Phase-1/Backlog-Refinement awareness). Doing them first stops that friction for the rest of the sprint. ~2-3h combined.

3. **Quick wins before features.** Execution order front-loads the small carry-ins (S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3) and process tooling (F93, F77) as warm-ups, then the substantive features (F91, F89, F74), then the variable-effort items (S38-CI-4, F92, BUG-S37-2).

4. **BUG-S37-2 design phase first.** The ccTLD blocklist-expansion sub-task needs a scoping decision (4 candidate options). Produce the option summary for Harold's selection at Phase 3/4 before implementing; the typo-cleanup sub-task can proceed independently.

5. **No CHANGELOG churn during sprint.** CHANGELOG entries added per task in the same commit, per CLAUDE.md changelog policy.

---

## Tasks (execution order)

### Task 1: F93 -- Auto-advance hook exempts Backlog Refinement (Phase 1) (~1-2h, Sonnet)
**Execution order**: 1 (process tooling; stops active friction)
**Problem**: `.claude/hooks/sprint-auto-advance.ps1` blocks any end-of-turn question on a `feature/\d+_Sprint_\d+` branch, with no awareness of Backlog Refinement (Phase 1). 5 false positives in the 2026-05-25 refinement session.
**Approach**: exempt when no `docs/sprints/SPRINT_N_PLAN.md` exists for the current sprint number (cleanest proxy for "not yet in Phase 4 execution").
**Acceptance Criteria**:
- [ ] Hook allows PO-decision questions during Backlog Refinement (no SPRINT_N_PLAN.md present)
- [ ] Hook still blocks procedural stalls during Phase 4-7 execution (plan present)
- [ ] 2-3 new test cases in `.claude/hooks/test-cases/*.json` covering the Phase-1-no-plan allow case; existing 7 cases still pass
**Risk**: Low. Self-contained hook + test-harness change.

### Task 2: F77 -- Hookify rule: block "want me to proceed?" patterns (~1h, Sonnet)
**Execution order**: 2 (process tooling; complements F93)
**Approach**: hookify rule rejecting "want me to proceed?", "should I continue?", "ready to proceed with X?" with the sprint-plan-approval reminder. Companion to F93 + the existing Stop-hook auto-advance enforcement.
**Acceptance Criteria**:
- [ ] Rule rejects the listed phrasings on sprint branches during execution
- [ ] Does not fire during Backlog Refinement (coordinate with F93's Phase-1 exemption)
- [ ] Rule documented in hookify config
**Risk**: Low.

### Task 3: S38-CI-1 -- Window X-close button fix (~1-3h, Sonnet)
**Execution order**: 3 (quick win; Windows bug)
**Problem**: X close button in the Windows 11 title bar does not close the app; other controls work.
**Investigation hints**: `mobile-app/windows/runner/main.cpp` + `flutter_window.cpp` WM_CLOSE handling; `window_manager` plugin config.
**Acceptance Criteria**:
- [ ] X button closes the app cleanly (same path as other close affordances)
- [ ] No regression to single-instance mutex / data-dir cleanup on close
- [ ] Manual verification on Windows dev build (Phase 5.3)
**Risk**: Low-medium (native window code). Awaiting Harold's image attachment for exact symptom.

### Task 4: S38-CI-2 -- Relocate "default folders account-specific" info card (~1h, Haiku)
**Execution order**: 4 (quick UX win)
**Change**: move the info card below the Default Folders header on the Manual Scan tab; ADD the same card in the same position on the Background tab.
**Acceptance Criteria**:
- [ ] Card appears below Default Folders header on Manual Scan tab
- [ ] Same card appears on Background tab
- [ ] `flutter analyze`/`flutter test` green
**Risk**: Low.

### Task 5: S38-CI-3 -- F84 Sub-tasks B+C: Shift+Click / Ctrl+Click-drag selection (~3-5h, Sonnet+Opus)
**Execution order**: 5 (UX; builds on shipped Sub-task A)
**Scope**: Sub-task A (Ctrl+A select-all) shipped Sprint 38. Remaining: B (Shift+Click extend selection) + C (Ctrl+Click-drag disjoint range) on Manage Rules + Manage Safe Senders.
**Acceptance Criteria**:
- [ ] Shift+Click extends current selection on both screens
- [ ] Ctrl+Click-drag creates disjoint selection on both screens
- [ ] macOS Cmd-equivalents; Linux uses Ctrl
- [ ] 3-5 widget tests via `WidgetTester.sendKeyEvent`
**Risk**: Medium (Flutter selection model is intricate).

### Task 6: F91 -- AOL copy-not-move source-folder dedup (~4-6h, Opus)
**Execution order**: 6 (highest-priority feature, P85; opens DB v6)
**Problem**: AOL re-injects a copy of a safe-sender-moved email back into Bulk Mail with a new UID; next scan re-rescues it -> infinite loop + Bulk Mail clutter.
**Phase 1 (~2h)**: capture RFC 5322 `Message-ID` into `EmailMessage.messageIdHeader`; persist in new `email_actions.rfc5322_message_id` column (**DB v6 migration** -- F89 extends same migration).
**Phase 2 (~2-3h)**: after safe-sender `UID MOVE`, `UID SEARCH HEADER Message-ID` in source folder; if duplicate found, move it to `deletedRuleFolder`. New `_safeSenderDedupCount`; surface as "Safe: N (M duplicates removed)".
**Acceptance Criteria** (abbreviated -- full list in ALL_SPRINTS_MASTER_PLAN.md F91):
- [ ] Message-ID captured (IMAP + Gmail), persisted in DB v6
- [ ] Post-move source-folder dedup deletes the re-injected copy (to Trash, recoverable)
- [ ] Skip when Message-ID null, Gmail OAuth (labels), or source==target
- [ ] Manual test on `kimmeyharold@aol.com`: scan 2 finds 0 new Bulk-Mail safe-sender hits
- [ ] Dedup logged to F90 live-scan log
- [ ] 5-8 tests with mocked IMAP responses
**Risk**: Medium (IMAP SEARCH HEADER quoting; DB migration). Depends on F90 (shipped) for log verification.

### Task 7: F89 -- Surface SPF/DKIM/DMARC auth failures on quick-add prompts (~6-10h, Opus)
**Execution order**: 7 (substantive security/UX feature; extends DB v6)
**Phase 1 (~2-4h)**: capture `Authentication-Results` (+ Received-SPF, DKIM-Signature, ARC) into `EmailMessage.headers` from Gmail + IMAP adapters; new `lib/core/services/auth_results_parser.dart` -> `EmailAuthResult`.
**Phase 2 (~4-6h)**: badge (GREEN/YELLOW/RED/GREY) on all quick-add surfaces; RED-state confirm dialog explaining what failed / why it matters / alternatives; persist `created_with_auth_state` (**DB v6**, extends F91's migration).
**Acceptance Criteria** (abbreviated -- full list in ALL_SPRINTS_MASTER_PLAN.md F89):
- [ ] Auth badge on RuleQuickAddScreen, SafeSenderQuickAddScreen, email-detail + results-display inline affordances
- [ ] RED blocks safe-sender add with informed-consent dialog; GREY/YELLOW do not block
- [ ] Sprint 38 Amazon phishing email is the lead test fixture
- [ ] 5-8 widget tests + 5-8 parser unit tests
**Risk**: Medium-high (header parsing across providers; UX copy). Bundle DB v6 with F91.

### Task 8: F74 -- FAQ section in Help (~2-4h, Haiku+Sonnet)
**Execution order**: 8 (first user-facing Help content; uses ADR-0038 assets)
**Scope**: FAQ section on the Help screen; content authored as Markdown assets per ADR-0038 (NOT inline Dart). >=8 questions: TLD, IANA list, domain-type distinctions, Safe Sender precedence, why scanner skips emails, ReDoS, where data is stored, export/import.
**Acceptance Criteria**:
- [ ] FAQ accessible from Help; >=8 questions; each answer fits one screen
- [ ] Content lives in `assets/content/help/faq*.md` + manifest entry (ADR-0038)
- [ ] Cross-reference from rule-creation screen to TLD FAQ
- [ ] Manifest validator passes
**Risk**: Low (infrastructure exists post-Sprint-38).

### Task 9: S38-CI-4 -- IMAP cursor cap at daysBack-ago-UID (~2-3h, Sonnet)
**Execution order**: 9 (refinement of Sprint 38 F6c)
**Scope**: cap the `oldest_no_rule_uid` cursor at the UID corresponding to `now - daysBack` so the no-rule backlog is bounded by retention. Needs a UID-for-date lookup (`UID SEARCH SINCE <date>`, cached per (account,folder) for the scan); clamp in `_updateOldestNoRuleCursors` at `max(oldestNoRuleUid, daysBackUid)`.
**Acceptance Criteria**:
- [ ] No-rule cursor never anchors older than `now - daysBack`
- [ ] daysBack-UID lookup cached per scan (one IMAP round-trip per folder, not per batch)
- [ ] 3-5 tests covering cap behavior + cache
**Risk**: Low-medium.

### Task 10: S38-CI-6 -- Widget test for `_loadLastCompletedScan` cross-screen reload (~2h, Sonnet)
**Execution order**: 10 (testing debt; pins the Sprint 38 Rounds 7/8/9 regression)
**Acceptance Criteria**:
- [ ] Widget test: open historical scan, mutate RuleSetProvider out-of-band, re-enter, assert chip count + footer "M of N" + `_hiddenEmailKeys` reflect new rule on FIRST paint
**Risk**: Low.

### Task 11: F92 -- Dedicated tests for `LiveScanLogger` (~2-3h, Haiku+Sonnet)
**Execution order**: 11 (testing debt from PR #259 Copilot review)
**Acceptance Criteria**:
- [ ] Tests: env-aware path, cross-platform path.join, silent-on-IO-failure, append semantics, gating (off=0 writes), CSV+XLSX on, XLSX regen
- [ ] 5-8 new tests; suite green
**Risk**: Low (path_provider test-harness mocking is the one wrinkle).

### Task 12: BUG-S37-2 -- Bundled-rule TLD data quality + ccTLD gap-fill (~30-60 min, Sonnet)
**Execution order**: 12 (data quality; pure DATA -- no UI)
**Scope decision (Harold, 2026-05-25)**: ccTLDs are bundled block rules in the rules DB, NOT a settings feature. The bundled DB already contains almost all ccTLDs; this task RECONCILES the bundled set against the full ISO 3166-1 alpha-2 list and ADDS only the missing ones, EXCLUDING `.us .uk .ca`. Users edit/remove these later via the existing Manage Rules screen -- no new ccTLD UI.
**Sub-task (a) -- data quality (DATA)**: script-driven sweep of bundled TLD rules for typos (`*.c`, `*.giw`, `*.nwm`, `*.sweepss`, `*.xd`, `*.xn-*`) and miscategorized second-level domains (`*.de.com`, `*.jp.com`, `*.uk.com`, etc.); output candidates for Harold review (NO auto-apply).
**Sub-task (b) -- ccTLD gap-fill (DATA)**: diff the bundled `rules.yaml` / seed DB `top_level_domain` set against the canonical ISO 3166-1 ccTLD list; add any MISSING ccTLDs (except `.us .uk .ca`) as `top_level_domain` block rules via one-time migration. Most already present -- this fills gaps, does not bulk-insert ~245 rules.
**Acceptance Criteria**:
- [ ] (a) Typo sweep outputs candidates for Harold review (no auto-apply)
- [ ] (b) Every ISO 3166-1 ccTLD except `.us .uk .ca` is present as a `top_level_domain` block rule in the default DB after migration (gap-fill, idempotent -- no duplicates for already-present ccTLDs)
- [ ] Migration is idempotent (re-running adds nothing); existing rules untouched
- [ ] Test asserts post-migration ccTLD coverage (full ISO set minus .us/.uk/.ca present)
**Risk**: Low (pure data reconcile; existing Manage Rules UI covers user edits). No UI work.

### Task 13: S38-CI-7 -- MOVED TO SPRINT 40
The Opus 4.6 vs 4.7 head-to-head evaluation was re-scoped (Harold 2026-05-25) to a ~6-10h experiment: 4+ tasks run on BOTH models on separate branches, scored on process-doc adherence / instruction-following / architecture discipline / stopping-criteria adherence / forward-looking code quality. It belongs against the Sprint 40 task set, not Sprint 39. See ALL_SPRINTS_MASTER_PLAN.md S38-CI-7 for the full rubric.

---

## Model Tiering Summary

| Task | Item | Model | Effort |
|------|------|-------|--------|
| 1 | F93 hook Phase-1 exempt | Sonnet | ~1-2h |
| 2 | F77 hookify proceed-rule | Sonnet | ~1h |
| 3 | S38-CI-1 X-close fix | Sonnet | ~1-3h |
| 4 | S38-CI-2 info-card relocate | Haiku | ~1h |
| 5 | S38-CI-3 Shift/Ctrl-click selection | Sonnet+Opus | ~3-5h |
| 6 | F91 AOL copy-not-move dedup | Opus | ~4-6h |
| 7 | F89 auth-failure warnings | Opus | ~6-10h |
| 8 | F74 Help FAQ | Haiku+Sonnet | ~2-4h |
| 9 | S38-CI-4 cursor cap | Sonnet | ~2-3h |
| 10 | S38-CI-6 reload widget test | Sonnet | ~2h |
| 11 | F92 LiveScanLogger tests | Haiku+Sonnet | ~2-3h |
| 12 | BUG-S37-2 TLD data quality + ccTLD | Sonnet | ~3-5h |

(S38-CI-7 model eval moved to Sprint 40.)

**Total**: ~30-45h estimated (12 tasks); actual wall-clock ~2h (see docs/CODING_VELOCITY.md -- estimates ran 4-14x high).

---

## Architecture Impact (Phase 3.6.1)

| Item | Architecture impact | Required updates |
|------|---------------------|-------------------|
| F91 | New `email_actions.rfc5322_message_id` column (DB v6); `EmailMessage.messageIdHeader`; post-move dedup in EmailScanner | F61-successor doc backlog: DB v6 + dedup path |
| F89 | New `auth_results_parser.dart` + `EmailAuthResult`; `created_with_auth_state` column (DB v6); reusable `EmailAuthBadge` widget | Doc backlog: auth subsystem + DB v6 |
| S38-CI-4 | New UID-for-date lookup; cursor clamp logic | Doc backlog: cursor cap semantics |
| F74 | New FAQ asset files + manifest entries (ADR-0038 pattern) | None new (uses shipped subsystem) |
| F93/F77 | `.claude/hooks/` changes only | None (Claude harness, not app) |
| Others | None / test-only | None |

**Net**: DB v6 is the one schema deliverable (shared by F91 + F89). No new ADR required.

---

## Test Plan

**Estimated new tests**: 25-40 across tasks (F91 5-8, F89 10-16, S38-CI-4 3-5, S38-CI-6 1, F92 5-8, S38-CI-3 3-5, F93 2-3).
**Starting test count**: 1460 passing (post-PR #259). Target Sprint 39 end: ~1490-1500 passing.
**Manual testing (Phase 5.3)**: F91 (AOL account), F89 (auth-failure email), S38-CI-1 (Windows X-close), S38-CI-2 (visual), S38-CI-3 (keyboard/pointer), F74 (Help visual).
**WinWright (per `feedback_winwright_policy.md`)**: this sprint touches `lib/ui/**` (S38-CI-2, S38-CI-3, F89 badges, F74). Per the Sprint 39 cadence, run the affected scripts mid-sprint; the end-of-sprint full sweep is gated on the F79 harness, which ships Sprint 40 -- so for Sprint 39, run conditional per-script (Manage Rules/Safe Senders after S38-CI-3; Settings tabs after S38-CI-2; Help after F74) and note the full sweep as deferred to F79.

---

## Standing Approval Inventory (Phase 3.7)

On Phase 3.7 approval of this plan, the following are pre-authorized through Phase 7 (no per-step re-approval):
- All 13 task implementations as specified
- Commits to `feature/20260523_Sprint_39` per task
- CHANGELOG updates per task (same commit)
- DB v6 migration (F91 + F89 columns)
- PR creation/update to `develop`
- Conditional WinWright runs for touched surfaces

**Decisions that still require surfacing (per CLAUDE.md decision-class taxonomy)**:
- BUG-S37-2 ccTLD scope (PO choice among 4 options) -- surface at Phase 3 or Phase 4 design
- F82-style design choices: N/A this sprint
- Any DB-migration semantic change beyond the two named columns (Class-1 architecture)
- S38-CI-1 root-cause if it requires changing the window-management architecture (Class-1)

---

## Open Items Before / During Execution

- **GitHub issues**: F79=#240 exists; F89/F91/F92/F77/F93 and several S38-CI items need issues created at Phase 3.2.2 (or reference by F# if issue creation deferred).
- **S38-CI-1 image attachment** pending from Harold (exact X-close symptom).
- **F77 + F93 in Sprint 39 scope** per Claude recommendation (the F93 friction is active now); confirm at approval.
