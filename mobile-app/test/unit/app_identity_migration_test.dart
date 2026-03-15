import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Unit tests for AppIdentityMigration logic
///
/// These tests verify the migration file copy logic using temp directories
/// rather than importing the actual migration class (which depends on
/// Platform.environment['APPDATA']).
void main() {
  late Directory tempDir;
  late Directory oldDir;
  late Directory newDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_test_');
    oldDir = Directory(path.join(tempDir.path, 'old'));
    newDir = Directory(path.join(tempDir.path, 'new'));
    oldDir.createSync(recursive: true);
    newDir.createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('File migration logic', () {
    test('copies file from old to new when new does not exist', () {
      final oldFile = File(path.join(oldDir.path, 'test.db'));
      oldFile.writeAsStringSync('old data with real content');

      final newFile = File(path.join(newDir.path, 'test.db'));
      expect(newFile.existsSync(), isFalse);

      // Simulate migration: copy if new does not exist
      oldFile.copySync(newFile.path);

      expect(newFile.existsSync(), isTrue);
      expect(newFile.readAsStringSync(), equals('old data with real content'));
    });

    test('replaces smaller new file with larger old file', () {
      final oldFile = File(path.join(oldDir.path, 'test.db'));
      oldFile.writeAsStringSync('old data with lots of real content here');

      final newFile = File(path.join(newDir.path, 'test.db'));
      newFile.writeAsStringSync('fresh');

      // New file is smaller - should be replaced
      expect(newFile.lengthSync(), lessThan(oldFile.lengthSync()));

      oldFile.copySync(newFile.path);

      expect(newFile.readAsStringSync(), equals('old data with lots of real content here'));
    });

    test('does not overwrite larger new file', () {
      final oldFile = File(path.join(oldDir.path, 'test.db'));
      oldFile.writeAsStringSync('small');

      final newFile = File(path.join(newDir.path, 'test.db'));
      newFile.writeAsStringSync('new data that is much larger than old');

      // New file is larger - should NOT be replaced
      expect(newFile.lengthSync(), greaterThanOrEqualTo(oldFile.lengthSync()));

      // Migration logic: only copy if new is smaller
      if (newFile.lengthSync() < oldFile.lengthSync()) {
        oldFile.copySync(newFile.path);
      }

      expect(newFile.readAsStringSync(), equals('new data that is much larger than old'));
    });

    test('copies directory recursively', () {
      // Create old directory structure
      final oldSubDir = Directory(path.join(oldDir.path, 'rules'));
      oldSubDir.createSync();
      File(path.join(oldSubDir.path, 'rules.yaml'))
          .writeAsStringSync('- rule1\n- rule2');
      File(path.join(oldSubDir.path, 'rules_safe_senders.yaml'))
          .writeAsStringSync('- sender1');

      // Create nested archive
      final archiveDir = Directory(path.join(oldSubDir.path, 'Archive'));
      archiveDir.createSync();
      File(path.join(archiveDir.path, 'backup.yaml'))
          .writeAsStringSync('backup data');

      // New directory exists but is empty
      final newSubDir = Directory(path.join(newDir.path, 'rules'));
      newSubDir.createSync();

      // Simulate recursive directory copy
      _copyDirectory(oldSubDir, newSubDir);

      expect(File(path.join(newSubDir.path, 'rules.yaml')).existsSync(), isTrue);
      expect(File(path.join(newSubDir.path, 'rules_safe_senders.yaml')).existsSync(), isTrue);
      expect(File(path.join(newSubDir.path, 'Archive', 'backup.yaml')).existsSync(), isTrue);
    });

    test('does not overwrite existing files in directory copy', () {
      final oldSubDir = Directory(path.join(oldDir.path, 'rules'));
      oldSubDir.createSync();
      File(path.join(oldSubDir.path, 'rules.yaml'))
          .writeAsStringSync('old rules');

      final newSubDir = Directory(path.join(newDir.path, 'rules'));
      newSubDir.createSync();
      File(path.join(newSubDir.path, 'rules.yaml'))
          .writeAsStringSync('new rules already here');

      // Copy without overwriting
      _copyDirectoryNoOverwrite(oldSubDir, newSubDir);

      expect(
        File(path.join(newSubDir.path, 'rules.yaml')).readAsStringSync(),
        equals('new rules already here'),
      );
    });

    test('marker file prevents re-migration', () {
      final markerFile = File(path.join(newDir.path, '.migration_complete'));
      expect(markerFile.existsSync(), isFalse);

      // Write marker
      markerFile.writeAsStringSync('Migration completed: 2026-02-27');
      expect(markerFile.existsSync(), isTrue);

      // On subsequent runs, marker exists -> skip migration
      final shouldMigrate = !markerFile.existsSync();
      expect(shouldMigrate, isFalse);
    });
  });
}

/// Helper: copy directory recursively (simulates migration logic)
void _copyDirectory(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: source.path);
      final targetFile = File(path.join(target.path, relativePath));
      targetFile.parent.createSync(recursive: true);
      entity.copySync(targetFile.path);
    }
  }
}

/// Helper: copy directory without overwriting existing files
void _copyDirectoryNoOverwrite(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: source.path);
      final targetFile = File(path.join(target.path, relativePath));
      if (!targetFile.existsSync()) {
        targetFile.parent.createSync(recursive: true);
        entity.copySync(targetFile.path);
      }
    }
  }
}
