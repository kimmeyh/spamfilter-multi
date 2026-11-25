# Sprint 86 Plan

### Task 1 -- Port two scripts

**Port of existing code**: original `scripts/old-tool.ps1` reviewed for defects FIRST: old-tool.ps1:42 swallowed a failed git call (fixed in the port).
- Error paths: git failure prints "[ERROR] git log failed" and exits 1; real failing command tested in: `test_missing_git_exits_1`
- Gates by file type: version sweep includes `.py`: yes
<!-- guidance in a comment never counts as a result: <each defect> -->

**Old name search**: `old-tool.ps1` -- hits: docs/TESTING_STRATEGY.md:120 updated; docs/adr/0017-tooling.md:33 dated note naming the port.

**Executed-by**: Sonnet agent + lead -- 30 min (task clock 2026-11-24 01:00 to 2026-11-24 01:30, 2 segment(s))

### Task 2 -- Rename a screen

**Port of existing code**: N/A -- not a port.

**Old name search**: `OldScreen` -- none found outside the renamed file.

**Executed-by**: Haiku agent -- 12 min (task clock 2026-11-24 02:00 to 2026-11-24 02:12, 1 segment(s))

## Phase 5 evidence

- **5.1.2 F-PRECHECK**: all classes ran, clean.
- **5.1.5 WinWright sweep**: 2026-11-28, 3 scripts, 3/3 PASS.
  - sweep-head: 0123abc
- **5.1.9 MV rehearsal**: 2026-11-28, every step rehearsed on the DEV build.

## Phase 7 evidence

- **7.7.1 final code reviews**: 2026-11-30, Copilot Findings None; code-reviewer + silent-failure-hunter 0 HIGH; improvement review: 0 findings.
