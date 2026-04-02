/// First-run data seeder for development environment (ADR-0035).
///
/// When the development environment is launched for the first time and its
/// data directory is empty, this seeder copies the production database and
/// credentials to bootstrap the dev environment with existing data.
///
/// This is a one-time operation marked by a .dev_seeded file.
library;

import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'app_environment.dart';

/// Seeds the development data directory from production data
class DevEnvironmentSeeder {
  static final Logger _logger = Logger();

  /// Seed the dev environment from production if needed.
  ///
  /// Only runs when:
  /// 1. APP_ENV is dev
  /// 2. Dev data directory has no database
  /// 3. Production database exists
  /// 4. .dev_seeded marker does not exist
  ///
  /// [UPDATED] Issue #218: Uses path_provider instead of Platform.environment
  /// for MSIX sandbox compatibility.
  static Future<void> seedIfNeeded() async {
    if (!AppEnvironment.isDev) return;

    // Use path_provider to resolve paths (MSIX-safe)
    final appSupport = await getApplicationSupportDirectory();
    // appSupport is already the dev path (with _Dev suffix applied by AppPaths later)
    // but we need the base path without suffix to find prod data
    final basePath = appSupport.parent.path; // MyEmailSpamFilter parent
    final prodDir = '$basePath\\MyEmailSpamFilter';
    final devDir = '$basePath\\MyEmailSpamFilter_Dev';
    final markerFile = File('$devDir\\.dev_seeded');
    final devDb = File('$devDir\\spam_filter.db');
    final prodDb = File('$prodDir\\spam_filter.db');

    // Skip if already seeded
    if (markerFile.existsSync()) {
      _logger.d('Dev environment already seeded (marker exists)');
      return;
    }

    // Skip if dev DB already exists (manual setup or previous seed)
    if (devDb.existsSync()) {
      _logger.d('Dev database already exists, skipping seed');
      // Create marker to prevent future checks
      await _createMarker(markerFile);
      return;
    }

    // Skip if production DB does not exist (fresh install)
    if (!prodDb.existsSync()) {
      _logger.i('No production database found, skipping dev seed (fresh install)');
      await _createMarker(markerFile);
      return;
    }

    // Seed: copy production data to dev directory
    _logger.i('Seeding dev environment from production data...');

    try {
      // Create dev directory if needed
      await Directory(devDir).create(recursive: true);

      // Copy database
      prodDb.copySync(devDb.path);
      _logger.i('Copied production database to dev: ${devDb.path}');

      // Copy credentials directory if it exists
      final prodCreds = Directory('$prodDir\\credentials');
      final devCreds = Directory('$devDir\\credentials');
      if (prodCreds.existsSync()) {
        await devCreds.create(recursive: true);
        for (final entity in prodCreds.listSync()) {
          if (entity is File) {
            final destPath = '${devCreds.path}\\${entity.uri.pathSegments.last}';
            entity.copySync(destPath);
          }
        }
        _logger.i('Copied production credentials to dev');
      }

      // Copy rules directory if it exists
      final prodRules = Directory('$prodDir\\rules');
      final devRules = Directory('$devDir\\rules');
      if (prodRules.existsSync()) {
        await devRules.create(recursive: true);
        for (final entity in prodRules.listSync()) {
          if (entity is File) {
            final destPath = '${devRules.path}\\${entity.uri.pathSegments.last}';
            entity.copySync(destPath);
          }
        }
        _logger.i('Copied production rules to dev');
      }

      // Create marker
      await _createMarker(markerFile);
      _logger.i('Dev environment seeded successfully from production data');
    } catch (e) {
      _logger.e('Failed to seed dev environment: $e');
      // Create marker anyway to prevent repeated failures
      await _createMarker(markerFile);
    }
  }

  static Future<void> _createMarker(File markerFile) async {
    await markerFile.parent.create(recursive: true);
    await markerFile.writeAsString(
      'Seeded from production on ${DateTime.now().toIso8601String()}\n',
    );
  }
}
