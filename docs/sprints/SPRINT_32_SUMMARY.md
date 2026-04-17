# Sprint 32 Summary - Security Hardening

**Sprint**: 32
**Date**: April 13-14, 2026
**Branch**: `feature/20260413_Sprint_32`
**PRs**: #231 (security), #232 (Copilot setup)
**Type**: Security Hardening (code + process)

## Objective

Implement 10 security items from Sprint 31 audit. Add automated code review and Copilot integration to sprint workflow.

## Deliverables

**Security fixes** (10 items):
- SEC-1: ReDoS detection in PatternCompiler.validatePattern() + PatternCompiler.safeHasMatch() with isolate timeout
- SEC-10: 10 MB file size limit on YAML imports
- SEC-12: OAuth token revocation on desktop signOut (Google revoke endpoint)
- SEC-13: Fail-fast on empty OAuth client ID
- SEC-16: dart pub outdated added to Phase 2 pre-kickoff
- SEC-17: Auth logging redaction (initial: secure_credentials_store + OAuth handler; extended after user log review: 9 more files / ~40 sites)
- SEC-18: Logger.w() in silent regex catch blocks
- SEC-20: Email format validation on account setup
- SEC-21: Password length warning (SnackBar, 5s)
- SEC-23: Windows binary hardening flags (/GS, /DYNAMICBASE, /NXCOMPAT, /guard:cf)

**Code review fixes** (from Phase 5.1.1 first trial):
- C2: SEC-12 token now in form-encoded body (not URL query string)
- H1: Redact.accountId() used (not Redact.email()) for accountId values; Redact.accountId() extended to handle plain email format
- H2: Password warning surfaced in UI (SnackBar) instead of log-only; password length removed from log

**Process improvements** (6 permanent additions to workflow):
- Phase 5.1.1: Automated Code Review with mechanical related-patterns grep (always run) + two-phase review for cross-cutting policies (conditional)
- Phase 6.4.1: GitHub Copilot Review Response (Fix/Backlog/NA recommendations per finding)
- Activities Requiring Opus (9 activities documented in SPRINT_PLANNING.md)
- Criterion 4a: User-Found Gap in Sprint Theme (SPRINT_STOPPING_CRITERIA.md v1.1)
- CODEOWNERS file (auto-assign @kimmeyh; Copilot via Repository Ruleset, not CODEOWNERS)
- .github/copilot-instructions.md (3983 chars under 4000-char limit) for project-specific Copilot guidance

## Test Impact

- Tests added: 13 (ReDoS detection 9, safeHasMatch 4)
- Tests modified: 0
- Total tests: 1239 passing
- flutter analyze: 0 issues

## Backlog Impact

- Removed: 10 completed SEC items (SEC-1, SEC-10, SEC-12, SEC-13, SEC-16, SEC-17, SEC-18, SEC-20, SEC-21, SEC-23)
- Added: SEC-1b (CRITICAL, design work needed for ReDoS runtime protection in evaluator hot path) and F72 (code hygiene cleanup)

## Retrospective

- All categories rated Very Good by both user and Claude (rounds 1 and 2)
- 6 process improvements approved and implemented (3 in round 1, 3 in round 2)
- See `docs/sprints/SPRINT_32_RETROSPECTIVE.md` for full details
