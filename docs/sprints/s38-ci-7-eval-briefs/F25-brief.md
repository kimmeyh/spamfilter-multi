# F25 Eval Brief (Sprint 40 Task 3, S38-CI-7 eval subject)

**Productive run model**: Sonnet
**Eval re-run model**: Opus 4.6 (this brief)
**Branch for eval**: `feature/20260525_Sprint_40_F25-opus46`

---

You are executing Sprint 40 Task 3 (F25) on this repo: `D:\Data\Harold\github\spamfilter-multi`.

## Task

Add 3 sub-features to the Rule Testing screen at `mobile-app/lib/ui/screens/rule_test_screen.dart` (505 lines). The screen is reachable from Settings > Tools > Test Rule Pattern, Rule Quick Add, and Manage Rules.

## Acceptance Criteria

- [ ] **Sub-feature 1** -- pre-populate match-against list from **Demo Scan data when no real-scan data is available** (so a brand-new user can test rules immediately). Currently `_loadSampleEmails` (line 62) pulls the 3 most recent scans of any type; if the result is empty, run/load a demo scan dataset and use that instead. Confirm the exact mechanism by reading `email_scanner.dart` + `mock_email_data.dart` first.

- [ ] **Sub-feature 2** -- plaintext-to-regex conversion on Test. When the user enters a plain string (e.g., `example.com`, `spam@example.com`, `.xyz`) and clicks Test, auto-detect the pattern type and generate the regex (reuse the ManualRuleCreateScreen generators), then run the test using that regex. Add a small UI affordance: a checkbox or icon button "Treat input as plain text (auto-regex)", and surface the generated regex back to the user (small label below the input so they see what was generated).

- [ ] **Sub-feature 3** -- "Open in test tool" action from Manage Rules. In `mobile-app/lib/ui/screens/rules_management_screen.dart` (979 lines), add a button/menu-item per-rule that navigates to RuleTestScreen with `initialPattern` + `initialConditionType` pre-filled from the selected rule's first condition. RuleTestScreen already accepts these params (lines 17-26) so wiring is mostly on the Manage Rules side.

## Critical context

- **Pattern generation source of truth**: `manual_rule_create_screen.dart` (~830 lines) contains the plaintext-to-regex generators for TLD / EntireDomain / ExactDomain / ExactEmail (private methods). If they are private, EXTRACT them into a new public utility at `mobile-app/lib/core/utils/manual_rule_pattern_generator.dart` (or similar) so both ManualRuleCreateScreen and RuleTestScreen (and future F35) can reuse them. The extraction is a Class-2 (development) decision EXCEPT that the plan EXPLICITLY pre-authorizes this reuse: "Three small wirings reusing existing regex-gen + test infra." So extraction-for-reuse is in-scope -- do it cleanly, do not duplicate.
- **Existing RuleTestScreen has `initialPattern` + `initialConditionType` constructor params already (lines 17-26).** Sub-feature 3 only needs the call site in Manage Rules.

## Reference

- Read first: `mobile-app/lib/ui/screens/rule_test_screen.dart` (full)
- Read first: `mobile-app/lib/ui/screens/manual_rule_create_screen.dart` (find the pattern-generation private methods; classify what to extract)
- Read first: `mobile-app/lib/ui/screens/rules_management_screen.dart` (find the per-rule row/card and existing per-rule actions; add the new action consistently)
- Read first: `mobile-app/lib/core/services/email_scanner.dart` line 108 (`isLiveScan` -- demo discriminator is `platformId == 'demo'`)
- Read first: `mobile-app/lib/core/services/mock_email_data.dart` (demo dataset structure)

## Constraints

- Estimate: **30-45 min** (UI-NEW ~18min + SVC-EDIT ~5min, three small wirings per `docs/CODING_VELOCITY.md`).
- All new code MUST have unit + widget test coverage. Test files live under `mobile-app/test/`.
- `flutter analyze` MUST be clean (0 issues).
- Full suite MUST stay green. As of F75 commit it is 1541 pass / 28 skip / 0 fail; your additions should add ~5-10 tests and not regress any.
- Do NOT use emojis. Do NOT use contractions (CLAUDE.md style).
- Use `Logger` not `print()` for any production logging.
- Do NOT modify the screen file's existing behavior; ADD the 3 sub-features.
- Do NOT commit. Leave changes staged.

## Workflow

1. Read the four reference files above.
2. Decide whether the pattern generators in manual_rule_create_screen.dart need extraction (public utility) or can stay private (e.g., if RuleTestScreen can call them via a single new public method on ManualRuleCreateScreen). Document the decision briefly in the report.
3. Implement Sub-feature 1 (Demo fallback in `_loadSampleEmails`).
4. Implement Sub-feature 2 (plaintext->regex conversion + generated-regex surfaced to user).
5. Implement Sub-feature 3 (Open-in-test-tool action in Manage Rules).
6. Add tests covering each sub-feature.
7. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter test`
8. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter analyze`
9. If any test fails OR analyze reports issues, FIX before reporting done.

## Output report

- Sub-feature 1: status + brief approach
- Sub-feature 2: status + UX affordance chosen + whether you extracted generators (and to where)
- Sub-feature 3: status + where you placed the action in Manage Rules
- Tests added: count + names
- Full-suite count (was 1541 pass, target 1545+)
- `flutter analyze` result
- Wall-clock minutes spent
- Any decisions deferred / questions for Harold

Note: this task is also an S38-CI-7 EVAL SUBJECT, meaning Opus 4.6 will re-run the IDENTICAL brief on a separate branch later for the head-to-head. Your output quality matters for the comparison rubric (process adherence / instruction-following / architecture discipline / stopping-criteria / code quality). Be deliberate.

---

## Eval-only note

The note above ("Opus 4.6 will re-run this IDENTICAL brief later") is now this re-run. The branch starting state for the 4.6 re-run should be `develop` AT THE COMMIT JUST BEFORE Sprint 40's F25 productive run landed -- so the 4.6 run sees the SAME starting code as the 4.7 productive run (no F25/F35/F37 already-merged work). Use `git log` on `develop` to find that commit.
