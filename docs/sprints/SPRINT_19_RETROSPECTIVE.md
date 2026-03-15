# Sprint 19 Retrospective

**Sprint**: Sprint 19 - Dual-Auth, Import/Export, Branding, and UX Polish
**Date**: February 27 - March 15, 2026
**Branch**: `feature/20260227_Sprint_19`
**PR**: [#183](https://github.com/kimmeyh/spamfilter-multi/pull/183)

---

## Sprint Summary

Sprint 19 delivered 6 planned tasks spanning authentication, data management, branding, and UX polish, followed by 3 rounds of testing feedback fixes (13 additional items). All work completed with 1141 tests passing.

### Tasks Completed

| Task | Feature | Issue | Status |
|------|---------|-------|--------|
| A | Version Numbering (GP-15) | #181 | [OK] Complete |
| B | Application Identity (GP-1) | #182 | [OK] Complete |
| C | Folder Selection UX (F27) | #172 | [OK] Complete |
| D | Safe Senders Filter Chips (F26) | #180 | [OK] Complete |
| E | YAML Import/Export UI (F22) | #179 | [OK] Complete |
| F | Gmail Dual-Auth (F12B) | #178 | [OK] Complete |

### Testing Feedback Fixes (3 Rounds)

**Round 1** (Feb 28):
- About section in Settings showing app version 0.5.0 (#181)
- Background scan worker log path updated for MyEmailSpamFilter directory (#182)
- Demo Mode changed from toggle switch to direct-launch card
- Scan History: 12-hour AM/PM format with timezone abbreviation
- Scan History: Always show all 7 count metrics

**Round 2** (Mar 14):
- Safe Senders YAML export crash fix - AppPaths not initialized (#179)
- Convert bare domain safe sender pattern to proper Entire Domain regex
- Gmail auth: App Password listed first as Recommended (#178)
- App Password instructions: selectable text, tappable URLs, updated steps (#178)
- Scan Results Summary shows folder names on scan start
- Live re-evaluation of No Rule emails after adding rule or safe sender
- Round-trip regex validation tests for YAML export/import

**Round 3** (Mar 14):
- Folder display using correct account (getSelectedFoldersForAccount)
- Scan History filters by account instead of showing all accounts

### Test Growth

- Sprint start: 1088 tests (from previous sprint + hotfix)
- After initial development: 1133 tests (+45 new tests)
  - Task D: +20 tests (SafeSenderCategory categorization)
  - Task E: +6 tests (YAML round-trip integration)
  - Task F: +19 tests (Gmail dual-auth routing)
- After testing feedback: 1141 tests (+8 additional tests)
  - Round-trip regex validation tests for YAML export/import
- **Total growth**: +53 tests

---

## What Went Well

1. **Continuous autonomous execution**: All 6 tasks completed without stopping for approvals, following the sprint autonomy guidelines established in Sprint 6.

2. **Clean architecture decisions**: The `gmail-imap` platform approach keeps OAuth and IMAP paths cleanly separated through the existing adapter pattern, requiring minimal changes to existing code.

3. **Round-trip testing**: The YAML import/export integration tests use actual repo files (400+ safe senders, multiple rules) for realistic validation, catching a normalization issue (Rule.toMap() conditional exceptions) that unit tests would not have found.

4. **Filter chip UX**: The SafeSenderCategory enum with pattern-based classification provides a clean, testable abstraction that could be extended for other categorization needs.

5. **Testing feedback process**: 3 rounds of manual testing caught 13 real-world issues that automated tests missed. The iterative fix-test-verify cycle was efficient and thorough.

6. **Live re-evaluation feature**: Adding inline re-evaluation after rule/safe sender changes from scan results was a significant UX improvement discovered during testing, not in the original plan.

---

## What Could Be Improved

1. **Retrospective timing**: The retrospective document was created prematurely (Feb 28) before manual testing was complete. Testing feedback continued through Mar 15, making the document stale. Future retrospectives should be created AFTER all testing feedback rounds are resolved.

2. **Account-scoping in UI features**: 3 of the 13 testing feedback items were account-context bugs (scan history showing all accounts, folder display using wrong account). Acceptance criteria for multi-account UI features should explicitly specify account-scoping behavior.

3. **Session context limits**: The 160K context window was a constraint during Sprint 19 (since resolved -- 1M tokens now available). Sprint 19 required session breaks, losing some research context.

4. **Pre-existing analyzer warnings**: 47 analyzer warnings persist in test files. While none are from Sprint 19 code, cleaning these up would improve overall code health.

---

## Technical Decisions

### Gmail Dual-Auth Architecture (Task F)

**Decision**: Add `gmail-imap` as a separate platform ID in the factory map, NOT in the visible platform list.

**Rationale**:
- Users see "Gmail" once in the platform selector (familiar, not confusing)
- Auth method choice happens in AccountSetupScreen after selecting Gmail
- `gmail-imap` routes to GenericIMAPAdapter with `imap.gmail.com:993` config
- Existing Gmail OAuth path unchanged (zero regression risk)
- Account display shows auth method badge ("App Password (IMAP)" vs "Google Sign-In (OAuth 2.0)")

**Alternative considered**: Adding a separate "Gmail (IMAP)" entry in the platform selector. Rejected because it would confuse users who do not understand the difference between OAuth and IMAP.

### YAML Export Normalization (Task E)

**Decision**: Compare data equivalence rather than byte-for-byte in double-export tests.

**Rationale**: `Rule.toMap()` conditionally includes `exceptions` (null vs empty RuleExceptions). First export from YAML source includes empty exceptions; re-import produces null exceptions. The important guarantee is data equivalence (same rules, conditions, actions), not byte-identical files.

### App Identity Migration (Task B)

**Decision**: Auto-migrate app data from old `com.example\spam_filter_mobile` directory to new `MyEmailSpamFilter\MyEmailSpamFilter` directory on first launch.

**Rationale**: Preserves user accounts, rules, credentials, and scan history across the identity change. One-time migration with no user interaction required.

---

## Metrics

| Metric | Value |
|--------|-------|
| Tasks planned | 6 |
| Tasks completed | 6 |
| Testing feedback items | 13 (across 3 rounds) |
| Tests added | 53 |
| Total tests | 1141 |
| Analyzer errors | 0 |
| Analyzer warnings | 47 (pre-existing) |
| Files changed | 43 |
| Lines added | ~3270 |
| Lines removed | ~462 |
| Commits | 8 |
| Elapsed time | Feb 27 - Mar 15, 2026 |

---

## User Feedback

No specific feedback provided. Manual testing complete across all 3 rounds with all issues addressed.

---

## Retrospective Improvements Implemented

Based on Sprint 19 analysis, the following improvements were approved and applied:

1. **Retrospective timing note** -- Added to SPRINT_EXECUTION_WORKFLOW.md Phase 7.7: Do NOT create retrospective document until after manual testing and all testing feedback rounds are complete.

2. **Multi-account UI acceptance criteria** -- Added to SPRINT_PLANNING.md: UI tasks involving multi-account features must specify account-scoping behavior explicitly, with examples.

3. **Updated this retrospective document** -- Replaced pre-testing metrics with final metrics reflecting all 3 testing feedback rounds.

4. **Updated ALL_SPRINTS_MASTER_PLAN.md** -- Final test count updated from 1133 to 1141.

5. **Analyzer warnings backlog item** -- Already present in ALL_SPRINTS_MASTER_PLAN.md as potential future work. No new item needed (47 warnings are pre-existing in test files, not blocking).

---

## Next Sprint Candidates

Refer to `docs/ALL_SPRINTS_MASTER_PLAN.md` for the prioritized backlog. Top candidates:
- Android app testing (Issue #163)
- Rule splitting UI (F24/Issue #149)
- Playwright UI tests (F11)
- Background scanning Android (F4)
