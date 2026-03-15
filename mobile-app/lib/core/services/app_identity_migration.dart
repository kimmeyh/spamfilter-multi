/// One-time data migration for Windows app identity change
///
/// [ISSUE #182] Sprint 19 changed the application identity from
/// `com.example.spam_filter_mobile` to `MyEmailSpamFilter`. On Windows,
/// this changed the app data directory from:
///   C:\Users\{user}\AppData\Roaming\com.example\spam_filter_mobile\
/// to:
///   C:\Users\{user}\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\
///
/// This migration copies database, rules, credentials, and secure storage
/// from the old directory to the new one on first launch after the update.
library;

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

/// Migrates app data from the old identity directory to the new one.
///
/// This is a one-time migration that runs on Windows only.
/// It is safe to call multiple times - once data is migrated and a
/// marker file is written, subsequent calls are no-ops.
class AppIdentityMigration {
  static final _log = Logger();

  /// Old app data directory (com.example identity)
  static String get _oldDirPath {
    final appData = Platform.environment['APPDATA'] ?? '';
    return path.join(appData, 'com.example', 'spam_filter_mobile');
  }

  /// New app data directory (MyEmailSpamFilter identity)
  static String get _newDirPath {
    final appData = Platform.environment['APPDATA'] ?? '';
    return path.join(appData, 'MyEmailSpamFilter', 'MyEmailSpamFilter');
  }

  /// Marker file to indicate migration has been completed
  static String get _migrationMarkerPath {
    return path.join(_newDirPath, '.migration_complete');
  }

  /// Run the migration if needed.
  ///
  /// Returns true if migration was performed, false if skipped.
  static Future<bool> migrateIfNeeded() async {
    if (!Platform.isWindows) return false;

    final oldDir = Directory(_oldDirPath);
    final markerFile = File(_migrationMarkerPath);

    // Skip if migration already completed
    if (await markerFile.exists()) {
      _log.d('App identity migration already completed, skipping');
      return false;
    }

    // Skip if old directory does not exist
    if (!await oldDir.exists()) {
      _log.d('Old app data directory not found, no migration needed');
      // Write marker so we do not check again
      await _writeMarker(markerFile);
      return false;
    }

    _log.i('Starting app identity migration from ${oldDir.path}');

    final newDir = Directory(_newDirPath);
    await newDir.create(recursive: true);

    int filesCopied = 0;
    int errors = 0;

    try {
      // 1. Migrate database (most critical - contains accounts, settings, scan history)
      filesCopied += await _migrateFile('spam_filter.db');

      // 2. Migrate flutter_secure_storage.dat (contains encrypted credentials)
      filesCopied += await _migrateFile('flutter_secure_storage.dat');

      // 3. Migrate rules directory (YAML rule files and archives)
      filesCopied += await _migrateDirectory('rules');

      // 4. Migrate backups directory
      filesCopied += await _migrateDirectory('backups');

      // 5. Migrate logs directory
      filesCopied += await _migrateDirectory('logs');

      // 6. Migrate credentials directory (metadata files)
      filesCopied += await _migrateDirectory('credentials');

      _log.i('App identity migration complete: $filesCopied files copied');
    } catch (e) {
      errors++;
      _log.e('App identity migration error: $e');
    }

    // Write marker even if there were some errors, to avoid re-running
    // partial migrations. The old data is preserved as a fallback.
    await _writeMarker(markerFile, filesCopied: filesCopied, errors: errors);

    return filesCopied > 0;
  }

  /// Copy a single file from old to new directory if it exists in old
  /// and does NOT exist in new (do not overwrite).
  ///
  /// Returns 1 if copied, 0 if skipped.
  static Future<int> _migrateFile(String filename) async {
    final oldFile = File(path.join(_oldDirPath, filename));
    final newFile = File(path.join(_newDirPath, filename));

    if (!await oldFile.exists()) {
      _log.d('Migration: $filename not found in old directory, skipping');
      return 0;
    }

    if (await newFile.exists()) {
      // Check if new file is substantially smaller (likely empty/fresh)
      final oldSize = await oldFile.length();
      final newSize = await newFile.length();

      if (newSize >= oldSize) {
        _log.d('Migration: $filename already exists in new directory '
            '(new: $newSize bytes >= old: $oldSize bytes), skipping');
        return 0;
      }

      _log.i('Migration: $filename in new directory is smaller '
          '(new: $newSize bytes vs old: $oldSize bytes), replacing with old');
    }

    try {
      await oldFile.copy(newFile.path);
      _log.i('Migration: Copied $filename '
          '(${await oldFile.length()} bytes)');
      return 1;
    } catch (e) {
      _log.e('Migration: Failed to copy $filename: $e');
      return 0;
    }
  }

  /// Copy all files from an old subdirectory to the new subdirectory.
  ///
  /// Returns the number of files copied.
  static Future<int> _migrateDirectory(String dirName) async {
    final oldSubDir = Directory(path.join(_oldDirPath, dirName));
    final newSubDir = Directory(path.join(_newDirPath, dirName));

    if (!await oldSubDir.exists()) {
      _log.d('Migration: $dirName/ not found in old directory, skipping');
      return 0;
    }

    await newSubDir.create(recursive: true);

    int copied = 0;
    try {
      await for (final entity in oldSubDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: oldSubDir.path);
          final newFile = File(path.join(newSubDir.path, relativePath));

          if (await newFile.exists()) {
            // Do not overwrite existing files
            continue;
          }

          // Create parent directories if needed
          await newFile.parent.create(recursive: true);
          await entity.copy(newFile.path);
          copied++;
        }
      }
      if (copied > 0) {
        _log.i('Migration: Copied $copied files from $dirName/');
      }
    } catch (e) {
      _log.e('Migration: Error copying $dirName/: $e');
    }

    return copied;
  }

  /// Write a marker file to indicate migration is complete.
  static Future<void> _writeMarker(
    File markerFile, {
    int filesCopied = 0,
    int errors = 0,
  }) async {
    try {
      await markerFile.parent.create(recursive: true);
      await markerFile.writeAsString(
        'Migration completed: ${DateTime.now().toIso8601String()}\n'
        'Files copied: $filesCopied\n'
        'Errors: $errors\n'
        'Old path: $_oldDirPath\n'
        'New path: $_newDirPath\n',
      );
    } catch (e) {
      _log.w('Failed to write migration marker: $e');
    }
  }
}
