---
description: "Run tests and fix any failures"
---

For spamfilter-multi, follow this process to run and fix tests:

1. **Run full test suite**:
   ```powershell
   cd mobile-app
   flutter test
   ```
   - Expected: 138+ tests pass
   - Check for: Test failures, timeouts, or flaky tests

2. **If all tests pass**:
   - Report success ✅
   - Optional: Run `flutter analyze` to check for warnings
   - Ready to commit or review

3. **If tests fail**:
   - **Analyze each failure**:
     - What test is failing? (Get test name and file)
     - What is the error message? (Is it an assertion failure, timeout, build error?)
     - Is it a test issue or implementation issue?
     - Does it relate to recent changes or pre-existing?
   - **Fix the issue**:
     - If test is incorrect: Fix the test (rare)
     - If implementation is wrong: Fix the code being tested (common)
     - Identify the root cause before fixing (what went wrong?)
   - **Re-run tests**: `flutter test`
   - **Verify fix**: Confirm the same test now passes
   - **Repeat**: Move to next failing test

4. **Specific test run** (after fixing, to verify quickly):
   ```powershell
   flutter test test/unit/rule_evaluator_test.dart  # Run specific file
   flutter test -k "test_spam_rule"                 # Run tests matching pattern
   ```

5. **Debug failing tests**:
   - Add debug logging to understand test flow
   - Run with verbose output: `flutter test --verbose`
   - Check test file for setup/teardown issues
   - Verify mock data is correct

6. **Report when complete**:
   - All tests pass: `flutter test` (138+ tests) ✅
   - No analysis warnings: `flutter analyze` (0 issues) ✅
   - Ready for commit

**Methodology**: Be systematic - fix one test at a time, verify it passes, then move to next. Do not try to fix multiple tests simultaneously.
