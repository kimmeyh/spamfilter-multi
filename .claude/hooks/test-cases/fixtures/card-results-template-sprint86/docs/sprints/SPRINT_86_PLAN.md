# Sprint 86 Plan

### Task 1 -- Port one script

**Port of existing code**: original `scripts/old-tool.ps1` reviewed for defects FIRST: old-tool.ps1:42 swallowed a failed git call (fixed in the port).
- Error paths: <each external call: what the port prints and returns when it fails> ; real failing command tested in: `<test name>`
- Gates by file type: none

**Old name search**: `old-tool.ps1` -- hits: docs/TESTING_STRATEGY.md:120 updated.

**Executed-by**: Sonnet agent ~20 min + lead ~10 = ~30 min

## Phase 5 evidence

- **5.1.2 F-PRECHECK**: all classes ran, clean.
- **5.1.5 WinWright sweep**: 2026-11-28, 3 scripts, 3/3 PASS.
  - sweep-head: 0123abc
- **5.1.9 MV rehearsal**: 2026-11-28, every step rehearsed on the DEV build.

## Phase 7 evidence

- **7.7.1 final code reviews**: 2026-11-30, Copilot Findings None; code-reviewer + silent-failure-hunter 0 HIGH; improvement review: 0 findings.
