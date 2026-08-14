# Sprint 48 Summary

**Branch**: `feature/20260720_Sprint_48`
**PR**: [#274](https://github.com/kimmeyh/spamfilter-multi/pull/274)
**Issues**: F119-b (no dedicated GitHub issue found in PR/commit history; tracked via retro/plan docs and CHANGELOG)
**Dates**: 2026-07-20 (single-day emergency hotfix)
**Retrospective**: `docs/sprints/SPRINT_48_RETROSPECTIVE.md` (lightweight, Claude Code Development Team only, per Harold's directive; contains a 2026-07-21 correction addendum -- see below)

**Note on this document**: This SUMMARY was backfilled during the Sprint 57 documentation audit (2026-08-14). The PLAN and RETROSPECTIVE already existed with substantial real content; this document synthesizes them plus the PR record. No new research beyond those sources was performed.

---

## Outcome

| Measure | Value |
|---|---|
| Tests | 1763 pass / 29 skip (full suite green) |
| Analyzer | Clean |
| Version | `0.5.5` -> `0.5.6` (Partner Center rejects a reused version number) |
| Windows build | Rebuilt prod MSIX; `--print-env` probe confirmed `APP_ENV=prod` (Dart-side only -- see correction) |
| Release | 0.5.6 submitted to Partner Center for certification (Harold, 2026-07-20) |
| Manual Validation | Not separately recorded beyond the compiled `--print-env` proof |
| Carry-forward | 4 stranded Sprint 47 post-merge commits cherry-picked onto the Sprint 48 branch |

## Scope

Sprint 48 was an emergency hotfix, not a pre-planned sprint (SPRINT_STOPPING_CRITERIA Criterion 4: critical bug found). It was triggered when Harold's manual test of the LIVE Store `0.5.5` build showed it still running as `[DEV]`, despite the Sprint 47 F119 fix. Work began immediately rather than through Phases 1-3; the Phase 3 plan document was written retroactively at Harold's request.

| Task | Feature | Result |
|---|---|---|
| 1 | F119-b | Root cause diagnosed and fixed: `secrets.prod.json`/`secrets.dev.json` contained a JSON key with spaces, which corrupted the `--dart-define-from-file` stream and silently dropped `APP_ENV=prod`. Secrets cleaned to credential-keys-only; `msix_config_test.dart` gate added to reject malformed secrets keys; `main.dart --print-env` compiled-truth probe added; `STORE_RELEASE_PROCESS.md` Step 4.0 rewritten to require the compiled check, not just the build log. |
| 2 (opportunistic) | Version bump | `0.5.5` -> `0.5.6` across all gated version-literal sites, including a Harold-caught hardcoded version in `test-background-scan-skip.ps1` (now derives from `pubspec.yaml`); logged as backlog item F-VERSION-DERIVE to extend the pattern to 6 production log-filename sites. |
| 3 (carried) | F-WINSTORE-ASSETS, stale-doc fix, 0.5.5-submission tracking | Cherry-picked from the merged Sprint 47 branch where they had been stranded post-merge. |

## What shipped

**F119-b root cause and fix.** `--dart-define-from-file` converts every JSON key in the secrets file into a `key=value` dart-define; a key containing spaces (`"comment OR try this"`) corrupted the resulting dart-define stream and silently dropped `APP_ENV=prod`, so `String.fromEnvironment` fell back to `dev`. This was independent of the Sprint 47 F119 `windows_build_args` key-name fix, and the two defects had masked each other across the 0.5.4 and 0.5.5 releases. The build log still showed the correct `--dart-define=APP_ENV=prod` command, so the pre-existing log-only Step 4.0 release check passed while the compiled build was actually dev.

**Hardening.** Two durable guards were added so the class of defect cannot silently recur: a policy test (`msix_config_test.dart`) that fails the build if any `secrets.*.json` (excluding example/template/backup files) has a key with spaces or an empty name, and a `--print-env` flag on `main.dart` that prints the compiled `APP_ENV`/`displaySuffix`/`dataDirSuffix`/`windowTitle` and exits, giving the release process a way to verify the compiled artifact rather than trust the build log.

**Release.** PR #274 merged to `develop` then to `main`; 0.5.6 was submitted to Partner Center for certification on 2026-07-20.

## Correction discovered in Sprint 49 (F119-c)

The Sprint 48 retrospective carries a dated correction addendum (2026-07-21): the F119-b causal claim, while a real and valid fix, was **not the actual cause of the `[DEV]` title on the Store build**. The Store-installed 0.5.6 (built with the cleaned secrets) still showed `[DEV]` in the window title. The true root cause, found in Sprint 49 as F119-c, was that the native window title is compiled from a `SPAMFILTER_APP_ENV` CMake definition sourced only from an OS environment variable that the `msix:create` Store build path never set -- CMake defaulted to `"dev"` and baked `[DEV]` into the native runner while the Dart side was correctly `prod`. The Sprint 48 `--print-env` proof was real but covered only the Dart-side compiled surface, not the independently-compiled native surface. The F119-b secrets cleanup and gate remain valid, correct hygiene fixes; they were simply not sufficient on their own to fix the visible symptom. See `docs/sprints/SPRINT_49_PLAN.md` (F119-c) for the follow-up fix.

## Retrospective format note

Per Harold's 2026-07-20 directive, Sprint 48's retrospective used a lightweight format: only the Claude Code Development Team role addressed all 14 categories; the Product Owner/Scrum Master/Lead Developer roles were explicitly waived for this hotfix rather than left silent.

## Lessons worth carrying

1. **A build-log check is not a compiled-behavior check.** Both 0.5.4 and 0.5.5 shipped broken while their build logs showed the correct dart-define command; the fix was to assert against the compiled artifact (`--print-env`), not the log.
2. **A single-surface compiled check is not proof of the whole artifact.** The Dart-side `--print-env` probe was correct but blind to the separately-compiled native CMake surface -- the Sprint 49 correction is the direct lesson.
3. **Version-consistency and policy gates pay for themselves during a bump.** The existing version-consistency gate caught a stale `0.5.5` literal in a support script during the 0.5.6 bump.
