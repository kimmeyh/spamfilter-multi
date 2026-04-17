# Sprint 33 Summary: Security Hardening + UX Polish

**Sprint**: 33
**Dates**: April 14-16, 2026
**Branch**: `feature/20260414_Sprint_33`
**PR**: #234 (merged to develop)
**Issue**: #233

---

## Objective

Continue the Sprint 31/32 security hardening track (6 items from the 23-item audit backlog) while landing 4 user-facing features and refreshing ARCHITECTURE.md for new components.

## Deliverables

**Security (6 items)**:
- SEC-1b (CRITICAL): ReDoS runtime protection via compile-time pattern rejection in PatternCompiler
- SEC-8: Certificate pinning for Google OAuth endpoints (CertificatePinner + PinnedHttpClient)
- SEC-11 (partial): Database encryption infrastructure (key service + opt-in flag; SQLCipher driver swap deferred)
- SEC-14: Unmatched-email retention (configurable 7/30/90/365/forever) + body-preview truncation to 100 chars
- SEC-19: "Disable detailed auth logging" toggle in Settings > Privacy and Logging
- SEC-22: Per-account rate limit on failed IMAP authentication (10 failures / 1 hour)

**Features (5 items)**:
- F53: .cc and .ne TLD block patterns + idempotent post-seed migration (NOTE: migration bug found post-sprint -- see F73 in Sprint 34)
- F54: In-app Help system (grew from 12 to 19 sections across 4 UX testing rounds)
- F55: Navigation consistency (Select Account icon standardized across all screens, back-button flow fixed)
- F65: Verified Gmail onboarding already aligns with ADR-0034 Dual Path (no code changes)
- F66: User data deletion (per-account + wipe-all flows with multi-step confirmation)

**Architecture**:
- ARCHITECTURE.md updated: PatternCompiler provenance, lib/core/security/ directory, DataDeletionService, DefaultRuleSetService, HelpScreen, DB schema v3

**Process**:
- Sprint retrospective standard upgraded to 4 roles x 14 categories (v2.0)
- PowerShell-first approach documented for skill file updates in don't-ask mode

## Metrics

| Metric | Sprint 32 | Sprint 33 | Delta |
|--------|-----------|-----------|-------|
| Tests passing | 1239 | 1313 | +74 |
| Analyzer issues | 0 | 0 | -- |
| Tasks completed | 10 | 12 + 4 UX rounds | +6 |
| Commits | 6 | 10 | +4 |
| New files | 6 | 14 | +8 |
| Days | 1 | 3 | +2 |

## Key Lessons

1. **Navigation state-machine bugs need Opus escalation after 1-2 failed surface fixes** -- Round 4 full trace resolved the double-push bug faster than Rounds 2+3 combined
2. **UX sprint plans need explicit back-button specs** -- "navigation consistency" was too abstract
3. **Post-seed DB migrations must match the DB format** -- F53 targeted a deleted monolithic row (tracked as F73 bug fix in Sprint 34)
4. **Sprint retrospective completeness** -- Sprint 33 retrospective was backfilled to the new 4-roles x 14-categories standard

## Known Issue Discovered Post-Sprint

**F73 (tracked in Sprint 34)**: F53's .cc/.ne TLD migration (`ensureTldBlockRules`) silently skips on existing installs because it searches for the monolithic `SpamAutoDeleteHeader` row which was deleted by the Sprint 20 split script. Result: .cc and .ne TLD blocks are missing from Harold's DB. Fix planned in Sprint 34.
