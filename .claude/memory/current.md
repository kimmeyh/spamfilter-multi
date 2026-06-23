# [STALE -- DO NOT TRUST] This file is OUT OF DATE (last real content: Sprint 39, 2026-05-24)

> **[STALE CONTEXT WARNING]** As of 2026-06-01, Sprint 40 has been executed and committed
> (branch `feature/20260525_Sprint_40`, 7 commits `2a2f579..e7db2bc`, pushed). The content
> below reflects Sprint 39 ONLY and must NOT be used to resume work. Re-run `/memory-save`
> to refresh this file before relying on it. Authoritative current state lives in:
> `docs/sprints/SPRINT_40_PLAN.md`, `docs/CODING_VELOCITY.md`, and the git log of the
> Sprint 40 branch.

---
# Sprint Context Save

**Sprint**: Sprint 39 (warmup complete; formal Phase 1 not yet started)
**Date**: 2026-05-24 20:15:00
**Branch**: feature/20260523_Sprint_39 (PR #259 MERGED to develop as 8d048c3)
**Status**: Sprint 39 warmup shipped; awaiting formal Phase 1 Backlog Refinement

## Current Tasks

- [x] F90 -- live-scan logging parity with background-scan logs (shipped PR #259)
- [x] BUG-S39-1 -- rule-name collision fix (preserves _ - @ .) (shipped PR #259)
- [x] BUG-S39-2 -- RuleSetProvider rethrow on UNIQUE violation (shipped PR #259)
- [x] F90 verbosity (per-step LiveScanLogger calls in EmailScanner) (shipped PR #259 round 2)
- [x] F90 Settings UI toggle on Manual Scan tab (shipped PR #259 round 2)
- [x] PR #259 Copilot review fixes -- PII redaction, path.join, doc fix (shipped PR #259 round 3)
- [x] F92 added to backlog (LiveScanLogger dedicated tests, deferred from Copilot review)
- [ ] Switch to develop, pull merge commit 8d048c3, delete local feature branch reference? (NEVER delete sprint branches per feedback_branch_retention.md -- skip)
- [ ] Formal Sprint 39 Phase 1 Backlog Refinement (when Harold ready)

## Recent Work (2026-05-21 -> 2026-05-24)

**Backlog refinement (no code, doc-only)**:
- F89 added -- surface SPF/DKIM/DMARC auth failures on rule + safe-sender quick-add prompts. Sourced from 2026-05-21 Amazon phishing email triage.
- F89 strengthened -- dialog content must explain WHAT failed, WHY it matters per quick-add action, and WHAT alternatives to consider (not just raw protocol output).
- F91 added -- post-safe-sender-move source-folder dedup to reconcile AOL "copy-not-move" classifier re-injection. Sourced from 2026-05-23 manual testing where safe-sender emails reappeared in Bulk Mail with new UIDs each scan despite UID MOVE to INBOX reporting success. Captured RFC 5322 Message-ID required (DB v6 migration).
- F90 added (then shipped) -- live-scan logging parity with background-scan.

**Sprint 39 warmup PR #259 (MERGED 2026-05-24 20:10 UTC as 8d048c3)**:
- New `lib/core/services/live_scan_logger.dart` with runtime log + per-account CSV/XLSX
- Per-step LiveScanLogger calls in EmailScanner (Step 1, 2, 2.5, 4, 5, 6a, 6b, 6b-1, 6b-2, 6b-3) matching background-log verbosity
- Settings > Manual Scan tab Debug section with "Export CSV After Each Scan" toggle
- BUG-S39-1: `_sanitizeForRuleName` preserves `_ - @ .` so distinct addresses produce distinct rule names
- BUG-S39-2: RuleSetProvider.addRule and addSafeSender now rethrow on UNIQUE violation
- Copilot review fixes: Redact.accountId/email on log lines, path.join for cross-platform, docstring drift fix
- F92 deferred to backlog (LiveScanLogger dedicated tests, Priority 50, ~2-3h)
- Tests: 1455 -> 1460 passing / 28 skipped / 0 failed
- 4 commits on feature/20260523_Sprint_39: 840c6ea, aa30074, 55df875, plus merge commit

## Bug Investigations Completed

**Bug 1 (2026-05-23)**: Safe-sender emails reappearing in AOL Bulk Mail after every live scan. Diagnosed AOL classifier copy-not-move pattern. Fix is F91 (backlogged, requires Message-ID capture).

**Bug 2 (2026-05-23)**: Block rule for `account_update@amazon.com` (underscore phishing) not appearing. Root cause: rule-name sanitizer collapsed `_` `-` `@` `.` all to `_`, so name collided with existing `account-update@amazon.com` (hyphen legitimate Amazon) rule. UNIQUE violation silently swallowed by RuleSetProvider.addRule. Both fixed in PR #259 (BUG-S39-1 + BUG-S39-2).

## Next Steps

1. **Switch to develop and pull**: `git -C "D:/Data/Harold/github/spamfilter-multi" checkout develop && git pull origin develop` -- pulls merge commit 8d048c3. Sprint branch stays per feedback_branch_retention.md.
2. **Formal Sprint 39 Phase 1 Backlog Refinement** when Harold ready -- candidate list spans:
   - **Tier A (store-release-critical)**: S38-CI-1 X-close button (~1-3h), BUG-S37-2 TLD cleanup + ccTLD expansion (~3-5h), F87 Settings icon Scan History verify (~1h), S38-CI-6 _loadLastCompletedScan widget test (~2h)
   - **Tier B (polish)**: S38-CI-2 info-card relocate (~1h), S38-CI-3 F84 Sub-B + Sub-C selection gestures (~3-5h)
   - **Tier A new (from bug investigations)**: F89 SPF/DKIM/DMARC auth warnings (~6-10h), F91 AOL copy-not-move dedup (~4-6h, depends on F90 = shipped)
   - **Tier B new (PR #259 deferred)**: F92 LiveScanLogger tests (~2-3h)
   - **Tier C (defer to Sprint 40)**: S38-CI-4 IMAP cursor cap, S38-CI-5 F88 IMAP batch research, BUG-S36-1 semantic subsumption, F76 visual regression, SEC-8b/SEC-11b, F83 per-account BG scan, F63 responsive design
   - **Process**: S38-CI-7 Opus 4.6 vs 4.7 side-by-side eval (~3-4h)
3. **No active bugs to investigate** at session end.

## Blockers/Notes

- **None active**. All PRs merged, branch clean.
- **F91 depends on F90** (now shipped) -- F91 can land any time.
- **Decision-class protocol active**: any architecture (Class 1), development (Class 2), or sprint-execution (Class 3) decisions outside approved Sprint 39 plan must be surfaced at natural breaks per CLAUDE.md.
- **Branch protection**: Harold's bypass-actor exemption is configured for the ruleset -- code-owner-self-approval works via admin bypass when needed.
- **Active model**: Opus 4.7. S38-CI-7 (Sprint 39 IMP-8) will side-by-side compare with 4.6.

---

**Instructions for Claude on Resume**:
1. Read this context file on startup
2. Verify git branch -- expect develop (after switching) or feature/20260523_Sprint_39 (if not yet switched)
3. Pull develop to get merge commit 8d048c3 from PR #259 if not already done
4. Continue from "Next Steps" section above -- most likely path is formal Sprint 39 Phase 1 Backlog Refinement
