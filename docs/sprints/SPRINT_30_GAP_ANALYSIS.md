# Sprint 30 Gap Analysis: Architecture vs Codebase

**Sprint**: 30
**Date**: April 13, 2026
**Issue**: #226 (F60)
**Scope**: docs/adr/ (36 ADRs), docs/ARCHITECTURE.md, docs/ARSD.md vs mobile-app/lib/ codebase

---

## Executive Summary

The documented architecture is largely accurate and well-aligned with the codebase. The core patterns (adapter, provider, database-as-truth, four scan modes, safe-sender priority) are all correctly implemented. However, there are several categories of drift:

1. **Stale documentation** -- ARCHITECTURE.md still documents the Dual-Write pattern removed in Sprint 20
2. **Missing documentation** -- New services and screens added in Sprints 20-29 are not reflected
3. **Dead code** -- Deprecated classes remain in the codebase (duplicate AppPaths, duplicate LocalRuleStore)
4. **ARSD drift** -- Some ARSD sections reference superseded patterns or outdated status
5. **Partially implemented ADRs** -- 10 ADRs are partially implemented, mostly related to Google Play and multi-platform readiness

---

## Gap Categories

### Category 1: Documentation Drift (Docs say X, code does Y)

#### G1. ARCHITECTURE.md: Dual-Write pattern still documented as active

**Severity**: Medium (misleading for anyone reading the architecture docs)

ARCHITECTURE.md extensively documents the Dual-Write pattern (lines 275, 292-293, 316, 318-328, 349, 353, 525, 571) where rules are written to both SQLite and YAML files. This pattern was **removed in Sprint 20** -- the database is now the sole source of truth, and YAML is import/export only.

Specific stale references:
- Section "Dual-Write Pattern (ADR-0004)" with full code flow (lines 318-328)
- `LocalRuleStore` documented as "secondary" storage (lines 275, 316, 525)
- Design Patterns table lists "Dual-Write" as active (line 571)
- `RuleSetProvider` documented with dual-write methods: `addRule(Rule), deleteRule(name): CRUD with dual-write` (line 353)
- Database schema table describes rules and safe_senders as "dual-write from YAML" (lines 292-293)

**What code actually does**: `RuleSetProvider` writes to `RuleDatabaseStore` only. `LocalRuleStore` exists but is legacy dead code. YAML export is available via `YamlExportService` as a manual user action from Settings.

**Backlog impact**: New item needed (documentation update)

#### G2. ARCHITECTURE.md: Last Updated date is February 24, 2026

**Severity**: Low

ARCHITECTURE.md says "Last Updated: February 24, 2026" but significant features have been added in Sprints 20-29 (March-April 2026) that are not reflected:
- F46: Default rule set creation (DefaultRuleSetService) -- not documented
- F48: Scan history multi-account enhancements -- not documented
- F50: Selectable text on all screens -- not documented (UX feature, may not need architecture doc)
- Sprint 20: Database-only rules, YAML dual-write removed -- partially documented (noted in RuleSetProvider line 64 but contradicted elsewhere)

**Backlog impact**: Part of G1 documentation update

#### G3. ARSD.md: Dual-Write still referenced in design patterns table

**Severity**: Low-Medium

ARSD.md Section A5 "Design Patterns in Use" table (line 337) lists:
```
| Dual-Write | RuleDatabaseStore + LocalRuleStore | SQLite primary, YAML secondary | ADR-0004 |
```

This is no longer active. The Glossary (line 753) also defines "Dual-Write" without noting it is superseded.

Additionally, Principle 6 (line 130) references ADR-0004 for "Database as Source of Truth" which is correct in intent but the ADR itself is marked superseded.

**Backlog impact**: Part of documentation update

#### G4. ARSD.md: Store certification status outdated

**Severity**: Low

Section A3 Baseline (line 140) says "Windows Store submission in progress" and Section A8 T1 (line 517) says "Windows Store submission in progress". The Microsoft Store certification **passed on April 4, 2026** and the app is live.

**Backlog impact**: Part of documentation update

#### G5. ARCHITECTURE.md: Missing screens in UI Layer table

**Severity**: Low

The UI Screens table (lines 479-499) lists 19 screens but is missing 2 that exist in the codebase:
- `yaml_import_export_screen.dart` -- YAML import/export UI (exists since early sprints)
- `rule_test_screen.dart` -- Rule testing UI (exists since early sprints)

**Backlog impact**: Part of documentation update

#### G6. ARCHITECTURE.md: Missing new service - DefaultRuleSetService

**Severity**: Low

`DefaultRuleSetService` (added in Sprint 29, F46) is not documented in the Core Services section. This service seeds the database with default rules on first install and supports rule reset.

**Backlog impact**: Part of documentation update

---

### Category 2: Dead/Legacy Code (Code exists that should be cleaned up)

#### G7. Duplicate AppPaths classes

**Severity**: Medium (confusing for developers)

Two `AppPaths` classes exist:
- `mobile-app/lib/config/app_paths.dart` -- **DEPRECATED** (static methods, YAML-only paths)
- `mobile-app/lib/adapters/storage/app_paths.dart` -- **CURRENT** (instance-based, full platform support)

The deprecated `config/app_paths.dart` should be removed if nothing imports it.

**Backlog impact**: New item needed (tech debt cleanup)

#### G8. Duplicate LocalRuleStore classes

**Severity**: Medium

Two `LocalRuleStore` classes exist:
- `mobile-app/lib/core/storage/local_rule_store.dart` -- Minimal version (7 lines)
- `mobile-app/lib/adapters/storage/local_rule_store.dart` -- Full version (51+ lines)

Both are legacy from the Dual-Write era (removed Sprint 20). If neither is actively used for YAML export, both should be removed or consolidated.

**Backlog impact**: Part of tech debt cleanup (G7)

#### G9. Legacy screens in lib/screens/ (outside ui/screens/)

**Severity**: Low

Two OAuth fallback screens exist in `mobile-app/lib/screens/` instead of `mobile-app/lib/ui/screens/`:
- `gmail_webview_oauth_screen.dart` -- WebView-based OAuth backup
- `gmail_manual_token_screen.dart` -- Manual token entry fallback

These are imported by `gmail_oauth_screen.dart` as fallbacks. They should either be:
- Moved to `lib/ui/screens/` for consistency, or
- Documented as intentional legacy location

**Backlog impact**: Part of tech debt cleanup (G7)

---

### Category 3: Partially Implemented ADRs (Architecture defined but not fully built)

#### G10. ADR-0028: Android permissions incomplete

**Severity**: Low (not blocking current Windows/Store work)

ADR-0028 prescribes `POST_NOTIFICATIONS` (dangerous, runtime on Android 13+) and foreground service types for background scanning. Currently `INTERNET` is declared but notification permissions and background service declarations are incomplete.

**Review note**: `POST_NOTIFICATIONS` is not needed initially for Android. Add only when Android background scanning is implemented.

**Backlog coverage**: Partially covered by #163 (Android app testing). Would be fully addressed when Android background scanning is implemented.

#### G11. ADR-0029/0034: Gmail IMAP app password path -- onboarding update needed

**Severity**: Low (code implemented, documentation/UX update needed)

ADR-0029 and ADR-0034 prescribe a phased Gmail access strategy:
- Path 1: Gmail REST API + OAuth (IMPLEMENTED)
- Path 2: Gmail via IMAP with app passwords for general users (IMPLEMENTED -- Sprint 19, Issue #178)
- Path 3: Full OAuth post-CASA verification (DEFERRED)

**Review correction**: Path 2 is already fully implemented. `GenericIMAPAdapter.gmail()` factory exists, platform registry routes `gmail-imap`, and the account setup screen offers dual-auth choice. What remains is updating onboarding/documentation to recommend app passwords as the **primary** approach for all platforms (Windows, Android, iOS), with OAuth as secondary/advanced.

**Backlog coverage**: New item F65 (Gmail onboarding update, P45).

#### G12. ADR-0030: Privacy policy hosting and data deletion

**Severity**: Medium (required for Google Play)

ADR-0030 prescribes hosting privacy policy on myemailspamfilter.com and enabling local-only account deletion. The privacy policy exists on the website but the in-app data deletion feature (ADR-0032) is not yet built.

**Backlog coverage**: Covered by ADR-0032 (GP-11 in Google Play roadmap, currently HOLD).

#### G13. ADR-0033: Firebase Analytics dependency not fully removed

**Severity**: Low

ADR-0033 prescribes removing Firebase Analytics dependency entirely (Option A: zero telemetry). The dependency may still exist in pubspec.yaml even though it is not initialized.

**Backlog coverage**: Covered by GP-12 in Google Play roadmap (currently HOLD).

#### G14. ADR-0035: Dev/prod side-by-side partially implemented

**Severity**: Low

ADR-0035 prescribes full environment separation. `AppEnvironment` class exists and dev/prod data directories work on Windows. However, the full 9-variant matrix (3 stores x 3 channels) described in F52 is not yet implemented.

**Backlog coverage**: Covered by F52 (Priority 90, in backlog).

#### G15. ADR-0032: User data deletion not implemented

**Severity**: Medium (required for Google Play, GDPR/CCPA, and Windows Store)

ADR-0032 prescribes per-account deletion and full data wipe features, plus an external GitHub Pages deletion form. None of these are implemented yet.

**Review note**: External deletion form is a no-op since no user data is stored server-side, but implement if required by store policies.

**Backlog coverage**: Covered by F66 (was GP-11, taken off HOLD -- applies to all platforms including Windows Store).

---

### Category 4: Missing Documentation (Code exists, not documented)

#### G16. ARCHITECTURE.md: RuleConflictDetector/Resolver not documented

**Severity**: Low

`RuleConflictDetector` and `RuleConflictResolver` services exist in the codebase but are not mentioned in the Core Services section of ARCHITECTURE.md.

#### G17. ARCHITECTURE.md: EmailAvailabilityChecker not documented

**Severity**: Low

`EmailAvailabilityChecker` service exists but is not documented. It checks whether unmatched emails still exist in the mailbox.

#### G18. ARCHITECTURE.md: EmailBodyParser not documented

**Severity**: Low

`EmailBodyParser` service exists for extracting text from HTML email bodies but is not documented.

#### G19. ARCHITECTURE.md: DevEnvironmentSeeder not documented

**Severity**: Low

`DevEnvironmentSeeder` service exists for seeding dev environments with production-like data but is not documented.

#### G20. ARCHITECTURE.md: UnmatchedEmailStore not documented

**Severity**: Low

The `unmatched_emails` table and `UnmatchedEmailStore` class exist but are not documented in the database schema section.

#### G21. ARCHITECTURE.md: BackgroundScanLogStore not documented

**Severity**: Low

The `background_scan_log` table and `BackgroundScanLogStore` class exist but are not documented.

#### G22. ARCHITECTURE.md: UI widgets incomplete

**Severity**: Low

The Widgets table lists 4 widgets. The `accessibility_helper.dart` utility in `lib/ui/utils/` is not listed.

---

### Category 5: Unimplemented Architecture (Documented but not built)

#### G23. Responsive design (AR-7)

**Severity**: Medium (required for tablet and multi-form-factor)

ARSD.md Section B4 defines requirement AR-7: "Adaptive layouts for phone (<600dp), tablet (600-900dp), desktop (>900dp)". This is not implemented -- the UI is currently desktop-optimized.

**Backlog coverage**: Partially covered by F55 (navigation consistency). No dedicated responsive design backlog item exists.

#### G24. CI/CD pipeline

**Severity**: Low

ARSD.md Section A6 "Target Additions" lists "GitHub Actions" CI/CD pipeline as "Not started". No backlog item exists.

**Backlog coverage**: Not in backlog.

#### G25. macOS/Linux/iOS platform validation

**Severity**: Low (architecture supports, no validation done)

ARSD.md Gap Analysis table lists macOS, Linux, and iOS as "Architecture supports, untested". These platforms need validation builds and testing.

**Backlog coverage**: Not in backlog as explicit items. Would be addressed when distribution to those platforms is prioritized.

#### G26. OutlookAdapter stub

**Severity**: Low

`OutlookAdapter` exists as a stub class implementing `SpamFilterPlatform` but is not functional. ARSD.md does not mention Outlook.com as a target provider (it is listed as "deferred" in CLAUDE.md).

**Backlog coverage**: Covered by Issue #44 (Outlook.com adapter, open since early project).

---

## Summary Table

| ID | Category | Severity | Description | Backlog Coverage |
|----|----------|----------|-------------|-----------------|
| G1 | Doc Drift | Medium | ARCHITECTURE.md: Dual-Write documented as active | NEW: Doc update needed |
| G2 | Doc Drift | Low | ARCHITECTURE.md: Last Updated stale (Feb 2026) | Part of G1 |
| G3 | Doc Drift | Low-Med | ARSD.md: Dual-Write in design patterns table | Part of G1 |
| G4 | Doc Drift | Low | ARSD.md: Store certification status outdated | Part of G1 |
| G5 | Doc Drift | Low | ARCHITECTURE.md: 2 screens missing from table | Part of G1 |
| G6 | Doc Drift | Low | ARCHITECTURE.md: DefaultRuleSetService missing | Part of G1 |
| G7 | Dead Code | Medium | Duplicate AppPaths classes | NEW: Tech debt cleanup |
| G8 | Dead Code | Medium | Duplicate LocalRuleStore classes | Part of G7 |
| G9 | Dead Code | Low | Legacy screens in wrong directory | Part of G7 |
| G10 | Partial ADR | Low | ADR-0028: Android permissions incomplete | #163 (partial) |
| G11 | Partial ADR | Low | ADR-0029/0034: Gmail IMAP implemented; onboarding update needed | F65 (P45) |
| G12 | Partial ADR | Medium | ADR-0030: Data deletion not built | GP-11 (HOLD) |
| G13 | Partial ADR | Low | ADR-0033: Firebase Analytics not fully removed | GP-12 (HOLD) |
| G14 | Partial ADR | Low | ADR-0035: Full multi-variant not done | F52 (Priority 90) |
| G15 | Partial ADR | Medium | ADR-0032: User data deletion missing | F66 (was GP-11, off HOLD) |
| G16 | Missing Doc | Low | RuleConflictDetector/Resolver undocumented | Part of G1 |
| G17 | Missing Doc | Low | EmailAvailabilityChecker undocumented | Part of G1 |
| G18 | Missing Doc | Low | EmailBodyParser undocumented | Part of G1 |
| G19 | Missing Doc | Low | DevEnvironmentSeeder undocumented | Part of G1 |
| G20 | Missing Doc | Low | UnmatchedEmailStore undocumented | Part of G1 |
| G21 | Missing Doc | Low | BackgroundScanLogStore undocumented | Part of G1 |
| G22 | Missing Doc | Low | UI widgets/utils incomplete | Part of G1 |
| G23 | Unimplemented | Medium | Responsive design (AR-7) | NEW: Backlog item needed |
| G24 | Unimplemented | Low | CI/CD pipeline | NEW: Backlog item needed |
| G25 | Unimplemented | Low | macOS/Linux/iOS validation | No item (future) |
| G26 | Unimplemented | Low | OutlookAdapter stub | #44 (open) |

---

## Recommended Backlog Actions

*Updated after user review on April 13, 2026.*

### New Backlog Items

**F61. Architecture documentation refresh (~3-4h) Priority 50** [APPROVED]
- Update ARCHITECTURE.md:
  - Remove Dual-Write pattern documentation (superseded Sprint 20)
  - Remove LocalRuleStore references from storage adapters section
  - Add DefaultRuleSetService to Core Services section
  - Add missing screens: yaml_import_export_screen, rule_test_screen
  - Add missing services: RuleConflictDetector, RuleConflictResolver, EmailAvailabilityChecker, EmailBodyParser, DevEnvironmentSeeder
  - Add missing database tables: unmatched_emails, background_scan_log
  - Add missing widget: accessibility_helper
  - Update "Last Updated" date
- Update ARSD.md:
  - Remove Dual-Write from Design Patterns table (Section A5, line 337)
  - Update Glossary to mark Dual-Write as superseded
  - Update Store certification status to "Passed" (Section A3, A8)
  - Update ADR-0004 references to note superseded status
- Covers gaps: G1, G2, G3, G4, G5, G6, G16, G17, G18, G19, G20, G21, G22

**F62. Dead code cleanup - remove deprecated classes (~2h) Priority 55** [APPROVED]
- Remove deprecated `config/app_paths.dart` (verify no imports first)
- Remove or consolidate duplicate `LocalRuleStore` classes (both locations)
- Move legacy OAuth screens from `lib/screens/` to `lib/ui/screens/` and update imports
- Verify ADR-0004 is clearly marked as superseded in the ADR file itself
- Covers gaps: G7, G8, G9

**F63. Responsive design framework (~8-12h) Priority 70** [APPROVED]
- Implement adaptive breakpoints per ARSD AR-7: phone (<600dp), tablet (600-900dp), desktop (>900dp)
- Start with LayoutBuilder + breakpoints approach (ARSD A6 recommendation)
- At minimum: scan progress, results display, and settings screens
- Covers gap: G23
- Note: F55 (navigation consistency, Priority 66) should be done before or with this

**F64. CI/CD pipeline with GitHub Actions (~4-6h) Priority 80** [APPROVED - HOLD]
- Set up GitHub Actions for: flutter analyze, flutter test, build verification
- Run on PR to develop
- Covers gap: G24
- HOLD rationale: Current CI/CD equivalent is handled by Claude Code sprint execution workflow (flutter analyze, flutter test, Windows build in Phase 5). Could be implemented later if beneficial to dev team, maintenance team, or instructed by Product Owner.

**F65. Update Gmail onboarding to recommend app passwords as primary (~1-2h) Priority 45** [APPROVED]
- Gmail IMAP with app passwords is already fully implemented (Sprint 19, Issue #178)
- Update account setup screen labels: app passwords as "Recommended", OAuth as "Advanced"
- Update any in-app help text referencing Gmail setup
- Update ADR-0034 status to reflect Path 2 is the primary production path
- Covers gap: G11

**F66. User data deletion feature (~4-6h) Priority 50** [APPROVED - was GP-11, OFF HOLD]
- Per-account deletion: remove all data for a specific email account
- Full data wipe: delete all app data as a complete reset
- External deletion form: GitHub Pages hosted (no-op since all data is local-only, implement only if store requires)
- Applies to all platforms including Windows Store (not just Google Play)
- Covers gaps: G12, G15

**F67. Platform validation - iOS, Linux, macOS (~4-6h per platform) Priority 85** [APPROVED - HOLD]
- Shared tasks (all 3): validation build, smoke test, IMAP scan test, storage path verification, auth flow testing
- iOS-specific: Xcode config, signing, keychain access
- macOS-specific: entitlements, sandbox, notarization
- Linux-specific: desktop entry, packaging (snap/flatpak/AppImage), dependency verification (GTK, libsecret)
- HOLD rationale: No current business need. Activate when distribution is prioritized by Product Owner.
- Covers gap: G25

### Updates to Existing Backlog Items

**F52 (Multi-variant side-by-side)**: No change needed. Already covers G14 (ADR-0035 full implementation).

**Issue #163 (Android app testing)**: Expanded scope to include ADR-0028 permission validation (G10) -- note `POST_NOTIFICATIONS` not needed initially, add when background scanning is implemented. Also include unique UI tests via Playwright/WinWright as needed/appropriate.

**Google Play HOLD items**: G12/G15 moved to F66 (off HOLD, all platforms). G13 remains tracked in GP-12 (HOLD). G11 corrected -- already implemented, onboarding update is F65.

**Issue #44 (Outlook.com adapter)**: G26 is correctly tracked. No change needed.

---

## Architecture Health Score

| Dimension | Score | Notes |
|-----------|-------|-------|
| **Core patterns implemented** | 9/10 | All core patterns working. -1 for dead Dual-Write code still present |
| **ADR compliance** | 26/36 (72%) | 24 fully implemented, 2 process-only, 10 partially implemented |
| **Documentation accuracy** | 7/10 | Major Dual-Write drift, several missing components |
| **Code cleanliness** | 8/10 | A few deprecated duplicates, otherwise well-organized |
| **Backlog coverage of gaps** | Good | Most gaps are already tracked or are documentation-only |

**Overall**: The architecture is sound and well-implemented. The primary gaps are documentation drift (fixable in one sprint) and partially implemented ADRs that are correctly deferred to future work (Google Play, multi-platform).
