# Sprint 29 Plan

**Sprint**: Sprint 29 - UX + Quality + Features
**Date**: April 3, 2026
**Branch**: `feature/20260403_Sprint_29`
**Base**: `develop`
**Estimated Total Effort**: not recorded

> **Note**: This document is a RETROACTIVE reconstruction, created during the
> Sprint 57 documentation audit (2026-08-14). No SPRINT_29_PLAN.md was found
> in the repository history; this file was rebuilt from PR #225 (commits and
> body), the four source GitHub issues (#220, #212, #208, #203), and the
> existing SPRINT_29_RETROSPECTIVE.md / SPRINT_29_SUMMARY.md. Effort
> estimates below are not recorded in any surviving source and are marked
> as such rather than invented; acceptance criteria are reconstructed from
> issue text and from what the shipped commits actually did.

---

## Sprint Goal

Improve UX (selectable/copyable text across all screens, Scan History
multi-account view), add default rule set creation for new-user onboarding,
and close test coverage gaps identified in Sprint 25 (F32), while fixing the
one pre-existing test failure.

---

## Background

Sprint 27 retrospective feedback requested that page text become selectable
and copyable (F50). F48 is a follow-up to the Sprint-era multi-account
scanning work (F7), redesigning Scan History from a per-account screen into
a combined view. F46 addresses a pre-1.0-release gap: new installs start
with zero rules and no bundled defaults. F42 continues the test-coverage
remediation begun in Sprint 25 (F32 gap analysis), targeting the
0%-coverage `email_scanner.dart` and `default_rule_set_service.dart` plus
`yaml_service.dart` parse paths.

**Backlog items**: F50 (Issue #220), F48 (Issue #212), F46 (Issue #208), F42
(Issue #203)

---

## Tasks

### Task 1: Make all page text selectable and copyable (F50, Issue #220)

**Model**: not recorded (executed by Claude Opus 4.6 per commit trailers)
**Execution**: Autonomous, with follow-up fixes from manual testing feedback
**Issue**: #220

Wrap all screens in `SelectionArea` (and expand `SelectableText` coverage
in `email_detail_view.dart` for metadata fields) so that text on every
major screen and dialog can be selected and copied to the clipboard.

**Screens to update** (per issue #220):
- Account Selection screen
- Manual Scan / Scan Progress screen
- Scan Results screen (email details, stats)
- Scan History screen (history entries)
- Settings screens (all 4 tabs)
- Manage Rules screen (rule patterns)
- Manage Safe Senders screen (sender patterns)
- Add Account / Provider Selection screen
- Alert/confirmation dialogs

**Acceptance Criteria** (per issue #220):
- [ ] Text on all major screens is selectable
- [ ] Selected text can be copied to clipboard (Ctrl+C or context menu)
- [ ] Buttons and interactive elements remain clickable (selection does not
      interfere)

**Note**: Dialogs are overlays outside the parent `SelectionArea`, so a
first pass covering the 16 primary screens missed dialog/popup content
(results screen email detail popup, account setup dialogs, platform
selection dialogs, Gmail OAuth dialogs). These were caught in manual
testing feedback and fixed in a follow-up commit, bringing total coverage
to 21 screens.

### Task 2: Scan History enhancements - multi-account, filters, totals (F48, Issue #212)

**Model**: not recorded
**Execution**: Autonomous, with follow-up fixes from manual testing feedback
**Issue**: #212

Redesign Scan History from a per-account screen into a single combined
view across all accounts.

**Changes** (per issue #212):
- [ ] Title updated from "Scan History" to "Scan History (N days)" showing
      the retention setting
- [ ] All accounts combined into one chronological view (previously
      per-account)
- [ ] Account filter chips (by email address) with toggle functionality
- [ ] Type filter chips
- [ ] Totals row: Deleted, Moved, Safe, No Rule, Errors (same order as
      Results screen), with the "Completed" total removed
- [ ] Tooltips on each total explaining what it counts
- [ ] Navigating from Settings > Manual/Background "Go to View Scan
      History" pre-selects that account's filter

**Note**: Initial implementation derived the account filter list from scan
data; manual testing feedback found this should instead use the configured
accounts from the credentials store (so accounts with zero scans still
appear), and found the totals/filter rows were not consistently
left-aligned. Both were corrected in follow-up commits, along with removing
a now-redundant account-selection dialog on the Select Account -> View Scan
History navigation path (superseded by the in-screen filter chips).

### Task 3: Default rule set creation with reset option (F46, Issue #208)

**Model**: not recorded
**Execution**: Autonomous
**Issue**: #208

Create a default set of rules (top-level-domain block rules and Entire
Domain rules) so new installs start with a baseline spam-filtering rule set
instead of an empty database, plus a way to restore those defaults later.

**Acceptance Criteria** (reconstructed from issue #208 and shipped commit):
- [ ] `DefaultRuleSetService` seeds rules and safe senders from the bundled
      YAML assets when the database is empty (fresh install)
- [ ] `YamlService` gains `parseRulesFromString` and
      `parseSafeSendersFromString` for asset-based loading
- [ ] `seedIfEmpty` wired into `RuleSetProvider` initialization
- [ ] Settings > General gains a "Reset Rules to Defaults" button with a
      confirmation dialog
- [ ] Scope: extract defaults from both `rules.yaml` and
      `rules_safe_senders.yaml` (not rules only)

### Task 4: Test coverage gaps - email_scanner, default_rule_set_service, yaml_service (F42, Issue #203)

**Model**: not recorded
**Execution**: Autonomous
**Issue**: #203

Close the highest-priority 0%-coverage gaps identified in the Sprint 25
(F32) coverage analysis (28.9% overall at the time), focused on core scan
orchestration and the new F46 service.

**Target files** (per issue #203):
- `core/services/email_scanner.dart` (267 lines, 0% coverage) - core scan
  orchestration
- `core/services/default_rule_set_service.dart` (new in this sprint, Task 3)
- `core/services/yaml_service.dart` parse methods (new asset-parsing paths
  added for Task 3)

**Acceptance Criteria**:
- [ ] New tests added for `email_scanner` (constructor, error paths,
      delegation)
- [ ] New tests added for `default_rule_set_service` (seed, reset,
      interaction with an empty vs. populated database)
- [ ] New tests added for `yaml_service` parse-from-string methods
- [ ] Any real bugs surfaced by new tests are fixed, not just documented
- [ ] `flutter test` passes with 0 failures

### Task 5 (opportunistic): Fix pre-existing YAML round-trip test failure

**Model**: not recorded
**Execution**: Autonomous
**Issue**: none tracked separately (discovered during Task 4)

`yaml_import_export_roundtrip_test.dart` looked for `rules.yaml` at the
repo root; the file moved to `mobile-app/assets/rules/` in Sprint 20 and
the test path was never updated, leaving one pre-existing test failure.

**Acceptance Criteria**:
- [ ] Test path updated to `mobile-app/assets/rules/`
- [ ] `flutter test` reports 0 failures (down from 1 pre-existing)

---

## Risks

| Risk | Mitigation |
|------|------------|
| SelectionArea wrapping may not reach dialog/popup content (overlays render outside the parent SelectionArea) | Manual testing pass across all screens and dialogs before sign-off; fix gaps as found |
| Scan History account filter sourced from scan data could hide never-scanned accounts | Derive filter list from configured accounts (credentials store) instead of scan history |
| F46 default rule seeding could silently overwrite an existing user's rules on upgrade | Only seed when the database is empty (fresh install), never on an existing populated database |
| New tests for email_scanner/default_rule_set_service could surface real bugs requiring fixes mid-sprint | Budget time to fix, not just document, any bugs found by new tests |

---

## Test Plan

- [ ] `flutter test` -- all tests pass, 0 failures (including the fixed
      YAML round-trip test)
- [ ] `flutter analyze` -- 0 issues
- [ ] Windows desktop build and manual launch
- [ ] Manual testing pass across all 21 screens/dialogs for text
      selection and copy
- [ ] Manual testing pass on Scan History: account filter, type filter,
      totals, tooltips, retention-days title
- [ ] Manual testing pass on fresh install: default rules seeded; Reset to
      Defaults works from Settings > General
- [ ] Winwright accessibility tree verification
