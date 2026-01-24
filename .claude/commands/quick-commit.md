---
description: "Stage all changes and commit with a descriptive message"
---

For spamfilter-multi, follow these steps for a quick commit:

1. **Review state**: Run `git status` and `git diff` to understand changes

2. **Verify quality**:
   - Run `flutter analyze` (must have 0 issues)
   - Run `flutter test` (must pass all tests)

3. **Stage all changes**: `git add -A` (only after verifying changes are correct)

4. **Create commit** with conventional format:
   - **Format**: `type: Description of change (Issue #N)`
   - **Types**: `feat:` (feature), `fix:` (bug), `refactor:` (structure), `docs:` (docs), `test:` (tests), `chore:` (maintenance)
   - **Mood**: Use imperative ("Add feature" not "Added feature")
   - **No contractions**: "Do not" not "Don't", "cannot" not "can't"
   - **Reference issue**: Include issue number if applicable

**Examples**:
- `feat: Add DKIM validation to RuleEvaluator (Issue #51)`
- `fix: Correct rule name display on Results screen`
- `test: Add comprehensive tests for folder discovery`
- `docs: Update sprint planning guide with examples`

**Note**: Use `/commit` skill (Skill tool) to automatically stage and commit with Co-Authored-By line.
