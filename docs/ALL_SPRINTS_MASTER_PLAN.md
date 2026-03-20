# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: March 19, 2026 (Sprint 22 retrospective)

## How to Maintain This Document

This section describes when and how to update this document during sprint execution. Referenced by SPRINT_EXECUTION_WORKFLOW.md (Phases 2.1, 3.2, 7.7), SPRINT_CHECKLIST.md, SPRINT_PLANNING.md, and SPRINT_RETROSPECTIVE.md.

### When to Update

| Sprint Phase | What to Update |
|-------------|----------------|
| **Phase 2 (Pre-Kickoff)** | Verify "Last Completed Sprint" is current; confirm all items from completed sprint are marked done or removed |
| **Phase 3 (Planning)** | Review "Next Sprint Candidates" for completeness; add any new items found in GitHub Issues; re-prioritize list; move selected items into sprint plan |
| **Phase 7 (Retrospective)** | Update "Past Sprint Summary" table; update "Last Completed Sprint"; remove completed feature/bug detail sections; add new issues discovered during sprint |
| **Backlog Refinement** | Full review of all sections; re-prioritize; add/remove items; verify GitHub Issue alignment |

### Maintenance Rules

1. **One list of incomplete work**: The "Next Sprint Candidates" section is THE single prioritized list. Do not create duplicate tracking elsewhere in this document.
2. **Remove completed work**: When a feature, bug, or spike is completed, remove its detail section from "Feature and Bug Details". History lives in sprint docs (`docs/sprints/`), CHANGELOG.md, and closed GitHub Issues.
3. **GitHub Issue alignment**: Every item in "Next Sprint Candidates" should reference a GitHub Issue number if one exists. Items without issues get issues created when added to a Sprint Plan.
4. **HOLD items last**: Items on HOLD are grouped at the bottom of the candidates list with a brief reason.
5. **Keep it current**: The "Last Updated" date at the top must reflect the most recent edit. Stale content erodes trust in the document.
6. **Minimal history**: Past Sprint Summary is a table of links. No completed feature details, no completed retrospective actions, no completed MVP feature lists.
7. **Detail sections are optional**: Not every candidate needs a detail section. Simple bugs or small features can be fully described in GitHub Issues alone. Only add detail sections for items that need architecture notes, task breakdowns, or context beyond what fits in a GitHub Issue.
8. **Cross-reference integrity**: When updating this document, verify that SPRINT_EXECUTION_WORKFLOW.md and SPRINT_CHECKLIST.md references remain accurate. Both reference this Maintenance Guide by name.

---

## SPRINT EXECUTION Documentation

**This is part of the SPRINT EXECUTION docs** - the authoritative set of sprint process documentation:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **ALL_SPRINTS_MASTER_PLAN.md** (this doc) | Master plan and backlog for all sprints | Before starting any sprint, after completing a sprint |
| **SPRINT_PLANNING.md** | Sprint planning methodology | When planning a new sprint |
| **SPRINT_EXECUTION_WORKFLOW.md** | Step-by-step execution checklist | During sprint execution (Phases 1-7) |
| **SPRINT_STOPPING_CRITERIA.md** | When/why to stop working | When uncertain if blocked or should continue |
| **SPRINT_RETROSPECTIVE.md** | Sprint review and retrospective guide | After PR submission (Phase 7) |
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | When requested by Product Owner |
| **TESTING_STRATEGY.md** | Testing approach and requirements | When writing or reviewing tests |
| **QUALITY_STANDARDS.md** | Quality standards for code and documentation | When writing code or documentation |
| **TROUBLESHOOTING.md** | Common issues and solutions | When encountering errors or debugging |
| **PERFORMANCE_BENCHMARKS.md** | Performance metrics and tracking | When measuring performance or comparing to baseline |
| **ARCHITECTURE.md** | System architecture and design | When making architectural decisions or understanding codebase |
| **CHANGELOG.md** | Project change history | When documenting sprint changes (mandatory sprint completion) |

---

## Table of Contents

1. [Past Sprint Summary](#past-sprint-summary)
2. [Last Completed Sprint](#last-completed-sprint)
3. [Next Sprint Candidates](#next-sprint-candidates)
4. [Feature and Bug Details](#feature-and-bug-details)
5. [Google Play Store Readiness (HOLD)](#google-play-store-readiness-hold)

---

## Past Sprint Summary

Historical sprint information lives in individual documents in `docs/sprints/` and CHANGELOG.md.

| Sprint | Summary Document | Status | Duration |
|--------|------------------|--------|----------|
| 1 | docs/sprints/SPRINT_1_RETROSPECTIVE.md | [OK] Complete | ~4h (Jan 19-24, 2026) |
| 2 | docs/sprints/SPRINT_2_RETROSPECTIVE.md | [OK] Complete | ~6h (Jan 24, 2026) |
| 3 | docs/sprints/SPRINT_3_SUMMARY.md | [OK] Complete | ~8h (Jan 24-25, 2026) |
| 8 | docs/sprints/SPRINT_8_SUMMARY.md | [OK] Complete | ~12h (Jan 31, 2026) |
| 9 | docs/sprints/SPRINT_9_SUMMARY.md | [OK] Complete | ~2h (Jan 30-31, 2026) |
| 10 | docs/sprints/SPRINT_10_SUMMARY.md | [OK] Complete | ~20h (Feb 1, 2026) |
| 11 | docs/sprints/SPRINT_11_SUMMARY.md | [OK] Complete | ~12h (Jan 31 - Feb 1, 2026) |
| 12 | docs/sprints/SPRINT_12_SUMMARY.md | [OK] Complete | ~48h (Feb 1-6, 2026) |
| 13 | docs/sprints/SPRINT_13_PLAN.md | [OK] Complete | ~3h (Feb 6, 2026) |
| 14 | docs/sprints/SPRINT_14_PLAN.md | [OK] Complete | ~8h (Feb 7-13, 2026) |
| 15 | docs/sprints/SPRINT_15_PLAN.md | [OK] Complete | ~16h (Feb 14-15, 2026) |
| 16 | docs/sprints/SPRINT_16_PLAN.md | [OK] Complete | ~6h (Feb 15-16, 2026) |
| 17 | docs/sprints/SPRINT_17_SUMMARY.md | [OK] Complete | ~20h (Feb 17-21, 2026) |
| 18 | docs/sprints/SPRINT_18_RETROSPECTIVE.md | [OK] Complete | Feb 24-27, 2026 |
| 19 | docs/sprints/SPRINT_19_SUMMARY.md | [OK] Complete | Feb 27 - Mar 15, 2026 |
| 20 | docs/sprints/SPRINT_20_RETROSPECTIVE.md | [OK] Complete | Mar 15-17, 2026 |
| 21 | docs/sprints/SPRINT_21_RETROSPECTIVE.md | [OK] Complete | Mar 18, 2026 |
| 22 | docs/sprints/SPRINT_22_RETROSPECTIVE.md | [OK] Complete | Mar 19, 2026 |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 22** (March 19, 2026)
- **Type**: Research sprint (no code changes)
- **Features**: Windows Store requirements research, codebase gap analysis, backlog items #17-#22 (Issue #191)
- **Backlog Added**: #17 (MSIX config fixes), #18 (MSIX signing ADR), #19 (privacy policy), #20 (store listing assets), #21 (app icon/branding), #22 (Partner Center submission)
- **Tooling Fix**: memory-save/restore/startup-check skills - absolute paths and bash compatibility
- **Retrospective**: docs/sprints/SPRINT_22_RETROSPECTIVE.md

---

## Next Sprint Candidates

**Last Reviewed**: March 19, 2026 (Sprint 22 retrospective)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Windows Store Readiness

**WS-B1. MSIX config fixes (~1h) Priority 20**
- Phase: Windows Store Readiness
- Platform: Windows Desktop
- Enable `store: true` in pubspec.yaml MSIX config
- Fix logo path reference
- Sync msix_version with pubspec version

**WS-B3. MSIX signing strategy ADR (~2h) Priority 22**
- Phase: Windows Store Readiness
- Platform: Windows Desktop
- ADR for code signing approach: MS Store auto-signing vs developer certificate
- Decision impacts CI/CD pipeline and local build workflow

**F28. App icon and branding finalization - ADR-0031 (~2-4h) Priority 24**
- Phase: Windows Store Readiness (also Google Play)
- Platform: All
- Finalize ADR-0031 app icon and visual identity
- Create Store-ready icon assets (300x300+ PNG)

**F29. Register myemailspamfilter.com domain (~1h) Priority 26**
- Phase: Windows Store Readiness (prerequisite)
- Platform: N/A (user action)
- Required for privacy policy hosting (GP-5, WS-B4)
- Issue [#166](https://github.com/kimmeyh/spamfilter-multi/issues/166)

**WS-B4. Privacy policy - write, host, and publish (~4-8h) Priority 30**
- Phase: Windows Store Readiness (also Google Play)
- Platform: All
- [Detail](#ws-b4-privacy-policy)
- Depends on: F29 (domain registration)

**WS-I1. Store listing assets (~3-4h) Priority 32**
- Phase: Windows Store Readiness
- Platform: Windows Desktop
- 4-5 screenshots of key app screens
- 300x300+ logo for Store listing
- App description and short description
- Depends on: F28 (icon/branding finalized)

**WS. Microsoft Partner Center account setup and first submission (~2-4h) Priority 40**
- Phase: Windows Store Readiness
- Platform: Windows Desktop
- Register Microsoft Partner Center account, reserve app name, submit MSIX, complete certification
- Depends on: all other WS items

### Core App

**F30. Safe Senders "Exact Domain" filter shows 0 results (~1-2h) Priority 50**
- Phase: Core App Quality
- Platform: All
- Investigate SafeSenderCategory classification for exact domain patterns
- Filter chip returns no results despite matching data in DB

**F31. Background scan task deleted on rebuild and not re-created (~4-6h) Priority 52**
- Phase: Core App Quality
- Platform: Windows Desktop
- [Detail](#background-scan-task-rebuild-persistence)

**F32. Test coverage analysis and Sprint 20 feature tests (~4-6h) Priority 54**
- Phase: Quality and Testing
- Platform: All
- [Detail](#test-coverage-analysis-and-sprint-20-feature-tests)

**F33. Body rules cleanup script (~4-6h) Priority 56**
- Phase: Core App Quality
- Platform: All
- [Detail](#body-rules-cleanup-script)

**F34. Live Scan: in-progress and completed status indicator (~2-4h) Priority 60**
- Phase: Core Feature
- Platform: All
- Visual indicator (icon or graphic) showing scan is in progress vs completed

**F25. Rule Testing UI Enhancements (~6-8h) Priority 62**
- Phase: Core Feature
- Platform: All
- [Detail](#f25-rule-testing-ui-enhancements)

**F35. Rule editing UI with regex generation (~8-12h) Priority 64**
- Phase: Core Feature
- Platform: All
- [Detail](#rule-editing-ui)

**F36. Settings: Add General tab for app-wide settings (~4-6h) Priority 70**
- Phase: Core Feature
- Platform: All
- [Detail](#settings-general-tab)

**F37. Folder selectors: two-level listing (~6-8h) Priority 72**
- Phase: Core Feature
- Platform: All
- [Detail](#folder-selectors-two-level-listing)

**F38. Live Scan: re-process emails after rule changes (~8-12h) Priority 80**
- Phase: Core Feature
- Platform: All
- [Detail](#live-scan-reprocess-after-rule-changes)

**F7. Multi-Account Scanning (~8-10h) Priority 90**
- Phase: Core Feature
- Platform: All
- [Detail](#f7-multi-account-scanning)

**F6. Provider-Specific Optimizations (~10-12h) Priority 100**
- Phase: Performance
- Platform: All
- [Detail](#f6-provider-specific-optimizations)

### HOLD Items (Android / Google Play Store)

**Issue #163. Android app not tested in several sprints (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Validation sprint needed to verify Android app still works

**F11. Playwright UI Tests + Android UI Testing Strategy (~12-16h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Windows Desktop + Android
- [Detail](#f11-playwright-ui-tests-and-android-ui-testing)

**F4. Background Scanning - Android (~14-16h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- [Detail](#f4-background-scanning-android)

**GP-2. Release Signing and Play App Signing (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-3. Android Manifest Permissions (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-4. Gmail API OAuth Verification / CASA (~40-80h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Trigger: 2,500+ users or $5K/yr revenue

**GP-5. Privacy Policy and Legal Documents (~8-16h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-6. Play Store Listing and Assets (~8-12h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-7. Adaptive Icons and App Branding (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-8. Android Target SDK + 16 KB Page Size (~4-8h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-9. ProGuard/R8 Code Optimization (~4-6h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-10. Data Safety Form Declarations (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

**GP-11. Account and Data Deletion Feature (~8-12h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-12. Firebase Analytics Decision (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-16. Google Play Developer Account Setup (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

### HOLD Items (Post-MVP)

**H1. GenAI Pattern Suggestions - Crowdsourced Spam Intelligence (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#142](https://github.com/kimmeyh/spamfilter-multi/issues/142)

**H2. Rule Pattern Consistency - Domain Matching Standards (~4-6h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#140](https://github.com/kimmeyh/spamfilter-multi/issues/140)

**H3. Requirements Documentation System (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: N/A
- Issue [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137)

**H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)

**H5. Outlook.com OAuth Implementation (~16-20h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44)

**F39. Scan Results: Multi-Select and Bulk Rule Application (~12-16h) Priority HOLD**
- Phase: Post-MVP, Post-Windows Store
- Platform: All (may need platform-specific UI)
- [Detail](#f39-scan-results-multi-select-and-bulk-rule-application)

---

## Feature and Bug Details

This section contains detailed specifications for incomplete items only. Completed features have their details in sprint documents and CHANGELOG.md.

### Folder Selectors: Two-Level Listing (F37)

**Status**: New (Sprint 20 testing feedback)
**Estimated Effort**: ~6-8h
**Phase**: Core Feature
**Platform**: All

**Overview**: Update folder selector UI (used by Safe Sender Folder, Deleted Rule Folder, and Default Folders settings) with context-aware behavior: two-level collapsible folders for Default Folders, and flat lists with provider defaults first for Safe Sender and Deleted Rule folder selectors.

**Part A: Default Folders selector (multi-select for scan)**

Two-level collapsible folder tree:

```
INBOX
Bulk Mail
Bulk Email
[Gmail] >              (expandable group, collapsed by default)
    [Gmail]/Trash
    [Gmail]/Spam
    [Gmail]/Sent Mail
    [Gmail]/Drafts
    [Gmail]/All Mail
Notes >                (expandable group)
    Notes/Work
    Notes/Personal
```

- Top-level folders shown flat (INBOX, Bulk Mail, etc.)
- Folders with children shown as expandable groups (chevron icon)
- Only first level of children shown (not grandchildren)
- Collapsed by default -- user expands to see children
- Junk/Trash folders auto-highlighted regardless of nesting depth
- Non-selectable parent containers (e.g., `[Gmail]`) shown as group headers only

**Part B: Safe Sender Folder and Deleted Rule Folder selectors (single-select)**

Flat list with provider default first:

- **Safe Sender Folder**: Provider default safe sender folder listed first (e.g., INBOX), remaining folders alphabetical, no sub-folders
- **Deleted Rule Folder**: Provider default deleted folder listed first (e.g., Trash or [Gmail]/Trash), remaining folders alphabetical, no sub-folders

Provider defaults:
- AOL: Deleted Rule = Trash, Safe Sender = INBOX
- Gmail IMAP: Deleted Rule = [Gmail]/Trash, Safe Sender = INBOX
- Gmail OAuth: Deleted Rule = TRASH, Safe Sender = INBOX
- Yahoo: Deleted Rule = Trash, Safe Sender = INBOX

**Provider-Specific Folder Hierarchies** (research before implementation):
- **Gmail IMAP**: `[Gmail]/` prefix for system folders. Custom labels may also use `/` hierarchy. Separator: `/`
- **AOL**: Flat folder structure (INBOX, Bulk Mail, Bulk Email, Sent, Trash). No sub-folders typically. Separator: `/`
- **Yahoo**: Flat structure similar to AOL (Inbox, Bulk, Sent, Trash, Draft). Separator: `/`
- **iCloud**: May have nested folders. Separator: `/`
- **Custom IMAP**: Unknown hierarchy -- must handle any structure. Separator: varies (usually `/` or `.`)

**Implementation Note**: The path separator varies by provider and is returned by the IMAP server in `listMailboxes()` response. Use `mailbox.pathSeparator` to split paths into parent/child, do not hardcode `/`.

**Acceptance Criteria**:
- [ ] Research and document actual folder hierarchy for each supported provider before implementation
- [ ] Part A: FolderSelectionScreen groups child folders under their parent (Default Folders only)
- [ ] Part A: Parent folders with children show expand/collapse toggle
- [ ] Part A: Groups collapsed by default, only first-level children shown
- [ ] Part A: Non-selectable parent containers cannot be selected, only expanded
- [ ] Part B: Safe Sender Folder selector shows provider default first, flat list, no sub-folders
- [ ] Part B: Deleted Rule Folder selector shows provider default first, flat list, no sub-folders
- [ ] Part B: Provider defaults configured per provider
- [ ] Path separator detected per-provider (not hardcoded)
- [ ] Works for Gmail IMAP, Gmail OAuth, AOL, Yahoo, and custom IMAP
- [ ] Existing folder selection behavior preserved for providers without sub-folders

---

### Rule Editing UI (F35)

**Status**: New (Sprint 20 testing feedback)
**Estimated Effort**: ~8-12h
**Phase**: Core Feature
**Platform**: All

**Overview**: Add the ability to edit existing rules from the Manage Rules screen. Since rules use regex patterns, the UI must help users who are not familiar with regex syntax.

**Key Features**:
1. **User-friendly input**: User enters a domain, email, or keyword in plain text, and the app generates the correct regex pattern
2. **Regex validation**: If the user edits the regex directly, validate it in real-time and show errors with suggested corrections
3. **Pattern preview**: Show what the pattern would match against sample text (reuse Rule Testing UI from Sprint 18)
4. **Edit dialog**: Tap a rule in Manage Rules > Edit button in details dialog
5. **Field editing**: Edit source_domain (regenerates regex), pattern_category, pattern_sub_type, enabled/disabled

**Acceptance Criteria**:
- [ ] Edit button in rule details dialog opens edit screen
- [ ] Plain-text domain/email input generates correct regex pattern
- [ ] Direct regex editing with real-time validation
- [ ] Invalid regex shows error message with suggested fix
- [ ] Pattern preview shows match results against sample data
- [ ] Changes saved to database
- [ ] Rule name updated if source_domain changes

---

### Live Scan: Re-process Emails After Rule Changes (F38)

**Status**: New (Sprint 20 testing feedback)
**Estimated Effort**: ~8-12h
**Phase**: Core Feature
**Platform**: All

**Overview**: During a live scan, when the user adds or changes a rule from the scan results screen, re-process affected emails asynchronously to apply the new rule action on the server.

**Scenarios**:

1. **New safe sender rule added**: If an email was previously "deleted" (moved to trash/junk) but now matches a safe sender rule, move it to the configured Safe Sender Folder (rescue the email).

2. **New block rule added**: If an email was previously "no rule" or "safe sender" but now matches a block rule, move it to the configured Deleted Rule Folder.

3. **Rule changed/disabled**: If a rule is modified or disabled, re-evaluate affected emails and apply corrective actions.

**Key Design Considerations**:
- Re-processing should be async to avoid blocking the UI
- Show progress indicator during re-processing
- Handle IMAP errors gracefully (email may already be moved/deleted by server)
- Track re-processed emails to avoid duplicate actions
- Consider batch operations for performance (similar to Phase 6b batch execution)
- Only re-process emails from the current scan session (not historical)

**Acceptance Criteria**:
- [ ] After adding a safe sender from scan results, previously deleted emails matching the new pattern are moved to Safe Sender Folder
- [ ] After adding a block rule from scan results, previously unmatched emails matching the new pattern are moved to Deleted Rule Folder
- [ ] Re-processing happens asynchronously without blocking the UI
- [ ] Progress indicator shown during re-processing
- [ ] Scan results display updates to reflect re-processed emails
- [ ] IMAP errors during re-processing are handled gracefully (logged, not fatal)
- [ ] Works for both live scan and historical scan result review

---

### F11: Playwright UI Tests and Android UI Testing

**Status**: HOLD (Android Google Play Store Readiness)
**Estimated Effort**: ~12-16h
**Phase**: Android Google Play Store Readiness
**Platform**: Windows Desktop + Android

**Overview**: Build comprehensive Playwright tests for Windows Desktop UI and determine recommended approach for Android UI testing.

**Key Features**:
- **Windows Desktop (Playwright)**: End-to-end UI tests for all screens (accounts, scanning, results, settings)
- **Android UI Testing Strategy**: Research Flutter integration testing options (Patrol, integration_test, Appium), document recommended approach, implement initial suite

**Dependencies**: Core UI features complete (Sprints 12-17)

**Acceptance Criteria**:
- [ ] Playwright tests cover all Windows Desktop screens
- [ ] Tests run in CI/CD pipeline
- [ ] Android testing approach documented
- [ ] Initial Android UI tests implemented

---

### F4: Background Scanning - Android

**Status**: HOLD (Android Google Play Store Readiness)
**Estimated Effort**: ~14-16h
**Phase**: Android Google Play Store Readiness
**Platform**: Android

**Overview**: Automatic periodic background scanning on Android with user-configured frequency using WorkManager.

**Key Features**:
- WorkManager for periodic background jobs
- Configurable scan frequency (hourly, daily, weekly)
- Battery-aware scheduling (defer when battery low)
- Notification on scan completion with results summary

**Dependencies**: Settings infrastructure (completed Sprint 12)

---

### F6: Provider-Specific Optimizations

**Status**: Idea
**Estimated Effort**: ~10-12h
**Phase**: Performance
**Platform**: All

**Overview**: Provider-specific optimizations leveraging unique API capabilities.

**Potential Features**:
- AOL: Bulk folder operations
- Gmail: Label-based filtering (faster than IMAP folder scans)
- Gmail: Batch email operations via API
- Outlook: Graph API integration (when implemented)

**Dependencies**: Core functionality complete

**Notes**: Defer until MVP complete. May not be needed if current performance acceptable.

---

### F7: Multi-Account Scanning

**Status**: Idea
**Estimated Effort**: ~8-10h
**Phase**: Core Feature
**Platform**: All

**Overview**: Scan multiple email accounts simultaneously (parallel execution).

**Potential Features**:
- Parallel scanning with progress tracking
- Per-account result aggregation
- Unified unmatched email list (with account filtering)

**Dependencies**: Scan Results (completed Sprint 12)

**Notes**: Defer until MVP complete. Current sequential scanning may be sufficient.

---

### Test Coverage Analysis and Sprint 20 Feature Tests (F32)

**Status**: New (Sprint 20 retrospective)
**Estimated Effort**: ~4-6h
**Phase**: Quality and Testing
**Platform**: All

**Overview**: Run test coverage analysis to identify gaps across the codebase, then add targeted tests for Sprint 20 features that shipped without automated test coverage.

**Phase 1: Coverage Analysis**
- Run `flutter test --coverage` and generate coverage report
- Identify files/functions with low or no coverage
- Prioritize gaps by risk (core business logic > UI > utilities)

**Phase 2: Sprint 20 Feature Tests**
- [ ] Classification fields set correctly when creating rules from results_display_screen
- [ ] Classification fields set correctly from email_detail_view quick rule
- [ ] Classification fields set correctly from rule_quick_add_screen
- [ ] Demo rules DB produces expected safe/deleted/no-rule distribution
- [ ] Safe sender folder skip logic (email in folder = skip, email not in folder = show, null config = show all)
- [ ] DB v2 migration idempotent (handles existing columns)
- [ ] YAML export/import preserves classification fields round-trip
- [ ] PlatformRegistry routing for gmail-imap platformId

**Phase 3: General Coverage Gaps**
- Add tests for any high-risk, low-coverage areas identified in Phase 1
- Target: meaningful coverage improvements, not 100% coverage

**Acceptance Criteria**:
- [ ] Coverage report generated and reviewed
- [ ] All Sprint 20 feature tests from Phase 2 implemented
- [ ] High-risk coverage gaps from Phase 3 addressed
- [ ] All tests pass, 0 analyzer issues

---

### Settings: General Tab (F36)

**Status**: New (Sprint 20 retrospective)
**Estimated Effort**: ~4-6h
**Phase**: Core Feature
**Platform**: All

**Overview**: Add a "General" tab to Settings for app-wide settings that apply across all accounts. Move rules management and data management from the Account tab to the General tab.

**Current Structure**:
```
Settings > Account (per-account)
  - Manage Rules (actually app-wide)
  - Manage Safe Senders (actually app-wide)
  - Data Management / Import-Export (actually app-wide)
  - Folder Settings (per-account)
  - Scan Settings (per-account)
  - About
```

**Proposed Structure**:
```
Settings > General (app-wide)
  - Rules Management (renamed from "Manage Rules" + "Data Management")
    - Manage Rules (filter, search, delete)
    - Manage Safe Senders (filter, search, delete)
    - Import/Export Rules (YAML import/export)
  - About

Settings > Account (per-account)
  - Folder Settings
  - Scan Settings
  - Account credentials
```

**Acceptance Criteria**:
- [ ] New "General" tab added to Settings screen
- [ ] Rules Management section moved from Account to General
- [ ] Safe Senders Management moved from Account to General
- [ ] Data Management (YAML Import/Export) moved to General and renamed "Rules Management" or "Import/Export"
- [ ] Account tab retains only per-account settings (folders, scan config, credentials)
- [ ] Navigation from all existing entry points still works
- [ ] Tab order: General first, then Account

---

### Body Rules Cleanup Script (F33)

**Status**: New (Sprint 21 testing feedback)
**Estimated Effort**: ~4-6h
**Phase**: Core App Quality
**Platform**: All

**Overview**: One-time Dart CLI script to clean up body rules. Many body rules are URL-targeting patterns that need better regex (similar to header Exact Domain / Entire Domain patterns but appropriate for URLs in email body content). Other body rules target non-URL body content and should not be affected.

**Issues to Address**:

1. **URL-targeting regex improvement**: Body rules that target URLs should use regex that specifically matches URLs, not arbitrary body text. Non-URL body rules (e.g., keyword matching) should remain unchanged.

2. **Duplicate consolidation**: Patterns like `.adamshetzner.com` and `adamshetzner.com` are duplicates and should be consolidated into a single rule.

**Acceptance Criteria**:
- [ ] Script identifies body rules that are URL-targeting vs non-URL patterns
- [ ] URL-targeting patterns converted to proper URL-matching regex
- [ ] Non-URL body rules left unchanged
- [ ] Duplicate patterns consolidated (e.g., `.domain.com` and `domain.com`)
- [ ] Backup DB before changes
- [ ] Report: patterns converted, duplicates removed, unchanged patterns
- [ ] All tests pass after cleanup

---

### Background Scan Task Rebuild Persistence (F31)

**Status**: New (Sprint 21 post-merge feedback)
**Estimated Effort**: ~4-6h
**Phase**: Core App Quality
**Platform**: Windows Desktop

**Overview**: The Windows Task Scheduler background scan task is deleted during `flutter clean` (which removes the executable) and not reliably re-created after rebuild. The task should be resilient to rebuilds.

**Current Problem**:
1. `flutter clean` removes `build/` directory including `spam_filter_mobile.exe`
2. Task Scheduler task still points to the deleted executable path
3. On rebuild, the executable is at a new path (or same path but Task Scheduler does not know)
4. The task is not automatically re-registered after rebuild
5. `verifyAndRepairTaskPath()` runs on app launch but may delete the task if the path mismatches

**Proposed Solution**:
- Add a post-build step to `build-windows.ps1` that:
  1. Removes the prior Task Scheduler task (for dev/prod as appropriate based on `-Environment`)
  2. Re-creates the task with the new executable path
  3. Uses background scan frequency from the DB settings (if configured)
  4. Leaves the task unregistered if background scanning is turned off in settings
- Environment-aware task names per ADR-0035: `SpamFilterBackgroundScan` (prod) vs `SpamFilterBackgroundScan_Dev` (dev)

**Alternative Approaches to Consider**:
- PowerShell script that reads scan settings from SQLite and re-registers task
- App startup always verifies and re-registers (current approach but unreliable)
- Separate maintenance script: `scripts/register-background-scan.ps1`

**Acceptance Criteria**:
- [ ] After `flutter clean` + rebuild, background scan task is re-registered
- [ ] Task uses correct executable path for the current build
- [ ] Task uses scan frequency from DB settings
- [ ] Task not registered if background scanning is disabled
- [ ] Works for both dev and prod environments (correct task name per ADR-0035)
- [ ] Existing background scan functionality not broken

---

### Windows Store Readiness (Complete - Sprint 22)

**Status**: [OK] Complete (Sprint 22)
**Estimated Effort**: ~8-12h (research + gap analysis; implementation in separate backlog items)
**Phase**: Windows Store Readiness
**Platform**: Windows Desktop

**Overview**: Research all requirements for publishing on the Microsoft Store (Windows Store), perform a deep analysis of the current codebase to identify gaps, and create actionable backlog items to bridge each gap. This includes creating or updating ADRs for architectural decisions required for store compliance.

**Phase 1: Requirements Research (~3-4h)**
- Microsoft Store app submission requirements (2026)
- MSIX packaging requirements and signing
- Store listing requirements (screenshots, descriptions, privacy policy)
- Content policy and app certification requirements
- Age ratings and content declarations
- Accessibility requirements
- Privacy and data handling declarations
- Update and versioning requirements
- Testing and certification process

**Phase 2: Codebase Gap Analysis (~3-4h)**
- Deep analysis of current app against each store requirement
- Review existing MSIX config in pubspec.yaml
- Review app identity, signing, and packaging
- Review privacy policy status (ADR-0030)
- Review data handling declarations
- Review accessibility compliance
- Review app capabilities and permissions
- Identify all gaps with severity (blocking vs nice-to-have)

**Phase 3: Gap Summary and Review (~1-2h)**
- Present findings to user with categorized gaps
- Discuss prioritization and approach for each gap
- Create/update ADRs for architectural decisions needed

**Phase 4: Backlog Item Creation (~1-2h)**
- Create individual backlog items for each gap
- Estimate effort per item
- Identify dependencies between items
- Propose implementation order

**Acceptance Criteria**:
- [ ] All Microsoft Store requirements documented
- [ ] Codebase gap analysis complete with severity ratings
- [ ] Findings reviewed with user
- [ ] ADRs created or updated for store-related architectural decisions
- [ ] Individual backlog items created for each gap
- [ ] Implementation order and dependencies documented

**Note**: This is similar to the existing Google Play Store Readiness section (HOLD items H6-H17) but for the Microsoft Store. Some requirements overlap (privacy policy, data deletion, icons/branding).

---

### WS-B4: Privacy Policy

**Status**: New (Sprint 22 gap analysis)
**Estimated Effort**: ~4-8h
**Phase**: Windows Store Readiness (also Google Play)
**Platform**: All
**Prerequisite**: Domain myemailspamfilter.com must be registered (F29)

**Overview**: Write, host, and publish the privacy policy per ADR-0030 design. Required for both Microsoft Store and Google Play Store submissions.

**Deliverables**:
- Privacy policy content written (based on ADR-0030 zero-telemetry design)
- Hosted at myemailspamfilter.com/privacy (GitHub Pages)
- URL entered in Partner Center and pubspec.yaml
- Covers: email access (transient), credential storage (encrypted), no analytics, no data sharing, data deletion process

**Dependencies**: H0 (domain registration) must be completed first

---

### WS: Implementation Order and Dependencies

**Recommended order for Windows Store publication**:

```
H0: Register domain (USER ACTION - prerequisite)
  |
  v
#17: MSIX config fixes (no dependencies)
#18: Signing strategy ADR (no dependencies)
#21: App icon/branding ADR-0031 (no dependencies)
  |
  v
#19: Privacy policy (depends on H0)
#20: Store listing assets (depends on #21 for icon)
  |
  v
#22: Partner Center account + first submission (depends on all above)
```

**Parallel tracks**: #17, #18, #21 can be done in parallel. #19 and #20 can be done in parallel after their dependencies.

---

### F25: Rule Testing UI Enhancements

**Status**: Planned
**Estimated Effort**: ~6-8h
**Phase**: Core Feature
**Platform**: All

**Overview**: Enhance the Rule Testing screen (Settings > Tools > Test Rule Pattern) with additional capabilities to make it a more complete rule authoring tool.

**Enhancements**:
1. **Example Email Addresses**: Pre-populate the "Match against" list with email addresses from the Demo Scan data, giving users real addresses to test against without needing a live scan
2. **Plain Text to Regex Conversion**: When a user enters a plain text pattern (no regex metacharacters) and presses Enter/Test, automatically convert it to the equivalent regex pattern and display both
3. **Edit Rules with Test Tool**: Add a way to open an existing rule in the test tool from the Manage Rules screen, allowing users to modify and test patterns before saving

**Dependencies**: None (builds on existing Rule Testing UI from Sprint 18)

---

### F39: Scan Results Multi-Select and Bulk Rule Application

**Status**: HOLD (Post-MVP, Post-Windows Store)
**Estimated Effort**: ~12-16h
**Phase**: Post-MVP, Post-Windows Store
**Platform**: All (may need platform-specific UI patterns)

**Overview**: Allow users to select multiple emails in Scan Results (live and history) and apply a rule action to all selected items at once, rather than one at a time.

**Selection Mechanics**:
- Radial button (checkbox) to the left of each item for select/unselect
- Ctrl+click to add individual items to selection (Windows/desktop)
- Shift+click to select a range of items between two clicked items (Windows/desktop)
- Selection applies only to the currently filtered list (respects active filter chips)
- Touch-friendly selection for mobile (long-press to enter selection mode, tap to toggle)

**Bulk Actions (right-click context menu / action bar)**:
7 options:
1. Add Safe Sender - Exact Email
2. Add Safe Sender - Exact Domain
3. Add Safe Sender - Entire Domain
4. Add Block Rule - Exact Email
5. Add Block Rule - Exact Domain
6. Add Block Rule - Entire Domain
7. Remove Current Rule

**Platform-Specific UI Considerations**:
- **Windows Desktop**: Right-click context menu, Ctrl+click and Shift+click selection, radial buttons
- **Android/iOS**: Long-press to enter selection mode, floating action bar for bulk actions, tap to toggle selection
- **Display size**: Compact layouts may need bottom sheet instead of context menu
- UI investigation needed before implementation to determine best pattern per platform

**Dependencies**: Scan Results screen (completed Sprint 12), Rule management (completed Sprint 20)

**Acceptance Criteria**:
- [ ] UI investigation completed: document recommended selection and action patterns per platform
- [ ] Multi-select works with Ctrl+click and Shift+click on desktop
- [ ] Radial button per item for direct select/unselect
- [ ] Selection scoped to current filter results only
- [ ] Right-click (desktop) or action bar (mobile) shows 7 bulk action options
- [ ] Bulk action applies chosen rule to all selected emails
- [ ] Works in both live scan results and scan history views
- [ ] Platform-appropriate UI for Windows, Android, and iOS

---

## Google Play Store Readiness (HOLD)

**Added**: February 15, 2026
**Status**: HOLD -- All GP items are on hold pending Product Owner prioritization
**Objective**: Features, configurations, and policy compliance needed to publish on the Google Play Store.

### Current App Assessment

The app is approximately 60-70% ready for Play Store publication. Core spam filtering functionality is complete and production-ready. The remaining work is primarily administrative (signing, permissions, policies, branding) and compliance-related (Gmail API verification, privacy policy, data safety declarations).

### Gap Analysis Summary

| Area | Current State | Play Store Required | Gap Severity |
|------|--------------|---------------------|-------------|
| Application ID | `com.example.spamfiltermobile` | Unique reverse-domain ID | BLOCKING |
| Release Signing | Debug keys only | Production keystore + Play App Signing | BLOCKING |
| App Bundle Format | APK builds only | AAB (Android App Bundle) required | BLOCKING |
| Privacy Policy | None | Publicly hosted URL required | BLOCKING |
| Gmail OAuth Verification | Unverified (dev-only) | Restricted scope verification + CASA audit | BLOCKING |
| Android Permissions | INTERNET only (debug/profile) | INTERNET, POST_NOTIFICATIONS, WAKE_LOCK, etc. | BLOCKING |
| Data Safety Form | Not started | Required in Play Console | BLOCKING |
| Content Rating | Not started | IARC questionnaire required | BLOCKING |
| App Version | 0.1.0 | Must be 1.0.0+ for release | HIGH |
| Adaptive Icons | No (only legacy mipmap) | Required for Android 8+ (API 26+) | HIGH |
| ProGuard/R8 Rules | None configured | Needed for obfuscation and size | HIGH |
| Store Listing Assets | None | Icon 512x512, feature graphic 1024x500, screenshots | HIGH |
| App Label | `spamfilter_mobile` | User-friendly display name | HIGH |
| Target SDK | Flutter default (~34) | API 35 required now; API 36 expected by Aug 2026 | MEDIUM |
| 16 KB Page Size | Unknown | Required for updates by May 1, 2026 | MEDIUM |

### GP Feature List

GP items on HOLD. When taken off hold, they are added to "Next Sprint Candidates" above.

| ID | Title | Est. Effort | ADR | Priority | Status |
|----|-------|-------------|-----|----------|--------|
| GP-1 | Application Identity and Branding | ~4-6h | ADR-0026 (Accepted) | BLOCKING | [OK] COMPLETE (Sprint 19) |
| GP-2 | Release Signing and Play App Signing | ~4-6h | ADR-0027 (Proposed) | BLOCKING | HOLD |
| GP-3 | Android Manifest Permissions | ~4-6h | ADR-0028 (Proposed) | BLOCKING | HOLD |
| GP-4 | Gmail API OAuth Verification (CASA) | ~40-80h | ADR-0029 (Accepted) | BLOCKING | HOLD -- trigger: 2,500+ users or $5K/yr revenue |
| GP-5 | Privacy Policy and Legal Documents | ~8-16h | ADR-0030 (Accepted) | BLOCKING | HOLD |
| GP-6 | Play Store Listing and Assets | ~8-12h | -- | HIGH | HOLD |
| GP-7 | Adaptive Icons and App Branding | ~4-6h | ADR-0031 (Proposed) | HIGH | HOLD |
| GP-8 | Android Target SDK + 16 KB Page Size | ~4-8h | -- | MEDIUM | HOLD |
| GP-9 | ProGuard/R8 Code Optimization | ~4-6h | -- | HIGH | HOLD |
| GP-10 | Data Safety Form Declarations | ~2-4h | -- | BLOCKING | HOLD |
| GP-11 | Account and Data Deletion Feature | ~8-12h | ADR-0032 (Proposed) | HIGH | HOLD |
| GP-12 | Firebase Analytics Decision | ~2-4h | ADR-0033 (Proposed) | MEDIUM | HOLD |
| GP-13 | Persistent Gmail Auth for Production | 0h | -- | -- | RESOLVED (merged with F12, see ADR-0029/0034) |
| GP-14 | IMAP vs Gmail REST API Decision | 0h | ADR-0034 (Accepted) | -- | RESOLVED (dual-path, no migration needed) |
| GP-15 | Version Numbering and Release Strategy | ~2-4h | -- | HIGH | [OK] COMPLETE (Sprint 19) |
| GP-16 | Google Play Developer Account Setup | ~2-4h | -- | BLOCKING | HOLD |

**Total Estimated Effort**: ~112-202 hours (plus 2-6 months for CASA verification if triggered)

### GP Detail Sections

Full detail for each GP item is preserved below for reference when these items are taken off hold.

#### GP-1: Application Identity and Branding

**Status**: [OK] Completed (Sprint 19, Issue #182)
**ADR**: ADR-0026 (Accepted)

Application rebranded to MyEmailSpamFilter with `com.myemailspamfilter` package. Firebase re-registration deferred until domain is registered (Issue #166).

---

#### GP-2: Release Signing and Play App Signing

**ADR**: ADR-0027 (Proposed)
**Estimated Effort**: ~4-6h

Configure production signing for release builds and enroll in Google Play App Signing.

**Tasks**:
- Generate production keystore (upload key)
- Configure `signingConfigs.release` in `build.gradle.kts`
- Secure keystore file (NEVER commit to git)
- Build AAB (Android App Bundle) instead of APK
- Test signed release build on physical device

---

#### GP-3: Android Manifest Permissions

**ADR**: ADR-0028 (Proposed)
**Estimated Effort**: ~4-6h

Declare all required permissions and implement runtime permission requests.

**Permissions Needed**: INTERNET, POST_NOTIFICATIONS (API 33+), RECEIVE_BOOT_COMPLETED, WAKE_LOCK, FOREGROUND_SERVICE (API 34+), FOREGROUND_SERVICE_DATA_SYNC (API 34+)

---

#### GP-4: Gmail API OAuth Verification (CASA)

**ADR**: ADR-0029 (Accepted)
**Estimated Effort**: ~40-80h (2-6 months elapsed)

Complete Google's three-tier verification for restricted Gmail scopes. CASA security assessment by approved third-party lab.

**ON HOLD** -- Trigger: 2,500+ active Gmail IMAP users at $3/yr or $5,000/yr revenue.

**Cost**: Tier 2 ($500-$1,800/yr), Tier 3 ($4,500-$8,000+/yr)

**Phased approach** (per ADR-0029): Phase 1 uses unverified OAuth for alpha/beta (up to 100 users). Phase 2 adds Gmail app passwords via IMAP for general users. Phase 3 (this GP item) pursues CASA when revenue justifies cost.

---

#### GP-5: Privacy Policy and Legal Documents

**ADR**: ADR-0030 (Accepted)
**Estimated Effort**: ~8-16h

Create and publish privacy policy, terms of service, and data handling documentation required by Play Store and Google API Services User Data Policy.

**Decision** (per ADR-0030): Host on `myemailspamfilter.com` via GitHub Pages. Zero telemetry (remove Firebase Analytics). Indefinite local storage with user-controlled deletion. In-app + web page account deletion. Template-based legal review.

---

#### GP-6: Play Store Listing and Assets

**Estimated Effort**: ~8-12h

Create all required Play Store listing assets: icon (512x512), feature graphic (1024x500), screenshots, descriptions, content rating, Data Safety form.

---

#### GP-7: Adaptive Icons and App Branding

**ADR**: ADR-0031 (Proposed)
**Estimated Effort**: ~4-6h

Create adaptive icons (required for Android 8+), replace legacy mipmap icons, establish visual identity.

---

#### GP-8: Android Target SDK and 16 KB Page Size

**Estimated Effort**: ~4-8h

Update target SDK to API 35+, ensure 16 KB page size compatibility (required by May 1, 2026 for app updates).

---

#### GP-9: ProGuard/R8 Code Optimization

**Estimated Effort**: ~4-6h

Configure R8 for code shrinking, obfuscation, and optimization in release builds.

---

#### GP-10: Data Safety Form Declarations

**Estimated Effort**: ~2-4h (after GP-5 privacy policy)

Complete Google Play Data Safety form. All data is on-device only, no sharing, no advertising SDKs.

---

#### GP-11: Account and Data Deletion Feature

**ADR**: ADR-0032 (Proposed)
**Estimated Effort**: ~8-12h

Implement user account and data deletion (required by Google Play policy). Must be discoverable in-app and via web interface.

---

#### GP-12: Firebase Analytics Decision

**ADR**: ADR-0033 (Proposed)
**Estimated Effort**: ~2-4h

Decide whether to use Firebase Analytics/Crashlytics or remove Firebase dependency. Impacts GP-5 and GP-10 disclosures.

---

#### GP-15: Version Numbering and Release Strategy

**Status**: [OK] Completed (Sprint 19, Issue #181)

Tagged v0.5.0, updated pubspec.yaml to 0.5.0+1, established semver convention.

---

#### GP-16: Google Play Developer Account Setup

**Estimated Effort**: ~2-4h

Register Google Play Developer account ($25 one-time), complete identity verification, set up payment profile.

---

### Architectural Decisions Required

| ADR | Title | Blocking Feature | Status |
|-----|-------|-----------------|--------|
| ADR-0026 | Application Identity and Package Naming | GP-1 | Accepted |
| ADR-0027 | Android Release Signing Strategy | GP-2 | Proposed |
| ADR-0028 | Android Permission Strategy | GP-3 | Proposed |
| ADR-0029 | Gmail API Scope and Verification Strategy | GP-4 | Accepted |
| ADR-0030 | Privacy and Data Governance Strategy | GP-5 | Accepted |
| ADR-0031 | App Icon and Visual Identity | GP-7 | Proposed |
| ADR-0032 | User Data Deletion Strategy | GP-11 | Proposed |
| ADR-0033 | Analytics and Crash Reporting Strategy | GP-12 | Proposed |
| ADR-0034 | Gmail Access Method for Production | GP-14 | Accepted |

### Recommended Sequencing (when taken off hold)

1. **Immediate**: GP-16 (Developer Account) + GP-1 (Application Identity) + ADR-0026
2. **Early**: GP-5 (Privacy Policy) + ADR-0030
3. **Sprint Work**: GP-2, GP-3, GP-7, GP-8, GP-9 (Technical features) + related ADRs
4. **After Privacy Policy**: GP-10 (Data Safety Form) + GP-11 (Account Deletion) + ADR-0032
5. **Before Submission**: GP-6 (Store Listing) + GP-15 (Versioning)
6. **Decision**: GP-12 (Analytics) + ADR-0033
7. **Deferred**: GP-4 (CASA Verification) -- trigger: revenue/user threshold

### Cost Estimates

| Item | Cost | Frequency |
|------|------|-----------|
| Google Play Developer Account | $25 | One-time |
| CASA Security Assessment (Tier 2) | $500-$1,800 | Annual |
| CASA Security Assessment (Tier 3) | $4,500-$8,000+ | Annual |
| Domain registration | $12-$20/year | Annual |
| Privacy policy hosting | $0-$10/month | Monthly (or free via GitHub Pages) |

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 5.0 | 2026-03-19 | Sprint 22: New backlog presentation format (priority-ordered, phase/platform fields, F# identifiers). Assigned F28-F38 to unnamed items. Moved Android/GP items to HOLD. Unholded H0 as F29. Removed old table format. |
| 4.1 | 2026-02-27 | Sprint 18 completion: removed completed items (#154, #141, #167, #168, #169), added F27 (Folder Selection UX), updated Last Completed Sprint and Past Sprint Summary |
| 4.0 | 2026-02-24 | Major restructure: added Maintenance Guide, unified Next Sprint Candidates list, removed completed feature details (F1/F2/F3/F5/F9/F10/F12/F17/F18), removed stale sections (Next Sprint TBD, Issue Backlog, Sprint 11/12 actions), integrated GP items into single priority view, condensed GP details |
| 3.3 | 2026-02-15 | Added Google Play Store Readiness section (GP-1 through GP-16, ADR-0026 through ADR-0034) |
| 3.2 | 2026-02-06 | Sprint 13 completed |
| 3.1 | 2026-02-01 | Added F12 to Sprint 13 |
| 3.0 | 2026-02-01 | Backlog refinement, reprioritized features |
| 2.0 | 2026-01-31 | Restructured to focus on current/future sprints |
| 1.0 | 2026-01-25 | Initial version |
