# Sprint 21 Summary

**Sprint**: Sprint 21 - Production/Development Side-by-Side Builds (ADR-0035)
**Date**: March 18, 2026
**Branch**: `feature/20260318_Sprint_21`
**PR**: [#190](https://github.com/kimmeyh/spamfilter-multi/pull/190)
**Status**: [OK] Complete

---

## Sprint Objective

Implement ADR-0035: environment-aware app identity so production and development builds coexist on the same Windows machine.

## Tasks Completed

| Task | Feature |
|------|---------|
| A | Version bump to 0.5.1, secrets.prod.json template |
| B | AppEnvironment class, environment-aware AppPaths, UI indicators |
| C | First-run dev environment seeded from production DB |
| D | build-windows.ps1 -Environment parameter |
| E | Single-instance mutex per executable path |
| F | Documentation updates |

## Key Deliverables

- Separate data directories: MyEmailSpamFilter (prod) vs MyEmailSpamFilter_Dev (dev)
- Window title shows [DEV] for dev builds
- Separate Task Scheduler tasks per environment
- Dev environment auto-seeded from production data on first launch
- Single-instance mutex prevents duplicate same-environment instances
- ADR-0004 superseded (dual-write removed)

## Metrics

| Metric | Value |
|--------|-------|
| Commits | 10 |
| Tests | 1141 |
| Analyzer issues | 0 |
| Testing feedback fixes | 1 (window title) |
| Backlog items added | 2 (#14, #15) |
