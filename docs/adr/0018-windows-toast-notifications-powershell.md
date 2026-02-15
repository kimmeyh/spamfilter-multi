# ADR-0018: Windows Toast Notifications via PowerShell

## Status

Accepted

## Date

~2026-02 (Sprint 8-9, background scanning feature)

## Context

After a background scan completes (see ADR-0014), the application needs to notify the user of the results - specifically, how many unmatched emails were found that may need attention. The app runs without a visible UI during background scans, so in-app notifications are not visible.

Windows 10/11 provides a native notification system (Toast notifications) through the WinRT `Windows.UI.Notifications` API. These appear in the system notification area, support rich content (title, body, images, buttons), and integrate with the Windows Action Center.

The challenge: Flutter does not have mature Windows desktop notification support. The `flutter_local_notifications` plugin had limited or absent Windows support at the time of implementation. Accessing WinRT APIs from Dart requires either native C++ plugins or an alternative bridge.

## Decision

Generate PowerShell scripts at runtime that use the WinRT Toast Notification API, execute them via `Process.run`, and clean up the temporary script files.

### Architecture

```
Dart (WindowsToastNotificationService)
  |
  +--> Generate PowerShell script with Toast XML
  +--> Write to %TEMP%\show_toast_{timestamp}.ps1
  +--> Execute: powershell.exe -NoProfile -ExecutionPolicy Bypass -File {path}
  +--> Delete temp script after execution
```

### Toast XML Template

The generated PowerShell script loads the Windows.UI.Notifications WinRT assembly, creates an XML document with the `ToastGeneric` binding template, and displays it via `ToastNotificationManager`:

```xml
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>{title}</text>
      <text>{body}</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
```

### Key Design Choices

- **App ID**: `SpamFilterMulti.BackgroundScan` - identifies the notification source
- **Non-blocking**: Notification failures are logged but do not propagate to the caller; a failed notification does not block or fail the background scan
- **Conditional display**: Notifications are only shown when unmatched emails are found (`unmatchedCount > 0`); zero-result scans produce no notification
- **XML escaping**: Title and body strings are escaped to prevent XML injection from email content

## Alternatives Considered

### flutter_local_notifications Plugin
- **Description**: Use the cross-platform `flutter_local_notifications` plugin which supports Android, iOS, macOS, and Linux
- **Pros**: Cross-platform API; managed by the Flutter community; handles platform differences; scheduled notifications built-in
- **Cons**: Windows desktop support was limited/experimental at the time of implementation; would add a dependency with uncertain Windows stability; plugin abstraction may not expose all WinRT Toast features
- **Why Rejected**: The plugin did not have production-quality Windows support when the feature was implemented. Using PowerShell provides direct access to the full WinRT Toast API without depending on an immature plugin. The plugin can be adopted in the future when Windows support matures

### Native C++ Win32 Plugin
- **Description**: Write a custom Flutter plugin in C++ that calls the WinRT Toast Notification API directly via the Flutter platform channel
- **Pros**: Native performance; no PowerShell dependency; type-safe API; compiled into the app binary
- **Cons**: Requires C++ development expertise; WinRT COM interop is complex; must maintain a native plugin alongside Dart code; increases build complexity; harder to debug
- **Why Rejected**: The complexity of WinRT COM interop in C++ is disproportionate to the simple notification requirement. PowerShell provides the same WinRT access with dramatically less code and maintenance burden

### In-App Notification Only (No System Notification)
- **Description**: Display notification results only within the app UI (e.g., a banner when the app is next opened)
- **Pros**: No platform-specific code; works on all platforms; simple implementation
- **Cons**: Background scans run when the app is not visible; the user would not know about scan results until they manually open the app; defeats the purpose of background scanning (proactive alerting)
- **Why Rejected**: The primary value of background scanning is proactive notification. If users must manually open the app to see results, background scanning offers little advantage over manual scanning

## Consequences

### Positive
- **Full WinRT access**: Toast notifications support all Windows 10/11 features (Action Center integration, rich content, audio)
- **No native plugin required**: Avoids C++ development, plugin maintenance, and build complexity
- **Simple implementation**: The PowerShell script is a short, well-understood template
- **Non-blocking design**: Notification failures never impact scan functionality

### Negative
- **Windows-only**: This implementation only works on Windows. macOS, Linux, Android, and iOS will each need their own notification mechanism
- **PowerShell execution overhead**: Spawning a PowerShell process for each notification adds ~500ms latency (acceptable for background scan completion, not suitable for rapid-fire notifications)
- **Temp file management**: Temporary `.ps1` files are written to `%TEMP%` and deleted after execution; cleanup failure leaves small orphaned files
- **Execution policy dependency**: Requires PowerShell script execution to be allowed (`-ExecutionPolicy Bypass` flag)

### Neutral
- **Single notification per scan**: Currently shows one notification per background scan cycle (not per account or per email). This keeps notifications non-intrusive but means users must open the app for detailed results

## References

- `mobile-app/lib/core/services/windows_toast_notification_service.dart` - Toast notification implementation (lines 28-136)
- ADR-0014 (Windows Background Scanning) - Background scan triggers notifications
- ADR-0017 (PowerShell Build Automation) - PowerShell as the standard scripting approach
