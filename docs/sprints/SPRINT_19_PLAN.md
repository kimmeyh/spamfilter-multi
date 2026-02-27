# Sprint 19 Plan

**Sprint**: Sprint 19 - Dual-Auth, Import/Export, Branding, and UX Polish
**Date**: February 27, 2026
**Branch**: `feature/20260227_Sprint_19`
**Base**: `develop`
**Estimated Total Effort**: ~32-50h

---

## Sprint Goal

Expand Gmail authentication options with dual-auth (OAuth + App Password), add YAML import/export UI, establish production branding and versioning, and polish UX with save-on-selection folders and safe sender filter chips.

---

## Tasks

### Task A: Version Numbering and Release Strategy (GP-15)

**Issue**: [#181](https://github.com/kimmeyh/spamfilter-multi/issues/181)
**Estimated Effort**: ~2-4h
**Model**: Sonnet
**Value**: This establishes the versioning foundation all future releases depend on.

**Acceptance Criteria**:
- [ ] Current main tagged as v0.5.0
- [ ] pubspec.yaml version updated to 0.5.0+1
- [ ] CHANGELOG.md release section created for v0.5.0
- [ ] Versioning convention documented (semver)

**Risks**: Low - documentation and configuration only

---

### Task B: Application Identity and Branding (GP-1)

**Issue**: [#182](https://github.com/kimmeyh/spamfilter-multi/issues/182)
**Estimated Effort**: ~4-6h
**Model**: Sonnet
**Value**: This enables production-ready identity for distribution and Google Play preparation.

**Acceptance Criteria**:
- [ ] applicationId updated to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- [ ] namespace updated to `com.myemailspamfilter` in `android/app/build.gradle.kts`
- [ ] android:label updated to `MyEmailSpamFilter` in AndroidManifest.xml
- [ ] msix_config updated in pubspec.yaml to match new identity
- [ ] Windows and Android builds succeed with new identity

**Risks**: Medium - changing applicationId may affect Firebase registration, existing installed apps. Mitigation: test both platforms after change.

**Note**: Firebase re-registration (Task E in GP-1 detail) deferred until domain is registered (Issue #166, on hold). App identity changes can proceed independently.

---

### Task C: Folder Selection Save-on-Selection UX (F27)

**Issue**: [#172](https://github.com/kimmeyh/spamfilter-multi/issues/172)
**Estimated Effort**: ~4-6h
**Model**: Sonnet
**Value**: This prevents user confusion from the current 2-step save workflow in folder selection.

**Acceptance Criteria**:
- [ ] "Select All Folders" toggle instantly checks/unchecks all folders and saves
- [ ] Individual folder toggle instantly saves on click
- [ ] Cancel and "Scan Selected Folder" buttons removed
- [ ] Applies to both Manual Scan and Background Scan folder selection in Settings
- [ ] Existing tests updated, new tests for instant-save behavior

**Risks**: Low - UI change with clear behavior specification

---

### Task D: Safe Senders Management Filter Chips (F26)

**Issue**: [#180](https://github.com/kimmeyh/spamfilter-multi/issues/180)
**Estimated Effort**: ~4-6h
**Model**: Sonnet
**Value**: This enables users to quickly find and manage safe sender rules in large lists.

**Acceptance Criteria**:
- [ ] Filter chips displayed on Settings > Account > Manage Safe Senders screen
- [ ] Filter categories: "Exact Email", "Exact Domain", "Entire Domain", "Top Level Domains", "Other"
- [ ] Filters are combinable (multi-select)
- [ ] Clear all filters option
- [ ] Categories replace current "Domain" / "Domain + Subdomains" labels
- [ ] New tests for filter chip categorization logic

**Risks**: Low - additive UI feature with clear categorization rules

---

### Task E: YAML Rules Import/Export UI in Settings (F22)

**Issue**: [#179](https://github.com/kimmeyh/spamfilter-multi/issues/179)
**Estimated Effort**: ~8-12h
**Model**: Opus
**Value**: This enables users to backup, share, and restore their rule configurations.

**Acceptance Criteria**:
- [ ] Settings screen has Import Rules and Export Rules options
- [ ] Export rules to user-selected directory (with automatic backup)
- [ ] Export safe senders to user-selected directory
- [ ] Import rules from YAML file with preview and conflict resolution (merge/replace/skip)
- [ ] Import safe senders from YAML file
- [ ] Validation display before import (show errors/warnings)
- [ ] Import status summary (success/failed counts)
- [ ] File picker for selecting import/export locations
- [ ] All existing tests pass, new tests for import/export workflows
- [ ] **Integration test**: Export ALL existing rules to YAML, then import all rules back and verify they match exactly (round-trip fidelity test)

**Risks**: Medium - file system access, YAML parsing edge cases, conflict resolution logic. Mitigation: leverage existing YamlService backend methods, add validation before import.

---

### Task F: Gmail Dual-Auth UX and Account Tracking (F12B)

**Issue**: [#178](https://github.com/kimmeyh/spamfilter-multi/issues/178)
**Estimated Effort**: ~10-16h
**Model**: Opus
**Value**: This enables Gmail users to choose between OAuth and App Password, removing the Google verification blocker for wider distribution.

**Acceptance Criteria**:
- [ ] Gmail platform selection offers choice: OAuth or App Password
- [ ] In-app walkthroughs shown for each auth method
- [ ] Selected auth method stored per Gmail account in database
- [ ] On reconnect/scan, correct adapter used based on stored auth method
- [ ] Gmail IMAP via app password works end-to-end
- [ ] Gmail OAuth continues to work (no regression)
- [ ] `AuthMethod.apiKey` removed from codebase
- [ ] All existing tests pass, new tests added for dual-auth routing
- [ ] **In-app walkthrough instructions** for Gmail App Password setup that are: (1) current as of February 2026, (2) verified accurate via walk-through, (3) step-by-step with no ambiguity
- [ ] **Integration test**: End-to-end test covering auth method selection, persistence, and correct adapter routing
- [ ] **User verification**: May need user assistance for final verification of setup steps (acceptable reason to pause)

**Risks**: High - touches authentication layer, adapter routing, database schema. Mitigation: implement incrementally (selection UI first, then routing, then cleanup), test each step. Walkthrough instructions are critical -- have been done wrong before and must be verified accurate.

---

## Execution Order

1. **Task A** (GP-15) - Version numbering first (foundation, low risk)
2. **Task B** (GP-1) - App identity (foundation, medium risk)
3. **Task C** (F27) - Folder selection UX (independent, low risk)
4. **Task D** (F26) - Safe sender filter chips (independent, low risk)
5. **Task E** (F22) - YAML import/export (medium complexity)
6. **Task F** (F12B) - Gmail dual-auth (highest complexity, last)

---

## Sprint Scope Notes

- **Total estimated effort**: ~32-50h across 6 tasks
- **This is an ambitious sprint** - if time runs short, Tasks E and F may carry over
- **Stretch goal**: None (scope is already substantial)
- **Dependencies**: Task B depends on Task A (version must be set before identity changes)
