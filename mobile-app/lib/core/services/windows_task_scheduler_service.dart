import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import 'app_environment.dart';
import 'background_scan_manager.dart';
import 'powershell_script_generator.dart';
import '../utils/account_id_sanitizer.dart';

/// Service for managing Windows Task Scheduler integration
///
/// Provides methods to create, update, delete, and monitor scheduled
/// tasks for background email scanning on Windows desktop.
///
/// Per-account model (Sprint 42, F98 / ADR-0039 Decision 2): there is ONE
/// Task Scheduler task per enabled account, named
/// `SpamFilterBackgroundScan_<sanitizedAccountId><suffix>`, whose action
/// launches the app with `--background-scan --account-id=<accountId>`. The
/// public methods accept an optional [accountId]; when null they target the
/// legacy global task name for backward compatibility during migration.
class WindowsTaskSchedulerService {
  static final Logger _logger = Logger();

  /// Base task name prefix (without the per-account token).
  static const String _taskNameBase = 'SpamFilterBackgroundScan';

  /// Legacy global task name (no account token). Retained so an un-migrated
  /// installation's single task can still be found and deleted.
  static String get taskName => '$_taskNameBase${AppEnvironment.taskNameSuffix}';

  /// Per-account task name: `SpamFilterBackgroundScan_<sanitizedAccountId><suffix>`.
  /// When [accountId] is null, returns the legacy global [taskName].
  static String taskNameFor(String? accountId) {
    if (accountId == null) return taskName;
    return '${_taskNameBase}_${sanitizeAccountId(accountId)}${AppEnvironment.taskNameSuffix}';
  }

  /// Create a scheduled task for background scanning
  ///
  /// Creates a Windows Task Scheduler task that launches the app
  /// with `--background-scan` flag at the specified frequency.
  static Future<bool> createScheduledTask({
    required ScanFrequency frequency,
    String? accountId,
  }) async {
    if (frequency == ScanFrequency.disabled) {
      _logger.w('Cannot create task with disabled frequency');
      return false;
    }

    try {
      final name = taskNameFor(accountId);
      _logger.i('Creating scheduled task "$name" with frequency: ${frequency.label}'
          '${accountId != null ? ' (account: $accountId)' : ''}');

      // Get executable path (current running app)
      final executablePath = await _getExecutablePath();
      final workingDirectory = await _getWorkingDirectory();

      _logger.d('Executable path: $executablePath');
      _logger.d('Working directory: $workingDirectory');

      // Generate PowerShell script
      final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
        taskName: name,
        executablePath: executablePath,
        frequency: frequency,
        workingDirectory: workingDirectory,
        accountId: accountId,
      );

      // Execute script
      final result = await _executePowerShellScript(scriptPath);

      if (result.success) {
        _logger.i('Scheduled task created successfully');
        return true;
      } else {
        _logger.e('Failed to create scheduled task: ${result.error}');
        return false;
      }
    } catch (e) {
      _logger.e('Exception creating scheduled task', error: e);
      return false;
    } finally {
      // Cleanup temporary scripts
      await PowerShellScriptGenerator.cleanupScripts();
    }
  }

  /// Update the frequency of an existing scheduled task
  ///
  /// Modifies the trigger of the existing task without recreating it
  static Future<bool> updateScheduledTask({
    required ScanFrequency frequency,
    String? accountId,
  }) async {
    if (frequency == ScanFrequency.disabled) {
      // Disabled means delete the task
      return await deleteScheduledTask(accountId: accountId);
    }

    try {
      _logger.i('Updating scheduled task "${taskNameFor(accountId)}" frequency to: ${frequency.label}');

      // Generate PowerShell script
      final scriptPath = await PowerShellScriptGenerator.generateUpdateTaskScript(
        taskName: taskNameFor(accountId),
        frequency: frequency,
      );

      // Execute script
      final result = await _executePowerShellScript(scriptPath);

      if (result.success) {
        _logger.i('Scheduled task updated successfully');
        return true;
      } else {
        _logger.e('Failed to update scheduled task: ${result.error}');
        return false;
      }
    } catch (e) {
      _logger.e('Exception updating scheduled task', error: e);
      return false;
    } finally {
      await PowerShellScriptGenerator.cleanupScripts();
    }
  }

  /// Delete the scheduled task
  ///
  /// Removes the task from Windows Task Scheduler completely
  static Future<bool> deleteScheduledTask({String? accountId}) async {
    return deleteScheduledTaskByName(taskNameFor(accountId));
  }

  /// Delete a scheduled task by its RAW task name (Sprint 42, F98). Used for
  /// orphan cleanup where only the enumerated task name is known.
  static Future<bool> deleteScheduledTaskByName(String taskName) async {
    try {
      _logger.i('Deleting scheduled task "$taskName"');

      // Generate PowerShell script
      final scriptPath = await PowerShellScriptGenerator.generateDeleteTaskScript(
        taskName: taskName,
      );

      // Execute script
      final result = await _executePowerShellScript(scriptPath);

      if (result.success) {
        _logger.i('Scheduled task deleted successfully');
        return true;
      } else {
        _logger.e('Failed to delete scheduled task: ${result.error}');
        return false;
      }
    } catch (e) {
      _logger.e('Exception deleting scheduled task', error: e);
      return false;
    } finally {
      await PowerShellScriptGenerator.cleanupScripts();
    }
  }

  /// Get the current status of the scheduled task
  ///
  /// Returns a map with task status information:
  /// - exists: Whether the task exists
  /// - state: Current task state (Ready, Running, Disabled)
  /// - enabled: Whether the task is enabled
  /// - lastRunTime: Last execution time (ISO 8601 string)
  /// - nextRunTime: Next scheduled execution (ISO 8601 string)
  /// - lastResult: Exit code of last run (0 = success)
  /// - triggerFrequency: Trigger interval
  static Future<Map<String, dynamic>> getScheduleStatus({String? accountId}) async {
    try {
      _logger.d('Getting scheduled task status for "${taskNameFor(accountId)}"');

      // Generate PowerShell script
      final scriptPath = await PowerShellScriptGenerator.generateGetStatusScript(
        taskName: taskNameFor(accountId),
      );

      // Execute script
      final result = await _executePowerShellScript(scriptPath);

      if (result.success && result.output.isNotEmpty) {
        try {
          // Parse JSON output from PowerShell
          final status = jsonDecode(result.output) as Map<String, dynamic>;
          _logger.d('Task status retrieved: $status');
          return status;
        } catch (e) {
          _logger.e('Failed to parse task status JSON', error: e);
          return {'exists': false, 'error': 'Failed to parse status'};
        }
      } else {
        _logger.w('Failed to get task status: ${result.error}');
        return {'exists': false, 'error': result.error};
      }
    } catch (e) {
      _logger.e('Exception getting task status', error: e);
      return {'exists': false, 'error': e.toString()};
    } finally {
      await PowerShellScriptGenerator.cleanupScripts();
    }
  }

  /// Get the next scheduled execution time
  ///
  /// Returns null if task does not exist or has no next run time
  static Future<DateTime?> getNextScheduledTime({String? accountId}) async {
    try {
      final status = await getScheduleStatus(accountId: accountId);

      if (status['exists'] == true && status['nextRunTime'] != null) {
        return DateTime.parse(status['nextRunTime'] as String);
      }

      return null;
    } catch (e) {
      _logger.e('Failed to get next scheduled time', error: e);
      return null;
    }
  }

  /// Check if the scheduled task exists
  static Future<bool> taskExists({String? accountId}) async {
    final status = await getScheduleStatus(accountId: accountId);
    return status['exists'] == true;
  }

  /// Ensure the scheduled task exists when background scanning is enabled
  ///
  /// [FIX] ISSUE #161: If background scanning is enabled in settings but
  /// the task is missing from Task Scheduler (e.g., after reboot, system
  /// cleanup, or failed recreation), this method recreates it.
  ///
  /// Returns true if the task was recreated, false if it already exists
  /// or recreation is not needed.
  static Future<bool> ensureTaskExists({
    required ScanFrequency frequency,
    String? accountId,
  }) async {
    try {
      if (!Platform.isWindows) return false;
      if (frequency == ScanFrequency.disabled) return false;

      final status = await getScheduleStatus(accountId: accountId);
      if (status['exists'] == true) {
        _logger.d('Scheduled task "${taskNameFor(accountId)}" already exists, no recreation needed');
        return false;
      }

      _logger.i('Scheduled task "${taskNameFor(accountId)}" is missing - recreating with frequency: ${frequency.label}');
      final success = await createScheduledTask(frequency: frequency, accountId: accountId);

      if (success) {
        _logger.i('Scheduled task recreated successfully');
      } else {
        _logger.e('Failed to recreate scheduled task');
      }

      return success;
    } catch (e) {
      _logger.e('Exception during task existence check', error: e);
      return false;
    }
  }

  /// Verify and repair the scheduled task executable path
  ///
  /// Checks if the registered task's executable path matches the current
  /// running app path. If mismatched (e.g., after a rebuild), deletes and
  /// recreates the task with the correct path and same frequency.
  ///
  /// Returns true if repair was needed and performed, false otherwise.
  static Future<bool> verifyAndRepairTaskPath({String? accountId}) async {
    try {
      if (!Platform.isWindows) return false;

      final status = await getScheduleStatus(accountId: accountId);
      if (status['exists'] != true) {
        _logger.d('No scheduled task "${taskNameFor(accountId)}" exists, nothing to repair');
        return false;
      }

      final registeredPath = status['executablePath'] as String?;
      final currentPath = Platform.resolvedExecutable;

      if (registeredPath == null || registeredPath.isEmpty) {
        _logger.w('Could not determine registered executable path');
        return false;
      }

      // Normalize paths for comparison (case-insensitive on Windows)
      if (registeredPath.toLowerCase() == currentPath.toLowerCase()) {
        _logger.d('Task executable path is correct, no repair needed');
        return false;
      }

      _logger.i('Task executable path mismatch detected');
      _logger.i('  Registered: $registeredPath');
      _logger.i('  Current:    $currentPath');

      // Determine current frequency from trigger info
      final triggerFrequency = status['triggerFrequency'] as String? ?? '';
      ScanFrequency frequency = ScanFrequency.every1hour; // default fallback

      if (triggerFrequency.contains('15')) {
        frequency = ScanFrequency.every15min;
      } else if (triggerFrequency.contains('30')) {
        frequency = ScanFrequency.every30min;
      } else if (triggerFrequency.contains('1:00') || triggerFrequency.contains('01:00') || triggerFrequency.contains('PT1H')) {
        frequency = ScanFrequency.every1hour;
      } else if (triggerFrequency == 'Once') {
        frequency = ScanFrequency.daily;
      }

      // Delete old task and recreate with current path
      _logger.i('Repairing task "${taskNameFor(accountId)}" with frequency: ${frequency.label}');
      await deleteScheduledTask(accountId: accountId);
      final success = await createScheduledTask(frequency: frequency, accountId: accountId);

      if (success) {
        _logger.i('Task path repaired successfully');
      } else {
        _logger.e('Failed to repair task path');
      }

      return success;
    } catch (e) {
      _logger.e('Exception during task path verification', error: e);
      return false;
    }
  }

  /// Enumerate all per-account background-scan task names currently registered
  /// in Task Scheduler for this environment (Sprint 42, F98). Used to clean up
  /// orphaned per-account tasks (accounts removed since the task was created)
  /// and to find the legacy global task for deletion after migration.
  ///
  /// Returns the list of task names matching `SpamFilterBackgroundScan*<suffix>`.
  static Future<List<String>> enumerateAccountTasks() async {
    try {
      if (!Platform.isWindows) return const [];
      final suffix = AppEnvironment.taskNameSuffix;
      // Match the base prefix; the suffix (if any) is environment-specific so a
      // dev build never enumerates prod tasks and vice-versa.
      final pattern = suffix.isEmpty
          ? '$_taskNameBase*'
          : '$_taskNameBase*$suffix';
      final script = '''
\$ErrorActionPreference = 'SilentlyContinue'
\$tasks = Get-ScheduledTask | Where-Object { \$_.TaskName -like '$pattern' }
\$names = \$tasks | ForEach-Object { \$_.TaskName }
\$names | ConvertTo-Json -Compress
''';
      final scriptPath = await PowerShellScriptGenerator.writeAdHocScript(script);
      final result = await _executePowerShellScript(scriptPath);
      if (!result.success || result.output.isEmpty) return const [];
      final decoded = jsonDecode(result.output);
      if (decoded is String) return [decoded];
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (e) {
      _logger.w('Failed to enumerate account tasks: $e');
      return const [];
    } finally {
      await PowerShellScriptGenerator.cleanupScripts();
    }
  }

  /// Execute a PowerShell script and return the result
  ///
  /// Runs PowerShell with ExecutionPolicy Bypass to allow script execution
  /// Returns a [PowerShellResult] with success status, output, and error
  static Future<PowerShellResult> _executePowerShellScript(
    String scriptPath,
  ) async {
    try {
      _logger.d('Executing PowerShell script: $scriptPath');

      // Run PowerShell with ExecutionPolicy Bypass
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
        ],
        runInShell: true,
      );

      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      final exitCode = result.exitCode;

      _logger.d('PowerShell exit code: $exitCode');
      if (output.isNotEmpty) {
        _logger.d('PowerShell output: $output');
      }
      if (error.isNotEmpty) {
        _logger.w('PowerShell stderr: $error');
      }

      // Exit code 0 means success
      final success = exitCode == 0;

      return PowerShellResult(
        success: success,
        exitCode: exitCode,
        output: output,
        error: error,
      );
    } catch (e) {
      _logger.e('Exception executing PowerShell script', error: e);
      return PowerShellResult(
        success: false,
        exitCode: -1,
        output: '',
        error: e.toString(),
      );
    }
  }

  /// Get the path to the current executable
  ///
  /// Returns the full path to the Flutter app executable
  static Future<String> _getExecutablePath() async {
    try {
      // In a Flutter Windows app, Platform.resolvedExecutable gives the .exe path
      final executablePath = Platform.resolvedExecutable;
      _logger.d('Resolved executable path: $executablePath');
      return executablePath;
    } catch (e) {
      _logger.e('Failed to get executable path', error: e);
      rethrow;
    }
  }

  /// Get the working directory for the app
  ///
  /// Returns the directory containing the executable
  static Future<String> _getWorkingDirectory() async {
    try {
      final executablePath = await _getExecutablePath();
      final workingDir = path.dirname(executablePath);
      _logger.d('Working directory: $workingDir');
      return workingDir;
    } catch (e) {
      _logger.e('Failed to get working directory', error: e);
      rethrow;
    }
  }
}

/// Result of PowerShell script execution
class PowerShellResult {
  final bool success;
  final int exitCode;
  final String output;
  final String error;

  PowerShellResult({
    required this.success,
    required this.exitCode,
    required this.output,
    required this.error,
  });

  @override
  String toString() {
    return 'PowerShellResult(success: $success, exitCode: $exitCode, '
        'output: $output, error: $error)';
  }
}
