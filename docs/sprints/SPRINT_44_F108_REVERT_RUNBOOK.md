# Sprint 44 F108 -- Dependency Upgrade Revert Runbook

**Purpose**: F108 upgrades three security-relevant dependencies, each a Class-2 change. This runbook lets you revert **any one, two, or all three** upgrades in isolation **without** touching the other Sprint 44 work (F107 ADR/ARSD, F109 background-deferral visibility) or any earlier sprint.

**Why this is safe to revert piecemeal**: each dependency upgrade is its own commit. F107 and F109 landed in **earlier, separate commits** (F107 = `ffc7aba`, F109 = `5dd7dce`), so a `git revert` of any F108 commit cannot affect them.

---

## Pre-upgrade pinned versions (the rollback target)

Base commit before any F108 upgrade: **`5dd7dce`**.

| Dependency | pubspec.yaml constraint (before) | resolved (before) |
|------------|----------------------------------|-------------------|
| `flutter_secure_storage` | `^9.0.0` | `9.2.4` |
| `flutter_appauth` | `^8.0.1` | `8.0.3` |
| `workmanager` | `^0.5.2` | `0.5.2` |
| (transitive) `flutter_secure_storage_windows` | -- | `3.1.2` |
| (transitive) `flutter_appauth_platform_interface` | -- | `8.0.0` |

Android `minSdk` before: `flutter.minSdkVersion` (= 21 on Flutter 3.38).

---

## The three F108 commits (fill in SHAs as each lands)

| # | Dependency | Commit SHA | Touches |
|---|------------|-----------|---------|
| 1 | `flutter_appauth` 8.0.3 -> 12.0.2 | **`0a8b9d4`** | pubspec.yaml/lock only (no code change) |
| 2 | `workmanager` 0.5.2 -> 0.9.0+3 | **`a9524c0`** | pubspec.yaml/lock only (no code change) |
| 3 | `flutter_secure_storage` 9.2.4 -> 10.3.1 | **`667075a`** | pubspec.yaml/lock + `secure_token_store.dart` + `secure_credentials_store.dart` (drop `encryptedSharedPreferences`) + `android/app/build.gradle.kts` (`minSdk = 23`) |

**Example -- revert ONLY secure_storage (the highest-risk one), keep the other two:**
```powershell
git revert --no-edit 667075a
cd mobile-app; flutter pub get; flutter analyze; flutter test
```
appauth (`0a8b9d4`) and workmanager (`a9524c0`) are untouched, as are F107 (`ffc7aba`) and F109 (`5dd7dce`).

---

## Revert procedure (per dependency)

### Option A -- clean `git revert` (preferred; preserves history)

Revert ONE dependency without disturbing the others:

```powershell
# From the sprint branch (or a hotfix branch off it):
git revert --no-edit <SHA-of-the-one-to-revert>
cd mobile-app
flutter pub get
flutter analyze
flutter test
```

- `git revert` of commit #1 or #2 cleanly restores that one dep (they are pubspec-only).
- `git revert` of commit #3 also restores the 2-file `encryptedSharedPreferences` code and the Android `minSdk` line, because they were all in that single commit.
- Revert order does not matter for #1/#2 (independent). If reverting #3 alongside others, do #3 last only if a later commit textually depends on its lines (none should).

### Option B -- manual pin-back (if a revert conflicts)

If history has moved and a revert conflicts, pin the constraint back in `pubspec.yaml` and re-resolve:

```powershell
# Edit mobile-app/pubspec.yaml back to the "before" constraint, e.g.:
#   flutter_secure_storage: ^9.0.0
#   flutter_appauth: ^8.0.1
#   workmanager: ^0.5.2
# For secure_storage also restore in lib/:
#   - secure_token_store.dart + secure_credentials_store.dart:
#       AndroidOptions(encryptedSharedPreferences: true)
#   - android/app/build.gradle.kts: minSdk = flutter.minSdkVersion
cd mobile-app
flutter pub get
flutter analyze
flutter test
```

To force an EXACT old resolved version (not just the caret range), add a temporary
`dependency_overrides:` block, e.g. `flutter_secure_storage: 9.2.4`, run `flutter pub get`, then remove the override once the lock is regenerated.

---

## Post-revert verification (any revert)

1. `flutter pub get` -- clean resolve, no error.
2. `flutter analyze` -- 0 issues.
3. `flutter test` -- full suite green.
4. `flutter build windows --dart-define-from-file=secrets.dev.json` -- builds.
5. If `flutter_secure_storage` or `flutter_appauth` was reverted: manual-retest the affected auth path (Windows Gmail OAuth loopback / AOL IMAP sign-in; Android Gmail sign-in).
6. If `workmanager` was reverted: re-verify per-account WorkManager scheduling on Android.

---

## Notes / gotchas

- **secure_storage 10 auto-migrates Android data** on first run (`migrateOnAlgorithmChange` default true). A revert from 10 -> 9 after users have already run 10 may require those users' secure-storage data to re-migrate; on this app the stored data is OAuth tokens + the DB key, which the app can re-acquire (re-sign-in / re-provision), so a revert is recoverable but may force a re-auth. Flag this if reverting after a prod release.
- **Android `minSdk = 23`** (from 21) drops Android 5.0-5.1 (API 21-22). Reverting #3 restores 21.
- These upgrades do NOT touch the DB schema, so no migration concerns on revert.
