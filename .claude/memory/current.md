# Ad-Hoc Architecture Review Context Save

**Work Type**: Ad-hoc (not a numbered sprint)
**Date**: 2026-02-22 afternoon
**Branch**: adhoc/20260221_architecture_review
**Status**: In Progress

## Current Tasks

- [x] Architecture review: identify gaps between docs and implementation (Task #35)
- [x] Update ARCHITECTURE.md with current state - v2.0 rewrite (Task #37)
- [x] Create GitHub spike card Issue #164 for architecture review
- [x] Create PR #165 for ARCHITECTURE.md v2.0 update (targeting develop)
- [x] Move Android app testing to future sprint (Issue #163)
- [ ] Review ADR-0026 through ADR-0034 for decisions (Task #36) - IN PROGRESS

## ADR Review Plan (Agreed with User)

Review order (user confirmed):
1. ADR-0029 (Gmail Scope/CASA) - DEEP DIVE IN PROGRESS
2. ADR-0034 (Gmail Access Method) - DEEP DIVE IN PROGRESS
3. ADR-0026 (Play Store Readiness)
4. ADR-0030 (Privacy Policy)
5. ADR-0033 (App Signing)
6. ADR-0028 (API Key Security)
7. ADR-0027 (ProtonMail Bridge)
8. ADR-0032 (Accessibility)
9. ADR-0031 (Internationalization)

## Current Deep Dive: ADR-0029 + ADR-0034 + F12

### What Was Presented to User
A comprehensive analysis showing how ADR-0029, ADR-0034, and F12 (Persistent Gmail Auth) are interconnected:

**Key finding**: Token lifetime (7 days vs months) depends on app verification status. F12 is a VERIFICATION problem, not a CODE problem. The existing google_auth_service.dart already has getValidAccessToken(), _refreshToken(), etc.

**Four paths presented**:
- Path 1: Pursue CASA verification ($550-$8,000+/year, 2-6 months)
- Path 2: Gmail app passwords (zero cost, no OAuth needed)
- Path 3: Dual path (app passwords now, OAuth later)
- Path 4: Launch without Gmail (fastest but excludes largest provider)

### Where We Stopped
User asked: "Can you explain the 100 user limit for Unverified OAuth tokens"

I attempted to fetch Google's official docs to give a precise answer but WebFetch/WebSearch were blocked in "don't ask" mode. We updated settings.local.json to add WebFetch and WebSearch permissions but the session needs a restart for them to take effect.

**I provided a preliminary answer** based on my knowledge:
- 100 limit is on test users in Google Cloud Console (Testing mode)
- Distinguished Testing mode (100 allowlisted users) vs Published+Unverified (warning screen but no cap)
- Noted 3 things I wanted to verify from Google's current docs:
  1. Does "Published + Unverified" truly have no user cap for restricted scopes?
  2. Is the 7-day token expiry specific to Testing mode or also Published+Unverified?
  3. Can restricted-scope apps even be "Published" without completing verification?

## Next Steps

1. **On resume**: Fetch Google OAuth docs to answer the 100-user-limit question precisely
   - URL: https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification
   - URL: https://support.google.com/cloud/answer/7454865
2. **Continue ADR-0029/0034 discussion** based on user's response to the four paths
3. **After ADR-0029/0034 decisions**: Continue through ADR review plan (Steps 3-9)
4. **PR #165** (ARCHITECTURE.md v2.0) is open and awaiting user review/merge

## Settings Change Made This Session

Updated `.claude/settings.local.json` to add:
- `"WebFetch"` (unrestricted) to allow list
- `"WebSearch"` to allow list
These should work after Claude Code restart.

## Blockers/Notes

- WebFetch and WebSearch need Claude Code restart to work in don't-ask mode
- The ADR decisions are Product Owner decisions - present options, let user decide
- F12 infrastructure already exists in codebase (google_auth_service.dart) but tokens expire in 7 days without CASA verification
- User wants to complete ADR-0029/0034 review BEFORE looking at other ADRs

## Open PRs

- PR #165: ARCHITECTURE.md v2.0 update (adhoc/20260221_architecture_review -> develop)

---

**Instructions for Claude on Resume**:
1. Read this context file on startup (via /startup-check)
2. Verify git branch is adhoc/20260221_architecture_review
3. Fetch the Google OAuth docs to answer the 100-user-limit question
4. Continue ADR-0029/0034 deep dive discussion with user
5. This is ad-hoc work, NOT a numbered sprint - do not look for sprint plans
