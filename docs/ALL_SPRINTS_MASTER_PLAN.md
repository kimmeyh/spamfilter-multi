# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: April 14, 2026 (Sprint 32 code review findings -- added SEC-1b, F72)

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
| 23 | docs/sprints/SPRINT_23_RETROSPECTIVE.md | [OK] Complete | Mar 20, 2026 |
| 24 | docs/sprints/SPRINT_24_RETROSPECTIVE.md | [OK] Complete | Mar 20-21, 2026 |
| 25 | docs/sprints/SPRINT_25_RETROSPECTIVE.md | [OK] Complete | Mar 22, 2026 |
| 26 | docs/sprints/SPRINT_26_RETROSPECTIVE.md | [OK] Complete | Mar 22-24, 2026 |
| 27 | docs/sprints/SPRINT_27_RETROSPECTIVE.md | [OK] Complete | Mar 29 - Apr 2, 2026 |
| 28 | docs/sprints/SPRINT_28_RETROSPECTIVE.md | [OK] Complete | Apr 2, 2026 |
| 29 | docs/sprints/SPRINT_29_RETROSPECTIVE.md | [OK] Complete | Apr 3-13, 2026 |
| 30 | docs/sprints/SPRINT_30_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |
| 31 | docs/sprints/SPRINT_31_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |
| 32 | docs/sprints/SPRINT_32_RETROSPECTIVE.md | [OK] Complete | Apr 13, 2026 |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 32** (April 13, 2026)
- **Type**: Security Hardening (code + process)
- **Feature**: 10 security items from Sprint 31 audit (Issue #230)
- **Delivered**: SEC-1 (ReDoS), SEC-10 (YAML file size), SEC-12 (token revocation), SEC-13 (fail-fast OAuth), SEC-16 (dependency scanning), SEC-17 (auth logging), SEC-18 (silent regex logging), SEC-20 (email validation), SEC-21 (password length), SEC-23 (Windows hardening)
- **Tests**: +13 (1239 total passing)
- **Process improvements**: Added automated code review (Phase 5.1.1), Copilot review response (Phase 6.4.1), Opus-required activities documentation
- **Retrospective**: docs/sprints/SPRINT_32_RETROSPECTIVE.md

---

## Next Sprint Candidates

**Last Reviewed**: April 13, 2026 (Sprint 32 completion -- removed 10 completed security items)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Core App

**F52. Multi-variant side-by-side install across all stores (~16-24h) Priority 90**
- Phase: Build and Release Infrastructure
- Platform: All (Windows, Android, iOS)
- Extend ADR-0035 dev/prod separation to all 9 build variants (3 stores × 3 channels: dev, production, store)
- All variants must run simultaneously without rebuild on same machine/device
- [Detail](#f52-multi-variant-side-by-side-install)

**F53. Add block rules for top-level domains .cc and .ne (~1h) Priority 60**
- Phase: Core Feature
- Platform: All
- Add `@.*\.cc$` (.cc = Cocos (Keeling) Islands) and `@.*\.ne$` (.ne = Nigeria) block rule patterns
- Update bundled rules.yaml asset (new user default bundle)
- Add to current user's rules database (migration or runtime insert for existing installs)
- Mirrors existing `@.*\.ru$` pattern
- Target: Sprint 30

**F54. Add icon to Select Account screen icon row (~1-2h) Priority 64**
- Phase: UX Improvement
- Platform: All
- Current icon row: View Scan History (history), Settings (gear), Exit Application
- Add a new icon+tooltip to the AppBar actions row
- Needs: icon choice, tooltip/label, navigation target
- Design decision: what action should this trigger? (account management, add account, etc.)

**F56. Manual rule creation UI - block and safe sender rules from user input (~10-14h) Priority 68**
- Phase: Core Feature
- Platform: All
- Add UI for creating rules directly from user input (not just from scan results)
- Block rules (4 types):
  - Top-level domain: user enters TLD (e.g., .cc, .ru) and app creates `@.*\.cc$` pattern
  - Exact domain: user pastes email address or domain string, app extracts domain and creates `@domain\.com$` pattern with confirmation
  - Entire domain: user pastes email address, domain, or URL, app extracts domain and creates `@(?:[a-z0-9-]+\.)*domain\.com$` subdomain-matching pattern with confirmation
  - Exact email: user enters email address, app validates format, creates `^user@domain\.com$` pattern with confirmation
- Safe sender rules (3 types, no TLD):
  - Exact domain: same as block but adds to safe senders
  - Entire domain: same as block but adds to safe senders
  - Exact email: same as block but adds to safe senders
- App should parse and extract domain from various input formats: email address, bare domain, URL with protocol, URL with path
- Validation: email format check, domain format check, warn if TLD-only for safe senders
- Confirmation dialog showing generated pattern before saving
- Accessible from Manage Rules and Manage Safe Senders screens
- Related: F35 (rule editing UI), F25 (rule testing UI enhancements)

**F55. Screen navigation consistency - linear flow + push/pop icons (~4-6h) Priority 66**
- Phase: UX Improvement
- Platform: All
- Two navigation models: linear scan flow (back returns up chain) and icon navigation (push/pop returns to origin)
- Linear flow: Select Account -> Manual Scan -> Live Scan Results; back buttons return one step up
- Icon navigation: Settings, Scan History, Select Account icons push onto stack; back pops to origin
- Current issues:
  - Results back button uses pushReplacement instead of pop (breaks stack)
  - "Back to Accounts" button on Results skips Manual Scan via popUntil
  - Results -> Manual Scan auto-navigation on scan complete should be push (not pushReplacement)
- Consider: keep "Back to Accounts" as convenience shortcut or remove for consistency?
- Consider: "Scan Again" pushReplacement is correct (avoids stack bloat on repeated scans)
- Consider: does the user need a Select Account icon on Manual Scan and Results screens?
- Related: F54 (add icon to Select Account screen)

**F61. Architecture documentation refresh (~3-4h) Priority 50**
- Phase: Documentation
- Platform: All
- Update ARCHITECTURE.md: remove Dual-Write pattern (superseded Sprint 20), add missing services (DefaultRuleSetService, RuleConflictDetector, EmailAvailabilityChecker, EmailBodyParser, DevEnvironmentSeeder), add missing screens (yaml_import_export, rule_test), add missing DB tables (unmatched_emails, background_scan_log)
- Update ARSD.md: remove Dual-Write from design patterns table, update Store certification status to "Passed", update Glossary
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gaps G1-G6, G16-G22)

**F62. Dead code cleanup - remove deprecated classes (~2h) Priority 55**
- Phase: Tech Debt
- Platform: All
- Remove deprecated config/app_paths.dart (duplicate of adapters/storage/app_paths.dart)
- Remove or consolidate duplicate LocalRuleStore classes (core/storage/ and adapters/storage/)
- Move legacy OAuth screens from lib/screens/ to lib/ui/screens/ or remove if unused
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gaps G7-G9)

**F72. Code hygiene cleanup (~1-2h) Priority 72**
- Phase: Tech Debt
- Platform: All
- Minor cleanup items identified in Sprint 32 Phase 5.1.1 automated code review:
  - Remove emoji `📦` in secure_credentials_store.dart:527 (violates CLAUDE.md "No emojis" rule)
  - Add `if(MSVC) ... endif()` guard around security flags in windows/runner/CMakeLists.txt for MinGW future-proofing
  - SEC-20: Soften email validation error messages in account_setup_screen.dart -- current messages are prescriptive about email format in ways that are technically incorrect for RFC 5321 edge cases; use generic "Please enter a valid email address" or stricter regex
- Source: Sprint 32 Phase 5.1.1 automated code review (H3 + Minor Notes)

**F63. Responsive design framework (~8-12h) Priority 70**
- Phase: UX Improvement
- Platform: All
- Implement adaptive breakpoints per ARSD AR-7: phone (<600dp), tablet (600-900dp), desktop (>900dp)
- LayoutBuilder + breakpoints approach (ARSD A6 recommendation)
- Priority screens: scan progress, results display, settings
- Related: F55 (navigation consistency) should be done before or with this
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G23)

**F65. Update Gmail onboarding to recommend app passwords as primary (~1-2h) Priority 45**
- Phase: UX Improvement
- Platform: All
- Gmail IMAP with app passwords already fully implemented (Sprint 19, Issue #178)
- Update account setup screen: app passwords as "Recommended", OAuth as "Advanced"
- Update in-app help text and ADR-0034 status
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G11)

**F66. User data deletion feature (~4-6h) Priority 50**
- Phase: Core Feature / Compliance
- Platform: All (Windows Store, Google Play, all platforms)
- Per-account deletion: remove all data for a specific email account
- Full data wipe: delete all app data as a complete reset
- External deletion form: GitHub Pages hosted (no-op since all data is local-only, implement only if store requires)
- Was GP-11, taken off HOLD -- applies to Windows Store too
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gaps G12, G15)

### Testing

**F69. E2E WinWright desktop tests - scan flows, history, settings (~6-8h) Priority 58**
- Phase: Testing / Quality
- Platform: Windows
- E2E tests using WinWright (desktop accessibility automation):
  - Manual scan: run scan, navigate to Scan History, tap the scan entry, verify displayed counts match
  - Background scan: trigger background scan, navigate to Scan History, tap the background scan entry, verify displayed counts match (validates Sprint 31 fix for stale results bug)
  - Select email address: verify account selection flow
  - Settings: test all settings on all tabs (General, Scan, Background, Account overrides)
- Source: Sprint 31 manual testing feedback (scan history showed wrong results for background scan)

### Security Hardening (Sprint 31 Audit)

**SEC-1b. ReDoS runtime protection - integrate safeHasMatch into evaluator (~6-10h) Priority 35 -- CRITICAL**
- Phase: Security
- Platform: All
- Sprint 32 added `PatternCompiler.safeHasMatch()` (timeout via Isolate.run) + `detectReDoS()` authoring-time validation
- **Gap**: `safeHasMatch` is defined but not used in production. Hot path (`RuleEvaluator`, `RuleConflictDetector`, `SafeSenderEvaluator`) still calls `regex.hasMatch()` directly
- **Design work needed**: Isolate-per-match is too slow for the evaluator iterating rules x messages. Options:
  - Shared isolate/worker pool for pattern matching
  - Batch-level timeout (abort entire batch if any match exceeds threshold)
  - Opt-in per-pattern timeout for user-supplied patterns only (trusted bundled patterns use direct hasMatch for speed)
- **Blocks**: F56 (manual rule creation), F35 (rule editing) -- currently have authoring-time protection but no runtime protection if a dangerous pattern slips through
- Source: Sprint 32 Phase 5.1.1 automated code review (finding C1)

**SEC-4. Android: Create network_security_config.xml (~1h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Block cleartext traffic, pin domains for OAuth and IMAP
- Reference in AndroidManifest.xml
- Source: Sprint 31 security audit (S11)


**SEC-6. Android: Configure release signing (~2h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Create release keystore, configure in build.gradle.kts
- Overlaps with GP-2 (release signing)
- Source: Sprint 31 security audit (S12)

**SEC-7. Android: Enable R8 obfuscation + Dart obfuscation (~2h) Priority 40 -- HIGH**
- Phase: Security
- Platform: Android
- Enable minifyEnabled, create proguard-rules.pro
- Use --obfuscate --split-debug-info for Dart
- Overlaps with GP-9 (ProGuard/R8)
- Source: Sprint 31 security audit (S13)

**SEC-8. Certificate pinning for OAuth and IMAP endpoints (~4-6h) Priority 42 -- HIGH**
- Phase: Security
- Platform: All
- Pin certs for accounts.google.com, oauth2.googleapis.com, imap.gmail.com, imap.aol.com
- Source: Sprint 31 security audit (S14)

**SEC-9. Move hardcoded Android client ID to build-time injection (~1h) Priority 42 -- HIGH**
- Phase: Security
- Platform: Android
- Move _androidClientId to --dart-define or google-services.json
- Source: Sprint 31 security audit (S5)

**SEC-11. SQLite database encryption (~4-8h) Priority 60 -- MEDIUM**
- Phase: Security
- Platform: All
- Implement SQLCipher or encrypt sensitive fields before storage
- Source: Sprint 31 security audit (S7)

**SEC-14. Unmatched emails: retention limit + body preview truncation (~2h) Priority 62 -- MEDIUM**
- Phase: Security / Privacy
- Platform: All
- Auto-cleanup old unmatched_emails, limit body_preview to 100 chars
- Source: Sprint 31 security audit (S8)

**SEC-15. IMAP host validation for custom servers (~1h) Priority 62 -- MEDIUM**
- Phase: Security
- Platform: All
- Reject internal/private IP ranges when custom IMAP is implemented
- Dependency: F37 (folder selectors / custom IMAP)
- Source: Sprint 31 security audit (S19)

**SEC-19. Log level control: runtime disable for auth logging (~1-2h) Priority 65 -- MEDIUM**
- Phase: Security
- Platform: All
- Add configuration to disable auth logging in production
- Source: Sprint 31 security audit (S28)

**SEC-22. Rate limiting on failed auth attempts (~2h) Priority 80 -- LOW**
- Phase: Security
- Platform: All
- Exponential backoff after 3+ failed logins per account
- Source: Sprint 31 security audit (S22)

**F6. Provider-Specific Optimizations (~10-12h) Priority 100**
- Phase: Performance
- Platform: All
- [Detail](#f6-provider-specific-optimizations)

**F64. CI/CD pipeline with GitHub Actions (~4-6h) Priority HOLD**
- Phase: DevOps
- Platform: All
- GitHub Actions workflow for: flutter analyze, flutter test, build verification
- Trigger on PR to develop
- HOLD rationale: Current CI/CD equivalent is handled by Claude Code sprint execution workflow (flutter analyze, flutter test, Windows build in Phase 5). Could be implemented later if beneficial to dev team, maintenance team, or instructed by Product Owner.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G24)

### HOLD Items (Periodic Reviews)

**F70. Periodic Security Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Security Spike (reusable template)
- Platform: All
- **Generic scope**: Security review based on Application Development Best Practices and OWASP Mobile Top 10 (use current year edition)
- **Application-specific scope**:
  - Dependency CVEs (flutter pub outdated, known vulnerability databases)
  - SQL injection and parameterization audit
  - Regex injection and ReDoS pattern review
  - Credential storage and logging audit
  - Platform-specific security: Windows 11 Store (MSIX sandbox, AppContainer), Android (APK/AAB signing, manifest permissions, ProGuard), iOS (App Transport Security, keychain, sandbox), Linux (file permissions, desktop integration)
  - App store compliance: Microsoft Store certification requirements, Google Play data safety policies, Apple App Store review guidelines
  - Device-specific concerns: biometric auth, secure enclave, clipboard access, screenshot protection
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic security review is needed.
- Source: Sprint 31 retrospective feedback

**F71. Periodic Architecture Deep Dive (~4-8h per review) Priority HOLD**
- Phase: Architecture Spike (reusable template)
- Platform: All
- **Generic scope**: Architecture review based on Application Development Best Practices
- **Application-specific scope**:
  - ADR drift detection: compare all ADRs against current codebase implementation
  - ARCHITECTURE.md alignment: verify documented components, services, and patterns match code
  - ARSD.md alignment: verify architectural requirements and standards document is current
  - Platform-specific architecture: Windows 11 Store (MSIX packaging, single-instance mutex, app data paths), Android (activity lifecycle, WorkManager, flavors), iOS (SwiftUI/UIKit bridge, entitlements, provisioning), Linux (GTK integration, libsecret, packaging)
  - App store constraints: store-specific sandboxing, capability declarations, update mechanisms
  - Device constraints: screen size breakpoints, input methods (touch, mouse, keyboard), offline capability
  - Dead code and deprecated class detection
  - Test coverage gaps relative to architecture
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for next review.
- HOLD rationale: Template item. Duplicate when periodic architecture review is needed.
- Source: Sprint 31 retrospective feedback (based on Sprint 30 architecture deep dive experience)

### HOLD Items (Post-Windows Store)

**F33. Body rules cleanup script (~4-6h) Priority HOLD**
- Phase: Core App Quality
- Platform: All
- Post-Windows Store release
- [Detail](#body-rules-cleanup-script)

**F25. Rule Testing UI Enhancements (~6-8h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#f25-rule-testing-ui-enhancements)

**F35. Rule editing UI with regex generation (~8-12h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#rule-editing-ui)

**F37. Folder selectors: two-level listing (~6-8h) Priority HOLD**
- Phase: Core Feature
- Platform: All
- Post-Windows Store release
- [Detail](#folder-selectors-two-level-listing)

### HOLD Items (Android / Google Play Store)

**Issue #163. Android app not tested in several sprints (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Validation sprint needed to verify Android app still works
- Expanded scope (Sprint 30 review): ADR-0028 permission validation (POST_NOTIFICATIONS not needed initially, add when background scanning implemented)
- Expanded scope (Sprint 30 review): Include unique UI tests via Playwright/WinWright as needed/appropriate

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

**GP-11. Account and Data Deletion Feature** -- Moved to F66 (off HOLD, all platforms including Windows Store). See F66 in Core App section above.

**GP-12. Firebase Analytics Decision (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: All

**GP-16. Google Play Developer Account Setup (~2-4h) Priority HOLD**
- Phase: Android Google Play Store Readiness
- Platform: Android

### HOLD Items (Multi-Platform)

**F67. Platform validation - iOS, Linux, macOS (~4-6h per platform) Priority HOLD**
- Phase: Multi-Platform Readiness
- Platform: iOS, Linux, macOS
- Shared tasks (all 3): validation build, smoke test, IMAP scan test, storage path verification, auth flow testing
- iOS-specific: Xcode config, signing, keychain access for credentials
- macOS-specific: entitlements, sandbox config, notarization requirements
- Linux-specific: desktop entry, packaging (snap/flatpak/AppImage), dependency verification (GTK, libsecret)
- HOLD rationale: No current business need. Activate when distribution is prioritized by Product Owner.
- Source: Sprint 30 gap analysis (SPRINT_30_GAP_ANALYSIS.md gap G25)

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

### F52: Multi-Variant Side-by-Side Install

**Status**: New (April 8, 2026)
**Estimated Effort**: ~16-24h (phased per platform)
**Phase**: Build and Release Infrastructure
**Platform**: All (Windows, Android, iOS)

**Overview**: Extend the existing dev/prod separation (ADR-0035, Windows only) to support all 9 build variants -- 3 channels (dev, production, store) across 3 platforms (Windows, Android, iOS) -- running simultaneously on the same machine/device without rebuilds.

**The 9 Variants**:

| Platform | Dev (feature/develop) | Production (main) | Store (downloaded) |
|----------|----------------------|-------------------|--------------------|
| Windows | [OK] Built today | [OK] Built today | Microsoft Store install |
| Android | TBD | TBD | Google Play install |
| iOS | TBD | TBD | App Store install |

**Current State**:
- **Windows dev/prod**: ADR-0035 implemented in Sprint 19. Same .exe path, but different `secrets.*.json` builds use different data dirs (`MyEmailSpamFilter` vs `MyEmailSpamFilter_Dev`), task names, and mutexes. Whichever was built last is what runs.
- **Windows store**: MSIX submitted to Microsoft Store (Sprint 28). Installs to `Packages\{PackageFamilyName}\` -- separate from dev/prod data dirs.
- **Android**: Single applicationId (`com.example.my_email_spam_filter`). No flavors configured.
- **iOS**: Not yet built.

**Problem**: A user/developer needs to be able to run any combination of these 9 variants simultaneously to:
- Compare dev vs prod behavior on same data
- Test store version against local builds without uninstalling
- Reproduce store-only bugs while a fix is in dev
- Demonstrate prod features while continuing dev work

The Windows dev/prod current implementation requires a rebuild to switch -- only one is "current" at a time.

**Industry Best Practices**:

**Android (Build Flavors)** -- See [Android docs](https://developer.android.com/build/build-variants):
- Use `productFlavors` in `build.gradle.kts` with distinct `applicationIdSuffix` per flavor
- Example: `com.example.app` (store), `com.example.app.prod` (sideloaded prod), `com.example.app.dev` (dev)
- Each variant gets its own data directory, app icon, and Launcher entry
- Side-by-side install works automatically on the same device
- Use Manifest Placeholders for distinct app names (e.g., "SpamFilter", "SpamFilter PROD", "SpamFilter DEV")

**iOS (Bundle ID + Targets/Configurations)** -- See [Xcode multi-config](https://medium.com/@danielgalasko/run-multiple-versions-of-your-app-on-the-same-device-using-xcode-configurations-1fd3a220c608):
- iOS identifies apps by bundle identifier; cannot have two apps with the same ID
- Create distinct bundle IDs per variant: `com.example.spamfilter`, `com.example.spamfilter.prod`, `com.example.spamfilter.dev`
- Use Xcode build configurations or separate targets to switch bundle ID at build time
- Each variant becomes a distinct app on the device with its own data, icon, and TestFlight stream
- TestFlight typically uses a `.test` or `.beta` suffix to avoid colliding with App Store releases

**Windows (MSIX Package Family + Distinct .exe Names)**:
- MSIX uses `PackageFamilyName` for identity. Different `Identity Name` values produce distinct sandboxed installs.
- For non-MSIX (sideloaded) builds, distinct .exe filenames + distinct install directories enable coexistence
- Currently: `MyEmailSpamFilter.exe` is the same filename for dev and prod (only data dirs differ)
- Recommendation: build to environment-specific subdirs (`Release-dev/`, `Release-prod/`) and use environment-specific .exe names (`MyEmailSpamFilter.exe`, `MyEmailSpamFilter-Dev.exe`)

**Cross-Platform Pattern**:
1. **Single source tree, build-time variants**: Use Flutter's `--dart-define` + `flutter run --flavor` for entry points
2. **Distinct identifiers per variant**: applicationId/bundle ID/package family
3. **Distinct visual markers**: app name, icon overlay (e.g., yellow stripe for dev, red for staging)
4. **Distinct data isolation**: separate data dirs (already done for Windows; automatic for Android/iOS via OS)
5. **Build matrix in CI**: each push to `main` builds prod variants, each push to `develop` builds dev variants

**Key Decisions Needed (during sprint planning)**:
1. **Naming convention**: `SpamFilter` (store) / `SpamFilter Pro` (sideloaded prod) / `SpamFilter Dev` (dev)? Or use suffixes?
2. **Build artifact location**: Should dev and prod Windows builds output to separate dirs to enable coexistence without rebuild?
3. **Icon variants**: Acceptable to ship 3 icon designs (or icon overlays generated at build time)?
4. **Store identifier strategy**: Reserve all bundle IDs in advance (App Store Connect, Google Play Console, Microsoft Partner Center)?

**Implementation Phases**:

**Phase 1: Windows distinct .exe + distinct dirs (~4-6h)**
- Update `build-windows.ps1` to output to `build/windows/x64/runner/Release-{env}/`
- Rename .exe to `MyEmailSpamFilter.exe` (prod) and `MyEmailSpamFilter-Dev.exe` (dev) at build time
- Verify Microsoft Store MSIX is unaffected (it installs separately)
- Update launch scripts and docs to reference env-specific paths
- Test: prod and dev builds present simultaneously, both runnable

**Phase 2: Android flavors (~6-8h)**
- Configure `productFlavors` in `mobile-app/android/app/build.gradle.kts`
- Define `dev`, `prod`, `store` flavors with distinct `applicationIdSuffix`
- Add Manifest Placeholder for app name
- Generate distinct icons per flavor (or use icon overlay)
- Update build scripts (`build-with-secrets.ps1`) to take a flavor parameter
- Test: install all 3 variants on emulator side-by-side
- Note: Cannot fully test "store" flavor until app is in Google Play (use `prod` flavor as proxy with different applicationId)

**Phase 3: iOS bundle IDs (~6-10h, requires macOS)**
- Configure Xcode build configurations or targets for `dev`, `prod`, `store`
- Set distinct bundle IDs per configuration
- Configure provisioning profiles for each variant
- Update CI to build correct variant per branch
- Note: Requires Apple Developer Program account and reserved bundle IDs
- HOLD until iOS development begins

**Acceptance Criteria**:
- [ ] Windows: dev, prod, and store builds all installable and runnable simultaneously
- [ ] Android: dev, prod, and store flavors all installable and runnable simultaneously on emulator
- [ ] iOS: dev, prod, and store configurations defined (full validation deferred to iOS dev)
- [ ] All 9 variants have distinct data directories (no cross-contamination)
- [ ] All 9 variants have visual markers (different name and/or icon)
- [ ] Build scripts updated to support variant selection
- [ ] Documentation updated: ADR (extend ADR-0035 or create new ADR), CLAUDE.md, build script READMEs
- [ ] No regression in existing dev/prod Windows separation
- [ ] CI builds correct variant per branch (main = prod+store, develop = dev)

**Dependencies**:
- iOS phase blocked until iOS development begins
- Android store flavor blocked until app is published to Google Play
- Windows store flavor already in place (MSIX from Sprint 28)

**Notes**:
- Phase 1 (Windows) is the only phase that can be done now without external dependencies
- Phases 2 and 3 should be combined with broader Android/iOS work
- Consider whether "store" flavor is really needed as a separate build, or if the actual store-downloaded app suffices

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
| 5.6 | 2026-04-14 | Sprint 32 code review findings: Added SEC-1b (ReDoS runtime protection -- design work needed) and F72 (code hygiene cleanup -- emoji, MSVC guard, email message softening) from Phase 5.1.1 automated code review. |
| 5.5 | 2026-04-13 | Sprint 32 completion: Removed 10 completed security items (SEC-1/10/12/13/16/17/18/20/21/23). Added Sprint 32 to Past Sprint Summary. Updated Last Completed Sprint. |
| 5.4 | 2026-04-13 | Sprint 31 retrospective: Added F70 (Periodic Security Deep Dive template) and F71 (Periodic Architecture Deep Dive template) as HOLD items. |
| 5.3 | 2026-03-24 | Sprint 26: Marked F7, F36, F43, F44, F45, F47 complete. Removed F7/F36/F45/F47 detail sections. Added F48 (scan history enhancements). Updated Last Completed Sprint. |
| 5.2 | 2026-03-22 | Sprint 25: Marked F30, F31, F34, F38, F40, F41 complete. Removed F31/F32/F38 detail sections. Added F42 (coverage gaps, on hold). Updated Last Completed Sprint. |
| 5.1 | 2026-03-21 | Sprint 24: Marked WS items complete. Added F40, F41. Updated Last Completed Sprint. |
| 5.0 | 2026-03-19 | Sprint 22: New backlog presentation format (priority-ordered, phase/platform fields, F# identifiers). Assigned F28-F38 to unnamed items. Moved Android/GP items to HOLD. Unholded H0 as F29. Removed old table format. |
| 4.1 | 2026-02-27 | Sprint 18 completion: removed completed items (#154, #141, #167, #168, #169), added F27 (Folder Selection UX), updated Last Completed Sprint and Past Sprint Summary |
| 4.0 | 2026-02-24 | Major restructure: added Maintenance Guide, unified Next Sprint Candidates list, removed completed feature details (F1/F2/F3/F5/F9/F10/F12/F17/F18), removed stale sections (Next Sprint TBD, Issue Backlog, Sprint 11/12 actions), integrated GP items into single priority view, condensed GP details |
| 3.3 | 2026-02-15 | Added Google Play Store Readiness section (GP-1 through GP-16, ADR-0026 through ADR-0034) |
| 3.2 | 2026-02-06 | Sprint 13 completed |
| 3.1 | 2026-02-01 | Added F12 to Sprint 13 |
| 3.0 | 2026-02-01 | Backlog refinement, reprioritized features |
| 2.0 | 2026-01-31 | Restructured to focus on current/future sprints |
| 1.0 | 2026-01-25 | Initial version |
