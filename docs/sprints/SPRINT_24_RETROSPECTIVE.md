# Sprint 24 Retrospective

**Sprint**: Sprint 24 - Windows Store Readiness: Privacy Policy, Store Assets, Submission
**Date**: March 20-21, 2026
**Branch**: `feature/20260320_Sprint_24`
**Issue**: #197

---

## Sprint Goal

Complete the remaining Windows Store readiness items: write and publish the privacy policy, create store listing assets, and submit the app to the Microsoft Store via Partner Center.

## Outcome: [OK] COMPLETE

All tasks completed. App submitted for Microsoft Store certification.

---

## Tasks Completed

### Task A: WS-B4 - Privacy Policy Website
- **Status**: [OK] Complete
- **Effort**: Delegated to Sonnet subagent
- Privacy policy website created at docs/website/
- Files: index.html (landing), privacy/index.html (policy), delete/index.html (deletion)
- CNAME configured for myemailspamfilter.com GitHub Pages hosting
- Contact email (kimmeyh@outlook.com) added to privacy policy contact section

### Task B: WS-I1 - Store Listing Assets
- **Status**: [OK] Complete
- **Effort**: Collaborative (Haiku + User)
- Short description (89 chars): "Filter spam from multiple email providers using customizable rules. Works offline."
- Long description (1,914 chars): Multi-paragraph covering features, providers, privacy, offline operation
- 5 screenshots captured from Windows Desktop app
- Store logos: 1080x1080 and 2160x2160 PNG versions
- Keywords, age ratings, product features documented
- All assets stored in docs/STORE_LISTING_ASSETS.md

### Task C: WS - Partner Center Account and Submission
- **Status**: [OK] Complete
- **Effort**: Collaborative (Haiku + User)
- Microsoft Store developer account created (kimmeyh@outlook.com)
- App name "MyEmailSpamFilter" reserved
- Store ID: 9N5QK9G904C0
- Publisher: Kimmey Consulting - Ohio (CN=84EA8722-0CA5-4EC0-9B10-07EE79B66062)
- MSIX package built and uploaded (v0.5.1.0)
- All listing sections completed: availability, properties, age ratings, packages, store listing
- Submission sent for certification (2026-03-21)

### Task D: Documentation and Release Notes
- **Status**: [OK] Complete
- CHANGELOG.md updated with Sprint 24 entries
- Sprint 24 retrospective created
- ALL_SPRINTS_MASTER_PLAN.md updated

### Additional Work (Unplanned)
- **Executable rename**: spam_filter_mobile -> MyEmailSpamFilter (CMakeLists.txt, Runner.rc, Package.appxmanifest, build-windows.ps1)
- **Dart package rename**: spam_filter_mobile -> my_email_spam_filter (pubspec.yaml + 224 imports across 73 files)
- **msix dependency added**: msix v3.16.8 as dev dependency
- **pubspec.yaml identity update**: Partner Center publisher, identity_name, publisher_display_name
- **Bug found**: Safe sender matches showing in results for Gmail IMAP (Issue #198)

---

## Test Results

- **All tests passing**: 1145 tests passed, 28 skipped
- **Flutter analyze**: 0 issues
- **Windows build**: MyEmailSpamFilter.exe builds and launches successfully
- **MSIX build**: my_email_spam_filter.msix built successfully with store: true

---

## What Went Well

1. **Privacy policy website**: Delegating to Sonnet subagent was efficient and produced a comprehensive, well-structured website
2. **Store listing collaboration**: User-Claude collaboration on descriptions, screenshots, and Partner Center walkthrough was effective
3. **Executable rename**: Large rename (224 imports) completed cleanly with zero test failures
4. **MSIX packaging**: First MSIX build for Store submission succeeded after fixing duplicate capability issue
5. **Documentation**: STORE_LISTING_ASSETS.md provides a comprehensive reference for all Store submission details

## What Did Not Go Well

1. **Partner Center onboarding**: Significant friction with Microsoft Partner Center registration
   - Initial registration with AOL email created a general Partner Center account, not a Windows developer account
   - "Apps and Games" workspace did not appear after initial registration
   - Had to discover the new onboarding flow at storedeveloper.microsoft.com
   - Required creating a new Microsoft account (kimmeyh@outlook.com)
2. **EXE vs MSIX product type**: First product was created as "EXE or MSI" instead of "MSIX or PWA", requiring deletion and recreation
3. **runFullTrust duplicate**: msix package auto-adds runFullTrust capability, causing MSIX build failure when it was also in pubspec.yaml capabilities list
4. **Bug discovery during testing**: Safe sender matches appearing in Gmail IMAP results (Issue #198) - not a sprint regression but found during verification

## Lessons Learned

1. **Microsoft Partner Center**: The registration flow changed significantly. The correct entry point for new individual developers is https://storedeveloper.microsoft.com (not partner.microsoft.com)
2. **Product type selection**: When creating a new product in Partner Center, carefully select "MSIX or PWA" for Flutter desktop apps, not "EXE or MSI"
3. **msix package behavior**: The msix Flutter package auto-adds runFullTrust as a restricted capability. Do not also list it in pubspec.yaml capabilities to avoid duplicate key errors
4. **flutter clean required**: When renaming the CMake project/binary, must run flutter clean before rebuilding to clear cached CMake targets

## Metrics

- **Duration**: ~6 hours across 2 sessions
- **Files changed**: ~80+ (primarily from package rename)
- **Tests**: 1145 passing (no regressions)
- **Issues created**: 1 (Issue #198 - safe sender bug)
- **Commits**: TBD (will be counted at PR time)

---

## Store Submission Status

- **Submitted**: 2026-03-21
- **Expected certification**: 1-3 business days
- **Discoverability**: Direct link only (soft launch)
- **Pricing**: Free
- **Markets**: United States
