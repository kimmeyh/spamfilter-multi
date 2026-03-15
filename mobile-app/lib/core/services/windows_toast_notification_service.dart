import 'dart:io';
import 'package:logger/logger.dart';

/// Windows-specific toast notification service for background scan results
///
/// Uses PowerShell and Windows 10+ Toast Notification APIs to display
/// notifications when background scans complete with unmatched emails.
class WindowsToastNotificationService {
  static final Logger _logger = Logger();

  /// Notification app ID for background scan results
  static const String appId = 'MyEmailSpamFilter.BackgroundScan';
  static const String appName = 'MyEmailSpamFilter';

  /// Initialize the notification service
  ///
  /// No initialization required for PowerShell-based notifications
  static Future<void> initialize() async {
    _logger.i('Windows toast notification service ready (PowerShell-based)');
  }

  /// Show toast notification for background scan completion
  ///
  /// Displays a notification with:
  /// - Title: "Spam Filter Background Scan Complete"
  /// - Body: "Found X unmatched emails in Y accounts"
  /// - Action: Tapping opens app (not yet implemented)
  static Future<void> showScanCompleteNotification({
    required int unmatchedCount,
    required int accountsScanned,
  }) async {
    if (unmatchedCount == 0) {
      _logger.d('Skipping notification - no unmatched emails');
      return;
    }

    try {
      _logger.i(
        'Showing scan complete notification: $unmatchedCount unmatched, $accountsScanned accounts',
      );

      final title = 'MyEmailSpamFilter Background Scan Complete';
      final body = unmatchedCount == 1
          ? 'Found $unmatchedCount unmatched email in $accountsScanned ${accountsScanned == 1 ? "account" : "accounts"}'
          : 'Found $unmatchedCount unmatched emails in $accountsScanned ${accountsScanned == 1 ? "account" : "accounts"}';

      // Generate PowerShell script to show toast notification
      final scriptContent = _generateToastNotificationScript(title, body);

      // Save script to temp file
      final tempDir = Directory.systemTemp;
      final scriptPath = '${tempDir.path}\\show_toast_${DateTime.now().millisecondsSinceEpoch}.ps1';
      final scriptFile = File(scriptPath);
      await scriptFile.writeAsString(scriptContent);

      try {
        // Execute PowerShell script
        final result = await Process.run(
          'powershell.exe',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          _logger.i('Toast notification displayed successfully');
        } else {
          _logger.w(
            'Toast notification may have failed: exit ${result.exitCode}, stderr: ${result.stderr}',
          );
        }
      } finally {
        // Cleanup script file
        try {
          await scriptFile.delete();
        } catch (e) {
          _logger.w('Failed to delete temp script', error: e);
        }
      }
    } catch (e) {
      _logger.e('Failed to show toast notification', error: e);
      // Do not rethrow - notification failure should not block scan completion
    }
  }

  /// Generate PowerShell script for Windows toast notification
  ///
  /// Uses Windows.UI.Notifications API to create and display toast
  static String _generateToastNotificationScript(String title, String body) {
    // Escape PowerShell strings
    final escapedTitle = title.replaceAll("'", "''");
    final escapedBody = body.replaceAll("'", "''");
    final escapedAppId = appId.replaceAll("'", "''");
    // final escapedAppName = appName.replaceAll("'", "''"); // Reserved for future use

    return '''
# Windows Toast Notification Script
# Shows a toast notification with title and body

try {
  # Load Windows.UI.Notifications assembly
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

  # Define toast XML template
  \$toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedBody</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

  # Create XmlDocument
  \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
  \$xml.LoadXml(\$toastXml)

  # Create toast notification
  \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)

  # Get toast notifier
  \$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$escapedAppId')

  # Show notification
  \$notifier.Show(\$toast)

  Write-Host "Toast notification displayed successfully"
  exit 0
} catch {
  Write-Error "Failed to show toast notification: \$_"
  exit 1
}
''';
  }

  /// Dismiss the notification
  ///
  /// Note: Windows toast notifications auto-dismiss after timeout
  /// or user action. Manual dismissal is not supported via PowerShell.
  static Future<void> dismissNotification() async {
    _logger.d('Windows toast notifications auto-dismiss - no manual dismissal needed');
  }

  /// Check if notifications are enabled
  ///
  /// Returns true if the user has granted notification permissions.
  /// Note: Windows does not have a permission system like iOS/macOS,
  /// so this always returns true if running on Windows 10+.
  static Future<bool> areNotificationsEnabled() async {
    try {
      // Windows 10+ toast notifications do not require explicit permissions
      // Notifications can be disabled by the user in Windows settings,
      // but there is no API to check this status programmatically
      return Platform.isWindows;
    } catch (e) {
      _logger.w('Failed to check notification permissions', error: e);
      return false;
    }
  }
}
