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

  /// The copy succeeded but the marker could not be written, even after one
  /// retry (Sprint 85 7.7.1 M4). The next launch copies again and keeps this
  /// DEV file as `.pre_f354_*` (renamed, never deleted), so a DEV sign-in made
  /// before then is in that backup, not lost.
  copiedMarkerNotWritten,

  /// Another process (the UI or a Task Scheduler background scan) held the
  /// copy lock and did not finish within [DevCredentialSeparation.lockWait]
  /// (Sprint 85 7.7.1 L1). Nothing was changed by this process.
  busy,
}

class DevCredentialSeparation {
  static final Logger _log = Logger();

  /// The credential file name `flutter_secure_storage_windows` uses.
  static const String credentialFileName = 'flutter_secure_storage.dat';

  /// Marker written in the DEV folder once the copy is done.
  static const String markerFileName = '.f354_credentials_separated';

  /// The production product folder name (Runner.rc ProductName for prod).
  static const String productionFolderName = 'MyEmailSpamFilter';

  /// Lock file that keeps two processes from copying at the same time.
  static const String lockFileName = '.f354_lock';

  /// How long a process waits for another process's copy to finish.
  static Duration lockWait = const Duration(seconds: 10);

  /// A lock older than this is left over from a process that died mid-copy
  /// and is taken over.
  static const Duration staleLockAge = Duration(minutes: 2);

  /// Why the last [run] returned [DevCredentialResult.failed],
  /// [DevCredentialResult.copiedMarkerNotWritten] or
  /// [DevCredentialResult.busy] (null after any other result). main.dart
  /// writes it to a log FILE (`Logger` writes nothing in a release build, which
  /// the DEV app is; Sprint 85 5.1.2 M3), and Settings > General shows it
  /// (Sprint 85 7.7.1 M4: the log is opt-in, so it is not visibility).
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
    final lock = File(p.join(devPath, lockFileName));

    // Sprint 85 7.7.1 L1: the UI process and a Task Scheduler background scan
    // can both start before the marker exists. Only the process that creates
    // the lock file copies; the other waits for the marker.
    var haveLock = false;
    // True once the copy is in place: the marker step below releases the lock.
    var copiedInPlace = false;
    try {
      await Directory(devPath).create(recursive: true);
      haveLock = await _takeLock(lock);
      if (!haveLock) {
        final deadline = DateTime.now().add(lockWait);
        while (DateTime.now().isBefore(deadline)) {
          if (await marker.exists()) return DevCredentialResult.alreadyDone;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (await marker.exists()) return DevCredentialResult.alreadyDone;
        lastError = 'another process held the copy lock for more than '
            '${lockWait.inSeconds} s; retried at the next launch';
        return DevCredentialResult.busy;
      }
      // The other process may have finished between our marker check and
      // taking the lock.
      if (await marker.exists()) return DevCredentialResult.alreadyDone;

      if (!await prodFile.exists()) {
        await _writeMarker(marker, 'nothing to copy', now);
        _log.i('F354: no production-named credential file; DEV starts empty');
        return DevCredentialResult.nothingToCopy;
      }

      if (await devFile.exists()) {
        final kept = await _freeBackupPath(devFile.path, now);
        await devFile.rename(kept);
        _log.i('F354: kept the earlier DEV credential file as '
            '${p.basename(kept)}');
      }

      final tmp = File('${devFile.path}.f354_tmp');
      if (await tmp.exists()) await tmp.delete();
      await prodFile.copy(tmp.path);
      await tmp.rename(devFile.path);
      copiedInPlace = true;
    } catch (e) {
      // No marker: the next launch retries. The production-named file was
      // only read, so it is unchanged whatever failed here.
      lastError = e.toString();
      _log.w('F354: DEV credential separation failed, will retry next '
          'launch: $e');
      return DevCredentialResult.failed;
    } finally {
      // Every early return above (alreadyDone, nothingToCopy, failed) lets go
      // of the lock; after a good copy the marker step below does it.
      if (haveLock && !copiedInPlace) await _releaseLock(lock);
    }

    // Sprint 85 7.7.1 M4: the copy is in place. A marker failure is NOT a
    // copy failure: retry the marker only, and report it as its own result.
    try {
      try {
        await _writeMarker(marker, 'copied', now);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await _writeMarker(marker, 'copied', now);
      }
      _log.i('F354: DEV credential file separated from the production file');
      return DevCredentialResult.copied;
    } catch (e) {
      lastError = 'copied, but the marker could not be written ($e); the '
          'next launch copies again and keeps this DEV file as .pre_f354_*';
      _log.w('F354: $lastError');
      return DevCredentialResult.copiedMarkerNotWritten;
    } finally {
      await _releaseLock(lock);
    }
  }

  /// Creates [lock] exclusively. A lock older than [staleLockAge] is left over
  /// from a process that died mid-copy and is replaced.
  static Future<bool> _takeLock(File lock) async {
    try {
      await lock.create(exclusive: true);
      return true;
    } on FileSystemException {
      try {
        final age = DateTime.now().difference(await lock.lastModified());
        if (age > staleLockAge) {
          await lock.delete();
          await lock.create(exclusive: true);
          return true;
        }
      } on FileSystemException {
        // Another process took or removed it first; treat as held.
      }
      return false;
    }
  }

  static Future<void> _releaseLock(File lock) async {
    try {
      if (await lock.exists()) await lock.delete();
    } on FileSystemException catch (e) {
      // A lock left behind is taken over after [staleLockAge]; say so.
      _log.w('F354: could not remove the copy lock: $e');
    }
  }

  /// `<file>.pre_f354_<stamp>`, with `_2`, `_3`, ... added when that name is
  /// already taken (Sprint 85 7.7.1 L1: two renames in one second must never
  /// replace an earlier backup).
  static Future<String> _freeBackupPath(
      String devPath, DateTime Function()? now) async {
    final base = '$devPath.pre_f354_${_stamp((now ?? DateTime.now)())}';
    var candidate = base;
    var n = 2;
    while (await File(candidate).exists()) {
      candidate = '${base}_$n';
      n++;
    }
    return candidate;
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
