# F78 Eval Brief (Sprint 40 Task 1, S38-CI-7 eval subject)

**Productive run model**: Haiku (per Sprint 40 plan)
**Eval re-run model**: Opus 4.6 (this brief)
**Branch for eval**: `feature/20260525_Sprint_40_F78-opus46`

---

You are executing Sprint 40 Task 1 (F78) on this repo: `D:\Data\Harold\github\spamfilter-multi`.

## Task

Add `testWidgets` coverage to `mobile-app/test/ui/screens/manual_rule_create_screen_test.dart` for the `ManualRuleCreateScreen` (file: `mobile-app/lib/ui/screens/manual_rule_create_screen.dart`, 830 lines).

The existing 185-line test file is **unit-only** (no `testWidgets`, no `pumpWidget`, no `WidgetTester`). Do NOT delete existing unit tests -- ADD widget tests in a new top-level `group()` at the end of the file (before the closing `}` of `main()`).

## Four coverage areas required (acceptance criteria)

1. **Radio selection** -- `RadioListTile<ManualRuleType>` around lines 644-660 of the screen. Verify tapping a different radio updates the selected rule type and the displayed pattern preview reflects the new type.

2. **Input-field validation feedback** -- enter invalid input (e.g., empty, malformed for the selected type), confirm validation error text appears.

3. **Pattern preview rendering** -- around lines 575-585 of the screen. Verify the preview text updates as the user types into the input field.

4. **Confirmation dialog** -- `AlertDialog` around lines 566-609. Verify tapping the save button opens the confirmation dialog with the expected pattern + metadata shown, and Cancel/Confirm buttons behave correctly.

## Reference patterns to MIRROR (per `feedback_mirror_working_code.md`)

- **sqflite_ffi `runAsync` workaround** (handles the sqflite-ffi hang seen Sprint 39): see `mobile-app/test/ui/screens/results_display_no_rule_reload_test.dart` -- the ONLY existing test using `runAsync`. Mirror its setup if the screen needs DB access during pumpWidget.
- **Close-cousin widget test for sibling rule-creation screen**: `mobile-app/test/ui/screens/rule_quick_add_screen_test.dart` -- mirror its `testWidgets` patterns, Provider/mock setup, and AlertDialog interaction patterns.

## Constraints

- Estimate: **25-40 min** of wall-clock coding. Per `docs/CODING_VELOCITY.md`, no Sprint 39 task exceeded 20 min; if you find yourself spending >40 min, STOP and report what is blocking you.
- All new tests MUST pass. Existing 185-line unit suite MUST continue to pass.
- `flutter analyze` MUST be clean (0 issues) after your changes.
- Do NOT use emojis; do NOT use contractions in comments (CLAUDE.md style).
- Use `Logger` not `print()` if any logging needed in test setup helpers (production rule does not apply to test files, but stay consistent).
- Do NOT modify the screen file `manual_rule_create_screen.dart` -- tests only.

## Workflow

1. Read the existing test file fully.
2. Read the sibling `rule_quick_add_screen_test.dart` for the working widget-test pattern.
3. Read the relevant sections of `manual_rule_create_screen.dart` (lines ~560-660, plus any helper methods the widget tests need to invoke).
4. Read `results_display_no_rule_reload_test.dart` ONLY if your tests trigger sqflite-ffi (most ManualRuleCreateScreen interactions do not -- prefer mocking).
5. Add a new group `group('F78 ManualRuleCreateScreen widget rendering', () { ... })` at end of `main()` with 4+ `testWidgets` cases (one per coverage area).
6. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter test test/ui/screens/manual_rule_create_screen_test.dart`
7. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter analyze test/ui/screens/manual_rule_create_screen_test.dart`
8. If both green, run the FULL suite to confirm no regression: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter test` (it should show ~1530+ passing, 28 skipped, 0 failed -- a +4 or so from your new tests).

## Output

Report back:
- Number of new `testWidgets` cases added
- Final test counts (your-file passing, full-suite passing)
- `flutter analyze` result
- Wall-clock minutes spent (start to tests-green/analyze-clean)
- Any blockers or deviations from the plan
- Do NOT commit. Leave changes staged for the parent to review.

You are on Haiku, not Opus. Be efficient. The minute-based estimates assume tight, focused execution -- match the pattern, ship the tests, report.

---

## Eval-only note (NOT in original brief; for the 4.6 re-run only)

The original productive brief told the model "You are on Haiku, not Opus." For the 4.6 eval, you ARE on Opus 4.6 -- that sentence is the only deliberate model-context lie in the briefs (it was true at productive-run time). Do not let that line change your behavior; behave as Opus 4.6 normally would. The eval is scoring HOW the model approaches the brief, not whether it correctly identifies its own model.
