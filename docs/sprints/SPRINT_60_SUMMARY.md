# Sprint 60 Summary

**Dates**: 2026-08-15 to 2026-08-16
**Branch**: `feature/20260815_Sprint_60` | **PR**: #335 -> develop
**Scope**: F160 (skipped-tests audit, Issue #328), F156 (full Android walk-through, Issue #329),
F157 (gradle/minSdk study + implement, Issue #330), F158 (Android CI job, Issue #331), F159
(metadata gates, Issue #332), F143 (touch selection, Issue #334), F144 (Android background-scan
re-evaluation, Issue #333); F166 (Scan Results header redesign, Issue #336) added mid-sprint per
Harold's plan-then-execute steering. Same-window context: 0.9.0.0 / Submission 16 uploaded to
Partner Center and in certification (Step 7 release close-out triggers on certification).

## What Shipped

- **F156 (headline)**: full Android walk-through that did exactly what it was chartered to do --
  found real Android-only failures in shared code. Two CRITICAL silent-failure bugs fixed:
  (1) Android's SQLiteDatabase rejects value-returning PRAGMAs via `execSQL`, so `busy_timeout`
  and WAL were silently absent and every live scan failed (fixed with `rawQuery`, works on FFI
  too); (2) `scan_results` has an FK to `accounts`, and the only code creating the accounts row
  was the WINDOWS background worker -- Windows masked the shared gap for months while Android
  persisted NOTHING from any scan (fixed in the shared path, `EmailScanProvider._ensureAccountRow`;
  proven by on-device DB forensics: adb run-as WAL-safe pull + sqlite3). The regression test
  seeds NO accounts row -- every sibling test pre-created one, which is why the class never
  showed in the suite.
- **F160**: 29-skipped-test decision table (purpose / why skipped / recommendation per test);
  Harold approved all recommendations -- 3 discontinued tests deleted (29 -> 26 skips), 11
  update-to-working verdicts registered as F163, 15 special-purpose keeps documented.
- **F157**: the Flutter migrator's gradle change adopted as `minSdk = maxOf(flutter.minSdkVersion, 23)`
  -- stable against re-migration, tracks Flutter's floor, preserves the F108 API-23 requirement;
  the watch-item is retired.
- **F158**: Android debug-build CI job (temurin 17, committed CI-safe `google-services.ci.json`
  stub with fake values -- the F150 class can no longer break silently).
- **F159**: version-consistency net extended -- `msix_version` must equal pubspec X.Y.Z + `.0`
  in both the policy test and the PowerShell checker.
- **F143**: touch-adapted multi-select on Review No Rule Items (long-press enters selection,
  tap toggles while active; desktop replace-single semantics pinned unchanged). Platform read
  via `Theme.of(context).platform` to give tests a seam.
- **F144**: Android background-scan re-evaluation -- verdict: full Windows-mirroring WorkManager
  scheduler is feasible (~3-5h, registered as F161 with POST_NOTIFICATIONS); the unwired
  pre-architecture code (4 classes + `workmanager` dep) DELETED; `ScanFrequency` extracted.
- **F166**: Scan Results header redesign per Harold's spec -- one single-select filter dropdown
  (No Rule default, mode-adaptive labels, live counts) + Folders chip on one line; inline
  "Scan complete"; simplified no-rule banner; compact-width (<600px) header folds into the
  scrolling list; email popup clamped to the window and full-width on phones.
- **MV fixes across 4 rounds**: dead filter-banner X, EmptyState overflow, demo scan mislabeled
  "Background" in Scan History (three-way Manual/Demo/Background label), plus the two CRITICAL
  fixes above. Round 4's "Review No Rule Items empty" was proven CORRECT behavior via a second
  DB pull (the items belonged to the Demo scan, which never feeds Review on any platform).
- **Tooling**: `start-emulator.ps1` (right SDK, netsimd note); storage pre-flight in
  `build-with-secrets.ps1`; account-preserving deploys standardized on `adb install -r`.

## Verification

- Full suite at close: **1,859 passed / 26 skipped / 0 failed**; on-device integration 32/32;
  `flutter analyze` clean throughout; every fix and gate mutation-verified (including one
  worthless popup test caught green-against-broken-code and tightened until it reproduced).
- Manual Validation: complete (Harold, 2026-08-16, 4 rounds) -- Android Scan Results, Live Scan,
  and No Rules pages approved.

## Notable Process Events

- The stale-app incident: Harold's first Android validation round exercised an ANCIENT
  `com.example.spamfiltermobile` install left on the AVD -- every observed "divergence" was
  archaeology, not current code. Verify-the-install-first is now written into F162.
- An emulator uninstall wiped Harold's saved account (keystore-backed secure storage does not
  survive uninstall); deploys switched permanently to `adb install -r`.
- Retro: Category 1 "Good" with two python-on-Windows tooling errors (cp1252 stdout; subprocess
  cannot resolve `.bat` shims) -- root-caused and saved as a standing memory rule (IMP-1);
  Categories 2-12 "Very Good"; IMP-2/3/4 declined by Harold.

## Backlog Movement

- NEW: F161 (Android scheduler), F162 (parity audit + ADR), F163 (skipped-test remediation),
  F164 (Android scan performance), F165 (cross-device rules sharing + hosted tier), F167
  (Android Help text per parity ADR, retro Category 14).
- DONE and pruned: F143, F144, F156, F157, F158, F159, F160, F166.
