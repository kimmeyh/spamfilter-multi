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
/// expression than behind a factory's class hierarchy. Since F282 the only
/// platform difference left is how Documents is FOUND ([_documentsFolder]);
/// the folder itself is the same on both.
///
/// **The default (F282, Sprint 78, Harold):** one named folder in Documents on
/// BOTH platforms -- `Documents\MyEmailSpamFilter` (prod) or
/// `Documents\MyEmailSpamFilter_Dev` (dev) -- so every file the app writes for
/// the user is in one place. It replaced the Sprint 74 split (Android
/// Documents, Windows Downloads) and retired that ADR-0042 non-parity entry.
/// The app folder is added to the DEFAULT only: a folder the user chose in
/// Settings > General always wins and is used exactly as chosen.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../storage/settings_store.dart';
import 'app_environment.dart';

class ExportDirectories {
  ExportDirectories._();

  static final Logger _logger = Logger();

  static String? _defaultOverride;

  /// Test seam: fix the platform's DOCUMENTS folder (the app folder is still
  /// added beneath it), so a test never mocks `dart:io`.
  @visibleForTesting
  static void overrideDefaultForTest(String? dir) => _defaultOverride = dir;

  /// The app's own folder inside Documents, environment-suffixed (ADR-0035),
  /// so DEV and PROD never write into -- or delete from -- each other's files.
  static String get appFolderName =>
      'MyEmailSpamFilter${AppEnvironment.dataDirSuffix}';

  /// How the default is described to the user in Settings. The same on every
  /// platform, because the default is the same.
  static String get defaultLabel => 'Documents/$appFolderName (default)';

  /// The default export folder: `<Documents>/<appFolderName>`.
  ///
  /// Finding Documents is the one platform conditional:
  /// - **Windows**: `getApplicationDocumentsDirectory()`, which
  ///   `path_provider_windows` 2.3.0 resolves to the Documents KNOWN FOLDER
  ///   (`path_provider_windows_real.dart:123-124`, `WindowsKnownFolder.Documents`)
  ///   -- the user's Documents even when they moved it (OneDrive, another
  ///   drive). `%USERPROFILE%\Documents` is the fallback.
  /// - **Android**: the public Documents folder, derived from
  ///   `getExternalStorageDirectory()` by [publicDocumentsFrom]. Not a native
  ///   call: a method channel is registered only in the UI's FlutterEngine, and
  ///   the WorkManager background scan runs in its OWN engine (MV74-2), where a
  ///   native call would fail. `path_provider` works in both.
  /// - **iOS/macOS/Linux** (not shipped): the app's documents folder.
  static Future<String?> platformDefault() async {
    final documents = await _documentsFolder();
    if (documents == null || documents.isEmpty) return null;
    return path.join(documents, appFolderName);
  }

  static Future<String?> _documentsFolder() async {
    final override = _defaultOverride;
    if (override != null) return override;

    if (Platform.isWindows) {
      try {
        return (await getApplicationDocumentsDirectory()).path;
      } catch (e) {
        _logger.w('Documents known folder unavailable; using '
            '%USERPROFILE%\\Documents: $e');
      }
      final profile = Platform.environment['USERPROFILE'];
      return (profile == null || profile.isEmpty)
          ? null
          : path.join(profile, 'Documents');
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

  /// Sprint 75 (Harold Q5 at Manual Validation): where a SAVE DIALOG should
  /// open, so a YAML export starts in the same folder every other export
  /// uses ([resolve]: Settings > General folder, else the platform default).
  ///
  /// Windows takes a filesystem path. Android's system save dialog takes a
  /// DOCUMENT URI (file_picker 8.3.7 passes `initialDirectory` through
  /// `Uri.parse` into `DocumentsContract.EXTRA_INITIAL_URI`), so the path is
  /// converted by [androidDocumentUri]. Null -- the dialog's own last folder,
  /// today's behavior -- when there is nothing usable. Never throws: where the
  /// dialog opens must never be the reason an export fails. The hint is the
  /// OS's to honor; Android documents it as a starting location, not a rule.
  static Future<String?> saveDialogStart({SettingsStore? settingsStore}) async {
    try {
      final dir = await resolve(settingsStore: settingsStore);
      if (Platform.isAndroid) return androidDocumentUri(dir);
      return dir;
    } catch (e) {
      _logger.w('No starting folder for the save dialog: $e');
      return null;
    }
  }

  /// `/storage/emulated/0/Documents/Sub` ->
  /// `content://com.android.externalstorage.documents/document/primary%3ADocuments%2FSub`.
  /// Only the PRIMARY user's shared storage (`/storage/emulated/0`) maps to
  /// the `primary:` document id; any other shape returns null rather than a
  /// guessed URI.
  @visibleForTesting
  static String? androidDocumentUri(String fsPath) {
    const root = '/storage/emulated/0';
    if (fsPath != root && !fsPath.startsWith('$root/')) return null;
    var rel = fsPath.length > root.length ? fsPath.substring(root.length + 1) : '';
    while (rel.endsWith('/')) {
      rel = rel.substring(0, rel.length - 1);
    }
    return 'content://com.android.externalstorage.documents/document/'
        '${Uri.encodeComponent('primary:$rel')}';
  }

  /// The folder to write an export to, created if missing.
  ///
  /// The user's configured folder (Settings > General) wins, used exactly as
  /// chosen; otherwise [platformDefault]. [subfolder] keeps generated files
  /// (diagnostic logs, per-scan exports) in their own folders.
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
      // The app folder name is added here too: on Windows the app's own
      // folder is Documents itself, shared by DEV and PROD.
      final fallbackBase = path.join(await _appOwnFolder(), appFolderName);
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
