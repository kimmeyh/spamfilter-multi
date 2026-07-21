# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: 2026-07-20 (Sprint 48 F119-b hotfix complete; 0.5.6 SUBMITTED for certification; Last-Completed-Sprint rolled 46 -> 48 -- see Version History 6.10)

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
| 33 | docs/sprints/SPRINT_33_RETROSPECTIVE.md | [OK] Complete | Apr 14-16, 2026 |
| 34 | docs/sprints/SPRINT_34_RETROSPECTIVE.md | [OK] Complete | Apr 17-18, 2026 |
| 35 | docs/sprints/SPRINT_35_RETROSPECTIVE.md | [OK] Complete | Apr 19, 2026 |
| 36 | docs/sprints/SPRINT_36_RETROSPECTIVE.md | [OK] Complete | Apr 20-25, 2026 |
| 37 | docs/sprints/SPRINT_37_RETROSPECTIVE.md | [OK] Complete | Apr 27 - May 1, 2026 |
| 38 | docs/sprints/SPRINT_38_RETROSPECTIVE.md | [OK] Complete | May 5-18, 2026 |
| 39 | docs/sprints/SPRINT_39_RETROSPECTIVE.md | [OK] Complete | May 18-25, 2026 (PR #260) |
| 40 | docs/sprints/SPRINT_40_PLAN.md | [OK] Complete | ~Jun 2026 (PR #261) |
| 41 | docs/sprints/SPRINT_41_RETROSPECTIVE.md | [OK] Complete | Jun 13-17, 2026 (PR #262) |
| 42 | docs/sprints/SPRINT_42_RETROSPECTIVE.md | [OK] Complete | Jun 20, 2026 (PR #263) |
| 43 | docs/sprints/SPRINT_43_RETROSPECTIVE.md | [OK] Complete | Jun 23-26, 2026 (PR #265) |
| 44 | docs/sprints/SPRINT_44_RETROSPECTIVE.md | [OK] Complete | Jun 26 - Jul 1, 2026 (PR #266) |
| 45 | docs/sprints/SPRINT_45_RETROSPECTIVE.md | [OK] Complete | Jul 1-2, 2026 (PR #268) |
| 46 | docs/sprints/SPRINT_46_RETROSPECTIVE.md | [OK] Complete | Jul 2-11, 2026 (PR #270) |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 48** (2026-07-20 -- merged PR #274; emergency F119-b hotfix)
- **Type**: Emergency hotfix (no Phase 3 plan / full Phase 7 retro at the time; plan + lightweight Claude-team retro written retroactively per Harold 2026-07-20).
- **Delivered**:
  - **F119-b** -- the `0.5.5` Store MSIX shipped running as `APP_ENV=dev` (a SECOND root cause, independent of the F119 key typo): `secrets.prod.json`/`secrets.dev.json` held a JSON key with SPACES (`"comment OR try this"`), which `--dart-define-from-file` turns into a malformed dart-define that silently drops `APP_ENV=prod`. The build LOG still showed `APP_ENV=prod`, so the log-only Step 4.0 check passed while the compiled build was dev.
  - **Fix**: cleaned both secrets files to credential-keys-only (values preserved, backups gitignored); new `msix_config_test.dart` gate fails the build on space/empty secrets keys; new `main.dart --print-env` prints the COMPILED `APP_ENV` so the release process verifies behavior not the log; `STORE_RELEASE_PROCESS.md` Step 4.0 rewritten to require it.
  - **0.5.6 bump** (Partner Center rejects a re-used version) across all gated literals; `test-background-scan-skip.ps1` converted to DERIVE the version from pubspec (Harold catch) -> backlog **F-VERSION-DERIVE** to extend derive-not-hardcode to the 6 production log-filename sites.
- **Verification**: 1763 pass / 29 skip; analyze clean; rebuilt 0.5.6 prod MSIX `--print-env` -> **`APP_ENV=prod`** (compiled proof, the check that was missing on 0.5.4/0.5.5); manifest `0.5.6.0`; 16 MB.
- **Plan/Retro**: `docs/sprints/SPRINT_48_PLAN.md` (retroactive) · `docs/sprints/SPRINT_48_RETROSPECTIVE.md` (lightweight, Claude-team only, Harold's PO/SM/Lead feedback waived for the hotfix).
- **PR**: #274 (merged develop -> main, 2026-07-20).
- **Store**: `0.5.6` SUBMITTED to Partner Center for certification 2026-07-20 (in cert). This is the corrected first-public-release build. On cert PASS -> Step 7 close-out + Android/Google Play track OFF HOLD.
- **Open carry-ins for next sprint's Phase 1**: F33-PROD prod-DB apply (gated on BUG-DECODE), the 5 `CI_*` GitHub repo secrets, F108 Android-device dep-bump retest, and the retro backlog cards (F-VERSION-DERIVE, F-WINSTORE-ASSETS, F-PRECHECK, F-COPILOT-INSTR).

_(Prior: **Sprint 47** shipped F112-F119 + 8 retro IMPs, PR #272; **Sprint 46** shipped F64/F39/F33 + IMPs, PR #270. See per-sprint docs in `docs/sprints/`.)_
- **Store status**: BOTH `0.5.4` and `0.5.5` shipped to the Store running as `APP_ENV=dev` -- two INDEPENDENT defects that masked each other. `0.5.4` (F119): `msix_config` key typo `build_windows_args` (correct: `windows_build_args`). `0.5.5` (F119-b): `secrets.prod.json` had a JSON key with SPACES (`"comment OR try this"`) which silently drops `APP_ENV=prod` via `--dart-define-from-file`; the build LOG still showed `APP_ENV=prod`, so the log-only Step 4.0 check passed while the compiled build was dev. **Fix (Sprint 48, F119-b)**: cleaned both secrets files to credential-keys-only, added a gate (`msix_config_test.dart` fails on space/empty secrets keys) and a `--print-env` compiled-truth probe (Step 4.0 now requires it). **`0.5.6` shipped 2026-07-20 and STILL shows the `[DEV]` window title** (Harold's Store-install test, 2026-07-21) -- exposing a THIRD independent defect, **F119-c**: the native window title is compiled from the `SPAMFILTER_APP_ENV` CMake definition, which the Sprint 37 F52 design sourced ONLY from an OS env var that `build-windows.ps1` sets but the `msix:create` Store path NEVER set -> CMake defaulted `"dev"` -> `[DEV]` title baked into the native runner of 0.5.5 AND 0.5.6 while the Dart side was prod. **Record correction**: the F119-b space-key was NOT the cause of the 0.5.5 `[DEV]` title (the 0.5.5 About text was clean and it used the prod data dir -- the Dart side was already prod); F119-b remains as secrets hygiene + gate. The Dart-side `--print-env` "proof" on 0.5.6 was real but only covered the DART side. **Fix (Sprint 49, F119-c)**: `runner/CMakeLists.txt` now derives `SPAMFILTER_APP_ENV` from the `APP_ENV` dart-define recorded in `ephemeral/generated_config.cmake` (env var fallback) -- one flag drives BOTH sides; `main.cpp` passes its compiled value to Dart (`--native-app-env=`) and `--print-env` now prints `NATIVE_APP_ENV` so Step 4.0 verifies both compiled sides; policy pins in `msix_config_test.dart`. **Corrected build = `0.5.7`**. On the `0.5.7` cert PASS: Step 7 close-out + verify Store download (title bar MUST read `MyEmailSpamFilter` with no `[DEV]`) + Android/Google Play track OFF HOLD.
- **Earlier sprints (39-45)**: 39 (PR #260), 40 (PR #261), 41 (PR #262), 42 (PR #263), 43 (PR #265), 44 (PR #266), 45 (PR #268 -- F111 Store-readiness GO, develop->main released). See `docs/sprints/` + the Past Sprint Summary table above.

---

## Next Sprint Candidates

**Last Reviewed**: July 11, 2026 (Sprint 47 pre-kickoff rollover -- Sprint 46 shipped items pruned; carry-ins recorded. Full candidate re-presentation to Harold pending at Phase 1.2.)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Sprint Assignment (Sprint 47 pre-kickoff rollover, 2026-07-11)

Recent sprints complete -- detail blocks removed per the Maintenance Guide (history lives in `docs/sprints/` + CHANGELOG.md):
- **Sprint 42** (merged PR #263): F99 (integration_test harness), F98 (per-account bg-scan, ADR-0039 + ADR-0040), BUG-S37-2
- **Sprint 43** (merged PR #265): F102, F103, F96 (DB v8), F100, F101, F104, F105, F110; SEC-11b deferred Post-MVP (cipher -> SQLite3MultipleCiphers)
- **Sprint 44** (merged PR #266): F107 (Accept ADR-0037 + promote ARSD), F109 (surface background-deferral state), F108 (dep bumps: flutter_appauth 8->12, workmanager 0.5->0.9, flutter_secure_storage 9->10 + Android minSdk 23); retro IMP-1 version-consistency gate
- **Sprint 45** (merged PR #268, 2026-07-02): F111 (Windows App Store upload readiness verification -- GO for 0.5.4); **develop -> main released**; retro IMP-1 read-format-doc-first rule
- **Sprint 46** (merged PR #270, 2026-07-11): F64 (CI/CD pipeline), F39 (cross-account "No Rule" review screen + unmatched_emails writer fix), F33 (body-rules cleanup, dev-DB applied); manual-testing fixes (popup position, auto-advance, provider-sender grouping); retro IMP-1/2/4/5 applied

**Sprint 47 scope (Store 0.5.4 manual-testing feedback + carry-ins, Harold 2026-07-15)**: The **F112-F119** items below (Store-0.5.4 manual-testing feedback) are assigned to Sprint 47. **Carry-ins** also folded in: (1) dev version bump 0.5.4 -> 0.5.5 (see F118); (2) F33 prod-DB `--env prod --apply` (post-Store-rollout; requires the Copilot round-6 decode-failure report-not-delete fix first); (3) populate the 5 `CI_*` GitHub repo secrets; (4) IMP-3 CHANGELOG-cadence decision (A per-completed-item vs B Phase-5-entry gate); (5) Copilot round-6 polish (no_rule_review_screen load-error stackTrace + friendly SnackBar; cleanup-script decode-failure fix -- required before carry-in #2). **Standing HOLD candidates** unchanged: template deep dives (F70 Security / F71 Architecture / F111 Store-readiness), Post-MVP (SEC-11b DB encryption + F106 cleanup, paired), platform/UX tracks (F94/F95 flavors, F63 responsive, SEC-8b/SEC-15, F6, H1-H5, F67, GP-*), F39 mobile variant. **Open follow-up (Sprint 44 carry-in)**: Android-device retest of the F108 dep bumps -- not yet scheduled. **Store status**: 0.5.4 LIVE on the Microsoft Store (submission accepted, certification passed 2026-07-15). Note (F119): 0.5.4 MSIX shipped running as APP_ENV=dev -- fix + re-release needed.

### Sprint 47 -- Store 0.5.4 Manual-Testing Feedback

Captured from Harold's manual testing of the Store-installed 0.5.4 build (2026-07-15). All Windows Desktop unless noted. F119 is highest priority (it distorts every other observation).

**F119. Store MSIX ships running as APP_ENV=dev (~2-4h) Priority 8**
- Phase: Windows Store Readiness / build integrity
- Platform: Windows Desktop
- The Store-installed 0.5.4 build runs as `APP_ENV=dev`: title bar shows `MyEmailSpamFilter [DEV]`, the About screen shows `Version 0.5.4 [DEV]`, and it reads the `MyEmailSpamFilter_Dev` app-data directory instead of prod `MyEmailSpamFilter` (which is why Harold saw his 2 dev accounts -- NOT a privacy leak; accounts are per-machine, never in the package).
- Root cause: `AppEnvironment.APP_ENV` defaults to `'dev'`; `pubspec.yaml` `msix_config.build_windows_args` DOES specify `--dart-define=APP_ENV=prod`, so `msix:create` is not forwarding it to the inner `flutter build windows` (or a cached dev artifact was packaged).
- Fix: ensure a prod MSIX builds with `APP_ENV=prod`; add a build-time/CI assertion that a prod MSIX has empty `AppEnvironment.displaySuffix` (no `[DEV]`) and uses the prod data dir. Requires a version bump + re-release to the Store once fixed.
- Verify: About shows `Version 0.5.x` (no `[DEV]`), clean title bar, prod data dir.
- Blocks: F113 (clean-user testing is only meaningful once the build runs as prod).

**F112. "Review No Rule Items" entry point everywhere (~2-3h) Priority 20**
- Phase: Core App Quality / UX consistency
- Platform: Windows Desktop
- Add a single consistent icon (rule_folder style, tooltip "Review No Rule Items", opens `NoRuleReviewScreen`, Windows-gated per existing pattern) across the app. Reuse the account-selection screen's existing widget/handler (Sprint 46) for consistency.
- (a) Scan History AppBar -- add the icon (currently absent; AppBar has only Refresh / Select Account / Settings / Help).
- (b) Scan History "No Rule: N" total chip -- a small tappable instance centered directly above that chip (wrap `_buildTotalChip('No Rule', ...)` ~L340 in a center-aligned Column).
- (c) All Settings pages -- insert in the shared Settings AppBar (~L254) just to the LEFT of the "View Scan History" icon; one insertion covers all four tabs.

**F113. New-account default profiles (Manual + Background, provider-keyed) (~3-5h) Priority 22**
- Phase: Core App Quality / onboarding defaults
- Platform: All (Windows Desktop primary)
- Provider-keyed default-folder map -- AOL: `Inbox, Bulk, Bulk Mail`; Gmail: `INBOX, [Gmail]/Spam, Unwanted` (extensible to future providers).
- Manual Scan (common): Read-Only Mode ON; Scan Range = "Scan all emails" ON (entire mailbox); Show confirmation dialogs ON; Export CSV After Each Scan ON.
- Background Scan (common): Enable Background Scanning OFF; Frequency 15 min; Read-Only Mode ON; Scan Range = "Scan all emails" OFF, slider = last 1 day; Export CSV After Each Scan ON.
- Manual vs Background Scan-Range default differs by design (background scans last-1-day, not entire mailbox). Export CSV defaults ON confirmed by Harold (new users most likely to need diagnostics; file size negligible).
- User base is ~1-2 (Harold + one family member) -- NO migration needed; change the default constants; re-select values once on existing installs if desired. Depends on: F119 (test against a correct prod build).

**F114. Change new-user retention defaults to 90 days (~30m) Priority 24**
- Phase: Core App Quality / defaults
- Platform: All
- `defaultScanHistoryRetentionDays` 7 -> 90 (settings_store.dart:82).
- `defaultUnmatchedRetentionDays` 30 -> 90 (settings_store.dart:84, SEC-14).
- Fresh-install default only; ~1-2 users so no migration -- re-select 90 once on existing installs if desired.

**F115. Reorder Review-No-Rule selection bar (~15m) Priority 26**
- Phase: Core App Quality / UI
- Platform: Windows Desktop
- In `_buildSelectionBar` (no_rule_review_screen.dart): change order to `Apply Rule` (left) -> `N selected` -> ~5 spaces -> `Clear`. (Currently: `N selected` ... Clear -> Apply Rule, right-aligned.)

**F116. Demo Scan (Testing) completion screen matches Live Scan (~1h) Priority 28**
- Phase: Core App Quality / UI
- Platform: Windows Desktop
- On completion, show the summary chips/buttons instead of the results list (currently `scan_progress_screen.dart` renders a `ListView` ~L461 in `isDemoMode`; live scan uses the chip/button summary via `ResultsDisplayScreen`).
- The intermediate "13 / 26 processed" progress counts (inconsistent with the ~20 shown) do NOT need to be displayed once the buttons are present -- so the count discrepancy is not a separate bug to fix, just remove the count display.

**F117. Help footer: show app version, not hardcoded sprint # (~30m-1h) Priority 30**
- Phase: Core App Quality / docs
- Platform: All
- The Help footer (`help_screen.dart:238`) hardcodes "Last updated: Sprint 40 (June 2026)" -- stale (we are at Sprint 46+) and not version-shaped, so the version-consistency gate does not catch it -> it drifts every sprint.
- Preferred: read the version at runtime via `package_info_plus` (always accurate, zero upkeep). Alternative: mirror the Settings `Version X.Y.Z` literal that the existing gate already enforces (no new dependency).
- Consider extending the version-consistency gate to also flag stale "Sprint N" / "Last updated" footer strings.

**F118. Post-Store-release housekeeping (~1h) Priority 32 -- [DONE Sprint 47]**
- Phase: Windows Store Readiness / release close-out
- Platform: N/A (repo)
- [DONE] CHANGELOG: entries stay under `## [Unreleased]` -- `0.5.5` is a DEV bump, not a release (release = develop->main, user-only). Corrected from the original "move to `[0.5.4]` heading" criterion, which was wrong: `0.5.4` already shipped, and the next release heading is created only when the user merges develop->main.
- [DONE] Dev worktree version bump `0.5.4 -> 0.5.5` (pubspec version + `msix_version`, `main.dart`, `settings_screen.dart`, `background_scan_windows_worker.dart`, `live_scan_logger.dart`, `windows/runner/main.cpp`, plus doc-comment log-filename refs in `settings_store.dart` and `test-background-scan-skip.ps1`; version-consistency gate green).
- [DONE] `ALL_SPRINTS_MASTER_PLAN.md` "Last Completed Sprint": recorded the Store-release outcome (0.5.4 live 2026-07-15, but defective per F119; corrected re-release is a pending Harold action).
- [DONE] Stray gradle-artifact commit (`e925855`): added `android_legacy_*/.gradle/` to `mobile-app/.gitignore` + `git rm --cached` the tracked cache files so they stop re-dirtying the tree (the commit itself stays in history; the files are now untracked/ignored).
- [Harold action] Refresh/verify `secrets.prod.json` (dated Apr 20) before the corrected Store re-release.

**Sprint 47 retrospective improvements (all "apply now", Harold 2026-07-18)** -- see `docs/sprints/SPRINT_47_RETROSPECTIVE.md`:
- [DONE] IMP-1 (Proposal 1): sprint-card task template upgraded in `SPRINT_PLANNING.md` (Value / R-N / Affected files / Dependencies / NFRs / AC-N / T-N / Task-Level DoD / Definition of Ready), from a research spike. Source: Category 7 Requirements Clarity (Harold).
- [DONE] IMP-2 (Proposal 2): in-execution actuals logging codified (Task-Level DoD item 6); all Sprint 47 items backfilled into `CODING_VELOCITY.md` Coverage Ledger + Accuracy Trend.
- [DONE] IMP-4 (Proposal 4): version-consistency gate extended to sweep `test/` (catches the F118 hardcoded-versioned-filename fragility class); mirrored in `check-version-consistency.ps1`.
- [DONE] IMP-5 (Proposal 5): new `stale_footer_test.dart` gate flags hardcoded "Sprint N" / "Last updated" strings in `lib/ui/` (the F117 class); caught + fixed a stale "coming in Sprint 12-13" placeholder on the Rules tab.
- [DONE] IMP-3 (Proposal 3): stash-guard PreToolUse hook `.claude/hooks/block-carry-forward-stash.ps1` authored AND wired into `.claude/settings.json` (matcher `Bash|PowerShell`) after Harold approved the `.claude/` write. Verified live: `git stash` blocked (exit 2), `git status` / `git stash list` / `allow_stash` bypass all pass.

### Core App

_(No active Core App candidates -- F96 shipped in Sprint 43.)_

### Process

_(F100 shipped in Sprint 43.)_

**F-VERSION-DERIVE. Derive the app version at runtime instead of hardcoding it in log filenames -- [SPRINT 49 SELECTED, Harold 2026-07-21] (added 2026-07-20)**
- **Why**: the version bump touches 6 production `lib/`/`windows/` files that HARDCODE the version in version-stamped log filenames (`background_scan_v0.5.6.log`, `live_scan_v0.5.6.log`) plus the About string. Every release requires a manual multi-file bump, backstopped by the version-consistency gate. Harold's point (2026-07-20): if the version lives in `pubspec.yaml`, source should DERIVE it, not duplicate it. (`scripts/test-background-scan-skip.ps1` was converted to derive-from-pubspec this sprint -- the same fix pattern as the F118 `live_scan_logger_test.dart`.)
- **Scope**: introduce a single compiled version constant (e.g. via `package_info_plus` at runtime -- already a dependency since F117 -- or a build-time generated constant) and use it to build the log filenames + About string, so the 6 files no longer hardcode the literal. `pubspec.yaml` stays the single source of truth; the version-consistency gate then guards only pubspec + any remaining unavoidable literal (e.g. `main.cpp`, which cannot easily read pubspec at C++ compile time -- evaluate whether it can derive via a generated header).
- **Caution / why NOT a hotfix**: log filenames are used by support/diagnostics and the background-scan worker runs headless (may not have `package_info` initialized the same way) -- validate the runtime-version read works in the background/MSIX-sandbox context before removing the literals. `main.cpp` is the hard case (native, pre-Flutter). Effort: **M-L (~2-4h)**, needs care on the headless + native paths.
- **Net goal**: a version bump becomes a ONE-file change (pubspec), with the gate confirming nothing else drifted.

**F-PRECHECK. Pre-PR self-review checklist for recurring Copilot finding-classes -- [SPRINT 49 SELECTED, Harold 2026-07-21] (added 2026-07-18, from the PR #272 review pattern)**
- **Observation**: Copilot reviews keep surfacing the SAME finding-classes across sprints. PR #272: (1) a doc comment contradicting the code it documents; (2) a helper wired into a display path but not the real call path (`getEffectiveFolders` vs the scan path); (3) a CLI mirror out of sync with its Dart-gate twin (`check-version-consistency.ps1` `$dirs`); (4) fragile string parsing (accountId dash-split). Sprint 37 (PR #249): unbounded concurrency (same helper missed at two call sites), a mailbox-wide API used as folder-scoped, a11y-semantics conflation (×2). Sprint 46: silent-delete on decode failure, missing stackTrace on load-error.
- **Recurring classes** (candidate checklist items): (a) **mirror/parallel-site sync** -- when editing one of a known twin pair (Dart gate + PS1 CLI, manual + background scan paths, two call sites of one helper), grep for the sibling and update it too; (b) **call-path wiring** -- when adding a resolver/helper, confirm the PRODUCTION path calls it, not just the settings/display path; (c) **doc-vs-code drift** -- when changing a default/behavior, update the doc comment in the same edit; (d) **defensive input parsing** -- prefer robust detection (domain match) over positional splits; (e) **API scope** -- verify an API's scope (mailbox-wide vs folder) matches the caller's intent; (f) **silent failure** -- a `catch` that empties/deletes rather than reports.
- **Deliverable**: a short pre-PR self-review checklist (in SPRINT_EXECUTION_WORKFLOW.md Phase 5.1 automated-review step, or a `.claude` reviewer sub-agent prompt) that runs these classes over the diff BEFORE the PR, so we catch them ourselves instead of round-tripping through Copilot. Consider a code-reviewer sub-agent invoked at Phase 5.1 seeded with this class list.
- **Also**: reconcile with `.github/copilot-instructions.md` -- encode any DELIBERATE project decisions that Copilot keeps re-flagging as "won't fix, here's why" so it stops resurfacing them (see F-COPILOT-INSTR below).

**F-COPILOT-INSTR. Encode "won't-fix, by-design" decisions in copilot-instructions.md -- [SPRINT 48 CANDIDATE] (Harold 2026-07-18)**
- **Goal**: reduce repeat Copilot comments on things we have deliberately decided AGAINST, by documenting the rationale in `.github/copilot-instructions.md`. A first "Settled Decisions (do not re-flag)" section was added THIS sprint (SEC-14 body-not-persisted, gate fixture literals, embedded scan-log version, Windows-only gating). **Sprint 48 work**: (a) audit past Copilot rounds for other n>=2 repeat classes to add; (b) the file is currently ~4618 chars vs the ~4000 soft budget -- do a proper budget-fit trim pass (the file already exceeded 4000 before this sprint; Copilot still reads it, so the limit is soft, but tighten it).
- **Candidate "by-design" entries** (validate each against the actual codebase before adding): (a) subsumption-before-exact-duplicate ordering is intentional (BUG-S36-1 / Issue #246) -- Copilot flagged it Sprint 37, disposition "not applicable"; (b) body content is deliberately NOT persisted to `unmatched_emails` (SEC-14) -- pre-empt "you dropped the body" comments; (c) Windows-desktop-only gating (`if (Platform.isWindows)`) on several review entry points is intentional, not a platform-coverage gap; (d) the version-consistency gate's own fixture files intentionally contain stale-version literals; (e) per-account log filenames embed the app version on purpose (drift is caught by the gate). 
- **Caution**: only add entries for decisions that are genuinely settled and that Copilot has actually re-flagged (n>=2) -- do not pre-load speculative suppressions that could hide a real future regression. Each entry states the decision + the one-line why, so a reviewer (human or Copilot) sees it is deliberate.
- **Effort**: S (~30-45m: audit past Copilot rounds for n>=2 repeat classes, draft concise entries, fit the 4000-char budget).

### Security Hardening (Sprint 31 Audit)

_(F107, F108, F109 shipped in Sprint 44 -- see docs/sprints/SPRINT_44_SUMMARY.md. F106 is HOLD/Post-MVP, paired under SEC-11b below.)_

### Release Readiness

**F-WINSTORE-ASSETS. Update all Windows/Microsoft Store listing images -- [BACKLOG] (Harold 2026-07-19)**
- **Why**: the Windows Store listing images (screenshots + store logos + promotional graphics in Partner Center) "carry over from the previous submission" (STORE_RELEASE_PROCESS.md Step 6) -- they have NOT been refreshed and likely show old UI, predating the Sprint 40-47 changes (Review-No-Rule flows, new defaults, footer, demo-scan nav, etc.). The 0.5.5 release is the first true public release (2 -> ~20 users), so the listing should show the current app.
- **Scope -- audit + refresh every Store-facing image**:
  - **App tile / launcher icon** (`mobile-app/assets/icon/icon.png` -> `msix_config.logo_path` + `flutter_launcher_icons`): confirm it is current and high-resolution; regenerate the derived sizes if the source changed (`dart run flutter_launcher_icons`).
  - **Partner Center Store listing screenshots**: recapture from the current build showing the real, current screens (account selection, scan results, Review No Rule Items, settings). Microsoft Store desktop screenshots: min 1366x768, PNG; 1-10 per listing.
  - **Store logos / tile images** required by the manifest/Partner Center (Square 44x44, 71x71, 150x150, 310x150 wide, 310x310, Store logo 300x300, etc. -- confirm the exact current Partner Center requirements at capture time; some are auto-generated from `logo_path` by `msix:create`, others are uploaded in the Store listing).
  - **Promotional / hero image** if the listing uses one.
- **Where they live**: app-side source under `mobile-app/assets/`; the listing screenshots/graphics live in Partner Center (uploaded, not in-repo) -- consider storing masters in the repo (e.g. `docs/store-assets/windows/`) for reproducibility.
- **Deliverable**: current-UI screenshot set + verified icon/logo assets, uploaded to Partner Center on the next submission (listing images can be updated WITHOUT a new package/version -- a metadata-only Store update).
- **Note**: this is the Windows counterpart to GP-6 (Play Store Listing and Assets) in the Android HOLD section. Effort: **M (~2-4h)** -- mostly screenshot capture + Partner Center upload; validate against current Microsoft Store image-spec requirements at execution time (specs change).

_(F111 shipped in Sprint 45 -- GO recommendation delivered; see docs/sprints/SPRINT_45_F111_STORE_READINESS.md and SPRINT_45_SUMMARY.md. Store upload of 0.5.4 is a pending Harold action, targeted Sat/Sun on a stable network -- not a backlog item.)_

_(F103 Architecture Deep Dive and F104 Security Deep Dive ran in Sprint 43 -- see `docs/sprints/SPRINT_43_F103_ARCHITECTURE_DEEP_DIVE.md` and `SPRINT_43_F104_SECURITY_DEEP_DIVE.md`; their reusable templates F71 / F70 remain HOLD below. F105 version bump shipped.)_

### DevOps

_(F64 CI/CD pipeline shipped in Sprint 46 -- `.github/workflows/ci.yml`; see CHANGELOG 2026-07-02 and SPRINT_46_RETROSPECTIVE.md. One-time `CI_*` repo-secret setup is a Sprint 47 carry-in.)_

### HOLD Items (Periodic Reviews)

**F111. Periodic Windows App Store upload readiness verification (~110-175m per review) Priority HOLD**
- Phase: Release Readiness (reusable template)
- Platform: Windows Desktop
- **Generic scope**: verify develop/main parity, version compatibility vs the currently-published Store version, MSIX build-path integrity (`msix_config.build_windows_args` OAuth-credential injection), and Store-submission preconditions (`docs/STORE_RELEASE_PROCESS.md` checklist) BEFORE any Store build/upload. Produces a GO/NO-GO readiness finding; does not build or upload.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a new Windows Store release is planned. First run: Sprint 45 (see `docs/sprints/SPRINT_45_F111_STORE_READINESS.md`).
- Source: Sprint 45 backlog refinement (2026-07-02) -- captured as a recurring template since Store readiness verification will be needed for every future release.

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

### Core App Quality

_(F39 cross-account "No Rule" review screen shipped in Sprint 46. F39 mobile (Android/iOS touch) variant remains a future backlog candidate.)_

**F33-PROD. Body-rules cleanup: prod-DB `--env prod --apply` run -- [SPRINT 48 CANDIDATE] (Harold 2026-07-18: deferred from Sprint 47)**
- The `cleanup_body_rules.dart` script (shipped + dev-DB applied in Sprint 46) still needs a one-time `--env prod --apply` run against the **local prod rules database**.
- **NOT release-gating**: the prod rules DB is a local SQLite file, NOT bundled into the MSIX and NOT downloaded by users (new Store users get bundled `rules.yaml` defaults). This cleanup has zero effect on Store users -- it is dev-machine housekeeping. Decoupled from the 0.5.5 Store re-release (Harold 2026-07-18).
- **Depends on BUG-DECODE below** (must land first so a malformed row is reported, not silently deleted, on `--apply`). Back up the prod DB before applying.

**BUG-DECODE. `cleanup_body_rules.dart` silently deletes rows on JSON-decode failure -- [SPRINT 48 CANDIDATE] (Copilot round-6; Harold 2026-07-18: assigned to Sprint 48)**
- In `mobile-app/scripts/cleanup_body_rules.dart` (~L339-345, L357-360): a `condition_body` that fails `jsonDecode` is caught, `patterns` set to `<String>[]`, and the row is then classified **G5 orphan -> in the delete set** on `--apply`. A decode-failing row is thus silently DELETED instead of reported as `ambiguous` for human review.
- **Fix**: on decode failure, route the row to `ambiguous` (report-only, untouched) with a logged warning -- report-not-delete. Add a unit test feeding malformed JSON that asserts the row is reported, not removed.
- **Latent, never fired**: the Sprint 46 dev run decoded all 1109 rows cleanly (0 failures), so no data was ever affected. It is a guard on a destructive dev-only script, not a user-facing bug. MUST land before the F33-PROD `--apply` run.

### HOLD Items (Android / Google Play Store)

> **[NEXT MAJOR TRACK] Promotion trigger (Harold, 2026-07-15)**: As soon as the corrected Windows Store `0.5.5` release (F119 fix -- SUBMITTED for certification 2026-07-19) is verified LIVE, this entire Android / Google Play track comes OFF HOLD and becomes the next focus. Android development is intentionally stagnant only until that Windows release lands. At promotion, refine this section into an active sprint: start with the `google-services.json` applicationId mismatch diagnosis (F94 pre-existing investigation item -- likely root of intermittent Android Gmail OAuth), then F94 flavors, then the F108 Android-device dep-bump retest carry-in, then the Google-Play-gated security items below.

**F94. Android dev/prod/store flavors (~6-8h) Priority HOLD (Issue #248) -- RENUMBERED from "F52 Phase 2" + MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Build and Release Infrastructure / Android Google Play Store Readiness
- Platform: Android
- Renumbered from the ambiguous "F52 Phase 2" to a distinct F# (was sharing F52 with the iOS phase, now F95). Sprint 37 shipped F52 Phase 1 (Windows distinct .exe + dirs); this Android-flavors work was deferred and is now grouped with the Android/GP HOLD track per Harold (2026-05-25).
- Android `productFlavors` with `applicationIdSuffix .dev` / `.prod`.
- **Prerequisites (external -- must be done BEFORE this work can produce a runnable Android build):**
  1. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.dev` applicationId
  2. Firebase Console -- register SHA-1 fingerprint for `com.myemailspamfilter.prod` applicationId
  3. Google Cloud Console -- create OAuth client ID for `.dev` package + matching SHA-1
  4. Google Cloud Console -- create OAuth client ID for `.prod` package + matching SHA-1
- **Pre-existing investigation item**: `mobile-app/android/app/google-services.json` has `applicationId="com.example.spamfiltermobile"` while `build.gradle.kts` declares `applicationId="com.myemailspamfilter"`. Diagnose and fix this mismatch BEFORE adding flavor complexity (may explain intermittent Android Gmail OAuth).
- Memory note: `project_f52_phase2_blockers.md` has full Sprint 37 deferral context.
- **Full #248 Phase 2 task list** (from the issue, deferred here): configure `productFlavors` in `android/app/build.gradle.kts` (dev/prod/store) with distinct `applicationId` suffixes, flavor-specific `google-services.json`, flavor-aware build scripts, and verify side-by-side install of dev + prod APKs on one device/emulator.
- Source: Sprint 37 retrospective Category 11 + Category 13; Issue [#248](https://github.com/kimmeyh/spamfilter-multi/issues/248) (closed 2026-06-23 -- Phase 1 Windows SHIPPED in Sprint 37; Phase 2 Android = this item F94; Phase 3 iOS = F95).

**F95. iOS variants + cross-store hardening (~10-16h) Priority HOLD -- RENUMBERED from "F52 Phase 3+" + MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Build and Release Infrastructure
- Platform: iOS, plus polish across all 9 variants (3 stores x 3 channels: dev, production, store)
- Renumbered from the ambiguous "F52 Phase 3+" to a distinct F# (was sharing F52 with the Android phase, now F94). Moved to HOLD with the multi-variant track per Harold (2026-05-25) -- blocked until iOS development begins (requires macOS + Apple Developer account).
- All variants must run simultaneously without rebuild on same machine/device.
- [Detail](#f52-multi-variant-side-by-side-install)
- Source: ADR-0035 dev/prod separation.

**F63. Responsive design framework (~8-12h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: UX Improvement
- Platform: All
- Implement adaptive breakpoints per ARSD AR-7: phone (<600dp), tablet (600-900dp), desktop (>900dp); LayoutBuilder + breakpoints (ARSD A6). Priority screens: scan progress, results display, settings.
- Moved to HOLD per Harold (2026-05-25). Related: F55 (navigation consistency). Source: Sprint 30 gap analysis (gap G23).

**SEC-15. IMAP host validation for custom servers (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security
- Platform: All
- Reject internal/private IP ranges when custom IMAP is implemented. Depends on: F37 (custom IMAP). Moved to HOLD per Harold (2026-05-25). Source: Sprint 31 security audit (S19).

**SEC-8b. Certificate pinning for IMAP endpoints (~4-6h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security
- Platform: All
- OAuth HTTPS pinning shipped Sprint 33; IMAP pinning deferred because `enough_mail.ImapClient.connectToServer` exposes no `SecurityContext`/bad-cert callback. Options: fork enough_mail, wrap socket via `SecureSocket.connect`, or file upstream issue. Moved to HOLD per Harold (2026-05-25). Source: Sprint 33 SEC-8 notes.

**F6. Provider-Specific Optimizations (~10-12h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Performance
- Platform: All
- Moved to HOLD per Harold (2026-05-25). [Detail](#f6-provider-specific-optimizations)

**SEC-4. Android: Create network_security_config.xml (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Block cleartext traffic, pin domains for OAuth and IMAP; reference in AndroidManifest.xml
- Moved to HOLD with the rest of the Android track per Harold (2026-05-25) -- gated by the Google Play release, which is on HOLD. Source: Sprint 31 security audit (S11).

**SEC-6. Android: Configure release signing (~2h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Create release keystore, configure in build.gradle.kts. Overlaps with GP-2 (release signing). Source: Sprint 31 security audit (S12).

**SEC-7. Android: Enable R8 obfuscation + Dart obfuscation (~2h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Enable minifyEnabled, create proguard-rules.pro; use --obfuscate --split-debug-info for Dart. Overlaps with GP-9 (ProGuard/R8). Source: Sprint 31 security audit (S13).

**SEC-9. Move hardcoded Android client ID to build-time injection (~1h) Priority HOLD -- MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Security / Android Google Play Store Readiness
- Platform: Android
- Move _androidClientId to --dart-define or google-services.json. Source: Sprint 31 security audit (S5).

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

**SEC-11b. Database-at-rest encryption via SQLite3MultipleCiphers (sqlite3mc) + plaintext-to-encrypted migration (~8-12h) Priority HOLD (Post-MVP)**
- Phase: Security
- Platform: All (Windows desktop + Android + iOS)
- **Moved to Post-MVP, removed from Sprint 43** (Harold direction 2026-06-24): the original `sqflite_sqlcipher` approach is mobile-only (no Windows desktop support), which blocked SEC-11b on the app's primary platform. After research, the cipher was switched to **SQLite3MultipleCiphers (sqlite3mc)** -- the modern cross-platform answer -- and the item was re-scoped and deferred rather than attempted with a half-working driver.
- **What Sprint 33 already shipped (infrastructure, reusable as-is)**: `DatabaseEncryptionKeyService` (`lib/core/security/database_encryption_key_service.dart`) -- 256-bit key in `flutter_secure_storage` under `db_encryption_key_v1`, base64-returned for `PRAGMA key`; `getOrCreateKey()` / `hasKey()` / `deleteKey()`. Opt-in `encrypt_database` settings toggle (default off). These do NOT change.
- **Cipher decision (Harold 2026-06-24): use SQLite3MultipleCiphers (sqlite3mc), NOT SQLCipher.** Rationale:
  - Truly cross-platform from one prebuilt source: Android (armv7a/aarch64/x86/x64), iOS, and **Windows desktop** all covered -- SQLCipher's `sqflite_sqlcipher` has no Windows desktop support.
  - Per the drift/sqlite3 maintainers, as of drift 2.32.0 / sqlite3 v3.x, sqlite3mc is the supported/easy path and `sqlcipher_flutter_libs` is being deprecated. SQLCipher is now the harder route.
  - sqlite3mc can still read SQLCipher-format DBs if ever needed (`PRAGMA cipher='sqlcipher'; PRAGMA legacy=4`), so it is not a dead end.
- **Key integration caveat -- this app uses `sqflite` / `sqflite_common_ffi`, NOT drift / the `sqlite3` package binding.** sqlite3mc is wired most cleanly through the `sqlite3` package; to use it with the existing `sqflite_common_ffi` driver on Windows desktop you must:
  - Provide a custom `ffiInit` to `createDatabaseFactoryFfi(ffiInit: ...)` that loads the sqlite3mc native library via `open.overrideFor(OperatingSystem.windows, ...)` (and for `OperatingSystem.android`/`iOS` as needed). Reference: [sqflite_common_ffi encryption_support.md](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md).
  - Set the key + cipher via `PRAGMA key='<base64>'` in `DatabaseHelper._initializeDatabase()`'s `onConfigure` (alongside the existing `foreign_keys`, `busy_timeout=30000`, WAL setup at `lib/core/storage/database_helper.dart`).
  - Bundle/ship the sqlite3mc native lib per platform (Windows: lib in the same folder as the executable for release; debug bundles automatically). Confirm prebuilt-binary availability vs the `hooks: user_defines: sqlite3: source: sqlite3mc` pubspec mechanism, and whether that mechanism is reachable from a sqflite-based (non-`sqlite3`-package) access layer -- if not, evaluate either (a) a thin `sqlite3`-package shim just for the native-lib resolution, or (b) shipping the sqlite3mc binaries directly.
- **Recommended approach when picked up: spike first.** A focused spike ("wire sqlite3mc through `ffiInit` and prove the Windows DB file on disk is encrypted, with the existing sqflite access layer intact") de-risks the whole feature before the migration work. Far more tractable than compiling/linking SQLCipher for Windows.
- **Migration logic (cipher-independent, unchanged by the cipher switch)**:
  - Atomic plaintext-to-encrypted migration on first opt-in: backup -> re-open with key -> copy -> swap -> verify -> retain backup.
  - **Dual-DB verification window (Harold 2026-06-23)**: Dev keeps an encrypted + plaintext dual-write for ~2 sprints; Prod is encrypted-only after migration with the original plaintext `spam_filter.db` retained as a rollback backup. Cleanup tracked separately as **F106** (spawned by this design).
  - **Existing prod-user upgrade path (Harold question 2026-06-23)**: users on <= 0.5.3 have a plaintext DB; on upgrade to the version that ships SEC-11b, the first launch detects the plaintext DB (no key set / `hasKey()` false but DB exists), runs the one-time migration, and retains the original as the rollback backup.
- **QA on real installs**: Windows desktop + Android emulator + physical device; verify the on-disk DB is unreadable without the key.
- **Flip `encrypt_database` default to true after QA (Class-1 -- surface to Chief Architect before flipping).**
- **Estimate revised to ~8-12h** (was ~6-10h) to cover the custom-`ffiInit` native-lib wiring + the spike.
- Source: Sprint 33 SEC-11 scoping decision (partial completion); driver switch + Post-MVP deferral Harold direction 2026-06-24. Research sources: [drift encryption docs](https://drift.simonbinder.eu/platforms/encryption/), [sqlite3.dart UPGRADING_TO_V3.md](https://github.com/simolus3/sqlite3.dart/blob/main/UPGRADING_TO_V3.md), [sqlite3 hook topic](https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html), [sqflite_common_ffi encryption_support.md](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/encryption_support.md).

**F106. SEC-11b verification-window cleanup (~30m) Priority HOLD (Post-MVP -- gated on SEC-11b)**
- Phase: Security / cleanup
- Platform: All
- After ~2 sprints of verified encrypted+plaintext dual-DB operation (per the SEC-11b dual-DB design above): remove the Dev plaintext-mirror dual-write code path, and delete the retained pre-migration plaintext `spam_filter.db` file in prod (kept as a rollback backup during the verification window). Gated on Harold confirming the encrypted DB has been verified working across the window.
- Depends on: **SEC-11b shipped + ~2 sprints of verified encrypted-DB operation.** Moved from Priority 30 to HOLD/Post-MVP (Harold 2026-07-01) -- F106 cannot start until the SEC-11b DB-encryption backlog item ships, so it is paired here under it.
- Source: Harold direction 2026-06-23 (SEC-11b dual-DB verification requirement); HOLD/dependency clarification 2026-07-01.

**H1. GenAI Pattern Suggestions - Crowdsourced Spam Intelligence (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#142](https://github.com/kimmeyh/spamfilter-multi/issues/142)

**H2. Rule Pattern Consistency - Domain Matching Standards (~4-6h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#140](https://github.com/kimmeyh/spamfilter-multi/issues/140)
- Ask: standardize the regex pattern conventions across `rules.yaml`/`rules_safe_senders.yaml` -- define a fixed taxonomy (exact-email / exact-domain / domain+subdomains / entire-TLD), add a new "domain + all TLDs" type, enforce the standard in tooling/UI, and refactor the ~3000+ inconsistent legacy patterns to conform.
- **Current state (verified 2026-05-25)**: PARTIAL. The standardized taxonomy + generators now exist for NEWLY created rules: `mobile-app/lib/core/utils/pattern_generation.dart` (`generateExactEmailPattern`, `generateDomainPattern`, `generateSubdomainPattern`, `detectPatternType`) and the user-facing `ManualRuleType` enum in `manual_rule_create_screen.dart` (entireDomain `@(?:[a-z0-9-]+\.)*domain$`, exactDomain `@domain$`, TLD `@.*\.tld$`), with `pattern_type` persisted to the DB. Subsumption/dedup (Sprints 36-38, `manual_rule_duplicate_checker.dart`) addresses the "consolidate duplicates" goal for new rules. **Remaining**: (1) the requested "domain + all TLDs" type (`@(?:[a-z0-9-]+\.)*spammer\..*$`) does NOT exist (the UI's `topLevelDomain` is the entire-TLD type, a different thing); (2) the ~3000 legacy `rules.yaml` patterns are NOT categorized/refactored/consolidated; (3) no YAML-schema pattern-type metadata field or build-time validation enforcing the standard on the YAML files. Standardization is prospective (manual-create path) only.

**H3. Requirements Documentation System (TBD) Priority HOLD**
- Phase: Post-MVP
- Platform: N/A
- Issue [#137](https://github.com/kimmeyh/spamfilter-multi/issues/137)

**H4. Sent Messages Scan for Safe Senders (~12-16h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Issue [#49](https://github.com/kimmeyh/spamfilter-multi/issues/49)
- Ask: add a "Sent Messages Scan for Safe Senders" flow -- read every message the account owner sent, collect normalized To:/CC: addresses as safe-sender candidates, flag/exclude ones hitting a delete rule or "unsubscribe," dedupe against existing safe senders, persist progress for resume, and give the user a filterable/sortable review UI (with auto-accept option) to approve additions.
- **Current state (verified 2026-05-25)**: NOT DONE -- entire feature remains. `email_scanner.dart` scans inbox/bulk folders only; no Sent-folder traversal and no safe-sender derivation. `CanonicalFolder.sent` exists as generic folder-classification plumbing in the adapters but nothing consumes it for a sent-scan. No sent-scan service, no resume-state store, no candidate-review UI. Reusable building blocks exist but are unwired: address normalization (`pattern_normalization.dart` `normalizeFromHeader`) and safe-sender storage (`safe_sender_database_store.dart`, `safe_senders_management_screen.dart`). Full scope remains: Sent-folder scan, To/CC candidate collection + normalization, delete-rule/unsubscribe flagging, dedup vs existing safe senders, resumable progress, and the approval UI.

**H5. Outlook.com / Office 365 email provider adapter (~16-20h) Priority HOLD**
- Phase: Post-MVP
- Platform: All
- Source: Issue [#44](https://github.com/kimmeyh/spamfilter-multi/issues/44) (closed 2026-06-23, deferred to this backlog item).
- **Current state**: `mobile-app/lib/adapters/email_providers/outlook_adapter.dart` is a stub that throws `UnimplementedError`; all methods need implementation. (Outlook.com OAuth is listed under Known Limitations in CLAUDE.md as deferred.)
- **Scope (from #44)**:
  - **Auth (OAuth 2.0)**: Microsoft Identity Platform; scopes `Mail.ReadWrite` + `offline_access`; `msal_flutter` package; interactive browser/webview auth; cache + refresh tokens.
  - **Core methods** via Microsoft Graph API: `loadCredentials()` (init OAuth), `fetchMessages()` (OData `$filter=receivedDateTime ge {date}`, `$top` pagination), plus the rest of the `EmailProvider`/`SpamFilterPlatform` interface (move/delete/folder-list) mapped to Graph endpoints.
  - Register the platform in `PlatformRegistry`; folder/canonical-folder mapping for Outlook's well-known folders.
- **Why HOLD**: post-MVP provider expansion; large (~16-20h) and gated behind a Microsoft app registration. The existing AOL/Gmail/IMAP providers cover current users.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- mostly NOT DONE. The unified `mobile-app/lib/ui/screens/folder_selection_screen.dart` handles both multi-select and single-select modes from a FLAT list.
- **Part A (two-level collapsible tree)**: NOT DONE. Folders render flat (~L520-606); no `ExpansionTile`/expandable groups, no non-selectable parent containers. A "Recommended" badge for junk/inbox exists (~L572-590) but that is not the auto-highlight-on-open behavior specified.
- **Part B (provider-default-first, flat, no sub-folders)**: PARTIAL. Single-select via `RadioListTile` exists (~L527-558), and folders are sorted by canonical type (Inbox, Junk) then alphabetically (~L163-175) -- but there is NO provider-specific default-first ordering and NO sub-folder exclusion.
- **Path-separator detection**: NOT DONE. Uses `mailbox.path` directly (`generic_imap_adapter.dart` ~L870-886); `FolderInfo` does not expose the IMAP separator, so callers cannot split paths per-provider. Hardcoded-`/` risk remains.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- but the landscape has shifted since this item was written (Sprint 20). The Sprint 34 `ManualRuleCreateScreen` (`mobile-app/lib/ui/screens/manual_rule_create_screen.dart`) now provides the plain-text-to-regex generation this item asked for, but ONLY for rule CREATION, not EDITING. Per-feature status:
- **(1) Plain-text -> regex generation**: PARTIAL (create-only). `_generatePattern` (~L147-249) converts plain-text email/domain/TLD/URL to regex by selected `ManualRuleType` (entire_domain, exact_domain, exact_email, top_level_domain). No edit mode -- the screen constructor (~L44-54) takes only `mode: ManualRuleMode` (blockRule | safeSender), no `initialRule`/`existingRule` param.
- **(2) Direct regex editing with real-time validation**: NOT DONE. Generated pattern is shown read-only (`SelectableText`, ~L739-766); no editable regex field, no validate-and-suggest-fix.
- **(3) Pattern preview against sample data (reuse Rule Testing UI)**: NOT DONE. `ManualRuleCreateScreen` does not import or link to `RuleTestScreen`.
- **(4) Edit button in rule details dialog**: NOT DONE. `rules_management_screen.dart` details dialog (`_showRuleDetails`, ~L248-329) has only Close / Toggle / Delete.
- **(5) Field editing (source_domain re-regex, category, sub_type, enabled/disabled)**: NOT DONE except enabled/disabled, which is editable via the existing toggle (`_toggleRule`, ~L155-181). source_domain / pattern_category / pattern_sub_type are not editable anywhere -- a rule can only be deleted and recreated.
- **Net**: the create-side regex-generation building blocks now exist and could be refactored into an edit flow; the actual edit UI (dialog Edit button, edit screen, direct-regex-edit, preview integration, metadata field editing) is all still to build. Revised remaining estimate likely toward the lower end of ~8-12h given the reusable generator.

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

**Current state (verified 2026-05-25)**: NOT essentially complete -- all 3 enhancements remain NOT DONE.
- **(1) Example email addresses from Demo data**: NOT DONE. `mobile-app/lib/ui/screens/rule_test_screen.dart` (`_loadSampleEmails`, ~L62-112) loads match-against samples only from recent scan history (`scanResultStore.getAllScanHistory(limit: 3)`); no Demo Mode / MockEmailProvider fallback.
- **(2) Plain-text-to-regex in the test tool**: NOT DONE. The screen validates that input is valid regex (~L124-134) but does not detect plain text and auto-convert. (Note: a separate plain-text-to-regex generator DOES exist in `manual_rule_create_screen.dart` for rule *creation* -- it is just not wired into the test screen.)
- **(3) Open existing rule in test tool from Manage Rules**: NOT DONE. `rules_management_screen.dart` has a toolbar icon that opens a BLANK test screen (~L439-446) and the rule details dialog (`_showRuleDetails`, ~L248-329) has only Close / Toggle / Delete -- no "edit and test" affordance that pre-fills the rule's pattern. (`RuleTestScreen` does accept `initialPattern`/`initialConditionType`, used from `rule_quick_add_screen.dart`, so wiring exists but is not connected from Manage Rules.)

**Dependencies**: None (builds on existing Rule Testing UI from Sprint 18)

---

### F39: Cross-Account "No Rule" Review Screen with Multi-Select Bulk Rule Application

**Status**: Active, Sprint 46 (taken off HOLD 2026-07-02; scope RESTRUCTURED during Phase 4 execution 2026-07-02 -- see below)
**Estimated Effort**: ~12-16h (legacy, original scope); Sprint 46 scope ~90-140m (Windows-only, new cross-account screen, see below)
**Phase**: Core App Quality
**Platform**: Sprint 46 scope = **Windows Desktop only** (Harold 2026-07-02: Android/iOS multi-select explicitly deferred, not attempted this sprint -- may return to backlog as a separate future item if prioritized).

**Scope restructure (Harold 2026-07-02, surfaced during Phase 4 implementation)**: the original ask ("add multi-select to the existing per-account Scan Results screen") was NOT the real need. Clarifying question during execution surfaced the actual requirement: **a single aggregated list of "No rule" items across ALL configured accounts by default** (account-filterable down to one), scoped to **each account's most recent scan/live run only** (not full history -- a user reviewing weekly wants this week's unaddressed items, not a re-scan of history). Realistic weekly volume: **<50 "No rule" items across all accounts**. Structural decision: **new screen** (not a mode grafted onto the existing 2812-line `results_display_screen.dart`, which is constructed with a required single account per instance). See `docs/sprints/SPRINT_46_PLAN.md` Task 3 for full detail.

**Overview**: New screen aggregating unaddressed ("No rule") scan results across all accounts, with multi-select and bulk rule-application actions -- replaces one-at-a-time triage with a batched weekly-review workflow.

**Selection Mechanics** (Windows desktop):
- Radial button (checkbox) to the left of each item for select/unselect
- Ctrl+click to add individual items to selection
- Shift+click to select a range of items between two clicked items
- Selection scoped to the current account filter

**Bulk Actions (right-click context menu)**:
7 options:
1. Add Safe Sender - Exact Email
2. Add Safe Sender - Exact Domain
3. Add Safe Sender - Entire Domain
4. Add Block Rule - Exact Email
5. Add Block Rule - Exact Domain
6. Add Block Rule - Entire Domain
7. Remove Current Rule

**Batching**: the expensive re-evaluate/re-process/notify tail (`_reEvaluateNoRuleEmails()`, `_reProcessAffectedEmails()`, SnackBar) runs ONCE per bulk operation, not once per selected item -- one summary notification instead of up to 50 stacked SnackBars. Rule-creation logic itself is extracted from `_addSafeSender`/`_createBlockRule` into a shared, screen-agnostic method so behavior does not drift between the existing single-item detail-sheet flow and this new bulk screen.

**Dependencies**: Scan Results screen (completed Sprint 12), Rule management (completed Sprint 20), existing single-item quick-add logic (`_addSafeSender` ~L2424, `_createBlockRule` ~L2589 in `results_display_screen.dart`) as the extraction source for shared rule-creation logic.

**Acceptance Criteria (Sprint 46, restructured scope, Windows-only per Harold 2026-07-02)**:
- [ ] New screen aggregates the latest "No rule" items across all accounts by default
- [ ] Account filter narrows the list to a single account
- [ ] Only each account's latest scan/live run is included (not full history)
- [ ] Multi-select works with Ctrl+click and Shift+click on desktop
- [ ] Radial/checkbox per item for direct select/unselect
- [ ] Right-click context menu shows 7 bulk action options
- [ ] Bulk action applies chosen rule to all selected emails, with re-evaluate/re-process/notify run ONCE per bulk operation
- [ ] Rule-creation logic is shared (not duplicated) between the existing single-item detail-sheet flow and the new bulk screen
- [ ] Android/iOS multi-select explicitly deferred (not attempted this sprint)

### F74: FAQ Section in Help

**Status**: HOLD (Post-Windows Store)
**Estimated Effort**: ~2-4h
**Phase**: Documentation / UX
**Platform**: All
**Added**: April 18, 2026 (Sprint 34 testing feedback)

**Overview**: Add a Frequently Asked Questions section to the in-app Help screen (F54 from Sprint 33 added the Help infrastructure). Users have asked about technical concepts during F56 testing that warrant FAQ-style answers rather than burying them in walkthrough text.

**Required FAQ topics**:
- **What is a TLD (Top-Level Domain)?** -- explain TLD concept (.com, .uk, .xyz), how the app's TLD block rules work, why blocking a TLD is heavy-handed (blocks everything from that TLD), and when to use entire-domain rules instead.
- **What is the IANA TLD list and why does the app use it?** -- explain IANA's role as the authority for valid TLDs, why the app rejects fake TLDs (`.com444`, `.whatevericanthinkof`), how the list is updated (`scripts/update_iana_tlds.sh`), and what to do if a real new TLD is rejected (file an issue).
- **What is the difference between Entire Domain, Exact Domain, Exact Email, and Top-Level Domain?** -- with concrete examples and matched/unmatched email lists for each.
- **What is a Safe Sender?** -- explain whitelist precedence over block rules.
- **Why does the scanner skip some emails?** -- explain Read-Only mode, default folders setting, retention.
- **What does "ReDoS" mean and why was my pattern rejected?** -- explain catastrophic backtracking in plain language with the rejected pattern shown.
- **Where is my data stored?** -- per ADR-0030 (privacy/zero telemetry), point to `MyEmailSpamFilter` AppData directory.
- **How do I export and re-import my rules?** -- point to Settings > Data Management.

**Implementation**:
- New `HelpSection.faq` enum value
- New `_buildFaqSection()` method in `help_screen.dart`
- ExpansionTile per question for collapsible Q&A
- Add `Help` icon entry on the Help screen jumping to FAQ
- Cross-reference from manual rule creation screen ("Learn more about TLDs" link)

**Acceptance Criteria**:
- [ ] FAQ section accessible from Help screen
- [ ] At least 8 questions answered (the topics above)
- [ ] Each answer fits on one screen (no scrolling within an answer)
- [ ] TLD/IANA answers explain the F56 validation behavior users encountered
- [ ] Cross-references from rule creation screens to relevant FAQ entries

### F75: Help Walkthrough -- End-to-End First-Use Guide

**Status**: HOLD (Post-Windows Store)
**Estimated Effort**: ~4-6h
**Phase**: Documentation / UX
**Platform**: All
**Added**: April 18, 2026 (Sprint 34 testing feedback)

**Overview**: Add a step-by-step walkthrough to the in-app Help screen that guides a first-time user through the recommended workflow from install to confident production use. Builds on the F54 Help infrastructure (Sprint 33).

**Walkthrough steps to document**:

1. **Install + first launch** -- account setup, choose provider, OAuth or app-password flow, first-run rule seeding (1638 default block rules from F73).

2. **Run a Demo scan first** -- explain the Demo Mode (ADR-0020) with synthetic emails. Lets users see how rule matching, results display, and the Process Results flow work without touching real email.

3. **Read-only manual scan with "move matched" target folder**:
   - Set Manual Scan to **Read-Only Mode** (Settings > Scan)
   - Set the **Default Folders > Spam folder** target to a safe destination (e.g., a user-created `Review-Spam` folder) so matched emails get **moved** rather than deleted
   - Run a manual scan
   - Walk through Results: which emails matched which rules
   - **For false positives** (legitimate emails matched as spam): use F56 to add a Safe Sender (recommend Entire Domain as the general best path; recommend Exact Email for transactional senders like banks/airlines/utilities where only one specific address is trusted)
   - **For real spam** that matched correctly: confirm the rule, no action needed
   - **For real spam not matched**: use F56 Add Block Rule -- recommend Entire Domain as default best practice; recommend Exact Email only for one-off senders that share a domain with legitimate mail (e.g., a single bad sender at gmail.com)

4. **Switch to "move all" mode and re-scan**:
   - After tuning rules and safe senders, change Manual Scan back to delete/move based on rule actions (not Read-Only)
   - Run another manual scan
   - Verify behavior matches expectations from the dry-run pass
   - If unexpected results: revert via Scan History -> per-email undo (where supported), then refine rules

5. **What ongoing, daily background scanning looks like** (added Sprint 39 refinement, Harold 2026-05-25):
   - **What it does day-to-day**: once Background Scanning is enabled (Settings > Background), the app scans the configured folders on a schedule (Windows Task Scheduler / Android WorkManager) without the app window being open. Known-rule matches are deleted (or moved per rule action) and safe-sender matches are moved to INBOX automatically -- so the user wakes up to an inbox that has already had the obvious spam cleared.
   - **What the user still sees / does**: the background scan does NOT auto-create rules. Emails that matched no rule ("no rules") are left in place and surfaced for review. So the steady-state daily loop is: background scan clears known spam overnight -> user opens Scan History > Scan Results periodically to process the "no rules" pool (add block rules / safe senders for senders the rules did not yet cover) -> those new rules apply on the next scan.
   - **Where to look**: Scan History shows each background run with its counts (deleted / moved / safe / no-rules). The per-account background log + CSV (F90, shipped) records per-message disposition for after-the-fact review.
   - **Expectation-setting**: the "no rules" count does not go to zero on its own -- it only shrinks as the user adds rules, and it grows as genuinely-new senders arrive. This is normal and expected; the goal is a *manageable* trickle, not zero.

6. **How often do I need to process the "no rules" section?** (added Sprint 39 refinement, Harold 2026-05-25):
   - **The hard constraint**: the scan only looks back `daysBack` days (the configured scan-range / retention window, Settings > Scan). A "no rules" email older than `daysBack` ages out of the scan window and will no longer appear in results. So the practical rule is: **review the "no rules" section at least once per `daysBack` window** if you want to catch every unaddressed sender before it falls out of range.
   - **Recommended cadence**: for a typical `daysBack` of 7-14 days, a weekly review of the "no rules" pool keeps the backlog bounded and ensures nothing ages out unreviewed. Heavy-mail accounts may prefer every 2-3 days.
   - **Why it is not "constant"**: the F82 "no rules" progress indicator (shipped Sprint 38) shows "M of N addressed -- K remaining" so the user can see at a glance whether the pool needs attention. If K is small and stable, the cadence can relax; if K is climbing, review more often or add broader rules (Entire Domain) to cover more senders per rule.
   - **Cross-reference S38-CI-4** (if shipped): the no-rule cursor is capped at the `daysBack` window, so the backlog is bounded by retention regardless of review cadence -- the walkthrough should state that older-than-`daysBack` no-rules age out automatically and are not lost data, just out of the active scan window.

**Implementation**:
- New `HelpSection.walkthrough` enum value
- Numbered step list with screenshots (or text-only initially) per step
- Each step links to the relevant in-app screen (e.g., "Open Settings > Scan" deep-link)
- Add a "First time? Start here" callout on the main Help screen entry pointing to the walkthrough
- Could be presented as a one-time onboarding overlay on first launch (out of scope for v1; flag for future consideration)

**Acceptance Criteria**:
- [ ] Walkthrough section accessible from Help screen
- [ ] All 6 numbered steps documented with concrete UI references
- [ ] Recommendation hierarchy stated clearly: Entire Domain (general best), Exact Email (provider/transactional senders), TLD (heavy-handed, last resort)
- [ ] Read-Only -> review -> tune -> move-all loop documented as the recommended adoption pattern
- [ ] Scan History referenced as the recovery path for unexpected actions
- [ ] Cross-references from Manual Rule Creation screen ("Need help choosing a rule type? See walkthrough")
- [ ] Step 5 explains ongoing daily background scanning: what runs automatically (delete known / move safe), what the user still does (process "no rules"), and where to look (Scan History + F90 logs)
- [ ] Step 6 answers "how often to process 'no rules'": at least once per `daysBack` window; weekly for typical 7-14 day ranges; explains the F82 progress indicator and that older-than-`daysBack` no-rules age out (not lost) per S38-CI-4

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
| 6.10 | 2026-07-20 | **Sprint 48 (emergency F119-b hotfix) complete + Phase 7 doc maintenance.** Root cause of the 0.5.5 Store dev-leak = a SPACE in a `secrets.*.json` key silently dropping `APP_ENV=prod` via `--dart-define-from-file` (independent of the F119 key typo). Fixed (cleaned secrets + gate + `--print-env` compiled-truth probe + Step 4.0 rewrite), bumped 0.5.5 -> 0.5.6, rebuilt + PROVEN prod (`--print-env` -> `APP_ENV=prod`), submitted 0.5.6 to Partner Center. Rolled **Last Completed Sprint** 46 -> 48; wrote `SPRINT_48_PLAN.md` (retroactive) + `SPRINT_48_RETROSPECTIVE.md` (lightweight, Claude-team only per Harold). Added backlog **F-VERSION-DERIVE** (derive version at runtime, not hardcoded in 6 log-filename sites). GitHub issues: 0 open. |
| 6.9 | 2026-07-19 | Added **F-WINSTORE-ASSETS** (Release Readiness, BACKLOG per Harold): update all Windows/Microsoft Store listing images (Partner Center screenshots + store logos/tiles + promo graphics + app icon). Rationale: listing images carry over from prior submissions and predate Sprint 40-47 UI; the 0.5.5 first-public-release listing should show the current app. Windows counterpart to GP-6 (Play Store assets). Effort M (~2-4h). |
| 6.8 | 2026-07-19 | **First public release submitted.** After the Sprint 47 develop->main merge (PR #273), reconciled prod worktree (no true divergence -- main = develop + GitFlow merge-commits + CNAME churn), synced it to origin/main `cdcb0da`. Version bump was already on main via F118 (0.5.5.0). Built the corrected MSIX (`flutter pub run msix:create`), **Step 4.0 F119 check PASSED** (build log: `--dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json`), manifest `0.5.5.0`, 17.6 MB. Harold SUBMITTED it to Partner Center for certification 2026-07-19 (in cert, 24-72h) -- the first true public release (2 -> ~20 users), corrected for the F119 dev/empty-creds defect. On cert PASS: Step 7 close-out + Android/Google Play track off HOLD. Also fixed a stale `build_windows_args` reference in STORE_RELEASE_PROCESS troubleshooting. GitHub issues: 0 open. |
| 6.7 | 2026-07-18 | Sprint 47 Phase 7 retrospective complete (all 5 apply-now IMPs applied). **Scope decisions (Harold, pre-merge release review)**: (1) prod `secrets.prod.json` CONFIRMED current (Store download signs in cleanly; re-review Dec 2026); (2) prod worktree bumps to 0.5.5 at release (working as expected); (3) **F33 prod-DB apply and the `cleanup_body_rules.dart` decode-failure fix DEFERRED to Sprint 48** and DECOUPLED from the Store release -- both operate on the local prod rules DB / a dev-only script, neither is bundled or user-facing, so they have zero impact on the 20 new Store users. Added F33-PROD + BUG-DECODE as Sprint 48 candidates (Core App Quality). Nothing now gates the develop->main release except Harold's merge. |
| 6.6 | 2026-07-15 | Sprint 47 backlog: added **F112-F119** from Harold's manual testing of the Store-installed 0.5.4 build (new "Sprint 47 -- Store 0.5.4 Manual-Testing Feedback" phase group). F119 (MSIX ships as APP_ENV=dev -- `[DEV]` title/About + `_Dev` data dir) is highest priority (P8) and blocks F113 clean-user testing. Others: F112 Review-No-Rule entry point everywhere, F113 new-account default profiles (provider-keyed folders + scan defaults, Export CSV ON), F114 retention defaults -> 90d, F115 selection-bar reorder, F116 Demo Scan completion matches Live, F117 Help footer -> app version, F118 post-Store-release housekeeping. All assigned to Sprint 47; carry-ins folded in. **0.5.4 confirmed LIVE on the Store (cert passed 2026-07-15)**. GitHub issues: 0 open. |
| 6.5 | 2026-07-11 | Sprint 46 completion + Sprint 47 pre-kickoff rollover (Phase 7 maintenance): rolled **Last Completed Sprint** 45 -> 46 (PR #270 merged); added the Sprint 46 row to the Past Sprint Summary table. Pruned the 3 shipped items **F64/F39/F33** from Next Sprint Candidates (DevOps + Core App Quality sections now reference-only). Refreshed Sprint Assignment header to Sprint 47 + "Last Reviewed" -> July 11, 2026 (dropped the Sprint 41 history line per the rolling window). Recorded **Sprint 47 carry-ins**: 0.5.5 version bump, F33 prod-DB apply (gated on Copilot round-6 decode-fix), CI_* repo secrets, IMP-3 CHANGELOG-cadence decision, round-6 polish. Backlog candidate re-presentation to Harold deferred to Phase 1.2 per his instruction. GitHub issues: 0 open. |
| 6.4 | 2026-07-02 | Sprint 46 Phase 1 backlog refinement: pruned the shipped **F111** from Next Sprint Candidates (Release Readiness section now empty -- GO delivered Sprint 45); refreshed Sprint Assignment header to Sprint 46 + "Last Reviewed" -> July 2, 2026. Added **F111** as a new reusable HOLD template under Periodic Reviews (Windows Store readiness verification will recur each release). Harold took **F64, F33, F39** off HOLD and selected them as Sprint 46 scope (Priority 10/20/30); standing constraint -- hold on other major changes until the 0.5.4 Store rollout completes. GitHub issues: 0 open. |
| 6.3 | 2026-07-02 | Sprint 45 completion + Sprint 46 pre-kickoff (Phase 3.2.1): created `docs/sprints/SPRINT_45_SUMMARY.md`; rolled **Last Completed Sprint** 44 -> 45; added the Sprint 45 row (PR #268) to the Past Sprint Summary table. Recorded the **develop -> main RELEASE MERGE** (Harold, 2026-07-02) -- F111-verified `0.5.4` codebase is now on `main`; Store upload targeted Sat/Sun on a stable network. F111 was Sprint 45's only item (Release Readiness), so Next Sprint Candidates is otherwise unchanged from the 6.2 refinement -- awaiting Sprint 46 scope selection. |
| 6.2 | 2026-07-01 | Sprint 45 backlog refinement (Harold direction): moved **F106** Priority 30 -> HOLD/Post-MVP and paired it under SEC-11b (F106 cannot start until the SEC-11b DB-encryption item ships + ~2 verification sprints). Added **F111** (Windows App Store upload readiness verification, P40) as a NEW active item under a new "Release Readiness" section -- selected as the Sprint 45 scope. |
| 6.1 | 2026-07-01 | Sprint 44 completion + Sprint 45 pre-kickoff (Phase 3.2.1 + Phase 1 backlog refinement): rolled **Last Completed Sprint** Sprint 42 -> Sprint 44 (43 + 44 both merged, PR #265 + #266); created `docs/sprints/SPRINT_44_SUMMARY.md`; added Sprint 43 (PR #265) + Sprint 44 (PR #266) rows to the Past Sprint Summary table. Pruned the 3 Sprint-44 shipped items (F107, F108, F109) from Next Sprint Candidates -- active near-term backlog is now empty; remaining candidates are the deep-dive templates (F70/F71), F64 (HOLD), Post-MVP (SEC-11b/F106), and the HOLD platform/UX tracks. Refreshed "Last Reviewed" -> July 1, 2026. Open follow-up recorded: Android-device retest of the Sprint 44 F108 dependency bumps. |
| 6.0 | 2026-06-25 | Sprint 43 Phase 7 currency pass (rolled into PR #265 before merge, per Harold): updated **Last Completed Sprint** Sprint 38 -> Sprint 42 (the last MERGED sprint; Sprint 43 becomes Last-Completed at Sprint 44 pre-kickoff once PR #265 merges). Filled the **Past Sprint Summary** gap -- added the missing Sprint 39 (PR #260) and Sprint 40 (PR #261) rows (table had jumped 38 -> 41). Refreshed the stale **"Last Reviewed: May 25, 2026"** marker to June 23, 2026 (Sprint 42 Backlog Refinement). Backlog items F107/F108/F109 added during Sprint 43; SEC-11b moved to Post-MVP (cipher -> SQLite3MultipleCiphers). Addresses the master-plan staleness flagged in the PR #265 Copilot review. |
| 5.16 | 2026-05-25 | Sprint 39 Backlog Refinement (Phase 1, sprint allocation): Assigned active backlog across 3 sprints (summary table added under Next Sprint Candidates). Sprint 39: S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3, S38-CI-7, F91, F89, S38-CI-4, F74, F92, BUG-S37-2, F77, F93. Sprint 40 target: F75, F25, F35, F37, F78, F79. Sprint 41 target: SEC-11b, F83. Renumbered the ambiguous shared "F52 Phase 2/3+" into distinct F94 (Android flavors) + F95 (iOS variants) and moved both to the Android/GP HOLD group. Additional HOLD moves (supersede row 5.15's "stay active" note for these): F63 (responsive design), SEC-15, SEC-8b, F6 (provider optimizations). F75 expanded with two new walkthrough steps (Step 5 ongoing daily background scanning; Step 6 "how often to process 'no rules'" tied to daysBack window + F82 indicator). Created `docs/sprints/SPRINT_39_PLAN.md` for Phase 3.7 approval. |
| 5.17 | 2026-05-25 | Sprint 39 execution + scope adjustment: S38-CI-7 (Opus 4.6 vs 4.7 eval) moved Sprint 39 -> Sprint 40 and re-scoped per Harold's clarified intent (4+ tasks run on BOTH models on separate branches; scored on process-doc adherence / instruction-following / architecture discipline / stopping-criteria / forward-looking code quality; ~6-10h). Sprint 39 now 12 tasks (all shipped + tests green 1530/0). BUG-S37-2 corrective: removed 6 malformed bundled TLD rules (.c .giw .nwm .xd .sweepss .qzz.io) from rules.yaml + v6 cleanup migration; .sweeps/.ca retained; all 194 ccTLDs (except .us/.uk/.ca) confirmed kept per Harold. S38-CI-1 X-close fixed round 3 (removed setPreventClose interception; root cause = window_manager 0.3.9 destroy()=PostQuitMessage-only + swallowed WM_CLOSE -> engine teardown during process-exit unwind w/ orphaned tray) -- manually verified working by Harold. Phase 5.3 manual testing complete 2026-05-25 (Harold): X-close, F91 (AOL dedup), F89 (auth warnings) all verified. Sprint 39 committed as a2bb75e. |
| 5.15 | 2026-05-25 | Sprint 39 Backlog Refinement (Phase 1): Removed S38-CI-5 (IMAP batch research) and F61 (architecture doc refresh) from backlog per Harold. Moved OFF HOLD into active candidates: F74 (Help FAQ, P60), F75 (Help walkthrough, P58), F76 (WinWright visual regression, P54), F25 (Rule Testing UI, P48), F35 (Rule editing UI, P46), F37 (Folder selectors two-level, P44), F78 (ManualRuleCreateScreen widget tests, P42), F77 (hookify "proceed?" rule, P52). F79 moved off HOLD AND rescoped from on-demand manual-run to a harness-BUILD task (one-command unattended runner + pre/post dev-DB snapshot guard, P50, Issue #240); new cadence = full sweep at end of any sprint touching `lib/ui/**` once harness ships -- policy written into `docs/TESTING_STRATEGY.md` When-to-Run + `feedback_winwright_policy.md` memory. Verified-against-code current-state notes added to F25, F35, F37, F39, F78, F79, H2, H4 -- all confirmed NOT essentially complete (F35/H2 PARTIAL via Sprint 34-38 ManualRuleCreateScreen + pattern_generation; rest NOT DONE). Non-HOLD review (Step 6.1) removed 6 stale completed items: F90 (live-scan logging, shipped PR #259), F81 (store release docs, shipped Sprint 36 commit 602053e -- `docs/STORE_RELEASE_PROCESS.md` exists), F85 (content-management for long strings -- ALL 3 phases shipped Sprint 38: ADR-0038 Accepted, 21 Help `.md` files + manifest exist, Settings audit found nothing >500 chars per `assets/content/audit-log.md`), F82 (Scan History no-rules progress indicator -- shipped Sprint 38 Rounds 4-9, design option (a); `_buildNoRuleProgressFooter` + `_reEvaluateNoRuleEmails` in results_display_screen.dart, CHANGELOG 2026-05-17), BUG-S35-1 (duplicate TLD check, shipped Sprint 36), BUG-S36-1 (semantic subsumption, shipped Sprint 37 verified CHANGELOG L177). Second-pass CHANGELOG cross-check of all remaining active IDs (2026-05-25) caught 5 more shipped-but-still-listed stragglers, all Sprint 38: F86 (live reload of rules during scan, Task 5 / Round 1 redesign), F88 (true Gmail batchGet endpoint, Task 4), F87 (Settings icon on Scan History, Task 1), F80 (Phase Cheat Sheet, prepended to SPRINT_EXECUTION_WORKFLOW.md), BUG-S37-1 (background-scan DB-locked mutex probe, Task 2). Moved 4 Android security items to the Android/GP HOLD group (gated by the on-HOLD Play release): SEC-4, SEC-6, SEC-7, SEC-9. SEC-8b + SEC-11b stay active (Platform: All); SEC-15 stays active (now unblockable -- its F37 dependency was activated this session). Resolved S38-CI-3 / F84 double-count: both tracked the same Shift+Click / Ctrl+Click-drag selection work at P65 (F84 Sub-task A shipped Sprint 38; only B+C remain). Consolidated into the single S38-CI-3 carry-in entry; removed the redundant standalone F84 entry. |
| 5.14 | 2026-04-19 | Sprint 35 retro Category 13 addendum: F81 added as Sprint 36 carry-in (mandatory, not backlog -- Issue #242). Store release process documentation -- new `docs/STORE_RELEASE_PROCESS.md`, deprecate faulty `build-msix.ps1`, walk team through Partner Center upload. Triggered by Sprint 35 store-prep gap-finding. |
| 5.13 | 2026-04-19 | Sprint 35 store release prep: Bumped dev version 0.5.1.0 -> 0.5.2.0 (prod at 0.5.1.0 in store; 0.5.2.0 is next submission). Built signed MSIX (17.4 MB) at `mobile-app/build/windows/x64/runner/Release/my_email_spam_filter.msix`. Sprint 36 to bump dev to 0.5.3.0. |
| 5.12 | 2026-04-19 | Sprint 35 retrospective complete (Phase 7): Applied four of five proposed process improvements -- P1 Phase Auto-Advance Rule (CLAUDE.md item 7), P2 Standing Approval Inventory (Phase 3.7), P4 Model-Version Pitfalls appendix (CLAUDE.md), P5 Sprint Resume Pattern memory. Backlogged P3 as F80 (Phase Cheat Sheet, Issue #241). Closed Category 2 testing gap by adding Phase 5.1.1 step 2a (test-assertion sibling sweep for structural-data changes). Promoted Sprint 35 to Last Completed Sprint; added Sprint 35 row to Past Sprint Summary. |
| 5.11 | 2026-04-19 | Sprint 35 in progress: Removed BUG-S34-1 and F69 (both shipping in Sprint 35 PR #238). Added BUG-S35-1 (manual rule UI accepts duplicates -- Issue #239) discovered during F69 execution; cleanup required direct SQLite delete because UI couldn't disambiguate the duplicate from the bundled rule. Added F79 (Full WinWright E2E sweep) as HOLD item -- Issue #240, on-demand only, distinct from per-sprint conditional WinWright runs. |
| 5.10 | 2026-04-19 | Sprint 34 post-merge cleanup (pre-Sprint-35 backlog refinement): Removed F56, F73, F62, F72 from Next Sprint Candidates -- all four shipped in Sprint 34 (PR #236, see CHANGELOG 2026-04-18). Master plan now reflects only incomplete work for Sprint 35 planning. F69 (WinWright E2E) kept on list -- Sprint 34 shipped only the JSON test scripts (line 35 of CHANGELOG); execution work remains. |
| 5.9 | 2026-04-19 | Sprint 34 post-merge: Added BUG-S34-1 (stale `expect(resetResult.rules, 5)` assertion in default_rule_set_service_test.dart that escaped F73 review and broke develop after PR #236 merge). Carry-in for Sprint 35 per Harold (option 3). |
| 5.8 | 2026-04-16 | Sprint 33 completion: Removed F53, F54, F55, F65, F66 (features) and SEC-1b, SEC-14, SEC-19, SEC-22 (security). SEC-8 split -- HTTPS pinning done; SEC-8b tracks remaining IMAP pinning. SEC-11 split -- infrastructure done; SEC-11b tracks SQLCipher driver swap + migration. Added Sprint 33 to Past Sprint Summary. Updated Last Completed Sprint. |
| 5.7 | 2026-04-14 | Sprint 33 planning: Moved F61 to HOLD per user direction (partial doc refresh happens organically in Sprint 33 via ARCHITECTURE.md updates for SQLCipher/HelpScreen/DataDeletionService/PatternCompiler). |
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
