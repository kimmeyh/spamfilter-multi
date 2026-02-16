# ADR-0019: Windows System Tray Integration

## Status

Accepted

## Date

~2026-02 (Sprint 8-9, desktop UX features)

## Context

Desktop applications on Windows are expected to minimize to the system tray (notification area) rather than fully closing when the user clicks the close button. This provides several UX benefits:

- Quick access without navigating to the app in the taskbar
- Visual indicator that the app is running (tray icon)
- Right-click context menu for common actions
- Tooltip showing current status (e.g., "Scanning... 50/100")

The spam filter benefits from tray integration because:
- Background scanning should continue even when the window is hidden
- Users want quick access to scan results without fully opening the app
- The app should feel like a persistent desktop utility, not a launched-and-closed tool

Flutter's desktop support does not include native tray integration. Third-party packages are needed.

## Decision

Use the `system_tray` package (v2.0.3) for tray icon and menu management, combined with `window_manager` (v0.3.7) for window lifecycle control. The integration is implemented in `WindowsSystemTrayService`.

### Tray Menu Structure

```
[Spam Filter Icon]
  |-- Show Window
  |-- ─────────────
  |-- Run Scan Now     (placeholder)
  |-- View Results     (placeholder)
  |-- ─────────────
  |-- Settings         (placeholder)
  |-- ─────────────
  |-- Exit
```

### Window Behavior

- **Close button**: Minimizes to tray (does not exit the app)
- **Single click on tray icon**: Shows and focuses the window
- **Right click on tray icon**: Shows the context menu
- **Exit menu item**: Fully closes the application via `windowManager.destroy()`

### Initialization

- Runs only on Windows (`Platform.isWindows` guard)
- Sets `windowManager.setPreventClose(true)` to intercept close button
- Registers tray icon with tooltip "Spam Filter - Click to show"
- Gracefully degrades: initialization failure logs a warning but does not prevent the app from running

### Dynamic Tooltip

The `updateTooltip()` method allows scan progress to be reflected in the tray tooltip (e.g., "Scanning account@gmail.com... 50/100 emails").

## Alternatives Considered

### No Tray (Always Visible Window)
- **Description**: The app behaves like a standard window - closing it exits the app; no tray icon
- **Pros**: Simplest implementation; no additional packages; standard Flutter behavior
- **Cons**: Users expect desktop utilities to minimize to tray; closing the window would stop background scanning; no quick-access mechanism; feels like a mobile app on desktop rather than a native desktop utility
- **Why Rejected**: The spam filter is a persistent utility that should run in the background. Without tray integration, users must keep the window open or restart the app for each scan

### Custom Win32 Tray Implementation
- **Description**: Use Dart FFI to call Win32 `Shell_NotifyIcon` API directly for tray icon management
- **Pros**: No third-party dependency; full control over Win32 notification area features; lighter weight
- **Cons**: Requires Win32 API expertise; must manage icon resources, message loops, and menu creation manually; significantly more code; platform-specific only (no macOS/Linux path)
- **Why Rejected**: The `system_tray` package already provides a well-tested abstraction over platform tray APIs. Building custom FFI bindings would duplicate effort without meaningful benefit

### Notification Area Only (Icon, No Menu)
- **Description**: Show a tray icon for status indication but without a right-click context menu
- **Pros**: Simpler; fewer UI elements to maintain; icon-only is less intrusive
- **Cons**: Users expect right-click menus on tray icons; no way to access common actions (scan, settings, exit) without opening the full window; less discoverable
- **Why Rejected**: The context menu is a standard Windows tray convention and provides essential quick-access functionality. Users would find an icon-only tray incomplete

## Consequences

### Positive
- **Native desktop feel**: The app behaves like a standard Windows desktop utility with tray icon, context menu, and minimize-to-tray on close
- **Background persistence**: The app continues running when minimized to tray, enabling background scanning without a visible window
- **Quick access**: Users can show the window, trigger scans, or exit from the tray menu without searching for the app
- **Status visibility**: Dynamic tooltip reflects current scan progress in the tray area

### Negative
- **Two package dependencies**: `system_tray` and `window_manager` add two packages to maintain and keep updated
- **Partial menu implementation**: Several menu items (Run Scan Now, View Results, Settings) are currently placeholders that just show the window. Full implementation is planned for future sprints
- **Windows-focused**: While `system_tray` supports macOS and Linux, the implementation and testing have been Windows-only. Tray behavior may differ on other desktop platforms

### Neutral
- **Graceful degradation**: If tray initialization fails (e.g., missing icon file, package incompatibility), the app continues without tray support. Users can still use the app normally through the window

## References

- `mobile-app/lib/core/services/windows_system_tray_service.dart` - System tray implementation (lines 24-168): initialization (24-91), menu setup (94-131), window management (136-168)
- `mobile-app/pubspec.yaml` - `system_tray: ^2.0.3`, `window_manager: ^0.3.7`
- ADR-0014 (Windows Background Scanning) - Tray provides UI for background scan management
