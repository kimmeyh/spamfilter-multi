# Productive Run Notes -- Opus 4.7 Outputs (Sprint 40, 2026-05-30)

Captured BEFORE the 4.6 re-run so the 4.6 outputs can be diffed against ground truth without bias from "the answer is in the merged PR."

## F78 (Sprint 40 Task 1) -- Haiku

- Productive-run model in the original brief: **Haiku** (the brief explicitly says "You are on Haiku, not Opus")
- For the 4.6 eval, this is the only brief where the parent productive model differs from Sonnet
- Files changed: `mobile-app/test/ui/screens/manual_rule_create_screen_test.dart` only
- Tests added: 11 `testWidgets` cases in a new group `F78 ManualRuleCreateScreen widget rendering` at line 187 of the test file
- File size: 185 -> 364 lines
- Suite delta: 1530 pass -> 1541 pass (+11)
- `flutter analyze`: 0 issues
- Wall-clock: ~25 min (top of 25-40 min estimate)
- Quality note flagged by parent: pattern-preview test asserts `Form`/`ListView` structure rather than verifying preview text updates as user types -- thinner than plan called for. Did not block; flagged for Phase 5.2 testing review.

## F25 (Sprint 40 Task 3) -- Sonnet

- Productive-run model: **Sonnet**
- Files changed (8):
  - `mobile-app/lib/core/utils/manual_rule_pattern_generator.dart` (NEW, 232 lines)
  - `mobile-app/lib/ui/screens/rule_test_screen.dart` (modified, +160 lines)
  - `mobile-app/lib/ui/screens/manual_rule_create_screen.dart` (refactored, -119 lines as old generators removed)
  - `mobile-app/lib/ui/screens/rules_management_screen.dart` (modified, +82 lines for Test button + _openRuleInTestTool)
  - `mobile-app/test/unit/utils/manual_rule_pattern_generator_test.dart` (NEW, 246 lines, 26 tests)
  - `mobile-app/test/unit/ui/open_in_test_tool_test.dart` (NEW, 157 lines, 11 tests)
  - `mobile-app/test/ui/screens/rule_test_screen_test.dart` (modified, +186 lines, 12 new widget tests + 2 updated)
  - `mobile-app/test/unit/ui/help_screen_test.dart` (FIXED -- pre-existing F75 regression caught: count 21 -> 22)
- Approach: extracted `ManualRulePatternGenerator` as public utility (5 static methods: `generateTopLevelDomain`, `generateEntireDomain`, `generateExactDomain`, `generateExactEmail`, `generateFromPlaintext`)
- Sub-feature 1 (Demo fallback): triggers in BOTH empty-DB-result path AND DB-unavailable catch-block path; amber banner renders when `_isDemoData == true`
- Sub-feature 2 (plaintext->regex): Checkbox above input field; label changes from "Regex pattern" to "Plain text input"; `Icons.auto_fix_high` + "Generated regex: `<pattern>`" label below after Test
- Sub-feature 3 (Open in test tool): `OutlinedButton.icon(Icons.science, "Test")` in `_showRuleDetails` AlertDialog actions row; new `_openRuleInTestTool(Rule rule)` method maps `patternCategory` -> `conditionType`
- Suite delta: 1541 pass -> 1588 pass (+47)
- `flutter analyze`: 0 issues
- Wall-clock: ~38 min (top of 30-45 min estimate)
- Class-2 decisions: utility extraction (pre-authorized); no surfacing needed

## F35 (Sprint 40 Task 4) -- Sonnet

- Productive-run model: **Sonnet**
- Files changed (4):
  - `mobile-app/lib/ui/screens/rule_edit_screen.dart` (NEW)
  - `mobile-app/lib/ui/screens/rules_management_screen.dart` (modified, Edit button + `_openRuleInEditScreen` method at line 405; Edit button at line 323 next to F25's Test button)
  - `mobile-app/lib/core/providers/rule_set_provider.dart` (modified, 1-line `rethrow` added to `updateRule` catch block, mirrors BUG-S39-2 addRule discipline)
  - `mobile-app/test/ui/screens/rule_edit_screen_test.dart` (NEW, 23 widget tests using `_StubRuleDatabaseStore`)
  - `mobile-app/test/unit/providers/rule_set_provider_test.dart` (modified, 2 new `rethrow` tests using `expectLater`, 1 broken test replaced)
- Approach chosen: full `RuleEditScreen` (NOT in-place dialog) -- mirrors `ManualRuleCreateScreen` structure with dual-mode (guided plaintext-to-regex via `ManualRulePatternGenerator`, OR direct-regex with ReDoS + syntax validation)
- `_initFromRule()` pre-populates all fields and auto-detects starting mode
- `_save()` preserves `name` (DB PK), calls `widget.store.updateRule(updatedRule)`, pops `true` on success
- Edit button keyed as `OutlinedButton.icon(Icons.edit, "Edit")` immediately next to F25's "Test" button
- No shared widgets extracted to `lib/ui/widgets/rule_form/` -- author judged the RuleEditScreen widgets self-contained enough not to warrant extraction
- Suite delta: 1588 pass -> 1612 pass (+24)
- `flutter analyze`: 0 issues
- Wall-clock: ~30 min (mid of 30-50 min estimate)
- Class-2 decisions: `updateRule` rethrow (pre-authorized); RuleEditScreen approach (pre-authorized as recommended); no extraction (judged unnecessary, documented)

## F37 (Sprint 40 Task 5) -- Sonnet

- Productive-run model: **Sonnet**
- Files changed (3):
  - `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart` (modified, +10 lines: `FolderInfo.hierarchyDelimiter` String field, defaulted to `/` for backward compat)
  - `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` (modified, +5 lines: uses `mailbox.pathSeparator` from `enough_mail` Mailbox class)
  - `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` (modified, +1 line: hardcoded `/`)
  - `mobile-app/lib/adapters/email_providers/mock_email_provider.dart` (modified, +1 line: hardcoded `/`)
  - `mobile-app/lib/adapters/email_providers/outlook_adapter.dart`: NOT changed -- listFolders is UnimplementedError, default `/` will apply when implemented
  - `mobile-app/lib/ui/screens/folder_selection_screen.dart` (modified, 375 lines, +91 net: `groupFoldersForTree()` pure fn, `reorderForSingleSelect()` pure fn, `_buildTreeItems()` ExpansionTile renderer for multi-select)
  - `mobile-app/test/unit/folder_tree_test.dart` (NEW, 19 tests: 4 Part C + 7 Part A + 8 Part B)
- Part A: ExpansionTile-based depth-2 tree. **Parent rows expand-only (no checkbox on parent header)**. Rationale: IMAP parent containers are typically `\NoSelect` on the server; allowing parent selection would produce silent scan failures. Documented in code comment.
- Part B: `reorderForSingleSelect` places `CanonicalFolder.inbox` first, `CanonicalFolder.trash` second, rest alphabetical. Used only in `singleSelect: true` mode. Multi-select mode unchanged.
- Part C: `enough_mail` v2.1.7 `Mailbox.pathSeparator` populated live from IMAP LIST response. No new dependency. No custom IMAP parsing.
- Suite delta: 1612 pass -> 1631 pass (+19)
- `flutter analyze`: 0 issues
- Wall-clock: ~35 min (within 40-60 min estimate)
- Class-2 decisions: FolderInfo extension (pre-authorized); ExpansionTile choice (pre-authorized); parent expand-only (implementation choice within ExpansionTile scope, not a Class-2 surfacing)

## Diff baselines for the 4.6 re-runs

To produce comparable 4.6 diffs:

1. For F25: fork from `develop` at the commit just before F25 productive run merged (after F78 + F75, before F25). Run F25 brief on 4.6. Capture diff.
2. For F35: fork from `develop` at the commit just before F35 merged (after F25, before F35). Run F35 brief on 4.6.
3. For F37: fork from `develop` at the commit just before F37 merged (after F35, before F37). Run F37 brief on 4.6.
4. For F78: fork from `develop` at the commit just before F78 productive run merged (Sprint 40 starting commit, after Sprint 39 merge). Run F78 brief on 4.6.

The Sprint 40 PR (when it lands) will contain commits in execution order: F78 -> F75 -> F25 -> F35 -> F37 -> F79 -> S38-CI-7 prep. Use the merge commit's parent and bisect to the per-task commit boundary.

## Scoring rubric (1-5 per dimension, per task, per model)

- **5 = exemplary**: zero deviations; production-grade output without prompting
- **4 = strong**: minor deviations on judgment calls; output ships as-is
- **3 = acceptable**: 1-2 corrections needed; output ships after small fixes
- **2 = weak**: multiple rounds; meaningful rework required
- **1 = poor**: missed core requirements; output not usable without major rework

Dimensions:
1. Sprint-execution-doc process adherence (phase gates, checklist, decision-class taxonomy)
2. Instruction-following (CLAUDE.md style, brief acceptance criteria adherence)
3. Architecture discipline (Class-1/2 deviations; ADR respect; reuse vs duplicate)
4. Stopping-criteria adherence (SPRINT_STOPPING_CRITERIA.md; no over/under-stop)
5. Code quality (12-month forward lens per `feedback_12_month_code_lens.md`)

Comparison matrix template (fill in `docs/sprints/SPRINT_40_RETROSPECTIVE.md`):

```
| Task | Dim 1 (process) | Dim 2 (instr) | Dim 3 (arch) | Dim 4 (stop) | Dim 5 (quality) |
|------|-----------------|---------------|--------------|--------------|-----------------|
| F78  | 4.6: __  4.7: __ | 4.6: __  4.7: __ | 4.6: __  4.7: __ | 4.6: __  4.7: __ | 4.6: __  4.7: __ |
| F25  | (same)           | (same)        | (same)       | (same)       | (same)          |
| F35  | (same)           | (same)        | (same)       | (same)       | (same)          |
| F37  | (same)           | (same)        | (same)       | (same)       | (same)          |
```

Narrative section after the matrix: per-dimension observations, surprise findings, model-assignment recommendations for future sprints.
