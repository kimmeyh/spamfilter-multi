# ADR-0012: AppPaths Platform Storage Abstraction

## Status

Accepted

## Date

~2025-10 (project inception, expanded through Sprint 1-4)

## Context

The spam filter stores several categories of files on disk:

- **YAML rule files**: `rules.yaml` and `rules_safe_senders.yaml` for the dual-write pattern (ADR-0004)
- **SQLite database**: `spam_filter.db` for runtime storage (ADR-0010)
- **Credential metadata**: OAuth token metadata files
- **Timestamped backups**: YAML backups before each export
- **Debug logs**: Application log files for troubleshooting

Each of the 5 supported platforms (Windows, macOS, Linux, Android, iOS) has different conventions for where applications should store persistent data:

| Platform | Convention |
|----------|-----------|
| Windows | `%APPDATA%\com.example\spam_filter_mobile\` |
| macOS | `~/Library/Application Support/spam_filter_mobile/` |
| Linux | `~/.local/share/spam_filter_mobile/` |
| Android | `/data/user/0/com.example.spam_filter_mobile/files/` |
| iOS | `/Library/Application Support/spam_filter_mobile/` |

Business logic (RuleSetProvider, DatabaseHelper, YamlExportService) must not contain platform-specific path logic. The same code that saves a rule on Windows must work identically on Android.

## Decision

Implement a single `AppPaths` class that wraps Flutter's `path_provider` package to resolve platform-appropriate base directories, then manages a fixed set of subdirectories within that base.

### Directory Structure

```
{platform_app_support_dir}/
  rules/                  # YAML rule files
  credentials/            # OAuth token metadata
  backups/                # Timestamped YAML backups
  logs/                   # Debug log files
  spam_filter.db          # SQLite database (at root level)
```

### Initialization Pattern

`AppPaths` uses lazy initialization with a safety guard:

1. **`initialize()` must be called before any path access** - uses `path_provider`'s `getApplicationSupportDirectory()` to resolve the platform-specific base directory
2. **All subdirectories are auto-created** during initialization (`create(recursive: true)`)
3. **Guard check**: Every property accessor calls `_checkInitialized()`, which throws `StateError` if `initialize()` has not been called
4. **Idempotent**: Calling `initialize()` multiple times is safe (early return if already initialized)

### Integration Points

- **DatabaseHelper**: Receives `AppPaths` via `setAppPaths()` setter; uses `databaseFilePath` for SQLite location
- **RuleSetProvider**: Initializes `AppPaths` during startup; passes to DatabaseHelper and YAML services
- **YamlExportService**: Uses `rulesFilePath` and `safeSendersFilePath` for YAML export; uses `backupDirectory` for timestamped backups
- **Backup naming**: `{name}_backup_YYYYMMDDThhmmss.yaml` format

## Alternatives Considered

### Hardcoded Paths Per Platform
- **Description**: Use `Platform.isWindows`, `Platform.isAndroid`, etc., with hardcoded path strings for each platform in every service that needs file access
- **Pros**: No abstraction layer; direct and explicit; no initialization step
- **Cons**: Path logic duplicated across DatabaseHelper, YamlExportService, RuleSetProvider, and credential stores; adding a new platform requires changes in every file; testing requires platform-specific mocking; violates DRY principle
- **Why Rejected**: Scattering platform-specific paths across multiple services creates maintenance burden and makes cross-platform testing difficult. A single abstraction point means platform support changes happen in one place

### Environment Variable Configuration
- **Description**: Read storage paths from environment variables (e.g., `SPAM_FILTER_DATA_DIR`), falling back to platform defaults
- **Pros**: Maximum flexibility; deployable to non-standard locations; useful for Docker/server environments; testable with custom paths
- **Cons**: Users must configure environment variables (poor UX for a consumer app); environment variable availability differs across platforms (Android does not use env vars the same way); adds a configuration step that most users will never need
- **Why Rejected**: This is a consumer application, not a server-side tool. Users expect the app to "just work" without configuring storage paths. Flutter's `path_provider` already handles platform conventions correctly

### Direct path_provider Usage Throughout Codebase
- **Description**: Call `getApplicationSupportDirectory()` directly wherever a path is needed, without an intermediary class
- **Pros**: No wrapper class to maintain; uses Flutter API directly; fewer abstractions
- **Cons**: `getApplicationSupportDirectory()` is async and must be awaited every time; no centralized subdirectory management; each caller must create subdirectories independently; no guarantee that all callers use consistent subdirectory names; initialization order not enforced
- **Why Rejected**: Centralizing path resolution in `AppPaths` provides a single initialization point, consistent subdirectory structure, and synchronous property access after initialization (avoiding repeated async calls)

## Consequences

### Positive
- **Platform transparency**: Business logic (RuleSetProvider, DatabaseHelper, YamlExportService) operates on paths without knowing the platform. The same code works on all 5 platforms
- **Single initialization point**: `AppPaths.initialize()` is called once during app startup, resolving all paths and creating all directories. Subsequent path access is synchronous and fast
- **Consistent directory structure**: All platforms get the same subdirectory layout (rules/, credentials/, backups/, logs/), making debugging and documentation platform-independent
- **Safety guard**: The `_checkInitialized()` guard catches programming errors where a service tries to access paths before initialization, producing a clear error message instead of a null reference

### Negative
- **Initialization ordering**: `AppPaths.initialize()` must be called before any service that uses paths, creating an implicit dependency order during startup. If initialization fails (e.g., filesystem permissions), the entire app cannot start
- **Fixed directory structure**: The subdirectory layout is hardcoded in `AppPaths`. Adding a new directory type requires modifying the class and its initialization logic
- **path_provider dependency**: The entire storage strategy depends on Flutter's `path_provider` package returning correct paths. Platform-specific bugs in `path_provider` would affect all storage operations

### Neutral
- **Database at root level**: The SQLite database file is stored at the root of the app support directory (not in a subdirectory), while other files are in subdirectories. This is a minor inconsistency that simplifies the database path but means the root directory contains a mix of files and subdirectories
- **Backup accumulation**: Timestamped backups accumulate in the backups/ directory without automatic cleanup. This provides a complete history but requires eventual manual cleanup for long-running installations

## References

- `mobile-app/lib/adapters/storage/app_paths.dart` - AppPaths implementation (lines 1-210)
- `mobile-app/lib/core/storage/database_helper.dart` - DatabaseHelper integration with AppPaths (lines 40-57)
- `mobile-app/lib/core/providers/rule_set_provider.dart` - AppPaths initialization during startup
- `mobile-app/lib/core/services/yaml_export_service.dart` - Uses AppPaths for YAML file locations
- `mobile-app/pubspec.yaml` - `path_provider` dependency
- ADR-0001 (Flutter/Dart Single Codebase) - AppPaths enables the cross-platform promise
- ADR-0004 (Dual-Write Storage) - YAML files stored via AppPaths-managed directories
- ADR-0010 (Database Schema) - Database file located via AppPaths
