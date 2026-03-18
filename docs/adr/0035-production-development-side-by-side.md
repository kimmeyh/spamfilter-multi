# ADR-0035: Production and Development Builds Side-by-Side on Windows

## Status

Proposed

## Date

2026-03-18

## Context

The developer runs the production app (built from `main` branch) with background scanning enabled on their Windows 11 development machine. Simultaneously, they need to build, test, and run development builds from `feature/*` and `develop` branches. Currently this creates several conflicts:

### Current Problems

1. **Shared data directory**: Both builds use `C:\Users\{username}\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\`. Development builds modify the same SQLite database, credentials, and rules as the production app.

2. **Background scan interference**: The Windows Task Scheduler task (`SpamFilterBackgroundScan`) stores a single executable path. Whichever build runs last overwrites the task to point to its executable. Development builds may register the task pointing to a debug build that gets deleted on `flutter clean`.

3. **No single-instance mutex**: Nothing prevents both production and development executables from running simultaneously, risking SQLite database corruption from concurrent writes.

4. **Same executable name**: Both builds produce `spam_filter_mobile.exe`, making it impossible to distinguish in Task Manager or Task Scheduler.

### Industry Best Practices

**Android/iOS**: Use application ID suffixes (`.debug`, `.dev`) via build flavors. This gives each build variant a separate package name, separate data directory, and separate app icon. Both versions install side-by-side on the same device.

**Flutter Flavors**: Flutter's flavor system supports multiple entry points (`main_dev.dart`, `main_prod.dart`), different app names, different icons, and different configurations per environment.

**Windows Desktop Apps**: Use named mutexes with environment-specific names (e.g., `Global\MyApp_Production`, `Global\MyApp_Development`) to prevent same-environment collisions while allowing cross-environment coexistence.

## Decision

Implement **environment-aware app identity** using Flutter's `--dart-define` mechanism to differentiate production and development builds. Each environment gets:

1. **Separate data directory** (different AppData subfolder)
2. **Separate Task Scheduler task name** (different scheduled task per environment)
3. **Separate background scan log** (different log file per environment)
4. **Visual differentiation** (different window title, optional debug banner)
5. **Single-instance mutex per environment** (prevent duplicate instances within same environment)

### Environment Configuration

| Property | Production (main) | Development (feature/develop) |
|----------|-------------------|-------------------------------|
| App data directory | `MyEmailSpamFilter\MyEmailSpamFilter\` | `MyEmailSpamFilter\MyEmailSpamFilter_Dev\` |
| Window title | MyEmailSpamFilter | MyEmailSpamFilter [DEV] v{VERSION} |
| Task Scheduler task | `SpamFilterBackgroundScan` | `SpamFilterBackgroundScan_Dev` |
| Background scan log | `background_scan_v{VERSION}.log` | `background_scan_dev_v{VERSION}.log` |
| Mutex name | `Global\MyEmailSpamFilter_Production` | `Global\MyEmailSpamFilter_Development` |
| Database | `spam_filter.db` | `spam_filter.db` (in separate directory) |
| About screen | v0.5.0 | v0.5.0 [DEV] |

### Version Number Strategy

**Production version**: Follows semver from `pubspec.yaml` (e.g., `0.5.0+1`). Only updated on releases merged to main.

**Development version**: Same `pubspec.yaml` version but with `[DEV]` suffix displayed in UI. The version number in pubspec.yaml is updated on the develop/feature branch when a new release is being prepared, but the `[DEV]` indicator makes it clear this is not a released build.

**Why not separate version numbers**: Both environments share the same `pubspec.yaml`. Maintaining separate version files adds complexity. The environment indicator (`[DEV]`) is sufficient to distinguish builds visually. The separate data directories prevent version-related DB migration conflicts.

**DB schema version isolation**: Each environment has its own database file in its own data directory. If the dev branch upgrades the DB schema (e.g., v2 -> v3), it only affects the dev database. The production database remains at the production schema version. This eliminates cross-environment schema conflicts.

### Repository Directory Structure

The production build should use a **separate checkout** (git worktree) so that switching branches for development does not overwrite the production executable:

```
D:\Data\Harold\github\
├── spamfilter-multi\                    # Primary checkout (develop/feature branches)
│   └── mobile-app\build\windows\...    # Development build output
│
└── spamfilter-multi-prod\              # Git worktree (main branch only)
    └── mobile-app\build\windows\...    # Production build output
```

**Setup**:
```powershell
# One-time: Create production worktree from main branch
cd D:\Data\Harold\github\spamfilter-multi
git worktree add ../spamfilter-multi-prod main
```

**Benefits**:
- Production executable path is stable (never overwritten by dev builds)
- Task Scheduler always points to the production worktree path
- `flutter clean` on dev branch does not delete production executable
- `git pull` in production worktree updates main branch independently

### Implementation Approach

**Option A: `--dart-define` flag** (Recommended)

Pass `APP_ENV=dev` or `APP_ENV=prod` at build time:

```powershell
# Production build (from main branch worktree)
cd D:\Data\Harold\github\spamfilter-multi-prod\mobile-app\scripts
.\build-windows.ps1 -Environment prod

# Development build (from feature/develop branch)
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts
.\build-windows.ps1    # defaults to dev
```

The app reads `String.fromEnvironment('APP_ENV', defaultValue: 'dev')` and adjusts:
- `AppPaths` data directory suffix
- Window title (includes `[DEV]` and version)
- Task Scheduler task name
- Mutex name
- Log file name
- About screen display

**Advantages**:
- No code duplication (single main.dart)
- Build scripts already use `--dart-define-from-file=secrets.dev.json`
- Easy to extend with additional environments (staging, QA)
- Works for both `flutter run` and `flutter build`

**Option B: Separate entry points** (main_prod.dart / main_dev.dart)

Create separate main files that configure the environment before calling shared initialization. More explicit but requires maintaining two entry points.

**Option C: Build flavors** (Android-style)

Flutter flavors work well for Android/iOS but have limited Windows support as of 2026. Not recommended for Windows-only differentiation.

### Chosen: Option A (`--dart-define`)

Option A is simplest, requires minimal code changes, and integrates with existing build scripts.

## Consequences

### Positive

- Production background scan runs uninterrupted during development
- Development builds cannot corrupt production database
- Both versions can run simultaneously on the same machine
- Clear visual indication of which version is running (window title)
- Development testing does not affect production scan history or credentials
- Easy rollback: just stop using the `APP_ENV` flag (defaults to dev)

### Negative

- Development builds start with empty database (no rules, no accounts) -- requires one-time setup or import from production export
- Two sets of credentials to manage (production and development accounts)
- Build scripts need updating to pass `APP_ENV` flag
- Developers must remember to use correct flag for production builds

### Neutral

- Production credentials remain isolated from development experiments
- Background scan logs are separate, making debugging clearer
- Database schema changes in development do not affect production until merged to main

## Implementation Plan

### Phase 0: Repository Setup (One-Time)
0. Create production git worktree: `git worktree add ../spamfilter-multi-prod main`
1. Build production release in worktree: `cd ../spamfilter-multi-prod/mobile-app/scripts && .\build-windows.ps1 -Environment prod`

### Phase 1: Core Infrastructure
2. Add `AppEnvironment` class that reads `APP_ENV` from `--dart-define`
3. Update `AppPaths` to use environment-aware data directory suffix
4. Update `WindowsTaskSchedulerService` to use environment-aware task name
5. Update `BackgroundScanWindowsWorker` to use environment-aware log file name
6. Add environment indicator to window title (`[DEV]` suffix)
7. Update About screen to show environment indicator with version

### Phase 2: Build Script Updates
8. Update `build-windows.ps1` to accept `-Environment` parameter (default: `dev`)
9. Production build command: `.\build-windows.ps1 -Environment prod`
10. Development build command: `.\build-windows.ps1` (defaults to dev)
11. Ensure `--dart-define=APP_ENV={env}` is passed to both `flutter build` and `flutter run`

### Phase 3: Single-Instance Mutex
12. Add named mutex in Windows runner (`main.cpp`) using environment-specific name
13. Show message and bring existing window to front if mutex already held
14. Mutex name includes environment: `Global\MyEmailSpamFilter_{Environment}`

### Phase 4: Documentation
15. Update CLAUDE.md with production/development build instructions and worktree setup
16. Update DEVELOPER_SETUP.md with side-by-side workflow
17. Document production worktree maintenance (git pull, rebuilding after main updates)

## References

- ADR-0012: AppPaths Platform Storage Abstraction (data directory resolution)
- ADR-0014: Windows Background Scanning Task Scheduler (task naming)
- ADR-0026: Application Identity and Package Naming (app identity)
- [Flutter Flavors Documentation](https://docs.flutter.dev/deployment/flavors)
- [Android Build Variants](https://developer.android.com/build/build-variants)
- [Windows Single Instance with Mutex](https://learn.microsoft.com/en-us/archive/technet-wiki/34423.create-a-single-instance-desktop-application)
