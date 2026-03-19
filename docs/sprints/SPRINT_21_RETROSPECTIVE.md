# Sprint 21 Retrospective

**Sprint**: Sprint 21 - Production/Development Side-by-Side Builds (ADR-0035)
**Date**: March 18, 2026
**Branch**: `feature/20260318_Sprint_21`
**PR**: [#190](https://github.com/kimmeyh/spamfilter-multi/pull/190)

---

## Sprint Summary

Sprint 21 implemented ADR-0035: environment-aware app identity enabling production and development builds to coexist on the same Windows machine. All 6 planned tasks completed plus 1 testing feedback fix.

### Tasks Completed

| Task | Feature | Status |
|------|---------|--------|
| A | Version bump to 0.5.1, secrets.prod.json template | [OK] Complete |
| B | AppEnvironment class, environment-aware AppPaths, UI indicators | [OK] Complete |
| C | First-run dev environment seeding from production DB | [OK] Complete |
| D | build-windows.ps1 -Environment parameter | [OK] Complete |
| E | Single-instance mutex per executable path | [OK] Complete |
| F | Documentation updates (CLAUDE.md, CHANGELOG.md) | [OK] Complete |

### Testing Feedback Fix
- Window title bar: C++ main.cpp now parses APP_ENV from command line for Win32 window title

### Phase 5 Documentation Review
- ARCHITECTURE.md: dual-write references updated to database-only
- QUICK_REFERENCE.md: secrets.prod.json, -Environment param, dev paths added
- ADR-0004: Status changed to Superseded
- ADR-0009: Dual-write references removed

---

## What Went Well

1. **ADR-first approach**: ADR-0035 was designed in Sprint 20 with thorough user input (version strategy, secrets, seeding, users). Implementation in Sprint 21 was straightforward with minimal rework.

2. **Well-scoped sprint**: Single ADR, single issue (#189), clear phase-based task breakdown. Estimated 6-8h, actual ~6h.

3. **Phase 5 docs review**: User's suggestion to review all docs/ files caught 4 MUST-FIX items that would have been missed.

4. **Comprehensive testing**: Manual test checklist covered all new functionality. Window title bug found and fixed immediately.

---

## What Could Be Improved

1. **Platform-specific behavior awareness**: The Win32 window title is not controlled by Flutter's `MaterialApp.title`. This platform-specific behavior was not obvious from Dart code review. Added checklist item to SPRINT_CHECKLIST.md.

---

## Metrics

| Metric | Value |
|--------|-------|
| Tasks planned | 6 |
| Tasks completed | 6 |
| Testing feedback fixes | 1 |
| Tests | 1141 (unchanged) |
| Analyzer issues | 0 |
| Commits | 9 |
| Backlog items added | 2 (#14, #15) |

---

## Improvements Implemented

1. **Platform-specific UI checklist item**: Added to SPRINT_CHECKLIST.md Phase 5 -- verify platform-level UI behavior (Win32 window title, system tray, notifications) separately from Flutter UI layer.

2. **ADR-first approach documentation**: Added to SPRINT_PLANNING.md -- for major architectural changes, design the ADR first, get user approval, then implement.

---

## Next Sprint Candidates

Refer to `docs/ALL_SPRINTS_MASTER_PLAN.md` for the prioritized backlog.
