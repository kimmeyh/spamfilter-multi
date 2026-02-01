import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;

/// Windows system tray integration service
///
/// Provides system tray icon, menu, and window management for Windows desktop.
/// Features:
/// - System tray icon with menu
/// - Minimize to tray
/// - Restore from tray
/// - Show/hide window
/// - Exit application
class WindowsSystemTrayService {
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
      // Initialize window manager for minimize-to-tray support
      await windowManager.ensureInitialized();

      // Set window options
      await windowManager.setPreventClose(true); // Prevent close, minimize to tray instead

      // Get icon path (assuming icon is in assets)
      // Note: For production, use a proper .ico file
      final String iconPath = path.join(
        Directory.current.path,
        'assets',
        'icons',
        'tray_icon.ico',
      );

      // Initialize system tray
      await _systemTray.initSystemTray(
        title: 'Spam Filter',
        iconPath: File(iconPath).existsSync() ? iconPath : '', // Use default if not found
        toolTip: 'Spam Filter - Click to show',
      );

      // Set up tray menu
      await _setupTrayMenu();

      // Register click handler
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          // Single click: Show window
          _showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          // Right click: Show menu (handled by system)
        }
      });

      _isInitialized = true;
    } catch (e) {
      // Initialization failed - log but don't crash
      // App will continue without system tray
      print('Failed to initialize system tray: $e');
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

  /// Exit application completely
  Future<void> _exitApplication() async {
    await windowManager.destroy();
    exit(0);
  }

  /// Update tray tooltip (e.g., "Scanning... 50/100")
  Future<void> updateTooltip(String tooltip) async {
    if (_isInitialized) {
      await _systemTray.setToolTip(tooltip);
    }
  }

  /// Dispose system tray
  Future<void> dispose() async {
    if (_isInitialized) {
      await _systemTray.destroy();
      _isInitialized = false;
    }
  }
}
