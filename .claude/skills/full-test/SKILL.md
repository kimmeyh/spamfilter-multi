---
name: full-test
description: Run all Flutter tests and analyze code quality for the mobile-app
allowed-tools: Bash
user-invocable: true
---

# Full Test

Runs the complete test suite and code analysis for the Flutter application.

## Instructions

Execute Flutter tests followed by static analysis:

```powershell
cd mobile-app
flutter test
flutter analyze
```

## Expected Results

- All 122+ tests should pass
- Code analysis should report 0 issues

## When to Use

- Before creating a pull request
- After making significant code changes
- To verify the codebase is in a good state
