---
description: "Commit, push, and open a PR"
---

Follow these steps in order for the spamfilter-multi project:

1. **Review changes**: Run `git status` and `git diff` to see what files have changed

2. **Verify project standards**:
   - Run `flutter analyze` (must report 0 issues)
   - Run `flutter test` (all 138+ tests must pass)
   - Ensure code follows CLAUDE.md standards (no contractions, use Logger not print)

3. **Stage files**: Run `git add` for appropriate files (or `git add -A` if all changes are valid)

4. **Create commit**: Use conventional commits format following CHANGELOG.md conventions:
   - Type: `feat:` (feature), `fix:` (bug fix), `docs:` (documentation), `test:` (test changes), `chore:` (maintenance)
   - Example: `feat: Add DKIM validation for Gmail OAuth emails`
   - Remember: No contractions in commit messages

5. **Push to remote**: Use `git push -u origin <branch>` to create remote branch if needed

6. **Create Pull Request**:
   ```bash
   gh pr create --base develop --title "[Your PR title]" --body "[Description]"
   ```
   - Target base: `develop` (for integration), then merge to `main` for releases
   - Include in PR description:
     - **What changed**: Summary of modifications
     - **Why**: Business value or bug being fixed (reference issue #N)
     - **Testing**: What was tested (flutter test results, manual testing on platforms)
     - **Notes for reviewers**: Any concerns, breaking changes, or platform-specific details

7. **Link to issues**: Reference GitHub issue in PR description using `Fixes #51` or `Related to #45`

If there are any issues at any step, stop and report them. Do not force push unless explicitly requested.
