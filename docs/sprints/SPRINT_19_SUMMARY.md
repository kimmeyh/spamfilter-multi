# Sprint 19 Summary

**Sprint**: Sprint 19 - Dual-Auth, Import/Export, Branding, and UX Polish
**Date**: February 27 - March 15, 2026
**Branch**: `feature/20260227_Sprint_19`
**PR**: [#183](https://github.com/kimmeyh/spamfilter-multi/pull/183)
**Status**: [OK] Complete

---

## Sprint Objective

Expand Gmail authentication options with dual-auth (OAuth + App Password), add YAML import/export UI, establish production branding and versioning, and polish UX with save-on-selection folders and safe sender filter chips.

---

## Tasks Completed

| Task | Feature | Issue | Model |
|------|---------|-------|-------|
| A | Version Numbering v0.5.0 (GP-15) | #181 | Sonnet |
| B | Application Identity - MyEmailSpamFilter (GP-1) | #182 | Sonnet |
| C | Folder Selection Save-on-Selection UX (F27) | #172 | Sonnet |
| D | Safe Senders Filter Chips (F26) | #180 | Sonnet |
| E | YAML Import/Export UI (F22) | #179 | Opus |
| F | Gmail Dual-Auth - OAuth + App Password (F12B) | #178 | Opus |

## Testing Feedback (3 Rounds, 13 Items)

- About section in Settings showing app version
- Background scan log path for new app identity
- Demo Mode UX change to direct-launch card
- Scan History: 12-hour format, all metrics, account filtering
- YAML export crash fix (AppPaths initialization)
- Safe sender pattern normalization
- Gmail auth method ordering (App Password as Recommended)
- App Password instructions UX (selectable text, tappable URLs)
- Scan Results Summary folder names
- Live re-evaluation after adding rules from scan results
- Folder display account-scoping fix

---

## Deliverables

- v0.5.0 tagged release with semver strategy
- Application rebranded to MyEmailSpamFilter (com.myemailspamfilter)
- Auto-migration of app data from old com.example directory
- Gmail dual-auth: OAuth or App Password choice with in-app walkthrough
- YAML import/export UI in Settings > Data Management
- Folder selection instant-save UX
- Safe sender filter chips (Exact Email, Exact Domain, Entire Domain, Other)

---

## Metrics

| Metric | Value |
|--------|-------|
| Tasks planned | 6 |
| Tasks completed | 6 |
| Testing feedback items | 13 |
| Tests added | 53 |
| Total tests | 1141 |
| Files changed | 43 |
| Lines added/removed | +3270 / -462 |
| Commits | 8 |

---

## Key Decisions

1. **Gmail Dual-Auth**: Added `gmail-imap` as hidden platform ID routing to GenericIMAPAdapter, keeping Gmail as single visible platform entry
2. **YAML Export**: Data equivalence comparison rather than byte-identical for round-trip tests
3. **App Identity Migration**: One-time auto-migration of user data on first launch after identity change

---

## Lessons Learned

1. Retrospective documents should be created AFTER all testing feedback rounds, not before manual testing
2. Multi-account UI features need explicit account-scoping acceptance criteria
3. Testing feedback rounds (3 rounds, 13 items) demonstrate the value of manual testing but also suggest room for broader automated integration tests

---

## Process Improvements Implemented

- Added retrospective timing guidance to SPRINT_EXECUTION_WORKFLOW.md
- Added multi-account UI acceptance criteria guidance to SPRINT_PLANNING.md
- Added analyzer warnings cleanup as backlog item
