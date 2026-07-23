# Sprint 48 Retrospective (Lightweight -- Claude Code Development Team only)

**Sprint**: 48 -- F119-b Store dev-leak fix + 0.5.6 corrected resubmit
**Date**: 2026-07-20
**Branch/PR**: `feature/20260720_Sprint_48` / PR #274 (merged develop -> main)
**Format**: LIGHTWEIGHT per Harold's directive (2026-07-20) -- this was an emergency hotfix, so only the **Claude Code Development Team** role provides feedback (not the full 4-role x 14-category ceremony). Harold's PO/SM/Lead-Developer feedback is intentionally waived for this hotfix. All 14 categories are still addressed by the Claude Code Development Team role.

**Verification at retro**: `flutter test` -> 1763 pass / 29 skip; `flutter analyze` clean; rebuilt 0.5.6 prod MSIX `--print-env` -> `APP_ENV=prod` (compiled proof); manifest `0.5.6.0`; 0.5.6 submitted to Partner Center.

---

## Claude Code Development Team feedback -- 14 categories

### 1. Effective while as Efficient as Reasonably Possible
Efficient given the stakes: root cause found and proven, fix + hardening + version bump + rebuild + compiled-proof in one continuous hotfix. Two efficiency losses, both process (not code): (a) I created the Sprint 48 branch off `develop` instead of off the current feature branch -- Harold's documented directive, corrected for the 5th time; I had to delete/recreate the branch. (b) I burned cycles on binary forensics (grepping AOT snapshots) before pivoting to the far cheaper diagnostic -- inspecting the secrets file's keys, which is where the defect was visible immediately.

### 2. Testing Approach
Strong: the F119-b class is now a FAILING test (`msix_config_test.dart` rejects space/empty secrets keys), and the `--print-env` probe gives the release process a compiled-truth check the prior log-only Step 4.0 lacked. The version-consistency gate earned its keep -- it caught the missed `0.5.5` literal in `test-background-scan-skip.ps1` during the bump. One recurring test-infra pain: `flutter test` at default concurrency intermittently drops isolate connections ("Connection closed before test suite loaded") on this machine under repeated-run load; files pass in isolation and at `--concurrency=4`. Worth a standing lower default for local full-suite runs.

### 3. Effort Accuracy
Hotfix, so no pre-estimate to compare against; per CODING_VELOCITY the F119-b Item should be logged (~90-180m band was reasonable for the deep-debug + rebuild + release). Actuals to be backfilled to the Coverage Ledger.

### 4. Planning Quality
No up-front plan (emergency hotfix); the Phase 3 plan was written retroactively at Harold's request. The retroactive plan maps cleanly to what happened. The one planning-quality miss the hotfix EXPOSED is upstream: neither F119 (Sprint 47) nor F119-b caught the OTHER at plan time, because the acceptance criterion was "build log shows APP_ENV=prod" rather than "the compiled build runs as prod" -- a log check, not a behavior check. Step 4.0 is now behavior-based.

### 5. Model Assignments
Opus was correct for F119-b -- the first hypothesis (dart-define/from-file ordering) was wrong and required tracing flutter's `extractDartDefines` source, the msix arg converter, AND the actual JSON to land on the space-in-key cause. A cheaper tier would likely have stopped at the plausible-but-wrong first hypothesis.

### 6. Communication
Good on narrating the diagnosis and reconciling branch state before destructive ops. The weak point mirrors Category 1: I repeatedly proposed/started the branch-off-develop path that Harold has corrected 5 times. The memory now makes his directive override the old recipe explicitly.

### 7. Requirements Clarity
Harold's screenshots (the `[DEV]` title bar, the Store install identity) were decisive -- they turned "the build might be dev" into "the certified Store package IS dev", which redirected me away from a wrong-installer theory. His pointed question "if the version is in a file, why do tests hardcode it?" produced a real fix (PS1 derive-from-pubspec) plus a backlog item.

### 8. Documentation
CHANGELOG, STORE_RELEASE_PROCESS (Step 2 + Step 4.0), master plan Store-status, and this plan+retro all updated. Memory added: `project_f119b_secrets_spacekey`, `feedback_yes_no_questions`, corrected `feedback_next_branch_on_merge`. New backlog cards: F-VERSION-DERIVE, F-WINSTORE-ASSETS (carried), F-PRECHECK, F-COPILOT-INSTR.

### 9. Process Issues
The dominant process issue is the branch-from-feature-vs-develop recurrence (5th correction). Memory alone has not stopped it; the correction now explicitly frames Harold's directive as overriding the older develop-based recipe, which should help. Second: I asked Harold an ambiguous yes/no question (clean-the-file "or you do it") -- fixed via `feedback_yes_no_questions`.

### 10. Risk Management
Handled well where it counted: the whole point of the `--print-env` probe is to convert "trust the build log" into "prove the compiled build" BEFORE the Store sees it -- and it did (APP_ENV=prod confirmed pre-submission). Secrets were backed up before cleaning and kept gitignored. The residual risk is that 0.5.6 is now IN CERTIFICATION and not yet verified live; a post-cert Store-download check remains.

### 11. Next Sprint Readiness
Clean. develop == main (post-merge, 0 divergence), working tree clean, 0.5.6 submitted. Ready for Phase 1 Backlog Refinement for the next sprint. Open threads that fold into it: F33-PROD + BUG-DECODE (Sprint 48 candidates deferred earlier), CI_* secrets, F-VERSION-DERIVE, F-WINSTORE-ASSETS, F-PRECHECK, F-COPILOT-INSTR, and (on 0.5.6 cert PASS) the Android/Google Play track off HOLD.

### 12. Architecture Maintenance
No architectural change. `--print-env` is a small additive diagnostic entry point in `main.dart`; the secrets gate is a policy test. No ADR needed. F-VERSION-DERIVE (backlog) is the one item that, if taken, touches a small architecture decision (single compiled version constant) -- flagged there.

### 13. Minor Function Updates for the Next Sprint Plan (carry-ins)
Carry-ins for the next sprint's Phase 1: F33-PROD prod-DB apply (gated on BUG-DECODE), the 5 CI_* GitHub repo secrets, and the F108 Android-device dep-bump retest. These fold naturally once 0.5.6 is live and the Android track opens.

### 14. Function Updates for the Future Backlog
Added this sprint: **F-VERSION-DERIVE** (derive the app version at runtime instead of hardcoding it in 6 production log-filename sites -- Harold's point). Also standing: F-PRECHECK (pre-PR self-review for recurring Copilot classes) and F-COPILOT-INSTR (audit copilot-instructions for more by-design suppressions), both added during Sprint 47 close-out.

---

## Improvement Decisions

Lightweight hotfix retro -- improvements already applied in-flight this sprint (secrets gate, `--print-env` probe, Step 4.0 rewrite, PS1 derive-fix, memory corrections). No separate Step 5/6 improvement-proposal round for this hotfix; the F-VERSION-DERIVE backlog card captures the one deferred improvement.

---

## CORRECTION ADDENDUM (2026-07-21, Sprint 49 F119-c)

**The F119-b causal claim in this retrospective is WRONG.** The Store-installed `0.5.6` (built with the cleaned secrets) STILL showed the `[DEV]` window title. Root cause of the `[DEV]` title on BOTH 0.5.5 and 0.5.6 is **F119-c**: the native window title is compiled from the `SPAMFILTER_APP_ENV` CMake definition, sourced (Sprint 37 F52 design) ONLY from an OS environment variable that the `msix:create` Store path never set -- CMake defaulted `"dev"` and baked the `[DEV]` title into the native runner while the Dart side was correctly prod (evidence that was visible at the time: the 0.5.5 About text had no `[DEV]` suffix and the Store app used the prod data dir). The F119-b secrets cleanup + gate remain valid hygiene, but the "space-key dropped APP_ENV and shipped the dev build" conclusion was not correct for 0.5.5. The Dart-side `--print-env` proof on 0.5.6 was real but covered only one of the two independently-compiled surfaces. Fix + both-sides probe: see `docs/sprints/SPRINT_49_PLAN.md` (F119-c) and the corrected `STORE_RELEASE_PROCESS.md` Step 4.0. Lesson recorded in memory: verify every independently-compiled surface; a single-side compiled check is not proof.
