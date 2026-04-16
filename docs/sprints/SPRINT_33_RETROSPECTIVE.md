# Sprint 33 Retrospective - Security Hardening + UX Polish

**Sprint**: 33
**Date**: April 14-16, 2026
**Branch**: `feature/20260414_Sprint_33`
**PR**: (TBD — to be filled after Phase 6 PR creation)
**Type**: Mixed — Security hardening (6 items), feature completion (4 items), architecture refresh (1 item), UX iteration (4 rounds)

---

## Sprint Objective

Continue the Sprint 31/32 security hardening track (address 6 items from the 23-item backlog) while landing 4 user-facing features that were ready to ship, and refresh ARCHITECTURE.md for the new components.

## Deliverables

**Security (6 items)**:
- SEC-1b (CRITICAL): ReDoS runtime protection via compile-time pattern rejection
- SEC-8: Certificate pinning for Google OAuth endpoints
- SEC-11 (partial): Database encryption infrastructure (key service + opt-in flag; SQLCipher driver swap deferred)
- SEC-14: Unmatched-email retention + body-preview truncation
- SEC-19: "Disable detailed auth logging" toggle
- SEC-22: Per-account rate limit on failed IMAP authentication

**Features (4 items)**:
- F53: `.cc` and `.ne` TLD block patterns + idempotent post-seed migration
- F54: In-app Help system (initial 12 sections → expanded to 19 sections across 4 rounds)
- F55: Navigation consistency (Select Account icon, standardized icon order, back-button flow)
- F65: Verified Gmail onboarding already aligns with ADR-0034 Dual Path (no code changes needed)
- F66: User data deletion service + Settings "Delete All App Data" entry point

**Architecture**:
- ARCHITECTURE.md updates for new components (PatternCompiler provenance, `lib/core/security/`, DataDeletionService, DefaultRuleSetService, HelpScreen, DB schema v3)

**Testing**:
- 74 net new tests (1239 → 1313 passing)
- 0 analyzer issues maintained throughout
- 4 rounds of manual UX testing on Windows desktop with fix turnaround

---

## Key Changes

### New Files

- `mobile-app/lib/core/security/auth_rate_limiter.dart` — SEC-22
- `mobile-app/lib/core/security/certificate_pinner.dart` — SEC-8
- `mobile-app/lib/core/security/database_encryption_key_service.dart` — SEC-11
- `mobile-app/lib/core/services/data_deletion_service.dart` — F66
- `mobile-app/lib/ui/screens/help_screen.dart` — F54
- 6 new unit-test files for the above

### Modified Files (hot spots)

- `pattern_compiler.dart` — SEC-1b provenance + compile-time rejection
- `default_rule_set_service.dart` — F53 idempotent TLD migration
- `database_helper.dart` — DB schema v3 (auth_rate_limit table)
- `settings_store.dart` — 4 new settings keys + getters/setters
- `settings_screen.dart` — Privacy & Logging section + Delete All App Data + tab-aware Help deep-link
- `scan_progress_screen.dart` — F55 RouteAware + double-push fix
- `results_display_screen.dart` — F55 back-button fix + demo-aware Help + icon reorder
- `account_selection_screen.dart` — per-account deletion upgrade
- `help_screen.dart` — grew from 12 → 19 sections across rounds
- 12 AppBars updated with standardized icon row

### Process Changes

- SEC-1b added as testing-checklist note to F56 (Manual rule creation UI) in ALL_SPRINTS_MASTER_PLAN.md

---

## Manual Testing — 4 Rounds of UX Iteration

This sprint's UX work (F54 + F55) went through four rounds of manual testing with the user on Windows desktop. Each round caught issues the previous round's automated tests missed.

### Round 1 — Initial 12-task PR

Issues surfaced:
- F55: Results back button sometimes returned to Results (not Manual Scan)
- F55: Accounts icon missing on Scan History, Settings, Platform Selection, Account Setup
- F55: Icon order not standardized
- F54: Missing Background Scanning help section
- F53: User couldn't locate the `.cc` / `.ne` patterns in the UI (they were in a 200+ entry sorted header list — not a bug, just hard to verify visually)
- SEC-1b: Cannot manually test without a rule add/edit UI (backlog note added to F56)
- SEC-11: Encrypt database toggle missing from the UI (only the settings key had been added)
- Rule/safe-sender detail dialogs not selectable (Flutter AlertDialog overlay is outside screen-level SelectionArea)

### Round 2 — First fix pass

Remaining issues:
- F55: Back from Results still landed on Scan Progress (not Manual Scan), and sometimes showed partial results
- Help: Scrollbar hover-only (not always visible)
- Help: Deep-linked section appeared mid-screen, not pinned to top
- Icon order needed final tweak (Download/Search/History/Accounts/Help/Settings/X)
- Need Demo Scan help section + wire from Scan Progress Help
- Need Settings > Account tab → "Folder Settings" help with per-provider suggestions
- Need Settings > Manual Scan tab → help for each sub-setting
- Need Settings > Background tab → split from Manual Scan (no duplication)

### Round 3 — Second fix pass

Remaining issues:
- Help deep-link broken at default viewport size (ListView lazy-build caused GlobalKey context to be null at post-frame)
- Help screen itself needed the standard AppBar icon row
- Help Settings sub-section order didn't match Settings tab order
- Live scan back button "refreshed" Results instead of popping (one tap wasn't enough)
- Manual Scan back button went to Results (!)

### Round 4 — Opus-assisted root-cause analysis

**Finding:** The last two F55 bugs were the same double-push bug.

- `_startRealScan()` pushed Results on scan-start (Sprint 12 intent).
- `ScanProgress.build()` ALSO pushed Results on scan-completed.
- Result: duplicate Results on nav stack. Back from top Results → older Results underneath (looks like refresh). "Scan Again" button's `pushReplacement` put fresh ScanProgress on top of the duplicate Results, so back from ScanProgress hit the duplicate Results (!).

**Fix:** Removed the auto-push-on-completion from `ScanProgress.build()`. Results already `context.watch`es the provider and renders scanning → completed naturally. Single push from scan-start is now the only path.

### Round 5 — All passing

User confirmed all working as expected.

---

## User Feedback

### 1. Effectiveness and Efficiency
- **Rating**: Good
- **Note**: Sprint scope was appropriate (12 tasks landed cleanly). Manual-testing iteration was higher than normal (4 rounds) because the scope touched a lot of UX surface area.

### 2. Testing Approach
- **Rating**: Very Good
- Automated tests held at 0 analyzer issues and 1313 passing across 4 rounds of fixes.
- Manual testing caught everything automated couldn't (navigation flow, lazy-build timing, cross-dialog selection).

### 3. Effort Accuracy
- **Rating**: Good
- 12 tasks landed in plan. UX iteration added ~4 additional fix commits (not tracked as separate tasks).

### 4. Planning Quality
- **Rating**: Very Good
- Sprint 33 plan correctly identified the mix of security + features + architecture. SEC-11 was rightly scoped as "infrastructure only" in the plan.

### 5. Model Assignments
- **Rating**: Good
- Sonnet handled most implementation cleanly. Escalation to Opus for Round 4 F55 root-cause analysis was the right call — the double-push bug required careful state tracing across multiple files.

### 6. Communication
- **Rating**: Very Good

### 7. Requirements Clarity
- **Rating**: Good
- Some F55 "back button" requirements only became precise after round 1 testing ("back should always and only go directly to the Manual Scan screen"). Round 1's interpretation was different from the user's mental model.

### 8. Documentation
- **Rating**: Very Good
- CHANGELOG updated per commit. ARCHITECTURE.md updated in the same sprint. SEC-1b backlog note captured.

### 9. Process Issues
- Help screen expanded from 12 → 19 sections over the sprint. Consider capturing sub-section layout (Settings tab mapping) in the sprint plan next time help work is in scope.

---

## What Went Well

- **Security + feature mix**: Keeping the sprint mixed (not pure security) avoided SEC fatigue and let ARCHITECTURE.md updates land organically.
- **Automated test discipline**: 0 analyzer issues across every commit. 1313 tests passing throughout. Round 4's refactor touched core navigation code without breaking any test.
- **Root-cause discipline on the double-push bug**: Three rounds of "surface patches" finally converged on Opus doing the full trace. Lesson: for state-machine bugs, escalate to Opus earlier.
- **SelectionArea + AlertDialog discovery**: A small but annoying Flutter-platform gotcha (dialogs are outside screen-level SelectionArea). Now documented via the in-code comment for future dialog additions.
- **Partial SEC-11 scope**: Shipping just the key-service + opt-in flag now means the SQLCipher driver swap can land in a focused future sprint without redoing the key plumbing. Good sprint-scoping call.

## What Did Not Go Well

- **Round 1's F55 interpretation was wrong**. Back button semantics were ambiguous in the sprint plan ("navigation consistency"), and Round 1 implemented "back goes to Account Selection" when the user wanted "back goes to Manual Scan". Should have clarified upfront.
- **Round 1's auto-push assumption was wrong**. I assumed ScanProgress's existing `build()` auto-push was the only push path. Missing `_startRealScan`'s explicit push caused four rounds of UX regressions.
- **Help sub-section layout drift**: The Help content grew from 12 to 19 sections across rounds. A more thorough first-pass look at Settings (with its 4 tabs and ~15 sub-sections) would have caught this.
- **F53 visibility in UI**: The `.cc` / `.ne` patterns are buried in a 200+ entry header list. Users can't easily verify. Not a bug, but the UI could surface a "recently added" filter in the future.

---

## Action Items

1. **Navigation assumptions** — When touching navigation code, read the existing `Navigator.push`/`pushReplacement` call sites *first* (grep for them) before adding new ones or changing flow. Double-push bugs are painful.
2. **UX sprint plans need back-button spec** — If a sprint's feature summary says "navigation consistency", include the exact expected flow per screen (back from X goes to Y, never Z) in the sprint plan.
3. **Escalate to Opus earlier for state-machine bugs** — After 2 failed surface fixes, switch models. Round 4's full trace took less elapsed time than Rounds 2+3 combined.
4. **Surface filter on Manage Rules** — Backlog candidate: "Recently added" / "Added in last sprint" chip on Manage Rules so users can verify new bundled patterns without scrolling.

---

## Metrics

| Metric | Sprint 32 | Sprint 33 | Delta |
|--------|-----------|-----------|-------|
| Tests passing | 1239 | 1313 | +74 |
| Analyzer issues | 0 | 0 | — |
| Tasks completed | 10 | 12 + 4 UX rounds | +2 tasks |
| Commits | 6 | 8 | +2 |
| Security items closed | 10 | 6 | -4 |
| Features closed | 0 | 4 | +4 |
| Days | 1 | 3 (Apr 14-16) | +2 |

---

## Next Sprint Candidates Highlights

Remaining items visible in the backlog after Sprint 33:

- **F56**: Manual rule creation UI (unblocks SEC-1b manual test)
- **F35**: Rule editing UI with regex generation (HOLD)
- **SEC-11 completion**: SQLCipher driver swap + migration (dedicated QA sprint)
- **SEC-2 through SEC-7, SEC-9, SEC-15, SEC-24**: Remaining security backlog

See `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" for the full prioritized list.
