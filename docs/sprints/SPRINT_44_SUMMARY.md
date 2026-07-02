# Sprint 44 Summary

**Sprint 44** (2026-06-26 -- 2026-07-01, merged PR #266)
**Type**: Docs/architecture ratification + UX visibility + dependency hardening
**Branch**: `feature/20260626_Sprint_44`

## Delivered

- **F107** -- Accepted **ADR-0037** (UI/Accessibility Standards; Proposed -> Accepted, standards implemented + in active use) and promoted **ARSD.md** from "1.0 (Draft)" to **1.0 / Accepted**. Docs only.
- **F109** -- surfaced the (correct-but-previously-invisible) **background-scan deferral** state -- scheduled scans pause while the foreground app holds the single-instance mutex (F98 DB-contention protection) -- across THREE surfaces:
  - Settings > Background status line (with the last-deferral time, `intl`-formatted).
  - Scan History info hint.
  - a `status='deferred'` row in `background_scan_log`.
  - **Design (handoff-file, Harold-approved)**: the deferral is detected in the native Windows runner (`main.cpp`) BEFORE any Dart/DB exists, so it appends the event to a handoff file (in the app-support ROOT, NOT `logs/`, to keep the email-derived account id out of the shareable log area -- PR #266 Copilot review); `BackgroundDeferralIngest` reads + clears it on the next foreground launch and inserts the row. NO DB migration.
  - **Incidental**: fixed the stale `main.cpp` `v0.5.3` background-scan log filename (missed by the Sprint 43 F105 bump) -> `v0.5.4`; added `main.cpp` + `live_scan_logger.dart` to the version checklist.
- **F108** -- upgraded three security-relevant dependencies, spike-first, **each in its own revertable commit**:
  - `flutter_appauth` 8.0.3 -> 12.0.2 (no code change).
  - `workmanager` 0.5.2 -> 0.9.0+3 (no code change).
  - `flutter_secure_storage` 9.2.4 -> 10.3.1 (dropped the deprecated `AndroidOptions(encryptedSharedPreferences)`; raised Android `minSdk` 21 -> 23).
  - plus minor drift (logger, path_provider, archive).
  - Per-dependency revert runbook: `docs/sprints/SPRINT_44_F108_REVERT_RUNBOOK.md`.

## Retrospective improvement applied

- **IMP-1** -- a build-failing **version-consistency gate** (`test/policy/version_consistency_test.dart` + `scripts/check-version-consistency.ps1`) asserting every app-version literal in `lib/` + `windows/runner/` + `scripts/` matches `pubspec.yaml`. Catches the silent stale-literal drift class (the F105/main.cpp miss).

## Metrics

- **Tests**: +1692 / ~28 skipped / 0 failed. `flutter analyze`: 0 issues. Windows build: green.
- **Model assignments** (first sprint under IMP-1 cheapest-first): Haiku (F107, F109a/b, main.cpp fix), Sonnet (F109c cross-layer, F108 spike/adopt, IMP-1 gate).
- **Retrospective**: `docs/sprints/SPRINT_44_RETROSPECTIVE.md` (4 roles x 14 categories, all "Very Good", no carry-ins).

## Open follow-up

- **Android-device retest of the F108 bumps** (Gmail sign-in via appauth 12, secure-storage round-trip via secure_storage 10's auto-migration, per-account WorkManager via workmanager 0.9) -- not runnable in the dev session (no emulator). Post-merge verification item; F108 revert runbook covers per-dep rollback if needed.

## PR

- **#266** (merged to develop, 2026-07-01).
