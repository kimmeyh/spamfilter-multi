import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';

/// Windows system tray integration service
///
/// Provides system tray icon, menu, and window management for Windows desktop.
/// Features:
/// - System tray icon with menu
/// - Minimize to tray
/// - Restore from tray
/// - Show/hide window
/// - Exit application
///
/// Implements [WindowListener] so that the window-close request raised by the
/// native title-bar X button is handled explicitly. window_manager is
/// configured with setPreventClose(true), which intercepts the close request
/// and forwards it to onWindowClose. Without a registered listener that
/// completes the close, clicking X is a silent no-op (BUG-S38-CI-1).
class WindowsSystemTrayService with WindowListener {
  static final Logger _logger = Logger();
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;

  /// Initialize system tray (Windows only)
  ///
  /// Call this during app startup on Windows platform
  Future<void> initialize() async {
    if (!Platform.isWindows) {
      return; // Only initialize on Windows
    }

    if (_isInitialized) {
      return; // Already initialized
    }

    try {
      // Initialize window manager (needed for tray show/hide/focus calls).
      await windowManager.ensureInitialized();

      // BUG-S38-CI-1 (Sprint 39): do NOT call setPreventClose(true) here.
      //
      // History: this app's title-bar X never worked. The cause was
      // setPreventClose(true): window_manager intercepts WM_CLOSE and returns
      // -1 from its window proc, so the runner's normal WM_CLOSE -> WM_DESTROY
      // path is swallowed and the window is never destroyed (X = silent no-op).
      // Routing the close through window_manager.destroy() instead crashed,
      // because in window_manager 0.3.9 destroy() only calls PostQuitMessage(0)
      // (it never calls DestroyWindow), so the message loop exits and the
      // Flutter engine is torn down during process-exit stack unwind AFTER
      // CoUninitialize(), with the orphaned system_tray icon -> native crash.
      //
      // Fix: leave the close path to the native runner. With preventClose off,
      // WM_CLOSE flows to DefWindowProc -> WM_DESTROY, and the runner's
      // SetQuitOnClose(true) (windows/runner/main.cpp) destroys the window
      // in-loop and posts WM_QUIT cleanly -- the same path every other Windows
      // app uses. The single-instance mutex (ADR-0035, held for process
      // lifetime) is released on the clean process exit.
      //
      // A future minimize-to-tray feature can re-introduce a WindowListener
      // whose onWindowClose calls hideWindow() (NOT destroy()); the mixin and
      // onWindowClose stub below are retained for that, but are not wired up.

      // Get icon path from Windows runner resources
      // This is the same icon used for the application window
      final String iconPath = path.join(
        Directory.current.path,
        'data',
        'flutter_assets',
        'assets',
        'app_icon.ico',
      );

      // Fallback to runner resources if flutter assets not available
      final String fallbackIconPath = path.join(
        Directory.current.path,
        'windows',
        'runner',
        'resources',
        'app_icon.ico',
      );

      // Determine which icon path exists
      final String finalIconPath = File(iconPath).existsSync()
          ? iconPath
          : (File(fallbackIconPath).existsSync() ? fallbackIconPath : '');

      // Initialize system tray
      await _systemTray.initSystemTray(
        title: 'MyEmailSpamFilter',
        iconPath: finalIconPath,
        toolTip: 'MyEmailSpamFilter - Click to show',
      );

      // Set up tray menu
      await _setupTrayMenu();

      // Register click handler
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          // Single click: Show window
          _showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          // Right click: Rebuild menu to ensure callbacks work
          _setupTrayMenu();
        }
      });

      _isInitialized = true;
    } catch (e) {
      // Initialization failed - log but don't crash
      // App will continue without system tray
      _logger.w('Failed to initialize system tray: $e');
    }
  }

  /// Set up system tray menu
  Future<void> _setupTrayMenu() async {
    final Menu menu = Menu();

    // Show window item
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show Window',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Run Scan Now',
        onClicked: (menuItem) {
          // TODO: Implement quick scan trigger
          _showWindow(); // For now, just show window
        },
      ),
      MenuItemLabel(
        label: 'View Results',
        onClicked: (menuItem) {
          // TODO: Navigate to results screen
          _showWindow(); // For now, just show window
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Settings',
        onClicked: (menuItem) {
          // TODO: Open settings
          _showWindow(); // For now, just show window
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) => _exitApplication(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// Show window and bring to front
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAlwaysOnTop(false); // Reset always-on-top
  }

  /// Hide window (minimize to tray)
  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  /// Retained stub for a FUTURE minimize-to-tray feature.
  ///
  /// This handler is NOT registered as a listener (see initialize: we removed
  /// addListener + setPreventClose to fix BUG-S38-CI-1). The native runner
  /// handles the title-bar X via WM_CLOSE -> WM_DESTROY -> SetQuitOnClose, so
  /// this method does not run today. If minimize-to-tray is implemented later,
  /// register this listener and have it call hideWindow() (NOT destroy()).
  @override
  void onWindowClose() {
    // Intentionally empty: not wired up. See initialize() BUG-S38-CI-1 note.
  }

  /// Exit application completely (used by the tray "Exit" menu item).
  ///
  /// preventClose is off, so windowManager.close() routes through the native
  /// runner's normal WM_CLOSE -> WM_DESTROY -> SetQuitOnClose(true) path (the
  /// same clean teardown the title-bar X now uses). The single-instance kernel
  /// mutex (ADR-0035, held for process lifetime) is released on process exit.
  /// Dispose the tray icon first so it is not orphaned during teardown.
  Future<void> _exitApplication() async {
    await dispose();
    await windowManager.close();
  }

  /// Update tray tooltip (e.g., "Scanning... 50/100")
  Future<void> updateTooltip(String tooltip) async {
    if (_isInitialized) {
      await _systemTray.setToolTip(tooltip);
    }
  }

  /// Dispose system tray (removes the tray icon so it is not orphaned).
  ///
  /// No removeListener call: this service no longer registers a WindowListener
  /// (see initialize() BUG-S38-CI-1 note). Idempotent via _isInitialized.
  Future<void> dispose() async {
    if (_isInitialized) {
      _isInitialized = false;
      await _systemTray.destroy();
    }
  }
}
