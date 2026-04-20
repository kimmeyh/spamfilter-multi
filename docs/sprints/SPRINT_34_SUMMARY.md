# Sprint 34 Summary: Rule Management Foundation + UI Standards

**Sprint**: 34
**Dates**: April 17-18, 2026
**Branch**: `feature/20260417_Sprint_34`
**PR**: TBD (to be created in Phase 6)
**Issue**: #235

---

## Objective

Fix the broken rule data layer (F73), build the manual rule creation UI (F56), establish UI/accessibility standards (ADR-0037), validate with WinWright E2E test infrastructure (F69), and clean up tech debt (F62, F72). Together these prepare the app for the next Windows Store submission with a solid manual rule management foundation.

## Deliverables

**Rule data layer (F73)**:
- Part A: `splitMonolithicRules()` startup migration -- detects remaining monolithic rules and splits to individual per-pattern rows with classification metadata
- Part B: Bundled `rules.yaml` rebuilt from 5 monolithic blobs to 1,638 individual per-pattern entries (header_from only, per user constraint)
- Part C: `ensureTldBlockRules()` rewritten for individual-row insertion with backwards-compat detection
- New helper: `scripts/rebuild_rules_yaml.py` for future YAML refreshes

**Manual rule creation (F56)**:
- New `ManualRuleCreateScreen` with guided form for block rules (4 types) and safe sender rules (3 types)
- Input parsing: bare email, bare domain, URL with protocol, URL with path
- Pattern preview with live generation and ReDoS validation (SEC-1b)
- Confirmation dialog showing generated regex before save
- Inline `+` icon next to row count on Manage Rules and Manage Safe Senders (replaces FAB after testing feedback)
- New `DomainValidation` utility class with RFC-compliant rules + IANA TLD allowlist (~1436 entries)
- 19 unit tests for pattern generation + 31 unit tests for domain validation

**UI/Accessibility standards (ADR-0037)**:
- WCAG 2.1 AA target documented
- Semantics labeling strategy for screen readers + WinWright testability
- SelectionArea/SelectableText standard for copyable text
- YAML round-trip invariant formalized (patternCategory/patternSubType/sourceDomain must survive)
- Cross-platform UI standards (Material 3, adaptive breakpoints, 48dp touch targets)
- ARSD AR-8 (accessibility) and AR-9 (YAML round-trip) requirements added
- ARCHITECTURE.md UI Standards quick-reference table
- QUALITY_STANDARDS.md accessibility quality gate with checklist

**WinWright E2E tests (F69)**:
- 7 JSON test scripts (navigation, settings tabs, manual scan, scan history, text selection, F56 block rule creation, F56 safe sender creation)
- `run-winwright-tests.ps1` PowerShell runner with auto SPI_SETSCREENREADER setup
- README documenting prerequisites and selector patterns
- TESTING_STRATEGY.md updated with new script index

**Tech debt cleanup**:
- F62: Removed deprecated `lib/config/app_paths.dart`, duplicate `lib/core/storage/local_rule_store.dart`; moved legacy OAuth screens to `lib/ui/screens/`
- F72: Removed 9 emojis from production code, added `if(MSVC)` guard in CMakeLists.txt, SEC-20 generic email validation messages

**Backlog additions (HOLD)**:
- F74: FAQ section in Help (TLD/IANA explanations)
- F75: Help walkthrough -- end-to-end first-use guide

## Metrics

| Metric | Sprint 33 | Sprint 34 | Delta |
|--------|-----------|-----------|-------|
| Tests passing | 1313 | 1362 | +49 |
| Analyzer issues | 0 | 0 | -- |
| Tasks completed | 12 + 4 UX rounds | 6 + 2 testing rounds | -- |
| Commits | 10 | 13 | +3 |
| New files | 14 | 12 | -2 |
| Days | 3 | 2 | -1 |
| Skipped tests | 28 | 28 | -- |

## Key Lessons

1. **Sprint plan approval covers all tasks** -- Claude paused twice for "should I continue?" mid-sprint despite memory entries. Hookify rule (F77 candidate) needed to enforce.
2. **WinWright tests verify presence, not visual layout** -- alignment bugs slip through. Visual regression testing is a separate concern (F76 candidate).
3. **Structural domain validation is not sufficient** -- `.com444` and `.whatevericanthinkof` exposed the gap. IANA TLD allowlist now enforced.
4. **Background agents work well for independent tech debt** -- F62 and F72 ran in parallel; both completed cleanly while main thread did ADR-0037.
5. **Opus 4.7 (1M context) shifts effort estimates 2-3x lower** -- 28-40h plan landed in ~12h actual.

## Recommended Carry-Outs to Backlog

- **F76**: Visual regression testing infrastructure (~6-10h, HOLD)
- **F77**: Hookify rule to block "want me to proceed?" patterns (~1h, HOLD or sprint-wrap)
- **F78**: Widget tests for ManualRuleCreateScreen rendering (~3-4h, HOLD)
