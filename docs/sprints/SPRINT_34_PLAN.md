# Sprint 34 Plan: Rule Management Foundation + UI Standards

**Sprint**: 34
**Date**: April 17, 2026
**Branch**: `feature/20260417_Sprint_34`
**Issue**: #235
**Type**: Mixed -- Bug fix (F73), Core feature (F56), Documentation (ADR-0037), Testing (F69), Tech debt (F62, F72)
**Estimated Effort**: ~28-40h (multi-session, Path C)

---

## Sprint Objective

Fix the broken rule data layer (F73), build the manual rule creation UI (F56), establish accessibility/UI standards documentation (ADR-0037 + ARSD/ARCHITECTURE updates), validate with WinWright E2E tests (F69), and clean up tech debt (F62/F72). Together these prepare the app for the next Windows Store submission.

---

## Key Design Decisions

1. **Bundled YAML for new users** includes ONLY `header_from` rules (TLD, entire domain, exact domain). NO `subject` or `body` rules -- those are too prone to accidental flagging; each user should choose these on their own via scanning and manual rule creation (F56).

2. **YAML round-trip invariant**: All rule schema changes must preserve the export -> user edit -> re-import cycle. Classification fields (`patternCategory`, `patternSubType`, `sourceDomain`) must survive the round trip.

3. **ADR/ARSD/ARCHITECTURE changes require user review**: Draft and present for approval before committing.

4. **Accessibility standards (ADR-0037)**: All new UI work must apply Semantics labels for WinWright testability and follow SelectionArea/SelectableText standards.

---

## Tasks

### Task 1: F73 -- Monolithic rule split + bundled YAML rebuild (~6-10h, Opus)

**Execution order**: 1 (fixes data layer that F56 builds on)

**Problem**: Bundled YAML stores 5 monolithic rules; Sprint 20 split script expanded these to ~3500 individual DB rows. Post-seed migrations (F53 TLD .cc/.ne) target the deleted monolithic row and silently skip.

**Part A: In-app migration for existing installs**
- At startup, detect remaining monolithic rules (rows where condition_header JSON array has >1 pattern)
- Split into individual per-pattern rows using same classification logic as split_rules.dart
- Insert missing .cc/.ne TLD patterns as individual rows (pattern_category=header_from, pattern_sub_type=top_level_domain, execution_order=10)
- Idempotent -- safe on already-split DBs

**Part B: Rebuild bundled YAML**
- Export Harold's split DB individual rules to new YAML format
- ONLY include header_from rules (TLD, entire_domain, exact_domain) -- EXCLUDE subject and body rules
- Each YAML entry maps to one DB row with patternCategory, patternSubType, sourceDomain
- New user seeding inserts individual rows directly -- no split step needed
- Exact_email rules excluded from bundled set (too user-specific)

**Part C: Fix ensureTldBlockRules**
- Rewrite to insert individual per-pattern rows instead of patching monolithic JSON array
- Must be idempotent against both monolithic (legacy) and split (current) DB formats
- Remove the monolithic SpamAutoDeleteHeader name lookup

**Acceptance criteria**:
- [ ] Harold's dev DB shows .cc and .ne in Manage Rules as "Header / From - Top-Level Domain"
- [ ] Bundled rules.yaml contains individual per-pattern entries (not 5 monolithic blobs)
- [ ] Bundled rules.yaml contains ONLY header_from rules (no subject, no body)
- [ ] Fresh install seeds individual rules with classification fields populated
- [ ] ensureTldBlockRules works on both monolithic and split DBs
- [ ] YAML export -> user edit -> re-import produces correct DB state
- [ ] All existing tests pass (1313 baseline)

### Task 2: ADR-0037 -- UI/Accessibility Standards (~2-3h, Sonnet)

**Execution order**: 2 (establishes standards before F56 UI work)

**DRAFT FOR USER REVIEW** -- present all docs for approval before committing.

**ADR-0037**: "UI/Accessibility Standards and Cross-Platform Compatibility"
- Accessibility target: WCAG 2.1 AA
- Semantics labeling strategy for WinWright testability and screen readers
- SelectionArea/SelectableText standard: all user-visible text must be selectable
- YAML round-trip compatibility: all rule/safe-sender schema changes must preserve export -> edit -> re-import
- Cross-platform UI: Flutter Material 3, adaptive breakpoints (F63 reference)
- Touch target minimum: 48dp (per accessibility_helper.dart)
- WinWright E2E testability: interactive elements discoverable via Windows UI Automation
- accessibility_helper.dart adoption guidance

**ARSD.md**: New section (appropriate insertion point TBD with user)
**ARCHITECTURE.md**: Add/expand UI standards subsection
**QUALITY_STANDARDS.md**: Add accessibility quality gate

**Acceptance criteria**:
- [ ] ADR-0037 drafted and user-approved
- [ ] ARSD section drafted and user-approved
- [ ] ARCHITECTURE.md and QUALITY_STANDARDS.md updates user-approved
- [ ] YAML round-trip invariant documented as formal requirement
- [ ] accessibility_helper.dart adoption guidance included

### Task 3: F56 -- Manual rule creation UI (~10-14h, Opus)

**Execution order**: 3 (biggest feature, depends on F73 data fix and ADR-0037 standards)

**Block rules (4 types)** accessible from Manage Rules screen:
- **Top-level domain**: User enters TLD (e.g., .cc) -> `@.*\.cc$`, header_from/top_level_domain, exec_order=10
- **Exact domain**: User pastes email/domain -> `@domain\.com$`, header_from/exact_domain, exec_order=30
- **Entire domain**: User pastes email/domain/URL -> `@(?:[a-z0-9-]+\.)*domain\.com$`, header_from/entire_domain, exec_order=20
- **Exact email**: User enters email -> `^user@domain\.com$`, header_from/exact_email, exec_order=40

**Safe sender rules (3 types, no TLD)** accessible from Manage Safe Senders screen:
- Exact domain, entire domain, exact email -- same input parsing

**Design principles** (from DB deep dive):
- PatternCompiler.detectReDoS validation at save time (SEC-1b enforcement)
- sourceDomain extracted for Manage Rules display
- Confirmation dialog showing generated regex before save
- Conflict checking against existing rules/safe senders
- Input parsing: bare email, bare domain, URL with protocol, URL with path
- Semantics labels per ADR-0037 for WinWright testability
- SelectionArea/SelectableText per ADR-0037
- created_by: 'manual' field for tracking

**SEC-1b manual test**: During Phase 5, user enters catastrophic regex (e.g., `(a+)+$`) -- app must reject on save with clear error.

**YAML round-trip**: Manually created rules must export and re-import cleanly.

**Acceptance criteria**:
- [ ] Block rule creation works for all 4 types with correct classification
- [ ] Safe sender creation works for all 3 types
- [ ] Input parsing handles: bare email, bare domain, URL with protocol, URL with path
- [ ] Confirmation dialog shows generated pattern
- [ ] Conflict detection warns on conflicts
- [ ] ReDoS rejection with clear error (SEC-1b)
- [ ] Rules appear correctly in Manage Rules UI
- [ ] Safe senders appear correctly in Manage Safe Senders UI
- [ ] YAML export -> edit -> re-import preserves manually created rules
- [ ] Semantics labels on all interactive elements

### Task 4: F69 -- WinWright E2E desktop tests (~6-8h, Sonnet)

**Execution order**: 4 (validates F56 and overall app)

**Test scripts**:
- Manual scan: run scan, navigate to Scan History, tap entry, verify counts
- Background scan: trigger, verify in Scan History
- Account selection: verify flow
- Settings: test all tabs (General, Scan, Background, Account overrides)
- F56 manual rule creation: create TLD block, verify in Manage Rules
- Text selection: verify on key screens

**Acceptance criteria**:
- [ ] WinWright test scripts created for scan flows, history, settings
- [ ] F56 rule creation E2E test included
- [ ] Tests pass on Windows desktop dev build
- [ ] Test scripts documented in TESTING_STRATEGY.md

### Task 5: F62 -- Dead code cleanup (~2h, Haiku)

**Execution order**: 5

- Remove deprecated config/app_paths.dart
- Consolidate duplicate LocalRuleStore classes
- Move or remove legacy OAuth screens from lib/screens/

**Acceptance criteria**:
- [ ] No deprecated duplicate files remain
- [ ] All tests pass, 0 analyzer issues

### Task 6: F72 -- Code hygiene cleanup (~1-2h, Haiku)

**Execution order**: 6

- Remove emoji in secure_credentials_store.dart:527
- Add if(MSVC) guard in CMakeLists.txt
- SEC-20: Soften email validation messages

**Acceptance criteria**:
- [ ] No emojis in production code
- [ ] CMakeLists.txt MSVC-guarded
- [ ] Email validation messages are generic
- [ ] All tests pass, 0 analyzer issues

---

## Execution Summary

| # | Task | Est. | Model | Deps |
|---|------|------|-------|------|
| 1 | F73: Rule data fix + YAML rebuild | ~6-10h | Opus | None |
| 2 | ADR-0037: UI/Accessibility standards | ~2-3h | Sonnet | None (user review gate) |
| 3 | F56: Manual rule creation UI | ~10-14h | Opus | F73, ADR-0037 |
| 4 | F69: WinWright E2E tests | ~6-8h | Sonnet | F56 |
| 5 | F62: Dead code cleanup | ~2h | Haiku | None |
| 6 | F72: Code hygiene cleanup | ~1-2h | Haiku | None |

**Total**: ~28-40h, 6 tasks

---

## Risks

- F73 bundled YAML rebuild is a large file change (~3500 entries filtered to header_from only) -- careful diff review
- F56 input parsing (email vs domain vs URL) has many edge cases -- rely on existing PatternNormalization
- WinWright tests depend on SPI_SETSCREENREADER flag (documented Sprint 27)
- ADR-0037 user review gate may require iteration

---

## Sprint 33 Category 13/14 Carry-ins

None (both "None" across all 4 roles).

---

## Test Baseline

- Tests: 1313 passing, 28 skipped, 0 failures
- Analyzer: 0 issues
