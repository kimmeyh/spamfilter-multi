# ADR-0014: Windows Background Scanning via Task Scheduler

## Status

Accepted

## Date

~2026-02 (Sprint 8-9)

## Context

Users want the spam filter to scan their email accounts automatically on a schedule without manually opening the app. This requires a background execution mechanism that:

- **Runs without user interaction**: Executes scans on a configurable schedule (every 15 minutes to daily)
- **Works when the app is closed**: The scan should not require the Flutter UI to be visible
- **Sends notifications**: Alert the user when unmatched or actionable emails are found
- **Manages system resources**: Should not consume battery or CPU unnecessarily
- **Platform-appropriate**: Use the Windows-native mechanism rather than a cross-platform workaround

Windows offers several background execution options, each with different trade-offs for complexity, reliability, and user permissions.

The Flutter desktop ecosystem does not have a mature, production-quality background task library for Windows. Mobile solutions like `workmanager` (which wraps Android's WorkManager and iOS's BGTaskScheduler) do not support Windows.

## Decision

Use the **Windows Task Scheduler** with **dynamically generated PowerShell scripts** to schedule and execute background scans. The architecture has four components:

### 1. PowerShellScriptGenerator

Generates `.ps1` scripts dynamically based on scan configuration:
- **Create task script**: Registers a scheduled task named `SpamFilterBackgroundScan` with trigger, action, and settings
- **Update task script**: Modifies trigger frequency without recreating the task
- **Delete task script**: Unregisters the scheduled task
- **Status query script**: Returns task state as JSON (exists, enabled, lastRunTime, nextRunTime)

Scripts are written to `%TEMP%\spam_filter_scripts\` and cleaned up after execution.

### 2. WindowsTaskSchedulerService

Executes the generated PowerShell scripts via `Process.run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath])`.

Key operations:
- `createScheduledTask()` - Register the task with frequency and app path
- `updateScheduledTask()` - Change frequency without re-registration
- `deleteScheduledTask()` - Remove the task entirely
- `getScheduleStatus()` - Query task metadata as JSON

### 3. BackgroundModeService

Detects whether the app was launched in background mode by checking for the `--background-scan` command-line flag:
- `BackgroundModeService.initialize(args)` - Called in `main()` with command-line arguments
- `BackgroundModeService.isBackgroundMode` - Static getter for checking mode
- When in background mode, the app skips UI initialization and runs the scan directly

### 4. ScanFrequency Enum

Configurable scan intervals:
- `disabled` (0 minutes)
- `every15min` (15 minutes)
- `every30min` (30 minutes)
- `every1hour` (60 minutes)
- `daily` (1440 minutes)

### Task Scheduler Configuration

The registered task uses these settings:
- **Trigger**: Repeating interval based on `ScanFrequency`, starting from registration time
- **Action**: Launch the app executable with `--background-scan` argument
- **Principal**: Runs as the current user with S4U (Service for User) logon type
- **Settings**: Allow start on battery, require network connection, 30-minute execution time limit

### Notification After Scan

After a background scan completes, results are sent to the user via Windows Toast notifications (using PowerShell-generated Toast API calls). Notifications report the count of unmatched emails found.

## Alternatives Considered

### Windows Service
- **Description**: Create a Windows Service (long-running background process) that manages scan scheduling internally
- **Pros**: Always running; can manage its own schedule; direct control over execution timing; standard Windows pattern for background tasks
- **Cons**: Requires administrator privileges to install; complex registration (sc.exe or MSI installer); must handle service lifecycle (start, stop, pause, resume); heavyweight for periodic scanning; debugging services is harder; Flutter apps are not designed to run as services (no UI thread management)
- **Why Rejected**: Excessive complexity for the use case. The app only needs to run a scan every 15-60 minutes, not maintain a persistent background process. Task Scheduler provides the scheduling infrastructure without the overhead of a full service

### Always-Running Daemon Process
- **Description**: Keep the Flutter app running in the background (minimized to system tray) and use Dart timers for scheduling
- **Pros**: Simple implementation; no external scheduling infrastructure; direct access to app state and credentials
- **Cons**: Consumes memory and CPU continuously; battery drain on laptops; process must survive reboots (requires autostart registration); Flutter desktop apps consume ~100MB+ RAM even when idle; unreliable if the user force-closes the app
- **Why Rejected**: Keeping a Flutter app running permanently for periodic 30-second scans is extremely resource-inefficient. Task Scheduler launches the process only when needed and terminates it after completion

### Node.js or Python Cron Script
- **Description**: Create a separate Node.js or Python script for background scanning, scheduled via Task Scheduler
- **Pros**: Lightweight; quick startup; no Flutter overhead; can share YAML rules directly
- **Cons**: Requires additional runtime dependency (Node.js or Python); must duplicate or share credential access logic; cannot reuse Dart business logic (RuleEvaluator, PatternCompiler, adapters); two codebases to maintain; version synchronization issues
- **Why Rejected**: Duplicating the rule evaluation engine and email adapter logic in another language contradicts ADR-0001 (single codebase). Using the same Flutter app with a `--background-scan` flag reuses all existing business logic

### WorkManager (Flutter Plugin)
- **Description**: Use the `workmanager` Flutter plugin which wraps Android's WorkManager and iOS's BGTaskScheduler
- **Pros**: Cross-platform API; handles scheduling, retry, and constraints; Flutter-native
- **Cons**: Does not support Windows desktop (Android and iOS only); would still need a Windows-specific solution; mixing two scheduling mechanisms increases complexity
- **Why Rejected**: `workmanager` does not support Windows. While it could be used for Android background scanning in the future, a separate Windows mechanism is required regardless. The Task Scheduler approach was built first for the primary development platform (Windows)

## Consequences

### Positive
- **Resource efficient**: The app process launches, scans, and exits. No persistent background process consuming memory or CPU between scans
- **Survives reboots**: Task Scheduler tasks persist across reboots and user logouts. The scan schedule continues without user intervention
- **User-visible**: Users can see and manage the `SpamFilterBackgroundScan` task in Windows Task Scheduler UI, providing transparency and manual control
- **Reuses all business logic**: Background scans use the same RuleEvaluator, PatternCompiler, and email adapters as foreground scans. No code duplication
- **No additional runtime**: Uses only PowerShell and Task Scheduler, both built into every Windows installation

### Negative
- **Windows-only**: This implementation is platform-specific. Android, iOS, macOS, and Linux will each need their own background scan mechanism (WorkManager for Android, BGTaskScheduler for iOS, cron/systemd for Linux, launchd for macOS)
- **PowerShell dependency**: The execution policy must allow script execution (`-ExecutionPolicy Bypass` flag). Some enterprise environments restrict PowerShell script execution
- **Flutter startup overhead**: Each background scan launches a full Flutter application (even without UI), which has a non-trivial startup time (~2-5 seconds) compared to a lightweight script
- **Port 8080 conflict**: If a background scan requires OAuth token refresh, the loopback server (ADR-0011) must bind to port 8080, which may conflict with other applications
- **Temp file management**: Generated PowerShell scripts in `%TEMP%` could accumulate if cleanup fails, though the impact is negligible

### Neutral
- **Single task name**: All accounts share one scheduled task (`SpamFilterBackgroundScan`). The app iterates through all accounts with background scanning enabled during each execution. This simplifies Task Scheduler management but means all accounts scan at the same frequency (the most frequent interval wins)

## References

- `mobile-app/lib/core/services/windows_task_scheduler_service.dart` - Task Scheduler management (lines 1-307)
- `mobile-app/lib/core/services/powershell_script_generator.dart` - PowerShell script generation (lines 1-259)
- `mobile-app/lib/core/services/background_mode_service.dart` - Background mode detection (lines 1-53)
- `mobile-app/lib/core/services/background_scan_manager.dart` - ScanFrequency enum and scan orchestration (lines 1-150+)
- `mobile-app/lib/core/services/background_scan_worker.dart` - Background scan execution (lines 1-246)
- ADR-0013 (Per-Account Settings) - Background scan frequency stored as per-account setting
- ADR-0011 (Desktop OAuth) - Token refresh during background scans uses loopback server
