# F35 Eval Brief (Sprint 40 Task 4, S38-CI-7 eval subject)

**Productive run model**: Sonnet
**Eval re-run model**: Opus 4.6 (this brief)
**Branch for eval**: `feature/20260525_Sprint_40_F35-opus46`

---

You are executing Sprint 40 Task 4 (F35) on this repo: `D:\Data\Harold\github\spamfilter-multi`.

## Task

Add a **rule editing UI** so users can edit existing rules from the Manage Rules screen, reusing the regex-generation building blocks. F25 (just completed) extracted the pattern generators into `mobile-app/lib/core/utils/manual_rule_pattern_generator.dart` -- USE that utility, do not duplicate it.

## Acceptance Criteria

- [ ] Edit existing rule from Manage Rules via a new "Edit" button/menu-item per rule. Most natural placement: alongside the existing "Test" / "Disable/Enable" / "Delete" buttons in the `_showRuleDetails` AlertDialog at `mobile-app/lib/ui/screens/rules_management_screen.dart:255-340`.
- [ ] Edit dialog/screen supports:
  - Plaintext-to-regex generation (reuse `ManualRulePatternGenerator.generateFromPlaintext` or per-type generators)
  - Direct-regex editing with validation (reuse `PatternCompiler` / `DomainValidation` for ReDoS + IANA checks)
  - Pattern preview (show what the final regex looks like, like `ManualRuleCreateScreen` does)
  - Metadata field editing -- at minimum: enabled flag, executionOrder, action (delete/move-to-folder/move-to-trash), conditionType (from/subject/body/header). Do NOT expose `name` for edit if it serves as DB primary identifier; do expose user-facing display fields.
- [ ] On Save: persist via `RuleSetProvider.updateRule()` (or the equivalent existing update method -- read `mobile-app/lib/core/state/rule_set_provider.dart` to find the right method; if no update method exists, add one that wraps the existing addRule + delete-old or a true UPDATE, with the same UNIQUE-violation rethrow semantics established by BUG-S39-2).
- [ ] Refresh Manage Rules list after Save so the user sees the change.

## Architectural decisions you may make WITHOUT re-asking

These are pre-authorized by the task brief and the Sprint 40 plan:
- Extract more shared UI building blocks from `ManualRuleCreateScreen` if needed for the edit dialog (e.g., the radio-rule-type widget, the input + preview widget). Place extracted widgets under `mobile-app/lib/ui/widgets/rule_form/` (new directory) and update both create-screen and new edit-screen to use them.
- Add a `RuleSetProvider.updateRule(...)` method if one does not exist. Mirror `addRule`'s UNIQUE-violation rethrow per `feedback_decision_class_taxonomy.md` (do not silently swallow).
- Choose between (a) an in-place edit dialog and (b) a full `RuleEditScreen` reusing `ManualRuleCreateScreen` infrastructure. **Recommendation**: (b) -- create a new `RuleEditScreen` that mirrors `ManualRuleCreateScreen`'s structure but pre-populates from an existing rule and calls update instead of insert. This keeps the dialog clean and matches how F25's "Test" button works (Navigator.push to RuleTestScreen).

## Decisions that DO require surfacing (do NOT proceed; STOP and report)

- Any change to the underlying DB schema (Class-1 architecture).
- Any change to the rule-evaluation semantics or rule-ordering rules (Class-1/2).
- Any restructure of `RuleSetProvider` beyond adding `updateRule`.

## Critical context

- **Current state (verified 2026-05-25 master plan)**: PARTIAL -- `ManualRuleCreateScreen` exists with create-only flow; pattern_generation building blocks exist; edit UI NOT DONE. F25 added the `ManualRulePatternGenerator` utility today.
- **Sprint 39 BUG-S39-2 lesson**: `RuleSetProvider.addRule` was silently swallowing UNIQUE-violation; it was fixed to rethrow. Apply the same rethrow discipline to `updateRule`.
- **F25's "Test" button placement** in `_showRuleDetails` at lines 320-327 is the template -- add an "Edit" `OutlinedButton.icon(icon: Icons.edit, label: 'Edit')` immediately next to it.

## Reference

- Read first: `mobile-app/lib/ui/screens/manual_rule_create_screen.dart` (the create flow; understand what to mirror in edit)
- Read first: `mobile-app/lib/ui/screens/rules_management_screen.dart` lines 255-340 (the dialog where the Edit button goes)
- Read first: `mobile-app/lib/core/utils/manual_rule_pattern_generator.dart` (F25's new utility; use it)
- Read first: `mobile-app/lib/core/state/rule_set_provider.dart` (look for addRule / updateRule / delete; understand UNIQUE-violation handling)
- Read first: `mobile-app/lib/core/models/rule.dart` (Rule model fields you may need to edit)

## Constraints

- Estimate: **30-50 min** (UI-NEW ~18min n=1; PARTIAL groundwork lowers risk; full edit flow is larger than F25's three small wirings).
- All new code MUST have unit + widget test coverage. Tests under `mobile-app/test/`.
- `flutter analyze` MUST be clean (0 issues).
- Full suite MUST stay green. Currently 1588 pass / 28 skip / 0 fail; your additions should add ~10-15 tests and not regress any.
- Do NOT use emojis. Do NOT use contractions (CLAUDE.md style).
- Use `Logger` not `print()` for production logging.
- Do NOT commit. Leave changes staged.

## Workflow

1. Read the 5 reference files.
2. Check whether `RuleSetProvider` has an `updateRule` method already (it may not).
3. Decide: in-place dialog vs full RuleEditScreen. Recommended is RuleEditScreen.
4. If extracting shared widgets, do that first under `lib/ui/widgets/rule_form/`.
5. Implement RuleEditScreen + updateRule provider method.
6. Wire the "Edit" button into `_showRuleDetails` next to the "Test" button (lines 320-327 template).
7. Add tests: unit tests for `updateRule` (success + UNIQUE rethrow), widget tests for RuleEditScreen (pre-population + Save + validation).
8. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter test`
9. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter analyze`
10. Fix anything red before reporting done.

## Output report

- Approach chosen: in-place dialog vs RuleEditScreen + rationale
- Any widgets extracted to `lib/ui/widgets/rule_form/` + rationale
- `RuleSetProvider` changes: new method signature(s) + UNIQUE handling confirmation
- Tests added: count + names
- Full-suite count (was 1588 pass; target 1600+)
- `flutter analyze` result
- Wall-clock minutes spent
- Any Class-1/2/3 decisions you encountered + how you handled them (the task brief says you may extract shared widgets and add updateRule without re-asking; anything BEYOND that requires you to STOP and report)

Note: this task is also an S38-CI-7 EVAL SUBJECT. Opus 4.6 will re-run this IDENTICAL brief on a separate branch later. Your output (process adherence, instruction-following, architecture discipline, stopping-criteria, code quality) is being scored against 4.6's. Be deliberate and document your decisions.

---

## Eval-only note

For the 4.6 re-run, branch should fork from `develop` AT THE COMMIT immediately preceding the F35 productive run landing -- so the 4.6 run sees `ManualRulePatternGenerator` (from F25) as available but NOT `RuleEditScreen` (which F35 introduces). Use `git log --oneline` to identify the right starting commit.
