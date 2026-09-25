/// F206 (Sprint 74): where exported files go, decided in ONE place.
///
/// **Why one place.** Three screens each carried their own copy of the same
/// "configured folder, else a platform default" block, and the Android default
/// (`getExternalStorageDirectory()`, the app's own external folder) was a place
/// the user could not easily find. Meanwhile the diagnostic log and the
/// per-scan exports fell back to app-private storage, which on Android the user
/// cannot reach at all. Every export now resolves its folder here;
/// `test/policy/factory_call_site_test.dart` pins that no screen re-inlines it.
///
/// **Deliberately NOT a platform factory.** ADR-0042 names "an export-directory
/// choice" as a two-value difference that is clearer as one conditional
/// expression than behind a factory's class hierarchy -- so the platform
/// difference is the single conditional in [platformDefault], recorded in
/// ADR-0042 "Deliberate non-parity".
///
/// **The defaults are Harold's decision (Sprint 74 planning, 2026-09-25):**
/// "Android - Documents / Windows - %USERPROFILE%\Downloads". A folder the user
/// chose in Settings > General always wins.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../storage/settings_store.dart';

class ExportDirectories {
  ExportDirectories._();

  static final Logger _logger = Logger();

  static String? _defaultOverride;

  /// Test seam: fix the platform default, so a test never mocks `dart:io`.
  @visibleForTesting
  static void overrideDefaultForTest(String? dir) => _defaultOverride = dir;

  /// How the platform default is described to the user in Settings.
  static String get defaultLabel => Platform.isAndroid
      ? 'Documents folder (default)'
      : Platform.isWindows
          ? 'Downloads folder (default)'
          : 'App documents folder (default)';

  /// The platform's default export folder -- the ONE platform conditional.
  ///
  /// - **Windows**: `getDownloadsDirectory()`, the Downloads KNOWN FOLDER --
  ///   `%USERPROFILE%\Downloads` unless the user moved it, in which case the
  ///   moved location is the one they know as "Downloads". The literal path is
  ///   the fallback.
  /// - **Android**: the public Documents folder, derived from
  ///   `getExternalStorageDirectory()` by [publicDocumentsFrom]. Not a native
  ///   call: a method channel is registered only in the UI's FlutterEngine, and
  ///   the WorkManager background scan runs in its OWN engine (MV74-2), where a
  ///   native call would fail. `path_provider` works in both.
  /// - **iOS/macOS/Linux** (not shipped): the app's documents folder.
  static Future<String?> platformDefault() async {
    final override = _defaultOverride;
    if (override != null) return override;

    if (Platform.isWindows) {
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) return downloads.path;
      } catch (e) {
        _logger.w('Downloads known folder unavailable; using '
            '%USERPROFILE%\\Downloads: $e');
      }
      final profile = Platform.environment['USERPROFILE'];
      return (profile == null || profile.isEmpty)
          ? null
          : path.join(profile, 'Downloads');
    }
    if (Platform.isAndroid) {
      final appExternal = await getExternalStorageDirectory();
      if (appExternal == null) return null;
      return publicDocumentsFrom(appExternal.path) ?? appExternal.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// `/storage/emulated/<user>/Android/data/<pkg>/files` ->
  /// `/storage/emulated/<user>/Documents`. Keeps the user number, so a
  /// secondary or work profile gets ITS OWN Documents folder. Null when the
  /// path does not have the expected shape; the caller then uses the app's own
  /// external folder, which is still reachable over MTP.
  @visibleForTesting
  static String? publicDocumentsFrom(String appExternalPath) {
    const marker = '/Android/data/';
    final i = appExternalPath.indexOf(marker);
    if (i <= 0) return null;
    return '${appExternalPath.substring(0, i)}/Documents';
  }

  /// The folder to write an export to, created if missing.
  ///
  /// The user's configured folder (Settings > General) wins; otherwise the
  /// platform default. [subfolder] keeps generated files (diagnostic logs,
  /// per-scan exports) from cluttering the top of Downloads/Documents.
  static Future<String> resolve({
    String? subfolder,
    SettingsStore? settingsStore,
  }) async {
    String? base;
    try {
      base = await (settingsStore ?? SettingsStore()).getCsvExportDirectory();
    } catch (e) {
      // A settings read must never be the reason an export fails -- but a
      // silently ignored user folder is worth a line in the log.
      _logger.w('Could not read the export folder setting; using the '
          'platform default: $e');
      base = null;
    }
    final usedDefault = base == null || base.isEmpty;
    if (usedDefault) {
      base = await platformDefault();
    }
    if (base == null || base.isEmpty) {
      throw const FileSystemException('No export folder is available');
    }
    final dir = subfolder == null ? base : path.join(base, subfolder);
    if (usedDefault && !await _writable(dir)) {
      // Review I-4: the public default can be unwritable -- Android 7-10
      // (API 24-29) need a storage permission this app does not request, and
      // Android 11+ can refuse a folder left by an earlier install. Fall back
      // to the app's OWN folder, which is always writable (and on Android
      // still reachable over MTP), rather than failing every export.
      final fallbackBase = await _appOwnFolder();
      _logger.w('Default export folder "$dir" is not writable; using '
          '"$fallbackBase" instead');
      final fb = subfolder == null ? fallbackBase : path.join(fallbackBase, subfolder);
      await Directory(fb).create(recursive: true);
      return fb;
    }
    final d = Directory(dir);
    if (!await d.exists()) await d.create(recursive: true);
    return dir;
  }

  /// Test seam: force the writability probe's answer.
  @visibleForTesting
  static bool? debugWritableOverride;

  /// Test seam: the fallback folder used when the default is unwritable.
  @visibleForTesting
  static String? debugAppOwnFolderOverride;

  /// Creates [dir] and writes/deletes a probe file. False on any failure.
  static Future<bool> _writable(String dir) async {
    final forced = debugWritableOverride;
    if (forced != null) return forced;
    try {
      await Directory(dir).create(recursive: true);
      final probe = File(path.join(dir, '.write_probe'));
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (e) {
      _logger.w('Export folder probe failed for "$dir": $e');
      return false;
    }
  }

  /// The app's own, always-writable folder: app external storage on Android,
  /// app documents elsewhere.
  static Future<String> _appOwnFolder() async {
    final forced = debugAppOwnFolderOverride;
    if (forced != null) return forced;
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }
}
