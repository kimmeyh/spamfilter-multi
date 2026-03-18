# Sprint 20 Retrospective

**Sprint**: Sprint 20 - Gmail Fix, Demo Scan, Manage Rules Overhaul, Performance, Cleanup
**Date**: March 15-17, 2026
**Branch**: `feature/20260315_Sprint_20`
**PR**: [#188](https://github.com/kimmeyh/spamfilter-multi/pull/188)

---

## Sprint Summary

Sprint 20 delivered 5 planned tasks plus 11 testing feedback fixes. The sprint scope expanded significantly during execution due to the decision to split monolithic rules into individual patterns and remove YAML dual-write, which were prerequisite changes for the Manage Rules UI overhaul.

### Tasks Completed

| Task | Feature | Issue | Status |
|------|---------|-------|--------|
| A | Gmail IMAP folder scan errors | #184 | [OK] Complete |
| B | Demo Scan expanded sample data | #185 | [OK] Complete |
| C | Manage Rules UI overhaul | #149 | [OK] Complete |
| D | Speed up Add Rule performance | #186 | [OK] Complete |
| E | Clean up analyzer warnings | #187 | [OK] Complete |

### Testing Feedback Fixes (11 items)

1. DB v2 migration idempotent (check existing columns before ALTER TABLE)
2. Scan Results folder display shows correct account folders after switching
3. Demo-specific rules DB for consistent demo results
4. IMAP folder listing recursive (shows [Gmail]/Trash, [Gmail]/Spam)
5. Non-selectable parent folders filtered from folder selection
6. 266 TLD patterns reclassified from exact_domain to top_level_domain
7. 1,370 wildcard TLD patterns converted to .com and reclassified as entire_domain
8. Add Rule from scan results sets classification fields
9. Quick rule from email detail popup sets classification fields
10. YAML migration and export preserve classification fields
11. Safe sender matches in safe sender folder skipped from scan results

### Test Growth

- Sprint start: 1141 tests
- Sprint end: 1141 tests (no new tests added -- focus was on infrastructure and UI)
- Analyzer: 46 warnings resolved to 0

---

## What Went Well

1. **Collaborative scope expansion**: The user identified that splitting rules and removing YAML dual-write should happen together with the UI overhaul. This was the right architectural decision and saved future rework.

2. **Standalone fix scripts**: The split_rules.dart, fix_tld_rules.dart, and fix_wildcard_tld.dart scripts worked well as one-time tools with backup/restore capability. This pattern of standalone migration scripts outside the app is effective.

3. **Deep code audit**: The thorough audit of all Rule creation/modification code paths caught 3 gaps (email detail popup, migration manager, YAML service) before they became production bugs.

4. **Iterative testing feedback**: 11 fixes across multiple testing rounds. Manual testing caught issues that automated tests did not cover (TLD classification, wildcard patterns, safe sender folder logic, IMAP child folders).

5. **Context window**: The 1M token context window allowed continuous work across the entire sprint without session breaks -- a significant improvement over Sprint 19 which required multiple sessions at 160K.

---

## What Could Be Improved

1. **Pattern classifier thoroughness**: The split script's classifier should have been tested against ALL pattern formats before first run. The TLD (`@.*\.xyz$`) and wildcard (`[a-z0-9.-]+$`) patterns required two follow-up fix scripts. A sample-based pre-check would have caught these.

2. **Safe sender folder skip logic**: Went through 3 iterations (skip at evaluation, skip only when configured, always display, final: skip when in folder). Should have mapped out all cases (null config, INBOX default, display vs action separation) before the first implementation.

3. **Test coverage for new features**: No new automated tests were added for the classification fields, demo rules DB, or safe sender folder skip logic. These should be added in a future sprint.

---

## Technical Decisions

### DB as Sole Source of Truth (YAML Dual-Write Removal)

**Decision**: Remove YAML dual-write from RuleSetProvider. Database is the only storage for rules. YAML import/export available via Settings > Data Management.

**Rationale**: With 3,291 individual rules, writing to YAML on every change would be slow and fragile. The Sprint 19 YAML import/export UI already provides backup/restore capability.

### Monolithic Rule Split

**Decision**: Split 5 monolithic rules (e.g., SpamAutoDeleteHeader with 1,742 patterns) into 3,291 individual rules, each with one pattern and classification metadata.

**Rationale**: Users cannot manage individual patterns within monolithic rules. Individual rules enable search, filter, enable/disable, and delete per pattern.

### Pattern Classification Schema

**Decision**: Add patternCategory (header_from, subject, body), patternSubType (entire_domain, exact_domain, exact_email, top_level_domain), and sourceDomain fields to Rule model.

**Rationale**: Enables filter chips and search in Manage Rules UI. Structured fields are better than parsing naming conventions.

### Safe Sender Folder Skip

**Decision**: Emails in the safe sender folder that match safe sender rules are skipped entirely (not counted, not displayed). Other matches (block, no rule) are still shown.

**Rationale**: These emails are already where they belong. Showing them clutters results. But block/no-rule matches in the safe sender folder indicate problems that need attention.

---

## Metrics

| Metric | Value |
|--------|-------|
| Tasks planned | 5 |
| Tasks completed | 5 |
| Testing feedback items | 11 |
| Tests | 1141 (unchanged) |
| Analyzer warnings | 46 -> 0 |
| Commits | 25 |
| Files changed | ~30 |
| New scripts | 3 (split_rules.dart, fix_tld_rules.dart, fix_wildcard_tld.dart) |
| Backlog items added | 4 (#14-#17) |
| DB schema version | 1 -> 2 |

---

## Backlog Items Added

- **#14**: Folder selectors: two-level listing with collapsible sub-folders
- **#15**: Rule editing UI with regex generation and validation
- **#16**: Live Scan: re-process emails after rule changes
- **#17**: Live Scan: in-progress and completed status indicator

---

## Next Sprint Candidates

Refer to `docs/ALL_SPRINTS_MASTER_PLAN.md` for the prioritized backlog.
