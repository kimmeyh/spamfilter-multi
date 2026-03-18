# Sprint 21 Plan

**Sprint**: Sprint 21 - Production/Development Side-by-Side Builds (ADR-0035)
**Date**: March 18, 2026
**Branch**: `feature/20260318_Sprint_21`
**Base**: `develop`
**Estimated Total Effort**: ~6-8h

---

## Sprint Goal

Implement environment-aware app identity so production (main branch) and development (feature/develop) builds can coexist on the same Windows machine with separate data directories, Task Scheduler tasks, and single-instance mutexes.

---

## Tasks

### Task A: Repository and Version Setup (Phase 0)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~1h
**Model**: Haiku
**Value**: This establishes the version differentiation and secrets separation needed for all subsequent tasks.

**Key Changes**:
- Bump `pubspec.yaml` version to `0.5.1` on develop (main stays `0.5.0`)
- Create `secrets.prod.json.template` (copy structure from `secrets.dev.json.template`)
- Add `secrets.prod.json` to `.gitignore`
- Document production worktree setup instructions

**Acceptance Criteria**:
- [ ] develop branch at version `0.5.1`, main at `0.5.0`
- [ ] `secrets.prod.json.template` exists with placeholder values
- [ ] `secrets.prod.json` in `.gitignore`

**Risks**: Low - configuration only

---

### Task B: Core Infrastructure - AppEnvironment and AppPaths (Phase 1)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~2-3h
**Model**: Sonnet
**Value**: This is the core change that enables all environment separation.

**Key Changes**:
- Create `AppEnvironment` class that reads `APP_ENV` from `String.fromEnvironment`
- Values: `prod` or `dev` (default: `dev`)
- Expose: `isDev`, `isProd`, `displaySuffix`, `dataDirSuffix`, `taskName`, `mutexName`
- Update `AppPaths` to append `_Dev` to data directory when `APP_ENV=dev`
- Update `WindowsTaskSchedulerService` task name to include environment suffix
- Update `BackgroundScanWindowsWorker` log file name with environment prefix
- Update window title in `main.dart` to show `[DEV] vX.Y.Z` for dev builds
- Update About screen in `settings_screen.dart` to show environment indicator

**Acceptance Criteria**:
- [ ] `AppEnvironment` class reads `APP_ENV` and provides environment-aware values
- [ ] Dev builds use `MyEmailSpamFilter_Dev` data directory
- [ ] Prod builds use `MyEmailSpamFilter` data directory (unchanged)
- [ ] Window title shows `[DEV] v0.5.1` for dev builds
- [ ] About screen shows `v0.5.1 [DEV]` for dev builds
- [ ] Task Scheduler task name includes `_Dev` suffix for dev builds
- [ ] Background scan log includes `dev_` prefix for dev builds

**Risks**: Medium - touches AppPaths which affects all file I/O. Must not break existing production path resolution.

---

### Task C: First-Run Data Seeding (Phase 1)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~1h
**Model**: Haiku
**Value**: This eliminates manual setup when first running a dev build.

**Key Changes**:
- On first launch in dev environment, check if dev data directory has a database
- If empty and production database exists, copy `spam_filter.db` from production directory
- Copy credentials directory if it exists
- Create `.dev_seeded` marker to prevent re-seeding
- Log seeding activity

**Acceptance Criteria**:
- [ ] First dev launch copies production DB automatically
- [ ] Credentials copied from production directory
- [ ] Seeding only happens once (marker file)
- [ ] Seeding logged for troubleshooting
- [ ] No seeding if production DB does not exist (fresh install)

**Risks**: Low - one-time file copy with marker

---

### Task D: Build Script Updates (Phase 2)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~1h
**Model**: Haiku
**Value**: This makes the environment selection easy and automatic for developers.

**Key Changes**:
- Add `-Environment` parameter to `build-windows.ps1` (values: `dev`, `prod`; default: `dev`)
- Pass `--dart-define=APP_ENV={env}` to `flutter build` and `flutter run`
- Select correct secrets file: `secrets.dev.json` for dev, `secrets.prod.json` for prod
- Update `build-with-secrets.ps1` if applicable

**Acceptance Criteria**:
- [ ] `.\build-windows.ps1` builds dev by default
- [ ] `.\build-windows.ps1 -Environment prod` builds prod
- [ ] Correct secrets file used per environment
- [ ] `APP_ENV` dart-define passed to Flutter

**Risks**: Low - script parameter addition

---

### Task E: Single-Instance Mutex (Phase 3)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~1-2h
**Model**: Sonnet
**Value**: This prevents accidental duplicate instances within the same environment while allowing cross-environment coexistence.

**Key Changes**:
- Add named mutex creation in `main.cpp` (Windows runner)
- Mutex name: `Global\MyEmailSpamFilter_{Environment}`
- Read environment from `--dart-define` via command line args or environment variable
- If mutex already held: show message box, bring existing window to front, exit
- Allow different environments to run simultaneously (different mutex names)

**Acceptance Criteria**:
- [ ] Second launch of same environment shows error and exits
- [ ] Production and development can run simultaneously
- [ ] Mutex released on app exit
- [ ] Mutex name includes environment identifier

**Risks**: Medium - C++ changes to Windows runner, must handle edge cases (crash without releasing mutex)

---

### Task F: Documentation (Phase 4)

**Issue**: [#189](https://github.com/kimmeyh/spamfilter-multi/issues/189)
**Estimated Effort**: ~1h
**Model**: Haiku
**Value**: This ensures the workflow is documented for future reference.

**Key Changes**:
- Update CLAUDE.md: production/development build commands, worktree setup
- Update DEVELOPER_SETUP.md: side-by-side workflow
- Document version bumping process (when to bump patch on develop)
- Document production worktree maintenance (git pull, rebuild after main updates)

**Acceptance Criteria**:
- [ ] CLAUDE.md has production build instructions
- [ ] DEVELOPER_SETUP.md has side-by-side workflow
- [ ] Version bumping process documented

**Risks**: Low - documentation only

---

## Execution Order

1. **Task A** (version + secrets setup - foundation)
2. **Task B** (core infrastructure - AppEnvironment, AppPaths, UI)
3. **Task C** (data seeding - depends on AppPaths from Task B)
4. **Task D** (build scripts - depends on APP_ENV from Task B)
5. **Task E** (mutex - independent but test after B/D)
6. **Task F** (documentation - last)

---

## Sprint Scope Notes

- **Total estimated effort**: ~6-8h across 6 tasks
- **Single issue**: All tasks under #189
- **ADR**: ADR-0035 (accepted)
- **Dependencies**: None external
- **Post-sprint**: Create production worktree and first production build
