# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: February 27, 2026 (Sprint 18 completion)

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

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 18** (February 24-27, 2026)
- **PR**: [#170](https://github.com/kimmeyh/spamfilter-multi/pull/170) (targeting develop)
- **Features**: Safe sender/block rule conflict detection (#154), Subject/body content rule standards (#141), Common email provider domains F20 (#167), Inline rule assignment F21 (#168), Rule testing UI F8 (#169), Architecture v2.0 (#164), 5 bug fixes, F22-F26 backlog items
- **Tests**: 1088 passed
- **Retrospective**: docs/sprints/SPRINT_18_RETROSPECTIVE.md

---

## Next Sprint Candidates

**Last Reviewed**: February 27, 2026 (Sprint 18 completion)

All incomplete features, bugs, and spikes in relative priority order. HOLD items grouped at bottom. Each item links to its detail section (if one exists) or GitHub Issue.

### Active Items

| # | Type | Title | Est. Effort | Issue | Detail |
|---|------|-------|-------------|-------|--------|
| 1 | Bug | Android app not tested in several sprints | ~2-4h | [#163](https://github.com/kimmeyh/spamfilter-multi/issues/163) | Validation sprint needed |
| 2 | Enhancement | Manage Rules UI: split combined rules, search, filter | ~12-16h | [#149](https://github.com/kimmeyh/spamfilter-multi/issues/149) | [Detail](#f149-manage-rules-ui-overhaul) |
| 3 | Enhancement | Playwright UI Tests + Android UI Testing Strategy (F11) | ~12-16h | -- | [Detail](#f11-playwright-ui-tests-and-android-ui-testing) |
| 4 | Enhancement | Background Scanning - Android / WorkManager (F4) | ~14-16h | -- | [Detail](#f4-background-scanning-android) |
| 5 | Enhancement | Provider-Specific Optimizations (F6) | ~10-12h | -- | [Detail](#f6-provider-specific-optimizations) |
| 6 | Enhancement | Multi-Account Scanning (F7) | ~8-10h | -- | [Detail](#f7-multi-account-scanning) |
| 7 | Enhancement | Rule Splitting Migration Script (F23) | ~6-8h | -- | [Detail](#f23-rule-splitting-migration-script) |
| 8 | Enhancement | Manage Rules Category Filter Chips (F24) | ~4-6h | -- | [Detail](#f24-manage-rules-category-filter-chips) |
| 9 | Enhancement | Rule Testing UI Enhancements (F25) | ~6-8h | -- | [Detail](#f25-rule-testing-ui-enhancements) |

### Sprint 19 Items

| # | Type | Title | Est. Effort | Issue | Detail |
|---|------|-------|-------------|-------|--------|
| S1 | Enhancement | Folder Selection Save-on-Selection UX (F27) | ~4-6h | [#172](https://github.com/kimmeyh/spamfilter-multi/issues/172) | [Detail](#f27-folder-selection-save-on-selection-ux) |
| S2 | Enhancement | Gmail Dual-Auth UX and Account Tracking (F12B) | ~10-16h | [#178](https://github.com/kimmeyh/spamfilter-multi/issues/178) | [Detail](#f12b-gmail-dual-auth-ux-and-account-tracking) |
| S3 | Enhancement | YAML Rules Import/Export UI in Settings (F22) | ~8-12h | [#179](https://github.com/kimmeyh/spamfilter-multi/issues/179) | [Detail](#f22-yaml-rules-importexport-ui) |
| S4 | Enhancement | Safe Senders Management Filter Chips (F26) | ~4-6h | [#180](https://github.com/kimmeyh/spamfilter-multi/issues/180) | [Detail](#f26-safe-senders-management-filter-chips) |
| S5 | Google Play | Application Identity and Branding (GP-1) | ~4-6h | [#182](https://github.com/kimmeyh/spamfilter-multi/issues/182) | [Detail](#gp-1-application-identity-and-branding) |
| S6 | Google Play | Version Numbering and Release Strategy (GP-15) | ~2-4h | [#181](https://github.com/kimmeyh/spamfilter-multi/issues/181) | [Detail](#gp-15-version-numbering-and-release-strategy) |

### HOLD Items

| # | Type | Title | Est. Effort | Issue | Reason |
|---|------|-------|-------------|-------|--------|
| H0 | Spike | Register myemailspamfilter.com domain | ~1h | [#166](https://github.com/kimmeyh/spamfilter-multi/issues/166) | User action, prerequisite for GP-1 |
| H1 | Enhancement | GenAI Pattern Suggestions - Crowdsourced Spam Intelligence | TBD | [#142](https://github.com/kimmeyh/spamfilter-multi/issues/142) | Post-MVP, research needed |
| H2 | Tech Debt | Rule Pattern Consistency - Domain Matching Standards | ~4-6h | [#140](https://github.com/kimmeyh/spamfilter-multi/issues/140) | Deferred to post-MVP |
| H3 | Enhancement | Requirements Documentation System | TBD | [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137) | Process improvement, not urgent |
| H4 | Enhancement | Sent Messages Scan for Safe Senders | ~12-16h | [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49) | Large feature, post-MVP |
| H5 | Enhancement | Outlook.com OAuth Implementation | ~16-20h | [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44) | New provider, MSAL integration, post-MVP |
| H6 | Google Play | Release Signing and Play App Signing (GP-2) | ~4-6h | -- | GP prerequisite, post-MVP |
| H7 | Google Play | Android Manifest Permissions (GP-3) | ~4-6h | -- | GP prerequisite, post-MVP |
| H8 | Google Play | Gmail API OAuth Verification / CASA (GP-4) | ~40-80h | -- | Trigger: 2,500+ users or $5K/yr revenue |
| H9 | Google Play | Privacy Policy and Legal Documents (GP-5) | ~8-16h | -- | GP prerequisite, post-MVP |
| H10 | Google Play | Play Store Listing and Assets (GP-6) | ~8-12h | -- | GP prerequisite, post-MVP |
| H11 | Google Play | Adaptive Icons and App Branding (GP-7) | ~4-6h | -- | GP prerequisite, post-MVP |
| H12 | Google Play | Android Target SDK + 16 KB Page Size (GP-8) | ~4-8h | -- | GP prerequisite, post-MVP |
| H13 | Google Play | ProGuard/R8 Code Optimization (GP-9) | ~4-6h | -- | GP prerequisite, post-MVP |
| H14 | Google Play | Data Safety Form Declarations (GP-10) | ~2-4h | -- | GP prerequisite, post-MVP |
| H15 | Google Play | Account and Data Deletion Feature (GP-11) | ~8-12h | -- | GP prerequisite, post-MVP |
| H16 | Google Play | Firebase Analytics Decision (GP-12) | ~2-4h | -- | GP prerequisite, post-MVP |
| H17 | Google Play | Google Play Developer Account Setup (GP-16) | ~2-4h | -- | GP prerequisite, post-MVP |

---

## Feature and Bug Details

This section contains detailed specifications for incomplete items only. Completed features have their details in sprint documents and CHANGELOG.md.

### F27: Folder Selection Save-on-Selection UX

**Status**: Planned
**Issue**: [#172](https://github.com/kimmeyh/spamfilter-multi/issues/172)
**Estimated Effort**: ~4-6h

**Overview**: Change "Select Folders to Scan" dialog in Settings (Manual and Background) to instantly save on selection, removing Cancel and "Scan Selected Folder" buttons. Matches UX pattern used by other Settings controls.

**Behavior**:
- "Select All Folders" checked -> instantly check all folders and save
- "Select All Folders" unchecked -> instantly uncheck all folders and save
- Individual folder checked -> clicking unchecks and saves immediately
- Individual folder unchecked -> clicking checks and saves immediately
- Remove Cancel and "Scan Selected Folder" buttons

**Scope**: Settings > Manual Scan and Settings > Background Scan folder selection

---

### F149: Manage Rules UI Overhaul

**Status**: Planned
**Issue**: [#149](https://github.com/kimmeyh/spamfilter-multi/issues/149)
**Estimated Effort**: ~12-16h

**Overview**: Split combined rules into separate views, add search and filter capabilities to the Manage Rules UI.

---

### F12B: Gmail Dual-Auth UX and Account Tracking

**Status**: Planned
**Estimated Effort**: ~10-16h

**Overview**: Implements the dual-path Gmail authentication strategy (ADR-0029, ADR-0034). Adds auth method selection UI, in-app setup walkthroughs for OAuth and app passwords, per-account auth method persistence, and adapter routing. Also removes unused `AuthMethod.apiKey`.

**Tasks**:
- **Task A**: Gmail Auth Method Selection UI (~3-4h) -- choice between OAuth and App Password during Gmail setup
- **Task B**: In-App Setup Walkthrough - Gmail OAuth (~2-3h) -- explains consent screen, 7-day tokens, re-auth
- **Task C**: In-App Setup Walkthrough - Gmail App Password (~2-3h) -- step-by-step Google Account instructions
- **Task D**: Per-Account Auth Method Tracking (~3-4h) -- store and route to correct adapter per account
- **Task E**: Remove Unused Auth Methods (~1-2h) -- remove `AuthMethod.apiKey`, audit dead code

**Dependencies**: ADR-0029 (Accepted), ADR-0034 (Accepted) -- decisions made, ready for implementation

**Acceptance Criteria**:
- [ ] Gmail platform selection offers choice: OAuth or App Password
- [ ] In-app walkthroughs shown for each method
- [ ] Selected auth method stored per Gmail account in database
- [ ] On reconnect/scan, correct adapter used based on stored auth method
- [ ] Gmail IMAP via app password works end-to-end
- [ ] Gmail OAuth continues to work (no regression)
- [ ] `AuthMethod.apiKey` removed from codebase
- [ ] All existing tests pass, new tests added for dual-auth routing

---

### F11: Playwright UI Tests and Android UI Testing

**Status**: Planned
**Estimated Effort**: ~12-16h

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

**Status**: Planned
**Estimated Effort**: ~14-16h
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

**Overview**: Scan multiple email accounts simultaneously (parallel execution).

**Potential Features**:
- Parallel scanning with progress tracking
- Per-account result aggregation
- Unified unmatched email list (with account filtering)

**Dependencies**: Scan Results (completed Sprint 12)

**Notes**: Defer until MVP complete. Current sequential scanning may be sufficient.

---

### F22: YAML Rules Import/Export UI

**Status**: Planned
**Estimated Effort**: ~8-12h

**Overview**: Add user-facing YAML import and export functionality in Settings > Account tab, allowing users to export rules/safe senders to YAML files and import from YAML files.

**Backend State**: `YamlService.exportRules()` and `YamlService.loadRules()` already exist. `YamlExportService` handles dual-write (database + YAML). Missing: UI triggers, file picker, conflict resolution, user feedback.

**Features**:
- Export rules to user-selected directory (with automatic backup)
- Export safe senders to user-selected directory
- Import rules from YAML file with preview and conflict resolution (merge/replace/skip)
- Import safe senders from YAML file
- Validation display before import (show errors/warnings)
- Import status summary (success/failed counts)

**Follow-up**: After import/export is stable, remove duplicate YAML storage (currently rules are stored in both SQLite and YAML asset files). SQLite becomes sole source of truth; YAML used only for import/export.

**Dependencies**: None (backend methods exist)

---

### F23: Rule Splitting Migration Script

**Status**: Planned
**Estimated Effort**: ~6-8h

**Overview**: One-time Dart CLI script to break apart the 4 monolithic rules (`SpamAutoDeleteHeader`, `SpamAutoDeleteFrom`, `SpamAutoDeleteBody`, `SpamAutoDeleteSubject`) into individual, well-named rules based on what each pattern actually blocks.

**Splitting Logic**:
- **SpamAutoDeleteHeader** patterns classified by regex structure:
  - Entire domain (`@(?:[a-z0-9-]+\.)*domain\.com$`) -> `Block_EntireDomain_<domain>`
  - Exact domain (`@domain\.com$`) -> `Block_ExactDomain_<domain>`
  - Exact email (`^user@domain\.com$`) -> `Block_ExactEmail_<user_domain>`
  - TLD (`\.<tld>$`) -> `Block_TopLevelDomain_<tld>`
- **SpamAutoDeleteFrom** patterns: Convert from `from:` to `header:` matching, then same classification
- **SpamAutoDeleteBody** patterns: `BlockBody_<cleaned_regex>` (use cleaned-up regex as name)
- **SpamAutoDeleteSubject** patterns: `BlockSubject_<cleaned_regex>` (use cleaned-up regex as name)
- Skip duplicates (if target rule name already exists)
- Remove migrated patterns from original monolithic rules

**Deliverable**: Dart CLI script in `scripts/` directory, run once, produces updated `rules.yaml`

**Dependencies**: F22 (YAML Import/Export UI) for reimporting the split rules into the app database

---

### F24: Manage Rules Category Filter Chips

**Status**: Planned
**Estimated Effort**: ~4-6h

**Overview**: Replace current "Header"/"Body"/"Subject" filter chips in Settings > Manage Rules with more meaningful categories that match the new rule naming convention from F23.

**New Filter Categories**:
- "Block Email" - rules matching `Block_ExactEmail_*`
- "Block Exact Domain" - rules matching `Block_ExactDomain_*`
- "Block Entire Domain" - rules matching `Block_EntireDomain_*`
- "Block Top Level Domains" - rules matching `Block_TopLevelDomain_*`
- "Block Body" - rules matching `BlockBody_*`
- "Block Subject" - rules matching `BlockSubject_*`
- "Other" - all rules not in the above categories

**Dependencies**: F23 (Rule Splitting Migration) must run first so rules have the new naming convention

---

### F25: Rule Testing UI Enhancements

**Status**: Planned
**Estimated Effort**: ~6-8h

**Overview**: Enhance the Rule Testing screen (Settings > Tools > Test Rule Pattern) with additional capabilities to make it a more complete rule authoring tool.

**Enhancements**:
1. **Example Email Addresses**: Pre-populate the "Match against" list with email addresses from the Demo Scan data, giving users real addresses to test against without needing a live scan
2. **Plain Text to Regex Conversion**: When a user enters a plain text pattern (no regex metacharacters) and presses Enter/Test, automatically convert it to the equivalent regex pattern and display both
3. **Edit Rules with Test Tool**: Add a way to open an existing rule in the test tool from the Manage Rules screen, allowing users to modify and test patterns before saving

**Dependencies**: None (builds on existing Rule Testing UI from Sprint 18)

---

### F26: Safe Senders Management Filter Chips

**Status**: Planned
**Estimated Effort**: ~4-6h

**Overview**: Add filter chips to Settings > Account > Manage Safe Senders to categorize safe sender rules by their pattern type, making it easier to browse and manage large lists.

**Filter Categories**:
- "Exact Email" - patterns matching a specific email address (e.g., `^user@domain\.com$`)
- "Exact Domain" - patterns matching an exact domain (e.g., `^[^@\s]+@domain\.com$`)
- "Entire Domain" - patterns matching domain and all subdomains (e.g., `^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$`)
- "Top Level Domains" - patterns matching TLDs (e.g., `\.edu$`, `\.gov$`)
- "Other" - all rules not matching the above categories

**Note**: These categories should replace current "Domain" / "Domain + Subdomains" labels with the more user-friendly names above.

**Dependencies**: None

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
| GP-1 | Application Identity and Branding | ~4-6h | ADR-0026 (Accepted) | BLOCKING | RELEASED - Active Item #15 |
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
| GP-15 | Version Numbering and Release Strategy | ~2-4h | -- | HIGH | RELEASED - Active Item #16 |
| GP-16 | Google Play Developer Account Setup | ~2-4h | -- | BLOCKING | HOLD |

**Total Estimated Effort**: ~112-202 hours (plus 2-6 months for CASA verification if triggered)

### GP Detail Sections

Full detail for each GP item is preserved below for reference when these items are taken off hold.

#### GP-1: Application Identity and Branding

**ADR**: ADR-0026 (Accepted)
**Estimated Effort**: ~4-6h

Change the application from development defaults to production-ready identity.

**Decision**: Domain `myemailspamfilter.com`, Application ID `com.myemailspamfilter`, App Name `MyEmailSpamFilter`.

**Tasks**:
- Task A: Update `applicationId` to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- Task B: Update `namespace` to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- Task C: Update `android:label` to `MyEmailSpamFilter` in `AndroidManifest.xml`
- Task D: Update `msix_config` in `pubspec.yaml` to match new identity
- Task E: Re-register with Firebase Console under new application ID and download new `google-services.json`

**Prerequisite**: Domain `myemailspamfilter.com` must be registered first (Issue #166 -- spike).

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

**Status**: Released from HOLD (Active Item #16)
**Estimated Effort**: ~2-4h

Set initial release version, establish versionCode numbering, plan release track strategy.

**Decision**: Current main release (Sprint 18 + hotfix #176) is designated **v0.5.0**.

**Tasks**:
- Task A: Tag current main as v0.5.0
- Task B: Update pubspec.yaml version to 0.5.0+1
- Task C: Create CHANGELOG.md release section for v0.5.0
- Task D: Establish versioning convention going forward (semver)

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
| 4.1 | 2026-02-27 | Sprint 18 completion: removed completed items (#154, #141, #167, #168, #169), added F27 (Folder Selection UX), updated Last Completed Sprint and Past Sprint Summary |
| 4.0 | 2026-02-24 | Major restructure: added Maintenance Guide, unified Next Sprint Candidates list, removed completed feature details (F1/F2/F3/F5/F9/F10/F12/F17/F18), removed stale sections (Next Sprint TBD, Issue Backlog, Sprint 11/12 actions), integrated GP items into single priority view, condensed GP details |
| 3.3 | 2026-02-15 | Added Google Play Store Readiness section (GP-1 through GP-16, ADR-0026 through ADR-0034) |
| 3.2 | 2026-02-06 | Sprint 13 completed |
| 3.1 | 2026-02-01 | Added F12 to Sprint 13 |
| 3.0 | 2026-02-01 | Backlog refinement, reprioritized features |
| 2.0 | 2026-01-31 | Restructured to focus on current/future sprints |
| 1.0 | 2026-01-25 | Initial version |
