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

Uses 3-level semver (`MAJOR.MINOR.PATCH`) with patch-level differentiation:

**Production version** (main branch): `0.5.0` -- the release version in `pubspec.yaml`. Only updated when a release is merged to main.

**Development version** (develop/feature branches): `0.5.1` -- always `PATCH+1` ahead of production. This ensures development builds are always distinguishable from production by version number alone. When a release is prepared (develop merged to main), the version becomes the new production version and develop bumps to the next patch.

**Version flow example**:
```
main:    0.5.0  ──────────────────────────>  0.6.0  ──────────>
develop: 0.5.1  -> sprint work -> 0.6.0 PR -> 0.6.1  -> ...
```

**UI display**:
- Production: `v0.5.0` (window title, About screen)
- Development: `v0.5.1 [DEV]` (window title, About screen)

**DB schema version isolation**: Each environment has its own database file in its own data directory. If the dev branch upgrades the DB schema (e.g., v2 -> v3), it only affects the dev database. The production database remains at the production schema version. This eliminates cross-environment schema conflicts.

### Secrets File Strategy

Each environment uses its own secrets file:

- **Production**: `secrets.prod.json` -- production OAuth credentials, API keys
- **Development**: `secrets.dev.json` -- development/testing OAuth credentials, API keys

Both files are excluded by `.gitignore`. The build scripts pass the correct file:
```powershell
# Production
flutter build windows --dart-define-from-file=secrets.prod.json --dart-define=APP_ENV=prod

# Development
flutter run -d windows --dart-define-from-file=secrets.dev.json --dart-define=APP_ENV=dev
```

Initially both files may contain the same credentials (same Google Cloud project). As the app scales, production credentials can be separated (different OAuth client IDs, different Firebase project, etc.).

### First-Run Data Seeding for Development

When the development environment is first created, its data directory is empty (no rules, no accounts, no safe senders). To avoid manual setup:

**One-time seed process** (automated during ADR-0035 implementation):
1. Check if dev data directory is empty (no `spam_filter.db`)
2. If empty, copy production database as seed: `spam_filter.db` -> dev directory
3. Copy production credentials (from Windows Credential Manager or credentials directory)
4. Log: "Development environment seeded from production data"
5. Mark as seeded (`.dev_seeded` marker file) to prevent re-seeding

**Manual alternative**: Use Settings > Data Management > Export from production, then Import in development.

**Important**: After seeding, the dev database is independent. Changes in dev do not affect production, and vice versa.

### User and Account Isolation

**Single OS user, two app environments**: The production and development apps share the same Windows user account but have separate data directories. Each environment maintains its own:
- Email accounts and credentials
- Rules and safe senders database
- Scan history
- App settings

**Multi-user scenarios**: Handled by the operating system, not the app:
- **Windows**: Each OS user has their own `%APPDATA%` directory, so separate Windows user accounts get completely isolated app data automatically
- **Android/iOS**: Device-level isolation (one user per device)
- **No in-app multi-user support needed**: The app manages email accounts (which may belong to different people), but the app itself runs as a single OS user

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

- First-run data seeding copies production DB but credentials may need re-authentication in dev environment
- Two secrets files to maintain (`secrets.dev.json`, `secrets.prod.json`)
- Build scripts need updating to pass `-Environment` parameter
- Developers must remember to bump patch version on develop after each release to main
- Git worktree requires disk space for second checkout

### Neutral

- Production credentials remain isolated from development experiments
- Background scan logs are separate, making debugging clearer
- Database schema changes in development do not affect production until merged to main

## Implementation Plan

### Phase 0: Repository and Version Setup (One-Time)
0. Bump develop branch version to `0.5.1` in `pubspec.yaml` (main stays at `0.5.0`)
1. Create `secrets.prod.json` template (copy from `secrets.dev.json`)
2. Add `secrets.prod.json` to `.gitignore`
3. Create production git worktree: `git worktree add ../spamfilter-multi-prod main`

### Phase 1: Core Infrastructure
4. Add `AppEnvironment` class that reads `APP_ENV` from `--dart-define`
5. Update `AppPaths` to use environment-aware data directory suffix
6. Update `WindowsTaskSchedulerService` to use environment-aware task name
7. Update `BackgroundScanWindowsWorker` to use environment-aware log file name
8. Add environment indicator to window title (`[DEV] vX.Y.Z` suffix)
9. Update About screen to show environment indicator with version
10. Add first-run data seeding: copy production DB to dev data directory if empty

### Phase 2: Build Script Updates
11. Update `build-windows.ps1` to accept `-Environment` parameter (default: `dev`)
12. Production build uses `secrets.prod.json`, dev build uses `secrets.dev.json`
13. Ensure `--dart-define=APP_ENV={env}` is passed to both `flutter build` and `flutter run`

### Phase 3: Single-Instance Mutex
14. Add named mutex in Windows runner (`main.cpp`) using environment-specific name
15. Show message and bring existing window to front if mutex already held
16. Mutex name includes environment: `Global\MyEmailSpamFilter_{Environment}`

### Phase 4: Documentation and First Production Build
17. Update CLAUDE.md with production/development build instructions and worktree setup
18. Update DEVELOPER_SETUP.md with side-by-side workflow
19. Document production worktree maintenance (git pull, rebuilding after main updates)
20. Document version bumping process (when to bump patch on develop)
21. Build and verify production release in worktree

## References

- ADR-0012: AppPaths Platform Storage Abstraction (data directory resolution)
- ADR-0014: Windows Background Scanning Task Scheduler (task naming)
- ADR-0026: Application Identity and Package Naming (app identity)
- [Flutter Flavors Documentation](https://docs.flutter.dev/deployment/flavors)
- [Android Build Variants](https://developer.android.com/build/build-variants)
- [Windows Single Instance with Mutex](https://learn.microsoft.com/en-us/archive/technet-wiki/34423.create-a-single-instance-desktop-application)
