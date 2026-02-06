import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/adapters/storage/app_paths.dart';
import 'dart:io';

void main() {
  // Initialize Flutter binding for path_provider to work in unit tests
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up mock for path_provider methods
  const platform = MethodChannel('plugins.flutter.io/path_provider');
  
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    platform,
    (MethodCall methodCall) async {
      // Create a temp directory for testing
      final tempDir = Directory.systemTemp.createTempSync('app_paths_test_');
      
      if (methodCall.method == 'getApplicationSupportDirectory') {
        return tempDir.path;
      } else if (methodCall.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      return null;
    },
  );

  late AppPaths appPaths;

  setUp(() {
    appPaths = AppPaths();
  });

  group('AppPaths', () {
    test('requires initialization before use', () {
      expect(
        () => appPaths.rulesDirectory,
        throwsA(isA<StateError>()),
      );
    });

    test('initializes successfully', () async {
      await appPaths.initialize();
      expect(appPaths.appSupportDirectory, isA<Directory>());
    });

    test('creates all required subdirectories', () async {
      await appPaths.initialize();

      expect(await appPaths.rulesDirectory.exists(), isTrue);
      expect(await appPaths.credentialsDirectory.exists(), isTrue);
      expect(await appPaths.backupDirectory.exists(), isTrue);
      expect(await appPaths.logsDirectory.exists(), isTrue);
    });

    test('provides correct file paths', () async {
      await appPaths.initialize();

      final rulesPath = appPaths.rulesFilePath;
      expect(rulesPath, endsWith('rules.yaml'));
      expect(rulesPath, contains('rules'));

      final safeSendersPath = appPaths.safeSendersFilePath;
      expect(safeSendersPath, endsWith('rules_safe_senders.yaml'));
      expect(safeSendersPath, contains('rules'));

      final credsPath = appPaths.credentialsMetadataPath;
      expect(credsPath, endsWith('credentials.json'));
      expect(credsPath, contains('credentials'));

      final logPath = appPaths.debugLogPath;
      expect(logPath, endsWith('debug.log'));
      expect(logPath, contains('logs'));
    });

    test('generates backup filenames with timestamps', () async {
      await appPaths.initialize();

      final timestamp = DateTime.parse('2025-12-11T14:30:45');
      final backup = appPaths.getBackupFilename('rules.yaml', timestamp);

      expect(backup, contains('rules'));
      expect(backup, contains('backup'));
      expect(backup, contains('20251211'));
      expect(backup, endsWith('.yaml'));
    });

    test('can initialize multiple times without error', () async {
      await appPaths.initialize();
      await appPaths.initialize(); // Should not throw
      expect(appPaths.appSupportDirectory, isA<Directory>());
    });

    test('throws helpful error message when paths accessed before init', () {
      expect(
        () => appPaths.rulesFilePath,
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('initialize'),
          ),
        ),
      );
    });
  });
}
