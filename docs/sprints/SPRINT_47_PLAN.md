# Sprint 47 Plan: Store 0.5.4 manual-testing feedback (F119, F112-F118)

**Sprint**: 47
**Date**: 2026-07-15 (Planning / Phase 1-3)
**Branch**: `feature/20260711_Sprint_47` (created off merged `develop` when Sprint 46 merged; already active)
**PR**: created at Phase 3.3.1 (draft) -- stays DRAFT until end of Phase 7.7 (IMP-2)
**Status**: DRAFT -- pending Harold Phase 3.7 approval

**Scope (Harold-selected, 2026-07-15)**: all 8 items -- **F119, F112, F113, F114, F115, F116, F117, F118** -- captured from Harold's manual testing of the Store-installed 0.5.4 build.

**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

---

## Sprint Objective

Address the 8 items from the Store-0.5.4 manual-testing pass: fix the build-integrity bug that shipped the Store MSIX as dev (F119), improve UX consistency and onboarding defaults (F112-F116), fix the stale Help footer (F117), and complete post-Store-release housekeeping (F118). The result is a corrected build that can be re-released to the Store with proper prod behavior and better new-user defaults.

---

## Sprint Scope (8 items, in priority order)

### Task 1 -- F119: Store MSIX ships as APP_ENV=dev (Priority 8, FIRST)
- **Diagnose FIRST** (per the diagnose-before-patching rule): the two Windows build paths diverge -- `build-windows.ps1` passes `--dart-define=APP_ENV=$Environment` directly (line 228, works), but `msix:create` relies on `msix_config.build_windows_args` in pubspec.yaml. The Store MSIX ran as dev, so either `msix:create` did not forward `build_windows_args` to its inner `flutter build windows`, or a cached dev AOT artifact was packaged. Confirm the actual failure mode before changing anything.
- **Fix**: ensure the supported Store-build path (`flutter pub run msix:create` from the prod worktree) produces an MSIX with `APP_ENV=prod`. If `build_windows_args` is not honored by the installed `msix` package version, switch to a `flutter build windows --dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json` + `msix:create --build-windows false` (or equivalent) sequence documented in STORE_RELEASE_PROCESS.md.
- **Add a build-time/CI assertion**: a prod MSIX must have empty `AppEnvironment.displaySuffix` (no `[DEV]`) and resolve the prod data dir. Prefer a check the release process runs before upload.
- **Verify**: About shows `Version 0.5.x` (no `[DEV]`), clean title bar, prod `MyEmailSpamFilter` data dir.
- **Model**: **Opus** -- *why not cheaper*: native/tooling build-path divergence, packaging semantics, and a "works everywhere except the Store artifact" bug -- exactly the deep-debug class the diagnose-before-patching rule targets; a wrong guess ships another broken Store build.
- **Step-types**: NATIVE-WIN/tooling investigation + fix + release-doc update. **Est-Effort: 90-180m** (NATIVE-WIN is high-variance, 10-15m median but this is investigation-heavy with a Store re-release on the line; padded well above the table).
- **Note**: F119 blocks F113 verification (clean-user default testing needs a correct prod build). Re-release to the Store is a separate Harold action after the fix.

### Task 2 -- F112: "Review No Rule Items" entry point everywhere (Priority 20)
- Reuse the existing `_buildNoRuleReviewButton()` / `_openNoRuleReview()` from `account_selection_screen.dart` (Sprint 46) for consistency; keep `if (Platform.isWindows)` gating.
- (a) Scan History AppBar -- add the icon (currently Refresh/Select Account/Settings/Help only).
- (b) Scan History "No Rule: N" total chip -- small tappable instance centered above it (wrap `_buildTotalChip('No Rule', ...)` ~L340 in a center-aligned Column).
- (c) Shared Settings AppBar (~L254) -- insert just LEFT of the "View Scan History" icon; one insertion covers all four tabs.
- **Model**: **Sonnet** -- *why not Haiku*: three distinct surfaces, one is a non-AppBar chip-overlay layout (needs judgment on the Column wrap), plus widget tests.
- **Step-types**: UI-MOVE x3 (reuse existing widget) + TEST-WIDGET. **Est-Effort: 30-50m.**

### Task 3 -- F113: New-account default profiles, provider-keyed (Priority 22)
- Provider-keyed default-folder map -- AOL: `Inbox, Bulk, Bulk Mail`; Gmail: `INBOX, [Gmail]/Spam, Unwanted` (extensible).
- Manual (common): Read-Only ON; Scan all emails ON (entire mailbox); confirmations ON; Export CSV ON.
- Background (common): Enable Background Scanning OFF; Frequency 15 min; Read-Only ON; Scan all emails OFF, slider last 1 day; Export CSV ON.
- No migration (~1-2 users); change the default constants/seed logic. Depends on F119 for clean-user verification.
- **Model**: **Sonnet** -- *why not Haiku*: provider-keyed default map applied across Manual + Background seed paths (SVC-EDIT across account-creation logic), multiple settings keys, judgment on where defaults are seeded vs read.
- **Step-types**: SVC-EDIT + DATA (default map) + TEST-UNIT. **Est-Effort: 45-90m.**

### Task 4 -- F114: Retention defaults -> 90 days (Priority 24)
- `defaultScanHistoryRetentionDays` 7 -> 90; `defaultUnmatchedRetentionDays` 30 -> 90 (settings_store.dart:82,84). No migration.
- **Model**: **Haiku** -- two constant changes + confirm the settings UI reflects the new default; mechanical.
- **Step-types**: SVC-EDIT + TEST-UNIT. **Est-Effort: 15-30m.**

### Task 5 -- F115: Reorder Review-No-Rule selection bar (Priority 26)
- `_buildSelectionBar` (no_rule_review_screen.dart): `Apply Rule` (left) -> `N selected` -> ~5 spaces -> `Clear`.
- **Model**: **Haiku** -- single-widget Row reorder.
- **Step-types**: UI-MOVE + TEST-WIDGET (adjust existing). **Est-Effort: 15-25m.**

### Task 6 -- F116: Demo Scan completion matches Live Scan (Priority 28)
- On completion, show the summary chips/buttons instead of the results list (currently `scan_progress_screen.dart` renders a `ListView` ~L461 in `isDemoMode`). Drop the intermediate "13/26 processed" count display (not a separate bug once buttons are present).
- **Model**: **Sonnet** -- *why not Haiku*: aligning the demo-mode completion path to the live-scan chip/button flow requires understanding both branches; risk of regressing the live path.
- **Step-types**: UI-MOVE + SVC-EDIT + TEST-WIDGET. **Est-Effort: 30-60m.**

### Task 7 -- F117: Help footer -> app version (Priority 30)
- `help_screen.dart:238` hardcodes "Last updated: Sprint 40 (June 2026)". Preferred: runtime `package_info_plus`. Alternative: gate-enforced `Version X.Y.Z` literal (no new dependency). Consider extending the version-consistency gate to flag stale "Sprint N"/"Last updated" strings.
- **Model**: **Sonnet** -- *why not Haiku*: the `package_info_plus`-vs-gate-literal choice is a small design decision (new dependency vs enforcement); either way, one code edit + optional gate extension.
- **Step-types**: SVC-EDIT/UI-MOVE + (optional) gate extension + TEST-UNIT. **Est-Effort: 30-60m.**

### Task 8 -- F118: Post-Store-release housekeeping (Priority 32)
- CHANGELOG `[Unreleased]` -> `## [0.5.4] - 2026-07-15` + comparison links.
- Dev worktree version bump 0.5.4 -> 0.5.5 (7-file bump per STORE_RELEASE_PROCESS.md Step 1 + version-consistency gate).
- `ALL_SPRINTS_MASTER_PLAN.md` "Last Completed Sprint": record 0.5.4 Store-live outcome.
- Clean up stray gradle-artifact commit (`e925855`) + add `android_legacy_*/.gradle/` to `.gitignore`.
- Refresh/verify `secrets.prod.json` (dated Apr 20) -- Harold action if credentials rotated.
- **Model**: **Haiku** -- mostly mechanical docs/version edits against a documented checklist; the version bump is gate-backstopped.
- **Step-types**: DOCS + version-bump (SVC-EDIT) + HOOK (.gitignore). **Est-Effort: 45-75m.**

---

## Estimated Effort Summary

| Task | Item | Model | Est-Effort (min) |
|------|------|-------|------------------|
| 1 | F119 MSIX APP_ENV=dev | Opus | 90-180 |
| 2 | F112 No-Rule entry point everywhere | Sonnet | 30-50 |
| 3 | F113 New-account default profiles | Sonnet | 45-90 |
| 4 | F114 Retention defaults -> 90d | Haiku | 15-30 |
| 5 | F115 Selection-bar reorder | Haiku | 15-25 |
| 6 | F116 Demo Scan completion | Sonnet | 30-60 |
| 7 | F117 Help footer -> version | Sonnet | 30-60 |
| 8 | F118 Post-release housekeeping | Haiku | 45-75 |
| | **TOTAL** | | **~300-570m (~5-9.5h)** |

**Est-Effort ~300-570m | Est-Wall ~300-570m** (assume serial; F119 first as it blocks F113 verification and gates the Store re-release). Well under the 400-HOUR stopping threshold. F119 dominates and carries the most variance.

## Model Assignments (cheapest-first per Sprint 43 retro IMP-1)

- **Haiku**: F114, F115, F118 -- mechanical constant/UI/doc changes.
- **Sonnet**: F112, F113, F116, F117 -- multi-surface UI, provider-keyed defaults, demo/live-path alignment, footer-source design choice.
- **Opus**: F119 -- native build-path divergence + packaging + Store re-release risk (diagnose-before-patching).
- **Planning / this plan / retro**: **Opus** (per SPRINT_PLANNING.md "Activities Requiring Opus").

## Decision-Class interrupts (NOT pre-authorized -- surface + wait)

- **F119 Store re-release** (Class-3 + release control): the fix requires a version bump and a new Store submission -- that upload is Harold's exclusive action. The sprint fixes + verifies the build; it does not upload.
- **F117 footer source** (Class-2, low): `package_info_plus` (new dependency) vs gate-enforced literal is a development-approach choice; will implement the recommended `package_info_plus` unless Harold prefers otherwise, and note it.
- **F113 verification gate**: default-profile correctness can only be fully verified against a prod build (F119) -- if F119 slips, F113 ships with unit-test verification and a note that clean-user visual verification is pending the corrected build.

## PR lifecycle (per SPRINT_EXECUTION_WORKFLOW.md, IMP-2)

PR created draft at 3.3.1. On 3.7 approval -> update to approved plan (keep DRAFT). End of dev -> update (keep DRAFT). End of 7.7 -> `gh pr ready` (the ONE ready conversion). 7.7.5 -> notify PO/SM. NEVER mark ready earlier.
