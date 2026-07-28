---
name: full-test
description: Run all Flutter tests and analyze code quality for the mobile-app
allowed-tools: Bash
user-invocable: true
model: sonnet
---

# Full Test

Runs the complete test suite and code analysis for the Flutter application.

## Instructions

Execute Flutter tests followed by static analysis:

```powershell
cd mobile-app
flutter test --concurrency=4
flutter analyze
```

`--concurrency=4` is REQUIRED for full-suite runs (`docs/TESTING_STRATEGY.md` "Local Full-Suite
Concurrency Policy", Sprint 49 retro IMP-5): at the default concurrency this machine intermittently
drops test-isolate connections and reports phantom load failures that are not real regressions.
Targeted single-file runs (`flutter test test/unit/foo_test.dart`) do not need the flag.

## Expected Results

- All tests pass. The current baseline lives in `.claude/sprint_status.json` -> `test_metrics`
  (1,814 passing / 29 skipped / 0 failing as of Sprint 51, 2026-07-28). Compare against that file
  rather than a number written here -- a hardcoded floor silently passes while hundreds of tests
  are missing.
- Code analysis should report 0 issues

## When to Use

- Before creating a pull request
- After making significant code changes
- To verify the codebase is in a good state
