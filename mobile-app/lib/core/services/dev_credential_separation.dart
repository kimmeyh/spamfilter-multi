/// One-time copy that gives a Windows DEV build its own credential file
/// (F354, Sprint 85; ADR-0035 "Credential store").
///
/// Before F354 every Windows build (DEV, a production build from the prod
/// worktree, and the Microsoft Store app) used ONE credential file:
/// `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter\flutter_secure_storage.dat`.
/// `flutter_secure_storage_windows` 4.1.0 writes that fixed file name into
/// `getApplicationSupportDirectory()` and has no path option
/// (`flutter_secure_storage_windows_ffi.dart:234`, `:252-258`), and
/// `path_provider_windows` 2.3.0 builds that folder from the executable's
/// CompanyName and ProductName (`path_provider_windows_real.dart:180-215`).
/// The Store app is not redirected: the file already existed outside the
/// package, and Microsoft's rule for packaged apps is "If the file is opened
/// from the real AppData location, then no virtualization for that file
/// occurs" (learn.microsoft.com, desktop-to-uwp-behind-the-scenes, 2026-09-30).
/// So deleting an account in DEV removed its production sign-in.
///
/// Since F354 the DEV executable's ProductName is `MyEmailSpamFilter_Dev`
/// (`windows/runner/Runner.rc`), so its support folder, and with it the
/// credential file, is the DEV data folder. This class runs once, at startup,
/// before any credential is read, and copies the production-named file into
/// the DEV folder so DEV keeps its accounts.
///
/// Safety rules:
/// - The production-named file is only READ, never written, moved or deleted.
/// - A credential file already in the DEV folder (a stale one from March 2026
///   exists on the developer machine) is renamed to
///   `flutter_secure_storage.dat.pre_f354_<timestamp>`, never deleted.
/// - The copy goes to a temporary file first and is renamed into place.
/// - The marker `.f354_credentials_separated` is written only after a
///   successful copy (or when there is nothing to copy), so a failed copy is
///   retried at the next launch.
/// - No credential value is read or logged; the file is copied as bytes. It is
///   DPAPI-encrypted for the current Windows user with no extra entropy
///   (`flutter_secure_storage_windows_ffi.dart:404-411`), so the copy decrypts
///   for the same user.
///
/// Parity (ADR-0042 / ADR-0049): Windows-only exception. Android keeps
/// credentials per applicationId and iOS per bundle ID, so DEV and production
/// are already separate there; [run] returns [DevCredentialResult.notApplicable]
/// on every other platform.
library;

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// Outcome of [DevCredentialSeparation.run].
enum DevCredentialResult {
  /// Not a Windows DEV build running with the DEV product name.
  notApplicable,

  /// The marker exists: the copy already ran.
  alreadyDone,

  /// The production-named file was copied into the DEV folder.
  copied,

  /// No production-named file exists; nothing to copy (marker written).
  nothingToCopy,

  /// The copy failed; no marker written, so it is retried next launch.
  failed,
}

class DevCredentialSeparation {
  static final Logger _log = Logger();

  /// The credential file name `flutter_secure_storage_windows` uses.
  static const String credentialFileName = 'flutter_secure_storage.dat';

  /// Marker written in the DEV folder once the copy is done.
  static const String markerFileName = '.f354_credentials_separated';

  /// The production product folder name (Runner.rc ProductName for prod).
  static const String productionFolderName = 'MyEmailSpamFilter';

  /// Why the last [run] returned [DevCredentialResult.failed] (null after any
  /// other result). main.dart writes it to a log FILE: `Logger` writes nothing
  /// in a release build, which the DEV app is (Sprint 85 5.1.2 M3).
  static String? lastError;

  /// Runs the one-time copy when [sharedStore] (PlatformCapabilities.sharesCredentialStoreAcrossEnvironments) and [isDev] are true and
  /// [supportDir] is the DEV product folder (its name ends with [devSuffix]).
  ///
  /// [now] is injectable for tests.
  static Future<DevCredentialResult> run({
    required Directory supportDir,
    required bool sharedStore,
    required bool isDev,
    String devSuffix = '_Dev',
    DateTime Function()? now,
  }) async {
    lastError = null;
    if (!sharedStore || !isDev) return DevCredentialResult.notApplicable;
    final devPath = supportDir.path.replaceAll(RegExp(r'[\\/]+$'), '');
    if (!p.basename(devPath).endsWith(devSuffix)) {
      // An executable built before F354: it still uses the shared,
      // production-named folder. Nothing can be separated from here.
      return DevCredentialResult.notApplicable;
    }

    final marker = File(p.join(devPath, markerFileName));
    if (await marker.exists()) return DevCredentialResult.alreadyDone;

    final prodFile = File(
        p.join(p.dirname(devPath), productionFolderName, credentialFileName));
    final devFile = File(p.join(devPath, credentialFileName));

    try {
      await Directory(devPath).create(recursive: true);
      if (!await prodFile.exists()) {
        await _writeMarker(marker, 'nothing to copy', now);
        _log.i('F354: no production-named credential file; DEV starts empty');
        return DevCredentialResult.nothingToCopy;
      }

      if (await devFile.exists()) {
        final stamp = _stamp((now ?? DateTime.now)());
        final kept = '${devFile.path}.pre_f354_$stamp';
        await devFile.rename(kept);
        _log.i('F354: kept the earlier DEV credential file as '
            '${p.basename(kept)}');
      }

      final tmp = File('${devFile.path}.f354_tmp');
      if (await tmp.exists()) await tmp.delete();
      await prodFile.copy(tmp.path);
      await tmp.rename(devFile.path);

      await _writeMarker(marker, 'copied', now);
      _log.i('F354: DEV credential file separated from the production file');
      return DevCredentialResult.copied;
    } catch (e) {
      // No marker: the next launch retries. The production-named file was
      // only read, so it is unchanged whatever failed here.
      lastError = e.toString();
      _log.w('F354: DEV credential separation failed, will retry next '
          'launch: $e');
      return DevCredentialResult.failed;
    }
  }

  static Future<void> _writeMarker(
      File marker, String what, DateTime Function()? now) async {
    final t = (now ?? DateTime.now)().toIso8601String();
    await marker.writeAsString('F354 $what at $t\n', flush: true);
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
