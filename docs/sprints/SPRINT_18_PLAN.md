# Sprint 18 Plan: Rule Management Quality, Provider Domains, and Rule Testing

**Sprint**: 18
**Branch**: `feature/20260224_Sprint_18`
**PR**: TBD targeting `develop`
**Planned Duration**: ~22-32h
**Start Date**: February 24, 2026

---

## Sprint Objective

Fix the critical safe sender / block rule conflict bug (#154), establish subject and body content rule pattern standards (#141), add common email provider domain detection (F20), verify and complete inline rule assignment from scan results (F21), and add rule testing and simulation UI (F8).

## Tasks

### Task A: Fix Safe Sender / Block Rule Conflict Detection (Issue #154)
- **Model**: Opus
- **Estimated Effort**: ~4-6h
- **Description**: When a user converts a safe sender to a block rule (via Quick Add or Manage Rules), the corresponding safe sender entry is not removed. Since safe senders are evaluated first by RuleEvaluator, the block rule never fires.
- **User-Reported Reproduction**: `no-reply@notification.circle.so` -- user attempted "Block Entire Domain" multiple times; app continues showing "Safe Sender Entire Domain".
- **Root Cause**: The `RuleQuickAddScreen` and `SafeSenderQuickAddScreen` have conflict detection (`RuleConflictDetector`) and auto-removal logic, but the inline quick-add buttons in `ResultsDisplayScreen` bypass this logic entirely. The `_addSafeSender()` and `_createBlockRule()` methods in `ResultsDisplayScreen` call `RuleSetProvider` directly without checking for or removing conflicting entries.
- **Key Files**:
  - `lib/ui/screens/results_display_screen.dart` (inline quick-add methods)
  - `lib/ui/screens/rule_quick_add_screen.dart` (has working conflict detection)
  - `lib/ui/screens/safe_sender_quick_add_screen.dart` (has working conflict detection)
  - `lib/core/services/rule_conflict_detector.dart`
  - `lib/core/providers/rule_set_provider.dart`
- **Acceptance Criteria**:
  - [ ] Adding a block rule via inline popup checks for matching safe sender entries
  - [ ] Matching safe sender entries are removed (with confirmation)
  - [ ] Adding a safe sender via inline popup checks for matching delete rules
  - [ ] Matching delete rules are removed (with confirmation)
  - [ ] Both rules and safe senders are updated atomically
  - [ ] Conflict detection works consistently across all three entry points (ResultsDisplayScreen inline, RuleQuickAddScreen, SafeSenderQuickAddScreen)
  - [ ] Regression tests cover conflict detection scenarios
  - [ ] Manual test: reproduce `no-reply@notification.circle.so` scenario and verify fix

### Task B: Subject and Body Content Rule Standards (Issue #141)
- **Model**: Sonnet
- **Estimated Effort**: ~4-6h
- **Description**: Establish and enforce standards for subject and body content rule patterns, including normalization, escaping, and matching conventions.
- **Key Files**:
  - `lib/core/utils/pattern_normalization.dart`
  - `lib/core/utils/pattern_generation.dart`
  - `lib/core/services/rule_evaluator.dart`
  - `lib/core/services/pattern_compiler.dart`
- **Acceptance Criteria**:
  - [ ] Document subject pattern standards (case sensitivity, whitespace handling, special characters)
  - [ ] Document body content pattern standards (URL extraction, domain matching, text normalization)
  - [ ] Ensure pattern generation utilities follow documented standards
  - [ ] Add validation for pattern standards in PatternCompiler
  - [ ] Tests cover standard and edge case patterns
  - [ ] Existing rules continue to work (no breaking changes)

### Task C: Common Email Provider Domain Reference Table (Issue #167, F20)
- **Model**: Sonnet
- **Estimated Effort**: ~3-4h
- **Description**: Maintain an application-level reference table of common email provider domains. Loaded into memory at scan time for matching against scan results. Used by rule suggestion logic to distinguish personal provider emails from business/organizational domains.
- **Key Files**:
  - New: `lib/core/data/common_email_providers.dart` (or similar)
  - `lib/core/services/rule_evaluator.dart` (for integration)
- **Acceptance Criteria**:
  - [ ] Application-managed table (not user-editable)
  - [ ] Covers major providers: Gmail, AOL, Yahoo, Microsoft (outlook.com, hotmail.com, live.com, msn.com), Proton (protonmail.com, proton.me, pm.me), iCloud, Zoho, GMX, mail.com
  - [ ] Loaded into memory at scan time for fast matching
  - [ ] API to check if a domain is a known provider: `isCommonProvider(String domain) -> bool`
  - [ ] API to get provider name: `getProviderName(String domain) -> String?`
  - [ ] Database-backed with seed data on first launch
  - [ ] Tests cover provider detection for all listed domains including subdomains

### Task D: Inline Rule Assignment Verification and Completion (Issue #168, F21)
- **Model**: Opus
- **Estimated Effort**: ~4-6h (reduced from original ~12-16h -- most implementation exists)
- **Description**: The inline rule assignment from scan results is already substantially implemented in `ResultsDisplayScreen` (popup dialog, safe sender/block rule options, visual checkmarks, immediate persistence). This task verifies the existing implementation against F21 acceptance criteria and completes any gaps.
- **Discovery**: Sprint exploration revealed that the popup dialog with all rule type options, green checkmark visual tracking, and immediate persistence already exists (lines 1189-1429 of `results_display_screen.dart`).
- **Key Files**:
  - `lib/ui/screens/results_display_screen.dart` (existing inline assignment)
  - `lib/core/providers/email_scan_provider.dart` (result state)
  - `lib/core/providers/rule_set_provider.dart` (rule persistence)
- **Verification Checklist**:
  - [ ] Safe Sender and Block Rule options work for "No Rule" emails
  - [ ] Safe Sender and Block Rule options work for already-matched emails
  - [ ] After adding a rule, the Scan Results list item updates to show the new assignment
  - [ ] Visual tracking: user can see which "No Rule" items now have rules during review session
  - [ ] Re-opening email detail popup after rule assignment shows the newly matched rule
  - [ ] Re-evaluation of rules happens when popup is reopened (not cached scan-time result)
  - [ ] Conflict detection integrated (ties into Task A fix)
- **Acceptance Criteria**:
  - [ ] All F21 features verified working or gaps implemented
  - [ ] List refresh after inline assignment works correctly
  - [ ] Visual tracking persists during review session
  - [ ] Integration with Task A conflict detection confirmed
  - [ ] Tests cover inline assignment flow

### Task E: Rule Testing and Simulation UI (Issue #169, F8)
- **Model**: Opus
- **Estimated Effort**: ~6-8h
- **Description**: UI for testing rules against sample emails before saving. Users can load recent emails from scan history and test a rule pattern against them to see which would match and why.
- **Key Files**:
  - New: `lib/ui/screens/rule_test_screen.dart` (or similar)
  - `lib/core/services/rule_evaluator.dart` (for test evaluation)
  - `lib/core/services/pattern_compiler.dart` (for pattern validation)
  - `lib/core/storage/unmatched_email_store.dart` (for sample emails)
- **Acceptance Criteria**:
  - [ ] User can enter or select a rule pattern to test
  - [ ] User can load sample emails from recent scan history (unmatched emails)
  - [ ] Test shows which emails match the pattern and why (matched field, matched text)
  - [ ] Pattern highlighting in matched content
  - [ ] Accessible from Rule Quick Add screen and Manage Rules screen
  - [ ] Works for all condition types: from, subject, body, header
  - [ ] Tests cover rule testing logic

---

## Dependencies

```
Task A (Bug #154) ─────────────────────────────────────┐
                                                        ├── Task D depends on A (conflict detection)
Task B (#141 Rule Standards) ──────────────────────────┤
                                                        ├── Task E depends on B (uses standardized patterns)
Task C (F20 Provider Domains) ─── independent           │
                                                        │
Task D (F21 Inline Assignment) ── depends on A ─────────┘
Task E (F8 Rule Testing) ──────── depends on B
```

**Recommended execution order**: A and B first (can parallel), then C (independent), then D (needs A), then E (needs B).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Task A conflict detection requires UI changes across 3 screens | Medium | Medium | Extract shared conflict resolution logic into reusable service |
| Task D reveals more gaps than expected | Low | Low | Most implementation exists; reduce to verification + minor fixes |
| Task E scope creep (full simulation vs pattern testing) | Medium | Medium | Time-box to pattern testing against sample emails; defer full inbox simulation |
| Task B standards changes break existing rules | Low | High | All changes must be backward-compatible; test against existing rules.yaml |

## Model Assignments

| Task | Model | Rationale |
|------|-------|-----------|
| A | Opus | Critical bug fix, cross-screen refactoring, needs deep understanding |
| B | Sonnet | Standards documentation and validation, well-defined scope |
| C | Sonnet | Data table and API, straightforward implementation |
| D | Opus | Verification across complex UI, integration with Task A |
| E | Opus | New UI screen, evaluation logic integration |
