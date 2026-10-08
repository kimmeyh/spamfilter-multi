# All Sprints Master Plan

**Purpose**: Single source of truth for all planned work -- features, bugs, spikes, and Google Play Store readiness items. Used alongside GitHub Issues for sprint planning and backlog management.

**Audience**: Claude Code models planning sprints; User prioritizing future work

**Last Updated**: 2026-10-04 (**Sprint 75 COMPLETE** -- PR #448; F238 shipped, so the 0.17.0 release hold is satisfied; F216, F214, F236, F215, Task 7 delivered; F239 delivered Sign In Again, its Android renewal spike FAILED (-> F246); F243 added at Manual Validation; retro IMP-1..6 applied; F244/F245/F246 added.) Earlier 2026-09-29 (**Sprint 74 COMPLETE** -- PR #440; retro IMP-1/2/3/4/6 applied; F240/F241 added from Category 14; 0.17.0 held for F238.) Earlier 2026-09-27 (Sprint 74 Manual Validation: **F238 (Issue #441) added as the Sprint 75 release blocker for 0.17.0**, model Fable 5.1; no AAB until the Sprint 74 and 75 PRs both merge.) Previous: 2026-09-22 (**Sprint 72 COMPLETE** -- PR #420 -> develop. Ran on the Sprint 71 branch; Sprint 71 was never separately executed and its stub is marked SUPERSEDED. Delivered: F233 diagnostic log + the header-only CSV export fix, F232 mechanism A (historical-view rules now act on the mailbox; MECHANISM B REMAINS UNDIAGNOSED and is now instrumented), F228 honest action toast, F230+F231 action-sheet layout and durable outcomes, F217 honest Doze caveat (MECHANISM DELIBERATELY NOT BUILT -- the "is this the only way" search Harold required found it is not, and that the exemption carries a Play policy cost), F229 export half (the screen half was attempted and REVERTED after it overflowed by 18px at phone width). Suite 2,155 -> 2,233; analyzer clean; hooks 75/0; WinWright 2/2 twice; CI all green. **THREE CRITICAL findings across two reviews, all fixed, none deferred** -- and two of them were defects introduced BY this sprint: the F232 fix created an unintended deletion path from screen load (a method three callers share, the third safe only by accident), and the diagnostic logger silently destroyed concurrent records, which is the exact failure it existed to prevent. Manual validation found F233 shipped with NO UI at all -- ten tests passed via the test seam. Retrospective: Harold 12x Very Good; IMP-1..IMP-5 approved and applied. NEW backlog: F234 (read-only as a preview mode) and F235 (Android Doze via setExactAndAllowWhileIdle, TARGETED FOR SPRINT 73). Earlier history in prior revisions of this line (git).)

## How to Maintain This Document

This section describes when and how to update this document during sprint execution. Referenced by SPRINT_EXECUTION_WORKFLOW.md (Phases 2.1, 3.2, 7.7), SPRINT_CHECKLIST.md, SPRINT_PLANNING.md, and SPRINT_RETROSPECTIVE.md.

### When to Update

| Sprint Phase | What to Update |
|-------------|----------------|
| **Phase 2 (Pre-Kickoff)** | Verify "Last Completed Sprint" is current; confirm all items from completed sprint are marked done or removed |
| **Phase 3 (Planning)** | Review "Next Sprint Candidates" for completeness; add any new items found in GitHub Issues; re-prioritize list; move selected items into sprint plan |
| **Phase 7 (Retrospective)** | Update "Past Sprint Summary" table; update "Last Completed Sprint"; remove completed feature/bug detail sections; add new issues discovered during sprint |
| **Phase 8.2 (Refinement pass 1 -- completeness sweep)** | Verify the completed sprint's items are marked done or removed; confirm "Last Completed Sprint" is current; prune shipped items from Next Sprint Candidates. Does NOT select scope. |
| **Phase 8.3 (Store release)** | Update "Last Completed Sprint" with the store release outcome (`STORE_RELEASE_PROCESS.md` Step 7). **Added F170 -- the release mutates this document, and that trigger was previously unlisted.** |
| **Phase 8.4 (Refinement pass 2 -- scope selection)** | Full review of all sections; re-prioritize; add/remove items; verify GitHub Issue alignment; capture the Product Owner's selection for Phase 3. |

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
| **BACKLOG_REFINEMENT.md** | Backlog refinement process | MANDATORY twice per cycle -- Phase 8.2 (completeness sweep) and Phase 8.4 (scope selection); extra passes on request |
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
| 47 | docs/sprints/SPRINT_47_RETROSPECTIVE.md | [OK] Complete | Jul 11-18, 2026 (PR #272) |
| 48 | docs/sprints/SPRINT_48_RETROSPECTIVE.md | [OK] Complete | Jul 19-20, 2026 (PR #274; F119-b hotfix) |
| 49 | docs/sprints/SPRINT_49_SUMMARY.md | [OK] Complete | Jul 21-23, 2026 (PR #276) |
| 50 | docs/sprints/SPRINT_50_SUMMARY.md | [OK] Complete | Jul 25-27, 2026 (PR #278; 0.5.8 submitted) |
| 51 | docs/sprints/SPRINT_51_SUMMARY.md | [OK] Complete | Jul 27-30, 2026 (PR #285; 0.5.8 LIVE Jul 29) |
| 52 | docs/sprints/SPRINT_52_SUMMARY.md | [OK] Complete | Jul 30-Aug 2, 2026 (PR #292) |
| 53 | docs/sprints/SPRINT_53_PLAN.md | [OK] Complete (retro skipped, PO decision) | Aug 3, 2026 (PR #295/#296; 0.5.9 LIVE Aug 3) |
| 54 | docs/sprints/SPRINT_54_RETROSPECTIVE.md | [OK] Complete | Aug 3-10, 2026 (PR #298/#303) |
| 55 | docs/sprints/SPRINT_55_RETROSPECTIVE.md | [OK] Complete | Aug 9-10, 2026 (PR #304; 0.6.0.0 LIVE Aug 10) |
| 56 | docs/sprints/SPRINT_56_RETROSPECTIVE.md | [OK] Complete | Aug 12-13, 2026 (PR #310) |
| 57 | docs/sprints/SPRINT_57_RETROSPECTIVE.md | [OK] Complete | Aug 13-14, 2026 (PR #314 -> develop, PR #316 -> main) |
| 58 | docs/sprints/SPRINT_58_SUMMARY.md | [OK] Complete | Aug 14-15, 2026 (PR #317; 0.7.0.0 LIVE Aug 15) |
| 59 | docs/sprints/SPRINT_59_SUMMARY.md | [OK] Complete | Aug 15, 2026 (PR #326; 0.8.0.0 LIVE Aug 15; Android builds restored) |
| 60 | docs/sprints/SPRINT_60_SUMMARY.md | [OK] Complete | Aug 15-16, 2026 (PR #335; 0.9.0.0 LIVE Aug 16; scope shipped in 0.10.0.0 LIVE Aug 16 22:17) |
| 61 | docs/sprints/SPRINT_61_SUMMARY.md | [OK] Complete | Aug 16-21, 2026 (PR #347; F161 Android scheduler validated, ADR-0042, Phase 8 encoded) |
| 62 | docs/sprints/SPRINT_62_SUMMARY.md | [OK] Complete | Aug 21-23, 2026 (PR #355; scan robustness F177/F175/F174, MV UX F178/F176, F163 skips 26->15) |
| 63 | docs/sprints/SPRINT_63_SUMMARY.md | [OK] Complete | Aug 24-27, 2026 (PR #366; F180 deferred body fetch ~10x, F185 Gmail decode, F94 flavors, Android/GP track opened) |
| 64 | docs/sprints/SPRINT_64_SUMMARY.md | [OK] Complete | Aug 27 - Sep 4, 2026 (PR #378; full Android release chain SEC-9/GP-2/GP-9/GP-8/GP-3/SEC-4 Play-submittable, Play account + legal docs live, F186 Body Phrase rules, F187 1,947 URL-shape rules purged, F188) |
| 65 | docs/sprints/SPRINT_65_SUMMARY.md | [OK] Complete | Sep 4-7, 2026 (PR #385; Google Play closed-test readiness -- Data safety, App content + reviewer access via Demo Mode, icons, listing copy/assets, tester roster. Zero product-code diff. Store Submission 22 listing-only corrections shipped mid-sprint) |

| 66 | docs/sprints/SPRINT_66_SUMMARY.md | [OK] Complete | Sep 7-8, 2026 (PR #391; Play closed-test submission and the first real tester round) |
| 67 | docs/sprints/SPRINT_67_SUMMARY.md | [OK] Complete | Sep 8-9, 2026 (PR #397; F193 Phase 5 evidence gate, emulator toolchain corrected -- two Android SDK installs, the hardcoded path selected the 2019 one) |
| 68 | docs/sprints/SPRINT_68_SUMMARY.md | [OK] Complete | Sep 9-10, 2026 (PR #403 -> develop, #404 -> main; Yahoo + iCloud shipped (two integers), privacy-page correction, F198 shipped NO hook deliberately. Defining pattern: four screenshots read wrong, three caught by Harold) |
| 69 | docs/sprints/SPRINT_69_SUMMARY.md | [OK] Complete | Sep 11-14, 2026 (PR #410 -> develop, #411 -> main; Android tester experience -- sign-in dead end, dark-mode contrast (9 instances not 1), YAML import, nav-bar overlap on 21 of 23 screens) |
| 70 | docs/sprints/SPRINT_70_SUMMARY.md | [OK] Complete | Sep 17-19, 2026 (PR #418 -> develop, #419 -> main; scan lifecycle + sign-in + toolchain. 6/6 planned plus 4 unplanned fixes. Both CRITICAL review findings were gates reporting protection they did not provide; three defects were introduced by earlier fixes in the same sprint) |
| 71 | docs/sprints/SPRINT_71_PLAN.md | [SUPERSEDED] | Never executed separately -- its stub's carry-ins were folded into Sprint 72, which ran on the Sprint 71 branch |
| 72 | docs/sprints/SPRINT_72_SUMMARY.md | [OK] Complete | Sep 22, 2026 (PR #420 -> develop, #429 -> main; 0.15.3, NOT submitted to either store. F233 diagnostic log + empty-export fix, F232 mechanism A, F228 honest action toast, F230/F231 action sheet, F217 Doze caveat. Two of three CRITICAL review findings were defects the sprint introduced) |
| 73 | docs/sprints/SPRINT_73_SUMMARY.md | [OK] Complete | Sep 22-23, 2026 (PR #435 -> develop; 0.16.0. F235 Doze scheduling, F234 read-only preview, F224+F207 cancel scan, F229 version on every screen, F226. Two CRITICAL defects were inert features with green suites -- verification by source text, not behavior) |
| 74 | docs/sprints/SPRINT_74_SUMMARY.md | [OK] Complete | Sep 24-29, 2026 (PR #440 -> develop; 0.17.0, HELD for F238. Per-account scan lock (any type, fail closed, dead holders reaped, 2-6 min busy retry), F232 mechanism B fixed, F222 Sort chip + row dates, F202 provider folder defaults, F206 exports + clear history + redaction, Gmail keeps sign-in, subject rules = Keyword (DB v10). Device checks moved to Sprint 75) |
| 75 | docs/sprints/SPRINT_75_SUMMARY.md | [OK] Complete | Oct 2-4, 2026 (PR #448 -> develop; 0.17.0 kept by exception, hold satisfied. F238 stop a background scan for a manual one (DB v11), F239 Sign In Again (renewal spike FAILED -> F246), F243 Windows background scans run with the app open, F216/F214/F236/F215, Task 7 WinWright + widget tests, four MV fixes. Phone checks moved to Sprint 76) |
| 76 | docs/sprints/SPRINT_76_SUMMARY.md | [OK] Complete | Oct 4-6, 2026 (PR #455 -> develop; 0.17.6+14, six closed-test builds. Unattended Android background scanning works -- overnight 0.17.4: 95 worker starts, 111/113 completed, 10 spam deletions with the app unopened. F248 scan diagnostics, F249 stop/KEEP/spacing, F250 Gmail renewal by stored refresh token, F251-F253 (battery row, notification trigger, ADR-0044), nine MV fixes. Fold checks carried as MV76-1) |

**Key Achievements**: See CHANGELOG.md for detailed feature history.

---

## Last Completed Sprint

**Sprint 76** (2026-10-04 -- 2026-10-06; PR #455 -> develop; version 0.17.6+14; six Play closed-test builds 0.17.1-0.17.6)
- **Type**: the 0.17.0 field issues (F248-F250), grown at Harold's direction into making unattended Android background scanning work (F251-F253 and nine Manual Validation fixes).
- **F248 (#452)**: the diagnostic log covers every scan, sign-in and renewal step, worker trigger and delay, stop reason, rule-update failures with reasons; a cross-isolate lock-file mutex (the per-process OS lock did not separate isolates on Android).
- **F249 (#453)**: cancel checkpoints; Doze enqueue KEEP (REPLACE cancelled running scans); 5-minute spacing, never a skip; a scan where every folder failed is a failure, retried.
- **F250 (#454)**: native sign-in cause named (`[16] Account reauth failed`); Android renewal falls back to the stored refresh token with the Android client -- confirmed on the Fold, overnight.
- **F251-F253 (#456-#458)**: No Rule banner total; "Keep background scans running" battery row; "Scan when new mail arrives" notification listener (ADR-0044, package name only, off by default).
- **MV fixes**: Gmail safe-sender move out of Spam; Gmail custom-label ID in incremental fetch; scan screen no longer zeroes a running scan; rule update skips a safe sender already in the target; export header row.
- **Field evidence**: overnight 0.17.4 -- 95 worker starts, 111/113 completed, 10 spam deletions with the app unopened; 0.17.5 -- 52 scans all completed, zero broken log lines.
- **Moved to Sprint 77** (Harold): MV76-1 Fold checks (F253 notification trigger, reboot, export header, rule-update fix, F250 account state, MV74-3).
- **Results**: suite 2,508 -> 2,601 (15 skipped), analyzer clean, WinWright 3/3 (85 steps), hook suite 91 -> 104, first JVM test; mutations M118-M209. Copilot: Findings None. Retro: Harold all Very Good; IMP-1/2/3/4/6 applied (kept AAB in dist/, versionCode reuse gate, OS-primitive rule, blind-staging hook, "Existing behavior relied on" card line); IMP-5/7/8b skipped; IMP-8a/c to backlog.

## Next Sprint Candidates

**Sprint 76 scope -- COMPLETE 2026-10-06 (PR #455)**: F248 (#452), F249 (#453), F250 (#454), F251 (#456), F252 (#457), F253 (#458), plus nine Manual Validation fixes and the 7.7.1 review fixes. Plan: `docs/sprints/SPRINT_76_PLAN.md`.

**Sprint 75 scope -- COMPLETE 2026-10-04 (PR #448)**: F238 (#441), F216 (#444), F214 (#445), F236 (#446), F239 (#442), F215 (#447), Task 7 (#449), F243 (#450, added at Manual Validation). Plan: `docs/sprints/SPRINT_75_PLAN.md`.

**Sprint 74 scope -- COMPLETE 2026-09-29 (PR #440)** (Phase 8.4 pass 2, selected by Harold 2026-09-24): MV74-1 (#428), MV74-2 (#434), MV74-3 (#422, #433), F202 (#438), F222 (#437), F232 (#422), F206 (#439), F205 (#433). Plan: `docs/sprints/SPRINT_74_PLAN.md`.

**Last Reviewed**: October 6, 2026 (Sprint 76 cycle, Phase 8.2 pass-1 COMPLETENESS SWEEP -- no scope selected: PR #455 merged to develop (96a9cfe) and main (31b7135); Sprint 77 branch opened from the Sprint 76 branch; #452 #453 #454 #456 #457 #458 closed by hand; #428 #433 stay open inside MV76-1; triad present; shipped F248-F253 already pruned at close-out; MV74-1/MV74-3 folded into MV76-1; F247 relabeled not-delivered; F258-F264 added at 7.7.1.) Previous: October 4, 2026 (Sprint 75 cycle, Phase 8.2 pass-1 COMPLETENESS SWEEP -- no scope selected: PR #448 merged to develop (85c602c) and main (e724faa); Sprint 76 branch opened from the Sprint 75 branch; #441 #442 #444 #445 #446 #447 #449 #450 closed by hand; #428 #433 stay open as Sprint 76 phone checks; triad present; shipped F238/F239/F216/F214/F236/F215 already pruned at close-out; F247 added from the PR reviews; MV74-1 dependency moved to the 0.17.0 Play build.) Previous: October 2, 2026 (Sprint 74 cycle, Phase 8.2 pass-1 COMPLETENESS SWEEP -- no scope selected: shipped MV74-2, F202, F206, F232, F222 pruned; MV74-1 + MV74-3 (F205) re-labeled as Sprint 75 phone validation; #422 #434 #437 #438 #439 closed by hand; 0.17.0 store release N/A (held for F238).) Previous: September 24, 2026 (Sprint 73 cycle, Phase 8.2 pass-1 COMPLETENESS SWEEP -- no scope selected: 6 Sprint 73 DONE cards cleared (F235 -> MV74-1, F234, F229, F226, F224, F207 -> MV74-2); new F236 (YAML export version, from #427) and F237 (Android build-log noise); issues #426 #430 #431 #432 closed; master plan rolled to Sprint 73.)

All incomplete items in relative priority order. Priority in increments of 10; items that can sprint together in increments of 2. HOLD items grouped at bottom. See [Feature and Bug Details](#feature-and-bug-details) for deep-dive specs. See [BACKLOG_REFINEMENT.md](BACKLOG_REFINEMENT.md) for presentation format rules.

### Sprint 77 carry-in -- Fold validation on 0.17.6 (Harold, Sprint 76 close, 2026-10-06)

**MV76-1. Finish the Sprint 76 Fold checks on 0.17.6 (~validation time) Priority 1 -- CARRY-IN**
- F253 AC-5: a scan started by a mail app's new-mail notification (`trigger=notification` in the log); confirm the AOL and Yahoo package names on the device (#458).
- MV74-1 reboot half: background scans resume after a phone restart without opening the app (#428). The Doze half PASSED on the 0.17.4 overnight run (95 worker starts, 111/113 completed).
- The scan-export header row on a new daily `.data.csv`.
- A Results rule update for an Inbox safe sender reports no failure (the 0.17.6 re-process fix).
- F250: the Google account state screenshot on the Fold; decide whether the native sign-in still matters now that refresh-token renewal works (#454).
- MV74-3: classify every scan error from normal use, or record zero (#433).

**R76-1. Battery deep dive for "Scan when new mail arrives" -- A/B tests on the Android emulator Priority 2 -- CARRY-IN (Sprint 76 retro Cat 13, Harold)**
- Deep dive on how to minimize battery usage for Android when set to run Background jobs on "scan when new mail arrives" while maintaining functionality; then add potential items to the backlog in priority order based on most likely success, written like A/B tests to be tested on the android simulator. OK to apply to both Windows and Android, primarily targeting Android (split solutions between platforms only if it greatly benefits Android).

**R76-2. Rework the Background section for the per-account new-mail switch and interval control Priority 3 -- CARRY-IN (Sprint 76 retro Cat 13, Harold; UPDATED 2026-10-06 by F264)**
- Originally "move 'Scan when new mail arrives' to the General tab?". Answered by F264 (Harold, 2026-10-06): the switch becomes PER ACCOUNT, so it stays in each account's Background section. Remaining work: deep dive on how the whole "Background scanning" section and its help text change for the per-account switch and the new interval control.

**R76-3. Deep dive: Heuristics, ML and GenAI spam identification from stored email content Priority 4 -- CARRY-IN (Sprint 76 retro Cat 13, Harold)**
- Result: one or more backlog items for Heuristic, ML and GenAI pipelines and how they are used -- updates to YAML imports (new delete rules: known bad domains, subject regex, body regex), new tools to find and identify safe senders, on-device Heuristics/ML/GenAI tools.

**R76-4. Store a history of email content for future Heuristics/ML/GenAI identifiers Priority 5 -- CARRY-IN (Sprint 76 retro Cat 13, Harold)**
- **Input from R76-3 (2026-10-07)**: the recommended fields (what to store, what never to store) are in Section 6 of `docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md`; storing content beyond the 100-character preview is a Class-1 decision with a privacy-policy revision (F273).
- Probably a database of fields -- design and implement. Fed by the Windows and Android scans (eventually iPhone); no duplicate emails; initially populated from the existing delete and safe-sender rules; Harold has a partial history of deleted emails to run through for more examples.

### Backlog from the Sprint 77 Manual Validation (Harold, 2026-10-07)

**F281. Deep dive: best-practice UI for "run every <interval>" in Background scanning (~90-120m research + implementation card) Priority 6 -- NEXT SPRINT (Harold, Sprint 77 MV step 1)**
- Harold: *"The UI just seem awkward for the Background Scanning ... deep dive into UI best practices for selecting time (in this case run something every <>)."* The F264 control (unit dropdown + typed number) works but reads awkwardly.
- Deliverable: at least the 3 best alternatives, each with a mockup, pros, cons, and Windows + Android fit (ADR-0042 parity: one shared control on both platforms), with sources for the practices cited. Recommendation and why. Harold picks one; the pick becomes an implementation card in the same sprint.
- Requirements for every alternative:
  - Minimum every 5 minutes (`kMinIntervalMinutes`). Maximum every 24 hours -- **a change**: today `kMaxIntervalMinutes` is 99 hours.
  - Suggest 15 minutes: the first time the control is shown for an account, it defaults to 15 minutes.
  - Great flexibility (not only a short fixed preset list).
  - Shown ONLY when a background mode is on: Android has two (scheduled background scanning, "Scan when new mail arrives"); Windows has one. **A change**: today the control is shown even when background scanning is OFF, deliberately (`settings_screen.dart` F264 R-11 comment, ISSUE #123/#124, so the user could set it first). Name what happens to a saved interval when the control is hidden.
  - Keeps the save-on-change behavior Harold chose at MV-Q3 (no Save button).
- Overlaps R76-2 (Background section rework); do them together.
- Control and screen: Settings > Account tab > Background > "Scan every".

### Backlog from the Sprint 76 retrospective

**F256. Rename `GmailWindowsOAuthHandler` to reflect both platforms Priority 60 -- backlog (Sprint 76 retro IMP-8a, Harold 2026-10-06)**
- Since Sprint 76 it serves Android too (`refreshAccessTokenMobile`, the mobile browser sign-in), so the name misleads. Rename the class and file; update callers, tests and docs.

**F257. Scan History shows which mechanism started each background scan Priority 55 -- backlog (Sprint 76 retro IMP-8c, Harold 2026-10-06)**
- The worker already logs `trigger=doze-alarm|periodic|notification|test` (F252/F253); persist it on the scan row and show it in Scan History, so "why did this scan run" is answerable without the diagnostic log.

### Backlog from the Sprint 76 7.7.1 final code reviews (Harold, 2026-10-06: "otherwise as recommended")

Each item is fixed PREVENTION FIRST (SPRINT_EXECUTION_WORKFLOW.md 7.7.1): name how the class is prevented, extending the connected existing control, before the instance fix.

**F258. Gmail moves to a custom label send the label NAME, not its ID Priority 25 -- backlog (7.7.1 code review H-2; predates Sprint 76)**
- Five write sites pass a stored folder NAME where Gmail expects a label ID: `deleteMessage` (`addLabelIds: [targetLabel]`), `moveMessage` via `_folderToLabelId`, `moveLabels` (`add: [target]`), and delete-to-custom-folder via `moveToFolderBatch`. The folder picker saves `displayName`, so a Deleted-Rule folder or safe-sender target such as "Unwanted" gets 400 "Invalid label" on every move. Prevention: route EVERY label write through the Sprint 76 `_labelIdFor` resolver (the read path already uses it; `_getOrCreateLabel` is the precedent) and add a source gate that no `addLabelIds:` / `removeLabelIds:` receives an unresolved folder name. Needs a Fold or Windows Gmail check with a custom target.

**F259. A missing Gmail label scans as 0 messages with no trace; history cursor is per account Priority 35 -- backlog (7.7.1 review L-3 / silent-failure M-8)**
- `_labelIdFor` returning null yields an empty fetch with no log line and no F202 "missing folder" classification, cached for the connection (a renamed label scans empty forever; the lookup is case-sensitive). Related, pre-existing: the incremental history cursor is stored per ACCOUNT (`getLastHistoryId(accountId)`), and INBOX saves the current historyId first, so later folders (a custom label, SPAM) read from "now". Prevention: route null through the existing F202 missing-folder path (extends that classifier) and store the cursor per account + folder.

**F260. Stale log-lock takeover by atomic rename Priority 50 -- backlog (7.7.1 silent-failure M-7; Harold Q11 "can a semaphore-type technique be used")**
- Two writers that break the same stale `<log>.lock` can race (one deletes the other's fresh lock, or one writes unlocked beside the other). Extend the existing lock-file mutex with an atomic takeover: rename the stale lock to a unique name -- only one rename can succeed on Android/Linux and Windows -- and only that winner deletes it and retries the create; losers simply retry. This makes the lock a true binary semaphore without a new mechanism. Also have `deleteAll` remove orphaned `.lock` files.

**F261. Export header recognized by its first column, not the full text Priority 65 -- backlog (7.7.1 silent-failure M-9)**
- The daily `.data.csv` header row is skipped by exact match with the CURRENT header text, so after any column change an older day file's header would read as a data row; two scans creating the same new day file at once could write two headers. Prevention: recognize the header by its first column name in the one shared `scanSheetHeaderLine` helper.

**F262. Gmail renewal failures named by cause; stale log line Priority 45 -- backlog (7.7.1 silent-failure M-5)**
- Three refresh failures all read "Session expired. Please sign in again.": a build-configuration error (`ANDROID_GMAIL_CLIENT_ID is not set`, which signing in cannot fix), a revoked refresh token (`invalid_grant`), and a network drop (transient -- should not mark the account as needing sign-in). The diagnostic line "refresh token present, not used on Android" is false since Sprint 76. Prevention: classify in the existing `GmailSignInRequiredException` / `humanize` path rather than per call site.

**F263. Background scan spacing: per-worker budget, Test Background Scan, sign-in skip Priority 40 -- backlog (7.7.1 review M-1, M-2, silent-failure LOW)**
- (Harold, 2026-10-06: "3. a" -- confirmed as backlog.) The 5-minute spacing and 6-minute busy cap are per ACCOUNT, so one Android worker scanning several accounts in sequence can exceed WorkManager's ~10-minute run limit and leave an `in_progress` row. Test Background Scan also waits out the spacing (up to 5 minutes with nothing visible), and an account that needs sign-in still waits before it is skipped. Prevention: one spacing budget per worker run in `BackgroundScanCore` (extends the existing `cappedBusyWait` cap), the test trigger exempt, and the sign-in check before the wait.

**F264. Per-account background interval (unit + number) and per-account "Scan when new mail arrives" Priority 10 -- backlog (Harold, 2026-10-06, 7.7.1 item 10; read back and confirmed "1. a 2. a")**
- **Interval control, per account, Windows and Android** (replaces the fixed 15/30/60/120/240 dropdown and the `ScanFrequency` list): a unit dropdown FIRST -- **Minutes | Hours** -- then a number box with room for 2 digits (1-99). The interval is number x unit, stored in minutes through the existing per-account frequency override (F98, ADR-0039). Minimum **5 minutes** (to limit battery use); an entry under 5 minutes is flagged inline ("Minimum is 5 minutes, to limit battery use") and not saved. Maximum **99 hours**.
- **Helper text** (the honest floor): "Android runs background scans when the phone allows; while it is idle, expect up to about 45 minutes between scans." Basis (verified 2026-10-06): Android docs -- in Doze, `setAndAllowWhileIdle` alarms fire "no more than once per nine minutes, per app"; the Frequent standby bucket allows 2 alarms per hour, Rare 1 per hour, Restricted 1 per day (developer.android.com/topic/performance/power/power-details); the Fold's 0.17.4 overnight run had a longest gap of 41 minutes.
- **Below 15 minutes on Android**: WorkManager's periodic minimum is 15 minutes ("The minimum repeat interval that can be defined is 15 minutes"), so 5-14 minutes run through the existing F235 Doze alarm chain at the chosen interval; Android limits that to about 9 minutes while idle and to about 6 minutes in the Working set bucket (10 alarms per hour). Windows: Task Scheduler minutes/hours directly; confirm its longest repetition interval at implementation (unverified).
- **Fixes a latent bug**: the current dropdown offers 2 and 4 hours, but `ScanFrequency.fromMinutes(120|240)` returns `disabled`, so `settings_screen.dart:1443-1444` returns without rescheduling (read from code; not observed on a device).
- **"Scan when new mail arrives" becomes per account**, in each account's Background section beside the interval. Notification access stays one Android permission for the app. Android reports only WHICH MAIL APP posted, not which account, so: Gmail app -> Gmail accounts with the switch on; AOL app -> AOL accounts; Yahoo Mail -> Yahoo accounts; Samsung Email and Outlook (any provider) -> every account with the switch on. The 5-minute spacing still applies. Replaces the app-wide switch from F253 (#458); R76-2 updated accordingly; R76-1 (battery A/B) should measure the per-account mapping.
- Prevention first: one shared interval parser/validator (unit + number -> minutes, min/max) used by both platforms' UI and the schedulers, with tests at 4, 5, 99 minutes and 99 hours; the package-to-provider mapping lives in the existing `MailNotificationPolicy` (extend it, JVM-tested).
- **Sprint 77**: SELECTED (Task 5, #465) with Harold's decisions Q8-Q14 recorded in `docs/sprints/SPRINT_77_PLAN.md`.

**F277. Fold energy check: interval 5 against interval 15 (~45-60m + phone time) Priority 20 -- backlog (Sprint 77 R76-1, was R77-BAT-1)**
- Phase: Core App Quality
- Platform: Android
- The emulator measures counts, not energy. Decision rule for the F264 floor: if an interval-5 account costs more than 3x an interval-15 account on the Fold (Settings > Battery screenshots over MTP), raise `kMinIntervalMinutes` to 10. Protocol: `docs/research/R76-1_BATTERY_AB_RESULTS.md` section R77-BAT-1.

**F278. Notifications that produced no scan, and alarm + WorkManager scans coexisting (~60-90m) Priority 34 -- backlog (Sprint 77 R76-1, was R77-BAT-2)**
- Phase: Core App Quality
- Platform: Android
- In arm 5, 2 of 4 posts left no scan and no log line (cause unknown); alarm and periodic starts also coexisted. Protocol and what would settle it: results doc section R77-BAT-2.

**F279. Listener gap 2 minutes vs 5 minutes (~30-45m) Priority 50 -- backlog (Sprint 77 R76-1, was arm 6 / R77-BAT-3)**
- Phase: Core App Quality
- Platform: Android
- Needs a change to `MailNotificationPolicy.MIN_GAP_MS`; likely redundant with the worker's 5-minute `kMinScanSpacing`. A/B in results doc section R77-BAT-3.

**F280. Doze network availability for alarm scans (~45-60m) Priority 36 -- backlog (Sprint 77 R76-1, was R77-BAT-4)**
- Phase: Core App Quality
- Platform: Android
- In arm 4, 2 of 3 alarm scans failed at DNS rather than login under forced Doze (cause unverified). Results doc section R77-BAT-4.

**F276. No Rule Review lists mail already deleted in the mail client (~60-90m) Priority 30 -- backlog (Sprint 77 5.1.2 F-PRECHECK; consequence of Q21 = 2)**
- Phase: Core App Quality
- Platform: All
- Since Sprint 77 No Rule Review lists every unprocessed row across scans (Harold Q21 = 2) and retention counts from the last sighting (Q22 = 1), so an email the user deleted in their mail app stays listed up to 90 days and actions on it fail. No status marks it gone: `UnmatchedEmailStore.updateAvailabilityStatus` has no caller in lib/ and `EmailAvailabilityChecker` is never constructed, so every row stays 'unknown'.
- Prevention-first fix: set the row's availability to deleted when an action on it fails with "not found" (one place, the shared action path) and filter it in the Review query; optionally run the existing availability checker for rows not seen in the latest scan.

**F265. Android Gmail native one-pick sign-in -- revisit only when a second device reproduces the failure Priority HOLD -- backlog (Sprint 77 plan Q24 = 2, Harold 2026-10-06)**
- Phase: Core App Quality
- Platform: Android
- F250 (#454, closed in Sprint 76): the native `authenticate()` fails with `[16] Account reauth failed` on the Fold, and the browser fallback then succeeds; since Sprint 76 Android renews through the stored refresh token, so users stay signed in. The cause is outside the changed code (OAuth clients, package and SHA-1 verified, `SPRINT_76_PLAN.md:783-795`). Harold chose to wait for a SECOND device that reproduces it before spending more time.
- Trigger to leave HOLD: a reproduction on another device (S24+ or a tester), with the diagnostic log's `gmail/renewal` and sign-in lines.

### Backlog from the R76-3 research (Sprint 77, 2026-10-07)

Source: `docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md` (Issue #468), placeholder ids R77-RS-1..10 renumbered F266-F275. Section 4.7 of that document lists the Class-1 questions (content storage, learned data, off-device lookups, bundling rules derived from Gmail data).

**F266. Unmatchable safe-sender patterns: validator check and seed fix (~45m) Priority 10** -- VERIFIED 2026-10-07 by the lead: 23 of 426 bundled safe-sender patterns carry a second literal `@` (e.g. `banking.jpmchase.com`, `accountprotection.microsoft.com`) and can never match, so those senders are NOT protected and a block rule can catch them. Surface at Sprint 77 Manual Validation as a scope question.
- Phase: Core App Quality
- Platform: All
- Value: safe senders the user believes are protected are not protected; 23 of 426 seed patterns can never match.
- Prevention first: extend `PatternCompiler.validatePattern` with an "unmatchable" check (a second `@` after the
  local part, and similar impossible shapes) so the quick-add screen, the import path and any future generator
  share one gate; then fix the 23 seed patterns and check Harold's live database (a DB data migration if they are
  there).
- Control and screen: existing Safe Senders management screen and Import / Export YAML (warning shown on import).
- Privacy precondition: none. Parity: shared Dart.
- Depends on: none.

**F267. Rule evaluation harness: score candidate rules against your own history, read only (~150m) Priority 20**
- Phase: Core App Quality
- Platform: All (Windows DEV for the dry run)
- Value: no proposed rule or score acts on mail until measured; the bar is zero safe-sender hits and precision of
  at least 0.99 (Section 4.8).
- Scope: a Dart CLI in `scripts/` that loads candidate YAML plus an exported database copy and reports precision,
  safe-sender false positives and recall; reuses `RuleEvaluator` and `PatternCompiler` unchanged.
- Control and screen: developer tool (no app UI); results feed F268 to F272.
- Privacy precondition: none (reads data already on Harold's PC). Parity: N/A (developer tool), engine code shared.
- Depends on: none.

**F268. PC-side rule miner: deleted-mail history to candidate delete rules (YAML) (~180m) Priority 22**
- Phase: Core App Quality
- Platform: N/A (developer tool on Harold's PC); output imported on All
- Value: closes the corpus gap (zero subject and body rules today) with known bad domains, subject regex and body
  regex mined from Harold's partial deleted-mail history, without the app storing any new content.
- Scope: script in `scripts/` reads Harold's exported deleted-mail history, mines recurring domains, subject
  phrases and body phrases, writes candidate YAML in `docs/RULE_FORMAT.md` shape, validated by F266 and scored by
  F267 before import.
- Control and screen: Settings > Import / Export YAML (merge via F269, or export-merge-import until F269 ships).
- Privacy precondition: content stays on Harold's PC; rules derived from his Gmail data must not be bundled into
  the shipped seed until the open legal question in Section 4.7 is settled (Class-1 if bundling is proposed).
- Depends on: F266, F267.

**F269. YAML import merge mode (add without replacing) (~90m) Priority 24**
- Phase: Core App Quality
- Platform: All
- Value: mined or shared rule files can be added without wiping the user's rules (import today replaces all).
- Scope: a "Merge" choice beside "Replace" on import; duplicates resolved by the existing
  `manual_rule_duplicate_checker` / `rule_conflict_detector` services; every new pattern passes F266.
- Control and screen: Settings > Import / Export YAML, import confirmation dialog.
- Decision class: Class-2 (changes import semantics; replace stays the default).
- Privacy precondition: none. Parity: shared Dart.
- Depends on: F266.

**F270. Safe-sender discovery: propose safe senders from history for review (~150m) Priority 30**
- Phase: Core App Quality
- Platform: All
- Value: fewer false positives; senders the user trusts are protected before a broad rule catches them.
- Scope: v1 uses stored data only -- repeated No Rule senders that pass DMARC and were never deleted; v2 adds
  Sent-folder recipients (reply pairs). Candidates are listed for accept or reject; nothing is added silently.
  Device contacts are excluded (new permission, platform exception).
- Control and screen: a "Suggested safe senders" list on the Safe Senders management screen.
- Privacy precondition: v1 none; v2 adds the Sent folder to "What the app accesses" in the privacy policy.
- Parity: shared Dart. Depends on: F266, F267.

**F271. Heuristic reasons and rule suggestions on No Rule Review (~210m) Priority 32**
- Phase: Core App Quality
- Platform: All
- Value: the user sees why an email looks like spam (Reply-To differs from From, auth failed, lookalike domain,
  bad TLD, bulk mail without unsubscribe) and gets a one-tap candidate rule.
- Scope: header-only signals computed at scan time from headers already fetched (no body fetch); shown as reason
  chips; "Create rule" opens the existing quick-add screen prefilled. Signals never act on mail by themselves.
  Two-header comparisons are computed in Dart, not added to the YAML grammar (a grammar change would be Class-2).
- Control and screen: No Rule Review screen, per-email reason chips and a "Create rule" action.
- Privacy precondition: none if signals are computed and shown, not stored; storing them is R76-4.
- Parity: shared Dart. Depends on: F267.

**F273. Privacy policy and Data safety revision for the content history and learning (~60m) Priority 40**
- Phase: Core App Quality
- Platform: All (one policy; Play and Microsoft Store)
- Value: keeps the published policy true before any build stores more content or learns from it.
- Scope: the rewrites listed in Section 4.7 "Exactly what would change"; cite the Workspace policy; re-run
  `data_safety_declarations_test.dart`; Play Data safety stays "No" while nothing leaves the device.
- Control and screen: N/A (documents and the website).
- Depends on: Harold's Class-1 decision on R76-4 (and on F272 if it is selected); it is written before
  either ships.

**F272. Per-user on-device spam classifier (pure Dart) ranking No Rule Review (~300m) Priority 42**
- Phase: Core App Quality
- Platform: All
- Value: learns each user's own spam from their own decisions and sorts likely spam to the top of review.
- Scope: hashed-token naive Bayes over From domain, subject and header tokens (body optional and off by default);
  trained incrementally on the device from the user's own actions; about 2 MiB of state; no new dependency
  (probe: about 161 microseconds per 1.2 kB text on the development laptop; Fold timing to measure first). The
  score ranks and suggests; it does not delete until it passes the F267 bar and Harold approves acting.
- Control and screen: Settings > General switch "Learn from my decisions" (off by default) and the No Rule Review
  sort order.
- Policy: inside the Workspace policy's "specific user's personalized model" carve-out; never trained on one
  user's data for another user.
- Privacy precondition: F273 published before a shipped build carries it. Parity: shared Dart.
- Depends on: R76-4 (labels), F267, F273. Decision class: Class-1 (new derived data store).
**HOLD (no viable runtime or contradicts the privacy posture):**

**F274. On-device GenAI rule explanations (~240m) Priority HOLD**
- Phase: Core App Quality
- Platform: All (would be two platform exceptions today)
- Why HOLD: Android ML Kit GenAI is foreground-only, Beta and absent from the Galaxy S24 family; Windows Phi
  Silica needs a Copilot+ NPU or a Developer Mode GPU path and is removed in January 2027; a bundled LLM costs a
  100+ MB download (size UNVERIFIED) under the Gemma pass-through terms.
- Revisit trigger: a GenAI API available to Store users on both platforms that runs in background work, or the
  Windows successor model (Aion Instruct) reaching retail with a non-Developer-Mode path.

**F275. Cloud GenAI classification (~360m) Priority HOLD**
- Phase: Core App Quality
- Platform: All
- Why HOLD: sends personal mail content to a third party; contradicts four sentences of the privacy policy; flips
  Play Data safety to "Emails collected and shared"; Gmail data transfer limits; no server for key management.
  About $0.0002-$0.0006 per email (Section 4.4).
- Revisit trigger: Harold decides the product posture changes (Class-1), with an explicit per-user opt-in design.

### Backlog from the Sprint 74-75 retrospectives and Manual Validation

**F240. Body-rule sub-type consistency Priority 40 -- backlog (Sprint 74 retro Category 14a)**
- Quick-add and the default rule-set split store body rules as `entire_domain`; manual and imported body rules use `keyword`. Same shape as the subject-rule label fix (DB v10). Decide per body pattern kind (URL/domain vs phrase), then align the creators and reclassify stored rows.

**F242. Span-replacing edit scripts assert what the span contains Priority 50 -- backlog (Sprint 74 retro IMP-5, Harold 2026-10-02: "add to backlog")**
- A script that replaces the text between two anchors must assert the span's content (for example exactly one `testWidgets(`) and compare the test count before and after. Sprint 74: an end anchor matched one test too far and deleted a neighboring widget test; only an unused-import warning revealed it. Prevention: extend CLAUDE.md IMP-3 ("every mutation script asserts its anchor matched"); consider a span-replace mode in `scripts/mutation-test.ps1` or a shared edit helper.

**F244. Tell the user when a Gmail background scan skips for sign-in Priority 45 -- backlog (Sprint 75 5.1.1 review SF-8; Harold at Manual Validation 2026-10-03: "backlog")**
- F239 records a skip -- no notification, no export -- when Gmail needs the user, and relies on the per-account `gmail_sign_in_required` flag to show "Sign In Again" in the account list. That write is best effort: if it fails (a locked database), background scans of the account skip every cycle and nothing tells the user. Fix: a one-time notification for a needs-sign-in skip, independent of the flag, or a retry of the flag write.

**F245. Background scans must not re-add No Rule rows for emails already listed Priority 35 -- backlog (Sprint 75 Manual Validation, Harold 2026-10-03: "q2 1")**
- Each read-only background scan of an all-mail range adds its own `unmatched_emails` rows, so the same emails are listed again every run: about 115 rows per AOL run, 2,266 rows in one evening (5,035 -> 7,301). Older behavior, but F243 (Windows background scans run while the app is open) makes it happen every 15 minutes, roughly 11,000 rows a day until the 90-day retention removes them. Decide the identity of a No Rule entry (account + message id / folder + uid) and skip or refresh an existing entry instead of inserting a duplicate; check the No Rule Review counts and the Scan History "No Rule" totals against it.
- **Export side (folded in by Harold, Sprint 76 Manual Validation 2026-10-06: "for 3 you can fold into F245")**: the per-account scan export (`scan_exports/*.data.csv`) lists an unaddressed No Rule email again on EVERY scan -- the 0.17.4 Fold export listed the same email (UID 232848) 10 times between 06:52 and 08:21. Use the same identity: an email already listed as No Rule is not exported again until it is addressed or changes. Keep the "<no records to process>" row for an empty scan (Harold: keep it).

**F246. Android Gmail background renewal through a server-side token exchange Priority 30 -- backlog (Sprint 75 F239 R-1 spike FAILED; Harold 2026-10-03: "1.3")**
- From a WorkManager worker, `clientAuthorizationTokensForScopes(email, promptIfUnauthorized: false)` returned NULL for an already-granted Gmail account (emulator, google_sign_in 7.2.0 / android 7.2.7; ADR-0011 known limit). Android stores no refresh token, so a Gmail background scan more than about an hour after the app was last opened skips with "Gmail needs you to sign in again". Google's documented route: request a server auth code at sign-in and exchange it on a server for a refresh token. Needs a backend this app does not have (hosting, secret handling, privacy-policy update, ADR); a Class-1 architecture decision. Before committing to it, a 30-minute scope-matched retry of the spike would rule out a requested-vs-granted scope mismatch. The switched-off `GoogleAuthService.authorizeWithoutActivity` is the code to remove or reuse.

**F254. Home-screen widget: last scan and new No Rule count Priority 45 -- backlog (Harold 2026-10-05, Q3 = 1)**
- A widget showing the last background scan time and the No Rule emails waiting. Two reasons: users see that unattended scanning runs without opening the app, and Android exempts apps with an active widget from the Restricted standby bucket (developer.android.com/topic/performance/appstandby: exemptions include "Apps with active widgets"), the bucket that limits jobs to once a day after 8 days without interaction. Android first (a declared ADR-0042 exception unless a Windows equivalent is wanted). Context: Sprint 76 unattended-scanning analysis, F252 (#457), F253 (#458).

**F247. Behavior tests for navigation and platform-gated paths (~120-180m) Priority 25 -- backlog (PR #448 review carry-in, 2026-10-04; targeted for Sprint 76 but NOT delivered -- that sprint was redirected to unattended Android scanning)**
- From the PR #448 Claude reviews (test analyzer items 5 and 7, code reviewer MINOR 5, plus test MINORs). Each needs a new navigation harness or a production test seam, so one planned card is more effective than piecemeal fixes at merge time.
  1. `scan_progress_screen.dart` `startRealScan` F238 branches as BEHAVIOR, not source gates: OK returns; `requested == false` proceeds; `!closed` shows "did not stop" and returns; plus the end-to-end success case (holder row present, stop chosen, row closed, manual scan claims). Harness: `s75_t7_scan_busy_snackbar_test.dart` already drives the real `startRealScan`.
  2. Gmail add flow as a widget test: push `AccountSetupScreen`, complete a stubbed `GmailOAuthScreen` with an address, assert the route on top -- and settle where Back lands (code review says the provider picker; Harold's MV round 4 saw the account list). Decide the WebView and manual-token fallback screens, which still open the folder step.
  3. Run the Windows token-path tests (`gmail_adapter_sign_in_flag_test.dart`, 5 cases) on CI: an injectable platform check in `GmailApiAdapter` (Class-2: a production seam -- surface at planning).
  4. Android `initialize` EXCEPTION path (review M-2: network -> ConnectionException, other -> AuthenticationException, never flagged) needs a seam in `GoogleAuthService`; no host test reaches it today.
  5. Sign In Again: the button disappears after success; the `_running` double-tap guard; `showLiveRefusal`'s `isViewingHistory` negative case.
  6. A self-test for `scripts/mutation-test.ps1` BASELINE and INVALID verdicts (a false INVALID would hide a SURVIVED mutant).

**F241. Remove or wire `ScanResultStore.getActiveBackgroundScan` Priority 60 -- backlog (Sprint 74 retro Category 14b)**
- No production caller since the manual-scan dialog moved to the per-account `getActiveScanForAccount`; kept with its tests. Delete with its tests, or wire it. F238 shipped without it (Sprint 75).

### Superseded: Sprint 76 phone validation carry-ins (Phase 8.2 pass 1, 2026-10-06)

MV74-1 (F235 Doze, #428) and MV74-3 (F205 errors, #433) are folded into **MV76-1** above. The Doze half of MV74-1 PASSED on the 0.17.4 overnight run (95 worker starts, 111/113 completed); the reboot half and the MV74-3 classification remain, on 0.17.6, inside MV76-1. Both issues stay open until MV76-1 runs. The F205 card under Core App Quality remains the place for any fix the classification calls for.

### Core App Quality

**F237. Quiet the non-fatal Kotlin "Daemon compilation failed" traces in the Android build (~20-40m) Priority 38 (NEW, 2026-09-24 -- Sprint 73 build misdiagnosis)**
- Phase: Core App Quality
- Platform: Android
- Every Android build prints dozens of `e: Daemon compilation failed: null` / "Could not close
  incremental caches" traces. They are NOT failures: plugin sources in the pub cache on `C:` cannot
  be made relative to the project on `D:` (`this and base files have different roots`), and Kotlin
  falls back and builds. Reading them as fatal cost Sprint 73 an evening and five self-interrupted
  builds. Full diagnosis: TROUBLESHOOTING.md.
- Options: `kotlin.incremental=false` in `mobile-app/android/gradle.properties`, or move the pub
  cache to `D:` via `PUB_CACHE`. Measure the build-time cost of the first before choosing it.
- Value is preventive only: a working build does not need it.

**F213. Migrate Android Gmail OAuth off Custom URI schemes to Google Identity Services (~180-300m) Priority 40 (NEW, 2026-09-11 -- found while fixing F211)**
- Phase: Android / Google Play Store Readiness
- Platform: Android only (Windows uses a loopback redirect and is unaffected)
- **Not urgent. Filed so it is not rediscovered under pressure**, which is exactly how F211
  arrived -- as a tester-blocking surprise.
- Google now disables Custom URI schemes BY DEFAULT on newly-created Android OAuth clients,
  because the scheme can be claimed by another app on the device (app impersonation). F211's
  fix re-enables the setting on the existing client, which works today and required no code
  change.
- **But Google describes this as the legacy path.** Verbatim from their developer blog: *"In
  the future, we may disallow Custom URI scheme methods."* The recommended replacement is the
  **Google Identity Services for Android SDK**, which delivers the OAuth 2.0 response directly
  to the app instead of via a registered URI scheme.
- **No cutoff date has been published.** That is the reason to file rather than schedule: there
  is nothing to race, but if Google does set a date, the migration becomes urgent on their
  timetable rather than ours, and it touches the sign-in path every tester uses first.
- **What it would touch**: `flutter_appauth` is built on the custom-scheme mechanism, so this
  is a dependency swap, not a settings change -- `AndroidManifest.xml`'s
  `${appAuthRedirectScheme}` intent filter, `build.gradle.kts:96`'s placeholder derivation, and
  `google_auth_service.dart`. A new Play submission would be required.
- **Do NOT start this speculatively.** Re-check Google's stated position before scheduling; the
  recommendation may change again, and the current setup is working.
- Depends on: nothing. Blocks nothing.
- Source: found 2026-09-11 while verifying Google's current wording for F211 R-2. Sources:
  developers.googleblog.com "Improving user safety in OAuth flows through new OAuth Custom URI
  scheme restrictions"; developers.google.com/identity/protocols/oauth2/native-app.

**F205. Closed-test error rate: 53 errors in 3,833 scanned on the S24+ -- find out what they ARE (~30-60m) Priority 18 (NEW, 2026-09-10 -- observed on the closed-test device)**
- Phase: Core App Quality
- Platform: Android (closed test); check Windows for the same class
- **NARROWED 2026-09-10 by Harold's per-account sweep, and this is the useful half**: he
  filtered Scan History by account and scan type. **kimmeyharold@aol.com: NO rows with Errors > 0**,
  background or manual. **kimmeyh@gmail.com background: 21 errors, ALL on a PRIOR VERSION.**
  Gmail manual: also all prior-version.
  So the errors are **Gmail-only and pre-0.15.0** -- not spread across accounts, and not
  occurring on the current build. That is a substantially smaller and colder problem than the
  raw total suggested, and it may already be fixed. **Confirm no NEW errors accrue on 0.15.0
  before spending time on the historical ones.**
- **Observation, from the S24+ Scan History 90-day totals on 2026-09-10**: Total 3,833,
  Processed 892, Deleted 374, Moved 0, Safe 43, No Rule 475, **Errors 53**. That is ~1.4% of
  scanned mail, and it is the only number on that screen that is not self-explanatory.
- **The per-scan rows all read `Errors: 0`.** The three visible background runs (AOL 6:34 PM
  Deleted 19, Gmail 6:34 PM, AOL 4:06 PM Deleted 6) each report zero. So the 53 are concentrated
  in runs not visible without scrolling, which makes them a cluster rather than background noise
  -- worth finding, because a cluster usually has ONE cause.
- **What was ruled out rather than assumed** (2026-09-10): the obvious hypothesis was F202's
  missing-folder finding -- a folder that does not exist routes through `recordFolderFetchError`
  into `errorCount`, so a wrong Gmail folder name would produce exactly this shape. **Checked and
  it does not hold**: `junk_folder_config.dart:70` correctly uses the bracketed `[Gmail]/Spam`
  form, and the Windows dev log has **zero** `EXCEPTION fetching folder` entries. The Scan
  History screen displays `Gmail/Spam` without brackets, but that is a DISPLAY string, not the
  IMAP name.
- **UNBLOCKED 2026-09-10 -- data IS retrievable after all, and I was wrong to say otherwise.**
  Harold changed the CSV export folder to Documents and ran a MANUAL scan; the file written and
  pulled over MTP:
  `/storage/emulated/0/Documents/scan_results_2026-09-10T20-32-31.csv`. So **manual-scan export
  works on Android**; it is the BACKGROUND path (`background_scan_windows_worker.dart`) that does
  not. My earlier "nothing landed" was checked BEFORE he changed the folder and re-scanned -- a
  moment-in-time observation reported as a conclusion.
  The CSV carries exactly what a diagnosis needs: `Scan Date, Received Date, From, Folder,
  Subject, Rule, Match Condition, Action, Status, Email ID` -- including the **matched rule and
  its regex**, which is more than the Windows CSV header shows.
  **So F205 is only PARTLY blocked**: manual scans can be exported today. If a Gmail manual scan
  reproduces an error row, the cause is diagnosable now rather than after F206.
- **CORRECTION (2026-09-10, same day)**: this card originally said to "get the device log off
  the S24+ ... `background_scan_v0.15.0.log`". **That file does not exist on Android.**
  `main.dart:152` gates the whole file-logging block on
  `BackgroundModeService.isBackgroundMode`, which is the WINDOWS Task Scheduler path; Android
  background scans run through WorkManager and never reach it. The path is even built with a
  hardcoded `\\` separator. I assumed a file rather than checking -- the same shape as retro
  IMP-1, one level up: assuming an ARTIFACT exists rather than assuming what one means.
- **So there is currently NO way to diagnose this.** The counters are visible on-device and the
  underlying detail is not retrievable at all. That is what F206 is for, and F205 is BLOCKED on
  it: without per-error detail, any diagnosis from the totals alone is guesswork.
- **Method when picked up (after F206 ships)**: export the scan history, group the error entries
  by cause, then fix. Do NOT start from a hypothesis; read the data first.
- **Why this matters more here than elsewhere**: the closed test is the ONLY build that acts on
  real mail (see `GOOGLE_PLAY_ACCOUNT_SETUP.md` "Scan mode by environment"). An error rate that
  is benign in read-only could be a failed delete or a half-applied action here. It is also the
  build 8 testers are about to be watching.
- **Not urgent, and not a launch blocker**: scans complete, the green check appears, and 3,780 of
  3,833 messages were handled without error. But an unexplained 1.4% on the build that touches
  real mail is worth an hour before the tester count reaches 12.
- Depends on: access to the device log. No code change is implied until the cause is known.
- Source: observed by Claude in Harold's 2026-09-10 S24+ screenshots.

**F204. Gate the three Play requirements that are documented but not asserted (~60-90m) Priority 24 (NEW, 2026-09-10 -- Harold, from the pre-review-checks research)**
- Phase: Android / Google Play Store Readiness
- Platform: Android
- **Origin**: Harold asked whether Play's "quick checks" could be replicated locally so a
  submission would "nearly guarantee" a clean pass. The honest answer split in two, and the
  split is the card:
  - **The checks themselves CANNOT be replicated.** Google publishes a page for the feature
    ([pre-review checks](https://support.google.com/googleplay/android-developer/answer/14807773))
    and explicitly declines to enumerate them: its own FAQ "What pre-review checks does Play
    Console run?" answers with **two examples and no list**. One of the two is **aggregate crash
    rates by device/Android version** -- telemetry that lives on Google's side and cannot be
    checked locally by anyone. Google also states plainly that passing pre-review checks does
    NOT guarantee passing review.
  - **The documented REQUIREMENTS can be, and three are not.** That is this card.
- **DO NOT build a gate that claims to predict pre-review checks.** It would assert something
  Google has never published, and would give false confidence -- the same shape as the Sprint 66
  provider gate that passed mutation while catching nothing.

- **Gap 1: `targetSdk` is INHERITED, never asserted (~30m).** `android/app/build.gradle.kts:38`
  reads `targetSdk = flutter.targetSdkVersion`, so the value comes from the pinned Flutter SDK
  rather than from this repo. It is CORRECT today -- the 0.15.0 AAB declares
  `targetSdkVersion 36`, verified 2026-09-10 by reading the built bundle's manifest -- but
  nothing would catch a regression. Google's deadline is LIVE: from **2026-08-31**, new apps and
  updates must target API 36 ([doc](https://support.google.com/googleplay/android-developer/answer/11926878)),
  extension available to 2026-11-01. A Flutter downgrade would silently drop below it and the
  first symptom would be a rejected upload.
  **Check**: assert the built AAB's manifest declares `targetSdkVersion >= 36`, or assert the
  resolved gradle value. Prefer reading the ARTIFACT over the config -- the config is a pointer.

- **Gap 2: no NEGATIVE gate on `AD_ID` (~20m).** Targeting Android 13+ requires declaring
  `com.google.android.gms.permission.AD_ID` if the ad ID is used
  ([doc](https://support.google.com/googleplay/android-developer/answer/6048248)). Verified
  ABSENT from the 0.15.0 AAB on 2026-09-10, and this app has no ads and no analytics (Firebase
  Analytics removed under GP-12/ADR-0030).
  **Why gate an absence**: this repo has ALREADY been bitten by transitive manifest injection --
  GP-3 had to strip NFC and biometric permissions an SDK pulled in via manifest merge. An
  analytics or ads dependency arriving transitively would inject `AD_ID` and silently turn the
  "no ads / no analytics" Data safety declaration into a FALSE one. That is a policy problem,
  not a build problem, and `data_safety_declarations_test` cannot see it because it reads
  documents, not the merged manifest.
  **Check**: assert `AD_ID` never appears in the built AAB's merged manifest.

- **Gap 3: 16 KB page-size alignment (~1-2h).** Flutter ships native `.so` libraries, so this
  applies -- a pure Java/Kotlin app would be exempt.
  **CORRECTION worth recording, because the wrong date is everywhere**: multiple community
  sources say enforcement began 2025-11-01. Google's own page says **2027-02-01**:
  "Starting February 1, 2027, if your app updates don't support 16 KB memory page sizes, you
  won't be able to release these updates" ([doc](https://developer.android.com/guide/practices/page-sizes)).
  Not urgent; do it before that date, not this sprint.
  **Check**: `apkanalyzer` or Android Studio's alignment detection over the bundle's `.so` files.

- **What is NOT applicable, verified rather than assumed** (2026-09-10, by enumerating the built
  AAB's manifest): no sensitive permissions -- no `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`,
  SMS/Call Log, or `SCHEDULE_EXACT_ALARM` -- so no Permissions Declaration Form. No ads, no IAP,
  no location, no camera, no analytics. Bundle is 53 MB against a 500 MB limit. The shipped set
  is 11 permissions, all mundane (INTERNET, WAKE_LOCK, POST_NOTIFICATIONS,
  FOREGROUND_SERVICE_SHORT_SERVICE, etc.).
- **Already covered, do NOT rebuild**: this repo has **56 tests across 13 Play-relevant policy
  gates**. Notably `app_content_declarations_test` (7 tests) covers App content declarations --
  which is the ONE check family Google explicitly names as mandatory. Of the two checks Google
  actually identifies, the coverable one is already covered.
- **Community evidence, labelled**: aggregator blogs converge on "Data safety form drift" as a
  common rejection cause -- the form describing an older SDK set than the shipped binary. MEDIUM
  confidence (multiple independent sources, and it matches Google's documented emphasis), and
  already gated here by `data_safety_declarations_test`. Deliberately NOT reproducing those
  sources' longer rejection lists: they are mutually copied and several repeat the 16 KB date
  error corrected above.
- Depends on: nothing. All three checks read the built AAB, which the release process already
  produces.
- Source: Harold, 2026-09-10 -- *"target is not perfection, but as good as reasonably possible."*

**F192. Custom IMAP Server support -- build the host-entry UI (~120-180m) Priority 32 (planned for Sprint 69 at the Sprint 68 scope selection, then NOT SELECTED -- `SPRINT_69_PLAN.md`; still unbuilt as of 2026-10-04: no `lib/ui` file collects `imapHost`; split from F191)**
- Phase: Core App Quality
- Platform: All
- **Deliberately SEPARATE from F191, because it is not the same kind of work.** Yahoo and iCloud need a gate opened; Custom IMAP needs a feature built. `GenericIMAPAdapter.custom()` defaults `imapHost: ''` -- it expects the host, port and TLS flag to be supplied by a caller, and no caller supplies them: `grep -rn "imapHost" lib/ui/` returns ZERO matches. There is no screen anywhere that collects a server address, so flipping `imap` to phase 1 would ship a provider that cannot connect to anything.
- Scope: a server-details form (host, port defaulting to 993, TLS toggle, username, password), validation and a "Test Connection" affordance mirroring the existing `AccountSetupScreen` connection test, plus persistence of the per-account server settings so a saved custom account reconnects without re-entry.
- Cross-platform parity (ADR-0042): the form is shared Flutter UI and must behave identically on Windows and Android; no platform exception is anticipated, and if one is needed it must be declared.
- Value: this is the item that turns "Gmail and AOL" into "and any IMAP provider" -- the single largest addressable-market claim in the listing copy, and the one most often asked about for self-hosted and workplace mail.
- Depends on: nothing. Independent of F191, though shipping both together would let the Play listing be rewritten once instead of twice.
- Source: Sprint 66 GP-19 listing submission, 2026-09-08.

**F165. Cross-device rules-DB sharing -- user cloud storage (iCloud/OneDrive/Box/Google Drive) exploration + hosted-tier option (~half-day exploration) Priority HOLD (MOVED TO HOLD by Harold, 2026-09-09, Sprint 68 scope selection)**
- Phase: Product direction / architecture exploration
- Platform: All
- Direction (Harold, 2026-08-16): long-term, the recommended deployment is a PHONE (Android/iPhone) doing the periodic background scans instead of the Windows app -- which makes the rules DB per-device divergence a real problem. Explore letting the user share their rules DB between devices via THEIR OWN cloud storage (iCloud / OneDrive / Box / Google Drive), e.g. exported-snapshot sync or file-provider integration. Additionally evaluate a hosted-sync option as a paid tier (~$4/year, non-free app option) -- pricing/product decision stays with Harold.
- Exploration deliverables: sync-model options (file-based snapshot vs true sync; conflict handling for rule edits on two devices), per-provider integration effort, security posture (rules contain sender addresses -- privacy note), and a recommendation. Builds on the existing YAML export invariants as the likely interchange format.
- Source: Harold, Sprint 60 Manual Validation, 2026-08-16.

**F173. Periodic "Test Coverage and Appropriate Testing" Deep Dive (~4-8h per review) Priority HOLD (NEW, Sprint 61 -- Harold; recurring HOLD template)**
- Phase: Testing / periodic review
- Platform: All -- backend, frontend/UI, data layer, Windows app, Android app
- Scope (Harold, 2026-08-17): a recurring deep dive answering TWO distinct questions, not one: (1) **coverage** -- what is tested and what is not, across backend, frontend/UI, data layer, and both apps; (2) **appropriateness** -- *does each test clearly test what it intends to test, AND does each SET of tests do what the set intends to do?* The second question is the one ordinary coverage metrics cannot answer.
- Why this matters here specifically: Sprint 60 produced three concrete instances of tests that passed while proving nothing -- a popup-fit test that stayed green against the broken code until it was tightened, a chip-tooltip test that passed off unrelated AppBar tooltips after the widget it guarded was deleted, and a long-press test that would have passed with the gesture wiring removed. All three were caught only because mutation-verification was run by hand. A periodic sweep institutionalizes that check.
- Method: mutation-verify a sample of existing gates (break what each guards, confirm red); look for assertions that prove EXISTENCE where the claim is about behavior, ordering, or sizing; check that test names still describe what the test does; check per-layer coverage gaps; report findings as backlog items.
- Cadence: same periodic-HOLD model as F70 (Security) and F71 (Architecture) -- triggered by Harold, not calendar-automatic.
- Source: Harold, 2026-08-17.

**F183. Upstream civyk-winwright request: script-runner replay support for ww_wait (~15m to file, then external) Priority HOLD (NEW, Sprint 62 retro IMP-7 -- external dependency)**
- Phase: Testing / E2E tooling (external)
- Platform: Windows Desktop (WinWright harness)
- Scope: the WinWright script runner does not replay `ww_wait` steps -- re-confirmed live 2026-08-23 (the runner SKIPS the step: "Replay of 'ww_wait' is not supported by the script runner"). This forces the settle-buffer workaround in the sweep scripts (harmless resolving clicks to outlast Flutter popup animations) and is the root reason the f37/f56 dialog-settle scripts stay EXCLUDED from the default sweep. File the feature request with civyk-winwright (ww_wait mode=element_state would suffice); when it lands, remove the settle buffers and re-evaluate readmitting the excluded scripts.
- HOLD rationale: external project owns the fix; our action is filing + tracking.
- Source: Sprint 62 sweep repair + retrospective IMP-7, 2026-08-23.

**F179. Subject-blocking phrase picker -- user selects (or GenAI recommends) the blocking SUBSET of a subject (~3-5h) Priority HOLD (NEW, Sprint 62 MV -- Harold; gated on the GenAI track)**
- Phase: Core App Quality / rules UX
- Platform: All (shared review popup)
- Scope (Harold, 2026-08-22, verbatim intent): "The scan results of a single email needs to have a 'from' dialog as it is not normal to mark an entire subject as a blocking phrase, but often a subset phrase and will need to have the user pick the subset -- likely this will wait until after the genai integration as an app 'recommended' subject phrase or matching string would be far better than have the user guess."
- Today's Block Subject action uses the whole (20-char-previewed) subject; a subset-phrase picker dialog is the right shape, and an H1-style GenAI-recommended phrase beats manual guessing.
- HOLD rationale: deliberately sequenced AFTER the GenAI integration (H1) so the recommendation flow ships with it rather than building a manual picker twice.
- Source: Harold, Sprint 62 Manual Validation, 2026-08-22.

**F152. Periodic User-Centric First-Run Evaluation (~2-3h per review, plus fix-item time if findings warrant) Priority HOLD** _(TEMPLATE -- first run produced F151 above, Sprint 58 Backlog Refinement, 2026-08-15)_
- Phase: UX Spike (reusable template)
- Platform: Windows Desktop (this run); extend per-platform when other platforms are release-ready
- **Generic scope**: re-run Harold's user-centric MVP test script + "First-Run Evaluation Summary Page" checklist (7 sections: Installation & Launch, First-Run Orientation, Completing the Primary Task, Feedback & Confirmation, Emotional Experience, Environment Compatibility, Quick User Feedback Capture) against the CURRENT app build, via a genuine live walkthrough (not just static code analysis) -- build the target platform's release-equivalent binary, reach a truly empty first-run state, and walk the checklist with a real user (Harold) driving and Claude observing/recording via the platform's UI-automation tooling (WinWright on Windows) where available.
- **Method** (validated this run): (1) static/code-analysis pass first via an Explore agent to establish a baseline hypothesis cheaply; (2) confirm/refute live via an actual build+launch with a genuinely empty account/data state (see F151's Investigation Note for this repo's specific data-persistence gotchas); (3) Harold drives interactively while Claude screenshots/narrates each step against the checklist's 7 sections; (4) consolidate into backlog candidate items; (5) always fully back up and restore any real account/rule/scan data touched to reach the empty state -- verify byte-for-byte before declaring restoration complete.
- **Deliverable**: a gap analysis against the 7-section checklist + concrete backlog candidate item(s) for anything found, sized and scoped like F151.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a first-run/onboarding review is warranted -- e.g. after a significant first-run-path UI change, before a major release, or periodically (suggested cadence: every 10-15 sprints, or whenever F75's walkthrough/onboarding gap is finally addressed and needs re-validation).
- Source: Harold, 2026-08-15 -- "at the end this first-use analysis will be added as a permanent backlog ON HOLD item that we can re-use."

_(Sprint 61 shipped and pruned at the 2026-08-21 Phase 8.2 pass-1 sweep: F161, F162, F167, F168 (its R-3 settings-interplay question is now DECIDED -- Harold, 2026-08-22: the fully-independent Manual/Background tabs are "correct and the desired behavior"; a deliberate Product Owner design decision, do NOT re-raise), F169, F170, F171, F172 -- history in `docs/sprints/SPRINT_61_PLAN.md` / `SPRINT_61_SUMMARY.md` and CHANGELOG.md. F143, F144, F156, F157, F158, F159, F160, and F166 shipped Sprint 60 (stubs also cleared this sweep) -- see `SPRINT_60_PLAN.md` / `SPRINT_60_SUMMARY.md`.)_

_(F149 shipped Sprint 57 -- see `docs/sprints/SPRINT_57_PLAN.md` and CHANGELOG.md 2026-08-14. Root-caused as an always-existing gap in F91's (Sprint 39) design, not a regression: F91 only reconciled the SOURCE folder after a safe-sender move; F149 added a symmetric pre-move check against the TARGET folder using the existing `searchByMessageId` capability. F148 shipped Sprint 56 -- see `docs/sprints/SPRINT_56_PLAN.md` and CHANGELOG.md 2026-08-13. F145/F146/F147 all shipped Sprint 55 -- see `docs/sprints/SPRINT_55_PLAN.md`, CHANGELOG.md 2026-08-10, and `docs/WINWRIGHT_SELECTORS.md`'s new F145 entry (WinWright false-failure finding + the real HelpScreen scroll-timing bug it led to). F145 also produced `integration_test/help_deep_link_test.dart`, the durable regression suite for all 22 HelpSection values.)_

### Android / Google Play Store Readiness (track ACTIVATED 2026-08-24 -- Harold took all Android + GP-n items off HOLD)

Recorded sequencing honored (see 'Recommended Sequencing' in the GP section below): account first, privacy early, technical features as sprint work, Data Safety after privacy, listing before submission, CASA trigger-gated last. Supersessions recorded this refinement: F4 (Android background scanning) was DELIVERED as F161 in Sprint 61; Issue #163 (Android untested) is RESOLVED by the continuous Sprint 59-62 on-device validation.

**F189. Periodic Skills Audit -- what tooling would make sprints, development, recovery and prevention measurably better (~4-8h per review, research-led) Priority HOLD** _(TEMPLATE -- first run assigned to Sprint 66; keep this item for reuse)_
- Phase: Process / tooling (repo instruction surface)
- Platform: N/A (repository tooling, harness configuration, agent definitions)
- **Scope (Harold, 2026-09-07, verbatim intent)**: analyze the codebase, recent conversation history, memories, hooks, docs, agents and `CLAUDE.md`, looking for SKILLS that would help us: (1) run sprints more effectively and efficiently; (2) develop features that are aligned with the defined architecture and tested effectively; (3) recover from mistakes; and (4) prevent the same AND SIMILAR mistakes from happening again. **Research latitude granted**: it is explicitly OK to research what this item is trying to achieve and to propose improvements to the item itself.
- **Why now**: the project already has 10 skills, 5 hooks and ~60 memory entries, all added reactively -- each one traceable to a specific escape. Nobody has ever asked the inverse question: given everything we now know went wrong, what is the RIGHT set? Sprint 65 alone produced two commit races, a false Play declaration in committed history, a gate that asserted a document's own claim of diligence, a gate defeated by a substring, and a fixed-duration wait on the wrong side of its margin. Those are five instances in one sprint, and every one was caught by adversarial probing rather than by a skill.
- **The (4) clause is the hard part and the most valuable.** "The same mistake" is what hooks already do well -- a specific string, a specific command, a specific file. "**Similar** mistakes" is a generalisation problem: the substring-shadow defect and the "verified by grep" defect are the SAME defect (a check that cannot fail) wearing different clothes, and no existing hook would have caught the second from having seen the first. The audit should ask what mechanism generalises, not just what rule to add next.
- **Method**: (a) inventory what exists -- skills, hooks, memories, agent definitions, CLAUDE.md rules -- and classify each by which of the four goals it serves; (b) mine the retrospectives and Process Issues categories for the actual failure taxonomy, since that is the ground truth of what goes wrong here; (c) identify the gaps, especially failure classes that recur under different surface forms; (d) propose specific skills with the cost of each, and be willing to conclude that some existing tooling should be REMOVED or merged -- more instruction surface is not automatically better, and F130 exists precisely because contradictory instructions cause their own defects.
- **Deliverable**: a written audit with concrete proposals presented for approval, in the same shape as retrospective improvement proposals (title, source, type, effort, recommendation), NOT auto-applied.
- **Guard against the obvious failure mode**: this item could easily produce a long list of plausible-sounding skills nobody uses. Each proposal must name the specific past escape it would have caught, or state honestly that it is preventive with no precedent.
- **Each proposal is evaluated like an ADR, not pitched** (Harold, 2026-09-07). Per proposed skill, state: **what it does**; **pros**; **cons**; **why we would do it** (the specific escape it would have caught, or an honest "preventive, no precedent"); and **what else it needs to work**. That last field matters -- a skill is often inert on its own, and may require a companion hook, a memory entry, a doc change, or an agent definition. Those companions are PART OF THE PROPOSAL and must be costed with it, not discovered later.
- **Not all proposals will be accepted, and that is the intended outcome.** The deliverable is a slate to evaluate, not a plan to execute. Rejecting a well-argued proposal is a valid result; the evaluation is the value.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable. Duplicate when the instruction surface has accumulated enough change to warrant re-asking the question -- suggested triggers: after a sprint that produced several process escapes, after a run of retrospectives whose Process Issues category repeats a theme, or when new tooling capabilities become available.
- Depends on: nothing. Reads the repository and its history; changes nothing without approval.
- Source: Harold, 2026-09-07. Made a periodic template at his direction, alongside F70 (Security), F71 (Architecture), F130 (Process-Docs), F152 (First-Run) and F173 (Test Coverage).

**GP-4. Gmail API OAuth Verification / CASA -- THE SUBMISSION ITSELF (~40-80h) Priority HOLD (MOVED TO HOLD by Harold, 2026-09-09, Sprint 68 scope selection; PREP DONE Sprint 66, submission remains trigger-gated at 2,500+ users or $5K/yr)**
- Phase: Android Google Play Store Readiness
- Platform: Android
- Trigger: 2,500+ users or $5K/yr revenue. **Do NOT set the OAuth consent screen to "In production" before verification completes** -- publishing while unverified caps the project at 100 new users FOR ITS LIFETIME, and that cap cannot be raised or reset.
- **Sprint 66 delivered the PREPARATION, not the submission**: scopes narrowed to `gmail.modify` + `userinfo.email` (removing `gmail.send`, never called, and the redundant `gmail.readonly`); the data-residency determination recorded with every outbound connection enumerated; and two gates -- Windows/Android scope parity, and a build failure if any analytics/crash/ad SDK ever enters `pubspec.yaml`. A Phase 5.1.1 review independently confirmed no live call path needs a removed scope.
- What remains on this card: the verification submission to Google, and the CASA security assessment IF it applies. Current determination is that it does NOT -- CASA is required only where restricted-scope data is stored or transmitted on servers, and this app is client-only with no backend. Re-verify that determination at submission time rather than trusting this line.

### Sprint Assignment (Sprint 47 pre-kickoff rollover, 2026-07-11)

Recent sprints complete -- detail blocks removed per the Maintenance Guide (history lives in `docs/sprints/` + CHANGELOG.md):
- **Sprint 42** (merged PR #263): F99 (integration_test harness), F98 (per-account bg-scan, ADR-0039 + ADR-0040), BUG-S37-2
- **Sprint 43** (merged PR #265): F102, F103, F96 (DB v8), F100, F101, F104, F105, F110; SEC-11b deferred Post-MVP (cipher -> SQLite3MultipleCiphers)
- **Sprint 44** (merged PR #266): F107 (Accept ADR-0037 + promote ARSD), F109 (surface background-deferral state), F108 (dep bumps: flutter_appauth 8->12, workmanager 0.5->0.9, flutter_secure_storage 9->10 + Android minSdk 23); retro IMP-1 version-consistency gate
- **Sprint 45** (merged PR #268, 2026-07-02): F111 (Windows App Store upload readiness verification -- GO for 0.5.4); **develop -> main released**; retro IMP-1 read-format-doc-first rule
- **Sprint 46** (merged PR #270, 2026-07-11): F64 (CI/CD pipeline), F39 (cross-account "No Rule" review screen + unmatched_emails writer fix), F33 (body-rules cleanup, dev-DB applied); manual-testing fixes (popup position, auto-advance, provider-sender grouping); retro IMP-1/2/4/5 applied

**Sprint 47 scope (Store 0.5.4 manual-testing feedback + carry-ins, Harold 2026-07-15)**: The **F112-F119** items below (Store-0.5.4 manual-testing feedback) are assigned to Sprint 47. **Carry-ins** also folded in: (1) dev version bump 0.5.4 -> 0.5.5 (see F118); (2) F33 prod-DB `--env prod --apply` (post-Store-rollout; requires the Copilot round-6 decode-failure report-not-delete fix first); (3) populate the 5 `CI_*` GitHub repo secrets; (4) IMP-3 CHANGELOG-cadence decision (A per-completed-item vs B Phase-5-entry gate); (5) Copilot round-6 polish (no_rule_review_screen load-error stackTrace + friendly SnackBar; cleanup-script decode-failure fix -- required before carry-in #2). **Standing HOLD candidates** unchanged: template deep dives (F70 Security / F71 Architecture / F111 Store-readiness), Post-MVP (SEC-11b DB encryption + F106 cleanup, paired), platform/UX tracks (F94/F95 flavors, F63 responsive, SEC-8b/SEC-15, F6, H1-H5, F67, GP-*), F39 mobile variant. **Open follow-up (Sprint 44 carry-in)**: Android-device retest of the F108 dep bumps -- not yet scheduled. **Store status**: 0.5.4 LIVE on the Microsoft Store (submission accepted, certification passed 2026-07-15). Note (F119): 0.5.4 MSIX shipped running as APP_ENV=dev -- fix + re-release needed.

**Sprint 50 scope (Harold 2026-07-25)**: **F126 + F122 + F123 + F124 + F127 (rescoped -- residual verification only)**. Selected from the 2026-07-25 refinement presentation after candidate conversations: F122 verified still needed; F127 re-scoped per Harold option 2 (see DevOps section); F-WINSTORE-ASSETS executed interactively during refinement and is DONE (see Release Readiness). Pre-kickoff work already on the sprint branch `feature/20260723_Sprint_50`: backlog-refinement format hardening (spec v1.3 + skill), F127 ci.yml key fix (`5c4e0ce`), F-WINSTORE-ASSETS screenshot masters (`3c357a6`, `b40c089`). Remaining candidates (F-COPILOT-INSTR, F125, F94, F108-RETEST, GP-*) stay in the backlog.

### Sprint 47 -- Store 0.5.4 Manual-Testing Feedback [ALL VALIDATED + CLOSED, Harold 2026-07-22]

**F112-F118 shipped in Sprint 47 (PR #272) and every item was re-validated item-by-item by Harold on the Sprint 49 (0.5.7-candidate) dev build on 2026-07-22 -- all "Working as expected. Can be closed."** Detail sections removed per the Maintenance Guide (history lives in `docs/sprints/SPRINT_47_PLAN.md`, `SPRINT_47_RETROSPECTIVE.md`, and CHANGELOG 2026-07-15). The F119 defect family (F119 key typo -> F119-b secrets hygiene -> F119-c native title) is tracked in the **Store status** line above; the corrected build is `0.5.7` (PR #276). Sprint 47's five retro improvements (IMP-1..IMP-5, all applied) are recorded in `SPRINT_47_RETROSPECTIVE.md`.

### Core App

_(No active Core App candidates -- F96 shipped in Sprint 43.)_

### Process

**F199-b. Partner Center publisher display name -- the last surface of the LLC rename (~15m once unblocked) Priority 12 (Sprint 68 remnant; EXTERNALLY BLOCKED)**
- Phase: Release Readiness
- Platform: Windows Desktop (Microsoft Store account surface)
- Sprint 68 delivered every other surface: the repo (10 replacements, 7 files), the Play
  developer name, and the Partner Center listing fields (Copyright / Developed by), the latter
  folded into Submission 25 rather than paying a separate listing-only certification pass.
- **What remains**: Partner Center still shows `Kimmey Consulting - Ohio` as the publisher
  display name. **Microsoft's own documentation contradicts itself** on whether an Individual
  account can change it -- the Windows Store FAQ says publisher display name "cannot be changed
  after registration", while the Partner Center account doc says you can "select the Update
  link to change your contact info, such as publisher display name", and the console DOES show
  that link. Unresolvable from documentation.
- **Next action is Harold's, not code**: a support ticket at
  https://aka.ms/windowsdevelopersupport asking (a) can this Individual account's publisher
  display name be changed, and (b) can a published app be transferred to a new Company account.
- **Do NOT touch** `msix_config.publisher` (`CN=84EA8722-...`) -- that is the Partner-Center
  assigned GUID, not a name; changing it breaks package identity and every installed copy's
  upgrade path.
- Account type is CLOSED: both stores stay Personal/Individual (`docs/LEGAL_ENTITY.md`).
- Depends on: a Microsoft support answer. Nothing in the repo blocks it.

**F111. Periodic Windows App Store upload readiness verification (~110-175m per review) Priority HOLD**
- Phase: Release Readiness (reusable template)
- Platform: Windows Desktop
- **Generic scope**: verify develop/main parity, version compatibility vs the currently-published Store version, MSIX build-path integrity (`msix_config.windows_build_args` OAuth-credential injection -- note the key is `windows_build_args`; the transposed `build_windows_args` is the F119 defect), and Store-submission preconditions (`docs/STORE_RELEASE_PROCESS.md` checklist) BEFORE any Store build/upload. Produces a GO/NO-GO readiness finding; does not build or upload.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a new Windows Store release is planned. First run: Sprint 45 (see `docs/sprints/SPRINT_45_F111_STORE_READINESS.md`).
- Source: Sprint 45 backlog refinement (2026-07-02) -- captured as a recurring template since Store readiness verification will be needed for every future release.

**F139. Local-install smoke test for a release-candidate MSIX (~30-50m per review) Priority HOLD**
- Phase: Release Readiness (reusable template)
- Platform: Windows Desktop
- **Generic scope**: build a release-candidate MSIX and run a full manual smoke pass (Gmail sign-in, About screen version, title bar, data directory) on the SAME machine that has the live Store build installed -- WITHOUT merging to `develop`/`main`, without uploading to Partner Center, and without disturbing the installed Store build. Produces a PASS/FAIL smoke-test finding on a release candidate; does not release anything.
- **What this covers (do this)**:
  1. Build from a **local, unpushed** checkout: merge the sprint feature branch into the prod worktree's local `main` (`git merge --no-edit origin/feature/...`) so `pubspec.yaml`'s `msix_version` bump and any other release-affecting changes are present, WITHOUT pushing or asking Harold to merge to `develop`/`main` first. Record the pre-merge HEAD SHA so the worktree can be restored (`git reset --hard <sha>`) after the smoke test.
  2. **The Store-submission MSIX config (`store: true, install_certificate: false`) produces an UNSIGNED package that cannot be locally installed** -- `Add-AppxPackage` fails with `0x800B0100 / HRESULT 0x80073CF0: The app package must be digitally signed for signature validation`. This is expected and is NOT a defect (Partner Center signs the real submission; a local smoke test never goes through Partner Center).
  3. **To make it locally installable**, temporarily flip the two flags already documented in `pubspec.yaml`'s own comment (`mobile-app/pubspec.yaml`, `msix_config` block, ~line 119-122): `store: false` and `install_certificate: true`, then rebuild with `flutter pub run msix:create`. This self-signs the package with a locally generated test certificate.
  4. A self-signed local build installs as a **separate package** alongside the live Store build (different signing identity -> different package family), so `Add-AppxPackage` does NOT need `-ForceApplicationShutdown` to replace anything and the live Store install is untouched. Both versions coexist and are separately launchable (`Get-AppxPackage -Name "*MyEmailSpamFilter*"` lists both; `Get-StartApps` shows two Start-menu entries with different AppIDs).
  5. Verify the installed release candidate the same way as any Store build: `<InstallLocation>\MyEmailSpamFilter.exe --print-env` (launch via `Start-Process ... -RedirectStandardOutput` to reliably capture output; a bare `&` invocation from a script can silently produce nothing) should show `APP_ENV=prod`, empty `displaySuffix`/`dataDirSuffix`, `windowTitle=MyEmailSpamFilter`, `NATIVE_APP_ENV=prod`. Launch the actual window via its AppX identity (`Start-Process "shell:AppsFolder\<AppID>"`, from `Get-StartApps`) for the visual title-bar/About-screen check, not the raw exe path directly (packaged apps are normally activated through their app identity). **Gap CLOSED by F153's Sprint 59 re-test (2026-08-15)**: with the `SPI_SETSCREENREADER` flag enabled and the semantics tree primed (one `ww_get_snapshot` after attach), WinWright reads the Settings > General version text directly (`ww_dump_tree` selector `name*="Version 0.8"` returned `Version 0.8.0 [DEV]`, on-screen -- the version now sits at the TOP of the tab and the whole tab fits the default window). The visual version confirmation CAN now be automated; the `--print-env` probe and title-bar check remain independently reliable. Pre-flight: check flag status + prime the tree per `docs/WINWRIGHT_SELECTORS.md` Prerequisites.
  6. Extract and grep `AppxManifest.xml` for `Version=` to confirm the manifest matches the target version, and check file size (~16-17 MB expected) -- same checks as a real release, see `docs/STORE_RELEASE_PROCESS.md` Step 4.
  7. After the smoke test: revert `pubspec.yaml`'s `store`/`install_certificate` flags back to `true`/`false` (do NOT commit the local-testing flip), and reset the prod worktree back to the recorded pre-merge SHA (`git reset --hard <sha>`) so it is clean and ready for the REAL release build later.
- **What this does NOT require (avoid re-deriving these)**:
  - Does NOT require merging the sprint branch to `develop` or `main` first -- a local, unpushed merge into the prod worktree is sufficient to get the version bump for a smoke-test build.
  - Does NOT require uploading anything to Partner Center.
  - Does NOT require a code-signing certificate purchase or Windows SDK signtool workflow -- the `install_certificate: true` msix-package option self-signs automatically.
  - Does NOT require uninstalling or disturbing the live Store build first -- self-signed and Store-signed packages install side-by-side under different package identities.
  - Does NOT require Developer Mode / sideload registry changes on a machine that already has them (check `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` -> `AllowAllTrustedApps`/`AllowDevelopmentWithoutDevLicense` -- Harold's dev machine already had both set to 1; the earlier signature-validation error was NOT a sideload/trust problem, it was purely the unsigned-package error above).
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable each time a release-candidate smoke test is needed before committing to a full Store release. Complements F111 (pre-build readiness check) and `docs/STORE_RELEASE_PROCESS.md` Step 4 (post-upload verification) by covering the middle step: proving an unreleased build installs and runs correctly on real hardware.
- Source: Sprint 53 (2026-08-03) -- F-STORE-53 scope was corrected mid-sprint from "full release pipeline" to "smoke test only" after Harold flagged the scope creep; the local-install signing workaround was discovered live during that task and is captured here so it does not need to be re-derived on the next release.

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

**F130. Periodic Process-Docs Consistency Deep Dive ([no-history] -- unbounded discovery; see estimating note) Priority HOLD** _(TEMPLATE -- first run assigned to Sprint 51, see F130-S51 below)_
- Phase: Process Spike (reusable template)
- Platform: N/A (repo documentation + harness configuration)
- **Generic scope**: audit the sprint-execution instruction surface for logical consistency, so that any Claude model tier (Haiku / Sonnet / Opus / Fable) executing the sprint process reaches the SAME correct behavior from whichever document it happens to read. The architecture deep dive (F71) does this for the CODE; nothing does it for the PROCESS DOCS, which are equally load-bearing -- they are the actual control system for development on this project.
- **Surfaces in scope** (the full instruction surface, not just `docs/`):
  - The 11 SPRINT EXECUTION docs (`SPRINT_EXECUTION_WORKFLOW.md`, `SPRINT_CHECKLIST.md`, `SPRINT_PLANNING.md`, `SPRINT_RETROSPECTIVE.md`, `SPRINT_STOPPING_CRITERIA.md`, `BACKLOG_REFINEMENT.md`, `TESTING_STRATEGY.md`, `QUALITY_STANDARDS.md`, `ALL_SPRINTS_MASTER_PLAN.md`, `STORE_RELEASE_PROCESS.md`, `CODING_VELOCITY.md`)
  - `CLAUDE.md` and `AGENTS.md` (read by every model tier; must not diverge from each other)
  - `.claude/hooks/*` (enforcement must match what the docs say, and must not false-positive)
  - `.claude/skills/*/SKILL.md` (skills encode deterministic processes; must match their source doc)
  - `.claude/agents/*` if present, `.claude/settings.json` hook registrations, `.claude/sprint_status.json` schema
  - Auto-memory `MEMORY.md` + `feedback_*.md` (**recall re-teaches whatever it says** -- a stale memory silently overrides corrected docs)
- **Defect classes to hunt** (each seeded by a real escape):
  1. **Same instruction, contradictory recipes** -- e.g. Phase 6.6 branch creation was stated 5 different ways across 2 docs + 2 memory entries; the cheat sheet said "off updated develop" while the detailed section said "from the current feature branch", and the detailed section's own "Why" paragraph contradicted its own "Steps" block two lines later (found 2026-07-27, Sprint 51).
  2. **Summary-vs-detail drift** -- cheat-sheet / table-of-contents / quick-reference rows that paraphrase a detailed section and fall out of sync when the section is corrected. Check EVERY summary row against its section.
  3. **Superseded recipes left in place without a supersession marker** -- old instructions retained "for context" that read as current. Require an explicit `SUPERSEDED by X (date)` marker or delete.
  4. **Memory-vs-doc divergence** -- a `feedback_*.md` `description:` field or `MEMORY.md` index line still teaching a corrected-away behavior. These surface during recall and outrank docs in practice.
  5. **Orphan instructions** -- a step referenced in one doc but defined nowhere (or a file like `.claude/sprint_status.json` mentioned in exactly ONE line with no definition of what to put in it -- how it drifted 15 sprints unnoticed).
  6. **Hook-vs-doc mismatch** -- enforcement that blocks something the docs permit, permits something the docs forbid, or false-positives (e.g. the stash-guard hook blocking a Bash command whose text merely *documents* the stash prohibition, 2026-07-27).
  7. **Unenforced MANDATORY steps** -- steps marked MANDATORY with no gate, hook, test, or checklist line that would catch omission. Rank by blast radius; propose the cheapest enforcement.
  8. **Tier-inconsistent guidance** -- instructions that only work if the reader is a top-tier model (implicit judgment calls, unstated context). Haiku executing the same step must reach the same outcome.
  9. **Dead references** -- links/paths/section anchors/issue numbers/skill names that no longer resolve.
- **Method**: build an inventory of every instruction that appears in more than one place, diff the statements pairwise, and produce a findings table (`Instruction | Sites | Statements | Authoritative version | Action`). Prefer ONE authoritative statement plus pointers over duplicated prose -- duplication is what drifts.
- **Deliverable**: findings table + corrections applied in-sprint + any new enforcement proposed; log the count of contradictions found so the trend is visible across reviews.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep this template for the next review.
- HOLD rationale: Template item, reusable. Duplicate when the process docs have accumulated enough change to warrant a consistency pass -- suggested triggers: after any sprint that applies 4+ process improvements, after any repeat-offense correction (the same mistake corrected 3+ times suggests contradictory guidance rather than model error), or every ~5 sprints.
- Source: Harold 2026-07-27, after the Sprint 50/51 close-out escapes traced to instruction-surface defects rather than one-off model error: a multi-part request treated as a theme, a checklist reported complete without being opened, and the Phase 6.6 branch recipe stated inconsistently in 5 places (2 of them in memory, which re-teaches on recall).

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

_(Sprint 51-52 detail sections pruned per Maintenance Rule 2 -- all shipped/resolved/retired, history lives in the sprint docs and CHANGELOG: F130-S51 process-docs consistency deep dive + stash-guard hook fix (Sprint 51); F129 WinWright coverage + F128-residual RuleSetProvider audit (Sprint 51); F131 WinWright create-path -- resolved as no app defect, root cause was an inherited bad selector (Sprint 52); F132 retired, superseded by F133; F133/F133-S52 accessibility audit template + first run -- see `docs/ACCESSIBILITY_STANDARDS.md` and `SPRINT_52_F133_FINDINGS.md`; F134 AppBar icon order + F135 session-scoped accounts + F136 Skip button, all shipped Sprint 52 -- see `SPRINT_52_RETROSPECTIVE.md`; ENV-1 dev-machine AppXSvc/Acronis conflict, resolved 2026-07-30 via an Acronis exclusion, machine-local and never an app defect.)_

### HOLD Items (Android / Google Play Store)

_(Track activated 2026-08-24: F94, SEC-4, SEC-9 and all GP-n items moved to the active 'Android / Google Play Store Readiness' section above with numeric priorities. SEC-6 MERGED into GP-2; SEC-7 MERGED into GP-9. **F4. Background Scanning - Android -- SUPERSEDED: delivered as F161 (Sprint 61), count-parity validated.** **Issue #163. Android app not tested -- RESOLVED: Android validated continuously on-device in Sprints 59-62.** Remaining below: non-Android or still-deferred items.)_


> **[NEXT MAJOR TRACK -- TRIGGER FIRED 2026-07-24]**: `0.5.7` is verified LIVE (clean prod title). Per Harold's 2026-07-15 promotion trigger, this Android / Google Play track is now **OFF HOLD** and is the next focus. Android development is intentionally stagnant only until that Windows release lands. At promotion, refine this section into an active sprint: start with the `google-services.json` applicationId mismatch diagnosis (F94 pre-existing investigation item -- likely root of intermittent Android Gmail OAuth), then F94 flavors, then the F108 Android-device dep-bump retest carry-in, then the Google-Play-gated security items below.

> **[GOVERNING DIRECTION -- Harold, 2026-08-03, Sprint 54 F141 deep dive]**: *"All the UIs (now with the Windows UI being the default) should use the same UI and tools unless they cannot -- then they should adapt as needed for the needs of the platform"* (UI/navigation), and *"same architectural principle for all the non-UI components -- reuse whatever possible, exactly as is, but adjust where necessary"* (services/backend). **Clarified same day**: the app was built Android-first for early MVP speed, then switched to the Windows Store App style UI and architecture once that became the priority -- so **Windows' current architecture and tooling is the baseline that takes precedence, not "whichever platform already has code."** It is explicitly OK to REMOVE existing Android UI and backend code and replace it with the Windows-side pattern, adjusting only where Android has a genuine platform constraint (no keyboard modifiers, no hover state, no Windows Task Scheduler equivalent) -- never merely to preserve old Android-first code for its own sake. This is DURABLE guidance for every future Android-track item, not scoped to one sprint. See `docs/sprints/SPRINT_54_F141_ANDROID_DEEP_DIVE.md` for the full deep dive this direction came from.

> **[TOOLING DECISION -- Harold, 2026-08-12, Android track unblocked]**: **Android Studio Emulator (AVD Manager) is the primary/default Android testing environment** for this track. Deep-dive comparison against 2 free alternatives (WSA ruled out -- discontinued March 2025):
> - **Android Studio Emulator (chosen)**: native "Google APIs"/"Google Play" system images (matches CLAUDE.md's existing Gmail-OAuth guidance exactly, zero extra setup); fully free, no feature gating; best Flutter tooling integration (`flutter devices`/`flutter run`/hot reload built against this exact toolchain); native multi-AVD side-by-side support (useful for F94 dev/prod/store flavor testing). Con: slowest cold boot (~22s) and heaviest resource footprint of the 3 candidates -- accepted tradeoff for zero-workaround OAuth correctness. SDK already installed at `C:\Android\android-sdk`.
> - **Genymotion Desktop (documented alternative, if needed)**: free "Personal Use" tier, ~9s boot (fastest of the 3). Requires flashing "Open GApps" for Google Sign-In -- **the classic Open GApps package only covers up to Android 11; Android 12+ needs Genymotion's newer built-in GApps mechanism**, verify per target API level before relying on it. Free tier disables Quick Boot and network-profile simulation (the latter could matter for WorkManager background-scan testing under connectivity changes). Consider if F94 flavor-testing iteration speed becomes a bottleneck on the Android Studio emulator.
> - **BlueStacks (documented alternative, if needed)**: free tier, ships with Google Play pre-baked (nothing to flash). Built on a gaming-oriented Android image, not a clean Google reference build -- higher risk of diverging from real-device behavior on OAuth redirects or background-task timing; known Flutter hardware-rendering compatibility issue (flutter/flutter#19711) may need a software-rendering fallback. Has a native multi-instance manager that could double for F94 side-by-side flavor testing if BlueStacks is ever adopted.
> - Not evaluated as primary candidates: Windows Subsystem for Android (discontinued), gaming-only emulators with no credible dev/testing workflow.

_(F142 shipped Sprint 57 -- see `docs/sprints/SPRINT_57_PLAN.md` and CHANGELOG.md 2026-08-14. `MainNavigationScreen`'s `Platform.isAndroid` bottom-nav branch removed entirely; both platforms now share the same default-screen decision, `appDefaultScreenFor`, formerly `_DesktopDefaultScreen`/`desktopDefaultScreenFor`. Manual on-device Android validation was blocked by the pre-existing F94/F150 build issue -- see F150 below.)_

**F201. Periodic Web Property Accuracy Re-Review -- myemailspamfilter.com + GitHub Pages (~1-2h per review, plus fix time if findings warrant) Priority HOLD** _(TEMPLATE -- created by the F200 final acceptance criterion, Harold 2026-09-09)_
- Phase: Web Property (reusable template)
- Platform: All (the site represents every shipped platform)
- **Generic scope**: re-review everything served at `https://myemailspamfilter.com/` and from
  GitHub Pages (`main:/docs`) for ACCURACY against the current app, the current legal
  documents, and the current store presence -- then make the updates the review finds.
- **Method**: (1) enumerate what is actually served LIVE, following every internal link, rather
  than reasoning from the repo -- the two have already diverged once; (2) diff every factual and
  privacy claim against `docs/legal/PRIVACY_POLICY.md`, `TERMS.md` and the shipped behavior;
  (3) verify publisher identity, contact details and store links against reality -- names and
  account facts change (F199); (4) confirm exactly one canonical privacy policy and one
  deletion page remain reachable; (5) check that any gate covering the served site still
  actually covers it.
- **Why this is periodic and not one-shot**: the site is hand-written HTML with no build step,
  so it does not track the app. It drifted ~6 months carrying a privacy claim the app had
  already stopped honoring, while the Markdown legal documents beside it stayed correct
  automatically. Anything without a build step or a gate needs a human on a schedule.
- **Suggested triggers**: after any change to `PRIVACY_POLICY.md` or `TERMS.md`; after a
  publisher/account identity change; after a new store or platform ships; after a feature
  changes what the app stores or transmits; otherwise periodically (suggested: every 10-15
  sprints).
- **ALSO RE-REVIEW THE IN-APP PROVIDER SETUP STEPS** (added Sprint 68 IMP-3):
  `platform_selection_screen.dart`'s `_build{Aol,Yahoo,ICloud}Steps` name vendor URLs and UI
  labels, and they went stale exactly the way the website did -- four of six iCloud steps were
  wrong, pointing at a page Apple had renamed. `test/policy/provider_setup_steps_test.dart`
  now gates app-vs-doc AGREEMENT, but **no gate can watch someone else's website**: only a
  human re-checking the vendor pages catches a rename. That is this item's job.
- **How to use**: Duplicate this item, assign a sprint, and remove HOLD. After completion, keep
  this template for the next review.
- HOLD rationale: Template item, reusable. Dormant until a trigger above fires.
- Depends on: F200 (which establishes the canonical state this re-review checks against).
- Source: Harold, 2026-09-09 -- the periodic companion is the F200 final acceptance criterion,
  alongside F70 (Security), F71 (Architecture), F130 (Process-Docs), F152 (First-Run), F173
  (Test Coverage) and F189 (Skills).

**F95. iOS variants + cross-store hardening (~10-16h) Priority HOLD -- RENUMBERED from "F52 Phase 3+" + MOVED TO HOLD (Sprint 39 Backlog Refinement, 2026-05-25)**
- Phase: Build and Release Infrastructure
- Platform: iOS, plus polish across all 9 variants (3 stores x 3 channels: dev, production, store)
- Renumbered from the ambiguous "F52 Phase 3+" to a distinct F# (was sharing F52 with the Android phase, now F94). Moved to HOLD with the multi-variant track per Harold (2026-05-25) -- blocked until iOS development begins (requires macOS + Apple Developer account).
- All variants must run simultaneously without rebuild on same machine/device.
- [Detail](#f52-multi-variant-side-by-side-install)
- Source: ADR-0035 dev/prod separation.

**F63. Responsive design framework -- [SUPERSEDED 2026-08-03 by Sprint 54 F141's per-screen findings] Priority HOLD**
- Phase: UX Improvement
- Platform: All
- Original scope: adaptive breakpoints per ARSD AR-7 (phone/tablet/desktop), priority screens scan progress/results display/settings.
- **Superseded**: the Sprint 54 F141 deep dive (`docs/sprints/SPRINT_54_F141_ANDROID_DEEP_DIVE.md` Section 2) audited all 23 screens directly -- only 2 use `MediaQuery` at all (both incidental, not breakpoint logic), zero `LayoutBuilder`/`OrientationBuilder` anywhere. Concrete per-screen findings now exist: 16 screens work-as-is, 5 need touch-target/density adaptation (`results_display`, `rules_management`, `safe_senders_management`, `account_setup`, `settings`), 2 need a genuine new interaction pattern (`yaml_import_export` -- data-layer, not layout; `no_rule_review` -- see F143). Use that document's Section 2 as the authoritative scope instead of this item's original vague framing.
- Source: Sprint 30 gap analysis (gap G23); superseded by Sprint 54 F141.

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

**GP-11. Account and Data Deletion Feature** -- Moved to F66 (off HOLD, all platforms including Windows Store). See F66 in Core App section above.

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

**Status as of Sprint 64 close (2026-09-04)**: the Android release chain is COMPLETE -- the app is
Play-submittable. GP-2/GP-3/GP-5/GP-8/GP-9/GP-16 shipped in Sprint 64; GP-12 in Sprint 63. The
remaining runway to a live Play listing is **GP-7 -> GP-6 -> GP-10 -> closed-test submission**.
Play App Signing enrolls automatically at the first upload. The **12-tester / 14-day closed test
is the long pole**, so tester recruitment should start BEFORE the code work, not after.

| ID | Title | Est. Effort | ADR | Priority | Status |
|----|-------|-------------|-----|----------|--------|
| GP-1 | Application Identity and Branding | ~4-6h | ADR-0026 (Accepted) | BLOCKING | [OK] COMPLETE (Sprint 19) |
| GP-2 | Release Signing and Play App Signing | ~4-6h | ADR-0027 (Accepted, IMPLEMENTED) | BLOCKING | [OK] COMPLETE (Sprint 64) |
| GP-3 | Android Manifest Permissions | ~4-6h | ADR-0028 (Proposed) | BLOCKING | [OK] COMPLETE (Sprint 64) -- exactly 9 justified permissions; GP-10's input |
| GP-4 | Gmail API OAuth Verification (CASA) | ~40-80h | ADR-0029 (Accepted) | BLOCKING | HOLD -- trigger: 2,500+ users or $5K/yr revenue |
| GP-5 | Privacy Policy and Legal Documents | ~8-16h | ADR-0030 (Accepted) | BLOCKING | [OK] COMPLETE (Sprint 64) -- PUBLISHED at myemailspamfilter.com/legal |
| GP-6 | Play Store Listing and Assets | ~8-12h | -- | HIGH | [OK] REPO WORK COMPLETE (Sprint 65) -- listing copy + asset spec + cross-store comparison + gate. CONSOLE ENTRY and SCREENSHOT CAPTURE remain Harold's (Sprint 66). |
| GP-7 | Adaptive Icons and App Branding | ~4-6h | ADR-0031 (Proposed) | HIGH | [OK] COMPLETE (Sprint 65) -- audit found the adaptive icons ALREADY correct at all five densities; only the 512x512 listing icon was produced. |
| GP-8 | Android Target SDK + 16 KB Page Size | ~4-8h | -- | MEDIUM | [OK] COMPLETE (Sprint 64) -- verify PASS: already API 36, 16KB aligned |
| GP-9 | ProGuard/R8 Code Optimization | ~4-6h | -- | HIGH | [OK] COMPLETE (Sprint 64) -- R8 + obfuscation, -12.8% APK |
| GP-10 | Data Safety Form Declarations | ~2-4h | -- | BLOCKING | [OK] REPO WORK COMPLETE (Sprint 65) -- declarations recorded WITH code evidence and gated. CONSOLE ENTRY remains Harold's (Sprint 66). |
| GP-11 | Account and Data Deletion Feature | ~8-12h | ADR-0032 (Proposed) | HIGH | HOLD |
| GP-12 | Firebase Analytics Decision | ~2-4h | ADR-0033 (Accepted) | MEDIUM | [OK] COMPLETE (Sprint 63) -- Firebase Analytics removed |
| GP-13 | Persistent Gmail Auth for Production | 0h | -- | -- | RESOLVED (merged with F12, see ADR-0029/0034) |
| GP-14 | IMAP vs Gmail REST API Decision | 0h | ADR-0034 (Accepted) | -- | RESOLVED (dual-path, no migration needed) |
| GP-15 | Version Numbering and Release Strategy | ~2-4h | -- | HIGH | [OK] COMPLETE (Sprint 19) |
| GP-16 | Google Play Developer Account Setup | ~2-4h | -- | BLOCKING | [OK] COMPLETE (Sprint 64) -- account created, all verifications cleared |

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
| ADR-0033 | Analytics and Crash Reporting Strategy | GP-12 | Accepted (2026-02-15; registry corrected 2026-08-24 -- rows here were stale) |
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
| 6.19 | 2026-07-30 | **Sprint 51 retrospective complete; 5 items carded for Sprint 52.** Manual Validation closed all 5 items ("Working as expected"). All 7 retro improvements were approved APPLY NOW; **IMP-7 shipped in-sprint** (auto-advance hook gained the ENFORCEMENT WINDOW upper bound Harold specified -- the rule applies only between Phase 3.7 approval and the start of Manual Validation, which was the root cause of every false positive this hook has produced; suite 33/33). IMP-1/2/3/4 became backlog cards for detail planning at Harold's direction: **F133** (accessibility audit as a repeatable HOLD template, **superseding and retiring F132**) + **F133-S52** first run; **F134** (canonical AppBar icon order -- shared builder DONE and applied to Manual Scan in Sprint 51, three screens remaining); **F135** (session-scoped account selection -- provider and lazy resolver DONE in Sprint 51, Settings per-tab prompting and the No-Rule default screen remaining); **F136** (Skip button in the No-Rule popup). IMP-5 (WinWright actuals) and IMP-6 (drive-it-don't-dump-it rule) fold into F133-S52. |
| 6.18 | 2026-07-28 | **`0.5.8` ACTUALLY SUBMITTED to Partner Center (Submission 9) -- correcting a 6.15 error.** Entry 6.15 recorded 0.5.8 as "SUBMITTED ... in certification" on 07-27. It was not. Partner Center showed Submission 9 **In draft** with a live "Submit for certification" button: the MSIX was built, uploaded and **Validated**, but the submission was never pushed over the line, and Store presence was still Submission 8 (`0.5.7`). Found 2026-07-28 when Harold checked Partner Center directly after questioning why the dev app still read `0.5.8` rather than `0.5.9`. **BUILT + VALIDATED is not SUBMITTED** -- and the same wrong state was then repeated as fact from `sprint_status.json` for a full day, including as a candidate explanation for an unrelated Store-client bug. Release state is verified in Partner Center, never from a tracking file. Also recorded: a **Microsoft Store CLIENT defect** (app detail pages render as never-populating skeletons while search works; reproduces on third-party listings; survives reboot + `wsreset`) -- not ours, not blocking, no action available. |
| 6.17 | 2026-07-28 | Added **F131** (WinWright create-path not drivable -- Priority 13) and **F132** (systematic accessibility sweep -- Priority 20), both from Sprint 51 F129 execution and both approved by Harold for the backlog. F131 matters beyond tooling: the two `test_f56_*` scripts are **STALE, not merely excluded** -- their own documented radio workaround did not reproduce, so re-enabling them hits three walls while the comment block asserts the fix works. F132 converts the reactive per-script accessibility fixes into one deliberate WCAG 2.1 AA pass (ADR-0037 already sets that target), with the caution that a wrapper which NAMES a node can also make it UNCLICKABLE -- verify both. **F130-S51 CLOSED**: all 3 tiers complete, 28 contradictions found and corrected, 0 outstanding; the single Class-3 item (retired Sprint-39 memory restore path) was decided by Harold 2026-07-28 and applied same-day (`/memory-restore` retired to a tombstone; `/startup-check` now reads `.claude/sprint_status.json`). |
| 6.16 | 2026-07-27 | Added **F130. Periodic Process-Docs Consistency Deep Dive** (Process Spike, Priority HOLD, reusable template -- the process-docs counterpart to F71's architecture deep dive). Audits the full instruction surface (11 sprint docs + CLAUDE.md/AGENTS.md + hooks + skills + settings + auto-memory) for 9 defect classes: contradictory recipes, summary-vs-detail drift, unmarked superseded text, memory-vs-doc divergence, orphan instructions, hook-vs-doc mismatch, unenforced MANDATORY steps, tier-inconsistent guidance, dead references. Seeded by the Sprint 50/51 escapes -- notably the Phase 6.6 branch recipe stated 5 inconsistent ways across 2 docs and 2 memory entries. Also added **F129** (WinWright coverage carry-in, Priority 19). |
| 6.15 | 2026-07-27 | **Sprint 50 merged (PR #278 -> develop, PR #284 -> main) + `0.5.8` SUBMITTED to Partner Center.** MSIX built from merged main; both-sides proof passed; credentials verified embedded. Sprint 51 branch `feature/20260727_Sprint_51` opened per Phase 6.6. Copilot review closed at 9 findings across 4 rounds, all fixed in-sprint (incl. F128 escalated from backlog). Open carry-ins for Sprint 51: F128 sibling early-returns (`removeRule`/`updateRule`/`removeSafeSender`), F129 WinWright coverage. STORE_RELEASE_PROCESS Step 6 gained the release-notes location (Store listings -> "What's new in this version"), which was undocumented. |
| 6.14 | 2026-07-25 | **Sprint 50 backlog refinement (v1.3 format with Summary Index) + scope selection (Harold): F126 + F122 + F123 + F124 + F127-rescope.** Registered F122-F127: F122/F123/F124 (Core App Quality, from Harold's 0.5.6 validation + Copilot round-6 carry-in), F125 (release self-test probe, Process), F126 (delete the 4 ambiguous legacy TLD rows -- PO decision made), F127 RESOLVED-RESCOPED (CI_* secrets deliberately unset; ci.yml key names fixed `5c4e0ce`; HOLD trigger = CI gains a runtime step). **F-WINSTORE-ASSETS DONE** -- 7 screenshot masters from the live 0.5.7 build committed to `docs/store-assets/windows/` and uploaded by Harold to Partner Center (metadata-only listing update). Pruned Sprint-49-shipped F33-PROD/BUG-DECODE details. |
| 6.13 | 2026-07-24 | **`0.5.7` LIVE + verified (NO [DEV] title) -- the first fully-correct public release; F119 family closed.** Close-out executed: CHANGELOG `[0.5.7] - 2026-07-24` release heading + links; dev bump 0.5.7 -> 0.5.8 (ONE file -- pubspec.yaml -- the F-VERSION-DERIVE payoff, gate-verified); Store status LIVE. **Android/Google Play track OFF HOLD** (promotion trigger fired). Sprint 50 scope selection pending with Harold. |
| 6.12 | 2026-07-23 | **Sprint 49 merged (PR #276 -> develop -> main) + `0.5.7` SUBMITTED to Partner Center** after the first-ever full both-sides proof (`APP_ENV=prod` + `NATIVE_APP_ENV=prod`). Rolled Last-Completed-Sprint 48 -> 49; pruned shipped F-VERSION-DERIVE / F-PRECHECK; Sprint 50 branch open (`feature/20260723_Sprint_50`, Phase 6.6 flow). On cert PASS: 0.5.7 close-out + Android/Google Play OFF HOLD. |
| 6.11 | 2026-07-22 | **Sprint 47 items ALL VALIDATED + CLOSED.** Harold re-validated every F112-F118 item on the Sprint 49 (0.5.7-candidate) dev build -- all "Working as expected. Can be closed." Pruned the 8-item detail block to a close-out note per the Maintenance Guide. Sprint 49 state: F119-c/F120/BUG-DECODE/F121/F-VERSION-DERIVE/F-PRECHECK done on PR #276; Part-C prod-DB applies rehearsed on a copy (F121: 12,539 -> 6,526; F33-PROD: convert 1,300 / remove 752 / 0 decode warnings) awaiting the app-closed window. |
| 6.10 | 2026-07-20 | **Sprint 48 (emergency F119-b hotfix) complete + Phase 7 doc maintenance.** Root cause of the 0.5.5 Store dev-leak = a SPACE in a `secrets.*.json` key silently dropping `APP_ENV=prod` via `--dart-define-from-file` (independent of the F119 key typo). Fixed (cleaned secrets + gate + `--print-env` compiled-truth probe + Step 4.0 rewrite), bumped 0.5.5 -> 0.5.6, rebuilt + PROVEN prod (`--print-env` -> `APP_ENV=prod`), submitted 0.5.6 to Partner Center. Rolled **Last Completed Sprint** 46 -> 48; wrote `SPRINT_48_PLAN.md` (retroactive) + `SPRINT_48_RETROSPECTIVE.md` (lightweight, Claude-team only per Harold). Added backlog **F-VERSION-DERIVE** (derive version at runtime, not hardcoded in 6 log-filename sites). GitHub issues: 0 open. |
| 6.9 | 2026-07-19 | Added **F-WINSTORE-ASSETS** (Release Readiness, BACKLOG per Harold): update all Windows/Microsoft Store listing images (Partner Center screenshots + store logos/tiles + promo graphics + app icon). Rationale: listing images carry over from prior submissions and predate Sprint 40-47 UI; the 0.5.5 first-public-release listing should show the current app. Windows counterpart to GP-6 (Play Store assets). Effort M (~2-4h). |
| 6.8 | 2026-07-19 | **First public release submitted.** After the Sprint 47 develop->main merge (PR #273), reconciled prod worktree (no true divergence -- main = develop + GitFlow merge-commits + CNAME churn), synced it to origin/main `cdcb0da`. Version bump was already on main via F118 (0.5.5.0). Built the corrected MSIX (`flutter pub run msix:create`), **Step 4.0 F119 check PASSED** (build log: `--dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json`), manifest `0.5.5.0`, 17.6 MB. Harold SUBMITTED it to Partner Center for certification 2026-07-19 (in cert, 24-72h) -- the first true public release (2 -> ~20 users), corrected for the F119 dev/empty-creds defect. On cert PASS: Step 7 close-out + Android/Google Play track off HOLD. Also fixed a stale `build_windows_args` reference in STORE_RELEASE_PROCESS troubleshooting. GitHub issues: 0 open. |
| 6.7 | 2026-07-18 | Sprint 47 Phase 7 retrospective complete (all 5 apply-now IMPs applied). **Scope decisions (Harold, pre-merge release review)**: (1) prod `secrets.prod.json` CONFIRMED current (Store download signs in cleanly; re-review Dec 2026); (2) prod worktree bumps to 0.5.5 at release (working as expected); (3) **F33 prod-DB apply and the `cleanup_body_rules.dart` decode-failure fix DEFERRED to Sprint 48** and DECOUPLED from the Store release -- both operate on the local prod rules DB / a dev-only script, neither is bundled or user-facing, so they have zero impact on the 20 new Store users. Added F33-PROD + BUG-DECODE as Sprint 48 candidates (Core App Quality). Nothing now gates the develop->main release except Harold's merge. |
| 6.6 | 2026-07-15 | Sprint 47 backlog: added **F112-F119** from Harold's manual validation of the Store-installed 0.5.4 build (new "Sprint 47 -- Store 0.5.4 Manual-Testing Feedback" phase group). F119 (MSIX ships as APP_ENV=dev -- `[DEV]` title/About + `_Dev` data dir) is highest priority (P8) and blocks F113 clean-user testing. Others: F112 Review-No-Rule entry point everywhere, F113 new-account default profiles (provider-keyed folders + scan defaults, Export CSV ON), F114 retention defaults -> 90d, F115 selection-bar reorder, F116 Demo Scan completion matches Live, F117 Help footer -> app version, F118 post-Store-release housekeeping. All assigned to Sprint 47; carry-ins folded in. **0.5.4 confirmed LIVE on the Store (cert passed 2026-07-15)**. GitHub issues: 0 open. |
| 6.5 | 2026-07-11 | Sprint 46 completion + Sprint 47 pre-kickoff rollover (Phase 7 maintenance): rolled **Last Completed Sprint** 45 -> 46 (PR #270 merged); added the Sprint 46 row to the Past Sprint Summary table. Pruned the 3 shipped items **F64/F39/F33** from Next Sprint Candidates (DevOps + Core App Quality sections now reference-only). Refreshed Sprint Assignment header to Sprint 47 + "Last Reviewed" -> July 11, 2026 (dropped the Sprint 41 history line per the rolling window). Recorded **Sprint 47 carry-ins**: 0.5.5 version bump, F33 prod-DB apply (gated on Copilot round-6 decode-fix), CI_* repo secrets, IMP-3 CHANGELOG-cadence decision, round-6 polish. Backlog candidate re-presentation to Harold deferred to Phase 1.2 per his instruction. GitHub issues: 0 open. |
| 6.4 | 2026-07-02 | Sprint 46 Phase 1 backlog refinement: pruned the shipped **F111** from Next Sprint Candidates (Release Readiness section now empty -- GO delivered Sprint 45); refreshed Sprint Assignment header to Sprint 46 + "Last Reviewed" -> July 2, 2026. Added **F111** as a new reusable HOLD template under Periodic Reviews (Windows Store readiness verification will recur each release). Harold took **F64, F33, F39** off HOLD and selected them as Sprint 46 scope (Priority 10/20/30); standing constraint -- hold on other major changes until the 0.5.4 Store rollout completes. GitHub issues: 0 open. |
| 6.3 | 2026-07-02 | Sprint 45 completion + Sprint 46 pre-kickoff (Phase 3.2.1): created `docs/sprints/SPRINT_45_SUMMARY.md`; rolled **Last Completed Sprint** 44 -> 45; added the Sprint 45 row (PR #268) to the Past Sprint Summary table. Recorded the **develop -> main RELEASE MERGE** (Harold, 2026-07-02) -- F111-verified `0.5.4` codebase is now on `main`; Store upload targeted Sat/Sun on a stable network. F111 was Sprint 45's only item (Release Readiness), so Next Sprint Candidates is otherwise unchanged from the 6.2 refinement -- awaiting Sprint 46 scope selection. |
| 6.2 | 2026-07-01 | Sprint 45 backlog refinement (Harold direction): moved **F106** Priority 30 -> HOLD/Post-MVP and paired it under SEC-11b (F106 cannot start until the SEC-11b DB-encryption item ships + ~2 verification sprints). Added **F111** (Windows App Store upload readiness verification, P40) as a NEW active item under a new "Release Readiness" section -- selected as the Sprint 45 scope. |
| 6.1 | 2026-07-01 | Sprint 44 completion + Sprint 45 pre-kickoff (Phase 3.2.1 + Phase 1 backlog refinement): rolled **Last Completed Sprint** Sprint 42 -> Sprint 44 (43 + 44 both merged, PR #265 + #266); created `docs/sprints/SPRINT_44_SUMMARY.md`; added Sprint 43 (PR #265) + Sprint 44 (PR #266) rows to the Past Sprint Summary table. Pruned the 3 Sprint-44 shipped items (F107, F108, F109) from Next Sprint Candidates -- active near-term backlog is now empty; remaining candidates are the deep-dive templates (F70/F71), F64 (HOLD), Post-MVP (SEC-11b/F106), and the HOLD platform/UX tracks. Refreshed "Last Reviewed" -> July 1, 2026. Open follow-up recorded: Android-device retest of the Sprint 44 F108 dependency bumps. |
| 6.0 | 2026-06-25 | Sprint 43 Phase 7 currency pass (rolled into PR #265 before merge, per Harold): updated **Last Completed Sprint** Sprint 38 -> Sprint 42 (the last MERGED sprint; Sprint 43 becomes Last-Completed at Sprint 44 pre-kickoff once PR #265 merges). Filled the **Past Sprint Summary** gap -- added the missing Sprint 39 (PR #260) and Sprint 40 (PR #261) rows (table had jumped 38 -> 41). Refreshed the stale **"Last Reviewed: May 25, 2026"** marker to June 23, 2026 (Sprint 42 Backlog Refinement). Backlog items F107/F108/F109 added during Sprint 43; SEC-11b moved to Post-MVP (cipher -> SQLite3MultipleCiphers). Addresses the master-plan staleness flagged in the PR #265 Copilot review. |
| 5.16 | 2026-05-25 | Sprint 39 Backlog Refinement (Phase 1, sprint allocation): Assigned active backlog across 3 sprints (summary table added under Next Sprint Candidates). Sprint 39: S38-CI-1, S38-CI-2, S38-CI-6, S38-CI-3, S38-CI-7, F91, F89, S38-CI-4, F74, F92, BUG-S37-2, F77, F93. Sprint 40 target: F75, F25, F35, F37, F78, F79. Sprint 41 target: SEC-11b, F83. Renumbered the ambiguous shared "F52 Phase 2/3+" into distinct F94 (Android flavors) + F95 (iOS variants) and moved both to the Android/GP HOLD group. Additional HOLD moves (supersede row 5.15's "stay active" note for these): F63 (responsive design), SEC-15, SEC-8b, F6 (provider optimizations). F75 expanded with two new walkthrough steps (Step 5 ongoing daily background scanning; Step 6 "how often to process 'no rules'" tied to daysBack window + F82 indicator). Created `docs/sprints/SPRINT_39_PLAN.md` for Phase 3.7 approval. |
| 5.17 | 2026-05-25 | Sprint 39 execution + scope adjustment: S38-CI-7 (Opus 4.6 vs 4.7 eval) moved Sprint 39 -> Sprint 40 and re-scoped per Harold's clarified intent (4+ tasks run on BOTH models on separate branches; scored on process-doc adherence / instruction-following / architecture discipline / stopping-criteria / forward-looking code quality; ~6-10h). Sprint 39 now 12 tasks (all shipped + tests green 1530/0). BUG-S37-2 corrective: removed 6 malformed bundled TLD rules (.c .giw .nwm .xd .sweepss .qzz.io) from rules.yaml + v6 cleanup migration; .sweeps/.ca retained; all 194 ccTLDs (except .us/.uk/.ca) confirmed kept per Harold. S38-CI-1 X-close fixed round 3 (removed setPreventClose interception; root cause = window_manager 0.3.9 destroy()=PostQuitMessage-only + swallowed WM_CLOSE -> engine teardown during process-exit unwind w/ orphaned tray) -- manually verified working by Harold. Phase 5.3 manual validation complete 2026-05-25 (Harold): X-close, F91 (AOL dedup), F89 (auth warnings) all verified. Sprint 39 committed as a2bb75e. |
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
