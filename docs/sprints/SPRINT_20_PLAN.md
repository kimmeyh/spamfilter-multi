# Sprint 20 Plan

**Sprint**: Sprint 20 - Gmail Folder Fix and Demo Scan Enhancements
**Date**: March 15, 2026
**Branch**: `feature/20260315_Sprint_20`
**Base**: `develop`
**Estimated Total Effort**: ~6-10h

---

## Sprint Goal

Fix Gmail folder scanning errors and expand Demo Scan sample data with realistic examples across all rule categories (safe sender exact email, safe sender exact domain, block email, block entire domain) to better demonstrate app capabilities.

---

## Tasks

### Task A: Gmail Folder Scan Errors (Bug #12)

**Issue**: [#184](https://github.com/kimmeyh/spamfilter-multi/issues/184)
**Estimated Effort**: ~2-4h
**Model**: Sonnet
**Value**: This fixes a blocking bug that prevents Gmail users from scanning folders.

**Acceptance Criteria**:
- [ ] Root cause identified for Gmail folder scan errors
- [ ] Fix implemented and tested with Gmail IMAP account
- [ ] Gmail OAuth and Gmail App Password (IMAP) paths both handle folder listing correctly
- [ ] No regression on AOL or other provider folder scanning
- [ ] Unit/integration tests added for Gmail folder handling

**Risks**: Medium - may require changes to GenericIMAPAdapter or GmailApiAdapter folder listing logic. Gmail IMAP uses `[Gmail]/` prefix for special folders which may differ from standard IMAP.

---

### Task B: Demo Scan Expanded Sample Data (Enhancement #13)

**Issue**: [#185](https://github.com/kimmeyh/spamfilter-multi/issues/185)
**Estimated Effort**: ~4-6h
**Model**: Haiku
**Value**: This enables new users to see all app capabilities through a realistic demo without needing a live email account.

**Acceptance Criteria**:
- [ ] Demo scan includes at least 3 Safe Sender - Exact Email examples using 3 different email providers (e.g., Gmail, Yahoo, Outlook)
- [ ] Demo scan includes at least 3 Safe Sender - Exact Domain examples using made-up addresses from: irs.gov, allstate.com, venmo.com
- [ ] Demo scan includes at least 3 Block Rule - Block Email examples using 3 different email providers (different providers from safe sender examples)
- [ ] Demo scan includes at least 3 Block Rule - Block Entire Domain examples using domains from existing block rules in rules.yaml
- [ ] Safe Sender and Block Rule provider examples do not overlap (different providers for each)
- [ ] Examples use realistic sender names and subject lines
- [ ] Demo scan results demonstrate all filter categories in results screen
- [ ] Existing demo scan tests updated for new sample data
- [ ] All tests pass after changes

**Risks**: Low - additive changes to mock_email_data.dart with clear requirements.

---

## Execution Order

1. **Task A** (Gmail folder fix - bug fix first, higher risk)
2. **Task B** (Demo scan data - additive, low risk)

---

## Sprint Scope Notes

- **Total estimated effort**: ~6-10h across 2 tasks
- **Focused sprint**: Small scope with clear deliverables
- **Dependencies**: None between tasks
