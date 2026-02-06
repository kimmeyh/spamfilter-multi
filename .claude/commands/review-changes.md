---
description: "Review uncommitted changes and suggest improvements"
---

For spamfilter-multi, follow this comprehensive review process:

1. **See changes**: Run `git status` and `git diff` to understand modifications

2. **Analyze each file** for correctness and quality:
   - **Correctness**: Is the logic sound? Does it solve the stated problem?
   - **Bugs**: Any potential null pointer exceptions, off-by-one errors, race conditions?
   - **Convention**: Follows CLAUDE.md standards (no contractions, Logger vs print, code style)?
   - **Security**: Any SQL injection, XSS, insecure credential handling, or OAuth token exposure?
   - **Error handling**: Appropriate try-catch? User feedback for failures? Graceful degradation?
   - **Performance**: Any N+1 queries, unnecessary rebuilds, blocking operations on main thread?
   - **Tests**: Added tests for new logic? Existing tests still pass?
   - **Cross-platform**: If multi-platform change (Windows, Android), verified on both?
   - **Email providers**: If provider-specific (Gmail, AOL), works with multiple adapters?

3. **Run automated checks**:
   ```powershell
   cd mobile-app
   flutter analyze        # Must have 0 issues
   flutter test          # Must pass all 138+ tests
   dart format --line-length=100 --check lib/
   ```

4. **Provide summary**:
   - **✅ Looks good**: What works well (clear logic, good error handling, solid tests)
   - **⚠️ Concerns**: Issues that need fixing before commit (bugs, missing tests, style violations)
   - **💡 Suggestions**: Improvements for future work (not blockers)
   - **📝 Next steps**: Recommended action (fix issues, add tests, commit, or request changes)

5. **Report detail level**:
   - Minor issues: Note and allow commit if non-critical
   - Major issues: Block commit until fixed
   - Block: Bugs, security issues, test failures, style violations
