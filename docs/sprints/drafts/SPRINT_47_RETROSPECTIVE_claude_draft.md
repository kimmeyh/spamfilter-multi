# Sprint 47 Retrospective -- Claude Code Development Team DRAFT

**Author**: Claude (Claude Code Development Team role, the 4th role).
**Status**: DRAFT for Step 3 use only. NOT a substitute for Harold's PO/SM/Lead Developer input.
Never written into the official retrospective in place of Harold's words.

Sprint 47 scope (8 items, all delivered): F119 (msix `windows_build_args` key fix +
policy gate + doc correction), F112 (Review-No-Rule entry point everywhere), F113
(provider-keyed new-account defaults), F114 (90-day retention defaults), F115
(selection-bar reorder), F116 (Demo Scan -> Results navigation), F117 (Help footer
app-version), F118 (post-Store-release housekeeping: dev bump 0.5.4 -> 0.5.5 + gradle
untracking). Source: Harold's manual testing of the LIVE Store 0.5.4 build.

---

## Claude Code Development Team feedback -- 14 categories

### 1. Effective while as Efficient as Reasonably Possible
Delivered all 8 items with each committed as its own CHANGELOG-tagged commit; full suite
green (1756 pass / 29 skip), analyze clean. One efficiency loss: during the Phase 6.6
carry-forward I reached for `git stash` instead of the documented "create branch then
commit" flow, which reverted `0Claudedev_prompts.txt` and cost a recovery round. The
process was already in memory; I should have followed it. Otherwise the F112-F118 pass
was continuous with no per-task approval stops.

### 2. Testing Approach
Each behavioral change landed with a test: F119 policy gate (`msix_config_test.dart`),
F113 provider-default folder tests + `getEffectiveFolders` contract update, F114 retention
defaults, F117 footer, F116 demo-nav. F118 surfaced a latent test-fragility class: two
tests hardcoded the versioned log filename (`live_scan_v0.5.4.log`) and broke on the bump;
I made `live_scan_logger_test.dart` derive the version from pubspec so it never drifts
again. The version-consistency gate excludes `test/`, so it could not have caught this --
worth noting as a small coverage gap.

### 3. Effort Accuracy
Measured from git commit timestamps (2026-07-15), not estimated. On-branch coding:
F119 18:09:07->18:21:30 (~12m), F112+F115 ->18:26:00 (~4.5m), F114 ->18:27:51 (~2m),
F117 ->18:33:43 (~6m), F116 ->18:35:37 (~2m), F113 ->18:42:34 (~7m), F118 ->18:57:13 (~15m).
Total on-branch coding ~48 minutes against a 300-570 minute plan -- roughly **6-12x under
estimate**. The estimates were systematically inflated for what were small, well-scoped
UI/config edits. Two corrections to my earlier draft: (a) I wrongly said F118 ran "slightly
over its ~1h estimate" -- its commit delta was ~15m, well UNDER; the stash detour added
rework but the net stayed under the hour. (b) The ~12m F119 commit delta UNDERCOUNTS F119:
its diagnosis, the second-worktree (prod/main) fix, the msix:create verification build, and
the STORE_RELEASE_PROCESS.md correction happened off this branch's timeline and were not
timestamped -- so F119 was the most involved item even though its on-branch edit was small.
Process miss: I did not record these per-task actuals in docs/CODING_VELOCITY.md during
execution (required by the estimating-in-minutes guidance); flagged as a retro improvement.

### 4. Planning Quality
The plan mapped cleanly to Harold's manual-testing feedback items; F119 was correctly
flagged highest-priority because it distorted every other observation (the Store build ran
as dev). One plan defect: the F118 acceptance criterion said "move CHANGELOG entries under
a `[0.5.4]` heading" -- wrong, since 0.5.5 is a dev bump and release headings are created
only at develop->main (user-only). I corrected the criterion in-flight and recorded why.

### 5. Model Assignments
Cheapest-first honored: Haiku for F114/F115/F118 mechanical work, Sonnet for the
multi-surface UI changes (F112/F113/F116/F117), Opus for F119 (root-cause diagnosis across
two worktrees + policy gate). No "why not cheaper" violations noted.

### 6. Communication
Good on the co-lead narration for F119 diagnosis. The weak point was the Phase 6.6
episode: I proposed a stash alternative that Harold had explicitly rejected multiple times
before, then compounded it by narrating "root cause" framing he had to correct. Lesson
reinforced: when memory already prescribes the deterministic step, execute it, do not
invent alternatives.

### 7. Requirements Clarity
Harold's feedback was captured per-screen with screenshots, so requirements were concrete.
The F112 "consolidate into a consistent Review-No-Rule entry point everywhere" theme was
explicitly confirmed before I broadened scope, which was the right echo-the-requirement
move. No ambiguity blocked execution.

### 8. Documentation
CHANGELOG updated per-item (cadence honored). STORE_RELEASE_PROCESS.md corrected in 3
places + new MANDATORY Step 4.0. Master plan updated: Sprint 47 phase group, F118 marked
DONE, "Last Completed Sprint" store outcome corrected to reflect the F119 defect, and the
Android/Google Play promotion trigger recorded. Memory added for the Android-next
direction.

### 9. Process Issues
The stash-instead-of-commit violation (Phase 6.6) is the one real process issue. It is now
covered by memory (`feedback_follow_deterministic_process`), but it recurred despite
existing guidance -- suggesting the memory alone is not a strong enough guard at the
branch-carry-forward moment. Candidate for a hook or a checklist hard-stop.

### 10. Risk Management
The F119 fix carries residual risk: the corrected MSIX has NOT yet been re-released, so the
Store still serves the defective dev build. This is correctly tracked as a pending Harold
action in the master plan + CHANGELOG, and Step 4.0 now forces a prod-vs-dev verification
before any future upload. `secrets.prod.json` (dated Apr 20) verification is also flagged
before re-release.

### 11. Next Sprint Readiness
Clean. Working tree clean, PR #272 draft/mergeable, all pushed. The next major track is
already set (Android/Google Play, per Harold 2026-07-15) and staged in the master plan's
HOLD section with a promotion trigger. Carry-ins from Sprint 46 (F33 prod-DB apply, CI_*
secrets, Copilot round-6 polish) remain open and should be reconciled at Sprint 48 planning.

### 12. Architecture Maintenance
No architectural changes this sprint -- all items were UI/config/housekeeping. F113's
provider-keyed default helper (`providerDefaultFolders`) is a small additive pattern, not
an architecture change; documented in the settings_store doc-comments. No ADR needed. No
ARCHITECTURE.md update required.

### 13. Minor Function Updates for the Next Sprint Plan (carry-ins)
Candidate carry-ins: (a) the F108 Android-device dep-bump retest (blocked on emulator);
(b) F33 prod-DB `--env prod --apply` run (gated on the Copilot round-6 decode-failure fix);
(c) populate the 5 `CI_*` GitHub repo secrets. These fold naturally into the Android track
kickoff.

### 14. Function Updates for the Future Backlog
Candidate: extend the version-consistency gate (or a sibling test) to also catch
hardcoded versioned filenames in `test/` -- the F118 fragility class the current gate
cannot see. Also consider a "Sprint N / Last updated" stale-footer check (already noted as
a stretch idea near F117 in the master plan).
